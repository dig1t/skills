---
name: roblox-failure-archaeology
description: Use when a Roblox/Luau bug looks familiar, before re-deriving a fix for placement math, NPC pathfinding, spawning, animation lifecycles, or client tag-handlers, when a weird code pattern (Euler tables over the wire, PivotTo ordering, bounded tag polls, generation counters, provider-injected requires) needs explaining before "simplifying" it, when something works in Studio but breaks live, or when deciding whether odd behavior is a bug or a deliberate design decision.
---

# Roblox Failure Archaeology

## Overview

Canonical case studies from shipped firebit games. Each one is a battle that was already fought and won; the scar tissue (odd-looking code patterns) is load-bearing. Check this chronicle before diagnosing a familiar-looking symptom or "simplifying" a pattern that exists because the naive version failed. Every case study follows the same shape: **symptom → root cause → mechanism → generic lesson → how to detect the same class in your project**.

The concrete incidents below come from a shipped firebit game (the reference implementation of the house stack); the lessons are stated generically and hold for any project on the stack.

## When to use / When NOT to use

**Use when:**
- A bug symptom matches anything in the index table below — read that case study before touching code.
- You are about to change model-placement math, NPC pathfinding, animation lifecycle code, spawn flow, or client tag-handlers — these areas are minefields with documented history.
- You need to know whether something is a bug or a deliberate design decision.
- You are setting up or updating the project's own OPEN-bugs register (format at the bottom).

**Do NOT use when:**
- You have a live symptom and need a triage procedure → use **roblox-debugging-playbook** (symptom→experiment view of this same material).
- You need the rules about what changes are allowed → **roblox-change-control**.
- You need architecture invariants (why services are shaped this way) → **roblox-architecture-contract**.
- You need Roblox platform theory in general → **roblox-platform-reference**.

## Index

| # | Case study | One-line generic lesson |
|---|-----------|--------------------------|
| 1 | Placement rotation saga | Never ship raw CFrames/basis vectors over the network; position + YXZ Euler table only |
| 2 | NPC swarm freeze (6 stacked causes) | Budget/queue pathfinding; don't re-issue walks to stationary targets; disable NPC self-collision |
| 3 | Players spawn at world origin | `CharacterAutoLoads=false`; never `:Wait()` on a signal a place variant never fires |
| 4 | Tag-added handler saw partial replication | Client tag-added handlers must tolerate partial replication — bounded poll, never one-shot resolve |
| 5 | FireClient on nil after a yield | Re-validate (or local-capture) player-keyed state after every yield |
| 6 | Wrong vendored-package API, twice | Verify vendored package APIs by reading `Packages/` source, never from model memory |
| 7 | NPCs spawning on/in the defended object | Filter the protected object from spawn raycasts + enforce min XZ distance |
| 8 | ViewModel physics chaos (ported code) | Studio-vs-live replication differs; per-frame redundant state sets break animations |
| 9 | Avatar Joint Upgrade broke weapon anims | The migration recipe is settled — apply it, do not re-derive |
| 10 | Weapon animation races | Generation counters on play/stop; cache AnimationTracks per anim id |
| 11 | Attack dead after equip/unequip | Clear/gate stale equip state on both client and server |
| 12 | Dropped items lost identity | Preserve model + props metadata across the whole drop/pickup pipeline |
| 13 | Placement ghost climbed invisible sensor volumes | New raycast systems get their own collision group |
| 14 | AoE trap missed its own triggerer | Always union the triggering entity into an AoE victim set |
| 15 | Mobile infinite yield on legacy GUI | Unbounded `WaitForChild` on legacy GUI = hang |
| 16 | Data reorg require breakage | Folder moves need a relative-require sweep; generated files stay put |
| 17 | Require cycles | Break cycles via provider injection; `(require :: any)` is the fallback |
| D1 | Scaled-down automated-kill rewards | Deliberate anti-AFK economics — a design decision, not a bug |
| D2 | Legacy live products undeclared in rblxsync.yml | Deliberate; declaring them risks name-mismatch duplicates |

---

## Case studies

### 1. Placement rotation saga (the crown jewel)

*Shipped firebit game, 2026-05/06: ~15 commits over a week to place a trap model facing the right way.*

**Symptom (evolving):** placed models appeared rotated 180° from the placement ghost; then descendants of multi-part models were mirrored while the PrimaryPart looked correct; then the whole model sat at the asset's original CFrames despite a "correct" pivot.

**Root causes, in discovery order:**
1. Placement was routed through a generic loot-spawn helper whose bounding-box part drifted orientation for asymmetric assets.
2. Client and server each derived the CFrame independently; they drifted.
3. **Left-handed basis + silent network normalization.** `up:Cross(WORLD_FORWARD)` yields a left-handed basis. Roblox's CFrame network serialization silently normalizes to right-handed (flips RightVector). The client's copy crossed the network and got flipped; the server's identical local math did not — a 180° disagreement invisible in same-machine tests. `CFrame.fromMatrix` on the ghost side did the same silent flip, mirroring descendants.
4. **`PivotTo` on an unparented Model** can leave descendant parts at their original asset CFrames while only the WorldPivot reference updates. Parent/pivot ordering was flipped twice for different reasons — read the history of that ordering in your project before touching it.
5. **Euler convention mismatch:** `CFrame.Angles` composes XYZ; it does not round-trip values from `ToEulerAnglesYXZ`. Use `CFrame.fromEulerAnglesYXZ` to match.
6. **Asset authoring:** some models shipped with `WorldPivot` offset 180° from the PrimaryPart.
7. Sending basis vectors over the wire invited all of the above.

**Mechanism:** every one of these is a representation mismatch between what one side computed and what the other side received or applied — the engine "helps" (normalizes, re-orders, defers) exactly once, on exactly one side.

**Final architecture (the settled pattern):** client computes a right-handed frame *by construction* (`WORLD_FORWARD:Cross(up)`) and sends **position + a `{ rY, rX, rZ }` table from `ToEulerAnglesYXZ`**; the server reconstructs via `CFrame.fromEulerAnglesYXZ` and applies `PivotTo` with a deliberate, documented ordering relative to parenting.

**Generic lessons (each cost real debugging days):**
1. Never send raw CFrames or basis vectors client→server. Position + YXZ Euler angles, reconstructed identically on both sides.
2. Any hand-built basis must be right-handed *by construction* — never rely on engine normalization, because it only happens on one side of the wire.
3. `CFrame.Angles` ≠ `fromEulerAnglesYXZ`. Match the extractor to the constructor.
4. Check `PivotTo`-vs-parenting order and the asset's `WorldPivot` before suspecting your math.
5. When client and server disagree, log **both** sides of the wire — the saga burned days assuming the received value equaled the sent value.

**Detect the class:** grep your action payload definitions for CFrame-typed fields (`grep -rn "CFrame" src/Shared` around network/action type definitions); grep for `:Cross(` and verify handedness at each construction site; grep for `CFrame.Angles(` fed from `ToEulerAnglesYXZ` output.

### 2. NPC swarm freeze — six stacked causes

*Shipped firebit game, 2026-06: zombies circled, froze, or wandered instead of reaching the defended object. All six causes fixed in one commit.*

**Root causes / mechanisms:**
1. NPCs shared a collision group but self-collision was never disabled → bodyblocking (pathfinding ignores dynamic bodies). Fix: disable NPC-vs-NPC and NPC-vs-player collision at collision-service init.
2. Chase logic re-issued walk commands every 0.5s at a *stationary* target, tearing down the movement library's follow loop before the NPC advanced. Fix: re-issue only on LOS loss, destination drift, or measured stall.
3. The pathfind budget queue was dead code (its pending-target field was never set) → every chase hit `PathfindingService` directly → a spawn burst flooded `ComputeAsync` → throws → frozen NPCs. Fix: actually route through the queue, dedupe queued entities, run walks detached via `task.spawn`.
4. Fresh spawns idled while queued. Fix: immediate straight-line walk first; the queued path refines.
5. A set-all-targets call only mutated *existing* NPCs; future spawns reverted to the default mode. Fix: store the mode and apply it on spawn.
6. Small destructible targets were unreachable (tight bounding box + short attack range). Fix: an explicit reach-clearance constant.

**Generic lessons:** budget and queue all `ComputeAsync` calls; never re-issue movement to a target that hasn't moved; disable NPC self-collision; global mode setters must also apply to future spawns.

**Detect the class:** grep for direct `PathfindingService` / `ComputeAsync` calls outside the one queued chokepoint; grep for periodic `WalkToPoint`/`MoveTo` re-issue loops with fixed timers; check `CollisionService`-equivalent init for NPC-group self-collision.

### 3. Players spawn at world origin

*Shipped firebit game, 2026-06.*

**Symptom:** everyone spawned at (0,0,0); a place variant also hung on load forever.

**Root cause / mechanism:** `CharacterAutoLoads=true` in the place project.jsons with no SpawnLocation → the engine pre-spawned everyone at origin, and an `if not player.Character` guard then skipped the custom spawn flow entirely. Separately, one place variant waited on a readiness signal that that variant never fires.

**Generic lesson:** the house convention is `CharacterAutoLoads: false` in every place project.json — a player service owns spawning via tagged Spawn parts (see **roblox-architecture-contract**). And never `:Wait()` on a signal without confirming every place variant fires it; gate variant-specific waits behind a place check.

**Detect the class:** `grep -rn "CharacterAutoLoads" *.project.json` (must be false everywhere); grep `:Wait()` call sites and confirm the signal fires in every place that runs the code.

### 4. Tag-added handler saw partial replication

*Shipped firebit game, 2026-06: placed multi-part trap models had no pickup prompt.*

**Root cause / mechanism:** a multi-part Model's CollectionService tag replicates to the client **before** its child parts and *their* tags stream in. A one-shot resolve inside the tag-added handler returned nil and never retried.

**Generic lesson / pattern to reuse:** every client CollectionService tag-added handler must tolerate partial replication — bounded poll for the expected descendants (bailing if the instance is destroyed), with a pending-set to dedupe duplicate waiters. Never a one-shot lookup.

**Detect the class:** grep client code for `GetInstanceAddedSignal` / tag-added handlers and check each for a one-shot `FindFirstChild` on descendants of the tagged instance.

### 5. FireClient on nil after a yield

*Shipped firebit game, 2026-06: leaderboard service crashed when a player left mid-update.*

**Root cause / mechanism:** a yielding call inside a per-player loop; the falsy-return path used `continue` and skipped the player-left check, so a player leaving during the yield nilled the player-keyed cache entry and the subsequent `FireClient` indexed nil.

**Generic lesson:** after **any** yield in a player loop, re-validate or pre-capture player-keyed state (capture the cache table in a local per iteration). Every code path after the yield needs the check — including early-continue paths.

**Detect the class:** in server loops over `Players:GetPlayers()`, find yielding calls (`GetValue`, DataStore, `WaitForChild`, Promise awaits) and check what player-keyed tables are indexed afterward.

### 6. Wrong vendored-package API, twice

*Shipped firebit game, 2026-03 and 2026-05: `Maid:GiveTask` / `DoCleaning` shipped broken twice.*

**Root cause / mechanism:** the house stack vendors **dig1t/maid**, which exposes `Add` / `Clean` / `Destroy` — NOT the quenty-style `GiveTask` / `DoCleaning` that models commonly assume. Wrong method names only fail at runtime.

**Generic lesson:** verify vendored package APIs by reading the source in `Packages/` before calling — never trust model memory for library method names. This holds for Maid, Signal, Promise, and every other Wally dep.

**Detect the class:** `grep -rn "GiveTask\|DoCleaning" src/` — any hit against dig1t/maid is a latent runtime error.

### 7. NPCs spawning on/in the defended object

*Shipped firebit game, 2026-04: zombies spawned on the RV roof.*

**Root cause / mechanism:** the spawn-position raycast could hit the protected object itself and accepted candidates arbitrarily close to it.

**Generic lesson:** exclude the defended/protected object from spawn raycasts and reject candidates below a minimum XZ distance from it.

**Detect the class:** read the spawn service's raycast params — is the central gameplay object in the exclusion list, and is there a min-distance check?

### 8. ViewModel physics chaos (ported code)

*Shipped firebit game, 2026-03/04: a first-person weapon system ported from another project fought Roblox physics for weeks.*

| Symptom | Root cause / fix |
|---------|------------------|
| Parts fell through the map on equip | Unanchored ViewModel root → anchor it |
| Character slid around | ViewModel collided with the character → own collision group + disable its state-machine collisions |
| Arms rendered far from player — **live servers only, fine in Studio** | ViewModel not rooted to the camera; and move the HumanoidRootPart, not the Head, so the Motor6D chain follows |
| Arms stuck in bind pose below camera | A per-frame *redundant* `setVisibility(false)` restarted the idle animation every frame; the fade-in never completed. Fix = delete one line |

**Generic lessons:** Studio-vs-live replication differences are a recurring class — always suspect them when "works in Studio". And idempotent-looking per-frame state sets are **not** idempotent for animations.

**Detect the class:** find per-frame (`RenderStepped`/`Heartbeat`) callbacks that set state unconditionally rather than on change; check any camera-attached rig for anchoring and a dedicated collision group.

### 9. Avatar Joint Upgrade migration — settled recipe

*Shipped firebit game, 2026-05: Roblox's Avatar Joint Upgrade (Motor6D → AnimationConstraint) broke weapon animations. The fix is a complete, verified recipe — apply it, do not re-derive it:*

- Stop destroying the default `Animate` LocalScript (client and server).
- Force `IsKinematic=true` on every created AnimationConstraint; catch late additions via `DescendantAdded`.
- Convert weapon-model Motor6Ds to kinematic AnimationConstraints on server init, preserving rest pose via `Attachment.CFrame = Motor6D.C0/C1`.
- One-heartbeat Attachment "poke" under HumanoidRootPart on spawn/equip (per a Roblox staff workaround) to re-wire nil-attachment constraints.
- Zero-weight all Core/Idle/Movement tracks on equip (restore on unequip); tool tracks at `Action4` priority.

**Generic lesson:** platform migrations of this kind get one reference implementation per studio; new projects copy the recipe, they don't rediscover it in production.

### 10–12. Tool/item lifecycle bugs

- **Animation races** — a play racing an unequip left a stray idle track → **generation counter** on play/stop, so a stale async completion can't act. `LoadAnimation` leaked a track per call → **cache tracks per animation id**. Rapid replay faded against itself → `Stop(0)` + TimePosition reset.
- **Attack dead after equip+unequip** — stale active-tool state never cleared; gate on the client's authoritative hotbar/slot state. Sibling bug: a server-side looped hold AnimationTrack kept replicating after unequip until explicitly `:Stop()`ped before destroy.
- **Dropped items became grey cubes, dead on pickup** — three stacked causes: the item's `model` field unset (fell back to a plain Part), the loot pipeline collapsed multi-part Models to the PrimaryPart, and the pickup path dropped the `props` metadata so the item's identity didn't survive re-equip. **Generic lesson:** an item's model + props metadata must survive the *entire* drop/pickup pipeline; test the round trip, not each half.

**Detect the class:** grep animation code for `LoadAnimation` calls inside handlers (should be cached); grep equip/unequip paths for state fields that are set but never cleared; round-trip-test drop→pickup→re-equip for every item category.

### 13–15. Smaller settled fights

- **Placement ghost climbed invisible sensor volumes** — the placement raycast hit another system's invisible collision-group volumes. First hack reused an existing group; the proper fix was a dedicated collision group for the new raycast system, registered in the shared collision-groups data module. **Generic lesson:** new raycast systems get their own collision group.
- **AoE trap didn't hurt its triggerer** — a tight-radius spatial scan can miss the entity standing exactly on the origin. **Generic lesson:** always union the triggering entity into the AoE victim set.
- **Mobile infinite yield** — `WaitForChild` on a legacy ScreenGui element absent on mobile hung forever. **Generic lesson:** unbounded `WaitForChild` on legacy GUI is banned; pass a timeout or (better) port to React (see **luau-react**).

**Detect the class:** `grep -rn 'WaitForChild("' src/Client | grep -v ","` — hits without a timeout argument on GUI paths are hang candidates.

### 16. Data reorg require breakage

*Shipped firebit game, 2026-04: reorganizing shared data into feature subfolders needed three same-day follow-up fixes.*

**Root cause / mechanism:** relative requires missed in the sweep, plus one auto-generated file that had to move **back** because its generator writes to a fixed path.

**Generic lesson:** folder moves require a full relative-require sweep plus a check for generated-file path assumptions (rblxsync's `Generated.luau`, asphalt image indexes, sourcemaps). Generated files stay where their generator writes them. Regenerate the sourcemap after moves (`npm run build:sourcemap`).

**Detect the class:** after any move, run `luau-lsp`/the analyze hook over `src/` and grep for the old path segment.

### 17. Require cycles

*Shipped firebit game, 2026-06: two service require cycles.*

- One cycle (three services in a loop) broken with `(require :: any)` on a single edge.
- Another broken by **provider injection**: instead of requiring the other service, inject a small getter function (e.g. `getCurrentDay`) at init.

**House pattern:** break cycles by provider injection where practical; `(require :: any)` on one edge is the fallback. Same cleanup surfaced two Luau-solver lessons: direct table iteration yields a distinct metatable type (wrap in `pairs()`), and the solver won't narrow `T?`→`T` across tuple-assign (use fresh non-optional locals) — see **luau-type-expert**.

**Detect the class:** luau-lsp reports the cycle; grep for `(require :: any)` to find existing deliberate breaks before adding requires between services.

---

## Design decisions — do NOT "fix" these classes

**D1. Deliberately scaled-down automated-kill rewards.** *Shipped firebit game, 2026-07:* kills made by placed automated devices credit the placer but pay reduced XP, so "place device, go AFK" cannot out-earn active play; a direct player finishing blow pays full reward. **Generic lesson:** reward scaling on automated/passive sources is anti-AFK economics, not a bug. Any change is an economy-tuning change → gates in **roblox-change-control** (hard rule 4: rationale + predicted metric + evidence path).

**D2. Legacy live products intentionally undeclared in rblxsync.yml.** *Shipped firebit game:* carryover developer products from an earlier era of the game are deliberately NOT declared in the manifest; they live on Roblox untouched until explicitly deprecated. Declaring them risks case-sensitive-name mismatches minting duplicate live products (**roblox-change-control** hard rule 2: never `rblxsync run` live; validate/`--dry-run` only). Related: flag-gated dormant code from earlier eras is fenced by hard rule 3 — leave it alone.

**Generic lesson:** before "fixing" an apparent inconsistency in monetization manifests or reward math, check the manifest comments, the project's CLAUDE.md, and `docs/plans/` for a recorded decision. Absence of a fix is sometimes the fix.

---

## Maintain your project's OPEN register

This skill deliberately carries no live bug list — open bugs are project state, not studio knowledge. Each project MUST keep its own register, either as `docs/plans/open-bugs.md` or inside a project-local skill. Required format per entry:

```markdown
### O<N>. <One-line symptom> — <STATUS: reported | verified | diagnosed | planned>
- **Evidence:** <file path + what to look at; plan file if one exists>
- **Verified:** <date it was last confirmed still open>
- **Re-verify:** `<one-liner command whose output proves it is still open>`
```

Rules for the register:
- Every entry needs a runnable re-verify one-liner (e.g. `grep -c '\- \[x\]' docs/plans/<plan>.md` where 0 = still open, or a `grep -n` on the offending line).
- When an OPEN item gets fixed, move it to a settled note **in the same change** as the fix. A register that disagrees with the repo is a bug.
- Live debug flags, unseeded `Random.new()` in generation code, and ungated `print` spam are register-worthy classes (learned in a shipped firebit game: a committed debug flag distorted every structure-distribution observation, and diagnostic prints committed during debugging outlived their fixes). Sweep for them: `grep -rn "DEBUG_" src/Server`, `grep -rn "Random.new()" src/`, `grep -rn "^\s*print(" src/Server`.
- Economy-touching open bugs (double payouts, reward miscounts) need their own plan before fixing — **roblox-change-control** hard rule 4 applies to the fix too.

## Common mistakes

- **Re-deriving a settled fix.** The Joint Upgrade recipe, the placement wire format, and the pathfind queue encode hard-won platform knowledge. Read the case study before rewriting the area.
- **"Simplifying" scar tissue.** Bounded polls in tag handlers, per-iteration cache captures around yields, Euler-table wire formats, immediate-straight-line-then-refine spawn walks — each looks over-engineered and each replaced a shipped bug. If a pattern looks weird, search this chronicle and the project's git history before deleting it.
- **Treating design decisions as bugs.** Scaled automated rewards and undeclared legacy products are decisions with rationale. "Fixing" them without the **roblox-change-control** gates is a regression, not a cleanup.
- **Citing evidence from memory.** During the original compilation, a commit hash cited from memory was one character wrong. Verify claims against the current repo (`git show --stat`, `grep -n`) before citing them.
- **Assuming Studio behavior equals live behavior** for replication order, camera-rig positioning, or CFrame serialization. Three separate case studies (4, 8, and the saga's handedness flip) were invisible or different in Studio.
- **Fixing an economy bug as a drive-by.** Anything touching live payouts needs its own plan, rationale, and evidence path per **roblox-change-control** hard rule 4.

## Provenance and maintenance

Derived on 2026-07-05 from the firebit house-stack reference project (`git log`/`git show --stat` over the full history plus direct working-tree reads; every underlying commit claim was individually verified that day). Commit hashes and repo-state specifics were dropped in this generic edition; attribution dates in the case studies are commit dates from that verification.

All re-verify and detection commands in this skill run against the **current project repo** (repo-root-relative, per the house structure: `src/Client|Server|Shared`, `Packages/`, `docs/plans/`, `*.project.json`). If your project deviates from the house layout, adjust paths — do not skip the check.

Maintain this skill by adding new case studies in the same symptom → root cause → mechanism → generic lesson → detection format, with a game/date attribution line. Project-specific open bugs go in that project's OPEN register (section above), never here.

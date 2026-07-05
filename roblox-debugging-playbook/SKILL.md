---
name: roblox-debugging-playbook
description: Use when triaging Roblox bug classes in a house-stack project — NPC pathfinding freezing or stalling, placed models rotated 180 degrees, client/server CFrame disagreement, "attempt to index nil" on player-keyed tables, the luau-analyze hook blocking a valid new file, vendored package API errors, players spawning at world origin, "Infinite yield possible on" warnings, data not persisting in Studio, replica data nil on client, tag handlers seeing empty Models, or live-server-only bugs.
---

# Roblox Debugging Playbook

## Overview

Symptom-first triage for the recurring failure modes of the house stack (Luau strict + Rojo + Wally + ProfileDB/Replica + red networking + FeatureFlags): match your symptom in the table, run the discriminating experiment to confirm the cause, then apply the fix pattern. Most of these bug classes have burned a project before — check the table before inventing a new theory.

## When to use / When NOT to use

**Use when:** a bug's symptom matches (or resembles) a row below; you are about to debug anything involving NPC locomotion, placement CFrames, player data, spawning, or client/server disagreement.

**Do NOT use for:**
- Full incident narratives and settled-battle history → **roblox-failure-archaeology**
- Driving the Studio runtime debugger (breakpoints, live inspection) → **roblox-debugging** skill
- General debugging process discipline (hypothesis → experiment loop) → **superpowers:systematic-debugging**
- Build/bootstrap failures (wally, rojo, npm scripts) → **roblox-build-and-env**
- Whether a fix is agent-safe to commit/push/sync → **roblox-change-control** (owns the four hard rules)
- Platform theory behind replication/streaming behavior → **roblox-platform-reference**

## Jargon (defined once)

| Term | Meaning here |
|---|---|
| `sourcemap.json` | Rojo-generated map of the game instance tree → filesystem paths; `luau-lsp` (the Luau type analyzer) needs it to resolve requires |
| red | `dig1t/red` — action networking package (all client↔server messages) |
| Replica | `dig1t/replica` — server→client data replication package (profile data) |
| ProfileService | The project's `src/Server/Features/Core/ProfileService.luau` (the single persistence choke point per the house architecture), NOT the community library of the same name |
| CollectionService | Roblox tag service; tag handlers fire when a tagged instance replicates |
| CFrame | Roblox coordinate frame: position + 3x3 rotation matrix |
| Maid | `dig1t/maid` — cleanup-task container |
| FeatureFlags | The project's `src/Shared/Class/FeatureFlags.luau` (standard flags: `SaveInStudio`, `SaveInventory`, `SkipLoadingScreenInStudio`, `HideTestItems`, plus per-game flags) |

## Triage table

Ranked roughly by historical cost across the studio's projects (NPC locomotion and placement-CFrame bugs were the two most expensive classes; they get deep dives below).

| # | Symptom | Most likely cause | Discriminating experiment | Fix pattern |
|---|---|---|---|---|
| 1 | NPCs circle, freeze, or wander instead of reaching their target | One of SIX stacked causes — see Deep dive 1 | Enable the NPC service's debug visualization/prints if it has them (add state labels + path viz if not); walk the Deep dive 1 checklist | Deep dive 1 below |
| 2 | Placed model orientation wrong: 180° flip, mirrored descendants, ghost preview ≠ placed result, client and server disagree | CFrame basis/Euler/pivot/parent-order class — five distinct causes, see Deep dive 2 | Print `cframe.RightVector` on both sides; if server-local ≈ −(client post-network), you built a left-handed basis | Deep dive 2 below |
| 3 | `luau-analyze` PostToolUse hook blocks an edit to a file that IS valid (typically a newly created file; errors are unresolved requires/unknown modules) | `sourcemap.json` is stale — the hook analyzes only against the existing sourcemap (the header of `scripts/luau-analyze-hook.sh` says exactly this) | `grep -F "YourNewFile.luau" sourcemap.json \|\| echo MISSING` — MISSING confirms stale | Run `npm run build:sourcemap`, retry the edit |
| 4 | Server error `attempt to index nil` on a player-keyed table, intermittent, correlates with players leaving | A yield (DataStore/Http/`task.wait`/async getter) sat between reading the table and using it; the player left mid-yield and a cleanup handler nilled the entry. A `continue` on a falsy return can skip your player-left check | Read the erroring function: is there a yielding call between `cache[player]` lookup and use? Does any early `continue`/`return` path bypass the leave check? | Local-capture the inner table once per iteration and re-check after every yield. (Learned in a shipped firebit game, 2026: a leaderboard loop yielded on a friends-cache fetch mid-iteration and indexed a nilled player entry.) |
| 5 | Client tag-added handler finds a Model with missing children (nil PrimaryPart, missing part, prompt never appears) | A Model's tag replicates BEFORE its child parts and their tags; one-shot resolution returns nil and never retries | In the handler, print `#model:GetChildren()` immediately vs after `task.wait(1)` — count grows | Bounded-poll pattern: poll for the child with a deadline (~5s), bail if `model.Parent` becomes nil, and dedupe concurrent waiters with a pending set |
| 6 | Runtime error calling `GiveTask` / `DoCleaning` on a Maid | Vendored `dig1t/maid` API is `Add` / `Remove` / `Clean` / `Destroy` — NOT the quenty/community API. (Burned a shipped firebit game twice.) | `grep -n "function Maid" Packages/_Index/dig1t_maid@*/maid/init.luau` | Use `maid:Add(task)` / `maid:Clean()`. Generalize: verify ANY vendored package's API in `Packages/_Index/` before calling it |
| 7 | Players spawn at world origin (0,0,0) or fall through the void on join | `CharacterAutoLoads` re-enabled, or no `Spawn`-tagged Part in the place. House convention: spawning is owned by PlayerService via the CollectionService tag `"Spawn"`, with auto-loads off | `grep -n CharacterAutoLoads *.project.json` — must be `false` in every per-place project file. In Studio: is any Part tagged `Spawn`? | Restore `"CharacterAutoLoads": false`; add/tag a Spawn part. Never re-enable auto-loads — see roblox-architecture-contract |
| 8 | Console warning `Infinite yield possible on '...'` + a feature hangs, often only on one platform (e.g. mobile) | Unbounded `WaitForChild` on a GUI/instance that never exists in that context | Does the awaited instance exist in that place/platform at all? Check the project.json mounts and platform-conditional UI | Bound it: `WaitForChild(name, 5)` + nil-check, or gate by platform |
| 9 | Inventory/profile changes don't persist across Studio sessions; or a Studio test-data seed never appears | FeatureFlags interplay: `SaveInStudio` and `SaveInventory` gate persistence branches in ProfileService, and DataTemplate test seeds are typically gated on `SaveInStudio` being false — certain flag combinations silently wipe or never seed | Read the current flag values in `src/Shared/Class/FeatureFlags.luau`, then trace which ProfileService branch wipes or skips your data at load AND at save. Which branch ate it? | Seed test data post-load inside ProfileService (after `Reconcile`), not via DataTemplate. Do NOT flip the flags to "fix" a test — that changes live behavior (see roblox-config-and-flags and roblox-change-control) |
| 10 | Client UI shows nil/default profile data; replica never arrives | (a) Reading the client data controller's replica before it loads, (b) `getReplicaAddedSignal(class, fireForExisting)` called with `fireForExisting=false` so pre-existing replicas are missed, (c) the Replica remote itself timed out (ReplicaClient fetches `ReplicaEvents` with a bounded 8s `WaitForChild`), or (d) server created the replica without this player in its `players` list | Wait on the data controller's Loaded signal and see if it ever fires; if not, check server logs for profile-load failure (house convention kicks players on load failure) | Always pass `true` for `fireForExisting`. Note: this Replica version has no `RequestData` API; the fetch happens inside `getReplicaAddedSignal` |
| 11 | Works in Studio, breaks on live servers only | Replication/streaming timing class: Studio's local client has everything instantly; live clients receive instances asynchronously (worse with StreamingEnabled). Code assuming a descendant/Camera/character part exists "now" | Reproduce in Team Test or a published test place, never plain Play Solo. Ask: what instance does this code assume exists at time zero? | Same bounded-wait discipline as rows 5/8. (Learned in a shipped firebit game, 2026: first-person ViewModel arms rendered away from the player only on live servers.) Theory: roblox-platform-reference |

## Deep dive 1: NPC locomotion freezes (costliest recurring class)

Learned in a shipped firebit game, 2026: one fix commit resolved **six stacked causes** in the horde NPC AI — they masked each other, which is what made the bug so expensive. When NPCs misbehave, check ALL of them:

1. **Self-collision bodyblocking.** If NPCs share a collision group and NPC-vs-NPC collision is on, they jam into each other; pathfinding ignores dynamic bodies, so a jammed NPC stays jammed until a neighbor despawns. Check: the collision setup must disable NPC-vs-NPC (and usually NPC-vs-player) collision.
2. **WalkTo re-issue teardown.** Re-issuing the walk/follow command on a fixed interval to a stationary target tears down the locomotion package's follow loop (cleanup + fresh `ComputeAsync`) before the NPC makes progress. Rule: re-issue only on line-of-sight loss, destination drift, or a measured stall.
3. **Unthrottled `ComputeAsync` flood.** If a pathfind budget queue exists but computes bypass it, a spawn burst floods `PathfindingService`, computes throw, and the locomotion layer freezes the NPC. Check: all chase-path computes go through a per-frame budget queue, deduped per NPC, with each walk command run in `task.spawn` so draining the queue never parks the update loop.
4. **Fresh spawns idle in queue.** A newly spawned NPC waiting for its queued path just stands there. Fix pattern: issue an immediate straight-line walk (no compute) as the first path; the queued computed path refines it.
5. **Mode changes not applied to future spawns.** A "set all NPCs to target X" call that mutates only existing NPCs means later spawns fall back to the default and wander. Cache the current mode on the service and apply it in the spawn path — keep that invariant when touching spawn code.
6. **Unreachable targets.** A tight bounding box plus a small attack range can leave the NPC's collision shell short of its target, so it never satisfies the attack gate. Pad the chase/attack distance gates by a reach constant.

First move for any NPC-behavior bug: turn on (or add) debug state labels and path visualization on the NPC service, plus a debug print stream. Flip them back off before committing. Related invariant from the same project: never spawn NPCs on top of the defended object — filter it from the spawn raycast and enforce a minimum XZ distance; do not weaken that check.

Full incident narrative pattern: roblox-failure-archaeology.

## Deep dive 2: placement CFrame orientation (second costliest)

Learned in a shipped firebit game, 2026: making a placed object match its ghost preview took a long string of fixes. Five independent causes — any ONE reproduces "orientation is wrong":

1. **Left-handed basis silently corrected by network serialization.** `up:Cross(WORLD_FORWARD)` builds a left-handed basis. Roblox's CFrame **network serialization silently normalizes to right-handed** (flips RightVector), so the client's post-network copy and the server's locally-constructed copy disagree by 180°. Build right-handed directly: `right = WORLD_FORWARD:Cross(up)`. Diagnostic: dot-check handedness with `right:Cross(up):Dot(back)` (should be +1), or compare `RightVector` across the wire.
2. **Euler order mismatch.** `CFrame.Angles` is XYZ-order; it does NOT round-trip `cframe:ToEulerAnglesYXZ()`. The inverse of `ToEulerAnglesYXZ` is `CFrame.fromEulerAnglesYXZ`.
3. **Asset pivot offset.** An asset's authored `WorldPivot` can be rotated 180° from its PrimaryPart. Set `model.WorldPivot = primaryPart.CFrame` before `PivotTo`.
4. **PivotTo/parent ordering.** Call `PivotTo` BEFORE parenting — parenting first can replicate the asset's original asset-space CFrames before `PivotTo` runs, which clients briefly render at the wrong spot. If existing code orders these deliberately with a rationale comment, read the rationale before touching it.
5. **Wrapper drift.** Spawning a placed object through a generic pickup/bounding-box wrapper drifts orientation for asymmetric assets. Spawn as a direct Model clone.

**Settled house pattern for networked placement:** the client computes the placement CFrame (right-handed basis), decomposes it to a YXZ Euler table, and sends the red action with `position` + `{rY, rX, rZ}` — never raw CFrames or basis vectors. The server validates every field and reconstructs via `fromEulerAnglesYXZ`. If your project duplicates the placement math between a shared helper and a controller, keep the copies in agreement.

## Common mistakes

- **Treating one NPC cause as THE cause.** The six causes in Deep dive 1 masked each other; fixing one and declaring victory is how this class gets expensive. Walk the whole checklist.
- **Debugging CFrame orientation with prints of Euler angles.** Angles alias; compare `RightVector`/handedness instead (Deep dive 2, cause 1).
- **"Fixing" the analyze hook by weakening it** (or editing `.claude/settings.json`) when the real problem is a stale sourcemap. `npm run build:sourcemap` first, always, after creating/renaming/moving any `.luau` file.
- **Flipping `SaveInStudio`/`SaveInventory` to make a Studio test pass.** Those flags shape live persistence behavior; seed test data post-load instead (row 9), and flag changes need change-control rationale (roblox-change-control).
- **Guessing a vendored package's API from the upstream/community library of the same name.** Maid burned a shipped firebit game twice; grep `Packages/_Index/` first (row 6). Same trap applies to the "ProfileService" name collision.
- **One-shot `WaitForChild`/tag resolution on the client.** Partial replication is normal, not an edge case; use bounded polls/timeouts (rows 5, 8, 11).
- **Leaving debug flags on in commits.** Diagnostic prints and debug-visualization flags get committed to main more often than you'd think; flip them back off before committing.

## Provenance and maintenance

Derived on 2026-07-05 from the firebit house-stack reference project by generalizing its project-specific debugging playbook. Case studies attributed to that project illustrate mechanisms; no instruction depends on that repo or its git history. Re-verify all commands and paths against the CURRENT project before citing them — file layouts and flag values are per-project and volatile.

Re-verification one-liners (run from the current project's repo root):

```bash
# Row 3 — hook analyzes against static sourcemap (read the header comment)
sed -n '1,12p' scripts/luau-analyze-hook.sh
# Row 6 — vendored maid API surface
grep -n "function Maid" Packages/_Index/dig1t_maid@*/maid/init.luau
# Row 7 — auto-loads must be false in every per-place project file
grep -n CharacterAutoLoads *.project.json
# Row 9 — current flag values + persistence branches (VOLATILE: per-project)
grep -n "SaveInStudio\|SaveInventory" src/Shared/Class/FeatureFlags.luau
grep -n "inventory" src/Server/Features/Core/ProfileService.luau | head
# Row 10 — replica client entry points
grep -n "getReplicaAddedSignal\|ReplicaEvents" Packages/_Index/dig1t_replica@*/replica/ReplicaClient.luau
```

---
name: roblox-proof-and-analysis-toolkit
description: Use when a claim needs proof, not a retry — a placed model faces the wrong way (CFrame/basis/Euler math), client and server disagree on an orientation, an economy or difficulty number needs a derived prediction before tuning, a ProcessReceipt path might double-grant or drop on crash, seeded generation should be identical across restarts but isn't, or a player-keyed table goes nil after a yield. Also for pre-tuning predictions (change-control rule 4 evidence) and "prove it, don't just try it" requests.
---

# Roblox Proof And Analysis Toolkit

## Overview

Every recipe here turns a hunch into a checkable statement: a formula you computed by hand, an assert that fails loudly on the wrong branch, or a table derived from the actual data modules. "I ran it once and it looked right" is not proof on this stack — the placement saga (Recipe 1's case study) is the canonical precedent: five stacked causes each survived a "just try it" fix.

These recipes assume the firebit house stack: Luau strict, a single currency-service write choke point, tuning values in `src/Shared/Data` modules, a `FeatureFlags` class gating dormant features, and a ledgered `ProcessReceipt` flow. Verify each anchor against the current project before relying on it (one-liners in the final section).

## When to use / When NOT to use

Use when:

- You are about to claim an orientation, an economy number, a difficulty value, an idempotency property, a determinism property, or a concurrency-safety property is correct.
- You need the predicted-metric half of a tuning rationale (hard rule 4 — see **roblox-change-control** for the rule itself).
- A bug survived one "obvious fix" already.

Do NOT use when:

- You need the lifecycle around proving (when to form a hypothesis, when to stop, how results get accepted) — that is **roblox-research-methodology**. This skill is the HOW; that one is the WHEN.
- You want live measurements (telemetry, console, flag audits) — **roblox-diagnostics-and-tooling**.
- You are triaging an unknown symptom — **roblox-debugging-playbook** first; come here once it names a recipe.
- You want the history of a settled battle — **roblox-failure-archaeology**.
- You are deciding what evidence counts as "tested/done" — **roblox-validation-and-qa**.
- You need platform theory (replication rules, receipt semantics, CFrame internals) rather than a proof procedure — **roblox-platform-reference**.

All paths below are repo-root-relative in the current project. For arithmetic, use `python3` (confirm with `which python3`); the house `aftman.toml` carries no Luau script runner (no lune), so do not plan on running derivations in Luau outside Studio.

---

## Recipe 1 — Orientation / CFrame proof

**When to run:** a placed model, ghost preview, spawned prop, or replicated part faces the wrong way; client and server disagree about a rotation; you are writing any code that constructs a CFrame from vectors or round-trips Euler angles.

**Definitions:** a *CFrame* is Roblox's position+rotation matrix. A *basis* is its three axis vectors (right, up, back). *Right-handed* means `right × up = back`; `CFrame.fromMatrix(pos, right, up, back)` expects that form and does not auto-correct a mirrored (left-handed) one.

**Steps:**

1. **Prove the basis is right-handed.** Two cases:

   - **Building the basis yourself:** derive `back` with the right-handed cross order — `right:Cross(up)`, never `up:Cross(right)` — and guard only against degeneracy:

     ```lua
     local right = WORLD_FORWARD:Cross(up)
     assert(right.Magnitude > 1e-3, "degenerate: up parallel to reference axis")
     right = right.Unit
     local back = right:Cross(up).Unit
     ```

     Right-handed by construction. (A fallback to a second reference axis, e.g. `WORLD_RIGHT:Cross(up)`, is an acceptable alternative to asserting on degeneracy.)

   - **Validating vectors you did NOT construct:** given the exact `right`/`up`/`back` you hand to `CFrame.fromMatrix`, `assert(right:Cross(up):Dot(back) > 0, "left-handed basis")`. `back` must be the incoming vector — if you re-derive it as `right:Cross(up)`, the assert compares the cross product with itself and passes for every non-degenerate basis, mirrored or not, and the check is vacuous.

   The failure mode is silent: Roblox's **network serialization normalizes a left-handed CFrame to right-handed** (flips an axis), so server-local and client-post-replication versions of the "same" CFrame disagree by a 180° mirror.

2. **Prove the Euler round-trip is lossless for your order.** `cframe:ToEulerAnglesYXZ()` pairs with `CFrame.fromEulerAnglesYXZ` — NOT with `CFrame.Angles`, which is the XYZ-order constructor. Proof harness (run in Studio command bar or a spec):

   ```lua
   local original = CFrame.fromMatrix(Vector3.zero, right, up, back)
   local rY, rX, rZ = original:ToEulerAnglesYXZ()
   local rebuilt = CFrame.fromEulerAnglesYXZ(rY, rX, rZ)
   -- Compare axis vectors, not components: FuzzyEq on each of
   -- RightVector/UpVector/LookVector within 1e-4.
   assert(original.RightVector:FuzzyEq(rebuilt.RightVector, 1e-4))
   ```

3. **Prove client/server agreement post-replication.** Log the same CFrame's `ToEulerAnglesYXZ()` on the server at write time AND on the client after replication, then diff. Temporary committed diag prints are an accepted house pattern for this — remove them in the eventual fix commit.

4. **Check the model-side traps** even when the math is right: parent the Model **before** `PivotTo` (an unparented `PivotTo` can leave descendants at their original CFrames), and align `model.WorldPivot = primaryPart.CFrame` first when the authored pivot is offset.

**Prefer an Euler wire format.** When a client must tell the server an orientation, send **position + a YXZ Euler table** (`{ rY, rX, rZ }` from `ToEulerAnglesYXZ()`, rebuilt server-side with `CFrame.fromEulerAnglesYXZ`) rather than raw CFrames or basis vectors. Euler angles cannot encode a mirrored basis, so the whole left-handed class of bug is unrepresentable on the wire.

**Case study (learned in a shipped firebit game, 2026 — the trap placement saga):** five stacked causes, each of which survived "just try rotating it": bounding-box wrapping drifting orientation, a left-handed basis that mirrored only after network normalization, `CFrame.Angles` vs `ToEulerAnglesYXZ` order mismatch, an unparented `PivotTo`, and an offset `WorldPivot`. The settled fix was the Euler wire format above. A follow-on lesson: the shared reference derivation module ended up with zero require sites after the wire format replaced its server usage — it was deliberately kept as the documented reference derivation. Flag-gated or superseded-but-documented code like that is deliberate; do not "clean it up" (hard rule 3, **roblox-change-control**). Full incident chronicle: **roblox-failure-archaeology**.

**"Proven" means:** the handedness assert and the Euler round-trip assert both pass, AND you logged the CFrame on both sides of replication once and they matched. One Studio run without the asserts is not proof.

---

## Recipe 2 — Economy flow audit

**When to run:** before any tuning change to a price, reward, or drop rate (hard rule 4 requires a predicted metric); when asked "can a solo player afford X per cycle"; when adding any new source or sink.

**Step 1 — enumerate sources/sinks from the choke point, not from memory.** On the house stack every currency mutation goes through the currency service's `add`/`take`:

```bash
grep -rn "CurrencyService\.\(add\|take\)" src/Server --include="*.luau"
```

(Adjust the service name if the project diverges — find it by grepping the currency key, e.g. `"coins"`.)

**Step 2 — classify each hit live vs dormant.** For every mutation site, trace its gating: is it behind a `FeatureFlags` value that is currently off, or reachable only from UI that no longer mounts? Read the flag class and the call site — never classify from memory. Dormant flows are **excluded from the audit** but **never deleted or refactored** (hard rule 3; see **roblox-config-and-flags** for the flag audit itself).

**Step 3 — build the source/sink table, one per currency.** Note each currency's persistence class (session-only vs persistent — see **roblox-architecture-contract**; session currencies reset on leave, which changes what "afford" means). Table shape, every row anchored to a data module:

| Flow | Amount | Source of truth |
|---|---|---|
| + NPC kill reward | value | `src/Shared/Data/.../XxxData.luau:<line>` |
| + Loot/pickup scatter | count range × value range (state the expected value) | file:line |
| + Level-up / daily / progression grants | formula or ladder | file:line |
| − Purchases (items, unlocks, upgrades) | price ladder | file:line |
| − Repair / maintenance sinks | rate | file:line |

Include modifiers (friend bonuses, multipliers, subscriptions) with their flag state, and the XP-to-level curve if level-ups grant currency — read the actual curve formula from its module, don't recall it.

**Step 4 — compute per-cycle net for a solo player, showing arithmetic.** The model: kills-per-cycle × reward-share × reward-value, plus scatter expectation, minus the realistic sinks — compared against the **cheapest meaningful sink** ("about one basic purchase or one upgrade tier per cycle" is the shape of a useful answer). Write the arithmetic out; use `python3`.

**Case study (shipped firebit game, 2026):** a session-currency kill reward was tuned 2 → 3 only after deriving "~9–15 per night solo" from the spawn table × composition share × reward value, i.e. roughly one cheap trap or one upgrade tier per night. The derivation, not the playtest feel, was the rationale that satisfied rule 4.

**"Proven" means:** every number in your prediction traces to a file:line in a data module, the arithmetic is written out, and the prediction names a measurable ("solo net session-currency/cycle ≈ +5") that a playtest or balance telemetry (see **roblox-diagnostics-and-tooling**) can confirm or kill.

---

## Recipe 3 — Difficulty curve derivation

**When to run:** before touching any value in the wave/NPC/day-cycle data modules; when asked "how hard is cycle N"; when a playtest "felt" too hard and you need to know whether the numbers agree.

**Step 1 — read the actual formulas from the data modules.** Never derive from memory. The house pattern keeps them in `src/Shared/Data/` (e.g. a wave-data module for spawn counts and composition, an NPC-data module for stats and per-cycle scaling, a day-cycle config for phase lengths). While reading, inventory the traps that break head-arithmetic:

- **Special-case multipliers** (e.g. a doubled teaching first cycle) and exactly where `ceil`/`floor` sit in the expression.
- **Caps** (active-entity caps, damage-multiplier caps) and which values are deliberately uncapped.
- **Multipliers that apply twice** — a zone/tier difficulty multiplier may scale BOTH the spawn count AND each entity's stats; missing one halves your prediction.
- **Composition/share lookup semantics** (inclusive vs exclusive night ranges when picking a row).
- **Boss/elite cadence** (every Nth cycle) and any determinism exceptions attached to it.

**Step 2 — derive the before/after table with python3.** Encode the formula verbatim and print the cycles your change touches, e.g.:

```bash
python3 -c "
import math
for n in range(1, 11):
    base = BASE + math.floor(n**EXP * K)          # from the data module
    total = math.ceil(base * (A + B * players) * (2 if n == 1 else 1))
    print(n, total)"
```

Columns worth deriving: spawn total (solo AND max party), active cap, boss cycles, phase length, composition share. Then a worked stat example for one entity at one cycle ("a cycle-10 basic NPC has `ceil(base × scale)` HP, deals X to players, Y to the defended object").

**Step 3 — state which rows move and by how much, BEFORE editing the file.** A tuning diff without the derived before/after table violates hard rule 4.

**Warning — debug leftovers distort observation.** Before trusting any "per-cycle" intuition from Studio runs, check the cycle-length config for leftover test values (learned in a shipped firebit game, 2026: a day length left at 2 seconds made every day-scale observation garbage for weeks of sessions). See **roblox-config-and-flags** for the debug-toggle audit.

**"Proven" means:** you printed the before/after table for the cycles your change touches and stated which row(s) move and by how much, before editing.

---

## Recipe 4 — Idempotency proof for receipt paths

**When to run:** touching the marketplace receipt service (house path `src/Server/Features/Shop/MarketplaceService.luau`), any receipt-callback registration, or adding a DevProduct. A DevProduct is a Robux consumable; Roblox retries `ProcessReceipt` until your handler returns `Enum.ProductPurchaseDecision.PurchaseGranted`, so every path must be safe to re-run. (Platform semantics: **roblox-platform-reference**.)

**The house receipt flow shape** (verify against the current project's service): in-progress dedupe → player-present check → processed-`purchases`-ledger check → `unsaved`-ledger retry path → product lookup → grant callbacks → write `purchases[PurchaseId]` → profile save → on save failure, park the receipt in `unsaved` → return `PurchaseGranted`.

**Method: enumerate the crash windows and show which mechanism covers each.** Fill this table for YOUR product's callback:

| # | Crash/failure window | What happens on retry | Covered by |
|---|---|---|---|
| 1 | Before any grant | Nothing persisted or granted; full clean re-run | Roblox's retry loop itself |
| 2 | After grant callbacks, before the `purchases` write | Grant already happened, no record → callbacks run **again** | **Usually NOT fully covered — the residual window.** See below |
| 3 | `purchases` written but the profile save fails | Receipt parked in `unsaved`; the retry path replays the ledger move and save — grant callbacks are NOT re-run | `unsaved` ledger |
| 4 | Everything succeeded; Roblox retries anyway | `purchases[PurchaseId]` hit → immediate `PurchaseGranted`, no re-grant | `purchases` ledger |
| 5 | Same receipt re-enters concurrently in one server session | In-progress map hit → `NotProcessedYet` | in-memory dedupe |

**Window 2 analysis discipline:** for a **state-checked** grant (the callback re-derives eligibility server-side — "is the target still in the grantable state?"), a window-2 retry is refused, but may then retry forever until the state recurs; decide and document whether that loop is acceptable. For a **stateless** grant (add N currency), window 2 is a genuine double-grant residual — either accept it explicitly in the plan file or add a pre-grant marker. Do not silently "fix" a documented accepted gap.

**Case study (shipped firebit game, 2026 — a revive-type receipt):** the callback re-derived everything server-side (target still dead? defended object still alive?) and returned a boolean mapped to Granted/NotProcessedYet. The player-left path deliberately returned `true` with the comment "report success so the receipt isn't retried in a loop" — that comment IS the idempotency reasoning pattern to copy: every return value justified in terms of what the retry loop will do with it.

**"Proven" means:** you wrote the five-row table for your product's callback: for each window, either name the covering mechanism or explicitly accept the residual risk in the plan file. A callback is safe only if running it twice is either harmless or detectably refused.

---

## Recipe 5 — Determinism audit

**When to run:** anything that must look identical across server restarts or across clients (world generation, per-structure loot/pickup scatter), or when a "same seed, same world" claim appears.

**Step 1 — build the seeded-vs-unseeded inventory for the current project:**

```bash
grep -rn "Random\.new(\|Rng\.new(" src --include="*.luau"
```

For each hit, record: seeded from what, and is the seed input restart-stable? The house stack ships a seeded xorshift RNG with a `Random`-compatible surface (`NextNumber`/`NextInteger`) at `src/Shared/Modules/Rng.luau` (verify it exists in your project) — prefer it over raw `Random.new()` for anything that claims determinism. `Random.new()` with no argument is time-seeded: fine for intentional per-spawn randomness, disqualifying for "same every restart" claims. Some unseeded sites are deliberate design (per-spawn variety) — classify, don't "fix".

**Step 2 — verify the seed derivation uses only restart-stable inputs:** world position, chunk index, structure pivot (e.g. `bit32.bxor` of scaled X/Z coordinates with large odd multipliers) — never `os.time`, entity creation order, or player join order.

**Step 3 — prove it with a two-run log diff:** log the first N outputs of the stream keyed by seed (e.g. pickup count + first 3 positions per structure) in two separate Studio play sessions, then diff. Any divergence means an unseeded consumer shares the stream or the seed input isn't stable.

**Step 4 — watch for consumption-order coupling:** two consumers pulling from one RNG instance are only deterministic if their call ORDER is fixed. If consumer A sometimes rolls before consumer B, split the streams (derive a sub-seed per consumer).

**Case study (shipped firebit game, 2026):** per-structure loot scatter was made deterministic by seeding from the structure's pivot (`bxor` of scaled X and Z), while chunk/biome placement stayed on unseeded `Random.new()` — a known, documented gap: same structure ⇒ same loot, but chunk layout differed every restart. The audit's value was naming which half was which instead of a blanket "world gen is seeded" claim.

**"Proven" means:** two independent runs produced byte-identical logs for the same seeds. "The seed code looks right" is not proof — the mixing/consumption order can betray you.

---

## Recipe 6 — Yield-safety audit

**When to run:** reviewing or writing any server loop that touches player-keyed state across a *yield* (a call that suspends the coroutine — during it, players can leave and `PlayerRemoving` handlers can nil out your tables). Symptom shape: intermittent "attempt to index nil" in a loop that "can't be nil".

**Steps:**

1. **Find the yields inside loops:**

   ```bash
   grep -rn "task\.wait\|:Wait()\|WaitForChild\|Async(\|GetValue" src/Server --include="*.luau"
   ```

   `GetValue`, all `*Async`, `WaitForChild`, `task.wait`, and `Signal:Wait()` yield. Flag every hit that sits inside a `for`/`while` iterating players or a player-keyed table.

2. **For each flagged site, verify post-yield revalidation.** After EVERY yield the code must either (a) re-check `player.Parent` (against `Players`, not just non-nil) and re-index the shared table, or (b) have captured the table in a local BEFORE the loop body's yields so a concurrent nil-out can't crash the tail of the iteration.

3. **Check the control flow, not just the checks.** The subtle variant: a guard placed after the yield but skipped by a `continue`/early branch on the yield's falsy return.

**Case study (learned in a shipped firebit game, 2026-06 — a leaderboard friends cache):** a web-API `GetValue` yielded inside a player loop; when it returned falsy, `continue` skipped the player-left check, so a player leaving mid-yield let `PlayerRemoving` nil the cache and a later `FireClient` indexed nil. The fix shape to copy: capture `local cache = Service.cache[player]` at the top of each outer iteration, abort if nil, re-check `player.Parent ~= Players` after the yield on the path that proceeds, and use only the captured local afterward.

**"Proven" means:** for every yield in the loop you can point at the revalidation (or pre-yield capture) that dominates every code path after it — including `continue` branches. If you can't trace one, write the failing scenario as a comment and fix it; to reproduce live, use **roblox-debugging** breakpoints to park a player mid-yield and kick them.

---

## Common mistakes

- Fixing an orientation bug by rotating 180° at the symptom site instead of proving handedness/Euler-order at the construction site — how the trap saga started.
- Comparing CFrames by printed components instead of `FuzzyEq` on axis vectors (float noise creates false negatives; mirrored bases can create false positives on position-only prints).
- Tuning an economy or difficulty number without the derived before/after table — violates hard rule 4 and produces unreviewable diffs.
- Counting dormant flag-gated sinks in the economy audit — they are dormant, and touching them violates hard rule 3.
- Declaring a receipt path safe because "the ledger has a dedupe" without enumerating window 2 (grant-then-crash-before-write).
- "Proving" determinism by reading the seed code — only a two-run log diff counts.
- Adding `player.Parent` checks after a yield but leaving a `continue` path that skips them.
- Doing Recipe-3 arithmetic in your head: special-case multipliers, `ceil`/`floor` placement, and tier multipliers that apply to both count AND stats are all easy to drop. Use the python3 snippet.
- Deleting a zero-require-site reference module because "nothing requires it" — check whether it is the documented reference derivation for a settled battle first (**roblox-failure-archaeology**).

## Provenance and maintenance

Derived on 2026-07-05 from the firebit house-stack reference project. The recipes are the durable content; every path, service name, and flow shape above is a house convention that a given project may have drifted from. Re-verify the anchors against the CURRENT project before relying on them:

```bash
# Recipe 2 — currency choke point exists and enumerate live mutations
grep -rn "CurrencyService\.\(add\|take\)" src/Server --include="*.luau"
# Recipes 2/3 — tuning values live in data modules; read them, never recall them
ls src/Shared/Data
# Recipe 2 — flag class for live-vs-dormant classification
ls src/Shared/Class/FeatureFlags.luau
# Recipe 4 — receipt flow anchors (dedupe, ledgers, decisions)
grep -n "PurchaseGranted\|NotProcessedYet\|purchases\[\|unsaved" src/Server/Features/Shop/MarketplaceService.luau | head
# Recipe 5 — seeded RNG module present? full RNG inventory
ls src/Shared/Modules/Rng.luau
grep -rn "Random\.new(\|Rng\.new(" src --include="*.luau"
# Recipe 6 — yields inside player loops
grep -rn "task\.wait\|:Wait()\|WaitForChild\|Async(" src/Server --include="*.luau"
# Toolchain — confirm no Luau script runner before planning Luau-side derivations
cat aftman.toml
which python3
```

If a re-verify grep comes back empty, the project has diverged from the house convention — find the equivalent (grep a currency key, a `ProcessReceipt` reference, or `registerCallback`) and note the divergence rather than assuming the recipe's anchor.

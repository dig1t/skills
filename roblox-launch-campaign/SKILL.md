---
name: roblox-launch-campaign
description: Use when taking a Roblox game from "code done" to launch-ready, resuming a stalled launch push, clearing a Testing lane full of unverified features, re-balancing an economy or difficulty curve before launch, planning retention experiments, or starting a session with no explicit task while the board's In Progress/Testing lanes look stalled. Sequenced, decision-gated campaign template with measurable gates between phases.
---

# Roblox Launch Campaign (house-stack template)

## Overview

A reusable, decision-gated template for taking any firebit house-stack game from "code done, nothing verified" to launch-ready. Four phases, in order, each with exact commands, expected observations, and a **measurable gate** that must pass before the next phase starts. Never judge a gate by eye — every gate is a parsed test summary, a scenario PASS, or a logged number compared against a **written prediction**.

The phases:

- **Phase 0** — bring the verification pipeline online (one green unit-test run, one green smoke playtest).
- **Phase 1** — convert every "code done, needs playtest" item into a scripted scenario and clear the Testing lane.
- **Phase 2** — balance re-triage: derive current curves from the game's Data modules, instrument telemetry, predict-then-measure.
- **Phase 3** — retention/discovery ratchet: gated experiments framed by 28-day player value.

A shipped firebit game (2026) is used throughout as a worked illustration; no step depends on that repo existing.

## When to use / When NOT to use

**Use when:** starting a work session without a specific assigned task; resuming a paused launch push; any task that touches the Testing lane, launch balancing, or retention features.

**Do NOT use for:**
- The rules themselves (what agents may never do, change classes, promotion gates) — that is **roblox-change-control**. This skill only sequences work within those rules.
- General debugging of a novel bug — **roblox-debugging-playbook** / **roblox-failure-archaeology**.
- How to bootstrap the toolchain or fix sourcemap/DevPackages traps — **roblox-build-and-env**.
- Test/scenario/storybook authoring conventions and the evidence bar — **roblox-validation-and-qa**.
- rblxsync/asphalt/deploy mechanics — **roblox-run-and-operate**.

## Before starting: take a situation snapshot

The campaign is only as good as its picture of reality. In the current project repo, build a snapshot before choosing a phase:

```bash
# Board lane counts (each <h2> carries its card count)
grep -A1 'data-status=' docs/BOARD.html | grep '<h2>'
# Open checkboxes across active plans
grep -rn '^- \[ \]' docs/plans/*.md
# Scenario and spec inventory
ls tests/scenarios/
grep -rln 'it(' --include='*.spec.luau' src/
```

Record: what is In Progress, what sits in Testing as "code done, needs playtest", which plans are paused, and any **known-bad tuning state** (debug values left in config — see Phase 2.1). If the verification pipeline (`/roblox-testing:test`, `/roblox-testing:playtest`) has never completed green in this project, everything else is blocked on Phase 0 — bringing the loop online is the highest-leverage act.

Definitions used throughout: **MCP** = Model Context Protocol, the bridge that lets Claude Code drive Roblox Studio (play/stop, run Luau, read console). **Rojo** = the tool that syncs `src/` files into a running Studio place. **DevProduct** = a purchasable Roblox item (consumable, priced in Robux). **Scenario** = a markdown playtest script under `tests/scenarios/` executed by `/roblox-testing:playtest`.

---

## PHASE 0 — Bring the verification pipeline online

Goal: one green `/roblox-testing:test` run and one green `/roblox-testing:playtest smoke` run in the current project. If neither has ever completed end-to-end, the first success is itself the deliverable — close the matching plan boxes when it lands.

### 0.1 Resume recipe (house stack)

```bash
cd <repo root>
npm run build:deps          # wally install + sourcemap + wally-package-types on Packages
wally-package-types --sourcemap sourcemap.json DevPackages   # Packages-only script skips this; Jest linker stubs need it
npm run dev:<place>         # builds the place, opens it in Studio, starts rojo serve (default.project.json)
```

Notes: `rojo serve` with no project argument serves `default.project.json` — the only project tree that mounts `DevPackages` and the `*.spec.luau` files. The opened place is built from the per-place project (which excludes both); the serve session injects them. In Studio: connect the Rojo plugin to the local server. Check `package.json` for the exact `dev:<place>` script names.

### 0.2 Confirm Studio MCP is reachable

The `roblox-testing` plugin (enabled in `.claude/settings.json`) provides the Studio MCP server (`/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP --stdio`). Load and call `list_roblox_studios` (via ToolSearch if not present). **Expect:** at least one Studio instance listed; `set_active_studio` if several.

**If MCP is unreachable →** (a) confirm Studio is actually open with a place; (b) confirm the StudioMCP binary exists at the path above; (c) confirm the plugin is enabled: `grep roblox-testing .claude/settings.json`; (d) historical fallback that worked pre-marketplace-install: relaunch as `claude --plugin-dir ~/.claude/plugins/roblox-testing`. Do not proceed to 0.3 — report and stop, per the command's own preflight.

### 0.3 Run the unit suite — with an expected-output pattern

Run `/roblox-testing:test`. It starts play mode, executes the project's test entry (house convention: `require(game:GetService("ReplicatedStorage").Shared.RunTests)()` — the module lives at `src/Shared/RunTests.luau`), polls console output, stops play, and parses the Jest summary.

**Expected-output pattern:** BEFORE running, derive what the summary must say by counting the project's specs — `grep -rc 'it(' src/**/__tests__/` per suite — and write the expected `Tests: N passed, N total` / `Test Suites: M passed, M total` down. Then compare. Treat any deviation as signal, not noise. (In the originating game the entire suite was one spec with three `it` blocks, so the first-ever green run had a fully predicted summary.)

**Failure branches:**

| You see | Branch to |
|---|---|
| Connection error on any MCP call | Step 0.2 |
| Test-entry module missing / not found | rojo serve not running against `default.project.json`, or Studio not connected to it — step 0.1 |
| Jest `require` errors inside DevPackages / malformed linker stubs | Run the `wally-package-types ... DevPackages` line from 0.1 (the npm script only covers `Packages/`) — details in **roblox-build-and-env** |
| `0 suites, 0 tests found` | `jest.config.luau` testMatch (`**/*.spec`) vs sync tree — confirm a spec file is visible under ReplicatedStorage in Studio's Explorer |
| luau-lsp PostToolUse hook blocks edits on valid new files | `npm run build:sourcemap` (stale sourcemap; see **roblox-build-and-env**) |

### 0.4 Run the smoke scenario

Run `/roblox-testing:playtest smoke` (drives `tests/scenarios/smoke.md`). If the project has no smoke scenario yet, write one first per **roblox-testing:writing-playtest-scenarios**: character spawns; screen capture shows the mounted HUD; basic movement succeeds; optional input steps marked `continue-on-fail`. **Expect assertions:** `LocalPlayer.Character` exists with `Humanoid.Health > 0`; PlayerGui contains the mounted React root; no console script errors. The command never reports PASS on a skipped assertion — hold it to that.

**If the character never spawns →** house convention keeps `Players.CharacterAutoLoads = false`; spawning is owned by a player service via tagged Spawn parts. The opened place must contain them; a fresh place without the tagged parts hangs on spawn (see **roblox-architecture-contract**).

### GATE 0 (must pass before Phase 1)

Both runs green: parsed Jest summary with 0 failed, and smoke scenario overall PASS. Then, same turn: check the matching plan boxes, set `status: done` if complete, archive, and move the board card — mechanics in the project's CLAUDE.md and **roblox-docs-and-writing**; promotion rules in **roblox-change-control**.

---

## PHASE 1 — Clear the Testing lane

Goal: convert every Testing-lane card from "code done" to "verified", using scripted scenarios for everything an agent can verify, and an explicit, fenced hand-off list for what only the owner can do. Write each scenario per **roblox-testing:writing-playtest-scenarios** (conventions in **roblox-validation-and-qa**); use the Setup block for determinism (seed currency, force state via `execute_luau`).

**Global fence:** completing a real Robux purchase — even a Studio "test purchase" dialog — is a human click. Agents verify everything up to and after the receipt by invoking the server-side receipt callback path directly in Setup; the purchase dialog itself, and anything on the live universe, is the owner's. Never run `rblxsync run` (hard rule: validate/`--dry-run` only for agents — canonical in **roblox-change-control**).

**Build the minted-products inventory first.** Board/plan notes saying "needs rblxsync run" go stale: check what is ALREADY minted before assuming a sync is needed:

```bash
grep -n 'Name = ' src/Shared/Data/Monetization/Generated.luau
```

Every product a scenario touches must appear there by exact (case-sensitive) name. In the originating game, the Monetization card's "needs rblxsync run" note was stale — all eleven products and the gamepass were already minted; verifying the generated file avoided a forbidden live sync that would have accomplished nothing.

### The per-card pattern

For each Testing card:

1. **Read its plan** in `docs/plans/` — the plan's own findings often contain the assertions (and the fences: features deliberately cut, adjacent bugs explicitly out of scope).
2. **Write one scenario per card** asserting server-observable behavior, not UI appearance:
   - State-machine payloads carry the right values as state advances (e.g., an escalating price ladder: assert cost 1 → cost 2 → cap, and that the counter resets on the documented reset events).
   - Product resolution is **by name** against the generated monetization file.
   - Setup-invoked receipt callbacks flip the persisted flag / grant the goods; re-claim and unauthorized-claim paths return their documented failure codes.
   - Invariants the plan investigated get pinned as assertions (in the originating game: "inventory survives death" was found true by code-reading — the scenario assertion keeps it true).
   - Currency/eligibility checks: sufficient → subtract + grant; insufficient → refused.
3. **List the owner-only residue explicitly**: real purchase prompts, live-universe checks, multi-account tests (real friendships/social features need two humans), visual sign-off on UI, and any pre-launch rename of test-window identifiers. On that last one — learned in a shipped firebit game, 2026: a season configured with a test id must be renamed to the real id before launch, because renaming forces a profile-keyed progress rollover — deliberate pre-launch, catastrophic post-launch. If your game keys persisted progress on a config identifier, put the rename on the owner list with that warning.
4. **Surface plan-contradicts-reality findings** instead of silently working around them. (Originating-game illustration: a subscription advertised "2× session currency", but the only multiplier chokepoint lived in a flag-gated-off minigame engine — so the advertised benefit had no effect in the main place. That is an owner decision, not an agent fix.)
5. **Extract agent-executable residue** from owner-gated cards: a stochastic helper can get a Jest spec (mean of N samples within tolerance) even when the feature's end-to-end test needs two humans — and it grows the Phase 0 suite.

If subscriptions are involved: they cannot be minted by rblxsync, and — UNVERIFIED (as of 2026-07-05) — may not support Studio test purchases at all; assume the purchase leg is live-only, owner-only.

### GATE 1

A card moves Testing → Done only when its scenario is green **and** its owner-only list is either done or explicitly re-fenced onto a new card. Same-turn plan checkbox + board move per the project's CLAUDE.md; class/gate rules in **roblox-change-control**.

---

## PHASE 2 — Launch balancing re-triage

Goal: replace stale balancing-plan numbers with derivations from current code, instrument, predict, then playtest. If the project has a `docs/plans/` balancing doc, treat its absolute tables as history unless freshly dated — but keep its *structure* (metrics list, playtest matrix, target-survival goal) as the frame unless the owner re-decides.

### 2.1 First: audit tuning configs for debug leftovers

Grep the game's cycle/tuning config modules and `git log -p` their key values. A value that history shows was set for Studio testing (absurdly short cycle length, forced spawn locations, `DEBUG_*` constants left on) invalidates every derived number until restored. Restoring it is reverting a debug leftover, not a tuning call — but per the tuning hard rule still state it, with the git evidence, and get owner confirmation. (Originating-game illustration: the day length had been left at **2 seconds** — history read 180 → 202222 → 2 — so every day-phase balance number was meaningless; a `DEBUG_FORCE_STRUCTURE_CHUNK` constant was also live.)

### 2.2 Re-derive the current curve from the Data modules

The house stack keeps tuning formulas in `src/Shared/Data/` modules. Read the actual formulas (spawn-count curve, active cap, per-stage stat scaling, cycle length, income per source, sink costs) and compute a **worked table**: rows = progression stage (day/night/wave N), columns = spawn totals, caps, income upper bound, key stat scaling. Then compute the income-vs-sink comparison: total cost to max every upgrade ladder vs realistic income per cycle. State every assumption in the table (e.g., "income column assumes the player kills every currency-dropping NPC — an upper bound").

Originating-game illustration (abridged): the formulas produced solo-play rows for nights 1/5/10/35 covering NPC totals, active cap, currency-dropper share, and HP/damage scaling; sinks summed to ~2,100 session currency vs ~8–15 income per night — showing upgrades were intentionally partial per run. **The derivation obligation for any tuning change is a before/after table exactly like this.**

### 2.3 Instrument, predict, then playtest

House pattern: a balance-log service (enabled in the gameplay place) printing an end-of-cycle block (spawned/killed, cap hit + when, defended-object HP start/end, players downed), plus an analytics service emitting death/loss/purchase events carrying a survival-depth field. Interpretation and extension recipes: **roblox-diagnostics-and-tooling**. Do not add counters speculatively — add only what a specific question needs.

Discipline (**roblox-research-methodology** owns the full protocol): before each instrumented run, write down predicted end-of-cycle numbers from your §2.2 table; run; reconcile every mismatch before touching a knob. Matrix: ≥3 solo runs minimum before any tuning conclusion (multiplayer rows when a second human exists).

### 2.4 Solution menu, ranked (each with its derivation obligation)

Build the project's own ranked knob list. The pattern per knob:

1. **Spawn/difficulty curve constants** — obligation: recompute the §2.2 table for the new values and predict time-to-kill + income deltas.
2. **Income knobs** — prefer the single documented tuning knob if the code declares one (grep Data modules for "tuning knob" comments); obligation: income-vs-sink table before/after.
3. **Sink costs** (especially self-declared placeholder ladders) — obligation: state the target ("N cheap tiers affordable per cycle") and show the ladder math.
4. **Monetized pricing (revive/skip ladders)** — do NOT touch anything that just shipped with zero purchase telemetry; revisit only after purchase-complete events exist.

**Fenced wrong paths:** never tune by feel (hard rule: rationale + predicted metric + evidence path, every time); never act on a stale balancing doc's absolute tables (in the originating game the stale doc's composition table omitted an NPC type that had grown to ~45% of early spawns); never nerf free earn rates; never let combined paid multipliers exceed the project's documented accelerator ceiling (house pattern: a `math.min(combined, cap)` clamp — find it before touching multipliers).

### GATE 2

Measurable: instrumented playtest matrix run with predictions reconciled, and either (a) the survival/progression metric lands in the owner's written target band, or (b) a tuning change ships with rationale + prediction + balance-log evidence attached to its plan file.

---

## PHASE 3 — Retention / discovery ratchet

Goal: activate remaining unshipped retention items as **gated experiments**, one at a time, each with a KPI milestone declared before the code.

**28-day player-value framing:** judge every candidate by its predicted effect on the value of a player across their first 28 days — return rate (D1/D7/D28), session length, and progression-depth distribution (from the survival-depth telemetry field) — not by "feels engaging". Declare which of those the experiment moves, by how much, before writing code.

**Status audit first:** if the project has a retention plan doc, verify each item's shipped/not-shipped status against `src/` (grep for the module/flag it specifies) — do not trust the doc's own status column or its flag snapshot; later owner decisions supersede it. The *principles* in such docs (capped paid accelerator, free rates untouched) stand; the state tables do not.

Rules for each experiment: declare the KPI first; ship behind its own FeatureFlag; measure across a comparable window; keep the accelerator ceiling and free earn rates byte-for-byte unchanged. Agents cannot read Creator Hub analytics; KPI actuals come from owner-supplied exports or in-game telemetry only.

### GATE 3 (entry)

Do not start any Phase 3 item until Gate 1 has passed (the scenario suite exists to regression-guard) and the owner has picked the item + KPI target. Sequencing beyond that is an owner call each time — this phase is a menu, not a queue.

---

## PARALLEL TRACK — committed-but-unplaytested quality fixes (after Gate 0)

Pattern: a stack of committed, lint-clean fixes to a runtime-behavior subsystem (NPC movement, physics feel) that has never been playtested gets its own **behavioral scenario with numeric thresholds** — never "looks right". The scenario Setup spawns the minimal case deterministically and samples position/state on a timer via `execute_luau`; assertions bound:

- **Time-to-goal:** reach the target state within `k ×` the straight-line optimum (start with 2× slack).
- **Path efficiency:** total sampled path length ÷ straight-line distance ≤ a fixed ratio (start ~1.5).
- **Stability at goal:** once the goal state is entered, displacement between samples stays within a fixed radius until the next expected event.

Thresholds are first-pass — tighten after the first green run, but never replace them with a visual judgment. Also carry forward the subsystem's fenced known-wrong paths from its plan/history (chronicle in **roblox-failure-archaeology**) so the fix stack is not "improved" back into a paid-for failure mode.

Case study (shipped firebit game, 2026): four stacked NPC-steering fixes sat committed and unplaytested; the gate scenario spawned one NPC 80 studs from the stationary defended object and asserted arrival ≤ 20s, path ratio ≤ 1.5, and ≤ 4-stud drift after engaging. The plan's fences — don't reissue move commands to stationary targets per-frame, don't remove the pathfinding budget (its absence had caused `ComputeAsync` floods and frozen NPCs), don't enable NPC self-collision — were the residue of previously paid-for failures.

---

## Common mistakes

- **Running `rblxsync run`** because a plan/board note says "needs rblxsync run" — verify against `src/Shared/Data/Monetization/Generated.luau` first; such notes go stale. The live run is an owner act (**roblox-change-control**).
- **Pushing to origin main/production** to "share progress" — the boilerplate `deploy.yml` auto-deploys the live game on push.
- Claiming a Phase 0/1 gate passed when the MCP call actually failed or an assertion was skipped — the commands themselves forbid PASS-on-skip; so does **roblox-validation-and-qa**.
- Tuning from a stale balancing doc's tables, or by feel — Phase 2 fences; the tuning hard rule.
- Treating a debug-leftover config value as a design decision and balancing around it.
- "Cleaning up" flag-gated dormant code found while wiring a feature — dormant legacy is gated off deliberately; never refactor or delete it.
- Moving a Testing card to Done with owner-only items silently dropped — re-fence them onto a card instead.
- Batching plan checkboxes/board moves to end-of-session — the project's CLAUDE.md requires same-turn updates.
- Skipping the situation snapshot and executing a remembered version of the board — the working tree and board of the CURRENT project are ground truth.

## Provenance and maintenance

Derived 2026-07-05 from the firebit house-stack reference project: its working tree, `docs/plans/*`, `docs/BOARD.html`, and git history. All originating-game specifics above are illustrations only; every command is written to run against the CURRENT project repo, from its root. Re-verify volatile facts there before acting:

```bash
# Board lane counts (each <h2> carries its card count)
grep -A1 'data-status=' docs/BOARD.html | grep '<h2>'
# Open boxes across active plans
grep -rn '^- \[ \]' docs/plans/*.md
# Minted product/pass/badge names (case-sensitive matching!)
grep -n 'Name = ' src/Shared/Data/Monetization/Generated.luau
# Expected unit-test counts for the Phase 0 prediction
grep -rc 'it(' --include='*.spec.luau' src/
# Scenario inventory
ls tests/scenarios/
# Exact dev-loop script names
grep '"dev:' package.json
# Debug leftovers in tuning configs (then git log -p the hits)
grep -rn 'DEBUG_\|debug' src/Shared/Data/ --include='*.luau' -i | grep -iv 'debugger'
```

UNVERIFIED (as of 2026-07-05, carried from the reference derivation): exact Jest summary formatting (counts were derived by reading specs; predict, then compare); whether Roblox subscriptions support Studio test purchases (assume live-only); whether `execute_luau` can drive receipt callbacks in the play-mode server VM (if Setup-invoked callbacks fail, fall back to calling the service functions the callbacks wrap); derived income tables assume 100% kill/collection rates (upper bounds).

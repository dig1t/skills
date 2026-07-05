---
name: roblox-research-frontier
description: Use when asking what agents should push on next in a house-stack Roblox project, how to remove the owner from verification loops, or what can be automated — autonomous dev pipeline, open problems, scripted playtests replacing manual Studio checks, headless simulation of game math, lune/luau CLI runners, telemetry-predicted balance tuning, spec-coverage ratchet, CI test gates, multi-client/two-account testing, "everything is stuck waiting on a playtest", "what's the frontier here".
---

# Roblox House Stack — Research Frontier: the Autonomous Dev Pipeline

## Overview

Every problem below serves one studio-wide direction: agents shipping verified features end-to-end with near-zero owner time. Everything here is OPEN or CANDIDATE — nothing is shipped; each problem states why current practice fails, what asset the house stack already provides, the first three concrete steps in the current project, and a falsifiable "you have a result when..." milestone.

**The recurring bottleneck:** in house-stack projects, feature work ends code-done with verification owed — cards pile up in the Testing lane of `docs/BOARD.html` blocked on the same gate: a human opening Roblox Studio. Measure it in your project before choosing a problem: open the board, count Testing-lane cards, and check each card's evidence status (evidence bar per **roblox-validation-and-qa**). When all agent-executable work in that lane is exhausted, that gate is the frontier. (Learned in a shipped firebit game, 2026: five features sat simultaneously code-done, all waiting on one manual playtest gate.)

## When to use

- Choosing what to work on when feature work is blocked on owner verification.
- Asked "what are the open problems / research directions / what can be automated?"
- Starting work on scripted playtests, headless sims, telemetry-driven tuning, or test coverage as a project (not a one-off).

## When NOT to use

- Running an existing test or scenario → **roblox-validation-and-qa** (owns the evidence bar and spec/scenario conventions).
- Executing a live-launch decision campaign → **roblox-launch-campaign** (owns the phased campaign; Problem 1 below feeds its Phase 0).
- The hunch→result discipline for any single experiment → **roblox-research-methodology**.
- Deriving a formula or curve by hand → **roblox-proof-and-analysis-toolkit**.
- Anything touching the four hard rules (push, rblxsync run, flag-gated-code deletion, tuning-on-a-guess) → **roblox-change-control** owns their canonical statement; nothing on this frontier overrides them.

---

## Problem 1 — Scripted playtests replacing owner verification gates (OPEN)

**Why current SOTA fails:** agents write and statically verify code, then a human eyeballs it in Studio. Every feature ends in a "needs Studio playtest" checkbox a model cannot check.

**The house stack's asset:**

| Asset | Where (house convention) | How to verify in your project |
| --- | --- | --- |
| Jest Lua runner | `src/Shared/RunTests.luau` (invoke: `require(game:GetService("ReplicatedStorage").Shared.RunTests)()`) | `ls src/Shared/RunTests.luau` |
| `/roblox-testing:test`, `/roblox-testing:playtest` commands | roblox-testing plugin, enabled per-project in `.claude/settings.json` | `grep roblox-testing .claude/settings.json` |
| Scenario format (`tests/scenarios/*.md`: frontmatter + Setup Luau + Steps + `capture:`/`state:`/`console:` Expects) | plugin skill `roblox-testing:writing-playtest-scenarios` | `ls tests/scenarios/` |
| Ready-made subjects | Testing lane, `docs/BOARD.html` | each card is a concrete "replace this exact manual playtest" target |

Pick the softest target first: a feature whose behavior is driven by a plain data module (a cost ladder, a curve table) and whose services expose public server-side seams a Setup block can drive without real purchases or real network peers. Anything that ends in a Robux prompt still needs one manual purchase check, but everything up to the prompt is scriptable. (Case study, shipped firebit game 2026: an escalating revive-cost feature was the softest target — the cost ladder was a data table and the death/revive services exposed `getReviveCount`/`Revive(targetUserId, buyer)` seams, so ladder progression, inventory retention, and respawn placement were all scriptable server-side.)

**First three steps:**
1. Unblock the plugin end-to-end in your project (this is Phase 0 of **roblox-launch-campaign**): `rojo serve default.project.json`, open Studio with the MCP reachable, run `/roblox-testing:test`, and check the corresponding boxes in the project's plan file for the testing setup (create one under `docs/plans/` if none exists).
2. Author `tests/scenarios/<feature>.md` for the softest Testing-lane card (per `roblox-testing:writing-playtest-scenarios`): Setup puts the game in the required state via server Luau, Steps drive the public service seams, Expects assert `state:` values against the data module and invariants (e.g. inventory unchanged).
3. Run `/roblox-testing:playtest <feature>`; paste the dated transcript into that feature's `docs/plans/` file as the evidence path (evidence bar per **roblox-validation-and-qa**).

**You have a result when:** one named Testing-lane card is promoted to Done on scripted evidence the owner accepts *without opening Studio*. Falsified if the owner still re-verifies manually before accepting.

## Problem 2 — Telemetry-predicted balance tuning (OPEN)

**Why current SOTA fails:** game tuning everywhere is tune-and-feel — change a number, play, vibe-check. Hard rule 4 (see **roblox-change-control**) already bans that here: every tuning change needs a stated rationale, predicted metric, and evidence path. This problem builds the machine that makes rule 4 cheap.

**The house stack's asset (pattern, not a package):** two services you build once per project over signals that already exist —
- A **round-summary logger**: subscribes to the game-loop lifecycle signals your services already fire (round/wave started and ended, NPC spawned/died, defended-object HP sampled, player downed) and prints one structured summary block per round to the console. Keep it behind a file-local `ENABLED` toggle. (Case study, shipped firebit game 2026: `BalanceLogService` summarized per night — NPCs spawned/killed, spawn-cap hit time, defended-object HP start/end, players downed — entirely from pre-existing service signals; no gameplay code changed.)
- A **live analytics emitter** for the few decision-driving events (player death with progress value, defended-object destroyed, purchase completed) via your analytics package.
- The prediction side needs a **pure difficulty/economy data module** — the curve as plain Luau functions with zero `require` and zero Roblox API calls, so it is derivable on paper. Derivation recipes: **roblox-proof-and-analysis-toolkit**.

**First three steps:**
1. Derive the predicted early-game curve (NPCs spawned per round, expected cap-hit round, expected session-currency income) from the project's pure data modules, by hand or by sim (Problem 3).
2. Write the prediction *with a tolerance* into a dated note in the relevant plan file BEFORE any playtest — prediction-first is the falsifiability mechanism (**roblox-research-methodology**).
3. Run one playtest (owner or scripted via Problem 1), capture the round-summary blocks from console output, and diff observed vs predicted.

**You have a result when:** a predicted survival/economy curve matches an observed playtest log within the tolerance you stated before the run (e.g. "NPCs spawned per round within ±20% for rounds 1–5"). A miss outside tolerance is also a result — it localizes a wrong formula assumption.

## Problem 3 — Headless simulation of pure game math (CANDIDATE)

**Why current SOTA fails:** on Roblox, "run the code" means "open Studio" — even for pure arithmetic. Iteration on economy/difficulty math is gated on a GUI app.

**The house stack's asset:** genuinely pure modules — zero `require`, zero Roblox API calls — individually loadable by file path. Find yours: `grep -cE "require\(|GetService" <candidate>.luau` (expect 0), then also grep for Roblox datatypes (`Vector3|Color3|Instance|CFrame`) — many data modules use them and are NOT candidates. Typical pure candidates in a house project: a seeded PRNG module, an XP/level curve, the wave/difficulty curve. (The originating game's were `Rng.luau` — deterministic xorshift32 on `bit32` only — `Level.luau`, and `WaveData.luau`.)

**CANDIDATE runner — lune. Nothing in the house stack runs headless today (as of 2026-07-05):** the reference project's `aftman.toml` lists no `lune` and no `luau` CLI. Getting a runner means adding e.g. `lune = "lune-org/lune@<version>"` to `aftman.toml` + `aftman install` — a dev-tooling change; the commit stays local (hard rule 1). Whether lune's `require` loads house modules unmodified is UNVERIFIED (as of 2026-07-05) — expected to work for modules that touch no Roblox globals, but prove it before claiming it.

**First three steps:**
1. Propose adding `lune = "lune-org/lune@<version>"` to `aftman.toml` and get the owner's go-ahead first (the project's CLAUDE.md: ask before adding a tool/library not already referenced in the project); then `aftman install` and smoke-test: a 5-line script in the scratchpad that requires the PRNG module by path and prints 10 seeded values (determinism check: same seed twice → identical stream).
2. Write an economy sim script (propose `scripts/sim/<loop>-economy.luau` — new file, plan first per the project's CLAUDE.md workflow): loop the early rounds over the pure curve functions × a kill-rate assumption × per-kill reward + level-up rewards. Trap: reward constants often live in *server services*, not pure modules — copy each constant into the sim with a provenance comment (file + symbol) rather than requiring the service.
3. Calibrate against reality: run one instrumented playtest (Problem 2's log) and fit the sim's free parameters (kill rate, pickup rate).

**You have a result when:** the sim's per-round currency output matches a real playtest log within a stated tolerance, seeded identically. Falsified if the sim needs per-round fudge factors to agree.

## Problem 4 — Spec-coverage ratchet on pure modules (OPEN)

**Why current SOTA fails:** agent-written code with no executable spec regresses silently; "the agent read the diff" is not a gate.

**The house stack's asset:** Jest Lua fully wired by convention — `wally.toml` dev-deps (`jsdotlua/jest` + `jest-globals`) → `DevPackages`, `src/Shared/jest.config.luau` with `testMatch = { "**/*.spec" }`, specs colocated in `__tests__/<Module>.spec.luau`, and specs excluded from production builds via `globIgnorePaths: ["**/*.spec.luau"]` in the per-place build projects. Count your project's specs: `find src -name "*.spec.luau"` — expect the number to be embarrassingly low; that is the ratchet's starting point. The pure-module hit list and purity classification are owned by **roblox-validation-and-qa** — beware modules that look pure but yield (e.g. anything calling MarketplaceService for a price). DevPackages type-stub trap: **roblox-build-and-env**.

**The gate gap:** the boilerplate `.github/workflows/` set (deploy/docs/format/linter/release/version-updater) ships NO test job — check yours with `ls .github/workflows/`. Adding one touches the deploy pipeline and CI config → owner-gated (**roblox-change-control**; hard rule 1 keeps it unpushable anyway). The interim gate is procedural, not CI.

**First three steps:**
1. Pick the next module from the project's hit list (**roblox-validation-and-qa**); write a colocated `src/.../__tests__/<Module>.spec.luau` per `roblox-testing:writing-roblox-tests`. A deterministic PRNG or curve module is ideal first (determinism + range assertions, no mocks).
2. Run it: `/roblox-testing:test` (requires Problem 1's Phase 0 unblocked), or headless once Problem 3 lands.
3. Ratchet: record the specced-module count in the plan file each time it rises; draft (do not merge) a CI test-job proposal for the owner.

**You have a result when:** N ≥ 5 pure modules have specs AND a gate exists that goes red on a deliberately broken module (prove it by breaking one locally and watching the run fail, then reverting). Coverage without a demonstrated-red gate is not a result.

## Problem 5 — Autonomous multi-client testing (OPEN, hardest)

**Why current SOTA fails / the blocker:** the MCP setup drives one Studio instance; social features (friend bonuses, trading, party mechanics) need two or more *befriended* players. (Case study, shipped firebit game 2026: a friend-bonus feature's plan sat paused with one unchecked box — "needs a human with a friend account — cannot be run by the agent." Code was verified statically only.)

**Why it's genuinely hard:** house social features typically gate on `otherPlayer:IsFriendsWith(player.UserId)`. Whether Studio multi-client test players ("Player1"/"Player2") satisfy `IsFriendsWith` is UNVERIFIED (as of 2026-07-05) — this single boolean decides the whole approach. The roblox-testing plugin's MCP surface lists `list_roblox_studios` / `set_active_studio` / `playtest_subagent` tools, suggesting multiple Studio instances are addressable, but that capability has never been exercised in a house project (UNVERIFIED).

**First three steps:**
1. Discriminating experiment: start a Studio multi-client test (Test tab → 2 players), run in the server console: `for _, a in game.Players:GetPlayers() do for _, b in game.Players:GetPlayers() do if a ~= b then print(a.Name, b.Name, a:IsFriendsWith(b.UserId)) end end end`. Record the answer in the plan file.
2. If `false` (likely): the honest options are (a) a flag-gated Studio-only test seam that treats test clients as friends — a code change through **roblox-change-control**, with the seam provably dead in production, or (b) accept that this gate needs a live second account = owner act. Write the decision down; do not silently stub.
3. Probe the MCP multi-instance surface: with two Studio windows open, call `list_roblox_studios` and document what `set_active_studio` can actually drive.

**You have a result when:** a social-feature verify box is checked on evidence produced without a second human — a two-client run where the friend-gated behavior demonstrably fires — OR a documented negative: proof that Studio test clients can never satisfy `IsFriendsWith`, with the plan's verify criterion rewritten accordingly. The negative result counts; it kills a dead-end option permanently for every house project.

## Common mistakes

- **Declaring a milestone met because code exists.** Assets sit "built" for days while their e2e boxes stay unchecked. Code done ≠ verified (**roblox-validation-and-qa**).
- **Routing around the hard rules to unblock a problem** — minting test products with `rblxsync run`, pushing a CI experiment to main, or "temporarily" deleting flag-gated code that trips a spec. All four rules bind research work too (**roblox-change-control**).
- **Tuning numbers while building the measurement loop** (Problem 2). Build the loop on current values; tune only after it works, with rule-4 paperwork.
- **Claiming lune/headless works from this doc.** It is labeled CANDIDATE because nothing headless has ever run in a house project. Install, run, then claim.
- **Scenarios that pass vacuously.** The plugin's own rule: never PASS on skipped assertions. A scenario that can't fail is not evidence.
- **Working these problems without the plan lifecycle.** Each problem's steps are non-trivial work — plan file first, `status: active`, boxes checked in-turn (the project's CLAUDE.md owns the workflow).

## Provenance and maintenance

Derived 2026-07-05 from the firebit house-stack reference project. House-convention paths and wiring (RunTests, jest.config, globIgnorePaths, scenario format, workflow set) were verified there on that date; no instruction depends on that repo existing. Re-verify volatile facts against the CURRENT project:

| Fact | Re-verify with (in the current project repo) |
| --- | --- |
| Testing-lane backlog | open `docs/BOARD.html`, Testing lane |
| Testing-plugin e2e status | `grep -n "\[ \]" docs/plans/*.md` (find the testing-setup plan) |
| Spec count | `find src -name "*.spec.luau"` |
| Scenario count | `ls tests/scenarios/` |
| Headless runner present? | `grep -n "lune\|luau " aftman.toml` |
| CI test job present? | `ls .github/workflows/` |
| Round-summary logger present/on | `grep -rn "local ENABLED" src/Server` (telemetry/balance services) |
| Candidate module purity | `grep -cE "require\(|GetService" <module>.luau` (expect 0), then grep `Vector3\|Color3\|Instance\|CFrame` |
| Friend-check mechanism | `grep -rn "IsFriendsWith" src/` |
| Jest wiring | `grep -n "jest" wally.toml; grep -n "testMatch" src/Shared/jest.config.luau; grep -n "globIgnorePaths" *.project.json` |

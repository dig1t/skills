---
name: roblox-validation-and-qa
description: Use when deciding whether a change in a Roblox project counts as tested, verified, or done, before claiming PASS or "works", when writing or running Jest Lua unit specs (*.spec.luau), adding a tests/scenarios/*.md playtest scenario, adding a UI Labs storybook story, moving a board card into or out of the Testing lane, or when asked "what evidence does feature X have?" / "is Y playtested?" / "what's untested?". Also covers the DevPackages test-dependency traps.
---

# Roblox Validation And Qa

## Overview

Every claim about a change must name the rung of the evidence ladder it actually reached, backed by output produced in the current session. "Code done" and "verified" are different states — the board's Testing lane exists precisely for the gap between them. This skill applies to any project on the house stack (Rojo + Wally + Jest Lua via DevPackages + the roblox-testing plugin + UI Labs).

## When to use / When NOT to use

Use this skill when:

- You are about to claim a change works, passes, or is done.
- You are writing or running unit tests, playtest scenarios, or UI stories.
- You need to know which shipped features are actually playtested vs merely code-complete.

Do NOT use this skill for:

- What is allowed to change and who signs off → **roblox-change-control** (it owns the four hard rules; note rule 2: never run `rblxsync run` against the live universe to "verify" a product exists).
- Diagnosing why something is broken → **roblox-debugging-playbook** (triage) and **superpowers:systematic-debugging**.
- Measurement/profiling tools → **roblox-diagnostics-and-tooling**.
- Build/bootstrap problems (wally, sourcemap, rojo serve) → **roblox-build-and-env** (it owns the canonical bootstrap; only test-specific traps are restated here).
- Deep playtest-scenario file format → plugin skill **roblox-testing:writing-playtest-scenarios**.
- Deep UI Labs story format/controls → plugin skill **install-ui-labs:writing-ui-labs-stories**.
- What "good evidence for a tuning change" means economically → **roblox-proof-and-analysis-toolkit** and hard rule 4 in **roblox-change-control**.

## The evidence ladder

Weakest to strongest. Every completed change should state its rung explicitly (in the plan file note and the board card text).

| Rung | Evidence | How to produce it |
|---|---|---|
| 1 | Types clean | `luau-lsp analyze` — runs automatically per edited file via the PostToolUse hook `scripts/luau-analyze-hook.sh`; manual full form below |
| 2 | Lint + format clean | `selene src` and `stylua --check src` (tools installed by Aftman per `aftman.toml`; no npm script wraps them) |
| 3 | Jest spec passing | `/roblox-testing:test` slash command (Studio + rojo serve required, see "Running unit tests") |
| 4 | Scripted playtest scenario passing | `/roblox-testing:playtest <scenario>` against `tests/scenarios/<name>.md` |
| 5 | Owner Studio playtest | A human plays the flow in Roblox Studio and reports the result |
| 6 | Live playtest, 2 accounts | Two real accounts in a live server — required for friend/social features (agents cannot do this) |

Manual rung-1 command (mirrors the hook; run from the project repo root, needs `sourcemap.json` + `globalTypes.d.luau` present — see **roblox-build-and-env**):

```bash
luau-lsp analyze --defs=globalTypes.d.luau --sourcemap=sourcemap.json \
  --no-strict-dm-types --ignore="Packages/**" \
  --ignore="*.spec.lua" --ignore="*.spec.luau" <file-or-dir>
```

Rules that make the ladder honest (the project's CLAUDE.md honesty rules own the general form — this is the QA application):

- Never claim PASS without run output from **this session**. A green run last week is a historical fact, not current evidence.
- A rung only counts if the run exercised the change. A passing smoke test does not verify a purchase flow.
- Rungs 1–2 catch syntax/type/style problems only. They say nothing about behavior.
- UI Labs storybooks are NOT a rung. They are a visual review aid with no assertions.
- If you cannot reach the rung a change needs (usually 5 or 6), say so, leave the plan box unchecked, and put/keep the card in the board's **Testing** lane. Board convention (docs/BOARD.html): "Testing = code done, needs a Studio playtest or rblxsync run to verify."

## Unit tests: Jest Lua

House-stack wiring (verified against the reference repo 2026-07-05; re-verify in your project with the commands in Provenance):

| Fact | Value |
|---|---|
| Framework | Jest Lua (jsdotlua port of Jest) 3.10.0 |
| Declared in | `wally.toml` `[dev-dependencies]`: `Jest = "jsdotlua/jest@3.10.0"`, `JestGlobals = "jsdotlua/jest-globals@3.10.0"` |
| Installed to | `DevPackages/` (git-ignored; created by `wally install`, which `npm run build:deps` runs) |
| Synced by | `default.project.json` only — it mounts `DevPackages` under ReplicatedStorage. ("Rojo project" = the JSON file mapping filesystem to the Roblox instance tree.) |
| Excluded from production | The per-place build projects (e.g. `level.project.json`, `lobby.project.json`) set `"globIgnorePaths": ["**/*.spec.luau"]` and do not mount DevPackages — built places carry no tests or test deps |
| Config | `src/Shared/jest.config.luau` → `{ testMatch = { "**/*.spec" } }` |
| Entrypoint | `src/Shared/RunTests.luau` — a ModuleScript returning a function; invoke with `require(game:GetService("ReplicatedStorage").Shared.RunTests)()`. Always ends with `Jest run complete` when the run finishes — a resolved run with failing tests prints `Jest run FAILED: one or more tests did not pass` first, then `Jest run complete`; only a rejected Jest promise prints `Jest run FAILED: <err>` with no completion line. Judge pass/fail from the `Tests: X failed, Y passed, Z total` summary or a FAILED line, never from the presence of `Jest run complete`. Never required by runtime code. |
| Spec convention | Colocate in `__tests__/` next to the module: `src/.../__tests__/<Module>.spec.luau` |

### Adding a spec — checklist

Use an existing spec in the project as the template (find one: `find src -name "*.spec.luau"`). The canonical shape:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

local Smoothstep = require(script.Parent.Parent.Smoothstep)

describe("Smoothstep", function()
	it("returns 0 at t = 0", function()
		expect(Smoothstep(0)).toBe(0)
	end)
end)
```

- [ ] Create `__tests__/<Module>.spec.luau` next to the module; require the module via `script.Parent.Parent.<Module>`.
- [ ] Ensure DevPackages exists: `npm run build:deps` (runs `wally install` + sourcemap). If DevPackages was freshly installed, also run the types pass that NO npm script covers: `wally-package-types --sourcemap sourcemap.json DevPackages` — `build:sourcemap` only runs `wally-package-types` on `Packages`, so DevPackages linker stubs stay untyped without this (verified in the reference repo's `package.json`; check yours the same way).
- [ ] Regenerate the sourcemap after creating the file: `npm run build:sourcemap`. The luau-lsp hook analyzes against a static `sourcemap.json`; a new file that isn't in it makes the hook fail on valid code (see **roblox-build-and-env**).
- [ ] Note the hook itself skips `*.spec.luau` (its `--ignore` flags) — your spec is not type-checked by the hook; keep it strict-clean anyway (`.luaurc` sets strict mode repo-wide).
- [ ] Run the suite (next section) and paste the pass/fail line into the plan file.

### Picking spec targets — the triage pattern

Sort candidate modules into three buckets before writing anything:

1. **Pure/deterministic — test today, zero mocks.** Data-in/data-out functions: math (XP/level curves, interpolation), seeded RNG streams, placement/geometry computed from plain inputs, threshold-to-text mappings. Highest value: pure modules whose regressions corrupt player-facing state silently (progression math, deterministic generation where same-seed-same-stream is a load-bearing invariant).
2. **Needs mocks — lower priority, do NOT unit-test naively.** Anything that calls a yielding web API or connects player signals at module load. Learned in a shipped firebit game, 2026: a shared price-adjustment module called `MarketplaceService:GetUsersPriceLevelsAsync` (a yielding web call) and connected `Players.PlayerRemoving` at module load — a naive spec yields on a web call inside the test run. Defer these until a mocking approach exists in the project.
3. **Services — integration-shaped, not Jest targets.** `*Service.luau` files hit DataStores/Replica/players; verify them via scenarios (rung 4) or playtests (rung 5), not Jest, until a service-harness pattern exists.

Measure your project's coverage gap directly (see Provenance) rather than assuming — on the house stack, expect services to be untested by Jest by design.

## Running unit tests: /roblox-testing:test

Prerequisites: Roblox Studio open with a place connected to `rojo serve` (no project argument = serves `default.project.json` — the only tree that mounts DevPackages and specs), and the Studio MCP server reachable. Then run the slash command `/roblox-testing:test`. It starts play mode, executes the `RunTests` require, polls console output for the completion line, stops play, and reports the `Tests: X failed, Y passed, Z total` summary.

Hard rules:

- **Never report PASS on 0 tests.** If `testMatch` matched nothing (wrong filename, spec not synced, sourcemap stale), a run with zero tests is a failure of the run, not a pass.
- If `/test` or `/playtest` has never completed end-to-end in the current project, say so before relying on it — a statically-verified pipeline is not a proven one. Record the first successful end-to-end run in the relevant plan file.

## Playtest scenarios (rung 4)

Scenarios live in `tests/scenarios/*.md` and are executed by `/roblox-testing:playtest <name>`. Every project should carry at least a `smoke.md` (spawn, HUD visible, basic movement/inputs, no console errors) — use it as the format example:

- YAML frontmatter: `name`, optional `timeout` (seconds, default per-step timeout), optional `place`.
- Optional `## Setup` Luau block for determinism (seed currency, teleport, force a game phase).
- `## Steps`: numbered natural language; append `(continue-on-fail)` to non-critical steps.
- `## Expect`: one assertion per line with a prefix — `capture:` (screenshot judgment), `state:` (instance-tree fact, e.g. `LocalPlayer.Character exists with Humanoid.Health > 0`), `console:` (log expectation, e.g. `no script errors`).

Deep format rules, naming, and setup-block idioms are owned by **roblox-testing:writing-playtest-scenarios** — read it before writing a new scenario.

**Scenario-first bug workflow:** when a reproducible bug is reported, write the scenario FIRST, confirm it fails, fix the code, confirm it passes, and keep the scenario as a permanent regression test. `tests/scenarios/` is not in any Rojo tree, so scenarios cost nothing in the shipped game.

## Storybooks (UI Labs)

Format is **UI Labs**, NOT Flipbook. House conventions:

- Storybook root: `src/Client/Test/init.storybook.luau` → `{ name = "firebit", storyRoots = { script.Parent:WaitForChild("Storybooks") } }`.
- Stories live in `src/Client/Test/Storybooks/*.story.luau`.
- Story shape: module returns `{ react = React, reactRoblox = ReactRoblox, summary, controls, story = function(props) ... end }` with `type Props = { controls: typeof(controls) }`. Use an existing `*.story.luau` in the project as the template. (Flipbook's storybook-level `packages` table is gone — do not reintroduce it.)
- Scope: leaf presentational components only. Overlays/portals are not storyable — learned in a shipped firebit game, 2026: the root overlay transitively required Workspace contents at module load, which the storybook environment does not have.
- Run inside Studio via the UI Labs plugin; there is no CLI runner.

Deep format detail is owned by **install-ui-labs:writing-ui-labs-stories**. Remember: a story is a review aid, not evidence — it never moves a change up the ladder.

## Certified inventory — the pattern

Every project maintains a certified inventory: a table of shipped/in-flight features vs the evidence rung each has actually reached, with the gate still to clear. The board's Testing lane (docs/BOARD.html) holds the "code done, NOT playtested" rows; the Done lane implies rung 5+ was reached. Format:

| Feature | Plan | Config / minted IDs | Rung reached | Gate to clear |
|---|---|---|---|---|
| Premium pass purchase flow | `docs/plans/<plan>.md` | Dev products present in `src/Shared/Data/Monetization/Generated.luau` | 3 (specs pass) | Rung 5: Studio playtest — layout, claim flow, purchase |
| Friend/social bonus | `docs/plans/<plan>.md` | Flag-driven, no products | 4 (scenario passes) | Rung 6: two human accounts — cannot be run by an agent |
| Session currency migration | `docs/plans/<plan>.md` | — | 5 | Done — record the playtest date in the plan |

Rules for maintaining it:

- Build the Testing-lane view from the board, not from memory: read `docs/BOARD.html` and the matching `docs/plans/*.md` files.
- For monetization rows, product/pass/badge ground truth is the checked-in `src/Shared/Data/Monetization/Generated.luau` and `rblxsync-lock.yml` — read the working tree, not git HEAD (pending changes may be uncommitted). Numeric IDs and flag values are project state: see **roblox-config-and-flags** for how each project catalogs them.
- Features gated on rung 5/6 are human-gated: the only agent-executable work is building rung-3/4 evidence underneath them.
- Board lanes and plan checkboxes can drift apart (learned in a shipped firebit game, 2026: several Done-lane features still had unchecked plan boxes). Treat disagreement as a bug; the fresher artifact wins while you fix the stale one — doc-debt handling is owned by **roblox-docs-and-writing**.

## Common mistakes

- Claiming PASS from memory or from a previous session's run. Evidence expires when the code changes; runs must come from this session.
- Reporting `/test` success when zero tests ran.
- Treating "types clean + selene clean" as verification of behavior. Rungs 1–2 gate merges, they don't verify features.
- Marking a Testing-lane card done, or checking a plan's playtest box, on the strength of static code reading.
- Running `rblxsync run` to "verify" product IDs — forbidden (hard rule 2, **roblox-change-control**). Read `src/Shared/Data/Monetization/Generated.luau` and `rblxsync-lock.yml` instead; both are checked-in ground truth — and read the working tree, not git HEAD, since recent monetization edits may be uncommitted.
- Requiring `RunTests`, `DevPackages`, or anything under `__tests__/` from runtime code — production builds strip all of it (`globIgnorePaths`), so the built place will error.
- Creating a spec and skipping `npm run build:sourcemap` — the luau-lsp hook then fails on the next edit.
- Forgetting the manual `wally-package-types --sourcemap sourcemap.json DevPackages` pass after a fresh `wally install`.
- Writing stories for overlays/portals, or citing a storybook as test evidence.
- Unit-testing a module that yields on a web API (e.g. a MarketplaceService call) without mocking it — the spec will yield mid-run.

## Provenance and maintenance

Derived 2026-07-05 from the firebit house-stack reference project, by direct reads of its working tree. All commands and paths are house conventions; re-verify them against the CURRENT project before relying on them:

```bash
# Jest wiring + spec count
grep -n -A3 "dev-dependencies" wally.toml
grep -n "testMatch" src/Shared/jest.config.luau
find src -name "*.spec.luau"

# Production exclusion + DevPackages mount (adjust per-place project names)
grep -n "globIgnorePaths" *.project.json
grep -n "DevPackages" default.project.json

# Coverage gap
find src/Server -name "*Service.luau" | wc -l
ls src/Shared/Modules | grep -c ".luau$"

# Scenarios + storybooks
ls tests/scenarios/
ls src/Client/Test/Storybooks/ | wc -l

# Certified-inventory inputs: board Testing lane + monetization ground truth
sed -n '/data-status="testing"/,/data-status="up-next"/p' docs/BOARD.html
grep -n "Name = " src/Shared/Data/Monetization/Generated.luau
```

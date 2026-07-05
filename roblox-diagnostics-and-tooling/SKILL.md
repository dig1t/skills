---
name: roblox-diagnostics-and-tooling
description: Use when you need numbers instead of guesses in a house-stack Roblox project — balance/tuning telemetry (session-summary console logs, analytics events), repo-wide luau-lsp/selene/stylua commands and what counts as a regression, reading the Studio console via MCP during a playtest, checking which DEBUG/feature flags are live, detecting stale plan files, or questions like "how many type errors do we have", "is any debug flag still on", "which plans are done but not archived".
---

# Roblox House Stack — Diagnostics and Tooling

## Overview

Every claim about a game's behavior should come from an instrument, not an impression: telemetry signals, analyzer counts, console captures, or one of the shipped scripts below. This skill catalogs each measurement instrument the house stack provides, the exact command to run it, and how to interpret what it prints. Commands are repo-root-relative and run in the current project repo.

## When to use

- You need evidence for a balance/tuning discussion (spawn vs kill counts, cap hits, HP loss per cycle, deaths).
- You want the repo-wide type/lint/format status, or to know whether your change regressed it.
- You need to read the running game's console or screen from a Claude session.
- You want a one-command view of every feature flag, debug toggle, or stale plan file.

## When NOT to use

| Situation | Use instead |
| --- | --- |
| Deciding whether a change counts as "tested"/"done", or writing Jest specs / playtest scenarios / stories | **roblox-validation-and-qa** |
| A bug to triage (symptom → experiment) | **roblox-debugging-playbook** |
| The luau-lsp hook blocked your edit, sourcemap is stale, tools missing | **roblox-build-and-env** |
| Whether you're allowed to change a tuning number at all | **roblox-change-control** (hard rule: tuning changes need rationale + predicted metric + evidence path) |
| What a flag *means* or how to add one | **roblox-config-and-flags** |
| Frame-rate / memory deep dives (MicroProfiler, memory tags) | skill **roblox-performance** |
| Runtime breakpoints, stepping, live variable inspection | plugin skill **roblox-debugging** |
| Acting on what the telemetry tells you (launch decisions) | **roblox-launch-campaign** |

## Choosing an instrument

| Question | Instrument |
| --- | --- |
| "Was that gameplay cycle too hard/easy?" | session-summary telemetry service (console block, §1) |
| "How do live players fail / when do they churn?" | analytics event service (Roblox Analytics + GameAnalytics dashboards, §1) |
| "Did my edit break types anywhere else?" | `scripts/analyze-all.sh` (this skill) |
| "Is a debug flag or forced-state hack still live?" | `scripts/flags-report.sh` (this skill) |
| "Which plans are finished but never closed out?" | `scripts/plan-board-drift.sh` (this skill) |
| "Does the game boot and the HUD render?" | `/roblox-testing:playtest smoke` (mechanics in **roblox-validation-and-qa**) |
| "Do the unit tests pass?" | `/roblox-testing:test` (mechanics in **roblox-validation-and-qa**) |
| "What did the server print at second 40?" | MCP `console_output` during a Studio session (§3) |

## 1. Balance telemetry (the evidence source for tuning)

House pattern: telemetry services live in `src/Server/Features/Telemetry/` and are gated to the gameplay place — they check an environment/place predicate (typically driven by a StringValue that the per-place `*.project.json` sets) and no-op elsewhere. **A lobby playtest produces zero balance telemetry.** There are two kinds of instrument; find your project's concrete services with:

```bash
ls src/Server/Features/Telemetry/ 2>/dev/null
grep -rn "Signal\|Subscribe\|:Connect" src/Server/Features/Telemetry/ --include="*.luau" | head -30
```

### Session-summary logger — per-cycle console block (Studio playtests)

Pattern: a service with a top-level `local ENABLED: boolean` toggle that subscribes to gameplay signals (cycle started/ended, NPC spawned/died, spawn-cap hit, player downed), accumulates counters across one gameplay cycle, and prints a single summary block at cycle end. **Nothing is persisted; the console print IS the output.** Search the console for the service's log prefix (e.g. `[BalanceLog]`).

To build the signal-wiring table for your project (which signals it subscribes to, where each is defined), grep the service for signal names and confirm each against the source service:

```bash
grep -n "= Signal" src/Server/Features/**/*.luau   # where signals are defined
grep -n "Connect\|Subscribe" src/Server/Features/Telemetry/*.luau
```

How to read it during a playtest: Studio's Output window, or from a Claude session via the MCP console tool (§3) after each cycle end. Generic interpretation heuristics:

- spawned − killed growing cycle-over-cycle = players falling behind the difficulty curve;
- spawn cap hit early in the cycle = spawn pressure is throttled and the intended difficulty isn't being delivered;
- defended-object HP delta per cycle is a primary difficulty signal.

One cycle is an anecdote — capture every cycle of a full run before proposing a tuning change (and even then, the change itself is gated by **roblox-change-control** hard rule: rationale + predicted metric + evidence path).

Case study (shipped firebit game, 2026): the night-summary block printed duration, zombies spawned/killed, whether the active-cap was hit and when, RV HP start/end, and players downed — five lines that turned "night 3 felt hard" into "night 3: 41 spawned, 38 killed, cap hit at +51s, RV lost 230 HP". Also learned there: the telemetry docstrings cited a docs path that had moved — verify any doc path a docstring cites before trusting it.

### Analytics event service — post-launch events (live servers)

Pattern: a second service, gated only by the place predicate (no toggle), that emits design events via the `Analytics` wally package (`lfg-studio/analytics` — check `wally.toml` for the pinned version). Verified in the reference repo: `Analytics.logPlayerEvent` writes to **both** sinks — Roblox `AnalyticsService:LogCustomEvent` (read in Creator Hub → Analytics → Custom Events) and GameAnalytics `addDesignEvent` (read on the GameAnalytics dashboard). Re-verify the dual sink in your project's pinned copy:

```bash
grep -rn "LogCustomEvent\|addDesignEvent" Packages/_Index/lfg-studio_analytics*/analytics/src/init.luau
```

The layer is initialized by `src/Server/Features/Core/AnalyticsService.luau` (`Analytics.start` with the GameAnalytics gameKey/secretKey hardcoded in that file — don't copy them elsewhere). The build tag is `version.txt` plus a `-dev` suffix whenever `game.GameId` differs from the live experience ID recorded in the project's game data — so dev/Studio events are separable from live data by build. To list which events your project emits and what value they carry:

```bash
grep -n "event = \|logPlayerEvent" src/Server/Features/Telemetry/*.luau
```

Case study (shipped firebit game, 2026): three events — player death, defended-object destroyed (logged once per connected player), and paid-revive completed — each carrying days-survived as the value. UNVERIFIED at the time: nobody had opened either dashboard to confirm events were arriving; the emission path was verified in code only. Do that dashboard check in your own project before citing live numbers.

## 2. Static analysis — exact commands and the regression bar

All tools come from `aftman.toml` (in the reference repo: luau-lsp 1.63.0, selene 0.29.0, stylua 2.3.1 — check your project's `aftman.toml` for its pins); run `aftman install` if missing. Run everything from the repo root.

### Type check (the one that matters)

```bash
.claude/skills/roblox-diagnostics-and-tooling/scripts/analyze-all.sh          # src/ (default)
.claude/skills/roblox-diagnostics-and-tooling/scripts/analyze-all.sh src/Server
```

which is equivalent to:

```bash
luau-lsp analyze \
  --defs=globalTypes.d.luau \
  --sourcemap=sourcemap.json \
  --no-strict-dm-types \
  --ignore="Packages/**" \
  --ignore="DevPackages/**" \
  --ignore="*.spec.lua" \
  --ignore="*.spec.luau" \
  src/
```

This is the same flag set as the per-file PostToolUse hook (`scripts/luau-analyze-hook.sh` in the house boilerplate) **plus** `--ignore="DevPackages/**"`: without it, directory-wide runs drown in dozens of Jest-internal type errors from `DevPackages/_Index/jsdotlua_jest-core...`. The script also dedupes luau-lsp's habit of printing some diagnostics twice (once with a `[game/...]` DataModel path, once relative) and, unlike the hook, fails loudly when `sourcemap.json` / `globalTypes.d.luau` are missing (the hook silently exits 0 — see **roblox-build-and-env** for the sourcemap traps).

**Interpretation / regression bar.** The intended baseline is zero diagnostics. If your project carries known debt, the baseline is a *recorded list*: run the script, save its output, and treat **any diagnostic not in that list** as a regression to fix before moving on. The per-file hook will block you on edited files anyway, but new-file and cross-file breakage only shows up in the directory-wide run. Establish/refresh your baseline:

```bash
.claude/skills/roblox-diagnostics-and-tooling/scripts/analyze-all.sh | tee /tmp/luau-baseline.txt
```

Case study (shipped firebit game, 2026): a dedicated type-cleanup pass took src/ from 80 luau-lsp errors to 0; the working tree later carried 5 known diagnostics (a DevPackages typing gap, one open type-debt pair, two DeprecatedApi warnings). The team's rule was exactly the above: those 5 are the list; a 6th is a regression.

### Lint

```bash
selene src
```

Config: `selene.toml` (house convention: `std = "seleneCustom+roblox"`, excludes `build.luau`, `test/**/*`, `*.d.luau` — verify with `cat selene.toml`). Record your project's current error/warning counts the same way as the type baseline (`selene src 2>&1 | tail -4`); the regression bar is: don't add to them.

### Format

```bash
stylua --check src          # report only
stylua path/to/File.luau    # format ONLY files you touched
```

If `stylua --check src` reports non-conforming files you didn't touch, the codebase is not stylua-clean — **never run `stylua src` repo-wide** in that state: it would produce a mass diff unrelated to your task (the project CLAUDE.md's surgical-changes rule). Use `--check` to see whether *your* files conform, and format only those. Case study (shipped firebit game, 2026): 114 files failed `--check`; a repo-wide format would have buried any real change in a 114-file diff.

## 3. Studio-side measurement (MCP)

When Roblox Studio is open with the MCP server connected, a Claude session can measure the running game directly. The core tools (names as documented in the roblox-testing plugin; they may arrive namespaced, e.g. `mcp__roblox-studio__start_stop_play` — discover the exact names with ToolSearch):

| Tool | Measurement use |
| --- | --- |
| `console_output` | capture server/client logs — this is how you read session-summary blocks, error spam, or your own probe prints without eyeballing the Output window |
| `screen_capture` | visual evidence: UI layout, HUD state, entity positions |
| `execute_luau` | run a probe expression in the live DataModel (e.g. count `CollectionService:GetTagged(...)`, read an Attribute) |
| `start_stop_play` | enter/exit play mode around a measurement |

Pattern for a measured playtest: start play → let a full gameplay cycle elapse → `console_output` and extract the summary block → repeat per cycle → stop play. Keep the raw blocks as the evidence artifact for any tuning proposal.

For frame time, MicroProfiler, and memory analysis use the skill **roblox-performance**; for breakpoint-level inspection of a live bug use the **roblox-debugging** plugin skill.

## 4. /test and /playtest as instruments

Reach for `/roblox-testing:test` when the question is "did I break a pure function/module" (Jest Lua over `__tests__/*.spec.luau`; its power is proportional to how many specs your project actually has — count them with `find src -name "*.spec.luau" | wc -l`). Reach for `/roblox-testing:playtest <scenario>` when the question is "does the game still boot / does this flow still work end-to-end" — scenarios live in `tests/scenarios/` (house baseline: at least `smoke.md`). Both require Studio + `rojo serve` on `default.project.json`. Conventions, evidence bar, and how to certify a test as trustworthy live in **roblox-validation-and-qa** — treat any harness whose own end-to-end run hasn't been verified in your project as pending-verification.

## 5. Shipped scripts (this skill's `scripts/`, all read-only)

All three assume the house repo layout and locate the repo root themselves (`git rev-parse`), so they can be invoked from any cwd inside the project. All three were test-run against the reference repo on 2026-07-05.

### analyze-all.sh

Covered in §2. Exit 0 clean / 1 diagnostics / 2 missing preconditions.

### flags-report.sh

```bash
.claude/skills/roblox-diagnostics-and-tooling/scripts/flags-report.sh
```

Prints four sections: the full `FeatureFlags` table (from the house-standard `src/Shared/Class/FeatureFlags.luau`) with line numbers, every `local *DEBUG*` constant in src/ with `file:line: declaration`, telemetry `ENABLED` toggles, and a drift section listing every DEBUG value that is not `false`. Output shape:

```
=== FeatureFlags (src/Shared/Class/FeatureFlags.luau) ===
  :15  SaveInStudio = true
  ...
=== DEBUG constants in src/ ===
  src/Server/Features/Xxx.luau:27:local DEBUG_PRINTS = false
  ...
=== Telemetry toggles ===
  ...
=== DEBUG values that are NOT false (check these before a release) ===
  ! src/.../Xxx.luau:79:local DEBUG_FORCE_STATE: number? = 1
```

Interpretation: the `!` section mixes true drift with tuning parameters that merely share the DEBUG prefix (e.g. a visual constant only used when a master `DEBUG_MODE` is true) — read each hit's context before acting. The dangerous class is a non-false DEBUG constant that lives in a production code path. Case study (shipped firebit game, 2026): a `DEBUG_FORCE_STRUCTURE_CHUNK = 1` constant was live in production paths, forcing a specific structure onto the first map chunk for everyone. Whether to change any flag is **roblox-config-and-flags** / **roblox-change-control** territory — and remember hard rule 3: flag-gated dormant code is deliberate, never refactor or delete it. This script only makes drift visible.

### plan-board-drift.sh

```bash
.claude/skills/roblox-diagnostics-and-tooling/scripts/plan-board-drift.sh
```

Tables every `docs/plans/*.md` with frontmatter status + open/checked box counts, counts `docs/plans/archive/`, and flags drift:

```
PLAN                                          STATUS    OPEN CHECKED
some-feature.md                               active       1       8
...
Archive: N plan(s) in docs/plans/archive/
=== Drift flags ===
  ! done-plan.md: status done but not moved to docs/plans/archive/
  ? old-plan.md: all 7 boxes checked but status is '(none)' (finished but never closed out?)
  i N plan(s) have no status frontmatter (predate the workflow)
```

Interpretation: `!` = a `status: done` plan sitting outside `archive/` (a direct workflow violation — the project's CLAUDE.md owns the lifecycle rules); `?` = probably-finished plans never closed out; `i` = plans predating the workflow. Known doc debt and how to pay it down is **roblox-docs-and-writing** territory; this script is how you re-measure it.

## Common mistakes

- **Running `stylua src` repo-wide on a non-clean codebase.** You'd bury your change in an unrelated mega-diff. Check with `stylua --check src` first; format only files you touched.
- **Directory-wide `luau-lsp analyze` without `--ignore="DevPackages/**"`.** Jest-internal errors flood the output and hide real regressions.
- **Treating the per-file hook as full coverage.** It analyzes only the edited file and silently passes when `sourcemap.json`/`globalTypes.d.luau` are missing. After creating/renaming files, regenerate the sourcemap (**roblox-build-and-env**) and run `analyze-all.sh`.
- **Proposing tuning changes from one cycle's feel.** Capture the summary blocks for a full run; the change itself still needs rationale + predicted metric + evidence path per **roblox-change-control**.
- **Expecting balance telemetry outside the gameplay place.** Place-gated telemetry services return early elsewhere (e.g. the lobby); playtest the gameplay place (`npm run dev:<place>`).
- **Expecting session-summary data anywhere but the console.** It only prints; if you didn't capture `console_output` (or copy the Output window) before stopping play, the data is gone.
- **Reading live-game numbers from Studio analytics.** Studio/dev sessions emit with a `-dev` build tag; filter by build when reading dashboards.
- **Trusting "0 errors" from a pipe.** `luau-lsp`/`selene`/`stylua` exit codes are eaten by `| tail`; use the shipped scripts or check `pipestatus`.

## Provenance and maintenance

Derived on 2026-07-05 from the firebit house-stack reference project; all commands and paths were verified there on that date. Everything project-specific is volatile — re-verify against the CURRENT project before relying on it:

| Fact to establish per project | Re-verify with (in the current project repo) |
| --- | --- |
| Telemetry services exist and their signal wiring | `ls src/Server/Features/Telemetry/; grep -rn "Connect\|Subscribe\|= Signal" src/Server/Features/Telemetry/ --include="*.luau"` |
| Which analytics events the project emits | `grep -rn "event = \|logPlayerEvent" src/Server/Features/Telemetry/ --include="*.luau"` |
| Analytics dual-sink (LogCustomEvent + addDesignEvent) in the pinned package | `grep -rn "LogCustomEvent\|addDesignEvent" Packages/_Index/lfg-studio_analytics*/analytics/src/init.luau` |
| Analytics init + build tag | `sed -n '1,20p' src/Server/Features/Core/AnalyticsService.luau` |
| Current type-diagnostic baseline | `.claude/skills/roblox-diagnostics-and-tooling/scripts/analyze-all.sh` |
| Current lint baseline | `selene src 2>&1 \| tail -4` |
| Is the codebase stylua-clean | `stylua --check src 2>&1 \| grep -c "^Diff in"` |
| Tool versions | `cat aftman.toml` |
| Hook flag-set parity with analyze-all.sh | `sed -n '1,25p' scripts/luau-analyze-hook.sh` |
| MCP tool names | `grep -n "console_output\|screen_capture" ~/.claude/plugins/roblox-testing/commands/playtest.md` |
| Live DEBUG/flag drift | `.claude/skills/roblox-diagnostics-and-tooling/scripts/flags-report.sh` |
| Plan/board drift | `.claude/skills/roblox-diagnostics-and-tooling/scripts/plan-board-drift.sh` |

---
name: roblox-change-control
description: Use when about to push, commit, merge, deploy, publish, sync monetization metadata, delete or refactor dormant code, or change tuning/economy numbers in a firebit Roblox project — or when unsure whether an action is agent-safe or owner-only. Covers git push to main/production, rblxsync run, flag-gated legacy code, balance-number edits, and what the luau-analyze / plan-reminder hooks mean when they fire.
---

# Roblox Change Control (firebit house rules)

## Overview

firebit game repos are wired directly to the live game: a GitHub workflow deploys on push, and a monetization sync tool mints real products for real money. Several ordinary-looking actions therefore have real-money or live-player consequences. This skill is the canonical statement of the four owner hard rules, the taxonomy of change types with their gates, and the enforcement hooks that back them. Rules were confirmed by the owner 2026-07-05 in the firebit house-stack reference project and apply to every project on the house stack.

## When to use

- Before any `git push`, `git commit`, merge, or branch operation.
- Before running `rblxsync` in any mode, or editing `rblxsync.yml` / `rblxsync-lock.yml`.
- Before deleting, refactoring, or "cleaning up" code that looks unused.
- Before changing any number in `src/Shared/Data/` (costs, rewards, durations, HP, spawn rates, XP curves).
- When a PostToolUse hook blocks an edit or injects a plan/board reminder and you want to know why.

## When NOT to use

- Deciding *how* to run builds, rblxsync, or asphalt operationally → **roblox-run-and-operate**.
- The evidence bar for a tuning change (what counts as proof) → **roblox-research-methodology**; analysis recipes → **roblox-proof-and-analysis-toolkit**.
- Which flags/config axes exist and how to add one → **roblox-config-and-flags**.
- The plan/board lifecycle *procedure* itself → the project's CLAUDE.md owns it (statuses, checkbox timing, archive steps). This skill only explains why it exists and what happens when it is skipped.

## The four hard rules (owner-confirmed 2026-07-05)

### Rule 1 — NEVER push to origin `main` or `production`

**Why:** the boilerplate `.github/workflows/deploy.yml` triggers on `push` to branches `main` and `production`. It runs `npm run build:deps`, resolves universe/place IDs from repo variables (`DEV_*` for main, `PRODUCTION_*` for production), then runs `rojo upload` for each place project (e.g. `lobby.project.json`, `level.project.json`) — publishing the places straight to Roblox. A push IS a deploy. There is no staging step, no approval gate.

Verify in the current project before assuming an exception:

```bash
sed -n '1,12p' .github/workflows/deploy.yml
grep -n "rojo upload" .github/workflows/deploy.yml
```

**Practice:** commits stay local. Local `main` being ahead of `origin/main` is often deliberate, not drift — check `git status -sb` before "helping". Commit only when the owner asks; push only when the owner does it or explicitly asks you to.

### Rule 2 — NEVER run `rblxsync run` against the live universe

**Why:** rblxsync matches resources by **case-sensitive NAME** — the manifest header in `rblxsync.yml` states that a name that doesn't match what's live on Roblox will create a **duplicate** live product on sync. Badge creation costs **100 Robux each** (a Roblox platform fee), charged to the account named in `badge_payment_source` — typically the owner's personal account. A run mints real Developer Products, Game Passes, and Badges that cannot be un-minted.

**Agents MAY:** edit `rblxsync.yml`, run `rblxsync validate`, run `rblxsync run --dry-run`.
**Owner-only:** `rblxsync run` (and `rblxsync export`, which needs live credentials). Exception: the owner explicitly requests the run in this session.

Verify the stakes in the current project:

```bash
sed -n '1,20p' rblxsync.yml
grep -n "badge_payment_source" rblxsync.yml
```

### Rule 3 — NEVER refactor, "clean up", or delete flag-gated dormant code

Code gated off behind a `false` flag in `src/Shared/Class/FeatureFlags.luau` is dormant by decision, not dead by accident. It often has live Roblox products still attached to it (declared on Roblox but intentionally absent from `rblxsync.yml`), and it is the re-enable path for a shelved feature. Deleting it strands live products and destroys that path.

Before touching anything that looks unused:

```bash
grep -nE "= false" src/Shared/Class/FeatureFlags.luau
grep -rn "<FlagName>" src/   # find what the flag gates
```

If dead-looking code blocks your task, mention it in your report; do not remove it.

**Case study (shipped firebit game, 2026):** an entire earlier era of the game — base-building, minigames, a player market — remained in the repo behind `false` flags, with its monetization products deliberately left out of `rblxsync.yml` so they'd stay live-but-untouched on Roblox. Any "dead code cleanup" pass would have stranded real purchased products and erased the re-enable path.

### Rule 4 — NEVER change economy/difficulty/tuning numbers on a guess

Every tuning change requires three things stated in the plan file before the edit:

1. **Rationale** — why this number, not just "feels wrong".
2. **Predicted metric** — what should move, in which direction, by roughly how much.
3. **Evidence path** — telemetry field or playtest scenario that will confirm or refute it.

The evidence bar and hunch→result discipline live in **roblox-research-methodology**. Tuning surfaces are the `*Data.luau` and constants modules under `src/Shared/Data/` (session/day-cycle config, reward tables, difficulty curves, NPC stats) and the prices in `rblxsync.yml`. "Placeholder — tune freely" comments in code lower the stakes but do not waive the rationale requirement.

## Change taxonomy

| Change class | Examples | Gate | Who executes | Verified by |
|---|---|---|---|---|
| Code change | new service, bug fix, UI component | Plan file with `status: active` in `docs/plans/` before first line of code (project CLAUDE.md rule); luau-analyze hook must pass | Agent | `/roblox-testing:test` (Jest), Studio playtest via `/roblox-testing:playtest`; see roblox-validation-and-qa |
| Tuning number | costs, durations, reward amounts, XP curve | Rule 4 triple (rationale + predicted metric + evidence path) written in the plan | Agent edits; owner judges outcome | Telemetry or playtest along the stated evidence path |
| Monetization metadata | add/rename/re-price products, passes, badges in `rblxsync.yml` | Rule 2: edit + `validate` + `--dry-run` only; exact-name match against `rblxsync-lock.yml` | Agent edits yml; **owner runs `rblxsync run`** | Diff `rblxsync-lock.yml` and `src/Shared/Data/Monetization/Generated.luau` after the owner's run |
| Asset (asphalt) | new PNG/audio under `assets/` | Generated ID files (e.g. `src/Shared/Data/Images.luau`, `Sounds.luau`) are never hand-edited | Owner runs the asphalt sync (uploads to Roblox); see roblox-run-and-operate | IDs appear in generated Luau; asset renders in Studio |
| Docs / board / plans | `docs/plans/*.md`, `docs/BOARD.html`, docs of record | Same-turn discipline: plan checkbox + board card move with the work (project CLAUDE.md owns the letter) | Agent | Plan status matches reality; board lane matches plan status |
| Push / deploy | `git push` to main or production | Rule 1: never | **Owner only** | GitHub Actions deploy run |

Committing (any class): only when the owner asks. Working-tree changes accumulating uncommitted on local main is a normal state in these repos.

## Enforcement that already exists — hooks are not noise

`.claude/settings.json` in each project wires real enforcement. When a hook fires, it is telling you something specific:

| Hook | Trigger | What it does | Correct response |
|---|---|---|---|
| `scripts/luau-analyze-hook.sh` (PostToolUse on Write/Edit/MultiEdit) | any `.luau` edit outside `Packages/` | Runs `luau-lsp analyze` on the edited file against `sourcemap.json`; on any issue prints them and **exits 2, blocking feedback** | Fix the reported type/lint errors now. If the file is NEW, the sourcemap doesn't know it — run `npm run build:sourcemap` first (see roblox-build-and-env) |
| Inline jq reminder (PostToolUse, same matcher) | edited path matches `*/src/*` | Injects context: update the matching `docs/plans/` plan and move the `docs/BOARD.html` card THIS TURN | Actually do it this turn. This is the mechanical backstop for the CLAUDE.md lifecycle |
| `scripts/setup-lsp.sh` (SessionStart) | every session | Refreshes `globalTypes.d.luau` (24h TTL) and regenerates the sourcemap when stale | Nothing — but explains why first-edit analysis works |
| `scripts/board-snapshot.sh` (SessionStart) | every session | Prints the mandatory file map + the board's active lanes (In Progress, Testing, Up Next) | Read it; it is the task context you are expected to have |

Confirm the wiring in the current project: `jq '.hooks' .claude/settings.json`.

## Why the plan/board discipline exists (failure evidence)

The project's CLAUDE.md owns the rules (plan before code, check boxes same-turn, archive on done). The reason they are non-negotiable is observed drift, not theory.

**Case study (shipped firebit game, 2026-07):** an audit found zero plans ever archived despite multiple Done-lane board cards; of 33 plan files only 5 were `active`, roughly 10 were stale — shipped features with unchecked boxes, a plan referencing a file that no longer existed, and diagnosed bugs on no board lane at all. Each skipped same-turn update compounded into a board nobody could trust.

Audit your own project's drift the same way:

```bash
ls -la docs/plans/archive/
grep -L "status: done" docs/plans/*.md | xargs grep -l "\[x\]" 2>/dev/null   # checked boxes, not archived
grep -l "status: active" docs/plans/*.md
```

That drift is exactly what "a plan file that disagrees with reality is a bug" means in practice.

## Rationalization table

| Excuse | Reality |
|---|---|
| "It's just a tiny push, docs only" | deploy.yml does not read diffs. Any push to main publishes the places to Roblox. |
| "I'll run rblxsync to be helpful / to finish the card" | A run mints real products and charges real Robux for badges. Board cards saying "needs rblxsync run" mean the OWNER runs it. |
| "This legacy code is dead anyway" | It is flag-gated off deliberately, often with live Roblox products still attached. Dormant ≠ dead. |
| "This number is obviously wrong" | "Obviously" is a guess. Rule 4: rationale + predicted metric + evidence path, or don't touch it. |
| "I'll batch the plan checkboxes at the end" | The project's CLAUDE.md says same-turn, and the jq hook reminds you per edit. Batching is how stale plans happen. |
| "I'll commit so the work is safe" | Uncommitted working tree is a normal state here. Commit only when the owner asks. |
| "The lock file has the ID, I'll just tweak the name in yml" | Names are the match key. A renamed entry creates a DUPLICATE live product on the next run. |
| "Dry-run passed, so the run is safe for me to do" | Dry-run validates the diff; it does not transfer the authority to execute it. |

## Red flags — thoughts that mean STOP

- "It's just a tiny push."
- "I'll sync rblxsync to be helpful."
- "This legacy code is dead anyway."
- "This number is obviously wrong."
- "No one will notice if I skip the plan file this once."
- "I'll rename this product to something cleaner."
- "The hook is being annoying, I'll work around it."

If any of these appear in your reasoning, stop, re-read the matching rule above, and either take the agent-safe portion (edit + validate + dry-run + plan note) or report the blocker to the owner.

## Common mistakes

- Treating `rblxsync run --dry-run` success as license to run the real sync. It is not.
- Editing `rblxsync-lock.yml` or `src/Shared/Data/Monetization/Generated.luau` by hand — both are tool-written outputs (Generated.luau says "Do not edit").
- "Fixing" or loosening `scripts/luau-analyze-hook.sh` to make a failing edit pass.
- Creating a new `.luau` file and then fighting the hook — regenerate the sourcemap instead (roblox-build-and-env).
- Renaming a product in `rblxsync.yml` to match code style — name IS identity; change code to match the yml, or flag it for the owner.
- Interpreting "commits stay local" as "never commit" — commit when the owner asks; just never push.

## Provenance and maintenance

Derived 2026-07-05 from the firebit house-stack reference project; the rules are standing convention for all firebit projects. Re-verify the volatile facts against the CURRENT project repo before relying on them:

```bash
# Rule 1: deploy trigger and what it publishes
sed -n '1,12p' .github/workflows/deploy.yml && grep -n "rojo upload" .github/workflows/deploy.yml
# Rule 2: name-matching warning and badge fee source
sed -n '1,20p' rblxsync.yml && grep -n "badge_payment_source" rblxsync.yml
# Rule 3: which flags are off, and what they gate
grep -nE "= false" src/Shared/Class/FeatureFlags.luau
# Hooks still wired
jq '.hooks' .claude/settings.json
grep -n "exit 2" scripts/luau-analyze-hook.sh
# Local-vs-origin state before any commit talk
git status -sb | head -1 && git log origin/main..main --oneline
# Plan-discipline drift
ls -la docs/plans/archive/ && grep -l "status: active" docs/plans/*.md
```

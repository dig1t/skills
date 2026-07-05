---
name: roblox-build-and-env
description: Use when setting up a firebit Roblox project on a fresh machine or when build tooling misbehaves — aftman/wally/rojo/npm errors, "Unknown require" on valid code, the luau-lsp PostToolUse hook blocking an edit (exit 2) or silently passing broken code, stale sourcemap.json, missing globalTypes.d.luau, DevPackages/Jest type errors, confusion over default vs per-place .project.json, stray .rbxl files in repo root, .env / ROBLOX_API_KEY questions, or "which npm script do I run".
---

# roblox-build-and-env — bootstrap and build-system traps

## Overview

Every firebit Roblox project builds a game from plain files on disk; every tool in the chain (Aftman → Wally → Rojo → luau-lsp) depends on artifacts produced by the previous one, and most "mysterious" failures are a stale artifact, not a code bug. Regenerate the artifact (usually `sourcemap.json`) before debugging the code.

All commands run from the current project's repo root; all paths are repo-root-relative.

Jargon, once:
- **Roblox Studio** — Roblox's IDE/engine; opens `.rbxl` "place" files (a place = one built game world).
- **Rojo** — syncs/builds filesystem source into a Roblox place. A `*.project.json` file maps disk paths → the Roblox instance tree.
- **Wally** — Luau package manager (like npm). Installs into `Packages/` and `DevPackages/`.
- **Aftman** — toolchain manager; pins CLI tool versions in `aftman.toml` (like asdf/mise).
- **luau-lsp** — Luau language server / analyzer; needs `globalTypes.d.luau` (Roblox API type definitions) and `sourcemap.json` (Rojo's file→instance map) to resolve requires and types.
- **wally-package-types** — patches Wally's thin package-link files so installed packages export their types to luau-lsp.

## When to use / when NOT to use

Use for: fresh-machine setup, npm script anatomy, sourcemap/hook failures, Wally/Packages problems, Rojo project selection, `.env` expectations, identifying root `.rbxl` files.

NOT for:
- Running/playtesting the game, deploying, live `rblxsync`/`asphalt` operations → **roblox-run-and-operate** (and hard rules live in **roblox-change-control**).
- Config axes and feature flags → **roblox-config-and-flags**.
- Test/scenario/storybook conventions → **roblox-validation-and-qa**.
- General Rojo theory → global skill **rojo-pro**; rblxsync.yml authoring → global skill **rblxsync**.

## 1. Fresh-machine bootstrap (ordered)

Run from the project's repo root.

```bash
# 1. Install Aftman itself (one-time per machine; not vendored in the repo).
#    UNVERIFIED which channel the owner uses — standard options:
#    download from https://github.com/rojo-rbx/aftman/releases or `cargo install aftman`.
#    Aftman puts tool shims in ~/.aftman/bin — ensure that is on PATH.

# 2. Install the pinned toolchain. Read aftman.toml for the exact set — the
#    house baseline is asphalt, luau-lsp, rblxsync, rojo, selene, stylua,
#    wally, wally-package-types (versions vary per project; never assume them):
cat aftman.toml
aftman install

# 3. Node deps (docs tooling, concurrently, open-cli — build helpers only)
npm install

# 4. Wally packages + sourcemap + package types (the core build step)
npm run build:deps

# 5. globalTypes.d.luau — either start a Claude session (the SessionStart hook
#    scripts/setup-lsp.sh downloads it automatically) or fetch manually:
curl -sL "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau" > globalTypes.d.luau

# 6. Build a playable place. Each project defines build:<place> scripts
#    (e.g. build:level, build:lobby); each re-runs build:deps first.
#    List them:
npm run
npm run build:<place>    # -> <game>-<place>.rbxl in repo root (exact name in package.json)
```

Verify success: `Packages/` and `DevPackages/` exist, `sourcemap.json` exists, the built `.rbxl` appears in repo root.

Optional, owner-gated: `.env` with `ROBLOX_API_KEY` for rblxsync (section 8); asphalt for asset uploads (operating both belongs to **roblox-run-and-operate**).

## 2. npm scripts anatomy

The house `package.json` scripts follow this shape — always confirm the exact set with `cat package.json`; place names differ per game:

| Script | Literally runs | Use when |
|---|---|---|
| `build:sourcemap` | `rojo sourcemap default.project.json -o sourcemap.json && wally-package-types --sourcemap sourcemap.json Packages` | After creating/renaming/moving any `.luau` file. The single most-needed command. |
| `build:deps` | `wally install && npm run build:sourcemap` | After any `wally.toml` change; part of every build. |
| `build:<place>` | `npm run build:deps && rojo build -o <game>-<place>.rbxl <place>.project.json` | Produce the playable place file for that place. |
| `build:<place>:open` | build + `npx open-cli ./<game>-<place>.rbxl` | Build and open in Studio (also typically wired to `.vscode/tasks.json`). |
| `dev:<place>` | build + `npx concurrently "npx open-cli ./<game>-<place>.rbxl" "rojo serve"` | Iterate in Studio with live sync. Note trap #6: the serve uses `default.project.json`. |
| `start` | `npm run build:deps && rojo serve` | Live-sync code only (no place build/open). |
| `build:docs` / `dev:docs` | `moonwave build` / `moonwave dev` | API docs site only. |

There is no `npm test` script — tests run via the roblox-testing plugin (`/roblox-testing:test`); see **roblox-validation-and-qa**.

## 3. The Rojo projects: default + one per place

The house convention is one code-only `default.project.json` plus one full-place project per place (e.g. `level.project.json`, `lobby.project.json`). List them with `ls *.project.json` and read each before assuming what it mounts.

| Project | Pattern | Mounts DevPackages? | Excludes specs? | Used for |
|---|---|---|---|---|
| `default.project.json` | Code-only: ReplicatedStorage{Packages, DevPackages, Shared←src/Shared, Version←version.txt}, ServerScriptService←src/Server, ReplicatedFirst←src/Client. No Workspace/assets. | **Yes — the only one** | No | Sourcemap generation; the implicit project for `rojo serve` (no arg = default.project.json); Jest tests live only in this tree. |
| `<place>.project.json` (one per place) | Full playable place: Workspace←assets/environment/<place>, ReplicatedStorage.Assets←assets/shared, an `Environment` StringValue naming the place, plus per-place mounts (lighting, materials, gui, server storage) that vary by project. | No | `"globIgnorePaths": ["**/*.spec.luau"]` | `build:<place>` → the `.rbxl`. |

Consequences:
- Built `.rbxl` places carry **no** test code (`*.spec.luau` glob-ignored) and no DevPackages.
- Game code reads the `Environment` StringValue to know which place it's in (see **roblox-config-and-flags**).
- Per-place projects differ in what they mount (e.g. one place may mount Lighting and another may not). Never infer a mount from the assets directory existing on disk — read the project file. (Learned in a shipped firebit game, 2026: `assets/lighting/level/` existed on disk while `level.project.json` mounted no Lighting.)
- Project files get renamed as games evolve; if a doc names a `.project.json` that `ls *.project.json` doesn't show, the doc is stale — trust the filesystem.

## 4. sourcemap.json — the #1 trap

`sourcemap.json` is gitignored and consumed by the luau-analyze PostToolUse hook and by luau-lsp in your editor. It is a **snapshot**: it does not update itself.

**MUST-KNOW:** after creating, renaming, or moving ANY `.luau` file, run:

```bash
npm run build:sourcemap
```

or the hook will fail valid code (new file isn't in the map → requires can't resolve → exit 2 on a correct edit).

Two different generators exist and produce different output:

| Generator | Command | Differences |
|---|---|---|
| Canonical: `npm run build:sourcemap` | `rojo sourcemap default.project.json -o sourcemap.json && wally-package-types --sourcemap sourcemap.json Packages` | Scripts only; refreshes Packages type exports. |
| `scripts/setup-lsp.sh` (SessionStart hook) | `rojo sourcemap --include-non-scripts --output sourcemap.json` | Adds non-script instances; **skips** wally-package-types. Only runs when sourcemap.json is missing OR globalTypes.d.luau was just (re)downloaded (older than 24h). |

So a session started >24h after the last globalTypes download silently regenerates the sourcemap with different flags. Facts verified; downstream impact is inference — if types behave oddly right after session start, run the canonical command.

## 5. DevPackages trap

`wally.toml` `[dev-dependencies]` (Jest, JestGlobals — jsdotlua) install into `DevPackages/`, a separate realm from `Packages/`. **No npm script in the boilerplate runs wally-package-types on DevPackages** — `build:sourcemap` types-passes `Packages` only. This gap is known and accepted for dev-only test code.

If you need typed Jest APIs in the editor, run (command inferred from tool usage, not present in any repo script):

```bash
wally-package-types --sourcemap sourcemap.json DevPackages
```

Note the analyze hook `--ignore`s `*.spec.luau`, so this gap shows up in your editor's LSP, not in hook failures.

## 6. Hook behavior reference

All wired in `.claude/settings.json` — confirm with `jq '.hooks' .claude/settings.json` in the current project.

**`scripts/luau-analyze-hook.sh`** — PostToolUse, matcher `Write|Edit|MultiEdit`, timeout 60:
- Reads the edited path from hook JSON stdin (`jq -r '.tool_input.file_path'`).
- Exit 0 (skip) if: not `*.luau`; path contains `/Packages/`; **or `sourcemap.json` / `globalTypes.d.luau` is missing** — meaning with either file absent, real type errors go silently unreported. A green hook is not proof of clean types unless both files exist.
- Otherwise runs: `luau-lsp analyze --defs=globalTypes.d.luau --sourcemap=sourcemap.json --no-strict-dm-types --ignore="Packages/**" --ignore="*.spec.lua" --ignore="*.spec.luau" <file>`
- On analyzer failure: prints issues to stderr, exits 2 (blocks the edit result).
- Analyzes only the edited file against the existing sourcemap (per its header comment): regen the sourcemap after renames/moves.

**`scripts/setup-lsp.sh`** — SessionStart, timeout 30: downloads `globalTypes.d.luau` from the luau-lsp repo's main branch if missing or >24h old (mtime check, macOS `stat -f %m` / Linux `stat -c %Y`); conditionally regenerates the sourcemap (section 4). Sourcemap failure is swallowed (`|| true`).

**`scripts/board-snapshot.sh`** — SessionStart, timeout 10: prints the mandatory-reads reminder from the project's CLAUDE.md plus the active lanes sliced out of `docs/BOARD.html`. Build-irrelevant; listed so you don't wonder what it is.

A second inline PostToolUse hook (jq one-liner in settings.json) fires on any `*/src/*` edit and injects a reminder to update `docs/plans/` + the board — the project's CLAUDE.md owns that workflow.

## 7. Wally specifics

- **After ANY `wally.toml` edit, run `npm run build:deps`.** Order matters: wally install must precede sourcemap generation (wally-package-types needs Packages present and in the map) — which is exactly what `build:deps` encodes. Never hand-roll the order.
- `Packages/` = runtime deps (the house stack: dig1t/red networking, ProfileDB, Replica, jsdotlua React 17 + ReactRoblox, Promise, Maid/Trash, dig1t utility modules — read `wally.toml` for the project's exact list). `DevPackages/` = dev-deps (Jest). Both gitignored, fully regenerated by `wally install` — never hand-edit files inside them (the hook skips them anyway).
- `.gitignore` also lists `ServerPackages`; if `wally.toml` has no `[server-dependencies]`, that directory won't exist — that's normal.
- Registry: UpliftGames/wally-index. House package naming: `firebit-dev/<game-name>`, `private = true`.

## 8. .env expectations

`.env` in repo root, **gitignored — never commit it** (it holds live credentials):

| Var | Used by | Notes |
|---|---|---|
| `ROBLOX_API_KEY` | rblxsync | Open Cloud API key. Required for any rblxsync network command. |
| `ROBLOSECURITY` | rblxsync (universe name/description sync only) | Cookie auth; invalidates when the account logs in elsewhere. Check `rblxsync.yml`: if the name/description fields are commented out, runs work with the API key alone. |

`rblxsync.exported.yml` is also gitignored (export scratch output). `rblxsync-lock.yml` and the generated `src/Shared/Data/Monetization/Generated.luau` ARE committed. Never run `rblxsync run` against the live universe yourself — that hard rule and its rationale are owned by **roblox-change-control**; operational workflow by **roblox-run-and-operate**.

## 9. Root *.rbxl files — classify before trusting

`*.rbxl`, `*.rbxlx`, and `*.lock` are all gitignored, so the repo root accumulates untracked place files. Before opening one, classify it:

```bash
ls -la *.rbxl*                          # inventory
grep '"build:' package.json             # which .rbxl names are real build outputs
```

- **Real** — files named exactly as a `build:<place>` script's `-o` output. Reproducible; safe to delete and rebuild.
- **Studio lock files** (`*.rbxl.lock`) — Studio has/had the place open. Safe to ignore.
- **Manual saves / backups** — anything else (date-named saves, keyboard-mash names). Junk; never a source of truth.
- **Other games entirely** — people save unrelated places into project folders. (Learned in a shipped firebit game, 2026: the repo root held place files from two completely different games; opening one thinking it was the project wastes a session.)

Do not delete any of them without the owner's say-so (they're untracked; deletion is unrecoverable).

## 10. Ranked trap list (violation → what you'll see)

1. **Created a new `.luau` and didn't regen the sourcemap** → PostToolUse hook exits 2, "luau-lsp found issues", unknown-require/unresolved-module errors on code that is actually correct. Fix: `npm run build:sourcemap`.
2. **`sourcemap.json` or `globalTypes.d.luau` missing** → you see *nothing*: the hook exits 0 and real type errors sail through unreported. If the hook has been suspiciously quiet, check both files exist.
3. **Edited `wally.toml` without `npm run build:deps`** → unknown-module errors on package requires; editor types stale for new/updated packages.
4. **Expecting typed Jest from DevPackages** → untyped/`any` Jest APIs in the editor; no npm script fixes this (section 5).
5. **24h session-start sourcemap swap** → sourcemap silently regenerated with `--include-non-scripts` and no wally-package-types pass; if types wobble after session start, rerun the canonical command.
6. **`dev:<place>` serves `default.project.json`, not the place project** → the served tree is code-only; the opened `.rbxl` has the full Workspace/assets, but the live sync covers only what default.project.json mounts (consequence partly inference; fact of the command verified).
7. **Editing files under `Packages/`/`DevPackages/`** → silently reverted by the next `wally install`.
8. **Opening the wrong root `.rbxl`** → you're editing a stale save or a different game entirely (section 9).
9. **Trusting `README.md`** → it may be unedited boilerplate ("firebit boilerplate for Roblox games"); bootstrap from this skill and `package.json` instead.

## Common mistakes

- Debugging "broken" code before checking artifact freshness. Sourcemap first, code second.
- Running `rojo build`/`rojo serve` by hand and skipping `build:deps` — use the npm scripts; they encode the ordering.
- Adding `--!strict` to files: `.luaurc` sets `"languageMode": "strict"` globally (the project's CLAUDE.md bans the redundant directive).
- Committing `.env`, `sourcemap.json`, `globalTypes.d.luau`, or any `.rbxl` — all deliberately gitignored.
- Assuming a passing hook means clean types when `sourcemap.json`/`globalTypes.d.luau` might be absent (trap #2).
- Pushing commits: the boilerplate `.github/workflows/deploy.yml` auto-deploys the live game on push to `main`/`production` — commits stay local; see **roblox-change-control**.

## Provenance and maintenance

Derived 2026-07-05 from the firebit house-stack reference project. All commands and paths are repo-root-relative and phrased for the **current** project — re-verify volatile facts against it, not against the reference project:

```bash
cat package.json                                  # scripts table (section 2)
cat aftman.toml                                   # tool pins (section 1)
cat wally.toml                                    # deps/dev-deps (sections 5, 7)
ls *.project.json && cat default.project.json     # project trees (section 3)
cat scripts/luau-analyze-hook.sh scripts/setup-lsp.sh   # hook commands/exit semantics (sections 4, 6)
jq '.hooks' .claude/settings.json                 # hook wiring (section 6)
cat .luaurc .gitignore                            # strict mode, ignore rules
ls -la *.rbxl*                                    # rbxl inventory (section 9)
grep -n "ROBLOX_API_KEY\|ROBLOSECURITY" rblxsync.yml    # .env expectations (section 8)
grep -rn "wally-package-types" package.json .github/workflows/  # DevPackages gap (section 5)
grep -n "branches" -A3 .github/workflows/deploy.yml     # deploy trigger
```

If a project's `package.json`, hook scripts, or project files diverge from the house shape described here, trust the project's files — and if the divergence is deliberate house-wide, update this skill in the same change (see **roblox-docs-and-writing** for doc-of-record rules).

---
name: roblox-run-and-operate
description: Use when running, building, deploying, or operating a Roblox project on the house stack — starting the dev loop (npm run dev:<place>), connecting Rojo to Studio, driving Studio via MCP, understanding what pushing to main/production actually does (CI/CD), syncing monetization IDs with rblxsync, uploading assets with asphalt, or answering "which universe/place ID is dev vs live", "where does this generated file come from", "why isn't my Workspace change syncing".
---

# Roblox — Run and Operate (house stack)

## Overview

This skill maps every way code and assets leave your editor and land in Roblox on the firebit house stack: the local dev loop, Studio automation, GitHub CI/CD, and the two ID-minting CLIs (rblxsync, asphalt). The core principle: **local builds and dry-runs are always safe; anything that touches origin main/production or runs a live sync publishes to a real Roblox universe** (canonical rules in roblox-change-control).

All commands run from the current project's repo root unless stated otherwise. Every project on this stack shares the same skeleton (Rojo + Wally + npm scripts + boilerplate workflows), but names, IDs, and script lists vary per project — verify against the current repo before quoting them.

## When to use / When NOT to use

Use when you need to run the game, build a place file, drive Roblox Studio, understand CI, or operate rblxsync/asphalt.

Do NOT use for:
- Bootstrap, npm script internals, sourcemap traps, wally → **roblox-build-and-env**
- Test/playtest/storybook mechanics and evidence standards → **roblox-validation-and-qa** (and plugin commands `/roblox-testing:test`, `/roblox-testing:playtest`)
- The four hard rules' canonical statement and change gates → **roblox-change-control**
- Adding a new config axis or flag → **roblox-config-and-flags**
- Runtime debugging in a running game → skill **roblox-debugging**
- General Rojo/rblxsync theory → global skills **rojo-pro**, **rblxsync**

## 1. Dev loop anatomy

Definitions: **Rojo** syncs a filesystem tree into Roblox Studio (a "project file" like `level.project.json` declares that tree); an **.rbxl** is a binary Roblox place file; **Wally** is the Luau package manager.

House-standard npm scripts (per-place names vary — read `package.json` for the actual `<place>` list, e.g. `level`, `lobby`):

| Command | What it does | Use for |
|---|---|---|
| `npm run dev:<place>` | `build:<place>` → opens the built .rbxl in Studio → `rojo serve` | Day-to-day work on that place |
| `npm run build:<place>` | `build:deps` + `rojo build -o <name>.rbxl <place>.project.json` | Build only, no Studio |
| `npm run build:<place>:open` | Build + open in Studio, no serve | One-shot inspection |
| `npm start` | `build:deps` + `rojo serve` (no build, no open) | Reconnecting serve to an already-open place |

The .rbxl output filename is defined inside each `build:<place>` script. Built .rbxl outputs land in the repo root and are gitignored — check `.gitignore` before assuming.

### The dev-loop caveat that bites everyone

`rojo serve` inside `dev:<place>` is invoked **with no project argument**, so it serves `default.project.json` — a **code-only** tree (Packages, DevPackages, `src/Shared`, `src/Server`, `src/Client`, and similar). The place you opened, however, was built from the per-place project file (`level.project.json`, `lobby.project.json`, ...), which additionally mounts Workspace geometry (`assets/environment/*` or equivalent), `ReplicatedStorage.Assets`, MaterialService, StarterGui, ServerStorage, and sometimes Lighting.

Practical consequences:
- After connecting the Rojo Studio plugin, **Luau code edits live-sync; edits under `assets/` do NOT**. To see asset/environment changes, stop, rebuild (`npm run dev:<place>` again), reopen.
- The served tree includes `DevPackages` (Jest); built per-place places exclude DevPackages and `**/*.spec.luau` — so unit tests only exist when serve is connected or when using the default tree (details: roblox-validation-and-qa).
- If your change is in a project-file mount (StreamingEnabled, environment StringValues, CharacterAutoLoads=false, any property set in the .project.json), it only takes effect on rebuild, never via serve.

Verify what each project file mounts by reading it — never guess: `cat default.project.json <place>.project.json`.

## 2. Studio: connecting and driving it

**Manual connect:** open the built .rbxl in Studio, then in Studio's Plugins tab click the Rojo plugin → Connect (defaults to `localhost:34872`, Rojo's default port). Install the plugin from the Rojo VS Code extension or `rojo plugin install` if missing. UNVERIFIED: plugin install state on any given machine — check before assuming.

**Scripted Studio (MCP):** an MCP server named `Roblox-Studio` is available via the house plugins (`roblox-testing@dig1t-plugins`, `install-ui-labs@dig1t-plugins` in `.claude/settings.json`). Its `.mcp.json` launches `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP --stdio` (path verified on macOS in the reference setup). It exposes tools like `start_stop_play`, `execute_luau`, `console_output`, `screen_capture`, `keyboard_input`, `search_game_tree`. Studio must already be open with a place loaded for the proxy to have something to drive.

**The scripted way to run tests/playtests** is `/roblox-testing:test` (Jest suite in play mode) and `/roblox-testing:playtest` (scenario files under `tests/scenarios/`). Mechanics, scenario format, and pass/fail rules are owned by **roblox-validation-and-qa** — do not improvise your own play-mode harness.

For runtime breakpoint debugging through the same MCP tools, use the skill **roblox-debugging**.

## 3. CI/CD reality (boilerplate `.github/workflows/`)

Every house project carries the same boilerplate workflows. Verified against the reference repo 2026-07-05 — re-read the current project's copies before relying on details:

| Workflow | Trigger | What actually happens |
|---|---|---|
| `deploy.yml` | Push to `main` or `production`; manual `workflow_dispatch` | `npm run build:deps`, then `rojo upload <place>.project.json` for each place **directly to a real Roblox universe**. Auth: `secrets.CLOUD_API_KEY`. Target IDs come from GitHub Actions repo variables: `DEV_*` for main, `PRODUCTION_*` for production. |
| `format.yml` | PRs (non-draft) only in practice — in the reference copy the `push` paths filter is `src` (not `src/**`), which never matches files under `src/`, so it has never fired on a push | StyLua action (pinned) formats `src`, auto-commits "Format with StyLua" and force-pushes with lease to the branch. |
| `linter.yml` | PRs (non-draft) only | wally install, download globalTypes, `rojo sourcemap --include-non-scripts`, wally-package-types, `luau-lsp analyze ... src`, `selene src`. Nothing runs on plain pushes. |
| `docs.yml` | Push to main touching `src/**`, `docs/**`, `moonwave.toml`, `README.md` | `npx moonwave build` → publishes `./build` to the studio's external docs repo (`firebit-dev/docs`, branch `gh-pages`, per-project subdirectory). |
| `release.yml` | Push to `production` touching `version.txt` | release-drafter publishes a GitHub release named from `version.txt`. |
| `version-updater.yml` | Push to `main` touching `version.txt` | Writes `src/Shared/Config/Version.luau` = `return "<version>"` and force-pushes an "Update version" commit back to main (pushed with `GITHUB_TOKEN`, so it does NOT re-trigger deploy or any other workflow — the deploy for that version came from the original human push of version.txt). |

**This is why hard rule 1 exists** (never push origin main/production; canonical statement in **roblox-change-control**): there is no staging gate — a push to main uploads every place to the universe in the `DEV_*` repo variables, and a push to production uploads to `PRODUCTION_*` (the live game). Treat both branches as deploy triggers. Commits stay local until the owner pushes.

To confirm the dev↔main / live↔production mapping in the current project: `gh variable list -R <owner>/<repo>` and compare against the in-game identity constants (section 6).

Note the deploy path never runs tests or the linter — linting is PR-only. A direct push to main deploys unlinted code.

## 4. rblxsync operating procedure

**rblxsync** (aftman-pinned; `dig1t/rblxsync@0.2.2` in the reference repo — check the current project's `aftman.toml`) declaratively syncs monetization metadata (game passes, dev products, badges, universe settings) from `rblxsync.yml` to Roblox Open Cloud, then generates `src/Shared/Data/Monetization/Generated.luau` (typed ID tables, "do not edit") and writes real IDs to `rblxsync-lock.yml` (commit both).

Agent-safe sequence (never mints anything on Roblox); run from the repo root:

```bash
rblxsync validate          # schema/config check
rblxsync run --dry-run     # preview the exact create/update plan
```

The live sync — `rblxsync run` with no flag — **is owner-gated (hard rule 2, canonical in roblox-change-control)**: it mints real products and badges (badges cost 100 Robux each) and matches resources by **case-sensitive NAME**; a name mismatch between yml and live creates a duplicate product on Roblox. Agents may edit `rblxsync.yml` freely and dry-run it.

Standing facts to verify per project:
- Auth: `ROBLOX_API_KEY` in `.env` (gitignored). Confirm presence without printing: `grep -c ROBLOX_API_KEY .env`.
- Universe `name`/`description` in `rblxsync.yml` require **cookie auth** (`ROBLOSECURITY` in `.env`). If they are commented out, that usually means the cookie is stale — do not uncomment them without a fresh cookie, or every subsequent run fails. The lock file may carry stale name/description from a prior run.
- Which universe does `rblxsync run` target? Read `universe.id` in `rblxsync.yml` and compare against the dev/live identity table (section 6). In the reference project it targeted the **live** universe with no dev-universe config — assume the same until you check.
- Trace where each generated ID actually flows at runtime. Case study (shipped firebit game, 2026): badge IDs did NOT flow from Generated.luau — they were hand-pasted from the lock into a table in the game-data module, so every new badge needed that paste step after the owner's live run. Grep for consumers of the lock/Generated IDs before assuming codegen covers everything.
- Live resources deliberately left undeclared in yml (legacy or previous-era products) may exist — look for an explanatory comment above `developer_products:` in `rblxsync.yml`. Leaving them undeclared and untouched is intentional (hard rule 3 adjacent): do not "clean up" by declaring or deleting them.
- CLI subcommand mismatch (rblxsync 0.2.2): a yml header may recommend `rblxsync export --output ...` to reconcile names, but `export` emits **Luau** of existing resources; `rblxsync import` is the subcommand that pulls live metadata into `rblxsync.yml` + lock. Both are read-only against Roblox, but `import` rewrites your local manifest — diff before committing.

Deeper CLI theory: global skill **rblxsync**. Which products exist and their prices: **roblox-config-and-flags** / the project's `rblxsync.yml` itself. Subscriptions cannot be minted by rblxsync at all — a manual Creator Hub act.

## 5. asphalt (asset upload + ID codegen)

**asphalt** (aftman-pinned; `jacktabscode/asphalt@1.0.0-pre.14` in the reference repo) uploads local asset files to Roblox and generates Luau modules mapping filename → `rbxassetid://` URL, so code never hardcodes asset IDs.

House-standard wiring (read `asphalt.toml` for the current project's exact inputs):

| Input (from `asphalt.toml`) | Output |
|---|---|
| `assets/images/**/*.png` | `src/Shared/Data/Images.luau` (generated header, flat keys, extensions stripped) |
| `assets/audio/**/*.{mp3,wav,ogg}` | `src/Shared/Data/Sounds.luau` |
| — | `asphalt.lock.toml` (upload state; committed) |

Invocation (verified from `asphalt --help` / `asphalt sync --help` at the pinned version — NOT wrapped in any npm script; run manually from the repo root):

```bash
asphalt sync --dry-run     # preview what would upload (agent-safe)
asphalt sync               # OWNER-EXECUTED: upload to Roblox cloud + regenerate Images/Sounds.luau
```

- Auth: `--api-key` flag or `ASPHALT_API_KEY` env var (note: a **different** variable than rblxsync's `ROBLOX_API_KEY`; whether `.env` carries it is typically UNVERIFIED — `.env` is unread by design).
- Uploads go to the creator group set in `asphalt.toml [creator]` — read it, do not assume.
- `--target studio` syncs to local Studio instead of cloud; `--target debug` for inspection.
- A cloud sync uploads real assets to the studio's group. Per the change taxonomy in **roblox-change-control** ("Asset (asphalt)" row), the live `asphalt sync` is **owner-executed**: agents run `asphalt sync --dry-run` only and hand off — the same pattern as `rblxsync run`.

## 6. Identity table (dev vs live) — how to build it for your project

Never quote universe/place IDs from memory. Each project keeps its identity constants in a shared game-data module (in the reference repo: a `GameData`-style module under `src/Shared/Data/Core/`). Build the table fresh:

1. Grep for the constants: `grep -rn "universeId\|placeId\|PlaceId" src/Shared/Data/`
2. Cross-check the deploy targets: `gh variable list -R <owner>/<repo>` — `DEV_*` variables should equal the dev IDs (deployed on push to main) and `PRODUCTION_*` the live IDs (push to production).
3. Cross-check `rblxsync.yml`'s `universe.id` against that table to know whether monetization syncs target dev or live.

Result: a table of dev vs live universe ID + one place ID per place. Record where each ID came from.

- A `game.PlaceId == 0` check (often exposed as an `isLocalFile`-style flag in the game-data module) is true when running an unpublished built .rbxl in Studio — the normal state of the local dev loop.

## 7. What output lands where

| Artifact | Produced by | Committed? |
|---|---|---|
| Per-place `.rbxl` files (repo root) | `npm run build:<place>` | No (`*.rbxl` gitignored; stray .rbxl files in root are usually old manual backups) |
| `sourcemap.json` | `npm run build:sourcemap` (also session-start hook — traps owned by roblox-build-and-env) | No |
| `src/Shared/Data/Monetization/Generated.luau` | `rblxsync run` (owner) | Yes |
| `rblxsync-lock.yml` | `rblxsync run` (owner) | Yes |
| `src/Shared/Data/Images.luau`, `Sounds.luau` | `asphalt sync` (owner) | Yes |
| `asphalt.lock.toml` | `asphalt sync` (owner) | Yes |
| `src/Shared/Config/Version.luau` | `version-updater.yml` in CI — it is machine-written; if it disagrees with `version.txt`, that is drift to flag, not to hand-fix silently | Yes |
| Moonwave docs site | `docs.yml` → studio docs repo (`firebit-dev.github.io/docs/<project>`) | External repo |
| Live place publish | `deploy.yml` on push to main/production | n/a |

## Common mistakes

- Editing `assets/environment/*` and expecting the connected Rojo session to show it — serve is code-only (`default.project.json`); rebuild the place.
- Running `rblxsync run` "to test" — it is a live mint against the universe in `rblxsync.yml`. Dry-run only; the live run is the owner's.
- Running `asphalt sync` (no flag) as an agent — a live asset upload to the studio's group is owner-executed (roblox-change-control taxonomy); `--dry-run` only.
- Pushing to origin main to "save work" — that is a deploy. Keep commits local (roblox-change-control).
- Assuming Generated.luau is hand-editable, or assuming all IDs flow from it at runtime — Generated is machine-written, and some ID classes may be hand-pasted elsewhere (see the badge case study in section 4). Trace consumers.
- Using `ROBLOX_API_KEY` for asphalt — asphalt wants `ASPHALT_API_KEY` (or `--api-key`).
- Uncommenting the universe name/description in `rblxsync.yml` without a fresh `ROBLOSECURITY` cookie — every subsequent run fails.
- Following a yml header's `rblxsync export --output ...` literally and expecting YAML — at 0.2.2, `export` emits Luau; use `rblxsync import` for yml reconciliation (diff before committing).
- Expecting CI to lint or format your push — a direct branch push runs no checks at all (main additionally triggers deploy/docs); both format and lint are effectively PR-only in the boilerplate, because `format.yml`'s push paths filter (`src`, not `src/**`) never matches files under `src/`. Confirm in the current project's copy.

## Provenance and maintenance

Derived 2026-07-05 from the firebit house-stack reference project. Project-specific state (IDs, product lists, flag values) was removed; only the shared conventions remain. Re-verify volatile facts **against the current project repo** (run from its root):

```bash
# npm scripts (dev loop, place names, .rbxl output names)
cat package.json
# CI truth
ls .github/workflows/ && cat .github/workflows/deploy.yml
# Deploy target repo variables (dev↔main, live↔production mapping)
gh variable list -R <owner>/<repo>
# Universe/place IDs (identity constants)
grep -rn "universeId\|placeId" src/Shared/Data/
# rblxsync target universe + commented-out metadata + header notes
sed -n '1,90p' rblxsync.yml
# rblxsync CLI subcommands/flags (version pinned in aftman.toml)
cat aftman.toml && rblxsync --help && rblxsync run --help
# asphalt inputs/outputs, creator group, and CLI
cat asphalt.toml && asphalt sync --help
# Studio MCP server definition + binary (macOS)
cat ~/.claude/plugins/roblox-testing/.mcp.json && ls /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP
# .env has the rblxsync key (do not print the value)
grep -c ROBLOX_API_KEY .env
# Version drift between source of truth and CI-written module
cat version.txt src/Shared/Config/Version.luau
```

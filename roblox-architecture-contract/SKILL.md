---
name: roblox-architecture-contract
description: Use when writing or reviewing code in a firebit house-stack Roblox project and the system's shape matters — service/controller boot order, where a new service goes, require cycles, "attempt to require a module that is loading", profile data not replicating, client sees stale state, choosing action networking vs Replica vs Attributes, hardcoded product/badge IDs, spawn ownership, persisted-schema key renames, or dormant flag-gated code that looks deletable.
---

# Roblox Architecture Contract (firebit house stack)

## Overview

Every firebit game project shares one architecture: Rojo + Wally + strict Luau, Bootstrap convention loading, ProfileDB/Replica persistence behind a single write choke point, red action networking, and rblxsync-generated monetization IDs. This skill is the list of load-bearing design decisions in that stack, WHY each exists, the invariants that must keep holding in the current project, and how to audit a project's weak points. Treat every decision here as intentional until you have evidence otherwise — most encode a past failure.

All commands below run from the current project's repo root and use house-structure paths. Before relying on any specific fact (a count, a file, a flag value), re-verify it in THIS repo with the given one-liner — never carry a number over from another project.

## When to use

- Before adding a service, controller, remote, data field, or replication path.
- When a change touches boot order, networking, profile data, spawning, monetization IDs, or a core game loop.
- When code looks wrong ("misspelled key", "dead engine behind a flag", "dev flag always on") and you are tempted to fix it.

## When NOT to use

- Deciding whether an action is allowed at all (push, rblxsync run, deleting legacy code, tuning numbers) → **roblox-change-control** owns the four hard rules.
- Per-flag catalog and how to add a config axis → **roblox-config-and-flags**.
- Bootstrap/toolchain/sourcemap problems → **roblox-build-and-env**.
- Roblox platform theory (why Attributes replicate, what ReplicatedFirst is) → **roblox-platform-reference**.
- Symptom-driven bug triage → **roblox-debugging-playbook**. History of why decisions were fought over → **roblox-failure-archaeology**.

## Boot narrative (60 seconds)

Jargon: **Rojo** syncs the filesystem into a Roblox place; **Wally** is the package manager (deps land in `Packages/`); **Luau** is Roblox's typed Lua; **red** is an action-based networking package; **ProfileDB/Replica** are the persistence and server→client data-sync packages.

Server: `src/Server/Entry.server.luau` runs `Attrify.start()` (attribute/tag-driven behavior watchers), then `Bootstrap.initServices(...)` and `Bootstrap.startServices(...)`. Client: `src/Client/Entry.client.luau` does the mirror with controllers. `src/Shared/Class/Bootstrap.luau` finds every `ModuleScript` whose **name contains** "Service" (or "Controller"), requires it in a `task.spawn`, and calls optional `init()` then `start()`. Consequences:

- Naming IS registration. A file named `FooService.luau` under `src/Server/Features/` boots automatically; nothing else wires it up. A helper module accidentally named `*Service` will also be required and booted.
- Each init/start runs in its own `task.spawn` — there is **no ordering guarantee between services**. Cross-service dependencies must be resolved lazily (require inside `start()`/first call) or by injection (decision 2 below).

Each game's loop (day cycles, rounds, waves, whatever the game runs on) is its own set of services under `src/Server/Features/`. Read those services directly — this skill covers the contract they all obey, not any one game's loop.

## Load-bearing decisions (house stack — verify each in the current repo)

| # | Decision | Where (house-standard location) | Why |
|---|----------|--------------------------------|-----|
| 1 | Convention-based boot: name-contains-Service/Controller, optional `init`/`start`, each in `task.spawn` | `src/Shared/Class/Bootstrap.luau` | Zero-registry wiring; adding a feature = adding a correctly named file |
| 2 | Provider injection instead of back-requires: when service A drives service B, A injects a callback/provider into B; B never requires A back | grep `Provider` setters across `src/Server` | Strict-mode Luau hard-fails on module require cycles at boot ("attempt to require a module that is loading"). Case study (shipped firebit game, 2026): the day-cycle service injects `setCurrentNightProvider` / `setCurrentPhaseProvider` into the wave and NPC services, with a comment stating the cycle rationale |
| 3 | `ProfileService` is the single profile-write choke point; out-of-band mutations MUST call `ProfileService.update(player, updatedKeys)` | `src/Server/Features/Core/ProfileService.luau` docstring declares it | Replica only replicates what you tell it; a silent direct write leaves the client stale forever |
| 4 | `update()` replication is coarse: it splits each dotted path but replicates the **whole top-level key subtree** via `replica:Set(firstKey, value)`, then fires the profile-updated signal (and syncs leaderstats for stat paths) | `ProfileService.update` in the same file | Coarse-grained by design — pass `"season.xp"` and the entire `season` table re-replicates. Size your top-level keys accordingly |
| 5 | red action networking; server receives only via handler modules mounted with `red.useHandlers(script.Parent.Handlers)`; per-handler server-side validation; `red.bind` sites are rare and deliberate | grep both patterns (invariants table below) | One networking idiom; validation lives next to the action it guards; no NEW raw RemoteEvents in `src/` — enumerate and pin your project's sanctioned exceptions |
| 6 | Three replication channels, each with a correct use (table below) | — | Prevents ad-hoc remotes and polling |
| 7 | Session-scoped vs persistent state is an explicit contract: with the standard `SaveInventory = false` flag, inventory is wiped at profile load AND before save; session currencies live in server memory, never in the profile | `src/Shared/Class/FeatureFlags.luau`, wipe blocks in `ProfileService` | Cross-session progression rewards must go through persisted currencies/XP only. Case study (shipped firebit game, 2026): runs are roguelike — in-run gear and the session currency reset every session, so a subscription's daily bonus had to pay persistent coins, not session scrap |
| 8 | If the project owns spawning: `Players.CharacterAutoLoads = false` in the place project JSON, and one service (PlayerService) spawns via CollectionService-tagged parts | place `*.project.json`, spawn-tag constant in `src/Shared/Data/` | Roblox default auto-respawn fights custom spawn/death logic (permadeath, revive-at-location) |
| 9 | Every gameplay gate is server-side first; the client copy is cosmetic. State that gates interaction is set by the server (often as an Attribute) and re-checked in the server handler | grep the gate attribute in the owning service | Client-side gating alone is exploitable. Case study (shipped firebit game, 2026): entering the defended vehicle at night would unanchor it and hand the client network ownership — the server sets a lock attribute AND refuses the enter request while locked |
| 10 | Monetization IDs resolve by NAME through generated code: `rblxsync run` writes `src/Shared/Data/Monetization/Generated.luau` ("Do not edit manually"); the sibling `init.luau` adds by-name lookups; misses warn loudly and return 0 | `src/Shared/Data/Monetization/{Generated,init}.luau` | rblxsync can reissue IDs; names are the stable key. Check how badges resolve in YOUR project — some projects hand-paste badge IDs into a data module as a sanctioned exception; a 0 ID means "not configured" and the award path must no-op with a warn |
| 11 | Terminal game-state transitions (game over, round end) are idempotent single fan-outs: a guard bool + one signal every subscriber shuts down from | the game-state service | The terminal condition can be reported from multiple paths; double-firing teardown corrupts everything downstream |
| 12 | Multiple Rojo projects, one codebase: `default.project.json` (slim dev: src + Packages + DevPackages + `version.txt` → `ReplicatedStorage.Version`) plus per-place build projects (e.g. `level.project.json`, `lobby.project.json`) that add assets and set a `ReplicatedStorage.Environment` StringValue; a place utility module reads it and services self-gate on it instead of forking the tree | repo root; `src/Shared/Modules/PlaceUtility.luau` | One codebase ships multiple places |
| 13 | Global strict typing: `.luaurc` sets `"languageMode": "strict"` — never add `--!strict` directives per file (redundant, per the project's CLAUDE.md; generated files are the exception) | `.luaurc` at repo root | Whole-repo type safety; also why require cycles hard-fail (decision 2) |

All projects mount `src/Server` → ServerScriptService, **`src/Client` → ReplicatedFirst** (not StarterPlayerScripts — client boots before replication finishes, hence the explicit loading screen in `Entry.client.luau`), `src/Shared` → `ReplicatedStorage.Shared`, `Packages` → `ReplicatedStorage.Packages`.

### The three replication channels — pick correctly

| Channel | Direction | Use for | Example |
|---|---|---|---|
| red actions (`red.dispatch` / handler modules) | both ways, event-shaped | Commands and one-shot events: purchases, phase broadcasts, claims | a phase-change broadcast, a revive request |
| Replica (profile replica, class `"Profile"`) | server→client, state-shaped | Persistent profile data the UI renders | the client data controller subscribes; UI reads client state |
| Instance Attributes | server→client, per-instance flags | Cheap per-instance state where a red round-trip is overkill; client reacts via `GetAttributeChangedSignal` | a lock flag on a vehicle, a subscription flag on the Player |

Do not add NEW raw RemoteEvents — red owns command networking. Enumerate your project's sanctioned `Instance.new("RemoteEvent")` sites once (`grep -rn 'Instance.new("Remote' src --include="*.luau"`), understand why each exists, and treat any change to that list as a review item. Case study (shipped firebit game, 2026): one sanctioned remote was a deliberate anti-exploit honeypot with an innocuous name — deleting "unused" remotes without reading them destroys traps like that.

## Invariants — each with its proof command

Run from the current project's repo root. If a check fails, either the invariant broke (treat as a bug) or this project deviates from the house stack (confirm with the owner and record it).

| Invariant | One-line verification |
|---|---|
| `red.bind` sites are few and known — pin the list | `grep -rn "red.bind(" src --include="*.luau"` |
| Server handlers all mount via `useHandlers` | `grep -rln "red.useHandlers" src/Server` |
| No unsanctioned raw remotes in src | `grep -rn 'Instance.new("Remote' src --include="*.luau"` → matches your pinned list |
| ProfileService is still the declared write choke point | `sed -n '1,10p' src/Server/Features/Core/ProfileService.luau` |
| Inventory wipe on load AND save while SaveInventory=false | `grep -n "SAVE_INVENTORY\|SaveInventory" src/Server/Features/Core/ProfileService.luau src/Shared/Class/FeatureFlags.luau` |
| Session currency never touches the profile | grep the currency's storage in its service — in-memory table, no profile writes |
| CharacterAutoLoads=false in shipping place projects (if project owns spawning) | `grep -n "CharacterAutoLoads" *.project.json` |
| Spawning only via tagged parts | grep the spawn-tag constant across `src/Server` and `src/Shared/Data` |
| Server re-checks gameplay gates in handlers | grep the gate attribute name in the owning service and its handlers |
| Provider injection still in place (no back-require of the driving service) | grep the provider setters, then grep the driving service's name in the driven services → only type/comment hits |
| Generated.luau is machine-owned | `head -3 src/Shared/Data/Monetization/Generated.luau` |
| Terminal-state fan-out is idempotent | read the game-state service's end-game function: guard bool + single signal |
| Strict mode global | `cat .luaurc` |

## Auditing a project's weak points

The reference implementation had six standing weak points; every house-stack project should be audited for the same classes. Run these and write the findings into the project's `docs/ARCHITECTURE.md` (doc-debt ledger: **roblox-docs-and-writing**).

1. **Test coverage gaps.** Services are usually verified only by playtests. `find src -name "*.spec.luau"` — if the list is nearly empty, say so plainly when asked about confidence. Evidence bar and test conventions: **roblox-validation-and-qa**.
2. **Doc drift on renames.** Renamed Rojo project files and moved modules leave stale references in `docs/ARCHITECTURE.md`. Trust the repo root over the doc; verify with `git log --diff-filter=R --name-status --oneline -- "*.project.json"` and grep the doc for old names. Learned in a shipped firebit game, 2026: the architecture doc referenced a build project file that had been renamed months earlier.
3. **Security hardening status.** Check `docs/plans/` for a security-hardening plan and count its unchecked boxes (`grep -c "\[ \]" docs/plans/<plan>.md`). Until server-side validation of damage, range, ownership, payload types, and fire rate is DONE (not planned), assume a hostile client can exploit the weapon/combat path.
4. **Dev-flag booby traps.** Any "is this production?" derivation from a place-ID constant is suspect: if the constant is a placeholder (e.g. `productionPlaceId = 0`), the flag evaluates wrong everywhere. Grep who consumes it before trusting it. Learned in a shipped firebit game, 2026: `ServerConfig.dev` evaluated true even in production because the production place ID was never filled in — harmless only because nothing consumed it yet. Details: **roblox-config-and-flags**; changing such a constant needs owner sign-off per **roblox-change-control**.
5. **Canonical misspellings in persisted schemas. Do NOT fix them.** A misspelled key in the DataTemplate/profile types is a key in every existing player's DataStore profile; renaming it orphans their data unless you write a migration. Spell it wrong, consistently. Find them: grep suspicious keys in `src/Shared/Data/Core/DataTemplate.luau` and the profile types file, and check both agree. Learned in a shipped firebit game, 2026: `proccessed_passes` [sic] lives in production profiles and must stay misspelled.
6. **Dormant flag-gated engines.** Whole subsystems (a round engine, a legacy mode) may be flag-gated off in FeatureFlags and deliberately kept. They are NOT the live game loop and NOT dead code — deletion is forbidden, see **roblox-change-control**. Learned in a shipped firebit game, 2026: a lobby minigame round base class was repeatedly misread as the main survival loop; the docstring, not the name, says what a class is for.

## Common mistakes

- Naming a plain helper module `*Service`/`*Controller` — Bootstrap will require and boot it.
- Requiring another service at module top level and assuming it initialized first — there is no boot order; require lazily or inject a provider (decision 2 is the template).
- Mutating profile data directly and forgetting `ProfileService.update()` — the server is right, the client is stale, and nothing errors.
- Persisting run-scoped progression as inventory items or session currency — it evaporates (`SaveInventory=false`, session currency is in-memory). Persistent rewards go through persisted currencies/XP only.
- Hand-editing `Monetization/Generated.luau` or hardcoding a freshly minted DevProduct ID — regenerated/reissued on the next `rblxsync run`. Only hand-paste IDs where your project has a sanctioned data-module exception (verify first).
- Gating purchases, entry, or revives on the client only — every gate is server-side first (decisions 5, 9); the client copy is cosmetic.
- Using `Instance.new` for UI or adding a raw RemoteEvent — React-only UI (see **luau-react**) and red-only networking.
- "Cleaning up" misspelled persisted keys or dormant flag-gated subsystems.
- Trusting a derived dev/production flag without reading how its place-ID constant is set.

## Provenance and maintenance

Derived 2026-07-05 from the firebit house-stack reference project; every decision and command was verified against that repo's working tree that day. Case studies are attributed and illustrative only — no instruction here depends on that repo or its git history existing.

Re-verification commands run against the CURRENT project repo, from its root:

```sh
grep -rn "red.bind(" src --include="*.luau"                     # pin this project's list
grep -rln "red.useHandlers" src/Server | wc -l                  # pin this project's count
grep -rn 'Instance.new("Remote' src --include="*.luau"          # matches the sanctioned list?
sed -n '1,10p' src/Server/Features/Core/ProfileService.luau     # choke-point docstring intact?
grep -n "SaveInventory\|SaveInStudio" src/Shared/Class/FeatureFlags.luau
head -3 src/Shared/Data/Monetization/Generated.luau             # machine-owned header intact?
cat .luaurc                                                     # strict mode global?
git log --diff-filter=R --name-status --oneline -- "*.project.json"  # doc-drift candidates
find src -name "*.spec.luau"                                    # test coverage reality check
```

Line numbers and counts drift with edits — re-grep the symbol rather than trusting a stale number. If any invariant check fails in a project, update that project's architecture notes AND raise it as a bug via **roblox-change-control**.

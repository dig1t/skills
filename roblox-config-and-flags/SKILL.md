---
name: roblox-config-and-flags
description: Use when touching any configuration axis in a house-stack Roblox project — feature flags (FeatureFlags class), file-local debug toggles, Studio/dev conditionals, rblxsync.yml products/passes/badges, Generated.luau monetization IDs, or tuning data modules. Also when a feature mysteriously won't turn on/off, a product ID resolves to 0, a "not in Monetization.Generated" warn fires, test inventory won't seed in Studio, or you need to add a flag, developer product, or badge.
---

# Roblox House Stack — Config and Flags

## Overview

In the house stack every switch is a plain Luau constant or a YAML entry — there is no remote config, no per-player rollout, no dashboard. Configuration lives on five axes: the FeatureFlags class, file-local debug constants, Studio/dev conditionals, the rblxsync monetization manifest, and tuning data modules. This skill explains each axis, how to build and re-verify a per-project catalog of it, and the checklists for adding new entries.

## When to use

- You need to know what a flag/constant does, or why a feature is on/off.
- You are adding a feature flag, a developer product, a game pass, or a badge.
- A monetization ID lookup warns and returns 0, or purchases silently no-op.
- Studio behaves differently from what you expect (seeding, saving, loading screens).
- You are building or refreshing the project's config catalog.

## When NOT to use

- **Changing a tuning VALUE** (prices, curves, NPC stats, round lengths): this skill tells you where the number lives, but changing it is gated — see **roblox-change-control** (rule 4: every tuning change needs rationale + predicted metric + evidence path).
- Running `rblxsync run` against the live universe, deploy/CI mechanics, universe/place IDs for the dev loop: **roblox-run-and-operate**. The live run itself is owner-only per **roblox-change-control** (rule 2).
- Build/bootstrap problems (aftman, wally, sourcemap): **roblox-build-and-env**.
- Why the architecture routes purchases/data the way it does: **roblox-architecture-contract**.
- rblxsync CLI generalities (auth, YAML schema): global **rblxsync** skill.

---

## 1. Feature flags — `src/Shared/Class/FeatureFlags.luau`

House-stack semantics (verify they hold in your project before relying on them):

- The module is a static in-memory boolean table with `get`/`set`/`setBulk`/`useModule`.
- In practice **no caller in `src/` calls the setters** — a flag's value is whatever is committed in the table. Confirm per project:
  `grep -rn 'FeatureFlags.set\|setBulk\|useModule' src --include='*.luau' | grep -v Class/FeatureFlags`
- `get` returns `flags[flag] == true`, so **querying an undeclared flag silently returns `false`** with no warning. This is the number-one flag trap (see Common mistakes).
- The module is shared — the same table serves server and client.

**Standard boilerplate flags** present in every house-stack project (by name and role — current values are per-project, read the table):

| Flag | Role |
| --- | --- |
| `SaveInStudio` | Allows DataStore writes during Studio sessions; typically also interacts with test-data seeding (see §3) |
| `SaveInventory` | Whether inventory persists across sessions; when false the profile load/save path wipes inventory (session-only by design) |
| `SkipLoadingScreenInStudio` | Skips the client loading screen in Studio |
| `HideTestItems` | Filters test-item entries from item catalogs in production |

Plus per-game flags for individual features, UI panels, and game modes.

**Build the project catalog.** For each flag record: name, committed value, status, and the verified call sites. Use three status buckets:

- **prod** — live gameplay path.
- **studio** — dev convenience, only affects Studio sessions.
- **dormant** — deliberately-off parked code. Protected by roblox-change-control rule 3: do NOT activate, refactor, or delete without owner sign-off.

Re-verify one-liners (repo root):

- Flag table + values: `sed -n '1,80p' src/Shared/Class/FeatureFlags.luau`
- Call-site census (catches undeclared flags): `grep -rhoP 'FeatureFlags.get\("\K[^"]+' -r src --include='*.luau' | sort | uniq -c` — then diff the names against the declared table. Any queried-but-undeclared flag is permanently `false`; if it sits in an active code path, adding the key flips real behavior — treat that as a tuning-class change.
- All call sites with context: `grep -rn 'FeatureFlags.get(' src --include='*.luau'`

> Case study (shipped firebit game, 2026): a flag `UseDownedState` was queried in the live weapon path but never declared — the feature had been silently off the whole time. Nobody noticed because `get` never errors. The census grep above is what found it.

## 2. Debug toggles (file-local constants)

House convention: debug switches are `local` constants near the top of their file (`DEBUG`, `DEBUG_PRINTS`, `DEBUG_MODE`, `*_DEBUG`, force-value overrides like `DEBUG_FORCE_*` or `TEST_*`). Flip them in-file for a debugging session; never commit a flip without a stated reason.

Build the project catalog with:

```
grep -rn "^local DEBUG\|_DEBUG\b\|DEBUG_\|TEST_" src --include='*.luau'
```

Record each hit: file:line, constant, committed value, effect when on. Three patterns to expect:

- **Print/visualization toggles** — log streams, state labels, path visualization. Harmless when on except for noise; the primary first-move for service triage (see **roblox-debugging-playbook**).
- **Behavior overrides** — e.g. a constant that short-circuits an ownership check ("treat everyone as owning the pass") or forces a specific spawn/roll outcome. These change gameplay; a committed `true` is a live anomaly.
- **Debug-shaped tuning values** — a tuning constant left at an obviously-test magnitude.

**Anomaly protocol:** when the catalog sweep finds a debug toggle or test-magnitude value committed as live, surface it to the owner — do NOT drive-by-fix it. Flipping it changes live behavior, and "restoring the obvious real value" is itself a tuning change (roblox-change-control rule 4). Run the sweep before any release build.

> Case study (shipped firebit game, 2026): a day-length constant was found committed at 2 seconds. Git history showed 20 → 180 → 202222 → 2 — a leftover test value, but the last intentional value was ambiguous. Unilaterally "fixing" it to 180 would have been a guess dressed as a fix; it went to the owner instead.

## 3. Studio / dev conditionals

Patterns to expect in a house-stack project (verify each in yours):

| Pattern | Typical shape | Watch for |
| --- | --- | --- |
| "Local file" detection | `RunService:IsStudio() and game.PlaceId == 0` — true only for an unpublished local .rbxl (the `npm run build:*` outputs; see roblox-build-and-env) | Fine as written; PlaceId ~= 0 in a published-place Studio session |
| "Dev environment" guards | A `ServerConfig`-style module comparing PlaceId against a production ID | **Verify the predicate before trusting it.** If the production ID is a 0 placeholder, the guard is true in production |
| DataStore skips in Studio | Services skipping GetDataStore/GetAsync when `IsStudio()`, often paired with an explicit "cannot do X in Studio" rejection | Skips are usually per-store, not global — e.g. MarketplaceService info fetches may be unguarded even where DataStores are skipped |
| Loading screen / FTUE skips | Gated on the §1 studio-convenience flags | — |

> Case study (shipped firebit game, 2026): a `ServerConfig.dev` boolean computed `PlaceId ~= productionPlaceId or IsStudio()` — but `productionPlaceId` was still 0, so `dev` was true on every published place including live production. It happened to have zero consumers, so it was inert, but any code using it as a "not production" guard would have opened dev behavior to live players.

**Studio test-data seeding trap.** In the house stack, `DataTemplate.luau` may contain a test-inventory seed gated on `IsStudio() and not FeatureFlags.get("SaveInStudio")`. Two flag interactions can make it never fire:

1. `SaveInStudio = true` makes the condition false.
2. Even if it seeded, `SaveInventory = false` makes ProfileService wipe inventory at profile load (and again before save) — any template-seeded inventory is destroyed.

Rule: to get test items into a Studio session, seed **after** profile load — inside ProfileService's load path, after the inventory wipe — never in DataTemplate.

Re-verify the interplay in your project:
`grep -rn 'SaveInStudio\|SaveInventory' src --include='*.luau' | grep -v Class/FeatureFlags`

## 4. rblxsync axis (monetization IDs)

**rblxsync** (pinned in `aftman.toml`; check the pin with `grep rblxsync aftman.toml`) declaratively syncs Roblox monetization objects from `rblxsync.yml` to the live universe via Open Cloud, then writes real IDs to a lock file and a generated Luau module. It matches existing objects **by NAME, case-sensitive** — a renamed entry creates a duplicate on the next run.

| File | Role |
| --- | --- |
| `rblxsync.yml` | Source of truth you edit: universe/creator IDs, game passes, developer products, badges, `badge_payment_source` |
| `rblxsync-lock.yml` | Written by `rblxsync run` — records live IDs. Committed. Read it (never the yml) when you need a real numeric ID |
| `src/Shared/Data/Monetization/Generated.luau` | Auto-generated Luau ("Do not edit"), regenerated each `rblxsync run`: typed `Universe`/`GamePasses`/`DeveloperProducts`/`Badges` tables with real IDs |

**Build the project catalog** — roster + prices from the yml, live IDs from the lock:

- Roster + prices: `grep -n '  - name:\|    price:' rblxsync.yml`
- Live IDs: `grep -n 'name:\|id:' rblxsync-lock.yml`
- Universe metadata section: check whether it is active or commented out — name/description sync requires cookie auth (`ROBLOSECURITY` in `.env`), and projects commonly run API-key-only, leaving universe metadata unmanaged.

**Consumption chain (house pattern — verify each link in your project):**

- `src/Shared/Data/Monetization/init.luau` wraps Generated with `devProductIdByName` / `gamePassIdByName` / `badgeIdByName`. **A name miss warns loudly and returns 0** — a typo or an un-synced product shows up as a console warn plus a purchase prompt for product id 0.
- `src/Server/Data/Products.luau` lists sellable products by name-lookup; game-pass data modules and UI components consume the same wrappers.
- Find all consumers: `grep -rn 'devProductIdByName\|gamePassIdByName\|badgeIdByName' src --include='*.luau'`
- **Audit for hardcoded IDs**: `grep -rn 'productId\s*=\s*[0-9]\|id\s*=\s*[0-9]\{8,\}' src --include='*.luau'`. Legacy hardcoded IDs may coexist with the by-name system, and they may point at OLD products that no longer match what the yml mints. Report the gap; do not silently "migrate" them — the live shop may be intentionally selling the legacy products (roblox-change-control rule 3).

**Badges exception (verify per project):** runtime badge awarding may NOT read Generated. In the reference implementation, BadgeService reads a hand-pasted ID table in `GameData` (`GameData.badges`), where `0` means "not configured" — the award path silently no-ops and a single startup warn lists all unconfigured badges. After minting a badge, pasting its ID into that table is mandatory. Check your project's award path:
`grep -rn 'badges\|BadgeService' src/Shared/Data/Core/GameData.luau src/Server --include='*.luau' | head -20`

**Hard rule (roblox-change-control rule 2): never run `rblxsync run` live.** Agents run `rblxsync validate` and `rblxsync run --dry-run` only. A live run creates real products on the live universe and minting badges costs real Robux (charged per `badge_payment_source`). Case-sensitive name matching means a bad run can also mint duplicates.

## 5. Tuning-data modules (the numbers surface)

House convention: gameplay numbers live in `XxxData.luau` / `XxxConfig.luau` modules under `src/Shared/Data/` (economy curves, reward tables, NPC stats, cycle lengths, movement constants, upgrade ladders). Changing any VALUE there is gated by **roblox-change-control** rule 4 (rationale + predicted metric + evidence path). This axis is for finding the knob, not turning it.

Build the project catalog: list each data module, what it owns, and its key values with `file:line` anchors. Values are line-level facts and WILL drift — always re-read the module (`sed -n '1,40p' <module path>`) before quoting a number.

Traps that recur across projects:

- **Identifier strings that key saved player data are not tuning values.** Renaming a season/period/rotation `id` string that keys a player's saved progress makes the active-period lookup mismatch saved data — the profile system resets that progress branch at next load. A rename IS a player-data reset; owner call.
  > Case study (shipped firebit game, 2026): a battle-pass season shipped with `id = "S1-test1"`. Renaming it to "S1" before launch would have reset every player's season progress via rollover-on-load — the "cleanup rename" was actually a destructive migration.
- **Index-aligned parallel tables.** Cost ladders paired with product-name ladders (e.g. escalating paid-retry prices) must stay index-aligned with each other AND with the prices in `rblxsync.yml`. The Luau side is usually display-only — the authoritative price lives on the DevProduct.
- **"Placeholder — tune freely" comments** do not exempt a change from rule 4; still cite a rationale.

## 6. How-to checklists

### Add a feature flag

1. Add `MyFlag = false,` to the table in `src/Shared/Class/FeatureFlags.luau` under the matching comment section (tabs, trailing comma, inline comment saying what it gates).
2. Gate code with `if not FeatureFlags.get("MyFlag") then return end` (early-return style). The module is shared — works on server and client.
3. Spelling is load-bearing: a typo'd name silently reads `false` with no warning. Grep your own call sites after writing them.
4. Plan-file and change-class rules apply as usual (see roblox-change-control and the project's CLAUDE.md for the plan lifecycle).

### Add a developer product (end-to-end)

1. **Declare:** add the entry under `developer_products:` in `rblxsync.yml` — `name` (this exact case-sensitive string is the join key everywhere), `description`, `price`. No `id` field; the sync assigns it.
2. **Validate locally:** `rblxsync validate` then `rblxsync run --dry-run`. Both are agent-safe.
3. **STOP — live mint is owner-only.** `rblxsync run` creates real products on the live universe (roblox-change-control rule 2). Hand off; do not run it unless the owner explicitly asked this session.
4. **After the owner runs it:** `rblxsync-lock.yml` and `Generated.luau` regenerate with the real ID. Verify: `grep "YourName" src/Shared/Data/Monetization/Generated.luau`.
5. **Server wiring (house pattern — confirm the exact registration API in your project's Shop/Marketplace feature before writing code):** add an entry to the product list in `src/Server/Data/Products.luau` with `id = Monetization.devProductIdByName("Your Name")`, a `type`, and an `action` string. In the owning service's `init`, register the receipt handler with the marketplace dispatcher (in the reference implementation: `MarketplaceData.registerCallback({ type = ..., action = ... }, handler)`; ProcessReceipt resolves the product by id and dispatches on type/action). Return `true` from the handler on success. Find working examples: `grep -rn 'registerCallback' src/Server --include='*.luau'`.
6. **Client display:** prompt with `MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)` where productId came through Products/Monetization by name — never a pasted literal.
7. Setting the price is an economy decision — rule 4 applies to the number itself.

### Add a badge

1. Add under `badges:` in `rblxsync.yml` (`name`, `description`, `icon:` pointing at the project's badge icon asset).
2. `rblxsync validate` / `--dry-run`, then STOP: minting a badge **costs real Robux** (charged per `badge_payment_source`) — owner-only.
3. After mint: if your project's award path reads a hand-pasted table (§4 badges exception — the reference implementation's `GameData.badges`), copy the numeric ID from `rblxsync-lock.yml` into it, matching the existing key style. This paste step is mandatory where the pattern applies — a missing/0 ID makes awarding silently no-op.
4. Award via the project's BadgeService feature, not raw Roblox BadgeService API calls.

## Common mistakes

- **Assuming a queried flag is declared.** `FeatureFlags.get` never errors; an undeclared flag reads `false` forever. Grep the table before trusting a call site (§1 census one-liner).
- **"Fixing" a committed debug toggle or test-magnitude value in passing.** Anomalies are worth surfacing, but flipping them changes live behavior — raise to owner, don't drive-by-fix (Karpathy rule 3: surgical changes).
- **Editing `Generated.luau` by hand.** It's overwritten on every `rblxsync run`. IDs enter code via by-name lookups (or the hand-pasted badge table where that pattern applies). Audit for legacy hardcoded-ID exceptions first (§4).
- **Renaming anything in rblxsync.yml.** Name IS the match key; a rename mints a duplicate on the live universe. Renames need the owner and probably `rblxsync export` reconciliation first.
- **Renaming an identifier string that keys saved player data.** It resets player progress on next login (§5).
- **Seeding Studio test data in DataTemplate.** Dead end when `SaveInStudio`/`SaveInventory` interact as in §3 — seed post-load in ProfileService.
- **Turning on a dormant flag "to see what happens."** That code is deliberately parked; activation needs owner sign-off (roblox-change-control rule 3).
- **Trusting a dev/production guard without reading its predicate.** A placeholder production ID can make "dev" true in production (§3 case study).

## Provenance and maintenance

Derived on 2026-07-05 from the firebit house-stack reference project. Structural claims (FeatureFlags semantics, Monetization wrapper behavior, rblxsync file roles, checklist wiring) were verified by reading that repo's files on that date; project-specific values and IDs were deliberately dropped. No claims are marked UNVERIFIED.

All re-verification commands run from the CURRENT project's repo root and must be re-run there before quoting any value — the catalogs this skill tells you to build are per-project artifacts:

| Volatile fact | Re-verify in current project |
| --- | --- |
| Flag table + values | `sed -n '1,80p' src/Shared/Class/FeatureFlags.luau` |
| Flag call-site census (incl. undeclared) | `grep -rhoP 'FeatureFlags.get\("\K[^"]+' -r src --include='*.luau' \| sort \| uniq -c` |
| No dynamic flag setters | `grep -rn 'FeatureFlags.set\|setBulk\|useModule' src --include='*.luau' \| grep -v Class/FeatureFlags` |
| Debug toggle catalog | `grep -rn "^local DEBUG\|_DEBUG\b\|DEBUG_\|TEST_" src --include='*.luau'` |
| Product/pass/badge roster + prices | `grep -n '  - name:\|    price:' rblxsync.yml` |
| Live IDs | `grep -n 'name:\|id:' rblxsync-lock.yml` |
| Universe metadata managed or not | read the `universe:` section of `rblxsync.yml` |
| Monetization by-name consumers | `grep -rn 'devProductIdByName\|gamePassIdByName\|badgeIdByName' src --include='*.luau'` |
| Hardcoded-ID exceptions | `grep -rn 'id\s*=\s*[0-9]\{8,\}' src --include='*.luau'` |
| Badge award path (Generated vs hand-pasted) | `grep -rn 'badgeIdByName\|badges' src/Server src/Shared/Data/Core --include='*.luau' \| grep -i badge \| head -20` |
| SaveInStudio/SaveInventory interplay | `grep -rn 'SaveInStudio\|SaveInventory' src --include='*.luau' \| grep -v Class/FeatureFlags` |
| rblxsync version pin | `grep rblxsync aftman.toml` |

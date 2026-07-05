---
name: roblox-platform-reference
description: Use when a task hits Roblox platform behavior rather than project logic — a placed model's rotation comes out flipped 180 degrees, CFrame/Euler math (Angles vs fromEulerAnglesYXZ, left-handed basis), a client tag handler finds nil children, StreamingEnabled quirks, DataStore session locks, ProcessReceipt / PurchaseGranted / NotProcessedYet / double-grant questions, DevProduct vs GamePass vs Subscription, Luau strict-mode narrowing errors, session-vs-persistent currency theory, or "look it up in brain".
---

# Roblox Platform Reference (house stack)

## Overview

This is the platform theory a mid-level engineer without Roblox background needs, scoped to what has actually bitten this studio's projects. Every claim is grounded in the house stack (the conventions shared across firebit game repos) or a named source; when the platform surprises you, check here before inventing a fix. Where a fact is project-specific (a flag value, a product name, a line number), this file gives you the one-liner to verify it in the current project rather than a stale answer.

## When to use / when NOT to use

**Use when:**
- Rotations or bases come out mirrored/flipped, or you're writing any CFrame math.
- A client-side handler sees a tagged instance but its children/parts are nil.
- You're touching profile load/save, purchases, receipts, or subscriptions.
- luau-lsp rejects code that "looks fine" (optional narrowing, iteration types).
- You need economy rationale (session vs persistent currency, discovery weighting).
- You need exact Roblox API signatures → follow the brain protocol in section 8.

**NOT for:**
- The history of how these lessons were learned → `roblox-failure-archaeology`.
- Which invariants the current project's code enforces and where → `roblox-architecture-contract`.
- How to run/build/sync anything → `roblox-build-and-env`, `roblox-run-and-operate`.
- Whether you're allowed to change a number or mint a product → `roblox-change-control` (owns the four hard rules).
- Debugging a specific live symptom → `roblox-debugging-playbook`.
- React component depth → skill `luau-react`.

---

## 1. CFrame math essentials

A **CFrame** is Roblox's 4x3 rigid transform (position + rotation matrix). Roblox is **right-handed**: +X = right, +Y = up, **-Z = forward** (`LookVector` is the negated third column). `CFrame.fromMatrix(pos, right, up, back)` takes **back** (+Z), not forward, as its third axis.

### Handedness — the rule a whole incident paid for

To build a basis from an up vector, the cross-product order decides handedness:

| Construction | Result |
|---|---|
| `right = FORWARD:Cross(up)`; `back = right:Cross(up)` | right-handed — correct |
| `right = up:Cross(FORWARD)` | **left-handed (mirrored)** — wrong |

The trap that makes this insidious: **Roblox's network serialization normalizes CFrames to right-handed**, silently flipping the RightVector of a left-handed basis in transit. So a left-handed CFrame *looks correct on whichever peer received it over the network* and is 180° wrong on the peer that computed it locally. Server (local math) and client (post-network) disagree and each side's logs look self-consistent.

Case study (learned in a shipped firebit game, 2026): surface-aligned trap placement was mirrored 180° for the placer but rendered correctly for everyone else — the basis was built with `up:Cross(FORWARD)` and the network "fixed" it on every peer except the one that computed it. Full incident chronicle: `roblox-failure-archaeology`.

**Rule:** always construct `right = WORLD_FORWARD:Cross(up)` (with a fallback axis when parallel), normalize, then `back = right:Cross(up)`. House convention: keep exactly one shared surface-alignment module under `src/Shared/Modules/` and reuse it — never re-derive the basis math per feature. Find the project's canonical implementation: `grep -rln "Cross(up)\|fromMatrix" src/Shared/Modules/`.

### Euler order — XYZ vs YXZ

Roblox has two Euler conventions and they do not mix:

| API | Order | Pairs with |
|---|---|---|
| `CFrame.Angles(x, y, z)` (= `fromEulerAnglesXYZ`) | applies X, then Y, then Z | `ToEulerAnglesXYZ()` |
| `CFrame.fromEulerAnglesYXZ(rx, ry, rz)` | applies Y (yaw) first, then X, then Z | `ToEulerAnglesYXZ()` (returns `rx, ry, rz`) |

The `YXZ` suffix names the rotation **application** order, not the argument order — arguments and returns are always positionally `(rx, ry, rz)`. If a project's payload fields are named `rY, rX, rZ` or similar, treat them as positional labels for that same `(rx, ry, rz)` tuple; the roundtrip works because it is strictly positional. Do not treat the first value as yaw.

The inverse of `cframe:ToEulerAnglesYXZ()` is `CFrame.fromEulerAnglesYXZ` — **not** `CFrame.Angles`. Mixing them flips Y orientation.

### Orientation over the wire

House pattern (settled after the incident above): send orientation as a **position table + YXZ Euler table** (e.g. `{x,y,z}` + `{rx,ry,rz}`) and rebuild the CFrame on the server — never send raw CFrames or basis vectors, because serialization can rewrite them. Find the project's reference payload validation: `grep -rln "fromEulerAnglesYXZ" src/Server/`.

### Pivot gotchas (theory only; history in roblox-failure-archaeology)

- `Model:PivotTo()` on an **unparented** Model can leave descendants at their original CFrames. Parent first, then pivot.
- An asset's `WorldPivot` is authored data and may be rotated relative to `PrimaryPart`. When you need pivot == primary part, set `model.WorldPivot = primaryPart.CFrame` before `PivotTo`.

---

## 2. Replication model

**Replication** = the engine automatically copying server-side Instances to clients. Two properties matter here:

1. **It is not atomic.** A Model, its CollectionService tags, and its attributes can arrive on the client **before its child parts** (and before *their* tags). A tag-added handler that fires on the Model and immediately does a one-shot `FindFirstChild`/descendant scan will get nil and never retry — that exact bug shipped in a firebit game (pickup prompts never appeared on multi-part placed objects).
2. **StreamingEnabled** is on by default in the house place projects (`StreamingEnabled: true`, `StreamingIntegrityMode: "PauseOutsideLoadedArea"`, `StreamingMinRadius: 256` in the per-place `*.project.json` files — verify the current project's values with `grep -n Streaming *.project.json`). Under streaming, workspace parts outside the radius may not exist on the client at all, can stream **in late** or **out again**, and an unbounded `WaitForChild` on a streamed-out instance hangs forever.

**The tolerant-client pattern** (copy the project's existing implementation, don't invent): a `waitForX` helper that tries a resolve, then does a bounded poll (`task.wait()` loop with a hard deadline, ~5s), bails if `model.Parent == nil` (removed mid-wait), and keeps a `_pending` set so a duplicate tag-added fire doesn't spawn a second waiter. Find one: `grep -rln "GetInstanceAddedSignal" src/Client/`.

Checklist for any client handler keyed on `CollectionService:GetInstanceAddedSignal(tag)`:

- [ ] Never assume children/attributes of the tagged instance exist yet.
- [ ] Poll with a deadline; never `WaitForChild` without a timeout.
- [ ] Handle the instance disappearing mid-wait (streamed out / destroyed).
- [ ] Dedupe in-flight waiters per instance.
- [ ] Also process instances tagged *before* your handler connected (`GetTagged(tag)` sweep on start).

Note the house topology: `src/Client` is mounted under **ReplicatedFirst** (see the project's `default.project.json` / place projects), which replicates before the rest of the game — client code can run while the world is still arriving.

---

## 3. Persistence semantics

**DataStore** = Roblox's per-experience key-value persistence (eventually consistent, budget-limited). House stack: profiles persist through the vendored Wally package **ProfileDB** (`Packages/_Index/dig1t_profiledb@<version>/profiledb/init.luau`), fronted by a single choke point, `src/Server/Features/Core/ProfileService.luau` — all writes go through it (ownership of that invariant: `roblox-architecture-contract`).

### Session locking as ProfileDB implements it

Session locking prevents two servers from saving the same player's data concurrently (the classic cause of item-dupe exploits and rollback).

- On load, ProfileDB stamps `sessionData = { lastUpdate = ISO now, jobId = game.JobId }` into the profile and saves.
- Another server loading the same profile is supposed to wait `SESSION_CHECK_INTERVAL = 8`s per retry, force-unlocking after `SESSION_LOCK_TIMEOUT = 60`s.
- **Observed quirk (read the vendored code before relying on the lock):** as read in ProfileDB 1.0.10 (2026-07-05), the still-locked check compares `DateTime.fromIsoDate(lastUpdate).UnixTimestampMillis < SESSION_LOCK_TIMEOUT` — epoch **milliseconds** against the number 60 — which is false for any real timestamp, so as written the "wait for lock" branch effectively never triggers and a second server takes the session over immediately. Re-verify in the current project's vendored copy: `grep -n "fromIsoDate" Packages/_Index/dig1t_profiledb@*/profiledb/init.luau`. If this matters to your change, raise it via `roblox-architecture-contract` / `roblox-change-control` rather than patching the vendored package ad hoc.
- **Release on leave (house pattern):** the player-lifecycle service calls `ProfileService.save(player, true)` on PlayerRemoving; the release flag flows into `profile:Save(releaseSession)` which strips `sessionData` before writing, then the local profile and its Replica are destroyed.
- **Fail-safe posture:** any load/decode failure sets `saveToDataStore = false` — the player gets template data and *nothing is written back*, so a bad session can't overwrite good data. Version writes are two-phase: profile blob under a new version key, then a version-record write; if the version record fails, saving is disabled (ProfileDB's own comment: "to prevent developer products from being lost"). Profile-load failure kicks the player.

### Receipt lifecycle — the ProcessReceipt contract

`MarketplaceService.ProcessReceipt` is the **single server-wide callback** Roblox invokes for every Developer Product purchase. The platform contract:

| You return | Roblox does |
|---|---|
| `Enum.ProductPurchaseDecision.PurchaseGranted` | Marks the receipt consumed. Final — never re-fires. |
| `Enum.ProductPurchaseDecision.NotProcessedYet` | Retries later — including on the player's **next join, possibly on another server** |
| (error / no return) | Treated as NotProcessedYet |

Consequences you must design for:
- **Idempotency is mandatory.** Roblox may invoke ProcessReceipt more than once for the same `PurchaseId`. Grant-then-crash before recording = double grant on retry.
- **Crash windows:** the danger zone is between "granted the goods" and "durably saved the fact you granted them". Only return `PurchaseGranted` after the grant is recorded.
- Old receipts eventually stop retrying (commonly cited as ~14 days — UNVERIFIED exact platform window as of 2026-07-05; treat "old receipts eventually stop retrying" as the operative fact and don't design flows that depend on indefinite retry).

The house receipt-processing pattern (find the project's implementation: `grep -rln "ProcessReceipt" src/Server/`), in order:

1. In-progress dedupe by `PurchaseId` (an in-memory set).
2. Player-present check — absent ⇒ `NotProcessedYet` (retries on next join).
3. **Profile ledger idempotency**: `profileData.purchases[PurchaseId]` already set ⇒ immediate `PurchaseGranted`.
4. **Unsaved-receipt retry ledger**: receipts granted but not yet durably saved sit in `profileData.unsaved` and get promoted to `purchases` with a forced `ProfileService.save`.
5. Product lookup by name/id through the shared products module; ownership-limit check.
6. Dispatch to callbacks registered per `{type, action}`; **any callback returning false ⇒ NotProcessedYet** — the whole receipt replays, so every callback must itself be idempotent.
7. Record `purchases[PurchaseId]`, force-save, and only then return `PurchaseGranted`; a save failure demotes the record back to `unsaved` and returns `NotProcessedYet`.

**Context-bearing purchases:** state that must survive until the receipt lands (e.g. in a shipped firebit game, *which* dead ally a paid revive targets) is stashed server-side via a `setPendingPurchase(productId, player, data)`-style call before the client is told to prompt, and read back inside the callback. Pending entries are wiped on PlayerRemoving.

---

## 4. Monetization platform surfaces

| Surface | Purchase model | Ownership check | Delivery | Created by |
|---|---|---|---|---|
| **Developer Product** | Consumable, repeatable | none (it's consumed) | `ProcessReceipt` (section 3) | `rblxsync run` (owner act — see `roblox-change-control`) |
| **Game Pass** | One-time, permanent | `UserOwnsGamePassAsync` (house stack wraps it via the `dig1t/GamePass` package) | apply perk whenever owned; no receipt | `rblxsync run` |
| **Subscription** | Recurring (monthly) | `GetUserSubscriptionStatusAsync`, refreshed by `PromptSubscriptionPurchaseFinished` | poll/cache status; no receipt | **manual Creator Hub only** — no Open Cloud/rblxsync API |

Facts that shape house code:

- **IDs resolve by NAME, never hardcoded numbers.** `rblxsync run` regenerates `src/Shared/Data/Monetization/Generated.luau`; runtime lookups go through name-based helpers in the shared Monetization module (e.g. `Monetization.devProductIdByName("...")`), which warn and return `0` on a miss. Client purchase paths must guard `productId == 0` and skip the prompt. List the current project's minted names: `grep -n "Name = " src/Shared/Data/Monetization/Generated.luau`. Sync mechanics: `roblox-run-and-operate`; the never-run-live rule: `roblox-change-control`.
- **The server picks product IDs for anything contextual.** Case study (shipped firebit game, escalating-revive ladder): the server selects which price rung to prompt based on the player's paid-revive count, stashes the target via the pending-purchase mechanism, and only then tells the client to call `MarketplaceService:PromptProductPurchase`. The client choosing a product id would let an exploiter buy the cheap rung forever. For context-free products the client may resolve the id by name from the shared Generated table — same source of truth either way.
- **Subscriptions cannot be minted programmatically.** The house pattern is a hand-maintained data module holding the Creator-Hub-pasted subscription id, with every consumer no-oping while it's unset. Check whether the current project has one and whether it's set: `grep -rn "SUBSCRIPTION_ID" src/Shared/`.
- Prompt calls (`PromptProductPurchase`, `PromptGamePassPurchase`, `PromptSubscriptionPurchase`) are client-side UI triggers only; all granting is server-side.

---

## 5. Luau strict-mode limits that shaped house code

`.luaurc` enforces strict mode repo-wide in house projects (so no `--!strict` directives — the project's CLAUDE.md owns the style rules). A full-codebase luau-lsp cleanup in a shipped firebit game (2026) established these workarounds; reach for them instead of fighting the solver:

| Solver limit | Workaround |
|---|---|
| Won't narrow `T?` → `T` across tuple-assign or reassign-in-branch | After the nil-guard, copy into a **fresh non-optional local** and use that |
| Direct iteration (`for k, v in obj`) over a metatable-typed table yields a subtly different type than `pairs()` | Wrap in `pairs()` to match existing code |
| Require cycles poison the **type graph** even when runtime order is fine | Break exactly one edge with `(require :: any)(path)`. For *runtime* cycles the house pattern is provider injection instead (see `roblox-architecture-contract`) |
| Base-class return types hide subclass properties | Return the most-derived class you construct (e.g. `Part`, not `BasePart`, when callers set `.Shape`) |
| Union property writes / instance unions | Split into per-`IsA` branches; cast `Instance` → `PVInstance` etc. explicitly |

Deeper type-system help: skill `luau-type-expert`.

---

## 6. React Lua 17 — pointers only

House UI is React-only: jsdotlua `react`/`react-roblox` 17.x via Wally, `React.createElement` aliased `e`, no JSX. Depth lives elsewhere — do not learn React Lua from this file:

- Skill **`luau-react`** — house component/hook conventions.
- `/Users/dig1t/Git/brain/reference/development/roblox/react-lua/deviations.md` + `api-reference/` — canonical React-Lua-vs-React-JS differences.
- `/Users/dig1t/Git/brain/obsidian/brain/knowledge/skills/react-lua-roblox-quirks.md` — distilled quirks (table keys, bindings, `React.Event`, reserved props).
- Storybook conventions: `roblox-validation-and-qa`.

---

## 7. Economy and discovery theory as adopted by the house

- **Discovery weighting (the "why" behind retention-first roadmaps):** Roblox's Recommended-For-You algorithm weights **28-day player value** — D1 return, D2-7 return, D8-28 engagement, session quality, and spend — rather than first-click/first-session signals. Monetization remains a heavy gatekeeper: high-retention games stall in discovery when monetization percentile lags. If the current project has an economy/retention strategy plan under `docs/plans/`, read it before proposing any economy feature.
- **Sources/sinks discipline (house two-currency pattern):** a **session currency** lives in an in-memory server table (house home: a `CurrencyService` under `src/Server/Features/Core/`), is dropped on leave, and is never persisted — it makes each run self-contained (die, restart, re-earn). A **persistent currency** lives in the profile (e.g. `stats.coins`) and carries meta-progression; it is the monetization anchor.
- **Persistence is flag-gated — check before paying rewards.** If the project's `SaveInventory` feature flag is `false`, inventory item rewards do NOT persist and are silently discarded on leave — anything meant to persist must pay out in persistent currency or XP, never items. Check the current values: `grep -n "SaveInStudio\|SaveInventory" src/Shared/Class/FeatureFlags.luau`.
- **Any change to actual numbers** (prices, rewards, multipliers, difficulty) is gated — `roblox-change-control` owns that rule. Analysis recipes for justifying a tuning change: `roblox-proof-and-analysis-toolkit`.

---

## 8. Going deeper: the brain retrieval protocol

`/Users/dig1t/Git/brain` is the studio-wide on-disk knowledge repo (optional deepening — everything load-bearing is embedded above). Protocol, per its own CLAUDE.md:

1. Read `/Users/dig1t/Git/brain/obsidian/brain/knowledge/index.md` first (page catalog).
2. Exact engine signatures/enums: grep `/Users/dig1t/Git/brain/reference/development/roblox/api/` (engine YAML under `api/engine/{classes,enums,datatypes,libraries}/`, Open Cloud under `api/cloud/`).
3. Official how-to guides: grep `/Users/dig1t/Git/brain/obsidian/brain/reference-roblox/` (e.g. `production/monetization/subscriptions.md`, `production/analytics/retention.md`).
4. **Never edit** `reference/` or `reference-roblox*/` — immutable raw sources.

Highest-value pages for this domain: `knowledge/skills/data-persistence-and-monetization.md`, `knowledge/skills/client-server-networking.md`, `knowledge/concepts/roblox-discovery-algorithm.md`, `knowledge/concepts/roblox-revenue-model.md`.

---

## Common mistakes

1. **Building a basis with `up:Cross(forward)`** and concluding it's fine because the *client* renders it correctly — the network flipped it for you; the server's copy is mirrored. Use the project's shared surface-alignment module.
2. **Round-tripping `ToEulerAnglesYXZ` through `CFrame.Angles`** — different axis order; Y ends up flipped.
3. **One-shot resolving children in a tag-added handler** — tags outrun children; poll with a deadline and a dedupe set (section 2).
4. **Returning `PurchaseGranted` before the grant is durably recorded** — a crash in that window double-grants on retry. Mirror the `purchases`/`unsaved` ledger pattern.
5. **Writing a non-idempotent receipt callback** — `NotProcessedYet` replays *all* callbacks for the receipt, not just the failed one.
6. **Hardcoding a product/pass/badge numeric ID** — IDs are regenerated by rblxsync and differ per mint (and per project); resolve by name and guard `== 0`.
7. **Letting the client pick the product ID for contextual purchases** (escalating price ladders etc.) — server picks, stashes context, then prompts.
8. **Fighting the strict solver** with `:: any` sprinkled everywhere instead of the five sanctioned patterns in section 5.
9. **Assuming the ProfileDB session lock will save you from concurrent sessions** — read section 3's observed quirk first.
10. **Paying persistent rewards in inventory items while `SaveInventory` is false** — they're silently discarded; pay persistent currency or XP.

## Provenance and maintenance

Derived 2026-07-05 from the firebit house-stack reference project; platform facts are engine behavior and transfer as-is, house patterns assume the shared project structure. Re-verify volatile or project-specific facts **against the CURRENT project repo** (all paths repo-root-relative):

| Fact | Re-verify with |
|---|---|
| Streaming settings | `grep -n Streaming *.project.json` |
| Shared surface-alignment module exists | `grep -rln "fromMatrix\|Cross(up)" src/Shared/Modules/` |
| YXZ wire rule in placement handlers | `grep -rn "fromEulerAnglesYXZ" src/Server/` |
| Bounded-poll tolerant-client pattern | `grep -rn "GetInstanceAddedSignal" src/Client/` |
| ProfileDB version + session-lock quirk | `grep -n "SESSION_LOCK_TIMEOUT\|fromIsoDate" Packages/_Index/dig1t_profiledb@*/profiledb/init.luau` |
| Release-on-leave | `grep -rn "ProfileService.save(player, true)" src/Server/` |
| Receipt flow implementation | `grep -rln "ProcessReceipt" src/Server/` |
| Subscription id module (volatile) | `grep -rn "SUBSCRIPTION_ID" src/Shared/` |
| Feature flag values (volatile) | `grep -n "SaveInStudio\|SaveInventory" src/Shared/Class/FeatureFlags.luau` |
| Minted product names (volatile) | `grep -n "Name = " src/Shared/Data/Monetization/Generated.luau` |
| Client mounted under ReplicatedFirst | `grep -n -A2 ReplicatedFirst default.project.json *.project.json` |
| Brain protocol | `sed -n '40,55p' /Users/dig1t/Git/brain/CLAUDE.md` |

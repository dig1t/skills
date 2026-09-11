---
name: luau-roblox-optimizer
description: Use when reviewing, debugging, or optimizing Luau scripts written directly in Roblox Studio (no Rojo, no VS Code) - memory leaks, dangling connections, client/server mistakes, exploitable RemoteEvents, lag from wait() or polling loops, animation scripts that stutter or stack, DataStore data loss, or "why does my script break on respawn / when a player leaves".
---

# Luau Roblox Optimizer

Review checklist for scripts that live inside Roblox Studio. Every item names
the symptom, the cause, and the one-line fix. Studio-only means: no external
tooling, no file layout advice, no `--!strict` lectures. Script Analysis,
the Output window, the Developer Console (F9), and MicroProfiler (Ctrl+F6)
are the whole toolkit.

## Review output

A review IS, in this order:

1. **Exploits and data loss** - anything a client can abuse or that drops
   saved data.
2. **Crashes** - nil indexes, races, errors that stop the script.
3. **Leaks** - connections, threads, and tables that outlive their owner.
4. **Performance** - work done more often than needed.
5. **Animation and DataStore hygiene** - the two areas below.

Each finding is one line: `line N - what breaks - fix`. Items that need the
whole file to change (adopt a framework, restructure folders) are out of
scope for a Studio review.

## Scan triggers

Walk the file once. Each token below opens a fixed set of checks; report
every check that fails, even when the same line already has a worse finding.

| Seeing | Check |
|---|---|
| `Touched` | debounce, `hit` may be an Accessory handle, connection cleaned when the part goes |
| `OnServerEvent`, `OnServerInvoke` | arg types and ranges, cooldown, player data may not be loaded yet |
| `PlayerAdded` | load inside `pcall`, not-loaded flag, table entry cleared in `PlayerRemoving` |
| `CharacterAdded` | every connection, loop, and track has a `CharacterRemoving` or `Died` cleanup |
| `LoadAnimation` | called on an Animator, loaded once per character, has a matching `Stop` |
| `GetAsync`, `SetAsync` | `pcall`, retry, `BindToClose`, `UpdateAsync` for merges |
| `wait(`, `spawn(`, `delay(`, `while true` | `task.*`, an event instead of polling, an exit condition |
| `game.Players`, `game.Workspace`, any `game.X` | `game:GetService` cached at the top |

## 1. Client/server mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Exploiters give themselves items or coins | Server reads an amount, id, or position from `OnServerEvent` args | Server computes the value itself; client sends intent only (`"buyItem", itemId`) |
| Remote handler errors on odd input | No type or range check on args | `if typeof(amount) ~= "number" or amount < 1 or amount > MAX then return end` |
| Remote spam lags the server | No cooldown | Track `lastFire[player] = os.clock()`; drop calls inside the cooldown |
| Script runs nowhere | LocalScript in ServerScriptService, or Script in StarterPlayerScripts | LocalScripts: StarterPlayerScripts, StarterCharacterScripts, StarterGui, StarterPack. Scripts: ServerScriptService, Workspace. ModuleScripts: ReplicatedStorage (shared) or ServerStorage (server only) |
| Client change doesn't show for others | Client edits Workspace directly | Client fires a RemoteEvent; server makes the change |
| Remote is nil on the client | Created by a Script after the LocalScript looked for it | Put RemoteEvents in ReplicatedStorage in the Explorer, not `Instance.new` at runtime, and `WaitForChild` on the client |

## 2. Bugs that crash on respawn or leave

| Symptom | Cause | Fix |
|---|---|---|
| `attempt to index nil` on `playerData[player]` | Remote or Touched fires before the async load in PlayerAdded finishes | Guard: `local data = playerData[player]; if not data then return end` |
| `attempt to perform arithmetic on nil` after leave | `PlayerRemoving` reads a table entry that never loaded | Same guard; never save when the load failed |
| Works in Play Solo, breaks in Team Test or live | Script assumes the character exists at start | `player.Character or player.CharacterAdded:Wait()` |
| Touched gives 2 to 5 pickups per coin | `Touched` fires once per limb | Debounce: `if coin:GetAttribute("Taken") then return end; coin:SetAttribute("Taken", true)` before awarding |
| Pickup ignores hats and tools | `hit.Parent` is the Accessory, not the character | `local char = hit:FindFirstAncestorOfClass("Model")` then `Players:GetPlayerFromCharacter(char)` |
| `Workspace.Folder.Part is not a valid member` | Dot chain runs before the part streams or loads | `WaitForChild` on the client; `FindFirstChild` plus a nil check on the server |
| Script errors once then goes silent | Error thrown inside a connection handler kills only that call, but an error at top level stops the whole script | Move setup into functions; wrap risky calls in `pcall` |

## 3. Memory leaks

| Symptom | Cause | Fix |
|---|---|---|
| Server memory climbs every respawn | `CharacterAdded` connects Heartbeat, Touched, or a `while true` loop and never stops it | Store the connection; disconnect in `CharacterRemoving` or `humanoid.Died`. Loops: `while character.Parent do` |
| Memory climbs per player who joined | Table keyed by `Player` never cleared | `playerData[player] = nil` in `PlayerRemoving` |
| Parts pile up invisibly | `part.Parent = nil` instead of `part:Destroy()` | `Destroy()` disconnects events and frees the instance |
| Tweens or tracks keep running on destroyed objects | Track or tween created per spawn, never stopped | Stop and destroy in `CharacterRemoving`, or keep one per character |
| Sounds and particles stack | `Instance.new` every event, never cleaned | Reuse one instance, or `Debris:AddItem(inst, seconds)` |

Rule of thumb: every `Connect`, `task.spawn`, `while`, `Instance.new`, and
`LoadAnimation` inside a `PlayerAdded` or `CharacterAdded` handler needs a
matching cleanup in `PlayerRemoving` or `CharacterRemoving`.

## 4. Performance

| Symptom | Cause | Fix |
|---|---|---|
| Everything slows under load | `wait()`, `spawn()`, `delay()` | `task.wait()`, `task.spawn()`, `task.delay()` |
| Script Performance window shows one script at the top | `FindFirstChild`, `GetChildren`, `GetDescendants`, or `game:GetService` inside Heartbeat or a tight loop | Cache references once above the loop |
| Polling loop per player | `while true do task.wait(0.1) if humanoid.MoveDirection ...` | Use the event: `humanoid.Running`, `humanoid.StateChanged`, `part:GetPropertyChangedSignal("Value")` |
| Heartbeat handler does work every frame | No throttle | Accumulate `dt` and run every 0.2 to 0.5s |
| String building lags | `s = s .. x` in a loop | Collect into a table, `table.concat` |
| Physics lag with static builds | Unanchored decorative parts | `Anchored = true` on anything that never moves |
| Low FPS on big maps | StreamingEnabled off | Turn it on in Workspace properties; guard client code for parts being nil |
| Unknown cause | Guessing | Ctrl+F6 MicroProfiler, Ctrl+P to pause a frame, find the wide bar. Wrap suspects in `debug.profilebegin("Name")` / `debug.profileend()` |

## 5. Studio-specific anti-patterns

- `game.Players`, `game.ReplicatedStorage` as dot access. Works, but
  `game:GetService("Players")` is the documented path and survives renames.
  Cache it once at the top of the script.
- `Instance.new("Part", workspace)`. The parent argument replicates every
  later property change one at a time. Set properties first, `Parent` last.
- A script inside a Workspace part that assumes `script.Parent` is ready.
  It is, but duplicated parts run duplicated scripts. Prefer one script in
  ServerScriptService that loops over a folder or a CollectionService tag.
- Logic in a ScreenGui with `ResetOnSpawn = true`. The LocalScript restarts
  on every respawn and reconnects everything. Set `ResetOnSpawn = false`
  unless the UI must reset.
- `while wait() do`. Yields the whole script; use an event or `task.wait`.
- `print` in Heartbeat. The Output window itself becomes the bottleneck.
- Testing DataStores in Play mode without Game Settings > Security > Enable
  Studio Access to API Services. Calls error with 403 and nothing saves.

## 6. Animation scripts

| Symptom | Cause | Fix |
|---|---|---|
| Deprecation warning, animation may not replicate | `humanoid:LoadAnimation(anim)` | `humanoid:WaitForChild("Animator"):LoadAnimation(anim)` |
| Animation stacks or stutters | `LoadAnimation` called every time the action fires | Load once per character, store the track, reuse it |
| Animation never stops | Only `Play` is called | `track:Stop()` on the opposite event (`Running` speed 0, tool unequipped, `Died`) |
| Walk overrides the attack | Wrong `Priority` | `track.Priority = Enum.AnimationPriority.Action` |
| Animation plays once and freezes | `Looped` unset for an idle | `track.Looped = true` for idles; leave false for one-shots |
| Works for you, invisible for others | Animation asset not owned by the game owner or group | Re-upload under the account or group that owns the place |
| Lag before the animation shows | Player animations loaded on the server | Load and play player-character animations in a LocalScript; the engine replicates them |
| Tracks pile up | Never destroyed | `track:Destroy()` in `CharacterRemoving`, or rely on one-per-character reuse |

## 7. DataStore review

| Symptom | Cause | Fix |
|---|---|---|
| Script errors with "Request was throttled" or HTTP 5xx | Bare `GetAsync` or `SetAsync` | Wrap every call in `pcall`; retry up to 3 times with `task.wait(2 ^ attempt)` |
| Player data resets to default | Load failed, script fell back to defaults, then saved them | If the load pcall fails, mark the player as not loaded and skip the save |
| Coins lost on server shutdown | Only saving in `PlayerRemoving` | Add `game:BindToClose(function() for each player: save end)`; in Studio this also runs when you stop Play |
| Two servers overwrite each other | `GetAsync` then `SetAsync` | `UpdateAsync(key, function(old) return new end)` for anything that merges |
| "DataStore request was added to queue" spam | Saving on every change | Save on `PlayerRemoving`, `BindToClose`, and at most every 60 to 120s |
| Old data unreadable after a schema change | Raw `UserId` as the key | String key with a version: `"v1_" .. player.UserId` |
| Nothing saves in Studio | API access off | Game Settings > Security > Enable Studio Access to API Services |
| Table saved as `nil` | Value contains an Instance, a function, or a mixed-key table | Save plain numbers, strings, booleans, and array or string-key tables only |

## Common mistakes in the review itself

- Flagging `--!strict`, type annotations, or file structure. Studio devs
  cannot act on these without changing their workflow.
- Suggesting a framework (Knit, ProfileService) as the first fix. Name the
  direct fix; mention a library only if the dev asks.
- Listing twenty items with no order. Severity first, one fix each.

# Wally Package Reference

This document provides a reference for commonly used Wally packages in Roblox development.

## Core Packages

### ProfileDB
**Package:** `dig1t/profiledb@1.0.10`

Player data persistence with session locking, auto-saving, and reconciliation.

```lua
local ProfileDB = require(ReplicatedStorage.Packages.ProfileDB)

local profile = ProfileDB.new(player.UserId, {
    template = DataTemplate,
    saveInStudio = false,
    dataStoreName = "PlayerData",
    dataStoreVersion = 1,
})

-- Reconcile with template (schema migrations)
if profile.dataFetched then
    profile:Reconcile()
end

-- Get/Set data
local coins = profile:Get("stats.coins")
profile:Set("stats.coins", 100)
profile:Add("stats.coins", 50)

-- Save profile
profile:Save()
profile:Save(true) -- Remove from local state
```

### Replica
**Package:** `dig1t/replica@1.0.15`

Server-to-client data replication with automatic synchronization.

```lua
-- Server
local Replica = require(ReplicatedStorage.Packages.Replica)

local replica = Replica.Server.new({
    players = { player },
    initialData = profile.metadata.data,
    class = "Profile",
})

replica:Set("coins", 100)
replica:Destroy()

-- Client
Replica.Client.getReplicaAddedSignal("Profile", true):Connect(function(replica)
    local data = replica.data

    replica:GetKeyChangedSignal("coins"):Connect(function(newValue)
        print(`Coins: {newValue}`)
    end)
end)
```

### Signal
**Package:** `dig1t/signal@1.0.3`

Type-safe event system for internal communication.

```lua
local Signal = require(ReplicatedStorage.Packages.Signal)

-- Create typed signal
local PlayerLoaded = Signal.new() :: Signal.Signal<Player, ProfileData>

-- Connect listener
local connection = PlayerLoaded:Connect(function(player, data)
    print(player.Name, data.coins)
end)

-- Fire signal
PlayerLoaded:Fire(player, profileData)

-- Wait for signal
local player, data = PlayerLoaded:Wait()

-- Disconnect
connection:Disconnect()
```

### State
**Package:** `dig1t/state@1.2.2`

Reactive state management for client-side data.

```lua
local State = require(ReplicatedStorage.Packages.State)

-- Create state
local coins = State.new(100)

-- Get value
local currentCoins = coins:Get()

-- Set value
coins:Set(200)

-- Listen to changes
local connection = coins:onChange(function(newValue, oldValue)
    print(`Coins: {oldValue} -> {newValue}`)
end)

-- Set path (for nested tables)
local playerData = State.new({ stats = { coins = 100 } })
playerData:SetPath("stats.coins", 200)
```

### Promise
**Package:** `evaera/promise@4.0.0`

Async operations and chaining.

```lua
local Promise = require(ReplicatedStorage.Packages.Promise)

-- Create promise
local function loadData(userId: number)
    return Promise.new(function(resolve, reject)
        local success, result = pcall(function()
            return DataStore:GetAsync(userId)
        end)

        if success then
            resolve(result)
        else
            reject(result)
        end
    end)
end

-- Chain operations
loadData(12345)
    :andThen(function(data)
        return processData(data)
    end)
    :andThen(function(processed)
        return saveData(processed)
    end)
    :catch(function(err)
        warn("Error:", err)
    end)
    :finally(function()
        print("Done")
    end)

-- Promise utilities
Promise.all({ promise1, promise2 })
Promise.race({ promise1, promise2 })
Promise.delay(5):andThen(function() print("5 seconds later") end)
Promise.resolve(value)
Promise.reject(error)
```

### Maid
**Package:** `dig1t/maid@1.1.3`

Resource cleanup and garbage collection.

```lua
local Maid = require(ReplicatedStorage.Packages.Maid)

local maid = Maid.new()

-- Track connections, instances, cleanup functions — all via Add.
-- NOT GiveTask/DoCleaning (that's Quenty's Maid; this API fails at runtime with it)
maid:Add(signal:Connect(handler))
maid:Add(instance)
maid:Add(function()
    print("Cleanup!")
end)

-- Add returns the task (and a task id usable with Remove)
local part, taskId = maid:Add(Instance.new("Part"))
maid:Remove(taskId)

-- Connect a signal and track the connection in one call
maid:Connect(signal, handler)

-- Destroy the maid when an instance is destroyed
maid:BindToInstance(instance)

-- Run all cleanup tasks
maid:Clean()

-- Destroy (runs Clean)
maid:Destroy()
```

### Trash
**Package:** `dig1t/trash@1.0.4`

Lightweight alternative to Maid.

```lua
local Trash = require(ReplicatedStorage.Packages.Trash)

local trash = Trash.new()

trash:Add(connection)
trash:Add(instance)
trash:Add(function() end)

trash:Destroy()
```

### Red
**Package:** `dig1t/red@2.2.10`

Event-driven action framework for client-server communication.

```lua
local red = require(ReplicatedStorage.Packages.red)

-- Server: Bind handlers
red.bind("PURCHASE_ITEM", function(player: Player, payload: { itemId: string })
    -- Process purchase
    return success
end)

-- Server: Use handler files
red.useHandlers(script.Parent.Handlers)

-- Client: Dispatch actions
red.dispatch({
    type = "PURCHASE_ITEM",
    payload = { itemId = "sword_001" },
})

-- Client: Dispatch with callback
red.dispatch({
    type = "GET_INVENTORY",
    payload = {},
}, function(inventory)
    print("Received inventory:", inventory)
end)
```

### Fusion
**Package:** `elttob/fusion@0.3.0`

Reactive UI framework.

```lua
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local New = Fusion.New
local Children = Fusion.Children
local Value = Fusion.Value
local Computed = Fusion.Computed

-- Create reactive values
local coins = Value(100)

-- Create computed values
local coinsText = Computed(function()
    return `Coins: {coins:get()}`
end)

-- Create UI
local gui = New "ScreenGui" {
    Parent = playerGui,

    [Children] = {
        New "TextLabel" {
            Text = coinsText,
            Size = UDim2.fromOffset(200, 50),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
        },
    },
}

-- Update value (UI updates automatically)
coins:set(200)
```

## Utility Packages

### Util
**Package:** `dig1t/util@1.0.20`

General utility functions.

```lua
local Util = require(ReplicatedStorage.Packages.Util)

-- Safe retry for API calls
local success, result = Util.attempt(function()
    return HttpService:GetAsync(url)
end, 3, 0.5) -- 3 retries, 0.5s delay

-- Table utilities
local merged = Util.merge(table1, table2)
local deep = Util.deepCopy(original)

-- String utilities
local formatted = Util.formatNumber(1234567) -- "1,234,567"
```

### Cache
**Package:** `dig1t/cache@1.0.10`

Caching utility with TTL support.

```lua
local Cache = require(ReplicatedStorage.Packages.Cache)

local cache = Cache.new({
    ttl = 60, -- 60 second TTL
})

cache:Set("key", value)
local value = cache:Get("key")
cache:Remove("key")
cache:Clear()
```

### Badge
**Package:** `dig1t/badge@1.0.8`

Badge/achievement system.

```lua
local Badge = require(ReplicatedStorage.Packages.Badge)

Badge.award(player, badgeId)

local hasBadge = Badge.has(player, badgeId)
```

### GamePass
**Package:** `dig1t/gamepass@1.0.9`

GamePass utilities.

```lua
local GamePass = require(ReplicatedStorage.Packages.GamePass)

local ownsPass = GamePass.owns(player, gamePassId)

GamePass.prompt(player, gamePassId)

GamePass.Purchased:Connect(function(player, passId)
    -- Handle purchase
end)
```

### Animation
**Package:** `dig1t/animation@1.0.8`

Animation controller.

```lua
local Animation = require(ReplicatedStorage.Packages.Animation)

local animController = Animation.new(humanoid)

animController:Load("idle", idleAnimation)
animController:Load("walk", walkAnimation)

animController:Play("idle")
animController:Stop("idle")
animController:StopAll()
```

### Ragdoll
**Package:** `dig1t/ragdoll@1.0.4`

Ragdoll system.

```lua
local Ragdoll = require(ReplicatedStorage.Packages.Ragdoll)

Ragdoll.enable(character)
Ragdoll.disable(character)

local isRagdolled = Ragdoll.isRagdolled(character)
```

### Analytics
**Package:** `dig1t/analytics@1.1.10`

GameAnalytics SDK wrapper.

```lua
local Analytics = require(ReplicatedStorage.Packages.Analytics)

-- Initialize (server only)
Analytics.init({
    GameKey = "your-game-key",
    SecretKey = "your-secret-key",
})

-- Track events
Analytics.logPlayerEvent({
    player = player,
    event = "Session:Start",
})

Analytics.logResourceEvent({
    player = player,
    flowType = "Sink",
    currency = "Coins",
    amount = 100,
    itemType = "Shop",
    itemId = "sword_001",
})

Analytics.logProgressionEvent({
    player = player,
    progressionStatus = "Complete",
    progression01 = "World1",
    progression02 = "Level5",
})
```

### t
**Package:** `osyrisrblx/t@3.1.1`

Runtime type checking library.

```lua
local t = require(ReplicatedStorage.Packages.t)

-- Create type checker
local checkPurchasePayload = t.strictInterface({
    itemId = t.string,
    quantity = t.optional(t.integer),
})

-- Use in handlers
red.bind("PURCHASE", function(player, payload)
    if not checkPurchasePayload(payload) then
        return false
    end

    -- Process valid payload
end)

-- Common checks
t.string
t.number
t.integer
t.boolean
t.table
t.Instance
t.instanceOf("Part")
t.optional(t.string)
t.union(t.string, t.number)
t.array(t.string)
t.map(t.string, t.number)
```

## Example wally.toml

```toml
[package]
name = "author/my-game"
version = "1.0.0"
realm = "shared"
registry = "https://github.com/UpliftGames/wally-index"

[dependencies]
# Core
ProfileDB = "dig1t/profiledb@1.0.10"
Replica = "dig1t/replica@1.0.15"
Signal = "dig1t/signal@1.0.3"
State = "dig1t/state@1.2.2"
Promise = "evaera/promise@4.0.0"
Maid = "dig1t/maid@1.1.3"

# Communication
red = "dig1t/red@2.2.10"

# UI
Fusion = "elttob/fusion@0.3.0"

# Utilities
Util = "dig1t/util@1.0.20"
t = "osyrisrblx/t@3.1.1"
Cache = "dig1t/cache@1.0.10"

# Game Features
Badge = "dig1t/badge@1.0.8"
GamePass = "dig1t/gamepass@1.0.9"
Animation = "dig1t/animation@1.0.8"

# Analytics
Analytics = "dig1t/analytics@1.1.10"

[dev-dependencies]
TestEZ = "roblox/testez@0.4.1"
```

## Installing Packages

```bash
# Add package to wally.toml
# Then run:
wally install

# Regenerate sourcemap and types
rojo sourcemap default.project.json -o sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages
```

## Finding Packages

- [Wally Registry](https://wally.run/) - Browse all available packages
- [GitHub](https://github.com) - Search for Roblox/Luau packages
- Check an existing house project (e.g. `~/Git/drive-or-die/wally.toml`) for common package combinations; package sources live in `~/Git/roblox-modules`

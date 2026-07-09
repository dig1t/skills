# Common Roblox Code Patterns

This document contains battle-tested patterns for Roblox game development.

## Service Pattern

### Basic Service Structure
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Signal = require(ReplicatedStorage.Packages.Signal)

--[=[
    @class MyService
    Brief description of what this service does.
]=]
local MyService = {
    -- Public signals for loose coupling
    SomethingHappened = Signal.new() :: Signal.Signal<Player, string>,

    -- Private state (prefix with _)
    _internalState = {} :: { [Player]: any },
}

function MyService.init()
    -- Initialize dependencies
    -- Set up internal state
    -- DO NOT start listening to events yet
    -- DO NOT access other services yet
end

function MyService.start()
    -- Start listening to events
    -- Begin service logic
    -- All other services are initialized at this point
end

-- Public API methods
function MyService.doSomething(player: Player, data: string): boolean
    -- Implementation
    return true
end

-- Private helper functions
local function _validateInput(input: any): boolean
    return input ~= nil
end

return MyService
```

### ProfileService Pattern
```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileDB = require(ReplicatedStorage.Packages.ProfileDB)
local Replica = require(ReplicatedStorage.Packages.Replica)
local Signal = require(ReplicatedStorage.Packages.Signal)

local DataTemplate = require(ReplicatedStorage.Shared.Data.DataTemplate)

local DATASTORE_NAME = "PlayerData"
local DATASTORE_VERSION = 1
local SAVE_IN_STUDIO = false

local ProfileService = {
    ProfileLoaded = Signal.new() :: Signal.Signal<Player, ProfileTypes.Profile>,
    _profiles = {} :: { [Player]: ProfileTypes.Profile },
    _replicas = {} :: { [Player]: any },
}

function ProfileService.init()
    -- Initialize handlers
end

function ProfileService.start()
    Players.PlayerAdded:Connect(function(player)
        ProfileService.loadProfile(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        ProfileService.save(player, true)
    end)

    -- Handle existing players
    for _, player in Players:GetPlayers() do
        task.spawn(ProfileService.loadProfile, player)
    end
end

function ProfileService.loadProfile(player: Player): (ProfileTypes.Profile?, string)
    local playerProfile = ProfileDB.new(player.UserId, {
        template = DataTemplate,
        saveInStudio = SAVE_IN_STUDIO,
        dataStoreName = DATASTORE_NAME,
        dataStoreVersion = DATASTORE_VERSION,
    })

    if playerProfile.dataFetched then
        playerProfile:Reconcile()
    end

    ProfileService._profiles[player] = playerProfile

    -- Create replica for client
    local replica = Replica.Server.new({
        players = { player },
        initialData = playerProfile.metadata.data,
        class = "Profile",
    })
    ProfileService._replicas[player] = replica

    ProfileService.ProfileLoaded:Fire(player, playerProfile)
    return playerProfile, "loaded"
end

function ProfileService.get(player: Player): ProfileTypes.ProfileData?
    local profile = ProfileService._profiles[player]
    return profile and profile.metadata.data
end

function ProfileService.set(player: Player, updates: { [string]: any })
    local profile = ProfileService._profiles[player]
    if not profile then return end

    local updatedKeys = {}
    for path, value in updates do
        profile:Set(path, value)
        table.insert(updatedKeys, path)
    end

    ProfileService._update(player, updatedKeys)
end

function ProfileService.add(player: Player, updates: { [string]: number })
    local profile = ProfileService._profiles[player]
    if not profile then return end

    local updatedKeys = {}
    for path, amount in updates do
        profile:Add(path, amount)
        table.insert(updatedKeys, path)
    end

    ProfileService._update(player, updatedKeys)
end

function ProfileService._update(player: Player, updatedKeys: { string })
    local replica = ProfileService._replicas[player]
    local profile = ProfileService._profiles[player]
    if not replica or not profile then return end

    for _, path in updatedKeys do
        local parts = string.split(path, ".")
        local rootKey = parts[1]
        local value = profile:Get(rootKey)
        if value ~= nil then
            replica:Set(rootKey, value)
        end
    end
end

function ProfileService.save(player: Player, removeLocal: boolean?): boolean
    local profile = ProfileService._profiles[player]
    if not profile then return false end

    local success = profile:Save(removeLocal)

    if removeLocal then
        ProfileService._profiles[player] = nil
        local replica = ProfileService._replicas[player]
        if replica then
            replica:Destroy()
            ProfileService._replicas[player] = nil
        end
    end

    return success
end

return ProfileService
```

## Controller Pattern

### Basic Controller Structure
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Replica = require(ReplicatedStorage.Packages.Replica)
local Signal = require(ReplicatedStorage.Packages.Signal)

local ClientState = require(script.Parent.Parent.Parent.ClientState)

local DataController = {
    didLoad = false :: boolean,
    Loaded = Signal.new() :: Signal.Signal<>,
    replica = nil :: any,
}

function DataController.init()
    -- Initialize dependencies
end

function DataController.start()
    -- Listen for profile replica
    Replica.Client.getReplicaAddedSignal("Profile", true):Connect(function(profileReplica)
        DataController.replica = profileReplica

        -- Update client state
        ClientState.playerData:Set(profileReplica.data)

        -- Listen to changes
        for key in pairs(profileReplica.data) do
            profileReplica:GetKeyChangedSignal(key):Connect(function(value)
                ClientState.playerData:SetPath(key, value)
            end)
        end

        DataController.didLoad = true
        DataController.Loaded:Fire()
    end)
end

function DataController.waitForLoad()
    if not DataController.didLoad then
        DataController.Loaded:Wait()
    end
end

return DataController
```

## Handler Pattern

### RemoteEvent Handler (with Red framework)
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShopService = require(ServerScriptService.Features.Shop.ShopService)
local red = require(ReplicatedStorage.Packages.red)

return function(bind: red.Bind)
    bind("SHOP_PURCHASE", function(player: Player, payload: { itemId: string })
        -- 1. Validate player
        if not player or not player.Parent then
            return false
        end

        -- 2. Validate payload
        if not payload or typeof(payload.itemId) ~= "string" then
            warn("Invalid purchase payload from", player.Name)
            return false
        end

        -- 3. Delegate to service
        return ShopService.purchase(player, payload.itemId)
    end)

    bind("SHOP_GET_STOCK", function(player: Player, payload: { shopType: string })
        if not payload or typeof(payload.shopType) ~= "string" then
            return nil
        end

        return ShopService.getStock(payload.shopType)
    end)
end
```

### RemoteEvent Handler (Vanilla)
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShopService = require(ServerScriptService.Features.Shop.ShopService)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Handler = {}

function Handler.init()
    local purchaseRemote = remotes:WaitForChild("ShopPurchase") :: RemoteEvent
    local stockRemote = remotes:WaitForChild("ShopGetStock") :: RemoteFunction

    purchaseRemote.OnServerEvent:Connect(function(player: Player, itemId: string)
        if not player or not player.Parent then return end
        if typeof(itemId) ~= "string" then return end

        ShopService.purchase(player, itemId)
    end)

    stockRemote.OnServerInvoke = function(player: Player, shopType: string)
        if typeof(shopType) ~= "string" then return nil end
        return ShopService.getStock(shopType)
    end
end

return Handler
```

## Data Template Pattern

```lua
local Players = game:GetService("Players")

export type Stats = {
    coins: number,
    xp: number,
    level: number,
}

export type ProfileData = {
    userLevel: number,
    inventory: { ItemRecord },
    inventory_equipped: { string },
    stats: Stats,
    settings: { [string]: any },
    ftue: {
        completed: boolean,
        checkpoint: number,
        version: number,
    },
    daily_rewards: {
        lastClaim: number,
        streak: number,
    },
    total_time: number,
    rounds_played: number,
    purchases: { [string]: boolean },
    claims: { [string]: boolean },
}

local function DataTemplate(player: Player): ProfileData
    return {
        userLevel = 1,

        inventory = {},
        inventory_equipped = {},

        stats = {
            coins = 100,
            xp = 0,
            level = 1,
        },

        settings = {},

        ftue = {
            completed = false,
            checkpoint = 0,
            version = 1,
        },

        daily_rewards = {
            lastClaim = 0,
            streak = 0,
        },

        total_time = 0,
        rounds_played = 0,

        purchases = {},
        claims = {},
    }
end

return DataTemplate
```

## Cleanup Pattern (Maid)

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Maid = require(ReplicatedStorage.Packages.Maid)

local playerMaids: { [Player]: Maid.Maid } = {}

local function setupPlayer(player: Player)
    local maid = Maid.new()
    playerMaids[player] = maid

    -- Track connections
    maid:Add(player.CharacterAdded:Connect(function(character)
        -- Handle character
    end))

    -- Track instances
    local gui = Instance.new("ScreenGui")
    gui.Parent = player.PlayerGui
    maid:Add(gui)

    -- Track cleanup functions
    maid:Add(function()
        print(`Cleaning up {player.Name}`)
    end)
end

local function cleanupPlayer(player: Player)
    local maid = playerMaids[player]
    if maid then
        maid:Destroy()
        playerMaids[player] = nil
    end
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)
```

## Signal Pattern

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

local CoinService = {
    CoinCollected = Signal.new() :: Signal.Signal<Player, string, number>,
}

function CoinService.collectCoin(player: Player, coinId: string)
    local coinValue = getCoinValue(coinId)

    -- Process collection
    ProfileService.add(player, { ["stats.coins"] = coinValue })

    -- Fire signal for other systems
    CoinService.CoinCollected:Fire(player, coinId, coinValue)
end

-- Elsewhere - subscribe to signal
CoinService.CoinCollected:Connect(function(player, coinId, value)
    -- Update analytics
    Analytics.logResourceEvent(player, "Source", "Coins", value)

    -- Update UI
    UIService.showCoinPopup(player, value)
end)
```

## Promise Pattern

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Packages.Promise)

local function loadAsset(assetId: number)
    return Promise.new(function(resolve, reject)
        local success, result = pcall(function()
            return game:GetService("InsertService"):LoadAsset(assetId)
        end)

        if success then
            resolve(result)
        else
            reject(`Failed to load asset {assetId}: {result}`)
        end
    end)
end

-- Chain operations
loadAsset(12345)
    :andThen(function(model)
        model.Parent = workspace
        return model
    end)
    :andThen(function(model)
        return Promise.delay(5):andThenReturn(model)
    end)
    :andThen(function(model)
        model:Destroy()
    end)
    :catch(function(err)
        warn("Error:", err)
    end)
```

## Timeout Pattern

```lua
local LOAD_TIMEOUT = 30

local function waitForConditionWithTimeout(
    condition: () -> boolean,
    timeout: number
): (boolean, string)
    local startTime = os.clock()

    while not condition() do
        if os.clock() - startTime > timeout then
            return false, "timed_out"
        end
        task.wait()
    end

    return true, "success"
end

-- Usage
local success, status = waitForConditionWithTimeout(function()
    return DataController.didLoad
end, LOAD_TIMEOUT)

if not success then
    player:Kick("Failed to load data")
end
```

## Rate Limiting Pattern

```lua
local rateLimits: { [Player]: { [string]: number } } = {}

local function checkRateLimit(player: Player, action: string, cooldown: number): boolean
    if not rateLimits[player] then
        rateLimits[player] = {}
    end

    local lastAction = rateLimits[player][action] or 0
    local currentTime = os.clock()

    if currentTime - lastAction < cooldown then
        return false -- Rate limited
    end

    rateLimits[player][action] = currentTime
    return true
end

-- Usage in handler
red.bind("COLLECT_COIN", function(player: Player, payload: { coinId: string })
    -- Rate limit: 1 collection per 0.5 seconds
    if not checkRateLimit(player, "COLLECT_COIN", 0.5) then
        return false
    end

    -- Process collection
end)

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(player)
    rateLimits[player] = nil
end)
```

## Validation Helpers

```lua
local Validators = {}

function Validators.isPlayer(value: any): boolean
    return typeof(value) == "Instance" and value:IsA("Player")
end

function Validators.isString(value: any): boolean
    return typeof(value) == "string"
end

function Validators.isNumber(value: any): boolean
    return typeof(value) == "number"
end

function Validators.isPositiveNumber(value: any): boolean
    return typeof(value) == "number" and value > 0
end

function Validators.isTable(value: any): boolean
    return typeof(value) == "table"
end

function Validators.hasKeys(value: any, keys: { string }): boolean
    if typeof(value) ~= "table" then
        return false
    end

    for _, key in keys do
        if value[key] == nil then
            return false
        end
    end

    return true
end

-- Usage
function Handler.onPurchase(player: Player, payload: any)
    if not Validators.isPlayer(player) then return end
    if not Validators.hasKeys(payload, { "itemId", "quantity" }) then return end
    if not Validators.isString(payload.itemId) then return end
    if not Validators.isPositiveNumber(payload.quantity) then return end

    -- Process purchase
end

return Validators
```

## State Pattern (Client)

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Packages.State)

local DataTemplate = require(ReplicatedStorage.Shared.Data.DataTemplate)

-- Create reactive state values
local ClientState = {
    playerData = State.new(DataTemplate(nil :: any)),
    coins = State.new(0),
    level = State.new(1),
    isLoading = State.new(true),
    currentRoute = State.new("MainMenu"),
}

-- Subscribe to changes
ClientState.coins.Changed:Connect(function(newValue)
    print(`Coins updated to {newValue}`)
end)

-- Update state
ClientState.coins:Set(500)

-- Get current value
local currentCoins = ClientState.coins:Get()

return ClientState
```

## UI Route Pattern

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Route = require(ReplicatedStorage.Shared.Class.UI.Route)
local ClientState = require(script.Parent.Parent.ClientState)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MainMenuRoute = Route.new({
    path = "MainMenu",
    root = playerGui:WaitForChild("MainMenu"),
    isDefault = true,
})

function MainMenuRoute:Initiate()
    -- Initialize route (called once)
end

function MainMenuRoute:Mount()
    -- Show route UI
    self.root.Enabled = true

    -- Subscribe to state
    self._coinConnection = ClientState.coins.Changed:Connect(function(value)
        self.root.CoinsLabel.Text = tostring(value)
    end)
end

function MainMenuRoute:Unmount()
    -- Hide route UI
    self.root.Enabled = false

    -- Cleanup subscriptions
    if self._coinConnection then
        self._coinConnection:Disconnect()
        self._coinConnection = nil
    end
end

return MainMenuRoute
```

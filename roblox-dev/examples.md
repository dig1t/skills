# Real Code Examples

This document contains code examples based on production patterns used in this project.

---

## Server Entry Point

A production server entry point that handles player joining, character spawning, and game initialization.

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage.Packages
local Server = ServerScriptService
local Shared = ReplicatedStorage.Shared

local Character = require(Server.Util.Character)
local GameService = require(ServerScriptService.Features.Minigames.GameService)
local PlayerOverhead = require(Shared.Class.PlayerOverhead)
local PlayerService = require(ServerScriptService.Features.Core.PlayerService)
local ProfileService = require(ServerScriptService.Features.Core.ProfileService)
local Ragdoll = require(Packages.Ragdoll)
local ServerConfig = require(Server.Data.ServerConfig)
local Util = require(Packages.Util)
local red = require(Packages.red)

local RESPAWN_TIME = 2

-- Load handlers and watchers
require(script.Parent.Handlers)
require(script.Parent.Features.CollectionWatcher)

PlayerService.watchForPlayers()

local function spawnPlayer(player: Player)
    local character: Model? = Character.createModel(player)
    local spawnPoint: Part = Util.tableRandom(ServerConfig.spawns)
    local offset: Vector3 = spawnPoint:GetAttribute("SpawnOffset") :: Vector3? or Vector3.new()

    if not character then
        return
    end

    character:PivotTo(
        spawnPoint.CFrame * CFrame.new(
            Util.random(-offset.X, offset.X),
            0,
            Util.random(-offset.Z, offset.Z)
        )
    )

    player.Character = character
    character.Parent = Workspace
end

local function playerAdded(player: Player)
    local profileData = ProfileService.fetch(player)

    if not profileData then
        return
    end

    local userLevel = Util.getUserLevel(player)

    player.CharacterAdded:Connect(function(character: Model)
        player:SetAttribute("SpawnOverride", false)

        if not character.Parent then
            character.AncestryChanged:Wait()
            if not character.Parent then
                return
            end
        end

        PlayerOverhead.create(player)

        local humanoid = character:WaitForChild("Humanoid") :: Humanoid

        humanoid.Died:Once(function()
            task.spawn(function()
                Ragdoll.playerDied(
                    player,
                    Workspace:FindFirstChild("GameContainer") or Workspace:FindFirstChild("World"),
                    RESPAWN_TIME,
                    character:GetAttribute("KeepRagdollInWorld") :: boolean?
                )
            end)

            RunService.Heartbeat:Wait()

            if player:GetAttribute("SpawnOverride") then
                return
            end

            task.wait(RESPAWN_TIME)

            if not player or not player.Parent or player:GetAttribute("SpawnOverride") then
                return
            end

            if character and character.Parent then
                character:Destroy()
            end

            if player.Character == character or not player.Character then
                spawnPlayer(player)
            end
        end)
    end)

    -- Notify clients that a player joined
    red.dispatch(true, {
        type = "PLAYER_JOINED",
        payload = {
            id = player.UserId,
            username = player.DisplayName,
            userLevel = userLevel,
            stats = {
                coins = profileData.stats.coins,
                level = profileData.stats.level,
            },
        },
    })

    player.NameDisplayDistance = 0
    player.HealthDisplayDistance = 0
    player.CameraMaxZoomDistance = 40

    if not player or not player.Parent then
        return
    end

    spawnPlayer(player)
end

-- Handle players that joined before connection was created
for _, player in pairs(Players:GetPlayers()) do
    playerAdded(player)
end

Players.PlayerAdded:Connect(playerAdded)

GameService.init()
```

---

## ProfileService (Complete Example)

A complete ProfileService implementation with data loading, saving, replication, and path-based updates.

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Maid = require(ReplicatedStorage.Packages.Maid)
local Util = require(Packages.Util)
local red = require(Packages.red)

local AdminService = require(ServerScriptService.Features.Core.AdminService)
local CoreState = require(ServerScriptService.Features.Core.CoreState)
local DataTemplate = require(ReplicatedStorage.Shared.Data.DataTemplate)
local ProfileDB = require(ReplicatedStorage.Packages.ProfileDB)
local ProfileTypes = require(ReplicatedStorage.Shared.Types.ProfileTypes)
local Replica = require(ReplicatedStorage.Packages.Replica)
local Signal = require(ReplicatedStorage.Packages.Signal)

export type PathValues = { [string]: any }

local replicas = {} :: { [Player]: Replica.ReplicaServer }
local playersLoading = {} :: { Player }

local ProfileService = {}

function ProfileService.getProfile(player: Player): ProfileTypes.Profile?
    local profileFetch: ProfileTypes.Profile? = CoreState.profiles:Get(player.UserId)

    if profileFetch then
        return profileFetch :: ProfileTypes.Profile
    end

    local signal: Signal.Signal<ProfileTypes.Profile?> = Signal.new()

    if table.find(playersLoading, player) then
        return signal:Wait()
    end

    -- Start loading
    table.insert(playersLoading, player)

    local maid = Maid.new()
    maid:Add(signal :: any)

    maid:Add(Players.PlayerRemoving:Connect(function(removedPlayer: Player)
        if removedPlayer == player then
            maid:Destroy()
        end
    end))

    maid:Add(function()
        local loadingIndex = table.find(playersLoading, player)
        if loadingIndex then
            table.remove(playersLoading, loadingIndex)
        end
    end)

    local isAdmin = AdminService.check(player)

    local playerProfile = ProfileDB.new(player.UserId, {
        template = DataTemplate,
    }) :: ProfileTypes.Profile

    if playerProfile.dataFetched then
        playerProfile:Reconcile()
    end

    -- Session properties (not saved)
    playerProfile.isAdmin = isAdmin
    playerProfile.userLevel = 1

    -- Create replica for client
    replicas[player] = Replica.Server.new({
        players = { player },
        initialData = playerProfile.metadata.data,
        class = "Profile",
    })

    CoreState.profiles:Push(player.UserId, playerProfile)

    signal:Fire(playerProfile)
    maid:Destroy()

    return playerProfile
end

function ProfileService.save(player: Player, removeLocal: boolean?): boolean
    assert(
        player and (typeof(player) == "Instance" and player:IsA("Player")),
        "ProfileService.save - Missing player"
    )

    local playerProfile: ProfileTypes.Profile? = ProfileService.getProfile(player)

    if not playerProfile then
        return false
    end

    -- Calculate session time
    local sessionTimePlayed = os.time() - playerProfile.sessionStart
    playerProfile.total_time += sessionTimePlayed

    local success = playerProfile:Save()

    if removeLocal then
        playerProfile:Destroy()
        CoreState.profiles:Remove(player.UserId)

        if replicas[player] then
            replicas[player]:Destroy()
            replicas[player] = nil
        end
    end

    return success
end

function ProfileService.set(player: Player, payload: PathValues): boolean
    assert(
        player and (typeof(player) == "Instance" and player:IsA("Player")),
        "ProfileService.set - Missing player"
    )

    local playerProfile: ProfileTypes.Profile? = ProfileService.getProfile(player)

    if not playerProfile then
        return false
    end

    local noEvent = payload.noEvent
    payload.noEvent = nil

    local updatedKeys = playerProfile:SetMultiple(payload)

    if not noEvent or #updatedKeys <= 0 then
        return #updatedKeys > 0
    end

    ProfileService._update(player, updatedKeys)

    return true
end

function ProfileService.add(player: Player, payload: { [string]: number }): boolean
    assert(
        player and (typeof(player) == "Instance" and player:IsA("Player")),
        "ProfileService.add - Missing player"
    )

    local playerProfile: ProfileTypes.Profile? = ProfileService.getProfile(player)

    if not playerProfile then
        return false
    end

    for key, value in pairs(payload) do
        local savedValue = playerProfile and playerProfile:Get(key)

        if savedValue then
            local newValue = (savedValue or 0) + value
            playerProfile:Set(key, newValue)
        end
    end

    return true
end

function ProfileService.insertValue(player: Player, payload: PathValues)
    assert(
        player and (typeof(player) == "Instance" and player:IsA("Player")),
        "ProfileService.add - Missing player"
    )

    local playerProfile: ProfileTypes.Profile? = ProfileService.getProfile(player)

    local insertedKeys = playerProfile and playerProfile:InsertMultiple(payload) or {}

    if #insertedKeys > 0 then
        ProfileService._update(player, insertedKeys)
    end
end

-- Internal: Update player's replica
function ProfileService._update(
    player: Player,
    updatedKeys: { string }?,
    removedKeys: { string }?
)
    local playerProfile: ProfileTypes.Profile? = ProfileService.getProfile(player)

    if not playerProfile then
        return
    end

    for _, pathTable in { updatedKeys, removedKeys } do
        if not pathTable then
            continue
        end

        for _, path: string in pathTable do
            local exploded = string.split(path, ".")
            local firstTableKey = exploded and exploded[1]

            if not firstTableKey then
                continue
            end

            local replica = replicas[player]
            local firstTableValue = playerProfile:Get(firstTableKey)

            if replica and firstTableValue then
                replica:Set(firstTableKey, firstTableValue)
            end
        end
    end
end

return ProfileService
```

---

## DataController (Client)

A client-side controller that receives replicated profile data and updates ClientState.

```lua
--[[
    Controller for managing data and state in the game.
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientState = require(ReplicatedFirst.ClientState)
local DataTemplate = require(ReplicatedStorage.Shared.Data.DataTemplate)
local Replica = require(ReplicatedStorage.Packages.Replica)
local Signal = require(ReplicatedStorage.Packages.Signal)

local DataController = {
    replica = nil :: Replica.ReplicaClient?,
    didLoad = false :: boolean,
    Loaded = Signal.new(),
}

Replica.Client.getReplicaAddedSignal("Profile", true):Connect(function(profileReplica)
    DataController.replica = profileReplica

    if not DataController.didLoad then
        DataController.didLoad = true
        DataController.Loaded:Fire()
    end

    -- Hook up signals to update the client state
    for key, _ in pairs(DataTemplate) do
        profileReplica:GetKeyChangedSignal(key):Connect(function(value)
            print(`{key} changed to {value}`)
            ClientState.playerData:SetPath(key, value)
        end)
    end
end)

return DataController
```

---

## Handler (Minimal Example)

A minimal handler that binds a single action to a service method.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MineableService = require(ServerScriptService.Features.Mineables.MineableService)
local red = require(ReplicatedStorage.Packages.red)

return function(bind: red.Bind)
    bind("MINEABLE_HIT", function(player: Player, payload: { mineableId: string })
        return MineableService.registerHit(player, payload.mineableId)
    end)
end
```

---

## ShopService (Complex Example)

A complex service showing:
- Stock management with replication
- Purchase validation
- Analytics tracking
- Code redemption
- Ownership limits

Key patterns from this service:

### Service Structure with init()
```lua
local ShopService = {
    shops = {} :: { [string]: ShopData },
    _lastRestockCycle = Workspace:GetServerTimeNow(),
}

function ShopService.init()
    red.useHandlers(script.Parent.Handlers)

    local supportedItemTypes = setupShops()
    populateShopItems(supportedItemTypes)
    initializeStock()

    -- Force initial restock
    for shopType, _ in pairs(ShopService.shops) do
        ShopService.manualRestock(shopType)
    end

    startRestockLoop()
end

return ShopService
```

### Purchase Validation Pattern
```lua
function ShopService.purchase(player: Player, itemId: string, quantity: number?): boolean
    assert(quantity == nil or quantity > 0, "Quantity must be positive")

    if not player or not itemId then
        return false
    end

    local itemData = Items[itemId] :: ItemTypes.BaseItem?

    -- Early return for invalid items
    if
        not itemData
        or itemData.hidden
        or not itemData.purchasePrice
        or not itemData.purchaseCurrency
        or itemData.stockData ~= nil
    then
        return false
    end

    -- Check ownership limits
    local canPurchase = ShopService.checkOwnershipLimit(player, itemId)
    if not canPurchase then
        return false
    end

    -- Check currency
    local playerCurrency = CurrencyService.fetchStat(player, itemData.purchaseCurrency)
    if playerCurrency < itemData.purchasePrice then
        return false
    end

    -- Process purchase
    local success, endingBalance = CurrencyService.take(
        player,
        itemData.purchaseCurrency,
        itemData.purchasePrice
    )

    if not success or not endingBalance then
        return false
    end

    -- Log analytics
    Analytics.logResourceEvent({
        player = player,
        flowType = "Sink",
        currency = itemData.purchaseCurrency,
        amount = itemData.purchasePrice,
        endingBalance = endingBalance,
        eventType = "ItemPurchase",
        itemId = itemData.name,
    })

    -- Give item
    local record = ShopService.giveItemToPlayer(player, itemId, 1)
    return record ~= nil
end
```

### Ownership Limit Check
```lua
function ShopService.checkOwnershipLimit(
    player: Player,
    itemId: string
): (boolean, number)
    local item = Items[itemId]
    if not item then
        return false, 0
    end

    -- No limit means always allow
    if not item.ownershipLimit or item.ownershipLimit == 0 then
        return true, 0
    end

    -- Count owned items
    local profile = ProfileService.getWithPayload(player, { "inventory" })
    local inventory = profile and profile.payload and profile.payload.inventory or {}

    local ownedCount = 0
    for _, record: Types.ItemRecord in pairs(inventory) do
        if record.itemId == itemId then
            ownedCount += record.quantity or 1
        end
    end

    -- For Props, also count placed items
    if item.type == "Prop" then
        ownedCount += #BaseService.getPropsByItemId(player, itemId)
    end

    local canPurchase = ownedCount < item.ownershipLimit
    return canPurchase, ownedCount
end
```

### Replica for Shop Stock
```lua
local function setupShops()
    for shopType, itemTypes in pairs(ShopData.SHOP_TYPES) do
        ShopService.shops[shopType] = {
            supportedItemTypes = itemTypes,
            replica = Replica.Server.new({
                class = ShopData.REPLICA_CLASS,
                initialData = {
                    shopType = shopType,
                    lastRestockTime = 0,
                    items = {},
                } :: ShopData.ShopReplicaData,
            }),
        }
    end
end
```


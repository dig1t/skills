# Common Luau Patterns

## Service Pattern (Server)

### Basic Service

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Signal = require(ReplicatedStorage.Packages.Signal)

local PlayerDataService = {}

-- Events
PlayerDataService.DataLoaded = Signal.new()
PlayerDataService.DataSaved = Signal.new()

-- Private state
local _started = false
local _playerData: { [Player]: PlayerData } = {}

-- Private functions
local function _loadData(player: Player): PlayerData
    -- Load from DataStore
    return { coins = 0, level = 1 }
end

local function _saveData(player: Player)
    local data = _playerData[player]
    if not data then return end
    -- Save to DataStore
end

-- Public API
function PlayerDataService:GetData(player: Player): PlayerData?
    return _playerData[player]
end

function PlayerDataService:SetCoins(player: Player, amount: number)
    local data = _playerData[player]
    if not data then return end
    data.coins = amount
end

-- Lifecycle
function PlayerDataService:Start()
    assert(not _started, "PlayerDataService already started")
    _started = true

    Players.PlayerAdded:Connect(function(player)
        _playerData[player] = _loadData(player)
        self.DataLoaded:Fire(player, _playerData[player])
    end)

    Players.PlayerRemoving:Connect(function(player)
        _saveData(player)
        _playerData[player] = nil
    end)

    -- Handle players already in game
    for _, player in Players:GetPlayers() do
        task.spawn(function()
            _playerData[player] = _loadData(player)
            self.DataLoaded:Fire(player, _playerData[player])
        end)
    end
end

return PlayerDataService
```

### Service with Dependencies

```lua
--!strict
local CombatService = {}

local _dataService
local _inventoryService

function CombatService:Init(dataService, inventoryService)
    _dataService = dataService
    _inventoryService = inventoryService
end

function CombatService:Start()
    -- Can now use dependencies
end

return CombatService
```

---

## Controller Pattern (Client)

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local InventoryController = {}

local _player = Players.LocalPlayer
local _inventory: { [string]: number } = {}

-- Events
InventoryController.ItemAdded = Signal.new()
InventoryController.ItemRemoved = Signal.new()

function InventoryController:GetItems(): { [string]: number }
    return table.clone(_inventory)
end

function InventoryController:HasItem(itemId: string): boolean
    return (_inventory[itemId] or 0) > 0
end

function InventoryController:Init()
    -- Non-yielding setup
end

function InventoryController:Start()
    -- Connect to server events
    local remote = ReplicatedStorage.Remotes.InventoryUpdate
    remote.OnClientEvent:Connect(function(newInventory)
        _inventory = newInventory
    end)
end

return InventoryController
```

---

## State Machine

```lua
--!strict
type State = "Idle" | "Walking" | "Running" | "Jumping" | "Falling"

type StateMachine = {
    current: State,
    transitions: { [State]: { State } },
    onEnter: { [State]: () -> () },
    onExit: { [State]: () -> () },
}

local function createStateMachine(): StateMachine
    return {
        current = "Idle",
        transitions = {
            Idle = { "Walking", "Running", "Jumping" },
            Walking = { "Idle", "Running", "Jumping" },
            Running = { "Idle", "Walking", "Jumping" },
            Jumping = { "Falling" },
            Falling = { "Idle", "Walking", "Running" },
        },
        onEnter = {},
        onExit = {},
    }
end

local function canTransition(sm: StateMachine, to: State): boolean
    local allowed = sm.transitions[sm.current]
    return allowed and table.find(allowed, to) ~= nil
end

local function transition(sm: StateMachine, to: State): boolean
    if not canTransition(sm, to) then
        return false
    end

    local exitFn = sm.onExit[sm.current]
    if exitFn then exitFn() end

    sm.current = to

    local enterFn = sm.onEnter[to]
    if enterFn then enterFn() end

    return true
end
```

---

## Object Pool

```lua
--!strict
type Pool<T> = {
    _available: { T },
    _inUse: { T },
    _create: () -> T,
    _reset: (T) -> (),
}

local function createPool<T>(create: () -> T, reset: (T) -> (), initialSize: number?): Pool<T>
    local pool: Pool<T> = {
        _available = {},
        _inUse = {},
        _create = create,
        _reset = reset,
    }

    for _ = 1, initialSize or 0 do
        table.insert(pool._available, create())
    end

    return pool
end

local function acquire<T>(pool: Pool<T>): T
    local obj = table.remove(pool._available)
    if not obj then
        obj = pool._create()
    end
    table.insert(pool._inUse, obj)
    return obj
end

local function release<T>(pool: Pool<T>, obj: T)
    local index = table.find(pool._inUse, obj)
    if index then
        table.remove(pool._inUse, index)
        pool._reset(obj)
        table.insert(pool._available, obj)
    end
end

-- Usage
local partPool = createPool(
    function()
        local part = Instance.new("Part")
        part.Anchored = true
        return part
    end,
    function(part)
        part.Parent = nil
        part.CFrame = CFrame.new()
    end,
    10
)
```

---

## Observer Pattern (Signals)

```lua
--!strict

-- Simple signal implementation
type Connection = {
    Disconnect: (self: Connection) -> (),
}

type Signal<T...> = {
    Fire: (self: Signal<T...>, T...) -> (),
    Connect: (self: Signal<T...>, (T...) -> ()) -> Connection,
    Once: (self: Signal<T...>, (T...) -> ()) -> Connection,
    Wait: (self: Signal<T...>) -> T...,
}

local function createSignal<T...>(): Signal<T...>
    local listeners: { (T...) -> () } = {}

    local signal = {}

    function signal:Fire(...: T...)
        for _, listener in listeners do
            task.spawn(listener, ...)
        end
    end

    function signal:Connect(fn: (T...) -> ()): Connection
        table.insert(listeners, fn)

        return {
            Disconnect = function()
                local index = table.find(listeners, fn)
                if index then
                    table.remove(listeners, index)
                end
            end,
        }
    end

    function signal:Once(fn: (T...) -> ()): Connection
        local connection
        connection = self:Connect(function(...)
            connection:Disconnect()
            fn(...)
        end)
        return connection
    end

    function signal:Wait(): T...
        local thread = coroutine.running()
        local connection
        connection = self:Connect(function(...)
            connection:Disconnect()
            task.spawn(thread, ...)
        end)
        return coroutine.yield()
    end

    return signal
end
```

---

## Command Pattern

```lua
--!strict
type Command = {
    execute: () -> (),
    undo: () -> (),
}

type CommandHistory = {
    _history: { Command },
    _index: number,
}

local function createCommandHistory(): CommandHistory
    return {
        _history = {},
        _index = 0,
    }
end

local function execute(history: CommandHistory, command: Command)
    command.execute()

    -- Remove any redo history
    while #history._history > history._index do
        table.remove(history._history)
    end

    table.insert(history._history, command)
    history._index += 1
end

local function undo(history: CommandHistory): boolean
    if history._index <= 0 then
        return false
    end

    history._history[history._index].undo()
    history._index -= 1
    return true
end

local function redo(history: CommandHistory): boolean
    if history._index >= #history._history then
        return false
    end

    history._index += 1
    history._history[history._index].execute()
    return true
end
```

---

## Retry Pattern

```lua
--!strict
type RetryConfig = {
    maxAttempts: number,
    delaySeconds: number,
    backoffMultiplier: number?,
    maxDelaySeconds: number?,
}

local function retry<T>(
    fn: () -> T,
    config: RetryConfig
): (boolean, T | string)
    local attempts = 0
    local delay = config.delaySeconds

    while attempts < config.maxAttempts do
        attempts += 1

        local success, result = pcall(fn)

        if success then
            return true, result
        end

        if attempts < config.maxAttempts then
            task.wait(delay)

            if config.backoffMultiplier then
                delay *= config.backoffMultiplier
                if config.maxDelaySeconds then
                    delay = math.min(delay, config.maxDelaySeconds)
                end
            end
        else
            return false, tostring(result)
        end
    end

    return false, "Max attempts reached"
end

-- Usage
local success, data = retry(function()
    return dataStore:GetAsync(key)
end, {
    maxAttempts = 3,
    delaySeconds = 1,
    backoffMultiplier = 2,
    maxDelaySeconds = 10,
})
```

---

## Debounce and Throttle

```lua
--!strict

-- Debounce: Wait until calls stop, then execute once
local function debounce<T...>(fn: (T...) -> (), delaySeconds: number): (T...) -> ()
    local lastCall = 0
    local scheduled = false

    return function(...: T...)
        local args = { ... }
        lastCall = os.clock()

        if not scheduled then
            scheduled = true
            task.delay(delaySeconds, function()
                while os.clock() - lastCall < delaySeconds do
                    task.wait(delaySeconds - (os.clock() - lastCall))
                end
                scheduled = false
                fn(table.unpack(args))
            end)
        end
    end
end

-- Throttle: Execute immediately, then ignore calls for duration
local function throttle<T...>(fn: (T...) -> (), intervalSeconds: number): (T...) -> ()
    local lastCall = 0

    return function(...: T...)
        local now = os.clock()
        if now - lastCall >= intervalSeconds then
            lastCall = now
            fn(...)
        end
    end
end

-- Usage
local debouncedSearch = debounce(function(query)
    performSearch(query)
end, 0.3)

local throttledUpdate = throttle(function()
    updateUI()
end, 0.1)
```

---

## Lazy Initialization

```lua
--!strict

-- Single value
local _expensiveData: ExpensiveData? = nil

local function getExpensiveData(): ExpensiveData
    if not _expensiveData then
        _expensiveData = computeExpensiveData()
    end
    return _expensiveData
end

-- With memoization
local function memoize<K, V>(fn: (K) -> V): (K) -> V
    local cache: { [K]: V } = {}

    return function(key: K): V
        local cached = cache[key]
        if cached ~= nil then
            return cached
        end

        local value = fn(key)
        cache[key] = value
        return value
    end
end

-- Usage
local getItemData = memoize(function(itemId: string)
    return loadItemFromDataStore(itemId)
end)
```

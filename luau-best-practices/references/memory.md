# Memory Management in Luau

## Connection Management

### Always Store and Disconnect

```lua
--!strict

-- BAD: Lost connection, can't disconnect
event:Connect(function()
    -- handler
end)

-- GOOD: Store for later cleanup
local connection = event:Connect(function()
    -- handler
end)

-- When done:
connection:Disconnect()
```

### Connection Tracking Pattern

```lua
--!strict
local connections: { RBXScriptConnection } = {}

local function connect(event: RBXScriptSignal, handler: (...any) -> ())
    local connection = event:Connect(handler)
    table.insert(connections, connection)
    return connection
end

local function disconnectAll()
    for _, connection in connections do
        connection:Disconnect()
    end
    table.clear(connections)
end

-- Usage
connect(Players.PlayerAdded, onPlayerAdded)
connect(RunService.Heartbeat, onHeartbeat)

-- Cleanup
disconnectAll()
```

---

## Maid/Janitor Pattern

### Simple Maid Implementation

```lua
--!strict
type Maid = {
    _tasks: { any },
    GiveTask: (self: Maid, task: any) -> (),
    Cleanup: (self: Maid) -> (),
    Destroy: (self: Maid) -> (),
}

local function createMaid(): Maid
    local maid = {
        _tasks = {},
    }

    function maid:GiveTask(task: any)
        table.insert(self._tasks, task)
    end

    function maid:Cleanup()
        for _, task in self._tasks do
            if typeof(task) == "RBXScriptConnection" then
                task:Disconnect()
            elseif typeof(task) == "Instance" then
                task:Destroy()
            elseif typeof(task) == "function" then
                task()
            elseif typeof(task) == "table" and task.Destroy then
                task:Destroy()
            end
        end
        table.clear(self._tasks)
    end

    function maid:Destroy()
        self:Cleanup()
    end

    return maid
end

-- Usage
local maid = createMaid()

maid:GiveTask(event:Connect(handler))
maid:GiveTask(Instance.new("Part"))
maid:GiveTask(function()
    print("Custom cleanup")
end)

-- Single call cleans everything
maid:Destroy()
```

### Per-Player Maids

```lua
--!strict
local playerMaids: { [Player]: Maid } = {}

Players.PlayerAdded:Connect(function(player)
    local maid = createMaid()
    playerMaids[player] = maid

    -- All player-specific connections go through maid
    maid:GiveTask(player.CharacterAdded:Connect(function(character)
        -- ...
    end))

    maid:GiveTask(someEvent:Connect(function()
        -- Player-specific handler
    end))
end)

Players.PlayerRemoving:Connect(function(player)
    local maid = playerMaids[player]
    if maid then
        maid:Destroy()
        playerMaids[player] = nil
    end
end)
```

---

## Instance Cleanup

### Destroy vs Parent = nil

```lua
-- Destroy: Removes from parent AND disconnects all events
instance:Destroy()

-- Parent = nil: Just removes from parent, connections stay!
instance.Parent = nil  -- Memory leak if connections exist

-- Always use Destroy for cleanup
```

### Instance Pooling

```lua
--!strict
type InstancePool<T> = {
    _available: { T },
    _template: T,
    Acquire: (self: InstancePool<T>) -> T,
    Release: (self: InstancePool<T>, instance: T) -> (),
    Prewarm: (self: InstancePool<T>, count: number) -> (),
}

local function createInstancePool<T>(template: T): InstancePool<T>
    local pool = {
        _available = {},
        _template = template,
    }

    function pool:Acquire(): T
        local instance = table.remove(self._available)
        if not instance then
            instance = self._template:Clone()
        end
        return instance
    end

    function pool:Release(instance: T)
        instance.Parent = nil
        -- Reset any properties if needed
        if instance:IsA("BasePart") then
            instance.CFrame = CFrame.new(0, -1000, 0)
        end
        table.insert(self._available, instance)
    end

    function pool:Prewarm(count: number)
        for _ = 1, count do
            local instance = self._template:Clone()
            table.insert(self._available, instance)
        end
    end

    return pool
end

-- Usage
local bulletPool = createInstancePool(bulletTemplate)
bulletPool:Prewarm(50)

local bullet = bulletPool:Acquire()
bullet.Parent = workspace
-- Later...
bulletPool:Release(bullet)
```

---

## Weak References

### Weak Table Modes

```lua
-- "k" = weak keys (keys can be garbage collected)
local cache = setmetatable({}, { __mode = "k" })

-- "v" = weak values (values can be garbage collected)
local cache = setmetatable({}, { __mode = "v" })

-- "kv" = both weak
local cache = setmetatable({}, { __mode = "kv" })
```

### Player Data Cache with Weak References

```lua
--!strict
-- Cache that automatically cleans up when players leave
local playerCache = setmetatable({}, { __mode = "k" })

local function getPlayerData(player: Player): PlayerData
    local cached = playerCache[player]
    if cached then
        return cached
    end

    local data = loadData(player)
    playerCache[player] = data
    return data
end

-- No manual cleanup needed - when player object is garbage collected,
-- the cache entry is automatically removed
```

### Instance Association

```lua
--!strict
-- Associate data with instances without preventing garbage collection
local instanceData = setmetatable({}, { __mode = "k" })

local function setData(instance: Instance, data: any)
    instanceData[instance] = data
end

local function getData(instance: Instance): any
    return instanceData[instance]
end

-- When instance is destroyed and collected, data is automatically cleaned up
```

---

## Common Memory Leaks

### Leak: Untracked Connections

```lua
-- LEAK: Connection never disconnected
RunService.Heartbeat:Connect(function()
    updatePlayer()
end)

-- FIX: Store and disconnect
local heartbeatConnection = RunService.Heartbeat:Connect(function()
    updatePlayer()
end)

-- On cleanup:
heartbeatConnection:Disconnect()
```

### Leak: Growing Tables

```lua
-- LEAK: Table grows forever
local history = {}

local function recordAction(action)
    table.insert(history, action)  -- Never removed!
end

-- FIX: Limit size or use circular buffer
local MAX_HISTORY = 100
local history = {}
local historyIndex = 0

local function recordAction(action)
    historyIndex = (historyIndex % MAX_HISTORY) + 1
    history[historyIndex] = action
end
```

### Leak: Closures Capturing References

```lua
-- LEAK: Closure keeps reference to large data
local function createHandler(largeData)
    return function()
        -- Only uses one field but captures entire table
        print(largeData.name)
    end
end

-- FIX: Extract only what's needed
local function createHandler(largeData)
    local name = largeData.name  -- Capture only the needed value
    return function()
        print(name)
    end
end
```

### Leak: Event Listeners on Destroyed Instances

```lua
-- LEAK: Connection survives instance destruction
local part = workspace.Part
part.Touched:Connect(function()
    -- This connection persists even after part:Destroy()
end)

-- FIX: Use Destroying event or maid
local maid = createMaid()
maid:GiveTask(part.Touched:Connect(function()
    -- handler
end))
maid:GiveTask(part)

-- Or use Destroying
part.Destroying:Connect(function()
    -- Cleanup when part is about to be destroyed
end)
```

---

## Debugging Memory Issues

### Tracking Table Sizes

```lua
local function getTableSize(t): number
    local count = 0
    for _ in t do
        count += 1
    end
    return count
end

local function logMemoryStats()
    print("Players cached:", getTableSize(playerCache))
    print("Connections:", #connections)
    print("Pool available:", #pool._available)
end

-- Call periodically
task.spawn(function()
    while true do
        task.wait(60)
        logMemoryStats()
    end
end)
```

### Memory Profiling

```lua
-- Before operation
local before = gcinfo()  -- Returns KB of memory used

-- Do operation
doExpensiveOperation()

-- After operation
local after = gcinfo()
print("Memory delta:", after - before, "KB")
```

### Forcing Garbage Collection (Debug Only)

```lua
-- Force GC to see true memory usage
-- Only use in development/debugging
collectgarbage("collect")
local memory = gcinfo()
print("Memory after GC:", memory, "KB")
```

---

## Best Practices Summary

| Do | Don't |
|----|-------|
| Store all connections | Fire-and-forget connections |
| Use Maid/Janitor for cleanup | Manual cleanup tracking |
| Destroy instances when done | Set Parent = nil |
| Use weak tables for caches | Strong references to players |
| Pool frequently created objects | Create/destroy repeatedly |
| Extract needed values from closures | Capture entire tables |
| Limit collection sizes | Unbounded growth |
| Disconnect on player leave | Assume connections auto-clean |

# Luau Code Style Guide

## Naming Conventions

### Summary Table

| Type | Convention | Example |
|------|------------|---------|
| Type alias | PascalCase | `type PlayerData = {}` |
| Module/Class | PascalCase | `local ShopService = {}` |
| Function | camelCase | `function getData()` |
| Method | camelCase | `function Shop:purchaseItem()` |
| Variable | camelCase | `local playerCount = 0` |
| Constant | SCREAMING_SNAKE | `local MAX_HEALTH = 100` |
| Private | _prefixed | `local _cache = {}` |
| Enum-like | PascalCase | `local State = { Running = 1 }` |

### Detailed Guidelines

**Types and Interfaces:**
```lua
type UserId = number
type PlayerData = {
    id: UserId,
    name: string,
    coins: number,
}

export type ShopItem = {
    id: string,
    price: number,
    name: string,
}
```

**Modules and Services:**
```lua
local PlayerService = {}
local CombatController = {}
local InventoryManager = {}
```

**Functions:**
```lua
-- Regular functions
local function calculateDamage() end
local function getPlayerData() end
local function isValidTarget() end

-- Boolean-returning functions: use is/has/can/should
local function isAlive() end
local function hasPermission() end
local function canAfford() end
local function shouldProcess() end
```

**Variables:**
```lua
local playerCount = 0
local currentTarget = nil
local itemsInInventory = {}

-- Avoid single letters except in loops
for i, v in items do end  -- OK
for index, value in items do end  -- Also OK
local x = 5  -- BAD outside math context
```

**Constants:**
```lua
local MAX_PLAYERS = 50
local DEFAULT_WALK_SPEED = 16
local DATASTORE_KEY_PREFIX = "player_"
local HTTP_TIMEOUT_SECONDS = 30
```

**Private Members:**
```lua
local _initialized = false
local _connections = {}
local _cache = {}

local function _validateInput() end
local function _processInternal() end
```

---

## Formatting

### Indentation and Spacing

```lua
-- Use tabs (Roblox convention) or consistent spaces
-- One blank line between logical sections
-- No trailing whitespace

local function process(data)
    if not data then
        return nil
    end

    local result = transform(data)

    return result
end
```

### Line Length

Keep lines under 100 characters. Break long lines:

```lua
-- Long function calls
local result = someModule:doSomethingComplex(
    firstArgument,
    secondArgument,
    thirdArgument
)

-- Long conditions
if playerHasPermission
    and itemIsAvailable
    and playerCanAfford(item)
then
    purchaseItem()
end

-- Long type definitions
type ComplexType = {
    id: string,
    name: string,
    data: {
        nested: number,
        values: { string },
    },
}
```

### Braces and Parentheses

```lua
-- Tables: consistent style within project
local config = {
    enabled = true,
    maxItems = 100,
}

-- Single-line for short tables
local point = { x = 0, y = 0 }

-- Functions: space before parentheses in definitions
local function doSomething(arg)
end

-- No space in calls
doSomething(value)
```

---

## File Structure

### Canonical Order

```lua
--!strict

-- ============================================
-- 1. SERVICES (Roblox services)
-- ============================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ============================================
-- 2. IMPORTS (require statements)
-- ============================================
local Packages = ReplicatedStorage.Packages
local Signal = require(Packages.Signal)
local Promise = require(Packages.Promise)
local Types = require(script.Parent.Types)

-- ============================================
-- 3. CONSTANTS
-- ============================================
local MAX_RETRIES = 3
local CACHE_DURATION = 60
local DEFAULT_CONFIG = {
    enabled = true,
    debug = false,
}

-- ============================================
-- 4. TYPES
-- ============================================
type Config = {
    enabled: boolean,
    debug: boolean,
}

type CacheEntry = {
    value: any,
    timestamp: number,
}

-- ============================================
-- 5. MODULE TABLE
-- ============================================
local MyModule = {}
MyModule.__index = MyModule

-- ============================================
-- 6. PRIVATE STATE
-- ============================================
local _initialized = false
local _cache: { [string]: CacheEntry } = {}
local _connections: { RBXScriptConnection } = {}

-- ============================================
-- 7. PRIVATE FUNCTIONS
-- ============================================
local function _validateConfig(config: Config): boolean
    return config.enabled ~= nil
end

local function _cleanupCache()
    local now = os.time()
    for key, entry in _cache do
        if now - entry.timestamp > CACHE_DURATION then
            _cache[key] = nil
        end
    end
end

-- ============================================
-- 8. PUBLIC API
-- ============================================
function MyModule.new(config: Config?): MyModule
    local self = setmetatable({}, MyModule)
    self.config = config or DEFAULT_CONFIG
    return self
end

function MyModule:init()
    if _initialized then
        warn("MyModule already initialized")
        return
    end
    _initialized = true
end

function MyModule:destroy()
    for _, connection in _connections do
        connection:Disconnect()
    end
    table.clear(_connections)
    table.clear(_cache)
    _initialized = false
end

-- ============================================
-- 9. RETURN
-- ============================================
return MyModule
```

---

## Comments

### When to Comment

```lua
-- DO: Explain WHY, not WHAT
-- Offset by 0.5 to center the hitbox (character pivot is at feet)
local hitboxPosition = position + Vector3.new(0, 0.5, 0)

-- DO: Document complex algorithms
-- Uses binary search to find insertion point in O(log n)
local function findInsertIndex(sorted, value)
    ...
end

-- DO: Warn about non-obvious behavior
-- WARNING: This function yields! Do not call from events.
local function loadPlayerData(player)
    ...
end

-- DON'T: State the obvious
local count = 0  -- Initialize count to zero (BAD)
count = count + 1  -- Increment count (BAD)
```

### Documentation Comments

```lua
--[=[
    Purchases an item for the player.

    @param player Player -- The player making the purchase
    @param itemId string -- The item identifier
    @param quantity number -- Amount to purchase (default: 1)
    @return boolean -- Whether purchase succeeded
    @error "Insufficient funds" -- Player cannot afford item
]=]
function Shop:purchaseItem(player: Player, itemId: string, quantity: number?): boolean
    ...
end
```

### TODO Comments

```lua
-- TODO: Implement retry logic for failed saves
-- FIXME: Race condition when player leaves during save
-- HACK: Workaround for engine bug #12345
-- NOTE: This assumes player is already validated
```

---

## Best Practices

### Prefer Early Returns

```lua
-- BAD: Deep nesting
function process(data)
    if data then
        if data.valid then
            if data.ready then
                return doWork(data)
            end
        end
    end
    return nil
end

-- GOOD: Early returns
function process(data)
    if not data then return nil end
    if not data.valid then return nil end
    if not data.ready then return nil end

    return doWork(data)
end
```

### Keep Functions Small

```lua
-- BAD: 200+ line function doing everything

-- GOOD: Composed small functions
function processOrder(order)
    if not validateOrder(order) then
        return { success = false, error = "Invalid order" }
    end

    local items = reserveItems(order)
    if not items then
        return { success = false, error = "Items unavailable" }
    end

    local payment = processPayment(order)
    if not payment.success then
        releaseItems(items)
        return { success = false, error = payment.error }
    end

    return finalizeOrder(order, items, payment)
end
```

### Use Descriptive Names

```lua
-- BAD
local t = {}
local n = 0
local function p(x) end

-- GOOD
local playerScores = {}
local activePlayerCount = 0
local function processTransaction(transaction) end
```

### Avoid Magic Numbers

```lua
-- BAD
if player.Health < 20 then
    task.wait(5)
    heal(player, 50)
end

-- GOOD
local CRITICAL_HEALTH_THRESHOLD = 20
local HEAL_COOLDOWN_SECONDS = 5
local HEAL_AMOUNT = 50

if player.Health < CRITICAL_HEALTH_THRESHOLD then
    task.wait(HEAL_COOLDOWN_SECONDS)
    heal(player, HEAL_AMOUNT)
end
```

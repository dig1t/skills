# Security Best Practices for Roblox

## Core Principle: Server Authority

The server is the single source of truth. The client is merely an input device and display.

```
TRUSTED                    UNTRUSTED
┌──────────────┐          ┌──────────────┐
│   SERVER     │◄─────────│   CLIENT     │
│              │          │              │
│ - Game state │  Remotes │ - Display    │
│ - Logic      │          │ - Input      │
│ - Validation │─────────►│ - Effects    │
└──────────────┘          └──────────────┘
```

---

## Never Trust the Client

### BAD: Client Decides Outcome

```lua
-- CLIENT (sends damage amount)
local damage = calculateDamage()
DamageRemote:FireServer(targetId, damage)

-- SERVER (trusts client)
DamageRemote.OnServerEvent:Connect(function(player, targetId, damage)
    local target = getTarget(targetId)
    target.Health -= damage  -- Client controls damage!
end)
```

### GOOD: Server Decides Everything

```lua
-- CLIENT (sends only intent)
AttackRemote:FireServer(targetId)

-- SERVER (validates and calculates)
AttackRemote.OnServerEvent:Connect(function(player, targetId)
    -- Validate target
    local target = getTarget(targetId)
    if not target then return end

    -- Validate player can attack
    if not canAttack(player) then return end

    -- Validate range/line of sight
    if not inRange(player, target) then return end

    -- Server calculates damage
    local damage = calculateDamage(player)
    target.Health -= damage
end)
```

---

## Input Validation

### Validate Everything

```lua
RemoteFunction.OnServerInvoke = function(player, ...)
    local args = { ... }

    -- 1. Validate argument count
    if #args ~= 3 then return end

    local action, targetId, data = args[1], args[2], args[3]

    -- 2. Validate types
    if typeof(action) ~= "string" then return end
    if typeof(targetId) ~= "number" then return end
    if typeof(data) ~= "table" then return end

    -- 3. Validate ranges/bounds
    if #action > 50 then return end
    if targetId < 0 or targetId > 2^31 then return end

    -- 4. Validate against expected values
    local validActions = { "buy", "sell", "trade" }
    if not table.find(validActions, action) then return end

    -- 5. Validate business logic
    if not playerCanPerform(player, action) then return end

    -- Now safe to process
    return processAction(player, action, targetId, data)
end
```

### Type Validation Helper

```lua
--!strict
type TypeValidator = {
    string: (value: any, maxLen: number?) -> boolean,
    number: (value: any, min: number?, max: number?) -> boolean,
    integer: (value: any, min: number?, max: number?) -> boolean,
    boolean: (value: any) -> boolean,
    table: (value: any) -> boolean,
    instance: (value: any, className: string?) -> boolean,
}

local Validate: TypeValidator = {
    string = function(value, maxLen)
        if typeof(value) ~= "string" then return false end
        if maxLen and #value > maxLen then return false end
        return true
    end,

    number = function(value, min, max)
        if typeof(value) ~= "number" then return false end
        if value ~= value then return false end  -- NaN check
        if min and value < min then return false end
        if max and value > max then return false end
        return true
    end,

    integer = function(value, min, max)
        if not Validate.number(value, min, max) then return false end
        if value ~= math.floor(value) then return false end
        return true
    end,

    boolean = function(value)
        return typeof(value) == "boolean"
    end,

    table = function(value)
        return typeof(value) == "table"
    end,

    instance = function(value, className)
        if typeof(value) ~= "Instance" then return false end
        if className and not value:IsA(className) then return false end
        return true
    end,
}

-- Usage
RemoteEvent.OnServerEvent:Connect(function(player, itemId, quantity)
    if not Validate.string(itemId, 50) then return end
    if not Validate.integer(quantity, 1, 999) then return end
    -- Process...
end)
```

---

## Rate Limiting

### Basic Rate Limiter

```lua
--!strict
local lastAction: { [Player]: number } = {}
local COOLDOWN = 0.5

local function isRateLimited(player: Player): boolean
    local now = os.clock()
    local last = lastAction[player]

    if last and now - last < COOLDOWN then
        return true
    end

    lastAction[player] = now
    return false
end

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
    lastAction[player] = nil
end)

-- Usage
RemoteEvent.OnServerEvent:Connect(function(player, ...)
    if isRateLimited(player) then
        warn(player.Name, "is sending requests too fast")
        return
    end
    -- Process...
end)
```

### Per-Action Rate Limiter

```lua
--!strict
type RateLimits = { [string]: number }  -- action -> cooldown in seconds

local rateLimits: RateLimits = {
    attack = 0.5,
    chat = 1,
    purchase = 2,
}

local lastActions: { [Player]: { [string]: number } } = {}

local function isRateLimited(player: Player, action: string): boolean
    local cooldown = rateLimits[action]
    if not cooldown then return false end

    local playerActions = lastActions[player]
    if not playerActions then
        playerActions = {}
        lastActions[player] = playerActions
    end

    local now = os.clock()
    local last = playerActions[action]

    if last and now - last < cooldown then
        return true
    end

    playerActions[action] = now
    return false
end
```

### Token Bucket Rate Limiter

```lua
--!strict
type TokenBucket = {
    tokens: number,
    lastRefill: number,
    maxTokens: number,
    refillRate: number,  -- tokens per second
}

local buckets: { [Player]: TokenBucket } = {}

local function getBucket(player: Player): TokenBucket
    local bucket = buckets[player]
    if not bucket then
        bucket = {
            tokens = 10,
            lastRefill = os.clock(),
            maxTokens = 10,
            refillRate = 2,
        }
        buckets[player] = bucket
    end

    -- Refill tokens
    local now = os.clock()
    local elapsed = now - bucket.lastRefill
    local newTokens = elapsed * bucket.refillRate
    bucket.tokens = math.min(bucket.maxTokens, bucket.tokens + newTokens)
    bucket.lastRefill = now

    return bucket
end

local function tryConsume(player: Player, cost: number?): boolean
    local bucket = getBucket(player)
    cost = cost or 1

    if bucket.tokens >= cost then
        bucket.tokens -= cost
        return true
    end

    return false
end
```

---

## Secure Remote Communication

### Remote Validation Wrapper

```lua
--!strict
type RemoteHandler = (player: Player, ...any) -> ...any

type ValidatorConfig = {
    rateLimit: number?,
    validators: { (any) -> boolean }?,
    requireCharacter: boolean?,
}

local function createSecureRemote(
    remote: RemoteEvent | RemoteFunction,
    handler: RemoteHandler,
    config: ValidatorConfig?
)
    config = config or {}

    local function secureHandler(player: Player, ...: any): ...any
        -- Rate limiting
        if config.rateLimit and isRateLimited(player) then
            return
        end

        -- Require character
        if config.requireCharacter and not player.Character then
            return
        end

        -- Validate arguments
        local args = { ... }
        if config.validators then
            for i, validator in config.validators do
                if not validator(args[i]) then
                    warn("Validation failed for", player.Name, "arg", i)
                    return
                end
            end
        end

        -- Call actual handler
        return handler(player, ...)
    end

    if remote:IsA("RemoteEvent") then
        remote.OnServerEvent:Connect(secureHandler)
    else
        remote.OnServerInvoke = secureHandler
    end
end

-- Usage
createSecureRemote(PurchaseRemote, function(player, itemId, quantity)
    return ShopService:Purchase(player, itemId, quantity)
end, {
    rateLimit = 1,
    requireCharacter = true,
    validators = {
        function(v) return Validate.string(v, 50) end,
        function(v) return Validate.integer(v, 1, 99) end,
    },
})
```

---

## Anti-Exploit Patterns

### Server-Side Hit Detection

```lua
-- Instead of trusting client hit detection:
RemoteEvent.OnServerEvent:Connect(function(player, targetId)
    local character = player.Character
    if not character then return end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    local target = getCharacterById(targetId)
    if not target then return end

    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    -- Server validates distance
    local distance = (humanoidRootPart.Position - targetRoot.Position).Magnitude
    if distance > MAX_ATTACK_RANGE then
        warn(player.Name, "attempted attack from too far")
        return
    end

    -- Server validates line of sight
    local rayResult = workspace:Raycast(
        humanoidRootPart.Position,
        (targetRoot.Position - humanoidRootPart.Position).Unit * distance
    )

    if rayResult and rayResult.Instance:FindFirstAncestorWhichIsA("Model") ~= target then
        return  -- Something in the way
    end

    -- Now safe to apply damage
    applyDamage(player, target)
end)
```

### Server-Side Movement Validation

```lua
--!strict
local lastPositions: { [Player]: { position: Vector3, time: number } } = {}
local MAX_SPEED = 50  -- studs per second (with some tolerance)

local function validateMovement(player: Player): boolean
    local character = player.Character
    if not character then return true end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return true end

    local currentPos = root.Position
    local currentTime = os.clock()

    local last = lastPositions[player]
    if not last then
        lastPositions[player] = { position = currentPos, time = currentTime }
        return true
    end

    local distance = (currentPos - last.position).Magnitude
    local elapsed = currentTime - last.time
    local speed = distance / elapsed

    lastPositions[player] = { position = currentPos, time = currentTime }

    if speed > MAX_SPEED then
        warn(player.Name, "moving too fast:", speed, "studs/s")
        return false
    end

    return true
end
```

### Ownership Verification

```lua
local function playerOwnsItem(player: Player, itemId: string): boolean
    local inventory = InventoryService:GetInventory(player)
    return inventory and inventory[itemId] ~= nil
end

RemoteEvent.OnServerEvent:Connect(function(player, action, itemId)
    -- Verify ownership before any item action
    if not playerOwnsItem(player, itemId) then
        warn(player.Name, "tried to use unowned item:", itemId)
        return
    end

    -- Process action
end)
```

---

## Logging Suspicious Activity

```lua
--!strict
type SuspiciousActivity = {
    player: Player,
    type: string,
    details: string,
    timestamp: number,
}

local suspiciousLog: { SuspiciousActivity } = {}

local function logSuspicious(player: Player, activityType: string, details: string)
    table.insert(suspiciousLog, {
        player = player,
        type = activityType,
        details = details,
        timestamp = os.time(),
    })

    warn(`[SUSPICIOUS] {player.Name}: {activityType} - {details}`)

    -- Send to analytics/moderation system
    pcall(function()
        AnalyticsService:LogSuspiciousActivity(player.UserId, activityType, details)
    end)
end

-- Usage examples
if speed > MAX_SPEED * 2 then
    logSuspicious(player, "SpeedHack", `Moving at {speed} studs/s`)
end

if not playerOwnsItem(player, itemId) then
    logSuspicious(player, "ItemExploit", `Tried to use unowned item: {itemId}`)
end
```

---

## Security Checklist

- [ ] All game state lives on server
- [ ] All remotes validate input types
- [ ] All remotes validate input ranges
- [ ] All remotes have rate limiting
- [ ] All remotes verify player can perform action
- [ ] Hit detection done on server (or verified)
- [ ] Movement speed validated on server
- [ ] Item ownership verified before use
- [ ] Currency/inventory changes only on server
- [ ] Suspicious activity logged
- [ ] No sensitive data sent to clients
- [ ] DataStore keys not guessable from client data

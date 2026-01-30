# Error Handling in Luau

## When to Use pcall

### Always pcall External APIs

```lua
-- DataStores
local success, result = pcall(function()
    return dataStore:GetAsync(key)
end)

-- HTTP
local success, response = pcall(function()
    return HttpService:RequestAsync(request)
end)

-- JSON
local success, decoded = pcall(function()
    return HttpService:JSONDecode(jsonString)
end)

-- LoadAsset
local success, asset = pcall(function()
    return InsertService:LoadAsset(assetId)
end)

-- Any method that can throw
local success, result = pcall(function()
    return instance:FindFirstChildOfClass("Unknown")
end)
```

### Never pcall Internal Logic

```lua
-- BAD: Hiding bugs
local success = pcall(function()
    processPlayerData(data)  -- If this errors, you want to know
end)

-- GOOD: Let errors propagate during development
processPlayerData(data)

-- Or use assert for validation
assert(data, "data is required")
processPlayerData(data)
```

---

## Result Type Pattern

### Basic Result Type

```lua
--!strict
type Result<T, E = string> =
    { ok: true, value: T } |
    { ok: false, error: E }

-- Constructors
local function Ok<T>(value: T): Result<T, never>
    return { ok = true, value = value }
end

local function Err<E>(error: E): Result<never, E>
    return { ok = false, error = error }
end

-- Usage
local function divide(a: number, b: number): Result<number>
    if b == 0 then
        return Err("Division by zero")
    end
    return Ok(a / b)
end

local result = divide(10, 2)
if result.ok then
    print("Result:", result.value)
else
    print("Error:", result.error)
end
```

### Result with Error Types

```lua
--!strict
type DataError =
    | { type: "NotFound", key: string }
    | { type: "Corrupted", key: string, reason: string }
    | { type: "Timeout", key: string, duration: number }

type DataResult<T> = Result<T, DataError>

local function loadData(key: string): DataResult<PlayerData>
    local success, data = pcall(function()
        return dataStore:GetAsync(key)
    end)

    if not success then
        return {
            ok = false,
            error = { type = "Timeout", key = key, duration = 30 }
        }
    end

    if data == nil then
        return {
            ok = false,
            error = { type = "NotFound", key = key }
        }
    end

    if not validateData(data) then
        return {
            ok = false,
            error = { type = "Corrupted", key = key, reason = "Invalid schema" }
        }
    end

    return { ok = true, value = data }
end
```

### Chaining Results

```lua
--!strict
local function map<T, U, E>(result: Result<T, E>, fn: (T) -> U): Result<U, E>
    if result.ok then
        return { ok = true, value = fn(result.value) }
    end
    return result
end

local function flatMap<T, U, E>(result: Result<T, E>, fn: (T) -> Result<U, E>): Result<U, E>
    if result.ok then
        return fn(result.value)
    end
    return result
end

-- Usage
local result = loadData(userId)
result = map(result, function(data)
    return data.inventory
end)
result = flatMap(result, function(inventory)
    return validateInventory(inventory)
end)
```

---

## Retry Strategies

### Simple Retry

```lua
local function retrySimple<T>(fn: () -> T, maxAttempts: number, delay: number): T?
    for attempt = 1, maxAttempts do
        local success, result = pcall(fn)
        if success then
            return result
        end

        if attempt < maxAttempts then
            warn(`Attempt {attempt} failed, retrying in {delay}s...`)
            task.wait(delay)
        end
    end

    warn(`All {maxAttempts} attempts failed`)
    return nil
end
```

### Exponential Backoff

```lua
--!strict
type RetryOptions = {
    maxAttempts: number,
    baseDelay: number,
    maxDelay: number,
    jitter: boolean?,
}

local function retryWithBackoff<T>(fn: () -> T, options: RetryOptions): (boolean, T | string)
    local delay = options.baseDelay

    for attempt = 1, options.maxAttempts do
        local success, result = pcall(fn)

        if success then
            return true, result
        end

        if attempt == options.maxAttempts then
            return false, tostring(result)
        end

        -- Add jitter to prevent thundering herd
        local actualDelay = delay
        if options.jitter then
            actualDelay = delay * (0.5 + math.random())
        end

        warn(`Attempt {attempt} failed: {result}. Retrying in {actualDelay:.2f}s`)
        task.wait(actualDelay)

        -- Exponential backoff
        delay = math.min(delay * 2, options.maxDelay)
    end

    return false, "Max attempts exceeded"
end

-- Usage
local success, data = retryWithBackoff(function()
    return dataStore:GetAsync(key)
end, {
    maxAttempts = 5,
    baseDelay = 1,
    maxDelay = 30,
    jitter = true,
})
```

### Retry with Circuit Breaker

```lua
--!strict
type CircuitBreaker = {
    failures: number,
    lastFailure: number,
    state: "closed" | "open" | "half-open",
}

local function createCircuitBreaker(threshold: number, resetTimeout: number): CircuitBreaker
    return {
        failures = 0,
        lastFailure = 0,
        state = "closed",
    }
end

local function canExecute(cb: CircuitBreaker, threshold: number, resetTimeout: number): boolean
    if cb.state == "closed" then
        return true
    end

    if cb.state == "open" then
        if os.clock() - cb.lastFailure > resetTimeout then
            cb.state = "half-open"
            return true
        end
        return false
    end

    -- half-open: allow one attempt
    return true
end

local function recordSuccess(cb: CircuitBreaker)
    cb.failures = 0
    cb.state = "closed"
end

local function recordFailure(cb: CircuitBreaker, threshold: number)
    cb.failures += 1
    cb.lastFailure = os.clock()

    if cb.failures >= threshold then
        cb.state = "open"
    end
end
```

---

## Validation Patterns

### Input Validation

```lua
--!strict
type ValidationError = {
    field: string,
    message: string,
}

type ValidationResult = Result<nil, { ValidationError }>

local function validatePurchase(itemId: any, quantity: any): ValidationResult
    local errors: { ValidationError } = {}

    -- Type checks
    if typeof(itemId) ~= "string" then
        table.insert(errors, {
            field = "itemId",
            message = "must be a string"
        })
    elseif #itemId == 0 then
        table.insert(errors, {
            field = "itemId",
            message = "cannot be empty"
        })
    elseif #itemId > 50 then
        table.insert(errors, {
            field = "itemId",
            message = "cannot exceed 50 characters"
        })
    end

    if typeof(quantity) ~= "number" then
        table.insert(errors, {
            field = "quantity",
            message = "must be a number"
        })
    elseif quantity ~= math.floor(quantity) then
        table.insert(errors, {
            field = "quantity",
            message = "must be an integer"
        })
    elseif quantity < 1 then
        table.insert(errors, {
            field = "quantity",
            message = "must be at least 1"
        })
    elseif quantity > 999 then
        table.insert(errors, {
            field = "quantity",
            message = "cannot exceed 999"
        })
    end

    if #errors > 0 then
        return { ok = false, error = errors }
    end

    return { ok = true, value = nil }
end
```

### Guard Functions

```lua
--!strict

-- Type guards that narrow types
local function isString(value: unknown): boolean
    return typeof(value) == "string"
end

local function isNumber(value: unknown): boolean
    return typeof(value) == "number"
end

local function isTable(value: unknown): boolean
    return typeof(value) == "table"
end

local function isInstance(value: unknown, className: string?): boolean
    if typeof(value) ~= "Instance" then
        return false
    end
    if className then
        return value:IsA(className)
    end
    return true
end

-- Assertion guards
local function assertString(value: unknown, name: string): string
    assert(typeof(value) == "string", `{name} must be a string`)
    return value
end

local function assertNumber(value: unknown, name: string): number
    assert(typeof(value) == "number", `{name} must be a number`)
    return value
end

local function assertInRange(value: number, min: number, max: number, name: string): number
    assert(value >= min and value <= max, `{name} must be between {min} and {max}`)
    return value
end
```

---

## Error Boundaries

### Safe Execution Wrapper

```lua
--!strict
local function safeExecute<T>(fn: () -> T, fallback: T, errorHandler: ((string) -> ())?): T
    local success, result = pcall(fn)

    if success then
        return result
    end

    if errorHandler then
        errorHandler(tostring(result))
    else
        warn("safeExecute caught error:", result)
    end

    return fallback
end

-- Usage
local config = safeExecute(function()
    return HttpService:JSONDecode(jsonString)
end, DEFAULT_CONFIG, function(err)
    Analytics:TrackError("ConfigParseFailed", err)
end)
```

### Error Boundaries for UI

```lua
--!strict
local function withErrorBoundary<T...>(
    fn: (T...) -> (),
    onError: (error: string, T...) -> ()
): (T...) -> ()
    return function(...: T...)
        local args = { ... }
        local success, err = pcall(function()
            fn(table.unpack(args))
        end)

        if not success then
            onError(tostring(err), table.unpack(args))
        end
    end
end

-- Usage
local safeRender = withErrorBoundary(function(data)
    renderComplexUI(data)
end, function(err, data)
    renderErrorState(err)
    reportError(err, data)
end)
```

---

## Logging Errors

### Structured Error Logging

```lua
--!strict
type ErrorContext = {
    userId: number?,
    action: string,
    data: { [string]: any }?,
    stack: string?,
}

local function logError(message: string, context: ErrorContext)
    local entry = {
        timestamp = os.time(),
        message = message,
        context = context,
    }

    -- Log locally
    warn(`[ERROR] {message}`, context)

    -- Send to analytics/monitoring
    pcall(function()
        AnalyticsService:LogError(entry)
    end)
end

-- Usage
local success, result = pcall(function()
    return dataStore:UpdateAsync(key, transform)
end)

if not success then
    logError("DataStore update failed", {
        userId = player.UserId,
        action = "SaveInventory",
        data = { key = key },
        stack = debug.traceback(),
    })
end
```

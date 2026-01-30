# Luau Performance Patterns

Type-safe patterns that maintain optimal runtime performance.

## Table Access

### Use Dot Notation
```lua
-- Fast
local name = player.Name
local pos = part.Position

-- Slower (string lookup)
local name = player["Name"]
```

### Field vs Method Placement
```lua
-- Fast: Methods in metatable, fields in instance
type Player = {
    name: string,
    score: number,
}

type PlayerImpl = {
    __index: PlayerImpl,
    getName: (self: Player) -> string,
}

local PlayerImpl: PlayerImpl = {} :: PlayerImpl
PlayerImpl.__index = PlayerImpl

-- Fields are direct access
local p: Player = { name = "Bob", score = 0 }
print(p.name)  -- direct field access

-- Methods go through metatable (one lookup)
function PlayerImpl:getName(): string
    return self.name
end
```

### Shallow Metatables
```lua
-- Fast: Direct __index to table
local MT = {}
MT.__index = MT

-- Slow: __index is a function
local MT = {}
MT.__index = function(t, k)
    return rawget(MT, k)
end

-- Slow: Deep chain
local A = { __index = {} }
local B = { __index = A }
local C = { __index = B }  -- 3 lookups
```

---

## Localizing Builtins

```lua
--!strict

-- Fast: Localized at module scope
local max = math.max
local insert = table.insert
local format = string.format

local function process(values: { number }): number
    local result = 0
    for _, v in values do
        result = max(result, v)  -- uses local
    end
    return result
end

-- Slower: Global lookup each call
local function process(values: { number }): number
    local result = 0
    for _, v in values do
        result = math.max(result, v)  -- global lookup
    end
    return result
end
```

**Note:** Builtins still get fastcall optimization even when localized.

---

## Table Creation

### Preallocate When Size Known
```lua
-- Fast: Preallocated
local function createArray(n: number): { number }
    local arr = table.create(n, 0)
    for i = 1, n do
        arr[i] = i * 2
    end
    return arr
end

-- Slower: Grows dynamically
local function createArray(n: number): { number }
    local arr = {}
    for i = 1, n do
        arr[i] = i * 2  -- may trigger resize
    end
    return arr
end
```

### Table Literals with All Fields
```lua
-- Fast: Complete literal (shape known at compile time)
local point: { x: number, y: number } = { x = 0, y = 0 }

-- Slower: Added after creation
local point: { x: number, y: number } = {}
point.x = 0  -- shape change
point.y = 0  -- shape change
```

### Consistent Table Shapes
```lua
type Entity = {
    x: number,
    y: number,
    health: number?,
}

-- Fast: All entities have same shape
local entities: { Entity } = {}
for i = 1, 100 do
    entities[i] = { x = 0, y = 0, health = 100 }  -- same fields
end

-- Slower: Mixed shapes
local entities: { Entity } = {}
for i = 1, 100 do
    if i % 2 == 0 then
        entities[i] = { x = 0, y = 0 }  -- missing health
    else
        entities[i] = { x = 0, y = 0, health = 100 }
    end
end
```

---

## Iteration

### Generic Iteration (Preferred)
```lua
-- Fast: Generic for
local function sum(t: { number }): number
    local total = 0
    for _, v in t do
        total += v
    end
    return total
end

-- Also fast: ipairs for arrays
for i, v in ipairs(arr) do
    -- ...
end

-- Avoid: Manual pairs call (slightly slower)
for k, v in pairs(t) do
    -- ...
end
```

### Avoid Index-Based When Possible
```lua
-- Fast
for _, item in items do
    process(item)
end

-- Slower (index arithmetic)
for i = 1, #items do
    process(items[i])
end
```

---

## Closures

### Module-Scope Closures Are Cached
```lua
--!strict

local constant = 42

-- This closure is cached (constant upvalue)
local function getConstant(): number
    return constant
end

-- Called many times, but closure created once
for i = 1, 1000 do
    print(getConstant())
end
```

### Avoid Creating Closures in Loops
```lua
-- Slow: Creates closure each iteration
local function bad()
    for i = 1, 1000 do
        local fn = function()
            return i
        end
        process(fn)
    end
end

-- Fast: Reuse closure or avoid
local function good()
    local function fn(i: number): number
        return i
    end
    for i = 1, 1000 do
        process(fn, i)  -- pass value instead
    end
end
```

---

## Avoid Deoptimization

### Never Use getfenv/setfenv
```lua
-- Causes deoptimization
local env = getfenv()  -- BAD
setfenv(1, {})         -- BAD

-- Use explicit modules instead
local MyModule = require(path)
```

### Avoid loadstring
```lua
-- Deoptimizes and security risk
local fn = loadstring("return 42")()  -- BAD

-- Use structured data instead
local data = { value = 42 }
```

---

## Memory and GC

### Reduce Allocations in Hot Paths
```lua
-- Slow: Allocates table each call
local function getPosition(): { x: number, y: number }
    return { x = self.x, y = self.y }
end

-- Fast: Reuse or return components
local function getPosition(): (number, number)
    return self.x, self.y
end

-- Or use object pool
local pool: { { x: number, y: number } } = {}
local function getPosition(): { x: number, y: number }
    local p = table.remove(pool) or { x = 0, y = 0 }
    p.x, p.y = self.x, self.y
    return p
end
```

### Use Native Vectors
```lua
-- Fast: Native vector type (no GC overhead)
local pos = vector.create(1, 2, 3)
local moved = pos + vector.create(0, 1, 0)

-- Slower: Table-based vector (GC'd)
local pos = { x = 1, y = 2, z = 3 }
local moved = { x = pos.x, y = pos.y + 1, z = pos.z }
```

### Weak Tables for Caches
```lua
-- Cache with automatic cleanup
local cache: { [Instance]: any } = setmetatable({}, {
    __mode = "k"  -- weak keys
})

-- Mark as shrinkable for better memory
local cache = setmetatable({}, {
    __mode = "ks"  -- weak + shrinkable
})
```

---

## String Operations

### Use Format for Complex Strings
```lua
-- Fast
local msg = string.format("%s scored %d points", name, score)

-- Slower (multiple concatenations)
local msg = name .. " scored " .. tostring(score) .. " points"
```

### Use Interpolation for Simple Cases
```lua
-- Fast and readable
local msg = `{name} scored {score} points`
```

### Avoid String Building in Loops
```lua
-- Slow: O(n^2) string copies
local function bad(): string
    local result = ""
    for i = 1, 1000 do
        result = result .. tostring(i)
    end
    return result
end

-- Fast: O(n) with table.concat
local function good(): string
    local parts = table.create(1000)
    for i = 1, 1000 do
        parts[i] = tostring(i)
    end
    return table.concat(parts)
end
```

---

## Compiler Optimization Flags

### -O2 Aggressive Optimization
Enables:
- Function inlining for local functions
- Loop unrolling for known bounds
- Constant folding for builtins

```lua
-- With -O2, this may be fully optimized
local function square(n: number): number
    return n * n
end

local result = square(5)  -- may become: local result = 25
```

---

## Type-Related Performance

### Specific Types Over any
```lua
-- Fast: Type known, specialized code path
local function add(a: number, b: number): number
    return a + b
end

-- Slower: Type checks at runtime
local function add(a: any, b: any): any
    return a + b
end
```

### Avoid Excessive Type Casts
```lua
-- Unnecessary casts add overhead
local x = getValue() :: number :: number :: number  -- BAD

-- One cast is enough
local x = getValue() :: number
```

---

## Quick Reference

| Pattern | Fast | Slow |
|---------|------|------|
| Field access | `obj.field` | `obj["field"]` |
| Metatable | Direct `__index` | Function `__index` |
| Builtins | `local max = math.max` | `math.max` in loop |
| Table creation | `table.create(n)` | `{}` with growth |
| Table literal | All fields at once | Add fields after |
| Iteration | `for _, v in t` | `for i = 1, #t` |
| Closures | Module-scope | Created in loop |
| Vectors | `vector.create()` | `{ x, y, z }` |
| Strings | `string.format` / interpolation | Concatenation loop |

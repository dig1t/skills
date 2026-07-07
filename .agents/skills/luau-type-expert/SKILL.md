---
name: luau-type-expert
description: Use when adding or fixing Luau type annotations - luau-lsp/luau-analyze errors, --!strict compliance, "Type X could not be converted into Y", generics, union types, type narrowing/refinements, casts (::), typed metatables and OOP, .d.luau definitions, or .luaurc setup. Triggers include "type error", "strict mode", "luau-lsp", "type mismatch", "export type".
---

# Luau Type Expert

Expert guidance for writing type-safe, clean Luau code that passes strict type checking.

## Type Modes

Always use `--!strict` at file top. Three modes exist:

| Mode | Behavior |
|------|----------|
| `--!nocheck` | Disables type checking entirely |
| `--!nonstrict` | Unknown types become `any` (default) |
| `--!strict` | Full type tracking, catches mismatches |

## Syntax Essentials

Standard annotation syntax (variables, function params/returns, optionals `?`, multiple returns, variadics, table types, aliases) is covered in [references/api_reference.md](references/api_reference.md). The parts worth remembering:

```lua
-- Export for cross-module use
export type ItemRecord = { id: string, quantity: number }

-- Function type
type Callback = (player: Player, data: any) -> boolean

-- Generic aliases
type Result<T, E> = { ok: true, value: T } | { ok: false, error: E }
type Map<K, V> = { [K]: V }

-- Literal unions (discriminated)
type Status = "pending" | "active" | "completed"

-- Intersection: value has all these properties
type Person = Named & Aged

-- Function intersection (overloads)
type Stringify = ((n: number) -> string) & ((b: boolean) -> string)
```

## Type Narrowing (Refinements)

Luau narrows types in conditional blocks via `type()`, `typeof()` (Roblox instances), truthiness, and equality checks:

```lua
local function process(value: string | number)
    if type(value) == "string" then
        print(value:upper())  -- value: string here
    else
        print(value + 1)      -- value: number here
    end
end

local function safePrint(msg: string?)
    if msg then
        print(msg)  -- msg: string (not nil)
    end
end
```

**Early return preserves refinements:**

```lua
local function requirePlayer(player: Player?): Player
    if not player then
        error("Player required")
    end
    -- player: Player (narrowed after early return)
    return player
end
```

## Type Casts

Use `::` to override inferred types:

```lua
-- Cast to specific type
local data = {} :: { string }
table.insert(data, "hello")  -- OK
table.insert(data, 123)      -- Error: number not string

-- Cast result of expression
local id = tostring(123) :: string

-- Cast for API returns
local part = workspace:FindFirstChild("Part") :: Part?
```

**Cast rules:** One operand must be subtype of the other, or `any`.

## Generics

```lua
-- Generic function
local function first<T>(arr: { T }): T?
    return arr[1]
end

-- Generic with constraint
local function clone<T>(obj: T & {}): T
    local copy = {}
    for k, v in obj :: any do
        copy[k] = v
    end
    return copy :: T
end

-- Generic type alias
type Container<T> = {
    value: T,
    set: (self: Container<T>, value: T) -> (),
    get: (self: Container<T>) -> T,
}

-- Multiple type parameters
type Pair<K, V> = { key: K, value: V }
```

## Metatables and OOP

```lua
--!strict

export type Vector2 = {
    x: number,
    y: number,
}

type Vector2Impl = {
    __index: Vector2Impl,
    new: (x: number, y: number) -> Vector2,
    add: (self: Vector2, other: Vector2) -> Vector2,
    magnitude: (self: Vector2) -> number,
}

local Vector2: Vector2Impl = {} :: Vector2Impl
Vector2.__index = Vector2

function Vector2.new(x: number, y: number): Vector2
    return setmetatable({ x = x, y = y }, Vector2) :: Vector2
end

function Vector2:add(other: Vector2): Vector2
    return Vector2.new(self.x + other.x, self.y + other.y)
end

function Vector2:magnitude(): number
    return math.sqrt(self.x^2 + self.y^2)
end

return Vector2
```

## Common Type Errors and Fixes

See [references/common-errors.md](references/common-errors.md) for detailed error solutions.

**Quick fixes:**

| Error | Fix |
|-------|-----|
| `Type 'X' could not be converted into 'Y'` | Add explicit cast `:: Y` or fix the type |
| `Unknown global 'X'` | Import module or declare global type |
| `Property 'X' is not compatible` | Match property types exactly |
| `W_001: Unknown require` | Use proper require path aliases |

## luau-lsp CLI Usage

```bash
# Basic analysis
luau-lsp analyze src/

# With sourcemap for Roblox
luau-lsp analyze --sourcemap=sourcemap.json src/

# With definitions
luau-lsp analyze --definitions:@roblox=globalTypes.d.luau src/

# Disable all FFlags
luau-lsp analyze --no-flags-enabled src/
```

## .luaurc Configuration

```json
{
    "languageMode": "strict",
    "lint": {
        "LocalShadow": "disabled",
        "ImportUnused": "enabled"
    },
    "aliases": {
        "@shared": "src/Shared",
        "@server": "src/Server"
    }
}
```

## Performance-Aware Typing

See [references/performance.md](references/performance.md) for performance patterns.

**Key points:**
- Use `table.field` not `table["field"]`
- Keep metatables shallow (direct `__index` to table)
- Localize builtins: `local max = math.max`
- Avoid `getfenv`/`setfenv` (deoptimizes)
- Use `table.create(n)` for known sizes

## Lint Rules Reference

See [references/lint-rules.md](references/lint-rules.md) for all 28 lint rules.

**Critical rules:**
- `UnknownGlobal` - Catches typos
- `LocalUnused` - Dead code
- `ImplicitReturn` - Inconsistent returns
- `UninitializedLocal` - Use before assign

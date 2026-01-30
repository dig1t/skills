# Common Type Errors and Fixes

## Table of Contents
- [Type Conversion Errors](#type-conversion-errors)
- [Property Errors](#property-errors)
- [Function Errors](#function-errors)
- [Generic Errors](#generic-errors)
- [Module/Require Errors](#modulerequire-errors)
- [Metatable Errors](#metatable-errors)

---

## Type Conversion Errors

### "Type 'X' could not be converted into 'Y'"

**Cause:** Assigning incompatible types.

```lua
-- Error
local x: number = "hello"  -- string -> number

-- Fix: Use correct type
local x: number = 42

-- Or fix: Change annotation
local x: string = "hello"
```

### "Type 'nil' could not be converted into 'X'"

**Cause:** Assigning potentially nil value to non-optional type.

```lua
-- Error
local function getName(): string
    return nil  -- nil -> string
end

-- Fix: Return type should be optional
local function getName(): string?
    return nil
end

-- Or fix: Return actual value
local function getName(): string
    return "default"
end
```

### "Type 'X | nil' could not be converted into 'X'"

**Cause:** Using optional value where non-optional expected.

```lua
-- Error
local function process(data: string?)
    local upper: string = data:upper()  -- data might be nil
end

-- Fix: Use type guard
local function process(data: string?)
    if data then
        local upper: string = data:upper()  -- data is now string
    end
end

-- Or fix: Use assert
local function process(data: string?)
    assert(data, "data required")
    local upper: string = data:upper()
end
```

### "Type 'any' has no keys"

**Cause:** Accessing properties on `any` type without narrowing.

```lua
-- Error
local data: any = getData()
print(data.name)  -- any has no keys

-- Fix: Cast to specific type
local data = getData() :: { name: string }
print(data.name)

-- Or fix: Use type guard
local data: any = getData()
if type(data) == "table" and data.name then
    print(data.name)
end
```

---

## Property Errors

### "Property 'X' is not compatible"

**Cause:** Table property types don't match.

```lua
type Expected = { count: number }
type Actual = { count: string }

-- Error
local a: Actual = { count = "5" }
local b: Expected = a  -- count types differ

-- Fix: Use correct property type
local b: Expected = { count = 5 }
```

### "Key 'X' is missing from table type"

**Cause:** Table literal missing required field.

```lua
type Player = {
    name: string,
    score: number,
}

-- Error
local p: Player = { name = "Bob" }  -- missing score

-- Fix: Include all required fields
local p: Player = { name = "Bob", score = 0 }

-- Or fix: Make field optional
type Player = {
    name: string,
    score: number?,
}
```

### "Table type 'X' not compatible with type 'Y'"

**Cause:** Extra keys or structural mismatch.

```lua
type Point = { x: number, y: number }

-- In strict mode, extra keys may cause issues
local p: Point = { x = 1, y = 2, z = 3 }  -- z is extra

-- Fix: Match structure exactly
local p: Point = { x = 1, y = 2 }
```

---

## Function Errors

### "Argument count mismatch"

**Cause:** Wrong number of arguments.

```lua
local function add(a: number, b: number): number
    return a + b
end

-- Error
add(1)  -- missing second argument

-- Fix: Provide all arguments
add(1, 2)

-- Or fix: Make parameter optional
local function add(a: number, b: number?): number
    return a + (b or 0)
end
```

### "Type 'X' is not callable"

**Cause:** Calling non-function value.

```lua
local data = { value = 42 }

-- Error
data()  -- table is not callable

-- Fix: Call actual function
local fn = function() return 42 end
fn()

-- Or fix: Add __call metamethod (if intentional)
setmetatable(data, {
    __call = function() return 42 end
})
```

### "Return type 'X' is not compatible with 'Y'"

**Cause:** Function returns wrong type.

```lua
-- Error
local function getNumber(): number
    return "42"  -- returns string, not number
end

-- Fix: Return correct type
local function getNumber(): number
    return 42
end

-- Or fix: Correct return annotation
local function getNumber(): string
    return "42"
end
```

---

## Generic Errors

### "Unknown type parameter"

**Cause:** Using undefined generic parameter.

```lua
-- Error
local function first(arr: { T }): T?
    return arr[1]
end

-- Fix: Declare generic parameter
local function first<T>(arr: { T }): T?
    return arr[1]
end
```

### "Generic type arity mismatch"

**Cause:** Wrong number of type arguments.

```lua
type Pair<K, V> = { key: K, value: V }

-- Error
local p: Pair<string> = { key = "a", value = 1 }  -- missing V

-- Fix: Provide all type arguments
local p: Pair<string, number> = { key = "a", value = 1 }
```

### "Cannot infer type parameter"

**Cause:** Luau can't determine generic type.

```lua
local function create<T>(): { T }
    return {}  -- T unknown
end

-- Error
local arr = create()  -- what is T?

-- Fix: Provide type argument
local arr = create<string>()

-- Or fix: Use cast
local arr = {} :: { string }
```

---

## Module/Require Errors

### "W_001: Unknown require"

**Cause:** luau-lsp can't resolve require path.

```lua
-- Error
local Module = require(script.Parent.Module)  -- path not found

-- Fix: Ensure path exists in sourcemap
-- Fix: Use proper aliases in .luaurc
local Module = require("@shared/Module")

-- Fix: Generate sourcemap
-- rojo sourcemap default.project.json -o sourcemap.json
```

### "Module 'X' has no type information"

**Cause:** Required module not type-checked.

```lua
-- If Module.luau has no types
local Module = require(Module)
Module.foo()  -- foo is any

-- Fix: Add types to Module.luau
--!strict
local Module = {}

function Module.foo(): string
    return "bar"
end

return Module
```

### "Cyclic module dependency"

**Cause:** Modules require each other.

```lua
-- A.luau requires B.luau
-- B.luau requires A.luau

-- Fix: Break cycle with dependency injection
-- A.luau
local A = {}
function A.init(B)
    A.B = B
end
return A

-- B.luau
local B = {}
function B.init(A)
    B.A = A
end
return B

-- Entry.luau
local A = require(A)
local B = require(B)
A.init(B)
B.init(A)
```

---

## Metatable Errors

### "Cannot use operator on types"

**Cause:** Using operator without metamethod.

```lua
type Vector = { x: number, y: number }

local a: Vector = { x = 1, y = 2 }
local b: Vector = { x = 3, y = 4 }

-- Error
local c = a + b  -- no __add metamethod

-- Fix: Define metamethod in type or cast
local Vector = {}
Vector.__index = Vector
Vector.__add = function(a, b)
    return { x = a.x + b.x, y = a.y + b.y }
end
```

### "setmetatable return type"

**Cause:** setmetatable loses type info.

```lua
type Point = { x: number, y: number }

-- Error: result is { x: number, y: number }, not Point
local p = setmetatable({ x = 0, y = 0 }, PointMT)

-- Fix: Cast result
local p = setmetatable({ x = 0, y = 0 }, PointMT) :: Point

-- Better fix: Use constructor pattern
function Point.new(x: number, y: number): Point
    return setmetatable({ x = x, y = y }, PointMT) :: Point
end
```

### "self parameter type"

**Cause:** Method `self` has wrong type.

```lua
type Obj = { value: number }

-- Error: self is any
function Obj:getValue()
    return self.value
end

-- Fix: Explicit self type
function Obj.getValue(self: Obj): number
    return self.value
end

-- Or: Use type in impl table
type ObjImpl = {
    getValue: (self: Obj) -> number,
}
```

---

## Quick Reference: Error -> Fix

| Error Message | Quick Fix |
|---------------|-----------|
| `could not be converted` | Check types match, add cast `:: Type` |
| `nil could not be converted` | Add `?` to make optional, or guard |
| `has no keys` | Cast `any` to specific type |
| `Property not compatible` | Match property types exactly |
| `Key missing` | Add missing field or make optional |
| `Argument count mismatch` | Fix args or make params optional |
| `is not callable` | Ensure value is function |
| `Unknown type parameter` | Add `<T>` to function signature |
| `Unknown require` | Fix path, check sourcemap, use aliases |
| `Cyclic module dependency` | Use dependency injection pattern |

# Luau Lint Rules Reference

All 28 built-in lint rules with descriptions and examples.

## Configuration

**Disable per-file:**
```lua
--!nolint LocalUnused
--!nolint  -- disables all linting
```

**Configure in .luaurc:**
```json
{
    "lint": {
        "LocalUnused": "disabled",
        "LocalShadow": "disabled",
        "ImportUnused": "enabled"
    }
}
```

---

## Rule Reference

### 1. UnknownGlobal
Detects use of undefined global variables (likely typos).

```lua
-- Warning
pritn("hello")  -- typo: should be print

-- Fix
print("hello")
```

### 2. DeprecatedGlobal
Flags deprecated global names.

```lua
-- Warning
local n = table.getn(t)  -- deprecated

-- Fix
local n = #t
```

### 3. GlobalUsedAsLocal
Identifies globals only used in one function (should be local).

```lua
-- Warning
function foo()
    counter = 0  -- only used here
    counter = counter + 1
end

-- Fix
function foo()
    local counter = 0
    counter = counter + 1
end
```

### 4. LocalShadow
Warns when local variable shadows another local or global.

```lua
-- Warning
local x = 1
if true then
    local x = 2  -- shadows outer x
end

-- Fix
local x = 1
if true then
    local y = 2  -- different name
end
```

### 5. SameLineStatement
Discourages multiple statements on one line.

```lua
-- Warning
local x = 1 local y = 2

-- Fix
local x = 1
local y = 2
```

### 6. MultiLineStatement
Flags improperly formatted multi-line statements.

```lua
-- Warning (hard to read)
local result = foo()
    + bar()

-- Fix
local result = foo()
    + bar()  -- proper continuation
```

### 7. LocalUnused
Reports unused local variables.

```lua
-- Warning
local unused = 42  -- never used

-- Fix: Remove or use
local used = 42
print(used)

-- Suppress with underscore prefix
local _intentionallyUnused = 42
```

### 8. FunctionUnused
Highlights unused local functions.

```lua
-- Warning
local function helper()
    return 1
end
-- helper never called

-- Fix: Remove or call it
local function helper()
    return 1
end
print(helper())
```

### 9. ImportUnused
Identifies unused require statements.

```lua
-- Warning
local HttpService = game:GetService("HttpService")  -- never used

-- Fix: Remove unused import
-- or use it
HttpService:JSONEncode({})
```

### 10. BuiltinGlobalWrite
Prevents reassigning standard library tables.

```lua
-- Warning
math = {}  -- overwrites math library

-- Fix: Use different name
local myMath = {}
```

### 11. PlaceholderRead
Detects reading from `_` placeholder (should only be written).

```lua
-- Warning
for _, v in pairs(t) do
    print(_)  -- reading placeholder
end

-- Fix
for k, v in pairs(t) do
    print(k)
end
```

### 12. UnreachableCode
Identifies code that can never execute.

```lua
-- Warning
function foo()
    return 1
    print("never runs")  -- unreachable
end

-- Fix
function foo()
    print("runs")
    return 1
end
```

### 13. UnknownType
Validates type name strings in comparisons.

```lua
-- Warning
if type(x) == "integer" then  -- invalid type name

-- Fix
if type(x) == "number" then  -- valid type name
```

### 14. ForRange
Catches numeric loop errors.

```lua
-- Warning: zero iterations
for i = 10, 1 do  -- wrong direction

-- Fix
for i = 10, 1, -1 do  -- correct step

-- Warning: infinite loop
for i = 1, 10, 0 do  -- step is 0

-- Fix
for i = 1, 10, 1 do
```

### 15. UnbalancedAssignment
Warns about mismatched variable/value counts.

```lua
-- Warning: too few values
local a, b, c = 1, 2  -- c is nil

-- Fix: match counts
local a, b, c = 1, 2, 3

-- Or be explicit
local a, b = 1, 2
local c = nil
```

### 16. ImplicitReturn
Flags inconsistent return patterns.

```lua
-- Warning
local function foo(x)
    if x > 0 then
        return x
    end
    -- implicit nil return
end

-- Fix: explicit returns
local function foo(x)
    if x > 0 then
        return x
    end
    return nil
end
```

### 17. DuplicateLocal
Detects duplicate names in declarations.

```lua
-- Warning
local function foo(a, a)  -- duplicate param

-- Fix
local function foo(a, b)
```

### 18. FormatString
Validates format strings for library functions.

```lua
-- Warning
string.format("%d", "hello")  -- wrong type for %d

-- Fix
string.format("%s", "hello")
string.format("%d", 42)
```

### 19. TableLiteral
Reports duplicate keys in table constructors.

```lua
-- Warning
local t = {
    x = 1,
    x = 2,  -- duplicate key
}

-- Fix
local t = {
    x = 1,
    y = 2,
}
```

### 20. UninitializedLocal
Warns about using variables before assignment.

```lua
-- Warning
local x
print(x + 1)  -- x is nil

-- Fix
local x = 0
print(x + 1)
```

### 21. DuplicateFunction
Flags multiple functions with same name.

```lua
-- Warning
local function helper() return 1 end
local function helper() return 2 end  -- duplicate

-- Fix
local function helper1() return 1 end
local function helper2() return 2 end
```

### 22. DeprecatedApi
Warns against deprecated methods/fields.

```lua
-- Warning (Roblox-specific)
workspace:FindFirstChild("Part", true)  -- recursive param deprecated

-- Fix
workspace:FindFirstChild("Part")
```

### 23. TableOperations
Ensures correct table library usage.

```lua
-- Warning
table.insert(t, 1, 2, 3)  -- wrong arg count

-- Fix
table.insert(t, 1)  -- append
table.insert(t, 1, 2)  -- insert at position
```

### 24. DuplicateCondition
Detects redundant conditions in if/elseif.

```lua
-- Warning
if x > 0 then
    print("a")
elseif x > 0 then  -- same condition
    print("b")
end

-- Fix
if x > 0 then
    print("a")
elseif x < 0 then
    print("b")
end
```

### 25. MisleadingAndOr
Catches unsafe ternary-like patterns.

```lua
-- Warning: returns 0 when cond is true but val is falsy
local result = cond and val or default

-- If val can be false/nil, this is wrong
local result = cond and false or true  -- always true!

-- Fix: use if expression
local result = if cond then val else default
```

### 26. CommentDirective
Reports unrecognized comment directives.

```lua
-- Warning
--!nostrict  -- typo

-- Fix
--!nonstrict
```

### 27. IntegerParsing
Flags numeric literals that lose precision.

```lua
-- Warning
local big = 9007199254740993  -- loses precision in double

-- Fix: use string or stay in safe range
local big = "9007199254740993"
```

### 28. ComparisonPrecedence
Catches operator precedence mistakes.

```lua
-- Warning: might not mean what you think
if a < b == c then  -- (a < b) == c, not a < (b == c)

-- Fix: use parentheses
if (a < b) == c then
if a < b and b == c then
```

---

## Quick Reference Table

| # | Rule | Severity | Description |
|---|------|----------|-------------|
| 1 | UnknownGlobal | Error | Undefined global (typo) |
| 2 | DeprecatedGlobal | Warning | Deprecated global name |
| 3 | GlobalUsedAsLocal | Warning | Global should be local |
| 4 | LocalShadow | Warning | Variable shadows another |
| 5 | SameLineStatement | Style | Multiple statements per line |
| 6 | MultiLineStatement | Style | Bad multi-line formatting |
| 7 | LocalUnused | Warning | Unused local variable |
| 8 | FunctionUnused | Warning | Unused local function |
| 9 | ImportUnused | Warning | Unused require |
| 10 | BuiltinGlobalWrite | Error | Overwriting stdlib |
| 11 | PlaceholderRead | Warning | Reading from `_` |
| 12 | UnreachableCode | Warning | Dead code |
| 13 | UnknownType | Error | Invalid type name |
| 14 | ForRange | Error | Bad loop bounds |
| 15 | UnbalancedAssignment | Warning | Mismatched assignment |
| 16 | ImplicitReturn | Warning | Missing return |
| 17 | DuplicateLocal | Error | Duplicate names |
| 18 | FormatString | Error | Bad format string |
| 19 | TableLiteral | Error | Duplicate table keys |
| 20 | UninitializedLocal | Warning | Use before assign |
| 21 | DuplicateFunction | Warning | Duplicate function names |
| 22 | DeprecatedApi | Warning | Deprecated API use |
| 23 | TableOperations | Error | Wrong table.* usage |
| 24 | DuplicateCondition | Warning | Redundant condition |
| 25 | MisleadingAndOr | Warning | Unsafe and/or pattern |
| 26 | CommentDirective | Error | Bad directive |
| 27 | IntegerParsing | Warning | Precision loss |
| 28 | ComparisonPrecedence | Warning | Precedence confusion |

# Luau Standard Library Type Signatures

Quick reference for built-in function types.

## Global Functions

```lua
type(obj: any): string  -- "nil", "boolean", "number", "string", "table", "function", "userdata", "thread", "buffer", "vector"
typeof(obj: any): string  -- Enhanced for Roblox userdata
tonumber(s: string, base: number?): number?
tostring(obj: any): string
assert<T>(value: T, message: string?): T
error(obj: any, level: number?): never
pcall<A..., R...>(f: (A...) -> R..., A...): (boolean, R...)
xpcall<A..., R...>(f: (A...) -> R..., e: (any) -> any, A...): (boolean, R...)
select<T...>(index: number | "#", T...): T... | number
pairs<K, V>(t: { [K]: V }): ((table, K?) -> (K, V), { [K]: V }, nil)
ipairs<V>(t: { V }): ((table, number) -> (number, V), { V }, number)
next<K, V>(t: { [K]: V }, k: K?): (K?, V)
rawget<K, V>(t: { [K]: V }, k: K): V?
rawset<K, V>(t: { [K]: V }, k: K, v: V): { [K]: V }
rawequal(a: any, b: any): boolean
rawlen(t: { any } | string): number
getmetatable<T>(t: T): { [any]: any }?
setmetatable<T>(t: T, mt: { [any]: any }?): T
unpack<V>(t: { V }, i: number?, j: number?): ...V
```

## math

```lua
math.abs(n: number): number
math.ceil(n: number): number
math.floor(n: number): number
math.round(n: number): number
math.sign(n: number): number  -- -1, 0, or 1
math.clamp(n: number, min: number, max: number): number
math.min(...: number): number
math.max(...: number): number
math.sqrt(n: number): number
math.pow(x: number, y: number): number
math.exp(n: number): number
math.log(n: number, base: number?): number
math.log10(n: number): number
math.sin(n: number): number
math.cos(n: number): number
math.tan(n: number): number
math.asin(n: number): number
math.acos(n: number): number
math.atan(n: number): number
math.atan2(y: number, x: number): number
math.deg(radians: number): number
math.rad(degrees: number): number
math.random(): number  -- [0, 1)
math.random(n: number): number  -- [1, n]
math.random(m: number, n: number): number  -- [m, n]
math.randomseed(seed: number): ()
math.noise(x: number, y: number?, z: number?): number  -- Perlin noise [-1, 1]
math.lerp(a: number, b: number, t: number): number
math.fmod(x: number, y: number): number
math.modf(n: number): (number, number)  -- integer, fractional
math.frexp(n: number): (number, number)  -- significand, exponent
math.ldexp(m: number, e: number): number
math.huge: number  -- infinity
math.pi: number
```

## table

```lua
table.insert<V>(t: { V }, v: V): ()
table.insert<V>(t: { V }, pos: number, v: V): ()
table.remove<V>(t: { V }, pos: number?): V?
table.sort<V>(t: { V }, comp: ((V, V) -> boolean)?): ()
table.concat(t: { string }, sep: string?, i: number?, j: number?): string
table.find<V>(t: { V }, value: V, init: number?): number?
table.clear(t: { [any]: any }): ()
table.clone<T>(t: T): T  -- shallow copy
table.freeze<T>(t: T): T  -- make immutable
table.isfrozen(t: { [any]: any }): boolean
table.create<V>(count: number, value: V?): { V }
table.move<V>(src: { V }, a: number, b: number, t: number, dst: { V }?): { V }
table.pack<V>(...: V): { n: number, [number]: V }
table.unpack<V>(t: { V }, i: number?, j: number?): ...V
table.maxn(t: { [number]: any }): number
table.getn<V>(t: { V }): number  -- deprecated, use #t
```

## string

```lua
string.len(s: string): number
string.byte(s: string, i: number?, j: number?): ...number
string.char(...: number): string
string.sub(s: string, i: number, j: number?): string
string.upper(s: string): string
string.lower(s: string): string
string.reverse(s: string): string
string.rep(s: string, n: number): string
string.find(s: string, pattern: string, init: number?, plain: boolean?): (number?, number?, ...string)
string.match(s: string, pattern: string, init: number?): ...string?
string.gmatch(s: string, pattern: string): () -> ...string
string.gsub(s: string, pattern: string, repl: string | { [string]: string } | ((...string) -> string), n: number?): (string, number)
string.format(fmt: string, ...: any): string
string.split(s: string, sep: string?): { string }
string.pack(fmt: string, ...: any): string
string.unpack(fmt: string, s: string, pos: number?): (...any, number)
string.packsize(fmt: string): number
```

## coroutine

```lua
coroutine.create(f: (...any) -> ...any): thread
coroutine.wrap<A..., R...>(f: (A...) -> R...): (A...) -> R...
coroutine.resume(co: thread, ...: any): (boolean, ...any)
coroutine.yield(...: any): ...any
coroutine.status(co: thread): "running" | "suspended" | "normal" | "dead"
coroutine.running(): thread?
coroutine.isyieldable(): boolean
coroutine.close(co: thread): (boolean, any?)
```

## bit32

All operate on 32-bit unsigned integers [0, 2^32-1].

```lua
bit32.band(...: number): number
bit32.bor(...: number): number
bit32.bxor(...: number): number
bit32.bnot(n: number): number
bit32.btest(...: number): boolean
bit32.lshift(n: number, disp: number): number
bit32.rshift(n: number, disp: number): number
bit32.arshift(n: number, disp: number): number  -- arithmetic (preserves sign)
bit32.lrotate(n: number, disp: number): number
bit32.rrotate(n: number, disp: number): number
bit32.extract(n: number, field: number, width: number?): number
bit32.replace(n: number, v: number, field: number, width: number?): number
bit32.countlz(n: number): number  -- leading zeros
bit32.countrz(n: number): number  -- trailing zeros
bit32.byteswap(n: number): number
```

## buffer

```lua
buffer.create(size: number): buffer
buffer.fromstring(s: string): buffer
buffer.tostring(b: buffer): string
buffer.len(b: buffer): number
buffer.readi8(b: buffer, offset: number): number
buffer.readu8(b: buffer, offset: number): number
buffer.readi16(b: buffer, offset: number): number
buffer.readu16(b: buffer, offset: number): number
buffer.readi32(b: buffer, offset: number): number
buffer.readu32(b: buffer, offset: number): number
buffer.readf32(b: buffer, offset: number): number
buffer.readf64(b: buffer, offset: number): number
buffer.writei8(b: buffer, offset: number, value: number): ()
buffer.writeu8(b: buffer, offset: number, value: number): ()
buffer.writei16(b: buffer, offset: number, value: number): ()
buffer.writeu16(b: buffer, offset: number, value: number): ()
buffer.writei32(b: buffer, offset: number, value: number): ()
buffer.writeu32(b: buffer, offset: number, value: number): ()
buffer.writef32(b: buffer, offset: number, value: number): ()
buffer.writef64(b: buffer, offset: number, value: number): ()
buffer.readstring(b: buffer, offset: number, count: number): string
buffer.writestring(b: buffer, offset: number, value: string, count: number?): ()
buffer.copy(dst: buffer, dstOffset: number, src: buffer, srcOffset: number?, count: number?): ()
buffer.fill(b: buffer, offset: number, value: number, count: number?): ()
```

## vector

Native 3-component (or 4-component) 32-bit float vector.

```lua
vector.create(x: number, y: number, z: number): vector
vector.create(x: number, y: number, z: number, w: number): vector  -- 4-wide mode
vector.magnitude(v: vector): number
vector.normalize(v: vector): vector
vector.dot(a: vector, b: vector): number
vector.cross(a: vector, b: vector): vector
vector.angle(a: vector, b: vector, axis: vector?): number
vector.floor(v: vector): vector
vector.ceil(v: vector): vector
vector.abs(v: vector): vector
vector.sign(v: vector): vector
vector.clamp(v: vector, min: vector, max: vector): vector
vector.max(...: vector): vector
vector.min(...: vector): vector
vector.zero: vector
vector.one: vector
```

## utf8

```lua
utf8.len(s: string, i: number?, j: number?): number?
utf8.offset(s: string, n: number, i: number?): number?
utf8.codepoint(s: string, i: number?, j: number?): ...number
utf8.char(...: number): string
utf8.codes(s: string): () -> (number, number)  -- position, codepoint
utf8.charpattern: string
```

## os

```lua
os.clock(): number  -- high-precision CPU time
os.time(t: { year: number, month: number, day: number, hour: number?, min: number?, sec: number? }?): number
os.date(format: string?, time: number?): string | { year: number, month: number, day: number, hour: number, min: number, sec: number, wday: number, yday: number, isdst: boolean }
os.difftime(t2: number, t1: number): number
```

## debug

```lua
debug.traceback(thread: thread?, message: string?, level: number?): string
debug.info<R...>(thread: thread, level: number, options: string): R...
debug.info<R...>(level: number, options: string): R...
debug.info<R...>(func: (...any) -> ...any, options: string): R...
-- options: s=source, l=line, n=name, f=function, a=arity+variadic
```

---
name: roblox-dev
description: |
  Roblox game development assistant for Luau code. Use this skill when:
  - Writing or reviewing Luau/Lua code for Roblox games
  - Creating services, controllers, or UI components
  - Setting up data persistence with ProfileDB/Replica
  - Implementing client-server communication
  - Debugging Roblox-specific issues
  - Working with Wally packages or Rojo projects
  - Implementing game features like shops, inventories, or combat
  This skill has access to production code examples and best practices.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# Roblox Development Assistant

You are an expert Roblox game developer with deep knowledge of Luau, the Rojo workflow, and modern Roblox architecture patterns.

## Quick Reference

- The current project's root `CLAUDE.md` - Project instructions and standards
- [patterns.md](patterns.md) - Common implementation patterns
- [libraries.md](libraries.md) - Wally package API reference
- [examples.md](examples.md) - Real code examples
- [troubleshooting.md](troubleshooting.md) - Common issues and fixes

**Related skills:**

- `/roblox-testing:test` and `/roblox-testing:playtest` (plugin commands, not a skill) — TestEZ, mocking, integration tests, CI via Lune
- `roblox-performance` — StreamingEnabled, object pooling, MicroProfiler, FPS diagnosis

## Core Principles

### 1. Type Safety (Mandatory)

Strict mode is enabled repo-wide via `.luaurc`. Do not add per-file `--!strict` directives.

```lua
local function calculateDamage(baseDamage: number, multiplier: number): number
    return baseDamage * multiplier
end

export type PlayerData = {
    coins: number,
    level: number,
    inventory: { ItemRecord },
}
```

### 2. Server Authority
Never trust the client. All game logic, validation, and persistence runs server-side.

```lua
-- Server validates everything
red.bind("COLLECT_COIN", function(player: Player, payload: { coinId: string })
    -- 1. Validate player exists
    if not player or not player.Parent then return end

    -- 2. Validate payload structure
    if typeof(payload.coinId) ~= "string" then return end

    -- 3. Validate game state (server determines value)
    local coinValue = getCoinValue(payload.coinId)
    if not canCollectCoin(player, payload.coinId) then return end

    -- 4. Process on server
    ProfileService.add(player, { ["stats.coins"] = coinValue })
end)
```

### 3. Bootstrap Lifecycle
Services and Controllers follow init() -> start() lifecycle:

```lua
local MyService = {}

function MyService.init()
    -- Initialize dependencies
    -- DO NOT access other services yet
end

function MyService.start()
    -- Start logic
    -- All services are now initialized
end

return MyService
```

### 4. Data Flow Pattern
```
[DataStore/ProfileDB] -> [ProfileService] -> [Replica] -> [DataController] -> [ClientState] -> [UI]
```

All data modifications go through ProfileService methods.

## Project Structure

```
src/
├── Server/
│   ├── Entry.server.luau
│   ├── Features/
│   │   ├── Core/
│   │   │   ├── PlayerService.luau
│   │   │   └── ProfileService.luau
│   │   └── [Feature]/
│   │       ├── [Feature]Service.luau
│   │       └── Handlers/Handler.luau
│   ├── Util/
│   └── Data/
├── Client/
│   ├── Entry.client.luau
│   ├── Features/
│   │   └── Core/
│   │       ├── Controllers/DataController.luau
│   │       ├── Routes/
│   │       └── Components/
│   └── ClientState.luau
└── Shared/
    ├── Class/Bootstrap.luau
    ├── Types/ProfileTypes.luau
    ├── Data/DataTemplate.luau
    └── Config/
```

## Common Tasks

### Creating a New Service
1. Create `src/Server/Features/[Feature]/[Name]Service.luau`
2. Include init() and start() functions
3. Bootstrap auto-discovers files ending in `Service.luau`

### Creating a New Controller
1. Create `src/Client/Features/[Feature]/Controllers/[Name]Controller.luau`
2. Include init() and start() functions
3. Bootstrap auto-discovers files ending in `Controller.luau`

### Adding Player Data Fields
1. Update `DataTemplate.luau` with new field and default value
2. Update `ProfileTypes.luau` with new type
3. ProfileDB reconciliation handles existing players

### Client-Server Communication
```lua
-- Client dispatches action
red.dispatch({
    type = "ACTION_NAME",
    payload = { data = "value" }
})

-- Server binds handler
red.bind("ACTION_NAME", function(player, payload)
    -- Validate and process
end)
```

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Services | PascalCase + Service | `PlayerService`, `ShopService` |
| Controllers | PascalCase + Controller | `DataController`, `UIController` |
| Types | PascalCase | `ProfileData`, `ItemRecord` |
| Functions | camelCase | `calculateDamage`, `onPlayerAdded` |
| Variables | camelCase | `playerData`, `isReady` |
| Constants | UPPER_SNAKE_CASE | `MAX_PLAYERS`, `RESPAWN_TIME` |
| Event handlers | on + Event | `onPlayerAdded`, `onCoinCollected` |
| Booleans | is/has/can/did | `isReady`, `hasProfile`, `canPurchase` |

## Import Order

```lua
-- 1. Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 2. Packages
local Promise = require(ReplicatedStorage.Packages.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)

-- 3. Shared modules
local Types = require(ReplicatedStorage.Shared.Types)
local Util = require(ReplicatedStorage.Packages.Util)

-- 4. Local modules
local ProfileService = require("./ProfileService")
```

## Tooling Commands

```bash
# Install tools (see aftman.toml for CLI tool versions)
aftman install

# Install packages (see wally.toml for dependency list)
wally install

# Generate sourcemap and types
rojo sourcemap default.project.json -o sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages

# Start dev server
rojo serve

# Lint and format
stylua src/
selene src/
luau-lsp analyze --sourcemap=sourcemap.json src/
```

## Security Rules

**NEVER:**
- Trust client input without server validation
- Store secrets on the client (API keys, admin lists)
- Use client-provided Player instances
- Replicate sensitive data to clients

**ALWAYS:**
- Validate all remote payloads server-side
- Use server as source of truth
- Rate-limit client requests
- Check permissions before actions

## Code Generation Guidelines

When generating Roblox code:

1. **Type all public APIs** - Strict mode is enabled repo-wide via `.luaurc`; do not add per-file `--!strict`. Annotate function parameters and returns.
2. **Follow bootstrap pattern** - Services have init/start lifecycle
3. **Use feature-based organization** - Group related code together
4. **Validate on server** - Never trust client data
5. **Clean up resources** - Use Maid pattern for connections/instances
6. **Prefer events over polling** - Use Signals, not while loops
7. **Early returns** - Validate and return early to avoid nesting
8. **Named constants** - No magic numbers or strings

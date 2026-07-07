---
name: rojo-pro
description: Use when setting up or troubleshooting Rojo for Roblox - project.json configuration, Studio sync issues, file naming conventions (init.luau, *.server.luau), rojo serve/build/sourcemap commands, multi-environment setups (dev/staging/prod), or Wally/Aftman integration. Triggers include "rojo", "project.json", "sync", "sourcemap".
---

# Rojo Professional

Rojo bridges the filesystem and Roblox Studio: write code in external editors, live-sync to Studio via the plugin, build `.rbxl`/`.rbxm` files for deployment, and keep everything in Git.

## Quick Reference

### Essential Commands

```bash
# Initialize new project
rojo init my-game

# Start dev server (connects to Studio plugin)
rojo serve

# Serve specific project file
rojo serve dev.project.json

# Build standalone file
rojo build -o game.rbxl
rojo build deploy.project.json -o game.rbxl

# Generate sourcemap (for luau-lsp type checking)
rojo sourcemap default.project.json -o sourcemap.json

# Install Studio plugin
rojo plugin install
```

### File Naming Conventions

| File Pattern | Roblox Instance |
|--------------|-----------------|
| `*.server.luau` | Script (runs on server) |
| `*.client.luau` | LocalScript (runs on client) |
| `*.luau` or `*.lua` | ModuleScript |
| `init.server.luau` | Directory becomes Script |
| `init.client.luau` | Directory becomes LocalScript |
| `init.luau` | Directory becomes ModuleScript |
| `*.model.json` | Custom model definition |
| `*.meta.json` | Metadata for sibling file/folder |
| `*.rbxm` / `*.rbxmx` | Binary/XML model files |
| `*.txt` | StringValue |
| `*.csv` | LocalizationTable |

### Project File Structure

```json
{
  "name": "MyGame",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Shared": { "$path": "src/Shared" },
      "Packages": { "$path": "Packages" }
    },
    "ServerScriptService": {
      "$className": "ServerScriptService",
      "Server": { "$path": "src/Server" }
    },
    "ReplicatedFirst": {
      "$className": "ReplicatedFirst",
      "Client": { "$path": "src/Client" }
    },
    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "$path": "src/StarterPlayerScripts"
      }
    }
  }
}
```

### Tree Node Properties

- `$className` - Roblox class (required for services, optional with `$path`)
- `$path` - Filesystem path to sync
- `$properties` - Instance properties
- `$ignoreUnknownInstances` - Don't delete untracked instances (useful for terrain)
- Any other key - Child instance name

### Optional Project Settings

```json
{
  "servePort": 34872,
  "servePlaceIds": [123456789],
  "placeId": 123456789,
  "gameId": 987654321,
  "globIgnorePaths": ["**/*.spec.luau", "**/test/**"],
  "emitLegacyScripts": true
}
```

Project setup and multi-environment patterns: [references/patterns.md](references/patterns.md). Sync troubleshooting: [references/sharp_edges.md](references/sharp_edges.md).

## Common Patterns

### Multi-Project Setup (Dev/Prod)

```
project/
├── default.project.json    # Development (rojo serve)
├── deploy.project.json     # Production build
├── src/
├── Packages/
└── ...
```

### Library/Package Distribution

Minimal config for distributing a standalone module:
```json
{
  "name": "my-library",
  "tree": {
    "$path": "src"
  }
}
```

### Setting Instance Properties

```json
{
  "$className": "Part",
  "$properties": {
    "Anchored": true,
    "Size": [4, 1, 2],
    "Color": [1, 0, 0],
    "BrickColor": { "BrickColor": "Bright red" },
    "Material": { "Enum": "Material.Neon" }
  }
}
```

### Preserving Studio-Created Instances

```json
{
  "Workspace": {
    "$className": "Workspace",
    "$ignoreUnknownInstances": true,
    "GameContent": { "$path": "src/Workspace" }
  }
}
```

## Integration with Toolchain

### Aftman (Tool Management)

```toml
# aftman.toml
[tools]
rojo = "rojo-rbx/rojo@7.6.1"
wally = "UpliftGames/wally@0.3.2"
stylua = "JohnnyMorganz/StyLua@2.0.0"
selene = "Kampfkarren/selene@0.27.0"
luau-lsp = "JohnnyMorganz/luau-lsp@1.30.0"
```

### Wally (Package Management)

```toml
# wally.toml
[package]
name = "author/my-game"
version = "1.0.0"
realm = "shared"
registry = "https://github.com/UpliftGames/wally-index"

[dependencies]
Promise = "evaera/promise@4.0.0"
Signal = "sleitnick/signal@2.0.0"
```

Packages install to `Packages/` and must be mapped in project file.

### Type Checking Setup

```bash
# Generate sourcemap for luau-lsp
rojo sourcemap default.project.json -o sourcemap.json

# Generate Wally package types
wally-package-types --sourcemap sourcemap.json Packages
```

## After Cloning a Repo

If `Packages/` is missing or you see "path does not exist" errors:

```bash
wally install                                           # Install packages from wally.toml
rojo sourcemap default.project.json -o sourcemap.json   # Regenerate sourcemap
```

`Packages/` is gitignored - it must be regenerated after every clone.

## Anti-Patterns

**DON'T:**
- Edit files in Studio while Rojo is connected (changes will be overwritten)
- Use spaces in file/folder names (use PascalCase or snake_case)
- Forget `$className` for Roblox services
- Mix `.lua` and `.luau` extensions inconsistently
- Put server code in ReplicatedStorage (security risk)
- Commit `Packages/` to git (it's generated by `wally install`)
- Forget to run `wally install` after cloning (Packages/ won't exist)

**DO:**
- Use `.luau` extension consistently (Roblox's official Lua dialect)
- Keep sourcemap updated after changing project structure
- Use `init.luau` for folder-as-module pattern
- Add `Packages/` to `.gitignore`
- Use multi-project setup for different environments

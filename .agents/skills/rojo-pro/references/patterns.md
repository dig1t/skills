# Rojo Project Patterns

## Table of Contents
1. [Standard Game Project](#standard-game-project)
2. [Library Distribution](#library-distribution)
3. [Multi-Environment Setup](#multi-environment-setup)
4. [Wally Integration](#wally-integration)
5. [Directory Structures](#directory-structures)
6. [Model Files](#model-files)
7. [Metadata Files](#metadata-files)
8. [CI/CD Patterns](#cicd-patterns)

---

## Standard Game Project

### Full Game Configuration

```json
{
  "name": "MyGame",
  "servePlaceIds": [123456789],
  "globIgnorePaths": ["**/*.spec.luau"],
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
      },
      "StarterCharacterScripts": {
        "$className": "StarterCharacterScripts",
        "$path": "src/StarterCharacterScripts"
      }
    },

    "StarterGui": {
      "$className": "StarterGui",
      "$path": "src/StarterGui"
    },

    "Workspace": {
      "$className": "Workspace",
      "$properties": {
        "FilteringEnabled": true
      },
      "$ignoreUnknownInstances": true
    },

    "Lighting": {
      "$className": "Lighting",
      "$properties": {
        "Ambient": [0.5, 0.5, 0.5],
        "Brightness": 2,
        "GlobalShadows": true,
        "Technology": { "Enum": "Technology.Future" }
      }
    },

    "SoundService": {
      "$className": "SoundService",
      "$ignoreUnknownInstances": true
    },

    "Chat": {
      "$className": "Chat",
      "$ignoreUnknownInstances": true
    }
  }
}
```

### Recommended Directory Structure

```
my-game/
├── .github/
│   └── workflows/
│       └── ci.yml
├── .vscode/
│   ├── extensions.json
│   └── settings.json
├── Packages/                    # Wally packages (gitignored)
├── src/
│   ├── Client/
│   │   ├── init.client.luau    # Client entry point
│   │   ├── Controllers/
│   │   └── UI/
│   ├── Server/
│   │   ├── init.server.luau    # Server entry point
│   │   ├── Services/
│   │   └── Data/
│   ├── Shared/
│   │   ├── Types.luau
│   │   ├── Constants.luau
│   │   └── Util/
│   ├── StarterPlayerScripts/
│   ├── StarterCharacterScripts/
│   └── StarterGui/
├── .gitignore
├── aftman.toml
├── default.project.json
├── selene.toml
├── stylua.toml
├── wally.toml
└── wally.lock
```

---

## Library Distribution

### Minimal Library Config

For publishing a standalone module/library:

```json
{
  "name": "my-library",
  "tree": {
    "$path": "src"
  }
}
```

### Library with Development Environment

Separate configs for distribution vs development:

**default.project.json** (distribution):
```json
{
  "name": "my-library",
  "tree": {
    "$path": "src"
  }
}
```

**dev.project.json** (development/testing):
```json
{
  "name": "my-library-dev",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Packages": {
        "$className": "Folder",
        "MyLibrary": { "$path": "src" },
        "TestEZ": { "$path": "modules/testez/src" }
      }
    },
    "ServerScriptService": {
      "$className": "ServerScriptService",
      "Tests": { "$path": "tests" }
    }
  }
}
```

### Library Directory Structure

```
my-library/
├── src/
│   ├── init.luau              # Main entry point
│   ├── Types.luau
│   └── Internal/
├── tests/
│   └── init.spec.luau
├── modules/                    # Git submodules for dev deps
│   └── testez/
├── default.project.json        # Distribution
├── dev.project.json            # Development
├── wally.toml
└── README.md
```

---

## Multi-Environment Setup

### Development vs Production

**default.project.json** (development):
```json
{
  "name": "MyGame-Dev",
  "servePlaceIds": [111111111],
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Shared": { "$path": "src/Shared" },
      "Packages": { "$path": "Packages" },
      "DevTools": { "$path": "src/DevTools" }
    },
    "ServerScriptService": {
      "$className": "ServerScriptService",
      "Server": { "$path": "src/Server" },
      "Tests": { "$path": "tests" }
    }
  }
}
```

**deploy.project.json** (production):
```json
{
  "name": "MyGame",
  "servePlaceIds": [222222222],
  "globIgnorePaths": ["**/*.spec.luau", "**/tests/**"],
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
    }
  }
}
```

### Version Tracking

Add version file that syncs to game:

**version.txt**:
```
1.2.3
```

**In project.json**:
```json
{
  "ReplicatedStorage": {
    "$className": "ReplicatedStorage",
    "Version": { "$path": "version.txt" }
  }
}
```

**Access in code**:
```lua
local version = ReplicatedStorage.Version.Value
```

---

## Wally Integration

### Standard Wally Setup

**wally.toml**:
```toml
[package]
name = "author/my-game"
version = "1.0.0"
realm = "shared"
registry = "https://github.com/UpliftGames/wally-index"

[dependencies]
Promise = "evaera/promise@4.0.0"
Signal = "sleitnick/signal@2.0.0"

[server-dependencies]
ProfileService = "madstudioroblox/profileservice@1.0.0"

[dev-dependencies]
TestEZ = "roblox/testez@0.4.1"
```

### Project Configuration for Wally

```json
{
  "ReplicatedStorage": {
    "$className": "ReplicatedStorage",
    "Packages": { "$path": "Packages" }
  },
  "ServerScriptService": {
    "$className": "ServerScriptService",
    "ServerPackages": { "$path": "ServerPackages" }
  }
}
```

### Type Generation Workflow

```bash
# Install packages
wally install

# Generate sourcemap
rojo sourcemap default.project.json -o sourcemap.json

# Generate types for packages
wally-package-types --sourcemap sourcemap.json Packages
```

---

## Directory Structures

### Feature-Based Organization

```
src/
├── Server/
│   ├── init.server.luau
│   └── Features/
│       ├── Shop/
│       │   ├── ShopService.luau
│       │   └── ShopData.luau
│       ├── Combat/
│       │   ├── CombatService.luau
│       │   └── DamageCalculator.luau
│       └── Inventory/
│           ├── InventoryService.luau
│           └── ItemData.luau
├── Client/
│   ├── init.client.luau
│   └── Features/
│       ├── Shop/
│       │   ├── ShopController.luau
│       │   └── ShopUI.luau
│       └── Combat/
│           └── CombatController.luau
└── Shared/
    ├── Types.luau
    └── Features/
        └── Shop/
            └── ShopTypes.luau
```

### init.luau as Folder Entry Point

When a folder contains `init.luau`, Rojo treats the folder as a ModuleScript:

```
MyModule/
├── init.luau           # This becomes the module
├── Submodule1.luau     # Child module
└── Submodule2.luau     # Child module
```

**init.luau**:
```lua
local MyModule = {}

MyModule.Submodule1 = require(script.Submodule1)
MyModule.Submodule2 = require(script.Submodule2)

return MyModule
```

---

## Model Files

### .model.json Format

Create Roblox instances declaratively:

**button.model.json**:
```json
{
  "className": "TextButton",
  "properties": {
    "Name": "PurchaseButton",
    "Size": { "UDim2": [[0, 200], [0, 50]] },
    "Position": { "UDim2": [[0.5, -100], [0.5, -25]] },
    "BackgroundColor3": [0.2, 0.6, 0.2],
    "Text": "Purchase",
    "TextColor3": [1, 1, 1],
    "Font": { "Enum": "Font.GothamBold" },
    "TextSize": 18
  },
  "children": [
    {
      "className": "UICorner",
      "properties": {
        "CornerRadius": { "UDim": [0, 8] }
      }
    }
  ]
}
```

### Complex Model with Hierarchy

**shop-kiosk.model.json**:
```json
{
  "className": "Model",
  "properties": {
    "Name": "ShopKiosk"
  },
  "children": [
    {
      "className": "Part",
      "properties": {
        "Name": "Base",
        "Size": [4, 0.5, 4],
        "Position": [0, 0.25, 0],
        "Anchored": true,
        "Material": { "Enum": "Material.SmoothPlastic" }
      }
    },
    {
      "className": "Part",
      "properties": {
        "Name": "Counter",
        "Size": [4, 3, 0.5],
        "Position": [0, 2, 1.75],
        "Anchored": true
      },
      "children": [
        {
          "className": "SurfaceGui",
          "properties": {
            "Face": { "Enum": "NormalId.Front" }
          }
        }
      ]
    }
  ]
}
```

---

## Metadata Files

### .meta.json Usage

Attach properties to files/folders:

**MyScript.luau** + **MyScript.meta.json**:
```json
{
  "properties": {
    "Disabled": true
  }
}
```

### Folder Metadata

**MyFolder/.meta.json**:
```json
{
  "className": "Configuration",
  "properties": {
    "Name": "Settings"
  },
  "ignoreUnknownInstances": true
}
```

---

## CI/CD Patterns

### GitHub Actions Workflow

**.github/workflows/ci.yml**:
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Aftman
        uses: ok-nick/setup-aftman@v0.4.2

      - name: Install tools
        run: aftman install

      - name: Install packages
        run: wally install

      - name: Generate sourcemap
        run: rojo sourcemap default.project.json -o sourcemap.json

      - name: Type check
        run: luau-lsp analyze --sourcemap=sourcemap.json src/

      - name: Lint
        run: selene src/

      - name: Build
        run: rojo build -o game.rbxl
```

### Deploy Workflow

**.github/workflows/deploy.yml**:
```yaml
name: Deploy

on:
  release:
    types: [published]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: ok-nick/setup-aftman@v0.4.2

      - run: aftman install
      - run: wally install

      - name: Build production
        run: rojo build deploy.project.json -o game.rbxl

      - name: Upload to Roblox
        run: |
          # Use Roblox Open Cloud API or rbxcloud CLI
          # rbxcloud experience upload game.rbxl --universe-id ${{ secrets.UNIVERSE_ID }}
        env:
          ROBLOSECURITY: ${{ secrets.ROBLOSECURITY }}
```

### NPM Scripts Pattern

**package.json**:
```json
{
  "scripts": {
    "setup": "aftman install && wally install",
    "sourcemap": "rojo sourcemap default.project.json -o sourcemap.json",
    "types": "wally-package-types --sourcemap sourcemap.json Packages",
    "dev": "npm run setup && npm run sourcemap && npm run types && rojo serve",
    "build": "npm run setup && rojo build -o game.rbxl",
    "build:prod": "npm run setup && rojo build deploy.project.json -o game.rbxl",
    "lint": "selene src/",
    "typecheck": "luau-lsp analyze --sourcemap=sourcemap.json src/",
    "check": "npm run lint && npm run typecheck"
  }
}
```

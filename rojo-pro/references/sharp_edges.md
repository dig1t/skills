# Rojo Sharp Edges & Troubleshooting

## Table of Contents
1. [Connection Issues](#connection-issues)
2. [Sync Problems](#sync-problems)
3. [File Naming Issues](#file-naming-issues)
4. [Project Configuration Errors](#project-configuration-errors)
5. [Type Checking Issues](#type-checking-issues)
6. [Wally Integration Problems](#wally-integration-problems)
7. [Build Failures](#build-failures)
8. [Plugin Issues](#plugin-issues)

---

## Connection Issues

### Plugin Won't Connect to Server

**Symptoms:**
- "Connection failed" in Studio plugin
- Plugin shows "Not Connected"
- Server running but plugin can't find it

**Solutions:**

1. **Check port availability:**
   ```bash
   # Default port is 34872
   lsof -i :34872
   ```

2. **Firewall blocking connection:**
   - Allow Rojo through firewall
   - Try different port in project.json:
   ```json
   { "servePort": 34873 }
   ```

3. **Wrong project file:**
   ```bash
   # Ensure you're serving the right file
   rojo serve default.project.json
   ```

4. **Plugin version mismatch:**
   ```bash
   # Reinstall plugin matching CLI version
   rojo plugin install
   ```

### Connection Drops Frequently

**Cause:** Long-polling timeouts (fixed in v7.7.0 with websockets)

**Solutions:**
- Update to v7.7.0+ for websocket support
- Keep Studio window focused
- Check network stability

---

## Sync Problems

### Changes Not Syncing

**Symptoms:**
- Edit file, no update in Studio
- Server shows no file change events

**Solutions:**

1. **File not in project tree:**
   ```bash
   # Verify file path is mapped in project.json
   cat default.project.json | grep -A5 "path"
   ```

2. **File pattern ignored:**
   ```json
   // Check globIgnorePaths
   {
     "globIgnorePaths": ["**/*.spec.luau"]  // This ignores test files
   }
   ```

3. **File watcher issue:**
   ```bash
   # Restart Rojo server
   # Ctrl+C then rojo serve
   ```

4. **Wrong file extension:**
   - Use `.luau` not `.lua` (or be consistent)
   - Check init file naming: `init.luau` not `Init.luau`

### Scripts Appearing in Wrong Location

**Symptoms:**
- Script shows up in wrong service
- Duplicated scripts

**Solution:** Check project.json tree structure. Each path should only be mapped once:

```json
// WRONG - src mapped twice
{
  "ReplicatedStorage": { "$path": "src" },
  "ServerScriptService": { "$path": "src/Server" }  // Conflicts!
}

// CORRECT - separate source directories
{
  "ReplicatedStorage": { "$path": "src/Shared" },
  "ServerScriptService": { "$path": "src/Server" }
}
```

### init.luau Not Working

**Symptoms:**
- Folder not becoming ModuleScript
- `init.luau` appears as separate file

**Causes & Solutions:**

1. **Wrong filename case:**
   ```bash
   # Must be exactly "init.luau" (lowercase)
   mv Init.luau init.luau
   ```

2. **Mixed extensions:**
   ```bash
   # Don't mix - pick one
   rm init.lua  # if init.luau exists
   ```

3. **Nested project file:**
   - If folder contains `default.project.json`, it uses that instead

---

## File Naming Issues

### Script Type Confusion

| Wanted | Wrong | Correct |
|--------|-------|---------|
| Server Script | `MyScript.luau` | `MyScript.server.luau` |
| Local Script | `MyScript.luau` | `MyScript.client.luau` |
| ModuleScript | `MyScript.server.luau` | `MyScript.luau` |

### Invalid Characters

**Avoid in file/folder names:**
- Spaces (use PascalCase or snake_case)
- Special characters: `< > : " / \ | ? *`
- Leading/trailing dots or spaces

```bash
# WRONG
"My Script.luau"
"script?.luau"

# CORRECT
"MyScript.luau"
"my_script.luau"
```

### Case Sensitivity

**Issue:** Windows/macOS are case-insensitive, Linux is case-sensitive

```bash
# These are SAME file on Windows/macOS
MyModule.luau
mymodule.luau

# But DIFFERENT on Linux - causes CI failures
```

**Solution:** Always use consistent casing, verify in CI on Linux.

---

## Project Configuration Errors

### Missing $className for Services

**Error:** `cannot create instance without className`

```json
// WRONG
{
  "ReplicatedStorage": {
    "Shared": { "$path": "src/Shared" }
  }
}

// CORRECT
{
  "ReplicatedStorage": {
    "$className": "ReplicatedStorage",
    "Shared": { "$path": "src/Shared" }
  }
}
```

### Invalid JSON Syntax

**Common mistakes:**

```json
// WRONG - trailing comma
{
  "name": "MyGame",
  "tree": {},  // <- trailing comma before }
}

// WRONG - comments (pre v7.6.1)
{
  "name": "MyGame",  // This is a comment <- Invalid!
}

// CORRECT (v7.6.1+ supports comments and trailing commas)
{
  "name": "MyGame",
  "tree": {}
}
```

### Path Not Found

**Error:** `path does not exist: src/Missing`

**Solutions:**
1. Create the missing directory
2. Fix typo in project.json
3. Check relative path (relative to project.json location)

### Circular Path References

**Error:** `circular reference detected`

```json
// WRONG - can't include parent in child
{
  "tree": {
    "$path": "."  // Maps entire project including project.json
  }
}
```

---

## Type Checking Issues

### Sourcemap Out of Date

**Symptoms:**
- luau-lsp can't find modules
- Red squiggles on valid requires

**Solution:**
```bash
# Regenerate after any project structure change
rojo sourcemap default.project.json -o sourcemap.json
```

### Package Types Missing

**Symptoms:**
- Wally packages show as `any` type
- No autocomplete for dependencies

**Solution:**
```bash
wally install
rojo sourcemap default.project.json -o sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages
```

### Wrong Sourcemap for Project

**Issue:** Using dev sourcemap when serving deploy project

```bash
# Match sourcemap to project being used
rojo sourcemap deploy.project.json -o sourcemap.json
```

---

## Wally Integration Problems

### Packages Directory Missing

**Symptoms:**
- `Packages/` folder doesn't exist
- Rojo errors about missing path: `path does not exist: Packages`
- Requires in code fail with "Module not found"

**Cause:** Wally packages haven't been installed yet.

**Solution:**
```bash
# Install all packages from wally.toml
wally install

# This creates Packages/ and ServerPackages/ directories
```

**Note:** `Packages/` is gitignored by convention. After cloning a repo, always run `wally install` before `rojo serve`.

---

### Packages Not Installing

**Symptoms:**
- `wally install` fails
- Missing dependencies

**Solutions:**

1. **Registry unreachable:**
   ```bash
   # Check network/proxy settings
   curl https://github.com/UpliftGames/wally-index
   ```

2. **Invalid wally.toml:**
   ```toml
   # Ensure proper format
   [package]
   name = "author/package"  # Must have author/
   version = "1.0.0"        # Semver format
   realm = "shared"         # shared, server, or dev
   ```

3. **Package not found:**
   - Check exact package name on wally.run
   - Version might not exist

### Packages Not Syncing to Studio

**Issue:** Packages/ exists but empty in Studio

**Solution:** Map Packages in project.json:

```json
{
  "ReplicatedStorage": {
    "$className": "ReplicatedStorage",
    "Packages": { "$path": "Packages" }
  }
}
```

### Server Dependencies in Wrong Place

**Issue:** Server-only packages visible to client

**Solution:** Use separate paths:

```toml
[server-dependencies]
ProfileService = "madstudioroblox/profileservice@1.0.0"
```

```json
{
  "ServerScriptService": {
    "$className": "ServerScriptService",
    "ServerPackages": { "$path": "ServerPackages" }
  }
}
```

---

## Build Failures

### Build Produces Empty File

**Symptoms:**
- .rbxl file is tiny/empty
- No instances in built file

**Causes:**
1. Empty tree in project.json
2. All paths are invalid/missing
3. Wrong project file specified

**Debug:**
```bash
# Verbose output
rojo build -o game.rbxl --verbose
```

### Property Sync Limitations

**These properties CANNOT sync live:**
- `Terrain` data
- `MeshPart.MeshId`
- `HttpService.HttpEnabled`
- Some physics properties

**Solution:** Set these manually in Studio or use `$ignoreUnknownInstances`

### Large File Build Timeout

**Issue:** Build hangs on large projects

**Solutions:**
- Exclude unnecessary files with `globIgnorePaths`
- Split into multiple project files
- Use `.rbxm` for large pre-built assets

---

## Plugin Issues

### Plugin Not Installed

**Error:** No Rojo option in Studio plugins

**Solutions:**
```bash
# Install via CLI
rojo plugin install

# Or download from GitHub releases
# Or install from Roblox marketplace (search "Rojo")
```

### Plugin Version Mismatch

**Symptoms:**
- "Protocol version mismatch"
- Connection works but sync fails

**Solution:**
```bash
# Reinstall plugin matching your CLI version
rojo plugin install

# Check versions match
rojo --version
# Compare with plugin version in Studio
```

### Plugin Crashes Studio

**Rare but possible causes:**
- Corrupted plugin file
- Studio version incompatibility

**Solutions:**
1. Uninstall plugin from Studio
2. Delete cached plugin files
3. Reinstall: `rojo plugin install`
4. Try older Rojo version if on latest Studio beta

---

## Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `path does not exist` | Missing directory | Create dir or fix path |
| `cannot create instance` | Missing $className | Add $className to services |
| `unexpected token` | Invalid JSON | Check for trailing commas, comments |
| `connection refused` | Server not running | Start `rojo serve` |
| `protocol mismatch` | Version mismatch | Update plugin to match CLI |
| `file watcher error` | Too many files | Add paths to globIgnorePaths |
| `circular reference` | Path includes project.json | Fix tree structure |

---

## Debugging Commands

```bash
# Check Rojo version
rojo --version

# Validate project file
rojo build --dry-run

# Verbose server output
rojo serve --verbose

# Check what would be built
rojo sourcemap default.project.json -o /dev/stdout | head -100

# Test specific project file
rojo serve other.project.json
```

---

## Prevention Checklist

Before starting development:
- [ ] Rojo CLI installed and in PATH
- [ ] Plugin installed in Studio (version matches CLI)
- [ ] project.json validated (no JSON errors)
- [ ] `wally install` run (creates Packages/ directory)
- [ ] All $path directories exist
- [ ] Services have $className
- [ ] Packages/ mapped if using Wally
- [ ] sourcemap.json generated
- [ ] .gitignore includes Packages/, *.rbxl, sourcemap.json

## Quick Fix: Missing Packages

If you see `path does not exist: Packages` or similar errors after cloning:

```bash
wally install && rojo sourcemap default.project.json -o sourcemap.json
```

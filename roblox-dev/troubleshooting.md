# Troubleshooting Guide

This document covers common issues in Roblox development and their solutions.

## Data & Profile Issues

### Profile Data Not Loading

**Symptoms:**
- Player spawns but data is nil/empty
- "Profile not found" errors in Output
- DataStore errors in console

**Causes & Solutions:**

1. **DataStore not available in Studio**
   ```lua
   -- Enable API services in Studio or use mock stores
   if RunService:IsStudio() then
       -- ProfileDB automatically mocks in Studio
       -- Or set saveInStudio = false in config
   end
   ```

2. **ProfileService not initialized before PlayerAdded**
   ```lua
   -- Ensure proper initialization order
   function PlayerService.start()
       -- ProfileService.init() must be called first
       Players.PlayerAdded:Connect(function(player)
           local profile = ProfileService.getProfile(player)
           if not profile then
               player:Kick("Failed to load data")
               return
           end
       end)

       -- Handle existing players
       for _, player in Players:GetPlayers() do
           task.spawn(playerAdded, player)
       end
   end
   ```

3. **DataTemplate mismatch with ProfileData type**
   ```lua
   -- Ensure DataTemplate matches ProfileData type
   -- In DataTemplate.luau:
   return {
       coins = 100,
       level = 1,
       inventory = {},  -- Must match type
   }

   -- In ProfileTypes.luau:
   export type ProfileData = {
       coins: number,
       level: number,
       inventory: { ItemRecord },  -- Same structure
   }
   ```

4. **Session locking conflicts**
   ```lua
   -- Player may be locked from another session
   -- ProfileDB handles this, but check for:
   -- - Multiple Rojo connections to same game
   -- - Running game in two Studio instances
   ```

### Client Not Receiving Data

**Symptoms:**
- DataController.didLoad never becomes true
- ClientState has default values
- UI shows placeholder data

**Solutions:**

1. **Verify Replica is created on server**
   ```lua
   -- ProfileService must create replica
   replicas[player] = Replica.Server.new({
       players = { player },  -- Player must be in list
       initialData = profileData,
       class = "Profile",  -- Must match client listener
   })
   ```

2. **Check DataController is listening for correct name**
   ```lua
   -- Client must listen for same class name
   Replica.Client.getReplicaAddedSignal("Profile", true):Connect(function(replica)
       -- "Profile" must match server's class
   end)
   ```

3. **Ensure client waits for replica before accessing**
   ```lua
   -- In Entry.client.luau
   if not DataController.didLoad then
       DataController.Loaded:Wait()
   end

   -- Then initialize UI/controllers
   ```

### Data Changes Not Persisting

**Symptoms:**
- Changes work during session but reset on rejoin
- Profile.Save() returns false

**Solutions:**

1. **Use ProfileService methods, not direct mutation**
   ```lua
   -- ❌ Wrong - won't save or replicate
   local profile = ProfileService.getProfile(player)
   profile.data.coins = 100

   -- ✅ Correct - uses proper methods
   ProfileService.set(player, { ["stats.coins"] = 100 })
   ```

2. **Ensure save is called on leave**
   ```lua
   Players.PlayerRemoving:Connect(function(player)
       ProfileService.save(player, true)  -- true = remove from memory
   end)

   game:BindToClose(function()
       for _, player in Players:GetPlayers() do
           ProfileService.save(player, true)
       end
   end)
   ```

3. **Check DataStore API limits**
   ```lua
   -- DataStore has rate limits
   -- Don't call save too frequently
   -- ProfileDB handles auto-save internally
   ```

---

## Remote Event Issues

### Remote Events Not Working

**Symptoms:**
- FireServer doesn't trigger OnServerEvent
- Client dispatches don't reach server handlers

**Solutions:**

1. **Verify RemoteEvent exists**
   ```lua
   -- Server must create remotes before client connects
   local remotes = Instance.new("Folder")
   remotes.Name = "Remotes"
   remotes.Parent = ReplicatedStorage

   local event = Instance.new("RemoteEvent")
   event.Name = "MyEvent"
   event.Parent = remotes
   ```

2. **Check event name spelling**
   ```lua
   -- Case-sensitive!
   -- Server: "PURCHASE_ITEM"
   -- Client must match exactly: "PURCHASE_ITEM"
   ```

3. **Ensure server is listening before client fires**
   ```lua
   -- Server handlers should be set up in init()
   function ShopService.init()
       red.useHandlers(script.Parent.Handlers)
       -- Handlers are ready before any client connects
   end
   ```

4. **Validate payload structure**
   ```lua
   red.bind("PURCHASE", function(player, payload)
       -- Check payload exists and has required fields
       if not payload or not payload.itemId then
           warn("Invalid payload from", player.Name)
           return
       end
   end)
   ```

### Server Not Responding to Client

**Symptoms:**
- Client fires event, nothing happens
- No errors in Output

**Solutions:**

1. **Add validation logging**
   ```lua
   red.bind("ACTION", function(player, payload)
       print(`Received ACTION from {player.Name}`)  -- Debug

       if not player.Parent then
           print("Player left during request")
           return
       end

       -- Continue processing
   end)
   ```

2. **Check for silent failures in handlers**
   ```lua
   -- Handler might be returning early
   function Handler.onPurchase(player, payload)
       if not canPurchase(player, payload.itemId) then
           -- Silently fails - add feedback
           red.dispatch(player, {
               type = "PURCHASE_ERROR",
               err = "Cannot purchase this item"
           })
           return
       end
   end
   ```

---

## Type Checking Issues

### Type Errors in Strict Mode

**Symptoms:**
- Red squiggles in VS Code
- "Type 'X' cannot be converted to type 'Y'" errors

**Solutions:**

1. **Use type assertions when type is known**
   ```lua
   local humanoid = character:WaitForChild("Humanoid") :: Humanoid
   local rootPart = model.PrimaryPart :: BasePart
   ```

2. **Handle nil cases explicitly**
   ```lua
   -- ❌ Might be nil
   local coins = profile.data.stats.coins

   -- ✅ Handle nil
   local coins = profile.data.stats and profile.data.stats.coins or 0
   ```

3. **Use proper type annotations**
   ```lua
   -- Function signatures
   function MyService.process(player: Player, data: string): boolean
       return true
   end

   -- Variables when inference fails
   local items: { [string]: ItemData } = {}
   ```

4. **Check exported types exist**
   ```lua
   -- Type-only modules must return nil
   export type MyType = { ... }
   return nil  -- Not return {}
   ```

### Sourcemap Issues

**Symptoms:**
- Types not recognized for packages
- "Unknown require" warnings

**Solutions:**

1. **Regenerate sourcemap**
   ```bash
   rojo sourcemap default.project.json -o sourcemap.json
   ```

2. **Regenerate package types**
   ```bash
   wally-package-types --sourcemap sourcemap.json Packages
   ```

3. **Run both after wally install**
   ```bash
   wally install
   rojo sourcemap default.project.json -o sourcemap.json
   wally-package-types --sourcemap sourcemap.json Packages
   ```

---

## Bootstrap & Initialization Issues

### Services Not Being Discovered

**Symptoms:**
- Service init/start never called
- Service module not available to other services

**Solutions:**

1. **Check naming convention**
   ```lua
   -- File must end with "Service.luau"
   -- ✅ PlayerService.luau
   -- ❌ Player.luau
   -- ❌ playerService.luau
   ```

2. **Verify directory structure**
   ```
   Server/
   └── Features/
       └── Core/
           └── PlayerService.luau  -- Auto-discovered here
   ```

3. **Check init/start exports**
   ```lua
   local MyService = {}

   function MyService.init()  -- Must be function, not property
       -- ...
   end

   function MyService.start()  -- Must be function
       -- ...
   end

   return MyService  -- Must return the module
   ```

### Circular Dependency Errors

**Symptoms:**
- "Attempted to require a cyclic dependency"
- Module loads forever

**Solutions:**

1. **Use init/start pattern**
   ```lua
   -- Instead of requiring at top level
   local OtherService  -- Declare but don't require

   function MyService.init()
       -- Require in init is safe
       OtherService = require(script.Parent.OtherService)
   end

   function MyService.start()
       -- Now safe to use OtherService
       OtherService.doSomething()
   end
   ```

2. **Use signals for loose coupling**
   ```lua
   -- Instead of direct calls
   MyService.SomethingHappened:Fire(data)

   -- Other service listens
   MyService.SomethingHappened:Connect(handler)
   ```

---

## Performance Issues

### High Memory Usage

**Symptoms:**
- Memory category growing over time
- Server lag with many players

**Solutions:**

1. **Use Maid for cleanup**
   ```lua
   local maid = Maid.new()

   -- Track everything
   maid:Add(connection)
   maid:Add(instance)

   -- Clean up when done
   Players.PlayerRemoving:Connect(function(player)
       maid:Destroy()
   end)
   ```

2. **Disconnect unused connections**
   ```lua
   local connection = signal:Connect(handler)

   -- When no longer needed
   connection:Disconnect()
   ```

3. **Remove references to leaving players**
   ```lua
   local playerData = {}

   Players.PlayerRemoving:Connect(function(player)
       playerData[player] = nil  -- Remove reference
   end)
   ```

### Excessive RemoteEvent Traffic

**Symptoms:**
- Network stats show high traffic
- Client lag during certain actions

**Solutions:**

1. **Batch updates**
   ```lua
   -- ❌ Multiple individual updates
   for _, item in items do
       replica:Set("item_" .. item.id, item)
   end

   -- ✅ Single batched update
   replica:Set("items", items)
   ```

2. **Rate limit client requests**
   ```lua
   local lastRequest = {}

   red.bind("ACTION", function(player, payload)
       local now = os.clock()
       if lastRequest[player] and now - lastRequest[player] < 0.5 then
           return -- Rate limited
       end
       lastRequest[player] = now
       -- Process
   end)
   ```

3. **Only replicate necessary data**
   ```lua
   -- Don't replicate entire profile if only coins changed
   replica:Set("coins", newCoins)  -- Not replica:Set("data", entireProfile)
   ```

---

## UI Issues

### UI Not Updating

**Symptoms:**
- Labels show stale data
- State changes don't reflect in UI

**Solutions:**

1. **Subscribe to state changes**
   ```lua
   ClientState.coins.Changed:Connect(function(newValue)
       coinsLabel.Text = tostring(newValue)
   end)
   ```

2. **Check subscription scope**
   ```lua
   function Route:Mount()
       -- Subscribe when mounted
       self._coinConnection = ClientState.coins.Changed:Connect(self.updateCoins)
   end

   function Route:Unmount()
       -- Unsubscribe when unmounted
       if self._coinConnection then
           self._coinConnection:Disconnect()
       end
   end
   ```

3. **Verify State.Set is called**
   ```lua
   -- Must call Set, not direct assignment
   ClientState.coins:Set(newValue)  -- ✅
   ClientState.coins = newValue     -- ❌ Won't trigger Changed
   ```

---

## Tooling Issues

### Rojo Not Syncing

**Symptoms:**
- Changes not appearing in Studio
- "Disconnected from Rojo" message

**Solutions:**

1. **Check Rojo is running**
   ```bash
   rojo serve
   ```

2. **Verify project file syntax**
   ```bash
   rojo build --output test.rbxl  # Catches JSON errors
   ```

3. **Check for file conflicts**
   - Two files with same name in different directories
   - Unsupported file extensions

### Wally Install Fails

**Symptoms:**
- "Could not find package" errors
- Network errors during install

**Solutions:**

1. **Check wally.toml syntax**
   ```toml
   [dependencies]
   Package = "author/package@1.0.0"  # Exact format
   ```

2. **Verify package exists on registry**
   - Visit https://wally.run/ and search for package
   - Check spelling and version

3. **Clear cache and retry**
   ```bash
   rm -rf ~/.wally
   wally install
   ```

---

## Common Error Messages

### "attempt to index nil with 'X'"
Something is nil that shouldn't be. Add nil checks:
```lua
if not profile or not profile.data then
    return
end
local value = profile.data.stats.coins
```

### "Argument 1 missing or nil"
Function called without required argument:
```lua
-- Check call site
MyService.process(player, data)  -- Are both provided?

-- Add validation
function MyService.process(player: Player, data: any)
    assert(player, "Missing player")
end
```

### "Script timeout: exhausted allowed execution time"
Infinite loop or expensive operation:
```lua
-- Add yield to long loops
while condition do
    -- do work
    if tick() % 100 == 0 then
        task.wait()  -- Yield periodically
    end
end
```

### "Cannot spawn threads while in an 'unsafe state'"
Trying to spawn thread in wrong context:
```lua
-- Don't spawn in RunService callbacks directly
RunService.Heartbeat:Connect(function()
    task.defer(function()  -- Use defer instead of spawn
        -- Your code
    end)
end)
```

---

## Getting More Help

1. **Check Roblox DevForum:** https://devforum.roblox.com/

2. **Review official documentation:**
   - [Roblox Creator Docs](https://create.roblox.com/docs)
   - [Luau Reference](https://luau-lang.org/)

3. **Enable verbose logging:**
   ```lua
   -- Add debug prints to trace issues
   print(`[MyService] Processing {player.Name} with {itemId}`)
   ```

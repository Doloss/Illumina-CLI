# Staff console

A typed command console for staff. ";" opens and closes it. Commands: `kick`, `ban`, `goto`, `fly`, `unfly`, `inv`, `vis`, `kill` (alias `slay`), `freeze`, `unfreeze`, `help`, `clear`.

## What this needs

**The other game must already have the Monarch admin panel installed.** The console has no server of its own: every command is an ordinary `AdminAction` call, so the rank check, rate limit, input check, staff protection and audit log all come from `ServerScriptService.Monarch.Admin`. Without Monarch, the client script stops at its first line of setup and nothing appears.

Specifically it uses:
- `ReplicatedStorage.MonarchShared.Remotes.AdminAction` (created by `Monarch.Admin`)
- `Monarch.Admin.Ranks` and `Monarch.Admin.Rules` (required by `CharacterCommands`)
- the existing actions `kick`, `ban`, `goto` and `setInvisible`

## What's in the folder

| Folder | Use |
|---|---|
| `studio-ready/` | The three scripts with comments removed. Paste these into Studio. |
| `source/` | The same three scripts with comments, for a repo. |

## Install

**1. Add the three scripts.**

| File | Where it goes | Type |
|---|---|---|
| `CharacterCommands.lua` | `ServerScriptService.Monarch.Admin.CharacterCommands` | ModuleScript |
| `CommandParser.lua` | `ServerStorage.MonarchAdmin.Client.CommandParser` | ModuleScript |
| `CommandClient.client.lua` | `ServerStorage.MonarchAdmin.Client.CommandClient` | LocalScript |

Monarch copies everything in `MonarchAdmin.Client` to staff when they join, so the two client scripts need no other wiring.

**2. Make four small edits to modules that Monarch already has.** These add the three new actions (`setFly`, `setFrozen`, `kill`).

`ServerScriptService.Monarch.Admin` (the module itself):
- In `TARGETED`, add a line: `kill = true, setFrozen = true,`
- In `ONLINE_ONLY`, add: `kill = true, setFrozen = true`

`Monarch.Admin.Rules`:
- In `Rules.MIN_LEVEL`, add:
  ```lua
  setFly = ADMIN,
  setFrozen = ADMIN,
  kill = ADMIN,
  ```
- In `Rules.STAFF_PROTECTED`, add:
  ```lua
  setFrozen = true,
  kill = true,
  ```
- In `Rules.DESTRUCTIVE`, add: `kill = true`

`Monarch.Admin.Validate`:
- In `NO_PAYLOAD`, add: `kill = true`
- After the `handlers.infiniteHealth` function, add:
  ```lua
  handlers.setFly = handlers.infiniteHealth
  handlers.setFrozen = handlers.infiniteHealth
  ```

`Monarch.Admin.Actions`:
- With the other requires at the top, add:
  ```lua
  local CharacterCommands = require(script.Parent.CharacterCommands)
  ```
- After the `handlers.setInvisible` function, add:
  ```lua
  function handlers.setFly(request)
  	return CharacterCommands.SetFly(request.actor, request.payload.on)
  end

  function handlers.setFrozen(request)
  	return CharacterCommands.SetFrozen(request.target, request.payload.on)
  end

  function handlers.kill(request)
  	local humanoid = humanoidOf(request.target)
  	if not humanoid or humanoid.Health <= 0 then
  		return false, "That player needs a living character"
  	end
  	infinite[request.target] = nil
  	CharacterCommands.Clear(request.target)
  	humanoid.Health = 0
  	return true, "Killed " .. request.target.Name
  end
  ```
- In `Actions.Init`, straight after `admin = adapter.Admin`, add:
  ```lua
  CharacterCommands.Init()
  ```

**3. Check it.** Join as staff and press ";". Type `help`, then `fly` and `unfly`.

## Things to know

- **Keyboard only.** There is no on-screen button, so staff on phones and tablets can't open it. The F2 panel still works there.
- **Ranks.** `fly`, `kill`, `freeze`, `inv` and `ban` need Admin or higher. `kick` needs Mod or higher. `goto` is open to all staff. Only an Owner can kill or freeze another staff member.
- **Targets** are players in the same server: `me`, an exact name or UserId, or the start of a name if only one player matches.
- **Position.** The console sits 194 px above the bottom of the screen, which clears this game's hotbar and "Store time" button. In another game, change the `-194` in `CommandClient` (the `Dock` frame's `Position`) if it overlaps something.
- **Anti-cheat.** Flight is run by the server, so the flying admin's character moves in ways a movement check may flag. If the other game has its own fly or speed detection, exempt players whose `MonarchFlying` attribute is true.

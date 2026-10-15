# Illumina

A dark glass UI kit for Roblox: translucent panels with a blurred world behind them, lighter glass cards and controls, a solid HUD dock, spring motion, and one accent colour. Cut out of a finished game UI so any game can use it.

## What is in the folder

| Folder | Use |
|---|---|
| `studio-ready/` | Every script with comments removed. Paste these into Studio. |
| `src/` | The same scripts with comments, for a repo. `src/Illumina/init.lua` is the root module. |

## Install

1. In `ReplicatedStorage`, add a **ModuleScript** named `Illumina` and paste `Illumina.lua` into it.
2. Inside that ModuleScript, add seven **ModuleScripts** named `Config`, `Theme`, `Kit`, `Controls`, `Panel`, `Dock` and `Tabs`, and paste the matching file into each.
3. To see it working, add a **LocalScript** named `IlluminaDemo` in `StarterPlayer.StarterPlayerScripts` and paste `IlluminaDemo.lua` into it. Press Play and click the "UI" tile on the left. Delete this script once the game has its own screens.

4. For a sword hotbar, add a **LocalScript** named `Hotbar` in `StarterPlayer.StarterPlayerScripts` and paste `Hotbar.lua` into it. See [Hotbar](#hotbar).

Illumina needs nothing else in the place. It is client-side only: it creates no remotes. The only server contact is the optional one in [Hotbar](#hotbar), and only when the game provides the remotes.

## Settings

Edit `Illumina.Config`:

| Setting | What it does |
|---|---|
| `accent` | The one accent colour. Hover and text-on-accent shades are worked out from it. |
| `fontFamily` | The font family asset. Use a family with Medium, SemiBold and Bold weights. |
| `blur` | `true` blurs the 3D world while a panel is open. `false` turns that off. |

Everything else (glass strength, corner sizes, text sizes, spring feel) is in `Illumina.Theme`.

## The modules

```lua
local Illumina = require(game.ReplicatedStorage:WaitForChild("Illumina"))
local Theme, Kit, Controls, Panel, Dock, Tabs = Illumina.Theme, Illumina.Kit, Illumina.Controls, Illumina.Panel, Illumina.Dock, Illumina.Tabs
```

**Panel**: the glass window.
- `Panel.new(name, title, bodyGap, width)` returns a panel. Put content in `panel.body` (a scrolling column; use `LayoutOrder`). `panel.note` is a muted label in the header.
- `panel:SetOpen(bool)` and `panel:Toggle()`. Opening one panel closes the others.
- `panel.onOpen`, `panel.onClose` and `panel.onLayout(isPhoneSheet)` are optional callbacks.
- `Panel.hideWhileOpen(screenGui)` hides a HUD screen while any panel is open.
- `Panel.Changed` fires `(name, open)`. `Panel.get(name)` returns a panel by name.
- Under 700 px wide the panel becomes a bottom sheet.

**Dock**: the solid column of tiles on the left edge.
- `Dock.new(guiName, align)` (`align` is `"top"`, `"center"` or `"bottom"`) then `dock:Add({ name, icon, label, panel, onClick })`. `icon` is an image id; without one the tile shows `label`. `panel` is the name of the Panel the tile toggles, and the tile lights up while that panel is open.
- `dock:SetLit(name, "accent")` fills a tile with the accent colour, for a toggle that is on. `dock:SetLit(name, false)` puts it back.

**Tabs**: text tabs with a sliding accent underline.
- `Tabs.new(parent, { "One", "Two" }, onSelect, { width, height, layoutOrder })` returns `{ Frame, value, Select(name, animate) }`. `onSelect(name)` fires on taps only.

**Controls**: the parts of a settings-style screen.
- `Controls.group(parent, title, layoutOrder)` returns a glass card.
- `Controls.row(card, text, layoutOrder, note)` returns `row, slot, title`. Put a control in `slot`.
- `Controls.segmented(parent, { { label, value } }, value, onChange)`, `Controls.slider(parent, { min, max, step, value, format, onDrag, onCommit })` (`format(value)` returns the readout text), `Controls.swatch(parent, color, onClick)`.
- `Controls.dialog(gui, width, height, scale)` returns `{ Card, Close }`.

**Kit**: the building blocks.
- Surfaces: `Kit.glass(frame, level, radius)` turns a frame into a glass layer (`level` is `"card"` or `"control"`), `Kit.glassTo(frame, level)` tweens it (use `"hover"` on mouse enter), `Kit.setRim(frame, color)` marks it as selected, `Kit.card(parent, layoutOrder)`.
- Buttons: `Kit.button(parent, { kind, text, width, height, onClick, layoutOrder })`, where `kind` is `primary`, `secondary`, `danger`, `ghost` or `stepper`. `Kit.setEnabled(button, bool)`, `Kit.setSelected(button, bool)`.
- Custom buttons: `local face = Kit.pressable(textButton)` gives a face that squashes on press; parent the content to the face.
- Other parts: `Kit.switch`, `Kit.input`, `Kit.badge`, `Kit.avatar`, `Kit.head`, `Kit.label`, `Kit.frame`, `Kit.scroll`.
- Motion: `Kit.spring(instance, property, goal, Theme.Spring.release)` for a number property, `Kit.tween`, `Kit.countTo(label, from, to, format)`, `Kit.stagger(canvasGroup, index)`.
- Layout helpers: `Kit.new`, `Kit.corner`, `Kit.stroke`, `Kit.pad`, `Kit.list`, `Kit.clear`.

## Hotbar

`Hotbar` is a solid HUD bar of sword slots at the bottom of the screen. A number key or a tap puts that slot's sword in the hand, and the same key puts it away. The held sword's slot gets an accent outline.

Settings at the top of the script:

| Setting | What it does |
|---|---|
| `ICONS` | Tool name to image id. A tool without one shows its initials, so `DarkHeartSword` shows "DH". |
| `SLOTS` | How many slots the bar shows. Keys 1 to 9 match the first nine. |
| `HIDE_ROBLOX_BACKPACK` | `true` turns off Roblox's own backpack bar, which this replaces. |

**Where the swords come from:**
- **With no server code**, slot 1 shows the sword in the player's hand, else the first tool in their Backpack. Nothing else is needed.
- **A game with an inventory** can fill the slots from the server. Put a RemoteFunction named `GetInventory` and a RemoteEvent named `InventoryUpdated` in `ReplicatedStorage`.
  - `GetInventory` returns `{ slots = { "SwordName", ... } }`.
  - `InventoryUpdated:FireClient(player, nil, slots)` sends a change, and the slots that changed pulse.
  - Once the server has answered, the Backpack fallback stops. The slot names must match Tool names in the player's Backpack.

## Things to know

- **The HUD is meant to stay solid.** Use `Theme.Color.panel`, `card` and `control` for anything always on screen, and glass only inside panels. Glass over a busy 3D scene with no blur is hard to read.
- **Panels sit at DisplayOrder 10.** A HUD screen at the default order (0) is drawn underneath, and shows through the glass unless it is registered with `Panel.hideWhileOpen`.
- **The blur is a `BlurEffect` named `IlluminaBlur` in Lighting**, created on the client. If the game clears or replaces Lighting effects, leave that one alone.
- **Not yet checked on a phone.** The bottom-sheet layout exists but has only been tested at desktop sizes.

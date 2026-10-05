# Illumina-CLI

Two drop-in pieces for Roblox games, written in Luau.

| Folder | What it is | Needs |
|---|---|---|
| [`Illumina/`](Illumina/README.md) | A dark glass UI kit: translucent panels over a blurred world, lighter glass cards and controls, a solid HUD dock, spring motion, one accent colour. | Nothing. Client-side only. |
| [`StaffConsole/`](StaffConsole/README.md) | A typed command console for staff, opened with the `;` key. Commands: `kick`, `ban`, `goto`, `fly`, `unfly`, `inv`, `vis`, `kill`, `freeze`, `unfreeze`, `help`, `clear`. | The Monarch admin panel on the server. See its README. |

Each folder has its own README with install steps, a `studio-ready` folder of scripts to paste into Roblox Studio, and the commented source.

## Illumina

- **Panel**: a glass window with a title, close button, spring open, and a bottom-sheet layout on phones. Opening one panel closes the others.
- **Dock**: a solid column of tiles on the left edge that open panels.
- **Tabs, Controls, Kit**: tabs with a sliding underline, grouped setting rows, switches, sliders, segmented choices, buttons, badges, inputs and dialogs.
- **Config**: accent colour, font family, and world blur on or off.
- `IlluminaDemo` shows every part in one panel. `SettingsUI` is an example settings screen built from a single table.

## Staff console

- **Server-authoritative.** The client only sends a command; rank checks, rate limits, input checks and staff protection all run on the server.
- **Server-owned flight and freeze**, so a client cannot fake either.
- **Keyboard only.** There is no on-screen button, so it is not reachable on phones.

## Licence and credit

GPL-3.0, with one added term: keep the notice and credit **ForeverDolo** with a link to this repository. The full wording is in [`NOTICE`](NOTICE) and [`LICENSE`](LICENSE).

In short: you may use and change this, including in a game you earn from, as long as you credit the author and publish the source of anything you distribute that includes it.

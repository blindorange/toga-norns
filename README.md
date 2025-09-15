# TOGA for Norns — Shim + Demo

This repo provides a small **Norns mod (TOGA-SHIM)** that lets you use the excellent [TOGA TouchOSC scripts](https://github.com/wangpy/toga) system-wide, without needing to manually patch each Lua script.

Instead of editing every script (`local grid = …` / `local arc = …`), TOGA-SHIM swaps in TOGA’s Grid/Arc shims automatically at startup. Once enabled, **any script that supports Monome Grid or Arc can be driven from TouchOSC right away**.

---

## What this mod does

- Hooks into Norns’ `script_pre_init` to redirect Grid/Arc calls to TOGA.
- Adds a **SYSTEM → MODS → TOGA-SHIM** menu with:
  - **Force**: Auto (use TOGA only if no hardware) or Always (force TOGA).
  - **Client management**: add the current TouchOSC client, clear or reload saved clients.
  - **Reset destinations**: clear all current TouchOSC connections if things get stuck.
  - **Test lights**: flash a checkerboard on Grid, sweep LEDs on Arc.
- Hardened `togagrid.lua` / `togaarc.lua` with:
  - Safe OSC handler capture/restore.
  - Grid → Arc destination mirroring (Arc auto-connects when Grid connects).
- Includes **arc-hello**, a lightweight Arc demo script (LED arcs + simple sound).

---

## Requirements

- [TOGA](https://github.com/wangpy/toga) installed at:  
  `~/dust/code/toga/`
- This mod installed at:  
  `~/dust/code/toga-shim/`

---

## Install

1. Clone or copy this repo into your Norns `dust` folder.  
   Key files:
~/dust/code/toga-shim/lib/mod.lua
~/dust/code/toga/lib/togagrid.lua
~/dust/code/toga/lib/togaarc.lua
~/dust/code/arc-hello/arc-hello.lua

2. On Norns, go to **SYSTEM → MODS**, enable **TOGA-SHIM**, and **RESTART**.

---

## TouchOSC / TOGA setup

- **Host (IP)**: your Norns’ IP  
- **Outgoing port (to Norns)**: `10111`  
- **Local/Incoming port (on iPad)**: `8002`  
- Use a TouchOSC layout with **Grid** and **Arc** pages.  
- Open Grid once; Arc will auto-mirror.  
- You can also manage clients from the TOGA-SHIM menu.

---

## Quick test

1. Load `SC → arc-hello`.  
2. Turn Arc rings in TouchOSC → LED arcs animate + sound changes.  
3. Try Arc-aware scripts like:  
- **Arcologies**  
- **Cheat Codes 2**  
- **mlr-arc**  
- **meadowphysics-arc**

---

## Script-specific compatibility (Arc/Grid declared locally)

Some scripts (e.g. **Arcologies**) declare their own local Grid/Arc variables at the top of the file, which **shadows** the shim. In those cases TOGA-SHIM can’t intercept, so Arc (or Grid) won’t work until you add two lines to the script **manually**.

Add these at the very top of the script (before any `grid.connect()` / `arc.connect()` or other includes):

```lua
-- Prefer TOGA shims when present (falls back to hardware if not)
local grid = util.file_exists(_path.code.."toga") and include "toga/lib/togagrid" or grid
local arc  = util.file_exists(_path.code.."toga") and include "toga/lib/togaarc"  or arc

Notes
	•	Place them above any lines that re-declare local grid or local arc, and before any connect() calls.
	•	If the script also uses midigrid, keep its include after the lines above, or let midigrid handle Grid and use the TOGA Arc line only.
	•	After editing, reload the script (or restart) to apply changes.

This is only needed for scripts that locally bind grid/arc. Most scripts work system-wide with TOGA-SHIM without any edits.

⸻

Troubleshooting
	•	No Arc LEDs / no movement:
	•	Ensure Grid and Arc pages share the same TouchOSC connection.
	•	Open Grid once, or use “Reset Destinations” in the mod.
	•	“physical arc/grid detected — leaving as is”:
	•	In TOGA-SHIM menu, set Force → Always, then restart.
	•	Still nothing?
	•	Check IP/ports match.
	•	Run arc-hello: if deltas print in Matron but not in your script, that script may require an Arc page/mode.

⸻

Credits
	•	TOGA by [wangpy] — the original TouchOSC layouts and Lua shims for Grid/Arc emulation.
	•	This repo just adds a lightweight system-wide wrapper to make TOGA easier in everyday Norns use.
	•	Shared with ❤️ for the Norns community.

# TOGA for norns — shim + demo

This repo provides a small **Norns mod (TOGA-SHIM)** that lets you use the excellent [Toga TouchOSC scripts](https://github.com/wangpy/toga) system-wide, without needing to manually patch each Lua script.

### Credits

- **[Toga](https://github.com/wangpy/toga)** by [wangpy] — the original TouchOSC templates and Lua shims for Grid/Arc emulation.  
- This repo just adds a lightweight **system-wide wrapper** (the “shim” mod) so any Norns script that uses Grid or Arc can be driven from TouchOSC without editing each script manually.

### What this mod does

- Hooks into Norns’ `script_pre_init` so that Grid/Arc calls can be redirected to Toga automatically.
- Provides a small **SYSTEM > MODS > TOGA-SHIM** menu to toggle *Force/Auto* and reset TouchOSC destinations.
- Lets you use TouchOSC for both Grid and Arc across all your scripts, immediately after enabling the mod.

### Requirements

- Install [Toga](https://github.com/wangpy/toga) into `~/dust/code/toga/`.  
- Install this mod into `~/dust/code/toga-shim/`.  
- Enable **TOGA-SHIM** under SYSTEM → MODS.

### Thanks

All credit for the **TouchOSC layouts, OSC shims, and original work** goes to [wangpy](https://github.com/wangpy).  
This repo is just a small tweak to make that work easier to use system-wide in day-to-day Norns life.
Drop-in **system-wide** OSC shims for **grid** and **arc** (TouchOSC/TOga), plus a musical Arc demo.  
No per-script edits. No REPL required. Toggle via **SYSTEM → MODS → TOGA-SHIM**.

## What you get
- **TOGA-SHIM mod**: replaces `grid`/`arc` at script start.
  - **Force**: `Auto` (default) uses Toga only if no physical device; `Always` forces Toga.
  - **Verbose logging** toggle.
  - “**Reset Destinations**” utility.
- Hardened **togagrid.lua** / **togaarc.lua**:
  - Safe `osc.event` capture/restore.
  - Arc path variants supported (`/encoder` & `/encoder1`, `/button` & `/button1`).
  - Grid→Arc **destination mirroring** (Arc “just works” when Grid connects).
- **arc-hello**: Arc playground (LED arcs, scales, softcut delay).

## Install
1. Copy this repo into your norns `dust`:
~/dust/code/toga-shim/lib/mod.lua
~/dust/code/toga/lib/togagrid.lua
~/dust/code/toga/lib/togaarc.lua
~/dust/code/arc-hello/arc-hello.lua

2. On norns: **SYSTEM → MODS → enable TOGA-SHIM** → **RESTART**.

## TouchOSC / TOga settings
- **Host**: your norns IP
- **Outgoing Port (to norns)**: `10111`
- **Local/Incoming Port (on iPad)**: `8002`
- Use a layout that has **Grid** and **Arc** pages. Open Grid once; Arc is auto-mirrored.

## Quick test
1. Load `SC → arc-hello`.
2. Turn Arc rings → you’ll see LED arcs and hear changes.
3. Try Arc-aware scripts (e.g. *Arcologies*, *Cheat Codes 2*, *mlr-arc*, *meadowphysics-arc*).

## Troubleshooting
- **No Arc LEDs / movement**: ensure the Arc page uses the same TouchOSC connection as Grid; open Grid once (or Reset Destinations in the mod).
- **Logs show “physical arc/grid detected — leaving … as is”**:
- In **TOGA-SHIM** menu, set **Force** to **Always**, restart.
- **Old OSC handler errors**: these shims guard `osc.event` properly; if you replaced them, restore from this repo.
- **Still nothing?** Check your ports/IP, then try the tiny tester:
- `arc-hello` will show Arc deltas in Matron; if prints appear here but not in a given script, that script may require an Arc-specific page/mode.

## Credits
- Built for TouchOSC/TOga with love for the norns community.
- MIT Licence.

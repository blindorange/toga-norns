# TOGA for norns — shim + demo

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

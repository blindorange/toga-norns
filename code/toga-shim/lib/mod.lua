-- TOGA-SHIM mod: system-wide Toga Grid/Arc with a simple settings menu
-- Places a menu at SYSTEM > MODS > TOGA-SHIM and swaps grid/arc at script_pre_init.

local mod     = require 'core/mods'
local util    = require 'util'
local tabutil = require 'tabutil'

-- ── persistence ──────────────────────────────────────────────────────────────
local DATA_DIR = tostring(_path.data) .. "toga-shim/"
local PREFS_FN = DATA_DIR .. "prefs.lua"

-- Force mode:
-- 0 = AUTO  (use Toga only if no physical device)
-- 1 = ALWAYS (use Toga regardless of physical devices)
local FORCE_MODE = 0
local VERBOSE    = false

local function ensure_dir(path)
  if not util.file_exists(path) then os.execute("mkdir -p '"..path.."'") end
end

local function save_prefs()
  ensure_dir(DATA_DIR)
  local ok, err = pcall(tabutil.save, PREFS_FN, { FORCE_MODE = FORCE_MODE, VERBOSE = VERBOSE })
  if not ok then
    local fh = io.open(PREFS_FN, "w")
    if fh then
      fh:write(string.format("return { FORCE_MODE=%d, VERBOSE=%s }\n", FORCE_MODE, tostring(VERBOSE)))
      fh:close()
    else
      print("[toga-shim] could not write prefs:", PREFS_FN)
    end
  end
end

local function load_prefs()
  if util.file_exists(PREFS_FN) then
    local ok, t = pcall(tabutil.load, PREFS_FN)
    if ok and type(t)=="table" then
      if type(t.FORCE_MODE)=="number" then FORCE_MODE = t.FORCE_MODE end
      if type(t.VERBOSE)=="boolean" then VERBOSE = t.VERBOSE end
    end
  else
    FORCE_MODE = 0
    VERBOSE    = false
    save_prefs()
  end
end

local function log(msg) if VERBOSE then print("[toga-shim] "..msg) end end

local function toga_installed()
  return util.file_exists(_path.code.."toga/lib/togagrid.lua")
      or util.file_exists(_path.code.."toga/lib/togaarc.lua")
end

local function have_physical(kind)
  local ok, core = pcall(require, kind) -- 'grid' or 'arc'
  return ok and core and core.vports and (#core.vports > 0)
end

local function safe_include(path)
  local ok, m = pcall(function() return include(path) end)
  if ok then return m else log("include failed: "..path); return nil end
end

-- load prefs now
load_prefs()

-- ── hook: swap modules before scripts init ───────────────────────────────────
mod.hook.register("script_pre_init", "toga-shim preinit", function()
  if not toga_installed() then log("toga not found in dust/code/toga — idle"); return end

  local force   = (FORCE_MODE == 1)
  local sub_grid = force or not have_physical('grid')
  local sub_arc  = force or not have_physical('arc')

  if sub_grid then
    local shim = safe_include 'toga/lib/togagrid'
    if shim then package.loaded['grid'] = shim; log("grid → Toga") end
  else
    log("physical grid detected — leaving grid as is")
  end

  if sub_arc then
    local shim = safe_include 'toga/lib/togaarc'
    if shim then package.loaded['arc'] = shim; log("arc → Toga") end
  else
    log("physical arc detected — leaving arc as is")
  end
end)

-- ── menu (SYSTEM > MODS > TOGA-SHIM) ────────────────────────────────────────
local menu = { i = 1, items = { "Force", "Verbose", "Status", "Reset Destinations" } }

function menu.redraw()
  screen.clear()
  screen.level(15); screen.move(64, 12); screen.text_center("TOGA-SHIM")
  screen.level(8);  screen.move(64, 28); screen.text_center("Force: "..(FORCE_MODE==1 and "Always" or "Auto"))
  screen.move(64, 40); screen.text_center("Verbose: "..(VERBOSE and "On" or "Off"))
  local g = have_physical('grid') and "phys" or "none"
  local a = have_physical('arc')  and "phys" or "none"
  screen.move(64, 52); screen.text_center("Phys  grid:"..g.."  arc:"..a)
  screen.update()
end

function menu.key(n,z)
  if z==0 then return end
  if n==2 then _menu.set_mode("mods") end
  if n==3 then
    if menu.i == 1 then
      FORCE_MODE = (FORCE_MODE==1) and 0 or 1
      save_prefs()
    elseif menu.i == 2 then
      VERBOSE = not VERBOSE
      save_prefs()
    elseif menu.i == 3 then
      print(string.format("[toga-shim] status: Force=%s, Verbose=%s", FORCE_MODE==1 and "Always" or "Auto", tostring(VERBOSE)))
    elseif menu.i == 4 then
      local okg, tg = pcall(function() return (include "toga/lib/togagrid").connect() end)
      if okg and tg then tg.dest = {}; tg:refresh(true) end
      local oka, ta = pcall(function() return (include "toga/lib/togaarc").connect() end)
      if oka and ta then ta.dest = {}; ta:refresh(true) end
      print("[toga-shim] cleared destinations")
    end
    menu.redraw()
  end
end

function menu.enc(n,d)
  if n==2 then
    menu.i = util.clamp(menu.i + (d>0 and 1 or -1), 1, #menu.items)
    menu.redraw()
  end
end

mod.menu.register(mod.this_name, menu)

return {
  get_force_mode = function() return FORCE_MODE end,
  set_force_mode = function(v) FORCE_MODE = (v and 1 or 0); save_prefs() end,
  set_verbose    = function(v) VERBOSE = not not v; save_prefs() end,
}

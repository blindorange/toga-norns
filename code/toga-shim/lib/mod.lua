-- TOGA-SHIM mod: system-wide Toga Grid/Arc with a tiny, robust menu

local mod     = require 'core/mods'
local util    = require 'util'
local tabutil = require 'tabutil'

-- ── prefs ───────────────────────────────────────────────────────────────────
local DATA_DIR = tostring(_path.data) .. "toga-shim/"
local PREFS_FN = DATA_DIR .. "prefs.lua"

-- 0 = AUTO (use Toga only if no physical device)
-- 1 = ALWAYS (force Toga)
local FORCE_MODE = 0

local function ensure_dir(p)
  if not util.file_exists(p) then os.execute("mkdir -p '"..p.."'") end
end

local function save_prefs()
  ensure_dir(DATA_DIR)
  local ok = pcall(tabutil.save, PREFS_FN, { FORCE_MODE = FORCE_MODE })
  if not ok then
    local f = io.open(PREFS_FN, "w")
    if f then f:write(string.format("return { FORCE_MODE=%d }\n", FORCE_MODE)); f:close() end
  end
end

local function load_prefs()
  if util.file_exists(PREFS_FN) then
    local ok, t = pcall(tabutil.load, PREFS_FN)
    if ok and type(t)=="table" and type(t.FORCE_MODE)=="number" then FORCE_MODE = t.FORCE_MODE end
  else
    FORCE_MODE = 0
    save_prefs()
  end
end

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
  if ok then return m else print("[toga-shim] include failed:", path); return nil end
end

load_prefs()

-- ── pre-init: swap grid/arc if needed ───────────────────────────────────────
mod.hook.register("script_pre_init", "toga-shim preinit", function()
  if not toga_installed() then print("[toga-shim] toga not found; idle") return end
  local force    = (FORCE_MODE == 1)
  local sub_grid = force or not have_physical('grid')
  local sub_arc  = force or not have_physical('arc')

  if sub_grid then
    local shim = safe_include 'toga/lib/togagrid'
    if shim then package.loaded['grid'] = shim; print("[toga-shim] grid → Toga") end
  else
    print("[toga-shim] physical grid present; leave as is")
  end

  if sub_arc then
    local shim = safe_include 'toga/lib/togaarc'
    if shim then package.loaded['arc'] = shim; print("[toga-shim] arc → Toga") end
  else
    print("[toga-shim] physical arc present; leave as is")
  end
end)

-- ── menu (tiny + robust) ────────────────────────────────────────────────────
local menu = { i = 1 }

local function force_label() return (FORCE_MODE==1) and "Always" or "Auto" end

-- robust back helper; if UI API fails, hard-escape by loading Awake
local function leave_mods()
  clock.run(function()
    clock.sleep(0)
    local m = _G._menu
    if m and m.set_page and m.pages and m.pages.mods and type(m.pages.mods)=="table" then
      if pcall(m.set_page, "mods") then return end
    end
    if m and m.set_mode and pcall(m.set_mode, "mods") then return end
    -- hard escape
    pcall(norns.script.load, "code/awake/awake.lua")
  end)
end

local rows = {
  { name="Force", value=function() return force_label() end, action=function()
      FORCE_MODE = (FORCE_MODE==1) and 0 or 1; save_prefs()
    end },
  { name="Reset Destinations", value=function() return "" end, action=function()
      local okg, tg = pcall(function() return (include "toga/lib/togagrid").connect() end)
      if okg and tg then tg.dest = {}; tg:refresh(true) end
      local oka, ta = pcall(function() return (include "toga/lib/togaarc").connect() end)
      if oka and ta then ta.dest = {}; ta:refresh(true) end
      print("[toga-shim] cleared destinations")
    end },
  { name="Exit to Mods", value=function() return "" end, action=function() leave_mods() end },
  { name="Exit to Awake", value=function() return "" end, action=function()
      pcall(norns.script.load, "code/awake/awake.lua")
    end },
}

-- required by norns menu system
function menu.init()
  menu.i = 1
  if screen.font_face then screen.font_face(1) end
  if screen.font_size then screen.font_size(8) end
end
function menu.deinit() end

function menu.redraw()
  screen.clear()
  screen.level(15); screen.move(64, 10); screen.text_center("TOGA-SHIM")

  -- compact rows; no bottom status at all (avoids overlap on some shields)
  local y0, row_h = 22, 12
  for idx, row in ipairs(rows) do
    local y = y0 + (idx-1)*row_h
    if idx == menu.i then screen.level(4); screen.move(10, y+3); screen.line(118, y+3); screen.stroke(); screen.level(15)
    else screen.level(8) end
    screen.move(12, y); screen.text(row.name)
    local val = row.value and row.value() or ""
    screen.move(118, y); screen.text_right(val)
  end
  screen.update()
end

function menu.key(n,z)
  if z==0 then return end
  if n==1 or n==2 then
    leave_mods(); return
  elseif n==3 then
    local row = rows[menu.i]; if row and row.action then row.action() end
    menu.redraw()
  end
end

function menu.enc(n,d)
  if n==2 then
    menu.i = util.clamp(menu.i + (d>0 and 1 or -1), 1, #rows)
    menu.redraw()
  end
end

-- register under a unique key
mod.menu.register("toga-shim", menu)

return {
  get_force_mode = function() return FORCE_MODE end,
  set_force_mode = function(v) FORCE_MODE = (v and 1 or 0); save_prefs() end,
}

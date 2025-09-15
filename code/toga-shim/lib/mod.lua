-- TOGA-SHIM — per-device force, client save/load, test lights, solid back
-- Grid/Arc each: Auto / Always / Off
-- K1/K2 exit via mod.menu.exit()

local mod     = require 'core/mods'
local util    = require 'util'
local tabutil = require 'tabutil'

local DATA_DIR    = tostring(_path.data) .. "toga-shim/"
local PREFS_FN    = DATA_DIR .. "prefs.lua"
local CLIENTS_FN  = DATA_DIR .. "clients.lua"

-- 0 = AUTO, 1 = ALWAYS, 2 = OFF
local FORCE_GRID = 0
local FORCE_ARC  = 0

local function ensure_dir(p)
  if not util.file_exists(p) then os.execute("mkdir -p '"..p.."'") end
end

local function save_prefs()
  ensure_dir(DATA_DIR)
  local ok = pcall(tabutil.save, PREFS_FN, { FORCE_GRID = FORCE_GRID, FORCE_ARC = FORCE_ARC })
  if not ok then
    local f = io.open(PREFS_FN, "w")
    if f then f:write(string.format("return { FORCE_GRID=%d, FORCE_ARC=%d }\n", FORCE_GRID, FORCE_ARC)); f:close() end
  end
end

local function load_prefs()
  if util.file_exists(PREFS_FN) then
    local ok, t = pcall(tabutil.load, PREFS_FN)
    if ok and type(t)=="table" then
      if type(t.FORCE_GRID)=="number" then FORCE_GRID = t.FORCE_GRID end
      if type(t.FORCE_ARC) =="number" then FORCE_ARC  = t.FORCE_ARC  end
    end
  else
    FORCE_GRID = 0; FORCE_ARC = 0; save_prefs()
  end
end

local function load_saved_clients()
  if not util.file_exists(CLIENTS_FN) then return end
  local list = tabutil.load(CLIENTS_FN) or {}
  local okg, tg = pcall(function() return (include "toga/lib/togagrid").connect() end)
  if okg and tg then for _,d in ipairs(list) do table.insert(tg.dest, d) end end
  local oka, ta = pcall(function() return (include "toga/lib/togaarc").connect() end)
  if oka and ta then for _,d in ipairs(list) do table.insert(ta.dest, d) end end
end

local function clear_saved_clients()
  os.execute("rm -f '"..CLIENTS_FN.."'")
end

local function save_last_client_from(t)
  ensure_dir(DATA_DIR)
  local list = util.file_exists(CLIENTS_FN) and (tabutil.load(CLIENTS_FN) or {}) or {}
  if t and t.dest and #t.dest > 0 then
    local last = t.dest[#t.dest]
    local exists=false
    for _,d in ipairs(list) do if d[1]==last[1] and d[2]==last[2] then exists=true; break end end
    if not exists then table.insert(list, {last[1], last[2]}); tabutil.save(CLIENTS_FN, list) end
    print(string.format("[toga-shim] saved client: %s:%s", last[1], tostring(last[2])))
  else
    print("[toga-shim] no active client to add")
  end
end

local function force_label(n) return (n==1) and "Always" or (n==2) and "Off" or "Auto" end
local function toga_installed() return util.file_exists(_path.code.."toga/lib/togagrid.lua") or util.file_exists(_path.code.."toga/lib/togaarc.lua") end
local function have_physical(kind) local ok, core = pcall(require, kind); return ok and core and core.vports and (#core.vports > 0) end
local function safe_include(path) local ok, m = pcall(function() return include(path) end); if ok then return m else print("[toga-shim] include failed:", path); return nil end end

load_prefs()

-- swap grid/arc pre-init if needed
mod.hook.register("script_pre_init", "toga-shim preinit", function()
  -- NOTE: call the function!
  if not toga_installed() then print("[toga-shim] toga not found; idle"); return end
  local sub_grid = (FORCE_GRID==1) or (FORCE_GRID==0 and not have_physical('grid'))
  local sub_arc  = (FORCE_ARC ==1) or (FORCE_ARC ==0 and not have_physical('arc'))

  if sub_grid and FORCE_GRID ~= 2 then
    local shim = safe_include 'toga/lib/togagrid'
    if shim then package.loaded['grid'] = shim; print("[toga-shim] grid → Toga ("..force_label(FORCE_GRID)..")") end
  else
    print("[toga-shim] grid left as is ("..force_label(FORCE_GRID)..")")
  end

  if sub_arc and FORCE_ARC ~= 2 then
    local shim = safe_include 'toga/lib/togaarc'
    if shim then package.loaded['arc'] = shim; print("[toga-shim] arc → Toga ("..force_label(FORCE_ARC)..")") end
  else
    print("[toga-shim] arc left as is ("..force_label(FORCE_ARC)..")")
  end
end)

-- load saved clients after boot
mod.hook.register("system_post_startup", "toga-shim load clients", function()
  if toga_installed() then load_saved_clients() end
end)

-- menu -----------------------------------------------------------------------
local menu = { i = 1 }
local rows = {
  { name="Grid force", value=function() return force_label(FORCE_GRID) end, action=function() FORCE_GRID = (FORCE_GRID+1)%3; save_prefs() end },
  { name="Arc force",  value=function() return force_label(FORCE_ARC)  end, action=function() FORCE_ARC  = (FORCE_ARC +1)%3; save_prefs() end },

  { name="Add current client", value=function() return "" end, action=function()
      local okg, tg = pcall(function() return (include "toga/lib/togagrid").connect() end)
      if okg and tg and tg.dest and #tg.dest>0 then save_last_client_from(tg)
      else local oka, ta = pcall(function() return (include "toga/lib/togaarc").connect() end); if oka and ta then save_last_client_from(ta) else print("[toga-shim] no client to add") end end
    end },

  { name="Clear clients", value=function() return "" end, action=function() clear_saved_clients(); print("[toga-shim] cleared saved clients") end },

  { name="Reset Destinations", value=function() return "" end, action=function()
      local okg, tg = pcall(function() return (include "toga/lib/togagrid").connect() end)
      if okg and tg then tg.dest = {}; tg:refresh(true) end
      local oka, ta = pcall(function() return (include "toga/lib/togaarc").connect() end)
      if oka and ta then ta.dest = {}; ta:refresh(true) end
      print("[toga-shim] cleared destinations")
    end },

  { name="Test lights", value=function() return "" end, action=function()
      -- grid checkerboard
      local okg, tg = pcall(function() return (include "toga/lib/togagrid").connect() end)
      if okg and tg then tg:all(0); for y=1,8 do for x=1,16 do tg:led(x,y, ((x+y)%2==0) and 10 or 2) end end; tg:refresh(true) end
      -- arc quarter sweep
      local oka, ta = pcall(function() return (include "toga/lib/togaarc").connect() end)
      if oka and ta then
        if ta.all then ta:all(0) end
        if ta.segment then
          local tau=math.pi*2
          for r=1,4 do ta:segment(r, 0, tau*0.25, 15) end
          if ta.refresh then ta:refresh() end
          clock.run(function()
            clock.sleep(0.6)
            if ta.all then ta:all(0) end
            if ta.refresh then ta:refresh() end
          end)
        end
      end
      print("[toga-shim] test sent")
    end },
}

function menu.init() menu.i = 1; if screen.font_face then screen.font_face(1) end; if screen.font_size then screen.font_size(8) end end
function menu.deinit() end

function menu.redraw()
  screen.clear()
  screen.level(15); screen.move(64, 10); screen.text_center("TOGA-SHIM")
  local y0, row_h = 22, 12
  for idx, row in ipairs(rows) do
    local y = y0 + (idx-1)*row_h
    if idx == menu.i then screen.level(4); screen.move(10, y+3); screen.line(118, y+3); screen.stroke(); screen.level(15) else screen.level(8) end
    screen.move(12, y); screen.text(row.name)
    local val = row.value and row.value() or ""
    screen.move(118, y); screen.text_right(val)
  end
  screen.update()
end

function menu.key(n,z)
  if z==0 then return end
  if n==1 or n==2 then mod.menu.exit(); return
  elseif n==3 then local row = rows[menu.i]; if row and row.action then row.action() end; menu.redraw() end
end

function menu.enc(n,d)
  if n==2 then menu.i = util.clamp(menu.i + (d>0 and 1 or -1), 1, #rows); menu.redraw() end
end

mod.menu.register("toga-shim", menu)

return {
  get_force_modes = function() return FORCE_GRID, FORCE_ARC end,
  set_force_modes = function(g,a) FORCE_GRID = g or FORCE_GRID; FORCE_ARC = a or FORCE_ARC; save_prefs() end,
}

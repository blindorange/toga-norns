-- UNCOMMENT TO add midigrid plugin
-- local grid = util.file_exists(_path.code.."midigrid") and include "midigrid/lib/mg_128" or grid

local togagrid = {
  device = nil, cols = 16, rows = 8,
  old_buffer = nil, new_buffer = nil,
  dest = {}, cleanup_done = false,
  old_grid = nil, old_osc_in = nil, old_cleanup = nil,
  key = nil
}

function togagrid:connect()
  if _ENV.togagrid then return _ENV.togagrid end
  togagrid:init(); _ENV.togagrid = togagrid; return togagrid
end

local function create_buffer(w,h)
  local b = {}; for r=1,w do b[r]={}; for c=1,h do b[r][c]=0 end end; return b
end

function togagrid:init()
  self.device = self
  self.old_buffer = create_buffer(self.cols, self.rows)
  self.new_buffer = create_buffer(self.cols, self.rows)
  self:hook_osc_in(); self:hook_cleanup(); self:refresh(true)

  local ok, g = pcall(function() return grid and grid.connect and grid.connect() end)
  if ok and g then
    self.old_grid = g
    self.old_grid.key = function(x,y,z) if togagrid.key then togagrid.key(x,y,z) end end
  end

  self:send_connected(nil, true)
end

function string.starts(s,p) return string.sub(s,1,string.len(p))==p end

function togagrid.osc_in(path, args, from)
  local consumed=false
  if not togagrid.cleanup_done then
    if string.starts(path, "/toga_connection") then
      print("togagrid connect!")
      local added=false
      for _,d in pairs(togagrid.dest) do if d[1]==from[1] and d[2]==from[2] then added=true break end end
      if not added then
        print("togagrid: add new toga client", from[1]..":"..from[2])
        table.insert(togagrid.dest, from)
        togagrid:refresh(true, from)
      end
      -- mirror Grid dest to Arc
      local ta = _ENV.togaarc or (include "toga/lib/togaarc").connect()
      local already=false
      for _,d in ipairs(ta.dest) do if d[1]==from[1] and d[2]==from[2] then already=true break end end
      if not already then table.insert(ta.dest, from); ta:refresh(true, from) end

      togagrid:send_connected(from, true)
    elseif string.starts(path, "/togagrid/") then
      local i = tonumber(string.sub(path,11))
      local x = ((i-1) % 16) + 1
      local y = (i-1) // 16 + 1
      local z = args[1] // 1
      if togagrid.key then togagrid.key(x,y,z) end
      if z==0 then togagrid:update_led(x,y) end
      consumed=true
    end
  end
  if not consumed then
    if type(togagrid.old_osc_in)=="function" then return togagrid.old_osc_in(path,args,from) end
    return
  end
end

function togagrid:hook_osc_in()
  if self.old_osc_in ~= nil then return end
  self.old_osc_in = osc.event or function() end
  osc.event = togagrid.osc_in
end

function togagrid.cleanup()
  if togagrid.old_cleanup then togagrid.old_cleanup() end
  if not togagrid.cleanup_done then
    togagrid:send_connected(nil, false)
    togagrid.cleanup_done = true
  end
end

function togagrid:hook_cleanup()
  if self.old_cleanup ~= nil then return end
  self.old_cleanup = grid and grid.cleanup or nil
  if grid then grid.cleanup = togagrid.cleanup end
end

function togagrid:rotation(v) if self.old_grid and self.old_grid.rotation then self.old_grid:rotation(v) end end
function togagrid:all(z)
  for r=1,self.rows do for c=1,self.cols do self.new_buffer[c][r]=z end end
  if self.old_grid and self.old_grid.all then self.old_grid:all(z) end
end
function togagrid:led(x,y,z)
  if x>self.cols or y>self.rows then return end
  self.new_buffer[x][y]=z
  if self.old_grid and self.old_grid.led then self.old_grid:led(x,y,z) end
end
function togagrid:refresh(force, target)
  for r=1,self.rows do
    for c=1,self.cols do
      if force or self.new_buffer[c][r]~=self.old_buffer[c][r] then
        self.old_buffer[c][r]=self.new_buffer[c][r]
        self:update_led(c,r,target)
      end
    end
  end
  if self.old_grid and self.old_grid.refresh then self.old_grid:refresh() end
end
function togagrid:intensity(i) if self.old_grid and self.old_grid.intensity then self.old_grid:intensity(i) end end

function togagrid:update_led(c,r,target)
  local z = self.new_buffer[c][r]
  local i = c + (r-1) * self.cols
  local addr = string.format("/togagrid/%d", i)
  for _,dest in pairs(self.dest) do
    if not target or (target[1]==dest[1] and target[2]==dest[2]) then
      osc.send(dest, addr, { z / 15.0 })
    end
  end
end

function togagrid:send_connected(target, connected)
  for _,dest in pairs(self.dest) do
    if not target or (target[1]==dest[1] and target[2]==dest[2]) then
      osc.send(dest, "/toga_connection", { connected and 1.0 or 0.0 })
    end
  end
end

return togagrid

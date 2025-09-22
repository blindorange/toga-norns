-- UNCOMMENT TO add midigrid plugin
-- local grid = util.file_exists(_path.code.."midigrid") and include "midigrid/lib/mg_128" or grid

local togagrid = {
  device = nil, -- needed by cheat codes 2
  cols = 16,
  rows = 8,
  old_buffer = nil,
  new_buffer = nil,
  dest = {},
  cleanup_done = false,
  old_grid = nil,
  old_osc_in = nil,
  old_cleanup = nil,
  key = nil -- key event callback
}

function togagrid:connect()
  if _ENV.togagrid then return _ENV.togagrid end
  togagrid:init()
  _ENV.togagrid = togagrid
  return togagrid
end

local function create_buffer(width, height)
  local new_buffer = {}
  for r = 1, width do
    new_buffer[r] = {}
    for c = 1, height do
      new_buffer[r][c] = 0
    end
  end
  return new_buffer
end

function togagrid:init()
  -- UNCOMMENT to add default touchosc client
  -- table.insert(self.dest, {"192.168.0.123", 8002})

  self.device    = self
  self.old_buffer = create_buffer(self.cols, self.rows)
  self.new_buffer = create_buffer(self.cols, self.rows)
  self:hook_osc_in()
  self:hook_cleanup()
  self:refresh(true)

  -- capture original grid (if any)
  local ok, g = pcall(function() return grid and grid.connect and grid.connect() end)
  if ok and g then
    self.old_grid = g
    self.old_grid.key = function(x, y, z)
      if togagrid.key then
        togagrid.key(x, y, z)
      end
    end
  end

  self:send_connected(nil, true)
end

function string.starts(String, Start)
  return string.sub(String, 1, string.len(Start)) == Start
end

-- @static
function togagrid.osc_in(path, args, from)
  local consumed = false
  if not togagrid.cleanup_done then
    local x, y, z, i
    -- print("togagrid_osc_in", path)
    if string.starts(path, "/toga_connection") then
      print("togagrid connect!")
      local added = false
      for _, dest in pairs(togagrid.dest) do
        if dest[1] == from[1] and dest[2] == from[2] then
          added = true
          break
        end
      end
      if not added then
        print("togagrid: add new toga client", from[1] .. ":" .. from[2])
        table.insert(togagrid.dest, from)
        togagrid:refresh(true, from)
      end

      -- also mirror this TouchOSC client into Arc so Arc works immediately
      local ok, ta = pcall(function() return (include "toga/lib/togaarc").connect() end)
      if ok and ta then
        local already = false
        for _, d in ipairs(ta.dest) do
          if d[1] == from[1] and d[2] == from[2] then
            already = true
            break
          end
        end
        if not already then
          table.insert(ta.dest, from)
          ta:refresh(true, from)
        end
      end

      -- echo back anyway to update connection button value
      togagrid:send_connected(from, true)
      -- do not consume the event so other shims can also add the client.
    elseif string.starts(path, "/togagrid/") then
      i = tonumber(string.sub(path, 11))
      x = ((i - 1) % 16) + 1
      y = (i - 1) // 16 + 1
      z = args[1] // 1
      if togagrid.key then
        togagrid.key(x, y, z)
      end
      if z == 0 then
        -- send button status to touchosc again after release event, which erased button value
        togagrid:update_led(x, y)
      end
      consumed = true
    end
  end

  if not consumed then
    -- invoke original osc.event callback (if any)
    if type(togagrid.old_osc_in) == "function" then
      return togagrid.old_osc_in(path, args, from)
    end
    return
  end
end

function togagrid:hook_osc_in()
  if self.old_osc_in ~= nil then return end
  -- keep whatever OSC handler existed (or a harmless no-op)
  self.old_osc_in = osc.event or function() end
  osc.event = togagrid.osc_in
end

-- @static
function togagrid.cleanup()
  if togagrid.old_cleanup then
    togagrid.old_cleanup()
  end
  if not togagrid.cleanup_done then
    togagrid:send_connected(nil, false)
    togagrid.cleanup_done = true
  end
end

function togagrid:hook_cleanup()
  if self.old_cleanup ~= nil then return end
  -- print("togagrid: hook old cleanup")
  self.old_cleanup = grid and grid.cleanup or nil
  if grid then
    grid.cleanup = togagrid.cleanup
  end
end

function togagrid:rotation(val)
  if self.old_grid and self.old_grid.rotation then
    self.old_grid:rotation(val)
  end
end

function togagrid:all(z)
  for r = 1, self.rows do
    for c = 1, self.cols do
      self.new_buffer[c][r] = z
    end
  end
  if self.old_grid and self.old_grid.all then
    self.old_grid:all(z)
  end
end

function togagrid:led(x, y, z)
  if x > self.cols or y > self.rows then return end
  self.new_buffer[x][y] = z
  if self.old_grid and self.old_grid.led then
    self.old_grid:led(x, y, z)
  end
end

function togagrid:refresh(force_refresh, target_dest)
  for r = 1, self.rows do
    for c = 1, self.cols do
      if force_refresh or self.new_buffer[c][r] ~= self.old_buffer[c][r] then
        self.old_buffer[c][r] = self.new_buffer[c][r]
        self:update_led(c, r, target_dest)
      end
    end
  end
  if self.old_grid and self.old_grid.refresh then
    self.old_grid:refresh()
  end
end

function togagrid:intensity(i)
  if self.old_grid and self.old_grid.intensity then
    self.old_grid:intensity(i)
  end
end

local function transform_to_button_x(z)
  local linear = z / 15.0
  return 0.9 * math.pow(linear, 1.5)
end

function togagrid:update_led(c, r, target_dest)
  local z = self.new_buffer[c][r]
  local i = c + (r - 1) * self.cols
  local addr = string.format("/togagrid/%d", i)
  -- print("togagrid osc.send", addr, z)
  for _, dest in pairs(self.dest) do
    if target_dest and (target_dest[1] ~= dest[1] or target_dest[2] ~= dest[2]) then
      -- skip
    else
      osc.send(dest, addr, { z / 15.0 })
    end
  end
end

function togagrid:send_connected(target_dest, connected)
  for _, dest in pairs(self.dest) do
    if target_dest and (target_dest[1] ~= dest[1] or target_dest[2] ~= dest[2]) then
      -- skip
    else
      osc.send(dest, "/toga_connection", { connected and 1.0 or 0.0 })
    end
  end
end

return togagrid

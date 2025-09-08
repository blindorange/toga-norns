-- arc-hello.lua  • Arc playground with arcing LEDs, scales, and softcut delay
engine.name = "PolyPerc"

local util      = require "util"
local musicutil = require "musicutil"

local function get_arc_module()
  if util.file_exists(_path.code.."toga/lib/togaarc.lua") then
    return include "toga/lib/togaarc"
  end
  local ok, m = pcall(require, "arc")
  if ok and m then return m end

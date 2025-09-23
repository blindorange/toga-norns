local arc_mod = package.loaded["arc"] or require("arc")
local a = arc_mod.connect()
function init() print("[arc-delta] ready") end
function a.delta(n, d) print("[arc-delta] a.delta", n, d) end

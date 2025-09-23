-- arc-hello.lua — “original four” rings + simple LED feedback
-- R1: cutoff base • R2: LFO depth • R3: delay feedback • R4: delay time

engine.name = "PolyPerc"

local util      = require "util"
local musicutil = require "musicutil"

-- Prefer TOGA Arc if present; otherwise use hardware Arc; else no-op stub.
local function get_arc_module()
  if util.file_exists(_path.code.."toga/lib/togaarc.lua") then
    return include "toga/lib/togaarc"
  end
  local ok, m = pcall(require, "arc")
  if ok and m then return m end
  -- no-op fallback object
  return {
    connect = function()
      return {
        all = function() end,
        led = function() end,
        segment = function() end,
        refresh = function() end,
      }
    end
  }
end

local a = get_arc_module().connect()

-- ring values (0..63)
local val = {32,32,32,32}

-- LFO for cutoff
local lfo_phase = 0
local lfo_rate  = 0.12 -- Hz

-- softcut delay max time
local sc_max = 2.0

-- LED feedback ---------------------------------------------------------------

local function arc_feedback()
  if not a then return end
  if a.all then a:all(0) end

  -- draw a short bright segment around each ring position
  local tau   = math.pi * 2
  local width = (tau / 64) * 2

  if a.segment then
    for ring = 1,4 do
      local theta = (val[ring] % 64) / 64 * tau
      a:segment(ring, theta - width, theta + width, 15)
    end
  elseif a.led then
    for ring = 1,4 do
      local i = (val[ring] % 64) + 1  -- 1..64
      a:led(ring, i, 15)
    end
  end

  if a.refresh then a:refresh() end
end

-- Audio / params -------------------------------------------------------------

local function set_delay_feedback(norm)
  local fb = util.clamp(norm, 0, 0.97)
  softcut.rec_level(1, fb)
  softcut.pre_level(1, 1.0)
end

local function set_delay_time(sec)
  sec = util.clamp(sec, 0.05, sc_max)
  softcut.loop_start(1, 0)
  softcut.loop_end(1, sec)
end

local function update_params()
  local cutoff_base = util.linexp(0,63,100,12000, val[1])
  local lfo_depth   = util.linlin(0,63,0,6000,   val[2])
  local cutoff      = cutoff_base + math.sin(lfo_phase * 2*math.pi) * lfo_depth

  engine.cutoff(util.clamp(cutoff, 100, 12000))
  engine.amp(0.8)

  set_delay_feedback(util.linlin(0,63,0,1,      val[3]))
  set_delay_time(    util.linlin(0,63,0.05,sc_max, val[4]))
end

local function delay_init()
  softcut.buffer_clear()
  softcut.enable(1,1)
  softcut.level(1,1.0)
  softcut.level_slew_time(1,0.02)
  softcut.rate(1,1.0)
  softcut.play(1,1)
  softcut.loop(1,1)
  softcut.loop_start(1,0.0)
  softcut.loop_end(1, sc_max)
  softcut.position(1,0.0)
  softcut.fade_time(1,0.01)
  softcut.rec(1,1)
  audio.level_eng_cut(1.0)
  audio.level_cut(1.0)
  audio.level_dac(1.0)
end

-- UI -------------------------------------------------------------------------

local function redraw_screen()
  screen.clear()
  screen.level(15); screen.move(64,12); screen.text_center("arc-hello")
  screen.level(8);  screen.move(64,28); screen.text_center("R1 cutoff  R2 LFO")
  screen.move(64,42); screen.text_center("R3 fbk    R4 time")
  screen.move(64,58); screen.text_center(string.format("LFO %.2f Hz", lfo_rate))
  screen.update()
end

-- Norns lifecycle ------------------------------------------------------------

function init()
  delay_init()
  update_params()
  arc_feedback()
  redraw_screen()

  -- simple tone generator: random triad so you hear the filter/delay move
  clock.run(function()
    while true do
      engine.hz(musicutil.note_num_to_freq(60 + (math.random(0,2)*7)))
      clock.sleep(0.5)
    end
  end)

  -- LFO + param refresh @ ~30 fps
  clock.run(function()
    while true do
      lfo_phase = (lfo_phase + lfo_rate/30) % 1
      update_params()
      clock.sleep(1/30)
    end
  end)
end

-- Arc events -----------------------------------------------------------------

function a.delta(n, d)
  val[n] = (val[n] + d) % 64
  update_params()
  arc_feedback()
end

-- Optional: tweak LFO rate with enc2; K3 triggers a note immediately
function enc(n, d)
  if n==2 then
    lfo_rate = util.clamp(lfo_rate + d*0.005, 0.02, 1.0)
    redraw_screen()
  end
end

function key(n, z)
  if z==1 and n==3 then
    engine.hz(musicutil.note_num_to_freq(60 + (math.random(0,2)*7)))
  end
end

function cleanup() end

-- Recon pass 22: continue tracing the corridor by alternating small Down and
-- Right taps (isometric diagonal hallway), screenshotting each step.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid21_progress.State")

local steps = {
  {"Down", 20}, {"Right", 20}, {"Down", 20}, {"Right", 20},
  {"Down", 20}, {"Right", 20}, {"Down", 20}, {"Right", 20},
  {"Down", 20}, {"Right", 20},
}
for i, s in ipairs(steps) do
  local btn = {}
  btn[s[1]] = true
  hold(btn, s[2]); wait(8)
  client.screenshot(out .. string.format("sraid22_%02d_%s.png", i, s[1]))
end

savestate.save(out .. "sraid22_progress.State")
wait(3)
client.exit()

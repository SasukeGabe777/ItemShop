-- Recon pass 17: longer directional holds to actually cross the room instead
-- of orbiting near spawn.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid16_progress.State")

local steps = {
  {"Down", 80}, {"Right", 80}, {"Down", 80}, {"Right", 80},
  {"Down", 80}, {"Right", 80},
}
for i, s in ipairs(steps) do
  local btn = {}
  btn[s[1]] = true
  hold(btn, s[2]); wait(10)
  client.screenshot(out .. string.format("sraid17_%02d_%s.png", i, s[1]))
end

savestate.save(out .. "sraid17_progress.State")
wait(3)
client.exit()

-- Recon pass 16: broader exploration of the Traverse Town room to find the
-- floor extent and any Heartless to fight.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid15_progress.State")

local steps = {
  {"Right", 40}, {"Down", 40}, {"Right", 40}, {"Down", 40},
  {"Right", 40}, {"Up", 40}, {"Right", 40}, {"Down", 40},
}
for i, s in ipairs(steps) do
  local btn = {}
  btn[s[1]] = true
  hold(btn, s[2]); wait(10)
  client.screenshot(out .. string.format("sraid16_%02d_%s.png", i, s[1]))
end

savestate.save(out .. "sraid16_progress.State")
wait(3)
client.exit()

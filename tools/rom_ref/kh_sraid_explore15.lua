-- Recon pass 15: dismiss the "Traverse Town" room banner, then explore this
-- new room for an enemy encounter (walking into a Heartless triggers battle
-- in CoM's overworld).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")

hold({A = true}, 6); wait(60)
client.screenshot(out .. "sraid15_00.png")

local steps = {
  {"Down", 20}, {"Left", 30}, {"Down", 30}, {"Left", 30},
  {"Down", 30}, {"Right", 30}, {"Down", 30}, {"Left", 30},
}
for i, s in ipairs(steps) do
  local btn = {}
  btn[s[1]] = true
  hold(btn, s[2]); wait(10)
  client.screenshot(out .. string.format("sraid15_%02d_%s.png", i, s[1]))
end

savestate.save(out .. "sraid15_progress.State")
wait(3)
client.exit()

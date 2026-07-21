-- Recon pass 9: grind through the remaining one-liner dialogue chain with A,
-- screenshotting every tap, until it ends (blank/no textbox) or repeats.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid8_progress.State")

for i = 1, 20 do
  hold({A = true}, 6); wait(70)
  client.screenshot(out .. string.format("sraid9_%02d.png", i))
end

savestate.save(out .. "sraid9_progress.State")
wait(3)
client.exit()

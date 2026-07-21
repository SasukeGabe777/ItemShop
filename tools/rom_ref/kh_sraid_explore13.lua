-- Recon pass 13: Room Synthesis screen wants a map card. See what happens
-- next -- probably an auto-continue for the tutorial floor, or a card pick
-- menu. Advance with A a bunch, screenshotting each step.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid12_progress.State")

for i = 1, 14 do
  hold({A = true}, 6); wait(50)
  client.screenshot(out .. string.format("sraid13_%02d.png", i))
end

savestate.save(out .. "sraid13_progress.State")
wait(3)
client.exit()

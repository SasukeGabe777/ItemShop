local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_battle_progress3.State")
for i = 1, 10 do
  hold({A = true}, 6); wait(60)
end
client.screenshot(out .. "kh_step15_00.png")
-- cycle through cards with R a few times, screenshotting each
for i = 1, 5 do
  hold({R = true}, 6); wait(20)
  client.screenshot(out .. string.format("kh_step15_r%d.png", i))
end
savestate.save(out .. "kh_battle_progress4.State")
wait(3)
client.exit()

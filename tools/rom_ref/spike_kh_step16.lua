local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_battle_progress4.State")
-- use the currently selected card (A), 3 times in quick succession
hold({A = true}, 8); wait(10)
client.screenshot(out .. "kh_step16_a1.png")
hold({A = true}, 8); wait(10)
client.screenshot(out .. "kh_step16_a2.png")
hold({A = true}, 8); wait(10)
client.screenshot(out .. "kh_step16_a3.png")
wait(60)
client.screenshot(out .. "kh_step16_a4.png")
savestate.save(out .. "kh_battle_progress5.State")
wait(3)
client.exit()

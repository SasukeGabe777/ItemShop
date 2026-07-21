local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_battle_progress4.State")
-- approach the enemy (it's to the right) then attack
hold({Right = true}, 40); wait(10)
client.screenshot(out .. "kh_step17_00.png")
hold({A = true}, 20); wait(30)
client.screenshot(out .. "kh_step17_01.png")
hold({A = true}, 20); wait(30)
client.screenshot(out .. "kh_step17_02.png")
hold({A = true}, 20); wait(30)
client.screenshot(out .. "kh_step17_03.png")
hold({A = true}, 20); wait(30)
client.screenshot(out .. "kh_step17_04.png")
savestate.save(out .. "kh_battle_progress6.State")
wait(3)
client.exit()

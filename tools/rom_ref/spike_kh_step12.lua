local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_battle_progress.State")
client.screenshot(out .. "kh_step12_00.png")
hold({R = true}, 6); wait(20)
client.screenshot(out .. "kh_step12_01.png")
hold({L = true}, 6); wait(20)
client.screenshot(out .. "kh_step12_02.png")
hold({A = true}, 30); wait(30)
client.screenshot(out .. "kh_step12_03.png")
hold({Down = true}, 6); wait(20)
client.screenshot(out .. "kh_step12_04.png")
hold({Up = true}, 6); wait(20)
client.screenshot(out .. "kh_step12_05.png")
wait(3)
client.exit()

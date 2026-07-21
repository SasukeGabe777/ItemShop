local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_battle_progress.State")
hold({A = true}, 120); wait(30)
client.screenshot(out .. "kh_step13_00.png")
hold({A = true}, 120); wait(30)
client.screenshot(out .. "kh_step13_01.png")
hold({A = true}, 120); wait(30)
client.screenshot(out .. "kh_step13_02.png")
savestate.save(out .. "kh_battle_progress2.State")
wait(3)
client.exit()

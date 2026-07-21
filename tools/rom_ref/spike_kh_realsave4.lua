local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_realsave_room.State")
hold({Up = true}, 40); wait(15)
hold({Up = true}, 60); wait(15)
hold({Left = true}, 100); wait(15)
hold({Down = true}, 100); wait(15)
hold({Right = true}, 150); wait(15)
client.screenshot(out .. "kh_rs4_00.png")
hold({Up = true}, 60); wait(15)
client.screenshot(out .. "kh_rs4_01.png")
hold({Right = true}, 60); wait(15)
client.screenshot(out .. "kh_rs4_02.png")
hold({Up = true}, 60); wait(15)
client.screenshot(out .. "kh_rs4_03.png")
savestate.save(out .. "kh_realsave_progress.State")
wait(3)
client.exit()

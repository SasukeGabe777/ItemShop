local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_realsave_room.State")
hold({Up = true}, 40); wait(15)
client.screenshot(out .. "kh_rs3_00.png")   -- should be room2 (the diamond platform)
-- keep pushing the same direction we entered from (up), then try each remaining direction longer
hold({Up = true}, 60); wait(15)
client.screenshot(out .. "kh_rs3_01.png")
hold({Left = true}, 100); wait(15)
client.screenshot(out .. "kh_rs3_02.png")
hold({Down = true}, 100); wait(15)
client.screenshot(out .. "kh_rs3_03.png")
hold({Right = true}, 150); wait(15)
client.screenshot(out .. "kh_rs3_04.png")
wait(3)
client.exit()

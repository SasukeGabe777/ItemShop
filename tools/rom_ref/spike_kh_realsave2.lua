local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_realsave_room.State")
-- approach the door (up a little, it's up-right of spawn) but stop short
hold({Up = true}, 12); wait(10)
client.screenshot(out .. "kh_rs2_00.png")
hold({A = true}, 10); wait(60)
client.screenshot(out .. "kh_rs2_01.png")
hold({A = true}, 10); wait(60)
client.screenshot(out .. "kh_rs2_02.png")
-- Select button too, in case it opens a floor/card map
hold({Select = true}, 10); wait(60)
client.screenshot(out .. "kh_rs2_03.png")
wait(3)
client.exit()

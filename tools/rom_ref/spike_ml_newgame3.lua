local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "ml_newgame_check.State")
hold({Up = true}, 8); wait(20)
client.screenshot(out .. "ml_ng3_00.png")
hold({Right = true}, 8); wait(20)
client.screenshot(out .. "ml_ng3_01.png")
hold({Down = true}, 8); wait(20)
client.screenshot(out .. "ml_ng3_02.png")
wait(3)
client.exit()

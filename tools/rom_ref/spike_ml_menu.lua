local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "ml_at_room.State")
hold({Start = true}, 10); wait(60)
client.screenshot(out .. "ml_menu_00.png")
hold({Right = true}, 10); wait(20)
client.screenshot(out .. "ml_menu_01.png")
hold({Right = true}, 10); wait(20)
client.screenshot(out .. "ml_menu_02.png")
hold({Right = true}, 10); wait(20)
client.screenshot(out .. "ml_menu_03.png")
wait(3)
client.exit()

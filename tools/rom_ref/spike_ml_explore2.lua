local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "ml_at_room.State")
hold({Down = true}, 60); wait(15)
client.screenshot(out .. "ml_e2_00.png")
hold({Down = true}, 60); wait(15)
client.screenshot(out .. "ml_e2_01.png")
hold({Left = true}, 60); wait(15)
client.screenshot(out .. "ml_e2_02.png")
wait(3)
client.exit()

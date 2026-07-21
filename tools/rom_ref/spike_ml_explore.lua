local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)      -- confirm "MARIO & LUIGI"
hold({A = true}, 10); wait(120)     -- file screen -> Start Game (cursor default?)
client.screenshot(out .. "ml_e00_filemenu.png")
hold({A = true}, 10); wait(150)     -- confirm Start Game
client.screenshot(out .. "ml_e01.png")
hold({A = true}, 10); wait(90)
client.screenshot(out .. "ml_e02.png")
savestate.save(out .. "ml_at_room.State")
wait(3)
client.exit()

-- Return to the REAL converted save (Level 55 Sora), not new-game, and
-- checkpoint right at the room so we can iterate quickly.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({Start = true}, 10); wait(90)   -- (in case first Start needed a repeat, as seen before)
client.screenshot(out .. "kh_rs_00.png")
hold({A = true}, 10); wait(90)       -- confirm LOAD (default cursor)
client.screenshot(out .. "kh_rs_01.png")
hold({A = true}, 10); wait(120)      -- confirm slot list -> File 1
client.screenshot(out .. "kh_rs_02.png")
hold({A = true}, 10); wait(150)      -- confirm File 1 -> into the room
client.screenshot(out .. "kh_rs_03.png")
savestate.save(out .. "kh_realsave_room.State")
wait(3)
client.exit()

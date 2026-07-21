local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)      -- new game: sora
wait(60)
client.screenshot(out .. "kh_d00.png")
-- approach the door (it's up-right of spawn) without going through it fully
hold({Up = true}, 20); wait(10)
client.screenshot(out .. "kh_d01.png")
hold({A = true}, 6); wait(90)
client.screenshot(out .. "kh_d02.png")
hold({A = true}, 6); wait(90)
client.screenshot(out .. "kh_d03.png")
hold({Right = true}, 10); wait(10)
hold({A = true}, 6); wait(90)
client.screenshot(out .. "kh_d04.png")
wait(3)
client.exit()

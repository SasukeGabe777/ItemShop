-- Check if the LINK -> Versus Battle menu offers a single-player CPU battle
-- (would be the fastest path to a real card battle for capture purposes).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)         -- title -> menu, cursor on LOAD
hold({Down = true}, 8); wait(20)       -- move to LINK
client.screenshot(out .. "kh_v00.png")
hold({A = true}, 10); wait(90)         -- confirm LINK
client.screenshot(out .. "kh_v01.png")
hold({A = true}, 10); wait(90)         -- confirm Versus Battle
client.screenshot(out .. "kh_v02.png")
hold({A = true}, 10); wait(120)
client.screenshot(out .. "kh_v03.png")
hold({A = true}, 10); wait(150)
client.screenshot(out .. "kh_v04.png")
wait(3)
client.exit()

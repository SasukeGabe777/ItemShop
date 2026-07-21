-- Explore from the loaded save: confirm controls, look for barrier-worthy
-- terrain (crates/fences/lamps) and any nearby enemy to trigger a battle.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)              -- title -> menu (cursor on LOAD)
hold({A = true}, 10); wait(120)             -- confirm LOAD -> slot list
hold({A = true}, 10); wait(150)             -- confirm slot -> into the room
client.screenshot(out .. "kh_e00.png")

hold({Down = true}, 60); wait(10); client.screenshot(out .. "kh_e01_down.png")
hold({Left = true}, 60); wait(10); client.screenshot(out .. "kh_e02_left.png")
hold({Up = true}, 60); wait(10); client.screenshot(out .. "kh_e03_up.png")
hold({Right = true}, 60); wait(10); client.screenshot(out .. "kh_e04_right.png")
hold({Up = true}, 90); wait(10); client.screenshot(out .. "kh_e05_up2.png")
hold({Right = true}, 90); wait(10); client.screenshot(out .. "kh_e06_right2.png")

wait(3)
client.exit()

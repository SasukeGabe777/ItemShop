-- Try entering the door/portal to reach a themed room (Traverse Town etc.)
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)
hold({A = true}, 10); wait(120)
hold({A = true}, 10); wait(150)
client.screenshot(out .. "kh_f00.png")

-- walk to the door straight ahead (up-ish, toward the portal seen in kh_e00)
hold({Up = true}, 30); wait(10)
client.screenshot(out .. "kh_f01.png")
hold({A = true}, 6); wait(120)
client.screenshot(out .. "kh_f02.png")
hold({A = true}, 6); wait(150)
client.screenshot(out .. "kh_f03.png")
hold({A = true}, 6); wait(150)
client.screenshot(out .. "kh_f04.png")
wait(3)
client.exit()

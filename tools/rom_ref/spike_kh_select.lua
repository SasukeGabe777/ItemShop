-- From the save-point room, try Select (card/map/menu access) and B (cancel
-- the save prompt) to find the way into a real explorable/battle room.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)     -- new game: sora
wait(60)
hold({B = true}, 10); wait(60)     -- cancel the save prompt if present
client.screenshot(out .. "kh_sel00.png")
hold({Select = true}, 10); wait(60)
client.screenshot(out .. "kh_sel01.png")
hold({B = true}, 10); wait(60)
client.screenshot(out .. "kh_sel02.png")
-- try walking through the door again and look at what's beyond fully
hold({Up = true}, 40); wait(20)
client.screenshot(out .. "kh_sel03.png")
hold({Up = true}, 60); wait(20)
client.screenshot(out .. "kh_sel04.png")
hold({Left = true}, 60); wait(10)
client.screenshot(out .. "kh_sel05.png")
hold({Down = true}, 90); wait(10)
client.screenshot(out .. "kh_sel06.png")
wait(3)
client.exit()

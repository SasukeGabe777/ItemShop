-- Follow-up: select LOAD and confirm the actual save slot renders (not blank).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)              -- title -> menu (NEW GAME/LOAD/LINK)
hold({Down = true}, 8); wait(20)            -- move cursor down to LOAD (menu may open directly on LOAD already)
client.screenshot(out .. "kh_s03_menu.png")
hold({A = true}, 10); wait(120)             -- confirm LOAD
client.screenshot(out .. "kh_s04_loadslot.png")
wait(3)
client.exit()

-- Follow-up v2: the menu opens with cursor already on LOAD -- confirm it
-- shows the actual save slot with progress, not blank/new.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)              -- title -> menu (cursor starts on LOAD)
client.screenshot(out .. "kh_s05_menu.png")
hold({A = true}, 10); wait(120)             -- confirm LOAD
client.screenshot(out .. "kh_s06_loadslot.png")
hold({A = true}, 10); wait(150)             -- confirm the save slot itself
client.screenshot(out .. "kh_s07_afterload.png")
wait(3)
client.exit()

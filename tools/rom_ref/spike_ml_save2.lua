-- Follow-up: select "MARIO & LUIGI" and confirm the save-file screen shows
-- real progress (not a blank/new file).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)              -- confirm "MARIO & LUIGI"
client.screenshot(out .. "ml_s03.png")
hold({A = true}, 10); wait(120)
client.screenshot(out .. "ml_s04.png")
hold({A = true}, 10); wait(150)
client.screenshot(out .. "ml_s05.png")
wait(3)
client.exit()

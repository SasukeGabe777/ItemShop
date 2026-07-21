-- Confirm the converted battery save shows on M&L Superstar Saga's file-select.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900); client.screenshot(out .. "ml_s00_title.png")
hold({Start = true}, 10); wait(90); client.screenshot(out .. "ml_s01.png")
hold({A = true}, 10); wait(90); client.screenshot(out .. "ml_s02.png")
wait(3)
client.exit()

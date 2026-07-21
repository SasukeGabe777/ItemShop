local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)      -- confirm "MARIO & LUIGI"
client.screenshot(out .. "ml_ng_00.png")
-- move cursor to NEW (first new-file slot) -- default may be on FILE1 already;
-- try Right to reach a NEW slot if needed
hold({Right = true}, 8); wait(20)
client.screenshot(out .. "ml_ng_01.png")
hold({A = true}, 10); wait(90)
client.screenshot(out .. "ml_ng_02.png")
savestate.save(out .. "ml_newgame_check.State")
wait(3)
client.exit()

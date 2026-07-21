local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "ml_newgame_check.State")
hold({R = true}, 8); wait(20)
client.screenshot(out .. "ml_ng2_00.png")
hold({A = true}, 10); wait(60)
client.screenshot(out .. "ml_ng2_01.png")
hold({A = true}, 10); wait(90)
client.screenshot(out .. "ml_ng2_02.png")
savestate.save(out .. "ml_newgame_slot.State")
wait(3)
client.exit()

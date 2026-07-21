local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_intro_progress6.State")
hold({B = true}, 6); wait(30)
client.screenshot(out .. "kh_step9_00.png")
hold({Left = true}, 4); wait(4); hold({Left = true}, 4); wait(30)
client.screenshot(out .. "kh_step9_01.png")
hold({A = true}, 6); wait(60)
client.screenshot(out .. "kh_step9_02.png")
hold({A = true}, 6); wait(60)
client.screenshot(out .. "kh_step9_03.png")
savestate.save(out .. "kh_intro_progress7.State")
wait(3)
client.exit()

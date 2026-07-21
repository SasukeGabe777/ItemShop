local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_realsave_progress2.State")
-- let the text finish typing on its own first (no input), then press A once
wait(120)
client.screenshot(out .. "kh_rs7_00.png")
hold({A = true}, 4); wait(90)
client.screenshot(out .. "kh_rs7_01.png")
hold({A = true}, 4); wait(90)
client.screenshot(out .. "kh_rs7_02.png")
hold({A = true}, 4); wait(90)
client.screenshot(out .. "kh_rs7_03.png")
hold({A = true}, 4); wait(90)
client.screenshot(out .. "kh_rs7_04.png")
hold({A = true}, 4); wait(90)
client.screenshot(out .. "kh_rs7_05.png")
savestate.save(out .. "kh_realsave_progress4.State")
wait(3)
client.exit()

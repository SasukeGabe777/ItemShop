local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "ml_intro_progress3.State")
wait(300)
client.screenshot(out .. "ml_ng8_wait.png")
hold({B = true}, 10); wait(60)
client.screenshot(out .. "ml_ng8_b.png")
hold({A = true}, 4); wait(300)
client.screenshot(out .. "ml_ng8_a1.png")
wait(3)
client.exit()

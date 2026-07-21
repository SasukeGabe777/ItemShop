local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)
hold({A = true}, 10); wait(120)
hold({A = true}, 10); wait(150)
hold({A = true}, 10); wait(150)
-- explore further into the castle looking for a roaming enemy to touch
hold({Right = true}, 80); wait(15)
client.screenshot(out .. "ml_fb_00.png")
hold({Up = true}, 80); wait(15)
client.screenshot(out .. "ml_fb_01.png")
hold({Right = true}, 100); wait(15)
client.screenshot(out .. "ml_fb_02.png")
hold({Down = true}, 80); wait(15)
client.screenshot(out .. "ml_fb_03.png")
savestate.save(out .. "ml_explore_far.State")
wait(3)
client.exit()

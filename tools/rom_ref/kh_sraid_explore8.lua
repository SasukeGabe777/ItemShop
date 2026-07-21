-- Recon pass 8: one more A press to close the last dialogue box, then walk
-- to the door and through it.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid7_progress.State")

hold({A = true}, 6); wait(60)
client.screenshot(out .. "sraid8_a1.png")
hold({A = true}, 6); wait(60)
client.screenshot(out .. "sraid8_a2.png")

hold({Up = true}, 30); wait(5)
client.screenshot(out .. "sraid8_m1.png")
hold({Right = true}, 50); wait(5)
client.screenshot(out .. "sraid8_m2.png")
hold({Up = true}, 40); wait(5)
client.screenshot(out .. "sraid8_m3.png")
hold({Right = true}, 30); wait(5)
client.screenshot(out .. "sraid8_m4.png")
hold({Up = true}, 40); wait(20)
client.screenshot(out .. "sraid8_m5.png")

savestate.save(out .. "sraid8_progress.State")
wait(3)
client.exit()

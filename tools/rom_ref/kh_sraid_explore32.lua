-- Recon pass 32: check the Start menu (deck/cards) from within the Traverse
-- Town save room, to understand what tools we have (map cards left, enemy
-- cards, etc.) and whether there's a way to progress besides walking.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)

hold({Start = true}, 6); wait(40)
client.screenshot(out .. "sraid32_start1.png")
hold({Right = true}, 10); wait(20)
client.screenshot(out .. "sraid32_start2.png")
hold({Right = true}, 10); wait(20)
client.screenshot(out .. "sraid32_start3.png")
hold({Right = true}, 10); wait(20)
client.screenshot(out .. "sraid32_start4.png")
hold({A = true}, 6); wait(30)
client.screenshot(out .. "sraid32_confirm.png")

client.exit()

-- Recon pass 40: there's a wooden crate/stool prop near the torches wall in
-- Traverse Town -- check if it's an interactive chest (strike with A) that
-- might drop another card.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)
hold({Up=true, Left=true}, 150); wait(10)
-- the crate/table sits a bit further along the wall past the torches;
-- nudge left along the wall toward it
hold({Left = true}, 20); wait(10)
client.screenshot(out .. "sraid40_00.png")
hold({A = true}, 15); wait(30)
client.screenshot(out .. "sraid40_01_strike.png")
hold({Left = true}, 20); wait(10)
client.screenshot(out .. "sraid40_02.png")
hold({A = true}, 15); wait(30)
client.screenshot(out .. "sraid40_03_strike.png")

client.exit()

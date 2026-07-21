-- Recon pass 41: final confirmation -- push hard back through the entrance
-- door (long hold) to see if the game surfaces a "need a card" message, and
-- also strike it with A while standing in the doorway.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)
hold({Down=true, Left=true}, 300); wait(30)
client.screenshot(out .. "sraid41_00_atdoor.png")
hold({A = true}, 20); wait(60)
client.screenshot(out .. "sraid41_01_strike.png")
hold({Down=true, Left=true}, 100); wait(30)
client.screenshot(out .. "sraid41_02_push.png")

client.exit()

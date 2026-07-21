-- Recon pass 30: push DownRight (and UpRight) much further/longer in case
-- the room extends beyond what a 150-frame hold reached, and check for a
-- Room Synthesis trigger by walking into candidate exit spots.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)
hold({Down=true, Right=true}, 300); wait(20)
client.screenshot(out .. "sraid30_downright_long.png")
hold({A = true}, 15); wait(30)
client.screenshot(out .. "sraid30_downright_strike.png")

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)
hold({Up=true, Right=true}, 300); wait(20)
client.screenshot(out .. "sraid30_upright_long.png")
hold({A = true}, 15); wait(30)
client.screenshot(out .. "sraid30_upright_strike.png")

client.exit()

-- Recon pass 36: last checks near the crystal -- try B (jump, per the move
-- tutorial: "B Button: Jump") in case the crystal sits on a ledge reachable
-- only by jumping, and also try holding straight Up (single button, not
-- diagonal) in case the collision grid isn't purely 45-degree.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)
hold({Up=true, Left=true}, 150); wait(10)
client.screenshot(out .. "sraid36_00.png")

hold({B = true}, 10); wait(30)
client.screenshot(out .. "sraid36_jump1.png")
hold({Up=true, B=true}, 20); wait(30)
client.screenshot(out .. "sraid36_jump2.png")

-- single-button Up/Right nudges (not diagonal combo)
hold({Up = true}, 15); wait(10)
client.screenshot(out .. "sraid36_u1.png")
hold({Right = true}, 15); wait(10)
client.screenshot(out .. "sraid36_r1.png")

client.exit()

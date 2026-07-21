-- Recon pass 29: approach the save-point crystal directly and interact (A)
-- -- CoM save points sometimes gate scripted progression.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)
hold({Up=true, Left=true}, 150); wait(10)  -- reach far corner near save point
client.screenshot(out .. "sraid29_00_atcorner.png")

-- nudge toward the crystal (it sat slightly right/below the far corner)
hold({Up=true, Right=true}, 20); wait(10)
client.screenshot(out .. "sraid29_01.png")
hold({A = true}, 15); wait(40)
client.screenshot(out .. "sraid29_02_strike.png")
hold({Down=true, Right=true}, 15); wait(10)
client.screenshot(out .. "sraid29_03.png")
hold({A = true}, 15); wait(40)
client.screenshot(out .. "sraid29_04_strike.png")

savestate.save(out .. "sraid29_progress.State")
wait(3)
client.exit()

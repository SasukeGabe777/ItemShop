-- Recon pass 21: at the dead end near the lamppost/pillar, try striking with
-- A (per the "strike doors with your Keyblade" tutorial) in case this is
-- another closed door needing a hit, not just a wall.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid20_progress.State")
client.screenshot(out .. "sraid21_00.png")

for i = 1, 5 do
  hold({A = true}, 15); wait(20)
  client.screenshot(out .. string.format("sraid21_a%02d.png", i))
end

-- also try Down from here (maybe the corridor turns)
hold({Down = true}, 40); wait(10)
client.screenshot(out .. "sraid21_down1.png")
hold({Down = true}, 40); wait(10)
client.screenshot(out .. "sraid21_down2.png")

savestate.save(out .. "sraid21_progress.State")
wait(3)
client.exit()

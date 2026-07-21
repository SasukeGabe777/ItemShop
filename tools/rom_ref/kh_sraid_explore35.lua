-- Recon pass 35: try walking back OUT through the entrance door (DownLeft,
-- long hold) in case it's a one-way passage forward to a new area rather
-- than backtracking, since this save room seems to have no second door.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)
client.screenshot(out .. "sraid35_00.png")
hold({Down=true, Left=true}, 200); wait(20)
client.screenshot(out .. "sraid35_01_door.png")
hold({Down=true, Left=true}, 100); wait(20)
client.screenshot(out .. "sraid35_02_door.png")

savestate.save(out .. "sraid35_progress.State")
wait(3)
client.exit()

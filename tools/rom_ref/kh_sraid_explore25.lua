-- Recon pass 25: confirmed the movement grid is 45-degree rotated (diagonal
-- d-pad combos = cardinal screen movement: UpLeft=screen-up, UpRight=screen-
-- right, DownRight=screen-down, DownLeft=screen-left). Explore the room
-- properly from the save-point position (sraid24_progress) using this.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid24_progress.State")
client.screenshot(out .. "sraid25_00.png")

local steps = {
  {Up=true, Left=true}, {Up=true, Left=true},
  {Up=true, Right=true}, {Up=true, Right=true},
  {Up=true, Left=true}, {Up=true, Right=true},
  {Down=true, Right=true}, {Up=true, Right=true},
}
local names = {"UL1","UL2","UR1","UR2","UL3","UR3","DR1","UR4"}
for i, c in ipairs(steps) do
  hold(c, 40); wait(8)
  client.screenshot(out .. string.format("sraid25_%02d_%s.png", i, names[i]))
end

savestate.save(out .. "sraid25_progress.State")
wait(3)
client.exit()

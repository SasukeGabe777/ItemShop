-- Recon pass 26: continue mapping the room past the save point -- push
-- further screen-right (UpRight) and screen-up (UpLeft) to find the far
-- edges / any other exits or enemies.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid25_progress.State")

local steps = {
  {Up=true, Right=true}, {Up=true, Right=true}, {Up=true, Right=true},
  {Up=true, Left=true}, {Up=true, Left=true}, {Up=true, Left=true},
  {Up=true, Right=true}, {Up=true, Right=true},
}
local names = {"UR1","UR2","UR3","UL1","UL2","UL3","UR4","UR5"}
for i, c in ipairs(steps) do
  hold(c, 45); wait(8)
  client.screenshot(out .. string.format("sraid26_%02d_%s.png", i, names[i]))
end

savestate.save(out .. "sraid26_progress.State")
wait(3)
client.exit()

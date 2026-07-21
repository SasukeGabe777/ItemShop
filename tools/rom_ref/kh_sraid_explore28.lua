-- Recon pass 28: at each of the 4 room boundaries, strike with A (B for jump
-- also tried) to check for a hidden/disguised second door prompt.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

local dirs = {
  {name="UpLeft", b={Up=true, Left=true}},
  {name="UpRight", b={Up=true, Right=true}},
  {name="DownRight", b={Down=true, Right=true}},
}
for _, d in ipairs(dirs) do
  savestate.load(out .. "sraid14_progress.State")
  hold({A = true}, 6); wait(30)
  hold(d.b, 150); wait(10)
  hold({A = true}, 15); wait(30)
  client.screenshot(out .. string.format("sraid28_%s_strike.png", d.name))
end
client.exit()

-- Recon pass 39: before going through the door, explore the ORIGINAL
-- tutorial-aftermath room more broadly (we beelined for the door before);
-- check other directions for a live enemy we might have skipped past.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

local dirs = {
  {name="DownLeft", b={Down=true, Left=true}},
  {name="DownRight", b={Down=true, Right=true}},
  {name="UpLeft", b={Up=true, Left=true}},
}
for _, d in ipairs(dirs) do
  savestate.load(out .. "sraid9_progress.State")
  hold(d.b, 150); wait(10)
  client.screenshot(out .. string.format("sraid39_%s.png", d.name))
end
client.exit()

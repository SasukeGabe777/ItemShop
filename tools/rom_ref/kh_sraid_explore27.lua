-- Recon pass 27: isolated LONG diagonal holds from the clean room-entry save,
-- one direction per reload, to map the true extent/shape of this room and
-- look for a second door.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

local dirs = {
  {name="UpLeft", b={Up=true, Left=true}},
  {name="UpRight", b={Up=true, Right=true}},
  {name="DownLeft", b={Down=true, Left=true}},
  {name="DownRight", b={Down=true, Right=true}},
}
for _, d in ipairs(dirs) do
  savestate.load(out .. "sraid14_progress.State")
  hold({A = true}, 6); wait(30)
  hold(d.b, 150); wait(10)
  client.screenshot(out .. string.format("sraid27_%s.png", d.name))
end
client.exit()

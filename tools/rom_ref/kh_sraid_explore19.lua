-- Recon pass 19: isolated direction probes from the clean Traverse-Town-entry
-- save (sraid14_progress, right after the room banner), each direction tried
-- independently (reload between) so drift doesn't compound and confuse
-- which way is open floor vs a wall.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

local dirs = {"Up", "Down", "Left", "Right"}
for _, d in ipairs(dirs) do
  savestate.load(out .. "sraid14_progress.State")
  hold({A = true}, 6); wait(30) -- clear any residual banner/text
  local btn = {}
  btn[d] = true
  hold(btn, 70); wait(10)
  client.screenshot(out .. string.format("sraid19_%s.png", d))
end

client.exit()

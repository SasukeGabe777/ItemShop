-- Long-charge probe: hold A for 1200 frames watching for the sustained beam +
-- ki drain the user described, then release with per-frame shots.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz/longcharge/"
local function wait(n) for i = 1, n do emu.frameadvance() end end

wait(300)
savestate.loadslot(0); wait(10)
for i = 1, 1200 do
  joypad.set({ A = true })
  emu.frameadvance()
  if i % 100 == 0 then
    client.screenshot(string.format("%shold_%04d.png", out, i))
  end
end
for i = 1, 40 do
  emu.frameadvance()
  if i % 2 == 0 then
    client.screenshot(string.format("%srel_%02d.png", out, i))
  end
end
client.exit()

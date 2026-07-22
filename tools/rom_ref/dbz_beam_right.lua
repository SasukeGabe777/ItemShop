-- Face-right beam probe: walk right so the beam (if any) travels across open
-- screen, then try charge holds of 60/240/600 frames with per-frame release
-- captures.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz/beamright/"
local function wait(n) for i = 1, n do emu.frameadvance() end end

wait(300)
for _, holdlen in ipairs({ 60, 240, 600 }) do
  savestate.loadslot(0); wait(10)
  for i = 1, 45 do joypad.set({ Right = true }); emu.frameadvance() end
  wait(10)
  for i = 1, holdlen do joypad.set({ A = true }); emu.frameadvance() end
  client.screenshot(string.format("%sh%03d_charged.png", out, holdlen))
  for i = 1, 36 do
    emu.frameadvance()
    if i % 2 == 0 then
      client.screenshot(string.format("%sh%03d_rel_%02d.png", out, holdlen, i))
    end
  end
end
client.exit()

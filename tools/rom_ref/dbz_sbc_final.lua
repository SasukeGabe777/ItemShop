-- SBC capture probe: L x2 selects the beam, face right, then hold B and
-- screenshot EVERY frame from the first held frame (beam drains EP fast, so
-- the visible beam window is early).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz/sbc/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function press(btn, hold)
  hold = hold or 8
  for i = 1, hold do joypad.set({ [btn] = true }); emu.frameadvance() end
  for i = 1, 15 do emu.frameadvance() end
end

wait(300)
savestate.loadslot(0); wait(10)
press("L"); press("L")
for i = 1, 45 do joypad.set({ Right = true }); emu.frameadvance() end
wait(10)
client.screenshot(out .. "before.png")
for i = 1, 90 do
  joypad.set({ B = true })
  emu.frameadvance()
  client.screenshot(string.format("%sb_%03d.png", out, i))
end
client.exit()

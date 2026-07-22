-- L cycles the selected ki attack; B uses it (hold = sustain/charge).
-- Try 0..3 L presses, then hold B, watching for the SBC beam + EP drain.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz/lcycle/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function press(btn, hold)
  hold = hold or 8
  for i = 1, hold do joypad.set({ [btn] = true }); emu.frameadvance() end
  for i = 1, 15 do emu.frameadvance() end
end

wait(300)
for cycles = 0, 3 do
  savestate.loadslot(0); wait(10)
  for c = 1, cycles do press("L") end
  client.screenshot(string.format("%sc%d_after_L.png", out, cycles))
  for i = 1, 150 do
    joypad.set({ B = true })
    emu.frameadvance()
    if i == 30 or i == 90 or i == 150 then
      client.screenshot(string.format("%sc%d_hold_%03d.png", out, cycles, i))
    end
  end
  for i = 1, 30 do
    emu.frameadvance()
    if i % 5 == 0 then
      client.screenshot(string.format("%sc%d_rel_%02d.png", out, cycles, i))
    end
  end
end
client.exit()

-- Does the red powered-up state enable the beam? Enter it (L x2 + hold B),
-- then try tapping/holding B again, per-frame captures.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz/redfire/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function press(btn, hold)
  hold = hold or 8
  for i = 1, hold do joypad.set({ [btn] = true }); emu.frameadvance() end
  for i = 1, 15 do emu.frameadvance() end
end

wait(300)
savestate.loadslot(0); wait(10)
press("L"); press("L")
for i = 1, 70 do joypad.set({ B = true }); emu.frameadvance() end
wait(20)
client.screenshot(out .. "red_state.png")
-- tap B in red state
for i = 1, 8 do joypad.set({ B = true }); emu.frameadvance() end
for i = 1, 40 do
  emu.frameadvance()
  if i % 2 == 0 then client.screenshot(string.format("%stapB_%02d.png", out, i)) end
end
-- tap A in red state
for i = 1, 8 do joypad.set({ A = true }); emu.frameadvance() end
for i = 1, 40 do
  emu.frameadvance()
  if i % 2 == 0 then client.screenshot(string.format("%stapA_%02d.png", out, i)) end
end
client.screenshot(out .. "end_state.png")
client.exit()

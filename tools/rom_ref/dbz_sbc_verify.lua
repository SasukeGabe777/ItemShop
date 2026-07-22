-- Verify the user's new states: slot 7 = mid-beam SBC, slot 8 = char switch,
-- slot 1 = perfect firing spot (SBC preselected; hold B alone fires).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz/sbcv/"
local function wait(n) for i = 1, n do emu.frameadvance() end end

wait(300)

savestate.loadslot(7); wait(2)
client.screenshot(out .. "s7_midbeam.png")
for i = 1, 20 do joypad.set({ B = true }); emu.frameadvance() end
client.screenshot(out .. "s7_midbeam_heldB.png")

savestate.loadslot(8); wait(5)
client.screenshot(out .. "s8_charswitch.png")

savestate.loadslot(1); wait(10)
client.screenshot(out .. "s1_start.png")
for i = 1, 120 do
  joypad.set({ B = true })
  emu.frameadvance()
  if i % 10 == 0 then
    client.screenshot(string.format("%ss1_holdB_%03d.png", out, i))
  end
end
client.exit()

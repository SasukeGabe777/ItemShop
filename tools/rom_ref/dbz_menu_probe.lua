-- Menu probe: what does Start (pause menu) and Select do in-game? Looking for
-- a ki-attack equip screen (suspect the equipped attack isn't SBC).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz/menuprobe/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function press(btn, hold)
  hold = hold or 10
  for i = 1, hold do joypad.set({ [btn] = true }); emu.frameadvance() end
  for i = 1, 20 do emu.frameadvance() end
end

wait(300)

-- Select button first
savestate.loadslot(0); wait(10)
press("Select")
client.screenshot(out .. "select_1.png")
press("Select")
client.screenshot(out .. "select_2.png")

-- Start menu walk
savestate.loadslot(0); wait(10)
press("Start"); wait(30)
client.screenshot(out .. "start_0.png")
press("Right"); client.screenshot(out .. "start_right1.png")
press("Right"); client.screenshot(out .. "start_right2.png")
press("Right"); client.screenshot(out .. "start_right3.png")
press("Down"); client.screenshot(out .. "start_down1.png")
press("A"); wait(20); client.screenshot(out .. "start_a.png")
client.exit()

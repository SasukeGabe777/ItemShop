-- Directive: check if BizHawk quicksave slot 8 is genuinely the character-
-- switch screen (session-2 handoff note). Load fresh, screenshot, try
-- Left/Right + A to see if Goku is selectable.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/slot8/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function tap(btn, n)
  n = n or 10
  for i = 1, n do joypad.set({ [btn] = true }); emu.frameadvance() end
  for i = 1, 15 do emu.frameadvance() end
end

wait(300)
local ok = savestate.loadslot(8)
wait(20)
client.screenshot(out .. "t00_fresh_load.png")
wait(60)
client.screenshot(out .. "t01_settle.png")
tap("Right")
client.screenshot(out .. "t02_right1.png")
tap("Right")
client.screenshot(out .. "t03_right2.png")
tap("Right")
client.screenshot(out .. "t04_right3.png")
tap("Down")
client.screenshot(out .. "t05_down1.png")
tap("A")
wait(30)
client.screenshot(out .. "t06_after_a.png")
client.exit()

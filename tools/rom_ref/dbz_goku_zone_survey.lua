-- Survey MAP TEST zones 0..24 (area=1, variation=0 defaults) via soft-reset
-- between each, looking for a Goku-controllable open area.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/survey/"
local FLAG = 0x0202B32D
local function poke() memory.write_u8(FLAG, 0x02, "System Bus") end
local function step(n, buttons)
  for i = 1, n do
    if buttons then joypad.set(buttons) end
    poke()
    emu.frameadvance()
  end
end
local function tap(btn, n)
  n = n or 10
  for i = 1, n do joypad.set({ [btn] = true }); poke(); emu.frameadvance() end
  for i = 1, 15 do poke(); emu.frameadvance() end
end
local function to_debug()
  step(600)
  for i = 1, 8 do
    step(90, { Start = true })
    step(90)
  end
end
local function soft_reset()
  step(60, { Start = true, Select = true, A = true, B = true })
end

for zone = 0, 24 do
  to_debug()
  tap("Down"); tap("Down")           -- land on ZONE (default value 1)
  if zone == 0 then
    tap("Left")
  else
    for i = 1, zone - 1 do tap("Right") end
  end
  tap("A")
  step(150)
  client.screenshot(string.format("%sz%02d.png", out, zone))
  soft_reset()
end

client.exit()

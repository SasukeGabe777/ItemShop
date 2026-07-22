-- Probe the DEBUG menu fully: scroll down through all rows, screenshot each,
-- to find where character selection lives (MAP TEST warps zone/area/variation
-- but session 2 notes "all 6 characters" -- need to see how).
-- Reuses the EXACT proven bring-up sequence from dbz_testmenu.lua.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/"
local FLAG = 0x0202B32D
local function poke() memory.write_u8(FLAG, 0x02, "System Bus") end
local function step(n, buttons)
  for i = 1, n do
    if buttons then joypad.set(buttons) end
    poke()
    emu.frameadvance()
  end
end

step(500)
step(700, { Start = true })
step(120)
step(60, { Start = true })
step(90)
client.screenshot(out .. "m00_debug_top.png")

local function tap(btn, n)
  n = n or 10
  for i = 1, n do joypad.set({ [btn] = true }); poke(); emu.frameadvance() end
  for i = 1, 15 do poke(); emu.frameadvance() end
end

for i = 1, 8 do
  tap("Down")
  client.screenshot(string.format("%sm01_down_%d.png", out, i))
end

client.exit()

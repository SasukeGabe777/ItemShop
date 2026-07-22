-- Address 0x02038EBC(EWRAM)/0x03000E90(IWRAM) confirmed LIVE: poking it
-- changes the field character/HUD (0xFF produced a garbage Super-Saiyan-
-- looking corrupted sprite -- out of range for THIS save's roster array).
-- The value->character mapping is presumably relative to THIS save's own
-- party array (which differs from slot8's), so sweep 0..4 directly on our
-- Goku-alive cold-boot save and look at each.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/valuesweep/"
local FLAG = 0x0202B32D
local EW = 0x02038EBC
local IW = 0x03000E90
local function make_poke(v)
  return function()
    memory.write_u8(FLAG, 0x02, "System Bus")
    memory.write_u8(EW, v, "System Bus")
    memory.write_u8(IW, v, "System Bus")
  end
end
local function step(n, buttons, poker)
  for i = 1, n do
    if buttons then joypad.set(buttons) end
    poker()
    emu.frameadvance()
  end
end
local function tap(btn, n, poker)
  n = n or 10
  for i = 1, n do joypad.set({ [btn] = true }); poker(); emu.frameadvance() end
  for i = 1, 15 do poker(); emu.frameadvance() end
end
local function to_debug(poker)
  step(600, nil, poker)
  for i = 1, 8 do
    step(90, { Start = true }, poker)
    step(90, nil, poker)
  end
end
local function soft_reset(poker)
  step(60, { Start = true, Select = true, A = true, B = true }, poker)
end

for v = 0, 4 do
  local poker = make_poke(v)
  to_debug(poker)
  tap("Down", 10, poker); tap("Down", 10, poker)
  tap("Right", 10, poker)   -- zone2
  tap("A", 10, poker)
  step(150, nil, poker)
  client.screenshot(string.format("%sval%d.png", out, v))
  soft_reset(poker)
end

client.exit()

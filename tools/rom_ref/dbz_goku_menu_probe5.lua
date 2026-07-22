-- Bulletproof debug bring-up: repeated Start taps (Start is a no-op once
-- already inside the DEBUG list, confirmed safe) to absorb timing jitter in
-- how long the intro/logo sequence takes before the title screen appears.
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

local function to_debug()
  step(600)
  for i = 1, 8 do
    step(90, { Start = true })
    step(90)
  end
end

to_debug()
client.screenshot(out .. "p5_00_debug.png")
client.exit()

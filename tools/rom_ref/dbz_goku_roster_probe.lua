-- Warp to East District (zone2, open Piccolo map), open Start->Status, cycle
-- the full party roster with Right, screenshot each. Then try A on a non-
-- Piccolo entry to see if it swaps field control.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/roster/"
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

to_debug()
tap("Down"); tap("Down")           -- ZONE field, default 1
tap("Right")                        -- zone = 2 (East District 439)
tap("A")
step(150)
client.screenshot(out .. "r00_ingame.png")

tap("Start")
step(20)
client.screenshot(out .. "r01_start_menu.png")

for i = 1, 7 do
  tap("Right")
  client.screenshot(string.format("%sr02_right_%d.png", out, i))
end
-- wrap check: keep going a couple more to confirm cycle length
for i = 8, 9 do
  tap("Right")
  client.screenshot(string.format("%sr02_right_%d.png", out, i))
end

-- try A on whoever is currently shown (see if it does anything -- swap/select)
tap("A")
step(20)
client.screenshot(out .. "r03_after_a.png")
step(60)
client.screenshot(out .. "r04_after_a_settle.png")

client.exit()

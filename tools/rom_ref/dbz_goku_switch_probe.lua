-- Land on Goku's STATUS entry (4x Right from Piccolo), try A (select/switch?),
-- then close the menu (Start/B) and check who's controllable in the field.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/switch/"
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
tap("Down"); tap("Down")
tap("Right")            -- zone = 2 (East District 439, open area)
tap("A")
step(150)

tap("Start"); step(20)
for i = 1, 4 do tap("Right") end
client.screenshot(out .. "s00_on_goku.png")
tap("A")
step(20)
client.screenshot(out .. "s01_after_a.png")

-- try B to back out / close menu
tap("B")
step(20)
client.screenshot(out .. "s02_after_b.png")
tap("B")
step(20)
client.screenshot(out .. "s03_after_b2.png")
step(60)
client.screenshot(out .. "s04_settle.png")

-- move to see who's on screen / controllable
for i = 1, 30 do joypad.set({ Down = true }); poke(); emu.frameadvance() end
client.screenshot(out .. "s05_walk_down.png")
for i = 1, 30 do joypad.set({ Right = true }); poke(); emu.frameadvance() end
client.screenshot(out .. "s06_walk_right.png")

client.exit()

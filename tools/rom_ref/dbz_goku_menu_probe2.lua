-- From DEBUG menu, move into the MAP TEST block (Down x2 lands on ZONE),
-- try Right/Left on ZONE, then A to see if it warps (and with which char).
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
local function tap(btn, n)
  n = n or 10
  for i = 1, n do joypad.set({ [btn] = true }); poke(); emu.frameadvance() end
  for i = 1, 15 do poke(); emu.frameadvance() end
end

step(500)
step(700, { Start = true })
step(120)
step(60, { Start = true })
step(90)

tap("Down"); tap("Down")  -- land on ZONE field of MAP TEST block
client.screenshot(out .. "p2_00_atzone.png")
tap("Right")
client.screenshot(out .. "p2_01_zone_right1.png")
tap("Right")
client.screenshot(out .. "p2_02_zone_right2.png")
tap("Left")
client.screenshot(out .. "p2_03_zone_left1.png")
tap("A")
client.screenshot(out .. "p2_04_after_a.png")
step(60)
client.screenshot(out .. "p2_05_after_a_settle.png")
client.exit()

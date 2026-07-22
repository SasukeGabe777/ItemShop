-- Robust debug bring-up + test ZONE Right/Left + A to warp (zone=1 default).
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

local function to_debug()
  step(600)
  step(900, { Start = true })
  step(200)
  step(90, { Start = true })
  step(150)
end

to_debug()
client.screenshot(out .. "p4_00_debug.png")
tap("Down"); tap("Down")
client.screenshot(out .. "p4_01_zone1.png")
tap("Right")
client.screenshot(out .. "p4_02_zone2.png")
tap("A")
step(30)
client.screenshot(out .. "p4_03_after_a.png")
step(90)
client.screenshot(out .. "p4_04_settle.png")
step(120)
client.screenshot(out .. "p4_05_settle2.png")
client.exit()

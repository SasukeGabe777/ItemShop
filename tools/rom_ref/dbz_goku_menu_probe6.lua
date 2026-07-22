-- Test ZONE Right/Left + A-confirm warp, using the bulletproof to_debug().
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
  for i = 1, 8 do
    step(90, { Start = true })
    step(90)
  end
end

to_debug()
tap("Down"); tap("Down")           -- land on ZONE
client.screenshot(out .. "p6_00_zone1.png")
tap("Right")
client.screenshot(out .. "p6_01_zone2.png")
tap("A")
step(60)
client.screenshot(out .. "p6_02_after_a.png")
step(90)
client.screenshot(out .. "p6_03_settle.png")
client.exit()

-- Test GBA soft-reset (Start+Select+A+B) from in-game back to boot, to allow
-- surveying multiple MAP TEST zones inside one BizHawk process (faster than
-- relaunching per zone).
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
tap("Down"); tap("Down")           -- land on ZONE (default value 1)
tap("A")
step(90)
client.screenshot(out .. "p8_00_zone1_ingame.png")

-- soft reset
step(60, { Start = true, Select = true, A = true, B = true })
step(200)
client.screenshot(out .. "p8_01_after_softreset.png")
step(400)
client.screenshot(out .. "p8_02_after_softreset_wait.png")
client.exit()

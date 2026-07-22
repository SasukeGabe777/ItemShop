-- Warp at ZONE 1 (default) to see which character/map that is.
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
client.screenshot(out .. "p7_00_zone1.png")
tap("A")
step(60)
client.screenshot(out .. "p7_01_after_a.png")
step(90)
client.screenshot(out .. "p7_02_settle.png")
-- take a couple steps to see the character clearly / confirm control
for i = 1, 20 do joypad.set({ Down = true }); poke(); emu.frameadvance() end
client.screenshot(out .. "p7_03_walk.png")
client.exit()

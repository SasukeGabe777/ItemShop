-- Verify: poke EWRAM 0x020000B0 = 0 (Goku) every frame from power-on,
-- alongside the debug flag, warp to zone2 (East District 439, open area),
-- confirm the field character is Goku and responds to movement. If the
-- sprite doesn't change, soft-reset and re-warp (character may bind on map
-- load, so poking before/through the warp should be enough, but allow a
-- couple of variations per the coordinator's cap).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/charpoke/"
local FLAG = 0x0202B32D
local CHAR = 0x020000B0
local function poke()
  memory.write_u8(FLAG, 0x02, "System Bus")
  memory.write_u8(CHAR, 0x00, "System Bus")
end
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
local function hold(btns, n)
  for i = 1, n do joypad.set(btns); poke(); emu.frameadvance() end
end
local function to_debug()
  step(600)
  for i = 1, 8 do
    step(90, { Start = true })
    step(90)
  end
end
local function soft_reset()
  step(60, { Start = true, Select = true, A = true, B = true })
end

local function warp_zone2()
  to_debug()
  tap("Down"); tap("Down")
  tap("Right")            -- zone2 (East District 439)
  tap("A")
  step(150)
end

-- attempt 1
warp_zone2()
client.screenshot(out .. "v1_00_after_warp.png")
hold({ Down = true }, 20)
client.screenshot(out .. "v1_01_walk_down.png")
hold({ Right = true }, 20)
client.screenshot(out .. "v1_02_walk_right.png")

-- attempt 2: soft reset + re-warp (in case char binds before poke settles)
soft_reset()
warp_zone2()
client.screenshot(out .. "v2_00_after_warp.png")
hold({ Down = true }, 20)
client.screenshot(out .. "v2_01_walk_down.png")

-- attempt 3: zone3 (Northern Wastelands) instead, fresh soft reset
soft_reset()
to_debug()
tap("Down"); tap("Down")
tap("Right"); tap("Right")   -- zone3
tap("A")
step(150)
client.screenshot(out .. "v3_00_zone3.png")
hold({ Down = true }, 20)
client.screenshot(out .. "v3_01_walk_down.png")

client.exit()

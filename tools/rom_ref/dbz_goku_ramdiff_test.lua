-- Test best-ranked candidate from the slot-8 3-way diff (Gohan=1,Vegeta=3,
-- Trunks=4 mapping): a pair of addresses (EWRAM + IWRAM, same relative
-- values in both banks) reading charID+9 -- EWRAM 0x0203926A, IWRAM
-- 0x03006C9A. To force GOKU (id=0) poke value = 9 at both.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/ramdifftest/"
local FLAG = 0x0202B32D
local EW = 0x0203926A
local IW = 0x03006C9A
local function poke_all()
  memory.write_u8(FLAG, 0x02, "System Bus")
  memory.write_u8(EW, 9, "System Bus")
  memory.write_u8(IW, 9, "System Bus")
end
local function poke_debug_only()
  memory.write_u8(FLAG, 0x02, "System Bus")
end
local function step(n, buttons, poker)
  poker = poker or poke_all
  for i = 1, n do
    if buttons then joypad.set(buttons) end
    poker()
    emu.frameadvance()
  end
end
local function tap(btn, n, poker)
  poker = poker or poke_all
  n = n or 10
  for i = 1, n do joypad.set({ [btn] = true }); poker(); emu.frameadvance() end
  for i = 1, 15 do poker(); emu.frameadvance() end
end
local function hold(btns, n, poker)
  poker = poker or poke_all
  for i = 1, n do joypad.set(btns); poker(); emu.frameadvance() end
end
local function to_debug(poker)
  poker = poker or poke_all
  step(600, nil, poker)
  for i = 1, 8 do
    step(90, { Start = true }, poker)
    step(90, nil, poker)
  end
end
local function soft_reset(poker)
  poker = poker or poke_all
  step(60, { Start = true, Select = true, A = true, B = true }, poker)
end

-- Variant 1: poke continuously from power-on through the warp
to_debug(poke_all)
tap("Down", 10, poke_all); tap("Down", 10, poke_all)
tap("Right", 10, poke_all)   -- zone2
tap("A", 10, poke_all)
step(150, nil, poke_all)
client.screenshot(out .. "v1_after_warp.png")
hold({ Down = true }, 20, poke_all)
client.screenshot(out .. "v1_walk.png")

-- Variant 2: boot/navigate WITHOUT poking the char bytes (only debug flag),
-- then poke once (continuously for a short burst) only AFTER the warp
-- settles, in case the byte is read once at map-load time and a poke that's
-- active too early gets clobbered by the load itself.
soft_reset(poke_debug_only)
to_debug(poke_debug_only)
tap("Down", 10, poke_debug_only); tap("Down", 10, poke_debug_only)
tap("Right", 10, poke_debug_only)
tap("A", 10, poke_debug_only)
step(150, nil, poke_debug_only)
client.screenshot(out .. "v2_before_poke.png")
step(30, nil, poke_all)   -- NOW start poking, post-load
client.screenshot(out .. "v2_after_poke.png")
hold({ Down = true }, 20, poke_all)
client.screenshot(out .. "v2_walk.png")

client.exit()

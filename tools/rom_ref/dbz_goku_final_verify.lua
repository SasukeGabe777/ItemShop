-- Fresh, from-scratch verification (per coordinator: don't trust the prior
-- interrupted run). Steps:
--  1. Boot cold, to_debug(), warp zone2 WITHOUT the char poke -- confirm
--     baseline (Piccolo) still works, i.e. SaveRAM is intact/not clobbered.
--  2. Start->Status, cycle to Goku's entry -- confirm he's still Lv40/alive
--     in the roster (SaveRAM sanity check).
--  3. Close menu, THEN start poking EWRAM 0x02038EBC / IWRAM 0x03000E90 = 4
--     continuously, re-warp zone2, confirm GOKU renders and walks in all
--     4 directions under input.
--  4. If confirmed, save the anchor state to savestates/goku_capture.State.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/finalverify/"
local FLAG = 0x0202B32D
local EW = 0x02038EBC
local IW = 0x03000E90
local GOKU_VAL = 4

local function poke_debug_only()
  memory.write_u8(FLAG, 0x02, "System Bus")
end
local function poke_goku()
  memory.write_u8(FLAG, 0x02, "System Bus")
  memory.write_u8(EW, GOKU_VAL, "System Bus")
  memory.write_u8(IW, GOKU_VAL, "System Bus")
end

local function step(n, buttons, poker)
  for i = 1, n do
    if buttons then joypad.set(buttons) end
    poker()
    emu.frameadvance()
  end
end
local function tap(btn, n, poker)
  n = n or 10
  for i = 1, n do joypad.set({ [btn] = true }); poker(); emu.frameadvance() end
  for i = 1, 15 do poker(); emu.frameadvance() end
end
local function hold(btns, n, poker)
  for i = 1, n do joypad.set(btns); poker(); emu.frameadvance() end
end
local function to_debug(poker)
  step(600, nil, poker)
  for i = 1, 8 do
    step(90, { Start = true }, poker)
    step(90, nil, poker)
  end
end
local function soft_reset(poker)
  step(60, { Start = true, Select = true, A = true, B = true }, poker)
end

-- Step 1+2: baseline sanity check with debug-flag-only poking (no char poke)
to_debug(poke_debug_only)
tap("Down", 10, poke_debug_only); tap("Down", 10, poke_debug_only)
tap("Right", 10, poke_debug_only)   -- zone2, East District 439
tap("A", 10, poke_debug_only)
step(150, nil, poke_debug_only)
client.screenshot(out .. "s1_baseline_piccolo.png")

tap("Start", 10, poke_debug_only)
step(20, nil, poke_debug_only)
for i = 1, 4 do tap("Right", 10, poke_debug_only) end  -- Piccolo->Vegeta->Trunks->Goku
client.screenshot(out .. "s2_status_goku_check.png")
tap("B", 10, poke_debug_only)  -- close status/back out
step(20, nil, poke_debug_only)
tap("B", 10, poke_debug_only)  -- close start menu fully
step(20, nil, poke_debug_only)

-- Step 3: now poke Goku's value continuously; MUST soft-reset first (the
-- debug menu is only reachable from a fresh boot/reset, not mid-gameplay)
soft_reset(poke_goku)
to_debug(poke_goku)
tap("Down", 10, poke_goku); tap("Down", 10, poke_goku)
tap("Right", 10, poke_goku)   -- zone2 again
tap("A", 10, poke_goku)
step(150, nil, poke_goku)
client.screenshot(out .. "s3_goku_after_warp.png")

hold({ Down = true }, 20, poke_goku)
client.screenshot(out .. "s4_walk_down.png")
hold({ Right = true }, 20, poke_goku)
client.screenshot(out .. "s5_walk_right.png")
hold({ Up = true }, 20, poke_goku)
client.screenshot(out .. "s6_walk_up.png")
hold({ Left = true }, 20, poke_goku)
client.screenshot(out .. "s7_walk_left.png")

-- Step 4: save the anchor state (still poking every frame up to the save)
savestate.save("C:\\Users\\Game Station\\Desktop\\crossroads\\savestates\\goku_capture.State")
client.screenshot(out .. "s8_saved.png")

client.exit()

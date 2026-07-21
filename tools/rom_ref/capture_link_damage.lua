-- Heart-HUD damage states. Correction found this session: Minish Cap's HP
-- hearts are NOT OAM sprite objects (decode_oam.py's pal-0 8x8 HUD objects
-- turned out to be sword/shield/R-button icons, not hearts -- a fresh check
-- of oam_idn_00.bin found only one stray pal-0 16x16 object, no heart row).
-- The hearts are rendered on BG0 (proven this session: bg0_ranch_fence.png
-- from the barrier tour is a clean full-HP heart row on transparency). So
-- this capture reuses the BG-dump pattern from capture_barriers_zelda.lua
-- (dumpmem VRAM+PALRAM+regs+screenshot) instead of the OAM pattern.
--
-- Route: reproduce the proven south-then-east path from
-- capture_barriers_zelda_fields.lua (direct east-from-spawn forks into a
-- hedge gate; going south-and-back first is what actually reaches the
-- ranch_fence hedge/crop-garden, which has a red Octorok nearby in every
-- screenshot from that site) to a spot near the Octorok, then bump into it
-- repeatedly, dumping BG state at intervals to catch each HP drop.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/bg/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

local function dumpmem(addr, len, domain, path)
  local t = memory.readbyterange(addr, len, domain)
  local base = (t[0] ~= nil) and 0 or 1
  local chars = {}
  for i = 0, len - 1 do chars[i + 1] = string.char(t[base + i]) end
  local f = io.open(path, "wb"); f:write(table.concat(chars)); f:close()
end

local function dumpsite(tag)
  dumpmem(0, 0x10000, "VRAM", out .. "bgvram_" .. tag .. ".bin")
  dumpmem(0, 0x200, "PALRAM", out .. "bgpal_" .. tag .. ".bin")
  local f = io.open(out .. "regs_" .. tag .. ".txt", "w")
  f:write(string.format("DISPCNT 0x%04X\n", memory.read_u16_le(0x04000000, "System Bus")))
  for n = 0, 3 do
    f:write(string.format("BG%dCNT 0x%04X\n", n, memory.read_u16_le(0x04000008 + n * 2, "System Bus")))
  end
  f:close()
  client.screenshot(out .. "shot_" .. tag .. ".png")
end

-- title -> file select -> select File 1 -> clear cutscene -> free-roam
wait(900)
hold({Start = true}, 30); wait(150)
hold({A = true}, 6); wait(60); hold({A = true}, 6); wait(90); hold({A = true}, 6); wait(120)
for j = 0, 34 do hold({A = true}, 4); wait(18) end
wait(60)

dumpsite("dmg_full")  -- baseline: full hearts, for confirmation

-- south leg (there and back) -- required fork to reach the ranch via east
for i = 1, 10 do hold({Down = true}, 120); wait(10) end
for i = 1, 10 do hold({Up = true}, 120); wait(10) end
wait(10)

-- east to the ranch_fence hedge/crop-garden (Octorok visible there)
for i = 1, 7 do hold({Right = true}, 120); wait(10) end
dumpsite("dmg_arrive")

-- bump into the Octorok repeatedly: hold Right/Up/Down alternately in short
-- bursts (it may be slightly off the direct line), dumping BG state after
-- each burst so we catch the HP row at each distinct damage step.
for burst = 1, 6 do
  hold({Right = true}, 30)
  hold({Up = true}, 10)
  hold({Right = true}, 20)
  wait(15)
  dumpsite("dmg_hit" .. burst)
end

client.exit()

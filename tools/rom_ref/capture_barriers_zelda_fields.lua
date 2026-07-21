-- Barrier identification tour part 2 (Minish Cap): Lon Lon Ranch / Hyrule
-- Field sites, reached via recon_fields_zelda.lua's confirmed routes (2/4/7
-- holds-of-120-frames east = flower planter / ranch sign / ranch fence,
-- 2 holds north = field hedge maze, 10 holds south = South Hyrule Field
-- entrance hedges). Same dump format as capture_barriers_zelda.lua so
-- decode_bg.py picks these up automatically (fresh tags, no collisions).
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

local function probe_edge(dir, tag)
  client.screenshot(out .. "edge_" .. tag .. "_before.png")
  hold(dir, 45)
  client.screenshot(out .. "edge_" .. tag .. "_after.png")
end

-- title -> file select -> select File 1 -> clear cutscene -> free-roam
wait(900)
hold({Start = true}, 30); wait(150)
hold({A = true}, 6); wait(60); hold({A = true}, 6); wait(90); hold({A = true}, 6); wait(120)
for j = 0, 34 do hold({A = true}, 4); wait(18) end
wait(60)

-- Mirror recon_fields_zelda.lua's EXACT leg order/timing (south-there-and-
-- back fully, THEN east, THEN north) -- proven this session that a direct
-- east-from-spawn walk forks differently (hits a hedge-flanked gate near
-- town) than the path recon took after the south round-trip. Reproducing
-- recon's path bit-for-bit is what actually reaches Lon Lon Ranch.

-- Leg 1: south, all the way to South Hyrule Field (recon r_south_10), then
-- fully back, matching recon's r_south_* / r_back1.
for i = 1, 10 do
  hold({Down = true}, 120); wait(10)
  if i == 10 then
    dumpsite("south_field")
    probe_edge({Left = true}, "south_field_left")
  end
end
for i = 1, 10 do hold({Up = true}, 120); wait(10) end
wait(10)

-- Leg 2: east toward Lon Lon Ranch (recon r_east_2 planter/hedge gate,
-- r_east_4 ranch sign, r_east_7 fence + haystacks).
for i = 1, 10 do
  hold({Right = true}, 120); wait(10)
  if i == 2 then
    dumpsite("field_planter")
    probe_edge({Down = true}, "field_planter_down")
  elseif i == 4 then
    dumpsite("ranch_gate")
    probe_edge({Down = true}, "ranch_gate_down")
  elseif i == 7 then
    dumpsite("ranch_fence")
    probe_edge({Right = true}, "ranch_fence_right")
  end
end
for i = 1, 10 do hold({Left = true}, 120); wait(10) end
wait(10)

-- Leg 3: north into the Hyrule Field hedge maze (recon r_north_2 corner).
for i = 1, 2 do
  hold({Up = true}, 120); wait(10)
  if i == 2 then
    dumpsite("field_hedge")
    probe_edge({Left = true}, "field_hedge_left")
  end
end

client.exit()

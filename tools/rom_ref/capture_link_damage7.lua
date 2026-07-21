-- Heart damage, take 7: dmg6's brown-critter/Octorok retargeting both missed
-- (overworld routing keeps landing on empty patches -- confirmed non-
-- deterministic run to run, per damage2.lua's note). Two new angles this run,
-- in one pass: (1) recon_south_far's sf_01 screenshot showed a red Octorok
-- close by right after the FIRST 90-frame Down leg into the field -- previous
-- attempts always closed to point-blank adjacency, which may be inside its
-- "too close to spit" band; this time stop short at a few tiles' range and
-- just wait facing it. (2) the wavy light-green tall-grass patches seen at
-- sf_06..sf_15 are the kind of cover Ropes (grass snakes) hide in across
-- Zelda games -- walk back and forth through that grass for a long stretch to
-- flush one out.
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

wait(900)
hold({Start = true}, 30); wait(150)
hold({A = true}, 6); wait(60); hold({A = true}, 6); wait(90); hold({A = true}, 6); wait(120)
for j = 0, 34 do hold({A = true}, 4); wait(18) end
wait(60)

-- reach South Hyrule Field (proven route)
for i = 1, 10 do hold({Down = true}, 120); wait(10) end

-- leg 1 (matches recon: sf_01 showed a red Octorok close by, up-right)
hold({Down = true}, 90); wait(10)
dumpsite("dmg7_oct_spot")
-- keep a little distance (don't close to adjacency) and just watch, facing it
for i = 0, 14 do
  wait(10)
  dumpsite(string.format("dmg7_oct_wait%02d", i))
end

-- push on into the tall-grass patches (legs 2-8, matching recon_south_far)
local legs = {
  {Down = true}, {Left = true}, {Down = true}, {Down = true}, {Right = true},
  {Down = true}, {Down = true},
}
for _, dir in ipairs(legs) do
  hold(dir, 90); wait(10)
end
dumpsite("dmg7_grass_arrive")

-- oscillate through the grass to flush anything hiding in it
for i = 0, 9 do
  hold({Down = true}, 20)
  hold({Up = true}, 20)
  dumpsite(string.format("dmg7_grass%02d", i))
end

client.exit()

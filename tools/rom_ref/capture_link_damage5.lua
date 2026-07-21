-- Heart damage, take 5 (final attempt): the ranch-area Octorok has ignored
-- ~450 combined frames of contact/proximity across 3 prior attempts with no
-- HP change -- it may simply be a passive decorative critter here, not a
-- hostile spawn. Last try: close to true overlap and mash B (sword) several
-- times in case it needs to be actively attacked before it retaliates/spits.
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

for i = 1, 10 do hold({Down = true}, 120); wait(10) end

local dirs = {{Down = true}, {Down = true}, {Left = true}, {Down = true}, {Right = true}}
for i = 1, 12 do
  hold(dirs[(i % 5) + 1], 40)
end
-- dmg3_close position: Octorok adjacent upper-right. Close the last step in.
hold({Up = true}, 8); hold({Right = true}, 8)
dumpsite("dmg5_contact")

for swing = 1, 8 do
  hold({B = true}, 8)
  wait(20)
  dumpsite(string.format("dmg5_sw%02d", swing))
end

client.exit()

-- Heart damage, take 4: adjacency alone (dmg3, 200 frames touching the
-- Octorok) produced zero HP change -- Minish Cap Octoroks likely only damage
-- via their spat rock at range, not contact. This run: reproduce the same
-- proven approach, then back off a couple tiles instead of closing in, wait
-- long enough for it to notice and spit, and also try a sword tap partway
-- through in case it counter-attacks when hurt.
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
-- this is the point where dmg3_close showed the Octorok adjacent, upper-right

-- back off to the left to open some distance instead of closing in
hold({Left = true}, 24)
dumpsite("dmg4_backoff")

-- swing the sword once (B), then hold still and watch for a long stretch --
-- dump every 6 frames so a brief rock-hit is not missed between samples.
hold({B = true}, 6)
for i = 0, 39 do
  wait(6)
  dumpsite(string.format("dmg4_w%02d", i))
end

client.exit()

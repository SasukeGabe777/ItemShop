-- Heart damage states, take 2: the south-then-east route to the ranch forked
-- to a different (empty) part of the map this run (no Octorok on-screen in
-- any of 6 bump bursts, hearts stayed full) -- overworld routing has proven
-- non-deterministic run-to-run all session. Pivot to the plain south leg
-- instead, which has landed at "South Hyrule Field" reliably twice now, then
-- wander further into the field (varying direction) for a longer stretch to
-- actually find an Octorok and its rock projectile.
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

-- south leg to South Hyrule Field (proven reliable)
for i = 1, 10 do hold({Down = true}, 120); wait(10) end
dumpsite("dmg2_field")

-- wander further into the field looking for an Octorok, dumping every ~1s
for i = 1, 20 do
  local dirs = {{Down = true}, {Down = true}, {Left = true}, {Down = true}, {Right = true}}
  hold(dirs[(i % 5) + 1], 40)
  dumpsite(string.format("dmg2_w%02d", i))
end

client.exit()

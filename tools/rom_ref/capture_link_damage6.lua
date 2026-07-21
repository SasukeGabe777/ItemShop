-- Heart damage, take 6: prior attempts (damage.lua..damage5.lua) all engaged
-- the Lon Lon Ranch red Octorok (east leg) or a South Hyrule Field Octorok
-- via pure contact/waiting -- neither ever attacked (rock-spit requires range
-- and never triggered; contact does nothing). recon_south_far.lua scouted a
-- NEW spot: pushing further south past the hedge row (sf_08/sf_12 screenshots)
-- turned up small brown ground critters neither prior attempt tried. This run
-- reproduces that exact route (same leg table) then actively closes on and
-- sword-taps those critters, dumping BG hearts throughout. If they're also
-- inert, falls back to sword-swinging the South Hyrule Field Octorok (never
-- attacked with a blade before, only walked into).
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

-- reproduce recon_south_far.lua's leg table through leg 12 (sf_12 showed two
-- small brown critters just below/left of Link, past the hedge row)
local legs = {
  {Down = true}, {Down = true}, {Down = true}, {Left = true}, {Down = true},
  {Down = true}, {Right = true}, {Down = true}, {Down = true}, {Left = true},
  {Down = true}, {Down = true},
}
for _, dir in ipairs(legs) do
  hold(dir, 90); wait(10)
end
dumpsite("dmg6_arrive")

-- close in on the critters (down-left of Link in sf_12) and sword-tap
hold({Left = true}, 16); hold({Down = true}, 20)
dumpsite("dmg6_close")
for swing = 1, 6 do
  hold({B = true}, 8)
  wait(16)
  dumpsite(string.format("dmg6_sw%02d", swing))
end

-- linger and watch for an active approach/attack
for i = 0, 19 do
  wait(8)
  dumpsite(string.format("dmg6_wait%02d", i))
end

-- fallback: track toward the South Hyrule Field Octorok (was visible a few
-- screens back toward the entrance, sf_01/sf_03) and sword-swing it instead
hold({Up = true}, 60); hold({Right = true}, 30)
dumpsite("dmg6_oct_arrive")
for swing = 1, 6 do
  hold({B = true}, 8)
  wait(16)
  dumpsite(string.format("dmg6_octsw%02d", swing))
end

client.exit()

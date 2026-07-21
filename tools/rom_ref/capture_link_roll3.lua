-- Link's ROLL, take 3: rup_* (roll2 script) rolled UP straight from spawn and
-- got bleached by a map-transition white fade -- rolling up from spawn crosses
-- into North Hyrule Field within a few tiles. Fix: walk DOWN first (away from
-- that transition, deeper into the town-square courtyard, proven open ground
-- by capture_barriers_zelda.lua's "south" leg and every south_* screenshot),
-- so the subsequent up-roll has a clear ~5+ tile runway with no transition
-- above it. Then roll UP (R+Up) and dump every frame for 30 frames, tag ru2.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/oam/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

local function dumpmem(addr, len, domain, path)
  local t = memory.readbyterange(addr, len, domain)
  local base = (t[0] ~= nil) and 0 or 1
  local chars = {}
  for i = 0, len - 1 do chars[i + 1] = string.char(t[base + i]) end
  local f = io.open(path, "wb"); f:write(table.concat(chars)); f:close()
end

local function dumpframe(tag)
  dumpmem(0, 1024, "OAM", out .. "oam_" .. tag .. ".bin")
  dumpmem(0x10000, 0x8000, "VRAM", out .. "objvram_" .. tag .. ".bin")
  dumpmem(0x200, 0x200, "PALRAM", out .. "objpal_" .. tag .. ".bin")
  client.screenshot(out .. "ref_" .. tag .. ".png")
end

local function holddump(b, tag, n)
  for i = 0, n - 1 do
    joypad.set(b)
    emu.frameadvance()
    dumpframe(string.format("%s_%02d", tag, i))
  end
end

-- title -> file select -> select File 1 -> clear cutscene -> free-roam
wait(900)
hold({Start = true}, 30); wait(150)
hold({A = true}, 6); wait(60); hold({A = true}, 6); wait(90); hold({A = true}, 6); wait(120)
for j = 0, 34 do hold({A = true}, 4); wait(18) end
wait(60)

-- walk DOWN ~90 frames to open runway away from the north transition, settle,
-- then roll UP for 30 frames.
hold({Down = true}, 90)
wait(15)
holddump({Up = true, R = true}, "ru2", 30)

client.exit()

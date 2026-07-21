-- Idle blink capture: stand still for ~10s per facing, dumping every 4th frame
-- so the short blink/fidget poses can't slip between samples (the 20-45 frame
-- spacing in capture_link_moves.lua missed them).
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
end

local function densedump(tag, n, gap)
  for i = 0, n - 1 do
    wait(gap)
    dumpframe(string.format("%s_%03d", tag, i))
  end
end

-- title -> file select -> select File 1 -> clear cutscene -> free-roam
wait(900)
hold({Start = true}, 30); wait(150)
hold({A = true}, 6); wait(60); hold({A = true}, 6); wait(90); hold({A = true}, 6); wait(120)
for j = 0, 34 do hold({A = true}, 4); wait(18) end
wait(60)

-- face down (spawn facing), long dense idle
hold({Down = true}, 4); wait(20)
densedump("bdn", 150, 4)
-- face right, long dense idle
hold({Right = true}, 4); wait(20)
densedump("brt", 150, 4)
-- face up, long dense idle
hold({Up = true}, 4); wait(20)
densedump("bup", 150, 4)
client.exit()

-- Barrier identification tour (Minish Cap): boot to free-roam, then at several
-- points dump BG VRAM + tilemaps + BG palette + control regs (decode_bg.py
-- reconstructs each background layer with exact tile boundaries), plus paired
-- before/after screenshots while walking INTO nearby edges -- if the view
-- doesn't change, the edge blocks: that's a real barrier, capture-worthy.
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

-- walk into an edge and screenshot before/after: unchanged view = blocked
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

dumpsite("spawn")
probe_edge({Left = true}, "spawn_left")

-- tour: south, then west, then north, dumping the surrounding map at each stop
hold({Down = true}, 150); wait(10); dumpsite("south")
probe_edge({Down = true}, "south_down")
hold({Left = true}, 200); wait(10); dumpsite("west")
probe_edge({Left = true}, "west_left")
hold({Up = true}, 200); wait(10); dumpsite("north")
probe_edge({Up = true}, "north_up")
hold({Right = true}, 150); wait(10); dumpsite("east")
client.exit()

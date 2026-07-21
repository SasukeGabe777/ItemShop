-- Barrier capture for M&L Superstar Saga, from the real converted save
-- (Bowser's Castle Great Door). BG dumps + edge probes at spawn and after
-- exploring a bit, same pattern as capture_barriers_zelda.lua.
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

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)      -- confirm "MARIO & LUIGI"
hold({A = true}, 10); wait(120)     -- file screen -> Start Game
hold({A = true}, 10); wait(150)     -- confirm Start Game
hold({A = true}, 10); wait(150)     -- clear any residual dialogue/prompt
dumpsite("ml_spawn")
probe_edge({Right = true}, "ml_spawn_right")
hold({Down = true}, 60); wait(10); dumpsite("ml_south")
probe_edge({Down = true}, "ml_south_down")
hold({Left = true}, 80); wait(10); dumpsite("ml_west")
probe_edge({Left = true}, "ml_west_left")
savestate.save(out .. "../ml_barrier_room.State")
client.exit()

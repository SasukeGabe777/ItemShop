local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
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
  dumpmem(0, 0x10000, "VRAM", out .. "bg/bgvram_" .. tag .. ".bin")
  dumpmem(0, 0x200, "PALRAM", out .. "bg/bgpal_" .. tag .. ".bin")
  local f = io.open(out .. "bg/regs_" .. tag .. ".txt", "w")
  f:write(string.format("DISPCNT 0x%04X\n", memory.read_u16_le(0x04000000, "System Bus")))
  for n = 0, 3 do
    f:write(string.format("BG%dCNT 0x%04X\n", n, memory.read_u16_le(0x04000008 + n * 2, "System Bus")))
  end
  f:close()
  client.screenshot(out .. "bg/shot_" .. tag .. ".png")
end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)
hold({A = true}, 10); wait(120)
hold({A = true}, 10); wait(150)
-- room 1: the save-point room (pedestal + wall reliefs + door)
dumpsite("kh_room1")
client.screenshot(out .. "kh_g00_room1.png")

-- edge-probe the pedestal (it's to the left of spawn)
client.screenshot(out .. "kh_g_ped_before.png")
hold({Left = true}, 40)
client.screenshot(out .. "kh_g_ped_after.png")

-- go back right, then up through the door
hold({Right = true}, 40); wait(5)
hold({Up = true}, 40); wait(20)
dumpsite("kh_room2")
client.screenshot(out .. "kh_g01_room2.png")

-- try all four directions from here, screenshotting each attempt
hold({Left = true}, 60); wait(5); client.screenshot(out .. "kh_g02_left.png")
hold({Down = true}, 60); wait(5); client.screenshot(out .. "kh_g03_down.png")
hold({Right = true}, 90); wait(5); client.screenshot(out .. "kh_g04_right.png")
hold({Up = true}, 60); wait(5); client.screenshot(out .. "kh_g05_up.png")

wait(3)
client.exit()

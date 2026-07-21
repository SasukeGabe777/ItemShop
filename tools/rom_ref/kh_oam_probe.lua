-- Probe OAM table while Sora walks, to identify his body palette bank and
-- any shadow-like anchor object (retuning decode_oam.py's BODY_PAL/SHADOW).
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

-- title -> menu -> LOAD -> confirm slot -> into the room
wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)
hold({A = true}, 10); wait(120)
hold({A = true}, 10); wait(150)

local f = io.open(out .. "kh_dispcnt.txt", "w")
f:write(string.format("0x%04X\n", memory.read_u16_le(0x04000000, "System Bus")))
f:close()

for i = 0, 11 do
  hold({Down = true}, 1)
  dumpframe(string.format("khp_dn_%02d", i))
end
for i = 0, 5 do
  wait(20)
  dumpframe(string.format("khp_idle_%02d", i))
end

client.exit()

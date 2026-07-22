-- Supplemental Piccolo capture: melee facing up, and a double-tap melee combo
-- facing down (first pass only caught the first hit down).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/oam_dbz/"
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

wait(300)

-- melee up: face up, tap B, dump 40
savestate.loadslot(1); wait(10)
hold({ Up = true }, 8); wait(10)
for i = 0, 39 do
  if i < 4 then joypad.set({ B = true }) end
  emu.frameadvance()
  dumpframe(string.format("mbu_%02d", i))
end

-- melee down double-tap: tap B, tap B again mid-swing, dump 60
savestate.loadslot(1); wait(10)
hold({ Down = true }, 2); wait(10)
for i = 0, 59 do
  if i < 4 or (i >= 14 and i < 18) then joypad.set({ B = true }) end
  emu.frameadvance()
  dumpframe(string.format("mcd_%02d", i))
end
client.exit()

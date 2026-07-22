-- Retry of double-tap melee combo down. Previous attempt (tag mcd) tapped B
-- again at frames 14-17, still mid-swing (swing runs to ~frame 24) -- it did
-- not chain, just let the same swing finish. This variant re-taps right
-- before the first swing's natural end (frames 20-23) to test for a real
-- combo-window chain. Tag: mcd2 (50 frames).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/oam_dbz/"
local function wait(n) for i = 1, n do emu.frameadvance() end end

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
savestate.loadslot(1); wait(10)
for i = 0, 49 do
  if i < 4 or (i >= 20 and i < 24) then joypad.set({ B = true }) end
  emu.frameadvance()
  dumpframe(string.format("mcd2_%02d", i))
end
client.exit()

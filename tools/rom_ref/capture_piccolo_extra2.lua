-- Retry of melee-up: previous attempt (capture_piccolo_extra.lua, tag mbu)
-- released Up before/while pressing B and Piccolo stayed facing down. This
-- variant holds Up THROUGH the whole attack window to test if facing sticks
-- only while the direction is actively held. Tag: mbu2 (40 frames).
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
-- hold Up continuously through the whole capture, tap B for the first 4
-- frames only (like actiondump), instead of releasing Up beforehand.
for i = 0, 39 do
  local b = { Up = true }
  if i < 4 then b.B = true end
  joypad.set(b)
  emu.frameadvance()
  dumpframe(string.format("mbu2_%02d", i))
end
client.exit()

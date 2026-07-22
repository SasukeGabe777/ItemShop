-- M&L Superstar Saga: COLD BOOT on the user's restored completed save — NO
-- savestates, NO scripted input. The user loads their file themselves.
-- Records OAM/OBJ-VRAM/OBJ-PAL on OAM-change frames + ref screenshots to
-- out/oam_ml_live/ for REC_MINUTES; live_view.png refreshes every second.
-- Emulator stays open when recording ends.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/oam_ml_live/"
local REC_MINUTES = 30

local function readrange(addr, len, domain)
  local t = memory.readbyterange(addr, len, domain)
  local base = (t[0] ~= nil) and 0 or 1
  local chars = {}
  for i = 0, len - 1 do chars[i + 1] = string.char(t[base + i]) end
  return table.concat(chars)
end
local function writefile(path, data)
  local f = io.open(path, "wb"); f:write(data); f:close()
end

gui.addmessage("== YOUR CONTROLS from boot — load your file yourself ==")
gui.addmessage("recording sprites for " .. REC_MINUTES .. " min")

local frames = REC_MINUTES * 60 * 60
local last_oam = ""
local dumps = 0
for i = 0, frames - 1 do
  emu.frameadvance()
  local oam = readrange(0, 1024, "OAM")
  if oam ~= last_oam then
    last_oam = oam
    local tag = string.format("live_%06d", i)
    writefile(out .. "oam_" .. tag .. ".bin", oam)
    writefile(out .. "objvram_" .. tag .. ".bin", readrange(0x10000, 0x8000, "VRAM"))
    writefile(out .. "objpal_" .. tag .. ".bin", readrange(0x200, 0x200, "PALRAM"))
    client.screenshot(out .. "ref_" .. tag .. ".png")
    dumps = dumps + 1
  end
  if i % 60 == 0 then
    client.screenshot(out .. "live_view.png")
  end
end
gui.addmessage("== recording finished (" .. dumps .. " pose dumps) — emulator stays open ==")

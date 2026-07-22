-- User-driven KH CoM session: load the most-progressed battle savestate and
-- HAND CONTROL TO THE USER to demonstrate Sora's true attack swings and the
-- Strike Raid sleight. Records OAM/OBJ-VRAM/OBJ-PAL on every OAM-change frame
-- (plus a ref screenshot) to out/oam_kh_live/ for REC_MINUTES; live_view.png
-- refreshes every second for the coordinator. Emulator stays open afterwards.
-- Pitfall reminder: do NOT open the 13F Namine door on the field save — that
-- cutscene hard-freezes (see AGENT_GUIDE pitfall table).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/oam_kh_live/"
-- the level-55 COMPLETED save in a FREE-ROAM field room (from the old Strike
-- Raid hunt). kh_realsave_walked/progress* are stuck at the 13F Namine
-- cutscene freeze; kh_battle_progress* are intro-tutorial states.
local STATE = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/sraid34_progress.State"
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

for i = 1, 120 do emu.frameadvance() end
savestate.load(STATE)
for i = 1, 30 do emu.frameadvance() end
client.screenshot(out .. "arrival.png")
gui.addmessage("== YOUR CONTROLS — recording sprites for " .. REC_MINUTES .. " min ==")
gui.addmessage("demo: attack swings + Strike Raid. AVOID the 13F Namine door (freeze)")

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
  if i % 3600 == 0 and i > 0 then
    gui.addmessage(string.format("recording: %d min left, %d poses",
      REC_MINUTES - i / 3600, dumps))
  end
end
gui.addmessage("== recording finished (" .. dumps .. " pose dumps) — emulator stays open ==")
client.screenshot(out .. "live_view.png")

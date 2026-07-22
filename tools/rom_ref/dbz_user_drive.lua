-- User-driven session: boot via debug menu, warp to Cell Games Arena
-- (zone 14, Piccolo field-active), then HAND CONTROL TO THE USER — the script
-- stops issuing input entirely. While the user plays, it records capture data
-- in the background: OAM/OBJ-VRAM/OBJ-PAL dumped only on frames where OAM
-- changed (poses persist several frames, so this is ~5-10 writes/sec), plus a
-- ref screenshot on every dump, for up to REC_MINUTES. live_view.png is
-- refreshed every second so the coordinating session can watch progress.
-- The emulator STAYS OPEN when recording ends.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/oam_dbz_live/"
local FLAG = 0x0202B32D
local ZONE = 14
local REC_MINUTES = 10

local function poke() memory.write_u8(FLAG, 0x02, "System Bus") end
local function step(n, buttons)
  for i = 1, n do
    if buttons then joypad.set(buttons) end
    poke()
    emu.frameadvance()
  end
end
local function tap(btn, n)
  n = n or 10
  for i = 1, n do joypad.set({ [btn] = true }); poke(); emu.frameadvance() end
  for i = 1, 15 do poke(); emu.frameadvance() end
end
local function to_debug()
  step(600)
  for i = 1, 8 do
    step(90, { Start = true })
    step(90)
  end
end

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

to_debug()
tap("Down"); tap("Down")
for i = 1, ZONE - 1 do tap("Right") end
tap("A")
step(150)
client.screenshot(out .. "arrival.png")
gui.addmessage("== YOUR CONTROLS NOW — recording sprites for " .. REC_MINUTES .. " min ==")

local frames = REC_MINUTES * 60 * 60
local last_oam = ""
local dumps = 0
for i = 0, frames - 1 do
  emu.frameadvance()   -- no joypad.set: the user drives
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

-- Full Piccolo move-set OAM capture (DBZ: Legacy of Goku II).
-- Slot 1 = open firing spot, SBC preselected (hold B fires, drains EP).
-- Slot 9 = overworld (flying). Each leg reloads its slot for clean EP/position.
-- Dumps OAM + OBJ-VRAM + OBJ-palette + ref screenshot per frame; decode in
-- Python (model: decode_oam.py, retune palette/shadow rules for this game).
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

local function holddump(b, tag, n)
  for i = 0, n - 1 do
    joypad.set(b)
    emu.frameadvance()
    dumpframe(string.format("%s_%02d", tag, i))
  end
end

local function actiondump(b, tag, n)
  for i = 0, n - 1 do
    if i < 4 then joypad.set(b) end
    emu.frameadvance()
    dumpframe(string.format("%s_%02d", tag, i))
  end
end

local function fresh(slot)
  savestate.loadslot(slot); wait(10)
end

wait(300)
fresh(1)
local f = io.open(out .. "dispcnt.txt", "w")
f:write(string.format("0x%04X\n", memory.read_u16_le(0x04000000, "System Bus")))
f:close()

-- 4-dir walks (60f each: enough to prove the cycle length)
fresh(1); holddump({ Down = true },  "wdn", 60)
fresh(1); holddump({ Up = true },    "wup", 60)
fresh(1); holddump({ Left = true },  "wlf", 60)
fresh(1); holddump({ Right = true }, "wrt", 60)

-- facing idles: walk briefly then stand
for _, d in ipairs({ { "Down", "idn" }, { "Up", "iup" }, { "Left", "ilf" }, { "Right", "irt" } }) do
  fresh(1); hold({ [d[1]] = true }, 8); wait(20)
  for i = 0, 3 do wait(20); dumpframe(string.format("%s_%02d", d[2], i)) end
end

-- long idle, dense (every 4f for ~10s) to catch blink/fidget
fresh(1)
for i = 0, 149 do wait(4); dumpframe(string.format("ilong_%03d", i)) end

-- Special Beam Cannon, all 4 facings (hold B 50f, dump every frame)
for _, d in ipairs({ { "Down", "kdn" }, { "Up", "kup" }, { "Left", "klf" }, { "Right", "krt" } }) do
  fresh(1); hold({ [d[1]] = true }, 2); wait(10)
  holddump({ B = true }, d[2], 50)
end

-- melee candidates: quick taps of A and B, facing down and right
fresh(1); actiondump({ A = true }, "mad", 30)
fresh(1); hold({ Right = true }, 8); wait(10); actiondump({ A = true }, "mar", 30)
fresh(1); actiondump({ B = true }, "mbd", 30)
fresh(1); hold({ Right = true }, 8); wait(10); actiondump({ B = true }, "mbr", 30)

-- flying (overworld, slot 9): idle hover + 4-dir movement
fresh(9)
for i = 0, 9 do wait(10); dumpframe(string.format("fidle_%02d", i)) end
fresh(9); holddump({ Down = true },  "fdn", 30)
fresh(9); holddump({ Up = true },    "fup", 30)
fresh(9); holddump({ Left = true },  "flf", 30)
fresh(9); holddump({ Right = true }, "frt", 30)

client.exit()

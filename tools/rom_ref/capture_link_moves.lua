-- Full Link move-set OAM capture: idle (all facings) + walk x4 + sword swings.
-- Boots File 1 from the battery save, reaches free-roam (nav sequence proven in
-- oam_dump.lua), then dumps OAM + OBJ-VRAM + OBJ-palette per frame for each
-- action. decode_oam.py reconstructs isolated frames from these.
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

-- hold buttons, dumping every frame
local function holddump(b, tag, n)
  for i = 0, n - 1 do
    joypad.set(b)
    emu.frameadvance()
    dumpframe(string.format("%s_%02d", tag, i))
  end
end

-- stand still, dumping frames spaced apart (catches idle blink variants)
local function idledump(tag, n, gap)
  for i = 0, n - 1 do
    wait(gap)
    dumpframe(string.format("%s_%02d", tag, i))
  end
end

-- tap a button for 4 frames, then keep dumping while the action plays out
local function actiondump(b, tag, n)
  for i = 0, n - 1 do
    if i < 4 then joypad.set(b) end
    emu.frameadvance()
    dumpframe(string.format("%s_%02d", tag, i))
  end
end

-- title -> file select -> select File 1 -> clear cutscene -> free-roam
wait(900)
hold({Start = true}, 30); wait(150)
hold({A = true}, 6); wait(60); hold({A = true}, 6); wait(90); hold({A = true}, 6); wait(120)
for j = 0, 34 do hold({A = true}, 4); wait(18) end
wait(60)

local f = io.open(out .. "dispcnt.txt", "w")
f:write(string.format("0x%04X\n", memory.read_u16_le(0x04000000, "System Bus")))
f:close()

-- walk each direction, then hold still for that facing's idle
holddump({Down = true},  "wdn", 24); idledump("idn", 4, 20)
holddump({Up = true},    "wup", 24); idledump("iup", 4, 20)
holddump({Left = true},  "wlf", 24); idledump("ilf", 4, 20)
holddump({Right = true}, "wrt", 24); idledump("irt", 4, 20)

-- long idle (facing right) to catch the fidget/blink cycle
idledump("ilong", 10, 45)

-- sword swings: B and A tried per facing; ref shots reveal which slot has it
actiondump({B = true}, "sbr", 26); wait(45)
hold({Down = true}, 6); wait(10)
actiondump({B = true}, "sbd", 26); wait(45)
hold({Up = true}, 6); wait(10)
actiondump({B = true}, "sbu", 26); wait(45)
hold({Down = true}, 6); wait(10)
actiondump({A = true}, "sad", 26); wait(45)

client.exit()

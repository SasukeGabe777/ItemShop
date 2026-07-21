-- Full Mario move-set OAM capture (M&L Superstar Saga), from the real
-- converted save (Bowser's Castle Great Door -- reached via the same
-- title->Start Game sequence proven in capture_barriers_ml.lua).
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
local function holddump(b, tag, n)
  for i = 0, n - 1 do
    joypad.set(b)
    emu.frameadvance()
    dumpframe(string.format("%s_%02d", tag, i))
  end
end
local function idledump(tag, n, gap)
  for i = 0, n - 1 do
    wait(gap)
    dumpframe(string.format("%s_%02d", tag, i))
  end
end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)
hold({A = true}, 10); wait(120)
hold({A = true}, 10); wait(150)
hold({A = true}, 10); wait(150)

holddump({Down = true},  "mwdn", 36); idledump("midn", 6, 20)
holddump({Up = true},    "mwup", 36); idledump("miup", 6, 20)
holddump({Left = true},  "mwlf", 36); idledump("milf", 6, 20)
holddump({Right = true}, "mwrt", 36); idledump("mirt", 6, 20)

-- dense idle for blink/fidget
hold({Down = true}, 4)
idledump("midn_long", 30, 6)

client.exit()

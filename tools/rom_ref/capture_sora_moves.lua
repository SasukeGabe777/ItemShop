-- Full Sora move-set OAM capture (Kingdom Hearts: Chain of Memories).
-- Boots the converted battery save, reaches free-roam, dumps OAM + OBJ-VRAM +
-- OBJ-palette per frame for idle (all facings, dense down-facing for
-- blink/fidget) + walk x4 (36 frames each, enough to prove the pose cycle
-- repeats per unique_poses.py).
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

-- title -> menu -> LOAD -> confirm slot -> into the room
wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)
hold({A = true}, 10); wait(120)
hold({A = true}, 10); wait(150)

-- walk each direction (36 frames -- long enough to see the cycle repeat),
-- then idle briefly facing that way
holddump({Down = true},  "swdn", 36); idledump("sidn", 6, 20)
holddump({Up = true},    "swup", 36); idledump("siup", 6, 20)
holddump({Left = true},  "swlf", 36); idledump("silf", 6, 20)
holddump({Right = true}, "swrt", 36); idledump("sirt", 6, 20)

-- dense idle (facing down, wherever we ended) for blink/fidget
hold({Down = true}, 4)
idledump("sidn_long", 40, 4)

client.exit()

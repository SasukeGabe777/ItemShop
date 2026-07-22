-- Full Goku move-set OAM capture (DBZ: Legacy of Goku II).
-- Goku is normally unreachable (pre-Cell-Games only); we force him field-
-- controllable via a live RAM poke discovered by 3-way diffing the slot-8
-- SWITCH CHARACTERS screen (Gohan=1/Vegeta=3/Trunks=4 states): the byte at
-- EWRAM 0x02038EBC (mirrored at IWRAM 0x03000E90) selects the active field
-- character for THIS save's roster; value 4 = Goku (confirmed visually).
-- We poke it to 4 every single frame throughout the capture as a safety
-- net against the game recomputing/overwriting it.
-- Anchor: savestates/goku_capture.State (Goku standing, East District 439,
-- open area, full EP). Dumps OAM + OBJ-VRAM + OBJ-palette + ref screenshot
-- per frame, same format as capture_piccolo_moves.lua; decode with
-- decode_oam_dbz.py --oamdir tools/rom_ref/out/oam_dbz_goku --prefix goku_.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/oam_dbz_goku/"
local STATE = "C:\\Users\\Game Station\\Desktop\\crossroads\\savestates\\goku_capture.State"
local EW = 0x02038EBC
local IW = 0x03000E90
local GOKU_VAL = 4

local function poke()
  memory.write_u8(EW, GOKU_VAL, "System Bus")
  memory.write_u8(IW, GOKU_VAL, "System Bus")
end
local function wait(n) for i = 1, n do poke(); emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); poke(); emu.frameadvance() end end
local function press(btn, n)
  n = n or 8
  for i = 1, n do joypad.set({ [btn] = true }); poke(); emu.frameadvance() end
  for i = 1, 15 do poke(); emu.frameadvance() end
end

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
    poke()
    emu.frameadvance()
    dumpframe(string.format("%s_%02d", tag, i))
  end
end

-- direction held THROUGH the action tap (pitfall: releasing the direction
-- before/during the tap loses the turn -- see AGENT_GUIDE §8 / mbu2 vs mbu)
local function actiondump_dir(dirbtn, actionbtn, tag, n)
  for i = 0, n - 1 do
    local b = { [dirbtn] = true }
    if i < 4 then b[actionbtn] = true end
    joypad.set(b)
    poke()
    emu.frameadvance()
    dumpframe(string.format("%s_%02d", tag, i))
  end
end

local function fresh()
  savestate.load(STATE)
  wait(10)
end

fresh()
local f = io.open(out .. "dispcnt.txt", "w")
f:write(string.format("0x%04X\n", memory.read_u16_le(0x04000000, "System Bus")))
f:close()

-- 4-dir walks (60f each: enough to prove the cycle length)
fresh(); holddump({ Down = true },  "wdn", 60)
fresh(); holddump({ Up = true },    "wup", 60)
fresh(); holddump({ Left = true },  "wlf", 60)
fresh(); holddump({ Right = true }, "wrt", 60)

-- facing idles: walk briefly then stand
for _, d in ipairs({ { "Down", "idn" }, { "Up", "iup" }, { "Left", "ilf" }, { "Right", "irt" } }) do
  fresh(); hold({ [d[1]] = true }, 8); wait(20)
  for i = 0, 3 do wait(20); dumpframe(string.format("%s_%02d", d[2], i)) end
end

-- long idle, dense (every 4f for ~10s) to catch blink/fidget
fresh()
for i = 0, 149 do wait(4); dumpframe(string.format("ilong_%03d", i)) end

-- melee: BOTH A-tap and B-tap, facing down/right/up, direction held through
-- the whole capture window (per the mbu2 pitfall fix)
local melee_dirs = { { "Down", "dn" }, { "Right", "rt" }, { "Up", "up" } }
for _, d in ipairs(melee_dirs) do
  fresh(); hold({ [d[1]] = true }, 8); wait(10)
  actiondump_dir(d[1], "A", "ma" .. d[2], 30)
end
for _, d in ipairs(melee_dirs) do
  fresh(); hold({ [d[1]] = true }, 8); wait(10)
  actiondump_dir(d[1], "B", "mb" .. d[2], 30)
end

-- Kamehameha, down/right/up (L-cycle=1 selects it; hold B 50f, dump every
-- frame). Recharge ki with A between if needed -- fresh() already restores
-- full EP each time via the savestate reload, so no recharge needed here.
local kame_dirs = { { "Down", "kdn" }, { "Right", "krt" }, { "Up", "kup" } }
for _, d in ipairs(kame_dirs) do
  fresh()
  hold({ [d[1]] = true }, 2); wait(10)
  press("L", 8)              -- L-cycle x1 -> Kamehameha
  holddump({ B = true }, d[2], 50)
end

client.exit()

-- Link's ROLL (R button, per the in-game "R: Roll" HUD hint). Same nav
-- prelude, dumpmem/dumpframe/holddump helpers as capture_link_moves.lua --
-- decode_oam.py picks up oam_r*.bin unchanged (BODY_PAL=6, shadow anchor).
-- Pattern: brief tap of the bare direction to set facing, then hold
-- direction+R together and dump every frame -- a roll is a committed dash
-- move in Minish Cap, so holding (not just tapping) R keeps it consistent
-- if the move needs sustained input. Repositions to open ground between
-- rolls so the dash doesn't get cut short by hedges/fountain/NPCs.
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

-- title -> file select -> select File 1 -> clear cutscene -> free-roam
wait(900)
hold({Start = true}, 30); wait(150)
hold({A = true}, 6); wait(60); hold({A = true}, 6); wait(90); hold({A = true}, 6); wait(120)
for j = 0, 34 do hold({A = true}, 4); wait(18) end
wait(60)

-- reposition to open ground (up, away from the spawn fountain/hedges)
hold({Up = true}, 40); wait(10)

-- Roll facing down
hold({Down = true}, 6); wait(6)
holddump({Down = true, R = true}, "rdn", 30)
wait(20)

-- back to open ground before the next roll (rolling down drifted us down)
hold({Up = true}, 40); wait(10)

-- Roll facing up
hold({Up = true}, 6); wait(6)
holddump({Up = true, R = true}, "rup", 30)
wait(20)

-- back to open ground (rolling up drifted us up)
hold({Down = true}, 40); wait(10)

-- Roll facing right (side)
hold({Right = true}, 6); wait(6)
holddump({Right = true, R = true}, "rrt", 30)

client.exit()

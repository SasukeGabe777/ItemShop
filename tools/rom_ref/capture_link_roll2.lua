-- Link's ROLL, take 2: v1 walked "up 40" to reposition before rolling and
-- that alone was enough to trip a North Hyrule Field boundary/banner lock,
-- eating the whole dump (frames identical, then faded to white mid-dump).
-- Town-center spawn itself has plenty of open grass either side of the path
-- (proven by every prior capture_barriers_zelda.lua/capture_link_moves.lua
-- run) -- roll straight from spawn instead, no pre-walk. Return to spawn
-- between rolls with a plain opposite-direction hold, not another roll.
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

-- Roll facing down (right at spawn -- open path toward the market, proven
-- clear for 150+ frames by capture_barriers_zelda.lua's "south" leg)
hold({Down = true}, 6); wait(6)
holddump({Down = true, R = true}, "rdn", 30)
wait(20)
hold({Up = true}, 40); wait(10)   -- back toward spawn

-- Roll facing up
hold({Up = true}, 6); wait(6)
holddump({Up = true, R = true}, "rup", 30)
wait(20)
hold({Down = true}, 40); wait(10) -- back toward spawn

-- Roll facing right (side)
hold({Right = true}, 6); wait(6)
holddump({Right = true, R = true}, "rrt", 30)

client.exit()

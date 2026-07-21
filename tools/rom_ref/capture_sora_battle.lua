-- Battle-view OAM capture: sword-attack swing + dodge roll (double-tap
-- direction, confirmed by the in-game tutorial text: "Tap the +Control Pad
-- Left or Right twice: Dodge Roll"). Also tries chaining 3 card-uses to see
-- if a sleight (combo attack) triggers.
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
local function actiondump(b, tag, n, holdframes)
  for i = 0, n - 1 do
    if i < holdframes then joypad.set(b) end
    emu.frameadvance()
    dumpframe(string.format("%s_%02d", tag, i))
  end
end

savestate.load("C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/kh_battle_progress6.State")

-- record DISPCNT for this scene (battle may use a different mode)
local f = io.open(out .. "kh_battle_dispcnt.txt", "w")
f:write(string.format("0x%04X\n", memory.read_u16_le(0x04000000, "System Bus")))
f:close()

-- attack swing x3 (A button)
actiondump({A = true}, "satk", 30, 8); wait(30)
actiondump({A = true}, "satk2", 30, 8); wait(30)
actiondump({A = true}, "satk3", 30, 8); wait(60)

-- dodge roll: double-tap Left
actiondump({Left = true}, "sdodge_tap1", 6, 4)
actiondump({}, "sdodge_gap", 4, 0)
actiondump({Left = true}, "sdodge_tap2", 30, 4)
wait(30)

-- dodge roll facing right too
actiondump({Right = true}, "sdodge2_tap1", 6, 4)
actiondump({}, "sdodge2_gap", 4, 0)
actiondump({Right = true}, "sdodge2_tap2", 30, 4)

client.exit()

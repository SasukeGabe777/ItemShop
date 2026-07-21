-- Phase 2: from the loaded save, select the file, reach in-game, and dump
-- consecutive frames of Link walking (each direction) and swinging the sword.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end
local function dump(b, tag, n)
  for i = 0, n - 1 do
    joypad.set(b); emu.frameadvance()
    client.screenshot(string.format("%s%s_%02d.png", out, tag, i))
  end
end

-- title -> file select -> select File 1 -> in-game
wait(900)
hold({Start = true}, 30); wait(150)
hold({A = true}, 6); wait(60);  client.screenshot(out .. "p2_a1.png")
hold({A = true}, 6); wait(90);  client.screenshot(out .. "p2_a2.png")
hold({A = true}, 6); wait(120); client.screenshot(out .. "p2_ingame.png")

-- capture walk cycles (16 frames each direction)
dump({Down = true},  "walk_dn", 16); wait(10)
dump({Up = true},    "walk_up", 16); wait(10)
dump({Left = true},  "walk_lf", 16); wait(10)
dump({Right = true}, "walk_rt", 16); wait(10)

-- capture a sword swing (A = sword/action). Dump idle first, then the swing.
client.screenshot(out .. "idle.png")
dump({A = true}, "sword", 16)

wait(3)
client.exit()

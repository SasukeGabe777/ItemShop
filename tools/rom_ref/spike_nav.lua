-- Phase 1b: wait past logos, then navigate title -> file select -> in-game.
-- Multiple checkpoints so the navigation path is visible.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b, 1); emu.frameadvance() end end

wait(900);                    client.screenshot(out .. "n00_boot.png")
hold({Start = true}, 5); wait(90);  client.screenshot(out .. "n01.png")
hold({Start = true}, 5); wait(90);  client.screenshot(out .. "n02.png")
hold({A = true}, 5);     wait(90);  client.screenshot(out .. "n03.png")
hold({A = true}, 5);     wait(120); client.screenshot(out .. "n04.png")
wait(3); client.exit()

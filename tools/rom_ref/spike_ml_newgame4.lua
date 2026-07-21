local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "ml_newgame_check.State")
hold({Up = true}, 8); wait(20)
hold({Right = true}, 8); wait(20)
hold({Down = true}, 8); wait(20)
hold({A = true}, 10); wait(90)     -- confirm Start Game on the empty slot
client.screenshot(out .. "ml_ng4_00.png")
savestate.save(out .. "ml_newgame_started.State")
for i = 1, 20 do
  hold({A = true}, 6); wait(50)
end
client.screenshot(out .. "ml_ng4_01.png")
for i = 1, 20 do
  hold({A = true}, 6); wait(50)
end
client.screenshot(out .. "ml_ng4_02.png")
savestate.save(out .. "ml_intro_progress.State")
wait(3)
client.exit()

local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({A = true}, 10); wait(90)
hold({Up = true}, 8); wait(20)
hold({Right = true}, 8); wait(20)
hold({Down = true}, 8); wait(20)
hold({A = true}, 10); wait(90)
client.screenshot(out .. "ml_full_00.png")
for i = 1, 150 do
  hold({A = true}, 6); wait(50)
  if i % 20 == 0 then
    client.screenshot(out .. string.format("ml_full_p%02d.png", i))
  end
end
client.screenshot(out .. "ml_full_zz.png")
savestate.save(out .. "ml_full_end.State")
wait(3)
client.exit()

local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "ml_intro_progress3.State")
for i = 1, 60 do
  hold({A = true}, 6); wait(50)
end
client.screenshot(out .. "ml_ng7_00.png")
savestate.save(out .. "ml_intro_progress4.State")
for i = 1, 60 do
  hold({A = true}, 6); wait(50)
end
client.screenshot(out .. "ml_ng7_01.png")
savestate.save(out .. "ml_intro_progress5.State")
wait(3)
client.exit()

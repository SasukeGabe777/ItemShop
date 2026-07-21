local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_realsave_progress2.State")
for i = 1, 20 do
  hold({A = true}, 6); wait(50)
end
client.screenshot(out .. "kh_rs6_00.png")
for i = 1, 20 do
  hold({A = true}, 6); wait(50)
end
client.screenshot(out .. "kh_rs6_01.png")
for i = 1, 20 do
  hold({A = true}, 6); wait(50)
end
client.screenshot(out .. "kh_rs6_02.png")
savestate.save(out .. "kh_realsave_progress3.State")
wait(3)
client.exit()

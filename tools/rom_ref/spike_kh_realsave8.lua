local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_realsave_progress4.State")
for i = 1, 60 do
  hold({A = true}, 4); wait(50)
end
client.screenshot(out .. "kh_rs8_00.png")
savestate.save(out .. "kh_realsave_progress5.State")
for i = 1, 60 do
  hold({A = true}, 4); wait(50)
end
client.screenshot(out .. "kh_rs8_01.png")
savestate.save(out .. "kh_realsave_progress6.State")
wait(3)
client.exit()

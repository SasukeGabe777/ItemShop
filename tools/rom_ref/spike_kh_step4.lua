local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_intro_progress.State")
for i = 1, 30 do
  hold({A = true}, 6); wait(60)
end
client.screenshot(out .. "kh_step4_00.png")
for i = 1, 30 do
  hold({A = true}, 6); wait(60)
end
client.screenshot(out .. "kh_step4_01.png")
savestate.save(out .. "kh_intro_progress2.State")
wait(3)
client.exit()

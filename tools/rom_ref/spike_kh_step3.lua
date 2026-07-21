local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_at_menu.State")
hold({A = true}, 10); wait(60)
client.screenshot(out .. "kh_step3_00.png")
for i = 1, 8 do
  hold({A = true}, 6); wait(60)
end
client.screenshot(out .. "kh_step3_01.png")
for i = 1, 8 do
  hold({A = true}, 6); wait(60)
end
client.screenshot(out .. "kh_step3_02.png")
savestate.save(out .. "kh_intro_progress.State")
wait(3)
client.exit()

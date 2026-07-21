local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_intro_progress8.State")
for i = 1, 10 do
  hold({A = true}, 6); wait(60)
end
client.screenshot(out .. "kh_step11_00.png")
-- try actual battle input: move + attack with A
hold({Right = true}, 20); wait(10)
client.screenshot(out .. "kh_step11_01.png")
hold({A = true}, 6); wait(40)
client.screenshot(out .. "kh_step11_02.png")
hold({A = true}, 6); wait(40)
client.screenshot(out .. "kh_step11_03.png")
hold({A = true}, 6); wait(40)
client.screenshot(out .. "kh_step11_04.png")
savestate.save(out .. "kh_battle_progress.State")
wait(3)
client.exit()

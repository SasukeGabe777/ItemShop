local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_battle_progress2.State")
for i = 1, 10 do
  hold({A = true}, 6); wait(60)
end
client.screenshot(out .. "kh_step14_00.png")
for i = 1, 10 do
  hold({A = true}, 6); wait(60)
end
client.screenshot(out .. "kh_step14_01.png")
savestate.save(out .. "kh_battle_progress3.State")
wait(3)
client.exit()

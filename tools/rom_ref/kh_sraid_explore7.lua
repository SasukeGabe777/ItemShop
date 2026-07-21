-- Recon pass 7: clear the Jiminy journal popup, then walk to the door
-- (visible top-right of the room) and through it to the next room, where we
-- hope for a normal (non-tutorial) battle.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid6_progress.State")

for i = 1, 4 do
  hold({A = true}, 6); wait(60)
  client.screenshot(out .. string.format("sraid7_dlg_%02d.png", i))
end

hold({Up = true}, 40); wait(10)
client.screenshot(out .. "sraid7_m1.png")
hold({Right = true}, 60); wait(10)
client.screenshot(out .. "sraid7_m2.png")
hold({Up = true}, 40); wait(10)
client.screenshot(out .. "sraid7_m3.png")
hold({Right = true}, 40); wait(10)
client.screenshot(out .. "sraid7_m4.png")
hold({Up = true}, 40); wait(20)
client.screenshot(out .. "sraid7_m5.png")

savestate.save(out .. "sraid7_progress.State")
wait(3)
client.exit()

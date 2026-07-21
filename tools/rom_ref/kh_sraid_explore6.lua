-- Recon pass 6: finish the cutscene dialogue and regain free control, then
-- walk toward the door (top-right of the room) and into the next room.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid5_progress.State")

for i = 1, 6 do
  hold({A = true}, 6); wait(90)
  client.screenshot(out .. string.format("sraid6_dlg_%02d.png", i))
end

-- try moving right/up toward the door
hold({Right = true}, 40); wait(10)
client.screenshot(out .. "sraid6_move1.png")
hold({Up = true}, 40); wait(10)
client.screenshot(out .. "sraid6_move2.png")
hold({Right = true}, 30); wait(10)
client.screenshot(out .. "sraid6_move3.png")
hold({Up = true}, 30); wait(10)
client.screenshot(out .. "sraid6_move4.png")

savestate.save(out .. "sraid6_progress.State")
wait(3)
client.exit()

-- Recon pass 14: door is synthesized and open; walk through into the next
-- room and see what's there (hoping for a free-roam Shadow encounter).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid13_progress.State")

for i = 1, 8 do
  hold({A = true}, 6); wait(50)
  client.screenshot(out .. string.format("sraid14_a_%02d.png", i))
end
hold({Up = true}, 30); wait(10)
client.screenshot(out .. "sraid14_m1.png")
hold({Right = true}, 30); wait(10)
client.screenshot(out .. "sraid14_m2.png")
hold({Up = true}, 30); wait(10)
client.screenshot(out .. "sraid14_m3.png")
hold({Up = true}, 30); wait(10)
client.screenshot(out .. "sraid14_m4.png")

savestate.save(out .. "sraid14_progress.State")
wait(3)
client.exit()

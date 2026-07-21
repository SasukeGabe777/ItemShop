-- Recon pass 34: continue from sraid33 end position with more Up taps to
-- land on the crystal tile.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)
hold({Up=true, Left=true}, 150); wait(10)
for i = 1, 8 do hold({Right = true}, 8); wait(15) end
for i = 1, 4 do hold({Up = true}, 8); wait(15) end

for i = 1, 6 do
  hold({Up = true}, 8); wait(15)
  client.screenshot(out .. string.format("sraid34_u%02d.png", i))
end

savestate.save(out .. "sraid34_progress.State")
wait(3)
client.exit()

local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)
hold({Up=true, Left=true}, 150); wait(10)
hold({Up = true}, 15); wait(10)
hold({Right = true}, 15); wait(10)

for i = 1, 6 do
  hold({Right = true}, 6); wait(10)
  client.screenshot(out .. string.format("sraid37_r%02d.png", i))
end
for i = 1, 4 do
  hold({Up = true}, 6); wait(10)
  client.screenshot(out .. string.format("sraid37_u%02d.png", i))
end
client.exit()

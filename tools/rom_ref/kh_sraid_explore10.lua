-- Recon pass 10: continue toward the door and through it; keep tapping A
-- (covers both "continue dialogue" and "swing keyblade to open door").
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid9_progress.State")

hold({Right = true}, 30); wait(5)
client.screenshot(out .. "sraid10_r1.png")
hold({A = true}, 20); wait(30)
client.screenshot(out .. "sraid10_a1.png")
hold({Right = true}, 30); wait(5)
client.screenshot(out .. "sraid10_r2.png")
hold({A = true}, 20); wait(30)
client.screenshot(out .. "sraid10_a2.png")

for i = 1, 12 do
  hold({A = true}, 6); wait(70)
  client.screenshot(out .. string.format("sraid10_%02d.png", i))
end

savestate.save(out .. "sraid10_progress.State")
wait(3)
client.exit()

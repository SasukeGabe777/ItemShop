-- Phase 2b: clear the cutscene dialogue, then capture walk + sword in free-roam.
local out = "C:/Users/sasuk/OneDrive/Desktop/ItemShop/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end
local function dump(b, tag, n)
  for i = 0, n - 1 do
    joypad.set(b); emu.frameadvance()
    client.screenshot(string.format("%s%s_%02d.png", out, tag, i))
  end
end

wait(900)
hold({Start = true}, 30); wait(150)
hold({A = true}, 6); wait(60); hold({A = true}, 6); wait(90); hold({A = true}, 6); wait(120)

-- mash A to clear cutscene dialogue boxes; sample progress
for j = 0, 34 do
  hold({A = true}, 4); wait(18)
  if j % 7 == 0 then client.screenshot(string.format("%sclr_%02d.png", out, j)) end
end
wait(60); client.screenshot(out .. "free.png")

-- verify control by walking, then swing sword
dump({Down = true}, "w2_dn", 16); wait(10)
client.screenshot(out .. "after_walk.png")
dump({Left = true}, "w2_lf", 16); wait(10)
dump({A = true}, "sw2", 16)
client.exit()

-- Recon pass 33: fine single-tap nudges toward the save crystal from the
-- near corner, to land exactly on its tile and see if stepping onto it
-- (not striking it) triggers anything automatically.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)
hold({Up=true, Left=true}, 150); wait(10)  -- far corner near torches/crystal

for i = 1, 8 do
  hold({Right = true}, 8); wait(15)
  client.screenshot(out .. string.format("sraid33_r%02d.png", i))
end
for i = 1, 4 do
  hold({Up = true}, 8); wait(15)
  client.screenshot(out .. string.format("sraid33_u%02d.png", i))
end

client.exit()

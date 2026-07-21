-- Strike Raid recon pass 2: continue the tutorial dialogue crawl found in
-- pass 1 ("The four card types...") by tapping A to advance each text box,
-- waiting long enough for the type-on animation to finish before the next
-- tap. Screenshot after every tap so we can read the whole tutorial script.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid1_progress.State")

for i = 1, 24 do
  hold({A = true}, 6); wait(90)
  client.screenshot(out .. string.format("sraid2_%02d.png", i))
end

savestate.save(out .. "sraid2_progress.State")
wait(3)
client.exit()

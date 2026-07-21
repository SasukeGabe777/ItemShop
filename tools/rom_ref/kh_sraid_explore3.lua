-- Strike Raid recon pass 3: tutorial demanded "Press SELECT" to change card
-- categories. Press Select, then keep advancing with A, screenshotting
-- every tap, watching for stocking/sleight instructions.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid2_progress.State")

hold({Select = true}, 6); wait(60)
client.screenshot(out .. "sraid3_select.png")

for i = 1, 30 do
  hold({A = true}, 6); wait(90)
  client.screenshot(out .. string.format("sraid3_%02d.png", i))
end

savestate.save(out .. "sraid3_progress.State")
wait(3)
client.exit()

-- Recon pass 4: from sraid3_progress (category switched to the empty enemy-
-- card category, "Press SELECT" hint stuck), press Select again to cycle
-- back, screenshot each step, then keep advancing with A.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid3_progress.State")
client.screenshot(out .. "sraid4_start.png")

hold({Select = true}, 6); wait(60)
client.screenshot(out .. "sraid4_select2.png")

for i = 1, 10 do
  hold({A = true}, 6); wait(90)
  client.screenshot(out .. string.format("sraid4_%02d.png", i))
end

savestate.save(out .. "sraid4_progress.State")
wait(3)
client.exit()

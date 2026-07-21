-- Recon pass 18: Sora seems to be bouncing at a doorway boundary going
-- Right (vanishes off-screen then reappears near the door on Down). Hold
-- Right for a long time to force through whatever transition this is.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid16_progress.State")
client.screenshot(out .. "sraid18_00.png")

for i = 1, 6 do
  hold({Right = true}, 30); wait(5)
  client.screenshot(out .. string.format("sraid18_r%02d.png", i))
end

savestate.save(out .. "sraid18_progress.State")
wait(3)
client.exit()

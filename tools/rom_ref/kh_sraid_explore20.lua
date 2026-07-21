-- Recon pass 20: Right is the open direction (pass 19 confirmed). Hold Right
-- much longer, screenshotting periodically, to cross the room and find an
-- enemy encounter marker.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)

for i = 1, 10 do
  hold({Right = true}, 40); wait(5)
  client.screenshot(out .. string.format("sraid20_%02d.png", i))
end

savestate.save(out .. "sraid20_progress.State")
wait(3)
client.exit()

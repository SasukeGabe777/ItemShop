-- Recon pass 38: last check -- wait a long time in the room in case an
-- enemy spawns on a timer rather than being placed statically.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)

for i = 1, 8 do
  wait(150)
  client.screenshot(out .. string.format("sraid38_%02d.png", i))
end
client.exit()

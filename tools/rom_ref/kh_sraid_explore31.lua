-- Recon pass 31: test whether entering Traverse Town continues as a scripted
-- auto-walk (like the "Obtained Key of Beginnings" walk was) if we just wait
-- with no input, rather than manually steering.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
client.screenshot(out .. "sraid31_00.png")

for i = 1, 10 do
  wait(60)
  client.screenshot(out .. string.format("sraid31_wait_%02d.png", i))
end

savestate.save(out .. "sraid31_progress.State")
wait(3)
client.exit()

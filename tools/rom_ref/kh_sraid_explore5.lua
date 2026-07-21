-- Recon pass 5: tutorial battle is over, Sora is in a cutscene with Donald
-- and Goofy. Keep advancing dialogue with A until we regain free control,
-- then poke around (screenshot) to find the room layout / next enemy.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid4_progress.State")

for i = 1, 30 do
  hold({A = true}, 6); wait(90)
  client.screenshot(out .. string.format("sraid5_%02d.png", i))
end

savestate.save(out .. "sraid5_progress.State")
wait(3)
client.exit()

-- Recon pass 24: test diagonal d-pad combos (Up+Right, Down+Left, etc.) in
-- case this isometric room needs diagonal presses to actually traverse the
-- floor (straight single directions have only bounced Sora in a tiny nook).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)
client.screenshot(out .. "sraid24_00.png")

local combos = {
  {Up=true, Right=true}, {Up=true, Left=true},
  {Down=true, Right=true}, {Down=true, Left=true},
}
local names = {"UpRight", "UpLeft", "DownRight", "DownLeft"}
for i, c in ipairs(combos) do
  hold(c, 60); wait(10)
  client.screenshot(out .. string.format("sraid24_%s.png", names[i]))
end

savestate.save(out .. "sraid24_progress.State")
wait(3)
client.exit()

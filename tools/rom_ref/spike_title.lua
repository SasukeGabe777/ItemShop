-- Phase 0 spike: prove launch -> Lua -> screenshot -> readable PNG.
-- Boots the ROM, advances past boot logos, dumps one screenshot, exits.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"

-- ~600 frames ≈ 10s of emulated time: enough to clear GBA/game logos.
for i = 1, 600 do
  emu.frameadvance()
end

client.screenshot(out .. "spike_title.png")

-- a couple more frames so the screenshot flush completes, then quit
for i = 1, 3 do
  emu.frameadvance()
end
client.exit()

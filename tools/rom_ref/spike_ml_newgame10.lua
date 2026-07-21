local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end

savestate.load(out .. "ml_intro_progress2.State")
wait(30)
client.screenshot(out .. "ml_ng10_00.png")
wait(300)
client.screenshot(out .. "ml_ng10_01.png")
wait(3)
client.exit()

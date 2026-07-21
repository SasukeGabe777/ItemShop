local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end

savestate.load(out .. "ml_intro_progress3.State")
wait(600)
client.screenshot(out .. "ml_ng9_00.png")
wait(600)
client.screenshot(out .. "ml_ng9_01.png")
wait(600)
client.screenshot(out .. "ml_ng9_02.png")
wait(600)
client.screenshot(out .. "ml_ng9_03.png")
wait(3)
client.exit()

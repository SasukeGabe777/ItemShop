-- Fresh boot spike (Mario & Luigi Superstar Saga): no save conversion applied yet.
-- Just clears boot logos, screenshots title, forces a save flush, exits.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end

wait(900)
client.screenshot(out .. "ml_boot_00.png")
wait(150)
client.screenshot(out .. "ml_boot_01.png")
client.saveram()
wait(3)
client.exit()

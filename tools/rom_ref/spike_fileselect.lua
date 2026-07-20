-- Confirm the converted battery save loads: screenshot the file-select screen.
local out = "C:/Users/sasuk/OneDrive/Desktop/ItemShop/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
wait(900)
for i = 1, 30 do joypad.set({Start = true}); emu.frameadvance() end
wait(150)
client.screenshot(out .. "fileselect.png")
wait(3)
client.exit()

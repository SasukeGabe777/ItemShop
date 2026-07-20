-- Phase 1 spike: confirm the battery save loaded (land on Link's saved file).
local out = "C:/Users/sasuk/OneDrive/Desktop/ItemShop/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function press(btn, n) for i = 1, n do joypad.set({[btn] = true}, 1); emu.frameadvance() end end

wait(600)                                  -- boot logos -> title
client.screenshot(out .. "save_00_title.png")
press("Start", 8); wait(150)               -- title -> file select
client.screenshot(out .. "save_01_fileselect.png")
wait(3)
client.exit()

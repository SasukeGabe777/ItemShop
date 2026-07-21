-- Boot check (DBZ: Legacy of Goku II): confirm the converted EEPROM SaveRAM is
-- recognized. Clears logos, then steps through the title/menu pressing Start/A
-- while screenshotting, so the continue/file-select reveals whether the save
-- loaded. Paths are for THIS (work) machine, not the home template path.
local out = "C:/Users/sasuk/OneDrive/Desktop/ItemShop/tools/rom_ref/out/dbz/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function press(btn, hold)
  hold = hold or 30
  for i = 1, hold do joypad.set({ [btn] = true }); emu.frameadvance() end
  for i = 1, 12 do emu.frameadvance() end
end

wait(900)                                   -- clear THQ/Webfoot/Atari + title fade
client.screenshot(out .. "boot_00_title.png")
press("Start"); wait(80)
client.screenshot(out .. "boot_01.png")
press("Start"); wait(80)
client.screenshot(out .. "boot_02.png")
press("A"); wait(90)
client.screenshot(out .. "boot_03.png")
press("A"); wait(120)
client.screenshot(out .. "boot_04.png")
client.saveram()
wait(3)
client.exit()

-- New lead: the little arrow icons at the top corners of STATUS/SWITCH
-- screens might be L/R shoulder-button tab cycling (Journal/Status/Items/
-- Switch?), separate from D-pad Left/Right which cycles party members
-- within a tab. Test L/R from the Start menu at zone2 (our Goku-alive save).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/starttab/"
local FLAG = 0x0202B32D
local function poke() memory.write_u8(FLAG, 0x02, "System Bus") end
local function step(n, buttons)
  for i = 1, n do
    if buttons then joypad.set(buttons) end
    poke()
    emu.frameadvance()
  end
end
local function tap(btn, n)
  n = n or 10
  for i = 1, n do joypad.set({ [btn] = true }); poke(); emu.frameadvance() end
  for i = 1, 15 do poke(); emu.frameadvance() end
end
local function to_debug()
  step(600)
  for i = 1, 8 do
    step(90, { Start = true })
    step(90)
  end
end

to_debug()
tap("Down"); tap("Down")
tap("Right")   -- zone2
tap("A")
step(150)

tap("Start"); step(20)
client.screenshot(out .. "b00_status.png")
tap("L")
client.screenshot(out .. "b01_after_L.png")
tap("L")
client.screenshot(out .. "b02_after_L2.png")
tap("R")
client.screenshot(out .. "b03_after_R.png")
tap("R")
client.screenshot(out .. "b04_after_R2.png")
tap("R")
client.screenshot(out .. "b05_after_R3.png")
tap("R")
client.screenshot(out .. "b06_after_R4.png")

client.exit()

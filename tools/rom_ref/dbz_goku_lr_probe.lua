-- Quick check: does L or R alone (outside the ki-cycle context) swap the
-- active field-controlled party member at an open map (zone2, Piccolo)?
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/lr/"
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
tap("Right")   -- zone2, East District 439
tap("A")
step(150)
client.screenshot(out .. "l00_before.png")
tap("R")
client.screenshot(out .. "l01_after_R.png")
tap("R")
client.screenshot(out .. "l02_after_R2.png")
tap("Select")
client.screenshot(out .. "l03_after_select.png")
step(30)
client.screenshot(out .. "l04_settle.png")
client.exit()

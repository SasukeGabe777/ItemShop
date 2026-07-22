-- Robustness test: more generous margins to reach DEBUG menu reliably.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/"
local FLAG = 0x0202B32D
local function poke() memory.write_u8(FLAG, 0x02, "System Bus") end
local function step(n, buttons)
  for i = 1, n do
    if buttons then joypad.set(buttons) end
    poke()
    emu.frameadvance()
  end
end

step(600)
step(900, { Start = true })
step(200)
client.screenshot(out .. "p3_00_after_hold.png")
step(90, { Start = true })
step(150)
client.screenshot(out .. "p3_01_settle.png")
-- if still at title, hit start again
step(60, { Start = true })
step(120)
client.screenshot(out .. "p3_02_settle2.png")
client.exit()

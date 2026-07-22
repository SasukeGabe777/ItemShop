-- Debug/test menu bring-up (DBZ: Legacy of Goku II, USA).
-- TCRF: write 0x02 to 0x0202B32D while the game is starting up, then press and
-- hold Start at the title screen. Debug mode = map warps + all 6 characters.
-- We emulate the GameShark by re-writing the flag every frame from power-on.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz/"
local FLAG = 0x0202B32D

local function poke() memory.write_u8(FLAG, 0x02, "System Bus") end
local function step(n, buttons)
  for i = 1, n do
    if buttons then joypad.set(buttons) end
    poke()
    emu.frameadvance()
  end
end

step(500)                                    -- logos
client.screenshot(out .. "dbg_00_prestart.png")
step(700, { Start = true })                  -- hold Start through title fade-in
client.screenshot(out .. "dbg_01_after_hold.png")
step(120)
client.screenshot(out .. "dbg_02_settle.png")
step(60, { Start = true })                   -- one more tap in case menu needs it
step(90)
client.screenshot(out .. "dbg_03_final.png")
client.exit()

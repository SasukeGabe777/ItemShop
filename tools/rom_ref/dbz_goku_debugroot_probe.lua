-- Directive #2: exhaustively confirm the DEBUG root has no hidden CHARA/
-- PLAYER TEST entry. Check Up-wrap (entry before Music Test), and A on
-- Music Test / Sample Test rows (do they open a submenu instead of just
-- playing a track/sfx?).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/debugroot/"
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
client.screenshot(out .. "d00_root.png")
tap("Up")
client.screenshot(out .. "d01_up1.png")
tap("Up")
client.screenshot(out .. "d02_up2.png")

-- back to root (Music Test), try A
tap("Down")  -- ensure known position: Music Test
client.screenshot(out .. "d03_at_music.png")
tap("A")
step(30)
client.screenshot(out .. "d04_a_on_music.png")
step(60)
client.screenshot(out .. "d05_settle.png")

tap("Down")  -- Sample Test
client.screenshot(out .. "d06_at_sample.png")
tap("A")
step(30)
client.screenshot(out .. "d07_a_on_sample.png")
step(60)
client.screenshot(out .. "d08_settle2.png")

client.exit()

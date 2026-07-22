-- New lead: slot8's "SWITCH CHARACTERS" screen is a STALE savestate snapshot
-- from a LATER story point (roster = Gohan/Piccolo/Vegeta/Trunks/Hercule --
-- no Goku). Our COLD-BOOT SaveRAM is from an EARLIER point where Goku is
-- still alive (confirmed via Status: Piccolo/Vegeta/Trunks/Goku/Hercule).
-- Hypothesis: walking up to a party-member NPC (e.g. Vegeta at the Cell
-- Games Arena, zone 14) and pressing A opens this same switch-characters
-- menu, but reading OUR current (Goku-alive) roster.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/talkswitch/"
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
for i = 1, 13 do tap("Right") end   -- zone 14 (Cell Games Arena, Piccolo+Vegeta NPC)
tap("A")
step(150)
client.screenshot(out .. "w00_arena.png")

-- Vegeta NPC was to the lower-right of Piccolo in the earlier survey shot;
-- walk right then down a bit toward him, talking (A) periodically.
for i = 1, 20 do joypad.set({ Right = true }); poke(); emu.frameadvance() end
client.screenshot(out .. "w01_after_right.png")
tap("A")
client.screenshot(out .. "w02_after_a1.png")
for i = 1, 10 do joypad.set({ Down = true }); poke(); emu.frameadvance() end
client.screenshot(out .. "w03_after_down.png")
tap("A")
client.screenshot(out .. "w04_after_a2.png")
step(30)
client.screenshot(out .. "w05_settle.png")

client.exit()

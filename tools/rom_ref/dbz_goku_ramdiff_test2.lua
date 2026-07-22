-- Candidate 2: Pattern A from the slot-8 diff (gohan=0,vegeta=2,trunks=3,
-- i.e. stored = charID - 1). EWRAM 0x02038EBC, IWRAM 0x03000E90.
-- For GOKU (id=0), stored value would be -1 -> 0xFF (unsigned byte wrap).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/ramdifftest2/"
local FLAG = 0x0202B32D
local EW = 0x02038EBC
local IW = 0x03000E90
local function poke_all()
  memory.write_u8(FLAG, 0x02, "System Bus")
  memory.write_u8(EW, 0xFF, "System Bus")
  memory.write_u8(IW, 0xFF, "System Bus")
end
local function step(n, buttons)
  for i = 1, n do
    if buttons then joypad.set(buttons) end
    poke_all()
    emu.frameadvance()
  end
end
local function tap(btn, n)
  n = n or 10
  for i = 1, n do joypad.set({ [btn] = true }); poke_all(); emu.frameadvance() end
  for i = 1, 15 do poke_all(); emu.frameadvance() end
end
local function hold(btns, n)
  for i = 1, n do joypad.set(btns); poke_all(); emu.frameadvance() end
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
client.screenshot(out .. "after_warp.png")
hold({ Down = true }, 20)
client.screenshot(out .. "walk.png")

client.exit()

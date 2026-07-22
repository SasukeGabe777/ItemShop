local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/talkswitch2/"
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
local function hold(btns, n)
  for i = 1, n do joypad.set(btns); poke(); emu.frameadvance() end
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
for i = 1, 13 do tap("Right") end   -- zone 14
tap("A")
step(150)

-- approach Vegeta step by step, screenshotting + trying A after each move
hold({ Right = true }, 12)
client.screenshot(out .. "a00.png")
hold({ Down = true }, 8)
client.screenshot(out .. "a01.png")
tap("A")
client.screenshot(out .. "a02_try_a.png")
hold({ Right = true }, 6)
client.screenshot(out .. "a03.png")
tap("A")
client.screenshot(out .. "a04_try_a.png")
hold({ Up = true }, 4)
client.screenshot(out .. "a05.png")
tap("A")
client.screenshot(out .. "a06_try_a.png")
step(20)
client.screenshot(out .. "a07_settle.png")

client.exit()

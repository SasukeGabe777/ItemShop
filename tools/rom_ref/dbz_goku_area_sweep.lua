-- Sweep AREA x VARIATION at ZONE=1 (Pepper Town cutscene where we saw
-- Gohan+Trunks) looking for an earlier/different scene that might be Goku.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/areasweep/"
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
local function soft_reset()
  step(60, { Start = true, Select = true, A = true, B = true })
end

local combos = {
  { area = 0, variation = 0 },
  { area = 1, variation = 1 },
  { area = 2, variation = 0 },
  { area = 3, variation = 0 },
}

for _, c in ipairs(combos) do
  to_debug()
  tap("Down"); tap("Down"); tap("Down")   -- AREA field (zone stays default 1)
  if c.area == 0 then
    tap("Left")
  else
    for i = 1, c.area - 1 do tap("Right") end
  end
  tap("Down")                             -- VARIATION field
  for i = 1, c.variation do tap("Right") end
  client.screenshot(string.format("%smenu_a%d_v%d.png", out, c.area, c.variation))
  tap("A")
  step(150)
  client.screenshot(string.format("%swarp_a%d_v%d.png", out, c.area, c.variation))
  soft_reset()
end

client.exit()

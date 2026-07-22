-- Deeper recon pass for the dragon_ball enemy roster, using the CONFIRMED
-- zone map (tools/rom_ref/out/dbz_goku/survey/z*.png, cross-checked against
-- dbz_enemy_recon.lua's z02/04/06-10 results):
--   2 East District 439, 3 Northern Wastelands, 4 West City,
--   7 Southern Continent, 8 Northern Mountains, 12 Tropical Islands.
-- (zone 3 in the FIRST recon run showed "THE CELL GAMES ARENA" -- a one-off
-- debug-menu cursor jitter, not the real zone 3; this run re-verifies the
-- spawn banner every time and walks much farther per direction than the
-- first pass, since the only enemy found so far -- a wild snake fighting
-- Piccolo -- turned up in unscripted real play, not a 90-120f scripted walk.)
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_enemy_recon2/"
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

-- walk in dir for n frames, screenshotting every `every` frames
local function explore(tag, dir, n, every)
  for i = 1, n do
    step(1, { [dir] = true })
    if i % every == 0 then
      client.screenshot(string.format("%s%s_%s_%03d.png", out, tag, dir, i))
    end
  end
end

local zones = { 2, 3, 4, 7, 8, 12 }

for _, zone in ipairs(zones) do
  to_debug()
  tap("Down"); tap("Down")
  if zone == 0 then
    tap("Left")
  else
    for i = 1, zone - 1 do tap("Right") end
  end
  tap("A")
  step(150)
  local tag = string.format("z%02d", zone)
  client.screenshot(string.format("%s%s_00_spawn.png", out, tag))
  -- longer legs than the first recon pass; still a cross pattern but 3x farther
  explore(tag, "Down", 300, 40)
  explore(tag, "Right", 300, 40)
  explore(tag, "Right", 300, 40) -- keep going right (city/field can be wide)
  explore(tag, "Up", 300, 40)
  explore(tag, "Up", 300, 40)
  explore(tag, "Left", 300, 40)
  explore(tag, "Left", 300, 40)
  explore(tag, "Down", 200, 40)
  soft_reset()
end

client.exit()

-- Recon sweep of overworld zones looking for the dragon_ball enemy roster
-- (saibaman, rr_robot, frieza_soldier, cell_junior, dbz_dinosaur). Reuses the
-- proven debug-menu MAP TEST navigation from dbz_goku_zone_survey.lua, but
-- after each warp walks a cross pattern and screenshots periodically instead
-- of a single static shot, since enemies are usually off the initial spawn
-- tile.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_enemy_recon/"
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

local zones = { 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14 }

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
  explore(tag, "Down", 90, 30)
  explore(tag, "Right", 120, 30)
  explore(tag, "Up", 120, 30)
  explore(tag, "Left", 60, 30)
  soft_reset()
end

client.exit()

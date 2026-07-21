-- Mission 2 scouting: recon_fields_zelda.lua's south leg (10 x 120-frame
-- holds) only just crosses into "South Hyrule Field" by r_south_10. Push much
-- further south (and fan west/east a bit once in the field) looking for
-- aggressive Octoroks/Takkuri crows -- the ranch-area Octorok (east leg,
-- Lon Lon Ranch) was tried at length (capture_link_damage.lua..damage5.lua)
-- and never attacked; don't revisit that spot. Screenshots only, no BG dumps
-- -- this is pure scouting to pick a damage-attempt route.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/recon/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

local function shot(tag)
  client.screenshot(out .. tag .. ".png")
end

wait(900)
hold({Start = true}, 30); wait(150)
hold({A = true}, 6); wait(60); hold({A = true}, 6); wait(90); hold({A = true}, 6); wait(120)
for j = 0, 34 do hold({A = true}, 4); wait(18) end
wait(60)

-- reach South Hyrule Field (proven route: 10 x 120-frame Down holds)
for i = 1, 10 do hold({Down = true}, 120); wait(10) end
shot("sf_enter")

-- push further south/around inside the field, screenshotting every leg
local legs = {
  {Down = true}, {Down = true}, {Down = true}, {Left = true}, {Down = true},
  {Down = true}, {Right = true}, {Down = true}, {Down = true}, {Left = true},
  {Down = true}, {Down = true}, {Right = true}, {Down = true}, {Down = true},
}
for i, dir in ipairs(legs) do
  hold(dir, 90); wait(10)
  shot(string.format("sf_%02d", i))
end

client.exit()

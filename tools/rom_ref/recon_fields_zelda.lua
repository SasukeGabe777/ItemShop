-- Recon pass (screenshots only, no BG dumps): boot Minish Cap File 1 to
-- free-roam in Hyrule Town, then push far past the town's north/south/east/
-- west exits, screenshotting every ~2s of travel, so we can eyeball where
-- field/ranch-like terrain (open grass, hedgerows, wooden fences) actually
-- lives before spending a full BG-dump tour there. Four independent legs,
-- each restarting from the town-center spawn point (reached by walking back)
-- so each leg's frames are easy to read as "N screens direction X of spawn".
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/recon/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

local function shot(tag)
  client.screenshot(out .. tag .. ".png")
end

-- title -> file select -> select File 1 -> clear cutscene -> free-roam
wait(900)
hold({Start = true}, 30); wait(150)
hold({A = true}, 6); wait(60); hold({A = true}, 6); wait(90); hold({A = true}, 6); wait(120)
for j = 0, 34 do hold({A = true}, 4); wait(18) end
wait(60)

shot("r_spawn")

-- Leg 1: south, far
for i = 1, 10 do hold({Down = true}, 120); wait(10); shot("r_south_" .. i) end
-- walk back north the same distance to return near spawn
for i = 1, 10 do hold({Up = true}, 120); wait(10) end
wait(10); shot("r_back1")

-- Leg 2: east, far
for i = 1, 10 do hold({Right = true}, 120); wait(10); shot("r_east_" .. i) end
for i = 1, 10 do hold({Left = true}, 120); wait(10) end
wait(10); shot("r_back2")

-- Leg 3: north, far
for i = 1, 10 do hold({Up = true}, 120); wait(10); shot("r_north_" .. i) end
for i = 1, 10 do hold({Down = true}, 120); wait(10) end
wait(10); shot("r_back3")

-- Leg 4: west, far
for i = 1, 10 do hold({Left = true}, 120); wait(10); shot("r_west_" .. i) end

client.exit()

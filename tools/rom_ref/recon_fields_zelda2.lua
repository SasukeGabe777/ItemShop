-- Recon pass part 2: north + west legs only (south/east already recon'd by
-- recon_fields_zelda.lua part 1). Same nav prelude, screenshots only.
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

-- Leg 3: north, far
for i = 1, 10 do hold({Up = true}, 120); wait(10); shot("r_north_" .. i) end
for i = 1, 10 do hold({Down = true}, 120); wait(10) end
wait(10); shot("r_back3")

-- Leg 4: west, far
for i = 1, 10 do hold({Left = true}, 120); wait(10); shot("r_west_" .. i) end

client.exit()

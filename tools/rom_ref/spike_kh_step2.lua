local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

wait(900)
hold({Start = true}, 10); wait(90)
hold({Start = true}, 10); wait(90)
hold({Up = true}, 8); wait(20)
hold({Up = true}, 8); wait(20)
client.screenshot(out .. "kh_step2_cursor.png")  -- should now be on NEW GAME: SORA
savestate.save(out .. "kh_at_menu.State")
wait(3)
client.exit()

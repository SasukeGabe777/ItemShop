local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_realsave_progress4.State")
hold({B = true}, 10); wait(60)
client.screenshot(out .. "kh_rs9_b.png")
hold({Down = true}, 40); wait(30)
client.screenshot(out .. "kh_rs9_walk.png")
hold({Left = true}, 60); wait(30)
client.screenshot(out .. "kh_rs9_walk2.png")
savestate.save(out .. "kh_realsave_walked.State")
wait(3)
client.exit()

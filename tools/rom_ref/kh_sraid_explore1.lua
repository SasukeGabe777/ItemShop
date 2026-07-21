-- Strike Raid recon pass 1: from the tutorial-battle progress save, catalog
-- the visible hand by cycling R (screenshot each step), then test whether
-- HOLDING R over cards stocks them (vs. the tutorial's stated "R = cycle").
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "kh_battle_progress7.State")
client.screenshot(out .. "sraid1_start.png")

-- catalog the hand: tap R once at a time, screenshot after each, 9 taps
for i = 1, 9 do
  hold({R = true}, 6); wait(14)
  client.screenshot(out .. string.format("sraid1_cyc_%02d.png", i))
end

wait(30)
client.screenshot(out .. "sraid1_after_cycle.png")

-- test: hold R continuously across multiple cards, screenshot every 10f,
-- to see if a "stock" indicator builds up (vs. plain cycling in place)
for i = 1, 6 do
  hold({R = true}, 10)
  client.screenshot(out .. string.format("sraid1_hold_%02d.png", i))
end
wait(20)
client.screenshot(out .. "sraid1_after_hold.png")

savestate.save(out .. "sraid1_progress.State")
wait(3)
client.exit()

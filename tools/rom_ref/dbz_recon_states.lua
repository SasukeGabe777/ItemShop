-- Recon of user-made savestates (DBZ LoG II):
--   slot 8 = character-switch screen (save point), slot 9 = overworld (flying),
--   slot 0 = Northern Wastelands with Piccolo (hold B = Special Beam Cannon).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(btns, n)
  for i = 1, n do joypad.set(btns); emu.frameadvance() end
end

wait(300)                                    -- let the core boot past logos

savestate.loadslot(8); wait(10)
client.screenshot(out .. "st8_charswitch.png")

savestate.loadslot(9); wait(10)
client.screenshot(out .. "st9_overworld_idle.png")
hold({ Right = true }, 40)
client.screenshot(out .. "st9_overworld_move1.png")
hold({ Down = true }, 40)
client.screenshot(out .. "st9_overworld_move2.png")

savestate.loadslot(0); wait(10)
client.screenshot(out .. "st0_wastelands_idle.png")
hold({ B = true }, 30)
client.screenshot(out .. "st0_beam_030.png")
hold({ B = true }, 40)
client.screenshot(out .. "st0_beam_070.png")
hold({ B = true }, 50)
client.screenshot(out .. "st0_beam_120.png")
wait(40)
client.screenshot(out .. "st0_beam_release.png")
client.exit()

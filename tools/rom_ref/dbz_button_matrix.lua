-- Button matrix probe: which GBA button fires Piccolo's Special Beam Cannon?
-- For each candidate: load slot 0, hold 240f (shots at 60/240), release with
-- per-frame shots for 30f.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz/btnmatrix/"
local function wait(n) for i = 1, n do emu.frameadvance() end end

wait(300)
for _, btn in ipairs({ "A", "L", "R" }) do
  savestate.loadslot(0); wait(10)
  for i = 1, 240 do
    joypad.set({ [btn] = true })
    emu.frameadvance()
    if i == 60 or i == 240 then
      client.screenshot(string.format("%s%s_hold_%03d.png", out, btn, i))
    end
  end
  for i = 1, 30 do
    emu.frameadvance()
    if i % 3 == 0 then
      client.screenshot(string.format("%s%s_rel_%02d.png", out, btn, i))
    end
  end
end
client.exit()

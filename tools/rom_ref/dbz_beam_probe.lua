-- Beam-timing probe v2: every-frame screenshots around B release, plus a tap
-- test, to catch the Special Beam Cannon however briefly it renders.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz/beamprobe/"
local function wait(n) for i = 1, n do emu.frameadvance() end end

wait(300)

-- Test 1: long hold (600f), then per-frame release captures
savestate.loadslot(0); wait(10)
for i = 1, 600 do
  joypad.set({ B = true })
  emu.frameadvance()
  if i % 100 == 0 then
    client.screenshot(string.format("%slong_%03d.png", out, i))
  end
end
for i = 1, 45 do
  emu.frameadvance()
  client.screenshot(string.format("%sxrel_%02d.png", out, i))
end

-- Test 2: quick tap (8f), per-frame captures after
savestate.loadslot(0); wait(10)
for i = 1, 8 do joypad.set({ B = true }); emu.frameadvance() end
for i = 1, 45 do
  emu.frameadvance()
  client.screenshot(string.format("%stap_%02d.png", out, i))
end
client.exit()

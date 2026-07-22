-- Verify Goku's Kamehameha L-cycle count from savestates/goku_capture.State.
-- L cycles the selected ki attack icon (top-right HUD); B fires/holds it.
-- Wrong selection = red power-up state, not a blue beam. Try 0..3 L presses.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/kameverify/"
local FLAG = 0x0202B32D
local EW = 0x02038EBC
local IW = 0x03000E90
local function poke()
  memory.write_u8(FLAG, 0x02, "System Bus")
  memory.write_u8(EW, 4, "System Bus")
  memory.write_u8(IW, 4, "System Bus")
end
local function wait(n) for i = 1, n do poke(); emu.frameadvance() end end
local function press(btn, hold)
  hold = hold or 8
  for i = 1, hold do joypad.set({ [btn] = true }); poke(); emu.frameadvance() end
  for i = 1, 15 do poke(); emu.frameadvance() end
end

for cycles = 0, 3 do
  savestate.load("C:\\Users\\Game Station\\Desktop\\crossroads\\savestates\\goku_capture.State")
  wait(10)
  for c = 1, cycles do press("L") end
  client.screenshot(string.format("%sc%d_after_L.png", out, cycles))
  for i = 1, 60 do
    joypad.set({ B = true })
    poke()
    emu.frameadvance()
    if i == 20 or i == 40 or i == 60 then
      client.screenshot(string.format("%sc%d_hold_%03d.png", out, cycles, i))
    end
  end
  wait(20)
  client.screenshot(string.format("%sc%d_release.png", out, cycles))
end
client.exit()

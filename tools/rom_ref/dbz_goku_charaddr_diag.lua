-- Diagnostic: the 0x020000B0=0 poke didn't visibly change the field
-- character (still Piccolo after 3 warp variations). Dump a window around
-- that address AFTER warping to zone2 (Piccolo, known value=2) to see if
-- the real "active character" byte is at a nearby offset instead.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/chardiag/"
local FLAG = 0x0202B32D
local function poke() memory.write_u8(FLAG, 0x02, "System Bus") end
local function step(n, buttons)
  for i = 1, n do
    if buttons then joypad.set(buttons) end
    poke()
    emu.frameadvance()
  end
end
local function tap(btn, n)
  n = n or 10
  for i = 1, n do joypad.set({ [btn] = true }); poke(); emu.frameadvance() end
  for i = 1, 15 do poke(); emu.frameadvance() end
end
local function to_debug()
  step(600)
  for i = 1, 8 do
    step(90, { Start = true })
    step(90)
  end
end

to_debug()
tap("Down"); tap("Down")
tap("Right")            -- zone2 (East District 439), Piccolo == value 2
tap("A")
step(150)
client.screenshot(out .. "d00_piccolo.png")

-- dump a generous window around 0x020000B0 for manual inspection, plus a
-- wider EWRAM low-address sweep in case the real var lives elsewhere in the
-- low "global state" region of EWRAM.
local function dumpwindow(base, len, path)
  local f = io.open(path, "w")
  for off = 0, len - 1, 16 do
    local line = string.format("%08X:", base + off)
    for k = 0, 15 do
      if off + k < len then
        local v = memory.read_u8(base + off + k, "System Bus")
        line = line .. string.format(" %02X", v)
      end
    end
    f:write(line .. "\n")
  end
  f:close()
end

dumpwindow(0x02000000, 0x400, out .. "ewram_low_0x000_0x400.txt")
client.exit()

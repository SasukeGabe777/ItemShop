-- Dump EWRAM+IWRAM for THREE clean "active character" states via the slot-8
-- SWITCH CHARACTERS screen (icons: 1=Gohan 2=Piccolo 3=Vegeta 4=Trunks
-- 5=Hercule; cursor starts on Gohan/icon1).
-- Mapping (user-provided): goku=0 gohan=1 piccolo=2 vegeta=3 trunks=4 hercule=5
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/ramdiff/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function tap(btn, n)
  n = n or 10
  for i = 1, n do joypad.set({ [btn] = true }); emu.frameadvance() end
  for i = 1, 15 do emu.frameadvance() end
end

local function dumpmem_chunked(addr, len, domain, path, chunk)
  chunk = chunk or 0x10000
  local f = io.open(path, "wb")
  local off = 0
  while off < len do
    local n = math.min(chunk, len - off)
    local t = memory.readbyterange(addr + off, n, domain)
    local base = (t[0] ~= nil) and 0 or 1
    local chars = {}
    for i = 0, n - 1 do chars[i + 1] = string.char(t[base + i]) end
    f:write(table.concat(chars))
    off = off + n
  end
  f:close()
end

local function dump_state(tag)
  dumpmem_chunked(0x02000000, 0x40000, "System Bus", out .. "ewram_" .. tag .. ".bin")
  dumpmem_chunked(0x03000000, 0x8000, "System Bus", out .. "iwram_" .. tag .. ".bin")
  client.screenshot(out .. "field_" .. tag .. ".png")
end

local function pick_character(rights, tag)
  wait(300)
  savestate.loadslot(8)
  wait(20)
  client.screenshot(out .. "menu_" .. tag .. ".png")
  for i = 1, rights do tap("Right") end
  client.screenshot(out .. "cursor_" .. tag .. ".png")
  tap("A")   -- SWITCH
  wait(90)
  dump_state(tag)
end

pick_character(0, "gohan")    -- icon1, value 1
pick_character(2, "vegeta")   -- icon3, value 3
pick_character(3, "trunks")   -- icon4, value 4 (extra pair per step 4)

client.exit()

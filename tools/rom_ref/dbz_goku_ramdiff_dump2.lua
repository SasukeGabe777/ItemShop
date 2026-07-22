-- Corrected: default cursor on the SWITCH CHARACTERS screen sits on icon2
-- (Piccolo, the character actually active when slot 8 was saved), not icon1.
-- Icons left->right: 1=Gohan 2=Piccolo(default) 3=Vegeta 4=Trunks 5=Hercule.
-- Mapping (user-provided): goku=0 gohan=1 piccolo=2 vegeta=3 trunks=4 hercule=5
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/dbz_goku/ramdiff2/"
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

-- moves: table of {btn, n} applied in order from the default (icon2/Piccolo)
-- cursor position
local function pick_character(moves, tag)
  wait(300)
  savestate.loadslot(8)
  wait(20)
  for _, m in ipairs(moves) do
    for i = 1, m[2] do tap(m[1]) end
  end
  client.screenshot(out .. "cursor_" .. tag .. ".png")
  tap("A")   -- SWITCH
  wait(90)
  dump_state(tag)
end

pick_character({ { "Left", 1 } }, "gohan1")    -- icon1, value 1
pick_character({ { "Right", 1 } }, "vegeta3")  -- icon3, value 3
pick_character({ { "Right", 2 } }, "trunks4")  -- icon4, value 4

client.exit()

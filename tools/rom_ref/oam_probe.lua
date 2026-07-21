-- Probe: confirm GBA memory-domain names + basic reads before building the dumper.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
for i = 1, 900 do emu.frameadvance() end

local f = io.open(out .. "domains.txt", "w")
f:write("systemid=" .. tostring(emu.getsystemid()) .. "\n")
f:write("-- memory domains --\n")
local list = memory.getmemorydomainlist()
for k, v in pairs(list) do f:write(tostring(k) .. " = " .. tostring(v) .. "\n") end
f:write("-- sizes --\n")
for _, name in ipairs({"OAM", "VRAM", "PALRAM", "IWRAM", "EWRAM", "System Bus"}) do
  local ok, sz = pcall(memory.getmemorydomainsize, name)
  f:write(name .. ": " .. tostring(ok and sz or "N/A") .. "\n")
end
-- DISPCNT (REG at 0x04000000) via System Bus
local ok, dispcnt = pcall(memory.read_u16_le, 0x04000000, "System Bus")
f:write("DISPCNT=" .. tostring(ok and string.format("0x%04X", dispcnt) or "err") .. "\n")
-- first 16 OAM bytes
local okv, oam = pcall(memory.read_u16_le, 0, "OAM")
f:write("OAM[0] u16=" .. tostring(okv and string.format("0x%04X", oam) or "err") .. "\n")
f:close()
client.exit()

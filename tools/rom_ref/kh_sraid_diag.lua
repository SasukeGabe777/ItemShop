-- Diagnostic: dump available joypad button names for this core so we know
-- the exact Select spelling BizHawk expects.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local f = io.open(out .. "sraid_diag_buttons.txt", "w")
local buttons = joypad.getavailablebuttons and joypad.getavailablebuttons() or joypad.get()
for k, v in pairs(buttons) do
  f:write(tostring(k) .. " = " .. tostring(v) .. "\n")
end
f:close()
client.exit()

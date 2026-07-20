-- Diagnose input: dump exact button names, test longer holds without port arg.
local out = "C:/Users/sasuk/OneDrive/Desktop/ItemShop/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end

-- 1) write the exact controller button names BizHawk exposes for this core
local f = io.open(out .. "buttons.txt", "w")
f:write("systemid=" .. tostring(emu.getsystemid()) .. "\n")
local ok, btns = pcall(joypad.get, 1)
if ok and btns then
  for k, v in pairs(btns) do f:write("[" .. tostring(k) .. "]\n") end
else
  f:write("joypad.get(1) failed: " .. tostring(btns) .. "\n")
end
f:close()

wait(900)
for i = 1, 30 do joypad.set({Start = true}); emu.frameadvance() end
wait(60); client.screenshot(out .. "dbg1.png")
for i = 1, 30 do joypad.set({Start = true}); emu.frameadvance() end
wait(60); client.screenshot(out .. "dbg2.png")
client.exit()

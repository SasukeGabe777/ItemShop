-- Diagnose input v2: dump joypad.get() with no port arg (v1 used port 1 and
-- got an empty table back), and take a quick R-button test at spawn.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

local f = io.open(out .. "buttons2.txt", "w")
f:write("systemid=" .. tostring(emu.getsystemid()) .. "\n")
local ok, btns = pcall(joypad.get)
if ok and btns then
  local n = 0
  for k, v in pairs(btns) do f:write("[" .. tostring(k) .. "]=" .. tostring(v) .. "\n"); n = n + 1 end
  f:write("count=" .. n .. "\n")
else
  f:write("joypad.get() failed: " .. tostring(btns) .. "\n")
end
-- also list joypad.getimmediate if available
local ok2, btns2 = pcall(joypad.getimmediate)
if ok2 and btns2 then
  f:write("--- getimmediate ---\n")
  for k, v in pairs(btns2) do f:write("[" .. tostring(k) .. "]=" .. tostring(v) .. "\n") end
end
f:close()

wait(900)
hold({Start = true}, 30); wait(150)
hold({A = true}, 6); wait(60); hold({A = true}, 6); wait(90); hold({A = true}, 6); wait(120)
for j = 0, 34 do hold({A = true}, 4); wait(18) end
wait(60)

-- quick test: face down, then R alone (no direction) for 30 frames, screenshot every 5
hold({Down = true}, 6); wait(6)
for i = 0, 29 do
  joypad.set({R = true})
  emu.frameadvance()
  if i % 5 == 0 then client.screenshot(out .. "rtest_" .. i .. ".png") end
end
client.exit()

-- Recon pass 23: pass 16 got Sora onto the checkered floor near a torch
-- (sraid16_progress, after step 6 "Up"). Reload from BEFORE that dead-end
-- detour (sraid16 steps 1-6 state doesn't exist standalone, so replay from
-- sraid14_progress with the exact winning prefix) and then push further
-- toward the blue diamond marker seen top-of-screen.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid14_progress.State")
hold({A = true}, 6); wait(30)

-- replay the exact prefix that reached the checkered floor in pass 16
local prefix = {
  {"Right", 40}, {"Down", 40}, {"Right", 40}, {"Down", 40},
  {"Right", 40}, {"Up", 40},
}
for _, s in ipairs(prefix) do
  local btn = {}; btn[s[1]] = true
  hold(btn, s[2]); wait(10)
end
client.screenshot(out .. "sraid23_onfloor.png")

-- now push toward the diamond marker: try Up and Left more
local steps = {
  {"Up", 30}, {"Left", 30}, {"Up", 30}, {"Left", 30},
  {"Up", 30}, {"Right", 30},
}
for i, s in ipairs(steps) do
  local btn = {}; btn[s[1]] = true
  hold(btn, s[2]); wait(8)
  client.screenshot(out .. string.format("sraid23_%02d_%s.png", i, s[1]))
end

savestate.save(out .. "sraid23_progress.State")
wait(3)
client.exit()

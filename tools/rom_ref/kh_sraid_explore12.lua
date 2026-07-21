-- Recon pass 12: Sora is right next to a lamppost near the door. Nudge
-- around it (Up, then Right) and strike the door with A per the tutorial
-- ("To open doors in the field, strike them with your Keyblade").
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid11_progress.State")
client.screenshot(out .. "sraid12_00.png")

local steps = {
  {"Up", 10}, {"Right", 10}, {"Up", 10}, {"Right", 10},
  {"A", 15}, {"A", 15}, {"Up", 15}, {"A", 15},
}
for i, s in ipairs(steps) do
  local btn = {}
  btn[s[1]] = true
  hold(btn, s[2]); wait(10)
  client.screenshot(out .. string.format("sraid12_%02d_%s.png", i, s[1]))
end

savestate.save(out .. "sraid12_progress.State")
wait(3)
client.exit()

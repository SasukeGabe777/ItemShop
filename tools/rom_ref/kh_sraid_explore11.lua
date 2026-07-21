-- Recon pass 11: redo navigation to the door from sraid9_progress with
-- smaller, careful steps so we can see exactly which direction closes the
-- gap (pass 10's long Right run walked Sora into a dead-end corner).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end

savestate.load(out .. "sraid9_progress.State")
client.screenshot(out .. "sraid11_00.png")

local steps = {
  {"Up", 15}, {"Up", 15}, {"Right", 15}, {"Right", 15},
  {"Up", 15}, {"Right", 15}, {"Up", 15}, {"Right", 15},
}
for i, s in ipairs(steps) do
  local btn = {}
  btn[s[1]] = true
  hold(btn, s[2]); wait(5)
  client.screenshot(out .. string.format("sraid11_%02d_%s.png", i, s[1]))
end

savestate.save(out .. "sraid11_progress.State")
wait(3)
client.exit()

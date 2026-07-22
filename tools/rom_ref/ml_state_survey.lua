-- Screenshot every stored M&L savestate in one boot: load -> settle -> shot.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/oam_ml_live/survey/"
local base = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local states = {
  "ml_explore_far", "ml_barrier_room", "ml_full_end", "ml_at_room",
  "ml_intro_progress5", "ml_newgame_started",
}
for i = 1, 120 do emu.frameadvance() end
for _, name in ipairs(states) do
  local ok = pcall(function() savestate.load(base .. name .. ".State") end)
  if ok then
    for i = 1, 40 do emu.frameadvance() end
    client.screenshot(out .. name .. ".png")
  end
end
client.exit()

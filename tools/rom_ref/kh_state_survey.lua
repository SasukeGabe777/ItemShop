-- Screenshot every stored KH savestate in one boot: load -> settle -> shot.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/oam_kh_live/survey/"
local base = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local states = {
  "kh_realsave_room", "kh_realsave_walked", "kh_realsave_progress",
  "kh_realsave_progress2", "kh_realsave_progress3", "kh_realsave_progress4",
  "kh_realsave_progress5", "kh_realsave_progress6", "kh_at_menu",
  "kh_battle_progress5", "kh_battle_progress6", "kh_battle_progress7",
  "sraid31_progress", "sraid34_progress", "sraid18_progress",
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

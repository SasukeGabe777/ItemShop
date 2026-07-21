-- Explore New Game -> Sora intro flow, mashing A/Start through dialogue,
-- looking for the tutorial card battle (guaranteed early in real KH CoM).
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end
local function mash(b, n, gap)
  for i = 1, n do hold(b, 4); wait(gap) end
end

wait(900)
hold({Start = true}, 10); wait(90)   -- title -> menu (NEW GAME:SORA / NEW GAME:RIKU / LOAD / LINK)
client.screenshot(out .. "kh_n00_menu.png")
hold({A = true}, 10); wait(90)       -- confirm NEW GAME: SORA (top entry, default cursor)
client.screenshot(out .. "kh_n01.png")
mash({A = true}, 40, 30)
client.screenshot(out .. "kh_n02.png")
mash({A = true}, 40, 30)
client.screenshot(out .. "kh_n03.png")
mash({A = true}, 40, 30)
client.screenshot(out .. "kh_n04.png")
wait(3)
client.exit()

-- 13F Namine cutscene, SELECT hypothesis (agent #3). Two prior agents burned
-- their budget: #1 tried ~9 A/B/movement strategies on this exact freeze
-- (spike_kh_realsave1..9.lua) and never got past the "Your heart can
-- withstand even Marluxia's power. I just know it!" box (frozen with a
-- blinking prompt icon bottom-right; Down/Left do nothing -- see
-- kh_rs9_walk.png / kh_rs9_walk2.png, identical despite different held
-- directions). #2 later found CoM's battle tutorial needs a SELECT press to
-- advance "Press SELECT to change categories" prompts (kh_sraid_explore3/4.lua,
-- pattern: hold({Select=true},6); wait(60)). Nobody has tried SELECT on this
-- 13F dialog box. This script tries exactly that, several ways, from the
-- frozen state.
local out = "C:/Users/Game Station/Desktop/crossroads/tools/rom_ref/out/"
local function wait(n) for i = 1, n do emu.frameadvance() end end
local function hold(b, n) for i = 1, n do joypad.set(b); emu.frameadvance() end end
local function snap(tag) client.screenshot(out .. "kh13f_" .. tag .. ".png") end

savestate.load(out .. "kh_realsave_progress4.State")
wait(90)  -- let any in-flight typing finish naturally first
snap("00_start")

-- Strategy 1: SELECT alone, single tap, generous settle
hold({Select = true}, 6); wait(60)
snap("01_select_once")

-- Strategy 2: SELECT again (in case first SELECT only "armed" something)
hold({Select = true}, 6); wait(60)
snap("02_select_twice")

-- Strategy 3: a third SELECT tap
hold({Select = true}, 6); wait(60)
snap("03_select_thrice")

-- Strategy 4: SELECT held longer (10f) in case a short tap isn't registered
hold({Select = true}, 10); wait(60)
snap("04_select_hold10")

-- Strategy 5: SELECT + A same frame (some CoM prompts want a combo)
hold({Select = true, A = true}, 6); wait(60)
snap("05_select_plus_a")

-- Strategy 6: alternate SELECT, A, SELECT, A (one per dialog "page")
hold({Select = true}, 6); wait(30)
hold({A = true}, 6); wait(30)
hold({Select = true}, 6); wait(30)
hold({A = true}, 6); wait(30)
snap("06_select_a_alternate")

-- Strategy 7: Start then SELECT (menu-open-then-select pattern)
hold({Start = true}, 6); wait(30)
hold({Select = true}, 6); wait(60)
snap("07_start_then_select")

-- Strategy 8: SELECT then B (select the option, then confirm/cancel)
hold({Select = true}, 6); wait(30)
hold({B = true}, 6); wait(60)
snap("08_select_then_b")

-- Strategy 9: rapid-fire SELECT taps (10x, short gap) in case it needs repetition
for i = 1, 10 do
  hold({Select = true}, 4); wait(10)
end
wait(30)
snap("09_select_rapidfire")

-- Strategy 10: SELECT held very long (like a menu-toggle hold)
hold({Select = true}, 45); wait(60)
snap("10_select_longhold")

savestate.save(out .. "kh13f_select_end.State")
wait(3)
client.exit()

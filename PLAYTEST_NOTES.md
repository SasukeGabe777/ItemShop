# Playtest Notes

---

## 2026-07-22 - First human playtest of the Pokémon world (controller)

### Date

2026-07-22

### Build tested

- Commit/build: `80d72c8` (Pokémon world), exported exe on a controller
- Godot version: 4.7.1-stable

### Player feedback (verbatim findings)

- **Nova specials feel worth it** (Discharge / Fire Spin) — keeping.
- **Charmander's left/right walk used diagonal sprites** — the PMD sheet row
  I read as "east" is actually a diagonal. FIXED same day: side anims now
  flipped from the true W row (`prep_pokemon_world.py`), verified on sheet.
- **Dodge dash travels too far, across the board** (named: Sora, Mario,
  Luigi, Link + the Pokémon pair). FIXED: all rolls brought to Goku/Piccolo's
  reference distance 60 (`tools/tune_dodge_2026_07_22.py`).
- **All bosses in all dungeons too big / overpixelated.** FIXED: `enemy.gd`
  now caps rendered boss height at 84px (hurtboxes follow the scale);
  verified with `tests/boss_lineup_shot.tscn` — all 17 manifested bosses now
  read 1.5-2x hero height, less magnified so less pixelated.
- **Pokémon rooms feel empty.** FIXED same day with the user's FRLG location
  drop: real map-crop rooms added (Pallet Town start, Pokémon Tower +
  Rocket Hideout combat, Rocket Game Corner treasure), obstacle props cut
  from the magenta tileset (pine/bush/boulder/rocks/gravestone), and the
  user's Strength-boulder barrier (`tools/build_pokemon_rooms_frlg.py`).
  Verified in-game: cave rooms now dressed with boulders.
- **Latios probably too strong**, but tested with nothing equipped — balance
  deliberately NOT changed yet per the user's call.
- **Mario & Luigi animations "completely broken."** FIXED with the user's
  new labeled sheet (`mario_luigi_new.png`): full rebuild via
  `tools/prep_mario_luigi_v2.py` — 8-frame walks in all directions
  (S/SW/W/NW/N rows, side flipped from W), 3-frame hammer melee per
  direction, fireball special poses per direction. Verified windowed
  (`tests/playtest_fixes_shot.gd`).

### Round 2 (same day): dodge animation drop

- "Pokemon pass went over incredibly." New dodge art wired for five heroes
  (`tools/add_dodge_anims.py` + prep_mario_luigi_v2): Link 3-direction
  somersault (18 frames), Mario 8-frame 360° twirl, Luigi 4-frame scramble,
  Pikachu + Charmander 4-frame dashes. All verified mid-roll in windowed
  shots (`tests/dodge_anims_shot.tscn`).
- Naruto's vanish distance lowered 85 -> 60 like the rest.
- New global **0.3s dodge cooldown** after the dash ends
  (`combat_hero.gd::dodge_cooldown`) — block + expiry proven headless
  (`tests/dodge_cooldown_probe.tscn`).

### Round 4 (same day): move_VFX drop wired into combat

- User supplied `assets/shared/effects/move_VFX` (258 effect sets) with
  exact references. Wired via strip sheets (`tools/build_move_vfx.py`) +
  a new one-shot `EffectFlipbook` node and animated `Projectile` art:
  - standard enemy shooters: flame bolt / bubble chain (8-direction rows,
    order [S,SW,W,NW,N,NE,E,SE] verified with an in-game direction ring)
    / pulse — stable per-enemy style pick
  - bosses: star-trail + dart volleys with a converging gather flourish,
    explosion flipbook on slam, wind swirl on charge dash
  - standard enemies: melee impact fist on contact, dust poof on
    lunger/ambusher dashes
  - Naruto: substitution log + smoke on vanish dodge (0148 pieces),
    pulsing rasengan ring on Shadow Clone Strike (0240) — both
    data-driven via dodge/special `vfx_*` fields in heroes.json
- All effects screenshot-verified in-game (`tests/vfx_probe_shot.tscn`).

### Round 3 (same day): Luigi moonwalk, Naruto spin, Sora rebuild

- **Luigi's side walk played backwards** (cycle authored right-to-left on
  the sheet) — frame order reversed in `prep_mario_luigi_v2.py`.
- **Naruto spun on basic movement** — his side anims used frame 3, a
  turn-transition pose (AGENT_GUIDE §8 pitfall); remapped to the true side
  frames 4/5.
- **Sora "completely messed up" except his roll** — full rebuild from the
  user's `sora_updated.png` (`tools/prep_sora_v2.py`): 8-frame runs in
  down/up/side, 5-frame keyblade melee in three facings + two combo
  variants (SW/NW rows), Strike Raid body poses, and a real spinning-blade
  projectile sprite. The old roll frames were preserved pixel-identical.
  Verified windowed (`tests/sora_fixes_shot.tscn`).

---

## 2026-07-20 - Shop Boom announcement and crowd flow

### Date

2026-07-20

### Build tested

- Commit/build: `098b911` plus the Boom-system pass
- Godot version: 4.7.1-stable
- Platform: Windows, headless behavior/economy suites and 1280x720 windowed visual probe

### Test route

- Forced **Kids' Adventure Day** through `BoomManager`.
- Opened the real shop with six icon-backed matching goods across its displays.
- Captured the pre-opening day briefing, first fast-wave arrivals, and the
  full live-customer cap through `tests/boom_shop_shot.tscn`.
- Ran `test_booms`, `test_parse_all`, `test_campaign`, `test_dev_hub`, and the
  existing Kingdom Hearts vertical-slice route.

### What worked

- The briefing clearly announced the Boom before opening, named desired
  categories/tags and the Cozy-shop bonus, and explained that the event waits
  for a shop session.
- The live session announced **22 incoming customers**, spawned them in fast
  waves, and visibly reached eight simultaneous shoppers without clipping or
  obvious pathing overlap.
- Focused coverage verified all 14 definitions use valid current content,
  traffic is at least twice normal, customer groups and merchandise are
  strongly weighted, poor preparation causes requests/departures, bundle sales
  account for every physical item, save/load and cooldowns work, and gate repair
  creates the correct world celebration.
- Campaign, Dev Hub, parse-all, and KH shop/expedition/save compatibility tests passed.

### Bugs

- The first visual pass exposed mojibake in new Boom separators. New Boom UI
  strings now use ASCII-safe punctuation; the fresh screenshots are clean.
- The first campaign pass exposed a simulation-only duration bug: live shop
  sessions consumed a Boom, but `ShopSim` did not. Both paths now consume one
  session exactly once, with focused regression coverage.
- The repository's pre-existing boot test reports the actively changing
  enemy/boss roster assumptions; no Boom reference or load errors were present.

### Visual issues

- Eight simultaneous customers make the shop intentionally busy. Names overlap
  in the densest frame, but sprites, displays, the player, and the Boom HUD
  remain readable at 1280x720.

### Next action

- Play one naturally rolled Boom with a controller and normal campaign stock;
  tune only the first event whose traffic, budgets, or requested merchandise
  feels unfair in a human session.

---

## 2026-07-18 - Independent split-screen item pickers

### Date

2026-07-18

### Build tested

- Commit/build: `4061f4e` plus the multiplayer focus-memory fix
- Godot version: 4.7.1-stable
- Platform: Windows, headless automated workflow and exported release smoke boot

### Test route

- Ran `tests/test_parse_all.tscn`.
- In `tests/dual_picker_probe.tscn`, enabled local multiplayer, entered the
  shop, and opened different item-stand pickers for both players on the same
  frame.
- Sent independent D-pad input to each picker, used P1's cancel-to-Close jump,
  closed only P1's picker, and continued navigating P2's picker.
- Ran `tests/p2_input_probe.tscn` through P2 stand and market navigation,
  held-stick repeat, focus recovery, input isolation, and close behavior.
- Exported the Windows release and booted `export/crossroads.exe` headlessly to
  the configured title scene for 120 frames.

### What worked

- Parse coverage ended with `PARSE_TEST_PASS`.
- The simultaneous-picker route ended with `DUAL_PICKER_PROBE_DONE`: both
  players stayed busy while both menus were open, each selector moved from its
  own remembered position, P1 closed only P1's picker, and P2 remained active.
- The existing P2 route ended with `P2_INPUT_PROBE_DONE`; P1-style input did not
  move P2, held-stick repeat advanced focus, lost focus recovered, and P2's
  market closed cleanly.
- The exported executable launched successfully and loaded all current content.

### Bugs

- The first dual-picker verification exposed stale freed Control references
  during scene shutdown. Focus-memory reads now validate the untyped reference
  before casting and erase stale entries; the rerun produced no script errors.
- Godot still prints headless shutdown leak warnings from the short-lived probe
  scenes. They did not affect the exercised state transitions or release boot.

### Visual issues

- Selector independence and menu state were verified headlessly. A two-pad,
  windowed human check of the stand-in focus highlight remains useful.

### Next action

- Run one short two-controller shop session from the exported executable and
  confirm both visible selector highlights read clearly while moving at once.

---

## 2026-07-16 - Location Workshop automated workflow

### Date

2026-07-16

### Build tested

- Commit/build: `83865b5` plus the uncommitted Location Workshop pass
- Godot version: 4.7.1-stable
- Platform: Windows, headless automated workflow

### Test route

- Opened the guided Workshop in a scratch-data harness.
- Selected Kingdom Hearts and verified current enemy availability.
- Saved and reloaded a readable brief and generated its structured proposal.
- Painted ground, walls, decorations, and collision; placed player/customer,
  enemy, chest, item-stand, door, dialogue, and boss markers; moved one marker.
- Saved and reloaded the layout and a review.
- Used **PLAY THIS LOCATION** to instantiate the authored room through
  `LocationLoader` in an isolated development campaign.

### What worked

- The test ended with `LOCATION_WORKSHOP_PASS`.
- The brief, proposal, map, and review all persisted in `user://` scratch data.
- All nine required marker types saved, the moved marker reloaded at its new
  cell, the wall layer rendered, and the player used the authored spawn.
- The launch selected no normal save slot and initialized in-memory dev state.

### Bugs

- An initial test-script inferred an untyped return value and failed parsing.
  The return is now explicitly typed and the focused parse/run passes.
- No blocking runtime error remained in the exercised workflow.

### Visual issues

- This was headless coverage. Native editor sizing, pointer feel, tileset
  readability, and the human clarity of every form still require a manual pass.

### Next action

- Have a human author one tiny real room, click **PLAY THIS LOCATION**, and save
  an approved/revise review. Do not connect it to campaign progression until
  that review exists.

Add new entries above older entries. Use exact build/commit identifiers and
separate verified behavior from assumptions.

## Reusable playtest entry

### Date

`YYYY-MM-DD`

### Build tested

- Commit/build:
- Godot version:
- Platform:

### Test route

Describe the exact start state and actions taken. Include save slot, scene path,
world/chapter, and whether debug commands or automation were used.

### What worked

-

### Bugs

- Include reproduction steps, expected result, actual result, and severity.

### Visual issues

- Include scene, screen size, and a screenshot path when available.

### Next action

- Name one smallest next action and its acceptance check.

---

## 2026-07-16 - Kingdom Hearts playable vertical slice (automated)

### Date

2026-07-16

### Build tested

- Commit/build: `a6ce0cb` plus the uncommitted Kingdom Hearts vertical-slice pass
- Godot version: 4.7.1-stable
- Platform: Windows, headless automated live-scene workflow

### Test route

- Started a Playtest Workspace session through `DevHubManager` and ran
  `tests/test_kh_vertical_slice.tscn`.
- Reset to new-campaign state and verified the scoped starter inventory and
  Sora's equipped Kingdom Key.
- Moved an existing display stand, stocked a Potion, resolved a sale through a
  dynamically selected furniture slot and normal negotiation bookkeeping, and
  advanced shop time.
- Launched the two-room first Kingdom Hearts expedition with Sora, drove the
  live combat scene, defeated one Shadow, collected the guaranteed Lucid Shard,
  exited north, and verified the loot transferred to shop storage.
- Displayed and sold the recovered shard, then saved to a temporary normal slot,
  reset the managers, reloaded, verified persisted state, and restored the
  pre-test slot file.

### What worked

- `KH_VERTICAL_SLICE_PASS` completed.
- Starter inventory, stand movement, display assignment, dynamic customer
  interest, negotiation, money changes, item removal, time advancement, Sora
  selection, live Shadow combat, reward pickup, expedition return, recovered
  loot resale, and save/reload all passed.
- The save roundtrip retained money, storage, a displayed Ether, the moved stand
  position, chapter state, and Kingdom Hearts vertical-slice completion.
- Required Playtest Workspace reports were rewritten under `playtest/latest/`.

### Bugs

- **Fixed during the run / blocking:** the first implementation created the
  guaranteed reward inside a physics collision callback. Godot reported that
  monitoring state could not change while queries were flushing. Reward node
  creation is now deferred to the next safe frame; the rerun passed without the
  error.
- No blocking parser or runtime error remained in the final automated route.

### Visual issues

- This was headless automation, so customer motion quality, exit readability,
  item-placement clarity, and negotiation presentation still require the
  planned human playthrough. The Lucid Shard currently uses the safe placeholder
  fallback when its processed icon is absent.

### Next action

- Personally play `docs/KH_VERTICAL_SLICE.md` without development tools and
  record only the largest observed issue: item placement, customer movement,
  dungeon exit clarity, or sale-screen presentation.

---

## 2026-07-16 - Live Developer Hub automated workflow

### Date

2026-07-16

### Build tested

- Commit/build: `02614ef` plus the uncommitted Live Developer Hub pass
- Godot version: 4.7.1-stable
- Platform: Windows, headless automated workflow

### Test route

- Loaded `tests/test_dev_hub.tscn` in development mode.
- Exercised F1 action handling, default pause, resume-behind-panel, and close.
- Created isolated campaign state, changed money/inventory, created a blank
  development location, and spawned a KH item, named customer, and enemy.
- Selected/moved the item, saved the location, instantiated the real shop,
  spawned/moved existing `DisplayFurniture`, and summoned a real `ShopCustomer`.
- Wrote the separate dev state, ran a playtest session, exported AI context, and
  compared normal save-file fingerprints before and after.

### What worked

- The required smoke test ended with `DEV_HUB_TEST_PASS`.
- All required playtest and AI context files were written.
- Normal save files were unchanged.
- The full parser test continued to report `PARSE_TEST_PASS`.
- The windowed visual tour rendered Today, Location, and Spawn at 640x360 and
  1280x720 and ended with `DEV_HUB_SCREENSHOT_PASS`.

### Bugs

- No blocking parser or runtime errors remained in the exercised workflow.
- The initial headless screenshot attempt produced a dummy-renderer texture
  error; capture is now skipped in headless mode and remains enabled windowed.

### Visual issues

- Windowed screenshots show the persistent navigation and primary controls fit
  at both tested resolutions. Text is necessarily compact at 640x360. Keyboard
  focus, pointer feel, and a human click-through of every tab remain unverified.

### Next action

- Use the Hub during one manual Kingdom Hearts Chapter 1 acceptance route, then
  fix only the first progression blocker and rerun from the nearest save.

---

## 2026-07-16 — Pass 1 repository audit

### Date

2026-07-16

### Build tested

- Commit/build: `30f583a` (`WIP: preserve interrupted content studio work`)
- Godot version: 4.7.1-stable
- Platform: Windows, 1280×720 window override

### Test route

- Ran Godot boot, parse-all, campaign, Asset Factory, standalone Sora importer,
  windowed automated live combat, and the windowed screenshot tour.
- Ran `python -m pytest -q`.
- Visually reviewed current screenshots for story, town, shop, dungeon, and main
  menu.
- This was an automated/inspection audit, not a human-controlled Chapter 1 run.

### What worked

- Boot/data validation and full script/scene parsing passed.
- Campaign logic passed; the final explicit audit run repaired all gates on day
  24.
- Save/load roundtrip, checkpoint retention, negotiation logic, simulated shop
  sessions/orders, crafting, and simulated boss balance passed inside the
  campaign suite.
- Windowed automated Sora combat defeated the Corrupted Fat Bandit and banked KH
  loot, gold, and the World Shard.
- The screenshot tour launched and captured all five target scenes.
- The title screen rendered cleanly and looked substantially more polished than
  the current in-game environments.
- The Sora manifest converted successfully to a six-animation SpriteFrames
  resource in standalone importer batch mode.
- Python tests: 19 passed; one optional live-network test skipped.

### Bugs

- **Asset Factory / medium:** `tests/test_asset_factory.tscn` reports
  `ASSET_FACTORY_TEST_FAIL: auto-detected wrong background color` during the
  opaque-sheet chroma-key test. Expected the preview's detected color to match
  the synthetic gray background; actual detected color differed.
- **Test harness / low:** the Asset Factory process returned shell exit code 0
  despite printing a failure. Automation must inspect output until exit behavior
  is corrected.
- **Headless live-combat test / low:** `test_live_combat.gd` attempts to save a
  viewport screenshot and receives a null texture under the dummy headless
  renderer. The documented windowed run passes.

### Visual issues

- Town and shop rely heavily on repeated ground texture, flat rectangles, and
  placeholder props; several town building shapes are cropped at viewport edges.
- The shop screenshot's HUD/header appeared largely dark/empty. Recheck during a
  hands-on shop session to determine whether this is capture timing or a real UI
  issue.
- The dungeon first room is sparse and uses large flat placeholder wall blocks.
- Current screenshots are under Godot's user data `screenshots` directory for
  `Crossroads- An Item Shop Tale`.

### Next action

- Manually play the complete Kingdom Hearts Chapter 1 acceptance route in
  `NEXT_TASKS.md`; record the first progression blocker and fix only that blocker
  before expanding scope.

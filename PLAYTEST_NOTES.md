# Playtest Notes

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

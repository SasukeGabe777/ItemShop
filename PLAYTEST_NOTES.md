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

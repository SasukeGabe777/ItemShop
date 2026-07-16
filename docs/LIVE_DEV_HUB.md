# Crossroads Live Developer Hub

The Live Developer Hub is a development-only overlay inside the running game. It is separate from the Godot editor's Content Studio / Asset Factory: the Asset Factory prepares source art and content data, while the Hub inspects, places, and tests that content in the game runtime.

## Enable and open it

The checked-in development configuration is:

```ini
[crossroads]
development/enabled=true
development/require_debug_build=true
```

Run the project from the Godot editor or a debug build and press **F1**. The game pauses when the Hub opens. Use **Resume Game Behind Hub** to keep simulation running while the overlay remains visible. Press F1 again to close it.

Release builds remain disabled while `development/require_debug_build` is true. A release build can only opt in explicitly with the `--dev-hub` command-line argument or by changing the project setting and disabling the debug-build requirement. The overlay also carries a visible DEVELOPMENT MODE label.

## Today and World

Today reads maintained claims from `data/dev_status.json` and combines them with the live scene, selected world/location, and campaign clock. Its launch buttons create an isolated in-memory development session and route to the title, shop, Kingdom Hearts dungeon, or KH full-loop starting state.

World lists every `ContentDatabase` world with hero, item, enemy, customer, location, missing-asset, and incomplete-content counts. Selecting a development world filters tools only; it does not persist a campaign unlock.

## Load or create a location

1. Open **Location**.
2. Select the built-in town, shop, a world dungeon, an authored data location, or a saved development location.
3. Choose **Load Selected Location** or **Play This Location**.
4. To author a layout, enter an ID and choose **Create Blank Development Location**.
5. Load it, then place gameplay objects from Spawn.
6. Choose **Save Location Layout**. Development locations are stored in the separate Dev Hub state file.

The first version focuses on gameplay-object placement, not tile painting. Use the Asset Factory's Locations tools to prepare tilesets and authored tile data. Create or open a location brief before map-generation work.

## Spawn and inspect objects

1. Open **Spawn**, choose a type, and search by content ID or display name.
2. Select an entry and choose **Place Selected**.
3. Move the preview in the world. Green is valid and red is invalid; appropriate objects snap to the 8-pixel development grid.
4. Left-click to place. Right-click or Escape cancels.
5. Use **Select Object In World**, then click an editable runtime object.

The inspector exposes the content ID, type, instance ID, transform, collision state, curated content properties, camera focus, duplication, deletion, and source-data path. Doors, triggers, chests, and NPC markers expose a small supported game-property field rather than Godot's raw property list.

Items, customers, heroes, enemies, furniture, chests, NPCs, doors, and triggers use existing content IDs. Shop customers and dungeon/outdoor enemies use their real runtime classes when those runtimes are active; other placement types use a safe development object representation.

## Edit the shop

Load **Crossroads Item Shop** from Location or choose **Play From Shop** on Today. The Shop tab uses `ShopFurnitureManager`, `DisplayFurniture`, and `InventoryManager`:

- place, select, move, or remove furniture;
- assign inventory items to display slots or clear all displays;
- fill inventory with the selected world's goods;
- summon a named customer;
- open or close the selling session;
- inspect reachable customer display targets;
- save and reload the separate development state.

Furniture UIDs, positions, slot counts, and display assignments remain in the existing save-compatible structures. The Hub does not create hardcoded crate positions.

## Player and game state

Player controls operate on the active `TownPlayer` or `CombatHero`: hero selection, heal/revive, speed, collision, teleport, equipment, and reset. Game State can change money, inventory, day/period, temporary world access, relationships, bridge state, and chapter state.

Opening the Hub starts an isolated development session. Hub saves go to:

```text
user://crossroads_dev/live_dev_state.json
```

They never call a normal manual save slot. Automatic normal autosaves and chapter checkpoints are suppressed for the remainder of that isolated development process. Restart the game without entering the Hub to resume normal save behavior. Explicit normal save-slot actions remain owned by the normal game UI and `SaveManager`.

## Playtest session

Open Playtest and choose **Start Playtest Session**. Add categorized notes, capture state at any time, and end the session. Reports are refreshed under `playtest/latest/`:

- `runtime_log.txt`
- `state_snapshot.json`
- `validation_report.json`
- `playtest_notes.md`
- `screenshot.png` when a non-headless renderer can capture it

Generated report contents are ignored by Git; the directory itself is retained with `.gitkeep`.

## Logs and missing data

Logs combines Dev Hub actions, DebugManager lines, the current Godot log tail, scene transitions, save/load notices, missing-asset fallbacks, and on-demand Asset Factory content validation. Clearing the visible log does not delete its source files.

Missing status, location, playtest, or AI files resolve to empty/default data instead of preventing the game from launching. PlaceholderFactory remains the fallback for missing art, so the Hub does not require copyrighted assets.


# Expansion guide

Everything gameplay-visible is data. Common additions:

## Add an item
Append to `data/items.json`. Fields: `id, name, world, category
(weapon|armor|accessory|consumable|food|material|treasure|key), tags, price,
appeal {cozy|intense|retro|modern}, stats {atk,def,spd}, effect {heal, meter,
buff_atk, buff_def, revive, aoe_damage, ...}, slot (accessory|charm), desc`.
It immediately becomes sellable, order-able, craftable-into, and lootable.
Put a sprite at `assets/franchises/<world>/processed/items/<id>.png` or let the
placeholder generator draw it.

## Add an enemy
Append to `data/enemies.json` with a `behavior` from: chaser, tank, lunger,
shooter, skitter_shooter, bomber, shy_ghost, swooper, creeper, ambusher,
splitter, teleporter, shell (+ boss_* for bosses). Add its id to a world's
`enemies` list. Loot is `[[item_id, chance], ...]`, gold `[min,max]`.

## Add a world / chapter
Append to `data/worlds.json` (chapter number drives ordering, deadline and
market unlocks), give it a hero in `heroes.json`, a boss, enemies, market
goods, and story scenes keyed to `chapter_start/hero_met/boss_defeated/
repair_done` triggers. `tests/test_boot.gd` will flag any dangling reference.

## Add real sprites (The Spriters Resource, GBA rips, etc.)
1. Download manually into `assets/franchises/<world>/raw/`.
2. Open the importer: `godot --path . res://tools/sprite_importer/sprite_importer.tscn`
   — slice, name animations (idle_down, walk_side, attack_1, ...), set pivot,
   save manifest, export .tres — or write the manifest JSON by hand and run:
   `godot --headless --path . res://tools/sprite_importer/sprite_importer.tscn -- --manifest <path> --out <path.tres>`
3. Manifests in `assets/franchises/<world>/manifests/<entity_id>.json` are
   picked up automatically by `CharacterVisual` (entity id = hero/enemy id).
4. Record source URL + contributor in `credits/ASSET_CREDITS.csv`.

## Music
Replace any track by dropping `<track_id>.ogg|wav` into
`user://music_overrides/` (player-facing) or `assets/music/user_overrides/`
(shipped). Track ids in `data/music_manifest.json`.

## Balance
`data/balance.json` — repair pacing lives in `worlds.json` (repair_cost) and
the prosperity keys (`prosperity_gate_growth`, `customer_budget_chapter_scale`).
After any change run the economy proof:
`godot --headless --path . res://tests/test_campaign.tscn` — it fails if the
35-day campaign can no longer be completed by a competent player policy.

## Story
`data/story_scenes.json`. Triggers: `game_start, chapter_start {chapter},
hero_met {hero}, boss_defeated {chapter}, repair_done {chapter}, day_start
{day}, chapter_failed, ending, endless_start`. Lines: `{who, text}`; `who`
resolves names/colors from heroes.json (heroes or npcs).

## Renames
The game title lives only in project.godot (`application/config/name`).
Patch is data: rename in `data/heroes.json` npcs + story text.

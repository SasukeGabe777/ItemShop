# Crossroads: An Item Shop Tale — Implementation Report

Build date: 2026-07-16. Engine: Godot 4.7.1-stable (downloaded to `tools/`,
gitignored). Language: typed GDScript. All content data-driven from
`data/*.json`.

## What was built

**Systems (14 autoloads)**: GameState, ContentDatabase, TimeManager,
MarketManager, EconomyManager, InventoryManager, RelationshipManager,
BridgeManager, DungeonManager, StoryEventManager, SaveManager, AudioManager,
SceneRouter, DebugManager (F3 console).

**Components (12)**: Health, Damage, Hitbox, Hurtbox, Movement, StatusEffect,
LootTable, Interaction, CustomerBrain, NegotiationProfile, Equipment, plus the
shared attack moveset inside CombatHero.

**Scenes**: main menu (3 slots), Crossroads town hub, shop interior (stocking,
live customer sessions, negotiation, orders, expansion), market / workshop /
guild / gates panels, dungeon runner, story player, plus the sprite importer
tool (GUI + headless batch).

**Content**: 110 items (incl. 12 craftable crossover items + 7 World Shards),
40 regular enemies + 8 bosses, 7 playable heroes + Hero/Patch/Red NPCs,
8 worlds, 40 recipes (22 crossover), 10 customer archetypes + 28 named
customers, 14 market events, 36 story scenes, 32 handcrafted room templates,
18 procedural chiptune placeholder tracks.

## Test results (all passing)

| Test | Command target | Verifies |
|------|----------------|----------|
| BOOT_TEST_PASS | tests/test_boot.tscn | data loads; every loot/recipe/market/world/customer reference resolves |
| PARSE_TEST_PASS | tests/test_parse_all.tscn | every script compiles; every scene instantiates |
| CAMPAIGN_TEST_PASS | tests/test_campaign.tscn | negotiation outcomes; shop session; orders; crafting; save/load roundtrip (gold, time, storage, display, relationships, shards, flags); all 8 bosses defeatable ≥50% by an equipped hero; failure restart retains merchant level / encyclopedia / customer knowledge / exactly N chosen items while rolling gold back; **full auto-played 35-day campaign: all 7 gates repaired by ~day 31, The Fade defeated, ending + endless reachable** |
| LIVE_COMBAT_PASS | tests/test_live_combat.tscn (windowed) | real-time hitboxes, combo damage, specials, consumables, boss AI/telegraphs, death, loot pickups magnetizing and banking (Kingdom Key + World Shard recovered live) |
| screenshot tour | tests/screenshot_tour.tscn (windowed) | story, town, shop, dungeon, main menu all render; Omori Hero sheet animates via its manifest |

## Economy proof

The auto-campaign plays a "sensible player" policy (stock in the morning,
2–3 shop sessions/day, one expedition/day, buys heals, gears heroes, pays
repairs ASAP). Result: repairs of 10k/25k/60k/120k/225k/400k/700k all met
inside their 5-day windows, finishing day ~31 of 35 with ~31k spare. The
growth engine is compounding **prosperity** (x1.4 per repaired gate on all
prices) + dungeon loot as free supply + chapter-scaled customer budgets — all
tunable in `data/balance.json` and re-provable by re-running the test.

## Bugs found and fixed during testing

- SpriteFrames row math (integer division warning path) in the frames builder.
- Chapter-failure restart kept N stacks instead of N items.
- Expedition simulator over-punished high-HP bosses / trash chip (no
  kiting model); added exposure + cap factors.
- Linear prosperity couldn't fund late chapters (repairs grow ~x1.8/chapter);
  switched to compounding per-gate growth.
- UIKit.button crashed on a null callable (negotiation counter button).
- Screenshot tour node freed itself on scene change (runner now parked on root).
- JSON floats broke `int in Array` window-slot checks.
- Test bot never healed / never walked to loot (test-side).

## Known limitations / next steps

- All franchise character/enemy art is generated placeholders until real
  sheets are dropped into `assets/franchises/*/raw` and manifests written with
  the importer (workflow documented in docs/EXPANSION.md). The Hero (Omori)
  sheet is the only real spriteset wired up, as supplied.
- Music is procedural placeholder chiptune; user overrides already work.
- Endless Mode is functional (rent pressure) but lightly featured.
- `export_presets.cfg` is committed; building the exe requires the 4.7.1
  export templates (see docs/EXPANSION.md).
- See "Crossroads Content Studio (Phase 1)" below for the current state of
  the asset-assignment tooling and what Phase 2 should pick up.

## Crossroads Content Studio (Phase 1)

Built 2026-07-16: an editor plugin (`addons/crossroads_content_studio/`) that
turns filling in franchise art/audio from a filesystem chore into an in-editor
workflow. Dock: bottom panel, "Crossroads Content Studio", five tabs.

**Files added**:
- `addons/crossroads_content_studio/plugin.cfg`, `plugin.gd`
- `addons/crossroads_content_studio/core/`: `asset_paths.gd` (path
  conventions, sourced from the same strings as `content_database.gd`),
  `file_ops.gd` (copy/mkdir/header-only image dimensions), `content_scan.gd`
  (editor-time re-parse of `data/*.json` — autoloads don't run in the bare
  editor, so this can't just read the live `ContentDatabase`),
  `credits_index.gd` (merges `ASSET_CREDITS.csv` / `MUSIC_CREDITS.csv` /
  downloader manifests), `validator.gd` (all validation checks below)
- `addons/crossroads_content_studio/ui/`: `main_panel.gd`, `dashboard_tab.gd`,
  `asset_browser_tab.gd`, `asset_assignment_tab.gd`, `ui_assets_tab.gd`,
  `validation_tab.gd`
- `docs/CONTENT_PIPELINE.md` (workflow doc)
- `project.godot`: added `[editor_plugins]` enabling the plugin
- `tests/test_parse_all.gd`: now also scans `res://addons` so plugin parse
  errors surface in the existing test suite

**Features**: content counts + missing-asset/broken-reference summary with
quick-open buttons (Dashboard); franchise-filtered raw/processed browsing with
preview, dimensions, and credit metadata, plus copy-to-processed
(Asset Browser); per-entity/item list with expected path, exists-check, and
assign-from-raw copy with overwrite confirmation (Asset Assignment); shared
UI asset preview grid with folder scaffolding and a "keep menu text as real
UI nodes" reminder (UI Assets); full validator with severity-filtered results
(Validation).

**Validation checks added**: missing/invalid data JSON, duplicate ids per
file, items missing required fields (id/name/world/category/price), missing
processed sprite/manifest for heroes/npcs/enemies/bosses, missing processed
item icons, recipes/loot referencing unknown items, worlds referenced by
content but absent from `worlds.json`, music tracks with no resolvable audio
file, missing UI theme/project icon/credits files.

**Known limitations**:
- Not a visual sprite cutter — turning a multi-frame raw sheet into an
  animated `manifests/<id>.json` still goes through
  `tools/sprite_importer/sprite_importer.tscn`, same as before this plugin.
  Asset Assignment/Browser only handle the "one raw file → one processed PNG"
  case (static icons/portraits).
- `content_scan.gd` duplicates `content_database.gd`'s loading rules by
  necessity (autoload singletons aren't instantiated while just editing) —
  if the loading rules ever change, update both.
- GIF preview shows dimensions only (read from the file header); Godot has no
  built-in GIF decoder, so no thumbnail renders for that format.
- No batch/bulk assignment yet (one entry at a time).

**Next recommended phase**: a visual sprite-cutter tab that wraps
`tools/sprite_importer` inside the dock (grid overlay, per-frame naming,
pivot picker) so slicing a raw sheet into a manifest doesn't require opening
a separate tool; bulk-assign (drag a folder of already-named PNGs onto a
category and auto-match by filename==id); and a "generate missing icons"
action that calls `PlaceholderFactory` to bake a permanent placeholder PNG
instead of relying on the runtime fallback, for franchises where no real art
is coming.

## Crossroads Asset Factory (Phase 2)

Built 2026-07-16 on top of Phase 1 — the plugin dock is now **"Crossroads
Asset Factory"** with 12 tabs (Dashboard, Import Queue, Items, Heroes,
Customers, Enemies, Locations, Shop Furniture, plus the four Phase-1 tabs).
The Phase-1 "next recommended phase" sprite cutter now exists as the shared
sheet viewer inside every factory tab. Full workflow docs:
`docs/ASSET_FACTORY.md`, `docs/SHOP_FURNITURE.md`, `docs/LOCATION_EDITOR.md`.

**Editor files added** (`addons/crossroads_content_studio/`):
- `widgets/sprite_sheet_preview.gd` — reusable Aseprite-style viewer:
  nearest-neighbor zoom/pan, configurable frame grid (W/H/margin/spacing),
  click + drag-rectangle frame selection (ordered), free-rect mode, frame
  index labels, coords readout, PNG region/strip extraction helpers.
- `widgets/animation_preview.gd` — play/stop/step/FPS/loop/scale playback of
  selected frames.
- `widgets/animation_set_editor.gd` — standard-animation-set authoring
  (assign selection, reorder, per-anim fps/loop, pivot, preview); reads and
  writes the runtime manifest schema.
- `core/factory_io.gd` — id/filename sanitizing, unique ids, `data/*.json`
  upserts (2-space style, schema tag preserved), sidecar metadata
  (`<file>.meta.json` with original source path), manifest writing.
- `ui/import_queue_tab.gd`, `ui/items_tab.gd`, `ui/entity_factory_tab.gd`
  (shared base), `ui/heroes_tab.gd`, `ui/customers_tab.gd` (with Duplicate),
  `ui/enemies_tab.gd`, `ui/locations_tab.gd` (tileset import + layered grid
  map painter), `ui/furniture_tab.gd`.
- Extended: `core/asset_paths.gd` (manifest/sheet/tileset/import-queue paths,
  per-world folder set), `core/content_scan.gd` (+ shop_furniture, locations),
  `core/validator.gd` (see below), `ui/main_panel.gd`, `plugin.gd`.

**Runtime files added**:
- `autoload/shop_furniture_manager.gd` (new autoload, saved as `furniture`
  section) — furniture layout, slot mapping, placement validation, customer
  adapter API (`get_all_available_display_slots`, `slot_attention_bonus`,
  `choose_display_slot_for_customer`).
- `scripts/shop/display_furniture.gd` — movable display furniture node
  (slots, interactions, optional collision, edit-mode tinting).
- `scripts/systems/location_loader.gd` — instantiates factory-authored
  locations (tiles, collision bodies, named markers).
- `data/shop_furniture.json` (6 starter furniture types), `data/locations.json`.

**Runtime files changed** (all additive):
- `scripts/shop/shop.gd` — hardcoded crate markers replaced by
  `DisplayFurniture` instances from the manager; new Shop Edit Mode
  ("Rearrange furniture" interactable: pick up / grid-snap move / validate /
  place); slot picker honors furniture `allowed_categories`.
- `scripts/systems/customer_gen.gd` — window-slot bonus now routed through
  `ShopFurnitureManager.slot_attention_bonus()` (identical numbers in the
  default layout, so the economy proof is unaffected).
- `scripts/systems/sprite_frames_builder.gd` — manifests may now use
  per-animation `rects` (variable-size frames) end-to-end.
- `scripts/entities/character_visual.gd` — explicit `walk_left`/`walk_right`
  (etc.) animations now win over the mirrored `_side` pair; `idle` accepted
  as a fallback start animation.
- `autoload/content_database.gd` (+furniture/locations loading + getters),
  `autoload/save_manager.gd` (+furniture section), `autoload/scene_router.gd`
  (+reset), `project.godot` (+ShopFurnitureManager autoload).

**Validation checks added**: duplicate furniture/location ids, unknown item
categories, manifest movement-animation coverage for heroes (and
move/attack/defeat for enemies), manifests pointing at missing sheets,
unknown enemy AI behaviors, named customers with missing/unknown archetypes
or no resolvable sprite, furniture with missing custom sprites / zero display
slots / bad allowed categories / no size, locations with invalid types,
missing or broken tilesets, out-of-range tile indices, missing
player/customer spawn+exit markers per location type, and unresolved or
dangling `door_exit` targets.

**Known limitations**: see the "Known limitations (first version)" sections
in `docs/ASSET_FACTORY.md`, `docs/SHOP_FURNITURE.md`, and
`docs/LOCATION_EDITOR.md` (collision boxes not authored in-editor, single
tile brush / no undo, furniture moveable but not yet purchasable, locations
not yet wired into scene routing).

# Current Build

Last audited/updated: **2026-07-16**

Audited baseline: **`a6ce0cb` - `Add in-game live developer hub`**, plus this Kingdom Hearts vertical-slice pass

Engine used: **Godot 4.7.1-stable**

This file records the observed state of the current checkout. “Verified” means
the path was exercised during this audit. “Partial” means meaningful code is
present but the complete player/editor workflow was not verified or has a known
gap. “Placeholder” means scaffolding or stand-in content exists without a
finished player-facing result.

## Validation performed in this audit

| Check | Result | What it establishes |
| --- | --- | --- |
| `tests/test_boot.tscn` | **PASS — `BOOT_TEST_PASS`** | Current JSON loads and tested cross-references resolve. Loaded 133 items, 40 enemies, 8 bosses, 7 heroes, 8 worlds, 39 recipes, 10 archetypes, 28 named customers, 14 events, 37 story scenes, and 32 room templates. |
| `tests/test_parse_all.tscn` | **PASS — `PARSE_TEST_PASS`** | Current autoload, gameplay, tool, and addon scripts compile; listed main scenes can instantiate. |
| `tests/test_campaign.tscn` | **PASS — `CAMPAIGN_TEST_PASS`** | Negotiation logic, simulated shop sessions/orders, crafting, save/load roundtrip, checkpoint retention, simulated boss balance, and the automated campaign pass. The final explicit run repaired all gates on day 23. |
| `tests/test_live_combat.tscn` (windowed) | **PASS — `LIVE_COMBAT_PASS`** | Automated Sora combat defeated the Fat Bandit, registered hits, collected KH loot and the World Shard, and banked gold. A headless run is not valid because its screenshot call has no headless texture. |
| `tests/screenshot_tour.tscn` (windowed) | **PASS — `SCREENSHOT_TOUR_DONE`** | Story, town, shop, dungeon, and main-menu scenes launched and produced current screenshots. |
| `tests/test_asset_factory.tscn` | **FAIL** | Furniture/layout, shop construction, JSON IO, slicing, manifest rects, and most chroma-key assertions ran, but the suite reported `auto-detected wrong background color`. The Asset Factory cannot be called fully verified. |
| Sprite importer batch using Sora manifest | **PASS — `IMPORTER_OK`** | The standalone importer built a six-animation `SpriteFrames` resource from the current Sora manifest. |
| `python -m pytest -q` | **PASS — 19 passed, 1 skipped** | Downloader/parser/project-layout Python tests pass; the optional live-network test was skipped. |
| `tests/test_dev_hub.tscn` | **PASS - `DEV_HUB_TEST_PASS`** | F1 action handling, pause/resume, isolated state, location objects, item/customer/enemy spawn, existing shop furniture/customer integration, money/inventory, playtest reports, AI export, and unchanged normal saves passed headlessly. |
| `tests/screenshot_dev_hub.tscn` (windowed) | **PASS - `DEV_HUB_SCREENSHOT_PASS`** | Today, Location, and Spawn rendered at both 640x360 and 1280x720 after live tab changes. |
| `tests/test_kh_vertical_slice.tscn` | **PASS - `KH_VERTICAL_SLICE_PASS`** | Scoped starter inventory, persistent moved furniture, dynamic display targeting, two real negotiations/sales, a live two-room Sora dungeon with one Shadow and a guaranteed Lucid Shard pickup, loot return/resale, and save/reload persistence passed through a Playtest Workspace session. |
| Normal project launch, windowed | **PASS** | The configured main scene reached the title screen under OpenGL on the current Windows/NVIDIA environment and exited cleanly after 180 frames. |

## Live Developer Hub - Verified automated core; visual/manual UX partial

- A development-only `DevHubManager` autoload opens the runtime overlay with F1 in debug development mode. The automated test verified opening pauses the tree, simulation can resume behind the visible overlay, and closing restores the prior pause state.
- The overlay supplies Today, World, Location, Spawn, Shop, Player, Game State, Playtest, AI Partner, and Logs tabs. Windowed tours rendered Today, Location, and Spawn cleanly at both 640x360 and 1280x720 using the existing theme and scrollable layout; a complete human click-through of every tab is still pending.
- Today reads maintained claims from `data/dev_status.json`. World counts current `ContentDatabase` entries. Location lists the built-in town/shop, each data-driven world dungeon, authored locations, and separately saved development locations.
- The automated workflow created a blank development location; spawned an item, named customer, and enemy; selected and moved an object; and persisted the layout in `user://crossroads_dev/live_dev_state.json`.
- The real shop scene spawned and moved `DisplayFurniture` through `ShopFurnitureManager` and summoned a real `ShopCustomer`. Display assignment and reachable target controls are implemented but were not manually clicked in this audit.
- Player and Game State expose curated development actions. Normal manual slots are never invoked by Hub actions, and automatic normal autosaves/checkpoints are suppressed after entering the isolated development session. The smoke test fingerprinted normal save files and verified they were unchanged.
- Playtest reports and AI context exports were generated with all required files. Screenshot capture is intentionally skipped under the headless renderer and attempted in windowed runs.
- The existing Godot editor Asset Factory remains enabled and unchanged in purpose; the Live Developer Hub consumes runtime content and does not replace its import/preparation workflows.
- Known limitation: normal campaign scenes still author their own layouts. The Hub catalog can launch them, while new development locations use `LocationLoader`; this pass does not migrate campaign scenes to location JSON.

## System-by-system state

### Title screen — Verified render; interactions partially verified

- `project.godot` boots `scenes/ui/main_menu.tscn`.
- The supplied title art renders at the current 1280×720 window size with real
  New Game, Load, Config, Extras, and Quit buttons over it.
- Slot selection, save summaries, deletion, audio/fullscreen settings, credits,
  and a no-art fallback are implemented in `scripts/ui/main_menu.gd` and parse.
- The screenshot tour visually verified the title screen. This audit did not
  manually click every menu action.

### Save/load — Verified core; menu UX not manually exercised

- Three manual slots, autosave, chapter checkpoint, checkpoint restart, slot
  summaries, and deletion are implemented in `autoload/save_manager.gd`.
- Save documents include game, time, economy, market, inventory, relationships,
  bridge, story, and furniture state.
- The campaign test verified a slot roundtrip for gold, merchant level, time,
  storage, display inventory, relationships, a KH World Shard, and flags. It
  also verified chapter-restart retention and rollback rules.
- New-game and continue routing are wired through `SceneRouter`. The menu click
  path and real-user save migration/error messaging were not manually tested.

### Player movement — Partial

- `TownPlayer` implements WASD/arrow movement, acceleration, wall collision,
  facing animations, interaction proximity, and freezing while panels are open.
- The player instantiated correctly in the town and shop screenshots. Sora also
  moved under automated input in the live-combat test.
- This audit did not manually walk the town/shop boundaries or verify controller
  feel, collision snags, camera feel, and every interaction prompt.

### Shop — Verified automated vertical slice; manual UX partial

- The shop scene builds and renders. The player can stock furniture slots, sort
  storage, expand the shop, rearrange furniture, open a one-period session, and
  return to town.
- Live customer spawning, browsing, negotiation queuing, orders, sales summary,
  time advancement, and shop restrictions are implemented.
- Headless shop/economy simulation passes, and the Asset Factory test verified
  that the shop scene constructs furniture and browse points before the later
  chroma-key failure.
- A human did not play a complete live shop session during this audit. The shop
  screenshot's top HUD appeared mostly dark/empty at capture time and needs a
  hands-on check before visual polish is considered complete.
- The vertical-slice test moved an existing stand, stocked it, resolved a
  dynamically targeted sale, sold returned expedition loot, and restored the
  moved stand plus displayed inventory through save/load. New campaigns also
  receive a concise first-shop guide. Human usability remains unverified.

### Customers — Partial

- Session generation, named and walk-in customers, budgets, interests, item
  preferences, orders, relationships, and hero auto-equipping are implemented.
- `ShopCustomer` and `CustomerBrain` support walking in, visiting furniture
  browse points, deciding, negotiating/ordering, and leaving. Named customers
  can use a manifest or static sprite and otherwise use generated placeholders.
- Customer generation and orders are exercised by campaign/shop simulation.
  The complete live multi-customer flow and negotiation queue were not manually
  played in this audit.
- The first starter-item sale and first returned Lucid Shard sale each use one
  data-selected Moogle Broker. Movement, browsing, and negotiation still run
  through the normal customer systems; later sessions use normal generation.

### Negotiation — Verified logic; interactive presentation partial

- Pricing tolerance accounts for archetype, relationship, preference, shop
  appeal, mood, merchant level, budget, and combo.
- Accept, perfect deal, counteroffer, final warning, refusal, relationship, sale,
  and combo outcomes are implemented. The campaign test exercises acceptance,
  rejection/counter behavior, and sale bookkeeping.
- The modal negotiation panel parses and is wired into the live shop, including
  typed prices and accepting counteroffers. Its complete player-facing flow was
  not manually exercised during this audit.

### Inventory — Verified core; management UX partial

- Storage stacks, display slots, item transfer, sorting, shop appeal, orders,
  collection tracking, crafting support, consumable selection, shop expansion,
  and hero equipment are implemented in `InventoryManager`.
- Campaign tests verify storage/display save restoration, order fulfillment,
  crafting inputs/output, and simulated shop use.
- The shop storage list, display picker, guild equipment UI, and longer-term
  inventory ergonomics were not manually playtested.

### Item stands and furniture — Verified slice persistence; manual edit feel partial

- Six furniture definitions exist in `data/shop_furniture.json`.
- `ShopFurnitureManager` supplies persistent layout, sequential display slots,
  window/attention bonuses, allowed categories, placement validation, movement,
  and customer slot selection.
- The shop now constructs `DisplayFurniture` nodes and exposes grid-snapped edit
  mode. The screenshot tour rendered the furniture and stocked item icons.
- Furniture assertions in the Asset Factory suite ran without reporting a
  furniture failure, but the suite as a whole fails later on chroma detection.
- Furniture is movable but not purchasable; edit mode and all placement edge
  cases were not manually tested.
- The Kingdom Hearts slice test verified that moving a stand changes its live
  customer browse target and that its position survives a normal slot reload.

### Dungeon combat — Verified small live slice; longer run UX partial

- The dungeon scene creates a generated room sequence with combat, treasure,
  boss rooms, walls, chests, switches, HUD, hero switching, loot, success, and
  failure handling.
- `CombatHero` implements movement, a three-hit/basic sequence, specials,
  dodge/guard variants, consumables, meter, finishers, damage, and defeat.
- Enemies and bosses use reusable data-driven behaviors, projectiles,
  telegraphs, phases, drops, and loot pickups.
- The windowed KH live-combat test passed against the Corrupted Fat Bandit. The
  campaign test also passes the logic-level dungeon simulations.
- A human did not play a full five-room expedition. The screenshot tour showed
  a sparse first room with large flat placeholder geometry, so room readability
  and visual composition remain partial.
- A new first-run preset reuses `start_plaza` and `combat_arena_open` for a
  two-room Traverse Town route with Sora and exactly one Shadow. The Shadow
  encounter guarantees a labeled Lucid Shard, and the final exit waits until
  that pickup is collected. The live automated route defeated the enemy,
  collected the pickup, returned, and banked the loot.

### Locations — Placeholder foundation

- `data/locations.json` currently contains **zero locations**.
- `LocationLoader` can build authored tile/decor layers, collision cells, and
  typed markers from location data.
- Existing town, shop, dungeon, and story scenes do **not** consume the location
  database or loader; they continue to build their layouts in gameplay scripts.
- No generated location should be described as playable yet.
- `docs/location_briefs/traverse_town_vertical_slice.md` documents the approved
  small first-expedition layout. The playable implementation remains a dungeon
  room preset and does not claim that `LocationLoader` is campaign-ready.

### Asset Factory — Partial with a known failing test

- The enabled Godot editor plugin builds a 12-tab Crossroads Asset Factory for
  dashboard/validation, queue routing, item/entity creation, locations,
  furniture, browsing, assignment, and shared UI assets.
- Its scripts parse and its lower-level test exercises data upserts, icon/strip
  export, manifest rectangles, furniture integration, and chroma removal.
- Current blocker: `tests/test_asset_factory.tscn` reports
  `auto-detected wrong background color`.
- This audit did not drive every native editor tab interactively. Treat all
  write-side editor workflows as partial until the failing test is fixed and an
  end-to-end import is performed on a disposable or reviewed asset.

### Item importer — Mixed verification

- The Asset Factory Items tab can slice one selected region into a processed
  icon, create/update `data/items.json`, and write source sidecar metadata. It
  parses but was not interactively exercised in this audit.
- The import queue copies files into a world's `raw/` folder without deleting
  the source and writes provenance metadata. It parses but was not interactively
  exercised.
- The standalone sprite importer supports manifests, grid/rect animation
  definitions, preview, atlas/`.tres` export, and headless batch conversion.
  Batch conversion was verified with the current Sora manifest.

### Hero/customer/enemy importers — Partial

- Shared entity tooling can slice animation sets, preview them, write processed
  sheets/manifests, and upsert the relevant JSON data.
- Hero creation supplies playable default combat data and balance flags.
- Customer creation supports static or animated art, archetypes, budgets,
  dialogue, and duplication.
- Enemy creation selects a reusable AI behavior and can route entries to the
  boss list.
- Scripts parse, but no complete editor-driven create/update workflow was
  performed during this audit. Generated balance/personality fields remain
  intentionally flagged for review.

### Location editor — Partial editor; no playable location

- The Locations tab implements tileset import, a ground/decoration painter,
  collision cells, markers, dimensions, and location JSON writes.
- It paints one tile at a time, has no fill/stamp/undo workflow, and is not wired
  into scene routing.
- With an empty locations database and no runtime consumer, this is tooling
  groundwork rather than a finished location system.

### Current Kingdom Hearts content — Automated playable slice; human acceptance pending

- Chapter data exists for Kingdom Hearts/Traverse Town with Sora, five regular
  enemies, the Corrupted Fat Bandit, a 10,000g repair, a World Shard, five
  generated dungeon rooms, and nine market goods.
- Data contains 19 KH items (including the World Shard and the newly added Lady
  Luck Keyblade), four named KH customers, Sora, five regular enemies, and one
  boss. Lady Luck currently has a price of 0 and review flags, so it is not
  balanced content yet.
- Animated processed manifests/sheets exist for **Sora, Shadow Heartless, Large
  Body, and Corrupted Fat Bandit**.
- Processed item icons exist for **bright_shard, keychain, kh_elixir, kh_ether,
  kh_potion, kingdom_key, and lady_luck_keyblade**.
- Soldier Heartless, Yellow Opera, Red Nocturne, Donald, Goofy, Moogle, and most
  KH item art still resolve through generated placeholders or have no dedicated
  animated manifest.
- The KH combat test proves Sora can defeat the boss and collect the shard. The
  automated campaign proves the chapter logic can be completed. A human has not
  yet verified the complete New Game → shop → dungeon → repair route in this
  audited build.
- The smaller Pass 3 route is automated end to end: new-campaign inventory,
  movable stand, first sale, Sora selection, two-room Traverse Town expedition,
  one live Shadow, guaranteed Lucid Shard collection, return to shop, shard
  resale, and save/reload. `docs/KH_VERTICAL_SLICE.md` is the exact human route.
- The longer Corrupted Fat Bandit, World Shard, 10,000g gate-repair route is not
  part of this small slice and remains pending manual Chapter 1 work.

## Current visual truth

- The title screen is the most polished current scene and rendered cleanly.
- Story presentation renders with portrait, speaker, dialogue, and continue
  prompt.
- Town and shop are functional but rely heavily on repeated floor textures,
  flat-color building/wall blocks, and placeholder props.
- The town screenshot shows some building geometry cropped at the viewport
  edges. The shop HUD needs a hands-on check because its captured header was
  largely dark. The dungeon is readable enough to run but visually sparse.
- Music content is primarily placeholder/prototype audio with a working local
  override system; this audit did not judge the full soundtrack.

## Recommended next smallest playable task

Personally play `docs/KH_VERTICAL_SLICE.md` from New Game without development
tools. Record only the largest observed issue in item placement, customer
movement, dungeon-exit clarity, or sale-screen presentation. If the route
blocks, fix only that blocker and replay from the nearest normal save.

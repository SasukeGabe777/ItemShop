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

# Architecture

Godot 4.7, typed GDScript, fully data-driven. UI is built in code via `UIKit`
so scenes stay thin (each .tscn is a single node + script).

## Autoload singletons (load order matters)

| Autoload | File | Owns |
|----------|------|------|
| GameState | autoload/game_state.gd | merchant level/xp, shop level, flags, encyclopedia, met heroes, stats |
| ContentDatabase | autoload/content_database.gd | loads every data/*.json; lookup helpers; texture resolution |
| TimeManager | autoload/time_manager.gd | day/period/chapter clock, deadline checks |
| MarketManager | autoload/market_manager.gd | market events, prosperity, market/wholesale prices |
| EconomyManager | autoload/economy_manager.gd | gold, sales bookkeeping, first-offer combo |
| InventoryManager | autoload/inventory_manager.gd | storage, display slots, orders, collection, hero equipment |
| RelationshipManager | autoload/relationship_manager.gd | customer relationships, hero friendship, daily moods |
| BridgeManager | autoload/bridge_manager.gd | gate states (shard/paid/repaired), accessibility, Fade |
| BoomManager | autoload/boom_manager.gd | announced shop-traffic events, focused demand, session duration/cooldowns |
| DungeonManager | autoload/dungeon_manager.gd | expedition planning, room layout gen, loot rolls, headless expedition sim |
| StoryEventManager | autoload/story_event_manager.gd | trigger→scene matching, scene queue |
| SaveManager | autoload/save_manager.gd | 3 slots + autosave + chapter checkpoint/restart |
| AudioManager | autoload/audio_manager.gd | music with user-override resolution, stingers |
| SceneRouter | autoload/scene_router.gd | scene navigation + context, campaign bootstrap |
| DebugManager | autoload/debug_manager.gd | F3 console (gold/advance/give/shard/repair/unlock_all/sim/...) |

Every stateful autoload implements `to_save()/from_save()`; SaveManager
composes them into one JSON document.

## Reusable components (scripts/components)

HealthComponent, DamageComponent, HitboxComponent, HurtboxComponent,
MovementComponent, AttackComponent (folded into CombatHero's shared moveset),
LootTableComponent, InteractionComponent, CustomerBrain, NegotiationProfile,
EquipmentComponent, StatusEffectComponent.

Collision layers: 1 walls | 2 player body | 4 enemy body | 8 enemy hurtbox |
16 player hurtbox.

## Entities (scripts/entities)

- `CharacterVisual` — SpriteFrames-from-manifest or generated placeholder,
  shared shadow/outline/flip/bob.
- `TownPlayer` — Hero in town/shop (Omori sheet via manifest).
- `CombatHero` — shared dungeon controller, data-driven per hero.
- `Enemy` — behavior archetypes from enemies.json; `Boss` extends it with
  telegraphs, phases, summons. `Projectile`, `LootPickup`.
- `ShopCustomer` + `CustomerBrain` — enter/browse/negotiate/order/leave.

## Pure logic (scripts/systems)

`Negotiation` (all haggling math), `CustomerGen` (session customer rolls,
interest picking, orders, hero auto-equip on purchase), `ShopSim` (headless
session driver used by tests), `FX` (hit pause/shake/particles/popups),
`PlaceholderFactory`, `SpriteFramesBuilder`, `UIKit`.

Game scenes and headless tests share the same logic classes — the economy
simulation exercises the real negotiation/market/inventory code, not a copy.

## Data packs (data/)

items, enemies(+bosses), heroes(+npcs), worlds, recipes, customers, booms
(archetypes+named), market_events, story_scenes, rooms, balance,
music_manifest. `tests/test_boot.gd` enforces referential integrity across all
of them (every loot/recipe/market/world reference must resolve).

## Tests (tests/)

- `test_boot` — data load + cross-reference integrity.
- `test_parse_all` — force-compiles every script, instantiates every scene.
- `test_campaign` — negotiation, crafting, save/load roundtrip, boss
  defeatability for all 8 bosses, failure-restart retention rules, and a full
  auto-played 35-day campaign that must finish all repairs + beat The Fade.
- `screenshot_tour` — windowed smoke test capturing PNGs of each scene.

Run: `godot --headless --path . res://tests/test_campaign.tscn`

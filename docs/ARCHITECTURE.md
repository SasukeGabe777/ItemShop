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
| MultiplayerState | autoload/multiplayer_state.gd | LOCAL 2-player couch split-screen (input device split, SubViewport rig, dual focus) |
| PartyState | autoload/party_state.gd | seat roster 1..5 for ALL modes (SINGLE/COUCH/ONLINE); player_index is the stable identity; colors/tints; N-player ready gate |
| Net | autoload/net.gd | ONLINE transport + authority: ENet listen server, version handshake, command bus, manager state sync, scene follow, reconnect/park, pause, LAN discovery, UPnP |
| Replica | autoload/net_replica.gd | ONLINE entity replication: host-simulated spawn/despawn/event/state streams + per-player body streams + damage forwarding |

Every stateful autoload implements `to_save()/from_save()`; SaveManager
composes them into one JSON document.

## Online co-op (up to 5 players — Net / PartyState / Replica)

Online is a **host-authoritative listen server** (host = peer 1 = player 1).
Offline and couch play never install a peer, so `Net.is_online()` is false and
every hook is a no-op — gameplay code calls `Net.request(...)` and
`Net.is_authority()` unconditionally.

- **State authority — command bus + snapshot rebroadcast.** Clients never
  mutate the singletons. They call `Net.request("economy.add_gold", {...})`;
  the host runs the *existing* mutator (its validation is the server
  validation), then rebroadcasts the affected manager's `to_save()`/`to_net()`
  dict, which clients apply via `from_save()`/`from_net()` — the same signals
  that fire on a save-load refresh the UI. Commands live in
  `scripts/net/net_commands.gd`. RNG-owning managers make lockstep impossible;
  snapshot-after-mutation is immune to divergence.
- **Scene coordination.** The party always travels together: `SceneRouter.go`
  on the host calls `Net.broadcast_scene_change` (full sync, then `_net_go` on
  the same reliable channel); clients follow and can't drive `go` themselves.
- **Entity replication (Replica).** The host simulates enemies, bosses,
  customers, projectiles and loot; clients get puppets built by per-scene
  factories, driven by a 15 Hz batched state stream (channel 1). Each player
  body streams at 20 Hz (channel 2, relayed through the host). A scene-
  generation stamp (`Replica.gen`), aligned across peers by the welcome and
  scene-change RPCs, drops stragglers from a freed scene.
- **Damage rule.** Hits are DETECTED on the attacker's machine, APPLIED on the
  owner of the defender's HP. `HurtboxComponent.receive` forwards a puppet's
  packet through `Replica.forward_hit`; guard/iframes/death always evaluate on
  authoritative state. Entities gain `make_puppet()`; heroes/enemies keep their
  hurtbox monitorable so local swings still register and forward.
- **Join / reconnect / disconnect.** New joins get a `SaveManager.snapshot()`
  welcome + roster; joining mid-dungeon parks the client until the party
  surfaces. A dropped client keeps its seat (session token) for 10 min and
  auto-reconnects into the same `player_index` (peer_id is remapped — nothing
  keys off it). Scene handlers react to `PartyState.player_left`.
- **All @rpc methods live on the three autoloads**, never on in-scene nodes, so
  a scene change can't free an RPC target mid-flight.
- **Couch and online are mutually exclusive.** MultiplayerState stays couch-only
  and mirrors into PartyState; online mode never touches the SubViewport rig.

Probes: `tests/net_*` — each spawns a second real instance on 127.0.0.1 (a few
windowed for screenshots). Run any headless; they print `*_PROBE_PASS`.

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

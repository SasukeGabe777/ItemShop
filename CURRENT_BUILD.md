# Current Build

Last audited: **2026-07-27**

Audited checkout: **`0b2e6925` plus the 2026-07-27 patch-note synchronization**.

Engine: **Godot 4.7.1-stable**. Application version: **0.2.0**.

This is the observed state of the checkout, regenerated from the actual data,
manifests, project configuration, tests, git history, and fresh windowed
screenshots. It supersedes the 2026-07-22 snapshot at `e56b3e8`, which predates
the Realm of the Mad God world and the entire online co-op implementation.

## Executive state

Crossroads now has **eight built franchise worlds**, a Null Archive endgame
chapter, local two-player couch play, and host-authoritative online co-op for up
to five players. The online route covers lobby/character selection, town, shop,
shared expedition lineup, dungeon, story following, disconnect handling,
late-join parking, and reconnect into a reserved seat.

The current release candidate is logic-green and visually smoke-tested. The
remaining acceptance gap is a real two-machine/WAN controller session; local
two-instance probes cannot prove an external router path.

Dungeon progression now has two independent softlock defenses: supplied
barrier art uses per-sprite collision fitted to its visible pixels, and every
cleared non-boss room advances the authoritative solo/co-op party automatically
after ten seconds if no hero reaches the open doorway.

## Content inventory

Verified by parsing `data/*.json` on 2026-07-26:

| Data | Current count |
| --- | ---: |
| World records | **9** |
| Playable heroes | **16** |
| NPC records | **3** |
| Regular enemies | **105** |
| Bosses | **28** |
| Items | **268** |
| Recipes | **98** |
| Customer archetypes / named customers | **10 / 28** |
| Customer visual pool | **529** |
| Story scenes | **37** |
| Market events / shop booms | **14 / 14** |
| Room templates | **32** |
| Authored locations | **0** |

## World state

| Chapter | World | Playable heroes | State |
| ---: | --- | --- | --- |
| 1 | Kingdom Hearts | Sora | Built |
| 2 | Mario | Mario, Luigi | Built |
| 3 | Final Fantasy | Cloud | Built |
| 4 | Zelda | Link | Built |
| 5 | Naruto | Naruto | Built |
| 6 | Dragon Ball | Goku, Piccolo | Built |
| 7 | Pokémon | Pikachu, Charmander | Built |
| 8 | Null Archive | Any | Endgame chapter/stub by design |
| 9 | Realm of the Mad God | Archer, Knight, Wizard, Rogue, Necromancer, Ninja | Built |

Realm is a ranged-combat world with six shooter heroes, twelve regular enemies,
nine bosses (Oryx is the debut boss), authentic item/customer art, biome rooms,
enemy projectile swarms, world-specific music, and an admin unlock mode.

## Multiplayer state

### Couch

Local two-player split-screen remains supported with separate devices,
per-player menu focus/input gates, viewport filtering, identities, shared
expeditions, and alternating shop-customer turns.

### Online

Online is a host-authoritative listen server implemented by `Net`,
`PartyState`, and `Replica`.

- Up to five seats, stable `player_index` identity, version handshake.
- LAN discovery, direct-IP join, and attempted UPnP port mapping.
- Twelve selectable OMORI town/shop avatars plus the original Omori avatar.
- Host-owned singleton mutation through the command bus and snapshot sync.
- Town, shop, dungeon, projectiles, loot, customer, and player replication.
- Shared lineup/ready gate, party travel, story follow, retreat, switching.
- Late join is parked during an expedition; dropped seats remain reconnectable
  for ten minutes.
- All scenes react to disconnects and clean up abandoned assignments/entities.

See `docs/ARCHITECTURE.md` for the authority and replication model.

## Verification through 2026-07-27

Core suites:

| Suite | Result |
| --- | --- |
| Boot/data integrity | `BOOT_TEST_PASS` |
| Full script/scene parse | `PARSE_TEST_PASS` |
| 35-day campaign simulation | `CAMPAIGN_TEST_PASS` — all gates repaired day 33, 41,396g spare |
| Asset Factory | `ASSET_FACTORY_TEST_PASS` |

Content/system probes passed:

- `DUNGEON_AUTOPLAY_PROBE_PASS` across all worlds.
- `BARRIER_BLOCKS_PROBE_PASS` for fitted horizontal/vertical collision across
  every supplied world barrier.
- `DUNGEON_BOUNDS_PROBE_PASS`, including the ten-second cleared-room fallback.
- `ADMIN_CHECK_PASS` for Realm/admin state.
- `DBZ_MUSIC_PROBE_PASS`.
- `MOREDECOR_FURNITURE_PROBE_PASS` for all ten OMORI decor pieces.
- Couch identity, alternating customer turns, P2 input, and P2 render filtering.

All **18 baseline `net_*_probe.tscn` routes passed**, including handshake,
state sync, scene follow, late join, parking, pause, reconnect, replication,
avatars, town, shop, lineup, dungeon, dungeon FX, progression, discovery,
disconnect, and offline regression. A nineteenth full-run regression drives the
remote client through every room and boss across seeded Kingdom Hearts, Naruto,
and Realm expeditions. Its first client now deliberately remains away from the
open door and confirms the host's timed room advance reaches both machines.

Windowed probes passed and every fresh screenshot was opened and inspected:

- Main menu and online lobby: alone and with a ready client.
- Two-player town with both bodies and names visible.
- Co-op dungeon with Sora and Link visible in the same room.
- Realm start, combat, facing, autofire, special, and Oryx boss room.
- OMORI wall/floor decor and the top/bottom of the purchase catalog.
- Mario, Final Fantasy, Zelda, Naruto, Dragon Ball, and Pokemon barrier runs
  with collision debugging visible; every fitted collider was inspected.

The screenshot client was corrected during this pass to hold its authoritative
body on-screen, so the town/dungeon evidence no longer clips player two at the
spawn edge.

## Hero animation snapshot

Multi-frame down idles: Link, Goku, Piccolo.

One-frame down idles: Sora, Mario, Luigi, Cloud, Naruto, Pikachu, Charmander,
and all six Realm heroes. Walk sets are present for every hero; Cloud and Naruto
remain the thinnest of the older melee heroes.

## Known gaps and non-blocking issues

1. **Real WAN acceptance remains external.** Local host/client instances pass,
   but this router rejected automatic UPnP mapping. The lobby reports the
   failure and recommends Tailscale/Hamachi or forwarding UDP 8910.
2. **No second-physical-machine/controller acceptance is recorded** for online
   co-op or Realm. Automated instances and windowed screenshots are green.
3. **Realm boss rooms are very dark.** Oryx and the red boss HP bar remain
   visible, but the black/navy floor is the weakest visual in the inspected
   Realm set.
4. **Python asset environment is broken on this machine.** Both project virtual
   environments point to a removed Python 3.12 installation. Generated assets
   are intact, but extraction scripts cannot be replayed until Python 3.12 and
   the Pillow/numpy environment are restored.
5. **`data/locations.json` remains empty.** Campaign scenes still construct
   their layouts in code.
6. **Pokédex and Fire Stone still lack item icons**, so they do not circulate
   through the live shop inventory.
7. Several heroes still use one-frame idles; this is polish, not a progression
   blocker.

## Export

The standard release artifact is `export/crossroads.exe`. Every changed pass
must reimport assets as needed, run the relevant logic/windowed probes, export
the Windows release, and commit. See `CLAUDE.md` and `docs/AGENT_GUIDE.md`.

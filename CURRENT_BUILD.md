# Current Build

Last regenerated: **2026-07-22**

Audited HEAD: **`e56b3e8` - `Update character assets and extraction tools`**

Engine: **Godot 4.7.1-stable** (binary lives in `tools/`, gitignored).

This file records the observed state of the current checkout. Regenerated on
2026-07-22 by parsing the actual `data/*.json`, manifests, and git history and by
re-running the headless suites, because the prior version had frozen at
`9f97b5b` (2026-07-20) and understated the build by a full development era:
Dragon Ball graduated from data-stub to a fully built world (Goku + Piccolo
playable, painted dungeon, enemy roster + Perfect Cell boss), plus a shop
handbook, order-capacity scaling, a dungeon pause/retreat menu, and a large
recipe/customer expansion — none of which the old doc reflected.

- **Verified (data):** confirmed by directly parsing the data/manifests in this
  checkout on 2026-07-22.
- **Verified (test):** re-run headless on 2026-07-22 (result noted inline).
- **Partial / Stub:** meaningful code or data exists but the full player route is
  incomplete or unproven.

## Content inventory (verified by parsing data/ at e56b3e8)

| Data | Count | Δ since 9f97b5b |
| --- | --- | --- |
| Worlds | **8** (`kingdom_hearts, mario, final_fantasy, zelda, naruto, dragon_ball, pokemon, null_archive`) | — |
| Playable heroes / NPCs | **9 / 3** | +1 hero (**Piccolo**) |
| Regular enemies / bosses | **93 / 17** | +8 enemies; bosses 25→17 (FF6 monsters refiled to enemies) |
| Items | **225** | — |
| Recipes | **99** | +44 |
| Customer archetypes / named | **10 / 28** | — |
| Customer visual pool | **510** | (new count recorded) |
| Story scenes | **37** | — |
| Market events | **14** | — |
| Room templates (`data/rooms.json`) | **32** | — |
| Authored locations (`data/locations.json`) | **0** (still empty) | — |

## World-by-world build state (verified by data)

| World (chapter) | Hero | Dungeon art | State |
| --- | --- | --- | --- |
| Kingdom Hearts (1) | Sora | obstacle props + shared room templates | **Built** — original vertical slice |
| Mario (2) | Mario, Luigi | room backgrounds + props | **Built** |
| Final Fantasy (3) | Cloud | room backgrounds + props | **Built** |
| Zelda (4) | Link | room backgrounds + props | **Built** (composited sword overlay) |
| Naruto (5) | Naruto | room backgrounds + props | **Built** — thinnest hero animation set |
| Dragon Ball (6) | Goku, Piccolo | room backgrounds + props | **Built (NEW)** — both heroes playable, beam specials + fly dodge, enemy roster + Perfect Cell boss |
| Pokémon (7) | Pikachu | **none** | **Data stub** — no hero manifest, no dungeon art; not a playable expedition |
| Null Archive (F) | any | n/a | Endgame stub (The Fade) |

**Six of the seven franchise worlds are now built.** Pokémon is the last
data-only stub: it has hero/enemy/item/customer data but no dungeon art and no
`pikachu` hero manifest, so it has no playable expedition yet.

### Dragon Ball detail (built 2026-07-21 on the home PC)

Goku and Piccolo were captured from *DBZ: Legacy of Goku II* via the OAM
reference pipeline (`docs/DBZ_HANDOFF.md` records the full method). Two new
engine kinds landed in `scripts/entities/combat_hero.gd`:

- special **`beam`** (`scripts/entities/beam.gd`): muzzle/shaft/tip textures,
  grow/hold/fade, line damage — used for Kamehameha (Goku) and Special Beam
  Cannon (Piccolo).
- dodge **`fly`**: dash + i-frames + flight pose.

DBZ enemy roster (`saibaman`-class, `rr_robot`, `dbz_dinosaur`, `dbz_wolf`,
`sabertooth_tiger`, `cell_junior`) and **Perfect Cell** boss all have real
manifests.

## Systems present (19 autoloads)

GameState, ContentDatabase, TimeManager, MarketManager, EconomyManager,
InventoryManager, RelationshipManager, BridgeManager, BoomManager, DungeonManager,
StoryEventManager, ShopFurnitureManager, SaveManager, AudioManager, SceneRouter,
DebugManager, DevHubManager, PadNav, MultiplayerState.

Highlights beyond the KH slice: local 2-player split-screen (`MultiplayerState`),
controller support (`PadNav`), the Dev Hub overlay (`DevHubManager`), Shop Booms
(`BoomManager` — 14 announced crowd events), per-player consumable belts,
autosave every day-portion, obstacle-prop dungeon dressing, day-briefing HUD,
negotiation overhaul, painted shop interior, and story portraits. Recent
shop-side additions: **order-capacity scaling**, a **shop handbook /
encyclopedia** panel, and a **dungeon ESC pause menu with retreat**.

## Test suite (re-run headless 2026-07-22)

| Suite | Token | Result 2026-07-22 |
| --- | --- | --- |
| `test_boot` | `BOOT_TEST_PASS` | **PASS** (after fixing a stale `!= 8 heroes` assertion → floor `< 8`; Piccolo is the 9th hero) |
| `test_parse_all` | `PARSE_TEST_PASS` | **PASS** |
| `test_campaign` | `CAMPAIGN_TEST_PASS` | **PASS** (all gates repaired day 26, 1.36M gold spare) |
| `test_asset_factory` | `ASSET_FACTORY_TEST_PASS` | **PASS** (the old float-vs-8-bit chroma precision bug is fixed — prior docs/PLAYTEST_NOTES still calling this red were stale) |

Not re-run this pass (last known good in history): `test_kh_vertical_slice`,
`test_dev_hub`, `test_location_workshop`, `test_music_override`, plus the
windowed `*_shot.gd` screenshot-probe harness. Re-run examples:

```powershell
tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests/test_campaign.tscn
tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests/test_boot.tscn
```

Screenshot probes must run **windowed** (no `--headless`). See
`docs/AGENT_GUIDE.md` for the full build → import → probe → export loop.

## Hero animation state (verified by reading manifests)

| Hero | Idle (down) | Notes |
| --- | --- | --- |
| Goku | **10 fr** | full DBZ set: walks, melee, 3-facing Kamehameha, fly |
| Piccolo | **10 fr** | full DBZ set: walks, melee, SBC charge/fire, fly flips |
| Link | **10 fr** (side 10 fr) | blink idles, 10-fr walks, composited sword |
| Sora | 1 fr | 8-fr walks, Keyblade combo + dodge-roll |
| Mario / Luigi | 1 fr | 6-fr walks, down+side attacks (no up) |
| Cloud | 1 fr | thin: 2-fr up/side walks, non-directional attacks |
| Naruto | 1 fr | thinnest: 3-fr walks, side-only attacks |
| Pikachu | — | **no hero manifest** (Pokémon world unbuilt) |

The old "**universal** 1-frame idle" claim is no longer true: Link, Goku, and
Piccolo now have multi-frame idle motion (the DBZ heroes are among the richest
sets in the game). The remaining 1-frame idles are Sora, Mario, Luigi, Cloud,
and Naruto — Naruto and Cloud are still the thinnest overall.

## Known real gaps and defects (verified this pass — not doc-staleness)

1. **Pokémon is not a playable expedition.** No `pikachu` hero manifest, no
   room backgrounds/obstacle props. Data only. It is now the *last* stub world.
2. **`data/locations.json` is empty.** `LocationLoader` and the Location
   Workshop exist, but campaign scenes still build layouts in code.
3. **No human acceptance playtest** of the expanded 6-built-world build is
   recorded in `PLAYTEST_NOTES.md`. This requires a controller run of the
   exported exe.
4. **`PLAYTEST_NOTES.md` is itself stale** — its bug list still flags the
   Asset Factory chroma test as failing (it passes now) and predates every
   built world after KH.

## Export capability

**This machine can now export** (set up 2026-07-22). The only thing that had
been missing was the Godot 4.7.1-stable export templates; they are now installed
at `%APPDATA%/Godot/export_templates/4.7.1.stable/` (Windows debug + release).
The `export/` directory (gitignored) must exist before running the release
export. See the standard command in `CLAUDE.md` / `docs/AGENT_GUIDE.md`.

## Recommended next work

See `NEXT_TASKS.md`. In short: (1) record a human acceptance playtest of the
built worlds and refresh `PLAYTEST_NOTES.md`; (2) decide Pokémon — build it out
following the DBZ recipe or explicitly defer it; (3) idle-motion polish for the
five heroes still on 1-frame idles (Naruto/Cloud thinnest).

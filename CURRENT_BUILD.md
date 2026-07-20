# Current Build

Last regenerated: **2026-07-20**

Audited HEAD: **`9f97b5b` - `Autosave every day portion, and make the autosave loadable`**

Engine: **Godot 4.7.1-stable** (binary lives in `tools/`, gitignored).

This file records the observed state of the current checkout. It was regenerated
by inspecting the actual `data/*.json`, scripts, manifests, and git history at
`9f97b5b` because every prior version of this doc had frozen at the mid-July
"Kingdom-Hearts-only vertical slice" era (baseline `83865b5`) and understated the
build by four franchise worlds, local 2-player, controller support, consumable
belts, and autosave.

- **Verified (data):** confirmed by directly parsing the data/manifests in this
  checkout on 2026-07-20.
- **Verified (test):** a named test token was recorded in commit history. These
  were **not re-run during this doc regeneration** — treat as "last known good,"
  not "green right now." Re-run before relying on any of them (commands below).
- **Partial / Stub:** meaningful code or data exists but the full player route is
  incomplete or unproven.

## Content inventory (verified by parsing data/ at 9f97b5b)

| Data | Count |
| --- | --- |
| Worlds | **8** (`kingdom_hearts, mario, final_fantasy, zelda, naruto, dragon_ball, pokemon, null_archive`) |
| Playable heroes / NPCs | **8 / 3** |
| Regular enemies / bosses | **85 / 25** |
| Items | **225** (incl. 7 world shards; 25 flagged `needs_ai_balance`) |
| Customer archetypes / named customers | **10 / 28** |
| Recipes | **55** |
| Story scenes | **37** |
| Market events | **14** |
| Room templates (`data/rooms.json`, shared across worlds) | **32** (4 start / 18 combat / 6 treasure / 4 boss) |
| Authored locations (`data/locations.json`) | **0** (still empty) |

## World-by-world build state (verified by data)

| World (chapter) | Hero | Dungeon art | State |
| --- | --- | --- | --- |
| Kingdom Hearts (1) | Sora | obstacle props + shared room templates (no map-crop backdrops) | **Built** — original vertical slice; richest hero animation |
| Mario (2) | Mario, Luigi | `room_backgrounds` + props | **Built** |
| Final Fantasy (3) | Cloud | `room_backgrounds` + props | **Built** |
| Zelda (4) | Link | `room_backgrounds` + props | **Built** (composited sword overlay) |
| Naruto (5) | Naruto | `room_backgrounds` + props | **Built** — thinnest hero animation set |
| Dragon Ball (6) | Goku | **none** | **Data stub** — no hero manifest, no dungeon art; not a playable expedition |
| Pokémon (7) | Pikachu | **none** | **Data stub** — no hero manifest, no dungeon art; not a playable expedition |
| Null Archive (F) | any | n/a | Endgame stub (The Fade) |

Five of the seven franchise worlds have real ripped art, rosters, item sets,
customers, and dungeon backdrops. Dragon Ball and Pokémon have
hero/enemy/item/customer data but no dungeon art and no hero manifest, so they
have no playable expedition yet.

## Systems present (18 autoloads at 9f97b5b)

GameState, ContentDatabase, TimeManager, MarketManager, EconomyManager,
InventoryManager, RelationshipManager, BridgeManager, DungeonManager,
StoryEventManager, ShopFurnitureManager, SaveManager, AudioManager, SceneRouter,
DebugManager, **DevHubManager**, **PadNav**, **MultiplayerState**.

The last three did not exist in the frozen docs:

- **Local 2-player split-screen** (`MultiplayerState`): P1 on the root viewport,
  P2 in a native-resolution `SubViewport`; hard per-device input isolation,
  per-player menu focus with a painted stand-in selector, co-op shared-midpoint
  dungeon camera, and a ready-gate where the partner presses A to confirm
  shop/expedition. Main-menu 2P toggle.
- **Controller support** (`PadNav`): D-pad movement, full menu focus navigation,
  right-stick scrolling, trigger zoom.
- **Live Developer Hub** (`DevHubManager`): F1 development overlay (debug builds).

Other work landed since the freeze: per-player **consumable belts** (and every
offered consumable now has an implemented effect), **autosave every day-portion**
loadable from Continue, an obstacle-prop pass replacing stretched wall textures,
day-briefing HUD, negotiation overhaul, painted shop interior, real story
portraits, and ~100 added items/customers.

## Known real gaps and defects (verified this pass — not doc-staleness)

1. **Dragon Ball and Pokémon are not playable expeditions.** No hero manifest
   (`goku`/`pikachu`), no `room_backgrounds`/`obstacle_props`. Data only.
2. **KH `boss_rotation` references non-bosses.** The KH rotation is
   `[corrupted_fat_bandit, guard_armor, darkside]`, but `guard_armor` and
   `darkside` are defined as **regular enemies**, not in the `bosses` array. Only
   `corrupted_fat_bandit` is a real boss. Rotation indices 1-2 will not resolve a
   boss — needs fixing or trimming.
3. **`data/locations.json` is empty.** `LocationLoader` and the Location Workshop
   exist, but no authored location is committed, and normal campaign scenes still
   build their layouts in code.
4. **Asset Factory chroma test still fails.** `tests/test_asset_factory.gd:156`
   compares an 8-bit-quantized auto-detected background color against the original
   float color with `is_equal_approx` — a ~0.0005 quantization delta guarantees
   failure. It is a **test-precision bug, not a detection-logic bug**, and no
   commit in `656dad8..9f97b5b` touched either file. `ASSET_FACTORY_TEST_PASS`
   cannot currently be reached.
5. **25 items carry `needs_ai_balance`** (19 crossover, 3 KH, 3 Mario), e.g.
   `lady_luck_keyblade`, the Yoshi eggs, bean items — auto-generated stats/prices
   awaiting a balance pass. The only zero-price items are the 7 world shards
   (quest items, expected).
6. **FF roster modeling oddity:** ~10 Final Fantasy monsters are stored in the
   `bosses` array rather than `enemies`. Confirm this resolves correctly at
   runtime for normal (non-boss) encounters.

## Hero animation state (verified by reading manifests)

| Hero | Idle | Walk | Attacks |
| --- | --- | --- | --- |
| Sora | 1 frame | 8 fr all dirs | 3× 3-frame combo |
| Link | 1 frame | 4 fr all dirs | full down/side/up × 2 (sword composited) |
| Mario / Luigi | 1 frame | 6 fr all dirs | down + side × 2 (no up) |
| Cloud | 1 frame | 4 fr down, **2 fr up/side** | 2× 2-frame, non-directional |
| Naruto | 1 frame | **3 fr all dirs** | side-only × 2 |
| Goku / Pikachu | — | — | **no hero manifest** |

Universal issue: **every hero has a 1-frame idle** (no idle motion). Coverage is
uneven — Naruto and Cloud are the thinnest of the playable heroes. Reported
player-facing complaints are "stiff/static," "wrong/jerky motion," and
"weapon/effect invisible" — all resolvable with ground-truth frames from the
real game. The **capture pipeline is built and proven** (Minish Cap: Link's
walk cycle isolated on transparency) — see `docs/SPRITE_REFERENCE_PIPELINE.md`
and `tools/rom_ref/`. Building the first full hero manifest from it is the
active Priority 0 in `NEXT_TASKS.md`.

## Test suite (present at 9f97b5b — re-run before relying on these)

Core headless suites: `test_boot` (`BOOT_TEST_PASS`), `test_parse_all`
(`PARSE_TEST_PASS`), `test_campaign` (`CAMPAIGN_TEST_PASS`, full 35-day economy
proof + all bosses), `test_kh_vertical_slice` (`KH_VERTICAL_SLICE_PASS`),
`test_dev_hub` (`DEV_HUB_TEST_PASS`), `test_location_workshop`
(`LOCATION_WORKSHOP_PASS`), `test_music_override`, `test_asset_factory`
(**failing**, see gap #4). Plus a large windowed screenshot-probe harness
(`*_shot.gd`) for the four newer worlds, 2P split-screen, autosave, consumables,
and the wall/prop overhaul. Python: `pytest` (sprite-downloader tooling).

Re-run examples (Godot binary in `tools/`):

```powershell
tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests/test_campaign.tscn
tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests/test_boot.tscn
```

Screenshot probes must run **windowed** (no `--headless`). See
`docs/AGENT_GUIDE.md` for the full build → import → probe → export loop.

## Recommended next work

See `NEXT_TASKS.md`. In short: (1) hero animation polish driven by real-game
reference recordings, starting with idle motion for all five playable heroes and
full sets for Naruto/Cloud; (2) fix the KH boss-rotation references and the
Asset Factory test-precision bug; (3) decide whether Dragon Ball and Pokémon get
built out or are explicitly deferred.

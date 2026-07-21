# Next Tasks

Regenerated 2026-07-20 against HEAD `9f97b5b`. The previous version of this file
was frozen at the KH-only vertical-slice era and told agents *not* to build other
worlds — but Mario, Final Fantasy, Zelda, and Naruto were built afterward, plus
local 2-player, controller support, consumable belts, and autosave. Priorities
below reflect the **actual** current state (see `CURRENT_BUILD.md`).

## Recently completed

- **Shop Booms (2026-07-20):** 14 announced, data-driven high-traffic shop
  events; focused merchandise/customer demand; direct requests and disappointed
  departures; bundle sales; shop-appeal interaction; gate-repair celebrations;
  save/load; debug/Dev Hub controls; focused and windowed verification. Schema
  and extension notes are in `docs/BOOMS.md`.

## Priority 0 — Hero animation polish (active focus)

Animation is the standing pain point across all heroes. The player-reported
failure modes are **stiff/static motion**, **wrong/jerky motion**, and
**invisible weapons/effects** — all three are resolved by matching our ripped
frames to a **reference recording of the real game**, not by re-ripping. Raw
`.rom` files are a fallback only; GBA/SNES sprites are runtime-assembled
metasprites, so direct ROM ripping is harder than using the existing sheets.

Method (see also `docs/AGENT_GUIDE.md` §4–5):

1. Capture short reference clips (emulator GIF capture, e.g. mGBA *Tools → Record
   GIF*) of each hero's idle, walk (each direction), attack combo, and
   special/dodge. A savestate before each action makes this quick.
2. Rebuild the manifest against the reference: correct frame selection, order,
   fps, pivot (feet), and per-frame weapon-overlay offsets.
3. `--import`, then verify **windowed** in-engine (look at every screenshot),
   then export and commit.

Priority order (highest impact first — verified from manifests):

1. ~~**Link full set**~~ **DONE 2026-07-20** via the OAM reference pipeline
   (`docs/AGENT_GUIDE.md` §4 "Real-game reference capture"): blink idles,
   real 10-frame walk cycles all directions, sword visibly in hand for both
   attacks in every direction. Link is the template for the other heroes.
2. **Idle motion for the other four playable heroes.** 1-frame idles, so nobody
   breathes when standing — likely the biggest source of "looks static."
3. **Naruto and Cloud full sets** — the thinnest playable heroes (Naruto: 3-frame
   walks, side-only attacks; Cloud: 2-frame up/side walks, non-directional
   attacks). ROMs for their games are not in `savestates/ROMS` yet; the DBZ,
   KH:CoM, M&L, FF6, Naruto PotN2 saves/ROMs there cover the other worlds.
4. Sora, Mario, Luigi are the richest; touch only if a reference shows a clear
   wrong-frame/order problem.

Skip Goku and Pikachu until their worlds get dungeon art (see Priority 3).

## Priority 1 — Fix verified data/test defects — **ALL DONE 2026-07-20**

1. ~~KH `boss_rotation`~~ guard_armor + darkside refiled as bosses, ten FF6
   monsters refiled as enemies (`tools/fix_boss_rosters.py`). Note: runtime
   accessors fall back across the enemies/bosses dicts, so this was latent
   taxonomy rot rather than broken rooms; `test_boot` now checks the dicts
   directly so it can't regrow.
2. ~~Asset Factory chroma test~~ expected color quantized to 8-bit;
   `ASSET_FACTORY_TEST_PASS` reachable.
3. ~~FF roster modeling~~ covered by the refiling in item 1.
4. ~~Balance pass~~ all 25 `needs_ai_balance` markers resolved
   (`tools/balance_flagged_items.py`, priced against unflagged neighbors;
   the revive-mushroom price inversion was the standout). `CAMPAIGN_TEST_PASS`.
   `test_boot`'s stale exact-9-bosses assertion (red since the FF world
   landed) is now a floor.

## Priority 2 — Verify the current game end-to-end

No human acceptance run is recorded for the expanded build. Play the real
`export\crossroads.exe` on a controller through at least one full chapter loop
(shop → expedition → boss → repair) per built world, and one 2-player session.
Record the largest issue per category in `PLAYTEST_NOTES.md`, then fix only
blockers.

## Priority 3 — Decide Dragon Ball & Pokémon

They are data-only stubs (hero/enemy/item/customer data but no dungeon art or
hero manifest). Either build them out following `docs/AGENT_GUIDE.md` §9 (hero
manifest, ~12 enemies, boss frames, room backdrops, obstacle props, item icons),
or explicitly mark them deferred so the campaign's later chapters aren't silently
broken. **Confirmed 2026-07-20** (`tests/stub_worlds_probe.tscn`): reaching
chapter 6-7 does NOT crash — layouts generate (7-8 rooms, boss rooms resolve
great_ape_vegeta / mewtwo), all combat defs exist, but the hero and all five
enemies per world have no visual manifests, so everything renders as colored
placeholder shapes in flat untextured rooms. Playable, but reads as unfinished;
the DBZ LoG2 ROM in savestates/ROMS can feed the capture pipeline for Goku's
world when it's built out.

## Priority 4 — Locations (optional, low urgency)

`data/locations.json` is empty and campaign scenes build layouts in code, which
works. Only invest in the Location Workshop / `LocationLoader` path if authored
locations become the preferred way to add content. Not blocking anything now.

## Maintenance note

Keep this file, `CURRENT_BUILD.md`, and `data/dev_status.json` honest after each
pass. They drifted a full development era out of date once; regenerate them when
the truth of a feature's status changes, per `AI_PARTNER.md`.

# Next Tasks

Regenerated 2026-07-20 against HEAD `9f97b5b`. The previous version of this file
was frozen at the KH-only vertical-slice era and told agents *not* to build other
worlds — but Mario, Final Fantasy, Zelda, and Naruto were built afterward, plus
local 2-player, controller support, consumable belts, and autosave. Priorities
below reflect the **actual** current state (see `CURRENT_BUILD.md`).

## Priority 0 — Hero animation polish (active focus)

Animation is the standing pain point across all heroes. The player-reported
failure modes are **stiff/static motion**, **wrong/jerky motion**, and
**invisible weapons/effects** — all three are resolved by matching our ripped
frames to **ground-truth frames captured from the real game**, not by re-ripping.

The capture pipeline is **built and proven** (2026-07-20) — see
`docs/SPRITE_REFERENCE_PIPELINE.md` and `tools/rom_ref/`. It drives the real game
in BizHawk, navigates to gameplay autonomously, and reconstructs the hero on full
transparency from OAM (no chroma-key). Proven end to end on Minish Cap: Link's
walk-down cycle captured as clean isolated frames.

Method:

1. Convert + place the battery save, launch the ROM with a capture Lua, and dump
   frames via the OAM path (`tools/rom_ref/oam_dump.lua` + `decode_oam.py`).
2. Retune the per-game hero-isolation band from the `obj_all` full-layer render;
   filter the shadow object.
3. Cut the isolated frames into the standard animation set (order, fps, feet
   pivot, weapon offsets) and write the hero manifest.
4. `--import`, verify **windowed** in-engine (look at every screenshot), export,
   commit.

Immediate next step: capture Link's **full** move set (idle + walk ×4 dirs +
sword ×dir), drop the shadow, and build `link.json` — the first hero actually
fixed by this pipeline.

Priority order after Link (highest impact first — verified from manifests):

1. **Idle motion for all five playable heroes.** Every hero currently has a
   1-frame idle, so nobody breathes when standing — likely the biggest source of
   "looks static." Cheapest fix for the widest effect.
2. **Naruto and Cloud full sets** — the thinnest playable heroes (Naruto: 3-frame
   walks, side-only attacks; Cloud: 2-frame up/side walks, non-directional
   attacks).
3. **Link weapon-overlay pass** — confirm the composited sword is visible and
   correctly offset per frame/direction (the known "weapon invisible" case).
4. Sora, Mario, Luigi are the richest; touch only if a reference shows a clear
   wrong-frame/order problem.

Skip Goku and Pikachu until their worlds get dungeon art (see Priority 3).

## Priority 1 — Fix verified data/test defects

1. **KH `boss_rotation`** references `guard_armor` and `darkside`, which exist as
   regular enemies but not as bosses. Either promote them to real boss entries or
   trim the rotation to the defined boss(es). Re-run `test_boot` after.
2. **Asset Factory chroma test** (`tests/test_asset_factory.gd:156`): fix the
   test-precision comparison (quantize the expected color to 8-bit before
   `is_equal_approx`, or widen tolerance) so `ASSET_FACTORY_TEST_PASS` is
   reachable. This is a test bug, not a detection-logic bug.
3. **FF roster modeling:** confirm the ~10 Final Fantasy monsters stored under
   `bosses` resolve correctly for normal encounters; move them to `enemies` if
   not.
4. **Balance pass** for the 25 `needs_ai_balance` items (prices/stats/tags in
   line with neighbors and `data/balance.json`), removing the marker as each is
   done. Run `test_campaign` (the economy safety net) afterward.

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
broken. Confirm what happens today if a player reaches chapter 6-7.

## Priority 4 — Locations (optional, low urgency)

`data/locations.json` is empty and campaign scenes build layouts in code, which
works. Only invest in the Location Workshop / `LocationLoader` path if authored
locations become the preferred way to add content. Not blocking anything now.

## Maintenance note

Keep this file, `CURRENT_BUILD.md`, and `data/dev_status.json` honest after each
pass. They drifted a full development era out of date once; regenerate them when
the truth of a feature's status changes, per `AI_PARTNER.md`.

# Next Tasks

Regenerated **2026-07-22** against HEAD `e56b3e8`. The prior version was frozen at
`9f97b5b` (2026-07-20) and had gone stale: it still called Dragon Ball a data
stub and told agents to "skip Goku until the world gets art" — but Goku **and**
Piccolo shipped as playable heroes with beam specials + a fly dodge, and the DBZ
dungeon (rooms, props, enemy roster, Perfect Cell boss) is built. Priorities
below reflect the **actual** current state (see `CURRENT_BUILD.md`).

## Recently completed

- **Pokémon world (2026-07-22):** Pikachu + Charmander playable (sheet-mined
  from the user's PMD rip drop — no emulator runs), new `nova` AOE special
  kind (Discharge / Fire Spin from user-provided effect frames), composed PMD
  dungeon (meadow/woods/crystal-cave/golden-vault/Temporal-Tower boss arena),
  5-enemy corrupt roster with real art, 3-boss rotation Latios → Ho-Oh →
  Mewtwo. **All seven franchise worlds are now built.** Screenshot-verified;
  boot/parse/campaign suites green.

- **Dragon Ball world (2026-07-21):** Goku + Piccolo playable (OAM-captured from
  *Legacy of Goku II*), new `beam` special + `fly` dodge engine kinds, painted
  dungeon, enemy roster + Perfect Cell boss. Full method in `docs/DBZ_HANDOFF.md`.
- **Shop depth (2026-07-21):** order-capacity scaling, shop handbook/encyclopedia
  panel, dungeon ESC pause menu with retreat, animated Kanto customers,
  furniture-attention progression, expanded customer pool.
- **Export on the work PC (2026-07-22):** installed the 4.7.1-stable export
  templates so this machine can export/verify locally (was the two-machine
  bottleneck). Also fixed the stale `test_boot` hero-count assertion.
- **Doc-honesty pass (2026-07-22):** regenerated this file + `CURRENT_BUILD.md`;
  re-ran boot/parse/campaign/asset-factory suites (all green). `PLAYTEST_NOTES.md`
  is still stale and should be refreshed by the next acceptance run.

## Priority 0 — Human acceptance playtest of the built worlds (active focus)

No human acceptance run of the expanded build is recorded, and `PLAYTEST_NOTES.md`
predates every world after Kingdom Hearts. Now that this machine can export:

1. Export `export/crossroads.exe` and play on a controller through at least one
   full chapter loop (shop → expedition → boss → repair) for each built world
   (KH, Mario, FF, Zelda, Naruto, Dragon Ball, **Pokémon**), plus one 2-player
   session.
2. Record the largest issue per category (blocker / bug / visual) per world in
   `PLAYTEST_NOTES.md`, replacing the stale entries.
3. Fix only blockers this pass; file the rest here.

Give Dragon Ball and Pokémon extra attention — they are the newest worlds.
Pokémon specifics worth eyeballing: nova special feel (Discharge/Fire Spin
cost/damage), boss rotation difficulty (Latios first-win at 1200hp), and
whether the prop-less rooms read too empty.

## Priority 1 — Pokémon polish (world built 2026-07-22)

Chapter 7 is now playable end-to-end. Remaining polish items:

- **Obstacle props:** rooms use flat-polygon obstacles (PMD wall tiles carry
  baked fills that read as pasted boxes). If rooms feel empty in playtest,
  hunt standalone object rips (boulders, berries, crates) to cut per §4.
- **Item icons:** `pokedex` and `fire_stone` lack icons so they never appear
  in shops; extract from `raw/items.png`.
- **Idle motion:** Pikachu/Charmander idles are 1-frame (their PMD idle rows
  have 2 poses — could become blink-style idles like Link's).
- **Music:** drop `dungeon_pokemon.mp3` into `assets/music/user_overrides/`
  if a track is wanted; resolves automatically.

## Priority 2 — Hero idle-motion polish

Five heroes still have 1-frame idles (no idle motion): **Sora, Mario, Luigi,
Cloud, Naruto**. Link, Goku, and Piccolo now have multi-frame idles and are the
template. Highest impact first:

1. **Naruto + Cloud** — thinnest overall sets (Naruto side-only attacks, Cloud
   2-frame up/side walks). No ROMs for their games in `savestates/ROMS`, so this
   is sheet-mining per `docs/AGENT_GUIDE.md` §4, not live capture.
2. **Sora, Mario, Luigi** idle motion — they have rich walk/attack sets already;
   only the idle is static.
3. **Parked (from the 2026-07-20 pass):** Sora's Strike Raid special (fresh-game
   card economy dead-ends; L55 save hard-freezes on the 13F textbox) and Mario's
   battle jump/hammer attacks (needs a short new-game M&L run to the first
   tutorial battle). See `docs/AGENT_GUIDE.md` §8.

## Priority 3 — Locations (optional, low urgency)

`data/locations.json` is empty and campaign scenes build layouts in code, which
works. Only invest in the Location Workshop / `LocationLoader` path if authored
locations become the preferred way to add content. Per `AI_PARTNER.md`, write a
`docs/LOCATION_BRIEF_TEMPLATE.md` brief before generating any location.

## Maintenance note

Keep this file, `CURRENT_BUILD.md`, `PLAYTEST_NOTES.md`, and
`data/dev_status.json` honest after each pass. They have drifted a full
development era out of date **twice** now (frozen at the KH slice, then at
`9f97b5b`). Regenerate them whenever a feature's status changes, per
`AI_PARTNER.md`.

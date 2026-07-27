# Next Tasks

Regenerated **2026-07-26** against the checkout based on `d619d3d4`.

The former task list stopped before Realm and online co-op. Those features are
now implemented and locally verified. Current priorities are acceptance,
environment/repository maintenance, and targeted polish.

## Completed in the 2026-07-26 pass

- Reconciled uncommitted asset staging:
  - promoted the twelve OMORI co-op source sheets into
    `assets/hero/raw/coop/`;
  - kept the one used OMORI furniture atlas as tracked provenance;
  - preserved unused furniture downloads locally but ignored them from Git;
  - removed accidental OMORI dry-run lines from Pokémon's download log;
  - tracked the six missing Godot probe UID sidecars.
- Made `p2_input_probe` assert its behavior and emit a real pass/fail token.
- Corrected the screenshot client so player two is visible in town/dungeon
  acceptance shots.
- Removed cross-process campaign-test flakiness by seeding `Negotiation.rng`,
  rebuilding day-one market events after seeding, sorting weighted pools, and
  adding stable ID tie-breakers. Three fresh runs now converge on day 33 with
  41,396g spare.
- Re-ran core, campaign, couch, Realm, content, and all 18 online probes.
- Re-ran and inspected the online lobby/town/dungeon, Realm, and shop-decor
  windowed probes.
- Fixed ambiguous/stuck online dungeon progression: full-room safe-area camera,
  prominent room-clear banner, room-scoped enemy accounting, explicit blocker
  removal, and a three-world remote-client full-run regression.
- Refreshed `CURRENT_BUILD.md`, this file, `PLAYTEST_NOTES.md`, and
  `data/dev_status.json`.

## Priority 0 — External acceptance

The code-side release candidate is green. The next evidence must come from
outside the single-machine harness:

1. Run `export/crossroads.exe` on two physical machines, preferably with
   controllers.
2. Exercise lobby → character select → town → shop → shared lineup → expedition
   → return → story.
3. Test one disconnect/reconnect and one client join while the host is already
   in town.
4. Test both LAN discovery and the intended remote-network method.
5. Record only actual blocker/bug/visual findings in `PLAYTEST_NOTES.md`.

This machine's router rejected UPnP. For WAN testing, use Tailscale/Hamachi or
forward UDP 8910 unless the router is reconfigured.

## Priority 1 — Restore the asset toolchain

`.venv312` and `.venv` both reference a removed Python 3.12 installation.
Restore Python 3.12, recreate `.venv312`, install the project requirements plus
Pillow/numpy, then prove:

```powershell
.venv312\Scripts\python.exe tools\prep_coop_avatars.py
.venv312\Scripts\python.exe tools\prep_moredecor_furniture.py
```

Both reruns should leave the processed PNGs/manifests unchanged.

## Priority 2 — Visual/content polish

1. **Realm boss-room readability:** brighten or selectively lift the black/navy
   room art while preserving the Oryx atmosphere.
2. **Pokémon item icons:** extract Pokédex and Fire Stone icons so both items
   enter live shop circulation.
3. **Idle motion:** prioritize Cloud and Naruto, then Sora/Mario/Luigi,
   Pikachu/Charmander, and the Realm classes.
4. **Realm controller feel:** after a human run, tune autofire cadence, enemy
   bullet density, and first-win Oryx balance only from observed feedback.

## Priority 3 — Optional authored locations

`data/locations.json` is still empty and current code-built scenes work. Invest
in the Location Workshop/`LocationLoader` path only if authored locations
become the chosen content workflow. Write a location brief first, per
`AI_PARTNER.md`.

## Maintenance

Keep `CURRENT_BUILD.md`, `NEXT_TASKS.md`, `PLAYTEST_NOTES.md`, and
`data/dev_status.json` synchronized whenever a feature changes state. They have
drifted behind the code three times.

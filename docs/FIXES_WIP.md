# October 15 fixes — work in progress, awaiting the Sonic project

The user confirmed an implemented Sonic dungeon exists in a newer project.
GitHub `main` still points to `639d8501`; both nearby Desktop/ItemShop and
OneDrive/Desktop/ItemShop checkouts match it. Only raw Sonic source sheets
were found in Desktop/Sonic_assets, not an implemented world. The archived
Desktop/ItemShop-main (1) copy also supplied no Sonic world record.

**Do not release this checkout as the latest game until the newer source has
been compared and integrated.** At the user's request, changes are now saved
for manual integration at home in `handoff/2026-10-15/README.md`, on branch
`handoff/pre-session-fixes-2026-10-15`. Gameplay fixes and the optional
progression draft are separate commits and portable patches.
The old audit export is still `export/crossroads.exe`; it does not include
these work-in-progress fixes. See the handoff README for merge instructions.

## Implemented and exercised

- Autoplay buying now respects the live market's locks and buys for two
  display turns rather than stockpiling goods indefinitely. The original
  seven-gate campaign passed day 25 / 33,048g without balance changes.
- Inventory reset clears old display merchandise instead of carrying it
  into a new campaign.
- All music manifest entries resolve using shipped defaults when ignored
  local overrides are absent. Canonical track-id overrides retain priority;
  Realm currently falls back to the existing final-dungeon ambience, not its
  missing custom soundtrack. WAV loop endpoints account for channel/bit depth.
- UPnP worker threads are joined on tree exit. Selected net tests no longer
  emitted the unfinished-thread warning; other resource-leak diagnostics remain.
- Online lineup locks all editing controls after submission, validates local
  stock, and restores editing and Ready after a host rejection. Host validates
  hero availability, belt size, and usable consumables.
- Solo/couch setup uses a separate error label so stock warnings do not erase
  the packed-belt readout.
- Expedition completion freezes room actors and heroes, waits for deferred
  boss drops, and banks all loose loot/gold before the result. Pickups are
  authority-gated and idempotent against same-frame duplicate collection.

## Draft progression changes — hold for Sonic comparison

- Realm changed to Chapter 8, Null Archive to Chapter 9, forty campaign days,
  eight repair gates, data-driven final-chapter checks across UI and systems.
- Save version 2 migrates old late-game saves while preserving gold/items/gates;
  unfinished saves receive time for Realm, completed/endless saves stay final.
  Migration still needs dedicated regression coverage and the Sonic comparison.
- Updated chapter/finale story triggers and gate-count copy; added two short
  Realm transition scenes. These must be reconciled with the newer story data.
- Application version draft is 0.2.1 so a finished release rejects older peers.

## Verification so far

Tests used temporary `override.cfg` with custom user directory
`%APPDATA%/Crossroads-Fixes-2026-10-15`; that override has been removed.
Logs are in ignored `playtest/latest/fixes_*.log`.

- Boot, full parse, new session-readiness regression (audio priority/loop
  frames, new-game inventory, autoplay purchase locks/buffer), DBZ/Realm music.
- Core existing selected tests: new-game shop polish and controller navigation.
- Real localhost host/client handshake, state sync, reconnect, town, shop,
  lineup/departure, and three-world full dungeon runs (KH, Naruto, Realm).
- New `expedition_recovery_probe` drives real menu buttons through insufficient
  stock/gold, retries successfully, checks deferred loot/gold exactly once, and
  verifies movement input cannot move the hero behind results.
- Draft eight-gate campaign passes day 27 / 271,487g.

Not yet done: windowed verification of the fixes, save-migration regressions,
full fresh export, or release patch notes. The source handoff is committed;
it is not a final release. No sprite changes
were made; Pokédex/Fire Stone and the flagged sprite review remain pending.
The Pillow/numpy environment at `.venv312` was recreated using available
Python 3.13; the extraction scripts have not yet been replayed.

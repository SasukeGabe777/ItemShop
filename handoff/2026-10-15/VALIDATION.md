# Validation and remaining work

All checks below ran on the old July 30 source plus the local fix pass.
They do not validate the newer Sonic project. Several later checks included
the optional progression draft; the seven-gate campaign was also checked
before that draft. No additional gameplay changes were made while packaging.

## Passed

- `test_boot`, `test_parse_all`.
- `session_readiness_probe`: inventory reset, autoplay market gates and stock
  buffer, every music entry resolving, override priority, stereo/8-bit loops.
- `dbz_music_probe`, `rotmg_music_probe`.
- `new_game_shop_polish_probe`, `ui_navigation_hardening_probe`.
- Actual two-process localhost probes: handshake, state sync, reconnect,
  town, shop, shared lineup/departure.
- `net_dungeon_full_run_probe`: complete seeded KH, Naruto, and Realm runs
  with a remote client, including timed room advance.
- `expedition_recovery_probe`: real lineup buttons reject stock/gold,
  become editable again, retry successfully, settle deferred loot/gold
  exactly once, and block movement input behind results.
- Existing seven-gate campaign after autoplay fixes: day 25, 33,048g spare.
- Optional eight-gate progression draft: day 27, 271,487g spare.
- Both portable patches apply in sequence to the clean audit base and
  reproduce the exact commit trees; patch checksums are in `manifest.json`.

Tests used `%APPDATA%/Crossroads-Fixes-2026-10-15`, isolated using a temporary
`override.cfg`. That override was removed. Ignored raw logs remain under
`playtest/latest/fixes_*.log` in the original workspace.

## Limitations to carry into the merge

- Sonic implementation was unavailable; world/progression conflicts need
  comparison with the newest local source.
- Save-migration regressions and fresh windowed verification of the fixes
  remain outstanding. The previous audit's screenshots predate these fixes.
- No final fixed executable was exported; export after the merge.
- WAN, physical controllers, and five physical clients remain unverified.
- Realm's missing custom soundtrack uses an existing bundled ambient track.
- Other ObjectDB/resource-leak diagnostics remain at shutdown despite pass
  tokens. The selected reruns no longer emitted the unfinished UPnP thread
  warning after the cleanup change.
- No sprite fixes were made. Pokédex/Fire Stone icons, flagged sprite review,
  Realm boss-room readability, and idle-animation polish remain pending.
- The local `.venv312` was recreated with available Python 3.13 plus Pillow
  and numpy. It is ignored by Git; recreate a suitable asset environment at
  home. Extraction scripts were not replayed in this fix pass.

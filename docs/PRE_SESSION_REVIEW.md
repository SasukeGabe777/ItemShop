# Online play-session review — October 15, 2026

Source: `SasukeGabe777/ItemShop`, `main` at `639d8501` (July 30).
This is a focused readiness audit, not full campaign or WAN acceptance.
No gameplay or balance changes were made. Engine: Godot 4.7.1-stable.

## Do first for tonight

1. Distribute the freshly exported `export/crossroads.exe` to every player.
   The older Desktop/ItemShop executable was dated July 23, before the later
   shop, controller, synchronization, and progression fixes. The handshake
   compares application version `0.2.0`, not a commit/build fingerprint, so
   that version alone cannot establish that friends have identical builds.
2. Test one friend joining from another network before the full group arrives.
   Localhost probes cannot establish WAN connectivity. The game's existing
   remote-network route is a Tailscale/Hamachi address or forwarded UDP 8910;
   LAN discovery uses UDP 8911. No router or firewall settings were changed.
3. Exercise lobby → town → shop → expedition → return → story, then reconnect.
   Seven current two-instance online routes passed below; five simultaneous
   physical PCs and external-network/controller play remain unverified.

## Recommended work, in priority order

| Priority | Finding and evidence | Smallest useful next step |
|---|---|---|
| High | Campaign safety simulation fails twice identically at day 30 / Chapter 6, with shard recovered, five gates repaired, and 261,210g against the 400,000g DBZ repair. July's green campaign claim does not describe this checkout. | Diagnose the automated buying/selling policy against July's catalog/economy changes, then determine whether the policy or actual balance needs correction. A failed policy does not prove a human cannot win. |
| High for online usability | Code inspection: `LineupPanel` disables Ready and hero selection on submission. On insufficient stock/gold the host clears picks and emits `lineup_failed`; town changes only the status text. Add also allows selecting more copies than owned. | Re-enable editing/readiness on rejection and validate the local belt. Current workaround: Cancel and reopen the lineup. Failure recovery was inspected, not runtime-reproduced; the existing happy-path probe bypasses the UI buttons. |
| Medium | Fresh-clone music resolution: DBZ and Realm probes both fail with null streams. Six manifest entries have no matching project audio files: `newgame_begin`, `crossroads_day`, `crossroads_night`, `dungeon_naruto`, `dungeon_dragon_ball`, `dungeon_rotmg`. Music overrides are ignored by Git. | Restore the intended local overrides for the build, or define shipped fallbacks. Some defaults already exist under different names; Realm has no matching default file. Do not assume the fresh export includes the original soundtrack. |
| Medium | July 29 player notes still report expedition results appearing before loose loot resolves, with the hero controllable behind the popup. `_finish` still banks the result immediately. | Have the dungeon owner reproduce completion with floor loot and freeze/settle the run before presenting its result. Not freshly exercised in this audit. |
| Medium | Realm is still Chapter 9; Null Archive occupies Chapter 8. Chapter progression, completion, bridge display, and the campaign test still assume seven repairs then the finale. | Plan Realm-as-Chapter-8 as a progression change with save compatibility and campaign verification, rather than changing just its displayed number. |
| Polish | `SPRITE_REVIEW.md` has 95 flagged entries; latest commit adds the reproducible sprite-audit pack generator. Missing item art excludes authored merchandise from circulation. | Review the three flagged item sprites first, or add Pokédex / Fire Stone icons; tackle character identities from labeled source comparisons. |

The persistent `No more ITEM in stock!` equipment-readout report is confirmed
in the solo/couch `GatesPanel` code. Online uses a separate `LineupPanel`, so
these are distinct setup issues.

## Already present in this checkout

July 28–30 commits include live co-op stocking/furniture synchronization,
selected avatars with separate sidekicks, boss/projectile visibility fixes,
controller menu fixes, item rarity and sellback, qualitative purse hints,
starter-shop/tutorial improvements, overlapping SFX, and single-player shop
exit readiness. They should be tested from the fresh export before duplicating
that work. Dungeon presentation is listed from history, not freshly accepted.

## Verification on this machine

All gameplay probes used a temporary custom user directory,
`%APPDATA%/Crossroads-Preflight-2026-10-15`, isolated from normal campaign saves.
The temporary `override.cfg` must be removed before release export.
Raw logs are in ignored `playtest/latest/preflight_*.log`.

| Check | Result |
|---|---|
| Content audit | 268 items, 216 with live art, zero errors; four world-level missing-art warnings |
| Boot / full script and scene parse | `BOOT_TEST_PASS`, `PARSE_TEST_PASS` |
| Core catalog/economy regression | `CORE_LOOP_HARDENING_PROBE_PASS` |
| Starter shop / controller UI | `NEW_GAME_SHOP_POLISH_PROBE_PASS`, `UI_NAVIGATION_HARDENING_PROBE_PASS` |
| Online handshake / state sync / scene follow | All three explicit pass tokens |
| Online reconnect / town / shop / expedition lineup | All four explicit pass tokens |
| Campaign | **FAIL**, same Chapter 6/day 30 outcome in two fresh processes |
| DBZ / Realm music | **FAIL**, both resolve to null in this clone |
| Import | First full import completed asset work but crashed at shutdown (`0xC0000005`); second import exited 0 |

Several scene/net probes emit resource-leak diagnostics at process shutdown
despite their gameplay pass tokens and zero exit codes; one emitted an
unfinished UPnP-thread warning. These remain maintenance findings. No script
execution error was reported in the selected passing routes.

All five fresh windowed screenshots were opened and inspected: main menu,
join panel, host lobby, joined/ready client, and town with both named players
and separate companions visible. No clipping blocker appeared in those views.

Release export succeeded (exit 0): `export/crossroads.exe`, 199,230,720 bytes
(about 190 MiB). The temporary override was removed. The exported executable
booted, loaded expected content, and exited 0 after a 30-frame headless smoke
test. Normal-save fingerprints were unchanged. SHA-256:
`7ff04d2b02bc6010c447262b4b284b0911d7b5f04162f4a732c06113adfbef65`.

Additional evidence is in the October 15 `PLAYTEST_NOTES.md` entry.
Full dungeon combat, all historical
probes, WAN, physical controllers, and five-player concurrency are outside
this focused pass.

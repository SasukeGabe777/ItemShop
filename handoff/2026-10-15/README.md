# Crossroads fixes to merge into the newer Sonic project

Everything needed for this handoff is committed on
`handoff/pre-session-fixes-2026-10-15` in `SasukeGabe777/ItemShop`.
The source used here was `639d8501` (July 30), which lacks the implemented
Sonic world. Start from your newest local project and preserve its existing
work in Git before integrating these fixes.

## Merge the gameplay fixes

From the newest project's Git checkout:

```powershell
git fetch origin handoff/pre-session-fixes-2026-10-15
git switch -c merge/session-fixes-2026-10-15
git cherry-pick b89ba9dd018e3a33240e5214ad8143b40f277bfb
```

Resolve any conflicts against the newer Sonic implementation. This commit
contains the gameplay fixes and all four new probe files, without changing
world chapter numbers, campaign duration, or save format. It does bump the
application version to 0.2.1; reconcile that with the newer project's version.

The fixes cover:

- Online lineup recovery after stock/gold rejection, locked editing while
  ready, local stock checks, and host belt/hero validation.
- A separate solo/couch belt-error message that preserves packed items.
- Finished expeditions bank deferred floor loot/gold once and freeze actors
  before showing results.
- New campaigns clear old displayed merchandise.
- Music uses shipped fallbacks when local overrides are missing, honors
  track-id override names, and calculates WAV loop endpoints correctly.
- UPnP workers are joined on shutdown.
- Campaign autoplay buys unlocked stock for its expected display turnover,
  instead of tying up all repair cash in unsold inventory. Live prices and
  repair costs are unchanged by this commit.

## Optional progression draft — review against Sonic first

Commit `f911cf3a97cae83c93b773be4ced93a982d8cb0c` is deliberately separate.
It was developed before learning that the latest project contains Sonic.
It assumes eight franchise gates: Realm at Chapter 8, Null Archive at 9,
forty campaign days, updated story/UI checks, and a version-2 save migration.

Use it as a reference while reconciling the newer world's chapter order.
The save migration needs dedicated tests and adaptation to the Sonic roster.
The gameplay commit above does not require this draft.

## Portable patch files

- `01-gameplay-fixes.patch` — equivalent to the gameplay commit, including
  newly added test scripts/scenes.
- `02-progression-DRAFT.patch` — the separate optional progression commit;
  authored on top of patch 01.
- `manifest.json` — commit IDs and SHA-256 checksums.
- `VALIDATION.md` — checks already run and remaining work.

If transferring this folder without fetching the branch, the gameplay patch
can be applied from the newest project using:

```powershell
git am -3 "PATH_TO_HANDOFF/01-gameplay-fixes.patch"
```

Choose either cherry-picking or applying its patch, since they contain the
same change. Both patches were checked against the clean audit base and
reconstructed their respective commit trees exactly. This does not establish
that they will apply without conflicts to the unavailable newer project.

## Before playing the merged version

Reimport with the project's Godot engine, run relevant probes with an isolated
test user directory, check windowed menu/results screenshots, and export the
merged project. Campaign probes reset game state and write saves, so isolate
them from real campaign saves. Share one matching executable with every player.

The existing `export/crossroads.exe` in this workspace is the earlier audit
build. This handoff contains source fixes; it does not provide a release of
the newer Sonic project. `handoff/.gdignore` keeps the package out of Godot's
resource import/export scan.

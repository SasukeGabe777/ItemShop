# Implementation Report

This report is updated after local validation.

## Test Results

Completed on 2026-07-16:

- Dependency installation: `pip install -r requirements.txt` succeeded with Python 3.12.10.
- Playwright browser install: `python -m playwright install chromium` succeeded.
- Formatting: `black sprite_resource_downloader tests --check` passed.
- Static checks: `ruff check sprite_resource_downloader tests` passed.
- Unit tests: `pytest` passed with 17 passed and 1 optional live test skipped.
- Live dry run: `python -m sprite_resource_downloader https://www.spriters-resource.com/game_boy_advance/khcom/ --dry-run --headless --max-assets 1 --yes` succeeded.
- One-asset live download: `--max-assets 1 --headless --yes --resume` downloaded `assets/franchises/kingdom_hearts/raw/kh_riku_gba.png`.
- Downloaded file verification: PNG signature is valid, file is not HTML, dimensions are 493x3379, and visual inspection confirms a full sprite sheet rather than a thumbnail.
- Manifest and credits verification: `ASSET_MANIFEST.json`, downloader `ASSET_CREDITS.csv`, `failed_downloads.json`, `.download_state.json`, and project-level `credits/ASSET_CREDITS.csv` were written successfully.
- Resume smoke test: rerunning `--max-assets 1 --headless --yes --resume` skipped completed site asset `1138`.
- Visual UI validation: `python -m sprite_resource_downloader.webui --host 127.0.0.1 --port 8765` started successfully, `/` returned HTTP 200, and `/api/config` returned the configured franchise targets.

Environment note: venv launchers created under this path failed with a quoted base-Python launcher error, so validation used the absolute Python 3.12 interpreter at `C:\Users\Game Station\AppData\Local\Programs\Python\Python312\python.exe`.

## Selector Maintenance Notes

Download control discovery is intentionally layered:

1. `a[download][href]`
2. `a[href*="/media/assets/"]`
3. `a[href*="/download/"]`
4. visible link or button text containing `Download`
5. material icon text containing `download`

If The Spriters Resource changes its download button text or media path, `sprite_resource_downloader/downloader.py` and `sprite_resource_downloader/asset_parser.py` are the selector modules most likely to need updates.

## Crossroads Content Studio Validation (2026-07-16)

Fresh-machine setup for the `addons/crossroads_content_studio/` editor plugin
(Phase 1 of the content pipeline — see `docs/CONTENT_PIPELINE.md` and the
"Crossroads Content Studio (Phase 1)" section of `docs/IMPLEMENTATION_REPORT.md`):

- Cloned the repo, downloaded `Godot_v4.7.1-stable_win64.exe` +
  `_console.exe` from the engine's GitHub release into `tools/` (gitignored,
  matches `docs/ARCHITECTURE.md`).
- `godot --headless --path . --import` completed the initial asset import
  with no errors.
- `godot --headless --path . --editor --quit`: editor loads with the plugin
  enabled — zero SCRIPT ERROR / parse errors after fixing two bugs found on
  the first run (see below).
- `godot --headless --path . res://tests/test_boot.tscn`: `BOOT_TEST_PASS`.
- `godot --headless --path . res://tests/test_parse_all.tscn` (now also
  scanning `res://addons`): `PARSE_TEST_PASS`.
- `godot --headless --path . res://tests/test_campaign.tscn`: `CAMPAIGN_TEST_PASS`
  (all 7 gates repaired by day 31, save/load roundtrip intact) — confirms the
  plugin doesn't touch runtime/save behavior.
- `pip install -r requirements.txt` (Python 3.13.5) then `pytest -q`: 19
  passed, 1 skipped (the optional live test) — sprite_resource_downloader
  unaffected, since this phase only touched the Godot editor side.

**Bugs found and fixed during this validation pass**:
- `validator.gd` crashed on `String(it[field])` when a required-field check
  hit a non-string-castable value — GDScript's `String()` constructor is
  stricter than `str()` about which Variant types it accepts. Replaced every
  `String(...)` cast in the validator with `str(...)`, which is the safe,
  permissive stringifier and is what a validator should use anyway (it must
  never crash on messy data — that's the thing it exists to report).
- `ui_assets_tab.gd` triggered a noisy (non-fatal) engine warning by calling
  `EditorInterface.get_resource_filesystem().scan()` during the dock's own
  startup, racing the editor's own plugin-enable bookkeeping. Split folder
  creation into a silent path (used on startup) and a scanning path (used
  only by the explicit "Ensure Folder Structure" button, safe once the editor
  has settled).

## Crossroads Asset Factory Validation (2026-07-16)

Phase 2 of the editor tooling: the Content Studio plugin was expanded into the
**Crossroads Asset Factory** (Items/Heroes/Customers/Enemies/Locations/Shop
Furniture factory tabs + Import Queue), plus the runtime movable
shop-furniture system. Full build inventory in `docs/IMPLEMENTATION_REPORT.md`
("Crossroads Asset Factory (Phase 2)"); workflow docs in
`docs/ASSET_FACTORY.md`, `docs/SHOP_FURNITURE.md`, `docs/LOCATION_EDITOR.md`.

Validation run on this machine with Godot 4.7.1 from `tools/`:

- `godot --headless --path . --import`: clean; new classes registered.
- `godot --headless --path . --editor --quit`: editor loads with the plugin
  enabled and all 12 factory tabs constructed — zero SCRIPT ERROR / parse
  errors (one type-inference parse error in `shop_furniture_manager.gd` was
  found on the first run and fixed).
- `res://tests/test_parse_all.tscn`: `PARSE_TEST_PASS` (scans addons too).
- `res://tests/test_boot.tscn`: `BOOT_TEST_PASS`.
- `res://tests/test_campaign.tscn`: `CAMPAIGN_TEST_PASS` — all gates repaired
  on day 33 with ~34k spare; confirms the furniture refactor (display slots,
  window attention bonus now routed through `ShopFurnitureManager`) left the
  economy proof intact, and the save/load roundtrip now includes the
  `furniture` section.
- `res://tests/test_asset_factory.tscn` (new): `ASSET_FACTORY_TEST_PASS` —
  default furniture layout matches the shop-level slot count, slot indices
  are sequential, the classic window bonus is preserved exactly, placement
  validation rejects out-of-bounds/overlaps, moved furniture survives a
  save/load roundtrip, the live shop scene builds `DisplayFurniture` nodes
  and browse points from the layout, customers pick stocked slots through the
  adapter, `CCSFactoryIO` sanitize/unique-id/upsert round-trips JSON without
  duplication (against `user://` scratch files), icon/strip slicing produces
  pixel-correct PNGs, and `rects`-based manifests build real SpriteFrames.
- `pytest -q`: 19 passed, 1 skipped — Python tooling unaffected.

## Project Integration Notes

The downloader now defaults to the Crossroads raw franchise folders instead of a generic `output/` tree. Use `--franchise` if a page title cannot be inferred reliably, and use `--output` for isolated staging. Downloader state/manifests are stored in `credits/sprite_resource_downloader/<franchise>/` so only source sheets land in `raw/`.

Successful downloads upsert rows in `credits/ASSET_CREDITS.csv`; the `asset_id` is the downloaded filename stem.

Use repeated `--include-asset` filters to target named sheets from a page without downloading every asset.

For the KH live page, the parser was adjusted to ignore cross-game sidebar links and read section names from the site's `div.section` headers.

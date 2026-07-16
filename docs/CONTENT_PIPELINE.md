# Content Pipeline

How art, audio, and content flow from nothing → placeholder → real asset, and
how the **Crossroads Asset Factory** editor plugin (`addons/crossroads_content_studio/`)
helps with that. For data schemas (what fields an item/enemy/hero needs), see
`docs/EXPANSION.md` — this document is about the asset side.

Open the factory from the editor's bottom panel tray: **Crossroads Asset
Factory**. Tabs: Dashboard, Import Queue, Items, Heroes, Customers, Enemies,
Locations, Shop Furniture, Asset Browser, Asset Assignment, UI Assets,
Validation. This document covers the original asset-copy pipeline (Asset
Browser/Assignment/UI Assets); the factory tabs that *create* content
(slicing sheets into items/heroes/customers/enemies, tilesets/locations, and
shop furniture) are documented in `docs/ASSET_FACTORY.md`,
`docs/LOCATION_EDITOR.md`, and `docs/SHOP_FURNITURE.md`.

## Raw vs. processed assets

- **Raw** (`assets/franchises/<world>/raw/`): sprite sheets and images exactly
  as downloaded from a source site. Never edited, renamed, or deleted by any
  tool in this project, including the Content Studio — raw is the permanent
  record of what was sourced and from where.
- **Processed** (`assets/franchises/<world>/processed/` and
  `assets/franchises/<world>/processed/items/`): the actual files the game
  reads at runtime, one PNG per entity or item, named after its id. These are
  the only files `ContentDatabase` and `CharacterVisual` ever load.

Turning a raw sheet into a processed asset is a deliberate step (slicing,
naming, cropping). The Asset Assignment/Browser tabs copy whole files; the
factory tabs slice: **Items** cuts a single tile into an item icon, and
**Heroes/Customers/Enemies** cut frames into animation manifests — see
`docs/ASSET_FACTORY.md`. `tools/sprite_importer/` still exists for headless
batch slicing and `.tres` export.

## How to use the downloader

`sprite_resource_downloader` (Python, in the repo root) pulls individual
sprite-sheet assets from The Spriters Resource into the correct raw folder.
See `README.md` for full CLI/webui usage. Quick version:

```powershell
python -m sprite_resource_downloader https://www.spriters-resource.com/game_boy_advance/khcom/ --headless --yes
```

## Where downloaded files go

- Sprite sheets land directly in `assets/franchises/<franchise>/raw/`.
- Credit/source metadata is written to
  `credits/sprite_resource_downloader/<franchise>/ASSET_MANIFEST.json` and
  upserted into the project-level `credits/ASSET_CREDITS.csv`.
- The Content Studio's Asset Browser reads both of those files to show
  source/credit metadata next to a preview — it never writes to them.

## How to assign an asset to a hero/enemy/item

1. Open **Asset Assignment**, pick the category (Heroes, NPCs, Enemies,
   Bosses, Items).
2. Find the row for the id you want. The "Exists" column shows whether a
   processed file is already there.
3. Select the row, click **Assign from Raw...**, and pick a PNG/GIF from that
   entry's `raw/` folder in the dialog that opens.
4. The file is copied to the expected processed path (overwrite requires
   confirmation if one already exists). The FileSystem dock is rescanned so
   it shows up immediately.

You can also do this manually from **Asset Browser**: select a raw file,
click **Copy to Processed...**, and give it a destination id (check "this is
an item icon" to route it into `processed/items/` instead of `processed/`).

## Expected file paths

- Hero / NPC / enemy / boss sprite: `assets/franchises/<world>/processed/<entity_id>.png`
- Item icon: `assets/franchises/<world>/processed/items/<item_id>.png`
- Animated sheet (optional, richer than a static PNG): a manifest at
  `assets/franchises/<world>/manifests/<entity_id>.json` — see
  `docs/EXPANSION.md`'s "Add real sprites" section and `tools/sprite_importer/`.
- Shared placeholder override (rarely used, mostly for `crossroads`-world
  characters like Hero/Patch): `assets/shared/placeholders/<entity_id>.png`.

`world_id` and `entity_id`/`item_id` always come straight from `data/*.json`
("world" and "id" fields) — nothing is franchise-hardcoded anywhere in the
studio; the franchise list you see in the Asset Browser dropdown is whatever
folders exist under `assets/franchises/` plus whatever "world" values appear
in the data files.

## How placeholders work

`ContentDatabase.entity_texture()` / `item_texture()` resolve art in this
order:

1. Processed franchise art (`processed/<id>.png` or `processed/items/<id>.png`).
2. A manifest-driven animated sheet (`manifests/<id>.json`), for entities.
3. A shared hand-placed placeholder (`assets/shared/placeholders/<id>.png`).
4. A procedurally generated placeholder (`PlaceholderFactory`), which always
   works and is why the game never crashes over missing art.

The Content Studio's "missing asset" counts (Dashboard, Validation tab) mean
"currently falling back to step 4" — not "broken."

## How to run validation

Dashboard → **Validate All Content**, or open the **Validation** tab directly
and click **Run Validation**. Results are ERROR / WARNING / INFO rows with a
content type, id, message, and expected path where relevant:

- **ERROR** — structural problems (missing/invalid data JSON, duplicate ids,
  items missing a required field) or dangling references (a recipe/loot entry
  pointing at an item id that doesn't exist) or missing project-level files
  (theme, icon, credits CSVs).
- **WARNING** — missing processed art/audio (falls back to a placeholder) or
  a "world" value used by content that has no entry in `worlds.json` (this is
  expected for the `crossroads` world, which is the hub, not a dungeon).
- **INFO** — reserved for future non-blocking notices.

Validation re-parses `data/*.json` itself rather than asking the running game
for its `ContentDatabase` — Godot only starts autoload singletons while the
project is actually playing, not while you're sitting in the editor, so the
plugin can't reach the live one. Keep this in mind if you ever change the
loading rules in `autoload/content_database.gd`: mirror the change in
`addons/crossroads_content_studio/core/content_scan.gd` too.

## How credits are preserved

The studio only *reads* `credits/ASSET_CREDITS.csv`, `credits/MUSIC_CREDITS.csv`,
and any per-franchise `ASSET_MANIFEST.json` under
`credits/sprite_resource_downloader/`. It never edits or deletes credit
records — adding a source manually still means editing `ASSET_CREDITS.csv`
by hand (or letting the downloader do it for you), same as before this plugin
existed.

## How to add a new item / enemy / hero

Field-level detail lives in `docs/EXPANSION.md`. In short:

- **Item**: add an entry to `data/items.json` (id, name, world, category,
  price are required — Validation will flag anything missing), then either
  drop art at `assets/franchises/<world>/processed/items/<id>.png` or use
  Asset Assignment once you have a raw source. It's immediately sellable,
  order-able, craftable-into, and lootable.
- **Enemy/boss**: add to `data/enemies.json` with a valid `behavior`, add its
  id to a world's `enemies` list, then assign art the same way (or let it use
  the generated placeholder — nothing breaks either way).
- **Hero**: add to `data/heroes.json` with `combat`/`base_stats`/etc., give it
  a world, then assign art or a manifest-driven sheet.

## How to add a new UI background

1. Open **UI Assets**, click **Ensure Folder Structure** if you haven't
   already (creates `assets/shared/ui/{backgrounds,buttons,panels,cursors,fonts,icons}/`).
2. Drop the background PNG into `assets/shared/ui/backgrounds/`, click
   **Refresh**, and it shows up as a thumbnail.
3. **Do not bake title or menu text into the image.** Title screens and menus
   in this project are built from real `Label`/`Button`/`Theme` nodes in code
   (see `scripts/ui/ui_kit.gd`) so they stay readable, localizable, and
   restyleable — a background image should be art only.

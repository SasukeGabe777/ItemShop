# Crossroads Asset Factory

The Asset Factory is the expanded version of the Content Studio editor plugin
(`addons/crossroads_content_studio/`). Open it from the editor's bottom panel
tray: **Crossroads Asset Factory**. It turns raw sprite/tile sheets into real
game content — items, heroes, customers, enemies, locations, and shop
furniture — without hand-editing JSON or hardcoding paths.

Tabs: **Dashboard · Import Queue · Items · Heroes · Customers · Enemies ·
Locations · Shop Furniture · Asset Browser · Asset Assignment · UI Assets ·
Validation**. (The last four are the original Content Studio tabs, unchanged.)

## The sheet viewer (shared by every factory tab)

Every factory tab embeds the same `CCSSpriteSheetPreview` control:

- **Zoom**: mouse wheel (zooms around the cursor), `+`/`-` buttons, `Fit`, `1:1`.
  Zooming is preview-only nearest-neighbor scaling — source files are never
  upscaled or modified.
- **Pan**: middle-mouse drag.
- **Grid**: toggle + frame `W`/`H`, `Margin`, `Spacing` spinners. Frame index
  labels appear when zoomed in enough.
- **Select**: click a grid cell to select it; drag a rectangle to select every
  cell it touches (row-major order — that order becomes animation frame
  order); Shift/Ctrl-click adds/removes from the selection.
- **Grid off**: each drag selects a free pixel rectangle instead (for sheets
  with uneven frames); click a rectangle to remove it.
- The status line shows the hovered pixel, hovered frame index and rect, and
  the selection count.

## Import Queue

1. Drop downloaded/bought files anywhere under `assets/import_queue/`.
2. Open **Import Queue**, press **Refresh**, select a file, pick a world, and
   **Copy to raw/**. The file is *copied* (never moved) into
   `assets/franchises/<world>/raw/` with a sanitized filename and a
   `<file>.meta.json` sidecar recording the original source path.
3. **Ensure Folder Structure** creates every factory folder for the selected
   world (`raw/`, `processed/`, `processed/items|sheets|heroes|customers|
   enemies|tilesets|locations/`, `manifests/`).

Raw files are the permanent record — no tool in this project edits, renames,
or deletes anything in `raw/`.

## Items

1. **Load Sheet...** and set the grid to the icon size (16x16 for most packs).
2. Click the icon tile you want.
3. Type a **Name**, pick a **World** (category/price optional), and press
   **Create Item From Selection**.

That writes the icon to `assets/franchises/<world>/processed/items/<id>.png`
(with sidecar), and upserts a valid entry into `data/items.json`:

```json
{"id": "...", "name": "...", "world": "...", "category": "misc",
 "tags": [], "price": 0, "desc": "",
 "needs_ai_balance": true, "needs_description": true}
```

The `needs_*` markers flag the item for a later Claude pass that fills in
descriptions, prices, tags, and appeal values — see “AI fill-in passes” below.

The list at the bottom shows every existing item with icon preview (or a
`MISSING` warning), id, world, category, and price. Selecting a row loads it
for editing: **Update Selected Item** rewrites name/category/price/world, and
**Assign Icon to Selected Item** replaces its icon from the current sheet
selection (with an overwrite confirmation).

## Heroes / Customers / Enemies

All three tabs share the same animation workflow:

1. Pick an existing entry from the dropdown (loads its manifest back into the
   editor) or leave `<new>` and type a **Name**.
2. **Load Sheet...**, set the grid (or turn the grid off for uneven frames).
3. Select frames on the sheet, choose an animation in the dropdown, and press
   **Set = Selection** (or **Append Selection**). Selection order = frame
   order; reorder with **Move Up/Down**.
4. Set **FPS** and **Loop** per animation, and press **Play** to preview the
   animation at 1x/2x/4x/8x nearest-neighbor scale.
5. Set the **Pivot** (defaults to bottom-center of the first frame — the
   character's feet) and preview **Scale**.
6. **Save**. This writes, without touching the raw sheet:
   - `assets/franchises/<world>/processed/sheets/<id>.png` — copied sheet + sidecar
   - `assets/franchises/<world>/manifests/<id>.json` — the runtime manifest
     (`SpriteFramesBuilder` schema; `CharacterVisual` picks it up automatically
     because entity id = data id)
   - the upserted entry in `data/heroes.json` / `data/customers.json` (named) /
     `data/enemies.json`

Standard animation sets (required before Save):

| Type | Required | Optional |
|---|---|---|
| Hero | idle_down/up/side, walk_down/up/side | idle/walk_left+right, attack_*, special, hurt, defeat, victory |
| Customer | idle_down/up/side, walk_down/up/side | idle/walk_left+right, happy, angry, thinking, buy, leave |
| Enemy | idle, move, attack, defeat | hurt, directional idle/walk, attack_1 |

`_side` animations are mirrored for the left direction automatically. If you
author explicit `walk_left`/`walk_right` (etc.) animations they take priority
over the mirrored `_side` pair at runtime.

**Save Static Sprite Only** is the fast path: select one frame and it writes
`processed/<id>.png` plus the data entry — no animations needed. Good enough
for background customers; upgrade them to manifests later.

Type-specific fields (everything has a safe default and can be fixed later):

- **Heroes**: weapon type, HP/ATK/DEF/move speed, hire cost. New heroes get a
  generic playable combat block and `needs_ai_balance: true`.
- **Customers**: archetype (drives budget/haggling — defaults to
  `adventurer`), chapter, budget multiplier, quirk, spoken line. New customers
  get `needs_ai_personality` + `needs_ai_balance`. **Duplicate Customer**
  clones the selected customer under a new id (reusing the original's sprite
  via `hero_ref` when the copy has no art of its own).
- **Enemies**: behavior (the reusable AI vocabulary from
  `scripts/entities/enemy.gd` — `chaser`, `shooter`, `bomber`, ... — never a
  custom per-enemy script), HP/damage/speed/size, and a **Boss** checkbox that
  routes the entry into the `bosses` array with attack/telegraph defaults.

## Locations & Shop Furniture

See `docs/LOCATION_EDITOR.md` and `docs/SHOP_FURNITURE.md`.

## Validation

**Validation** tab → **Run Validation** (or Dashboard → Validate All Content).
On top of the original checks (duplicate ids, missing icons/sprites/music,
recipe/loot references, required item fields), the factory adds:

- Items: unknown category.
- Heroes/entities with manifests: missing movement animations, manifest
  pointing at a missing sheet.
- Enemies: missing move/attack/defeat animations, unknown AI behavior.
- Customers: unknown/missing archetype, missing sprite (accounting for
  `hero_ref` sharing).
- Furniture: missing custom sprite, zero display slots, unknown allowed
  categories, missing size.
- Locations: invalid type, missing/broken tileset, tile indices beyond the
  tileset, missing player/customer spawns and exits per location type,
  unresolved `door_exit` targets.

## AI fill-in passes

Factory-created entries carry markers instead of guessed numbers:

- `needs_ai_balance` — prices, stats, loot tables, budgets need a balance pass
- `needs_description` — item `desc` is empty
- `needs_ai_personality` — customer quirk/line/archetype fit is placeholder

To run a pass later, ask Claude to grep `data/*.json` for these markers, fill
the fields in line with the surrounding entries (and
`docs/EXPANSION.md`/`data/balance.json` conventions), and remove the marker.
`tests/test_campaign.tscn` is the economy safety net after any balance change.

## Where things are stored

| Thing | Path |
|---|---|
| Inbox for new files | `assets/import_queue/` |
| Untouched originals | `assets/franchises/<world>/raw/` |
| Item icons | `assets/franchises/<world>/processed/items/<id>.png` |
| Entity sheets (copied) | `assets/franchises/<world>/processed/sheets/<id>.png` |
| Animation manifests | `assets/franchises/<world>/manifests/<id>.json` |
| Static entity sprites | `assets/franchises/<world>/processed/<id>.png` |
| Tilesets | `assets/franchises/<world>/processed/tilesets/<id>.{png,json}` |
| Furniture sprites | `assets/shared/furniture/<id>.png` |
| Copy provenance | `<file>.meta.json` sidecars next to every copied file |
| Game data | `data/items.json`, `data/heroes.json`, `data/customers.json`, `data/enemies.json`, `data/shop_furniture.json`, `data/locations.json` |

## Known limitations (first version)

- Collision/hurtbox boxes for heroes/enemies are not authored in the editor —
  the current combat derives its own shapes; manifest support can be added
  when combat reads them.
- SpriteFrames `.tres` export is not needed at runtime (SpriteFrames are built
  from manifests on the fly); `tools/sprite_importer/` still offers `.tres`
  export headlessly if you want committed resources.
- The Locations tab paints one tile at a time (no fill/stamp tools yet) and
  locations are not yet wired into scene routing — `LocationLoader.build()`
  is the runtime entry point for adopting them.
- Factory lists refresh after saves, but external edits to `data/*.json`
  need Dashboard → Reload.

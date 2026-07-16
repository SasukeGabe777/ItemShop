# Location / Tileset Editor

The Asset Factory's **Locations** tab is a first-version RPGMaker-style map
workflow: import a tile sheet as a tileset, paint a layered grid map, place
gameplay markers, and save it all as data.

## Importing a tileset

1. **Load Tile Sheet...** (any PNG — typically from `assets/franchises/<world>/raw/`).
2. Set the tile grid on the palette (`W`/`H`, `Margin`, `Spacing`).
3. **Save as Tileset** — copies the sheet to
   `assets/franchises/<world>/processed/tilesets/<id>.png` (raw untouched,
   sidecar written) and writes grid metadata to `<id>.json` next to it:

```json
{"id": "town_tiles", "sheet": "res://assets/franchises/<world>/processed/tilesets/town_tiles.png",
 "tile_size": [16, 16], "margin": 0, "spacing": 0, "columns": 12, "rows": 8}
```

## Editing a map

- Pick `<new>` or an existing location; set **Name**, **World**, **Type**
  (`shop`, `town`, `dungeon_room`, `story_scene`) and grid **W**/**H**.
- Choose the active **Layer**: `ground`, `decoration`, `collision`, `markers`.
- For tile layers: click a tile in the palette to make it the brush, then
  left-click/drag on the map to paint, right-click to erase.
- `collision` paints blocking cells (red overlay).
- `markers` places the selected marker type (one per cell, right-click
  removes): `player_spawn`, `customer_spawn`, `customer_exit`,
  `shop_counter_area`, `item_stand_slot`, `door_exit`,
  `dungeon_enemy_spawn`, `dungeon_chest_spawn`. For `door_exit`, fill the
  **Exit target** field with the destination location id first (empty target
  = flagged “unresolved” by validation).
- **Save Location** upserts the entry in `data/locations.json`.

## Location data format

```json
{
  "id": "my_shop", "name": "My Shop", "world": "crossroads",
  "location_type": "shop",
  "tileset": "res://assets/franchises/crossroads/processed/tilesets/town_tiles.json",
  "tile_size": 16, "width": 20, "height": 12,
  "layers": {"ground": [/* w*h tile indices, -1 = empty */], "decoration": [...]},
  "collision": [/* w*h 0/1 */],
  "markers": [{"type": "player_spawn", "x": 2, "y": 6},
              {"type": "door_exit", "x": 10, "y": 11, "target": "town_square"}]
}
```

## Validation rules

- shop: at least one `player_spawn`, `customer_spawn`, and `customer_exit`
  (error), `item_stand_slot` recommended (warning)
- town/dungeon_room: at least one `player_spawn`
- every `door_exit` needs a `target` that exists in `data/locations.json`
  (empty = warning “unresolved”, unknown id = error)
- tileset JSON/PNG must exist; tile indices must fit the tileset

## Runtime

`scripts/systems/location_loader.gd` (`LocationLoader`) instantiates a
location as a `Node2D`: nearest-neighbor tile sprites per layer,
`StaticBody2D` colliders for collision cells, and named `Marker2D` children
under `Markers/` (query positions with
`LocationLoader.markers_of(root, "customer_spawn")`).

The existing town/shop/dungeon scenes still build their rooms in code —
`LocationLoader` is the foundation for migrating them (or adding new
locations) incrementally; nothing is forced onto it yet, by design. The
dungeon's handcrafted room templates in `data/rooms.json` are unchanged and
separate.

## Limitations (first version)

- Single-tile brush only (no rectangle fill, stamps, or autotiling).
- No undo — repaint over mistakes.
- Layers beyond ground/decoration/collision/markers (e.g. above-player
  overhang) are not modeled yet.
- Uses JSON + sprites at runtime rather than Godot's TileMap resource; the
  data model is deliberately close to TileSet so a later migration is
  mechanical.

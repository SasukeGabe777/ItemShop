# Shop Furniture & Movable Item Stands

The shop's display spots used to be hardcoded crate markers built inline by
`scripts/shop/shop.gd`. They are now data-driven, movable furniture:

- **`data/shop_furniture.json`** — furniture *types* (`window_counter`,
  `wooden_shelf`, `round_pedestal`, `display_case`, `small_table`,
  `wall_rack`, ...). Edit or add types in the Asset Factory's **Shop
  Furniture** tab.
- **`autoload/shop_furniture_manager.gd`** (`ShopFurnitureManager`) — owns the
  shop's furniture *layout* (which pieces exist and where), maps furniture
  display slots to `InventoryManager.display` indices, and persists the layout
  in the save file.
- **`scripts/shop/display_furniture.gd`** (`DisplayFurniture`) — the runtime
  node: furniture sprite, one `ItemSprite` + `InteractionComponent` per
  display slot, optional collision (`blocks_movement`), edit-mode tinting.

## Furniture type fields

```json
{
  "id": "wall_rack", "name": "Wall Rack", "furniture_type": "wall_rack",
  "scenery": "",                    // key into Scenery art, if any
  "sprite": "res://assets/shared/furniture/wall_rack.png",  // custom art (optional)
  "size": [52, 18],                 // pixel footprint for placement checks
  "blocks_movement": false,         // true adds a StaticBody2D collider
  "display_slots": [[-16,-10],[0,-10],[16,-10]],  // local item positions
  "allowed_categories": ["weapon", "armor"],       // empty = anything
  "is_moveable": true,
  "customer_attention_modifier": 0.05,             // added to browse scoring
  "price_modifier": 1.0,
  "appeal_modifiers": {"intense": 1}
}
```

Sprite resolution: custom `sprite` PNG → `scenery` key → generated
`PlaceholderFactory.furniture_texture`.

## How the shop uses it

`shop.gd:_build_furniture()` asks `ShopFurnitureManager.ensure_layout()` for
the layout (generating the classic 4-column arrangement the first time or
after a shop expansion), then instantiates one `DisplayFurniture` per
instance. Display slot indices are assigned sequentially across the layout,
so `InventoryManager.display` (and existing saves) keep working unchanged —
slot 0 is still slot 0 no matter where its stand was dragged.

Customers no longer read hardcoded crate positions: browse points come from
`DisplayFurniture.slot_global_positions()`, and item scoring pulls placement
bonuses from `ShopFurnitureManager.slot_attention_bonus(slot)` — the classic
window bonus for the front slot indices plus the furniture's own
`customer_attention_modifier`. Adapter API for AI code:

- `ShopFurnitureManager.get_all_available_display_slots()` →
  `[{index, position, furniture_uid, type, allowed_categories, item_id}]`
- `ShopFurnitureManager.get_reachable_display_slots()` (same today; pathing
  constraints can hook in later)
- `ShopFurnitureManager.choose_display_slot_for_customer(cust)` →
  `{slot, item_id}` or `{}`

`allowed_categories` restricts what the slot picker offers (a wall rack only
takes weapons/armor).

## Shop Edit Mode

Walk to the **“Rearrange furniture”** interaction spot (right side of the
shop) and press E (not available mid-session):

- Moveable furniture highlights; click a piece to pick it up.
- The piece follows the mouse on an 8px grid, tinted green (valid) or red
  (out of bounds / overlapping another piece).
- Click to place, right-click to put it back, `E` or `Esc` to finish.

Placement is validated by `ShopFurnitureManager.placement_valid()` against
the room interior (`FURNITURE_AREA`) and every other piece's footprint.

## Saving

`SaveManager` persists a `furniture` section:
`{layout: [{uid, type, pos: [x, y]}], uid_seq}`. Displayed items stay in the
`inventory.display` section exactly as before. Old saves without the section
simply regenerate the classic layout — nothing breaks. Instances whose type
id no longer exists in `data/shop_furniture.json` are dropped on load.

## Limitations (first version)

- Furniture can be rearranged but not yet bought/sold/stored — the piece
  count is derived from the shop level's display slot count.
- Rotation is not supported (no `rotation` field saved yet).
- `price_modifier` / `appeal_modifiers` are stored and validated but not yet
  consumed by the economy; `customer_attention_modifier` is live.

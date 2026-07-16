# Next Tasks

Priorities are ordered by player value and dependency. Keep work narrow and do not begin another franchise world while the Kingdom Hearts route is awaiting human acceptance.

## Completed in the playable Kingdom Hearts slice

- A new game has a scoped starter inventory: Potion, Ether, and Gold Coin, with Sora's Kingdom Key already equipped.
- The first shop session uses one deterministic Moogle Broker while retaining the normal dynamic furniture targets, customer movement, and negotiation systems.
- The first Kingdom Hearts expedition is a two-room Traverse Town preset built from existing room templates: arrival plaza, then one open room with one Shadow.
- The Shadow produces a guaranteed, labeled Lucid Shard pickup. The final exit waits for its collection, and successful return transfers it to shop storage.
- The first recovered Lucid Shard sale is deterministic and still uses the normal display, browsing, negotiation, inventory, and economy paths.
- The automated Playtest Workspace route verifies the live Shadow fight and save/reload persistence for money, storage, displayed items, furniture placement, chapter state, and slice completion.
- The approved room scope is recorded in `docs/location_briefs/traverse_town_vertical_slice.md`; exact player instructions are in `docs/KH_VERTICAL_SLICE.md`.

## Priority 0 - Human acceptance of the playable slice

1. Play `docs/KH_VERTICAL_SLICE.md` from **New Game** without F1, debug commands, the editor, or manual file changes.
2. Record only the largest issue in each relevant category:
   - Could not understand how to place an item.
   - Customer movement looked broken.
   - Dungeon exit was unclear.
   - Sale screen was ugly.
3. If the route blocks, fix only that blocker and replay from the nearest normal save.
4. Confirm **Menu -> Save to slot -> Quit to main menu -> Load** restores money, storage, the moved stand, any displayed item, and the completed first expedition.

The small slice is accepted when a human completes both sales and the expedition in one session without development tools. The longer boss/World Shard/gate-repair route is not part of this acceptance check.

## Priority 1 - Longer Kingdom Hearts Chapter 1 route

1. Manually verify the existing five-room expedition, Corrupted Fat Bandit, World Shard, 10,000g repair, checkpoint, and continue flow.
2. Use findings from the small accepted slice; do not add new systems solely for the longer run.
3. Review Lady Luck's role, price, tags, stats, and acquisition source before exposing it as normal playable loot.
4. Replace only the most visible placeholder art encountered in the accepted route.

## Priority 2 - Stabilize content production needed by Kingdom Hearts

1. Fix the existing Asset Factory failure: `auto-detected wrong background color`.
2. Perform one reviewed end-to-end import for a relevant item icon, animated enemy, static customer, and location tileset.
3. Add regression coverage only for bugs found during those imports.

## Priority 3 - Locations after playable-route feedback

1. Keep the current two-room runtime preset until human feedback justifies a data-authored Traverse Town location.
2. If map work is approved, update the location brief first and connect one small location through the existing `LocationLoader`.
3. Do not migrate every campaign scene or expand tile-painting tools as part of that work.

## Later - Do not start yet

- Full vertical slices for Mario, Final Fantasy, Zelda, Naruto, Dragon Ball, and Pokemon.
- Broad location generation or migration of every scene.
- New combat classes, economy layers, crafting systems, or campaign modes.
- Large Asset Factory or Live Developer Hub additions unrelated to a recorded playtest blocker.

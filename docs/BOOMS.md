# Shop Booms

Booms are announced, session-based shop events that create a large temporary
crowd with focused merchandise demand. They are separate from market events:
market events change prices for a number of days, while a Boom changes customer
traffic and behavior until its configured number of shop sessions is consumed.

## Player flow

1. The day briefing displays a red **BOOM ALERT** before the shop opens.
2. The player prepares storage, display items, and shop appeal around the
   announced categories, tags, world, and attributes.
3. Opening the shop consumes one Boom session. Customers arrive in faster waves
   with a higher simultaneous-customer cap.
4. Matching customers heavily prefer matching display stock. If the shop has no
   announced goods, most Boom shoppers request a matching category/tag/world or
   leave disappointed.
5. Inexpensive configured categories can sell in small bundles. The normal
   customer budget, negotiation, relationship, equipment, inventory, and price
   tolerance systems still resolve the transaction.
6. The period summary reports the Boom, total arrivals, physical items sold,
   revenue, orders, and disappointed departures.

Repairing a World Bridge gate triggers a one-session **New World Celebration**
for that real world. Other Booms roll on new days using the global rarity and
per-Boom weight/cooldown rules. An announced Boom waits for a shop session; it
does not expire merely because the player spends time elsewhere.

## Data

Definitions live in `data/booms.json`. Every referenced archetype, category,
tag, world, and shop attribute is validated by `tests/test_booms.tscn` against
the current content database.

| Field | Purpose |
| --- | --- |
| `traffic_multiplier` | Multiplies the normal session customer count. |
| `max_live_customers` | Simultaneous crowd cap; remaining customers wait in waves. |
| `spawn_interval` | Minimum/maximum seconds between arrivals. |
| `named_chance` | Chance an arrival is a currently unlocked named customer. |
| `customer_weights` | Multipliers for existing customer archetype IDs. |
| `preferred_categories`, `preferred_tags` | Strong item-demand matches. |
| `preferred_worlds` | Static world demand; dynamic events use `dynamic_world`. |
| `preferred_shop_attributes` | Cozy/intense/retro/modern appeal that boosts traffic and tolerance. |
| `budget_multiplier` | Multiplies the customer's normal generated purse. |
| `purchase_quantity` | Inclusive desired bundle-size range. |
| `bulk_categories` | Categories allowed to sell more than one copy per negotiation. |
| `request_frequency` | Direct request chance when matching stock is absent. |
| `off_theme_purchase_chance` | Chance a Boom shopper accepts unrelated displayed goods. |
| `duration_sessions` | Inclusive number of shop sessions the Boom lasts. |
| `cooldown_days`, `weight`, `min_chapter` | Random scheduling controls. |
| `announcement` | Preparation text; `{world_name}` is substituted for dynamic events. |

The root `daily_roll_chance` controls how often a random Boom begins. The root
`max_customers_per_session` is a safety cap after traffic and appeal bonuses.

## Runtime and tools

`BoomManager` owns active/queued state, scheduling, world context, cooldowns,
and save/load. `CustomerGen` applies traffic, group weights, budgets, demand,
requests, and quantity. Both the live shop and `ShopSim` must call
`BoomManager.complete_shop_session()` exactly once after a completed session.

Debug console:

```text
boom
boom kids_adventure_day
boom new_world_celebration kingdom_hearts
boom random
boom clear
```

The Live Developer Hub's **Shop > Boom testing** section provides the same
force/clear workflow before opening the real shop.

## Verification

```powershell
tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests/test_booms.tscn
tools\Godot_v4.7.1-stable_win64_console.exe --path . res://tests/boom_shop_shot.tscn
```

The second command must be windowed. Inspect `boom_announcement.png`,
`boom_arrivals.png`, and `boom_crowd.png` in the normal Godot screenshots
folder.

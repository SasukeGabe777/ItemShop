# Location Brief: Traverse Town Vertical Slice

## Location ID

`kh_traverse_town_vertical_slice`

## Purpose

Provide the smallest complete first Kingdom Hearts expedition: leave the Crossroads with Sora, learn the dungeon exit rule, defeat one Shadow, collect a guaranteed Lucid Shard, and return that loot to the shop inventory.

## World

Kingdom Hearts / Traverse Town

## Visual Theme

A compact nighttime town plaza built from the project's existing Kingdom Hearts dungeon tiles and safe placeholder art. Readability and navigation take priority over decorative density.

## Player Experience

The player enters a quiet arrival room, walks north through one clearly marked exit, fights one Shadow in an open combat room, collects a visible Lucid Shard, and uses the north exit to return to the Crossroads. Expected duration is two to four minutes.

## Dimensions

Two rooms, each using the existing `20 x 12` dungeon-room grid:

1. Arrival plaza: existing `start_plaza` layout.
2. Combat plaza: existing `combat_arena_open` layout.

## Entrances / Exits

- Arrival: Sora spawns near the south-center of the first room.
- Room transition: the north doorway opens immediately in the arrival room.
- Return exit: the north doorway in the combat room opens after the Shadow is defeated.
- The HUD must state when the north exit is available.

## Enemies

- One `shadow_heartless` in the combat room.
- No boss in this first-run slice.

## Rewards

- One guaranteed, visible `lucid_shard` pickup from the Shadow encounter.
- Existing random enemy drops may still occur.
- Collected expedition loot transfers to shop storage on a successful return.

## Interactables

- North room exits using the existing dungeon door/room-transition behavior.
- Loot pickups using the existing pickup and expedition-loot systems.
- No new bespoke interactable types.

## Required Assets

- Existing Kingdom Hearts dungeon tiles, with safe fallbacks if missing.
- Existing Sora hero data and sprite/fallback.
- Existing Shadow enemy data and sprite/fallback.
- Existing Lucid Shard item data and icon/fallback.
- Existing dungeon doorway and loot-pickup visuals.

## Design Notes

- This is a first-expedition preset, not a new dungeon framework or location-editor format.
- Reuse `DungeonManager`, the runtime dungeon scene, room templates, enemy combat, and loot pickup systems.
- Keep the combat floor open so the player can read Sora, the Shadow, the reward, and the exit.
- Do not require a boss, bridge repair, or editor action to finish this loop.
- Store completion in normal campaign progress so save/reload preserves it.
- After the first successful slice, the existing longer Kingdom Hearts expedition may remain available for later development.

## Test Criteria

- A new campaign can select Sora and launch this route from the World Bridge.
- Exactly two rooms are generated for the first successful Kingdom Hearts expedition.
- The combat room contains exactly one Shadow.
- The Shadow can be defeated with normal player combat.
- A Lucid Shard pickup appears and can be collected.
- The north exit is visibly unlocked after combat.
- Leaving through it returns the player to the Crossroads and adds the collected shard to shop storage.
- Completion, inventory, money, furniture layout, and displayed items survive save/reload.
- No editor or manual data-file edit is required during play.

# Location Brief Template

Create and review this brief before generating, painting, or implementing a
location. Keep the proposal small enough to serve a specific playable route.

## Location ID

- Stable ID:
- Display name:
- Location type (`shop`, `town`, `dungeon_room`, `story_scene`, or proposed new
  type):

## Purpose

What player-facing need does this location serve? Why must it exist in the
current playable slice?

## World

- Franchise/world ID:
- Chapter or unlock condition:
- Relationship to connected locations:

## Visual theme

- Mood and palette:
- Architectural/environmental language:
- Readability priorities:
- Reference assets or approved inspiration:

## Player experience

Describe the intended emotional and mechanical experience from entrance to
exit. Include the main route, optional spaces, expected duration, and what the
player should understand by the end.

## Dimensions

- Grid width × height:
- Tile size:
- Approximate world-space size:
- Camera/viewport assumptions:

## Entrances and exits

| ID/marker | Position or edge | Destination | Unlock/condition | Return behavior |
| --- | --- | --- | --- | --- |
| | | | | |

## Enemies

| Enemy ID | Count/range | Placement or trigger | Purpose | Respawn rules |
| --- | --- | --- | --- | --- |
| | | | | |

## Rewards

| Reward ID/type | Source | Requirement | One-time/repeatable | Player value |
| --- | --- | --- | --- | --- |
| | | | | |

## Interactables

| ID/type | Location | Player action | Result | Required system |
| --- | --- | --- | --- | --- |
| | | | | |

## Required assets

- Tileset:
- Background/foreground art:
- Props:
- Character/enemy sprites:
- Item/reward icons:
- UI elements:
- Music/ambience/SFX:
- Credits/provenance requirements:
- Existing placeholders that are acceptable for this pass:

## Design notes

- Reused systems/components:
- Important collision and navigation rules:
- Save/load and return-state expectations:
- Performance or accessibility considerations:
- Explicit non-goals:
- Open decisions requiring human approval:

## Test criteria

- [ ] Location loads from the intended entry point without errors.
- [ ] Player spawns at the correct marker and can reach every required exit.
- [ ] Collision prevents leaving the intended play area without trapping the
      player.
- [ ] Entrances/exits route to the correct targets and preserve required state.
- [ ] Required enemies, rewards, and interactables appear and complete their
      intended behavior.
- [ ] The main route is visually readable at the target window size.
- [ ] Missing assets use agreed placeholders and are listed above.
- [ ] Save/load during or around the location preserves the required progress.
- [ ] Relevant automated validation passes.
- [ ] A human completes the intended route and records the result in
      `PLAYTEST_NOTES.md`.

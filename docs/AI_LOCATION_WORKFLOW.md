# AI Location Workflow

The Location Workshop is a guided design space inside the existing Crossroads
Asset Factory. It lets a person describe, build, launch, and review one small
location without editing Godot scenes or knowing node internals. It does not
generate finished maps automatically and it does not call an online AI.

## Open the Workshop

1. Open the project in Godot.
2. Open **Crossroads Asset Factory** in Godot's bottom panel.
3. Choose the **Location Workshop** tab.

The numbered tabs are the intended order. A brief, proposal, layout, and review
with the same location ID are separate artifacts, so a human and an AI partner
can revise the design without losing the reason behind it.

## 1. Human chooses the world and goal

Choose a world in **1 World**. The page lists the tilesets, enemies, rewards,
NPCs/customers, and existing locations currently available for that world.
Connected-room targets are shown when existing exit markers name them.

Choose an existing location to load its known fields, or leave **new location**
selected. Decide on one player-facing purpose, such as "cross a small plaza,
defeat one Shadow, collect a shard, and find the exit." Keep the room small
enough to test in a few minutes.

## 2. Workshop creates the location brief

In **2 Brief**, fill in the location name and stable ID, followed by purpose,
type, intended player experience, theme, dimensions, entries, exits, enemy and
reward plans, interactables, story events, and design notes.

Click **Save Location Brief**. The Workshop writes readable JSON to
`data/location_briefs/<location_id>.json`.

The location ID links every later artifact. Avoid changing it after layout work
has begun. **Apply Brief to Map** copies the ID, world, type, name, and dimensions
into the painter without requiring scene knowledge.

## 3. Claude or Codex proposes layout and gameplay

Click **Generate Layout Proposal** in **3 Proposal**. This saves
`data/location_briefs/<location_id>.proposal.json`.

The proposal is a deterministic starting template containing room purpose,
dimensions, tile zones, entries/exits, encounter and reward placement guidance,
interaction points, risks, possible missing assets, and acceptance criteria. It
does not paint the room.

For an AI-assisted revision, give the AI `LOCATION_PARTNER_PROMPT.md`, the brief,
the proposal, the review if one exists, `data/locations.json`, and the relevant
content/tileset data. The AI should inspect and propose a small change before
editing files.

## 4. Human approves or revises, then builds the room

Review the proposal against the intended experience. Update the brief and
regenerate the proposal if the plan is too large, unclear, or needs unavailable
assets.

In **4 Build Map**:

- Choose an existing tileset or load and save a new tile sheet.
- Click a tile in the nearest-neighbor palette.
- Select **ground**, **walls**, or **decoration**, then left-drag to paint and
  right-drag to erase.
- Select **collision** to paint blocked cells.
- Select **markers**, choose a marker type, and click a cell to place it.
- Drag an existing marker to move it. Right-click it to remove it.
- For an exit/door, enter the target location ID before placing the marker.
- Use the integer map zoom controls to inspect pixels without smoothing.
- Click **Save Location**. Use the existing-location list to reload it later.

The marker palette contains player spawn, customer spawn, customer exit, enemy
spawn, chest, item stand, exit/door, dialogue trigger, and boss trigger.

## 5. Human clicks Play This Location

Click the permanent **PLAY THIS LOCATION** button. The Workshop saves first and
launches the selected layout through the data-driven `LocationLoader` in a safe,
in-memory development campaign. This launch does not select or overwrite a
normal save slot.

Walk the route as a player would. Check the spawn, paths, collision, objective,
encounter spacing, reward visibility, and exit. A painted room may still use
placeholders when its tileset or runtime object art is incomplete.

## 6. Review is saved

In **5 Review**, record whether navigation, collision, objective, enemies, and
rewards work. Add visual problems, missing assets, and concise revision notes,
then choose **approved** or **revise** and save. The Workshop writes
`data/location_briefs/<location_id>.review.json`.

This is design evidence, not an automatic certification. A human-controlled
playtest is required before changing the decision to approved.

## Human/AI partnership loop

1. Human chooses the world and one player-facing goal.
2. Workshop creates a location brief.
3. Claude or Codex reads the brief, connected rooms, and available assets.
4. Claude or Codex proposes the smallest layout and gameplay change.
5. Human approves or revises the proposal.
6. Claude or the human builds the room with current systems.
7. Human clicks **PLAY THIS LOCATION** and plays it.
8. Human saves the review.
9. Claude or Codex reads the review and performs only the next justified
   revision.

Commit the brief, proposal, layout data, and review together when they describe
the same accepted revision. Keep normal campaign routing separate until the
location itself passes this loop.

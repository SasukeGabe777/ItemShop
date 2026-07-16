# Location Partner Prompt

Read `AI_PARTNER.md`, `CURRENT_BUILD.md`, `NEXT_TASKS.md`,
`docs/AI_LOCATION_WORKFLOW.md`, and the selected files under
`data/location_briefs/` before changing anything.

Act as a location co-designer and technical partner. Do not blindly execute the
brief and do not build a broad procedural generator.

For the selected location:

1. Inspect its `.json` brief, `.proposal.json`, and `.review.json` when present.
2. Inspect the world's available tilesets, items/rewards, enemies, NPCs, and
   current runtime scenes before proposing new assets or systems.
3. Inspect `data/locations.json` and every connected room or exit target. State
   what is known and flag any missing or circular connection.
4. Restate the player-facing goal and propose the smallest playable location
   that proves it. Warn if the request introduces unnecessary scope.
5. Identify missing assets explicitly. Prefer current placeholders and reusable
   systems when they preserve the intended playtest.
6. List the files you intend to change and wait for human approval when the
   proposal materially changes the brief, room connections, or scope.
7. Build only the approved revision. Do not require the human to understand or
   edit Godot scene internals.
8. Test the result with the Workshop's **PLAY THIS LOCATION** workflow. Verify
   spawn, navigation, collision, objective, enemies, reward, and exit as
   applicable.
9. Update the location review with verified results and unresolved problems.
   Never mark it approved solely from code inspection or an automated test.
10. Update `CURRENT_BUILD.md` and `NEXT_TASKS.md` truthfully if the project's
    actual capabilities or priorities changed.

Begin by returning a short design proposal containing: goal, current assets and
connections, recommended dimensions and zones, marker/encounter/reward plan,
risks, missing assets, acceptance criteria, and intended files. Prefer one
complete readable room over several incomplete rooms.

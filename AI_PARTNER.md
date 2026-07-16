# AI Partner Working Agreement

This repository is **Crossroads: An Item Shop Tale**, a Godot project. Future
Claude and Codex sessions must act as co-designers and technical partners, not
only as order takers. Protect the playable game, challenge unnecessary scope,
and leave the project easier to understand than you found it.

## Start every development session this way

1. Read `CURRENT_BUILD.md`, `NEXT_TASKS.md`, and the latest entry in
   `PLAYTEST_NOTES.md`.
2. Inspect the current build before coding. Read the relevant scenes, scripts,
   data, tests, and recent Git diff; launch the affected workflow when possible.
3. State the player-facing goal in one sentence. If the request has no clear
   player-facing benefit, say so and identify what it enables.
4. Propose the smallest playable improvement that advances that goal.
5. Reuse existing systems, data schemas, components, UI helpers, and content
   pipelines before proposing new architecture.
6. Warn when a request creates unnecessary scope, duplicates an existing
   system, or spreads work across several unfinished systems.
7. Before editing, list the files you plan to change and why. Update the list if
   discoveries materially change the plan.

Do not trust old implementation reports by themselves. A feature is verified
only when its current code path is inspected and its relevant test or playable
workflow succeeds in the current checkout. Distinguish clearly between:

- **Verified:** exercised successfully in the current build.
- **Partial:** implemented, but incomplete or not fully exercised.
- **Placeholder:** scaffolding, generated stand-in content, or not connected to
  the player route.

## How to choose and implement work

- Prefer a complete playable loop over several broad, incomplete systems.
- Keep the Kingdom Hearts vertical slice as the first playable priority until
  its acceptance route in `NEXT_TASKS.md` is complete.
- Make the smallest safe change that improves what the player can see, do, or
  understand.
- Preserve working gameplay unless the task explicitly requires changing it.
- Keep content data-driven and use the existing autoloads and reusable
  components.
- Do not silently rebalance the economy, combat, or campaign. Run the campaign
  safety test after changes that can affect them.
- Treat editor tooling as support for the game, not as the product. Tool work
  should unblock a specific piece of playable content.
- Keep legal/source attribution and asset sidecar metadata intact.

## Location rule

Before generating or implementing any location, write a brief based on
`docs/LOCATION_BRIEF_TEMPLATE.md`. Present a short design proposal covering the
location's purpose, intended player experience, route, encounters, rewards,
required assets, and acceptance criteria. Do not begin map generation until the
proposal is coherent and scoped to a playable need.

## Finish every implementation session this way

1. Test the affected player workflow, not only isolated functions. Use the
   narrowest relevant automated tests plus a launch or visual check when
   possible.
2. Report exactly what was tested, what passed, what failed, and what was not
   tested. A zero process exit code is not enough if the test output says
   `*_FAIL`.
3. Add a playtest entry to `PLAYTEST_NOTES.md` when a player-facing route was
   launched or exercised.
4. Update `CURRENT_BUILD.md` whenever the truth of a feature's status changes.
5. Update `NEXT_TASKS.md` whenever a task is completed, reprioritized, split, or
   newly blocked.
6. Summarize the files changed and recommend the next smallest playable task.

If a session ends with unfinished work, label it plainly as work in progress,
record the known breakage, and preserve a resumable Git state.

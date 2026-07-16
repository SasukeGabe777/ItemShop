# Next Tasks

Priorities are ordered by player value and dependency. Keep tasks narrow enough
to finish and verify. Do not begin broad work for later worlds while Priority 0
is incomplete.

## Priority 0 — Complete Kingdom Hearts vertical slice

Target acceptance route:

> Start a new game, view the intro, walk the Crossroads, enter and stock the
> shop, complete a live sale/negotiation, prepare Sora, enter the Kingdom Hearts
> dungeon, defeat the Corrupted Fat Bandit, collect the Traverse Town World
> Shard, return, pay 10,000g, repair the gate, save, quit, and continue from the
> saved slot without losing state.

The slice is complete only when a human can perform that route without debug
commands and the relevant automated tests remain green.

1. **Manually play the complete Chapter 1 acceptance route.** Record the exact
   route, blockers, confusing steps, economy friction, and visual issues in
   `PLAYTEST_NOTES.md`. Fix only progression blockers found during the run.
2. **Verify live shop usability.** Play stocking, one customer session,
   negotiation/counteroffer, order behavior, session summary, and save afterward.
   Confirm the dark/empty-looking shop HUD capture is timing-only or fix the
   smallest real presentation defect.
3. **Verify the complete live dungeon route.** Play all five rooms with Sora,
   including movement, attacks, special, dodge, consumable, loot pickup, boss,
   return flow, and shard persistence. Keep the existing combat architecture.
4. **Complete only the KH art needed by that route.** Wire dedicated sprites for
   Soldier Heartless, Yellow Opera, and Red Nocturne; replace the most visible KH
   item/customer placeholders encountered in the acceptance route. Preserve
   credits and provenance metadata.
5. **Review new KH data.** Give Lady Luck a deliberate role, price, description,
   tags, stats, and acquisition source, or remove it from the playable slice
   until those decisions exist. Review any `needs_ai_*` fields added by tools.
6. **Create a Traverse Town location brief before map work.** Use
   `docs/LOCATION_BRIEF_TEMPLATE.md`; agree on the player experience and asset
   list before generating or wiring a location.
7. **Polish the Chapter 1 presentation only after the route works.** Address
   viewport composition, placeholder geometry, interaction clarity, and the
   smallest audio/visual gaps visible in the acceptance route.
8. **Run the full acceptance checks.** Boot, parse, campaign, Asset Factory,
   windowed live combat, screenshot tour, Python tests, and a manual save/continue
   replay. Update `CURRENT_BUILD.md` with the new truth.

## Priority 1 — Stabilize content production needed by Priority 0

1. Fix the Asset Factory test failure:
   `auto-detected wrong background color`.
2. Perform one reviewed end-to-end import for each relevant workflow: item icon,
   animated enemy, static customer, and location tileset. Confirm data, asset,
   manifest, sidecar, validation, and runtime output.
3. Add regression coverage for any bug found during those imports. Do not expand
   the editor with unrelated features while its current write paths are unproven.
4. Decide whether the standalone sprite importer remains a supported fallback or
   whether its unique `.tres`/atlas functions should be folded into the Factory.

## Priority 2 — Locations after the KH brief is approved

1. Implement one small Traverse Town location from an approved brief.
2. Connect it through the existing `LocationLoader` with the smallest routing
   change possible; do not migrate every scene at once.
3. Verify entrances/exits, collision, player spawn, enemies, rewards, and return
   routing in a real playtest.
4. Only then decide whether town/shop/dungeon layouts should adopt location data
   more broadly.

## Priority 3 — Quality and maintainability

1. Turn test output failures into reliable nonzero process exits where practical;
   today the Asset Factory printed a failure while the shell still saw exit 0.
2. Add a launch/playtest command that captures logs without colliding when two
   Godot instances run simultaneously.
3. Refresh the root `README.md` so it introduces the game first and links to the
   downloader documentation second.
4. Review historical implementation reports and mark them as historical so they
   cannot be mistaken for current verification.

## Later — Do not start yet

- Full vertical slices for Mario, Final Fantasy, Zelda, Naruto, Dragon Ball, and
  Pokémon.
- Broad location generation or migration of every scene.
- New combat classes, economy layers, crafting systems, or campaign modes.
- Large Asset Factory feature additions unrelated to completing real content.

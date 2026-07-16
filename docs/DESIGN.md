# Crossroads: An Item Shop Tale — Design Document

The full concept lives in the original brief; this file records how the build
maps onto it and what each system actually does.

## Fantasy

You are **Hero** (the supplied Omori "Hero (Faraway)" sprite), shopkeeper of the
Crossroads — the neutral hub between game universes. The World Bridge has
shattered. Rebuild its seven gates in 35 days by running the item shop,
recovering World Shards from corrupted dungeons, and paying repair fees.

**Patch** (a floating fragment of the bridge's maintenance system) is advisor,
tutorial voice, comic relief and the story's emotional center. **The Fade** —
the apparent villain — is abandoned data: forgotten worlds that were excluded
when the bridge was first built. The ending adds an eighth, unconditional gate.

## Campaign skeleton

- 35 days, 7 chapters x 5 days; day = Morning / Afternoon / Evening / Night.
- Shop session = 1 period; expedition = 2; rest = 1. UI always confirms cost.
- Chapter deadline (end of day 5/10/15/...): the chapter's World Shard must be
  recovered **and** the repair fee paid, or the gate collapses.
- Failure → restart chapter from its checkpoint, retaining merchant level,
  customer knowledge, encyclopedia, tutorials, decorations, and up to 10 chosen
  inventory items (all configurable in `data/balance.json`).
- After chapter 7 the Null Archive opens; defeating The Fade rolls the ending
  and unlocks Endless Mode.

## Chapters

| Ch | World | Location | Hero | Boss | Repair |
|----|-------|----------|------|------|--------|
| 1 | Kingdom Hearts | Traverse Town | Sora | Corrupted Fat Bandit | 10,000 |
| 2 | Mario | Mushroom Kingdom | Mario | King Bob-omb | 25,000 |
| 3 | Final Fantasy | Crystal Ruins | Cloud | Behemoth | 60,000 |
| 4 | Zelda | Lost Woods & Hyrule Ruins | Link | Gohma | 120,000 |
| 5 | Naruto | Hidden Leaf Outskirts | Naruto | Zabuza | 225,000 |
| 6 | Dragon Ball Z | Broken Lookout | Goku | Great Ape Vegeta | 400,000 |
| 7 | Pokémon | Viridian Path & Cerulean Depths | Pikachu | Mewtwo | 700,000 |
| F | Null Archive | — | any unlocked | The Fade | — |

All of this is data (`data/worlds.json`); nothing franchise-specific is
hardcoded in systems.

## Economy

The deliberate growth curve that lets 10k scale to 700k:

- **Prosperity**: every repaired gate multiplies all market prices by 1.4
  (compounds; `prosperity_gate_growth`), plus 2% per merchant level. More
  worlds connected = more trade through the Crossroads. Wholesale costs scale
  identically, so *margins* grow while stocking stays meaningful.
- Customer budgets ride prosperity plus a per-chapter bump.
- Dungeon loot is free inventory — late-game boss farming (Mewtwo's Master
  Ball, Vegeta's Dragon Balls) is the intended big-ticket supply, exactly like
  Recettear's dungeon economy.
- Market events (`data/market_events.json`) multiply prices by tag/category
  for 1–4 days (healing shortages, evolution-stone rushes, mushroom
  oversupply...).
- Negotiation: propose a price; the customer's tolerance = archetype markup
  x relationship x mood x preference x shop-appeal match x merchant skill.
  Results: Perfect Deal / Accept / Counteroffer / Final Warning / Leave.
  First-offer successes build a combo that nudges tolerance shop-wide.

Verified by simulation: an automated "sensible player" completes all seven
repairs by ~day 31 (`tests/test_campaign.gd`).

## Combat

One shared controller (`CombatHero`): move, 3-hit basic combo, special, dodge
or guard, consumable, full-meter finisher. Per-hero data (`heroes.json`)
selects special kind (projectile / burst / dash / clones / spin), dodge kind
(roll / vanish / guard) and finisher (AOE or beam). Juice: hit-pause, screen
shake, damage numbers, particles, knockback, i-frame blink, attack trails,
boss telegraph rings. Enemies use 14 data-driven behavior archetypes
(chaser, lunger, shooter, bomber, shy_ghost, swooper, creeper, ambusher,
splitter, teleporter, shell, tank, skitter_shooter, boss variants).

## Shop appeal

Four theme values — cozy / intense / retro / modern — summed from displayed
items' `appeal` tags. Dominant appeal attracts matching archetypes (shown in
storage UI). Window slots (front counter) get an attention bonus.

## Asset pipeline

- `assets/<pack>/raw` (originals) → `manifests` (JSON: grid, pivot,
  animations) → `processed` (atlases / SpriteFrames .tres).
- `tools/sprite_importer` — GUI + headless batch importer.
- Anything missing renders as a generated pixel placeholder at runtime
  (`PlaceholderFactory`) — the game never breaks on absent art.
- Music: original procedural chiptune placeholders; user overrides by dropping
  a correctly named .ogg/.wav into `user://music_overrides/`.

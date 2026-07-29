# Crossroads Core Loop Baseline Audit

Generated deterministically by `tools/core_loop_audit.py`.

- Items: 268 (216 live with art)
- Rarities: Common 77, Legendary 33, Rare 74, Uncommon 84
- Errors: 0
- Warnings: 4

## Chapter availability

| Chapter | Price cap | Obtainable | Market | Newly obtainable | World |
|---:|---:|---:|---:|---:|---|
| 1 | 800g | 8 | 4 | 8 | kingdom_hearts |
| 2 | 1480g | 35 | 21 | 27 | mario |
| 3 | 2160g | 42 | 25 | 7 | final_fantasy |
| 4 | 2840g | 73 | 48 | 31 | zelda |
| 5 | 3520g | 102 | 64 | 29 | naruto |
| 6 | 4200g | 143 | 95 | 41 | dragon_ball |
| 7 | 4880g | 187 | 122 | 44 | pokemon |
| 8 | 5560g | 187 | 122 | 0 | null_archive |
| 9 | 6240g | 215 | 150 | 28 | rotmg |

## World opening stock

| World | Chapter | Authored | Live | Affordable at unlock |
|---|---:|---:|---:|---:|
| Kingdom Hearts | 1 | 10 | 4 | 4 |
| Mario | 2 | 23 | 17 | 17 |
| Final Fantasy | 3 | 13 | 6 | 4 |
| The Legend of Zelda | 4 | 22 | 22 | 21 |
| Naruto | 5 | 15 | 15 | 15 |
| Dragon Ball Z | 6 | 32 | 32 | 31 |
| Pokémon | 7 | 29 | 27 | 27 |
| The Null Archive | 8 | 0 | 0 | 0 |
| Realm of the Mad God | 9 | 28 | 28 | 28 |

## Findings

- **WARNING · market_goods_missing_art** — kingdom_hearts has market goods without live item art
- **WARNING · market_goods_missing_art** — mario has market goods without live item art
- **WARNING · market_goods_missing_art** — final_fantasy has market goods without live item art
- **WARNING · market_goods_missing_art** — pokemon has market goods without live item art

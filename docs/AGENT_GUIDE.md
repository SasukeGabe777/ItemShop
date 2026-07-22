# Agent Guide — working on Crossroads like a veteran

This document is written by an AI agent, for AI agents (Claude, Codex, or
anything else). It captures hard-won operational knowledge from many sessions
of building this game — the loop, the tools, the extraction recipes, the traps
that repeatedly cost hours, and the *reasoning* behind decisions, so you can
make consistent calls on new problems. Read it fully before your first change.

Companion docs: `docs/ARCHITECTURE.md` (autoloads, components, scene shape),
`docs/CONTENT_PIPELINE.md` + `docs/ASSET_FACTORY.md` (asset flow, editor
tooling), `docs/EXPANSION.md` (data schemas). This guide is the layer those
don't cover: how to actually *work* here.

---

## 1. Who you are working with, and the shape of a session

The user playtests **`export\crossroads.exe` on a controller**, then returns
with a batch of feedback ("Link's sword doesn't animate, the boss looks
broken, walls are messy"). They do not run the editor. Two consequences:

- **Every change you make is invisible until you re-export.** A session that
  ends without an export shipped nothing.
- **Feedback describes what a player *saw*, not what the code does.** "The
  boss sprite is broken" turned out to mean "the boss is a single static
  frame sliding around". "Sword doesn't play the animation" meant "the frames
  play, but the blade isn't visible in them". Before coding a fix, reproduce
  what the player saw with your own eyes (screenshots, below), then diagnose.

The expected cycle for every task, no exceptions:

```
implement → (re)import assets → probe with logic checks → probe with
WINDOWED screenshots and LOOK at them → export exe → commit
```

## 2. The command loop (exact commands, PowerShell-safe paths)

Run from the repo root. The Godot binary lives in-repo:

| Step | Command |
|---|---|
| Reimport after any PNG/asset change | `tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . --import` |
| Headless logic probe | `tools\...console.exe --headless --path . res://tests/<probe>.tscn` |
| Windowed probe (screenshots) | `tools\...console.exe --path . res://tests/<probe>.tscn` (NO `--headless`) |
| Export (mandatory before ending) | `tools\...console.exe --headless --path . --export-release "Windows Desktop" "export/crossroads.exe"` |

**Why each rule exists:**

- `--import` first: plain game runs use the stale `.godot/imported` cache; you
  will stare at old art and think your fix failed.
- Screenshots **must** be windowed: headless uses a dummy renderer, so
  `get_viewport().get_texture().get_image()` returns **null** (error:
  `texture_2d_get: Parameter "t" is null`) and the probe hangs at the crash.
  Logic-only checks are fine headless.
- Capture run output to a file and grep the file
  (`... > log.txt 2>&1; grep PATTERN log.txt`) — grepping a live pipe
  block-buffers and can show nothing even though the run printed.
- Python for asset work is **`.venv312\Scripts\python.exe`** (has Pillow +
  numpy). The plain `.venv` does not have PIL.
- Multi-line python: use the bash tool with `<<'EOF'` heredocs. PowerShell
  here-strings cause parse pain; don't fight it.

## 3. Verification playbook (the part that catches real bugs)

Write throwaway probe scenes in `tests/` (a bare `.tscn` with one script).
Patterns that work, learned the hard way:

**Two-stage probes for scene changes.** `SceneRouter.go("dungeon")` frees the
current scene — including your running probe script. Hand off to a second
node parented to the **root** first:

```gdscript
var prober := Node.new()
prober.set_script(preload("res://tests/my_probe_stage.gd"))
get_tree().root.add_child(prober)          # survives the scene change
DungeonManager.plan_expedition("zelda", "link", [], false)
SceneRouter.go("dungeon")
```

**Screenshot mechanics.**
- Wait ≥ 0.4 s after window creation before the first capture — earlier frames
  come back solid white.
- The logical viewport is **640×360** rendered at 2× into a 1280×720 window.
  Lay montage content inside 640×360 or it silently falls off-screen.
- Shots land in `%APPDATA%\Godot\app_userdata\Crossroads- An Item Shop Tale\screenshots\`.
- **Actually open and look at every screenshot.** Twice this project shipped
  something a probe "passed" because only the printed checks were read.

**Driving the real game from a probe** (closest thing to the player's build):
- `get_tree().get_first_node_in_group("dungeon_runtime")` → the dungeon; read
  `hero` and `layout` from it; `dungeon.call("_enter_room", layout.size() - 1)`
  jumps straight to the boss room.
- Force hero actions: `hero.facing = Vector2(1, 0); hero._do_basic_attack()`,
  or `hero.meter = 100.0; hero._do_special()`.
- Standard state reset before an expedition: `GameState.reset_campaign()`,
  `TimeManager.reset(4)`, `EconomyManager/InventoryManager/BridgeManager/
  StoryEventManager/DungeonManager .reset()`.

**Interrogating the exported exe.** The export **excludes `tests/**`**, so
you cannot boot the exe into a probe scene (an `export/override.cfg` trick
fails on the missing resource — and delete that file if you create it; it
changes the shipped game's settings). To confirm an asset made it into the
pack: `grep -c "asset_name" export/crossroads.exe` — the pck index stores
path strings, so a hit means the file (and its `.ctex`) is inside.

**Don't trust one screenshot for "X is invisible".** A boss that chased the
player off-camera looked like a broken sprite in shot #1 and was perfectly
fine in shot #2. Take a time series, print positions alongside
(`print(boss.global_position, cam.get_screen_center_position())`), and only
then conclude.

## 4. Sprite extraction — the chroma recipe book

All extraction is scripted in `tools/*.py` using `tools/slice_lib.py`. Scripts
are kept in-repo and re-runnable; they are the permanent record of *how* an
asset was produced. Never hand-edit a processed PNG; fix the script and rerun.
Never modify anything under `assets/franchises/<world>/raw/` — raw is the
provenance record.

### The toolbox (`tools/slice_lib.py`)

| Function | Use when |
|---|---|
| `chroma_key(img, color, tol)` | remove one flat background color globally |
| `find_islands(img, min_area, merge_gap)` | split a keyed sheet into per-sprite bounding boxes |
| `largest_component(img)` | crop contains stray junk (ripper credit text, neighbor sprite slivers) — keep only the biggest connected blob |
| `keep_components(img, min_area)` | multi-part sprite where largest_component would eat detached bits |
| `clean_alpha(img, lo, hi)` | after keying/resizing: snap semi-transparent fringe, trim to content bbox |
| `flood_bg(img, is_bg_fn)` | background color also occurs INSIDE the art (green tree on green grass): flood from the borders only — interior pixels of the same color survive because the flood can't cross outlines |
| `resize_rgba(img, size)` | capped downscale (then `clean_alpha(lo=96, hi=160)` to re-crisp) |

### Decision tree for a new sheet

1. Sample the corner pixel. Flat, single-color background → `key_corner`
   (chroma the corner color + always magenta as a bonus pass).
2. Sheet has framed cells (sprite boxes on a second color) → key corner color
   **+ the cell color sampled from inside a cell** + white if the outer bg is
   white. Cell colors seen in Minish Cap rips: teal `(64,176,136)`, blue
   `(0,172,255)`, navy `(56,64,160)`.
3. **White- or light-bodied sprite on a white-backed sheet** (ghost, white
   armor): NEVER blanket-key white — you will eat the body (a keyed darknut
   showed up as headless robes). Pass an explicit color list that excludes
   the body's colors.
4. Object sitting on busy terrain in a *map* (grass, sky, dirt): `flood_bg`
   with a hue predicate, e.g. grass `(g > r+15) & (g > b+50)`, sky
   `(b > r+30) & (b > 180) & (g > 150)`. Global keying would punch holes in
   same-hued art; flooding only eats the connected outside.
5. After any crop: `largest_component` (or `keep_components`) + `clean_alpha`.
   Ripper text loves to sit inside island bboxes.

### The workflow that prevents guessing

Generate a **labeled contact sheet** (draw each island's index on it), save to
a scratch dir, and *view the image* before picking indices. Choose frames by
island index, note them as constants in the script with a comment naming the
contact sheet they were verified on. When a pick is wrong (crowned variant,
wrong facing, propeller-only fragment), you fix one integer.

**THE SCALE TRAP (has burned multiple hours, twice):** contact sheets and
zoom renders are saved at 2–6× scale. Any pixel coordinate you read off such
an image **must be divided by that scale** before use. Boss idle cells were
once cut at display coordinates → empty frames (0 opaque pixels). If a
cut produces empty/absurd output, check this first.

**Coordinate hygiene:** when you crop a band then find islands inside it, the
island boxes are band-relative — offset them back
(`(b[0]+box[0], b[1]+box[1], ...)`) before cropping from the full sheet.

### Real-game reference capture (`tools/rom_ref/` — the quality path for hero anims)

When ripped sheets can't tell you frame order/timing (or lack the weapon), capture
the real game. BizHawk + ROMs + converted battery saves live in `savestates/`
(gitignored, never committed). Launch:
`savestates\BizHawk-2.11.1-win-x64\EmuHawk.exe --lua=<abs path to script.lua> "<abs path to rom>"`.
Lua scripts boot File 1 from the title screen (`wait(900)`, then the proven
Start/A sequence in `capture_link_moves.lua`), drive the hero with
`joypad.set`, and per frame dump OAM + OBJ-VRAM + OBJ-palette binaries;
`decode_oam.py` then reconstructs the hero isolated on transparency — no
background, no chroma key. Hard-won isolation rules (v1 broke immediately):

- **Never isolate by screen-position band** — it breaks as soon as the hero
  drifts (blocked walk, camera edge). Instead: drop static HUD objects (same
  OAM tuple in >60% of all frames), keep the hero's **palette bank** (Link = 6)
  plus any non-HUD object within 24 px of the body bbox (that pulls in sword +
  effect sprites), and **anchor the crop on the drop-shadow object** (Link:
  pal 5, tile 1) so every frame lands feet-registered in its cell.
- **Prove a cycle repeats before picking frames**: 24 walk dumps looked like a
  complete 8-pose cycle; a 60-frame run showed the real cycle is 10 poses.
  `unique_poses.py` prints the pose-order string — trust it, not your eyes.
- **Blinks/fidgets need dense sampling** (every 4 frames for ~10 s of standing).
  Spaced idle dumps (every 20–45 frames) missed the 6-frame blink entirely.
- `tools/build_link_from_oam.py` maps picked pose tags → sheet + manifest and is
  the permanent record of the picks (inputs themselves are gitignored).

### Known-good source recipes (verified, reuse as-is)

- Minish Cap enemy rips: see the `ZE` table in `tools/prep_zelda_world.py` —
  per-file key mode, crop, island params, picks. Ghini = navy cells
  `(56,64,160)` + green, no white. Darknut = lavender `(184,184,216)` + teal,
  no white.
- Boss sheets (`boss_1/2/3.png`): labeled rows Idle / Hit / Jumping / Falling
  / Death on cell backgrounds (boss_1 blue `(0,172,255)`, boss_2 teal
  `(64,176,136)`, outer white). Idle is the lone top cell; Jumping is the
  4-cell row at y≈118–140. `tools/fix_zelda_pass2.py` extracts them.
- Beanbean avenue trees: crowns against sky, cut just above the hedgerow
  (`tools/cut_obstacle_props.py`).
- Esperville pines: tileset rows on pure black at the sheet's bottom-left.
- Lon Lon props (boulder/rocks/haystack/stumps): objects on plain grass,
  flood the greens.
- Naruto: Path of the Ninja 2 enemy sheet: a palette-variant grid where **every
  cell has its own background colour**, so no single key works. Cells are
  auto-detected as large uniform-colour regions and each is keyed against its
  own background (`detect_cells` in `tools/prep_naruto_world.py`) — reuse this
  whenever a rip is "the same creature in N colours".
- Objects on busy terrain that share the terrain's hue (a green tree on green
  grass) cannot be flooded reliably; pick a non-green prop instead (posts,
  rocks, stumps) rather than fighting the key.
- Room crops: when a map's screens are narrower than 640, cut 320x192 and
  upscale 2x. Besides fitting, it lands each 16px source tile on exactly one
  32px dungeon cell.

## 5. Manifests and the CharacterVisual contract

Animated entities load a JSON manifest
(`assets/franchises/<world>/manifests/<id>.json`):

```json
{ "asset_id": "...", "sheet": "res://.../sheets/x.png",
  "native_scale": 1, "display_scale": 1, "pivot": [cx, feet_y],
  "grid": {"frame_width": W, "frame_height": H, "columns": C, "rows": R},
  "animations": {"idle_down": {"frames": [0], "fps": 3, "loop": true}, ...} }
```

Rules that make sprites behave:

- **Pivot is the feet.** `CharacterVisual` aligns pivot to the node origin;
  enemies also size hurtboxes from measured frame size, so a wrong pivot
  drags hitboxes with it.
- Animation names: `idle_/walk_` × `down/up/side`; attacks
  `attack_1_down|side|up`, `attack_2_*`. `play_action` fallback chain:
  `attack_N_<dir>` → `attack_N_side` → `attack_N` → `attack_1_*` — so a
  3-hit combo works even on 2-attack sheets.
- **Side frames are stored RIGHT-facing**; the engine `flip_h`'s for left.
  Most GBA rips face left — flip at extraction.
- **Never ship a one-frame character.** A single static frame gliding around
  reads as "broken sprite" to players (exact playtest quote). Minimum: idle
  frame + 2–4 walk frames. Mine the rip's labeled rows (Jumping made a great
  hop-walk for the ChuChu bosses; a second winged frame made Vaati flap).
- If the game-side pose lacks its weapon (MC bodies carry no sword), look for
  a **separate overlay sheet** (sword-only frames with a green hilt marker)
  and composite at build time: windup frame bare, extended frames with the
  blade pasted at a fixed per-direction offset. Grow the cell (26×28 → 48×48)
  so the blade fits; hero hurtboxes are fixed-size circles in
  `combat_hero.gd`, so cell growth is safe for heroes (NOT for enemies, which
  measure their art).

## 6. Data wiring

Data lives in `data/*.json`, loaded by `ContentDatabase` (see
`docs/EXPANSION.md` for schemas). Operational rules:

- **Indentation is load-bearing for diffs**: `worlds/enemies/items/heroes
  .json` use `indent=1`; `data/customer_visuals.json` uses `indent=2`.
  Rewriting with the wrong indent once produced a 1464-line diff for an
  85-line change. Match the file you're touching.
- Write wiring as **idempotent python scripts** in `tools/` (strip your
  world's entries, re-add them). Safe to edit + rerun; doubles as
  documentation of what was added.
- Item icons: `assets/franchises/<world>/processed/items/<item_id>.png`.
  `ContentDatabase.live_items` only surfaces items *with icons* — a wired
  item without an icon silently never appears in shops.
- Names/prices/descriptions must be **franchise-authentic** — check the wiki
  for the source game rather than inventing ("use the wiki" is a standing
  user instruction). Flavor text can wink at the shopkeeping premise.
- Music: `dungeon.gd` plays track `dungeon_<world_id>`; `AudioManager`
  resolves `assets/music/user_overrides/<track>.mp3` automatically — drop-in
  files just work, no wiring.
- Boss rotation: `boss_rotation` array in the world's `worlds.json` entry,
  indexed by `expedition_wins_<world>` (clamped at the last entry).
- Customer pool: entries in `customer_visuals.json` `pool`; named story
  customers match pool entries by slug/name.

## 7. Combat & entity model (what plugs into what)

- Collision layers: 1 = walls, 4 = enemy body, 8 = enemy hurtbox
  (`LAYER_ENEMY_HURT`), 16 = player hurtbox.
- Damage flows through dictionaries ("packets"): `{"damage": int,
  "knockback": float, "source": node}` → `HurtboxComponent.receive` /
  `take_packet`. New attack types (e.g. `bomb.gd`) reuse this — AOE = iterate
  group `"enemies"`, range-check, `take_packet`.
- Hero specials are data-driven: `combat.special.kind` in `heroes.json`
  switches in `combat_hero.gd::_do_special` (`dash`, `projectile`, `clones`,
  `bomb`, ...). Adding a kind = one `match` arm + a data blob.
- Dodge kinds are **deliberate character design**, not bugs: `roll`
  (Sora/Mario/Pikachu/Link — dash + iframes; Link switched from guard to roll
  at the user's direction 2026-07-20 after his real Minish Cap R-roll was
  captured), `guard` (Cloud — hold to block 75% damage; the flash is the
  guard-up cue), `vanish` (Naruto/Goku). Don't "fix" a guard character into
  a roller because it feels different. Dodge/special can play real frames:
  `combat_hero` calls play_action("roll"/"special") — no-op without art.
- Obstacles/walls (`dungeon.gd::_wall`): perimeter walls are **always flat
  `wall_color` polygons — never textured**. Interior obstacles in worlds with
  `obstacle_props` (worlds.json, full `res://` paths, loaded directly — NOT
  via `Scenery.texture_or_null`, which prepends its own dir and `.png`) get
  **one unscaled prop per 32px cell**, variant + jitter chosen by a stable
  position hash (same room → same look), bottom-aligned per cell.
  **Why:** stretching/tiling map-crop textures over arbitrary rects smears
  them and drags their baked-in ground along — it made every dungeon look
  pasted-over (major playtest complaint). Props must be background-free
  objects, ≤ 36px, cut via §4. Worlds without props fall back to flat
  lightened polygons, which read fine.

## 8. Pitfall quick-scan (check before deep debugging)

| Symptom | First suspect |
|---|---|
| Fix invisible in game | forgot `--import`, or user is on a stale exe (re-export) |
| Probe screenshot crash `Parameter "t" is null` | you ran headless; rerun windowed |
| First screenshot solid white | captured before ~0.4s warmup |
| Probe content off-screen | layout exceeds 640×360 logical viewport |
| Extracted frame empty / nonsense | contact-sheet scale trap — divide coords |
| "1 island" from find_islands | background not fully keyed (cells/dialog borders merge everything) |
| White body parts vanish | blanket white key on a white-bodied sprite |
| Sprite has garbage text baked in | island bbox overlaps ripper credit — `largest_component` per frame |
| Icon/prop clipped | `largest_component` ate a detached part — widen crop or `keep_components` |
| "X doesn't render" in one screenshot | may be off-camera — time series + position prints before concluding |
| Giant diff on a data file | wrong JSON indent for that file, **or** Python wrote CRLF — these files are LF, so always `open(..., newline="\n")` |
| grep on godot output shows nothing | block buffering — write to a log file, grep the file |
| Corner key leaves "1 island" on a character sheet | 1px **border frame** around the sheet: the corner samples the frame, not the background. Sample `(1,1)` too and key both |
| Extraction picks a title letter / HP bar / manga panel | score islands for character-likeness: fill ratio < 0.82 (panels are solid), mean chroma > 12 (title letters are achromatic), ≥ 9 colours (UI text is flat) |
| Sprite has a "STAND"/"Block" label stuck to it | label shares the island bbox — `largest_component` per frame |
| Probe screenshots blank white despite a wait | warmup scales with asset count; a world-sized addition can need 2.5–3.5 s, not 0.4 s |
| Texture loads as null in `_wall`/props | passed full path to `Scenery.texture_or_null` (it wants a bare name) — `load()` full paths directly |
| OAM-decoded hero frames vanish for part of a capture | position-band isolation + hero drifted; use palette-bank/HUD-exclusion/shadow-anchor (§4 rom_ref) |
| Walk anim hitches on loop despite "all" frames captured | capture never looped once — cycle is longer than it looks; dump 36+ frames and check `unique_poses.py` order repeats |
| `--import` crawls through hundreds of capture PNGs | keep a `.gdignore` in `tools/rom_ref/out/` (committed via gitignore exception) |
| KH CoM dialog won't advance on A | scripted prompts can require **SELECT** (found on the "Changing Categories" tutorial; technique in `kh_sraid_explore1-9.lua`) |
| KH CoM level-55 save frozen on the 13F Naminé textbox | hard freeze, NOT an input miss — A/B/Start/SELECT/movement all ignored, 10 SELECT strategies pixel-identical (`kh_13f_select1.lua`). Suspect BizHawk core sync or a bad conversion moment; try another GBA core before more input permutations |
| Boom stays active forever in campaign tests | live `shop.gd` and headless `ShopSim` must each call `BoomManager.complete_shop_session()` exactly once per completed session |
| OAM decode finds 0 objects but the ref screenshots show sprites | game uses **8bpp** objects (DBZ LoG II does) — `decode_oam.py` is 4bpp-only; see `decode_oam_dbz.py` (8bpp 1D mapping: tile numbers advance by 2 per 8x8 block, palette bank ignored) |
| Emulator button does nothing / wrong action despite user instructions | the user's keyboard binding ≠ GBA button of the same name — probe every button scripted (`dbz_button_matrix.lua` pattern) instead of trusting the letter |
| Captured "up-facing" action actually faces the old direction | releasing a held direction before the action tap loses the turn (DBZ melee-up bug) — hold the direction THROUGH the action input (`capture_piccolo_extra2.lua`), then verify facing on the ref screenshots |

## 9. Checklist: adding or fixing a world

1. Inventory `assets/franchises/<world>/raw/` (heroes, enemies, bosses,
   customers, items, locations). Contact-sheet everything first; pick indices
   from the labeled sheets.
2. Hero sheet → manifest with all 12 core anims (idle/walk × 3 dirs, attack_1
   & attack_2 × 3 dirs). Composite weapon overlays if the body frames lack
   them.
3. Enemies: ~12 to match other worlds. Drop unusable rips honestly (a
   propeller-only peahat was cut and the user was told) rather than shipping
   junk.
4. Bosses: multi-frame (idle + walk minimum) from the rip's animation rows;
   2× upscale small rips to boss presence (~90–120px).
5. Rooms: 640×384 map crops into `assets/locations/<world>dungeon/processed/`,
   wired via `room_backgrounds`; obstacle props cut per §7; watch for white
   map-void edges in crops.
6. Items: wiki-accurate names/prices/descs, icons ≤ 22px into
   `processed/items/`.
7. Customers: statics into the pool (indent=2!).
8. Music: drop `dungeon_<world>.mp3` in `user_overrides` — resolves itself.
9. Probe: logic (rotation, manifests, anims present, special behavior) +
   windowed screenshots of lineup, start room, a combat room, and the boss
   room. Look at all of them.
10. `--import` → export → commit. Add rows to `credits/ASSET_CREDITS.csv` for
    any new fan-ripped sheets.

## 10. Working style (what the user has reinforced)

- **See it before you ship it.** When feedback is visual, reproduce it
  visually, fix, then verify with fresh screenshots. "Do a visual test
  yourself" is the standing expectation.
- **Report honestly.** Dropped content, failed rips, and compromises get
  told to the user plainly, with the reason.
- **Small clean diffs.** Match file conventions (indents, naming); don't
  reformat neighbors.
- Commit at the end of each verified pass; message = what the player will
  notice, body = why. Keep any project-required trailers your harness
  specifies.
- Throwaway probes stay in `tests/` and get committed — they are cheap and
  the next agent reuses the pattern.
- If you learn a new pitfall the hard way, **add it to this guide** — that is
  how it stays alive across models and sessions.

## 11. Real-game animation reference (emulator capture)

When you need to know what an animation *actually* looks like (frame count,
order, timing, weapon offsets) instead of guessing from a static rip, drive the
real game in **BizHawk** and capture ground-truth frames. Full workflow:
`docs/SPRITE_REFERENCE_PIPELINE.md`. Tooling: `tools/rom_ref/` (Lua capture +
`decode_oam.py`). ROMs/saves/emulator/output are gitignored (`savestates/`,
`roms/`, `tools/rom_ref/out/`) — never commit them.

Non-obvious facts that cost time during bring-up:

- Provided saves are **battery saves in export containers**, not savestates.
  SharkPort `.sps` (GBA/SNES), ARDS `.duc` (DS). **BizHawk names SaveRAM by its
  gamedb canonical name, not the ROM filename** — boot once to see the name/size
  it wants.
- **EEPROM 8 KB saves** (Minish Cap, Mario & Luigi): convert SharkPort by
  **reversing each 8-byte block**, pad `0xFF` to 128 KB, append 16-byte `0xFF`
  footer. **Flash 64 KB saves** (KH:CoM, DBZ, FF6 Advance) are NOT 8-byte-swapped
  — use a different transform; verify per game.
- Lua input: `joypad.set({Start=true})` with **no port arg** (a port silently
  does nothing), **held ~30 frames**, and **wait ~900 frames past the boot logos**
  before any input. `client.screenshot(path)`, `client.exit()`; guard the launch
  with a `timeout`.
- Quality frames come from the **OAM sprite-dump** (raw OAM + OBJ VRAM + OBJ
  palette per frame, reconstructed in Python) — isolated hero on transparency, no
  chroma-key. The hero-isolation X-band is **per-game**; retune it from the
  `obj_all_*.png` full-layer render. `decode_oam.py` handles 4bpp/1D only so far.
- An emulator capture can also map **dungeon layouts and barriers** 1:1 later
  (walk the hero into every edge, record where movement stops) — a planned second
  use of this same harness.

# DBZ dungeon — session handoff

Building the Dragon Ball Z: Legacy of Goku II dungeon with playable **Goku**
and **Piccolo**.

## Session 3 (home PC, 2026-07-21, post power outage): Piccolo SHIPPED

- **Piccolo hero is live**: `tools/build_piccolo_from_oam.py` (re-renders from
  raw OAM bins — strips beam tiles 832/840/848, HUD, and stray overworld
  objects via bbox-distance from the hero object) → 8x6 sheet + manifest with
  16 anims (idles+blink, 4-dir walks, melee incl. recaptured up swing,
  SBC charge/fire in 3 facings, fly flips). Verified windowed
  (`tests/piccolo_moves_shot.tscn`) + headless (`tests/piccolo_logic_probe.tscn`).
- **New engine kinds** in `combat_hero.gd`: special `"beam"` (spawns
  `scripts/entities/beam.gd` — muzzle/shaft/tip textures from the special def,
  grow/hold/fade, line damage) and dodge `"fly"` (plays `fly_*` anims).
  Piccolo added to `data/heroes.json` (SBC beam, fly dodge, hire 1000).
- **Capture facts**: melee-up needed a recapture with the direction held
  THROUGH the B-tap (`mbu2`; original `mbu` never turned — pitfall added to
  AGENT_GUIDE §8). The double-tap combo has NO distinct second-hit sprite
  (mcd == mbd); attack_2_down reuses the mbd crackle inverted. Firing pose =
  frames _25+/_31 (two-handed thrust), NOT _24 (still coiled). mad/mar
  (A-tap) are 4-pose acrobatic flips — used as the fly-dodge anim (walking
  scale); overworld f* flight sprites unused for now.

### Next actions
1. Goku: debug-menu MAP TEST to a pre-Cell map with Goku, redo the Piccolo
   capture recipe (Kamehameha instead of SBC; reuse `build_piccolo_from_oam.py`
   pattern + the beam kind with new kame_* part sprites).
2. Build the dungeon (rooms/enemies/boss/barriers/music), probes + windowed
   screenshots, export, commit.

---

## Session 2 (home PC, 2026-07-21): Piccolo captured, debug menu unlocked

- **Debug menu works** (`tools/rom_ref/dbz_testmenu.lua`): poke `0x02` to
  `0x0202B32D` every frame from boot, hold Start at title → DEBUG menu with
  MAP TEST (zone/area warps) and all 6 characters. This is the route to Goku
  (he's pre-Cell-Games only; the user's save can't reach him).
- **Game mechanics (learned the hard way):** L cycles the selected ki attack
  (icon top-right HUD), B fires/holds it, A charges ki. The user's keyboard "B"
  is NOT GBA B in their profile — scripted `joypad.set` tests must probe.
  Wrong selected attack = red power-up state, not the beam.
- **User savestates** (BizHawk quicksave slots, gitignored):
  slot 1 = Piccolo, open area, SBC preselected (hold B fires);
  slot 7 = mid-beam; slot 8 = character-switch screen; slot 9 = overworld
  (flying); slot 0 = Northern Wastelands spawn.
- **Full Piccolo OAM capture done** (`capture_piccolo_moves.lua` → 856 frames
  in `tools/rom_ref/out/oam_dbz/`, gitignored — recapture by rerunning):
  4-dir walks (60f), 4-dir idles, 150-frame dense idle, 4-dir SBC, melee
  combo (B-tap), overworld flight (4-dir + hover).
- **DBZ LoG II uses 8bpp OAM objects** — `decode_oam.py` (4bpp-only) sees
  nothing; use `decode_oam_dbz.py` (8bpp, 1D mapping advances tile numbers by
  2 per 8x8 block). Scene is sparse: hero = tile-896 object near screen
  center; HUD = 3 static bars. SBC decomposes into muzzle (tile 832) +
  stretching shaft (840) + traveling tip (848) — ideal for a reusable beam
  special. Decoded contact sheets: `out/oam_dbz/decoded/contact_*.png`.

### Next actions
1. Pick poses (`unique_poses.py` pattern) → `tools/build_piccolo_from_oam.py`
   → sheet + manifest; wire Piccolo hero + `fly` dodge + beam special kind.
2. Goku: debug-menu MAP TEST to a pre-Cell map with Goku, redo the same
   capture (Kamehameha instead of SBC).
3. Build the dungeon (rooms/enemies/boss/barriers/music), probes + windowed
   screenshots, export, commit.

---

## Session 1 (work PC): emulator bring-up — original handoff below

## Hero spec (agreed)
- **Goku** (hero already in `data/heroes.json`): special = **Kamehameha** (beam),
  dodge = **fly**.
- **Piccolo** (NEW hero — add him): special = **Special Beam Cannon** (beam),
  dodge = **fly**.
- Add a **`fly` dodge kind** (dash + i-frames + flight pose) and a beam special
  kind in `scripts/entities/combat_hero.gd` (existing kinds: dash/projectile/
  clones/bomb; dodges: roll/guard/vanish).

## DONE this session
- DBZ world already scaffolded in `worlds.json` (`dragon_ball`, shard
  `world_shard_dbz`). Goku hero exists; Piccolo does not yet.
- Emulator works: BizHawk 2.11.1 boots the ROM; your completed GameShark save
  loads into gameplay. Files: **Slot 1 = "Capsule Corporation"**,
  **Slot 2 = "East District 439"** (both full party / unlocked).
- **Save conversion is scripted + verified:** `tools/rom_ref/gsv_convert.py`.
  GameShark `.gsv` uses the SAME 8-byte EEPROM block-reversal as SharkPort,
  then pad to 131088. Native order boots to empty "NEW GAME" slots; unreversed
  boots to the real files (confirmed by screenshot).
- Boot-check Lua: `tools/rom_ref/dbz_bootcheck.lua` (title -> select -> in-game).

## To restore the save on the home PC
The SaveRAM is gitignored, so regenerate it from the `.gsv` (get the file onto
home first — it's `dragon-ball-z-the-legacy-of-goku-ii.22863.gsv`, from the
user's Downloads):
```
.venv312/Scripts/python.exe tools/rom_ref/gsv_convert.py <path-to>.gsv \
  --out "<BizHawk>/GBA/SaveRAM/Dragon Ball Z - The Legacy of Goku II (USA).SaveRAM"
```
ROM SHA1 (USA) = 18e0715dec419f3501c301511530d2edcd590f8b. gamedb canonical
name = "Dragon Ball Z - The Legacy of Goku II (USA)". `DBZ_finalboss.sps` /
FF6 `.sps` are gzipped full **savestates** (not battery saves) — don't feed
those to the converters.

## PENDING — next action (need the user's LoG II knowledge, then capture)
Before capturing, get quick answers (saves blind menu-poking):
1. Which slot to use (Capsule Corp vs East District 439) — whichever has BOTH
   Goku and Piccolo usable near an open area with weak enemies.
2. How to switch active character to Goku, then Piccolo (menu/buttons).
3. How to fire Kamehameha (Goku) and Special Beam Cannon (Piccolo).
4. How to trigger flying (the dodge animation).

Then, per task list:
- Set up cheats (infinite Ki, walk-through-walls) before the specials capture.
- Capture Goku (idle/4-dir walk/fly/melee/Kamehameha) via the `sprite-capture`
  subagent + OAM pipeline; retune BODY_PAL/SHADOW for this game. Then Piccolo.
- Build sheets/manifests (model on `tools/build_sora_from_oam.py`), wire heroes
  + fly dodge, build out the dungeon (rooms/enemies/boss/barriers/music),
  verify with probes + windowed screenshots, then export on home + commit.

Workflow agreed: cheats ON; I drive via Lua and try ~2-3x, escalate to the user
to drive live when stuck, fall back to user-made BizHawk savestates.

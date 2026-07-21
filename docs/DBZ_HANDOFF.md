# DBZ dungeon — session handoff (resume on the home PC)

Building the Dragon Ball Z: Legacy of Goku II dungeon with playable **Goku**
and **Piccolo**. Left off mid-emulator-bring-up; pick up at "Pending" below.

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

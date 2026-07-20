# Real-Game Sprite/Animation Reference Pipeline

Hero (and enemy/boss) animation has been the recurring struggle in this project:
sprites read as **stiff/static** (1-frame idles), **jerky/wrong** (guessed frame
order), or with **invisible weapons/effects**. The root cause is *frame
identification* — knowing which frames of a ripped sheet form each animation and
in what order — not source-art quality.

This pipeline removes the guessing by driving the **real game** in an emulator
and capturing ground-truth animation frames, isolated on transparency, that we
match our ripped sheets against (or use directly). An AI agent can run the whole
loop autonomously from a command line; a human only supplies a ROM and a battery
save.

Everything here is **local-only tooling for a private, noncommercial project**.
ROMs, battery saves, the emulator, and all capture output live under gitignored
paths (`savestates/`, `roms/`, `tools/rom_ref/out/`) and must never be committed.
Only the scripts in `tools/rom_ref/` are versioned.

## What you need

- **BizHawk (EmuHawk)** — one emulator that covers GBA (mGBA core), SNES, and
  DS (melonDS core), all under one Lua API. Path used during bring-up:
  `savestates/BizHawk-2.11.1-win-x64/EmuHawk.exe`.
- **The ROM** for the game whose sprites we're referencing.
- **A battery save** parked ideally in **calm free-roam with room to walk** (not
  mid-cutscene or in a boss fight — that just costs navigation inputs).
- **`.venv312`** with Pillow + numpy (`decode_oam.py` needs them).

## The loop

```
convert save -> place as BizHawk SaveRAM -> launch ROM with a capture Lua ->
autonomously navigate to gameplay -> dump frames (screenshots OR OAM) ->
reconstruct/cut in Python -> feed the manifest
```

## 1. Convert and place the battery save

Provided saves are **battery saves in export containers**, not emulator
savestates:

- `.sps` = SharkPort (GBA/SNES). Structure: `u32 len=13` + `"SharkPortSave"` +
  `u32 platform` + three length-prefixed strings + `u32 datalen` + `0x1C`
  internal header + the raw SRAM.
- `.duc` = Action Replay DS (`ARDS...` header) — DS battery saves.

**BizHawk names SaveRAM by its gamedb canonical name, not the ROM filename.**
E.g. the `(U)` Minish Cap ROM wants
`GBA/SaveRAM/Legend of Zelda, The - The Minish Cap (USA).SaveRAM`. Boot the ROM
once and let BizHawk create the file to learn the exact name and expected size.

**EEPROM games (8 KB save, e.g. Minish Cap, Mario & Luigi):** the SharkPort SRAM
is stored with a different byte order than mGBA. Convert with: **reverse each
8-byte block**, pad with `0xFF` to 128 KB, append a 16-byte `0xFF` footer
(final size 131088). Verify by booting to the file-select screen — the saved
file should appear.

**Flash games (64 KB save, e.g. KH: Chain of Memories, DBZ: Legacy of Goku II,
FF6 Advance):** flash is *not* 8-byte-swapped like EEPROM — expect a simpler
transform (raw + pad). Verify per game; do not assume the EEPROM recipe.

**DS (`.duc`):** use the melonDS core and the ARDS unwrap; not yet exercised.

## 2. Launch + autonomous navigation (Lua)

Launch from a shell (foreground with a timeout guard; the script self-exits):

```
tools\...\EmuHawk.exe "<rom>" --lua="<abs path to capture .lua>"
```

Lua facts learned the hard way:

- **Wait ~900 frames before the first input** — presses during the boot logos
  are ignored.
- **`joypad.set({Start=true})` with NO port argument.** Passing a port silently
  did nothing. **Hold a button ~30 frames**; short taps don't register.
- `client.screenshot(path)` writes a PNG; loop `emu.frameadvance()` + screenshot
  to capture consecutive animation frames. `client.exit()` ends the run.
- If a save is parked mid-cutscene, mash `A` (hold 4 / wait ~18, repeated) to
  clear dialogue, then screenshot to confirm free-roam before capturing.

## 3a. Quick capture (screenshots)

`capture_link.lua` / `capture_link2.lua` dump full-screen PNGs per frame. Good
for a first look, but frames include the scrolling background and the hero is
small — fine for reading a cycle, not for cutting a manifest.

## 3b. Quality capture (OAM sprite-dump) — preferred

This produces **isolated frames on full transparency, no chroma-keying**.

`tools/rom_ref/oam_dump.lua` navigates to free-roam, then per frame dumps raw
memory to `.bin`:

- OAM: `memory.readbyterange(0, 1024, "OAM")`
- OBJ tiles: VRAM offset `0x10000`, length `0x8000`
- OBJ palette: PALRAM offset `0x200`, length `0x200`
- `DISPCNT` (System Bus `0x04000000`): bit 6 set = **1D tile mapping**.

`tools/rom_ref/decode_oam.py` (uses `.venv312`) reconstructs the GBA object layer
(4bpp, 1D mapping): BGR555 palette, 32-byte tiles, palette index 0 = transparent,
shape/size → (w,h), hflip/vflip. It renders the **full object layer**
(`obj_all_*.png`, includes HUD + hero) and an **isolated hero** crop, plus a
contact sheet.

**Hero isolation is per-game.** Objects are filtered by `w>=16` (drops 8x8 HUD
hearts/icons) within a central X-band. For Minish Cap Link: `cx in [92,140]`,
`cy<=140` → clean 16-18 x 24-26px frames. Retune the band for each game by first
viewing `obj_all_*.png` to see where the hero sits and what the HUD occupies.

**Note:** the hero's OBJ set may include a shadow object; our `CharacterVisual`
draws its own shadow, so filter it (a separate flat/wide OBJ below the feet)
before building a manifest.

## 4. Into the manifest

Cut the isolated frames into the standard animation set (idle/walk x dir,
attack_* x dir; see `docs/ASSET_FACTORY.md` and `docs/AGENT_GUIDE.md` §5), set the
feet pivot, and write `assets/franchises/<world>/manifests/<hero>.json`. The
reference frames give correct frame count, order, and timing so the result is not
guessed.

## Per-game status

| Game (hero) | Platform | Save type | Pipeline proven |
|---|---|---|---|
| Zelda: Minish Cap (Link) | GBA | EEPROM 8 KB | **Yes** — walk-down cycle isolated; full move set + manifest pending |
| Mario & Luigi: Superstar Saga (Mario/Luigi) | GBA | EEPROM 8 KB | ROM+save present; not yet run |
| KH: Chain of Memories (Sora) | GBA | Flash 64 KB | ROM+save present; flash conversion unverified |
| DBZ: Legacy of Goku II (Goku) | GBA | Flash 64 KB | ROM+save present; flash conversion unverified |
| Final Fantasy VI Advance (Cloud) | GBA | Flash 64 KB | save present; ROM not confirmed |
| Naruto: Path of the Ninja 2 | DS | ARDS | save present; melonDS path not built |
| Pokémon HeartGold/SoulSilver (Pikachu) | DS | ARDS | save present; melonDS path not built |

## Gotchas

- Every capture run boots from the logos, so budget ~900 frames + any
  cutscene-clearing before the hero is controllable.
- 8bpp objects and affine/rotated sprites aren't handled by `decode_oam.py` yet
  (Link is 4bpp non-affine). Add those paths if a hero needs them.
- The `X`/`Y` wrap conventions in OAM (9-bit X, 8-bit Y) are handled for on-screen
  heroes; revisit if a sprite is captured near a screen edge.
- Screenshots must be windowed if you use the quick path — headless returns null
  textures (same rule as `docs/AGENT_GUIDE.md` §2). The OAM path reads memory, so
  it does not depend on the renderer.

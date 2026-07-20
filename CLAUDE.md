# Crossroads — instructions for AI agents

**Read `docs/AGENT_GUIDE.md` before making any change.** It is the
operational manual for this repo (build/verify/export loop, probe patterns,
sprite-extraction recipes, data conventions, and a pitfall table), written by
a previous agent from hard-won experience. This file is only the summary of
the absolute musts.

Non-negotiables:

1. The user only ever plays `export\crossroads.exe` (on a controller). Every
   task ends with:
   `tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" "export/crossroads.exe"`
   — then commit. No export = nothing shipped.
2. After adding/changing any asset, run
   `tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . --import`
   before testing, or you'll see stale art.
3. Screenshot probes must run **windowed** (no `--headless` — the headless
   renderer returns null viewport textures). Logic probes may run headless.
   Look at every screenshot you take.
4. Visual feedback gets visual verification: reproduce what the player saw,
   fix it, re-screenshot, then ship.
5. Asset extraction is scripted (`tools/*.py`, run with
   `.venv312\Scripts\python.exe`). Never hand-edit processed PNGs; never
   touch `assets/franchises/*/raw/`.
6. Match each JSON file's existing indent (`worlds/enemies/items/heroes` = 1,
   `customer_visuals` = 2) — wrong indent makes unreviewable diffs.

Architecture reference: `docs/ARCHITECTURE.md`. Data schemas:
`docs/EXPANSION.md`. Asset pipeline/editor tooling: `docs/CONTENT_PIPELINE.md`.

If you learn a new pitfall the hard way, add it to `docs/AGENT_GUIDE.md` §8.

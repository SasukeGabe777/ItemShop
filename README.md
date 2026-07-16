# sprite_resource_downloader

`sprite_resource_downloader` is a Python 3.12 command-line tool for downloading individual sprite-sheet assets from one game page on The Spriters Resource. It uses Playwright with Chromium so downloads happen through a normal browser context and the site's own download controls.

This tool is intended only for private, unpublished, legally permitted noncommercial projects. Do not mirror the website, run multiple concurrent downloaders, bypass access controls, or use downloaded assets outside the permissions that apply to your project.

## Windows Setup

Install Python 3.12 from <https://www.python.org/downloads/windows/>. During installation, enable **Add python.exe to PATH**.

Create and activate a virtual environment:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
```

Install the package dependencies and Chromium:

```powershell
pip install -r requirements.txt
playwright install chromium
```

## Usage

```powershell
python -m sprite_resource_downloader https://www.spriters-resource.com/game_boy_advance/khcom/
python -m sprite_resource_downloader https://www.spriters-resource.com/game_boy_advance/khcom/ --output assets/raw
python -m sprite_resource_downloader https://www.spriters-resource.com/game_boy_advance/khcom/ --dry-run
python -m sprite_resource_downloader https://www.spriters-resource.com/game_boy_advance/khcom/ --resume
python -m sprite_resource_downloader https://www.spriters-resource.com/game_boy_advance/khcom/ --yes
python -m sprite_resource_downloader https://www.spriters-resource.com/game_boy_advance/khcom/ --headed
python -m sprite_resource_downloader https://www.spriters-resource.com/game_boy_advance/khcom/ --headless
python -m sprite_resource_downloader https://www.spriters-resource.com/game_boy_advance/khcom/ --max-assets 20
python -m sprite_resource_downloader https://www.spriters-resource.com/game_boy_advance/khcom/ --include-section "Enemies"
python -m sprite_resource_downloader https://www.spriters-resource.com/game_boy_advance/khcom/ --exclude-section "Backgrounds"
python -m sprite_resource_downloader https://www.spriters-resource.com/game_boy_advance/khcom/ --include-asset "Sora" --include-asset "Shadow"
```

The first run defaults to a headed browser so you can observe the interaction. Use `--headless` after you have confirmed the site flow works.

## Visual UI

Start the local browser interface:

```powershell
python -m sprite_resource_downloader.webui --port 8765
```

Then open `http://127.0.0.1:8765/`. The UI supports dry-runs, downloads, resume mode, franchise targeting, section filters, asset-name filters, headed/headless Chromium, job logs, cancellation, and raw-file refresh.

## Output

By default, assets are saved directly into this project's franchise raw folders when the game can be inferred:

```text
assets/franchises/kingdom_hearts/raw/
assets/franchises/mario/raw/
assets/franchises/final_fantasy/raw/
assets/franchises/zelda/raw/
assets/franchises/naruto/raw/
assets/franchises/dragon_ball/raw/
assets/franchises/pokemon/raw/
```

Use `--franchise` when inference is ambiguous, or `--output` to stage files somewhere else. Filenames are lowercase snake_case and include the project prefix, for example `kh_sora_gba.png` or `mario_goomba.png`. The manifest `asset_id` matches the filename stem.

Downloader metadata is stored outside `raw/`, under:

```text
credits/sprite_resource_downloader/<franchise>/
```

That metadata folder contains:

```text
ASSET_MANIFEST.json
ASSET_CREDITS.csv
download.log
failed_downloads.json
.download_state.json
```

`ASSET_CREDITS.csv` records the game, platform, section, asset name, asset ID, source page, uploader, contributors, submitted date, format, size, local path, and download timestamp. Contributor and source information is kept even when separate ripper credit is not legally required.

Each successful download also upserts a row in `credits/ASSET_CREDITS.csv` using the project schema:

```text
asset_id,character_id,source_game,source_site,source_page,contributor,permission_notes,file
```

## Resume Behavior

The state file in `credits/sprite_resource_downloader/<franchise>/` tracks completed and failed asset IDs. On a later run with `--resume`, completed assets are skipped and only unfinished assets are attempted. The tool also skips completed assets if it finds an existing state file during a normal run.

## Responsible Use

The downloader uses one Chromium page and one active download at a time. It waits between requests, backs off on transient server errors, and stops on CAPTCHA, Cloudflare, login, access-denied, or rate-limit pages. It never attempts to bypass these protections.

Keep assets limited to private or otherwise legally permitted noncommercial use. Do not mirror the entire website, download unrelated games, or run multiple copies of the downloader at the same time.

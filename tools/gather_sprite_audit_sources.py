"""Build a human-review pack for every entry in SPRITE_REVIEW.md.

The pack is intentionally written outside the Godot project by default so
large raw sheets never enter the import/export scan. It contains:

* each unique original source sheet that can be traced from the extraction
  scripts and manifests;
* the current processed asset/sheet for side-by-side comparison;
* CSV and Markdown indexes mapping all audit IDs back to those files;
* contact-sheet catalogs and a blank feedback template.

Run:
    .venv312/Scripts/python tools/gather_sprite_audit_sources.py
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT.parent / "sprite-exportaudit-sheets-2026-07-30"
AUDIT_PATH = ROOT / "SPRITE_REVIEW.md"
FRANCHISES = ROOT / "assets/franchises"


@dataclass(frozen=True)
class AuditEntry:
    section: str
    label: str
    asset_id: str
    current_ref: str
    world: str


@dataclass(frozen=True)
class SourceChoice:
    relative_path: str
    confidence: str = "exact"
    note: str = ""


DIRECT_SOURCES: dict[str, list[SourceChoice]] = {
    # Items.
    "zelda_boomerang": [
        SourceChoice("zelda/raw/items/items.png"),
    ],
    "cane_of_pacci": [
        SourceChoice("zelda/raw/items/items.png"),
    ],
    "forehead_protector": [
        SourceChoice("naruto/raw/items.png"),
    ],
    # Customers whose output name does not map directly to a raw filename.
    "field_guard": [
        SourceChoice("zelda/raw/customers/sprite_royal_guards.png"),
    ],
    "dragonair": [
        SourceChoice(
            "pokemon/raw/customers_updated/"
            "sprite_pok_mon_1st_generation_overworld.png"
        ),
    ],
    "bulma": [
        SourceChoice("dragon_ball/raw/customers/sprite_bulma_s_familly.png"),
    ],
    "jus_yugi": [
        SourceChoice("anime/raw/Yugi.png"),
    ],
    # Enemies and bosses with scripted, direct provenance.
    "cell_junior": [
        SourceChoice("dragon_ball/raw/enemies/sprite_cell_jr.png"),
    ],
    "crescendo": [
        SourceChoice("kingdom_hearts/raw/enemies/sprite_crescendo.png"),
    ],
    "darknut": [
        SourceChoice("zelda/raw/enemies/sprite_darknut.png"),
    ],
    "ghini": [
        SourceChoice("zelda/raw/enemies/sprite_ghini.png"),
    ],
    "pirate_kh": [
        SourceChoice("kingdom_hearts/raw/enemies/sprite_pirate.png"),
    ],
    "screwdiver": [
        SourceChoice("kingdom_hearts/raw/enemies/sprite_screwdiver.png"),
    ],
    "sea_neon": [
        SourceChoice("kingdom_hearts/raw/enemies/sprite_sea_neon.png"),
    ],
    "big_green_chuchu": [
        SourceChoice("zelda/raw/enemies/boss_1.png"),
    ],
    "big_blue_chuchu": [
        SourceChoice("zelda/raw/enemies/boss_2.png"),
    ],
    "vaati": [
        SourceChoice("zelda/raw/enemies/boss_3.png"),
    ],
    "darkside": [
        SourceChoice("kingdom_hearts/raw/enemies/sprite_darkside.png"),
    ],
    "guard_armor": [
        SourceChoice("kingdom_hearts/raw/enemies/sprite_guard_armor.png"),
    ],
    # These legacy audit paths no longer exist. The compilation sheet is the
    # only preserved raw source used by the original static-enemy pass.
    "bomb_ff": [
        SourceChoice(
            "final_fantasy/raw/enemies/sprite_enemies.png",
            "source collection",
            "The audited processed file is missing; locate Bomb on this sheet.",
        ),
    ],
    "cactuar": [
        SourceChoice(
            "final_fantasy/raw/enemies/sprite_enemies.png",
            "source collection",
            "The audited processed file is missing; locate Cactuar on this sheet.",
        ),
    ],
    "sahagin": [
        SourceChoice(
            "final_fantasy/raw/enemies/sprite_enemies.png",
            "source collection",
            "The audited processed file is missing; locate Sahagin on this sheet.",
        ),
    ],
    # There is no King Bob-omb sheet in the repository. Preserve the closest
    # supplied Bob-omb animation as a clearly labeled candidate, not a claim
    # that it is the correct boss.
    "king_bobomb": [
        SourceChoice(
            "mario/raw/enemies/mario_bob_omb.png",
            "candidate only",
            "No King Bob-omb source exists in the repository; this is regular Bob-omb.",
        ),
    ],
    # No Shy Guy source exists under raw/. Leaving this list empty makes that
    # absence explicit in the generated index.
    "shy_guy": [],
    # Null Archive concepts were never backed by reproducible extraction
    # scripts and their audited outputs are now missing. Include the likely
    # component sheets without pretending they are exact provenance.
    "fade_goomba": [
        SourceChoice(
            "mario/raw/enemies/mario_goomba.png",
            "concept candidate",
            "Likely Goomba component; no Null Archive build script is present.",
        ),
        SourceChoice(
            "kingdom_hearts/raw/enemies/sprite_shadow.png",
            "concept candidate",
            "Likely Heartless component; no Null Archive build script is present.",
        ),
    ],
    "fade_bomb_tag": [
        SourceChoice(
            "final_fantasy/raw/enemies/sprite_enemies.png",
            "concept candidate",
            "Likely Bomb component; no Null Archive build script is present.",
        ),
        SourceChoice(
            "naruto/raw/items.png",
            "concept candidate",
            "Likely explosive-tag component; no Null Archive build script is present.",
        ),
    ],
    "fade_saibadeku": [
        SourceChoice(
            "zelda/raw/customers/sprite_deku_scrub.png",
            "concept candidate",
            "Deku component only; no Saibaman source or build script exists.",
        ),
    ],
    "fade_tonberry_ball": [
        SourceChoice(
            "final_fantasy/raw/ff_master_tonberry.png",
            "concept candidate",
            "Likely Tonberry component; no Null Archive build script is present.",
        ),
        SourceChoice(
            "pokemon/raw/items.png",
            "concept candidate",
            "Likely Poké Ball component; no Null Archive build script is present.",
        ),
    ],
    "fade_gastly_boo": [
        SourceChoice(
            "pokemon/raw/customers_enemies_bosses/"
            "sprite_gastly_haunter_gengar.png",
            "concept candidate",
            "Likely Gastly component; no Null Archive build script is present.",
        ),
        SourceChoice(
            "mario/raw/enemies/mario_boo.png",
            "concept candidate",
            "Likely Boo component; no Null Archive build script is present.",
        ),
    ],
}


def parse_audit() -> list[AuditEntry]:
    entries: list[AuditEntry] = []
    section = ""
    line_pattern = re.compile(
        r"^- \[[ xX]\] (.*?) \(`([^`]+)`\).*?`res://([^`]+)`\s*$"
    )
    for line in AUDIT_PATH.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            section = line[3:].strip()
            continue
        match = line_pattern.match(line)
        if not match:
            continue
        label, asset_id, current_ref = match.groups()
        parts = Path(current_ref).parts
        world = parts[2] if len(parts) > 2 and parts[:2] == ("assets", "franchises") else ""
        entries.append(AuditEntry(section, label, asset_id, current_ref, world))
    if len(entries) != 95:
        raise SystemExit(f"Expected 95 audit entries, parsed {len(entries)}")
    return entries


def first_existing(*paths: Path) -> Path | None:
    return next((path for path in paths if path.exists()), None)


def source_choices(entry: AuditEntry) -> list[SourceChoice]:
    if entry.asset_id in DIRECT_SOURCES:
        return DIRECT_SOURCES[entry.asset_id]

    if entry.asset_id.startswith("dragon_ball_traveler_"):
        raw_dir = FRANCHISES / "dragon_ball/raw/customers"
        return [
            SourceChoice(
                path.relative_to(FRANCHISES).as_posix(),
                "generated pool",
                "Traveler IDs were generated from the full Dragon Ball customer pool; "
                "the old script did not persist an individual source-frame mapping.",
            )
            for path in sorted(raw_dir.glob("*.png"))
        ]

    if entry.section == "Characters":
        candidates: list[Path] = []
        if entry.world == "final_fantasy":
            candidates = [FRANCHISES / f"final_fantasy/raw/ff_{entry.asset_id}.png"]
        elif entry.world == "kingdom_hearts":
            candidates = [
                FRANCHISES
                / f"kingdom_hearts/raw/customers/kh_{entry.asset_id}_gba.png"
            ]
        elif entry.world == "mario":
            base = FRANCHISES / f"mario/raw/customers/mario_{entry.asset_id}"
            candidates = [base.with_suffix(".png"), base.with_suffix(".gif")]
        elif entry.world == "dragon_ball":
            candidates = [
                FRANCHISES
                / f"dragon_ball/raw/customers/sprite_{entry.asset_id}.png"
            ]
        path = first_existing(*candidates)
        if path:
            return [SourceChoice(path.relative_to(FRANCHISES).as_posix())]
    return []


def resolve_current(entry: AuditEntry) -> Path | None:
    path = ROOT / entry.current_ref
    if not path.exists():
        return None
    if path.suffix.lower() != ".json":
        return path
    data = json.loads(path.read_text(encoding="utf-8"))
    sheet = str(data.get("sheet", "")).removeprefix("res://")
    resolved = ROOT / sheet
    return resolved if resolved.exists() else None


def safe_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        shutil.copy2(source, destination)


def load_preview(path: Path) -> Image.Image:
    with Image.open(path) as opened:
        opened.seek(0)
        return opened.convert("RGBA")


def checker(size: tuple[int, int], tile: int = 12) -> Image.Image:
    image = Image.new("RGBA", size, (238, 238, 238, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            if (x // tile + y // tile) % 2:
                draw.rectangle(
                    (x, y, min(size[0] - 1, x + tile - 1), min(size[1] - 1, y + tile - 1)),
                    fill=(205, 205, 205, 255),
                )
    return image


def fit_preview(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    image.thumbnail(size, Image.Resampling.NEAREST)
    canvas = checker(size)
    canvas.alpha_composite(
        image,
        ((size[0] - image.width) // 2, (size[1] - image.height) // 2),
    )
    return canvas.convert("RGB")


def write_catalog(
    rows: list[tuple[str, Path]],
    output_dir: Path,
    prefix: str,
    page_size: int = 20,
) -> None:
    font = ImageFont.load_default()
    cell_w, cell_h = 300, 230
    preview_size = (280, 180)
    for page_index in range(0, len(rows), page_size):
        page_rows = rows[page_index : page_index + page_size]
        columns = 4
        row_count = (len(page_rows) + columns - 1) // columns
        page = Image.new("RGB", (cell_w * columns, cell_h * row_count), "white")
        draw = ImageDraw.Draw(page)
        for index, (label, path) in enumerate(page_rows):
            x = (index % columns) * cell_w
            y = (index // columns) * cell_h
            try:
                preview = fit_preview(load_preview(path), preview_size)
                page.paste(preview, (x + 10, y + 8))
            except Exception as exc:  # review pack should still finish
                draw.text((x + 10, y + 30), f"PREVIEW ERROR: {exc}", fill="red", font=font)
            draw.text((x + 10, y + 194), label[:46], fill="black", font=font)
            draw.text((x + 10, y + 207), path.name[:46], fill=(70, 70, 70), font=font)
        output_dir.mkdir(parents=True, exist_ok=True)
        page.save(output_dir / f"{prefix}_{page_index // page_size + 1:02d}.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise SystemExit(
            f"Refusing to overwrite existing review folder: {output}\n"
            "Choose a new --output path."
        )
    output.mkdir(parents=True)

    entries = parse_audit()
    source_root = output / "source_sheets"
    current_root = output / "current_audit_assets"
    rows: list[dict[str, str]] = []
    unique_sources: dict[str, Path] = {}
    current_catalog: list[tuple[str, Path]] = []

    for entry in entries:
        choices = source_choices(entry)
        source_cells: list[str] = []
        confidence_cells: list[str] = []
        note_cells: list[str] = []
        for choice in choices:
            source = FRANCHISES / choice.relative_path
            if not source.exists():
                note_cells.append(f"MISSING expected source: {choice.relative_path}")
                continue
            destination = source_root / choice.relative_path
            safe_copy(source, destination)
            relative_output = destination.relative_to(output).as_posix()
            source_cells.append(relative_output)
            confidence_cells.append(choice.confidence)
            if choice.note:
                note_cells.append(choice.note)
            unique_sources.setdefault(relative_output, destination)

        current = resolve_current(entry)
        current_cell = ""
        current_state = "missing"
        if current:
            suffix = current.suffix.lower()
            destination = (
                current_root
                / entry.world
                / f"{entry.asset_id}__current{suffix}"
            )
            safe_copy(current, destination)
            current_cell = destination.relative_to(output).as_posix()
            current_state = "present"
            current_catalog.append((f"{entry.asset_id} — {entry.label}", destination))

        if not source_cells:
            note_cells.append("No direct original source sheet is present in the repository.")
            confidence_cells.append("missing source")

        rows.append(
            {
                "section": entry.section,
                "id": entry.asset_id,
                "name": entry.label,
                "world": entry.world,
                "current_state": current_state,
                "current_asset": current_cell,
                "source_confidence": " | ".join(dict.fromkeys(confidence_cells)),
                "source_sheets": " | ".join(source_cells),
                "provenance_notes": " | ".join(dict.fromkeys(note_cells)),
                "issue_type": "",
                "preferred_source_file": "",
                "preferred_pose_or_frame": "",
                "correction_notes": "",
            }
        )

    fieldnames = list(rows[0])
    with (output / "review_index.csv").open(
        "w", encoding="utf-8-sig", newline=""
    ) as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    with (output / "review_index.md").open(
        "w", encoding="utf-8", newline="\n"
    ) as handle:
        handle.write("# Sprite export-audit source index\n\n")
        handle.write(
            f"- Audit entries: {len(rows)}\n"
            f"- Unique source sheets: {len(unique_sources)}\n"
            f"- Current assets present: {sum(r['current_state'] == 'present' for r in rows)}\n"
            f"- Current audit paths missing: {sum(r['current_state'] == 'missing' for r in rows)}\n\n"
        )
        for row in rows:
            handle.write(f"## {row['name']} (`{row['id']}`)\n\n")
            handle.write(f"- World: {row['world']}\n")
            handle.write(
                f"- Current: {row['current_asset'] or '**missing from repository**'}\n"
            )
            handle.write(
                f"- Source confidence: {row['source_confidence']}\n"
            )
            handle.write(
                f"- Source sheets: {row['source_sheets'] or '**no direct source present**'}\n"
            )
            if row["provenance_notes"]:
                handle.write(f"- Notes: {row['provenance_notes']}\n")
            handle.write("\n")

    shutil.copy2(AUDIT_PATH, output / "original_sprite_review.md")

    readme = """# Crossroads sprite correction review pack

This folder maps every one of the 95 checked entries in `SPRITE_REVIEW.md`
to its current processed art and the original raw source sheets available in
the repository.

## Best way to return corrections

Open `review_index.csv` and fill only these four blank columns:

1. `issue_type` — use one or more of: wrong identity, wrong variant, wrong
   pose, wrong facing, bad crop/background, bad scale, broken animation,
   missing art.
2. `preferred_source_file` — paste the filename from `source_sheets`. For
   multi-character sheets, this is the most important field.
3. `preferred_pose_or_frame` — describe the row/frame, or attach an annotated
   screenshot with the correct sprite circled.
4. `correction_notes` — what the sprite should look like in the shop/dungeon.

The strongest feedback is an annotated copy of the source sheet with the
correct identity/pose boxed and the audit ID written beside it. Pixel-perfect
crop coordinates are welcome but not required.

Entries marked `candidate only`, `concept candidate`, or `missing source`
need a replacement source sheet from you if none of the candidates are right.
Please include the original file and its source/credit link when possible.

`source_catalog/` previews every unique raw sheet. `current_catalog/` previews
the currently wired art so wrong identities can be compared quickly.
"""
    (output / "README.md").write_text(readme, encoding="utf-8", newline="\n")

    source_catalog = [
        (relative, path) for relative, path in sorted(unique_sources.items())
    ]
    write_catalog(source_catalog, output / "source_catalog", "sources")
    write_catalog(current_catalog, output / "current_catalog", "current")

    summary = {
        "audit_entries": len(rows),
        "unique_source_sheets": len(unique_sources),
        "current_assets_present": sum(r["current_state"] == "present" for r in rows),
        "current_assets_missing": sum(r["current_state"] == "missing" for r in rows),
        "entries_without_direct_source": [
            row["id"] for row in rows if "missing source" in row["source_confidence"]
        ],
    }
    (output / "pack_summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"Review pack written to: {output}")


if __name__ == "__main__":
    main()

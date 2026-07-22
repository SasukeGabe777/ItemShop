"""Expand the shop customer pool from the supplied franchise sprite archive.

Final Fantasy is deliberately left at the curated set: its source is the very
large Record Keeper archive. Pokémon uses the cleaner customers_updated Gen-I
overworld sheet. Other worlds add one clean front-facing frame per available
character sheet, with conservative extra NPC variants only where the archive
contains multi-character sheets and the world remains below 50 entries.

Run: .venv312/Scripts/python tools/prep_expanded_customer_pool.py
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from prep_supplied_assets import _key_sheet, front_score
from slice_lib import clean_alpha, find_islands, largest_component, load_rgba, resize_rgba


ROOT = Path(__file__).resolve().parents[1]
FRANCHISES = ROOT / "assets" / "franchises"
POOL_PATH = ROOT / "data" / "customer_visuals.json"
CAP_HEIGHT = 40

NON_CUSTOMER_SLUGS = {
    "animals", "beanstar", "bulma_s_familly", "cork_cask", "generic_npcs",
    "goku_s_familly", "goku_s_friends_others", "kame_house_npc",
    "kami_s_lookout_npc", "oucher_glass",
}

POKEMON_GEN1 = """
Bulbasaur Ivysaur Venusaur Charmander Charmeleon Charizard Squirtle Wartortle Blastoise
Caterpie Metapod Butterfree Weedle Kakuna Beedrill Pidgey Pidgeotto Pidgeot Rattata Raticate
Spearow Fearow Ekans Arbok Pikachu Raichu Sandshrew Sandslash Nidoran-F Nidorina Nidoqueen
Nidoran-M Nidorino Nidoking Clefairy Clefable Vulpix Ninetales Jigglypuff Wigglytuff Zubat
Golbat Oddish Gloom Vileplume Paras Parasect Venonat Venomoth Diglett Dugtrio Meowth Persian
Psyduck Golduck Mankey Primeape Growlithe Arcanine Poliwag Poliwhirl Poliwrath Abra Kadabra
Alakazam Machop Machoke Machamp Bellsprout Weepinbell Victreebel Tentacool Tentacruel Geodude
Graveler Golem Ponyta Rapidash Slowpoke Slowbro Magnemite Magneton Farfetchd Doduo Dodrio Seel
Dewgong Grimer Muk Shellder Cloyster Gastly Haunter Gengar Onix Drowzee Hypno Krabby Kingler Voltorb
Electrode Exeggcute Exeggutor Cubone Marowak Hitmonlee Hitmonchan Lickitung Koffing Weezing
Rhyhorn Rhydon Chansey Tangela Kangaskhan Horsea Seadra Goldeen Seaking Staryu Starmie Mr-Mime
Scyther Jynx Electabuzz Magmar Pinsir Tauros Magikarp Gyarados Lapras Ditto Eevee Vaporeon
Jolteon Flareon Porygon Omanyte Omastar Kabuto Kabutops Aerodactyl Snorlax Articuno Zapdos
Moltres Dratini Dragonair Dragonite Mewtwo
""".split()

WORLD_SOURCES = {
    "kingdom_hearts": ("kh_", "_gba"),
    "mario": ("mario_", ""),
    "dragon_ball": ("sprite_", ""),
}

SUPPLEMENT_TARGETS = {
    "dragon_ball": 50,
    "naruto": 50,
    "zelda": 50,
}


def slugify(value: str) -> str:
    value = value.lower().replace("pok_mon", "pokemon")
    value = re.sub(r"[^a-z0-9]+", "_", value).strip("_")
    return value


def display_name(slug: str) -> str:
    special = {
        "mr_mime": "Mr. Mime",
        "nidoran_f": "Nidoran F",
        "nidoran_m": "Nidoran M",
        "farfetchd": "Farfetch'd",
        "hercule_mr_satan": "Mr. Satan",
        "tien_shinhan": "Tien",
        "mickey_mouse": "Mickey",
        "donald_duck": "Donald",
    }
    return special.get(slug, slug.replace("_", " ").title())


def fit_customer(frame: Image.Image) -> Image.Image:
    frame = clean_alpha(largest_component(frame), lo=1, hi=255)
    if frame.height > CAP_HEIGHT:
        scale = CAP_HEIGHT / frame.height
        frame = resize_rgba(frame, (max(1, round(frame.width * scale)), CAP_HEIGHT))
        frame = clean_alpha(frame, lo=96, hi=160)
    return frame


def candidate_frames(path: Path) -> list[tuple[float, int, int, Image.Image]]:
    image = _key_sheet(load_rgba(path))
    candidates: list[tuple[float, int, int, Image.Image]] = []
    for box in find_islands(image, min_area=45, merge_gap=1)[:900]:
        width, height = box[2] - box[0], box[3] - box[1]
        if not (5 <= width <= 100 and 8 <= height <= 110 and height >= width * 0.55):
            continue
        frame = clean_alpha(largest_component(image.crop(tuple(box))), lo=1, hi=255)
        # Front-facing symmetry alone strongly favors oval shadows and tiny
        # spell effects. Reward a readable character-height silhouette and
        # reject those fragments before ranking the sheet.
        score = front_score(frame) + min(height, CAP_HEIGHT)
        if height < 12 or width < 5:
            score -= 300.0
        if score > 5.0:
            candidates.append((score, box[1], box[0], frame))
    candidates.sort(key=lambda row: (-row[0], row[1], row[2]))
    return candidates


def normalized_signature(frame: Image.Image) -> np.ndarray:
    canvas = Image.new("RGBA", (32, 40), (0, 0, 0, 0))
    fitted = fit_customer(frame)
    if fitted.width > 30:
        scale = 30 / fitted.width
        fitted = resize_rgba(fitted, (30, max(1, round(fitted.height * scale))))
    canvas.alpha_composite(fitted, ((32 - fitted.width) // 2, 40 - fitted.height))
    return np.asarray(canvas.resize((16, 20), Image.Resampling.NEAREST), dtype=np.int16)


def palette_signature(frame: Image.Image) -> np.ndarray:
    array = np.asarray(frame.convert("RGBA"))
    rgb = array[..., :3][array[..., 3] > 20]
    if not len(rgb):
        return np.zeros(512, dtype=np.float32)
    quantized = (rgb // 32).astype(np.int16)
    indices = quantized[:, 0] * 64 + quantized[:, 1] * 8 + quantized[:, 2]
    histogram = np.bincount(indices, minlength=512).astype(np.float32)
    return histogram / histogram.sum()


def is_visually_new(frame: Image.Image, signatures: list[tuple[np.ndarray, np.ndarray]],
                    pixel_threshold: float = 11.0, palette_threshold: float = 0.15) -> bool:
    signature = normalized_signature(frame)
    palette = palette_signature(frame)
    for prior, prior_palette in signatures:
        # This catches the same person facing another direction, while the
        # direct pixel comparison still catches palette-swapped near-copies.
        if float(np.abs(palette - prior_palette).sum()) < palette_threshold:
            return False
        alpha_union = (signature[..., 3] > 8) | (prior[..., 3] > 8)
        if not alpha_union.any():
            continue
        delta = np.abs(signature - prior).mean(axis=2)
        if float(delta[alpha_union].mean()) < pixel_threshold:
            return False
    signatures.append((signature, palette))
    return True


def pokemon_blocks(path: Path) -> list[Image.Image]:
    image = load_rgba(path)
    x_ranges = [(0, 64)] + [(65 + i * 65, min(image.width, 129 + i * 65)) for i in range(14)]
    y_ranges = [(0, 128)] + [(129 + i * 129, min(image.height, 257 + i * 129)) for i in range(9)]
    blocks: list[Image.Image] = []
    for y0, y1 in y_ranges:
        for x0, x1 in x_ranges:
            if len(blocks) >= len(POKEMON_GEN1):
                return blocks
            blocks.append(image.crop((x0, y0, x1, y1)))
    return blocks


def best_pokemon_frame(block: Image.Image) -> Image.Image | None:
    keyed = _key_sheet(block)
    candidates: list[tuple[float, Image.Image]] = []
    for box in find_islands(keyed, min_area=18, merge_gap=0):
        width, height = box[2] - box[0], box[3] - box[1]
        if not (4 <= width <= 32 and 5 <= height <= 32):
            continue
        frame = clean_alpha(largest_component(keyed.crop(tuple(box))), lo=1, hi=255)
        score = front_score(frame)
        if score > 0:
            candidates.append((score, frame))
    return fit_customer(max(candidates, key=lambda row: row[0])[1]) if candidates else None


def extract_pokemon(generated_names: dict[tuple[str, str], str]) -> int:
    if len(POKEMON_GEN1) != 150:
        raise SystemExit(f"Expected 150 Gen-I names, got {len(POKEMON_GEN1)}")
    source = FRANCHISES / "pokemon/raw/customers_updated/sprite_pok_mon_1st_generation_overworld.png"
    output = FRANCHISES / "pokemon/processed/customers"
    output.mkdir(parents=True, exist_ok=True)
    made = 0
    for name, block in zip(POKEMON_GEN1, pokemon_blocks(source)):
        slug = slugify(name)
        frame = best_pokemon_frame(block)
        if frame is None:
            print(f"  pokemon/{slug}: no clean updated frame")
            continue
        frame.save(output / f"{slug}.png")
        generated_names[("pokemon", slug)] = display_name(slug)
        made += 1
    print(f"  pokemon: {made} updated Gen-I customers")
    return made


def canonical_source_slug(world: str, path: Path) -> str:
    prefix, suffix = WORLD_SOURCES[world]
    stem = path.stem.replace(" - Copy", "")
    if stem.startswith(prefix):
        stem = stem[len(prefix):]
    if suffix and stem.endswith(suffix):
        stem = stem[:-len(suffix)]
    return slugify(stem)


def expand_single_sheet_world(world: str, generated_names: dict[tuple[str, str], str]) -> int:
    source = FRANCHISES / world / "raw/customers"
    output = FRANCHISES / world / "processed/customers"
    output.mkdir(parents=True, exist_ok=True)
    paths_by_slug: dict[str, Path] = {}
    for path in sorted(source.iterdir()):
        if path.suffix.lower() not in {".png", ".gif"} or " - Copy" in path.stem:
            continue
        slug = canonical_source_slug(world, path)
        if slug in NON_CUSTOMER_SLUGS:
            continue
        if world == "mario" and any(term in slug for term in ("battle", "disassembled", "bros_moves")):
            continue
        paths_by_slug.setdefault(slug, path)
    made = 0
    for slug, path in paths_by_slug.items():
        target = output / f"{slug}.png"
        if target.exists():
            existing = load_rgba(target)
            if existing.width >= 5 and existing.height >= 12:
                continue  # preserve the hand-verified/readable frame
        candidates = candidate_frames(path)
        if not candidates:
            continue
        fit_customer(candidates[0][3]).save(target)
        generated_names[(world, slug)] = display_name(slug)
        made += 1
    print(f"  {world}: {made} new single-sheet customers")
    return made


def supplement_world(world: str, target_count: int,
                     generated_names: dict[tuple[str, str], str]) -> int:
    output = FRANCHISES / world / "processed/customers"
    # Reproducible derivatives are cleared so a changed identity filter cannot
    # leave stale directional duplicates behind.
    for old in output.glob(f"{world}_traveler_*.png"):
        old.unlink()
    current_by_identity: dict[str, Path] = {}
    for path in sorted(output.glob("*.png")):
        if path.stem in NON_CUSTOMER_SLUGS:
            continue
        current_by_identity.setdefault(customer_identity(path.stem), path)
    current = list(current_by_identity.values())
    if len(current) >= target_count:
        return 0
    signatures = [
        (normalized_signature(load_rgba(path)), palette_signature(load_rgba(path)))
        for path in current if path.stem not in NON_CUSTOMER_SLUGS
    ]
    source = FRANCHISES / world / "raw/customers"
    all_candidates: list[tuple[float, Path, int, int, Image.Image]] = []
    for path in sorted(source.iterdir()):
        if path.suffix.lower() not in {".png", ".gif"}:
            continue
        for score, y, x, frame in candidate_frames(path)[:30]:
            all_candidates.append((score, path, y, x, frame))
    all_candidates.sort(key=lambda row: (-row[0], row[1].name, row[2], row[3]))
    made = 0
    for _score, path, _y, _x, frame in all_candidates:
        if len(current) + made >= target_count:
            break
        if not is_visually_new(frame, signatures):
            continue
        made += 1
        slug = f"{world}_traveler_{made:02d}"
        while (output / f"{slug}.png").exists():
            made += 1
            slug = f"{world}_traveler_{made:02d}"
        fit_customer(frame).save(output / f"{slug}.png")
        label = {"naruto": "Shinobi", "zelda": "Hyrule Resident", "dragon_ball": "Earthling"}[world]
        generated_names[(world, slug)] = f"{label} {made:02d}"
    print(f"  {world}: {made} additional distinct travelers (target {target_count})")
    return made


def write_pool(generated_names: dict[tuple[str, str], str]) -> None:
    existing_doc = json.loads(POOL_PATH.read_text(encoding="utf-8"))
    existing = {(str(row.get("world", "")), str(row.get("slug", ""))): row
                for row in existing_doc["pool"]}
    entries: list[dict] = []
    seen_identities: set[str] = set()
    for png in sorted(FRANCHISES.glob("*/processed/customers/*.png")):
        world = png.relative_to(FRANCHISES).parts[0]
        slug = png.stem
        if slug in NON_CUSTOMER_SLUGS:
            continue
        frame = load_rgba(png)
        if frame.width < 5 or frame.height < 10:
            continue
        identity = customer_identity(slug)
        # Costumes, transformations, and franchise crossovers are still the
        # same customer. Keep exactly one stable personality per character.
        if identity in seen_identities:
            continue
        seen_identities.add(identity)
        prior = existing.get((world, slug), {})
        manifest = FRANCHISES / world / "manifests" / f"pool_{slug}.json"
        entries.append({
            "slug": slug,
            "name": generated_names.get((world, slug), str(prior.get("name", display_name(slug)))),
            "world": world,
            "static": "res://" + png.relative_to(ROOT).as_posix(),
            "manifest": "res://" + manifest.relative_to(ROOT).as_posix() if manifest.exists() else "",
        })
    document = {"schema": "crossroads.customer_visuals.v2", "pool": entries}
    POOL_PATH.write_text(
        json.dumps(document, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    counts: dict[str, int] = {}
    for row in entries:
        counts[row["world"]] = counts.get(row["world"], 0) + 1
    print("  pool counts: " + ", ".join(f"{world}={count}" for world, count in sorted(counts.items())))


def customer_identity(slug: str) -> str:
    aliases = {
        "bowser_jpn": "bowser",
        "bowser_usa": "bowser",
        "cid_vii": "cid",
        "donald_duck_classic": "donald_duck",
        "goofy_classic": "goofy",
        "iruka_asuma_guy": "asuma",
        "luigi_overworld": "luigi",
        "mario_overworld": "mario",
        "piccolo_without_weight": "piccolo",
        "rookie_bowser_jpn": "bowser",
        "rookie_bowser_usa": "bowser",
    }
    if slug in aliases:
        return aliases[slug]
    identity = re.sub(
        r"_(battle_suit|casual|demon_clothes|namek_armor)(?:_super_saiyan(?:_2)?)?$",
        "",
        slug,
    )
    identity = re.sub(r"_super_saiyan(?:_2)?$", "", identity)
    identity = re.sub(r"_teen$", "", identity)
    identity = re.sub(r"_\d{4,}$", "", identity)
    return identity


def write_review_sheet() -> None:
    entries = json.loads(POOL_PATH.read_text(encoding="utf-8"))["pool"]
    cell_w, cell_h, columns = 84, 70, 10
    rows = (len(entries) + columns - 1) // columns
    sheet = Image.new("RGBA", (cell_w * columns, cell_h * rows), (29, 34, 52, 255))
    draw = ImageDraw.Draw(sheet)
    for index, entry in enumerate(entries):
        png = ROOT / str(entry["static"]).removeprefix("res://")
        frame = load_rgba(png)
        x = (index % columns) * cell_w
        y = (index // columns) * cell_h
        sheet.alpha_composite(frame, (x + (cell_w - frame.width) // 2, y + 2 + max(0, 42 - frame.height)))
        label = str(entry["name"])[:13]
        draw.text((x + 2, y + 47), label, fill=(255, 255, 255, 255))
        draw.text((x + 2, y + 58), str(entry["world"])[:12], fill=(170, 190, 225, 255))
    appdata = os.environ.get("APPDATA", "")
    review = (
        Path(appdata) / "Godot/app_userdata/Crossroads- An Item Shop Tale/screenshots/workshop_customer_overhaul/customer_pool_source_review.png"
        if appdata else ROOT / "tools/out/customer_pool_expanded_review.png"
    )
    review.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(review)
    print(f"  review sheet: {review}")


def main() -> None:
    generated_names: dict[tuple[str, str], str] = {}
    extract_pokemon(generated_names)
    for world in WORLD_SOURCES:
        expand_single_sheet_world(world, generated_names)
    for world, target in SUPPLEMENT_TARGETS.items():
        supplement_world(world, target, generated_names)
    write_pool(generated_names)
    write_review_sheet()


if __name__ == "__main__":
    main()

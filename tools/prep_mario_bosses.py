"""Build additional Mario expedition bosses from the supplied Superstar Saga art.

Queen Bean's source sheet is preserved under raw/customers. Run with
`--contact` to regenerate the labeled keyed reference used to select frames;
the normal mode writes the runtime sheet + manifest.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

from slice_lib import chroma_key, compose_grid, contact_sheet, find_islands, load_rgba


ROOT = Path(__file__).resolve().parents[1]
MARIO = ROOT / "assets/franchises/mario"
RAW = MARIO / "raw/customers/mario_queen_bean.png"
OUT_SHEET = MARIO / "processed/sheets/queen_bean.png"
OUT_MANIFEST = MARIO / "manifests/queen_bean.json"
BOO_SHEET = MARIO / "processed/sheets/boo.png"
KING_BOO_SHEET = MARIO / "processed/sheets/king_boo.png"
CONTACT = ROOT / "tools/out/mario_queen_bean_contact.png"


def keyed_sheet():
    image = load_rgba(RAW)
    # Flat cyan background sampled from the source sheet's upper-left pixel.
    image = chroma_key(image, image.getpixel((0, 0))[:3], tol=3)
    boxes = find_islands(image, min_area=70, merge_gap=0)
    return image, boxes


def build_king_boo() -> None:
    """Lift the existing animated Boo frames and give the boss a real crown."""
    source = Image.open(BOO_SHEET).convert("RGBA")
    cell_w, source_h, cell_h = 35, 27, 35
    output = Image.new("RGBA", (cell_w * 8, cell_h * 3), (0, 0, 0, 0))
    for row in range(3):
        for col in range(8):
            frame = source.crop((
                col * cell_w, row * source_h,
                (col + 1) * cell_w, (row + 1) * source_h,
            ))
            output.alpha_composite(frame, (col * cell_w, row * cell_h + 8))
            draw = ImageDraw.Draw(output)
            ox, oy = col * cell_w, row * cell_h
            outline = [
                (ox + 11, oy + 11), (ox + 11, oy + 5),
                (ox + 14, oy + 8), (ox + 17, oy + 2),
                (ox + 20, oy + 8), (ox + 23, oy + 5),
                (ox + 23, oy + 11),
            ]
            draw.polygon(outline, fill=(104, 55, 12, 255))
            fill = [
                (ox + 12, oy + 10), (ox + 12, oy + 7),
                (ox + 14, oy + 9), (ox + 17, oy + 4),
                (ox + 20, oy + 9), (ox + 22, oy + 7),
                (ox + 22, oy + 10),
            ]
            draw.polygon(fill, fill=(255, 210, 48, 255))
            draw.rectangle(
                (ox + 11, oy + 10, ox + 23, oy + 12),
                fill=(104, 55, 12, 255),
            )
            draw.rectangle(
                (ox + 12, oy + 10, ox + 22, oy + 11),
                fill=(255, 221, 64, 255),
            )
            draw.point((ox + 17, oy + 10), fill=(220, 45, 45, 255))
    KING_BOO_SHEET.parent.mkdir(parents=True, exist_ok=True)
    output.save(KING_BOO_SHEET)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contact", action="store_true")
    args = parser.parse_args()
    image, boxes = keyed_sheet()
    if args.contact:
        CONTACT.parent.mkdir(parents=True, exist_ok=True)
        contact_sheet(image, boxes, CONTACT, scale=1)
        print(f"wrote {CONTACT} with {len(boxes)} islands")
        for index, box in enumerate(boxes):
            print(index, box)
        return

    build_king_boo()
    # Picks verified against tools/out/mario_queen_bean_contact.png.
    # 51-63 are front battle poses, 64-73 are side steps, 74-81 are back
    # steps, and 84-91 are the hurt/attack turn. Side art is stored
    # left-facing in the rip, so compose_grid's negative ids flip it right.
    picks = {
        "idle_down": [51],
        "walk_down": [51, 53, 55, 57, 59, 61, 63],
        "idle_side": [-65],
        "walk_side": [-65, -66, -67, -68, -69, -70, -71, -72, -73, -74],
        "idle_up": [74],
        "walk_up": [74, 75, 76, 77, 78, 79, 80, 81],
        "attack_1": [84, 85, 86, 87, 88, 89, 90, 91],
    }
    compose_grid(
        image,
        boxes,
        picks,
        (76, 64),
        OUT_SHEET,
        OUT_MANIFEST,
        "res://assets/franchises/mario/processed/sheets/queen_bean.png",
        fps={"walk_down": 7, "walk_side": 7, "walk_up": 7, "attack_1": 10},
        loops={"attack_1": False},
    )


if __name__ == "__main__":
    main()

"""Extract verified OMORI furniture from the user-supplied moredecor atlas.

The source sheet is preserved untouched. Picks were visually verified against
%TEMP%/crossroads_moredecor/homes_contact.png, generated with slice_lib's
labeled contact-sheet workflow on the transparent band beginning at y=760.
"""
from pathlib import Path
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import clean_alpha, find_islands, largest_component  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (
    ROOT
    / "assets/shared/furniture/decor/moredecor"
    / "sprite_faraway_town_interior_homes_day.png"
)
OUTPUT = ROOT / "assets/shared/furniture/decor"
BAND_Y = 760

# Contact-sheet index -> (output id, expected band-relative box).
PICKS = {
    9: ("omori_brick_hearth", (6, 454, 59, 568)),
    124: ("omori_tall_houseplant", (352, 550, 384, 649)),
    128: ("omori_photo_garland", (354, 831, 450, 864)),
    135: ("omori_party_balloons", (358, 135, 378, 202)),
    159: ("omori_round_cafe_table", (406, 883, 459, 934)),
    183: ("omori_rose_sofa", (450, 765, 542, 810)),
    194: ("omori_stage_curtain", (484, 68, 572, 179)),
    274: ("omori_haunted_portrait", (751, 520, 816, 581)),
    298: ("omori_arched_window", (834, 486, 926, 617)),
    334: ("omori_ceiling_fan", (952, 382, 996, 444)),
}


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    band = source.crop((0, BAND_Y, source.width, source.height))
    boxes = find_islands(band, min_area=45, merge_gap=2)
    OUTPUT.mkdir(parents=True, exist_ok=True)

    for island_index, (asset_id, expected_box) in PICKS.items():
        actual_box = boxes[island_index]
        if tuple(actual_box) != expected_box:
            raise RuntimeError(
                f"{asset_id}: island {island_index} moved; "
                f"expected {expected_box}, got {actual_box}"
            )
        crop = clean_alpha(band.crop(actual_box))
        if asset_id == "omori_ceiling_fan":
            crop = clean_alpha(largest_component(crop))
        out_path = OUTPUT / f"{asset_id}.png"
        crop.save(out_path)
        print(f"wrote {out_path.relative_to(ROOT)} ({crop.width}x{crop.height})")


if __name__ == "__main__":
    main()

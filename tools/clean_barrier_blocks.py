"""Remove the dark text labels bundled beside supplied dungeon barrier art.

The source PNGs were delivered directly in their final location. Keeping this
small pass idempotent makes the processed result reproducible without manual
pixel edits: retain the largest connected opaque component, then trim only the
transparent canvas around it.
"""
from pathlib import Path

from slice_lib import largest_component, load_rgba


ROOT = Path(__file__).resolve().parents[1]
LABELED_BLOCKS = [
    "assets/locations/ffdungeon/processed/barrier_block.png",
    "assets/locations/mariodungeon/barrierblock.png",
    "assets/locations/narutodungeon/processed/barrier_block.png",
    "assets/locations/zeldadungeon/processed/barrier_block.png",
]


def clean(path: Path) -> None:
    art = largest_component(load_rgba(path))
    bbox = art.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError(f"barrier has no visible pixels: {path}")
    art = art.crop(bbox)
    art.save(path)
    print(f"{path.relative_to(ROOT)}: {art.width}x{art.height}")


def main() -> None:
    for relative in LABELED_BLOCKS:
        clean(ROOT / relative)


if __name__ == "__main__":
    main()

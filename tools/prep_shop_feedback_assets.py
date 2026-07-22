"""Extract the user-supplied Crossroads economy/customer feedback art.

Sources remain untouched in assets/wip_sprites/.  Crops were verified against
the labeled sheets supplied 2026-07-21; every output is transparent and sized
for the 640x360 logical viewport.
"""
from pathlib import Path

from PIL import Image

from slice_lib import clean_alpha, resize_rgba


ROOT = Path(__file__).resolve().parents[1]
WIP = ROOT / "assets" / "wip_sprites"
OUT = ROOT / "assets" / "shared" / "ui" / "processed"


def fit_crop(source: Image.Image, box: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
    crop = clean_alpha(source.crop(box), lo=4, hi=245)
    ratio = min(size[0] / crop.width, size[1] / crop.height)
    fitted = resize_rgba(crop, (max(1, round(crop.width * ratio)), max(1, round(crop.height * ratio))))
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(fitted, ((size[0] - fitted.width) // 2, size[1] - fitted.height))
    return canvas


def save(image: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    image.save(path)
    print(f"{name}: {image.size}")


def main() -> None:
    coins = Image.open(WIP / "crossroadscoins.png").convert("RGBA")
    # Manual regions exclude the white annotation cards to the right.
    save(fit_crop(coins, (0, 440, 356, 730), (72, 56)), "gold_pile_large.png")
    save(fit_crop(coins, (0, 800, 265, 1050), (48, 40)), "gold_pile_medium.png")
    save(fit_crop(coins, (0, 1130, 260, 1340), (24, 20)), "gold_coin_small.png")

    emotes = Image.open(WIP / "customeremotes.png").convert("RGBA")
    # Six labeled 16x16 rows: leave/bad, Boom, perfect/good, overpaid,
    # neutral interaction, wealthy.
    for name, y in [
        ("unhappy", 34),
        ("boom", 59),
        ("happy", 80),
        ("overpaid", 105),
        ("neutral", 128),
        ("wealthy", 149),
    ]:
        save(emotes.crop((0, y, 16, y + 16)), f"emote_{name}.png")

    bonds = Image.open(WIP / "customerbond.png").convert("RGBA")
    # Each region contains one heart, its detached sparkle/crown, and number.
    bond_boxes = [
        (18, 690, 180, 975),
        (205, 660, 400, 975),
        (405, 640, 610, 975),
        (605, 615, 810, 975),
        (805, 565, 1024, 975),
    ]
    for tier, box in enumerate(bond_boxes, 1):
        save(fit_crop(bonds, box, (64, 64)), f"bond_{tier}.png")


if __name__ == "__main__":
    main()

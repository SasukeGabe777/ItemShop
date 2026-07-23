"""Build 640x384 ROTMG room-floor backgrounds by tiling groundTiles.png.

The dungeon grid is 20x12 cells of 32px. ROTMG ground tiles are native 8x8, so we
upscale each 4x -> exactly one tile per dungeon cell (clean alignment, per the
AGENT_GUIDE room-crop rule). Each biome picks its ground tile(s) from the atlas
by colour score, then tiles the room with a little per-cell tile-variation and
brightness jitter so it doesn't read as a flat repeat. Deterministic (seeded).

Outputs to assets/locations/rotmgdungeon/processed/{start,combat,treasure,boss}_*.png
plus prop_*.png cut from the raw location/Environment art. Never touches raw/.
"""
import os
from PIL import Image, ImageEnhance
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAWF = os.path.join(ROOT, "assets/franchises/rotmg/raw")
OUT = os.path.join(ROOT, "assets/locations/rotmgdungeon/processed")
T = 8
CELL = 32           # dungeon cell px -> upscale factor 4
COLS, ROWS = 20, 12  # 640x384

_atlas = np.array(Image.open(os.path.join(RAWF, "Sheets/atlases/groundTiles.png")).convert("RGBA"))


def _uniform_tiles():
    H, W = _atlas.shape[:2]
    out = []
    for ty in range(H // T):
        for tx in range(W // T):
            c = _atlas[ty*T:(ty+1)*T, tx*T:(tx+1)*T]
            if (c[:, :, 3] > 200).all():
                rgb = c[:, :, :3].reshape(-1, 3).astype(float)
                if rgb.std(axis=0).mean() < 40:
                    out.append((tx, ty, rgb.mean(axis=0)))
    return out


def _best(tiles, score, n=3):
    ranked = sorted(tiles, key=lambda t: score(*t[2]), reverse=True)
    return [(tx, ty) for tx, ty, _ in ranked[:n]]


def pick_biomes():
    t = _uniform_tiles()
    return {
        "grass":  _best(t, lambda r, g, b: g - 0.7*r - 0.8*b + (g > 90)*20),
        "dirt":   _best(t, lambda r, g, b: -(abs(r-120) + abs(g-85) + abs(b-55)) + (r > g > b)*30),
        "sand":   _best(t, lambda r, g, b: (r+g) - 1.5*b + (min(r, g) > 150)*30),
        "stone":  _best(t, lambda r, g, b: -(max(r, g, b)-min(r, g, b))*2 - abs((r+g+b)/3 - 135)),
        "lava":   _best(t, lambda r, g, b: r - b - abs(g-100) + (r > 170)*20),
        "abyss":  _best(t, lambda r, g, b: -(r+g+b)/3 * 1.5 + (b - r) * 0.3),
    }


def _tile_img(tx, ty):
    return Image.fromarray(_atlas[ty*T:(ty+1)*T, tx*T:(tx+1)*T]).resize((CELL, CELL), Image.NEAREST)


def build_bg(name, tile_sets, seed):
    """Intentional tiling: a dominant biome laid in coherent 2x2 patches, with the
    accent biome appearing as occasional organic clumps (not per-cell noise). Each
    patch commits to one tile so terrain reads as connected regions.
    tile_sets = [primary_tiles, accent_tiles] (each a list of (tx, ty))."""
    rng = np.random.default_rng(seed)
    prim = [_tile_img(*t) for t in tile_sets[0]]
    acc = [_tile_img(*t) for t in (tile_sets[1] if len(tile_sets) > 1 else tile_sets[0])]
    bg = Image.new("RGBA", (COLS*CELL, ROWS*CELL), (0, 0, 0, 255))
    P = 2  # patch size in cells
    for by in range(0, ROWS, P):
        for bx in range(0, COLS, P):
            pool = acc if rng.random() < 0.16 else prim   # ~16% accent clumps
            base = int(rng.integers(len(pool)))
            for r in range(by, min(by + P, ROWS)):
                for c in range(bx, min(bx + P, COLS)):
                    # mostly the patch tile; a small chance to vary within it
                    idx = base if rng.random() < 0.8 else int(rng.integers(len(pool)))
                    bg.paste(pool[idx], (c*CELL, r*CELL))
    os.makedirs(OUT, exist_ok=True)
    bg.save(os.path.join(OUT, name + ".png"))
    return bg


def build_props():
    """Cut a few background-free environment props (<=36px) for obstacle_props."""
    env = os.path.join(RAWF, "location/Environment")
    picks = {"prop_tree": "Tree Round.png", "prop_tree_small": "Tree Small.png",
             "prop_bush": "Bush.png", "prop_bush2": "Bush 3.png"}
    for pid, src in picks.items():
        fp = os.path.join(env, src)
        if not os.path.exists(fp):
            print(f"  !! prop missing {src}"); continue
        im = Image.open(fp).convert("RGBA")
        a = np.array(im); m = a[:, :, 3] > 16
        ys, xs = np.where(m)
        im = im.crop((xs.min(), ys.min(), xs.max()+1, ys.max()+1))
        scale = 34 / max(im.width, im.height)
        im = im.resize((max(1, round(im.width*scale)), max(1, round(im.height*scale))), Image.LANCZOS)
        im.save(os.path.join(OUT, pid + ".png"))
        print(f"  prop {pid} {im.size} <- {src}")


def main():
    b = pick_biomes()
    for k, v in b.items():
        print(f"biome {k}: tiles {v}")
    build_bg("start_grass",     [b["grass"], b["dirt"]], 11)
    build_bg("combat_grass",    [b["grass"], b["dirt"]], 22)
    build_bg("combat_godland",  [b["grass"], b["stone"]], 33)
    build_bg("combat_desert",   [b["sand"], b["dirt"]], 44)
    build_bg("combat_forest",   [b["grass"], b["abyss"]], 55)
    build_bg("treasure_marble", [b["stone"], b["sand"]], 66)
    build_bg("boss_abyss",      [b["abyss"], b["stone"]], 77)
    build_bg("boss_lava",       [b["lava"], b["dirt"]], 88)
    build_props()
    print("rooms built ->", OUT)


if __name__ == "__main__":
    main()

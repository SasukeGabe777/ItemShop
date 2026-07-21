"""Cut Minish Cap barrier tiles (Lon Lon Ranch / Hyrule Field) from the BG
dumps captured by capture_barriers_zelda_fields.lua + decoded by decode_bg.py.
Reads tools/rom_ref/out/bg/decoded/*.png, writes native-8px-aligned crops
upscaled 2x NEAREST into tools/rom_ref/out/staging/zelda/. Never touches
assets/ or data/ -- this is reference art for a future wiring pass.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from slice_lib import clean_alpha, flood_bg, resize_rgba  # noqa: E402

from PIL import Image

DEC = Path("tools/rom_ref/out/bg/decoded")
STAGE = Path("tools/rom_ref/out/staging/zelda")
STAGE.mkdir(parents=True, exist_ok=True)


def load(tag_layer: str) -> Image.Image:
    return Image.open(DEC / f"{tag_layer}.png").convert("RGBA")


def save2x(img: Image.Image, name: str) -> None:
    up = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
    up.save(STAGE / name)
    print(f"  {name}: native {img.size} -> {up.size}")


# ---------------------------------------------------------------------------
# 1) Round hedge bush -- BG1 overlay (transparent), CONFIRMED blocker via
#    edge_field_hedge_left (screen unchanged pressing Left into it) and
#    edge_ranch_fence_right (screen unchanged pressing Right into it).
#    Source: bg1_field_hedge.png, the tall single lobe of the maze's T-joint
#    (x 56-136, y 32-100 native window) -- trimmed to content, fit to a
#    32x32 native cell (matches the 2x2-cell hedge scale already used in
#    assets/locations/zeldadungeon/processed/combat_fields.png).
hedge_src = load("bg1_field_hedge")
hedge_crop = hedge_src.crop((56, 32, 136, 100))
hedge_crop = clean_alpha(hedge_crop, lo=40, hi=216)
# fit into a 32x32 native cell, preserving aspect (single lobe reads clean)
ratio = min(32 / hedge_crop.width, 32 / hedge_crop.height)
hedge_fit = resize_rgba(hedge_crop, (max(1, int(hedge_crop.width * ratio)), max(1, int(hedge_crop.height * ratio))))
canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
canvas.alpha_composite(hedge_fit, ((32 - hedge_fit.width) // 2, 32 - hedge_fit.height))
save2x(canvas, "hedge_lobe_32.png")

# 1b) Hedge maze corner/junction -- same site, wider window showing the
# T-junction silhouette (row + branch), useful as a distinct "hedge corner"
# variant. Native 8px-aligned box, fit to 32x64 (1x2 cells).
corner_crop = hedge_src.crop((32, 40, 160, 176))
corner_crop = clean_alpha(corner_crop, lo=40, hi=216)
ratio = min(32 / corner_crop.width, 64 / corner_crop.height)
corner_fit = resize_rgba(corner_crop, (max(1, int(corner_crop.width * ratio)), max(1, int(corner_crop.height * ratio))))
canvas2 = Image.new("RGBA", (32, 64), (0, 0, 0, 0))
canvas2.alpha_composite(corner_fit, ((32 - corner_fit.width) // 2, 64 - corner_fit.height))
save2x(canvas2, "hedge_corner_32x64.png")

# ---------------------------------------------------------------------------
# 2) Wooden lattice fence rail -- BG2 main map (opaque texture, self-
#    contained: the maroon+white "h" glyph fills its whole cell, no grass
#    baked in at this crop). Source: bg2_ranch_fence.png, a clean two-row
#    repeat at x=192-208 (one column of the long run visible at x=160-240).
#    NOT edge-probed directly at this exact tile (the edge probe at this site
#    landed on the hedge/crop-row in front of Link, not this fence segment,
#    which sits nearby in the same loaded VRAM block) -- flagged in report.
fence_src = load("bg2_ranch_fence")
fence_mid = fence_src.crop((192, 136, 208, 168))  # 16x32 native
save2x(fence_mid, "fence_lattice_mid_16x32.png")

# 2b) Wooden log/post -- vertical variant, same site, x=224-240 y=96-128.
# Crop is already tight to the post texture (no grass at these edges, checked
# against the raw crop) -- delivered opaque as-is, no flood needed.
post_crop = fence_src.crop((224, 96, 240, 128))  # 16x32 native
save2x(post_crop, "fence_post_vert_16x32.png")

# ---------------------------------------------------------------------------
# 3) Stone wall -- BG2 main map, the gray building/wall segment near the
#    hedge gate (field_planter site). Ground (grass) baked in at the base;
#    flooded out with the standard grass predicate. Not edge-probed in this
#    exact direction either -- flagged as a strong-by-design candidate only.
wall_src = load("bg2_field_planter")
wall_crop = wall_src.crop((0, 24, 32, 72))  # 32x48 native, one wall bay + base
wall_keyed = flood_bg(wall_crop, lambda rgb: (rgb[..., 1] > rgb[..., 0] + 15) & (rgb[..., 1] > rgb[..., 2] + 50))
wall_keyed = clean_alpha(wall_keyed, lo=40, hi=216)
save2x(wall_keyed, "stone_wall_32x48.png")

print("done")

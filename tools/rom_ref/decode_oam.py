"""Reconstruct isolated hero frames from dumped OAM + OBJ-VRAM + OBJ-palette.

Two-pass, position-independent isolation (v2 -- the X-band of v1 broke as soon
as Link drifted from screen center):

1. HUD detection: an OAM object whose (x, y, w, h, tile, pal) tuple is identical
   in >60% of all captured frames is static UI (hearts, button display, item
   boxes, rupee counter) and is excluded everywhere.
2. Hero cluster: in Minish Cap, Link's body objects are palette bank 6 and his
   drop-shadow is the pal-5 tile-1 object under his feet. Any non-HUD object
   within GATHER_R px of the body bbox is kept too -- that pulls in the sword
   blade (pal 4) and swing sparkles (pal 1) without a hardcoded screen band.
3. Registration: every frame is cropped as a fixed CELL x CELL window anchored
   on the shadow's center (the feet), so frames land pre-registered for a
   sprite-sheet grid. The shadow itself is not rendered.

Outputs per frame: obj_all_<tag>.png (full object layer, for retuning) and
link_<tag>.png (registered isolated crop), plus a contact sheet per action
group (tag prefix before the trailing _NN).

Assumes 4bpp objects, 1D tile mapping (DISPCNT bit6 set) -- verified for Minish Cap.
"""
import glob, os, re, struct
from collections import Counter, defaultdict
import numpy as np
from PIL import Image, ImageDraw

OAMDIR = "tools/rom_ref/out/oam"
OUT = "tools/rom_ref/out/oam/decoded"
os.makedirs(OUT, exist_ok=True)

BODY_PAL = 6          # Link's body palette bank (Minish Cap)
SHADOW = (5, 1)       # (pal, tile) of the drop-shadow anchor object
GATHER_R = 24         # px around body bbox to pull in weapon/effect objects
CELL = 48             # output cell size; feet anchored at (CELL/2, FEET_Y)
FEET_Y = 40
HUD_FRACTION = 0.6

# shape/size -> (w,h) in pixels
SIZES = {
    0: {0: (8, 8),  1: (16, 16), 2: (32, 32), 3: (64, 64)},   # square
    1: {0: (16, 8), 1: (32, 8),  2: (32, 16), 3: (64, 32)},   # horizontal
    2: {0: (8, 16), 1: (8, 32),  2: (16, 32), 3: (32, 64)},   # vertical
}

def load_palette(path):
    raw = open(path, "rb").read()
    cols = struct.unpack("<256H", raw)
    pal = np.zeros((256, 4), np.uint8)
    for i, c in enumerate(cols):
        r = (c & 0x1F); g = (c >> 5) & 0x1F; b = (c >> 10) & 0x1F
        pal[i] = (r << 3 | r >> 2, g << 3 | g >> 2, b << 3 | b >> 2, 255)
    return pal

def parse_oam(oam):
    """Yield visible 4bpp objects as dicts."""
    for i in range(128):
        a0, a1, a2 = struct.unpack_from("<HHH", oam, i * 8)
        affine = (a0 >> 8) & 1
        if not affine and ((a0 >> 9) & 1):
            continue  # hidden
        if (a0 >> 13) & 1:
            continue  # 8bpp unhandled (Link is 4bpp)
        y = a0 & 0xFF
        if y >= 160: y -= 256
        x = a1 & 0x1FF
        if x >= 400: x -= 512
        w, h = SIZES[(a0 >> 14) & 3][(a1 >> 14) & 3]
        yield {
            "x": x, "y": y, "w": w, "h": h,
            "hflip": (a1 >> 12) & 1 if not affine else 0,
            "vflip": (a1 >> 13) & 1 if not affine else 0,
            "tile": a2 & 0x3FF, "pal": (a2 >> 12) & 0xF,
        }

def obj_key(o):
    return (o["x"], o["y"], o["w"], o["h"], o["tile"], o["pal"])

def decode_tile_4bpp(vram, tilenum):
    """Return 8x8 array of palette-nibble indices (0..15)."""
    off = (tilenum & 0x3FF) * 32
    data = vram[off:off + 32]
    t = np.zeros((8, 8), np.uint8)
    for row in range(8):
        for k in range(4):
            byte = data[row * 4 + k]
            t[row, k * 2] = byte & 0x0F
            t[row, k * 2 + 1] = byte >> 4
    return t

def render(objs, vram, pal, canvas_w=240, canvas_h=160, ox=0, oy=0):
    canvas = np.zeros((canvas_h, canvas_w, 4), np.uint8)
    for o in objs:
        w, h = o["w"], o["h"]
        tiles_w = w // 8
        sprite = np.zeros((h, w, 4), np.uint8)
        for ty in range(h // 8):
            for tx in range(tiles_w):
                idx = decode_tile_4bpp(vram, o["tile"] + ty * tiles_w + tx)
                block = np.zeros((8, 8, 4), np.uint8)
                for yy in range(8):
                    for xx in range(8):
                        n = idx[yy, xx]
                        if n != 0:
                            block[yy, xx] = pal[o["pal"] * 16 + n]
                sprite[ty * 8:ty * 8 + 8, tx * 8:tx * 8 + 8] = block
        if o["hflip"]: sprite = sprite[:, ::-1]
        if o["vflip"]: sprite = sprite[::-1, :]
        for yy in range(h):
            py = o["y"] + yy + oy
            if py < 0 or py >= canvas_h: continue
            for xx in range(w):
                px = o["x"] + xx + ox
                if px < 0 or px >= canvas_w: continue
                if sprite[yy, xx, 3]:
                    canvas[py, px] = sprite[yy, xx]
    return canvas

def bbox_dist(o, x0, y0, x1, y1):
    dx = max(x0 - (o["x"] + o["w"]), o["x"] - x1, 0)
    dy = max(y0 - (o["y"] + o["h"]), o["y"] - y1, 0)
    return max(dx, dy)

def contact_sheet(imgs, path):
    scale, cols, lab = 4, 8, 14
    mw = max(a.shape[1] for _, a in imgs) * scale
    mh = max(a.shape[0] for _, a in imgs) * scale
    cw, ch = mw + 8, mh + lab + 6
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cw, rows * ch), (40, 40, 40))
    d = ImageDraw.Draw(sheet)
    for i, (tag, arr) in enumerate(imgs):
        im = Image.fromarray(arr, "RGBA").resize(
            (arr.shape[1] * scale, arr.shape[0] * scale), Image.NEAREST)
        cellimg = Image.new("RGBA", (mw, mh), (60, 60, 60, 255))
        cellimg.alpha_composite(im, ((mw - im.width) // 2, (mh - im.height) // 2))
        r, c = divmod(i, cols)
        d.text((c * cw + 2, r * ch), tag, fill=(255, 255, 0))
        sheet.paste(cellimg.convert("RGB"), (c * cw + 4, r * ch + lab))
    sheet.save(path)

frames = sorted(glob.glob(f"{OAMDIR}/oam_*.bin"))

# pass 1: find static HUD objects
counts = Counter()
for fp in frames:
    for o in parse_oam(open(fp, "rb").read()):
        counts[obj_key(o)] += 1
hud = {k for k, n in counts.items() if n > len(frames) * HUD_FRACTION}
print(f"{len(frames)} frames; {len(hud)} static HUD objects excluded")

# pass 2: render
groups = defaultdict(list)
for fp in frames:
    tag = os.path.basename(fp)[4:-4]
    oam = open(fp, "rb").read()
    vram = open(f"{OAMDIR}/objvram_{tag}.bin", "rb").read()
    pal = load_palette(f"{OAMDIR}/objpal_{tag}.bin")
    objs = [o for o in parse_oam(oam)]
    Image.fromarray(render(objs, vram, pal), "RGBA").save(f"{OUT}/obj_all_{tag}.png")

    live = [o for o in objs if obj_key(o) not in hud]
    body = [o for o in live if o["pal"] == BODY_PAL]
    shadow = [o for o in live if (o["pal"], o["tile"]) == SHADOW]
    if not body or not shadow:
        print("decoded", tag, "-- no body/shadow, skipped")
        continue
    x0 = min(o["x"] for o in body); x1 = max(o["x"] + o["w"] for o in body)
    y0 = min(o["y"] for o in body); y1 = max(o["y"] + o["h"] for o in body)
    keep = [o for o in live
            if (o["pal"], o["tile"]) != SHADOW
            and (o["pal"] == BODY_PAL or bbox_dist(o, x0, y0, x1, y1) <= GATHER_R)]
    ax = shadow[0]["x"] + shadow[0]["w"] // 2   # feet anchor = shadow center
    ay = shadow[0]["y"] + shadow[0]["h"] // 2
    cell = render(keep, vram, pal, CELL, CELL,
                  ox=CELL // 2 - ax, oy=FEET_Y - ay)
    Image.fromarray(cell, "RGBA").save(f"{OUT}/link_{tag}.png")
    groups[re.sub(r"_\d+$", "", tag)].append((tag, cell))
    print("decoded", tag, f"objs={len(keep)}")

for prefix, imgs in sorted(groups.items()):
    path = f"{OUT}/contact_{prefix}.png"
    contact_sheet(imgs, path)
    print("contact sheet:", path, "frames:", len(imgs))

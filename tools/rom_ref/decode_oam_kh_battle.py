"""Battle-view variant of decode_oam_kh.py. Retuned from an OAM dump of a
few battle frames: Sora's body in battle is palette bank 0 only (head/torso
tile 0, legs tile 16, blade/accent tile 24 -- all pal 0, no separate
constant-tile shadow object like the field view has). The enemy (pal 1/3)
sits far enough away that a body-bbox anchor with no gather radius keeps it
out cleanly; the "Selecting Cards" tutorial reminder renders as many static
16x16 objects in pal 4/5 near the top of the screen (text glyphs) and is
excluded as HUD (same object tuple every frame).

Anchor: no shadow object exists in this view, so the feet anchor is the
bottom-center of the pal-0 (body) bounding box instead.
"""
import glob, os, re, struct
from collections import Counter, defaultdict
import numpy as np
from PIL import Image, ImageDraw

OAMDIR = "tools/rom_ref/out/oam"
OUT = "tools/rom_ref/out/oam/decoded_kh_battle"
os.makedirs(OUT, exist_ok=True)

BODY_PAL = 0
CELL = 64
FEET_Y = 56
HUD_FRACTION = 0.6

SIZES = {
    0: {0: (8, 8),  1: (16, 16), 2: (32, 32), 3: (64, 64)},
    1: {0: (16, 8), 1: (32, 8),  2: (32, 16), 3: (64, 32)},
    2: {0: (8, 16), 1: (8, 32),  2: (16, 32), 3: (32, 64)},
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
    for i in range(128):
        a0, a1, a2 = struct.unpack_from("<HHH", oam, i * 8)
        affine = (a0 >> 8) & 1
        if not affine and ((a0 >> 9) & 1):
            continue
        if (a0 >> 13) & 1:
            continue
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

frames = sorted(glob.glob(f"{OAMDIR}/oam_satk*.bin") + glob.glob(f"{OAMDIR}/oam_sdodge*.bin"))

counts = Counter()
for fp in frames:
    for o in parse_oam(open(fp, "rb").read()):
        counts[obj_key(o)] += 1
hud = {k for k, n in counts.items() if n > len(frames) * HUD_FRACTION}
print(f"{len(frames)} frames; {len(hud)} static HUD objects excluded")

groups = defaultdict(list)
for fp in frames:
    tag = os.path.basename(fp)[4:-4]
    oam = open(fp, "rb").read()
    vram = open(f"{OAMDIR}/objvram_{tag}.bin", "rb").read()
    pal = load_palette(f"{OAMDIR}/objpal_{tag}.bin")
    objs = [o for o in parse_oam(oam)]

    live = [o for o in objs if obj_key(o) not in hud]
    body = [o for o in live if o["pal"] == BODY_PAL]
    if not body:
        print("decoded", tag, "-- no body, skipped")
        continue
    x0 = min(o["x"] for o in body); x1 = max(o["x"] + o["w"] for o in body)
    y0 = min(o["y"] for o in body); y1 = max(o["y"] + o["h"] for o in body)
    ax = (x0 + x1) // 2
    ay = y1
    cell = render(body, vram, pal, CELL, CELL,
                  ox=CELL // 2 - ax, oy=FEET_Y - ay)
    Image.fromarray(cell, "RGBA").save(f"{OUT}/sora_{tag}.png")
    groups[re.sub(r"_\d+$", "", tag)].append((tag, cell))
    print("decoded", tag, f"objs={len(body)}")

for prefix, imgs in sorted(groups.items()):
    path = f"{OUT}/contact_{prefix}.png"
    contact_sheet(imgs, path)
    print("contact sheet:", path, "frames:", len(imgs))

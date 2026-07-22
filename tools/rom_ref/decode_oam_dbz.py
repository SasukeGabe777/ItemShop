"""Reconstruct isolated Piccolo/Goku frames from DBZ LoG II OAM dumps.

DBZ LoG II differs from Minish Cap in two big ways (found via raw OAM dump):
objects are 8bpp (256-color, palette bank meaningless) and the scene is sparse
(~5 objects: 3 static HUD bars + the hero). So isolation is: drop static HUD
tuples (same OAM tuple in >60% of frames), keep every other object, anchor the
crop on the cluster bbox bottom-center. 8bpp 1D mapping: tile numbers advance
by 2 per 8x8 block.
"""
import argparse, glob, os, re, struct
from collections import Counter, defaultdict
import numpy as np
from PIL import Image, ImageDraw

OAMDIR = "tools/rom_ref/out/oam_dbz"
OUT = "tools/rom_ref/out/oam_dbz/decoded"

# --- retune for DBZ (discovered via --probe) ---
BODY_PAL = None       # set after probe
SHADOW = None         # (pal, tile) anchor object, or None to anchor on body bbox
GATHER_R = 24
CELL = 64             # beams are long; keep a generous cell
FEET_Y = 52
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
        y = a0 & 0xFF
        if y >= 160: y -= 256
        x = a1 & 0x1FF
        if x >= 400: x -= 512
        w, h = SIZES[(a0 >> 14) & 3][(a1 >> 14) & 3]
        yield {
            "x": x, "y": y, "w": w, "h": h,
            "bpp8": (a0 >> 13) & 1,
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

def decode_tile_8bpp(vram, tilenum):
    off = (tilenum & 0x3FF) * 32
    data = vram[off:off + 64]
    return np.frombuffer(data, np.uint8).reshape(8, 8).copy()

def render(objs, vram, pal, canvas_w=240, canvas_h=160, ox=0, oy=0):
    canvas = np.zeros((canvas_h, canvas_w, 4), np.uint8)
    for o in objs:
        w, h = o["w"], o["h"]
        tiles_w = w // 8
        sprite = np.zeros((h, w, 4), np.uint8)
        for ty in range(h // 8):
            for tx in range(tiles_w):
                block = np.zeros((8, 8, 4), np.uint8)
                if o["bpp8"]:
                    idx = decode_tile_8bpp(vram, o["tile"] + (ty * tiles_w + tx) * 2)
                    for yy in range(8):
                        for xx in range(8):
                            n = idx[yy, xx]
                            if n != 0:
                                block[yy, xx] = pal[n]
                else:
                    idx = decode_tile_4bpp(vram, o["tile"] + ty * tiles_w + tx)
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
    scale, cols, lab = 3, 10, 14
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

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--probe", action="store_true",
                    help="render obj_all for sample frames + print pal inventory")
    ap.add_argument("--body-pal", type=int, default=BODY_PAL)
    ap.add_argument("--shadow", default=None,
                    help="pal,tile of shadow anchor (e.g. 5,1); omit = body-bbox anchor")
    ap.add_argument("--tags", default="",
                    help="only decode tags matching this regex")
    ap.add_argument("--cell", type=int, default=CELL)
    ap.add_argument("--feet-y", type=int, default=FEET_Y)
    ap.add_argument("--oamdir", default=OAMDIR,
                    help="directory with oam_*/objvram_*/objpal_* dumps")
    ap.add_argument("--outdir", default=None,
                    help="decoded output dir (default: <oamdir>/decoded)")
    ap.add_argument("--prefix", default="piccolo_",
                    help="filename prefix for decoded per-frame PNGs")
    args = ap.parse_args()
    oamdir = args.oamdir
    outdir = args.outdir or f"{oamdir}/decoded"
    os.makedirs(outdir, exist_ok=True)

    frames = sorted(glob.glob(f"{oamdir}/oam_*.bin"))
    counts = Counter()
    for fp in frames:
        for o in parse_oam(open(fp, "rb").read()):
            counts[obj_key(o)] += 1
    hud = {k for k, n in counts.items() if n > len(frames) * HUD_FRACTION}
    print(f"{len(frames)} frames; {len(hud)} static HUD objects excluded")

    if args.probe:
        # sample one frame per action group; print live-object table
        seen = set()
        for fp in frames:
            tag = os.path.basename(fp)[4:-4]
            prefix = re.sub(r"_\d+$", "", tag)
            if prefix in seen:
                continue
            seen.add(prefix)
            oam = open(fp, "rb").read()
            vram = open(f"{oamdir}/objvram_{tag}.bin", "rb").read()
            pal = load_palette(f"{oamdir}/objpal_{tag}.bin")
            objs = list(parse_oam(oam))
            live = [o for o in objs if obj_key(o) not in hud]
            Image.fromarray(render(objs, vram, pal), "RGBA").save(
                f"{outdir}/obj_all_{tag}.png")
            print(f"\n== {tag}  ({len(live)} live objs)")
            for o in sorted(live, key=lambda o: (o["pal"], o["tile"])):
                print(f"  pal={o['pal']:2d} tile={o['tile']:4d} "
                      f"{o['w']}x{o['h']} at ({o['x']},{o['y']})")
        return

    tagre = re.compile(args.tags) if args.tags else None

    groups = defaultdict(list)
    for fp in frames:
        tag = os.path.basename(fp)[4:-4]
        if tagre and not tagre.search(tag):
            continue
        oam = open(fp, "rb").read()
        vram = open(f"{oamdir}/objvram_{tag}.bin", "rb").read()
        pal = load_palette(f"{oamdir}/objpal_{tag}.bin")
        live = [o for o in parse_oam(oam) if obj_key(o) not in hud]
        # sparse scene: everything non-HUD is the hero + their effects
        keep = live
        if not keep:
            print("decoded", tag, "-- no objects, skipped")
            continue
        # anchor on the hero: the object nearest screen center (camera-locked)
        hero = min(keep, key=lambda o: (o["x"] + o["w"] / 2 - 120) ** 2
                                     + (o["y"] + o["h"] / 2 - 80) ** 2)
        ax = hero["x"] + hero["w"] // 2
        ay = hero["y"] + hero["h"]
        cell = render(keep, vram, pal, args.cell, args.cell,
                      ox=args.cell // 2 - ax, oy=args.feet_y - ay)
        Image.fromarray(cell, "RGBA").save(f"{outdir}/{args.prefix}{tag}.png")
        groups[re.sub(r"_\d+$", "", tag)].append((tag, cell))
        print("decoded", tag, f"objs={len(keep)}")

    for prefix, imgs in sorted(groups.items()):
        path = f"{outdir}/contact_{prefix}.png"
        contact_sheet(imgs, path)
        print("contact sheet:", path, "frames:", len(imgs))

if __name__ == "__main__":
    main()

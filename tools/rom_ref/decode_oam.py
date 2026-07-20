"""Reconstruct GBA object (sprite) layer from dumped OAM + OBJ-VRAM + OBJ-palette.

Produces, per frame: the full object layer (obj_all_*) and an isolated Link crop
(link_*), plus a contact sheet. No background, no chroma-key -- these are the
actual hardware sprite tiles composited on transparency.

Assumes 4bpp objects, 1D tile mapping (DISPCNT bit6 set) -- verified for Minish Cap.
"""
import glob, os, struct
import numpy as np
from PIL import Image, ImageDraw

OAMDIR = "tools/rom_ref/out/oam"
OUT = "tools/rom_ref/out/oam/decoded"
os.makedirs(OUT, exist_ok=True)

# shape/size -> (w,h) in pixels
SIZES = {
    0: {0: (8, 8),  1: (16, 16), 2: (32, 32), 3: (64, 64)},   # square
    1: {0: (16, 8), 1: (32, 8),  2: (32, 16), 3: (64, 32)},   # horizontal
    2: {0: (8, 16), 1: (8, 32),  2: (16, 32), 3: (32, 64)},   # vertical
}

# Link occupies the central horizontal band; HUD hearts sit far-left and the
# item/button UI far-right, so isolate by an X window rather than a tight radius.
LINK_X_MIN, LINK_X_MAX = 92, 140
LINK_Y_MAX = 140

def load_palette(path):
    raw = open(path, "rb").read()
    cols = struct.unpack("<256H", raw)
    pal = np.zeros((256, 4), np.uint8)
    for i, c in enumerate(cols):
        r = (c & 0x1F); g = (c >> 5) & 0x1F; b = (c >> 10) & 0x1F
        pal[i] = (r << 3 | r >> 2, g << 3 | g >> 2, b << 3 | b >> 2, 255)
    return pal

def decode_tile_4bpp(vram, tilenum):
    """Return 8x8 array of palette-nibble indices (0..15)."""
    off = tilenum * 32
    data = vram[off:off + 32]
    t = np.zeros((8, 8), np.uint8)
    for row in range(8):
        for k in range(4):
            byte = data[row * 4 + k]
            t[row, k * 2] = byte & 0x0F
            t[row, k * 2 + 1] = byte >> 4
    return t

def render_objects(oam, vram, pal, only_link=False):
    canvas = np.zeros((160, 240, 4), np.uint8)
    for i in range(128):
        a0, a1, a2 = struct.unpack_from("<HHH", oam, i * 8)
        affine = (a0 >> 8) & 1
        if not affine and ((a0 >> 9) & 1):
            continue  # hidden
        shape = (a0 >> 14) & 3
        colormode = (a0 >> 13) & 1  # 1 = 8bpp (unhandled; Link is 4bpp)
        y = a0 & 0xFF
        if y >= 160: y -= 256
        x = a1 & 0x1FF
        if x >= 400: x -= 512
        size = (a1 >> 14) & 3
        hflip = (a1 >> 12) & 1 if not affine else 0
        vflip = (a1 >> 13) & 1 if not affine else 0
        tile = a2 & 0x3FF
        palbank = (a2 >> 12) & 0xF
        w, h = SIZES[shape][size]
        # skip fully off-screen and 8bpp for this first pass
        if colormode == 1:
            continue
        cx, cy = x + w / 2, y + h / 2
        # Link's body objects are 16px+; HUD hearts and small UI are 8x8.
        is_link = (w >= 16 and LINK_X_MIN <= cx <= LINK_X_MAX and cy <= LINK_Y_MAX)
        if only_link and not is_link:
            continue
        tiles_w = w // 8
        sprite = np.zeros((h, w, 4), np.uint8)
        for ty in range(h // 8):
            for tx in range(tiles_w):
                tnum = (tile + ty * tiles_w + tx) & 0x3FF
                idx = decode_tile_4bpp(vram, tnum)
                block = np.zeros((8, 8, 4), np.uint8)
                for yy in range(8):
                    for xx in range(8):
                        n = idx[yy, xx]
                        if n != 0:
                            block[yy, xx] = pal[palbank * 16 + n]
                sprite[ty * 8:ty * 8 + 8, tx * 8:tx * 8 + 8] = block
        if hflip: sprite = sprite[:, ::-1]
        if vflip: sprite = sprite[::-1, :]
        # composite onto canvas with clipping
        for yy in range(h):
            py = y + yy
            if py < 0 or py >= 160: continue
            for xx in range(w):
                px = x + xx
                if px < 0 or px >= 240: continue
                if sprite[yy, xx, 3]:
                    canvas[py, px] = sprite[yy, xx]
    return canvas

def crop_nonempty(arr):
    ys, xs = np.where(arr[:, :, 3] > 0)
    if len(ys) == 0: return None
    return arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]

frames = sorted(glob.glob(f"{OAMDIR}/oam_dn_*.bin"))
link_imgs = []
for fp in frames:
    tag = os.path.basename(fp)[4:-4]  # dn_NN
    oam = open(fp, "rb").read()
    vram = open(f"{OAMDIR}/objvram_{tag}.bin", "rb").read()
    pal = load_palette(f"{OAMDIR}/objpal_{tag}.bin")
    allobj = render_objects(oam, vram, pal, only_link=False)
    Image.fromarray(allobj, "RGBA").save(f"{OUT}/obj_all_{tag}.png")
    link = render_objects(oam, vram, pal, only_link=True)
    crop = crop_nonempty(link)
    if crop is not None:
        Image.fromarray(crop, "RGBA").save(f"{OUT}/link_{tag}.png")
        link_imgs.append((tag, crop))
    print("decoded", tag, "link crop:", None if crop is None else crop.shape)

# contact sheet of isolated Link frames (dark bg so transparency reads)
if link_imgs:
    scale, cols, lab = 4, 6, 14
    mw = max(a.shape[1] for _, a in link_imgs) * scale
    mh = max(a.shape[0] for _, a in link_imgs) * scale
    cw, ch = mw + 8, mh + lab + 6
    rows = (len(link_imgs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cw, rows * ch), (40, 40, 40))
    d = ImageDraw.Draw(sheet)
    for i, (tag, arr) in enumerate(link_imgs):
        im = Image.fromarray(arr, "RGBA").resize(
            (arr.shape[1] * scale, arr.shape[0] * scale), Image.NEAREST)
        cellimg = Image.new("RGBA", (mw, mh), (60, 60, 60, 255))
        cellimg.alpha_composite(im, ((mw - im.width) // 2, (mh - im.height) // 2))
        r, c = divmod(i, cols)
        d.text((c * cw + 2, r * ch), tag, fill=(255, 255, 0))
        sheet.paste(cellimg.convert("RGB"), (c * cw + 4, r * ch + lab))
    sheet.save(f"{OUT}/link_contact.png")
    print("contact sheet:", f"{OUT}/link_contact.png", "frames:", len(link_imgs))

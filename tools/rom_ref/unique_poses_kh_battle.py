import glob, os, re
from collections import defaultdict
import numpy as np
from PIL import Image, ImageDraw

OUT = "tools/rom_ref/out/oam/decoded_kh_battle"

groups = defaultdict(list)
for fp in sorted(glob.glob(f"{OUT}/sora_*.png")):
    tag = os.path.basename(fp)[5:-4]
    groups[re.sub(r"_\d+$", "", tag)].append((tag, np.array(Image.open(fp))))

for prefix, frames in sorted(groups.items()):
    poses = []
    order = []
    for tag, arr in frames:
        for i, (t0, a0, n) in enumerate(poses):
            if arr.shape == a0.shape and np.array_equal(arr, a0):
                poses[i] = (t0, a0, n + 1)
                order.append(i)
                break
        else:
            order.append(len(poses))
            poses.append((tag, arr, 1))
    seq = "".join(f"{i:X}" for i in order)
    print(f"{prefix}: {len(poses)} poses, order={seq}")
    scale, lab = 4, 14
    mw = max(a.shape[1] for _, a, _ in poses) * scale
    mh = max(a.shape[0] for _, a, _ in poses) * scale
    cw, ch = mw + 8, mh + lab + 6
    sheet = Image.new("RGB", (len(poses) * cw, ch), (40, 40, 40))
    d = ImageDraw.Draw(sheet)
    for i, (tag, arr, n) in enumerate(poses):
        im = Image.fromarray(arr, "RGBA").resize(
            (arr.shape[1] * scale, arr.shape[0] * scale), Image.NEAREST)
        cell = Image.new("RGBA", (mw, mh), (60, 60, 60, 255))
        cell.alpha_composite(im, ((mw - im.width) // 2, (mh - im.height) // 2))
        d.text((i * cw + 2, 0), f"{i}:{tag} x{n}", fill=(255, 255, 0))
        sheet.paste(cell.convert("RGB"), (i * cw + 4, lab))
    sheet.save(f"{OUT}/unique_{prefix}.png")

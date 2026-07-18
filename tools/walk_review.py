"""Review sheet for the auto-detected walk animations: one row per character
showing idle_down + walk frames for each direction (side already flipped to
face right). Also prints the detected segment ids so AUTO_WALK_FIXES entries
can be written against them."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from prep_supplied_assets import (AUTO_WALK_CUSTOMERS, AUTO_WALK_FIXES,
                                  _facing_left, _filter_side_frames,
                                  _key_sheet, detect_walk_rows)
from slice_lib import load_rgba

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    rows_out = []
    for world, cfg in AUTO_WALK_CUSTOMERS.items():
        for name in cfg["names"]:
            path = ROOT / f"assets/franchises/{world}/raw/customers" / (cfg["pattern"] % name)
            if not path.exists():
                continue
            img = _key_sheet(load_rgba(path))
            rows = detect_walk_rows(img)
            fix = AUTO_WALK_FIXES.get((world, name), {})
            if fix and rows.get("segments"):
                segs = {s["id"]: s["frames"] for s in rows["segments"]}
                for key in ("down", "side", "up"):
                    if key in fix and fix[key] in segs:
                        rows[key] = segs[fix[key]]
                    elif key in fix and fix[key] < 0:
                        rows.pop(key, None)
                if "side_faces_left" in fix:
                    rows["side_faces_left"] = fix["side_faces_left"]
            segs = rows.get("segments", [])
            info = " ".join("%d:(sym%.2f fd%.2f n%d)" % (s["id"], s["sym"], s["fd"], len(s["frames"]))
                            for s in segs[:10])
            print(f"{world}/{name}: {info}")
            strip = []
            for key in ("down", "side", "up"):
                frames = rows.get(key, [])
                if key == "side" and frames:
                    frames = _filter_side_frames(frames)
                    if _facing_left(frames):
                        frames = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames]
                strip.append((key, frames[:5]))
            rows_out.append((f"{world}/{name}", strip))

    cell, gap = 72, 8
    max_frames = 15 + 2
    sheet = Image.new("RGBA", (140 + max_frames * (cell // 2 + gap), len(rows_out) * (cell + 14) + 10),
                      (35, 35, 45, 255))
    d = ImageDraw.Draw(sheet)
    for r, (label, strip) in enumerate(rows_out):
        y = 10 + r * (cell + 14)
        d.text((4, y + cell // 2), label, fill=(255, 255, 150, 255))
        x = 140
        for key, frames in strip:
            d.text((x, y - 2), key, fill=(150, 220, 255, 255))
            for f in frames:
                k = min((cell - 14) / max(1, f.height), (cell // 2) / max(1, f.width), 2.0)
                im = f.resize((max(1, int(f.width * k)), max(1, int(f.height * k))), Image.NEAREST)
                sheet.alpha_composite(im, (x, y + 10 + (cell - 14 - im.height)))
                x += im.width + 4
            x += gap * 2
    out = ROOT / "tools/out/walk_review.png"
    out.parent.mkdir(exist_ok=True)
    sheet.convert("RGB").save(out)
    print("->", out)


if __name__ == "__main__":
    main()

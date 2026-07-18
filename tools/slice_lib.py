"""Shared helpers for slicing supplied sprite sheets: chroma-key, island
detection (connected sprite regions), annotated contact sheets, and uniform
grid re-composition with manifest output."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


def load_rgba(path: str | Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def chroma_key(img: Image.Image, color: tuple[int, int, int], tol: int = 12) -> Image.Image:
    """Make every pixel within tol of color fully transparent."""
    a = np.array(img).astype(np.int16)
    mask = (
        (np.abs(a[..., 0] - color[0]) <= tol)
        & (np.abs(a[..., 1] - color[1]) <= tol)
        & (np.abs(a[..., 2] - color[2]) <= tol)
    )
    a[mask, 3] = 0
    return Image.fromarray(a.astype(np.uint8))


def find_islands(img: Image.Image, min_area: int = 30, merge_gap: int = 2) -> list[tuple[int, int, int, int]]:
    """Connected non-transparent regions as (x0, y0, x1, y1) boxes, sorted in
    reading order (row bands, then x). merge_gap dilates so nearby specks
    (detached hands, sparkles) join their sprite."""
    alpha = np.array(img)[..., 3] > 10
    if merge_gap > 0:
        pad = merge_gap
        dil = np.zeros_like(alpha)
        for dy in range(-pad, pad + 1):
            for dx in range(-pad, pad + 1):
                shifted = np.roll(alpha, (dy, dx), axis=(0, 1))
                if dy > 0:
                    shifted[:dy, :] = False
                elif dy < 0:
                    shifted[dy:, :] = False
                if dx > 0:
                    shifted[:, :dx] = False
                elif dx < 0:
                    shifted[:, dx:] = False
                dil |= shifted
    else:
        dil = alpha
    h, w = dil.shape
    labels = np.zeros((h, w), dtype=np.int32)
    boxes: list[list[int]] = []
    next_label = 0
    for sy in range(h):
        xs = np.nonzero(dil[sy] & (labels[sy] == 0))[0]
        for sx in xs:
            if labels[sy, sx]:
                continue
            next_label += 1
            stack = [(sy, sx)]
            labels[sy, sx] = next_label
            x0, y0, x1, y1 = sx, sy, sx, sy
            area = 0
            while stack:
                cy, cx = stack.pop()
                area += 1
                x0 = min(x0, cx); x1 = max(x1, cx)
                y0 = min(y0, cy); y1 = max(y1, cy)
                lo_y, hi_y = max(0, cy - 1), min(h - 1, cy + 1)
                lo_x, hi_x = max(0, cx - 1), min(w - 1, cx + 1)
                for ny in range(lo_y, hi_y + 1):
                    row = dil[ny]
                    lrow = labels[ny]
                    for nx in range(lo_x, hi_x + 1):
                        if row[nx] and not lrow[nx]:
                            lrow[nx] = next_label
                            stack.append((ny, nx))
            if area >= min_area:
                boxes.append([x0, y0, x1 + 1, y1 + 1])
    # reading order: cluster into row bands by vertical overlap
    boxes.sort(key=lambda b: b[1])
    bands: list[list[list[int]]] = []
    for b in boxes:
        placed = False
        for band in bands:
            by0 = min(x[1] for x in band)
            by1 = max(x[3] for x in band)
            if b[1] < by1 and b[3] > by0:
                band.append(b)
                placed = True
                break
        if not placed:
            bands.append([b])
    out: list[tuple[int, int, int, int]] = []
    for band in bands:
        band.sort(key=lambda b: b[0])
        out.extend(tuple(b) for b in band)
    return out


def contact_sheet(img: Image.Image, boxes: list[tuple[int, int, int, int]], out_path: str | Path, scale: int = 1) -> None:
    """Save the keyed sheet with numbered red boxes for frame picking."""
    base = img.copy()
    if scale > 1:
        base = base.resize((base.width * scale, base.height * scale), Image.NEAREST)
    draw = ImageDraw.Draw(base)
    for i, (x0, y0, x1, y1) in enumerate(boxes):
        draw.rectangle([x0 * scale, y0 * scale, x1 * scale - 1, y1 * scale - 1], outline=(255, 0, 0, 255))
        draw.text((x0 * scale + 1, y0 * scale + 1), str(i), fill=(255, 255, 0, 255))
    bg = Image.new("RGBA", base.size, (40, 40, 60, 255))
    bg.alpha_composite(base)
    bg.convert("RGB").save(out_path)


def compose_grid(
    img: Image.Image,
    boxes: list[tuple[int, int, int, int]],
    picks: dict[str, list[int]],
    cell: tuple[int, int],
    out_png: str | Path,
    out_manifest: str | Path,
    sheet_res_path: str,
    fps: dict[str, int] | None = None,
    loops: dict[str, bool] | None = None,
    anchor: str = "bottom",
    flip: dict[str, bool] | None = None,
) -> None:
    """Copy picked islands into a uniform grid sheet + manifest JSON.
    picks: anim_name -> [island indices]; negative index -i-1 = flipped island i.
    anchor 'bottom': feet aligned at a common baseline; 'center' for floaters."""
    fps = fps or {}
    loops = loops or {}
    order: list[tuple[str, list[int]]] = list(picks.items())
    total = sum(len(v) for _, v in order)
    cols = max(1, min(8, total))
    rows = (total + cols - 1) // cols
    cw, ch = cell
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    manifest_anims: dict[str, dict] = {}
    idx = 0
    for anim, frame_ids in order:
        frame_indices: list[int] = []
        for fid in frame_ids:
            flipped = fid < 0
            real = -fid - 1 if flipped else fid
            x0, y0, x1, y1 = boxes[real]
            crop = img.crop((x0, y0, x1, y1))
            if flipped:
                crop = crop.transpose(Image.FLIP_LEFT_RIGHT)
            # fit into the cell (downscale only if oversized)
            if crop.width > cw or crop.height > ch:
                ratio = min(cw / crop.width, ch / crop.height)
                crop = crop.resize((max(1, int(crop.width * ratio)), max(1, int(crop.height * ratio))), Image.NEAREST)
            cx = (idx % cols) * cw + (cw - crop.width) // 2
            if anchor == "bottom":
                cy = (idx // cols) * ch + (ch - crop.height) - 2
            else:
                cy = (idx // cols) * ch + (ch - crop.height) // 2
            sheet.alpha_composite(crop, (cx, cy))
            frame_indices.append(idx)
            idx += 1
        manifest_anims[anim] = {
            "frames": frame_indices,
            "fps": fps.get(anim, 7 if anim.startswith("walk") else 3),
            "loop": loops.get(anim, True),
        }
    Path(out_png).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_png)
    manifest = {
        "asset_id": Path(out_png).stem,
        "sheet": sheet_res_path,
        "native_scale": 1,
        "display_scale": 1,
        "pivot": [cw // 2, ch - 4],
        "grid": {"frame_width": cw, "frame_height": ch, "columns": cols, "rows": rows},
        "animations": manifest_anims,
    }
    Path(out_manifest).parent.mkdir(parents=True, exist_ok=True)
    Path(out_manifest).write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"  wrote {out_png} ({cols}x{rows} cells of {cw}x{ch}) + manifest")


def resize_rgba(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    """High-quality RGBA resize without dark edge halos: premultiply alpha,
    resize, then unpremultiply. Plain LANCZOS on straight alpha bleeds the
    transparent pixels' black RGB into edges."""
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    alpha = a[..., 3:4] / 255.0
    a[..., :3] *= alpha
    pre = Image.fromarray(a.astype(np.uint8))
    small = np.asarray(pre.resize(size, Image.LANCZOS)).astype(np.float32)
    out_alpha = small[..., 3:4]
    scale = np.where(out_alpha > 0, 255.0 / np.maximum(out_alpha, 1e-6), 0.0)
    small[..., :3] = np.clip(small[..., :3] * scale, 0, 255)
    return Image.fromarray(small.astype(np.uint8))


def save_island(img: Image.Image, box: tuple[int, int, int, int], out_path: str | Path, size: int | None = None) -> None:
    """Save one island as a standalone icon PNG (optionally fit into size^2)."""
    crop = img.crop(box)
    if size is not None and (crop.width > size or crop.height > size):
        ratio = min(size / crop.width, size / crop.height)
        crop = crop.resize((max(1, int(crop.width * ratio)), max(1, int(crop.height * ratio))), Image.NEAREST)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    crop.save(out_path)

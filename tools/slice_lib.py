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


def shave_sparse_edges(img: Image.Image, frac: float = 0.6, cols: bool = True) -> Image.Image:
    """Crop away edge rows (and optionally columns) that are mostly empty —
    leftover crumbs of baked shadows/outlines hugging a slice's border."""
    alpha = np.array(img)[..., 3] > 0
    t, b, l, r = 0, alpha.shape[0], 0, alpha.shape[1]
    while b - t > 2 and alpha[t, l:r].sum() < frac * (r - l):
        t += 1
    while b - t > 2 and alpha[b - 1, l:r].sum() < frac * (r - l):
        b -= 1
    if cols:
        while r - l > 2 and alpha[t:b, l].sum() < frac * (b - t):
            l += 1
        while r - l > 2 and alpha[t:b, r - 1].sum() < frac * (b - t):
            r -= 1
    return img.crop((l, t, r, b))


def flood_bg(img: Image.Image, is_bg) -> Image.Image:
    """Remove background connected to the image border: BFS from all border
    pixels through colors is_bg(rgb_int16_array) says are background-family.
    Interior pixels of those colors survive because the flood cannot cross
    the art's outlines — safer than a global chroma key for busy scenes."""
    from collections import deque
    a = np.array(img.convert("RGBA"))
    h, w = a.shape[:2]
    bg = is_bg(a[..., :3].astype(np.int16)) & (a[..., 3] > 0)
    bg |= a[..., 3] == 0  # already-transparent pixels carry the flood too
    seen = np.zeros((h, w), bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bg[y, x] and not seen[y, x]:
                seen[y, x] = True
                dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if bg[y, x] and not seen[y, x]:
                seen[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and bg[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                dq.append((ny, nx))
    a[seen] = 0
    return Image.fromarray(a)


def _label_components(alpha: np.ndarray) -> tuple[np.ndarray, dict[int, int]]:
    """8-connected component labels for a boolean mask; returns labels and
    label -> area."""
    h, w = alpha.shape
    labels = np.zeros((h, w), dtype=np.int32)
    areas: dict[int, int] = {}
    next_label = 0
    for sy in range(h):
        xs = np.nonzero(alpha[sy] & (labels[sy] == 0))[0]
        for sx in xs:
            if labels[sy, sx]:
                continue
            next_label += 1
            stack = [(sy, sx)]
            labels[sy, sx] = next_label
            area = 0
            while stack:
                cy, cx = stack.pop()
                area += 1
                for ny in range(max(0, cy - 1), min(h - 1, cy + 1) + 1):
                    row = alpha[ny]
                    lrow = labels[ny]
                    for nx in range(max(0, cx - 1), min(w - 1, cx + 1) + 1):
                        if row[nx] and not lrow[nx]:
                            lrow[nx] = next_label
                            stack.append((ny, nx))
            areas[next_label] = area
    return labels, areas


def largest_component(img: Image.Image, thresh: int = 10) -> Image.Image:
    """Zero out everything but the largest connected opaque region. Island
    detection's merge_gap dilation can pull detached shadow specks from
    neighboring sheet pieces into a slice; those read as gray smudges in-game."""
    a = np.array(img)
    labels, areas = _label_components(a[..., 3] > thresh)
    if not areas:
        return Image.fromarray(a)
    best_label = max(areas, key=lambda k: areas[k])
    a[labels != best_label] = 0
    return Image.fromarray(a)


def keep_components(img: Image.Image, min_area: int, thresh: int = 10) -> Image.Image:
    """Drop connected regions smaller than min_area but keep every larger one
    (for art with legitimate detached pieces, e.g. floating-island rubble)."""
    a = np.array(img)
    labels, areas = _label_components(a[..., 3] > thresh)
    small = {k for k, v in areas.items() if v < min_area}
    if small:
        a[np.isin(labels, list(small))] = 0
    return Image.fromarray(a)


def clean_alpha(img: Image.Image, lo: int = 40, hi: int = 216) -> Image.Image:
    """Snap ghost alpha (<lo) to 0 and near-opaque (>=hi) to 255, then trim to
    the visible content. Kills the faint resize halo rows that render as light
    gray fringes over bright backgrounds in-game."""
    a = np.array(img)
    alpha = a[..., 3]
    a[alpha < lo] = 0
    hi_mask = a[..., 3] >= hi
    a[..., 3][hi_mask] = 255
    bbox = Image.fromarray(a[..., 3]).getbbox()
    out = Image.fromarray(a)
    return out.crop(bbox) if bbox is not None else out


def save_island(img: Image.Image, box: tuple[int, int, int, int], out_path: str | Path, size: int | None = None) -> None:
    """Save one island as a standalone icon PNG (optionally fit into size^2)."""
    crop = img.crop(box)
    if size is not None and (crop.width > size or crop.height > size):
        ratio = min(size / crop.width, size / crop.height)
        crop = crop.resize((max(1, int(crop.width * ratio)), max(1, int(crop.height * ratio))), Image.NEAREST)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    crop.save(out_path)

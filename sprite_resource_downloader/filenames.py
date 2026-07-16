from __future__ import annotations

import re
from pathlib import Path

WINDOWS_INVALID_CHARS = '<>:"/\\|?*'
RESERVED_NAMES = {
    "CON",
    "PRN",
    "AUX",
    "NUL",
    *(f"COM{i}" for i in range(1, 10)),
    *(f"LPT{i}" for i in range(1, 10)),
}


def safe_name(value: str | None, *, fallback: str = "untitled", max_length: int = 120) -> str:
    """Return a Windows-safe path segment."""
    text = (value or "").strip()
    text = re.sub(f"[{re.escape(WINDOWS_INVALID_CHARS)}]", "_", text)
    text = re.sub(r"\s+", " ", text).strip(" .")
    text = re.sub(r"_+", "_", text)
    if not text:
        text = fallback

    stem, dot, suffix = text.partition(".")
    if stem.upper() in RESERVED_NAMES:
        stem = f"{stem}_"
        text = stem + (dot + suffix if dot else "")

    if len(text) > max_length:
        text = text[:max_length].rstrip(" .")
    return text or fallback


def safe_extension(*candidates: str | None, fallback: str = ".bin") -> str:
    for candidate in candidates:
        if not candidate:
            continue
        suffix = Path(candidate).suffix
        if suffix and re.fullmatch(r"\.[A-Za-z0-9]{1,12}", suffix):
            return suffix.lower()
        cleaned = candidate.strip().lower().lstrip(".")
        if re.fullmatch(r"[a-z0-9]{1,12}", cleaned):
            return f".{cleaned}"
    return fallback


def snake_case(value: str | None, *, fallback: str = "asset", max_length: int = 100) -> str:
    text = safe_name(value, fallback=fallback, max_length=max_length)
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "_", text)
    text = re.sub(r"_+", "_", text).strip("_")
    return text[:max_length].strip("_") or fallback


def asset_filename_stem(asset_name: str, *, prefix: str, suffix: str = "") -> str:
    parts = [snake_case(prefix, fallback="asset"), snake_case(asset_name, fallback="sheet")]
    if suffix:
        parts.append(snake_case(suffix, fallback=""))
    return "_".join(part for part in parts if part)


def reserve_destination(
    directory: Path,
    asset_name: str,
    extension: str,
    *,
    asset_id: str | None = None,
    existing_names: set[str] | None = None,
) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    safe_stem = safe_name(asset_name, fallback=f"asset_{asset_id or 'unknown'}", max_length=100)
    ext = extension if extension.startswith(".") else f".{extension}"
    candidate = directory / f"{safe_stem}{ext.lower()}"
    names = existing_names if existing_names is not None else set()

    if candidate.name.lower() in names or candidate.exists():
        suffix = safe_name(asset_id or "duplicate", fallback="duplicate", max_length=32)
        candidate = directory / f"{safe_stem}_{suffix}{ext.lower()}"

    names.add(candidate.name.lower())
    return candidate

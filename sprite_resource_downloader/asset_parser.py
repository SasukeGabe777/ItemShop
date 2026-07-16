from __future__ import annotations

import re
from dataclasses import asdict, dataclass
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from .game_parser import asset_id_from_url


@dataclass
class AssetMetadata:
    asset_name: str
    asset_id: str
    asset_page_url: str
    game: str = ""
    platform: str = ""
    section: str = ""
    uploaded_by: str = ""
    contributors: list[str] | None = None
    submitted: str = ""
    format: str = ""
    size: str = ""
    source_url: str = ""
    local_file: str = ""
    downloaded_at: str = ""

    def to_manifest_record(self) -> dict[str, object]:
        data = asdict(self)
        data["contributors"] = self.contributors or []
        return data

    def to_credits_row(self) -> dict[str, str]:
        return {
            "game": self.game,
            "platform": self.platform,
            "section": self.section,
            "asset_name": self.asset_name,
            "asset_id": self.asset_id,
            "asset_page_url": self.asset_page_url,
            "uploaded_by": self.uploaded_by,
            "contributors": "; ".join(self.contributors or []),
            "submitted": self.submitted,
            "format": self.format,
            "size": self.size,
            "local_file": self.local_file,
            "downloaded_at": self.downloaded_at,
        }


def parse_asset_page(html: str, page_url: str) -> AssetMetadata:
    soup = BeautifulSoup(html, "html.parser")
    labels = _label_map(soup)
    asset_id = asset_id_from_url(page_url) or labels.get("asset id", "")
    title = labels.get("name") or _first_heading(soup) or f"asset_{asset_id or 'unknown'}"
    contributors = _split_names(labels.get("contributors", ""))
    uploaded_by = labels.get("uploaded by", "") or labels.get("ripped by", "")

    return AssetMetadata(
        asset_name=title,
        asset_id=asset_id,
        asset_page_url=page_url,
        game=labels.get("game", ""),
        platform=labels.get("platform", "")
        or labels.get("console", "")
        or labels.get("system", ""),
        section=labels.get("section", ""),
        uploaded_by=uploaded_by,
        contributors=contributors,
        submitted=labels.get("submitted", "") or labels.get("date submitted", ""),
        format=labels.get("format", ""),
        size=labels.get("size", "") or labels.get("file size", ""),
        source_url=_source_url(soup, page_url),
    )


def _label_map(soup: BeautifulSoup) -> dict[str, str]:
    values: dict[str, str] = {}

    for row in soup.find_all("tr"):
        cells = row.find_all(["th", "td"], recursive=False)
        if len(cells) >= 2:
            _put_label(
                values, cells[0].get_text(" ", strip=True), cells[1].get_text(" ", strip=True)
            )

    for dt in soup.find_all("dt"):
        dd = dt.find_next_sibling("dd")
        if dd:
            _put_label(values, dt.get_text(" ", strip=True), dd.get_text(" ", strip=True))

    for node in soup.find_all(["li", "p", "div"]):
        text = node.get_text(" ", strip=True)
        if ":" not in text or len(text) > 180:
            continue
        key, value = text.split(":", 1)
        if 2 <= len(key) <= 32:
            _put_label(values, key, value)

    return values


def _put_label(values: dict[str, str], key: str, value: str) -> None:
    normalized = re.sub(r"\s+", " ", key).strip(" :").lower()
    cleaned = re.sub(r"\s+", " ", value).strip()
    if normalized and cleaned and normalized not in values:
        values[normalized] = cleaned


def _first_heading(soup: BeautifulSoup) -> str | None:
    for selector in ("h1", "main h1", "h2"):
        node = soup.select_one(selector)
        if node:
            text = node.get_text(" ", strip=True)
            if text:
                return text
    return None


def _split_names(text: str) -> list[str]:
    if not text:
        return []
    names = re.split(r"\s*(?:,|;|\band\b)\s*", text)
    return [name.strip() for name in names if name.strip()]


def _source_url(soup: BeautifulSoup, page_url: str) -> str:
    for selector in ("a[download][href]", 'a[href*="/media/assets/"]', 'a[href*="/download/"]'):
        node = soup.select_one(selector)
        if node:
            return urljoin(page_url, str(node.get("href")))

    for img in soup.find_all("img", src=True):
        src = str(img.get("src"))
        if "/media/assets/" in src and "thumb" not in src.lower():
            return urljoin(page_url, src)

    return ""


def looks_restricted(text: str) -> bool:
    lowered = text.lower()
    restricted_markers = [
        "captcha",
        "access denied",
        "checking your browser",
        "cloudflare",
        "forbidden",
        "login required",
        "sign in to continue",
    ]
    return any(marker in lowered for marker in restricted_markers)


def write_debug_snapshot(path, html: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(html, encoding="utf-8")

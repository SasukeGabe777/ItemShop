from __future__ import annotations

import re
from dataclasses import dataclass
from urllib.parse import urljoin, urlparse, urlunparse

from bs4 import BeautifulSoup, Tag

ALLOWED_HOSTS = {"www.spriters-resource.com", "spriters-resource.com"}
ASSET_SEGMENTS = {"sheet", "asset", "spritesheet"}
ASSET_URL_RE = re.compile(r"/(?P<kind>sheet|asset|spritesheet)/(?P<asset_id>\d+)/?", re.I)


@dataclass(frozen=True)
class AssetLink:
    url: str
    asset_id: str
    name: str | None = None
    section: str | None = None


@dataclass(frozen=True)
class GameInfo:
    url: str
    title: str
    platform: str
    asset_count: int | None
    sections: list[str]
    assets: list[AssetLink]


def validate_game_url(url: str) -> str:
    parsed = urlparse(url)
    if parsed.scheme != "https":
        raise ValueError("URL must use HTTPS.")
    if parsed.netloc.lower() not in ALLOWED_HOSTS:
        raise ValueError("URL must belong to spriters-resource.com.")

    parts = [part for part in parsed.path.split("/") if part]
    if len(parts) < 2:
        raise ValueError("URL does not look like a game page.")
    if any(part.lower() in ASSET_SEGMENTS or part.lower() == "media" for part in parts):
        raise ValueError("URL appears to be an individual asset or media page.")

    normalized = parsed._replace(fragment="")
    return urlunparse(normalized)


def asset_id_from_url(url: str) -> str | None:
    match = ASSET_URL_RE.search(urlparse(url).path)
    return match.group("asset_id") if match else None


def parse_game_page(html: str, page_url: str) -> GameInfo:
    soup = BeautifulSoup(html, "html.parser")
    title = _first_text(soup, ["h1", "main h1"]) or _document_title(soup) or "Unknown Game"
    platform = (
        _platform_from_url(page_url) or _platform_from_breadcrumbs(soup) or "Unknown Platform"
    )
    assets = _discover_asset_links(soup, page_url)
    sections = []
    for asset in assets:
        section = asset.section or "Uncategorized"
        if section not in sections:
            sections.append(section)
    asset_count = _asset_count(soup) or (len(assets) if assets else None)
    return GameInfo(
        url=page_url,
        title=title,
        platform=platform,
        asset_count=asset_count,
        sections=sections,
        assets=assets,
    )


def _discover_asset_links(soup: BeautifulSoup, page_url: str) -> list[AssetLink]:
    seen: set[str] = set()
    assets: list[AssetLink] = []
    game_path = urlparse(page_url).path.rstrip("/") + "/"
    for anchor in soup.find_all("a", href=True):
        href = str(anchor.get("href"))
        absolute = _canonical_url(urljoin(page_url, href))
        if not urlparse(absolute).path.startswith(game_path):
            continue
        asset_id = asset_id_from_url(absolute)
        if not asset_id or absolute in seen:
            continue
        seen.add(absolute)
        assets.append(
            AssetLink(
                url=absolute,
                asset_id=asset_id,
                name=anchor.get_text(" ", strip=True) or None,
                section=_nearest_section(anchor),
            )
        )
    return assets


def _canonical_url(url: str) -> str:
    parsed = urlparse(url)
    return urlunparse(parsed._replace(fragment="", query=""))


def _nearest_section(anchor: Tag) -> str | None:
    previous_section = anchor.find_previous(class_="section")
    if previous_section:
        section = _clean_section_text(previous_section.get_text("\n", strip=True))
        if section:
            return section

    current: Tag | None = anchor
    while current is not None:
        previous = current.find_previous(["h2", "h3", "h4"])
        if previous:
            text = previous.get_text(" ", strip=True)
            if text:
                return text
        current = current.parent if isinstance(current.parent, Tag) else None
    return None


def _clean_section_text(text: str) -> str | None:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    ignored = {"arrow_drop_down", "arrow_right", "expand_more", "expand_less"}
    candidates = [
        line for line in lines if line not in ignored and not re.fullmatch(r"\[\d+\]|\d+", line)
    ]
    return candidates[-1] if candidates else None


def _first_text(soup: BeautifulSoup, selectors: list[str]) -> str | None:
    for selector in selectors:
        node = soup.select_one(selector)
        if node:
            text = node.get_text(" ", strip=True)
            if text:
                return text
    return None


def _document_title(soup: BeautifulSoup) -> str | None:
    if not soup.title:
        return None
    return soup.title.get_text(" ", strip=True).split("-")[0].strip() or None


def _platform_from_breadcrumbs(soup: BeautifulSoup) -> str | None:
    candidates = soup.select("nav a, .breadcrumbs a, #breadcrumb a, a")
    for node in candidates:
        href = str(node.get("href", ""))
        text = node.get_text(" ", strip=True)
        if text and href.count("/") <= 2 and href not in {"/", "#"}:
            return text
    return None


def _platform_from_url(url: str) -> str | None:
    parts = [part for part in urlparse(url).path.split("/") if part]
    if not parts:
        return None
    platform_names = {
        "game_boy": "Game Boy",
        "game_boy_advance": "Game Boy Advance",
        "nintendo_ds": "Nintendo DS",
        "super_nintendo": "Super Nintendo",
        "snes": "Super Nintendo",
        "nes": "NES",
        "pc_computer": "PC / Computer",
    }
    return platform_names.get(parts[0], parts[0].replace("_", " ").title())


def _asset_count(soup: BeautifulSoup) -> int | None:
    text = soup.get_text(" ", strip=True)
    match = re.search(r"\b(\d{1,5})\s+(?:sheets?|sprites?|assets?)\b", text, re.I)
    return int(match.group(1)) if match else None

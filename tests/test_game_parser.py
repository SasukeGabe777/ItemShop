from pathlib import Path

import pytest

from sprite_resource_downloader.game_parser import parse_game_page, validate_game_url


FIXTURES = Path(__file__).parent / "fixtures"


def test_validate_game_url_accepts_game_page() -> None:
    assert validate_game_url("https://www.spriters-resource.com/game_boy_advance/khcom/")


@pytest.mark.parametrize(
    "url",
    [
        "http://www.spriters-resource.com/game_boy_advance/khcom/",
        "https://example.com/game_boy_advance/khcom/",
        "https://www.spriters-resource.com/game_boy_advance/khcom/sheet/1029/",
    ],
)
def test_validate_game_url_rejects_invalid_pages(url: str) -> None:
    with pytest.raises(ValueError):
        validate_game_url(url)


def test_game_page_asset_discovery_deduplicates_and_extracts_sections() -> None:
    html = (FIXTURES / "game_page.html").read_text(encoding="utf-8")
    info = parse_game_page(html, "https://www.spriters-resource.com/game_boy_advance/khcom/")
    assert info.title == "Kingdom Hearts: Chain of Memories"
    assert info.platform == "Game Boy Advance"
    assert info.asset_count == 3
    assert [asset.asset_id for asset in info.assets] == ["1029", "1030", "1031", "1032"]
    assert info.sections == ["Playable Characters", "Enemies", "Bosses"]
    assert info.assets[2].section == "Enemies"
    assert info.assets[3].section == "Bosses"

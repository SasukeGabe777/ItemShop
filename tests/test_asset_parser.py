from pathlib import Path

from sprite_resource_downloader.asset_parser import looks_restricted, parse_asset_page


FIXTURES = Path(__file__).parent / "fixtures"


def test_asset_metadata_extraction() -> None:
    html = (FIXTURES / "asset_page.html").read_text(encoding="utf-8")
    metadata = parse_asset_page(
        html,
        "https://www.spriters-resource.com/game_boy_advance/khcom/sheet/1029/",
    )
    assert metadata.asset_name == "Sora Battle"
    assert metadata.asset_id == "1029"
    assert metadata.game == "Kingdom Hearts: Chain of Memories"
    assert metadata.platform == "Game Boy Advance"
    assert metadata.section == "Playable Characters"
    assert metadata.uploaded_by == "ExampleUser"
    assert metadata.contributors == ["Alice", "Bob", "Carol"]
    assert metadata.submitted == "Jan 1, 2020"
    assert metadata.format == "PNG"
    assert metadata.size == "32 KB"
    assert metadata.source_url.endswith("/media/assets/1029/sora.png")


def test_restricted_detection() -> None:
    assert looks_restricted("Please complete the CAPTCHA to continue")

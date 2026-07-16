import logging
from pathlib import Path

from sprite_resource_downloader.downloader import DownloaderConfig, SpriteResourceDownloader
from sprite_resource_downloader.game_parser import AssetLink, GameInfo
from sprite_resource_downloader.project_layout import infer_franchise, resolve_target


def test_infer_kingdom_hearts_project_target() -> None:
    game = GameInfo(
        url="https://www.spriters-resource.com/game_boy_advance/khcom/",
        title="Kingdom Hearts: Chain of Memories",
        platform="Game Boy Advance",
        asset_count=None,
        sections=[],
        assets=[],
    )
    assert infer_franchise(game) == "kingdom_hearts"
    target = resolve_target(
        game,
        output=None,
        project_root=Path("."),
        franchise=None,
        filename_prefix=None,
        filename_suffix=None,
    )
    assert target.directory == Path("assets/franchises/kingdom_hearts/raw")
    assert target.prefix == "kh"
    assert target.suffix == "gba"


def test_asset_name_filter_matches_substrings() -> None:
    game = GameInfo(
        url="https://www.spriters-resource.com/game_boy_advance/khcom/",
        title="Kingdom Hearts: Chain of Memories",
        platform="Game Boy Advance",
        asset_count=None,
        sections=["Enemies"],
        assets=[
            AssetLink("https://example.test/1", "1", "Sora", "Playable Characters"),
            AssetLink("https://example.test/2", "2", "Shadow", "Enemies"),
            AssetLink("https://example.test/3", "3", "Background", "Backgrounds"),
        ],
    )
    config = DownloaderConfig(
        game_url=game.url,
        output=None,
        include_assets=["sha"],
        exclude_sections=["Backgrounds"],
    )
    downloader = SpriteResourceDownloader(config, logger=logging.getLogger("test"))
    assert [asset.name for asset in downloader._filtered_assets(game)] == ["Shadow"]

from pathlib import Path

from sprite_resource_downloader.asset_parser import AssetMetadata
from sprite_resource_downloader.manifest import ManifestWriter, ProjectCreditsWriter
from sprite_resource_downloader.rate_limit import DelayPolicy, backoff_seconds
from sprite_resource_downloader.state import DownloadState


def test_manifest_updates_and_failed_downloads(tmp_path: Path) -> None:
    writer = ManifestWriter(tmp_path)
    metadata = AssetMetadata(
        asset_name="Sora",
        asset_id="1029",
        asset_page_url="https://www.spriters-resource.com/game_boy_advance/khcom/sheet/1029/",
        game="Kingdom Hearts",
        platform="Game Boy Advance",
        section="Playable Characters",
        local_file="Playable Characters/Sora.png",
    )
    writer.upsert(metadata)
    writer.write_failed({"1030": {"reason": "missing", "url": "https://example.test"}})
    assert writer.manifest_path.exists()
    assert "Sora" in writer.credits_path.read_text(encoding="utf-8")
    assert "missing" in writer.failed_path.read_text(encoding="utf-8")


def test_project_credits_upsert_uses_filename_asset_id(tmp_path: Path) -> None:
    path = tmp_path / "credits" / "ASSET_CREDITS.csv"
    writer = ProjectCreditsWriter(path)
    metadata = AssetMetadata(
        asset_name="Sora",
        asset_id="kh_sora_gba",
        asset_page_url="https://www.spriters-resource.com/game_boy_advance/khcom/sheet/1029/",
        game="Kingdom Hearts: Chain of Memories",
        platform="Game Boy Advance",
        section="Playable Characters",
        uploaded_by="ExampleUser",
        contributors=["Alice"],
    )
    writer.upsert(metadata, Path("assets/franchises/kingdom_hearts/raw/kh_sora_gba.png"))
    text = path.read_text(encoding="utf-8")
    assert "kh_sora_gba" in text
    assert "ExampleUser; Alice" in text
    assert "assets/franchises/kingdom_hearts/raw/kh_sora_gba.png" in text


def test_resume_state(tmp_path: Path) -> None:
    state = DownloadState.load(tmp_path / ".download_state.json")
    state.mark_completed("1029", {"local_file": "Sora.png"})
    loaded = DownloadState.load(tmp_path / ".download_state.json")
    assert loaded.is_completed("1029")
    loaded.mark_failed("1030", "boom", "https://example.test")
    assert "1030" in loaded.failed


def test_rate_limit_clamps_and_backoff() -> None:
    policy = DelayPolicy(0.1, 0.2)
    assert policy.min_delay == 2.0
    assert policy.max_delay == 2.0
    assert backoff_seconds(1) == 8.0
    assert backoff_seconds(3) == 32.0

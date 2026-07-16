import os

import pytest

from sprite_resource_downloader.cli import main


@pytest.mark.live
@pytest.mark.skipif(
    os.environ.get("SPRITE_RESOURCE_LIVE_TEST") != "1",
    reason="Set SPRITE_RESOURCE_LIVE_TEST=1 to run the optional live test.",
)
def test_live_dry_run() -> None:
    assert (
        main(
            [
                "https://www.spriters-resource.com/game_boy_advance/khcom/",
                "--dry-run",
                "--headless",
                "--max-assets",
                "1",
                "--yes",
            ]
        )
        == 0
    )

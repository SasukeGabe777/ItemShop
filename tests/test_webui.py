from sprite_resource_downloader.webui import build_command, split_terms


def test_split_terms_accepts_newlines_and_commas() -> None:
    assert split_terms("Sora, Shadow\nSoldier") == ["Sora", "Shadow", "Soldier"]


def test_build_command_includes_repeated_filters() -> None:
    command = build_command(
        {
            "game_url": "https://www.spriters-resource.com/game_boy_advance/khcom/",
            "mode": "dry-run",
            "franchise": "kingdom_hearts",
            "include_assets": "Sora\nShadow",
            "exclude_sections": "Backgrounds",
            "max_assets": "2",
            "headed": False,
            "resume": True,
        }
    )
    assert command[1:4] == [
        "-m",
        "sprite_resource_downloader",
        "https://www.spriters-resource.com/game_boy_advance/khcom/",
    ]
    assert "--dry-run" in command
    assert "--headless" in command
    assert command.count("--include-asset") == 2
    assert command.count("--exclude-section") == 1
    assert "--resume" in command

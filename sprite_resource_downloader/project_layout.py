from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .game_parser import GameInfo


@dataclass(frozen=True)
class FranchiseTarget:
    franchise: str
    directory: Path
    prefix: str
    suffix: str = ""
    metadata_directory: Path | None = None


FRANCHISE_TARGETS = {
    "kingdom_hearts": FranchiseTarget(
        franchise="kingdom_hearts",
        directory=Path("assets/franchises/kingdom_hearts/raw"),
        prefix="kh",
        suffix="gba",
        metadata_directory=Path("credits/sprite_resource_downloader/kingdom_hearts"),
    ),
    "mario": FranchiseTarget(
        "mario",
        Path("assets/franchises/mario/raw"),
        "mario",
        metadata_directory=Path("credits/sprite_resource_downloader/mario"),
    ),
    "final_fantasy": FranchiseTarget(
        "final_fantasy",
        Path("assets/franchises/final_fantasy/raw"),
        "ff",
        metadata_directory=Path("credits/sprite_resource_downloader/final_fantasy"),
    ),
    "zelda": FranchiseTarget(
        "zelda",
        Path("assets/franchises/zelda/raw"),
        "zelda",
        metadata_directory=Path("credits/sprite_resource_downloader/zelda"),
    ),
    "naruto": FranchiseTarget(
        "naruto",
        Path("assets/franchises/naruto/raw"),
        "naruto",
        metadata_directory=Path("credits/sprite_resource_downloader/naruto"),
    ),
    "dragon_ball": FranchiseTarget(
        "dragon_ball",
        Path("assets/franchises/dragon_ball/raw"),
        "dbz",
        metadata_directory=Path("credits/sprite_resource_downloader/dragon_ball"),
    ),
    "pokemon": FranchiseTarget(
        "pokemon",
        Path("assets/franchises/pokemon/raw"),
        "pokemon",
        metadata_directory=Path("credits/sprite_resource_downloader/pokemon"),
    ),
}


def infer_franchise(game: GameInfo) -> str | None:
    haystack = f"{game.title} {game.platform} {game.url}".casefold()
    checks = [
        ("kingdom_hearts", ("kingdom hearts", "khcom", "/kh")),
        ("mario", ("mario", "superstar saga", "super mario")),
        ("final_fantasy", ("final fantasy", "fftactics", "tactics advance", "/ff")),
        ("zelda", ("zelda", "minish cap")),
        ("naruto", ("naruto", "ninja council")),
        ("dragon_ball", ("dragon ball", "dbz", "buu", "legacy of goku")),
        ("pokemon", ("pokemon", "firered", "leafgreen", "emerald")),
    ]
    for franchise, markers in checks:
        if any(marker in haystack for marker in markers):
            return franchise
    return None


def resolve_target(
    game: GameInfo,
    *,
    output: Path | None,
    project_root: Path,
    franchise: str | None,
    filename_prefix: str | None,
    filename_suffix: str | None,
) -> FranchiseTarget:
    if output is not None:
        prefix = filename_prefix or "sprite"
        return FranchiseTarget(
            franchise or "custom",
            output,
            prefix,
            filename_suffix or "",
            metadata_directory=output,
        )

    selected = franchise or infer_franchise(game)
    if selected not in FRANCHISE_TARGETS:
        raise ValueError(
            "Could not infer franchise from the game page. "
            "Pass --franchise or --output to choose a destination."
        )
    target = FRANCHISE_TARGETS[selected]
    return FranchiseTarget(
        target.franchise,
        project_root / target.directory,
        filename_prefix or target.prefix,
        target.suffix if filename_suffix is None else filename_suffix,
        project_root / (target.metadata_directory or target.directory),
    )

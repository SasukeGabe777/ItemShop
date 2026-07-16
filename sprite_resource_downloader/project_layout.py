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


FRANCHISE_TARGETS = {
    "kingdom_hearts": FranchiseTarget(
        franchise="kingdom_hearts",
        directory=Path("assets/franchises/kingdom_hearts/raw"),
        prefix="kh",
        suffix="gba",
    ),
    "mario": FranchiseTarget("mario", Path("assets/franchises/mario/raw"), "mario"),
    "final_fantasy": FranchiseTarget(
        "final_fantasy",
        Path("assets/franchises/final_fantasy/raw"),
        "ff",
    ),
    "zelda": FranchiseTarget("zelda", Path("assets/franchises/zelda/raw"), "zelda"),
    "naruto": FranchiseTarget("naruto", Path("assets/franchises/naruto/raw"), "naruto"),
    "dragon_ball": FranchiseTarget(
        "dragon_ball",
        Path("assets/franchises/dragon_ball/raw"),
        "dbz",
    ),
    "pokemon": FranchiseTarget("pokemon", Path("assets/franchises/pokemon/raw"), "pokemon"),
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
        return FranchiseTarget(franchise or "custom", output, prefix, filename_suffix or "")

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
    )

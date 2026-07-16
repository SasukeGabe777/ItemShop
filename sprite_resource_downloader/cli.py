from __future__ import annotations

import argparse
from pathlib import Path

from .downloader import DownloaderConfig, SpriteResourceDownloader, StopDownload
from .game_parser import validate_game_url
from .logging_config import configure_logging
from .project_layout import FRANCHISE_TARGETS


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="sprite_resource_downloader")
    parser.add_argument("game_url", help="The Spriters Resource game page URL.")
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Override destination. By default the tool writes to assets/franchises/<franchise>/raw/.",
    )
    parser.add_argument("--project-root", type=Path, default=Path("."))
    parser.add_argument("--franchise", choices=sorted(FRANCHISE_TARGETS))
    parser.add_argument("--filename-prefix")
    parser.add_argument("--filename-suffix")
    parser.add_argument("--project-credits", type=Path, default=Path("credits/ASSET_CREDITS.csv"))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--yes", action="store_true")
    parser.add_argument("--headed", dest="headed", action="store_true", default=True)
    parser.add_argument("--headless", dest="headed", action="store_false")
    parser.add_argument("--max-assets", type=int)
    parser.add_argument("--include-section", action="append", default=[])
    parser.add_argument("--exclude-section", action="append", default=[])
    parser.add_argument("--include-asset", action="append", default=[])
    parser.add_argument("--exclude-asset", action="append", default=[])
    parser.add_argument("--min-delay", type=float, default=4.0)
    parser.add_argument("--max-delay", type=float, default=8.0)
    parser.add_argument("--verbose", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        game_url = validate_game_url(args.game_url)
    except ValueError as exc:
        raise SystemExit(f"Invalid URL: {exc}") from exc

    log_path = (args.output or args.project_root) / "download.log"
    logger = configure_logging(log_path, verbose=args.verbose)
    config = DownloaderConfig(
        game_url=game_url,
        output=args.output,
        project_root=args.project_root,
        franchise=args.franchise,
        filename_prefix=args.filename_prefix,
        filename_suffix=args.filename_suffix,
        project_credits=args.project_credits,
        dry_run=args.dry_run,
        resume=args.resume,
        yes=args.yes,
        headed=args.headed,
        max_assets=args.max_assets,
        include_sections=args.include_section,
        exclude_sections=args.exclude_section,
        include_assets=args.include_asset,
        exclude_assets=args.exclude_asset,
        min_delay=args.min_delay,
        max_delay=args.max_delay,
        verbose=args.verbose,
    )
    try:
        return SpriteResourceDownloader(config, logger).run()
    except StopDownload as exc:
        logger.error("%s", exc)
        return 2

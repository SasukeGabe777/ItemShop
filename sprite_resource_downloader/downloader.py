from __future__ import annotations

import logging
import re
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import urlparse

from playwright.sync_api import Page, TimeoutError as PlaywrightTimeoutError

from .asset_parser import AssetMetadata, looks_restricted, parse_asset_page, write_debug_snapshot
from .browser import chromium_page
from .filenames import asset_filename_stem, reserve_destination, safe_extension
from .game_parser import AssetLink, GameInfo, parse_game_page
from .logging_config import add_file_log
from .manifest import ManifestWriter, ProjectCreditsWriter
from .project_layout import FranchiseTarget, resolve_target
from .rate_limit import ACCESS_STOP_STATUSES, TRANSIENT_HTTP_STATUSES, DelayPolicy, backoff_seconds
from .state import DownloadState


class StopDownload(Exception):
    pass


@dataclass
class DownloaderConfig:
    game_url: str
    output: Path | None
    project_root: Path = Path(".")
    franchise: str | None = None
    filename_prefix: str | None = None
    filename_suffix: str | None = None
    project_credits: Path = Path("credits/ASSET_CREDITS.csv")
    dry_run: bool = False
    resume: bool = False
    yes: bool = False
    headed: bool = True
    max_assets: int | None = None
    include_sections: list[str] | None = None
    exclude_sections: list[str] | None = None
    include_assets: list[str] | None = None
    exclude_assets: list[str] | None = None
    min_delay: float = 4.0
    max_delay: float = 8.0
    verbose: bool = False


class SpriteResourceDownloader:
    def __init__(self, config: DownloaderConfig, logger: logging.Logger) -> None:
        self.config = config
        self.logger = logger
        self.delay = DelayPolicy(config.min_delay, config.max_delay)
        self.transient_failures = 0

    def run(self) -> int:
        with chromium_page(headed=self.config.headed) as (_, _, page):
            self.logger.info("Opening game page: %s", self.config.game_url)
            self._goto_with_retries(page, self.config.game_url)
            html = page.content()
            game = parse_game_page(html, self.config.game_url)
            target = resolve_target(
                game,
                output=self.config.output,
                project_root=self.config.project_root,
                franchise=self.config.franchise,
                filename_prefix=self.config.filename_prefix,
                filename_suffix=self.config.filename_suffix,
            )
            metadata_root = target.metadata_directory or target.directory
            add_file_log(self.logger, metadata_root / "download.log")
            assets = self._filtered_assets(game)
            self._print_summary(game, assets, target)

            if self.config.dry_run:
                self.logger.info("Dry run only; no assets downloaded.")
                return 0
            if not self.config.yes and not self._confirm():
                self.logger.info("Cancelled before downloading.")
                return 1

            game_root = target.directory
            manifest = ManifestWriter(metadata_root)
            project_credits = ProjectCreditsWriter(
                self.config.project_root / self.config.project_credits
            )
            manifest.load_existing()
            state = DownloadState.load(metadata_root / ".download_state.json")
            if not self.config.resume and state.completed:
                self.logger.info("Existing state found; completed assets will still be skipped.")

            existing_names: dict[str, set[str]] = {}
            for index, asset in enumerate(assets, start=1):
                if state.is_completed(asset.asset_id):
                    self.logger.info(
                        "[%s/%s] Skipping completed asset %s", index, len(assets), asset.asset_id
                    )
                    continue
                if index > 1:
                    slept = self.delay.sleep_between_requests()
                    self.logger.debug("Waited %.2f seconds before next request.", slept)

                try:
                    metadata = self._process_asset(
                        page,
                        game,
                        asset,
                        game_root,
                        metadata_root,
                        target,
                        existing_names,
                    )
                    manifest.upsert(metadata)
                    project_credits.upsert(
                        metadata,
                        self._project_relative_path(game_root / metadata.local_file),
                    )
                    state.mark_completed(asset.asset_id, metadata.to_manifest_record())
                    manifest.write_failed(state.failed)
                except StopDownload:
                    manifest.write_failed(state.failed)
                    state.save()
                    raise
                except Exception as exc:
                    self.logger.exception("Failed asset %s: %s", asset.url, exc)
                    state.mark_failed(asset.asset_id, str(exc), asset.url)
                    manifest.write_failed(state.failed)
            return 0

    def _filtered_assets(self, game: GameInfo) -> list[AssetLink]:
        include = {item.casefold() for item in self.config.include_sections or []}
        exclude = {item.casefold() for item in self.config.exclude_sections or []}
        include_assets = [item.casefold() for item in self.config.include_assets or []]
        exclude_assets = [item.casefold() for item in self.config.exclude_assets or []]
        assets = []
        for asset in game.assets:
            section = (asset.section or "Uncategorized").casefold()
            name = (asset.name or "").casefold()
            if include and section not in include:
                continue
            if exclude and section in exclude:
                continue
            if include_assets and not any(item in name for item in include_assets):
                continue
            if exclude_assets and any(item in name for item in exclude_assets):
                continue
            assets.append(asset)
        if self.config.max_assets is not None:
            assets = assets[: self.config.max_assets]
        return assets

    def _print_summary(
        self, game: GameInfo, assets: list[AssetLink], target: FranchiseTarget
    ) -> None:
        self.logger.info("Game: %s", game.title)
        self.logger.info("Platform/category: %s", game.platform)
        self.logger.info(
            "Asset count reported: %s",
            game.asset_count if game.asset_count is not None else "unknown",
        )
        self.logger.info("Assets selected: %s", len(assets))
        self.logger.info("Sections: %s", ", ".join(game.sections) if game.sections else "unknown")
        self.logger.info("Destination: %s", target.directory)
        self.logger.info(
            "Filename pattern: %s_<asset>%s",
            target.prefix,
            f"_{target.suffix}" if target.suffix else "",
        )

    def _confirm(self) -> bool:
        answer = input("Download the selected assets? Type 'yes' to continue: ").strip().casefold()
        return answer == "yes"

    def _process_asset(
        self,
        page: Page,
        game: GameInfo,
        asset: AssetLink,
        game_root: Path,
        metadata_root: Path,
        target: FranchiseTarget,
        existing_names: dict[str, set[str]],
    ) -> AssetMetadata:
        self.logger.info("Visiting asset %s: %s", asset.asset_id, asset.url)
        self._goto_with_retries(page, asset.url)
        html = page.content()
        metadata = parse_asset_page(html, asset.url)
        metadata.game = metadata.game or game.title
        metadata.platform = metadata.platform or game.platform
        metadata.section = metadata.section or asset.section or "Uncategorized"
        if metadata.asset_name.startswith("asset_") and asset.name:
            metadata.asset_name = asset.name

        if not metadata.source_url:
            debug_path = metadata_root / "debug_html" / f"asset_{asset.asset_id}.html"
            write_debug_snapshot(debug_path, html)
            self.logger.debug("Wrote debug HTML snapshot to %s", debug_path)

        names = existing_names.setdefault(str(game_root), set())
        file_stem = asset_filename_stem(
            metadata.asset_name,
            prefix=target.prefix,
            suffix=target.suffix,
        )
        final_path = self._download_asset(page, metadata, game_root, names, file_stem=file_stem)
        metadata.asset_id = final_path.stem
        metadata.local_file = str(final_path.relative_to(game_root))
        metadata.downloaded_at = datetime.now(UTC).isoformat()
        return metadata

    def _goto_with_retries(self, page: Page, url: str) -> None:
        for attempt in range(1, 4):
            response = page.goto(url, wait_until="domcontentloaded", timeout=60_000)
            status = response.status if response else 0
            if status in ACCESS_STOP_STATUSES:
                raise StopDownload(f"Access restriction returned HTTP {status}. Progress saved.")
            if status in TRANSIENT_HTTP_STATUSES:
                self.transient_failures += 1
                if self.transient_failures >= 5:
                    raise StopDownload(
                        "Repeated transient or rate-limit responses. Progress saved."
                    )
                wait = backoff_seconds(attempt)
                self.logger.warning("HTTP %s from %s; backing off %.0f seconds.", status, url, wait)
                time.sleep(wait)
                continue
            self.transient_failures = 0
            try:
                page.wait_for_load_state("networkidle", timeout=15_000)
            except PlaywrightTimeoutError:
                self.logger.debug(
                    "Network idle timed out for %s; continuing with DOM content.", url
                )
            body_text = page.locator("body").inner_text(timeout=10_000)
            if looks_restricted(body_text):
                raise StopDownload(
                    "Access restriction, CAPTCHA, login, or bot challenge detected. Progress saved."
                )
            return
        raise StopDownload(f"HTTP {status} persisted after retries. Progress saved.")

    def _download_asset(
        self,
        page: Page,
        metadata: AssetMetadata,
        section_dir: Path,
        existing_names: set[str],
        *,
        file_stem: str | None = None,
    ) -> Path:
        controls = [
            ("a[download][href]", "download attribute"),
            ('a[href*="/media/assets/"]', "media asset link"),
            ('a[href*="/download/"]', "download URL"),
            ('a:has-text("Download")', "visible download link"),
            ('button:has-text("Download")', "visible download button"),
            ('a:has-text("download")', "material download icon link"),
            ('button:has-text("download")', "material download icon button"),
        ]
        last_error: Exception | None = None
        original_url = page.url
        for selector, description in controls:
            locator = page.locator(selector).first
            try:
                if locator.count() == 0 or not locator.is_visible(timeout=1_000):
                    continue
                self.logger.info("Trying download control: %s", description)
                with page.expect_download(timeout=30_000) as download_info:
                    locator.click()
                download = download_info.value
                extension = safe_extension(
                    download.suggested_filename, metadata.source_url, metadata.format
                )
                final_path = reserve_destination(
                    section_dir,
                    file_stem or metadata.asset_name,
                    extension,
                    asset_id=metadata.asset_id,
                    existing_names=existing_names,
                )
                download.save_as(final_path)
                self._verify_file(final_path)
                return final_path
            except PlaywrightTimeoutError as exc:
                last_error = exc
                self.logger.debug("No download event from %s.", description)
                if self._is_media_url(page.url):
                    return self._save_current_media_url(
                        page,
                        metadata,
                        section_dir,
                        existing_names,
                        file_stem=file_stem,
                    )
                if page.url != original_url:
                    page.goto(original_url, wait_until="domcontentloaded", timeout=30_000)
            except Exception as exc:
                last_error = exc
                self.logger.debug("Download control %s failed: %s", description, exc)

        if metadata.source_url and self._is_media_url(metadata.source_url):
            return self._save_media_url(
                page,
                metadata.source_url,
                metadata,
                section_dir,
                existing_names,
                file_stem=file_stem,
            )
        raise RuntimeError(f"No usable official download control found. Last error: {last_error}")

    def _save_current_media_url(
        self,
        page: Page,
        metadata: AssetMetadata,
        section_dir: Path,
        existing_names: set[str],
        *,
        file_stem: str | None = None,
    ) -> Path:
        url = page.url
        return self._save_media_url(
            page, url, metadata, section_dir, existing_names, file_stem=file_stem
        )

    def _save_media_url(
        self,
        page: Page,
        url: str,
        metadata: AssetMetadata,
        section_dir: Path,
        existing_names: set[str],
        *,
        file_stem: str | None = None,
    ) -> Path:
        self.logger.info("Saving media response from browser context: %s", url)
        response = page.context.request.get(
            url, headers={"referer": metadata.asset_page_url}, timeout=30_000
        )
        if not response.ok:
            raise RuntimeError(f"Media download failed with HTTP {response.status}")
        extension = safe_extension(urlparse(url).path, metadata.format)
        final_path = reserve_destination(
            section_dir,
            file_stem or metadata.asset_name,
            extension,
            asset_id=metadata.asset_id,
            existing_names=existing_names,
        )
        final_path.write_bytes(response.body())
        self._verify_file(final_path)
        return final_path

    def _verify_file(self, path: Path) -> None:
        data = path.read_bytes()[:512].lower()
        if not data:
            raise RuntimeError(f"Downloaded file is empty: {path}")
        if re.search(rb"<(?:!doctype\s+html|html|body)\b", data):
            raise RuntimeError(f"Downloaded file looks like an HTML error page: {path}")

    def _is_media_url(self, url: str) -> bool:
        parsed = urlparse(url)
        return parsed.netloc.endswith("spriters-resource.com") and "/media/assets/" in parsed.path

    def _project_relative_path(self, path: Path) -> Path:
        try:
            return path.resolve(strict=False).relative_to(
                self.config.project_root.resolve(strict=False)
            )
        except ValueError:
            return path

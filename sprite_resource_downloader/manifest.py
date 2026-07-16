from __future__ import annotations

import csv
import json
from pathlib import Path

from .asset_parser import AssetMetadata

CREDITS_COLUMNS = [
    "game",
    "platform",
    "section",
    "asset_name",
    "asset_id",
    "asset_page_url",
    "uploaded_by",
    "contributors",
    "submitted",
    "format",
    "size",
    "local_file",
    "downloaded_at",
]

PROJECT_CREDITS_COLUMNS = [
    "asset_id",
    "character_id",
    "source_game",
    "source_site",
    "source_page",
    "contributor",
    "permission_notes",
    "file",
]

PROJECT_PERMISSION_NOTES = (
    "Fan-ripped sprites; for private/non-commercial prototype use only. "
    "Credit original Spriters Resource submitters where required."
)


class ManifestWriter:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.records: list[dict[str, object]] = []

    @property
    def manifest_path(self) -> Path:
        return self.root / "ASSET_MANIFEST.json"

    @property
    def credits_path(self) -> Path:
        return self.root / "ASSET_CREDITS.csv"

    @property
    def failed_path(self) -> Path:
        return self.root / "failed_downloads.json"

    def load_existing(self) -> None:
        if self.manifest_path.exists():
            self.records = json.loads(self.manifest_path.read_text(encoding="utf-8"))

    def upsert(self, metadata: AssetMetadata) -> None:
        record = metadata.to_manifest_record()
        self.records = [item for item in self.records if item.get("asset_id") != metadata.asset_id]
        self.records.append(record)
        self.write()

    def write(self) -> None:
        self.root.mkdir(parents=True, exist_ok=True)
        self.manifest_path.write_text(
            json.dumps(self.records, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        with self.credits_path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=CREDITS_COLUMNS)
            writer.writeheader()
            for record in self.records:
                metadata = AssetMetadata(
                    **{key: record.get(key, "") for key in AssetMetadata.__dataclass_fields__}
                )
                writer.writerow(metadata.to_credits_row())

    def write_failed(self, failed: dict[str, dict[str, object]]) -> None:
        self.root.mkdir(parents=True, exist_ok=True)
        self.failed_path.write_text(json.dumps(failed, indent=2, sort_keys=True), encoding="utf-8")


class ProjectCreditsWriter:
    def __init__(self, path: Path) -> None:
        self.path = path

    def upsert(self, metadata: AssetMetadata, local_file: Path) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        rows, columns = self._read_rows()
        row = self._row(metadata, local_file, columns)
        rows = [item for item in rows if item.get("asset_id") != metadata.asset_id]
        rows.append(row)
        with self.path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=columns)
            writer.writeheader()
            writer.writerows(rows)

    def _read_rows(self) -> tuple[list[dict[str, str]], list[str]]:
        if not self.path.exists():
            return [], PROJECT_CREDITS_COLUMNS
        with self.path.open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            columns = reader.fieldnames or PROJECT_CREDITS_COLUMNS
            return list(reader), columns

    def _row(self, metadata: AssetMetadata, local_file: Path, columns: list[str]) -> dict[str, str]:
        contributor = metadata.uploaded_by
        if metadata.contributors:
            contributor = "; ".join([metadata.uploaded_by, *metadata.contributors]).strip("; ")
        values = {
            "asset_id": metadata.asset_id,
            "character_id": _character_id(metadata.asset_id),
            "source_game": metadata.game,
            "source_site": "The Spriters Resource",
            "source_page": metadata.asset_page_url,
            "source_page_url": metadata.asset_page_url,
            "contributor": contributor,
            "permission_notes": PROJECT_PERMISSION_NOTES,
            "file": local_file.as_posix(),
        }
        return {column: values.get(column, "") for column in columns}


def _character_id(asset_id: str) -> str:
    parts = asset_id.split("_")
    if len(parts) <= 1:
        return asset_id
    if parts[-1] in {"gba", "snes", "nes", "ds"}:
        parts = parts[:-1]
    return "_".join(parts[1:]) or asset_id

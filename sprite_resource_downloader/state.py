from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class DownloadState:
    path: Path
    completed: dict[str, dict[str, Any]] = field(default_factory=dict)
    failed: dict[str, dict[str, Any]] = field(default_factory=dict)

    @classmethod
    def load(cls, path: Path) -> "DownloadState":
        if not path.exists():
            return cls(path=path)
        data = json.loads(path.read_text(encoding="utf-8"))
        return cls(
            path=path,
            completed=dict(data.get("completed", {})),
            failed=dict(data.get("failed", {})),
        )

    def is_completed(self, asset_id: str) -> bool:
        return asset_id in self.completed

    def mark_completed(self, asset_id: str, record: dict[str, Any]) -> None:
        self.completed[asset_id] = record
        self.failed.pop(asset_id, None)
        self.save()

    def mark_failed(self, asset_id: str, reason: str, url: str) -> None:
        self.failed[asset_id] = {"reason": reason, "url": url}
        self.save()

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {"completed": self.completed, "failed": self.failed}
        self.path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")

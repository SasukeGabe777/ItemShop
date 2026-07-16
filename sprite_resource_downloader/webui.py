from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import threading
import uuid
import webbrowser
from dataclasses import dataclass, field
from datetime import UTC, datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

from .project_layout import FRANCHISE_TARGETS


PROJECT_ROOT = Path.cwd()


@dataclass
class Job:
    id: str
    command: list[str]
    status: str = "queued"
    return_code: int | None = None
    created_at: str = field(default_factory=lambda: datetime.now(UTC).isoformat())
    started_at: str = ""
    ended_at: str = ""
    lines: list[str] = field(default_factory=list)
    process: subprocess.Popen[str] | None = None


class JobManager:
    def __init__(self, project_root: Path) -> None:
        self.project_root = project_root
        self._jobs: dict[str, Job] = {}
        self._lock = threading.Lock()

    def start(self, payload: dict[str, Any]) -> Job:
        command = build_command(payload)
        job = Job(id=uuid.uuid4().hex[:12], command=command)
        with self._lock:
            self._jobs[job.id] = job
        thread = threading.Thread(target=self._run, args=(job,), daemon=True)
        thread.start()
        return job

    def list_jobs(self) -> list[dict[str, Any]]:
        with self._lock:
            return [self._serialize(job, tail=40) for job in self._jobs.values()]

    def get(self, job_id: str) -> dict[str, Any] | None:
        with self._lock:
            job = self._jobs.get(job_id)
            return self._serialize(job) if job else None

    def cancel(self, job_id: str) -> bool:
        with self._lock:
            job = self._jobs.get(job_id)
            process = job.process if job else None
            if not job or job.status not in {"queued", "running"}:
                return False
            job.status = "cancelling"
            job.lines.append("Cancellation requested.")

        if process and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill()
        return True

    def _run(self, job: Job) -> None:
        self._update(job, status="running", started_at=datetime.now(UTC).isoformat())
        creationflags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
        try:
            process = subprocess.Popen(
                job.command,
                cwd=self.project_root,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                creationflags=creationflags,
            )
            self._update(job, process=process)
            assert process.stdout is not None
            for line in process.stdout:
                self._append(job, line.rstrip())
            return_code = process.wait()
            with self._lock:
                if job.status == "cancelling":
                    job.status = "cancelled"
                else:
                    job.status = "succeeded" if return_code == 0 else "failed"
                job.return_code = return_code
                job.ended_at = datetime.now(UTC).isoformat()
        except Exception as exc:
            with self._lock:
                job.status = "failed"
                job.return_code = -1
                job.ended_at = datetime.now(UTC).isoformat()
                job.lines.append(f"UI runner failed: {exc}")

    def _append(self, job: Job, line: str) -> None:
        with self._lock:
            job.lines.append(line)
            if len(job.lines) > 2000:
                job.lines = job.lines[-2000:]

    def _update(self, job: Job, **values: Any) -> None:
        with self._lock:
            for key, value in values.items():
                setattr(job, key, value)

    def _serialize(self, job: Job, *, tail: int | None = None) -> dict[str, Any]:
        lines = job.lines[-tail:] if tail else job.lines
        return {
            "id": job.id,
            "status": job.status,
            "return_code": job.return_code,
            "created_at": job.created_at,
            "started_at": job.started_at,
            "ended_at": job.ended_at,
            "command": printable_command(job.command),
            "lines": lines,
        }


def build_command(payload: dict[str, Any]) -> list[str]:
    game_url = str(payload.get("game_url", "")).strip()
    if not game_url:
        raise ValueError("Game URL is required.")

    command = [sys.executable, "-m", "sprite_resource_downloader", game_url, "--yes"]
    if payload.get("mode") == "dry-run":
        command.append("--dry-run")
    if payload.get("resume"):
        command.append("--resume")
    command.append("--headed" if payload.get("headed") else "--headless")

    optional_values = {
        "--franchise": payload.get("franchise"),
        "--output": payload.get("output"),
        "--max-assets": payload.get("max_assets"),
        "--min-delay": payload.get("min_delay"),
        "--max-delay": payload.get("max_delay"),
    }
    for flag, value in optional_values.items():
        text = str(value).strip() if value is not None else ""
        if text:
            command.extend([flag, text])

    for flag, key in (
        ("--include-section", "include_sections"),
        ("--exclude-section", "exclude_sections"),
        ("--include-asset", "include_assets"),
        ("--exclude-asset", "exclude_assets"),
    ):
        for term in split_terms(payload.get(key)):
            command.extend([flag, term])
    return command


def split_terms(value: Any) -> list[str]:
    if not value:
        return []
    if isinstance(value, list):
        source = "\n".join(str(item) for item in value)
    else:
        source = str(value)
    raw_terms = []
    for line in source.splitlines():
        raw_terms.extend(line.split(","))
    return [term.strip() for term in raw_terms if term.strip()]


def printable_command(command: list[str]) -> str:
    return " ".join(f'"{part}"' if " " in part else part for part in command)


class UiHandler(BaseHTTPRequestHandler):
    manager: JobManager

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self._send_html(INDEX_HTML)
            return
        if parsed.path == "/api/config":
            self._send_json(config_payload())
            return
        if parsed.path == "/api/jobs":
            self._send_json({"jobs": self.manager.list_jobs()})
            return
        if parsed.path.startswith("/api/jobs/"):
            job_id = parsed.path.rsplit("/", 1)[-1]
            job = self.manager.get(job_id)
            if job is None:
                self._send_json({"error": "Job not found."}, HTTPStatus.NOT_FOUND)
                return
            self._send_json(job)
            return
        if parsed.path == "/api/files":
            query = parse_qs(parsed.query)
            franchise = query.get("franchise", [""])[0]
            self._send_json(files_payload(franchise))
            return
        self._send_json({"error": "Not found."}, HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        try:
            payload = self._read_json()
            if parsed.path == "/api/jobs":
                job = self.manager.start(payload)
                self._send_json(self.manager.get(job.id) or {"id": job.id}, HTTPStatus.CREATED)
                return
            if parsed.path.startswith("/api/jobs/") and parsed.path.endswith("/cancel"):
                job_id = parsed.path.split("/")[-2]
                if not self.manager.cancel(job_id):
                    self._send_json({"error": "Job cannot be cancelled."}, HTTPStatus.CONFLICT)
                    return
                self._send_json({"ok": True})
                return
            self._send_json({"error": "Not found."}, HTTPStatus.NOT_FOUND)
        except ValueError as exc:
            self._send_json({"error": str(exc)}, HTTPStatus.BAD_REQUEST)

    def log_message(self, format: str, *args: Any) -> None:
        return

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8") if length else "{}"
        return json.loads(raw)

    def _send_json(self, data: dict[str, Any], status: HTTPStatus = HTTPStatus.OK) -> None:
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, html: str) -> None:
        body = html.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def config_payload() -> dict[str, Any]:
    franchises = []
    for key, target in FRANCHISE_TARGETS.items():
        franchises.append(
            {
                "id": key,
                "label": key.replace("_", " ").title(),
                "directory": str(target.directory),
                "prefix": target.prefix,
                "suffix": target.suffix,
            }
        )
    return {
        "franchises": franchises,
        "presets": [
            {
                "label": "KH GBA Targets",
                "url": "https://www.spriters-resource.com/game_boy_advance/khcom/",
                "franchise": "kingdom_hearts",
                "include_assets": "Sora\nShadow\nSoldier\nLarge Body\nYellow Opera\nRed Nocturne\nFat Bandit",
            },
            {
                "label": "Pokemon FR/LG",
                "url": "https://www.spriters-resource.com/game_boy_advance/pokemonfireredleafgreen/",
                "franchise": "pokemon",
                "include_assets": "Pikachu\nRattata\nZubat\nGastly\nMagnemite\nBeedrill\nMewtwo",
            },
        ],
    }


def files_payload(franchise: str) -> dict[str, Any]:
    target = FRANCHISE_TARGETS.get(franchise)
    if not target:
        return {"files": []}
    root = PROJECT_ROOT / target.directory
    files = []
    if root.exists():
        for path in sorted(root.glob("*")):
            if path.is_file() and path.suffix.lower() in {".png", ".gif", ".zip"}:
                files.append({"name": path.name, "bytes": path.stat().st_size})
    return {"files": files}


def run_server(host: str, port: int, *, open_browser: bool) -> ThreadingHTTPServer:
    manager = JobManager(PROJECT_ROOT)
    handler = type("SpriteUiHandler", (UiHandler,), {"manager": manager})
    server = ThreadingHTTPServer((host, port), handler)
    url = f"http://{host}:{server.server_address[1]}/"
    print(f"Sprite Resource Downloader UI running at {url}", flush=True)
    if open_browser:
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return server


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m sprite_resource_downloader.webui")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--open", action="store_true", help="Open the UI in the default browser.")
    args = parser.parse_args(argv)
    run_server(args.host, args.port, open_browser=args.open)
    return 0


INDEX_HTML = r"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sprite Resource Downloader</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #141414;
      --panel: #1f2226;
      --panel-2: #262a30;
      --line: #383d45;
      --text: #eeeeee;
      --muted: #aeb4be;
      --accent: #79b8ff;
      --good: #86d39b;
      --bad: #ff8b8b;
      --warn: #ffd06e;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font: 14px/1.45 "Segoe UI", system-ui, sans-serif;
      background: var(--bg);
      color: var(--text);
    }
    header {
      height: 56px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 20px;
      border-bottom: 1px solid var(--line);
      background: #191b1f;
    }
    h1 { font-size: 17px; margin: 0; font-weight: 650; letter-spacing: 0; }
    main {
      display: grid;
      grid-template-columns: minmax(360px, 440px) minmax(480px, 1fr);
      gap: 16px;
      padding: 16px;
      min-height: calc(100vh - 56px);
    }
    section {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      min-width: 0;
    }
    .panel-head {
      padding: 12px 14px;
      border-bottom: 1px solid var(--line);
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
    }
    h2 { font-size: 14px; margin: 0; font-weight: 650; letter-spacing: 0; }
    form { padding: 14px; display: grid; gap: 12px; }
    label { display: grid; gap: 6px; color: var(--muted); font-size: 12px; }
    input, select, textarea {
      width: 100%;
      background: #14171a;
      color: var(--text);
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 9px 10px;
      font: inherit;
      outline: none;
    }
    textarea { min-height: 92px; resize: vertical; }
    input:focus, select:focus, textarea:focus { border-color: var(--accent); }
    .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
    .checks { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
    .check {
      display: flex;
      align-items: center;
      gap: 8px;
      color: var(--text);
      background: var(--panel-2);
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 8px 10px;
      min-height: 38px;
    }
    .check input { width: auto; }
    .toolbar { display: flex; gap: 8px; flex-wrap: wrap; }
    button {
      border: 1px solid var(--line);
      background: var(--panel-2);
      color: var(--text);
      border-radius: 6px;
      min-height: 36px;
      padding: 0 12px;
      font: inherit;
      cursor: pointer;
    }
    button.primary { background: #1f5f9e; border-color: #2f75bd; }
    button.danger { background: #6d2828; border-color: #8b3838; }
    button:disabled { opacity: .55; cursor: not-allowed; }
    .muted { color: var(--muted); }
    .job-layout {
      display: grid;
      grid-template-rows: auto minmax(320px, 1fr) auto;
      height: 100%;
      min-height: 520px;
    }
    .status-row {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      align-items: center;
      padding: 12px 14px;
      border-bottom: 1px solid var(--line);
    }
    .pill {
      display: inline-flex;
      align-items: center;
      min-height: 26px;
      padding: 0 9px;
      border-radius: 999px;
      background: var(--panel-2);
      color: var(--muted);
      border: 1px solid var(--line);
      font-size: 12px;
    }
    .pill.running { color: var(--warn); }
    .pill.succeeded { color: var(--good); }
    .pill.failed, .pill.cancelled { color: var(--bad); }
    pre {
      margin: 0;
      padding: 14px;
      overflow: auto;
      background: #0f1113;
      color: #e8edf2;
      font: 12px/1.5 Consolas, "Cascadia Mono", monospace;
      white-space: pre-wrap;
    }
    .files {
      border-top: 1px solid var(--line);
      padding: 12px 14px;
      max-height: 160px;
      overflow: auto;
    }
    .file-row {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      padding: 3px 0;
      color: var(--muted);
    }
    @media (max-width: 920px) {
      main { grid-template-columns: 1fr; }
      .job-layout { min-height: 420px; }
    }
  </style>
</head>
<body>
  <header>
    <h1>Sprite Resource Downloader</h1>
    <span class="muted">Local Playwright runner</span>
  </header>
  <main>
    <section>
      <div class="panel-head">
        <h2>Download Job</h2>
        <select id="preset" title="Preset"></select>
      </div>
      <form id="jobForm">
        <label>Game page URL
          <input id="gameUrl" required value="https://www.spriters-resource.com/game_boy_advance/khcom/">
        </label>
        <div class="grid-2">
          <label>Franchise
            <select id="franchise"></select>
          </label>
          <label>Mode
            <select id="mode">
              <option value="dry-run">Dry run</option>
              <option value="download">Download</option>
            </select>
          </label>
        </div>
        <label>Include assets
          <textarea id="includeAssets" spellcheck="false">Sora
Shadow
Soldier
Large Body
Yellow Opera
Red Nocturne
Fat Bandit</textarea>
        </label>
        <div class="grid-2">
          <label>Include sections
            <input id="includeSections" placeholder="Enemies & Bosses">
          </label>
          <label>Exclude sections
            <input id="excludeSections" placeholder="Backgrounds">
          </label>
        </div>
        <div class="grid-2">
          <label>Max assets
            <input id="maxAssets" type="number" min="1" step="1" value="1">
          </label>
          <label>Output override
            <input id="output" placeholder="leave blank for project raw folder">
          </label>
        </div>
        <div class="grid-2">
          <label>Min delay
            <input id="minDelay" type="number" min="2" step="0.5" value="4">
          </label>
          <label>Max delay
            <input id="maxDelay" type="number" min="2" step="0.5" value="8">
          </label>
        </div>
        <div class="checks">
          <label class="check"><input id="resume" type="checkbox" checked> Resume</label>
          <label class="check"><input id="headed" type="checkbox"> Show Chromium</label>
        </div>
        <div class="toolbar">
          <button class="primary" type="submit">Start Job</button>
          <button id="cancel" class="danger" type="button" disabled>Cancel</button>
          <button id="refreshFiles" type="button">Refresh Files</button>
        </div>
        <div class="muted" id="destination">Destination: assets/franchises/kingdom_hearts/raw</div>
      </form>
    </section>
    <section class="job-layout">
      <div class="panel-head">
        <h2>Runner Output</h2>
        <span id="jobId" class="muted">No active job</span>
      </div>
      <div class="status-row">
        <span id="status" class="pill">idle</span>
        <span id="returnCode" class="pill">return code: -</span>
      </div>
      <pre id="log">Ready.</pre>
      <div class="files">
        <strong>Raw files</strong>
        <div id="files" class="muted">No files loaded.</div>
      </div>
    </section>
  </main>
  <script>
    const state = { config: null, activeJob: null, timer: null };
    const $ = (id) => document.getElementById(id);

    async function api(path, options = {}) {
      const res = await fetch(path, {
        headers: { "Content-Type": "application/json" },
        ...options
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
      return data;
    }

    function payload() {
      return {
        game_url: $("gameUrl").value,
        franchise: $("franchise").value,
        mode: $("mode").value,
        include_assets: $("includeAssets").value,
        include_sections: $("includeSections").value,
        exclude_sections: $("excludeSections").value,
        max_assets: $("maxAssets").value,
        output: $("output").value,
        min_delay: $("minDelay").value,
        max_delay: $("maxDelay").value,
        resume: $("resume").checked,
        headed: $("headed").checked
      };
    }

    async function loadConfig() {
      state.config = await api("/api/config");
      $("franchise").innerHTML = state.config.franchises.map(f =>
        `<option value="${f.id}">${f.label}</option>`
      ).join("");
      $("preset").innerHTML = `<option value="">Preset...</option>` + state.config.presets.map((p, i) =>
        `<option value="${i}">${p.label}</option>`
      ).join("");
      $("franchise").value = "kingdom_hearts";
      updateDestination();
      refreshFiles();
    }

    function updateDestination() {
      const f = state.config?.franchises.find(item => item.id === $("franchise").value);
      $("destination").textContent = `Destination: ${$("output").value || f?.directory || "custom output"}`;
    }

    async function refreshFiles() {
      const data = await api(`/api/files?franchise=${encodeURIComponent($("franchise").value)}`);
      $("files").innerHTML = data.files.length ? data.files.map(file =>
        `<div class="file-row"><span>${file.name}</span><span>${formatBytes(file.bytes)}</span></div>`
      ).join("") : `<div class="muted">No raw files found for this franchise.</div>`;
    }

    function formatBytes(bytes) {
      if (bytes < 1024) return `${bytes} B`;
      if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
      return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
    }

    function renderJob(job) {
      state.activeJob = job.id;
      $("jobId").textContent = job.id;
      $("status").textContent = job.status;
      $("status").className = `pill ${job.status}`;
      $("returnCode").textContent = `return code: ${job.return_code ?? "-"}`;
      $("log").textContent = [`$ ${job.command}`, "", ...job.lines].join("\n");
      $("cancel").disabled = !["queued", "running"].includes(job.status);
      if (!["queued", "running", "cancelling"].includes(job.status)) {
        clearInterval(state.timer);
        state.timer = null;
        refreshFiles();
      }
    }

    async function pollJob() {
      if (!state.activeJob) return;
      renderJob(await api(`/api/jobs/${state.activeJob}`));
    }

    $("jobForm").addEventListener("submit", async (event) => {
      event.preventDefault();
      try {
        const job = await api("/api/jobs", { method: "POST", body: JSON.stringify(payload()) });
        renderJob(job);
        clearInterval(state.timer);
        state.timer = setInterval(pollJob, 1200);
      } catch (err) {
        $("log").textContent = err.message;
      }
    });

    $("cancel").addEventListener("click", async () => {
      if (!state.activeJob) return;
      await api(`/api/jobs/${state.activeJob}/cancel`, { method: "POST", body: "{}" });
      await pollJob();
    });

    $("preset").addEventListener("change", () => {
      const preset = state.config.presets[Number($("preset").value)];
      if (!preset) return;
      $("gameUrl").value = preset.url;
      $("franchise").value = preset.franchise;
      $("includeAssets").value = preset.include_assets;
      updateDestination();
      refreshFiles();
    });

    ["franchise", "output"].forEach(id => $(id).addEventListener("input", updateDestination));
    $("refreshFiles").addEventListener("click", refreshFiles);
    loadConfig();
  </script>
</body>
</html>"""


if __name__ == "__main__":
    raise SystemExit(main())

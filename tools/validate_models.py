#!/usr/bin/env python3
"""Run the shared runtime validator against this template."""
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
RUNTIME_URL = "https://github.com/Hearmeman24/comfyui-runtime.git"
CACHE = Path.home() / ".cache" / "comfyui-runtime-validator"


def runtime_dir() -> Path:
    local = os.environ.get("COMFYUI_RUNTIME_DIR")
    if local:
        return Path(local)
    ref = json.loads((REPO / "pins.json").read_text())["runtime_ref"]
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    if not (CACHE / ".git").is_dir():
        subprocess.run(["git", "clone", "--quiet", RUNTIME_URL, str(CACHE)], check=True)
    subprocess.run(["git", "-C", str(CACHE), "fetch", "--quiet", "origin", ref], check=True)
    subprocess.run(["git", "-C", str(CACHE), "checkout", "--quiet", "--force", "FETCH_HEAD"], check=True)
    return CACHE


if __name__ == "__main__":
    runtime = runtime_dir()
    raise SystemExit(subprocess.run([
        sys.executable, str(runtime / "tools" / "validate_models.py"),
        "--registry", str(REPO / "src" / "models_registry.json"),
        "--workflows", str(REPO / "workflows"),
        "--template", str(REPO / "template.json"), *sys.argv[1:]
    ]).returncode)

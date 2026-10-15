"""Configuration, paths, and cost logging for SpriteForge."""
from __future__ import annotations

import csv
import datetime
import os
from pathlib import Path

# Paths
ROOT_DIR = Path(__file__).resolve().parent.parent.parent
RUNS_DIR = ROOT_DIR / "spriteforge-runs"
COSTS_FILE = RUNS_DIR / "costs.csv"
ENV_FILE = ROOT_DIR / ".env"


def get_gemini_api_key() -> str:
    """Read GEMINI_API_KEY from environment or .env without leaking secrets."""
    if os.environ.get("GEMINI_API_KEY"):
        return os.environ["GEMINI_API_KEY"].strip()
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("GEMINI_API_KEY=") and not line.startswith("#"):
                val = line.split("=", 1)[1].strip()
                if val:
                    return val
    raise ValueError(
        "GEMINI_API_KEY is missing. Please add GEMINI_API_KEY=... to your .env file."
    )


def log_cost(character: str, action: str, model: str, cost: float, notes: str = "") -> None:
    """Record an API cost entry in spriteforge-runs/costs.csv."""
    RUNS_DIR.mkdir(parents=True, exist_ok=True)
    file_exists = COSTS_FILE.exists()
    with open(COSTS_FILE, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        if not file_exists:
            writer.writerow(["timestamp", "character", "action", "model", "estimated_cost_usd", "notes"])
        writer.writerow([
            datetime.datetime.now(datetime.timezone.utc).isoformat(),
            character,
            action,
            model,
            f"{cost:.4f}",
            notes,
        ])

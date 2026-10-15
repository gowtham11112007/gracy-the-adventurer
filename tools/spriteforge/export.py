"""Godot game export module for SpriteForge sprites."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict
from PIL import Image

from tools.spriteforge.config import ROOT_DIR, RUNS_DIR

GODOT_DIR = ROOT_DIR / "godot"
GODOT_ASSETS_HERO2_DIR = GODOT_DIR / "assets" / "hero2"
GODOT_DATA_DIR = GODOT_DIR / "data"
HERO2_DATA_FILE = GODOT_DATA_DIR / "hero2.json"
TARGET_CELL = 210
TARGET_HEIGHT = 168.0


def export_action_to_godot(
    character: str,
    outfit: str,
    action: str,
) -> Path:
    """Export an action strip into Godot hero2 assets and update hero2.json."""
    action_run_dir = RUNS_DIR / character / action
    frames_dir = action_run_dir / "frames_keyed"
    manifest_file = action_run_dir / "manifest.json"

    if not frames_dir.exists() or not manifest_file.exists():
        raise FileNotFoundError(
            f"No processed frames found at {frames_dir}. Please run animate or repick first."
        )

    with open(manifest_file, "r", encoding="utf-8") as f:
        meta = json.load(f)

    frame_files = sorted(frames_dir.glob("frame_*.png"))
    frames = [Image.open(f) for f in frame_files]
    fps = meta.get("fps", 12)

    # Scale frames to target standing height
    boxes = [f.getbbox() for f in frames if f.getbbox()]
    max_h = max(b[3] - b[1] for b in boxes) if boxes else TARGET_HEIGHT
    scale = TARGET_HEIGHT / float(max_h)

    cell_frames = []
    for f in frames:
        w = max(1, round(f.width * scale))
        h = max(1, round(f.height * scale))
        resized = f.resize((w, h), Image.Resampling.LANCZOS)

        cell_img = Image.new("RGBA", (TARGET_CELL, TARGET_CELL), (0, 0, 0, 0))
        px = round((TARGET_CELL - w) / 2.0)
        py = TARGET_CELL - h
        cell_img.alpha_composite(resized, (px, py))
        cell_frames.append(cell_img)

    GODOT_ASSETS_HERO2_DIR.mkdir(parents=True, exist_ok=True)
    strip_name = f"{outfit}_{action}.png"
    strip_path = GODOT_ASSETS_HERO2_DIR / strip_name

    strip = Image.new("RGBA", (TARGET_CELL * len(cell_frames), TARGET_CELL), (0, 0, 0, 0))
    for i, c in enumerate(cell_frames):
        strip.alpha_composite(c, (i * TARGET_CELL, 0))
    strip.save(strip_path)

    # Update hero2.json
    hero2_data: Dict[str, Any] = {}
    if HERO2_DATA_FILE.exists():
        try:
            with open(HERO2_DATA_FILE, "r", encoding="utf-8") as f:
                hero2_data = json.load(f)
        except Exception:
            hero2_data = {}

    if outfit not in hero2_data:
        hero2_data[outfit] = {"cell": TARGET_CELL, "base": outfit, "actions": {}}
    hero2_data[outfit]["cell"] = TARGET_CELL
    hero2_data[outfit]["base"] = outfit
    if "actions" not in hero2_data[outfit]:
        hero2_data[outfit]["actions"] = {}

    action_key = f"hero2/{outfit}_{action}"
    hero2_data[outfit]["actions"][action] = {
        "key": action_key,
        "frames": len(cell_frames),
        "fps": fps,
    }

    with open(HERO2_DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(hero2_data, f, indent=2)

    print(f"Exported {strip_path} ({len(cell_frames)} frames, {TARGET_CELL}x{TARGET_CELL})")
    print(f"Updated {HERO2_DATA_FILE} -> {action_key}")
    return strip_path

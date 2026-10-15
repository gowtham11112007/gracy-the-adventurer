"""Prepare Kitty sprite strips and skins for Godot from Spriterrific runs.

Usage:
    .venv/bin/python tools/prepare_kitty.py [RUN_DIR]

Generates strips in godot/assets/kitty/ for each coat skin (orange, gray, black, cream):
- run (20 frames, 24 fps)
- jump (25 frames, 24 fps)
- attack (25 frames, 24 fps)
- hurt (25 frames, 24 fps)
- idle (6 frames, 6 fps)
- portrait (128x128 face portrait)
Updates godot/data/manifest.json and godot/data/kitty_skins.json.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from PIL import Image
import numpy as np

CELL = 256
OUT_CELL = 128
OUT_DIR = Path("godot/assets/kitty")
MANIFEST_PATH = Path("godot/data/manifest.json")
SKINS_PATH = Path("godot/data/kitty_skins.json")

SKINS = [
    {"id": "orange", "name": "Ginger Tabby", "color": "#f2994a"},
    {"id": "gray", "name": "Silver Tabby", "color": "#b0bec5"},
    {"id": "black", "name": "Midnight Black", "color": "#37474f"},
    {"id": "cream", "name": "Snow Cream", "color": "#fff3e0"},
]


def recolor_image(img: Image.Image, skin: str) -> Image.Image:
    """Recolor cat fur while preserving eye speculars and outlines."""
    if skin == "orange":
        return img

    arr = np.array(img, dtype=np.float32)
    alpha = arr[:, :, 3]
    mask = alpha > 10

    r = arr[:, :, 0] / 255.0
    g = arr[:, :, 1] / 255.0
    b = arr[:, :, 2] / 255.0

    cmax = np.maximum(np.maximum(r, g), b)
    cmin = np.minimum(np.minimum(r, g), b)
    delta = cmax - cmin + 1e-6

    # Eye detection: green iris
    is_eye = mask & (g > 0.2) & (delta > 0.15) & (g > r + 0.06) & (g > b + 0.08)
    fur = mask & ~is_eye

    out = arr.copy()
    val = cmax

    if skin == "gray":
        gv = val * 0.95 * 255.0
        out[fur, 0] = gv[fur] * 0.97
        out[fur, 1] = gv[fur] * 0.99
        out[fur, 2] = gv[fur] * 1.04
    elif skin == "black":
        bv = np.clip(((val) ** 1.35) * 0.38 + 0.08, 0, 1.0) * 255.0
        out[fur, 0] = bv[fur] * 0.92
        out[fur, 1] = bv[fur] * 0.95
        out[fur, 2] = bv[fur] * 1.05
    elif skin == "cream":
        cv = np.clip(val * 0.42 + 0.58, 0, 1.0) * 255.0
        out[fur, 0] = cv[fur] * 1.00
        out[fur, 1] = cv[fur] * 0.97
        out[fur, 2] = cv[fur] * 0.90

    return Image.fromarray(out.astype(np.uint8))


def extract_cells(sheet_path: Path, count: int, cols: int = 5) -> list[Image.Image]:
    sheet = Image.open(sheet_path).convert("RGBA")
    return [
        sheet.crop((
            (i % cols) * CELL,
            (i // cols) * CELL,
            (i % cols + 1) * CELL,
            (i // cols + 1) * CELL,
        ))
        for i in range(count)
    ]


def align_and_scale(frames: list[Image.Image], ground_y: int) -> list[Image.Image]:
    """Shift frames so standing ground_y touches bottom of 256, then resize to OUT_CELL."""
    dy = 255 - ground_y
    res = []
    for f in frames:
        aligned = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        aligned.paste(f, (0, dy))
        res.append(aligned.resize((OUT_CELL, OUT_CELL), Image.LANCZOS))
    return res


def make_strip(frames: list[Image.Image]) -> Image.Image:
    strip = Image.new("RGBA", (OUT_CELL * len(frames), OUT_CELL), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * OUT_CELL, 0))
    return strip


def make_portrait(stand_frame: Image.Image) -> Image.Image:
    """Make 128x128 close-up portrait avatar of Kitty from standing frame."""
    # Head crop in original 256x256 is roughly (45..105, 65..125)
    head = stand_frame.crop((40, 60, 115, 135))
    head_scaled = head.resize((100, 100), Image.LANCZOS)
    canvas = Image.new("RGBA", (OUT_CELL, OUT_CELL), (0, 0, 0, 0))
    # Center on canvas
    canvas.paste(head_scaled, ((OUT_CELL - 100) // 2, (OUT_CELL - 100) // 2 + 5), head_scaled)
    return canvas


def main(run_dir_str: str | None = None) -> None:
    if run_dir_str:
        run_dir = Path(run_dir_str)
    else:
        # Default to latest yuva run
        candidates = sorted(Path("spriterrific-runs").glob("yuva-*"))
        if not candidates:
            print("No spriterrific run found in spriterrific-runs/!")
            sys.exit(1)
        run_dir = candidates[-1]

    print(f"Using run directory: {run_dir}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    raw_run = extract_cells(run_dir / "run" / "spritesheet.png", 20)
    raw_jump = extract_cells(run_dir / "jump" / "spritesheet.png", 25)
    raw_attack = extract_cells(run_dir / "attack" / "spritesheet.png", 25)
    raw_hurt = extract_cells(run_dir / "hurt" / "spritesheet.png", 25)

    # Idle breathing loop from standing frames 0..4
    idle_indices = [0, 1, 2, 3, 2, 1]
    raw_idle = [raw_jump[i] for i in idle_indices]

    # Standing frame ground Y
    ground_y = 230

    actions_raw = {
        "run": raw_run,
        "jump": raw_jump,
        "attack": raw_attack,
        "hurt": raw_hurt,
        "idle": raw_idle,
    }

    manifest_entries = {}

    for skin in SKINS:
        skin_id = skin["id"]
        print(f"Processing coat skin: {skin['name']} ({skin_id})...")

        # Process actions
        for act_name, frames in actions_raw.items():
            recolored_frames = [recolor_image(f, skin_id) for f in frames]
            aligned = align_and_scale(recolored_frames, ground_y)
            strip = make_strip(aligned)

            key = f"kitty_{skin_id}_{act_name}"
            out_file = OUT_DIR / f"{key}.png"
            strip.save(out_file)

            manifest_entries[key] = {
                "frameWidth": OUT_CELL,
                "frameHeight": OUT_CELL,
                "frames": len(aligned),
            }

        # Portrait
        recolored_stand = recolor_image(raw_jump[0], skin_id)
        portrait = make_portrait(recolored_stand)
        port_key = f"portrait_kitty_{skin_id}"
        portrait.save(OUT_DIR / f"{port_key}.png")
        manifest_entries[port_key] = {
            "width": OUT_CELL,
            "height": OUT_CELL,
        }

    # Also make default aliases pointing to orange
    for act_name in actions_raw:
        manifest_entries[f"kitty_{act_name}"] = manifest_entries[f"kitty_orange_{act_name}"]

    # Update manifest.json
    manifest = {}
    if MANIFEST_PATH.exists():
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    manifest.update(manifest_entries)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(f"Updated {MANIFEST_PATH} with {len(manifest_entries)} Kitty entries.")

    # Write kitty_skins.json
    SKINS_PATH.write_text(json.dumps(SKINS, indent=2), encoding="utf-8")
    print(f"Wrote {SKINS_PATH}.")
    print("All Kitty skins prepared successfully!")


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    main(arg)

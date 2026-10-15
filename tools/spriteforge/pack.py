"""Sprite strip packing, GIF preview generation, and manifest writing."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List
from PIL import Image


def pack_strip(frames: List[Image.Image], cell_w: int, cell_h: int) -> Image.Image:
    """Pack frames horizontally into a single-row PNG strip."""
    count = len(frames)
    strip = Image.new("RGBA", (cell_w * count, cell_h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.alpha_composite(f, (i * cell_w, 0))
    return strip


def save_preview_gif(
    frames: List[Image.Image],
    output_path: Path,
    fps: int = 24,
) -> None:
    """Save an animated GIF preview of the loop."""
    if not frames:
        return
    duration_ms = max(10, int(round(1000.0 / fps)))
    
    # Convert RGBA frames to palette mode with transparency
    gif_frames = []
    for f in frames:
        # Create RGB with solid neutral dark gray background for clear preview, or keep transparent
        rgb = Image.new("RGB", f.size, (25, 25, 30))
        rgb.paste(f, mask=f.split()[3])
        gif_frames.append(rgb)

    gif_frames[0].save(
        output_path,
        save_all=True,
        append_images=gif_frames[1:],
        duration=duration_ms,
        loop=0,
        optimize=True,
    )


def save_manifest(output_path: Path, data: Dict[str, Any]) -> None:
    """Save manifest.json with frame information and loop ranges."""
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

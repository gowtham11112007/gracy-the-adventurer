"""Chroma key green screen removal, despill, and frame extraction."""
from __future__ import annotations

import subprocess
from pathlib import Path
from typing import List
import numpy as np
from PIL import Image
import imageio_ffmpeg


def extract_video_frames(video_path: Path, output_dir: Path, fps: int = 24) -> List[Path]:
    """Extract frames from video at specified fps using bundled ffmpeg."""
    output_dir.mkdir(parents=True, exist_ok=True)
    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
    
    # Pattern for extracted frames
    frame_pattern = str(output_dir / "frame_%04d.png")
    
    cmd = [
        ffmpeg_exe,
        "-y",
        "-i", str(video_path),
        "-vf", f"fps={fps}",
        frame_pattern,
    ]
    
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    frames = sorted(output_dir.glob("frame_*.png"))
    return frames


def remove_green_screen(
    im: Image.Image,
    t_low: float = 12.0,
    t_high: float = 55.0,
    despill: bool = True,
) -> Image.Image:
    """Remove pure green background with soft edge blending and green despill.
    
    t_low: green excess below this is fully opaque.
    t_high: green excess above this is fully transparent.
    """
    rgba = im.convert("RGBA")
    arr = np.asarray(rgba).astype(np.float32)
    
    r = arr[..., 0]
    g = arr[..., 1]
    b = arr[..., 2]
    
    # Green excess over other channels
    max_rb = np.maximum(r, b)
    green_diff = g - max_rb
    
    # Smooth alpha ramp
    alpha = np.clip((t_high - green_diff) / (t_high - t_low), 0.0, 1.0) * 255.0
    
    # Despill: replace excess green in foreground / semi-transparent edges with max(r, b)
    if despill:
        spill = np.maximum(0.0, g - max_rb)
        # Suppress green down to max(r, b) where green dominates
        g_clean = np.where(g > max_rb, max_rb, g)
        # Blend clean green based on alpha
        g = np.where(alpha < 255.0, g_clean, g)
    
    # Pack back into uint8 RGBA
    out = np.dstack([
        np.clip(r, 0, 255).astype(np.uint8),
        np.clip(g, 0, 255).astype(np.uint8),
        np.clip(b, 0, 255).astype(np.uint8),
        np.clip(alpha, 0, 255).astype(np.uint8),
    ])
    
    return Image.fromarray(out, "RGBA")


def process_frames_chroma(input_frames: List[Path], output_dir: Path) -> List[Path]:
    """Process all extracted frames through chroma key and despill."""
    output_dir.mkdir(parents=True, exist_ok=True)
    clean_frames: List[Path] = []
    
    for f in input_frames:
        im = Image.open(f)
        keyed = remove_green_screen(im)
        out_path = output_dir / f.name
        keyed.save(out_path)
        clean_frames.append(out_path)
        
    return clean_frames

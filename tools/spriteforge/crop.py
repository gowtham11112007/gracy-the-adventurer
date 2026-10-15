"""Uniform bounding box alignment and cropping to prevent sprite jitter."""
from __future__ import annotations

from pathlib import Path
from typing import List, Tuple
import numpy as np
from PIL import Image


def get_alpha_bbox(im: Image.Image, alpha_thresh: int = 15) -> Tuple[int, int, int, int]:
    """Get (x0, y0, x1, y1) bounding box of pixels with alpha > alpha_thresh."""
    arr = np.asarray(im)
    if arr.shape[2] < 4:
        return (0, 0, im.width, im.height)
    alpha = arr[..., 3] > alpha_thresh
    if not alpha.any():
        return (0, 0, im.width, im.height)
    ys, xs = np.where(alpha)
    return (int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1))


def body_center_x(im: Image.Image, top_ratio: float = 0.15, bottom_ratio: float = 0.65) -> float:
    """Horizontal center of the torso and head so limbs don't make the sprite jitter."""
    arr = np.asarray(im)
    if arr.shape[2] < 4:
        return im.width / 2.0
    alpha = arr[..., 3] > 20
    h = arr.shape[0]
    band = alpha[int(h * top_ratio):int(h * bottom_ratio)]
    xs = np.where(band)[1]
    return float(xs.mean()) if len(xs) > 0 else float(im.width / 2.0)


def align_and_crop_frames(
    frames: List[Image.Image],
    padding: int = 8,
) -> Tuple[List[Image.Image], int, int]:
    """Crop all frames with a uniform cell size, centered body, feet pinned to bottom edge.
    
    Returns (aligned_frames, cell_width, cell_height).
    """
    if not frames:
        return ([], 0, 0)

    # 1. Measure all frames
    bboxes = [get_alpha_bbox(f) for f in frames]
    centers = [body_center_x(f) for f in frames]
    
    # Max height of character across frames
    max_h = max(b[3] - b[1] for b in bboxes)
    # Max half-width on left and right of the body center
    max_left_extent = max(centers[i] - bboxes[i][0] for i in range(len(frames)))
    max_right_extent = max(bboxes[i][2] - centers[i] for i in range(len(frames)))
    
    half_w = max(max_left_extent, max_right_extent)
    cell_w = int(np.ceil((half_w + padding) * 2))
    # Make sure width is even for clean pixel rendering
    if cell_w % 2 != 0:
        cell_w += 1
    cell_h = int(np.ceil(max_h + padding * 2))

    # 2. Render each frame into uniform cell:
    # Horizontally centered around body_center_x, bottom-aligned with character feet
    aligned_frames: List[Image.Image] = []
    
    # Global ground baseline: the lowest foot across frames (max y1)
    global_baseline = max(b[3] for b in bboxes)

    for i, f in enumerate(frames):
        cell = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        cx = centers[i]
        
        # Position so that cx lands exactly in the middle of cell_w
        paste_x = int(round(cell_w / 2.0 - cx))
        # Position so that global_baseline lands at (cell_h - padding)
        paste_y = int(round((cell_h - padding) - global_baseline))
        
        cell.alpha_composite(f, (paste_x, paste_y))
        aligned_frames.append(cell)

    return (aligned_frames, cell_w, cell_h)

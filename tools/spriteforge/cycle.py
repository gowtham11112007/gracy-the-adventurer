"""Loop and cycle detection algorithm adapted from Spriterrific."""
from __future__ import annotations

from typing import List, Optional, Tuple
from PIL import Image, ImageChops, ImageStat


def to_thumbnail(im: Image.Image, size: int = 64) -> Image.Image:
    """Convert frame to small grayscale thumbnail for fast pixel difference comparison."""
    # Convert RGBA to grayscale with black background for transparent pixels
    bg = Image.new("RGB", im.size, (0, 0, 0))
    if im.mode == "RGBA":
        bg.paste(im, mask=im.split()[3])
    else:
        bg.paste(im)
    return bg.convert("L").resize((size, size), Image.Resampling.BILINEAR)


def frame_distance(a: Image.Image, b: Image.Image) -> float:
    """Mean absolute pixel difference between two thumbnails."""
    return float(ImageStat.Stat(ImageChops.difference(a, b)).mean[0])


def find_cycle(
    frames: List[Image.Image],
    action: str = "run",
    typical_length: Optional[int] = None,
) -> Tuple[int, int]:
    """Find (start_index, length) of one clean two-step cycle for looping actions.
    
    If cycle detection is unclear, returns a robust fallback range.
    """
    total = len(frames)
    if total < 6:
        return (0, total)

    # Typical cycles at 24 fps: run is ~16 frames, walk is ~24 frames, idle is ~24-48
    if typical_length is None:
        if action == "run":
            typical_length = 16
            start_ratio = 0.18
        elif action == "walk":
            typical_length = 24
            start_ratio = 0.08
        else:
            typical_length = 24
            start_ratio = 0.05
    else:
        start_ratio = 0.10

    start = int(round(total * start_ratio))
    thumbs = [to_thumbnail(f) for f in frames]

    curve: dict[int, float] = {}
    max_k = min(len(thumbs) - start - 5, round(typical_length * 1.8))
    for k in range(1, max_k + 1):
        pairs = range(start, len(thumbs) - k)
        if len(pairs) < 6:
            break
        curve[k] = sum(frame_distance(thumbs[i], thumbs[i + k]) for i in pairs) / len(pairs)

    if not curve:
        return (start, min(typical_length, total - start))

    # Find local minima (dips)
    dips = [
        k for k in sorted(curve)
        if k - 1 in curve and k + 1 in curve
        and curve[k] <= min(curve[k - 1], curve[k + 1])
        and curve[k] <= 0.90 * max(curve[j] for j in range(1, k))
    ]

    # Step detection (half-cycle: single leg step)
    steps = [k for k in dips if 0.3 * typical_length <= k <= 0.75 * typical_length]
    if steps:
        first_step = steps[0]
        # Full cycle is two steps (~2 * first_step)
        cycles = [k for k in dips if 1.6 * first_step <= k <= 2.4 * first_step]
        if cycles:
            estimate = min(cycles, key=lambda k: abs(k - 2 * first_step))
            options = [
                (begin, length)
                for length in range(max(4, estimate - 2), min(total - start, estimate + 3))
                for begin in range(start, min(len(thumbs) - length, start + estimate // 2 + 1))
            ]
            if options:
                best = min(options, key=lambda o: frame_distance(thumbs[o[0]], thumbs[o[0] + o[1]]))
                return best

    # Fallback: scan for the best matching pair around typical_length
    best_pair = (start, min(typical_length, total - start))
    min_dist = float("inf")
    for length in range(max(6, typical_length - 4), min(total - start, typical_length + 6)):
        for begin in range(start, min(len(thumbs) - length, start + 10)):
            d = frame_distance(thumbs[begin], thumbs[begin + length])
            if d < min_dist:
                min_dist = d
                best_pair = (begin, length)

    return best_pair


def trim_oneshot(frames: List[Image.Image]) -> Tuple[int, int]:
    """Trim a one-shot action (jump, hurt, victory) to remove dead frames at start/end."""
    total = len(frames)
    if total <= 4:
        return (0, total)

    thumbs = [to_thumbnail(f) for f in frames]
    
    # Calculate motion velocity (difference between adjacent frames)
    diffs = [frame_distance(thumbs[i], thumbs[i + 1]) for i in range(total - 1)]
    max_diff = max(diffs) if diffs else 1.0
    thresh = max(0.5, 0.08 * max_diff)

    # Start: first frame where motion begins
    start = 0
    for i, d in enumerate(diffs):
        if d > thresh:
            start = max(0, i - 1)
            break

    # End: frame where motion has largely settled
    end = total
    for i in range(total - 2, start, -1):
        if diffs[i] > thresh:
            end = min(total, i + 3)
            break

    return (start, end - start)

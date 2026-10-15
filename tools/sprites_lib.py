"""Helpers for turning the Gemini sprite sheets in art/ into game-ready frames.

Only mechanical steps: remove the plain white background, find each sprite on a sheet,
crop, scale and pack. The artwork itself is never redrawn.
"""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi


def load(path):
    return Image.open(path).convert("RGB")


def remove_white_bg(img, thresh=232, halo=True):
    """Make the white background transparent. Only white that touches the sheet edge
    (or a large white area) is removed, so white clothes and eye whites stay."""
    a = np.asarray(img).astype(np.int16)
    lo, hi = a.min(2), a.max(2)
    whiteish = (lo > thresh) & (hi - lo < 22)
    lab, n = ndi.label(whiteish)
    if n == 0:
        bg = np.zeros(whiteish.shape, bool)
    else:
        edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
        sizes = ndi.sum(np.ones_like(lab), lab, index=np.arange(1, n + 1))
        big = np.where(sizes > 0.02 * whiteish.size)[0] + 1
        bg = np.isin(lab, np.union1d(edge[edge > 0], big))
    if halo:
        # eat the 1px light anti-alias fringe left around sprites
        fringe = ndi.binary_dilation(bg, iterations=1) & ~bg & (lo > 200) & (hi - lo < 30)
        bg |= fringe
    rgba = np.dstack([a.astype(np.uint8), np.where(bg, 0, 255).astype(np.uint8)])
    return Image.fromarray(rgba, "RGBA")


def find_items(rgba, merge=6, min_area=150):
    """Bounding boxes (x0, y0, x1, y1) of separate sprites, in reading order (rows, then left to right).
    Nearby pieces (sparkles, wings, motion lines) closer than `merge` px join their sprite."""
    alpha = np.asarray(rgba)[..., 3] > 0
    grown = ndi.binary_dilation(alpha, iterations=merge)
    lab, n = ndi.label(grown)
    boxes = []
    for i, sl in enumerate(ndi.find_objects(lab), start=1):
        m = (lab[sl] == i) & alpha[sl]
        if m.sum() < min_area:
            continue
        ys, xs = np.where(m)
        boxes.append((sl[1].start + xs.min(), sl[0].start + ys.min(),
                      sl[1].start + xs.max() + 1, sl[0].start + ys.max() + 1))
    # group into rows by vertical overlap, then sort each row left to right
    boxes.sort(key=lambda b: (b[1] + b[3]) / 2)
    rows, cur = [], []
    for b in boxes:
        if cur and (b[1] + b[3]) / 2 > max(c[3] for c in cur):
            rows.append(cur); cur = []
        cur.append(b)
    if cur:
        rows.append(cur)
    return [b for r in rows for b in sorted(r, key=lambda b: b[0])]


def crop(rgba, box, pad=0):
    x0, y0, x1, y1 = box
    return rgba.crop((x0 - pad, y0 - pad, x1 + pad, y1 + pad))


def scale_to_height(im, h):
    w = max(1, round(im.width * h / im.height))
    return im.resize((w, h), Image.LANCZOS)


def scale_by(im, f):
    return im.resize((max(1, round(im.width * f)), max(1, round(im.height * f))), Image.LANCZOS)


def body_center_x(im, top=0.12, bottom=0.6):
    """Horizontal center of the head and torso, so swinging arms don't make a sprite jitter sideways."""
    a = np.asarray(im)[..., 3] > 0
    h = a.shape[0]
    band = a[int(h * top):int(h * bottom)]
    xs = np.where(band)[1]
    return xs.mean() if len(xs) else im.width / 2


def pack_strip(frames, cell_w, cell_h, anchor="bottom", center=None):
    """Pack frames into one horizontal strip of equal cells (for Phaser spritesheets).
    Each frame sits on the cell's bottom edge, centered on its body."""
    sheet = Image.new("RGBA", (cell_w * len(frames), cell_h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        cx = center(f) if center else f.width / 2
        x = i * cell_w + round(cell_w / 2 - cx)
        y = cell_h - f.height if anchor == "bottom" else round((cell_h - f.height) / 2)
        sheet.alpha_composite(f, (max(i * cell_w, x), max(0, y)))
    return sheet


def debug_numbers(rgba, boxes, path):
    """Save a preview with each found sprite boxed and numbered (for mapping frames by eye)."""
    from PIL import ImageDraw
    bg = Image.new("RGBA", rgba.size, (200, 230, 200, 255))
    bg.alpha_composite(rgba)
    d = ImageDraw.Draw(bg)
    for i, (x0, y0, x1, y1) in enumerate(boxes):
        d.rectangle((x0, y0, x1, y1), outline=(255, 0, 0, 255), width=2)
        d.rectangle((x0, y0, x0 + 26, y0 + 18), fill=(255, 0, 0, 255))
        d.text((x0 + 3, y0 + 3), str(i), fill=(255, 255, 255, 255))
    bg.convert("RGB").save(path)

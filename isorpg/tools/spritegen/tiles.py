"""Plain test-map tiles and the arcane bolt, drawn with the same palette rules.

    python3 tiles.py
Writes isorpg/assets/gen/tiles/{floor.png,block.png} and isorpg/assets/gen/fx/bolt.png.
"""
import os
import numpy as np
from PIL import Image

from raster import OUTLINE, hexpal

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "gen"))

STONE = hexpal("#c9c3b2", "#a59f8f", "#857f72", "#635e55", "#433f3b")
WALL = hexpal("#b8b4d6", "#8e89b5", "#6b6692", "#4c4870", "#2f2c4a")


def diamond_mask(w, h):
    ys, xs = np.mgrid[0:h, 0:w]
    cx, cy = (w - 1) / 2, (h - 1) / 2
    return (np.abs(xs - cx) / (w / 2) + np.abs(ys - cy) / (h / 2)) <= 1.0


def floor_tile(tones, variant):
    w, h = 64, 32
    img = np.zeros((h, w, 4), np.uint8)
    m = diamond_mask(w, h)
    base = tones[1] if variant == 0 else tones[2]
    img[m, :3] = base
    img[m, 3] = 255
    ys, xs = np.mgrid[0:h, 0:w]
    # lit upper edges, dark lower edges, so neighbouring tiles read as a grid
    up = m & ~np.roll(m, 1, axis=0)
    down = m & ~np.roll(m, -1, axis=0)
    img[up & (xs < w // 2), :3] = tones[0]
    img[up & (xs >= w // 2), :3] = tones[0] if variant == 0 else tones[1]
    img[down, :3] = tones[3]
    return img


def block_tile(tones):
    """A 64x64 cube: diamond top, two side faces of 32 px. Origin at the bottom of the top diamond + 32."""
    w, h = 64, 64
    img = np.zeros((h, w, 4), np.uint8)
    top = np.zeros((h, w), bool)
    top[0:32] = diamond_mask(64, 32)
    ys, xs = np.mgrid[0:h, 0:w]
    left = (xs < 32) & (ys >= 16 + xs * 0.5 - 0.5) & (ys < 48 + xs * 0.5) & ~top
    right = (xs >= 32) & (ys >= 16 + (63 - xs) * 0.5 - 0.5) & (ys < 48 + (63 - xs) * 0.5) & ~top
    img[top, :3] = tones[0]
    img[left, :3] = tones[2]
    img[right, :3] = tones[3]
    for mm in (top, left, right):
        img[mm, 3] = 255
    body = img[..., 3] > 0
    # inner edges
    edge_top = top & ~np.roll(top, -1, axis=0)
    img[edge_top & body, :3] = tones[1]
    img[(xs == 31) & left | (xs == 32) & right, :3] = tones[4]
    # outline
    out = np.zeros_like(body)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        out |= np.roll(np.roll(body, dy, 0), dx, 1)
    out &= ~body
    big = np.zeros((h + 2, w + 2, 4), np.uint8)
    big[1:-1, 1:-1] = img
    o2 = np.zeros((h + 2, w + 2), bool)
    b2 = np.zeros((h + 2, w + 2), bool)
    b2[1:-1, 1:-1] = body
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        o2 |= np.roll(np.roll(b2, dy, 0), dx, 1)
    o2 &= ~b2
    big[o2, :3] = OUTLINE
    big[o2, 3] = 255
    return big


def bolt_frames(n=4, size=24):
    """Arcane bolt: a hard-edged core with two rings of glow, pulsing over n frames."""
    pal = hexpal("#ffffff", "#bafff7", "#55e2ea", "#2c9ec6", "#1d5b8e")
    frames = []
    ys, xs = np.mgrid[0:size, 0:size]
    c = (size - 1) / 2
    for f in range(n):
        ph = f / n * 2 * np.pi
        r = np.hypot(xs - c, ys - c)
        img = np.zeros((size, size, 4), np.uint8)
        rings = [(9.5 + 0.8 * np.sin(ph), pal[3], 110), (7.0 + 0.6 * np.sin(ph + 1), pal[2], 200),
                 (4.6 + 0.4 * np.sin(ph + 2), pal[1], 255), (2.4, pal[0], 255)]
        for rad, col, a in rings:
            sel = r <= rad
            img[sel, :3] = col
            img[sel, 3] = a
        # four sparkle spokes that rotate
        ang = np.arctan2(ys - c, xs - c) + ph / 2
        spoke = (np.abs(np.sin(ang * 2)) < 0.12) & (r < 11) & (r > 5)
        img[spoke, :3] = pal[1]
        img[spoke, 3] = 230
        frames.append(img)
    return np.concatenate(frames, axis=1)


def main():
    os.makedirs(os.path.join(OUT, "tiles"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "fx"), exist_ok=True)
    floor = np.concatenate([floor_tile(STONE, 0), floor_tile(STONE, 1)], axis=1)
    Image.fromarray(floor).save(os.path.join(OUT, "tiles", "floor.png"))
    Image.fromarray(block_tile(WALL)).save(os.path.join(OUT, "tiles", "block.png"))
    Image.fromarray(bolt_frames()).save(os.path.join(OUT, "fx", "bolt.png"))
    print("tiles + fx written")


if __name__ == "__main__":
    main()

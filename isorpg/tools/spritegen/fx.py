"""Spell effects. Every ability is an object you can draw: a comet, a pillar of fire, an ice lance.

    python3 fx.py
Writes strips under isorpg/assets/gen/fx/. Shapes are drawn at 4x and brought down by majority
vote like the characters, so effects stay crisp pixels instead of blurry glows. Large shapes keep
an empty middle (rings, shells) so a spell never hides the hero or blows out to white.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw

from raster import Canvas, Material, compose, hexpal, S

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "gen", "fx"))

PAL = {
    "arcane": hexpal("#ffffff", "#bafff7", "#55e2ea", "#2c9ec6", "#1d5b8e"),
    "astral": hexpal("#ffffff", "#fff1b0", "#f5c451", "#b46ad8", "#5b3394"),
    "fire": hexpal("#fffbe0", "#ffd65a", "#ff8a2a", "#e0402a", "#8a1f2a"),
    "ice": hexpal("#ffffff", "#d8f7ff", "#93dbf3", "#549fd2", "#2b5a92"),
}
SMOKE = hexpal("#a49cb0", "#7d7590", "#5d5670", "#403a52", "#2a2538")
CHAR = hexpal("#4a3a3a", "#3a2b30", "#2c2028", "#201820", "#140f18")


def vote_down(hi, s=S):
    """Majority vote of exact RGBA values in s x s blocks (transparent counts as a value)."""
    h, w = hi.shape[0] // s, hi.shape[1] // s
    hi = hi[:h * s, :w * s]
    key = (hi[..., 0].astype(np.int64) << 24) | (hi[..., 1].astype(np.int64) << 16) | \
          (hi[..., 2].astype(np.int64) << 8) | hi[..., 3].astype(np.int64)
    key = np.where(hi[..., 3] == 0, 0, key)
    kb = key.reshape(h, s, w, s).transpose(0, 2, 1, 3).reshape(h, w, s * s)
    eq = kb[..., :, None] == kb[..., None, :]
    score = eq.sum(-1) + (kb != 0) * 0.5  # ties go to the drawn pixel
    idx = np.argmax(score, -1)
    k = np.take_along_axis(kb, idx[..., None], -1)[..., 0]
    out = np.zeros((h, w, 4), np.uint8)
    out[..., 0] = (k >> 24) & 255
    out[..., 1] = (k >> 16) & 255
    out[..., 2] = (k >> 8) & 255
    out[..., 3] = k & 255
    return out


def hi_canvas(w, h):
    return Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))


def col(c, a=255):
    return (c[0], c[1], c[2], a)


def ell(d, cx, cy, rx, ry, fill):
    d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=fill)


def strip(frames):
    return np.concatenate(frames, axis=1)


def save(name, arr):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(arr).save(os.path.join(OUT, name))


# --------------------------------------------------------------------------- rune circles

def rune_circle(pal, frames=8, w=72, h=36):
    out = []
    rng = np.random.default_rng(7)
    glyphs = [rng.integers(0, 4, size=3) for _ in range(6)]
    for f in range(frames):
        im = Image.new("RGBA", (w * S, w * S), (0, 0, 0, 0))  # drawn top-down, squashed after
        d = ImageDraw.Draw(im)
        c = w * S / 2
        r0, r1 = c - 2 * S, c - 4 * S
        d.ellipse([c - r0, c - r0, c + r0, c + r0], outline=col(pal[2], 230), width=int(1.6 * S))
        d.ellipse([c - r1 + 6 * S, c - r1 + 6 * S, c + r1 - 6 * S, c + r1 - 6 * S], outline=col(pal[3], 200), width=int(1.2 * S))
        rot = f / frames * (math.pi / 3)
        # hexagram that turns one sixth per loop
        for k in range(2):
            pts = []
            for j in range(3):
                a = rot + k * math.pi / 3 + j * 2 * math.pi / 3
                pts.append((c + math.cos(a) * (r1 - 7 * S), c + math.sin(a) * (r1 - 7 * S)))
            d.polygon(pts, outline=col(pal[3], 170), width=int(1.0 * S))
        # six runes riding the ring, counter-rotating
        for j, g in enumerate(glyphs):
            a = -rot * 1.5 + j * math.pi / 3
            gx, gy = c + math.cos(a) * (r0 - 3.5 * S), c + math.sin(a) * (r0 - 3.5 * S)
            s = 1.6 * S
            shapes = [
                [(gx - s, gy - s), (gx + s, gy + s)], [(gx - s, gy + s), (gx + s, gy - s)],
                [(gx, gy - s * 1.3), (gx, gy + s * 1.3)], [(gx - s * 1.3, gy), (gx + s * 1.3, gy)],
            ]
            for gi in g[:2]:
                d.line(shapes[gi], fill=col(pal[1], 255), width=int(0.9 * S))
        squashed = im.resize((w * S, h * S), Image.NEAREST)
        out.append(vote_down(np.asarray(squashed)))
    return strip(out)


# --------------------------------------------------------------------------- comet

def comet(frames=6, size=80):
    pal = PAL["astral"]
    out = []
    head = np.array([size * 0.36, size * 0.68])
    back = np.array([0.55, -1.0])
    back /= np.linalg.norm(back)
    side = np.array([-back[1], back[0]])
    rng = np.random.default_rng(3)
    for f in range(frames):
        im = hi_canvas(size, size)
        d = ImageDraw.Draw(im)
        # tail: a tapering ribbon of discs, thin and see-through at the far end
        n = 22
        for i in range(n, 0, -1):
            u = i / n
            wob = math.sin(u * 9 + f * 1.7) * 2.2 * u
            p = head + back * (u * size * 0.62) + side * wob
            r = 7.5 * (1 - u) ** 0.8 + 0.8
            tone = 1 if u < 0.15 else 2 if u < 0.4 else 3 if u < 0.7 else 4
            a = 255 if u < 0.5 else 190 if u < 0.75 else 120
            ell(d, p[0], p[1], r, r, col(pal[tone], a))
        # sparks left behind
        for _ in range(7):
            u = rng.uniform(0.2, 1.0)
            p = head + back * (u * size * 0.62) + side * rng.uniform(-6, 6) * u
            ell(d, p[0], p[1], 0.7, 0.7, col(pal[0], 255))
        # head: a burning star-rock, hot side facing where it goes
        ell(d, head[0], head[1], 9.2, 9.2, col(pal[4]))
        ell(d, head[0] - 0.5, head[1] - 0.3, 7.9, 7.9, col(pal[3]))
        fwd = -back
        ell(d, head[0] + fwd[0] * 1.1, head[1] + fwd[1] * 1.1, 5.9, 5.9, col(pal[2]))
        ell(d, head[0] + fwd[0] * 2.2, head[1] + fwd[1] * 2.2, 3.6, 3.6, col(pal[1]))
        ell(d, head[0] + fwd[0] * 2.8 - 0.8, head[1] + fwd[1] * 2.8 - 0.8, 1.6, 1.6, col(pal[0]))
        out.append(vote_down(np.asarray(im)))
    return strip(out)


def shockwave(frames=8, w=128, h=64, pal=None):
    pal = pal or PAL["astral"]
    out = []
    for f in range(frames):
        t = (f + 1) / frames
        im = hi_canvas(w, h)
        d = ImageDraw.Draw(im)
        R = 8 + (w / 2 - 10) * t ** 0.6
        th = (5.5 * (1 - t) + 1.2) * (w / 128) ** 0.5
        tone = 0 if t < 0.25 else 1 if t < 0.5 else 2 if t < 0.75 else 3
        a = int(255 * (1 - 0.55 * t))
        cx, cy = w / 2, h / 2
        ell(d, cx, cy, R, R * 0.5, col(pal[tone], a))
        ell(d, cx, cy, max(R - th, 0.1), max(R - th, 0.1) * 0.5, (0, 0, 0, 0))
        # broken dust ring just inside
        R2 = R * 0.72
        for k in range(14):
            a0 = k * 2 * math.pi / 14 + t
            x, y = cx + math.cos(a0) * R2, cy + math.sin(a0) * R2 * 0.5
            ell(d, x, y, 1.6 * (1 - t) + 0.6, 0.9 * (1 - t) + 0.5, col(pal[3], int(a * 0.8)))
        out.append(vote_down(np.asarray(im)))
    return strip(out)


def scorch(w=72, h=36):
    im = hi_canvas(w, h)
    d = ImageDraw.Draw(im)
    cx, cy = w / 2, h / 2
    rng = np.random.default_rng(11)
    for k in range(9):
        a = k * 2 * math.pi / 9 + rng.uniform(-0.2, 0.2)
        r = rng.uniform(22, 32)
        d.line([(cx * S, cy * S), ((cx + math.cos(a) * r) * S, (cy + math.sin(a) * r * 0.5) * S)],
               fill=col(CHAR[1], 210), width=int(1.2 * S))
    ell(d, cx, cy, 20, 10, col(CHAR[2], 220))
    ell(d, cx, cy + 0.5, 14, 7, col(CHAR[3], 235))
    ell(d, cx, cy + 0.8, 8, 4, col(CHAR[4], 245))
    pal = PAL["astral"]
    for _ in range(10):
        a, r = rng.uniform(0, 2 * math.pi), rng.uniform(3, 17)
        ell(d, cx + math.cos(a) * r, cy + math.sin(a) * r * 0.5, 0.6, 0.6, col(pal[2] if rng.random() < 0.6 else pal[1]))
    return vote_down(np.asarray(im))


# --------------------------------------------------------------------------- fire

def flame_pillar(frames=8, w=26, h=52):
    pal = PAL["fire"]
    heights = [12, 26, 40, 44, 41, 44, 30, 14]
    widths = [6, 8.5, 9.5, 9.5, 9.0, 9.5, 7.5, 5.0]
    out = []
    ys, xs = np.mgrid[0:h * S, 0:w * S] / S
    for f in range(frames):
        img = np.zeros((h * S, w * S, 4), np.uint8)
        H, Wd = heights[f], widths[f]
        base = h - 2.0
        u = (base - ys) / H  # 0 at the base, 1 at the tip
        sway = 1.6 * np.sin(u * 5.5 + f * 1.3) * u
        cx = w / 2 + sway
        uc = np.clip(u, 0, 1)
        prof = np.where((u >= 0) & (u <= 1), Wd * np.sin(np.pi * uc ** 0.7) * (1 - uc) ** 0.35, 0)
        dx = np.abs(xs - cx)
        layers = [(1.0, 4 if f >= 6 else 3, 235), (0.72, 2, 255), (0.45, 1, 255), (0.2, 0, 255)]
        dying = f >= 6
        for scale, tone, a in layers:
            m = dx < prof * scale
            if scale < 0.5:
                m &= u < (0.55 if not dying else 0.25)
            c = (SMOKE[tone - 1] if dying and tone >= 3 else pal[tone])
            img[m] = col(c, a)
        # licks of flame breaking off the tip
        if 2 <= f <= 5:
            for k in range(2):
                ty = base - H - 3 - 4 * k - (f % 2) * 2
                tx = w / 2 + (2.5 if (f + k) % 2 else -2.5)
                m = ((xs - tx) ** 2 / 1.6 ** 2 + (ys - ty) ** 2 / 2.4 ** 2) < 1
                img[m] = col(pal[2 if k == 0 else 3], 255)
        if dying:
            for k in range(3):
                ty, tx = base - H - 4 - 6 * k, w / 2 + (k - 1) * 3
                m = ((xs - tx) ** 2 + (ys - ty) ** 2) < (2.6 - 0.5 * k) ** 2
                img[m] = col(SMOKE[2 + (k > 0)], 170 - 40 * k)
        out.append(vote_down(img))
    return strip(out)


# --------------------------------------------------------------------------- ice

ICE = Material("ice", hexpal("#ffffff", "#d8f7ff", "#93dbf3", "#549fd2", "#2b5a92"))
ICE_DEEP = Material("ice_deep", hexpal("#d8f7ff", "#93dbf3", "#6cbde6", "#3f7fb8", "#22457a"))


def _octa(part, c, axis, length_f, length_b, r, twist=0.0):
    axis = axis / np.linalg.norm(axis)
    up = np.array([0.0, 0.0, 1.0]) if abs(axis[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    a = np.cross(axis, up)
    a /= np.linalg.norm(a)
    b = np.cross(axis, a)
    ca, sa = math.cos(twist), math.sin(twist)
    a, b = a * ca + b * sa, -a * sa + b * ca
    tip, tail = c + axis * length_f, c - axis * length_b
    ring = [c + a * r, c + b * r, c - a * r, c - b * r]
    for i in range(4):
        q0, q1 = ring[i], ring[(i + 1) % 4]
        part.tri([tip, q0, q1])
        part.tri([tail, q1, q0])


def ice_lance(dirs=16, size=80):
    """A crystal spear rendered like the hero: z-buffer, cel shading by mask offsets, outline."""
    frames = []
    for k in range(dirs):
        th = k * 2 * math.pi / dirs
        fwd = np.array([math.cos(th), math.sin(th), 0.0])
        cv = Canvas(size, size, size / 2, size / 2)
        body = cv.part("lance", ICE, bands=(1.0, 2.2), highlight=0.8, vote=2.0)
        _octa(body, np.zeros(3), fwd, 24.0, 17.0, 4.3, twist=0.6)
        guard = cv.part("guard", ICE_DEEP, bands=(0.8, 1.6), vote=2.0)
        side = np.array([-fwd[1], fwd[0], 0.0])
        for sgn in (-1, 1):
            c = -fwd * 10 + side * sgn * 4.0
            _octa(guard, c, -fwd + side * sgn * 0.9, 5.5, 4.0, 1.9)
        out = compose(cv)
        frames.append(out["rgba"])
    return strip(frames)


def frozen_block(w=48, h=48):
    cv = Canvas(w, h, w / 2, h - 8)
    shards = [((0, 0, 9), (0.0, 0.1, 1.0), 13, 7, 6.2), ((-6, 1, 5), (-0.5, -0.1, 1.0), 10, 5, 4.2),
              ((6, -1, 5), (0.55, 0.0, 1.0), 9, 5, 4.0), ((2, -5, 4), (0.2, -0.6, 1.0), 8, 4, 3.4),
              ((-3, 5, 3), (-0.2, 0.7, 1.0), 7, 4, 3.0)]
    for i, (c, ax, lf, lb, r) in enumerate(shards):
        p = cv.part("shard%d" % i, ICE if i % 2 == 0 else ICE_DEEP, group="shard%d" % i, bands=(1.0, 2.4), highlight=1.0)
        _octa(p, np.array(c, float), np.array(ax, float), lf, lb, r, twist=0.4 * i)
    return compose(cv)["rgba"]


def ice_burst(frames=6, size=56):
    pal = PAL["ice"]
    rng = np.random.default_rng(5)
    shards = [(rng.uniform(0, 2 * math.pi), rng.uniform(1.6, 3.0), rng.uniform(1.8, 3.2)) for _ in range(12)]
    out = []
    for f in range(frames):
        t = (f + 1) / frames
        im = hi_canvas(size, size)
        d = ImageDraw.Draw(im)
        c = size / 2
        if f < 2:  # the flash of the break, as a hollow diamond
            r = 6 + 6 * f
            d.polygon([((c) * S, (c - r * 0.6) * S), ((c + r) * S, c * S), (c * S, (c + r * 0.6) * S), ((c - r) * S, c * S)],
                      outline=col(pal[0]), width=int(1.2 * S))
        for a, sp, sz in shards:
            dist = sp * 9 * t
            x = c + math.cos(a) * dist
            y = c + math.sin(a) * dist * 0.5 - 10 * t + 16 * t * t
            s = sz * (1 - 0.6 * t)
            tone = 0 if t < 0.4 else 1 if t < 0.7 else 2
            d.polygon([(x * S, (y - s) * S), ((x + s * 0.6) * S, y * S), (x * S, (y + s) * S), ((x - s * 0.6) * S, y * S)],
                      fill=col(pal[tone], 255 if t < 0.8 else 170))
        out.append(vote_down(np.asarray(im)))
    return strip(out)


# --------------------------------------------------------------------------- icons

def icon(glyph, pal, size=24):
    im = hi_canvas(size, size)
    d = ImageDraw.Draw(im)
    c = size / 2
    ell(d, c, c, 11.5, 11.5, (20, 12, 28, 255))
    ell(d, c, c, 10.5, 10.5, col(pal[3]))
    ell(d, c, c, 9.5, 9.5, (27, 22, 46, 255))
    base = vote_down(np.asarray(im))
    g = glyph
    gh, gw = g.shape[:2]
    scale = min(16 / gw, 16 / gh)
    gi = Image.fromarray(g).resize((max(1, int(gw * scale)), max(1, int(gh * scale))), Image.NEAREST)
    canvas = Image.fromarray(base)
    canvas.alpha_composite(gi, ((size - gi.width) // 2, (size - gi.height) // 2))
    return np.asarray(canvas)


def crop_alpha(a):
    ys, xs = np.where(a[..., 3] > 0)
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def main():
    for name, pal in PAL.items():
        save("rune_%s.png" % name, rune_circle(pal))
    c = comet()
    save("comet.png", c)
    save("shockwave.png", shockwave(w=208, h=104))
    save("scorch.png", scorch())
    fl = flame_pillar()
    save("flame.png", fl)
    save("fire_wave.png", shockwave(w=256, h=128, pal=PAL["fire"]))
    lance = ice_lance()
    save("ice_lance.png", lance)
    save("ice_burst.png", ice_burst())
    save("frozen.png", frozen_block())

    bolt = np.asarray(Image.open(os.path.join(OUT, "bolt.png")))[:, :24]
    icons = [
        icon(crop_alpha(bolt), PAL["arcane"]),
        icon(crop_alpha(c[:, :80]), PAL["astral"]),
        icon(crop_alpha(fl[:, 26 * 3:26 * 4]), PAL["fire"]),
        icon(crop_alpha(lance[:, 80 * 2:80 * 3]), PAL["ice"]),
    ]
    save("icons.png", strip(icons))
    print("fx written")


if __name__ == "__main__":
    main()

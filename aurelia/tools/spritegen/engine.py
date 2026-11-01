"""Aurelia sprite engine (Pillow + numpy only).

Pipeline per frame (mirrors the GRAYFALL post):
  pose dict -> shapes rasterised at 4x into material/tone/part buffers ->
  cel shading by mask offset -> majority-vote downsample -> internal seams ->
  1px outline -> face painted at final resolution -> generated normal map.
"""
import colorsys
import math

import numpy as np
from PIL import Image, ImageDraw

SS = 4  # supersample factor

# ----------------------------------------------------------------- geometry


def catmull(points, per_seg=6):
    """Catmull-Rom resample a polyline. Returns list of (x, y)."""
    if len(points) < 3:
        return list(points)
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(per_seg):
            t = s / per_seg
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t +
                       (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2 +
                       (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3)
                for k in range(2)))
    out.append(points[-1])
    return out


def ik2(root, target, l1, l2, bend):
    """Analytic 2-bone IK. bend = +1/-1 picks the side of the joint.
    Returns (joint, end)."""
    dx, dy = target[0] - root[0], target[1] - root[1]
    d = math.hypot(dx, dy)
    d = max(min(d, l1 + l2 - 1e-3), abs(l1 - l2) + 1e-3)
    if math.hypot(dx, dy) < 1e-6:
        ux, uy = 0.0, 1.0
    else:
        ux, uy = dx / math.hypot(dx, dy), dy / math.hypot(dx, dy)
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    jx = root[0] + ux * a + (-uy) * h * bend
    jy = root[1] + uy * a + ux * h * bend
    return (jx, jy), (root[0] + ux * d, root[1] + uy * d)


def lerp_pose(a, b, t):
    if isinstance(a, dict):
        return {k: lerp_pose(a[k], b[k], t) for k in a}
    if isinstance(a, (tuple, list)):
        return tuple(lerp_pose(x, y, t) for x, y in zip(a, b))
    if isinstance(a, str):
        return a if t < 0.5 else b
    return a + (b - a) * t


def smooth(t):
    return t * t * (3 - 2 * t)


# -------------------------------------------------------------------- masks


class Mask:
    """Supersampled drawing surface. Coordinates are in 1x pixels."""

    def __init__(self, size):
        self.size = size
        self.img = Image.new("L", (size * SS, size * SS), 0)
        self.d = ImageDraw.Draw(self.img)

    @staticmethod
    def _p(p):
        return (p[0] * SS, p[1] * SS)

    def circle(self, c, r):
        x, y = self._p(c)
        R = r * SS
        self.d.ellipse([x - R, y - R, x + R, y + R], fill=255)
        return self

    def ellipse(self, c, rx, ry, angle=0.0):
        a = math.radians(angle)
        pts = []
        for k in range(36):
            t = 2 * math.pi * k / 36
            ex, ey = rx * math.cos(t), ry * math.sin(t)
            pts.append((c[0] + ex * math.cos(a) - ey * math.sin(a),
                        c[1] + ex * math.sin(a) + ey * math.cos(a)))
        return self.poly(pts)

    def poly(self, pts):
        self.d.polygon([self._p(p) for p in pts], fill=255)
        return self

    def capsule(self, a, b, ra, rb=None):
        rb = ra if rb is None else rb
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L > 1e-6:
            nx, ny = -dy / L, dx / L
            self.poly([(a[0] + nx * ra, a[1] + ny * ra), (b[0] + nx * rb, b[1] + ny * rb),
                       (b[0] - nx * rb, b[1] - ny * rb), (a[0] - nx * ra, a[1] - ny * ra)])
        self.circle(a, ra)
        self.circle(b, rb)
        return self

    def ribbon(self, pts, w0, w1, spline=True):
        s = catmull(pts) if spline else pts
        n = len(s)
        for i in range(n - 1):
            t0, t1 = i / (n - 1), (i + 1) / (n - 1)
            self.capsule(s[i], s[i + 1], w0 + (w1 - w0) * t0, w0 + (w1 - w0) * t1)
        return self

    def array(self):
        return np.array(self.img) > 127


def shift(m, dx, dy):
    """Shift a bool mask by integer (dx, dy) with zero fill."""
    dx, dy = int(round(dx)), int(round(dy))
    out = np.zeros_like(m)
    h, w = m.shape
    ys0, ys1 = max(0, dy), min(h, h + dy)
    xs0, xs1 = max(0, dx), min(w, w + dx)
    out[ys0:ys1, xs0:xs1] = m[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out


def grid(size):
    ys, xs = np.mgrid[0:size * SS, 0:size * SS]
    return xs / SS, ys / SS


# ------------------------------------------------------------------ palette


def ramp(base, glossy=False):
    """5 tones: 0 deep, 1 shade, 2 base, 3 light, 4 highlight (hue-shifted)."""
    r, g, b = [c / 255 for c in base]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)

    def mk(dh, ms, mv):
        rr, gg, bb = colorsys.hsv_to_rgb((h + dh) % 1.0, min(1, s * ms), min(1, v * mv))
        return (int(rr * 255), int(gg * 255), int(bb * 255))

    return [mk(-0.05, 1.08, 0.36), mk(-0.025, 1.04, 0.62), mk(0, 1, 1),
            mk(0.012, 0.92, 1.14), mk(0.03, 0.40, 1.5 if glossy else 1.3)]


def hexc(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


OUTLINE = (26, 16, 34)


# ------------------------------------------------------------------- canvas


class Canvas:
    def __init__(self, size, materials):
        """materials: dict name -> (hex, glossy)."""
        self.size = size
        S = size * SS
        self.S = S
        self.key = np.zeros((S, S), np.uint16)
        self.tone = np.zeros((S, S), np.uint8)
        self.matidx = {}
        self.ramps = [[(0, 0, 0)] * 5]
        for i, (name, (hx, glossy)) in enumerate(materials.items(), start=1):
            self.matidx[name] = i
            self.ramps.append(ramp(hexc(hx), glossy))
        self.glossy = {self.matidx[n]: g for n, (_, g) in materials.items()}
        self.nparts = 0
        self.group = {}
        self.matof = {}
        self.xs, self.ys = grid(size)

    def paint(self, mat, mask, group=None, k=5, deep=True, cast=0, hi=True, shade=True,
              ramp_override=None):
        """Paint a part. mask: Mask or bool array. Light comes from the upper left."""
        m = mask.array() if isinstance(mask, Mask) else mask
        if not m.any():
            return None
        self.nparts += 1
        pid = self.nparts
        mi = self.matidx[mat]
        self.group[pid] = group or f"p{pid}"
        self.matof[pid] = mi
        before = self.key > 0
        tone = np.full(m.shape, 2, np.uint8)
        if shade:
            band = m & ~shift(m, -k, -k)           # lower-right edge strip
            wide = m & ~shift(m, -2 * k, -2 * k)
            tone[wide] = 1
            if deep:
                tone[band] = 0
        if hi:
            lit = m & ~shift(m, k, k)               # upper-left strip
            tone[lit & (tone == 2)] = 3
            if self.glossy.get(mi):
                spec = m & ~shift(m, int(k * 0.5), int(k * 0.5)) & ~shift(m, -2 * k, 0)
                tone[spec & (tone == 3)] = 4
        if cast:
            reg = shift(m, cast, cast) & ~m & before
            self.tone[reg] = np.maximum(self.tone[reg].astype(int) - 1, 0)
        self.key[m] = (pid << 8) | (mi << 4)
        self.tone[m] = tone[m]
        return pid

    def vote(self):
        n = self.size
        key = (self.key | self.tone.astype(np.uint16))
        key = np.where(self.key > 0, key, 0).astype(np.uint16)
        k = key.reshape(n, SS, n, SS).transpose(0, 2, 1, 3).reshape(n, n, SS * SS)
        eq = (k[:, :, :, None] == k[:, :, None, :]).sum(-1)
        score = eq * 2 + (k != 0)
        idx = score.argmax(-1)
        return np.take_along_axis(k, idx[..., None], -1)[..., 0]

    def finish(self, no_seam=()):
        """Downsample, add seams + outline. Returns dict of 1x buffers."""
        key = self.vote()
        part = (key >> 8).astype(np.int32)
        mat = ((key >> 4) & 15).astype(np.int32)
        tone = (key & 15).astype(np.int32)
        filled = part > 0
        # seams: back part pixel next to a different-group front part goes to deep tone
        seam = np.zeros_like(filled)
        for dx, dy in ((1, 0), (0, 1)):
            a = part
            b = np.roll(part, (-dy, -dx), (0, 1))
            valid = filled & (b > 0) & (a != b)
            if dx:
                valid[:, -1] = False
            if dy:
                valid[-1, :] = False
            ys, xs = np.nonzero(valid)
            for y, x in zip(ys, xs):
                pa, pb = a[y, x], b[y, x]
                ga, gb = self.group.get(pa), self.group.get(pb)
                if ga == gb or (ga, gb) in no_seam or (gb, ga) in no_seam:
                    continue
                back = (y, x) if pa < pb else (y + dy, x + dx)
                seam[back] = True
        tone = np.where(seam, 0, tone)
        rgba = np.zeros((self.size, self.size, 4), np.uint8)
        ramps = np.array(self.ramps, np.uint8)  # (mats, 5, 3)
        rgb = ramps[mat, np.clip(tone, 0, 4)]
        rgba[filled, :3] = rgb[filled]
        rgba[filled, 3] = 255
        # 1px outline (4-neighbour dilation), added last so it never eats the body
        grown = filled.copy()
        grown[1:, :] |= filled[:-1, :]
        grown[:-1, :] |= filled[1:, :]
        grown[:, 1:] |= filled[:, :-1]
        grown[:, :-1] |= filled[:, 1:]
        ol = grown & ~filled
        rgba[ol, :3] = OUTLINE
        rgba[ol, 3] = 255
        return {"rgba": rgba, "part": part, "mat": mat, "tone": tone, "filled": filled,
                "outline": ol}


# --------------------------------------------------------------------- face


def paint_face(buf, canvas, head, expr, skin="skin", eye=(40, 24, 44), blush=(236, 126, 118)):
    """Paint the face pixel by pixel at final resolution (only over skin)."""
    rgba, mat = buf["rgba"], buf["mat"]
    sm = canvas.matidx[skin]
    hx, hy = int(round(head[0])), int(round(head[1]))

    def put(dx, dy, col):
        x, y = hx + dx, hy + dy
        if 0 <= x < rgba.shape[1] and 0 <= y < rgba.shape[0] and mat[y, x] == sm and buf["filled"][y, x]:
            rgba[y, x, :3] = col

    E = {
        "neutral": [(1, 0), (1, 1), (5, 0), (5, 1)],
        "blink": [(0, 1), (1, 1), (4, 1), (5, 1)],
        "hurt": [(0, -1), (1, 0), (0, 1), (6, -1), (5, 0), (6, 1)],
        "dead": [(0, -1), (1, 1), (1, -1), (0, 1), (5, -1), (6, 1), (6, -1), (5, 1)],
        "focus": [(1, 0), (1, 1), (5, 0), (5, 1), (0, -1), (1, -1), (5, -1), (6, -2)],
        "happy": [(0, 1), (1, 0), (2, 1), (4, 1), (5, 0), (6, 1)],
        "angry": [(1, 0), (1, 1), (5, 0), (5, 1), (0, -1), (1, -1), (5, -2), (6, -1)],
    }
    for dx, dy in E.get(expr, E["neutral"]):
        put(dx, dy, eye)
    if expr in ("neutral", "blink", "focus", "happy", "angry"):
        put(0, 3, blush)
        put(5, 3, blush)
    mouth = {
        "neutral": [(3, 4)], "blink": [(3, 4)], "hurt": [(3, 4), (4, 4), (3, 5), (4, 5)],
        "dead": [(3, 4), (4, 4)], "focus": [(3, 4), (4, 4)], "happy": [(2, 4), (3, 5), (4, 5), (5, 4)],
        "angry": [(3, 5), (4, 4), (5, 5)],
    }
    for dx, dy in mouth.get(expr, mouth["neutral"]):
        put(dx, dy, (150, 56, 66) if expr in ("hurt", "focus") else (110, 50, 56))


# ------------------------------------------------------------------ normals


def erode(m):
    o = m.copy()
    o[1:, :] &= m[:-1, :]
    o[:-1, :] &= m[1:, :]
    o[:, 1:] &= m[:, :-1]
    o[:, :-1] &= m[:, 1:]
    o[0, :] = o[-1, :] = False
    o[:, 0] = o[:, -1] = False
    return o


def blur3(a):
    p = np.pad(a, 1, mode="edge")
    return sum(p[dy:dy + a.shape[0], dx:dx + a.shape[1]] for dy in range(3) for dx in range(3)) / 9.0


def normal_map(buf, depth=4):
    """Per-part dome height map -> RGB normal map (green = up)."""
    part = buf["part"]
    H = np.zeros(part.shape, np.float32)
    for pid in np.unique(part):
        if pid == 0:
            continue
        m = part == pid
        d = np.zeros(part.shape, np.float32)
        cur = m
        for _ in range(depth):
            cur = erode(cur)
            d += cur
        H = np.where(m, np.maximum(H, np.sqrt(d / depth + 0.04) * 1.6), H)
    H = blur3(H)
    gx = (np.roll(H, -1, 1) - np.roll(H, 1, 1)) * 0.5
    gy = (np.roll(H, -1, 0) - np.roll(H, 1, 0)) * 0.5
    nx, ny, nz = -gx * 1.2, gy * 1.2, np.ones_like(H)  # ny: up
    L = np.sqrt(nx * nx + ny * ny + nz * nz)
    out = np.zeros(part.shape + (4,), np.uint8)
    out[..., 0] = np.clip((nx / L * 0.5 + 0.5) * 255, 0, 255)
    out[..., 1] = np.clip((ny / L * 0.5 + 0.5) * 255, 0, 255)
    out[..., 2] = np.clip((nz / L * 0.5 + 0.5) * 255, 0, 255)
    out[..., 3] = np.where(buf["filled"] | buf["outline"], 255, 0)
    flat = buf["outline"]
    out[flat, 0], out[flat, 1], out[flat, 2] = 128, 128, 255
    return out


# ------------------------------------------------------------------- springs


def simulate_chain(anchors, rests, stiffness=0.14, damping=0.80, gravity=0.18, wind=0.0,
                   seglens=None, loop=False, floor=57.5):
    """Simulate a spring chain over a sequence of display frames.

    anchors: list of (x, y) pinned root per frame.
    rests:   list (per frame) of lists of rest points (len n) for the free joints.
    Returns per frame list of points [anchor, p1..pn].
    """
    n = len(rests[0])
    frames = len(anchors)
    passes = 2 if loop else 1
    seg = seglens or [math.hypot(rests[0][0][0] - anchors[0][0], rests[0][0][1] - anchors[0][1])]
    if seglens is None:
        pts0 = [anchors[0]] + list(rests[0])
        seg = [math.hypot(pts0[i + 1][0] - pts0[i][0], pts0[i + 1][1] - pts0[i][1]) for i in range(n)]
    p = [list(r) for r in rests[0]]
    prev = [list(r) for r in rests[0]]
    out = []
    for ps in range(passes):
        out = []
        for f in range(frames):
            a = anchors[f]
            for i in range(n):
                vx = (p[i][0] - prev[i][0]) * damping
                vy = (p[i][1] - prev[i][1]) * damping
                prev[i] = list(p[i])
                p[i][0] += vx + wind * (1 + 0.5 * math.sin(f * 0.9 + i)) + stiffness * (rests[f][i][0] - p[i][0])
                p[i][1] += vy + gravity + stiffness * (rests[f][i][1] - p[i][1])
            for _ in range(3):
                last = a
                for i in range(n):
                    dx, dy = p[i][0] - last[0], p[i][1] - last[1]
                    d = math.hypot(dx, dy) or 1e-6
                    p[i][0] = last[0] + dx / d * seg[i]
                    p[i][1] = last[1] + dy / d * seg[i]
                    if p[i][1] > floor:
                        p[i][1] = floor
                    last = p[i]
            out.append([tuple(a)] + [tuple(q) for q in p])
    return out

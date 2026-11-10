"""Painted texture atlas for the body, drawn in code: gradients, seams, stitching, embroidery, fold strokes,
hair strands and highlights. Every lofted part unwraps into one tile (u around, v along)."""
import numpy as np
from .look import PALETTE

SIZE = 2048
PAD = 2
LAYOUT = [("hair", 256, 1024), ("blade", 128, 1024), ("scarftail", 128, 768), ("tail", 256, 768), ("scabbard", 128, 768),
          ("sleeve", 384, 512), ("pants", 384, 512), ("boot", 384, 512), ("coat", 1024, 384), ("tunic", 384, 384),
          ("bracer", 256, 256), ("haircap", 256, 256), ("pauldron", 256, 256), ("grip", 128, 256),
          ("scarfwrap", 512, 128), ("belt", 512, 64), ("swatch", 1024, 64)]


def _pack():
    rects, x, y, rowh = {}, 0, 0, 0
    for name, w, h in sorted(LAYOUT, key=lambda t: -t[2]):
        if x + w > SIZE:
            x, y, rowh = 0, y + rowh, 0
        rects[name] = (x, y, w, h)
        x += w
        rowh = max(rowh, h)
    assert y + rowh <= SIZE, "atlas overflow"
    return rects


RECT = _pack()
TILES = {n: ((x + PAD) / SIZE, 1.0 - (y + h - PAD) / SIZE, (w - 2 * PAD) / SIZE, (h - 2 * PAD) / SIZE)
         for n, (x, y, w, h) in RECT.items()}
MATS = list(PALETTE.keys())
SWATCH = {m: ((RECT["swatch"][0] + 32 + 64 * i) / SIZE, 1.0 - (RECT["swatch"][1] + 32) / SIZE) for i, m in enumerate(MATS)}


def C(name):
    return np.array(PALETTE[name]["base"], np.float32)


def S(name):
    return np.array(PALETTE[name]["shade"], np.float32)


def mx(a, b, t):
    return np.asarray(a, np.float32) * (1 - t) + np.asarray(b, np.float32) * t


def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


class Paint:
    def __init__(self, img, rect):
        x, y, w, h = rect
        self.a = img[y:y + h, x:x + w]
        self.w, self.h = w, h
        self.U, self.V = np.meshgrid((np.arange(w) + 0.5) / w, 1.0 - (np.arange(h) + 0.5) / h)

    def put(self, m, c):
        m = np.clip(m, 0, 1)[..., None]
        self.a[:] = self.a * (1 - m) + np.asarray(c, np.float32) * m

    def grad(self, c0, c1, p=1.0, axis="v"):
        t = ((self.V if axis == "v" else self.U) ** p)[..., None]
        self.a[:] = np.asarray(c0, np.float32) * (1 - t) + np.asarray(c1, np.float32) * t

    def du(self, u):
        d = np.abs(self.U - u)
        return np.minimum(d, 1 - d) * self.w

    def dv(self, v):
        return np.abs(self.V - v) * self.h

    def line_u(self, u, wpx, c, a=1.0, v0=0.0, v1=1.0, taper=False):
        m = np.clip(wpx * 0.5 + 0.5 - self.du(u), 0, 1) * ((self.V >= v0) & (self.V <= v1))
        if taper:
            m = m * np.sin(np.pi * np.clip((self.V - v0) / (v1 - v0), 0, 1)) ** 0.55
        self.put(m * a, c)

    def line_v(self, v, wpx, c, a=1.0, u0=0.0, u1=1.0):
        self.put(np.clip(wpx * 0.5 + 0.5 - self.dv(v), 0, 1) * ((self.U >= u0) & (self.U <= u1)) * a, c)

    def dash_v(self, v, wpx, c, n, duty=0.55, a=1.0, u0=0.0, u1=1.0):
        m = np.clip(wpx * 0.5 + 0.5 - self.dv(v), 0, 1) * (np.mod(self.U * n, 1.0) < duty) * ((self.U >= u0) & (self.U <= u1))
        self.put(m * a, c)

    def dash_u(self, u, wpx, c, n, duty=0.55, a=1.0, v0=0.0, v1=1.0):
        m = np.clip(wpx * 0.5 + 0.5 - self.du(u), 0, 1) * (np.mod(self.V * n, 1.0) < duty) * ((self.V >= v0) & (self.V <= v1))
        self.put(m * a, c)

    def band_v(self, v0, v1, c, a=1.0, soft=1.5, u0=0.0, u1=1.0):
        m = np.clip((self.V - v0) * self.h / soft + 0.5, 0, 1) * np.clip((v1 - self.V) * self.h / soft + 0.5, 0, 1)
        self.put(m * ((self.U >= u0) & (self.U <= u1)) * a, c)

    def band_u(self, u0, u1, c, a=1.0, soft=1.5, v0=0.0, v1=1.0):
        m = np.clip((self.U - u0) * self.w / soft + 0.5, 0, 1) * np.clip((u1 - self.U) * self.w / soft + 0.5, 0, 1)
        self.put(m * ((self.V >= v0) & (self.V <= v1)) * a, c)

    def spot(self, u, v, ru, rv, c, a=1.0, soft=1.5):
        k = np.sqrt((self.du(u) / ru) ** 2 + (self.dv(v) / rv) ** 2)
        self.put(np.clip(0.5 - (k - 1) * min(ru, rv) / soft, 0, 1) * a, c)

    def ring(self, u, v, r, wpx, c, a=1.0):
        k = np.sqrt(self.du(u) ** 2 + self.dv(v) ** 2)
        self.put(np.clip(wpx * 0.5 + 0.5 - np.abs(k - r), 0, 1) * a, c)

    def diamond(self, u, v, ru, rv, c, a=1.0):
        self.put(np.clip(0.5 - (self.du(u) / ru + self.dv(v) / rv - 1) * min(ru, rv), 0, 1) * a, c)

    def stroke(self, pts, wpx, c, a=1.0, taper=True):
        X, Y = self.U * self.w, (1 - self.V) * self.h
        P = [(u * self.w, (1 - v) * self.h) for u, v in pts]
        n = len(P) - 1
        d = np.full(X.shape, 1e9)
        for i in range(n):
            (ax, ay), (bx, by) = P[i], P[i + 1]
            ex, ey = bx - ax, by - ay
            ee = ex * ex + ey * ey + 1e-9
            t = np.clip(((X - ax) * ex + (Y - ay) * ey) / ee, 0, 1)
            w = wpx * (np.sin(np.pi * np.clip((i + t) / n, 0.02, 0.98)) ** 0.6 if taper else 1.0)
            d = np.minimum(d, np.hypot(X - ax - ex * t, Y - ay - ey * t) - w * 0.5)
        self.put(np.clip(0.5 - d, 0, 1) * a, c)


# ----------------------------------------------------------------------------
# tile painters
# ----------------------------------------------------------------------------
GOLD, GOLD_D, GLOW = C("gold"), S("gold"), C("glow")
WHITE = np.array([1, 1, 1], np.float32)


def coat(t):
    """u 0..0.5: outside, from the wearer's left front edge round the back (u=.25) to the right front edge;
    u 0.5..1: lining. v: hem -> collar."""
    nv, dk, lt = C("coat"), mx(C("coat"), S("coat"), 0.6), mx(C("coat"), WHITE, 0.14)
    t.grad(mx(nv, dk, 0.55), nv, p=0.8)
    t.put(sstep(0.50, 0.92, t.V) * 0.55, lt)                                 # light catches chest and shoulders
    t.put(np.exp(-((t.V - 0.20) / 0.05) ** 2) * 0.55, dk)                    # shadow where the belt cinches
    for u in (0.125, 0.375):
        t.line_u(u, 2.2, dk, 0.9, v0=0.02, v1=0.80)
    t.line_u(0.25, 2.0, dk, 0.75, v0=0.02, v1=0.52)
    for u0 in (0.036, 0.464):                                                # frogging down both front panels
        t.line_u(u0, 2.0, GOLD, 0.95, v0=0.27, v1=0.88)
        for k in range(8):
            t.diamond(u0, 0.31 + k * 0.075, 5.5, 9, GOLD)
    for u0, u1 in ((0.062, 0.112), (0.388, 0.438)):                          # breast pocket welts
        t.line_v(0.64, 2.0, lt, 0.9, u0=u0, u1=u1)
        t.dash_v(0.625, 1.4, lt, 110, a=0.8, u0=u0, u1=u1)
    t.line_v(0.80, 2.0, dk, 0.8, u0=0.14, u1=0.36)                           # back yoke
    # crest on the back
    t.ring(0.25, 0.645, 30, 2.4, GOLD)
    t.diamond(0.25, 0.645, 9, 40, GOLD)
    t.diamond(0.25, 0.645, 40, 9, GOLD)
    t.diamond(0.25, 0.645, 14, 14, nv)
    t.spot(0.25, 0.645, 6.5, 6.5, GLOW)
    for du in (-0.06, 0.06):
        t.stroke([(0.25 + du, 0.61), (0.25 + du * 1.5, 0.66), (0.25 + du * 1.25, 0.71)], 3.2, GOLD)
    for k in range(6):                                                       # waist creases above the belt
        u = 0.06 + k * 0.076
        t.stroke([(u, 0.235), (u + 0.012, 0.275), (u + 0.006, 0.31)], 2.4, dk, 0.8)
    t.dash_v(0.045, 1.6, GOLD, 150, duty=0.5, a=0.9, u0=0.0, u1=0.5)
    # lining
    cr, crd = C("crimson"), mx(C("crimson"), S("crimson"), 0.5)
    t.band_u(0.5, 1.0, cr, soft=0.5)
    for k in range(12):
        for j in range(5):
            t.diamond(0.52 + k * 0.04 + (j % 2) * 0.02, 0.1 + j * 0.2, 7, 12, crd, 0.6)


def tunic(t):
    cm, sh = C("cream"), mx(C("cream"), S("cream"), 0.55)
    t.grad(mx(cm, sh, 0.6), cm, p=0.7)
    for u in (0.012, 0.988):
        t.line_u(u, 1.8, sh, 0.9, v0=0.0, v1=0.97)
    for k in range(9):
        t.spot(0.0, 0.12 + k * 0.095, 3.2, 3.2, GOLD_D)
    t.line_v(0.955, 2.2, GOLD, 1.0)
    t.dash_v(0.925, 1.4, sh, 90, a=0.9)
    for u in (0.25, 0.75):
        t.line_u(u, 1.6, sh, 0.7, v0=0.0, v1=0.8)
    for k in range(5):
        u = 0.045 + k * 0.012
        t.stroke([(u, 0.30 + k * 0.03), (u + 0.03, 0.36 + k * 0.03)], 1.8, sh, 0.7)


def sleeve(t):
    """v: shoulder (0) -> cuff (1). u = .25 is the underside."""
    nv, dk, lt = C("coat"), mx(C("coat"), S("coat"), 0.6), mx(C("coat"), WHITE, 0.14)
    t.grad(nv, mx(nv, dk, 0.35), p=1.0)
    t.put(np.exp(-(np.minimum(np.abs(t.U - 0.75), 1 - np.abs(t.U - 0.75)) / 0.13) ** 2) * 0.45, lt)   # light along the top
    t.line_u(0.25, 2.0, dk, 0.85)
    t.dash_v(0.115, 1.6, lt, 46, a=0.9)                                      # shoulder seam stitches
    t.line_v(0.135, 2.0, dk, 0.8)
    for v in (0.315, 0.355):                                                 # rank bands
        t.band_v(v, v + 0.020, GOLD, soft=1.2)
    for k, v in enumerate((0.62, 0.66, 0.705, 0.75)):                        # elbow creases
        u = 0.06 + 0.03 * (k % 2)
        t.stroke([(u, v), (u + 0.10, v + 0.012), (u + 0.20, v - 0.004)], 2.4, dk, 0.85)
        t.stroke([(u + 0.5, v + 0.01), (u + 0.58, v + 0.022), (u + 0.66, v + 0.006)], 2.0, dk, 0.6)
    t.dash_v(0.955, 1.4, lt, 46, a=0.8)


def bracer(t):
    le, dk, lt = C("leather"), mx(C("leather"), S("leather"), 0.7), mx(C("leather"), WHITE, 0.22)
    t.grad(mx(le, dk, 0.3), le, p=1.0)
    for k in range(7):                                                       # cross lacing along the top
        v = 0.12 + k * 0.118
        t.stroke([(0.66, v), (0.84, v + 0.085)], 2.6, lt, 0.95, taper=False)
        t.stroke([(0.84, v), (0.66, v + 0.085)], 2.6, dk, 0.95, taper=False)
    for u in (0.64, 0.86):
        t.dash_u(u, 1.6, lt, 22, a=0.9)
    t.line_u(0.25, 2.0, dk, 0.9)
    for v in (0.05, 0.95):
        t.dash_v(v, 1.6, lt, 30, a=0.9)


def belt(t):
    le, dk, lt = C("leather"), mx(C("leather"), S("leather"), 0.7), mx(C("leather"), WHITE, 0.25)
    t.grad(mx(le, dk, 0.35), mx(le, lt, 0.25), p=1.0)
    for v in (0.24, 0.76):
        t.dash_v(v, 1.6, lt, 120, a=0.95)
    for k in range(5):
        t.spot(0.08 + k * 0.03, 0.5, 2.6, 2.6, dk)
        t.spot(0.92 - k * 0.03, 0.5, 2.6, 2.6, dk)


def pants(t):
    """v: ankle (0) -> hip (1). u = 0: front, u = .25: outer side."""
    pn, dk, lt = C("pants"), mx(C("pants"), S("pants"), 0.7), mx(C("pants"), WHITE, 0.16)
    t.grad(mx(pn, dk, 0.5), pn, p=0.8)
    t.put(np.exp(-(np.minimum(t.U, 1 - t.U) / 0.10) ** 2) * sstep(0.35, 0.75, t.V) * 0.5, lt)        # thigh highlight
    t.band_u(0.236, 0.264, mx(C("coat"), WHITE, 0.05), soft=1.2)             # side stripe
    for u in (0.232, 0.268):
        t.line_u(u, 1.4, GOLD, 0.9)
    t.line_u(0.75, 1.8, dk, 0.9)
    # knee patch
    t.band_v(0.185, 0.335, mx(pn, lt, 0.5), u0=0.0, u1=0.105, soft=2.0)
    t.band_v(0.185, 0.335, mx(pn, lt, 0.5), u0=0.895, u1=1.0, soft=2.0)
    for v in (0.195, 0.325):
        t.dash_v(v, 1.4, lt, 70, a=0.9, u0=0.0, u1=0.10)
        t.dash_v(v, 1.4, lt, 70, a=0.9, u0=0.90, u1=1.0)
    for u in (0.10, 0.90):
        t.dash_u(u, 1.4, lt, 60, a=0.9, v0=0.195, v1=0.325)
    for k, v in enumerate((0.42, 0.47, 0.53)):                               # creases behind the knee and at the hip
        t.stroke([(0.40, v), (0.50, v - 0.02), (0.60, v)], 2.4, dk, 0.9)
    for k in range(4):
        t.stroke([(0.02 + k * 0.03, 0.86 - k * 0.02), (0.10 + k * 0.03, 0.80 - k * 0.02)], 2.2, dk, 0.8)
    t.line_v(0.82, 1.6, lt, 0.6, u0=0.10, u1=0.22)


def boot(t):
    """v: sole (0) -> top (1). u = 0: front."""
    le, dk, lt = C("leather"), mx(C("leather"), S("leather"), 0.75), mx(C("leather"), WHITE, 0.28)
    t.grad(mx(le, dk, 0.35), le, p=0.6)
    front = np.minimum(t.U, 1 - t.U)
    t.put((front < 0.20) * (t.V < 0.135) * 0.9, mx(le, dk, 0.55))            # toe cap
    t.dash_v(0.142, 1.6, lt, 90, a=0.9, u0=0.0, u1=0.205)
    t.dash_v(0.142, 1.6, lt, 90, a=0.9, u0=0.795, u1=1.0)
    t.put(np.exp(-(front / 0.06) ** 2) * np.exp(-((t.V - 0.075) / 0.03) ** 2) * 0.8, lt)   # toe shine
    t.put((np.abs(t.U - 0.5) < 0.16) * (t.V < 0.26) * 0.85, mx(le, dk, 0.5))  # heel counter
    t.dash_u(0.34, 1.4, lt, 40, a=0.8, v0=0.03, v1=0.26)
    t.dash_u(0.66, 1.4, lt, 40, a=0.8, v0=0.03, v1=0.26)
    t.band_u(0.965, 1.0, mx(le, dk, 0.4), v0=0.30, v1=0.90, soft=1.5)        # tongue
    t.band_u(0.0, 0.035, mx(le, dk, 0.4), v0=0.30, v1=0.90, soft=1.5)
    for k in range(7):                                                       # laces
        v = 0.34 + k * 0.075
        t.stroke([(0.0, v), (0.048, v + 0.05)], 2.6, mx(C("cream"), le, 0.15), 1.0, taper=False)
        t.stroke([(1.0, v), (0.952, v + 0.05)], 2.6, mx(C("cream"), le, 0.15), 1.0, taper=False)
        t.spot(0.05, v + 0.05, 3, 3, GOLD)
        t.spot(0.95, v + 0.05, 3, 3, GOLD)
    for k in range(3):
        t.stroke([(0.30, 0.31 + k * 0.03), (0.42, 0.295 + k * 0.03), (0.52, 0.31 + k * 0.03)], 2.2, dk, 0.8)


def scarfwrap(t):
    """u: around the roll, v: around the neck."""
    cr, dk, lt = C("crimson"), mx(C("crimson"), S("crimson"), 0.75), mx(C("crimson"), WHITE, 0.22)
    t.a[:] = cr
    t.put(np.exp(-((t.U - 0.30) / 0.10) ** 2) * 0.55, lt)
    t.put(np.exp(-(np.minimum(np.abs(t.U - 0.78), 1 - np.abs(t.U - 0.78)) / 0.12) ** 2) * 0.7, dk)
    for k in range(7):
        u = 0.06 + k * 0.135
        v0 = (k * 0.37) % 1.0
        t.stroke([(u, v0), (u + 0.02, v0 + 0.16), (u - 0.01, v0 + 0.34)], 2.4, dk, 0.9)
        t.stroke([(u + 0.05, v0 + 0.5), (u + 0.03, v0 + 0.62), (u + 0.06, v0 + 0.78)], 2.0, dk, 0.7)


def scarftail(t):
    """u 0..0.5: outer face across the width, 0.5..1: inner face. v: knot (0) -> tip (1)."""
    cr, dk, lt = C("crimson"), mx(C("crimson"), S("crimson"), 0.75), mx(C("crimson"), WHITE, 0.2)
    t.grad(mx(cr, dk, 0.25), cr, p=0.5)
    t.band_u(0.5, 1.0, mx(cr, dk, 0.55), soft=0.5)
    for u in (0.12, 0.33):
        t.line_u(u, 2.2, dk, 0.8, v0=0.02, v1=0.72, taper=True)
    t.line_u(0.24, 1.6, lt, 0.8, v0=0.10, v1=0.60, taper=True)
    for v0, v1, c in ((0.765, 0.795, C("cream")), (0.81, 0.822, GOLD), (0.845, 0.860, C("cream"))):
        t.band_v(v0, v1, c, u0=0.0, u1=0.5, soft=1.2)
    for k in range(9):
        t.line_u(0.03 + k * 0.055, 1.4, dk, 0.8, v0=0.93, v1=1.0)


def tail(t):
    """Coat tails. u 0..0.5: outside, 0.5..1: lining. v: waist (0) -> tip (1)."""
    nv, dk, lt = C("coat"), mx(C("coat"), S("coat"), 0.6), mx(C("coat"), WHITE, 0.14)
    t.grad(nv, mx(nv, dk, 0.5), p=1.0)
    t.line_u(0.25, 1.8, GOLD, 0.9, v0=0.06, v1=0.74)
    for k in range(7):
        t.diamond(0.25, 0.10 + k * 0.10, 7, 12, GOLD)
    t.diamond(0.25, 0.83, 16, 28, GOLD)
    t.diamond(0.25, 0.83, 8, 14, GLOW)
    for u in (0.11, 0.39):
        t.line_u(u, 1.8, dk, 0.7, v0=0.0, v1=0.86, taper=True)
    cr, crd = C("crimson"), mx(C("crimson"), S("crimson"), 0.5)
    t.band_u(0.5, 1.0, cr, soft=0.5)
    for k in range(9):
        t.diamond(0.75, 0.06 + k * 0.105, 16, 20, crd, 0.7)


def hair(t):
    """One lock: u 0..0.9 across (edge - ridge - edge), u > 0.9: underside. v: root (0) -> tip (1)."""
    base, sh = C("hair"), S("hair")
    root, tip = mx(base, sh, 0.50), np.array([0.70, 0.90, 0.95], np.float32)
    g = t.V[..., None]
    col = np.where(g < 0.35, root * (1 - g / 0.35) + base * (g / 0.35), base)
    k = np.clip((g - 0.80) / 0.20, 0, 1) ** 1.5
    t.a[:] = col * (1 - k * 0.5) + tip * (k * 0.5)
    x = np.abs(t.U / 0.9 * 2 - 1)                                            # 0 at the ridge, 1 at the lock's edges
    t.put((x > 0.80) * (t.U < 0.9) * sstep(0.80, 1.0, x) * 0.75, mx(sh, base, 0.15))
    for u, v0, v1, w, a in ((0.20, 0.10, 0.92, 2.6, 0.85), (0.34, 0.22, 0.80, 1.8, 0.6), (0.52, 0.05, 0.97, 2.2, 0.7),
                            (0.66, 0.28, 0.88, 1.8, 0.6), (0.76, 0.12, 0.72, 2.4, 0.8)):
        t.line_u(u, w, mx(sh, base, 0.1), a, v0=v0, v1=v1, taper=True)
    for u, v, ru, rv in ((0.27, 0.41, 9, 42), (0.44, 0.385, 12, 58), (0.60, 0.42, 8, 38), (0.12, 0.44, 6, 26)):
        t.diamond(u, v, ru, rv, WHITE, 0.95)                                 # painted shine
    t.band_u(0.9, 1.0, mx(sh, base, 0.05) * 0.86, soft=0.5)


def haircap(t):
    base, sh = C("hair"), S("hair")
    t.grad(mx(base, sh, 0.15), mx(base, sh, 0.45), p=1.0)
    rng = np.random.RandomState(4)
    for k in range(34):
        u = (k + rng.rand() * 0.6) / 34.0
        v0 = rng.rand() * 0.25
        t.line_u(u, 1.6 + rng.rand(), mx(sh, base, 0.1), 0.75, v0=v0, v1=min(1.0, v0 + 0.5 + rng.rand() * 0.4), taper=True)


def blade(t):
    """u: 0 edge, .25 ridge, .5 edge, .75 ridge. v: guard (0) -> tip (1)."""
    st, sh = C("steel"), S("steel")
    t.grad(mx(st, sh, 0.45), mx(st, WHITE, 0.4), p=0.8)
    for u in (0.0, 0.5):
        t.put(np.clip(1 - t.du(u) / 9.0, 0, 1) * 0.9, WHITE)                 # honed edges
    for u in (0.25, 0.75):
        t.line_u(u, 2.0, mx(sh, st, 0.2), 0.8)
        for k in range(5):                                                   # runes near the guard
            v = 0.07 + k * 0.035
            t.stroke([(u - 0.07, v), (u + 0.07, v + 0.012)], 2.2, GLOW, 0.95, taper=False)
            t.stroke([(u, v - 0.008), (u, v + 0.018)], 2.0, GLOW, 0.95, taper=False)


def grip(t):
    dk, lt = C("dark"), mx(C("dark"), WHITE, 0.30)
    t.a[:] = dk
    for k in range(-4, 16):
        v = k * 0.075
        t.stroke([(0.0, v), (1.0, v + 0.30)], 3.0, lt, 0.9, taper=False)
        t.stroke([(0.0, v + 0.30), (1.0, v)], 3.0, mx(dk, lt, 0.5), 0.9, taper=False)


def pauldron(t):
    nv, dk, lt = C("coat"), mx(C("coat"), S("coat"), 0.6), mx(C("coat"), WHITE, 0.2)
    t.grad(mx(nv, dk, 0.5), mx(nv, lt, 0.6), p=1.0)
    for k in range(8):
        t.line_u(k / 8.0, 2.0, dk, 0.8, v0=0.0, v1=0.78, taper=True)
    t.line_v(0.30, 2.6, GOLD, 0.95)
    t.dash_v(0.22, 2.0, GOLD, 16, duty=0.25, a=1.0)


def scabbard(t):
    nv, dk = mx(C("coat"), C("dark"), 0.55), C("dark")
    t.grad(nv, mx(nv, dk, 0.5), p=1.0)
    t.put(np.exp(-((t.U - 0.25) / 0.08) ** 2) * 0.5, mx(nv, WHITE, 0.35))
    for v0, v1 in ((0.0, 0.07), (0.20, 0.235), (0.90, 1.0)):
        t.band_v(v0, v1, GOLD, soft=1.2)
    for k in range(9):
        t.diamond(0.25, 0.30 + k * 0.065, 7, 16, GOLD, 0.95)
        t.diamond(0.75, 0.30 + k * 0.065, 7, 16, GOLD, 0.95)


PAINTERS = dict(coat=coat, tunic=tunic, sleeve=sleeve, bracer=bracer, belt=belt, pants=pants, boot=boot,
                scarfwrap=scarfwrap, scarftail=scarftail, tail=tail, hair=hair, haircap=haircap, blade=blade, grip=grip,
                pauldron=pauldron, scabbard=scabbard)


def build():
    """Returns the atlas as float32 RGBA (row 0 = top)."""
    img = np.zeros((SIZE, SIZE, 3), np.float32)
    img[:] = (0.5, 0.5, 0.5)
    for name, fn in PAINTERS.items():
        fn(Paint(img, RECT[name]))
    x, y, w, h = RECT["swatch"]
    for i, m in enumerate(MATS):
        img[y:y + h, x + 64 * i:x + 64 * (i + 1)] = PALETTE[m]["base"]
    out = np.ones((SIZE, SIZE, 4), np.float32)
    out[..., :3] = np.clip(img, 0, 1)
    return out

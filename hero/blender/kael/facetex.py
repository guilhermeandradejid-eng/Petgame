"""Anime face texture atlas, drawn with a small numpy vector rasteriser (signed-distance coverage).

The texture is a 2x2 atlas of expressions; every cell is the same front-on projection of the face:
    u = (x - X0) / SPAN, v = (z - Z0) / SPAN   (metres, character space, +x = character's left)
Cells: (0,0) neutral   (1,0) blink   (0,1) attack   (1,1) hurt      [col, row-from-top]
"""
import numpy as np

X0, Z0, SPAN = -0.13, 1.335, 0.26
EXPRESSIONS = ["neutral", "blink", "attack", "hurt"]
CELL = {"neutral": (0, 0), "blink": (1, 0), "attack": (0, 1), "hurt": (1, 1)}

SKIN = (1.0, 0.895, 0.815)
EYE_C = (0.0405, 1.449)
EYE_SCALE = 0.90


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def bez(p0, p1, p2, p3, n=18):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2, p3 = (np.asarray(p, float) for p in (p0, p1, p2, p3))
    return ((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * t * t * p2 + (t ** 3) * p3


def qbez(p0, p1, p2, n=16):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2 = (np.asarray(p, float) for p in (p0, p1, p2))
    return ((1 - t) ** 2) * p0 + 2 * (1 - t) * t * p1 + (t ** 2) * p2


def path(*segs):
    out = [segs[0]]
    for s in segs[1:]:
        out.append(s[1:])
    return np.concatenate(out)


class Canvas:
    def __init__(self, size, bg):
        self.n = size
        self.img = np.empty((size, size, 3), np.float32)
        self.img[:] = bg
        self.px = SPAN / size
        self.mirror = 1.0       # +1: character's left eye (x>0); -1: mirrored
        self.origin = (0.0, 0.0)
        self.scale = 1.0

    # local (eye) coordinates -> world metres
    def W(self, pts):
        p = np.asarray(pts, float).reshape(-1, 2)
        k = self.scale
        return np.stack([self.origin[0] + self.mirror * k * p[:, 0], self.origin[1] + k * p[:, 1]], 1)

    def _window(self, lo, hi, pad):
        n, px = self.n, self.px
        c0 = int(max(0, np.floor((lo[0] - pad - X0) / px)))
        c1 = int(min(n, np.ceil((hi[0] + pad - X0) / px)))
        r0 = int(max(0, np.floor((Z0 + SPAN - hi[1] - pad) / px)))
        r1 = int(min(n, np.ceil((Z0 + SPAN - lo[1] + pad) / px)))
        xs = X0 + (np.arange(c0, c1) + 0.5) * px
        zs = Z0 + SPAN - (np.arange(r0, r1) + 0.5) * px
        X, Z = np.meshgrid(xs, zs)
        return (slice(r0, r1), slice(c0, c1)), X, Z

    def _cov(self, d, soft):
        if soft:
            t = np.clip(0.5 - d / (2 * soft), 0, 1)
            return t * t * (3 - 2 * t)
        return np.clip(0.5 - d / self.px, 0, 1)

    def sd_poly(self, P, X, Z):
        d2 = np.full(X.shape, 1e9)
        inside = np.zeros(X.shape, bool)
        n = len(P)
        for i in range(n):
            a, b = P[i], P[(i + 1) % n]
            e = b - a
            ee = float(e @ e)
            if ee < 1e-18:
                continue
            wx, wz = X - a[0], Z - a[1]
            t = np.clip((wx * e[0] + wz * e[1]) / ee, 0, 1)
            dx, dz = wx - e[0] * t, wz - e[1] * t
            d2 = np.minimum(d2, dx * dx + dz * dz)
            if abs(e[1]) > 1e-12:
                cond = ((a[1] <= Z) != (b[1] <= Z)) & (X < a[0] + e[0] * (Z - a[1]) / e[1])
                inside ^= cond
        return np.where(inside, -1.0, 1.0) * np.sqrt(d2)

    def poly(self, pts, color, alpha=1.0, soft=0.0, clip=None, grad=None):
        """Fill polygon (local coords). grad=(z_top, color_top, z_bot, color_bot) vertical gradient (local z)."""
        P = self.W(pts)
        win, X, Z = self._window(P.min(0), P.max(0), 3 * self.px + 2 * soft)
        cov = self._cov(self.sd_poly(P, X, Z), soft) * alpha
        self._paint(win, X, Z, cov, color, clip, grad)

    def ellipse(self, c, rx, rz, color, alpha=1.0, soft=0.0, rot=0.0, clip=None, grad=None, world_offset=None):
        C = self.W([c])[0]
        if world_offset is not None:
            C = C + np.asarray(world_offset) * self.scale
        rx, rz, soft = rx * self.scale, rz * self.scale, soft * self.scale
        r = max(rx, rz)
        win, X, Z = self._window(C - r, C + r, 3 * self.px + 2 * soft)
        dx, dz = X - C[0], Z - C[1]
        a = np.radians(rot) * self.mirror if world_offset is None else np.radians(rot)
        ux, uz = dx * np.cos(a) + dz * np.sin(a), -dx * np.sin(a) + dz * np.cos(a)
        k = np.sqrt((ux / rx) ** 2 + (uz / rz) ** 2)
        d = (k - 1.0) * min(rx, rz)
        cov = self._cov(d, soft) * alpha
        self._paint(win, X, Z, cov, color, clip, grad)

    def stroke(self, pts, w0, w1, color, alpha=1.0, soft=0.0, clip=None, wmid=None):
        """Polyline stroke with half-width tapering w0 -> (wmid) -> w1."""
        P = self.W(pts)
        n = len(P)
        w0, w1 = w0 * self.scale, w1 * self.scale
        wmid = None if wmid is None else wmid * self.scale
        ws = np.empty(n)
        for i in range(n):
            t = i / (n - 1)
            if wmid is None:
                ws[i] = w0 + (w1 - w0) * t
            else:
                ws[i] = (w0 + (wmid - w0) * t * 2) if t < 0.5 else (wmid + (w1 - wmid) * (t - 0.5) * 2)
        wm = float(ws.max())
        win, X, Z = self._window(P.min(0), P.max(0), wm + 3 * self.px + 2 * soft)
        d = np.full(X.shape, 1e9)
        for i in range(n - 1):
            a, b = P[i], P[i + 1]
            e = b - a
            ee = float(e @ e)
            if ee < 1e-18:
                continue
            wx, wz = X - a[0], Z - a[1]
            t = np.clip((wx * e[0] + wz * e[1]) / ee, 0, 1)
            dx, dz = wx - e[0] * t, wz - e[1] * t
            d = np.minimum(d, np.sqrt(dx * dx + dz * dz) - (ws[i] + (ws[i + 1] - ws[i]) * t))
        cov = self._cov(d, soft) * alpha
        self._paint(win, X, Z, cov, color, clip, None)

    def mask_poly(self, pts, soft=0.0):
        """Full-canvas coverage of a polygon, for clipping."""
        P = self.W(pts)
        m = np.zeros((self.n, self.n), np.float32)
        win, X, Z = self._window(P.min(0), P.max(0), 3 * self.px + 2 * soft)
        m[win] = self._cov(self.sd_poly(P, X, Z), soft)
        return m

    def _paint(self, win, X, Z, cov, color, clip, grad):
        if clip is not None:
            cov = cov * clip[win]
        if grad is not None:
            zt, ct, zb, cb = grad
            zt, zb = self.origin[1] + zt * self.scale, self.origin[1] + zb * self.scale
            t = np.clip((zt - Z) / (zt - zb), 0, 1)[..., None]
            col = np.asarray(ct, np.float32) * (1 - t) + np.asarray(cb, np.float32) * t
        else:
            col = np.asarray(color, np.float32)
        a = cov[..., None].astype(np.float32)
        self.img[win] = self.img[win] * (1 - a) + col * a


# ----------------------------------------------------------------------------
# Face drawing
# ----------------------------------------------------------------------------
LASH = rgb("#2b2233")
LASH_TIP = rgb("#6b3a3a")
BROW = rgb("#6f7396")
SCLERA = rgb("#fdfaf6")
SCLERA_SH = rgb("#b9b4d2")
IRIS_TOP = rgb("#6a2a0a")
IRIS_MID = rgb("#e8861a")
IRIS_BOT = rgb("#ffd45a")
IRIS_RIM = rgb("#4a1c08")
PUPIL = rgb("#2a1006")
CREASE = rgb("#d99a88")
MOUTH = rgb("#a84c46")
MOUTH_IN = rgb("#7a2630")
TONGUE = rgb("#e8807a")
BLUSH = rgb("#ff8f84")
NOSE = rgb("#dc9482")


def eye_open(cv, lid=0.0, squint=0.0, look=(0.0, 0.0)):
    """Open eye. lid: 0..1 lowers the upper lid (determined look). squint raises the lower lid."""
    L = 0.0075 * lid
    S = 0.004 * squint
    I = (-0.0228, -0.0015)
    Pk = (0.0035, 0.0238 - L)
    O = (0.0268, 0.0128 - L * 0.55)
    up = path(bez(I, (-0.0205, 0.0165 - L * 0.7), (-0.009, 0.0238 - L), Pk),
              bez(Pk, (0.014, 0.0238 - L), (0.0225, 0.0195 - L * 0.8), O))
    Bm = (0.0055, -0.0208 + S)
    lo = path(bez(O, (0.0272, 0.001), (0.0205, -0.0165 + S), Bm),
              bez(Bm, (-0.007, -0.0218 + S), (-0.0185, -0.0125 + S * 0.6), I))
    opening = path(up, lo)
    clip = cv.mask_poly(opening)

    # sclera + lid shadow
    cv.poly(opening, SCLERA)
    sh = path(up, bez(O, (0.018, 0.010 - L), (0.0, 0.012 - L), (-0.0228, -0.0015)))
    cv.poly(sh, SCLERA_SH, alpha=0.95, soft=0.0022, clip=clip)

    # iris
    ic = (0.0012 + look[0], -0.0008 + look[1])
    cv.ellipse(ic, 0.0162, 0.0212, IRIS_RIM, clip=clip)
    cv.ellipse(ic, 0.0148, 0.0198, None, clip=clip,
               grad=(ic[1] + 0.016, IRIS_TOP, ic[1] - 0.019, IRIS_BOT))
    cv.ellipse((ic[0], ic[1] - 0.002), 0.0125, 0.0150, None, clip=clip, alpha=0.55, soft=0.003,
               grad=(ic[1] + 0.010, IRIS_MID, ic[1] - 0.016, IRIS_BOT))
    # pupil with a soft dark halo
    cv.ellipse((ic[0], ic[1] + 0.0015), 0.0088, 0.0118, IRIS_TOP, alpha=0.55, soft=0.003, clip=clip)
    cv.ellipse((ic[0], ic[1] + 0.0015), 0.0058, 0.0082, PUPIL, clip=clip)
    # lower glow crescent
    cv.ellipse((ic[0], ic[1] - 0.0125), 0.0098, 0.0052, rgb("#fff3a8"), alpha=0.85, soft=0.0016, clip=clip)
    # shadow of the upper lid across the iris
    cv.poly(path(up, bez(O, (0.016, 0.0125 - L), (0.0, 0.0155 - L), (-0.0228, 0.002))), IRIS_RIM, alpha=0.6,
            soft=0.002, clip=clip)
    # highlights: same screen side on both eyes (viewer's upper-left = character's right = -x)
    hc = cv.W([ic])[0]
    cv.ellipse((0, 0), 0.0050, 0.0062, (1, 1, 1), rot=-22, clip=clip,
               world_offset=((hc[0] - cv.origin[0]) / cv.scale - 0.0062, (hc[1] - cv.origin[1]) / cv.scale + 0.0082))
    cv.ellipse((0, 0), 0.0021, 0.0025, (1, 1, 1), alpha=0.95, clip=clip,
               world_offset=((hc[0] - cv.origin[0]) / cv.scale + 0.0066, (hc[1] - cv.origin[1]) / cv.scale - 0.0092))

    # upper lash: thick, tapering in at the nose side, flick at the temple side
    th = 0.0052
    top = path(bez((-0.0240, -0.0040), (-0.0222, 0.0172 - L * 0.7), (-0.010, 0.0282 - L), (0.0035, 0.0290 - L)),
               bez((0.0035, 0.0290 - L), (0.016, 0.0292 - L), (0.027, 0.0240 - L * 0.7), (0.0355, 0.0185 - L * 0.5)))
    flick = bez((0.0355, 0.0185 - L * 0.5), (0.0325, 0.0135 - L * 0.5), (0.0300, 0.0080 - L * 0.5),
                (0.0282, 0.0005 - L * 0.4), 10)
    back = bez((0.0282, 0.0005 - L * 0.4), (0.0285, 0.007 - L * 0.5), (0.0278, 0.0105 - L * 0.5), O, 8)
    lash = path(top, flick, back, up[::-1])
    cv.poly(lash, LASH, grad=(0.03, LASH, -0.004, LASH))
    # warm tint at the outer tip, like a painted lash
    cv.poly(path(flick, back, bez(O, (0.030, 0.015 - L * 0.5), (0.033, 0.0175 - L * 0.5), (0.0355, 0.0185 - L * 0.5), 6)),
            LASH_TIP, alpha=0.75, soft=0.0012)
    # small extra lash spike
    cv.poly([(0.0235, 0.0235 - L * 0.7), (0.0318, 0.0262 - L * 0.6), (0.0275, 0.0205 - L * 0.6)], LASH)
    # lower lash line (outer half only) and eyelid crease
    cv.stroke(bez((0.0268, 0.0020 - L * 0.4), (0.0262, -0.006), (0.0215, -0.0165 + S), (0.0085, -0.0212 + S), 14),
              0.0013, 0.0002, LASH, alpha=0.9)
    cv.stroke(bez((-0.014, 0.0285 - L * 0.6), (-0.002, 0.0355 - L * 0.6), (0.014, 0.0350 - L * 0.5), (0.0265, 0.0282 - L * 0.4), 16),
              0.0003, 0.0003, CREASE, alpha=0.85, wmid=0.0008)


def eye_closed(cv, tight=False):
    if tight:   # ">" shape: pain
        cv.stroke(qbez((-0.019, 0.010), (0.004, 0.004), (0.026, -0.003)), 0.0010, 0.0022, LASH, wmid=0.0026)
        cv.stroke(qbez((-0.017, -0.012), (0.004, -0.006), (0.026, -0.003)), 0.0008, 0.0020, LASH, wmid=0.0018)
        cv.stroke([(0.026, -0.003), (0.033, -0.001)], 0.0020, 0.0004, LASH)
    else:       # relaxed blink: downward arc with lashes
        arc = bez((-0.0225, -0.002), (-0.012, -0.0125), (0.012, -0.0135), (0.0275, -0.0015), 20)
        cv.stroke(arc, 0.0012, 0.0026, LASH, wmid=0.0030)
        cv.stroke([(0.0275, -0.0015), (0.0345, 0.0030)], 0.0024, 0.0003, LASH)
        cv.stroke([(0.020, -0.0088), (0.0265, -0.0125)], 0.0013, 0.0002, LASH)
        cv.stroke([(0.0105, -0.0118), (0.0135, -0.0165)], 0.0011, 0.0002, LASH)
        cv.stroke(bez((-0.014, 0.006), (-0.002, 0.011), (0.014, 0.0105), (0.0265, 0.005), 14), 0.0003, 0.0003, CREASE,
                  alpha=0.7, wmid=0.0007)


def brow(cv, inner_dz=0.0, outer_dz=0.0, lift=0.0):
    p0 = (-0.0215, 0.0415 + inner_dz + lift)
    p1 = (0.002, 0.0478 + lift + (inner_dz + outer_dz) * 0.35)
    p2 = (0.0315, 0.0405 + outer_dz + lift)
    cv.stroke(qbez(p0, p1, p2, 20), 0.0021, 0.0005, BROW, wmid=0.0019)


def draw_face(size, expr):
    cv = Canvas(size, SKIN)
    # soft cheek blush + faint under-fringe shade
    for sx in (1, -1):
        cv.mirror, cv.origin = sx, (0.0, 0.0)
        cv.ellipse((0.058, 1.411), 0.021, 0.0105, BLUSH, alpha=0.20, soft=0.007)
    cv.mirror, cv.origin = 1, (0.0, 0.0)
    cv.ellipse((0.0, 1.548), 0.12, 0.022, rgb("#eab7a6"), alpha=0.35, soft=0.012)

    for sx in (1, -1):
        cv.mirror, cv.origin, cv.scale = sx, (sx * EYE_C[0], EYE_C[1]), EYE_SCALE
        if expr == "neutral":
            eye_open(cv, lid=0.22)
            brow(cv)
        elif expr == "blink":
            eye_closed(cv)
            brow(cv, lift=-0.002)
        elif expr == "attack":
            eye_open(cv, lid=0.55, squint=0.45)
            brow(cv, inner_dz=-0.0105, outer_dz=0.0035)
        elif expr == "hurt":
            eye_closed(cv, tight=True)
            brow(cv, inner_dz=0.004, outer_dz=-0.0045, lift=-0.003)

    cv.mirror, cv.origin, cv.scale = 1, (0.0, 0.0), 1.0
    # nose: a tiny shadow tick under the tip
    cv.stroke(qbez((-0.0005, 1.4155), (0.0035, 1.4105), (0.0010, 1.4078), 8), 0.0003, 0.0003, NOSE, alpha=0.9, wmid=0.0011)
    # mouth
    if expr in ("neutral", "blink"):
        cv.stroke(bez((-0.0125, 1.3868), (-0.006, 1.3838), (0.006, 1.3838), (0.0125, 1.3872), 16), 0.0004, 0.0004, MOUTH,
                  wmid=0.0011)
        cv.stroke(qbez((-0.004, 1.3785), (0.0, 1.3776), (0.004, 1.3785), 8), 0.0002, 0.0002, NOSE, alpha=0.8, wmid=0.0008)
    elif expr == "attack":
        m = path(bez((-0.0135, 1.3905), (-0.006, 1.3925), (0.006, 1.3925), (0.0135, 1.3905), 12),
                 bez((0.0135, 1.3905), (0.0125, 1.378), (0.006, 1.3715), (0.0, 1.3715), 10),
                 bez((0.0, 1.3715), (-0.006, 1.3715), (-0.0125, 1.378), (-0.0135, 1.3905), 10))
        clip = cv.mask_poly(m)
        cv.poly(m, MOUTH_IN)
        cv.ellipse((0.0, 1.3725), 0.0085, 0.0052, TONGUE, clip=clip)
        cv.poly([(-0.012, 1.3925), (0.012, 1.3925), (0.011, 1.3878), (-0.011, 1.3878)], (1, 1, 1), clip=clip)
        cv.stroke(np.vstack([m, m[:1]]), 0.0007, 0.0007, MOUTH)
    else:  # hurt: clenched, wavy
        m = path(bez((-0.012, 1.3885), (-0.006, 1.3915), (0.006, 1.3915), (0.012, 1.3885), 12),
                 bez((0.012, 1.3885), (0.010, 1.380), (0.005, 1.3775), (0.0, 1.3775), 8),
                 bez((0.0, 1.3775), (-0.005, 1.3775), (-0.010, 1.380), (-0.012, 1.3885), 8))
        clip = cv.mask_poly(m)
        cv.poly(m, (1, 1, 1))
        cv.stroke([(-0.012, 1.3842), (0.012, 1.3842)], 0.0004, 0.0004, MOUTH, clip=clip)
        cv.stroke(np.vstack([m, m[:1]]), 0.0007, 0.0007, MOUTH)
    return cv.img


def build_atlas(cell=1024):
    """Returns float32 RGBA array (2*cell, 2*cell, 4), row 0 = top."""
    atlas = np.ones((2 * cell, 2 * cell, 4), np.float32)
    for name in EXPRESSIONS:
        c, r = CELL[name]
        atlas[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell, :3] = draw_face(cell, name)
    return atlas


def face_uv(x, z, expr="neutral"):
    """Blender UV (origin bottom-left) for a face point, in the cell of `expr`."""
    c, r = CELL[expr]
    u = (x - X0) / SPAN
    v = (z - Z0) / SPAN
    return ((c + u) * 0.5, ((1 - r) + v) * 0.5)

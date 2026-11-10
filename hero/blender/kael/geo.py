"""Tiny procedural-modelling kit: analytic lofts that write straight into one skinned mesh."""
import math
from math import sin, cos, pi, sqrt, radians
from mathutils import Vector


def ss(a, b, x):
    """Smoothstep from a to b (works with a > b)."""
    if a == b:
        return 0.0 if x < a else 1.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def spow(v, e):
    return math.copysign(abs(v) ** e, v)


class Curve:
    """Monotone cubic (PCHIP) interpolation of rows (t, v0, v1, ...). No overshoot between stations."""

    def __init__(self, rows):
        rows = sorted(rows, key=lambda r: r[0])
        self.t = [float(r[0]) for r in rows]
        self.v = [[float(x) for x in r[1:]] for r in rows]
        n, k = len(rows), len(rows[0]) - 1
        self.m = [[0.0] * k for _ in range(n)]
        for c in range(k):
            d = [(self.v[i + 1][c] - self.v[i][c]) / (self.t[i + 1] - self.t[i]) for i in range(n - 1)]
            for i in range(n):
                if i == 0:
                    self.m[i][c] = d[0]
                elif i == n - 1:
                    self.m[i][c] = d[-1]
                elif d[i - 1] * d[i] <= 0:
                    self.m[i][c] = 0.0
                else:
                    h0, h1 = self.t[i] - self.t[i - 1], self.t[i + 1] - self.t[i]
                    w1, w2 = 2 * h1 + h0, h1 + 2 * h0
                    self.m[i][c] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])

    def __call__(self, t):
        ts = self.t
        if t <= ts[0]:
            return list(self.v[0])
        if t >= ts[-1]:
            return list(self.v[-1])
        i = 0
        while ts[i + 1] < t:
            i += 1
        h = ts[i + 1] - ts[i]
        u = (t - ts[i]) / h
        h00, h10 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u
        h01, h11 = -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
        return [h00 * a + h10 * h * ma + h01 * b + h11 * h * mb
                for a, b, ma, mb in zip(self.v[i], self.v[i + 1], self.m[i], self.m[i + 1])]


def catmull(pts, n):
    """Resample a polyline of Vectors as a centripetal-ish Catmull-Rom curve with n+1 points (uniform in arc length)."""
    P = [Vector(p) for p in pts]
    ext = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    dense = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for s in range(16):
            u = s / 16.0
            dense.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u
                                + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3))
    dense.append(P[-1].copy())
    acc = [0.0]
    for a, b in zip(dense, dense[1:]):
        acc.append(acc[-1] + (b - a).length)
    out, j = [], 0
    for k in range(n + 1):
        d = acc[-1] * k / n
        while j < len(acc) - 2 and acc[j + 1] < d:
            j += 1
        seg = acc[j + 1] - acc[j]
        u = 0.0 if seg < 1e-12 else (d - acc[j]) / seg
        out.append(dense[j].lerp(dense[j + 1], max(0.0, min(1.0, u))))
    return out


def tangents(pts):
    out = []
    for i in range(len(pts)):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        out.append((b - a).normalized())
    return out


class Builder:
    """Accumulates one skinned mesh. Faces carry a material and per-corner UVs into the painted atlas:
    lofts with a `tile` are unwrapped (u around, v along); everything else samples its material's flat swatch."""

    def __init__(self, mats, tiles=None, swatch=None):
        self.mats = list(mats)
        self.mi = {n: i for i, n in enumerate(self.mats)}
        self.tiles = tiles or {}
        self.swatch = swatch or {}
        self.v, self.w, self.uv, self.ol = [], [], [], []
        self.f, self.fm, self.sharp = [], [], set()
        self.cuv = {}            # face index -> {vertex index: (u, v)}
        self.parts = {}          # name -> (v0, v1)
        self._part = None
        self.cur_ol = 1.0

    # -- bookkeeping ---------------------------------------------------------
    def begin(self, name, outline=1.0):
        self._part = (name, len(self.v))
        self.cur_ol = outline

    def end(self, weight_fn=None):
        name, v0 = self._part
        v1 = len(self.v)
        self.parts[name] = (v0, v1)
        if weight_fn is not None:
            for i in range(v0, v1):
                if self.w[i] is None:
                    self.w[i] = weight_fn(self.v[i])
        for i in range(v0, v1):
            assert self.w[i] is not None, "unweighted vertex in part " + name
        self._part = None
        return v0, v1

    def vert(self, p, w=None, uv=(0.0, 0.0)):
        self.v.append(Vector(p))
        self.w.append(w)
        self.uv.append(uv)
        self.ol.append(self.cur_ol)
        return len(self.v) - 1

    def face(self, idx, mat, uvs=None):
        idx = tuple(idx)
        if len(set(idx)) < 3:
            return
        if uvs is not None:
            self.cuv[len(self.f)] = {i: tuple(u) for i, u in zip(idx, uvs)}
        self.f.append(idx)
        self.fm.append(self.mi[mat])

    def mark_sharp(self, a, b):
        self.sharp.add((min(a, b), max(a, b)))

    def tile_uv(self, tile, u, v):
        u0, v0, w, h = self.tiles[tile]
        return (u0 + w * u, v0 + h * v)

    # -- primitives ----------------------------------------------------------
    def ring(self, pts, w=None, uvs=None):
        return [self.vert(p, w, uvs[i] if uvs else (0.0, 0.0)) for i, p in enumerate(pts)]

    def strip(self, r0, r1, mat, closed=True, uv0=None, uv1=None, tile_mats=None):
        """uv0 / uv1: per-point UVs of each ring, with one extra entry for the wrap-around when closed.
        tile_mats: only faces of these materials are unwrapped; the others keep their flat swatch."""
        n = len(r0)
        for j in range(n if closed else n - 1):
            k = (j + 1) % n
            m = mat(j) if callable(mat) else mat
            if m is not None:
                use = uv0 is not None and (tile_mats is None or m in tile_mats)
                uvs = (uv0[j], uv0[j + 1], uv1[j + 1], uv1[j]) if use else None
                self.face((r0[j], r0[k], r1[k], r1[j]), m, uvs)

    def cap(self, ring, mat, center=None, w=None, uv=None):
        c = center if center is not None else sum((self.v[i] for i in ring), Vector()) / len(ring)
        ci = len(self.v)
        self.v.append(Vector(c))
        self.w.append(w if w is not None else self.w[ring[0]])
        self.uv.append(self.uv[ring[0]])
        self.ol.append(self.cur_ol)
        n = len(ring)
        for j in range(n):
            self.face((ci, ring[j], ring[(j + 1) % n]), mat(j) if callable(mat) else mat, None if uv is None else (uv, uv, uv))
        return ci

    def loft(self, rings, mat, closed=True, caps=(True, True), w=None, uvfn=None, sharp_rings=(), sharp_cols=(),
             tile=None, ushift=0.0, vspan=(0.0, 1.0), vs=None, us=None, tile_mats=None):
        """rings: list of point lists. mat: name or fn(ring_index, col_index). tile: unwrap into that atlas tile
        (u around the ring, v along the loft; `vs` gives explicit v per ring). Returns the index grid."""
        grid = []
        for i, pts in enumerate(rings):
            uvs = [uvfn(i, j, p) for j, p in enumerate(pts)] if uvfn else None
            grid.append(self.ring(pts, w, uvs))
        n, R = len(grid[0]), len(grid)
        rows = None
        if tile:
            rows = []
            for i in range(R):
                t = vs[i] if vs else (i / (R - 1.0) if R > 1 else 0.0)
                v = vspan[0] + (vspan[1] - vspan[0]) * t
                rows.append([self.tile_uv(tile, (us[j] if us else (j / float(n) if closed else j / (n - 1.0))) + ushift, v)
                             for j in range(n + 1)])
        for i in range(R - 1):
            m = (lambda j, i=i: mat(i, j)) if callable(mat) else mat
            self.strip(grid[i], grid[i + 1], m, closed, rows[i] if rows else None, rows[i + 1] if rows else None, tile_mats)
        cm = (lambda i: (lambda j: mat(i, j))) if callable(mat) else (lambda i: mat)
        if caps[0]:
            self.cap(grid[0], cm(0), uv=rows[0][n // 2] if rows else None)
        if caps[1]:
            self.cap(grid[-1], cm(R - 2), uv=rows[-1][n // 2] if rows else None)
        for i in sharp_rings:
            r = grid[i]
            for j in range(n if closed else n - 1):
                self.mark_sharp(r[j], r[(j + 1) % n])
        for j in sharp_cols:
            for a, b in zip(grid, grid[1:]):
                self.mark_sharp(a[j % n], b[j % n])
        return grid


# -- ring generators -----------------------------------------------------------
def hring(z, a, bf, bb, cy=0.0, nf=2.0, nb=2.0, cx=0.0, M=20, phis=None, ab=None):
    """Horizontal super-ellipse ring. phi=0 is the character's front (-Y), 90 is +X.
    a: half width, bf/bb: front/back depth, nf/nb: squareness, ab: optional half width of the back half."""
    out = []
    angs = phis if phis is not None else [360.0 * j / M for j in range(M)]
    for ph in angs:
        s, c = sin(radians(ph)), cos(radians(ph))
        front = c >= 0
        e = nf if front else nb
        aw = a if (front or ab is None) else lerp(a, ab, min(1.0, -c * 1.5))
        out.append(Vector((cx + aw * spow(s, 2.0 / e), cy - (bf if front else bb) * spow(c, 2.0 / e), z)))
    return out


def fring(c, u, v, ru, rv, n=2.0, M=12, phase=0.0, flip=False):
    """Super-ellipse ring in an arbitrary frame: c + u*ru*cos + v*rv*sin. flip reverses the winding."""
    out = []
    for j in range(M):
        th = (-1.0 if flip else 1.0) * 2 * pi * j / M + phase
        out.append(c + u * (ru * spow(cos(th), 2.0 / n)) + v * (rv * spow(sin(th), 2.0 / n)))
    return out


def sym_phis(half):
    """Mirror a list of angles (0..180, inclusive of both ends) into a full symmetric ring."""
    return list(half) + [360.0 - p for p in reversed(half[1:-1])]

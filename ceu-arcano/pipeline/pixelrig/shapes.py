"""Formas vetoriais (SDF) que viram pixel art.

Cada forma é uma função de distância com sinal avaliada em coordenadas locais do osso
(pixels, y para baixo). Negativo = dentro. O rasterizador avalia a função no centro de cada
pixel, então não existe antialiasing: o resultado já é pixel art limpo, em qualquer rotação.
"""
from __future__ import annotations

import math
import numpy as np


# ---------------------------------------------------------------- primitivas

def _len(x, y):
    return np.sqrt(x * x + y * y)


def sd_circle(cx, cy, r):
    def f(x, y):
        return _len(x - cx, y - cy) - r
    return f, (cx - r, cy - r, cx + r, cy + r)


def sd_ellipse(cx, cy, rx, ry, rot=0.0):
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))

    def f(x, y):
        px, py = x - cx, y - cy
        lx, ly = c * px + s * py, -s * px + c * py
        k0 = _len(lx / rx, ly / ry)
        k1 = _len(lx / (rx * rx), ly / (ry * ry))
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)
    m = max(rx, ry)
    return f, (cx - m, cy - m, cx + m, cy + m)


def sd_capsule(a, b, ra, rb=None):
    """Cápsula com raios diferentes nas pontas (afunilada)."""
    if rb is None:
        rb = ra
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    h = math.hypot(dx, dy)
    if h < 1e-4:
        return sd_circle(ax, ay, max(ra, rb))
    ux, uy = dx / h, dy / h          # eixo da cápsula
    bb = (ra - rb) / h
    bb = max(-0.999, min(0.999, bb))
    aa = math.sqrt(1.0 - bb * bb)

    def f(x, y):
        px, py = x - ax, y - ay
        v = px * ux + py * uy          # ao longo
        u = np.abs(-px * uy + py * ux)  # perpendicular
        k = -bb * u + aa * v
        d_mid = aa * u + bb * v - ra
        d_a = _len(u, v) - ra
        d_b = _len(u, v - h) - rb
        return np.where(k < 0, d_a, np.where(k > aa * h, d_b, d_mid))
    r = max(ra, rb)
    return f, (min(ax, bx) - r, min(ay, by) - r, max(ax, bx) + r, max(ay, by) + r)


def sd_poly(points, rounding=0.0):
    pts = np.asarray(points, dtype=np.float64)
    n = len(pts)

    def f(x, y):
        d = (x - pts[0, 0]) ** 2 + (y - pts[0, 1]) ** 2
        s = np.ones_like(x)
        j = n - 1
        for i in range(n):
            vix, viy = pts[i]
            vjx, vjy = pts[j]
            ex, ey = vjx - vix, vjy - viy
            wx, wy = x - vix, y - viy
            ee = ex * ex + ey * ey
            t = np.clip((wx * ex + wy * ey) / (ee if ee > 1e-9 else 1e-9), 0.0, 1.0)
            bx, by = wx - ex * t, wy - ey * t
            d = np.minimum(d, bx * bx + by * by)
            c1 = y >= viy
            c2 = y < vjy
            c3 = ex * wy > ey * wx
            flip = (c1 & c2 & c3) | (~c1 & ~c2 & ~c3)
            s = np.where(flip, -s, s)
            j = i
        return s * np.sqrt(d) - rounding
    x0, y0 = pts.min(axis=0)
    x1, y1 = pts.max(axis=0)
    r = rounding
    return f, (x0 - r, y0 - r, x1 + r, y1 + r)


def sd_ribbon(points, radii):
    """Fita: união de cápsulas afuniladas ao longo de uma polilinha."""
    segs = [sd_capsule(points[i], points[i + 1], radii[i], radii[i + 1]) for i in range(len(points) - 1)]
    return sd_union(*segs)


def sd_union(*items):
    fns = [it[0] for it in items]
    bx = [it[1] for it in items]

    def f(x, y):
        d = fns[0](x, y)
        for g in fns[1:]:
            d = np.minimum(d, g(x, y))
        return d
    return f, (min(b[0] for b in bx), min(b[1] for b in bx), max(b[2] for b in bx), max(b[3] for b in bx))


def sd_smooth_union(a, b, k=3.0):
    fa, ba = a
    fb, bb_ = b

    def f(x, y):
        d1, d2 = fa(x, y), fb(x, y)
        h = np.clip(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0)
        return d2 * (1 - h) + d1 * h - k * h * (1 - h)
    return f, (min(ba[0], bb_[0]), min(ba[1], bb_[1]), max(ba[2], bb_[2]), max(ba[3], bb_[3]))


def sd_subtract(a, b):
    fa, ba = a
    fb, _ = b

    def f(x, y):
        return np.maximum(fa(x, y), -fb(x, y))
    return f, ba


def sd_intersect(a, b):
    fa, ba = a
    fb, bb_ = b

    def f(x, y):
        return np.maximum(fa(x, y), fb(x, y))
    return f, (max(ba[0], bb_[0]), max(ba[1], bb_[1]), min(ba[2], bb_[2]), min(ba[3], bb_[3]))


def chaikin(points, iterations=2, closed=True):
    """Arredonda um polígono de controle (corte de cantos de Chaikin)."""
    pts = [tuple(p) for p in points]
    for _ in range(iterations):
        out = []
        n = len(pts)
        rng = range(n) if closed else range(n - 1)
        if not closed:
            out.append(pts[0])
        for i in rng:
            p = pts[i]
            q = pts[(i + 1) % n]
            out.append((0.75 * p[0] + 0.25 * q[0], 0.75 * p[1] + 0.25 * q[1]))
            out.append((0.25 * p[0] + 0.75 * q[0], 0.25 * p[1] + 0.75 * q[1]))
        if not closed:
            out.append(pts[-1])
        pts = out
    return pts


def smooth_poly(points, iterations=2, rounding=0.0):
    return sd_poly(chaikin(points, iterations), rounding)


# ---------------------------------------------------------------- forma com material

class Shape:
    """Uma forma desenhável.

    mat      nome do material (rampa de cores)
    bevel    "altura" do travesseiro de sombreamento, em pixels
    level    nível fixo da rampa (sem sombreamento) ou None
    bias     soma no valor de luz (positivo clareia)
    line     desenha contorno interno sobre o que estiver atrás
    shadow   projeta sombra nas partes de trás
    when     (chave, valor) do contexto do quadro: só desenha se bater
    """

    __slots__ = ("fn", "bbox", "mat", "bevel", "level", "bias", "line", "shadow", "when", "group", "hi")

    def __init__(self, sdf, mat, bevel=3.0, level=None, bias=0.0, line=True, shadow=True,
                 when=None, group=None, hi=True):
        self.fn, self.bbox = sdf
        self.mat = mat
        self.bevel = bevel
        self.level = level
        self.bias = bias
        self.line = line
        self.shadow = shadow
        self.when = when
        self.group = group
        self.hi = hi


class Decal:
    """Grade de pixels feita à mão (rosto, detalhes minúsculos).

    rows: lista de strings; cada caractere é chave em `keys` -> (material, nível); '.' é vazio.
    (x, y): canto superior esquerdo em coordenadas locais.
    """

    __slots__ = ("rows", "x", "y", "keys", "when", "mirror", "line", "shadow", "group", "bbox")

    def __init__(self, rows, x, y, keys, when=None, mirror=False):
        self.rows = [r[::-1] for r in rows] if mirror else rows
        self.x, self.y = x, y
        self.keys = keys
        self.when = when
        self.line = False
        self.shadow = False
        self.group = None
        w = max(len(r) for r in rows)
        self.bbox = (x, y, x + w, y + len(rows))


def matches(when, ctx):
    if when is None:
        return True
    key, val = when
    cur = ctx.get(key)
    if isinstance(val, (tuple, list, set)):
        return cur in val
    return cur == val

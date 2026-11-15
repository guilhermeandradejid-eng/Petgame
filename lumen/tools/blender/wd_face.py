"""wd_face.py: orelhas/chifres (slot 'ears') e acessorios de rosto e pescoco (slot 'acc').

Orelhas no alto da cabeca levam meta top=True: o jogo esconde essas pecas quando o chapeu
cobre o topo da cabeca (qualquer chapeu que nao seja hair='keep').
"""
import math

from mathutils import Vector

import lp
from lp import Geo, ellipsoid, stack, tube
import hero_body as hb
from hero_body import HEAD_C, HEAD_R
from wd_base import piece, scalp

PINK = lp.hexc('#f4a3b4')
IVORY = lp.hexc('#f3e6c8')
HORN_D = lp.hexc('#4a3a5e')


def ring_path(center, R, u, v, n=14, rv=None):
    """Pontos de um circulo/elipse fechado (repete o primeiro no fim)."""
    c, u, v = Vector(center), Vector(u), Vector(v)
    rv = R if rv is None else rv
    pts = [c + u * (math.cos(lp.TAU * i / n) * R) + v * (math.sin(lp.TAU * i / n) * rv) for i in range(n)]
    return pts + [pts[0]]


def torus(center, R, r, u, v, n=14, m=5, mat='accent', rv=None):
    return tube(ring_path(center, R, u, v, n, rv), r, m, mat, cap_a=False, cap_b=False, up=tuple(Vector(u).cross(Vector(v))))


def on_head(x, z, k=1.0):
    """Ponto na superficie do rosto (frente) em (x, z), empurrado k-1 para fora."""
    p = hb.head_warp(Vector((x, hb.head_surface_y(x, z), z)))
    return HEAD_C + (p - HEAD_C) * k


def ear_cone(base, tip, w, th, mat, n=5, bulge=1.0):
    """Orelha triangular achatada (larga em X, fina em Y) da base ate a ponta."""
    base, tip = Vector(base), Vector(tip)
    mid = base.lerp(tip, 0.45) + Vector((0, 0, 0.0))
    path = [base - (tip - base).normalized() * 0.03, base, mid, tip]
    radii = [(w * 0.9, th * 0.9), (w, th), (w * 0.72 * bulge, th * 0.8), (w * 0.06, th * 0.15)]
    return tube(path, radii, n, mat, up=(0, 1, 0), square=0.25)


# ================================================================= ORELHAS
@piece('ears', 'ears_elfo', 'Orelhas Élficas', rarity=0, cost=0)
def ears_elfo():
    base = Vector((0.252, 0.03, 0.985))
    tip = Vector((0.44, 0.115, 1.135))
    path = [base, base.lerp(tip, 0.35) + Vector((0, -0.005, -0.012)), base.lerp(tip, 0.72) + Vector((0, 0, -0.006)), tip]
    g = tube(path, [(0.048, 0.02), (0.044, 0.017), (0.026, 0.012), (0.004, 0.003)], 6, 'skin', up=(0, 1, 0))
    g.grad('x', 0.25, 0.44, (0.86, 0.76, 0.8), lp.WHITE)
    return g.both().bind('head')


@piece('ears', 'ears_gato', 'Orelhas de Gato', rarity=1, cost=150, top=True)
def ears_gato():
    g = Geo()
    b = scalp(0.13, -0.02, HEAD_C.z + 0.2, 1.04)
    tip = b + Vector((0.035, 0.0, 0.15))
    outer = ear_cone(b, tip, 0.07, 0.03, 'hair')
    outer.grad('z', b.z, tip.z, (0.8, 0.75, 0.85), lp.WHITE)
    g.add(outer)
    ib = b + Vector((0.004, -0.024, 0.015))
    inner = ear_cone(ib, tip + Vector((-0.005, -0.016, -0.03)), 0.04, 0.012, 'vcol').color(PINK)
    g.add(inner)
    return g.both().bind('head')


@piece('ears', 'ears_raposa', 'Orelhas de Raposa', rarity=1, cost=180, top=True)
def ears_raposa():
    g = Geo()
    b = scalp(0.14, 0.0, HEAD_C.z + 0.19, 1.04)
    tip = b + Vector((0.07, 0.01, 0.2))
    split = b.lerp(tip, 0.74)
    body = tube([b - Vector((0.0, 0, 0.03)), b, b.lerp(tip, 0.45), split], [(0.07, 0.033), (0.085, 0.035), (0.062, 0.03), (0.032, 0.018)],
                5, 'hair', cap_b=False, up=(0, 1, 0), square=0.25)
    body.grad('z', b.z, split.z, (0.82, 0.76, 0.86), lp.WHITE)
    g.add(body)
    g.add(tube([split, tip], [(0.032, 0.018), (0.003, 0.003)], 5, 'dark', cap_a=False, up=(0, 1, 0), square=0.25))
    ib = b + Vector((0.004, -0.028, 0.018))
    g.add(ear_cone(ib, b.lerp(tip, 0.7) + Vector((0, -0.02, 0)), 0.045, 0.012, 'white'))
    return g.both().bind('head')


@piece('ears', 'ears_coelho', 'Orelhas de Coelho', rarity=1, cost=220, top=True)
def ears_coelho():
    g = Geo()
    for side in (1, -1):
        b = scalp(0.075 * side, 0.02, HEAD_C.z + 0.25, 1.03)
        p1 = b + Vector((0.025 * side, 0.01, 0.16))
        p2 = b + Vector((0.055 * side, 0.03, 0.32))
        tip = b + Vector((0.07 * side, 0.06, 0.42))
        e = tube([b - Vector((0, 0, 0.03)), b, p1, p2, tip], [(0.042, 0.02), (0.046, 0.022), (0.06, 0.022), (0.052, 0.02), (0.012, 0.008)],
                 6, 'hair', up=(0, 1, 0))
        e.grad('z', b.z, tip.z, (0.8, 0.75, 0.86), lp.WHITE)
        inner = tube([b + Vector((0, -0.016, 0.05)), p1 + Vector((0, -0.02, 0)), p2 + Vector((0, -0.019, 0)), tip + Vector((-0.004 * side, -0.012, -0.05))],
                     [(0.022, 0.006), (0.034, 0.006), (0.03, 0.006), (0.006, 0.004)], 5, 'vcol', up=(0, 1, 0)).color(PINK)
        e.add(inner)
        z0 = b.z

        def w(p, z0=z0):
            k = max(0.0, min(1.0, (p.z - z0 - 0.04) / 0.22))
            k = k * k * (3 - 2 * k)
            return {'head': 1.0 - k, 'hat1': k}
        e.bind_fn(w)
        g.add(e)
    return g


@piece('ears', 'ears_chifres', 'Chifres de Dragão', rarity=2, cost=400, top=True)
def ears_chifres():
    g = Geo()
    for side in (1, -1):
        a = Vector((0.13 * side, -0.07, 1.19))
        path = [a - Vector((0.0, -0.01, 0.04)), a, a + Vector((0.05 * side, 0.06, 0.09)), a + Vector((0.085 * side, 0.17, 0.13)),
                a + Vector((0.08 * side, 0.27, 0.1)), a + Vector((0.06 * side, 0.32, 0.05))]
        h = tube(path, [0.042, 0.045, 0.038, 0.028, 0.016, 0.003], 6, 'vcol')

        def col(p, c, a=a):
            t = max(0.0, min(1.0, (p.y - a.y) / 0.36))
            return lp.mixc(IVORY, HORN_D, t ** 1.4)
        h.tint(col)
        g.add(h)
        # anel dourado na base
        g.add(torus(a + Vector((0.012 * side, 0.012, 0.03)), 0.044, 0.009, (1, 0, 0), (0, 1, 0), 10, 4, 'accent'))
    return g.bind('head')


# ================================================================= ACESSORIOS
@piece('acc', 'acc_oculos', 'Óculos Redondos', rarity=0, cost=0)
def acc_oculos():
    g = Geo()
    for side in (1, -1):
        c = on_head(hb.EYE_X * side, hb.EYE_Z - 0.012) + Vector((0, -0.03, 0))
        g.add(torus(c, 0.06, 0.008, (1, 0, 0), (0, 0, 1), 14, 4, 'accent'))
        outer = c + Vector((0.06 * side, 0, 0.005))
        g.add(tube([outer, Vector((0.25 * side, -0.07, hb.EYE_Z + 0.005)), Vector((0.272 * side, 0.02, hb.EYE_Z - 0.01)),
                    Vector((0.262 * side, 0.07, hb.EYE_Z - 0.05))], 0.006, 4, 'accent'))
    l = on_head(-hb.EYE_X + 0.058, hb.EYE_Z) + Vector((0, -0.03, 0.012))
    r = on_head(hb.EYE_X - 0.058, hb.EYE_Z) + Vector((0, -0.03, 0.012))
    g.add(tube([l, (l + r) / 2 + Vector((0, -0.006, 0.012)), r], 0.006, 4, 'accent'))
    return g.bind('head')


@piece('acc', 'acc_tapaolho', 'Tapa-olho', rarity=0, cost=80)
def acc_tapaolho():
    cx = -hb.EYE_X
    g = hb.decal(cx, hb.EYE_Z, 0.062, 0.07, 12, 'dark', 0.014)
    g.add(hb.decal(cx + 0.015, hb.EYE_Z + 0.02, 0.012, 0.01, 6, 'accent', 0.017))
    # tira passando em volta da cabeca, mais alta atras
    pts = []
    rot = math.radians(-25)
    for i in range(23):
        th = lp.TAU * i / 22
        z = hb.EYE_Z + 0.03 + 0.11 * (1 - math.cos(th)) / 2
        k = math.sqrt(max(0.05, 1 - ((z - HEAD_C.z) / HEAD_R.z) ** 2)) * 1.1
        x, y = math.sin(th) * HEAD_R.x * k, -math.cos(th) * HEAD_R.y * k
        x, y = x * math.cos(rot) - y * math.sin(rot), x * math.sin(rot) + y * math.cos(rot)
        pts.append(Vector((x * 1.05, HEAD_C.y + y, z)))
    pts[-1] = pts[0]
    g.add(tube(pts, (0.011, 0.004), 4, 'dark', cap_a=False, cap_b=False))
    return g.bind('head')


@piece('acc', 'acc_mascara', 'Lenço de Bandido', rarity=1, cost=140)
def acc_mascara():
    s = ellipsoid(HEAD_R.x, HEAD_R.y, HEAD_R.z, n=16, rings=12, mat='primary', center=tuple(HEAD_C))
    s.warp(hb.head_warp)
    s.warp(lambda p: HEAD_C + (p - HEAD_C) * 1.05)
    zt, zb = hb.EYE_Z - 0.05, hb.EYE_Z - 0.2

    def keep(c):
        front = c.y < HEAD_C.y - 0.05
        band = zb + 0.05 < c.z < zt - 0.02
        return (front and zb < c.z < zt) or band
    s.keep_faces(keep)
    s.grad('z', zb, zt, (0.8, 0.76, 0.86), lp.WHITE)
    s.add(s.copy().warp(lambda p: HEAD_C + (p - HEAD_C) * 0.985).flip())
    # no atras com pontas soltas
    kz = hb.EYE_Z - 0.1
    knot = ellipsoid(0.035, 0.03, 0.03, 6, 4, 'primary', center=(0, HEAD_C.y + HEAD_R.y * 1.05, kz))
    for sx in (-1, 1):
        knot.add(tube([(0.01 * sx, HEAD_C.y + HEAD_R.y * 1.04, kz), (0.04 * sx, HEAD_C.y + HEAD_R.y * 1.1, kz - 0.06),
                       (0.05 * sx, HEAD_C.y + HEAD_R.y * 1.12, kz - 0.13)], [(0.03, 0.008), (0.028, 0.008), (0.022, 0.006)], 4, 'primary'))
    s.add(knot)
    return s.bind('head')


@piece('acc', 'acc_bigode', 'Bigodão', rarity=0, cost=60)
def acc_bigode():
    g = Geo()
    z0 = hb.EYE_Z - 0.078
    for side in (1, -1):
        pts = [on_head(0.0, z0, 1.0) + Vector((0, -0.012, 0)), on_head(0.045 * side, z0 - 0.014) + Vector((0, -0.014, 0)),
               on_head(0.088 * side, z0 - 0.008) + Vector((0, -0.012, 0)), on_head(0.112 * side, z0 + 0.018) + Vector((0, -0.01, 0)),
               on_head(0.1 * side, z0 + 0.04) + Vector((0, -0.012, 0))]
        g.add(tube(pts, [0.016, 0.02, 0.014, 0.009, 0.004], 6, 'hair'))
    return g.bind('head')


@piece('acc', 'acc_flor', 'Flor no Cabelo', rarity=0, cost=0)
def acc_flor():
    g = Geo()
    petal_c = lp.hexc('#ff7fa8')
    for i in range(5):
        a = 360.0 * i / 5
        p = ellipsoid(0.012, 0.03, 0.022, 6, 4, 'vcol', center=(0, 0.028, 0))
        p.grad('y', 0.0, 0.058, lp.mulc(petal_c, 0.8), lp.mixc(petal_c, lp.WHITE, 0.45))
        p.rot('X', a)
        g.add(p)
    g.add(ellipsoid(0.018, 0.018, 0.018, 6, 4, 'vcol', center=(0.008, 0, 0)).color(lp.hexc('#f2c64a')))
    for a in (200, 250):
        leaf = ellipsoid(0.006, 0.03, 0.014, 5, 3, 'vcol', center=(-0.004, 0.05, 0)).color(lp.hexc('#4fae6a'))
        leaf.rot('X', a)
        g.add(leaf)
    g.rot('Y', -25)
    g.move(0.245, 0.05, 1.09)
    return g.bind('head')


@piece('acc', 'acc_brincos', 'Argolas', rarity=0, cost=90)
def acc_brincos():
    g = Geo()
    for side in (1, -1):
        c = Vector((0.272 * side, 0.03, 0.89))
        g.add(torus(c, 0.03, 0.006, (0, 1, 0), (0, 0, 1), 12, 4, 'accent'))
        g.add(ellipsoid(0.01, 0.01, 0.012, 5, 3, 'glow', center=(0.272 * side, 0.03, 0.858)).color(lp.hexc('#7df9ff')))
    return g.bind('head')


@piece('acc', 'acc_cachecol', 'Cachecol', rarity=1, cost=160)
def acc_cachecol():
    g = torus((0, 0.005, 0.735), 0.125, 0.038, (1, 0, 0), (0, 1, 0), 16, 6, 'primary', rv=0.112)
    g.grad('z', 0.7, 0.77, (0.82, 0.78, 0.88), lp.WHITE)
    # ponta caindo na frente, com listras
    tail = tube([(0.055, -0.1, 0.74), (0.07, -0.135, 0.68), (0.075, -0.14, 0.6), (0.07, -0.13, 0.52)],
                [(0.045, 0.014), (0.048, 0.014), (0.05, 0.014), (0.05, 0.014)], 5, 'primary', up=(0, 1, 0), square=0.6)
    g.add(tail)
    for z in (0.62, 0.56):
        g.add(tube([(0.074, -0.142, z + 0.012), (0.074, -0.142, z - 0.012)], (0.053, 0.017), 5, 'secondary', up=(0, 1, 0), square=0.6))
    for i in range(5):
        x = 0.05 + i * 0.012
        g.add(tube([(x, -0.13, 0.52), (x + 0.002, -0.13, 0.49)], 0.005, 3, 'secondary'))
    return g.bind('chest')

"""wd_back.py: pecas das costas (slot 'back'): capas, mochilas, asas, caudas, casco e espadao.

Capas usam a cadeia de ossos cape1-cape3 e caudas a tail1-tail2: no jogo esses ossos tem
fisica de mola, entao as pecas balancam sozinhas com o movimento.
"""
import math

from mathutils import Vector

import lp
from lp import Geo, box, cyl, ellipsoid, poly_extrude, sheet, stack, tube
from wd_base import piece

GOLD = lp.hexc('#e9b949')
CAPE_STOPS = [(0.36, 'cape3'), (0.46, 'cape2'), (0.6, 'cape1'), (0.7, 'chest')]


def cape_rows(z_top, z_bot, r_top, r_bot, a_top, a_bot, rows=7, cols=9, y_push=0.03, hem_wave=0.0):
    """Linhas de pontos de uma capa que envolve as costas (angulo 0 = bem atras)."""
    out = []
    for r in range(rows):
        t = r / (rows - 1)
        z = z_top + (z_bot - z_top) * t
        rad = r_top + (r_bot - r_top) * (t ** 0.75)
        amax = math.radians(a_top + (a_bot - a_top) * t)
        row = []
        for c in range(cols):
            u = c / (cols - 1)
            a = -amax + 2 * amax * u
            zz = z + (hem_wave * math.sin(u * math.pi * 3) if r == rows - 1 else 0.0)
            row.append((math.sin(a) * rad, 0.02 + math.cos(a) * rad * 0.82 + y_push * t, zz))
        out.append(row)
    return out


def strap(path, w=0.022, th=0.007, mat='leather'):
    return tube(path, (w, th), 4, mat, square=0.7)


def shoulder_straps(y_back=0.15, z_end=0.5, mat='leather'):
    g = Geo()
    for s in (1, -1):
        g.add(strap([(0.075 * s, y_back, 0.66), (0.085 * s, 0.07, 0.75), (0.09 * s, -0.06, 0.735), (0.105 * s, -0.115, 0.63),
                     (0.11 * s, -0.122, z_end)], mat=mat))
    return g


# ================================================================= CAPAS
@piece('back', 'back_capa', 'Capa de Viagem', rarity=0, cost=0)
def back_capa():
    g = sheet(cape_rows(0.725, 0.3, 0.13, 0.21, 62, 52, 7, 9, 0.035, 0.012), 'primary', 'secondary', thickness=0.012)
    g.grad('z', 0.3, 0.72, (0.78, 0.74, 0.86), lp.WHITE)
    g.bind_axis('z', CAPE_STOPS)
    cord = tube([(-0.118, 0.07, 0.722), (-0.1, -0.08, 0.705), (0.0, -0.125, 0.695), (0.1, -0.08, 0.705), (0.118, 0.07, 0.722)], 0.011, 5, 'accent')
    cord.add(ellipsoid(0.022, 0.012, 0.022, 6, 4, 'accent', center=(0, -0.13, 0.695)))
    g.add(cord.bind('chest'))
    return g


@piece('back', 'back_capa_real', 'Manto Real', rarity=2, cost=480)
def back_capa_real():
    g = sheet(cape_rows(0.73, 0.07, 0.14, 0.27, 66, 58, 9, 11, 0.07, 0.02), 'primary', 'secondary', thickness=0.014)
    g.grad('z', 0.07, 0.72, (0.72, 0.68, 0.84), lp.WHITE)
    # barra dourada na beira de baixo
    hem = []
    for row in cape_rows(0.11, 0.07, 0.262, 0.27, 59, 58, 2, 11, 0.0, 0.02):
        hem.append([(x, y + 0.004 + 0.07, z) for x, y, z in row])
    g.add(sheet(hem, 'accent', 'accent', thickness=0.004))
    g.bind_axis('z', [(0.2, 'cape3'), (0.38, 'cape2'), (0.56, 'cape1'), (0.7, 'chest')])
    # gola de pele em volta do pescoco e broche
    fur = Geo()
    pts = [Vector((math.cos(lp.TAU * i / 16) * 0.155, 0.015 + math.sin(lp.TAU * i / 16) * 0.13, 0.735)) for i in range(16)]
    fur.add(tube(pts + [pts[0]], 0.05, 6, 'white', cap_a=False, cap_b=False))
    for i in range(8):
        a = lp.TAU * i / 8 + 0.2
        fur.add(ellipsoid(0.012, 0.012, 0.012, 4, 3, 'dark', center=(math.cos(a) * 0.17, 0.015 + math.sin(a) * 0.145, 0.75)))
    fur.add(ellipsoid(0.03, 0.016, 0.034, 8, 4, 'vcol', center=(0, -0.155, 0.705)).color(GOLD))
    fur.add(ellipsoid(0.016, 0.01, 0.02, 6, 3, 'glow', center=(0, -0.17, 0.705)).color(lp.hexc('#ff7fa8')))
    g.add(fur.bind('chest'))
    return g


# ================================================================= BOLSAS
@piece('back', 'back_mochila', 'Mochila de Aventureiro', rarity=0, cost=0)
def back_mochila():
    y = 0.19
    g = stack([(0.42, 0.11, 0.06, 0, y, 0.7), (0.46, 0.125, 0.072, 0, y, 0.7), (0.66, 0.12, 0.07, 0, y, 0.7), (0.71, 0.1, 0.055, 0, y, 0.7)],
              10, 'leather')
    g.grad('z', 0.42, 0.71, (0.72, 0.68, 0.8), lp.WHITE)
    flap = stack([(0.6, 0.128, 0.077, 0, y, 0.7), (0.66, 0.126, 0.076, 0, y, 0.7), (0.715, 0.104, 0.06, 0, y, 0.7)], 10, 'primary', cap_a=False)
    g.add(flap)
    g.add(box(0.13, 0.04, 0.1, 'leather', center=(0, y + 0.085, 0.52)).flat())
    g.add(box(0.05, 0.02, 0.04, 'vcol', center=(0, y + 0.08, 0.6)).color(GOLD))
    roll = cyl(0.052, 0.3, 8, 'secondary', center=(0, y + 0.01, 0.765))
    roll.rot('Y', 90, (0, y + 0.01, 0.765))
    for x in (-0.08, 0.08):
        b = cyl(0.056, 0.022, 8, 'leather', center=(x, y + 0.01, 0.765))
        b.rot('Y', 90, (x, y + 0.01, 0.765))
        roll.add(b)
    g.add(roll)
    g.add(shoulder_straps(0.14, 0.5))
    return g.bind_axis('z', [(0.45, 'spine'), (0.58, 'chest')])


@piece('back', 'back_aljava', 'Aljava', rarity=0, cost=90)
def back_aljava():
    g = Geo()
    a0, a1 = Vector((-0.1, 0.18, 0.4)), Vector((0.13, 0.18, 0.83))
    d = (a1 - a0)
    ang = math.degrees(math.atan2(d.x, d.z))
    q = stack([(0.0, 0.058, 0.05), (0.04, 0.062, 0.054), (0.44, 0.07, 0.058), (0.46, 0.064, 0.052)], 8, 'leather', cap_b=False)
    q.add(stack([(0.03, 0.066, 0.058), (0.06, 0.066, 0.058)], 8, 'accent', cap_a=False, cap_b=False))
    q.add(stack([(0.39, 0.074, 0.062), (0.43, 0.074, 0.062)], 8, 'accent', cap_a=False, cap_b=False))
    for i, (x, y) in enumerate(((-0.025, 0.0), (0.02, 0.012), (0.0, -0.022), (0.03, -0.02), (-0.03, 0.02))):
        h = 0.56 + 0.03 * (i % 2)
        q.add(cyl(0.006, h - 0.3, 4, 'vcol', center=(x, y, 0.3 + (h - 0.3) / 2)).color(lp.hexc('#c9a26b')))
        fl = box(0.006, 0.05, 0.08, 'vcol', center=(x, y, h - 0.03)).color(lp.hexc('#f3ead6') if i % 2 else lp.hexc('#e2665a'))
        fl.rot('Z', 30 * i, (x, y, h))
        q.add(fl)
    q.rot('Y', ang)
    q.move(*a0)
    g.add(q)
    g.add(strap([(0.1, 0.14, 0.7), (0.105, 0.05, 0.765), (0.08, -0.08, 0.72), (0.0, -0.118, 0.6), (-0.09, -0.118, 0.48), (-0.135, -0.04, 0.43),
                 (-0.12, 0.11, 0.42)], 0.024, 0.008))
    return g.bind_axis('z', [(0.45, 'spine'), (0.58, 'chest')])


# ================================================================= ASAS
def wing(pts, depth, mat, ang_z, tilt, at, side):
    w = poly_extrude(pts, depth, mat)
    w.rot('X', tilt)
    w.rot('Z', ang_z)
    if side < 0:
        w = w.mirrored()
    w.move(at[0] * side, at[1], at[2])
    return w


@piece('back', 'back_asas_fada', 'Asas de Fada', rarity=3, cost=1100)
def back_asas_fada():
    g = Geo()
    up = [(0.0, 0.0), (0.08, 0.1), (0.2, 0.22), (0.32, 0.27), (0.37, 0.2), (0.33, 0.08), (0.18, 0.0)]
    lo = [(0.0, 0.0), (0.12, -0.02), (0.24, -0.12), (0.23, -0.2), (0.14, -0.17), (0.05, -0.08)]
    for side in (1, -1):
        for pts, at, az, tl in ((up, (0.03, 0.15, 0.63), 28, -14), (lo, (0.03, 0.15, 0.6), 22, -8)):
            w = wing(pts, 0.008, 'glow', az, tl, at, side)
            w.tint(lambda p, c: lp.mulc(lp.mixc(lp.hexc('#5fd8ff'), lp.hexc('#ff7fc8'), min(1.0, abs(p.x) / 0.36)), 0.5))
            g.add(w)
    g.add(ellipsoid(0.03, 0.02, 0.04, 6, 4, 'vcol', center=(0, 0.14, 0.62)).color(GOLD))
    return g.bind('chest')


@piece('back', 'back_asas_morcego', 'Asas de Dragão', rarity=2, cost=520)
def back_asas_morcego():
    g = Geo()
    mem = [(0.0, 0.02), (0.12, 0.15), (0.3, 0.24), (0.42, 0.12), (0.33, 0.07), (0.34, -0.06), (0.24, -0.01), (0.2, -0.15),
           (0.11, -0.05), (0.02, -0.08)]
    bones_pts = [[(0, 0.02), (0.12, 0.15), (0.3, 0.24), (0.42, 0.12)], [(0.3, 0.24), (0.34, -0.06)], [(0.3, 0.24), (0.2, -0.15)]]
    for side in (1, -1):
        w = wing(mem, 0.01, 'primary', 18, -10, (0.04, 0.15, 0.62), side)
        w.grad('z', 0.45, 0.9, (0.72, 0.66, 0.82), lp.WHITE)
        g.add(w)
        for chain in bones_pts:
            path = [Vector((x, 0, z)) for x, z in chain]
            b = tube(path, [0.016] + [0.01] * (len(path) - 2) + [0.004], 4, 'dark')
            b.rot('X', -10)
            b.rot('Z', 18)
            if side < 0:
                b = b.mirrored()
            b.move(0.04 * side, 0.15 - 0.008, 0.62)
            g.add(b)
    g.add(ellipsoid(0.05, 0.03, 0.05, 6, 4, 'dark', center=(0, 0.14, 0.62)))
    return g.bind('chest')


# ================================================================= CAUDAS E OUTROS
def tail_bind(g):
    def w(p):
        if p.z > 0.56:
            return {'tail2': 1.0}
        y = p.y
        if y < 0.12:
            return {'hips': 1.0}
        if y < 0.2:
            k = (y - 0.12) / 0.08
            return {'hips': 1 - k, 'tail1': k}
        if y < 0.3:
            k = (y - 0.2) / 0.1
            return {'tail1': 1 - k, 'tail2': k}
        return {'tail2': 1.0}
    return g.bind_fn(w)


@piece('back', 'back_rabo_raposa', 'Cauda de Raposa', rarity=1, cost=200)
def back_rabo_raposa():
    path = [(0, 0.09, 0.43), (0, 0.2, 0.37), (0, 0.32, 0.38), (0, 0.41, 0.47), (0, 0.44, 0.56)]
    g = tube(path, [0.032, 0.07, 0.092, 0.085, 0.062], 8, 'hair', cap_b=False)
    g.grad('z', 0.37, 0.56, (0.78, 0.74, 0.86), lp.WHITE)
    g.add(tube([(0, 0.44, 0.56), (0, 0.44, 0.62), (0, 0.42, 0.68)], [0.062, 0.042, 0.004], 8, 'white', cap_a=False))
    return tail_bind(g)


@piece('back', 'back_rabo_gato', 'Cauda de Gato', rarity=1, cost=160)
def back_rabo_gato():
    path = [(0, 0.09, 0.42), (0, 0.21, 0.36), (0, 0.33, 0.39), (0, 0.4, 0.5), (0, 0.39, 0.62), (0, 0.33, 0.69), (0, 0.27, 0.69)]
    g = tube(path, [0.022, 0.028, 0.028, 0.027, 0.026, 0.024, 0.01], 7, 'hair')
    g.grad('z', 0.36, 0.7, (0.8, 0.76, 0.86), lp.WHITE)
    return tail_bind(g)


@piece('back', 'back_casco', 'Casco de Tartaruga', rarity=1, cost=240)
def back_casco():
    y0 = 0.135
    dome = ellipsoid(0.175, 0.1, 0.2, 12, 8, 'primary', center=(0, y0, 0.56))
    dome.keep_faces(lambda c: c.y > y0 - 0.005)
    dome.grad('y', y0, y0 + 0.1, (0.72, 0.68, 0.82), lp.WHITE)
    g = dome
    rim = [Vector((math.sin(lp.TAU * i / 18) * 0.178, y0, 0.56 + math.cos(lp.TAU * i / 18) * 0.203)) for i in range(18)]
    g.add(tube(rim + [rim[0]], 0.022, 5, 'secondary', cap_a=False, cap_b=False))
    for x, z, r in ((0, 0.6, 0.06), (0, 0.45, 0.045), (0, 0.72, 0.045), (0.09, 0.54, 0.045), (-0.09, 0.54, 0.045), (0.08, 0.66, 0.035),
                    (-0.08, 0.66, 0.035)):
        yy = y0 + 0.1 * math.sqrt(max(0.0, 1 - (x / 0.175) ** 2 - ((z - 0.56) / 0.2) ** 2))
        g.add(ellipsoid(r, 0.016, r * 0.9, 6, 3, 'secondary', center=(x, yy - 0.004, z)).flat())
    g.add(shoulder_straps(0.13, 0.48))
    return g.bind_axis('z', [(0.45, 'spine'), (0.58, 'chest')])


@piece('back', 'back_espadao', 'Espadão nas Costas', rarity=1, cost=300)
def back_espadao():
    s = Geo()
    s.add(stack([(0.0, 0.05, 0.02), (0.06, 0.056, 0.024), (0.6, 0.06, 0.026), (0.66, 0.054, 0.022)], 6, 'leather', phase=0.5))
    s.add(stack([(-0.02, 0.04, 0.018), (0.06, 0.062, 0.028)], 6, 'accent', phase=0.5, cap_b=False))
    s.add(box(0.2, 0.05, 0.035, 'accent', center=(0, 0, 0.68)))
    s.add(cyl(0.017, 0.16, 6, 'leather', center=(0, 0, 0.78)))
    s.add(ellipsoid(0.028, 0.028, 0.026, 6, 4, 'accent', center=(0, 0, 0.875)))
    s.rot('Y', 32)
    s.move(-0.13, 0.175, 0.33)
    s.add(strap([(0.1, 0.14, 0.7), (0.105, 0.05, 0.765), (0.08, -0.08, 0.72), (0.0, -0.118, 0.6), (-0.09, -0.118, 0.48), (-0.135, -0.04, 0.43),
                 (-0.12, 0.12, 0.42)], 0.024, 0.008))
    return s.bind_axis('z', [(0.45, 'spine'), (0.58, 'chest')])

"""env_boss.py: kit 'env_boss' (Santuario do Guardiao), a arena final aberta para o por do sol.

    python3 tools/blender/env_boss.py   -> assets/models/env_boss.glb + env_boss_manifest.json

Reaproveita a biblioteca de formas e a paleta da Gruta de Cristal (env_crystal.py) para o
santuario parecer o mesmo mundo: pedra antiga palida, runas e cristais de lumen.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lp  # noqa: E402
from mathutils import Vector  # noqa: E402
from lp import hexc, mixc  # noqa: E402
import env_crystal as ec  # noqa: E402
from kit import Kit  # noqa: E402

kit = Kit('env_boss')
TAU = math.tau
GOLD = hexc('#e9b949')
GOLD_D = hexc('#a8742a')
CLOTH = hexc('#5a3f9a')
CLOTH_D = hexc('#3a2a6e')


def gems(specs, cols=None):
    """specs: [(x, y, z, altura, raio, inclina, giro, semente)]."""
    g = lp.Geo()
    for i, (x, y, z, h, r, tl, yw, sd) in enumerate(specs):
        c = cols or (ec.GEM_CV if i % 3 else ec.GEM_VP)
        g.add(ec.place(ec.crystal(h, r, n=5 if r < 0.25 else 6, seed=sd, cols=c), (x, y, z), tilt=tl, yaw=yw))
    return g


def annulus(r0, r1, h, n=48, mat='vcol', col=lp.WHITE, z0=0.0):
    """Anel achatado (topo + lateral externa), para o piso de runas."""
    g = lp.Geo()
    inn = [g.add_vert((math.cos(TAU * i / n) * r0, math.sin(TAU * i / n) * r0, z0 + h), c=col) for i in range(n)]
    out = [g.add_vert((math.cos(TAU * i / n) * r1, math.sin(TAU * i / n) * r1, z0 + h), c=col) for i in range(n)]
    bot = [g.add_vert((math.cos(TAU * i / n) * r1, math.sin(TAU * i / n) * r1, z0), c=col) for i in range(n)]
    for i in range(n):
        j = (i + 1) % n
        if r0 > 1e-4:
            g.add_face((inn[i], out[i], out[j], inn[j]), mat, False)
        g.add_face((bot[i], bot[j], out[j], out[i]), mat, False)
    if r0 <= 1e-4:
        c = g.add_vert((0, 0, z0 + h), c=col)
        for i in range(n):
            g.add_face((c, out[i], out[(i + 1) % n]), mat, False)
    return g


# =========================================================================== muralha
@kit.prop('ring_wall', collider=('box', 4.0, 1.6, 4.6), tags=['wall'])
def ring_wall():
    """Trecho da muralha do santuario: fiadas de blocos, faixa de runas e cristais nascendo na base."""
    rnd = random.Random(7)
    g = lp.Geo()
    z = 0.0
    courses = [(0.95, 4, 1.5), (1.15, 3, 1.42), (1.0, 4, 1.36), (0.95, 3, 1.3)]
    fronts = []
    for ci, (h, n, d) in enumerate(courses):
        w = 4.0 / n
        for i in range(n):
            x = -2 + w * (i + 0.5)
            b = ec.cblock(w - 0.05, d, h - 0.03, 0.08)
            ec.stone(b, seed=ci * 7 + i, z0=-z, z1=4.6 - z)
            g.add(ec.place(b, (x + rnd.uniform(-0.03, 0.03), rnd.uniform(-0.05, 0.05), z), yaw=rnd.uniform(-1.5, 1.5)))
        fronts.append(-d / 2)
        z += h
    cor = ec.cblock(4.12, 1.52, 0.34, 0.09)
    ec.stone(cor, seed=40, z0=-1.0, z1=1.0)
    g.add(ec.place(cor, (0, 0, z)))
    # ameias quebradas
    for x, hh in ((-1.45, 0.55), (-0.2, 0.42), (1.2, 0.6)):
        m = ec.cblock(0.8, 1.0, hh, 0.07)
        m.warp(lambda p, hh=hh: Vector((p.x, p.y, min(p.z, hh * (0.65 + 0.5 * ec.sm(-0.4, 0.4, p.x))))) if p.z > 0.05 else p)
        ec.stone(m, seed=int(x * 10) + 50, z0=-z, z1=4.8 - z)
        g.add(ec.place(m, (x, 0.05, z + 0.34)))
    # faixa de runas na terceira fiada
    zr = courses[0][0] + courses[1][0] + courses[2][0] * 0.5
    for i, nm in enumerate(['fe', 'os', 'ti', 'ha', 'in']):
        g.add(ec.place(ec.rune(nm, 0.42, col=ec.CY), (-1.6 + i * 0.8, fronts[2] - 0.02, zr)))
    # cristais na base, de um lado so (assimetria)
    g.add(gems([(1.45, -0.62, 0.0, 1.5, 0.22, 18, 20, 11), (1.1, -0.72, 0.0, 0.9, 0.15, 34, -30, 12),
                (1.75, -0.55, 0.3, 0.7, 0.12, 40, 60, 13), (-1.6, -0.7, 0.0, 0.55, 0.1, 30, -50, 14)]))
    ec.spill(g, [((1.4, -0.9, 0.8), ec.mul(ec.CY, 0.9), 1.4), ((0, -0.8, zr), ec.mul(ec.CY, 0.5), 1.8)], 0.4)
    return ec.finish(ec.no_bottom(g), 0.55, 0.7)


@kit.prop('ring_pillar', collider=('cyl', 0.85, 7.0), tags=['wall_pillar'])
def ring_pillar():
    """Pilar monumental de runas (~7 m): base larga, tambores com faixas acesas, capitel com cristais."""
    g = ec.stone(ec.cblock(1.75, 1.75, 0.5, 0.1), seed=1, z0=0, z1=2.0)
    g.add(ec.place(ec.stone(ec.cblock(1.45, 1.45, 0.3, 0.08), seed=2, z0=-0.5, z1=1.5), (0, 0, 0.5)))
    z = 0.8
    for i, (r, hh) in enumerate(((0.66, 1.25), (0.62, 0.32), (0.62, 1.4), (0.6, 0.32), (0.6, 1.35))):
        d = ec.drum(r, hh, n=10, ch=0.04, flute=0.1 if hh > 1 else 0.0)
        ec.stone(d, seed=10 + i, z0=-z, z1=7.0 - z)
        g.add(ec.place(d, (0, 0, z), yaw=i * 9))
        if hh < 0.5:
            g.add(ec.rune_band(r + 0.012, z + hh / 2, 8, size=0.22, start=i, arc=TAU))
        z += hh
    cap = ec.stone(ec.cblock(1.55, 1.55, 0.45, 0.1, taper=1.12), seed=30, z0=-z, z1=1.0)
    g.add(ec.place(cap, (0, 0, z), yaw=4))
    z += 0.45
    g.add(gems([(0.0, 0.0, z - 0.05, 1.3, 0.26, 8, 0, 21), (0.35, -0.2, z - 0.05, 0.8, 0.16, 32, 40, 22),
                (-0.3, 0.25, z - 0.05, 0.7, 0.15, 30, -110, 23), (-0.25, -0.35, z - 0.05, 0.5, 0.12, 40, -40, 24)]))
    ec.spill(g, [((0, -0.2, z + 0.4), ec.mul(ec.CY, 0.9), 1.4)], 0.45)
    return ec.finish(ec.no_bottom(g), 0.5, 0.7)


# =========================================================================== centro da arena
@kit.prop('rune_floor', tags=['centerpiece'])
def rune_floor():
    """Ornamento circular do piso (8 m): aneis de pedra com canais de luz e runas deitadas."""
    g = lp.Geo()
    rings = [(0.0, 1.15, 0.04, ec.STONE_L), (1.3, 2.55, 0.035, ec.STONE), (2.7, 3.75, 0.03, ec.STONE_D), (3.9, 4.0, 0.03, ec.STONE)]
    for r0, r1, h, col in rings:
        g.add(annulus(r0, r1, h, 56, 'vcol', col))
    for r0, r1 in ((1.15, 1.3), (2.55, 2.7), (3.75, 3.9)):
        g.add(annulus(r0, r1, 0.02, 56, 'glow', ec.mul(ec.CY, 0.85)))
    # raios de luz ligando o centro aos aneis
    for i in range(8):
        a = TAU * i / 8 + TAU / 16
        s = ec.lay_flat(ec.stroke((0, 1.3), (0, 2.55), 0.09, ec.mul(ec.CY, 0.8)), 0.045)
        g.add(ec.place(s, (0, 0, 0), yaw=math.degrees(a)))
    for i in range(12):
        a = TAU * i / 12
        rn = ec.lay_flat(ec.rune(ec.RUNE_SEQ[i % len(ec.RUNE_SEQ)], 0.55, col=ec.CY), 0.04)
        rn.rot('Z', -math.degrees(a) + 90)
        rn.move(math.cos(a) * 3.22, math.sin(a) * 3.22, 0)
        g.add(rn)
    estrela = ec.lay_flat(ec.polyline([(math.cos(TAU * k * 2 / 5 + math.pi / 2) * 0.85, math.sin(TAU * k * 2 / 5 + math.pi / 2) * 0.85)
                                       for k in range(6)], 0.08, ec.mul(ec.CY, 0.9)), 0.05)
    g.add(estrela)
    return g


@kit.prop('brazier', collider=('cyl', 0.5, 1.4), tags=['light'],
          light=dict(color='#8ff3ff', energy=2.2, height=1.7, range=8.0))
def brazier():
    """Braseiro de pedra com cristais de lumen no lugar do fogo."""
    g = ec.stone(ec.cblock(0.9, 0.9, 0.22, 0.06), seed=3, z0=0, z1=1.6)
    shaft = ec.drum(0.24, 0.8, n=8, ch=0.03, r_top=0.2)
    ec.stone(shaft, seed=4, z0=-0.22, z1=1.4)
    g.add(ec.place(shaft, (0, 0, 0.22)))
    bowl = lp.lathe([(0.12, 1.0), (0.42, 1.12), (0.55, 1.34), (0.5, 1.4), (0.36, 1.3)], n=10)
    bowl.c = [mixc(ec.STONE_D, ec.STONE, ec.sm(1.0, 1.4, p.z)) for p in bowl.v]
    g.add(ec.facet(bowl))
    g.add(ec.place(lp.cyl(0.47, 0.06, 10, center=(0, 0, 0)).color(GOLD).flat(), (0, 0, 1.3)))
    g.add(gems([(0, 0, 1.15, 0.75, 0.16, 6, 0, 31), (0.15, 0.08, 1.15, 0.5, 0.12, 28, 60, 32), (-0.14, -0.06, 1.15, 0.55, 0.12, 26, -120, 33),
                (0.02, -0.17, 1.15, 0.38, 0.09, 36, -10, 34)], ec.GEM_CP))
    ec.spill(g, [((0, 0, 1.6), ec.mul(ec.CY, 0.9), 0.9)], 0.45)
    return ec.finish(ec.no_bottom(g), 0.45, 0.5)


# =========================================================================== fundo
@kit.prop('crystal_throne', tags=['backdrop'])
def crystal_throne():
    """Trono adormecido do Guardiao: degraus, espaldar alto e cristais enormes tomando tudo."""
    g = lp.Geo()
    for i, (w, d, h) in enumerate(((5.2, 3.6, 0.4), (4.4, 3.0, 0.4), (3.6, 2.4, 0.45))):
        b = ec.stone(ec.cblock(w, d, h, 0.1), seed=60 + i, z0=-i * 0.4, z1=3.0)
        g.add(ec.place(b, (0, 0.2 * i, i * 0.4)))
    z = 1.25
    seat = ec.stone(ec.cblock(2.2, 1.6, 0.7, 0.08), seed=70, z0=-z, z1=4.0)
    g.add(ec.place(seat, (0, 0.2, z)))
    back = ec.stone(ec.cblock(2.4, 0.6, 3.6, 0.1, taper=0.8), seed=71, z0=-z, z1=4.0)
    back.warp(lambda p: Vector((p.x, p.y, p.z + 0.35 * max(0.0, 1 - abs(p.x) / 1.0) if p.z > 3.4 else p.z)))
    g.add(ec.place(back, (0, 0.85, z + 0.7)))
    for sx in (-1, 1):
        arm = ec.stone(ec.cblock(0.45, 1.6, 0.9, 0.06), seed=72 + sx, z0=-z, z1=3.0)
        g.add(ec.place(arm, (sx * 1.2, 0.2, z)))
    g.add(ec.place(ec.rune('ey', 0.9, col=ec.CY), (0, 0.53, z + 3.0)))
    g.add(gems([(-1.5, 0.9, 1.2, 3.4, 0.45, 14, 20, 41), (-1.1, 1.0, 1.2, 2.3, 0.32, 30, -20, 42), (1.6, 0.8, 1.2, 2.8, 0.4, 20, -40, 43),
                (1.25, 1.15, 1.2, 1.8, 0.28, 34, 30, 44), (0.2, 1.3, 4.4, 1.6, 0.3, 24, 10, 45), (-2.2, -0.9, 0.0, 1.1, 0.22, 30, 80, 46),
                (2.3, -1.0, 0.0, 0.9, 0.2, 28, -70, 47), (0.6, -1.2, 0.4, 0.6, 0.14, 40, 20, 48)]))
    ec.spill(g, [((-1.4, 0.4, 2.6), ec.mul(ec.PK, 0.8), 2.0), ((1.5, 0.4, 2.4), ec.mul(ec.CY, 0.8), 2.0)], 0.4)
    return ec.finish(ec.no_bottom(g), 0.55, 1.0)


@kit.prop('ring_arch', tags=['backdrop'])
def ring_arch():
    """Arco monumental quebrado (~10 m): um lado inteiro, o outro partido com o arco desabado."""
    g = lp.Geo()
    rnd = random.Random(9)
    span = 3.6
    for sx, top in ((-1, 7.2), (1, 5.4)):
        z = 0.0
        base = ec.stone(ec.cblock(1.9, 1.9, 0.6, 0.1), seed=80 + sx, z0=0, z1=8.0)
        g.add(ec.place(base, (sx * span, 0, 0)))
        z = 0.6
        while z < top:
            hh = min(1.1, top - z)
            b = ec.cblock(1.4, 1.4, hh - 0.03, 0.08)
            if z + hh >= top and sx > 0:
                b.warp(lambda p, hh=hh: Vector((p.x, p.y, min(p.z, hh * (0.4 + 0.6 * ec.sm(-0.6, 0.6, -p.x + p.y * 0.3))))) if p.z > 0.05 else p)
            ec.stone(b, seed=int(z * 10) + sx, z0=-z, z1=10.0 - z)
            g.add(ec.place(b, (sx * span + rnd.uniform(-0.04, 0.04), 0, z), yaw=rnd.uniform(-3, 3)))
            z += hh
    # aduelas do arco: so o lado esquerdo e o fecho continuam de pe
    for i in range(7):
        a = math.pi - (i + 0.5) * (math.pi / 12)
        cx = math.cos(a) * span
        cz = 7.2 + math.sin(a) * span * 0.85 - 0.6
        v = ec.cblock(1.1, 1.3, 0.85, 0.07)
        ec.stone(v, seed=90 + i, z0=-1.0, z1=1.0)
        v.move(0, 0, -0.42)
        v.rot('Y', -math.degrees(a) + 90)
        v.move(cx, 0, cz + 0.42)
        g.add(v)
    g.add(ec.place(ec.rune('os', 0.8, col=ec.CY), (-span, -0.72, 4.0)))
    g.add(gems([(span - 0.2, -0.3, 5.3, 1.6, 0.3, 20, 20, 51), (span + 0.3, 0.1, 5.2, 1.0, 0.2, 38, -60, 52),
                (-span + 0.6, -0.8, 0.0, 1.0, 0.2, 25, 40, 53)]))
    # destrocos do arco no chao
    for i, (x, y) in enumerate(((1.5, -0.8), (2.4, 0.9), (0.6, 0.4))):
        d = ec.stone(ec.mesa(100 + i, 1.0, 0.8, 0.6, n=5, top=0.6, tilt=0.4), seed=100 + i, z0=0, z1=1.2)
        g.add(ec.place(d, (x, y, 0), yaw=rnd.uniform(0, 360)))
    ec.spill(g, [((span, -0.5, 6.0), ec.mul(ec.CY, 0.8), 2.0)], 0.4)
    return ec.finish(ec.no_bottom(g), 0.5, 1.0)


# =========================================================================== miudezas
@kit.prop('rubble_a', collider=('cyl', 0.8, 1.0), tags=['rock'])
def rubble_a():
    g = ec.stone(ec.cblock(1.3, 1.0, 0.7, 0.08), seed=110, z0=0, z1=1.4)
    g.add(ec.place(ec.stone(ec.mesa(111, 0.8, 0.7, 0.5, n=5, top=0.6, tilt=0.5), seed=111, z0=-0.7, z1=0.8), (0.1, 0.0, 0.7), yaw=30))
    g.add(ec.place(ec.stone(ec.mesa(112, 0.6, 0.5, 0.35, n=5), seed=112, z0=0, z1=1.0), (-0.85, -0.4, 0.0), yaw=70))
    g.add(gems([(0.55, -0.4, 0.0, 0.55, 0.11, 30, 40, 113)]))
    return ec.finish(ec.no_bottom(g), 0.55, 0.6)


@kit.prop('rubble_b', collider=('cyl', 0.75, 0.9), tags=['rock'])
def rubble_b():
    """Bloco caido com runa e um tambor de coluna tombado."""
    d = ec.drum(0.55, 1.5, n=10, ch=0.04, flute=0.1)
    ec.stone(d, seed=120, z0=0, z1=1.5)
    d.rot('Y', 90)
    d.move(-0.75, 0, 0.55)
    g = d
    b = ec.stone(ec.cblock(0.9, 0.9, 0.8, 0.07), seed=121, z0=0, z1=1.2)
    g.add(ec.place(b, (0.55, 0.15, 0), yaw=20))
    g.add(ec.place(ec.rune('ti', 0.4, col=ec.CY), (0.5, -0.32, 0.42), yaw=20))
    return ec.finish(ec.no_bottom(g), 0.55, 0.6)


@kit.prop('banner_ruin', tags=['deco'])
def banner_ruin():
    """Estandarte antigo rasgado num mastro, balancando ao vento."""
    g = lp.cyl(0.05, 3.6, 6, center=(0, 0, 1.8)).color(ec.WOOD)
    g.add(lp.ellipsoid(0.09, 0.09, 0.09, 6, 4, center=(0, 0, 3.65)).color(GOLD))
    g.add(lp.cyl(0.035, 1.3, 6, center=(0, 0, 3.3)).rot('Y', 90, (0, 0, 3.3)).color(ec.WOOD))
    rnd = random.Random(4)
    rows = []
    cols = 7
    for r in range(9):
        t = r / 8
        row = []
        for c in range(cols):
            u = c / (cols - 1)
            x = -0.6 + 1.2 * u
            rag = 0.0
            if r == 8:
                rag = rnd.uniform(0.0, 0.5) * (0.4 + 0.6 * abs(u - 0.5) * 2)
            z = 3.25 - t * 2.3 + rag
            y = -0.06 + 0.06 * math.sin(u * math.pi * 1.5 + t * 2.0)
            row.append((x, y, z))
        rows.append(row)
    cloth = lp.sheet(rows, 'vcol_wind', 'vcol_wind', thickness=0.02)
    cloth.c = [mixc(CLOTH_D, CLOTH, ec.sm(0.9, 3.2, p.z)) for p in cloth.v]
    for p_i, p in enumerate(cloth.v):
        if 2.9 < p.z < 3.0 or 1.25 < p.z < 1.35:
            cloth.c[p_i] = GOLD
    g.add(cloth)
    g.add(ec.place(ec.rune('ey', 0.5, col=GOLD, mat='vcol'), (0, -0.1, 2.25)))
    return lp.bake_ao(g, 0.4, 0.4, floor_z=0)


if __name__ == '__main__':
    kit.build()

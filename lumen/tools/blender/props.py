"""props.py: props interativos, coletaveis e projeteis do Lumen (kit 'props').

    python3 tools/blender/props.py            -> assets/models/props.glb + props_manifest.json

Cada objeto fica centrado na origem, base em z=0, frente para -Y. Materiais: so 'vcol'
(cor no vertice), 'glow' (emissivo, cor do vertice = cor da luz) e 'vcol_wind' (pano/folha).
Excecoes de origem (pedidas pelo jogo):
  - arrow / dagger: centrados na origem, apontando para -Y.
  - chest_*_base e chest_*_lid: a origem fica na linha da dobradica (fundo do bau, y=0);
    o bau ocupa y de -0.6 a 0. O jogo poe a tampa em (0, 0, altura da base) e gira em X.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lp  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
from lp import Geo, box, cone, cyl, ellipsoid, icosphere, lathe, loft, merge, poly_extrude, ring_pts, stack, tube  # noqa: E402
from kit import Kit  # noqa: E402

kit = Kit('props')
TAU = math.tau
H = lp.hexc

# ---------------------------------------------------------------- paleta
WOOD, WOOD_HI, WOOD_LO, WOOD_DK = H('#a2693a'), H('#c98d52'), H('#6d4329'), H('#4f3226')
STONE, STONE_HI, STONE_LO = H('#8a92a8'), H('#aab2c4'), H('#5f6682')
MOSS, MOSS_LO = H('#6cae58'), H('#3f8a55')
IRON, IRON_HI = H('#4e546c'), H('#8088a2')
STEEL = H('#cfd6e6')
GOLD, GOLD_HI, GOLD_LO = H('#e9b949'), H('#ffe08a'), H('#b47a2c')
LUMEN, LUMEN_MID, LUMEN_LO = H('#7df9ff'), H('#45d3ee'), H('#1fa3d6')
RED, RED_LO, CREAM = H('#d9483b'), H('#9e2f3a'), H('#f3e8cf')
TEAL, TEAL_LO = H('#2a9d8f'), H('#1f6f7a')
NIGHT, NIGHT_LO = H('#4a3f9e'), H('#2c2766')
STRAW, STRAW_LO = H('#e2c46a'), H('#b8923f')
ROPE = H('#cdb07a')
DARK = H('#2f2a3d')
EMBER = H('#f0561a')
LIGHT_LUMEN = dict(color='#7df9ff')


# ---------------------------------------------------------------- ajudantes
def ramp(g, axis, stops, fn=None):
    """Cores absolutas ao longo de um eixo: stops = [(valor, cor), ...]."""
    ai = 'xyz'.index(axis)

    def paint(p, c):
        v = fn(p[ai]) if fn else p[ai]
        if v <= stops[0][0]:
            return stops[0][1]
        for (a, ca), (b, cb) in zip(stops, stops[1:]):
            if v <= b:
                return lp.mixc(ca, cb, (v - a) / (b - a))
        return stops[-1][1]
    return g.tint(paint)


def shade(g, lo=(0.74, 0.72, 0.88), hi=(1.05, 1.04, 1.0)):
    """Degrade vertical frio embaixo / quente em cima (multiplica)."""
    return g.autograd(lo, hi)


def ao(g, strength=0.5, floor=True):
    return lp.bake_ao(g, strength=strength, dist=0.5, samples=20, floor_z=0.0 if floor else None)


def aim(g, d, origin=(0, 0, 0)):
    q = Vector((0, 0, 1)).rotation_difference(Vector(d).normalized())
    return g.xf(Matrix.Translation(Vector(origin)) @ q.to_matrix().to_4x4())


def bbox(sx, sy, sz, bev=0.015, at=(0, 0, 0), mat='vcol'):
    """Caixa com todas as quinas chanfradas. at = (cx, cy, z da base)."""
    hx, hy = sx / 2, sy / 2
    b = min(bev, hx * 0.45, hy * 0.45, sz * 0.45)

    def ring(k, z):
        x, y = hx - k, hy - k
        return [(x, -y + b, z), (x, y - b, z), (x - b, y, z), (-x + b, y, z),
                (-x, y - b, z), (-x, -y + b, z), (-x + b, -y, z), (x - b, -y, z)]
    g = loft([ring(b, 0), ring(0, b), ring(0, sz - b), ring(b, sz)], mat, cap_a='flat', cap_b='flat', smooth=False)
    return g.move(*at)


def inset(pts, d):
    n = len(pts)
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    sgn = 1.0 if area > 0 else -1.0
    out = []
    for i in range(n):
        p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n])
        e1, e2 = (p1 - p0).normalized(), (p2 - p1).normalized()
        n1 = Vector((-e1.y, e1.x)) * sgn
        n2 = Vector((-e2.y, e2.x)) * sgn
        b = n1 + n2
        if b.length < 1e-6:
            b = n1.copy()
        b.normalize()
        k = 1.0 / max(0.55, b.dot(n1))
        out.append((p1.x + b.x * d * k, p1.y + b.y * d * k))
    return out


def plate(pts, depth, bev=0.01, mat='vcol'):
    """Placa: poligono (x, z) com espessura em Y e bordas chanfradas (frente em -Y)."""
    n = len(pts)
    ins = inset(pts, bev)
    h = depth / 2
    bv = min(bev, h * 0.8)
    g = Geo()
    rows = [[g.add_vert((x, -h, z)) for x, z in ins], [g.add_vert((x, -h + bv, z)) for x, z in pts],
            [g.add_vert((x, h - bv, z)) for x, z in pts], [g.add_vert((x, h, z)) for x, z in ins]]
    g.add_face(tuple(rows[0]), mat, False)
    g.add_face(tuple(reversed(rows[3])), mat, False)
    for a, b in zip(rows, rows[1:]):
        for i in range(n):
            j = (i + 1) % n
            g.add_face((a[j], a[i], b[i], b[j]), mat, False)
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    if area < 0:
        g.flip()
    return g


def sym(half):
    return list(half) + [(-x, z) for x, z in reversed(half) if x > 1e-6]


def star(n=5, r1=0.05, r2=0.022, depth=0.03, mat='vcol', rot=0.0):
    """Estrela facetada no plano XZ, bojuda no centro."""
    g = Geo()
    cf = g.add_vert((0, -depth / 2, 0))
    cb = g.add_vert((0, depth / 2, 0))
    rim = []
    for i in range(2 * n):
        a = math.radians(rot) + math.pi * i / n
        r = r1 if i % 2 == 0 else r2
        rim.append(g.add_vert((math.sin(a) * r, 0, math.cos(a) * r)))
    for i in range(2 * n):
        j = (i + 1) % (2 * n)
        g.add_face((cf, rim[j], rim[i]), mat, False)
        g.add_face((cb, rim[i], rim[j]), mat, False)
    return g


def gem(r, h, n=6, mat='glow', lo=0.32):
    return lathe([(0.0, -h * lo), (r, 0.0), (0.0, h * (1.0 - lo))], n, mat, smooth=False)


def crystal(r, h, n=6, mat='glow'):
    """Cristal comprido facetado, base em z=0."""
    return lathe([(0.0, 0.0), (r * 0.72, h * 0.14), (r, h * 0.60), (0.0, h)], n, mat, smooth=False)


def lumen(g, z0, z1):
    return ramp(g, 'z', [(z0, LUMEN_LO), ((z0 + z1) / 2, LUMEN_MID), (z1, LUMEN)])


def stud(r, half, tip, n=6, mat='glow'):
    """Gema encravada com eixo em Y (aparece dos dois lados de uma placa)."""
    return lathe([(0.0, -tip), (r, -half), (r, half), (0.0, tip)], n, mat, smooth=False).rot('X', 90)


def torus(R, r, n=12, m=5, mat='vcol', rz=None, smooth=True):
    """Anel no plano XY (eixo Z)."""
    rz = r if rz is None else rz
    g = Geo()
    idx = []
    for i in range(n):
        a = TAU * i / n
        row = []
        for j in range(m):
            b = TAU * (j + 0.5) / m
            rr = R + r * math.cos(b)
            row.append(g.add_vert((rr * math.cos(a), rr * math.sin(a), -rz * math.sin(b))))
        idx.append(row)
    for i in range(n):
        a, b = idx[i], idx[(i + 1) % n]
        for j in range(m):
            k = (j + 1) % m
            g.add_face((a[j], a[k], b[k], b[j]), mat, smooth)
    return g


def prism(pts, z0, z1, mat='vcol'):
    """Poligono (x, y) anti-horario visto de cima, de z0 a z1."""
    g = Geo()
    n = len(pts)
    a = [g.add_vert((x, y, z0)) for x, y in pts]
    b = [g.add_vert((x, y, z1)) for x, y in pts]
    g.add_face(tuple(reversed(a)), mat, False)
    g.add_face(tuple(b), mat, False)
    for i in range(n):
        j = (i + 1) % n
        g.add_face((a[i], a[j], b[j], b[i]), mat, False)
    return g


def rock(r, seed=0, squash=0.7, sub=1):
    g = icosphere(r, sub, jitter=0.16, seed=seed).scale(1.0, 1.0, squash)
    rnd = random.Random(seed)
    k = rnd.uniform(0.9, 1.08)
    ramp(g, 'z', [(-r * squash, lp.mulc(STONE_LO, k)), (r * squash, lp.mulc(STONE_HI, k))])
    return g


def moss(x, y, z, r):
    g = ellipsoid(r, r * 0.8, r * 0.34, 6, 3, center=(x, y, z))
    return ramp(g, 'z', [(z - r * 0.2, MOSS_LO), (z + r * 0.34, MOSS)])


def stone_box(sx, sy, sz, at, tone=1.0, bev=0.03, seed=0):
    g = bbox(sx, sy, sz, bev, at)
    ramp(g, 'z', [(at[2], lp.mulc(STONE_LO, tone)), (at[2] + sz, lp.mulc(STONE, tone * 1.06))])
    return g


def wood_box(sx, sy, sz, at, tone=1.0, bev=0.015, c=None):
    g = bbox(sx, sy, sz, bev, at)
    return g.color(lp.mulc(c or WOOD, tone))


def log(r, length, n=6):
    """Tora ao longo de +Z com os topos claros (madeira cortada)."""
    g = stack([(0.0, r, r), (length * 0.5, r * 1.06, r * 1.06), (length, r * 0.94, r * 0.94)], n)
    g.tint(lambda p, c: WOOD_HI if abs(p.x) + abs(p.y) < 1e-6 else WOOD_LO)
    return g


def flask(r, h, liquid, n=8):
    """Frasco bojudo com liquido, vidro, anel dourado e rolha. Base em z=0."""
    k = h / 0.33
    lo = lathe([(0.0, 0.0), (0.60 * r, 0.0), (0.94 * r, 0.05 * k), (r, 0.11 * k), (0.97 * r, 0.14 * k)], n)
    ramp(lo, 'z', [(0.0, lp.mulc(liquid, 0.62)), (0.14 * k, liquid)])
    hi = lathe([(0.97 * r, 0.14 * k), (0.80 * r, 0.185 * k), (0.42 * r, 0.225 * k), (0.36 * r, 0.27 * k),
                (0.48 * r, 0.28 * k), (0.48 * r, 0.295 * k), (0.0, 0.295 * k)], n)
    ramp(hi, 'z', [(0.14 * k, H('#bfeaf2')), (0.29 * k, H('#f2fdff'))])
    cork = lathe([(0.30 * r, 0.29 * k), (0.36 * r, 0.33 * k), (0.0, 0.335 * k)], n).color(WOOD)
    ring = torus(0.40 * r, 0.10 * r, n, 4).move(0, 0, 0.25 * k).color(GOLD)
    shine = ellipsoid(0.20 * r, 0.10 * r, 0.30 * r, 5, 3, center=(-0.52 * r, -0.74 * r, 0.115 * k)).color(H('#fff4f6'))
    return merge(lo, hi, cork, ring, shine)


# ================================================================= projeteis
@kit.prop('arrow', tags=['projectile'])
def arrow():
    g = Geo()
    sh = stack([(-0.27, 0.012, 0.012), (0.19, 0.014, 0.014)], 6)
    g.add(ramp(sh, 'z', [(-0.27, WOOD), (0.19, WOOD_HI)]))
    hd = stack([(0.160, 0.016, 0.014), (0.192, 0.052, 0.015), (0.300, 0.002, 0.002)], 4).flat()
    g.add(ramp(hd, 'z', [(0.16, H('#8e97b3')), (0.30, H('#f1f5ff'))]))
    g.add(cyl(0.019, 0.022, 6, center=(0, 0, 0.158)).color(GOLD))
    for i in range(3):
        f = poly_extrude([(0.010, -0.262), (0.050, -0.292), (0.050, -0.205), (0.010, -0.140)], 0.009)
        ramp(f, 'x', [(0.01, CREAM), (0.05, RED)])
        g.add(f.rot('Z', 90 + 120 * i))
    g.add(cyl(0.016, 0.03, 6, center=(0, 0, -0.275)).color(RED_LO))
    return g.rot('X', 90)


@kit.prop('dagger', tags=['projectile'])
def dagger():
    g = Geo()
    rings = []
    for z, w, t in ((0.0, 0.030, 0.009), (0.11, 0.032, 0.009), (0.215, 0.002, 0.002)):
        rings.append([(w, 0, z), (w * 0.4, t, z), (-w * 0.4, t, z), (-w, 0, z), (-w * 0.4, -t, z), (w * 0.4, -t, z)])
    bl = loft(rings).flat()
    g.add(ramp(bl, 'z', [(0.0, H('#9aa3bd')), (0.21, H('#f4f7ff'))]))
    g.add(bbox(0.10, 0.032, 0.024, 0.008, (0, 0, -0.022)).color(GOLD))
    hd = stack([(-0.125, 0.014, 0.014), (-0.085, 0.018, 0.018), (-0.02, 0.014, 0.014)], 6)
    g.add(ramp(hd, 'z', [(-0.125, RED_LO), (-0.02, RED)]))
    g.add(gem(0.022, 0.04, 6, 'vcol', lo=0.5).move(0, 0, -0.14).color(GOLD))
    return g.move(0, 0, -0.03).rot('X', 90)


# ================================================================= coletaveis
@kit.prop('coin', tags=['pickup'])
def coin():
    c = lathe([(0.0, -0.013), (0.100, -0.013), (0.108, -0.024), (0.134, -0.024), (0.145, -0.012), (0.145, 0.012),
               (0.134, 0.024), (0.108, 0.024), (0.100, 0.013), (0.0, 0.013)], 12, smooth=False, phase=0.5)
    c.tint(lambda p, col: GOLD_HI if math.hypot(p.x, p.y) > 0.105 else GOLD)
    c.rot('X', 90)
    for s in (-1, 1):
        c.add(star(5, 0.078, 0.034, 0.024).move(0, 0.013 * s, 0).color(GOLD_HI))
    c.grad('z', -0.145, 0.145, (0.82, 0.70, 0.66), (1.06, 1.04, 0.98))
    return c.move(0, 0, 0.145)


@kit.prop('shard', tags=['pickup', 'currency'], light=dict(color='#7df9ff', energy=1.2, height=0.2, range=3.0))
def shard():
    g = lumen(gem(0.085, 0.36, 5, lo=0.30).rot('Y', 9).move(0, 0, 0.115), 0.0, 0.37)
    g.add(lumen(gem(0.042, 0.17, 4, lo=0.35).rot('Y', -24).move(0.115, 0.02, 0.10), 0.02, 0.26))
    g.add(lumen(gem(0.030, 0.12, 4, lo=0.35).rot('Y', 30).move(-0.105, -0.02, 0.215), 0.14, 0.34))
    return g


@kit.prop('heart', tags=['pickup', 'heal'])
def heart():
    rz = 0.13
    g = ellipsoid(0.15, 0.088, rz, n=12, rings=6)

    def w(p):
        t = (p.z + rz) / (2 * rz)
        k = min(1.0, (t / 0.5) ** 0.6) if t > 0 else 0.0
        x = p.x * k
        return Vector((x, p.y * (0.45 + 0.55 * k), p.z + 0.9 * abs(x)))
    g.warp(w)
    ramp(g, 'z', [(-rz, H('#c4204a')), (0.05, H('#f2415f')), (0.19, H('#ff7890'))])
    g.add(ellipsoid(0.034, 0.016, 0.024, 6, 3, center=(-0.078, -0.070, 0.118)).rot('Y', -25, pivot=(-0.078, -0.07, 0.118))
          .color(H('#ffe1e6')))
    return g.move(0, 0, rz)


@kit.prop('potion', tags=['pickup'])
def potion():
    return flask(0.12, 0.34, H('#e8436b'), 10)


@kit.prop('tome', tags=['pickup', 'spell'])
def tome():
    g = Geo()
    for y in (-0.036, 0.036):
        cv = bbox(0.25, 0.022, 0.32, 0.008, (0.005, y, 0))
        g.add(ramp(cv, 'z', [(0, NIGHT_LO), (0.32, NIGHT)]))
    g.add(ramp(bbox(0.036, 0.094, 0.32, 0.014, (-0.118, 0, 0)), 'z', [(0, NIGHT_LO), (0.32, NIGHT)]))
    g.add(bbox(0.215, 0.052, 0.296, 0.004, (0.012, 0, 0.012)).color(CREAM).grad('x', -0.1, 0.12, (0.8, 0.76, 0.8), lp.WHITE))
    gold = Geo()
    for z in (0.045, 0.275):
        gold.add(bbox(0.044, 0.100, 0.03, 0.006, (-0.118, 0, z - 0.015)))
    for s in (-1, 1):       # cantoneiras
        for z0, sg in ((0.0, 1), (0.32, -1)):
            gold.add(prism([(0.130, -0.004), (0.130, 0.004), (0.060, 0.004), (0.060, -0.004)], 0, 0.07)
                     .warp(lambda p, sg=sg, z0=z0: Vector((p.x - (0.07 - p.z) * 0 , p.y, z0 + sg * p.z * (p.x - 0.06) / 0.07)))
                     .move(0, 0.049 * s, 0))
    gold.add(star(4, 0.070, 0.026, 0.020).move(0.01, -0.047, 0.165))
    gold.add(star(4, 0.070, 0.026, 0.020).move(0.01, 0.047, 0.165))
    gold.color(GOLD).grad('z', 0, 0.32, (0.8, 0.68, 0.66), (1.06, 1.04, 0.98))
    g.add(gold)
    g.add(stud(0.020, 0.058, 0.066, 4).move(0.01, 0, 0.165).color(LUMEN_MID))
    return g


@kit.prop('relic_orb', tags=['pickup', 'relic'], light=dict(color='#7df9ff', energy=1.0, height=0.2, range=3.0))
def relic_orb():
    cz = 0.205
    gold = lathe([(0.0, 0.0), (0.085, 0.0), (0.092, 0.018), (0.040, 0.040), (0.030, 0.070), (0.0, 0.075)], 8)
    gold.add(torus(0.118, 0.019, 14, 4).rot('X', 90).move(0, 0, cz))
    for a in (0, 90, 180, 270):
        gold.add(gem(0.026, 0.06, 4, 'vcol', lo=0.5).move(0, 0, 0.128).rot('Y', a).move(0, 0, cz))
    gold.add(crystal(0.022, 0.07, 4, 'vcol').move(0, 0, cz + 0.135))
    gold.color(GOLD).grad('z', 0, 0.40, (0.78, 0.66, 0.64), (1.08, 1.06, 0.98))
    orb = icosphere(0.086, 1, 'glow', center=(0, 0, cz))
    return gold.add(lumen(orb, cz - 0.09, cz + 0.09))


@kit.prop('key', tags=['pickup'])
def key():
    g = torus(0.062, 0.022, 10, 4).rot('X', 90).move(0, 0, 0.30)
    g.add(stack([(0.0, 0.020, 0.020), (0.236, 0.022, 0.022)], 6))
    g.add(stack([(0.205, 0.030, 0.030), (0.222, 0.036, 0.036), (0.240, 0.030, 0.030)], 6))
    g.add(bbox(0.075, 0.034, 0.040, 0.008, (0.050, 0, 0.012)))
    g.add(bbox(0.052, 0.034, 0.032, 0.008, (0.040, 0, 0.075)))
    g.color(GOLD).grad('z', 0, 0.38, (0.78, 0.66, 0.64), (1.08, 1.06, 0.98))
    g.add(stud(0.020, 0.012, 0.026, 4).move(0, 0, 0.30).color(LUMEN_MID))
    return g


@kit.prop('bomb', tags=['pickup'])
def bomb():
    g = ellipsoid(0.135, 0.135, 0.13, 10, 6, center=(0, 0, 0.13))
    ramp(g, 'z', [(0.0, H('#262338')), (0.26, H('#55527a'))])
    g.add(ellipsoid(0.034, 0.016, 0.026, 6, 3, center=(-0.062, -0.098, 0.185)).color(H('#a9a8d0')))
    g.add(stack([(0.245, 0.050, 0.050), (0.285, 0.046, 0.046)], 8).color(IRON_HI))
    g.add(tube([(0, 0, 0.28), (0.012, 0, 0.325), (0.050, 0, 0.360), (0.090, 0, 0.365)], 0.011, 5, up=(0, 1, 0)).color(ROPE))
    sp = star(4, 0.050, 0.018, 0.030, 'glow')
    sp.add(star(4, 0.050, 0.018, 0.030, 'glow').rot('Z', 90))
    return g.add(sp.move(0.098, 0, 0.368).color(H('#f2641c')))


# ================================================================= baus
CH_W, CH_D, CH_H = 0.84, 0.54, 0.40   # corpo; com as ferragens o bau ocupa ~0.90 x 0.60


def _chest(rare):
    wood_lo, wood_hi = (H('#1f4f78'), H('#3a86b0')) if rare else (WOOD_LO, WOOD)
    metal, metal_hi = (GOLD_LO, GOLD) if rare else (IRON, IRON_HI)
    cy, hx, hy = -0.30, CH_W / 2, CH_D / 2

    def rect(k, z):
        return [(hx - k, cy - hy + k, z), (hx - k, cy + hy - k, z), (-hx + k, cy + hy - k, z), (-hx + k, cy - hy + k, z)]
    dark = lp.mulc(wood_lo, 0.45)
    rings = [rect(0.02, 0.0), rect(0, 0.03), rect(0, 0.192), rect(0.010, 0.198), rect(0, 0.204), rect(0, CH_H),
             rect(0.045, CH_H), rect(0.045, 0.29)]
    cols = [wood_lo, wood_lo, lp.mixc(wood_lo, wood_hi, 0.5), dark, lp.mixc(wood_lo, wood_hi, 0.55), wood_hi,
            lp.mulc(wood_hi, 0.8), dark]
    base = loft(rings, colors=cols, smooth=False)
    fer = bbox(CH_W + 0.06, CH_D + 0.06, 0.075, 0.015, (0, cy, 0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            fer.add(bbox(0.095, 0.034, CH_H - 0.01, 0.010, (0.29 * sx, cy + sy * (hy + 0.006), 0.01)))
    ramp(fer, 'z', [(0.0, metal), (CH_H, metal_hi)])
    base.add(fer)
    # fechadura na frente
    base.add(bbox(0.15, 0.034, 0.15, 0.02, (0, cy - hy - 0.006, 0.225)).color(GOLD))
    base.add(bbox(0.034, 0.012, 0.06, 0.004, (0, cy - hy - 0.026, 0.262)).color(DARK))
    # tesouro: monte de ouro que aparece quando a tampa abre
    pile = ellipsoid(0.34, 0.21, 0.085, 8, 3, center=(0, cy, 0.305))
    ramp(pile, 'z', [(0.25, GOLD_LO), (0.39, GOLD_HI)])
    for (x, y, a) in ((-0.17, cy - 0.06, 20), (0.12, cy + 0.07, -30), (0.20, cy - 0.08, 12)):
        pile.add(cyl(0.05, 0.014, 8, center=(0, 0, 0)).rot('X', a).move(x, y, 0.372).color(GOLD_HI))
    base.add(pile)
    ao(base, 0.5)
    glow = Geo()
    if rare:
        for (x, y, r, h, t) in ((0.02, cy + 0.02, 0.040, 0.105, 8), (-0.24, cy + 0.06, 0.028, 0.08, -20)):
            glow.add(lumen(crystal(r, h, 5).rot('Y', t).move(x, y, 0.29), 0.29, 0.40))
        glow.add(stud(0.030, 0.019, 0.034, 4).move(0, cy - hy - 0.006, 0.31).color(LUMEN_MID))
    base.add(glow)

    # tampa: origem na dobradica (y=0, z=0), abaulada
    prof = [(-0.57, 0.0), (-0.03, 0.0), (-0.03, 0.05)]
    for i in range(1, 6):
        a = math.pi * i / 6
        prof.append((cy + 0.27 * math.cos(a), 0.05 + 0.185 * math.sin(a)))
    prof.append((-0.57, 0.05))
    lid = poly_extrude(prof, CH_W).rot('Z', 90)
    ramp(lid, 'z', [(0.0, lp.mixc(wood_lo, wood_hi, 0.4)), (0.235, wood_hi)])
    lid.tint(lambda p, c: dark if p.z < 0.001 else c)
    out = inset(prof, -0.016)
    lf = Geo()
    for sx in (-1, 1):
        lf.add(poly_extrude(out, 0.095).rot('Z', 90).move(0.29 * sx, 0, 0))
    ramp(lf, 'z', [(0.0, metal), (0.25, metal_hi)])
    lid.add(lf)
    lid.add(bbox(0.10, 0.03, 0.10, 0.012, (0, cy - hy - 0.02, -0.035)).color(GOLD_HI))
    lp.bake_ao(lid, strength=0.35, dist=0.3, samples=16)
    if rare:
        crest = plate(sym([(0.0, 0.0), (0.12, 0.0), (0.16, 0.05), (0.07, 0.045), (0.035, 0.10), (0.0, 0.075)]), 0.05, 0.01)
        crest.move(0, cy, 0.225).color(GOLD_HI)
        lid.add(crest)
        lid.add(lumen(gem(0.036, 0.10, 4, lo=0.4).move(0, cy, 0.30), 0.26, 0.36))
    return base, lid


_CHESTS = {}


def _chest_part(rare, i):
    if rare not in _CHESTS:
        _CHESTS[rare] = _chest(rare)
    return _CHESTS[rare][i]


@kit.prop('chest_base', collider=('cyl', 0.55, 0.45), tags=['chest', 'interact'], lid='chest_lid', origin='hinge')
def chest_base():
    return _chest_part(False, 0)


@kit.prop('chest_lid', tags=['chest', 'part'], origin='hinge')
def chest_lid():
    return _chest_part(False, 1)


@kit.prop('chest_rare_base', collider=('cyl', 0.55, 0.45), tags=['chest', 'interact', 'rare'], lid='chest_rare_lid',
          origin='hinge', light=dict(color='#7df9ff', energy=0.8, height=0.5, range=3.0))
def chest_rare_base():
    return _chest_part(True, 0)


@kit.prop('chest_rare_lid', tags=['chest', 'part', 'rare'], origin='hinge')
def chest_rare_lid():
    return _chest_part(True, 1)


# ================================================================= marcos de pedra
def _rune(kind, s=1.0):
    """Glifos simples (x, z) para runas acesas."""
    shapes = {
        'dia': [(0, -0.07), (0.045, 0), (0, 0.07), (-0.045, 0)],
        'chev': [(0, -0.02), (0.055, -0.06), (0.055, -0.015), (0, 0.065), (-0.055, -0.015), (-0.055, -0.06)],
        'bar': [(-0.016, -0.08), (0.016, -0.08), (0.016, 0.0), (0.06, 0.045), (0.035, 0.07), (0.016, 0.05),
                (0.016, 0.08), (-0.016, 0.08)],
        'tri': [(-0.05, -0.05), (0.05, -0.05), (0, 0.06)],
    }
    return [(x * s, z * s) for x, z in shapes[kind]]


@kit.prop('portal_arch', tags=['portal', 'landmark'], light=dict(color='#7df9ff', energy=1.6, height=2.0, range=7.0))
def portal_arch():
    g = Geo()
    glow = Geo()
    rnd = random.Random(7)
    D = 0.52
    for s in (-1, 1):
        cx = 1.12 * s
        g.add(stone_box(0.66, D + 0.16, 0.26, (cx, 0, 0), 0.92, 0.04))
        z = 0.26
        for i, (w, hgt, dx) in enumerate(((0.46, 0.50, 0.0), (0.42, 0.46, 0.012), (0.46, 0.48, -0.010))):
            b = plate([(-w / 2, 0), (w / 2, 0), (w / 2, hgt - 0.012), (-w / 2, hgt - 0.012)], D - 0.03 * (i % 2), 0.03)
            ramp(b, 'z', [(0, lp.mulc(STONE_LO, rnd.uniform(0.95, 1.12))), (hgt, lp.mulc(STONE, rnd.uniform(0.94, 1.1)))])
            g.add(b.move(cx + dx * s, 0, z))
            if i > 0:
                r = poly_extrude(_rune(('chev', 'bar')[i - 1] if s < 0 else ('dia', 'tri')[i - 1], 1.5), D + 0.02, 'glow')
                glow.add(r.move(cx + dx * s, 0, z + hgt / 2))
            z += hgt
        g.add(stone_box(0.56, D + 0.08, 0.13, (cx, 0, z), 1.08, 0.03))
    # arco: aduelas em leque + chave maior com a gema
    cz, r0, r1, n = 1.83, 0.90, 1.36, 7
    for i in range(n):
        a0 = math.pi * i / n + 0.012
        a1 = math.pi * (i + 1) / n - 0.012
        key = i == n // 2
        ra, rb = (r0 - 0.03, r1 + 0.10) if key else (r0, r1 - 0.03 * (i % 2))
        pts = [(ra * math.cos(a0), ra * math.sin(a0)), (rb * math.cos(a0), rb * math.sin(a0)),
               (rb * math.cos(a1), rb * math.sin(a1)), (ra * math.cos(a1), ra * math.sin(a1))]
        b = plate(pts, D + (0.06 if key else 0.0), 0.03)
        k = rnd.uniform(0.94, 1.1)
        b.tint(lambda p, c, k=k: lp.mixc(lp.mulc(STONE_LO, k), lp.mulc(STONE_HI, k), min(1.0, max(0.0, (p.z - 0.2) / 1.2))))
        g.add(b.move(0, 0, cz))
    g.add(moss(-1.22, -0.18, 0.27, 0.16)).add(moss(1.05, 0.2, 0.27, 0.13)).add(moss(-0.55, -0.1, cz + 1.27, 0.17))
    g.add(moss(0.95, -0.12, cz + 0.98, 0.13)).add(moss(1.30, -0.26, 0.03, 0.2))
    g.add(rock(0.17, 3).move(-1.52, -0.22, 0.09)).add(rock(0.12, 5, sub=0).move(1.5, 0.25, 0.06))
    ao(g, 0.55)
    glow.add(stud(0.085, D / 2 + 0.035, D / 2 + 0.10, 4).move(0, 0, cz + 1.14))
    glow.color(LUMEN_MID)
    return g.add(glow)


@kit.prop('reward_pedestal', collider=('cyl', 0.44, 0.74), tags=['interact', 'reward'],
          light=dict(color='#7df9ff', energy=0.8, height=0.9, range=3.5))
def reward_pedestal():
    g = lathe([(0.0, 0.0), (0.47, 0.0), (0.49, 0.06), (0.44, 0.13), (0.31, 0.15), (0.27, 0.21), (0.24, 0.50),
               (0.30, 0.56), (0.43, 0.60), (0.45, 0.70), (0.39, 0.74), (0.0, 0.72)], 8, smooth=False, phase=0.5)
    ramp(g, 'z', [(0.0, STONE_LO), (0.2, STONE), (0.74, STONE_HI)])
    g.add(moss(0.36, -0.22, 0.13, 0.13)).add(moss(-0.30, 0.30, 0.13, 0.10)).add(rock(0.10, 2, sub=0).move(-0.47, -0.3, 0.05))
    ao(g, 0.5)
    glow = torus(0.25, 0.024, 12, 4, 'glow', rz=0.014).move(0, 0, 0.735)
    for i, kind in enumerate(('dia', 'chev', 'tri', 'bar')):
        r = poly_extrude(_rune(kind, 0.95), 0.03, 'glow').move(0, -0.222, 0.355).rot('Z', 90 * i)
        glow.add(r)
    return g.add(glow.color(LUMEN_MID))


@kit.prop('altar', collider=('box', 1.4, 0.95, 0.9), tags=['interact', 'shrine'],
          light=dict(color='#7df9ff', energy=2.0, height=1.3, range=6.0))
def altar():
    g = stone_box(1.50, 1.00, 0.14, (0, 0, 0), 0.9, 0.035)
    g.add(stone_box(1.24, 0.80, 0.13, (0, 0, 0.14), 1.0, 0.03))
    g.add(stone_box(0.96, 0.58, 0.45, (0, 0, 0.27), 0.95, 0.04))
    g.add(bbox(1.00, 0.62, 0.05, 0.012, (0, 0, 0.635)).color(GOLD))
    g.add(stone_box(1.18, 0.76, 0.13, (0, 0, 0.71), 1.1, 0.035))
    for s in (-1, 1):       # pequenos pilares com tigela dourada
        g.add(stone_box(0.20, 0.20, 0.40, (0.60 * s, -0.36, 0.14), 1.02, 0.03))
        g.add(lathe([(0.05, 0.54), (0.10, 0.60), (0.085, 0.62), (0.0, 0.59)], 6, smooth=False).move(0.60 * s, -0.36, 0).color(GOLD))
    g.add(moss(-0.52, 0.30, 0.28, 0.15)).add(moss(0.66, 0.36, 0.15, 0.13)).add(moss(0.30, 0.12, 0.845, 0.12))
    ao(g, 0.55)
    glow = Geo()
    for (x, y, r, h, t, n) in ((0.0, 0.03, 0.17, 0.82, 5, 6), (0.24, 0.05, 0.10, 0.46, 24, 5),
                               (-0.22, -0.02, 0.085, 0.36, -27, 5), (0.05, -0.20, 0.055, 0.20, 12, 4)):
        glow.add(lumen(crystal(r, h, n).rot('Y', t).move(x, y, 0.82), 0.82, 0.82 + h))
    glow.add(poly_extrude(_rune('chev', 1.9), 0.03, 'glow').move(0, -0.285, 0.47).color(LUMEN_MID))
    for s in (-1, 1):
        glow.add(gem(0.045, 0.11, 4, lo=0.35).move(0.60 * s, -0.36, 0.635).color(LUMEN_MID))
    return g.add(glow)


# ================================================================= vila
@kit.prop('shop_stall', collider=('box', 2.3, 1.3, 1.0), tags=['interact', 'shop'],
          light=dict(color='#ffc878', energy=1.5, height=1.6, range=5.0))
def shop_stall():
    g = Geo()
    for sx in (-1, 1):
        g.add(wood_box(0.10, 0.10, 1.96, (1.05 * sx, -0.50, 0), 0.8, 0.02, WOOD_LO))
        g.add(wood_box(0.10, 0.10, 2.26, (1.05 * sx, 0.52, 0), 0.8, 0.02, WOOD_LO))
        g.add(box(0.06, 1.0, 0.07, center=(1.05 * sx, 0.01, 0.95)).color(WOOD_LO))
    # balcao
    g.add(ramp(bbox(2.0, 0.52, 0.80, 0.02, (0, -0.44, 0)), 'z', [(0, WOOD_LO), (0.8, WOOD)]))
    for x in (-0.66, 0.0, 0.66):
        g.add(bbox(0.56, 0.03, 0.56, 0.03, (x, -0.705, 0.12)).color(lp.mulc(WOOD_HI, 0.92)))
    g.add(bbox(2.24, 0.68, 0.07, 0.02, (0, -0.44, 0.80)).color(WOOD_HI))
    # fundo com prateleira
    g.add(box(2.04, 0.05, 1.30, center=(0, 0.55, 0.65)).color(lp.mulc(WOOD_LO, 0.85)))
    g.add(bbox(2.04, 0.30, 0.05, 0.012, (0, 0.40, 1.05)).color(WOOD))
    g.add(box(2.2, 0.07, 0.08, center=(0, -0.50, 1.90)).color(WOOD_LO))
    g.add(box(2.2, 0.07, 0.08, center=(0, 0.52, 2.20)).color(WOOD_LO))
    # mercadorias
    g.add(flask(0.085, 0.24, H('#e8436b'), 6).move(-0.72, -0.42, 0.87))
    g.add(flask(0.065, 0.19, H('#3fc6d8'), 6).move(-0.50, -0.34, 0.87))
    for i in range(3):
        g.add(cyl(0.07, 0.024, 8, center=(0.18 + 0.012 * i, -0.45, 0.885 + 0.026 * i)).color(GOLD if i % 2 else GOLD_HI))
    g.add(cyl(0.07, 0.024, 8).rot('X', 68).move(0.34, -0.42, 0.935).color(GOLD))
    g.add(wood_box(0.30, 0.24, 0.20, (0.72, -0.42, 0.87), 1.0, 0.02))
    g.add(bbox(0.33, 0.27, 0.05, 0.012, (0.72, -0.42, 1.06)).color(WOOD_LO))
    g.add(flask(0.075, 0.22, H('#7fd46a'), 6).move(-0.6, 0.40, 1.10))
    g.add(flask(0.075, 0.22, H('#f2b632'), 6).move(-0.2, 0.40, 1.10))
    g.add(wood_box(0.34, 0.22, 0.22, (0.55, 0.40, 1.10), 0.9, 0.02))
    # placa redonda pendurada com a moeda
    sign = lathe([(0.0, -0.02), (0.19, -0.02), (0.21, 0.0), (0.19, 0.02), (0.0, 0.02)], 10, smooth=False).rot('X', 90)
    sign.color(WOOD_HI)
    sign.add(star(5, 0.12, 0.052, 0.066).color(GOLD))
    g.add(sign.move(0, -0.80, 1.60))
    for x in (-0.12, 0.12):
        g.add(box(0.016, 0.016, 0.16, center=(x, -0.80, 1.86)).color(DARK))
    shade(g)
    ao(g, 0.5)
    # toldo listrado + barrado que balanca
    n, x0, w = 8, -1.26, 2.52 / 8
    top = Geo()
    val = Geo()
    for i in range(n):
        xa, xb = x0 + w * i, x0 + w * (i + 1)
        c = RED if i % 2 == 0 else CREAM
        st = prism([(xa, -0.82), (xb, -0.82), (xb, 0.66), (xa, 0.66)], 0.0, 0.05)
        st.warp(lambda p: Vector((p.x, p.y, p.z + 1.94 + (p.y + 0.82) * 0.26)))
        top.add(st.color(c).grad('y', -0.82, 0.66, lp.WHITE, (0.80, 0.76, 0.88)))
        tab = poly_extrude([(xa, 0.0), (xb, 0.0), (xb, -0.15), ((xa + xb) / 2, -0.24), (xa, -0.15)], 0.03, 'vcol_wind')
        val.add(tab.move(0, -0.82, 1.955).color(lp.mulc(c, 0.9)))
    g.add(top).add(val)
    # lanterna
    g.add(box(0.014, 0.014, 0.22, center=(0.80, -0.50, 1.76)).color(DARK))
    g.add(cone(0.085, 0.06, 4, center=(0.80, -0.50, 1.62), phase=0.5, smooth=False).color(IRON))
    g.add(cyl(0.07, 0.02, 4, center=(0.80, -0.50, 1.44), phase=0.5).color(IRON))
    g.add(lathe([(0.05, 1.45), (0.07, 1.54), (0.055, 1.62)], 4, 'glow', phase=0.5, smooth=False).move(0.80, -0.50, 0)
          .color(H('#f2a23a')))
    return g


@kit.prop('wardrobe', collider=('box', 2.0, 0.7, 2.0), tags=['interact', 'wardrobe'])
def wardrobe():
    g = Geo()
    cx = -0.30                      # centro do armario
    hi, lo = H('#b97a45'), H('#7a4a2c')
    g.add(ramp(bbox(1.10, 0.56, 0.32, 0.025, (cx, 0, 0)), 'z', [(0, lo), (0.32, hi)]))
    g.add(bbox(0.88, 0.03, 0.19, 0.02, (cx, -0.285, 0.07)).color(lp.mulc(hi, 1.08)))
    for dx in (-0.2, 0.2):
        g.add(gem(0.03, 0.05, 6, 'vcol', lo=0.5).rot('X', 90).move(cx + dx, -0.31, 0.165).color(GOLD))
    g.add(box(1.0, 0.04, 1.46, center=(cx, 0.24, 1.05)).color(lp.mulc(lo, 0.62)))
    for sx in (-1, 1):
        g.add(ramp(bbox(0.06, 0.52, 1.46, 0.015, (cx + 0.50 * sx, 0, 0.32)), 'z', [(0.32, lo), (1.78, hi)]))
    g.add(bbox(1.16, 0.60, 0.11, 0.03, (cx, 0, 1.78)).color(hi))
    crest = plate(sym([(0.0, 0.0), (0.50, 0.0), (0.50, 0.04), (0.30, 0.07), (0.14, 0.17), (0.0, 0.20)]), 0.07, 0.015)
    g.add(crest.move(cx, -0.24, 1.885).color(lp.mulc(hi, 1.06)))
    g.add(star(5, 0.065, 0.028, 0.03).move(cx, -0.28, 1.975).color(GOLD))
    # portas abertas
    for sx, ang in ((-1, 112), (1, 96)):
        d = bbox(0.50, 0.04, 1.42, 0.012, (0.25, 0, 0)).color(hi)
        d.add(bbox(0.36, 0.02, 0.52, 0.02, (0.25, -0.022, 0.14)).color(lp.mulc(lo, 1.1)))
        d.add(bbox(0.36, 0.02, 0.52, 0.02, (0.25, -0.022, 0.76)).color(lp.mulc(lo, 1.1)))
        d.add(gem(0.022, 0.04, 6, 'vcol', lo=0.5).rot('X', 90).move(0.44, -0.04, 0.71).color(GOLD))
        if sx > 0:
            d.scale(-1, 1, 1)
        d.rot('Z', -ang * sx)
        g.add(d.move(cx + 0.53 * sx, -0.27, 0.34))
    # cabideiro, botas
    g.add(cyl(0.016, 0.96, 6).rot('Y', 90).move(cx, 0.02, 1.66).color(GOLD_LO))
    for bx in (-0.08, 0.10):
        g.add(bbox(0.11, 0.13, 0.20, 0.03, (cx + 0.26 + bx, 0.02, 0.32)).color(WOOD_DK))
        g.add(bbox(0.11, 0.20, 0.09, 0.03, (cx + 0.26 + bx, -0.03, 0.32)).color(WOOD_DK))
    # chapeu de mago em cima
    hat = lathe([(0.0, 0.0), (0.20, 0.0), (0.20, 0.014), (0.10, 0.03), (0.062, 0.15), (0.0, 0.30)], 8)
    ramp(hat, 'z', [(0, NIGHT_LO), (0.3, NIGHT)])
    hat.warp(lambda p: Vector((p.x + 0.5 * max(0.0, p.z - 0.1) ** 1.3, p.y, p.z)))
    hat.add(stack([(0.028, 0.104, 0.104), (0.056, 0.092, 0.092)], 8, cap_a=False, cap_b=False).color(GOLD))
    g.add(hat.move(cx - 0.26, 0.02, 1.89))
    # espelho de pe com moldura dourada
    m = Geo()
    mz, rx, rz = 1.06, 0.25, 0.50
    path = [(rx * math.sin(TAU * i / 16), 0, mz - rz * math.cos(TAU * i / 16)) for i in range(17)]
    m.add(tube(path, 0.034, 5, up=(0, 1, 0)).color(GOLD))
    m.add(star(5, 0.085, 0.036, 0.04).move(0, 0, mz + rz + 0.075).color(GOLD_HI))
    foot = lathe([(0.0, 0.0), (0.21, 0.0), (0.22, 0.04), (0.085, 0.10), (0.04, 0.30), (0.062, 0.47), (0.03, 0.53)], 8)
    m.add(foot.color(GOLD_LO))
    glass = cyl(1.0, 0.03, 16).rot('X', 90).scale(rx, 1.0, rz).move(0, 0, mz)
    glass.tint(lambda p, c: lp.mixc(H('#7fcfe6'), H('#eafcff'), min(1.0, max(0.0, 0.5 + (p.x * 1.2 + (p.z - mz)) / 0.9))))
    m.add(glass)
    for dx, wd in ((-0.05, 0.05), (0.06, 0.022)):
        m.add(poly_extrude([(dx - 0.09, mz - 0.14), (dx - 0.09 + wd, mz - 0.14), (dx + 0.09 + wd, mz + 0.22),
                            (dx + 0.09, mz + 0.22)], 0.012).move(0, -0.012, 0).color(H('#ffffff')))
    g.add(m.rot('Z', -14).move(0.70, -0.06, 0))
    shade(g, (0.80, 0.78, 0.92), (1.04, 1.03, 1.0))
    ao(g, 0.5)
    # roupas penduradas (balancam)
    tunic = sym([(0.0, 0.0), (0.135, 0.0), (0.105, 0.29), (0.150, 0.33), (0.120, 0.44), (0.045, 0.47), (0.0, 0.445)])
    for x, c in ((-0.30, H('#3f86d9')), (0.0, RED), (0.30, H('#58b368'))):
        t = poly_extrude(tunic, 0.07, 'vcol_wind')
        ramp(t, 'z', [(0.0, lp.mulc(c, 0.62)), (0.47, c)])
        t.add(bbox(0.20, 0.076, 0.035, 0.008, (0, 0, 0.19), 'vcol_wind').color(GOLD if c is RED else CREAM))
        g.add(t.move(cx + x, 0.02, 1.17))
        g.add(box(0.012, 0.012, 0.05, center=(cx + x, 0.02, 1.655)).color(DARK))
    return g.move(0.06, 0, 0)


@kit.prop('dummy', collider=('cyl', 0.32, 1.3), tags=['dummy', 'training'])
def dummy():
    g = Geo()
    for a in (35, 125):
        g.add(wood_box(0.86, 0.12, 0.07, (0, 0, 0), 0.85, 0.02, WOOD_LO).rot('Z', a))
    g.add(ramp(stack([(0.0, 0.058, 0.058), (1.0, 0.05, 0.05)], 6), 'z', [(0, WOOD_LO), (1.0, WOOD)]))
    body = lathe([(0.0, 0.40), (0.13, 0.42), (0.21, 0.49), (0.245, 0.63), (0.25, 0.80), (0.21, 0.94), (0.11, 1.0),
                  (0.0, 1.0)], 8, phase=0.5)
    ramp(body, 'z', [(0.40, STRAW_LO), (0.70, STRAW), (1.0, lp.mulc(STRAW, 1.08))])
    g.add(body)
    g.add(torus(0.238, 0.022, 8, 4).rot('Z', 22.5).move(0, 0, 0.60).color(ROPE))
    g.add(torus(0.125, 0.020, 8, 4).rot('Z', 22.5).move(0, 0, 0.985).color(ROPE))
    arm = stack([(-0.44, 0.04, 0.04), (0.44, 0.04, 0.04)], 6).rot('Y', 90).move(0, 0, 0.86)
    g.add(arm.color(WOOD_LO))
    for s in (-1, 1):
        cuff = lathe([(0.05, 0.0), (0.085, 0.11), (0.06, 0.13), (0.0, 0.10)], 6).rot('Y', 90 * s).move(0.40 * s, 0, 0.86)
        g.add(cuff.color(STRAW))
    # alvo pintado no peito
    for r, c, y in ((0.125, RED, -0.236), (0.082, CREAM, -0.242), (0.040, RED, -0.248)):
        g.add(cyl(r, 0.012, 10).rot('X', 90).move(0, y, 0.74).color(c))
    # cabeca de palha + balde de elmo, meio torto
    hd = ellipsoid(0.135, 0.13, 0.12, 8, 4, center=(0, 0, 1.10)).color(STRAW)
    bk = lathe([(0.185, 1.085), (0.19, 1.11), (0.165, 1.115), (0.142, 1.33), (0.0, 1.345)], 8, phase=0.5)
    ramp(bk, 'z', [(1.08, IRON), (1.34, IRON_HI)])
    bk.add(bbox(0.17, 0.02, 0.034, 0.006, (0, -0.158, 1.175)).color(DARK))
    bk.add(torus(0.15, 0.012, 8, 3).rot('Z', 22.5).move(0, 0, 1.29).color(IRON))
    bk.rot('Y', 9, pivot=(0, 0, 1.1)).rot('X', -5, pivot=(0, 0, 1.1))
    g.add(hd).add(bk)
    shade(g, (0.80, 0.78, 0.92), (1.04, 1.03, 1.0))
    return ao(g, 0.5)


@kit.prop('signpost', collider=('cyl', 0.12, 1.8), tags=['deco', 'sign', 'interact'])
def signpost():
    g = ramp(bbox(0.11, 0.11, 1.74, 0.02, (0, 0, 0)), 'z', [(0, WOOD_DK), (1.74, WOOD_LO)])
    g.add(cone(0.085, 0.09, 4, center=(0, 0, 1.74), phase=0.5, smooth=False).color(WOOD_LO))
    arrow_pts = [(-0.28, -0.095), (0.30, -0.095), (0.46, 0.0), (0.30, 0.095), (-0.28, 0.095)]
    for z, flip, tilt, tone in ((1.46, 1, 4, 1.0), (1.14, -1, -6, 0.9)):
        b = plate(arrow_pts, 0.05, 0.012).color(lp.mulc(WOOD_HI, tone))
        b.add(poly_extrude([(-0.24, -0.095), (-0.17, -0.095), (-0.17, 0.095), (-0.24, 0.095)], 0.056).color(TEAL))
        b.add(poly_extrude(_rune('dia', 0.75), 0.058).move(0.08, 0, 0).color(CREAM))
        b.add(cyl(0.016, 0.07, 5).rot('X', 90).move(-0.05, 0, 0).color(DARK))
        if flip < 0:
            b.scale(-1, 1, 1)
        g.add(b.rot('Y', tilt).move(0.05 * flip, -0.078, z))
    g.rot('Y', 2.5)
    g.add(rock(0.13, 4).move(0.12, 0.04, 0.06)).add(rock(0.10, 9, sub=0).move(-0.13, -0.06, 0.05))
    g.add(moss(-0.04, 0.12, 0.05, 0.11))
    return ao(g, 0.5)


@kit.prop('campfire', collider=('cyl', 0.5, 0.3), tags=['deco', 'fire', 'camp'],
          light=dict(color='#ffa040', energy=2.5, height=0.5, range=7.0))
def campfire():
    g = cyl(0.36, 0.03, 10, center=(0, 0, 0.015)).color(H('#3a3545'))
    for i in range(7):
        a = TAU * i / 7 + 0.2
        r = 0.105 + 0.03 * ((i * 37) % 3) / 2
        g.add(rock(r, 20 + i, 0.72).rot('Z', i * 50).move(0.43 * math.cos(a), 0.43 * math.sin(a), r * 0.55))
    for i, (ang, tilt, ln) in enumerate(((10, 62, 0.50), (100, 58, 0.46), (190, 64, 0.52), (275, 60, 0.48))):
        lg = log(0.058, ln).move(0, 0, -ln * 0.42).rot('Y', tilt).move(0, 0, 0.17).rot('Z', ang)
        g.add(lg)
    ao(g, 0.55)
    em = lathe([(0.20, 0.03), (0.14, 0.085), (0.0, 0.11)], 6, 'glow', smooth=False)
    ramp(em, 'z', [(0.03, H('#a8260f')), (0.11, EMBER)])
    return g.add(em)


@kit.prop('bench', collider=('box', 1.3, 0.5, 0.42), tags=['deco', 'seat'])
def bench():
    g = Geo()
    for y, tone in ((-0.095, 1.0), (0.095, 0.92)):
        g.add(wood_box(1.34, 0.18, 0.06, (0, y, 0.34), tone, 0.015, WOOD_HI))
    for sx in (-1, 1):
        leg = plate([(-0.20, 0.0), (-0.10, 0.0), (-0.07, 0.10), (0.07, 0.10), (0.10, 0.0), (0.20, 0.0), (0.16, 0.34),
                     (-0.16, 0.34)], 0.08, 0.012).rot('Z', 90)
        g.add(leg.move(0.50 * sx, 0, 0).color(WOOD_LO))
        post = wood_box(0.07, 0.06, 0.46, (0.50 * sx, 0.20, 0.34), 1.0, 0.012, WOOD_LO)
        g.add(post.rot('X', -9, pivot=(0, 0.20, 0.34)))
    back = wood_box(1.34, 0.045, 0.17, (0, 0.20, 0.60), 1.0, 0.012, WOOD)
    g.add(back.rot('X', -9, pivot=(0, 0.20, 0.34)))
    g.add(wood_box(0.92, 0.05, 0.06, (0, 0, 0.12), 0.9, 0.012, WOOD_LO))
    cush = bbox(0.34, 0.32, 0.075, 0.03, (-0.36, -0.01, 0.40))
    g.add(ramp(cush, 'z', [(0.40, TEAL_LO), (0.475, TEAL)]))
    shade(g, (0.82, 0.80, 0.92), (1.04, 1.03, 1.0))
    return ao(g, 0.5)


@kit.prop('crate', collider=('box', 0.7, 0.7, 0.7), tags=['deco', 'breakable'])
def crate():
    g = box(0.62, 0.62, 0.60, center=(0, 0, 0.35)).color(lp.mulc(WOOD, 0.86))
    for z in (0.0, 0.61):
        g.add(wood_box(0.70, 0.70, 0.09, (0, 0, z), 1.0, 0.015, WOOD_HI))
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.add(wood_box(0.09, 0.09, 0.54, (0.305 * sx, 0.305 * sy, 0.08), 0.95, 0.012, WOOD_HI))
    for i in range(4):
        br = wood_box(0.075, 0.03, 0.70, (0, 0, -0.35), 1.05, 0.008, WOOD_HI).rot('Y', 45 if i % 2 == 0 else -45)
        g.add(br.move(0, -0.318, 0.35).rot('Z', 90 * i))
    shade(g, (0.80, 0.78, 0.92), (1.04, 1.03, 1.0))
    return ao(g, 0.5)


@kit.prop('barrel', collider=('cyl', 0.33, 0.8), tags=['deco', 'breakable'])
def barrel():
    g = lathe([(0.0, 0.0), (0.24, 0.0), (0.295, 0.18), (0.32, 0.40), (0.295, 0.62), (0.24, 0.80), (0.205, 0.80),
               (0.20, 0.755), (0.0, 0.755)], 12, smooth=False)
    ramp(g, 'z', [(0.0, WOOD_LO), (0.45, WOOD), (0.80, WOOD_HI)])
    idx = {}
    g.tint(lambda p, c: lp.mulc(c, 0.86 + 0.16 * ((round(math.atan2(p.y, p.x) / (TAU / 12)) % 3) / 2)))
    for z, r in ((0.15, 0.292), (0.65, 0.292)):
        g.add(stack([(z - 0.03, r, r), (z + 0.03, r + 0.004 * (1 if z < 0.4 else -1), r + 0.004 * (1 if z < 0.4 else -1))],
                    12, cap_a=False, cap_b=False).color(IRON))
    g.add(cyl(0.035, 0.03, 6).rot('X', 90).move(0, -0.318, 0.40).color(WOOD_DK))
    return ao(g, 0.5)


@kit.prop('lantern_post', collider=('cyl', 0.14, 2.3), tags=['deco', 'light'],
          light=dict(color='#7df9ff', energy=2.0, height=1.9, range=7.0))
def lantern_post():
    g = lathe([(0.0, 0.0), (0.21, 0.0), (0.22, 0.07), (0.15, 0.15), (0.10, 0.22), (0.0, 0.22)], 8, smooth=False, phase=0.5)
    ramp(g, 'z', [(0.0, STONE_LO), (0.22, STONE_HI)])
    path = [(0, 0, 0.12), (0.012, 0, 1.0), (0.0, 0, 1.85), (0.01, 0, 2.12), (0.07, 0, 2.28), (0.19, 0, 2.36),
            (0.32, 0, 2.34), (0.40, 0, 2.25)]
    post = tube(path, [0.060, 0.055, 0.050, 0.048, 0.044, 0.040, 0.034, 0.028], 6, up=(0, 1, 0))
    g.add(ramp(post, 'z', [(0.1, WOOD_DK), (2.3, WOOD_LO)]))
    g.add(stack([(1.02, 0.064, 0.064), (1.10, 0.064, 0.064)], 6).color(IRON))
    lx = 0.40
    g.add(box(0.014, 0.014, 0.12, center=(lx, 0, 2.19)).color(DARK))
    fr = cone(0.13, 0.09, 4, center=(lx, 0, 2.05), phase=0.5, smooth=False)
    fr.add(bbox(0.19, 0.19, 0.035, 0.012, (lx, 0, 1.75)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            fr.add(box(0.016, 0.016, 0.28, center=(lx + 0.078 * sx, 0.078 * sy, 1.92)))
    g.add(fr.color(IRON))
    g.add(moss(0.14, -0.12, 0.10, 0.10))
    ao(g, 0.5)
    return g.add(lumen(gem(0.062, 0.22, 4, lo=0.45).rot('Z', 45).move(lx, 0, 1.905), 1.80, 2.03))


@kit.prop('banner', collider=('cyl', 0.2, 2.8), tags=['deco', 'banner'])
def banner():
    g = stone_box(0.42, 0.42, 0.16, (0, 0, 0), 0.95, 0.03)
    g.add(stone_box(0.28, 0.28, 0.10, (0, 0, 0.16), 1.08, 0.025))
    g.add(ramp(stack([(0.2, 0.04, 0.04), (2.76, 0.032, 0.032)], 6), 'z', [(0.2, WOOD_DK), (2.76, WOOD_LO)]))
    g.add(stack([(-0.46, 0.024, 0.024), (0.46, 0.024, 0.024)], 6).rot('Y', 90).move(0, -0.05, 2.56).color(WOOD_LO))
    gold = gem(0.055, 0.17, 6, 'vcol', lo=0.3).move(0, 0, 2.80)
    for s in (-1, 1):
        gold.add(gem(0.036, 0.07, 6, 'vcol', lo=0.5).rot('Y', 90).move(0.47 * s, -0.05, 2.56))
    g.add(gold.color(GOLD).grad('z', 2.5, 2.95, (0.8, 0.68, 0.66), (1.06, 1.04, 0.98)))
    ao(g, 0.5)
    # pano em rabo de andorinha (balanca)
    rows = []
    zs = [1.18, 1.42, 1.66, 1.90, 2.14, 2.38, 2.585]
    xs = [-0.36, -0.18, 0.0, 0.18, 0.36]
    for ri, z in enumerate(zs):
        row = []
        for x in xs:
            zz = z + (0.26 * (1 - abs(x) / 0.36) if ri == 0 else 0.0)
            row.append((x, -0.07 - 0.035 * math.sin((2.585 - z) * 3.4) * min(1.0, (2.585 - z) / 0.5), zz))
        rows.append(row)
    cl = lp.sheet(rows, 'vcol_wind', thickness=0.014)
    ramp(cl, 'z', [(1.18, GOLD), (1.50, TEAL_LO), (2.58, TEAL)])
    cl.tint(lambda p, c: GOLD_HI if p.z > 2.52 else c)
    cl.add(star(5, 0.17, 0.072, 0.05, 'vcol_wind').move(0, -0.085, 2.06).color(GOLD_HI))
    return g.add(cl)


@kit.prop('bridge_plank', collider=('box', 2.0, 4.0, 0.22), tags=['bridge', 'platform'])
def bridge_plank():
    g = Geo()
    rnd = random.Random(11)
    for sx in (-1, 1):
        g.add(wood_box(0.18, 4.0, 0.14, (0.72 * sx, 0, 0), 0.8, 0.02, WOOD_DK))
    n = 10
    for i in range(n):
        y = -2.0 + 0.4 * (i + 0.5)
        p = wood_box(2.0 + rnd.uniform(-0.06, 0.06), 0.37, 0.08, (rnd.uniform(-0.03, 0.03), 0, 0), 1.0, 0.014,
                     lp.mixc(WOOD, WOOD_HI, rnd.random()))
        g.add(p.rot('Z', rnd.uniform(-1.6, 1.6)).move(0, y, 0.14))
    for sx in (-1, 1):
        for y in (-1.9, 1.9):
            g.add(wood_box(0.14, 0.14, 0.30, (0.92 * sx, y, 0.0), 0.9, 0.02, WOOD_LO))
    shade(g, (0.80, 0.78, 0.92), (1.04, 1.03, 1.0))
    return ao(g, 0.4)


_SPIKE_XY = [(x, y) for x in (-0.3, 0.0, 0.3) for y in (-0.3, 0.0, 0.3)]


@kit.prop('spike_trap', tags=['trap'])
def spike_trap():
    g = stone_box(1.10, 1.10, 0.06, (0, 0, 0), 0.9, 0.02)
    g.add(bbox(0.96, 0.96, 0.03, 0.01, (0, 0, 0.045)).color(IRON))
    for x, y in _SPIKE_XY:
        g.add(cyl(0.075, 0.012, 8, center=(x, y, 0.075), r_top=0.062).color(IRON_HI))
        g.add(cyl(0.05, 0.006, 8, center=(x, y, 0.082)).color(H('#1d1a28')))
    return ao(g, 0.4)


@kit.prop('spike_trap_spikes', tags=['trap', 'part'])
def spike_trap_spikes():
    g = Geo()
    for x, y in _SPIKE_XY:
        sp = lathe([(0.046, 0.0), (0.040, 0.08), (0.0, 0.46)], 5, smooth=False).move(x, y, 0)
        g.add(ramp(sp, 'z', [(0.0, H('#7a829e')), (0.46, H('#f1f5ff'))]))
    return g


if __name__ == '__main__':
    kit.build()

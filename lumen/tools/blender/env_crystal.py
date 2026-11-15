"""env_crystal.py: kit "Gruta de Cristal" (caverna funda sob as ruinas, iluminada pelos
proprios cristais de lumen).

    python3 tools/blender/env_crystal.py [--out caminho.glb] [--only cave_wall_a,rock_b]

Este modulo tambem guarda os ajudantes de modelagem de cenario facetado (pedra por casco
convexo, cristais, estratos, runas, pintura por faceta, luz falsa dos cristais na pedra)
que o env_boss.py reaproveita.

Regras de pintura do kit:
- pedra indigo/violeta, sempre com a base mais escura e fria e as bordas de cima mais claras;
- cristal 'glow' com raiz escura e ponta clara, e cada faceta com um tom (a emissao apaga a
  luz da cena, entao o desenho das facetas precisa estar na cor);
- toda pedra perto de cristal recebe um pouco da cor dele (`spill`).
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lp  # noqa: E402  (carrega o bpy antes do bmesh)
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402
from lp import hexc, mixc, TAU  # noqa: E402
from kit import Kit  # noqa: E402

kit = Kit('env_crystal')

# --------------------------------------------------------------------------- paleta
ROCK_K = hexc('#211c40')   # fundo de fresta
ROCK_D = hexc('#3b3566')
ROCK_M = hexc('#54498a')
ROCK_L = hexc('#7a6fb5')
ROCK_B = hexc('#3d4a86')   # estrato azulado
ROCK_P = hexc('#684a8c')   # estrato arroxeado
CY = hexc('#7df9ff')
VI = hexc('#b48cff')
PK = hexc('#ff8fd8')
ROOT = hexc('#2c1f7a')     # raiz dos cristais
ROOT_P = hexc('#5a1f7e')
TEAL = hexc('#5ff5c8')
STONE = hexc('#b9b4d6')
STONE_D = hexc('#7d77a6')
STONE_L = hexc('#dedaf0')
BASALT = hexc('#34304f')
WOOD = hexc('#5a3f4e')
IRON = hexc('#2e2a44')



def _gem(*cols):
    """Rampa de cristal. O shader soma ~2x a cor como emissao, entao as cores ficam bem abaixo
    de 1 para nao estourar em branco: raiz quase apagada, ponta saturada."""
    return tuple((c[0] * k, c[1] * k, c[2] * k) for c, k in cols)


GEM_CV = _gem((ROOT, 0.26), (hexc('#4f35d8'), 0.22), (hexc('#9a6cff'), 0.3), (CY, 0.55))             # indigo -> violeta -> ciano
GEM_VP = _gem((ROOT_P, 0.26), (hexc('#7d2fd0'), 0.22), (hexc('#d85cf0'), 0.32), (PK, 0.6))          # roxo -> violeta -> rosa
GEM_CP = _gem((ROOT, 0.26), (hexc('#2f5fe0'), 0.22), (hexc('#55e6ff'), 0.32), (hexc('#c4a8ff'), 0.6))  # azul -> ciano -> lilas

KEY = Vector((-0.45, -0.55, 0.70)).normalized()     # luz "pintada" (vem da frente-esquerda)


# --------------------------------------------------------------------------- utilidades
def sm(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a))) if b != a else float(x >= b)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def gradn(cols, t):
    """Gradiente por trechos iguais entre varias cores."""
    t = max(0.0, min(1.0, t)) * (len(cols) - 1)
    i = min(int(t), len(cols) - 2)
    return mixc(cols[i], cols[i + 1], t - i)


def mul(c, k):
    if isinstance(k, (int, float)):
        return (c[0] * k, c[1] * k, c[2] * k)
    return (c[0] * k[0], c[1] * k[1], c[2] * k[2])


def fnormal(g, f):
    n = Vector()
    for i in range(len(f)):
        a = g.v[f[i]]
        b = g.v[f[(i + 1) % len(f)]]
        n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
    return n.normalized() if n.length > 1e-12 else Vector((0, 0, 1))


def facet(g):
    """Separa os vertices por face (cada faceta pode ter sua cor) e deixa tudo facetado."""
    out = lp.Geo()
    for f, m in zip(g.f, g.fm):
        out.add_face([out.add_vert(g.v[i], g.w[i], g.c[i]) for i in f], m, False)
    return out


def place(g, pos=(0, 0, 0), tilt=0.0, yaw=0.0, roll=0.0, s=1.0):
    """Escala, inclina em X (positivo = cai para -Y), rola em Y, gira em Z e move."""
    if s != 1.0:
        g.scale(s)
    if roll:
        g.rot('Y', roll)
    if tilt:
        g.rot('X', tilt)
    if yaw:
        g.rot('Z', yaw)
    return g.move(*pos)


def drop_faces(g, fn):
    """Remove as faces em que fn(centroide, normal) e verdadeiro."""
    keep = [i for i, f in enumerate(g.f)
            if not fn(sum((g.v[j] for j in f), Vector()) / len(f), fnormal(g, f))]
    g.f = [g.f[i] for i in keep]
    g.fm = [g.fm[i] for i in keep]
    g.fsm = [g.fsm[i] for i in keep]
    return g.keep_faces(lambda c: True)


def no_bottom(g, z=0.01):
    """Tira as faces viradas para baixo coladas no chao (ninguem ve)."""
    return drop_faces(g, lambda c, n: c.z < z and n.z < -0.9)


# --------------------------------------------------------------------------- formas
def ploft(rings, apex=None, cap_a=False, cap_b=False, mat='vcol'):
    """Loft facetado de aneis (anti-horario visto de cima, subindo), com ponta opcional."""
    g = lp.Geo()
    idx = [[g.add_vert(p) for p in r] for r in rings]
    n = len(rings[0])
    for a, b in zip(idx, idx[1:]):
        for i in range(n):
            j = (i + 1) % n
            g.add_face((a[i], a[j], b[j], b[i]), mat, False)
    if apex is not None:
        ai = g.add_vert(apex)
        top = idx[-1]
        for i in range(n):
            g.add_face((top[i], top[(i + 1) % n], ai), mat, False)
    elif cap_b:
        g.add_face(tuple(idx[-1]), mat, False)
    if cap_a:
        g.add_face(tuple(reversed(idx[0])), mat, False)
    return g


def hull(pts, dissolve=7.0, mat='vcol'):
    """Casco convexo dos pontos: pedra de planos grandes, sem cara de esfera."""
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(p)
    r = bmesh.ops.convex_hull(bm, input=list(bm.verts))
    junk = {e for e in r['geom_interior'] + r['geom_unused'] if isinstance(e, bmesh.types.BMVert)}
    junk = [v for v in junk if v.is_valid and not v.link_faces]
    if junk:
        bmesh.ops.delete(bm, geom=junk, context='VERTS')
    if dissolve:
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(dissolve), verts=list(bm.verts),
                                 edges=list(bm.edges))
    bm.verts.index_update()
    g = lp.Geo()
    for v in bm.verts:
        g.add_vert(v.co)
    cen = sum((v.co for v in bm.verts), Vector()) / max(1, len(bm.verts))
    for f in bm.faces:
        idx = [v.index for v in f.verts]
        c = sum((g.v[i] for i in idx), Vector()) / len(idx)
        if fnormal(g, idx).dot(c - cen) < 0:
            idx.reverse()
        g.add_face(idx, mat, False)
    bm.free()
    return facet(g)


def chunk(seed, w, d, h, n=5, top=0.5, mid=0.4, off=(0.0, 0.0), jit=0.16, peak=1, sink=0.0):
    """Pedregulho anguloso: 3 aneis irregulares + pico(s), fechado por casco convexo.
    top = raio relativo do anel de cima; off = quanto o topo anda para o lado (em raios)."""
    rnd = random.Random(seed)
    pts = []
    rot = rnd.uniform(0, TAU)
    for zf, rf, k in ((0.0, 0.92, 0.0), (mid, 1.0, 0.45), (0.86, top, 1.0)):
        for i in range(n):
            a = rot + TAU * (i + rnd.uniform(-0.28, 0.28)) / n + zf * 1.3
            rr = rf * (1 + rnd.uniform(-jit, jit))
            z = h * zf + (rnd.uniform(-0.07, 0.07) * h if zf > 0 else -sink)
            pts.append((math.cos(a) * rr * w / 2 + off[0] * k * w / 2, math.sin(a) * rr * d / 2 + off[1] * k * d / 2, z))
    for _ in range(peak):
        a = rnd.uniform(0, TAU)
        rr = rnd.uniform(0.0, top * 0.5)
        pts.append((math.cos(a) * rr * w / 2 + off[0] * w / 2, math.sin(a) * rr * d / 2 + off[1] * d / 2, h))
    return hull(pts)


def mesa(seed, w, d, h, n=5, top=0.6, tilt=0.25, off=(0.0, 0.0), jit=0.15, belt=0.0, sink=0.03):
    """Pedra "cortada": base irregular de n lados e um topo plano inclinado, menor e girado.
    belt > 0 engorda a pedra a 1/3 da altura (barriga). off desloca o topo (em raios)."""
    rnd = random.Random(seed)
    rot = rnd.uniform(0, TAU)
    ta = rnd.uniform(0, TAU)
    pts = []
    for i in range(n):
        a = rot + TAU * (i + rnd.uniform(-0.25, 0.25)) / n
        rr = 1 + rnd.uniform(-jit, jit)
        pts.append((math.cos(a) * rr * w / 2, math.sin(a) * rr * d / 2, -sink))
        if belt:
            pts.append((math.cos(a) * rr * w / 2 * (1 + belt) + off[0] * w * 0.15,
                        math.sin(a) * rr * d / 2 * (1 + belt) + off[1] * d * 0.15, h * rnd.uniform(0.25, 0.4)))
    m = max(3, n - 1)
    for i in range(m):
        a = rot + 0.6 + TAU * (i + rnd.uniform(-0.2, 0.2)) / m
        rr = top * (1 + rnd.uniform(-jit, jit))
        pts.append((math.cos(a) * rr * w / 2 + off[0] * w / 2, math.sin(a) * rr * d / 2 + off[1] * d / 2,
                    h * (1 - tilt * 0.5 * (1 + math.cos(a - ta)))))
    return hull(pts, dissolve=2.0)


STALAG = [(0.0, 1.38), (0.06, 1.0), (0.30, 0.76), (0.33, 0.60), (0.60, 0.40), (0.63, 0.29), (0.85, 0.13)]
COLUMN = [(0.0, 1.6), (0.05, 1.12), (0.2, 0.88), (0.23, 0.72), (0.4, 0.55), (0.5, 0.48), (0.6, 0.53), (0.74, 0.68),
          (0.77, 0.83), (0.93, 1.05), (1.0, 1.55)]


def spike(h, r, n=6, seed=0, prof=None, lean=(0.0, 0.0), jit=0.13, squash=1.0, twist=0.25, mat='vcol', apex=True):
    """Estalagmite: cone irregular em degraus (escorrimento de calcario). prof = [(z, r)] relativos.
    apex=False fecha o topo com uma tampa (coluna)."""
    prof = prof or STALAG
    rnd = random.Random(seed)
    fac = [1 + rnd.uniform(-jit, jit) for _ in range(n)]
    rot = rnd.uniform(0, TAU)
    rings = []
    for k, (zf, rf) in enumerate(prof):
        t = zf ** 1.6
        ring = []
        for i in range(n):
            a = rot + TAU * i / n + twist * zf + rnd.uniform(-0.08, 0.08)
            rr = r * rf * fac[i] * (1 + rnd.uniform(-0.06, 0.06))
            flat_end = k == 0 or (not apex and k == len(prof) - 1)
            ring.append((math.cos(a) * rr + lean[0] * t, math.sin(a) * rr * squash + lean[1] * t,
                         h * zf + (0.0 if flat_end else rnd.uniform(-0.02, 0.02) * h)))
        rings.append(ring)
    if apex:
        return facet(ploft(rings, apex=(lean[0] * 1.04, lean[1] * 1.04, h), mat=mat))
    return facet(ploft(rings, cap_b=True, mat=mat))


def slab(poly, h, bevel=0.012, inset=0.035, dome=0.004, cen=None):
    """Laje baixa a partir de um poligono (x, y) anti-horario: lateral, chanfro e tampo em leque."""
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    rad = sum(math.hypot(p[0] - cx, p[1] - cy) for p in poly) / len(poly)
    k = 1 - inset / max(rad, 1e-4)
    top = [(cx + (x - cx) * k, cy + (y - cy) * k, h) for x, y in poly]
    cen = cen or (cx, cy)
    return facet(ploft([[(x, y, 0.0) for x, y in poly], [(x, y, h - bevel) for x, y in poly], top],
                       apex=(cen[0], cen[1], h + dome)))


def hexagon(r, seed=0, jit=0.05, rot=0.0, squash=1.0):
    rnd = random.Random(seed)
    return [(math.cos(TAU * i / 6 + rot) * r * (1 + rnd.uniform(-jit, jit)),
             math.sin(TAU * i / 6 + rot) * r * squash * (1 + rnd.uniform(-jit, jit))) for i in range(6)]


def crystal(h, r, n=6, seed=0, tip=0.3, base=0.7, squash=0.84, off=0.35, cols=GEM_CV, cut=False, power=1.0):
    """Cristal facetado ao longo de +Z, material 'glow', raiz escura -> ponta clara."""
    rnd = random.Random(seed)
    fac = [rnd.uniform(0.8, 1.2) for _ in range(n)]
    rot = rnd.uniform(0, TAU)
    angs = [rot + TAU * (i + rnd.uniform(-0.2, 0.2)) / n for i in range(n)]
    zs = h * (1 - tip)
    ta = rnd.uniform(0, TAU)

    def ring(z, k, zj=0.0):
        out = []
        for a, f in zip(angs, fac):
            dz = zj * math.cos(a - ta) if zj else 0.0
            out.append((math.cos(a) * r * k * f, math.sin(a) * r * k * f * squash, z + dz))
        return out

    rings = [ring(0, base), ring(zs * 0.52, (base + 1) / 2 * 1.03), ring(zs, 1.0, -tip * h * (0.55 if cut else 0.28))]
    if cut:   # ponta em bisel: um plano inclinado em vez de piramide
        top = [(p[0] * 0.3 + math.cos(ta) * r * 0.45, p[1] * 0.3 + math.sin(ta) * r * 0.45 * squash,
                h - (h - p[2]) * 0.22) for p in rings[-1]]
        g = ploft(rings + [top], cap_b=True, mat='glow')
    else:
        g = ploft(rings, apex=(math.cos(ta) * r * off, math.sin(ta) * r * off * squash, h), mat='glow')
    g.c = [gradn(cols, (p.z / h) ** power) for p in g.v]
    return facet(g)


def shard(h, r, seed=0, cols=GEM_CV):
    """Cristalzinho barato (4 lados, ~12 tri)."""
    return crystal(h, r, n=4, seed=seed, tip=0.38, base=0.6, off=0.5, cols=cols)


def cblock(sx, sy, sz, ch=0.06, taper=1.0):
    """Bloco talhado com quinas chanfradas (secao octogonal), base em z=0."""
    def ring(z, inset, k):
        hx, hy = sx / 2 * k - inset, sy / 2 * k - inset
        c = min(ch, hx * 0.6, hy * 0.6)
        return [(hx, -hy + c, z), (hx, hy - c, z), (hx - c, hy, z), (-hx + c, hy, z),
                (-hx, hy - c, z), (-hx, -hy + c, z), (-hx + c, -hy, z), (hx - c, -hy, z)]
    cz = min(ch, sz * 0.3)
    rings = [ring(0, ch * 0.7, 1.0), ring(cz, 0, 1.0), ring(sz - cz, 0, taper), ring(sz, ch * 0.7, taper)]
    return facet(ploft(rings, cap_a=True, cap_b=True))


def drum(r, h, n=10, ch=0.05, flute=0.0, r_top=None, phase=0.0):
    """Tambor de coluna: anel facetado com chanfro em cima e embaixo; flute > 0 = caneluras."""
    r_top = r if r_top is None else r_top

    def ring(z, rr):
        out = []
        for i in range(n):
            a = TAU * (i + phase) / n
            k = rr * (1 - flute if (flute and i % 2) else 1.0)
            out.append((math.cos(a) * k, math.sin(a) * k, z))
        return out
    cz = min(ch, h * 0.3)
    return facet(ploft([ring(0, r - ch), ring(cz, r), ring(h - cz, r_top), ring(h, r_top - ch)], cap_a=True, cap_b=True))


# --------------------------------------------------------------------------- runas
RUNES = {
    'fe': [((0, -1), (0, 1)), ((0, 0.25), (0.5, 0.8)), ((0, -0.3), (0.5, 0.25))],
    'os': [((0, 1), (0.45, 0.35)), ((0.45, 0.35), (0, -0.3)), ((0, -0.3), (-0.45, 0.35)), ((-0.45, 0.35), (0, 1)),
           ((0, -0.3), (-0.4, -1)), ((0, -0.3), (0.4, -1))],
    'so': [((0.35, 1), (-0.35, 0.3)), ((-0.35, 0.3), (0.35, -0.3)), ((0.35, -0.3), (-0.35, -1))],
    'ti': [((0, -1), (0, 1)), ((0, 1), (-0.45, 0.4)), ((0, 1), (0.45, 0.4))],
    'ha': [((-0.38, -1), (-0.38, 1)), ((0.38, -1), (0.38, 1)), ((-0.38, 0.35), (0.38, -0.35))],
    'al': [((0, -1), (0, 1)), ((0, 0.2), (-0.45, 0.85)), ((0, 0.2), (0.45, 0.85))],
    'in': [((-0.4, 1), (0.4, 0.1)), ((0.4, 0.1), (-0.4, -1)), ((0.4, 1), (-0.4, 0.1)), ((-0.4, 0.1), (0.4, -1))],
    'da': [((-0.42, -0.8), (-0.42, 0.8)), ((0.42, -0.8), (0.42, 0.8)), ((-0.42, 0.8), (0.42, -0.8)),
           ((-0.42, -0.8), (0.42, 0.8))],
    'ey': [((-0.5, 0), (0, 0.5)), ((0, 0.5), (0.5, 0)), ((0.5, 0), (0, -0.5)), ((0, -0.5), (-0.5, 0)),
           ((0, 0.16), (0, -0.16))],
}
RUNE_SEQ = ['fe', 'os', 'so', 'ti', 'ha', 'al', 'in', 'da']


def stroke(a, b, w, col=CY, mat='glow', tip=0.6):
    """Traco losangular no plano XZ (y=0), virado para -Y."""
    a, b = Vector((a[0], 0, a[1])), Vector((b[0], 0, b[1]))
    d = b - a
    ln = d.length
    if ln < 1e-6:
        return lp.Geo()
    d /= ln
    s = Vector((d.z, 0, -d.x)) * (w / 2)
    e = d * min(w * tip, ln * 0.4)
    g = lp.Geo()
    ids = [g.add_vert(p, c=col) for p in (a, a + e - s, b - e - s, b, b - e + s, a + e + s)]
    g.add_face(ids, mat, False)
    if fnormal(g, ids).y > 0:
        g.flip()
    return g


def rune(name, size=0.3, w=None, col=CY, mat='glow'):
    """Runa com altura `size`, centrada na origem, no plano XZ virada para -Y."""
    w = size * 0.16 if w is None else w
    g = lp.Geo()
    k = size / 2
    for a, b in RUNES[name]:
        g.add(stroke((a[0] * k, a[1] * k), (b[0] * k, b[1] * k), w, col, mat))
    return g


def polyline(pts, w, col=CY, mat='glow'):
    g = lp.Geo()
    for a, b in zip(pts, pts[1:]):
        g.add(stroke(a, b, w, col, mat, tip=0.35))
    return g


def lay_flat(g, z=0.0):
    """Deita uma forma do plano XZ (virada para -Y) no chao, virada para +Z."""
    g.rot('X', -90)
    return g.move(0, 0, z)


# --------------------------------------------------------------------------- pintura
def zgrad(g, lo, hi, z0=None, z1=None, power=1.0):
    """Cor base por altura (substitui a cor)."""
    b0, b1 = g.bounds()
    z0 = b0[2] if z0 is None else z0
    z1 = b1[2] if z1 is None else z1
    g.c = [mixc(lo, hi, sm(z0, z1, p.z) ** power) for p in g.v]
    return g


def shade(g, top=ROCK_L, k_top=0.7, under=(0.56, 0.55, 0.78), seed=0, jit=0.07, key=0.13, mats=('vcol', 'vcol_wind')):
    """Tom por faceta: plano virado para cima clareia para `top`, virado para baixo esfria,
    um pouco de luz pintada do lado da KEY e uma variacao pequena de valor/matiz por faceta."""
    rnd = random.Random(seed)
    seen = set()
    for f, m in zip(g.f, g.fm):
        j = 1 + rnd.uniform(-jit, jit)
        hue = rnd.uniform(-1, 1)
        if m not in mats:
            continue
        n = fnormal(g, f)
        up = sm(0.25, 0.9, n.z) * k_top
        dn = sm(0.1, 0.75, -n.z)
        kk = (1 + key * n.dot(KEY)) * j
        for i in f:
            if i in seen:
                continue
            seen.add(i)
            c = g.c[i]
            if top is not None:
                c = mixc(c, top, up)
            c = (c[0] * lerp(1, under[0], dn), c[1] * lerp(1, under[1], dn), c[2] * lerp(1, under[2], dn))
            g.c[i] = (c[0] * kk * (1 + 0.045 * hue), c[1] * kk, c[2] * kk * (1 - 0.035 * hue))
    return g


def gem_shade(g, seed=0, lo=0.45, hi=1.3):
    """Facetas do cristal: como o material emite luz, o volume vem pintado. Facetas viradas
    para a KEY ficam claras, as opostas escuras e mais violetas; uma ou outra faceta bem de
    frente para a luz ganha um reflexo quase branco."""
    rnd = random.Random(seed)
    seen = set()
    for f, m in zip(g.f, g.fm):
        if m != 'glow' or len(f) > 5:
            continue
        n = fnormal(g, f)
        d = n.dot(KEY)
        k = sm(-0.7, 0.8, d + rnd.uniform(-0.3, 0.3))
        v = lerp(lo, hi, k)
        hot = sm(0.72, 0.95, d) * 0.3
        for i in f:
            if i in seen:
                continue
            seen.add(i)
            c = g.c[i]
            c = (c[0] * v * lerp(0.9, 1.0, k), c[1] * v * lerp(0.78, 1.0, k), c[2] * v * lerp(1.08, 1.0, k))
            g.c[i] = mixc(c, (0.75, 0.75, 0.75), hot * min(1.0, (c[0] + c[1] + c[2]) * 1.2))
    return g


def spill(g, srcs, k=0.5):
    """Luz falsa dos cristais na pedra: srcs = [(pos, cor, raio)]. So mexe no que nao e 'glow'."""
    glow = set()
    for f, m in zip(g.f, g.fm):
        if m == 'glow':
            glow.update(f)
    for i, p in enumerate(g.v):
        if i in glow:
            continue
        c = g.c[i]
        for pos, col, rad in srcs:
            d = (p - Vector(pos)).length
            if d < rad:
                w = (1 - d / rad) ** 2 * k
                c = (c[0] + (col[0] - c[0] * 0.6) * w, c[1] + (col[1] - c[1] * 0.6) * w, c[2] + (col[2] - c[2] * 0.6) * w)
        g.c[i] = c
    return g


def rock(g, lo=ROCK_D, hi=ROCK_M, top=ROCK_L, seed=0, z0=None, z1=None, k_top=0.7, power=1.0):
    """Pintura padrao de pedra da gruta."""
    zgrad(g, lo, hi, z0, z1, power)
    return shade(g, top, k_top, seed=seed)


def stone(g, seed=0, lo=STONE_D, hi=STONE, top=STONE_L, z0=None, z1=None, k_top=0.6):
    """Pintura padrao de pedra antiga talhada (palida)."""
    zgrad(g, lo, hi, z0, z1)
    return shade(g, top, k_top, under=(0.62, 0.6, 0.8), seed=seed, jit=0.05)


def finish(g, ao=0.55, dist=0.7, gem=True, seed=3, floor=0.0):
    if gem:
        gem_shade(g, seed)
    return lp.bake_ao(g, ao, dist, samples=28, floor_z=floor)


def glow_centers(parts, col_fn=None):
    """Fontes de `spill` a partir de uma lista de (geo_cristal, raio)."""
    out = []
    for g, rad in parts:
        b0, b1 = g.bounds()
        cen = ((b0[0] + b1[0]) / 2, (b0[1] + b1[1]) / 2, (b0[2] + b1[2]) / 2)
        col = max(g.c, key=lambda c: c[0] + c[1] + c[2])
        out.append((cen, col, rad))
    return out


# =========================================================================== PAREDES
# Parede = fiadas de blocos angulosos (casco convexo), alternando camada grossa recuada e
# prateleira fina saliente. Todas as variantes dividem as mesmas alturas e profundidades de
# camada nas bordas (x = -2 e x = 2), entao emendam lado a lado em qualquer ordem.
WALL_L = [(0.0, 0.8, -0.86, 'thick'), (0.8, 1.12, -1.0, 'shelf'), (1.12, 2.5, -0.62, 'thick'),
          (2.5, 2.84, -0.88, 'shelf'), (2.84, 4.2, -0.56, 'thick'), (4.2, 4.5, -0.8, 'shelf'),
          (4.5, 5.3, -0.5, 'crown')]
WALL_BACK = 0.95


def bump(x, c, w):
    t = (x - c) / w
    return math.exp(-t * t)


def wall_blocks(seed, dz=None, crown=None, breaks=None, skip=(), ydelta=None, dark=None, wob=0.13):
    """dz(x, i): desvio da divisa i (zerado nas bordas); crown(x): altura extra do topo;
    breaks = {camada: [x das juntas]}; skip = {(camada, bloco)}; ydelta = {(camada, bloco): dy};
    dark(p) -> 0..1 escurece (nicho). Juntas inclinadas, divisas onduladas (as prateleiras
    viram cunhas) e topo quebrado: nada de linha reta de ponta a ponta."""
    rnd = random.Random(seed)
    nl = len(WALL_L)
    ydelta = ydelta or {}
    g = lp.Geo()
    wv = [(rnd.uniform(0.6, 1.0) * wob, rnd.uniform(0.9, 1.9), rnd.uniform(0, TAU)) for _ in range(nl + 1)]

    def ek(x):
        return 1 - (abs(x) / 2) ** 4

    def zline(x, i):
        if i == 0:
            return -0.02
        a, f, ph = wv[i]
        return WALL_L[i - 1][1] + ((dz(x, i) if dz else 0.0) + a * math.sin(x * f + ph)) * ek(x)

    prev = []
    for i, (z0, z1, ye, kind) in enumerate(WALL_L):
        if breaks and i in breaks:
            bs = list(breaks[i])
        else:
            n = {'thick': rnd.choice((2, 3)), 'shelf': rnd.choice((2, 3)), 'crown': rnd.choice((2, 3))}[kind]
            for _ in range(60):
                bs = sorted(rnd.uniform(-1.4, 1.4) for _ in range(n))
                xs = [-2.0] + bs + [2.0]
                if min(q - p for p, q in zip(xs, xs[1:])) < 0.7:
                    continue
                if any(abs(q - p) < 0.28 for q in bs for p in prev):
                    continue
                break
        prev = bs
        sl = [rnd.uniform(-0.16, 0.16) * (0.4 if kind == 'shelf' else 1.0) for _ in bs]
        xb = [-2.0] + [b - s for b, s in zip(bs, sl)] + [2.0]     # juntas embaixo
        xt = [-2.0] + [b + s for b, s in zip(bs, sl)] + [2.0]     # juntas em cima
        nb = len(xb) - 1
        for k in range(nb):
            amp = 0.15 if kind == 'shelf' else 0.2
            yb = ye + rnd.uniform(-amp, amp * 0.9) + ydelta.get((i, k), 0.0)
            y0 = ye if k == 0 else yb + rnd.uniform(-0.13, 0.13)
            y1 = ye if k == nb - 1 else yb + rnd.uniform(-0.13, 0.13)
            slope = {'thick': rnd.uniform(-0.08, 0.24), 'shelf': rnd.uniform(-0.03, 0.08), 'crown': rnd.uniform(0.08, 0.3)}[kind]
            bulge = rnd.uniform(0.08, 0.26) if kind != 'shelf' else rnd.uniform(0.04, 0.16)
            ch = rnd.uniform(0.07, 0.17) if kind != 'shelf' else 0.0
            tm = rnd.uniform(0.3, 0.7)
            tm2 = min(0.8, max(0.2, tm + rnd.uniform(-0.18, 0.18)))
            tone = mixc(mul(ROCK_D, 0.82), ROCK_M, rnd.uniform(0.0, 0.6)) if kind != 'shelf' else mixc(ROCK_D, ROCK_M, rnd.uniform(0.5, 1.0))
            r = rnd.random()
            if r < 0.22:
                tone = mixc(tone, ROCK_B, 0.6)
            elif r < 0.4:
                tone = mixc(tone, ROCK_P, 0.5)
            cz = [(crown(x) if crown else 0.0) + rnd.uniform(-0.12, 0.12) for x in (xt[k], (xt[k] + xt[k + 1]) / 2, xt[k + 1])]
            pk = rnd.uniform(0.15, 0.45)
            if (i, k) in skip:
                continue
            pts = []
            cols3 = ((xb[k], xt[k], y0, k == 0), (lerp(xb[k], xb[k + 1], tm), lerp(xt[k], xt[k + 1], tm2), (y0 + y1) / 2 - bulge, False),
                     (xb[k + 1], xt[k + 1], y1, k == nb - 1))
            for ci, (x_b, x_t, y, edge) in enumerate(cols3):
                zb = zline(min(max(x_b, xb[k] + 0.01), xb[k + 1] - 0.01), i) - (0.07 if i else 0.0)
                if kind == 'crown':
                    zt = z1 + (0.0 if edge else cz[ci] * ek(x_t))
                else:
                    zt = zline(min(max(x_t, xt[k] + 0.01), xt[k + 1] - 0.01), i + 1)
                s_ = (0.06 if kind == 'thick' else 0.0) if edge else slope
                pts.append((x_b, y, zb))
                if ch:
                    pts += [(x_t, y + s_, zt - ch), (x_t, y + s_ + ch * 1.3, zt)]
                else:
                    pts.append((x_t, y + s_, zt))
                if ci != 1:
                    pts += [(x_b, WALL_BACK, zb), (x_t, WALL_BACK, zt - (0.35 if kind == 'crown' else 0.0))]
                elif kind == 'crown':
                    pts.append((x_t, y + 0.55, zt + pk * ek(x_t)))
            b = hull(pts, dissolve=2.5)
            zlo, zhi = min(p[2] for p in pts), max(p[2] for p in pts)
            b.c = [mul(mul(tone, lerp(0.62, 1.06, sm(zlo, zhi, p.z))),
                       mixc((0.62, 0.68, 0.96), (1.04, 1.0, 1.0), sm(0.0, 5.8, p.z))) for p in b.v]
            shade(b, ROCK_L, 0.55, seed=seed * 31 + i * 7 + k, jit=0.06)
            g.add(b)
    no_bottom(g, 0.0)
    if dark:
        g.c = [mul(c, mixc((1, 1, 1), (0.26, 0.24, 0.42), dark(p))) for p, c in zip(g.v, g.c)]
    return g


def wall_gems(specs, k=1.0):
    """specs: [(x, y, z, h, r, tilt, yaw, seed, cols)] -> (geo, fontes de spill)."""
    g = lp.Geo()
    srcs = []
    for x, y, z, h, r, tilt, yaw, seed, cols in specs:
        c = crystal(h, r, n=5 if r < 0.14 else 6, seed=seed, cols=cols, tip=0.32)
        place(c, (x, y, z), tilt=tilt, yaw=yaw)
        g.add(c)
        tipp = max(c.v, key=lambda p: (p - Vector((x, y, z))).length)
        srcs.append(((x * 0.5 + tipp.x * 0.5, y * 0.5 + tipp.y * 0.5, z * 0.5 + tipp.z * 0.5), mul(cols[-1], 1.6),
                     (0.45 + h * 0.75) * k))
    return g, srcs


def monolith(seed, w, d, h, lean=(0.0, 0.0), top=0.55, tilt=0.22, n=5, tone=(ROCK_D, ROCK_M)):
    """Laje/coluna de pedra em pe, de topo cortado torto."""
    b = mesa(seed, w, d, h, n=n, top=top, tilt=tilt, off=lean, belt=0.0)
    return rock(b, tone[0], tone[1], seed=seed, z0=0, z1=h, k_top=0.55)


def wall_finish(g, srcs, k=0.34):
    spill(g, srcs, k)
    return finish(g, ao=0.68, dist=0.9)


@kit.prop('cave_wall_a', collider=('box', 4.0, 1.9, 5.6), tags=['wall'])
def cave_wall_a():
    """Estratos arqueados, laje alta a esquerda e um cacho ciano na prateleira de baixo."""
    g = wall_blocks(11, dz=lambda x, i: 0.26 * bump(x, -0.3, 1.2) * (1 - i * 0.06),
                    crown=lambda x: 0.7 * bump(x, -0.7, 0.8) - 0.25 * bump(x, 1.0, 0.5))
    g.add(place(monolith(4, 1.1, 0.8, 3.3, lean=(0.25, 0.3), top=0.5), (-1.3, -0.95, 0), yaw=15))
    g.add(place(monolith(5, 0.8, 0.7, 1.9, lean=(-0.2, 0.2), top=0.55), (-0.55, -1.02, 0), yaw=-20))
    g.add(place(rock(mesa(9, 0.9, 0.7, 0.5, top=0.6), seed=4, z0=0, z1=1.2), (1.3, -1.1, 0), yaw=50))
    gems, srcs = wall_gems([
        (0.7, -0.8, 1.05, 1.5, 0.24, 30, -14, 1, GEM_CV),
        (1.1, -0.82, 1.05, 0.95, 0.18, 46, -62, 2, GEM_CV),
        (0.35, -0.85, 1.05, 0.8, 0.16, 50, 40, 3, GEM_CP),
        (0.82, -0.98, 1.05, 0.5, 0.12, 66, -5, 6, GEM_CV),
        (-0.5, -0.5, 4.3, 0.8, 0.16, 58, 24, 4, GEM_CV),
        (-0.85, -0.5, 4.3, 0.45, 0.11, 74, 52, 5, GEM_CP),
    ])
    g.add(gems)
    return wall_finish(g, srcs)


@kit.prop('cave_wall_b', collider=('box', 4.0, 1.9, 6.3), tags=['wall'])
def cave_wall_b():
    """Contraforte alto a direita (tres lajes em escada) e veio rosa ao pe, a esquerda."""
    g = wall_blocks(27, dz=lambda x, i: -0.22 * bump(x, 0.5, 1.1) * (0.5 + 0.1 * i),
                    crown=lambda x: 0.5 * bump(x, 0.9, 0.7) - 0.3 * bump(x, -0.8, 0.6))
    g.add(place(monolith(14, 1.25, 0.95, 6.3, lean=(0.12, 0.35), top=0.42, tilt=0.12), (1.15, -0.72, 0), yaw=10))
    g.add(place(monolith(15, 0.95, 0.8, 4.2, lean=(-0.1, 0.25), top=0.5, tilt=0.2), (0.35, -0.9, 0), yaw=-25))
    g.add(place(monolith(16, 0.8, 0.7, 2.2, lean=(0.2, 0.2), top=0.55, tilt=0.3), (1.5, -1.05, 0), yaw=40))
    g.add(place(rock(mesa(31, 1.0, 0.8, 0.6, top=0.6), seed=9, z0=0, z1=1.2), (-1.4, -1.08, 0), yaw=35))
    gems, srcs = wall_gems([
        (-0.75, -0.9, 0.5, 1.35, 0.23, 34, 16, 11, GEM_VP),
        (-0.4, -0.95, 0.4, 0.8, 0.16, 52, -30, 12, GEM_VP),
        (-1.05, -0.92, 0.5, 0.7, 0.14, 50, 58, 13, GEM_CV),
        (-0.7, -1.05, 0.3, 0.45, 0.11, 70, 5, 16, GEM_VP),
        (-1.0, -0.55, 2.82, 0.8, 0.16, 50, 30, 14, GEM_CV),
        (-1.3, -0.55, 2.82, 0.42, 0.1, 66, 60, 15, GEM_VP),
    ])
    g.add(gems)
    return wall_finish(g, srcs)


@kit.prop('cave_wall_c', collider=('box', 4.0, 1.9, 5.6), tags=['wall'])
def cave_wall_c():
    """Nicho escuro no meio, com um brilho pequeno la dentro."""
    def dark(p):
        return sm(-0.5, 0.1, p.y) * sm(0.95, 0.7, abs(p.x - 0.05)) * sm(2.85, 2.5, p.z) * sm(0.9, 1.1, p.z)

    g = wall_blocks(41, dz=lambda x, i: 0.1 * bump(x, 1.0, 0.9), crown=lambda x: 0.4 * bump(x, 1.0, 0.7) + 0.2 * bump(x, -1.1, 0.5),
                    breaks={1: [-0.9], 2: [-0.62, 0.72], 3: [1.0]}, ydelta={(2, 1): 1.05, (1, 1): 0.02, (3, 0): -0.02}, dark=dark)
    g.add(place(monolith(17, 1.0, 0.8, 2.9, lean=(-0.2, 0.3), top=0.5), (1.4, -0.95, 0), yaw=-10))
    g.add(place(rock(mesa(52, 0.8, 0.7, 0.5, top=0.6), seed=7, z0=0, z1=1.2), (-1.45, -1.12, 0), yaw=25))
    g.add(place(rock(mesa(53, 0.6, 0.5, 0.85, top=0.5), seed=8, z0=0, z1=1.2), (-0.9, -1.1, 0), yaw=65))
    gems, srcs = wall_gems([
        (0.12, 0.2, 1.08, 0.62, 0.12, 14, 10, 21, GEM_CV),
        (-0.14, 0.24, 1.08, 0.36, 0.09, 34, 60, 22, GEM_CP),
        (0.34, 0.16, 1.08, 0.3, 0.08, 40, -50, 23, GEM_VP),
        (-1.2, -0.5, 4.3, 0.75, 0.15, 56, 30, 24, GEM_VP),
        (-0.9, -0.52, 4.3, 0.4, 0.1, 72, -10, 26, GEM_VP),
        (1.25, -0.55, 4.3, 0.5, 0.12, 64, -28, 25, GEM_CV),
    ])
    g.add(gems)
    return wall_finish(g, srcs, k=0.42)


@kit.prop('cave_wall_d', collider=('box', 4.0, 1.9, 6.1), tags=['wall'])
def cave_wall_d():
    """Falha vertical: o lado esquerdo desceu, e um veio de cristais sobe pela fenda."""
    fx = 0.35

    def dz(x, i):
        return -0.3 * (x + 2) / (fx + 2) if x < fx else 0.26 * (2 - x) / (2 - fx)

    br = {i: [fx] for i in range(7)}
    br[0] = [-0.9, fx]
    br[2] = [-0.8, fx, 1.2]
    br[4] = [-1.1, fx]
    br[6] = [-0.7, fx, 1.25]
    g = wall_blocks(63, dz=dz, crown=lambda x: 0.8 * bump(x, 1.0, 0.6) + 0.25 * bump(x, -1.2, 0.4), breaks=br)
    g.add(place(monolith(71, 1.0, 0.8, 2.4, lean=(0.2, 0.3), top=0.5), (-1.45, -0.98, 0), yaw=10))
    g.add(place(rock(mesa(72, 1.1, 0.8, 0.65, top=0.6), seed=2, z0=0, z1=1.2), (1.35, -1.05, 0), yaw=-30))
    g.add(place(rock(mesa(73, 0.6, 0.5, 0.4, top=0.6), seed=3, z0=0, z1=1.2), (0.75, -1.2, 0), yaw=20))
    specs = []
    for k, (z, h, r, tl, yw, cols) in enumerate(((0.55, 0.6, 0.13, 62, -35, GEM_CV), (1.3, 1.1, 0.2, 48, 28, GEM_CV),
                                               (2.2, 0.7, 0.15, 64, -34, GEM_VP), (3.0, 1.3, 0.22, 52, 20, GEM_CV),
                                               (3.9, 0.6, 0.13, 70, -40, GEM_CP), (4.6, 0.85, 0.16, 58, 32, GEM_VP))):
        specs.append((fx + (0.09 if k % 2 else -0.09), -0.5 if z > 2.6 else -0.62, z, h, r, tl, yw, 40 + k, cols))
    gems, srcs = wall_gems(specs)
    g.add(gems)
    return wall_finish(g, srcs)


# =========================================================================== CRISTAIS
def cluster(specs, base, k=0.4):
    """specs: [(x, y, z, h, r, tilt, yaw, seed, cols, {extras})] sobre uma base de pedra.
    Os cristais nascem juntos de uma raiz e abrem em leque (tilt para fora, yaw = direcao)."""
    g = base
    srcs = []
    for sp in specs:
        x, y, z, h, r, tilt, yaw, seed, cols = sp[:9]
        kw = sp[9] if len(sp) > 9 else {}
        c = crystal(h, r, seed=seed, cols=cols, **kw)
        place(c, (x, y, z), tilt=tilt, yaw=yaw)
        g.add(c)
        srcs.append(((x, y, z + 0.1), mul(cols[-1], 1.6), 0.3 + h * 0.3))
    spill(g, srcs, k)
    return g


@kit.prop('crystal_big_a', collider=('cyl', 0.75, 2.6), tags=['crystal_big'],
          light=dict(color='#8fe9ff', energy=2.4, height=1.6, range=7.5))
def crystal_big_a():
    """Um cristal dominante inclinado, com a familia pequena aberta do lado oposto."""
    base = rock(mesa(3, 1.7, 1.4, 0.62, n=6, top=0.62, tilt=0.35, belt=0.1), seed=1, z0=0, z1=0.8)
    base.add(place(rock(mesa(8, 0.85, 0.7, 0.4, top=0.6, tilt=0.4), seed=2, z0=0, z1=0.8), (0.78, -0.42, 0), yaw=30))
    base.add(place(rock(mesa(9, 0.5, 0.42, 0.75, n=4, top=0.45, tilt=0.5, off=(-0.3, 0)), seed=5, z0=0, z1=0.8), (-0.82, 0.1, 0), yaw=10))
    g = cluster([
        (-0.02, 0.05, 0.25, 2.5, 0.33, 8, 205, 1, GEM_CV),
        (0.2, 0.0, 0.3, 1.5, 0.24, 30, 110, 2, GEM_CV, dict(cut=True)),
        (-0.25, -0.1, 0.3, 1.05, 0.2, 36, -62, 3, GEM_CP),
        (0.05, -0.28, 0.3, 0.75, 0.16, 46, 10, 4, GEM_CV),
        (-0.1, 0.3, 0.3, 0.9, 0.17, 38, 190, 5, GEM_VP),
        (0.85, -0.45, 0.2, 0.55, 0.12, 30, 60, 6, GEM_CV),
        (0.68, -0.6, 0.15, 0.36, 0.09, 52, -20, 7, GEM_CP),
    ], base)
    return finish(g, 0.6, 0.7)


@kit.prop('crystal_big_b', collider=('cyl', 0.85, 1.9), tags=['crystal_big'],
          light=dict(color='#ff9fe0', energy=2.0, height=1.2, range=6.5))
def crystal_big_b():
    """Leque largo rosa/violeta, mais baixo e aberto, numa laje rachada."""
    base = rock(mesa(13, 1.9, 1.3, 0.5, n=6, top=0.7, tilt=0.3, belt=0.08), seed=4, z0=0, z1=0.7)
    base.add(place(rock(mesa(14, 0.7, 0.6, 0.55, n=5, top=0.5, tilt=0.5), seed=6, z0=0, z1=0.7), (-0.8, 0.25, 0), yaw=70))
    g = cluster([
        (0.05, 0.08, 0.25, 1.75, 0.3, 12, 160, 11, GEM_VP, dict(cut=True)),
        (-0.18, 0.0, 0.25, 1.5, 0.25, 40, -100, 12, GEM_VP),
        (0.25, -0.02, 0.25, 1.3, 0.22, 44, 92, 13, GEM_VP),
        (0.0, -0.22, 0.25, 0.85, 0.17, 44, 6, 14, GEM_CV),
        (-0.3, -0.2, 0.22, 0.7, 0.14, 62, -48, 15, GEM_VP),
        (0.38, -0.22, 0.22, 0.65, 0.14, 60, 50, 16, GEM_CV),
        (0.12, 0.3, 0.25, 0.95, 0.16, 34, 195, 17, GEM_VP),
    ], base)
    return finish(g, 0.6, 0.7)


@kit.prop('crystal_big_c', collider=('cyl', 0.7, 2.9), tags=['crystal_big'],
          light=dict(color='#a9b4ff', energy=2.6, height=1.8, range=8.0))
def crystal_big_c():
    """Dois obeliscos gemeos tortos brotando de uma pedra alta rachada."""
    base = rock(mesa(21, 1.4, 1.2, 0.95, n=5, top=0.58, tilt=0.35, off=(0.15, 0.0), belt=0.1), seed=6, z0=0, z1=1.0)
    base.add(place(rock(mesa(22, 0.9, 0.75, 0.42, top=0.6, tilt=0.4), seed=7, z0=0, z1=1.0), (-0.72, -0.3, 0), yaw=40))
    g = cluster([
        (0.14, 0.08, 0.5, 2.45, 0.29, 5, 80, 21, GEM_CP, dict(tip=0.24)),
        (-0.08, 0.0, 0.5, 1.75, 0.25, 17, -84, 22, GEM_CV, dict(cut=True)),
        (0.3, -0.2, 0.45, 0.9, 0.17, 42, 55, 23, GEM_CV),
        (0.05, -0.3, 0.45, 0.6, 0.13, 55, -5, 25, GEM_CP),
        (0.1, 0.32, 0.45, 0.8, 0.15, 40, 170, 26, GEM_CV),
        (-0.72, -0.35, 0.2, 0.7, 0.14, 26, -50, 24, GEM_VP),
        (-0.55, -0.5, 0.15, 0.4, 0.1, 50, 20, 27, GEM_VP),
    ], base)
    return finish(g, 0.6, 0.7)


def small_cluster(seed, specs, pebbles=2):
    g = lp.Geo()
    rnd = random.Random(seed)
    for i, (x, y, h, r, tilt, yaw, cols) in enumerate(specs):
        g.add(place(shard(h, r, seed * 10 + i, cols), (x, y, -0.02), tilt=tilt, yaw=yaw))
    for i in range(pebbles):
        a = rnd.uniform(0, TAU)
        p = rock(chunk(seed * 7 + i, 0.2, 0.16, 0.1, n=4, top=0.6, peak=0), seed=i, z0=0, z1=0.15)
        g.add(place(no_bottom(p), (math.cos(a) * 0.16, math.sin(a) * 0.14, 0), yaw=rnd.uniform(0, 360)))
    spill(g, [((0, 0, 0.1), specs[0][6][2], 0.4)], 0.6)
    return finish(g, 0.5, 0.3)


@kit.prop('crystal_small_a', tags=['crystal_small'])
def crystal_small_a():
    return small_cluster(1, [(0.0, 0.0, 0.48, 0.07, 8, 0, GEM_CV), (0.09, -0.05, 0.3, 0.055, 30, 110, GEM_CV),
                             (-0.09, -0.03, 0.24, 0.05, 34, -80, GEM_CP), (0.02, 0.1, 0.2, 0.045, 40, 190, GEM_CV)])


@kit.prop('crystal_small_b', tags=['crystal_small'])
def crystal_small_b():
    return small_cluster(2, [(-0.04, 0.0, 0.34, 0.065, 22, -60, GEM_VP), (0.08, 0.02, 0.4, 0.06, 16, 80, GEM_VP),
                             (0.0, -0.1, 0.2, 0.05, 44, 0, GEM_CV)])


@kit.prop('crystal_small_c', tags=['crystal_small'])
def crystal_small_c():
    return small_cluster(3, [(0.0, 0.02, 0.26, 0.06, 12, 40, GEM_CP), (0.12, -0.04, 0.2, 0.05, 40, 100, GEM_CV),
                             (-0.12, 0.0, 0.32, 0.055, 28, -95, GEM_CV), (-0.02, -0.12, 0.16, 0.045, 50, -10, GEM_VP),
                             (0.05, 0.13, 0.22, 0.045, 36, 170, GEM_CP)], pebbles=1)


# =========================================================================== PEDRAS
def stalagmite(h, r, seed, lean=(0.0, 0.0), n=6, lo=ROCK_D, hi=ROCK_M, prof=None):
    g = spike(h, r, n=n, seed=seed, lean=lean, prof=prof)
    zgrad(g, mul(lo, 0.85), hi, 0, h)
    g.c = [mixc(c, mul(ROCK_L, 1.08), sm(0.62 * h, h, p.z) * 0.7) for p, c in zip(g.v, g.c)]   # ponta molhada, clara
    return shade(g, ROCK_L, 0.6, seed=seed)


@kit.prop('rock_a', collider=('cyl', 0.6, 2.3), tags=['rock'])
def rock_a():
    """Estalagmite alta e torta com duas filhas."""
    g = no_bottom(rock(mesa(5, 1.5, 1.25, 0.32, n=6, top=0.7, tilt=0.4), seed=1, z0=0, z1=0.5, k_top=0.5))
    g.add(place(stalagmite(2.45, 0.42, 3, lean=(0.22, -0.1)), (0.05, 0.08, 0.0)))
    g.add(place(stalagmite(1.15, 0.26, 4, lean=(-0.12, -0.05), n=5), (-0.5, -0.22, 0.0)))
    g.add(place(stalagmite(0.6, 0.17, 6, lean=(0.05, -0.05), n=5), (0.42, -0.4, 0.0)))
    return finish(g, 0.6, 0.6)


@kit.prop('rock_b', collider=('box', 2.3, 1.1, 1.5), tags=['rock'])
def rock_b():
    """Fileira de estalagmites em escada, meio muro baixo."""
    g = no_bottom(rock(mesa(15, 2.4, 1.0, 0.3, n=6, top=0.75, tilt=0.4), seed=2, z0=0, z1=0.5, k_top=0.5))
    for i, (x, y, h, r, ln, sd) in enumerate(((-0.75, 0.05, 1.9, 0.36, (-0.12, 0.05), 11), (-0.1, -0.08, 1.25, 0.3, (0.1, -0.06), 12),
                                              (0.5, 0.1, 1.6, 0.3, (0.16, 0.0), 13), (0.95, -0.15, 0.7, 0.2, (0.05, -0.05), 14),
                                              (-0.4, -0.3, 0.5, 0.16, (-0.03, -0.05), 15))):
        g.add(place(stalagmite(h, r, sd, lean=ln, n=6 if r > 0.25 else 5), (x, y, 0.0)))
    return finish(g, 0.6, 0.6)


@kit.prop('rock_c', collider=('cyl', 0.95, 1.3), tags=['rock'])
def rock_c():
    """Rochedo de tres lajes empilhadas, com um veio de cristal na rachadura."""
    g = rock(mesa(31, 2.0, 1.6, 0.85, n=6, top=0.72, tilt=0.25, belt=0.1), seed=1, z0=0, z1=1.5)
    g.add(place(rock(mesa(32, 1.35, 1.1, 0.8, n=5, top=0.6, tilt=0.4, off=(0.2, 0.1)), seed=2, z0=-0.6, z1=0.9, lo=ROCK_D, hi=ROCK_L, k_top=0.6),
                (-0.18, 0.12, 0.62), yaw=25))
    g.add(place(rock(mesa(33, 0.8, 0.7, 0.55, n=5, top=0.55, tilt=0.5), seed=3, z0=0, z1=1.2), (0.85, -0.5, 0.0), yaw=-20))
    gems = lp.Geo()
    for x, y, z, h, r, tl, yw, sd in ((0.52, -0.42, 0.62, 0.55, 0.11, 48, 40, 61), (0.36, -0.55, 0.6, 0.34, 0.08, 64, -8, 62),
                                      (0.66, -0.3, 0.62, 0.28, 0.07, 58, 80, 63)):
        gems.add(place(crystal(h, r, n=5, seed=sd, cols=GEM_CV), (x, y, z), tilt=tl, yaw=yw))
    g.add(gems)
    spill(g, [((0.5, -0.5, 0.75), mul(CY, 0.9), 0.75)], 0.4)
    return finish(no_bottom(g), 0.62, 0.7)


def pebbles(seed, specs):
    g = lp.Geo()
    for i, (x, y, w, d, h, yaw) in enumerate(specs):
        p = rock(mesa(seed * 13 + i, w, d, h, n=4 if w < 0.2 else 5, top=0.62, tilt=0.45, sink=0.01), seed=seed + i, z0=0, z1=0.3,
                 lo=ROCK_D, hi=mixc(ROCK_M, ROCK_L, 0.3), k_top=0.5)
        g.add(place(no_bottom(p), (x, y, 0), yaw=yaw))
    return finish(g, 0.5, 0.25)


@kit.prop('pebble_a', tags=['pebble'])
def pebble_a():
    return pebbles(1, [(0.0, 0.02, 0.3, 0.22, 0.16, 20), (0.2, -0.1, 0.16, 0.13, 0.09, 70), (-0.2, -0.08, 0.13, 0.1, 0.07, 130),
                       (0.1, 0.2, 0.1, 0.09, 0.05, 10)])


@kit.prop('pebble_b', tags=['pebble'])
def pebble_b():
    return pebbles(2, [(-0.08, 0.0, 0.24, 0.17, 0.11, -30), (0.14, 0.06, 0.2, 0.16, 0.2, 55), (0.02, -0.19, 0.12, 0.1, 0.06, 100)])


# =========================================================================== PILARES
@kit.prop('pillar_a', collider=('cyl', 0.62, 4.7), tags=['pillar'])
def pillar_a():
    """Coluna natural: estalagmite e estalactite que se encontraram, cintura fina e torta."""
    h = 4.7
    g = spike(h, 0.6, n=7, seed=8, prof=COLUMN, lean=(0.0, 0.0), twist=0.5, apex=False)
    g.warp(lambda p: Vector((p.x + 0.16 * math.sin(p.z / h * math.pi), p.y - 0.1 * math.sin(p.z / h * math.pi), p.z)))
    zgrad(g, mul(ROCK_D, 0.8), ROCK_M, 0, h)
    g.c = [mul(c, lerp(1.0, 0.78, sm(3.6, 4.7, p.z))) for p, c in zip(g.v, g.c)]
    shade(g, ROCK_L, 0.6, seed=4)
    g.add(place(stalagmite(1.2, 0.26, 21, lean=(-0.1, -0.05), n=5), (-0.72, -0.3, 0.0)))
    g.add(place(stalagmite(0.65, 0.18, 22, lean=(0.04, -0.04), n=5), (0.66, -0.42, 0.0)))
    gems = lp.Geo()
    for x, y, z, hh, r, tl, yw, sd, cols in ((0.28, -0.22, 2.25, 0.75, 0.14, 62, 35, 71, GEM_VP), (0.14, -0.3, 2.1, 0.45, 0.1, 80, -5, 72, GEM_VP),
                                             (0.36, -0.1, 2.45, 0.4, 0.09, 50, 70, 73, GEM_CV)):
        gems.add(place(crystal(hh, r, n=5, seed=sd, cols=cols), (x, y, z), tilt=tl, yaw=yw))
    g.add(gems)
    spill(g, [((0.35, -0.4, 2.35), mul(PK, 0.9), 1.0)], 0.4)
    return finish(g, 0.6, 0.8)


def rune_band(r, z, n, size=0.3, start=0, col=CY, seq=RUNE_SEQ, arc=TAU):
    """Runas em volta de um cilindro de raio r (virada para fora), a partir da frente (-Y)."""
    g = lp.Geo()
    for i in range(n):
        a = arc * (i - (n - 1) / 2) / n
        g.add(place(rune(seq[(start + i) % len(seq)], size, col=col), (math.sin(a) * r, -math.cos(a) * r, z), yaw=math.degrees(a)))
    return g


@kit.prop('pillar_b', collider=('cyl', 0.65, 4.3), tags=['pillar'])
def pillar_b():
    """Pilar talhado em ruina: tambores desalinhados, faixa de runas, topo quebrado com cristal."""
    g = stone(cblock(1.35, 1.35, 0.34, 0.07), seed=1, z0=0, z1=1.2)
    g.add(place(stone(cblock(1.08, 1.08, 0.24, 0.06), seed=2, z0=-0.3, z1=0.9), (0.02, 0.0, 0.34), yaw=6))
    z = 0.58
    specs = [(0.5, 0.26, 10, 0.0, 0, 0, 0), (0.43, 1.02, 10, 0.12, 0.03, -0.02, 8), (0.42, 0.36, 12, 0.0, -0.02, 0.02, 0),
             (0.41, 1.0, 10, 0.12, 0.05, 0.03, -14), (0.4, 0.85, 10, 0.12, -0.06, -0.03, 22)]
    for i, (r, hh, n, fl, dx, dy, yaw) in enumerate(specs):
        d = drum(r, hh, n=n, ch=0.035, flute=fl)
        if i == len(specs) - 1:   # topo quebrado em diagonal
            d.warp(lambda p: Vector((p.x, p.y, min(p.z, 0.35 + 0.55 * sm(-0.4, 0.4, p.x * 0.8 + p.y * 0.6)))) if p.z > 0.1 else p)
        stone(d, seed=10 + i, z0=-z, z1=4.6 - z)
        g.add(place(d, (dx, dy, z), yaw=yaw))
        if i == 2:
            g.add(rune_band(r + 0.012, z + hh / 2, 7, size=0.24, arc=TAU))
        z += hh
    gems = lp.Geo()
    for x, y, zz, hh, r, tl, yw, sd, cols in ((-0.1, -0.02, 3.7, 1.0, 0.17, 16, -60, 81, GEM_VP), (0.1, -0.1, 3.75, 0.6, 0.12, 40, 40, 82, GEM_VP),
                                              (-0.22, -0.2, 3.6, 0.45, 0.1, 52, -20, 83, GEM_CV), (0.45, -0.4, 0.5, 0.5, 0.11, 30, 30, 84, GEM_VP)):
        gems.add(place(crystal(hh, r, n=5, seed=sd, cols=cols), (x, y, zz), tilt=tl, yaw=yw))
    g.add(gems)
    frag = stone(mesa(41, 0.6, 0.5, 0.36, n=5, top=0.7, tilt=0.5), seed=5, z0=0, z1=0.8)
    g.add(place(frag, (-0.72, -0.62, 0.0), yaw=30))
    spill(g, [((0.0, -0.2, 4.0), mul(PK, 0.9), 1.0), ((0.5, -0.5, 0.7), mul(PK, 0.8), 0.6)], 0.35)
    spill(g, [((0, 0, 1.9 + 0.2), mul(CY, 0.5), 0.75)], 0.22)
    return finish(no_bottom(g), 0.6, 0.6)


# =========================================================================== TETO
def hanging(g):
    """Vira de ponta-cabeca (modelado em pe, raiz em z=0) e pinta por faceta."""
    g.scale(1, 1, -1)
    return g


def stalactite(h, r, seed, lean=(0.0, 0.0), n=6):
    prof = [(0.0, 1.5), (0.05, 1.05), (0.26, 0.74), (0.29, 0.6), (0.56, 0.4), (0.59, 0.3), (0.84, 0.13)]
    g = spike(h, r, n=n, seed=seed, lean=lean, prof=prof)
    zgrad(g, mul(ROCK_D, 0.62), ROCK_M, 0, h)
    g.c = [mixc(c, mul(ROCK_L, 1.1), sm(0.6 * h, h, p.z) * 0.75) for p, c in zip(g.v, g.c)]
    return g


def ceiling_group(seed, specs, root):
    """specs: [(x, y, h, r, lean)]; root = (w, d, h) da laje de teto de onde tudo pende."""
    g = mesa(seed, root[0], root[1], root[2], n=7, top=0.62, tilt=0.3, sink=0.0)
    zgrad(g, mul(ROCK_D, 0.6), ROCK_D, 0, root[2])
    for i, (x, y, h, r, ln) in enumerate(specs):
        g.add(place(stalactite(h, r, seed * 9 + i, lean=ln, n=6 if r > 0.2 else 5), (x, y, 0.0)))
    hanging(g)
    shade(g, ROCK_L, 0.3, under=(0.9, 0.9, 1.0), seed=seed, key=0.16)
    return g


@kit.prop('stalactite_a', tags=['ceiling'], drop=2.7)
def stalactite_a():
    """Grupo com uma estalactite longa e quatro menores."""
    g = ceiling_group(1, [(0.0, 0.0, 2.7, 0.36, (0.12, -0.08)), (0.55, 0.2, 1.5, 0.27, (0.06, 0.04)), (-0.5, -0.15, 1.1, 0.24, (-0.08, 0.0)),
                          (0.2, -0.55, 0.75, 0.18, (0.0, -0.05)), (-0.3, 0.5, 0.55, 0.16, (0.0, 0.03))], (2.0, 1.8, 0.28))
    return finish(g, 0.55, 0.6)


@kit.prop('stalactite_b', tags=['ceiling'], drop=1.9)
def stalactite_b():
    """Cortina: fileira torta de estalactites de alturas diferentes."""
    g = ceiling_group(2, [(-1.1, 0.1, 0.9, 0.24, (-0.05, 0.0)), (-0.6, -0.08, 1.9, 0.3, (0.08, -0.04)), (-0.05, 0.08, 1.3, 0.27, (-0.05, 0.03)),
                          (0.5, -0.05, 1.65, 0.28, (0.1, 0.0)), (1.0, 0.12, 0.7, 0.2, (0.04, 0.0)), (0.25, -0.35, 0.5, 0.15, (0.0, -0.03))],
                      (3.0, 1.1, 0.25))
    return finish(g, 0.55, 0.6)


@kit.prop('stalactite_c', tags=['ceiling'], drop=2.6, light=dict(color='#8fe9ff', energy=1.6, height=-2.1, range=6.0))
def stalactite_c():
    """Estalactite grossa com um cristal de lumen na ponta."""
    g = ceiling_group(3, [(0.0, 0.0, 1.75, 0.42, (0.05, 0.03)), (0.6, -0.2, 0.95, 0.24, (0.06, -0.03)), (-0.5, 0.3, 1.25, 0.26, (-0.08, 0.02)),
                          (-0.25, -0.5, 0.6, 0.17, (0.0, -0.03))], (1.9, 1.7, 0.28))
    gems = lp.Geo()
    for x, y, z, hh, r, tl, yw, sd, cols in ((0.05, 0.03, 1.45, 1.15, 0.2, 4, 0, 91, GEM_CV), (0.1, -0.02, 1.4, 0.6, 0.12, 24, 80, 92, GEM_CP),
                                             (0.0, 0.08, 1.4, 0.5, 0.1, 26, 220, 93, GEM_CV), (0.62, -0.2, 0.8, 0.4, 0.08, 6, 0, 94, GEM_VP)):
        gems.add(place(crystal(hh, r, n=5, seed=sd, cols=cols), (x, y, z), tilt=tl, yaw=yw))
    g.add(hanging(gems))
    spill(g, [((0.05, 0.03, -1.6), mul(CY, 0.9), 1.1)], 0.45)
    return finish(g, 0.55, 0.6)


# =========================================================================== COGUMELOS
SHROOM = ((0.03, 0.10, 0.16), (0.04, 0.30, 0.27), (TEAL[0] * 0.5, TEAL[1] * 0.5, TEAL[2] * 0.5))   # centro -> meio -> borda


def mushroom(h, r, seed=0, lean=(0.1, 0.0), n=7, tilt=14, flat=0.55, droop=0.14):
    """Cogumelo bioluminescente: pe palido torto + chapeu 'glow' (centro escuro, borda e lamelas acesas)."""
    lx, ly = lean
    path = [(0, 0, -0.02), (lx * 0.2, ly * 0.2, h * 0.4), (lx * 0.72, ly * 0.72, h * 0.78), (lx, ly, h)]
    stem = lp.tube(path, [r * 0.26, r * 0.17, r * 0.13, r * 0.12], n=5, cap_a=False, cap_b=False)
    zgrad(stem, hexc('#5b5290'), hexc('#bfeee0'), 0, h, power=1.4)
    prof = [(0.12, 0.03), (0.9, -droop), (1.0, -droop * 0.3), (0.86, flat * 0.45), (0.5, flat * 0.85), (0.0, flat)]
    cap = lp.lathe([(a * r, b * r) for a, b in prof], n=n, mat='glow', phase=seed * 0.37)
    cols = [mul(TEAL, 0.62), mul(hexc('#b8ffe9'), 0.55), SHROOM[2], SHROOM[1], mixc(SHROOM[0], SHROOM[1], 0.4), SHROOM[0]]
    i = 0
    for k, (a, b) in enumerate(prof):
        cnt = 1 if a <= 1e-6 else n
        for _ in range(cnt):
            cap.c[i] = cols[k]
            i += 1
    cap.scale(1.0, 0.88, 1.0)
    ang = math.degrees(math.atan2(lx, -ly)) if (lx or ly) else 0.0
    place(cap, (lx, ly, h - 0.02 * r), tilt=tilt, yaw=ang)
    return lp.merge(stem, cap)


@kit.prop('mushroom_a', tags=['mushroom'], light=dict(color='#5ff5c8', energy=1.1, height=0.6, range=4.0))
def mushroom_a():
    """Tres cogumelos altos inclinados para lados diferentes, mais dois botoes."""
    g = lp.Geo()
    g.add(place(mushroom(0.92, 0.3, 1, lean=(0.16, -0.12), n=8), (0.0, 0.05, 0)))
    g.add(place(mushroom(0.58, 0.22, 2, lean=(-0.15, -0.1), n=7, tilt=20), (-0.16, -0.1, 0)))
    g.add(place(mushroom(0.36, 0.16, 3, lean=(0.1, -0.1), n=6, tilt=24), (0.2, -0.2, 0)))
    g.add(place(mushroom(0.15, 0.085, 4, lean=(0.0, -0.02), n=5, flat=0.8, tilt=8), (-0.3, -0.28, 0)))
    g.add(place(mushroom(0.11, 0.07, 5, lean=(0.02, 0.0), n=5, flat=0.8, tilt=8), (0.34, 0.12, 0)))
    g.add(place(no_bottom(rock(mesa(7, 0.34, 0.28, 0.14, n=5, top=0.6, tilt=0.4), seed=3, z0=0, z1=0.2)), (-0.02, 0.2, 0), yaw=20))
    spill(g, [((0, -0.05, 0.05), mul(TEAL, 0.8), 0.45)], 0.5)
    return finish(g, 0.5, 0.35, gem=False)


@kit.prop('mushroom_b', tags=['mushroom'], light=dict(color='#5ff5c8', energy=0.9, height=0.35, range=3.5))
def mushroom_b():
    """Tufo baixo e largo sobre uma pedra: chapeus chatos em degraus."""
    g = no_bottom(rock(mesa(27, 0.75, 0.6, 0.26, n=6, top=0.7, tilt=0.35, belt=0.06), seed=5, z0=0, z1=0.4, k_top=0.5))
    for x, y, z, h, r, ln, tl, sd, n, fl in ((-0.1, 0.05, 0.2, 0.42, 0.27, (-0.08, -0.08), 18, 11, 8, 0.36), (0.2, -0.05, 0.16, 0.3, 0.2, (0.1, -0.08), 22, 12, 7, 0.4),
                                            (0.0, -0.22, 0.1, 0.22, 0.15, (0.0, -0.1), 28, 13, 6, 0.42), (-0.38, -0.2, 0.0, 0.2, 0.11, (-0.05, -0.04), 16, 14, 6, 0.6),
                                            (0.42, 0.14, 0.0, 0.26, 0.12, (0.06, 0.02), 18, 15, 6, 0.55), (0.34, -0.3, 0.0, 0.1, 0.065, (0.0, -0.02), 8, 16, 5, 0.8)):
        g.add(place(mushroom(h, r, sd, lean=ln, n=n, tilt=tl, flat=fl), (x, y, z)))
    spill(g, [((0, -0.05, 0.25), mul(TEAL, 0.8), 0.5)], 0.5)
    return finish(g, 0.5, 0.35, gem=False)


# =========================================================================== LAJOTAS
def tile_paint(g, lo, hi, edge, seed, r):
    """Tampo mais escuro no meio, borda gasta clara; lateral escura."""
    g.c = [mixc(mixc(lo, hi, sm(0.0, r, math.hypot(p.x, p.y))), edge, sm(r * 0.75, r * 1.02, math.hypot(p.x, p.y)) * 0.55)
           if p.z > 0.02 else mul(lo, 0.6) for p in g.v]
    return shade(g, None, 0.0, seed=seed, jit=0.09, key=0.05)


@kit.prop('tile_a', tags=['tile'])
def tile_a():
    """Lajota sextavada de basalto com um canto lascado."""
    poly = hexagon(0.62, seed=1, jit=0.04, rot=0.1)
    a, b, c = poly[0], poly[1], poly[5]
    poly = [(lerp(a[0], c[0], 0.3), lerp(a[1], c[1], 0.3)), (lerp(a[0], b[0], 0.34), lerp(a[1], b[1], 0.34))] + poly[1:]
    g = tile_paint(slab(poly, 0.045, cen=(0.08, -0.05)), BASALT, hexc('#4a4670'), ROCK_L, 1, 0.6)
    chip = rock(mesa(3, 0.13, 0.1, 0.05, n=4, top=0.6, tilt=0.4, sink=0.0), lo=BASALT, hi=ROCK_M, seed=1)
    g.add(place(no_bottom(chip), (0.72, -0.08, 0), yaw=30))
    return finish(g, 0.5, 0.2)


@kit.prop('tile_b', tags=['tile'])
def tile_b():
    """Lajota grande rachada em tres cacos, um deles afundado e torto."""
    poly = hexagon(0.72, seed=2, jit=0.04, rot=0.45)
    m = (0.06, -0.04)
    e01 = (lerp(poly[0][0], poly[1][0], 0.55), lerp(poly[0][1], poly[1][1], 0.55))
    e34 = (lerp(poly[3][0], poly[4][0], 0.4), lerp(poly[3][1], poly[4][1], 0.4))
    parts = [([poly[1], poly[2], poly[3], e34, m, e01], (0.0, 0.02), 0.0, 0.05),
             ([e34, poly[4], poly[5], m], (-0.02, -0.03), -3.0, 0.042),
             ([poly[5], poly[0], e01, m], (0.035, -0.02), 4.0, 0.034)]
    g = lp.Geo()
    for i, (pl, sh, rot, h) in enumerate(parts):
        cx = sum(p[0] for p in pl) / len(pl)
        cy = sum(p[1] for p in pl) / len(pl)
        pl = [(cx + (x - cx) * 0.95, cy + (y - cy) * 0.95) for x, y in pl]
        t = tile_paint(slab(pl, h, inset=0.03), BASALT, hexc('#4c4874'), ROCK_L, 5 + i, 0.72)
        t.rot('Z', rot, (cx, cy, 0)).move(sh[0], sh[1], 0)
        g.add(t)
    seam = lp.Geo()   # fundo escuro da rachadura
    ids = [seam.add_vert((x * 0.9, y * 0.9, 0.004), c=mul(ROCK_K, 0.6)) for x, y in poly]
    seam.add_face(ids, 'vcol', False)
    g.add(seam)
    return finish(g, 0.5, 0.2)


@kit.prop('tile_c', tags=['tile'])
def tile_c():
    """Lajota antiga palida com moldura e uma runa de lumen gasta no meio."""
    poly = hexagon(0.6, seed=3, jit=0.025, rot=0.0)
    g = tile_paint(slab(poly, 0.04, inset=0.05), STONE_D, STONE, STONE_L, 3, 0.6)
    inner = slab(hexagon(0.4, seed=4, jit=0.02, rot=0.0), 0.012, bevel=0.006, inset=0.03, dome=0.0)
    tile_paint(inner, mul(STONE_D, 0.8), STONE_D, STONE, 4, 0.4)
    g.add(inner.move(0.01, 0.0, 0.036))
    r = lay_flat(rune('os', 0.5, w=0.06, col=mul(CY, 0.5)), 0.0505)
    r.c = [mul(c, lerp(0.35, 1.0, sm(-0.3, 0.2, p.x + p.y * 0.5))) for p, c in zip(r.v, r.c)]   # metade apagada
    g.add(r)
    return finish(g, 0.45, 0.2, gem=False)


if __name__ == '__main__':
    kit.build()

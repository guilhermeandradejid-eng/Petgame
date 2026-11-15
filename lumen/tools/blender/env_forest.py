"""env_forest.py: kit de cenario "Bosque Luminoso" (floresta encantada ao entardecer, ruinas
antigas tomadas pelo mato).

    python3 tools/blender/env_forest.py [--out caminho.glb] [--only rock_a,tree_b]

A primeira metade do arquivo sao ajudantes de modelagem de cenario (casco convexo, pintura
por faceta, AO azulada, copas, laminas de capim, blocos de pedra...) que o env_hub.py tambem
importa. Tudo segue o guia de estilo do README: formas cheias, facetas grandes, 3 a 5 cores
por objeto, base mais fria/escura e topo mais quente/claro.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import lp  # noqa: E402  (importa o bpy; o bmesh so existe depois dele)
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402
from lp import Geo, box, cyl, icosphere, lathe, loft, merge, poly_extrude, ring_pts, stack, tube  # noqa: E402,F401
from kit import Kit  # noqa: E402

TAU = math.tau
H = lp.hexc
WHITE = lp.WHITE
mixc = lp.mixc

kit = Kit('env_forest')

# --------------------------------------------------------------------------- paleta
LEAF_D = H('#2e8f77')
LEAF_M = H('#3fae7a')
LEAF_L = H('#8fd16a')
LEAF_DEEP = H('#236f6c')
GOLD = H('#f2c14e')
BLOSSOM = H('#ff9ec1')
BLOSSOM_D = H('#d9679d')
BARK_D = H('#6b4a5a')
BARK_L = H('#8a5f4d')
STONE = H('#8e8fb0')
STONE_D = H('#6f6d94')
STONE_L = H('#a9a8c6')
MOSS = H('#5fae6a')
MOSS_L = H('#86c873')
LUMEN = H('#7df9ff')
AMBER = H('#ffc46b')
PINK = H('#ff7fa8')
CREAM = H('#fff3df')
EARTH = H('#6a5068')

# multiplicadores de gradiente (base fria/escura -> topo claro)
COOL = (0.66, 0.64, 0.86)
COOL_SOFT = (0.80, 0.78, 0.93)


def mul(a, b):
    return (a[0] * b[0], a[1] * b[1], a[2] * b[2])


def jit_col(c, rnd, var=0.06):
    """Variacao de valor com leve desvio de temperatura (claro = quente, escuro = frio)."""
    k = rnd.uniform(-var, var)
    return (c[0] * (1 + k * 1.25), c[1] * (1 + k), c[2] * (1 + k * 0.6))


# --------------------------------------------------------------------------- geometria
def fnormal(g, f):
    n = Vector()
    pts = [g.v[i] for i in f]
    for a, b in zip(pts, pts[1:] + pts[:1]):
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n.normalized() if n.length > 1e-12 else Vector((0, 0, 1))


def hull(points, mat='vcol', limit=5.0):
    """Casco convexo facetado (faces coplanares viram um poligono so)."""
    bm = bmesh.new()
    vs = [bm.verts.new(tuple(p)) for p in points]
    r = bmesh.ops.convex_hull(bm, input=vs)
    dead = {e for k in ('geom_interior', 'geom_unused') for e in r.get(k, []) if isinstance(e, bmesh.types.BMVert)}
    if dead:
        bmesh.ops.delete(bm, geom=list(dead), context='VERTS')
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if limit:
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(limit), verts=bm.verts[:], edges=bm.edges[:])
    bm.verts.index_update()
    g = Geo()
    for v in bm.verts:
        g.add_vert(v.co)
    for f in bm.faces:
        g.add_face([v.index for v in f.verts], mat, False)
    bm.free()
    return g


def nofloor(g, z=0.004):
    """Tira as faces coladas no chao (ninguem ve e evita z-fight)."""
    keep = [i for i, f in enumerate(g.f) if not all(g.v[j].z <= z for j in f)]
    g.f = [g.f[i] for i in keep]
    g.fm = [g.fm[i] for i in keep]
    g.fsm = [g.fsm[i] for i in keep]
    return g


SUN = Vector((-0.45, -0.5, 0.74)).normalized()


def facet(g, base=None, top=None, top_n=0.55, under=(0.80, 0.77, 0.95), var=0.06, seed=0, sun=0.07, fn=None):
    """Separa os vertices por face (sombreamento chapado) e pinta cada faceta. Parte da cor de
    vertice que ja existe (vezes `base`, se houver); faces viradas para cima puxam para `top`;
    faces de baixo ficam mais frias; depois variacao por faceta e um toque de luz quente do
    lado do sol. fn(normal, centro, cor) -> cor permite regras extras."""
    rnd = random.Random(seed)
    o = Geo()
    for f, m in zip(g.f, g.fm):
        n = fnormal(g, f)
        cen = sum((g.v[i] for i in f), Vector()) / len(f)
        jk = jit_col(WHITE, rnd, var)
        k = n.dot(SUN) * sun
        lk = (jk[0] * (1 + k * 1.2), jk[1] * (1 + k), jk[2] * (1 + k * 0.5))
        idx = []
        for i in f:
            c = g.c[i] if base is None else mul(g.c[i], base)
            if top is not None and n.z > top_n:
                c = mixc(c, top, min(1.0, (n.z - top_n) / 0.2))
            if n.z < -0.3:
                c = mul(c, under)
            if fn is not None:
                c = fn(n, cen, c)
            idx.append(o.add_vert(g.v[i], g.w[i], mul(c, lk)))
        o.add_face(idx, m, False)
    g.v, g.f, g.fm, g.fsm, g.w, g.c = o.v, o.f, o.fm, o.fsm, o.w, o.c
    return g


def vgrad(g, lo=COOL, hi=WHITE, z0=None, z1=None, power=1.0):
    b0, b1 = g.bounds()
    return g.grad('z', b0[2] if z0 is None else z0, b1[2] if z1 is None else z1, lo, hi, power)


def ramp(g, stops, z0=None, z1=None):
    """Pinta por altura com varias paradas [(t, cor)...] (substitui a cor)."""
    b0, b1 = g.bounds()
    z0 = b0[2] if z0 is None else z0
    z1 = b1[2] if z1 is None else z1

    def fn(p, c):
        t = 0.0 if z1 == z0 else max(0.0, min(1.0, (p.z - z0) / (z1 - z0)))
        for (ta, ca), (tb, cb) in zip(stops, stops[1:]):
            if t <= tb:
                return mixc(ca, cb, (t - ta) / (tb - ta) if tb > ta else 1.0)
        return stops[-1][1]
    return g.tint(fn)


# O jogo ilumina com sol forte + ambiente lilas: uma cor de vertice aparece ~1,6x mais clara na
# tela. Todo cenario passa por ao(), entao a compensacao mora aqui: o albedo desce um degrau
# para a cor *vista* bater com a paleta e os personagens saltarem na frente.
EXPOSE = (0.78, 0.78, 0.82)


def ao(g, strength=0.55, dist=0.7, floor=0.0, expose=EXPOSE):
    """AO de vertice com sombra puxada para o azul/roxo. Nao escurece o material 'glow'."""
    if not g.v:
        return g
    glow = {i for f, m in zip(g.f, g.fm) if m == 'glow' for i in f}
    orig = g.c
    g.c = [WHITE] * len(g.v)
    lp.bake_ao(g, strength=1.0, dist=dist, floor_z=floor)
    out = []
    for i, (c, a) in enumerate(zip(orig, g.c)):
        if i in glow:
            out.append(c)
            continue
        occ = (1.0 - a[0]) * strength
        out.append((c[0] * (1 - occ) * expose[0], c[1] * (1 - occ * 1.03) * expose[1], c[2] * (1 - occ * 0.70) * expose[2]))
    g.c = out
    return g


def clampx(g, lo=-2.0, hi=2.0):
    for p in g.v:
        p.x = max(lo, min(hi, p.x))
    return g


def cut(pts, planes):
    """Achata os pontos que passam de cada plano (normal, distancia): cria facetas grandes."""
    out = [Vector(p) for p in pts]
    for n, d in planes:
        n = Vector(n).normalized()
        for p in out:
            s = p.dot(n) - d
            if s > 0:
                p -= n * s
    return out


# --------------------------------------------------------------------------- pedra
def boulder(rx, ry, h, seed=0, n=7, peak=(0.0, 0.0), shoulder=0.45, top_r=0.5, top_n=3, bulge=1.05, cuts=()):
    """Pedra facetada com forma: anel de base, ombro mais largo e um topo pequeno deslocado."""
    rnd = random.Random(seed)
    pts = []
    ph = rnd.random()
    for i in range(n):
        a = TAU * (i + ph) / n + rnd.uniform(-0.16, 0.16)
        k = rnd.uniform(0.84, 1.06)
        pts.append((math.cos(a) * rx * k, math.sin(a) * ry * k, 0.0))
        a2 = a + rnd.uniform(0.1, 0.4)
        k2 = rnd.uniform(0.92, 1.08) * bulge
        pts.append((peak[0] * rx * 0.35 + math.cos(a2) * rx * k2, peak[1] * ry * 0.35 + math.sin(a2) * ry * k2,
                    h * shoulder * rnd.uniform(0.75, 1.2)))
    for i in range(top_n):
        a = TAU * (i + ph * 2.3) / top_n + rnd.uniform(-0.3, 0.3)
        k = rnd.uniform(0.7, 1.1) * top_r
        pts.append((peak[0] * rx + math.cos(a) * rx * k, peak[1] * ry + math.sin(a) * ry * k,
                    h * rnd.uniform(0.84, 1.0)))
    return nofloor(hull(cut(pts, cuts)))


def stone_paint(g, seed=0, moss=MOSS, z0=None, z1=None, base=STONE, dark=STONE_D, top_n=0.6, var=0.06, lo=COOL):
    """Pedra: lados entre o tom escuro e o claro conforme olham para o sol, topo com musgo."""
    def fn(n, cen, c):
        if n.z > top_n:
            return c
        t = max(0.0, min(1.0, 0.55 + 0.6 * n.dot(SUN)))
        return mul(c, mixc(dark, base, t))
    g.color(WHITE)
    facet(g, None, moss if moss else STONE_L, top_n=top_n, var=var, seed=seed, fn=fn, sun=0.0)
    vgrad(g, lo, (1.0, 0.98, 0.95), z0, z1)
    return g


def chunk(cx, cy, z0, z1, wx, wy, seed=0, n=6, taper=0.86, jit=0.10, mid=1.03, sq=0.45, off=(0.0, 0.0), tilt=(0.0, 0.0)):
    """Bloco/coluna de rocha: prisma irregular (casco). Devolve (geo, anel_do_topo_xy)."""
    rnd = random.Random(seed)
    ph = rnd.random()

    def ring(z, k, ox, oy, tz=(0.0, 0.0)):
        out = []
        for x, y in ring_pts(n, wx / 2 * k, wy / 2 * k, sq, ph):
            j = 1 + rnd.uniform(-jit, jit)
            px, py = cx + ox + x * j, cy + oy + y * j
            out.append((px, py, z + tz[0] * (px - cx) + tz[1] * (py - cy)))
        return out
    bot = ring(z0, 1.0, 0, 0)
    midr = ring(z0 + (z1 - z0) * rnd.uniform(0.38, 0.62), mid, off[0] * 0.5, off[1] * 0.5)
    top = ring(z1, taper, off[0], off[1], tilt)
    return hull(bot + midr + top), [(p[0], p[1]) for p in top]


def hull2d(pts):
    pts = sorted(set((round(x, 5), round(y, 5)) for x, y in pts))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


def grass_cap(poly, z, th=0.14, over=0.10, fringe=0.26, dome=0.10, seed=0, xclamp=None, mat='vcol'):
    """Tampa de grama com franja em zigue-zague caindo pela borda (poly = contorno xy do topo)."""
    rnd = random.Random(seed)
    poly = hull2d(poly)
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    outer = []
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        elen = math.hypot(b[0] - a[0], b[1] - a[1])
        steps = max(2, int(round(elen / 0.42)))
        steps += steps % 2  # par: alterna dente/vale
        for s in range(steps):
            t = s / steps
            outer.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    g = Geo()
    lo, hi = [], []
    for i, (x, y) in enumerate(outer):
        dx, dy = x - cx, y - cy
        d = math.hypot(dx, dy) or 1.0
        tooth = (i % 2 == 0)
        ex = over * (1.0 if tooth else 0.55)
        px, py = x + dx / d * ex, y + dy / d * ex
        if xclamp:
            px = max(xclamp[0], min(xclamp[1], px))
        zl = z - (fringe * rnd.uniform(0.6, 1.0) if tooth else 0.03)
        lo.append(g.add_vert((px, py, zl)))
        hx, hy = x + dx / d * over * 0.25, y + dy / d * over * 0.25
        if xclamp:
            hx = max(xclamp[0], min(xclamp[1], hx))
        hi.append(g.add_vert((hx, hy, z + th * rnd.uniform(0.8, 1.15))))
    m = len(outer)
    ct = g.add_vert((cx, cy, z + th + dome))
    cb = g.add_vert((cx, cy, z - 0.02))
    for i in range(m):
        j = (i + 1) % m
        g.add_face((lo[i], lo[j], hi[j], hi[i]), mat, False)
        g.add_face((hi[i], hi[j], ct), mat, False)
        g.add_face((lo[j], lo[i], cb), mat, False)
    zt = z + th

    def fn(nrm, cen, c):
        if nrm.z > 0.5:
            return mixc(LEAF_M, LEAF_L, 0.7)
        if nrm.z < -0.3:
            return LEAF_DEEP
        return mixc(LEAF_D, LEAF_M, max(0.0, min(1.0, (cen.z - (z - fringe)) / (zt - (z - fringe) + 1e-6))))
    facet(g, fn=fn, var=0.07, seed=seed, under=WHITE)
    return g


# --------------------------------------------------------------------------- folhagem
def blob(r, s=(1.0, 1.0, 0.8), center=(0, 0, 0), seed=0, jit=0.10, sub=1, floor=-0.42, warp=0.10, mat='vcol_wind'):
    """Massa de folhas: icosfera irregular com a barriga achatada."""
    rnd = random.Random(seed * 7 + 3)
    g = icosphere(1.0, sub, mat, jitter=jit, seed=seed)
    g.rot('Z', rnd.uniform(0, 360)).rot('X', rnd.uniform(-18, 18))
    if warp:
        g.warp(lp.noise_warp(warp, seed=seed, freq=1.6))
    if floor is not None:
        for p in g.v:
            if p.z < floor:
                p.z = floor - (floor - p.z) * 0.12
    g.scale(r * s[0], r * s[1], r * s[2])
    g.move(*center)
    return g


def leafy(g, dark=LEAF_D, mid=LEAF_M, light=LEAF_L, deep=LEAF_DEEP, seed=0, var=0.06, z0=None, z1=None, steps=True):
    """Pintura de copa: mistura altura + inclinacao da face numa rampa de 4 tons."""
    b0, b1 = g.bounds()
    z0 = b0[2] if z0 is None else z0
    z1 = b1[2] if z1 is None else z1

    def fn(n, cen, c):
        t = 0.5 * (cen.z - z0) / (z1 - z0 + 1e-6) + 0.5 * (n.z * 0.5 + 0.5)
        t += n.dot(SUN) * 0.10
        if t < 0.30:
            return mixc(deep, dark, max(0.0, t) / 0.30)
        if t < 0.58:
            return mixc(dark, mid, (t - 0.30) / 0.28)
        return mixc(mid, light, min(1.0, (t - 0.58) / 0.30))
    return facet(g, fn=fn, var=var, seed=seed, under=WHITE, sun=0.0)


def spike(base, tip, w, yaw=0.0, mid=None, flat=0.4, n=3, mat='vcol_wind', midw=0.75):
    """Lamina/folha pontuda de secao triangular (fechada dos lados, serve com cull_back)."""
    g = Geo()
    ca, sa = math.cos(yaw), math.sin(yaw)

    def ring(c, r):
        out = []
        for i in range(n):
            a = TAU * i / n
            lx, ly = math.cos(a) * r, math.sin(a) * r * flat
            out.append(g.add_vert((c[0] + lx * ca - ly * sa, c[1] + lx * sa + ly * ca, c[2])))
        return out
    rows = [ring(base, w)]
    if mid is not None:
        rows.append(ring(mid, w * midw))
    t = g.add_vert(tip)
    for r0, r1 in zip(rows, rows[1:]):
        for i in range(n):
            j = (i + 1) % n
            g.add_face((r0[i], r0[j], r1[j], r1[i]), mat, False)
    last = rows[-1]
    for i in range(n):
        j = (i + 1) % n
        g.add_face((last[i], last[j], t), mat, False)
    return g


def tuft(blades, seed=0, c0=LEAF_D, c1=LEAF_L, mat='vcol_wind', n=3):
    """Tufo de capim. blades = [(x, y, altura, largura, yaw_graus, inclinacao, curvo?)...]"""
    g = Geo()
    rnd = random.Random(seed)
    zmax = max(b[2] for b in blades)
    for x, y, h, w, yaw, lean, bent in blades:
        a = math.radians(yaw)
        dx, dy = -math.sin(a), math.cos(a)  # a lamina cai na direcao da face larga
        tip = (x + dx * lean, y + dy * lean, h)
        mid = (x + dx * lean * 0.28, y + dy * lean * 0.28, h * 0.55) if bent else None
        b = spike((x, y, 0.0), tip, w, a, mid, 0.42, n, mat)
        k = jit_col(WHITE, rnd, 0.08)
        b.tint(lambda p, c, k=k: mul(mixc(c0, c1, min(1.0, p.z / zmax) ** 0.8), k))
        g.add(b)
    return g


def limb(path, radii, n=6, mat='vcol', cap_a=False, cap_b=True):
    return tube(path, radii, n, mat, cap_a=cap_a, cap_b=cap_b)


def bark(g, seed=0, c0=BARK_D, c1=BARK_L, z0=None, z1=None, var=0.06):
    ramp(g, [(0.0, mul(c0, (0.80, 0.78, 0.95))), (0.25, c0), (1.0, c1)], z0, z1)
    return facet(g, var=var, seed=seed, sun=0.08)


def roots(r, count=4, seed=0, length=0.5, h=0.45, n=4, phase=0.0):
    """Dedos de raiz saindo da base do tronco e entrando no chao."""
    rnd = random.Random(seed)
    g = Geo()
    for i in range(count):
        a = TAU * (i + phase) / count + rnd.uniform(-0.35, 0.35)
        ln = length * rnd.uniform(0.7, 1.25)
        c, s = math.cos(a), math.sin(a)
        path = [(c * r * 0.35, s * r * 0.35, h * rnd.uniform(0.8, 1.2)),
                (c * (r + ln * 0.35), s * (r + ln * 0.35), h * 0.38),
                (c * (r + ln), s * (r + ln), -0.04)]
        g.add(tube(path, [r * 0.42, r * 0.30, r * 0.10], n, cap_a=False, cap_b=True))
    return g


# =========================================================================== PEDRAS
def shard(cx, cy, w, d, h, seed=0, n=5, lean=(0.0, 0.0), tilt=(0.0, 0.0), taper=0.62, z0=0.0, sq=0.3):
    """Laje/lasca de pedra em pe: prisma que afina, com o topo cortado em diagonal."""
    g, top = chunk(cx, cy, z0, h, w, d, seed=seed, n=n, taper=taper, jit=0.12, mid=0.98, sq=sq, off=lean, tilt=tilt)
    return nofloor(g)


@kit.prop('rock_a', collider=('cyl', 0.95, 2.2), tags=['rock', 'large'])
def rock_a():
    # tres lascas em pe, da maior para a menor, como dentes tortos
    g = merge(
        shard(-0.28, 0.12, 1.25, 1.05, 2.35, seed=3, n=5, lean=(-0.22, 0.05), tilt=(0.55, 0.12), taper=0.55),
        shard(0.62, -0.18, 0.95, 0.85, 1.45, seed=7, n=5, lean=(0.16, -0.05), tilt=(-0.4, 0.2), taper=0.6),
        shard(-0.95, -0.42, 0.62, 0.55, 0.78, seed=12, n=5, lean=(-0.1, -0.04), tilt=(0.3, -0.2), taper=0.62),
        boulder(0.34, 0.28, 0.36, seed=8, n=5, top_r=0.5).move(0.2, -0.78, 0),
    )
    stone_paint(g, seed=3, z0=0, z1=2.3, top_n=0.5)
    g.add(tuft([(-0.45, -0.8, 0.36, 0.06, 20, 0.10, True), (-0.3, -0.86, 0.24, 0.05, -30, 0.08, False),
                (1.22, 0.1, 0.3, 0.06, 200, 0.1, True), (1.15, 0.26, 0.2, 0.05, 150, 0.06, False)], seed=2))
    return ao(g, 0.65)


@kit.prop('rock_b', collider=('cyl', 0.9, 1.0), tags=['rock', 'medium'])
def rock_b():
    # pedra-mesa: laje larga e inclinada apoiada em duas pedras
    slab, _ = chunk(0.05, 0.0, 0.52, 0.98, 2.1, 1.5, seed=5, n=7, taper=0.88, jit=0.10, mid=1.08, sq=0.25,
                    tilt=(0.10, -0.04), off=(0.06, 0.0))
    slab.warp(lambda p: Vector((p.x, p.y, p.z + 0.10 * p.x)))
    g = merge(
        slab,
        boulder(0.62, 0.55, 0.66, seed=21, n=6, peak=(0.1, 0.1), top_r=0.6).move(-0.38, 0.08, 0),
        boulder(0.5, 0.46, 0.74, seed=4, n=6, peak=(-0.2, 0), top_r=0.6).move(0.52, -0.05, 0),
        boulder(0.3, 0.26, 0.3, seed=14, n=5, top_r=0.5).move(-0.92, -0.52, 0),
    )
    stone_paint(g, seed=7, z0=0, z1=1.15, top_n=0.62)
    g.add(tuft([(0.86, -0.6, 0.3, 0.06, 10, 0.1, True), (0.98, -0.52, 0.2, 0.05, 60, 0.07, False),
                (0.72, -0.66, 0.18, 0.05, -40, 0.06, False)], seed=5))
    return ao(g, 0.65)


@kit.prop('rock_c', collider=('cyl', 0.5, 0.65), tags=['rock', 'small'])
def rock_c():
    g = merge(
        shard(0.0, 0.0, 0.9, 0.72, 0.68, seed=33, n=6, lean=(0.1, 0.0), tilt=(-0.35, 0.1), taper=0.66),
        boulder(0.26, 0.22, 0.28, seed=9, n=5, top_r=0.5).move(0.5, -0.3, 0),
    )
    stone_paint(g, seed=1, z0=0, z1=0.75, top_n=0.5)
    return ao(g, 0.65)


@kit.prop('pebble_a', tags=['pebble'])
def pebble_a():
    g = merge(boulder(0.17, 0.13, 0.12, seed=2, n=5, top_r=0.55, top_n=3),
              boulder(0.10, 0.09, 0.08, seed=6, n=4, top_r=0.5).move(0.22, -0.08, 0),
              boulder(0.07, 0.07, 0.06, seed=7, n=4, top_r=0.5).move(-0.08, -0.2, 0))
    facet(g, STONE, STONE_L, var=0.08, seed=4)
    vgrad(g, COOL_SOFT, WHITE)
    return ao(g, 0.5, dist=0.2)


@kit.prop('pebble_b', tags=['pebble'])
def pebble_b():
    g = merge(boulder(0.13, 0.19, 0.10, seed=12, n=5, top_r=0.6, top_n=3).rot('Z', 30),
              boulder(0.09, 0.08, 0.07, seed=16, n=4, top_r=0.5).move(-0.24, 0.05, 0),
              boulder(0.08, 0.06, 0.05, seed=3, n=4, top_r=0.5).move(-0.1, 0.22, 0),
              boulder(0.05, 0.05, 0.04, seed=19, n=4, top_r=0.5).move(0.16, 0.2, 0))
    facet(g, mixc(STONE, STONE_D, 0.4), MOSS, var=0.08, seed=9)
    vgrad(g, COOL_SOFT, WHITE)
    return ao(g, 0.5, dist=0.2)


# =========================================================================== ARVORES
@kit.prop('tree_a', collider=('cyl', 0.38, 4.8), tags=['tree', 'round'])
def tree_a():
    # arvore "nuvem": tronco gordo que entorta e abre em dois, copa de quatro massas
    t = limb([(0, 0, -0.05), (0.06, 0.0, 0.55), (-0.10, 0.05, 1.5), (-0.02, 0.0, 2.3), (-0.2, 0.0, 3.0)],
             [0.42, 0.30, 0.25, 0.21, 0.13], 7)
    br = limb([(-0.08, 0.03, 1.6), (0.45, -0.05, 2.25), (0.95, -0.08, 2.75)], [0.17, 0.13, 0.08], 5)
    b2 = limb([(-0.06, 0.02, 2.0), (-0.6, 0.15, 2.5), (-0.95, 0.2, 2.75)], [0.13, 0.10, 0.06], 5)
    wood = merge(t, br, b2, roots(0.36, 4, seed=3, length=0.42, h=0.5))
    bark(wood, seed=1, z0=0, z1=3.0)
    crown = merge(
        blob(1.32, (1.15, 1.05, 0.82), (-0.2, 0.05, 3.55), seed=1),
        blob(0.92, (1.1, 1.0, 0.8), (1.12, -0.15, 3.05), seed=2),
        blob(0.74, (1.1, 1.0, 0.8), (-1.2, 0.25, 2.95), seed=3),
        blob(0.80, (1.0, 1.0, 0.85), (0.42, 0.2, 4.25), seed=4),
    )
    leafy(crown, seed=2)
    return ao(merge(wood, crown), 0.6, dist=0.9)


def _tier(z0, z1, r, n=7, seed=0, droop=0.3, tilt=(0.0, 0.0), off=(0.0, 0.0), mat='vcol_wind'):
    """Um andar de pinheiro: cone bojudo com a saia em zigue-zague."""
    rnd = random.Random(seed)
    g = Geo()
    ph = rnd.random()
    lo, mid = [], []
    m = n * 2
    for i in range(m):
        a = TAU * (i + ph) / m
        tooth = i % 2 == 0
        k = (1.0 if tooth else 0.74) * rnd.uniform(0.92, 1.08)
        zz = z0 - (droop * rnd.uniform(0.7, 1.1) if tooth else 0.0)
        lo.append(g.add_vert((off[0] + math.cos(a) * r * k, off[1] + math.sin(a) * r * k, zz)))
    for i in range(n):
        a = TAU * (i * 2 + 1 + ph) / m
        k = 0.56 * rnd.uniform(0.92, 1.08)
        mid.append(g.add_vert((off[0] * 0.6 + math.cos(a) * r * k, off[1] * 0.6 + math.sin(a) * r * k,
                               z0 + (z1 - z0) * 0.42)))
    top = g.add_vert((tilt[0], tilt[1], z1))
    bot = g.add_vert((off[0], off[1], z0 + 0.10))
    for i in range(n):
        a0, a1, a2 = lo[(2 * i) % m], lo[(2 * i + 1) % m], lo[(2 * i + 2) % m]
        m0, m1 = mid[(i - 1) % n], mid[i]
        g.add_face((a0, a1, m1), mat, False)
        g.add_face((a0, m1, m0), mat, False)
        g.add_face((a1, a2, m1), mat, False)
        g.add_face((m0, m1, top), mat, False)
    for i in range(m):
        g.add_face((lo[(i + 1) % m], lo[i], bot), mat, False)
    return g


@kit.prop('tree_b', collider=('cyl', 0.32, 5.9), tags=['tree', 'tall'])
def tree_b():
    # pinheiro alto de andares tortos, ponta dobrada
    t = limb([(0, 0, -0.05), (0.03, 0, 0.6), (-0.04, 0.02, 1.7), (0.02, 0, 3.0)], [0.36, 0.25, 0.20, 0.12], 7)
    wood = merge(t, roots(0.30, 3, seed=5, length=0.36, h=0.42, phase=0.4))
    bark(wood, seed=4, z0=0, z1=3.0)
    crown = merge(
        _tier(1.55, 3.3, 1.62, 7, seed=1, droop=0.42, off=(0.05, 0.0), tilt=(-0.05, 0.0)),
        _tier(2.55, 4.2, 1.30, 7, seed=2, droop=0.36, off=(-0.08, 0.05), tilt=(0.06, 0.0)),
        _tier(3.45, 5.0, 0.98, 6, seed=3, droop=0.30, off=(0.08, -0.03), tilt=(0.0, 0.0)),
        _tier(4.3, 5.95, 0.66, 5, seed=4, droop=0.24, off=(-0.03, 0.02), tilt=(0.22, 0.04)),
    )
    leafy(crown, dark=H('#27807a'), mid=H('#35a07c'), light=H('#7fcf7a'), deep=H('#1f6068'), seed=5, z0=1.2, z1=5.95)
    return ao(merge(wood, crown), 0.6, dist=0.9)


@kit.prop('tree_c', collider=('cyl', 0.30, 3.6), tags=['tree', 'blossom'])
def tree_c():
    # arvore de flor torta, copa larga e baixa em prateleiras
    t = limb([(0, 0, -0.05), (0.10, 0, 0.5), (0.34, 0.03, 1.15), (0.22, 0.0, 1.8), (-0.12, 0.0, 2.35)],
             [0.34, 0.24, 0.19, 0.16, 0.10], 6)
    br = limb([(0.3, 0.02, 1.3), (0.85, -0.06, 1.85), (1.25, -0.1, 2.3)], [0.14, 0.10, 0.06], 5)
    b2 = limb([(0.2, 0.0, 1.85), (-0.5, 0.1, 2.2), (-1.05, 0.12, 2.3)], [0.11, 0.08, 0.05], 5)
    wood = merge(t, br, b2, roots(0.28, 3, seed=9, length=0.36, h=0.4, phase=0.2))
    bark(wood, seed=6, z0=0, z1=2.4, c0=H('#5d4160'), c1=H('#84586a'))
    crown = merge(
        blob(1.12, (1.25, 1.05, 0.62), (-0.25, 0.05, 2.95), seed=11),
        blob(0.86, (1.2, 1.0, 0.62), (1.28, -0.12, 2.62), seed=12),
        blob(0.66, (1.15, 1.0, 0.65), (-1.3, 0.15, 2.5), seed=13),
        blob(0.62, (1.1, 1.0, 0.7), (0.5, 0.1, 3.35), seed=14),
    )
    leafy(crown, dark=H('#d95f97'), mid=H('#f783b0'), light=H('#ffb0cc'), deep=H('#a04a8c'), seed=8)
    return ao(merge(wood, crown), 0.55, dist=0.9)


# --------------------------------------------------------------------------- detalhes
def leaf(pos, size, roll=0.0, yaw=0.0, lift=0.35, mat='vcol_wind', col=LEAF_M, two_sided=False, wide=0.33):
    """Folha em pipa dobrada no meio. Local: cabo em (0,0,0), ponta para -Z, frente para -Y.
    roll gira no plano da parede (positivo = ponta para -X); yaw gira em torno de Z."""
    s = size
    pts = [Vector((0, 0, 0)), Vector((-wide * s, 0, -0.36 * s)), Vector((0, -lift * s, -s)), Vector((wide * s, 0, -0.36 * s))]
    cr, sr = math.cos(math.radians(roll)), math.sin(math.radians(roll))
    cy_, sy_ = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    g = Geo()
    for q in pts:
        x, z = q.x * cr + q.z * sr, -q.x * sr + q.z * cr
        y = q.y
        x, y = x * cy_ - y * sy_, x * sy_ + y * cy_
        g.add_vert((pos[0] + x, pos[1] + y, pos[2] + z), None, col)
    g.c[2] = mul(col, (1.10, 1.08, 0.95))
    g.c[0] = mul(col, (0.78, 0.82, 0.95))
    g.add_face((0, 1, 2), mat, False)
    g.add_face((0, 2, 3), mat, False)
    if two_sided:
        g.add_face((2, 1, 0), mat, False)
        g.add_face((3, 2, 0), mat, False)
    return g


IVY_COLS = [LEAF_M, LEAF_M, mixc(LEAF_M, LEAF_L, 0.55), mixc(LEAF_M, LEAF_L, 0.85), LEAF_D]


def ivy(x, z, length, width, y, seed=0, size=0.34, drift=0.0, gold=0.10, wob=0.14, dens=1.0):
    """Cascata de hera numa parede plana (frente em -Y, profundidade y). Duas camadas de folhas
    em pipa apontando para baixo: folhas grandes e escuras que se sobrepoem (a massa) e folhas
    menores e claras por cima (o brilho). Desce de (x, z) e afina."""
    rnd = random.Random(seed)
    g = Geo()

    def at(t):
        cx = x + drift * t + math.sin(t * 4.2 + seed) * wob
        w = width * 0.5 * (1.0 - 0.80 * t ** 1.3)
        return cx, w, z - length * t
    rows = max(3, int(round(length / 0.30)))
    for r in range(rows):
        t = r / rows
        cx, w, zc = at(t)
        cols = max(1, int(round(w * 2 / 0.32)))
        for c in range(cols):
            u = (c + 0.5) / cols - 0.5 + (0.25 / cols if r % 2 else -0.25 / cols)
            lx = cx + u * 2 * w + rnd.uniform(-0.05, 0.05)
            sz = size * 1.8 * rnd.uniform(0.85, 1.15)
            col = mixc(LEAF_D, LEAF_DEEP, min(1.0, t * 0.8 + rnd.uniform(0, 0.4)))
            g.add(leaf((lx, y - 0.02 - 0.015 * (r % 3), zc + sz * 0.45 + rnd.uniform(-0.06, 0.06)), sz, roll=-u * 60 + rnd.uniform(-14, 14),
                       lift=rnd.uniform(0.16, 0.26), col=jit_col(col, rnd, 0.05), wide=0.40))
    n = max(4, int((length * 3.4 + width * 2) * dens))
    for i in range(n):
        t = min(0.98, (i + rnd.random() * 0.8) / n)
        cx, w, zc = at(t)
        u = rnd.uniform(-1.05, 1.05)
        col = GOLD if rnd.random() < gold else rnd.choice(IVY_COLS)
        sz = size * rnd.uniform(0.8, 1.2)
        g.add(leaf((cx + u * w, y - 0.10, zc + sz * 0.3), sz, roll=-u * 38 + rnd.uniform(-15, 15), yaw=rnd.uniform(-10, 10),
                   lift=rnd.uniform(0.3, 0.5), col=jit_col(col, rnd, 0.06)))
    return g


def vine(x, y, z, length, seed=0, r=0.03, leaves=3, sway=0.12, col=LEAF_D):
    """Cipo pendurado com folhas alternadas."""
    rnd = random.Random(seed)
    ph = rnd.uniform(0, TAU)
    path = []
    for i in range(4):
        t = i / 3
        path.append((x + math.sin(ph + t * 2.6) * sway * t, y - 0.02 - 0.03 * t, z - length * t))
    g = tube(path, [r, r * 0.85, r * 0.7, r * 0.3], 3, 'vcol_wind', cap_a=False, cap_b=True).flat()
    g.color(mul(col, (0.8, 0.85, 0.95)))
    for i in range(leaves):
        t = (i + 0.7) / (leaves + 0.1)
        px = x + math.sin(ph + t * 2.6) * sway * t
        side = -1 if i % 2 else 1
        g.add(leaf((px, y - 0.05, z - length * t + 0.08), rnd.uniform(0.28, 0.36), roll=-side * rnd.uniform(30, 55),
                   yaw=rnd.uniform(-20, 20), col=jit_col(rnd.choice(IVY_COLS), rnd, 0.06), two_sided=True))
    g.add(leaf((path[-1][0], y - 0.05, z - length + 0.1), 0.3, roll=rnd.uniform(-10, 10), col=IVY_COLS[2], two_sided=True))
    return g


def crystal(h, r, n=5, seed=0, lean=(0.0, 0.0), pos=(0, 0, 0), mat='glow', col=LUMEN):
    """Cristal de lumen: prisma facetado com ponta, mais escuro na base."""
    rnd = random.Random(seed)
    g = stack([(-0.05, r * 0.72, r * 0.72), (h * rnd.uniform(0.62, 0.78), r, r), (h, r * 0.04, r * 0.04)], n, mat,
              cap_a=False, phase=rnd.random()).flat()
    g.warp(lambda p: Vector((p.x + lean[0] * p.z, p.y + lean[1] * p.z, p.z)))
    deep = mul(col, (0.30, 0.62, 0.80))
    g.tint(lambda p, c: mixc(deep, mixc(col, WHITE, 0.25), max(0.0, min(1.0, p.z / h)) ** 1.3))
    facet(g, var=0.10, seed=seed, sun=0.0, under=WHITE)
    return g.move(*pos)


def block(x0, x1, y0, y1, z0, z1, seed=0, j=0.025, chips=(), chip=0.16, bevel=0.0):
    """Bloco de cantaria levemente torto. chips = cantos lascados (indices 0..7: bit0 x, bit1 y,
    bit2 z). bevel > 0 chanfra a face da frente (-Y) para as juntas aparecerem."""
    rnd = random.Random(seed)
    pts = []
    for ci in range(8):
        sx, sy, sz = ci & 1, (ci >> 1) & 1, (ci >> 2) & 1
        p = Vector(((x1 if sx else x0) + rnd.uniform(-j, j), (y1 if sy else y0) + rnd.uniform(-j, j),
                    (z1 if sz else z0) + rnd.uniform(-j, j) * 0.5))
        if ci in chips:
            c = chip * rnd.uniform(0.7, 1.3)
            dx = (-1 if sx else 1) * min(c * 1.6, (x1 - x0) * 0.6)
            dy = (-1 if sy else 1) * min(c, (y1 - y0) * 0.6)
            dz = (-1 if sz else 1) * min(c * 1.2, (z1 - z0) * 0.7)
            pts += [p + Vector((dx, 0, 0)), p + Vector((0, dy, 0)), p + Vector((0, 0, dz))]
        elif bevel and not sy:
            bx = (-1 if sx else 1) * bevel
            bz = (-1 if sz else 1) * bevel
            pts += [p + Vector((bx, 0, bz)), p + Vector((0, bevel * 1.1, 0))]
        else:
            pts.append(p)
    return hull(pts, limit=3.0)


def arch_stones(cx, z0, r_in, r_out, y0, y1, n=7, a0=0.0, a1=180.0, skip=(), seed=0, key=0.0, j=0.02):
    """Aduelas de um arco no plano XZ (centro cx, nascenca z0). a0..a1 em graus (0 = +X).
    key > 0 faz a pedra do meio (chave) maior. Devolve Geo de blocos soltos."""
    rnd = random.Random(seed)
    g = Geo()
    for i in range(n):
        if i in skip:
            continue
        b0 = math.radians(a0 + (a1 - a0) * i / n)
        b1 = math.radians(a0 + (a1 - a0) * (i + 1) / n)
        is_key = (i == n // 2 and n % 2 == 1)
        ro = r_out + (key if is_key else 0.0) + rnd.uniform(-j, j) * 2
        ri = r_in - (key * 0.3 if is_key else 0.0)
        ya, yb = y0 + rnd.uniform(-j, j) * 2 - (key * 0.5 if is_key else 0.0), y1 + rnd.uniform(-j, j)
        pts = []
        for b in (b0, b1):
            for r in (ri, ro):
                for y in (ya, yb):
                    pts.append((cx + math.cos(b) * r, y, z0 + math.sin(b) * r))
        st = hull(pts)
        kk = rnd.uniform(-0.07, 0.07)
        st.color((1 + kk * 1.2, 1 + kk, 1 + kk * 0.6))
        g.add(st)
    return g


def arched_opening(cx, z_sill, z_spring, r_in, r_out, y0, y1, seed=0, n=7, skip=(), key=0.08, back=None):
    """Vao em arco pronto para encaixar numa alvenaria: ombreiras, aduelas e os dois cantos de
    enchimento. Ocupa o retangulo x = cx +- r_out, z = z_sill .. z_spring + r_out.
    back = y de um fundo cego (nicho); None = vazado (janela)."""
    rnd = random.Random(seed)
    g = Geo()
    for sx in (-1, 1):
        xa, xb = sorted((cx + sx * r_in, cx + sx * r_out))
        zz = z_sill
        hh = (z_spring - z_sill)
        parts = 2 if hh > 0.9 else 1
        for i in range(parts):
            b = block(xa, xb, y0 - 0.03, y1, zz + hh * i / parts, zz + hh * (i + 1) / parts, seed=rnd.randrange(9999), bevel=0.035)
            kk = rnd.uniform(-0.06, 0.08)
            g.add(b.color((1 + kk * 1.2, 1 + kk, 1 + kk * 0.6)))
        # canto de enchimento, um pouco recuado
        corner = [(cx + sx * r_out, z_spring + r_out), (cx + sx * r_out, z_spring), (cx + sx * r_out * 0.05, z_spring + r_out)]
        pts = [(x, y, z) for x, z in corner for y in (y0 + 0.07, y1 - 0.02)]
        g.add(hull(pts).color((0.9, 0.89, 0.96)))
    g.add(arch_stones(cx, z_spring, r_in, r_out, y0 - 0.04, y1, n=n, seed=seed + 1, key=key, skip=skip))
    if back is not None:
        g.add(block(cx - r_out + 0.02, cx + r_out - 0.02, back, y1 - 0.01, z_sill, z_spring + r_out - 0.02, seed=1, j=0.0).color((0.62, 0.60, 0.80)))
    return g


def masonry(rows, y0, y1, seed=0, keep=None, jy=0.06, xlim=(-2.0, 2.0), chip_top=None, bevel=0.035, tone_var=0.12):
    """Fiadas de blocos. rows = [(z0, z1, [x cortes...])]. keep(xc, z0, z1) decide se o bloco existe.
    chip_top(xc, z1) -> True lasca os cantos de cima da frente. Deixa um multiplicador de cor por bloco."""
    rnd = random.Random(seed)
    g = Geo()
    for z0, z1, xs in rows:
        for xa, xb in zip(xs, xs[1:]):
            xc = (xa + xb) / 2
            if keep is not None and not keep(xc, z0, z1):
                continue
            d = rnd.uniform(-jy, jy)
            chips = ()
            if chip_top is not None and chip_top(xc, z1):
                chips = rnd.choice([(4,), (5,), (4, 5), (5, 7), (4, 6)])
            b = block(xa, xb, y0 + d, y1 + d * 0.5, z0, z1, seed=rnd.randrange(9999), chips=chips, chip=0.22, bevel=bevel)
            k = rnd.uniform(-tone_var, tone_var * 0.7)
            tone = (1 + k * 1.2, 1 + k, 1 + k * 0.6)
            r = rnd.random()
            if r < 0.14:
                tone = mul(tone, (0.90, 1.0, 0.93))   # pedra esverdeada de musgo
            elif r < 0.28:
                tone = mul(tone, (1.05, 0.97, 0.98))  # pedra mais rosada
            b.color(tone)
            g.add(b)
    for p in g.v:
        p.x = max(xlim[0], min(xlim[1], p.x))
    return g


def rubble(specs, seed=0):
    """Blocos caidos. specs = [(x, y, sx, sy, sz, yaw, tomba)...]"""
    rnd = random.Random(seed)
    g = Geo()
    for x, y, sx, sy, sz, yaw, tip in specs:
        b = block(-sx / 2, sx / 2, -sy / 2, sy / 2, 0, sz, seed=rnd.randrange(9999), j=0.03, chips=(rnd.choice([4, 5, 6, 7]),), chip=0.12)
        b.rot('Y', tip, (0, 0, 0)).rot('Z', yaw)
        zmin = min(p.z for p in b.v)
        b.move(x, y, -zmin - 0.03)
        k = rnd.uniform(-0.08, 0.05)
        b.color((1 + k * 1.2, 1 + k, 1 + k * 0.6))
        g.add(b)
    return g


# =========================================================================== PAREDES
ROCK = mixc(STONE_D, STONE, 0.25)
ROCK_D = H('#514c78')
ROCK_L = H('#9796b6')


def rock_paint(g, seed=0, zmax=None, moss=MOSS, top_n=0.5, var=0.08):
    """Rocha natural (falesia): facetas viradas para o sol claras, viradas para baixo escuras,
    degraus com musgo e degrade frio na base."""
    b0, b1 = g.bounds()
    zmax = b1[2] if zmax is None else zmax

    def fn(n, cen, c):
        if n.z > top_n:
            return c
        t = max(0.0, min(1.0, 0.5 + 0.55 * n.dot(SUN) + 0.25 * n.z))
        base = mixc(ROCK_D, ROCK, t / 0.6) if t < 0.6 else mixc(ROCK, ROCK_L, (t - 0.6) / 0.4)
        return mul(c, base)
    g.color(WHITE)
    facet(g, None, moss, top_n=top_n, var=var, seed=seed, fn=fn, sun=0.0, under=WHITE)
    stops = [(0.0, (0.62, 0.62, 0.84)), (0.30, (0.84, 0.83, 0.95)), (0.75, (0.97, 0.96, 0.99)), (1.0, (1.0, 0.98, 0.94))]

    def grad(p, c):
        t = max(0.0, min(1.0, p.z / zmax))
        for (ta, ca), (tb, cb) in zip(stops, stops[1:]):
            if t <= tb:
                return mul(c, mixc(ca, cb, (t - ta) / (tb - ta)))
        return c
    return g.tint(grad)


def crag(cx, cy, wx, wy, zs, seed=0, n=6, sq=0.55, wob=0.10, bulge=1.10, shrink=0.90):
    """Coluna de rocha em degraus: blocos empilhados, cada um bojudo, girado e deslocado.
    Devolve (geo, contorno xy do topo)."""
    rnd = random.Random(seed)
    g = Geo()
    top = None
    k = 1.0
    ox = oy = 0.0
    for i, (z0, z1) in enumerate(zip(zs, zs[1:])):
        last = i == len(zs) - 2
        c, top = chunk(cx + ox, cy + oy, z0 - (0.12 if i else 0.0), z1, wx * k, wy * k, seed=rnd.randrange(9999), n=n,
                       taper=rnd.uniform(0.80, 0.90), jit=0.09, mid=bulge * rnd.uniform(0.97, 1.05), sq=sq,
                       off=(rnd.uniform(-wob, wob) * 0.5, rnd.uniform(-wob, wob) * 0.3),
                       tilt=(0.0, 0.0) if last else (rnd.uniform(-0.08, 0.08), rnd.uniform(-0.06, 0.02)))
        g.add(c)
        k *= shrink * rnd.uniform(0.95, 1.06)
        ox += rnd.uniform(-wob, wob)
        oy += rnd.uniform(-wob * 0.3, wob * 0.8)
    return g, top


def _cliff(crags, seed, zmax, vines=(), extra=None, d=1.0):
    """crags = [dict(c=(cx,cy), w=(wx,wy), zs=[...], cap=bool, ...)]. Corta em x = +-2."""
    rock = Geo()
    caps = Geo()
    for i, c in enumerate(crags):
        g, top = crag(c['c'][0], c['c'][1], c['w'][0], c['w'][1], c['zs'], seed=c.get('seed', seed * 10 + i),
                      n=c.get('n', 6), sq=c.get('sq', 0.55), wob=c.get('wob', 0.10), bulge=c.get('bulge', 1.10),
                      shrink=c.get('shrink', 0.90))
        rock.add(g)
        if c.get('cap'):
            top = [(max(-2.0, min(2.0, x)), max(-d, min(d, y))) for x, y in top]
            caps.add(grass_cap(top, c['zs'][-1], th=0.13, over=0.12, fringe=c.get('fringe', 0.32), seed=seed * 7 + i, xclamp=(-2, 2)))
    for p in rock.v:
        p.x = max(-2.0, min(2.0, p.x))
        p.y = max(-d, min(d, p.y))
    nofloor(rock)
    rock_paint(rock, seed, zmax)
    g = merge(rock, caps)
    for v in vines:
        g.add(vine(*v[:4], seed=v[4] if len(v) > 4 else 0, leaves=v[5] if len(v) > 5 else 3))
    if extra is not None:
        g.add(extra)
    return ao(g, 0.75, dist=1.1)


BACKFILL = dict(n=4, sq=0.85, wob=0.0, bulge=1.0, shrink=1.0, cap=True, fringe=0.2)


@kit.prop('wall_cliff_a', collider=('box', 4.0, 2.0, 4.6), tags=['wall', 'cliff'])
def wall_cliff_a():
    crags = [
        dict(c=(0.0, 0.45), w=(4.6, 1.25), zs=[0, 3.4], **BACKFILL),
        dict(c=(-1.2, -0.12), w=(1.9, 1.7), zs=[0, 1.5, 3.2, 4.6], cap=True, seed=3),
        dict(c=(1.25, -0.08), w=(1.8, 1.65), zs=[0, 2.1, 4.0], cap=True, seed=8, n=5),
        dict(c=(0.1, 0.1), w=(1.5, 1.45), zs=[0, 1.7, 3.0], cap=True, seed=14, n=5),
        dict(c=(0.35, -0.6), w=(1.5, 0.8), zs=[0, 1.15], seed=21, n=5),
        dict(c=(-1.5, -0.74), w=(0.85, 0.5), zs=[0, 0.6], seed=5, n=5),
    ]
    extra = tuft([(0.1, -0.66, 0.36, 0.07, 15, 0.1, True), (0.28, -0.62, 0.26, 0.06, -50, 0.08, False),
                  (0.0, -0.58, 0.2, 0.05, 70, 0.06, False)], seed=3).move(0, 0, 1.13)
    return _cliff(crags, 1, 4.6, vines=[(1.0, -0.82, 3.95, 1.4, 2), (-0.5, -0.86, 4.5, 1.0, 5, 2)], extra=extra)


@kit.prop('wall_cliff_b', collider=('box', 4.0, 2.0, 5.3), tags=['wall', 'cliff'])
def wall_cliff_b():
    crags = [
        dict(c=(0.0, 0.45), w=(4.6, 1.25), zs=[0, 3.8], **BACKFILL),
        dict(c=(0.3, -0.05), w=(2.1, 1.8), zs=[0, 1.9, 3.7, 5.3], cap=True, seed=31, shrink=0.86),
        dict(c=(-1.4, -0.05), w=(1.55, 1.6), zs=[0, 1.6, 3.4], cap=True, seed=37, n=5),
        dict(c=(1.5, 0.0), w=(1.35, 1.5), zs=[0, 2.4, 4.3], cap=True, seed=41, n=5),
        dict(c=(-0.95, -0.68), w=(1.2, 0.65), zs=[0, 0.9, 1.7], seed=44, n=5),
        dict(c=(1.4, -0.72), w=(1.0, 0.55), zs=[0, 0.75], seed=48, n=5),
    ]
    cr = merge(crystal(0.9, 0.16, 5, seed=1, lean=(0.16, -0.12), pos=(0.5, -0.92, 0)),
               crystal(0.58, 0.12, 5, seed=2, lean=(-0.3, -0.15), pos=(0.24, -0.96, 0)),
               crystal(0.4, 0.10, 4, seed=3, lean=(0.45, -0.1), pos=(0.78, -0.97, 0)))
    return _cliff(crags, 2, 5.3, vines=[(-1.3, -0.82, 3.35, 1.2, 4), (1.42, -0.74, 4.2, 1.5, 7)], extra=cr)


@kit.prop('wall_cliff_c', collider=('box', 4.0, 2.0, 3.9), tags=['wall', 'cliff'])
def wall_cliff_c():
    crags = [
        dict(c=(0.0, 0.45), w=(4.6, 1.25), zs=[0, 3.2], **BACKFILL),
        dict(c=(-0.9, -0.1), w=(2.4, 1.7), zs=[0, 1.4, 2.7, 3.9], cap=True, seed=52, shrink=0.93),
        dict(c=(1.3, 0.05), w=(1.7, 1.55), zs=[0, 1.6, 3.0], cap=True, seed=57, n=5),
        dict(c=(1.0, -0.55), w=(2.1, 0.9), zs=[0, 0.9, 1.7], cap=True, seed=63, fringe=0.24, shrink=0.97, wob=0.05),
        dict(c=(-1.3, -0.74), w=(1.1, 0.5), zs=[0, 0.85], seed=66, n=5),
    ]
    bush = merge(blob(0.42, (1.15, 1.0, 0.8), (1.3, -0.42, 2.02), seed=5, mat='vcol_wind'),
                 blob(0.28, (1.1, 1.0, 0.8), (0.75, -0.58, 1.95), seed=6, mat='vcol_wind'))
    leafy(bush, seed=3)
    return _cliff(crags, 3, 3.9, vines=[(-0.3, -0.9, 3.8, 1.3, 3), (-1.6, -0.84, 3.8, 0.9, 6, 2)], extra=bush)


def _wall_paint(g, seed, zmax, moss=0.5):
    """Pedra lavrada: lados entre o tom escuro e o claro conforme olham para o sol; topos
    claros, com musgo em manchas (moss = fracao aproximada)."""
    def fn(n, cen, c):
        if n.z > 0.7:
            k = 0.5 + 0.5 * math.sin(cen.x * 2.3 + cen.y * 3.1 + cen.z * 1.7 + seed * 1.3)
            return mul(c, MOSS if k < moss else mixc(STONE, STONE_L, 0.5))
        t = max(0.0, min(1.0, 0.55 + 0.6 * n.dot(SUN)))
        return mul(c, mixc(STONE_D, STONE, t))
    facet(g, None, None, var=0.035, seed=seed, sun=0.0, under=(0.8, 0.78, 0.92), fn=fn)
    vgrad(g, (0.62, 0.62, 0.86), (1.0, 0.98, 0.95), 0, zmax)
    return g


@kit.prop('wall_ruin_a', collider=('box', 4.0, 1.5, 4.8), tags=['wall', 'ruin'])
def wall_ruin_a():
    # muro com janela em arco, topo quebrado descendo para a direita, hera na esquerda
    def top(x):
        return 4.8 if x < -1.0 else (4.1 if x < 0.3 else (3.4 if x < 1.3 else 2.0))

    def keep(xc, z0, z1):
        if z0 >= top(xc) - 0.05:
            return False
        if -0.75 < xc < 1.15 and 1.3 < (z0 + z1) / 2 < 3.4:
            return False
        return True
    Y0, Y1 = -0.42, 0.5
    rows = [
        (0.60, 1.30, [-2, -0.9, 0.5, 1.3, 2]),
        (1.30, 2.00, [-2, -1.6, -0.75, 1.15, 2]),
        (2.00, 2.70, [-2, -0.75, 1.15, 1.7, 2]),
        (2.70, 3.40, [-2, -1.35, -0.75, 1.15, 1.3]),
        (3.40, 4.10, [-2, -1.0, 0.3]),
        (4.10, 4.80, [-2, -1.55, -1.0]),
    ]
    g = masonry(rows, Y0, Y1, seed=4, keep=keep, chip_top=lambda xc, z1: z1 >= top(xc) - 0.05)
    g.add(masonry([(0.0, 0.6, [-2, -0.5, 1.0, 2])], -0.6, 0.66, seed=9, jy=0.03))        # embasamento
    g.add(arched_opening(0.2, 1.3, 2.45, 0.6, 0.95, Y0, Y1, seed=6, n=7))
    sill = block(-0.5, 0.9, -0.56, 0.3, 1.2, 1.32, seed=5, j=0.02)
    butt, _ = chunk(-1.5, -0.56, 0.0, 3.0, 0.66, 0.42, seed=6, n=4, sq=0.85, taper=0.7, jit=0.04, off=(0, 0.12))
    g = merge(g, sill.color((1.05, 1.03, 1.0)), butt.color((0.95, 0.94, 0.98)))
    g.add(rubble([(1.4, -0.52, 0.66, 0.42, 0.4, 22, 14), (0.85, -0.62, 0.36, 0.3, 0.26, -30, -8), (1.78, -0.36, 0.34, 0.3, 0.24, 50, 20),
                  (1.55, 0.2, 0.7, 0.5, 0.45, -12, -18)], seed=3))
    for p in g.v:
        p.y = max(-0.75, min(0.75, p.y))
    _wall_paint(g, 2, 4.8)
    g.add(ivy(-1.3, 4.9, 3.3, 1.3, Y0 - 0.05, seed=3, drift=0.3))
    g.add(ivy(1.55, 2.1, 1.2, 0.8, Y0 - 0.05, seed=12, drift=-0.1))
    g.add(tuft([(0.7, -0.1, 0.32, 0.06, 0, 0.08, True), (0.84, 0.0, 0.22, 0.05, 80, 0.06, False), (0.56, 0.05, 0.24, 0.05, -60, 0.06, False)], seed=4).move(0, 0, 3.4))
    clampx(g)
    return ao(g, 0.7, dist=0.6)


@kit.prop('wall_ruin_b', collider=('box', 4.0, 1.5, 4.8), tags=['wall', 'ruin'])
def wall_ruin_b():
    # dois pilares salientes e um nicho em arco com cristal de lumen; lados desabados
    def top(x):
        return 3.4 if x < -1.25 else (4.8 if x < 0.2 else (4.1 if x < 1.0 else 2.7))

    def keep(xc, z0, z1):
        if z0 >= top(xc) - 0.05:
            return False
        if abs(xc) < 0.9 and 0.6 < (z0 + z1) / 2 < 2.7:
            return False
        return True
    Y0, Y1 = -0.3, 0.56
    rows = [
        (0.60, 1.30, [-2, -0.9, 0.9, 2]),
        (1.30, 2.00, [-2, -1.5, -0.9, 0.9, 1.45, 2]),
        (2.00, 2.70, [-2, -0.9, 0.9, 2]),
        (2.70, 3.40, [-2, -1.25, -0.2, 1.0, 2]),
        (3.40, 4.10, [-1.25, -0.6, 0.2, 1.0]),
        (4.10, 4.80, [-1.25, -0.5, 0.2]),
    ]
    g = masonry(rows, Y0, Y1, seed=11, keep=keep, chip_top=lambda xc, z1: z1 >= top(xc) - 0.05)
    g.add(masonry([(0.0, 0.6, [-2, -0.7, 0.8, 2])], -0.56, 0.7, seed=12, jy=0.03))
    g.add(arched_opening(0.0, 0.6, 1.8, 0.58, 0.9, Y0, Y1, seed=3, n=7, back=0.18))
    # pilares salientes
    for px, ph, sd in ((-1.32, 3.4, 21), (1.34, 2.3, 22)):
        prow = []
        z, i = 0.6, 0
        while z < ph - 0.01:
            hgt = 0.7
            prow.append((z, min(ph, z + hgt), [px - 0.34, px + 0.34]))
            z += hgt
            i += 1
        g.add(masonry(prow, -0.64, -0.2, seed=sd, jy=0.03, chip_top=lambda xc, z1, ph=ph: z1 >= ph - 0.02))
    g.add(block(-1.78, -0.86, -0.74, -0.1, 3.4, 3.62, seed=7, j=0.02, chips=(4,)).color((1.06, 1.04, 1.0)))
    g.add(rubble([(1.5, -0.56, 0.62, 0.4, 0.36, -18, 10), (0.95, -0.62, 0.34, 0.3, 0.24, 40, -12), (-0.55, -0.6, 0.32, 0.28, 0.2, 15, 8),
                  (1.6, 0.25, 0.66, 0.5, 0.42, 20, 16)], seed=8))
    for p in g.v:
        p.y = max(-0.75, min(0.75, p.y))
    _wall_paint(g, 5, 4.8)
    # cristal no nicho, em cima de um pedestal
    ped, _ = chunk(0.0, -0.1, 0.55, 0.9, 0.62, 0.44, seed=3, n=6, taper=0.8, jit=0.04)
    stone_paint(ped, seed=2, moss=None, z0=0.3, z1=0.95)
    g.add(ped)
    g.add(crystal(0.95, 0.17, 5, seed=5, lean=(0.06, 0.0), pos=(-0.03, -0.1, 0.9)))
    g.add(crystal(0.5, 0.1, 4, seed=6, lean=(0.35, -0.05), pos=(0.15, -0.12, 0.9)))
    g.add(ivy(1.2, 4.2, 2.6, 1.2, Y0 - 0.05, seed=5, drift=0.35))
    g.add(ivy(-1.3, 3.75, 1.5, 0.8, -0.7, seed=9, drift=0.05))
    clampx(g)
    return ao(g, 0.7, dist=0.6)


# =========================================================================== RUINAS
def drum(z0, z1, r0, r1=None, n=8, phase=0.0, off=(0.0, 0.0), ch=0.035):
    """Tambor de coluna com um chanfro pequeno nas juntas."""
    r1 = r0 if r1 is None else r1
    return stack([(z0, r0 - ch, r0 - ch, off[0], off[1]), (z0 + ch, r0, r0, off[0], off[1]),
                  (z1 - ch, r1, r1, off[0], off[1]), (z1, r1 - ch, r1 - ch, off[0], off[1])], n, phase=phase)


def broken_drum(z0, z1, r, n=8, seed=0, jag=0.5, phase=0.0, off=(0.0, 0.0)):
    """Tambor com o topo quebrado em diagonal (um lado alto, o outro baixo) e uma cratera."""
    rnd = random.Random(seed)
    ring = ring_pts(n, r, r, 0.0, phase)
    th0 = rnd.uniform(0, TAU)
    lo = [(off[0] + x, off[1] + y, z0) for x, y in ring]
    hi = []
    for x, y in ring:
        k = 0.5 - 0.5 * math.cos(math.atan2(y, x) - th0)
        hi.append((off[0] + x * 0.97, off[1] + y * 0.97, z1 - jag * (k ** 0.8) * rnd.uniform(0.8, 1.0)))
    g = loft([lo, hi])
    g.v[-1].z = (min(p[2] for p in hi) + max(p[2] for p in hi)) / 2 - 0.12
    return g


def rune_band(r, z0, z1, n=8, phase=0.0, every=2, col=LUMEN, off=(0.0, 0.0), start=0):
    """Losangos de lumen entalhados em faces alternadas de um tambor."""
    g = Geo()
    pts = ring_pts(n, r + 0.012, r + 0.012, 0.0, phase)
    zm = (z0 + z1) / 2
    for i in range(start, n, every):
        a, b = pts[i], pts[(i + 1) % n]
        m = ((a[0] + b[0]) / 2 + off[0], (a[1] + b[1]) / 2 + off[1])
        la = (a[0] + (b[0] - a[0]) * 0.24 + off[0], a[1] + (b[1] - a[1]) * 0.24 + off[1])
        lb = (a[0] + (b[0] - a[0]) * 0.76 + off[0], a[1] + (b[1] - a[1]) * 0.76 + off[1])
        idx = [g.add_vert((la[0], la[1], zm), None, col), g.add_vert((m[0], m[1], z0), None, mul(col, (0.6, 0.8, 0.9))),
               g.add_vert((lb[0], lb[1], zm), None, col), g.add_vert((m[0], m[1], z1), None, mixc(col, WHITE, 0.3))]
        g.add_face(idx, 'glow', False)
    return g


def ivy_wrap(r, z_top, length, th0, th1, seed=0, size=0.3, center=(0.0, 0.0), gold=0.1, dens=1.0):
    """Hera abracando um cilindro entre os angulos th0..th1 (graus), descendo e afinando."""
    rnd = random.Random(seed)
    g = Geo()
    thm, span = (th0 + th1) / 2, (th1 - th0)
    rows = max(2, int(round(length / 0.3)))
    for layer in (0, 1):
        for ri in range(rows):
            t = ri / rows
            w = span * (1.0 - 0.75 * t)
            arc = math.radians(w) * r
            cols = max(1, int(round(arc / (0.30 if layer == 0 else 0.5))))
            for c in range(cols):
                if layer == 1 and rnd.random() > 0.7 * dens:
                    continue
                u = (c + 0.5) / cols - 0.5 + rnd.uniform(-0.12, 0.12)
                th = math.radians(thm + u * w + math.sin(t * 4 + seed) * 8)
                rr = r + (0.03 if layer == 0 else 0.09)
                if layer == 0:
                    col = mixc(LEAF_D, LEAF_DEEP, min(1.0, t * 0.8 + rnd.uniform(0, 0.4)))
                    sz = size * 1.8 * rnd.uniform(0.85, 1.15)
                else:
                    col = GOLD if rnd.random() < gold else rnd.choice(IVY_COLS)
                    sz = size * rnd.uniform(0.8, 1.2)
                g.add(leaf((center[0] + math.cos(th) * rr, center[1] + math.sin(th) * rr, z_top - length * t + sz * 0.4 + rnd.uniform(-0.06, 0.06)),
                           sz, roll=rnd.uniform(-22, 22), yaw=math.degrees(th) + 90, lift=rnd.uniform(0.2, 0.4),
                           col=jit_col(col, rnd, 0.06), wide=0.40 if layer == 0 else 0.33))
    return g


@kit.prop('pillar_a', collider=('cyl', 0.52, 3.4), tags=['pillar', 'whole'])
def pillar_a():
    g = merge(
        block(-0.55, 0.55, -0.55, 0.55, 0.0, 0.26, seed=1, j=0.02, chips=(5,), chip=0.14),
        stack([(0.26, 0.47, 0.47), (0.34, 0.50, 0.50), (0.44, 0.41, 0.41)], 8),
        drum(0.44, 1.32, 0.385, 0.37, phase=0.0, off=(0.0, 0.0)),
        drum(1.32, 2.2, 0.37, 0.35, phase=0.3, off=(0.025, -0.01)),
        drum(2.2, 3.0, 0.35, 0.325, phase=0.65, off=(-0.015, 0.02)),
        stack([(3.0, 0.32, 0.32), (3.07, 0.39, 0.39), (3.14, 0.35, 0.35), (3.27, 0.50, 0.50)], 8, phase=0.2),
        block(-0.56, 0.56, -0.56, 0.56, 3.27, 3.44, seed=4, j=0.02, chips=(6,), chip=0.2).rot('Z', 5).rot('Y', 1.5, (0, 0, 3.27)),
    )
    _wall_paint(g, 3, 3.44)
    g.add(rune_band(0.362, 1.58, 1.94, 8, phase=0.3, off=(0.025, -0.01)))
    g.add(ivy_wrap(0.37, 1.25, 1.2, -150, -20, seed=4, size=0.28))
    g.add(tuft([(0.5, -0.58, 0.3, 0.06, 20, 0.09, True), (0.62, -0.5, 0.2, 0.05, 80, 0.06, False), (0.4, -0.64, 0.18, 0.05, -50, 0.06, False)], seed=1))
    return ao(g, 0.65, dist=0.6)


@kit.prop('pillar_b', collider=('cyl', 0.6, 1.9), tags=['pillar', 'broken'])
def pillar_b():
    g = merge(
        block(-0.55, 0.55, -0.55, 0.55, 0.0, 0.26, seed=2, j=0.02, chips=(4, 7), chip=0.16),
        stack([(0.26, 0.47, 0.47), (0.34, 0.50, 0.50), (0.44, 0.41, 0.41)], 8),
        drum(0.44, 1.3, 0.385, 0.37, phase=0.1),
        broken_drum(1.3, 2.0, 0.365, 8, seed=5, jag=0.55, phase=0.45, off=(0.02, 0.015)),
    )
    # tambor caido ao lado, encostado na base
    fallen = merge(drum(-0.42, 0.42, 0.35, 0.34, phase=0.2), )
    fallen.rot('Y', 78).rot('Z', 28).move(0.98, -0.36, 0.30)
    g.add(fallen)
    g.add(rubble([(0.35, -0.86, 0.34, 0.28, 0.22, 30, 12), (-0.72, -0.62, 0.26, 0.22, 0.18, -20, -10)], seed=4))
    _wall_paint(g, 6, 2.0)
    g.add(ivy_wrap(0.38, 1.95, 1.5, 100, 250, seed=7, size=0.28))
    g.add(tuft([(-0.5, 0.6, 0.3, 0.06, 200, 0.09, True), (-0.62, 0.5, 0.2, 0.05, 140, 0.06, False)], seed=2))
    return ao(g, 0.65, dist=0.6)


@kit.prop('pillar_c', collider=('box', 3.3, 1.0, 0.7), tags=['pillar', 'fallen'])
def pillar_c():
    a = merge(drum(-0.8, 0.0, 0.37, 0.36, phase=0.1), drum(0.0, 0.75, 0.36, 0.35, phase=0.4, off=(0.015, 0.0)))
    a.rot('Y', 90).rot('Z', 4).move(-0.55, 0.02, 0.27)
    b = broken_drum(0.0, 0.95, 0.35, 8, seed=3, jag=0.4, phase=0.2)
    b.rot('Y', 90).rot('Y', -7).rot('Z', -9).move(0.42, -0.06, 0.27)
    cap = merge(stack([(0.0, 0.32, 0.32), (0.07, 0.39, 0.39), (0.14, 0.35, 0.35), (0.27, 0.50, 0.50)], 8, phase=0.2),
                block(-0.55, 0.55, -0.55, 0.55, 0.27, 0.44, seed=4, j=0.02, chips=(6,), chip=0.2))
    cap.rot('Y', 62).rot('Z', -24).move(1.18, 0.1, 0.36)
    g = merge(a, b, cap, rubble([(0.3, -0.52, 0.3, 0.26, 0.2, 30, 10), (-1.4, 0.42, 0.24, 0.2, 0.16, -15, -8)], seed=6))
    g.keep_faces(lambda c: c.z > -0.02)
    _wall_paint(g, 9, 0.9)
    g.add(tuft([(-0.9, -0.44, 0.34, 0.06, 0, 0.1, True), (-0.76, -0.48, 0.22, 0.05, 60, 0.07, False), (-1.02, -0.42, 0.2, 0.05, -40, 0.06, False),
                (0.7, 0.44, 0.3, 0.06, 180, 0.09, True), (0.84, 0.4, 0.2, 0.05, 220, 0.06, False)], seed=3))
    return ao(g, 0.65, dist=0.5)


@kit.prop('ruin_arch', collider=('box', 3.7, 0.9, 3.7), tags=['ruin', 'arch'])
def ruin_arch():
    Y0, Y1 = -0.36, 0.36
    rows_l = [(0.3 + i * 0.6, 0.9 + i * 0.6, [-1.72, -1.05]) for i in range(3)]
    rows_r = [(0.3 + i * 0.6, 0.9 + i * 0.6, [1.05, 1.72]) for i in range(3)]
    g = merge(
        masonry(rows_l, Y0, Y1, seed=3, jy=0.03, xlim=(-9, 9)),
        masonry(rows_r, Y0, Y1, seed=5, jy=0.03, xlim=(-9, 9)),
        block(-1.86, -0.92, -0.48, 0.48, 0.0, 0.3, seed=1, j=0.02, chips=(4,)),
        block(0.92, 1.86, -0.48, 0.48, 0.0, 0.3, seed=2, j=0.02, chips=(7,)),
        block(-1.8, -0.98, -0.42, 0.42, 2.1, 2.28, seed=6, j=0.015),
        block(0.98, 1.8, -0.42, 0.42, 2.1, 2.28, seed=7, j=0.015, chips=(5,)),
        arch_stones(0.0, 2.28, 1.05, 1.52, Y0, Y1, n=9, seed=4, key=0.12, skip=(2,)),
    )
    # aduela caida
    fallen = arch_stones(0.0, 0.0, 1.05, 1.52, -0.36, 0.36, n=9, seed=9, skip=(0, 1, 3, 4, 5, 6, 7, 8))
    cen = sum((p for p in fallen.v), Vector()) / len(fallen.v)
    fallen.move(-cen.x, -cen.y, -cen.z).rot('X', 90).rot('Z', 35)
    zmin = min(p.z for p in fallen.v)
    fallen.move(0.7, -0.8, -zmin - 0.03)
    g.add(fallen)
    g.add(rubble([(1.3, -0.72, 0.36, 0.3, 0.24, 20, 10), (-0.5, 0.7, 0.3, 0.26, 0.2, -35, 12)], seed=5))
    _wall_paint(g, 4, 3.9)
    g.add(ivy(-1.5, 3.2, 2.3, 0.9, Y0 - 0.06, seed=6, drift=-0.1, wob=0.06))
    g.add(ivy(1.4, 2.4, 1.1, 0.7, Y0 - 0.06, seed=2, drift=0.05, wob=0.05))
    g.add(tuft([(-1.9, -0.5, 0.3, 0.06, 0, 0.09, True), (-2.0, -0.4, 0.2, 0.05, 60, 0.06, False)], seed=5))
    return ao(g, 0.65, dist=0.7)


@kit.prop('ruin_statue', collider=('cyl', 0.62, 3.0), tags=['ruin', 'statue'])
def ruin_statue():
    # guardia encapuzada erguendo um orbe de lumen; perdeu o braco direito
    zp = 0.92
    ped = merge(
        block(-0.64, 0.64, -0.6, 0.6, 0.0, 0.24, seed=1, j=0.02, chips=(4,), chip=0.14),
        block(-0.48, 0.48, -0.45, 0.45, 0.24, 0.78, seed=2, j=0.015, bevel=0.03),
        block(-0.58, 0.58, -0.54, 0.54, 0.78, zp, seed=3, j=0.015, chips=(5,), chip=0.12),
    )
    robe = stack([(0.0, 0.47, 0.41), (0.16, 0.44, 0.38), (0.8, 0.31, 0.27), (1.14, 0.27, 0.23)], 8, phase=0.25)

    def folds(p):
        k = 1.0 + 0.10 * math.cos(4 * math.atan2(p.y, p.x) + 0.6) * max(0.0, 1.0 - p.z / 0.8)
        return Vector((p.x * k, p.y * k, p.z))
    robe.warp(folds)
    mantle = stack([(0.98, 0.42, 0.33), (1.20, 0.41, 0.31), (1.35, 0.28, 0.22), (1.43, 0.15, 0.15)], 7, phase=0.1)
    hood = stack([(1.38, 0.18, 0.18), (1.54, 0.275, 0.29), (1.74, 0.255, 0.29, 0, 0.03), (1.90, 0.14, 0.18, 0, 0.10),
                  (2.03, 0.02, 0.02, 0.02, 0.22)], 7, phase=0.25)
    hood.v = cut(hood.v, [((0, -1, 0), 0.19)])
    arm_l = tube([(0.33, 0.0, 1.24), (0.52, -0.2, 1.33), (0.45, -0.42, 1.60)], [0.115, 0.10, 0.085], 5)
    cuff = stack([(0.0, 0.13, 0.13), (0.1, 0.10, 0.10)], 6).rot('X', 40).move(0.45, -0.40, 1.56)
    stub = tube([(-0.33, 0.0, 1.24), (-0.42, -0.07, 1.10)], [0.115, 0.095], 5)
    fig = merge(robe, mantle, hood, arm_l, cuff, stub)
    fig.rot('Y', -2.5).rot('Z', 8).move(0.0, 0.02, zp)
    piece = tube([(0, 0, 0), (0.3, 0, 0.03)], [0.095, 0.08], 5).rot('Z', 40).move(-0.6, -0.85, 0.08)
    g = merge(ped, fig, piece)
    _wall_paint(g, 8, 3.0, moss=0.6)

    def face_dark(n, cen, c):
        if n.y < -0.8 and zp + 1.46 < cen.z < zp + 1.92 and abs(cen.x) < 0.3:
            return mul(c, (0.36, 0.34, 0.58))
        return c
    facet(g, fn=face_dark, var=0.0, sun=0.0, under=WHITE)
    orb = icosphere(0.15, 1, 'glow', jitter=0.0)
    orb.color(LUMEN).grad('z', -0.15, 0.15, (0.45, 0.75, 0.9), (1.0, 1.0, 1.0))
    orb.move(0.45, -0.46, 1.76).rot('Y', -2.5).rot('Z', 8).move(0, 0.02, zp)
    g.add(orb)
    g.add(ivy(-0.22, 0.9, 0.85, 0.7, -0.62, seed=4, size=0.24, drift=-0.1, wob=0.04))
    g.add(tuft([(0.68, -0.52, 0.3, 0.06, 10, 0.08, True), (0.76, -0.4, 0.2, 0.05, 70, 0.06, False)], seed=7))
    return ao(g, 0.65, dist=0.6)


@kit.prop('ruin_stairs', collider=('box', 2.5, 2.5, 1.0), tags=['ruin', 'stairs'])
def ruin_stairs():
    g = Geo()
    rnd = random.Random(5)
    n = 5
    for i in range(n):
        y0 = -1.25 + i * 0.36
        z1 = 0.2 * (i + 1)
        x1 = 1.0 if i < 3 else (0.72 if i == 3 else 0.4)
        cutx = rnd.uniform(-0.4, 0.3)
        for xa, xb in ((-1.0, cutx), (cutx, x1)):
            ch = (5,) if (xb == x1 and i >= 3) else ((4,) if rnd.random() < 0.3 and xa == -1.0 else ())
            b = block(xa, xb, y0 - 0.02, y0 + 0.40, 0.0, z1, seed=rnd.randrange(999), j=0.018, chips=ch, chip=0.14)
            k = rnd.uniform(-0.09, 0.06)
            g.add(b.color((1 + k * 1.2, 1 + k, 1 + k * 0.6)))
    g.add(block(-1.0, 0.25, 0.55, 1.25, 0.0, 1.0, seed=9, j=0.02, chips=(5,), chip=0.3))
    g.add(block(-1.0, 1.0, 0.55, 1.25, 0.0, 0.62, seed=10, j=0.02, chips=(5,), chip=0.2).color((0.93, 0.92, 0.97)))
    # mureta da esquerda em degraus, a da direita so sobrou o pe
    g.add(block(-1.3, -0.98, -1.3, -0.4, 0.0, 0.62, seed=11, j=0.02, chips=(4,)))
    g.add(block(-1.3, -0.98, -0.4, 0.45, 0.0, 1.05, seed=12, j=0.02).color((1.05, 1.03, 1.0)))
    g.add(block(-1.3, -0.98, 0.45, 1.25, 0.0, 1.42, seed=13, j=0.02, chips=(6,)).color((0.95, 0.95, 0.99)))
    g.add(block(0.98, 1.3, -1.3, -0.62, 0.0, 0.5, seed=14, j=0.02, chips=(5, 6), chip=0.2))
    g.add(rubble([(1.22, -0.2, 0.4, 0.3, 0.26, 25, 14), (1.1, 0.5, 0.5, 0.4, 0.3, -20, -15), (0.72, 0.95, 0.3, 0.28, 0.22, 50, 10)], seed=2))
    _wall_paint(g, 7, 1.45)
    g.add(tuft([(0.5, 0.4, 0.32, 0.06, 0, 0.08, True), (0.62, 0.48, 0.22, 0.05, 80, 0.06, False), (0.4, 0.5, 0.2, 0.05, -60, 0.06, False)], seed=4).move(0, 0, 0.8))
    g.add(ivy(-1.14, 1.45, 1.0, 0.36, -0.42, seed=3, size=0.24, wob=0.02).warp(lambda p: Vector((-1.32 - (p.y + 0.42), 0.85 + (p.x + 1.14), p.z))))
    return ao(g, 0.65, dist=0.6)


# =========================================================================== PLANTAS
def gblob(r, s, x, y, seed, z=0.0, floor=-0.40, **kw):
    """Massa de folhas apoiada no chao (a barriga chata fica em z)."""
    return blob(r, s, (x, y, z - floor * r * s[2] - 0.02), seed=seed, floor=floor, **kw)


def gem(pos, r, h=None, mat='vcol', col=PINK, tip=None, n=4, phase=0.0):
    """Diamante pequeno (dois cones): botao de flor, baga, brilho."""
    h = r * 1.3 if h is None else h
    g = lathe([(0.0, -h * 0.6), (r, 0.0), (0.0, h)], n, mat, phase=phase, smooth=False)
    g.tint(lambda p, c: mixc(mul(col, (0.75, 0.75, 0.9)), tip if tip is not None else mixc(col, WHITE, 0.35), max(0.0, min(1.0, (p.z + h * 0.6) / (h * 1.6)))))
    return g.move(*pos)


@kit.prop('bush_a', tags=['bush'])
def bush_a():
    g = merge(gblob(0.56, (1.15, 1.0, 0.80), 0.0, 0.05, 21), gblob(0.40, (1.1, 1.0, 0.82), 0.56, -0.16, 22),
              gblob(0.32, (1.1, 1.0, 0.85), -0.52, -0.1, 23))
    leafy(g, seed=4)
    sp = merge(spike((0.1, -0.1, 0.72), (0.2, -0.22, 1.02), 0.09, 0.4), spike((-0.2, 0.1, 0.7), (-0.42, 0.16, 0.96), 0.08, 2.0),
               spike((0.62, -0.2, 0.5), (0.9, -0.3, 0.7), 0.07, 1.0))
    sp.color(mixc(LEAF_M, LEAF_L, 0.75))
    return ao(merge(g, sp), 0.55, dist=0.5)


@kit.prop('bush_b', tags=['bush', 'blossom'])
def bush_b():
    # moita baixa e larga salpicada de botoes cor-de-rosa
    g = merge(gblob(0.46, (1.3, 1.05, 0.72), -0.1, 0.0, 31), gblob(0.36, (1.2, 1.0, 0.75), 0.52, 0.12, 32))
    leafy(g, dark=H('#2a8572'), mid=H('#3aa57c'), light=H('#7cc970'), seed=6)
    rnd = random.Random(3)
    buds = Geo()
    for x, y, z in ((-0.3, -0.32, 0.5), (0.05, -0.2, 0.62), (-0.42, 0.1, 0.6), (0.5, -0.12, 0.5), (0.72, 0.2, 0.44), (0.2, 0.3, 0.6), (-0.05, 0.1, 0.66)):
        buds.add(gem((x, y, z * 0.72 - 0.03), 0.085, 0.07, col=PINK, tip=H('#ffd3e0'), phase=rnd.random()))
    return ao(merge(g, buds), 0.55, dist=0.5)


@kit.prop('grass_a', tags=['grass'])
def grass_a():
    return tuft([(0.0, 0.0, 0.42, 0.07, 10, 0.12, True), (0.09, 0.05, 0.34, 0.065, 150, 0.12, True), (-0.08, 0.04, 0.26, 0.055, -100, 0.09, False),
                 (0.03, -0.09, 0.22, 0.055, 60, 0.08, False), (-0.05, -0.06, 0.3, 0.055, -40, 0.1, False), (0.1, -0.05, 0.18, 0.05, 220, 0.07, False)], seed=1)


@kit.prop('grass_b', tags=['grass'])
def grass_b():
    # baixa e aberta, folhas largas
    return tuft([(0.0, 0.0, 0.24, 0.085, 0, 0.16, True), (0.07, 0.04, 0.2, 0.08, 120, 0.16, True), (-0.07, 0.03, 0.2, 0.08, 240, 0.15, True),
                 (0.0, -0.06, 0.14, 0.06, 60, 0.1, False), (0.02, 0.07, 0.13, 0.06, 180, 0.1, False)], seed=2,
                c0=H('#2a8572'), c1=mixc(LEAF_M, LEAF_L, 0.6))


@kit.prop('grass_c', tags=['grass'])
def grass_c():
    # alta e fina com pontas douradas
    return tuft([(0.0, 0.0, 0.62, 0.05, 20, 0.14, True), (0.06, 0.03, 0.5, 0.05, 170, 0.12, True), (-0.05, 0.03, 0.44, 0.045, -80, 0.14, True),
                 (0.02, -0.05, 0.3, 0.045, 80, 0.08, False), (-0.04, -0.04, 0.24, 0.045, -30, 0.07, False), (0.07, -0.03, 0.2, 0.04, 250, 0.06, False)],
                seed=3, c0=LEAF_D, c1=mixc(LEAF_L, GOLD, 0.55))


def _head(r, n=5, col=PINK, core=GOLD, droop=0.28, mat='vcol', notch=0.42):
    """Corola vista de cima: leque de petalas pontudas, levemente caidas, com miolo."""
    g = Geo()
    c = g.add_vert((0, 0, r * 0.10), None, mixc(col, WHITE, 0.35))
    ring = []
    for i in range(n * 2):
        a = TAU * i / (n * 2)
        tipp = i % 2 == 0
        rr = r if tipp else r * notch
        ring.append(g.add_vert((math.cos(a) * rr, math.sin(a) * rr, -r * droop if tipp else 0.0), None,
                               col if tipp else mul(col, (0.82, 0.78, 0.92))))
    for i in range(n * 2):
        g.add_face((c, ring[i], ring[(i + 1) % (n * 2)]), mat, False)
    g.add(spike((0, 0, r * 0.06), (0, 0, r * 0.42), r * 0.26, 0.3, None, 1.0, 4, 'vcol').color(core))
    return g


def _stem(base, top, w=0.014, col=LEAF_D, bend=(0.0, 0.0)):
    mid = ((base[0] + top[0]) / 2 + bend[0], (base[1] + top[1]) / 2 + bend[1], (base[2] + top[2]) / 2)
    g = spike(base, top, w, 0.0, mid, 1.0, 3, 'vcol_wind', midw=0.9)
    g.color(col).grad('z', base[2], top[2], (0.7, 0.75, 0.9), WHITE)
    return g


def _base_leaves(specs, col=LEAF_M, size=0.2):
    g = Geo()
    for x, y, yaw, sz in specs:
        lf = leaf((0, 0, 0), size * sz, lift=0.0, col=col, two_sided=True, wide=0.36)
        lf.rot('X', -62).rot('Z', yaw).move(x, y, 0.02)
        g.add(lf)
    return g


@kit.prop('flower_a', tags=['flower', 'pink'])
def flower_a():
    g = Geo()
    for x, y, h, r, tx, ty, yaw in ((0.0, 0.0, 0.36, 0.10, 14, -10, 0), (0.13, -0.06, 0.25, 0.085, -16, 12, 40), (-0.1, -0.09, 0.19, 0.075, 12, 20, 80)):
        hd = _head(r, 5, PINK, GOLD).rot('Z', yaw).rot('X', tx).rot('Y', ty).move(x + ty * 0.004, y - tx * 0.004, h)
        g.add(_stem((x, y, 0), (x + ty * 0.004, y - tx * 0.004, h), 0.014))
        g.add(hd)
    g.add(_base_leaves([(0.03, 0.03, 30, 1.0), (-0.03, 0.0, 200, 0.9)]))
    return g


def _bud(r, n=5, col=CREAM, base=H('#c9d4ff')):
    g = lathe([(0.0, 0.0), (0.78 * r, 0.45 * r), (r, 1.3 * r), (0.62 * r, 2.05 * r), (0.0, 2.3 * r)], n, 'vcol', smooth=False)
    g.tint(lambda p, c: mixc(base, col, min(1.0, p.z / (1.6 * r))))
    return g


@kit.prop('flower_b', tags=['flower', 'white'])
def flower_b():
    # sinos brancos de base azulada
    g = Geo()
    for x, y, h, r, tx, ty, n in ((0.0, 0.0, 0.34, 0.058, 16, 8, 5), (-0.12, 0.05, 0.24, 0.05, -10, -22, 4), (0.1, 0.08, 0.17, 0.044, -20, 16, 4)):
        g.add(_stem((x, y, 0), (x + ty * 0.003, y - tx * 0.003, h), 0.013))
        g.add(_bud(r, n).rot('X', tx).rot('Y', ty).move(x + ty * 0.003, y - tx * 0.003, h - 0.01))
    g.add(_base_leaves([(0.02, -0.03, -20, 1.25), (-0.02, 0.02, 150, 1.1)], col=H('#3a9d80')))
    return g


@kit.prop('flower_c', tags=['flower', 'glow', 'lumen'])
def flower_c():
    # flor-estrela de lumen: petalas emissivas, dois botoes
    g = Geo()
    hx, hy, hz = 0.05, -0.03, 0.34
    g.add(_stem((0, 0, 0), (hx, hy, hz), 0.016, col=LEAF_DEEP, bend=(-0.04, 0.02)))
    hd = _head(0.13, 6, LUMEN, WHITE, droop=-0.22, mat='glow', notch=0.36)
    hd.fm = ['glow'] * len(hd.fm)
    hd.tint(lambda p, c: mul(c, (0.55, 0.85, 0.95)) if p.z < 0.012 and abs(p.x) + abs(p.y) < 0.09 else c)
    g.add(hd.rot('X', 22).rot('Y', 10).move(hx, hy, hz))
    for x, y, h in ((-0.1, -0.06, 0.17), (0.09, 0.09, 0.12)):
        g.add(_stem((x * 0.3, y * 0.3, 0), (x, y, h), 0.011, col=LEAF_DEEP))
        g.add(gem((x, y, h + 0.02), 0.032, 0.07, 'glow', col=LUMEN, n=4))
    g.add(_base_leaves([(0.03, 0.0, -40, 1.2), (-0.03, 0.03, 120, 1.0)], col=H('#237a78')))
    return g


def shroom(x, y, h, r, seed=0, n=6, cap=H('#2f86b8'), cap_l=H('#63cfe0'), glow=LUMEN, tilt=(0.0, 0.0), dots=2, cone=0.55):
    """Cogumelo de lumen: chapeu fosco em cima, lamelas e aba emissivas, pintas de luz."""
    rnd = random.Random(seed)
    stem = stack([(0.0, 0.34 * r, 0.34 * r), (h * 0.55, 0.22 * r, 0.22 * r), (h + 0.02, 0.20 * r, 0.20 * r)], 5, cap_a=False, cap_b=False,
                 phase=rnd.random()).flat()
    stem.color(H('#e6dcf2')).grad('z', 0, h, (0.62, 0.62, 0.9), (1.0, 0.98, 0.95))
    ph = rnd.random()
    top = lathe([(0.86 * r, h + 0.20 * r), (0.56 * r, h + 0.42 * r * cone / 0.55), (0.0, h + r * cone)], n, 'vcol', phase=ph, smooth=False)
    top.tint(lambda p, c: mixc(cap_l, cap, max(0.0, min(1.0, (p.z - h - 0.2 * r) / (r * cone - 0.2 * r + 1e-6))) ** 0.7))
    facet(top, var=0.07, seed=seed, sun=0.05)
    under = lathe([(0.2 * r, h), (0.95 * r, h - 0.06 * r), (1.0 * r, h + 0.06 * r), (0.86 * r, h + 0.20 * r)], n, 'glow', phase=ph, smooth=False)
    under.tint(lambda p, c: mixc(mul(glow, (0.45, 0.75, 0.85)), glow, min(1.0, math.hypot(p.x, p.y) / r)))
    g = merge(stem, top, under)
    for i in range(dots):
        a = rnd.uniform(0, TAU)
        rr = r * rnd.uniform(0.3, 0.5)
        zz = h + r * cone - (rr / (0.56 * r)) * (r * cone - 0.42 * r * cone / 0.55) if rr < 0.56 * r else h + 0.3 * r
        g.add(gem((math.cos(a) * rr, math.sin(a) * rr, zz + 0.012), r * 0.13, r * 0.06, 'glow', col=glow, n=4, phase=rnd.random()))
    g.rot('X', tilt[0]).rot('Y', tilt[1])
    return g.move(x, y, 0)


@kit.prop('mushroom_a', tags=['mushroom', 'glow'], light=dict(color='#7df9ff', energy=0.9, height=0.4, range=3.2))
def mushroom_a():
    g = merge(shroom(0.0, 0.02, 0.40, 0.25, seed=1, n=7, tilt=(6, -5), dots=3),
              shroom(0.27, -0.12, 0.22, 0.165, seed=2, n=6, tilt=(-8, 12), dots=2),
              shroom(-0.2, -0.16, 0.13, 0.12, seed=3, n=5, tilt=(10, -14), dots=1))
    g.add(tuft([(-0.22, 0.14, 0.2, 0.05, 200, 0.07, False), (0.2, 0.16, 0.16, 0.05, 150, 0.06, False)], seed=1))
    return ao(g, 0.5, dist=0.3)


@kit.prop('mushroom_b', tags=['mushroom', 'glow'], light=dict(color='#9fe8ff', energy=0.8, height=0.5, range=3.0))
def mushroom_b():
    # chapeus pontudos violeta, mais altos e finos
    V, VL = H('#5b55b5'), H('#9a8fe6')
    g = merge(shroom(0.02, 0.0, 0.52, 0.17, seed=11, n=6, cap=V, cap_l=VL, tilt=(-7, 6), dots=2, cone=0.95),
              shroom(-0.2, -0.1, 0.32, 0.13, seed=12, n=5, cap=V, cap_l=VL, tilt=(8, -12), dots=1, cone=0.95),
              shroom(0.2, -0.14, 0.2, 0.10, seed=13, n=5, cap=V, cap_l=VL, tilt=(12, 14), dots=1, cone=0.9),
              shroom(0.12, 0.2, 0.11, 0.075, seed=14, n=5, cap=V, cap_l=VL, tilt=(-14, 6), dots=0, cone=0.9))
    return ao(g, 0.5, dist=0.3)


def frond(length, width, yaw, arch=0.3, droop=0.15, seg=3, c0=LEAF_D, c1=LEAF_L, mat='vcol_wind', lift=0.3):
    """Folha de samambaia: tira arqueada com nervura alta no meio, dupla face."""
    g = Geo()
    prof = [0.38, 1.0, 0.72, 0.0] if seg == 3 else [0.4, 0.9, 1.0, 0.6, 0.0]
    rows = []
    for i in range(seg + 1):
        t = i / seg
        y = length * t
        z = arch * math.sin(t * math.pi * 0.62) * 1.25 + lift * length * t - droop * t * t * 1.6
        w = width * prof[i]
        col = mixc(c0, c1, t ** 0.8)
        if i == seg:
            rows.append([g.add_vert((0, y, z), None, col)])
        else:
            rows.append([g.add_vert((-w, y, z - w * 0.35), None, mul(col, (1.06, 1.06, 0.98))), g.add_vert((0, y, z), None, mul(col, (0.82, 0.86, 0.96))),
                         g.add_vert((w, y, z - w * 0.35), None, mul(col, (1.06, 1.06, 0.98)))])
    for a, b in zip(rows, rows[1:]):
        if len(b) == 3:
            quads = [(a[0], a[1], b[1], b[0]), (a[1], a[2], b[2], b[1])]
        else:
            quads = [(a[0], a[1], b[0]), (a[1], a[2], b[0])]
        for q in quads:
            g.add_face(q, mat, False)
            g.add_face(tuple(reversed(q)), mat, False)
    g.rot('Z', yaw - 90)
    return g


@kit.prop('fern_a', tags=['fern'])
def fern_a():
    g = Geo()
    for i, (ln, w, yaw, arch) in enumerate(((0.72, 0.15, 10, 0.26), (0.6, 0.14, 75, 0.22), (0.78, 0.15, 140, 0.3), (0.55, 0.13, 200, 0.2),
                                            (0.7, 0.15, 262, 0.26), (0.5, 0.12, 320, 0.2))):
        g.add(frond(ln, w, yaw, arch, droop=0.16, c0=H('#27807a'), c1=mixc(LEAF_M, LEAF_L, 0.7)))
    g.add(spike((0, 0, 0), (0.03, 0.02, 0.4), 0.035, 0.5, (0.0, 0.0, 0.2)).color(mixc(LEAF_L, GOLD, 0.3)))
    return g


@kit.prop('reed_a', tags=['reed'])
def reed_a():
    g = Geo()
    rnd = random.Random(4)
    for x, y, h, lean, yaw, head in ((0.0, 0.0, 1.25, 0.10, 20, True), (0.1, 0.06, 1.0, 0.16, 140, True), (-0.09, 0.05, 0.86, 0.14, 250, False),
                                     (0.04, -0.1, 0.7, 0.12, 80, False), (-0.06, -0.08, 1.08, 0.08, 300, True)):
        a = math.radians(yaw)
        tip = (x + math.cos(a) * lean, y + math.sin(a) * lean, h)
        st = spike((x, y, 0), tip, 0.022, a, (x + math.cos(a) * lean * 0.3, y + math.sin(a) * lean * 0.3, h * 0.5), 1.0, 3, 'vcol_wind', midw=0.85)
        st.tint(lambda p, c: mixc(LEAF_D, mixc(LEAF_M, LEAF_L, 0.5), min(1.0, p.z / 1.2)))
        g.add(st)
        if head:
            hd = stack([(0.0, 0.02, 0.02), (0.04, 0.042, 0.042), (0.2, 0.042, 0.042), (0.25, 0.012, 0.012)], 4, 'vcol_wind', phase=rnd.random()).flat()
            hd.tint(lambda p, c: mixc(H('#6b4a5a'), H('#a8705a'), min(1.0, p.z / 0.25)))
            hd.rot('Y', math.degrees(math.cos(a) * lean * 0.6)).rot('X', -math.degrees(math.sin(a) * lean * 0.6))
            g.add(hd.move(tip[0] * 0.86 + x * 0.14, tip[1] * 0.86 + y * 0.14, h * 0.74))
    for yaw, ln in ((40, 0.8), (190, 0.7), (285, 0.62)):
        g.add(frond(ln, 0.05, yaw, 0.1, droop=0.3, lift=0.95, c0=LEAF_D, c1=LEAF_L))
    return g


# =========================================================================== CHAO E LUZES
def slab(poly, th=0.04, inset=0.035, z0=0.0):
    """Laje de piso: contorno xy (anti-horario), topo um pouco menor (chanfro)."""
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    lo = [(x, y, z0) for x, y in poly]
    hi = []
    for x, y in poly:
        d = math.hypot(x - cx, y - cy) or 1.0
        hi.append((x - (x - cx) / d * inset, y - (y - cy) / d * inset, z0 + th))
    return loft([lo, hi], cap_a=False, cap_b='flat', smooth=False)


def tile_paint(g, seed=0, moss_fn=None, base=STONE):
    rnd = random.Random(seed)

    def fn(n, cen, c):
        if n.z > 0.7:
            col = mixc(base, STONE_L, 0.35)
            if moss_fn is not None and moss_fn(cen):
                col = mixc(col, MOSS, 0.8)
            return mul(c, col)
        return mul(c, STONE_D)
    return facet(g, fn=fn, var=0.05, seed=seed, sun=0.0, under=WHITE)


@kit.prop('tile_a', tags=['tile'])
def tile_a():
    # laje grande rachada em duas
    a = slab([(-0.64, -0.38), (-0.2, -0.67), (0.08, -0.64), (-0.03, -0.05), (-0.23, 0.62), (-0.62, 0.3)])
    b = slab([(0.14, -0.63), (0.44, -0.6), (0.7, -0.12), (0.52, 0.5), (-0.16, 0.64), (0.03, -0.02)], th=0.045)
    b.rot('Y', 1.2)
    a.color((1.0, 1.0, 1.0))
    b.color((0.93, 0.93, 0.98))
    g = tile_paint(merge(a, b), 1, lambda c: c.x + c.y * 0.5 < -0.55)
    g.add(tuft([(0.02, -0.3, 0.1, 0.03, 20, 0.03, False), (-0.08, 0.2, 0.08, 0.03, 200, 0.03, False)], seed=1))
    return ao(g, 0.45, dist=0.15)


@kit.prop('tile_b', tags=['tile'])
def tile_b():
    # duas pedras menores e uma lasca
    a = slab([(-0.55, -0.2), (-0.12, -0.42), (0.1, -0.1), (-0.02, 0.32), (-0.42, 0.36)], th=0.045)
    b = slab([(0.16, -0.3), (0.52, -0.22), (0.56, 0.2), (0.2, 0.42), (0.06, 0.12)], th=0.04).color((0.92, 0.92, 0.98))
    c = slab([(-0.05, -0.58), (0.2, -0.56), (0.16, -0.4), (-0.02, -0.44)], th=0.03, inset=0.02).color((1.04, 1.02, 1.0))
    g = tile_paint(merge(a, b, c), 2, lambda c: c.y > 0.3 and c.x < 0)
    return ao(g, 0.45, dist=0.15)


@kit.prop('tile_c', tags=['tile'])
def tile_c():
    # pedra redonda entalhada com um anel (resto de um piso cerimonial)
    n = 9
    rnd = random.Random(7)
    rr = [0.6 * rnd.uniform(0.93, 1.05) for _ in range(n)]

    def ring(k, z, dk=0.0):
        return [(math.cos(TAU * (i + 0.2) / n) * (rr[i] * k - dk), math.sin(TAU * (i + 0.2) / n) * (rr[i] * k - dk), z) for i in range(n)]
    g = loft([ring(1.0, 0.0), ring(1.0, 0.03, 0.03), ring(0.70, 0.045), ring(0.64, 0.03), ring(0.50, 0.03), ring(0.44, 0.045)],
             cap_a=False, cap_b=True, smooth=False)
    g.keep_faces(lambda c: True)

    def fn(nrm, cen, c):
        d = math.hypot(cen.x, cen.y)
        if nrm.z < 0.6 and d > 0.5:
            return STONE_D
        if 0.26 < d < 0.36 or nrm.z < 0.9:
            return mixc(STONE_D, H('#514c78'), 0.6)
        col = mixc(STONE, STONE_L, 0.4)
        return mixc(col, MOSS, 0.8) if (cen.x > 0.2 and cen.y > 0.05 and d > 0.36) else col
    facet(g, fn=fn, var=0.05, seed=3, sun=0.0, under=WHITE)
    return ao(g, 0.45, dist=0.15)


@kit.prop('light_lantern', collider=('cyl', 0.4, 1.6), tags=['light', 'lantern'],
          light=dict(color='#ffc46b', energy=1.6, height=1.05, range=6.5))
def light_lantern():
    # lanterna de pedra, meio torta, com o fogo de ambar ainda aceso
    base, _ = chunk(0, 0, 0.0, 0.16, 0.86, 0.8, seed=2, n=6, taper=0.86, jit=0.05, sq=0.2)
    post = stack([(0.14, 0.2, 0.2), (0.24, 0.15, 0.15), (0.5, 0.17, 0.17), (0.74, 0.13, 0.13), (0.80, 0.26, 0.26)], 6, phase=0.2)
    plat = block(-0.33, 0.33, -0.33, 0.33, 0.80, 0.9, seed=3, j=0.012, chips=(1,), chip=0.08)
    posts = Geo()
    for sx in (-1, 1):
        for sy in (-1, 1):
            posts.add(block(sx * 0.25 - 0.045, sx * 0.25 + 0.045, sy * 0.25 - 0.045, sy * 0.25 + 0.045, 0.9, 1.26, seed=5 + sx + 2 * sy, j=0.006))
    roof = lathe([(0.50, 1.24), (0.47, 1.31), (0.20, 1.50), (0.07, 1.54), (0.10, 1.62), (0.0, 1.70)], 4, phase=0.5, smooth=False)
    roof.warp(lambda p: Vector((p.x, p.y, p.z + (0.07 if (abs(p.x) > 0.3 and p.z < 1.35) else 0.0))))
    stone = merge(base, post, plat, posts, roof)
    _wall_paint(stone, 4, 1.7, moss=0.55)
    fire = box(0.36, 0.36, 0.36, 'glow', center=(0, 0, 1.08))
    fire.color(AMBER).grad('z', 0.9, 1.26, (1.0, 0.62, 0.38), (1.0, 1.0, 0.9))
    g = merge(stone, fire)
    g.rot('Y', 2.5).rot('X', -1.5)
    g.add(tuft([(0.4, -0.3, 0.26, 0.06, 20, 0.08, True), (0.48, -0.2, 0.18, 0.05, 90, 0.06, False), (-0.42, 0.2, 0.2, 0.05, 200, 0.06, False)], seed=6))
    return ao(g, 0.6, dist=0.5)


@kit.prop('light_flower', collider=('cyl', 0.2, 1.8), tags=['light', 'lumen'],
          light=dict(color='#7df9ff', energy=1.4, height=1.35, range=5.5))
def light_flower():
    # flor-lampiao de lumen: haste que se curva e um sino de luz pendurado
    stalk = tube([(0, 0, -0.05), (0.05, 0.0, 0.6), (-0.07, 0.0, 1.2), (0.06, -0.02, 1.64), (0.30, -0.05, 1.84), (0.52, -0.08, 1.72)],
                 [0.09, 0.072, 0.06, 0.05, 0.04, 0.03], 5, cap_a=False).flat()
    stalk.tint(lambda p, c: mixc(H('#1f6068'), LEAF_M, min(1.0, max(0.0, p.z / 1.8))))
    facet(stalk, var=0.05, seed=2)
    bx, by = 0.56, -0.08
    bell = lathe([(0.26, 1.20), (0.19, 1.27), (0.17, 1.46), (0.075, 1.60), (0.0, 1.68)], 6, 'glow', smooth=False)
    bell.tint(lambda p, c: mixc(mixc(LUMEN, WHITE, 0.15), mul(LUMEN, (0.25, 0.6, 0.78)), min(1.0, max(0.0, (p.z - 1.2) / 0.42))))
    mouth = lathe([(0.0, 1.30), (0.19, 1.26)], 6, 'glow', smooth=False).color(mixc(LUMEN, WHITE, 0.5))
    drop = gem((0, 0, 1.12), 0.045, 0.1, 'glow', col=LUMEN, n=4)
    calyx = lathe([(0.11, 1.52), (0.09, 1.62), (0.03, 1.72)], 5, 'vcol', smooth=False).color(LEAF_D)
    head = merge(bell, mouth, drop, calyx)
    head.rot('Y', 10, (0, 0, 1.7)).move(bx, by, 0.02)
    lv = Geo()
    for yaw, ln, w in ((20, 0.75, 0.2), (150, 0.62, 0.18), (255, 0.7, 0.2)):
        lv.add(frond(ln, w, yaw, 0.28, droop=0.2, c0=H('#237a78'), c1=mixc(LEAF_M, LEAF_L, 0.5), lift=0.35))
    lf = leaf((0, 0, 0), 0.34, lift=0.2, col=LEAF_M, two_sided=True).rot('X', -100).rot('Z', 200).move(-0.04, 0.02, 1.0)
    bud = gem((-0.26, 0.06, 0.92), 0.06, 0.13, 'glow', col=mul(LUMEN, (0.5, 0.8, 0.9)), n=5)
    bstem = tube([(-0.02, 0.0, 0.62), (-0.2, 0.04, 0.78), (-0.26, 0.06, 0.88)], [0.03, 0.025, 0.02], 3, cap_a=False).flat().color(LEAF_D)
    g = merge(stalk, calyx if False else Geo(), lv, lf, bstem, head, bud)
    return ao(g, 0.5, dist=0.5)


# =========================================================================== TRONCOS
WOOD_CUT = H('#d7ab86')
WOOD_RING = H('#b98263')


def cut_face(r, n=8, phase=0.0, hollow=0.0, bark_c=BARK_D, rr=None):
    """Topo cortado de um tronco (plano z=0, olhando para +Z): casca, lenho claro, anel e miolo.
    hollow > 0 afunda o miolo (tronco oco). rr = raios por vertice (irregular)."""
    rr = rr or [r] * n
    pts = ring_pts(n, 1.0, 1.0, 0.0, phase)
    g = Geo()

    def ring(k, z, col):
        return [g.add_vert((x * rr[i] * k, y * rr[i] * k, z), None, col) for i, (x, y) in enumerate(pts)]
    for k0, k1, z0, z1, col in ((1.0, 0.84, 0.0, 0.0, bark_c), (0.84, 0.5, 0.0, 0.0, WOOD_CUT), (0.5, 0.38, 0.0, 0.0, WOOD_RING)):
        a, b = ring(k0, z0, col), ring(k1, z1, col)
        for i in range(n):
            j = (i + 1) % n
            g.add_face((a[i], a[j], b[j], b[i]), 'vcol', False)
    core = H('#3b2a48') if hollow else WOOD_CUT
    a = ring(0.38, 0.0, core)
    c = g.add_vert((0, 0, -hollow), None, mul(core, (0.7, 0.7, 0.8)) if hollow else core)
    for i in range(n):
        g.add_face((a[i], a[(i + 1) % n], c), 'vcol', False)
    return g


@kit.prop('log_a', collider=('box', 2.7, 0.9, 0.7), tags=['log', 'fallen'])
def log_a():
    n = 8
    L = 2.5
    body = stack([(0.0, 0.37, 0.35), (0.8, 0.35, 0.34, 0.03, 0.0), (1.7, 0.33, 0.32, -0.02, 0.02), (L, 0.31, 0.30, 0.02, 0.0)], n,
                 cap_a=False, cap_b=False, phase=0.1)
    body.color(BARK_D)
    end_a = cut_face(0.36, n, 0.1, hollow=0.3).rot('X', 180).warp(lambda p: Vector((p.x, p.y * 0.95, p.z)))
    end_b = cut_face(0.305, n, 0.1).move(0.02, 0, L)
    stubb = tube([(0.0, 0.26, 1.5), (0.02, 0.5, 1.56), (0.0, 0.62, 1.62)], [0.11, 0.09, 0.07], 5).color(BARK_L)
    g = merge(body, end_a, end_b, stubb)
    g.rot('Y', 90).rot('Z', 6).move(-L / 2, 0.02, 0.30)

    def fn(nrm, cen, c):
        if c[0] > 0.3 and c[1] > 0.2:      # lenho cortado: nao mexe
            return c
        if nrm.z > 0.62 and (math.sin(cen.x * 2.6 + 1.0) > -0.35):
            return MOSS
        return mul(c, mixc((0.8, 0.78, 0.95), (1.2, 1.12, 1.0), max(0.0, min(1.0, 0.5 + 0.6 * nrm.dot(SUN)))))
    facet(g, fn=fn, var=0.06, seed=3, sun=0.0, under=(0.75, 0.72, 0.92))
    # orelhas-de-pau na lateral
    sh = Geo()
    for x, z, r in ((0.35, 0.36, 0.2), (0.55, 0.26, 0.14), (0.16, 0.24, 0.11)):
        pts = [(x + math.cos(a) * r, -0.3 - math.sin(a) * r * 0.9, z) for a in [math.pi * i / 4 for i in range(5)]]
        pts += [(x + math.cos(a) * r * 0.7, -0.3 - math.sin(a) * r * 0.6, z + r * 0.3) for a in [math.pi * i / 3 for i in range(4)]]
        pts += [(x, -0.26, z - r * 0.25)]
        f = hull(pts)
        facet(f, CREAM, H('#ffd9c2'), var=0.05, seed=int(x * 100), under=(0.75, 0.68, 0.85))
        sh.add(f)
    g.add(sh)
    g.add(tuft([(-0.8, -0.44, 0.34, 0.06, 0, 0.1, True), (-0.66, -0.48, 0.22, 0.05, 60, 0.07, False), (-0.92, -0.42, 0.2, 0.05, -40, 0.06, False),
                (0.9, 0.5, 0.3, 0.06, 180, 0.09, True), (1.02, 0.44, 0.2, 0.05, 220, 0.06, False)], seed=3))
    return ao(g, 0.6, dist=0.5)


@kit.prop('stump_a', collider=('cyl', 0.52, 0.65), tags=['log', 'stump'])
def stump_a():
    n = 8
    rnd = random.Random(6)
    rr = [0.43 * rnd.uniform(0.9, 1.12) for _ in range(n)]
    pts = ring_pts(n, 1.0, 1.0, 0.0, 0.2)

    def ring(k, z, lift=0.0):
        return [(x * rr[i] * k, y * rr[i] * k, z + (lift if i in (5, 6) else 0.0)) for i, (x, y) in enumerate(pts)]
    body = loft([ring(1.5, -0.03), ring(1.14, 0.16), ring(1.0, 0.42), ring(0.98, 0.6)], cap_a=False, cap_b=False)
    bark(merge(body), seed=2, z0=0, z1=0.6)
    wood = merge(body, roots(0.44, 5, seed=4, length=0.4, h=0.3, phase=0.3))
    bark(wood, seed=2, z0=0, z1=0.6)
    top = cut_face(0.43, n, 0.2, rr=[r * 0.98 for r in rr]).move(0, 0, 0.6)
    facet(top, var=0.04, seed=1, sun=0.0)
    # lasca que ficou em pe do lado onde a arvore quebrou
    sp = merge(spike((-0.26, -0.3, 0.58), (-0.3, -0.34, 1.02), 0.13, 0.9, None, 0.5), spike((-0.06, -0.38, 0.58), (-0.04, -0.4, 0.84), 0.1, 0.2, None, 0.5))
    sp.fm = ['vcol'] * len(sp.fm)
    sp.tint(lambda p, c: mixc(BARK_L, WOOD_CUT, min(1.0, max(0.0, (p.z - 0.58) / 0.4))))
    # broto novo
    sprout = merge(_stem((0.14, 0.1, 0.6), (0.2, 0.12, 0.86), 0.016, col=LEAF_M),
                   leaf((0.2, 0.12, 0.86), 0.2, col=mixc(LEAF_M, LEAF_L, 0.7), two_sided=True).rot('X', -110, (0.2, 0.12, 0.86)).rot('Z', 40, (0.2, 0.12, 0.86)),
                   leaf((0.2, 0.12, 0.84), 0.17, col=LEAF_L, two_sided=True).rot('X', -100, (0.2, 0.12, 0.84)).rot('Z', 220, (0.2, 0.12, 0.84)))
    moss = boulder(0.2, 0.16, 0.06, seed=3, n=6, top_r=0.6).move(0.1, -0.12, 0.6)
    facet(moss, MOSS, MOSS_L, var=0.06, seed=2)
    g = merge(wood, top, sp, sprout, moss)
    g.add(tuft([(0.6, -0.4, 0.3, 0.06, 20, 0.09, True), (0.7, -0.3, 0.2, 0.05, 80, 0.06, False), (-0.66, 0.36, 0.22, 0.05, 200, 0.07, False)], seed=8))
    return ao(g, 0.6, dist=0.5)


# =========================================================================== FUNDO
@kit.prop('backdrop_tree', tags=['backdrop', 'tree', 'glow'])
def backdrop_tree():
    # arvore anciã gigante: tronco torto, raizes grandes, copa em sete massas com flores de lumen
    t = limb([(0, 0, -0.1), (0.15, 0, 1.3), (-0.3, 0.1, 3.2), (0.1, 0, 5.2), (0.0, 0, 6.8)], [1.6, 1.1, 0.92, 0.8, 0.5], 9)
    wood = merge(
        t,
        limb([(0, 0, 5.0), (-1.6, 0.1, 6.4), (-3.2, 0.0, 7.7)], [0.5, 0.38, 0.2], 6),
        limb([(0.1, 0, 5.2), (1.6, -0.2, 6.6), (3.1, -0.3, 8.1)], [0.5, 0.36, 0.2], 6),
        limb([(0, 0, 6.2), (0.5, 0.3, 7.8), (0.3, 0.3, 9.3)], [0.45, 0.3, 0.18], 6),
        roots(1.35, 6, seed=2, length=1.7, h=1.5, n=5),
    )
    bark(wood, seed=3, z0=0, z1=8.0)
    spec = [(2.7, (1.25, 1.1, 0.70), (0.1, 0.1, 10.2), 41), (2.1, (1.2, 1.05, 0.72), (-3.6, 0.0, 8.5), 42),
            (2.2, (1.2, 1.05, 0.72), (3.5, -0.3, 8.9), 43), (1.7, (1.2, 1.0, 0.70), (0.5, -1.5, 8.2), 44),
            (1.5, (1.1, 1.0, 0.75), (-1.9, 0.3, 11.0), 45), (1.4, (1.1, 1.0, 0.75), (2.0, 0.2, 11.2), 46),
            (1.1, (1.2, 1.0, 0.70), (4.9, -0.2, 7.6), 47)]
    crown = merge(*[blob(r, sc, c, seed=sd) for r, sc, c, sd in spec])
    leafy(crown, dark=H('#27807a'), mid=LEAF_M, light=mixc(LEAF_M, LEAF_L, 0.75), deep=H('#1f6068'), seed=7)
    rnd = random.Random(11)
    glow = Geo()
    for i in range(18):
        r, sc, c, _ = spec[i % len(spec)]
        a = rnd.uniform(0, TAU)
        el = rnd.uniform(-0.1, 1.0)
        d = Vector((math.cos(a) * math.cos(el), -abs(math.sin(a) * math.cos(el)) if i % 3 else math.sin(a) * math.cos(el), math.sin(el)))
        pos = (c[0] + d.x * r * sc[0] * 0.97, c[1] + d.y * r * sc[1] * 0.97, c[2] + max(-0.38, d.z) * r * sc[2] * 0.97)
        col = LUMEN if i % 4 else H('#ffd0e6')
        glow.add(gem(pos, 0.17, 0.2, 'glow', col=col, n=4, phase=rnd.random()))
    for x, y, z, ln in ((-3.9, -0.6, 7.9, 1.9), (-2.4, -0.9, 7.6, 1.2), (1.2, -1.9, 7.6, 2.2), (3.0, -1.0, 8.0, 1.5), (4.8, -0.5, 7.2, 1.1)):
        st = tube([(x, y, z), (x + 0.05, y, z - ln * 0.5), (x, y, z - ln)], [0.035, 0.03, 0.02], 3, 'vcol_wind', cap_a=False).flat().color(LEAF_D)
        glow.add(st)
        glow.add(gem((x, y, z - ln - 0.12), 0.13, 0.2, 'glow', col=LUMEN, n=4))
    return ao(merge(wood, crown, glow), 0.6, dist=1.6)


@kit.prop('backdrop_tower', tags=['backdrop', 'ruin', 'glow'])
def backdrop_tower():
    # torre em ruinas: topo arrancado, cristais de lumen brotando da cratera, janelas ainda acesas
    n = 8
    body = merge(
        stack([(0.0, 2.15, 2.15), (0.5, 2.05, 2.05), (0.62, 1.9, 1.9)], n, phase=0.5),
        drum(0.6, 3.6, 1.82, 1.72, n, phase=0.5, ch=0.06),
        stack([(3.6, 1.86, 1.86), (3.8, 1.92, 1.92), (3.95, 1.74, 1.74)], n, phase=0.5),
        drum(3.95, 6.9, 1.66, 1.56, n, phase=0.5, off=(0.05, 0.0), ch=0.06),
        stack([(6.9, 1.70, 1.70), (7.08, 1.76, 1.76), (7.22, 1.58, 1.58)], n, phase=0.5),
        broken_drum(7.2, 9.7, 1.5, n, seed=4, jag=2.1, phase=0.5, off=(0.03, 0.0)),
    )
    stub = masonry([(0.0, 0.8, [1.8, 2.6, 3.5]), (0.8, 1.6, [1.8, 2.3, 3.2]), (1.6, 2.4, [1.8, 2.7])], -0.45, 0.45, seed=6, xlim=(-9, 9),
                   chip_top=lambda xc, z1: True, bevel=0.05)
    stone = merge(body, stub, rubble([(-2.5, -1.0, 0.9, 0.6, 0.5, 20, 12), (-1.9, -1.9, 0.6, 0.5, 0.4, -30, -10), (2.6, -1.2, 0.7, 0.5, 0.4, 40, 15)], seed=3))
    frames = Geo()
    panes = Geo()
    for yaw, z0, w in ((0, 4.5, 0.36), (45, 1.6, 0.32), (-45, 7.4, 0.3)):
        rr = 1.80 - 0.035 * z0
        y = -rr * math.cos(math.pi / 8) - 0.03
        pane = poly_extrude([(-w, z0), (w, z0), (w, z0 + 0.8), (w * 0.62, z0 + 1.12), (0, z0 + 1.26), (-w * 0.62, z0 + 1.12), (-w, z0 + 0.8)], 0.08, 'glow')
        pane.tint(lambda p, c, z0=z0: mixc(mul(LUMEN, (0.25, 0.6, 0.8)), LUMEN, min(1.0, max(0.0, (p.z - z0) / 1.26))))
        panes.add(pane.move(0, y, 0).rot('Z', yaw))
        fr = merge(arch_stones(0.0, z0 + 0.8, w, w + 0.22, y - 0.12, y + 0.2, n=5, seed=int(z0 * 10), key=0.06),
                   block(-w - 0.24, w + 0.24, y - 0.16, y + 0.2, z0 - 0.16, z0, seed=2, j=0.01),
                   block(-w - 0.2, -w, y - 0.1, y + 0.2, z0, z0 + 0.8, seed=3, j=0.01), block(w, w + 0.2, y - 0.1, y + 0.2, z0, z0 + 0.8, seed=4, j=0.01))
        frames.add(fr.rot('Z', yaw))
    stone.add(frames)
    _wall_paint(stone, 9, 9.7, moss=0.55)
    cr = merge(crystal(2.9, 0.52, 6, seed=1, lean=(0.05, -0.04), pos=(0.1, -0.1, 8.0)),
               crystal(2.0, 0.38, 5, seed=2, lean=(-0.3, 0.05), pos=(-0.55, 0.2, 7.9)),
               crystal(1.6, 0.32, 5, seed=3, lean=(0.36, -0.2), pos=(0.65, -0.4, 7.9)))
    yf = -1.5 * math.cos(math.pi / 8)
    g = merge(stone, panes, cr,
              ivy(-0.5, 8.2, 3.2, 1.3, yf - 0.1, seed=5, size=0.5, drift=0.3),
              ivy(0.5, 3.5, 2.4, 1.2, -1.72 * math.cos(math.pi / 8) - 0.1, seed=8, size=0.5, drift=-0.4),
              ivy(2.5, 2.5, 1.6, 0.9, -0.52, seed=3, size=0.42))
    return ao(g, 0.65, dist=1.4)



if __name__ == '__main__':
    kit.build()

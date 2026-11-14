"""lp.py: kit de modelagem low-poly para o Lumen (roda dentro do Blender / modulo bpy).

A ideia: montar a geometria em listas Python simples (classe Geo), com material por
face, cor por vertice (tinta/AO) e pesos de osso por vertice, e so no final virar um
objeto do Blender pronto para exportar em glTF.

Convencoes: Blender Z para cima, personagem olhando para -Y, lado esquerdo em +X.
"""
import math
import random

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

TAU = math.tau


# --------------------------------------------------------------------------- cores
def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexc(h):
    """'#rrggbb' (sRGB) -> tupla linear (r, g, b)."""
    h = h.lstrip('#')
    return tuple(srgb_to_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def mixc(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def mulc(a, k):
    return tuple(max(0.0, min(1.0, a[i] * k)) for i in range(3))


WHITE = (1.0, 1.0, 1.0)


# --------------------------------------------------------------------------- Geo
class Geo:
    def __init__(self):
        self.v = []    # Vector
        self.f = []    # tuplas de indices
        self.fm = []   # nome do material por face
        self.fsm = []  # face suave?
        self.w = []    # dict osso->peso por vertice
        self.c = []    # (r,g,b) linear por vertice

    # -- construcao basica
    def add_vert(self, p, w=None, c=WHITE):
        self.v.append(Vector(p))
        self.w.append(dict(w) if w else {})
        self.c.append(tuple(c))
        return len(self.v) - 1

    def add_face(self, idx, mat='vcol', smooth=True):
        self.f.append(tuple(idx))
        self.fm.append(mat)
        self.fsm.append(smooth)

    def copy(self):
        g = Geo()
        g.v = [p.copy() for p in self.v]
        g.f = list(self.f)
        g.fm = list(self.fm)
        g.fsm = list(self.fsm)
        g.w = [dict(w) for w in self.w]
        g.c = list(self.c)
        return g

    def add(self, other):
        """Anexa outra Geo (sem soldar vertices)."""
        if other is None:
            return self
        off = len(self.v)
        self.v += [p.copy() for p in other.v]
        self.w += [dict(w) for w in other.w]
        self.c += list(other.c)
        self.f += [tuple(i + off for i in f) for f in other.f]
        self.fm += list(other.fm)
        self.fsm += list(other.fsm)
        return self

    __iadd__ = add

    # -- transformacoes
    def xf(self, m):
        self.v = [m @ p for p in self.v]
        if m.to_3x3().determinant() < 0:
            self.f = [tuple(reversed(f)) for f in self.f]
        return self

    def move(self, x=0.0, y=0.0, z=0.0):
        d = Vector((x, y, z))
        self.v = [p + d for p in self.v]
        return self

    def scale(self, sx=1.0, sy=None, sz=None):
        sy = sx if sy is None else sy
        sz = sx if sz is None else sz
        return self.xf(Matrix.Diagonal((sx, sy, sz, 1.0)))

    def rot(self, axis, deg, pivot=(0, 0, 0)):
        pv = Vector(pivot)
        m = Matrix.Translation(pv) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-pv)
        return self.xf(m)

    def warp(self, fn):
        """fn(Vector) -> Vector, aplicado em cada vertice."""
        self.v = [Vector(fn(p)) for p in self.v]
        return self

    def mirrored(self):
        """Copia espelhada em X, trocando sufixos .L/.R dos ossos."""
        g = self.copy()
        g.xf(Matrix.Diagonal((-1, 1, 1, 1)))
        g.w = [{_swap_lr(b): w for b, w in ws.items()} for ws in g.w]
        return g

    def both(self):
        """Retorna self + espelho."""
        return self.copy().add(self.mirrored())

    # -- material / cor / pesos
    def mat(self, name):
        self.fm = [name] * len(self.f)
        return self

    def flat(self):
        self.fsm = [False] * len(self.f)
        return self

    def color(self, c):
        self.c = [tuple(c)] * len(self.v)
        return self

    def tint(self, fn):
        """fn(Vector, cor_atual) -> cor."""
        self.c = [tuple(fn(p, c)) for p, c in zip(self.v, self.c)]
        return self

    def grad(self, axis, lo, hi, c_lo, c_hi, power=1.0):
        """Gradiente multiplicativo ao longo de um eixo ('x','y','z')."""
        ai = 'xyz'.index(axis)

        def fn(p, c):
            t = 0.0 if hi == lo else max(0.0, min(1.0, (p[ai] - lo) / (hi - lo)))
            t = t ** power
            k = mixc(c_lo, c_hi, t)
            return (c[0] * k[0], c[1] * k[1], c[2] * k[2])
        return self.tint(fn)

    def autograd(self, c_lo=(0.72, 0.72, 0.78), c_hi=WHITE, axis='z', power=1.0):
        ai = 'xyz'.index(axis)
        vals = [p[ai] for p in self.v]
        return self.grad(axis, min(vals), max(vals), c_lo, c_hi, power)

    def bind(self, bone):
        self.w = [{bone: 1.0} for _ in self.v]
        return self

    def bind_fn(self, fn):
        """fn(Vector) -> dict osso->peso."""
        self.w = [_norm_w(fn(p)) for p in self.v]
        return self

    def bind_axis(self, axis, stops):
        """Pesos por faixa ao longo de um eixo. stops = [(valor, osso), ...] crescente;
        entre dois stops os pesos sao interpolados."""
        ai = 'xyz'.index(axis)

        def fn(p):
            x = p[ai]
            if x <= stops[0][0]:
                return {stops[0][1]: 1.0}
            for (a, ba), (b, bb) in zip(stops, stops[1:]):
                if x <= b:
                    t = (x - a) / (b - a) if b > a else 1.0
                    t = t * t * (3 - 2 * t)
                    if ba == bb:
                        return {ba: 1.0}
                    return {ba: 1.0 - t, bb: t}
            return {stops[-1][1]: 1.0}
        return self.bind_fn(fn)

    def keep_faces(self, fn):
        """Mantem so as faces em que fn(centroide) e verdadeiro e descarta vertices soltos."""
        keep = []
        for i, f in enumerate(self.f):
            c = sum((self.v[j] for j in f), Vector()) / len(f)
            if fn(c):
                keep.append(i)
        used = sorted({j for i in keep for j in self.f[i]})
        remap = {old: new for new, old in enumerate(used)}
        self.f = [tuple(remap[j] for j in self.f[i]) for i in keep]
        self.fm = [self.fm[i] for i in keep]
        self.fsm = [self.fsm[i] for i in keep]
        self.v = [self.v[j] for j in used]
        self.w = [self.w[j] for j in used]
        self.c = [self.c[j] for j in used]
        return self

    def flip(self):
        self.f = [tuple(reversed(f)) for f in self.f]
        return self

    def bounds(self):
        xs = [p.x for p in self.v]
        ys = [p.y for p in self.v]
        zs = [p.z for p in self.v]
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))

    def tris(self):
        return sum(len(f) - 2 for f in self.f)


def _swap_lr(name):
    if name.endswith('.L'):
        return name[:-2] + '.R'
    if name.endswith('.R'):
        return name[:-2] + '.L'
    return name


def _norm_w(ws):
    s = sum(ws.values())
    if s <= 0:
        return {}
    return {b: w / s for b, w in ws.items() if w > 1e-4}


def merge(*geos):
    g = Geo()
    for o in geos:
        g.add(o)
    return g


# --------------------------------------------------------------------------- primitivas
def ring_pts(n, rx, ry=None, square=0.0, phase=0.0):
    """Anel 2D (x,y) com n pontos. square: 0 = elipse, 1 = quase retangulo (superelipse)."""
    ry = rx if ry is None else ry
    pts = []
    e = 1.0 - 0.75 * square
    for i in range(n):
        a = TAU * (i + phase) / n
        c, s = math.cos(a), math.sin(a)
        x = math.copysign(abs(c) ** e, c) * rx
        y = math.copysign(abs(s) ** e, s) * ry
        pts.append((x, y))
    return pts


def loft(rings, mat='vcol', cap_a=True, cap_b=True, weights=None, colors=None, smooth=True, closed=True):
    """Liga aneis consecutivos (listas de pontos 3D com o mesmo tamanho).
    cap: True = tampa em leque com centro; 'flat' = n-gon; False = aberto.
    weights/colors: listas opcionais, uma entrada por anel."""
    g = Geo()
    n = len(rings[0])
    idx = []
    for ri, ring in enumerate(rings):
        row = []
        for p in ring:
            row.append(g.add_vert(p, weights[ri] if weights else None, colors[ri] if colors else WHITE))
        idx.append(row)
    m = n if closed else n - 1
    for a, b in zip(idx, idx[1:]):
        for i in range(m):
            j = (i + 1) % n
            g.add_face((a[i], a[j], b[j], b[i]), mat, smooth)

    def cap(row, ring, ri, flip):
        c = sum((Vector(p) for p in ring), Vector()) / n
        ci = g.add_vert(c, weights[ri] if weights else None, colors[ri] if colors else WHITE)
        for i in range(n):
            j = (i + 1) % n
            g.add_face((ci, row[j], row[i]) if flip else (ci, row[i], row[j]), mat, smooth)

    if cap_a == 'flat':
        g.add_face(tuple(reversed(idx[0])), mat, smooth)
    elif cap_a:
        cap(idx[0], rings[0], 0, True)
    if cap_b == 'flat':
        g.add_face(tuple(idx[-1]), mat, smooth)
    elif cap_b:
        cap(idx[-1], rings[-1], len(rings) - 1, False)
    return g


def stack(sections, n=8, mat='vcol', cap_a=True, cap_b=True, phase=0.0, smooth=True):
    """Loft vertical simples. sections = [(z, rx, ry, [cx, cy, square])...] de baixo para cima."""
    rings = []
    for s in sections:
        z, rx, ry = s[0], s[1], s[2]
        cx = s[3] if len(s) > 3 else 0.0
        cy = s[4] if len(s) > 4 else 0.0
        sq = s[5] if len(s) > 5 else 0.0
        rings.append([(cx + x, cy + y, z) for x, y in ring_pts(n, rx, ry, sq, phase)])
    return loft(rings, mat, cap_a, cap_b, smooth=smooth)


def lathe(profile, n=8, mat='vcol', phase=0.0, smooth=True):
    """Revolucao em torno de Z. profile = [(r, z), ...]; r == 0 nas pontas vira polo."""
    g = Geo()
    rows = []
    for r, z in profile:
        if r <= 1e-6:
            rows.append([g.add_vert((0, 0, z))])
        else:
            rows.append([g.add_vert((x, y, z)) for x, y in ring_pts(n, r, r, 0.0, phase)])
    for a, b in zip(rows, rows[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for i in range(n):
            j = (i + 1) % n
            if len(a) == 1:
                g.add_face((a[0], b[j], b[i]), mat, smooth)
            elif len(b) == 1:
                g.add_face((a[i], a[j], b[0]), mat, smooth)
            else:
                g.add_face((a[i], a[j], b[j], b[i]), mat, smooth)
    # profile sobe em z com face para fora: confere orientacao
    if profile[0][1] > profile[-1][1]:
        g.f = [tuple(reversed(f)) for f in g.f]
    return g


def ellipsoid(rx, ry, rz, n=8, rings=5, mat='vcol', center=(0, 0, 0), phase=0.0):
    prof = []
    for i in range(rings + 1):
        a = -math.pi / 2 + math.pi * i / rings
        prof.append((max(0.0, math.cos(a)), math.sin(a)))
    prof[0] = (0.0, -1.0)
    prof[-1] = (0.0, 1.0)
    g = lathe(prof, n, mat, phase)
    g.scale(rx, ry, rz)
    g.move(*center)
    return g


def box(sx, sy, sz, mat='vcol', center=(0, 0, 0), taper=1.0, smooth=False):
    """Caixa centrada. taper: escala do topo em relacao a base."""
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    g = Geo()
    pts = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
           (-hx * taper, -hy * taper, hz), (hx * taper, -hy * taper, hz),
           (hx * taper, hy * taper, hz), (-hx * taper, hy * taper, hz)]
    for p in pts:
        g.add_vert(p)
    for f in [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
        g.add_face(f, mat, smooth)
    g.move(*center)
    return g


def cyl(r, h, n=8, mat='vcol', r_top=None, center=(0, 0, 0), phase=0.0, smooth=True):
    r_top = r if r_top is None else r_top
    g = stack([(-h / 2, r, r), (h / 2, r_top, r_top)], n, mat, phase=phase, smooth=smooth)
    g.move(*center)
    return g


def cone(r, h, n=8, mat='vcol', center=(0, 0, 0), phase=0.0, smooth=True):
    g = lathe([(0.0, 0.0), (r, 0.0), (0.0, h)], n, mat, phase, smooth)
    g.move(*center)
    return g


def tube(path, radii, n=6, mat='vcol', cap_a=True, cap_b=True, up=(0, 0, 1), square=0.0, phase=0.0):
    """Tubo ao longo de pontos 3D. radii: numero, (rx, ry) ou lista por ponto."""
    pts = [Vector(p) for p in path]
    rings = []
    ref = Vector(up).normalized()
    prev_x = None
    for i, p in enumerate(pts):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == len(pts) - 1:
            t = pts[-1] - pts[-2]
        else:
            t = pts[i + 1] - pts[i - 1]
        t.normalize()
        if prev_x is None:
            x = ref.cross(t)
            if x.length < 1e-4:
                x = Vector((1, 0, 0)).cross(t)
        else:
            x = prev_x - t * prev_x.dot(t)
        x.normalize()
        y = t.cross(x)
        prev_x = x
        r = radii[i] if isinstance(radii, list) else radii
        rx, ry = (r, r) if isinstance(r, (int, float)) else r
        rings.append([p + x * a + y * b for a, b in ring_pts(n, rx, ry, square, phase)])
    return loft(rings, mat, cap_a, cap_b)


def poly_extrude(pts2d, depth, mat='vcol', smooth=False):
    """Extrude um poligono 2D (x, z) ao longo de Y (espessura centrada)."""
    g = Geo()
    n = len(pts2d)
    a = [g.add_vert((x, -depth / 2, z)) for x, z in pts2d]
    b = [g.add_vert((x, depth / 2, z)) for x, z in pts2d]
    g.add_face(tuple(a), mat, smooth)
    g.add_face(tuple(reversed(b)), mat, smooth)
    for i in range(n):
        j = (i + 1) % n
        g.add_face((a[j], a[i], b[i], b[j]), mat, smooth)
    # garante normais para fora (poligono anti-horario visto de -Y)
    area = sum(pts2d[i][0] * pts2d[(i + 1) % n][1] - pts2d[(i + 1) % n][0] * pts2d[i][1] for i in range(n))
    if area < 0:
        g.f = [tuple(reversed(f)) for f in g.f]
    return g


def sheet(rows, mat='vcol', two_sided_mat=None, thickness=0.0):
    """Malha em grade a partir de linhas de pontos (todas com o mesmo tamanho).
    Com thickness > 0 cria o verso (two_sided_mat) deslocado pela normal aproximada."""
    g = Geo()
    idx = [[g.add_vert(p) for p in row] for row in rows]
    for a, b in zip(idx, idx[1:]):
        for i in range(len(a) - 1):
            g.add_face((a[i], a[i + 1], b[i + 1], b[i]), mat)
    if thickness > 0.0:
        back = g.copy()
        normals = _vertex_normals(g)
        back.v = [p - nrm * thickness for p, nrm in zip(back.v, normals)]
        back.f = [tuple(reversed(f)) for f in back.f]
        if two_sided_mat:
            back.mat(two_sided_mat)
        nb = len(g.v)
        g.add(back)
        # fecha as bordas
        h, wd = len(rows), len(rows[0])
        border = [idx[0][i] for i in range(wd)] + [idx[r][wd - 1] for r in range(1, h)] + \
                 [idx[h - 1][i] for i in range(wd - 2, -1, -1)] + [idx[r][0] for r in range(h - 2, 0, -1)]
        for i in range(len(border)):
            a0, a1 = border[i], border[(i + 1) % len(border)]
            g.add_face((a1, a0, a0 + nb, a1 + nb), mat)
    return g


def _vertex_normals(g):
    ns = [Vector() for _ in g.v]
    for f in g.f:
        p0, p1, p2 = g.v[f[0]], g.v[f[1]], g.v[f[2]]
        nrm = (p1 - p0).cross(p2 - p0)
        for i in f:
            ns[i] += nrm
    return [n.normalized() if n.length > 1e-9 else Vector((0, 0, 1)) for n in ns]


def icosphere(r=1.0, subdiv=1, mat='vcol', center=(0, 0, 0), jitter=0.0, seed=0, smooth=False):
    """Icosfera (boa para pedras, copas de arvore, cristais facetados)."""
    t = (1 + 5 ** 0.5) / 2
    vs = [Vector(p).normalized() for p in [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t),
                                           (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]]
    fs = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6),
          (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10),
          (8, 6, 7), (9, 8, 1)]
    for _ in range(subdiv):
        cache = {}
        nf = []

        def mid(a, b):
            k = (min(a, b), max(a, b))
            if k not in cache:
                vs.append(((vs[a] + vs[b]) / 2).normalized())
                cache[k] = len(vs) - 1
            return cache[k]
        for a, b, c in fs:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            nf += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        fs = nf
    rnd = random.Random(seed)
    g = Geo()
    for p in vs:
        k = 1.0 + (rnd.uniform(-jitter, jitter) if jitter else 0.0)
        g.add_vert(p * r * k)
    for f in fs:
        g.add_face(f, mat, smooth)
    g.move(*center)
    return g


# --------------------------------------------------------------------------- utilidades de forma
def bend(axis_len, angle_deg, along='z', toward='y'):
    """Retorna funcao de warp que curva a geometria ao longo de um eixo."""
    ai = 'xyz'.index(along)
    ti = 'xyz'.index(toward)
    ang = math.radians(angle_deg)

    def fn(p):
        if abs(ang) < 1e-6:
            return p
        t = p[ai] / axis_len
        a = ang * t
        r = axis_len / ang
        q = Vector(p)
        d = p[ti]
        q[ai] = math.sin(a) * (r - d)
        q[ti] = r - math.cos(a) * (r - d)
        return q
    return fn


def noise_warp(amount, seed=0, freq=1.0):
    """Deslocamento pseudo-aleatorio coerente (soma de senos), barato e deterministico."""
    rnd = random.Random(seed)
    ph = [rnd.uniform(0, TAU) for _ in range(9)]
    fr = [rnd.uniform(0.7, 1.6) * freq for _ in range(9)]

    def fn(p):
        dx = math.sin(p.y * fr[0] + ph[0]) + math.sin(p.z * fr[1] + ph[1]) + math.sin((p.x + p.y) * fr[2] + ph[2])
        dy = math.sin(p.z * fr[3] + ph[3]) + math.sin(p.x * fr[4] + ph[4]) + math.sin((p.y + p.z) * fr[5] + ph[5])
        dz = math.sin(p.x * fr[6] + ph[6]) + math.sin(p.y * fr[7] + ph[7]) + math.sin((p.z + p.x) * fr[8] + ph[8])
        return p + Vector((dx, dy, dz)) * (amount / 3.0)
    return fn


def bake_ao(g, strength=0.6, dist=0.6, samples=24, seed=1, floor_z=None):
    """Oclusao de ambiente por vertice (raycast em BVH), multiplicada na cor."""
    polys = [list(f) for f in g.f]
    verts = [tuple(p) for p in g.v]
    if floor_z is not None:
        b0, b1 = g.bounds()
        e = 50.0
        base = len(verts)
        verts += [(-e, -e, floor_z), (e, -e, floor_z), (e, e, floor_z), (-e, e, floor_z)]
        polys.append([base, base + 1, base + 2, base + 3])
    bvh = BVHTree.FromPolygons(verts, polys)
    normals = _vertex_normals(g)
    rnd = random.Random(seed)
    dirs = []
    while len(dirs) < samples:
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
        if 0.05 < d.length <= 1.0:
            dirs.append(d.normalized())
    out = []
    for p, nrm, c in zip(g.v, normals, g.c):
        occ = 0.0
        tot = 0.0
        o = p + nrm * 0.004
        for d in dirs:
            k = d.dot(nrm)
            if k <= 0.05:
                continue
            tot += k
            hit = bvh.ray_cast(o, d, dist)
            if hit[0] is not None:
                occ += k * (1.0 - hit[3] / dist)
        a = 1.0 - strength * (occ / tot if tot > 0 else 0.0)
        out.append((c[0] * a, c[1] * a, c[2] * a))
    g.c = out
    return g


# --------------------------------------------------------------------------- Blender
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps = 30
    scn.unit_settings.system = 'METRIC'
    return scn


_MATS = {}

PREVIEW_COLORS = {
    'vcol': (1, 1, 1), 'skin': hexc('#f2c4a0'), 'hair': hexc('#6b4630'), 'primary': hexc('#3f7fd9'),
    'secondary': hexc('#f1e7d0'), 'accent': hexc('#f2b632'), 'metal': hexc('#b8c4d6'),
    'leather': hexc('#7a5236'), 'eye': hexc('#2a2233'), 'white': hexc('#ffffff'), 'dark': hexc('#2b2536'),
    'glow': hexc('#7df9ff'),
}


def get_mat(name):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    col = PREVIEW_COLORS.get(name.split('.')[0], (0.8, 0.8, 0.8))
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (*col, 1.0)
        bsdf.inputs['Roughness'].default_value = 0.9
    return m


def to_object(g, name, collection=None, sharp_angle=42.0):
    """Converte uma Geo em objeto mesh do Blender (materiais, cor de vertice, grupos)."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(p) for p in g.v], [], [list(f) for f in g.f])
    mats = []
    for m in g.fm:
        if m not in mats:
            mats.append(m)
    for m in mats:
        me.materials.append(get_mat(m))
    for poly, m, sm in zip(me.polygons, g.fm, g.fsm):
        poly.material_index = mats.index(m)
        poly.use_smooth = sm
    col = me.color_attributes.new('Color', 'FLOAT_COLOR', 'POINT')
    for i, c in enumerate(g.c):
        col.data[i].color = (c[0], c[1], c[2], 1.0)
    me.color_attributes.active_color = col
    me.color_attributes.render_color_index = 0
    me.update()
    me.validate()
    if any(g.fsm):
        me.set_sharp_from_angle(angle=math.radians(sharp_angle))
    ob = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(ob)
    bones = set()
    for ws in g.w:
        bones.update(ws.keys())
    for b in sorted(bones):
        vg = ob.vertex_groups.new(name=b)
        for i, ws in enumerate(g.w):
            if b in ws:
                vg.add([i], ws[b], 'REPLACE')
    return ob


def make_armature(name, bones):
    """bones = [(nome, pai|None, head, tail, roll_graus)]. Retorna o objeto armature."""
    arm = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for spec in bones:
        bname, parent, head, tail = spec[0], spec[1], spec[2], spec[3]
        roll = spec[4] if len(spec) > 4 else 0.0
        eb = arm.edit_bones.new(bname)
        eb.head = head
        eb.tail = tail
        eb.roll = math.radians(roll)
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    ob.select_set(False)
    return ob


def skin_to(mesh_ob, arm_ob):
    mesh_ob.parent = arm_ob
    mod = mesh_ob.modifiers.new('Armature', 'ARMATURE')
    mod.object = arm_ob
    # todo vertice precisa de peso: usa o primeiro osso como reserva
    return mesh_ob


def export_glb(path, objects=None, animations=True):
    bpy.ops.object.select_all(action='DESELECT')
    use_sel = False
    if objects:
        for o in objects:
            o.select_set(True)
        use_sel = True
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB', use_selection=use_sel,
        export_yup=True, export_apply=False,
        export_vertex_color='ACTIVE', export_all_vertex_colors=False,
        export_active_vertex_color_when_no_material=True,
        export_normals=True, export_tangents=False, export_materials='EXPORT',
        export_animations=animations, export_animation_mode='NLA_TRACKS',
        export_force_sampling=True, export_optimize_animation_size=False,
        export_skins=True, export_morph=False, export_extras=False,
        export_def_bones=False, export_rest_position_armature=True,
    )

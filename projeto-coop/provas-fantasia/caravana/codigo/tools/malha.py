# Utilitários de malha (bmesh) da prova Wickwain (adaptado da Tralha da Cheia). Cada peça vai para uma malha final
# com a cor base na cor de vértice (linear), pesos de osso e a casca de contorno (cópia deslocada pela normal,
# alfa da cor de vértice = espessura). O shader pintado_pela_luz faz todo o resto.
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler
import paleta as PAL

def srgb2lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def hexc(h, a=1.0):
    if not h.startswith('#'):
        h = PAL.P[h]
    h = h.lstrip('#')
    return tuple(srgb2lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (a,)

MATS = ['cor', 'metal', 'emis', 'contorno', 'olho']

def spec_of(paint):
    if isinstance(paint, str):
        return {'base': paint}
    return dict(paint)

class Builder:
    def __init__(self, seed, bones, outline=0.006):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new('Col')
        self.uv = self.bm.loops.layers.uv.new('UVMap')
        self.pc = self.bm.faces.layers.int.new('pc')
        self.dl = self.bm.verts.layers.deform.verify()
        self.groups = list(bones) + ['contorno']
        self.rng = random.Random(seed)
        self.outline = outline
        self.specs = []
        self.xf = {}      # osso -> (Matrix, escala): transforma as peças presas só a esse osso (cabeça maior e inclinada)

    def piece(self, tmp, paint='lona', bone='root', weights=None, jitter=0.0, smooth=False, oline=1.0,
              mat='cor', hull=True, uvfn=None, seg_keep=False, xfb=None):
        """paint: nome de cor da paleta ou dict {base, pat, c1, c2, s, axis, wear, ...} (ver pintura.py)."""
        uvv = {v: uvfn(v.co) for v in tmp.verts} if uvfn else None
        spec = spec_of(paint)
        key = xfb if xfb else (bone if weights is None else None)
        if key in self.xf:
            M, k = self.xf[key]
            xform(tmp, M)
            if spec.get('marks'):
                mk_ = []
                for m in spec['marks']:
                    if m[0] == 'traco':
                        mk_.append((m[0], [M @ Vector(q) for q in m[1]], m[2] * k, m[3]))
                    else:
                        mk_.append((m[0], M @ Vector(m[1]), m[2] * k, m[3]))
                spec['marks'] = mk_
            if 's' in spec:
                spec['s'] = spec['s'] * k
        if mat != 'olho':
            bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
        tmp.normal_update()
        if jitter > 0:  # cortes de faca: ruído com semente fixa ao longo da normal, por vértice
            for v in tmp.verts:
                v.co += v.normal * (self.rng.uniform(-1, 1) * jitter)
            tmp.normal_update()
        spec.setdefault('seed', self.rng.randint(0, 99999))
        self.specs.append(spec)
        pid = len(self.specs) - 1
        passes = [False, True] if (hull and oline > 0 and mat != 'olho') else [False]
        for is_hull in passes:
            vmap = {}
            for v in tmp.verts:
                co = v.co.copy()
                if is_hull:
                    co = co + v.normal * self.outline * oline
                nv = self.bm.verts.new(co)
                w = weights(v.co) if weights else {bone: 1.0}
                for b, ww in w.items():
                    if ww > 0:
                        nv[self.dl][self.groups.index(b)] = ww
                if is_hull:
                    nv[self.dl][self.groups.index('contorno')] = oline
                vmap[v] = nv
            for f in tmp.faces:
                try:
                    nf = self.bm.faces.new([vmap[v] for v in f.verts])
                except ValueError:
                    continue
                nf.material_index = MATS.index('contorno') if is_hull else MATS.index(mat)
                nf.smooth = True if is_hull else smooth
                nf[self.pc] = -1 if is_hull else (-2 if mat == 'olho' else pid)
                rgba = hexc('tinta', oline) if is_hull else hexc(spec['base'], spec.get('a', 1.0))
                uvs = [uvv[v] for v in f.verts] if (uvv and not is_hull) else None
                for i, lo in enumerate(nf.loops):
                    lo[self.col] = rgba
                    if uvs:
                        lo[self.uv].uv = uvs[i]
        tmp.free()
        return pid

# ------------------------------------------------------------------ primitivas
def mk(kind, **kw):
    bm = bmesh.new()
    if kind == 'sphere':
        bmesh.ops.create_uvsphere(bm, u_segments=kw.get('u', 10), v_segments=kw.get('v', 7), radius=1.0)
    elif kind == 'ico':
        bmesh.ops.create_icosphere(bm, subdivisions=kw.get('sub', 1), radius=1.0)
    elif kind == 'cube':
        bmesh.ops.create_cube(bm, size=2.0)
        if kw.get('cuts'):
            bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=kw['cuts'], use_grid_fill=True)
        if kw.get('bevel'):
            bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=kw['bevel'], segments=kw.get('bseg', 1), affect='EDGES')
    elif kind == 'cyl':
        bmesh.ops.create_cone(bm, cap_ends=True, segments=kw.get('seg', 8), radius1=kw.get('r1', 1.0), radius2=kw.get('r2', 1.0), depth=2.0)
    return bm

def place(bm, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0)):
    M = Matrix.Translation(loc) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4() @ Matrix.Diagonal((*scale, 1))
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm

def xform(bm, M):
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm

def seg(bm, a, b, r):
    """Cilindro unitário (eixo Z, -1..1) colocado entre a e b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    M = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((r, r, d.length / 2, 1))
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm

def se(t, n):
    """superelipse: devolve (x, y) unitários para o ângulo t e expoente n."""
    c, s = math.cos(t), math.sin(t)
    return (math.copysign(abs(c) ** (2 / n), c), math.copysign(abs(s) ** (2 / n), s))

def loft(rings, seg_n=16, cap_bot=True, cap_top=True, phase=0.0):
    """rings: lista de (z, meia-largura, meia-profundidade, desloc_y, expoente n[, desloc_x]).
    Seção superelíptica por anel. Cabeças e corpos por perfil desenhado (frente e lado)."""
    bm = bmesh.new()
    R = []
    for rg in rings:
        z, w, d, yo, n = rg[:5]
        xo = rg[5] if len(rg) > 5 else 0.0
        ring = []
        for j in range(seg_n):
            t = 2 * math.pi * j / seg_n + phase
            x, y = se(t, n)
            ring.append(bm.verts.new((xo + w * x, yo + d * y, z)))
        R.append(ring)
    for i in range(len(R) - 1):
        for j in range(seg_n):
            a, b = R[i][j], R[i][(j + 1) % seg_n]
            c, d = R[i + 1][(j + 1) % seg_n], R[i + 1][j]
            bm.faces.new([a, b, c, d])
    if cap_bot:
        z, w, d, yo, n = rings[0][:5]
        xo = rings[0][5] if len(rings[0]) > 5 else 0.0
        cv = bm.verts.new((xo, yo, z))
        for j in range(seg_n):
            bm.faces.new([cv, R[0][(j + 1) % seg_n], R[0][j]])
    if cap_top:
        z, w, d, yo, n = rings[-1][:5]
        xo = rings[-1][5] if len(rings[-1]) > 5 else 0.0
        cv = bm.verts.new((xo, yo, z))
        for j in range(seg_n):
            bm.faces.new([cv, R[-1][j], R[-1][(j + 1) % seg_n]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm

def tube(path, radii, seg_n=10, cap=True, n=2.0, flat=1.0):
    """Tubo ao longo de uma lista de pontos com raios por ponto (mangas, antenas, fitas, fios)."""
    bm = bmesh.new()
    path = [Vector(p) for p in path]
    R = []
    prev_n = None
    for i, p in enumerate(path):
        tg = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        if prev_n is None:
            up = Vector((0, 0, 1)) if abs(tg.z) < 0.9 else Vector((0, 1, 0))
            nx = tg.cross(up).normalized()
        else:
            nx = (prev_n - tg * prev_n.dot(tg)).normalized()
        ny = tg.cross(nx).normalized()
        prev_n = nx
        ring = []
        for j in range(seg_n):
            x, y = se(2 * math.pi * j / seg_n, n)
            ring.append(bm.verts.new(p + nx * x * radii[i] + ny * y * radii[i] * flat))
        R.append(ring)
    for i in range(len(R) - 1):
        for j in range(seg_n):
            bm.faces.new([R[i][j], R[i][(j + 1) % seg_n], R[i + 1][(j + 1) % seg_n], R[i + 1][j]])
    if cap:
        for ring, rev in ((R[0], True), (R[-1], False)):
            if len(ring) >= 3:
                c = bm.verts.new(sum((v.co for v in ring), Vector()) / len(ring))
                for j in range(seg_n):
                    vs = [c, ring[j], ring[(j + 1) % seg_n]]
                    bm.faces.new(vs[::-1] if rev else vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm

def axis_uv(a, b, rep=1.0, vs=2.0):
    """UV de tubo: u = ângulo em volta do eixo a->b, v = distância ao longo do eixo."""
    a, b = Vector(a), Vector(b)
    ax = (b - a).normalized()
    ref = Vector((0, 0, 1)) if abs(ax.z) < 0.9 else Vector((0, 1, 0))
    e1 = ax.cross(ref).normalized(); e2 = ax.cross(e1)
    def f(co):
        d = co - a
        u = (math.atan2(d.dot(e2), d.dot(e1)) / (2 * math.pi) + 0.5) * rep
        return (u, d.dot(ax) * vs)
    f.rep = rep
    return f

def cyl_uv(rep=2.0, vs=1.6, z0=0.0):
    def f(co):
        u = (math.atan2(co.x, -co.y) / (2 * math.pi) + 0.5) * rep
        return (u, (co.z - z0) * vs)
    f.rep = rep
    return f

def planar_uv(sx=1.0, sy=1.0, ox=0.0, oy=0.0, axes='xz'):
    def f(co):
        a = getattr(co, axes[0]); b = getattr(co, axes[1])
        return ((a - ox) * sx, (b - oy) * sy)
    return f

def bend(bm, axis_from='z', k=0.0, z0=0.0, toward='y'):
    """Curva uma peça ao longo de um eixo (chapéu caído, gorro curvado)."""
    for v in bm.verts:
        t = getattr(v.co, axis_from) - z0
        if t > 0:
            setattr(v.co, toward, getattr(v.co, toward) + k * t * t)
    return bm

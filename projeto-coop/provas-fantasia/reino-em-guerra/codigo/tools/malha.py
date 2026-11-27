# Utilitários de malha (bmesh) de "A Pequena Hoste". Cada peça entra na malha final com:
#  - cor de vértice: rgb = aguada (linear), a = quantidade de aguada (0 = só papel e tinta, como os mortos);
#  - UV = coordenadas de hachura em METROS, que seguem a forma da peça (em volta do eixo principal e ao longo dele),
#    para o buril andar em volta do volume e não na tela;
#  - UV2 = (densidade de hachura, semente da peça);
#  - pesos de osso e a casca de contorno (cópia deslocada pela normal; alfa = espessura).
import bpy, bmesh, math, random
import numpy as np
from mathutils import Vector, Matrix, Euler
import paleta as PAL

def srgb2lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def lin(name):
    r = PAL.rgb(name)
    return tuple(srgb2lin(v / 255) for v in r)

MATS = ['grav', 'contorno', 'plano', 'chama', 'verde']

class Builder:
    def __init__(self, seed, bones, outline=0.0085):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new('Col')
        self.uv = self.bm.loops.layers.uv.new('UVMap')
        self.uv2 = self.bm.loops.layers.uv.new('UV2')
        self.dl = self.bm.verts.layers.deform.verify()
        self.groups = list(bones) + ['contorno']
        self.rng = random.Random(seed)
        self.outline = outline
        self.n = 0
        self.xf = {}

    def piece(self, tmp, wash=None, amt=1.0, bone='root', weights=None, oline=1.0, mat='grav', hull=True,
              uv='auto', dens=1.0, smooth=True, jitter=0.0, axis=None):
        """wash: nome da paleta (aguada) ou None (só papel e tinta). mat: grav|plano|chama|verde.
        uv: 'auto' (cilíndrico no eixo principal, ou plano se a peça for chata), função co->(u,v), ou 'world'."""
        if weights is None and bone in self.xf:
            xform(tmp, self.xf[bone])
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
        tmp.normal_update()
        if jitter > 0:
            for v in tmp.verts:
                v.co += v.normal * (self.rng.uniform(-1, 1) * jitter)
            tmp.normal_update()
        self.n += 1
        seed = self.rng.random()
        uvf = auto_uv(tmp, axis) if uv == 'auto' else uv
        wc = lin(wash) if wash else (1.0, 1.0, 1.0)
        a = amt if wash else 0.0
        passes = [False, True] if (hull and oline > 0 and mat in ('grav', 'plano')) else [False]
        for is_hull in passes:
            vmap = {}
            for v in tmp.verts:
                co = v.co.copy()
                if is_hull:
                    co = co + v.normal * self.outline * oline * 0.25
                nv = self.bm.verts.new(co)
                w = weights(v.co) if weights else {bone: 1.0}
                for b, ww in w.items():
                    if ww > 0:
                        nv[self.dl][self.groups.index(b)] = ww
                vmap[v] = nv
            for f in tmp.faces:
                try:
                    nf = self.bm.faces.new([vmap[v] for v in f.verts])
                except ValueError:
                    continue
                nf.material_index = MATS.index('contorno') if is_hull else MATS.index(mat)
                nf.smooth = True if is_hull else smooth
                uvs = None
                if not is_hull and uvf is not None:
                    uvs = [uvf(v.co) for v in f.verts]
                    # costura do cilindro: a face que cruza o corte ganha +perímetro nas pontas negativas
                    per = getattr(uvf, 'per', 0.0)
                    if per > 0:
                        us = [q[0] for q in uvs]
                        if max(us) - min(us) > per * 0.5:
                            uvs = [(q[0] + per if q[0] < per * 0.5 else q[0], q[1]) for q in uvs]
                for i, lo in enumerate(nf.loops):
                    lo[self.col] = (0.137, 0.11, 0.09, oline) if is_hull else (wc[0], wc[1], wc[2], a)
                    if uvs:
                        lo[self.uv].uv = uvs[i]
                    lo[self.uv2].uv = (dens, seed)
        tmp.free()

def auto_uv(bm, axis=None):
    P = np.array([v.co[:] for v in bm.verts])
    if len(P) < 3:
        return None
    c = P.mean(0)
    Q = P - c
    w, V = np.linalg.eigh(Q.T @ Q / len(P))
    a0 = Vector(V[:, 2]) if axis is None else Vector(axis).normalized()
    if axis is None and w[0] < 0.02 * w[2] and w[1] > 0.08 * w[2]:
        # peça chata (escudo, bandeira, lâmina): plano dos dois eixos maiores
        e1, e2 = Vector(V[:, 2]), Vector(V[:, 1])
        cc = Vector(c)
        def f(co):
            d = co - cc
            return (d.dot(e2), d.dot(e1))
        f.per = 0.0
        return f
    ref = Vector((0, 0, 1)) if abs(a0.z) < 0.9 else Vector((0, 1, 0))
    # o corte do cilindro fica nas costas (+Y) sempre que possível
    e1 = a0.cross(ref).normalized()
    e2 = a0.cross(e1).normalized()
    cc = Vector(c)
    rad = float(np.mean([((Vector(p) - cc) - a0 * (Vector(p) - cc).dot(a0)).length for p in P])) + 1e-4
    back = Vector((0, 1, 0))
    if abs(a0.dot(back)) < 0.9:
        e1 = (back - a0 * back.dot(a0)).normalized()
        e2 = a0.cross(e1)
    def f(co):
        d = co - cc
        ang = math.atan2(d.dot(e2), d.dot(e1))  # corte em ang = ±pi, longe da frente
        ang = ang if ang >= 0 else ang + 2 * math.pi
        return (ang * rad, d.dot(a0))
    f.per = 2 * math.pi * rad
    return f

# ------------------------------------------------------------------ primitivas
def mk(kind, **kw):
    bm = bmesh.new()
    if kind == 'sphere':
        bmesh.ops.create_uvsphere(bm, u_segments=kw.get('u', 14), v_segments=kw.get('v', 9), radius=1.0)
    elif kind == 'ico':
        bmesh.ops.create_icosphere(bm, subdivisions=kw.get('sub', 2), radius=1.0)
    elif kind == 'cube':
        bmesh.ops.create_cube(bm, size=2.0)
        if kw.get('cuts'):
            bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=kw['cuts'], use_grid_fill=True)
        if kw.get('bevel'):
            bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=kw['bevel'], segments=kw.get('bseg', 2), affect='EDGES')
    elif kind == 'cyl':
        bmesh.ops.create_cone(bm, cap_ends=True, segments=kw.get('seg', 12), radius1=kw.get('r1', 1.0), radius2=kw.get('r2', 1.0), depth=2.0)
    return bm

def place(bm, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0)):
    M = Matrix.Translation(loc) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4() @ Matrix.Diagonal((*scale, 1))
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm

def xform(bm, M):
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm

def se(t, n):
    c, s = math.cos(t), math.sin(t)
    return (math.copysign(abs(c) ** (2 / n), c), math.copysign(abs(s) ** (2 / n), s))

def loft(rings, seg_n=16, cap_bot=True, cap_top=True, phase=0.0):
    """rings: (z, meia-largura x, meia-profundidade y, desloc_y, expoente n[, desloc_x])."""
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
            bm.faces.new([R[i][j], R[i][(j + 1) % seg_n], R[i + 1][(j + 1) % seg_n], R[i + 1][j]])
    for cap, ring, rg, rev in ((cap_bot, R[0], rings[0], True), (cap_top, R[-1], rings[-1], False)):
        if cap:
            xo = rg[5] if len(rg) > 5 else 0.0
            cv = bm.verts.new((xo, rg[3], rg[0]))
            for j in range(seg_n):
                vs = [cv, ring[(j + 1) % seg_n], ring[j]]
                bm.faces.new(vs if rev else vs[::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm

def tube(path, radii, seg_n=10, cap=True, n=2.0, flat=1.0, up=None):
    bm = bmesh.new()
    path = [Vector(p) for p in path]
    R = []
    prev = None
    for i, p in enumerate(path):
        tg = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        if prev is None:
            u0 = Vector(up) if up else (Vector((0, 0, 1)) if abs(tg.z) < 0.9 else Vector((0, 1, 0)))
            nx = tg.cross(u0).normalized()
        else:
            nx = (prev - tg * prev.dot(tg)).normalized()
        ny = tg.cross(nx).normalized()
        prev = nx
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
            c = bm.verts.new(sum((v.co for v in ring), Vector()) / len(ring))
            for j in range(seg_n):
                vs = [c, ring[j], ring[(j + 1) % seg_n]]
                bm.faces.new(vs[::-1] if rev else vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm

def limb(a, b, r0, r1, seg_n=10, n=2.0, bulge=0.0, flat=1.0, rings=5):
    a, b = Vector(a), Vector(b)
    L = (b - a).length
    R = []
    for i in range(rings):
        t = i / (rings - 1)
        r = r0 + (r1 - r0) * t + bulge * math.sin(math.pi * t)
        R.append((t * L, r, r * flat, 0.0, n))
    bm = loft(R, seg_n=seg_n)
    q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
    return xform(bm, Matrix.Translation(a) @ q.to_matrix().to_4x4())

def slab(pts2d, thick, z0=0.0):
    """placa: polígono 2D (x, z) extrudado em Y (espessura), para escudos, asas, bandeiras, tampas de caixão."""
    bm = bmesh.new()
    f = [bm.verts.new((x, -thick / 2, z)) for x, z in pts2d]
    b = [bm.verts.new((x, thick / 2, z)) for x, z in pts2d]
    bm.faces.new(f[::-1]); bm.faces.new(b)
    n = len(pts2d)
    for i in range(n):
        bm.faces.new([f[i], f[(i + 1) % n], b[(i + 1) % n], b[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm

def bend(bm, k, axis='z', toward='y', z0=0.0):
    for v in bm.verts:
        t = getattr(v.co, axis) - z0
        if t > 0:
            setattr(v.co, toward, getattr(v.co, toward) + k * t * t)
    return bm

def assemble(B, name):
    me = bpy.data.meshes.new(name)
    B.bm.to_mesh(me)
    B.bm.free()
    for mname in MATS:
        m = bpy.data.materials.get(mname) or bpy.data.materials.new(mname)
        me.materials.append(m)
    me.color_attributes.active_color_name = 'Col'
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for g in B.groups:
        ob.vertex_groups.new(name=g)
    ad = bpy.data.armatures.new(name + '_rig')
    arm = bpy.data.objects.new(name + '_rig', ad)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = {}
    for bn, h, t, p in B.bones:
        b = ad.edit_bones.new(bn)
        b.head, b.tail = Vector(h), Vector(t)
        if p:
            b.parent = eb[p]
            b.use_connect = False
        eb[bn] = b
    bpy.ops.object.mode_set(mode='OBJECT')
    ob.parent = arm
    mod = ob.modifiers.new('Armature', 'ARMATURE'); mod.object = arm
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    return arm, ob

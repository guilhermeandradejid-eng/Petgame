# Biblioteca de geometria para figuras de faiança: loft por perfil (seção superelíptica com frente e
# costas diferentes), tubo entre dois pontos, construtor com atlas de pintura, pesos rígidos por osso e
# casca de contorno. Só bpy/bmesh + numpy.
import math, random
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix, Euler, Quaternion
from paleta import lin, rgb

# ------------------------------------------------------------------ formas
def loft(rings, seg=18, p=2.0, fold=None, close=True):
    """rings: lista de baixo para cima com (z, rx, ryf, ryb[, cx, cy]).
    ryf = profundidade para a frente (-Y), ryb = para trás (+Y). Raio 0 vira polo.
    fold(i, th) -> multiplicador de raio (pregas). UV: s = ângulo (frente = 0,5), t = 0 no topo."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new('UVMap')
    n = len(rings)
    grid = []
    for i, r in enumerate(rings):
        z, rx, ryf, ryb = r[:4]
        cx = r[4] if len(r) > 4 else 0.0
        cy = r[5] if len(r) > 5 else 0.0
        row = []
        if max(rx, ryf, ryb) < 1e-5:
            row = [bm.verts.new((cx, cy, z))]
        else:
            for j in range(seg):
                th = 2 * math.pi * j / seg  # th=0 atrás (+Y), th=pi frente (-Y)
                sn, cs = math.sin(th), math.cos(th)
                e = 2.0 / p
                x = rx * math.copysign(abs(sn) ** e, sn)
                ry = ryb if cs > 0 else ryf
                y = ry * math.copysign(abs(cs) ** e, cs)
                k = fold(i, th) if fold else 1.0
                row.append(bm.verts.new((cx + x * k, cy + y * k, z)))
        grid.append(row)
    def uv(i, j):
        return (j / seg, 1.0 - i / (n - 1))
    for i in range(n - 1):
        a, b = grid[i], grid[i + 1]
        for j in range(seg):
            j2 = j + 1
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                vs = [a[0], b[j2 % seg], b[j]]; us = [(j + 0.5) / seg, j2 / seg, j / seg]; ts = [i, i + 1, i + 1]
            elif len(b) == 1:
                vs = [a[j], a[j2 % seg], b[0]]; us = [j / seg, j2 / seg, (j + 0.5) / seg]; ts = [i, i, i + 1]
            else:
                vs = [a[j], a[j2 % seg], b[j2 % seg], b[j]]; us = [j / seg, j2 / seg, j2 / seg, j / seg]; ts = [i, i, i + 1, i + 1]
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            for lo, u, t in zip(f.loops, us, ts):
                lo[uvl].uv = (u, 1.0 - t / (n - 1))
    if close:
        for row, top in ((grid[0], False), (grid[-1], True)):
            if len(row) > 2:
                f = bm.faces.new(row if top else list(reversed(row)))
                for lo in f.loops:
                    lo[uvl].uv = (0.5, 0.0 if top else 1.0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm

def profile_rings(pts, rx_scale=1.0, ryf=None, ryb=None):
    """pts: (z, r) -> anéis circulares com fatores de profundidade."""
    return [(z, r * rx_scale, r * (ryf or 1.0), r * (ryb or 1.0)) for z, r in pts]

def tube(a, b, radii, seg=12, p=2.0, flat=1.0, roll=0.0):
    """Tubo de a até b. radii: lista (t, r) de 0 a 1 (r=0 nas pontas fecha em polo).
    flat < 1 achata a seção na direção do 'y' local."""
    a, b = Vector(a), Vector(b)
    L = (b - a).length
    rings = [(t * L, r, r * flat, r * flat) for t, r in radii]
    bm = loft(rings, seg, p)
    q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
    M = Matrix.Translation(a) @ q.to_matrix().to_4x4() @ Matrix.Rotation(math.radians(roll), 4, 'Z')
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm

def capsule(r0, r1):
    """Perfil de cápsula afunilada para tube(): polo, ombro arredondado, corpo, ombro, polo."""
    return [(0.0, 0.0), (0.03, r0 * 0.62), (0.08, r0 * 0.9), (0.16, r0), (0.5, (r0 + r1) / 2), (0.84, r1), (0.92, r1 * 0.9), (0.97, r1 * 0.62), (1.0, 0.0)]

def sphere(r=1.0, u=16, v=10):
    rings = []
    for i in range(v + 1):
        ph = math.pi * i / v
        rings.append((-math.cos(ph), math.sin(ph), math.sin(ph), math.sin(ph)))
    return loft([(z * r, rx * r, f * r, b * r) for z, rx, f, b in rings], u)

def box(sx, sy, sz, bevel=0.0, seg=1):
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new('UVMap')
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=seg, affect='EDGES', profile=0.5)
    for f in bm.faces:  # UV planar pelo maior eixo da normal
        nrm = f.normal
        ax = max(range(3), key=lambda k: abs(nrm[k]))
        for lo in f.loops:
            co = lo.vert.co
            if ax == 0:
                u, v = co.y / sy + 0.5, co.z / sz + 0.5
            elif ax == 1:
                u, v = co.x / sx + 0.5, co.z / sz + 0.5
            else:
                u, v = co.x / sx + 0.5, co.y / sy + 0.5
            lo[uvl].uv = (u, v)
    return bm

def slab(poly, th, bevel=0.006):
    """Caco: polígono (x, z) extrudado em Y (frente = -Y). Faces marcadas na camada 'reg':
    0 frente (pintada), 1 borda (biscoito), 2 verso (argamassa). UV planar por face."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new('UVMap')
    reg = bm.faces.layers.int.new('reg')
    xs = [p[0] for p in poly]; zs = [p[1] for p in poly]
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    fr = [bm.verts.new((x, -th / 2, z)) for x, z in poly]
    bk = [bm.verts.new((x, th / 2, z)) for x, z in poly]
    ff = bm.faces.new(fr); ff[reg] = 0
    fb = bm.faces.new(list(reversed(bk))); fb[reg] = 2
    n = len(poly)
    per = 0.0
    for i in range(n):
        j = (i + 1) % n
        f = bm.faces.new([fr[j], fr[i], bk[i], bk[j]]); f[reg] = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges], offset=bevel, segments=1, affect='EDGES')
    bm.normal_update()
    for f in bm.faces:
        nrm = f.normal
        f[reg] = 0 if nrm.y < -0.7 else (2 if nrm.y > 0.7 else 1)
        for lo in f.loops:
            co = lo.vert.co
            if abs(nrm.y) > 0.7:
                u = (co.x - x0) / max(1e-6, x1 - x0); v = (co.z - z0) / max(1e-6, z1 - z0)
                if nrm.y > 0: u = 1 - u
            else:
                u = (math.atan2(co.z - (z0 + z1) / 2, co.x - (x0 + x1) / 2) / (2 * math.pi) + 0.5); v = co.y / th + 0.5
            lo[uvl].uv = (u, v)
    # faces do chanfro herdam a marca da borda
    return bm

def xf(bm, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    M = Matrix.Translation(loc) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4() @ Matrix.Diagonal((*scale, 1))
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm

def bend(bm, fn):
    for v in bm.verts:
        v.co = Vector(fn(v.co.copy()))
    return bm

# ------------------------------------------------------------------ atlas
class Atlas:
    def __init__(self, S=1024):
        self.S = S
        self.img = np.zeros((S, S, 3), np.float32)
        self.x = self.y = self.rowh = 0
        self.regions = {}

    def region(self, name, w, h, painter=None):
        if name in self.regions:
            return self.regions[name]
        if self.x + w > self.S:
            self.x = 0; self.y += self.rowh; self.rowh = 0
        if self.y + h > self.S:
            raise RuntimeError('atlas cheio: ' + name)
        r = (self.x, self.y, w, h)
        self.x += w; self.rowh = max(self.rowh, h)
        self.regions[name] = r
        if painter:
            x, y, w, h = r
            self.img[y:y + h, x:x + w] = painter(w, h)
        return r

    def uv(self, name, s, t, pad=2):
        x, y, w, h = self.regions[name]
        s = min(max(s, 0.0), 1.0); t = min(max(t, 0.0), 1.0)
        px = x + pad + s * (w - 2 * pad)
        py = y + pad + t * (h - 2 * pad)
        return (px / self.S, 1.0 - py / self.S)

# ------------------------------------------------------------------ construtor
class Fig:
    """Malha única com 2 materiais: 'corpo' (atlas) e 'contorno' (casca invertida).
    Cor de vértice: R = máscara de especular, G = material (0 esmalte, .25 biscoito, .5 salitre,
    .75 fosco do porto, 1 metal), B = emissão, A = peso do contorno (só na casca)."""
    def __init__(self, bones, seed=1, atlas=1024, outline=0.006):
        self.bones = bones  # lista (nome, cabeça, cauda, pai)
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new('Col')
        self.uvl = self.bm.loops.layers.uv.new('UVMap')
        self.dl = self.bm.verts.layers.deform.verify()
        self.groups = [b[0] for b in bones]
        self.rng = random.Random(seed)
        self.atlas = Atlas(atlas)
        self.outline = outline
        self.sockets = {}
        self.hxf = None   # (pivô, escala, deslocamento, ossos): cabeça maior para ler a 16 m

    def head_xf(self, pivot, s, off=(0, 0, 0), bones=('head',)):
        self.hxf = (Vector(pivot), s, Vector(off), set(bones))

    def _hx(self, co):
        pv, s, off, _ = self.hxf
        return pv + (Vector(co) - pv) * s + off

    def add(self, tmp, region, bone='hips', weights=None, spec=1.0, mat=0.0, emit=0.0, oline=1.0, smooth=True, hull=True):
        """region: nome da região do atlas, ou lista [frente, borda, verso] para cacos (camada 'reg');
        mat/spec também podem ser listas na mesma ordem."""
        if bone not in self.groups:
            bone = self.groups[0]
        if self.hxf and weights is None and bone in self.hxf[3]:
            for v in tmp.verts:
                v.co = self._hx(v.co)
        tmp.normal_update()
        tuv = tmp.loops.layers.uv.get('UVMap') or tmp.loops.layers.uv.verify()
        regl = tmp.faces.layers.int.get('reg')
        passes = [False, True] if (hull and oline > 0) else [False]
        for is_hull in passes:
            vmap = {}
            for v in tmp.verts:
                co = v.co.copy()
                if is_hull:
                    co = co + v.normal * self.outline * oline
                nv = self.bm.verts.new(co)
                w = weights(v.co) if weights else {bone: 1.0}
                for b, ww in w.items():
                    if ww > 1e-4:
                        nv[self.dl][self.groups.index(b)] = ww
                vmap[v] = nv
            for f in tmp.faces:
                try:
                    nf = self.bm.faces.new([vmap[v] for v in f.verts])
                except ValueError:
                    continue
                nf.material_index = 1 if is_hull else 0
                nf.smooth = True if is_hull else smooth
                for lo, olo in zip(nf.loops, f.loops):
                    if is_hull:
                        lo[self.col] = (0, 0, 0, oline)
                        lo[self.uvl].uv = (0, 0)
                    else:
                        ri = f[regl] if (regl is not None and isinstance(region, (list, tuple))) else 0
                        rname = region[ri] if isinstance(region, (list, tuple)) else region
                        sp = spec[ri] if isinstance(spec, (list, tuple)) else spec
                        mt = mat[ri] if isinstance(mat, (list, tuple)) else mat
                        lo[self.col] = (sp, mt, emit, 1.0)
                        s, t = olo[tuv].uv
                        lo[self.uvl].uv = self.atlas.uv(rname, s, t)
        tmp.free()

    def build(self, name):
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for mname in ('corpo', 'contorno'):
            m = bpy.data.materials.get(mname) or bpy.data.materials.new(mname)
            me.materials.append(m)
        me.color_attributes.active_color_name = 'Col'
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        for g in self.groups:
            ob.vertex_groups.new(name=g)
        ad = bpy.data.armatures.new(name + '_rig')
        arm = bpy.data.objects.new(name + '_rig', ad)
        bpy.context.scene.collection.objects.link(arm)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode='EDIT')
        eb = {}
        for bn, h, t, p in self.bones:
            b = ad.edit_bones.new(bn)
            b.head, b.tail = Vector(h), Vector(t)
            if self.hxf and bn in self.hxf[3]:
                b.head, b.tail = self._hx(h), self._hx(t)
            b.roll = 0.0
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

# ------------------------------------------------------------------ pose e chaves
def pose_q(arm, bone, rx=0, ry=0, rz=0):
    b = arm.data.bones[bone]
    R = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), 'XYZ').to_quaternion()
    Bq = b.matrix_local.to_quaternion()
    return Bq.inverted() @ R @ Bq

def apply_pose(arm, pose):
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    for bn, v in pose.items():
        if bn not in arm.pose.bones:
            continue
        pb = arm.pose.bones[bn]
        if 'r' in v:
            pb.rotation_quaternion = pose_q(arm, bn, *v['r'])
        if 'l' in v:
            b = arm.data.bones[bn]
            pb.location = b.matrix_local.to_3x3().inverted() @ Vector(v['l'])
        if 's' in v:
            pb.scale = v['s']

def key_action(arm, name, frames, skip_prefix='mola'):
    """frames: lista de (quadro, pose). Chaves CONSTANT (pose segurada, animação em 2s).
    Ossos de mola ficam sem chave: o motor os simula."""
    act = bpy.data.actions.new(name)
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = act
    for f, pose in frames:
        apply_pose(arm, pose)
        for pb in arm.pose.bones:
            if pb.name.startswith(skip_prefix):
                continue
            pb.keyframe_insert('rotation_quaternion', frame=f)
            pb.keyframe_insert('location', frame=f)
            pb.keyframe_insert('scale', frame=f)
    from bpy_extras.anim_utils import action_get_channelbag_for_slot
    for slot in act.slots:
        cb = action_get_channelbag_for_slot(act, slot)
        for fc in cb.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = 'CONSTANT'
    act.use_fake_user = True
    tr = arm.animation_data.nla_tracks.new(); tr.name = name
    tr.strips.new(name, int(frames[0][0]), act)
    arm.animation_data.action = None
    return act

def P_(base, **over):
    d = {k: dict(v) for k, v in base.items()}
    for k, v in over.items():
        k = k.replace('_L', '.L').replace('_R', '.R')
        d.setdefault(k, {}).update(v)
    return d

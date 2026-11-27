# Cenário do Brejo das Lamparinas Afogadas, todo por código: terreno contínuo (ruído), juncos, árvores mortas de
# galhos brancos, pedras, passarelas sobre palafitas, lanternas afundadas, a Wain (3 vagões e Graxo) e os marcos
# do horizonte (Farol Cego, Torre Torta, Gigante Ajoelhado). Exporta GLB estáticos e mundo.json com as instâncias.
# Coordenadas do Godot (x direita, y cima, z para a câmera); no Blender (x, -z, y).
import sys, os, json, math, random, time, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import bpy, bmesh
from mathutils import Vector, Matrix
from malha import *
from personagens import limb, disc, shell

PROJ = sys.argv[1]
GLB = os.path.join(PROJ, 'assets', 'glb')
os.makedirs(GLB, exist_ok=True)
only = sys.argv[2:]

def G(x, y, z):
    return Vector((x, -z, y))

# ------------------------------------------------------------------ ruído e altura do brejo
rng = np.random.default_rng(7)
PERM = rng.permutation(256)
def _vn(x, y):
    xi = np.floor(x).astype(int); yi = np.floor(y).astype(int)
    xf = x - xi; yf = y - yi
    def h(a, b):
        return (PERM[(PERM[a & 255] + b) & 255] / 255.0)
    u = xf * xf * (3 - 2 * xf); v = yf * yf * (3 - 2 * yf)
    return (h(xi, yi) * (1 - u) + h(xi + 1, yi) * u) * (1 - v) + (h(xi, yi + 1) * (1 - u) + h(xi + 1, yi + 1) * u) * v
def fbm(x, z, oct=4, f=0.08):
    s = 0.0; a = 0.5; ff = f
    for i in range(oct):
        s = s + a * _vn(x * ff + 17.3 * i, z * ff - 9.1 * i)
        a *= 0.5; ff *= 2.03
    return s

# passarelas (polilinhas em xz)
PASS = [
    [(-13.0, 9.0), (-8.5, 3.5), (-5.5, -1.2), (-2.0, -4.8), (1.5, -10.0), (2.5, -18.0), (3.0, -24.0), (-12.0, -25.5), (16.0, -25.0)],
    [(5.5, 9.0), (8.0, 3.0), (11.5, -1.0), (16.0, -3.0), (22.0, -3.5)],
    # ramal que sai da clareira para o fundo à direita, até a capela em ruínas (lanternas no caminho)
    [(8.8, 1.2), (10.5, -4.5), (12.5, -9.5), (15.0, -14.0), (17.5, -19.0)],
    # passarela curta que some pela borda de baixo (o caminho de onde o grupo veio)
    [(-2.5, 3.6), (-3.2, 6.5), (-4.0, 10.5)],
]
# trilha de pedras de pisar até o Farol Cego (caminho opcional) e a posição dos pontos de interesse
DEGRAUS = [(-5.8, -3.6), (-7.2, -5.2), (-8.4, -7.1), (-9.9, -8.6), (-11.0, -10.6), (-12.6, -12.1), (-13.6, -14.3), (-15.2, -16.0), (-16.2, -18.3), (-17.8, -20.2), (-19.0, -22.6)]
RUINA = (-5.6, -9.0)      # arco quebrado com braseiro aceso (plano médio, à esquerda)
CARROCA = (7.6, -7.4)     # carroça tombada com lanterna caída (plano médio, à direita)
CAPELA = (18.5, -21.0)    # capela afundada no fim do ramal (fundo)
def dist_seg(px, pz, a, b):
    ax, az = a; bx, bz = b
    dx, dz = bx - ax, bz - az
    t = np.clip(((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz + 1e-9), 0, 1)
    return np.hypot(px - (ax + t * dx), pz - (az + t * dz))
def dist_pass(px, pz):
    d = np.full(np.shape(px), 1e9)
    for pl in PASS:
        for i in range(len(pl) - 1):
            if pl is PASS[0] and i == 6:
                continue
            d = np.minimum(d, dist_seg(px, pz, pl[i], pl[i + 1]))
    return d

def altura(x, z):
    x = np.asarray(x, float); z = np.asarray(z, float)
    n = fbm(x, z, 4, 0.07)
    canal = fbm(x + 40, z - 13, 3, 0.035)
    h = (n - 0.5) * 0.5
    # canais de água rasa e poças
    agua = np.clip((canal - 0.52) * 6.0, 0, 1)
    h = h - agua * 0.45
    # o lodo do combate: largo e raso, um pouco acima da água
    c = np.exp(-((x - 1.0) ** 2 / 90.0 + (z + 0.5) ** 2 / 40.0))
    h = h * (1 - c) + c * (0.05 + (n - 0.5) * 0.12)
    # poças rasas no lodo do combate (refletem a Labareda e as lanternas)
    for (px, pz, pr) in ((-0.9, 2.4, 0.8), (4.9, 2.2, 0.65), (5.4, -2.3, 0.8), (-3.0, -2.6, 0.9)):
        k = np.exp(-((x - px) ** 2 + (z - pz) ** 2) / (pr * pr))
        h = h - k * 0.17
    # montes ao longe (relevo) e o rochedo do farol
    far = np.clip((-z - 30) / 80.0, 0, 1)
    h = h + far * (fbm(x, z, 3, 0.012) - 0.45) * 9.0
    return h

AGUA_Y = -0.06

def mesh_from(verts, faces, cols, name, mats=('cor',)):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(G(*v)) for v in verts], [], faces)
    me.update()
    ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
    li = np.array([lo.vertex_index for lo in me.loops])
    c = np.asarray(cols, np.float32)[li]
    ca.data.foreach_set('color', c.ravel())
    for mn in MATS:
        m = bpy.data.materials.get(mn) or bpy.data.materials.new(mn)
        me.materials.append(m)
    me.color_attributes.active_color_name = 'Col'
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob

def lin(h):
    r = hexc(h)
    return np.array(r[:3])

def export(name):
    path = os.path.join(GLB, name + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_animations=False, export_vertex_color='NAME',
                              export_vertex_color_name='Col', export_all_vertex_colors=True, export_materials='EXPORT', export_yup=True)
    print(name, round(os.path.getsize(path) / 1024), 'kb', flush=True)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def build_terreno():
    reset()
    # linhas em z (finas perto, largas longe), colunas que abrem com a distância
    zs = []
    z = 11.0
    while z > -330:
        zs.append(z)
        d = max(0.0, -z - 4.0)
        z -= 0.2 + d * 0.035
    NC = 260
    verts, cols = [], []
    for z in zs:
        half = 26.0 + max(0.0, -z) * 0.62
        xs = np.linspace(-half, half, NC)
        h = altura(xs, np.full(NC, z))
        n = fbm(xs + 5, np.full(NC, z) * 1.3, 3, 0.3)
        dp = dist_pass(xs, np.full(NC, z))
        for i, x in enumerate(xs):
            hh = float(h[i])
            wet = np.clip((0.05 - hh) * 6, 0, 1)
            c = lin('lodo') * (1 - n[i] * 0.5) + lin('lodo_claro') * n[i] * 0.5
            musgo = np.clip((fbm(x * 1.0 + 3, z, 2, 0.15) - 0.55) * 5, 0, 1) * (1 - wet)
            c = c * (1 - musgo) + lin('musgo') * musgo
            c = c * (1 - wet * 0.45)
            c = c * (1 - 0.25 * np.clip(1.2 - dp[i], 0, 1))   # chão pisado sob as passarelas
            verts.append((float(x), hh, float(z)))
            cols.append((*c, 1.0))
    faces = []
    for r in range(len(zs) - 1):
        for i in range(NC - 1):
            a = r * NC + i
            faces.append((a, a + 1, a + NC + 1, a + NC))
    ob = mesh_from(verts, faces, cols, 'terreno')
    ob.data.polygons.foreach_set('use_smooth', [True] * len(faces))
    export('terreno')
    return zs

# ------------------------------------------------------------------ peças soltas (instanciadas no motor)
class Obj:
    def __init__(self, seed, outline=0.02):
        self.B = Builder(seed, ['root'], outline=outline)
        self.B.bones = [('root', (0, 0, 0), (0, 0, 0.1), None)]
    def p(self, bm, paint, **kw):
        kw.setdefault('bone', 'root')
        return self.B.piece(bm, paint=paint, **kw)
    def save(self, name):
        reset()
        import personagens as K
        K.assemble(self.B, name, armature=False)
        export(name)

def build_junco():
    o = Obj(11, outline=0.0)
    r = random.Random(3)
    for i in range(16):
        a = r.uniform(0, 2 * math.pi); rr = r.uniform(0.0, 0.28)
        base = Vector((math.cos(a) * rr, math.sin(a) * rr, -0.05))
        H = r.uniform(0.9, 1.7)
        lean = Vector((r.uniform(-0.25, 0.25), r.uniform(-0.25, 0.25), 0))
        pts = [base + lean * (t * t) + Vector((0, 0, H * t)) for t in (0, 0.35, 0.7, 1.0)]
        o.p(tube(pts, [0.018, 0.014, 0.009, 0.002], seg_n=4), 'junco' if i % 3 else 'musgo', hull=False)
        if i % 5 == 0:   # taboa
            tp = pts[-1] + Vector((0, 0, 0.05))
            o.p(limb(tp - Vector((0, 0, 0.12)), tp + Vector((0, 0, 0.12)), 0.032, 0.03, seg_n=6, rings=3), 'couro', hull=False)
    o.save('junco')

def build_capim():
    o = Obj(12, outline=0.0)
    r = random.Random(4)
    for i in range(9):
        a = r.uniform(0, 2 * math.pi)
        base = Vector((math.cos(a) * 0.08, math.sin(a) * 0.08, -0.02))
        tip = base + Vector((math.cos(a) * 0.25, math.sin(a) * 0.25, r.uniform(0.25, 0.45)))
        o.p(tube([base, (base + tip) / 2 + Vector((0, 0, 0.05)), tip], [0.02, 0.012, 0.002], seg_n=3), 'musgo' if i % 2 else 'junco', hull=False)
    o.save('capim')

def galho(o, a, d, L, r, depth, rr, paint):
    b = a + d.normalized() * L
    o.p(limb(a, b, r, r * 0.62, seg_n=6, rings=3, bulge=r * 0.05), paint, jitter=r * 0.15, oline=0.8)
    if depth <= 0:
        return
    n = 2 if depth > 1 else rr.choice([1, 2, 2, 3])
    for k in range(n):
        nd = d.normalized() + Vector((rr.uniform(-0.9, 0.9), rr.uniform(-0.9, 0.9), rr.uniform(-0.1, 0.6)))
        galho(o, b, nd, L * rr.uniform(0.55, 0.75), r * 0.62, depth - 1, rr, paint)

def build_arvore(k):
    o = Obj(20 + k, outline=0.035)
    rr = random.Random(30 + k)
    H = [3.2, 4.6, 2.6][k]
    # tronco torto, raízes e galhos brancos de osso
    galho(o, Vector((0, 0, -0.2)), Vector((rr.uniform(-0.2, 0.2), rr.uniform(-0.2, 0.2), 1)), H * 0.5, 0.2, 3, rr, 'osso')
    for i in range(4):
        a = i * math.pi / 2 + rr.uniform(-0.3, 0.3)
        o.p(limb((0, 0, 0.25), (math.cos(a) * 0.7, math.sin(a) * 0.7, -0.15), 0.12, 0.04, seg_n=5, rings=2), 'osso', jitter=0.02, oline=0.8)
    o.save('arvore%d' % k)

def build_pedra(k):
    o = Obj(40 + k, outline=0.03)
    rr = random.Random(50 + k)
    s = [(0.8, 0.6, 0.5), (1.4, 1.0, 0.7), (0.5, 0.45, 0.35)][k]
    bm = mk('ico', sub=1)
    for v in bm.verts:
        v.co = Vector((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2])) * rr.uniform(0.85, 1.12)
        if v.co.z < -0.1:
            v.co.z *= 0.3
    o.p(bm, 'pedra' if k != 1 else 'pedra_esc', jitter=0.03)
    o.save('pedra%d' % k)

def build_lanterna_afogada():
    o = Obj(60, outline=0.0)
    o.p(place(mk('cyl', seg=8), (0, 0, 0.1), (0.12, 0.12, 0.12)), 'linha', mat='emis', hull=False)
    o.p(place(mk('cyl', seg=8, r2=0.4), (0, 0, 0.26), (0.16, 0.16, 0.06)), 'pedra_esc', hull=False)
    o.save('lanterna_afogada')

def build_passarela():
    """tábuas sobre palafitas ao longo das polilinhas; tudo numa malha só."""
    reset()
    o = Obj(70, outline=0.02)
    rr = random.Random(71)
    for pi_, pl in enumerate(PASS):
        for i in range(len(pl) - 1):
            if pi_ == 0 and i == 6:
                continue
            (ax, az), (bx, bz) = pl[i], pl[i + 1]
            L = math.hypot(bx - ax, bz - az)
            dx, dz = (bx - ax) / L, (bz - az) / L
            px, pz = -dz, dx
            n = int(L / 0.34)
            for k in range(n):
                t = (k + 0.5) / n
                cx, cz = ax + (bx - ax) * t, az + (bz - az) * t
                y = 0.32 + rr.uniform(-0.03, 0.03)
                if rr.random() < 0.04:
                    continue   # tábua faltando
                ang = math.atan2(-dz, dx)
                w = 1.25 + rr.uniform(-0.08, 0.08)
                bm = place(mk('cube'), (0, 0, 0), (0.15, w / 2, 0.035))
                xform(bm, Matrix.Translation(G(cx + px * rr.uniform(-0.05, 0.05), y, cz + pz * rr.uniform(-0.05, 0.05))) @ Matrix.Rotation(math.atan2(dz, -dx), 4, 'Z') @ Matrix.Rotation(rr.uniform(-0.04, 0.04), 4, 'X'))
                o.p(bm, rr.choice(['madeira', 'madeira', 'madeira_clara', 'couro']), jitter=0.006, oline=0.6)
                if k % 6 == 0:
                    for s in (-1, 1):
                        qx, qz = cx + px * s * 0.62, cz + pz * s * 0.62
                        o.p(limb(G(qx, -0.6, qz), G(qx, 0.55 + rr.uniform(0, 0.25), qz), 0.06, 0.05, seg_n=6, rings=2), 'couro', jitter=0.01, oline=0.7)
    o.save('passarela')

# ------------------------------------------------------------------ a Wain: vagões e Graxo
def roda(o, c, nrm, R, w=0.12):
    Mw = Matrix.Translation(c) @ Vector((0, 0, 1)).rotation_difference(Vector(nrm)).to_matrix().to_4x4()
    aro = loft([(-w / 2, R, R, 0, 2.0), (w / 2, R, R, 0, 2.0)], seg_n=16, cap_bot=False, cap_top=False)
    bmesh.ops.solidify(aro, geom=aro.faces[:], thickness=0.07)
    o.p(xform(aro, Mw), 'madeira', oline=0.8)
    for i in range(8):
        t = 2 * math.pi * i / 8
        o.p(xform(limb((0, 0, 0), (math.cos(t) * R * 0.92, math.sin(t) * R * 0.92, 0), 0.035, 0.03, seg_n=5, rings=2), Mw), 'madeira_clara', oline=0.6)
    o.p(xform(place(mk('cyl', seg=8), (0, 0, 0), (0.12, 0.12, w * 0.8)), Mw), 'ferro', mat='metal', oline=0.7)

def lanterna_grande(o, p, s=1.0, haste=True):
    p = Vector(p)
    o.p(place(mk('cyl', seg=8), p, (0.13 * s, 0.13 * s, 0.17 * s)), 'ambar', mat='emis', hull=False)
    o.p(place(mk('cyl', seg=8, r2=0.3), p + Vector((0, 0, 0.24 * s)), (0.19 * s, 0.19 * s, 0.08 * s)), 'latao', mat='metal', oline=0.6)
    o.p(place(mk('cyl', seg=8), p - Vector((0, 0, 0.19 * s)), (0.16 * s, 0.16 * s, 0.03 * s)), 'latao', mat='metal', oline=0.6)

def vagao(o, x0, tipo, rr):
    L, W = 2.8, 1.55
    base = 0.95
    # caixa de tábuas (telha queimada) com chanfro nas quinas
    for k in range(4):
        z = base + 0.12 + k * 0.24
        for sy in (-1, 1):
            o.p(place(mk('cube', bevel=0.12, bseg=1), (x0, sy * W / 2, z), (L / 2, 0.04, 0.11)), rr.choice(['telha', 'telha', 'madeira']), jitter=0.01, oline=0.7)
    for sx in (-1, 1):
        o.p(place(mk('cube', bevel=0.12, bseg=1), (x0 + sx * L / 2, 0, base + 0.48), (0.04, W / 2, 0.5)), 'telha', jitter=0.01, oline=0.7)
    o.p(place(mk('cube'), (x0, 0, base), (L / 2 + 0.1, W / 2 + 0.05, 0.06)), 'couro', oline=0.7)
    for sx in (-1, 1):
        for sy in (-1, 1):
            roda(o, Vector((x0 + sx * 0.95, sy * (W / 2 + 0.14), 0.62)), (0, sy, 0), 0.62)
    top = base + 1.0
    if tipo == 'torre':
        # Torre-Lanterna: torre de tábuas com a Grande Lanterna no alto
        o.p(place(mk('cyl', seg=8, r2=0.75), (x0, 0, top + 0.9), (0.62, 0.62, 0.9)), 'madeira', jitter=0.02)
        o.p(place(mk('cyl', seg=8), (x0, 0, top + 1.85), (0.75, 0.75, 0.08)), 'couro', oline=0.7)
        o.p(place(mk('cyl', seg=8), (x0, 0, top + 2.25), (0.42, 0.42, 0.34)), 'ambar', mat='emis', hull=False)
        o.p(place(mk('cyl', seg=8), (x0, 0, top + 2.25), (0.22, 0.22, 0.36)), 'sebo', mat='emis', hull=False)
        for i in range(8):
            t = 2 * math.pi * (i + 0.5) / 8
            o.p(limb((x0 + math.cos(t) * 0.46, math.sin(t) * 0.46, top + 1.9), (x0 + math.cos(t) * 0.46, math.sin(t) * 0.46, top + 2.62), 0.03, 0.03, seg_n=4, rings=2), 'latao', mat='metal', oline=0.6)
        o.p(place(mk('cyl', seg=8, r2=0.2), (x0, 0, top + 2.85), (0.62, 0.62, 0.26)), 'latao', mat='metal')
        o.p(place(mk('cyl', seg=6), (x0, 0, top + 3.2), (0.05, 0.05, 0.12)), 'latao', mat='metal', oline=0.6)
        # manivela do Feixe
        o.p(limb((x0 + 0.62, 0, top + 1.2), (x0 + 0.9, 0, top + 1.2), 0.05, 0.05, seg_n=5, rings=2), 'ferro', mat='metal', oline=0.6)
    else:
        # lona em arcos (sebo e lona remendada)
        rows = []
        for i in range(7):
            x = x0 - L / 2 + 0.1 + i * (L - 0.2) / 6
            rows.append(x)
        bm = bmesh.new()
        R = []
        for x in rows:
            ring = []
            for j in range(13):
                t = math.pi * j / 12
                ring.append(bm.verts.new((x, math.cos(t) * (W / 2 + 0.05), top - 0.05 + math.sin(t) * 0.95 + 0.04 * math.sin(x * 9))))
            R.append(ring)
        for i in range(len(R) - 1):
            for j in range(12):
                bm.faces.new([R[i][j], R[i + 1][j], R[i + 1][j + 1], R[i][j + 1]])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.04)
        o.p(bm, 'lona', jitter=0.015)
        for x in (rows[0], rows[3], rows[-1]):
            arc = [(x, math.cos(math.pi * j / 8) * (W / 2 + 0.09), top - 0.05 + math.sin(math.pi * j / 8) * 0.99) for j in range(9)]
            o.p(tube(arc, [0.045] * 9, seg_n=5, cap=True), 'couro', oline=0.7)
        # remendos
        for i in range(3):
            a = rr.uniform(0.6, 2.5); x = x0 + rr.uniform(-1.0, 1.0)
            o.p(disc(Vector((x, math.cos(a) * (W / 2 + 0.1), top - 0.05 + math.sin(a) * 1.0)), Vector((0, math.cos(a), math.sin(a))), 0.22, seg=6, sx=1.3, depth=0.02),
                rr.choice(['lona_esc', 'sebo', 'telha']), oline=0.6)
        if tipo == 'tonel':
            o.p(place(mk('cyl', seg=10), (x0 + L / 2 + 0.3, 0.0, base + 0.5), (0.35, 0.35, 0.45)), 'madeira', jitter=0.01)
            for z in (0.2, 0.8):
                o.p(place(mk('cyl', seg=10), (x0 + L / 2 + 0.3, 0, base + z), (0.37, 0.37, 0.04)), 'ferro', mat='metal', oline=0.5)
            # chaminé com fumaça (o motor faz a fumaça)
            o.p(place(mk('cyl', seg=6), (x0 - 0.6, 0.3, top + 1.05), (0.09, 0.09, 0.35)), 'ferro', mat='metal')
    # lanternas penduradas nas quinas, em ganchos
    for sx in (-1, 1):
        hx = x0 + sx * (L / 2 + 0.15)
        o.p(tube([(x0 + sx * L / 2, -W / 2 - 0.05, top - 0.05), (hx, -W / 2 - 0.25, top + 0.2), (hx, -W / 2 - 0.4, top + 0.1)], [0.025] * 3, seg_n=4), 'ferro', oline=0.6)
        lanterna_grande(o, (hx, -W / 2 - 0.4, top - 0.18), 0.8)

def build_wain():
    o = Obj(80, outline=0.03)
    rr = random.Random(81)
    # vagões em fila ao longo de x: Tonel, Oficina, Torre-Lanterna (o Graxo puxa pela esquerda)
    for x0, t in ((-1.2, 'tonel'), (2.1, 'oficina'), (5.4, 'torre')):
        vagao(o, x0, t, rr)
        if x0 > -1:
            o.p(limb((x0 - 1.5, 0, 0.9), (x0 - 1.8, 0, 0.9), 0.06, 0.06, seg_n=5, rings=2), 'ferro', mat='metal', oline=0.6)
    # varal até o Graxo
    for sy in (-0.5, 0.5):
        o.p(limb((-2.6, sy, 0.95), (-5.6, sy * 1.6, 1.4), 0.06, 0.05, seg_n=6, rings=2), 'madeira', oline=0.7)
    o.save('wain')

def build_estandarte():
    o = Obj(85, outline=0.012)
    o.p(limb((0, 0, 0), (0, 0, 2.4), 0.04, 0.035, seg_n=6, rings=2), 'madeira', oline=0.6)
    o.p(limb((0, -0.02, 2.3), (0.9, -0.02, 2.3), 0.025, 0.025, seg_n=5, rings=2), 'madeira', oline=0.6)
    # pano comprido com ponta em rabo de andorinha; o vento balança (peso pela altura invertida no shader)
    bm = bmesh.new()
    vs = []
    N = 8
    for i in range(N + 1):
        z = 2.28 - i * 0.18
        w0, w1 = 0.04, 0.86
        if i == N:
            vs.append([bm.verts.new((w0, -0.02, z + 0.1)), bm.verts.new(((w0 + w1) / 2, -0.02, z + 0.3)), bm.verts.new((w1, -0.02, z + 0.1))])
        else:
            vs.append([bm.verts.new((w0, -0.02, z)), bm.verts.new(((w0 + w1) / 2, -0.02, z)), bm.verts.new((w1, -0.02, z))])
    for i in range(N):
        for j in range(2):
            bm.faces.new([vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.02)
    o.p(bm, 'telha', jitter=0.005)
    # sinal: mariposa de sebo pintada
    o.p(disc(Vector((0.45, -0.05, 1.75)), Vector((0, -1, 0)), 0.16, seg=6, sx=1.6, sy=0.8, depth=0.01), 'sebo', oline=0.5)
    o.save('estandarte')

def build_graxo():
    """Graxo: fera de sebo de seis patas, cega, 5 m. Corpo de gota de cera, pavios acesos nas costas."""
    o = Obj(90, outline=0.035)
    rr = random.Random(91)
    body = loft([(0.0, 1.05, 1.2, 0, 2.0), (0.5, 1.45, 1.55, 0.0, 2.1), (1.2, 1.6, 1.7, 0.0, 2.2), (1.9, 1.45, 1.55, 0.05, 2.1), (2.4, 1.0, 1.15, 0.1, 2.0),
                 (2.65, 0.4, 0.5, 0.1, 2.0)], seg_n=16)
    for v in body.verts:
        v.co += v.normal * rr.uniform(-0.04, 0.06)
    # corpo deitado ao longo de x (cabeça para -x)
    xform(body, Matrix.Translation((0.2, 0, 1.45)) @ Matrix.Diagonal((1.45, 1.0, 1.0, 1)) @ Matrix.Rotation(math.radians(-8), 4, 'Y'))
    o.p(body, 'cera', jitter=0.03, smooth=True)
    # escorridos de sebo nos flancos
    for i in range(14):
        a = rr.uniform(0.3, 2.8); x = rr.uniform(-1.3, 2.0)
        p = Vector((x, math.cos(a) * 1.55, 1.45 + 1.0 + math.sin(a) * 0.9))
        o.p(tube([p, p + Vector((0, math.cos(a) * 0.1, -0.35)), p + Vector((0, math.cos(a) * 0.15, -0.7))], [0.09, 0.07, 0.09], seg_n=6), 'sebo', oline=0.6, smooth=True)
    # pavios acesos nas costas (o sebo vira luz)
    for i in range(5):
        x = -0.8 + i * 0.6
        p = Vector((x, rr.uniform(-0.3, 0.3), 4.05 - abs(x - 0.4) * 0.25))
        o.p(limb(p, p + Vector((0, 0, 0.18)), 0.025, 0.02, seg_n=4, rings=2), 'tinta', hull=False)
        fl = loft([(0.0, 0.0, 0.0, 0, 2.0), (0.04, 0.07, 0.07, 0, 2.0), (0.12, 0.08, 0.08, 0, 2.0), (0.24, 0.04, 0.04, 0, 2.0), (0.32, 0.0, 0.0, 0, 2.0)], seg_n=7)
        o.p(place(fl, p + Vector((0, 0, 0.18))), 'ambar', mat='emis', hull=False)
    # seis patas grossas como colunas de vela
    for i, x in enumerate((-1.4, 0.4, 2.0)):
        for sy in (-1, 1):
            a = Vector((x, sy * 0.95, 1.2)); b = Vector((x - 0.15, sy * 1.15, 0.0))
            o.p(limb(a, b, 0.45, 0.36, seg_n=8, rings=3, bulge=0.05), 'cera_esc', jitter=0.03)
            o.p(place(mk('cyl', seg=8), b + Vector((0, 0, 0.08)), (0.45, 0.45, 0.1)), 'couro', oline=0.7)
    # cabeça pequena, baixa, sem olhos; narinas grandes
    hb = Vector((-2.35, 0, 1.8))
    head = loft([(0.0, 0.5, 0.55, 0, 2.0), (0.4, 0.62, 0.6, 0, 2.1), (0.8, 0.55, 0.5, 0, 2.0), (1.05, 0.35, 0.32, 0, 2.0), (1.15, 0.0, 0.0, 0, 2.0)], seg_n=12)
    xform(head, Matrix.Translation(hb) @ Matrix.Rotation(math.radians(-115), 4, 'Y'))
    o.p(head, 'cera', jitter=0.02, smooth=True)
    for sy in (-1, 1):
        o.p(place(mk('sphere', u=8, v=6), hb + Vector((-0.95, sy * 0.15, -0.45)), (0.1, 0.08, 0.08)), 'tinta', hull=False)
    # arreio de couro e cangalha
    o.p(place(loft([(0, 1.25, 1.45, 0, 2.0), (0.25, 1.28, 1.48, 0, 2.0)], seg_n=16, cap_bot=False, cap_top=False), (-1.0, 0, 1.55), (1, 1, 1), rot=(0, -80, 0)), 'couro', oline=0.7)
    o.save('graxo')

# ------------------------------------------------------------------ marcos do horizonte
def build_farol():
    o = Obj(100, outline=0.25)
    rr = random.Random(101)
    # rochedo
    bm = mk('ico', sub=2)
    for v in bm.verts:
        v.co = Vector((v.co.x * 14, v.co.y * 10, v.co.z * 9)) * rr.uniform(0.85, 1.1)
    o.p(bm, 'pedra_esc', jitter=0.4)
    # torre afunilada rachada
    o.p(place(loft([(0, 3.2, 3.2, 0, 2.0), (10, 2.6, 2.6, 0, 2.0), (18, 2.2, 2.2, 0, 2.0)], seg_n=10), (0, 0, 7)), 'pedra', jitter=0.1)
    o.p(place(mk('cyl', seg=10), (0, 0, 25.5), (3.0, 3.0, 0.4)), 'pedra_esc')
    o.p(place(mk('cyl', seg=10), (0, 0, 27.6), (1.9, 1.9, 1.9)), 'linha', mat='emis', hull=False)
    o.p(place(mk('cyl', seg=10, r2=0.2), (0, 0, 30.5), (2.4, 2.4, 1.2)), 'pedra_esc')
    o.save('farol')

def build_torre():
    o = Obj(110, outline=0.2)
    # campanário de capela afundada, inclinado 20 graus
    t = loft([(0, 2.4, 2.4, 0, 4.0), (14, 2.0, 2.0, 0, 4.0), (15, 2.4, 2.4, 0, 4.0), (19, 2.2, 2.2, 0, 4.0), (19.5, 1.8, 1.8, 0, 4.0), (25, 0.1, 0.1, 0, 4.0)], seg_n=8)
    xform(t, Matrix.Rotation(math.radians(20), 4, 'X'))
    o.p(t, 'pedra', jitter=0.08)
    sino = loft([(0, 0.3, 0.3, 0, 2.0), (0.6, 0.7, 0.7, 0, 2.0), (1.2, 1.0, 1.0, 0, 2.0)], seg_n=10)
    xform(sino, Matrix.Rotation(math.radians(20), 4, 'X') @ Matrix.Translation((0, -1.9, 16.0)) @ Matrix.Rotation(math.pi, 4, 'X'))
    o.p(sino, 'bronze', mat='metal')
    o.save('torre')

def build_gigante():
    o = Obj(120, outline=0.4)
    # estátua de joelhos segurando um disco solar rachado
    o.p(place(loft([(0, 6, 5, 0, 2.0), (4, 7, 5.5, 0, 2.0), (12, 8, 5, 0, 2.0), (18, 9, 5, 0, 2.0), (21, 4, 3, 0, 2.0)], seg_n=10), (0, 0, 8)), 'pedra', jitter=0.3)
    o.p(place(mk('sphere', u=10, v=7), (0, -1, 33), (3.6, 3.6, 4.0)), 'pedra', jitter=0.2)
    for sx in (-1, 1):
        o.p(limb((sx * 4, -2, 0), (sx * 5, -9, 2), 3.2, 2.6, seg_n=8, rings=2), 'pedra', jitter=0.2)
        o.p(limb((sx * 4, 2, 9), (sx * 4, 0, 0), 3.4, 3.0, seg_n=8, rings=2), 'pedra', jitter=0.2)
        o.p(limb((sx * 8, 0, 26), (sx * 6, -6, 17), 2.0, 1.8, seg_n=8, rings=2), 'pedra', jitter=0.2)
        o.p(limb((sx * 6, -6, 17), (sx * 2.5, -9, 22), 1.8, 1.5, seg_n=8, rings=2), 'pedra', jitter=0.2)
    # disco solar rachado (meio disco faltando um gomo)
    d = disc(Vector((0, -10, 24)), Vector((0, -1, 0.15)), 6.5, seg=16, depth=0.8)
    o.p(d, 'pedra_esc', jitter=0.2)
    o.save('gigante')

# ------------------------------------------------------------------ plano médio e restos (mundo que continua)
def build_ruina():
    """arco de pedra quebrado, três pilares tombados e um braseiro de ferro aceso (ponto de luz que chama)."""
    o = Obj(130, outline=0.035)
    rr = random.Random(131)
    for sx in (-1, 1):
        h = 3.4 if sx < 0 else 2.1
        for k in range(int(h / 0.42)):
            z = 0.21 + k * 0.42
            o.p(place(mk('cube', bevel=0.06), (sx * 1.3 + rr.uniform(-0.04, 0.04), rr.uniform(-0.04, 0.04), z), (0.32, 0.32, 0.2), rot=(0, 0, rr.uniform(-6, 6))), rr.choice(['pedra', 'pedra', 'pedra_esc']), jitter=0.02)
    # meia volta do arco (o outro lado caiu)
    for k in range(5):
        a = math.radians(180 - k * 22)
        o.p(place(mk('cube', bevel=0.05), (math.cos(a) * 1.3, 0, 3.4 + math.sin(a) * 1.25 - 0.2), (0.3, 0.33, 0.2), rot=(0, -math.degrees(a) + 90, 0)), 'pedra', jitter=0.02)
    # blocos caídos e pilar tombado
    for i in range(6):
        o.p(place(mk('cube', bevel=0.06), (rr.uniform(-0.5, 2.5), rr.uniform(-1.2, 1.2), 0.15), (0.3, 0.28, 0.18), rot=(rr.uniform(-20, 20), rr.uniform(-20, 20), rr.uniform(0, 90))), 'pedra_esc', jitter=0.02)
    o.p(limb((2.0, 1.4, 0.3), (4.4, 0.6, 0.35), 0.32, 0.3, seg_n=8, rings=3), 'pedra', jitter=0.03)
    # braseiro: tripé de ferro, bacia e brasa
    for i in range(3):
        a = i * 2 * math.pi / 3
        o.p(limb((0.4 + math.cos(a) * 0.35, -0.6 + math.sin(a) * 0.35, 0.0), (0.4, -0.6, 0.9), 0.03, 0.03, seg_n=5, rings=2), 'ferro', mat='metal', oline=0.6)
    o.p(place(mk('cyl', seg=10, r1=0.5, r2=1.0), (0.4, -0.6, 0.98), (0.36, 0.36, 0.12)), 'ferro', mat='metal')
    o.p(place(mk('sphere', u=8, v=5), (0.4, -0.6, 1.08), (0.3, 0.3, 0.1)), 'ambar', mat='emis', hull=False)
    # estandarte rasgado preso no pilar
    bm = bmesh.new()
    vs = [[bm.verts.new((-1.0 + j * 0.3, -0.36, 3.0 - i * 0.35 - (0.15 * j if i == 4 else 0))) for j in range(3)] for i in range(5)]
    for i in range(4):
        for j in range(2):
            bm.faces.new([vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.02)
    o.p(bm, 'telha', jitter=0.01)
    o.save('ruina')

def build_carroca():
    """carroça tombada de lado: caixa virada, uma roda para cima, caixotes e barris espalhados, lanterna caída acesa."""
    o = Obj(140, outline=0.03)
    rr = random.Random(141)
    for k in range(4):
        o.p(place(mk('cube', bevel=0.1), (0, -0.45 + k * 0.24, 0.62), (1.3, 0.04, 0.11), rot=(90, 0, 0)), rr.choice(['madeira', 'telha']), jitter=0.01)
    o.p(place(mk('cube'), (0, -0.55, 0.62), (1.35, 0.06, 0.62)), 'madeira', jitter=0.01)
    o.p(place(mk('cube'), (0, 0.4, 0.05), (1.35, 0.6, 0.05)), 'madeira_clara', jitter=0.01)
    roda(o, Vector((-0.9, -0.55, 1.35)), (0, 0, 1), 0.55)
    roda(o, Vector((0.9, -0.55, 0.12)), (0, 0, 1), 0.55)
    for i in range(4):
        o.p(place(mk('cube', bevel=0.08), (rr.uniform(1.4, 2.6), rr.uniform(-0.6, 1.4), 0.2), (0.22, 0.22, 0.2), rot=(0, 0, rr.uniform(0, 90))), 'madeira', jitter=0.01)
    for i in range(2):
        o.p(place(mk('cyl', seg=10), (rr.uniform(-2.2, -1.5), rr.uniform(0.2, 1.2), 0.25), (0.25, 0.25, 0.35), rot=(90, 0, rr.uniform(0, 180))), 'madeira', jitter=0.01)
    lanterna_grande(o, (1.6, 1.3, 0.2), 0.8)
    o.save('carroca')

def build_poste():
    """poste de lanterna do caminho: estaca torta, braço e lanterna pendurada (marca o caminho na Treva)."""
    o = Obj(150, outline=0.02)
    o.p(limb((0, 0, -0.3), (0.05, 0.0, 2.0), 0.06, 0.045, seg_n=6, rings=3), 'madeira', jitter=0.01)
    o.p(limb((0.04, 0, 1.9), (0.5, 0, 1.95), 0.03, 0.03, seg_n=5, rings=2), 'madeira', oline=0.7)
    o.p(tube([(0.48, 0, 1.94), (0.48, 0, 1.75)], [0.01, 0.01], seg_n=4), 'ferro', oline=0.5)
    lanterna_grande(o, (0.48, 0, 1.55), 0.6)
    o.save('poste')

def build_capela():
    """capela afundada no fim do ramal: paredes de pedra, telhado partido, janela acesa."""
    o = Obj(160, outline=0.06)
    rr = random.Random(161)
    o.p(place(mk('cube', bevel=0.05), (0, 0, 1.6), (2.0, 1.4, 1.6), rot=(0, 4, 0)), 'pedra', jitter=0.05)
    o.p(place(mk('cyl', seg=4, r2=0.0), (0, 0, 4.0), (2.4, 1.8, 0.9), rot=(0, 4, 45)), 'telha', jitter=0.06)
    o.p(place(mk('cube'), (0, -1.42, 1.9), (0.35, 0.05, 0.6)), 'ambar', mat='emis', hull=False)
    o.p(place(mk('cube'), (0, 0, 5.4), (0.25, 0.25, 0.7)), 'pedra_esc', jitter=0.03)
    for i in range(5):
        o.p(place(mk('cube', bevel=0.06), (rr.uniform(-2.5, 2.5), rr.uniform(-2.0, -1.5), 0.2), (0.3, 0.3, 0.2), rot=(0, 0, rr.uniform(0, 90))), 'pedra_esc', jitter=0.02)
    o.save('capela')

def build_restos():
    """restos no chão: poça de cera endurecida, casca de Fuligento apagado e estandarte rasgado caído."""
    o = Obj(170, outline=0.0)
    rr = random.Random(171)
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=14, radius=0.3)
    for v in bm.verts:
        a = math.atan2(v.co.y, v.co.x)
        v.co *= 1.0 + 0.25 * math.sin(a * 3 + 1.0) + 0.12 * math.sin(a * 7)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.02)
    o.p(place(bm, (0, 0, 0.01), (1.0, 0.7, 1.0)), 'couro', hull=False)
    # toco de vela derretido com o pavio carbonizado (um herói caído antes de você)
    o.p(place(mk('cyl', seg=8), (0.12, 0.04, 0.08), (0.06, 0.06, 0.08)), 'cera', jitter=0.005)
    o.p(limb((0.12, 0.04, 0.16), (0.14, 0.05, 0.22), 0.01, 0.006, seg_n=4, rings=2), 'tinta', hull=False)
    o.save('poca_cera')
    o = Obj(171, outline=0.015)
    bm = mk('sphere', u=10, v=6)
    for v in bm.verts:
        v.co = Vector((v.co.x * 0.32, v.co.y * 0.28, max(v.co.z, -0.2) * 0.13)) * rr.uniform(0.85, 1.1)
    o.p(bm, 'fuligem', jitter=0.02)
    for i in range(4):
        a = rr.uniform(0, 6.28)
        o.p(place(mk('cyl', seg=4, r2=0.0), (math.cos(a) * 0.3, math.sin(a) * 0.25, 0.06), (0.04, 0.04, 0.12), rot=(rr.uniform(40, 80), 0, math.degrees(a))), 'fuligem', jitter=0.005)
    o.p(limb((0.0, 0.0, 0.1), (0.05, 0.1, 0.35), 0.02, 0.01, seg_n=4, rings=2), 'tinta')
    o.save('casca')
    o = Obj(172, outline=0.012)
    o.p(limb((-1.2, 0, 0.04), (1.0, 0.2, 0.04), 0.035, 0.03, seg_n=6, rings=2), 'madeira', oline=0.6)
    bm = bmesh.new()
    vs = [[bm.verts.new((-0.9 + i * 0.22, 0.05 + j * 0.3 + 0.08 * math.sin(i * 1.7), 0.02 + 0.015 * math.sin(i * 2.3 + j))) for j in range(3)] for i in range(6)]
    for i in range(5):
        for j in range(2):
            if (i, j) != (3, 1):
                bm.faces.new([vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.01)
    o.p(bm, 'telha', jitter=0.005)
    o.save('estandarte_caido')

def build_junco_alto():
    """touceira alta de primeiro plano (moldura escura embaixo do quadro, desfocada no PC)."""
    o = Obj(13, outline=0.0)
    r = random.Random(5)
    for i in range(26):
        a = r.uniform(0, 2 * math.pi); rr_ = r.uniform(0.0, 0.5)
        base = Vector((math.cos(a) * rr_, math.sin(a) * rr_, -0.05))
        H = r.uniform(1.8, 3.2)
        lean = Vector((r.uniform(-0.5, 0.5), r.uniform(-0.5, 0.5), 0))
        pts = [base + lean * (t * t) + Vector((0, 0, H * t)) for t in (0, 0.35, 0.7, 1.0)]
        o.p(tube(pts, [0.03, 0.024, 0.015, 0.003], seg_n=4), 'junco' if i % 3 else 'musgo', hull=False)
        if i % 4 == 0:
            tp = pts[-1] + Vector((0, 0, 0.05))
            o.p(limb(tp - Vector((0, 0, 0.18)), tp + Vector((0, 0, 0.18)), 0.05, 0.045, seg_n=6, rings=3), 'couro', hull=False)
    o.save('junco_alto')

def instancias():
    """Posições de juncos, capim, árvores, pedras e lanternas afogadas (o motor usa MultiMesh)."""
    r = np.random.default_rng(12)
    out = {}
    def scatter(n, xr, zr, cond, seed):
        rr = np.random.default_rng(seed)
        xs = rr.uniform(*xr, n * 4); zs = rr.uniform(*zr, n * 4)
        h = altura(xs, zs); dp = dist_pass(xs, zs)
        ok = cond(xs, zs, h, dp)
        xs, zs, h = xs[ok][:n], zs[ok][:n], h[ok][:n]
        rot = rr.uniform(0, 6.283, len(xs)); sc = rr.uniform(0.7, 1.3, len(xs))
        return [[float(a), float(b), float(c), float(d), float(e)] for a, b, c, d, e in zip(xs, h, zs, rot, sc)]
    combate = lambda x, z: (((x - 1.0) ** 2 / 64 + (z + 0.5) ** 2 / 25) < 1.0) | (np.hypot(x - RUINA[0], z - RUINA[1]) < 3.5) | (np.hypot(x - CARROCA[0], z - CARROCA[1]) < 3.0)
    out['junco'] = scatter(900, (-40, 40), (-60, 10), lambda x, z, h, dp: (dp > 1.0) & ~combate(x, z) & (fbm(x, z, 2, 0.12) > 0.48), 1)
    out['junco'] += scatter(250, (-14, 16), (-6, 8), lambda x, z, h, dp: (dp > 1.0) & ~combate(x, z) & (np.abs(x - 1) > 7.5), 11)
    out['capim'] = scatter(700, (-25, 25), (-30, 9), lambda x, z, h, dp: (dp > 0.9) & (h > -0.02) & ~(((x - 1.0) ** 2 / 20 + (z + 0.5) ** 2 / 9) < 1.0), 2)
    out['arvore'] = scatter(26, (-45, 45), (-70, 7), lambda x, z, h, dp: (dp > 3) & ~combate(x, z) & ((np.abs(x) > 9) | (z < -8)), 3)
    out['pedra'] = scatter(60, (-35, 35), (-50, 9), lambda x, z, h, dp: (dp > 1.5) & ~(((x - 1.0) ** 2 / 30 + (z + 0.5) ** 2 / 12) < 1.0) & ~((z > 2.5) & (np.abs(x - 0.6) < 9)) & ~((z > -12) & (z < 3) & (np.abs(x - 1) < 12)), 4)
    out['afogada'] = scatter(40, (-30, 30), (-40, 9), lambda x, z, h, dp: (h < -0.15), 5)
    # pedras de pisar (trilha opcional até o farol)
    out['degraus'] = [[float(x), float(altura(x, z)) + 0.05, float(z), float(i * 0.7), 0.55] for i, (x, z) in enumerate(DEGRAUS)]
    # postes de lanterna ao longo do ramal e da passarela da Wain
    post = []
    for (x, z) in ((9.9, -3.0), (12.0, -8.4), (14.3, -12.6), (16.7, -17.4), (2.3, -12.0), (2.9, -19.5), (-4.0, 8.5)):
        post.append([x + 0.75, float(altura(x + 0.75, z)), z, 0.3, 1.0])
    out['poste'] = post
    out['ruina'] = [RUINA[0], float(altura(*RUINA)), RUINA[1], 0.35, 1.0]
    out['carroca'] = [CARROCA[0], float(altura(*CARROCA)), CARROCA[1], 1.25, 1.0]
    out['capela'] = [CAPELA[0], float(altura(*CAPELA)) - 0.4, CAPELA[1], 0.25, 1.0]
    # restos: poças de cera, cascas de Fuligentos apagados e estandartes rasgados
    restos = lambda x, z, h, dp: (dp > 0.8) & (h > -0.05)
    out['poca_cera'] = scatter(7, (-6, 9), (-5, 4), restos, 21)
    out['casca'] = scatter(9, (-7, 10), (-6, 4), restos, 22)
    out['estandarte_caido'] = scatter(3, (-6, 9), (-5, 3), restos, 23)
    # primeiro plano: touceiras altas nas bordas de baixo
    out['junco_alto'] = [[x, float(altura(x, z)), z, r, s_] for (x, z, r, s_) in ((-4.6, 5.0, 0.3, 1.2), (-3.1, 5.7, 1.4, 1.0), (-5.8, 4.5, 2.1, 1.1), (6.0, 5.1, 0.8, 1.15), (7.3, 4.6, 2.6, 1.0), (5.0, 5.8, 1.9, 0.9))]
    out['passarela_pts'] = PASS
    out['agua_y'] = AGUA_Y
    json.dump(out, open(os.path.join(PROJ, 'assets', 'mundo.json'), 'w'))
    print({k: len(v) for k, v in out.items() if isinstance(v, list)})

T0 = time.time()
todo = [('terreno', build_terreno), ('junco', build_junco), ('capim', build_capim), ('arvore', lambda: [build_arvore(k) for k in range(3)]),
        ('pedra', lambda: [build_pedra(k) for k in range(3)]), ('afogada', build_lanterna_afogada), ('passarela', build_passarela),
        ('wain', build_wain), ('estandarte', build_estandarte), ('graxo', build_graxo), ('farol', build_farol), ('torre', build_torre),
        ('gigante', build_gigante), ('ruina', build_ruina), ('carroca', build_carroca), ('poste', build_poste), ('capela', build_capela),
        ('restos', build_restos), ('junco_alto', build_junco_alto), ('inst', instancias)]
for n, fn in todo:
    if only and n not in only:
        continue
    fn()
print('cenario', round(time.time() - T0, 1), 's')

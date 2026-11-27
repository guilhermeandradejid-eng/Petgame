# Gerador paramétrico de boneco de mamulengo (madeira talhada + roupa de chita), só bpy/bmesh.
# Peças rígidas de madeira presas a um osso cada (como boneco articulado de verdade),
# roupa de chita com pesos misturados, casca de contorno gerada junto (material "contorno",
# espessura por vertex group "contorno" gravada no alfa da cor de vértice).
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler, Quaternion

def srgb2lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def hexc(h, a=1.0):
    h = h.lstrip('#')
    return tuple(srgb2lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (a,)

INK = '#1E1A1C'
MAT = {'madeira': 0, 'chita': 1, 'contorno': 2}

BONES = [  # nome, cabeça, cauda, pai
    ('root', (0, 0, 0), (0, 0, 0.15), None),
    ('hips', (0, 0, 0.60), (0, 0, 0.75), 'root'),
    ('spine', (0, 0, 0.75), (0, 0, 0.86), 'hips'),
    ('chest', (0, 0, 0.86), (0, 0, 0.98), 'spine'),
    ('neck', (0, 0, 0.98), (0, 0, 1.10), 'chest'),
    ('head', (0, 0, 1.10), (0, 0, 1.45), 'neck'),
    ('jaw', (0, 0.06, 1.17), (0, -0.12, 1.12), 'head'),
    ('hat', (0, 0, 1.56), (0, 0, 1.75), 'head'),
    ('shoulder.L', (0.05, 0, 0.95), (0.20, 0, 0.95), 'chest'),
    ('upperarm.L', (0.20, 0, 0.95), (0.31, 0, 0.75), 'shoulder.L'),
    ('forearm.L', (0.31, 0, 0.75), (0.38, -0.02, 0.57), 'upperarm.L'),
    ('hand.L', (0.38, -0.02, 0.57), (0.41, -0.03, 0.47), 'forearm.L'),
    ('shoulder.R', (-0.05, 0, 0.95), (-0.20, 0, 0.95), 'chest'),
    ('upperarm.R', (-0.20, 0, 0.95), (-0.31, 0, 0.75), 'shoulder.R'),
    ('forearm.R', (-0.31, 0, 0.75), (-0.38, -0.02, 0.57), 'upperarm.R'),
    ('hand.R', (-0.38, -0.02, 0.57), (-0.41, -0.03, 0.47), 'forearm.R'),
    ('weapon', (-0.40, -0.04, 0.51), (-0.40, -0.30, 0.75), 'hand.R'),
    ('thigh.L', (0.09, 0, 0.60), (0.10, 0, 0.34), 'hips'),
    ('shin.L', (0.10, 0, 0.34), (0.10, 0.0, 0.09), 'thigh.L'),
    ('foot.L', (0.10, 0.0, 0.09), (0.10, -0.15, 0.03), 'shin.L'),
    ('thigh.R', (-0.09, 0, 0.60), (-0.10, 0, 0.34), 'hips'),
    ('shin.R', (-0.10, 0, 0.34), (-0.10, 0.0, 0.09), 'thigh.R'),
    ('foot.R', (-0.10, 0.0, 0.09), (-0.10, -0.15, 0.03), 'shin.R'),
    ('skirt.F', (0, -0.16, 0.66), (0, -0.30, 0.40), 'hips'),
    ('skirt.B', (0, 0.16, 0.66), (0, 0.30, 0.40), 'hips'),
]

class Builder:
    def __init__(self, seed, outline=0.018):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new('Col')
        self.uv = self.bm.loops.layers.uv.new('UVMap')
        self.dl = self.bm.verts.layers.deform.verify()
        self.groups = [b[0] for b in BONES] + ['contorno']
        self.rng = random.Random(seed)
        self.outline = outline

    def piece(self, tmp, mat='madeira', color='#D9A06B', bone='head', weights=None,
              jitter=0.012, smooth=False, oline=1.0, colorfn=None, uvfn=None, hull=True):
        """Copia um bmesh temporário (já transformado) para a malha final, com cor por face,
        pesos e a casca de contorno."""
        tmp.normal_update()
        if jitter > 0:  # facetas de talho: ruído com semente fixa ao longo da normal
            for v in tmp.verts:
                v.co += v.normal * (self.rng.uniform(-1, 1) * jitter)
            tmp.normal_update()
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
                nf.material_index = MAT['contorno'] if is_hull else MAT[mat]
                nf.smooth = True if is_hull else smooth
                c = colorfn(f) if (colorfn and not is_hull) else color
                rgba = hexc(INK, oline) if is_hull else hexc(c)
                uvs = [uvfn(lo.vert.co) for lo in nf.loops] if (uvfn and not is_hull) else None
                if uvs:
                    us = [u for u, _ in uvs]
                    span = getattr(uvfn, 'rep', 1.0)
                    if max(us) - min(us) > span / 2:
                        uvs = [(u + span if u < span / 2 else u, v) for u, v in uvs]
                for i, lo in enumerate(nf.loops):
                    lo[self.col] = rgba
                    if uvs:
                        lo[self.uv].uv = uvs[i]
        tmp.free()

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
        if kw.get('cast'):
            for v in bm.verts:
                v.co = v.co.lerp(v.co.normalized() * 1.25, kw['cast'])
        if kw.get('bevel'):
            bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=kw['bevel'], segments=1, affect='EDGES')
    elif kind == 'cyl':
        bmesh.ops.create_cone(bm, cap_ends=True, segments=kw.get('seg', 8), radius1=kw.get('r1', 1.0), radius2=kw.get('r2', 1.0), depth=2.0)
    return bm

def place(bm, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0)):
    M = Matrix.Translation(loc) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4() @ Matrix.Diagonal((*scale, 1))
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

def lathe(profile, seg_n=20, axis_fn=None, wave=0.0, wave_n=6):
    """Torno: perfil (raio, z) em volta do eixo Z. Só a casca (aberta embaixo)."""
    bm = bmesh.new()
    rings = []
    for i, (r, z) in enumerate(profile):
        ring = []
        for j in range(seg_n):
            th = 2 * math.pi * j / seg_n
            zz = z + (wave * math.sin(wave_n * th) if i == len(profile) - 1 else 0)
            ring.append(bm.verts.new((r * math.cos(th), r * math.sin(th), zz)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for j in range(seg_n):
            a, b = rings[i][j], rings[i][(j + 1) % seg_n]
            c, d = rings[i + 1][(j + 1) % seg_n], rings[i + 1][j]
            bm.faces.new([a, d, c, b])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm

def cyl_uv(rep=2.0, vs=1.6, z0=0.0):
    def f(co):
        u = (math.atan2(co.y, co.x) / (2 * math.pi) + 0.5) * rep
        return (u, (co.z - z0) * vs)
    f.rep = rep
    return f

def arm_joints(P, sx):
    hx = P.get('hunch', 0.0); sw = P.get('shoulder_w', 1.0); la = P.get('arm_len', 1.0)
    sh = Vector((sx * 0.19 * sw, -hx * 0.5, 0.95)); el = Vector((sx * 0.31 * sw, -hx * 0.4, 0.75)); wr = Vector((sx * 0.38 * sw, -0.02 - hx * 0.3, 0.57))
    el = sh + (el - sh) * la; wr = el + (wr - el) * la
    return sh, el, wr, wr + (wr - el).normalized() * 0.06

def skeleton(P):
    hx = P.get('hunch', 0.0)
    J = {n: [Vector(h), Vector(t), p] for n, h, t, p in BONES}
    J['neck'][0] = Vector((0, -hx * 0.5, 0.98)); J['neck'][1] = Vector((0, -hx * 0.8, 1.10))
    for n in ('head', 'jaw', 'hat'):
        J[n][0] = J[n][0] + Vector((0, -hx, -hx * 0.6)); J[n][1] = J[n][1] + Vector((0, -hx, -hx * 0.6))
    for s, sx in (('L', 1), ('R', -1)):
        sh, el, wr, hd = arm_joints(P, sx)
        J['shoulder.' + s][0] = Vector((sx * 0.05, -hx * 0.5, 0.95)); J['shoulder.' + s][1] = sh
        J['upperarm.' + s][:2] = [sh, el]; J['forearm.' + s][:2] = [el, wr]; J['hand.' + s][:2] = [wr, hd + (wr - el).normalized() * 0.05]
    hd = arm_joints(P, -1)[3]
    J['weapon'][:2] = [hd, hd + Vector((0, -0.04, -0.34))]
    return J

def build(P):
    """P: dict de parâmetros (ver HERO, ENEMY)."""
    B = Builder(P['seed'], outline=P.get('outline', 0.018))
    B.J = skeleton(P)
    wood, wood2 = P['wood'], P['wood_dark']
    hx = P.get('hunch', 0.0)  # deslocamento da cabeça para a frente (corcunda)
    # ---- cabeça talhada
    hc = Vector((0, -hx, 1.38 - hx * 0.6))
    if P['head'] == 'talhada':
        h = place(mk('cube', cuts=2, cast=0.72), hc, (0.18, 0.165, 0.20))
        for v in h.verts:  # queixo achatado e testa larga
            if v.co.z < hc.z - 0.08:
                v.co.x *= 0.86
        B.piece(h, color=wood, bone='head', jitter=0.010)
        B.piece(place(mk('cyl', seg=6, r1=1.0, r2=0.25), hc + Vector((0, -0.2, -0.01)), (0.045, 0.045, 0.06), (90, 0, 0)), color=wood2, bone='head', jitter=0.004, oline=0.5)
        # orelhas
        for s in (1, -1):
            B.piece(place(mk('sphere', u=6, v=4), hc + Vector((s * 0.2, 0.01, 0.0)), (0.03, 0.045, 0.06)), color=wood2, bone='head', jitter=0.003, oline=0.6)
    else:  # cabaça
        lo = place(mk('sphere', u=12, v=8), hc + Vector((0, 0, -0.03)), (0.2, 0.19, 0.17))
        def gourd_col(f):
            z = f.calc_center_median().z
            return INK if abs(((z - hc.z) * 22) % 2 - 1) < 0.22 else P['gourd']
        B.piece(lo, color=P['gourd'], bone='head', jitter=0.006, colorfn=gourd_col)
        B.piece(place(mk('sphere', u=10, v=6), hc + Vector((0, 0.03, 0.17)), (0.11, 0.11, 0.11)), color=P['gourd'], bone='head', jitter=0.005)
        B.piece(place(mk('cyl', seg=6, r1=1, r2=0.6), hc + Vector((0.02, 0.04, 0.30)), (0.025, 0.025, 0.05), (0, 18, 0)), color=wood2, bone='head', jitter=0.0, oline=0.6)
    # boca (interior escuro), maxilar articulado
    B.piece(place(mk('cube'), hc + Vector((0, -0.02, -0.205)), (0.10, 0.12, 0.022)), color='#5A1520', bone='head', jitter=0, hull=False)
    jaw = place(mk('cube', cuts=1, cast=0.5), hc + Vector((0, -0.03, -0.265)), (0.14, 0.135, 0.05))
    B.piece(jaw, color=wood if P['head'] == 'talhada' else P['gourd'], bone='jaw', jitter=0.006)
    if P.get('teeth'):
        for s in (-0.06, 0, 0.06):
            B.piece(place(mk('cyl', seg=4, r1=1, r2=0.05), hc + Vector((s, -0.15, -0.205)), (0.02, 0.02, 0.03)), color='#F4EFE4', bone='jaw', jitter=0, oline=0.4)
    # ---- rosto pintado (peças finas, sem casca)
    fy = hc.y - 0.178
    if P['eyes'] == 2:
        for s in (1, -1):
            B.piece(place(mk('sphere', u=8, v=5), (s * 0.072, fy, hc.z + 0.03), (0.05, 0.016, 0.042)), color='#F4EFE4', bone='head', jitter=0, hull=False)
            B.piece(place(mk('sphere', u=6, v=4), (s * 0.066, fy - 0.012, hc.z + 0.025), (0.022, 0.01, 0.026)), color=INK, bone='head', jitter=0, hull=False)
            B.piece(place(mk('cube'), (s * 0.08, fy - 0.004, hc.z + 0.095), (0.055, 0.012, 0.014), (0, s * -14, 0)), color=INK, bone='head', jitter=0, hull=False)
            B.piece(place(mk('sphere', u=6, v=4), (s * 0.125, fy + 0.04, hc.z - 0.07), (0.04, 0.014, 0.03), (0, 0, s * 35)), color=P['cheek'], bone='head', jitter=0, hull=False)
        if P.get('mustache'):
            for s in (1, -1):
                B.piece(place(mk('sphere', u=6, v=4), (s * 0.06, fy - 0.02, hc.z - 0.10), (0.07, 0.02, 0.025), (0, s * 20, 0)), color=INK, bone='head', jitter=0.002, oline=0.4)
    else:
        B.piece(place(mk('sphere', u=10, v=6), (0, hc.y - 0.188, hc.z + 0.02), (0.075, 0.02, 0.06)), color='#F2C230', bone='head', jitter=0, hull=False)
        B.piece(place(mk('cube'), (0, hc.y - 0.205, hc.z + 0.02), (0.012, 0.008, 0.05)), color=INK, bone='head', jitter=0, hull=False)
    # ---- chapéu (silhueta muda por jogador)
    hat = P.get('hat')
    ht = hc + Vector((0, 0, 0.19))
    if hat == 'palha':
        def brim(f):
            a = math.atan2(f.calc_center_median().y, f.calc_center_median().x)
            return P['hat_c1'] if int((a + 4) * 4) % 2 else P['hat_c2']
        B.piece(place(mk('cyl', seg=16), ht, (0.33, 0.33, 0.014), (-6, 0, 0)), color=P['hat_c1'], bone='hat', jitter=0.004, colorfn=brim)
        B.piece(place(mk('cyl', seg=10, r1=1, r2=0.8), ht + Vector((0, 0, 0.08)), (0.16, 0.16, 0.07)), color=P['hat_c1'], bone='hat', jitter=0.004)
        B.piece(place(mk('cyl', seg=10), ht + Vector((0, 0, 0.03)), (0.165, 0.165, 0.022)), color=P['hat_c3'], bone='hat', jitter=0, oline=0.4)
    elif hat == 'cone':  # chapéu de reisado: cone alto com espelhinhos
        def cone_c(f):
            z = f.calc_center_median().z
            return P['hat_c2'] if int((z - ht.z) * 18) % 2 else P['hat_c1']
        B.piece(place(mk('cyl', seg=10, r1=1, r2=0.08), ht + Vector((0, 0.02, 0.2)), (0.16, 0.16, 0.24), (-8, 0, 0)), color=P['hat_c1'], bone='hat', jitter=0.004, colorfn=cone_c)
        B.piece(place(mk('sphere', u=8, v=5), ht + Vector((0, 0.06, 0.46)), (0.05, 0.05, 0.05)), color=P['hat_c3'], bone='hat', jitter=0)
    elif hat == 'meialua':  # chapéu de couro em meia-lua com estrela pintada
        bm = mk('cyl', seg=12, r1=1, r2=1)
        for v in bm.verts:
            v.co.z += 0.9 * (1 - abs(v.co.x)) * (1 if v.co.z > 0 else 0.6)
        place(bm, ht + Vector((0, 0, 0.06)), (0.30, 0.10, 0.10))
        B.piece(bm, color=P['hat_c1'], bone='hat', jitter=0.004)
        B.piece(place(mk('cyl', seg=5, r1=1, r2=1), ht + Vector((0, -0.105, 0.12)), (0.05, 0.05, 0.006), (90, 0, 0)), color=P['hat_c3'], bone='hat', jitter=0, hull=False)
    elif hat == 'flores':  # coroa de flores de papel
        for k in range(7):
            a = k / 7 * 2 * math.pi
            B.piece(place(mk('ico', sub=1), ht + Vector((math.cos(a) * 0.15, math.sin(a) * 0.14, -0.02 + 0.03 * math.sin(3 * a))), (0.055, 0.055, 0.04)), color=[P['hat_c1'], P['hat_c2'], P['hat_c3']][k % 3], bone='hat', jitter=0.006, oline=0.7)
    # ---- pescoço
    B.piece(seg(mk('cyl', seg=8), (0, -hx * 0.5, 0.97), (0, -hx * 0.8, 1.13), 0.055), color=wood2, bone='neck', jitter=0.003)
    # ---- roupa de chita (torno), pesos misturados
    sw = P.get('shoulder_w', 1.0)
    prof = [(0.07, 1.03), (0.16 * sw, 0.985), (0.19 * sw, 0.93), (0.18, 0.82), (0.17, 0.72), (0.23, 0.60), (0.29, 0.48), (0.32, 0.40)]
    dress = lathe(prof, seg_n=20, wave=0.018, wave_n=7)
    for v in dress.verts:
        v.co.y -= hx * max(0, (v.co.z - 0.8) / 0.2)
    def dress_w(co):
        z = co.z
        if z >= 0.9: return {'chest': 1.0}
        if z >= 0.74:
            t = (z - 0.74) / 0.16; return {'chest': t, 'spine': 1 - t}
        if z >= 0.62:
            t = (z - 0.62) / 0.12; return {'spine': t, 'hips': 1 - t}
        ws = min(1.0, (0.62 - z) / 0.2) * 0.85
        f = 0.5 + 0.5 * max(-1, min(1, -co.y / 0.2))
        return {'hips': 1 - ws, 'skirt.F': ws * f, 'skirt.B': ws * (1 - f)}
    B.piece(dress, mat='chita', color='#FFFFFF', weights=dress_w, jitter=0.0, smooth=True, uvfn=cyl_uv(2.0, 1.8))
    # gola de madeira/franja: tira de cor no decote
    B.piece(lathe([(0.08, 1.045), (0.165 * sw, 0.995), (0.19 * sw, 0.965)], seg_n=20), color=P['collar'], bone='chest', jitter=0.0, smooth=False, oline=0.0)
    # ---- braços: mangas de chita em sino, mãos de madeira
    for side, sx in (('L', 1), ('R', -1)):
        sh, el, wr, hd = arm_joints(P, sx)
        B.piece(place(mk('sphere', u=8, v=5), sh, (0.07, 0.07, 0.07)), mat='chita', color='#FFFFFF', bone='shoulder.' + side, jitter=0, smooth=True, uvfn=cyl_uv(1, 2))
        up = seg(lathe([(0.06, -1), (0.065, 1)], seg_n=10), sh, el, 1.0)
        B.piece(seg(mk('cyl', seg=10, r1=1.0, r2=0.9), sh, el, 0.058), mat='chita', color='#FFFFFF', bone='upperarm.' + side, jitter=0, smooth=True, uvfn=cyl_uv(1, 2))
        up.free()
        B.piece(seg(mk('cyl', seg=10, r1=0.85, r2=1.45), el, wr, 0.055), mat='chita', color='#FFFFFF', bone='forearm.' + side, jitter=0, smooth=True, uvfn=cyl_uv(1, 2))
        B.piece(place(mk('cube', cuts=1, cast=0.6), hd, (0.045, 0.035, 0.06)), color=wood, bone='hand.' + side, jitter=0.004)
        B.piece(place(mk('sphere', u=6, v=4), hd + Vector((-sx * 0.035, -0.03, 0.02)), (0.02, 0.02, 0.03)), color=wood, bone='hand.' + side, jitter=0.002, oline=0.6)
        if P.get('claws'):
            for k in (-1, 0, 1):
                B.piece(seg(mk('cyl', seg=4, r1=1, r2=0.1), hd + Vector((k * 0.025, -0.02, -0.04)), hd + Vector((k * 0.035, -0.06, -0.12)), 0.015), color='#F4EFE4', bone='hand.' + side, jitter=0, oline=0.5)
    # ---- pernas de pau com joelho de bola e botina
    for side, sx in (('L', 1), ('R', -1)):
        hp = Vector((sx * 0.09, 0, 0.60)); kn = Vector((sx * 0.10, 0, 0.34)); an = Vector((sx * 0.10, 0, 0.09))
        B.piece(seg(mk('cyl', seg=7), hp, kn, 0.042), color=wood2, bone='thigh.' + side, jitter=0.003)
        B.piece(place(mk('sphere', u=8, v=5), kn, (0.052, 0.052, 0.052)), color=wood, bone='shin.' + side, jitter=0.003)
        B.piece(seg(mk('cyl', seg=7, r1=0.8, r2=1.0), kn, an, 0.040), color=wood2, bone='shin.' + side, jitter=0.003)
        B.piece(place(mk('cube', bevel=0.25), an + Vector((0, -0.05, -0.045)), (0.055, 0.10, 0.045)), color=P['boot'], bone='foot.' + side, jitter=0.004)
    # ---- arma
    if P.get('weapon') == 'espada':
        a, t = B.J['weapon'][0], B.J['weapon'][1]
        d = (t - a).normalized()
        B.piece(seg(mk('cyl', seg=6), a - d * 0.07, a + d * 0.06, 0.02), color=wood2, bone='weapon', jitter=0)
        g = seg(mk('cube'), a + d * 0.06, a + d * 0.09, 0.075)
        bmesh.ops.scale(g, vec=(0.3, 1, 1), verts=g.verts, space=Matrix.Translation(-(a + d * 0.075)))
        B.piece(g, color=P['hat_c3'], bone='weapon', jitter=0)
        bl = seg(mk('cyl', seg=4, r1=1.0, r2=0.45), a + d * 0.09, a + d * 0.72, 0.065)
        bmesh.ops.scale(bl, vec=(0.4, 1.0, 1), verts=bl.verts, space=Matrix.Translation(-(a + d * 0.4)))
        long_e = [e for e in bl.edges if abs((e.verts[1].co - e.verts[0].co).normalized().dot(d)) > 0.8]
        bmesh.ops.subdivide_edges(bl, edges=long_e, cuts=7, use_grid_fill=False)
        def bands(f):
            k = (f.calc_center_median() - a).dot(d)
            return '#F4EFE4' if int(k * 10) % 2 else P['blade']
        B.piece(bl, color='#F4EFE4', bone='weapon', jitter=0, colorfn=bands)
    return B

def assemble(B, name):
    me = bpy.data.meshes.new(name)
    B.bm.to_mesh(me)
    B.bm.free()
    for mname in ('madeira', 'chita', 'contorno'):
        m = bpy.data.materials.get(mname) or bpy.data.materials.new(mname)
        me.materials.append(m)
    me.color_attributes.active_color_name = 'Col'
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for g in B.groups:
        ob.vertex_groups.new(name=g)
    # armature
    ad = bpy.data.armatures.new(name + '_rig')
    arm = bpy.data.objects.new(name + '_rig', ad)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = {}
    for bn, _, _, p in BONES:
        h, t, _ = B.J[bn]
        b = ad.edit_bones.new(bn)
        b.head, b.tail = h, t
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

def pose_q(arm, bone, rx=0, ry=0, rz=0):
    """Rotação dada nos eixos do armature (X: inclinar p/ frente, Y: rolar, Z: girar)
    convertida para o espaço local do osso."""
    b = arm.data.bones[bone]
    R = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), 'XYZ').to_quaternion()
    Bq = b.matrix_local.to_quaternion()
    return Bq.inverted() @ R @ Bq

def apply_pose(arm, pose):
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    for bn, v in pose.items():
        pb = arm.pose.bones[bn]
        if 'r' in v:
            pb.rotation_quaternion = pose_q(arm, bn, *v['r'])
        if 'l' in v:  # deslocamento em eixos do armature
            b = arm.data.bones[bn]
            pb.location = b.matrix_local.to_3x3().inverted() @ Vector(v['l'])
        if 's' in v:
            pb.scale = v['s']

def key_action(arm, name, frames):
    """frames: lista de (quadro, pose). Chaves CONSTANT (pose segurada)."""
    bpy.context.preferences.edit.keyframe_new_interpolation_type = 'CONSTANT'
    act = bpy.data.actions.new(name)
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = act
    for f, pose in frames:
        apply_pose(arm, pose)
        for pb in arm.pose.bones:
            pb.keyframe_insert('rotation_quaternion', frame=f)
            pb.keyframe_insert('location', frame=f)
            pb.keyframe_insert('scale', frame=f)
    from bpy_extras.anim_utils import action_get_channelbag_for_slot
    nk = 0
    for slot in act.slots:
        cb = action_get_channelbag_for_slot(act, slot)
        for fc in cb.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = 'CONSTANT'; nk += 1
    act['n_keys'] = nk
    act.use_fake_user = True
    tr = arm.animation_data.nla_tracks.new(); tr.name = name
    tr.strips.new(name, int(frames[0][0]), act)
    arm.animation_data.action = None
    return act

# ------------------------------------------------------------------ poses (graus, eixos do armature)
GUARD = {
    'hips': {'l': (0, 0, -0.025)}, 'chest': {'r': (4, 0, -8)}, 'head': {'r': (-4, 0, 6)},
    'upperarm.R': {'r': (-35, 0, 0)}, 'forearm.R': {'r': (-55, 0, 0)}, 'hand.R': {'r': (-10, 0, 0)},
    'upperarm.L': {'r': (-15, 10, 0)}, 'forearm.L': {'r': (-35, 0, 0)},
    'thigh.L': {'r': (-14, 0, 0)}, 'shin.L': {'r': (18, 0, 0)}, 'thigh.R': {'r': (10, 0, 0)}, 'shin.R': {'r': (8, 0, 0)},
    'foot.L': {'r': (-4, 0, 0)}, 'foot.R': {'r': (-16, 0, 0)},
}
def P_(base, **over):
    d = {k: dict(v) for k, v in base.items()}
    for k, v in over.items():
        d[k.replace('_L', '.L').replace('_R', '.R').replace('_F', '.F').replace('_B', '.B')] = v
    return d
ANTIC = P_(GUARD, hips={'l': (0, 0.04, -0.07)}, chest={'r': (-14, 0, -38)}, head={'r': (-20, 0, 12)}, jaw={'r': (28, 0, 0)},
           upperarm_R={'r': (-190, 0, 12)}, forearm_R={'r': (-30, 0, 0)}, hand_R={'r': (25, 0, 0)},
           upperarm_L={'r': (-50, 20, 0)}, forearm_L={'r': (-30, 0, 0)},
           thigh_L={'r': (-30, 0, 0)}, shin_L={'r': (42, 0, 0)}, thigh_R={'r': (18, 0, 0)}, shin_R={'r': (22, 0, 0)},
           skirt_F={'s': (1.12, 0.86, 1.12)}, skirt_B={'s': (1.12, 0.86, 1.12)}, hat={'r': (8, 0, 0)})
STRIKE = P_(GUARD, hips={'l': (0, -0.12, -0.05)}, chest={'r': (26, 0, 28)}, head={'r': (12, 0, -6)}, jaw={'r': (0, 0, 0)},
            upperarm_R={'r': (-80, 0, -10)}, forearm_R={'r': (0, 0, 0)}, hand_R={'r': (10, 0, 0)},
            upperarm_L={'r': (30, -20, 0)}, forearm_L={'r': (-20, 0, 0)},
            thigh_L={'r': (-42, 0, 0)}, shin_L={'r': (30, 0, 0)}, thigh_R={'r': (32, 0, 0)}, shin_R={'r': (6, 0, 0)},
            skirt_F={'r': (22, 0, 0), 's': (0.94, 1.1, 0.94)}, skirt_B={'r': (30, 0, 0), 's': (0.94, 1.12, 0.94)}, hat={'r': (-16, 0, 0)})
FOLLOW = P_(STRIKE, chest={'r': (34, 0, 44)}, head={'r': (18, 0, -10)}, jaw={'r': (14, 0, 0)},
            upperarm_R={'r': (-58, 0, -18)}, hand_R={'r': (0, 0, 0)},
            skirt_F={'r': (34, 0, 0)}, skirt_B={'r': (40, 0, 0)}, hat={'r': (-24, 0, 0)})
RECOV = P_(GUARD, hips={'l': (0, -0.06, -0.035)}, chest={'r': (14, 0, 10)}, head={'r': (4, 0, 0)},
           upperarm_R={'r': (-50, 0, 0)}, forearm_R={'r': (-40, 0, 0)}, skirt_F={'r': (10, 0, 0)}, skirt_B={'r': (14, 0, 0)}, hat={'r': (6, 0, 0)})
IDLE2 = P_(GUARD, hips={'l': (0, 0, -0.04)}, chest={'r': (7, 0, -8)}, head={'r': (-1, 0, 8)}, hat={'r': (4, 0, 0)},
           skirt_F={'s': (1.05, 0.95, 1.05)}, skirt_B={'s': (1.05, 0.95, 1.05)})
HIT = P_(GUARD, hips={'l': (0, 0.08, -0.02)}, chest={'r': (-24, 10, 15)}, head={'r': (-26, 12, 0)}, jaw={'r': (34, 0, 0)},
         upperarm_R={'r': (-70, 0, 30)}, upperarm_L={'r': (-70, 0, -30)}, skirt_F={'r': (-20, 0, 0)}, skirt_B={'r': (-14, 0, 0)}, hat={'r': (20, 0, 0)})

# ataque: 24 quadros a 24 fps, poses em "2s" (no mínimo 2 quadros cada); antecipação longa, contato curto, segura no excesso
ATTACK = [(1, GUARD), (3, P_(GUARD, chest={'r': (-4, 0, -20)}, upperarm_R={'r': (-120, 0, 6)}, hips={'l': (0, 0.02, -0.04)})),
          (5, ANTIC), (9, P_(ANTIC, head={'r': (-24, 0, 14)}, upperarm_R={'r': (-200, 0, 12)})),
          (11, STRIKE), (13, FOLLOW), (17, P_(FOLLOW, chest={'r': (30, 0, 40)}, hat={'r': (-12, 0, 0)})),
          (19, RECOV), (22, GUARD), (24, GUARD)]
IDLE = [(1, GUARD), (7, IDLE2), (13, GUARD), (19, IDLE2), (24, GUARD)]
HITA = [(1, HIT), (5, P_(HIT, chest={'r': (-14, 6, 8)}, jaw={'r': (20, 0, 0)})), (9, GUARD), (12, GUARD)]

HERO = dict(seed=7, head='talhada', eyes=2, mustache=True, wood='#D9A06B', wood_dark='#B9784C', cheek='#D2453C',
            hat='palha', hat_c1='#E0B54A', hat_c2='#C98E2E', hat_c3='#C3253A', collar='#F2C230', boot='#3A2A22',
            weapon='espada', blade='#C3253A')
ENEMY = dict(seed=21, head='cabaca', eyes=1, teeth=True, wood='#9C7A52', wood_dark='#7A5C3C', gourd='#8F7440', cheek='#000000',
             hat=None, collar='#B08A4A', boot='#2A2430', hunch=0.07, shoulder_w=1.25, arm_len=1.18, claws=True)

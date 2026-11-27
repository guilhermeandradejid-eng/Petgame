# Personagens da prova Wickwain: 4 heróis (Rodeira, Pavieiro, Sineira, Gatuno), 2 inimigos (Fuligento, Apagador)
# e a lanterna de mão. Tudo em bmesh, cor base na cor de vértice; o shader decide guache ou gravura.
# Proporção: 2,25 cabeças, 0,9 m. Eixos do Blender: frente = -Y, cima = +Z, esquerda do boneco = +X.
# Família de formas: gota de cera (vivo e quente), chanfro de roda (construído), lasca (Treva).
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler, Quaternion
from malha import *

# ================================================================== formas
def limb(a, b, r0, r1, seg_n=7, n=2.2, bulge=0.0, flat=1.0, rings=4, phase=0.3, cap=True, twist=0.0):
    a, b = Vector(a), Vector(b)
    L = (b - a).length
    R = []
    for i in range(rings):
        t = i / (rings - 1)
        r = r0 + (r1 - r0) * t + bulge * math.sin(math.pi * t)
        R.append((t * L, r, r * flat, 0.0, n))
    bm = loft(R, seg_n=seg_n, cap_bot=cap, cap_top=cap, phase=phase)
    q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
    M = Matrix.Translation(a) @ q.to_matrix().to_4x4() @ Matrix.Rotation(twist, 4, 'Z')
    return xform(bm, M)

def ring_at(rings, z):
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        if a[0] <= z <= b[0]:
            t = (z - a[0]) / max(1e-6, b[0] - a[0])
            return [a[k] + (b[k] - a[k]) * t for k in range(1, 5)]
    r = rings[0] if z < rings[0][0] else rings[-1]
    return list(r[1:5])

def front_pt(rings, x, z, z0=0.0):
    def fy(xx, zz):
        w, d, yo, n = ring_at(rings, zz)
        u = min(0.995, abs(xx) / max(w, 1e-4))
        return yo - d * (1 - u ** n) ** (1 / n)
    p = Vector((x, fy(x, z), z + z0))
    e = 0.004
    px = Vector((x + e, fy(x + e, z), z + z0)); pz = Vector((x, fy(x, z + e), z + e + z0))
    nn = (pz - p).cross(px - p).normalized()
    if nn.y > 0:
        nn = -nn
    return p, nn

def eye_quad(B, center, nrm, w, h, bone, tilt=0.0, mirror=False, base='branco_olho'):
    """olho: quad com UV 0..1; o shader 'olho' desenha branco, pupila, brilho e pálpebra."""
    bm = bmesh.new()
    xa = Vector((0, 0, 1)).cross(nrm).normalized()
    ya = nrm.cross(xa).normalized()
    ca, sa = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
    xa, ya = xa * ca + ya * sa, ya * ca - xa * sa
    N = 3
    vs = {}
    for i in range(N + 1):
        for j in range(N + 1):
            u, v = i / N, j / N
            bul = 0.25 * (1 - (2 * u - 1) ** 2) * (1 - (2 * v - 1) ** 2)
            vs[i, j] = bm.verts.new(center + xa * (u - 0.5) * w + ya * (v - 0.5) * h + nrm * (0.002 + bul * h * 0.25))
    for i in range(N):
        for j in range(N):
            bm.faces.new([vs[i, j], vs[i + 1, j], vs[i + 1, j + 1], vs[i, j + 1]])
    lut = {(round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5)): ((1 - i / N) if mirror else i / N, j / N) for (i, j), v in vs.items()}
    def uvfn(co):
        return lut.get((round(co.x, 5), round(co.y, 5), round(co.z, 5)), (0.5, 0.5))
    B.piece(bm, paint=base, bone=bone, mat='olho', hull=False, uvfn=uvfn)

def disc(center, nrm, r, seg=10, sx=1.0, sy=1.0, depth=0.0):
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=seg, radius=r)
    if depth > 0:
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=depth)
    M = Matrix.Translation(center) @ Vector((0, 0, 1)).rotation_difference(Vector(nrm).normalized()).to_matrix().to_4x4() @ Matrix.Diagonal((sx, sy, 1, 1))
    return xform(bm, M)

def shell(rows, a0, a1, thick=0.012, seg=10, center_y=0.0):
    """Casca aberta (capa, capuz, manto): rows = [(z, raio_x, raio_y, desloc_y)], arco de a0 a a1 (graus; 0 = costas).
    Devolve bmesh com espessura."""
    bm = bmesh.new()
    R = []
    for row in rows:
        z, rx, ry, yo = row[:4]
        b0, b1 = (a0, a1) if len(row) < 5 else (-180 + row[4], 180 - row[4])
        ring = []
        for j in range(seg + 1):
            t = math.radians(b0 + (b1 - b0) * j / seg)
            ring.append(bm.verts.new((rx * math.sin(t), center_y + yo + ry * math.cos(t), z)))
        R.append(ring)
    for i in range(len(R) - 1):
        for j in range(seg):
            bm.faces.new([R[i][j], R[i + 1][j], R[i + 1][j + 1], R[i][j + 1]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    # normais para fora (costas = +Y)
    bm.normal_update()
    out = sum((f.normal.dot(f.calc_center_median() - Vector((0, center_y, f.calc_center_median().z))) for f in bm.faces))
    if out < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=-thick)
    return bm

def mitt(B, side, wr, d, up, s, bone, pose='fist', paint='pele'):
    """luva de 3 dedos: palma em almofada, polegar à parte; punho fechado ou mão aberta."""
    d = Vector(d).normalized(); up = Vector(up).normalized()
    sx = 1 if side == 'L' else -1
    side_v = d.cross(up).normalized() * sx
    M = Matrix((side_v, up, -d)).transposed().to_4x4()
    M = Matrix.Translation(wr) @ M @ Matrix.Diagonal((s, s, s, 1))
    parts = []
    if pose == 'fist':
        parts.append(place(loft([(0.0, 0.04, 0.036, 0, 2.2), (0.03, 0.054, 0.048, 0, 2.6), (0.08, 0.058, 0.052, 0.004, 2.6), (0.11, 0.048, 0.042, 0.006, 2.2)],
                                seg_n=8, phase=0.2), (0, 0, 0), (1, 1, -1)))
        parts.append(place(limb((0.058, 0.03, -0.07), (-0.058, 0.03, -0.07), 0.036, 0.036, seg_n=7, rings=2), (0, 0, 0)))
        parts.append(limb((-0.03, 0.03, -0.02), (-0.062, 0.075, -0.06), 0.024, 0.018, seg_n=6, rings=2))
    else:
        parts.append(place(loft([(0.0, 0.04, 0.024, 0, 2.2), (0.04, 0.056, 0.03, 0, 2.6), (0.09, 0.058, 0.03, 0, 2.6), (0.11, 0.052, 0.026, 0, 2.2)],
                                seg_n=8, phase=0.2), (0, 0, 0), (1, 1, -1)))
        for fx, ang in ((0.034, -8), (-0.002, 0), (-0.038, 9)):
            parts.append(limb((fx, 0.0, -0.1), (fx + math.sin(math.radians(ang)) * 0.075, -0.004, -0.175), 0.019, 0.016, seg_n=6, rings=3, bulge=0.002))
        parts.append(limb((-0.045, -0.005, -0.03), (-0.1, -0.02, -0.078), 0.022, 0.017, seg_n=6, rings=2))
    for bm in parts:
        B.piece(xform(bm, M), paint=paint, bone=bone, jitter=0.0015, oline=0.85)

# ================================================================== cabeça grande, inclinada para a câmera alta
HEAD_TILT = -14.0
def cabeca_grande(B, S, nomes, k=1.0):
    piv = Vector((0, 0, S['headb']))
    M = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(HEAD_TILT), 4, 'X') @ Matrix.Diagonal((k, k, k, 1)) @ Matrix.Translation(-piv)
    for n in nomes:
        B.xf[n] = (M, k)
    B._head_M = M

def cabeca_ossos(B):
    M = B._head_M
    out = []
    for (n, h, t, p) in B.bones:
        if n in B.xf:
            h, t = tuple(M @ Vector(h)), tuple(M @ Vector(t))
        out.append((n, h, t, p))
    B.bones = out
    B.xf = {}

# ================================================================== esqueleto comum (~29 ossos)
def hero_bones(S):
    B = []
    hip, wz, cz, nz, hb, ht = S['hip'], S['waist'], S['chest'], S['neck'], S['headb'], S['headt']
    B.append(('root', (0, 0, 0), (0, 0, 0.08), None))
    B.append(('hips', (0, 0, hip), (0, 0, wz), 'root'))
    B.append(('spine', (0, 0, wz), (0, 0, cz), 'hips'))
    B.append(('chest', (0, 0, cz), (0, 0, nz), 'spine'))
    B.append(('neck', (0, 0, nz), (0, 0, hb), 'chest'))
    B.append(('head', (0, 0, hb), (0, 0, ht), 'neck'))
    B.append(('hat', (0, 0, ht - 0.02), (0, 0, ht + 0.1), 'head'))
    for s, sx in (('L', 1), ('R', -1)):
        sh = Vector((sx * S['shw'], 0, S['shz']))
        el = sh + Vector((sx * S['ua_out'], 0.0, -S['ua']))
        wr = el + Vector((sx * 0.005, -0.02, -S['fa']))
        hc = wr + (wr - el).normalized() * 0.04 * S['hs'] / 0.6
        B.append(('shoulder.' + s, (sx * 0.04, 0, S['shz']), tuple(sh), 'chest'))
        B.append(('upperarm.' + s, tuple(sh), tuple(el), 'shoulder.' + s))
        B.append(('forearm.' + s, tuple(el), tuple(wr), 'upperarm.' + s))
        B.append(('hand.' + s, tuple(wr), tuple(hc + (wr - el).normalized() * 0.03), 'forearm.' + s))
        if s == 'R':
            B.append(('prop', tuple(hc), tuple(hc + Vector((0, -0.15, 0))), 'hand.R'))
        lx = sx * S['legx']
        B.append(('thigh.' + s, (lx, 0, hip), (lx, -0.005, S['knee']), 'hips'))
        B.append(('shin.' + s, (lx, -0.005, S['knee']), (lx, 0.0, S['ankle']), 'thigh.' + s))
        B.append(('foot.' + s, (lx, 0.0, S['ankle']), (lx, -0.08, S['ankle'] - 0.01), 'shin.' + s))
    # capa em duas juntas (molas no motor)
    B.append(('capa1', (0, 0.07, S['shz'] + 0.01), (0, 0.1, (S['shz'] + 0.04) * 0.55), 'chest'))
    B.append(('capa2', (0, 0.1, (S['shz'] + 0.04) * 0.55), (0, 0.14, 0.04), 'capa1'))
    for (n, h, t, p) in S.get('extra', []):
        B.append((n, h, t, p))
    return B

def J(B, n):
    for bn, h, t, p in B:
        if bn == n:
            return Vector(h), Vector(t)
    raise KeyError(n)

def arm_pieces(B, bones, S, side, sleeve, skin, pose='fist', glove=None):
    sx = 1 if side == 'L' else -1
    sh, el = J(bones, 'upperarm.' + side)
    _, wr = J(bones, 'forearm.' + side)
    r = S['arm_r']
    B.piece(limb(sh + Vector((0, 0, 0.01)), el, r * 1.3, r * 0.85, seg_n=7, bulge=r * 0.2, phase=0.2, rings=4), paint=sleeve, bone='upperarm.' + side, jitter=0.001)
    fa = [(0.0, r * 0.88), (0.35, r * 1.05), (1.0, r * 0.7)]
    L = (wr - el).length
    fab = loft([(t * L, rr, rr * 0.92, 0.0, 2.2) for t, rr in fa], seg_n=7, phase=0.5)
    B.piece(xform(fab, Matrix.Translation(el) @ Vector((0, 0, 1)).rotation_difference((wr - el).normalized()).to_matrix().to_4x4()),
            paint=S.get('fa_paint', sleeve), bone='forearm.' + side, jitter=0.001)
    d = (wr - el).normalized()
    up = Vector((-sx, 0, 0))
    mitt(B, side, wr, d, up, S['hs'], 'hand.' + side, pose=pose, paint=glove or skin)

def leg_pieces(B, bones, S, side, pants, boot):
    th, kn = J(bones, 'thigh.' + side)
    _, an = J(bones, 'shin.' + side)
    r = S['leg_r']
    B.piece(limb(th, kn, r * 1.35, r * 0.9, seg_n=7, phase=0.4, rings=3, bulge=r * 0.1), paint=pants, bone='thigh.' + side, jitter=0.001)
    B.piece(limb(kn, an + Vector((0, 0, 0.02)), r * 0.95, r * 0.85, seg_n=7, phase=0.1, rings=3), paint=pants, bone='shin.' + side, jitter=0.001)
    # bota de gota: bico redondo, sola achatada
    bk = S.get('boot_k', 1.0)
    b = loft([(0.0, 0.05 * bk, 0.075 * bk, -0.025 * bk, 2.4), (0.035, 0.052 * bk, 0.078 * bk, -0.028 * bk, 2.4), (0.07, 0.044 * bk, 0.05 * bk, -0.01, 2.2),
              (0.1, 0.036, 0.036, 0.0, 2.0)], seg_n=8)
    B.piece(place(b, (an.x, an.y, 0.0)), paint=boot, bone='foot.' + side, jitter=0.002)

def face(B, S, rings, z0, eye_w=0.075, eye_h=0.085, eye_z=0.13, eye_x=0.062, mouth='sorriso', brow='neutro', brow_col='tinta',
         nose=True, blush=False, mouth_w=0.05, skin='pele'):
    """Rosto de cera talhada: olhos de botão de fuligem (quad; o shader faz o botão, o brilho e a pálpebra),
    sobrancelhas de tinta, nariz de gota, boca, um vinco talhado sob cada olho. Sem bochecha rosada."""
    pe, pn = front_pt(rings, -eye_x, eye_z, z0)
    pd, pnd = front_pt(rings, eye_x, eye_z, z0)
    eye_w, eye_h = eye_w * 0.8, eye_h * 0.8
    eye_quad(B, pe, pn, eye_w, eye_h, 'head', tilt=0)
    eye_quad(B, pd, pnd, eye_w, eye_h, 'head', tilt=0, mirror=True)
    for sx, p in ((-1, pe), (1, pd)):
        c = p + Vector((sx * 0.006, -0.004, -eye_h * 0.62))
        B.piece(limb(c - Vector((0.018, 0, 0.004 * sx)), c + Vector((0.018, 0, -0.004 * sx)), 0.0035, 0.0025, seg_n=4, rings=2), paint='pele_esc', bone='head', oline=0.0, hull=False)
    # sobrancelhas: barras grossas de tinta, ângulo dá a intenção
    ang = {'neutro': (0, 0), 'brava': (-22, 0.0), 'nervoso': (24, 0.01), 'calma': (-6, -0.004), 'safado': (-14, 0.005)}[brow]
    for sx, p in ((-1, pe), (1, pd)):
        c = p + Vector((0, -0.008, eye_h * 0.62 + ang[1]))
        dx = Vector((math.cos(math.radians(ang[0])) * sx, 0, math.sin(math.radians(ang[0])))) * 0.028
        if brow == 'safado' and sx > 0:
            dx = Vector((math.cos(math.radians(8)), 0, math.sin(math.radians(8)))) * 0.028
            c = c + Vector((0, 0, 0.012))
        B.piece(limb(c - dx, c + dx, 0.008, 0.006, seg_n=5, rings=2), paint=brow_col, bone='head', oline=0.0, hull=False)
    if nose:
        pn0, nn0 = front_pt(rings, 0.0, eye_z - 0.035, z0)
        B.piece(place(mk('sphere', u=7, v=5), pn0 + nn0 * 0.008, (0.019, 0.017, 0.016)), paint=skin, bone='head', oline=0.6)
    if blush:
        for sx in (-1, 1):
            pb, nb = front_pt(rings, sx * 0.085, eye_z - 0.06, z0)
            B.piece(disc(pb + nb * 0.004, nb, 0.02, seg=8, sx=1.3, sy=0.8), paint='telha', bone='head', hull=False)
    pm, nm = front_pt(rings, 0.0, eye_z - 0.075, z0)
    if mouth:
        bm = bmesh.new()
        pts = []
        N = 7
        for i in range(N + 1):
            t = i / N
            x = (t - 0.5) * 2 * mouth_w
            if mouth == 'sorriso':
                y0, y1 = 0.01 - 0.4 * (x / mouth_w) ** 2 * 0.02, -0.012 - 0.6 * (1 - (x / mouth_w) ** 2) * 0.03
            elif mouth == 'reta':
                y0, y1 = 0.002, -0.006
            elif mouth == 'aberta':
                y0, y1 = 0.012 - 0.01 * (x / mouth_w) ** 2, -0.03 * (1 - (x / mouth_w) ** 2) - 0.006
            else:  # 'torta' (sorriso de canto)
                y0 = 0.008 + 0.012 * (x / mouth_w); y1 = y0 - 0.012 - 0.018 * max(0, x / mouth_w)
            pts.append((x, y0, y1))
        top = [bm.verts.new((x, 0, y0)) for x, y0, y1 in pts]
        bot = [bm.verts.new((x, 0, y1)) for x, y0, y1 in pts]
        for i in range(N):
            bm.faces.new([top[i], top[i + 1], bot[i + 1], bot[i]])
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.006)
        xa = Vector((0, 0, 1)).cross(nm).normalized(); ya = nm.cross(xa).normalized()
        M = Matrix((xa, nm, ya)).transposed().to_4x4()
        M = Matrix.Translation(pm + nm * 0.004) @ M
        B.piece(xform(bm, M), paint='tinta', bone='head', hull=False)

HEAD_RINGS = [(0.0, 0.085, 0.08, 0.0, 2.0), (0.035, 0.15, 0.135, -0.005, 2.2), (0.1, 0.185, 0.165, -0.004, 2.3), (0.18, 0.192, 0.172, 0.0, 2.3),
              (0.26, 0.178, 0.165, 0.004, 2.2), (0.32, 0.14, 0.135, 0.006, 2.1), (0.355, 0.08, 0.08, 0.008, 2.0), (0.37, 0.02, 0.02, 0.008, 2.0)]

def torso(B, S, paint, k_ombro=1.0, k_barriga=1.0, bone='chest', z0=None):
    z0 = S['hip'] - 0.03 if z0 is None else z0
    rings = [(0.0, 0.10 * k_barriga, 0.085 * k_barriga, 0.0, 2.2), (0.06, 0.12 * k_barriga, 0.1 * k_barriga, -0.004, 2.2),
             (0.13, 0.125 * k_barriga, 0.1 * k_barriga, -0.002, 2.3), (0.19, 0.135 * k_ombro, 0.095, 0.0, 2.6),
             (0.225, 0.11 * k_ombro, 0.08, 0.0, 2.4), (0.25, 0.05, 0.05, 0.0, 2.0)]
    def w(co):
        t = max(0.0, min(1.0, (co.z - S['waist'] + 0.02) / 0.07))
        return {'hips': 1 - t, 'chest': t}
    B.piece(place(loft(rings, seg_n=10, phase=0.31), (0, 0, z0)), paint=paint, weights=w, jitter=0.002)

def capa(B, S, paint, comp=1.0, larg=1.0, abre=1.0, gola=None):
    """capa de jogador: casca do ombro até perto do chão, nas costas; pesos chest -> capa1 -> capa2."""
    top = S['shz'] + 0.03
    rows = [(top, 0.11 * larg, 0.08, 0.0), (top - 0.06, 0.15 * larg, 0.11, 0.01), (top - 0.18, 0.17 * larg * abre, 0.13 * abre, 0.03),
            (top - 0.3 * comp, 0.19 * larg * abre, 0.15 * abre, 0.05), (max(0.05, top - 0.4 * comp), 0.21 * larg * abre, 0.17 * abre, 0.07)]
    bm = shell(rows, -112, 112, thick=0.014, seg=12)
    # barra recortada (pinceladas): sobe e desce
    for v in bm.verts:
        if v.co.z < top - 0.35 * comp:
            v.co.z += 0.02 * math.sin(math.atan2(v.co.x, v.co.y) * 5.0)
    zc = top
    def w(co):
        t = (zc - co.z) / (0.4 * comp)
        if t < 0.2:
            return {'chest': 1.0}
        if t < 0.55:
            a = (t - 0.2) / 0.35
            return {'chest': 1 - a, 'capa1': a}
        a = min(1.0, (t - 0.55) / 0.35)
        return {'capa1': 1 - a, 'capa2': a}
    B.piece(bm, paint=paint, weights=w, jitter=0.002)
    if gola:
        g = loft([(0.0, 0.12 * larg, 0.1, 0.01, 2.0), (0.04, 0.13 * larg, 0.11, 0.012, 2.0), (0.06, 0.1, 0.085, 0.01, 2.0)], seg_n=10, cap_bot=False, cap_top=False)
        bmesh.ops.solidify(g, geom=g.faces[:], thickness=0.012)
        B.piece(place(g, (0, 0, top - 0.04)), paint=gola, bone='chest', jitter=0.002)

def cinto(B, S, paint, z=None, larg=1.0):
    z = S['waist'] - 0.02 if z is None else z
    B.piece(place(loft([(0, 0.125 * larg, 0.105 * larg, 0, 2.3), (0.03, 0.127 * larg, 0.107 * larg, 0, 2.3)], seg_n=10), (0, 0, z)), paint=paint, bone='hips', oline=0.7)

def lanterna_cinto(B, pos, bone='hips', s=0.55):
    """lanterninha de cinto (luz de borda própria do herói)."""
    p = Vector(pos)
    B.piece(place(mk('cyl', seg=8), p, (0.03 * s / 0.55, 0.03 * s / 0.55, 0.04 * s / 0.55)), paint='ambar', bone=bone, mat='emis', hull=False)
    B.piece(place(mk('cyl', seg=8, r2=0.3), p + Vector((0, 0, 0.05 * s / 0.55)), (0.036 * s / 0.55, 0.036 * s / 0.55, 0.015 * s / 0.55)), paint='latao', bone=bone, mat='metal', oline=0.6)
    B.piece(place(mk('cyl', seg=8), p - Vector((0, 0, 0.045 * s / 0.55)), (0.034 * s / 0.55, 0.034 * s / 0.55, 0.008)), paint='latao', bone=bone, mat='metal', oline=0.6)

# ================================================================== RODEIRA (guerreira, Carmim): elmo-panela e roda de carroça
def build_rodeira():
    S = dict(hip=0.2, waist=0.26, chest=0.36, neck=0.44, headb=0.45, headt=0.82, shz=0.42, shw=0.135, ua=0.1, ua_out=0.025,
             fa=0.09, hs=0.9, legx=0.065, knee=0.11, ankle=0.035, arm_r=0.04, leg_r=0.042, boot_k=1.12)
    S['extra'] = [('roda', (0.2, -0.02, 0.26), (0.2, -0.02, 0.5), 'chest'),
                  ('tranca', (0, 0.15, 0.62), (0, 0.2, 0.46), 'head'),
                  ('balde', (-0.15, -0.02, 0.24), (-0.16, -0.02, 0.12), 'hips')]
    bones = hero_bones(S)
    B = Builder(101, [b[0] for b in bones], outline=0.007)
    B.bones = bones; B.S = S
    cabeca_grande(B, S, ['head', 'hat', 'tranca'])
    torso(B, S, 'lona', k_ombro=1.2, k_barriga=1.15)
    # avental de couro com graxa
    av = shell([(S['chest'] + 0.04, 0.12, 0.11, 0.0), (S['waist'], 0.14, 0.125, -0.004), (S['hip'] - 0.02, 0.15, 0.13, -0.004), (0.1, 0.16, 0.14, -0.01)], 125, 235, thick=0.01, seg=8)
    B.piece(av, paint='madeira_clara', weights=lambda co: {'hips': 1.0} if co.z < S['waist'] else {'chest': 1.0}, jitter=0.002)
    B.piece(place(mk('sphere', u=8, v=5), (0.03, -0.135, 0.19), (0.04, 0.012, 0.03)), paint='graxa', bone='hips', hull=False)
    cinto(B, S, 'graxa', larg=1.15)
    capa(B, S, 'carmim', comp=0.95, larg=1.2, gola='carmim_esc')
    # cabeça
    z0 = S['headb']
    B.piece(place(loft(HEAD_RINGS, seg_n=12), (0, 0, z0)), paint='pele', bone='head', jitter=0.005, smooth=False)
    face(B, S, HEAD_RINGS, z0, eye_z=0.12, eye_w=0.07, eye_h=0.075, mouth='sorriso', brow='brava', mouth_w=0.055)
    # trança grossa saindo do elmo
    a, b = J(bones, 'tranca')
    for i in range(4):
        t = i / 4
        B.piece(place(mk('sphere', u=7, v=5), a + (b - a) * t, (0.04 - i * 0.005, 0.035 - i * 0.004, 0.04)), paint='telha', bone='tranca', jitter=0.002, oline=0.8)
    # elmo-panela: panela de ferro emborcada, amassada e torta, cobrindo os olhos até a metade, com o cabo para o lado
    hz = z0 + 0.155
    pan = loft([(0.0, 0.205, 0.195, 0.0, 2.0), (0.02, 0.212, 0.2, 0.0, 2.0), (0.15, 0.2, 0.19, 0.0, 2.0), (0.19, 0.18, 0.17, 0.0, 2.0),
                (0.2, 0.12, 0.11, 0.0, 2.0), (0.205, 0.0, 0.0, 0.0, 2.0)], seg_n=16, cap_bot=False, phase=0.2)
    bmesh.ops.solidify(pan, geom=pan.faces[:], thickness=-0.012)
    for v in pan.verts:  # amassados
        if v.co.x > 0.05 and v.co.z > 0.06 and v.co.y < 0:
            v.co -= Vector((v.co.x, v.co.y, 0)).normalized() * 0.022 * math.exp(-((v.co.z - 0.12) / 0.04) ** 2)
    xform(pan, Matrix.Translation((0, 0.005, hz)) @ Matrix.Rotation(math.radians(9), 4, 'Y') @ Matrix.Rotation(math.radians(-6), 4, 'X'))
    B.piece(pan, paint='estanho', bone='hat', mat='metal', jitter=0.002)   # panela de estanho areado: lê claro contra o lodo e a sombra de contato
    # aba (lábio da panela)
    aba = loft([(0, 0.225, 0.215, 0, 2.0), (0.025, 0.225, 0.215, 0, 2.0)], seg_n=16)
    xform(aba, Matrix.Translation((0, 0.005, hz - 0.005)) @ Matrix.Rotation(math.radians(9), 4, 'Y') @ Matrix.Rotation(math.radians(-6), 4, 'X'))
    B.piece(aba, paint='estanho', bone='hat', mat='metal', oline=0.8)
    # cabo da panela para a direita do quadro
    cab = limb((-0.2, 0.0, 0.03), (-0.39, 0.02, 0.07), 0.022, 0.018, seg_n=6, rings=2)
    xform(cab, Matrix.Translation((0, 0.005, hz)) @ Matrix.Rotation(math.radians(9), 4, 'Y') @ Matrix.Rotation(math.radians(-6), 4, 'X'))
    B.piece(cab, paint='madeira', bone='hat')
    rebite = place(mk('sphere', u=6, v=4), (0.03, -0.17, 0.12), (0.018, 0.012, 0.018))
    xform(rebite, Matrix.Translation((0, 0.005, hz)) @ Matrix.Rotation(math.radians(9), 4, 'Y') @ Matrix.Rotation(math.radians(-6), 4, 'X'))
    B.piece(rebite, paint='latao', bone='hat', mat='metal', oline=0.5)
    # brasão pintado no fundo da panela (o que a câmera alta vê): roda de seis raios em Carmim, a marca da Rodeira
    Mp = Matrix.Translation((0, 0.005, hz)) @ Matrix.Rotation(math.radians(9), 4, 'Y') @ Matrix.Rotation(math.radians(-6), 4, 'X')
    anel = disc(Vector((0, 0, 0.0)), Vector((0, 0, 1)), 0.112, seg=16, depth=0.006)
    B.piece(xform(place(anel, (0, 0, 0.214)), Mp), paint='carmim', bone='hat', hull=False)
    for k in range(3):
        raio = place(mk('cube'), (0, 0, 0.224), (0.095, 0.013, 0.004), rot=(0, 0, k * 60))
        B.piece(xform(raio, Mp), paint='carmim_esc', bone='hat', hull=False)
    B.piece(xform(place(mk('cyl', seg=10), (0, 0, 0.226), (0.03, 0.03, 0.005)), Mp), paint='estanho', bone='hat', hull=False)
    # pescoço curto e grosso
    B.piece(limb((0, 0, S['neck'] - 0.03), (0, 0, S['headb'] + 0.03), 0.05, 0.05, seg_n=7, rings=2), paint='pele', bone='neck')
    # braços fortes: ombreira de couro
    for s, sx in (('L', 1), ('R', -1)):
        sh, el = J(bones, 'upperarm.' + s)
        B.piece(place(mk('sphere', u=8, v=5), sh + Vector((sx * 0.01, 0, 0.01)), (0.06, 0.058, 0.05)), paint='couro', bone='upperarm.' + s, jitter=0.002)
        arm_pieces(B, bones, S, s, 'lona', 'pele', pose='fist' if s == 'R' else 'fist', glove='couro')
        leg_pieces(B, bones, S, s, 'lona_esc', 'graxa')
    # a RODA no braço esquerdo: aro de chanfro (16 faces), aro de ferro, 8 raios, cubo
    c = Vector((0.23, -0.06, 0.34))
    nrm = Vector((0.8, -0.6, 0)).normalized()
    Mw = Matrix.Translation(c) @ Vector((0, 0, 1)).rotation_difference(nrm).to_matrix().to_4x4()
    Rr = 0.37
    aro = bmesh.new()
    segs = 16
    outer, inner = [], []
    for i in range(segs):
        t = 2 * math.pi * (i + 0.5) / segs
        outer.append((math.cos(t) * Rr, math.sin(t) * Rr)); inner.append((math.cos(t) * (Rr - 0.06), math.sin(t) * (Rr - 0.06)))
    vs = []
    for z in (-0.035, 0.035):
        vs.append([aro.verts.new((x, y, z)) for x, y in outer]); vs.append([aro.verts.new((x, y, z)) for x, y in inner])
    o0, i0, o1, i1 = vs
    for i in range(segs):
        j = (i + 1) % segs
        aro.faces.new([o0[i], o0[j], o1[j], o1[i]]); aro.faces.new([i0[j], i0[i], i1[i], i1[j]])
        aro.faces.new([o0[j], o0[i], i0[i], i0[j]]); aro.faces.new([o1[i], o1[j], i1[j], i1[i]])
    bmesh.ops.recalc_face_normals(aro, faces=aro.faces[:])
    B.piece(xform(aro, Mw), paint='madeira', bone='roda', jitter=0.002)
    tire = bmesh.new()
    vs = []
    for rr in (Rr + 0.012, Rr - 0.004):
        for z in (-0.03, 0.03):
            vs.append([tire.verts.new((math.cos(2 * math.pi * (i + 0.5) / segs) * rr, math.sin(2 * math.pi * (i + 0.5) / segs) * rr, z)) for i in range(segs)])
    a0, a1, b0, b1 = vs
    for i in range(segs):
        j = (i + 1) % segs
        tire.faces.new([a0[i], a0[j], a1[j], a1[i]]); tire.faces.new([b0[j], b0[i], b1[i], b1[j]])
        tire.faces.new([a0[j], a0[i], b0[i], b0[j]]); tire.faces.new([a1[i], a1[j], b1[j], b1[i]])
    bmesh.ops.recalc_face_normals(tire, faces=tire.faces[:])
    B.piece(xform(tire, Mw), paint='ferro', bone='roda', mat='metal', oline=0.7)
    for i in range(8):
        t = 2 * math.pi * i / 8 + 0.2
        sp = limb((math.cos(t) * 0.07, math.sin(t) * 0.07, 0), (math.cos(t) * (Rr - 0.04), math.sin(t) * (Rr - 0.04), 0), 0.022, 0.016, seg_n=6, rings=2)
        B.piece(xform(sp, Mw), paint='madeira_clara', bone='roda', jitter=0.002, oline=0.8)
    hub = place(mk('cyl', seg=8), (0, 0, 0), (0.085, 0.085, 0.06))
    B.piece(xform(hub, Mw), paint='madeira_clara', bone='roda', jitter=0.002)
    cap_ = place(mk('cyl', seg=8, r2=0.6), (0, 0, 0.07), (0.05, 0.05, 0.03))
    B.piece(xform(cap_, Mw), paint='ferro', bone='roda', mat='metal', oline=0.7)
    # balde de graxa na anca direita, com alça e graxa escorrendo
    bp = Vector((-0.16, -0.03, 0.16))
    B.piece(place(mk('cyl', seg=10, r2=0.82), bp, (0.06, 0.06, 0.06)), paint='ferro', bone='balde', mat='metal', jitter=0.002)
    B.piece(place(mk('cyl', seg=10), bp + Vector((0, 0, 0.055)), (0.05, 0.05, 0.008)), paint='graxa', bone='balde', hull=False)
    B.piece(tube([bp + Vector((0.055, 0, 0.05)), bp + Vector((0.0, 0, 0.12)), bp + Vector((-0.055, 0, 0.05))], [0.007] * 3, seg_n=5), paint='ferro', bone='balde', oline=0.5)
    B.piece(tube([bp + Vector((0.03, -0.055, 0.06)), bp + Vector((0.035, -0.062, 0.0)), bp + Vector((0.03, -0.06, -0.04))], [0.012, 0.01, 0.014], seg_n=5), paint='graxa', bone='balde', oline=0.5)
    lanterna_cinto(B, (0.11, -0.08, 0.2), 'hips')
    cabeca_ossos(B)
    return B

# ================================================================== PAVIEIRO (mago, Ouro velho): chapéu-vela aceso que derrete
def build_pavieiro():
    S = dict(hip=0.22, waist=0.27, chest=0.37, neck=0.45, headb=0.46, headt=0.82, shz=0.43, shw=0.105, ua=0.1, ua_out=0.02,
             fa=0.09, hs=0.82, legx=0.05, knee=0.12, ankle=0.035, arm_r=0.026, leg_r=0.028, boot_k=1.0)
    S['extra'] = [('chama', (0, 0.0, 0.0), (0, 0.0, 0.0), 'hat'), ('barba', (0, -0.15, 0.53), (0, -0.16, 0.4), 'head'),
                  ('manga.L', (0.12, 0, 0.3), (0.14, 0, 0.18), 'forearm.L'), ('manga.R', (-0.12, 0, 0.3), (-0.14, 0, 0.18), 'forearm.R')]
    bones = hero_bones(S)
    # o osso do chapéu e da chama: ao longo da vela
    hb = S['headt']
    bones = [(n, h, t, p) if n not in ('hat', 'chama') else
             ((n, (0, 0.01, hb - 0.05), (0, 0.03, hb + 0.38), 'head') if n == 'hat' else (n, (0, 0.03, hb + 0.4), (0, 0.035, hb + 0.52), 'hat'))
             for (n, h, t, p) in bones]
    B = Builder(202, [b[0] for b in bones], outline=0.007)
    B.bones = bones; B.S = S
    cabeca_grande(B, S, ['head', 'hat', 'chama', 'barba'])
    torso(B, S, 'ouro', k_ombro=0.85, k_barriga=0.9)
    # manto longo em sino (ouro velho), cobre as pernas até a canela
    rows = [(S['waist'] + 0.02, 0.115, 0.1, 0.0), (S['hip'], 0.13, 0.115, 0.0), (0.12, 0.16, 0.14, 0.005), (0.05, 0.18, 0.16, 0.01)]
    sk = shell(rows, -180, 180, thick=0.01, seg=14)
    def w(co):
        t = max(0.0, min(1.0, (S['hip'] - co.z) / 0.15))
        return {'hips': 1.0 - 0.5 * t, 'thigh.L' if co.x > 0 else 'thigh.R': 0.5 * t}
    B.piece(sk, paint='ouro', weights=w, jitter=0.002)
    # barra queimada
    bar = shell([(0.07, 0.172, 0.152, 0.009), (0.045, 0.184, 0.163, 0.011)], -180, 180, thick=0.012, seg=14)
    for v in bar.verts:
        v.co.z += 0.012 * math.sin(math.atan2(v.co.x, v.co.y) * 7)
    B.piece(bar, paint='couro', weights=w, jitter=0.002)
    capa(B, S, 'ouro', comp=0.85, larg=0.95, gola='ouro_esc')
    cinto(B, S, 'couro', larg=0.95)
    # cinto de velas de reserva
    for i, x in enumerate((-0.07, -0.03, 0.01)):
        B.piece(place(mk('cyl', seg=6), (x, -0.112, S['waist'] - 0.04), (0.012, 0.012, 0.035)), paint='cera', bone='hips', oline=0.6)
    z0 = S['headb']
    hr = [(z, w * 0.96, d * 0.96, yo, n) for (z, w, d, yo, n) in HEAD_RINGS]
    B.piece(place(loft(hr, seg_n=12), (0, 0, z0)), paint='pele', bone='head', jitter=0.005, smooth=False)
    face(B, S, hr, z0, eye_z=0.16, eye_w=0.082, eye_h=0.092, eye_x=0.06, mouth='aberta', brow='nervoso', mouth_w=0.03, blush=False)
    # barba de cera escorrida: três gotas compridas
    a, b = J(bones, 'barba')
    for dx, L, r in ((-0.04, 0.11, 0.03), (0.0, 0.15, 0.036), (0.04, 0.1, 0.028)):
        p0 = a + Vector((dx, 0.012, 0.0))
        g = loft([(0.0, r, r * 0.7, 0, 2.0), (L * 0.4, r * 1.05, r * 0.75, 0, 2.0), (L * 0.85, r * 0.55, r * 0.45, 0, 2.0), (L, r * 0.2, r * 0.2, 0, 2.0)], seg_n=7)
        xform(g, Matrix.Translation(p0) @ Matrix.Rotation(math.pi, 4, 'X'))
        B.piece(g, paint='cera', bone='barba', jitter=0.002, smooth=True)
    # bigode de cera
    pm, nm = front_pt(hr, 0.0, 0.11, z0)
    for sx in (-1, 1):
        B.piece(tube([pm + Vector((0, -0.01, 0.0)), pm + Vector((sx * 0.045, -0.012, -0.01)), pm + Vector((sx * 0.075, -0.0, -0.035))], [0.016, 0.013, 0.006], seg_n=6),
                paint='cera', bone='head', oline=0.7)
    # CHAPÉU-VELA: cone de cera amarela com gola derretida, escorridos, pavio e chama
    hz = z0 + 0.25
    cone = loft([(0.0, 0.2, 0.19, 0.0, 2.0), (0.04, 0.175, 0.168, 0.004, 2.0), (0.12, 0.13, 0.125, 0.008, 2.0), (0.24, 0.085, 0.082, 0.014, 2.0),
                 (0.33, 0.055, 0.053, 0.02, 2.0), (0.37, 0.045, 0.044, 0.022, 2.0)], seg_n=14, phase=0.1)
    for v in cone.verts:   # a ponta derretida torta
        if v.co.z > 0.3:
            v.co.z += 0.02 * math.sin(math.atan2(v.co.x, v.co.y) * 3 + 1.0)
    xform(cone, Matrix.Translation((0, 0.008, hz)))
    B.piece(cone, paint='cera', bone='hat', jitter=0.002, smooth=True)
    # gola de cera derretida na aba, com gotas penduradas
    gola = loft([(0, 0.225, 0.215, 0, 2.0), (0.03, 0.215, 0.205, 0, 2.0), (0.05, 0.18, 0.17, 0, 2.0)], seg_n=16)
    B.piece(place(gola, (0, 0.006, hz - 0.03)), paint='cera_esc', bone='hat', jitter=0.003, smooth=True)
    rr = random.Random(7)
    for i in range(9):
        t = 2 * math.pi * i / 9 + 0.3
        L = 0.03 + rr.random() * 0.06
        p = Vector((math.sin(t) * 0.215, 0.006 - math.cos(t) * 0.205, hz - 0.03))
        g = loft([(0.0, 0.018, 0.016, 0, 2.0), (L * 0.6, 0.014, 0.013, 0, 2.0), (L, 0.017, 0.016, 0, 2.0), (L + 0.012, 0.0, 0.0, 0, 2.0)], seg_n=6)
        B.piece(xform(g, Matrix.Translation(p) @ Matrix.Rotation(math.pi, 4, 'X')), paint='cera_esc', bone='hat', oline=0.7, smooth=True)
    for i in range(4):   # escorridos no cone
        t = 2 * math.pi * i / 4 + 0.6
        z = 0.12 + i * 0.05
        r_ = 0.13 - i * 0.02
        p = Vector((math.sin(t) * r_, 0.008 - math.cos(t) * r_ * 0.97, hz + z))
        B.piece(tube([p, p + Vector((math.sin(t) * 0.02, -math.cos(t) * 0.02, -0.07)), p + Vector((math.sin(t) * 0.035, -math.cos(t) * 0.035, -0.11))],
                     [0.016, 0.014, 0.018], seg_n=6), paint='cera_esc', bone='hat', oline=0.6, smooth=True)
    # pavio e chama (gota, emissiva) no osso 'chama'
    top = Vector((0, 0.03, hz + 0.38))
    B.piece(limb(top - Vector((0, 0, 0.02)), top + Vector((0.0, 0.0, 0.04)), 0.007, 0.006, seg_n=5, rings=2), paint='tinta', bone='hat', oline=0.0, hull=False)
    fl = loft([(0.0, 0.0, 0.0, 0, 2.0), (0.012, 0.03, 0.03, 0, 2.0), (0.04, 0.042, 0.042, 0, 2.0), (0.08, 0.03, 0.03, 0, 2.0), (0.12, 0.012, 0.012, 0, 2.0), (0.14, 0.0, 0.0, 0, 2.0)], seg_n=8)
    B.piece(place(fl, top + Vector((0, 0, 0.02))), paint='ambar', bone='chama', mat='emis', hull=False)
    fl2 = loft([(0.0, 0.0, 0.0, 0, 2.0), (0.012, 0.016, 0.016, 0, 2.0), (0.03, 0.022, 0.022, 0, 2.0), (0.055, 0.012, 0.012, 0, 2.0), (0.07, 0.0, 0.0, 0, 2.0)], seg_n=8)
    B.piece(place(fl2, top + Vector((0, -0.012, 0.03))), paint='sebo', bone='chama', mat='emis', hull=False)
    B.piece(limb((0, 0, S['neck'] - 0.03), (0, 0, S['headb'] + 0.03), 0.035, 0.035, seg_n=7, rings=2), paint='pele', bone='neck')
    # braços magros com MANGAS largas em sino (ação secundária)
    for s, sx in (('L', 1), ('R', -1)):
        arm_pieces(B, bones, S, s, 'ouro', 'pele', pose='open' if s == 'L' else 'fist')
        el, wr = J(bones, 'forearm.' + s)
        d = (wr - el).normalized()
        m = loft([(0.0, 0.04, 0.04, 0, 2.0), (0.05, 0.06, 0.058, 0, 2.0), (0.09, 0.085, 0.08, 0.01, 2.0), (0.11, 0.09, 0.085, 0.015, 2.0)], seg_n=10, cap_bot=False, cap_top=False)
        bmesh.ops.solidify(m, geom=m.faces[:], thickness=0.008)
        xform(m, Matrix.Translation(el + d * 0.0) @ Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4())
        B.piece(m, paint='ouro', weights=lambda co, s=s, el=el, d=d: ({'forearm.' + s: 1.0} if (co - el).dot(d) < 0.05 else {'forearm.' + s: 0.3, 'manga.' + s: 0.7}), jitter=0.002)
        # pés pontudos aparecendo sob o manto
        an = J(bones, 'shin.' + s)[1]
        b = loft([(0.0, 0.035, 0.08, -0.035, 2.2), (0.03, 0.035, 0.082, -0.04, 2.2), (0.05, 0.025, 0.04, -0.01, 2.0)], seg_n=8)
        B.piece(place(b, (an.x, an.y, 0.0)), paint='couro', bone='foot.' + s, jitter=0.002)
        B.piece(limb(J(bones, 'thigh.' + s)[0], an + Vector((0, 0, 0.03)), 0.03, 0.025, seg_n=6, rings=2), paint='lona_esc', weights=lambda co, s=s: {'thigh.' + s: 0.5, 'shin.' + s: 0.5})
    cabeca_ossos(B)
    return B

# ================================================================== SINEIRA (clériga, Celeste): sino do tamanho do corpo num cabo
def build_sineira():
    S = dict(hip=0.21, waist=0.27, chest=0.37, neck=0.45, headb=0.46, headt=0.82, shz=0.43, shw=0.12, ua=0.1, ua_out=0.02,
             fa=0.09, hs=0.84, legx=0.055, knee=0.12, ankle=0.035, arm_r=0.032, leg_r=0.034, boot_k=1.0)
    S['extra'] = [('cabo', (-0.12, -0.08, 0.3), (-0.1, 0.62, 0.98), 'hand.R'),
                  ('sino', (-0.1, 0.66, 0.97), (-0.1, 0.66, 0.76), 'cabo'),
                  ('faixa', (0, -0.12, 0.36), (0, -0.14, 0.08), 'chest'),
                  ('ponta', (0, 0.12, 0.98), (0, 0.24, 1.05), 'head')]
    bones = hero_bones(S)
    B = Builder(303, [b[0] for b in bones], outline=0.007)
    B.bones = bones; B.S = S
    cabeca_grande(B, S, ['head', 'hat', 'ponta'])
    torso(B, S, 'lona_esc', k_ombro=1.0, k_barriga=1.0)
    # hábito longo (lona escura) até os pés
    rows = [(S['waist'] + 0.02, 0.12, 0.105, 0.0), (S['hip'], 0.14, 0.12, 0.0), (0.1, 0.165, 0.145, 0.005), (0.035, 0.175, 0.155, 0.008)]
    sk = shell(rows, -180, 180, thick=0.01, seg=14)
    def w(co):
        t = max(0.0, min(1.0, (S['hip'] - co.z) / 0.15))
        return {'hips': 1.0 - 0.5 * t, 'thigh.L' if co.x > 0 else 'thigh.R': 0.5 * t}
    B.piece(sk, paint='lona_esc', weights=w, jitter=0.002)
    # manto celeste
    capa(B, S, 'celeste', comp=0.8, larg=0.95, gola=None)
    # faixa comprida da frente: pano cru com barra celeste (mola)
    a, b = J(bones, 'faixa')
    f = loft([(0.0, 0.045, 0.008, 0, 2.0), (0.14, 0.05, 0.008, 0, 2.0), (0.27, 0.055, 0.008, 0, 2.0), (0.3, 0.05, 0.008, 0, 2.0)], seg_n=6)
    xform(f, Matrix.Translation(a) @ Matrix.Rotation(math.pi, 4, 'X'))
    B.piece(f, paint='sebo', weights=lambda co: {'chest': 1.0} if co.z > 0.3 else {'faixa': 1.0}, jitter=0.001)
    B.piece(place(mk('cube'), a + Vector((0, -0.002, -0.26)), (0.052, 0.01, 0.018)), paint='celeste_esc', bone='faixa', oline=0.6)
    cinto(B, S, 'couro')
    # terço de dentes de lobo
    for i in range(9):
        t = (i / 8 - 0.5) * 2.2
        B.piece(place(mk('cone' if False else 'cyl', seg=5, r2=0.1), (math.sin(t) * 0.12, -math.cos(t) * 0.1 - 0.01, S['chest'] + 0.03 - 0.02 * math.cos(t * 1.5)), (0.008, 0.008, 0.014), rot=(180, 0, 0)),
                paint='osso', bone='chest', oline=0.4)
    # saquinho de sal
    B.piece(place(mk('sphere', u=8, v=6), (0.1, -0.07, S['waist'] - 0.06), (0.04, 0.035, 0.045)), paint='sal', bone='hips', jitter=0.003)
    B.piece(place(mk('cyl', seg=6), (0.1, -0.07, S['waist'] - 0.015), (0.015, 0.015, 0.012)), paint='couro', bone='hips', oline=0.5)
    z0 = S['headb']
    hr = [(z, w * 0.94, d * 0.94, yo, n) for (z, w, d, yo, n) in HEAD_RINGS]
    B.piece(place(loft(hr, seg_n=12), (0, 0, z0)), paint='pele_esc', bone='head', jitter=0.005, smooth=False)
    face(B, S, hr, z0, eye_z=0.13, eye_w=0.07, eye_h=0.07, eye_x=0.058, mouth='reta', brow='calma', mouth_w=0.03, skin='pele_esc')
    # touca branca (moldura do rosto) e CAPUZ PONTUDO celeste com a ponta caída para trás
    tou = shell([(0.29, 0.13, 0.12, 0.0), (0.22, 0.175, 0.16, 0.0), (0.12, 0.185, 0.17, 0.0), (0.02, 0.15, 0.14, 0.01), (-0.04, 0.12, 0.11, 0.02)], -150, 150, thick=0.012, seg=14)
    B.piece(place(tou, (0, 0.012, z0)), paint='osso', bone='head', jitter=0.001)
    cap_rows = [(-0.04, 0.15, 0.14, 0.03, 42), (0.06, 0.2, 0.185, 0.02, 40), (0.17, 0.205, 0.195, 0.02, 36), (0.26, 0.2, 0.19, 0.02, 3), (0.33, 0.17, 0.17, 0.04, 0.5), (0.43, 0.1, 0.1, 0.1, 0.5), (0.58, 0.025, 0.025, 0.22, 0.5)]
    cp = shell(cap_rows, -158, 158, thick=0.014, seg=16)
    for v in cp.verts:   # a borda do capuz avança sobre a testa
        if v.co.y < -0.05 and 0.22 < v.co.z < 0.36:
            v.co.y -= 0.035
    def wc(co):
        t = max(0.0, min(1.0, (co.z - z0 - 0.4) / 0.12))
        return {'head': 1 - t, 'ponta': t}
    B.piece(place(cp, (0, 0.012, z0)), paint='celeste', weights=wc, jitter=0.002, xfb='head')
    B.piece(limb((0, 0, S['neck'] - 0.03), (0, 0, S['headb'] + 0.03), 0.04, 0.04, seg_n=7, rings=2), paint='pele_esc', bone='neck')
    for s in ('L', 'R'):
        arm_pieces(B, bones, S, s, 'lona_esc', 'pele_esc', pose='fist', glove='couro')
        an = J(bones, 'shin.' + s)[1]
        b = loft([(0.0, 0.04, 0.07, -0.025, 2.2), (0.03, 0.042, 0.072, -0.028, 2.2), (0.05, 0.03, 0.04, -0.01, 2.0)], seg_n=8)
        B.piece(place(b, (an.x, an.y, 0.0)), paint='graxa', bone='foot.' + s, jitter=0.002)
    # CABO comprido no ombro direito e SINO de bronze pendurado atrás
    a, b = J(bones, 'cabo')
    B.piece(limb(a, b + (b - a).normalized() * 0.08, 0.028, 0.025, seg_n=7, rings=2), paint='madeira', bone='cabo', jitter=0.002)
    # gancho de ferro na ponta do cabo: o sino fica pendurado nele, atrás do ombro, longe do capuz
    hk = b + (b - a).normalized() * 0.06
    B.piece(tube([hk, hk + Vector((0, 0.03, 0.03)), hk + Vector((0, 0.05, 0.0))], [0.01, 0.01, 0.01], seg_n=5), paint='ferro', bone='cabo', oline=0.5)
    sc, st = J(bones, 'sino')
    B.piece(tube([sc + Vector((0, 0, 0.03)), sc + Vector((0, 0, -0.04))], [0.012, 0.012], seg_n=5), paint='ferro', bone='sino', oline=0.5)
    sino = loft([(0.0, 0.025, 0.025, 0, 2.0), (0.02, 0.075, 0.075, 0, 2.0), (0.08, 0.1, 0.1, 0, 2.0), (0.16, 0.115, 0.115, 0, 2.0), (0.22, 0.15, 0.15, 0, 2.0),
                 (0.25, 0.18, 0.18, 0, 2.0), (0.265, 0.185, 0.185, 0, 2.0)], seg_n=16, cap_bot=True, cap_top=False)
    bmesh.ops.solidify(sino, geom=sino.faces[:], thickness=0.015)
    xform(sino, Matrix.Translation(sc + Vector((0, 0, -0.04))) @ Matrix.Rotation(math.pi, 4, 'X'))
    B.piece(sino, paint='bronze', bone='sino', mat='metal', jitter=0.001, smooth=True)
    B.piece(place(loft([(0, 0.19, 0.19, 0, 2.0), (0.022, 0.192, 0.192, 0, 2.0)], seg_n=16), sc + Vector((0, 0, -0.3))), paint='bronze', bone='sino', mat='metal', oline=0.7)
    B.piece(place(mk('sphere', u=8, v=6), sc + Vector((0, 0, -0.28)), (0.045, 0.045, 0.045)), paint='ferro', bone='sino', mat='metal', oline=0.5)
    cabeca_ossos(B)
    return B

# ================================================================== GATUNO (ladino, Lilás): capuz de orelhas caídas e saco de saque
def build_gatuno():
    S = dict(hip=0.18, waist=0.24, chest=0.34, neck=0.41, headb=0.42, headt=0.78, shz=0.39, shw=0.11, ua=0.09, ua_out=0.03,
             fa=0.085, hs=0.84, legx=0.06, knee=0.1, ankle=0.035, arm_r=0.028, leg_r=0.032, boot_k=1.35)
    S['extra'] = [('saco', (0, 0.14, 0.4), (0, 0.22, 0.7), 'chest'),
                  ('orelha.L', (0.05, 0.14, 0.84), (0.2, 0.5, 0.7), 'head'), ('orelha.R', (-0.05, 0.1, 0.8), (-0.08, 0.2, 0.7), 'head'),
                  ('adaga', (0.14, -0.06, 0.15), (0.18, -0.08, 0.02), 'hand.L')]
    bones = hero_bones(S)
    B = Builder(404, [b[0] for b in bones], outline=0.007)
    B.bones = bones; B.S = S
    cabeca_grande(B, S, ['head', 'hat', 'orelha.L', 'orelha.R'], k=1.06)
    torso(B, S, 'couro', k_ombro=0.95, k_barriga=1.0)
    capa(B, S, 'lilas', comp=0.6, larg=1.0, gola=None)
    cinto(B, S, 'graxa')
    z0 = S['headb']
    hr = HEAD_RINGS
    B.piece(place(loft(hr, seg_n=12), (0, 0, z0)), paint='pele', bone='head', jitter=0.005, smooth=False)
    face(B, S, hr, z0, eye_z=0.14, eye_w=0.085, eye_h=0.09, eye_x=0.064, mouth='torta', brow='safado', mouth_w=0.05)
    # CAPUZ enorme: interior escuro (moldura dos olhos) e as duas pontas caídas como orelhas
    # capuz justo e anguloso (seg baixo = facetas), que sobe para trás até a ponta
    rows = [(-0.03, 0.16, 0.15, 0.03, 44), (0.08, 0.19, 0.18, 0.02, 40), (0.2, 0.195, 0.185, 0.015, 34), (0.28, 0.18, 0.175, 0.03, 3), (0.34, 0.14, 0.14, 0.06, 0.5), (0.4, 0.085, 0.085, 0.1, 0.5), (0.43, 0.03, 0.03, 0.13, 0.5)]
    cp = shell(rows, -150, 150, thick=0.016, seg=9)
    for v in cp.verts:
        if v.co.y < -0.08 and 0.2 < v.co.z < 0.38:
            v.co.y -= 0.05 * min(1.0, (v.co.z - 0.2) / 0.08)
    B.piece(place(cp, (0, 0.0, z0)), paint='lilas', bone='head', jitter=0.002)
    inner = shell([(0.05, 0.18, 0.17, 0.03), (0.2, 0.185, 0.175, 0.02), (0.3, 0.16, 0.155, 0.04)], -146, 146, thick=0.006, seg=9)
    B.piece(place(inner, (0, 0.0, z0)), paint='lilas_esc', bone='head', hull=False)
    # ponta do capuz: uma só, comprida, angular (seção de losango), jogada para trás e para um lado (assimetria)
    a, b = J(bones, 'orelha.L')
    L = (b - a).length + 0.06
    tip = loft([(0.0, 0.11, 0.08, 0, 1.0), (L * 0.3, 0.085, 0.06, 0, 1.0), (L * 0.65, 0.05, 0.035, 0, 1.0), (L * 0.9, 0.018, 0.014, 0, 1.0), (L, 0.0, 0.0, 0, 1.0)], seg_n=4, phase=0.785)
    q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
    B.piece(xform(tip, Matrix.Translation(a - (b - a).normalized() * 0.05) @ q.to_matrix().to_4x4()), paint='lilas', weights=lambda co, a=a: {'head': 0.4, 'orelha.L': 0.6} if (co - a).length < 0.08 else {'orelha.L': 1.0}, jitter=0.002, xfb='head')
    B.piece(limb((0, 0, S['neck'] - 0.03), (0, 0, S['headb'] + 0.03), 0.035, 0.035, seg_n=7, rings=2), paint='pele', bone='neck')
    for s in ('L', 'R'):
        arm_pieces(B, bones, S, s, 'couro', 'pele', pose='fist', glove='graxa')
        leg_pieces(B, bones, S, s, 'lona_esc', 'couro')
    # SACO DE SAQUE nas costas: gota grande e torta, nó no alto, moedas e um castiçal espiando
    sa, sb = J(bones, 'saco')
    bag = loft([(0.0, 0.1, 0.09, 0, 1.8), (0.07, 0.18, 0.16, 0.02, 1.8), (0.17, 0.21, 0.18, 0.03, 1.8), (0.28, 0.18, 0.15, 0.02, 1.8), (0.36, 0.08, 0.08, 0.0, 1.8),
                (0.39, 0.03, 0.03, 0.0, 2.0)], seg_n=10)
    for v in bag.verts:
        v.co += Vector((0.01 * math.sin(v.co.z * 30), 0.008 * math.cos(v.co.z * 25 + v.co.x * 10), 0))
    # corcunda: o saco sobe acima dos ombros e entorta para o lado da ponta do capuz
    xform(bag, Matrix.Translation(sa + Vector((-0.13, 0.12, -0.14))) @ Matrix.Rotation(math.radians(-18), 4, 'X') @ Matrix.Rotation(math.radians(-25), 4, 'Y'))
    B.piece(bag, paint='lona_esc', bone='saco', jitter=0.004, smooth=True)
    so = Vector((-0.22, 0.08, 0.02))
    B.piece(place(mk('sphere', u=7, v=5), sa + so + Vector((0.05, 0.2, 0.18)), (0.06, 0.055, 0.04)), paint='lona_esc', bone='saco', jitter=0.003)
    for i, (dx, dz) in enumerate(((-0.06, 0.17), (0.02, 0.2), (0.09, 0.15))):
        B.piece(disc(sa + so + Vector((dx, 0.18, dz)), Vector((0.2 * dx * 10, 0.3, 1)), 0.035, seg=8, depth=0.008), paint='latao', bone='saco', mat='metal', oline=0.6)
    B.piece(limb(sa + so + Vector((-0.05, 0.18, 0.12)), sa + so + Vector((-0.14, 0.2, 0.34)), 0.014, 0.014, seg_n=6, rings=2), paint='latao', bone='saco', mat='metal', oline=0.6)
    B.piece(place(mk('cyl', seg=8, r2=1.4), sa + so + Vector((-0.145, 0.202, 0.35)), (0.035, 0.035, 0.014)), paint='latao', bone='saco', mat='metal', oline=0.6)
    # alças do saco
    for sx in (1, -1):
        B.piece(tube([(sx * 0.09, -0.08, 0.38), (sx * 0.11, 0.02, 0.41), (sx * 0.1, 0.12, 0.36)], [0.012] * 3, seg_n=5), paint='couro', bone='chest', oline=0.5)
    # rolo de corda no ombro
    rope = bmesh.new()
    bmesh.ops.create_cone(rope, cap_ends=False, segments=10, radius1=1, radius2=1, depth=1)
    rope = loft([(0, 0.085, 0.085, 0, 2.0), (0.02, 0.09, 0.09, 0, 2.0), (0.04, 0.085, 0.085, 0, 2.0)], seg_n=12, cap_bot=False, cap_top=False)
    bmesh.ops.solidify(rope, geom=rope.faces[:], thickness=0.02)
    xform(rope, Matrix.Translation((0.06, 0.0, 0.33)) @ Matrix.Rotation(math.radians(70), 4, 'Y') @ Matrix.Rotation(math.radians(20), 4, 'X'))
    B.piece(rope, paint='madeira_clara', bone='chest', jitter=0.003)
    # adagas: uma na mão direita (osso prop) e outra invertida na esquerda
    def adaga(p0, d, bone, L=0.2):
        d = Vector(d).normalized()
        blade = loft([(0.0, 0.022, 0.006, 0, 2.0), (L * 0.6, 0.02, 0.005, 0, 2.0), (L, 0.0, 0.0, 0, 2.0)], seg_n=6)
        q = Vector((0, 0, 1)).rotation_difference(d)
        B.piece(xform(blade, Matrix.Translation(p0) @ q.to_matrix().to_4x4()), paint='ferro', bone=bone, mat='metal', oline=0.8)
        B.piece(limb(p0 - d * 0.06, p0, 0.014, 0.014, seg_n=6, rings=2), paint='couro', bone=bone, oline=0.6)
        gx = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized()
        B.piece(limb(p0 - gx * 0.04, p0 + gx * 0.04, 0.01, 0.01, seg_n=5, rings=2), paint='latao', bone=bone, mat='metal', oline=0.6)
    ph, pt = J(bones, 'prop')
    adaga(ph + Vector((0, -0.02, 0)), Vector((0, -1, 0.15)), 'prop')
    a, b = J(bones, 'adaga')
    adaga(a, b - a, 'adaga', L=0.16)
    lanterna_cinto(B, (-0.1, -0.06, 0.18), 'hips', s=0.45)
    cabeca_ossos(B)
    return B

HEROES = {'rodeira': build_rodeira, 'pavieiro': build_pavieiro, 'sineira': build_sineira, 'gatuno': build_gatuno}

# ================================================================== FULIGENTO (comum): bicho de fuligem e lascas, dois olhos brancos
def build_fuligento():
    bones = [('root', (0, 0, 0), (0, 0, 0.08), None), ('corpo', (0, 0.05, 0.3), (0, -0.05, 0.6), 'root'), ('cabeca', (0, -0.08, 0.55), (0, -0.16, 0.8), 'corpo'),
             ('cauda', (0, 0.22, 0.32), (0, 0.45, 0.28), 'corpo')]
    for s, sx in (('L', 1), ('R', -1)):
        bones.append(('braco.' + s, (sx * 0.17, -0.12, 0.45), (sx * 0.24, -0.28, 0.08), 'corpo'))
        bones.append(('perna.' + s, (sx * 0.14, 0.12, 0.3), (sx * 0.18, 0.1, 0.0), 'corpo'))
    B = Builder(505, [b[0] for b in bones], outline=0.007)
    B.bones = bones
    rr = random.Random(5)
    # corpo de gota invertida e corcunda, cheio de calombos de fuligem
    rings = [(0.0, 0.14, 0.15, 0.05, 2.0), (0.08, 0.2, 0.22, 0.04, 2.1), (0.18, 0.23, 0.25, 0.02, 2.1), (0.28, 0.22, 0.23, -0.02, 2.0),
             (0.36, 0.19, 0.19, -0.06, 2.0), (0.44, 0.15, 0.15, -0.09, 2.0), (0.5, 0.06, 0.07, -0.1, 2.0)]
    body = loft(rings, seg_n=12)
    for v in body.verts:
        v.co += v.co.normalized() * 0.0 + Vector((0, 0, 0)) + v.normal * rr.uniform(-0.012, 0.02)
    B.piece(place(body, (0, 0, 0.22)), paint='fuligem', weights=lambda co: {'corpo': 1.0} if co.z < 0.55 else {'cabeca': 1.0}, jitter=0.01)
    # olhos grandes no alto da frente (o shader faz o ponto e a fenda)
    for sx in (-1, 1):
        p = Vector((sx * 0.075, -0.255, 0.62)); n = Vector((sx * 0.35, -1, 0.75)).normalized()
        eye_quad(B, p, n, 0.11, 0.11, 'cabeca', mirror=sx > 0)
    # boca rasgada
    bm = bmesh.new()
    pts = [(-0.08, 0.0), (-0.04, -0.02), (0.0, -0.01), (0.04, -0.025), (0.08, 0.0)]
    top = [bm.verts.new((x, 0, z + 0.005)) for x, z in pts]; bot = [bm.verts.new((x, 0, z - 0.02 - 0.015 * (1 - abs(x) / 0.08))) for x, z in pts]
    for i in range(len(pts) - 1):
        bm.faces.new([top[i], top[i + 1], bot[i + 1], bot[i]])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.01)
    xform(bm, Matrix.Translation((0, -0.3, 0.5)) @ Matrix.Rotation(math.radians(-25), 4, 'X'))
    B.piece(bm, paint='telha', bone='cabeca', mat='emis', hull=False)
    # pavio carbonizado no alto da cabeça, com a ponta ainda em brasa (o bicho é uma vela que a Treva apagou)
    wk = [Vector((0.0, -0.06, 0.68)), Vector((0.02, -0.04, 0.8)), Vector((0.07, 0.0, 0.88)), Vector((0.11, 0.05, 0.86))]
    B.piece(tube(wk, [0.022, 0.018, 0.014, 0.01], seg_n=5), paint='tinta', bone='cabeca', oline=0.7)
    B.piece(place(mk('sphere', u=6, v=4), wk[-1], (0.022, 0.022, 0.022)), paint='telha', bone='cabeca', mat='emis', hull=False)
    # cera escorrida: filetes claros que descem pelo corpo de fuligem
    for ang, z0_, L in ((115, 0.66, 0.26), (160, 0.62, 0.2), (215, 0.67, 0.3), (250, 0.6, 0.16), (75, 0.58, 0.14)):
        a_ = math.radians(ang)
        d = Vector((math.sin(a_), math.cos(a_), 0))
        pts = [d * 0.17 + Vector((0, 0, z0_)), d * 0.215 + Vector((0, 0, z0_ - L * 0.45)), d * 0.225 + Vector((0, 0, z0_ - L))]
        B.piece(tube(pts, [0.02, 0.016, 0.022], seg_n=5), paint='cera_esc', weights=lambda co: {'corpo': 1.0} if co.z < 0.55 else {'cabeca': 1.0}, oline=0.6)
    # LASCAS nas costas e na cabeça (triângulos finos e quebrados)
    def lasca(base, d, L, w, bone):
        d = Vector(d).normalized()
        g = loft([(0.0, w, w * 0.45, 0, 1.6), (L * 0.45, w * 0.7, w * 0.32, 0, 1.6), (L * 0.75, w * 0.35, w * 0.2, 0.0, 1.6), (L, 0.0, 0.0, 0, 1.6)], seg_n=4, phase=0.785)
        q = Vector((0, 0, 1)).rotation_difference(d)
        B.piece(xform(g, Matrix.Translation(base) @ q.to_matrix().to_4x4()), paint='fuligem', bone=bone, jitter=0.004)
    for i, (x, y, z, dx, dy, dz, L) in enumerate([(0.0, 0.12, 0.62, 0, 0.6, 1, 0.24), (0.1, 0.16, 0.55, 0.6, 0.8, 0.8, 0.2), (-0.1, 0.16, 0.55, -0.6, 0.8, 0.8, 0.2),
                                                  (0.05, 0.22, 0.42, 0.3, 1, 0.4, 0.17), (-0.06, 0.22, 0.44, -0.3, 1, 0.5, 0.16), (0.12, -0.08, 0.7, 0.4, 0.1, 1, 0.16),
                                                  (-0.12, -0.08, 0.7, -0.4, 0.1, 1, 0.14)]):
        lasca(Vector((x, y, z)), (dx, dy, dz), L, 0.045, 'cabeca' if z > 0.65 else 'corpo')
    # braços de lasca com garras
    for s, sx in (('L', 1), ('R', -1)):
        a, b = J(bones, 'braco.' + s)
        B.piece(limb(a, b, 0.05, 0.02, seg_n=5, rings=3, phase=0.6), paint='fuligem', bone='braco.' + s, jitter=0.005)
        for k in (-1, 0, 1):
            lasca(b + Vector((0, -0.01, 0.02)), (sx * 0.2 + k * 0.4, -1, -0.3), 0.08, 0.016, 'braco.' + s)
        a, b = J(bones, 'perna.' + s)
        B.piece(limb(a, b, 0.06, 0.02, seg_n=5, rings=3, phase=0.6), paint='fuligem', bone='perna.' + s, jitter=0.005)
    a, b = J(bones, 'cauda')
    lasca(a, b - a, 0.28, 0.05, 'cauda')
    return B

# ================================================================== APAGADOR (elite): alto e magro, cabeça de apagador de vela de latão
def build_apagador():
    bones = [('root', (0, 0, 0), (0, 0, 0.1), None), ('hips', (0, 0, 0.75), (0, 0, 0.95), 'root'), ('spine', (0, 0, 0.95), (0, 0, 1.2), 'hips'),
             ('chest', (0, 0, 1.2), (0, 0, 1.4), 'spine'), ('pesc1', (0, 0, 1.42), (0, -0.04, 1.68), 'chest'), ('pesc2', (0, -0.04, 1.68), (0, -0.2, 1.8), 'pesc1'),
             ('cone', (0, -0.2, 1.8), (0, -0.3, 1.72), 'pesc2'), ('manto', (0, 0.1, 1.2), (0, 0.18, 0.4), 'chest')]
    for s, sx in (('L', 1), ('R', -1)):
        bones += [('upperarm.' + s, (sx * 0.17, 0, 1.36), (sx * 0.22, 0.0, 1.02), 'chest'), ('forearm.' + s, (sx * 0.22, 0.0, 1.02), (sx * 0.24, -0.04, 0.7), 'upperarm.' + s),
                  ('hand.' + s, (sx * 0.24, -0.04, 0.7), (sx * 0.25, -0.06, 0.55), 'forearm.' + s),
                  ('thigh.' + s, (sx * 0.09, 0, 0.75), (sx * 0.1, 0, 0.4), 'hips'), ('shin.' + s, (sx * 0.1, 0, 0.4), (sx * 0.1, 0.02, 0.04), 'thigh.' + s)]
    B = Builder(606, [b[0] for b in bones], outline=0.008)
    B.bones = bones
    # túnica preta comprida com barra em lascas
    rows = [(1.42, 0.13, 0.1, 0.0), (1.3, 0.16, 0.12, 0.0), (1.05, 0.14, 0.11, 0.0), (0.8, 0.17, 0.14, 0.01), (0.45, 0.23, 0.2, 0.03), (0.12, 0.29, 0.25, 0.05)]
    rb = shell(rows, -180, 180, thick=0.014, seg=18)
    for v in rb.verts:
        if v.co.z < 0.2:
            a = math.atan2(v.co.x, v.co.y)
            v.co.z += 0.1 * abs(math.sin(a * 4.5)) ** 2.5
    def wr(co):
        if co.z > 1.15:
            return {'chest': 1.0}
        if co.z > 0.8:
            return {'spine': 1.0}
        t = min(1.0, (0.8 - co.z) / 0.6)
        return {'hips': 1 - t * 0.6, 'manto': t * 0.6}
    B.piece(rb, paint='fuligem', weights=wr, jitter=0.006)
    # ombros ossudos e capuz-gola de onde sai o cabo
    B.piece(place(loft([(0, 0.2, 0.13, 0, 2.0), (0.06, 0.18, 0.12, 0, 2.0), (0.1, 0.08, 0.07, 0, 2.0)], seg_n=10), (0, 0, 1.34)), paint='fuligem', bone='chest', jitter=0.006)
    gola = shell([(1.52, 0.07, 0.07, 0.02), (1.44, 0.12, 0.11, 0.02), (1.38, 0.15, 0.13, 0.01)], -170, 170, thick=0.014, seg=12)
    for v in gola.verts:
        if v.co.z > 1.5:
            v.co.z += 0.05 * abs(math.sin(math.atan2(v.co.x, v.co.y) * 3))
    B.piece(gola, paint='fuligem', bone='chest', jitter=0.005)
    # o cabo (pescoço) de latão em dois ossos e o cone de apagador
    for bn in ('pesc1', 'pesc2'):
        a, b = J(bones, bn)
        B.piece(limb(a, b, 0.022, 0.02, seg_n=7, rings=2), paint='latao', bone=bn, mat='metal')
    a, b = J(bones, 'cone')
    cone = loft([(0.0, 0.03, 0.03, 0, 2.0), (0.05, 0.05, 0.05, 0, 2.0), (0.14, 0.11, 0.11, 0, 2.0), (0.24, 0.17, 0.17, 0, 2.0), (0.28, 0.19, 0.19, 0, 2.0)], seg_n=14, cap_bot=True, cap_top=False)
    bmesh.ops.solidify(cone, geom=cone.faces[:], thickness=0.012)
    # o cone pende para a frente, com a boca para baixo e para a frente
    xform(cone, Matrix.Translation(a + Vector((0, -0.01, 0.0))) @ Matrix.Rotation(math.radians(155), 4, 'X'))
    B.piece(cone, paint='latao', bone='cone', mat='metal', jitter=0.002, smooth=True)
    # gancho enrolado no topo do cone e anel de solda
    B.piece(tube([a + Vector((0, 0.0, 0.08)), a + Vector((0, 0.05, 0.15)), a + Vector((0, 0.11, 0.13)), a + Vector((0, 0.1, 0.07))], [0.012, 0.012, 0.01, 0.008], seg_n=5), paint='latao', bone='cone', mat='metal', oline=0.6)
    B.piece(place(loft([(0, 0.04, 0.04, 0, 2.0), (0.025, 0.04, 0.04, 0, 2.0)], seg_n=10), a + Vector((0, -0.01, 0.0))), paint='ferro', bone='cone', mat='metal', oline=0.6)
    # braços compridos, finos, mãos de três garras longas
    for s, sx in (('L', 1), ('R', -1)):
        a, b = J(bones, 'upperarm.' + s)
        B.piece(limb(a, b, 0.045, 0.03, seg_n=6, rings=3), paint='fuligem', bone='upperarm.' + s, jitter=0.004)
        a, b = J(bones, 'forearm.' + s)
        B.piece(limb(a, b, 0.032, 0.02, seg_n=6, rings=3), paint='fuligem', bone='forearm.' + s, jitter=0.004)
        # manga rasgada
        m = loft([(0, 0.05, 0.05, 0, 2.0), (0.12, 0.08, 0.08, 0.0, 2.0), (0.16, 0.09, 0.09, 0, 2.0)], seg_n=8, cap_bot=False, cap_top=False)
        bmesh.ops.solidify(m, geom=m.faces[:], thickness=0.01)
        for v in m.verts:
            if v.co.z > 0.12:
                v.co.z += 0.04 * abs(math.sin(math.atan2(v.co.x, v.co.y) * 3))
        q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
        B.piece(xform(m, Matrix.Translation(a) @ q.to_matrix().to_4x4()), paint='fuligem', bone='forearm.' + s, jitter=0.003)
        a, b = J(bones, 'hand.' + s)
        for k in (-1, 0, 1):
            tip = b + Vector((sx * 0.04 * k, -0.05 + 0.02 * abs(k), -0.12))
            B.piece(tube([a, a + (tip - a) * 0.5 + Vector((0, -0.03, 0)), tip], [0.014, 0.011, 0.004], seg_n=5), paint='fuligem', bone='hand.' + s, oline=0.8)
        a, b = J(bones, 'thigh.' + s)
        B.piece(limb(a, b, 0.05, 0.035, seg_n=6, rings=2), paint='fuligem', bone='thigh.' + s)
        a, b = J(bones, 'shin.' + s)
        B.piece(limb(a, b, 0.035, 0.025, seg_n=6, rings=2), paint='fuligem', bone='shin.' + s)
        B.piece(place(loft([(0, 0.035, 0.1, -0.06, 1.8), (0.03, 0.03, 0.11, -0.07, 1.8), (0.05, 0.0, 0.0, -0.08, 1.8)], seg_n=6), (b.x, b.y, 0.0)), paint='fuligem', bone='shin.' + s)
    return B

ENEMIES = {'fuligento': build_fuligento, 'apagador': build_apagador}

# ================================================================== LANTERNA de mão (prop, sem esqueleto)
def build_lanterna():
    bones = [('root', (0, 0, 0), (0, 0, 0.1), None)]
    B = Builder(707, ['root'], outline=0.006)
    B.bones = bones
    s = 1.0
    B.piece(place(mk('cyl', seg=8), (0, 0, 0.12), (0.075, 0.075, 0.08)), paint='ambar', bone='root', mat='emis', hull=False)
    B.piece(place(mk('cyl', seg=8), (0, 0, 0.12), (0.035, 0.035, 0.05)), paint='sebo', bone='root', mat='emis', hull=False)
    for i in range(8):   # varetas de latão (chanfro)
        t = 2 * math.pi * (i + 0.5) / 8
        B.piece(limb((math.cos(t) * 0.08, math.sin(t) * 0.08, 0.035), (math.cos(t) * 0.08, math.sin(t) * 0.08, 0.205), 0.008, 0.008, seg_n=4, rings=2), paint='latao', bone='root', mat='metal', oline=0.6)
    B.piece(place(mk('cyl', seg=8, r2=0.85), (0, 0, 0.025), (0.1, 0.1, 0.025)), paint='latao', bone='root', mat='metal')
    B.piece(place(mk('cyl', seg=8, r2=0.35), (0, 0, 0.245), (0.105, 0.105, 0.045)), paint='latao', bone='root', mat='metal')
    B.piece(place(mk('cyl', seg=6), (0, 0, 0.3), (0.02, 0.02, 0.02)), paint='latao', bone='root', mat='metal', oline=0.6)
    ring = loft([(0, 0.045, 0.045, 0, 2.0), (0.012, 0.045, 0.045, 0, 2.0)], seg_n=10, cap_bot=False, cap_top=False)
    bmesh.ops.solidify(ring, geom=ring.faces[:], thickness=0.01)
    B.piece(xform(ring, Matrix.Translation((0, 0, 0.36)) @ Matrix.Rotation(math.pi / 2, 4, 'X')), paint='latao', bone='root', mat='metal', oline=0.6)
    return B

PROPS = {'lanterna': build_lanterna}

# ================================================================== montagem
def assemble(B, name, armature=True):
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
    if not armature:
        return None, ob
    ad = bpy.data.armatures.new(name + '_rig')
    arm = bpy.data.objects.new(name + '_rig', ad)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = {}
    for bn, h, t, p in B.bones:
        b = ad.edit_bones.new(bn)
        h, t = Vector(h), Vector(t)
        if (t - h).length < 1e-4:
            t = h + Vector((0, 0, 0.05))
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

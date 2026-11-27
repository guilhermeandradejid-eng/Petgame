# Formas comuns dos bonecos (adaptadas da prova Wickwain): membros, luvas de 3 dedos, rosto de carisma,
# esqueleto de ~29 ossos e cabeça grande inclinada para a câmera alta. Eixos do Blender: frente = -Y, cima = +Z.
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
         nose=True, blush=True, mouth_w=0.05, skin='pele'):
    """Rosto de carisma: olhos grandes (quad), sobrancelhas de tinta, nariz de gota, boca em meia-lua, bochecha."""
    pe, pn = front_pt(rings, -eye_x, eye_z, z0)
    pd, pnd = front_pt(rings, eye_x, eye_z, z0)
    eye_quad(B, pe, pn, eye_w, eye_h, 'head', tilt=0)
    eye_quad(B, pd, pnd, eye_w, eye_h, 'head', tilt=0, mirror=True)
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
            B.piece(disc(pb + nb * 0.004, nb, 0.02, seg=8, sx=1.3, sy=0.8), paint='rubor', bone='head', hull=False, sub=False)
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
        B.piece(xform(bm, M), paint='tinta', bone='head', hull=False, sub=False)

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


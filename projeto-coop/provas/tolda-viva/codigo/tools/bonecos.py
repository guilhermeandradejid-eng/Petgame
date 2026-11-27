# Gerador dos bonecos da Tolda Viva (heróis de luva e pragas), só bpy/bmesh.
# Regras de material: madeira (cabeça, mãos, pernas, adereço) nunca deforma e mostra facetas de talho;
# pano (corpo, mangas, chapéu) é o único que estica; contorno por casca invertida no mesmo GLB;
# olhos em quads com shader próprio (abertura e pupila), sem textura.
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler, Quaternion
from malha import *

# ================================================================== esqueleto dos heróis
def hero_bones(S):
    hz, wz, cz, sz, nz, hb = S['hem'], S['waist'], S['chest'], S['sh'], S['neck'], S['head']
    shw, ua, fa = S['shw'], S['ua'], S['fa']
    hip = S['hip']; kn = S['knee']; an = S['ankle']
    B = []
    B.append(('root', (0, 0, 0), (0, 0, 0.12), None))
    B.append(('hips', (0, 0, hip), (0, 0, wz), 'root'))
    B.append(('spine', (0, 0, wz), (0, 0, cz), 'hips'))
    B.append(('chest', (0, 0, cz), (0, 0, nz), 'spine'))
    B.append(('peito', (0, -0.06, cz - 0.02), (0, -0.06, cz + 0.08), 'chest'))
    B.append(('neck', (0, 0, nz), (0, 0, hb), 'chest'))
    B.append(('head', (0, 0, hb), (0, 0, hb + 0.25), 'neck'))
    B.append(('jaw', (0, 0.08, hb + S.get('jaw_z', 0.09)), (0, -0.10, hb + S.get('jaw_z', 0.09) - 0.02), 'head'))
    B.append(('hat', (0, 0, hb + S['hat_z']), (0, 0, hb + S['hat_z'] + 0.14), 'head'))
    if S.get('cap'):
        for i, (a, b) in enumerate(S['cap']):
            B.append(('cap%d' % (i + 1), a, b, 'hat' if i == 0 else 'cap%d' % i))
    for s, sx in (('L', 1), ('R', -1)):
        sh = Vector((sx * shw, 0, sz))
        el = sh + Vector((sx * 0.045, 0.01, -ua))
        wr = el + Vector((sx * 0.025, -0.03, -fa))
        d = (wr - el).normalized()
        hc = wr + d * 0.05 * S['hs']
        B.append(('shoulder.' + s, (sx * 0.05, 0, sz), tuple(sh), 'chest'))
        B.append(('upperarm.' + s, tuple(sh), tuple(el), 'shoulder.' + s))
        B.append(('forearm.' + s, tuple(el), tuple(wr), 'upperarm.' + s))
        B.append(('hand.' + s, tuple(wr), tuple(hc + d * 0.05), 'forearm.' + s))
        if s == 'R':
            B.append(('prop', tuple(hc), tuple(hc + d * 0.3), 'hand.R'))
            B.append(('smear', tuple(hc), tuple(hc + d * 0.3), 'prop'))
        lx = sx * S['legx']
        B.append(('thigh.' + s, (lx, 0, hip), (lx, -0.01, kn), 'hips'))
        B.append(('shin.' + s, (lx, -0.01, kn), (lx, 0.0, an), 'thigh.' + s))
        B.append(('foot.' + s, (lx, 0.0, an), (lx, -0.12, an - 0.03), 'shin.' + s))
    for s, d in (('F', (0, -1)), ('B', (0, 1)), ('L', (1, 0)), ('R', (-1, 0))):
        r0 = 0.12; r1 = S['hem_r'] * 0.9
        B.append(('skirt.' + s, (d[0] * r0, d[1] * r0, wz - 0.04), (d[0] * r1, d[1] * r1, hz + 0.02), 'hips'))
    # v2: cabeça maior (critica: o rosto sumia na câmera de camarote). Os ossos presos à cabeça
    # escalam em volta da base do crânio; as peças escalam no Builder (head_scale).
    k = S.get('hsc', 1.0)
    if k != 1.0:
        c = Vector((0, 0, hb))
        def sc(p):
            return tuple(c + (Vector(p) - c) * k)
        B = [(n, sc(h), sc(t), p) if (n in ('jaw', 'hat') or n.startswith('cap')) else (n, h, t, p) for n, h, t, p in B]
    return B

def joints(S, B):
    return {n: (Vector(h), Vector(t)) for n, h, t, p in B}

# ================================================================== peças comuns
def ring_at(rings, z):
    """interpola os parâmetros do anel (w, d, yo, n) numa altura z."""
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        if a[0] <= z <= b[0]:
            t = (z - a[0]) / max(1e-6, b[0] - a[0])
            return [a[k] + (b[k] - a[k]) * t for k in range(1, 5)]
    r = rings[0] if z < rings[0][0] else rings[-1]
    return list(r[1:5])

def front_y(rings, x, z):
    w, d, yo, n = ring_at(rings, z)
    u = min(0.999, abs(x) / w)
    return yo - d * (1 - u ** n) ** (1 / n)

def face_normal(rings, x, z, eps=0.004):
    p = Vector((x, front_y(rings, x, z), z))
    px = Vector((x + eps, front_y(rings, x + eps, z), z))
    pz = Vector((x, front_y(rings, x, z + eps), z + eps))
    n = (pz - p).cross(px - p).normalized()
    return p, -n if n.y > 0 else n

def eye_quad(B, center, nrm, w, h, bone, lid='madeira', abertura=1.0, tilt=0.0, mirror=False):
    """olho pintado: quad levemente curvo com UV 0..1; o shader 'olho' desenha amêndoa, pupila e pálpebra.
    cor de vértice = cor da pálpebra; alfa = abertura padrão."""
    bm = bmesh.new()
    up0 = Vector((0, 0, 1))
    xa = up0.cross(nrm).normalized()
    if xa.length < 0.5:
        xa = Vector((1, 0, 0))
    ya = nrm.cross(xa).normalized()
    ca, sa = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
    xa, ya = xa * ca + ya * sa, ya * ca - xa * sa
    N = 4
    vs = {}
    for i in range(N + 1):
        for j in range(N + 1):
            u, v = i / N, j / N
            bulge = 0.25 * (1 - (2 * u - 1) ** 2) * (1 - (2 * v - 1) ** 2)
            p = center + xa * (u - 0.5) * w + ya * (v - 0.5) * h + nrm * (0.004 + bulge * h * 0.25)
            vs[i, j] = bm.verts.new(p)
    uvl = []
    for i in range(N):
        for j in range(N):
            f = bm.faces.new([vs[i, j], vs[i + 1, j], vs[i + 1, j + 1], vs[i, j + 1]])
            uvl.append(f)
    uv = bm.loops.layers.uv.new('t')
    tmpuv = {}
    for (i, j), v in vs.items():
        tmpuv[v] = ((1 - i / N) if mirror else i / N, j / N)
    def uvfn(co):
        best = min(vs.values(), key=lambda v: (v.co - co).length)
        return tmpuv[best]
    B.piece(bm, mat='olho', color=lid, bone=bone, hull=False, uvfn=uvfn)
    # abertura no alfa da cor de vértice
    return

def set_last_alpha(B, a, count):
    pass

def mitt(B, S, side, sx, J, pose='fist'):
    """mão de luva em 3 blocos (polegar, indicador, resto). Punho fechado na mão do adereço."""
    hs = S['hs']
    wr, hd = J['hand.' + side]
    el = J['forearm.' + side][0]
    d = (wr - el).normalized()
    q = Vector((0, 0, -1)).rotation_difference(d)
    M = Matrix.Translation(wr) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((hs, hs, hs, 1))
    wood = S.get('hand_col', 'madeira')
    bone = 'hand.' + side
    parts = []
    if pose == 'fist':
        parts.append((place(mk('cube', bevel=0.35, bseg=2), (0, 0, -0.055), (0.04, 0.047, 0.05)), wood))
        # dedos dobrados: dois rolos na frente
        for k, z in enumerate((-0.035, -0.07)):
            parts.append((place(mk('cyl', seg=8), (0, -0.044, z), (0.019, 0.019, 0.042), (0, 90, 0)), wood))
        parts.append((place(mk('cube', bevel=0.4, bseg=1), (sx * -0.032, -0.03, -0.03), (0.016, 0.03, 0.02), (25, 0, sx * 15)), wood))
    else:
        parts.append((place(mk('cube', bevel=0.4, bseg=2), (0, 0, -0.05), (0.024, 0.052, 0.048)), wood))
        parts.append((place(mk('cube', bevel=0.45, bseg=1), (0, -0.026, -0.112), (0.02, 0.022, 0.04), (-12, 0, 0)), wood))
        parts.append((place(mk('cube', bevel=0.45, bseg=1), (0, 0.022, -0.108), (0.021, 0.028, 0.036), (8, 0, 0)), wood))
        parts.append((place(mk('cube', bevel=0.45, bseg=1), (sx * 0.012, -0.062, -0.045), (0.017, 0.032, 0.016), (-50, 0, sx * -25)), wood))
    for bm, c in parts:
        B.piece(xform(bm, M), color=c, bone=bone, jitter=0.0015, oline=0.9)

def sleeve(B, S, side, sx, J):
    sh, el = J['upperarm.' + side]
    _, wr = J['forearm.' + side]
    sc = S.get('sleeve', 1.0)
    puff = S.get('puff', 1.0)
    mid1 = sh.lerp(el, 0.5); mid2 = el.lerp(wr, 0.55)
    B.piece(place(mk('sphere', u=10, v=7), sh + Vector((sx * 0.01, 0, -0.01)), (0.085 * sc * puff, 0.08 * sc * puff, 0.075 * sc * puff)), mat='pano', color='creme', bone='shoulder.' + side, smooth=True, uvfn=axis_uv(sh + Vector((0, 0, 0.1)), sh - Vector((0, 0, 0.1)), 1, 2.5))
    B.piece(tube([sh, mid1, el + (el - sh).normalized() * 0.02], [0.066 * sc, 0.058 * sc, 0.062 * sc], seg_n=10), mat='pano', color='creme', bone='upperarm.' + side, smooth=True, uvfn=axis_uv(sh, el, 1, 2.5))
    d = (wr - el).normalized()
    B.piece(tube([el - d * 0.02, mid2, wr - d * 0.01], [0.06 * sc, 0.056 * sc, 0.074 * sc], seg_n=10), mat='pano', color='creme', bone='forearm.' + side, smooth=True, uvfn=axis_uv(el, wr, 1, 2.5))
    # punho: barra de tecido creme
    B.piece(tube([wr - d * 0.03, wr + d * 0.005], [0.078 * sc, 0.08 * sc], seg_n=10), color=S.get('cuff', 'creme'), bone='forearm.' + side, smooth=True, oline=0.8)

def legs(B, S, J):
    for side, sx in (('L', 1), ('R', -1)):
        hp, kn = J['thigh.' + side]
        _, an = J['shin.' + side]
        r = S['leg_r']
        B.piece(seg(mk('cyl', seg=7), hp, kn, r), color=S.get('leg_col', 'madeira'), bone='thigh.' + side, jitter=0.002)
        B.piece(place(mk('sphere', u=8, v=5), kn, (r * 1.3, r * 1.3, r * 1.3)), color=S.get('leg_col', 'madeira'), bone='shin.' + side, jitter=0.002)
        B.piece(seg(mk('cyl', seg=7, r1=0.75, r2=1.0), kn, an, r * 0.95), color=S.get('leg_col', 'madeira'), bone='shin.' + side, jitter=0.002)
        bt = S.get('boot', 'tabua_esc')
        bm = loft([(-0.04, 0.05, 0.09, -0.04, 2.6), (0.0, 0.058, 0.105, -0.045, 2.8), (0.035, 0.05, 0.075, -0.025, 2.4), (0.05, 0.035, 0.04, 0.0, 2.0)], seg_n=10)
        B.piece(place(bm, an + Vector((0, 0, -0.0)), (S.get('boot_s', 1.0),) * 3), color=bt, bone='foot.' + side, jitter=0.002, smooth=False)

def body(B, S, J, fabric_hem=None):
    prof = S['body']
    n = S.get('body_n', 2.2); dep = S.get('body_d', 0.8)
    rings = [(z, r, r * dep, 0.0, n) for r, z in reversed(prof)]
    bm = loft(rings, seg_n=22, cap_bot=False, cap_top=True)
    # barra ondulada (festão) e prega leve
    zmin = rings[0][0]
    for v in bm.verts:
        a = math.atan2(v.co.x, -v.co.y)
        if abs(v.co.z - zmin) < 1e-4:
            v.co.z += 0.012 * math.sin(7 * a)
        if v.co.z < S['waist']:
            k = (S['waist'] - v.co.z) / (S['waist'] - zmin)
            rr = 1 + 0.035 * k * math.sin(9 * a + 1.3)
            v.co.x *= rr; v.co.y *= rr
    wz, cz, hz = S['waist'], S['chest'], S['hem']
    def w(co):
        z = co.z
        if z >= cz:
            if co.y < -0.02 and S.get('puffchest'):
                t = min(1, (-co.y - 0.02) / 0.08)
                return {'chest': 1 - t * 0.8, 'peito': t * 0.8}
            return {'chest': 1.0}
        if z >= wz:
            t = (z - wz) / (cz - wz); return {'spine': 1 - t * 0.6, 'chest': t * 0.6} if t < 1 else {'chest': 1.0}
        k = min(1.0, (wz - z) / max(0.05, (wz - hz))) ** 1.2 * 0.9
        a = math.atan2(co.x, -co.y)
        wf = max(0, math.cos(a)); wb = max(0, -math.cos(a)); wl = max(0, math.sin(a)); wr = max(0, -math.sin(a))
        s = wf + wb + wl + wr
        return {'hips': 1 - k, 'skirt.F': k * wf / s, 'skirt.B': k * wb / s, 'skirt.L': k * wl / s, 'skirt.R': k * wr / s}
    hem = S.get('hem_band')
    def colf(f):
        if hem and f.calc_center_median().z < hem[0]:
            return hem[1]
        return 'creme'
    B.piece(bm, mat='pano', color='creme', weights=w, smooth=True, uvfn=cyl_uv(S.get('uv_rep', 2.0), S.get('uv_v', 2.2)), colorfn=colf)

def collar(B, S, color, wavy=True, r0=None, r1=None, z=None, bone='chest'):
    z = z if z is not None else S['neck'] - 0.01
    r0 = r0 or 0.06; r1 = r1 or 0.15
    rings = [(z + 0.03, r0, r0 * 0.9, 0, 2), (z - 0.005, r1, r1 * 0.85, 0, 2), (z - 0.03, r1 * 1.05, r1 * 0.9, 0, 2)]
    bm = loft(rings, seg_n=24, cap_bot=False, cap_top=False)
    if wavy:
        for v in bm.verts:
            if v.co.z < z - 0.02:
                a = math.atan2(v.co.x, -v.co.y)
                v.co.z += 0.018 * abs(math.sin(6 * a))
    bm2 = bmesh.new()
    B.piece(bm, color=color, bone=bone, smooth=True, oline=0.8)

# ================================================================== cabeças por perfil
def head_tarugo(B, S, J):
    hb = J['head'][0]
    HS = Matrix.Translation(hb) @ Matrix.Diagonal((1.12, 1.12, 1.12, 1)) @ Matrix.Translation(-hb)
    R = [(0.10, 0.160, 0.132, 0.0, 3.0), (0.135, 0.178, 0.146, -0.004, 3.6), (0.20, 0.183, 0.152, 0.0, 4.2),
         (0.27, 0.180, 0.150, 0.006, 4.4), (0.33, 0.170, 0.140, 0.010, 4.0), (0.37, 0.142, 0.115, 0.014, 3.2), (0.388, 0.085, 0.07, 0.016, 2.6)]
    B.piece(xform(loft(R, seg_n=12), HS @ Matrix.Translation(hb)), color='madeira_esc', bone='head', jitter=0.005)
    # queixo enorme articulado
    JR = [(-0.06, 0.150, 0.118, -0.052, 3.4), (-0.03, 0.188, 0.148, -0.040, 3.8), (0.03, 0.200, 0.160, -0.026, 4.0), (0.105, 0.182, 0.150, -0.008, 3.6), (0.12, 0.17, 0.14, 0.0, 3.4)]
    B.piece(xform(loft(JR, seg_n=12), HS @ Matrix.Translation(hb)), color='madeira_esc', bone='jaw', jitter=0.005)
    # boca (interior escuro) entre crânio e queixo, recuada: só aparece com o queixo aberto
    B.piece(xform(place(mk('cube'), hb + Vector((0, -0.02, 0.105)), (0.12, 0.1, 0.03)), HS), color='vinho', bone='head', hull=False)
    # sobrancelha única entalhada, em V (fanfarrão)
    pts = [hb + Vector((x, front_y(R, x, 0.25 - 0.03 * (1 - abs(x) / 0.14)) - 0.012, 0.25 - 0.03 * (1 - abs(x) / 0.14) + 0.0)) for x in (-0.15, -0.075, 0.0, 0.075, 0.15)]
    B.piece(xform(tube(pts, [0.016, 0.026, 0.028, 0.026, 0.016], seg_n=8, flat=0.7), HS), color='tabua_esc', bone='head', jitter=0.0, oline=0.6)
    # olhos juntos, sob a sobrancelha
    for sx in (1, -1):
        p, nrm = face_normal(R, sx * 0.064, 0.19)
        eye_quad(B, (HS @ (hb + p)), nrm, 0.078, 0.06, 'head', lid='madeira_esc', tilt=sx * -8, mirror=sx < 0)
        p2, n2 = face_normal(R, sx * 0.125, 0.135)
        B.piece(xform(place(mk('cyl', seg=10), hb + p2 + n2 * 0.002, (0.03, 0.03, 0.003), (90, 0, 0)), HS), color='bochecha', bone='head', hull=False)
        B.piece(xform(place(mk('sphere', u=6, v=4), hb + Vector((sx * 0.185, 0.01, 0.19)), (0.025, 0.045, 0.055)), HS), color='madeira_esc', bone='head', jitter=0.003, oline=0.7)
    # nariz de batata, abaixo dos olhos
    pn, nn = face_normal(R, 0.0, 0.14)
    B.piece(xform(place(mk('ico', sub=2), hb + pn + nn * 0.022 + Vector((0, 0, -0.005)), (0.046, 0.04, 0.042)), HS), color='madeira_esc', bone='head', jitter=0.004, oline=0.8)
    # cabelo raspado: faixa escura atrás
    B.piece(xform(loft([(0.23, 0.186, 0.155, 0.004, 4.4), (0.30, 0.178, 0.148, 0.008, 4.2)], seg_n=12, cap_bot=False, cap_top=False), HS @ Matrix.Translation(hb + Vector((0, 0.004, 0))) @ Matrix.Diagonal((1.02, 1.02, 1, 1))),
            color='tabua_esc', bone='head', hull=False, colorfn=lambda f: 'tabua_esc' if f.calc_center_median().y > 0.0 else 'madeira_esc')

def head_anilina(B, S, J):
    hb = J['head'][0]
    R = [(0.075, 0.08, 0.07, 0.0, 2.2), (0.10, 0.16, 0.13, 0.0, 2.3), (0.15, 0.205, 0.158, 0.0, 2.4), (0.21, 0.212, 0.163, 0.0, 2.4),
         (0.26, 0.198, 0.152, 0.006, 2.3), (0.30, 0.158, 0.124, 0.01, 2.2), (0.325, 0.085, 0.07, 0.012, 2.0)]
    B.piece(xform(loft(R, seg_n=16), Matrix.Translation(hb)), color='madeira', bone='head', jitter=0.003)
    JR = [(0.035, 0.065, 0.055, -0.062, 2.2), (0.06, 0.12, 0.10, -0.04, 2.3), (0.10, 0.155, 0.125, -0.02, 2.3), (0.115, 0.15, 0.12, -0.012, 2.3)]
    B.piece(xform(loft(JR, seg_n=16), Matrix.Translation(hb)), color='madeira', bone='jaw', jitter=0.003)
    B.piece(place(mk('cube'), hb + Vector((0, -0.02, 0.105)), (0.09, 0.09, 0.025)), color='vinho', bone='head', hull=False)
    for sx in (1, -1):
        p, nrm = face_normal(R, sx * 0.092, 0.195)
        eye_quad(B, hb + p, nrm, 0.085, 0.05, 'head', lid='madeira', tilt=sx * 6, mirror=sx < 0)
        p2, n2 = face_normal(R, sx * 0.135, 0.135)
        B.piece(place(mk('cyl', seg=10), hb + p2 + n2 * 0.002, (0.034, 0.034, 0.003), (90, 0, 0)), color='bochecha', bone='head', hull=False)
        # cabelo: mechas escuras sob a aba
        B.piece(place(mk('sphere', u=8, v=5), hb + Vector((sx * 0.175, 0.02, 0.24)), (0.06, 0.1, 0.075), (0, sx * -20, 0)), color='tabua_esc', bone='head', jitter=0.004, oline=0.8)
    # nariz pequeno e arrebitado
    pn, nn = face_normal(R, 0.0, 0.155)
    B.piece(place(mk('cyl', seg=6, r1=1.0, r2=0.15), hb + pn + nn * 0.02 + Vector((0, 0, 0.005)), (0.028, 0.024, 0.03), (-70, 0, 0)), color='madeira', bone='head', jitter=0.0, oline=0.7)
    # coque atrás
    B.piece(place(mk('sphere', u=8, v=6), hb + Vector((0, 0.16, 0.17)), (0.07, 0.06, 0.07)), color='tabua_esc', bone='head', jitter=0.004)
    # chapéu de feltro de aba enorme, respingado de tinta
    hz = hb.z + S['hat_z']
    rng = random.Random(5)
    brim = bmesh.new()
    NR, NA = 10, 72
    V = {}
    for i in range(NR + 1):
        rr = 0.12 + (0.31 - 0.12) * i / NR
        for j in range(NA):
            a = 2 * math.pi * j / NA
            fr = max(0.0, math.cos(a)) ** 2  # na frente a aba dobra para cima
            droop = (-0.08 * (1 - fr) + 0.06 * fr) * ((rr - 0.12) / 0.19) ** 2 + 0.012 * math.sin(5 * a) * (rr / 0.33)
            V[i, j] = brim.verts.new((rr * math.sin(a) * 1.04, -rr * math.cos(a) * 0.98, droop))
    for i in range(NR):
        for j in range(NA):
            brim.faces.new([V[i, j], V[i, (j + 1) % NA], V[i + 1, (j + 1) % NA], V[i + 1, j]])
    bmesh.ops.solidify(brim, geom=brim.faces[:], thickness=0.022)
    bmesh.ops.recalc_face_normals(brim, faces=brim.faces[:])
    # v2: só respingos azuis, poucos e maiores (os claros liam como textura quebrada em blocos)
    blobs = [(Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3))), rng.uniform(0.035, 0.055), 'anilina') for k in range(9)]
    def splat(f):
        c = f.calc_center_median()
        for bc, br, bcol in blobs:
            if (Vector((c.x, c.y)) - bc).length < br:
                return bcol
        return 'tabua_esc'
    B.piece(xform(brim, Matrix.Translation((0, 0.0, hz)) @ Euler((math.radians(-26), 0, 0)).to_matrix().to_4x4()), color='tabua_esc', bone='hat', smooth=True, colorfn=splat, oline=0.9)
    crown = loft([(0.0, 0.17, 0.155, 0, 2.2), (0.03, 0.168, 0.153, 0.0, 2.3), (0.06, 0.165, 0.15, 0.0, 2.3), (0.09, 0.155, 0.142, 0.005, 2.3), (0.12, 0.14, 0.13, 0.01, 2.3), (0.14, 0.115, 0.105, 0.012, 2.2), (0.155, 0.08, 0.075, 0.015, 2.0)], seg_n=36)
    for v in crown.verts:  # amassado no topo
        if v.co.z > 0.13:
            v.co.z -= 0.025 * math.exp(-(v.co.x ** 2) / 0.003)
    B.piece(xform(crown, Matrix.Translation((0, 0.0, hz)) @ Euler((math.radians(-26), 0, 0)).to_matrix().to_4x4()), color='tabua_esc', bone='hat', smooth=True, colorfn=splat)
    band = loft([(0.012, 0.176, 0.161, 0, 2.2), (0.05, 0.172, 0.157, 0, 2.3)], seg_n=18, cap_bot=False, cap_top=False)
    B.piece(xform(band, Matrix.Translation((0, 0.0, hz)) @ Euler((math.radians(-26), 0, 0)).to_matrix().to_4x4()), color='p_folha', bone='hat', smooth=True, oline=0.0, hull=False)
    # pincel enfiado na fita do chapéu
    B.piece(seg(mk('cyl', seg=6), (0.12, 0.08, hz + 0.02), (0.2, 0.12, hz + 0.2), 0.009), color='madeira_esc', bone='hat', oline=0.6)
    B.piece(seg(mk('cyl', seg=6, r1=1.0, r2=0.3), (0.2, 0.12, hz + 0.2), (0.215, 0.127, hz + 0.25), 0.016), color='anilina', bone='hat', oline=0.6)

def head_retros(B, S, J):
    hb = J['head'][0]
    W = 0.125
    R = [(0.075, 0.05, 0.05, 0, 2), (0.085, 0.165, 0.165, 0, 2), (0.115, 0.168, 0.168, 0, 2), (0.13, 0.13, 0.13, 0, 2), (0.15, W, W, 0, 2),
         (0.24, W, W, 0, 2), (0.26, 0.13, 0.13, 0, 2), (0.275, 0.168, 0.168, 0, 2), (0.305, 0.165, 0.165, 0, 2), (0.315, 0.05, 0.05, 0, 2)]
    def col(f):
        z = f.calc_center_median().z - hb.z
        if z < 0.14 or z > 0.255:
            return 'madeira_esc'
        if z > 0.225:
            return 'p_ciano'  # linha enrolada
        return 'madeira'
    B.piece(xform(loft(R[4:], seg_n=16), Matrix.Translation(hb)), color='madeira', bone='head', jitter=0.002, colorfn=col)
    # aba de baixo do carretel é o queixo articulado
    B.piece(xform(loft(R[:5], seg_n=16), Matrix.Translation(hb)), color='madeira_esc', bone='jaw', jitter=0.002, colorfn=col)
    for sx in (1, -1):
        p, nrm = face_normal(R, sx * 0.05, 0.19)
        eye_quad(B, hb + p, nrm, 0.05, 0.042, 'head', lid='madeira', tilt=sx * -12, mirror=sx < 0)
        # óculos pintados: aro
        c = hb + p + nrm * 0.006
        pts = [c + Vector((math.cos(a) * 0.034, 0, math.sin(a) * 0.03)) for a in [k * math.pi / 6 for k in range(13)]]
        pts = [Vector((q.x, front_y(R, q.x - hb.x, q.z - hb.z) + hb.y - 0.006, q.z)) for q in pts]
        B.piece(tube(pts, [0.005] * len(pts), seg_n=5, cap=False), color='tinta', bone='head', hull=False)
    pn, nn = face_normal(R, 0.0, 0.175)
    B.piece(place(mk('cyl', seg=5, r1=1.0, r2=0.1), hb + pn + nn * 0.03, (0.02, 0.02, 0.04), (-95, 0, 0)), color='madeira', bone='head', oline=0.7)
    # coque alto com alfinetes
    top = hb + Vector((0, 0.01, 0.315))
    B.piece(place(mk('sphere', u=10, v=7), top + Vector((0, 0, 0.06)), (0.075, 0.07, 0.07)), color='tabua_esc', bone='hat', jitter=0.003)
    rng = random.Random(3)
    for k in range(6):
        a = k / 6 * 2 * math.pi + 0.3
        base = top + Vector((math.cos(a) * 0.05, math.sin(a) * 0.05, 0.08))
        tip = base + Vector((math.cos(a) * 0.07, math.sin(a) * 0.07, 0.08 + rng.uniform(-0.02, 0.03)))
        B.piece(seg(mk('cyl', seg=4), base, tip, 0.006), color='creme', bone='hat', oline=0.5)
        B.piece(place(mk('sphere', u=6, v=4), tip, (0.017,) * 3), color=['p_ciano', 'creme', 'bochecha'][k % 3], bone='hat', oline=0.6)

def head_pavio(B, S, J):
    hb = J['head'][0]
    R = [(0.04, 0.06, 0.06, 0, 2), (0.07, 0.14, 0.135, 0, 2.1), (0.13, 0.172, 0.165, 0, 2.1), (0.19, 0.168, 0.16, 0.0, 2.1), (0.25, 0.12, 0.115, 0.01, 2.0),
         (0.28, 0.085, 0.085, 0.015, 2), (0.31, 0.088, 0.088, 0.02, 2), (0.345, 0.075, 0.075, 0.02, 2), (0.37, 0.03, 0.03, 0.02, 2)]
    B.piece(xform(loft(R, seg_n=14), Matrix.Translation(hb)), color='lua', bone='head', jitter=0.003)
    JR = [(0.03, 0.06, 0.05, -0.06, 2.0), (0.055, 0.105, 0.09, -0.045, 2.1), (0.085, 0.12, 0.1, -0.03, 2.1)]
    B.piece(xform(loft(JR, seg_n=14), Matrix.Translation(hb)), color='lua', bone='jaw', jitter=0.003)
    for sx in (1, -1):
        p, nrm = face_normal(R, sx * 0.06, 0.16)
        eye_quad(B, hb + p, nrm, 0.07, 0.075, 'head', lid='lua', tilt=sx * 10, mirror=sx < 0)
        # orelhas de abano
        ear = loft([(-0.05, 0.012, 0.03, 0, 2), (0.0, 0.016, 0.055, 0, 2), (0.05, 0.012, 0.04, 0, 2)], seg_n=10)
        B.piece(xform(ear, Matrix.Translation(hb + Vector((sx * 0.19, 0.02, 0.15))) @ Euler((0, 0, math.radians(sx * -35))).to_matrix().to_4x4()), color='lua', bone='head', jitter=0.002, oline=0.8)
        p2, n2 = face_normal(R, sx * 0.115, 0.1)
        B.piece(place(mk('cyl', seg=10), hb + p2 + n2 * 0.002, (0.026, 0.026, 0.003), (90, 0, 0)), color='bochecha', bone='head', hull=False)
    pn, nn = face_normal(R, 0.0, 0.12)
    B.piece(place(mk('sphere', u=8, v=5), hb + pn + nn * 0.015, (0.025, 0.022, 0.022)), color='bochecha', bone='head', oline=0.7)
    # gorro comprido de ponta em 3 ossos, com pompom-pavio
    cap = S['cap']
    rings = []
    pts = [Vector(cap[0][0])] + [Vector(b) for a, b in cap]
    radii = [0.095, 0.07, 0.045, 0.018]
    bones_ = ['hat', 'cap1', 'cap2', 'cap3']
    for i in range(len(pts) - 1):
        bm = tube([pts[i], pts[i + 1] + (pts[i + 1] - pts[i]).normalized() * 0.015], [radii[i], radii[i + 1]], seg_n=12, cap=True)
        B.piece(bm, color='musgo', bone=bones_[i + 1] if i > 0 else 'cap1', smooth=True, colorfn=(lambda f, i=i: 'creme' if i == 0 and f.calc_center_median().z < pts[0].z + 0.03 else 'musgo'))
    tip = pts[-1]
    B.piece(seg(mk('cyl', seg=6), tip, tip + Vector((0, 0.01, 0.05)), 0.008), color='tabua_esc', bone='cap3', oline=0.6)
    fl = loft([(0.0, 0.02, 0.02, 0, 2), (0.03, 0.03, 0.03, 0, 2), (0.07, 0.0, 0.0, 0.0, 2)], seg_n=8)
    B.piece(place(fl, tip + Vector((0, 0.01, 0.05))), color='p_gema', bone='cap3', oline=0.7)

# ================================================================== adereços
def prop_macete(B, S, J):
    hc, tl = J['prop']; d = (tl - hc).normalized()
    side = Vector((0, 1, 0))
    B.piece(seg(mk('cyl', seg=8), hc - d * 0.08, hc + d * 0.64, 0.028), color='madeira_esc', bone='prop', jitter=0.002, colorfn=lambda f: 'madeira_esc')
    c = hc + d * 0.76
    L, r = 0.48, 0.165
    barrel = loft([(-L / 2, r * 0.93, r * 0.93, 0, 2), (-L / 2 + 0.03, r, r, 0, 2), (0, r * 1.04, r * 1.04, 0, 2), (L / 2 - 0.03, r, r, 0, 2), (L / 2, r * 0.93, r * 0.93, 0, 2)], seg_n=12)
    def endgrain(f):
        cc = f.calc_center_median()
        if abs(abs(cc.z) - L / 2) < 0.005:
            return 'madeira'   # v2: topo liso (os anéis por face liam como degrau de pixel)
        return 'tabua_esc'
    q = Vector((0, 0, 1)).rotation_difference(side)
    B.piece(xform(barrel, Matrix.Translation(c) @ q.to_matrix().to_4x4()), color='madeira_esc', bone='prop', jitter=0.004, colorfn=endgrain)
    for s in (-1, 1):
        hoop = tube([c + side * (s * 0.15 - 0.022), c + side * (s * 0.15 + 0.022)], [r * 1.07, r * 1.07], seg_n=14)
        B.piece(hoop, color='tinta', bone='prop', smooth=True, oline=0.6)
    S['_prop_pts'] = [hc + d * t for t in (0.0, 0.3, 0.6)] + [c + side * s * 0.24 + d * k * r for s in (-1, 1) for k in (-1, 1)]
    S['_prop_head'] = (c, d, side, L, r)

def prop_broxa(B, S, J):
    hc, tl = J['prop']; d = (tl - hc).normalized()
    B.piece(seg(mk('cyl', seg=7, r1=1.0, r2=0.8), hc - d * 0.12, hc + d * 0.95, 0.024), color='madeira_esc', bone='prop', jitter=0.001)
    fe = hc + d * 0.95
    wide = Vector((0, 1, 0)); thin = d.cross(wide).normalized()
    ferr = loft([(0, 0.035, 0.05, 0, 3), (0.08, 0.04, 0.1, 0, 4)], seg_n=12)
    q = Matrix((thin, wide, d)).transposed()
    B.piece(xform(ferr, Matrix.Translation(fe) @ q.to_4x4()), color='creme', bone='prop', colorfn=lambda f: 'tabua_esc' if 0.02 < (f.calc_center_median() - fe).dot(d) < 0.035 else 'creme')
    rng = random.Random(9)
    for k in range(4):
        off = (k - 1.5) * 0.045
        ln = 0.2 + rng.uniform(-0.012, 0.015)
        cl = loft([(0.0, 0.034, 0.03, 0, 2.6), (ln * 0.55, 0.036, 0.034, 0, 2.6), (ln * 0.9, 0.028, 0.024, 0, 2.4), (ln, 0.01, 0.012, 0, 2)], seg_n=8)
        def bc(f, ln=ln):
            z = (f.calc_center_median() - fe).dot(d) - 0.07
            return 'anilina' if z > ln * 0.45 else 'madeira'
        B.piece(xform(cl, Matrix.Translation(fe + d * 0.07 + wide * off) @ q.to_4x4()), color='madeira', bone='prop', jitter=0.003, colorfn=bc, smooth=False)
    S['_prop_pts'] = [hc + d * t for t in (0.0, 0.4, 0.8, 1.1, 1.25)] + [fe + d * 0.25 + wide * s * 0.1 for s in (-1, 1)]
    S['_prop_head'] = (fe + d * 0.17, d, wide, 0.2, 0.05)

def prop_agulhao(B, S, J):
    hc, tl = J['prop']; d = (tl - hc).normalized()
    nd = loft([(-0.14, 0.012, 0.03, 0, 2), (-0.1, 0.018, 0.03, 0, 2), (0.3, 0.022, 0.022, 0, 2), (1.0, 0.014, 0.014, 0, 2), (1.12, 0.002, 0.002, 0, 2)], seg_n=8)
    q = Vector((0, 0, 1)).rotation_difference(d)
    B.piece(xform(nd, Matrix.Translation(hc) @ q.to_matrix().to_4x4()), color='lona', bone='prop', smooth=True, oline=0.8)
    eye = hc - d * 0.12
    pts = [eye + Vector((0.0, 0.03 * math.sin(t * 6), 0.0)) + Vector((0.05 * math.sin(t * 3), 0.12 * t, -0.18 * t * t)) for t in [k / 10 for k in range(11)]]
    B.piece(tube(pts, [0.009] * len(pts), seg_n=5), color='p_ciano', bone='prop', smooth=True, oline=0.6)
    S['_prop_pts'] = [hc + d * t for t in (0.0, 0.5, 1.1)]
    S['_prop_head'] = (hc + d * 1.0, d, Vector((0, 1, 0)), 0.2, 0.02)

def prop_baladeira(B, S, J):
    hc, tl = J['prop']; d = (tl - hc).normalized()
    side = Vector((0, 1, 0))
    fork = hc + d * 0.12
    B.piece(seg(mk('cyl', seg=6), hc - d * 0.05, fork, 0.02), color='madeira_esc', bone='prop', jitter=0.002)
    for s in (-1, 1):
        B.piece(seg(mk('cyl', seg=6, r1=1.0, r2=0.8), fork, fork + d * 0.12 + side * s * 0.07, 0.016), color='madeira_esc', bone='prop', jitter=0.002)
    B.piece(tube([fork + d * 0.12 + side * -0.07, fork + d * 0.06 + Vector((0.0, 0, 0)) - Vector((0.04, 0, 0)), fork + d * 0.12 + side * 0.07], [0.007] * 3, seg_n=5), color='tabua_esc', bone='prop', oline=0.5)
    S['_prop_pts'] = [hc, fork + d * 0.12]
    S['_prop_head'] = (fork + d * 0.12, d, side, 0.1, 0.03)

# ================================================================== heróis
HEROES = {
    'tarugo': dict(seed=11, hand_col='madeira_esc', leg_col='madeira_esc', hem=0.42, hip=0.47, waist=0.62, chest=0.74, sh=0.85, neck=0.89, head=0.95, hat_z=0.42, jaw_z=0.11,
                   shw=0.25, ua=0.16, fa=0.15, hs=1.75, legx=0.1, knee=0.27, ankle=0.085, leg_r=0.05, boot_s=1.25, hem_r=0.28,
                   body=[(0.07, 0.905), (0.19, 0.89), (0.255, 0.86), (0.262, 0.80), (0.245, 0.72), (0.235, 0.64), (0.25, 0.55), (0.272, 0.47), (0.28, 0.42)],
                   body_n=3.2, body_d=0.78, sleeve=1.45, puff=1.15, puffchest=True, fabric='xadrez', hem_band=(0.53, 'tabua_esc'), uv_rep=3.0, uv_v=3.0,
                   head_fn='tarugo', prop='macete', scarf='p_magenta', cuff='p_magenta', hsc=1.2),
    'anilina': dict(seed=12, hem=0.12, hip=0.20, waist=0.60, chest=0.71, sh=0.80, neck=0.845, head=0.83, hat_z=0.29, jaw_z=0.10,
                    shw=0.17, ua=0.17, fa=0.16, hs=1.15, legx=0.08, knee=0.12, ankle=0.06, leg_r=0.035, hem_r=0.34,
                    body=[(0.06, 0.86), (0.15, 0.845), (0.185, 0.815), (0.18, 0.75), (0.15, 0.64), (0.19, 0.54), (0.26, 0.38), (0.325, 0.2), (0.345, 0.12)],
                    body_n=2.2, body_d=0.85, sleeve=1.1, fabric='chita', hem_band=(0.235, 'tabua_esc'), uv_rep=3.0, uv_v=2.6,
                    head_fn='anilina', prop='broxa', cuff='p_folha', hsc=1.3),
    'retros': dict(seed=13, hem=0.40, hip=0.45, waist=0.76, chest=0.88, sh=0.98, neck=1.02, head=1.005, hat_z=0.315, jaw_z=0.13,
                   shw=0.15, ua=0.2, fa=0.19, hs=1.0, legx=0.065, knee=0.24, ankle=0.07, leg_r=0.03, hem_r=0.22,
                   body=[(0.055, 1.025), (0.13, 1.0), (0.155, 0.97), (0.14, 0.88), (0.112, 0.78), (0.13, 0.68), (0.18, 0.55), (0.21, 0.44), (0.218, 0.40)],
                   body_n=2.0, body_d=0.8, sleeve=0.9, fabric='listrado', hem_band=(0.52, 'tabua_esc'), uv_rep=2.0, uv_v=2.0, head_fn='retros', prop='agulhao', cuff='p_ciano', hsc=1.28),
    'pavio': dict(seed=14, hem=0.36, hip=0.40, waist=0.55, chest=0.64, sh=0.72, neck=0.755, head=0.735, hat_z=0.30, jaw_z=0.075,
                  shw=0.15, ua=0.14, fa=0.13, hs=1.05, legx=0.07, knee=0.22, ankle=0.07, leg_r=0.03, hem_r=0.2,
                  body=[(0.05, 0.765), (0.12, 0.75), (0.15, 0.72), (0.18, 0.64), (0.193, 0.56), (0.18, 0.47), (0.17, 0.40), (0.165, 0.36)],
                  body_n=2.0, body_d=0.9, sleeve=0.95, fabric='poa', hem_band=(0.45, 'tabua_esc'), uv_rep=2.5, uv_v=2.5, head_fn='pavio', prop='baladeira', cuff='p_gema', hsc=1.3),
}
# gorro do Pavio: 3 ossos curvando para trás
_p = HEROES['pavio']; _b = _p['head'] + _p['hat_z']
_p['cap'] = [((0, 0.02, _b), (0, 0.06, _b + 0.17)), ((0, 0.06, _b + 0.17), (0, 0.15, _b + 0.31)), ((0, 0.15, _b + 0.31), (0, 0.28, _b + 0.38))]

def build_hero(name):
    S = dict(HEROES[name])
    Bn = hero_bones(S)
    B = Builder(S['seed'], [b[0] for b in Bn])
    J = joints(S, Bn)
    B.J = J; B.bones = Bn
    B.head_scale = ({'head', 'jaw', 'hat', 'cap1', 'cap2', 'cap3'}, Vector((0, 0, S['head'])), S.get('hsc', 1.0))
    body(B, S, J)
    {'tarugo': head_tarugo, 'anilina': head_anilina, 'retros': head_retros, 'pavio': head_pavio}[S['head_fn']](B, S, J)
    # pescoço curto
    B.piece(seg(mk('cyl', seg=8), (0, 0, S['neck'] - 0.03), (0, 0, S['head'] + 0.1), 0.05), color='madeira', bone='neck', jitter=0.002, oline=0.6)
    if name == 'tarugo':  # lenço no pescoço com nó (cor do jogador)
        collar(B, S, 'p_magenta', wavy=False, r0=0.08, r1=0.19, z=S['neck'] - 0.005)
        for s in (1, -1):
            B.piece(place(mk('cube', bevel=0.4, bseg=1), (s * 0.05, -0.17, S['neck'] - 0.08), (0.035, 0.02, 0.06), (0, s * 25, s * 10)), color='p_magenta', bone='chest', smooth=True, oline=0.8)
        B.piece(place(mk('sphere', u=8, v=5), (0, -0.165, S['neck'] - 0.035), (0.04, 0.03, 0.035)), color='p_magenta', bone='chest', oline=0.8)
    elif name == 'anilina':
        collar(B, S, 'creme', wavy=True, r0=0.065, r1=0.15)
    elif name == 'retros':
        collar(B, S, 'creme', wavy=True, r0=0.06, r1=0.13)
        # fita métrica no pescoço
        for s in (1, -1):
            pts = [Vector((s * 0.06, -0.02, S['neck'] + 0.01)), Vector((s * 0.1, -0.1, S['neck'] - 0.04)), Vector((s * 0.085, -0.13, S['neck'] - 0.18)), Vector((s * 0.08, -0.125, S['neck'] - 0.3 + s * 0.04))]
            B.piece(tube(pts, [0.016] * 4, seg_n=6, flat=0.3), color='lua', bone='chest', smooth=False, oline=0.6)
    elif name == 'pavio':
        collar(B, S, 'p_gema', wavy=True, r0=0.055, r1=0.13)
    for side, sx in (('L', 1), ('R', -1)):
        sleeve(B, S, side, sx, J)
        mitt(B, S, side, sx, J, 'fist' if side == 'R' else 'open')
    legs(B, S, J)
    {'macete': prop_macete, 'broxa': prop_broxa, 'agulhao': prop_agulhao, 'baladeira': prop_baladeira}[S['prop']](B, S, J)
    B.S = S
    return B

# ================================================================== inimigos
def caruncho_bones():
    B = [('root', (0, 0, 0), (0, 0, 0.1), None),
         ('body', (0, 0.18, 0.26), (0, -0.12, 0.3), 'root'),
         ('head', (0, -0.14, 0.3), (0, -0.32, 0.29), 'body'),
         ('mand.L', (0.06, -0.3, 0.25), (0.08, -0.44, 0.24), 'head'), ('mand.R', (-0.06, -0.3, 0.25), (-0.08, -0.44, 0.24), 'head'),
         ('ant1.L', (0.07, -0.27, 0.36), (0.16, -0.4, 0.5), 'head'), ('ant2.L', (0.16, -0.4, 0.5), (0.25, -0.5, 0.6), 'ant1.L'),
         ('ant1.R', (-0.07, -0.27, 0.36), (-0.16, -0.4, 0.5), 'head'), ('ant2.R', (-0.16, -0.4, 0.5), (-0.25, -0.5, 0.6), 'ant1.R'),
         ('shell.L', (0.03, -0.05, 0.4), (0.06, 0.3, 0.36), 'body'), ('shell.R', (-0.03, -0.05, 0.4), (-0.06, 0.3, 0.36), 'body')]
    for i, y in enumerate((-0.1, 0.02, 0.14)):
        for s, sx in (('L', 1), ('R', -1)):
            B.append(('leg%d.%s' % (i, s), (sx * 0.13, y, 0.2), (sx * 0.44, y + (i - 1) * 0.12, 0.0), 'body'))
    return B

def build_caruncho(chifre=False):
    Bn = caruncho_bones()
    B = Builder(31, [b[0] for b in Bn]); J = joints({}, Bn); B.J = J; B.bones = Bn
    rng = random.Random(4)
    # élitros de cortiça com furos de caruncho (ironia: a praga é furada)
    hole_c = [Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.25, 0.35), rng.uniform(0.25, 0.48))) for k in range(26)][:9]
    hole_r = [rng.uniform(0.02, 0.034) for k in range(26)][:9]
    def cork(f):
        c = f.calc_center_median()
        if abs(abs(c.x) - 0.085) < 0.012 and c.z > 0.36:
            return 'tinta'
        for hc, hr in zip(hole_c, hole_r):
            if (c - hc).length < hr * 1.6 and abs(c.z - hc.z) < 0.15:
                return 'laca_esc'
        return 'laca'
    def ring_lerp(a, b, n):
        return [tuple(a[k] + (b[k] - a[k]) * i / n for k in range(5)) for i in range(n)]
    ER = [(-0.24, 0.02, 0.03, 0, 2), (-0.2, 0.1, 0.12, 0, 2.2), (-0.05, 0.135, 0.15, 0, 2.4), (0.1, 0.125, 0.14, 0, 2.3), (0.22, 0.07, 0.085, 0, 2.1), (0.27, 0.01, 0.01, 0, 2)]
    ERf = []
    for i in range(len(ER) - 1):
        ERf += ring_lerp(ER[i], ER[i + 1], 3)
    ERf.append(ER[-1])
    for s, sx in (('L', 1), ('R', -1)):
        el = loft(ERf, seg_n=22)
        M = Matrix.Translation((sx * 0.072, 0.07, 0.28)) @ Euler((math.radians(90 - 8), 0, 0)).to_matrix().to_4x4() @ Matrix.Diagonal((1.0, 0.72, 1.0, 1))
        bm = xform(el, M)
        for v in bm.verts:
            if v.co.x * sx < 0.0:
                v.co.x = sx * 0.0 + (v.co.x - 0.0) * 0.3
        if chifre:  # arquétipo 2: élitros abertos (silhueta própria no enxame)
            xform(bm, Matrix.Translation((sx * 0.02, 0, 0.36)) @ Euler((0, math.radians(sx * 32), math.radians(sx * -10))).to_matrix().to_4x4() @ Matrix.Translation((-sx * 0.02, 0, -0.36)))
        B.piece(bm, color='laca', bone='shell.' + s, jitter=0.002, colorfn=cork, smooth=False)
    # barriga e pronoto
    B.piece(place(mk('sphere', u=12, v=8), (0, 0.06, 0.22), (0.15, 0.24, 0.09)), color='laca_esc', bone='body', jitter=0.003)
    if chifre:  # asa membranosa de papel vegetal entre os élitros abertos
        for sx in (1, -1):
            wg = place(mk('sphere', u=10, v=6), (sx * 0.12, 0.14, 0.36), (0.09, 0.18, 0.01), (0, sx * 30, sx * 12))
            B.piece(wg, color='cortica', bone='body', smooth=True, oline=0.6)
    pr = loft([(-0.07, 0.07, 0.06, 0, 2), (-0.03, 0.15, 0.1, 0, 2.6), (0.04, 0.16, 0.11, 0, 2.8), (0.08, 0.1, 0.06, 0, 2.2)], seg_n=12)
    B.piece(xform(pr, Matrix.Translation((0, -0.13, 0.32)) @ Euler((math.radians(70), 0, 0)).to_matrix().to_4x4()), color='laca', bone='body', jitter=0.004)
    # cabeça
    hd = loft([(-0.08, 0.05, 0.05, 0, 2), (-0.04, 0.11, 0.1, 0, 2.2), (0.03, 0.12, 0.105, 0, 2.2), (0.08, 0.06, 0.06, 0, 2)], seg_n=12)
    B.piece(xform(hd, Matrix.Translation((0, -0.27, 0.3)) @ Matrix.Diagonal((1.15, 1.15, 1.15, 1)) @ Euler((math.radians(80), 0, 0)).to_matrix().to_4x4()), color='laca_esc', bone='head', jitter=0.004)
    if chifre:  # chifre de rinoceronte, curvo para cima
        hp = [Vector((0, -0.31, 0.36)), Vector((0, -0.4, 0.43)), Vector((0, -0.45, 0.53)), Vector((0, -0.42, 0.63))]
        B.piece(tube(hp, [0.045, 0.036, 0.022, 0.006], seg_n=8), color='laca_esc', bone='head', smooth=True, oline=0.8)
    for sx in (1, -1):
        c = Vector((sx * 0.07, -0.35, 0.35)); n = Vector((sx * 0.45, -1, 0.5)).normalized()
        B.piece(place(mk('sphere', u=10, v=7), c - n * 0.005, (0.06, 0.055, 0.06)), color='creme', bone='head', oline=0.8)
        eye_quad(B, c + n * 0.045, n, 0.095, 0.095, 'head', lid='laca', tilt=sx * 20, mirror=sx < 0)
        # mandíbula em gancho
        s = 'L' if sx > 0 else 'R'
        pts = [Vector((sx * 0.05, -0.32, 0.25)), Vector((sx * 0.12, -0.42, 0.245)), Vector((sx * 0.1, -0.52, 0.24)), Vector((sx * 0.03, -0.55, 0.235))]
        B.piece(tube(pts, [0.036, 0.03, 0.02, 0.006], seg_n=7, flat=0.7), color='creme', bone='mand.' + s, jitter=0.0)
        a1h, a1t = J['ant1.' + s]; a2h, a2t = J['ant2.' + s]
        B.piece(tube([a1h, a1h.lerp(a1t, 0.5) + Vector((0, 0, 0.02)), a1t], [0.014, 0.012, 0.012], seg_n=6), color='laca_esc', bone='ant1.' + s, smooth=True, oline=0.7)
        B.piece(tube([a2h, a2h.lerp(a2t, 0.5), a2t], [0.012, 0.011, 0.01], seg_n=6), color='laca_esc', bone='ant2.' + s, smooth=True, oline=0.7)
        B.piece(place(mk('sphere', u=8, v=5), a2t, (0.035, 0.035, 0.03)), color='laca_esc', bone='ant2.' + s, jitter=0.003, oline=0.8)
    for i in range(3):
        for s, sx in (('L', 1), ('R', -1)):
            h, t = J['leg%d.%s' % (i, s)]
            kn = h.lerp(t, 0.42) + Vector((sx * 0.03, 0, 0.17))
            B.piece(tube([h, kn, t + Vector((sx * 0.02, 0, 0.01))], [0.022, 0.02, 0.012], seg_n=6), color='laca_esc', bone='leg%d.%s' % (i, s), smooth=False, oline=0.7)
    return B

def traca_bones():
    h = 1.35
    return [('root', (0, 0, 0), (0, 0, 0.1), None), ('body', (0, 0.15, h), (0, -0.15, h + 0.05), 'root'),
            ('head', (0, -0.15, h + 0.05), (0, -0.3, h + 0.1), 'body'),
            ('ant.L', (0.04, -0.27, h + 0.14), (0.16, -0.4, h + 0.36), 'head'), ('ant.R', (-0.04, -0.27, h + 0.14), (-0.16, -0.4, h + 0.36), 'head'),
            ('wing.L', (0.06, -0.05, h + 0.08), (0.5, 0.0, h + 0.12), 'body'), ('wing.R', (-0.06, -0.05, h + 0.08), (-0.5, 0.0, h + 0.12), 'body')]

def build_traca():
    Bn = traca_bones(); B = Builder(41, [b[0] for b in Bn]); J = joints({}, Bn); B.J = J; B.bones = Bn
    h = 1.35
    ab = loft([(-0.0, 0.02, 0.02, 0, 2), (0.06, 0.08, 0.07, 0, 2), (0.16, 0.095, 0.085, 0, 2), (0.3, 0.07, 0.06, 0, 2), (0.42, 0.02, 0.02, 0, 2)], seg_n=10)
    B.piece(xform(ab, Matrix.Translation((0, -0.02, h)) @ Euler((math.radians(-100), 0, 0)).to_matrix().to_4x4()), color='madeira_esc', bone='body', smooth=True,
            colorfn=lambda f: 'tabua_esc' if int((f.calc_center_median().y + 0.5) * 22) % 3 == 0 else 'madeira_esc')
    ruff = mk('ico', sub=2)
    for v in ruff.verts:
        v.co *= 1 + 0.25 * random.Random(int(v.index)).random()
    B.piece(place(ruff, (0, -0.1, h + 0.05), (0.11, 0.1, 0.1)), color='cortica', bone='body', jitter=0.01)
    B.piece(place(mk('sphere', u=10, v=7), (0, -0.22, h + 0.08), (0.075, 0.07, 0.07)), color='cortica', bone='head', jitter=0.003)
    for sx in (1, -1):
        s = 'L' if sx > 0 else 'R'
        c = Vector((sx * 0.045, -0.275, h + 0.1)); n = Vector((sx * 0.6, -1, 0.2)).normalized()
        eye_quad(B, c, n, 0.06, 0.06, 'head', lid='cortica', tilt=sx * -15, mirror=sx < 0)
        a, t = J['ant.' + s]
        B.piece(tube([a, a.lerp(t, 0.5) + Vector((0, -0.04, 0)), t], [0.008, 0.007, 0.004], seg_n=5), color='tabua_esc', bone='ant.' + s, oline=0.6)
        for k in range(5):  # pente da antena plumosa
            p = a.lerp(t, 0.3 + k * 0.15)
            B.piece(seg(mk('cyl', seg=4), p, p + Vector((sx * 0.05, -0.02, -0.01)), 0.005), color='tabua_esc', bone='ant.' + s, oline=0.4)
        # asas de retalho de chita (anterior e posterior)
        for wi, (span, chord, yo, ang) in enumerate(((0.62, 0.3, -0.06, 8), (0.42, 0.26, 0.14, -18))):
            outline = []
            for k in range(14):
                t_ = k / 13
                x = span * t_
                hw = chord * (0.35 + 0.65 * math.sin(math.pi * min(1, t_ * 1.15)) ** 0.7) * (1 - 0.25 * t_)
                outline.append((x, hw))
            bm = bmesh.new()
            top = [bm.verts.new((x, -w * 0.5 + yo, 0.0)) for x, w in outline]
            bot = [bm.verts.new((x, w * 0.5 + yo, 0.0)) for x, w in outline]
            for k in range(13):
                bm.faces.new([top[k], top[k + 1], bot[k + 1], bot[k]])
            bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.012)
            M = Matrix.Translation((sx * 0.07, -0.04, h + 0.1)) @ Euler((0, 0, math.radians(sx * ang))).to_matrix().to_4x4() @ Matrix.Diagonal((sx, 1, 1, 1))
            bm = xform(bm, M)
            if sx < 0:
                bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
            B.piece(bm, mat='pano', color='creme', bone='wing.' + s, smooth=False, uvfn=planar_uv(1.6, 1.6, -0.7, -0.4, 'xy'), oline=0.9)
    return B

def bastidor_bones():
    return [('root', (0, 0, 0), (0, 0, 0.1), None), ('flat', (0, 0, 0.0), (0, 0, 1.0), 'root'),
            ('eyes', (0, -0.05, 1.3), (0, -0.05, 1.4), 'flat')]

def build_bastidor():
    Bn = bastidor_bones(); B = Builder(51, [b[0] for b in Bn]); J = joints({}, Bn); B.J = J; B.bones = Bn
    W, H, T = 1.05, 1.85, 0.05
    # lona da frente (textura 'bastidor': paisagem desbotada e mofo)
    cv = place(mk('cube'), (0, -0.0, H / 2), (W / 2 - 0.02, 0.012, H / 2 - 0.02))
    B.piece(cv, mat='pano', color='creme', bone='flat', uvfn=planar_uv(1 / W, 1 / H, -W / 2, 0.0, 'xz'), oline=0.8)
    # moldura de sarrafo
    for (a, b) in [((-W / 2, 0, 0), (-W / 2, 0, H)), ((W / 2, 0, 0), (W / 2, 0, H)), ((-W / 2, 0, H), (W / 2, 0, H)), ((-W / 2, 0, 0.02), (W / 2, 0, 0.02))]:
        bm = mk('cube', bevel=0.2)
        a, b = Vector(a), Vector(b)
        L = (b - a).length
        q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
        bm = xform(bm, Matrix.Translation((a + b) / 2 + Vector((0, 0.03, 0))) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((0.035, 0.03, L / 2 + 0.035, 1)))
        B.piece(bm, color='madeira_esc', bone='flat', jitter=0.002)
    # mão-francesa atrás com peso de saco
    bm = seg(mk('cube'), (0, 0.06, 1.3), (0, 0.55, 0.02), 1.0)
    bmesh.ops.scale(bm, vec=(0.03, 0.03, 1), verts=bm.verts)
    B.piece(seg(mk('cyl', seg=4), (0, 0.06, 1.25), (0, 0.55, 0.03), 0.03), color='madeira_esc', bone='flat', jitter=0.002)
    B.piece(place(mk('sphere', u=10, v=6), (0, 0.55, 0.08), (0.13, 0.1, 0.08)), color='lona', bone='flat', jitter=0.01)
    # olhos zangados sobre a pintura
    for sx in (1, -1):
        eye_quad(B, Vector((sx * 0.17, -0.02, 1.3)), Vector((0, -1, 0)), 0.2, 0.13, 'eyes', lid='mofo', tilt=sx * -14, mirror=sx < 0)
    return B

def contrarregra_bones():
    return [('root', (0, 0, 0), (0, 0, 0.1), None), ('hips', (0, 0, 0.9), (0, 0, 1.15), 'root'), ('chest', (0, 0, 1.15), (0, 0, 1.45), 'hips'),
            ('head', (0, 0, 1.48), (0, 0, 1.7), 'chest'),
            ('upperarm.L', (0.2, 0, 1.42), (0.24, 0, 1.12), 'chest'), ('forearm.L', (0.24, 0, 1.12), (0.26, -0.02, 0.86), 'upperarm.L'),
            ('upperarm.R', (-0.2, 0, 1.42), (-0.24, 0, 1.12), 'chest'), ('forearm.R', (-0.24, 0, 1.12), (-0.26, -0.02, 0.86), 'upperarm.R'),
            ('thigh.L', (0.1, 0, 0.9), (0.11, 0, 0.48), 'hips'), ('shin.L', (0.11, 0, 0.48), (0.11, 0, 0.05), 'thigh.L'),
            ('thigh.R', (-0.1, 0, 0.9), (-0.11, 0, 0.48), 'hips'), ('shin.R', (-0.11, 0, 0.48), (-0.11, 0, 0.05), 'thigh.R')]

def build_contrarregra():
    Bn = contrarregra_bones(); B = Builder(61, [b[0] for b in Bn]); J = joints({}, Bn); B.J = J; B.bones = Bn
    c = 'tinta'
    B.piece(xform(loft([(0.85, 0.15, 0.11, 0, 2.2), (1.15, 0.16, 0.11, 0, 2.2), (1.42, 0.2, 0.12, 0, 2.6), (1.48, 0.07, 0.06, 0, 2)], seg_n=10), Matrix()), color=c, bone='chest',
            weights=lambda co: {'hips': 1.0} if co.z < 1.1 else {'chest': 1.0})
    B.piece(xform(loft([(1.46, 0.05, 0.05, 0, 2), (1.55, 0.11, 0.12, 0, 2), (1.68, 0.1, 0.11, 0, 2), (1.75, 0.03, 0.03, 0.01, 2)], seg_n=10), Matrix()), color=c, bone='head')
    for s in ('L', 'R'):
        for b in ('upperarm', 'forearm', 'thigh', 'shin'):
            h, t = J[b + '.' + s]
            B.piece(seg(mk('cyl', seg=7), h, t, 0.05 if b in ('upperarm', 'forearm') else 0.065), color=c, bone=b + '.' + s)
        _, t = J['forearm.' + s]
        B.piece(place(mk('sphere', u=7, v=5), t + Vector((0, 0, -0.04)), (0.05, 0.05, 0.07)), color=c, bone='forearm.' + s)
        _, t = J['shin.' + s]
        B.piece(place(mk('cube', bevel=0.3), t + Vector((0, -0.06, -0.02)), (0.06, 0.12, 0.035)), color=c, bone='shin.' + s)
    return B

ENEMIES = {'caruncho': build_caruncho, 'caruncho_chifre': lambda: build_caruncho(True), 'traca': build_traca, 'bastidor': build_bastidor, 'contrarregra': build_contrarregra}

# ================================================================== montagem
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

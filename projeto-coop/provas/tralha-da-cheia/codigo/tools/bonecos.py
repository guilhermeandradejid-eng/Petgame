# Gerador dos bonecos de miriti da Tralha da Cheia (heróis, Inchados e armas), só bpy/bmesh.
# Regras de material: toda peça é facetada a faca (6 a 12 cortes por volta, semente fixa), uma peça por osso, com
# junta à mostra em miriti cru. Só pano e borracha esticam (saia, lenço, boia). Pintura por faceta em pintura.py.
# Eixos do Blender: frente = -Y, cima = +Z, esquerda do boneco = +X.
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler, Quaternion
from malha import *

# ================================================================== formas facetadas
def limb(a, b, r0, r1, seg_n=7, n=2.2, bulge=0.0, flat=1.0, rings=4, phase=0.3, cap=True, twist=0.0):
    """Bloco facetado e afunilado entre a e b (braço, perna, cabo)."""
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
    """ponto da frente (-Y) de um loft de anéis (z relativo ao loft) e a normal."""
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

def eye_quad(B, center, nrm, w, h, bone, lid='pele', tilt=0.0, mirror=False):
    """olho de ponto pintado: quad com UV 0..1; o shader 'olho' desenha o ponto, o brilho e a pálpebra."""
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
            vs[i, j] = bm.verts.new(center + xa * (u - 0.5) * w + ya * (v - 0.5) * h + nrm * (0.003 + bul * h * 0.2))
    for i in range(N):
        for j in range(N):
            bm.faces.new([vs[i, j], vs[i + 1, j], vs[i + 1, j + 1], vs[i, j + 1]])
    lut = {(round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5)): ((1 - i / N) if mirror else i / N, j / N) for (i, j), v in vs.items()}
    def uvfn(co):
        return lut.get((round(co.x, 5), round(co.y, 5), round(co.z, 5)), (0.5, 0.5))
    B.piece(bm, paint=lid, bone=bone, mat='olho', hull=False, uvfn=uvfn)

def peg(B, c, r, bone, axis=(1, 0, 0)):
    """junta à mostra: tarugo de miriti cru."""
    a = Vector(c) - Vector(axis) * r * 0.9; b = Vector(c) + Vector(axis) * r * 0.9
    B.piece(limb(a, b, r, r, seg_n=7, rings=2), paint={'base': 'miriti', 'cru': True}, bone=bone, oline=0.6)

def mitt(B, side, wr, d, up, s, bone, pose='fist', paint='pele'):
    """mão de bloco com 3 dedos: palma, polegar e um bloco de dedos (ou o punho fechado no cabo)."""
    d = Vector(d).normalized(); up = Vector(up).normalized()
    sx = 1 if side == 'L' else -1
    side_v = d.cross(up).normalized() * sx
    M = Matrix((side_v, up, -d)).transposed().to_4x4()  # colunas: x=lado, y=cima(palma), z=-dir
    M = Matrix.Translation(wr) @ M @ Matrix.Diagonal((s, s, s, 1))
    parts = []
    if pose == 'fist':
        # luva fechada: palma em almofada, rolo de dedos mais largo que o punho e polegar à parte por cima
        parts.append(place(loft([(0.0, 0.04, 0.036, 0, 2.2), (0.03, 0.052, 0.046, 0, 2.6), (0.08, 0.056, 0.05, 0.004, 2.6), (0.11, 0.046, 0.04, 0.006, 2.2)],
                                seg_n=8, phase=0.2), (0, 0, 0), (1, 1, -1)))
        parts.append(place(limb((0.058, 0.03, -0.07), (-0.058, 0.03, -0.07), 0.034, 0.034, seg_n=7, rings=2), (0, 0, 0)))
        parts.append(limb((-0.03, 0.03, -0.02), (-0.062, 0.075, -0.06), 0.022, 0.016, seg_n=6, rings=2))
    else:
        parts.append(place(loft([(0.0, 0.04, 0.022, 0, 2.2), (0.04, 0.054, 0.028, 0, 2.6), (0.09, 0.056, 0.028, 0, 2.6), (0.11, 0.05, 0.024, 0, 2.2)],
                                seg_n=8, phase=0.2), (0, 0, 0), (1, 1, -1)))
        for fx, ang in ((0.032, -6), (-0.002, 0), (-0.036, 7)):   # 3 dedos em bloco, de ponta redonda
            parts.append(limb((fx, 0.0, -0.1), (fx + math.sin(math.radians(ang)) * 0.07, -0.004, -0.17), 0.017, 0.014, seg_n=6, rings=3, bulge=0.002))
        parts.append(limb((-0.045, -0.005, -0.03), (-0.095, -0.02, -0.075), 0.02, 0.015, seg_n=6, rings=2))
    for bm in parts:
        B.piece(xform(bm, M), paint=paint, bone=bone, jitter=0.002, oline=0.85)

# ================================================================== cabeça de jogo
# A câmera de camarote vê os bonecos de cima: a cabeça (e o que vai nela) cresce 1,3x a partir da base e o crânio
# inclina 12° para trás, para a cara olhar para a câmera. As peças presas só a esses ossos são transformadas na
# hora (Builder.xf) e os ossos são acertados no fim (cabeca_ossos).
HEAD_K, HEAD_TILT = 1.3, -12.0
def cabeca_grande(B, S, nomes):
    piv = Vector((0, 0, S['headb']))
    M = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(HEAD_TILT), 4, 'X') @ Matrix.Diagonal((HEAD_K, HEAD_K, HEAD_K, 1)) @ Matrix.Translation(-piv)
    for n in nomes:
        B.xf[n] = (M, HEAD_K)
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

# ================================================================== esqueleto comum dos heróis
def hero_bones(S):
    B = []
    hip, wz, cz, nz, hb, ht = S['hip'], S['waist'], S['chest'], S['neck'], S['headb'], S['headt']
    B.append(('root', (0, 0, 0), (0, 0, 0.12), None))
    B.append(('hips', (0, 0, hip), (0, 0, wz), 'root'))
    B.append(('spine', (0, 0, wz), (0, 0, cz), 'hips'))
    B.append(('chest', (0, 0, cz), (0, 0, nz), 'spine'))
    B.append(('neck', (0, 0, nz), (0, 0, hb), 'chest'))
    B.append(('head', (0, 0, hb), (0, 0, ht), 'neck'))
    B.append(('hat', (0, 0, ht - 0.02), (0, 0, ht + 0.12), 'head'))
    for s, sx in (('L', 1), ('R', -1)):
        sh = Vector((sx * S['shw'], 0, S['shz']))
        el = sh + Vector((sx * S['ua_out'], 0.0, -S['ua']))
        wr = el + Vector((sx * 0.01, -0.03, -S['fa']))
        hc = wr + (wr - el).normalized() * 0.06 * S['hs']
        B.append(('shoulder.' + s, (sx * 0.06, 0, S['shz']), tuple(sh), 'chest'))
        B.append(('upperarm.' + s, tuple(sh), tuple(el), 'shoulder.' + s))
        B.append(('forearm.' + s, tuple(el), tuple(wr), 'upperarm.' + s))
        B.append(('hand.' + s, tuple(wr), tuple(hc + (wr - el).normalized() * 0.05), 'forearm.' + s))
        if s == 'R':
            # adereço: cabeça no punho, cauda para a frente (a arma em repouso aponta para -Y)
            B.append(('prop', tuple(hc), tuple(hc + Vector((0, -0.25, 0))), 'hand.R'))
        lx = sx * S['legx']
        B.append(('thigh.' + s, (lx, 0, hip), (lx, -0.01, S['knee']), 'hips'))
        B.append(('shin.' + s, (lx, -0.01, S['knee']), (lx, 0.0, S['ankle']), 'thigh.' + s))
        B.append(('foot.' + s, (lx, 0.0, S['ankle']), (lx, -0.12, S['ankle'] - 0.02), 'shin.' + s))
    for (n, h, t, p) in S.get('extra', []):
        B.append((n, h, t, p))
    return B

def J(B, n):
    for bn, h, t, p in B:
        if bn == n:
            return Vector(h), Vector(t)
    raise KeyError(n)

def arm_pieces(B, bones, S, side, sleeve, skin, pose='fist'):
    sx = 1 if side == 'L' else -1
    sh, el = J(bones, 'upperarm.' + side)
    _, wr = J(bones, 'forearm.' + side)
    r = S['arm_r']
    B.piece(limb(sh + Vector((0, 0, 0.02)), el, r * 1.35, r * 0.78, seg_n=7, bulge=r * 0.22, phase=0.2, rings=5), paint=S.get('ua_paint', skin), bone='upperarm.' + side, jitter=0.002)
    if sleeve:
        sl = dict(sleeve) if isinstance(sleeve, dict) else {'base': sleeve}
        B.piece(limb(sh + Vector((0, 0, 0.05)), sh + (el - sh) * S.get('sleeve_len', 0.55), r * 1.45, r * 1.3, seg_n=8, rings=3, phase=0.1),
                paint=sl, bone='upperarm.' + side, jitter=0.003, smooth=False)
    fa = [(0.0, r * 0.82), (0.3, r * 1.12), (0.65, r * 0.86), (1.0, r * 0.58)]   # antebraço: cheio perto do cotovelo, punho fino
    L = (wr - el).length
    fab = loft([(t * L, rr, rr * 0.92, 0.0, 2.2) for t, rr in fa], seg_n=7, phase=0.5)
    B.piece(xform(fab, Matrix.Translation(el) @ Vector((0, 0, 1)).rotation_difference((wr - el).normalized()).to_matrix().to_4x4()),
            paint=S.get('fa_paint', skin), bone='forearm.' + side, jitter=0.002)
    peg(B, el, r * 0.55, 'forearm.' + side)
    d = (wr - el).normalized()
    up = Vector((-sx, 0, 0))
    mitt(B, side, wr, d, up, S['hs'], 'hand.' + side,
         pose='fist' if side == 'R' else S.get('left_hand', 'open'), paint=S.get('hand_paint', skin))

def leg_pieces(B, bones, S, side, pants, shin_paint, foot_fn):
    th, kn = J(bones, 'thigh.' + side)
    _, an = J(bones, 'shin.' + side)
    r = S['leg_r']
    B.piece(limb(th, kn, r * 1.45, r * 0.82, seg_n=7, phase=0.4, rings=4, bulge=r * 0.12), paint=pants, bone='thigh.' + side, jitter=0.002)
    L = (an - kn).length
    sb = loft([(0.0, r * 0.82, r * 0.82, 0, 2.2), (0.3 * L, r * 1.05, r * 1.0, 0.004, 2.2), (0.75 * L, r * 0.72, r * 0.7, 0, 2.2), (L, r * 0.6, r * 0.6, 0, 2.2)], seg_n=7, phase=0.1)
    B.piece(xform(sb, Matrix.Translation(kn) @ Vector((0, 0, 1)).rotation_difference((an - kn).normalized()).to_matrix().to_4x4()),
            paint=shin_paint, bone='shin.' + side, jitter=0.002)
    peg(B, kn, r * 0.6, 'shin.' + side)
    foot_fn(B, side, an)

# ================================================================== Tiá Marola, a estivadora (trapézio)
def build_marola():
    S = dict(hip=0.56, waist=0.66, chest=0.84, neck=1.02, headb=1.06, headt=1.30, shz=0.99, shw=0.31, ua=0.26, ua_out=0.05,
             fa=0.24, hs=1.4, legx=0.12, knee=0.31, ankle=0.08, arm_r=0.07, leg_r=0.066)
    hb, ht = S['headb'], S['headt']
    S['extra'] = [
        ('lenco.L', (0.0, -0.02, ht + 0.02), (0.13, 0.03, ht + 0.12), 'hat'),
        ('lenco.R', (0.0, -0.02, ht + 0.02), (-0.13, 0.03, ht + 0.12), 'hat'),
        ('back', (0, 0.12, 0.86), (0, 0.12, 1.06), 'chest'),
    ]
    for s, d in (('F', (0, -1)), ('B', (0, 1)), ('L', (1, 0)), ('R', (-1, 0))):
        S['extra'].append(('skirt.' + s, (d[0] * 0.10, d[1] * 0.08, S['waist'] - 0.02), (d[0] * 0.25, d[1] * 0.21, 0.36), 'hips'))
    bones = hero_bones(S)
    B = Builder(11, [b[0] for b in bones], outline=0.006)
    B.bones = bones; B.S = S
    cabeca_grande(B, S, ['head', 'hat', 'lenco.L', 'lenco.R'])
    # --- tronco em trapézio: ombros enormes, cintura estreita
    blusa = {'base': 'urucum', 'pat': ['zigue', 'bolinhas'], 'pats': [{'c1': 'amarelo', 's': 0.11, 'zs': 0.045, 'amp': 0.4, 'w': 0.22, 'R': 0.25, 'center': (0, 0, 0.9)},
             {'c1': 'miriti', 's': 0.055, 'r': 0.14, 'dens': 0.5}], 'wear': 0.55}
    torso = loft([(0.0, 0.17, 0.13, 0.0, 2.4), (0.10, 0.20, 0.14, 0.0, 2.4), (0.24, 0.32, 0.17, 0.0, 3.0), (0.33, 0.36, 0.165, 0.01, 3.2),
                  (0.38, 0.30, 0.14, 0.02, 2.6), (0.40, 0.12, 0.09, 0.02, 2.0)], seg_n=10, phase=0.31)
    B.piece(place(torso, (0, 0, S['waist'] - 0.03)), paint=blusa, bone='chest', jitter=0.004)
    # barriga e quadril (miolo, coberto pela saia)
    B.piece(place(loft([(0, 0.15, 0.12, 0, 2.2), (0.12, 0.18, 0.13, 0, 2.2), (0.2, 0.16, 0.12, 0, 2.2)], seg_n=9), (0, 0, S['hip'] - 0.04)),
            paint='escuro', bone='hips', jitter=0.003)
    # saia curta e rodada: pano escuro (massa escura no pé) com barra pintada
    saia = {'base': 'escuro', 'pat': ['faixas', 'bolinhas'], 'pats': [{'c1': 'urucum', 'bands': [(0.37, 0.43)]}, {'c1': 'miriti', 's': 0.06, 'r': 0.16, 'dens': 0.7}],
            'wear': 0.4}
    rings = [(0.0, 0.17, 0.135, 0.0, 2.2), (0.08, 0.22, 0.17, 0.0, 2.2), (0.20, 0.29, 0.24, 0.0, 2.3), (0.30, 0.31, 0.26, 0.0, 2.3)]
    sk = loft([(z, w, d, yo, n) for z, w, d, yo, n in rings], seg_n=12, cap_bot=False, cap_top=True, phase=0.13)
    sk = place(sk, (0, 0, 0), (1, 1, -1))
    sk = place(sk, (0, 0, S['waist'] + 0.02))
    def skirt_w(co):
        t = max(0.0, min(1.0, (S['waist'] - co.z) / 0.3))
        w = {'hips': 1 - t}
        ax = abs(co.x); ay = abs(co.y)
        tot = ax + ay + 1e-6
        w['skirt.L' if co.x > 0 else 'skirt.R'] = t * ax / tot
        w['skirt.B' if co.y > 0 else 'skirt.F'] = t * ay / tot
        return w
    B.piece(sk, paint=saia, weights=skirt_w, jitter=0.003, mat='pano')
    # pescoço grosso
    B.piece(limb((0, 0.0, S['neck'] - 0.03), (0, 0.0, S['headb'] + 0.02), 0.06, 0.055, seg_n=7, rings=2), paint='pele', bone='neck')
    # --- cabeça pequena por perfil: mandíbula larga, testa reta, coberta pelo lenço
    hr = [(0.0, 0.050, 0.055, -0.005, 2.2), (0.03, 0.085, 0.085, -0.008, 2.4), (0.08, 0.098, 0.095, 0.0, 2.6), (0.14, 0.096, 0.098, 0.004, 2.4),
          (0.19, 0.082, 0.088, 0.006, 2.2), (0.225, 0.05, 0.06, 0.008, 2.0)]
    z0 = hb
    pe, pn = front_pt(hr, -0.045, 0.105, z0)
    ped, pnd = front_pt(hr, 0.045, 0.105, z0)
    pm, _ = front_pt(hr, 0.0, 0.045, z0)
    marks = [('traco', [pm + Vector((-0.032, 0.001, 0.008)), pm + Vector((-0.012, -0.002, -0.002)), pm + Vector((0.012, -0.002, -0.002)), pm + Vector((0.032, 0.001, 0.008))], 0.0045, 'tinta'),
             ('traco', [pe + Vector((-0.022, 0.0, 0.026)), pe + Vector((0.018, -0.002, 0.03))], 0.004, 'tinta'),
             ('traco', [ped + Vector((-0.018, -0.002, 0.03)), ped + Vector((0.022, 0.0, 0.026))], 0.004, 'tinta'),
             ('disco', pe + Vector((-0.012, 0.0, -0.04)), 0.017, 'urucum'), ('disco', ped + Vector((0.012, 0.0, -0.04)), 0.017, 'urucum')]
    B.piece(place(loft(hr, seg_n=10, phase=0.0), (0, 0, z0)), paint={'base': 'pele', 'marks': marks, 'wear': 0.35}, bone='head', jitter=0.003)
    # nariz em cunha
    pn0, nn0 = front_pt(hr, 0.0, 0.085, z0)
    B.piece(limb(pn0 + Vector((0, 0.01, 0.025)), pn0 + Vector((0, -0.03, -0.012)), 0.017, 0.012, seg_n=5, rings=2), paint='pele', bone='head', oline=0.7)
    for p, n in ((pe, pn), (ped, pnd)):
        eye_quad(B, p, n, 0.046, 0.054, 'head', lid='pele')
    # orelhas
    for sx in (1, -1):
        B.piece(place(mk('cube', bevel=0.35, bseg=1), (sx * 0.098, 0.01, hb + 0.1), (0.012, 0.022, 0.03)), paint='pele', bone='head', oline=0.8)
    # lenço amarrado no alto: touca + nó + duas pontas (mola)
    lenco = {'base': 'amarelo', 'pat': 'bolinhas', 'c1': 'urucum', 's': 0.045, 'r': 0.27, 'dens': 0.75, 'wear': 0.45}
    cap = loft([(0.12, 0.104, 0.104, 0.01, 2.3), (0.17, 0.105, 0.108, 0.012, 2.4), (0.22, 0.09, 0.096, 0.012, 2.2), (0.255, 0.05, 0.06, 0.012, 2.0)],
               seg_n=10, cap_bot=False, phase=0.1)
    B.piece(place(cap, (0, 0, z0)), paint=lenco, bone='head', jitter=0.003, mat='pano')
    knot = place(mk('ico', sub=1), (0, -0.01, ht + 0.035), (0.04, 0.035, 0.03))
    B.piece(knot, paint=lenco, bone='hat', jitter=0.004, mat='pano')
    for s, sx in (('L', 1), ('R', -1)):
        tip = loft([(0.0, 0.022, 0.012, 0, 2.0), (0.06, 0.035, 0.012, 0, 2.0), (0.13, 0.03, 0.01, 0, 2.0), (0.16, 0.008, 0.006, 0, 2.0)], seg_n=6, phase=0.0)
        a, b = J(bones, 'lenco.' + s)
        q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
        B.piece(xform(tip, Matrix.Translation(a) @ q.to_matrix().to_4x4()), paint=lenco, bone='lenco.' + s, jitter=0.002, mat='pano')
    # ombreiras (deltoides) e juntas
    for s, sx in (('L', 1), ('R', -1)):
        sh, el = J(bones, 'upperarm.' + s)
        B.piece(place(mk('ico', sub=1), sh + Vector((sx * 0.02, 0, 0.0)), (0.085, 0.08, 0.075)), paint=blusa, bone='upperarm.' + s, jitter=0.004)
    for s in 'LR':
        arm_pieces(B, bones, S, s, None, 'pele')
    # pernas: calça escura grossa e botina
    def bota(B, side, an):
        sx = 1 if side == 'L' else -1
        b = loft([(0.0, 0.06, 0.1, -0.03, 2.4), (0.05, 0.062, 0.105, -0.035, 2.4), (0.09, 0.05, 0.06, -0.0, 2.2)], seg_n=8)
        B.piece(place(b, (an.x, an.y, 0.0)), paint={'base': 'tinta', 'pat': 'faixas', 'c1': 'miriti_som', 'bands': [(0.0, 0.018)], 'wear': 0.6}, bone='foot.' + side, jitter=0.003)
    for s in 'LR':
        leg_pieces(B, bones, S, s, 'escuro', {'base': 'escuro', 'pat': 'faixas', 'c1': 'urucum', 'bands': [(0.10, 0.125)]}, bota)
    # caixote nas costas: ripas de miriti cru com faixa anil e a marca da estiva
    bz = 0.86
    crate = {'base': 'miriti_som', 'cru': True}
    for k, z in enumerate((0.0, 0.08, 0.16)):
        for sy in (0.0, 0.22):
            B.piece(place(mk('cube'), (0, 0.13 + sy, bz + z + 0.03), (0.2, 0.012, 0.032)), paint={'base': 'anil' if k == 1 else 'miriti_som', 'wear': 1.0, 'cru': k != 1}, bone='back', jitter=0.002, oline=0.8)
        for sx in (1, -1):
            B.piece(place(mk('cube'), (sx * 0.2, 0.24, bz + z + 0.03), (0.012, 0.12, 0.032)), paint={'base': 'anil' if k == 1 else 'miriti_som', 'wear': 1.0, 'cru': k != 1}, bone='back', jitter=0.002, oline=0.8)
    for sx in (1, -1):
        for sy in (0.13, 0.35):
            B.piece(place(mk('cube'), (sx * 0.19, sy, bz + 0.11), (0.018, 0.018, 0.13)), paint=crate, bone='back', jitter=0.002, oline=0.8)
    # alças
    for sx in (1, -1):
        B.piece(tube([(sx * 0.17, -0.05, 0.98), (sx * 0.2, 0.06, 1.02), (sx * 0.19, 0.13, 0.96)], [0.016] * 3, seg_n=5), paint='lama', bone='chest', oline=0.6)
    B.S['_body'] = (0.22, 0.05, 1.3)   # cápsula do corpo para o teste de colisão: raio, z0, z1
    cabeca_ossos(B)
    return B

# ================================================================== Piaba, o mergulhador (bola)
def build_piaba():
    S = dict(hip=0.46, waist=0.52, chest=0.72, neck=0.86, headb=0.88, headt=1.16, shz=0.80, shw=0.25, ua=0.23, ua_out=0.04,
             fa=0.21, hs=1.2, legx=0.11, knee=0.27, ankle=0.08, arm_r=0.054, leg_r=0.06)
    hb, ht = S['headb'], S['headt']
    S['extra'] = [('boia', (0, 0, S['waist'] - 0.04), (0, 0, S['waist'] + 0.12), 'hips'),
                  ('snorkel', (-0.15, -0.02, hb + 0.12), (-0.17, 0.02, ht + 0.12), 'head'),
                  ('flip.L', (0.11, -0.08, 0.02), (0.11, -0.3, 0.02), 'foot.L'),
                  ('flip.R', (-0.11, -0.08, 0.02), (-0.11, -0.3, 0.02), 'foot.R')]
    bones = hero_bones(S)
    B = Builder(23, [b[0] for b in bones], outline=0.006)
    B.bones = bones; B.S = S
    cabeca_grande(B, S, ['head', 'snorkel'])
    # corpo em bola: roupa de mergulho anil com escamas pintadas
    roupa = {'base': 'anil', 'pat': 'escamas', 'c1': 'miriti', 's': 0.05, 'R': 0.2, 'center': (0, 0, 0.6), 'lw': 0.08, 'wear': 0.5}
    body = loft([(0.0, 0.08, 0.08, 0, 2.0), (0.06, 0.17, 0.16, 0, 2.2), (0.16, 0.23, 0.21, 0, 2.3), (0.27, 0.235, 0.215, 0.0, 2.3),
                 (0.36, 0.2, 0.18, 0.0, 2.2), (0.42, 0.12, 0.11, 0.0, 2.0), (0.44, 0.06, 0.06, 0.0, 2.0)], seg_n=10, phase=0.15)
    def bw(co):
        t = max(0.0, min(1.0, (co.z - (S['waist'] - 0.02)) / 0.18))
        return {'hips': 1 - t, 'chest': t}
    B.piece(place(body, (0, 0, S['hip'] - 0.08)), paint=roupa, weights=bw, jitter=0.004)
    # boia de câmara de ar na cintura (borracha: estica e achata pelo osso 'boia')
    tor = bmesh.new()
    Rm, rm, NU, NV = 0.26, 0.075, 14, 7
    vv = {}
    for i in range(NU):
        for j in range(NV):
            u = 2 * math.pi * i / NU; v = 2 * math.pi * j / NV
            vv[i, j] = tor.verts.new(((Rm + rm * math.cos(v)) * math.cos(u), (Rm + rm * math.cos(v)) * math.sin(u) * 0.93, rm * math.sin(v) * 1.1))
    for i in range(NU):
        for j in range(NV):
            tor.faces.new([vv[i, j], vv[(i + 1) % NU, j], vv[(i + 1) % NU, (j + 1) % NV], vv[i, (j + 1) % NV]])
    bmesh.ops.recalc_face_normals(tor, faces=tor.faces[:])
    B.piece(place(tor, (0, 0, S['waist'] + 0.0)), paint={'base': 'escuro', 'marks': [('disco', (0.0, -0.33, S['waist'] + 0.02), 0.03, 'amarelo')], 'wear': 0.25},
            bone='boia', jitter=0.004, mat='pano', smooth=False)
    # válvula
    B.piece(limb((0.0, -0.31, S['waist'] + 0.02), (0.0, -0.36, S['waist'] + 0.05), 0.014, 0.01, seg_n=5, rings=2), paint='amarelo', bone='boia', oline=0.6)
    # cabeça redonda grande
    hr = [(0.0, 0.07, 0.07, 0, 2.0), (0.04, 0.135, 0.13, 0, 2.2), (0.12, 0.165, 0.155, 0, 2.3), (0.2, 0.16, 0.152, 0.005, 2.3),
          (0.26, 0.125, 0.12, 0.01, 2.2), (0.3, 0.06, 0.06, 0.01, 2.0)]
    z0 = hb
    pm, _ = front_pt(hr, 0.0, 0.05, z0)
    marks = [('traco', [pm + Vector((-0.06, 0.0, 0.02)), pm + Vector((-0.03, -0.004, -0.005)), pm + Vector((0.0, -0.005, -0.01)), pm + Vector((0.03, -0.004, -0.005)), pm + Vector((0.06, 0.0, 0.02))], 0.006, 'tinta'),
             ('traco', [pm + Vector((-0.025, -0.002, -0.006)), pm + Vector((0.025, -0.002, -0.006))], 0.004, 'miriti')]
    B.piece(place(loft(hr, seg_n=10, phase=0.0), (0, 0, z0)), paint={'base': 'pele_clara', 'marks': marks, 'wear': 0.3}, bone='head', jitter=0.003)
    # cabelo espetado (cunhas de tinta)
    rng = random.Random(4)
    for k in range(7):
        a = -0.6 + k * 0.2
        base = Vector((math.sin(a) * 0.08, 0.04 + math.cos(a) * 0.04, ht + 0.0))
        tipv = base + Vector((math.sin(a) * 0.05, 0.06, 0.09 + rng.uniform(-0.02, 0.02)))
        B.piece(limb(base, tipv, 0.035, 0.004, seg_n=4, rings=2), paint='tinta', bone='head', oline=0.8)
    # máscara de mergulho enorme: aro de borracha + vidro com reflexo pintado + tira
    mz = hb + 0.15
    frame = bmesh.new()
    NU = 12
    outer, inner = [], []
    for i in range(NU):
        t = 2 * math.pi * i / NU
        x, z = math.cos(t), math.sin(t)
        ox, oz = 0.175 * x, 0.105 * z
        ix, iz = 0.14 * x, 0.075 * z
        y0 = -0.165 + 0.05 * x * x
        outer.append((frame.verts.new((ox, y0 - 0.0, oz)), frame.verts.new((ox * 0.98, y0 + 0.06, oz * 0.98))))
        inner.append((frame.verts.new((ix, y0 - 0.035, iz)), frame.verts.new((ix, y0 + 0.0, iz))))
    for i in range(NU):
        j = (i + 1) % NU
        frame.faces.new([outer[i][0], outer[j][0], inner[j][0], inner[i][0]])
        frame.faces.new([outer[j][1], outer[i][1], outer[i][0], outer[j][0]])
        frame.faces.new([inner[i][0], inner[j][0], inner[j][1], inner[i][1]])
        frame.faces.new([inner[i][1], inner[j][1], outer[j][1], outer[i][1]])
    bmesh.ops.recalc_face_normals(frame, faces=frame.faces[:])
    B.piece(place(frame, (0, 0, mz)), paint={'base': 'escuro', 'wear': 0.3}, bone='head', jitter=0.002)
    glass = bmesh.new()
    gv = [glass.verts.new((0.14 * math.cos(2 * math.pi * i / NU), -0.16 + 0.05 * math.cos(2 * math.pi * i / NU) ** 2 + 0.005, 0.075 * math.sin(2 * math.pi * i / NU))) for i in range(NU)]
    c = glass.verts.new((0, -0.205, 0))
    for i in range(NU):
        glass.faces.new([c, gv[i], gv[(i + 1) % NU]])
    bmesh.ops.recalc_face_normals(glass, faces=glass.faces[:])
    for f in glass.faces:
        if f.normal.y > 0:
            f.normal_flip()
    gm = [('traco', [(-0.1, -0.2, mz + 0.05), (-0.03, -0.21, mz - 0.06)], 0.012, 'miriti'), ('traco', [(-0.055, -0.21, mz + 0.06), (-0.005, -0.21, mz - 0.01)], 0.005, 'miriti')]
    B.piece(place(glass, (0, 0, mz)), paint={'base': 'rio_claro', 'marks': gm, 'wear': 0.0}, bone='head', hull=False)
    # olhos grandes atrás do vidro
    for sx in (1, -1):
        p = Vector((sx * 0.06, -0.205, mz + 0.0))
        eye_quad(B, p, Vector((sx * 0.1, -1, 0.05)).normalized(), 0.06, 0.07, 'head', lid='rio_claro')
    # tira da máscara em volta da cabeça
    strap = [Vector((0.17 * math.cos(a), 0.15 * math.sin(a) + 0.0, mz + 0.01)) for a in [math.radians(x) for x in range(-10, 200, 20)]]
    B.piece(tube(strap, [0.018] * len(strap), seg_n=5, n=3.0, flat=0.5), paint='escuro', bone='head', oline=0.7)
    # snorkel amarelo com faixas urucum
    a, b = J(bones, 'snorkel')
    B.piece(tube([a, a + Vector((-0.02, 0.0, 0.1)), b], [0.022, 0.022, 0.024], seg_n=7), paint={'base': 'amarelo', 'pat': 'faixas', 'c1': 'anil', 'axis': (0, 0, 1),
            'bands': [(hb + 0.25, hb + 0.28), (hb + 0.33, hb + 0.36)], 'wear': 0.5}, bone='snorkel', jitter=0.001)
    B.piece(limb(b - Vector((0, 0, 0.01)), b + Vector((0, 0, 0.03)), 0.03, 0.032, seg_n=7, rings=2), paint='anil', bone='snorkel')
    for s in 'LR':
        sh, el = J(bones, 'upperarm.' + s)
        sx = 1 if s == 'L' else -1
        B.piece(place(mk('ico', sub=1), sh + Vector((sx * 0.01, 0, 0.0)), (0.08, 0.08, 0.08)), paint=roupa, bone='upperarm.' + s, jitter=0.003)
    S['sleeve_len'] = 0.5
    for s in 'LR':
        arm_pieces(B, bones, S, s, {'base': 'anil', 'pat': 'faixas', 'c1': 'amarelo', 'bands': [(0.62, 0.64)]}, 'pele_clara')
    # pés de pato enormes (borracha escura com nervuras amarelas)
    def pe_de_pato(B, side, an):
        sx = 1 if side == 'L' else -1
        B.piece(place(loft([(0.0, 0.05, 0.07, -0.02, 2.2), (0.07, 0.048, 0.07, -0.02, 2.2), (0.1, 0.035, 0.04, -0.0, 2.0)], seg_n=7), (an.x, an.y, 0.0)),
                paint='escuro', bone='foot.' + side, jitter=0.002)
        fl = bmesh.new()
        pts = [(-0.055, 0.0), (0.055, 0.0), (0.11, -0.2), (0.06, -0.25), (0.0, -0.21), (-0.06, -0.25), (-0.11, -0.2)]
        top = [fl.verts.new((an.x + x, an.y - 0.06 + y, 0.035)) for x, y in pts]
        bot = [fl.verts.new((an.x + x, an.y - 0.06 + y, 0.01)) for x, y in pts]
        fl.faces.new(top); fl.faces.new(bot[::-1])
        for i in range(len(pts)):
            j = (i + 1) % len(pts)
            fl.faces.new([bot[i], bot[j], top[j], top[i]])
        bmesh.ops.recalc_face_normals(fl, faces=fl.faces[:])
        rib = [('traco', [(an.x + x0, an.y - 0.08, 0.036), (an.x + x1, an.y - 0.27, 0.036)], 0.008, 'amarelo') for x0, x1 in ((-0.03, -0.08), (0.0, 0.0), (0.03, 0.08))]
        B.piece(fl, paint={'base': 'escuro', 'marks': rib, 'wear': 0.2}, bone='flip.' + side, mat='pano')
    for s in 'LR':
        leg_pieces(B, bones, S, s, {'base': 'anil', 'pat': 'escamas', 'c1': 'miriti', 's': 0.05, 'R': 0.05, 'lw': 0.08}, 'pele_clara', pe_de_pato)
    B.S['_body'] = (0.24, 0.05, 1.2)
    cabeca_ossos(B)
    return B

# ================================================================== Seu Remanso, o balseiro (linha vertical)
def build_remanso():
    S = dict(hip=0.66, waist=0.76, chest=0.98, neck=1.18, headb=1.21, headt=1.44, shz=1.12, shw=0.2, ua=0.27, ua_out=0.03,
             fa=0.25, hs=1.05, legx=0.08, knee=0.37, ankle=0.07, arm_r=0.04, leg_r=0.045)
    hb, ht = S['headb'], S['headt']
    S['extra'] = [('zinga', (0.12, 0.2, 0.05), (0.62, 0.02, 2.45), 'chest')]
    bones = hero_bones(S)
    B = Builder(37, [b[0] for b in bones], outline=0.006)
    B.bones = bones; B.S = S
    cabeca_grande(B, S, ['head', 'hat'])
    camisa = {'base': 'folha', 'pat': 'folhas', 'c1': 'escuro', 'c2': 'folha', 's': 0.07, 'R': 0.12, 'center': (0, 0, 1.0), 'wear': 0.5}
    torso = loft([(0.0, 0.11, 0.09, 0, 2.2), (0.15, 0.12, 0.095, 0, 2.3), (0.32, 0.17, 0.1, 0.0, 2.6), (0.4, 0.15, 0.09, 0.0, 2.4), (0.43, 0.06, 0.06, 0, 2.0)], seg_n=9, phase=0.2)
    B.piece(place(torso, (0, 0, S['waist'] - 0.04)), paint=camisa, bone='chest', jitter=0.003)
    B.piece(place(loft([(0, 0.11, 0.09, 0, 2.2), (0.14, 0.115, 0.09, 0, 2.2)], seg_n=8), (0, 0, S['hip'] - 0.05)),
            paint={'base': 'escuro', 'pat': 'faixas', 'c1': 'urucum', 'bands': [(S['hip'] + 0.06, S['hip'] + 0.085)]}, bone='hips', jitter=0.002)
    B.piece(limb((0, 0, S['neck'] - 0.02), (0, 0, hb + 0.02), 0.04, 0.04, seg_n=6, rings=2), paint='pele', bone='neck')
    # cabeça comprida, queixo pontudo, bigode
    hr = [(0.0, 0.03, 0.04, -0.02, 2.0), (0.04, 0.07, 0.075, -0.01, 2.2), (0.12, 0.085, 0.09, 0.0, 2.4), (0.19, 0.08, 0.088, 0.005, 2.3), (0.23, 0.04, 0.05, 0.005, 2.0)]
    z0 = hb
    pe, pn = front_pt(hr, -0.035, 0.115, z0)
    ped, pnd = front_pt(hr, 0.035, 0.115, z0)
    pm, _ = front_pt(hr, 0.0, 0.06, z0)
    marks = [('traco', [pm + Vector((-0.05, -0.003, -0.012)), pm + Vector((-0.02, -0.01, 0.006)), pm + Vector((0.0, -0.01, 0.0)), pm + Vector((0.02, -0.01, 0.006)), pm + Vector((0.05, -0.003, -0.012))], 0.009, 'tinta'),
             ('traco', [pm + Vector((-0.012, -0.004, -0.03)), pm + Vector((0.012, -0.004, -0.03))], 0.0035, 'tinta')]
    B.piece(place(loft(hr, seg_n=9), (0, 0, z0)), paint={'base': 'pele', 'marks': marks, 'wear': 0.3}, bone='head', jitter=0.003)
    pn0, _ = front_pt(hr, 0.0, 0.095, z0)
    B.piece(limb(pn0 + Vector((0, 0.01, 0.03)), pn0 + Vector((0, -0.04, -0.02)), 0.016, 0.01, seg_n=5, rings=2), paint='pele', bone='head', oline=0.7)
    for p, n in ((pe, pn), (ped, pnd)):
        eye_quad(B, p, n, 0.036, 0.042, 'head', lid='pele')
    # chapéu cônico alto de palha pintada (mola)
    hat = loft([(0.0, 0.2, 0.2, 0.0, 2.0), (0.02, 0.2, 0.2, 0.0, 2.0), (0.035, 0.1, 0.1, 0, 2.0), (0.32, 0.012, 0.012, 0.0, 2.0)], seg_n=9, cap_bot=True)
    B.piece(place(hat, (0, 0.0, ht - 0.07)), paint={'base': 'lama', 'pat': ['listras', 'faixas'], 'pats': [{'c1': 'ferrugem', 's': 0.03, 'w': 0.3, 'axis': (0.3, 0.3, 1)}, {'c1': 'folha', 'bands': [(ht - 0.07, ht - 0.02), (ht + 0.05, ht + 0.09)]}], 'wear': 0.55},
            bone='hat', jitter=0.003)
    for s in 'LR':
        arm_pieces(B, bones, S, s, camisa, 'pele')
    def pe_descalco(B, side, an):
        B.piece(place(loft([(0.0, 0.04, 0.09, -0.04, 2.2), (0.04, 0.042, 0.09, -0.04, 2.2), (0.07, 0.03, 0.04, 0.0, 2.0)], seg_n=7), (an.x, an.y, 0.0)), paint='pele', bone='foot.' + side, jitter=0.002)
    for s in 'LR':
        leg_pieces(B, bones, S, s, 'escuro', {'base': 'escuro', 'pat': 'faixas', 'c1': 'miriti_som', 'bands': [(0.2, 0.37)]}, pe_descalco)
    # zinga apoiada no ombro
    a, b = J(bones, 'zinga')
    B.piece(limb(a, b, 0.036, 0.028, seg_n=7, rings=3), paint={'base': 'lama', 'pat': 'faixas', 'c1': 'miriti', 'axis': (0.2, -0.07, 0.98),
            'bands': [(0.9, 0.96), (1.9, 1.96)], 'wear': 0.8}, bone='zinga', oline=1.0, jitter=0.002)
    # mão esquerda agarrada na vara e amarra de corda no meio
    B.piece(tube([a + (b - a) * t + Vector((0.035 * math.cos(k), 0.035 * math.sin(k), 0.0)) for k, t in zip([0, 2, 4, 6, 8], [0.6, 0.61, 0.62, 0.63, 0.64])], [0.012] * 5, seg_n=5),
            paint='miriti_som', bone='zinga', oline=0.5)
    B.S['_body'] = (0.16, 0.05, 1.5)
    cabeca_ossos(B)
    return B

# ================================================================== Mestra Breu, a calafate (assimétrica)
def build_breu():
    S = dict(hip=0.54, waist=0.63, chest=0.82, neck=0.99, headb=1.02, headt=1.26, shz=0.95, shw=0.24, ua=0.25, ua_out=0.05,
             fa=0.23, hs=1.1, legx=0.1, knee=0.3, ankle=0.07, arm_r=0.05, leg_r=0.052)
    hb, ht = S['headb'], S['headt']
    S['extra'] = [('balde', (0.2, -0.02, 0.62), (0.2, -0.02, 0.45), 'hips'), ('estopa', (0.27, 0.07, 1.0), (0.31, 0.1, 0.74), 'shoulder.L'),
                  ('pote', (0.0, 0.2, 0.6), (0.0, 0.2, 0.9), 'chest')]
    bones = hero_bones(S)
    B = Builder(41, [b[0] for b in bones], outline=0.006)
    B.bones = bones; B.S = S
    cabeca_grande(B, S, ['head', 'hat'])
    avental = {'base': 'acai', 'pat': 'bolinhas', 'c1': 'amarelo', 's': 0.06, 'r': 0.25, 'wear': 0.55}
    torso = loft([(0.0, 0.16, 0.12, 0, 2.2), (0.14, 0.17, 0.125, 0, 2.3), (0.3, 0.22, 0.13, 0, 2.6), (0.35, 0.16, 0.1, 0.0, 2.2), (0.37, 0.07, 0.06, 0, 2.0)], seg_n=9, phase=0.2)
    B.piece(place(torso, (0, 0, S['waist'] - 0.03)), paint=avental, bone='chest', jitter=0.004)
    sk = loft([(0.0, 0.17, 0.13, 0, 2.2), (0.15, 0.24, 0.2, 0, 2.2), (0.26, 0.26, 0.22, 0, 2.2)], seg_n=11, cap_bot=False)
    sk = place(place(sk, (0, 0, 0), (1, 1, -1)), (0, 0, S['waist'] + 0.02))
    B.piece(sk, paint={'base': 'escuro', 'pat': 'faixas', 'c1': 'acai', 'bands': [(0.37, 0.41)], 'wear': 0.4}, bone='hips', jitter=0.003, mat='pano')
    B.piece(limb((0, 0, S['neck'] - 0.02), (0, 0, hb + 0.02), 0.05, 0.05, seg_n=6, rings=2), paint='pele_clara', bone='neck')
    hr = [(0.0, 0.06, 0.06, -0.005, 2.0), (0.05, 0.1, 0.095, 0, 2.3), (0.13, 0.11, 0.105, 0.0, 2.4), (0.2, 0.09, 0.09, 0.005, 2.2), (0.24, 0.04, 0.05, 0.01, 2.0)]
    z0 = hb
    pe, pn = front_pt(hr, -0.04, 0.115, z0)
    ped, pnd = front_pt(hr, 0.04, 0.115, z0)
    pm, _ = front_pt(hr, 0.0, 0.05, z0)
    marks = [('traco', [pm + Vector((-0.03, 0.0, -0.004)), pm + Vector((0.0, -0.004, 0.004)), pm + Vector((0.03, 0.0, -0.002))], 0.0045, 'tinta'),
             ('traco', [pe + Vector((-0.02, 0.0, 0.035)), pe + Vector((0.02, -0.003, 0.025))], 0.005, 'tinta'),
             ('traco', [ped + Vector((-0.02, -0.003, 0.03)), ped + Vector((0.02, 0.0, 0.034))], 0.005, 'tinta')]
    B.piece(place(loft(hr, seg_n=9), (0, 0, z0)), paint={'base': 'pele_clara', 'marks': marks, 'wear': 0.3}, bone='head', jitter=0.003)
    pn0, _ = front_pt(hr, 0.0, 0.085, z0)
    B.piece(limb(pn0 + Vector((0, 0.01, 0.02)), pn0 + Vector((0, -0.035, -0.015)), 0.02, 0.014, seg_n=5, rings=2), paint='pele_clara', bone='head', oline=0.7)
    for p, n in ((pe, pn), (ped, pnd)):
        eye_quad(B, p, n, 0.04, 0.046, 'head', lid='pele_clara')
    # cabelo com coque e lenço
    hair = loft([(0.12, 0.115, 0.115, 0.012, 2.3), (0.2, 0.1, 0.1, 0.012, 2.3), (0.25, 0.05, 0.06, 0.015, 2.0)], seg_n=9, cap_bot=False)
    B.piece(place(hair, (0, 0, z0)), paint='tinta', bone='head', jitter=0.003)
    B.piece(place(mk('ico', sub=1), (0, 0.07, ht + 0.03), (0.06, 0.06, 0.055)), paint='tinta', bone='hat', jitter=0.004)
    # braço esquerdo normal; braço direito com luva de couro enorme
    arm_pieces(B, bones, S, 'L', avental, 'pele_clara')
    S['hand_paint'] = 'ferrugem'
    S['fa_paint'] = {'base': 'ferrugem', 'pat': 'faixas', 'c1': 'tinta', 'bands': [(0.62, 0.65)], 'wear': 0.7}
    arm_pieces(B, bones, S, 'R', avental, 'pele_clara')
    _, wr = J(bones, 'forearm.R')
    el, _ = J(bones, 'forearm.R')
    B.piece(limb(el + (wr - el) * 0.35, wr + (wr - el) * 0.15, 0.09, 0.1, seg_n=8, rings=3), paint={'base': 'ferrugem', 'pat': 'faixas', 'c1': 'tinta', 'bands': [(0.6, 0.63), (0.68, 0.7)], 'axis': (0, 0, 1), 'wear': 0.8},
            bone='forearm.R', jitter=0.004)
    def bota(B, side, an):
        B.piece(place(loft([(0.0, 0.055, 0.09, -0.03, 2.3), (0.06, 0.055, 0.09, -0.03, 2.3), (0.09, 0.045, 0.05, 0.0, 2.0)], seg_n=7), (an.x, an.y, 0.0)), paint='tinta', bone='foot.' + side, jitter=0.002)
    for s in 'LR':
        leg_pieces(B, bones, S, s, 'escuro', 'escuro', bota)
    # balde de breu na cintura, pingando
    a, b = J(bones, 'balde')
    bal = loft([(0.0, 0.07, 0.07, 0, 2.0), (0.14, 0.085, 0.085, 0, 2.0)], seg_n=8, cap_top=False)
    B.piece(place(bal, (a.x, a.y, b.z)), paint={'base': 'miriti_som', 'pat': 'faixas', 'c1': 'acai', 'bands': [(b.z + 0.1, b.z + 0.12)], 'wear': 0.9}, bone='balde', jitter=0.003)
    B.piece(place(loft([(0.0, 0.075, 0.075, 0, 2.0), (0.01, 0.075, 0.075, 0, 2.0)], seg_n=8), (a.x, a.y, b.z + 0.12)), paint='tinta', bone='balde')
    B.piece(tube([(a.x + 0.08, a.y, b.z + 0.13), (a.x, a.y, b.z + 0.24), (a.x - 0.08, a.y, b.z + 0.13)], [0.007] * 3, seg_n=4), paint='tinta', bone='balde', oline=0.5)
    # pote de breu nas costas, preso por alça; pincel de estopa saindo torto para cima e para a direita
    pz = 0.66
    pote = loft([(0.0, 0.13, 0.12, 0, 2.2), (0.06, 0.19, 0.17, 0, 2.3), (0.2, 0.2, 0.18, 0, 2.3), (0.3, 0.16, 0.15, 0, 2.2), (0.33, 0.17, 0.16, 0, 2.2)],
                seg_n=10, cap_top=False, phase=0.1)
    B.piece(place(pote, (-0.03, 0.27, pz)), paint={'base': 'ferrugem', 'descasca': 0.25, 'sob': 'lama', 'pat': 'faixas', 'c1': 'tinta', 'axis': (0, 0, 1),
            'bands': [(pz + 0.25, pz + 0.34)], 'wear': 0.8, 'marks': [('traco', [(-0.03 + 0.18 * math.cos(a), 0.27 + 0.16 * math.sin(a), pz + 0.26), (-0.03 + 0.19 * math.cos(a), 0.27 + 0.17 * math.sin(a), pz + 0.15 + 0.05 * (k % 2))], 0.016, 'tinta') for k, a in enumerate([3.6, 4.2, 4.9, 5.5, 0.3, 1.1])]},
            bone='pote', jitter=0.005)
    B.piece(place(loft([(0.0, 0.15, 0.14, 0, 2.2), (0.015, 0.15, 0.14, 0, 2.2)], seg_n=10), (-0.03, 0.27, pz + 0.3)), paint={'base': 'tinta', 'wear': 0.0}, bone='pote', oline=0.5)
    for sx in (1, -1):
        B.piece(tube([(sx * 0.15, 0.2, pz + 0.3), (sx * 0.17, 0.02, 0.98), (sx * 0.12, -0.08, 0.86)], [0.014] * 3, seg_n=5), paint='lama', bone='chest', oline=0.6)
    pa, pb = Vector((0.02, 0.27, pz + 0.2)), Vector((-0.3, 0.36, pz + 0.95))
    B.piece(limb(pa, pb, 0.022, 0.018, seg_n=6, rings=2), paint={'base': 'miriti_som', 'cru': True}, bone='pote', oline=0.9)
    rng = random.Random(9)
    for k in range(7):   # tufo de estopa na ponta do pincel, sujo de breu na ponta
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.2, 1.0))).normalized()
        B.piece(limb(pb - Vector((0, 0, 0.03)), pb + d * rng.uniform(0.1, 0.15), 0.04, 0.008, seg_n=5, rings=2),
                paint={'base': 'miriti', 'pat': 'faixas', 'c1': 'tinta', 'axis': tuple(d), 'bands': [((pb + d * 0.08).dot(d), 9.0)], 'wear': 0.0}, bone='pote', oline=0.8, jitter=0.004)
    # chumaço de estopa pendurado no ombro esquerdo (mola)
    a, b = J(bones, 'estopa')
    for k in range(6):
        off = Vector((rng.uniform(-0.05, 0.05), rng.uniform(-0.06, 0.06), 0))
        B.piece(limb(a + off * 0.4 + Vector((0, 0, 0.02)), b + off + Vector((0, 0, rng.uniform(-0.06, 0.06))), 0.04, 0.012, seg_n=5, rings=3, bulge=0.012),
                paint={'base': 'miriti', 'pat': 'listras', 'c1': 'miriti_som', 's': 0.03, 'w': 0.4, 'axis': (0, 0, 1), 'wear': 0.0}, bone='estopa', oline=0.8, jitter=0.006)
    B.S['_body'] = (0.2, 0.05, 1.3)
    cabeca_ossos(B)
    return B

HEROES = {'marola': build_marola, 'piaba': build_piaba, 'remanso': build_remanso, 'breu': build_breu}

# ================================================================== Inchados
def eye_big(B, center, nrm, size, bone):
    eye_quad(B, Vector(center), Vector(nrm).normalized(), size, size, bone, lid='inchado')

def build_bucho():
    """Bucho: bexiga de peixe de duas câmaras (amendoim em pé), amarrada no alto como balão, olho único e pezinhos."""
    bones = [('root', (0, 0, 0), (0, 0, 0.1), None), ('body', (0, 0, 0.12), (0, 0, 0.62), 'root'),
             ('no', (0, 0.02, 0.86), (0, 0.06, 1.02), 'body'),
             ('fin.L', (0.27, 0.0, 0.36), (0.42, 0.06, 0.42), 'body'), ('fin.R', (-0.27, 0.0, 0.36), (-0.42, 0.06, 0.42), 'body'),
             ('leg.L', (0.1, 0.0, 0.14), (0.1, 0.0, 0.02), 'root'), ('leg.R', (-0.1, 0.0, 0.14), (-0.1, 0.0, 0.02), 'root')]
    B = Builder(51, [b[0] for b in bones], outline=0.005)
    B.bones = bones
    pele = {'base': 'inchado_esc', 'descasca': 0.3, 'sob': 'tabua_rosa', 'pat': 'listras', 'c1': 'tinta', 's': 0.12, 'w': 0.14, 'axis': (0.0, 0.25, 1.0), 'wear': 0.9}
    rings = [(0.0, 0.08, 0.08, 0, 2.0), (0.05, 0.2, 0.19, 0, 2.1), (0.15, 0.29, 0.27, 0, 2.2), (0.26, 0.3, 0.28, 0.0, 2.2), (0.36, 0.24, 0.23, 0.0, 2.1),
             (0.42, 0.21, 0.2, 0.0, 2.0), (0.5, 0.24, 0.23, 0.0, 2.1), (0.6, 0.23, 0.22, 0.0, 2.1), (0.68, 0.15, 0.15, 0.0, 2.0), (0.73, 0.05, 0.05, 0.0, 2.0)]
    B.piece(place(loft(rings, seg_n=9, phase=0.17), (0, 0, 0.1)), paint=pele, bone='body', jitter=0.008)
    # olho único no gomo de cima, boca de bexiga no de baixo
    p, n = front_pt(rings, 0.0, 0.57, 0.1)
    n = (n + Vector((0, 0, 0.55))).normalized()
    eye_big(B, p + Vector((0, -0.012, 0.0)), n, 0.27, 'body')
    pm, nm = front_pt(rings, 0.0, 0.26, 0.1)
    mouth = bmesh.new()
    bmesh.ops.create_circle(mouth, cap_ends=True, segments=8, radius=0.05)
    xform(mouth, Matrix.Translation(pm + nm * 0.004) @ Vector((0, 0, 1)).rotation_difference(nm).to_matrix().to_4x4() @ Matrix.Diagonal((1.0, 0.55, 1, 1)))
    B.piece(mouth, paint='tinta', bone='body', hull=False)
    # nó de balão no alto, com a ponta do barbante
    B.piece(place(mk('ico', sub=1), (0, 0.0, 0.84), (0.05, 0.05, 0.04)), paint={'base': 'inchado_esc', 'wear': 0.8}, bone='body', jitter=0.004)
    B.piece(tube([(0, 0.02, 0.86), (0.02, 0.05, 0.94), (-0.01, 0.07, 1.02)], [0.012, 0.01, 0.008], seg_n=5), paint='miriti_som', bone='no', oline=0.6)
    for s, sx in (('L', 1), ('R', -1)):
        a, b = J(bones, 'fin.' + s)
        fin = bmesh.new()
        vs = [fin.verts.new(a + Vector((0, -0.05, -0.04))), fin.verts.new(b + Vector((0, 0.0, 0.06))), fin.verts.new(b + Vector((0, 0.07, -0.04))), fin.verts.new(a + Vector((0, 0.05, -0.06)))]
        fin.faces.new(vs)
        bmesh.ops.solidify(fin, geom=fin.faces[:], thickness=0.018)
        B.piece(fin, paint={'base': 'tabua_rosa', 'pat': 'listras', 'c1': 'tinta', 's': 0.035, 'w': 0.4, 'axis': (sx, 1, 0), 'wear': 0.8}, bone='fin.' + s)
        lg = limb((sx * 0.1, 0.0, 0.16), (sx * 0.11, -0.02, 0.03), 0.03, 0.026, seg_n=6, rings=2)
        B.piece(lg, paint='tinta', bone='leg.' + s)
        B.piece(place(mk('cube', bevel=0.3, bseg=1), (sx * 0.11, -0.05, 0.025), (0.045, 0.07, 0.025)), paint='tinta', bone='leg.' + s, jitter=0.002)
    return B

def build_gaiola():
    bones = [('root', (0, 0, 0), (0, 0, 0.1), None), ('body', (0, 0, 0.25), (0, 0, 0.7), 'root'), ('porta', (0.0, -0.25, 0.28), (0.0, -0.25, 0.6), 'body'),
             ('olho', (0, 0, 0.3), (0, -0.05, 0.5), 'body')]
    for s, sx in (('L', 1), ('R', -1)):
        bones.append(('garra.' + s, (sx * 0.25, -0.15, 0.32), (sx * 0.42, -0.42, 0.3), 'body'))
        for k in range(3):
            bones.append(('perna%d.%s' % (k, s), (sx * 0.22, 0.1 - k * 0.12, 0.27), (sx * 0.45, 0.14 - k * 0.15, 0.0), 'body'))
    B = Builder(61, [b[0] for b in bones], outline=0.005)
    B.bones = bones
    base = {'base': 'inchado_esc', 'descasca': 0.35, 'sob': 'ferrugem', 'wear': 0.9}
    barra = {'base': 'tinta', 'descasca': 0.3, 'sob': 'ferrugem', 'wear': 0.6}
    B.piece(place(loft([(0, 0.27, 0.25, 0, 2.0), (0.06, 0.28, 0.26, 0, 2.0)], seg_n=10), (0, 0, 0.22)), paint=base, bone='body', jitter=0.004)
    N = 9
    for i in range(N):
        t = 2 * math.pi * (i + 0.5) / N
        if abs(math.sin(t) + 1) < 0.12:
            continue
        pts = []
        for k in range(5):
            u = k / 4 * math.pi / 2
            pts.append(Vector((0.25 * math.cos(t) * math.cos(u), 0.23 * math.sin(t) * math.cos(u), 0.28 + 0.36 * math.sin(u))))
        B.piece(tube(pts, [0.016] * 5, seg_n=5), paint=barra, bone='body', oline=0.8)
    B.piece(place(loft([(0, 0.05, 0.05, 0, 2.0), (0.04, 0.03, 0.03, 0, 2.0)], seg_n=6), (0, 0, 0.63)), paint=base, bone='body')
    B.piece(tube([(0, 0, 0.66), (0.0, 0, 0.76), (0.0, 0.04, 0.8), (0, 0.08, 0.76)], [0.012] * 4, seg_n=5), paint=barra, bone='body', oline=0.7)
    # anel do meio
    ring = [Vector((0.235 * math.cos(2 * math.pi * k / 12), 0.215 * math.sin(2 * math.pi * k / 12), 0.46)) for k in range(13)]
    B.piece(tube(ring, [0.014] * 13, seg_n=5, cap=False), paint=barra, bone='body', oline=0.7)
    # porta da frente (abre na telegrafia)
    for x in (-0.07, 0.0, 0.07):
        B.piece(limb((x, -0.255, 0.29), (x, -0.235, 0.56), 0.014, 0.014, seg_n=5, rings=2), paint={'base': 'inchado', 'descasca': 0.5, 'sob': 'inchado_esc', 'wear': 0.8}, bone='porta', oline=1.0)
    B.piece(place(mk('cube'), (0, -0.25, 0.42), (0.09, 0.012, 0.012)), paint={'base': 'inchado_esc', 'wear': 0.8}, bone='porta')
    # olho no talo dentro da gaiola
    B.piece(limb((0, 0.02, 0.28), (0, -0.04, 0.45), 0.02, 0.016, seg_n=5, rings=2), paint='inchado_esc', bone='olho', oline=0.7)
    B.piece(place(mk('ico', sub=1), (0, -0.05, 0.48), (0.07, 0.06, 0.07)), paint={'base': 'inchado', 'wear': 0.5}, bone='olho', jitter=0.003)
    eye_big(B, (0, -0.11, 0.5), (0, -1, 0.6), 0.13, 'olho')
    # isca rosa pendurada dentro da gaiola: a mancha de cor que faz a Gaiola ler de longe
    B.piece(tube([(0, 0.0, 0.64), (0.02, 0.04, 0.5), (0.03, 0.06, 0.42)], [0.006] * 3, seg_n=4), paint='miriti_som', bone='body', oline=0.4)
    isca = loft([(0.0, 0.02, 0.02, 0, 2.0), (0.05, 0.07, 0.06, 0, 2.2), (0.12, 0.075, 0.065, 0, 2.2), (0.18, 0.03, 0.03, 0, 2.0), (0.22, 0.06, 0.012, 0, 2.0)], seg_n=8)
    B.piece(xform(isca, Matrix.Translation((0.06, 0.08, 0.36)) @ Matrix.Rotation(math.radians(70), 4, 'Y')), paint={'base': 'olho', 'pat': 'escamas', 'c1': 'tabua_rosa', 's': 0.03, 'R': 0.05, 'lw': 0.12, 'wear': 0.3}, bone='body', jitter=0.003)
    for s, sx in (('L', 1), ('R', -1)):
        a, b = J(bones, 'garra.' + s)
        B.piece(limb(a, a + (b - a) * 0.5, 0.03, 0.035, seg_n=6, rings=2), paint=base, bone='garra.' + s)
        c = a + (b - a) * 0.5
        B.piece(limb(c, b + Vector((sx * 0.03, 0, 0.04)), 0.06, 0.02, seg_n=6, rings=3), paint={'base': 'ferrugem', 'descasca': 0.4, 'sob': 'miriti_som', 'wear': 1.0}, bone='garra.' + s, jitter=0.004)
        B.piece(limb(c, b + Vector((-sx * 0.04, 0, -0.05)), 0.04, 0.015, seg_n=6, rings=3), paint={'base': 'ferrugem', 'descasca': 0.4, 'sob': 'miriti_som', 'wear': 1.0}, bone='garra.' + s, jitter=0.004)
        for k in range(3):
            a, b = J(bones, 'perna%d.%s' % (k, s))
            kn = a + (b - a) * 0.5 + Vector((0, 0, 0.12))
            B.piece(limb(a, kn, 0.036, 0.03, seg_n=6, rings=2), paint={'base': 'tinta', 'descasca': 0.3, 'sob': 'ferrugem', 'wear': 0.6}, bone='perna%d.%s' % (k, s), oline=1.6)
            B.piece(limb(kn, b, 0.03, 0.014, seg_n=6, rings=2), paint={'base': 'tinta', 'descasca': 0.3, 'sob': 'ferrugem', 'wear': 0.6}, bone='perna%d.%s' % (k, s), oline=1.6)
    return B

def build_lata():
    bones = [('root', (0, 0, 0), (0, 0, 0.1), None), ('body', (0, 0, 0.05), (0, 0, 0.7), 'root')]
    B = Builder(71, [b[0] for b in bones], outline=0.005)
    B.bones = bones
    can = mk('cube', cuts=2)
    place(can, (0, 0, 0.36), (0.24, 0.19, 0.33))
    rng = random.Random(7)
    for v in can.verts:  # amassados
        if rng.random() < 0.4:
            v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.025
    for v in can.verts:
        v.co.x *= 1.0 - 0.18 * (abs(v.co.y) / 0.19) ** 4 * (abs(v.co.z - 0.36) < 0.3)
    lata = {'base': 'inchado_esc', 'descasca': 0.45, 'sob': 'ferrugem', 'pat': 'faixas', 'c1': 'tabua_azul', 'bands': [(0.25, 0.45)], 'wear': 1.0}
    B.piece(can, paint=lata, bone='body', jitter=0.006)
    B.piece(limb((0.12, 0.05, 0.69), (0.12, 0.05, 0.78), 0.045, 0.04, seg_n=7, rings=2), paint={'base': 'inchado', 'wear': 0.8}, bone='body')
    B.piece(place(mk('cube', bevel=0.3, bseg=1), (0.12, 0.05, 0.8), (0.05, 0.05, 0.02)), paint={'base': 'inchado_esc', 'wear': 0.8}, bone='body')
    B.piece(tube([(-0.16, -0.02, 0.69), (-0.12, -0.02, 0.8), (0.0, -0.02, 0.84), (0.0, 0.02, 0.84)][:3], [0.012] * 3, seg_n=5), paint='inchado_esc', bone='body', oline=0.6)
    eye_big(B, (0.0, -0.2, 0.42), (0, -1, 0.05), 0.15, 'body')
    return B

ENEMIES = {'bucho': build_bucho, 'gaiola': build_gaiola, 'lata': build_lata}

# ================================================================== armas (GLB à parte, presas ao osso 'prop' no motor)
# Construídas ao longo de +Z a partir do punho (origem). No glTF, +Z do Blender vira +Y.
def build_remo():
    bones = [('root', (0, 0, 0), (0, 0, 0.3), None)]
    B = Builder(81, ['root'], outline=0.006)
    B.bones = bones
    cabo = {'base': 'miriti_som', 'cru': True}
    B.piece(limb((0, 0, -0.18), (0, 0, 0.95), 0.024, 0.022, seg_n=7, rings=2), paint={'base': 'lama', 'pat': 'faixas', 'c1': 'miriti', 'bands': [(-0.2, -0.12), (0.12, 0.2), (0.55, 0.6)], 'wear': 0.7}, bone='root', jitter=0.002)
    B.piece(place(mk('cube', bevel=0.3, bseg=1), (0, 0, -0.2), (0.07, 0.025, 0.025)), paint='lama', bone='root')
    # pá facetada com chevrons
    pa = loft([(0.0, 0.03, 0.022, 0, 2.0), (0.08, 0.09, 0.024, 0, 2.6), (0.3, 0.1, 0.024, 0, 3.0), (0.42, 0.085, 0.022, 0, 2.6), (0.47, 0.03, 0.018, 0, 2.0)], seg_n=8)
    marks = [('traco', [(-0.09, 0, 1.08 + k * 0.08), (0.0, 0, 1.13 + k * 0.08), (0.09, 0, 1.08 + k * 0.08)], 0.014, 'miriti') for k in range(4)]
    B.piece(place(pa, (0, 0, 0.92)), paint={'base': 'ferrugem', 'marks': marks, 'wear': 0.8}, bone='root', jitter=0.003)
    # entalhes do fôlego (riscos escuros no cabo)
    return B

def build_malho():
    B = Builder(91, ['root'], outline=0.006)
    B.bones = [('root', (0, 0, 0), (0, 0, 0.3), None)]
    B.piece(limb((0, 0, -0.12), (0, 0, 0.7), 0.026, 0.024, seg_n=7, rings=2), paint={'base': 'miriti_som', 'cru': True, 'marks': [('traco', [(0.0, -0.027, 0.05 + 0.04 * k), (0.0, -0.027, 0.07 + 0.04 * k)], 0.004, 'tinta') for k in range(3)]}, bone='root', jitter=0.002)
    head = loft([(0.0, 0.11, 0.11, 0, 2.0), (0.04, 0.125, 0.125, 0, 2.0), (0.32, 0.125, 0.125, 0, 2.0), (0.36, 0.11, 0.11, 0, 2.0)], seg_n=8, phase=0.2)
    head = place(head, (0, 0, 0), (1, 1, 1), (0, 90, 0))
    place(head, (-0.18, 0, 0.75))
    B.piece(head, paint={'base': 'lama', 'pat': ['faixas', 'bolinhas'], 'pats': [{'c1': 'miriti', 'axis': (1, 0, 0), 'bands': [(-0.15, -0.12), (0.12, 0.15)]}, {'c1': 'tabua_ocre', 's': 0.05, 'r': 0.22}], 'wear': 0.9},
            bone='root', jitter=0.004)
    return B

PROPS = {'remo': build_remo, 'malho': build_malho}

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
    if not armature:
        return None, ob
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

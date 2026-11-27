# Bonecos de "A Pequena Hoste": 4 heróis (0,95 m, 2,2 cabeças), a milícia e 3 mortos da Procissão, só bpy/bmesh.
# Eixos do Blender: frente = -Y, cima = +Z, esquerda do boneco = +X. Cabeça de 0,43 m.
# Regra de cor: herói = aguada plana da paleta; morto = só papel e tinta (aguada 0) com verde-mordente nos olhos.
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler
from malha import *

# ================================================================== esqueleto comum
def S_heroi(**kw):
    S = dict(hip=0.25, waist=0.31, chest=0.40, neck=0.47, headb=0.49, headt=0.92, shz=0.45, shw=0.13, ua=0.105, fa=0.095,
             legx=0.07, knee=0.135, ankle=0.045, arm_r=0.034, leg_r=0.04, hw=0.205, hd=0.19, hand=1.0, extra=[])
    S.update(kw)
    return S

def bones_corpo(S):
    B = []
    hip, wz, cz, nz, hb, ht = S['hip'], S['waist'], S['chest'], S['neck'], S['headb'], S['headt']
    B.append(('root', (0, 0, 0), (0, 0, 0.1), None))
    B.append(('hips', (0, 0, hip), (0, 0, wz), 'root'))
    B.append(('spine', (0, 0, wz), (0, 0, cz), 'hips'))
    B.append(('chest', (0, 0, cz), (0, 0, nz), 'spine'))
    B.append(('neck', (0, 0, nz), (0, 0, hb), 'chest'))
    B.append(('head', (0, 0, hb), (0, 0, ht), 'neck'))
    B.append(('hat', (0, 0, ht - 0.02), (0, 0, ht + 0.1), 'head'))
    for s, sx in (('L', 1), ('R', -1)):
        sh = Vector((sx * S['shw'], 0, S['shz']))
        el = sh + Vector((sx * 0.02, 0.0, -S['ua']))
        wr = el + Vector((0, -0.01, -S['fa']))
        B.append(('shoulder.' + s, (sx * 0.04, 0, S['shz']), tuple(sh), 'chest'))
        B.append(('upperarm.' + s, tuple(sh), tuple(el), 'shoulder.' + s))
        B.append(('forearm.' + s, tuple(el), tuple(wr), 'upperarm.' + s))
        hc = wr + Vector((0, 0, -0.05 * S['hand']))
        B.append(('hand.' + s, tuple(wr), tuple(hc), 'forearm.' + s))
        # adereço: cabeça no centro do punho fechado, cauda para a frente (a arma em repouso aponta para -Y)
        B.append(('prop' + ('' if s == 'R' else 'L'), tuple(hc), tuple(hc + Vector((0, -0.2, 0))), 'hand.' + s))
        lx = sx * S['legx']
        B.append(('thigh.' + s, (lx, 0, hip), (lx, -0.005, S['knee']), 'hips'))
        B.append(('shin.' + s, (lx, -0.005, S['knee']), (lx, 0.0, S['ankle']), 'thigh.' + s))
        B.append(('foot.' + s, (lx, 0.0, S['ankle']), (lx, -0.09, S['ankle'] - 0.02), 'shin.' + s))
    B += S['extra']
    return B

def hc_of(S, side):
    sx = 1 if side == 'L' else -1
    return Vector((sx * (S['shw'] + 0.02), -0.01, S['shz'] - S['ua'] - S['fa'] - 0.05 * S['hand']))

def J(B, n):
    for bn, h, t, p in B.bones:
        if bn == n:
            return Vector(h), Vector(t)
    raise KeyError(n)

def novo(seed, S):
    bones = bones_corpo(S)
    B = Builder(seed, [b[0] for b in bones])
    B.bones = bones
    B.S = S
    return B

# ------------------------------------------------------------------ cabeça e rosto
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

def cabeca(B, wash='papel_dia', aguda=0.0, queixo=1.0):
    """crânio grande: 0,43 m de altura, rosto chato na frente, bochecha cheia. Devolve os anéis (para o rosto)."""
    S = B.S
    hw, hd = S['hw'], S['hd']
    H = S['headt'] - S['headb']
    rings = [(0.0, 0.07, 0.07, -0.01, 2.0), (0.04, hw * 0.72 * queixo, hd * 0.75, -0.012, 2.2), (0.12, hw * 0.95, hd * 0.95, 0.0, 2.4),
             (0.22, hw, hd, 0.005, 2.5), (0.31, hw * 0.96, hd * 0.97, 0.01, 2.4), (0.38, hw * 0.78, hd * 0.8, 0.012, 2.2),
             (H - 0.01, hw * 0.4 * (1 - aguda), hd * 0.42, 0.012, 2.0), (H, 0.02, 0.02, 0.012, 2.0)]
    B.piece(place(loft(rings, seg_n=18), (0, 0, S['headb'])), wash=wash, bone='head', axis=(0, 0, 1))
    B.piece(limb((0, 0, S['neck'] - 0.01), (0, 0, S['headb'] + 0.03), 0.045, 0.05, seg_n=8, rings=2), wash=wash, bone='neck')
    return rings

def olho(B, rings, x, z, w=0.034, h=0.046, palp=0.0, palp_ang=0.0, pup=1.0, cor='tinta', brilho=True, bone='head', mat='plano'):
    """olho de gravura: amêndoa de tinta com o brilho em papel reservado; pálpebra de pele por cima (palp 0..1)."""
    S = B.S
    p, n = front_pt(rings, x, z, S['headb'])
    xa = Vector((0, 0, 1)).cross(n).normalized(); ya = n.cross(xa).normalized()
    M = Matrix((xa, ya, n)).transposed().to_4x4()
    e = place(mk('sphere', u=12, v=8), (0, 0, 0), (w * pup, h * pup, 0.012))
    B.piece(xform(e, Matrix.Translation(p + n * 0.004) @ M), wash=cor, mat=mat, bone=bone, hull=False)
    if brilho:
        hl = place(mk('sphere', u=8, v=6), (0, 0, 0), (w * 0.3, w * 0.3, 0.006))
        B.piece(xform(hl, Matrix.Translation(p + n * 0.014 + ya * h * 0.3 * pup + xa * w * 0.25 * (1 if x < 0 else -1)) @ M),
                wash='papel_dia', mat='plano', bone=bone, hull=False)
    if palp > 0:
        lid = place(mk('sphere', u=12, v=8), (0, 0, 0), (w * 1.25, h * 1.0, 0.018))
        bm = lid
        cut = h * (1.0 - 2.0 * palp)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, cut, 0), plane_no=(0, -1, 0), clear_outer=True)
        R = Matrix.Rotation(math.radians(palp_ang * (1 if x < 0 else -1)), 4, 'Z')
        B.piece(xform(bm, Matrix.Translation(p + n * 0.008) @ M @ R), wash='papel_dia', mat='grav', bone=bone, oline=0.5)

def traco(B, pts, r, bone='head', cor='tinta'):
    B.piece(tube(pts, [r * (0.5 + 0.5 * math.sin(math.pi * (i + 0.5) / len(pts))) for i in range(len(pts))], seg_n=6), wash=cor, mat='plano', bone=bone, hull=False)

def rosto_pt(B, rings, x, z, out=0.006):
    p, n = front_pt(rings, x, z, B.S['headb'])
    return p + n * out

# ------------------------------------------------------------------ corpo, braços, mãos, pernas
def mao(B, side, fist=True, wash='papel_dia', s=1.0):
    S = B.S
    wr, hc = J(B, 'hand.' + side)
    sx = 1 if side == 'L' else -1
    k = 1.4 * s * S['hand']
    if fist:
        B.piece(place(mk('sphere', u=10, v=7), hc + Vector((0, -0.005, 0.005)), (0.034 * k, 0.03 * k, 0.034 * k)), wash=wash, bone='hand.' + side)
        B.piece(limb(hc + Vector((sx * 0.024 * k, -0.01, 0.012)), hc + Vector((sx * 0.012 * k, -0.034 * k, 0.0)), 0.013 * k, 0.011 * k, seg_n=8, rings=3),
                wash=wash, bone='hand.' + side, oline=0.7)
    else:
        B.piece(place(mk('sphere', u=10, v=7), hc + Vector((0, 0, 0.004)), (0.034 * k, 0.018 * k, 0.034 * k)), wash=wash, bone='hand.' + side)
        for fx in (-0.018, 0.0, 0.018):
            B.piece(limb(hc + Vector((fx * k, 0, -0.02 * k)), hc + Vector((fx * k * 1.3, -0.004, -0.06 * k)), 0.01 * k, 0.009 * k, seg_n=7, rings=3),
                    wash=wash, bone='hand.' + side, oline=0.6)
        B.piece(limb(hc + Vector((sx * 0.025 * k, -0.005, 0.0)), hc + Vector((sx * 0.05 * k, -0.02 * k, -0.025 * k)), 0.011 * k, 0.009 * k, seg_n=7, rings=3),
                wash=wash, bone='hand.' + side, oline=0.6)

def braco(B, side, manga, pele='papel_dia', fist=True, manga_r=1.25, punho=None):
    S = B.S
    sh, el = J(B, 'upperarm.' + side)
    _, wr = J(B, 'forearm.' + side)
    r = S['arm_r']
    B.piece(limb(sh + Vector((0, 0, 0.015)), el, r * 1.35 * manga_r, r * 1.05 * manga_r, seg_n=10, bulge=r * 0.15), wash=manga, bone='upperarm.' + side)
    B.piece(limb(el, wr, r * 1.05 * manga_r, r * 0.95 * manga_r, seg_n=10, bulge=r * 0.1), wash=manga, bone='forearm.' + side)
    if punho:
        B.piece(limb(wr + (el - wr) * 0.35, wr - (el - wr) * 0.12, r * 1.5, r * 1.6, seg_n=10, rings=3), wash=punho, bone='forearm.' + side)
    mao(B, side, fist=fist, wash=pele)

def perna(B, side, calca, bota='sombra', bota_k=1.0, cano=0.6):
    S = B.S
    th, kn = J(B, 'thigh.' + side)
    _, an = J(B, 'shin.' + side)
    r = S['leg_r']
    B.piece(limb(th + Vector((0, 0, 0.02)), kn, r * 1.3, r * 1.0, seg_n=10, bulge=r * 0.1), wash=calca, bone='thigh.' + side)
    B.piece(limb(kn, an, r * 1.0, r * 0.85, seg_n=10), wash=calca, bone='shin.' + side)
    # bota grande: cano + pé arredondado, 1,4x
    k = bota_k
    B.piece(limb(an + Vector((0, 0, -0.03)), an + (kn - an) * cano, r * 1.25 * k, r * 1.35 * k, seg_n=10, rings=3), wash=bota, bone='shin.' + side)
    pe = loft([(0.0, 0.046 * k, 0.075 * k, -0.025 * k, 2.4), (0.035 * k, 0.05 * k, 0.08 * k, -0.03 * k, 2.6), (0.06 * k, 0.04 * k, 0.05 * k, -0.005, 2.2)], seg_n=12)
    B.piece(place(pe, (an.x, an.y, 0.0)), wash=bota, bone='foot.' + side)

def tronco(B, rings, wash, bone='chest', z0=None, **kw):
    z0 = B.S['waist'] - 0.03 if z0 is None else z0
    B.piece(place(loft(rings, seg_n=16), (0, 0, z0)), wash=wash, bone=bone, **kw)

def W_saia(bones_w):
    def f(co):
        return bones_w(co)
    return f

# ================================================================== PORTA-ESTANDARTE (paladino, vermelhão)
def build_porta():
    S = S_heroi(hw=0.2, hd=0.185, shw=0.15, arm_r=0.038, leg_r=0.045, legx=0.075)
    ht = S['headt']
    S['extra'] = [('asa', (-0.19, 0.0, 0.8), (-0.33, 0.06, 1.02), 'head'),
                  ('asa2', (-0.33, 0.06, 1.02), (-0.43, 0.13, 1.08), 'asa'),
                  ('tabardo.F', (0, -0.15, 0.3), (0, -0.16, 0.12), 'hips'), ('tabardo.B', (0, 0.15, 0.3), (0, 0.16, 0.12), 'hips'),
                  ('costas', (0, 0.17, 0.34), (0, 0.17, 0.5), 'chest')]
    B = novo(11, S)
    # tronco de barril, com tabardo vermelho por cima da cota (rio = aço)
    tronco(B, [(0.0, 0.15, 0.13, 0, 2.2), (0.08, 0.17, 0.145, 0, 2.4), (0.15, 0.175, 0.15, 0, 2.5), (0.2, 0.15, 0.13, 0, 2.3), (0.21, 0.07, 0.06, 0, 2.0)], 'sombra')
    # tabardo: duas abas com mola (frente e costas) e a parte de cima vestida no peito
    tab = loft([(0.0, 0.155, 0.135, 0, 2.6), (0.09, 0.172, 0.15, 0, 2.6), (0.15, 0.178, 0.152, 0, 2.6)], seg_n=16, cap_bot=False, cap_top=False)
    B.piece(place(tab, (0, 0, S['waist'] - 0.02)), wash='vermelhao', bone='chest')
    for s, sy in (('F', -1), ('B', 1)):
        aba = slab([(-0.12, 0.0), (0.12, 0.0), (0.13, -0.16), (0.0, -0.2), (-0.13, -0.16)], 0.018)
        B.piece(place(aba, (0, sy * 0.15, S['waist'] - 0.01), rot=(sy * -8, 0, 0)), wash='vermelhao', bone='tabardo.' + s)
    # brasão do jogador 1 (torre): papel reservado no peito
    tor = slab([(-0.045, 0), (0.045, 0), (0.045, 0.07), (0.028, 0.07), (0.028, 0.085), (0.01, 0.085), (0.01, 0.07), (-0.01, 0.07), (-0.01, 0.085), (-0.028, 0.085), (-0.028, 0.07), (-0.045, 0.07)], 0.01)
    B.piece(place(tor, (0, -0.158, S['waist'] + 0.035), rot=(6, 0, 0)), wash='papel_dia', bone='chest', oline=0.5)
    # cinto
    B.piece(place(loft([(0.0, 0.162, 0.142, 0, 2.5), (0.025, 0.162, 0.142, 0, 2.5)], seg_n=16), (0, 0, S['waist'] - 0.01)), wash='sombra', bone='hips')
    B.piece(place(mk('cube', bevel=0.004), (0, -0.147, S['waist'] + 0.002), (0.022, 0.01, 0.018)), wash='trigo', bone='hips', oline=0.6)
    # ombreiras redondas de aço
    for s, sx in (('L', 1), ('R', -1)):
        B.piece(place(mk('sphere', u=12, v=8), (sx * 0.155, 0, S['shz'] - 0.005), (0.07, 0.07, 0.05)), wash='rio', bone='shoulder.' + s)
    # cabeça (por baixo do elmo) e elmo de balde de topo chato
    rings = cabeca(B, wash='papel_dia')
    hb = S['headb']
    elmo = loft([(0.0, 0.2, 0.19, 0.0, 2.6), (0.04, 0.215, 0.2, 0.0, 2.8), (0.3, 0.212, 0.198, 0.0, 2.9), (0.4, 0.205, 0.192, 0.0, 2.9), (0.41, 0.16, 0.15, 0.0, 2.8)], seg_n=20)
    B.piece(place(elmo, (0, 0.0, hb + 0.02)), wash='papel_dia', bone='head', axis=(0, 0, 1))
    # tampa chata e aros rebitados
    for z in (hb + 0.03, hb + 0.4):
        B.piece(place(loft([(0.0, 0.219, 0.205, 0, 2.9), (0.022, 0.219, 0.205, 0, 2.9)], seg_n=20), (0, 0, z)), wash='trigo', bone='head', oline=0.7)
    # cruz de reforço na frente
    B.piece(place(mk('cube', bevel=0.004), (0, -0.207, hb + 0.17), (0.018, 0.012, 0.15)), wash='trigo', bone='head', oline=0.7)
    # viseira: fenda horizontal de tinta, com os dois olhos de papel lá dentro (determinados)
    fen = place(mk('cube', bevel=0.006), (0, -0.204, hb + 0.27), (0.17, 0.012, 0.024))
    B.piece(fen, wash='tinta', mat='plano', bone='head', hull=False)
    for sx in (-1, 1):
        B.piece(place(mk('sphere', u=8, v=6), (sx * 0.07, -0.214, hb + 0.27), (0.022, 0.006, 0.015)), wash='papel_dia', mat='plano', bone='head', hull=False)
        B.piece(place(mk('sphere', u=8, v=6), (sx * 0.075, -0.218, hb + 0.268), (0.009, 0.004, 0.011)), wash='tinta', mat='plano', bone='head', hull=False)
    # furos de respiro
    for k in range(4):
        for sx in (-1, 1):
            B.piece(place(mk('sphere', u=6, v=4), (sx * (0.06 + 0.025 * k), -0.2 + 0.01 * k, hb + 0.14), (0.007, 0.004, 0.007)), wash='tinta', mat='plano', bone='head', hull=False)
    # asa de metal de um lado só (direito do boneco = -X), 3 penas em placa, com mola
    a0, a1 = J(B, 'asa'); _, a2 = J(B, 'asa2')
    for k, (L, ang, wv) in enumerate(((0.24, 62, 0.075), (0.2, 44, 0.065), (0.15, 26, 0.055))):
        pena = slab([(0, 0), (wv * 0.5, L * 0.35), (wv * 0.4, L * 0.8), (0.0, L), (-wv * 0.45, L * 0.55)], 0.016)
        bm = place(pena, (0, 0, 0), rot=(0, ang - 90, 0))
        bm = place(bm, (-0.205, 0.04, hb + 0.25 + k * 0.035), rot=(0, 0, -15))
        B.piece(bm, wash='papel_dia', bone='asa' if k > 0 else 'asa2', weights=None)
    # braços com manga de cota e manoplas
    braco(B, 'L', 'sombra', pele='rio', fist=True, manga_r=1.15, punho='tinta')
    braco(B, 'R', 'sombra', pele='rio', fist=True, manga_r=1.15, punho='tinta')
    perna(B, 'L', 'sombra', bota='sombra', bota_k=1.15)
    perna(B, 'R', 'sombra', bota='sombra', bota_k=1.15)
    # escudo de torre no braço esquerdo (tábua com faixa vermelha e aro de ferro)
    _, el = J(B, 'upperarm.L')
    sc = slab([(-0.15, -0.26), (0.15, -0.26), (0.16, 0.2), (0.0, 0.25), (-0.16, 0.2)], 0.03)
    for v in sc.verts:
        v.co.y += 1.4 * v.co.x * v.co.x
    M = Matrix.Translation(el + Vector((0.07, -0.075, -0.02))) @ Matrix.Rotation(math.radians(25), 4, 'Z')
    B.piece(xform(sc, M), wash='sombra', bone='forearm.L', axis=None)
    fx = slab([(-0.045, -0.25), (0.045, -0.25), (0.045, 0.23), (-0.045, 0.23)], 0.036)
    for v in fx.verts:
        v.co.y += 1.4 * v.co.x * v.co.x
    B.piece(xform(fx, M @ Matrix.Translation((0, -0.004, 0))), wash='vermelhao', bone='forearm.L', oline=0.6)
    tor2 = slab([(-0.05, 0), (0.05, 0), (0.05, 0.08), (0.03, 0.08), (0.03, 0.1), (0.01, 0.1), (0.01, 0.08), (-0.01, 0.08), (-0.01, 0.1), (-0.03, 0.1), (-0.03, 0.08), (-0.05, 0.08)], 0.04)
    B.piece(xform(tor2, M @ Matrix.Translation((0, -0.01, -0.02))), wash='papel_dia', bone='forearm.L', oline=0.5)
    # maça na mão direita (cabo de madeira, cabeça de ferro com flanges)
    hc, tip = J(B, 'prop')
    d = (tip - hc).normalized()
    B.piece(limb(hc - d * 0.06, hc + d * 0.3, 0.014, 0.016, seg_n=8, rings=2), wash='sombra', bone='prop')
    hd_ = hc + d * 0.33
    B.piece(place(mk('sphere', u=10, v=8), hd_, (0.048, 0.055, 0.048)), wash='rio', bone='prop')
    for k in range(6):
        a = k * math.pi / 3
        fl = slab([(0, -0.045), (0.05, -0.02), (0.05, 0.02), (0, 0.045)], 0.012)
        B.piece(xform(fl, Matrix.Translation(hd_) @ Matrix.Rotation(a, 4, 'Y') @ Matrix.Rotation(-math.pi / 2, 4, 'X')),
                wash='rio', bone='prop', oline=0.7)
    B.S['_body'] = (0.2, 0.0, 1.05)
    return B

# ================================================================== SINEIRA (clériga, ouro-gema)
def build_sineira():
    S = S_heroi(hw=0.205, hd=0.19, shw=0.12, arm_r=0.032, leg_r=0.036, legx=0.06)
    S['extra'] = [('saia.F', (0, -0.1, 0.3), (0, -0.2, 0.05), 'hips'), ('saia.B', (0, 0.1, 0.3), (0, 0.2, 0.05), 'hips'),
                  ('saia.L', (0.1, 0, 0.3), (0.2, 0, 0.05), 'hips'), ('saia.R', (-0.1, 0, 0.3), (-0.2, 0, 0.05), 'hips'),
                  ('veu', (0, 0.17, 0.82), (0, 0.24, 0.52), 'head'), ('coroa', (0, 0, 0.9), (0, 0, 1.0), 'head'),
                  ('pote', (0.16, -0.06, 0.3), (0.16, -0.06, 0.2), 'hips')]
    B = novo(22, S)
    hb, ht = S['headb'], S['headt']
    # saia em forma de sino (ouro), cada quarto preso ao seu osso de mola
    def wsaia(co):
        ang = math.atan2(co.x, -co.y)
        h = max(0.0, min(1.0, (S['waist'] - co.z) / 0.25))
        out = {'hips': 1.0 - h}
        ws = {'F': max(0, math.cos(ang)), 'L': max(0, math.sin(ang)), 'B': max(0, -math.cos(ang)), 'R': max(0, -math.sin(ang))}
        tot = sum(ws.values()) + 1e-6
        for k, v in ws.items():
            out['saia.' + k] = h * v / tot
        return out
    saia = loft([(0.0, 0.25, 0.24, 0.01, 2.0), (0.04, 0.245, 0.235, 0.01, 2.0), (0.12, 0.205, 0.195, 0.005, 2.0), (0.22, 0.15, 0.14, 0.0, 2.0), (0.31, 0.12, 0.11, 0, 2.0)], seg_n=20, cap_bot=False)
    B.piece(place(saia, (0, 0, 0.03)), wash='ouro', weights=wsaia, axis=(0, 0, 1))
    # boca do sino: barra mais escura por dentro (sombra) e friso de cera
    B.piece(place(loft([(0.0, 0.254, 0.244, 0.01, 2.0), (0.022, 0.25, 0.24, 0.01, 2.0)], seg_n=20, cap_bot=False, cap_top=False), (0, 0, 0.06)), wash='cera', weights=wsaia, oline=0.6)
    tronco(B, [(0.0, 0.12, 0.11, 0, 2.0), (0.1, 0.13, 0.115, 0, 2.2), (0.16, 0.115, 0.1, 0, 2.2), (0.19, 0.06, 0.05, 0, 2.0)], 'ouro')
    # escapulário de cera com o sino do jogador 2 (símbolo)
    esc = slab([(-0.06, 0.0), (0.06, 0.0), (0.06, 0.15), (-0.06, 0.15)], 0.012)
    B.piece(place(esc, (0, -0.118, S['waist'] - 0.04), rot=(5, 0, 0)), wash='cera', bone='chest', oline=0.6)
    sinosym = slab([(-0.03, 0), (0.03, 0), (0.022, 0.02), (0.018, 0.05), (0.0, 0.06), (-0.018, 0.05), (-0.022, 0.02)], 0.014)
    B.piece(place(sinosym, (0, -0.126, S['waist'] + 0.02), rot=(5, 0, 0)), wash='ouro', bone='chest', oline=0.5)
    rings = cabeca(B, wash='papel_dia')
    # rosto resmungão: sobrancelhas baixas e juntas, pálpebra caída, boca de lado para baixo, bochecha redonda
    for sx in (-1, 1):
        olho(B, rings, sx * 0.075, 0.18, w=0.032, h=0.042, palp=0.38, palp_ang=14)
        p0 = rosto_pt(B, rings, sx * 0.03, 0.235); p1 = rosto_pt(B, rings, sx * 0.075, 0.228); p2 = rosto_pt(B, rings, sx * 0.115, 0.245)
        traco(B, [p0, p1, p2], 0.011)
    B.piece(place(mk('sphere', u=10, v=7), rosto_pt(B, rings, 0, 0.135, 0.0), (0.022, 0.02, 0.02)), wash='papel_dia', bone='head', oline=0.6)
    traco(B, [rosto_pt(B, rings, -0.045, 0.075), rosto_pt(B, rings, -0.01, 0.085), rosto_pt(B, rings, 0.03, 0.082), rosto_pt(B, rings, 0.05, 0.068)], 0.008)
    # véu curto (cera), atrás da coroa até os ombros, com mola
    # meia-casca só atrás (de orelha a orelha), caindo até os ombros
    bm = bmesh.new()
    rows = []
    for i in range(7):
        t = i / 6
        z = ht - 0.1 - t * 0.3
        r = 0.2 + 0.05 * t
        rr = []
        for j in range(11):
            a = math.pi * (j / 10)
            rr.append(bm.verts.new((r * math.cos(a), 0.03 + r * 0.95 * math.sin(a) + 0.02 * t, z + 0.015 * math.sin(j * 1.7) * t)))
        rows.append(rr)
    for i in range(6):
        for j in range(10):
            bm.faces.new([rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.012)
    veu = bm
    B.piece(veu, wash='cera', weights=lambda co: {'veu': min(1, max(0, (ht - 0.06 - co.z) / 0.2)), 'head': 1 - min(1, max(0, (ht - 0.06 - co.z) / 0.2))})
    # coroa de bronze com 5 velas que derretem (alturas diferentes), pingos e chamas
    zc = ht - 0.075
    B.piece(place(loft([(0.0, 0.17, 0.16, 0.01, 2.0), (0.05, 0.185, 0.175, 0.01, 2.0)], seg_n=18, cap_bot=False, cap_top=False), (0, 0, zc)), wash='ocre', bone='coroa')
    rng = random.Random(5)
    for k, (ang, hgt) in enumerate(((-62, 0.17), (-30, 0.23), (0, 0.27), (32, 0.2), (64, 0.15), (180, 0.2), (130, 0.13), (-130, 0.16))):
        a = math.radians(ang)
        x, y = 0.178 * math.sin(a), -0.168 * math.cos(a) + 0.01
        B.piece(limb((x, y, zc + 0.02), (x, y, zc + 0.02 + hgt), 0.027, 0.024, seg_n=10, rings=3), wash='cera', bone='coroa')
        for j in range(2):   # pingos de cera
            zz = zc + 0.03 + rng.uniform(0.2, 0.8) * hgt
            B.piece(place(mk('sphere', u=6, v=5), (x + 0.02 * math.sin(a + 1.2 * j), y - 0.02 * math.cos(a + 1.2 * j), zz), (0.011, 0.011, 0.022)), wash='cera', bone='coroa', oline=0.5)
        B.piece(limb((x, y, zc + 0.02 + hgt), (x, y, zc + 0.035 + hgt), 0.003, 0.003, seg_n=4, rings=2), wash='tinta', mat='plano', bone='coroa', hull=False)
        fl = loft([(0.0, 0.016, 0.016, 0, 2.0), (0.03, 0.024, 0.024, 0, 2.0), (0.085, 0.002, 0.002, 0, 2.0)], seg_n=8)
        B.piece(place(fl, (x, y, zc + 0.03 + hgt)), wash='fogo', mat='chama', bone='coroa', hull=False)
    braco(B, 'L', 'ouro', fist=False, manga_r=1.25)
    braco(B, 'R', 'ouro', fist=True, manga_r=1.25)
    perna(B, 'L', 'sombra', bota='sombra', bota_k=0.95)
    perna(B, 'R', 'sombra', bota='sombra', bota_k=0.95)
    # pote de cera na cintura
    a, b = J(B, 'pote')
    B.piece(place(loft([(0.0, 0.035, 0.035, 0, 2.0), (0.05, 0.045, 0.045, 0, 2.0), (0.08, 0.03, 0.03, 0, 2.0)], seg_n=10), (a.x + 0.06, a.y, b.z - 0.02)), wash='cera', bone='pote')
    B.S['_body'] = (0.25, 0.0, 1.1)
    return B

# ================================================================== SAPADOR (ladino, ultramar)
def build_sapador():
    S = S_heroi(hw=0.195, hd=0.18, shw=0.12, arm_r=0.03, leg_r=0.035, legx=0.065, hip=0.23, waist=0.29, chest=0.37, neck=0.43, headb=0.45, headt=0.88, shz=0.41)
    S['extra'] = [('mochila', (0, 0.16, 0.32), (0, 0.18, 0.62), 'chest'), ('barril.L', (0.1, 0.24, 0.5), (0.1, 0.24, 0.66), 'mochila'),
                  ('barril.R', (-0.1, 0.24, 0.5), (-0.1, 0.24, 0.66), 'mochila'), ('barril.T', (0, 0.22, 0.68), (0, 0.22, 0.84), 'mochila'),
                  ('aba', (0, -0.05, 0.86), (0, -0.22, 0.86), 'hat'),
                  ('lanterna', (-0.2, 0.2, 0.64), (-0.2, 0.2, 0.5), 'mochila'),
                  ('cachecol1', (0, 0.12, 0.45), (0.02, 0.3, 0.42), 'chest'), ('cachecol2', (0.02, 0.3, 0.42), (0.06, 0.5, 0.38), 'cachecol1')]
    B = novo(33, S)
    hb, ht = S['headb'], S['headt']
    tronco(B, [(0.0, 0.12, 0.11, 0, 2.2), (0.09, 0.13, 0.12, 0, 2.4), (0.15, 0.12, 0.11, 0, 2.3), (0.17, 0.06, 0.05, 0, 2.0)], 'anil')
    # casaco curto com barra (ultramar) e cinto de corda
    B.piece(place(loft([(0.0, 0.14, 0.13, 0, 2.3), (0.06, 0.13, 0.12, 0, 2.3)], seg_n=16, cap_bot=False, cap_top=False), (0, 0, S['hip'] - 0.03)), wash='anil', bone='hips')
    B.piece(place(loft([(0.0, 0.133, 0.123, 0, 2.3), (0.018, 0.133, 0.123, 0, 2.3)], seg_n=16), (0, 0, S['waist'] - 0.02)), wash='trigo', bone='hips', oline=0.6)
    # símbolo do jogador 3 (barril) em papel no peito
    B.piece(place(mk('cyl', seg=10), (0.0, -0.115, S['waist'] + 0.05), (0.025, 0.006, 0.03), rot=(90, 0, 0)), wash='papel_dia', bone='chest', oline=0.5)
    rings = cabeca(B, wash='papel_dia')
    # olhos nervosos: grandes, pupila pequena, sobrancelha alta e torta; pano no rosto (ultramar)
    for sx in (-1, 1):
        olho(B, rings, sx * 0.078, 0.2, w=0.04, h=0.05, cor='papel_dia', brilho=False)
        p, n = front_pt(rings, sx * 0.078 + sx * 0.008, 0.195, hb)
        B.piece(place(mk('sphere', u=8, v=6), p + n * 0.016, (0.012, 0.012, 0.012)), wash='tinta', mat='plano', bone='head', hull=False)
        ring_eye = place(loft([(0.0, 0.043, 0.053, 0, 2.0), (0.006, 0.043, 0.053, 0, 2.0)], seg_n=12, cap_bot=False, cap_top=False), (0, 0, 0))
        xa = Vector((0, 0, 1)).cross(n).normalized(); ya = n.cross(xa).normalized()
        p0, _ = front_pt(rings, sx * 0.078, 0.2, hb)
        B.piece(xform(ring_eye, Matrix.Translation(p0 + n * 0.006) @ Matrix((xa, ya, n)).transposed().to_4x4()), wash='tinta', mat='plano', bone='head', hull=False)
        traco(B, [rosto_pt(B, rings, sx * 0.04, 0.27), rosto_pt(B, rings, sx * 0.08, 0.29 + 0.01 * sx), rosto_pt(B, rings, sx * 0.12, 0.275)], 0.009)
    # gota de suor
    p, n = front_pt(rings, 0.15, 0.25, hb)
    B.piece(place(mk('sphere', u=8, v=6), p + n * 0.01, (0.012, 0.012, 0.02)), wash='raio_borda', mat='plano', bone='head', oline=0.5)
    pano = loft([(0.0, S['hw'] * 0.74, S['hd'] * 0.78, -0.014, 2.3), (0.07, S['hw'] * 0.97, S['hd'] * 0.97, -0.005, 2.4), (0.13, S['hw'] * 1.02, S['hd'] * 1.02, 0.0, 2.5)], seg_n=18, cap_bot=False, cap_top=False)
    B.piece(place(pano, (0, 0, hb + 0.035)), wash='anil', bone='head')
    B.piece(limb((0.0, 0.2, hb + 0.13), (0.0, 0.3, hb + 0.04), 0.03, 0.012, seg_n=8, rings=3), wash='anil', bone='head')
    # chapéu de mineiro: copa redonda de couro (sombra: lê escuro contra a água do vau) e aba larga caída, vela acesa na frente
    copa = loft([(0.0, 0.215, 0.2, 0.0, 2.2), (0.08, 0.205, 0.19, 0.0, 2.2), (0.15, 0.16, 0.15, 0.0, 2.0), (0.18, 0.08, 0.075, 0.0, 2.0)], seg_n=18)
    B.piece(place(copa, (0, 0, ht - 0.1)), wash='sombra', bone='hat')
    aba = loft([(0.0, 0.33, 0.33, -0.03, 2.0), (0.02, 0.33, 0.33, -0.03, 2.0)], seg_n=22)
    for v in aba.verts:
        r = math.hypot(v.co.x, v.co.y + 0.03)
        v.co.z -= 0.18 * max(0, r - 0.2) ** 1.3
    B.piece(place(aba, (0, 0, ht - 0.1)), wash='sombra', weights=lambda co: {'aba': 0.5 if co.y < -0.1 else 0.0, 'hat': 0.5 if co.y < -0.1 else 1.0})
    vz = ht - 0.04
    B.piece(place(mk('cube', bevel=0.005), (0, -0.21, vz), (0.03, 0.012, 0.025)), wash='ocre', bone='hat', oline=0.6)
    B.piece(limb((0, -0.225, vz + 0.02), (0, -0.225, vz + 0.1), 0.016, 0.015, seg_n=8, rings=2), wash='cera', bone='hat')
    fl = loft([(0.0, 0.01, 0.01, 0, 2.0), (0.018, 0.014, 0.014, 0, 2.0), (0.045, 0.002, 0.002, 0, 2.0)], seg_n=8)
    B.piece(place(fl, (0, -0.225, vz + 0.105)), wash='fogo', mat='chama', bone='hat', hull=False)
    braco(B, 'L', 'anil', fist=False)
    braco(B, 'R', 'anil', fist=True)
    perna(B, 'L', 'sombra', bota='sombra', bota_k=1.05)
    perna(B, 'R', 'sombra', bota='sombra', bota_k=1.05)
    # mochila de barris (pirâmide de carga maior que ele): estrado, 2 barris em baixo, 1 em cima, cordas
    B.piece(place(mk('cube', bevel=0.006), (0, 0.15, 0.48), (0.18, 0.02, 0.16)), wash='sombra', bone='mochila')
    def barril(c, bone, r=0.085, L=0.19):
        c = Vector(c)
        bm = loft([(0.0, r * 0.85, r * 0.85, 0, 2.0), (L * 0.5, r, r, 0, 2.0), (L, r * 0.85, r * 0.85, 0, 2.0)], seg_n=14)
        B.piece(xform(bm, Matrix.Translation(c + Vector((-L / 2, 0, 0))) @ Matrix.Rotation(math.pi / 2, 4, 'Y')), wash='ocre', bone=bone, axis=(1, 0, 0))
        for t in (0.18, 0.82):
            rr = r * (0.85 + 0.15 * math.sin(math.pi * t)) + 0.004
            B.piece(xform(loft([(0.0, rr, rr, 0, 2.0), (0.016, rr, rr, 0, 2.0)], seg_n=14, cap_bot=False, cap_top=False),
                          Matrix.Translation(c + Vector((-L / 2 + L * t, 0, 0))) @ Matrix.Rotation(math.pi / 2, 4, 'Y')), wash='tinta', mat='plano', bone=bone, hull=False)
    barril((0.1, 0.25, 0.52), 'barril.L')
    barril((-0.1, 0.25, 0.52), 'barril.R')
    barril((0.0, 0.24, 0.69), 'barril.T', r=0.08)
    B.piece(tube([(0.0, 0.24, 0.77), (0.03, 0.2, 0.84), (0.07, 0.22, 0.88)], [0.007, 0.007, 0.005], seg_n=5), wash='tinta', mat='plano', bone='barril.T', hull=False)
    for sx in (1, -1):
        B.piece(tube([(sx * 0.11, 0.13, 0.6), (sx * 0.13, -0.03, 0.42), (sx * 0.1, -0.1, 0.3)], [0.011] * 3, seg_n=6), wash='sombra', bone='chest', oline=0.6)
    # pá e enxadão cruzados nas costas, saindo acima da aba do chapéu (leem de cima como um X)
    for sx in (1, -1):
        a0 = Vector((sx * 0.22, 0.36, 0.28)); a1 = Vector((-sx * 0.25, 0.36, 1.16))
        B.piece(limb(a0, a1, 0.013, 0.012, seg_n=7, rings=2), wash='sombra', bone='mochila')
        dd = (a1 - a0).normalized()
        if sx == 1:   # pá de sapa: lâmina larga
            pa = slab([(-0.07, 0.0), (0.07, 0.0), (0.06, 0.16), (0.0, 0.2), (-0.06, 0.16)], 0.012)
            q = Vector((0, 0, 1)).rotation_difference(dd)
            B.piece(xform(pa, Matrix.Translation(a1 - dd * 0.02) @ q.to_matrix().to_4x4()), wash='rio', bone='mochila')
        else:         # enxadão: cabeça atravessada
            hd0 = a1 + Vector((0.0, -0.02, 0.0))
            B.piece(tube([hd0 + Vector((0.11, 0, -0.06)), hd0 + Vector((0.0, 0, 0.02)), hd0 + Vector((-0.13, 0, -0.03))], [0.004, 0.022, 0.006], seg_n=7), wash='rio', bone='mochila')
    # lanterna de sapador pendurada no lado direito da mochila (balança com mola; o motor acende a luz)
    lz = 0.46
    B.piece(place(mk('cube', bevel=0.004), (-0.2, 0.2, lz), (0.045, 0.045, 0.06)), wash='cera', bone='lanterna', oline=0.8)
    for zz in (lz - 0.065, lz + 0.065):
        B.piece(place(mk('cube', bevel=0.003), (-0.2, 0.2, zz), (0.055, 0.055, 0.012)), wash='tinta', mat='plano', bone='lanterna', hull=False)
    B.piece(limb((-0.2, 0.2, lz + 0.075), (-0.2, 0.2, lz + 0.18), 0.004, 0.004, seg_n=4, rings=2), wash='tinta', mat='plano', bone='lanterna', hull=False)
    fl2 = loft([(0.0, 0.016, 0.016, 0, 2.0), (0.03, 0.022, 0.022, 0, 2.0), (0.07, 0.003, 0.003, 0, 2.0)], seg_n=8)
    B.piece(place(fl2, (-0.2, 0.2, lz - 0.04)), wash='fogo', mat='chama', bone='lanterna', hull=False)
    # cachecol de anil: volta no pescoço e duas pontas compridas que voam para trás
    B.piece(place(loft([(0.0, 0.105, 0.1, 0, 2.0), (0.05, 0.11, 0.105, 0, 2.0)], seg_n=14, cap_bot=False, cap_top=False), (0, 0, S['neck'] - 0.04)), wash='anil', bone='chest')
    def wcc(co):
        t = max(0.0, min(1.0, (co.y - 0.1) / 0.4))
        return {'chest': max(0.0, 1 - 2 * t), 'cachecol1': 1 - abs(2 * t - 1) if t < 1 else 0.0, 'cachecol2': max(0.0, 2 * t - 1)}
    for k, dx in enumerate((0.03, -0.04)):
        B.piece(tube([(dx, 0.1, 0.45), (dx + 0.01, 0.22, 0.44), (dx + 0.03, 0.36, 0.41), (dx + 0.06, 0.5, 0.37)], [0.034, 0.036, 0.034, 0.03], seg_n=8, flat=0.3),
                wash='anil', weights=wcc)
    # picareta comprida na mão direita
    hc, tip = J(B, 'prop')
    d = (tip - hc).normalized()
    B.piece(limb(hc - d * 0.08, hc + d * 0.5, 0.012, 0.013, seg_n=8, rings=2), wash='sombra', bone='prop')
    pk = tube([hc + d * 0.48 + Vector((0, 0, 0.16)), hc + d * 0.52 + Vector((0, 0, 0.04)), hc + d * 0.52 + Vector((0, 0, -0.06)), hc + d * 0.46 + Vector((0, 0, -0.17))],
              [0.004, 0.022, 0.022, 0.004], seg_n=8)
    B.piece(pk, wash='rio', bone='prop')
    B.S['_body'] = (0.25, 0.05, 1.0)
    return B

# ================================================================== BRUXA DO PÁRA-RAIOS (bruxa, púrpura-múrice)
def build_bruxa():
    S = S_heroi(hw=0.195, hd=0.18, shw=0.11, arm_r=0.029, leg_r=0.034, legx=0.06)
    ht = S['headt']
    chain = []
    z = ht - 0.04
    pts = [(0, 0.0, z), (0.01, 0.03, z + 0.22), (0.05, 0.07, z + 0.42), (0.13, 0.1, z + 0.58), (0.25, 0.1, z + 0.66), (0.37, 0.06, z + 0.66)]
    names = ['chapeu1', 'chapeu2', 'chapeu3', 'chapeu4', 'chapeu5']
    for i in range(5):
        chain.append((names[i], pts[i], pts[i + 1], 'hat' if i == 0 else names[i - 1]))
    S['extra'] = chain + [('casaco.F', (0, -0.1, 0.32), (0, -0.14, 0.02), 'hips'), ('casaco.B', (0, 0.1, 0.32), (0, 0.18, 0.0), 'hips'),
                          ('cabelo.L', (0.17, 0.02, 0.62), (0.21, 0.04, 0.48), 'head'), ('cabelo.R', (-0.17, 0.02, 0.62), (-0.21, 0.04, 0.48), 'head')]
    B = novo(44, S)
    hb = S['headb']
    # casaco comprido que arrasta no chão, barra queimada (tinta), aberto na frente
    def wcas(co):
        h = max(0.0, min(1.0, (S['waist'] - co.z) / 0.3))
        f = 1.0 if co.y < 0 else 0.0
        return {'hips': 1 - h, 'casaco.F': h * f, 'casaco.B': h * (1 - f)}
    cas = loft([(0.0, 0.2, 0.2, 0.04, 2.0), (0.1, 0.17, 0.16, 0.025, 2.0), (0.24, 0.135, 0.125, 0.0, 2.0), (0.34, 0.12, 0.11, 0.0, 2.0)], seg_n=20, cap_bot=False)
    B.piece(place(cas, (0, 0, -0.01)), wash='amora', weights=wcas, axis=(0, 0, 1))
    barra = loft([(0.0, 0.205, 0.205, 0.04, 2.0), (0.035, 0.2, 0.2, 0.04, 2.0)], seg_n=20, cap_bot=False, cap_top=False)
    B.piece(place(barra, (0, 0, -0.012)), wash='tinta', mat='plano', weights=wcas, hull=False)
    tronco(B, [(0.0, 0.12, 0.11, 0, 2.2), (0.1, 0.125, 0.11, 0, 2.3), (0.16, 0.11, 0.1, 0, 2.2), (0.19, 0.055, 0.05, 0, 2.0)], 'amora')
    # gola alta de padre-de-tempestade e o raio do jogador 4 em papel
    B.piece(place(loft([(0.0, 0.1, 0.095, 0.01, 2.0), (0.07, 0.13, 0.12, 0.02, 2.0)], seg_n=16, cap_bot=False, cap_top=False), (0, 0, S['neck'] - 0.03)), wash='amora', bone='chest')
    rz = slab([(-0.01, 0.06), (0.025, 0.06), (0.005, 0.03), (0.025, 0.03), (-0.02, -0.02), (-0.002, 0.018), (-0.022, 0.018)], 0.012)
    B.piece(place(rz, (0, -0.115, S['waist'] + 0.05), rot=(5, 0, 0)), wash='papel_dia', bone='chest', oline=0.5)
    # livro de contrato com corrente, no quadril
    B.piece(place(mk('cube', bevel=0.004), (0.15, -0.02, S['hip']), (0.012, 0.045, 0.055), rot=(0, 0, 10)), wash='sombra', bone='hips', oline=0.7)
    rings = cabeca(B, wash='papel_dia', queixo=0.85)
    # rosto vaidoso: pálpebras a meio-pau, cílios, sorriso de canto, queixo fino
    for sx in (-1, 1):
        olho(B, rings, sx * 0.072, 0.18, w=0.034, h=0.04, palp=0.5, palp_ang=-8)
        for k in range(3):
            p = rosto_pt(B, rings, sx * (0.075 + 0.02 * k), 0.198 + 0.004 * k, 0.012)
            traco(B, [p, p + Vector((sx * 0.02, -0.006, 0.016 - 0.005 * k))], 0.005)
        traco(B, [rosto_pt(B, rings, sx * 0.035, 0.245), rosto_pt(B, rings, sx * 0.08, 0.26), rosto_pt(B, rings, sx * 0.12, 0.25)], 0.007)
    B.piece(limb(rosto_pt(B, rings, 0, 0.15, -0.004), rosto_pt(B, rings, 0, 0.11, 0.035), 0.02, 0.008, seg_n=8, rings=3), wash='papel_dia', bone='head', oline=0.6)
    traco(B, [rosto_pt(B, rings, -0.035, 0.075), rosto_pt(B, rings, 0.0, 0.068), rosto_pt(B, rings, 0.04, 0.074), rosto_pt(B, rings, 0.058, 0.09)], 0.007)
    # cabelo comprido (sombra) que sai do chapéu dos dois lados, com mola
    for s, sx in (('L', 1), ('R', -1)):
        B.piece(tube([(sx * 0.17, 0.03, 0.82), (sx * 0.21, 0.04, 0.66), (sx * 0.2, 0.06, 0.5), (sx * 0.17, 0.08, 0.44)], [0.05, 0.055, 0.045, 0.02], seg_n=10, flat=0.6),
                wash='sombra', weights=lambda co, s=s: {'cabelo.' + s: min(1, max(0, (0.7 - co.z) / 0.2)), 'head': 1 - min(1, max(0, (0.7 - co.z) / 0.2))})
    # chapéu altíssimo e torto: aba larga ondulada + cone em 5 ossos, ponta de ferro e espiral de cobre
    aba = loft([(0.0, 0.32, 0.3, 0.0, 2.0), (0.018, 0.32, 0.3, 0.0, 2.0)], seg_n=24)
    for v in aba.verts:
        a = math.atan2(v.co.y, v.co.x)
        v.co.z += 0.03 * math.sin(3 * a) * (math.hypot(v.co.x, v.co.y) > 0.2)
    B.piece(place(aba, (0, 0, ht - 0.07)), wash='amora', bone='hat')
    rgs = []
    for i in range(6):
        p = Vector(pts[i])
        r = 0.15 * (1 - i / 5.4) ** 1.4 + 0.01
        rgs.append((p, r))
    def wch(co):
        best = {}
        for i in range(5):
            a, b = Vector(pts[i]), Vector(pts[i + 1])
            t = max(0, min(1, (co - a).dot(b - a) / (b - a).length_squared))
            dd = (co - (a + (b - a) * t)).length
            best[names[i]] = 1.0 / (0.02 + dd) ** 3
        tot = sum(best.values())
        return {k: v / tot for k, v in best.items()}
    cone = tube([p for p, r in rgs], [r for p, r in rgs], seg_n=16)
    B.piece(cone, wash='amora', weights=wch)
    B.piece(tube([Vector(pts[0]) + Vector((0, 0, 0.04)), Vector(pts[0]) + Vector((0, 0.005, 0.075))], [0.165, 0.16], seg_n=16), wash='sombra', bone='chapeu1', oline=0.7)
    tipb = Vector(pts[5])
    B.piece(limb(tipb - Vector((0.02, 0, 0.01)), tipb + Vector((0.09, 0.0, 0.07)), 0.012, 0.003, seg_n=6, rings=3), wash='tinta', mat='grav', bone='chapeu5', oline=0.6)
    sp = []
    for k in range(26):
        t = k / 25
        a = t * 6 * math.pi
        sp.append(Vector(pts[4]).lerp(tipb, t) + Vector((math.cos(a), math.sin(a), 0)) * (0.032 - 0.014 * t))
    B.piece(tube(sp, [0.006] * len(sp), seg_n=5, cap=False), wash='fogo', bone='chapeu5', oline=0.5)
    braco(B, 'L', 'amora', fist=False, manga_r=1.3)
    braco(B, 'R', 'amora', fist=True, manga_r=1.3)
    perna(B, 'L', 'tinta', bota='sombra', bota_k=0.9)
    perna(B, 'R', 'tinta', bota='sombra', bota_k=0.9)
    # cajado em forquilha (madeira torta, dois dentes com fio de cobre)
    hc, tip = J(B, 'prop')
    d = Vector((0, -0.25, 1.0)).normalized()
    a = hc - d * 0.25; b = hc + d * 0.55
    B.piece(tube([a, hc, hc + d * 0.3 + Vector((0.01, 0, 0)), b], [0.012, 0.013, 0.013, 0.014], seg_n=7), wash='sombra', bone='prop')
    for sx in (1, -1):
        B.piece(tube([b, b + d * 0.06 + Vector((sx * 0.04, 0, 0)), b + d * 0.16 + Vector((sx * 0.06, 0, 0))], [0.012, 0.009, 0.004], seg_n=6), wash='sombra', bone='prop')
    B.S['_body'] = (0.3, 0.0, 1.7)
    return B

# ================================================================== MILICIANO (aldeão retomado, com chapéu de piqueiro)
def build_miliciano():
    S = S_heroi(hw=0.18, hd=0.17, shw=0.11, hip=0.21, waist=0.27, chest=0.34, neck=0.4, headb=0.42, headt=0.8, shz=0.385, ua=0.09, fa=0.085,
                arm_r=0.03, leg_r=0.034, legx=0.06, knee=0.115, ankle=0.04)
    B = novo(55, S)
    hb, ht = S['headb'], S['headt']
    tronco(B, [(0.0, 0.11, 0.1, 0, 2.2), (0.09, 0.12, 0.11, 0, 2.3), (0.14, 0.105, 0.095, 0, 2.2), (0.16, 0.05, 0.045, 0, 2.0)], 'verde_terra')
    B.piece(place(loft([(0.0, 0.13, 0.12, 0, 2.0), (0.09, 0.115, 0.105, 0, 2.0)], seg_n=14, cap_bot=False), (0, 0, S['hip'] - 0.07)), wash='verde_terra', bone='hips')
    rings = cabeca(B, wash='papel_dia')
    for sx in (-1, 1):
        olho(B, rings, sx * 0.065, 0.17, w=0.026, h=0.034)
        traco(B, [rosto_pt(B, rings, sx * 0.035, 0.225), rosto_pt(B, rings, sx * 0.09, 0.235)], 0.008)
    B.piece(place(mk('sphere', u=8, v=6), rosto_pt(B, rings, 0, 0.12, 0.0), (0.02, 0.018, 0.02)), wash='papel_dia', bone='head', oline=0.6)
    traco(B, [rosto_pt(B, rings, -0.04, 0.07), rosto_pt(B, rings, 0, 0.055), rosto_pt(B, rings, 0.04, 0.07)], 0.008)
    # chapéu de piqueiro (morrião de palha batida): copa com crista e aba em canoa
    cp = loft([(0.0, 0.2, 0.19, 0, 2.0), (0.07, 0.19, 0.18, 0, 2.0), (0.14, 0.12, 0.13, 0, 2.0), (0.16, 0.03, 0.05, 0, 2.0)], seg_n=16)
    B.piece(place(cp, (0, 0, ht - 0.13)), wash='trigo', bone='hat')
    aba = loft([(0.0, 0.3, 0.24, 0, 2.0), (0.015, 0.3, 0.24, 0, 2.0)], seg_n=20)
    for v in aba.verts:
        v.co.z += 0.12 * (abs(v.co.y) / 0.24) ** 2
    B.piece(place(aba, (0, 0, ht - 0.12)), wash='trigo', bone='hat')
    B.piece(place(slab([(-0.16, 0), (0.16, 0), (0.1, 0.05), (-0.1, 0.05)], 0.02), (0, 0, ht + 0.02), rot=(0, 0, 90)), wash='ocre', bone='hat', oline=0.7)
    braco(B, 'L', 'ocre', fist=True)
    braco(B, 'R', 'ocre', fist=True)
    perna(B, 'L', 'sombra', bota='sombra', bota_k=0.9)
    perna(B, 'R', 'sombra', bota='sombra', bota_k=0.9)
    B.S['_body'] = (0.2, 0.0, 0.9)
    return B

# ================================================================== MORTOS DA PROCISSÃO (só papel e tinta, olhos verde-mordente)
def olhos_verdes(B, rings, z, dx=0.07, w=0.03, h=0.03):
    S = B.S
    for sx in (-1, 1):
        p, n = front_pt(rings, sx * dx, z, S['headb'])
        xa = Vector((0, 0, 1)).cross(n).normalized(); ya = n.cross(xa).normalized()
        M = Matrix.Translation(p + n * 0.004) @ Matrix((xa, ya, n)).transposed().to_4x4()
        B.piece(xform(place(mk('sphere', u=10, v=7), (0, 0, 0), (w * 1.35, h * 1.35, 0.01)), M), wash='tinta', mat='plano', bone='head', hull=False)
        B.piece(xform(place(mk('sphere', u=10, v=7), (0, 0, 0.004), (w, h, 0.012), rot=(0, 0, sx * -18)), M), wash='mordente', mat='verde', bone='head', hull=False)

def build_piqueiro():
    S = S_heroi(hw=0.18, hd=0.17, shw=0.12, hip=0.27, waist=0.33, chest=0.42, neck=0.5, headb=0.52, headt=0.88, shz=0.47, ua=0.11, fa=0.1,
                arm_r=0.022, leg_r=0.025, legx=0.065, knee=0.15, ankle=0.045, extra=[('pique', (0, -0.1, 0.4), (0, -0.4, 0.4), 'root')])
    B = novo(66, S)
    hb, ht = S['headb'], S['headt']
    # armadura de tampa de caixão: hexágono alongado na frente e nas costas, pregos de tinta
    tampa = slab([(-0.08, 0.0), (0.08, 0.0), (0.15, 0.24), (0.11, 0.36), (-0.11, 0.36), (-0.15, 0.24)], 0.028)
    for sy in (-1, 1):
        B.piece(place(tampa.copy(), (0, sy * 0.085, S['hip'] - 0.05), rot=(sy * 4, 0, 0)), bone='chest')
        for (x, z) in ((-0.1, 0.3), (0.1, 0.3), (-0.12, 0.2), (0.12, 0.2), (0, 0.05)):
            B.piece(place(mk('sphere', u=6, v=4), (x, sy * 0.1, S['hip'] - 0.05 + z), (0.012, 0.006, 0.012)), wash='tinta', mat='plano', bone='chest', hull=False)
    tampa.free()
    # cruz pregada torta na tampa da frente
    B.piece(place(slab([(-0.015, 0), (0.015, 0), (0.015, 0.2), (-0.015, 0.2)], 0.01), (0.0, -0.104, S['hip'] + 0.04), rot=(-4, 8, 0)), wash='tinta', mat='plano', bone='chest', hull=False)
    B.piece(place(slab([(-0.07, 0), (0.07, 0), (0.07, 0.025), (-0.07, 0.025)], 0.01), (0.005, -0.105, S['hip'] + 0.17), rot=(-4, 8, 0)), wash='tinta', mat='plano', bone='chest', hull=False)
    # crânio grande com órbitas fundas e mandíbula
    rings = cabeca(B, wash=None, queixo=0.8)
    olhos_verdes(B, rings, 0.15, dx=0.068, w=0.032, h=0.028)
    for k in range(5):
        x = -0.06 + 0.03 * k
        p, n = front_pt(rings, x, 0.06, hb)
        B.piece(place(mk('cube'), p + n * 0.004, (0.011, 0.006, 0.016)), wash=None, bone='head', oline=0.5)
    p, n = front_pt(rings, 0.0, 0.11, hb)
    B.piece(place(mk('sphere', u=6, v=5), p + n * 0.002, (0.018, 0.008, 0.016)), wash='tinta', mat='plano', bone='head', hull=False)
    # morrião amassado com crista
    cp = loft([(0.0, 0.2, 0.19, 0, 2.0), (0.08, 0.19, 0.18, 0, 2.0), (0.14, 0.12, 0.12, 0, 2.0), (0.17, 0.02, 0.04, 0, 2.0)], seg_n=16)
    B.piece(place(cp, (0, 0, ht - 0.1), rot=(0, 7, 0)), bone='hat')
    aba = loft([(0.0, 0.29, 0.25, 0, 2.0), (0.015, 0.29, 0.25, 0, 2.0)], seg_n=20)
    for v in aba.verts:
        v.co.z += 0.13 * (abs(v.co.y) / 0.25) ** 2
    B.piece(place(aba, (0, 0, ht - 0.1), rot=(0, 7, 0)), bone='hat')
    B.piece(place(slab([(-0.17, 0), (0.17, 0), (0.1, 0.07), (-0.1, 0.07)], 0.02), (0, 0, ht + 0.04), rot=(0, 7, 90)), bone='hat', oline=0.7)
    # membros de osso (finos) com nós
    for s in 'LR':
        sh, el = J(B, 'upperarm.' + s); _, wr = J(B, 'forearm.' + s)
        B.piece(limb(sh, el, 0.022, 0.018, seg_n=8, rings=3), bone='upperarm.' + s)
        B.piece(limb(el, wr, 0.018, 0.016, seg_n=8, rings=3), bone='forearm.' + s)
        B.piece(place(mk('sphere', u=8, v=6), el, (0.026, 0.026, 0.026)), bone='forearm.' + s, oline=0.6)
        mao(B, s, fist=True, wash=None, s=0.8)
        th, kn = J(B, 'thigh.' + s); _, an = J(B, 'shin.' + s)
        B.piece(limb(th, kn, 0.026, 0.02, seg_n=8, rings=3), bone='thigh.' + s)
        B.piece(limb(kn, an, 0.02, 0.018, seg_n=8, rings=3), bone='shin.' + s)
        B.piece(place(mk('sphere', u=8, v=6), kn, (0.028, 0.028, 0.028)), bone='shin.' + s, oline=0.6)
        B.piece(place(loft([(0.0, 0.035, 0.06, -0.02, 2.2), (0.03, 0.035, 0.06, -0.02, 2.2), (0.045, 0.025, 0.03, 0, 2.0)], seg_n=10), (an.x, an.y, 0.0)), bone='foot.' + s)
    # pique de 3,5 m: haste e ponta de ferro com o ponto fraco (nada verde aqui: o verde vai na telegrafia no chão)
    a, b = J(B, 'pique')
    B.piece(limb((0, 0.9, 0.4), (0, -2.55, 0.4), 0.012, 0.012, seg_n=6, rings=2), bone='pique', oline=0.6)
    B.piece(xform(slab([(-0.025, 0), (0.025, 0), (0.0, 0.16)], 0.012), Matrix.Translation((0, -2.55, 0.4)) @ Matrix.Rotation(math.pi / 2, 4, 'X')), wash='tinta', mat='plano', bone='pique', hull=False)
    B.S['_body'] = (0.2, 0.0, 1.0)
    return B

def build_penitente():
    S = S_heroi(hw=0.17, hd=0.165, shw=0.1, hip=0.2, waist=0.26, chest=0.33, neck=0.38, headb=0.4, headt=0.76, shz=0.36, ua=0.09, fa=0.08,
                arm_r=0.026, leg_r=0.03, legx=0.05, knee=0.11, ankle=0.04,
                extra=[('capuz', (0, 0.1, 0.7), (0, 0.2, 0.86), 'head')])
    h = hc_of(S, 'L')
    S['extra'] += [('corrente', tuple(h), tuple(h + Vector((0, 0, -0.18))), 'hand.L'), ('bola', tuple(h + Vector((0, 0, -0.18))), tuple(h + Vector((0, 0, -0.3))), 'corrente')]
    B = novo(77, S)
    hb, ht = S['headb'], S['headt']
    tun = loft([(0.0, 0.17, 0.16, 0.01, 2.0), (0.1, 0.15, 0.14, 0.0, 2.0), (0.26, 0.11, 0.1, 0, 2.0), (0.34, 0.08, 0.07, 0, 2.0)], seg_n=16, cap_bot=False)
    B.piece(place(tun, (0, 0, 0.03)), weights=lambda co: {'hips': 1.0 if co.z < 0.25 else 0.5, 'chest': 0.0 if co.z < 0.25 else 0.5}, axis=(0, 0, 1))
    rings = cabeca(B, wash=None, queixo=0.9)
    olhos_verdes(B, rings, 0.16, dx=0.06, w=0.026, h=0.024)
    traco(B, [rosto_pt(B, rings, -0.05, 0.07), rosto_pt(B, rings, 0.0, 0.08), rosto_pt(B, rings, 0.05, 0.07)], 0.007)
    # número da tiragem na testa: placa de papel com 3 traços de tinta
    p, n = front_pt(rings, 0.0, 0.25, hb)
    B.piece(place(mk('cube'), p + n * 0.003, (0.05, 0.004, 0.018), rot=(-20, 0, 0)), wash='papel_dia', mat='plano', bone='head', hull=False)
    for k in range(4):
        B.piece(place(mk('cube'), p + n * 0.007 + Vector((-0.032 + 0.021 * k, 0, 0)), (0.003, 0.003, 0.011), rot=(-20, 0, 15 if k == 1 else 0)), wash='tinta', mat='plano', bone='head', hull=False)
    # capuz pontudo que cai para trás
    bm = bmesh.new()
    prof = [(0.0, 0.205, 0.02), (0.12, 0.215, 0.03), (0.26, 0.2, 0.05), (0.36, 0.13, 0.09), (0.44, 0.04, 0.16), (0.48, 0.005, 0.24)]
    rows = []
    for z, r, yo in prof:
        rr = []
        for j in range(15):
            a = math.radians(-145 + 290 * j / 14) + math.pi / 2   # abre na frente (-Y)
            rr.append(bm.verts.new((r * math.cos(a), yo + r * math.sin(a), z)))
        rows.append(rr)
    for i in range(len(rows) - 1):
        for j in range(14):
            bm.faces.new([rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.02)
    cz = bm
    B.piece(place(cz, (0, 0.0, hb + 0.02)), weights=lambda co: {'capuz': min(1, max(0, (co.z - 0.7) / 0.1)), 'head': 1 - min(1, max(0, (co.z - 0.7) / 0.1))})
    for s in 'LR':
        braco(B, s, None, pele=None, fist=True)
        sh, el = J(B, 'upperarm.' + s)
        perna(B, s, None, bota=None, bota_k=0.8)
    # flagelo: corrente e bola com cravos, na mão esquerda
    a, b = J(B, 'corrente'); _, c = J(B, 'bola')
    B.piece(tube([a, (a + b) / 2 + Vector((0.01, 0, 0)), b], [0.008] * 3, seg_n=5), wash='tinta', mat='plano', bone='corrente', hull=False)
    B.piece(place(mk('ico', sub=1), b + Vector((0, 0, -0.04)), (0.04, 0.04, 0.04)), bone='bola')
    B.S['_body'] = (0.2, 0.0, 0.85)
    return B

def build_carpideira():
    S = S_heroi(hw=0.15, hd=0.15, shw=0.13, hip=0.78, waist=0.88, chest=1.08, neck=1.24, headb=1.26, headt=1.58, shz=1.2, ua=0.3, fa=0.3,
                arm_r=0.02, leg_r=0.03, legx=0.06, knee=0.45, ankle=0.15, hand=1.3,
                extra=[('veu.F', (0, -0.14, 1.4), (0, -0.2, 0.35), 'head'), ('veu.B', (0, 0.15, 1.4), (0, 0.25, 0.25), 'head'),
                       ('veu.L', (0.15, 0, 1.4), (0.3, 0.02, 0.3), 'head'), ('veu.R', (-0.15, 0, 1.4), (-0.3, 0.02, 0.3), 'head'),
                       ('boca', (0, -0.15, 1.33), (0, -0.2, 1.33), 'head')])
    B = novo(88, S)
    hb, ht = S['headb'], S['headt']
    # corpo magro, sem pernas visíveis (flutua): túnica que afina em fiapos
    tun = loft([(0.0, 0.03, 0.03, 0.0, 2.0), (0.3, 0.12, 0.1, 0.0, 2.0), (0.7, 0.15, 0.12, 0, 2.0), (1.0, 0.12, 0.1, 0, 2.0), (1.18, 0.07, 0.06, 0, 2.0)], seg_n=14)
    B.piece(place(tun, (0, 0, 0.12)), weights=lambda co: {'hips': 1.0 if co.z < 0.9 else 0.0, 'chest': 0.0 if co.z < 0.9 else 1.0}, axis=(0, 0, 1))
    rings = cabeca(B, wash=None, aguda=0.2, queixo=0.7)
    olhos_verdes(B, rings, 0.17, dx=0.05, w=0.02, h=0.03)
    # boca: oval de tinta com o verde no fundo (acende quando inspira; o motor sobe a escala do osso 'boca')
    p, n = front_pt(rings, 0.0, 0.07, hb)
    xa = Vector((0, 0, 1)).cross(n).normalized(); ya = n.cross(xa).normalized()
    M = Matrix.Translation(p + n * 0.004) @ Matrix((xa, ya, n)).transposed().to_4x4()
    B.piece(xform(place(mk('sphere', u=10, v=7), (0, 0, 0), (0.035, 0.05, 0.01)), M), wash='tinta', mat='plano', bone='boca', hull=False)
    B.piece(xform(place(mk('sphere', u=10, v=7), (0, -0.005, 0.004), (0.022, 0.032, 0.012)), M), wash='mordente', mat='verde', bone='boca', hull=False)
    # véu longo: 4 painéis com mola, do alto da cabeça até perto do chão (papel, sem aguada)
    for s, (dx, dy) in (('F', (0, -1)), ('B', (0, 1)), ('L', (1, 0)), ('R', (-1, 0))):
        a, b = J(B, 'veu.' + s)
        if s == 'F':
            continue
        w = 0.2
        pts = []
        L = 10
        for i in range(L + 1):
            t = i / L
            pts.append(a.lerp(b, t) + Vector((dx, dy, 0)) * 0.06 * math.sin(math.pi * t))
        side = Vector((-dy, dx, 0))
        bm = bmesh.new()
        rows = []
        for i, p in enumerate(pts):
            wv = w * (0.6 + 0.5 * i / L)
            rr = []
            for j in range(5):
                u = (j / 4 - 0.5) * 2
                q = p + side * u * wv + Vector((dx, dy, 0)) * (0.03 * (1 - u * u))
                if i == L:
                    q.z += 0.06 * math.sin(j * 2.1)
                rr.append(bm.verts.new(q))
            rows.append(rr)
        for i in range(L):
            for j in range(4):
                bm.faces.new([rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]])
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.012)
        ht_ = a.z
        B.piece(bm, weights=lambda co, s=s, ht_=ht_: {'veu.' + s: min(1, max(0, (ht_ - co.z) / 0.3)), 'head': 1 - min(1, max(0, (ht_ - co.z) / 0.3))})
    # capelo de véu sobre a cabeça
    cz = loft([(0.0, 0.165, 0.165, 0.01, 2.0), (0.2, 0.17, 0.17, 0.01, 2.0), (0.32, 0.12, 0.12, 0.02, 2.0), (0.37, 0.02, 0.02, 0.03, 2.0)], seg_n=16, cap_bot=False)
    for v in cz.verts:
        if v.co.y < -0.1 and v.co.z < 0.24:
            v.co.y = 0.02
    B.piece(place(cz, (0, 0.0, hb + 0.04)), bone='head')
    # braços compridos demais, mãos de dedos longos
    for s in 'LR':
        sh, el = J(B, 'upperarm.' + s); _, wr = J(B, 'forearm.' + s)
        B.piece(limb(sh, el, 0.024, 0.018, seg_n=8, rings=3), bone='upperarm.' + s)
        B.piece(limb(el, wr, 0.018, 0.014, seg_n=8, rings=3), bone='forearm.' + s)
        _, hc = J(B, 'hand.' + s)
        sx = 1 if s == 'L' else -1
        for k in range(4):
            fx = (k - 1.5) * 0.016
            B.piece(tube([wr, wr + Vector((fx, -0.01, -0.06)), wr + Vector((fx * 1.6, -0.03, -0.14)), wr + Vector((fx * 2, -0.06, -0.19))], [0.012, 0.009, 0.007, 0.003], seg_n=5), bone='hand.' + s, oline=0.5)
    B.S['_body'] = (0.3, 0.0, 1.75)
    return B

# ================================================================== adereços soltos (passam de mão em mão)
def prop_bones():
    return [('root', (0, 0, 0), (0, 0, 0.1), None)]

def build_mastro():
    """estandarte: mastro de 1,45 m (1,5x o corpo) com ponta de ferro; a bandeira é do motor (pano com vento)."""
    B = Builder(91, ['root'])
    B.bones = prop_bones(); B.S = {}
    B.piece(limb((0, 0, -0.05), (0, 0, 1.45), 0.017, 0.015, seg_n=8, rings=2), wash='sombra', bone='root')
    B.piece(limb((-0.28, 0, 1.36), (0.03, 0, 1.36), 0.012, 0.012, seg_n=6, rings=2), wash='sombra', bone='root')
    B.piece(place(mk('sphere', u=8, v=6), (0, 0, 1.46), (0.025, 0.025, 0.02)), wash='rio', bone='root')
    B.piece(limb((0, 0, 1.47), (0, 0, 1.64), 0.022, 0.002, seg_n=6, rings=3), wash='rio', bone='root')
    B.piece(xform(slab([(-0.03, 0), (0.03, 0), (0, 0.05)], 0.01), Matrix.Translation((0, 0, 1.55)) @ Matrix.Rotation(-math.pi / 2, 4, 'X') @ Matrix.Rotation(math.pi / 2, 4, 'X')), wash='rio', bone='root')
    B.piece(limb((0, 0, -0.05), (0, 0, -0.16), 0.016, 0.002, seg_n=6, rings=2), wash='rio', bone='root')
    return B

def build_sino():
    """sino de bronze num cabo: cabeça no punho, boca para a frente (-Y) como o adereço em repouso."""
    B = Builder(92, ['root'])
    B.bones = prop_bones(); B.S = {}
    B.piece(limb((0, 0.06, 0), (0, -0.24, 0), 0.014, 0.015, seg_n=8, rings=2), wash='sombra', bone='root')
    rings = [(0.0, 0.04, 0.04, 0, 2.0), (0.04, 0.078, 0.078, 0, 2.0), (0.13, 0.09, 0.09, 0, 2.0), (0.22, 0.13, 0.13, 0, 2.0), (0.26, 0.17, 0.17, 0, 2.0), (0.28, 0.17, 0.17, 0, 2.0)]
    sino = loft(rings, seg_n=18, cap_top=False)
    B.piece(xform(sino, Matrix.Translation((0, -0.24, 0)) @ Matrix.Rotation(math.pi / 2, 4, 'X')), wash='ocre', bone='root', axis=(0, -1, 0))
    B.piece(xform(loft([(0.0, 0.174, 0.174, 0, 2.0), (0.025, 0.174, 0.174, 0, 2.0)], seg_n=18, cap_bot=False, cap_top=False), Matrix.Translation((0, -0.24 - 0.225, 0)) @ Matrix.Rotation(math.pi / 2, 4, 'X')),
            wash='tinta', mat='plano', bone='root', hull=False)
    B.piece(place(mk('sphere', u=8, v=6), (0, -0.5, 0.0), (0.04, 0.04, 0.04)), wash='tinta', mat='plano', bone='root', hull=False)
    return B

def build_pote():
    B = Builder(93, ['root'])
    B.bones = prop_bones(); B.S = {}
    B.piece(loft([(0.0, 0.035, 0.035, 0, 2.0), (0.05, 0.05, 0.05, 0, 2.0), (0.08, 0.03, 0.03, 0, 2.0), (0.1, 0.034, 0.034, 0, 2.0)], seg_n=12), wash='cera', bone='root')
    return B

def build_tocha():
    B = Builder(94, ['root'])
    B.bones = prop_bones(); B.S = {}
    B.piece(limb((0, 0, -0.3), (0, 0, 0.35), 0.014, 0.02, seg_n=8, rings=2), wash='sombra', bone='root')
    B.piece(limb((0, 0, 0.3), (0, 0, 0.4), 0.03, 0.032, seg_n=8, rings=2), wash='tinta', mat='plano', bone='root', hull=False)
    fl = loft([(0.0, 0.03, 0.03, 0, 2.0), (0.05, 0.04, 0.04, 0, 2.0), (0.14, 0.003, 0.003, 0, 2.0)], seg_n=10)
    B.piece(place(fl, (0, 0, 0.39)), wash='fogo', mat='chama', bone='root', hull=False)
    return B

def build_piquemil():
    B = Builder(95, ['root'])
    B.bones = prop_bones(); B.S = {}
    B.piece(limb((0, 0, -0.5), (0, 0, 1.6), 0.011, 0.011, seg_n=6, rings=2), wash='sombra', bone='root')
    B.piece(limb((0, 0, 1.6), (0, 0, 1.78), 0.02, 0.002, seg_n=6, rings=3), wash='rio', bone='root')
    return B

HEROES = {'porta': build_porta, 'sineira': build_sineira, 'sapador': build_sapador, 'bruxa': build_bruxa}
OTHERS = {'miliciano': build_miliciano, 'piqueiro': build_piqueiro, 'penitente': build_penitente, 'carpideira': build_carpideira}
PROPS = {'mastro': build_mastro, 'sino': build_sino, 'pote': build_pote, 'tocha': build_tocha, 'piquemil': build_piquemil}

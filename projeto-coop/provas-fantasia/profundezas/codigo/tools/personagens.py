# Personagens de Plumbdeep: os 4 heróis da Guilda do Prumo (Escorador, Cristaleira, Coveira, Gancheiro),
# 2 inimigos da Mata de Lume (Ouvidor e Bocalume) e o Prumo. Tudo em bmesh; a malha 'sub' recebe Catmull-Clark
# (forma esculpida de miniatura), a 'flat' fica dura (tábuas, viga, lâminas). A pintura (lavagem, aresta, zenital,
# brilho pintado, lascas) é assada no montar.py e lida pelo shader mini_pintada.
# Proporção: 2,25 cabeças, 0,85 m, escala heroica (cabeça, mãos e armas exageradas).
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler, Quaternion
from malha import *
from formas import *

def bevel_box(c, s, bev=0.008, rot=(0, 0, 0)):
    bm = mk('cube', bevel=bev / max(min(s), 1e-3), bseg=1)
    return place(bm, c, s, rot)

def torus(R, r, nu=20, nv=8, groove=0, gk=0.0):
    bm = bmesh.new()
    rings = []
    for i in range(nu):
        a = 2 * math.pi * i / nu
        ring = []
        for j in range(nv):
            b = 2 * math.pi * j / nv
            rr = r * (1 + gk * math.sin(groove * a + b)) if groove else r
            ring.append(bm.verts.new(((R + rr * math.cos(b)) * math.cos(a), (R + rr * math.cos(b)) * math.sin(a), rr * math.sin(b))))
        rings.append(ring)
    for i in range(nu):
        for j in range(nv):
            a, b_ = rings[i][j], rings[(i + 1) % nu][j]
            c, d = rings[(i + 1) % nu][(j + 1) % nv], rings[i][(j + 1) % nv]
            bm.faces.new([a, b_, c, d])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm

def head_xf(B, p):
    return tuple(B._head_M @ Vector(p))

def chama(B, base, bone='chama', k=1.0):
    """chama de vela: gota emissiva (o motor anima a mola e o tremor)."""
    fl = loft([(0.0, 0.012 * k, 0.012 * k, 0, 2.0), (0.02 * k, 0.026 * k, 0.026 * k, 0, 2.0), (0.05 * k, 0.022 * k, 0.022 * k, 0, 2.0),
               (0.085 * k, 0.008 * k, 0.008 * k, 0, 2.0), (0.1 * k, 0.0, 0.0, 0, 2.0)], seg_n=8)
    B.piece(place(fl, base), paint='geodo', bone=bone, mat='emis', hull=False)

# ================================================================== ESCORADOR (guerreiro, Âmbar): viga de escora e capacete de vela
def build_escorador():
    S = dict(hip=0.2, waist=0.26, chest=0.35, neck=0.43, headb=0.44, headt=0.81, shz=0.41, shw=0.14, ua=0.1, ua_out=0.025,
             fa=0.09, hs=0.98, legx=0.07, knee=0.11, ankle=0.035, arm_r=0.043, leg_r=0.046, boot_k=1.18)
    ht = S['headb'] + 0.37
    S['extra'] = [('viga', (0, 0.07, S['shz'] + 0.07), (0.3, 0.07, S['shz'] + 0.07), 'chest'),
                  ('chama', (0, 0.0, ht + 0.16), (0, 0.0, ht + 0.26), 'hat'),
                  ('saco', (0.13, -0.02, 0.24), (0.15, -0.03, 0.12), 'hips')]
    bones = hero_bones(S)
    B = Builder(111, [b[0] for b in bones], outline=0.006)
    B.bones = bones; B.S = S; B.wash = 'lavagem'
    B.remap = {'pele': 'pele_escorador'}
    cabeca_grande(B, S, ['head', 'hat', 'chama'])
    torso(B, S, 'ambar', k_ombro=1.25, k_barriga=1.2)
    # avental de couro grosso, do peito aos joelhos
    av = shell([(S['chest'] + 0.03, 0.12, 0.115, -0.005), (S['waist'], 0.15, 0.135, -0.006), (S['hip'] - 0.02, 0.16, 0.14, -0.008), (0.09, 0.165, 0.145, -0.02)],
               122, 238, thick=0.012, seg=8)
    B.piece(av, paint='couro_claro', weights=lambda co: {'hips': 1.0} if co.z < S['waist'] else {'chest': 1.0}, jitter=0.002)
    cinto(B, S, 'couro', larg=1.22)
    B.piece(bevel_box((0, -0.14, S['waist'] - 0.005), (0.035, 0.012, 0.028), 0.004), paint='latao', bone='hips', mat='metal', oline=0.6, sub=False)
    z0 = S['headb']
    B.piece(place(loft(HEAD_RINGS, seg_n=12), (0, 0, z0)), paint='pele', bone='head', jitter=0.002)
    face(B, S, HEAD_RINGS, z0, eye_z=0.12, eye_w=0.066, eye_h=0.07, eye_x=0.066, mouth=None, brow='brava', mouth_w=0.05, brow_col='cabelo')
    # nariz de batata e bigode cheio (calado: a boca some sob o bigode)
    pn, nn = front_pt(HEAD_RINGS, 0.0, 0.085, z0)
    B.piece(place(mk('sphere', u=8, v=6), pn + nn * 0.012, (0.032, 0.03, 0.028)), paint='pele', bone='head')
    for sx in (-1, 1):
        pm, nm = front_pt(HEAD_RINGS, sx * 0.03, 0.055, z0)
        B.piece(tube([pm + nm * 0.01, pm + nm * 0.02 + Vector((sx * 0.04, 0, -0.01)), pm + nm * 0.005 + Vector((sx * 0.085, 0.01, -0.045))],
                     [0.022, 0.019, 0.008], seg_n=7), paint='cabelo', bone='head', jitter=0.002)
    # fuligem da vela: manchas na testa e numa bochecha (imperfeição com causa)
    for (fx, fz, sx_, sz_) in ((0.05, 0.2, 0.05, 0.022), (-0.09, 0.07, 0.03, 0.022), (-0.02, 0.215, 0.03, 0.014)):
        pf, nf = front_pt(HEAD_RINGS, fx, fz, z0)
        B.piece(disc(pf + nf * 0.003, nf, sx_, seg=8, sx=1.0, sy=sz_ / sx_), paint='fuligem', bone='head', hull=False, sub=False)
    # costeletas
    for sx in (-1, 1):
        B.piece(place(mk('sphere', u=7, v=5), (sx * 0.178, -0.02, z0 + 0.12), (0.03, 0.05, 0.07)), paint='cabelo', bone='head', oline=0.7)
    # CAPACETE DE MINERADOR: cúpula de couro fervido com aro de ferro e aba curta
    hz = z0 + 0.19
    dome = loft([(0.0, 0.205, 0.195, 0.0, 2.0), (0.06, 0.205, 0.195, 0.0, 2.0), (0.13, 0.18, 0.17, 0.0, 2.0), (0.18, 0.13, 0.125, 0.0, 2.0),
                 (0.205, 0.05, 0.05, 0.0, 2.0), (0.21, 0.0, 0.0, 0.0, 2.0)], seg_n=14, cap_bot=False)
    bmesh.ops.solidify(dome, geom=dome.faces[:], thickness=-0.014)
    B.piece(place(dome, (0, 0.004, hz)), paint='couro_claro', bone='hat', jitter=0.002)
    aba = loft([(0, 0.25, 0.245, -0.03, 2.0), (0.02, 0.235, 0.23, -0.025, 2.0)], seg_n=14)
    B.piece(place(aba, (0, 0.004, hz - 0.01)), paint='couro', bone='hat')
    B.piece(place(loft([(0, 0.21, 0.2, 0, 2.0), (0.028, 0.211, 0.201, 0, 2.0)], seg_n=14), (0, 0.004, hz + 0.02)), paint='ferro', bone='hat', mat='metal', oline=0.7)
    for a in range(0, 360, 45):
        t = math.radians(a)
        B.piece(place(mk('sphere', u=6, v=4), (0.212 * math.sin(t), 0.004 + 0.202 * math.cos(t), hz + 0.034), (0.012, 0.012, 0.012)), paint='latao', bone='hat', mat='metal', oline=0.5)
    # castiçal de ferro, vela grossa com escorridos e a chama (mola de 6 quadros de atraso no motor)
    cz = hz + 0.205
    B.piece(place(mk('cyl', seg=10, r2=1.3), (0, 0.004, cz + 0.01), (0.045, 0.045, 0.02)), paint='ferro', bone='hat', mat='metal')
    B.piece(place(mk('cyl', seg=10), (0, 0.004, cz + 0.08), (0.032, 0.032, 0.055)), paint='cera', bone='hat')
    for i, (dx, dy, L) in enumerate(((0.03, -0.01, 0.05), (-0.022, -0.022, 0.035), (0.005, 0.03, 0.045))):
        B.piece(tube([(dx, dy + 0.004, cz + 0.13), (dx * 1.15, dy * 1.15 + 0.004, cz + 0.13 - L)], [0.01, 0.007], seg_n=6), paint='cera', bone='hat', oline=0.6)
    B.piece(limb((0, 0.004, cz + 0.13), (0, 0.004, cz + 0.155), 0.004, 0.004, seg_n=4, rings=2), paint='tinta', bone='hat', hull=False)
    chama(B, (0, 0.004, cz + 0.15), 'chama', k=1.25)
    B.glows.append((head_xf(B, (0, 0.0, cz + 0.17)), 0.42, 'resina', 0.75))
    # pescoço curto e grosso, lenço de pescoço
    B.piece(limb((0, 0, S['neck'] - 0.03), (0, 0, S['headb'] + 0.03), 0.055, 0.055, seg_n=8, rings=2), paint='pele', bone='neck')
    B.piece(place(torus(0.085, 0.03, 14, 6), (0, 0, S['neck'] - 0.01)), paint='ambar_esc', bone='chest')
    # ombreiras de tábua amarrada (3 tábuas por ombro)
    for s, sx in (('L', 1), ('R', -1)):
        sh, el = J(bones, 'upperarm.' + s)
        for k in range(3):
            B.piece(bevel_box(sh + Vector((sx * (0.02 + 0.01 * k), -0.05 + 0.05 * k, 0.03 - 0.012 * k)), (0.06, 0.024, 0.009), 0.004, rot=(0, sx * -28, 0)),
                    paint='madeira_clara', bone='upperarm.' + s, sub=False, oline=0.8)
        B.piece(place(torus(0.055, 0.008, 12, 5), sh + Vector((sx * 0.01, 0, 0.0)), (1, 1, 1)), paint='corda', bone='upperarm.' + s, oline=0.5)
        arm_pieces(B, bones, S, s, 'ambar', 'pele', pose='fist', glove='couro_claro')
        leg_pieces(B, bones, S, s, 'lona_esc', 'couro')
    # saco de cal na cintura (solta pó quando corre)
    sa, sb = J(bones, 'saco')
    sk = loft([(0.0, 0.03, 0.03, 0, 2.0), (0.03, 0.065, 0.06, 0, 2.0), (0.09, 0.07, 0.065, 0, 2.0), (0.13, 0.04, 0.04, 0, 2.0), (0.15, 0.018, 0.018, 0, 2.0)], seg_n=10)
    for v in sk.verts:
        v.co += Vector((0.006 * math.sin(v.co.z * 40), 0.006 * math.cos(v.co.z * 33), 0))
    B.piece(place(sk, sb + Vector((0.0, -0.01, -0.035))), paint='cal', bone='saco', jitter=0.003)
    B.piece(place(torus(0.022, 0.007, 10, 5), sb + Vector((0, -0.01, 0.1))), paint='corda', bone='saco', oline=0.5)
    # A VIGA: escora de madeira duas vezes mais comprida que ele, atravessada nos ombros (o T)
    va, vb = J(bones, 'viga')
    L = 1.7
    B.piece(bevel_box((0.0, va.y, va.z + 0.0), (L / 2, 0.06, 0.065), 0.014), paint='madeira_clara', bone='viga', sub=False, jitter=0.0)
    # veios e lascas da madeira (cortes de faca), pontas cortadas em chanfro e uma cinta de ferro
    rr = random.Random(7)
    for k in range(7):
        x = rr.uniform(-0.8, 0.8)
        B.piece(bevel_box((x, va.y + rr.choice((-1, 1)) * 0.061, va.z + rr.uniform(-0.03, 0.03)), (rr.uniform(0.05, 0.14), 0.002, 0.004), 0.001),
                paint='couro', bone='viga', sub=False, hull=False)
    for sxx in (-1, 1):
        B.piece(place(loft([(0, 0.07, 0.07, 0, 4.0), (0.035, 0.07, 0.07, 0, 4.0)], seg_n=12, phase=0.785), (sxx * 0.62, va.y, va.z), (1, 1, 1)), paint='ferro', bone='viga', mat='metal', oline=0.7, sub=False)
        xform_box = bevel_box((sxx * 0.62, va.y, va.z), (0.03, 0.07, 0.072), 0.004)
        B.piece(xform_box, paint='ferro', bone='viga', mat='metal', sub=False, oline=0.7)
    # pó de cal grudado nos ombros e nas botas: imperfeição com causa
    for s, sx in (('L', 1), ('R', -1)):
        B.piece(place(mk('sphere', u=6, v=4), (sx * 0.06, -0.06, 0.04), (0.04, 0.03, 0.012)), paint='cal', bone='foot.' + s, oline=0.0, hull=False)
    cabeca_ossos(B)
    return B

# ================================================================== CRISTALEIRA (maga, Cobalto): chapéu de geodo e túnica que arrasta
def build_cristaleira():
    S = dict(hip=0.22, waist=0.28, chest=0.37, neck=0.45, headb=0.46, headt=0.83, shz=0.43, shw=0.1, ua=0.1, ua_out=0.02,
             fa=0.09, hs=0.82, legx=0.05, knee=0.12, ankle=0.035, arm_r=0.026, leg_r=0.03, boot_k=1.0)
    hb = S['headb']
    S['extra'] = [('chapeu2', (0, 0.06, hb + 0.56), (0, 0.12, hb + 0.68), 'hat'),
                  ('geodo', (0, 0.13, hb + 0.71), (0, 0.15, hb + 0.61), 'chapeu2'),
                  ('barra', (0, 0.05, 0.2), (0, 0.12, 0.02), 'hips'),
                  ('manga.L', (0.12, 0, 0.32), (0.15, -0.01, 0.2), 'forearm.L'), ('manga.R', (-0.12, 0, 0.32), (-0.15, -0.01, 0.2), 'forearm.R')]
    bones = hero_bones(S)
    B = Builder(222, [b[0] for b in bones], outline=0.006)
    B.bones = bones; B.S = S; B.wash = 'azul_negro'
    B.remap = {'pele': 'pele_cristaleira'}
    cabeca_grande(B, S, ['head', 'hat', 'chapeu2', 'geodo'], k=1.0)
    # TÚNICA que arrasta: cone do peito ao chão, barra rasgada e molhada; os pés nunca aparecem
    rings = [(0.0, 0.215, 0.235, 0.045, 2.0), (0.04, 0.2, 0.2, 0.03, 2.0), (0.14, 0.165, 0.15, 0.012, 2.1), (0.26, 0.135, 0.115, 0.0, 2.2),
             (0.36, 0.13, 0.1, 0.0, 2.3), (0.44, 0.1, 0.08, 0.0, 2.2), (0.47, 0.05, 0.05, 0.0, 2.0)]
    rb = loft(rings, seg_n=16, cap_bot=True, phase=0.2)
    for v in rb.verts:
        if v.co.z < 0.05:
            a = math.atan2(v.co.x, v.co.y)
            v.co.z = max(0.0, v.co.z + 0.035 * abs(math.sin(a * 3.5)) ** 2 - 0.004)
    def wt(co):
        if co.z > S['waist'] + 0.02:
            return {'chest': 1.0}
        if co.z > 0.18:
            return {'hips': 1.0}
        t = min(1.0, (0.18 - co.z) / 0.16)
        return {'hips': 1 - 0.6 * t, 'barra': 0.6 * t}
    B.piece(rb, paint='cobalto', weights=wt, jitter=0.003)
    # faixa de quartzo no peito e cinto de corda com bolsas de lasca
    B.piece(place(loft([(0, 0.142, 0.118, 0, 2.3), (0.03, 0.142, 0.118, 0, 2.3)], seg_n=14), (0, 0, S['waist'] - 0.04)), paint='corda_esc', bone='hips', oline=0.6)
    B.piece(place(mk('sphere', u=7, v=5), (-0.11, -0.07, S['waist'] - 0.06), (0.045, 0.035, 0.05)), paint='couro', bone='hips')
    # capinha curta nos ombros (cobalto escuro) com gola alta: postura orgulhosa
    cp = shell([(S['shz'] + 0.04, 0.09, 0.075, 0.0), (S['shz'] - 0.02, 0.15, 0.12, 0.0), (S['shz'] - 0.1, 0.17, 0.14, 0.01)], -180, 180, thick=0.012, seg=14)
    for v in cp.verts:
        if v.co.z < S['shz'] - 0.08:
            v.co.z += 0.018 * math.sin(math.atan2(v.co.x, v.co.y) * 6)
    B.piece(cp, paint='cobalto_esc', bone='chest', jitter=0.002)
    # cabeça, rosto vaidoso (sobrancelha arqueada, sorriso de canto)
    z0 = hb
    B.piece(place(loft(HEAD_RINGS, seg_n=12), (0, 0, z0)), paint='pele', bone='head', jitter=0.002)
    face(B, S, HEAD_RINGS, z0, eye_z=0.13, eye_w=0.08, eye_h=0.088, eye_x=0.064, mouth='torta', brow='safado', mouth_w=0.045, brow_col='ruivo')
    # cabelo ruivo: franja e duas mechas grossas que emolduram o rosto
    for sx in (-1, 1):
        B.piece(tube([(sx * 0.14, -0.1, z0 + 0.3), (sx * 0.19, -0.07, z0 + 0.17), (sx * 0.17, -0.09, z0 + 0.02), (sx * 0.13, -0.11, z0 - 0.04)],
                     [0.045, 0.05, 0.04, 0.02], seg_n=8), paint='ruivo', bone='head', jitter=0.003)
    fr = shell([(z0 + 0.31, 0.17, 0.16, 0.0), (z0 + 0.26, 0.185, 0.17, 0.0)], 120, 240, thick=0.02, seg=8)
    for v in fr.verts:
        a = math.atan2(v.co.x, v.co.y)
        if v.co.z < z0 + 0.27:
            v.co.z -= 0.03 * abs(math.sin(a * 5))
    B.piece(fr, paint='ruivo', bone='head', jitter=0.002)
    # CHAPÉU PONTUDO cuja ponta é um geodo aberto: aba larga, copa alta que cai para trás com o peso da pedra
    bz = z0 + 0.28
    aba = loft([(0, 0.3, 0.29, 0.01, 2.0), (0.012, 0.3, 0.29, 0.01, 2.0), (0.026, 0.22, 0.21, 0.01, 2.0)], seg_n=18)
    for v in aba.verts:
        a = math.atan2(v.co.x, v.co.y)
        v.co.z += 0.03 * math.cos(a) + 0.012 * math.sin(a * 3)   # a aba sobe atrás e ondula
    B.piece(place(aba, (0, 0, bz)), paint='cobalto_esc', bone='hat', jitter=0.002)
    cone = loft([(0.0, 0.2, 0.19, 0.0, 2.0), (0.06, 0.185, 0.175, 0.005, 2.0), (0.16, 0.14, 0.135, 0.02, 2.0), (0.26, 0.1, 0.095, 0.045, 2.0),
                 (0.33, 0.075, 0.07, 0.07, 2.0)], seg_n=14, cap_bot=False)
    B.piece(place(cone, (0, 0, bz)), paint='cobalto', weights=lambda co: {'hat': 1.0} if co.z < bz + 0.22 else {'hat': 0.4, 'chapeu2': 0.6}, jitter=0.003, xfb='hat')
    ponta = loft([(0.0, 0.075, 0.07, 0.0, 2.0), (0.05, 0.065, 0.062, 0.02, 2.0), (0.1, 0.06, 0.058, 0.05, 2.0), (0.12, 0.05, 0.05, 0.065, 2.0)], seg_n=14, cap_bot=False, cap_top=True)
    B.piece(place(ponta, (0, 0.07, bz + 0.33)), paint='cobalto', weights=lambda co: {'hat': 0.3, 'chapeu2': 0.7} if co.z < bz + 0.37 else {'chapeu2': 1.0}, jitter=0.003, xfb='hat')
    B.piece(place(loft([(0, 0.19, 0.18, 0.004, 2.0), (0.035, 0.19, 0.18, 0.004, 2.0)], seg_n=14), (0, 0, bz + 0.02)), paint='couro', bone='hat', oline=0.6)
    B.piece(bevel_box((0, -0.18, bz + 0.04), (0.03, 0.012, 0.025), 0.004), paint='latao', bone='hat', mat='metal', oline=0.6, sub=False)
    # o GEODO: casca de pedra escura aberta, cheia de cristais acesos
    ga, gb = J(bones, 'geodo')
    gc = Vector((0, 0.14, bz + 0.48))
    # casca de pedra escura (ovo quebrado no alto) e uma drusa de cristais acesos saindo pela fratura
    egg = loft([(0.0, 0.0, 0.0, 0, 2.0), (0.02, 0.05, 0.048, 0, 2.0), (0.06, 0.08, 0.076, 0, 2.0), (0.1, 0.085, 0.08, 0, 2.0), (0.12, 0.075, 0.07, 0, 2.0)],
               seg_n=12, cap_bot=False, cap_top=False)
    rr = random.Random(3)
    for v in egg.verts:
        if v.co.z > 0.11:
            v.co.z += rr.uniform(-0.02, 0.012)
        v.co.x += rr.uniform(-0.005, 0.005); v.co.y += rr.uniform(-0.005, 0.005)
    bmesh.ops.solidify(egg, geom=egg.faces[:], thickness=-0.012)
    Mg = Matrix.Translation(gc + Vector((0, 0, -0.1))) @ Matrix.Rotation(math.radians(-25), 4, 'X') @ Matrix.Diagonal((1.45, 1.45, 1.45, 1))
    B.piece(xform(egg, Mg.copy()), paint='ardosia', bone='geodo', jitter=0.004)
    for k in range(11):
        a = 2 * math.pi * k / 11 + rr.uniform(-0.2, 0.2)
        rk = 0.0 if k == 0 else (0.05 if k % 2 else 0.028)
        base = Vector((math.cos(a) * rk, math.sin(a) * rk, 0.07))
        d = Vector((math.cos(a) * rk * 9, math.sin(a) * rk * 9, 1)).normalized()
        L = 0.14 if k == 0 else rr.uniform(0.06, 0.1)
        wd = 0.024 if k == 0 else 0.017
        cr = loft([(0.0, wd, wd, 0, 1.2), (L * 0.72, wd, wd, 0, 1.2), (L, 0.0, 0.0, 0, 1.2)], seg_n=6, phase=rr.uniform(0, 1))
        q = Vector((0, 0, 1)).rotation_difference(d)
        B.piece(xform(cr, Mg @ Matrix.Translation(base) @ q.to_matrix().to_4x4()), paint='geodo', bone='geodo', mat='emis', hull=False, sub=False)
    B.glows.append((head_xf(B, gc + Vector((0, 0, -0.05))), 0.3, 'dourado', 0.55))
    # pescoço fino e colar de lascas de quartzo
    B.piece(limb((0, 0, S['neck'] - 0.03), (0, 0, hb + 0.03), 0.036, 0.036, seg_n=7, rings=2), paint='pele', bone='neck')
    for k in range(7):
        a = math.radians(-60 + 20 * k)
        p = Vector((math.sin(a) * 0.07, -math.cos(a) * 0.06, S['neck'] - 0.03))
        cr = loft([(0, 0.01, 0.01, 0, 1.4), (0.025, 0.009, 0.009, 0, 1.4), (0.04, 0.0, 0.0, 0, 1.4)], seg_n=5)
        B.piece(xform(cr, Matrix.Translation(p) @ Matrix.Rotation(math.pi, 4, 'X') @ Matrix.Rotation(-a * 0.3, 4, 'Y')), paint='quartzo', bone='chest', oline=0.6, sub=False)
    # braços com mangas em sino
    for s, sx in (('L', 1), ('R', -1)):
        arm_pieces(B, bones, S, s, 'cobalto', 'pele', pose='fist' if s == 'R' else 'open', glove='pele')
        el, wr = J(bones, 'forearm.' + s)
        m = loft([(0, 0.045, 0.045, 0, 2.0), (0.06, 0.07, 0.068, 0.0, 2.0), (0.1, 0.085, 0.082, -0.005, 2.0)], seg_n=12, cap_bot=False, cap_top=False)
        bmesh.ops.solidify(m, geom=m.faces[:], thickness=0.01)
        q = Vector((0, 0, 1)).rotation_difference((wr - el).normalized())
        B.piece(xform(m, Matrix.Translation(el) @ q.to_matrix().to_4x4()), paint='cobalto_esc', weights=lambda co, s=s, el=el: {'forearm.' + s: 0.5, 'manga.' + s: 0.5}, jitter=0.002)
    # CAJADO de quartzo bruto (osso prop): cabo torto de raiz e drusa no alto
    ph, pt = J(bones, 'prop')
    base = ph + Vector((0, -0.015, -0.32))
    B.piece(tube([base, base + Vector((0.01, 0, 0.3)), base + Vector((-0.01, 0.005, 0.6)), base + Vector((0.012, 0, 0.82))], [0.018, 0.02, 0.019, 0.024], seg_n=7),
            paint='madeira', bone='prop', jitter=0.002)
    top = base + Vector((0.012, 0, 0.84))
    for k in range(5):
        a = 2 * math.pi * k / 5
        d = Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, 1)).normalized()
        L = 0.09 if k else 0.13
        cr = loft([(0.0, 0.022, 0.022, 0, 1.2), (L * 0.75, 0.022, 0.022, 0, 1.2), (L, 0.0, 0.0, 0, 1.2)], seg_n=6)
        B.piece(xform(cr, Matrix.Translation(top) @ Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()), paint='quartzo', bone='prop', sub=False, oline=0.7)
    for k in range(3):
        B.piece(place(torus(0.026, 0.006, 10, 4), base + Vector((0.01, 0, 0.72 + 0.03 * k))), paint='corda', bone='prop', oline=0.5)
    cabeca_ossos(B)
    return B

# ================================================================== COVEIRA (clériga, Branco-giz): aba larga com véu, pá enorme e turíbulo
def build_coveira():
    S = dict(hip=0.2, waist=0.27, chest=0.36, neck=0.44, headb=0.45, headt=0.82, shz=0.42, shw=0.11, ua=0.1, ua_out=0.02,
             fa=0.09, hs=0.86, legx=0.055, knee=0.11, ankle=0.035, arm_r=0.03, leg_r=0.032, boot_k=1.05)
    S['extra'] = [('veu', (0, 0.17, 0.74), (0, 0.2, 0.52), 'head'),
                  ('etiquetas', (0.12, -0.05, 0.24), (0.13, -0.06, 0.14), 'hips')]
    bones = hero_bones(S)
    # a pá vai no osso prop (mão direita), em pé; a corrente e o turíbulo pendem do cabo em T, no alto
    ph, pt = J(bones, 'prop')
    grip = ph + Vector((-0.07, 0.03, 0.62))
    bones += [('corrente', tuple(grip + Vector((-0.08, 0.0, 0.0))), tuple(grip + Vector((-0.09, 0.0, -0.22))), 'prop'),
              ('turibulo', tuple(grip + Vector((-0.09, 0.0, -0.22))), tuple(grip + Vector((-0.09, 0.0, -0.32))), 'corrente')]
    B = Builder(333, [b[0] for b in bones], outline=0.006)
    B.bones = bones; B.S = S; B.wash = 'azul_negro'
    B.remap = {'pele': 'pele_coveira', 'rubor': 'pele_coveira'}
    cabeca_grande(B, S, ['head', 'hat', 'veu'])
    # sobretudo preto até a canela, avental de terra por cima
    rings = [(0.0, 0.17, 0.16, 0.02, 2.0), (0.1, 0.15, 0.135, 0.01, 2.1), (0.2, 0.135, 0.11, 0.0, 2.2), (0.3, 0.13, 0.1, 0.0, 2.3), (0.4, 0.12, 0.09, 0.0, 2.3),
             (0.45, 0.07, 0.06, 0.0, 2.0)]
    co_ = loft(rings, seg_n=14, phase=0.2)
    for v in co_.verts:
        if v.co.z < 0.02:
            v.co.z = 0.05 + 0.02 * math.sin(math.atan2(v.co.x, v.co.y) * 4)
    def wt(co):
        if co.z > S['waist'] + 0.02:
            return {'chest': 1.0}
        if co.z > 0.16:
            return {'hips': 1.0}
        return {'hips': 0.5, 'thigh.L': 0.25, 'thigh.R': 0.25}
    B.piece(co_, paint='gesso', weights=wt, jitter=0.003)
    av = shell([(S['chest'] + 0.02, 0.11, 0.1, -0.006), (S['waist'], 0.14, 0.12, -0.008), (0.12, 0.16, 0.14, -0.012), (0.07, 0.165, 0.145, -0.015)], 130, 230, thick=0.01, seg=8)
    B.piece(av, paint='terra', weights=lambda co: {'hips': 1.0} if co.z < S['waist'] else {'chest': 1.0}, jitter=0.003)
    cinto(B, S, 'couro', larg=1.12)
    # molho de etiquetas de defunto no cinto
    ea, eb = J(bones, 'etiquetas')
    rr = random.Random(9)
    for k in range(5):
        B.piece(bevel_box(eb + Vector((rr.uniform(-0.02, 0.02), -0.01 * k, rr.uniform(-0.03, 0.02))), (0.022, 0.003, 0.032), 0.002, rot=(0, rr.uniform(-25, 25), 90 + rr.uniform(-20, 20))),
                paint='osso', bone='etiquetas', sub=False, oline=0.6)
    B.piece(limb(ea, eb, 0.006, 0.006, seg_n=4, rings=2), paint='corda', bone='etiquetas', oline=0.5)
    # cabeça: calma e seca (olhos meio fechados no shader, boca reta)
    z0 = S['headb']
    B.piece(place(loft(HEAD_RINGS, seg_n=12), (0, 0, z0)), paint='pele', bone='head', jitter=0.002)
    face(B, S, HEAD_RINGS, z0, eye_z=0.125, eye_w=0.072, eye_h=0.074, eye_x=0.064, mouth='reta', brow='calma', mouth_w=0.035, brow_col='cabelo', blush=False)
    # olheiras fundas de quem vela os mortos
    for sx in (-1, 1):
        po_, no_ = front_pt(HEAD_RINGS, sx * 0.064, 0.075, z0)
        B.piece(disc(po_ + no_ * 0.003, no_, 0.04, seg=10, sx=1.0, sy=0.35), paint='olheira', bone='head', hull=False, sub=False)
    # cabelo preso em coque baixo, preto
    hr = shell([(z0 + 0.34, 0.12, 0.11, 0.01), (z0 + 0.28, 0.185, 0.17, 0.01), (z0 + 0.17, 0.198, 0.18, 0.01), (z0 + 0.08, 0.17, 0.16, 0.01)], -110, 110, thick=0.02, seg=12)
    B.piece(hr, paint='cabelo', bone='head', jitter=0.002)
    B.piece(place(mk('sphere', u=8, v=6), (0, 0.17, z0 + 0.09), (0.07, 0.06, 0.06)), paint='cabelo', bone='head')
    # CHAPÉU DE ABA LARGA: aba mais larga que os ombros, copa baixa, fita de giz
    bz = z0 + 0.29
    aba = loft([(0, 0.36, 0.34, 0.0, 2.0), (0.012, 0.36, 0.34, 0.0, 2.0), (0.024, 0.22, 0.21, 0.0, 2.0)], seg_n=20)
    for v in aba.verts:
        a = math.atan2(v.co.x, v.co.y)
        r = math.hypot(v.co.x, v.co.y)
        v.co.z -= 0.035 * max(0.0, r - 0.2) / 0.16 * (0.6 + 0.4 * math.cos(a * 2))   # aba que cai dos lados
    B.piece(place(aba, (0, 0, bz)), paint='preto_pano', bone='hat', jitter=0.002)
    copa = loft([(0.0, 0.2, 0.19, 0, 2.2), (0.1, 0.18, 0.17, 0, 2.2), (0.13, 0.15, 0.14, 0, 2.2), (0.14, 0.0, 0.0, 0, 2.0)], seg_n=16, cap_bot=False)
    B.piece(place(copa, (0, 0, bz + 0.01)), paint='preto_pano', bone='hat', jitter=0.002)
    B.piece(place(loft([(0, 0.205, 0.195, 0, 2.2), (0.04, 0.2, 0.19, 0, 2.2)], seg_n=16), (0, 0, bz + 0.015)), paint='giz', bone='hat', oline=0.6)
    # VÉU de giz: cai da aba pelas costas e pelos lados, deixando o rosto à mostra
    vz = bz - 0.01
    veu = shell([(vz, 0.25, 0.24, 0.0), (vz - 0.12, 0.23, 0.23, 0.03), (vz - 0.26, 0.21, 0.22, 0.06), (vz - 0.38, 0.2, 0.21, 0.08)], -105, 105, thick=0.008, seg=14)
    for v in veu.verts:
        a = math.atan2(v.co.x, v.co.y)
        lift = max(0.0, abs(a) - 0.9) * 0.28   # nos lados o véu é mais curto: o rosto fica livre
        if v.co.z < vz - 0.05:
            v.co.z += lift * (vz - v.co.z) / 0.38 * 1.0 + 0.025 * abs(math.sin(a * 5)) * ((vz - v.co.z) / 0.38)
    def wv(co):
        t = (vz - co.z) / 0.36
        return {'head': 1 - min(1.0, t * 1.2) * 0.8, 'veu': min(1.0, t * 1.2) * 0.8}
    B.piece(veu, paint='giz', weights=wv, jitter=0.002, xfb='head')
    B.piece(limb((0, 0, S['neck'] - 0.03), (0, 0, z0 + 0.03), 0.038, 0.038, seg_n=7, rings=2), paint='pele', bone='neck')
    # gola alta branca de sacristia
    B.piece(place(loft([(0, 0.075, 0.07, 0, 2.0), (0.05, 0.09, 0.085, 0, 2.0)], seg_n=12, cap_bot=False, cap_top=False), (0, 0, S['neck'] - 0.04)), paint='giz', bone='chest', oline=0.7)
    for s in ('L', 'R'):
        arm_pieces(B, bones, S, s, 'gesso', 'pele', pose='fist', glove='giz_esc')
        leg_pieces(B, bones, S, s, 'preto_pano', 'couro')
    # A PÁ maior que ela: lâmina de ferro no chão, cabo de 1,15 m, punho em T no alto
    bot = ph + Vector((-0.07, 0.03, -0.33))
    B.piece(tube([bot, bot + Vector((0.004, 0, 0.5)), grip], [0.017, 0.018, 0.018], seg_n=7), paint='madeira', bone='prop', jitter=0.002)
    B.piece(limb(grip + Vector((0.07, 0, 0)), grip + Vector((-0.09, 0, 0)), 0.022, 0.022, seg_n=7, rings=2), paint='madeira_clara', bone='prop')
    bl = loft([(0.0, 0.11, 0.012, 0, 3.0), (0.14, 0.12, 0.014, 0, 3.0), (0.2, 0.06, 0.02, 0, 2.2), (0.23, 0.03, 0.02, 0, 2.0)], seg_n=12)
    for v in bl.verts:
        v.co.y += 0.03 * (1 - min(1.0, v.co.z / 0.2)) * (1 - (v.co.x / 0.12) ** 2)   # concha
    B.piece(place(bl, bot + Vector((0, 0, -0.205)), (1, 1, 1), (180, 0, 0)), paint='ferro', bone='prop', mat='metal', jitter=0.002)
    B.piece(place(bl.copy() if False else loft([(0, 0.02, 0.02, 0, 2.0), (0.06, 0.024, 0.024, 0, 2.0)], seg_n=8), bot + Vector((0, 0, -0.04))), paint='ferro', bone='prop', mat='metal', oline=0.7)
    # TURÍBULO de bronze: corrente de elos e globo furado com brasas
    ca, cb = J(bones, 'corrente')
    for k in range(6):
        t = k / 5
        p = ca + (cb - ca) * t
        B.piece(xform(torus(0.012, 0.004, 8, 4), Matrix.Translation(p) @ Matrix.Rotation(math.pi / 2 * (k % 2), 4, 'Z') @ Matrix.Rotation(math.pi / 2, 4, 'X')),
                paint='bronze', bone='corrente', mat='metal', oline=0.4, sub=False)
    ta, tb = J(bones, 'turibulo')
    tc = ta + Vector((0, 0, -0.075))
    glob = loft([(0.0, 0.0, 0.0, 0, 2.0), (0.02, 0.045, 0.045, 0, 2.0), (0.06, 0.065, 0.065, 0, 2.0), (0.09, 0.058, 0.058, 0, 2.0), (0.1, 0.04, 0.04, 0, 2.0)], seg_n=12, cap_bot=False)
    B.piece(place(glob, tc + Vector((0, 0, -0.05))), paint='bronze', bone='turibulo', mat='metal')
    lid = loft([(0.0, 0.045, 0.045, 0, 2.0), (0.03, 0.04, 0.04, 0, 2.0), (0.05, 0.015, 0.015, 0, 2.0), (0.06, 0.0, 0.0, 0, 2.0)], seg_n=12)
    B.piece(place(lid, tc + Vector((0, 0, 0.05))), paint='bronze', bone='turibulo', mat='metal')
    for k in range(6):
        a = 2 * math.pi * k / 6
        B.piece(place(mk('sphere', u=6, v=4), tc + Vector((math.cos(a) * 0.06, math.sin(a) * 0.06, 0.0)), (0.016, 0.016, 0.012)), paint='forja', bone='turibulo', mat='emis', hull=False)
    B.piece(place(mk('sphere', u=7, v=5), tc + Vector((0, 0, 0.035)), (0.04, 0.04, 0.02)), paint='forja', bone='turibulo', mat='emis', hull=False)
    cabeca_ossos(B)
    return B

# ================================================================== GANCHEIRO (ladino, Verde-veneno): rolo de corda nas costas, gancho e capuz de duas pontas
def build_gancheiro():
    S = dict(hip=0.18, waist=0.24, chest=0.34, neck=0.41, headb=0.42, headt=0.79, shz=0.39, shw=0.11, ua=0.09, ua_out=0.03,
             fa=0.085, hs=0.86, legx=0.058, knee=0.1, ankle=0.035, arm_r=0.027, leg_r=0.026, boot_k=1.42)
    S['extra'] = [('rolo', (0, 0.12, 0.33), (0, 0.16, 0.6), 'chest'),
                  ('gancho', (-0.16, 0.22, 0.3), (-0.17, 0.23, 0.16), 'rolo'),
                  ('ponta.L', (0.1, 0.12, 0.78), (0.2, 0.26, 0.9), 'head'), ('ponta.R', (-0.1, 0.12, 0.78), (-0.2, 0.26, 0.9), 'head'),
                  ('adaga', (0.14, -0.06, 0.15), (0.18, -0.08, 0.02), 'hand.L')]
    bones = hero_bones(S)
    B = Builder(444, [b[0] for b in bones], outline=0.006)
    B.bones = bones; B.S = S; B.wash = 'lavagem'
    B.remap = {'pele': 'pele_gancheiro'}
    cabeca_grande(B, S, ['head', 'hat', 'ponta.L', 'ponta.R'], k=1.04)
    torso(B, S, 'couro_claro', k_ombro=0.95, k_barriga=0.95)
    # colete curto verde-veneno por cima
    cv = shell([(S['shz'] + 0.02, 0.1, 0.085, 0.0), (S['chest'], 0.135, 0.11, 0.0), (S['waist'] - 0.02, 0.13, 0.11, 0.0)], -150, 150, thick=0.012, seg=12)
    B.piece(cv, paint='veneno', weights=lambda co: {'chest': 1.0} if co.z > S['waist'] + 0.03 else {'hips': 0.5, 'chest': 0.5}, jitter=0.002)
    cinto(B, S, 'couro', larg=1.05)
    # frascos de resina (Visgo) no cinto
    for k, x in enumerate((0.09, 0.03, -0.06)):
        p = Vector((x, -0.12, S['waist'] - 0.04))
        B.piece(place(mk('cyl', seg=8, r2=0.7), p, (0.022, 0.022, 0.032)), paint='resina', bone='hips', oline=0.7)
        B.piece(place(mk('cyl', seg=6), p + Vector((0, 0, 0.04)), (0.01, 0.01, 0.01)), paint='madeira', bone='hips', oline=0.5)
    z0 = S['headb']
    B.piece(place(loft(HEAD_RINGS, seg_n=12), (0, 0, z0)), paint='pele', bone='head', jitter=0.002)
    face(B, S, HEAD_RINGS, z0, eye_z=0.13, eye_w=0.084, eye_h=0.09, eye_x=0.064, mouth='torta', brow='safado', mouth_w=0.055)
    # cicatriz que corta a sobrancelha e a bochecha esquerda
    pa_, na_ = front_pt(HEAD_RINGS, 0.045, 0.21, z0); pb_, nb_ = front_pt(HEAD_RINGS, 0.1, 0.05, z0)
    B.piece(tube([pa_ + na_ * 0.004, (pa_ + pb_) / 2 + (na_ + nb_) * 0.004, pb_ + nb_ * 0.004], [0.006, 0.007, 0.004], seg_n=5), paint='cicatriz', bone='head', hull=False, oline=0.0)
    # CAPUZ de duas pontas (a "rosca com orelhas")
    rows = [(-0.03, 0.17, 0.16, 0.03, 44), (0.08, 0.21, 0.195, 0.02, 40), (0.2, 0.22, 0.205, 0.01, 34), (0.28, 0.215, 0.2, 0.015, 3), (0.36, 0.18, 0.17, 0.02, 0.5),
            (0.42, 0.11, 0.11, 0.03, 0.5), (0.45, 0.03, 0.03, 0.04, 0.5)]
    cp = shell(rows, -150, 150, thick=0.016, seg=18)
    for v in cp.verts:
        if v.co.y < -0.08 and 0.2 < v.co.z < 0.38:
            v.co.y -= 0.045 * min(1.0, (v.co.z - 0.2) / 0.08)
    B.piece(place(cp, (0, 0.0, z0)), paint='veneno', bone='head', jitter=0.002)
    inner = shell([(0.05, 0.2, 0.19, 0.03), (0.2, 0.21, 0.2, 0.02), (0.32, 0.18, 0.17, 0.03)], -146, 146, thick=0.006, seg=16)
    B.piece(place(inner, (0, 0.0, z0)), paint='veneno_esc', bone='head', hull=False)
    for s in ('L', 'R'):
        a, b = J(bones, 'ponta.' + s)
        ear = loft([(0.0, 0.06, 0.04, 0, 2.0), (0.08, 0.05, 0.034, 0, 2.0), (0.15, 0.03, 0.022, 0, 2.0), (0.2, 0.012, 0.01, 0, 2.0), (0.22, 0.0, 0.0, 0, 2.0)], seg_n=8)
        q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
        B.piece(xform(ear, Matrix.Translation(a) @ q.to_matrix().to_4x4()), paint='veneno', weights=lambda co, s=s, a=a: {'head': 0.4, 'ponta.' + s: 0.6} if (co - a).length < 0.05 else {'ponta.' + s: 1.0}, jitter=0.002, xfb='head')
    B.piece(limb((0, 0, S['neck'] - 0.03), (0, 0, S['headb'] + 0.03), 0.034, 0.034, seg_n=7, rings=2), paint='pele', bone='neck')
    for s in ('L', 'R'):
        arm_pieces(B, bones, S, s, 'couro_claro', 'pele', pose='fist', glove='couro')
        leg_pieces(B, bones, S, s, 'lona_esc', 'couro')
    # O ROLO DE CORDA nas costas: rosca maior que o tronco, com a espiral da corda
    ra, rb_ = J(bones, 'rolo')
    rc = Vector((0, 0.17, 0.47))
    rolo = torus(0.2, 0.085, 36, 10, groove=18, gk=0.16)
    B.piece(xform(rolo, Matrix.Translation(rc) @ Matrix.Rotation(math.radians(80), 4, 'X')), paint='corda', bone='rolo', jitter=0.002)
    # amarras do rolo
    for sx in (1, -1):
        B.piece(tube([(sx * 0.09, -0.085, 0.38), (sx * 0.11, 0.03, 0.43), (sx * 0.12, 0.12, 0.47)], [0.011] * 3, seg_n=5), paint='couro', bone='chest', oline=0.5)
    # O GANCHO de ferro pendurado na ponta da corda
    ga, gb = J(bones, 'gancho')
    B.piece(tube([ga, ga + Vector((0, 0.01, -0.06))], [0.012, 0.012], seg_n=6), paint='corda', bone='gancho', oline=0.5)
    gc = ga + Vector((0, 0.01, -0.07))
    B.piece(limb(gc, gc + Vector((0, 0, -0.06)), 0.014, 0.014, seg_n=6, rings=2), paint='ferro', bone='gancho', mat='metal')
    for sx in (1, -1):
        B.piece(tube([gc + Vector((0, 0, -0.06)), gc + Vector((sx * 0.05, 0, -0.08)), gc + Vector((sx * 0.07, 0, -0.03)), gc + Vector((sx * 0.06, 0, 0.0))],
                     [0.013, 0.012, 0.01, 0.004], seg_n=6), paint='ferro', bone='gancho', mat='metal')
    # punhais: um na mão direita (osso prop) e outro invertido na esquerda
    def punhal(p0, d, bone, L=0.17):
        d = Vector(d).normalized()
        blade = loft([(0.0, 0.024, 0.006, 0, 2.0), (L * 0.55, 0.022, 0.005, 0, 2.0), (L, 0.0, 0.0, 0, 2.0)], seg_n=6)
        q = Vector((0, 0, 1)).rotation_difference(d)
        B.piece(xform(blade, Matrix.Translation(p0) @ q.to_matrix().to_4x4()), paint='ferro', bone=bone, mat='metal', oline=0.8, sub=False)
        B.piece(limb(p0 - d * 0.06, p0, 0.014, 0.014, seg_n=6, rings=2), paint='couro', bone=bone, oline=0.6)
        gx = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized()
        B.piece(limb(p0 - gx * 0.04, p0 + gx * 0.04, 0.01, 0.01, seg_n=5, rings=2), paint='latao', bone=bone, mat='metal', oline=0.6)
    ph, pt = J(bones, 'prop')
    punhal(ph + Vector((0, -0.02, 0)), Vector((0, -1, 0.15)), 'prop')
    a, b = J(bones, 'adaga')
    punhal(a, b - a, 'adaga', L=0.15)
    cabeca_ossos(B)
    return B

HEROES = {'escorador': build_escorador, 'cristaleira': build_cristaleira, 'coveira': build_coveira, 'gancheiro': build_gancheiro}

# ================================================================== OUVIDOR (comum): pálido, cego, orelhas em leque
def build_ouvidor():
    bones = [('root', (0, 0, 0), (0, 0, 0.06), None), ('hips', (0, 0.02, 0.24), (0, 0.0, 0.34), 'root'), ('spine', (0, 0.0, 0.34), (0, -0.05, 0.46), 'hips'),
             ('head', (0, -0.06, 0.46), (0, -0.1, 0.7), 'spine')]
    for s, sx in (('L', 1), ('R', -1)):
        bones += [('ear.' + s, (sx * 0.1, -0.04, 0.6), (sx * 0.16, 0.18, 0.72), 'head'),
                  ('upperarm.' + s, (sx * 0.1, -0.05, 0.43), (sx * 0.15, -0.08, 0.28), 'spine'), ('forearm.' + s, (sx * 0.15, -0.08, 0.28), (sx * 0.16, -0.14, 0.12), 'upperarm.' + s),
                  ('thigh.' + s, (sx * 0.06, 0.02, 0.24), (sx * 0.08, -0.04, 0.12), 'hips'), ('shin.' + s, (sx * 0.08, -0.04, 0.12), (sx * 0.08, 0.02, 0.02), 'thigh.' + s)]
    B = Builder(555, [b[0] for b in bones], outline=0.006)
    B.bones = bones; B.wash = 'azul_negro'
    # tronco magro e corcunda, barriga de fome
    tr = loft([(0.0, 0.08, 0.07, 0.0, 2.0), (0.06, 0.1, 0.09, -0.01, 2.0), (0.12, 0.095, 0.08, -0.02, 2.0), (0.18, 0.1, 0.085, -0.04, 2.1), (0.24, 0.08, 0.07, -0.06, 2.0),
              (0.27, 0.04, 0.04, -0.07, 2.0)], seg_n=10)
    B.piece(place(tr, (0, 0.03, 0.22)), paint='ouvidor', weights=lambda co: {'hips': 1.0} if co.z < 0.34 else {'spine': 1.0}, jitter=0.003)
    # coluna de vértebras salientes nas costas
    for k in range(5):
        B.piece(place(mk('sphere', u=6, v=4), (0, 0.075 - k * 0.01, 0.28 + k * 0.04), (0.02, 0.018, 0.016)), paint='ouvidor', bone='spine' if k > 1 else 'hips', oline=0.6)
    # cabeça grande, careca, sem olhos: testa lisa com duas covas costuradas
    hr = [(0.0, 0.06, 0.06, 0.0, 2.0), (0.04, 0.11, 0.105, -0.01, 2.0), (0.1, 0.13, 0.13, -0.01, 2.1), (0.17, 0.13, 0.13, 0.0, 2.1), (0.22, 0.1, 0.1, 0.01, 2.0),
          (0.25, 0.04, 0.04, 0.01, 2.0)]
    h0 = Vector((0, -0.08, 0.47))
    B.piece(xform(loft(hr, seg_n=12), Matrix.Translation(h0) @ Matrix.Rotation(math.radians(18), 4, 'X')), paint='ouvidor', bone='head', jitter=0.003)
    for sx in (-1, 1):
        c = h0 + Vector((sx * 0.05, -0.12, 0.15))
        B.piece(place(mk('sphere', u=7, v=5), c, (0.03, 0.012, 0.022)), paint='ouvidor_esc', bone='head', hull=False)
        B.piece(limb(c + Vector((-0.03, -0.01, 0.0)), c + Vector((0.03, -0.01, 0.0)), 0.004, 0.004, seg_n=4, rings=2), paint='tinta', bone='head', hull=False)
    # boca larga: o ÚNICO ponto de cor (o motor acende em magenta na telegrafia)
    bm = loft([(0.0, 0.1, 0.05, 0, 2.0), (0.02, 0.105, 0.058, 0, 2.0), (0.035, 0.075, 0.04, 0, 2.0)], seg_n=12)
    B.piece(xform(bm, Matrix.Translation(h0 + Vector((0, -0.112, 0.045))) @ Matrix.Rotation(math.radians(80), 4, 'X')), paint='boca', bone='head', mat='emis', hull=False)
    for k in range(8):
        x = -0.075 + 0.0214 * k
        B.piece(place(loft([(0, 0.008, 0.006, 0, 2.0), (0.026, 0.0, 0.0, 0, 2.0)], seg_n=4), h0 + Vector((x, -0.14, 0.085)), (1, 1, -1)), paint='osso', bone='head', oline=0.0, hull=False, sub=False)
    # ORELHAS EM LEQUE maiores que a cabeça (descanso: dobradas para trás; telegrafia: abertas em T)
    for s, sx in (('L', 1), ('R', -1)):
        a, b = J(bones, 'ear.' + s)
        d = (b - a).normalized()
        side = Vector((sx, 0, 0))
        up = d.cross(side).normalized()
        if up.z < 0: up = -up
        fan = bmesh.new()
        N = 7
        cv = [fan.verts.new(a)]
        rim = []
        for k in range(N + 1):
            t = -0.9 + 1.8 * k / N
            r = 0.26 * (1 - 0.25 * abs(t))
            p = a + d * math.cos(t) * r + up * math.sin(t) * r * 0.75 + side * 0.03 * math.sin(k * 1.7)
            rim.append(fan.verts.new(p))
        for k in range(N):
            fan.faces.new([cv[0], rim[k], rim[k + 1]])
        bmesh.ops.solidify(fan, geom=fan.faces[:], thickness=0.012)
        B.piece(fan, paint='ouvidor', mat='orelha', weights=lambda co, s=s, a=a: {'head': 0.3, 'ear.' + s: 0.7} if (co - a).length < 0.04 else {'ear.' + s: 1.0}, jitter=0.002)
        for k in (1, 3, 5):   # nervuras
            t = -0.9 + 1.8 * k / N
            r = 0.22
            p = a + d * math.cos(t) * r + up * math.sin(t) * r * 0.75
            B.piece(limb(a, p, 0.008, 0.004, seg_n=5, rings=2), paint='ouvidor_esc', bone='ear.' + s, mat='orelha', oline=0.0, hull=False)
    # trapos com o brasão de Thessimor (peixe que engoliu uma chave): faixa na cintura e farrapo no ombro
    tp = shell([(0.3, 0.105, 0.095, 0.02), (0.22, 0.12, 0.1, 0.02), (0.13, 0.13, 0.11, 0.025)], -180, 180, thick=0.01, seg=14)
    for v in tp.verts:
        if v.co.z < 0.16:
            v.co.z += 0.04 * abs(math.sin(math.atan2(v.co.x, v.co.y) * 3.5)) ** 2
    B.piece(tp, paint='trapo', weights=lambda co: {'hips': 1.0}, jitter=0.003)
    B.piece(disc(Vector((0, -0.112, 0.235)), Vector((0, -1, 0.1)), 0.03, seg=10, sx=1.2, depth=0.004), paint='ocre', bone='hips', hull=False, sub=False)
    B.piece(tube([(-0.02, -0.117, 0.235), (0.025, -0.117, 0.235)], [0.006, 0.003], seg_n=4), paint='trapo', bone='hips', hull=False)
    # braços compridos e finos, mãos de garra
    for s, sx in (('L', 1), ('R', -1)):
        a, b = J(bones, 'upperarm.' + s)
        B.piece(limb(a, b, 0.036, 0.028, seg_n=6, rings=3), paint='ouvidor', bone='upperarm.' + s, jitter=0.002)
        a, b = J(bones, 'forearm.' + s)
        B.piece(limb(a, b, 0.028, 0.022, seg_n=6, rings=3), paint='ouvidor', bone='forearm.' + s, jitter=0.002)
        for k in (-1, 0, 1):
            tip = b + Vector((sx * 0.025 * k, -0.04, -0.06))
            B.piece(tube([b, b + (tip - b) * 0.5 + Vector((0, -0.015, 0)), tip], [0.01, 0.008, 0.002], seg_n=5), paint='ouvidor_esc', bone='forearm.' + s, oline=0.7)
        a, b = J(bones, 'thigh.' + s)
        B.piece(limb(a, b, 0.042, 0.03, seg_n=6, rings=3), paint='ouvidor', bone='thigh.' + s)
        a, b = J(bones, 'shin.' + s)
        B.piece(limb(a, b, 0.03, 0.024, seg_n=6, rings=3), paint='ouvidor', bone='shin.' + s)
        B.piece(place(loft([(0, 0.03, 0.07, -0.04, 1.8), (0.025, 0.026, 0.075, -0.045, 1.8), (0.04, 0.0, 0.0, -0.05, 1.8)], seg_n=6), (b.x, b.y, 0.0)), paint='ouvidor', bone='shin.' + s)
    return B

# ================================================================== BOCALUME (comum, suporte): lesma de 2 m com isca de lanterna
def build_bocalume():
    bones = [('root', (0, 0, 0), (0, 0, 0.1), None), ('corpo', (0, 0.1, 0.25), (0, -0.4, 0.3), 'root'), ('cabeca', (0, -0.4, 0.3), (0, -0.85, 0.35), 'corpo'),
             ('cauda1', (0, 0.1, 0.25), (0, 0.55, 0.2), 'corpo'), ('cauda2', (0, 0.55, 0.2), (0, 1.0, 0.1), 'cauda1'),
             ('haste1', (0, -0.65, 0.55), (0, -0.85, 0.85), 'cabeca'), ('haste2', (0, -0.85, 0.85), (0, -1.1, 0.8), 'haste1'), ('isca', (0, -1.1, 0.8), (0, -1.12, 0.62), 'haste2')]
    B = Builder(666, [b[0] for b in bones], outline=0.008)
    B.bones = bones; B.wash = 'azul_negro'
    # corpo ao longo de Y: frente (-Y) larga e alta, cauda que afina; barriga chata
    secs = [(-0.95, 0.16, 0.18), (-0.8, 0.3, 0.38), (-0.55, 0.36, 0.5), (-0.25, 0.37, 0.52), (0.1, 0.34, 0.46), (0.45, 0.28, 0.36), (0.75, 0.2, 0.24), (1.0, 0.1, 0.12), (1.1, 0.03, 0.04)]
    bm = bmesh.new()
    R = []
    nseg = 14
    for y, w, h in secs:
        ring = []
        for j in range(nseg):
            t = 2 * math.pi * j / nseg
            x, z = math.sin(t) * w, math.cos(t)
            zz = h * 0.5 + (z * h * 0.5 if z > 0 else z * 0.05)   # barriga chata
            ring.append(bm.verts.new((x, y, max(0.0, zz))))
        R.append(ring)
    for i in range(len(R) - 1):
        for j in range(nseg):
            bm.faces.new([R[i][j], R[i][(j + 1) % nseg], R[i + 1][(j + 1) % nseg], R[i + 1][j]])
    for ring, rev in ((R[0], False), (R[-1], True)):
        c = bm.verts.new(sum((v.co for v in ring), Vector()) / len(ring))
        for j in range(nseg):
            f = [c, ring[j], ring[(j + 1) % nseg]]
            bm.faces.new(f[::-1] if rev else f)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    rr = random.Random(66)
    for v in bm.verts:
        if v.co.z > 0.05:
            v.co += Vector((0, 0, 0.02 * math.sin(v.co.y * 18) * min(1.0, v.co.z / 0.3)))
    def wb(co):
        if co.y < -0.45:
            return {'cabeca': 1.0}
        if co.y < 0.2:
            return {'corpo': 1.0}
        if co.y < 0.6:
            t = (co.y - 0.2) / 0.4
            return {'corpo': 1 - t, 'cauda1': t}
        t = min(1.0, (co.y - 0.6) / 0.4)
        return {'cauda1': 1 - t, 'cauda2': t}
    B.piece(bm, paint='bocalume', weights=wb, jitter=0.006)
    # manto com cristas e pintas claras (lesma de fungo)
    for k in range(9):
        y = -0.6 + k * 0.17
        w = 0.32 - abs(y) * 0.12
        B.piece(place(mk('sphere', u=8, v=5), (0, y, 0.44 - abs(y + 0.2) * 0.18), (w * 0.55, 0.06, 0.04)), paint='bocalume_esc', bone='corpo' if y < 0.2 else 'cauda1', jitter=0.004)
    for k in range(16):
        y = rr.uniform(-0.7, 0.9); x = rr.uniform(-0.25, 0.25) * (1 - abs(y) * 0.4)
        B.piece(place(mk('sphere', u=6, v=4), (x, y, 0.47 - abs(y + 0.2) * 0.2 - abs(x) * 0.5), (0.03, 0.03, 0.012)), paint='ardosia', bone='corpo' if y < 0.2 else 'cauda1', hull=False)
    # boca: fenda larga na frente, embaixo (acende em magenta antes do cuspe)
    mo = loft([(0.0, 0.26, 0.07, 0, 2.0), (0.03, 0.28, 0.1, 0, 2.0), (0.06, 0.24, 0.06, 0, 2.0)], seg_n=14)
    B.piece(xform(mo, Matrix.Translation((0, -0.9, 0.15)) @ Matrix.Rotation(math.radians(90), 4, 'X')), paint='boca', bone='cabeca', mat='emis', hull=False)
    # chifres sensoriais curtos
    for sx in (-1, 1):
        B.piece(tube([(sx * 0.15, -0.75, 0.42), (sx * 0.22, -0.82, 0.55), (sx * 0.24, -0.9, 0.6)], [0.03, 0.02, 0.012], seg_n=6), paint='bocalume', bone='cabeca')
    # HASTE da isca: curva para a frente; a isca imita a lanterna de um aventureiro (quente, de propósito)
    a1, b1 = J(bones, 'haste1'); a2, b2 = J(bones, 'haste2'); ai, bi = J(bones, 'isca')
    B.piece(tube([a1, a1 + (b1 - a1) * 0.5 + Vector((0, 0.02, 0.03)), b1], [0.028, 0.022, 0.018], seg_n=7), paint='bocalume', bone='haste1')
    B.piece(tube([a2, a2 + (b2 - a2) * 0.5 + Vector((0, 0, 0.03)), b2], [0.018, 0.015, 0.012], seg_n=6), paint='bocalume', bone='haste2')
    B.piece(tube([ai, ai + Vector((0, -0.005, -0.08))], [0.006, 0.006], seg_n=5), paint='bocalume_esc', bone='isca', oline=0.5)
    ic = ai + Vector((0, -0.01, -0.17))
    B.piece(place(mk('sphere', u=8, v=6), ic, (0.11, 0.11, 0.13)), paint='geodo', bone='isca', mat='emis', hull=False)
    B.piece(place(loft([(0, 0.06, 0.06, 0, 2.0), (0.04, 0.03, 0.03, 0, 2.0)], seg_n=8), ic + Vector((0, 0, 0.09))), paint='bocalume_esc', bone='isca', oline=0.6)
    return B

ENEMIES = {'ouvidor': build_ouvidor, 'bocalume': build_bocalume}

# ================================================================== PRUMO (prop): o peso de chumbo da guilda
def build_prumo():
    bones = [('root', (0, 0, 0), (0, 0, 0.1), None)]
    B = Builder(777, ['root'], outline=0.006)
    B.bones = bones; B.wash = 'azul_negro'
    pr = loft([(0.0, 0.0, 0.0, 0, 2.0), (0.03, 0.04, 0.04, 0, 2.0), (0.1, 0.1, 0.1, 0, 2.0), (0.17, 0.125, 0.125, 0, 2.0), (0.23, 0.11, 0.11, 0, 2.0),
               (0.27, 0.07, 0.07, 0, 2.0), (0.29, 0.03, 0.03, 0, 2.0)], seg_n=14)
    B.piece(place(pr, (0, 0, -0.15)), paint='chumbo', bone='root', mat='metal')
    B.piece(place(loft([(0, 0.127, 0.127, 0, 2.0), (0.03, 0.127, 0.127, 0, 2.0)], seg_n=14), (0, 0, 0.0)), paint='latao', bone='root', mat='metal', oline=0.6)
    B.piece(xform(torus(0.035, 0.01, 12, 5), Matrix.Translation((0, 0, 0.16)) @ Matrix.Rotation(math.pi / 2, 4, 'X')), paint='latao', bone='root', mat='metal', oline=0.6)
    return B

PROPS = {'prumo': build_prumo}

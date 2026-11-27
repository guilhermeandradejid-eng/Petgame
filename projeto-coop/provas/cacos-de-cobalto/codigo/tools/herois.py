# Heróis de Cacos de Cobalto: figuras de faiança em negativo (esmalte azul-noite pintado de branco),
# peças rígidas presas a um osso cada (louça não estica), pano com osso de mola, rosto de 3 traços
# no shader. Frente = -Y, Z para cima, metros.
import math
from mathutils import Vector
import geo as G
import pintura as PT

def mirror(p):
    return (-p[0], p[1], p[2])

def humanoid_bones(J, extra=()):
    """J: dicionário de juntas. Devolve lista de ossos (nome, cabeça, cauda, pai)."""
    B = [
        ('root', (0, 0, 0), (0, 0, 0.1), None),
        ('hips', J['hips'], J['spine'], 'root'),
        ('spine', J['spine'], J['chest'], 'hips'),
        ('chest', J['chest'], J['neck'], 'spine'),
        ('neck', J['neck'], J['head'], 'chest'),
        ('head', J['head'], J['head_top'], 'neck'),
    ]
    for s, sx in (('L', 1), ('R', -1)):
        f = (lambda p: p) if sx == 1 else mirror
        B += [
            ('shoulder.' + s, f(J['clav']), f(J['sh']), 'chest'),
            ('upperarm.' + s, f(J['sh']), f(J['el']), 'shoulder.' + s),
            ('forearm.' + s, f(J['el']), f(J['wr']), 'upperarm.' + s),
            ('hand.' + s, f(J['wr']), f(J['hd']), 'forearm.' + s),
            ('thigh.' + s, f(J['hip_j']), f(J['knee']), 'hips'),
            ('shin.' + s, f(J['knee']), f(J['ankle']), 'thigh.' + s),
            ('foot.' + s, f(J['ankle']), f(J['toe']), 'shin.' + s),
        ]
    B += list(extra)
    return B

def hand(F, wr, hd, side, bone, grip=True, size=1.0, region='pele'):
    """Mão de luva com 3 dedos e polegar, legível de cima. grip=True fecha em volta de um cabo
    perpendicular ao antebraço (eixo X local do mundo para a mão direita/esquerda)."""
    wr, hd = Vector(wr), Vector(hd)
    d = (hd - wr).normalized()
    sx = 1 if side == 'L' else -1
    s = size
    c = wr + d * 0.045 * s
    palm = G.sphere(1.0, 12, 8)
    G.xf(palm, scale=(0.040 * s, 0.032 * s, 0.050 * s))
    G.xf(palm, loc=tuple(c))
    F.add(palm, region, bone)
    side_v = Vector((sx, 0, 0))
    fwd = Vector((0, -1, 0))
    for k, off in enumerate((-0.022, 0.0, 0.022)):
        base = c + d * 0.035 * s + fwd * off * s * 0.0 + Vector((0, off * s, 0))
        base = c + d * 0.04 * s + Vector((0, off * s, 0))
        if grip:  # dedos dobrados para dentro (em gancho)
            tip = base + d * 0.022 * s - side_v * 0.03 * s
        else:
            tip = base + d * (0.05 - abs(off) * 0.4) * s + Vector((0, off * s * 0.5, 0))
        F.add(G.tube(tuple(base - d * 0.01 * s), tuple(tip), G.capsule(0.016 * s, 0.014 * s), 8), region, bone)
    th0 = c + Vector((0, -0.028 * s, 0)) + side_v * 0.012 * s
    th1 = th0 + Vector((0, -0.03 * s, 0)) + d * 0.02 * s - side_v * (0.015 if grip else -0.005) * s
    F.add(G.tube(tuple(th0), tuple(th1), G.capsule(0.016 * s, 0.013 * s), 8), region, bone)

def arm(F, J, side, sleeve_region, skin_region='pele', puff=0.0, r_up=0.055, r_fo=0.042, cuff_region=None, grip=True, hand_size=1.0):
    f = (lambda p: Vector(p)) if side == 'L' else (lambda p: Vector(mirror(p)))
    sh, el, wr, hd = f(J['sh']), f(J['el']), f(J['wr']), f(J['hd'])
    if puff > 0:
        ps = G.sphere(1.0, 14, 9); G.xf(ps, scale=(puff * 1.05, puff, puff * 0.9)); G.xf(ps, loc=tuple(sh + (el - sh) * 0.12))
        F.add(ps, sleeve_region, 'upperarm.' + side)
    F.add(G.tube(tuple(sh), tuple(el + (el - sh).normalized() * 0.02), G.capsule(r_up, r_up * 0.9), 12), sleeve_region, 'upperarm.' + side)
    F.add(G.tube(tuple(el - (wr - el).normalized() * 0.02), tuple(wr), G.capsule(r_fo, r_fo * 0.85), 12), skin_region, 'forearm.' + side)
    if cuff_region:
        F.add(G.tube(tuple(el - (wr - el).normalized() * 0.015), tuple(el + (wr - el).normalized() * 0.05), [(0, 0), (0.05, r_fo * 1.25), (0.95, r_fo * 1.2), (1, 0)], 12), cuff_region, 'forearm.' + side)
    hand(F, wr, hd, side, 'hand.' + side, grip=grip, size=hand_size, region=skin_region)

HEAD_S = 1.22   # cabeças 22% maiores: o rosto de 3 traços precisa ler na câmera de camarote

def face_meta(s, **m):
    for k in ('eye_gap', 'eye_w', 'eye_h', 'mouth_w'):
        m[k] = m[k] * s
    m['face_size'] = [m['face_size'][0] * s, m['face_size'][1] * s]
    return m

def smooth_w(z, z0, z1):
    return min(1.0, max(0.0, (z - z0) / (z1 - z0)))

# ================================================================== TIA LAMPARINA (Brasa)
def lamparina():
    J = dict(hips=(0, 0, 0.50), spine=(0, 0, 0.62), chest=(0, 0, 0.74), neck=(0, -0.01, 0.92), head=(0, -0.02, 0.97), head_top=(0, -0.02, 1.32),
             clav=(0.06, 0, 0.86), sh=(0.20, 0.0, 0.85), el=(0.27, 0.01, 0.66), wr=(0.30, -0.02, 0.49), hd=(0.31, -0.03, 0.42),
             hip_j=(0.09, 0, 0.48), knee=(0.10, 0, 0.27), ankle=(0.10, 0.01, 0.07), toe=(0.10, -0.12, 0.02))
    hc = Vector(mirror(J['wr'])) + (Vector(mirror(J['hd'])) - Vector(mirror(J['wr']))).normalized() * 0.05
    tip = hc + Vector((0, -0.92, 0))
    extra = [
        ('prop.R', tuple(hc), tuple(hc + Vector((0, -0.3, 0))), 'hand.R'),
        ('mola_lanterna', tuple(tip), tuple(tip + Vector((0, 0, -0.16))), 'prop.R'),
        ('mola_lenco', (0, 0.0, 1.30), (0, -0.02, 1.46), 'head'),
        ('mola_avental', (0, -0.22, 0.60), (0, -0.33, 0.18), 'hips'),
        ('mola_saia_F', (0, -0.10, 0.52), (0, -0.30, 0.10), 'hips'),
        ('mola_saia_B', (0, 0.10, 0.52), (0, 0.30, 0.10), 'hips'),
    ]
    F = G.Fig(humanoid_bones(J, extra), seed=11)
    F.head_xf(J['head'], HEAD_S, (0, 0, 0), ('head', 'mola_lenco'))
    A = F.atlas
    # ---- regiões do atlas
    A.region('liso', 64, 64, lambda w, h: PT.navy(w, h, 1))
    A.region('pele', 64, 64, lambda w, h: PT.skin(w, h, 2))
    A.region('vestido', 512, 256, lambda w, h: PT.navy(w, h, 3, PT.compose_deco(
        PT.deco_folds(7, 0.05, 0.80, 9, phase=0.25), PT.deco_scallops(0.84, 14, 0.07, 3.5), PT.deco_bands([0.97], 4.0),
        PT.deco_dots(30, 3.2, rows=(0.1, 0.7)))))
    A.region('busto', 256, 128, lambda w, h: PT.navy(w, h, 4, PT.compose_deco(
        PT.deco_bands([0.10], 7.0), PT.deco_dots(22, 2.6, rows=(0.28, 0.95)),
        lambda D, w, h, r: [PT.K.stroke(D, [(w / 2 + 0.5, y), (w / 2 - 0.5, y + 1)], 5, 4.5, load=1.0, pool=0.2, seed=int(y)) for y in (h * 0.4, h * 0.62, h * 0.84)])))
    A.region('avental', 256, 256, lambda w, h: PT.white_panel(w, h, 5, PT.compose_deco(
        PT.deco_bands([0.95], 10), PT.deco_scallops(0.84, 8, 0.05, 3.0),
        PT.deco_flower(0.5, 0.45, 40, 7), PT.deco_leaves(14, 0.15, 0.72, 13),
        lambda D, w, h, r: [PT.K.stroke(D, [(x, -2), (x + 1, h * 0.5), (x, h + 2)], 4.5, 4, load=0.95, pool=0, seed=int(x), taper_in=0) for x in (w * 0.255, w * 0.745)])))
    A.region('peitilho', 128, 96, lambda w, h: PT.white_panel(w, h, 6, PT.compose_deco(PT.deco_bands([0.08, 0.92], 4), PT.deco_flower(0.5, 0.52, 18, 5))))
    A.region('manga', 128, 96, lambda w, h: PT.navy(w, h, 7, PT.compose_deco(PT.deco_bands([0.55, 0.9], 3.4), PT.deco_dots(18, 2.4, rows=(0.05, 0.45)))))
    A.region('punho', 64, 32, lambda w, h: PT.navy(w, h, 8, PT.deco_bands([0.5], 5)))
    A.region('cabeca', 256, 192, lambda w, h: PT.face_region(w, h, 9, face_s=(0.30, 0.70), face_t=(0.0, 1.02),
                                                              hair=PT.subtract(PT.deco_hair(0.5, 0.10, 0.17, 9))))
    A.region('lenco', 256, 128, lambda w, h: PT.navy(w, h, 10, PT.compose_deco(PT.deco_dots(26, 4.0), PT.deco_bands([0.96], 5))))
    A.region('laco', 64, 64, lambda w, h: PT.accent('brasa', w, h, 11, stripes=3))
    A.region('faixa', 256, 64, lambda w, h: PT.navy(w, h, 16, PT.compose_deco(PT.deco_bands([0.2, 0.8], 4), PT.deco_dots(20, 3.0, rows=(0.4, 0.6)))))
    A.region('sapato', 64, 32, lambda w, h: PT.navy(w, h, 12))
    A.region('madeira', 64, 256, lambda w, h: PT.wood(w, h, 13))
    A.region('ferro', 64, 64, lambda w, h: PT.iron(w, h, 14))
    A.region('chama', 32, 64, lambda w, h: PT.flame(w, h, 15))

    # ---- vestido (pera larga) com pregas
    dress = [(0.05, 0.355, 0.33, 0.34), (0.09, 0.372, 0.345, 0.352), (0.18, 0.372, 0.345, 0.35), (0.30, 0.34, 0.31, 0.325),
             (0.42, 0.29, 0.26, 0.28), (0.53, 0.245, 0.22, 0.235), (0.62, 0.222, 0.205, 0.205)]
    fold = lambda i, th: 1 + 0.03 * max(0, 1 - i / 4.5) * math.sin(7 * th)
    def w_dress(co):
        k = 0.85 * (1 - smooth_w(co.z, 0.12, 0.5))
        fb = 'mola_saia_F' if co.y < 0 else 'mola_saia_B'
        return {'hips': 1 - k, fb: k}
    F.add(G.loft(dress, 28, 2.0, fold), 'vestido', weights=w_dress)
    # ---- busto
    torso = [(0.58, 0.215, 0.195, 0.19), (0.67, 0.228, 0.222, 0.19), (0.75, 0.226, 0.235, 0.185), (0.83, 0.21, 0.20, 0.172),
             (0.89, 0.175, 0.145, 0.15), (0.93, 0.10, 0.085, 0.09), (0.955, 0.0, 0.0, 0.0)]
    F.add(G.loft(torso, 24, 2.1), 'busto', weights=lambda co: {'spine': 1 - smooth_w(co.z, 0.66, 0.8), 'chest': smooth_w(co.z, 0.66, 0.8)})
    # ---- avental (laje curva sobre o vestido, osso de mola) e peitilho
    def wrap_front(bm, prof, gap):
        def fn(co):
            z = co.z
            # raio do corpo na frente nessa altura (interpola o perfil)
            ry, rx = 0.2, 0.22
            for (z0, rx0, ryf0, _), (z1, rx1, ryf1, _) in zip(prof[:-1], prof[1:]):
                if z0 <= z <= z1:
                    u = (z - z0) / (z1 - z0); ry = ryf0 + (ryf1 - ryf0) * u; rx = rx0 + (rx1 - rx0) * u
            x = co.x
            y = -math.sqrt(max(0.0, 1 - (x / (rx * 1.02)) ** 2)) * ry - gap + co.y
            return (x, y, z)
        return G.bend(bm, fn)
    ap = G.loft([(0.10, 0.0, 0.0, 0.0, 0, 0), (0.105, 0.20, 0.018, 0.018), (0.20, 0.215, 0.02, 0.02), (0.40, 0.19, 0.02, 0.02), (0.57, 0.15, 0.018, 0.018), (0.61, 0.145, 0.016, 0.016), (0.615, 0, 0, 0)], 24, 3.0)
    wrap_front(ap, dress, 0.025)
    F.add(ap, 'avental', weights=lambda co: {'hips': 1 - smooth_w(-co.z, -0.6, -0.48), 'mola_avental': smooth_w(-co.z, -0.6, -0.48)})
    bib = G.loft([(0.60, 0, 0, 0), (0.605, 0.12, 0.014, 0.014), (0.70, 0.125, 0.016, 0.016), (0.79, 0.11, 0.014, 0.014), (0.795, 0, 0, 0)], 20, 3.0)
    wrap_front(bib, torso, 0.012)
    F.add(bib, 'peitilho', 'chest')
    # faixa de vidrado na cintura (cor do jogador, trocada no shader): cobre o cós do avental
    sash = [(0.50, 0.0, 0.0, 0.0), (0.502, 0.262, 0.262, 0.25), (0.56, 0.252, 0.26, 0.24), (0.615, 0.236, 0.236, 0.222), (0.617, 0, 0, 0)]
    F.add(G.loft(sash, 28, 2.0), 'faixa', 'hips')
    # alças do avental
    for sx in (1, -1):
        F.add(G.tube((sx * 0.10, -0.205, 0.79), (sx * 0.13, -0.05, 0.90), G.capsule(0.014, 0.014), 6, flat=0.6), 'liso', 'chest', oline=0.6)
    # ---- braços (manga bufante, antebraço de pele, mão de luva)
    arm(F, J, 'L', 'manga', puff=0.085, r_up=0.058, r_fo=0.044, cuff_region='punho', grip=False, hand_size=1.15)
    arm(F, J, 'R', 'manga', puff=0.085, r_up=0.058, r_fo=0.044, cuff_region='punho', grip=True, hand_size=1.15)
    # ---- cabeça redonda (bochechas largas, queixo pequeno) por perfil
    head = [(0.955, 0, 0, 0, 0, -0.035), (0.975, 0.075, 0.07, 0.05, 0, -0.035), (1.01, 0.15, 0.135, 0.11, 0, -0.03), (1.06, 0.188, 0.165, 0.145, 0, -0.025),
            (1.12, 0.193, 0.168, 0.158, 0, -0.02), (1.18, 0.182, 0.158, 0.165, 0, -0.015), (1.24, 0.155, 0.14, 0.152, 0, -0.012), (1.29, 0.108, 0.098, 0.11, 0, -0.01), (1.315, 0, 0, 0, 0, -0.01)]
    F.add(G.loft(head, 24, 2.15), 'cabeca', 'head')
    nose = G.sphere(1.0, 12, 8); G.xf(nose, scale=(0.038, 0.034, 0.032), loc=(0, -0.19, 1.10))
    F.add(nose, 'pele', 'head')
    # lenço: cobre topo e nuca, deixa o rosto livre
    scarf = [(1.10, 0, 0, 0, 0, 0.07), (1.105, 0.10, 0.02, 0.10, 0, 0.07), (1.15, 0.196, 0.04, 0.168, 0, 0.05), (1.21, 0.195, 0.08, 0.178, 0, 0.03),
             (1.26, 0.172, 0.11, 0.166, 0, 0.015), (1.305, 0.14, 0.11, 0.135, 0, 0.0), (1.338, 0.075, 0.065, 0.07, 0, -0.005), (1.35, 0, 0, 0, 0, -0.005)]
    bun = G.sphere(1.0, 14, 9); G.xf(bun, scale=(0.085, 0.075, 0.08), loc=(0, 0.17, 1.20)); F.add(bun, 'lenco', 'head')
    F.add(G.loft(scarf, 24, 2.1), 'lenco', 'head')
    # laço do lenço (acento laranja-ferro), em mola
    for sx in (1, -1):
        F.add(G.tube((0, -0.01, 1.33), (sx * 0.10, -0.03, 1.47), [(0, 0), (0.1, 0.03), (0.55, 0.05), (0.9, 0.035), (1, 0)], 10, flat=0.45, roll=90), 'laco', 'mola_lenco')
    kn = G.sphere(1.0, 10, 7); G.xf(kn, scale=(0.04, 0.035, 0.035), loc=(0, -0.012, 1.345)); F.add(kn, 'laco', 'mola_lenco')
    # ---- sapatos
    for s, sx in (('L', 1), ('R', -1)):
        sh = G.loft([(0.0, 0, 0, 0, 0, 0), (0.005, 0.05, 0.10, 0.05), (0.04, 0.055, 0.11, 0.055), (0.07, 0.04, 0.07, 0.04), (0.075, 0, 0, 0)], 14, 2.4)
        G.xf(sh, loc=(sx * 0.10, -0.06, 0.0)); F.add(sh, 'sapato', 'foot.' + s)
    # ---- lamparina de cabo longo (madeira) com lanterna de ferro pendurada (mola)
    F.add(G.tube(tuple(hc + Vector((0, 0.26, 0))), tuple(tip + Vector((0, 0.02, 0))), [(0, 0), (0.01, 0.02), (0.99, 0.02), (1, 0)], 8), 'madeira', 'prop.R', spec=0.0, mat=0.75)
    F.add(G.tube(tuple(tip + Vector((0, 0.03, 0))), tuple(tip + Vector((0, -0.03, -0.03))), G.capsule(0.012, 0.012), 6), 'ferro', 'prop.R', spec=0.2, mat=1.0, oline=0.7)
    lt = tip + Vector((0, 0, -0.05))
    cap = G.loft([(0.0, 0.07, 0.07, 0.07), (0.035, 0.035, 0.035, 0.035), (0.05, 0.0, 0.0, 0.0)], 4, 2.0); G.xf(cap, rot=(0, 0, 45), loc=tuple(lt + Vector((0, 0, -0.06))))
    F.add(cap, 'ferro', 'mola_lanterna', spec=0.25, mat=1.0, smooth=False)
    base = G.box(0.11, 0.11, 0.025, 0.004); G.xf(base, loc=tuple(lt + Vector((0, 0, -0.22)))); F.add(base, 'ferro', 'mola_lanterna', spec=0.25, mat=1.0)
    for dx, dy in ((0.045, 0.045), (-0.045, 0.045), (0.045, -0.045), (-0.045, -0.045)):
        F.add(G.tube(tuple(lt + Vector((dx, dy, -0.065))), tuple(lt + Vector((dx, dy, -0.21))), [(0, 0.008), (1, 0.008)], 6), 'ferro', 'mola_lanterna', spec=0.2, mat=1.0, oline=0.6)
    fl = G.loft([(0, 0, 0, 0), (0.02, 0.03, 0.03, 0.03), (0.05, 0.034, 0.034, 0.034), (0.09, 0.02, 0.02, 0.02), (0.12, 0, 0, 0)], 10, 2.0)
    G.xf(fl, loc=tuple(lt + Vector((0, 0, -0.205)))); F.add(fl, 'chama', 'mola_lanterna', spec=0.0, mat=1.0, emit=1.0, oline=0.0)
    F.meta = face_meta(HEAD_S, face_size=[1.12, 0.48], t_eyes=0.43, t_mouth=0.71, eye_gap=0.07, eye_w=0.025, eye_h=0.038, mouth_w=0.055, lantern_bone='mola_lanterna')
    F.meta['player_regions'] = [['lenco', 1], ['faixa', 1]]
    return F

# ================================================================== BENTO RODO (Cal)
def bento():
    J = dict(hips=(0, 0, 0.82), spine=(0, 0, 0.95), chest=(0, 0, 1.08), neck=(0, -0.01, 1.26), head=(0, -0.03, 1.38), head_top=(0, -0.03, 1.78),
             clav=(0.045, 0, 1.22), sh=(0.145, 0.0, 1.20), el=(0.20, 0.02, 0.95), wr=(0.235, -0.01, 0.72), hd=(0.245, -0.02, 0.64),
             hip_j=(0.08, 0, 0.80), knee=(0.085, -0.01, 0.45), ankle=(0.09, 0.01, 0.09), toe=(0.09, -0.16, 0.02))
    hcR = Vector(mirror(J['wr'])) + (Vector(mirror(J['hd'])) - Vector(mirror(J['wr']))).normalized() * 0.05
    hcL = Vector(J['wr']) + (Vector(J['hd']) - Vector(J['wr'])).normalized() * 0.05
    extra = [
        ('prop.R', tuple(hcR), tuple(hcR + Vector((0, 0, -0.3))), 'hand.R'),
        ('prop.L', tuple(hcL), tuple(hcL + Vector((0, 0, -0.1))), 'hand.L'),
        ('mola_balde', tuple(hcL + Vector((0, 0, -0.01))), tuple(hcL + Vector((0, 0, -0.30))), 'prop.L'),
        ('mola_chapeu', (0, -0.03, 1.70), (0, -0.03, 1.92), 'head'),
        ('mola_lenco', (0, -0.08, 1.27), (0, -0.16, 1.12), 'chest'),
        ('mola_saia_F', (0, -0.08, 0.80), (0, -0.20, 0.42), 'hips'),
        ('mola_saia_B', (0, 0.08, 0.80), (0, 0.20, 0.42), 'hips'),
    ]
    F = G.Fig(humanoid_bones(J, extra), seed=21)
    # pescoço 30% mais curto (a cabeça desce 5,5 cm) e cabeça 25% maior: silhueta de cravo
    BS = 1.25
    F.head_xf(J['head'], BS, (0, 0, -0.055), ('head', 'mola_chapeu'))
    A = F.atlas
    A.region('liso', 64, 64, lambda w, h: PT.navy(w, h, 21))
    A.region('pele', 64, 64, lambda w, h: PT.skin(w, h, 22))
    A.region('guardapo', 384, 320, lambda w, h: PT.navy(w, h, 23, PT.compose_deco(PT.deco_stripes_v(12, 2.6, 0.92), PT.deco_bands([0.93], 6), PT.deco_bands([0.04], 4))))
    A.region('calca', 192, 128, lambda w, h: PT.navy(w, h, 24, PT.deco_stripes_v(8, 1.6, 0.66)))
    A.region('manga', 128, 128, lambda w, h: PT.navy(w, h, 25, PT.compose_deco(PT.deco_stripes_v(7, 2.0, 0.9), PT.deco_bands([0.9], 4))))
    A.region('cabeca', 256, 256, lambda w, h: PT.face_region(w, h, 26, face_s=(0.33, 0.67), face_t=(0.10, 1.0),
                                                              hair=PT.subtract(PT.compose_deco(PT.deco_hair(0.5, 0.13, 0.14, 7), PT.deco_mustache(0.5, 0.585, 0.085, 5.5)))))
    A.region('chapeu', 192, 128, lambda w, h: PT.face_region(w, h, 27, face_s=(-1, 2), face_t=(-1, 2), hair=PT.subtract(PT.deco_text_lines(9, 0.2, 0.8, 1.2, 0.8))))
    A.region('lenco', 64, 64, lambda w, h: PT.accent('cal', w, h, 28, stripes=2))
    A.region('bota', 64, 64, lambda w, h: PT.navy(w, h, 29, PT.deco_bands([0.25], 3)))
    A.region('madeira', 64, 256, lambda w, h: PT.wood(w, h, 30))
    A.region('ferro', 64, 64, lambda w, h: PT.iron(w, h, 31))
    A.region('cal', 64, 64, lambda w, h: PT.cal(w, h, 32))
    A.region('balde', 128, 64, lambda w, h: PT.navy(w, h, 33, PT.compose_deco(PT.deco_bands([0.12, 0.88], 3.5), PT.deco_folds(6, 0.25, 0.75, 4, load=0.9))))
    # ---- guarda-pó comprido (linha vertical)
    coat = [(0.40, 0.205, 0.17, 0.185), (0.48, 0.19, 0.16, 0.172), (0.70, 0.165, 0.14, 0.15), (0.86, 0.155, 0.135, 0.14),
            (1.00, 0.16, 0.148, 0.135), (1.10, 0.155, 0.148, 0.128), (1.18, 0.142, 0.128, 0.115), (1.23, 0.105, 0.095, 0.09), (1.265, 0.05, 0.045, 0.045), (1.27, 0, 0, 0)]
    fold = lambda i, th: 1 + 0.025 * max(0, 1 - i / 3) * math.sin(5 * th + 0.5)
    def w_coat(co):
        if co.z > 0.95:
            return {'spine': 1 - smooth_w(co.z, 0.98, 1.12), 'chest': smooth_w(co.z, 0.98, 1.12)}
        k = 0.8 * (1 - smooth_w(co.z, 0.45, 0.78))
        return {'hips': 1 - k, ('mola_saia_F' if co.y < 0 else 'mola_saia_B'): k}
    F.add(G.loft(coat, 26, 2.1, fold), 'guardapo', weights=w_coat)
    # ---- pernas finas e botas grandes
    for s, sx in (('L', 1), ('R', -1)):
        F.add(G.tube((sx * 0.08, -0.0, 0.62), (sx * 0.085, -0.01, 0.44), G.capsule(0.055, 0.05), 10), 'calca', 'thigh.' + s)
        F.add(G.tube((sx * 0.085, -0.01, 0.47), (sx * 0.09, 0.01, 0.10), G.capsule(0.05, 0.045), 10), 'calca', 'shin.' + s)
        bt = G.loft([(0.0, 0, 0, 0, 0, -0.03), (0.005, 0.06, 0.14, 0.06, 0, -0.03), (0.05, 0.065, 0.15, 0.065, 0, -0.03), (0.09, 0.055, 0.06, 0.055, 0, 0), (0.15, 0.05, 0.05, 0.05), (0.155, 0, 0, 0)], 14, 2.3)
        G.xf(bt, loc=(sx * 0.09, -0.02, 0.0)); F.add(bt, 'bota', 'foot.' + s)
    # ---- braços longos
    arm(F, J, 'L', 'manga', puff=0.0, r_up=0.048, r_fo=0.038, cuff_region=None, grip=True, hand_size=1.2)
    arm(F, J, 'R', 'manga', puff=0.0, r_up=0.048, r_fo=0.038, cuff_region=None, grip=True, hand_size=1.2)
    # ---- pescoço longo, lenço verde-cobre
    F.add(G.tube((0, -0.01, 1.22), (0, -0.03, 1.36), [(0, 0.05), (1, 0.045)], 10), 'pele', 'neck')
    knot = G.sphere(1.0, 10, 7); G.xf(knot, scale=(0.05, 0.04, 0.045), loc=(0, -0.10, 1.24)); F.add(knot, 'lenco', 'chest')
    F.add(G.tube((0, 0.0, 1.25), (0, 0.0, 1.29), [(0, 0.0), (0.05, 0.088), (0.95, 0.078), (1, 0)], 14, flat=0.85), 'lenco', 'chest')
    for dx in (0.03, -0.02):
        F.add(G.tube((0, -0.12, 1.25), (dx, -0.17, 1.13), [(0, 0.0), (0.1, 0.028), (0.8, 0.03), (1, 0)], 8, flat=0.4), 'lenco', 'mola_lenco')
    # ---- cabeça comprida: testa alta, queixo longo para a frente, nariz comprido
    hd = [(1.36, 0, 0, 0, 0, -0.06), (1.375, 0.06, 0.05, 0.04, 0, -0.065), (1.41, 0.10, 0.09, 0.07, 0, -0.05), (1.47, 0.13, 0.13, 0.11, 0, -0.03),
          (1.54, 0.142, 0.14, 0.135, 0, -0.02), (1.61, 0.142, 0.135, 0.145, 0, -0.02), (1.68, 0.128, 0.122, 0.135, 0, -0.02), (1.73, 0.09, 0.09, 0.095, 0, -0.02), (1.755, 0, 0, 0, 0, -0.02)]
    F.add(G.loft(hd, 24, 2.2), 'cabeca', 'head')
    F.add(G.tube((0, -0.135, 1.57), (0, -0.215, 1.525), [(0, 0.0), (0.15, 0.024), (0.55, 0.026), (0.9, 0.015), (1, 0)], 10), 'pele', 'head')
    for sx in (1, -1):
        ear = G.sphere(1.0, 10, 7); G.xf(ear, scale=(0.02, 0.035, 0.05), loc=(sx * 0.14, 0.0, 1.56)); F.add(ear, 'pele', 'head')
    # ---- chapéu de jornal dobrado (silhueta triangular), em mola
    def hat():
        # chapéu de jornal dobrado: tenda com cumeeira (vista de cima é um barco atravessado na cabeça)
        bm = G.bmesh.new()
        uvl = bm.loops.layers.uv.new('UVMap')
        W, H, Dp = 0.19, 0.15, 0.10
        V = lambda x, y, z: bm.verts.new((x, y, z))
        a0, a1 = V(-W, -Dp, 0), V(W, -Dp, 0)
        b0, b1 = V(-W, Dp, 0), V(W, Dp, 0)
        r0, r1 = V(-0.05, 0, H), V(0.07, 0, H * 0.96)
        faces = [[a0, a1, r1, r0], [b1, b0, r0, r1], [a0, r0, b0], [a1, b1, r1], [a0, b0, b1, a1]]
        for fv in faces:
            f = bm.faces.new(fv)
            for lo in f.loops:
                co = lo.vert.co
                lo[uvl].uv = ((co.x + W) / (2 * W), co.z / H)
        G.bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        G.bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.006, segments=1, affect='EDGES')
        return bm
    # aba larga e o chapéu inclinado 12° para o lado (quebra a vertical)
    h_ = hat(); G.xf(h_, rot=(-6, 12, 5), loc=(0.01, -0.02, 1.685)); F.add(h_, 'chapeu', 'mola_chapeu', smooth=False)
    fl = G.box(0.38, 0.012, 0.045, 0.004); G.xf(fl, rot=(-6, 12, 5), loc=(0.01, -0.105, 1.70)); F.add(fl, 'chapeu', 'mola_chapeu', smooth=False)
    # aba larga de jornal dobrado: elipse com a borda virada para cima (lê como chapéu de cima)
    brim = G.loft([(0.0, 0.0, 0.0, 0.0), (0.004, 0.17, 0.12, 0.12), (0.012, 0.29, 0.2, 0.2), (0.03, 0.30, 0.215, 0.215), (0.034, 0.0, 0.0, 0.0)], 28, 2.0,
                  fold=lambda i, th: 1 + 0.04 * math.sin(3 * th))
    G.xf(brim, rot=(-6, 12, 5), loc=(0.01, -0.02, 1.665)); F.add(brim, 'chapeu', 'mola_chapeu', smooth=False)
    # ---- rodo em T (cabo de madeira, travessa de ferro) na mão direita
    a = hcR + Vector((0, 0, 0.55)); b = hcR + Vector((0, 0, -0.78))
    F.add(G.tube(tuple(a), tuple(b), [(0, 0), (0.01, 0.019), (0.99, 0.019), (1, 0)], 8), 'madeira', 'prop.R', spec=0.0, mat=0.75)
    tb = G.box(0.52, 0.05, 0.05, 0.01); G.xf(tb, loc=tuple(b + Vector((0, 0, -0.01)))); F.add(tb, 'madeira', 'prop.R', spec=0.0, mat=0.75)
    rb = G.box(0.5, 0.025, 0.04, 0.008); G.xf(rb, loc=tuple(b + Vector((0, 0, -0.05)))); F.add(rb, 'ferro', 'prop.R', spec=0.2, mat=1.0)
    # ---- balde de cal pendurado (mola)
    bc = hcL + Vector((0, 0, -0.24))
    bk = G.loft([(0.0, 0, 0, 0), (0.005, 0.10, 0.10, 0.10), (0.20, 0.125, 0.125, 0.125), (0.205, 0.0, 0.0, 0.0)], 18, 2.0)
    G.xf(bk, loc=tuple(bc + Vector((0, 0, -0.10)))); F.add(bk, 'balde', 'mola_balde')
    calsurf = G.loft([(0.0, 0, 0, 0), (0.005, 0.115, 0.115, 0.115), (0.012, 0, 0, 0)], 18, 2.0)
    G.xf(calsurf, loc=tuple(bc + Vector((0, 0, 0.085)))); F.add(calsurf, 'cal', 'mola_balde', spec=0.8, oline=0.0)
    hdl = [bc + Vector((0.125 * math.cos(a_), 0, 0.10 + 0.12 * math.sin(a_))) for a_ in (0.0, math.pi / 2, math.pi)]
    F.add(G.tube(tuple(hdl[0]), tuple(hdl[1]), [(0, 0.008), (1, 0.008)], 6), 'ferro', 'mola_balde', spec=0.2, mat=1.0, oline=0.6)
    F.add(G.tube(tuple(hdl[1]), tuple(hdl[2]), [(0, 0.008), (1, 0.008)], 6), 'ferro', 'mola_balde', spec=0.2, mat=1.0, oline=0.6)
    for dx in (-0.06, 0.07):  # escorridos de cal
        F.add(G.tube(tuple(bc + Vector((dx, -0.115, 0.095))), tuple(bc + Vector((dx * 1.1, -0.122, 0.0))), [(0, 0.012), (0.8, 0.012), (1, 0.0)], 6, flat=0.4), 'cal', 'mola_balde', spec=0.8, oline=0.0)
    F.meta = face_meta(BS, face_size=[0.88, 0.56], t_eyes=0.355, t_mouth=0.66, eye_gap=0.052, eye_w=0.019, eye_h=0.03, mouth_w=0.035)
    F.meta['player_regions'] = [['chapeu', 0]]
    return F

# ================================================================== NINA CATAVENTO (Lufada)
def nina():
    """Dois círculos: corpo pequeno e redondo, cata-vento gigante nas costas (mola)."""
    J = dict(hips=(0, 0, 0.30), spine=(0, 0, 0.38), chest=(0, 0, 0.46), neck=(0, -0.01, 0.56), head=(0, -0.02, 0.60), head_top=(0, -0.02, 0.96),
             clav=(0.05, 0, 0.53), sh=(0.15, 0.0, 0.53), el=(0.20, 0.0, 0.41), wr=(0.23, -0.02, 0.30), hd=(0.24, -0.03, 0.24),
             hip_j=(0.07, 0, 0.28), knee=(0.08, 0, 0.17), ankle=(0.08, 0.0, 0.06), toe=(0.08, -0.08, 0.02))
    extra = [('mola_catavento', (0, 0.17, 0.50), (0, 0.22, 1.40), 'chest'), ('mola_saia_F', (0, -0.08, 0.32), (0, -0.2, 0.08), 'hips'), ('mola_saia_B', (0, 0.08, 0.32), (0, 0.2, 0.08), 'hips'),
             ('mola_lenco', (0, 0.05, 0.86), (0, 0.15, 0.70), 'head')]
    F = G.Fig(humanoid_bones(J, extra), seed=31)
    F.head_xf(J['head'], 1.2, (0, 0, 0), ('head', 'mola_lenco'))
    A = F.atlas
    A.region('liso', 64, 64, lambda w, h: PT.navy(w, h, 31))
    A.region('pele', 64, 64, lambda w, h: PT.skin(w, h, 32))
    A.region('vestido', 384, 192, lambda w, h: PT.navy(w, h, 33, PT.compose_deco(PT.deco_dots(34, 6.5, rows=(0.1, 0.85)), PT.deco_scallops(0.9, 10, 0.06, 3.2))))
    A.region('cabeca', 256, 192, lambda w, h: PT.face_region(w, h, 34, face_s=(0.30, 0.70), face_t=(0.16, 1.0), hair=PT.subtract(PT.deco_hair(0.5, 0.16, 0.24, 8))))
    A.region('pa', 128, 128, lambda w, h: PT.white_panel(w, h, 35, PT.compose_deco(PT.deco_bands([0.12], 3), PT.deco_folds(4, 0.2, 0.9, 3, load=0.36))))
    A.region('roxo', 64, 64, lambda w, h: PT.accent('roxo', w, h, 36))
    A.region('madeira', 64, 256, lambda w, h: PT.wood(w, h, 37))
    A.region('sapato', 64, 32, lambda w, h: PT.navy(w, h, 38))
    dress = [(0.06, 0, 0, 0), (0.065, 0.16, 0.15, 0.15), (0.12, 0.24, 0.22, 0.22), (0.24, 0.27, 0.25, 0.25), (0.38, 0.24, 0.22, 0.22), (0.50, 0.17, 0.15, 0.15), (0.57, 0.08, 0.07, 0.07), (0.59, 0, 0, 0)]
    def w_dress(co):
        k = 0.7 * (1 - smooth_w(co.z, 0.08, 0.3))
        return {'chest' if co.z > 0.42 else 'hips': 1 - k, ('mola_saia_F' if co.y < 0 else 'mola_saia_B'): k}
    F.add(G.loft(dress, 24, 2.0), 'vestido', weights=w_dress)
    head = [(0.56, 0, 0, 0, 0, -0.02), (0.58, 0.10, 0.09, 0.08, 0, -0.02), (0.63, 0.17, 0.155, 0.14, 0, -0.02), (0.72, 0.19, 0.17, 0.17, 0, -0.02),
            (0.81, 0.185, 0.165, 0.175, 0, -0.02), (0.89, 0.15, 0.135, 0.15, 0, -0.02), (0.94, 0.08, 0.075, 0.08, 0, -0.02), (0.955, 0, 0, 0, 0, -0.02)]
    F.add(G.loft(head, 24, 2.1), 'cabeca', 'head')
    nose = G.sphere(1.0, 10, 7); G.xf(nose, scale=(0.025, 0.022, 0.022), loc=(0, -0.19, 0.71)); F.add(nose, 'pele', 'head')
    for sx in (1, -1):  # marias-chiquinhas (mola)
        F.add(G.tube((sx * 0.15, 0.06, 0.86), (sx * 0.30, 0.10, 0.74), [(0, 0.0), (0.15, 0.05), (0.6, 0.055), (1, 0.0)], 10), 'liso', 'mola_lenco')
    arm(F, J, 'L', 'liso', puff=0.06, r_up=0.04, r_fo=0.034, grip=False, hand_size=0.95)
    arm(F, J, 'R', 'liso', puff=0.06, r_up=0.04, r_fo=0.034, grip=False, hand_size=0.95)
    for s, sx in (('L', 1), ('R', -1)):
        F.add(G.tube((sx * 0.08, 0, 0.14), (sx * 0.08, 0, 0.05), [(0, 0.035), (1, 0.035)], 8), 'pele', 'shin.' + s)
        sh = G.loft([(0.0, 0, 0, 0), (0.005, 0.045, 0.08, 0.045), (0.05, 0.045, 0.085, 0.045), (0.055, 0, 0, 0)], 12, 2.4); G.xf(sh, loc=(sx * 0.08, -0.03, 0)); F.add(sh, 'sapato', 'foot.' + s)
    # cata-vento: haste e 4 pás em quarto de volta (branco-leite com borda roxa), na mola das costas
    top = (0, 0.24, 1.30)
    F.add(G.tube((0, 0.17, 0.48), top, [(0, 0.016), (1, 0.016)], 8), 'madeira', 'mola_catavento', spec=0.0, mat=0.75)
    import bmesh as BM
    for k in range(4):
        a = k * math.pi / 2
        bm = BM.new(); uvl = bm.loops.layers.uv.new('UVMap')
        R = 0.42
        pts = [(0, 0), (R * math.cos(a), R * math.sin(a)), (R * 0.72 * math.cos(a + 0.9), R * 0.72 * math.sin(a + 0.9))]
        vf = [bm.verts.new((top[0] + x, top[1] - 0.012, top[2] + z)) for x, z in pts]
        vb = [bm.verts.new((top[0] + x, top[1] + 0.012, top[2] + z)) for x, z in pts]
        faces = [vf, list(reversed(vb))] + [[vf[j], vf[(j + 1) % 3], vb[(j + 1) % 3], vb[j]] for j in range(3)]
        for fv in faces:
            f = bm.faces.new(fv)
            for lo in f.loops:
                co = lo.vert.co
                lo[uvl].uv = (min(1, max(0, (co.x - top[0]) / (2 * R) + 0.5)), min(1, max(0, (co.z - top[2]) / (2 * R) + 0.5)))
        BM.ops.recalc_face_normals(bm, faces=bm.faces[:])
        F.add(bm, 'pa', 'mola_catavento', smooth=False)
        F.add(G.tube((top[0] + pts[1][0], top[1] - 0.014, top[2] + pts[1][1]), (top[0] + pts[2][0], top[1] - 0.014, top[2] + pts[2][1]), [(0, 0.012), (1, 0.012)], 6), 'roxo', 'mola_catavento', oline=0.5)
    hub = G.sphere(1.0, 10, 7); G.xf(hub, scale=(0.04, 0.04, 0.04), loc=(top[0], top[1] - 0.02, top[2])); F.add(hub, 'roxo', 'mola_catavento')
    F.meta = face_meta(1.2, face_size=[1.1, 0.48], t_eyes=0.42, t_mouth=0.66, eye_gap=0.07, eye_w=0.028, eye_h=0.042, mouth_w=0.045)
    F.meta['player_regions'] = [['pa', 0]]
    return F

# ================================================================== SEU GALVÃO (Faísca)
def galvao():
    """Ponto de interrogação: corcunda, garrafa de Leyden nas costas, vareta alta na mão."""
    J = dict(hips=(0, 0, 0.62), spine=(0, 0.02, 0.74), chest=(0, 0.04, 0.88), neck=(0, -0.08, 1.06), head=(0, -0.14, 1.10), head_top=(0, -0.16, 1.42),
             clav=(0.05, 0.02, 1.0), sh=(0.17, 0.03, 0.98), el=(0.23, -0.02, 0.78), wr=(0.26, -0.08, 0.60), hd=(0.27, -0.09, 0.52),
             hip_j=(0.08, 0, 0.60), knee=(0.09, -0.02, 0.33), ankle=(0.09, 0.0, 0.08), toe=(0.09, -0.15, 0.02))
    hc = Vector(mirror(J['wr'])) + (Vector(mirror(J['hd'])) - Vector(mirror(J['wr']))).normalized() * 0.05
    extra = [('prop.R', tuple(hc), tuple(hc + Vector((0, 0, 0.3))), 'hand.R'), ('mola_garrafa', (0, 0.22, 0.95), (0, 0.30, 0.65), 'chest'),
             ('mola_saia_F', (0, -0.08, 0.6), (0, -0.2, 0.25), 'hips'), ('mola_saia_B', (0, 0.1, 0.6), (0, 0.25, 0.25), 'hips'), ('mola_chapeu', (0, -0.16, 1.36), (0, -0.16, 1.5), 'head')]
    F = G.Fig(humanoid_bones(J, extra), seed=41)
    F.head_xf(J['head'], HEAD_S, (0, 0.0, 0), ('head', 'mola_chapeu'))
    A = F.atlas
    A.region('liso', 64, 64, lambda w, h: PT.navy(w, h, 41))
    A.region('pele', 64, 64, lambda w, h: PT.skin(w, h, 42))
    A.region('casaco', 384, 256, lambda w, h: PT.navy(w, h, 43, PT.compose_deco(PT.deco_bands([0.92], 5), PT.deco_folds(6, 0.1, 0.9, 5, load=0.6),
        lambda D, w, h, r: [PT.K.stroke(D, [(w / 2 + 0.5, y), (w / 2 - 0.5, y + 1)], 4.5, 4, load=1.0, pool=0.2, seed=int(y)) for y in (h * 0.2, h * 0.35, h * 0.5, h * 0.65)])))
    A.region('cabeca', 256, 192, lambda w, h: PT.face_region(w, h, 44, face_s=(0.28, 0.72), face_t=(0.10, 1.1)))
    A.region('barba', 128, 128, lambda w, h: PT.white_panel(w, h, 45, PT.deco_folds(7, 0.1, 0.95, 3, load=0.34)))
    A.region('bone', 192, 96, lambda w, h: PT.navy(w, h, 46, PT.deco_bands([0.72], 7)))
    A.region('vidro', 128, 128, lambda w, h: PT.white_panel(w, h, 47, PT.compose_deco(PT.deco_bands([0.62, 0.9], 4), PT.deco_folds(5, 0.05, 0.55, 2.5, load=0.36))))
    A.region('faisca', 64, 64, lambda w, h: PT.accent('faisca', w, h, 48, stripes=2))
    A.region('ferro', 64, 64, lambda w, h: PT.iron(w, h, 49))
    A.region('bota', 64, 64, lambda w, h: PT.navy(w, h, 50))
    coat = [(0.30, 0.20, 0.18, 0.19, 0, 0.02), (0.45, 0.19, 0.17, 0.18, 0, 0.02), (0.65, 0.18, 0.16, 0.18, 0, 0.03), (0.80, 0.19, 0.15, 0.22, 0, 0.06),
            (0.92, 0.19, 0.13, 0.24, 0, 0.06), (1.00, 0.16, 0.10, 0.20, 0, 0.03), (1.06, 0.09, 0.07, 0.10, 0, -0.04), (1.08, 0, 0, 0, 0, -0.06)]
    def w_coat(co):
        if co.z > 0.72:
            return {'spine': 1 - smooth_w(co.z, 0.74, 0.88), 'chest': smooth_w(co.z, 0.74, 0.88)}
        k = 0.75 * (1 - smooth_w(co.z, 0.35, 0.62))
        return {'hips': 1 - k, ('mola_saia_F' if co.y < 0 else 'mola_saia_B'): k}
    F.add(G.loft(coat, 24, 2.1), 'casaco', weights=w_coat)
    for s, sx in (('L', 1), ('R', -1)):
        F.add(G.tube((sx * 0.08, 0, 0.40), (sx * 0.09, 0.0, 0.10), G.capsule(0.05, 0.045), 10), 'liso', 'shin.' + s)
        bt = G.loft([(0.0, 0, 0, 0, 0, -0.03), (0.005, 0.055, 0.13, 0.055, 0, -0.03), (0.06, 0.06, 0.13, 0.06, 0, -0.03), (0.11, 0.05, 0.05, 0.05), (0.115, 0, 0, 0)], 12, 2.3)
        G.xf(bt, loc=(sx * 0.09, -0.02, 0)); F.add(bt, 'bota', 'foot.' + s)
    arm(F, J, 'L', 'liso', puff=0.0, r_up=0.05, r_fo=0.042, grip=False, hand_size=1.1)
    arm(F, J, 'R', 'liso', puff=0.0, r_up=0.05, r_fo=0.042, grip=True, hand_size=1.1)
    head = [(1.08, 0, 0, 0, 0, -0.16), (1.10, 0.08, 0.07, 0.06, 0, -0.17), (1.15, 0.13, 0.12, 0.11, 0, -0.16), (1.22, 0.145, 0.14, 0.14, 0, -0.16),
            (1.30, 0.14, 0.13, 0.145, 0, -0.16), (1.36, 0.11, 0.105, 0.12, 0, -0.16), (1.40, 0, 0, 0, 0, -0.16)]
    F.add(G.loft(head, 22, 2.1), 'cabeca', 'head')
    F.add(G.tube((0, -0.29, 1.24), (0, -0.35, 1.17), [(0, 0.0), (0.2, 0.034), (0.7, 0.03), (1, 0.0)], 10), 'pele', 'head')
    beard = G.loft([(0.98, 0, 0, 0, 0, -0.22), (1.0, 0.08, 0.06, 0.05, 0, -0.24), (1.06, 0.13, 0.09, 0.07, 0, -0.24), (1.14, 0.14, 0.10, 0.08, 0, -0.22), (1.19, 0.12, 0.05, 0.06, 0, -0.2), (1.2, 0, 0, 0, 0, -0.2)], 18, 2.0, fold=lambda i, th: 1 + 0.06 * math.sin(9 * th))
    F.add(beard, 'barba', 'head')
    for sx in (1, -1):  # sobrancelhas fartas
        F.add(G.tube((sx * 0.03, -0.29, 1.29), (sx * 0.12, -0.26, 1.31), [(0, 0.0), (0.2, 0.025), (0.8, 0.02), (1, 0.0)], 8, flat=0.5), 'barba', 'head', oline=0.7)
    cap = G.loft([(1.32, 0, 0, 0, 0, -0.16), (1.325, 0.15, 0.15, 0.15, 0, -0.16), (1.40, 0.155, 0.155, 0.155, 0, -0.16), (1.44, 0.14, 0.14, 0.14, 0, -0.16), (1.445, 0, 0, 0, 0, -0.16)], 20, 2.0)
    F.add(cap, 'bone', 'mola_chapeu')
    pala = G.loft([(1.33, 0, 0, 0), (1.335, 0.13, 0.10, 0.02), (1.345, 0.13, 0.10, 0.02), (1.35, 0, 0, 0)], 16, 2.0); G.xf(pala, loc=(0, -0.29, 0)); F.add(pala, 'liso', 'mola_chapeu')
    # garrafa de Leyden nas costas (mola)
    jar = G.loft([(0.0, 0, 0, 0), (0.005, 0.11, 0.11, 0.11), (0.25, 0.12, 0.12, 0.12), (0.32, 0.07, 0.07, 0.07), (0.36, 0.05, 0.05, 0.05), (0.365, 0, 0, 0)], 16, 2.0)
    G.xf(jar, rot=(-12, 0, 0), loc=(0, 0.30, 0.62)); F.add(jar, 'vidro', 'mola_garrafa')
    F.add(G.tube((0, 0.34, 0.97), (0, 0.36, 1.12), [(0, 0.01), (1, 0.01)], 6), 'ferro', 'mola_garrafa', spec=0.3, mat=1.0, oline=0.6)
    kb = G.sphere(1.0, 10, 7); G.xf(kb, scale=(0.035, 0.035, 0.035), loc=(0, 0.36, 1.14)); F.add(kb, 'faisca', 'mola_garrafa', emit=0.5)
    # vareta de cobre (ferro com ponta de antimônio)
    a = hc + Vector((0, 0, -0.5)); b = hc + Vector((0, 0, 1.05))
    F.add(G.tube(tuple(a), tuple(b), [(0, 0), (0.01, 0.014), (0.99, 0.012), (1, 0)], 8), 'ferro', 'prop.R', spec=0.3, mat=1.0)
    tp = G.sphere(1.0, 10, 7); G.xf(tp, scale=(0.04, 0.04, 0.04), loc=tuple(b)); F.add(tp, 'faisca', 'prop.R', emit=0.6)
    F.meta = face_meta(HEAD_S, face_size=[0.9, 0.48], t_eyes=0.40, t_mouth=0.80, eye_gap=0.05, eye_w=0.016, eye_h=0.022, mouth_w=0.03)
    F.meta['player_regions'] = [['bone', 1], ['vidro', 0]]
    return F

HEROES = {'lamparina': lamparina, 'bento': bento, 'nina': nina, 'galvao': galvao}

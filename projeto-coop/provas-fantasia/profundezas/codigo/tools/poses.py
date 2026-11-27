# Poses-chave e ações de Plumbdeep (quadros a 60 fps, chaves CONSTANT: pose a pose, no ritmo de cada classe).
# Rotações em graus nos eixos do armature (X = esquerda do boneco, Y = costas, Z = cima):
#   rx < 0 leva para a FRENTE um osso que aponta para baixo (braço, perna); rx > 0 inclina para a frente um osso que
#   aponta para cima (coluna, cabeça); ry > 0 leva um osso pendurado para a direita do boneco (-X); rz > 0 gira a
#   frente para a esquerda do boneco. 's' é escala local do osso (x, ao longo do osso, z).
# Ritmos: Escorador 15 poses/s (4 quadros), Cristaleira 20 (3), Coveira 20 (3, turíbulo a 60 pela mola),
# Gancheiro 30 (2). Ouvidor 15, Bocalume 12.
# A ação 'poca' de cada herói é a linha do tempo inteira da cena "A Poça sob a Cascata" (quadro da ação = quadro da cena).
from animar import P_

def R(rx=0, ry=0, rz=0):
    return {'r': (rx, ry, rz)}

def RL(rx=0, ry=0, rz=0, l=(0, 0, 0)):
    return {'r': (rx, ry, rz), 'l': l}

def RS(rx=0, ry=0, rz=0, s=(1, 1, 1), l=None):
    d = {'r': (rx, ry, rz), 's': s}
    if l:
        d['l'] = l
    return d

def seq(lst):
    """lista de (pose, quadros segurados) -> [(quadro, pose)]"""
    out, f = [], 0
    for p, n in lst:
        out.append((f, p))
        f += n
    out.append((f, lst[-1][0]))
    return out

def lerp_pose(a, b, t):
    out = {}
    for k in set(a) | set(b):
        pa, pb = a.get(k, {}), b.get(k, {})
        d = {}
        for key, dv in (('r', (0, 0, 0)), ('l', (0, 0, 0)), ('s', (1, 1, 1))):
            if key in pa or key in pb:
                va, vb = pa.get(key, dv), pb.get(key, dv)
                d[key] = tuple(x + (y - x) * t for x, y in zip(va, vb))
        out[k] = d
    return out

def ease(t, kind):
    if kind == 'in':      # sai devagar
        return t * t
    if kind == 'out':     # chega devagar
        return 1 - (1 - t) ** 2
    if kind == 'io':
        return t * t * (3 - 2 * t)
    return t

def tl(keys, step):
    """linha do tempo: [(quadro, pose, easing_até_a_próxima)] -> chaves no ritmo 'step' (poses intermediárias
    interpoladas com aceleração e desaceleração, seguradas por 'step' quadros)."""
    out = []
    for i, k in enumerate(keys):
        f, p = k[0], k[1]
        kind = k[2] if len(k) > 2 else 'io'
        out.append((f, p))
        if i + 1 < len(keys) and kind != 'hold':
            f1, p1 = keys[i + 1][0], keys[i + 1][1]
            g = f + step
            while g < f1 - step * 0.5:
                out.append((g, lerp_pose(p, p1, ease((g - f) / (f1 - f), kind))))
                g += step
    out.append((keys[-1][0] + 1, keys[-1][1]))
    return out

def breath(base, n_hold, cycles, f0=0, amp=2.5, bone='chest'):
    a = base
    r = base.get(bone, {}).get('r', (0, 0, 0))
    b = P_(base, **{bone.replace('.', '_'): R(r[0] - amp, r[1], r[2])})
    rl = base.get('root', {})
    b['root'] = dict(rl, l=tuple(x + y for x, y in zip(rl.get('l', (0, 0, 0)), (0, 0, 0.006))))
    out = []
    for i in range(cycles * 2):
        out.append((f0 + i * n_hold, a if i % 2 == 0 else b))
    out.append((f0 + cycles * 2 * n_hold, a))
    return out

# ================================================================== ESCORADOR: a viga nos ombros como uma canga
ESC_G = {'root': RL(0, 0, 0, (0, 0, -0.01)), 'spine': R(4, 0, 0), 'chest': R(-2, 0, 0), 'head': R(-6, 0, 0),
         'upperarm.L': R(20, -118, 0), 'forearm.L': R(0, -72, 0), 'hand.L': R(0, 0, 0),
         'upperarm.R': R(20, 118, 0), 'forearm.R': R(0, 72, 0),
         'thigh.L': R(-4, -10, 0), 'shin.L': R(6, 0, 0), 'thigh.R': R(4, 10, 0), 'shin.R': R(6, 0, 0)}
# Escorar: finca a viga em pé à frente e se apoia nela
ESC_E = {'root': RL(0, 0, 0, (0, 0, -0.03)), 'spine': R(14, 0, 0), 'chest': R(6, 0, 10), 'head': R(-14, 0, -8),
         'viga': RL(0, 90, 0, (0.05, -0.3, 0.42)),
         'upperarm.L': R(-75, -10, 0), 'forearm.L': R(-30, 0, 0), 'upperarm.R': R(-60, 20, 0), 'forearm.R': R(-50, 0, 0),
         'thigh.L': R(-30, -10, 0), 'shin.L': R(35, 0, 0), 'thigh.R': R(20, 10, 0), 'shin.R': R(10, 0, 0)}

def escorador_idle():
    return breath(ESC_G, 16, 3)

def escorador_escorar():
    return breath(ESC_E, 16, 2)

# ================================================================== CRISTALEIRA: nervosa, orgulhosa, rápida demais
CRI_G = {'root': RL(0, 0, 0, (0, 0, 0)), 'spine': R(-2, 0, 0), 'chest': R(-4, 0, 6), 'head': R(-10, 0, -4),
         'upperarm.R': R(-25, 12, 0), 'forearm.R': R(-55, 0, 0), 'hand.R': R(80, 0, 0),
         'upperarm.L': R(10, -30, 0), 'forearm.L': R(-60, 30, 0), 'hand.L': R(0, 0, -20)}

def cristaleira_poca():
    g = CRI_G
    g2 = P_(g, chest=R(-6, 0, 6), head=R(-12, 0, -2), forearm_L=R(-70, 30, 0))
    # nojo: resina caindo nela (ombros sobem, cabeça vira, braços afastados do corpo, chapéu tomba)
    nj = P_(g, root=RS(0, 0, 0, (1.05, 0.93, 1.05)), spine=R(-6, 0, 0), chest=R(-10, 0, -10), head=R(10, 0, 26), hat=R(0, 14, -12),
            upperarm_L=R(-20, -60, 0), forearm_L=R(-40, 0, 0), hand_L=R(0, 0, 30), upperarm_R=R(-20, 40, 0), forearm_R=R(-40, 0, 0), hand_R=R(60, 0, 0))
    nj2 = P_(nj, head=R(14, 0, 30), chest=R(-12, 0, -12), hat=R(0, 10, -8))
    # antecipação do Estalo: cajado no alto, corpo esticado para trás (o chapéu estica)
    an = P_(g, root=RS(0, 0, 0, (0.94, 1.12, 0.94)), spine=R(-14, 0, 0), chest=R(-10, 0, 14), head=R(-20, 0, -6), hat=RS(-12, 0, 0, (1, 1.2, 1)),
            upperarm_R=R(-160, 10, 0), forearm_R=R(-25, 0, 0), hand_R=R(150, 0, 0), upperarm_L=R(-60, -40, 0), forearm_L=R(-30, 0, 0))
    # contato: crava o cajado na água (achata 0,85, o chapéu atrasa)
    ct = P_(g, root=RS(0, 0, 0, (1.12, 0.84, 1.12), (0, -0.03, -0.04)), spine=R(26, 0, 0), chest=R(10, 0, 8), head=R(6, 0, -4), hat=RS(18, 0, 0, (1, 0.9, 1)),
            upperarm_R=R(-62, 16, 0), forearm_R=R(-12, 0, 0), hand_R=R(74, 0, 0), upperarm_L=R(-30, -70, 0), forearm_L=R(-20, 0, 0), hand_L=R(0, 0, 40))
    ct2 = P_(ct, root=RS(0, 0, 0, (1.06, 0.92, 1.06), (0, -0.03, -0.03)), hat=RS(8, 0, 0, (1, 1.05, 1)))
    # pose de "olha só": queixo para cima, cajado erguido, mão na cintura (8 quadros parada, e mais)
    ex = P_(g, root=RS(0, 0, 0, (0.97, 1.05, 0.97)), spine=R(-8, 0, 0), chest=R(-10, 0, 14), head=R(-26, 0, -10), hat=RS(-6, 0, 0, (1, 1.08, 1)),
            upperarm_R=R(-172, 8, 0), forearm_R=R(-6, 0, 0), hand_R=R(178, 0, 0), upperarm_L=R(15, -42, 0), forearm_L=R(-20, 95, 0), hand_L=R(0, 0, 0))
    ex2 = P_(ex, head=R(-28, 0, -12))
    # espera o Prumo: olha para cima, mão esquerda aberta
    ol = P_(g, head=R(-30, 0, 18), chest=R(-6, 0, 12), upperarm_L=R(-120, -20, 0), forearm_L=R(-20, 0, 0), hand_L=R(-20, 0, 0))
    re = P_(g, root=RS(0, 0, 0, (0.95, 1.1, 0.95), (0, 0, 0.03)), spine=R(-10, 0, 0), head=R(-34, 0, 12), chest=R(-10, 0, 16),
            upperarm_L=R(-168, -14, 0), forearm_L=R(-8, 0, 0), hand_L=R(-10, 0, 0), upperarm_R=R(-30, 40, 0), forearm_R=R(-30, 0, 0))
    # pega (Para-raio): o Prumo trava no alto, corpo achata na pegada e estica
    pg = P_(re, root=RS(0, 0, 0, (1.07, 0.9, 1.07), (0, 0, -0.02)), upperarm_L=R(-160, -16, 0), forearm_L=R(-25, 0, 0))
    pr = P_(re, root=RS(0, 0, 0, (0.94, 1.14, 0.94), (0, 0, 0.02)), head=R(-36, 0, 6), hat=RS(-10, 0, 0, (1, 1.25, 1)), upperarm_L=R(-176, -6, 0), forearm_L=R(0, 0, 0))
    # arremesso: braço para trás, torce; depois o braço passa por cima em arco e o corpo estica 1,25 para a frente
    aa = P_(g, root=RL(0, 0, -24, (0, 0.02, -0.02)), spine=R(-10, 0, -10), chest=R(-12, 0, -26), head=R(-12, 0, 26),
            upperarm_L=R(55, -50, 0), forearm_L=R(-40, 0, 0), upperarm_R=R(-40, 40, 0), forearm_R=R(-30, 0, 0), hat=RS(-14, 0, 0, (1, 0.95, 1)))
    lan = P_(g, root=RS(0, 0, 20, (0.92, 1.18, 0.92), (0, -0.05, 0.0)), spine=RS(26, 0, 10, (1, 1.15, 1)), chest=R(14, 0, 26), head=R(0, 0, -10),
             upperarm_L=R(-130, -10, 0), forearm_L=R(-5, 0, 0), hand_L=R(-30, 0, 0), upperarm_R=R(-10, 50, 0), forearm_R=R(-20, 0, 0), hat=RS(26, 0, 0, (1, 1.4, 1)))
    fo = P_(g, root=RL(0, 0, 14, (0, -0.05, -0.02)), spine=R(30, 0, 0), chest=R(14, 0, 18), head=R(4, 0, -6),
            upperarm_L=R(-70, 20, 0), forearm_L=R(-5, 0, 0), upperarm_R=R(-10, 40, 0), forearm_R=R(-30, 0, 0), hat=RS(16, 0, 0, (1, 1.1, 1)))
    # olha a Cascata (à esquerda do quadro)
    oc = P_(g, head=R(-14, 0, 42), chest=R(-4, 0, 20))
    keys = [(0, g, 'hold'), (12, g2, 'hold'), (24, g, 'hold'),
            (36, nj, 'hold'), (39, nj2, 'hold'), (46, nj, 'in'), (55, an, 'in'), (58, ct, 'hold'), (64, ct2, 'out'), (76, g),
            (80, ex, 'hold'), (92, ex2, 'hold'), (104, ex, 'io'), (116, g, 'hold'), (128, g2, 'hold'),
            (138, ol, 'out'), (148, re, 'hold'), (155, pg, 'hold'), (158, pr, 'hold'), (162, aa, 'in'), (167, lan, 'hold'), (170, fo, 'out'), (184, g),
            (200, ex, 'hold'), (214, ex2, 'hold'), (228, g, 'hold'), (240, g2, 'hold'), (252, g, 'hold'), (264, g2, 'io'),
            (290, oc, 'hold'), (340, oc, 'hold')]
    return tl(keys, 3)

def cristaleira_idle():
    return breath(CRI_G, 9, 3, amp=3)

# ================================================================== COVEIRA: calma e seca
COV_G = {'root': RL(0, 0, 0, (0, 0, 0)), 'spine': R(0, 0, 0), 'chest': R(-2, 0, 0), 'head': R(-6, 0, 0),
         'upperarm.R': R(-12, 10, 0), 'forearm.R': R(-30, 0, 0), 'hand.R': R(42, 0, 0),
         'upperarm.L': R(-20, -10, 0), 'forearm.L': R(-80, 0, 0)}
COV_I = P_(COV_G, spine=R(6, 0, -10), chest=R(4, 0, -20), head=R(-10, 0, 12), upperarm_R=R(-70, 50, 0), forearm_R=R(-50, 0, 0), hand_R=R(110, 0, -20),
           upperarm_L=R(-50, -30, 0), forearm_L=R(-60, 0, 0), thigh_L=R(-20, -8, 0), shin_L=R(20, 0, 0), thigh_R=R(12, 8, 0))

def coveira_idle():
    return breath(COV_G, 12, 3)

def coveira_incensar():
    return breath(COV_I, 9, 3, amp=2)

# ================================================================== GANCHEIRO: exibido, ganancioso, sempre com pressa
GAN_G = {'root': RL(0, 0, 0, (0, 0, -0.025)), 'spine': R(14, 0, 0), 'chest': R(8, 0, -8), 'head': R(-22, 0, 10),
         'upperarm.R': R(-45, 22, 0), 'forearm.R': R(-55, 0, 0), 'upperarm.L': R(-35, -30, 0), 'forearm.L': R(-65, 0, 0),
         'thigh.L': R(-22, -8, 0), 'shin.L': R(28, 0, 0), 'thigh.R': R(16, 8, 0), 'shin.R': R(18, 0, 0), 'foot.R': R(-8, 0, 0)}

def gancheiro_poses():
    g = GAN_G
    g2 = P_(g, chest=R(4, 0, -8), root=RL(0, 0, 0, (0, 0, -0.02)))
    # Visgada: frasco na mão esquerda, braço para trás e baixo, depois passa por cima em arco
    va = P_(g, root=RS(0, 0, -20, (1.05, 0.92, 1.05), (0, 0.02, -0.04)), spine=R(4, 0, 0), chest=R(-6, 0, 28), head=R(-24, 0, -16),
            upperarm_L=R(55, -30, 0), forearm_L=R(-30, 0, 0), thigh_L=R(-10, -8, 0), thigh_R=R(30, 8, 0), shin_R=R(30, 0, 0))
    vl = P_(g, root=RS(0, 0, 18, (0.94, 1.1, 0.94), (0, -0.03, 0.0)), spine=R(20, 0, 0), chest=R(10, 0, -24), head=R(-26, 0, 6),
            upperarm_L=R(-150, -18, 0), forearm_L=R(-10, 0, 0), hand_L=R(-30, 0, 0), thigh_L=R(-36, -8, 0), shin_L=R(20, 0, 0), thigh_R=R(30, 8, 0))
    vf = P_(vl, upperarm_L=R(-110, -10, 0), chest=R(12, 0, -16), root=RS(0, 0, 10, (1.0, 1.0, 1.0), (0, -0.03, -0.01)))
    # risadinha: ombros sobem, mão na boca (ação secundária)
    ri = P_(g, chest=R(-4, 0, -6), head=R(-30, 0, 14), upperarm_L=R(-80, -10, 0), forearm_L=R(-120, 0, 0), root=RS(0, 0, 0, (0.98, 1.04, 0.98)))
    ri2 = P_(ri, head=R(-26, 0, 18), chest=R(-2, 0, -4))
    # corrida em passos de 2 quadros (30 poses/s): corpo à frente, pernas e braços alternando
    c1 = P_(g, root=RL(0, 0, 0, (0, 0, 0.02)), spine=R(28, 0, 0), chest=R(6, 0, 10), head=R(-30, 0, -6), thigh_L=R(-60, 0, 0), shin_L=R(60, 0, 0),
            thigh_R=R(40, 0, 0), shin_R=R(50, 0, 0), upperarm_L=R(40, -20, 0), upperarm_R=R(-70, 20, 0))
    c2 = P_(c1, root=RL(0, 0, 0, (0, 0, -0.01)), thigh_L=R(10, 0, 0), shin_L=R(70, 0, 0), thigh_R=R(-20, 0, 0), shin_R=R(10, 0, 0))
    c3 = P_(c1, chest=R(6, 0, -10), thigh_L=R(40, 0, 0), shin_L=R(50, 0, 0), thigh_R=R(-60, 0, 0), shin_R=R(60, 0, 0), upperarm_L=R(-70, -20, 0), upperarm_R=R(40, 20, 0))
    c4 = P_(c3, root=RL(0, 0, 0, (0, 0, -0.01)), thigh_L=R(-20, 0, 0), shin_L=R(10, 0, 0), thigh_R=R(10, 0, 0), shin_R=R(70, 0, 0))
    # punhais: golpe 1 (direita), golpe 2 (esquerda), estocadas com bote
    s1a = P_(g, root=RL(0, 0, -16, (0, 0.03, -0.04)), chest=R(4, 0, -26), upperarm_R=R(30, 40, 0), forearm_R=R(-90, 0, 0))
    s1 = P_(g, root=RS(0, 0, 18, (0.95, 1.06, 0.95), (0, -0.08, -0.04)), spine=R(30, 0, 0), chest=R(10, 0, 24), head=R(-18, 0, -8),
            upperarm_R=R(-100, 4, 0), forearm_R=R(-4, 0, 0), upperarm_L=R(10, -40, 0), forearm_L=R(-60, 0, 0),
            thigh_L=R(-55, -6, 0), shin_L=R(35, 0, 0), thigh_R=R(36, 8, 0), shin_R=R(10, 0, 0))
    s1r = P_(s1, upperarm_R=R(-70, 20, 0), forearm_R=R(-40, 0, 0), spine=R(22, 0, 0))
    s2 = P_(g, root=RS(0, 0, -20, (0.95, 1.06, 0.95), (0, -0.1, -0.04)), spine=R(30, 0, 0), chest=R(10, 0, -26), head=R(-18, 0, 8),
            upperarm_L=R(-100, -4, 0), forearm_L=R(-4, 0, 0), upperarm_R=R(20, 40, 0), forearm_R=R(-70, 0, 0),
            thigh_R=R(-55, 6, 0), shin_R=R(35, 0, 0), thigh_L=R(36, -8, 0), shin_L=R(10, 0, 0))
    # Lance do Prumo: tira das costas, arma baixo e atrás, solta por cima em arco alto
    la = P_(g, root=RS(0, 0, -30, (1.06, 0.9, 1.06), (0, 0.04, -0.05)), spine=R(6, 0, 0), chest=R(-8, 0, -30), head=R(-30, 0, 24),
            upperarm_R=R(60, 30, 0), forearm_R=R(-20, 0, 0), upperarm_L=R(-60, -40, 0), forearm_L=R(-30, 0, 0),
            thigh_L=R(-30, -8, 0), shin_L=R(40, 0, 0), thigh_R=R(20, 8, 0), shin_R=R(30, 0, 0))
    ll = P_(g, root=RS(0, 0, 24, (0.92, 1.15, 0.92), (0, -0.05, 0.02)), spine=R(18, 0, 0), chest=R(8, 0, 30), head=R(-36, 0, -10),
            upperarm_R=R(-160, 10, 0), forearm_R=R(-6, 0, 0), upperarm_L=R(-10, -60, 0), forearm_L=R(-20, 0, 0),
            thigh_L=R(-40, -8, 0), shin_L=R(20, 0, 0), thigh_R=R(30, 8, 0), shin_R=R(20, 0, 0), foot_R=R(-30, 0, 0))
    lf = P_(g, root=RL(0, 0, 18, (0, -0.07, -0.03)), spine=R(30, 0, 0), chest=R(12, 0, 24), head=R(-22, 0, -6),
            upperarm_R=R(-60, -30, 0), forearm_R=R(-10, 0, 0), upperarm_L=R(0, -50, 0), forearm_L=R(-30, 0, 0),
            thigh_L=R(-50, -6, 0), shin_L=R(30, 0, 0), thigh_R=R(30, 8, 0), shin_R=R(20, 0, 0))
    # puxa a linha (duas puxadas) e abraça o Prumo como a um saco de moedas
    p1 = P_(g, spine=R(10, 0, 0), upperarm_R=R(-80, 10, 0), forearm_R=R(-10, 0, 0), upperarm_L=R(-80, -10, 0), forearm_L=R(-10, 0, 0))
    p2 = P_(g, root=RL(0, 0, 0, (0, 0.03, -0.03)), spine=R(-12, 0, 0), chest=R(-6, 0, 0), head=R(-14, 0, 0), upperarm_R=R(10, 20, 0), forearm_R=R(-70, 0, 0),
            upperarm_L=R(10, -20, 0), forearm_L=R(-70, 0, 0), thigh_L=R(-30, -8, 0), shin_L=R(10, 0, 0), thigh_R=R(-6, 8, 0))
    ab = P_(g, root=RS(0, 0, 0, (1.06, 0.92, 1.06), (0, 0, -0.03)), spine=R(10, 0, 0), chest=R(-6, 0, 0), head=R(-20, 0, 16),
            upperarm_R=R(-60, -30, 0), forearm_R=R(-70, -40, 0), upperarm_L=R(-60, 30, 0), forearm_L=R(-70, 40, 0))
    ab2 = P_(ab, root=RS(0, 0, 8, (1.03, 0.96, 1.03), (0, 0, -0.03)), head=R(-24, 0, 22))
    oc = P_(g2, head=R(-16, 0, 40), chest=R(4, 0, 14))
    return dict(g=g, g2=g2, va=va, vl=vl, vf=vf, ri=ri, ri2=ri2, c1=c1, c2=c2, c3=c3, c4=c4, s1a=s1a, s1=s1, s1r=s1r, s2=s2, la=la, ll=ll, lf=lf,
                p1=p1, p2=p2, ab=ab, ab2=ab2, oc=oc)

def gancheiro_poca():
    k = gancheiro_poses()
    keys = [(0, k['g'], 'hold'), (2, k['va'], 'hold'), (8, k['vl'], 'hold'), (12, k['vf'], 'out'), (22, k['g'], 'hold'), (36, k['g2'], 'hold'),
            (56, k['ri'], 'hold'), (62, k['ri2'], 'hold'), (68, k['ri'], 'hold'), (74, k['ri2'], 'hold'), (84, k['g'], 'hold')]
    f = 96
    run = [k['c1'], k['c2'], k['c3'], k['c4']]
    i = 0
    while f < 110:
        keys.append((f, run[i % 4], 'hold')); f += 3; i += 1
    keys += [(110, k['s1a'], 'hold'), (112, k['s1'], 'hold'), (118, k['s1r'], 'hold'), (122, k['s2'], 'hold'), (128, k['la'], 'hold'),
             (136, k['ll'], 'hold'), (140, k['lf'], 'out'), (156, k['g'], 'hold'), (170, k['g2'], 'hold'), (184, k['ri'], 'hold'), (190, k['ri2'], 'hold'),
             (196, k['ri'], 'hold'), (204, k['g'], 'hold'), (226, k['p1'], 'hold'), (232, k['p2'], 'hold'), (238, k['p1'], 'hold'), (244, k['p2'], 'hold'),
             (256, k['ab'], 'hold'), (264, k['ab2'], 'hold'), (272, k['ab'], 'hold'), (280, k['ab2'], 'hold'), (292, k['oc'], 'hold'), (340, k['oc'], 'hold')]
    return tl(keys, 2)

def gancheiro_folha():
    """8 poses-chave do combo e do Lance do Prumo (folha de modelo): guarda, antecipação, golpe 1, golpe 2,
    arma o Lance, solta, continuidade, abraço."""
    k = gancheiro_poses()
    ps = [k['g'], k['s1a'], k['s1'], k['s2'], k['la'], k['ll'], k['lf'], k['ab']]
    return [(i, p) for i, p in enumerate(ps)] + [(len(ps), ps[-1])]

def gancheiro_idle():
    return breath(GAN_G, 6, 4, amp=3)

# ================================================================== OUVIDOR
OUV_G = {'root': RL(0, 0, 0, (0, 0, -0.02)), 'spine': R(10, 0, 0), 'head': R(6, 0, 0),
         'ear.L': R(0, 0, 0), 'ear.R': R(0, 0, 0),
         'upperarm.L': R(-20, -6, 0), 'forearm.L': R(-20, 0, 0), 'upperarm.R': R(-20, 6, 0), 'forearm.R': R(-20, 0, 0),
         'thigh.L': R(-30, -6, 0), 'shin.L': R(40, 0, 0), 'thigh.R': R(-30, 6, 0), 'shin.R': R(40, 0, 0)}

def ouvidor_acts():
    g = OUV_G
    # telegrafia (30 quadros): agacha, ergue a cabeça e as orelhas abrem para os lados (oval vira T)
    t0 = P_(g, root=RS(0, 0, 0, (1.1, 0.86, 1.1), (0, 0, -0.04)), spine=R(20, 0, 0), head=R(-10, 0, 0), ear_L=R(-10, 0, -40), ear_R=R(-10, 0, 40))
    t1 = P_(t0, head=R(-24, 0, 0), ear_L=R(-25, 0, -78), ear_R=R(-25, 0, 78), upperarm_L=R(-10, -40, 0), upperarm_R=R(-10, 40, 0),
            root=RS(0, 0, 0, (1.14, 0.82, 1.14), (0, 0, -0.05)))
    t2 = P_(t1, ear_L=R(-30, 0, -84), ear_R=R(-30, 0, 84))
    tele = seq([(g, 4), (t0, 4), (t1, 4), (t2, 4), (t1, 4), (t2, 4), (t1, 6)])
    # pulo-mordida: estica, braços e garras à frente, orelhas varridas para trás
    p = P_(g, root=RS(-30, 0, 0, (0.9, 1.22, 0.9)), spine=R(10, 0, 0), head=R(-20, 0, 0), ear_L=R(-70, -10, 50), ear_R=R(-70, 10, -50),
           upperarm_L=R(-130, -20, 0), forearm_L=R(-10, 0, 0), upperarm_R=R(-130, 20, 0), forearm_R=R(-10, 0, 0),
           thigh_L=R(30, 0, 0), shin_L=R(30, 0, 0), thigh_R=R(40, 0, 0), shin_R=R(20, 0, 0))
    # eletrocutado no ar: braços e pernas abertos, rígido (o motor congela 18 quadros e mostra o "esqueleto")
    e = P_(g, root=RS(-10, 0, 0, (1.0, 1.0, 1.0)), spine=R(-20, 0, 0), head=R(-30, 0, 0), ear_L=R(-50, 0, -95), ear_R=R(-50, 0, 95),
           upperarm_L=R(-60, -90, 0), forearm_L=R(0, -20, 0), upperarm_R=R(-60, 90, 0), forearm_R=R(0, 20, 0),
           thigh_L=R(-40, -40, 0), shin_L=R(10, 0, 0), thigh_R=R(-40, 40, 0), shin_R=R(10, 0, 0))
    e2 = P_(e, upperarm_L=R(-70, -80, 0), upperarm_R=R(-50, 100, 0), head=R(-26, 0, 6))
    # atordoado na água: sentado e torto, orelhas murchas
    a = P_(g, root=RL(0, 0, 0, (0, 0, -0.12)), spine=R(36, 0, 14), head=R(30, 0, -20), ear_L=R(30, 30, -20), ear_R=R(30, -30, 20),
           upperarm_L=R(-10, -30, 0), forearm_L=R(-10, 0, 0), upperarm_R=R(-30, 20, 0), forearm_R=R(-20, 0, 0),
           thigh_L=R(-80, -30, 0), shin_L=R(70, 0, 0), thigh_R=R(-80, 30, 0), shin_R=R(80, 0, 0))
    a2 = P_(a, head=R(36, 0, -10), spine=R(40, 0, 8))
    # golpeado: cabeça para trás, braços abertos, achata
    gp = P_(g, root=RS(14, 0, 0, (1.12, 0.84, 1.12), (0, 0.05, -0.03)), spine=R(-20, 0, 0), head=R(-30, 0, 10), ear_L=R(-40, 0, -70), ear_R=R(-40, 0, 70),
            upperarm_L=R(-40, -70, 0), upperarm_R=R(-40, 70, 0))
    # levanta da água (alvo do Gancheiro)
    lv = P_(g, root=RL(0, 0, 0, (0, 0, -0.06)), spine=R(30, 0, 0), head=R(10, 0, 0), thigh_L=R(-60, -10, 0), shin_L=R(70, 0, 0), thigh_R=R(-40, 10, 0), shin_R=R(60, 0, 0),
            upperarm_L=R(-30, -10, 0), upperarm_R=R(-30, 10, 0))
    return {'idle': seq([(g, 8), (P_(g, spine=R(12, 0, 0), head=R(8, 0, 4)), 8)] * 3), 'telegrafa': tele,
            'pulo': [(0, p), (1, p)], 'eletro': seq([(e, 2), (e2, 2)] * 6), 'atordoado': seq([(a, 10), (a2, 10)] * 4),
            'golpeado': [(0, gp), (1, gp)], 'levanta': seq([(a, 4), (lv, 8), (g, 4)]),
            'folha': [(0, g), (1, t2), (2, p), (3, e), (4, a), (5, a)]}

# ================================================================== BOCALUME
BOC_G = {'root': RL(0, 0, 0, (0, 0, 0)), 'cabeca': R(0, 0, 0), 'haste1': R(0, 0, 0)}
def bocalume_acts():
    g = BOC_G
    g2 = P_(g, corpo=RS(0, 0, 0, (1.02, 1.0, 1.04)), cabeca=R(-4, 0, 3), haste1=R(-6, 0, 4))
    # telegrafia (36 quadros): contrai (0,7), cabeça baixa; a isca apaga (motor)
    c0 = P_(g, root=RS(0, 0, 0, (1.08, 0.82, 1.08)), cabeca=R(12, 0, 0), haste1=R(14, 0, 0))
    c1 = P_(g, root=RS(0, 0, 0, (1.16, 0.7, 1.16)), cabeca=R(18, 0, 0), haste1=R(24, 0, 0), cauda1=R(-10, 0, 0))
    # cospe: estica e ergue a cabeça
    cs = P_(g, root=RS(0, 0, 0, (0.92, 1.16, 0.92)), cabeca=R(-24, 0, 0), haste1=R(-30, 0, 0), cauda1=R(8, 0, 0))
    cs2 = P_(cs, root=RS(0, 0, 0, (0.98, 1.06, 0.98)), cabeca=R(-14, 0, 0))
    # golpeado: recua e perde a casca de cima (motor)
    gp = P_(g, root=RS(0, 0, 0, (1.1, 0.8, 1.1), (0, 0.15, 0)), cabeca=R(20, 0, 10), haste1=R(30, 0, 0))
    return {'idle': seq([(g, 10), (g2, 10)] * 3), 'telegrafa': seq([(g, 5), (c0, 5), (c1, 26)]), 'cospe': seq([(cs, 10), (cs2, 20)]),
            'golpeado': seq([(gp, 20)]), 'folha': [(0, g), (1, c1), (2, cs)]}

OA = ouvidor_acts(); BA = bocalume_acts()
ACTIONS = {
    'escorador': {'idle': escorador_idle(), 'escorar': escorador_escorar()},
    'cristaleira': {'idle': cristaleira_idle(), 'poca': cristaleira_poca()},
    'coveira': {'idle': coveira_idle(), 'incensar': coveira_incensar()},
    'gancheiro': {'idle': gancheiro_idle(), 'poca': gancheiro_poca(), 'folha': gancheiro_folha()},
    'ouvidor': OA,
    'bocalume': BA,
}

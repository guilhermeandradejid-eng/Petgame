# Poses-chave e ações da prova Wickwain (quadros a 60 fps, chaves CONSTANT: pose a pose, segurando cada pose
# no ritmo da classe). Rotações em graus nos eixos do armature (X = esquerda do boneco, Y = costas, Z = cima):
#   rx < 0 leva um osso que aponta para baixo para a FRENTE (braço, perna); rx > 0 inclina para a frente um osso
#   que aponta para cima (coluna, cabeça); ry > 0 leva um osso pendurado para a direita do boneco (-X);
#   rz > 0 gira a frente para a esquerda do boneco. 's' é escala local do osso (x, ao longo do osso, z).
# Ritmos: Rodeira 12 poses/s (5 quadros, poses seguradas longas), Pavieiro 15 (4 quadros, tremor entre poses),
# Sineira 10 (6 quadros, solene), Gatuno 20 (3 quadros), Fuligento 15, Apagador 10.
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

def respira(base, k, n_hold, bone='chest', amp=3.0, ciclos=3):
    a = P_(base, **{bone: R(*(base.get(bone, {}).get('r', (0, 0, 0))))})
    b = P_(base, **{bone: R(base.get(bone, {}).get('r', (0, 0, 0))[0] - amp, *base.get(bone, {}).get('r', (0, 0, 0))[1:])})
    b = P_(b, root=RL(*base.get('root', {}).get('r', (0, 0, 0)), l=tuple(x + y for x, y in zip(base.get('root', {}).get('l', (0, 0, 0)), (0, 0, 0.008)))))
    return seq([(a, n_hold), (b, n_hold)] * ciclos)

# ================================================================== RODEIRA
ROD_G = {
    'root': RL(0, 0, 0, (0, 0, -0.015)), 'hips': R(0, 0, -8), 'spine': R(6, 0, 0), 'chest': R(4, 0, 10), 'head': R(-8, 0, -6),
    'thigh.L': R(-18, -8, 0), 'shin.L': R(22, 0, 0), 'thigh.R': R(10, 8, 0), 'shin.R': R(12, 0, 0), 'foot.R': R(-10, 0, 0),
    'upperarm.L': R(-25, -20, 0), 'forearm.L': R(-35, 0, 0),
    'upperarm.R': R(-15, 20, 0), 'forearm.R': R(-40, 0, 0),
}

def rodeira_eixo():
    g = ROD_G
    # antecipação: agacha olhando a lanterna que vem pelo alto
    a1 = P_(g, root=RS(0, 0, 0, (1.08, 0.86, 1.08), (0, 0.02, -0.06)), spine=R(14, 0, 0), chest=R(6, 0, 18), head=R(-28, 0, -14),
            thigh_L=R(-42, -10, 0), shin_L=R(55, 0, 0), thigh_R=R(-10, 12, 0), shin_R=R(42, 0, 0),
            upperarm_R=R(25, 30, 0), forearm_R=R(-60, 0, 0), upperarm_L=R(-60, -25, 0))
    # estica: pulinho, braço direito alto, corpo comprido (arco do pulso ao alto)
    a2 = P_(g, root=RS(0, 0, 0, (0.92, 1.14, 0.92), (0, 0.0, 0.06)), spine=R(-10, 0, 0), chest=R(-12, 0, 16), head=R(-34, 0, -10),
            thigh_L=R(-10, -6, 0), shin_L=R(18, 0, 0), thigh_R=R(18, 10, 0), shin_R=R(30, 0, 0), foot_R=R(-30, 0, 0),
            upperarm_R=R(-168, 18, 0), forearm_R=R(-12, 0, 0), upperarm_L=R(-40, -40, 0), forearm_L=R(-30, 0, 0))
    # contato: pega (segura igual, a mão fecha)
    ct = P_(a2, chest=R(-8, 0, 14), upperarm_R=R(-160, 15, 0), forearm_R=R(-25, 0, 0), head=R(-28, 0, -8))
    # crava: desce a lanterna no lodo, achata 0,8, linha de ação curva do pé ao elmo
    pl = P_(g, root=RS(0, 0, 0, (1.12, 0.8, 1.12), (0, -0.02, -0.07)), hips=R(0, 0, -16), spine=R(14, 0, 0), chest=R(6, 0, 24), head=R(-30, 0, -18),
            thigh_L=R(-55, -14, 0), shin_L=R(70, 0, 0), foot_L=R(-10, 0, 0), thigh_R=R(12, 16, 0), shin_R=R(40, 0, 0), foot_R=R(-24, 0, 0),
            upperarm_R=R(-62, 25, 0), forearm_R=R(-8, 0, 0), upperarm_L=R(-75, -35, 0), forearm_L=R(-30, 0, 0), roda=RS(0, 0, 0, (1 / 1.12, 1 / 0.8, 1 / 1.12)))
    pl2 = P_(pl, root=RS(0, 0, 0, (1.05, 0.9, 1.05), (0, -0.02, -0.06)), roda=RS(0, 0, 0, (1 / 1.05, 1 / 0.9, 1 / 1.05)))
    # Eixo: gira em volta da lanterna cravada, roda aberta varrendo (o motor gira o corpo)
    gi = P_(g, root=RL(0, 0, 0, (0, 0.0, -0.04)), hips=R(0, 0, 20), spine=R(18, -14, 0), chest=R(10, -10, 30), head=R(-6, 0, 20),
            thigh_L=R(-50, -10, 0), shin_L=R(40, 0, 0), thigh_R=R(30, 10, 0), shin_R=R(30, 0, 0),
            upperarm_R=R(-50, 40, 0), forearm_R=R(-10, 0, 0), upperarm_L=R(-30, -95, 0), forearm_L=R(-10, 0, 0))
    gi2 = P_(gi, thigh_L=R(20, -10, 0), shin_L=R(40, 0, 0), thigh_R=R(-45, 10, 0), shin_R=R(30, 0, 0), chest=R(10, -10, 36))
    # continuidade: o elmo gira meio quarto de volta e cai sobre o olho
    ft = P_(g, root=RL(0, 0, 0, (0, 0, -0.02)), spine=R(4, 0, 0), chest=R(2, 0, 6), head=R(-6, 0, 4), hat=R(14, -10, 16),
            upperarm_R=R(-30, 30, 0), forearm_R=R(-30, 0, 0))
    # empurra o elmo com o dedo, e sorri
    dd = P_(ft, hat=R(7, -5, 8), head=R(-10, 0, 6), upperarm_R=R(-135, 5, 0), forearm_R=R(-115, 0, 0), hand_R=R(0, 0, 0))
    st = P_(g, hat=R(0, 0, 0), head=R(-12, 0, 2), upperarm_R=R(-20, 22, 0), forearm_R=R(-35, 0, 0))
    return seq([(g, 30), (a1, 15), (a2, 5), (ct, 10), (pl, 5), (pl2, 15), (gi, 5), (gi2, 5), (gi, 5), (gi2, 5), (ft, 25), (dd, 20), (st, 30)])

def rodeira_folha():
    """as 8 poses-chave da recepção Eixo, cada uma por 1 quadro (folha de modelo)."""
    k = rodeira_eixo()
    idx = [0, 1, 2, 3, 4, 6, 10, 11]
    return [(i, k[j][1]) for i, j in enumerate(idx)] + [(len(idx), k[idx[-1]][1])]

# ================================================================== PAVIEIRO
PAV_G = {
    'root': RL(0, 0, 0, (0, 0, -0.01)), 'spine': R(4, 0, 0), 'chest': R(-2, 0, -6), 'head': R(-10, 0, 4),
    'upperarm.R': R(-10, 15, 0), 'forearm.R': R(-50, 0, 0), 'upperarm.L': R(-40, -25, 0), 'forearm.L': R(-60, 0, 0),
    'thigh.L': R(-6, -4, 0), 'shin.L': R(8, 0, 0), 'thigh.R': R(4, 4, 0), 'shin.R': R(6, 0, 0),
}

def tremor(p, k):
    """tremor fino entre poses (mãos e cabeça), alternando a cada 2 quadros."""
    d = 1.6 if k % 2 else -1.6
    out = P_(p)
    for b in ('hand.L', 'hand.R', 'head'):
        r = list(out.get(b, {}).get('r', (0, 0, 0)))
        r[2] += d
        r[0] += d * 0.5
        out[b] = dict(out.get(b, {}), r=tuple(r))
    return out

def pavieiro_lance():
    g = PAV_G
    # antecipação: torce para a direita, lanterna para trás, mão esquerda apontando o óleo
    a1 = P_(g, root=RL(0, 0, -20, (0, 0.02, -0.04)), spine=R(-4, 0, -18), chest=R(-10, 0, -22), head=R(-12, 0, 30),
            upperarm_R=R(45, 45, 0), forearm_R=R(-30, 0, 0), upperarm_L=R(-85, -20, 0), forearm_L=R(-10, 0, 0),
            thigh_L=R(-24, -6, 0), shin_L=R(30, 0, 0), thigh_R=R(14, 8, 0), shin_R=R(22, 0, 0), hat=RS(-8, 0, 0, (1, 0.94, 1)))
    a2 = P_(a1, chest=R(-12, 0, -30), upperarm_R=R(55, 55, 0))
    # Lance: o braço passa por cima, em arco largo; a lanterna sai da mão
    la = P_(g, root=RL(0, 0, 18, (0, -0.02, -0.02)), spine=R(14, 0, 14), chest=R(12, 0, 24), head=R(-6, 0, 16),
            upperarm_R=R(-150, -20, 0), forearm_R=R(-10, 0, 0), upperarm_L=R(-50, -40, 0), forearm_L=R(-20, 0, 0),
            thigh_L=R(-30, -6, 0), shin_L=R(20, 0, 0), thigh_R=R(30, 8, 0), shin_R=R(20, 0, 0), foot_R=R(-30, 0, 0), hat=RS(10, 0, 0, (1, 1.06, 1)))
    # Fagulha: a mão esquerda empurra para a frente em arco largo, a direita cruza o corpo
    fa = P_(la, root=RL(0, 0, 6, (0, -0.04, -0.03)), spine=R(18, 0, 0), chest=R(12, 0, -10), head=R(-4, 0, -6),
            upperarm_L=R(-100, -45, 0), forearm_L=R(-5, 0, 0), hand_L=R(-30, 0, 0),
            upperarm_R=R(-70, 50, 0), forearm_R=R(-40, 0, 0), hat=RS(16, 0, 0, (1, 1.12, 1)))
    fb = P_(fa, upperarm_L=R(-96, -50, 0), chest=R(14, 0, -12))
    # continuidade: braço estendido, manga voando, chapéu esticado
    co = P_(fa, root=RL(0, 0, 4, (0, -0.03, -0.02)), spine=R(12, 0, 0), upperarm_L=R(-92, -48, 0), forearm_L=R(0, 0, 0), hat=RS(8, 0, 0, (1, 1.06, 1)))
    # susto: olha as pernas que viram hachura (pose segurada de boca aberta)
    su = P_(g, root=RS(0, 0, 0, (0.95, 1.06, 0.95), (0, 0.0, 0.0)), spine=R(-6, 0, 0), chest=R(-4, 0, 0), head=R(32, 0, 0),
            upperarm_L=R(-30, -50, 0), forearm_L=R(-110, 0, 0), upperarm_R=R(-30, 50, 0), forearm_R=R(-110, 0, 0),
            thigh_L=R(0, 6, 0), shin_L=R(4, 0, 0), thigh_R=R(0, -6, 0), shin_R=R(4, 0, 0), hat=RS(-6, 0, 0, (1, 0.96, 1)))
    poses = [(g, 4), (tremor(g, 1), 4), (g, 4), (a1, 4), (tremor(a1, 1), 4), (a2, 8), (la, 4), (fa, 4), (fb, 4), (co, 8), (tremor(co, 1), 4), (co, 8),
             (tremor(co, 1), 4), (su, 4), (tremor(su, 1), 2), (su, 2), (tremor(su, 1), 2), (su, 2), (tremor(su, 1), 2), (su, 2), (tremor(su, 1), 2), (su, 30)]
    return seq(poses)

def pavieiro_espera():
    return respira(PAV_G, 0, 8)

# ================================================================== SINEIRA e GATUNO (estresse e folha)
SIN_G = {'root': RL(0, 0, 0, (0, 0, 0)), 'spine': R(-2, 0, 0), 'chest': R(-4, 0, 0), 'head': R(-6, 0, 0),
         'upperarm.L': R(-20, -10, 0), 'forearm.L': R(-70, 0, 0)}
def sineira_badalada():
    g = SIN_G
    fe = P_(g, head=R(6, 0, 0))   # fecha os olhos, pausa calma
    cr = P_(g, root=RS(0, 0, 0, (1.04, 0.94, 1.04), (0, 0, -0.03)), spine=R(-8, 0, 0), chest=R(-6, 0, 0), head=R(-14, 0, 0),
            upperarm_R=R(-15, 8, 0), forearm_R=R(-10, 0, 0), upperarm_L=R(-70, -55, 0), forearm_L=R(-20, 0, 0), cabo=R(-15, 0, 0), sino=R(-35, 0, 0),
            thigh_L=R(-24, -8, 0), shin_L=R(30, 0, 0), thigh_R=R(16, 8, 0), shin_R=R(16, 0, 0))
    return seq([(g, 12), (fe, 12), (cr, 60)])

GAT_G = {'root': RL(0, 0, 0, (0, 0, -0.03)), 'spine': R(16, 0, 0), 'chest': R(10, 0, -8), 'head': R(-24, 0, 10),
         'upperarm.R': R(-50, 20, 0), 'forearm.R': R(-50, 0, 0), 'upperarm.L': R(-40, -30, 0), 'forearm.L': R(-60, 0, 0),
         'thigh.L': R(-35, -10, 0), 'shin.L': R(50, 0, 0), 'thigh.R': R(10, 10, 0), 'shin.R': R(35, 0, 0), 'foot.R': R(-20, 0, 0)}
def gatuno_bote():
    g = GAT_G
    olha1 = P_(g, head=R(-20, 0, 35))
    olha2 = P_(g, head=R(-20, 0, -35))
    bo = P_(g, root=RS(0, 0, 0, (0.85, 1.3, 0.85), (0, -0.06, 0.04)), spine=R(30, 0, 0), chest=R(16, 0, 10), head=R(-30, 0, 0),
            upperarm_R=R(-100, 10, 0), forearm_R=R(-5, 0, 0), upperarm_L=R(30, -30, 0), forearm_L=R(-40, 0, 0),
            thigh_L=R(-60, -10, 0), shin_L=R(30, 0, 0), thigh_R=R(40, 10, 0), shin_R=R(10, 0, 0), foot_R=R(-40, 0, 0))
    po = P_(g, root=RS(0, 0, 0, (1.2, 0.7, 1.2), (0, 0, -0.06)))
    return seq([(g, 6), (olha1, 6), (olha2, 6), (bo, 6), (po, 3), (g, 30)])

# ================================================================== FULIGENTO
FUL_G = {'root': RL(0, 0, 0, (0, 0, 0)), 'corpo': R(6, 0, 0), 'cabeca': R(-6, 0, 0)}
def fuligento_acao():
    g = FUL_G
    ag = P_(g, root=RS(0, 0, 0, (1.15, 0.8, 1.15), (0, 0.02, -0.03)), corpo=R(22, 0, 0), cabeca=R(-20, 0, 0),
            braco_L=R(30, -10, 0), braco_R=R(30, 10, 0), perna_L=R(-20, 0, 0), perna_R=R(-20, 0, 0))
    pu = P_(g, root=RS(-25, 0, 0, (0.85, 1.25, 0.85)), corpo=R(10, 0, 0), cabeca=R(-15, 0, 0),
            braco_L=R(-80, -20, 0), braco_R=R(-80, 20, 0), perna_L=R(50, 0, 0), perna_R=R(50, 0, 0), cauda=R(20, 0, 0))
    su = P_(g, root=RS(-10, 0, 0, (1.3, 0.72, 1.3)), corpo=R(-10, 0, 0), cabeca=R(-25, 0, 0),
            braco_L=R(-150, -60, 0), braco_R=R(-150, 60, 0), perna_L=R(-30, -40, 0), perna_R=R(-30, 40, 0), cauda=R(-40, 0, 0))
    su2 = P_(su, root=RS(-60, 0, 0, (1.1, 0.9, 1.1)))
    return seq([(g, 8), (ag, 28), (pu, 12), (su, 4), (su2, 40)])

def fuligento_espera():
    g = FUL_G
    b = P_(g, root=RS(0, 0, 0, (1.04, 0.95, 1.04)), corpo=R(10, 0, 0))
    return seq([(g, 6), (b, 6)] * 4)

# ================================================================== APAGADOR
APA_G = {'spine': R(8, 0, 0), 'chest': R(6, 0, 0), 'pesc1': R(10, 0, 0), 'pesc2': R(10, 0, 0),
         'upperarm.L': R(-10, -8, 0), 'upperarm.R': R(-10, 8, 0), 'forearm.L': R(-15, 0, 0), 'forearm.R': R(-15, 0, 0)}
def apagador_acao():
    g = APA_G
    # Abafar: arqueia o cabo de latão sobre a luz, o cone erguido; braços abertos em garra
    ab = P_(g, spine=R(22, 0, 0), chest=R(18, 0, 0), pesc1=R(30, 0, 0), pesc2=R(46, 0, 0), cone=R(-30, 0, 0),
            upperarm_L=R(-110, -40, 0), forearm_L=R(-50, 0, 0), upperarm_R=R(-110, 40, 0), forearm_R=R(-50, 0, 0),
            thigh_L=R(-20, -4, 0), shin_L=R(20, 0, 0), thigh_R=R(16, 4, 0), shin_R=R(10, 0, 0))
    ab2 = P_(ab, pesc2=R(52, 0, 0), cone=R(-38, 0, 0))
    # recua da luz: corpo para trás, braços na frente da "cara", cone se encolhe
    re = P_(g, spine=R(-14, 0, 0), chest=R(-12, 0, 0), pesc1=R(-12, 0, 0), pesc2=R(30, 0, 0), cone=R(20, 0, 0),
            upperarm_L=R(-120, -10, 0), forearm_L=R(-90, 0, 0), upperarm_R=R(-125, 10, 0), forearm_R=R(-95, 0, 0),
            thigh_L=R(20, -4, 0), shin_L=R(30, 0, 0), thigh_R=R(-10, 4, 0), shin_R=R(10, 0, 0))
    return seq([(g, 6), (ab, 30), (ab2, 54), (re, 60)])

def esp(g, n=8):
    return respira(g, 0, n)

ACTIONS = {
    'rodeira': {'espera': esp(ROD_G, 12), 'eixo': rodeira_eixo(), 'folha': rodeira_folha()},
    'pavieiro': {'espera': esp(PAV_G, 8), 'lance': pavieiro_lance()},
    'sineira': {'espera': esp(SIN_G, 12), 'badalada': sineira_badalada()},
    'gatuno': {'espera': esp(GAT_G, 6), 'bote': gatuno_bote()},
    'fuligento': {'espera': fuligento_espera(), 'acao': fuligento_acao()},
    'apagador': {'espera': esp(APA_G, 12), 'acao': apagador_acao()},
}

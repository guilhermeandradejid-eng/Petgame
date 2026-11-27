# Poses-chave e ações da Tralha da Cheia (quadros a 60 fps, chaves CONSTANT: pose a pose, sem interpolação).
# Rotações em graus nos eixos do armature (X = esquerda do boneco, Y = costas, Z = cima), compostas pela cadeia:
#   rx < 0 leva um osso que aponta para baixo para a FRENTE; ry > 0 leva para a direita do boneco (-X);
#   rz > 0 gira a frente para a esquerda do boneco. 'ly' estica o osso ao longo dele mesmo.
# Ritmo por herói: Marola 15 poses/s (segura 4 quadros, antecipação longa), Piaba 30 poses/s (2 quadros, arcos largos).
# Mesma família de golpe (remada) para os dois: antecipação e contato próprios por herói; recuperação comum.
import json, os
from animar import P_

def R(rx=0, ry=0, rz=0):
    return {'r': (rx, ry, rz)}

def RL(rx=0, ry=0, rz=0, l=(0, 0, 0)):
    return {'r': (rx, ry, rz), 'l': l}

# ------------------------------------------------------------------ Tiá Marola
M_GUARDA = {
    'root': RL(0, 0, 0, (0, 0, -0.02)),
    'hips': R(0, 0, -6), 'spine': R(4, 0, 0), 'chest': R(2, 0, 4), 'head': R(-4, 0, -4),
    'thigh.L': R(-12, -6, 0), 'shin.L': R(16, 0, 0), 'foot.L': R(-4, 0, 0),
    'thigh.R': R(8, 6, 0), 'shin.R': R(10, 0, 0), 'foot.R': R(-16, 0, 0),
    'upperarm.L': R(-14, -12, 0), 'forearm.L': R(-35, 0, 0), 'hand.L': R(0, 0, 0),
    'upperarm.R': R(-20, 10, 0), 'forearm.R': R(-60, 0, 0), 'hand.R': R(10, 0, 0),
}
M_IDLE2 = P_(M_GUARDA, root=RL(0, 0, 0, (0, 0, -0.035)), chest=R(5, 0, 4), head=R(-1, 0, -4), shin_L=R(20, 0, 0), shin_R=R(14, 0, 0))

def marola_malho():
    """Despedida do malho: golpe pesado vertical, antecipação longa e segura (o peso se lê na espera)."""
    g = M_GUARDA
    a1 = P_(g, root=RL(0, 0, 0, (0, 0.03, -0.04)), spine=R(-6, 0, 0), chest=R(-8, 0, -10), head=R(-8, 0, 0),
            upperarm_R=R(-125, 6, 0), forearm_R=R(-35, 0, 0), hand_R=R(-10, 0, 0), upperarm_L=R(-50, -25, 0), forearm_L=R(-25, 0, 0),
            thigh_L=R(-24, -8, 0), shin_L=R(26, 0, 0), thigh_R=R(16, 8, 0), shin_R=R(22, 0, 0))
    a2 = P_(a1, root=RL(4, 0, 0, (0, 0.06, -0.07)), spine=R(-12, 0, 0), chest=R(-16, 0, -14), head=R(-14, 0, 6),
            upperarm_R=R(-165, 4, 0), forearm_R=R(-24, 0, 0), hand_R=R(-10, 0, 0), upperarm_L=R(-85, -35, 0), forearm_L=R(-15, 0, 0),
            thigh_L=R(-34, -10, 0), shin_L=R(34, 0, 0), thigh_R=R(22, 10, 0), shin_R=R(30, 0, 0), foot_R=R(-24, 0, 0))
    sm = P_(a2, root=RL(-6, 0, 0, (0, -0.02, -0.06)), spine=R(10, 0, 0), chest=R(14, 0, -4), head=R(4, 0, 0),
            upperarm_R=R(-105, 0, 0), forearm_R=R(-15, 0, 0), hand_R=R(15, 0, 0), upperarm_L=R(-40, -30, 0), forearm_L=R(-30, 0, 0))
    ct = P_(sm, root=RL(-14, 0, 0, (0, -0.08, -0.14)), spine=R(16, 0, 0), chest=R(26, 0, 2), head=R(6, 0, 0),
            upperarm_R=R(-62, 2, 0), forearm_R={'r': (-4, 0, 0), 'ly': 0.045}, hand_R=R(48, 0, 0), upperarm_L=R(-20, -38, 0), forearm_L=R(-40, 0, 0),
            thigh_L=R(-58, -12, 0), shin_L=R(56, 0, 0), foot_L=R(0, 0, 0), thigh_R=R(30, 12, 0), shin_R=R(14, 0, 0), foot_R=R(-30, 0, 0))
    ft = P_(ct, root=RL(-16, 0, 0, (0, -0.08, -0.16)), chest=R(30, 0, 4), upperarm_R=R(-56, 2, 0), forearm_R=R(-4, 0, 0), hand_R=R(50, 0, 0), head=R(10, 0, 0))
    # depois da Despedida: a mão fica vazia; ela olha para a mão
    v1 = P_(g, root=RL(-4, 0, 0, (0, -0.03, -0.08)), chest=R(12, 0, 0), head=R(22, 0, -10),
            upperarm_R=R(-45, 18, 0), forearm_R=R(-95, 0, 0), hand_R=R(-20, 0, 0), upperarm_L=R(-30, -20, 0), forearm_L=R(-50, 0, 0),
            thigh_L=R(-40, -10, 0), shin_L=R(44, 0, 0), thigh_R=R(18, 10, 0), shin_R=R(20, 0, 0))
    v2 = P_(v1, head=R(18, 0, 8), upperarm_R=R(-50, 22, 0), forearm_R=R(-100, 0, 6))
    return [(0, g), (6, a1), (12, a2), (32, sm), (33, ct), (40, ft), (52, v1), (60, v2), (68, v1), (76, v2)]

def marola_mepassa():
    """'Me passa!': braço esquerdo erguido chamando, peso no pé de trás."""
    g = M_GUARDA
    c1 = P_(g, root=RL(0, 0, 0, (0, 0.0, -0.03)), chest=R(-8, 0, 20), head=R(-12, 0, 22),
            upperarm_L=R(-172, -38, 0), forearm_L=R(-12, 0, 0), upperarm_R=R(-30, 40, 0), forearm_R=R(-50, 0, 0))
    c2 = P_(c1, upperarm_L=R(-168, -58, 0), forearm_L=R(-28, -10, 0), head=R(-14, 0, 24))
    return [(0, c1), (8, c2), (16, c1), (24, c2), (32, c1)]

def marola_pegada():
    """Pegada no ar: mão no alto, contato com a saia comprimindo, assenta na guarda alta."""
    g = M_GUARDA
    r1 = P_(g, root=RL(0, 0, 0, (0, 0.0, 0.01)), chest=R(-10, 0, 18), head=R(-22, 0, 16),
            upperarm_R=R(-158, 18, 0), forearm_R=R(-12, 0, 0), hand_R=R(-40, 0, 0), upperarm_L=R(-120, -40, 0), forearm_L=R(-20, 0, 0))
    sq = {'s': (1.08, 0.85, 1.08)}
    c1 = P_(r1, root=RL(0, 0, 0, (0, 0.0, -0.09)), chest=R(6, 0, 10), head=R(-6, 0, 10),
            upperarm_R=R(-120, 20, 0), forearm_R=R(-40, 0, 0), hand_R=R(-30, 0, 0), upperarm_L=R(-60, -40, 0), forearm_L=R(-40, 0, 0),
            thigh_L=R(-36, -8, 0), shin_L=R(48, 0, 0), thigh_R=R(20, 8, 0), shin_R=R(40, 0, 0),
            skirt_F=sq, skirt_B=sq, skirt_L=sq, skirt_R=sq)
    c2 = P_(c1, root=RL(0, 0, 0, (0, 0.0, -0.05)), skirt_F={}, skirt_B={}, skirt_L={}, skirt_R={},
            upperarm_R=R(-100, 15, 0), forearm_R=R(-60, 0, 0), hand_R=R(-20, 0, 0))
    return [(0, r1), (4, c1), (12, c2)]

def marola_remada():
    """Remada (recepção): arco largo e plano da direita para a esquerda. Antecipação própria, longa e segura;
    contato sem tremor, com o braço esticado 15% por 1 pose."""
    g = M_GUARDA
    a1 = P_(g, root=RL(0, 0, -14, (0.03, 0.03, -0.05)), hips=R(0, 0, -18), spine=R(0, 0, -10), chest=R(-4, 0, -26), head=R(-6, 0, 30),
            upperarm_R=R(-80, 0, -60), forearm_R=R(-25, 0, 0), hand_R=R(70, 0, 0), upperarm_L=R(-60, -20, 20), forearm_L=R(-40, 0, 0),
            thigh_L=R(-20, -10, 0), shin_L=R(22, 0, 0), thigh_R=R(10, 14, 0), shin_R=R(26, 0, 0))
    a2 = P_(a1, root=RL(0, 0, -20, (0.06, 0.05, -0.1)), hips=R(0, 0, -22), spine=R(-6, 0, -18), chest=R(-12, 0, -42), head=R(-8, 0, 62),
            upperarm_R=R(-62, 0, -100), forearm_R=R(-96, 0, 0), hand_R=R(40, 0, 0), upperarm_L=R(-70, 0, 40), forearm_L=R(-70, 0, 0),
            thigh_L=R(-30, -12, 0), shin_L=R(34, 0, 0), thigh_R=R(16, 18, 0), shin_R=R(40, 0, 0), foot_R=R(-22, 0, 0))
    sm = P_(a2, root=RL(0, 0, 0, (0.0, 0.0, -0.08)), hips=R(0, 0, -4), spine=R(2, 0, 0), chest=R(4, 0, 0), head=R(0, 0, 10),
            upperarm_R=R(-86, 0, -20), forearm_R=R(-30, 0, 0), hand_R=R(80, 0, 0))
    ct = P_(sm, root=RL(0, 0, 6, (-0.05, -0.07, -0.1)), hips=R(0, 0, 4), spine=R(6, 0, 4), chest=R(8, 0, 10), head=R(4, 0, -6),
            upperarm_R=R(-88, 0, -6), forearm_R={'r': (-4, 0, 0), 'ly': 0.045}, hand_R=R(84, 0, 0), upperarm_L=R(-30, -50, -10), forearm_L=R(-30, 0, 0),
            thigh_L=R(-44, -14, 0), shin_L=R(40, 0, 0), thigh_R=R(26, 14, 0), shin_R=R(12, 0, 0), foot_R=R(-26, 0, 0))
    return [(0, g), (4, a1), (12, a2), (30, sm), (31, ct)] + remada_recuperacao(ct, g, 31)

def remada_recuperacao(ct, g, f0, passo=8):
    """Recuperação comum da família Remos: continuidade (passa do alvo 25°), freio e volta à guarda."""
    ft = P_(ct, chest=R(10, 0, 30), upperarm_R=R(-80, 0, 26), forearm_R=R(-10, 0, 0), hand_R=R(80, 0, 0), head=R(4, 0, -16))
    r1 = P_(ct, chest=R(8, 0, 26), upperarm_R=R(-50, 0, 30), forearm_R=R(-50, 0, 0), hand_R=R(30, 0, 0))
    r2 = P_(g, root=RL(0, 0, 4, (-0.02, -0.02, -0.04)), chest=R(4, 0, 14), upperarm_R=R(-30, 6, 16), forearm_R=R(-60, 0, 0), hand_R=R(20, 0, 0))
    return [(f0 + 8, ft), (f0 + 8 + passo * 2, r1), (f0 + 8 + passo * 4, r2), (f0 + 8 + passo * 6, g)]

# ------------------------------------------------------------------ Piaba
P_GUARDA = {
    'root': RL(0, 0, 0, (0, 0, -0.01)),
    'chest': R(0, 0, -6), 'head': R(-4, 0, 6),
    'thigh.L': R(-8, -12, 0), 'shin.L': R(12, 0, 0), 'thigh.R': R(6, 12, 0), 'shin.R': R(10, 0, 0),
    'upperarm.L': R(-20, -26, 0), 'forearm.L': R(-50, 0, 0),
    'upperarm.R': R(-30, 22, 0), 'forearm.R': R(-55, 0, 0), 'hand.R': R(-10, 0, 0),
}
P_IDLE2 = P_(P_GUARDA, root=RL(0, 0, 0, (0, 0, 0.02)), boia={'s': (0.95, 1.08, 0.95)})

def piaba_arremesso():
    """Arremesso por cima: agacha na boia, estica no lançamento, braço passa do ponto, quica ao assentar."""
    g = P_GUARDA
    sq = {'s': (1.22, 0.72, 1.22)}
    st = {'s': (0.86, 1.36, 0.86)}
    a1 = P_(g, root=RL(0, 0, -20, (0, 0.03, -0.06)), boia=sq, chest=R(-10, 0, -30), head=R(-8, 0, 30),
            upperarm_R=R(-140, 40, 0), forearm_R=R(-60, 0, 0), hand_R=R(-30, 0, 0), upperarm_L=R(-90, -10, 30), forearm_L=R(-10, 0, 0),
            thigh_L=R(-30, -14, 0), shin_L=R(40, 0, 0), thigh_R=R(20, 16, 0), shin_R=R(40, 0, 0))
    a2 = P_(a1, root=RL(0, 0, -28, (0, 0.06, -0.1)), chest=R(-18, 0, -40), head=R(-12, 0, 40),
            upperarm_R=R(-168, 46, 0), forearm_R=R(-70, 0, 0), hand_R=R(-45, 0, 0), upperarm_L=R(-95, -6, 40), forearm_L=R(-5, 0, 0))
    sm = P_(a2, root=RL(0, 0, 4, (0, -0.02, 0.04)), boia=st, chest=R(10, 0, 10), head=R(-4, 0, 0),
            upperarm_R=R(-120, 10, 0), forearm_R=R(-10, 0, 0), hand_R=R(20, 0, 0), upperarm_L=R(-40, -30, 10), forearm_L=R(-30, 0, 0),
            thigh_L=R(-20, -10, 0), shin_L=R(10, 0, 0), thigh_R=R(10, 10, 0), shin_R=R(10, 0, 0))
    ft = P_(sm, root=RL(0, 0, 24, (0, -0.08, 0.05)), boia={'s': (0.82, 1.42, 0.82)}, chest=R(28, 0, 34), head=R(4, 0, -22),
            upperarm_R=R(-20, -34, 0), forearm_R=R(-15, 0, 0), hand_R=R(40, 0, 0), upperarm_L=R(20, -40, 0), forearm_L=R(-30, 0, 0),
            thigh_L=R(-40, -10, 0), shin_L=R(20, 0, 0), thigh_R=R(50, 10, 0), shin_R=R(60, 0, 0), foot_R=R(30, 0, 0))
    ld = P_(ft, root=RL(0, 0, 18, (0, -0.06, -0.07)), boia={'s': (1.3, 0.68, 1.3)}, chest=R(16, 0, 24), thigh_R=R(10, 12, 0), shin_R=R(30, 0, 0), foot_R=R(0, 0, 0),
            thigh_L=R(-30, -14, 0), shin_L=R(44, 0, 0))
    b1 = P_(ld, root=RL(0, 0, 14, (0, -0.06, 0.03)), boia={'s': (0.92, 1.14, 0.92)}, chest=R(6, 0, 16))
    b2 = P_(ld, root=RL(0, 0, 12, (0, -0.06, -0.02)), boia={'s': (1.06, 0.92, 1.06)}, chest=R(8, 0, 14))
    st_ = P_(g, root=RL(0, 0, 12, (0, -0.06, 0.0)), chest=R(2, 0, 8), upperarm_R=R(-10, 20, 0), forearm_R=R(-40, 0, 0))
    return [(0, g), (4, a1), (8, a2), (18, sm), (19, ft), (34, ld), (40, b1), (44, b2), (48, st_)]

def piaba_comemora():
    g = P_(P_GUARDA, upperarm_R=R(-20, 30, 0), forearm_R=R(-40, 0, 0))
    sq = P_(g, root=RL(0, 0, 0, (0, 0, -0.07)), boia={'s': (1.28, 0.7, 1.28)}, chest=R(14, 0, 0), upperarm_L=R(-10, -40, 0), upperarm_R=R(-10, 40, 0))
    up = P_(g, root=RL(0, 0, 0, (0, 0, 0.26)), boia={'s': (0.85, 1.35, 0.85)}, chest=R(-14, 0, 0), head=R(-20, 0, 0),
            upperarm_L=R(-170, -30, 0), forearm_L=R(-10, 0, 0), upperarm_R=R(-170, 30, 0), forearm_R=R(-10, 0, 0),
            thigh_L=R(20, -10, 0), shin_L=R(50, 0, 0), thigh_R=R(30, 10, 0), shin_R=R(60, 0, 0))
    top = P_(up, root=RL(0, 0, 0, (0, 0, 0.3)), boia={'s': (1.0, 1.0, 1.0)}, upperarm_L=R(-160, -60, 0), upperarm_R=R(-160, 60, 0))
    ld = P_(sq, upperarm_L=R(-120, -50, 0), upperarm_R=R(-120, 50, 0))
    b1 = P_(g, root=RL(0, 0, 0, (0, 0, 0.06)), boia={'s': (0.9, 1.18, 0.9)}, upperarm_L=R(-140, -40, 0), upperarm_R=R(-140, 40, 0))
    return [(0, sq), (6, up), (12, top), (20, up), (26, ld), (32, b1), (36, P_(g, boia={'s': (1.06, 0.92, 1.06)})), (40, g)]

def piaba_remada():
    """A mesma remada no ritmo e com as poses próprias do Piaba: salta no contato e estica a boia."""
    g = P_GUARDA
    sq = {'s': (1.24, 0.72, 1.24)}
    a1 = P_(g, root=RL(0, 0, -30, (0.04, 0.04, -0.08)), boia=sq, chest=R(-6, 0, -40), head=R(-6, 0, 40),
            upperarm_R=R(-84, 0, -70), forearm_R=R(-30, 0, 0), hand_R=R(74, 0, 0), upperarm_L=R(-80, -20, 40), forearm_L=R(-20, 0, 0),
            thigh_L=R(-30, -14, 0), shin_L=R(44, 0, 0), thigh_R=R(20, 18, 0), shin_R=R(44, 0, 0))
    sm = P_(a1, root=RL(0, 0, 0, (0, 0, 0.04)), boia={'s': (0.88, 1.3, 0.88)}, chest=R(4, 0, 0), upperarm_R=R(-86, 0, -10), hand_R=R(80, 0, 0))
    ct = P_(sm, root=RL(0, 0, 20, (-0.06, -0.08, 0.12)), boia={'s': (0.82, 1.42, 0.82)}, chest=R(10, 0, 30), head=R(4, 0, -20),
            upperarm_R=R(-90, 0, 30), forearm_R={'r': (-2, 0, 0), 'ly': 0.04}, hand_R=R(84, 0, 0), upperarm_L=R(-20, -70, 0), forearm_L=R(-10, 0, 0),
            thigh_L=R(-50, -10, 0), shin_L=R(30, 0, 0), thigh_R=R(40, 10, 0), shin_R=R(60, 0, 0))
    ld = P_(ct, root=RL(0, 0, 20, (-0.06, -0.08, -0.06)), boia={'s': (1.3, 0.7, 1.3)}, thigh_L=R(-34, -14, 0), shin_L=R(40, 0, 0), thigh_R=R(16, 14, 0), shin_R=R(30, 0, 0))
    return [(0, g), (2, a1), (8, sm), (9, ct), (13, ld)] + remada_recuperacao(ld, g, 13, passo=4)

# ------------------------------------------------------------------ Remanso e Breu (estresse: guarda e um golpe)
RM_G = {'root': RL(0, 0, 0, (0, 0, 0)), 'chest': R(3, 0, 0), 'head': R(4, 0, 0), 'upperarm.L': R(-10, -8, 0), 'forearm.L': R(-20, 0, 0),
        'upperarm.R': R(-35, 10, 0), 'forearm.R': R(-50, 0, 0), 'thigh.L': R(-6, -4, 0), 'shin.L': R(6, 0, 0)}
def remanso_golpe():
    g = RM_G
    a = P_(g, chest=R(-10, 0, -20), upperarm_R=R(-160, 10, 0), forearm_R=R(-40, 0, 0), hand_R=R(-20, 0, 0))
    c = P_(g, root=RL(-6, 0, 0, (0, -0.05, -0.05)), chest=R(20, 0, 10), upperarm_R=R(-70, 0, 0), forearm_R={'r': (0, 0, 0), 'ly': 0.04}, hand_R=R(50, 0, 0),
           thigh_L=R(-40, -6, 0), shin_L=R(30, 0, 0))
    return [(0, g), (10, a), (24, c), (40, g)]
BR_G = {'root': RL(0, 0, 8, (0, 0, -0.02)), 'chest': R(4, 6, 0), 'head': R(-4, -8, 0), 'upperarm.L': R(-20, -20, 0), 'forearm.L': R(-60, 0, 0),
        'upperarm.R': R(-15, 18, 0), 'forearm.R': R(-50, 0, 0), 'thigh.L': R(-10, -6, 0), 'shin.L': R(14, 0, 0), 'thigh.R': R(6, 8, 0), 'shin.R': R(10, 0, 0)}
def breu_golpe():
    g = BR_G
    a = P_(g, chest=R(-12, 12, -10), upperarm_R=R(-150, 30, 0), forearm_R=R(-50, 0, 0), hand_R=R(-30, 0, 0))
    c = P_(g, root=RL(-8, 0, 0, (0, -0.04, -0.08)), chest=R(24, 10, 6), upperarm_R=R(-60, 10, 0), forearm_R=R(-5, 0, 0), hand_R=R(50, 0, 0))
    return [(0, g), (10, a), (24, c), (40, g)]

# ------------------------------------------------------------------ Inchados (4s e 5s, brinquedo duro)
BU = {'root': RL(0, 0, 0, (0, 0, 0))}
def bucho_idle():
    return [(0, BU), (15, P_(BU, body={'s': (1.04, 0.95, 1.04)}, leg_L=R(-14, 0, 0), leg_R=R(10, 0, 0))), (30, P_(BU, leg_L=R(8, 0, 0), leg_R=R(-12, 0, 0))), (45, BU)]
def bucho_incha():
    """telegrafia: incha de 1,0 para 1,3 em 3 poses e segura tremendo (1 a 2°), olho apertado."""
    k = []
    for i, s in enumerate((1.0, 1.1, 1.2, 1.3)):
        k.append((i * 10, P_(BU, body={'s': (s, s * 0.97, s)}, fin_L=R(0, -10 * i, 0), fin_R=R(0, 10 * i, 0))))
    for j in range(6):
        k.append((40 + j * 4, P_(BU, body={'r': (0, 2 if j % 2 else -2, 0), 's': (1.3, 1.26, 1.3)}, fin_L=R(0, -40, 0), fin_R=R(0, 40, 0))))
    return k
def bucho_golpeado():
    return [(0, P_(BU, body={'r': (24, 0, 0), 's': (1.38, 0.6, 1.38)}, root=RL(0, 0, 0, (0, 0.08, 0)))),
            (6, P_(BU, body={'r': (-10, 0, 0), 's': (0.82, 1.3, 0.82)}, root=RL(0, 0, 0, (0, 0.18, 0.05)))),
            (12, P_(BU, body={'s': (1.12, 0.88, 1.12)}, root=RL(0, 0, 0, (0, 0.22, 0)))),
            (18, P_(BU, root=RL(0, 0, 0, (0, 0.22, 0))))]
def bucho_panqueca():
    """estoura achatado como panqueca e desincha em 3 poses."""
    fin = {'s': (0.35, 0.35, 0.35)}
    no = {'s': (0.5, 0.5, 0.5)}
    return [(0, P_(BU, body={'s': (1.9, 0.22, 1.9)}, root=RL(0, 0, 0, (0, 0, -0.08)), fin_L=fin, fin_R=fin, no=no)),
            (20, P_(BU, body={'s': (1.7, 0.16, 1.7)}, root=RL(0, 0, 0, (0, 0, -0.09)), fin_L=fin, fin_R=fin, no=no)),
            (30, P_(BU, body={'s': (1.4, 0.1, 1.4)}, root=RL(0, 0, 0, (0, 0, -0.095)), fin_L=fin, fin_R=fin, no=no)),
            (40, P_(BU, body={'s': (1.1, 0.06, 1.1)}, root=RL(0, 0, 0, (0, 0, -0.1)), fin_L=fin, fin_R=fin, no=no))]

GA = {'root': RL(0, 0, 0, (0, 0, 0))}
def gaiola_idle():
    a = P_(GA, body={'r': (0, 4, 0)}, garra_L=R(0, -10, 10), garra_R=R(0, 10, -10))
    b = P_(GA, body={'r': (0, -4, 0)}, garra_L=R(0, 0, -6), garra_R=R(0, 0, 6))
    return [(0, a), (16, b), (32, a)]
def gaiola_abre():
    k = [(0, GA)]
    for j, ang in enumerate((40, 80, 110)):
        k.append((8 + j * 8, P_(GA, porta={'r': (0, 0, -ang)}, garra_L=R(-30, -30, 0), garra_R=R(-30, 30, 0), body={'r': (-6, 0, 0)})))
    return k
LA = {'root': RL(0, 0, 0, (0, 0, 0))}
def lata_treme():
    return [(0, LA)] + [(4 + j * 4, P_(LA, body={'r': (0, 3 if j % 2 else -3, 0), 's': (0.94, 0.94, 1.0)})) for j in range(12)]

# Respiração em degrau (hold de 12 quadros): o peito estica 3% e a cabeça acompanha um quadro atrasada.
def respira(g, extra_in=None, extra_out=None, passo=12):
    inn = P_(g, chest=dict(g.get('chest', {}), s=(1.0, 1.028, 1.0)), **(extra_in or {}))
    out = P_(g, **(extra_out or {}))
    return [(0, g), (passo, inn), (passo * 2, P_(inn, **(extra_out or {}))), (passo * 3, out), (passo * 4, g)]

M_IDLE = respira(M_GUARDA, {'head': R(-6, 0, -2), 'root': RL(0, 0, 0, (0, 0, -0.012))}, {'root': RL(0, 0, 0, (0, 0, -0.03)), 'shin_L': R(20, 0, 0), 'shin_R': R(14, 0, 0)})
P_IDLE = respira(P_GUARDA, {'boia': {'s': (0.96, 1.07, 0.96)}, 'head': R(-8, 0, 8)}, {'boia': {'s': (1.05, 0.94, 1.05)}, 'root': RL(0, 0, 0, (0, 0, -0.025))}, passo=8)

ACTIONS = {
    'marola': {'idle': M_IDLE, 'malho': marola_malho(), 'mepassa': marola_mepassa(),
               'pegada': marola_pegada(), 'remada': marola_remada()},
    'piaba': {'idle': P_IDLE, 'arremesso': piaba_arremesso(), 'comemora': piaba_comemora(),
              'remada': piaba_remada()},
    'remanso': {'idle': respira(RM_G, {'head': R(0, 0, 4)}, {'root': RL(0, 0, 0, (0, 0, -0.015))}, passo=14), 'golpe': remanso_golpe()},
    'breu': {'idle': respira(BR_G, {'head': R(-8, -8, 0)}, {'root': RL(0, 0, 8, (0, 0, -0.03))}, passo=10), 'golpe': breu_golpe()},
    'bucho': {'idle': bucho_idle(), 'incha': bucho_incha(), 'golpeado': bucho_golpeado(), 'panqueca': bucho_panqueca()},
    'gaiola': {'idle': gaiola_idle(), 'abre': gaiola_abre()},
    'lata': {'idle': [(0, LA), (30, LA)], 'treme': lata_treme()},
}
# metadados para o motor: quadro de contato (dano preso à pose), quadros de borrão e de soltura da arma
META = {
    'marola': {'malho': {'smear': [32], 'contato': 33}, 'remada': {'smear': [30], 'contato': 31}, 'pegada': {'contato': 4}},
    'piaba': {'arremesso': {'smear': [18], 'solta': 19}, 'remada': {'smear': [8], 'contato': 9}},
    'remanso': {'golpe': {'contato': 24}}, 'breu': {'golpe': {'contato': 24}},
}

if __name__ == '__main__':
    import sys
    json.dump(META, open(sys.argv[1], 'w'), indent=1)

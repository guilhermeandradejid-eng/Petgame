# Poses-chave (graus, eixos do armature: X inclina para a frente, Y rola, Z gira; braço direito
# erguido de lado = Y +90; braço erguido à frente = X negativo). Chaves CONSTANT a 60 fps:
# o corpo anda em poses seguradas, o quadro de borrão aparece 1 quadro, as molas ficam no Godot.
from animar import P_

REST = {}

# ================================================================== Tarugo: marretada pesada
T_GUARD = {
    'hips': {'l': (0, 0, -0.02)}, 'spine': {'r': (4, 0, 0)}, 'chest': {'r': (4, 0, -6)}, 'head': {'r': (-6, 0, 8)},
    'upperarm.R': {'r': (-62, 0, 8)}, 'forearm.R': {'r': (-128, 0, 0)}, 'hand.R': {'r': (-6, 0, 0)},
    'upperarm.L': {'r': (-38, -22, 0)}, 'forearm.L': {'r': (-38, 0, 0)}, 'hand.L': {'r': (0, 0, -20)},
    'thigh.L': {'r': (-10, 0, 0)}, 'thigh.R': {'r': (8, 0, 0)}, 'shin.L': {'r': (12, 0, 0)},
}
T_IDLE2 = P_(T_GUARD, hips={'l': (0, 0, -0.035)}, chest={'r': (7, 0, -6)}, peito={'s': (1.05, 1.0, 1.05)}, head={'r': (-2, 0, 10)},
             upperarm_R={'r': (-60, 0, 8)})
T_A1 = P_(T_GUARD, hips={'l': (0, 0.03, -0.05)}, spine={'r': (-4, 0, 0)}, chest={'r': (-8, 0, -14)}, head={'r': (-14, 0, 6)}, jaw={'r': (10, 0, 0)},
          upperarm_R={'r': (-120, 0, 6)}, forearm_R={'r': (-90, 0, 0)}, upperarm_L={'r': (-60, -20, 0)},
          skirt_F={'s': (1.06, 0.93, 1.06)}, skirt_B={'s': (1.06, 0.93, 1.06)}, skirt_L={'s': (1.06, 0.93, 1.06)}, skirt_R={'s': (1.06, 0.93, 1.06)})
T_A2 = P_(T_A1, hips={'l': (0, 0.06, -0.08)}, spine={'r': (-10, 0, 0)}, chest={'r': (-16, 0, -18)}, peito={'s': (1.1, 1.0, 1.1)}, head={'r': (-24, 0, 4)}, jaw={'r': (24, 0, 0)},
          upperarm_R={'r': (-140, 0, 4)}, forearm_R={'r': (-50, 0, 0)}, hand_R={'r': (-10, 0, 0)}, upperarm_L={'r': (-85, -25, 0)}, forearm_L={'r': (-15, 0, 0)},
          skirt_F={'s': (1.1, 0.88, 1.1)}, skirt_B={'s': (1.1, 0.88, 1.1)}, skirt_L={'s': (1.1, 0.88, 1.1)}, skirt_R={'s': (1.1, 0.88, 1.1)})
# extremo da antecipação: peito estufado 15%, macete atrás da cabeça, grito
# v2: torção maior para ler de cima (tronco gira 44° no total) e agachamento mais fundo; a madeira não achata
T_A3 = P_(T_A2, hips={'l': (0, 0.1, -0.14)}, spine={'r': (-14, 0, -18)}, chest={'r': (-20, 0, -26)}, peito={'s': (1.15, 1.0, 1.15)}, head={'r': (-30, 0, 2)}, jaw={'r': (32, 0, 0)},
          upperarm_R={'r': (-150, 0, 2)}, forearm_R={'r': (-30, 0, 0)}, hand_R={'r': (12, 0, 0)}, upperarm_L={'r': (-100, -30, 0)},
          skirt_F={'s': (1.12, 0.86, 1.12)}, skirt_B={'s': (1.12, 0.86, 1.12)}, skirt_L={'s': (1.12, 0.86, 1.12)}, skirt_R={'s': (1.12, 0.86, 1.12)})
T_SMEAR = P_(T_GUARD, hips={'l': (0, -0.04, -0.06)}, spine={'r': (10, 0, 0)}, chest={'r': (14, 0, 6)}, peito={'s': (1.05, 1.0, 1.05)}, head={'r': (-14, 0, 0)}, jaw={'r': (30, 0, 0)},
             upperarm_R={'r': (-130, 0, -2)}, forearm_R={'r': (-12, 0, 0)}, hand_R={'r': (0, 0, 0)}, upperarm_L={'r': (-30, -40, 0)}, forearm_L={'r': (-20, 0, 0)},
             _smear=True)
T_CONTACT = P_(T_GUARD, hips={'l': (0, -0.1, -0.07)}, spine={'r': (14, 0, 0)}, chest={'r': (26, 0, 10)}, peito={'s': (0.96, 1.0, 0.96)}, head={'r': (-22, 0, -4)}, jaw={'r': (26, 0, 0)},
               upperarm_R={'r': (-114, 0, -4)}, forearm_R={'r': (-4, 0, 0)}, hand_R={'r': (4, 0, 0)},
               upperarm_L={'r': (14, -55, 0)}, forearm_L={'r': (-10, 0, 0)}, hand_L={'r': (0, 0, -30)},
               thigh_L={'r': (-30, 0, 0)}, shin_L={'r': (20, 0, 0)}, thigh_R={'r': (30, 0, 0)},
               skirt_F={'s': (0.94, 1.12, 0.94), 'r': (14, 0, 0)}, skirt_B={'s': (0.94, 1.12, 0.94), 'r': (18, 0, 0)}, skirt_L={'s': (0.94, 1.12, 0.94)}, skirt_R={'s': (0.94, 1.12, 0.94)})
T_FOLLOW = P_(T_CONTACT, spine={'r': (18, 0, 0)}, chest={'r': (32, 0, 14)}, head={'r': (-12, 0, -6)}, jaw={'r': (18, 0, 0)},
              upperarm_R={'r': (-110, 0, -6)}, hand_R={'r': (6, 0, 0)}, upperarm_L={'r': (24, -60, 0)})
T_RECOIL = P_(T_GUARD, hips={'l': (0, -0.06, -0.04)}, spine={'r': (10, 0, 0)}, chest={'r': (14, 0, 6)}, head={'r': (2, 0, 10)},
              upperarm_R={'r': (-105, 0, -4)}, forearm_R={'r': (-30, 0, 0)}, hand_R={'r': (0, 0, 0)}, upperarm_L={'r': (-10, -40, 0)})
T_RECOV = P_(T_GUARD, hips={'l': (0, -0.02, -0.03)}, chest={'r': (6, 0, 0)}, upperarm_R={'r': (-70, 0, 6)}, forearm_R={'r': (-110, 0, 0)}, head={'r': (-4, 0, 14)})
# vira a cabeça para a plateia e estufa o peito (segura 6+ quadros)
T_PLATEIA = P_(T_RECOV, chest={'r': (-6, 0, 10)}, peito={'s': (1.1, 1.0, 1.1)}, head={'r': (-18, 0, 48)}, jaw={'r': (16, 0, 0)},
               upperarm_L={'r': (-20, -70, 0)}, forearm_L={'r': (-80, 0, 0)}, hand_L={'r': (0, 0, 0)})

T_GOLPE = [(0, T_GUARD), (3, T_A1), (6, T_A2), (10, T_A3), (20, T_SMEAR), (21, T_CONTACT), (24, T_FOLLOW), (30, T_RECOIL),
           (38, T_RECOV), (46, T_PLATEIA), (60, T_GUARD), (72, T_GUARD)]
T_IDLE = [(0, T_GUARD), (16, T_IDLE2), (32, T_GUARD), (48, T_IDLE2), (64, T_GUARD)]

# ================================================================== Anilina: pincelada larga em arco
N_GUARD = {
    'hips': {'l': (0, 0, -0.01)}, 'chest': {'r': (2, 0, -10)}, 'head': {'r': (-4, 0, 10)},
    'upperarm.R': {'r': (-30, 40, 0)}, 'forearm.R': {'r': (-40, 0, 0)}, 'hand.R': {'r': (0, 0, 0)},
    'upperarm.L': {'r': (-10, -30, 0)}, 'forearm.L': {'r': (-60, 0, 0)}, 'hand.L': {'r': (0, 0, 30)},
}
N_IDLE2 = P_(N_GUARD, chest={'r': (4, 0, -8)}, head={'r': (-2, 0, 14)})
N_A1 = P_(N_GUARD, chest={'r': (0, 0, -22)}, spine={'r': (0, 0, -8)}, head={'r': (-6, 0, -6)},
          upperarm_R={'r': (-10, 70, -25)}, forearm_R={'r': (-15, 0, 0)}, upperarm_L={'r': (-40, -40, 10)})
N_A2 = P_(N_A1, chest={'r': (-4, 0, -34)}, spine={'r': (-2, 0, -14)}, head={'r': (-8, 0, -12)}, jaw={'r': (8, 0, 0)},
          upperarm_R={'r': (0, 82, -45)}, forearm_R={'r': (-10, 0, 0)}, hand_R={'r': (0, 0, -10)}, upperarm_L={'r': (-70, -50, 20)}, forearm_L={'r': (-20, 0, 0)},
          skirt_F={'s': (1.06, 0.94, 1.06)}, skirt_B={'s': (1.06, 0.94, 1.06)})
N_A3 = P_(N_A2, chest={'r': (-6, 0, -42)}, spine={'r': (-4, 0, -18)}, head={'r': (-10, 0, -16)},
          upperarm_R={'r': (0, 86, -58)}, hand_R={'r': (0, 0, -18)}, upperarm_L={'r': (-80, -60, 30)},
          skirt_F={'s': (1.1, 0.9, 1.1)}, skirt_B={'s': (1.1, 0.9, 1.1)}, skirt_L={'s': (1.1, 0.9, 1.1)}, skirt_R={'s': (1.1, 0.9, 1.1)})
N_B = P_(N_A3, chest={'r': (-4, 0, -36)}, upperarm_R={'r': (0, 90, -48)}, hand_R={'r': (0, 0, -24)})
N_SMEAR = P_(N_GUARD, chest={'r': (4, 0, -6)}, spine={'r': (0, 0, -4)}, head={'r': (0, 0, 4)}, jaw={'r': (12, 0, 0)},
             upperarm_R={'r': (0, 98, 10)}, forearm_R={'r': (0, 0, 0)}, hand_R={'r': (0, 0, -6)}, upperarm_L={'r': (-50, -70, 0)}, _smear=True)
N_CONTACT = P_(N_GUARD, chest={'r': (8, 0, 14)}, spine={'r': (2, 0, 6)}, head={'r': (4, 0, 14)}, jaw={'r': (10, 0, 0)},
               upperarm_R={'r': (0, 100, 40)}, forearm_R={'r': (0, 0, 0)}, hand_R={'r': (0, 0, 8)}, upperarm_L={'r': (-30, -80, -10)}, forearm_L={'r': (-10, 0, 0)},
               skirt_F={'s': (0.95, 1.1, 0.95)}, skirt_B={'s': (0.95, 1.1, 0.95)}, skirt_L={'s': (0.95, 1.1, 0.95)}, skirt_R={'s': (0.95, 1.1, 0.95)})
N_PASS = P_(N_CONTACT, chest={'r': (8, 0, 34)}, spine={'r': (2, 0, 14)}, head={'r': (-18, 0, 28)}, upperarm_R={'r': (0, 96, 80)}, hand_R={'r': (0, 0, 18)})
N_F1 = P_(N_PASS, chest={'r': (6, 0, 46)}, spine={'r': (2, 0, 18)}, head={'r': (-26, 0, 36)}, upperarm_R={'r': (0, 90, 112)}, hand_R={'r': (0, 0, 26)},
          upperarm_L={'r': (-10, -60, -30)})
N_F2 = P_(N_F1, chest={'r': (2, 0, 52)}, head={'r': (-30, 0, 40)}, upperarm_R={'r': (-12, 80, 126)}, hand_R={'r': (0, 0, 30)}, jaw={'r': (0, 0, 0)})
# floreio: broxa erguida, olhar vaidoso para o próprio trabalho
N_FLOR = P_(N_F2, chest={'r': (-6, 0, 40)}, spine={'r': (-2, 0, 14)}, head={'r': (-28, 0, 10)}, upperarm_R={'r': (-40, 60, 130)}, forearm_R={'r': (-40, 0, 0)}, hand_R={'r': (0, 0, 20)},
            upperarm_L={'r': (-20, -80, -40)}, forearm_L={'r': (-90, 0, 0)}, hand_L={'r': (0, 0, 60)})
N_SETTLE = P_(N_GUARD, chest={'r': (0, 0, 10)}, head={'r': (-6, 0, 16)})
N_GOLPE = [(0, N_GUARD), (4, N_A1), (8, N_A2), (11, N_A3), (16, N_B), (18, N_SMEAR), (19, N_CONTACT), (22, N_PASS), (26, N_F1), (31, N_F2),
           (38, N_FLOR), (52, N_SETTLE), (64, N_GUARD), (72, N_GUARD)]
N_IDLE = [(0, N_GUARD), (16, N_IDLE2), (32, N_GUARD), (48, N_IDLE2), (64, N_GUARD)]

# ================================================================== Retrós e Pavio (estresse e folha)
R_GUARD = {'chest': {'r': (2, 0, -6)}, 'head': {'r': (-4, 0, 6)}, 'upperarm.R': {'r': (-70, 10, 0)}, 'forearm.R': {'r': (-30, 0, 0)}, 'hand.R': {'r': (20, 0, 0)},
           'upperarm.L': {'r': (-20, -20, 0)}, 'forearm.L': {'r': (-60, 0, 0)}}
R_ANT = P_(R_GUARD, chest={'r': (-6, 0, -14)}, upperarm_R={'r': (-40, 20, -10)}, forearm_R={'r': (-80, 0, 0)}, hand_R={'r': (40, 0, 0)})
R_ESTOCA = P_(R_GUARD, hips={'l': (0, -0.08, -0.03)}, chest={'r': (16, 0, 8)}, head={'r': (8, 0, 0)}, upperarm_R={'r': (-90, 0, 4)}, forearm_R={'r': (0, 0, 0)}, hand_R={'r': (0, 0, 0)},
              upperarm_L={'r': (20, -50, 0)})
R_GOLPE = [(0, R_GUARD), (2, R_ANT), (6, R_ESTOCA), (14, R_GUARD), (20, R_GUARD)]
P_GUARD = {'chest': {'r': (4, 0, -8)}, 'head': {'r': (-6, 0, 8)}, 'upperarm.R': {'r': (-80, 0, 0)}, 'forearm.R': {'r': (-30, 0, 0)}, 'hand.R': {'r': (-60, 0, 0)},
           'upperarm.L': {'r': (-70, -10, 0)}, 'forearm.L': {'r': (-60, 0, 0)}}
P_PUXA = P_(P_GUARD, chest={'r': (-8, 0, -10)}, head={'r': (-10, 0, 0)}, upperarm_L={'r': (-60, -30, -20)}, forearm_L={'r': (-120, 0, 0)}, jaw={'r': (20, 0, 0)})
P_SOLTA = P_(P_GUARD, chest={'r': (10, 0, 4)}, upperarm_L={'r': (-20, -60, 0)}, forearm_L={'r': (-10, 0, 0)}, jaw={'r': (8, 0, 0)})
P_GOLPE = [(0, P_GUARD), (4, P_PUXA), (12, P_SOLTA), (20, P_GUARD), (26, P_GUARD)]

def hero_idle(g):
    return [(0, g), (16, P_(g, hips={'l': (0, 0, -0.02)}, head={'r': (-2, 0, 12)})), (32, g), (48, g)]

def pulo(g):  # pulinho: agacha (pano comprime), no ar estica, aterrissagem segurada 2 quadros
    sq = {'s': (1.1, 0.88, 1.1)}; st = {'s': (0.94, 1.1, 0.94)}
    C = P_(g, hips={'l': (0, 0, -0.04)}, skirt_F=sq, skirt_B=sq, skirt_L=sq, skirt_R=sq)
    A = P_(g, skirt_F=st, skirt_B=st, skirt_L=st, skirt_R=st, head={'r': (-10, 0, 8)})
    return [(0, C), (4, A), (14, C), (16, g), (18, g)]

# ================================================================== inimigos
C_IDLE1 = {'leg0.L': {'r': (10, 0, 0)}, 'leg1.R': {'r': (10, 0, 0)}, 'leg2.L': {'r': (10, 0, 0)}, 'ant1.L': {'r': (0, 0, 8)}}
C_IDLE2 = {'leg0.R': {'r': (10, 0, 0)}, 'leg1.L': {'r': (10, 0, 0)}, 'leg2.R': {'r': (10, 0, 0)}, 'ant1.R': {'r': (0, 0, -8)}, 'body': {'l': (0, 0, -0.01)}}
# telegrafia: ergue a frente, abre a mandíbula, sacode as antenas (24+ quadros)
C_TEL = {'body': {'r': (-28, 0, 0), 'l': (0, 0.04, 0.02)}, 'head': {'r': (-12, 0, 0)}, 'mand.L': {'r': (0, 0, 28)}, 'mand.R': {'r': (0, 0, -28)},
         'shell.L': {'r': (0, -10, 0)}, 'shell.R': {'r': (0, 10, 0)}, 'leg0.L': {'r': (-30, 0, 0)}, 'leg0.R': {'r': (-30, 0, 0)}, 'leg2.L': {'r': (20, 0, 0)}, 'leg2.R': {'r': (20, 0, 0)}}
C_TEL_A = P_(C_TEL, ant1_L={'r': (0, 0, 16)}, ant1_R={'r': (0, 0, 6)})
C_TEL_B = P_(C_TEL, ant1_L={'r': (0, 0, -6)}, ant1_R={'r': (0, 0, -16)})
# golpeado de cima: achata, pernas abrem, casco abre, antenas tombam
C_HIT = {'body': {'r': (6, 0, 0), 'l': (0, 0, -0.1), 's': (1.15, 1.0, 0.8)}, 'head': {'r': (20, 0, 0)}, 'mand.L': {'r': (0, 0, 35)}, 'mand.R': {'r': (0, 0, -35)},
         'shell.L': {'r': (0, -35, 0)}, 'shell.R': {'r': (0, 35, 0)},
         'leg0.L': {'r': (0, -40, 0)}, 'leg1.L': {'r': (0, -45, 0)}, 'leg2.L': {'r': (0, -40, 0)}, 'leg0.R': {'r': (0, 40, 0)}, 'leg1.R': {'r': (0, 45, 0)}, 'leg2.R': {'r': (0, 40, 0)},
         'ant1.L': {'r': (30, 0, 20)}, 'ant1.R': {'r': (30, 0, -20)}}
# atingido de lado pela pincelada
C_TINTA = {'body': {'r': (0, 14, -18), 'l': (0, 0, -0.02)}, 'head': {'r': (0, 0, -22)}, 'mand.L': {'r': (0, 0, 20)}, 'mand.R': {'r': (0, 0, -10)},
           'ant1.L': {'r': (-10, 0, -20)}, 'ant1.R': {'r': (-10, 0, -30)}, 'leg0.L': {'r': (0, -20, 0)}, 'leg1.L': {'r': (0, -20, 0)}}
C_TINTA2 = P_(C_TINTA, body={'r': (0, 6, -8), 'l': (0, 0, -0.01)}, head={'r': (0, 0, -8)})
# v2: susto (o vizinho do estouro pula, abre as pernas, antenas em pé, mandíbula escancarada)
C_SUSTO = {'body': {'r': (-16, 0, 0), 'l': (0, 0, 0.16)}, 'head': {'r': (-18, 0, 0)}, 'mand.L': {'r': (0, 0, 40)}, 'mand.R': {'r': (0, 0, -40)},
           'shell.L': {'r': (0, -18, 0)}, 'shell.R': {'r': (0, 18, 0)},
           'leg0.L': {'r': (-20, -35, 0)}, 'leg1.L': {'r': (0, -40, 0)}, 'leg2.L': {'r': (20, -35, 0)}, 'leg0.R': {'r': (-20, 35, 0)}, 'leg1.R': {'r': (0, 40, 0)}, 'leg2.R': {'r': (20, 35, 0)},
           'ant1.L': {'r': (-40, 0, 12)}, 'ant1.R': {'r': (-40, 0, -12)}, 'ant2.L': {'r': (-20, 0, 0)}, 'ant2.R': {'r': (-20, 0, 0)}}
C_SUSTO2 = P_(C_SUSTO, body={'r': (-6, 0, 0), 'l': (0, 0, 0.03)}, ant1_L={'r': (-30, 0, 20)}, ant1_R={'r': (-30, 0, -4)})
C_RECUA = P_(C_IDLE1, body={'r': (6, 0, 0), 'l': (0, 0.04, -0.02)}, head={'r': (10, 0, 0)}, ant1_L={'r': (20, 0, 10)}, ant1_R={'r': (20, 0, -10)})
# andar em trípode a 15 poses/s
C_W1 = {'leg0.L': {'r': (-25, 0, 0)}, 'leg2.L': {'r': (-25, 0, 0)}, 'leg1.R': {'r': (-25, 0, 0)}, 'leg0.R': {'r': (15, 0, 10)}, 'leg2.R': {'r': (15, 0, 10)}, 'leg1.L': {'r': (15, 0, -10)},
        'body': {'r': (0, 4, 0), 'l': (0, 0, 0.015)}, 'ant1.L': {'r': (0, 0, 10)}}
C_W2 = {'leg0.R': {'r': (-25, 0, 0)}, 'leg2.R': {'r': (-25, 0, 0)}, 'leg1.L': {'r': (-25, 0, 0)}, 'leg0.L': {'r': (15, 0, -10)}, 'leg2.L': {'r': (15, 0, -10)}, 'leg1.R': {'r': (15, 0, 10)},
        'body': {'r': (0, -4, 0), 'l': (0, 0, -0.005)}, 'ant1.R': {'r': (0, 0, -10)}}

TR_UP = {'wing.L': {'r': (0, -38, 0)}, 'wing.R': {'r': (0, 38, 0)}, 'body': {'l': (0, 0, 0.04)}}
TR_DN = {'wing.L': {'r': (0, 30, 0)}, 'wing.R': {'r': (0, -30, 0)}, 'body': {'l': (0, 0, -0.03)}}
TR_TEL = {'wing.L': {'r': (0, -70, 10)}, 'wing.R': {'r': (0, 70, -10)}, 'body': {'r': (-25, 0, 0), 'l': (0, 0.1, 0.12)}, 'head': {'r': (-15, 0, 0)}}
BS_IDLE = {'flat': {'r': (0, 3, 0)}}
BS_IDLE2 = {'flat': {'r': (0, -3, 0)}, 'eyes': {'l': (0, 0, -0.01)}}
BS_TEL = {'flat': {'r': (-24, 0, 0)}}
BS_TEL2 = {'flat': {'r': (-27, 0, 0)}}
CR_CARREGA = {'upperarm.L': {'r': (-150, -10, 0)}, 'upperarm.R': {'r': (-150, 10, 0)}, 'forearm.L': {'r': (-20, 0, 0)}, 'forearm.R': {'r': (-20, 0, 0)},
              'thigh.L': {'r': (-35, 0, 0)}, 'shin.L': {'r': (40, 0, 0)}, 'thigh.R': {'r': (25, 0, 0)}, 'chest': {'r': (12, 0, 0)}, 'hips': {'l': (0, 0, -0.05)}}
CR_CARREGA2 = P_(CR_CARREGA, thigh_L={'r': (25, 0, 0)}, shin_L={'r': (5, 0, 0)}, thigh_R={'r': (-35, 0, 0)}, shin_R={'r': (40, 0, 0)})

ACTIONS = {
    'tarugo': {'repouso': [(0, REST), (4, REST)], 'idle': T_IDLE, 'golpe': T_GOLPE, 'pulo': pulo(T_GUARD)},
    'anilina': {'repouso': [(0, REST), (4, REST)], 'idle': N_IDLE, 'golpe': N_GOLPE, 'pulo': pulo(N_GUARD)},
    'retros': {'repouso': [(0, REST), (4, REST)], 'idle': hero_idle(R_GUARD), 'golpe': R_GOLPE, 'pulo': pulo(R_GUARD)},
    'pavio': {'repouso': [(0, REST), (4, REST)], 'idle': hero_idle(P_GUARD), 'golpe': P_GOLPE, 'pulo': pulo(P_GUARD)},
    'caruncho': {'repouso': [(0, REST), (4, REST)], 'idle': [(0, C_IDLE1), (9, C_IDLE2), (18, C_IDLE1), (27, C_IDLE2), (36, C_IDLE1)],
                 'telegrafia': [(0, C_IDLE1), (3, P_(C_TEL, body={'r': (-14, 0, 0)})), (6, C_TEL_A), (9, C_TEL_B), (12, C_TEL_A), (15, C_TEL_B), (18, C_TEL_A), (21, C_TEL_B), (24, C_TEL_A), (27, C_TEL_B), (30, C_TEL_A)],
                 'golpeado': [(0, C_HIT), (30, C_HIT)], 'tinta': [(0, C_TINTA), (6, C_TINTA2), (12, C_IDLE1), (18, C_IDLE1)],
                 'susto': [(0, C_SUSTO), (6, C_SUSTO2), (10, C_SUSTO), (14, C_SUSTO2), (20, C_RECUA), (32, C_RECUA), (40, C_IDLE1)],
                 'andar': [(0, C_W1), (4, C_W2), (8, C_W1), (12, C_W2), (16, C_W1)]},
    'traca': {'repouso': [(0, REST), (4, REST)], 'idle': [(0, TR_UP), (3, REST), (6, TR_DN), (9, REST), (12, TR_UP)], 'telegrafia': [(0, TR_TEL), (2, P_(TR_TEL, wing_L={'r': (0, -60, 10)})), (4, TR_TEL)]},
    'bastidor': {'repouso': [(0, REST), (4, REST)], 'idle': [(0, BS_IDLE), (12, BS_IDLE2), (24, BS_IDLE)], 'telegrafia': [(0, BS_TEL), (3, BS_TEL2), (6, BS_TEL)]},
    'contrarregra': {'repouso': [(0, REST), (4, REST)], 'carrega': [(0, CR_CARREGA), (8, CR_CARREGA2), (16, CR_CARREGA)]},
}
SMEARS = {'tarugo': {'golpe': (10, 20, 'macete')}, 'anilina': {'golpe': (16, 18, 'broxa')}}
# (quadros, raio da cápsula do corpo, z0, z1)
COLLIDE = {'tarugo': {'golpe': (list(range(0, 72)), 0.2, 0.42, 0.95)}, 'anilina': {'golpe': (list(range(0, 72)), 0.17, 0.12, 0.86)}}

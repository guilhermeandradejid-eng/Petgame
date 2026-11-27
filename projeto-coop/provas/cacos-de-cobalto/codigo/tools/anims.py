# Clipes pose a pose (chaves CONSTANT a 60 fps). Heróis: golpe em 2s (pose nova a cada 2 quadros
# no trecho rápido, segurada nos extremos); inimigos em 3s (20 poses/s, o "clac-clac" de azulejo).
# Ângulos em graus nos eixos do armature: rx > 0 inclina o tronco para a frente e leva o braço
# pendurado para trás; ry > 0 leva para o lado +X (esquerda do boneco); rz > 0 gira para a esquerda.
from geo import P_

# ================================================================== TIA LAMPARINA
L_GUARD = {
    'hips': {'l': (0, 0, -0.01)}, 'spine': {'r': (-3, 0, 0)}, 'chest': {'r': (-2, 0, -6)}, 'head': {'r': (4, 0, 8)},
    'upperarm.R': {'r': (-62, 12, -10)}, 'forearm.R': {'r': (-78, 0, 0)}, 'hand.R': {'r': (0, 0, 0)}, 'prop.R': {'r': (-20, 0, 0)},
    'upperarm.L': {'r': (2, -10, 0)}, 'forearm.L': {'r': (-78, 0, -38)}, 'hand.L': {'r': (0, 0, 0)},
    'thigh.L': {'r': (-6, -4, 0)}, 'thigh.R': {'r': (6, 4, 0)}, 'foot.L': {'r': (6, 0, 0)},
}
L_IDLE2 = P_(L_GUARD, hips={'l': (0, 0, -0.022)}, chest={'r': (1, 0, -6)}, head={'r': (7, 0, 8)})
L_ANT1 = P_(L_GUARD, hips={'l': (0, 0.03, -0.05)}, spine={'r': (-10, 0, -10)}, chest={'r': (-8, 0, -22)}, head={'r': (-6, 0, 22)},
            upperarm_R={'r': (-20, 75, -10)}, forearm_R={'r': (-60, 0, 0)}, prop_R={'r': (-165, 0, 15)},
            upperarm_L={'r': (-58, -24, 0)}, forearm_L={'r': (-30, 0, 0)}, thigh_L={'r': (-12, -6, 0)}, shin_L={'r': (14, 0, 0)}, thigh_R={'r': (14, 6, 0)}, shin_R={'r': (12, 0, 0)})
L_ANT2 = P_(L_ANT1, hips={'l': (0, 0.05, -0.07)}, spine={'r': (-15, 0, -16)}, chest={'r': (-12, 0, -32)}, head={'r': (-10, 0, 30)},
            upperarm_R={'r': (10, 85, -10)}, forearm_R={'r': (-50, 0, 0)}, prop_R={'r': (135, 0, 0)}, upperarm_L={'r': (-72, -30, 0)})
L_SMEAR = P_(L_ANT2, hips={'l': (0, 0.0, -0.05)}, spine={'r': (0, 0, 0)}, chest={'r': (0, 0, 4)}, head={'r': (2, 0, 12)},
             upperarm_R={'r': (-172, 6, -6)}, forearm_R={'r': (-18, 0, 0)}, prop_R={'r': (100, 0, 0)}, upperarm_L={'r': (-40, -20, 0)}, forearm_L={'r': (-30, 0, 0)})
L_HIT = P_(L_GUARD, hips={'l': (0, -0.07, -0.07)}, spine={'r': (14, 0, 8)}, chest={'r': (14, 0, 22)}, head={'r': (8, 0, -6)},
           upperarm_R={'r': (-98, 4, 0)}, forearm_R={'r': (-6, 0, 0)}, prop_R={'r': (78, 0, 0)},
           upperarm_L={'r': (28, -30, 0)}, forearm_L={'r': (-20, 0, 0)},
           thigh_L={'r': (-30, -6, 0)}, shin_L={'r': (22, 0, 0)}, foot_L={'r': (12, 0, 0)}, thigh_R={'r': (26, 8, 0)}, shin_R={'r': (18, 0, 0)}, foot_R={'r': (-30, 0, 0)})
L_FOLLOW = P_(L_HIT, hips={'l': (0, -0.08, -0.08)}, spine={'r': (20, 0, 12)}, chest={'r': (18, 0, 30)}, head={'r': (12, 0, -10)},
              upperarm_R={'r': (-58, -4, 6)}, forearm_R={'r': (-4, 0, 0)}, prop_R={'r': (32, 0, 0)}, upperarm_L={'r': (40, -34, 0)})
L_RECOV = P_(L_GUARD, hips={'l': (0, -0.04, -0.04)}, spine={'r': (8, 0, 4)}, chest={'r': (6, 0, 12)}, head={'r': (6, 0, 0)},
             upperarm_R={'r': (-74, 8, -4)}, forearm_R={'r': (-48, 0, 0)}, prop_R={'r': (20, 0, 0)}, upperarm_L={'r': (8, -24, 0)}, forearm_L={'r': (-40, 0, -10)},
             thigh_L={'r': (-20, -6, 0)}, shin_L={'r': (14, 0, 0)}, thigh_R={'r': (16, 6, 0)})
L_SETTLE = P_(L_GUARD, hips={'l': (0, 0.01, -0.02)}, spine={'r': (-6, 0, -2)}, chest={'r': (-5, 0, -10)}, head={'r': (0, 0, 10)})

# Corpo inteiro como bloco (a louça não estica): o quadril inclina e gira para trás na antecipação
# (tilt de 15 a 20°), e na descida o giro começa no quadril e chega ao peito e à cabeça 2 quadros
# depois (defasagem de 2 quadros, quadril -> peito -> cabeça), sem esticar malha nenhuma.
HB_ANT1 = {'l': (0, 0.03, -0.05), 'r': (-7, -8, -12)}
HB_ANT2 = {'l': (0, 0.05, -0.07), 'r': (-10, -12, -22)}
HB_HIT = {'l': (0, -0.07, -0.07), 'r': (12, 8, 24)}
HB_FOL = {'l': (0, -0.08, -0.08), 'r': (16, 10, 30)}
L_ANT1b = P_(L_ANT1, hips=HB_ANT1, spine={'r': (-6, 0, -6)}, chest={'r': (-5, 0, -14)})
L_ANT2b = P_(L_ANT2, hips=HB_ANT2, spine={'r': (-7, 0, -8)}, chest={'r': (-6, 0, -18)}, head={'r': (-6, 0, 34)})
L_DESC1 = P_(L_ANT2b, hips={'l': (0, 0.0, -0.06), 'r': (2, 0, 4)})                     # 13: só o quadril sai
L_SMEARb = P_(L_SMEAR, hips={'l': (0, -0.03, -0.06), 'r': (8, 5, 16)}, chest={'r': (-4, 0, -10)}, head={'r': (-4, 0, 26)})  # 15: peito ainda atrás
L_HITb = P_(L_HIT, hips=HB_HIT, spine={'r': (8, 0, 4)}, chest={'r': (8, 0, 10)}, head={'r': (4, 0, 6)})   # 17: peito chega, cabeça atrasada
L_HIT2 = P_(L_HITb, head={'r': (8, 0, -8)})                                               # 19: cabeça chega
L_FOLLOWb = P_(L_FOLLOW, hips=HB_FOL, spine={'r': (12, 0, 6)}, chest={'r': (10, 0, 16)}, head={'r': (10, 0, -12)})
L_RECOVb = P_(L_RECOV, hips={'l': (0, -0.04, -0.04), 'r': (6, 4, 10)})
LAMP_LANCAR = [(1, L_GUARD), (5, L_ANT1b), (9, L_ANT2b), (13, L_DESC1), (15, L_SMEARb), (17, L_HITb), (19, L_HIT2), (23, P_(L_HIT2, chest={'r': (10, 0, 14)})),
               (25, L_FOLLOWb), (35, P_(L_FOLLOWb, chest={'r': (10, 0, 18)}, upperarm_R={'r': (-62, -2, 4)})), (41, L_RECOVb), (51, L_SETTLE), (61, L_GUARD), (90, L_GUARD)]
LAMP_IDLE = [(1, L_GUARD), (31, L_IDLE2), (61, L_GUARD)]

# ================================================================== BENTO RODO
B_GUARD = {
    'spine': {'r': (-2, 0, 0)}, 'chest': {'r': (-3, 0, 0)}, 'head': {'r': (6, 0, -6)},
    'upperarm.R': {'r': (-6, 10, 0)}, 'forearm.R': {'r': (-28, 0, 0)}, 'prop.R': {'r': (30, 0, 0)},
    'upperarm.L': {'r': (-4, -10, 0)}, 'forearm.L': {'r': (-20, 0, 0)},
    'thigh.L': {'r': (0, -4, 0)}, 'thigh.R': {'r': (0, 4, 0)},
}
B_ANT = P_(B_GUARD, hips={'l': (0, 0.03, -0.07)}, spine={'r': (6, 0, 14)}, chest={'r': (4, 0, 22)}, head={'r': (4, 0, -18)},
           upperarm_L={'r': (58, -14, 0)}, forearm_L={'r': (-10, 0, 0)}, upperarm_R={'r': (-30, 16, 0)},
           thigh_L={'r': (-14, -6, 0)}, shin_L={'r': (22, 0, 0)}, thigh_R={'r': (-10, 6, 0)}, shin_R={'r': (20, 0, 0)})
B_SMEAR = P_(B_ANT, hips={'l': (0, 0.0, -0.05)}, spine={'r': (10, 0, 0)}, chest={'r': (8, 0, -6)}, upperarm_L={'r': (-30, -20, 0)}, head={'r': (6, 0, -4)})
B_REL = P_(B_GUARD, hips={'l': (0, -0.06, -0.05)}, spine={'r': (16, 0, -10)}, chest={'r': (14, 0, -22)}, head={'r': (10, 0, 4)},
           upperarm_L={'r': (-112, -18, 0)}, forearm_L={'r': (-12, 0, 0)}, upperarm_R={'r': (12, 18, 0)}, forearm_R={'r': (-30, 0, 0)},
           thigh_L={'r': (-26, -4, 0)}, shin_L={'r': (18, 0, 0)}, thigh_R={'r': (18, 6, 0)}, shin_R={'r': (10, 0, 0)}, foot_R={'r': (-20, 0, 0)})
B_FOLLOW = P_(B_REL, spine={'r': (20, 0, -14)}, chest={'r': (16, 0, -28)}, upperarm_L={'r': (-128, -20, 0)}, head={'r': (12, 0, 6)})
B_RECOV = P_(B_GUARD, hips={'l': (0, -0.02, -0.03)}, spine={'r': (6, 0, -4)}, chest={'r': (4, 0, -8)}, upperarm_L={'r': (-40, -14, 0)})
BENTO_BALDE = [(1, B_GUARD), (7, B_ANT), (19, P_(B_ANT, hips={'l': (0, 0.035, -0.08)})), (23, B_SMEAR), (25, B_REL), (29, P_(B_REL, upperarm_L={'r': (-116, -18, 0)})),
               (31, B_FOLLOW), (43, P_(B_FOLLOW, upperarm_L={'r': (-120, -20, 0)})), (51, B_RECOV), (63, P_(B_GUARD, chest={'r': (-6, 0, 4)})), (73, B_GUARD), (90, B_GUARD)]
# isolado: o choque passa por baixo; susto (pulo em pose segurada), depois a pose de quem estava untado de propósito
B_SUSTO = P_(B_GUARD, root={'l': (0, 0, 0.20)}, hips={'l': (0, 0, 0.02)}, spine={'r': (-8, 0, 0)}, chest={'r': (-8, 0, 0)}, head={'r': (-10, 0, 0)},
             upperarm_L={'r': (-30, -70, 0)}, forearm_L={'r': (-30, 0, 0)}, upperarm_R={'r': (-34, 50, 0)},
             thigh_L={'r': (-20, -10, 0)}, shin_L={'r': (40, 0, 0)}, thigh_R={'r': (-24, 10, 0)}, shin_R={'r': (44, 0, 0)})
B_POUSO = P_(B_GUARD, hips={'l': (0, 0, -0.06)}, spine={'r': (6, 0, 0)}, thigh_L={'r': (-16, -6, 0)}, shin_L={'r': (24, 0, 0)}, thigh_R={'r': (-16, 6, 0)}, shin_R={'r': (24, 0, 0)},
             upperarm_L={'r': (-20, -40, 0)}, upperarm_R={'r': (-24, 30, 0)})
B_SNOB = P_(B_GUARD, spine={'r': (-6, 0, 0)}, chest={'r': (-8, 0, 6)}, head={'r': (-12, 0, 14)},
            upperarm_L={'r': (6, -36, 0)}, forearm_L={'r': (-110, 0, -30)}, upperarm_R={'r': (-20, 14, 0)})
BENTO_ISOLADO = [(1, B_GUARD), (3, B_SUSTO), (13, B_POUSO), (21, P_(B_POUSO, hips={'l': (0, 0, -0.03)})), (29, B_SNOB), (45, P_(B_SNOB, head={'r': (-14, 0, 18)})), (90, P_(B_SNOB, head={'r': (-14, 0, 18)}))]
# espera em contraposto: peso na perna esquerda, quadril deslocado e inclinado, ombros no contra,
# rodo na diagonal apoiado no ombro direito (quebra a linha vertical do Bento)
B_IDLE = {
    'hips': {'l': (0.035, 0, -0.012), 'r': (0, 6, 0)}, 'spine': {'r': (-2, -3, 2)}, 'chest': {'r': (-4, -6, 6)}, 'head': {'r': (8, 7, -10)},
    'thigh.L': {'r': (0, -6, 0)}, 'shin.L': {'r': (0, 0, 0)}, 'thigh.R': {'r': (-14, 0, 6)}, 'shin.R': {'r': (24, 0, 0)}, 'foot.R': {'r': (-10, 0, 0)},
    'upperarm.R': {'r': (-28, 22, 0)}, 'forearm.R': {'r': (-112, 0, 0)}, 'prop.R': {'r': (-100, -75, 15)},
    'upperarm.L': {'r': (6, -14, 0)}, 'forearm.L': {'r': (-16, 0, 0)},
}
B_IDLE2 = P_(B_IDLE, hips={'l': (0.038, 0, -0.02), 'r': (0, 7, 0)}, chest={'r': (-3, -7, 7)}, head={'r': (10, 8, -6)})
BENTO_IDLE = [(1, B_IDLE), (37, B_IDLE2), (73, B_IDLE)]

# ================================================================== LASCA (3s)
S_N = {'corpo': {'r': (0, 0, 0)}}
S_UP = {'root': {'l': (0, 0, 0.16)}, 'corpo': {'r': (-6, 0, 0)}, 'pe.L': {'r': (30, 0, 0)}, 'pe.R': {'r': (30, 0, 0)}, 'lasca1': {'l': (0.03, 0, 0.05)}, 'lasca2': {'l': (-0.03, 0, 0.04)}}
S_SQ = {'corpo': {'r': (10, 0, 0), 'l': (0, 0, -0.06)}, 'cabeca': {'r': (12, 0, 0)}, 'lasca1': {'l': (0.02, 0, -0.04)}, 'lasca2': {'l': (-0.02, 0, -0.04)}}
S_CROUCH = {'corpo': {'r': (24, 0, 0), 'l': (0, 0, -0.09)}, 'cabeca': {'r': (-18, 0, 0)}, 'lasca1': {'l': (0.05, -0.02, -0.06)}, 'lasca2': {'l': (-0.05, -0.02, -0.06)},
            'pe.L': {'r': (-10, 0, 0)}, 'pe.R': {'r': (-10, 0, 0)}}
S_CROUCH2 = P_(S_CROUCH, corpo={'r': (28, 0, 3), 'l': (0, 0, -0.10)}, cabeca={'r': (-22, 0, 4)})
S_HIT = {'root': {'l': (0, 0.06, 0.12)}, 'corpo': {'r': (-38, 0, 14), 'l': (0, 0.03, 0.06)}, 'cabeca': {'r': (-30, 20, 30), 'l': (0.06, 0.02, 0.12)},
         'lasca1': {'l': (0.16, 0.08, 0.10), 'r': (80, 30, 0)}, 'lasca2': {'l': (-0.16, 0.10, 0.06), 'r': (-60, 0, 40)}, 'pe.L': {'r': (40, 0, -20), 'l': (0.05, 0.02, 0.03)}, 'pe.R': {'r': (30, 0, 30), 'l': (-0.05, 0.03, 0.04)}}
S_HIT2 = P_(S_HIT, root={'l': (0, 0.1, 0.05)}, corpo={'r': (-24, 0, 20), 'l': (0, 0.02, 0.03)}, cabeca={'r': (-10, 10, 40), 'l': (0.04, 0.01, 0.07)}, lasca1={'l': (0.2, 0.12, 0.02), 'r': (140, 40, 0)}, lasca2={'l': (-0.2, 0.14, 0.0), 'r': (-100, 0, 60)})
S_FALL = {'root': {'l': (0, 0.14, 0.0)}, 'corpo': {'r': (-70, 0, 20), 'l': (0, 0.08, -0.12)}, 'cabeca': {'r': (-20, 0, 50), 'l': (0.12, 0.06, -0.3)}, 'lasca1': {'l': (0.26, 0.2, -0.4), 'r': (180, 40, 0)}, 'lasca2': {'l': (-0.25, 0.2, -0.3), 'r': (-160, 0, 60)},
          'pe.L': {'r': (80, 0, -30)}, 'pe.R': {'r': (70, 0, 40)}}
LASCA_PULO = [(1, S_N), (7, S_SQ), (13, S_UP), (22, P_(S_UP, root={'l': (0, 0, 0.12)})), (28, S_SQ), (34, S_N), (60, S_N)]
LASCA_TELEGRAFIA = [(1, S_N), (4, S_CROUCH), (10, P_(S_CROUCH, corpo={'r': (25, 0, -2), 'l': (0, 0, -0.095)})), (16, S_CROUCH2), (22, P_(S_CROUCH2, lasca1={'l': (0.06, -0.02, -0.07)})), (28, S_CROUCH2), (60, S_CROUCH2)]
LASCA_GOLPEADO = [(1, S_HIT), (7, S_HIT2), (16, P_(S_HIT2, root={'l': (0, 0.12, 0.0)})), (22, S_FALL), (60, S_FALL)]

# ================================================================== CROSTA (3s)
C_N = {'corpo': {'r': (6, 0, 0)}, 'braco.L': {'r': (0, 0, 0)}}
C_UP = {'root': {'l': (0, 0, 0.0)}, 'corpo': {'r': (-14, 0, 0), 'l': (0, 0, 0.04)}, 'cabeca': {'r': (-16, 0, 0)}, 'braco.L': {'r': (-150, -10, 0)}, 'braco.R': {'r': (-150, 10, 0)}}
C_UP2 = P_(C_UP, corpo={'r': (-20, 0, 0), 'l': (0, 0, 0.06)}, braco_L={'r': (-165, -12, 0)}, braco_R={'r': (-165, 12, 0)})
C_SLAM = {'corpo': {'r': (34, 0, 0), 'l': (0, 0, -0.12)}, 'cabeca': {'r': (10, 0, 0)}, 'braco.L': {'r': (-60, -6, 0)}, 'braco.R': {'r': (-60, 6, 0)}}
CROSTA_TELEGRAFIA = [(1, C_N), (10, C_UP), (22, P_(C_UP, corpo={'r': (-17, 0, 0), 'l': (0, 0, 0.05)})), (34, C_UP2), (43, C_SLAM), (70, P_(C_SLAM, corpo={'r': (30, 0, 0), 'l': (0, 0, -0.1)})), (100, C_N)]
CROSTA_IDLE = [(1, C_N), (31, P_(C_N, corpo={'r': (8, 0, 0), 'l': (0, 0, -0.02)})), (61, C_N)]

# ================================================================== LADRILHEIRO (3s)
T_N = {'painel': {'r': (4, 0, 0)}}
T_UP = {'root': {'l': (0, 0, 0.05)}, 'painel': {'r': (-24, 0, 0)}, 'braco.L': {'r': (-40, -20, 0)}, 'braco.R': {'r': (-40, 20, 0)}, 'perna.L': {'r': (-10, 0, 0)}}
LADRILHEIRO_ERGUER = [(1, T_N), (13, P_(T_UP, painel={'r': (-12, 0, 0)})), (25, T_UP), (37, P_(T_UP, painel={'r': (-30, 0, 0)})), (60, P_(T_UP, painel={'r': (-30, 0, 0)}))]
LADRILHEIRO_IDLE = [(1, T_N), (31, P_(T_N, painel={'r': (6, 0, 2)})), (61, T_N)]

N_GUARD = {'chest': {'r': (-4, 0, 0)}, 'head': {'r': (-6, 0, 8)}, 'upperarm.L': {'r': (-20, -40, 0)}, 'upperarm.R': {'r': (-20, 40, 0)}, 'forearm.L': {'r': (-30, 0, 0)}, 'forearm.R': {'r': (-30, 0, 0)}}
G_GUARD = {'spine': {'r': (10, 0, 0)}, 'chest': {'r': (14, 0, 0)}, 'head': {'r': (-18, 0, 0)}, 'upperarm.R': {'r': (-20, 8, 0)}, 'forearm.R': {'r': (-40, 0, 0)}, 'prop.R': {'r': (55, 0, 0)},
           'upperarm.L': {'r': (10, -6, 0)}, 'forearm.L': {'r': (-60, 0, -20)}}
CLIPS = {
    'nina': {'idle': [(1, N_GUARD), (31, P_(N_GUARD, hips={'l': (0, 0, -0.015)})), (61, N_GUARD)]},
    'galvao': {'idle': [(1, G_GUARD), (31, P_(G_GUARD, head={'r': (-14, 0, 4)})), (61, G_GUARD)]},
    'lamparina': {'lancar': LAMP_LANCAR, 'idle': LAMP_IDLE},
    'bento': {'balde': BENTO_BALDE, 'isolado': BENTO_ISOLADO, 'idle': BENTO_IDLE},
    'lasca': {'pulo': LASCA_PULO, 'telegrafia': LASCA_TELEGRAFIA, 'golpeado': LASCA_GOLPEADO},
    'crosta': {'telegrafia': CROSTA_TELEGRAFIA, 'idle': CROSTA_IDLE},
    'ladrilheiro': {'erguer': LADRILHEIRO_ERGUER, 'idle': LADRILHEIRO_IDLE},
}

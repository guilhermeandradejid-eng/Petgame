# Poses e ações de "A Pequena Hoste". Rotação em graus no espaço do esqueleto (X = esquerda do boneco, Y = costas,
# Z = cima): +rx dobra para a frente (coluna) ou joga o braço para trás; -rx levanta o braço para a frente;
# +rz vira para a esquerda; no braço esquerdo -ry abre para fora, no direito +ry abre para fora.
# Regra da casa: o jogador antecipa pouco e se recupera muito; o inimigo antecipa muito (24 a 60 quadros).
from animar import *

# ------------------------------------------------------------------ base comum
BASE = P(upperarm_L={'r': (0, -14, 0)}, upperarm_R={'r': (0, 14, 0)},
         forearm_L={'r': (-18, 0, 0)}, forearm_R={'r': (-18, 0, 0)},
         thigh_L={'r': (0, -3, 0)}, thigh_R={'r': (0, 3, 0)})

def respira(base, n=60, amp=0.03, step=2, cabeca=3.0):
    """idle: o peito estica em degrau (hold), a cabeça acompanha um pouco atrasada."""
    a = M(base, chest={'s': (1 + amp * 0.5, 1 + amp, 1 + amp * 0.5)}, head={'r': (-cabeca, 0, 0)})
    b = M(base, spine={'r': (2, 0, 0)}, head={'r': (cabeca * 0.6, 0, 1.5)})
    return seq([(0, base, 'io'), (n * 0.45, a, 'io'), (n, b, 'io'), (n * 1.5, base, 'lin')], step)

def ciclo_corrida(base, n=20, passo=40, braco=35, pulo=0.03, incl=12, step=2, peso=1.0):
    """corrida em 4 poses-chave (contato, baixa, passagem, alta) espelhadas; 'peso' achata a baixa."""
    def pose(fase):
        s = 1 if fase == 0 else -1
        return M(base, root={'l': (0, 0, 0.0)}, spine={'r': (incl, 0, 0)}, head={'r': (-incl * 0.6, 0, 0)},
                 thigh_L={'r': (-passo * s, 0, 0)}, thigh_R={'r': (passo * s, 0, 0)},
                 shin_L={'r': (10 if s > 0 else 60, 0, 0)}, shin_R={'r': (60 if s > 0 else 10, 0, 0)},
                 upperarm_L={'r': (braco * s, 0, 0)}, upperarm_R={'r': (-braco * s, 0, 0)},
                 hips={'r': (0, 0, -8 * s)}, chest={'r': (0, 0, 10 * s)})
    c1 = pose(0); c2 = pose(1)
    baixa1 = M(c1, root={'l': (0, 0, -pulo * peso)}, hips={'s': (1.04, 1.04, 0.94)})
    alta1 = M(c1, root={'l': (0, 0, pulo * 1.5)})
    baixa2 = M(c2, root={'l': (0, 0, -pulo * peso)}, hips={'s': (1.04, 1.04, 0.94)})
    alta2 = M(c2, root={'l': (0, 0, pulo * 1.5)})
    q = n / 4
    return seq([(0, c1, 'out'), (q * 0.5, baixa1, 'io'), (q * 1.5, alta1, 'in'), (q * 2, c2, 'out'), (q * 2.5, baixa2, 'io'), (q * 3.5, alta2, 'in'), (n, c1, 'lin')], step)

# ================================================================== PORTA-ESTANDARTE
PB = M(BASE, upperarm_L={'r': (-8, -4, 0)}, forearm_L={'r': (-6, 0, 0)}, hand_R={'r': (70, 0, 0)},
       chest={'r': (0, 0, 6)}, head={'r': (0, 4, 0)}, shoulder_L={'r': (0, 0, 0)}, shoulder_R={'r': (0, -5, 0)})  # ombros a 10° um do outro

def porta():
    A = {}
    A['idle'] = respira(PB, 72, 0.025, cabeca=2.0)
    run = M(PB, upperarm_L={'r': (-20, 0, 0)}, hand_R={'r': (40, 0, 0)})
    A['corre'] = ciclo_corrida(run, n=24, passo=32, braco=22, pulo=0.025, incl=16, peso=1.6)
    # Investida de Escudo: antecipação curta (5q), avanço, contato achatado a 0,85, segura, recupera devagar (14q)
    ant = M(PB, root={'l': (0, 0.06, -0.03)}, spine={'r': (-8, 0, -18)}, chest={'r': (0, 0, -14)}, upperarm_L={'r': (25, 0, 0)},
            forearm_L={'r': (-30, 0, 0)}, thigh_L={'r': (-30, 0, 0)}, shin_L={'r': (40, 0, 0)}, thigh_R={'r': (20, 0, 0)}, shin_R={'r': (20, 0, 0)},
            hips={'s': (1.05, 1.05, 0.9)})
    lunge = M(PB, root={'l': (0, -0.55, 0.02)}, spine={'r': (26, 0, 14)}, chest={'r': (6, 0, 16)}, upperarm_L={'r': (-75, -15, 0)},
              forearm_L={'r': (-40, 0, 0)}, thigh_L={'r': (-55, 0, 0)}, shin_L={'r': (30, 0, 0)}, thigh_R={'r': (45, 0, 0)}, shin_R={'r': (35, 0, 0)},
              head={'r': (-14, 0, 0)}, hips={'s': (0.96, 0.96, 1.08)})
    contato = M(lunge, root={'l': (0, -0.05, -0.03)}, hips={'s': (1.1, 1.1, 0.85)}, chest={'s': (1.08, 1.08, 0.88)})
    rec = M(PB, root={'l': (0, -0.65, 0)}, spine={'r': (8, 0, 4)}, upperarm_L={'r': (-30, 0, 0)})
    fim = M(PB, root={'l': (0, -0.65, 0)})
    A['investida'] = seq([(0, PB, 'in'), (5, ant, ('snap', 1)), (11, lunge, ('lin', 1)), (13, contato, 'hold'), (21, contato, ('out', 1)),
                          (35, rec, ('io', 2)), (48, fim, 'lin')])
    # Fincar: respira fundo (12q), alcança o mastro nas costas, ergue com as duas mãos, crava (contato), segura de perfil
    resp = M(PB, chest={'s': (1.05, 1.06, 1.05)}, head={'r': (-10, 0, 0)}, spine={'r': (-4, 0, 0)})
    alc = M(PB, upperarm_R={'r': (-160, 10, 0)}, forearm_R={'r': (-70, 0, 0)}, upperarm_L={'r': (-140, -20, 0)}, forearm_L={'r': (-80, 0, 0)},
            spine={'r': (-10, 0, 0)}, head={'r': (-12, 0, 0)}, hand_R={'r': (0, 0, 0)})
    alto = M(PB, upperarm_R={'r': (-175, 15, 0)}, forearm_R={'r': (-15, 0, 0)}, upperarm_L={'r': (-170, -15, 0)}, forearm_L={'r': (-20, 0, 0)},
             spine={'r': (-16, 0, 0)}, head={'r': (-18, 0, 0)}, root={'l': (0, 0, 0.05)}, thigh_L={'r': (-12, 0, 0)}, shin_L={'r': (15, 0, 0)}, hand_R={'r': (0, 0, 0)})
    crava = M(PB, upperarm_R={'r': (-80, 18, 0)}, forearm_R={'r': (-20, 0, 0)}, upperarm_L={'r': (-75, -18, 0)}, forearm_L={'r': (-25, 0, 0)},
              spine={'r': (24, 0, 0)}, head={'r': (6, 0, 0)}, root={'l': (0, 0, -0.06)}, thigh_L={'r': (-40, 0, 0)}, shin_L={'r': (55, 0, 0)},
              thigh_R={'r': (20, 0, 0)}, shin_R={'r': (40, 0, 0)}, hips={'s': (1.1, 1.1, 0.86)}, hand_R={'r': (0, 0, 0)})
    segura = M(PB, upperarm_R={'r': (-100, 20, 0)}, forearm_R={'r': (-40, 0, 0)}, upperarm_L={'r': (-30, -10, 0)}, forearm_L={'r': (-60, 0, 0)},
               spine={'r': (-4, 0, 0)}, head={'r': (-10, 0, 0)}, chest={'s': (1.04, 1.04, 1.04)}, hand_R={'r': (0, 0, 0)})
    A['fincar'] = seq([(0, PB, 'io'), (12, resp, 'io'), (20, alc, ('io', 1)), (30, alto, 'hold'), (34, alto, ('snap', 1)), (40, crava, 'hold'),
                       (46, crava, ('out', 2)), (66, segura, 'lin')])
    # Juramento: incha a 1,15 com o peito estufado, escudo erguido, maça para trás; treme em degrau
    jur = M(PB, chest={'s': (1.15, 1.15, 1.15)}, spine={'r': (-8, 0, 0)}, head={'r': (-14, 0, 0)}, upperarm_L={'r': (-60, -25, 0)},
            forearm_L={'r': (-70, 0, 0)}, upperarm_R={'r': (30, 30, 0)}, forearm_R={'r': (-40, 0, 0)}, hand_R={'r': (20, 0, 0)},
            thigh_L={'r': (-15, -12, 0)}, thigh_R={'r': (12, 14, 0)}, shin_L={'r': (10, 0, 0)}, root={'l': (0, 0, -0.01)})
    jur2 = M(jur, root={'l': (0.008, 0, -0.015)}, chest={'r': (0, 0, 2)})
    A['juramento'] = seq([(0, PB, ('out', 1)), (8, jur, ('lin', 4)), (24, jur2, ('lin', 4)), (32, jur, ('lin', 4)), (40, jur2, ('lin', 4)), (48, jur, 'lin')])
    # Recepção (Dobre Duplo): mãos abertas para cima, pega, o sino pesado gira o corpo inteiro e arrasta meio passo
    pron = M(PB, upperarm_R={'r': (-120, 30, 0)}, forearm_R={'r': (-30, 0, 0)}, upperarm_L={'r': (-90, -30, 0)}, forearm_L={'r': (-40, 0, 0)},
             head={'r': (-25, 0, 0)}, spine={'r': (-10, 0, 0)}, hand_R={'r': (-30, 0, 0)})
    pega = M(pron, root={'l': (0, 0, -0.04)}, hips={'s': (1.08, 1.08, 0.88)}, upperarm_R={'r': (20, 0, 0)}, hand_R={'r': (60, 0, 0)})
    g1 = M(PB, upperarm_R={'r': (-80, 80, 0)}, forearm_R={'r': (-10, 0, 0)}, hand_R={'r': (90, 0, 0)}, spine={'r': (0, 0, 80)}, chest={'r': (0, 0, 30)},
           head={'r': (0, 0, -20)}, root={'l': (0, 0, 0)}, upperarm_L={'r': (-40, -50, 0)})
    g2 = M(PB, upperarm_R={'r': (-80, 85, 0)}, forearm_R={'r': (-5, 0, 0)}, hand_R={'r': (90, 0, 0)}, root={'l': (0.12, -0.18, 0)},
           spine={'r': (0, 0, 40)}, chest={'r': (0, 0, 20)}, head={'r': (0, 0, -30)}, upperarm_L={'r': (-40, -60, 0)}, thigh_L={'r': (-30, 0, 0)}, shin_L={'r': (30, 0, 0)})
    g3 = M(PB, upperarm_R={'r': (-70, 70, 0)}, forearm_R={'r': (-20, 0, 0)}, hand_R={'r': (80, 0, 0)}, root={'l': (0.2, -0.3, -0.02)},
           spine={'r': (6, 0, -20)}, chest={'r': (0, 0, -10)}, head={'r': (0, 0, 14)}, hips={'s': (1.06, 1.06, 0.9)})
    pousa = M(PB, upperarm_R={'r': (-20, 20, 0)}, forearm_R={'r': (-30, 0, 0)}, hand_R={'r': (80, 0, 0)}, root={'l': (0.22, -0.32, 0)},
              spine={'r': (10, 0, 0)}, head={'r': (4, 0, 0)})
    A['recepcao'] = seq([(0, pron, 'hold'), (6, pron, ('in', 1)), (9, pega, ('out', 1)), (13, g1, ('in', 1)), (22, g2, ('lin', 1)), (30, g3, ('out', 1)),
                         (38, g3, ('io', 2)), (60, pousa, 'lin')])
    # passe desajeitado de volta: segura o sino com as duas mãos atrás da cabeça e joga torto, quase cai
    p0 = M(PB, upperarm_R={'r': (-160, 10, 0)}, forearm_R={'r': (-60, 0, 0)}, upperarm_L={'r': (-150, -10, 0)}, forearm_L={'r': (-60, 0, 0)},
           spine={'r': (-14, 0, -6)}, head={'r': (-8, 0, 0)}, hand_R={'r': (-40, 0, 0)})
    p1 = M(PB, upperarm_R={'r': (-60, 0, 0)}, forearm_R={'r': (0, 0, 0)}, upperarm_L={'r': (-60, 0, 0)}, forearm_L={'r': (0, 0, 0)},
           spine={'r': (28, 0, 12)}, head={'r': (-10, 0, 0)}, root={'l': (0, -0.08, -0.02)}, thigh_L={'r': (-40, 0, 0)}, shin_L={'r': (20, 0, 0)})
    p2 = M(p1, spine={'r': (10, 8, 10)}, root={'l': (0.04, -0.12, -0.04)}, thigh_R={'r': (30, 10, 0)}, head={'r': (10, 0, 6)})
    A['passa'] = seq([(0, PB, 'io'), (10, p0, ('snap', 1)), (16, p1, ('out', 1)), (22, p2, ('io', 2)), (44, M(PB, root={'l': (0.04, -0.12, 0)}), 'lin')])
    A['atingido'] = seq([(0, PB, 'out'), (3, M(PB, spine={'r': (-10, -6, 0)}, head={'r': (-12, 0, 6)}, root={'l': (0.02, 0.03, 0)}), ('out', 1)), (16, PB, 'lin')])
    A['rest'] = seq([(0, {}, 'lin'), (2, {}, 'lin')])
    return A

# ================================================================== SINEIRA
SB = M(BASE, upperarm_R={'r': (5, 32, 0)}, forearm_R={'r': (-10, 0, 0)}, hand_R={'r': (85, 0, 0)}, upperarm_L={'r': (-20, -8, 0)},
       forearm_L={'r': (-80, 0, 20)}, spine={'r': (6, 0, 0)}, chest={'r': (0, -3, 4)}, head={'r': (-6, -4, 0)})

def sineira():
    A = {}
    A['idle'] = respira(SB, 66, 0.03, cabeca=3.0)
    # arremesso da Unção (mão esquerda, por baixo), apontando com o queixo
    a0 = M(SB, upperarm_L={'r': (50, -20, 0)}, forearm_L={'r': (-20, 0, 0)}, spine={'r': (10, 0, -15)}, head={'r': (-10, 0, 10)},
           upperarm_R={'r': (30, 0, 0)}, hips={'s': (1.04, 1.04, 0.93)})
    a1 = M(SB, upperarm_L={'r': (-120, -10, 0)}, forearm_L={'r': (-10, 0, 0)}, spine={'r': (-4, 0, 15)}, head={'r': (-22, 0, -6)},
           upperarm_R={'r': (-20, 0, 0)}, root={'l': (0, -0.05, 0.02)})
    a2 = M(SB, upperarm_L={'r': (-80, -20, 0)}, forearm_L={'r': (-20, 0, 0)}, spine={'r': (8, 0, 8)}, head={'r': (-18, 0, 0)}, root={'l': (0, -0.07, 0)})
    A['arremessa'] = seq([(0, SB, 'in'), (4, a0, ('io', 1)), (9, a1, ('out', 1)), (16, a2, ('io', 2)), (36, M(SB, root={'l': (0, -0.07, 0)}), 'lin')])
    A['recua'] = ciclo_corrida(M(SB, spine={'r': (-6, 0, 0)}), n=28, passo=22, braco=12, pulo=0.015, incl=-6)
    # grito "Segura!": braço livre para cima, cabeça para trás, sino puxando o braço direito para baixo
    g = M(SB, upperarm_L={'r': (-150, -30, 0)}, forearm_L={'r': (-30, 0, 0)}, head={'r': (-24, 0, 0)}, spine={'r': (-10, 0, 0)}, chest={'s': (1.05, 1.05, 1.08)})
    g2 = M(g, root={'l': (0, 0, 0.03)}, head={'r': (-4, 0, 3)})
    A['grita'] = seq([(0, SB, ('out', 1)), (6, g, ('lin', 2)), (12, g2, ('lin', 2)), (18, g, ('lin', 2)), (24, g2, ('lin', 2)), (30, g, 'lin')])
    # golpe de sino com passe: sino para trás (4q), corpo à frente (contraponto), arco de pêndulo, solta no quadro ativo,
    # o peso puxa 0,3 m para a frente (follow-through), assenta
    k0 = M(SB, upperarm_R={'r': (70, 20, 0)}, forearm_R={'r': (-20, 0, 0)}, hand_R={'r': (100, 0, 0)}, spine={'r': (18, 0, -20)}, chest={'r': (0, 0, -15)},
           head={'r': (-14, 0, 10)}, hips={'s': (1.06, 1.06, 0.9)}, root={'l': (0, 0.04, -0.02)})
    k1 = M(SB, upperarm_R={'r': (-60, 20, 0)}, forearm_R={'r': (-10, 0, 0)}, hand_R={'r': (60, 0, 0)}, spine={'r': (0, 0, 15)}, chest={'r': (0, 0, 10)},
           head={'r': (-16, 0, -6)}, root={'l': (0, -0.08, 0.02)}, hips={'s': (0.96, 0.96, 1.1)})
    k2 = M(SB, upperarm_R={'r': (-150, 25, 0)}, forearm_R={'r': (-5, 0, 0)}, hand_R={'r': (10, 0, 0)}, spine={'r': (-10, 0, 25)}, chest={'r': (0, 0, 14)},
           head={'r': (-26, 0, -10)}, root={'l': (0, -0.2, 0.03)}, upperarm_L={'r': (40, -20, 0)})
    k3 = M(SB, upperarm_R={'r': (-110, 30, 0)}, forearm_R={'r': (-20, 0, 0)}, spine={'r': (24, 0, 10)}, head={'r': (-6, 0, 0)}, root={'l': (0, -0.32, -0.02)},
           thigh_R={'r': (-30, 0, 0)}, shin_R={'r': (20, 0, 0)}, hips={'s': (1.05, 1.05, 0.92)}, upperarm_L={'r': (30, -35, 0)})
    k4 = M(SB, upperarm_R={'r': (-30, 20, 0)}, root={'l': (0, -0.32, 0)}, head={'r': (-12, 0, 0)}, upperarm_L={'r': (0, -10, 0)})
    A['passa'] = seq([(0, SB, 'in'), (4, k0, ('snap', 1)), (9, k1, ('lin', 1)), (12, k2, ('out', 1)), (20, k3, ('io', 2)), (40, k4, 'lin')])
    # o sino devolvido bate na cabeça: achata, coroa entorta (osso 'coroa'), cambaleia
    b0 = M(SB, root={'l': (0, 0, -0.04)}, head={'r': (16, 0, -12)}, spine={'r': (10, 0, 0)}, hips={'s': (1.1, 1.1, 0.84)}, coroa={'r': (0, -22, 0)},
           upperarm_L={'r': (-60, -50, 0)}, upperarm_R={'r': (-20, 40, 0)})
    b1 = M(SB, root={'l': (-0.06, 0.12, 0)}, head={'r': (-8, 0, 8)}, spine={'r': (-8, 0, 6)}, coroa={'r': (0, -18, 0)}, thigh_L={'r': (20, 0, 0)})
    b2 = M(SB, root={'l': (-0.08, 0.16, 0)}, coroa={'r': (0, -16, 0)}, head={'r': (-6, 0, 0)}, upperarm_L={'r': (-130, -10, 0)}, forearm_L={'r': (-100, 0, 0)})
    A['bonk'] = seq([(0, SB, ('out', 1)), (3, b0, 'hold'), (9, b0, ('out', 2)), (22, b1, ('io', 2)), (44, b2, 'lin')])
    A['rest'] = seq([(0, {}, 'lin'), (2, {}, 'lin')])
    return A

# ================================================================== SAPADOR e BRUXA (estresse e folha)
SAB = M(BASE, spine={'r': (18, 0, 0)}, chest={'r': (8, 0, 0)}, head={'r': (-22, 0, 0)}, hand_R={'r': (60, 0, 0)}, upperarm_L={'r': (-30, -10, 0)},
        forearm_L={'r': (-70, 0, 0)}, thigh_L={'r': (-10, -6, 0)}, shin_L={'r': (14, 0, 0)}, thigh_R={'r': (8, 6, 0)}, shin_R={'r': (12, 0, 0)}, root={'l': (0, 0, -0.012)})
def sapador():
    A = {}
    A['idle'] = respira(SAB, 40, 0.035, cabeca=4.0)
    t0 = M(SAB, upperarm_L={'r': (60, -20, 0)}, spine={'r': (10, 0, -20)}, root={'l': (0, 0.05, -0.02)})
    t1 = M(SAB, upperarm_L={'r': (-150, -10, 0)}, forearm_L={'r': (-10, 0, 0)}, spine={'r': (0, 0, 20)}, root={'l': (0, -0.08, 0)})
    A['arremessa'] = seq([(0, SAB, 'in'), (3, t0, ('snap', 1)), (7, t1, ('out', 1)), (20, M(SAB, root={'l': (0, -0.08, 0)}), 'lin')])
    # corrida nervosa: inclinado, passo curto e rápido, a mochila quase o derruba (achatamento forte na baixa)
    A['corre'] = ciclo_corrida(M(SAB, spine={'r': (6, 0, 0)}), n=16, passo=34, braco=30, pulo=0.035, incl=10, peso=1.6)
    # olha para os lados (micropausa de 2 quadros entre as olhadas)
    A['olha'] = seq([(0, SAB, ('snap', 2)), (10, M(SAB, head={'r': (0, 0, 35)}, chest={'r': (0, 0, 8)}), ('hold', 2)), (24, M(SAB, head={'r': (0, 0, -35)}, chest={'r': (0, 0, -8)}), ('hold', 2)), (40, SAB, 'lin')])
    A['rest'] = seq([(0, {}, 'lin'), (2, {}, 'lin')])
    return A

BRB = M(BASE, hand_R={'r': (62, 0, 0)}, upperarm_R={'r': (-20, 20, 0)}, forearm_R={'r': (-50, 0, 0)}, upperarm_L={'r': (-10, -40, 0)},
        forearm_L={'r': (-80, 0, -30)}, spine={'r': (-6, 0, 0)}, head={'r': (-10, 6, 8)}, chest={'r': (0, 0, -6)}, thigh_L={'r': (-6, 0, 0)})
def bruxa():
    A = {}
    A['idle'] = respira(BRB, 80, 0.03, cabeca=2.0)
    # aponta para o céu: braço do cajado no alto, cabeça só um pouco para trás (o chapéu fica de pé e lê de cima)
    c0 = M(BRB, upperarm_R={'r': (-175, 10, 0)}, forearm_R={'r': (-5, 0, 0)}, upperarm_L={'r': (-60, -60, 0)}, spine={'r': (-3, 0, 6)},
           head={'r': (0, 0, -6)}, root={'l': (0, 0, 0.04)}, hips={'s': (0.96, 0.96, 1.1)}, chest={'s': (0.97, 0.97, 1.06)})
    A['conjura'] = seq([(0, BRB, 'in'), (4, M(BRB, spine={'r': (10, 0, 0)}, root={'l': (0, 0, -0.03)}), ('snap', 1)), (7, c0, 'hold'), (13, c0, ('io', 2)), (40, c0, 'lin')])
    # corrida teatral: casaco arrasta, chapéu chicoteia (molas), braço do cajado para trás
    A['corre'] = ciclo_corrida(M(BRB, upperarm_R={'r': (30, 0, 0)}), n=22, passo=30, braco=18, pulo=0.03, incl=8)
    # aponta para o céu (3 quadros), achata ao receber o contrato e volta esticando a 1,15
    c1 = M(c0, root={'l': (0, 0, -0.05)}, hips={'s': (1.1, 1.1, 0.8)}, chest={'s': (1.04, 1.04, 0.9)}, head={'r': (8, 0, 0)})
    c2 = M(c0, root={'l': (0, 0, 0.04)}, hips={'s': (0.95, 0.95, 1.1)}, chest={'s': (0.97, 0.97, 1.06)})
    A['contrato'] = seq([(0, BRB, 'in'), (5, M(BRB, spine={'r': (12, 0, 8)}, root={'l': (0, 0, -0.04)}), ('snap', 1)), (8, c0, ('hold', 1)), (30, c0, ('out', 1)),
                         (33, c1, ('out', 1)), (38, c2, ('io', 2)), (50, c0, ('io', 2)), (70, BRB, 'lin')])
    A['rest'] = seq([(0, {}, 'lin'), (2, {}, 'lin')])
    return A

# ================================================================== MILÍCIA
MB = M(BASE, hand_R={'r': (80, 0, 0)}, upperarm_R={'r': (-10, 10, 0)}, forearm_R={'r': (-40, 0, 0)})
def miliciano():
    A = {}
    A['idle'] = respira(MB, 50, 0.03, cabeca=3.0)
    A['corre'] = ciclo_corrida(M(MB, hand_R={'r': (60, 0, 0)}), n=20, passo=38, braco=20, pulo=0.03, incl=14)
    gr = M(MB, upperarm_L={'r': (-160, -20, 0)}, forearm_L={'r': (-20, 0, 0)}, head={'r': (-20, 0, 0)}, spine={'r': (-8, 0, 0)})
    A['grita'] = seq([(0, MB, ('out', 2)), (8, gr, ('lin', 2)), (16, M(gr, root={'l': (0, 0, 0.04)}), ('lin', 2)), (24, gr, 'lin')])
    A['rest'] = seq([(0, {}, 'lin'), (2, {}, 'lin')])
    return A

# ================================================================== MORTOS
QB = M(BASE, upperarm_R={'r': (-50, 10, 0)}, forearm_R={'r': (-60, 0, 0)}, upperarm_L={'r': (-40, -10, 0)}, forearm_L={'r': (-70, 0, 0)},
       spine={'r': (8, 0, 0)}, head={'r': (-8, 0, 0)}, pique={'r': (-82, 0, 0)})
def piqueiro():
    A = {}
    A['idle'] = respira(QB, 80, 0.015, cabeca=4.0)
    A['marcha'] = ciclo_corrida(QB, n=40, passo=18, braco=4, pulo=0.01, incl=6)
    # baixa os piques juntos em 36 quadros, com um estalo no fim (o motor desenha as faixas verdes no chão)
    meio = M(QB, pique={'r': (40, 0, 0)}, spine={'r': (-6, 0, 0)}, upperarm_R={'r': (-20, 0, 0)}, root={'l': (0, 0.03, 0)})
    baixo = M(QB, pique={'r': (80, 0, 0)}, spine={'r': (16, 0, 0)}, head={'r': (-14, 0, 0)}, upperarm_R={'r': (10, 0, 0)}, upperarm_L={'r': (10, 0, 0)},
              thigh_L={'r': (-30, 0, 0)}, shin_L={'r': (35, 0, 0)}, thigh_R={'r': (25, 0, 0)}, shin_R={'r': (20, 0, 0)}, root={'l': (0, -0.02, -0.04)})
    A['baixa'] = seq([(0, QB, ('io', 3)), (24, meio, ('in', 2)), (34, baixo, ('lin', 1)), (36, M(baixo, root={'l': (0, -0.03, 0)}), 'hold'), (48, baixo, 'lin')])
    # choque elétrico: poses quebradas que trocam a cada 3 quadros (o raio muda a cada 3 quadros)
    c1 = M(baixo, spine={'r': (-20, 10, 0)}, head={'r': (-30, 0, 15)}, upperarm_L={'r': (-90, -60, 0)}, upperarm_R={'r': (-80, 70, 0)}, pique={'r': (60, 0, 20)})
    c2 = M(baixo, spine={'r': (-10, -12, 0)}, head={'r': (-20, 0, -18)}, upperarm_L={'r': (-120, -40, 0)}, upperarm_R={'r': (-100, 40, 0)}, pique={'r': (90, 0, -20)}, root={'l': (0, 0, 0.03)})
    A['choque'] = seq([(0, c1, ('hold', 3)), (3, c2, ('hold', 3)), (6, c1, ('hold', 3)), (9, c2, ('hold', 3)), (12, c1, 'lin')])
    # derrubado pela investida: voa para trás e cai sentado na água
    v1 = M(QB, root={'l': (0, 0.5, 0.25), 'r': (-35, 0, 0)}, upperarm_L={'r': (-120, -30, 0)}, upperarm_R={'r': (-120, 30, 0)}, pique={'r': (-140, 0, 30)}, head={'r': (20, 0, 0)})
    v2 = M(QB, root={'l': (0, 0.9, -0.1), 'r': (-75, 0, 0)}, upperarm_L={'r': (-150, -40, 0)}, upperarm_R={'r': (-150, 40, 0)}, pique={'r': (-170, 0, 40)}, thigh_L={'r': (-70, 0, 0)}, thigh_R={'r': (-80, 0, 0)})
    A['cai'] = seq([(0, QB, ('out', 1)), (10, v1, ('in', 1)), (20, v2, 'hold'), (40, v2, 'lin')])
    A['rest'] = seq([(0, {}, 'lin'), (2, {}, 'lin')])
    return A

NB = M(BASE, spine={'r': (14, 0, 0)}, head={'r': (-14, 0, 0)}, upperarm_L={'r': (-20, -10, 0)}, forearm_L={'r': (-30, 0, 0)})
def penitente():
    A = {}
    A['idle'] = respira(NB, 70, 0.02, cabeca=5.0)
    A['anda'] = ciclo_corrida(NB, n=36, passo=20, braco=8, pulo=0.01, incl=10)
    # telegrafia: levanta a corrente acima da cabeça girando por 30 quadros
    keys = []
    for i in range(7):
        f = i * 5
        keys.append((f, M(NB, upperarm_L={'r': (-170, -10 + 25 * math.sin(i * 1.6), 0)}, forearm_L={'r': (-10, 0, 0)}, hand_L={'r': (0, 0, 60 * i)},
                          head={'r': (-24, 0, 0)}, spine={'r': (-4, 0, 0)}), ('lin', 1)))
    A['gira'] = seq(keys + [(36, keys[0][1], 'lin')])
    c1 = M(NB, spine={'r': (-20, 10, 0)}, head={'r': (-30, 0, 15)}, upperarm_L={'r': (-90, -60, 0)}, upperarm_R={'r': (-80, 70, 0)})
    c2 = M(NB, spine={'r': (-10, -12, 0)}, head={'r': (-20, 0, -18)}, upperarm_L={'r': (-120, -40, 0)}, upperarm_R={'r': (-100, 40, 0)}, root={'l': (0, 0, 0.03)})
    A['choque'] = seq([(0, c1, ('hold', 3)), (3, c2, ('hold', 3)), (6, c1, ('hold', 3)), (9, c2, ('hold', 3)), (12, c1, 'lin')])
    A['rest'] = seq([(0, {}, 'lin'), (2, {}, 'lin')])
    return A

CB = M(BASE, root={'l': (0, 0, 0.2)}, upperarm_L={'r': (-10, -10, 0)}, upperarm_R={'r': (-10, 10, 0)}, forearm_L={'r': (-30, 0, 0)}, forearm_R={'r': (-30, 0, 0)},
       spine={'r': (10, 0, 0)}, chest={'r': (8, 0, 0)}, head={'r': (12, 0, 6)})
def carpideira():
    A = {}
    A['flutua'] = seq([(0, CB, 'io'), (40, M(CB, root={'l': (0, 0, 0.06)}, head={'r': (-4, 0, -4)}), 'io'), (80, CB, 'lin')], 2)
    # inspira 48 quadros: o véu sobe (ossos do véu para trás), a boca abre (osso 'boca' cresce), o peito enche
    i1 = M(CB, root={'l': (0, 0.04, 0.3)}, spine={'r': (-14, 0, 0)}, chest={'r': (-10, 0, 0), 's': (1.15, 1.15, 1.2)}, head={'r': (-26, 0, 0)},
           upperarm_L={'r': (40, -50, 0)}, upperarm_R={'r': (40, 50, 0)}, forearm_L={'r': (-60, 0, 0)}, forearm_R={'r': (-60, 0, 0)}, boca={'s': (1.6, 1.0, 1.8)},
           veu_B={'r': (-40, 0, 0)}, veu_L={'r': (0, -30, 0)}, veu_R={'r': (0, 30, 0)})
    A['inspira'] = seq([(0, CB, ('in', 2)), (40, i1, ('lin', 2)), (48, M(i1, root={'l': (0, 0, 0.03)}), 'lin')])
    r1 = M(CB, root={'l': (0, 0.25, 0.15), 'r': (14, 0, 0)}, head={'r': (30, 0, -20)}, upperarm_L={'r': (-100, -30, 0)}, upperarm_R={'r': (-100, 30, 0)},
           forearm_L={'r': (-90, 0, 0)}, forearm_R={'r': (-90, 0, 0)}, boca={'s': (0.5, 1.0, 0.5)})
    A['recua'] = seq([(0, i1, ('out', 1)), (8, r1, ('io', 2)), (40, M(r1, root={'l': (0, 0.05, -0.05)}), 'lin')])
    A['rest'] = seq([(0, {}, 'lin'), (2, {}, 'lin')])
    return A

import math
def acoes(nome):
    f = {'porta': porta, 'sineira': sineira, 'sapador': sapador, 'bruxa': bruxa, 'miliciano': miliciano,
         'piqueiro': piqueiro, 'penitente': penitente, 'carpideira': carpideira}.get(nome)
    if f is None:
        return {'rest': seq([(0, {}, 'lin'), (2, {}, 'lin')])}
    return f()

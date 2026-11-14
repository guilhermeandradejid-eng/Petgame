"""hero_anim.py: animacoes do heroi, escritas pose a pose (ver anim.py para os canais).

30 qps. Nomes terminados em -loop viram loop no Godot. Os tipos de arma (sword, bow,
staff, hammer) tem cada um seu idle/run/air; as acoes sao de corpo inteiro.
"""
from anim import Clip

FPS = 30


def mirror(p):
    """Espelha uma pose (troca lados e inverte giros/tombos do tronco)."""
    out = {}
    for ch, v in p.items():
        if ch.endswith('.L'):
            nch = ch[:-2] + '.R'
        elif ch.endswith('.R'):
            nch = ch[:-2] + '.L'
        else:
            nch = ch
        base = ch.split('.')[0]
        if ch.endswith('.pos'):
            v = (-v[0], v[1], v[2])
        elif base in ('hips', 'spine', 'chest', 'head') and not ch.endswith('.scale') and not isinstance(v, (int, float)):
            v = (v[0], -v[1], -v[2])
        out[nch] = v
    return out


def K(frame, ease='io', **kw):
    return (frame, {k.replace('_', '.'): v for k, v in kw.items()}, ease)


def KP(frame, pose, ease='io'):
    return (frame, dict(pose), ease)


def merged(*dicts):
    out = {}
    for d in dicts:
        out.update(d)
    return out


# ------------------------------------------------------------------ poses base
BASE = {
    'hips': (0, 0, 0), 'hips.pos': (0, 0, 0), 'spine': (2, 0, 0), 'chest': (0, 0, 0), 'head': (0, 0, 0),
    'arm.L': (4, 14, 0), 'elbow.L': (24, 0, 0), 'hand.L': (0, 0, 0),
    'arm.R': (4, 14, 0), 'elbow.R': (24, 0, 0), 'hand.R': (0, 0, 0),
    'leg.L': (0, 5, 8), 'knee.L': 3, 'foot.L': 0,
    'leg.R': (0, 5, 8), 'knee.R': 3, 'foot.R': 0,
    'lift': 0,
}

# como cada tipo de arma e segurada parada
HOLD = {
    'sword': {'arm.R': (8, 18, 8), 'elbow.R': (40, 0, 0), 'hand.R': (0, 34, 0)},
    'bow': {'arm.L': (12, 16, 0), 'elbow.L': (46, 0, 0), 'hand.L': (0, -14, 0)},
    'staff': {'arm.R': (16, 16, 0), 'elbow.R': (66, 0, 0), 'hand.R': (0, -6, 0)},
    'hammer': {'arm.R': (6, 18, 6), 'elbow.R': (34, 0, 0), 'hand.R': (0, 44, 0),
               'arm.L': (34, 24, -24), 'elbow.L': (88, 0, 0)},
}
# braco que nao balanca na corrida (segura a arma firme) e quanto balanca
RUN_ARM = {
    'sword': {'R': 0.45, 'L': 1.0},
    'bow': {'R': 1.0, 'L': 0.35},
    'staff': {'R': 0.25, 'L': 1.0},
    'hammer': {'R': 0.45, 'L': 0.15},
}


def stance(wt):
    return merged(BASE, HOLD[wt])


# ------------------------------------------------------------------ locomocao
def idle(wt):
    b = stance(wt)

    def arm(side, d_abd, d_el):
        a = b['arm.' + side]
        e = b['elbow.' + side]
        return {'arm.' + side: (a[0], a[1] + d_abd, a[2]), 'elbow.' + side: (e[0] + d_el, 0, 0)}
    k = [
        KP(0, b),
        KP(30, merged({'chest': (3, 0, 0), 'spine': (3, 0, 0), 'head': (-3, 0, 0), 'knee.L': 8, 'knee.R': 8,
                       'leg.L': (4, 5, 8), 'leg.R': (4, 5, 8)}, arm('L', 3, 3), arm('R', 3, 3))),
    ]
    return Clip(wt + '_idle', 60, k, loop=True, base=b)


def run(wt):
    b = stance(wt)
    amp = RUN_ARM[wt]

    def arm(side, flex, elbow):
        """Mistura o balanco da corrida com a pose de segurar a arma."""
        a = amp[side]
        h = b['arm.' + side]
        he = b['elbow.' + side][0]
        return {'arm.' + side: (h[0] + (flex - h[0]) * a, h[1] + (10 - h[1]) * a * 0.5, h[2]),
                'elbow.' + side: (he + (elbow - he) * a, 0, 0)}
    half = [
        (0, merged({'hips': (12, -9, 0), 'chest': (8, 15, 0), 'head': (-12, -5, 0),
                    'leg.L': (44, 4, 4), 'knee.L': 14, 'foot.L': -14,
                    'leg.R': (-30, 4, 4), 'knee.R': 46, 'foot.R': 26, 'lift': 0.0},
                   arm('R', 55, 80), arm('L', -42, 58))),
        (2, merged({'hips': (15, -5, 0), 'chest': (9, 8, 0), 'head': (-14, -3, 0),
                    'leg.L': (24, 4, 4), 'knee.L': 42, 'foot.L': 0,
                    'leg.R': (-6, 4, 4), 'knee.R': 92, 'foot.R': 20, 'lift': 0.0},
                   arm('R', 30, 78), arm('L', -24, 62))),
        (4, merged({'hips': (13, 0, 0), 'chest': (8, 0, 0), 'head': (-12, 0, 0),
                    'leg.L': (2, 4, 4), 'knee.L': 18, 'foot.L': 4,
                    'leg.R': (40, 4, 4), 'knee.R': 86, 'foot.R': 10, 'lift': 0.0},
                   arm('R', 4, 70), arm('L', 8, 70))),
        (6, merged({'hips': (11, 5, 0), 'chest': (7, -9, 0), 'head': (-10, 3, 0),
                    'leg.L': (-24, 4, 4), 'knee.L': 22, 'foot.L': 32,
                    'leg.R': (56, 4, 4), 'knee.R': 52, 'foot.R': -6, 'lift': 0.055},
                   arm('R', -28, 60), arm('L', 40, 78))),
    ]
    keys = []
    for f, p in half:
        keys.append(KP(f, p, 'io'))
        keys.append(KP(f + 8, mirror_run(p, wt), 'io'))
    return Clip(wt + '_run', 16, keys, loop=True, base=b)


def mirror_run(p, wt):
    """Espelha pernas e tronco; os bracos sao recalculados (a arma nao troca de mao)."""
    m = mirror(p)
    b = stance(wt)
    amp = RUN_ARM[wt]
    out = dict(m)
    for side in ('L', 'R'):
        # desfaz a mistura para achar o balanco puro do lado oposto e refaz com o peso deste lado
        other = 'R' if side == 'L' else 'L'
        ao = amp[other]
        ho = b['arm.' + other]
        heo = b['elbow.' + other][0]
        src = p['arm.' + other]
        srce = p['elbow.' + other][0]
        if ao > 1e-6:
            flex = ho[0] + (src[0] - ho[0]) / ao
            elbow = heo + (srce - heo) / ao
        else:
            flex, elbow = ho[0], heo
        a = amp[side]
        h = b['arm.' + side]
        he = b['elbow.' + side][0]
        out['arm.' + side] = (h[0] + (flex - h[0]) * a, h[1] + (10 - h[1]) * a * 0.5, h[2])
        out['elbow.' + side] = (he + (elbow - he) * a, 0, 0)
    return out


def air(wt):
    b = stance(wt)
    h = HOLD[wt]
    p0 = merged(b, {'hips': (6, 0, 0), 'chest': (-4, 0, 0), 'head': (4, 0, 0),
                    'leg.L': (48, 8, 4), 'knee.L': 78, 'leg.R': (-6, 8, 4), 'knee.R': 44,
                    'foot.L': 20, 'foot.R': 30})
    if 'arm.L' not in h:
        p0.update({'arm.L': (30, 52, 0), 'elbow.L': (42, 0, 0)})
    if 'arm.R' not in h:
        p0.update({'arm.R': (30, 52, 0), 'elbow.R': (42, 0, 0)})
    p1 = dict(p0)
    p1.update({'leg.L': (42, 8, 4), 'knee.L': 70, 'leg.R': (-10, 8, 4), 'knee.R': 50, 'chest': (-6, 0, 0)})
    return Clip(wt + '_air', 20, [KP(0, p0), KP(10, p1)], loop=True, base=b, ground=False)


# ------------------------------------------------------------------ genericas
def land():
    b = dict(BASE)
    return Clip('land', 9, [
        KP(0, merged(b, {'hips': (14, 0, 0), 'chest': (10, 0, 0), 'head': (-6, 0, 0),
                         'leg.L': (48, 10, 10), 'knee.L': 82, 'leg.R': (48, 10, 10), 'knee.R': 82,
                         'arm.L': (-10, 40, 0), 'arm.R': (-10, 40, 0), 'hips.scale': (1.07, 1.07, 0.90)})),
        K(3, 'o', hips=(10, 0, 0), leg_L=(36, 10, 10), knee_L=62, leg_R=(36, 10, 10), knee_R=62,
          hips_scale=(1.0, 1.0, 1.0)),
        KP(9, merged(b, {'hips.scale': (1, 1, 1)})),
    ], base=b)


def dodge():
    b = dict(BASE)
    tuck = {'leg.L': (112, 8, 0), 'knee.L': 128, 'leg.R': (104, 8, 0), 'knee.R': 122,
            'arm.L': (58, 22, 0), 'elbow.L': 112, 'arm.R': (58, 22, 0), 'elbow.R': 112,
            'head': (28, 0, 0), 'chest': (22, 0, 0), 'spine': (16, 0, 0)}
    return Clip('dodge', 17, [
        KP(0, b),
        KP(2, merged(b, {'hips': (26, 0, 0), 'hips.pos': (0, 0.02, -0.11), 'chest': (16, 0, 0),
                         'leg.L': (62, 8, 8), 'knee.L': 88, 'leg.R': (62, 8, 8), 'knee.R': 88,
                         'arm.L': (-40, 26, 0), 'arm.R': (-40, 26, 0), 'hips.scale': (1.06, 1.06, 0.9)}), 'o'),
        KP(5, merged(tuck, {'hips': (95, 0, 0), 'hips.pos': (0, 0, 0.10), 'hips.scale': (0.96, 0.96, 1.06)}), 'io'),
        KP(8, merged(tuck, {'hips': (185, 0, 0), 'hips.pos': (0, 0, 0.42), 'hips.scale': (1, 1, 1)}), 'l'),
        KP(11, merged(tuck, {'hips': (285, 0, 0), 'hips.pos': (0, 0, 0.26)}), 'l'),
        KP(13, merged(b, {'hips': (350, 0, 0), 'hips.pos': (0, 0, -0.10), 'chest': (14, 0, 0),
                          'leg.L': (58, 10, 8), 'knee.L': 86, 'leg.R': (40, 10, 8), 'knee.R': 80,
                          'arm.L': (10, 44, 0), 'arm.R': (10, 44, 0), 'hips.scale': (1.07, 1.07, 0.9)}), 'l'),
        KP(17, merged(b, {'hips': (360, 0, 0), 'hips.scale': (1, 1, 1)}), 'o'),
    ], base=b, ground=False)


def hit():
    b = dict(BASE)
    return Clip('hit', 11, [
        KP(0, b),
        KP(2, merged(b, {'hips': (-10, 6, 0), 'chest': (-24, 12, 0), 'head': (-20, -8, 10),
                         'arm.L': (34, 56, 0), 'elbow.L': 50, 'arm.R': (20, 48, 0), 'elbow.R': 60,
                         'leg.L': (-12, 8, 8), 'knee.L': 26, 'leg.R': (14, 8, 8), 'knee.R': 22,
                         'hips.scale': (1.05, 1.05, 0.93)}), 'o'),
        KP(5, merged(b, {'hips': (-4, 2, 0), 'chest': (-8, 4, 0), 'head': (-4, 0, 2), 'hips.scale': (1, 1, 1)}), 'io'),
        KP(11, b),
    ], base=b)


LYING = {'hips': (-90, 0, 0), 'hips.pos': (0, -0.30, -0.275), 'spine': (-4, 0, 0), 'chest': (8, 0, 0),
         'head': (14, 0, 12), 'arm.L': (-6, 62, 0), 'elbow.L': 22, 'arm.R': (-4, 48, 0), 'elbow.R': 40,
         'leg.L': (10, 16, 10), 'knee.L': 10, 'leg.R': (4, 10, 10), 'knee.R': 26, 'foot.L': 20, 'foot.R': 24}


def down():
    b = dict(BASE)
    return Clip('down', 24, [
        KP(0, b),
        KP(4, merged(b, {'hips': (-22, 0, 0), 'hips.pos': (0, -0.05, 0.03), 'chest': (-22, 0, 0),
                         'head': (-24, 0, 0), 'arm.L': (62, 60, 0), 'arm.R': (56, 54, 0),
                         'leg.L': (30, 10, 8), 'knee.L': 40, 'leg.R': (12, 10, 8), 'knee.R': 30}), 'o'),
        KP(10, merged(b, {'hips': (-64, 0, 0), 'hips.pos': (0, -0.20, -0.10), 'chest': (-8, 0, 0),
                          'head': (-6, 0, 0), 'arm.L': (40, 70, 0), 'arm.R': (30, 64, 0),
                          'leg.L': (38, 12, 8), 'knee.L': 50, 'leg.R': (26, 10, 8), 'knee.R': 44}), 'i'),
        KP(14, LYING, 'i'),
        KP(17, merged(LYING, {'hips.pos': (0, -0.31, -0.23), 'chest': (2, 0, 0), 'leg.L': (22, 16, 10),
                              'arm.L': (10, 70, 0)}), 'o'),
        KP(24, LYING, 'io'),
    ], base=b, ground=False)


def down_loop():
    return Clip('down', 50, [
        KP(0, LYING),
        KP(25, merged(LYING, {'chest': (11, 0, 0), 'head': (12, 0, 12), 'arm.L': (-6, 64, 0)})),
    ], loop=True, base=LYING, ground=False)


def getup():
    b = dict(BASE)
    return Clip('getup', 22, [
        KP(0, LYING),
        KP(7, merged(LYING, {'hips': (-48, 0, 0), 'hips.pos': (0, -0.18, -0.20), 'chest': (20, 0, 0),
                             'head': (10, 0, 0), 'arm.L': (-30, 30, 0), 'elbow.L': 30, 'arm.R': (-30, 30, 0),
                             'elbow.R': 30, 'leg.L': (60, 12, 8), 'knee.L': 96, 'leg.R': (52, 12, 8),
                             'knee.R': 90}), 'io'),
        KP(13, merged(b, {'hips': (20, 0, 0), 'hips.pos': (0, -0.02, -0.13), 'chest': (16, 0, 0),
                          'leg.L': (64, 10, 8), 'knee.L': 100, 'leg.R': (56, 10, 8), 'knee.R': 92,
                          'arm.L': (20, 30, 0), 'arm.R': (20, 30, 0)}), 'io'),
        KP(18, merged(b, {'hips.pos': (0, 0, 0.02), 'chest': (-4, 0, 0), 'hips.scale': (0.97, 0.97, 1.05)}), 'o'),
        KP(22, merged(b, {'hips.scale': (1, 1, 1)})),
    ], base=LYING, ground=False)


# ------------------------------------------------------------------ espada
def sword_atk1(name='sword_atk1', wt='sword', extra=None):
    """Corte horizontal da direita para a esquerda. Acerto no quadro 6."""
    b = stance(wt)
    ex = extra or {}
    return Clip(name, 20, [
        KP(0, b),
        KP(3, merged({'hips': (0, -18, 0), 'chest': (-5, -40, 0), 'head': (2, 34, 0),
                      'arm.R': (-26, 76, 22), 'elbow.R': 74, 'hand.R': (0, -14, 0),
                      'arm.L': (30, 26, 0), 'elbow.L': 62,
                      'leg.L': (24, 6, 8), 'knee.L': 28, 'leg.R': (-12, 8, 22), 'knee.R': 22}, ex), 'o'),
        KP(6, merged({'hips': (7, 20, 0), 'chest': (11, 50, 0), 'head': (-5, -44, 0),
                      'arm.R': (78, 20, 0), 'elbow.R': 8, 'hand.R': (0, 72, 0),
                      'arm.L': (-32, 30, 0), 'elbow.L': 72,
                      'leg.L': (40, 6, 8), 'knee.L': 48, 'leg.R': (-30, 8, 16), 'knee.R': 12,
                      'hips.scale': (1.03, 1.03, 0.97)}, ex), 'i'),
        KP(8, merged({'chest': (12, 62, 0), 'arm.R': (86, -8, 0), 'elbow.R': 16, 'hand.R': (0, 60, 0)}, ex), 'o'),
        KP(12, merged({'hips': (5, 14, 0), 'chest': (8, 44, 0), 'head': (-3, -36, 0),
                       'arm.R': (70, 0, 0), 'elbow.R': 30, 'hips.scale': (1, 1, 1)}, ex), 'io'),
        KP(20, b),
    ], base=b)


def sword_atk2(name='sword_atk2', wt='sword', extra=None):
    """Corte de volta, da esquerda para a direita. Acerto no quadro 6."""
    b = stance(wt)
    ex = extra or {}
    return Clip(name, 20, [
        KP(0, b),
        KP(3, merged({'hips': (0, 16, 0), 'chest': (0, 44, 0), 'head': (0, -38, 0),
                      'arm.R': (72, -18, 30), 'elbow.R': 88, 'hand.R': (0, 6, 0),
                      'arm.L': (-12, 32, 0), 'elbow.L': 40,
                      'leg.R': (20, 6, 8), 'knee.R': 26, 'leg.L': (-8, 8, 18), 'knee.L': 18}, ex), 'o'),
        KP(6, merged({'hips': (5, -20, 0), 'chest': (7, -48, 0), 'head': (-3, 42, 0),
                      'arm.R': (52, 82, 0), 'elbow.R': 6, 'hand.R': (0, 72, 0),
                      'arm.L': (24, 40, 0), 'elbow.L': 66,
                      'leg.R': (38, 6, 8), 'knee.R': 46, 'leg.L': (-28, 8, 16), 'knee.L': 12,
                      'hips.scale': (1.03, 1.03, 0.97)}, ex), 'i'),
        KP(8, merged({'chest': (8, -60, 0), 'arm.R': (28, 92, 0), 'elbow.R': 12, 'hand.R': (0, 58, 0)}, ex), 'o'),
        KP(12, merged({'hips': (4, -14, 0), 'chest': (6, -42, 0), 'head': (-2, 34, 0),
                       'arm.R': (30, 80, 0), 'elbow.R': 30, 'hips.scale': (1, 1, 1)}, ex), 'io'),
        KP(20, b),
    ], base=b)


def sword_atk3(name='sword_atk3', wt='sword', extra=None, two_hand=True):
    """Salto com golpe de cima para baixo. Acerto no quadro 11."""
    b = stance(wt)
    ex = extra or {}
    lh_up = {'arm.L': (142, 20, 0), 'elbow.L': 72} if two_hand else {}
    lh_dn = {'arm.L': (44, 22, 0), 'elbow.L': 34} if two_hand else {}
    return Clip(name, 28, [
        KP(0, b),
        KP(4, merged({'hips': (10, 0, 0), 'spine': (-4, 0, 0), 'chest': (-12, 0, 0), 'head': (-6, 0, 0),
                      'arm.R': (150, 20, 0), 'elbow.R': 64, 'hand.R': (0, 0, 0),
                      'leg.L': (44, 8, 8), 'knee.L': 80, 'leg.R': (44, 8, 8), 'knee.R': 80,
                      'hips.scale': (1.06, 1.06, 0.92), 'lift': 0}, lh_up, ex), 'o'),
        KP(8, merged({'hips': (-6, 0, 0), 'chest': (-24, 0, 0), 'head': (-10, 0, 0),
                      'arm.R': (176, 10, 0), 'elbow.R': 42, 'hand.R': (0, -22, 0),
                      'leg.L': (30, 8, 8), 'knee.L': 70, 'leg.R': (8, 8, 8), 'knee.R': 52,
                      'hips.scale': (0.96, 0.96, 1.07), 'lift': 0.32}, lh_up, ex), 'o'),
        KP(11, merged({'hips': (20, 0, 0), 'chest': (40, 0, 0), 'head': (-28, 0, 0),
                       'arm.R': (56, 8, 0), 'elbow.R': 4, 'hand.R': (0, 82, 0),
                       'leg.L': (58, 10, 10), 'knee.L': 90, 'leg.R': (50, 10, 10), 'knee.R': 84,
                       'hips.scale': (1.08, 1.08, 0.88), 'lift': 0}, lh_dn, ex), 'i'),
        KP(16, merged({'hips': (18, 0, 0), 'chest': (36, 0, 0), 'hips.scale': (1.02, 1.02, 0.98),
                       'arm.R': (52, 8, 0)}, ex), 'o'),
        KP(28, merged(b, {'hips.scale': (1, 1, 1)})),
    ], base=b)


def thrust():
    """Investida com estocada. Acerto nos quadros 5-9."""
    b = stance('sword')
    return Clip('thrust', 20, [
        KP(0, b),
        KP(2, merged({'hips': (4, -20, 0), 'chest': (0, -42, 0), 'head': (0, 50, 0),
                      'arm.R': (-34, 30, 0), 'elbow.R': 104, 'hand.R': (0, 64, 0),
                      'arm.L': (60, 20, 0), 'elbow.L': 30,
                      'leg.L': (20, 6, 8), 'knee.L': 40, 'leg.R': (0, 8, 20), 'knee.R': 40}), 'o'),
        KP(5, merged({'hips': (16, 22, 0), 'chest': (12, 34, 0), 'head': (-14, -50, 0),
                      'arm.R': (90, 4, 0), 'elbow.R': 0, 'hand.R': (0, 86, 0),
                      'arm.L': (-54, 32, 0), 'elbow.L': 22,
                      'leg.L': (54, 5, 5), 'knee.L': 60, 'leg.R': (-42, 5, 10), 'knee.R': 6,
                      'hips.scale': (0.97, 0.97, 1.05)}), 'i'),
        KP(10, merged({'hips': (14, 20, 0), 'chest': (10, 30, 0), 'hips.scale': (1, 1, 1)}), 'o'),
        KP(20, b),
    ], base=b)


def spin():
    """Redemoinho (loop): gira com a arma estendida."""
    b = stance('sword')
    pose = merged(b, {'chest': (8, 0, -6), 'head': (-4, 0, 0),
                      'arm.R': (16, 86, 0), 'elbow.R': 4, 'hand.R': (0, 78, 0),
                      'arm.L': (10, 70, 0), 'elbow.L': 24,
                      'leg.L': (14, 10, 8), 'knee.L': 34, 'leg.R': (-6, 14, 8), 'knee.R': 26})
    return Clip('spin', 10, [
        KP(0, merged(pose, {'hips': (8, 0, 4)})),
        KP(5, merged(pose, {'hips': (8, 180, -4)}), 'l'),
        KP(10, merged(pose, {'hips': (8, 360, 4)}), 'l'),
    ], loop=True, base=b)


def slam():
    """Golpe no chao com as duas maos (martelo, magias de impacto). Acerto no quadro 12."""
    b = stance('sword')
    return Clip('slam', 28, [
        KP(0, b),
        KP(6, merged({'hips': (-4, 0, 0), 'spine': (-6, 0, 0), 'chest': (-20, 0, 0), 'head': (-8, 0, 0),
                      'arm.R': (168, 14, 0), 'elbow.R': 50, 'hand.R': (0, -16, 0),
                      'arm.L': (160, 16, 0), 'elbow.L': 60,
                      'leg.L': (16, 8, 8), 'knee.L': 30, 'leg.R': (-10, 8, 14), 'knee.R': 20,
                      'hips.scale': (0.96, 0.96, 1.07), 'lift': 0.06}), 'o'),
        KP(9, merged({'chest': (-24, 0, 0), 'arm.R': (174, 12, 0), 'lift': 0.10}), 'io'),
        KP(12, merged({'hips': (22, 0, 0), 'chest': (42, 0, 0), 'head': (-30, 0, 0),
                       'arm.R': (58, 8, 0), 'elbow.R': 4, 'hand.R': (0, 84, 0),
                       'arm.L': (46, 20, 0), 'elbow.L': 30,
                       'leg.L': (58, 10, 10), 'knee.L': 92, 'leg.R': (44, 10, 10), 'knee.R': 80,
                       'hips.scale': (1.09, 1.09, 0.87), 'lift': 0}), 'i'),
        KP(18, merged({'hips': (18, 0, 0), 'chest': (36, 0, 0), 'hips.scale': (1.02, 1.02, 0.98)}), 'o'),
        KP(28, merged(b, {'hips.scale': (1, 1, 1)})),
    ], base=b)


def bash():
    """Pancada de escudo (braco esquerdo). Acerto no quadro 5."""
    b = stance('hammer')
    return Clip('bash', 18, [
        KP(0, b),
        KP(2, merged({'hips': (0, 14, 0), 'chest': (-4, 30, 0), 'head': (0, -24, 0),
                      'arm.L': (-10, 40, -24), 'elbow.L': 110,
                      'leg.R': (18, 6, 8), 'knee.R': 30, 'leg.L': (-6, 8, 14), 'knee.L': 22}), 'o'),
        KP(5, merged({'hips': (12, -18, 0), 'chest': (12, -30, 0), 'head': (-8, 40, 0),
                      'arm.L': (84, 10, -30), 'elbow.L': 40,
                      'leg.L': (48, 6, 8), 'knee.L': 56, 'leg.R': (-36, 8, 12), 'knee.R': 8,
                      'hips.scale': (0.97, 0.97, 1.04)}), 'i'),
        KP(9, merged({'hips': (10, -14, 0), 'chest': (10, -24, 0), 'hips.scale': (1, 1, 1)}), 'o'),
        KP(18, b),
    ], base=b)


# ------------------------------------------------------------------ arco
DRAW = {'hips': (0, -34, 0), 'chest': (-2, -42, 0), 'head': (0, 72, 4),
        'arm.L': (8, 88, -90), 'elbow.L': 4, 'hand.L': (0, 0, 0),
        'arm.R': (14, 84, -80), 'elbow.R': 150, 'hand.R': (0, 0, 0),
        'leg.L': (16, 12, 30), 'knee.L': 14, 'leg.R': (-12, 12, 10), 'knee.R': 14}


def bow_shot():
    """Puxa e solta. Flecha sai no quadro 7."""
    b = stance('bow')
    return Clip('bow_shot', 17, [
        KP(0, b),
        KP(3, merged(DRAW, {'elbow.R': 110, 'arm.R': (14, 70, -80)}), 'o'),
        KP(6, merged(DRAW, {'chest': (-4, -46, 0)}), 'io'),
        KP(7, merged(DRAW, {'arm.R': (8, 100, -80), 'elbow.R': 96, 'arm.L': (10, 86, -74),
                            'chest': (0, -38, 0), 'hips.scale': (1.02, 1.02, 0.98)}), 'i'),
        KP(10, merged(DRAW, {'arm.R': (6, 104, -80), 'elbow.R': 70, 'arm.L': (8, 88, -90),
                             'hips.scale': (1, 1, 1)}), 'o'),
        KP(17, b),
    ], base=b)


def bow_charge():
    b = stance('bow')
    return Clip('bow_charge', 16, [
        KP(0, DRAW),
        KP(8, merged(DRAW, {'chest': (-5, -45, 0), 'elbow.R': 154, 'arm.L': (9, 88, -88)})),
    ], loop=True, base=b)


def bow_leap():
    """Salto para tras atirando. Flecha sai no quadro 9."""
    b = stance('bow')
    return Clip('bow_leap', 24, [
        KP(0, b),
        KP(3, merged(b, {'hips': (14, 0, 0), 'leg.L': (50, 8, 8), 'knee.L': 84, 'leg.R': (50, 8, 8), 'knee.R': 84,
                         'hips.scale': (1.06, 1.06, 0.92), 'lift': 0}), 'o'),
        KP(8, merged(DRAW, {'hips': (-16, -34, 0), 'leg.L': (40, 10, 10), 'knee.L': 60, 'leg.R': (10, 10, 10),
                            'knee.R': 70, 'lift': 0.42, 'hips.scale': (0.97, 0.97, 1.05)}), 'o'),
        KP(9, merged(DRAW, {'arm.R': (8, 100, -80), 'elbow.R': 96, 'lift': 0.42}), 'i'),
        KP(14, merged(DRAW, {'hips': (-6, -34, 0), 'arm.R': (6, 104, -80), 'elbow.R': 70, 'lift': 0.30,
                             'leg.L': (30, 10, 10), 'knee.L': 40, 'leg.R': (0, 10, 10), 'knee.R': 40}), 'io'),
        KP(18, merged(b, {'hips': (12, 0, 0), 'leg.L': (46, 10, 10), 'knee.L': 80, 'leg.R': (46, 10, 10),
                          'knee.R': 80, 'lift': 0, 'hips.scale': (1.07, 1.07, 0.9)}), 'i'),
        KP(24, merged(b, {'hips.scale': (1, 1, 1)})),
    ], base=b)


# ------------------------------------------------------------------ cajado
def staff_bolt():
    """Estocada curta com o cajado. Projetil sai no quadro 6."""
    b = stance('staff')
    return Clip('staff_bolt', 16, [
        KP(0, b),
        KP(3, merged({'hips': (0, -10, 0), 'chest': (-8, -26, 0), 'head': (0, 22, 0),
                      'arm.R': (-12, 30, 0), 'elbow.R': 100, 'hand.R': (0, -24, 0),
                      'arm.L': (36, 26, 0), 'elbow.L': 40,
                      'leg.L': (14, 6, 8), 'knee.L': 22, 'leg.R': (-8, 8, 16), 'knee.R': 18}), 'o'),
        KP(6, merged({'hips': (8, 12, 0), 'chest': (10, 24, 0), 'head': (-6, -20, 0),
                      'arm.R': (82, 10, 0), 'elbow.R': 10, 'hand.R': (0, 52, 0),
                      'arm.L': (-28, 28, 0), 'elbow.L': 30,
                      'leg.L': (36, 6, 8), 'knee.L': 44, 'leg.R': (-26, 8, 14), 'knee.R': 10,
                      'hips.scale': (0.98, 0.98, 1.04)}), 'i'),
        KP(9, merged({'arm.R': (76, 10, 0), 'elbow.R': 18, 'hand.R': (0, 40, 0), 'hips.scale': (1, 1, 1)}), 'o'),
        KP(16, b),
    ], base=b)


def staff_big():
    """Ergue o cajado e bate no chao. Magia sai no quadro 14."""
    b = stance('staff')
    return Clip('staff_big', 32, [
        KP(0, b),
        KP(7, merged({'spine': (-6, 0, 0), 'chest': (-14, 0, 0), 'head': (-16, 0, 0),
                      'arm.R': (150, 16, 0), 'elbow.R': 40, 'hand.R': (0, -10, 0),
                      'arm.L': (140, 26, 0), 'elbow.L': 58,
                      'leg.L': (6, 8, 8), 'knee.L': 10, 'leg.R': (6, 8, 8), 'knee.R': 10,
                      'foot.L': 26, 'foot.R': 26, 'lift': 0.05, 'hips.scale': (0.97, 0.97, 1.05)}), 'o'),
        KP(11, merged({'chest': (-18, 0, 0), 'arm.R': (158, 14, 0), 'lift': 0.08}), 'io'),
        KP(14, merged({'hips': (14, 0, 0), 'chest': (26, 0, 0), 'head': (-16, 0, 0),
                       'arm.R': (50, 14, 0), 'elbow.R': 56, 'hand.R': (0, -10, 0),
                       'arm.L': (64, 40, 0), 'elbow.L': 20,
                       'leg.L': (40, 10, 10), 'knee.L': 66, 'leg.R': (30, 10, 10), 'knee.R': 58,
                       'foot.L': 0, 'foot.R': 0, 'lift': 0, 'hips.scale': (1.07, 1.07, 0.9)}), 'i'),
        KP(21, merged({'hips': (10, 0, 0), 'chest': (20, 0, 0), 'hips.scale': (1.01, 1.01, 0.99)}), 'o'),
        KP(32, merged(b, {'hips.scale': (1, 1, 1)})),
    ], base=b)


def channel():
    b = stance('staff')
    p = merged(b, {'chest': (-4, 0, 0), 'head': (-6, 0, 0),
                   'arm.R': (64, 22, 0), 'elbow.R': 44, 'hand.R': (0, 14, 0),
                   'arm.L': (72, 34, 0), 'elbow.L': 30, 'hand.L': (40, 0, 0),
                   'leg.L': (10, 10, 12), 'knee.L': 18, 'leg.R': (-6, 10, 12), 'knee.R': 14})
    return Clip('channel', 30, [
        KP(0, p),
        KP(15, merged(p, {'chest': (-7, 4, 0), 'arm.R': (70, 24, 0), 'arm.L': (78, 38, 0), 'knee.L': 24,
                          'knee.R': 20})),
    ], loop=True, base=b)


def raise_():
    """Mao livre para o alto (cura, bencao, grito). Efeito no quadro 8."""
    b = dict(BASE)
    return Clip('raise', 24, [
        KP(0, b),
        KP(3, merged(b, {'hips': (8, 0, 0), 'chest': (8, 0, 0), 'arm.L': (-20, 30, 0), 'elbow.L': 60,
                         'knee.L': 30, 'knee.R': 30, 'leg.L': (16, 6, 8), 'leg.R': (16, 6, 8),
                         'hips.scale': (1.05, 1.05, 0.93)}), 'o'),
        KP(8, merged(b, {'chest': (-12, 0, 0), 'head': (-18, 0, 0), 'arm.L': (168, 16, 0), 'elbow.L': 8,
                         'hand.L': (30, 0, 0), 'foot.L': 28, 'foot.R': 28, 'lift': 0.05,
                         'hips.scale': (0.96, 0.96, 1.06)}), 'b'),
        KP(15, merged(b, {'chest': (-10, 0, 0), 'head': (-14, 0, 0), 'arm.L': (164, 18, 0), 'elbow.L': 12,
                          'foot.L': 20, 'foot.R': 20, 'lift': 0.03, 'hips.scale': (1, 1, 1)}), 'io'),
        KP(24, b),
    ], base=b)


def throw():
    """Arremesso com a mao esquerda. Solta no quadro 6."""
    b = dict(BASE)
    return Clip('throw', 16, [
        KP(0, b),
        KP(3, merged(b, {'hips': (0, 14, 0), 'chest': (-10, 34, 0), 'head': (0, -28, 0),
                         'arm.L': (150, 30, 0), 'elbow.L': 100,
                         'leg.R': (18, 6, 8), 'knee.R': 24}), 'o'),
        KP(6, merged(b, {'hips': (8, -14, 0), 'chest': (16, -30, 0), 'head': (-8, 28, 0),
                         'arm.L': (70, 14, 0), 'elbow.L': 6, 'hand.L': (-30, 0, 0),
                         'leg.L': (30, 6, 8), 'knee.L': 36, 'leg.R': (-22, 8, 12), 'knee.R': 10}), 'i'),
        KP(9, merged(b, {'chest': (18, -34, 0), 'arm.L': (40, 10, 0), 'elbow.L': 14}), 'o'),
        KP(16, b),
    ], base=b)


# ------------------------------------------------------------------ emotes
def wave():
    b = dict(BASE)
    up = {'arm.L': (20, 150, -90), 'chest': (0, 0, -5), 'head': (-4, 0, 8)}
    keys = [KP(0, b), KP(6, merged(b, up, {'elbow.L': 30}), 'o')]
    for i, e in enumerate((70, 20, 70, 20, 70, 30)):
        keys.append(KP(10 + i * 5, merged(b, up, {'elbow.L': e})))
    keys.append(KP(44, b))
    return Clip('wave', 44, keys, base=b)


def cheer():
    b = dict(BASE)
    crouch = merged(b, {'hips': (10, 0, 0), 'leg.L': (40, 8, 8), 'knee.L': 72, 'leg.R': (40, 8, 8), 'knee.R': 72,
                        'arm.L': (-20, 30, 0), 'arm.R': (-20, 30, 0), 'hips.scale': (1.07, 1.07, 0.9), 'lift': 0})
    jump = merged(b, {'chest': (-12, 0, 0), 'head': (-14, 0, 0), 'arm.L': (165, 30, 0), 'elbow.L': 10,
                      'arm.R': (165, 30, 0), 'elbow.R': 10, 'leg.L': (20, 16, 8), 'knee.L': 50,
                      'leg.R': (20, 16, 8), 'knee.R': 50, 'hips.scale': (0.95, 0.95, 1.08), 'lift': 0.30})
    return Clip('cheer', 40, [
        KP(0, b), KP(4, crouch, 'o'), KP(10, jump, 'o'), KP(16, crouch, 'i'),
        KP(22, jump, 'o'), KP(28, crouch, 'i'), KP(40, merged(b, {'hips.scale': (1, 1, 1)})),
    ], base=b)


def dance():
    b = dict(BASE)

    def beat(s):
        return merged(b, {'hips': (4, 10 * s, 9 * s), 'chest': (0, -14 * s, -8 * s), 'head': (0, 6 * s, 10 * s),
                          'arm.L': (60 if s > 0 else 10, 60 if s > 0 else 30, 0), 'elbow.L': 90 if s > 0 else 40,
                          'arm.R': (10 if s > 0 else 60, 30 if s > 0 else 60, 0), 'elbow.R': 40 if s > 0 else 90,
                          'leg.L': (14, 8, 10), 'knee.L': 36, 'leg.R': (14, 8, 10), 'knee.R': 36})

    def up(s):
        return merged(b, {'hips': (0, 4 * s, 4 * s), 'chest': (-4, -6 * s, -3 * s),
                          'arm.L': (40, 46, 0), 'elbow.L': 70, 'arm.R': (40, 46, 0), 'elbow.R': 70,
                          'knee.L': 8, 'knee.R': 8, 'lift': 0.03})
    return Clip('dance', 32, [
        KP(0, beat(1)), KP(4, up(1), 'o'), KP(8, beat(1), 'i'), KP(12, up(-1), 'o'),
        KP(16, beat(-1), 'i'), KP(20, up(-1), 'o'), KP(24, beat(-1), 'i'), KP(28, up(1), 'o'),
        KP(32, beat(1), 'i'),
    ], loop=True, base=b)


def sit():
    b = dict(BASE)
    p = merged(b, {'hips': (-8, 0, 0), 'hips.pos': (0, 0, -0.285), 'spine': (10, 0, 0), 'chest': (6, 0, 0),
                   'leg.L': (88, 34, 30), 'knee.L': 118, 'leg.R': (88, 34, 30), 'knee.R': 118,
                   'foot.L': 30, 'foot.R': 30,
                   'arm.L': (30, 18, 0), 'elbow.L': 50, 'arm.R': (30, 18, 0), 'elbow.R': 50})
    return Clip('sit', 50, [
        KP(0, p), KP(25, merged(p, {'chest': (9, 0, 0), 'head': (-3, 0, 4)})),
    ], loop=True, base=b, ground=False)


def build_clips():
    clips = []
    for wt in ('sword', 'bow', 'staff', 'hammer'):
        clips += [idle(wt), run(wt), air(wt)]
    clips += [land(), dodge(), hit(), down(), down_loop(), getup()]
    clips += [sword_atk1(), sword_atk2(), sword_atk3(), thrust(), spin(), slam()]
    shield = {'arm.L': (40, 26, -24), 'elbow.L': 92}
    clips += [sword_atk1('hammer_atk1', 'hammer', shield), sword_atk2('hammer_atk2', 'hammer', shield),
              sword_atk3('hammer_atk3', 'hammer', shield, two_hand=False), bash()]
    clips += [bow_shot(), bow_charge(), bow_leap()]
    clips += [staff_bolt(), staff_big(), channel()]
    clips += [raise_(), throw()]
    clips += [wave(), cheer(), dance(), sit()]
    return clips

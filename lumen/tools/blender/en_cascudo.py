"""en_cascudo.py: Cascudo, o besouro-rinoceronte blindado (~1 m de altura, 1,5 m de comprimento)."""
import math

from mathutils import Vector

import lp
import en_base as eb
from en_base import B, C, clip, mg, sym, wave

ID = 'cascudo'
NAME = 'Cascudo'
RADIUS = 0.55
HEIGHT = 1.00

SC = Vector((0, 0.18, 0.50))          # centro das asas-casca
SR = Vector((0.43, 0.53, 0.40))
HINGE = Vector((0.05, -0.20, 0.82))
LEGS = {   # quadril, joelho, pe (lado esquerdo)
    'F': (Vector((0.22, -0.32, 0.30)), Vector((0.40, -0.44, 0.27)), Vector((0.44, -0.52, 0.0))),
    'M': (Vector((0.30, 0.04, 0.30)), Vector((0.51, 0.02, 0.28)), Vector((0.57, 0.03, 0.0))),
    'R': (Vector((0.27, 0.38, 0.30)), Vector((0.44, 0.50, 0.27)), Vector((0.49, 0.62, 0.0))),
}
BONES = [
    B('root', None, (0, 0, 0)),
    B('body', 'root', (0, 0.15, 0.45), 0.2),
    B('thorax', 'body', (0, -0.10, 0.45), 0.2),
    B('skull', 'thorax', (0, -0.44, 0.36), 0.15),
]
for s in (1, -1):
    sf = '.L' if s > 0 else '.R'
    BONES += [B('shell' + sf, 'body', (HINGE.x * s, HINGE.y, HINGE.z)),
              B('feeler' + sf, 'skull', (0.10 * s, -0.64, 0.42), 0.06)]
    for k, (hp, kn, ft) in LEGS.items():
        par = 'thorax' if k == 'F' else 'body'
        BONES += [B('leg' + k + sf, par, (hp.x * s, hp.y, hp.z), 0.08), B('tip' + k + sf, 'leg' + k + sf, (kn.x * s, kn.y, kn.z), 0.08)]

TEAL = C('#178a8c')
TEAL_HI = C('#46dcb4')
TEAL_LO = C('#1c3f74')
NAVY = C('#2a2f6e')
INNER = C('#ff8a3c')
UNDER = C('#3a2757')
OCHRE = C('#e9b25a')
IVORY = C('#fbe6ad')
HORN_TIP = C('#70384a')
LEGC = C('#3b2c62')


def shell_z(x, y):
    k = 1.0 - (x / SR.x) ** 2 - ((y - SC.y) / SR.y) ** 2
    z = SC.z + SR.z * math.sqrt(max(0.0, k))
    n = Vector((x / SR.x ** 2, (y - SC.y) / SR.y ** 2, (z - SC.z) / SR.z ** 2)).normalized()
    return Vector((x, y, z)), n


def model():
    g = lp.Geo()
    # ---- abdome por baixo
    ab = lp.ellipsoid(0.37, 0.50, 0.27, n=10, rings=6, center=(0, 0.18, 0.41))
    eb.paint(ab, 0.14, 0.5, eb.cool(UNDER, 0.8), C('#5a3a78'))
    g.add(ab.bind('body'))
    # ---- asas-casca (uma metade, com forro laranja por dentro)
    sh = lp.ellipsoid(SR.x, SR.y, SR.z, n=14, rings=8, center=tuple(SC), phase=0.5)
    sh.keep_faces(lambda c: c.z > 0.34 and c.x > 0.0)
    sh.warp(lambda p: Vector((max(p.x, 0.012), p.y, p.z)))

    def shell_col(p, c):
        t = (p.z - 0.34) / 0.56
        base = eb.mixc(TEAL_LO, TEAL, min(1.0, t * 1.6))
        band = math.exp(-((p.z - 0.74) / 0.07) ** 2) * (0.6 + 0.4 * math.sin((p.y - 0.1) * 3.0))
        base = eb.mixc(base, TEAL_HI, 0.75 * band)
        seam = math.exp(-(p.x / 0.045) ** 2)
        return eb.mixc(base, TEAL_LO, 0.6 * seam)
    sh.tint(shell_col)
    inner = sh.copy().flip()
    inner.warp(lambda p: SC + (p - SC) * 0.955)
    inner.warp(lambda p: Vector((max(p.x, 0.035), p.y, p.z)))
    inner.color(INNER)
    eb.paint(inner, 0.34, 0.9, C('#c9452f'), INNER)
    sh.add(inner)
    # brilho pintado e pintas de lumen
    def streak(x0, y0, y1, w, off=0.006, col=C('#c9fff0')):
        top, bot = [], []
        for i in range(6):
            t = i / 5.0
            y = y0 + (y1 - y0) * t
            x = x0 + 0.05 * math.sin(t * math.pi)
            ww = w * (0.35 + 0.65 * math.sin(t * math.pi))
            pa, na = shell_z(x - ww, y)
            pb, nb = shell_z(x + ww, y)
            top.append(pa + na * off)
            bot.append(pb + nb * off)
        return lp.sheet([bot, top]).color(col)
    sh.add(streak(0.19, -0.10, 0.34, 0.030))
    sh.add(streak(0.30, 0.02, 0.16, 0.016))
    for x, y, r in [(0.27, 0.42, 0.040), (0.17, 0.56, 0.032), (0.33, 0.22, 0.026)]:
        p, n = shell_z(x, y)
        dot = lp.ellipsoid(r, r, 0.014, n=6, rings=3, mat='glow')
        dot.keep_faces(lambda c: c.z > -0.003)
        dot.color(eb.GLOW_HI)
        eb.aim(dot, n, p - n * 0.003)
        sh.add(dot)
    sh.bind('shell.L')
    g.add(sh)
    g.add(sh.mirrored())
    # ---- pronoto (escudo do torax) com chifrinho
    pr = lp.ellipsoid(0.37, 0.28, 0.33, n=12, rings=7, center=(0, -0.27, 0.46))
    pr.warp(lambda p: Vector((p.x, p.y - 0.05 * max(0.0, 1 - abs(p.x) / 0.37) * max(0.0, (p.z - 0.5) / 0.3), p.z)))
    eb.paint3(pr, [(0.14, eb.cool(NAVY, 0.7)), (0.40, NAVY), (0.66, C('#2f6fa8')), (0.80, C('#59c9d6'))])
    eb.under_shade(pr, 0.7)
    g.add(pr.bind('thorax'))
    th = lp.tube([(0, -0.40, 0.68), (0, -0.50, 0.76), (0, -0.56, 0.86)], [(0.060, 0.050), (0.042, 0.036), (0.008, 0.008)], n=6)
    eb.paint(th, 0.68, 0.86, OCHRE, HORN_TIP)
    g.add(th.bind('thorax'))
    # ---- cabeca + chifre bifurcado
    hd = lp.ellipsoid(0.205, 0.19, 0.165, n=10, rings=6, center=(0, -0.53, 0.33))
    eb.paint(hd, 0.17, 0.5, eb.cool(OCHRE, 0.7), OCHRE)
    eb.under_shade(hd, 0.8)
    horn = lp.tube([(0, -0.60, 0.36), (0, -0.75, 0.42), (0, -0.85, 0.56), (0, -0.87, 0.74), (0, -0.85, 0.82)],
                   [(0.105, 0.075), (0.090, 0.062), (0.072, 0.052), (0.066, 0.046), (0.070, 0.044)], n=8, cap_b=True)
    hd.add(horn)
    for s in (1, -1):
        pr2 = lp.tube([(0.02 * s, -0.86, 0.79), (0.10 * s, -0.83, 0.90), (0.15 * s, -0.76, 0.98), (0.16 * s, -0.69, 1.0)],
                      [(0.046, 0.040), (0.038, 0.034), (0.024, 0.022), (0.004, 0.004)], n=6)
        hd.add(pr2)
    eb.paint3(horn, [], 'z') if False else None
    def horn_col(p, c):
        if p.y > -0.60 and p.z < 0.5:
            return c
        t = max(0.0, min(1.0, (p.z - 0.38) / 0.60))
        return eb.mixc(eb.mixc(OCHRE, IVORY, min(1.0, t * 2.2)), HORN_TIP, max(0.0, t - 0.62) * 2.4)
    hd.tint(horn_col)
    for s in (1, -1):
        p = Vector((0.135 * s, -0.655, 0.355))
        n = Vector((0.62 * s, -0.75, 0.22)).normalized()
        hd.add(eb.brow_eye(p + n * 0.012, n, s, 0.050, 0.056, 0.026, cut=(0.35, 0.40), brow=(0.13, 0.042, NAVY, 20),
                           eye_bone='skull', face_bone='skull').bind('skull'))
    hd.bind('skull')
    g.add(hd)
    # ---- antenas
    fe = lp.tube([(0.10, -0.64, 0.42), (0.19, -0.72, 0.50), (0.27, -0.77, 0.52)], [0.016, 0.013, 0.012], n=4)
    fe.color(LEGC)
    club = lp.ellipsoid(0.034, 0.034, 0.034, n=6, rings=4, center=(0.285, -0.78, 0.52)).color(OCHRE)
    fe.add(club)
    fe.bind('feeler.L')
    g.add(fe)
    g.add(fe.mirrored())
    # ---- pernas
    for k, (hp, kn, ft) in LEGS.items():
        leg = lp.Geo()
        up = lp.tube([hp - (kn - hp) * 0.3, hp, kn], [0.070, 0.092, 0.084], n=7)
        lo = lp.tube([kn, (kn + ft) / 2 + Vector((0.015, 0, 0)), ft + Vector((0, 0, 0.03))], [0.086, 0.072, 0.060], n=7)
        cl = lp.ellipsoid(0.085, 0.105, 0.050, n=7, rings=4, center=(ft.x, ft.y - 0.02, 0.046))
        cl.warp(lambda p: Vector((p.x, p.y, max(p.z, 0.004))))
        leg.add(up).add(lo).add(cl)
        eb.paint(leg, 0.0, 0.42, eb.cool(LEGC, 0.8), C('#5a4a94'))
        knee = lp.ellipsoid(0.094, 0.094, 0.090, n=7, rings=4, center=tuple(kn)).color(C('#2c8a9a'))
        leg.add(knee)
        eb.bind_chain(leg, [hp, kn, ft], ['leg' + k + '.L', 'tip' + k + '.L'], blend=0.2)
        g.add(leg)
        g.add(leg.mirrored())
    lp.bake_ao(g, strength=0.5, dist=0.4, samples=18, floor_z=0.0)
    return g


# ---------------------------------------------------------------- animacao
FEET = {}
for _k, (_h, _n, _f) in LEGS.items():
    FEET['pad%s.L.ik' % _k] = eb.lfu(_f)
FEET = sym(FEET)
REST = mg(FEET, sym({'shell.L': (0, 0, 0), 'feeler.L': (0, 0, 0)}),
          {'body': (0, 0, 0), 'body.pos': (0, 0, 0), 'body.scale': (1, 1, 1), 'thorax': (0, 0, 0), 'skull': (0, 0, 0)})
FLARE = (16, -22, -26)
CH = mg(REST, {'body': (8, 0, 0), 'body.pos': (0, 0, -0.04), 'thorax': (8, 0, 0), 'skull': (22, 0, 0)},
        sym({'shell.L': (8, -8, -10)}))
SOLID = ('body', 'thorax', 'skull', 'shell.L', 'shell.R')


def feet(dy=0.0, dz=0.0, dx=0.0, only=None):
    out = {}
    for ch, v in FEET.items():
        if only and ch[3] not in only:
            continue
        sx = 1 if '.L' in ch else -1
        out[ch] = (v[0] + dx * sx, v[1] + dy, v[2] + dz)
    return out


def fin(c, sk, space='world', settle=5, g=None):
    if g is not None:
        eb.floor_fit(c, sk, g, mode='up', bones=SOLID)
    for sf in ('.L', '.R'):
        s = 1 if sf == '.L' else -1
        for k, (hp, kn, ft) in LEGS.items():
            eb.ik_bake(c, sk, 'leg' + k + sf, 'tip' + k + sf, 'pad' + k + sf, space=space,
                       end_point=(ft.x * s, ft.y, ft.z))
        eb.spring(c, sk, 'feeler' + sf, (0.285 * s, -0.78, 0.52), k=420, c=9, limit=45, settle=settle)
    return c


def ck(name, length, keys, loop=False, base=REST):
    return clip(name, length, [(0, base)] + list(keys), loop=loop, base=base)


def idle(sk, g):
    c = ck('idle', 40, [
        (10, {'body.pos': (0, 0, -0.02), 'thorax': (3, 0, 0), 'skull': (6, 0, 0)}),
        (20, {'body.pos': (0, 0, 0.012), 'thorax': (-2, 0, 0), 'skull': (-4, 0, 3)}),
        (30, {'body.pos': (0, 0, -0.015), 'thorax': (2, 0, 0), 'skull': (4, 0, -3)}),
        (26, sym({'shell.L': (0, 0, 0)})), (29, sym({'shell.L': (8, -10, -12)}), 'o'), (33, sym({'shell.L': (0, 0, 0)}), 'i'),
        (12, sym({'feeler.L': (0, 0, 0)})), (15, {'feeler.L': (0, 0, 22), 'feeler.R': (-14, 0, 0)}, 'o'),
        (19, sym({'feeler.L': (0, 0, 0)})),
    ], loop=True)
    return fin(c, sk, g=g)


def _gait(c, stride, lift, phases, duty=0.5):
    for ch, v in FEET.items():
        eb.gait(c, ch, v, phases[ch[3] + ch[5]], stride=stride, lift=lift, duty=duty, side=1 if '.L' in ch else -1)
    return c


def move(sk, g):
    c = ck('move', 16, [], loop=True)
    _gait(c, 0.34, 0.09, {'FL': 0.0, 'MR': 0.05, 'RL': 0.1, 'FR': 0.5, 'ML': 0.55, 'RR': 0.6})
    eb.add_fn(c, 'body', lambda f: (wave(f, 8, 1.5), wave(f, 16, 3.5), wave(f, 16, 3.0, 0.25)))
    eb.add_fn(c, 'body.pos', lambda f: (0, 0, wave(f, 8, 0.015)))
    eb.add_fn(c, 'skull', lambda f: (wave(f, 8, 4.0, 0.3), 0, wave(f, 16, -4.0, 0.25)))
    return fin(c, sk, g=g)


def charge_start(sk, g):
    """Cava o chao com a pata da frente, abaixa o chifre e abre as cascas. Termina na pose de investida."""
    fl = FEET['padF.L.ik']

    def paw(dy, dz):
        return {'padF.L.ik': (fl[0] - 0.04, fl[1] + dy, fl[2] + dz)}
    c = ck('charge_start', 18, [
        (2, mg({'body': (-4, 0, -3), 'body.pos': (0, -0.05, 0.02), 'skull': (-10, 0, 0)}, paw(0.14, 0.16)), 'o'),
        (5, mg(paw(-0.16, 0.0), {'body': (6, 0, 0), 'skull': (14, 0, 0)}), 'i'),
        (8, mg(paw(0.14, 0.15), {'body.pos': (0, -0.09, 0.0), 'body': (4, 0, -3)}), 'o'),
        (11, mg(paw(-0.18, 0.0), {'body': (9, 0, 0), 'thorax': (8, 0, 0), 'skull': (26, 0, 0)},
                sym({'shell.L': FLARE})), 'i'),
        (14, mg(paw(0.0, 0.0), {'body.pos': (0, -0.13, -0.06), 'body': (11, 0, 0), 'body.scale': (1.04, 0.94, 1.0)})),
        (18, mg(CH, {'body.scale': (1, 1, 1)}), 'i'),
    ])
    eb.shake(c, 'shell.L', 10, 17, (0, 5, 4), freq=1.6, seed=1)
    eb.shake(c, 'shell.R', 10, 17, (0, 5, 4), freq=1.6, seed=2)
    return fin(c, sk, g=g)


def charge_loop(sk, g):
    c = ck('charge', 10, [], loop=True, base=CH)
    _gait(c, 0.52, 0.13, {'FL': 0.0, 'FR': 0.12, 'ML': 0.38, 'MR': 0.5, 'RL': 0.7, 'RR': 0.82}, duty=0.42)
    eb.add_fn(c, 'body', lambda f: (wave(f, 10, 5.0), 0, 0))
    eb.add_fn(c, 'body.pos', lambda f: (0, 0, wave(f, 10, 0.04, 0.2)))
    eb.add_fn(c, 'skull', lambda f: (wave(f, 10, -5.0, 0.1), 0, 0))
    eb.add_fn(c, 'shell.L', lambda f: (0, wave(f, 5, 5.0), wave(f, 5, 4.0)))
    eb.add_fn(c, 'shell.R', lambda f: (0, wave(f, 5, 5.0, 0.5), wave(f, 5, 4.0, 0.5)))
    return fin(c, sk, g=g)


def charge_end(sk, g):
    """Freia derrapando: empina, abre as cascas como freio e assenta."""
    c = ck('charge_end', 16, [
        (3, mg({'body': (-15, 0, 4), 'body.pos': (0, 0.12, 0.03), 'thorax': (-8, 0, 0), 'skull': (-14, 0, 0),
                'body.scale': (1.0, 0.93, 1.05)}, sym({'shell.L': (26, -30, -36)}), feet(dy=0.13, only='F'),
               feet(dy=0.08, only='M')), 'o'),
        (7, {'body': (-9, 0, -3), 'body.pos': (0, 0.16, 0.0)}),
        (11, mg({'body': (6, 0, 0), 'body.pos': (0, 0.04, -0.04), 'thorax': (3, 0, 0), 'skull': (8, 0, 0),
                 'body.scale': (1.03, 1.03, 0.95)}, sym({'shell.L': (0, 0, 0)}), feet()), 'io'),
        (16, REST),
    ], base=CH)
    return fin(c, sk, g=g)


def attack(sk, g):
    """Abaixa o chifre rente ao chao (0,35 s) e da uma chifrada para cima. Acerto no quadro 13."""
    c = ck('attack', 28, [
        (3, {'body.pos': (0, 0.02, 0.02), 'skull': (-8, 0, 0)}, 'o'),
        (9, mg({'body': (7, 0, 0), 'body.pos': (0, -0.10, -0.05), 'thorax': (7, 0, 0), 'skull': (26, 0, 0),
                'body.scale': (1.04, 0.95, 0.97)}, sym({'shell.L': (8, -8, -10)})), 'o'),
        (11, {'body.pos': (0, -0.12, -0.06), 'skull': (29, 0, 0)}),
        (13, mg({'body': (-17, 0, 0), 'body.pos': (0, 0.20, 0.07), 'thorax': (-22, 0, 0), 'skull': (-40, 0, 0),
                 'body.scale': (0.97, 1.06, 1.02)}, feet(dy=0.10, dz=0.20, only='F')), 'i'),
        (15, mg({'body': (-20, 0, 0), 'thorax': (-25, 0, 0), 'skull': (-50, 0, 0)}, feet(dy=0.12, dz=0.24, only='F')), 'o'),
        (20, mg({'body': (5, 0, 0), 'body.pos': (0, 0.05, -0.04), 'thorax': (4, 0, 0), 'skull': (-6, 0, 0),
                 'body.scale': (1.03, 1.0, 0.96)}, sym({'shell.L': (0, 0, 0)}), feet()), 'i'),
        (28, REST),
    ])
    eb.shake(c, 'skull', 8, 12, (0, 0, 3), freq=1.2)
    return fin(c, sk, g=g)


def hit(sk, g):
    c = ck('hit', 9, [
        (2, mg({'body': (-11, 0, 9), 'body.pos': (0, -0.11, 0.03), 'thorax': (-6, 0, 0), 'skull': (-22, 0, 8),
                'body.scale': (1.06, 0.96, 0.94)}, sym({'shell.L': (14, -20, -22)})), 'o'),
        (5, mg({'body': (4, 0, -3), 'body.pos': (0, -0.03, -0.02), 'skull': (8, 0, 0), 'body.scale': (0.98, 1.0, 1.03)},
               sym({'shell.L': (2, -3, -3)}))),
        (9, REST),
    ])
    return fin(c, sk, g=g, settle=3)


def die(sk, g):
    """E arremessado, vira de barriga para cima, esperneia e encolhe as pernas."""
    def curl(k):
        out = {}
        for ch, v in FEET.items():
            sx = 1 if '.L' in ch else -1
            out[ch] = (v[0] + (0.22 * sx - v[0]) * k, v[1] * (1 - 0.35 * k), v[2] + 0.10 * k)
        return out

    def kick(a):
        out = {}
        for i, (ch, v) in enumerate(sorted(FEET.items())):
            s = a if i % 2 == 0 else -a
            out[ch] = (v[0] * 0.8, v[1] + 0.10 * s, v[2] + 0.04)
        return out
    c = ck('die', 42, [
        (2, mg({'body': (-12, 0, 8), 'body.pos': (0, -0.10, 0.06), 'skull': (-24, 0, 0), 'body.scale': (1.06, 0.96, 0.94)},
               sym({'shell.L': (14, -20, -22)})), 'o'),
        (9, {'body': (-6, 100, 20), 'body.pos': (0, -0.20, 0.62), 'body.scale': (1, 1, 1)}, 'o'),
        (15, mg({'body': (4, 186, 26), 'body.pos': (0, -0.28, 0.02), 'body.scale': (1.08, 1.04, 0.86), 'skull': (-20, 0, 0)},
                sym({'shell.L': (6, -30, -16)}), kick(1)), 'i'),
        (19, mg({'body': (-3, 174, 28), 'body.pos': (0, -0.28, 0.12), 'body.scale': (1, 1, 1)}, kick(-1)), 'o'),
        (23, mg({'body': (2, 183, 30), 'body.pos': (0, -0.28, 0.02)}, kick(1)), 'i'),
        (27, mg({'body': (0, 178, 30)}, kick(-0.8))),
        (31, mg({'body': (0, 181, 30)}, kick(0.5), sym({'shell.L': (4, -22, -12)}))),
        (36, mg(curl(0.7), {'skull': (-34, 0, 6)})),
        (42, mg({'body': (0, 180, 30)}, curl(1.0))),
    ])
    eb.floor_fit(c, sk, g, mode='up', bones=SOLID)
    eb.floor_fit(c, sk, g, mode='fit', f0=15, f1=15, bones=SOLID)
    eb.floor_fit(c, sk, g, mode='fit', f0=23, bones=SOLID, blend=2)
    return fin(c, sk, space='parent', settle=0)


def spawn(sk, g):
    """Cava de baixo para cima: o chifre fura o chao primeiro e o corpo sai num tranco."""
    tuck = {}
    for ch, v in FEET.items():
        tuck[ch] = (v[0] * 0.7, v[1], v[2] + 0.16)
    c = ck('spawn', 32, [
        (0, mg({'body': (-56, 0, 0), 'body.pos': (0, -0.20, -1.15), 'skull': (-10, 0, 0)}, tuck)),
        (7, {'body.pos': (0, -0.20, -0.72), 'skull': (14, 0, 10)}, 'o'),
        (10, {'skull': (-12, 0, -10)}),
        (13, {'body.pos': (0, -0.20, -0.80), 'skull': (6, 0, 0), 'body': (-52, 0, 0)}),
        (19, mg({'body': (-16, 0, 0), 'body.pos': (0, 0, 0.16), 'skull': (-16, 0, 0), 'body.scale': (0.96, 1.08, 1.0)},
                sym({'shell.L': FLARE}), {k: (v[0] * 1.1, v[1], v[2] - 0.06) for k, v in FEET.items()}), 'o'),
        (23, mg({'body': (6, 0, 0), 'body.pos': (0, 0, -0.06), 'skull': (10, 0, 0), 'body.scale': (1.05, 1.0, 0.92)}, FEET), 'i'),
        (27, mg({'body': (-2, 0, 0), 'body.pos': (0, 0, 0.01), 'body.scale': (1, 1, 1)}, sym({'shell.L': (0, 0, 0)}))),
        (32, REST),
    ])
    eb.shake(c, 'shell.L', 18, 27, (0, 6, 5), freq=1.6, seed=1, grow=False)
    eb.shake(c, 'shell.R', 18, 27, (0, 6, 5), freq=1.6, seed=2, grow=False)
    return fin(c, sk, space='parent')


def clips(sk, g):
    return [(idle(sk, g), None), (move(sk, g), None), (charge_start(sk, g), 18), (charge_loop(sk, g), 0),
            (charge_end(sk, g), None), (attack(sk, g), 13), (hit(sk, g), None), (die(sk, g), None), (spawn(sk, g), None)]

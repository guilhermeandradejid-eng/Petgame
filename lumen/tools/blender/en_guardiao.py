"""en_guardiao.py: Guardiao Cristalino, o colosso tomado por cristais de lumen (chefe, 3,4 m).

Usa o mesmo esqueleto dos golens (en_golem), maior e mais lento, com um braco direito de cristal."""
import math

from mathutils import Vector

import lp
import en_base as eb
import en_golem as eg
from en_base import C, mg, sym, wave

ID = 'guardiao'
NAME = 'Guardião Cristalino'
RADIUS = 1.15
HEIGHT = 3.40
S = 1.31
BONES = eg.rig(S)
GOL = eg.Golem(S, 1.25)

SLATE = C('#5a5f96')
SLATE_HI = C('#8a90c6')
SLATE_LO = C('#2e2b56')
DARKST = C('#3a3868')
GOLD = C('#e2b048')
GOLD_HI = C('#ffe08a')
GOLD_LO = C('#93583a')
CR_BASE = C('#3323a6')
CR_TIP = C('#74ecea')


def slate(g, seed=0, lo=SLATE_LO, mid=SLATE, hi=SLATE_HI):
    b0, b1 = g.bounds()
    eb.paint3(g, [(b0[2], eb.mixc(lo, mid, 0.3)), (b0[2] + (b1[2] - b0[2]) * 0.5, mid), (b1[2], eb.mixc(mid, hi, 0.75))])
    return eb.speckle(g, 0.05, seed)


def gold(g):
    b0, b1 = g.bounds()
    eb.paint(g, b0[2], b1[2], GOLD_LO, GOLD_HI, power=0.7)
    return g


def cry(pos, d, h, r, seed=0, n=6, glow=True, tip=0.34, base=0.7):
    c = eb.crystal(r, h, n=n, tip=tip, base=base, c_base=CR_BASE, c_tip=CR_TIP, seed=seed, skew=r * 0.25,
                   glow_tip=glow)
    return eb.aim(c, d, pos, roll=seed * 37)


def model():
    g = lp.Geo()

    def add(geo, bone, seed=0, **kw):
        g.add(slate(geo, seed, **kw).bind(bone))

    def addg(geo, bone):
        g.add(gold(geo).bind(bone))

    def addc(bone, *a, **kw):
        g.add(cry(*a, **kw).bind(bone))

    # ---- quadril, cinto e tabardo
    add(eb.cbox(0.60, 0.46, 0.30, 0.05, center=(0, 0, 0.98), taper=0.86), 'body', 1)
    addg(eb.cbox(0.70, 0.54, 0.09, 0.02, center=(0, 0, 1.115)), 'body')
    add(lp.cyl(0.22, 0.12, n=8, center=(0, 0, 1.19), smooth=False), 'body', 2, mid=DARKST, hi=SLATE)
    tab = lp.poly_extrude([(-0.16, 0.0), (0.16, 0.0), (0.13, -0.34), (0.0, -0.46), (-0.13, -0.34)], 0.07)
    tab.move(0, -0.26, 1.06)
    addg(tab, 'body')
    add(eb.cbox(0.16, 0.03, 0.22, 0.01, center=(0, -0.30, 0.88)), 'body', 3, mid=DARKST, hi=SLATE)
    # ---- peito largo, gola dourada e o nucleo
    add(eb.cbox(1.04, 0.64, 0.70, 0.08, center=(0, 0.02, 1.52), taper=1.26), 'torso', 4)
    addg(eb.cbox(1.34, 0.24, 0.10, 0.03, center=(0, -0.27, 1.83)).rot('X', 12, (0, -0.27, 1.83)), 'torso')
    ring = lp.lathe([(0.17, 0.0), (0.27, 0.0), (0.27, 0.08), (0.19, 0.10)], n=6, smooth=False, phase=0.5)
    ring.rot('X', 90).move(0, -0.30, 1.44)
    addg(ring, 'torso')
    gem = lp.lathe([(0.0, -0.24), (0.165, 0.0), (0.0, 0.24)], n=6, smooth=False, mat='glow', phase=0.5)
    gem.scale(1.0, 0.55, 1.0).move(0, -0.34, 1.44)
    gem.tint(lambda p, c: eb.mixc(eb.GLOW_LO, eb.GLOW_HI, max(0.0, 1.0 - abs(p.z - 1.44) / 0.24)))
    g.add(gem.bind('core'))
    for ang, ln, off in ((38, 0.30, 0.36), (-52, 0.24, 0.34), (150, 0.22, 0.33), (-140, 0.28, 0.36), (100, 0.16, 0.30)):
        a = math.radians(ang)
        cx, cz = math.sin(a) * off, 1.44 + math.cos(a) * off
        m = eb.cbox(0.030, 0.03, ln, 0.008, center=(cx, -0.345 - 0.02 * math.cos(a), cz), mat='glow').color(eb.GLOW_LO)
        m.rot('Y', ang + 12, (cx, -0.345, cz))
        g.add(m.bind('core'))
    # cristais das costas (silhueta)
    addc('torso', (0.24, 0.26, 1.80), (0.30, 0.45, 1), 0.74, 0.130, 1)
    addc('torso', (-0.16, 0.30, 1.82), (-0.18, 0.55, 1), 0.80, 0.150, 2)
    addc('torso', (0.02, 0.34, 1.58), (0.05, 1, 0.55), 0.58, 0.120, 3)
    addc('torso', (0.46, 0.22, 1.74), (0.75, 0.40, 0.8), 0.46, 0.095, 4)
    addc('torso', (-0.40, 0.30, 1.50), (-0.6, 1, 0.3), 0.40, 0.090, 5, glow=False)
    # ---- cabeca baixa entre os ombros, com coroa de cristais
    add(eb.cbox(0.38, 0.38, 0.32, 0.05, center=(0, -0.10, 1.99), taper=0.86), 'noggin', 6)
    addg(eb.cbox(0.46, 0.15, 0.08, 0.02, center=(0, -0.27, 2.085)).rot('X', 18, (0, -0.27, 2.085)), 'noggin')
    add(eb.cbox(0.20, 0.10, 0.12, 0.02, center=(0, -0.27, 1.87)), 'noggin', 7, mid=DARKST, hi=SLATE)
    for a in (-1, 1):
        e = eb.cbox(0.115, 0.03, 0.050, 0.008, center=(0.095 * a, -0.292, 1.995), mat='glow')
        e.color(eb.mixc(eb.GLOW_LO, eb.GLOW_HI, 0.5)).rot('Y', 16 * a, (0.095 * a, -0.292, 1.995))
        g.add(e.bind('eyes'))
    addc('noggin', (0, -0.08, 2.10), (0, 0.12, 1), 0.50, 0.078, 6)
    addc('noggin', (0.13, -0.07, 2.09), (0.42, 0.10, 1), 0.38, 0.064, 7)
    addc('noggin', (-0.13, -0.07, 2.09), (-0.46, 0.14, 1), 0.34, 0.060, 8)
    addc('noggin', (0.19, -0.05, 2.04), (0.95, 0.15, 0.7), 0.25, 0.050, 9, glow=False)
    addc('noggin', (-0.19, -0.05, 2.04), (-0.95, 0.18, 0.6), 0.28, 0.052, 10, glow=False)
    # ---- braco esquerdo de pedra
    sh = eb.cbox(0.48, 0.52, 0.46, 0.06, center=(0.76, 0, 1.67))
    add(sh.rot('Y', 8, (0.76, 0, 1.67)), 'armU.L', 11)
    addg(eb.cbox(0.52, 0.56, 0.07, 0.02, center=(0.77, 0, 1.925)).rot('Y', 8, (0.76, 0, 1.67)), 'armU.L')
    addc('armU.L', (0.84, 0.10, 1.92), (0.5, 0.3, 1), 0.34, 0.07, 11)
    add(eb.cbox(0.22, 0.24, 0.30, 0.04, center=(0.80, 0.01, 1.32)), 'armU.L', 12, mid=DARKST, hi=SLATE)
    add(eb.cbox(0.44, 0.46, 0.58, 0.06, center=(0.85, -0.02, 0.87), taper=0.80), 'armF.L', 13)
    addg(eb.cbox(0.42, 0.44, 0.08, 0.02, center=(0.85, -0.02, 1.10)), 'armF.L')
    addg(eb.cbox(0.50, 0.52, 0.08, 0.02, center=(0.85, -0.02, 0.63)), 'armF.L')
    add(eb.cbox(0.54, 0.56, 0.42, 0.07, center=(0.86, -0.06, 0.33), taper=0.92), 'fist.L', 14)
    for k in (-1, 0, 1):
        add(eb.cbox(0.14, 0.09, 0.22, 0.025, center=(0.86 + 0.17 * k, -0.355, 0.29)), 'fist.L', 15 + k, mid=DARKST, hi=SLATE)
    # ---- braco direito: tomado pelo cristal
    add(eb.cbox(0.54, 0.56, 0.48, 0.06, center=(-0.80, 0, 1.68)).rot('Y', -10, (-0.8, 0, 1.68)), 'armU.R', 20)
    addc('armU.R', (-0.88, 0.05, 1.86), (-0.35, 0.2, 1), 0.56, 0.105, 20)
    addc('armU.R', (-1.00, -0.05, 1.78), (-0.9, 0.0, 0.55), 0.42, 0.085, 21)
    addc('armU.R', (-0.68, 0.16, 1.88), (0.1, 0.5, 1), 0.36, 0.070, 22, glow=False)
    addc('armU.R', (-0.80, 0.02, 1.50), (-0.08, 0.0, -1), 0.40, 0.135, 23, glow=False)
    addg(lp.cyl(0.25, 0.10, n=6, center=(-0.84, 0.02, 1.20), smooth=False), 'armF.R')
    addc('armF.R', (-0.84, 0.02, 1.26), (-0.02, -0.07, -1), 1.06, 0.255, 24, tip=0.36, base=0.74)
    addc('armF.R', (-0.92, 0.06, 1.08), (-0.80, 0.25, -0.50), 0.58, 0.130, 25)
    addc('armF.R', (-0.80, 0.12, 1.02), (0.10, 0.90, -0.35), 0.46, 0.110, 26, glow=False)
    addc('armF.R', (-0.88, -0.04, 0.98), (-0.45, -0.55, -0.75), 0.52, 0.120, 27)
    addc('fist.R', (-0.84, -0.08, 0.56), (0.20, -0.60, -0.75), 0.52, 0.115, 28)
    addc('fist.R', (-0.92, -0.06, 0.56), (-0.40, -0.25, -0.9), 0.44, 0.095, 29)
    # ---- pernas
    for a in (1, -1):
        sf = '.L' if a > 0 else '.R'
        sd = 30 if a > 0 else 40
        add(eb.cbox(0.34, 0.38, 0.36, 0.05, center=(0.28 * a, 0, 0.70)), 'legU' + sf, sd)
        addg(eb.cbox(0.26, 0.10, 0.16, 0.03, center=(0.29 * a, -0.19, 0.54)), 'legF' + sf)
        add(eb.cbox(0.27, 0.31, 0.27, 0.04, center=(0.29 * a, -0.01, 0.37)), 'legF' + sf, sd + 1, mid=DARKST, hi=SLATE)
        add(eb.cbox(0.46, 0.64, 0.24, 0.05, center=(0.30 * a, -0.08, 0.12), taper=0.84), 'paw' + sf, sd + 2)
        addg(eb.cbox(0.44, 0.16, 0.15, 0.03, center=(0.30 * a, -0.36, 0.085)), 'paw' + sf)
    addc('legU.R', (-0.40, -0.05, 0.80), (-0.9, -0.2, 0.5), 0.30, 0.07, 41, glow=False)
    addc('paw.L', (0.44, 0.10, 0.20), (0.6, 0.5, 0.7), 0.26, 0.06, 42, glow=False)
    g.scale(S)
    lp.bake_ao(g, strength=0.55, dist=0.6, samples=18, floor_z=0.0)
    return g


# ---------------------------------------------------------------- clipes so do chefe
G = GOL
KNEEL = mg({'body': (10, 0, 0), 'torso': (32, 0, 4), 'noggin': (24, 0, -6), 'paw.R.wrot': (52, 0, 0)},
           G.bp(0, -0.04, -0.40), G.feet(l=(0.02, 0.28, 0), r=(0.02, -0.44, 0.12)),
           G.hands((0.76, 0.46, 0.50), (-0.80, 0.40, 0.72)))
CHARGE = mg(G.REST, {'body': (20, 0, 10), 'torso': (14, 0, 22), 'noggin': (-24, 0, -28)}, G.bp(0, 0.10, -0.16),
            G.hands((0.95, -0.45, 0.80), (-0.20, 0.62, 1.05)))
OFF = {'core.scale': (0.01, 0.01, 0.01), 'eyes.scale': (0.01, 0.01, 0.01)}


def bk(name, n, keys, loop=False, base=None):
    return G.ck(name, n, keys, loop=loop, scale=False, base=base)


def cast(sk):
    """Ergue os dois bracos para o ceu e segura ~1,2 s (chuva de cristais). Efeito a partir do quadro 16."""
    up = mg({'body': (-4, 0, 0), 'torso': (-16, 0, 0), 'noggin': (-26, 0, 0)}, G.bp(0, -0.05, 0.03),
            G.hands((0.80, -0.05, 2.55), (-0.86, -0.05, 2.62)))
    c = bk('cast', 66, [
        (5, mg({'body': (6, 0, 0), 'torso': (10, 0, 0)}, G.bp(0, 0, -0.12), G.hands((0.80, 0.25, 0.60))), 'o'),
        (14, mg(up, {'core.scale': (1.6, 1.6, 1.6)}), 'o'),
        (50, mg(up, {'torso': (-19, 0, 0), 'core.scale': (1.6, 1.6, 1.6)})),
        (56, mg({'body': (4, 0, 0), 'torso': (10, 0, 0), 'noggin': (0, 0, 0), 'core.scale': (1, 1, 1)}, G.bp(0, 0.02, -0.08),
                G.hands((0.90, 0.25, 0.75))), 'i'),
        (66, G.REST),
    ])
    for i, ch in enumerate(('fist.L.ik', 'fist.R.ik')):
        eb.shake(c, ch, 13, 51, (0.035 * S, 0, 0.03 * S), freq=1.1, seed=3 + i, grow=False)
    eb.add_fn(c, 'core.scale', lambda f: ((0.3 * math.sin(f * 0.9),) * 3 if 14 <= f <= 50 else (0, 0, 0)))
    eb.add_fn(c, 'torso', lambda f: ((0, 0, 2.0 * math.sin(f * 0.35)) if 14 <= f <= 50 else (0, 0, 0)))
    return G.fin(c, sk, arms='world')


def roar(sk):
    """Troca de fase: encolhe, estufa o peito e ruge com os bracos abertos (~1,5 s)."""
    out = mg({'body': (-6, 0, 0), 'torso': (-24, 0, 0), 'noggin': (-34, 0, 0), 'core.scale': (2.0, 2.0, 2.0),
              'body.scale': (1.04, 1.04, 1.0)}, G.bp(0, -0.06, 0.02), G.hands((1.22, -0.36, 0.80), (-1.28, -0.38, 0.86)))
    c = bk('roar', 46, [
        (8, mg({'body': (8, 0, 0), 'torso': (24, 0, 0), 'noggin': (22, 0, 0), 'core.scale': (0.6, 0.6, 0.6)},
               G.bp(0, 0.02, -0.18), G.hands((0.26, 0.56, 1.00), (-0.26, 0.56, 1.06))), 'o'),
        (10, {'torso': (27, 0, 0)}),
        (13, out, 'i'),
        (34, mg(out, {'torso': (-20, 0, 0), 'core.scale': (1.6, 1.6, 1.6)})),
        (46, G.REST),
    ])
    eb.shake(c, 'torso', 12, 36, (1.5, 0, 3.0), freq=1.5, grow=False)
    eb.shake(c, 'noggin', 12, 36, (4, 0, 6), freq=1.7, seed=2, grow=False)
    eb.shake(c, 'fist.L.ik', 12, 36, (0.03 * S, 0.03 * S, 0.03 * S), freq=1.4, seed=5, grow=False)
    eb.shake(c, 'fist.R.ik', 12, 36, (0.03 * S, 0.03 * S, 0.03 * S), freq=1.4, seed=7, grow=False)
    return G.fin(c, sk, arms='world')


def charge_start(sk):
    """Empina, bate o pe e arma o ombro de cristal como ariete. Parte no quadro 24."""
    c = bk('charge_start', 24, [
        (6, mg({'body': (-8, 0, -6), 'torso': (-10, 0, -18), 'noggin': (-6, 0, 14)}, G.bp(0, -0.12, 0.0),
               G.hands((0.95, 0.10, 0.80), (-1.15, -0.30, 1.50)), G.feet(l=(0, 0.10, 0.32))), 'o'),
        (10, mg({'body': (8, 0, 0), 'torso': (0, 0, -22), 'body.scale': (1.05, 1.05, 0.94)}, G.bp(0, -0.04, -0.14),
                G.feet(l=(0, 0.20, 0))), 'i'),
        (13, {'body.scale': (1, 1, 1)}),
        (19, mg(CHARGE, {'body': (24, 0, 12)}, G.bp(0, 0.04, -0.22)), 'io'),
        (24, CHARGE),
    ])
    return G.fin(c, sk)


def charge_end(sk):
    c = bk('charge_end', 24, [
        (4, mg({'body': (-12, 0, 0), 'torso': (-10, 0, 4), 'noggin': (4, 0, 0), 'body.scale': (1.04, 1.04, 0.95)},
               G.bp(0, 0.14, -0.22), G.feet(l=(0, 0.32, 0), r=(0, 0.22, 0)), G.hands((0.80, 0.55, 0.95), (-0.80, 0.62, 1.0))), 'o'),
        (9, mg({'body': (-8, 0, 0)}, G.bp(0, 0.20, -0.20))),
        (15, mg({'body': (8, 0, 0), 'torso': (6, 0, 0), 'body.scale': (1, 1, 1)}, G.bp(0, 0.06, -0.10), G.feet(),
                G.hands((0.86, 0.16, 0.66))), 'io'),
        (24, G.REST),
    ], base=CHARGE)
    return G.fin(c, sk)


def stagger(sk):
    """Leva o tranco, desaba sobre um joelho, fica tonto (~1 s) e se levanta. 2 s."""
    c = bk('stagger', 60, [
        (3, mg({'body': (-6, 0, 4), 'torso': (-18, 0, 8), 'noggin': (-20, 0, 10), 'noggin.pos': G.v(0, 0, 0.10),
                'core.scale': (0.5, 0.5, 0.5)}, G.bp(0, -0.12, 0.0), G.hands((1.05, -0.10, 0.95), (-1.0, 0.0, 1.0))), 'o'),
        (8, mg({'body': (2, 0, -3), 'torso': (10, 0, -4), 'noggin.pos': (0, 0, 0)}, G.bp(0, -0.10, -0.16),
               G.feet(r=(0.02, -0.30, 0.16)))),
        (14, mg(KNEEL, {'body.scale': (1.05, 1.05, 0.93), 'core.scale': (0.45, 0.45, 0.45)}), 'i'),
        (18, mg({'body.scale': (1, 1, 1), 'torso': (28, 0, 4)})),
        (42, mg(KNEEL, {'torso': (34, 0, -4), 'core.scale': (0.7, 0.7, 0.7)})),
        (50, mg({'body': (12, 0, 0), 'torso': (16, 0, 0), 'noggin': (4, 0, 0), 'core.scale': (1.3, 1.3, 1.3),
                 'paw.R.wrot': (0, 0, 0)}, G.bp(0, 0.0, -0.20), G.feet(r=(0, -0.10, 0.14)), G.hands((0.86, 0.30, 0.55))), 'io'),
        (60, G.REST),
    ])
    stun = lambda f: max(0.0, min(1.0, (f - 16) / 4.0, (44 - f) / 4.0))
    eb.add_fn(c, 'noggin', lambda f: (4 * stun(f) * math.sin(f * 0.5), 0, 10 * stun(f) * math.sin(f * 0.25)))
    eb.add_fn(c, 'torso', lambda f: (0, 3 * stun(f) * math.sin(f * 0.25 + 1), 0))
    eb.add_fn(c, 'core.scale', lambda f: (0.25 * stun(f) * math.sin(f * 1.3),) * 3)
    return G.fin(c, sk, arms='world')


def spawn(sk):
    """Despertar: ajoelhado e apagado, o nucleo acende, a cabeca ergue, levanta e estufa o peito. ~2 s."""
    start = mg(G.REST, KNEEL, OFF)
    flex = mg({'body': (-4, 0, 0), 'torso': (-18, 0, 0), 'noggin': (-24, 0, 0), 'core.scale': (1.7, 1.7, 1.7)},
              G.bp(0, -0.04, 0.02), G.hands((1.18, -0.24, 0.92), (-1.24, -0.26, 1.0)))
    c = bk('spawn', 64, [
        (11, OFF),
        (15, {'core.scale': (2.0, 2.0, 2.0)}, 'o'), (20, {'core.scale': (1, 1, 1)}),
        (15, {'eyes.scale': (0.01, 0.01, 0.01)}), (18, {'eyes.scale': (1.3, 1.3, 1.8)}, 'o'), (22, {'eyes.scale': (1, 1, 1)}),
        (14, {'noggin': (24, 0, -6), 'torso': (32, 0, 4)}),
        (26, {'noggin': (-4, 0, 6), 'torso': (26, 0, 0)}),
        (24, mg({'body': (10, 0, 0), 'paw.R.wrot': (52, 0, 0)}, G.bp(0, -0.04, -0.52), G.feet(l=(0.02, 0.28, 0), r=(0.02, -0.44, 0.12)),
                G.hands((0.76, 0.46, 0.44), (-0.80, 0.40, 0.56)))),
        (34, mg({'body': (14, 0, 0), 'torso': (18, 0, 0), 'paw.R.wrot': (10, 0, 0)}, G.bp(0, 0.04, -0.26),
                G.feet(l=(0.02, 0.28, 0), r=(0, -0.16, 0.20)), G.hands((0.86, 0.36, 0.60), (-0.88, 0.34, 0.66)))),
        (42, mg({'body': (4, 0, 0), 'torso': (6, 0, 0), 'noggin': (0, 0, 0), 'paw.R.wrot': (0, 0, 0)}, G.bp(0, 0.04, -0.08),
                G.feet(l=(0, 0.10, 0), r=(0, 0.0, 0)), G.hands((0.86, 0.10, 0.52))), 'io'),
        (49, mg(flex, G.feet()), 'o'),
        (54, mg(flex, {'torso': (-15, 0, 0), 'core.scale': (1.4, 1.4, 1.4)})),
        (64, G.REST),
    ], base=start)
    eb.shake(c, 'noggin', 13, 27, (2, 0, 4), freq=1.4, grow=False)
    eb.shake(c, 'torso', 47, 56, (1.2, 0, 2.5), freq=1.5, seed=3, grow=False)
    return G.fin(c, sk, arms='world')


def clips(sk, g):
    slam, sh = G.slam(sk)
    sweep, wh = G.sweep(sk)
    charge = G.move(sk, n=16, stride=0.78, lean=0, name='charge', arm_r=0.03, base=CHARGE, drop=0.08, lift=0.28)
    return [(G.idle(sk), None), (G.move(sk, n=36, arm_r=0.04), None), (slam, sh), (sweep, wh), (cast(sk), 16), (roar(sk), None),
            (charge_start(sk), 24), (charge, 0), (charge_end(sk), None), (stagger(sk), None), (G.hit(sk, n=10), None),
            (G.die(sk, n=48, g=g), None), (spawn(sk), None)]

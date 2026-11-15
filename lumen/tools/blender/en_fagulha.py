"""en_fagulha.py: Fagulha, o espirito-lanterna (flutua a ~0,5 m, conjurador a distancia)."""
import math

from mathutils import Vector

import lp
import en_base as eb
from en_base import B, C, clip, mg, sym, wave

ID = 'fagulha'
NAME = 'Fagulha'
RADIUS = 0.30
HEIGHT = 1.55

MC = Vector((0.36, -0.12, 0.98))      # centro da luva esquerda
BONES = [
    B('root', None, (0, 0, 0)),
    B('body', 'root', (0, 0, 1.05), 0.2),
    B('wisp', 'body', (0, 0, 0.99), 0.12),
    B('ring', 'body', (0, 0, 1.465), 0.08),
    B('tail1', 'body', (0, 0, 0.84), 0.1),
    B('tail2', 'tail1', (0, 0.045, 0.63), 0.1),
    B('mitt.L', 'body', tuple(MC), 0.08),
    B('mitt.R', 'body', (-MC.x, MC.y, MC.z), 0.08),
]
BRASS = C('#e3a23a')
BRASS_HI = C('#ffd66e')
BRASS_LO = C('#8d4f3c')
ROOF = C('#4a3a9a')
ROOF_HI = C('#7a66d0')
CLOTH = C('#5a43a8')
CLOTH_HI = C('#a58ae8')
TAIL_TIP = (0, 0.21, 0.46)


def brass(g, z0, z1):
    eb.paint(g, z0, z1, BRASS_LO, BRASS_HI, power=0.8)
    return eb.under_shade(g, 0.8)


def model():
    g = lp.Geo()
    lan = lp.Geo()
    # prato de baixo + ponteira
    dish = lp.lathe([(0.0, 0.795), (0.035, 0.815), (0.06, 0.86), (0.165, 0.885), (0.19, 0.905), (0.172, 0.928),
                     (0.0, 0.93)], n=6, smooth=False)
    lan.add(brass(dish, 0.80, 0.94))
    # hastes curvas da gaiola
    for k in range(6):
        a = math.radians(60 * k)
        pts = [(math.cos(a) * r, math.sin(a) * r, z) for r, z in [(0.168, 0.915), (0.208, 0.99), (0.214, 1.10),
                                                                 (0.168, 1.215)]]
        lan.add(brass(lp.tube(pts, 0.013, n=4), 0.9, 1.25))
    band = lp.lathe([(0.20, 1.035), (0.222, 1.045), (0.222, 1.065), (0.20, 1.075)], n=6, smooth=False)
    band.keep_faces(lambda c: abs(math.atan2(c.x, -c.y)) > 0.6)      # janela da frente aberta
    lan.add(brass(band, 1.0, 1.1))
    # telhado de pagode
    roof = lp.lathe([(0.0, 1.20), (0.15, 1.205), (0.262, 1.192), (0.292, 1.228), (0.205, 1.268), (0.125, 1.335),
                     (0.07, 1.395), (0.052, 1.43), (0.0, 1.44)], n=6, smooth=False)
    eb.paint(roof, 1.19, 1.44, ROOF, ROOF_HI)
    roof.tint(lambda p, c: BRASS if (math.hypot(p.x, p.y) > 0.28) else c)
    eb.under_shade(roof, 0.9)
    lan.add(roof)
    for k in range(6):
        a = math.radians(60 * k)
        ball = lp.ellipsoid(0.024, 0.024, 0.024, n=5, rings=3, center=(math.cos(a) * 0.298, math.sin(a) * 0.298, 1.222))
        lan.add(brass(ball, 1.19, 1.25))
    knob = lp.lathe([(0.0, 1.43), (0.038, 1.445), (0.03, 1.47), (0.0, 1.48)], n=6)
    lan.add(brass(knob, 1.42, 1.48))
    lan.bind('body')
    g.add(lan)
    # argola de cima (balanca)
    pts = [(math.cos(math.tau * i / 8) * 0.058, 0, 1.53 + math.sin(math.tau * i / 8) * 0.058) for i in range(8)]
    ring = lp.loft([[Vector(p) + Vector((math.cos(math.tau * i / 8) * a, b, math.sin(math.tau * i / 8) * a))
                     for a, b in lp.ring_pts(4, 0.013, 0.013)] for i, p in list(enumerate(pts)) + [(0, pts[0])]],
                   cap_a=False, cap_b=False)
    g.add(brass(ring, 1.46, 1.6).bind('ring'))
    # chama (nucleo de lumen) com rostinho
    w = lp.lathe([(0.0, 0.935), (0.078, 0.955), (0.108, 1.01), (0.098, 1.07), (0.062, 1.125), (0.028, 1.17),
                  (0.0, 1.215)], n=8, mat='glow')
    w.warp(lambda p: Vector((p.x + 0.035 * max(0.0, (p.z - 1.08) / 0.13) ** 2, p.y, p.z)))
    eb.paint(w, 0.94, 1.21, (0.22, 0.64, 0.66), (0.02, 0.28, 0.62))
    g.add(w.bind('wisp'))
    for sx in (1, -1):
        e = eb.eye((0.040 * sx, -0.097, 1.035), (0.36 * sx, -1, 0.05), 0.021, 0.030, depth=0.012, hl=(-0.2, 0.3, 0.34),
                   color=C('#1d1440'))
        g.add(e.bind('wisp'))
    # cauda de pano
    tail = lp.tube([(0, 0, 0.875), (0, 0.0, 0.78), (0, 0.02, 0.68), (0, 0.07, 0.58), (0, 0.14, 0.50), TAIL_TIP],
                   [0.080, 0.112, 0.098, 0.072, 0.040, 0.006], n=7)
    eb.paint(tail, 0.46, 0.88, CLOTH_HI, CLOTH, power=0.8)
    eb.under_shade(tail, 0.8)
    eb.bind_chain(tail, [(0, 0, 0.84), (0, 0.045, 0.63), TAIL_TIP], ['tail1', 'tail2'], blend=0.35)
    g.add(tail)
    for k in range(6):
        a = math.radians(30 + 60 * k)
        fl = lp.poly_extrude([(-0.062, 0.0), (0.062, 0.0), (0.012, -0.19 if k % 2 else -0.15), (-0.02, -0.11)], 0.012)
        eb.paint(fl, -0.19, 0.0, CLOTH_HI, CLOTH)
        fl.rot('X', -20).rot('Z', math.degrees(a) + 90).move(math.cos(a) * 0.150, math.sin(a) * 0.150, 0.895)
        fl.bind_axis('z', [(0.74, 'tail1'), (0.87, 'body')])
        g.add(fl)
    # luvas flutuantes
    m = lp.ellipsoid(0.064, 0.088, 0.070, n=8, rings=5, center=tuple(MC + Vector((0, -0.03, 0))))
    th = lp.ellipsoid(0.030, 0.045, 0.030, n=6, rings=4, center=(MC.x - 0.062, MC.y - 0.035, MC.z + 0.025))
    m.add(th)
    eb.paint(m, MC.z - 0.07, MC.z + 0.07, CLOTH, CLOTH_HI)
    eb.under_shade(m, 0.9)
    cuff = lp.cyl(0.060, 0.040, n=8, r_top=0.052).rot('X', 90).move(MC.x, MC.y + 0.055, MC.z)
    brass(cuff, MC.z - 0.06, MC.z + 0.06)
    m.add(cuff)
    m.bind('mitt.L')
    g.add(m)
    g.add(m.mirrored())
    lp.bake_ao(g, strength=0.4, dist=0.25, samples=16)
    return g


# ---------------------------------------------------------------- animacao
REST = sym({'mitt.L': (0, 0, 0), 'mitt.L.pos': (0, 0, 0), 'mitt.L.scale': (1, 1, 1)})
REST.update({'body': (0, 0, 0), 'body.pos': (0, 0, 0), 'body.scale': (1, 1, 1), 'wisp': (0, 0, 0), 'wisp.scale': (1, 1, 1),
             'tail1': (0, 0, 0), 'tail2': (0, 0, 0)})


def ck(name, length, keys, loop=False):
    return clip(name, length, [(0, REST)] + list(keys), loop=loop, base=REST)


def flicker(c, amt=1.0):
    def fn(f):
        d = amt * (0.06 * math.sin(math.tau * f / 20.0) + 0.045 * math.sin(math.tau * f / 12.0 + 1.0))
        return (-d * 0.5, -d * 0.5, d)
    eb.add_fn(c, 'wisp.scale', fn)
    if c.loop:
        eb.add_fn(c, 'wisp', lambda f: (0, wave(f, 30, 5.0), 0))
    return c


def fin(c, sk, wind=(0, 0, 0), settle=5, floor=None, k=1.0):
    eb.spring(c, sk, 'ring', (0, 0, 1.59), k=240, c=5, limit=70, settle=settle, floor=floor)
    eb.spring(c, sk, 'tail1', (0, 0.045, 0.63), k=150 * k, c=7, limit=50, wind=wind, settle=settle)
    eb.spring(c, sk, 'tail2', TAIL_TIP, k=110 * k, c=6, limit=70, wind=wind, settle=settle, floor=floor)
    return c


def idle(sk, g):
    c = ck('idle', 60, [], loop=True)
    eb.add_fn(c, 'body.pos', lambda f: (wave(f, 60, 0.012, 0.25), 0, wave(f, 60, 0.05)))
    eb.add_fn(c, 'body', lambda f: (wave(f, 60, 3.0, 0.2), wave(f, 60, 2.5, 0.6), wave(f, 60, 5.0, 0.4)))
    eb.add_fn(c, 'mitt.L.pos', lambda f: (wave(f, 30, 0.012), wave(f, 60, 0.02, 0.5), wave(f, 60, 0.035, 0.70)))
    eb.add_fn(c, 'mitt.R.pos', lambda f: (wave(f, 30, 0.012, 0.5), wave(f, 60, 0.02), wave(f, 60, 0.035, 0.45)))
    eb.add_fn(c, 'mitt.L', lambda f: (wave(f, 60, 8, 0.6), 0, 0))
    eb.add_fn(c, 'mitt.R', lambda f: (wave(f, 60, 8, 0.35), 0, 0))
    eb.add_fn(c, 'tail1', lambda f: (wave(f, 30, 4.0), 0, 0))
    return fin(flicker(c), sk)


def move(sk, g):
    lean = sym({'mitt.L.pos': (0.03, -0.16, 0.0), 'mitt.L': (-20, 0, 0)})
    lean.update({'body': (17, 0, 0), 'wisp': (-18, 0, 0), 'tail1': (24, 0, 0), 'tail2': (18, 0, 0)})
    c = clip('move', 24, [(0, lean)], loop=True, base=REST)
    eb.add_fn(c, 'body.pos', lambda f: (0, 0, wave(f, 24, 0.035)))
    eb.add_fn(c, 'body', lambda f: (wave(f, 24, 3.0, 0.25), wave(f, 24, 3.0, 0.5), 0))
    eb.add_fn(c, 'mitt.L.pos', lambda f: (0, wave(f, 24, 0.07), wave(f, 24, 0.03, 0.25)))
    eb.add_fn(c, 'mitt.R.pos', lambda f: (0, wave(f, 24, 0.07, 0.5), wave(f, 24, 0.03, 0.75)))
    eb.add_fn(c, 'tail2', lambda f: (wave(f, 12, 9.0), wave(f, 24, 6.0), 0))
    return fin(flicker(c), sk, wind=(0, -2.0, 0), k=1.3)


def cast(sk, g):
    """Junta luz por ~0,5 s (a chama cresce) e empurra para a frente. Disparo no quadro 17."""
    c = ck('cast', 38, [
        (5, mg({'body': (-6, 0, 0), 'body.pos': (0, -0.05, 0.04), 'wisp.scale': (1.15, 1.15, 1.2)},
               sym({'mitt.L.pos': (-0.20, 0.20, 0.02), 'mitt.L': (0, 0, -30)})), 'o'),
        (13, mg({'body': (-20, 0, 0), 'body.pos': (0, -0.15, 0.11), 'body.scale': (0.94, 0.94, 1.08),
                 'wisp.scale': (1.6, 1.6, 1.75), 'tail1': (-16, 0, 0)},
                sym({'mitt.L.pos': (-0.10, -0.04, 0.24), 'mitt.L': (40, 0, -20), 'mitt.L.scale': (1.15, 1.15, 1.15)})),
         'io'),
        (15, {'body': (-23, 0, 0), 'body.pos': (0, -0.17, 0.12), 'wisp.scale': (1.75, 1.75, 1.9)}),
        (17, mg({'body': (26, 0, 0), 'body.pos': (0, 0.30, -0.05), 'body.scale': (1.10, 1.10, 0.88),
                 'wisp.scale': (0.65, 0.65, 0.55), 'tail1': (30, 0, 0)},
                sym({'mitt.L.pos': (-0.22, 0.34, 0.10), 'mitt.L': (-60, 0, 0), 'mitt.L.scale': (1.3, 1.3, 1.3)})), 'i'),
        (20, mg({'body': (30, 0, 0), 'body.pos': (0, 0.34, -0.06), 'body.scale': (1, 1, 1)},
                sym({'mitt.L.scale': (1, 1, 1)})), 'o'),
        (27, mg({'body': (-6, 0, 0), 'body.pos': (0, -0.05, 0.03), 'wisp.scale': (0.9, 0.9, 0.9), 'tail1': (0, 0, 0)},
                sym({'mitt.L.pos': (0.02, 0.06, 0.0), 'mitt.L': (-10, 0, 0)}))),
        (38, REST),
    ])
    eb.shake(c, 'body', 6, 16, (2.5, 0, 3.5), freq=1.0)
    eb.shake(c, 'mitt.L.pos', 6, 16, (0.012, 0, 0.012), freq=1.1, seed=3)
    eb.shake(c, 'mitt.R.pos', 6, 16, (0.012, 0, 0.012), freq=1.1, seed=5)
    return fin(c, sk)


def hit(sk, g):
    c = ck('hit', 9, [
        (2, mg({'body': (-26, 0, 10), 'body.pos': (0, -0.13, 0.04), 'body.scale': (1.1, 1.1, 0.9),
                'wisp.scale': (0.5, 0.5, 0.45)}, sym({'mitt.L.pos': (0.14, -0.04, 0.18), 'mitt.L': (30, 0, 30)})), 'o'),
        (5, mg({'body': (9, 0, -4), 'body.pos': (0, -0.03, -0.02), 'body.scale': (0.97, 0.97, 1.04),
                'wisp.scale': (1.2, 1.2, 1.3)}, sym({'mitt.L.pos': (0.02, 0.03, -0.03), 'mitt.L': (0, 0, 0)}))),
        (9, REST),
    ])
    return fin(c, sk, settle=3)


def die(sk, g):
    """A chama falha e apaga; a lanterna despenca e tomba de lado, as luvas caem."""
    down = {'body': (-84, 0, 24), 'body.pos': (0, -0.16, -0.86), 'wisp.scale': (0.01, 0.01, 0.01)}
    end = dict(down)
    eb.place(sk, end, 'mitt.L', MC, (0.44, -0.06, 0.055), (0, 80, 30))
    eb.place(sk, end, 'mitt.R', (-MC.x, MC.y, MC.z), (-0.36, -0.34, 0.055), (0, -84, -50))
    mid = {'body': (-30, 0, 10), 'body.pos': (0, -0.10, -0.30)}
    eb.place(sk, mid, 'mitt.L', MC, (0.46, 0.0, 0.50), (20, 30, 10))
    eb.place(sk, mid, 'mitt.R', (-MC.x, MC.y, MC.z), (-0.42, -0.22, 0.42), (10, -40, -20))
    c = ck('die', 38, [
        (2, mg({'body': (-24, 0, 8), 'body.pos': (0, -0.12, 0.05), 'wisp.scale': (0.5, 0.5, 0.45)},
               sym({'mitt.L.pos': (0.14, -0.04, 0.18)})), 'o'),
        (6, {'wisp.scale': (1.35, 1.35, 1.5), 'body': (-8, 0, -6), 'body.pos': (0, -0.10, 0.08)}),
        (9, {'wisp.scale': (0.35, 0.35, 0.3)}), (12, {'wisp.scale': (0.9, 0.9, 1.0), 'body': (-4, 0, 6),
                                                    'body.pos': (0, -0.10, 0.06)}),
        (15, mg({'wisp.scale': (0.01, 0.01, 0.01)}, sym({'mitt.L.pos': (0.04, 0.0, 0.04)})), 'i'),
        (19, mid, 'i'),
        (24, mg(down, {'body.scale': (1.08, 1.08, 0.9)}, {k: v for k, v in end.items() if k.startswith('mitt')}), 'i'),
        (28, {'body': (-74, 0, 30), 'body.pos': (0, -0.16, -0.78), 'body.scale': (1, 1, 1)}, 'o'),
        (33, {'body': (-86, 0, 34), 'body.pos': (0, -0.16, -0.86)}, 'i'),
        (38, {'body': (-84, 0, 34)}),
    ])
    lan = ('body',)
    eb.floor_fit(c, sk, g, mode='up', bones=lan)
    eb.floor_fit(c, sk, g, mode='fit', f0=24, f1=24, bones=lan)
    eb.floor_fit(c, sk, g, mode='fit', f0=32, bones=lan, blend=1)
    return fin(c, sk, settle=0, floor=0.03)


def spawn(sk, g):
    """A lanterna sobe do chao girando, a chama acende com um estalo e as luvas aparecem."""
    off = sym({'mitt.L.scale': (0.01, 0.01, 0.01), 'mitt.L.pos': (-0.2, 0.05, 0.0)})
    c = ck('spawn', 32, [
        (0, mg({'body.pos': (0, 0, -1.05), 'body.scale': (0.4, 0.4, 0.4), 'body': (0, 0, -400),
                'wisp.scale': (0.01, 0.01, 0.01)}, off)),
        (13, {'body.pos': (0, 0, 0.14), 'body.scale': (1.0, 1.0, 1.08), 'body': (0, 0, -30)}, 'o'),
        (18, {'body.pos': (0, 0, -0.03), 'body.scale': (1.03, 1.03, 0.97), 'body': (0, 0, 0)}),
        (16, {'wisp.scale': (0.01, 0.01, 0.01)}), (20, {'wisp.scale': (1.7, 1.7, 1.9)}, 'o'),
        (25, {'wisp.scale': (0.9, 0.9, 0.9)}), (30, {'wisp.scale': (1, 1, 1)}),
        (19, off), (23, sym({'mitt.L.scale': (1.3, 1.3, 1.3), 'mitt.L.pos': (0.03, 0, 0.03)}), 'o'),
        (27, sym({'mitt.L.scale': (1, 1, 1), 'mitt.L.pos': (0, 0, 0)})),
        (24, {'body.pos': (0, 0, 0.02), 'body.scale': (1, 1, 1)}),
        (32, REST),
    ])
    return fin(c, sk)


def clips(sk, g):
    return [(idle(sk, g), None), (move(sk, g), None), (cast(sk, g), 17), (hit(sk, g), None), (die(sk, g), None),
            (spawn(sk, g), None)]

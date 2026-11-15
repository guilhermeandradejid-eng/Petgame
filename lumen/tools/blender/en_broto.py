"""en_broto.py: Brotinho, o bulbo saltitante (inimigo fraco de enxame, 0,7 m)."""
import math

from mathutils import Matrix, Vector

import lp
import en_base as eb
from en_base import B, C, clip, mg, sym

ID = 'broto'
NAME = 'Brotinho'
RADIUS = 0.26
HEIGHT = 0.70

# ---------------------------------------------------------------- medidas
PROFILE = [(0.0, 0.035), (0.105, 0.042), (0.188, 0.085), (0.234, 0.165), (0.242, 0.25), (0.210, 0.335),
           (0.150, 0.400), (0.090, 0.440), (0.064, 0.468), (0.0, 0.476)]
YS = 0.93          # o bulbo e um pouco menos fundo que largo
EYE_X, EYE_Z = 0.096, 0.262
LEAF_BASE = Vector((0.028, 0.0, 0.462))

BONES = [
    B('root', None, (0, 0, 0)),
    B('body', 'root', (0, 0, 0.0), 0.10),
    B('crown', 'body', (0, 0, 0.10), 0.20),
    B('eye.L', 'crown', (EYE_X, -0.21, EYE_Z), 0.05),
    B('eye.R', 'crown', (-EYE_X, -0.21, EYE_Z), 0.05),
    B('leafA.L', 'crown', tuple(LEAF_BASE), 0.10),
    B('leafA.R', 'crown', (-LEAF_BASE.x, 0, LEAF_BASE.z), 0.10),
    # leafB.* entram em _leaf_bones() (dependem da curva da folha)
    B('toe.L', 'body', (0.105, -0.03, 0.05), 0.05),
    B('toe.R', 'body', (-0.105, -0.03, 0.05), 0.05),
    B('rootlet', 'body', (0, 0.17, 0.10), 0.06),
]

PINK = C('#ec6f98')
MAGENTA = C('#d43f86')
DEEP = C('#9c2a6c')
CREAM = C('#f3dcc0')
LEAF_LO = C('#258f5a')
LEAF_HI = C('#93dd52')
LEAF_BACK = C('#1f7d62')
PLUM = C('#5b2c58')


def rad(z):
    for (r0, z0), (r1, z1) in zip(PROFILE, PROFILE[1:]):
        if z <= z1:
            t = (z - z0) / (z1 - z0) if z1 > z0 else 0.0
            return r0 + (r1 - r0) * max(0.0, t)
    return 0.0


def surf(x, z):
    """Ponto e normal na frente do bulbo."""
    r = rad(z)
    y = -math.sqrt(max(1e-6, r * r - x * x))
    dr = (rad(z + 0.01) - rad(z - 0.01)) / 0.02
    n = Vector((x, y, -r * dr))
    n.y /= YS
    n.normalize()
    return Vector((x, y * YS, z)), n


def _leaf_xf(side, length, elev, yaw, pitch):
    """Transformacao da folha esquerda: nasce no pescoco, abre para fora e para cima."""
    m = Matrix.Rotation(math.radians(90), 4, 'Z')              # arqueia para +X
    m = Matrix.Rotation(math.radians(90 - elev), 4, 'Y') @ m    # levanta `elev` graus do horizonte
    m = Matrix.Rotation(math.radians(pitch), 4, 'X') @ m        # inclina o conjunto para a frente
    m = Matrix.Rotation(math.radians(yaw), 4, 'Z') @ m
    return Matrix.Translation(LEAF_BASE) @ m


LEAF_L = dict(length=0.40, width=0.235, elev=54, yaw=-12, pitch=24, droop=80)
LEAF_R = dict(length=0.35, width=0.21, elev=36, yaw=14, pitch=14, droop=60)   # montada como esquerda e espelhada


def _leaf(spec):
    g, spine = eb.leaf(spec['length'], spec['width'], n=5, droop=spec['droop'], fold=0.30, thickness=0.014,
                       tip=0.10, base=0.30, belly=0.42)
    L = spec['length']
    # cor: base escura -> ponta amarelada; verso mais frio; nervura clara
    eb.paint(g, 0.0, L * 0.8, LEAF_LO, LEAF_HI, power=0.9)
    nv = len(g.v) // 2
    g.c = [c if i < nv else eb.mixc(c, LEAF_BACK, 0.65) for i, c in enumerate(g.c)]
    g.c = [eb.mixc(c, LEAF_HI, 0.35) if (i < nv and i % 3 == 1) else c for i, c in enumerate(g.c)]
    zmid = spine[2].z + 0.01
    g.bind_axis('z', [(0.0, 'crown'), (0.03, 'leafA.L'), (zmid - 0.05, 'leafA.L'), (zmid + 0.05, 'leafB.L')])
    m = _leaf_xf('L', L, spec['elev'], spec['yaw'], spec['pitch'])
    g.xf(m)
    return g, [m @ p for p in spine]


def _leaves():
    gl, sl = _leaf(LEAF_L)
    gr, sr = _leaf(LEAF_R)
    gr = gr.mirrored()
    sr = [Vector((-p.x, p.y, p.z)) for p in sr]
    return gl, gr, sl, sr


_GL, _GR, _SL, _SR = _leaves()
# o osso da ponta fica no meio da nervura; usa a media espelhada para o esqueleto ser simetrico
_MID = Vector(((_SL[2].x - _SR[2].x) / 2, (_SL[2].y + _SR[2].y) / 2, (_SL[2].z + _SR[2].z) / 2))
BONES += [B('leafB.L', 'leafA.L', tuple(_MID), 0.08), B('leafB.R', 'leafA.R', (-_MID.x, _MID.y, _MID.z), 0.08)]
TIP_A = {'L': _SL[2], 'R': _SR[2]}
TIP_B = {'L': _SL[-1], 'R': _SR[-1]}


def model():
    g = lp.Geo()
    # ---- bulbo
    body = lp.lathe(PROFILE, n=12)
    body.scale(1.0, YS, 1.0)
    eb.paint3(body, [(0.03, C('#d9b3b4')), (0.11, CREAM), (0.19, C('#f7c3b6')), (0.28, PINK), (0.38, MAGENTA),
                     (0.47, DEEP)])
    # veios de rabanete: meridianos alternados mais escuros na metade de cima
    def veins(p, c):
        a = math.atan2(p.y, p.x)
        k = 0.5 + 0.5 * math.cos(a * 6)
        t = max(0.0, min(1.0, (p.z - 0.24) / 0.14)) * k
        return eb.mixc(c, DEEP, 0.28 * t)
    body.tint(veins)
    # bochechas
    def blush(p, c):
        if p.y > -0.05:
            return c
        d = min((Vector((p.x - sx * 0.165, p.z - 0.19)).length for sx in (-1, 1)))
        return eb.mixc(c, C('#ff8d9d'), 0.55 * max(0.0, 1.0 - d / 0.075))
    body.tint(blush)
    eb.under_shade(body, 0.9)
    body.bind_axis('z', [(0.05, 'body'), (0.20, 'crown')])
    g.add(body)

    # ---- pes
    for sx in (1, -1):
        f = lp.ellipsoid(0.066, 0.092, 0.050, n=8, rings=5, center=(0.105 * sx, -0.085, 0.044))
        f.warp(lambda p: Vector((p.x, p.y, max(p.z, 0.004))))
        eb.paint(f, 0.0, 0.09, eb.cool(PLUM, 0.75), C('#8a4a7c'))
        f.bind('toe.L' if sx > 0 else 'toe.R')
        g.add(f)

    # ---- raizinha atras
    path = [(0, 0.15, 0.10), (0, 0.235, 0.085), (0, 0.30, 0.105), (0.02, 0.345, 0.15), (0.045, 0.36, 0.20)]
    rt = lp.tube(path, [0.040, 0.030, 0.021, 0.013, 0.004], n=6, cap_a=False)
    eb.paint(rt, 0.15, 0.36, CREAM, PINK, axis='y')
    eb.under_shade(rt, 0.8)
    rt.bind_axis('y', [(0.17, 'body'), (0.24, 'rootlet')])
    g.add(rt)

    # ---- folhas e broto de lumen
    g.add(_GL)
    g.add(_GR)
    collar = lp.lathe([(0.0, 0.452), (0.070, 0.455), (0.082, 0.474), (0.060, 0.490), (0.0, 0.494)], n=8)
    eb.paint(collar, 0.45, 0.50, LEAF_LO, C('#58bd5c'))
    collar.bind('crown')
    g.add(collar)
    bud = lp.lathe([(0.0, 0.482), (0.034, 0.500), (0.040, 0.528), (0.022, 0.562), (0.0, 0.590)], n=6, mat='glow')
    eb.paint(bud, 0.49, 0.59, eb.GLOW_LO, eb.GLOW_HI)
    bud.bind('crown')
    g.add(bud)

    # ---- rosto
    for sx in (1, -1):
        p, n = surf(EYE_X * sx, EYE_Z)
        n = (n + Vector((0, -0.25, 0))).normalized()     # olha um pouco mais para a frente
        e = eb.eye((0, 0, 0), (0, -1, 0), 0.066, 0.078, depth=0.034, hl=(-0.22, 0.02, 0.30), hl2=(0.22, -0.42, 0.14),
                   cut_top=(0.50, 0.55 * sx), n=10)
        brow = eb.cbox(0.158, 0.046, 0.042, 0.012, center=(-0.008 * sx, 0.000, 0.078 * 0.50 + 0.022))
        brow.rot('Y', -29 * sx, (0, 0, 0.078 * 0.50))
        brow.color(DEEP)
        eb.paint(brow, 0.02, 0.09, eb.cool(DEEP, 0.9), C('#b8387c'))
        e.add(brow)
        e.xf(eb.face_frame(n, p - n * 0.004))
        e.bind('eye.L' if sx > 0 else 'eye.R')
        # a sobrancelha nao pisca: fica no bulbo
        nb = len(brow.v)
        for i in range(len(e.v) - nb, len(e.v)):
            e.w[i] = {'crown': 1.0}
        g.add(e)
    # boca emburrada + dentinho
    pts = []
    for i in range(5):
        x = -0.044 + 0.022 * i
        z = 0.172 - 0.020 * (abs(x) / 0.044) ** 1.6
        p, n = surf(x, z)
        pts.append(p + n * 0.004)
    mouth = lp.tube(pts, [0.006, 0.010, 0.011, 0.010, 0.006], n=4, up=(0, -1, 0)).color(eb.DARK)
    mouth.bind('crown')
    g.add(mouth)
    p, n = surf(0.020, 0.176)
    tooth = lp.cone(0.014, 0.034, n=4).color(lp.WHITE)
    tooth.scale(1.0, 0.7, 1.0).move(p.x, p.y - 0.008, p.z - 0.004)
    tooth.bind('crown')
    g.add(tooth)
    lp.bake_ao(g, strength=0.45, dist=0.25, samples=20, floor_z=0.0)
    return g


# ---------------------------------------------------------------- animacao
SOLID = ('body', 'crown', 'toe.L', 'toe.R')


def _springs(c, sk, g, wind=(0, 0, 0), k=1.0, settle=5, fit=None, floor=None):
    """Encosta no chao e depois assa o balanco das folhas e da raizinha."""
    if fit != 'none':
        eb.floor_fit(c, sk, g, mode='up', bones=SOLID)
    if fit and fit != 'none':
        eb.floor_fit(c, sk, g, mode='fit', f0=fit[0], blend=fit[1], bones=SOLID)
    for s in ('L', 'R'):
        eb.spring(c, sk, 'leafA.' + s, TIP_A[s], k=300 * k, c=11, limit=50, wind=wind, settle=settle, floor=floor)
        eb.spring(c, sk, 'leafB.' + s, TIP_B[s], k=200 * k, c=8, limit=75, wind=wind, settle=settle, floor=floor)
    eb.spring(c, sk, 'rootlet', (0.045, 0.36, 0.20), k=260, c=9, limit=40, settle=settle)
    return c


BLINK = {'eye.L.scale': (1, 1, 0.12), 'eye.R.scale': (1, 1, 0.12)}
OPEN = {'eye.L.scale': (1, 1, 1), 'eye.R.scale': (1, 1, 1)}
SQUINT = {'eye.L.scale': (1.05, 1, 0.55), 'eye.R.scale': (1.05, 1, 0.55)}


def idle(sk, g):
    c = clip('idle', 48, [
        (0, mg({'body.scale': (1, 1, 1), 'crown': (0, 0, 0), 'toe.L': (0, 0, 0), 'toe.R': (0, 0, 0),
                'leafA.L': (0, 0, 0), 'leafA.R': (0, 0, 0)}, OPEN)),
        (9, {'body.scale': (1.05, 1.05, 0.94), 'crown': (4, 0, -3), 'leafA.L': (0, 5, 0), 'leafA.R': (0, 5, 0)}),
        (20, {'body.scale': (0.97, 0.97, 1.04), 'crown': (-3, 4, 3), 'leafA.L': (0, -6, 0), 'leafA.R': (0, -3, 0)}),
        (22, {'toe.L': (0, 0, 0)}),
        (25, {'toe.L': (-28, 0, 0)}, 'o'),
        (28, {'toe.L': (0, 0, 0)}, 'i'),
        (31, {'toe.L': (-22, 0, 0)}, 'o'),
        (34, {'toe.L': (0, 0, 0), 'body.scale': (1.04, 1.04, 0.95), 'crown': (3, -3, 2)}, 'i'),
        (30, OPEN), (32, BLINK, 'i'), (35, OPEN, 'o'),
        (42, {'body.scale': (0.985, 0.985, 1.02), 'crown': (-1, 0, -1), 'leafA.L': (0, -2, 0), 'leafA.R': (0, 4, 0)}),
        (38, {'leafB.R': (0, 0, 0)}), (40, {'leafB.R': (0, -26, 0)}, 'o'), (44, {'leafB.R': (0, 0, 0)}, 'io'),
    ], loop=True)
    return _springs(c, sk, g)


def move(sk, g):
    """Ciclo de pulo (0,6 s): amassa, estica, sobe, cai."""
    c = clip('move', 18, [
        (0, {'body.pos': (0, 0, 0), 'body.scale': (1.20, 1.20, 0.74), 'body': (0, 0, 0), 'crown': (-5, 0, 0),
             'toe.L': (0, 0, 0), 'toe.R': (0, 0, 0)}),
        (3, {'body.pos': (0, 0, 0), 'body.scale': (1.25, 1.25, 0.68), 'body': (6, 0, 0), 'crown': (10, 0, 0)}, 'o'),
        (6, {'body.pos': (0, 0, 0.05), 'body.scale': (0.82, 0.82, 1.28), 'body': (10, 0, 0), 'crown': (8, 0, 0),
             'toe.L': (46, 0, 0), 'toe.R': (40, 0, 0)}, 'i'),
        (11, {'body.pos': (0, 0, 0.27), 'body.scale': (0.97, 0.97, 1.04), 'body': (2, 0, 0), 'crown': (0, 0, 0),
              'toe.L': (-10, 0, 0), 'toe.R': (-22, 0, 0)}, 'o'),
        (15, {'body.pos': (0, 0, 0.13), 'body.scale': (0.90, 0.90, 1.14), 'body': (-8, 0, 0), 'crown': (-6, 0, 0),
              'toe.L': (-30, 0, 0), 'toe.R': (-34, 0, 0)}, 'i'),
        (18, {'body.pos': (0, 0, 0), 'body.scale': (1.20, 1.20, 0.74), 'body': (0, 0, 0), 'crown': (-5, 0, 0),
              'toe.L': (0, 0, 0), 'toe.R': (0, 0, 0)}, 'i'),
    ], loop=True)
    return _springs(c, sk, g, wind=(0, -5.0, 0))


def attack(sk, g):
    """Agacha (0,35 s) e da uma cabecada. Acerto no quadro 13."""
    c = clip('attack', 28, [
        (0, mg({'body.pos': (0, 0, 0), 'body.scale': (1, 1, 1), 'body': (0, 0, 0), 'crown': (0, 0, 0),
                'toe.L': (0, 0, 0), 'toe.R': (0, 0, 0), 'leafA.L': (0, 0, 0), 'leafA.R': (0, 0, 0)}, OPEN)),
        (3, {'body.scale': (0.95, 0.95, 1.08), 'crown': (6, 0, 0)}, 'o'),
        (8, mg({'body.pos': (0, -0.07, 0), 'body.scale': (1.26, 1.26, 0.66), 'body': (-8, 0, 0), 'crown': (-26, 0, 0),
                'leafA.L': (-30, 20, 0), 'leafA.R': (-30, 20, 0)}, SQUINT), 'o'),
        (11, {'body.pos': (0, -0.09, 0), 'body.scale': (1.30, 1.30, 0.62), 'body': (-10, 0, 0), 'crown': (-30, 0, 0)},
         'io'),
        (13, {'body.pos': (0, 0.36, 0.17), 'body.scale': (0.80, 0.80, 1.36), 'body': (64, 0, 0), 'crown': (14, 0, 0),
              'toe.L': (50, 0, 0), 'toe.R': (50, 0, 0), 'leafA.L': (20, -10, 0), 'leafA.R': (20, -10, 0)}, 'i'),
        (15, {'body.pos': (0, 0.42, 0.14), 'body.scale': (1.12, 1.12, 0.84), 'body': (72, 0, 0), 'crown': (4, 0, 0)},
         'o'),
        (19, mg({'body.pos': (0, 0.24, 0.20), 'body.scale': (1, 1, 1), 'body': (24, 0, 0), 'crown': (-8, 0, 0),
                 'toe.L': (-20, 0, 0), 'toe.R': (-20, 0, 0), 'leafA.L': (0, 0, 0), 'leafA.R': (0, 0, 0)}, OPEN), 'io'),
        (23, {'body.pos': (0, 0, 0), 'body.scale': (1.18, 1.18, 0.78), 'body': (0, 0, 0), 'crown': (-4, 0, 0),
              'toe.L': (0, 0, 0), 'toe.R': (0, 0, 0)}, 'i'),
        (28, {'body.scale': (1, 1, 1), 'crown': (0, 0, 0)}, 'b'),
    ])
    eb.shake(c, 'crown', 7, 12, (0, 0, 5), freq=1.0)
    return _springs(c, sk, g)


def hit(sk, g):
    c = clip('hit', 9, [
        (0, mg({'body.pos': (0, 0, 0), 'body.scale': (1, 1, 1), 'body': (0, 0, 0), 'crown': (0, 0, 0),
                'toe.L': (0, 0, 0), 'toe.R': (0, 0, 0)}, OPEN)),
        (2, mg({'body.pos': (0, -0.08, 0.03), 'body.scale': (1.16, 1.16, 0.82), 'body': (-20, 0, 6),
                'crown': (-22, 0, 8), 'toe.L': (-45, 0, 0), 'toe.R': (-30, 0, 0)}, BLINK), 'o'),
        (5, mg({'body.pos': (0, -0.03, 0), 'body.scale': (0.94, 0.94, 1.08), 'body': (4, 0, -2), 'crown': (8, 0, -3),
                'toe.L': (0, 0, 0), 'toe.R': (0, 0, 0)}, SQUINT)),
        (9, mg({'body.pos': (0, 0, 0), 'body.scale': (1, 1, 1), 'body': (0, 0, 0), 'crown': (0, 0, 0)}, OPEN)),
    ])
    return _springs(c, sk, g, settle=3)


def die(sk, g):
    """Leva o golpe, da uma cambalhota para tras e murcha de costas no chao."""
    end = mg({'body.pos': (0, -0.34, 0.215), 'body': (-442, 0, 14), 'body.scale': (1.16, 0.80, 1.06),
              'crown': (-6, 0, 0), 'toe.L': (34, 0, 20), 'toe.R': (18, 0, 12),
              'leafA.L': (22, 30, 0), 'leafA.R': (18, 20, 0)}, BLINK)
    c = clip('die', 30, [
        (0, mg({'body.pos': (0, 0, 0), 'body.scale': (1, 1, 1), 'body': (0, 0, 0), 'crown': (0, 0, 0),
                'toe.L': (0, 0, 0), 'toe.R': (0, 0, 0), 'leafA.L': (0, 0, 0), 'leafA.R': (0, 0, 0)}, OPEN)),
        (2, mg({'body.pos': (0, -0.06, 0.06), 'body.scale': (1.18, 1.18, 0.80), 'body': (-26, 0, 0),
                'crown': (-20, 0, 0)}, BLINK), 'o'),
        (8, {'body.pos': (0, -0.20, 0.50), 'body.scale': (0.90, 0.90, 1.16), 'body': (-200, 0, 4),
             'toe.L': (-40, 0, 0), 'toe.R': (-25, 0, 0)}, 'o'),
        (14, {'body.pos': (0, -0.33, 0.20), 'body.scale': (1.24, 0.66, 1.14), 'body': (-438, 0, 10),
              'crown': (-10, 0, 0), 'toe.L': (40, 0, 20), 'toe.R': (30, 0, 12)}, 'i'),
        (18, {'body.pos': (0, -0.34, 0.30), 'body.scale': (0.96, 1.06, 0.98), 'body': (-448, 0, 16)}, 'o'),
        (22, {'body.pos': (0, -0.34, 0.20), 'body.scale': (1.20, 0.74, 1.08), 'body': (-441, 0, 14),
              'leafA.L': (0, 30, 0), 'leafA.R': (0, 20, 0)}, 'i'),
        (30, end, 'o'),
    ])
    return _springs(c, sk, g, settle=0, fit=(14, 2), floor=0.03)


def spawn(sk, g):
    """As folhas aparecem primeiro, tremem, e o bulbo pula para fora da terra."""
    shut = {'leafA.L': (0, -34, 0), 'leafA.R': (0, -30, 0), 'leafB.L': (0, -30, 0), 'leafB.R': (0, -26, 0)}
    c = clip('spawn', 26, [
        (0, mg({'body.pos': (0, 0, -0.62), 'body.scale': (0.7, 0.7, 0.7), 'body': (0, 0, 0), 'crown': (0, 0, 0),
                'toe.L': (0, 0, 0), 'toe.R': (0, 0, 0)}, shut, OPEN)),
        (4, {'body.pos': (0, 0, -0.44), 'body.scale': (0.8, 0.8, 0.8), 'body': (0, 0, 9)}, 'o'),
        (7, {'body.pos': (0, 0, -0.42), 'body': (0, 0, -9)}),
        (10, {'body.pos': (0, 0, -0.50), 'body.scale': (0.95, 0.95, 0.80), 'body': (0, 0, 4)}, 'io'),
        (11, shut),
        (14, mg({'body.pos': (0, 0, 0.34), 'body.scale': (0.80, 0.80, 1.34), 'body': (0, 0, 0),
                 'toe.L': (40, 0, 0), 'toe.R': (40, 0, 0), 'leafA.L': (0, 16, 0), 'leafA.R': (0, 16, 0),
                 'leafB.L': (0, 0, 0), 'leafB.R': (0, 0, 0)}, SQUINT), 'o'),
        (16, {'body.pos': (0, 0, 0.36), 'body.scale': (0.96, 0.96, 1.06), 'toe.L': (-20, 0, 0), 'toe.R': (-20, 0, 0)}),
        (19, mg({'body.pos': (0, 0, 0), 'body.scale': (1.26, 1.26, 0.68), 'toe.L': (0, 0, 0), 'toe.R': (0, 0, 0),
                 'leafA.L': (0, 0, 0), 'leafA.R': (0, 0, 0)}, OPEN), 'i'),
        (22, {'body.scale': (0.94, 0.94, 1.09)}, 'o'),
        (26, {'body.scale': (1, 1, 1)}),
    ])
    eb.floor_fit(c, sk, g, mode='up', f0=15, bones=SOLID)
    return _springs(c, sk, g, fit='none')


def clips(sk, g):
    return [(idle(sk, g), None), (move(sk, g), None), (attack(sk, g), 13), (hit(sk, g), None), (die(sk, g), None),
            (spawn(sk, g), None)]

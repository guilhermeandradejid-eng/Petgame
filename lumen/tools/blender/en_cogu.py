"""en_cogu.py: Cogumelo Brigao, o cogumelo lutador (1,1 m, corpo a corpo)."""
import math

from mathutils import Matrix, Vector

import lp
import en_base as eb
from en_base import B, C, clip, mg, sym

ID = 'cogu'
NAME = 'Cogumelo Brigão'
RADIUS = 0.40
HEIGHT = 1.10

SH = Vector((0.26, 0.0, 0.52))
EL = Vector((0.44, -0.02, 0.41))
WR = Vector((0.46, -0.21, 0.32))
HIPV = Vector((0.13, 0.0, 0.22))
CAP_PIV = Vector((0, 0, 0.66))

BONES = [
    B('root', None, (0, 0, 0)),
    B('body', 'root', (0, 0, 0), 0.2),
    B('torso', 'body', (0, 0, 0.30), 0.2),
    B('cap', 'torso', tuple(CAP_PIV), 0.3),
    B('eye.L', 'torso', (0.088, -0.24, 0.475), 0.05),
    B('eye.R', 'torso', (-0.088, -0.24, 0.475), 0.05),
]
for s in (1, -1):
    sf = '.L' if s > 0 else '.R'
    BONES += [B('armU' + sf, 'torso', (SH.x * s, SH.y, SH.z)), B('armF' + sf, 'armU' + sf, (EL.x * s, EL.y, EL.z)),
              B('fist' + sf, 'armF' + sf, (WR.x * s, WR.y, WR.z)), B('legU' + sf, 'body', (HIPV.x * s, 0, HIPV.z))]

STALK = [(0.0, 0.14), (0.15, 0.15), (0.245, 0.215), (0.278, 0.33), (0.264, 0.44), (0.230, 0.55), (0.205, 0.64),
         (0.19, 0.71), (0.0, 0.73)]
CAPP = [(0.10, 0.665), (0.30, 0.640), (0.455, 0.622), (0.492, 0.648), (0.497, 0.700), (0.468, 0.81), (0.40, 0.93),
        (0.29, 1.02), (0.15, 1.085), (0.0, 1.105)]
CAP_TILT = Matrix.Translation(Vector((0, 0.025, 0))) @ Matrix.Translation(CAP_PIV) @ \
    Matrix.Rotation(math.radians(-13), 4, 'X') @ Matrix.Translation(-CAP_PIV)

RED = C('#e8503a')
RED_HI = C('#ff8347')
RED_LO = C('#9c2848')
CREAM = C('#e6d2b0')
SPOT = C('#ffe6a8')
GILL = C('#e9b48e')
WRAP = C('#7748ad')
WRAP_HI = C('#b596e3')
BOOT = C('#553066')
BROW = C('#4a2140')


def _prof(prof, z):
    for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
        if z0 <= z <= z1:
            t = (z - z0) / (z1 - z0) if z1 > z0 else 0.0
            return r0 + (r1 - r0) * t, (r1 - r0) / max(1e-6, z1 - z0)
    return prof[-1][0], 0.0


def stalk_surf(x, z):
    r, dr = _prof(STALK, z)
    y = -math.sqrt(max(1e-6, r * r - x * x))
    return Vector((x, y, z)), Vector((x, y, -r * dr)).normalized()


def cap_surf(theta, z):
    """Ponto e normal na cupula do chapeu (theta em graus a partir da frente, para a esquerda)."""
    r, dr = _prof(CAPP[4:], z)
    a = math.radians(theta)
    nr = Vector((1.0, -dr)).normalized()
    p = Vector((r * math.sin(a), -r * math.cos(a), z))
    n = Vector((math.sin(a) * nr.x, -math.cos(a) * nr.x, nr.y))
    return CAP_TILT @ p, (CAP_TILT.to_3x3() @ n).normalized()


def model():
    g = lp.Geo()
    # ---- corpo (talo)
    st = lp.lathe(STALK, n=12)
    st.warp(lambda p: Vector((p.x, p.y - 0.02 * math.exp(-((p.z - 0.30) / 0.12) ** 2) * (1 if p.y < 0 else 0), p.z)))
    eb.paint3(st, [(0.14, C('#bfa0bb')), (0.26, C('#d9c1ae')), (0.45, CREAM), (0.70, C('#cdb3a6'))])
    eb.under_shade(st, 0.8)
    st.bind_axis('z', [(0.22, 'body'), (0.40, 'torso')])
    g.add(st)

    # ---- chapeu
    n = 14
    cap = lp.lathe(CAPP, n=n)
    cols = []
    for i, p in enumerate(cap.v):
        row = min(i // n, len(CAPP) - 1)
        if row <= 2:
            k = (i % n) % 2
            c = eb.mixc(eb.cool(GILL, 0.62), GILL, row / 2.0)
            cols.append(eb.mixc(c, eb.cool(GILL, 0.8), 0.35 * k))
        elif row == 3:
            cols.append(RED_LO)
        else:
            t = (p.z - 0.70) / 0.40
            cols.append(eb.mixc(eb.mixc(RED_LO, RED, min(1.0, t * 2.2)), RED_HI, max(0.0, t - 0.5) * 1.3))
    cap.c = cols

    def wavy(p):
        r = math.hypot(p.x, p.y)
        if r < 0.2:
            return p
        a = math.atan2(p.x, -p.y)
        rim = max(0.0, min(1.0, (r - 0.25) / 0.24)) * max(0.0, min(1.0, (0.95 - p.z) / 0.25))
        k = 1.0 + rim * (0.045 * math.sin(a * 3 + 0.8) + 0.03 * math.sin(a * 5 + 2.0))
        nick = math.exp(-((a - math.radians(-118)) / 0.20) ** 2) * rim
        k -= 0.20 * nick
        return Vector((p.x * k, p.y * k, p.z + 0.035 * nick + 0.012 * rim * math.sin(a * 4 + 1.0)))
    cap.warp(wavy)
    cap.xf(CAP_TILT)
    cap.bind('cap')
    g.add(cap)
    for th, z, r in [(24, 0.955, 0.105), (-52, 0.86, 0.074), (100, 0.875, 0.088), (-150, 0.93, 0.095), (172, 0.80, 0.060),
                     (-14, 1.07, 0.062), (62, 0.775, 0.046), (-96, 1.02, 0.052), (140, 1.03, 0.045), (-20, 0.80, 0.040)]:
        p, nr = cap_surf(th, z)
        s = lp.ellipsoid(r, r * 0.92, 0.030, n=8, rings=4)
        s.keep_faces(lambda c: c.z > -0.006)
        eb.paint(s, 0.0, 0.03, eb.mixc(SPOT, RED_HI, 0.25), SPOT)
        eb.aim(s, nr, p - nr * 0.010, roll=th)
        s.bind('cap')
        g.add(s)

    # ---- rosto emburrado
    for sx in (1, -1):
        p, nr = stalk_surf(0.088 * sx, 0.475)
        nr = (nr + Vector((0, -0.3, 0.05))).normalized()
        g.add(eb.brow_eye(p, nr, sx, 0.050, 0.054, 0.026, cut=(0.30, 0.30), brow=(0.150, 0.050, BROW, 17),
                          face_bone='torso'))
    pts = []
    for i in range(7):
        x = -0.084 + 0.028 * i
        z = 0.375 - 0.030 * (abs(x) / 0.084) ** 1.5
        p, nr = stalk_surf(x, z)
        pts.append(p + nr * 0.004)
    g.add(lp.tube(pts, [0.006, 0.011, 0.013, 0.013, 0.013, 0.011, 0.006], n=4, up=(0, -1, 0)).color(eb.DARK).bind('torso'))
    for x in (-0.050, 0.046):
        p, nr = stalk_surf(x, 0.366)
        g.add(lp.cone(0.016, 0.040, n=4).color(lp.WHITE).scale(1, 0.7, 1).move(p.x, p.y - 0.010, p.z - 0.004).bind('torso'))

    # ---- bracos e punhos (lado esquerdo, depois espelha)
    side = lp.Geo()
    path = [SH + Vector((-0.07, 0, 0.01)), SH, (SH + EL) / 2 + Vector((0.015, 0, 0.01)), EL, (EL + WR) / 2, WR]
    arm = lp.tube(path, [0.050, 0.062, 0.064, 0.070, 0.082, 0.092], n=7, cap_a=False)
    eb.paint(arm, 0.30, 0.54, C('#d9c0b4'), CREAM)
    eb.under_shade(arm, 0.7)
    eb.bind_chain(arm, [SH, EL, WR + (WR - EL)], ['armU.L', 'armF.L'], blend=0.3)
    side.add(arm)
    fc = WR + Vector((0.0, -0.10, -0.015))
    fist = lp.ellipsoid(0.120, 0.138, 0.110, n=9, rings=6, center=tuple(fc))

    def boxy(p):
        d = p - fc
        return fc + Vector((d.x, d.y * (1.0 + 0.10 * (1 if d.y < 0 else 0)), d.z * (0.92 if d.z > 0 else 1.0)))
    fist.warp(boxy)

    def wrap(p, c):
        band = 0.5 + 0.5 * math.sin((p.y - fc.y) * 62.0 + (p.z - fc.z) * 30.0)
        return eb.mixc(WRAP, WRAP_HI, 0.55 * (1 if band > 0.72 else 0))
    fist.tint(wrap)
    eb.under_shade(fist, 0.9)
    side.add(fist.bind('fist.L'))
    for i in range(3):
        kx = fc.x - 0.07 + 0.07 * i
        kn = lp.ellipsoid(0.040, 0.040, 0.036, n=6, rings=4, center=(kx, fc.y - 0.105, fc.z + 0.055))
        kn.color(eb.warm(WRAP_HI, 0.98))
        side.add(kn.bind('fist.L'))
    th = lp.ellipsoid(0.045, 0.062, 0.045, n=6, rings=4, center=(fc.x - 0.105, fc.y - 0.035, fc.z + 0.01))
    th.color(WRAP)
    eb.under_shade(th, 0.9)
    side.add(th.bind('fist.L'))
    cuff = lp.tube([WR + Vector((0, 0.035, 0.012)), WR + Vector((0, -0.02, -0.008))], 0.103, n=8)
    cuff.color(eb.cool(WRAP, 0.8))
    side.add(cuff.bind('fist.L'))
    # ---- perninhas e botas
    leg = lp.tube([(0.125, 0, 0.27), (0.135, 0, 0.16), (0.14, -0.005, 0.07)], [0.085, 0.082, 0.078], n=7)
    eb.paint(leg, 0.06, 0.28, C('#b99bb6'), C('#e2ccbb'))
    side.add(leg.bind('legU.L'))
    boot = lp.ellipsoid(0.100, 0.150, 0.075, n=8, rings=5, center=(0.145, -0.05, 0.062))
    boot.warp(lambda p: Vector((p.x, p.y, max(p.z, 0.004))))
    eb.paint(boot, 0.0, 0.14, eb.cool(BOOT, 0.8), C('#7d4a8c'))
    side.add(boot.bind('legU.L'))
    g.add(side)
    g.add(side.mirrored())
    lp.bake_ao(g, strength=0.5, dist=0.35, samples=20, floor_z=0.0)
    return g


# ---------------------------------------------------------------- animacao
RW = eb.lfu(WR)
REST = sym({'fist.L.ik': RW, 'fist.L': (0, 0, 0), 'fist.L.scale': (1, 1, 1), 'legU.L': (0, 0, 0), 'legU.L.pos': (0, 0, 0),
            'eye.L.scale': (1, 1, 1)})
REST.update({'body': (0, 0, 0), 'body.pos': (0, 0, 0), 'body.scale': (1, 1, 1), 'torso': (0, 0, 0), 'cap': (0, 0, 0),
             'cap.scale': (1, 1, 1)})
SHUT = sym({'eye.L.scale': (1, 1, 0.12)})
OPEN = sym({'eye.L.scale': (1, 1, 1)})
CAP_TIP = (0, 0.12, 1.10)


def fin(c, sk, g, floor=True, f0=0, fit=None, settle=5, k=1.0):
    for sf in ('.L', '.R'):
        eb.ik_bake(c, sk, 'armU' + sf, 'armF' + sf, 'fist' + sf, space='parent')
    if floor:
        eb.floor_fit(c, sk, g, mode='up', f0=f0)
    if fit:
        eb.floor_fit(c, sk, g, mode='fit', f0=fit[0], f1=fit[1], blend=2)
    eb.spring(c, sk, 'cap', CAP_TIP, k=330 * k, c=9, limit=20, settle=settle)
    return c


def ck(name, length, keys, loop=False):
    return clip(name, length, [(0, REST)] + list(keys), loop=loop, base=REST)


def idle(sk, g):
    c = ck('idle', 40, [
        (10, sym({'body.scale': (1.04, 1.04, 0.95), 'torso': (4, 0, 0), 'cap': (3, 0, 0), 'fist.L.ik': (0.47, 0.20, 0.29)})),
        (20, sym({'body.scale': (0.98, 0.98, 1.03), 'torso': (-3, 0, 2), 'cap': (-3, 0, 0), 'fist.L.ik': (0.44, 0.24, 0.37),
                  'fist.L.scale': (1.12, 1.12, 1.12)})),
        (24, sym({'fist.L.scale': (1, 1, 1)})),
        (30, sym({'body.scale': (1.03, 1.03, 0.96), 'torso': (3, 0, -2), 'cap': (2, 0, 0), 'fist.L.ik': (0.47, 0.20, 0.30)})),
        (26, OPEN), (28, SHUT, 'i'), (31, OPEN, 'o'),
    ], loop=True)
    return fin(c, sk, g)


def move(sk, g):
    """Gingado: rola de um pe para o outro, bracos pesados balancando."""
    def step(s):   # s=+1: peso no pe esquerdo, direito no ar
        return {'body': (5, 9 * s, -5 * s), 'body.pos': (0.035 * s, 0, 0.0), 'torso': (2, 0, 9 * s),
                'legU.L': (-6 if s < 0 else 4, -9 * s, 0), 'legU.R': (-6 if s > 0 else 4, 9 * s, 0),
                'legU.L.pos': (0, 0, 0.07 if s < 0 else 0), 'legU.R.pos': (0, 0, 0.07 if s > 0 else 0),
                'fist.L.ik': (0.46, 0.20 - 0.02 * s, 0.33), 'fist.R.ik': (-0.46, 0.20 + 0.02 * s, 0.33), 'cap': (3, 0, 0)}

    def contact(s):  # s=+1: pe esquerdo na frente
        return {'body': (7, 0, 5 * s), 'body.pos': (0, 0, 0), 'body.scale': (1.04, 1.04, 0.95), 'torso': (3, 0, -10 * s),
                'legU.L': (-26 * s, 0, 0), 'legU.R': (26 * s, 0, 0), 'legU.L.pos': (0, 0, 0), 'legU.R.pos': (0, 0, 0),
                'fist.L.ik': (0.46, 0.20 - 0.13 * s, 0.31 + 0.03), 'fist.R.ik': (-0.46, 0.20 + 0.13 * s, 0.31 + 0.03),
                'cap': (-2, 0, 0)}
    up = {'body.scale': (0.98, 0.98, 1.03)}
    c = clip('move', 24, [(0, contact(1)), (6, mg(step(1), up)), (12, contact(-1)), (18, mg(step(-1), up)),
                          (24, contact(1))], loop=True, base=REST)
    return fin(c, sk, g, k=0.8)


def attack(sk, g):
    """Puxa o punho direito para tras (0,4 s) e solta um direto. Acerto no quadro 15."""
    c = ck('attack', 32, [
        (3, {'body.scale': (0.97, 0.97, 1.04), 'torso': (5, 0, 6)}, 'o'),
        (10, {'body': (-7, 0, -12), 'body.pos': (0, -0.07, 0), 'body.scale': (1.08, 1.08, 0.90), 'torso': (-8, 0, -40),
              'cap': (-8, 0, 0), 'fist.R.ik': (-0.50, -0.10, 0.66), 'fist.R.scale': (1.2, 1.2, 1.2),
              'fist.L.ik': (0.24, 0.36, 0.54), 'legU.L': (-12, 0, 0), 'legU.R': (14, 0, 0)}, 'o'),
        (13, {'body': (-9, 0, -14), 'torso': (-10, 0, -44), 'fist.R.ik': (-0.52, -0.14, 0.68)}),
        (15, {'body': (12, 0, 12), 'body.pos': (0, 0.24, 0), 'body.scale': (0.95, 0.95, 1.06), 'torso': (16, 0, 38),
              'cap': (10, 0, 0), 'fist.R.ik': (-0.04, 0.62, 0.50), 'fist.R.scale': (1.55, 1.55, 1.55),
              'fist.L.ik': (0.50, -0.06, 0.50), 'legU.L': (22, 0, 0), 'legU.R': (-26, 0, 0)}, 'i'),
        (17, {'body.pos': (0, 0.27, 0), 'torso': (18, 0, 44), 'fist.R.scale': (1.25, 1.25, 1.25),
              'body.scale': (1.04, 1.04, 0.95)}, 'o'),
        (22, {'body': (8, 0, 8), 'body.pos': (0, 0.20, 0), 'torso': (12, 0, 30), 'fist.R.ik': (-0.14, 0.50, 0.48),
              'fist.R.scale': (1, 1, 1)}),
        (32, REST),
    ])
    eb.shake(c, 'torso', 9, 14, (0, 0, 3), freq=1.0)
    return fin(c, sk, g)


def attack2(sk, g):
    """Agacha, da uma cambalhota e crava o chapeu no chao (ataque em area). Acerto no quadro 24."""
    armsup = sym({'fist.L.ik': (0.50, 0.10, 0.80)})
    c = ck('attack2', 46, [
        (9, mg({'body.scale': (1.22, 1.22, 0.70), 'torso': (10, 0, 0), 'cap': (12, 0, 0)},
               sym({'fist.L.ik': (0.50, -0.16, 0.34), 'legU.L': (-10, 0, 0)})), 'o'),
        (12, {'body.scale': (1.26, 1.26, 0.66)}),
        (16, mg({'body': (40, 0, 0), 'body.pos': (0, 0.06, 0.55), 'body.scale': (0.86, 0.86, 1.24), 'torso': (-6, 0, 0),
                 'cap': (-8, 0, 0)}, armsup, sym({'legU.L': (30, 0, 0)})), 'o'),
        (21, {'body': (150, 0, 0), 'body.pos': (0, 0.20, 1.05), 'body.scale': (1, 1, 1), 'torso': (10, 0, 0)}, 'o'),
        (24, mg({'body': (180, 0, 0), 'body.pos': (0, 0.30, 0.78), 'body.scale': (1.22, 1.22, 0.70), 'cap': (0, 0, 0),
                 'cap.scale': (1.18, 1.18, 0.70), 'legU.L': (-34, 0, 0), 'legU.R': (30, 0, 0)},
                sym({'fist.L.ik': (0.56, 0.12, 0.44)})), 'i'),
        (27, {'body.scale': (0.96, 0.96, 1.05), 'cap.scale': (0.97, 0.97, 1.06), 'legU.L': (30, 0, 0),
              'legU.R': (-34, 0, 0)}, 'o'),
        (30, {'body': (184, 0, 0), 'body.scale': (1.08, 1.08, 0.90), 'cap.scale': (1.06, 1.06, 0.90),
              'legU.L': (-24, 0, 0), 'legU.R': (24, 0, 0)}),
        (35, mg({'body': (300, 0, 0), 'body.pos': (0, 0.14, 0.62), 'body.scale': (0.94, 0.94, 1.10),
                 'cap.scale': (1, 1, 1), 'legU.L': (10, 0, 0), 'legU.R': (10, 0, 0)}, armsup), 'o'),
        (39, mg({'body': (360, 0, 0), 'body.pos': (0, 0, 0), 'body.scale': (1.20, 1.20, 0.74), 'legU.L': (0, 0, 0),
                 'legU.R': (0, 0, 0)}, sym({'fist.L.ik': (0.50, 0.16, 0.30)})), 'i'),
        (46, mg(REST, {'body': (360, 0, 0)}), 'o'),
    ])
    eb.shake(c, 'body', 8, 13, (0, 0, 2.5), freq=1.0)
    return fin(c, sk, g, fit=(24, 30))


def hit(sk, g):
    c = ck('hit', 9, [
        (2, mg({'body': (-10, 0, 5), 'body.pos': (0, -0.07, 0), 'body.scale': (1.10, 1.10, 0.88), 'torso': (-22, 0, 10),
                'cap': (-14, 0, 6), 'legU.L': (14, 0, 0)}, sym({'fist.L.ik': (0.54, 0.14, 0.60)}), SHUT), 'o'),
        (5, mg({'body': (3, 0, -2), 'body.pos': (0, -0.03, 0), 'body.scale': (0.97, 0.97, 1.04), 'torso': (8, 0, -3),
                'cap': (6, 0, 0), 'legU.L': (0, 0, 0)}, sym({'fist.L.ik': (0.48, 0.22, 0.36)}))),
        (9, REST),
    ])
    return fin(c, sk, g, settle=3)


def die(sk, g):
    """Cambaleia para tras e cai de costas, apoiado no chapeu, de pernas para o ar."""
    limp = sym({'fist.L.ik': (0.50, -0.20, 0.50), 'fist.L': (0, 0, 30)})
    c = ck('die', 38, [
        (2, mg({'body': (-12, 0, 6), 'body.pos': (0, -0.08, 0), 'body.scale': (1.12, 1.12, 0.86), 'torso': (-24, 0, 12),
                'cap': (-14, 0, 8)}, sym({'fist.L.ik': (0.56, 0.10, 0.64)}), SHUT), 'o'),
        (9, {'body': (-22, 0, -6), 'body.pos': (0, -0.16, 0), 'body.scale': (0.98, 0.98, 1.03), 'torso': (-10, 0, -14),
             'legU.L': (-30, 0, 0), 'legU.R': (10, 0, 0), 'fist.L.ik': (0.50, 0.30, 0.70), 'fist.R.ik': (-0.56, -0.10, 0.40)}),
        (14, {'body': (-40, 0, 4), 'body.pos': (0, -0.22, 0), 'torso': (-6, 0, 8), 'legU.L': (10, 0, 0), 'legU.R': (-34, 0, 0),
              'fist.L.ik': (0.56, -0.10, 0.44), 'fist.R.ik': (-0.50, 0.30, 0.72)}),
        (21, mg({'body': (-108, 0, 6), 'body.pos': (0, -0.30, 0.30), 'body.scale': (1.08, 1.08, 0.90), 'torso': (6, 0, 0),
                 'cap': (10, 0, 0), 'legU.L': (-30, 0, 0), 'legU.R': (-22, 0, 0)}, limp), 'i'),
        (25, {'body': (-92, 0, 8), 'body.scale': (0.98, 0.98, 1.03), 'legU.L': (26, 0, 0), 'legU.R': (30, 0, 0)}, 'o'),
        (30, {'body': (-104, 0, 9), 'body.scale': (1.04, 1.04, 0.96), 'legU.L': (-6, 0, 0), 'legU.R': (12, 0, 0)}),
        (38, {'body': (-99, 0, 9), 'legU.L': (8, 0, 14), 'legU.R': (20, 0, 10), 'torso': (4, 0, 0)}),
    ])
    return fin(c, sk, g, fit=(19, 38), settle=0)


def spawn(sk, g):
    """Brota do chao como cogumelo: o chapeu aparece, treme, e o corpo salta para fora."""
    c = ck('spawn', 32, [
        (0, mg({'body.pos': (0, 0, -1.02), 'body.scale': (0.85, 0.85, 0.85)}, sym({'fist.L.ik': (0.34, 0.10, 0.36)}))),
        (6, {'body.pos': (0, 0, -0.66), 'body': (0, 5, 0), 'body.scale': (0.9, 0.9, 0.9)}, 'o'),
        (9, {'body.pos': (0, 0, -0.62), 'body': (0, -5, 0)}),
        (12, {'body.pos': (0, 0, -0.72), 'body': (0, 2, 0), 'body.scale': (1.0, 1.0, 0.86)}),
        (16, mg({'body.pos': (0, 0, 0.30), 'body': (0, 0, 0), 'body.scale': (0.86, 0.86, 1.26)},
                sym({'fist.L.ik': (0.56, 0.06, 0.78)})), 'o'),
        (18, {'body.pos': (0, 0, 0.32), 'body.scale': (0.97, 0.97, 1.05)}),
        (21, mg({'body.pos': (0, 0, 0), 'body.scale': (1.22, 1.22, 0.72)}, sym({'fist.L.ik': (0.52, 0.16, 0.28)})), 'i'),
        (25, mg({'body.scale': (0.95, 0.95, 1.08), 'torso': (-6, 0, 0)}, sym({'fist.L.ik': (0.40, 0.26, 0.62)})), 'o'),
        (32, REST),
    ])
    return fin(c, sk, g, f0=20)


def clips(sk, g):
    return [(idle(sk, g), None), (move(sk, g), None), (attack(sk, g), 15), (attack2(sk, g), 24), (hit(sk, g), None),
            (die(sk, g), None), (spawn(sk, g), None)]

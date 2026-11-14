"""hero_body.py: esqueleto compartilhado e pecas-base do heroi chibi.

Medidas em metros, Z para cima, olhando para -Y. Pose de repouso em T.
Todas as roupas e acessorios sao malhas separadas presas a ESTE esqueleto.
"""
import math

from mathutils import Vector

import lp
from lp import Geo, box, cone, cyl, ellipsoid, lathe, loft, merge, ring_pts, stack, tube

# ---------------------------------------------------------------- medidas
HEAD_C = Vector((0.0, 0.0, 1.005))     # centro da cabeca
HEAD_R = Vector((0.265, 0.245, 0.250))  # raios
NECK_Z = 0.755
SHOULDER = Vector((0.165, 0.0, 0.69))
ELBOW_X = 0.305
WRIST_X = 0.435
HAND_X = 0.495
HIP = Vector((0.085, 0.0, 0.405))
KNEE_Z = 0.235
ANKLE_Z = 0.085

BONES = [
    ('root', None, (0, 0, 0), (0, 0, 0.12)),
    ('hips', 'root', (0, 0, 0.40), (0, 0, 0.50)),
    ('spine', 'hips', (0, 0, 0.50), (0, 0, 0.60)),
    ('chest', 'spine', (0, 0, 0.60), (0, 0, 0.73)),
    ('head', 'chest', (0, 0, NECK_Z), (0, 0, 1.02)),
    ('eye.L', 'head', (0.105, -0.20, 0.975), (0.105, -0.20, 1.03)),
    ('eye.R', 'head', (-0.105, -0.20, 0.975), (-0.105, -0.20, 1.03)),
    ('hair1', 'head', (0, 0.20, 1.00), (0, 0.27, 0.82)),
    ('hair2', 'hair1', (0, 0.27, 0.82), (0, 0.30, 0.62)),
    ('hat1', 'head', (0, 0.0, 1.27), (0, 0.03, 1.45)),
    ('upper_arm.L', 'chest', tuple(SHOULDER), (ELBOW_X, 0, 0.69)),
    ('forearm.L', 'upper_arm.L', (ELBOW_X, 0, 0.69), (WRIST_X, 0, 0.69)),
    ('hand.L', 'forearm.L', (WRIST_X, 0, 0.69), (0.53, 0, 0.69)),
    ('weapon.L', 'hand.L', (HAND_X, 0, 0.69), (HAND_X, -0.12, 0.69)),
    ('upper_arm.R', 'chest', (-SHOULDER.x, 0, 0.69), (-ELBOW_X, 0, 0.69)),
    ('forearm.R', 'upper_arm.R', (-ELBOW_X, 0, 0.69), (-WRIST_X, 0, 0.69)),
    ('hand.R', 'forearm.R', (-WRIST_X, 0, 0.69), (-0.53, 0, 0.69)),
    ('weapon.R', 'hand.R', (-HAND_X, 0, 0.69), (-HAND_X, -0.12, 0.69)),
    ('thigh.L', 'hips', tuple(HIP), (0.09, 0, KNEE_Z)),
    ('shin.L', 'thigh.L', (0.09, 0, KNEE_Z), (0.09, 0, ANKLE_Z)),
    ('foot.L', 'shin.L', (0.09, 0, ANKLE_Z), (0.09, -0.13, 0.02)),
    ('thigh.R', 'hips', (-HIP.x, 0, HIP.z), (-0.09, 0, KNEE_Z)),
    ('shin.R', 'thigh.R', (-0.09, 0, KNEE_Z), (-0.09, 0, ANKLE_Z)),
    ('foot.R', 'shin.R', (-0.09, 0, ANKLE_Z), (-0.09, -0.13, 0.02)),
    ('cape1', 'chest', (0, 0.105, 0.70), (0, 0.14, 0.52)),
    ('cape2', 'cape1', (0, 0.14, 0.52), (0, 0.165, 0.34)),
    ('cape3', 'cape2', (0, 0.165, 0.34), (0, 0.18, 0.17)),
    ('tail1', 'hips', (0, 0.10, 0.43), (0, 0.25, 0.40)),
    ('tail2', 'tail1', (0, 0.25, 0.40), (0, 0.39, 0.47)),
]

# ossos animados por codigo no Godot (piscar): ficam fora das animacoes
CODE_BONES = ('eye.L', 'eye.R')

SHADE_LO = (0.74, 0.70, 0.80)   # leve escurecida fria na base das pecas


# ---------------------------------------------------------------- cabeca
def head_surface_y(x, z, front=True):
    """y da superficie da cabeca (elipsoide) em (x, z)."""
    u = (x - HEAD_C.x) / HEAD_R.x
    w = (z - HEAD_C.z) / HEAD_R.z
    k = max(0.0, 1.0 - u * u - w * w)
    y = HEAD_R.y * math.sqrt(k)
    return HEAD_C.y - y if front else HEAD_C.y + y


def head_warp(p):
    """Deixa o elipsoide com cara de cabeca chibi: bochechas cheias, queixo suave."""
    q = Vector(p)
    t = (q.z - HEAD_C.z) / HEAD_R.z  # -1 base .. 1 topo
    # bochechas: alarga um pouco abaixo do centro
    cheek = math.exp(-((t + 0.35) / 0.38) ** 2)
    q.x *= 1.0 + 0.07 * cheek
    # queixo: estreita o fundo
    if t < -0.55:
        k = (-(t + 0.55) / 0.45)
        q.x *= 1.0 - 0.16 * k
        q.y = HEAD_C.y + (q.y - HEAD_C.y) * (1.0 - 0.10 * k)
    # nuca um pouco mais cheia, rosto mais chato
    d = q.y - HEAD_C.y
    if d < 0:
        q.y = HEAD_C.y + d * 0.94
    return q


def decal(cx, cz, rx, rz, n=10, mat='eye', off=0.004, rot=0.0, color=lp.WHITE, squash_top=1.0):
    """Disco eliptico colado na frente da cabeca."""
    g = Geo()
    pts = []
    for i in range(n):
        a = lp.TAU * i / n
        px, pz = math.cos(a) * rx, math.sin(a) * rz
        if pz > 0:
            pz *= squash_top
        c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        px, pz = px * c - pz * s, px * s + pz * c
        pts.append((cx + px, cz + pz))
    ci = g.add_vert(_on_face(cx, cz, off), c=color)
    ids = [g.add_vert(_on_face(x, z, off), c=color) for x, z in pts]
    for i in range(n):
        g.add_face((ci, ids[i], ids[(i + 1) % n]), mat)
    return g


def _on_face(x, z, off):
    p = head_warp(Vector((x, head_surface_y(x, z), z)))
    # normal aproximada do elipsoide
    nrm = Vector(((p.x - HEAD_C.x) / HEAD_R.x ** 2, (p.y - HEAD_C.y) / HEAD_R.y ** 2, (p.z - HEAD_C.z) / HEAD_R.z ** 2))
    nrm.normalize()
    return p + nrm * off


def strip_decal(pts, width, mat='eye', off=0.005, color=lp.WHITE):
    """Faixa fina colada no rosto seguindo pontos (x, z): sobrancelha, boca."""
    g = Geo()
    top, bot = [], []
    for i, (x, z) in enumerate(pts):
        w = width if isinstance(width, (int, float)) else width[i]
        top.append(g.add_vert(_on_face(x, z + w / 2, off), c=color))
        bot.append(g.add_vert(_on_face(x, z - w / 2, off), c=color))
    for i in range(len(pts) - 1):
        g.add_face((bot[i], bot[i + 1], top[i + 1], top[i]), mat)
    return g


def make_head():
    g = ellipsoid(HEAD_R.x, HEAD_R.y, HEAD_R.z, n=12, rings=8, mat='skin', center=tuple(HEAD_C))
    g.warp(head_warp)
    g.grad('z', HEAD_C.z - HEAD_R.z, HEAD_C.z - 0.05, (0.90, 0.80, 0.82), lp.WHITE)
    # pescoco curtinho
    neck = stack([(0.715, 0.055, 0.05), (NECK_Z + 0.03, 0.06, 0.055)], 8, 'skin', cap_a=False, cap_b=False)
    neck.color((0.82, 0.72, 0.76))
    g.add(neck)
    g.bind('head')
    return g


def make_ears_human():
    e = ellipsoid(0.03, 0.045, 0.06, n=6, rings=4, mat='skin', center=(0.268, 0.02, 0.975))
    e.color((0.95, 0.86, 0.86))
    return e.both().bind('head')


EYE_STYLES = ('round', 'sharp', 'sleepy', 'dot', 'happy')
EYE_X = 0.108
EYE_Z = 0.972


def make_face(style='round'):
    """Olhos (presos aos ossos eye.L/R para piscar), sobrancelhas, boca e blush."""
    g = Geo()
    for side in (1, -1):
        bone = 'eye.L' if side > 0 else 'eye.R'
        cx = EYE_X * side
        e = Geo()
        if style == 'round':
            e.add(decal(cx, EYE_Z, 0.043, 0.062, 12, 'eye', 0.004))
            e.add(decal(cx, EYE_Z - 0.022, 0.030, 0.034, 10, 'iris', 0.006, squash_top=0.75))
            e.add(decal(cx - 0.014, EYE_Z + 0.026, 0.014, 0.017, 8, 'white', 0.008))
            e.add(decal(cx + 0.016, EYE_Z - 0.034, 0.007, 0.008, 6, 'white', 0.008))
        elif style == 'sharp':
            e.add(decal(cx, EYE_Z, 0.050, 0.050, 12, 'eye', 0.004, rot=-12 * side, squash_top=0.55))
            e.add(decal(cx, EYE_Z - 0.016, 0.030, 0.028, 10, 'iris', 0.006, squash_top=0.6))
            e.add(decal(cx - 0.016, EYE_Z + 0.010, 0.012, 0.012, 8, 'white', 0.008))
        elif style == 'sleepy':
            e.add(decal(cx, EYE_Z - 0.008, 0.046, 0.048, 12, 'eye', 0.004, squash_top=0.35))
            e.add(decal(cx, EYE_Z - 0.024, 0.028, 0.026, 10, 'iris', 0.006, squash_top=0.5))
            e.add(decal(cx - 0.014, EYE_Z - 0.002, 0.010, 0.010, 8, 'white', 0.008))
        elif style == 'dot':
            e.add(decal(cx, EYE_Z - 0.004, 0.030, 0.040, 10, 'eye', 0.004))
            e.add(decal(cx - 0.009, EYE_Z + 0.012, 0.010, 0.012, 8, 'white', 0.007))
        elif style == 'happy':
            pts = [(cx + side * 0.0 + dx, EYE_Z - 0.012 + 0.030 * math.cos(dx / 0.046 * math.pi / 2))
                   for dx in (-0.046, -0.028, -0.010, 0.010, 0.028, 0.046)]
            e.add(strip_decal(pts, [0.008, 0.018, 0.022, 0.022, 0.018, 0.008], 'eye', 0.005))
        e.bind(bone)
        g.add(e)
        # sobrancelha (cor do cabelo)
        bz = EYE_Z + (0.088 if style != 'sleepy' else 0.075)
        tilt = {'sharp': -0.016, 'sleepy': 0.010}.get(style, 0.004)
        brow = strip_decal([(cx - 0.040 * side, bz + tilt), (cx, bz + 0.010), (cx + 0.042 * side, bz - tilt * 0.3)],
                           [0.012, 0.016, 0.010], 'hair', 0.005)
        if side < 0:
            brow.f = [tuple(reversed(f)) for f in brow.f]
        g.add(brow.bind('head'))
        # blush
        bl = decal(cx + 0.045 * side, EYE_Z - 0.085, 0.036, 0.020, 8, 'skin', 0.003, color=(1.0, 0.66, 0.66))
        g.add(bl.bind('head'))
    # boca: sorrisinho
    mz = EYE_Z - 0.108
    mouth = strip_decal([(-0.028, mz + 0.010), (-0.012, mz), (0.012, mz), (0.028, mz + 0.010)],
                        [0.006, 0.012, 0.012, 0.006], 'mouth', 0.005)
    g.add(mouth.bind('head'))
    return g


# ---------------------------------------------------------------- maos
def make_hand(mat='skin'):
    """Mao 'luva' esquerda (em T, palma para baixo)."""
    g = ellipsoid(0.062, 0.052, 0.045, n=8, rings=5, mat=mat, center=(HAND_X + 0.005, 0, 0.69))
    thumb = ellipsoid(0.026, 0.034, 0.024, n=6, rings=4, mat=mat, center=(HAND_X - 0.012, -0.050, 0.685))
    g.add(thumb)
    g.grad('x', WRIST_X, HAND_X + 0.07, (0.86, 0.78, 0.80), lp.WHITE)
    g.bind('hand.L')
    return g


def make_hands(mat='skin'):
    return make_hand(mat).both()


# ---------------------------------------------------------------- tronco / bracos / pernas
def torso_rings(belly=1.0, chest=1.0, hip=1.0, zlo=0.385, ztop=0.735):
    """Secoes padrao do tronco (z, rx, ry, cx, cy, square)."""
    return [
        (zlo, 0.112 * hip, 0.092 * hip, 0, 0.004, 0.25),
        (0.44, 0.136 * hip, 0.108 * hip, 0, 0.004, 0.2),
        (0.52, 0.128 * belly, 0.102 * belly, 0, 0.0, 0.2),
        (0.61, 0.138 * chest, 0.104 * chest, 0, -0.002, 0.25),
        (0.685, 0.130 * chest, 0.094 * chest, 0, 0.0, 0.3),
        (ztop, 0.068, 0.060, 0, 0.0, 0.0),
    ]


TORSO_W = [(0.40, 'hips'), (0.50, 'spine'), (0.60, 'chest')]


def bind_torso(g):
    return g.bind_axis('z', [(0.43, 'hips'), (0.52, 'spine'), (0.62, 'chest')])


def make_torso(mat='primary', n=10, **kw):
    g = stack(torso_rings(**kw), n, mat, cap_a=True, cap_b=True)
    g.grad('z', 0.385, 0.70, SHADE_LO, lp.WHITE)
    return bind_torso(g)


def arm_weights(p):
    x = abs(p.x)
    if x < ELBOW_X - 0.03:
        return {'upper_arm.L': 1.0}
    if x < ELBOW_X + 0.03:
        t = (x - (ELBOW_X - 0.03)) / 0.06
        return {'upper_arm.L': 1.0 - t, 'forearm.L': t}
    return {'forearm.L': 1.0}


def make_arm(mat_upper='skin', mat_fore='skin', r0=0.050, r1=0.044, r2=0.050, n=8, x0=None, split=None):
    """Braco esquerdo em T. split: x onde troca do material de cima para o de baixo."""
    x0 = SHOULDER.x - 0.03 if x0 is None else x0
    z = 0.69
    xs = [x0, SHOULDER.x + 0.035, ELBOW_X - 0.03, ELBOW_X, ELBOW_X + 0.03, WRIST_X - 0.02, WRIST_X + 0.012]
    rs = [r0 * 0.62, r0, r1 * 1.02, r1, r1 * 1.02, r2, r2 * 0.92]
    split = split if split is not None else ELBOW_X
    g = Geo()

    def seg(lo, hi, mat):
        pts = [(x, r) for x, r in zip(xs, rs) if lo - 1e-6 <= x <= hi + 1e-6]
        rings = [[(x, a, z + b) for a, b in ring_pts(n, r, r)] for x, r in pts]
        # anel no plano YZ: ordem que deixa a normal para fora quando x cresce
        rings = [list(reversed(r)) for r in rings]
        return loft(rings, mat, cap_a=True, cap_b=True)
    if mat_upper == mat_fore:
        g.add(seg(xs[0], xs[-1], mat_upper))
    else:
        g.add(seg(xs[0], split, mat_upper))
        g.add(seg(split, xs[-1], mat_fore))
    g.grad('x', x0, WRIST_X, lp.WHITE, (0.88, 0.84, 0.90))
    g.bind_fn(arm_weights)
    return g


def leg_weights(p):
    z = p.z
    if z > KNEE_Z + 0.03:
        return {'thigh.L': 1.0}
    if z > KNEE_Z - 0.03:
        t = (KNEE_Z + 0.03 - z) / 0.06
        return {'thigh.L': 1.0 - t, 'shin.L': t}
    if z > ANKLE_Z + 0.01:
        return {'shin.L': 1.0}
    return {'foot.L': 1.0}


def make_leg(mat_thigh='secondary', mat_shin='secondary', r_hip=0.066, r_knee=0.056, r_ankle=0.056, n=8,
             z_top=0.41, z_bot=None, split=None):
    """Perna esquerda (sem o pe)."""
    cx = 0.088
    z_bot = ANKLE_Z - 0.01 if z_bot is None else z_bot
    secs = [(z_bot, r_ankle * 0.96), (ANKLE_Z + 0.03, r_ankle), (KNEE_Z - 0.03, r_knee * 1.02), (KNEE_Z, r_knee),
            (KNEE_Z + 0.03, r_knee * 1.04), (0.35, r_hip), (z_top, r_hip * 0.72)]
    split = KNEE_Z if split is None else split

    def seg(lo, hi, mat):
        s = [(z, r, r, cx + (0.004 if z > 0.3 else 0.0), 0.0) for z, r in secs if lo - 1e-6 <= z <= hi + 1e-6]
        return stack(s, n, mat)
    g = Geo()
    if mat_thigh == mat_shin:
        g.add(seg(secs[0][0], secs[-1][0], mat_thigh))
    else:
        g.add(seg(secs[0][0], split, mat_shin))
        g.add(seg(split, secs[-1][0], mat_thigh))
    g.grad('z', z_bot, 0.43, SHADE_LO, lp.WHITE)
    g.bind_fn(leg_weights)
    return g


def make_foot(mat='leather', length=0.20, width=0.066, height=0.075, toe_up=0.012, n=8):
    """Pe/bota esquerda: forma de 'feijao' com bico arredondado."""
    cx = 0.09
    # secoes ao longo de Y (do calcanhar ao bico), cada uma um anel no plano XZ
    ys = [0.062, 0.045, 0.0, -0.06, -0.105, -0.135]
    ws = [0.60, 0.92, 1.0, 1.06, 0.92, 0.50]
    hs = [0.70, 1.0, 1.0, 0.80, 0.62, 0.36]
    rings = []
    for y, w, h in zip(ys, ws, hs):
        ring = []
        for a, b in ring_pts(n, width * w, height * h * 0.5, 0.35):
            zc = height * h * 0.5 + (toe_up if y < -0.09 else 0.0)
            ring.append((cx + a, y, zc + b))
        rings.append(ring)
    g = loft(rings, mat)
    # sola achatada no chao
    g.warp(lambda p: Vector((p.x, p.y, max(p.z, 0.004))))
    g.grad('z', 0.0, height, (0.66, 0.62, 0.72), lp.WHITE)
    g.bind('foot.L')
    return g


def make_boot_cuff(mat='leather', z=0.15, r=0.068, h=0.045, flare=1.12, n=8):
    g = stack([(z, r, r, 0.09, 0), (z + h, r * flare, r * flare, 0.09, 0), (z + h, r * flare * 0.86, r * flare * 0.86, 0.09, 0)],
              n, mat, cap_a=False, cap_b=False)
    g.bind('shin.L')
    return g

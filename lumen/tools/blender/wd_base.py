"""wd_base.py: registro de pecas trocaveis do heroi e ajudantes de modelagem compartilhados.

Cada peca e uma funcao decorada com @piece(slot, nome, rotulo, **meta) que devolve uma Geo
ja com materiais e pesos (ou uma tupla (base, topo) no caso de cabelos: o "topo" e o volume
que some quando um chapeu com hair='flat' esta equipado).

Slots: hair, hat, ears, acc, top, bottom, back, weapon.
Meta comuns: rarity (0 comum .. 3 lendario), cost (moedas; 0 = ja vem liberado),
             hair ('keep' | 'flat' | 'hide') para chapeus, cls para armas.
"""
import math

from mathutils import Vector

import lp
from lp import Geo, box, cone, cyl, ellipsoid, icosphere, lathe, loft, merge, poly_extrude, ring_pts, sheet, stack, tube
import hero_body as hb
from hero_body import HEAD_C, HEAD_R

PIECES = {}


def piece(slot, name, label, **meta):
    def deco(fn):
        meta.setdefault('rarity', 0)
        meta.setdefault('cost', 0)
        PIECES[name] = dict(slot=slot, fn=fn, label=label, **meta)
        return fn
    return deco


# ================================================================= ajudantes de cabelo
def scalp(x, y, z, k=1.07):
    """Projeta uma direcao a partir do centro da cabeca ate a casca do cabelo."""
    d = Vector((x, y, z)) - HEAD_C
    d = Vector((d.x / HEAD_R.x, d.y / HEAD_R.y, d.z / HEAD_R.z))
    if d.length < 1e-6:
        d = Vector((0, 0, 1))
    d.normalize()
    return hb.head_warp(HEAD_C + Vector((d.x * HEAD_R.x, d.y * HEAD_R.y, d.z * HEAD_R.z)) * 1.0) * 1.0 + \
        Vector((d.x * HEAD_R.x, d.y * HEAD_R.y, d.z * HEAD_R.z)) * (k - 1.0)


def hair_cap(front=0.115, back=-0.21, side=-0.02, k=1.07, n=12, rings=8):
    """Casca do cabelo: elipsoide da cabeca inflado, cortado na linha do cabelo.
    front/back/side: altura da linha (relativa ao centro) na testa, na nuca e nas temporas."""
    g = ellipsoid(HEAD_R.x, HEAD_R.y, HEAD_R.z, n=n, rings=rings, mat='hair', center=tuple(HEAD_C))
    g.warp(hb.head_warp)
    g.warp(lambda p: HEAD_C + (p - HEAD_C) * k)

    def line(c):
        a = math.atan2(c.x - HEAD_C.x, -(c.y - HEAD_C.y))  # 0 = frente, pi = nuca
        t = abs(a) / math.pi
        if t < 0.5:
            u = t / 0.5
            u = u * u * (3 - 2 * u)
            h = front + (side - front) * u
        else:
            u = (t - 0.5) / 0.5
            u = u * u * (3 - 2 * u)
            h = side + (back - side) * u
        return c.z - HEAD_C.z > h
    g.keep_faces(line)
    return g


def tuft(p0, p1, p2, w=0.05, th=0.03, n=5, segs=4, mat='hair', tip=0.12, up=None):
    """Mecha: tubo achatado numa curva de Bezier quadratica, afinando ate a ponta."""
    p0, p1, p2 = Vector(p0), Vector(p1), Vector(p2)
    path, radii = [], []
    for i in range(segs + 1):
        t = i / segs
        path.append((1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2)
        k = (1.0 - t) ** 0.8 * (1.0 - tip) + tip
        if i == 0:
            k *= 0.8
        radii.append((w * k, th * k))
    if up is None:
        up = (p0 - HEAD_C).normalized()
    return tube(path, radii, n, mat, up=tuple(up))


def hair_shade(g):
    b0, b1 = g.bounds()
    g.grad('z', b0[2], b1[2], (0.70, 0.66, 0.80), (1.06, 1.04, 1.0))
    return g



# ================================================================= ajudantes de roupa e arma
def skirt_weights(zlo, zhi):
    def fn(p):
        t = max(0.0, min(1.0, (zhi - p.z) / (zhi - zlo)))
        side = max(0.0, min(1.0, abs(p.x) / 0.10)) * t * 0.6
        if side < 0.02:
            return {'hips': 1.0}
        return {'hips': 1.0 - side, ('thigh.L' if p.x > 0 else 'thigh.R'): side}
    return fn


def belt(z=0.455, rx=0.142, ry=0.114, h=0.036, mat='leather', buckle=True, n=10):
    g = stack([(z - h / 2, rx, ry, 0, 0.003, 0.2), (z + h / 2, rx * 0.985, ry * 0.985, 0, 0.003, 0.2)], n, mat,
              cap_a=False, cap_b=False)
    # borda grossa: fecha por dentro
    if buckle:
        b = box(0.05, 0.02, 0.05, 'vcol', center=(0, -ry - 0.004, z)).color(lp.hexc('#f4c542'))
        b2 = box(0.026, 0.024, 0.026, 'vcol', center=(0, -ry - 0.006, z)).color(lp.hexc('#8a5a22'))
        g.add(b).add(b2)
    return g.bind('hips')



def to_hand(g, side='R'):
    """Leva uma arma modelada na origem (cabo em Z, ponta para +Z) ate a mao em T."""
    g.rot('X', 90)
    x = -hb.HAND_X if side == 'R' else hb.HAND_X
    g.move(x, 0, 0.69)
    return g.bind('weapon.' + side)


# ================================================================= pecas de referencia
# Usadas como roupa padrao nos previews e como as pecas iniciais do jogo. NAO editar aqui.
def ref_top():
    g = hb.make_torso('primary')
    # saiote da tunica
    sk = stack([(0.325, 0.172, 0.142, 0, 0.004, 0.15), (0.39, 0.156, 0.126, 0, 0.004, 0.15),
                (0.455, 0.140, 0.112, 0, 0.003, 0.2)], 10, 'primary', cap_a=True, cap_b=False)
    sk.grad('z', 0.325, 0.455, (0.70, 0.66, 0.78), lp.WHITE)
    sk.bind_fn(skirt_weights(0.325, 0.455))
    g.add(sk)
    # barra clara do saiote
    hem = stack([(0.322, 0.176, 0.146, 0, 0.004, 0.15), (0.345, 0.171, 0.141, 0, 0.004, 0.15)], 10, 'secondary',
                cap_a=False, cap_b=False)
    hem.bind_fn(skirt_weights(0.325, 0.455))
    g.add(hem)
    g.add(belt())
    # gola
    col = stack([(0.705, 0.105, 0.085, 0, 0.0, 0.2), (0.745, 0.082, 0.072, 0, 0.004, 0.1)], 10, 'secondary',
                cap_a=False, cap_b=False)
    g.add(col.bind('chest'))
    # mangas curtas + antebraco na pele
    arm = hb.make_arm('primary', 'skin', r0=0.058, r1=0.046, r2=0.048, split=hb.ELBOW_X - 0.035)
    cuff = lp.loft([[(x, a, 0.69 + b) for a, b in reversed(ring_pts(8, r, r))] for x, r in
                    ((hb.ELBOW_X - 0.06, 0.060), (hb.ELBOW_X - 0.03, 0.063))], 'secondary', cap_a=False, cap_b=True)
    cuff.bind('upper_arm.L')
    arm.add(cuff)
    g.add(arm.both())
    return g



def ref_bottom():
    leg = hb.make_leg('secondary', 'leather', split=0.205, r_ankle=0.062, r_knee=0.058)
    leg.add(hb.make_foot('leather'))
    leg.add(hb.make_boot_cuff('leather', z=0.185, r=0.066, h=0.04))
    return leg.both()



def ref_hair():
    g = hair_cap(front=0.13, back=-0.20, side=-0.03)
    top = Geo()
    z0 = HEAD_C.z
    # franja: mechas descendo pela testa
    fr = [(-0.15, 0.10, -0.19, 0.050), (-0.075, 0.03, -0.085, 0.060), (0.0, -0.04, 0.03, 0.062),
          (0.085, 0.02, 0.11, 0.058), (0.16, 0.09, 0.20, 0.048)]
    for x0, dz, x2, w in fr:
        r = scalp(x0, -0.5, z0 + 0.34, 1.08)
        tipz = z0 + 0.035 + dz * 0.5
        tp = Vector((x2, hb.head_surface_y(x2 * 0.9, tipz) - 0.030, tipz))
        mid = (r + tp) / 2 + Vector((0, -0.05, 0.035))
        g.add(tuft(r, mid, tp, w, 0.026))
    # costeletas
    for s in (1, -1):
        r = scalp(0.24 * s, -0.12, z0 + 0.08, 1.07)
        g.add(tuft(r, r + Vector((0.035 * s, -0.02, -0.08)), Vector((0.235 * s, -0.10, z0 - 0.15)), 0.042, 0.026))
    # espetos na nuca e no topo
    sp = [(0.0, 0.26, 0.20, 0.0, 0.36, 0.30, 0.07), (0.14, 0.22, 0.14, 0.23, 0.33, 0.20, 0.06),
          (-0.14, 0.22, 0.14, -0.23, 0.33, 0.20, 0.06), (0.09, 0.20, -0.06, 0.15, 0.34, -0.10, 0.058),
          (-0.09, 0.20, -0.06, -0.15, 0.34, -0.10, 0.058), (0.0, 0.18, -0.14, 0.0, 0.30, -0.21, 0.06),
          (0.05, -0.02, 0.26, 0.10, -0.06, 0.37, 0.05), (-0.10, 0.06, 0.25, -0.17, 0.08, 0.34, 0.045)]
    for x0, y0, dz0, x2, y2, dz2, w in sp:
        r = scalp(x0, y0, z0 + dz0, 1.03)
        tp = Vector((x2, y2, z0 + dz2))
        mid = (r + tp) / 2 + Vector((0, 0.0, 0.04))
        (top if dz0 > 0.1 else g).add(tuft(r, mid, tp, w * 1.25, w * 0.8, n=5, segs=3))
    return hair_shade(g).bind('head'), hair_shade(top).bind('head')


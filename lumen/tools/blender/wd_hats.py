"""wd_hats.py: chapeus.

Todo chapeu e modelado em pe sobre a cabeca e depois inclinado um pouco para tras (frente mais
alta). A boca do chapeu tem raio interno >= cabeca x 1,12 e um labio para dentro, para nao
aparecer fresta nem o avesso; o que o cabelo tiver acima dessa linha fica no "topo" dele.
"""
import math

from mathutils import Vector

import lp
from lp import Geo, box, cone, cyl, ellipsoid, icosphere, lathe, loft, merge, poly_extrude, ring_pts, sheet, stack, tube
import hero_body as hb
from hero_body import HEAD_C, HEAD_R
import wd_base
from wd_base import piece
from wd_hair import hpt, hz, volta, casca, mecha, bez, _ss, FOLHA, GOTA, ESPINHO

FRIO = (0.70, 0.66, 0.82)          # sombra fria padrao
OURO = lp.hexc('#f4c542')
OURO_ESC = lp.hexc('#c98a25')
PALHA = lp.hexc('#ecca72')
PALHA_ESC = lp.hexc('#c99a45')
TILT = -7.0                        # graus em X: frente do chapeu mais alta que a nuca


# ================================================================= ajudantes
def Z(h):
    return HEAD_C.z + h


def fit(h, k=1.12):
    """Raios (rx, ry) da cabeca inflada por k na altura h (metros acima do centro)."""
    s = math.sqrt(max(0.0, 1.0 - (h / (HEAD_R.z * k)) ** 2))
    return HEAD_R.x * k * s, HEAD_R.y * k * s


def S(h, k, dz=0.0, cy=0.0):
    """Secao de stack colada na cabeca inflada por k."""
    rx, ry = fit(h, k)
    return (Z(h) + dz, rx, ry, 0.0, cy)


def tilt(g, deg=TILT):
    return g.rot('X', deg, pivot=tuple(HEAD_C))


def aponta(g, p, d):
    """Vira o +Z da peca para a direcao d e leva ate p."""
    g.xf(Vector((0, 0, 1)).rotation_difference(Vector(d).normalized()).to_matrix().to_4x4())
    return g.move(*p)


def az_of(p):
    return math.atan2(p.x, -(p.y - HEAD_C.y))


def pinta(az, el, k, r, mat, n=6, color=lp.WHITE):
    """Bolinha/remendo colado numa cupula (az, el em graus)."""
    c = hpt(az, el, k)
    nrm = (c - HEAD_C).normalized()
    t1 = nrm.cross(Vector((0, 0, 1)))
    t1 = t1.normalized() if t1.length > 1e-4 else Vector((1, 0, 0))
    t2 = nrm.cross(t1)
    g = Geo()
    ci = g.add_vert(c + nrm * 0.002, c=color)
    ids = [g.add_vert(c + (t1 * math.cos(lp.TAU * i / n) + t2 * math.sin(lp.TAU * i / n)) * r - nrm * (r * r / 0.5),
                      c=color) for i in range(n)]
    for i in range(n):
        g.add_face((ci, ids[i], ids[(i + 1) % n]), mat)
    return g


def toro(R, r, n=12, m=5, mat='vcol'):
    """Anel (toro) deitado no plano XY."""
    return lathe([(R + r * math.cos(lp.TAU * i / m), r * math.sin(lp.TAU * i / m)) for i in range(m + 1)], n, mat)


def estrelinha(r=0.03, mat='vcol'):
    """Brilho de seis pontas: tres losangos cruzados."""
    g = Geo()
    for ax, deg in (('X', 0), ('X', 90), ('Y', 90)):
        d = lathe([(0.0, -r), (r * 0.26, 0.0), (0.0, r)], 4, mat, smooth=False)
        g.add(d.rot(ax, deg))
    return g


def flor(r=0.05, mat='accent', miolo=OURO, petalas=5):
    """Flor chapada de petalas arredondadas, virada para +Z, com miolo em cupula."""
    g = Geo()
    ci = g.add_vert((0, 0, r * 0.22))
    ring = []
    for i in range(petalas):
        a = lp.TAU * i / petalas
        for da, rr, zz in ((-0.50, 0.40, r * 0.12), (-0.20, 1.0, 0.0), (0.20, 1.0, 0.0)):
            b = a + da * lp.TAU / petalas
            ring.append(g.add_vert((math.cos(b) * r * rr, math.sin(b) * r * rr, zz)))
    n = len(ring)
    for i in range(n):
        g.add_face((ci, ring[i], ring[(i + 1) % n]), mat)
    g.grad('z', 0.0, r * 0.22, (0.80, 0.74, 0.86), lp.WHITE)
    c = lathe([(r * 0.30, r * 0.10), (r * 0.22, r * 0.30), (0.0, r * 0.38)], 6, 'vcol').color(miolo)
    return g.add(c)


def folha(p0, p1, p2, w=0.03, cor=lp.hexc('#5fa052')):
    f = mecha([p0, p1, p2], w, 0.006, n=4, segs=2, prof=[(0.0, 0.25), (0.5, 1.0), (1.0, 0.08)], mat='vcol')
    return f.color(cor)


def aba(n, r_in, r_out, z, th=0.014, mat_top='primary', mat_bot='primary', mid=None, droop=0.0, top_in=None):
    """Aba plana com espessura: (baixo, topo), aneis elipticos. r_* = (rx, ry)."""
    mid = mid or ((r_in[0] + r_out[0]) / 2, (r_in[1] + r_out[1]) / 2)
    top_in = top_in or r_in
    bot = stack([(z - th, r_in[0], r_in[1]), (z - th - droop * 0.5, mid[0], mid[1]),
                 (z - th - droop, r_out[0], r_out[1]), (z - droop, r_out[0] + 0.004, r_out[1] + 0.004)], n, mat_bot,
                cap_a=False, cap_b=False)
    bot.color(FRIO)
    top = stack([(z - droop, r_out[0] + 0.004, r_out[1] + 0.004), (z - droop * 0.5 + 0.002, mid[0], mid[1]),
                 (z + 0.004, top_in[0], top_in[1])], n, mat_top, cap_a=False, cap_b=False)
    return bot, top


def labio(h0, k, n, mat, dz=-0.012):
    """Fecha a boca do chapeu por baixo, da borda ate dentro da cabeca."""
    return stack([S(h0, 0.93, dz), S(h0, k, dz)], n, mat, cap_a=False, cap_b=False).color(FRIO)


# ================================================================= pecas
@piece('hat', 'hat_gorro', 'Gorro de Lã', hair='flat')
def hat_gorro():
    h0 = 0.10
    barra = stack([S(h0, 0.93, -0.014), S(h0 - 0.012, 1.175, -0.010), S(h0 + 0.025, 1.195), S(h0 + 0.062, 1.185),
                   S(h0 + 0.070, 1.13)], 12, 'secondary', cap_a=False, cap_b=False)

    # canelado: colunas alternadas mais escuras
    def rib(p, c):
        k = 0.5 + 0.5 * math.cos(6 * az_of(p))
        m = lp.mixc((0.78, 0.74, 0.88), lp.WHITE, k)
        return (c[0] * m[0], c[1] * m[1], c[2] * m[2])
    barra.tint(rib)
    corpo = stack([S(h0 + 0.062, 1.135), (Z(0.215), 0.214, 0.198), (Z(0.268), 0.168, 0.156, 0, 0.012),
                   (Z(0.318), 0.110, 0.102, 0, 0.032), (Z(0.348), 0.052, 0.050, 0, 0.048)], 12, 'primary',
                  cap_a=False, cap_b=True)
    corpo.grad('z', Z(0.14), Z(0.35), FRIO, lp.WHITE)
    pom = icosphere(0.062, 1, 'secondary', center=(0, 0.062, Z(0.385)), jitter=0.05, seed=3, smooth=True)
    pom.grad('z', Z(0.33), Z(0.44), (0.78, 0.74, 0.88), lp.WHITE)
    g = merge(barra, corpo, pom)
    return tilt(g).bind('head')


@piece('hat', 'hat_bandana', 'Bandana', hair='flat')
def hat_bandana():
    half = [(0, 0.128), (25, 0.125), (50, 0.110), (75, 0.085), (100, 0.055), (125, 0.022), (150, -0.008),
            (180, -0.020)]
    b = volta(half)
    g = casca(b, k=1.118, rows=5, edge=0.975, mat='primary')
    g.grad('z', Z(-0.02), Z(0.28), FRIO, lp.WHITE)
    # dobra enrolada na borda
    path = [hz(az, h + 0.016, 1.135) for az, h in b]
    path.append(path[0])
    rolo = tube(path, (0.013, 0.024), 5, 'primary', cap_a=False, cap_b=False, up=(0, 0, 1))
    rolo.color((0.80, 0.76, 0.90))
    g.add(rolo)
    for az, el, r in ((0, 56, 0.036), (62, 50, 0.032), (-62, 50, 0.032), (122, 44, 0.034), (-122, 44, 0.034),
                      (180, 52, 0.032), (20, 84, 0.030)):
        g.add(pinta(az, el, 1.124, r, 'secondary'))
    # no e pontas atras
    kn = hz(168, -0.004, 1.17)
    g.add(ellipsoid(0.040, 0.034, 0.034, n=7, rings=4, mat='primary', center=tuple(kn)).color((0.80, 0.76, 0.90)))
    pano = [(0.0, 0.45), (0.7, 1.0), (1.0, 0.70)]
    g.add(mecha([kn, kn + Vector((0.07, 0.07, -0.02)), kn + Vector((0.10, 0.09, -0.15))], 0.046, 0.010, n=4, segs=3,
                prof=pano, up=(0, 1, 0), mat='primary'))
    g.add(mecha([kn, kn + Vector((-0.02, 0.09, -0.03)), kn + Vector((-0.03, 0.10, -0.19))], 0.042, 0.010, n=4,
                segs=3, prof=pano, up=(0, 1, 0), mat='primary'))
    return g.bind('head')


@piece('hat', 'hat_palha', 'Chapéu de Palha', hair='flat')
def hat_palha():
    h0, n = 0.115, 14
    bot, top = aba(n, fit(h0, 1.12), (0.470, 0.455), Z(h0), th=0.014, mat_top='vcol', mat_bot='vcol', droop=0.016,
                   top_in=fit(h0, 1.15))
    copa = stack([S(h0, 1.15, 0.004), (Z(0.205), 0.238, 0.220), (Z(0.262), 0.205, 0.190), (Z(0.290), 0.130, 0.120)],
                 n, 'vcol', cap_a=False, cap_b=True)
    g = merge(labio(h0, 1.12, n, 'vcol', -0.014), bot, top, copa)

    def cor(p, c):
        r = math.hypot(p.x, p.y - HEAD_C.y)
        k = 0.5 + 0.5 * math.cos(r * 60.0)
        m = lp.mixc(PALHA_ESC, PALHA, 0.35 + 0.65 * k)
        return (c[0] * m[0], c[1] * m[1], c[2] * m[2])
    g.tint(cor)

    # aba mole e desfiada: ondula e alterna o raio na beirada
    def mole(p):
        r = math.hypot(p.x, p.y - HEAD_C.y)
        t = _ss((r - 0.30) / 0.17)
        a = az_of(p)
        q = Vector(p)
        q.z += 0.022 * math.sin(2 * a + 0.7) * t
        if r > 0.44:
            s = 1.0 + 0.030 * math.cos(n / 2 * a)
            q.x *= s
            q.y *= s
        return q
    g.warp(mole)
    # fita
    faixa = stack([(Z(h0 + 0.010), 0.262, 0.244), (Z(h0 + 0.012), 0.286, 0.265), (Z(h0 + 0.060), 0.270, 0.250),
                   (Z(h0 + 0.062), 0.246, 0.228)], n, 'primary', cap_a=False, cap_b=False)
    g.add(faixa)
    kn = Vector((0.07, 0.262, Z(h0 + 0.036)))
    pano = [(0.0, 0.5), (0.7, 1.0), (1.0, 0.75)]
    g.add(mecha([kn, kn + Vector((0.05, 0.08, 0.00)), kn + Vector((0.07, 0.17, -0.035))], 0.034, 0.008, n=4, segs=3,
                prof=pano, up=(0, 0, 1), mat='primary'))
    g.add(mecha([kn, kn + Vector((-0.02, 0.09, 0.00)), kn + Vector((-0.05, 0.16, -0.030))], 0.030, 0.008, n=4,
                segs=3, prof=pano, up=(0, 0, 1), mat='primary'))
    return tilt(g).bind('head')


@piece('hat', 'hat_mago', 'Chapéu de Mago', rarity=1, cost=220, hair='flat')
def hat_mago():
    h0, n = 0.115, 12
    bot, top = aba(n, fit(h0, 1.12), (0.500, 0.485), Z(h0), th=0.016, mat_top='primary', mat_bot='secondary',
                   droop=0.014, top_in=fit(h0 + 0.02, 1.16))
    g = merge(labio(h0, 1.12, n, 'secondary', -0.016), bot, top)

    def mole(p):
        r = math.hypot(p.x, p.y - HEAD_C.y)
        q = Vector(p)
        q.z += (0.030 * math.sin(2 * az_of(p) - 0.9) - 0.012) * _ss((r - 0.30) / 0.20)
        return q
    g.warp(mole)
    # cone torto: sobe amassado e a ponta cai para tras
    bx, by = fit(h0 + 0.02, 1.16)
    path = [(0, 0, Z(h0 + 0.018)), (0.006, 0.0, Z(0.205)), (-0.012, 0.012, Z(0.295)), (0.012, 0.045, Z(0.390)),
            (-0.006, 0.105, Z(0.475)), (0.004, 0.190, Z(0.535)), (0.0, 0.275, Z(0.545)), (0.0, 0.340, Z(0.505))]
    radii = [(bx, by), (0.216, 0.202), (0.166, 0.156), (0.120, 0.114), (0.080, 0.077), (0.050, 0.048), (0.027, 0.026),
             (0.008, 0.008)]
    cone_ = tube(path, radii, n, 'primary', cap_a=False, cap_b=True, up=(0, 1, 0))
    g.add(cone_)
    g.grad('z', Z(0.10), Z(0.55), FRIO, lp.WHITE)
    # faixa com fivela
    g.add(stack([(Z(h0 + 0.020), bx - 0.01, by - 0.01), (Z(h0 + 0.022), bx + 0.012, by + 0.012),
                 (Z(h0 + 0.070), 0.262, 0.244), (Z(h0 + 0.072), 0.240, 0.224)], n, 'accent', cap_a=False, cap_b=False))
    g.add(box(0.074, 0.022, 0.060, 'vcol', center=(0, -(by + 0.004), Z(h0 + 0.046))).color(OURO))
    g.add(box(0.040, 0.026, 0.028, 'vcol', center=(0, -(by + 0.005), Z(h0 + 0.046))).color(OURO_ESC))
    # estrelinha pendurada na ponta
    st = estrelinha(0.042).color(OURO)
    st.move(0.0, 0.345, Z(0.455))
    g.add(st)
    tilt(g)
    return g.bind_axis('z', [(1.31, 'head'), (1.45, 'hat1')])


@piece('hat', 'hat_cogumelo', 'Chapéu de Cogumelo', rarity=1, cost=180, hair='flat')
def hat_cogumelo():
    n = 14
    C0 = Vector((0, 0, Z(0.105)))
    R, H = 0.47, 0.265

    def cap(az, el):
        a, e = math.radians(az), math.radians(el)
        return C0 + Vector((math.sin(a) * math.cos(e) * R, -math.cos(a) * math.cos(e) * R, math.sin(e) * H))
    prof = [(R * math.cos(math.radians(e)), C0.z + H * math.sin(math.radians(e))) for e in (0, 18, 36, 54, 72)]
    g = lathe([(0.20, Z(0.085)), (0.30, Z(0.070)), (0.425, Z(0.082)), (R * 0.985, C0.z - 0.008)], n, 'secondary')
    g.grad('y', -0.47, 0.47, lp.WHITE, FRIO)
    top = lathe(prof + [(0.0, C0.z + H)], n, 'primary')
    top.grad('z', C0.z, C0.z + H, FRIO, lp.WHITE)
    # beirada gordinha
    g.add(lathe([(R * 0.985, C0.z - 0.008), (R + 0.012, C0.z - 0.022), (R + 0.016, C0.z + 0.004), (R, C0.z + 0.012)],
                n, 'primary').color((0.82, 0.78, 0.90)))
    g.add(top)
    for az, el, r in ((12, 34, 0.088), (-58, 26, 0.060), (78, 30, 0.070), (152, 38, 0.082), (-128, 32, 0.066),
                      (-24, 68, 0.062), (104, 66, 0.046)):
        p = cap(az, el)
        nrm = Vector(((p.x - C0.x) / R ** 2, (p.y - C0.y) / R ** 2, (p.z - C0.z) / H ** 2))
        d = lathe([(r, -0.004), (r * 0.80, 0.012), (0.0, 0.017)], 8, 'secondary')
        g.add(aponta(d, p, nrm))
    return tilt(g, -5).bind('head')


@piece('hat', 'hat_capuz', 'Capuz de Viajante', cost=90, hair='hide')
def hat_capuz():
    half = [(0, 0.098), (16, 0.094), (32, 0.070), (44, 0.018), (52, -0.065), (57, -0.150), (62, -0.222),
            (85, -0.228), (112, -0.228), (146, -0.228), (180, -0.228)]

    def kf(az, u):
        return 1.15 + 0.06 * u ** 3
    g = casca(volta(half), k=kf, rows=7, edge=0.99, mat='primary', rim_mat='secondary', shade=(0.86, 0.82, 0.92))
    # bico do capuz caindo para tras
    r = hpt(180, 50, 1.06)
    bico = mecha([r, r + Vector((0, 0.15, 0.07)), r + Vector((0, 0.27, -0.04)), r + Vector((0, 0.27, -0.20))],
                 0.105, 0.090, n=8, segs=6, prof=[(0.0, 1.0), (0.35, 0.80), (1.0, 0.06)], up=(1, 0, 0), mat='primary')
    bico.bind_fn(lambda p: {'head': 1.0 - 0.7 * _ss((p.y - 0.30) / 0.14), 'hat1': 0.7 * _ss((p.y - 0.30) / 0.14)})
    g.add(bico)
    g.grad('z', Z(-0.23), Z(0.30), FRIO, lp.WHITE)
    # franjinha escapando (cor do cabelo do jogador)
    fr = Geo()
    for a0, a1, hh in ((-24, -34, 0.030), (-2, 6, 0.045), (24, 31, 0.028)):
        fr.add(mecha([hz(a0, 0.130, 1.05), hz((a0 + a1) / 2, 0.085, 1.13), hz(a1, hh, 1.085)], 0.052, 0.020, n=6,
                     segs=4))
    fr.grad('z', Z(0.02), Z(0.13), (0.74, 0.70, 0.84), lp.WHITE)
    g.add(fr)
    g.w = [w if w else {'head': 1.0} for w in g.w]
    return g


@piece('hat', 'hat_flores', 'Coroa de Flores', rarity=1, cost=160, hair='keep')
def hat_flores():
    def el(az):
        return 28.0 + 6.0 * math.cos(math.radians(az))
    path = [hpt(az, el(az), 1.125) for az in range(-180, 181, 24)]
    g = tube(path, 0.013, 5, 'vcol', cap_a=False, cap_b=False, up=(0, 0, 1)).color(lp.hexc('#6b8f3e'))
    mats = ['accent', 'secondary', 'primary']
    fl = [(-74, 0.050), (-34, 0.064), (10, 0.074), (52, 0.058), (96, 0.066), (150, 0.056), (-128, 0.068)]
    for i, (az, r) in enumerate(fl):
        p = hpt(az, el(az) + 1.5, 1.165)
        d = (p - HEAD_C).normalized() + Vector((0, 0, 0.25))
        m = mats[i % 3]
        g.add(aponta(flor(r, m, lp.hexc('#fff1c9') if m == 'accent' else OURO), p, d))
    for az in (-54, -10, 31, 74, 124, 178, -100, -152):
        p = hpt(az, el(az), 1.13)
        out = (p - HEAD_C).normalized()
        g.add(folha(p, p + out * 0.03 + Vector((0, 0, 0.03)), p + out * 0.05 + Vector((0, 0, 0.065)), 0.026))
    return g.bind('head')


@piece('hat', 'hat_pirata', 'Tricórnio de Pirata', rarity=2, cost=380, hair='flat')
def hat_pirata():
    h0, n = 0.115, 18
    zb = Z(h0)
    copa = stack([S(h0, 1.14, -0.004), (Z(0.200), 0.226, 0.210), (Z(0.262), 0.176, 0.164), (Z(0.300), 0.095, 0.090)],
                 n, 'dark', cap_a=False, cap_b=True)
    copa.grad('z', zb, Z(0.30), lp.WHITE, (1.5, 1.45, 1.6))
    ri, ro = 0.262, 0.475
    brim = stack([(zb - 0.016, ri, ri * 0.93), (zb - 0.018, 0.36, 0.36), (zb - 0.020, ro, ro), (zb - 0.004, ro, ro),
                  (zb - 0.002, 0.36, 0.36), (zb + 0.002, ri + 0.02, ri * 0.93 + 0.02)], n, 'dark', cap_a=False,
                 cap_b=False)
    brim.tint(lambda p, c: (1.45, 1.40, 1.55) if p.z > zb - 0.010 else c)
    galao = stack([(zb - 0.026, ro - 0.012, ro - 0.012), (zb - 0.028, ro + 0.012, ro + 0.012),
                   (zb + 0.004, ro + 0.012, ro + 0.012), (zb + 0.006, ro - 0.012, ro - 0.012)], n, 'accent',
                  cap_a=False, cap_b=False)
    g = merge(brim, galao)

    # dobra a aba em tres: bicos na frente e nos dois lados de tras
    def dobra(p):
        r = math.hypot(p.x, p.y)
        t = max(0.0, min(1.0, (r - ri) / (ro - ri)))
        a = az_of(p)
        c = (0.5 + 0.5 * math.cos(3 * a)) ** 0.8
        rr = ri + (r - ri) * (0.30 + 0.82 * c)
        q = Vector(p)
        s = rr / r if r > 1e-6 else 1.0
        q.x, q.y = p.x * s, p.y * s
        q.z += 0.185 * (1.0 - c) * t ** 0.8 - 0.018 * c * t
        return q
    g.warp(dobra)
    g.add(copa)
    g.add(labio(h0, 1.14, n, 'dark', -0.016))
    # pena presa na dobra esquerda
    p0 = Vector((0.20, -0.12, zb + 0.07))
    pena = mecha([p0, p0 + Vector((0.07, 0.10, 0.17)), p0 + Vector((0.02, 0.30, 0.20)), p0 + Vector((-0.02, 0.42, 0.06))],
                 0.062, 0.012, n=4, segs=6, prof=[(0.0, 0.25), (0.35, 1.0), (0.8, 0.8), (1.0, 0.15)], up=(1, 0, 0.3),
                 mat='secondary')
    pena.grad('y', -0.1, 0.35, FRIO, lp.WHITE)
    g.add(pena)
    g.add(icosphere(0.026, 1, 'vcol', center=tuple(p0 + Vector((0.012, -0.012, 0.0))), smooth=True).color(OURO))
    return tilt(g, -6).bind('head')


@piece('hat', 'hat_elmo', 'Elmo de Cavaleiro', rarity=2, cost=420, hair='hide')
def hat_elmo():
    half = [(0, 0.076), (20, 0.070), (37, 0.050), (47, -0.020), (53, -0.120), (58, -0.212), (78, -0.218),
            (104, -0.218), (130, -0.218), (155, -0.218), (180, -0.218)]

    def kf(az, u):
        return 1.135 + 0.045 * u ** 4
    g = casca(volta(half), k=kf, rows=7, edge=0.99, mat='metal', rim_mat='secondary', shade=(0.90, 0.86, 0.94))
    g.grad('z', Z(-0.22), Z(0.28), FRIO, lp.WHITE)
    # viseira levantada: chapa com bico no meio da testa
    azs = [-72, -54, -36, -18, 0, 18, 36, 54, 72]
    lo = [hz(a, 0.084 - 0.040 * max(0.0, 1.0 - abs(a) / 30.0), 1.205) for a in azs]
    hi = [hz(a, 0.175 - 0.020 * (abs(a) / 72.0) ** 2, 1.185) for a in azs]
    vis = sheet([lo, hi], 'metal', thickness=0.022)
    vis.grad('z', Z(0.04), Z(0.18), (0.80, 0.76, 0.90), lp.WHITE)
    g.add(vis)
    for s in (1, -1):
        g.add(aponta(lathe([(0.030, 0.0), (0.024, 0.014), (0.0, 0.020)], 7, 'vcol').color(OURO), hz(80 * s, 0.125, 1.165),
                     (s, -0.15, 0.1)))
    # crista e penacho
    def mid(phi, k):
        return hpt(0, phi, k) if phi <= 90 else hpt(180, 180 - phi, k)
    g.add(tube([mid(p, 1.150) for p in (46, 62, 78, 94, 110, 126, 142, 158)], (0.030, 0.017), 4, 'secondary',
               up=(1, 0, 0)))
    pl = mecha([(0, -0.02, Z(0.275)), (0, -0.02, Z(0.560)), (0, 0.36, Z(0.540)), (0, 0.43, Z(0.180))], 0.088, 0.052,
               n=6, segs=8, prof=GOTA, up=(1, 0, 0), mat='accent')
    pl.grad('z', Z(0.2), Z(0.5), FRIO, lp.WHITE)

    def wf(p):
        t = max(_ss((p.z - 1.29) / 0.13), _ss((p.y - 0.10) / 0.12))
        return {'head': 1.0 - t, 'hat1': t}
    pl.bind_fn(wf)
    g.add(pl)
    g.w = [w if w else {'head': 1.0} for w in g.w]
    return g


@piece('hat', 'hat_coroa', 'Coroinha', rarity=2, cost=520, hair='keep')
def hat_coroa():
    n = 10

    def ring(r, z, zig=0.0, flare=0.0):
        return [(math.cos(lp.TAU * i / n) * (r + (flare if i % 2 == 0 else 0.0)),
                 math.sin(lp.TAU * i / n) * (r + (flare if i % 2 == 0 else 0.0)),
                 z + (zig if i % 2 == 0 else 0.0)) for i in range(n)]
    g = loft([ring(0.094, 0.0), ring(0.106, 0.018), ring(0.103, 0.052), ring(0.104, 0.062, 0.066, 0.014)], 'vcol',
             cap_a=False, cap_b=False)
    g.add(loft([ring(0.090, 0.052), ring(0.091, 0.062, 0.066, 0.014)], 'vcol', cap_a=False, cap_b=False).flip())
    g.add(loft([ring(0.104, 0.062, 0.066, 0.014), ring(0.091, 0.062, 0.066, 0.014)], 'vcol', cap_a=False,
               cap_b=False))
    for i in range(0, n, 2):
        a = lp.TAU * i / n
        g.add(icosphere(0.017, 0, 'vcol', center=(math.cos(a) * 0.112, math.sin(a) * 0.112, 0.136), smooth=True))
    g.color(OURO).grad('z', 0.0, 0.13, (0.78, 0.60, 0.42), lp.WHITE)
    g.add(ellipsoid(0.094, 0.094, 0.058, n=10, rings=5, mat='primary', center=(0, 0, 0.046)))
    for i in range(0, n, 2):
        a = lp.TAU * (i + 0.0) / n
        gem = lathe([(0.0, -0.016), (0.014, 0.0), (0.0, 0.016)], 4, 'accent', smooth=False).scale(1.0, 0.6, 1.0)
        gem.rot('Z', math.degrees(a) + 90)
        gem.move(math.cos(a) * 0.108, math.sin(a) * 0.108, 0.035)
        g.add(gem)
    # pousada torta no lado esquerdo do cocuruto
    p = hpt(52, 60, 1.075)
    d = (p - HEAD_C).normalized() + Vector((0, 0, 0.35))
    return aponta(g, p, d).bind('head')


@piece('hat', 'hat_viking', 'Elmo Viking', rarity=1, cost=240, hair='flat')
def hat_viking():
    h0, n = 0.10, 12
    aro = stack([S(h0, 0.93, -0.014), S(h0, 1.175, -0.012), S(h0 + 0.045, 1.180), S(h0 + 0.050, 1.13)], n, 'leather',
                cap_a=False, cap_b=False)
    dome = stack([S(h0 + 0.045, 1.14), S(0.190, 1.15), S(0.240, 1.15), (Z(0.275), 0.100, 0.094), (Z(0.290), 0.040, 0.038)],
                 n, 'metal', cap_a=False, cap_b=True)
    dome.grad('z', Z(0.14), Z(0.29), FRIO, lp.WHITE)
    g = merge(aro, dome)
    g.add(lathe([(0.030, Z(0.286)), (0.022, Z(0.312)), (0.0, Z(0.322))], 6, 'metal'))
    for i in range(6):
        a = 30 + 60 * i
        rx, ry = fit(h0 + 0.02, 1.185)
        p = Vector((math.sin(math.radians(a)) * rx, -math.cos(math.radians(a)) * ry, Z(h0 + 0.020)))
        g.add(aponta(lathe([(0.020, 0.0), (0.016, 0.010), (0.0, 0.014)], 6, 'vcol').color(OURO), p, (p.x, p.y, 0.0)))
    # protetor de nariz curtinho
    g.add(sheet([[hz(a, 0.020, 1.20) for a in (-5, 0, 5)], [hz(a, 0.110, 1.19) for a in (-9, 0, 9)]], 'metal',
                thickness=0.016))
    tilt(g, -5)
    # chifres
    osso, osso_esc = lp.hexc('#f3ead2'), lp.hexc('#b79a7a')
    for s in (1, -1):
        r = hpt(90 * s, 36, 1.10)
        hn = mecha([r, r + Vector((0.16 * s, 0, 0.00)), r + Vector((0.25 * s, -0.02, 0.15)),
                    r + Vector((0.18 * s, -0.04, 0.31))], 0.062, 0.062, n=7, segs=6,
                   prof=[(0.0, 1.0), (0.5, 0.74), (1.0, 0.08)], up=(0, 1, 0), mat='vcol')
        hn.tint(lambda p, c, r=r: lp.mixc(osso_esc, osso, _ss(((p - r).length - 0.02) / 0.20)))
        g.add(hn)
        base = toro(0.062, 0.016, 8, 5, 'metal')
        g.add(aponta(base, r + Vector((0.035 * s, 0, 0.0)), (s, 0, 0.0)))
    return g.bind('head')


@piece('hat', 'hat_aureola', 'Auréola', rarity=3, cost=900, hair='keep')
def hat_aureola():
    luz = (1.0, 0.86, 0.46)
    g = toro(0.165, 0.021, 16, 6, 'glow')
    for a, r, dz in ((35, 0.245, 0.03), (160, 0.225, -0.035), (265, 0.250, 0.045)):
        st = estrelinha(0.030, 'glow')
        st.move(math.cos(math.radians(a)) * r, math.sin(math.radians(a)) * r, dz)
        g.add(st)
    g.color(luz)
    g.rot('X', -12).move(0.0, 0.015, Z(0.415))
    return g.bind('hat1')

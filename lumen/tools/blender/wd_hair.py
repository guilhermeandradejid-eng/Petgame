"""wd_hair.py: cabelos.

Cada cabelo devolve (base, topo). A base e uma casca com a linha do cabelo esculpida (borda
grossa, sem serrilhado) mais mechas grandes; o topo e so o volume que furaria um chapeu.
"""
import math

from mathutils import Vector
from mathutils.bvhtree import BVHTree

import lp
from lp import Geo, box, cone, cyl, ellipsoid, icosphere, lathe, loft, merge, poly_extrude, ring_pts, sheet, stack, tube
import hero_body as hb
from hero_body import HEAD_C, HEAD_R
import wd_base
from wd_base import piece, scalp, hair_cap, tuft, hair_shade, skirt_weights, belt, to_hand

SOMBRA = (0.60, 0.55, 0.74)   # lado de baixo das bordas e mechas (frio)


# ================================================================= ajudantes
def _ss(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def hpt(az, el, k=1.07):
    """Ponto na cabeca inflada por k. az em graus: 0 = rosto (-Y), 90 = lado esquerdo (+X),
    180 = nuca. el = elevacao em graus (90 = topo)."""
    a, e = math.radians(az), math.radians(el)
    r = Vector((math.sin(a) * math.cos(e) * HEAD_R.x, -math.cos(a) * math.cos(e) * HEAD_R.y, math.sin(e) * HEAD_R.z))
    return HEAD_C + (hb.head_warp(HEAD_C + r) - HEAD_C) * k


def h2el(h):
    """Altura em metros (relativa ao centro da cabeca) -> elevacao em graus."""
    return math.degrees(math.asin(max(-1.0, min(1.0, h / HEAD_R.z))))


def hz(az, h, k=1.07):
    return hpt(az, h2el(h), k)


def volta(half):
    """Espelha uma meia borda [(az 0..180, h[, k])] para a volta toda."""
    out = [(-b[0],) + tuple(b[1:]) for b in reversed(half) if 0 < b[0] < 180]
    return out + list(half)


def casca(borda, k=1.07, rows=5, edge=0.975, pw=1.0, shade=SOMBRA, mat='hair', rim_mat=None):
    """Casca do cabelo com a linha esculpida e borda grossa.
    borda = [(az, h[, k_borda])] dando a volta (az crescente, -180 < az <= 180); h em metros
    relativo ao centro. k: numero ou funcao (az, u), u = 0 no topo .. 1 na borda."""
    n = len(borda)
    kf = k if callable(k) else (lambda az, u: k)
    hs = [b[1] for b in borda]
    # os aneis de cima seguem um envelope suave; so o ultimo desce ate o recorte
    env = [max(hs[i - 1], hs[i], hs[(i + 1) % n]) for i in range(n)]
    env = [max(env[i], (env[i - 1] + env[i] + env[(i + 1) % n]) / 3.0) for i in range(n)]
    g = Geo()
    top = g.add_vert(hpt(0, 90, kf(0, 0.0)))
    rws = []
    for j in range(1, rows + 1):
        row = []
        for i, b in enumerate(borda):
            az = b[0]
            if j < rows:
                u = (j / rows) ** pw
                el1 = h2el(env[i]) + (h2el(b[1]) - h2el(env[i])) * u ** 3
                row.append(g.add_vert(hpt(az, 90 - (90 - el1) * u, kf(az, u))))
            else:
                row.append(g.add_vert(hz(az, b[1], b[2] if len(b) > 2 else kf(az, 1.0))))
        rws.append(row)
    for i in range(n):
        j = (i + 1) % n
        g.add_face((top, rws[0][i], rws[0][j]), mat)
    for a, b in zip(rws, rws[1:]):
        for i in range(n):
            j = (i + 1) % n
            # triangula pela diagonal mais "para fora": a casca nunca afunda na cabeca
            if ((g.v[b[i]] + g.v[a[j]]) / 2 - HEAD_C).length >= ((g.v[b[j]] + g.v[a[i]]) / 2 - HEAD_C).length:
                g.add_face((b[i], b[j], a[j]), mat)
                g.add_face((b[i], a[j], a[i]), mat)
            else:
                g.add_face((b[i], b[j], a[i]), mat)
                g.add_face((b[j], a[j], a[i]), mat)
    # borda: dobra para dentro ate a pele
    last = rws[-1]
    dup = [g.add_vert(g.v[i], c=shade) for i in last]
    inner = [g.add_vert(hz(b[0], b[1], edge), c=shade) for b in borda]
    for i in range(n):
        j = (i + 1) % n
        g.add_face((inner[i], inner[j], dup[j], dup[i]), rim_mat or mat)
    return desfura(g, n * (2 * rows - 1), dict(zip(last, dup)))


_HEAD_PTS = []


def desfura(g, nf, twins, margin=0.006):
    """A cabeca e um poliedro grosso e tem bochecha: uma face grande da casca pode passar por
    baixo de um vertice da cabeca. Empurra para fora so as faces que ficam rentes demais."""
    if not _HEAD_PTS:
        _HEAD_PTS.extend(p.copy() for p in hb.make_head().v if p.z > 0.79)
    for _ in range(6):
        bvh = BVHTree.FromPolygons([tuple(p) for p in g.v], [list(f) for f in g.f[:nf]])
        push = {}
        for p in _HEAD_PTS:
            d = p - HEAD_C
            dn = d.normalized()
            loc, nrm, fi, dist = bvh.ray_cast(HEAD_C + d * 0.85, dn, 0.25)
            if loc is None:
                continue
            lack = d.length * 0.15 + margin - dist
            if lack > 0:
                for vi in g.f[fi]:
                    push[vi] = max(push.get(vi, 0.0), lack * 1.25)
        if not push:
            break
        for vi, amt in push.items():
            g.v[vi] = g.v[vi] + (g.v[vi] - HEAD_C).normalized() * amt
            if vi in twins:
                g.v[twins[vi]] = g.v[vi].copy()
    return g


def bez(ctrl, t):
    pts = [Vector(p) for p in ctrl]
    while len(pts) > 1:
        pts = [a.lerp(b, t) for a, b in zip(pts, pts[1:])]
    return pts[0]


FOLHA = [(0.0, 0.55), (0.3, 1.0), (0.62, 0.82), (1.0, 0.10)]     # mecha comum
GOTA = [(0.0, 0.42), (0.38, 1.0), (0.72, 0.80), (1.0, 0.08)]      # rabo gordinho
ESPINHO = [(0.0, 1.0), (0.45, 0.66), (1.0, 0.05)]                 # espeto


def perfil(prof, t):
    for (a, ka), (b, kb) in zip(prof, prof[1:]):
        if t <= b + 1e-9:
            u = (t - a) / (b - a)
            return ka + (kb - ka) * u
    return prof[-1][1]


def mecha(ctrl, w, th, n=6, segs=5, prof=FOLHA, up=None, phase=0.0, sq=0.0, mat='hair'):
    """Mecha gordinha: tubo achatado ao longo de uma Bezier (3 ou 4 pontos de controle),
    com a largura seguindo um perfil. w = meia largura, th = meia espessura."""
    path = [bez(ctrl, i / segs) for i in range(segs + 1)]
    radii = []
    for i in range(segs + 1):
        kk = perfil(prof, i / segs)
        radii.append((w * kk, th * kk))
    if up is None:
        up = (path[0] - HEAD_C).normalized()
    return tube(path, radii, n, mat, up=tuple(up), square=sq, phase=phase)


def fita(p, axis, r=0.04, th=0.014, w=0.03, n=8, mat='accent'):
    """Elastico/fita: anel grosso em volta de um ponto, com o eixo dado."""
    ax = Vector(axis).normalized()
    g = lathe([(r * 0.86, -w / 2), (r + th, -w * 0.22), (r + th, w * 0.22), (r * 0.86, w / 2)], n, mat)
    q = Vector((0, 0, 1)).rotation_difference(ax)
    g.xf(q.to_matrix().to_4x4())
    g.move(*p)
    return g


def acabamento(base, top):
    """Gradiente padrao (base fria e escura, topo claro), igual para a base e o topo."""
    b0, b1 = merge(base, top).bounds() if top.v else base.bounds()
    for g in (base, top):
        if not g.v:
            continue
        g.grad('z', max(b0[2], HEAD_C.z - 0.30), b1[2], (0.70, 0.66, 0.80), (1.06, 1.04, 1.0))
    return base, top


def so_cabeca(g):
    """Da peso 'head' para os vertices que ainda nao tem osso."""
    g.w = [w if w else {'head': 1.0} for w in g.w]
    return g


# ================================================================= pecas
@piece('hair', 'hair_bagunca', 'Bagunçado')
def hair_bagunca():
    return wd_base.ref_hair()


@piece('hair', 'hair_tigela', 'Tigela')
def hair_tigela():
    half = [(0, 0.072), (17, 0.072), (34, 0.070), (50, 0.062), (64, 0.045), (78, 0.018), (93, -0.008),
            (112, -0.032), (135, -0.066), (158, -0.088), (180, -0.095)]
    b = volta(half)
    # um entalhe torto na franja, de quem cortou em casa
    i = b.index((-17, 0.072))
    b[i:i + 1] = [(-23, 0.072), (-16, 0.108), (-9, 0.072)]
    g = casca(b, k=lambda az, u: 1.07 + 0.055 * u ** 4, rows=5)
    top = Geo()
    # pega-rapaz no cocuruto
    r = hpt(150, 78, 1.04)
    top.add(mecha([r, r + Vector((0.0, 0.03, 0.09)), r + Vector((0.05, 0.11, 0.07))], 0.030, 0.020, n=4, segs=4,
                  prof=ESPINHO, up=(1, 0, 0)))
    acabamento(g, top)
    return g.bind('head'), top.bind('head')


# arco da linha do cabelo por cima da orelha, com costeleta em ponta na frente (meia borda)
ORELHA = [(69, -0.060), (75, -0.005), (82, 0.036), (92, 0.050), (102, 0.038), (110, -0.005), (118, -0.066)]


@piece('hair', 'hair_rabo', 'Rabo de Cavalo')
def hair_rabo():
    ore = ORELHA
    b = volta(ore + [(138, -0.130), (160, -0.160), (180, -0.170)])
    # frente assimetrica: risca do lado esquerdo, franja varrida para a direita
    fr = [(-56, 0.022), (-40, 0.036), (-24, 0.052), (-8, 0.070), (8, 0.088), (21, 0.108), (33, 0.142), (45, 0.086),
          (57, 0.048)]
    i = b.index((-69, -0.060))
    b[i + 1:i + 1] = fr
    g = casca(b, k=1.07, rows=5)
    # franja jogada para o lado: mechas grandes saindo da risca
    g.add(mecha([hpt(36, 47, 1.02), hpt(8, 36, 1.15), hpt(-30, 24, 1.15), hz(-58, 0.005, 1.10)], 0.070, 0.026,
                n=6, segs=6))
    g.add(mecha([hpt(40, 42, 1.02), hpt(24, 30, 1.15), hpt(-2, 20, 1.14), hz(-22, 0.035, 1.11)], 0.050, 0.022,
                n=6, segs=5))
    g.add(mecha([hpt(42, 44, 1.02), hpt(56, 32, 1.13), hz(64, 0.03, 1.10), hz(70, -0.085, 1.07)], 0.040, 0.022,
                n=6, segs=5))
    # rabo: elastico + gota comprida presa nos ossos de mola
    root = Vector((0.0, 0.250, 1.050))
    g.add(fita(root + Vector((0, 0.030, 0.012)), (0, 1, 0.4), r=0.046, th=0.018, w=0.036))
    tail = mecha([root, Vector((0, 0.47, 1.20)), Vector((0, 0.53, 0.90)), Vector((0, 0.40, 0.70)),
                  Vector((0, 0.47, 0.66))], 0.105, 0.085, n=6, segs=8, prof=GOTA, up=(0, 0, 1))
    tail.bind_axis('z', [(0.80, 'hair2'), (0.90, 'hair1'), (0.99, 'hair1'), (1.07, 'head')])
    g.add(tail)
    # mechinha solta do rabo
    t2 = mecha([root + Vector((0.03, 0.02, 0)), Vector((0.10, 0.40, 1.12)), Vector((0.12, 0.45, 0.92)),
                Vector((0.07, 0.43, 0.80))], 0.040, 0.032, n=4, segs=5, prof=GOTA, up=(0, 0, 1))
    t2.bind_axis('z', [(0.80, 'hair2'), (0.90, 'hair1'), (0.99, 'hair1'), (1.07, 'head')])
    g.add(t2)
    top = Geo()
    acabamento(g, top)
    return so_cabeca(g), top


def cortina(cols, h_top, k_top, rings, front=72, n_mat='hair'):
    """Cabelo comprido caindo pelas costas: tubo achatado cujo anel de cima nasce colado na
    casca (nas colunas de tras) e cujos aneis de baixo sao superelipses.
    rings = [(z, rx, y_tras, y_frente, square)] de cima para baixo."""
    rr = []
    top = []
    for az in cols:
        top.append(hz(az, h_top, k_top if abs(az) >= front else 0.80))
    rr.append(top)
    for z, rx, yb, yf, sq in rings:
        e = 1.0 - 0.75 * sq
        cy, ry = (yb + yf) / 2.0, (yb - yf) / 2.0
        ring = []
        for az in cols:
            a = math.radians(az)
            s, c = math.sin(a), -math.cos(a)
            ring.append((math.copysign(abs(s) ** e, s) * rx, cy + math.copysign(abs(c) ** e, c) * ry, z))
        rr.append(ring)
    rr.reverse()
    return loft(rr, n_mat, cap_a=True, cap_b=False)


@piece('hair', 'hair_liso', 'Liso Comprido')
def hair_liso():
    half = [(0, 0.150), (9, 0.118), (22, 0.082), (36, 0.040), (50, -0.020), (62, -0.085), (73, -0.130), (88, -0.130),
            (108, -0.110), (130, -0.100), (155, -0.100), (180, -0.100)]

    def kf(az, u):
        return 1.07 + 0.085 * u ** 2 * _ss((abs(az) - 35) / 40.0)
    b = volta(half)
    g = casca(b, k=kf, rows=6)
    # mechas compridas na frente da orelha
    for s in (1, -1):
        g.add(mecha([hz(64 * s, -0.04, 1.10), hz(67 * s, -0.15, 1.15), Vector((0.222 * s, -0.110, 0.775))],
                    0.052, 0.030, n=6, segs=4))
    # cortina das costas ate a cintura, nos ossos de mola
    cols = [az for az in range(-165, 181, 15) if abs(az) > 70] + [-45, 0, 45]
    cols.sort()
    back = cortina(cols, -0.035, 1.14, [(0.880, 0.296, 0.262, 0.030, 0.10), (0.770, 0.272, 0.270, 0.105, 0.22),
                                         (0.660, 0.246, 0.268, 0.125, 0.28), (0.565, 0.214, 0.262, 0.140, 0.30),
                                         (0.530, 0.160, 0.248, 0.160, 0.30)])
    back.bind_axis('z', [(0.62, 'hair2'), (0.74, 'hair1'), (0.84, 'hair1'), (0.95, 'head')])
    g.add(back)
    top = Geo()
    acabamento(g, top)
    return so_cabeca(g), top


def _rabo_lado(g, s, root, ctrl, w, th):
    """Rabo lateral (maria-chiquinha) com elastico; pesos suaves nos ossos de mola."""
    d = (ctrl[1] - ctrl[0]).normalized()
    g.add(fita(root + d * 0.022, d, r=0.040, th=0.016, w=0.032))
    t = mecha(ctrl, w, th, n=6, segs=7, prof=GOTA, up=(0, 1, 0))

    def wf(p):
        k = _ss((1.07 - p.z) / 0.12)
        k2 = _ss((0.93 - p.z) / 0.14)
        return {'head': 1.0 - 0.65 * k, 'hair1': 0.65 * k * (1.0 - k2), 'hair2': 0.65 * k * k2}
    t.bind_fn(wf)
    g.add(t)


@piece('hair', 'hair_maria', 'Maria-Chiquinha')
def hair_maria():
    half = [(0, 0.040, 1.10), (9, 0.088), (18, 0.046, 1.10), (28, 0.090), (38, 0.050, 1.10), (49, 0.092),
            (59, 0.030, 1.09)] + ORELHA + [(138, -0.125), (160, -0.150), (180, -0.158)]
    g = casca(volta(half), k=1.07, rows=5)
    for s in (1, -1):
        r = hpt(108 * s, 16, 1.07)
        ctrl = [r, r + Vector((0.17 * s, 0.03, 0.11)), r + Vector((0.27 * s, 0.05, -0.12)),
                r + Vector((0.16 * s, 0.03, -0.33))]
        _rabo_lado(g, s, r, ctrl, 0.078, 0.066)
    top = Geo()
    acabamento(g, top)
    return so_cabeca(g), top


@piece('hair', 'hair_coque', 'Coquinhos')
def hair_coque():
    half = [(0, 0.030, 1.10), (11, 0.098), (24, 0.088), (38, 0.064), (50, 0.036, 1.09), (60, 0.070)] + ORELHA + \
           [(138, -0.100), (160, -0.116), (180, -0.120)]
    g = casca(volta(half), k=1.07, rows=5)
    top = Geo()
    for s in (1, -1):
        c = Vector((0.168 * s, 0.035, 1.262))
        ax = Vector((0.45 * s, 0.05, 1.0)).normalized()
        bun = ellipsoid(0.092, 0.092, 0.078, n=8, rings=5, mat='hair')
        bun.xf(Vector((0, 0, 1)).rotation_difference(ax).to_matrix().to_4x4())
        bun.move(*(c + ax * 0.03))
        top.add(bun)
        top.add(fita(c - ax * 0.030, ax, r=0.058, th=0.016, w=0.030))
        # pontinha escapando do coque
        r = c + ax * 0.085
        top.add(mecha([r, r + Vector((0.035 * s, 0.03, 0.04)), r + Vector((0.075 * s, 0.07, 0.005))], 0.026, 0.020,
                      n=4, segs=3, prof=ESPINHO, up=(0, 1, 0)))
    acabamento(g, top)
    return g.bind('head'), top.bind('head')


@piece('hair', 'hair_moicano', 'Moicano')
def hair_moicano():
    # lados raspados: casquinha fina e mais escura
    half = [(0, 0.140), (22, 0.134), (42, 0.116), (55, 0.080), (63, 0.020)] + ORELHA + \
           [(138, -0.120), (160, -0.142), (180, -0.148)]
    g = casca(volta(half), k=1.028, rows=6, edge=0.99)
    g.tint(lambda p, c: (c[0] * 0.64, c[1] * 0.61, c[2] * 0.78))
    # faixa do meio, mais alta, da testa ate a nuca
    faixa = [(0, 0.152), (13, 0.152), (24, 0.146), (33, 0.190), (48, 0.222), (68, 0.233), (90, 0.236), (112, 0.233),
             (132, 0.222), (147, 0.190), (156, 0.120), (162, 0.000), (169, -0.100), (180, -0.156)]
    g.add(casca(volta(faixa), k=1.085, rows=3))
    top = Geo()
    # crista: uma barbatana dentada continua, da testa a nuca, com os dentes tombados para tras
    def mid(phi, k):
        return hpt(0, phi, k) if phi <= 90 else hpt(180, 180 - phi, k)
    alt = [0.0, 0.13, 0.05, 0.21, 0.07, 0.27, 0.08, 0.26, 0.08, 0.22, 0.07, 0.17, 0.05, 0.11, 0.0]
    nn = len(alt)
    fin = Geo()
    bl, br, rd = [], [], []
    for i, h in enumerate(alt):
        phi = 36 + (192 - 36) * i / (nn - 1)
        c = mid(phi, 1.06)
        bl.append(fin.add_vert(c + Vector((0.052, 0, 0))))
        br.append(fin.add_vert(c + Vector((-0.052, 0, 0))))
        out = (mid(phi + 16 * (i % 2), 1.4) - HEAD_C).normalized()
        rd.append(fin.add_vert(mid(phi + 10 * (i % 2), 1.075) + out * h))
    for i in range(nn - 1):
        fin.add_face((bl[i], bl[i + 1], rd[i + 1], rd[i]), 'hair')
        fin.add_face((br[i], rd[i], rd[i + 1], br[i + 1]), 'hair')
    top.add(fin)
    acabamento(g, top)
    return g.bind('head'), top.bind('head')


@piece('hair', 'hair_ondulado', 'Chanel Ondulado')
def hair_ondulado():
    def gomo(az):
        # gomos de 30 graus dos lados e atras: vale em quina, crista redonda
        return abs(math.sin(math.radians((abs(az) - 60) * 6))) if abs(az) >= 60 else 0.0
    b = [(a, -0.112 - 0.050 * gomo(a), 1.19 + 0.085 * gomo(a)) for a in
         [x * 7.5 for x in range(-23, 25)] if abs(a) >= 60]
    fr = [(-51, -0.050, 1.14), (-41, 0.030, 1.10), (-27, 0.058, 1.09), (-12, 0.075, 1.09), (2, 0.095, 1.08),
          (14, 0.116, 1.08), (24, 0.148, 1.07), (34, 0.100, 1.09), (44, 0.060, 1.10), (52, -0.040, 1.14)]
    i = [x[0] for x in b].index(60)
    b[i:i] = fr

    def kf(az, u):
        lado = _ss((abs(az) - 35) / 30.0)
        return 1.07 + (0.025 + 0.095 * lado) * u ** 2.0 + 0.085 * gomo(az) * lado * _ss((u - 0.25) / 0.6)
    g = casca(b, k=kf, rows=6)
    # onda grande da franja
    g.add(mecha([hpt(26, 46, 1.02), hpt(6, 34, 1.17), hpt(-34, 30, 1.10), hz(-50, 0.01, 1.19), hz(-58, -0.07, 1.14)],
                0.066, 0.028, n=6, segs=7))
    g.add(mecha([hpt(30, 44, 1.02), hpt(46, 30, 1.15), hz(52, 0.02, 1.18), hz(57, -0.08, 1.15)], 0.046, 0.026,
                n=6, segs=5))
    top = Geo()
    acabamento(g, top)

    # vales entre os gomos mais escuros, para as mechas lerem de longe
    def vale(p, c):
        az = math.degrees(math.atan2(p.x / HEAD_R.x, -(p.y - HEAD_C.y) / HEAD_R.y))
        k = (1.0 - gomo(az)) * _ss((1.10 - p.z) / 0.14) * (1.0 if abs(az) >= 60 else 0.0)
        return (c[0] * (1 - 0.30 * k), c[1] * (1 - 0.34 * k), c[2] * (1 - 0.20 * k))
    g.tint(vale)
    return g.bind('head'), top


@piece('hair', 'hair_espetado', 'Espetado')
def hair_espetado():
    half = [(0, 0.100), (14, 0.120), (30, 0.100), (46, 0.076), (58, 0.040)] + ORELHA + \
           [(138, -0.120), (160, -0.150), (180, -0.160)]
    g = casca(volta(half), k=1.07, rows=5)
    top = Geo()
    # franja em tres espetos grandes
    g.add(mecha([hpt(-6, 46, 1.02), hpt(-8, 28, 1.22), hz(4, -0.012, 1.13)], 0.066, 0.030, n=4, segs=4,
                prof=ESPINHO))
    g.add(mecha([hpt(30, 46, 1.02), hpt(44, 28, 1.20), hz(50, 0.000, 1.12)], 0.062, 0.030, n=4, segs=4,
                prof=ESPINHO))
    g.add(mecha([hpt(-36, 46, 1.02), hpt(-50, 28, 1.20), hz(-56, -0.020, 1.12)], 0.066, 0.030, n=4, segs=4,
                prof=ESPINHO))
    # espetos grandes varridos para tras; os da nuca descem ate os ombros (ossos de mola)
    sp = [(180, 80, (0.0, 0.20, 1.55), 0.105, top), (118, 56, (0.29, 0.25, 1.45), 0.105, top),
          (-118, 56, (-0.29, 0.25, 1.45), 0.105, top), (180, 42, (0.0, 0.48, 1.34), 0.115, top),
          (106, 22, (0.45, 0.25, 1.20), 0.100, top), (-106, 22, (-0.45, 0.25, 1.20), 0.100, top),
          (142, 2, (0.29, 0.45, 1.04), 0.105, g), (-142, 2, (-0.29, 0.45, 1.04), 0.105, g),
          (180, -14, (0.0, 0.46, 0.80), 0.105, g), (128, -24, (0.22, 0.36, 0.74), 0.090, g),
          (-128, -24, (-0.22, 0.36, 0.74), 0.090, g)]
    for az, el, tip, w, dst in sp:
        r = hpt(az, el, 0.90)
        tip = Vector(tip)
        out = (hpt(az, el, 1.5) - HEAD_C).normalized()
        mid = r + out * ((tip - r).length * 0.62) + Vector((0, -0.02, 0.0 if el < -5 else 0.03))
        side = out.cross(tip - r)
        up = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
        m = mecha([r, mid, tip], w, w * 0.74, n=4, segs=3, prof=ESPINHO, up=tuple(up))
        if el < -5:
            m.bind_axis('z', [(0.80, 'hair1'), (0.93, 'head')])
        dst.add(m)
    acabamento(g, top)
    return so_cabeca(g), top.bind('head')


def _tufo(az, el, k, r, seed=0):
    """Bola de cacho: elipsoide levemente achatado com o polo virado para fora da cabeca
    (a tampa de dentro, que ficaria escondida, e descartada)."""
    c = hpt(az, el, k)
    d = (c - HEAD_C).normalized()
    e = ellipsoid(r, r * 0.97, r * 0.92, n=9, rings=5, mat='hair', phase=seed * 0.37)
    e.keep_faces(lambda q: q.z > -r * 0.62)
    e.xf(Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4())
    e.move(*c)
    return e


@piece('hair', 'hair_black', 'Black Power')
def hair_black():
    half = [(0, 0.112), (30, 0.100), (56, 0.050), (72, -0.040), (95, -0.080), (125, -0.125), (155, -0.158),
            (180, -0.165)]
    g = casca(volta(half), k=1.09, rows=4)
    top = Geo()
    low = [(82, -4, 1.12, 0.112), (-82, -4, 1.12, 0.112), (136, -12, 1.12, 0.124), (-136, -12, 1.12, 0.124),
           (180, -17, 1.12, 0.118)]
    for i, (az, el, k, r) in enumerate(low):
        g.add(_tufo(az, el, k, r, i))
    high = [(0, 88, 1.18, 0.185), (36, 46, 1.19, 0.140), (-36, 46, 1.19, 0.140), (92, 34, 1.18, 0.165),
            (-92, 34, 1.18, 0.165), (148, 36, 1.18, 0.170), (-148, 36, 1.18, 0.170)]
    for i, (az, el, k, r) in enumerate(high):
        top.add(_tufo(az, el, k, r, i + 5))
    acabamento(g, top)
    return g.bind('head'), top.bind('head')


@piece('hair', 'hair_raspado', 'Raspadinho')
def hair_raspado():
    half = [(0, 0.124), (16, 0.136), (32, 0.130), (46, 0.114), (56, 0.080), (63, 0.020)] + ORELHA + \
           [(138, -0.118), (160, -0.140), (180, -0.146)]
    g = casca(volta(half), k=1.028, rows=5, edge=0.99)
    acabamento(g, Geo())
    g.tint(lambda p, c: (c[0] * 0.84, c[1] * 0.82, c[2] * 0.92))
    # risquinho raspado do lado esquerdo
    pts = [(58, 40), (72, 37), (88, 33), (104, 30)]
    r = Geo()
    a = [r.add_vert(hpt(az, el + 2.2, 1.040)) for az, el in pts]
    c = [r.add_vert(hpt(az, el - 2.2, 1.040)) for az, el in pts]
    for i in range(len(pts) - 1):
        r.add_face((c[i], c[i + 1], a[i + 1], a[i]), 'skin')
    r.color((0.95, 0.86, 0.86))
    g.add(r)
    return g.bind('head'), Geo()

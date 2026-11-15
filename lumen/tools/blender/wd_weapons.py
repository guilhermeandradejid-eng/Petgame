"""wd_weapons.py: armas (espadas, arcos, cajados, martelos com escudo).

Toda arma e modelada na origem: a mao segura em z=0, o cabo corre em Z, a ponta vai para +Z
e a "cara" larga (lamina, lua, cabeca do martelo) fica no plano XZ. to_hand leva para a mao.
Escudos sao modelados deitados (face para +Z, eixo do antebraco em X) e presos em forearm.L.
"""
import math

from mathutils import Matrix, Vector

import lp
from lp import Geo, box, cone, cyl, ellipsoid, icosphere, lathe, loft, merge, poly_extrude, ring_pts, sheet, stack, tube
import hero_body as hb
from hero_body import HEAD_C, HEAD_R
import wd_base
from wd_base import piece, scalp, hair_cap, tuft, hair_shade, skirt_weights, belt, to_hand

TAU = math.tau

# ---------------------------------------------------------------- paleta fixa (material vcol)
GOLD = lp.hexc('#e9b949')
GOLD_HI = lp.hexc('#ffe08a')
GOLD_LO = lp.hexc('#b47a2c')
WOOD = lp.hexc('#a2693a')
WOOD_HI = lp.hexc('#c98d52')
WOOD_LO = lp.hexc('#6d4329')
IVORY = lp.hexc('#f3e8cf')
LEAF = lp.hexc('#6cc24a')
LEAF_LO = lp.hexc('#2f8f58')
NIGHT = lp.hexc('#3a3f9a')
NIGHT_LO = lp.hexc('#27245e')
LUMEN = lp.hexc('#7df9ff')
LUMEN_LO = lp.hexc('#1fa3d6')
LUMEN_MID = lp.hexc('#45d3ee')
IRON = (0.20, 0.21, 0.33)       # multiplicador: ferro batido
STRING = lp.hexc('#f4eede')
COOL = (0.70, 0.67, 0.82)    # sombra fria: multiplicador para a base de pecas de paleta
STEEL_D = (0.11, 0.12, 0.22)  # multiplicador: aco escuro sobre o material metal


# ---------------------------------------------------------------- ajudantes
def _pl(x, pts):
    """Interpolacao linear por trechos em [(x, y), ...]."""
    if x <= pts[0][0]:
        return pts[0][1]
    for (a, ya), (b, yb) in zip(pts, pts[1:]):
        if x <= b:
            return ya + (yb - ya) * (x - a) / (b - a) if b > a else yb
    return pts[-1][1]


def _ramp(g, axis, stops, fn=None):
    """Pinta com cores absolutas ao longo de um eixo. stops = [(valor, cor), ...].
    fn opcional transforma a coordenada antes (ex.: abs)."""
    ai = 'xyz'.index(axis)

    def paint(p, c):
        v = fn(p[ai]) if fn else p[ai]
        if v <= stops[0][0]:
            return stops[0][1]
        for (a, ca), (b, cb) in zip(stops, stops[1:]):
            if v <= b:
                return lp.mixc(ca, cb, (v - a) / (b - a))
        return stops[-1][1]
    return g.tint(paint)


def _aim(g, d, origin=(0, 0, 0)):
    """Gira uma Geo modelada ao longo de +Z para apontar em d e leva ate origin."""
    q = Vector((0, 0, 1)).rotation_difference(Vector(d).normalized())
    return g.xf(Matrix.Translation(Vector(origin)) @ q.to_matrix().to_4x4())


def _blade(secs, mat='metal', core=0.42):
    """Lamina facetada de secao hexagonal: miolo chato + dois gumes.
    secs = [(z, larg_esq, larg_dir, meia_esp, cx, sobe_esq, sobe_dir)] da base ate a ponta;
    sobe_* levanta so o vertice do gume (da para fazer linguas de chama)."""
    rings = []
    for s in secs:
        z, wl, wr, t = s[:4]
        cx = s[4] if len(s) > 4 else 0.0
        ll = s[5] if len(s) > 5 else 0.0
        lr = s[6] if len(s) > 6 else 0.0
        rings.append([(cx + wr, 0, z + lr), (cx + wr * core, t, z), (cx - wl * core, t, z),
                      (cx - wl, 0, z + ll), (cx - wl * core, -t, z), (cx + wr * core, -t, z)])
    return loft(rings, mat).flat()


def _inset(pts, d):
    """Encolhe um poligono 2D em d (meia-esquadria limitada)."""
    n = len(pts)
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    sgn = 1.0 if area > 0 else -1.0
    out = []
    for i in range(n):
        p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n])
        e1, e2 = (p1 - p0).normalized(), (p2 - p1).normalized()
        n1 = Vector((-e1.y, e1.x)) * sgn
        n2 = Vector((-e2.y, e2.x)) * sgn
        b = n1 + n2
        if b.length < 1e-6:
            b = n1.copy()
        b.normalize()
        k = 1.0 / max(0.55, b.dot(n1))
        out.append((p1.x + b.x * d * k, p1.y + b.y * d * k))
    return out


def _plate(pts, depth, bev=0.008, mat='vcol'):
    """Placa: poligono (x, z) com espessura em Y e bordas chanfradas (frente em -Y)."""
    n = len(pts)
    ins = _inset(pts, bev)
    h = depth / 2
    bv = min(bev, h * 0.8)
    g = Geo()
    rows = [[g.add_vert((x, -h, z)) for x, z in ins],
            [g.add_vert((x, -h + bv, z)) for x, z in pts],
            [g.add_vert((x, h - bv, z)) for x, z in pts],
            [g.add_vert((x, h, z)) for x, z in ins]]
    g.add_face(tuple(rows[0]), mat, False)
    g.add_face(tuple(reversed(rows[3])), mat, False)
    for a, b in zip(rows, rows[1:]):
        for i in range(n):
            j = (i + 1) % n
            g.add_face((a[j], a[i], b[i], b[j]), mat, False)
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    if area < 0:
        g.flip()
    return g


def _sym(half):
    """Contorno simetrico em x a partir da metade direita (de baixo para cima, x >= 0)."""
    left = [(-x, z) for x, z in reversed(half) if x > 1e-6]
    return list(half) + left


def _star(n=5, r1=0.05, r2=0.022, depth=0.03, mat='glow', rot=0.0):
    """Estrela facetada no plano XZ (bojuda no centro, quina viva na borda)."""
    g = Geo()
    cf = g.add_vert((0, -depth / 2, 0))
    cb = g.add_vert((0, depth / 2, 0))
    rim = []
    for i in range(2 * n):
        a = math.radians(rot) + math.pi * i / n
        r = r1 if i % 2 == 0 else r2
        rim.append(g.add_vert((math.sin(a) * r, 0, math.cos(a) * r)))
    for i in range(2 * n):
        j = (i + 1) % (2 * n)
        g.add_face((cf, rim[j], rim[i]), mat, False)
        g.add_face((cb, rim[i], rim[j]), mat, False)
    return g


def _gem(r, h, n=6, mat='glow', lo=0.32):
    """Gema bipiramidal facetada, centro no anel mais largo."""
    return lathe([(0.0, -h * lo), (r, 0.0), (0.0, h * (1.0 - lo))], n, mat, smooth=False)


def _stud(r, half, tip, n=6, mat='glow'):
    """Gema encravada: prisma com duas piramides, eixo em Y (aparece dos dois lados de uma placa)."""
    return lathe([(0.0, -tip), (r, -half), (r, half), (0.0, tip)], n, mat, smooth=False).rot('X', 90)


def _crystal(r, h, n=6, mat='glow'):
    """Cristal comprido facetado, base em z=0."""
    return lathe([(0.0, 0.0), (r * 0.72, h * 0.14), (r, h * 0.60), (0.0, h)], n, mat, smooth=False)


def _torus(R, r, n=12, m=5, mat='vcol', rz=None, smooth=True):
    """Anel no plano XY (eixo Z)."""
    rz = r if rz is None else rz
    g = Geo()
    idx = []
    for i in range(n):
        a = TAU * i / n
        ca, sa = math.cos(a), math.sin(a)
        row = []
        for j in range(m):
            b = TAU * (j + 0.5) / m
            rr = R + r * math.cos(b)
            row.append(g.add_vert((rr * ca, rr * sa, -rz * math.sin(b))))
        idx.append(row)
    for i in range(n):
        a, b = idx[i], idx[(i + 1) % n]
        for j in range(m):
            k = (j + 1) % m
            g.add_face((a[j], a[k], b[k], b[j]), mat, smooth)
    return g


def _prism(pts, z0, z1, mat='vcol'):
    """Poligono (x, y) anti-horario visto de cima, extrudado de z0 a z1."""
    g = Geo()
    n = len(pts)
    a = [g.add_vert((x, y, z0)) for x, y in pts]
    b = [g.add_vert((x, y, z1)) for x, y in pts]
    g.add_face(tuple(reversed(a)), mat, False)
    g.add_face(tuple(b), mat, False)
    for i in range(n):
        j = (i + 1) % n
        g.add_face((a[i], a[j], b[j], b[i]), mat, False)
    return g


def _leaf(p0, d, length, w, t=0.008, mat='vcol', up=(0, 1, 0), curl=0.0):
    """Folha/pena: losango comprido saindo de p0 na direcao d. curl entorta a ponta (no plano de up)."""
    p0 = Vector(p0)
    d = Vector(d).normalized()
    side = Vector(up).cross(d).normalized()
    path, rad = [], []
    for u, kw, kt in ((0.0, 0.30, 0.6), (0.38, 1.0, 1.0), (0.74, 0.72, 0.8), (1.0, 0.04, 0.2)):
        path.append(p0 + d * (length * u) + side * (curl * u * u))
        rad.append((w * kw, t * kt))
    return tube(path, rad, 4, mat, up=up)


def _grip(z0, z1, r=0.021, mat='leather', n=6, wraps=3):
    """Cabo em gomos (tira enrolada)."""
    secs = []
    for i in range(wraps):
        a = z0 + (z1 - z0) * i / wraps
        b = z0 + (z1 - z0) * (i + 1) / wraps
        secs += [(a, r * 0.84, r * 0.84), ((a + b) / 2, r, r)]
    secs.append((z1, r * 0.84, r * 0.84))
    g = stack(secs, n, mat)
    return g.grad('z', z0, z1, COOL, lp.WHITE)


def _band(z, r, h=0.016, mat='accent', n=6, center=(0, 0)):
    """Anel/abracadeira chanfrada em volta do cabo."""
    return stack([(z - h / 2, r * 0.9, r * 0.9, center[0], center[1]), (z - h / 4, r, r, center[0], center[1]),
                  (z + h / 4, r, r, center[0], center[1]), (z + h / 2, r * 0.9, r * 0.9, center[0], center[1])], n, mat)


# ================================================================= espadas
@piece('weapon', 'sword_ferro', 'Espada de Ferro', wt='sword')
def sword_ferro():
    g = Geo()
    blade = stack([(0.09, 0.050, 0.014), (0.50, 0.044, 0.012), (0.60, 0.028, 0.008), (0.68, 0.002, 0.002)], 4, 'metal')
    blade.grad('z', 0.09, 0.68, (0.80, 0.80, 0.90), lp.WHITE)
    g.add(blade)
    g.add(box(0.21, 0.046, 0.04, 'vcol', center=(0, 0, 0.075)).color(lp.hexc('#e9b949')))
    g.add(cyl(0.02, 0.12, 6, 'leather', center=(0, 0, 0.0)))
    g.add(ellipsoid(0.032, 0.032, 0.028, 6, 4, 'vcol', center=(0, 0, -0.075)).color(lp.hexc('#e9b949')))
    return to_hand(g, 'R')


@piece('weapon', 'sword_runa', 'Lâmina Rúnica', wt='sword', rarity=2, cost=450)
def sword_runa():
    g = Geo()
    c_lo, c_mid, c_hi = lp.hexc('#3b2f9e'), lp.hexc('#2d7fd6'), lp.hexc('#93efff')
    # lamina: caco de cristal anguloso, com a ponta em cinzel fora do centro
    bl = _blade([(0.100, 0.030, 0.030, 0.012),
                 (0.172, 0.066, 0.060, 0.018),
                 (0.470, 0.060, 0.074, 0.017, 0.004),
                 (0.615, 0.056, 0.040, 0.013, -0.004),
                 (0.785, 0.003, 0.003, 0.003, -0.036)], 'vcol')
    _ramp(bl, 'z', [(0.10, c_lo), (0.42, c_mid), (0.78, c_hi)])
    bl.tint(lambda p, c: lp.mixc(c, c_hi, 0.5) if abs(p.y) < 1e-5 else c)   # gumes claros
    g.add(bl)
    # runas acesas embutidas no miolo (atravessam a lamina)
    runes = [
        [(0.0, 0.200), (0.020, 0.245), (0.0, 0.290), (-0.020, 0.245)],
        [(0.0, 0.335), (0.024, 0.318), (0.024, 0.345), (0.0, 0.392), (-0.024, 0.345), (-0.024, 0.318)],
        [(0.004, 0.430), (0.022, 0.470), (0.004, 0.540), (-0.014, 0.470)],
    ]
    for pts in runes:
        g.add(poly_extrude(pts, 0.043, 'glow').color(LUMEN))
    # guarda: asas de aco escuro abracando a base do cristal
    wing = _sym([(0.0, 0.048), (0.040, 0.054), (0.094, 0.084), (0.132, 0.160), (0.074, 0.120), (0.032, 0.110),
                 (0.0, 0.116)])
    gd = _plate(wing, 0.050, 0.011, 'metal').color(STEEL_D)
    gd.grad('z', 0.05, 0.16, lp.WHITE, (1.9, 1.9, 1.7))
    g.add(gd)
    g.add(_stud(0.026, 0.026, 0.042, 4).move(0, 0, 0.084).color(LUMEN_MID))
    # cabo e pomo de cristal
    g.add(_grip(-0.064, 0.052, 0.021, 'leather'))
    g.add(_band(-0.066, 0.027, 0.018, 'metal').color(STEEL_D))
    g.add(_crystal(0.026, 0.075, 5, 'glow').rot('X', 180).move(0, 0, -0.068).color(LUMEN_MID))
    return to_hand(g, 'R')


@piece('weapon', 'sword_solar', 'Lâmina Solar', wt='sword', rarity=3, cost=900)
def sword_solar():
    g = Geo()
    # contorno de chama: cada gume cresce e corta para dentro, alternando os lados
    right = [(0.105, 0.028), (0.145, 0.050), (0.235, 0.076), (0.252, 0.044), (0.455, 0.066), (0.472, 0.036),
             (0.660, 0.046), (0.805, 0.003)]
    left = [(0.105, 0.028), (0.145, 0.048), (0.345, 0.074), (0.362, 0.042), (0.565, 0.058), (0.582, 0.030),
            (0.805, 0.003)]
    peak_r, peak_l = (0.235, 0.455), (0.345, 0.565)
    secs = []
    for z in sorted({z for z, _ in right} | {z for z, _ in left}):
        t = (z - 0.105) / 0.70
        th = 0.016 * (1.0 - 0.8 * max(0.0, (t - 0.55) / 0.45) ** 1.5) + 0.001
        cx = 0.012 * math.sin(t * TAU * 0.85) * t
        secs.append((z, _pl(z, left), _pl(z, right), th, cx,
                     0.036 if z in peak_l else 0.0, 0.036 if z in peak_r else 0.0))
    bl = _blade(secs, 'vcol', core=0.40)
    edge = [(0.10, lp.hexc('#c9301c')), (0.45, lp.hexc('#f06a1c')), (0.80, lp.hexc('#ffc93a'))]
    flat = [(0.10, lp.hexc('#f07a1e')), (0.45, lp.hexc('#ffa92e')), (0.80, lp.hexc('#ffe58a'))]
    bl.tint(lambda p, c: _pl_c(p.z, edge) if abs(p.y) < 1e-5 else _pl_c(p.z, flat))
    g.add(bl)
    # alma de luz: chama interna que atravessa o miolo
    core = poly_extrude([(0.0, 0.160), (0.015, 0.210), (0.007, 0.320), (0.016, 0.400), (0.005, 0.590),
                         (-0.009, 0.470), (-0.015, 0.350), (-0.006, 0.270), (-0.016, 0.205)], 0.038, 'glow')
    core.warp(lambda p: Vector((p.x, p.y * (1.0 if p.z < 0.5 else 0.62), p.z)))
    g.add(_ramp(core, 'z', [(0.16, lp.hexc('#ff8a2a')), (0.60, lp.hexc('#ffd257'))]))
    # guarda: sol nascente entre dois chifres dourados
    arc = []
    rad = []
    for i in range(9):
        a = math.radians(198 + (342 - 198) * i / 8)
        arc.append((0.128 * math.cos(a), 0, 0.196 + 0.128 * math.sin(a)))
        k = math.sin(math.pi * i / 8) ** 0.7
        rad.append((0.006 + 0.020 * k, 0.006 + 0.019 * k))
    gold = tube(arc, rad, 6, 'vcol', up=(0, 1, 0))
    gold.add(lathe([(0.0, -0.029), (0.042, -0.029), (0.052, 0.0), (0.042, 0.029), (0.0, 0.029)], 8, 'vcol',
                   smooth=False).rot('X', 90).move(0, 0, 0.094))
    gold.add(_band(-0.066, 0.028, 0.018, 'vcol'))
    gold.add(_gem(0.031, 0.070, 6, 'vcol', lo=0.42).rot('X', 180).move(0, 0, -0.092))
    gold.color(GOLD)
    gold.grad('z', -0.13, 0.16, (0.78, 0.64, 0.62), (1.10, 1.08, 0.98))
    g.add(gold)
    g.add(_stud(0.028, 0.030, 0.048, 6).move(0, 0, 0.094).color(lp.hexc('#f03a14')))
    g.add(_grip(-0.064, 0.050, 0.021, 'leather'))
    return to_hand(g, 'R')


def _pl_c(x, stops):
    if x <= stops[0][0]:
        return stops[0][1]
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if x <= b:
            return lp.mixc(ca, cb, (x - a) / (b - a))
    return stops[-1][1]


# ================================================================= arcos
def _bow_limbs(half, radii, n=6, mat='vcol'):
    """half = [(x, z), ...] do punho (z=0) ate a ponta de cima; espelha para baixo.
    radii = [(espessura no plano do arco, largura em Y), ...]."""
    path = [(x, 0, -z) for x, z in reversed(half[1:])] + [(x, 0, z) for x, z in half]
    rr = list(reversed(radii[1:])) + list(radii)
    return tube(path, rr, n, mat, up=(0, 1, 0))


def _bow_string(x, z, mat='vcol', color=STRING, r=0.004):
    return tube([(x, 0, -z), (x, 0, z)], r, 4, mat, up=(0, 1, 0)).color(color)


@piece('weapon', 'bow_madeira', 'Arco de Madeira', wt='bow')
def bow_madeira():
    half = [(0.002, 0.0), (0.006, 0.075), (-0.004, 0.165), (-0.036, 0.265), (-0.086, 0.350), (-0.126, 0.410),
            (-0.138, 0.445), (-0.116, 0.480)]
    rad = [(0.026, 0.028), (0.025, 0.031), (0.021, 0.035), (0.018, 0.034), (0.016, 0.029), (0.014, 0.023),
           (0.014, 0.019), (0.009, 0.012)]
    g = _bow_limbs(half, rad)
    _ramp(g, 'z', [(0.0, WOOD_LO), (0.12, WOOD), (0.36, WOOD_HI), (0.420, WOOD_HI), (0.448, IVORY)], fn=abs)
    g.add(_bow_string(-0.127, 0.470))
    # punho de couro e amarras
    g.add(_grip(-0.068, 0.068, 0.034, 'leather', wraps=3).move(0.004, 0, 0))
    for s in (1, -1):
        g.add(_band(0.090 * s, 0.037, 0.022, 'accent', center=(0.005, 0)))
        g.add(_band(0.424 * s, 0.023, 0.018, 'accent', 5, center=(-0.131, 0)))
    return to_hand(g, 'L')


@piece('weapon', 'bow_elfico', 'Arco Élfico', wt='bow', rarity=1, cost=220)
def bow_elfico():
    half = [(0.004, 0.0), (0.014, 0.070), (0.008, 0.150), (-0.020, 0.235), (-0.074, 0.320), (-0.126, 0.385),
            (-0.150, 0.430), (-0.142, 0.462), (-0.112, 0.486)]
    rad = [(0.024, 0.026), (0.023, 0.030), (0.019, 0.034), (0.016, 0.033), (0.014, 0.028), (0.013, 0.022),
           (0.012, 0.018), (0.011, 0.014), (0.007, 0.009)]
    g = _bow_limbs(half, rad)
    birch, birch_lo = lp.hexc('#efe3c6'), lp.hexc('#b9a27c')
    _ramp(g, 'z', [(0.0, birch_lo), (0.14, birch), (0.40, birch), (0.47, lp.hexc('#c7e28a'))], fn=abs)
    g.add(_bow_string(-0.122, 0.478, color=lp.hexc('#e8f6c8')))
    g.add(_grip(-0.064, 0.064, 0.032, 'leather', wraps=3).move(0.008, 0, 0))
    for s in (1, -1):
        g.add(_band(0.086 * s, 0.036, 0.022, 'accent', center=(0.013, 0)))
        # folhas brotando da ponta e do ombro do arco
        lf = Geo()
        lf.add(_leaf((-0.146, 0.004, 0.425), (0.50, -0.25, 0.83), 0.165, 0.040, 0.010, up=(0.3, 1, 0), curl=0.02))
        lf.add(_leaf((-0.130, -0.004, 0.388), (0.92, 0.30, 0.25), 0.120, 0.032, 0.009, up=(0.2, 1, 0.2), curl=-0.015))
        lf.add(_leaf((0.012, 0.0, 0.105), (0.80, 0.0, 0.60), 0.095, 0.028, 0.009, up=(0, 1, 0)))
        _ramp(lf, 'x', [(-0.15, LEAF_LO), (0.0, LEAF)])
        lf.grad('z', 0.0, 0.5, (0.86, 0.9, 0.95), (1.08, 1.06, 0.95))
        if s < 0:
            lf.scale(1, 1, -1)
        g.add(lf)
    # gema verde no ventre do arco
    g.add(_gem(0.022, 0.046, 4, 'glow', lo=0.5).rot('Y', 90).move(0.040, 0, 0.0).color(lp.hexc('#2fc04a')))
    return to_hand(g, 'L')


@piece('weapon', 'bow_celeste', 'Arco Celeste', wt='bow', rarity=3, cost=950)
def bow_celeste():
    half = [(0.006, 0.0), (0.018, 0.070), (0.014, 0.150), (-0.012, 0.240), (-0.064, 0.330), (-0.116, 0.400),
            (-0.140, 0.446), (-0.124, 0.490)]
    rad = [(0.026, 0.028), (0.025, 0.031), (0.022, 0.034), (0.019, 0.032), (0.016, 0.027), (0.014, 0.022),
           (0.013, 0.018), (0.007, 0.009)]
    g = _bow_limbs(half, rad)
    _ramp(g, 'z', [(0.0, GOLD_LO), (0.12, GOLD), (0.44, GOLD_HI)], fn=abs)
    g.add(_bow_string(-0.130, 0.480, 'glow', lp.hexc('#9fe9f7'), r=0.005))
    g.add(_grip(-0.062, 0.062, 0.032, 'leather', wraps=3).move(0.010, 0, 0))
    for s in (1, -1):
        w = Geo()
        # asa: tres penas abrindo para a frente do arco, com um veio de luz em cada
        vein = Geo()
        for p0, d, ln, wd in (((0.014, 0, 0.165), (0.80, 0, 0.60), 0.200, 0.044),
                              ((-0.026, 0, 0.275), (0.66, 0, 0.75), 0.175, 0.040),
                              ((-0.086, 0, 0.368), (0.46, 0, 0.89), 0.140, 0.034)):
            w.add(_leaf(p0, d, ln, wd, 0.011, 'vcol'))
            vein.add(_leaf(Vector(p0) + Vector(d).normalized() * 0.02, d, ln * 0.72, wd * 0.36, 0.015, 'glow'))
        _ramp(w, 'x', [(-0.06, lp.hexc('#4d8fe6')), (0.02, lp.hexc('#a9d8ff')), (0.12, lp.hexc('#f2fbff'))])
        w.add(vein.color(LUMEN_MID))
        w.add(_band(0.092, 0.037, 0.024, 'vcol', center=(0.018, 0)).color(GOLD_HI))
        # estrela na ponta
        w.add(_star(4, 0.044, 0.016, 0.026, 'glow').move(-0.128, 0, 0.502).color(lp.hexc('#ffe27a')))
        if s < 0:
            w.scale(1, 1, -1)
        g.add(w)
    return to_hand(g, 'L')


# ================================================================= cajados
STAFF_TURN = 90   # gira o enfeite do cajado para ficar de frente (visto pela frente/costas do heroi)


@piece('weapon', 'staff_aprendiz', 'Cajado de Aprendiz', wt='staff')
def staff_aprendiz():
    g = Geo()
    # haste torta que termina num gancho em espiral abracando o cristal
    path = [(0.0, 0, -0.45), (0.006, 0, -0.25), (-0.004, 0, 0.0), (0.004, 0, 0.19), (0.000, 0, 0.30),
            (0.014, 0, 0.365)]
    rad = [0.020, 0.024, 0.024, 0.025, 0.026, 0.025]
    cz, n, R = 0.495, 10, 0.098
    for i in range(n + 1):
        a = math.radians(300 + 300 * i / n)
        r = R - 0.034 * (i / n) ** 1.4
        path.append((r * math.cos(a), 0, cz + r * math.sin(a)))
        rad.append(0.024 - 0.012 * (i / n))
    wood = tube(path, rad, 6, 'vcol', up=(0, 1, 0))
    _ramp(wood, 'z', [(-0.45, WOOD_LO), (-0.1, WOOD), (0.45, WOOD_HI)])
    g.add(wood)
    cr = _gem(0.043, 0.140, 5, 'glow', lo=0.42).rot('Y', 10).move(0, 0, cz - 0.004)
    g.add(_ramp(cr, 'z', [(cz - 0.06, LUMEN_LO), (cz + 0.02, LUMEN_MID), (cz + 0.08, LUMEN)]))
    # faixa de couro, amarras e ponteira
    g.add(stack([(0.205, 0.029, 0.029, 0.003, 0), (0.285, 0.030, 0.030, 0.001, 0)], 6, 'leather'))
    g.add(_band(0.202, 0.034, 0.018, 'accent', center=(0.003, 0)))
    g.add(_band(0.288, 0.035, 0.018, 'accent', center=(0.001, 0)))
    g.add(lathe([(0.0, -0.480), (0.024, -0.44), (0.026, -0.40), (0.0, -0.395)], 6, 'metal').color(IRON))
    # um broto teimoso
    lf = _leaf((0.016, 0.0, 0.335), (0.85, -0.2, 0.5), 0.095, 0.028, 0.008, up=(0.2, 1, 0))
    g.add(_ramp(lf, 'x', [(0.02, LEAF_LO), (0.10, LEAF)]))
    return to_hand(g.rot('Z', STAFF_TURN), 'R')


@piece('weapon', 'staff_lunar', 'Cajado Lunar', wt='staff', rarity=2, cost=420)
def staff_lunar():
    g = Geo()
    sh = stack([(-0.45, 0.014, 0.014), (-0.40, 0.021, 0.021), (0.0, 0.021, 0.021), (0.33, 0.023, 0.023)], 6, 'vcol')
    _ramp(sh, 'z', [(-0.45, NIGHT_LO), (0.34, NIGHT)])
    g.add(sh)
    for z in (-0.38, 0.105, 0.29):
        g.add(_band(z, 0.030, 0.022, 'metal'))
    g.add(lathe([(0.0, -0.495), (0.023, -0.45), (0.0, -0.44)], 6, 'metal'))
    # lua crescente facetada, tombada, com uma estrela no colo
    cz, R = 0.478, 0.122
    arc, rad = [], []
    for i in range(13):
        a = math.radians(136 + (404 - 136) * i / 12)
        arc.append((R * math.cos(a), 0, cz + R * math.sin(a)))
        k = math.sin(math.pi * i / 12) ** 0.8
        rad.append((0.004 + 0.043 * k, 0.004 + 0.019 * k))
    moon = tube(arc, rad, 4, 'metal', up=(0, 1, 0)).flat()
    moon.grad('z', cz - R, cz + R, (0.80, 0.80, 0.96), (1.1, 1.1, 1.06))
    moon.rot('Y', -16, pivot=(0, 0, cz))
    g.add(moon)
    g.add(lathe([(0.024, 0.300), (0.036, 0.322), (0.028, 0.345), (0.0, 0.352)], 6, 'metal'))
    g.add(_star(5, 0.066, 0.029, 0.040, 'glow').rot('Y', -16).move(0.010, 0, cz + 0.016).color(lp.hexc('#ffd95e')))
    return to_hand(g.rot('Z', STAFF_TURN), 'R')


@piece('weapon', 'staff_lumen', 'Cetro do Lúmen', wt='staff', rarity=3, cost=1000)
def staff_lumen():
    g = Geo()
    sh = stack([(-0.44, 0.018, 0.018), (0.0, 0.021, 0.021), (0.31, 0.024, 0.024)], 6, 'vcol')
    _ramp(sh, 'z', [(-0.44, lp.hexc('#c9bcae')), (0.31, IVORY)])
    g.add(sh)
    gold = Geo()
    for z in (-0.36, -0.10, 0.11, 0.26):
        gold.add(_band(z, 0.030, 0.024, 'vcol'))
    gold.add(lathe([(0.0, -0.50), (0.027, -0.44), (0.0, -0.425)], 6, 'vcol'))
    # calice que segura o cristal
    gold.add(lathe([(0.023, 0.295), (0.040, 0.322), (0.030, 0.348), (0.060, 0.392), (0.050, 0.400), (0.0, 0.380)],
                   8, 'vcol'))
    # aneis de armilar
    cz = 0.492
    r1 = _torus(0.128, 0.012, 14, 4, 'vcol').rot('X', 90).rot('Y', 24)
    r2 = _torus(0.110, 0.011, 14, 4, 'vcol').rot('X', 90).rot('Z', 78).rot('Y', -30)
    gold.add(r1.move(0, 0, cz)).add(r2.move(0, 0, cz))
    gold.color(GOLD)
    gold.grad('z', -0.5, 0.62, (0.80, 0.68, 0.66), (1.10, 1.08, 0.98))
    g.add(gold)
    cr = _gem(0.064, 0.220, 6, 'glow', lo=0.44).move(0, 0, cz)
    _ramp(cr, 'z', [(cz - 0.10, LUMEN_LO), (cz + 0.02, LUMEN_MID), (cz + 0.12, LUMEN)])
    g.add(cr)
    for (x, y, z, r, h, tilt) in ((0.150, 0.02, 0.600, 0.018, 0.064, 20), (-0.160, -0.03, 0.520, 0.015, 0.052, -25),
                                  (-0.075, 0.05, 0.665, 0.013, 0.044, -10)):
        g.add(_gem(r, h, 4, 'glow', lo=0.4).rot('Y', tilt).move(x, y, z).color(LUMEN_MID))
    return to_hand(g.rot('Z', STAFF_TURN), 'R')


# ================================================================= martelos + escudos
SHIELD_X = 0.37     # centro do escudo ao longo do antebraco
SHIELD_Z = 0.748    # costas do escudo (0,058 acima do eixo do braco)


def _mount_shield(sh):
    """Leva um escudo modelado deitado (costas em z=0, face +Z) ate o antebraco esquerdo."""
    sh.move(SHIELD_X, 0, SHIELD_Z)
    # bracadeira de couro em volta do antebraco
    strap = lathe([(0.036, -0.022), (0.064, -0.022), (0.064, 0.022), (0.036, 0.022), (0.036, -0.022)], 8, 'leather')
    strap.rot('Y', 90).move(SHIELD_X, 0, 0.69)
    strap.color((0.78, 0.74, 0.86))
    sh.add(strap)
    return sh.bind('forearm.L')


def _stand_to_arm(sh, drop=0.02):
    """Escudo modelado de pe (XZ, frente -Y, ponta para baixo) -> deitado no antebraco:
    a frente vira +Z e a ponta vai para +Y (que aponta para o chao na guarda)."""
    return sh.rot('X', -90).rot('Z', 180).move(0, drop, 0)


def _haft(z0, z1, r0, r1, color_lo, color_hi, n=6):
    g = stack([(z0, r0, r0), ((z0 + z1) / 2, (r0 + r1) / 2 * 0.94, (r0 + r1) / 2 * 0.94), (z1, r1, r1)], n, 'vcol')
    return _ramp(g, 'z', [(z0, color_lo), (z1, color_hi)])


def _shield_madeira():
    R = 0.186
    sh = Geo()
    sh.add(cyl(R - 0.006, 0.014, 12, 'vcol', center=(0, 0, 0.007)).color(lp.mulc(WOOD_LO, 0.7)))
    # tabuas ao longo do braco; a do meio pintada na cor de detalhe
    ys = [-0.94 * R, -0.58 * R, -0.20 * R, 0.20 * R, 0.58 * R, 0.94 * R]
    tones = [WOOD, WOOD_HI, None, WOOD_HI, WOOD]
    lift = [0.0, 0.003, 0.001, 0.004, 0.0]
    for i in range(5):
        y0, y1 = ys[i] + 0.003, ys[i + 1] - 0.003
        ym = (y0 + y1) / 2

        def hw(y):
            return math.sqrt(max(R * R - y * y, 0.0)) - 0.004
        pts = [(-hw(y0), y0), (hw(y0), y0), (hw(ym), ym), (hw(y1), y1), (-hw(y1), y1), (-hw(ym), ym)]
        pl = _prism(pts, 0.010, 0.030 + lift[i], 'accent' if tones[i] is None else 'vcol')
        pl.color((0.92, 0.9, 0.95) if tones[i] is None else tones[i])
        pl.grad('x', -R, R, (0.80, 0.76, 0.88), (1.06, 1.05, 1.0))
        sh.add(pl)
    # aro, travessa e broquel de ferro
    iron = Geo()
    iron.add(lathe([(R - 0.024, 0.0), (R + 0.006, 0.0), (R + 0.006, 0.030), (R - 0.004, 0.042), (R - 0.024, 0.040),
                    (R - 0.024, 0.0)], 12, 'metal'))
    iron.add(box(0.050, 2 * R - 0.03, 0.012, 'metal', center=(0, 0, 0.037)))
    iron.add(lathe([(0.070, 0.034), (0.066, 0.050), (0.044, 0.072), (0.0, 0.082)], 8, 'metal'))
    iron.color((0.36, 0.38, 0.54))
    sh.add(iron)
    return sh


@piece('weapon', 'hammer_ferro', 'Maça e Broquel', wt='hammer')
def hammer_ferro():
    g = Geo()
    g.add(_haft(-0.10, 0.30, 0.022, 0.023, WOOD_LO, WOOD_HI))
    g.add(_grip(-0.066, 0.062, 0.026, 'leather'))
    g.add(ellipsoid(0.033, 0.033, 0.027, 6, 4, 'metal', center=(0, 0, -0.105)).color(IRON))
    # cabeca: bola de ferro com cravos grandes
    c = Vector((0, 0, 0.378))
    iron = Geo()
    iron.add(lathe([(0.025, 0.258), (0.043, 0.278), (0.036, 0.300)], 6, 'metal'))
    iron.add(ellipsoid(0.094, 0.094, 0.088, 8, 5, 'metal', center=tuple(c)))
    dirs = [(0, 0, 1)]
    for i in range(6):
        a = TAU * i / 6
        dirs.append((math.cos(a), math.sin(a), 0.12))
    for i in range(3):
        a = TAU * (i + 0.5) / 3
        dirs.append((math.cos(a) * 0.72, math.sin(a) * 0.72, 0.72))
    iron.color(IRON)
    for d in dirs:
        dv = Vector(d).normalized()
        iron.add(_aim(cone(0.040, 0.066, 4, 'metal', smooth=False), dv, c + dv * 0.074).color((0.74, 0.76, 0.90)))
    iron.grad('z', 0.27, 0.50, (0.80, 0.78, 0.96), (1.25, 1.25, 1.18))
    g.add(iron)
    to_hand(g, 'R')
    return g.add(_mount_shield(_shield_madeira()))


def _shield_kite():
    # contorno (x, z) de pe: ponta para baixo
    out = _sym([(0.0, -0.250), (0.060, -0.185), (0.118, -0.085), (0.150, 0.030), (0.158, 0.130), (0.150, 0.178),
                (0.075, 0.190), (0.0, 0.205)])
    sh = Geo()
    rim = _plate(out, 0.034, 0.010, 'metal')
    rim.color((0.80, 0.81, 0.92))
    sh.add(rim)
    field = _plate(_inset(out, 0.024), 0.050, 0.008, 'vcol')
    _ramp(field, 'z', [(-0.25, lp.hexc('#27337f')), (0.2, lp.hexc('#3f63c9'))])
    sh.add(field)
    # brasao: estrela de quatro pontas na cor de detalhe, em relevo sobre o campo
    sh.add(_star(4, 0.120, 0.040, 0.036, 'accent').scale(0.82, 1.0, 1.12).move(0, -0.025, 0.006))
    _stand_to_arm(sh)
    return sh.move(0, 0, 0.025)


@piece('weapon', 'hammer_cavaleiro', 'Martelo de Cavaleiro', wt='hammer', rarity=1, cost=260)
def hammer_cavaleiro():
    g = Geo()
    g.add(_haft(-0.10, 0.34, 0.021, 0.022, lp.hexc('#4f3226'), lp.hexc('#7d5138')))
    g.add(_grip(-0.066, 0.062, 0.025, 'leather'))
    g.add(_gem(0.031, 0.058, 6, 'metal', lo=0.5).move(0, 0, -0.112).color((0.8, 0.8, 0.92)))
    # cabeca: bloco de aco com duas bocas largas e faixas na cor de detalhe
    hz = 0.37
    head = stack([(-0.160, 0.066, 0.066, 0, 0, 0.55), (-0.146, 0.082, 0.082, 0, 0, 0.55),
                  (-0.100, 0.082, 0.082, 0, 0, 0.55), (-0.078, 0.056, 0.056, 0, 0, 0.55),
                  (0.078, 0.056, 0.056, 0, 0, 0.55), (0.100, 0.082, 0.082, 0, 0, 0.55),
                  (0.146, 0.082, 0.082, 0, 0, 0.55), (0.160, 0.066, 0.066, 0, 0, 0.55)], 8, 'metal', phase=0.5)
    head.color((0.84, 0.84, 0.96))
    for s in (1, -1):
        head.add(stack([(0.060 * s - 0.012, 0.062, 0.062, 0, 0, 0.55), (0.060 * s + 0.012, 0.062, 0.062, 0, 0, 0.55)],
                       8, 'accent', phase=0.5))
    head.rot('Y', 90).move(0, 0, hz)
    head.grad('z', hz - 0.08, hz + 0.08, (0.78, 0.76, 0.94), (1.12, 1.12, 1.08))
    g.add(head)
    g.add(box(0.076, 0.132, 0.130, 'metal', center=(0, 0, hz), taper=0.86).color((0.30, 0.32, 0.48)))
    g.add(cone(0.040, 0.072, 4, 'metal', center=(0, 0, hz + 0.062), phase=0.5, smooth=False))
    g.add(_band(0.272, 0.030, 0.026, 'metal').color((0.30, 0.32, 0.48)))
    to_hand(g, 'R')
    return g.add(_mount_shield(_shield_kite()))


def _shield_aurora():
    out = _sym([(0.0, -0.262), (0.062, -0.190), (0.124, -0.075), (0.150, 0.040), (0.206, 0.196), (0.118, 0.150),
                (0.058, 0.186), (0.0, 0.226)])
    sh = Geo()
    rim = _plate(out, 0.036, 0.011, 'vcol').color(GOLD)
    rim.grad('z', -0.26, 0.22, (0.78, 0.64, 0.62), (1.10, 1.08, 0.98))
    sh.add(rim)
    field = _plate(_inset(out, 0.026), 0.052, 0.008, 'vcol')
    _ramp(field, 'z', [(-0.25, lp.hexc('#8fa3dc')), (-0.02, lp.hexc('#e9ecf7')), (0.2, lp.hexc('#fbf8ee'))])
    sh.add(field)
    # sol dourado em relevo com o cristal no centro
    sh.add(_star(8, 0.104, 0.064, 0.030, 'vcol').move(0, -0.026, 0.020).color(GOLD)
           .grad('z', -0.08, 0.12, (0.80, 0.66, 0.64), (1.08, 1.06, 0.98)))
    sh.add(_stud(0.046, 0.010, 0.034, 6).move(0, -0.036, 0.020).color(LUMEN_MID))
    sh.add(_stud(0.018, 0.006, 0.016, 4).move(0, -0.028, -0.150).color(LUMEN_MID))
    _stand_to_arm(sh)
    return sh.move(0, 0, 0.026)


@piece('weapon', 'hammer_aurora', 'Martelo da Aurora', wt='hammer', rarity=3, cost=1000)
def hammer_aurora():
    g = Geo()
    g.add(_haft(-0.10, 0.34, 0.021, 0.022, lp.hexc('#c9bcae'), IVORY))
    g.add(_grip(-0.066, 0.062, 0.025, 'leather'))
    hz = 0.375
    gold = Geo()
    gold.add(_gem(0.032, 0.062, 6, 'vcol', lo=0.5).move(0, 0, -0.114))
    gold.add(_band(0.270, 0.031, 0.026, 'vcol'))
    for s in (1, -1):
        cap = stack([(0.056, 0.058, 0.058, 0, 0, 0.3), (0.078, 0.086, 0.086, 0, 0, 0.3),
                     (0.140, 0.092, 0.092, 0, 0, 0.3), (0.160, 0.072, 0.072, 0, 0, 0.3)], 8, 'vcol', phase=0.5)
        cap.rot('Y', 90 * s).move(0, 0, hz)
        gold.add(cap)
    gold.add(stack([(hz - 0.076, 0.040, 0.050, 0, 0, 0.4), (hz + 0.076, 0.034, 0.044, 0, 0, 0.4),
                    (hz + 0.094, 0.048, 0.048)], 8, 'vcol', phase=0.5))
    gold.color(GOLD)
    gold.grad('z', hz - 0.09, hz + 0.09, (0.80, 0.66, 0.64), (1.10, 1.08, 0.98))
    g.add(gold)
    # miolo de cristal aceso entre as duas bocas
    core = stack([(-0.060, 0.058, 0.058), (0.0, 0.070, 0.070), (0.060, 0.058, 0.058)], 6, 'glow', cap_a=False,
                 cap_b=False).flat()
    core.rot('Y', 90).move(0, 0, hz)
    g.add(_ramp(core, 'z', [(hz - 0.07, LUMEN_LO), (hz + 0.07, LUMEN_MID)]))
    cr = _crystal(0.036, 0.110, 5, 'glow').move(0, 0, hz + 0.088)
    g.add(_ramp(cr, 'z', [(hz + 0.09, LUMEN_LO), (hz + 0.20, LUMEN)]))
    to_hand(g, 'R')
    return g.add(_mount_shield(_shield_aurora()))

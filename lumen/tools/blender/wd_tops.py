"""wd_tops.py: roupas de cima (tronco + bracos).

Toda peca traz o tronco e os dois bracos (pele onde aparece pele). As maos sao fixas, entao
manga comprida termina num punho perto de x=0.435. Quem nao tem saiote ganha uma barra larga
em z~0.36-0.40 para esconder o encaixe das pernas, e as costas ficam abaixo de y~0.125 entre
a cintura e os ombros para sobrar espaco para as pecas de costas.
"""
import math

from mathutils import Vector

import lp
from lp import Geo, box, cone, cyl, ellipsoid, icosphere, lathe, loft, merge, poly_extrude, ring_pts, sheet, stack, tube
import hero_body as hb
from hero_body import HEAD_C, HEAD_R
import wd_base
from wd_base import piece, scalp, hair_cap, tuft, hair_shade, skirt_weights, belt, to_hand

AZ = 0.69                                   # altura do eixo do braco em T
SHX, ELX, WRX = hb.SHOULDER.x, hb.ELBOW_X, hb.WRIST_X
FRIO = (0.70, 0.66, 0.80)                   # sombra fria (multiplicador)
OURO = lp.hexc('#f4c542')
OURO_E = lp.hexc('#b9781c')
RUBI = lp.hexc('#e0455a')
AGUA = lp.hexc('#58e0d0')


# ================================================================= ajudantes
def _ss(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def _pt(s, a):
    """Ponto da secao (z, rx, ry, cx, cy, sq) no angulo a (graus: 0 = +X, 90 = costas, -90 = frente)."""
    e = 1.0 - 0.75 * (s[5] if len(s) > 5 else 0.0)
    c, sn = math.cos(math.radians(a)), math.sin(math.radians(a))
    return Vector(((s[3] if len(s) > 3 else 0.0) + math.copysign(abs(c) ** e, c) * s[1],
                   (s[4] if len(s) > 4 else 0.0) + math.copysign(abs(sn) ** e, sn) * s[2], s[0]))


def _par(secs, z):
    z = max(secs[0][0], min(secs[-1][0], z))
    s0, s1 = secs[0], secs[1]
    for s0, s1 in zip(secs, secs[1:]):
        if z <= s1[0]:
            break
    t = (z - s0[0]) / (s1[0] - s0[0]) if s1[0] > s0[0] else 0.0
    return s0, s1, t, z


def _sec(secs, z, off=0.0):
    """Secao interpolada na altura z, inflada em 'off'."""
    s0, s1, t, z = _par(secs, z)
    v = [s0[i] + (s1[i] - s0[i]) * t for i in range(1, 6)]
    return (z, v[0] + off, v[1] + off, v[2], v[3], v[4])


def _sup(secs, a, z, off=0.0, n=10, phase=0.0):
    """Ponto na superficie de um loft vertical, no angulo a e altura z, afastado 'off' para fora.
    n > 0 segue as facetas do loft de n lados; n = 0 usa a curva lisa."""
    s0, s1, t, z = _par(secs, z)
    if n <= 0:
        p = _pt(s0, a).lerp(_pt(s1, a), t)
        if off:
            q = _pt(s0, a + 1.0).lerp(_pt(s1, a + 1.0), t) - _pt(s0, a - 1.0).lerp(_pt(s1, a - 1.0), t)
            p += Vector((q.y, -q.x, 0.0)).normalized() * off
        return p
    step = 360.0 / n
    u = a / step - phase
    i = math.floor(u)
    a0, a1 = (i + phase) * step, (i + 1 + phase) * step
    p0 = _pt(s0, a0).lerp(_pt(s1, a0), t)
    p1 = _pt(s0, a1).lerp(_pt(s1, a1), t)
    p = p0.lerp(p1, u - i)
    if off:
        d = p1 - p0
        p += Vector((d.y, -d.x, 0.0)).normalized() * off
    return p


def _frente(secs, x, z, off=0.0, n=10, phase=0.0, costas=False):
    """Ponto na frente (ou nas costas) do loft facetado, na coordenada x."""
    step = 360.0 / n
    for i in range(n):
        p0 = _sup(secs, (i + phase) * step, z, 0.0, 0)
        p1 = _sup(secs, (i + 1 + phase) * step, z, 0.0, 0)
        if ((p0.y + p1.y) > 1e-6) != costas:
            continue
        lo, hi = min(p0.x, p1.x), max(p0.x, p1.x)
        if hi - lo > 1e-9 and lo - 1e-6 <= x <= hi + 1e-6:
            d = p1 - p0
            return p0.lerp(p1, (x - p0.x) / d.x) + Vector((d.y, -d.x, 0.0)).normalized() * off
    return _sup(secs, 0.0 if x > 0 else 180.0, z, off, 0)


def _cinta(secs, z0, z1, off, mat, n=10, phase=0.0, ch=0.0, cap_a=False, arco=False):
    """Anel (cinto, barra) em volta de um loft; ch > 0 chanfra as bordas ate a superficie.
    arco=True usa a mesma divisao das cascas de _casca (comeca na frente), para nao furar."""
    rs = [_sec(secs, z0, off), _sec(secs, z1, off)]
    if ch > 0:
        rs = [_sec(secs, z0 - ch, -0.003)] + rs + [_sec(secs, z1 + ch, -0.003)]
    if arco:
        return _arco(rs, [(-90.0, 270.0)] * len(rs), n, mat, None, 0.0)
    return stack(rs, n, mat, cap_a=cap_a, cap_b=False, phase=phase)


def _folha(rows, mat, th=0.0, forro=None):
    """Como lp.sheet, mas sem forro cria so a borda grossa (dobrada para dentro), sem o verso:
    serve para cascas coladas no corpo, onde o lado de dentro nunca aparece."""
    if th <= 0 or forro:
        return sheet(rows, mat, forro, th)
    g = sheet(rows, mat)
    h, wd = len(rows), len(rows[0])
    nrm = lp._vertex_normals(g)
    border = [i for i in range(wd)] + [r * wd + wd - 1 for r in range(1, h)] + \
             [(h - 1) * wd + i for i in range(wd - 2, -1, -1)] + [r * wd for r in range(h - 2, 0, -1)]
    inner = {b: g.add_vert(g.v[b] - nrm[b] * th) for b in border}
    for i in range(len(border)):
        a0, a1 = border[i], border[(i + 1) % len(border)]
        g.add_face((a1, a0, inner[a0], inner[a1]), mat)
    return g


def _arco(secs, angs, n, mat, forro=None, th=0.012):
    """Casca cobrindo so um arco: secs de baixo para cima, angs = [(a0, a1)] por secao.
    Com forro ganha verso (abas soltas); sem forro so a borda grossa."""
    rows = [[_pt(s, a0 + (a1 - a0) * i / n) for i in range(n + 1)] for s, (a0, a1) in zip(secs, angs)]
    return _folha(rows, mat, th, forro)


def _casca(secs, n, mat, forro=None, th=0.012, gap=18.0):
    """Casca aberta na frente (colete, casaco): o indice 6 de cada secao e a meia abertura em graus."""
    angs = []
    for s in secs:
        g0 = s[6] if len(s) > 6 else gap
        angs.append((-90.0 + g0, 270.0 - g0))
    return _arco(secs, angs, n, mat, forro, th)


def _faixa(rows, mat, th=0.008, forro=None, fora=None):
    """Tira com espessura a partir de linhas de pontos; vira a face para fora do eixo do corpo."""
    rows = [[Vector(p) for p in r] for r in rows]
    a, b = rows[0], rows[1]
    nrm = (a[-1] - a[0]).cross(b[0] - a[0]) + (a[-1] - a[0]).cross(b[-1] - a[-1])
    c = (a[0] + a[-1] + b[0] + b[-1]) / 4.0
    ref = Vector(fora) if fora is not None else Vector((c.x, c.y, 0.0))
    if nrm.dot(ref) < 0:
        rows = [list(reversed(r)) for r in rows]
    return _folha(rows, mat, th, forro)


def _decal(pts, mat, fora=None):
    """Um poligono chapado (enfeite colado na superficie)."""
    pts = [Vector(p) for p in pts]
    g = Geo()
    ids = [g.add_vert(p) for p in pts]
    c = sum(pts, Vector()) / len(pts)
    nrm = (pts[1] - pts[0]).cross(pts[2] - pts[0])
    ref = Vector(fora) if fora is not None else Vector((c.x, c.y, 0.0))
    g.add_face(ids if nrm.dot(ref) >= 0 else list(reversed(ids)), mat)
    return g


def _pinta(g, fn):
    """Troca o material das faces: fn(centroide) -> nome ou None."""
    for i, f in enumerate(g.f):
        m = fn(sum((g.v[j] for j in f), Vector()) / len(f))
        if m:
            g.fm[i] = m
    return g


def _manga(secs, mat, n=8, cap_a=False, cap_b=False, sq=0.0):
    """Manga/braco esquerdo em T. secs = [(x, ry, rz[, dz[, dy]])...] com x crescente."""
    rings = []
    for s in secs:
        dz = s[3] if len(s) > 3 else 0.0
        dy = s[4] if len(s) > 4 else 0.0
        rings.append([(s[0], dy + a, AZ + dz + b) for a, b in reversed(ring_pts(n, s[1], s[2], sq))])
    return loft(rings, mat, cap_a, cap_b).bind_fn(hb.arm_weights)


def _boca(x, ry, rz, fundo=0.035, r_in=0.042, mat='dark', n=8, dz=0.0):
    """Fundo escuro da boca de uma manga larga (funil virado para a mao)."""
    g = _manga([(x - fundo, r_in, r_in), (x, ry, rz, dz)], mat, n).flip()
    return g.color((0.62, 0.58, 0.74))


def _antebraco(x0=0.275, mat='skin', r=0.047, n=8, x1=None, cap_b=True):
    """Antebraco de pele de x0 ate o pulso (ou ate x1)."""
    x1 = WRX + 0.012 if x1 is None else x1
    xs = [x for x in (0.275, 0.305, 0.335, 0.415) if x0 + 0.004 < x < x1 - 0.004]
    secs = [(x0, r, r)] + [(x, r * (0.97 if x == 0.305 else 1.0), r * (0.97 if x == 0.305 else 1.0)) for x in xs]
    secs.append((x1, r * 0.95, r * 0.95))
    g = _manga(secs, mat, n, cap_b=cap_b)
    return g.grad('x', SHX, WRX, lp.WHITE, (0.88, 0.84, 0.90))


def _tw(p):
    """Pesos do tronco pela altura (iguais aos de hb.bind_torso)."""
    z = p.z
    if z <= 0.43:
        return {'hips': 1.0}
    if z <= 0.52:
        t = _ss((z - 0.43) / 0.09)
        return {'hips': 1.0 - t, 'spine': t}
    if z <= 0.62:
        t = _ss((z - 0.52) / 0.10)
        return {'spine': 1.0 - t, 'chest': t}
    return {'chest': 1.0}


def _pesos(zlo, zhi=0.455, k=0.6):
    """Tronco + saia: abaixo de zhi os lados da barra acompanham as coxas (ate k na altura zlo)."""
    def fn(p):
        w = _tw(p)
        if p.z >= zhi:
            return w
        t = min(1.0, (zhi - p.z) / (zhi - zlo))
        s = min(1.0, abs(p.x) / 0.10) * t * k
        if s < 0.02:
            return w
        w = {b: v * (1.0 - s) for b, v in w.items()}
        w['thigh.L' if p.x > 0 else 'thigh.R'] = s
        return w
    return fn


def _orient(g, pos, nrm):
    """Gira o eixo Z da peca para a direcao nrm e leva ate pos."""
    q = Vector((0, 0, 1)).rotation_difference(Vector(nrm).normalized())
    g.xf(q.to_matrix().to_4x4())
    return g.move(*pos)


def _botao(pos, nrm, r=0.014, h=0.010, cor=OURO, n=5):
    g = stack([(-0.004, r, r), (h, r * 0.78, r * 0.78)], n, 'vcol', cap_a=False, cap_b='flat').color(cor)
    return _orient(g, pos, nrm)


def _gema(pos, nrm, r=0.02, h=0.016, mat='vcol', cor=AGUA, n=4, phase=0.0, esc=1.0):
    """Gema facetada (losango); esc alonga na vertical quando virada para a frente."""
    g = lathe([(r, -0.003), (r * 0.55, h * 0.7), (0.0, h)], n, mat, phase=phase).flat()
    g.scale(1.0, esc, 1.0)
    if cor is not None:
        g.color(cor)
    return _orient(g, pos, nrm)


def _laco(c, w=0.05, h=0.03, d=0.02, mat='accent', fora=(0, -1, 0)):
    """Lacinho: duas alcas gordinhas + no. Modelado no plano XZ, virado para 'fora'."""
    g = Geo()
    for s in (1, -1):
        g.add(stack([(-h * 0.5, w * 0.30, d * 0.5, s * w * 0.62, 0), (0.0, w * 0.46, d * 0.7, s * w * 0.56, 0),
                     (h * 0.5, w * 0.30, d * 0.5, s * w * 0.62, 0)], 4, mat, phase=0.5))
    g.add(box(w * 0.36, d * 1.5, h * 0.62, mat, taper=0.8))
    g.xf(Vector((0, -1, 0)).rotation_difference(Vector(fora).normalized()).to_matrix().to_4x4())
    return g.move(*c)


def _sombra(g, z0, z1, lo=FRIO):
    return g.grad('z', z0, z1, lo, lp.WHITE)


def _tampa(sec, n, mat, phase=0.0, arco=False):
    """Tampa de baixo de um saiote (leque virado para o chao)."""
    g = Geo()
    if arco:
        pts = [_pt(sec, -90.0 + 360.0 * i / n) for i in range(n)]
    else:
        pts = [_pt(sec, 360.0 * (i + phase) / n) for i in range(n)]
    c = g.add_vert(sum(pts, Vector()) / n)
    ids = [g.add_vert(p) for p in pts]
    for i in range(n):
        g.add_face((c, ids[(i + 1) % n], ids[i]), mat)
    return g.color((0.62, 0.58, 0.74))


def _cristal(base, tip, r, n=5, mat='glow', fase=0.0):
    """Estilhaco facetado da base ate a ponta."""
    base, tip = Vector(base), Vector(tip)
    ln = (tip - base).length
    g = lathe([(r * 0.55, 0.0), (r, ln * 0.30), (r * 0.70, ln * 0.74), (0.0, ln)], n, mat, phase=fase).flat()
    g.grad('z', 0.0, ln, (0.50, 0.58, 0.86), lp.WHITE)
    return _orient(g, base, tip - base)


# ================================================================= pecas
@piece('top', 'top_tunica', 'Túnica de Aventureiro')
def top_tunica():
    return wd_base.ref_top()


@piece('top', 'top_gibao', 'Gibão de Couro')
def top_gibao():
    g = hb.make_torso('secondary')
    g.keep_faces(lambda c: c.y < 0.01 or c.z > 0.67 or c.z < 0.39)
    # colete de couro com abas abaixo do cinto; abertura estreita amarrada no peito
    vs = [(0.350, 0.168, 0.138, 0, 0.004, 0.15, 9), (0.400, 0.158, 0.128, 0, 0.004, 0.2, 4),
          (0.455, 0.148, 0.118, 0, 0.003, 0.2, 0), (0.520, 0.141, 0.114, 0, 0.0, 0.2, 5),
          (0.610, 0.151, 0.116, 0, -0.002, 0.25, 10), (0.685, 0.143, 0.106, 0, 0.0, 0.3, 20),
          (0.728, 0.094, 0.080, 0, 0.0, 0.1, 44)]
    w = _pesos(0.35)
    vest = _casca(vs, 10, 'leather', None, 0.013)
    _sombra(vest, 0.35, 0.70)
    g.add(vest.bind_fn(w))
    g.add(_tampa(vs[0], 10, 'leather', arco=True).bind_fn(w))
    # cadarco: tres pontos grossos fechando o peito
    for z, hw in ((0.545, 0.024), (0.592, 0.030), (0.640, 0.037)):
        g.add(box(hw * 2, 0.014, 0.014, 'dark', center=(0, -0.117, z)).bind_fn(_tw))
    # cinto escuro com fivela grande
    g.add(_cinta(vs, 0.436, 0.480, 0.007, 'dark', 10, arco=True).bind('hips'))
    fiv = box(0.056, 0.020, 0.056, 'vcol', center=(0, -0.127, 0.458)).color(OURO)
    fiv.add(box(0.028, 0.024, 0.028, 'vcol', center=(0, -0.129, 0.458)).color(OURO_E))
    g.add(fiv.bind('hips'))
    # bolsinha pendurada no cinto (quadril direito)
    bp = _sup(vs, 220, 0.425, 0.020, 0)
    bolsa = box(0.064, 0.042, 0.070, 'leather', taper=0.84).color((0.80, 0.76, 0.86))
    bolsa.add(box(0.070, 0.048, 0.028, 'leather', center=(0, 0, 0.028)))
    bolsa.add(_botao((0, -0.024, 0.016), (0, -1, 0), 0.011, 0.006))
    bolsa.rot('Z', -50).move(bp.x, bp.y, 0.412)
    g.add(bolsa.bind('hips'))
    # bandoleira: do ombro esquerdo ao quadril direito, dando a volta
    rows = []
    for k in range(11):
        a = -180.0 + 36.0 * k
        z = 0.588 + 0.118 * math.cos(math.radians(a))
        dz = 0.021 + 0.006 * abs(math.sin(math.radians(a)))
        rows.append([_sup(vs, a, z + dz, 0.008, 0), _sup(vs, a, z - dz, 0.008, 0)])
    tira = _faixa(rows, 'dark', 0.016)
    tira.color((1.3, 1.25, 1.25))
    g.add(tira.bind_fn(_tw))
    az = -62.0
    fv = _sup(vs, az, 0.588 + 0.118 * math.cos(math.radians(az)), 0.013, 0)
    fiv = box(0.040, 0.014, 0.054, 'vcol').color(OURO)
    fiv.add(box(0.022, 0.018, 0.032, 'vcol').color(OURO_E))
    fiv.rot('Y', -40).rot('Z', 24)
    g.add(fiv.move(*fv).bind('chest'))
    # gola da camisa
    gola = stack([(0.708, 0.104, 0.086, 0, 0.0, 0.2), (0.748, 0.082, 0.072, 0, 0.004, 0.1)], 10, 'secondary',
                 cap_a=False, cap_b=False)
    g.add(gola.bind('chest'))
    # mangas arregacadas + antebraco de pele com bracadeira
    arm = _manga([(0.135, 0.036, 0.036), (0.200, 0.059, 0.059), (0.250, 0.058, 0.058), (0.258, 0.068, 0.068),
                  (0.288, 0.067, 0.067)], 'secondary', cap_a=True, cap_b=True)
    arm.grad('x', SHX, ELX, lp.WHITE, (0.86, 0.82, 0.90))
    arm.add(_antebraco(0.286))
    arm.add(_manga([(0.350, 0.049, 0.049), (0.356, 0.057, 0.057), (0.426, 0.056, 0.056), (0.432, 0.048, 0.048)],
                   'leather', 6))
    g.add(arm.both())
    return g


@piece('top', 'top_quimono', 'Quimono de Lutador', cost=90)
def top_quimono():
    w = _pesos(0.335)
    # peito de pele que aparece no decote
    g = hb.make_torso('skin', chest=0.93, belly=0.93, hip=0.9)
    g.keep_faces(lambda c: c.z > 0.5 and c.y < 0.03)
    g.color((0.93, 0.84, 0.86))
    hb.bind_torso(g)
    # jaqueta: casca com decote em V e saiote
    js = [(0.335, 0.178, 0.148, 0, 0.004, 0.15, 0), (0.400, 0.160, 0.130, 0, 0.004, 0.2, 0),
          (0.458, 0.146, 0.117, 0, 0.003, 0.2, 0), (0.520, 0.139, 0.111, 0, 0.0, 0.2, 0),
          (0.600, 0.148, 0.114, 0, -0.002, 0.25, 8), (0.685, 0.140, 0.104, 0, 0.0, 0.3, 27),
          (0.738, 0.088, 0.078, 0, 0.0, 0.0, 54)]
    jq = _casca(js, 10, 'primary', None, 0.014)
    _sombra(jq, 0.335, 0.70)
    g.add(jq.bind_fn(w))
    g.add(_tampa(js[0], 10, 'primary', arco=True).bind_fn(w))

    def borda(z):
        """Angulo da borda esquerda do decote; abaixo do V ela cruza para o lado direito."""
        if z >= 0.685:
            return -90 + 27 + (z - 0.685) / 0.053 * 27
        if z >= 0.60:
            return -90 + 8 + (z - 0.60) / 0.085 * 19
        return -90 + 8 - (0.60 - z) / 0.13 * 26
    # lapela esquerda por cima (desce ate a faixa), direita por baixo
    esq = [[_sup(js, borda(z) - 3, z, 0.007, 0), _sup(js, borda(z) + 15, z, 0.007, 0)]
           for z in (0.738, 0.685, 0.60, 0.53, 0.47)]
    g.add(_faixa(esq, 'secondary', 0.016).bind_fn(w))
    dire = [[_sup(js, 180 - borda(z) + 3, z, 0.005, 0), _sup(js, 180 - borda(z) - 15, z, 0.005, 0)]
            for z in (0.738, 0.685, 0.60, 0.565)]
    g.add(_faixa(dire, 'secondary', 0.014).bind_fn(w))
    gola = _casca([(0.722, 0.100, 0.088, 0, 0, 0.0, 56), (0.756, 0.090, 0.080, 0, 0.002, 0.0, 56)], 6, 'secondary',
                  None, 0.014)
    g.add(gola.bind('chest'))
    # barra do saiote
    g.add(_cinta(js, 0.332, 0.352, 0.005, 'secondary', 10, arco=True).bind_fn(w))
    # faixa preta com no e pontas
    g.add(_cinta(js, 0.438, 0.482, 0.008, 'dark', 10, ch=0.006, arco=True).bind('hips'))
    kp = _sup(js, -68, 0.46, 0.016, 0)
    g.add(ellipsoid(0.030, 0.022, 0.026, 6, 3, 'dark', center=tuple(kp)).bind('hips'))
    for dx, ln, sp in ((0.012, 0.115, 0.030), (-0.016, 0.090, -0.022)):
        rows = []
        for i in range(4):
            t = i / 3.0
            c = Vector((kp.x + dx + sp * t, kp.y - 0.006 - 0.024 * t, kp.z - 0.012 - ln * t))
            hw = 0.014 + 0.006 * t
            rows.append([c + Vector((-hw, 0, 0)), c + Vector((hw, 0, 0))])
        g.add(_faixa(rows, 'dark', 0.010, fora=(0, -1, 0)).bind_fn(w))
    # mangas largas ate o meio do antebraco
    arm = _manga([(0.135, 0.040, 0.040), (0.200, 0.063, 0.063), (0.275, 0.065, 0.065), (0.305, 0.067, 0.067),
                  (0.335, 0.071, 0.070), (0.388, 0.080, 0.076, 0.004)], 'primary', cap_a=True)
    arm.grad('x', SHX, 0.39, lp.WHITE, (0.86, 0.82, 0.90))
    arm.add(_manga([(0.366, 0.081, 0.078, 0.004), (0.392, 0.085, 0.081, 0.004)], 'secondary'))
    arm.add(_boca(0.392, 0.085, 0.081, 0.04, 0.045, 'primary', dz=0.004))
    arm.add(_antebraco(0.345, n=6))
    g.add(arm.both())
    return g


@piece('top', 'top_moletom', 'Moletom com Capuz', cost=120)
def top_moletom():
    # corpo folgado, caindo por cima da barra canelada
    cs = [(0.392, 0.158, 0.128, 0, 0.004, 0.2), (0.428, 0.171, 0.138, 0, 0.004, 0.2),
          (0.500, 0.167, 0.135, 0, 0.002, 0.2), (0.610, 0.155, 0.119, 0, -0.002, 0.25),
          (0.685, 0.140, 0.101, 0, 0.0, 0.3), (0.735, 0.072, 0.064, 0, 0.0, 0.0)]
    g = stack(cs, 10, 'primary', cap_a=False)
    _sombra(g, 0.39, 0.70)
    barra = stack([(0.352, 0.150, 0.120, 0, 0.004, 0.2), (0.364, 0.161, 0.131, 0, 0.004, 0.2),
                   (0.398, 0.161, 0.131, 0, 0.004, 0.2)], 10, 'secondary', cap_a=True, cap_b=False)
    barra.color((0.86, 0.82, 0.90))
    g.add(barra)
    # bolso canguru
    rows = []
    for z, hw in ((0.418, 0.082), (0.462, 0.082), (0.512, 0.052)):
        xr = _pt(_sec(cs, z), -72).x
        xm = xr if xr < hw - 0.004 else hw * 0.5
        rows.append([_frente(cs, x, z, 0.008) for x in (hw, xm, 0.0, -xm, -hw)])
    bolso = _faixa(rows, 'primary', 0.014)
    bolso.color((0.90, 0.87, 0.93))
    g.add(bolso)
    for s in (1, -1):
        # entrada do bolso: tira escura na diagonal
        a, b = _frente(cs, s * 0.080, 0.468, 0.0095), _frente(cs, s * 0.054, 0.508, 0.0095)
        d = Vector((0.016 * -s, 0, 0.0))
        g.add(_decal([a, b, b + d + Vector((0, 0, -0.004)), a + d + Vector((0, -0.002, -0.022))], 'dark'))
    hb.bind_torso(g)
    # capuz caido: rolo grosso em volta da nuca + saco nas costas
    path = [(0.050, -0.098, 0.690), (0.098, -0.040, 0.728), (0.112, 0.040, 0.744), (0.066, 0.108, 0.748),
            (0.0, 0.128, 0.748)]
    path = path + [(-x, y, z) for x, y, z in reversed(path[:-1])]
    rad = [0.020, 0.034, 0.042, 0.050, 0.054]
    rad = rad + list(reversed(rad[:-1]))
    capuz = tube(path, [(r, r * 0.86) for r in rad], 6, 'primary')
    saco = ellipsoid(0.112, 0.050, 0.078, 8, 5, 'primary', center=(0, 0.112, 0.694))
    saco.warp(lambda p: Vector((p.x * (1.0 - 0.9 * max(0.0, 0.70 - p.z)), p.y, p.z)))
    capuz.add(saco)
    _sombra(capuz, 0.62, 0.78)
    # forro aparecendo na dobra de cima
    capuz.add(ellipsoid(0.070, 0.040, 0.014, 8, 3, 'secondary', center=(0, 0.108, 0.772)))
    g.add(capuz.bind('chest'))
    # cordoes
    for s in (1, -1):
        p0 = Vector((s * 0.040, -0.105, 0.690))
        p1 = _frente(cs, s * 0.036, 0.640, 0.010)
        p2 = _frente(cs, s * 0.042, 0.585, 0.010)
        g.add(tube([p0, p1, p2], 0.0075, 4, 'white').bind('chest'))
        g.add(box(0.020, 0.020, 0.026, 'secondary', center=tuple(p2 + Vector((0, 0, -0.012))), taper=0.7)
              .bind('chest'))
    # mangas folgadas com punho canelado
    arm = _manga([(0.135, 0.040, 0.040), (0.200, 0.066, 0.066), (0.275, 0.064, 0.064), (0.305, 0.064, 0.064),
                  (0.335, 0.066, 0.066), (0.396, 0.068, 0.068), (0.410, 0.056, 0.056)], 'primary', cap_a=True)
    arm.grad('x', SHX, 0.41, lp.WHITE, (0.86, 0.82, 0.90))
    arm.add(_manga([(0.404, 0.057, 0.057), (0.444, 0.055, 0.055), (0.450, 0.046, 0.046)], 'secondary', cap_b=True)
            .color((0.86, 0.82, 0.90)))
    g.add(arm.both())
    return g


@piece('top', 'top_vestido', 'Vestido de Camponesa', cost=110)
def top_vestido():
    zh = 0.262
    saia = [(zh, 0.226, 0.200, 0, 0.004, 0.05), (0.310, 0.222, 0.196, 0, 0.004, 0.05),
            (0.378, 0.196, 0.168, 0, 0.004, 0.1), (0.428, 0.162, 0.134, 0, 0.004, 0.15),
            (0.460, 0.141, 0.113, 0, 0.003, 0.2)]
    w = _pesos(zh, 0.46, 0.66)
    g = hb.make_torso('primary', chest=0.98, belly=0.95)
    g.keep_faces(lambda c: c.z > 0.44)
    s = stack(saia, 10, 'primary', cap_a=False, cap_b=False)
    _sombra(s, zh, 0.46)
    g.add(s)
    # anagua de bico aparecendo por baixo
    n = 20
    top = [(x, 0.004 + y, zh + 0.012) for x, y in ring_pts(n, 0.218, 0.192, 0.05)]
    bot = [(x, 0.004 + y, zh - 0.030 + (0.014 if i % 2 else 0.0)) for i, (x, y) in enumerate(ring_pts(n, 0.222, 0.196, 0.05))]
    an = loft([bot, top], 'white', cap_a=True, cap_b=False)
    an.color((0.90, 0.88, 0.96))
    g.add(an)
    # avental: painel na frente da saia + peitilho
    rows = []
    for z, hw in ((0.286, 0.060), (0.300, 0.082), (0.378, 0.078), (0.428, 0.064), (0.462, 0.054)):
        xr = _pt(_sec(saia, z), -72).x
        xm = xr if xr < hw - 0.004 else hw * 0.5
        rows.append([_frente(saia, x, z, 0.007) for x in (hw, xm, 0.0, -xm, -hw)])
    g.add(_faixa(rows, 'secondary', 0.012))
    tr = hb.torso_rings(chest=0.98, belly=0.95)
    pe = [[_frente(tr, x, z, 0.006) for x in (hw, -hw)] for z, hw in ((0.470, 0.046), (0.540, 0.042), (0.618, 0.048))]
    g.add(_faixa(pe, 'secondary', 0.010))
    # bolsinho do avental
    bz = [[_frente(saia, x, z, 0.012) for x in (0.058, 0.020)] for z in (0.335, 0.385)]
    g.add(_faixa(bz, 'accent', 0.008))
    g.bind_fn(w)
    # faixa do avental com laco nas costas
    g.add(_cinta(saia + list(tr[2:4]), 0.444, 0.478, 0.007, 'secondary').bind('hips'))
    lc = _laco((0, 0.128, 0.468), 0.105, 0.062, 0.030, 'secondary', fora=(0, 1, 0.15))
    for s in (1, -1):
        rows = []
        for i in range(3):
            t = i / 2.0
            c = Vector((s * (0.018 + 0.040 * t), 0.132 + 0.034 * t, 0.455 - 0.105 * t))
            hw = 0.016 + 0.006 * t
            rows.append([c + Vector((-hw, 0, 0)), c + Vector((hw, 0, 0))])
        lc.add(_faixa(rows, 'secondary', 0.008, fora=(0, 1, 0)))
    g.add(lc.bind_fn(w))
    # gola redonda + lacinho
    gola = stack([(0.694, 0.120, 0.094, 0, 0.0, 0.2), (0.740, 0.080, 0.070, 0, 0.003, 0.1)], 10, 'secondary',
                 cap_a=False, cap_b=False)
    gola.add(_laco((0, -0.100, 0.700), 0.060, 0.034, 0.018, 'accent'))
    g.add(gola.bind('chest'))
    # mangas bufantes, punho e braco de pele
    arm = _manga([(0.132, 0.040, 0.040), (0.160, 0.072, 0.072), (0.208, 0.084, 0.084), (0.252, 0.072, 0.072),
                  (0.272, 0.052, 0.052)], 'secondary', cap_a=True)
    arm.grad('x', SHX, 0.27, lp.WHITE, (0.84, 0.80, 0.90))
    arm.add(_manga([(0.264, 0.055, 0.055), (0.290, 0.055, 0.055)], 'accent', cap_b=True))
    arm.add(_antebraco(0.284))
    g.add(arm.both())
    return g


@piece('top', 'top_manto', 'Manto de Mago', rarity=1, cost=220)
def top_manto():
    zh = 0.205
    saia = [(zh, 0.214, 0.180, 0, 0.004, 0.1), (0.300, 0.188, 0.156, 0, 0.004, 0.1),
            (0.385, 0.162, 0.131, 0, 0.004, 0.15), (0.458, 0.141, 0.113, 0, 0.003, 0.2)]
    tr = hb.torso_rings(chest=0.97)
    corpo = saia + list(tr[2:5])
    w = _pesos(zh, 0.458, 0.72)
    g = hb.make_torso('primary', chest=0.97)
    g.keep_faces(lambda c: c.z > 0.44)
    s = stack(saia, 10, 'primary', cap_a=True, cap_b=False)
    _sombra(s, zh, 0.46)
    g.add(s)
    # barra com dentes
    g.add(_cinta(saia, zh - 0.004, zh + 0.034, 0.005, 'accent'))
    for k in range(10):
        a = 36.0 * k + 18.0
        g.add(_decal([_sup(saia, a - 13, zh + 0.034, 0.005), _sup(saia, a + 13, zh + 0.034, 0.005),
                      _sup(saia, a, zh + 0.084, 0.004)], 'accent'))
    # estola clara descendo pela frente
    rows = []
    for z, hw in ((0.660, 0.030), (0.610, 0.031), (0.520, 0.032), (0.458, 0.034), (0.385, 0.038), (0.300, 0.043),
                  (zh + 0.034, 0.048)):
        rows.append([_frente(corpo, hw, z, 0.007), _frente(corpo, -hw, z, 0.007)])
    g.add(_faixa(rows, 'secondary', 0.012))
    g.bind_fn(w)
    # cordao na cintura com pingente
    g.add(stack([_sec(corpo, 0.440, 0.004), _sec(corpo, 0.458, 0.013), _sec(corpo, 0.476, 0.004)], 10, 'accent',
                cap_a=False, cap_b=False).bind('hips'))
    pp = _frente(corpo, 0.070, 0.452, 0.014)
    pg = tube([pp, pp + Vector((0.006, -0.012, -0.050))], 0.006, 4, 'accent')
    pg.add(_gema(pp + Vector((0.006, -0.012, -0.050)), (0, 0, -1), 0.018, 0.040, cor=AGUA))
    pg.add(_gema(pp + Vector((0.006, -0.012, -0.050)), (0, 0, 1), 0.018, 0.014, cor=AGUA))
    g.add(pg.bind_fn(w))

    # pelerine com ponta na frente e nas costas
    def anel(z, rx, ry, cy, pt=0.0):
        return [(x, cy + y, z - (pt if i in (3, 9) else 0.0)) for i, (x, y) in enumerate(ring_pts(12, rx, ry))]
    cp = loft([anel(0.632, 0.208, 0.136, -0.012, 0.034), anel(0.712, 0.140, 0.108, -0.002), anel(0.750, 0.082, 0.074, 0.0)],
              'primary', cap_a=False, cap_b=False)
    cp.grad('z', 0.60, 0.75, (0.80, 0.77, 0.88), (1.06, 1.05, 1.02))
    cp.add(loft([anel(0.626, 0.214, 0.141, -0.012, 0.034), anel(0.652, 0.197, 0.133, -0.010, 0.030)], 'accent',
                cap_a=False, cap_b=False))
    cp.add(loft([anel(0.642, 0.176, 0.108, -0.012, 0.030), anel(0.626, 0.214, 0.141, -0.012, 0.034)], 'primary',
                cap_a=False, cap_b=False).color((0.62, 0.58, 0.74)))
    # gola alta
    cp.add(stack([(0.735, 0.084, 0.076, 0, 0.0, 0.0), (0.765, 0.096, 0.086, 0, 0.002, 0.0),
                  (0.765, 0.083, 0.074, 0, 0.002, 0.0)], 10, 'secondary', cap_a=False, cap_b=False))
    # broche
    bp, bn = Vector((0, -0.099, 0.724)), Vector((0, -0.72, 0.69))
    cp.add(_botao(bp, bn, 0.027, 0.008, OURO, 6))
    cp.add(_gema(bp + bn.normalized() * 0.007, bn, 0.017, 0.014, cor=AGUA))
    g.add(cp.bind('chest'))
    # mangas de sino
    arm = _manga([(0.135, 0.036, 0.036), (0.200, 0.056, 0.056), (0.275, 0.054, 0.054), (0.305, 0.056, 0.055),
                  (0.335, 0.062, 0.058), (0.385, 0.078, 0.066, 0.004), (0.430, 0.092, 0.074, 0.008)], 'primary',
                 cap_a=True)
    arm.grad('x', SHX, 0.43, lp.WHITE, (0.84, 0.80, 0.90))
    arm.add(_manga([(0.408, 0.089, 0.073, 0.007), (0.434, 0.097, 0.078, 0.008)], 'accent'))
    arm.add(_boca(0.434, 0.097, 0.078, 0.045, 0.044, 'primary', dz=0.008))
    arm.add(_antebraco(0.385, n=6))
    g.add(arm.both())
    return g


def _ombreira(R=0.098, h=0.086, mat='metal', friso='accent', n=8):
    """Ombreira esquerda: cupula com friso na borda e fundo fechado (o braco gira por dentro)."""
    g = lathe([(R, -0.014), (R * 0.99, 0.004), (R * 0.84, h * 0.55), (R * 0.46, h * 0.92), (0.0, h)], n, mat)
    g.grad('z', -0.014, h, (0.80, 0.78, 0.92), lp.WHITE)
    g.add(lathe([(R * 1.03, -0.024), (R * 1.08, -0.008), (R * 1.0, 0.010)], n, friso))
    g.add(lathe([(0.0, -0.022), (R * 1.03, -0.020)], n, 'dark'))
    return g


@piece('top', 'top_placas', 'Armadura de Placas', rarity=1, cost=280)
def top_placas():
    tr = hb.torso_rings(chest=1.07, belly=1.02)

    def quilha(p):
        if abs(p.x) < 0.01 and p.y < 0 and 0.5 < p.z < 0.70:
            return Vector((p.x, p.y - 0.016, p.z))
        return p
    g = stack(tr, 10, 'metal', phase=0.5)
    g.add(_cinta(tr, 0.512, 0.536, 0.006, 'accent', phase=0.5))
    g.warp(quilha)
    _sombra(g, 0.385, 0.70, (0.74, 0.72, 0.88))
    hb.bind_torso(g)
    # gema no peito
    g.add(_gema((0, -0.128, 0.622), (0, -1, 0.12), 0.034, 0.018, 'accent', None).bind('chest'))
    # escarcela: duas laminas + barra
    sw = skirt_weights(0.332, 0.455)
    l2 = stack([(0.332, 0.178, 0.148, 0, 0.004, 0.15), (0.405, 0.153, 0.124, 0, 0.004, 0.2)], 10, 'metal',
               cap_a=True, cap_b=False, phase=0.5)
    l2.grad('z', 0.332, 0.405, (0.70, 0.68, 0.86), lp.WHITE)
    l1 = stack([(0.390, 0.164, 0.134, 0, 0.004, 0.2), (0.462, 0.145, 0.116, 0, 0.003, 0.2)], 10, 'metal',
               cap_a=False, cap_b=False, phase=0.5)
    l1.grad('z', 0.390, 0.462, (0.76, 0.74, 0.90), lp.WHITE)
    l2.add(l1)
    l2.add(stack([(0.327, 0.183, 0.153, 0, 0.004, 0.15), (0.347, 0.177, 0.147, 0, 0.004, 0.15)], 10, 'accent',
                 cap_a=False, cap_b=False, phase=0.5))
    # tabardo de pano na frente
    rows = []
    for z, y, hw in ((0.452, -0.130, 0.036), (0.390, -0.146, 0.040), (0.330, -0.161, 0.044), (0.278, -0.166, 0.046),
                     (0.246, -0.166, 0.0)):
        rows.append([(hw, y + 0.007, z), (0.0, y, z), (-hw, y + 0.007, z)])
    tb = _faixa(rows, 'primary', 0.010, forro='primary', fora=(0, -1, 0))
    tb.grad('z', 0.246, 0.452, FRIO, lp.WHITE)
    tb.add(_decal([(0, -0.170, 0.372), (0.020, -0.167, 0.342), (0, -0.172, 0.312), (-0.020, -0.167, 0.342)], 'accent',
                  fora=(0, -1, 0)))
    l2.add(tb)
    g.add(l2.bind_fn(sw))
    # cinto de couro com fivelao
    g.add(stack([(0.444, 0.153, 0.124, 0, 0.003, 0.2), (0.480, 0.149, 0.120, 0, 0.003, 0.2)], 10, 'leather',
                cap_a=False, cap_b=False, phase=0.5).bind('hips'))
    fiv = box(0.060, 0.022, 0.054, 'vcol', center=(0, -0.130, 0.462)).color(OURO)
    fiv.add(box(0.030, 0.026, 0.026, 'vcol', center=(0, -0.132, 0.462)).color(OURO_E))
    g.add(fiv.bind('hips'))
    # gorjal
    g.add(stack([(0.700, 0.108, 0.090, 0, 0.0, 0.1), (0.760, 0.100, 0.088, 0, 0.002, 0.0),
                 (0.760, 0.086, 0.076, 0, 0.002, 0.0)], 8, 'metal', cap_a=False, cap_b=False).bind('chest'))
    # bracos: malha escura, cotoveleira e avambraco de metal
    arm = _manga([(0.135, 0.034, 0.034), (0.200, 0.052, 0.052), (0.275, 0.048, 0.048), (0.305, 0.047, 0.047),
                  (0.340, 0.049, 0.049)], 'dark', cap_a=True)
    arm.add(ellipsoid(0.040, 0.050, 0.050, 6, 3, 'metal', center=(0.305, 0.018, AZ)).bind_fn(hb.arm_weights))
    vam = _manga([(0.330, 0.050, 0.050), (0.338, 0.067, 0.067), (0.354, 0.064, 0.064), (0.425, 0.055, 0.055),
                  (0.447, 0.050, 0.050)], 'metal', cap_b=True)
    vam.grad('x', 0.33, 0.45, lp.WHITE, (0.80, 0.78, 0.92))
    arm.add(vam)
    arm.add(_manga([(0.414, 0.059, 0.059), (0.436, 0.058, 0.058)], 'accent'))
    # ombreira grande: acompanha o braco, mas presa um pouco no peito
    om = _ombreira()
    om.add(_botao((0, 0, 0.083), (0, 0, 1), 0.017, 0.012, OURO, 6))
    om.scale(1.0, 0.95, 1.0).rot('Y', 22).move(0.190, 0.0, 0.710)
    arm.add(om.bind_fn(lambda p: {'upper_arm.L': 0.7, 'chest': 0.3}))
    g.add(arm.both())
    return g


@piece('top', 'top_pirata', 'Colete de Pirata', rarity=1, cost=200)
def top_pirata():
    tr = hb.torso_rings()
    zs = [0.385, 0.440, 0.480, 0.520, 0.565, 0.610, 0.648, 0.685, 0.735]
    g = stack([_sec(tr, z) for z in zs], 10, 'white')
    # camisa listrada
    def lista(c):
        for i in range(len(zs) - 1):
            if zs[i] + 1e-4 < c.z < zs[i + 1] - 1e-4:
                return 'dark' if i % 2 else None
        return None
    _pinta(g, lista)
    g.keep_faces(lambda c: c.y < 0.02 or c.z > 0.68)
    _sombra(g, 0.385, 0.70)
    hb.bind_torso(g)
    # colete aberto
    vs = [(0.468, 0.151, 0.123, 0, 0.002, 0.2, 44), (0.520, 0.146, 0.119, 0, 0.0, 0.2, 37),
          (0.610, 0.156, 0.121, 0, -0.002, 0.25, 32), (0.685, 0.148, 0.110, 0, 0.0, 0.3, 37),
          (0.728, 0.098, 0.084, 0, 0.0, 0.1, 54)]
    vest = _casca(vs, 10, 'primary', None, 0.014)
    _sombra(vest, 0.468, 0.70)
    for z, s in ((0.522, 1), (0.522, -1), (0.598, 1), (0.598, -1)):
        gp = _par(vs, z)
        a = -90 + s * (gp[0][6] + (gp[1][6] - gp[0][6]) * gp[2] + 9)
        vest.add(_botao(_sup(vs, a, z, 0.0, 0), _sup(vs, a, z, 1.0, 0) - _sup(vs, a, z, 0.0, 0), 0.013, 0.008))
    g.add(vest.bind_fn(_tw))
    # faixa na cintura com no no quadril e pontas caindo
    w = _pesos(0.30, 0.455, 0.6)
    fx = stack([_sec(tr, 0.398, 0.018), _sec(tr, 0.435, 0.027), _sec(tr, 0.472, 0.018)], 10, 'accent', cap_a=False,
               cap_b=False)
    fx.grad('z', 0.398, 0.472, (0.80, 0.76, 0.88), lp.WHITE)
    g.add(fx.bind('hips'))
    kp = _sup(tr, -28, 0.435, 0.034, 0)
    no = ellipsoid(0.026, 0.030, 0.030, 6, 3, 'accent', center=tuple(kp))
    for dy, ln, sp in ((-0.014, 0.125, 0.020), (0.016, 0.100, 0.034)):
        rows = []
        for i in range(4):
            t = i / 3.0
            c = Vector((kp.x + 0.004 + sp * t, kp.y + dy * (1 + t), kp.z - 0.012 - ln * t))
            hw = 0.013 + 0.007 * t
            rows.append([c + Vector((0.006, -hw, 0)), c + Vector((-0.006, hw, 0))])
        no.add(_faixa(rows, 'accent', 0.009, forro='accent', fora=(1, 0, 0)).grad('z', 0.30, 0.43, FRIO, lp.WHITE))
    g.add(no.bind_fn(w))
    # barra da camisa por baixo da faixa
    cam = stack([(0.350, 0.168, 0.138, 0, 0.004, 0.15), (0.405, 0.150, 0.122, 0, 0.004, 0.2)], 10, 'white',
                cap_a=True, cap_b=False)
    cam.grad('z', 0.35, 0.405, FRIO, lp.WHITE)
    g.add(cam.bind_fn(skirt_weights(0.35, 0.455)))
    # lenco no pescoco
    ln = stack([(0.706, 0.100, 0.084, 0, 0.0, 0.1), (0.736, 0.092, 0.080, 0, 0.002, 0.0),
                (0.754, 0.076, 0.068, 0, 0.002, 0.0)], 8, 'accent', cap_a=False, cap_b=False)
    ln.add(_faixa([[(0.046, -0.088, 0.730), (-0.046, -0.088, 0.730)], [(0.026, -0.108, 0.692), (-0.026, -0.108, 0.692)],
                   [(0.004, -0.112, 0.652), (-0.004, -0.112, 0.652)]], 'accent', 0.012, fora=(0, -1, 0)))
    g.add(ln.bind('chest'))
    # mangas bufantes presas abaixo do cotovelo
    arm = _manga([(0.135, 0.040, 0.040), (0.185, 0.066, 0.066), (0.245, 0.076, 0.076), (0.298, 0.076, 0.076),
                  (0.330, 0.054, 0.054)], 'white', cap_a=True)
    arm.grad('x', SHX, 0.33, lp.WHITE, (0.84, 0.80, 0.92))
    arm.add(_manga([(0.324, 0.056, 0.056), (0.352, 0.055, 0.055)], 'dark', cap_b=True))
    arm.add(_antebraco(0.346))
    g.add(arm.both())
    return g


@piece('top', 'top_casaca', 'Casaca Real', rarity=2, cost=450)
def top_casaca():
    tr = hb.torso_rings(chest=1.03)
    g = stack(tr, 10, 'primary', cap_a=False, phase=0.5)
    _pinta(g, lambda c: 'secondary' if c.z < 0.5 else None)
    _sombra(g, 0.385, 0.70)
    hb.bind_torso(g)
    w = _pesos(0.215, 0.455, 0.6)
    # colete claro com duas pontas na frente
    col = stack([(0.356, 0.168, 0.138, 0, 0.004, 0.15), (0.440, 0.147, 0.119, 0, 0.004, 0.2)], 10, 'secondary',
                cap_a=True, cap_b=False, phase=0.5)
    col.warp(lambda p: Vector((p.x, p.y, p.z - 0.032)) if p.z < 0.36 and p.y < -0.06 and abs(p.x) > 0.03 else p)
    col.grad('z', 0.33, 0.44, FRIO, lp.WHITE)
    g.add(col.bind_fn(skirt_weights(0.33, 0.455)))
    # casaca: recorte na cintura que vira duas caudas nas costas (metade esquerda, espelhada)
    cs = [(0.215, 0.196, 0.163, 0, 0.004, 0.1), (0.300, 0.186, 0.152, 0, 0.004, 0.1),
          (0.385, 0.171, 0.139, 0, 0.004, 0.15), (0.455, 0.154, 0.124, 0, 0.003, 0.2),
          (0.545, 0.139, 0.110, 0, 0.0, 0.2)]
    angs = [(34, 84), (16, 86), (-18, 88), (-52, 89), (-80, 90)]
    cd = _arco(cs, angs, 5, 'primary', 'secondary', 0.012)
    _sombra(cd, 0.215, 0.50)
    g.add(cd.bind_fn(w).both())
    # alamares dourados
    for z, hw in ((0.662, 0.060), (0.610, 0.050), (0.558, 0.040)):
        rows = [[_frente(tr, x, z + dz, 0.006, 10, 0.5) for x in (hw, 0.0, -hw)] for dz in (0.009, -0.009)]
        al = _faixa(rows, 'vcol', 0.010).color(OURO)
        for s in (1, -1):
            p = _frente(tr, s * hw, z, 0.004, 10, 0.5)
            al.add(_botao(p, _frente(tr, s * hw, z, 1.0, 10, 0.5) - _frente(tr, s * hw, z, 0.0, 10, 0.5), 0.016, 0.010))
        g.add(al.bind_fn(_tw))
    # gola alta + jabo com rubi
    gola = _casca([(0.712, 0.098, 0.084, 0, 0, 0.1, 30), (0.764, 0.094, 0.084, 0, 0.002, 0.0, 38)], 6, 'accent',
                  None, 0.014)
    gola.add(ellipsoid(0.040, 0.020, 0.028, 6, 3, 'white', center=(0, -0.098, 0.712)))
    gola.add(ellipsoid(0.032, 0.018, 0.030, 6, 3, 'white', center=(0, -0.110, 0.676)))
    gola.add(_gema((0, -0.116, 0.716), (0, -1, 0.1), 0.015, 0.012, cor=RUBI))
    g.add(gola.bind('chest'))
    # mangas justas com canhao largo
    arm = _manga([(0.135, 0.038, 0.038), (0.200, 0.056, 0.056), (0.275, 0.052, 0.052), (0.305, 0.052, 0.052),
                  (0.335, 0.054, 0.054), (0.388, 0.056, 0.056)], 'primary', cap_a=True)
    arm.grad('x', SHX, 0.39, lp.WHITE, (0.84, 0.80, 0.90))
    arm.add(_manga([(0.372, 0.058, 0.058), (0.380, 0.069, 0.069), (0.440, 0.066, 0.066), (0.448, 0.050, 0.050)],
                   'accent', cap_b=True))
    arm.add(_botao((0.410, 0.0, AZ + 0.066), (0, 0, 1), 0.014, 0.009).bind('forearm.L'))
    # dragona dourada com franja
    dr = lathe([(0.056, -0.040), (0.062, -0.010), (0.056, 0.008), (0.0, 0.016)], 8, 'vcol').color(OURO)
    dr.grad('z', -0.040, -0.008, (0.62, 0.50, 0.42), lp.WHITE)
    dr.scale(1.0, 0.92, 1.0).rot('Y', 10).move(0.172, 0.0, 0.750)
    arm.add(dr.bind_fn(lambda p: {'chest': 0.7, 'upper_arm.L': 0.3}))
    g.add(arm.both())
    return g


@piece('top', 'top_cristal', 'Armadura de Cristal', rarity=3, cost=1200)
def top_cristal():
    g = hb.make_torso('dark')
    # peitoral facetado com nucleo luminoso
    ps = [(0.515, 0.150, 0.122, 0, 0.0, 0.1), (0.610, 0.166, 0.130, 0, -0.004, 0.15),
          (0.690, 0.152, 0.110, 0, 0.0, 0.2), (0.738, 0.082, 0.072, 0, 0.0, 0.0)]
    pe = stack(ps, 6, 'primary', cap_a=False, cap_b=False, phase=0.5).flat()
    pe.grad('z', 0.515, 0.74, (0.72, 0.70, 0.88), lp.WHITE)
    cz = 0.622
    cy = _frente(ps, 0.0, cz, 0.0, 6, 0.5).y
    pe.add(_gema((0, cy + 0.006, cz), (0, -1, 0.06), 0.050, 0.014, 'accent', None, esc=1.3))
    pe.add(_gema((0, cy - 0.004, cz), (0, -1, 0.06), 0.036, 0.030, 'glow', None, esc=1.3))
    for s in (1, -1):
        # veios de luz do nucleo aos ombros
        a = [_frente(ps, s * x, z, 0.004, 6, 0.5) for x, z in ((0.040, 0.652), (0.118, 0.694), (0.122, 0.680),
                                                               (0.046, 0.640))]
        pe.add(_decal(a, 'glow'))
    b = [_frente(ps, x, z, 0.004, 6, 0.5) for x, z in ((0.006, 0.566), (0.006, 0.520), (0.0, 0.516), (-0.006, 0.520),
                                                       (-0.006, 0.566))]
    pe.add(_decal(b, 'glow'))
    g.add(pe.bind_fn(_tw))
    # gola de cristal
    g.add(stack([(0.716, 0.098, 0.086, 0, 0.0, 0.0), (0.760, 0.108, 0.096, 0, 0.002, 0.0),
                 (0.760, 0.094, 0.083, 0, 0.002, 0.0)], 6, 'primary', cap_a=False, cap_b=False, phase=0.5)
          .flat().bind('chest'))
    # saiote em pontas, com as pontas acesas
    sw = skirt_weights(0.30, 0.455)
    top = [(x, 0.003 + y, 0.462) for x, y in ring_pts(12, 0.146, 0.118)]
    bot = []
    for i, (x, y) in enumerate(ring_pts(12, 0.176, 0.146)):
        k = 1.06 if i % 2 == 0 else 1.0
        bot.append((x * k, 0.004 + y * k, 0.302 if i % 2 == 0 else 0.356))
    sk = loft([bot, top], 'primary', cap_a=True, cap_b=False).flat()
    sk.grad('z', 0.30, 0.462, FRIO, lp.WHITE)
    for i in range(0, 12, 2):
        p, l, r = Vector(bot[i]), Vector(bot[i - 1]), Vector(bot[(i + 1) % 12])
        up = Vector(top[i])
        out = Vector((p.x, p.y, 0)).normalized() * 0.004
        sk.add(_decal([p + out, p.lerp(r, 0.55) + out, p.lerp(up, 0.42) + out, p.lerp(l, 0.55) + out], 'glow'))
    g.add(sk.bind_fn(sw))
    g.add(stack([(0.446, 0.153, 0.124, 0, 0.003, 0.0), (0.478, 0.149, 0.120, 0, 0.003, 0.0)], 12, 'accent',
                cap_a=False, cap_b=False).bind('hips'))
    # bracos escuros, bracadeira facetada com estilhaco
    arm = _manga([(0.135, 0.034, 0.034), (0.200, 0.051, 0.051), (0.275, 0.047, 0.047), (0.305, 0.046, 0.046),
                  (0.335, 0.048, 0.048), (0.356, 0.049, 0.049)], 'dark', cap_a=True)
    arm.add(_manga([(0.344, 0.052, 0.052), (0.352, 0.066, 0.066), (0.425, 0.059, 0.059), (0.449, 0.050, 0.050)],
                   'primary', 6, cap_b=True).flat())
    arm.add(_cristal((0.392, 0.0, AZ + 0.046), (0.330, 0.020, AZ + 0.128), 0.024).bind('forearm.L'))
    # ombreira facetada de onde brotam os cristais
    om = lathe([(0.088, -0.012), (0.080, 0.020), (0.046, 0.050), (0.0, 0.058)], 6, 'primary').flat()
    om.grad('z', -0.012, 0.058, (0.74, 0.72, 0.88), lp.WHITE)
    om.add(lathe([(0.0, -0.016), (0.088, -0.012)], 6, 'dark'))
    om.add(_cristal((0.0, 0.0, 0.030), (0.030, 0.0, 0.200), 0.038))
    om.add(_cristal((0.036, 0.030, 0.020), (0.104, 0.064, 0.130), 0.027, fase=0.5))
    om.add(_cristal((0.020, -0.036, 0.020), (0.070, -0.084, 0.118), 0.023, fase=0.3))
    om.rot('Y', 20).move(0.188, 0.0, 0.708)
    arm.add(om.bind_fn(lambda p: {'upper_arm.L': 0.7, 'chest': 0.3}))
    g.add(arm.both())
    return g

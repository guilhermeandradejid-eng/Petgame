# Texturas do mundo, todas por processo simulado (estampilha + pincel), semente fixa.
# Uso: python3 texturas.py OUTDIR
import sys, os, math, time
import numpy as np
from PIL import Image
import pincel as K
from paleta import rgb

T = 256  # px por azulejo (0,25 m)

def glaze_base(h, w, seed):
    """Esmalte de estanho: branco quente com variação de espessura (nunca chapado)."""
    base = np.array(rgb('estanho'), np.float32)
    n = K.fbm(h, w, 64, seed, 3)
    return base[None, None, :] * (0.985 + 0.03 * n[..., None])

def compose(D, seed, base=None, names=K.RAMP_W):
    h, w = D.shape
    col = K.ramp(D, names)
    if base is not None and names is K.RAMP_W:
        bw = (D < 0.12)[..., None]
        col = np.where(bw, base, col)
    return col

# ------------------------------------------------------------------ piso: ponta de diamante
def tile_diamond(seed):
    rng = np.random.default_rng(seed)
    h = w = T
    m = 20 + rng.integers(-2, 3)        # margem do molde
    c = (T / 2 + rng.normal(0, 1.2), T / 2 + rng.normal(0, 1.2))
    A, B, C, Dd = (m, m), (T - m, m), (T - m, T - m), (m, T - m)
    facN, facE, facS, facW = [A, B, c], [B, C, c], [C, Dd, c], [Dd, A, c]
    off = lambda: (rng.uniform(-2, 2), rng.uniform(-2, 2))  # erro de registro por cor
    D = np.zeros((h, w), np.float32)
    # estampilha: aguada no sul, médio no leste e no norte (sol de sudoeste: W e S claros)
    ag = K.wash(K.poly_mask(h, w, [facS], offset=off()), 0.36, seed + 1, 0 + rng.normal(0, 8))
    md = K.wash(K.poly_mask(h, w, [facE], offset=off()), 0.66, seed + 2, 90 + rng.normal(0, 8))
    md2 = K.wash(K.poly_mask(h, w, [facN], offset=off()), 0.74, seed + 3, 0 + rng.normal(0, 8))
    D = np.maximum(np.maximum(ag, md), md2)
    D = K.granulate(D, seed, 0.10, 1.3)
    # pincel à mão livre: arestas da pirâmide e moldura
    S = np.zeros_like(D)
    j = lambda p, s=1.4: (p[0] + rng.normal(0, s), p[1] + rng.normal(0, s))
    for p in (A, B, C, Dd):
        K.stroke(S, [j(c, 0.6), j(((c[0] + p[0]) / 2, (c[1] + p[1]) / 2)), j(p)], 3.0, 1.6, load=0.98, pool=0.2, seed=int(rng.integers(1e6)))
    for a, b in ((A, B), (B, C), (C, Dd), (Dd, A)):
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        K.stroke(S, [j(a), j(mid, 1.8), j(b)], 2.4, 1.5, load=0.95, pool=0.25, seed=int(rng.integers(1e6)))
    # quartos de roseta nos cantos: com 4 azulejos em junta corrida formam um círculo inteiro
    for cx, cy, a0 in ((0, 0, 0), (T, 0, 90), (T, T, 180), (0, T, 270)):
        R = 30 + rng.uniform(-1.5, 1.5)
        pts = [(cx + R * math.cos(math.radians(a0 + t)), cy + R * math.sin(math.radians(a0 + t))) for t in range(0, 91, 10)]
        K.stroke(S, pts, 2.6, 2.0, load=0.95, pool=0.15, seed=int(rng.integers(1e6)))
        fill = K.ellipse_mask(h, w, cx, cy, R - 7, R - 7)
        D = np.maximum(D, fill * 0.66)
        dot = K.ellipse_mask(h, w, cx, cy, 9, 9)
        D = np.maximum(D, dot * 0.95)
    D = np.maximum(D, S)
    D = K.rough_edge(D, seed + 9, 0.9, 2.5)
    return compose(D, seed, glaze_base(h, w, seed))

# ------------------------------------------------------------------ piso: losango de laçaria (claro, contraste baixo)
def tile_losango(seed):
    """Losango inscrito (pontas no meio das arestas): em junta corrida as diagonais continuam de peça
    em peça e formam uma rede; na amarração a rede quebra a cada coluna. Fundo de estanho, aguada
    leve dentro do losango, florão médio no centro, quartos de roseta nos cantos."""
    rng = np.random.default_rng(seed)
    h = w = T
    off = lambda: (rng.uniform(-2, 2), rng.uniform(-2, 2))
    m = 10
    L = [(T / 2, m), (T - m, T / 2), (T / 2, T - m), (m, T / 2)]
    D = K.wash(K.poly_mask(h, w, [L], offset=off()), 0.30, seed + 1, 45 + rng.normal(0, 6), var=0.22)
    inner = [(T / 2, 62), (T - 62, T / 2), (T / 2, T - 62), (62, T / 2)]
    D = np.maximum(D, K.wash(K.poly_mask(h, w, [inner], offset=off()), 0.36, seed + 2, -45, var=0.2) * 0)
    S = np.zeros_like(D)
    j = lambda p, s=1.2: (p[0] + rng.normal(0, s), p[1] + rng.normal(0, s))
    for a, b in zip(L, L[1:] + L[:1]):
        K.stroke(S, [j(a), j(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2), 1.6), j(b)], 2.6, 1.8, load=0.68, pool=0.25, seed=int(rng.integers(1e6)))
    # florão de 4 pétalas no centro (médio) com miolo azul-noite
    c = (T / 2 + rng.normal(0, 1), T / 2 + rng.normal(0, 1))
    for k in range(4):
        an = math.pi / 2 * k + math.pi / 4
        tip = (c[0] + math.cos(an) * 34, c[1] + math.sin(an) * 34)
        K.stroke(S, [j(c, 0.5), ((c[0] + tip[0]) / 2 + math.cos(an + 0.5) * 4, (c[1] + tip[1]) / 2 + math.sin(an + 0.5) * 4), j(tip)], 7.0, 2.0, load=0.66, pool=0.2, seed=int(rng.integers(1e6)), taper_in=0.3)
    K.stroke(S, [(c[0] - 1, c[1]), (c[0] + 1, c[1])], 5.5, 5.5, load=0.95, pool=0, seed=2)
    # quartos de roseta nos cantos (aguada) com ponto
    for cx, cy, a0 in ((0, 0, 0), (T, 0, 90), (T, T, 180), (0, T, 270)):
        R = 26 + rng.uniform(-1.5, 1.5)
        D = np.maximum(D, K.ellipse_mask(h, w, cx, cy, R, R) * 0.33)
        pts = [(cx + R * math.cos(math.radians(a0 + t)), cy + R * math.sin(math.radians(a0 + t))) for t in range(0, 91, 10)]
        K.stroke(S, pts, 2.2, 1.6, load=0.66, pool=0.15, seed=int(rng.integers(1e6)))
        D = np.maximum(D, K.ellipse_mask(h, w, cx, cy, 8, 8) * 0.95)
    D = np.maximum(K.granulate(D, seed, 0.10, 1.3), S)
    D = K.rough_edge(D, seed + 9, 0.9, 2.5)
    return compose(D, seed, glaze_base(h, w, seed))

# ------------------------------------------------------------------ cercadura (corda torcida)
def tile_corda(seed):
    """Corda torcida: gomos inclinados em forma de amêndoa, aguada média e contorno a pincel."""
    rng = np.random.default_rng(seed)
    h = w = T
    D = np.zeros((h, w), np.float32)
    S = np.zeros_like(D)
    y0, y1 = 48, T - 48
    for k in range(-1, 5):
        x = k * T / 4 + rng.normal(0, 1)
        # gomo: amêndoa de (x, y1) a (x + 80, y0), inclinada
        a = np.array((x, y1)); b = np.array((x + 84, y0))
        d = b - a; n = np.array((-d[1], d[0])) / np.linalg.norm(d)
        poly = [tuple(a + d * t + n * 24 * math.sin(math.pi * t) ** 0.9) for t in np.linspace(0, 1, 12)]
        poly += [tuple(a + d * t - n * 14 * math.sin(math.pi * t) ** 0.9) for t in np.linspace(1, 0, 12)]
        m = K.poly_mask(h, w, [poly], offset=(rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5)))
        D = np.maximum(D, K.wash(m, 0.64, seed + k + 9, 50))
        K.stroke(S, poly[:12], 2.8, 1.6, load=0.96, pool=0.25, seed=int(rng.integers(1e6)))
        hl = [tuple(a + d * t + n * 6) for t in (0.25, 0.5, 0.72)]
        K.stroke(S, hl, 2.2, 0.9, load=0.0001, pool=0, seed=1)  # reserva (não pinta)
    for y in (34, T - 34):
        K.stroke(S, [(-4, y + rng.normal(0, 1)), (T / 2, y + rng.normal(0, 1.2)), (T + 4, y + rng.normal(0, 1))], 3.4, 2.8, load=0.96, pool=0, seed=int(rng.integers(1e6)), taper_in=0)
    D = np.maximum(K.granulate(D, seed, 0.1, 1.3), S)
    D = K.rough_edge(D, seed + 2, 0.9, 2.5)
    return compose(D, seed, glaze_base(h, w, seed))

# ------------------------------------------------------------------ parede: folha em quadrante (padrão 2x2)
def tile_folha(seed):
    rng = np.random.default_rng(seed)
    h = w = T
    D = np.zeros((h, w), np.float32)
    S = np.zeros_like(D)
    # quarto de folha a partir do canto superior esquerdo; o shader gira por paridade para fechar a roseta 2x2
    for ang, L, wd in ((45, 175, 46), (12, 120, 26), (78, 120, 26)):
        a = math.radians(ang)
        tip = (L * math.cos(a), L * math.sin(a))
        nrm = (-math.sin(a), math.cos(a))
        poly = []
        for t in np.linspace(0, 1, 14):
            r = wd * math.sin(math.pi * t) ** 0.8
            poly.append((tip[0] * t + nrm[0] * r, tip[1] * t + nrm[1] * r))
        for t in np.linspace(1, 0, 14):
            r = wd * math.sin(math.pi * t) ** 0.8
            poly.append((tip[0] * t - nrm[0] * r, tip[1] * t - nrm[1] * r))
        leaf = K.poly_mask(h, w, [poly], offset=(rng.uniform(-2, 2), rng.uniform(-2, 2)))
        D = np.maximum(D, K.wash(leaf, 0.62, seed + ang, ang))
        K.stroke(S, [(6, 6), (tip[0] * 0.5, tip[1] * 0.5), (tip[0] * 0.92, tip[1] * 0.92)], 2.6, 1.0, load=0.97, pool=0.2, seed=int(rng.integers(1e6)))
        K.stroke(S, poly[:14], 2.2, 1.4, load=0.95, pool=0.15, seed=int(rng.integers(1e6)))
        K.stroke(S, poly[14:], 2.2, 1.4, load=0.95, pool=0.15, seed=int(rng.integers(1e6)))
    D = np.maximum(D, K.ellipse_mask(h, w, 0, 0, 34, 34) * 0.95)
    # ramo de canto oposto (liga com o azulejo vizinho)
    K.stroke(S, [(T, T - 70), (T - 40, T - 40), (T - 70, T)], 3.0, 2.0, load=0.9, seed=int(rng.integers(1e6)))
    D = np.maximum(D, K.ellipse_mask(h, w, T, T, 22, 22) * 0.34)
    D = np.maximum(K.granulate(D, seed, 0.1, 1.3), S)
    D = K.rough_edge(D, seed + 4, 0.9, 2.5)
    return compose(D, seed, glaze_base(h, w, seed))

def tile_barra(seed):
    """Barra (rodapé) da parede: azul-noite com reserva branca em losango."""
    rng = np.random.default_rng(seed)
    h = w = T
    D = np.full((h, w), 0.95, np.float32)
    lz = K.poly_mask(h, w, [[(T / 2, 26), (T - 26, T / 2), (T / 2, T - 26), (26, T / 2)]], offset=(rng.uniform(-2, 2), rng.uniform(-2, 2)))
    D = D * (1 - lz)
    inner = K.poly_mask(h, w, [[(T / 2, 70), (T - 70, T / 2), (T / 2, T - 70), (70, T / 2)]], offset=(rng.uniform(-2, 2), rng.uniform(-2, 2)))
    D = np.maximum(D, inner * 0.33)
    S = np.zeros_like(D)
    K.stroke(S, [(T / 2, 76), (T / 2, T - 76)], 3.0, 1.6, load=0.95, seed=int(rng.integers(1e6)))
    K.stroke(S, [(76, T / 2), (T - 76, T / 2)], 3.0, 1.6, load=0.95, seed=int(rng.integers(1e6)))
    D = np.maximum(D, S)
    D = D * (0.93 + 0.1 * K.streaks(h, w, seed, 8, 60, 3))
    D = K.rough_edge(K.granulate(D, seed, 0.08, 1.3), seed, 0.9, 2.5)
    return compose(D, seed, glaze_base(h, w, seed))

# ------------------------------------------------------------------ painel figurativo: barco na tempestade
# biblioteca de motivos desenhados por regra: nuvem, onda, barco, gaivota, chuva.
def m_nuvem(S, D, cx, cy, R, rng):
    """Cúmulo: arcos de festão no topo, base reta; contorno a pincel e aguada por dentro."""
    n = 5
    pts = []
    for k in range(n):
        a0 = math.pi * (1 - k / n); a1 = math.pi * (1 - (k + 1) / n)
        bx = cx + R * math.cos((a0 + a1) / 2) * 1.25; by = cy - R * 0.25 * math.sin((a0 + a1) / 2)
        r = R * (0.42 + 0.12 * rng.random())
        for t in np.linspace(0, 1, 7):
            a = math.pi + math.pi * t
            pts.append((bx + r * math.cos(a), by + r * math.sin(a) * 0.95))
    base = [(cx + R * 1.75, cy + R * 0.3), (cx - R * 1.75, cy + R * 0.3)]
    poly = pts + base
    m = K.poly_mask(D.shape[0], D.shape[1], [poly], offset=(rng.uniform(-2, 2), rng.uniform(-2, 2)))
    D[:] = np.maximum(D, K.wash(m, 0.34, int(rng.integers(1e6)), 20))
    K.stroke(S, pts[:len(pts)], 3.2, 2.2, load=0.97, pool=0.25, seed=int(rng.integers(1e6)))
    K.stroke(S, [(cx - R * 1.6, cy + R * 0.3), (cx, cy + R * 0.33), (cx + R * 1.6, cy + R * 0.28)], 2.4, 1.2, load=0.8, pool=0.1, seed=int(rng.integers(1e6)))
    for k in range(3):  # sombra da nuvem em hachura curva
        y = cy + R * (0.05 + 0.08 * k)
        K.stroke(S, [(cx - R * (1.1 - 0.2 * k), y), (cx, y + 3), (cx + R * (1.0 - 0.2 * k), y)], 1.6, 0.8, load=0.7, pool=0, seed=int(rng.integers(1e6)))

def m_onda(S, D, x0, y0, L, H, rng, curl=True):
    """Onda de painel: dorso em S, crista enrolada com espuma em reserva, aguada média dentro."""
    back = [(x0 + L * t, y0 - H * math.sin(math.pi * t) ** 1.3 * (0.6 + 0.4 * t)) for t in np.linspace(0, 1, 16)]
    tipx, tipy = back[-1]
    crest = [(tipx, tipy - H * 0.15), (tipx + L * 0.12, tipy - H * 0.35), (tipx + L * 0.2, tipy - H * 0.05), (tipx + L * 0.12, tipy + H * 0.25), (tipx + L * 0.02, tipy + H * 0.08)]
    poly = back + [(tipx + L * 0.18, tipy + H * 0.1), (tipx + L * 0.3, D.shape[0] + 10), (x0 - L * 0.1, D.shape[0] + 10)]
    m = K.poly_mask(D.shape[0], D.shape[1], [poly], offset=(rng.uniform(-2, 2), rng.uniform(-2, 2)))
    D[:] = np.maximum(D, K.wash(m, 0.66, int(rng.integers(1e6)), -20))
    K.stroke(S, back, 4.0, 2.6, load=0.98, pool=0.2, seed=int(rng.integers(1e6)))
    if curl:
        K.stroke(S, crest, 3.0, 1.4, load=0.98, pool=0.35, seed=int(rng.integers(1e6)))
        for k in range(4):  # espuma: dedos da crista
            fx = tipx - L * (0.08 + 0.1 * k); fy = tipy - H * (0.05 - 0.03 * k) + H * 0.25 * (k / 4)
            K.stroke(S, [(fx, fy), (fx + 6, fy - 5), (fx + 12, fy - 2)], 1.8, 0.7, load=0.9, pool=0.15, seed=int(rng.integers(1e6)))
    for k in range(3):  # linhas de corrente no corpo da onda
        yy = y0 + H * (0.1 + 0.15 * k)
        K.stroke(S, [(x0 + L * 0.1, yy), (x0 + L * 0.5, yy - H * 0.12), (x0 + L * 0.9, yy - H * 0.05)], 1.6, 0.7, load=0.85, pool=0, seed=int(rng.integers(1e6)))

def m_barco(S, D, cx, cy, Lh, ang, rng):
    """Barco de pesca com vela latina, adernando."""
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    R = lambda x, y: (cx + x * ca - y * sa, cy + x * sa + y * ca)
    hull = [R(-Lh / 2, -Lh * 0.02), R(Lh / 2 + Lh * 0.08, -Lh * 0.12), R(Lh * 0.38, Lh * 0.14), R(-Lh * 0.36, Lh * 0.14)]
    m = K.poly_mask(D.shape[0], D.shape[1], [hull])
    D[:] = np.maximum(D, K.wash(m, 0.92, 7, ang))
    K.stroke(S, [hull[0], hull[1]], 2.8, 2.2, load=0.98, pool=0.2, seed=int(rng.integers(1e6)))
    mast = [R(-Lh * 0.02, -Lh * 0.02), R(0.0, -Lh * 0.95)]
    K.stroke(S, mast, 3.0, 2.0, load=0.98, pool=0.3, seed=int(rng.integers(1e6)))
    sail = [R(0.02 * Lh, -Lh * 0.92), R(Lh * 0.46, -Lh * 0.18), R(0.02 * Lh, -Lh * 0.12)]
    ms = K.poly_mask(D.shape[0], D.shape[1], [sail])
    D[:] = np.maximum(D, ms * 0.08)
    sm = K.poly_mask(D.shape[0], D.shape[1], [[sail[0], sail[1], R(Lh * 0.2, -Lh * 0.45)]])
    D[:] = np.maximum(D, K.wash(sm, 0.33, 3, ang + 40))
    K.stroke(S, sail + [sail[0]], 2.6, 1.8, load=0.98, pool=0.2, seed=int(rng.integers(1e6)), smooth=False)
    for k in range(4):  # costuras da vela
        t = (k + 1) / 5
        a = (sail[0][0] + (sail[2][0] - sail[0][0]) * t, sail[0][1] + (sail[2][1] - sail[0][1]) * t)
        b = (sail[0][0] + (sail[1][0] - sail[0][0]) * t, sail[0][1] + (sail[1][1] - sail[0][1]) * t)
        K.stroke(S, [a, b], 1.3, 0.8, load=0.75, pool=0, seed=int(rng.integers(1e6)), smooth=False)
    for k in range(3):  # tábuas do casco (reserva)
        t = 0.3 + 0.2 * k
        K.stroke(S, [R(-Lh * 0.4, Lh * 0.13 * t), R(Lh * 0.4, -Lh * 0.05 + Lh * 0.13 * t)], 1.0, 0.8, load=0.0, pool=0, seed=1)
    flag = [R(0, -Lh * 0.95), R(Lh * 0.12, -Lh * 0.98), R(Lh * 0.02, -Lh * 0.88)]
    K.stroke(S, flag, 2.0, 1.2, load=0.95, pool=0.1, seed=int(rng.integers(1e6)))

def m_gaivota(S, x, y, s, rng):
    K.stroke(S, [(x - s, y - s * 0.1), (x - s * 0.45, y - s * 0.45), (x, y)], 2.0, 1.0, load=0.95, pool=0.2, seed=int(rng.integers(1e6)))
    K.stroke(S, [(x, y), (x + s * 0.5, y - s * 0.5), (x + s, y - s * 0.2)], 2.0, 1.0, load=0.95, pool=0.2, seed=int(rng.integers(1e6)))

def painel_barco(W=1024, H=512, seed=900):
    rng = np.random.default_rng(seed)
    D = np.zeros((H, W), np.float32); S = np.zeros_like(D)
    # céu de tempestade: faixas de aguada horizontais no alto (nunca degradê liso: pinceladas)
    for k in range(7):
        y = 18 + k * 22
        K.stroke(D, [(-10, y + rng.normal(0, 3)), (W / 2, y + rng.normal(0, 5)), (W + 10, y + rng.normal(0, 3))], 9 - k, 7 - k * 0.6, load=0.42 - k * 0.03, pool=0, seed=int(rng.integers(1e6)), taper_in=0, dry=0.2)
    m_nuvem(S, D, 210, 120, 70, rng); m_nuvem(S, D, 640, 90, 85, rng); m_nuvem(S, D, 900, 150, 55, rng)
    for k in range(26):  # chuva em hachura diagonal
        x = rng.uniform(380, 1000); y = rng.uniform(150, 230)
        K.stroke(S, [(x, y), (x - 14, y + 40)], 1.2, 0.6, load=0.75, pool=0, seed=int(rng.integers(1e6)))
    # raio da tempestade: zigue-zague em cobalto (não amarelo: decoração estática não usa cor de matéria)
    zz = [(735, 160), (722, 200), (742, 214), (716, 262), (736, 272), (712, 318)]
    K.stroke(S, zz, 3.2, 1.6, load=0.98, pool=0.3, seed=11, smooth=False)
    m_gaivota(S, 330, 230, 16, rng); m_gaivota(S, 380, 205, 11, rng); m_gaivota(S, 870, 250, 13, rng)
    # mar: aguada de fundo em pinceladas horizontais, depois três planos de onda
    for k in range(12):
        y = 300 + k * 18
        K.stroke(D, [(-10, y + rng.normal(0, 3)), (W / 2, y + rng.normal(0, 4)), (W + 10, y + rng.normal(0, 3))], 11, 10, load=0.36, pool=0, seed=int(rng.integers(1e6)), taper_in=0, dry=0.05)
    m_onda(S, D, 560, 360, 380, 70, rng)
    m_barco(S, D, 420, 330, 210, -14, rng)
    m_onda(S, D, 40, 400, 420, 85, rng)
    m_onda(S, D, 620, 450, 400, 75, rng)
    for k in range(9):
        y = 470 + k * 5
        K.stroke(S, [(rng.uniform(0, 60), y), (W / 2, y + rng.normal(0, 3)), (W - rng.uniform(0, 60), y)], 1.4, 0.9, load=0.6, pool=0, seed=int(rng.integers(1e6)))
    D = np.maximum(K.granulate(D, seed, 0.1, 1.3), S)
    D = K.rough_edge(D, seed + 3, 0.9, 2.5)
    return compose(D, seed, glaze_base(H, W, seed))

# ------------------------------------------------------------------ placa "RUA DA SALGA" (letras a pincel)
GLYPH = {
    'R': [[(0, 0), (0, 1)], [(0, 1), (0.42, 0.98), (0.56, 0.8), (0.44, 0.58), (0.02, 0.55)], [(0.22, 0.55), (0.6, 0.0)]],
    'U': [[(0, 1), (0, 0.28), (0.1, 0.06), (0.3, 0.0), (0.5, 0.06), (0.6, 0.28), (0.6, 1)]],
    'A': [[(0, 0), (0.3, 1), (0.62, 0)], [(0.13, 0.36), (0.5, 0.36)]],
    'D': [[(0, 0), (0, 1)], [(0, 1), (0.34, 0.97), (0.58, 0.72), (0.58, 0.28), (0.34, 0.03), (0.0, 0.0)]],
    'S': [[(0.58, 0.86), (0.44, 0.98), (0.18, 0.98), (0.03, 0.82), (0.1, 0.6), (0.48, 0.44), (0.6, 0.22), (0.46, 0.03), (0.16, 0.02), (0.0, 0.14)]],
    'L': [[(0, 1), (0, 0), (0.55, 0)]],
    'G': [[(0.6, 0.84), (0.46, 0.98), (0.2, 0.98), (0.03, 0.76), (0.0, 0.4), (0.12, 0.08), (0.32, 0.0), (0.55, 0.08), (0.62, 0.38), (0.36, 0.38)]],
}

def placa(W=1024, H=256, text='RUA DA SALGA', seed=950):
    rng = np.random.default_rng(seed)
    D = np.zeros((H, W), np.float32); S = np.zeros_like(D)
    for m in (14, 26):  # moldura dupla
        r = [(m, m), (W - m, m), (W - m, H - m), (m, H - m), (m, m)]
        K.stroke(S, r, 4.5 if m == 14 else 2.2, 4 if m == 14 else 2, load=0.98, pool=0.1, seed=int(rng.integers(1e6)), smooth=False, taper_in=0.02)
    for cx, cy in ((26, 26), (W - 26, 26), (W - 26, H - 26), (26, H - 26)):
        K.stroke(S, [(cx - 1, cy), (cx + 1, cy)], 9, 9, load=1.0, pool=0, seed=1)
    gh = 100; gw = 0.62 * gh; sp = 0.20 * gh
    total = sum(gw if c != ' ' else gw * 0.5 for c in text) + sp * (len(text) - 1)
    x = (W - total) / 2; y0 = H / 2 + gh / 2
    for ch in text:
        if ch == ' ':
            x += gw * 0.5 + sp; continue
        for path in GLYPH[ch]:
            pts = [(x + px * gh + rng.normal(0, 1.2), y0 - py * gh + rng.normal(0, 1.2)) for px, py in path]
            K.stroke(S, pts, 8.0, 5.0, load=1.0, pool=0.35, seed=int(rng.integers(1e6)), smooth=len(pts) > 3)
        x += gw + sp
    D = np.maximum(D, S)
    D = K.rough_edge(D, seed, 0.9, 2.5)
    return compose(D, seed, glaze_base(H, W, seed))

def atlas(tiles, cols):
    rows = math.ceil(len(tiles) / cols)
    A = np.zeros((rows * T, cols * T, 3), np.float32)
    for i, t in enumerate(tiles):
        r, c = divmod(i, cols)
        A[r * T:(r + 1) * T, c * T:(c + 1) * T] = t
    return A

if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    t0 = time.time()
    piso = [tile_losango(100 + i) for i in range(6)] + [tile_corda(200 + i) for i in range(2)]
    K.to_img(atlas(piso, 4)).save(os.path.join(out, 'piso_atlas.png'))
    parede = [tile_folha(300 + i) for i in range(4)] + [tile_barra(400 + i) for i in range(2)] + [tile_corda(500 + i) for i in range(2)]
    K.to_img(atlas(parede, 4)).save(os.path.join(out, 'parede_atlas.png'))
    K.to_img(painel_barco()).save(os.path.join(out, 'painel_barco.png'))
    K.to_img(placa()).save(os.path.join(out, 'placa.png'))
    print('texturas', round(time.time() - t0, 1), 's')

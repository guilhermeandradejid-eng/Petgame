# Pincel e estampilha simulados em numpy.
# Pincel: o traço começa carregado, afina, perde carga e deixa uma poça de pigmento onde para.
# Estampilha: molde vazado com borda nítida e erro de registro de 1 a 2 px entre cores.
# Tudo devolve um campo de DENSIDADE de pigmento (0..1+); a cor sai da rampa de 3 valores do cobalto.
import math
import numpy as np
from PIL import Image, ImageDraw
from paleta import rgb

# ------------------------------------------------------------------ ruído
def value_noise(h, w, cell, seed, cell_y=None):
    rng = np.random.default_rng(seed)
    cy = cell if cell_y is None else cell_y
    gh, gw = int(h / cy) + 3, int(w / cell) + 3
    g = rng.random((gh, gw)).astype(np.float32)
    y = np.arange(h, dtype=np.float32) / cy
    x = np.arange(w, dtype=np.float32) / cell
    yi = y.astype(int); xi = x.astype(int)
    fy = y - yi; fx = x - xi
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    a = g[yi][:, xi]; b = g[yi][:, xi + 1]; c = g[yi + 1][:, xi]; d = g[yi + 1][:, xi + 1]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]

def fbm(h, w, cell, seed, oct=4):
    out = np.zeros((h, w), np.float32); amp = 1.0; tot = 0
    for o in range(oct):
        out += amp * value_noise(h, w, max(1.0, cell / 2 ** o), seed + 17 * o)
        tot += amp; amp *= 0.5
    return out / tot

# ------------------------------------------------------------------ pincel
def _dab(D, cx, cy, r, a, soft=0.9):
    h, w = D.shape
    x0, x1 = int(max(0, cx - r - 2)), int(min(w, cx + r + 3))
    y0, y1 = int(max(0, cy - r - 2)), int(min(h, cy + r + 3))
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    m = np.clip((r - d) / max(0.7, soft), 0, 1) * a
    sub = D[y0:y1, x0:x1]
    np.maximum(sub, m, out=sub)

def resample(pts, step):
    pts = [np.array(p, np.float32) for p in pts]
    out = [pts[0]]
    for a, b in zip(pts[:-1], pts[1:]):
        L = float(np.linalg.norm(b - a))
        n = max(1, int(L / step))
        for i in range(1, n + 1):
            out.append(a + (b - a) * (i / n))
    return out

def catmull(pts, n=8):
    """Curva suave que passa pelos pontos (para traços desenhados à mão)."""
    P = [np.array(p, np.float32) for p in pts]
    if len(P) < 3:
        return P
    P = [P[0]] + P + [P[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P[-2])
    return out

def stroke(D, pts, w0, w1=None, load=1.0, pool=0.35, seed=0, smooth=True, taper_in=0.12, dry=0.35):
    """Traço com carga de tinta. D: campo de densidade (modificado no lugar).
    w0/w1: raio no começo/fim (px). load: densidade inicial. pool: densidade extra na poça final.
    dry: quanto a carga cai ao longo do traço."""
    rng = np.random.default_rng(seed)
    if w1 is None:
        w1 = w0 * 0.55
    path = catmull(pts) if (smooth and len(pts) > 2) else pts
    path = resample(path, max(0.6, min(w0, w1) * 0.35))
    n = len(path)
    ph = rng.random() * 6.28
    for i, p in enumerate(path):
        u = i / max(1, n - 1)
        grow = min(1.0, u / taper_in) ** 0.6 if taper_in > 0 else 1.0
        r = (w0 + (w1 - w0) * u) * (0.55 + 0.45 * grow) * (1 + 0.10 * math.sin(ph + u * 23.0) + 0.06 * rng.standard_normal())
        a = load * (1.0 - dry * u) * (0.93 + 0.07 * rng.random())
        _dab(D, p[0], p[1], max(0.6, r), a)
    if pool > 0 and n > 1:  # poça de pigmento no fim do traço
        p = path[-1]; q = path[max(0, n - 4)]
        d = (p - q); d = d / (np.linalg.norm(d) + 1e-6)
        rr = max(0.8, w1 * 1.05)
        _dab(D, p[0] - d[0] * rr * 0.3, p[1] - d[1] * rr * 0.3, rr, min(1.25, load * (1 - dry) + pool))

def streaks(h, w, seed, ang=0.0, along=40.0, across=2.5):
    """Estrias do pincel largo na aguada, numa direção (graus)."""
    S = max(h, w) * 2
    n = value_noise(S, S, along, seed, across) * 0.7 + value_noise(S, S, along * 0.5, seed + 1, across * 3) * 0.3
    im = Image.fromarray((n * 255).astype(np.uint8)).rotate(ang, resample=Image.BILINEAR)
    o = (S - w) // 2, (S - h) // 2
    return np.asarray(im.crop((o[0], o[1], o[0] + w, o[1] + h))).astype(np.float32) / 255

def wash(mask, level, seed, ang=0.0, var=0.16):
    """Aguada: densidade quase plana com estrias na direção do pincel e acúmulo na borda."""
    h, w = mask.shape
    st = streaks(h, w, seed, ang)
    edge = np.clip(mask - np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(__import__('PIL.ImageFilter', fromlist=['x']).MinFilter(5))).astype(np.float32) / 255, 0, 1)
    return mask * level * (1 - var / 2 + var * st) + edge * level * 0.25

def granulate(D, seed, amount=0.18, cell=2.0):
    """Granulação do pigmento: o cobalto se junta em grãos, mais visível na aguada."""
    h, w = D.shape
    n = value_noise(h, w, cell, seed) * 0.6 + value_noise(h, w, cell * 5, seed + 3) * 0.4
    k = amount * (1 - np.clip(D, 0, 1)) * 2.0
    return np.clip(D * (1 - k * (n - 0.35)), 0, 1.4)

def rough_edge(D, seed, px=1.2, cell=3.0):
    """Borda irregular: desloca a amostragem por ruído (o pincel não é compasso)."""
    h, w = D.shape
    dx = (value_noise(h, w, cell, seed) - 0.5) * 2 * px
    dy = (value_noise(h, w, cell, seed + 1) - 0.5) * 2 * px
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    xs = np.clip((xx + dx).round().astype(int), 0, w - 1)
    ys = np.clip((yy + dy).round().astype(int), 0, h - 1)
    return D[ys, xs]

# ------------------------------------------------------------------ estampilha
def poly_mask(h, w, polys, ss=4, offset=(0, 0)):
    """Molde vazado: polígonos preenchidos com borda nítida (antisserrilhado por superamostragem)."""
    im = Image.new('L', (w * ss, h * ss), 0)
    dr = ImageDraw.Draw(im)
    for poly in polys:
        dr.polygon([((x + offset[0]) * ss, (y + offset[1]) * ss) for x, y in poly], fill=255)
    im = im.resize((w, h), Image.BOX)
    return np.asarray(im).astype(np.float32) / 255

def ellipse_mask(h, w, cx, cy, rx, ry, ss=4):
    im = Image.new('L', (w * ss, h * ss), 0)
    ImageDraw.Draw(im).ellipse([(cx - rx) * ss, (cy - ry) * ss, (cx + rx) * ss, (cy + ry) * ss], fill=255)
    return np.asarray(im.resize((w, h), Image.BOX)).astype(np.float32) / 255

# ------------------------------------------------------------------ cor
RAMP_W = ['estanho', 'aguado', 'medio', 'noite']   # cobalto sobre estanho
RAMP_N = ['noite', 'medio', 'aguado', 'estanho']   # branco sobre azul-noite (heróis)

def ramp(D, names=RAMP_W, stops=(0.0, 0.30, 0.62, 0.92), sharp=0.06):
    """Densidade -> cor em 3 valores mais o fundo. Transição curta (sharp) para a paleta ficar curta,
    sem degradê liso."""
    cols = np.array([rgb(n) for n in names], np.float32)
    D = np.clip(D, 0, 1.2)
    out = np.broadcast_to(cols[0], D.shape + (3,)).copy()
    for i in range(1, len(names)):
        t = np.clip((D - (stops[i] - sharp / 2)) / sharp, 0, 1)[..., None]
        out = out * (1 - t) + cols[i] * t
    return out

def to_img(rgbf):
    return Image.fromarray((np.clip(rgbf, 0, 1) * 255 + 0.5).astype(np.uint8))

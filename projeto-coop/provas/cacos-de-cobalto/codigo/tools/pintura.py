# Pintores das regiões do atlas das figuras. Esmalte azul-noite com pintura branca a pincel
# (o herói é o negativo do mundo), pele em reserva branca com aguada de cobalto,
# materiais do porto foscos, miolo de biscoito e salitre granulado.
import math
import numpy as np
import pincel as K
from paleta import rgb

def _rng(seed):
    return np.random.default_rng(seed)

def navy(w, h, seed, deco=None):
    """Esmalte azul-noite; deco(D, w, h, rng) pinta o branco (densidade sobe para 1)."""
    rng = _rng(seed)
    D = K.fbm(h, w, 24, seed, 2) * 0.05
    if deco:
        deco(D, w, h, rng)
    D = K.rough_edge(D, seed + 1, 0.8, 2.0)
    return K.ramp(D, K.RAMP_N, stops=(0.0, 0.30, 0.60, 0.86))

def skin(w, h, seed):
    """Pele = reserva branca com aguada de cobalto nas bordas (modelado pintado)."""
    D = np.ones((h, w), np.float32)
    t = np.linspace(0, 1, h)[:, None]
    D -= 0.42 * (t > 0.82) * (0.85 + 0.15 * K.streaks(h, w, seed, 0, 30, 2))
    return K.ramp(np.clip(D, 0, 1), K.RAMP_N, stops=(0.0, 0.30, 0.60, 0.86))

def flat(name, w, h, seed, var=0.04):
    c = np.array(rgb(name), np.float32)
    n = K.fbm(h, w, 16, seed, 2)
    return np.broadcast_to(c, (h, w, 3)) * (1 - var / 2 + var * n[..., None])

def two(name_a, name_b, mask):
    a = np.array(rgb(name_a), np.float32); b = np.array(rgb(name_b), np.float32)
    return a * (1 - mask[..., None]) + b * mask[..., None]

def wood(w, h, seed):
    """Madeira de cais: veio ao longo do comprimento (t), dois tons, nós raros."""
    st = K.streaks(h, w, seed, 90, 70, 2.2)
    m = (st > 0.62).astype(np.float32)
    return two('madeira', 'madeira_e', m * 0.85)

def iron(w, h, seed):
    n = K.fbm(h, w, 10, seed, 3)
    return two('ferro', 'madeira_e', (n > 0.62).astype(np.float32) * 0.6)

def rope(w, h, seed):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    m = ((np.sin((xx * 0.9 + yy * 1.6) * 0.35) > 0.55)).astype(np.float32)
    return two('corda', 'madeira', m * 0.8)

def flame(w, h, seed):
    t = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    m = (t > 0.38).astype(np.float32)
    return two('brasa', 'faisca', m)

def cal(w, h, seed):
    n = K.streaks(h, w, seed, 90, 20, 3)
    return two('cal', 'estanho', (n > 0.72).astype(np.float32))

def accent(name, w, h, seed, stripes=None):
    base = flat(name, w, h, seed, 0.03)
    if stripes:
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        m = (np.sin(xx / w * math.pi * 2 * stripes) > 0.6).astype(np.float32)
        base = base * (1 - m[..., None] * 0.18)
    return base

def bisque(w, h, seed):
    """Miolo do caco: biscoito poroso com grão."""
    n = K.value_noise(h, w, 1.5, seed)
    c = np.array(rgb('biscoito'), np.float32)
    return np.broadcast_to(c, (h, w, 3)) * (0.93 + 0.1 * n[..., None])

def terracota(w, h, seed):
    """Miolo dos cacos inimigos: terracota crua, porosa, com grão e manchas de queima."""
    n = K.value_noise(h, w, 1.5, seed) * 0.6 + K.value_noise(h, w, 6, seed + 3) * 0.4
    c = np.array(rgb('terracota'), np.float32)
    return np.broadcast_to(c, (h, w, 3)) * (0.86 + 0.22 * n[..., None])

def salitre_v(w, h, seed):
    """Salitre dos Descascados: branco-esverdeado, granulado e fosco."""
    n = K.value_noise(h, w, 1.2, seed) * 0.6 + K.value_noise(h, w, 4, seed + 1) * 0.4
    m = (n > 0.58).astype(np.float32)
    return two('salitre_v', 'rejunte', m * 0.55)

def salitre(w, h, seed):
    """Salitre: branco-acinzentado granulado e fosco (grão grosso + fino)."""
    n = K.value_noise(h, w, 1.2, seed) * 0.6 + K.value_noise(h, w, 4, seed + 1) * 0.4
    m = (n > 0.58).astype(np.float32)
    return two('salitre', 'rejunte', m * 0.75)

# ------------------------------------------------------------------ decorações (densidade de branco)
def deco_dots(spacing, r, rows=None, load=0.95, jitter=0.25):
    def f(D, w, h, rng):
        for yi, y in enumerate(np.arange(spacing / 2, h, spacing * 0.866)):
            if rows and not (rows[0] <= y / h <= rows[1]):
                continue
            off = (spacing / 2) if yi % 2 else 0
            for x in np.arange(off, w + spacing, spacing):
                cx, cy = x + rng.normal(0, spacing * jitter * 0.2), y + rng.normal(0, spacing * jitter * 0.2)
                rr = r * (0.85 + 0.3 * rng.random())
                K.stroke(D, [(cx - rr * 0.3, cy), (cx + rr * 0.3, cy + rr * 0.1)], rr, rr * 0.8, load=load, pool=0.1, seed=int(rng.integers(1e6)), taper_in=0.3)
    return f

def deco_bands(ts, width, load=0.95, wave=0.0, nwave=6):
    def f(D, w, h, rng):
        for t in ts:
            y = t * h
            pts = [(x, y + wave * h * math.sin(x / w * math.pi * 2 * nwave) + rng.normal(0, 0.6)) for x in np.linspace(-6, w + 6, 24)]
            K.stroke(D, pts, width, width * 0.8, load=load, pool=0.0, seed=int(rng.integers(1e6)), taper_in=0.0, dry=0.1)
    return f

def deco_scallops(t, n, depth, width, load=0.95):
    """Barra em festão: arcos pintados em volta da peça."""
    def f(D, w, h, rng):
        y = t * h
        for k in range(n):
            x0 = k * w / n; x1 = (k + 1) * w / n
            pts = [(x0 + (x1 - x0) * u, y + depth * h * math.sin(math.pi * u)) for u in np.linspace(0, 1, 7)]
            K.stroke(D, pts, width, width * 0.6, load=load, pool=0.2, seed=int(rng.integers(1e6)))
            cx = (x0 + x1) / 2
            K.stroke(D, [(cx, y + depth * h * 0.35), (cx + 1, y + depth * h * 0.55)], width * 1.2, width, load=load, pool=0.1, seed=int(rng.integers(1e6)))
    return f

def deco_folds(n, t0, t1, width, phase=0.0, load=0.72):
    """Traços verticais nos vales das pregas: a pintura segue a forma."""
    def f(D, w, h, rng):
        for k in range(n):
            x = ((k + 0.5 + phase) / n) * w
            pts = [(x + rng.normal(0, 1.2), t0 * h), (x + rng.normal(0, 2.0), (t0 + t1) / 2 * h), (x + rng.normal(0, 2.5), t1 * h)]
            K.stroke(D, pts, width * 0.45, width, load=load, pool=0.25, seed=int(rng.integers(1e6)), dry=0.05)
    return f

def deco_stripes_v(n, width, load=0.9):
    def f(D, w, h, rng):
        for k in range(n):
            x = (k + 0.5) / n * w
            K.stroke(D, [(x + rng.normal(0, 0.8), -4), (x + rng.normal(0, 1.2), h / 2), (x + rng.normal(0, 0.8), h + 4)], width, width * 0.85, load=load, pool=0.0, seed=int(rng.integers(1e6)), taper_in=0.0, dry=0.12)
    return f

def deco_flower(cx, cy, R, petals=6, load=0.97):
    def f(D, w, h, rng):
        x0, y0 = cx * w, cy * h
        for k in range(petals):
            a = 2 * math.pi * k / petals + rng.normal(0, 0.05)
            pts = [(x0 + math.cos(a) * R * 0.18, y0 + math.sin(a) * R * 0.18), (x0 + math.cos(a + 0.12) * R * 0.6, y0 + math.sin(a + 0.12) * R * 0.6), (x0 + math.cos(a) * R, y0 + math.sin(a) * R)]
            K.stroke(D, pts, R * 0.2, R * 0.08, load=load, pool=0.3, seed=int(rng.integers(1e6)), taper_in=0.25)
        K.stroke(D, [(x0 - 1, y0), (x0 + 1, y0)], R * 0.14, R * 0.14, load=0.0, pool=0, seed=1)
    return f

def deco_leaves(n, t0, t1, size, load=0.9):
    def f(D, w, h, rng):
        for k in range(n):
            x = rng.random() * w; y = (t0 + (t1 - t0) * rng.random()) * h
            a = rng.random() * 6.28
            K.stroke(D, [(x, y), (x + math.cos(a) * size, y + math.sin(a) * size)], size * 0.35, size * 0.12, load=load, pool=0.3, seed=int(rng.integers(1e6)), taper_in=0.4)
    return f

def deco_text_lines(n, t0, t1, width, load=0.62):
    """Linhas de 'texto' de jornal (chapéu de papel): traços curtos em fila."""
    def f(D, w, h, rng):
        for k in range(n):
            y = (t0 + (t1 - t0) * k / max(1, n - 1)) * h
            x = rng.uniform(2, 10)
            while x < w - 8:
                L = rng.uniform(5, 16)
                K.stroke(D, [(x, y), (x + L, y + rng.normal(0, 0.3))], width, width * 0.8, load=load, pool=0, seed=int(rng.integers(1e6)), taper_in=0.0)
                x += L + rng.uniform(3, 6)
    return f

def compose_deco(*fs):
    def f(D, w, h, rng):
        for g in fs:
            g(D, w, h, rng)
    return f

def subtract(fn):
    """Pinta azul-noite sobre branco (traço que tira o branco)."""
    def f(D, w, h, rng):
        M = np.zeros_like(D)
        fn(M, w, h, rng)
        D *= (1 - np.clip(M, 0, 1))
    return f

def face_region(w, h, seed, face_s=(0.30, 0.70), face_t=(0.18, 1.0), hair=None):
    """Cabeça: frente em reserva branca (rosto), aguada nas bordas do rosto, resto em azul-noite.
    Os 3 traços do rosto (olhos e boca) são desenhados pelo shader."""
    rng = _rng(seed)
    D = K.fbm(h, w, 24, seed, 2) * 0.05
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    s = xx / w; t = yy / h
    cs, rs = (face_s[0] + face_s[1]) / 2, (face_s[1] - face_s[0]) / 2
    ct, rt = (face_t[0] + face_t[1]) / 2, (face_t[1] - face_t[0]) / 2
    e = ((s - cs) / rs) ** 2 + ((t - ct) / rt) ** 2
    e = K.rough_edge(e.astype(np.float32), seed, 1.5, 3)
    D = np.where(e < 1.0, 1.0, D)
    D = np.where((e > 0.62) & (e < 1.0), 0.66 + 0.06 * K.streaks(h, w, seed, 90, 20, 2), D)  # aguada de modelado
    if hair:
        hair(D, w, h, rng)
    return K.ramp(np.clip(D, 0, 1.2), K.RAMP_N, stops=(0.0, 0.30, 0.60, 0.86))

def white_panel(w, h, seed, deco=None):
    """Reserva branca com pintura de cobalto (rampa do mundo): avental, peitilho."""
    rng = _rng(seed)
    D = np.zeros((h, w), np.float32)
    if deco:
        deco(D, w, h, rng)
    D = K.rough_edge(D, seed + 1, 0.8, 2.0)
    base = np.array(rgb('estanho'), np.float32)
    col = K.ramp(D, K.RAMP_W)
    return col

def deco_hair(cs, t0, t1, n):
    """Franja: mechas pintadas do topo do rosto para baixo (azul-noite sobre a reserva)."""
    def f(D, w, h, rng):
        for k in range(n):
            u = (k + 0.5) / n
            x = (cs - 0.2 + 0.4 * u) * w
            y0 = t0 * h - 6; y1 = (t0 + (t1 - t0) * (0.6 + 0.4 * math.sin(math.pi * u))) * h
            K.stroke(D, [(x, y0), (x + (u - 0.5) * 10, (y0 + y1) / 2), (x + (u - 0.5) * 16, y1)], 7, 3, load=1.0, pool=0.2, seed=int(rng.integers(1e6)))
        K.stroke(D, [((cs - 0.21) * w, t0 * h - 3), (cs * w, t0 * h + 2), ((cs + 0.21) * w, t0 * h - 3)], 9, 9, load=1.0, pool=0, seed=3, taper_in=0)
    return f

def deco_mustache(cs, t, half, width):
    def f(D, w, h, rng):
        for sx in (-1, 1):
            K.stroke(D, [(cs * w + sx * 2, t * h), (cs * w + sx * half * w * 0.5, t * h + 3), (cs * w + sx * half * w, t * h - 2)], width, width * 0.35, load=1.0, pool=0.2, seed=int(rng.integers(1e6)))
    return f

# Tecidos dos bonecos por código (numpy): xadrez em sarja, chita de fundo escuro, listrado de colchão,
# poá, retalho de chita lavada (asas da traça) e a lona pintada do bastidor. Cada tecido tem trama.
# Uso: python3 tecidos.py SAIDA
import sys, os, math
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paleta as PAL

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
S = 1024

def C(n):
    return np.array(PAL.f(n), np.float32)

def vnoise(h, w, cell, rng):
    gh, gw = max(2, h // cell), max(2, w // cell)
    g = rng.random((gh + 1, gw + 1)).astype(np.float32)
    g[-1, :] = g[0, :]; g[:, -1] = g[:, 0]
    im = Image.fromarray(g).resize((w + w // gw, h + h // gh), Image.BICUBIC)
    return np.asarray(im)[:h, :w]

def fbm(h, w, cell, rng, oc=3):
    a, s, t = 1.0, 0, 0
    for i in range(oc):
        s = s + a * vnoise(h, w, max(2, cell >> i), rng); t += a; a *= 0.5
    return s / t

def cov(sdf, aa=1.2):
    return np.clip(0.5 - sdf / aa, 0, 1)

Y, X = np.mgrid[0:S, 0:S].astype(np.float32) + 0.5

def weave(img, period=8, amp=0.07, twill=True):
    """trama: fios de urdume e trama alternando em sarja; modula valor sem mudar a cor."""
    tx = (X // (period / 2)).astype(int); ty = (Y // (period / 2)).astype(int)
    over = ((tx + (ty if twill else 0) * (1 if twill else 0)) // (2 if twill else 1) + ty) % 2 if not twill else ((tx + ty) // 2) % 2
    fx = np.abs(np.sin(X * math.pi / (period / 2))); fy = np.abs(np.sin(Y * math.pi / (period / 2)))
    th = np.where(over == 1, fx, fy)
    return img * (1 - amp + amp * 1.4 * th[..., None] ** 0.6)

def save(img, name, out=512):
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((out, out), Image.LANCZOS)
    im.save(os.path.join(OUT, name))

def paint(img, m, col):
    img[:] = img * (1 - m[..., None]) + C(col) * m[..., None]

# ---------------------------------------------------------------- xadrez escuro (Tarugo)
def xadrez():
    sett = [('vinho', 70), ('tabua_esc', 46), ('vinho', 14), ('bochecha', 6), ('vinho', 14), ('tabua_esc', 46), ('vinho', 40), ('creme', 4), ('vinho', 16)]
    tot = sum(w for _, w in sett)
    lut = []
    for c, w in sett:
        lut += [c] * w
    def band(coord):
        idx = (coord * tot / (S / 2)).astype(int) % tot
        out = np.zeros(coord.shape + (3,), np.float32)
        for name in set(lut):
            m = np.array([lut[i] == name for i in range(tot)])[idx]
            out[m] = C(name)
        return out
    warp = band(X); weft = band(Y)
    tw = (((X // 3).astype(int) + (Y // 3).astype(int)) % 4) < 2
    img = np.where(tw[..., None], warp, weft)
    img = 0.75 * img + 0.25 * (warp + weft) / 2
    img = weave(img, 6, 0.10)
    rng = np.random.default_rng(1)
    img *= (0.95 + 0.08 * fbm(S, S, 64, rng))[..., None]
    save(img, 'xadrez.png')

# ---------------------------------------------------------------- chita de fundo escuro (Anilina)
def flower(img, cx, cy, R, rng, petal, center):
    dx = (X - cx + S / 2) % S - S / 2; dy = (Y - cy + S / 2) % S - S / 2
    r = np.hypot(dx, dy); th = np.arctan2(dy, dx) + rng.random() * 6.28
    for a in (rng.random() * 6.28, rng.random() * 6.28 + 2.5):
        ux, uy = math.cos(a), math.sin(a)
        px = dx * ux + dy * uy - R * 1.05; py = -dx * uy + dy * ux
        e = np.hypot(px / (R * 0.8), py / (R * 0.33)) - 1
        paint(img, cov(e * R * 0.3 - 2.0), 'tinta')
        paint(img, cov(e * R * 0.3 + 1.5), 'musgo')
        paint(img, cov(np.abs(py) - 1.2) * (np.abs(px) < R * 0.6), 'musgo_esc')
    n = int(rng.integers(5, 7))
    rp = R * (0.6 + 0.4 * np.abs(np.cos(n * th / 2)) ** 0.7)
    paint(img, cov(r - rp - 2.5), 'tinta')
    paint(img, cov(r - rp + 1.5), petal)
    # pincelada interna da pétala (sombra de estampa)
    paint(img, cov(r - rp * 0.62) * 0.35, 'tinta')
    paint(img, cov(r - R * 0.28), center)
    for q in range(n):
        aa = q * 6.283 / n + 0.3
        paint(img, cov(np.hypot(dx - math.cos(aa) * R * 0.4, dy - math.sin(aa) * R * 0.4) - R * 0.045), 'creme')

def chita_escura():
    rng = np.random.default_rng(7)
    img = np.ones((S, S, 3), np.float32) * C('verde_esc')
    for i in range(220):
        cx, cy = rng.random(2) * S
        dx = (X - cx + S / 2) % S - S / 2; dy = (Y - cy + S / 2) % S - S / 2
        paint(img, cov(np.hypot(dx, dy) - S * 0.004), 'lua')
    n = 3
    cols = ['lua', 'bochecha', 'creme', 'lua', 'bochecha', 'creme', 'lua', 'bochecha', 'creme']
    k = 0
    for i in range(n):
        for j in range(n):
            cx = (i + 0.5 + (j % 2) * 0.5 + (rng.random() - 0.5) * 0.3) * S / n
            cy = (j + 0.5 + (rng.random() - 0.5) * 0.3) * S / n
            flower(img, cx, cy, S * (0.075 + rng.random() * 0.03), rng, cols[k], 'p_gema' if cols[k] != 'lua' else 'bochecha'); k += 1
    img = weave(img, 5, 0.08, twill=False)
    save(img, 'chita.png')

# ---------------------------------------------------------------- listrado de colchão (Retrós)
def listrado():
    img = np.ones((S, S, 3), np.float32) * C('marinho')
    per = S / 8
    u = X % per
    paint(img, ((u > per * 0.62) & (u < per * 0.7)).astype(np.float32), 'creme')
    paint(img, ((u > per * 0.76) & (u < per * 0.79)).astype(np.float32), 'creme')
    paint(img, ((u > per * 0.10) & (u < per * 0.13)).astype(np.float32), 'p_ciano')
    img = weave(img, 6, 0.12)
    save(img, 'listrado.png')

# ---------------------------------------------------------------- poá (Pavio)
def poa():
    img = np.ones((S, S, 3), np.float32) * C('tabua_esc')
    per = S / 7
    for row in range(8):
        for col in range(8):
            cx = col * per + (row % 2) * per / 2; cy = row * per
            dx = (X - cx + S / 2) % S - S / 2; dy = (Y - cy + S / 2) % S - S / 2
            paint(img, cov(np.hypot(dx, dy) - per * 0.2), 'creme')
    img = weave(img, 6, 0.09, twill=False)
    save(img, 'poa.png')

# ---------------------------------------------------------------- retalho lavado (asas da traça)
def traca():
    rng = np.random.default_rng(3)
    img = np.ones((S, S, 3), np.float32) * C('lona')
    k = 0
    for i in range(3):
        for j in range(3):
            flower(img, (i + 0.5) * S / 3 + (j % 2) * S / 6, (j + 0.5) * S / 3, S * 0.09, rng, ['cortica', 'mofo', 'creme'][k % 3], 'mofo'); k += 1
    img = img * 0.55 + C('lona') * 0.45  # desbotado
    # costuras de remendo
    for yy in (S * 0.33, S * 0.71):
        seamline = cov(np.abs(Y - yy - 10 * np.sin(X / 70)) - 1.5)
        paint(img, seamline * 0.6, 'tabua_esc')
        st = cov(np.abs(Y - yy - 10 * np.sin(X / 70)) - 5) * ((X % 18) < 9)
        paint(img, st * 0.8, 'tabua_esc')
    # furos roídos (escuros)
    for i in range(14):
        cx, cy = rng.random(2) * S
        rr = S * (0.012 + rng.random() * 0.025)
        dd = np.hypot(X - cx, Y - cy) - rr * (1 + 0.3 * np.sin(np.arctan2(Y - cy, X - cx) * 5 + i))
        paint(img, cov(dd - 3), 'cortica')
        paint(img, cov(dd), 'tinta')
    img = weave(img, 5, 0.07, twill=False)
    img *= (0.93 + 0.1 * fbm(S, S, 128, rng))[..., None]
    img = img * 0.55 + C('tabua_esc') * 0.12  # retalho encardido
    save(img, 'traca.png')

# ---------------------------------------------------------------- lona pintada e mofada (bastidor)
def bastidor():
    rng = np.random.default_rng(5)
    u = X / S; v = 1 - Y / S
    img = np.ones((S, S, 3), np.float32)
    sky = np.clip((v - 0.35) / 0.65, 0, 1)[..., None]
    img[:] = C('lona') * (1 - sky * 0.5) + C('anil') * sky * 0.5
    img = img * 0.6 + C('lona') * 0.4
    hill = v < (0.38 + 0.08 * np.sin(u * 7 + 1) + 0.04 * np.sin(u * 19))
    paint(img, hill.astype(np.float32) * 0.6, 'musgo')
    # árvore pintada desbotada
    tr = np.hypot((u - 0.3) * 1.6, v - 0.55) < 0.17
    paint(img, tr.astype(np.float32) * 0.45, 'musgo_esc')
    # pinceladas largas visíveis
    br = fbm(S, S, 24, rng, 2)
    img *= (0.9 + 0.15 * br)[..., None]
    # boca zangada pintada
    mouth = cov(np.abs((v - 0.52) - 0.05 * np.abs(np.sin((u - 0.5) * 10)) + 0.06 * ((u - 0.5) * 3) ** 2) * S - 7) * (np.abs(u - 0.5) < 0.2)
    paint(img, mouth, 'tabua_esc')
    # mofo: manchas felpudas com halo
    for i in range(10):
        cx, cy = rng.random() * S, (0.15 + rng.random() * 0.8) * S
        rr = S * (0.03 + rng.random() * 0.08)
        n = fbm(S, S, 16, rng, 2)
        d = np.hypot(X - cx, Y - cy) / rr + (n - 0.5) * 0.9
        paint(img, np.clip(1.2 - d, 0, 1) * 0.5, 'mofo')
        paint(img, (np.clip(0.75 - d, 0, 1) > 0).astype(np.float32) * 0.7 * (n > 0.45), 'musgo_esc')
    # escorridos de umidade
    for i in range(18):
        cx = rng.random() * S; ln = rng.random() * S * 0.4; y0 = rng.random() * S * 0.4
        m = cov(np.abs(X - cx - 3 * np.sin(Y / 30)) - 2.5) * ((Y > y0) & (Y < y0 + ln))
        paint(img, m * 0.25, 'tabua_esc')
    img = weave(img, 7, 0.08, twill=False)
    img = img * 0.5 + C('musgo_esc') * 0.18  # lona velha encharcada de mofo: valor baixo, lê contra o palco claro
    save(img, 'bastidor.png')

for fn in (xadrez, chita_escura, listrado, poa, traca, bastidor):
    fn()
print('ok')

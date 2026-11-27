# Gera texturas por script: chita (tile) e mapas de xilogravura (tinta, cor chapada, recorte).
# Uso: python3 tex.py OUTDIR
import sys, os, math
import numpy as np
from PIL import Image

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

def hexc(h):
    h = h.lstrip('#'); return np.array([int(h[i:i+2], 16) / 255 for i in (0, 2, 4)])

PAL = dict(
    paper='#EDE3CB', ink='#1E1A1C', ochre='#D9A441', terra='#C4562F', sage='#7E8C5A',
    p1='#C3253A', p2='#2459B8', p3='#2E8B57', p4='#8E3B9E',
    fyel='#F2C230', fwht='#F4EFE4', fblu='#3D7BD9', fred='#E0483A', leaf='#3E9A4C',
    ebase='#4A4560', eacc='#B08A4A',
)

def vnoise(h, w, cell, rng, tile=False):
    gh, gw = max(2, h // cell), max(2, w // cell)
    g = rng.random((gh, gw)).astype(np.float32)
    if tile:
        g = np.pad(g, ((0, 1), (0, 1)), mode='wrap')
        im = Image.fromarray(g).resize((w + w // gw, h + h // gh), Image.BICUBIC)
        return np.asarray(im)[:h, :w]
    return np.asarray(Image.fromarray(g).resize((w, h), Image.BICUBIC))

def fbm(h, w, cell, rng, oct=3, tile=False):
    a, s, tot = 1.0, 0, 0
    for i in range(oct):
        s = s + a * vnoise(h, w, max(2, cell >> i), rng, tile); tot += a; a *= 0.5
    return s / tot

def cov(sdf, aa=1.0):
    return np.clip(0.5 - sdf / aa, 0, 1)

# ---------------------------------------------------------------- chita
def chita(name, base, petal_cols, center_col, seed, S=1024, n=4, rmin=0.085, rmax=0.12, dots=True):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:S, 0:S].astype(np.float32) + 0.5
    img = np.ones((S, S, 3), np.float32) * hexc(base)
    def paint(mask, col):
        img[:] = img * (1 - mask[..., None]) + hexc(col) * mask[..., None]
    if dots:  # pontinhos brancos de fundo, como na chita barata
        for i in range(140):
            cx, cy = rng.random(2) * S
            dx = (x - cx + S / 2) % S - S / 2; dy = (y - cy + S / 2) % S - S / 2
            paint(cov(np.hypot(dx, dy) - S * 0.006), '#F4EFE4')
    cells = [(i, j) for i in range(n) for j in range(n)]
    rng.shuffle(cells)
    for k, (i, j) in enumerate(cells):
        cx = (i + 0.5 + (rng.random() - 0.5) * 0.5 + (j % 2) * 0.5) * S / n
        cy = (j + 0.5 + (rng.random() - 0.5) * 0.5) * S / n
        R = S * (rmin + rng.random() * (rmax - rmin))
        dx = (x - cx + S / 2) % S - S / 2; dy = (y - cy + S / 2) % S - S / 2
        r = np.hypot(dx, dy); th = np.arctan2(dy, dx) + rng.random() * 6.28
        # folhas: duas elipses com nervura
        for a in (rng.random() * 6.28, rng.random() * 6.28):
            ux, uy = math.cos(a), math.sin(a)
            px = dx * ux + dy * uy - R * 1.05; py = -dx * uy + dy * ux
            e = np.hypot(px / (R * 0.75), py / (R * 0.32)) - 1
            paint(cov(e * R * 0.3 - 1.5), PAL['ink'])
            paint(cov(e * R * 0.3 + 1.0), PAL['leaf'])
            paint(cov(np.abs(py) - 1.2) * (np.abs(px) < R * 0.6), PAL['ink'])
        npet = int(rng.integers(5, 8))
        rp = R * (0.62 + 0.38 * np.abs(np.cos(npet * th / 2)) ** 0.6)
        pc = petal_cols[k % len(petal_cols)]
        paint(cov(r - rp - 2.0), PAL['ink'])          # contorno escuro
        paint(cov(r - rp + 1.5), pc)
        paint(cov(r - rp * 0.55), PAL['ink'] if pc != PAL['ink'] else PAL['fwht'])
        paint(cov(r - rp * 0.5 + 1.2), pc)
        paint(cov(r - R * 0.26), center_col)
        # anel de pontinhos no miolo
        for q in range(npet):
            aa = q * 6.283 / npet
            paint(cov(np.hypot(dx - math.cos(aa) * R * 0.38, dy - math.sin(aa) * R * 0.38) - R * 0.05), PAL['fwht'])
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((S // 2, S // 2), Image.LANCZOS)
    im.save(os.path.join(OUT, name))

chita('chita_p1.png', PAL['p1'], [PAL['fyel'], PAL['fwht'], PAL['fblu']], PAL['fred'], 1)
chita('chita_p2.png', PAL['p2'], [PAL['fyel'], PAL['fwht'], PAL['fred']], PAL['fyel'], 2)
chita('chita_p3.png', PAL['p3'], [PAL['fyel'], PAL['fred'], PAL['fwht']], PAL['fblu'], 3)
chita('chita_p4.png', PAL['p4'], [PAL['fyel'], PAL['fwht'], PAL['leaf']], PAL['fred'], 4)
chita('chita_en.png', PAL['ebase'], [PAL['eacc']], PAL['ink'], 5, n=5, rmin=0.05, rmax=0.07, dots=False)

# ---------------------------------------------------------------- xilogravura
def gouge_rows(x, y, spacing, wmax, L, rng_seed, wave=0.0, wavef=0.004):
    """Golpes de goiva em V: linhas em fileiras, cada golpe afina nas pontas."""
    yy = y + wave * np.sin(x * wavef)
    row = np.floor(yy / spacing)
    dy = yy - (row + 0.5) * spacing
    h = (np.sin(row * 12.9898 + rng_seed * 78.233) * 43758.5453) % 1.0
    s = (x + h * L * 3.0) / (L * (0.7 + 0.6 * h))
    t = s % 1.0
    width = wmax * np.maximum(np.sin(np.pi * np.clip((t - 0.06) / 0.88, 0, 1)), 0) ** 0.7
    return np.clip(0.5 - (np.abs(dy) - width * 0.5), 0, 1)

def sd_circle(x, y, cx, cy, r): return np.hypot(x - cx, y - cy) - r
def sd_box(x, y, cx, cy, hw, hh, rr=0):
    qx = np.abs(x - cx) - hw + rr; qy = np.abs(y - cy) - hh + rr
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - rr
def sd_capsule(x, y, ax, ay, bx, by, r):
    px, py, bax, bay = x - ax, y - ay, bx - ax, by - ay
    h = np.clip((px * bax + py * bay) / (bax * bax + bay * bay), 0, 1)
    return np.hypot(px - bax * h, py - bay * h) - r
def smin(a, b, k=8.0):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1); return b * (1 - h) + a * h - k * h * (1 - h)

def finish(ink, spot1, spot2, alpha, name, rng):
    H, W = ink.shape
    # tinta falha onde o papel é áspero: manchas e veio da madeira só nas áreas pretas
    grain = fbm(H, W, 6, rng, 2)
    streak = np.asarray(Image.fromarray(rng.random((H // 3, 24)).astype(np.float32)).resize((W, H), Image.BICUBIC))
    falha = ((grain > 0.80) | (streak > 0.93)).astype(np.float32) * 0.85
    ink = ink * (1 - falha)
    rgba = np.stack([ink, spot1, spot2, alpha], -1)
    Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), 'RGBA').save(os.path.join(OUT, name))

# Telão de fundo 18 x 7 m -> 2304 x 896 (128 px/m)
rng = np.random.default_rng(10)
W, H = 2304, 896
y, x = np.mgrid[0:H, 0:W].astype(np.float32) + 0.5
edge = (fbm(H, W, 18, rng, 3) - 0.5) * 7.0   # borda irregular de talho
ink = np.zeros((H, W), np.float32); s1 = np.zeros_like(ink); s2 = np.zeros_like(ink)
# sol: disco preto com anéis entalhados e raios em cunha; cor ocre por baixo (registro)
cx, cy = 1650, 250
dsun = sd_circle(x, y, cx, cy, 150) + edge
ang = np.arctan2(y - cy, x - cx); rr = np.hypot(x - cx, y - cy)
rays = (np.abs(((ang / (2 * np.pi) * 24) % 1.0) - 0.5) < 0.16 * np.clip((330 - rr) / 150, 0, 1)) & (rr > 175) & (rr < 330)
ink = np.maximum(ink, cov(dsun)); ink = np.maximum(ink, rays.astype(np.float32))
for k in range(3):
    ring = np.abs(rr - (40 + k * 38)) < (5 - k)
    ink = np.where(ring & (dsun < -6), 0.0, ink)
s1 = np.maximum(s1, cov(sd_circle(x, y, cx + 3, cy + 2, 175) + edge))
# nuvens: linhas entalhadas em faixas horizontais curtas, com contorno
for (ux, uy, uw) in [(420, 170, 260), (900, 120, 200), (1150, 260, 170)]:
    dc = smin(sd_circle(x, y, ux, uy, uw * 0.35), smin(sd_circle(x, y, ux - uw * 0.4, uy + 20, uw * 0.25), sd_circle(x, y, ux + uw * 0.45, uy + 25, uw * 0.22))) + edge
    band = cov(np.abs(dc) - 4)
    ink = np.maximum(ink, band)
    ink = np.maximum(ink, gouge_rows(x, y, 20, 4.0, 60, 3) * cov(dc + 18))
# serras ao longe: massa preta com goivas horizontais brancas onduladas
hill = H * 0.56 - 90 * np.sin(x * 0.0021 + 0.7) - 50 * np.sin(x * 0.0057 + 2) - 25 * np.sin(x * 0.013)
dh = (hill - y) + edge
hm = cov(dh)
cut = gouge_rows(x, y, 15, 7.0, 90, 7, wave=10, wavef=0.006) * cov(dh + 10) * (y < hill + 160)
ink = np.maximum(ink, hm * (1 - cut))
s2 = np.maximum(s2, cov(dh + 0) * (y < H * 0.95))
# igrejinha
dchurch = np.minimum(sd_box(x, y, 560, 520, 70, 60), sd_box(x, y, 520, 430, 26, 70))
dchurch = np.minimum(dchurch, sd_box(x, y, 520, 345, 4, 22)); dchurch = np.minimum(dchurch, sd_box(x, y, 520, 352, 14, 4))
ink = np.where(dchurch + edge * 0.4 < 0, 0.0, ink)  # igreja é papel (entalhada) dentro da serra
ink = np.maximum(ink, cov(np.abs(dchurch + edge * 0.4) - 3))
ink = np.maximum(ink, cov(sd_box(x, y, 560, 545, 14, 35)))  # porta
# chão do telão
dg = (y - H * 0.93) + edge
ink = np.maximum(ink, cov(-dg) * (1 - gouge_rows(x, y, 11, 5, 40, 9)))
finish(ink, s1, s2, np.ones_like(ink), 'xilo_fundo.png', rng)

# Camada recortada do meio: mandacarus, xique-xique e casa. 18 x 3.2 m -> 2304 x 410
rng = np.random.default_rng(11)
W, H = 2304, 410
y, x = np.mgrid[0:H, 0:W].astype(np.float32) + 0.5
edge = (fbm(H, W, 14, rng, 3) - 0.5) * 6.0
d = np.full((H, W), 1e4, np.float32)
for cxp, hgt, sc in [(200, 330, 1.0), (760, 260, 0.8), (1900, 360, 1.1), (2180, 220, 0.7)]:
    base = H - 6
    trunk = sd_capsule(x, y, cxp, base, cxp, base - hgt, 26 * sc)
    l1 = smin(sd_capsule(x, y, cxp, base - hgt * 0.45, cxp - 75 * sc, base - hgt * 0.45, 18 * sc), sd_capsule(x, y, cxp - 75 * sc, base - hgt * 0.45, cxp - 75 * sc, base - hgt * 0.8, 18 * sc), 10)
    r1 = smin(sd_capsule(x, y, cxp, base - hgt * 0.3, cxp + 70 * sc, base - hgt * 0.3, 18 * sc), sd_capsule(x, y, cxp + 70 * sc, base - hgt * 0.3, cxp + 70 * sc, base - hgt * 0.62, 18 * sc), 10)
    d = np.minimum(d, smin(trunk, smin(l1, r1, 10), 10))
# xique-xique: tufos baixos
for cxp in (420, 1050, 1350, 1650):
    for k in range(5):
        d = np.minimum(d, sd_capsule(x, y, cxp + k * 22, H - 6, cxp + k * 22 + (k - 2) * 12, H - 70 - 25 * ((k * 7) % 3), 9))
# casinha de taipa
roof = np.maximum(np.maximum((H - 262 + np.abs(x - 1180) * 0.5) - y, y - (H - 168)), np.abs(x - 1180) - 165)
house = np.minimum(sd_box(x, y, 1180, H - 90, 130, 84), roof)
d = np.minimum(d, house)
d = d + edge
ink = cov(d)
# entalhes: frisos verticais nos cactos, tijolos na casa, janela e porta em papel
vert = gouge_rows(y, x, 13, 4.0, 50, 4).astype(np.float32)  # linhas verticais (troca x/y)
inner = cov(d + 9)
ink = ink * (1 - vert * inner * (np.abs(x - 1180) > 160))
brick = gouge_rows(x, y, 22, 3.5, 34, 5) * cov(house + edge + 8)
ink = ink * (1 - brick)
win = np.minimum(sd_box(x, y, 1120, H - 100, 30, 28), sd_box(x, y, 1250, H - 60, 28, 54))
ink = np.where(win < 0, 0.0, ink)
s2 = cov(d - 4) * (np.abs(x - 1180) > 160)  # verde-sálvia sob os cactos
s1 = cov(house + edge - 4)                   # terracota sob a casa
alpha = cov(d - 16 + edge * 0.5)             # recorte de papel com margem branca
finish(ink, s1, s2, alpha, 'xilo_meio.png', rng)

# Chão 18 x 10 m -> 2304 x 1280: terra rachada (Voronoi) em ocre com rachaduras pretas
rng = np.random.default_rng(12)
W, H = 2304, 1280
y, x = np.mgrid[0:H, 0:W].astype(np.float32) + 0.5
edge = (fbm(H, W, 10, rng, 3) - 0.5) * 5.0
pts = np.stack([rng.random(200) * W, rng.random(200) * H], 1).astype(np.float32)
d1 = np.full((H, W), 1e9, np.float32); d2 = np.full((H, W), 1e9, np.float32)
for px, py in pts:
    dd = np.hypot(x - px, y - py)
    m = dd < d1
    d2 = np.where(m, d1, np.minimum(d2, dd)); d1 = np.where(m, dd, d1)
crack = (d2 - d1) + edge
wcrack = 2.5 + 3.5 * fbm(H, W, 40, rng, 2)
ink = cov(crack - wcrack)
# goivas curtas dentro das placas de terra (textura de chão), esparsas
g = gouge_rows(x, y, 24, 3.0, 26, 8) * (fbm(H, W, 64, rng, 2) > 0.62)
ink = np.maximum(ink, g * 0.9)
s1 = np.ones_like(ink)  # ocre chapado no chão inteiro
s2 = (fbm(H, W, 80, rng, 2) > 0.58).astype(np.float32)  # manchas de terracota
finish(ink, s1, s2, np.ones_like(ink), 'xilo_chao.png', rng)
print('ok')

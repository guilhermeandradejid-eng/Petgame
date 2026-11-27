# Cenário da Tolda Viva por código: telão a têmpera sobre lona (gerador de pinceladas com cerdas,
# carga de tinta e pincel seco que falha onde a trama é alta), bastidores recortados, praticável de
# tábuas, lona listrada da tolda, lua de papel e juta do contrapeso. Uso: python3 cenario.py SAIDA
import sys, os, math, time
import numpy as np
from PIL import Image, ImageFilter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paleta as PAL

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

def C(n):
    return np.array(PAL.f(n), np.float32)

def mixc(a, b, t):
    return C(a) * (1 - t) + C(b) * t

def vnoise(h, w, cell, rng):
    gh, gw = max(2, h // cell + 2), max(2, w // cell + 2)
    g = rng.random((gh, gw)).astype(np.float32)
    im = Image.fromarray(g).resize((gw * cell, gh * cell), Image.BICUBIC)
    return np.asarray(im)[:h, :w]

def fbm(h, w, cell, rng, oc=4):
    a, s, t = 1.0, 0, 0
    for i in range(oc):
        s = s + a * vnoise(h, w, max(2, cell >> i), rng); t += a; a *= 0.5
    return s / t

def weave(h, w, per=5.0, rng=None):
    """dente da lona: trama em tafetá com fios irregulares (0..1, alto = fio)."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    jx = vnoise(h, w, 40, rng) * 1.6; jy = vnoise(h, w, 40, rng) * 1.6
    fx = 0.5 + 0.5 * np.sin((x + jx) * math.pi / per * 2)
    fy = 0.5 + 0.5 * np.sin((y + jy) * math.pi / per * 2)
    over = ((np.floor((x + jx) / per) + np.floor((y + jy) / per)) % 2).astype(np.float32)
    t = over * fx + (1 - over) * fy
    slub = vnoise(h, w, 12, rng)
    return np.clip(t * 0.4 + slub * 0.6, 0, 1)

class Canvas:
    def __init__(self, h, w, seed, per=5.0):
        self.h, self.w = h, w
        self.rng = np.random.default_rng(seed)
        self.img = np.zeros((h, w, 3), np.float32)
        self.alpha = np.zeros((h, w), np.float32)
        self.tooth = weave(h, w, per, self.rng)

    def stroke(self, pts, width, col, load=1.0, dry=0.55, alpha=1.0, taper=0.25, jitter=0.0, mask=None):
        """Pincelada de broxa: perfil de cerdas ao longo da normal, carga que cai ao longo do traço,
        pincel seco onde o dente da lona é alto, ponta afinando. col: rgb (np.array)."""
        pts = np.asarray(pts, np.float32)
        seg = np.diff(pts, axis=0)
        L = np.sqrt((seg ** 2).sum(1))
        tot = L.sum()
        if tot < 1:
            return
        step = max(1.0, width * 0.2)
        n = int(tot / step) + 2
        cum = np.concatenate([[0], np.cumsum(L)])
        ss = np.linspace(0, tot, n)
        cx = np.interp(ss, cum, pts[:, 0]); cy = np.interp(ss, cum, pts[:, 1])
        tx = np.gradient(cx); ty = np.gradient(cy)
        tn = np.sqrt(tx * tx + ty * ty) + 1e-6
        tx /= tn; ty /= tn
        R = width / 2 + 2
        x0 = int(max(0, cx.min() - R)); x1 = int(min(self.w, cx.max() + R + 1))
        y0 = int(max(0, cy.min() - R)); y1 = int(min(self.h, cy.max() + R + 1))
        if x1 <= x0 or y1 <= y0:
            return
        cov = np.zeros((y1 - y0, x1 - x0), np.float32)
        prof = self.rng.random(48).astype(np.float32)
        prof = 0.55 + 0.45 * np.convolve(prof, np.ones(2) / 2, mode='same')
        gaps = self.rng.random(48) < 0.12
        prof[gaps] *= 0.25
        tooth = self.tooth[y0:y1, x0:x1]
        for i in range(n):
            u = ss[i] / tot
            wv = width * (1 - taper * (1 - min(1, u * 6)) ** 2) * (1 - taper * max(0, (u - 0.8) / 0.2))
            r = wv / 2
            ax0 = int(max(x0, cx[i] - r - 1)); ax1 = int(min(x1, cx[i] + r + 2))
            ay0 = int(max(y0, cy[i] - r - 1)); ay1 = int(min(y1, cy[i] + r + 2))
            if ax1 <= ax0 or ay1 <= ay0:
                continue
            yy, xx = np.mgrid[ay0:ay1, ax0:ax1].astype(np.float32)
            dx = xx - cx[i]; dy = yy - cy[i]
            s = (dx * -ty[i] + dy * tx[i]) / max(r, 0.5)
            a = (dx * tx[i] + dy * ty[i])
            inside = (np.abs(s) < 1) & (np.abs(a) <= step * 0.8 + 0.5)
            pi = np.clip(((s + 1) * 0.5 * 47).astype(int), 0, 47)
            bv = prof[pi] * np.clip((1 - np.abs(s)) * 6, 0, 1)
            ld = load * (1 - dry * u)  # carga de tinta caindo
            t = tooth[ay0 - y0:ay1 - y0, ax0 - x0:ax1 - x0]
            dryk = np.clip((ld - t * 0.85 + 0.35) * 3, 0, 1)
            c = bv * dryk * inside
            sub = cov[ay0 - y0:ay1 - y0, ax0 - x0:ax1 - x0]
            np.maximum(sub, c, out=sub)
        if mask is not None:
            cov *= mask[y0:y1, x0:x1]
        cov = np.clip(cov * alpha, 0, 1)[..., None]
        reg = self.img[y0:y1, x0:x1]
        # tinta mais grossa escurece levemente nas bordas (acúmulo de pigmento)
        reg[:] = reg * (1 - cov) + col * cov
        al = self.alpha[y0:y1, x0:x1]
        np.maximum(al, cov[..., 0], out=al)

    def fill_region(self, mask, cols, width, angle_fn, length=(80, 220), density=1.0, dry=0.5, alpha=1.0, curve=0.3, load=1.0):
        """cobre uma região com pinceladas cuja direção segue a forma (angle_fn(x, y))."""
        ys, xs = np.nonzero(mask > 0.5)
        if len(xs) == 0:
            return
        area = len(xs)
        nst = int(area / (width * np.mean(length)) * 2.2 * density) + 1
        idx = self.rng.integers(0, len(xs), nst)
        for k in idx:
            x, y = float(xs[k]), float(ys[k])
            ang = angle_fn(x, y) + self.rng.normal(0, 0.12)
            ln = self.rng.uniform(*length)
            bend = self.rng.normal(0, curve)
            pts = []
            for j in range(6):
                t = (j / 5 - 0.5) * ln
                a2 = ang + bend * (j / 5 - 0.5)
                pts.append((x + math.cos(a2) * t, y + math.sin(a2) * t))
            col = cols[self.rng.integers(0, len(cols))]
            col = col * (0.96 + 0.08 * self.rng.random())
            self.stroke(pts, width * self.rng.uniform(0.8, 1.15), col, dry=dry, alpha=alpha, mask=mask, load=load)

    def finish(self, base=None):
        img = self.img
        if base is not None:
            img = np.where(self.alpha[..., None] > 0, img, base)
        # a trama aparece por baixo da tinta e a lona crua onde a tinta falhou
        sh = (self.tooth - 0.5) * 0.07
        return np.clip(img * (1 + sh[..., None]), 0, 1)

def save(img, name, alpha=None, size=None):
    a = (np.clip(img, 0, 1) * 255).astype(np.uint8)
    if alpha is not None:
        a = np.dstack([a, (np.clip(alpha, 0, 1) * 255).astype(np.uint8)])
    im = Image.fromarray(a)
    if size:
        im = im.resize(size, Image.LANCZOS)
    im.save(os.path.join(OUT, name))

# ================================================================== telão do Pomar das Luas
def telao():
    t0 = time.time()
    H, W = 640, 2560
    cv = Canvas(H, W, 21, per=4.0)
    rng = cv.rng
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    lona = C('lona')
    horizon = 390
    # subpintura: degradê do céu em faixas (não liso: 6 degraus), depois pinceladas por cima
    t = np.clip(y / horizon, 0, 1)
    tq = np.floor(t * 6) / 6
    base = C('anil_esc') * (1 - tq[..., None]) + mixc('anil', 'lona', 0.22) * tq[..., None]
    base = np.where((y > horizon)[..., None], C('musgo_esc'), base)
    cv.img[:] = base
    sky = (y < horizon + 40).astype(np.float32)
    for band, cols in ((0.0, [C('anil_esc'), C('anil_esc') * 0.88, mixc('anil_esc', 'anil', 0.35)]),
                       (0.35, [C('anil'), mixc('anil_esc', 'anil', 0.6), mixc('anil', 'lona', 0.1)]),
                       (0.7, [mixc('anil', 'lona', 0.2), mixc('anil', 'lona', 0.32), mixc('anil', 'musgo', 0.25)])):
        m = sky * (y > band * horizon - 40) * (y < (band + 0.42) * horizon)
        cv.fill_region(m, cols, 44, lambda xx, yy: 0.05 * math.sin(xx / 300.0 + yy / 90.0), length=(160, 420), density=1.6, dry=0.45, curve=0.2, alpha=0.9)
    # nuvens de pinceladas compridas, claras na borda de baixo (luz das luas)
    for k in range(9):
        cx_, cy_ = rng.random() * W, rng.uniform(40, 260)
        for j in range(5):
            yy0 = cy_ + j * 13
            ln = rng.uniform(220, 520) * (1 - j * 0.12)
            xx0 = cx_ + rng.normal(0, 40)
            col = mixc('anil', 'lona', 0.25 + 0.1 * j) if j > 2 else mixc('anil_esc', 'anil', 0.7)
            cv.stroke([(xx0 - ln / 2, yy0), (xx0, yy0 - 6), (xx0 + ln / 2, yy0 + 3)], rng.uniform(16, 26), col, dry=0.5, alpha=0.85)
    moons = [(420, 105, 58), (1350, 72, 44), (2150, 130, 66)]
    for mx, my, mr in moons:
        d = np.hypot(x - mx, y - my)
        # brilho pintado: pinceladas horizontais curtas e ralas em volta
        halo = ((d < mr * 2.0) & (d > mr * 0.9)).astype(np.float32)
        cv.fill_region(halo, [mixc('anil', 'lua', 0.28), mixc('anil', 'lua', 0.2)], 18, lambda xx, yy: 0.0, length=(40, 110), density=0.45, dry=0.75, alpha=0.7)
        disc = (d < mr).astype(np.float32)
        cv.fill_region(disc, [C('lua'), mixc('lua', 'creme', 0.5)], 22, lambda xx, yy, mx=mx, my=my: math.atan2(yy - my, xx - mx) + math.pi / 2, length=(40, 110), density=2.4, dry=0.25)
        for k in range(5):
            a = rng.random() * 6.28; rr = rng.random() * mr * 0.6
            cx, cy = mx + math.cos(a) * rr, my + math.sin(a) * rr
            cv.stroke([(cx - 8, cy), (cx + 8, cy + 2)], mr * 0.22, mixc('lua', 'madeira_esc', 0.35), dry=0.5, alpha=0.6)
    # estrelas: toques de pincel
    for k in range(160):
        sx, sy = rng.random() * W, rng.random() * horizon * 0.85
        if any(math.hypot(sx - mx, sy - my) < mr * 2.2 for mx, my, mr in moons):
            continue
        s = rng.uniform(3, 7)
        cv.stroke([(sx - s, sy), (sx + s, sy + rng.normal(0, 1))], s * 0.9, mixc('lua', 'creme', rng.random()), dry=0.2, alpha=0.9, taper=0.6)
    # colinas distantes em camadas (perspectiva aérea: mais longe, mais clara e azulada)
    def ridge(base_y, amp, f1, ph):
        return base_y + amp * np.sin(x[0] / f1 + ph) + amp * 0.45 * np.sin(x[0] / (f1 * 0.37) + ph * 2.1)
    layers = [(360, 28, 260, 0.4, [mixc('anil', 'musgo', 0.35), mixc('anil', 'musgo', 0.25)]),
              (425, 38, 330, 2.1, [mixc('anil_esc', 'musgo_esc', 0.55), mixc('anil', 'musgo_esc', 0.6)]),
              (500, 32, 410, 4.0, [C('musgo_esc'), mixc('musgo_esc', 'anil_esc', 0.3)])]
    for by, amp, f1, ph, cols in layers:
        top = ridge(by, amp, f1, ph)
        m = (y > top[None, :]).astype(np.float32)
        cv.img[:] = np.where(m[..., None] > 0, cols[0], cv.img)
        cv.fill_region(m * (y < by + 300), cols, 34, lambda xx, yy: 0.08 * math.sin(xx / 200.0), length=(120, 300), density=1.2, dry=0.5)
        # pomar: copas redondas na crista, cada uma com 2 tintas e pinceladas em volta da forma
        nt = int(W / 110)
        for k in range(nt):
            tx = (k + rng.random() * 0.6) * W / nt
            ty = float(np.interp(tx, x[0], top)) + 6
            tr = rng.uniform(24, 46) * (0.85 if by > 400 else 0.65)
            d = np.hypot(x - tx, (y - ty + tr * 0.8) * 1.15)
            cm = (d < tr).astype(np.float32)
            cv.img[:] = np.where(cm[..., None] > 0, cols[0] * 0.8, cv.img)
            sh_ = cm * ((x - tx) + (y - ty + tr * 0.8) > tr * 0.2)
            cv.fill_region(cm * (1 - sh_), [cols[0] * 1.12, cols[1] * 1.08], tr * 0.5, lambda xx, yy, tx=tx, ty=ty: math.atan2(yy - ty, xx - tx) + math.pi / 2, length=(tr * 0.8, tr * 1.6), density=2.2, dry=0.35)
            # luz da lua na borda de cima da copa
            hl = cm * (y < ty - tr * 0.8 - tr * 0.2)
            cv.fill_region(hl, [cols[0] * 1.25], tr * 0.35, lambda xx, yy: 0.0, length=(tr * 0.5, tr), density=1.0, dry=0.5, alpha=0.7)
            # frutas-lua pequenas
            for q in range(int(rng.integers(1, 4))):
                fx, fy = tx + rng.normal(0, tr * 0.4), ty - tr * 0.8 + rng.normal(0, tr * 0.3)
                fs = rng.uniform(4, 7)
                cv.stroke([(fx - fs * 0.4, fy), (fx + fs * 0.4, fy)], fs * 1.6, mixc('lua', 'creme', 0.3), dry=0.2, taper=0.5)
    # emenda das faixas de lona (costura vertical) e um remendo
    img = cv.finish()
    for sxp in (640, 1280, 1920):
        seam = np.exp(-((x - sxp - 2 * np.sin(y / 40)) ** 2) / 3.0)
        img *= (1 - 0.12 * seam)[..., None]
        st = (np.abs(x - sxp - 6 - 2 * np.sin(y / 40)) < 1.4) & ((y % 14) < 7)
        img[st] = img[st] * 0.78
    # vinheta pintada: escurece as pontas e o alto (o urdimento)
    vg = 1 - 0.35 * (np.abs(x - W / 2) / (W / 2)) ** 3 - 0.25 * (1 - y / H) ** 4
    img *= vg[..., None]
    save(img, 'telao.png')
    print('telao', round(time.time() - t0, 1), 's')

# ================================================================== bastidores recortados (árvores)
def bastidor_arvore(name, seed, W=640, H=820):
    cv = Canvas(H, W, seed, per=4.0)
    rng = cv.rng
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    trunk_w = rng.uniform(50, 70)
    cx = W / 2 + rng.normal(0, 20)
    # tronco torto
    tx = cx + 25 * np.sin(y / 120.0 + seed)
    trunk = ((np.abs(x - tx) < trunk_w / 2 * (1 + 0.6 * (y / H) ** 3)) & (y > H * 0.35)).astype(np.float32)
    cv.fill_region(trunk, [mixc('tabua_esc', 'anil_esc', 0.35), mixc('tabua_esc', 'musgo_esc', 0.4)], 22, lambda xx, yy: math.pi / 2, length=(80, 200), density=1.8, dry=0.4)
    # copa: aglomerado de bolas
    blobs = [(cx + rng.normal(0, W * 0.13), H * 0.33 + rng.normal(0, H * 0.05), rng.uniform(W * 0.16, W * 0.26)) for k in range(7)]
    cm = np.zeros((H, W), np.float32)
    for bx, by, br in blobs:
        cm = np.maximum(cm, (np.hypot(x - bx, y - by) < br).astype(np.float32))
    cv.fill_region(cm, [C('musgo_esc'), mixc('musgo_esc', 'anil_esc', 0.35), mixc('musgo_esc', 'musgo', 0.3)], 40,
                   lambda xx, yy: math.atan2(yy - H * 0.28, xx - cx) + math.pi / 2, length=(60, 160), density=2.4, dry=0.35)
    # luz de lua no alto das bolas
    for bx, by, br in blobs:
        hl = ((np.hypot(x - bx + br * 0.25, y - by + br * 0.35) < br * 0.55) & (cm > 0)).astype(np.float32)
        cv.fill_region(hl, [mixc('musgo', 'lua', 0.12), C('musgo')], 26, lambda xx, yy, bx=bx, by=by: math.atan2(yy - by, xx - bx) + math.pi / 2, length=(40, 90), density=1.2, dry=0.55, alpha=0.9)
    # frutas-lua
    for k in range(int(rng.integers(5, 9))):
        bx, by, br = blobs[k % len(blobs)]
        fx, fy = bx + rng.normal(0, br * 0.5), by + rng.normal(0, br * 0.5)
        if cm[int(np.clip(fy, 0, H - 1)), int(np.clip(fx, 0, W - 1))] < 0.5:
            continue
        cv.stroke([(fx - 6, fy), (fx + 6, fy)], 20, C('lua'), dry=0.15, taper=0.4)
        cv.stroke([(fx - 2, fy - 4), (fx + 3, fy - 5)], 6, C('creme'), dry=0.2, taper=0.5)
    img = cv.finish()
    # recorte serrado: alfa = onde houve tinta, com borda dilatada (a madeira compensada passa da pintura)
    al = (cv.alpha > 0.05).astype(np.uint8) * 255
    al = np.asarray(Image.fromarray(al).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(3))) / 255.0
    # borda de compensado cru aparecendo
    edge = al - np.asarray(Image.fromarray((cv.alpha > 0.05).astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(3))) / 255.0
    img = np.where((edge > 0.5)[..., None], C('madeira') * 0.85, img)
    img = np.where((al > 0.5)[..., None] & (cv.alpha[..., None] < 0.05), mixc('musgo_esc', 'anil_esc', 0.3), img)
    save(img, name, alpha=al)

# ================================================================== praticável (tábuas)
def praticavel():
    t0 = time.time()
    PXM = 128
    Wm, Hm = 20, 14
    W, H = Wm * PXM, Hm * PXM
    rng = np.random.default_rng(8)
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    plank_w = 0.22 * PXM
    pi = np.floor(x / plank_w).astype(int)
    u = (x - pi * plank_w) / plank_w
    # tábuas correm em profundidade (eixo y da textura), com emendas desencontradas
    offs = rng.random(200) * 3.0 * PXM
    plen = rng.uniform(2.2, 3.6, 200) * PXM
    v = y + offs[pi % 200]
    seg = np.floor(v / plen[pi % 200]).astype(int)
    vloc = v - seg * plen[pi % 200]
    pid = (pi * 31 + seg * 7) % 997
    tone = (np.sin(pid * 12.9898) * 43758.5453) % 1.0
    base = C('tabua')[None, None] * (0.86 + 0.2 * tone[..., None])
    base = base * (1 - 0.12 * ((pid % 5) == 0)[..., None]) + C('madeira') * 0.12 * ((pid % 7) == 0)[..., None]
    # veio da madeira: linhas onduladas ao longo da tábua
    n1 = fbm(H, W, 64, rng, 3)
    grain = np.sin((u * 9 + n1 * 5 + pid * 0.37) * math.pi * 2 + vloc / PXM * 0.6)
    gr = (0.5 + 0.5 * grain) ** 6
    img = base * (1 - 0.09 * gr[..., None])
    knots = rng.random((40, 3))
    for kx, ky, kr in knots:
        d = np.hypot(x - kx * W, (y - ky * H) * 0.6)
        img *= (1 - 0.18 * np.exp(-d ** 2 / (2 * (6 + kr * 8) ** 2)))[..., None]
    # frestas entre tábuas e emendas
    gap = (u < 0.035) | (u > 0.975)
    img[gap] = C('tabua_esc') * 0.75
    joint = vloc < 2.2
    img[joint] = C('tabua_esc') * 0.85
    # pregos nas pontas (v2: 1 par a cada 3 tábuas, contraste 60% menor)
    nail_ok = (pi % 3) == 0
    for side in (0.2, 0.8):
        nd = np.hypot((u - side) * plank_w, vloc - 10)
        m = (nd < 2.6) & nail_ok
        img[m] = img[m] * 0.76
        m = (nd < 1.2) & nail_ok
        img[m] = img[m] * 0.8 + C('lona') * 0.2
    # desgaste: tinta velha clara no meio do palco e arranhões
    wear = fbm(H, W, 128, rng, 3)
    center = np.exp(-(((x / W - 0.5) * 2) ** 2 + ((y / H - 0.5) * 2) ** 2) * 1.2)
    img = img * (1 + 0.1 * (wear[..., None] - 0.5)) + C('lona') * 0.06 * center[..., None]
    for k in range(260):
        sx, sy = rng.random() * W, rng.random() * H
        a = rng.normal(0, 0.5) + (0 if rng.random() < 0.5 else math.pi / 2)
        ln = rng.uniform(10, 60)
        t = np.linspace(0, 1, 30)
        xs = (sx + np.cos(a) * ln * t).astype(int); ys = (sy + np.sin(a) * ln * t).astype(int)
        ok = (xs >= 0) & (xs < W) & (ys >= 0) & (ys < H)
        img[ys[ok], xs[ok]] = img[ys[ok], xs[ok]] * 1.12
    # marcações de cena em fita crepe (cruzes) e o alçapão
    def tape(x0, y0, x1, y1, w=0.05):
        d = np.abs((x - x0 * PXM) * (y1 - y0) - (y - y0 * PXM) * (x1 - x0)) / (math.hypot(x1 - x0, y1 - y0) + 1e-6)
        t = ((x - x0 * PXM) * (x1 - x0) + (y - y0 * PXM) * (y1 - y0)) / (math.hypot(x1 - x0, y1 - y0) ** 2 * PXM + 1e-6)
        m = (d < w * PXM / 2) & (t > 0) & (t < 1)
        img[m] = img[m] * 0.25 + C('creme') * 0.75 * (0.92 + 0.08 * n1[m][..., None])
    for cx_, cy_ in ((6.5, 8.6), (13.6, 5.3), (4.1, 4.4), (15.5, 10.0)):
        tape(cx_ - 0.14, cy_, cx_ + 0.14, cy_); tape(cx_, cy_ - 0.14, cx_, cy_ + 0.14)
    # alçapão: tampa com dobradiças
    ax0, ay0, ax1, ay1 = 12.3, 8.9, 13.9, 10.1
    m = (x > ax0 * PXM) & (x < ax1 * PXM) & (y > ay0 * PXM) & (y < ay1 * PXM)
    img[m] *= 0.92
    border = m & ~((x > ax0 * PXM + 5) & (x < ax1 * PXM - 5) & (y > ay0 * PXM + 5) & (y < ay1 * PXM - 5))
    img[border] = C('tabua_esc') * 0.6
    for hx in (ax0 + 0.3, ax1 - 0.3):
        hm = (np.abs(x - hx * PXM) < 14) & (np.abs(y - ay0 * PXM) < 7)
        img[hm] = C('tabua_esc') * 0.5
    save(img, 'praticavel.png')
    print('praticavel', round(time.time() - t0, 1), 's')

# ================================================================== lona listrada da tolda
def lona_listrada():
    H, W = 256, 1024
    rng = np.random.default_rng(2)
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    per = W / 16
    s = ((x // (per / 2)) % 2).astype(np.float32)
    img = np.where(s[..., None] > 0, C('vinho'), C('lona'))
    tooth = weave(H, W, 3.0, rng)
    img = img * (0.93 + 0.12 * tooth[..., None])
    # remendos costurados
    for px_, py_, pw, ph in ((300, 60, 90, 70), (760, 120, 70, 60)):
        m = (x > px_) & (x < px_ + pw) & (y > py_) & (y < py_ + ph)
        img[m] = C('lona') * 0.85 * (0.93 + 0.12 * tooth[m][..., None])
        e = m & ~((x > px_ + 4) & (x < px_ + pw - 4) & (y > py_ + 4) & (y < py_ + ph - 4)) & (((x + y) % 8) < 4)
        img[e] = C('tabua_esc')
    # manchas de uso
    n = fbm(H, W, 64, rng, 3)
    img *= (0.9 + 0.15 * n)[..., None]
    save(img, 'lona_listrada.png')

# ================================================================== lua de papel e juta
def lua_papel():
    S = 512
    cv = Canvas(S, S, 33, per=3.0)
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.hypot(x - S / 2, y - S / 2)
    disc = (d < S * 0.48).astype(np.float32)
    cv.img[:] = C('lua')
    cv.fill_region(disc, [C('lua'), mixc('lua', 'creme', 0.5), mixc('lua', 'creme', 0.25)], 30, lambda xx, yy: math.atan2(yy - S / 2, xx - S / 2) + math.pi / 2, length=(60, 160), density=2.0, dry=0.3)
    rng = cv.rng
    for k in range(7):
        a = rng.random() * 6.28; rr = rng.random() * S * 0.33
        cx, cy = S / 2 + math.cos(a) * rr, S / 2 + math.sin(a) * rr
        cr = rng.uniform(14, 40)
        ring = ((np.hypot(x - cx, y - cy) < cr)).astype(np.float32)
        cv.fill_region(ring, [mixc('lua', 'madeira_esc', 0.3)], cr * 0.5, lambda xx, yy, cx=cx, cy=cy: math.atan2(yy - cy, xx - cx) + math.pi / 2, length=(cr, cr * 2), density=1.0, dry=0.5, alpha=0.6)
    img = cv.finish()
    # varetas de bambu da armação aparecendo por trás do papel
    for a in np.linspace(0, math.pi, 4, endpoint=False):
        dd = np.abs((x - S / 2) * math.sin(a) - (y - S / 2) * math.cos(a))
        img *= (1 - 0.18 * np.exp(-dd ** 2 / 8))[..., None]
    img *= (1 - 0.25 * np.clip((d - S * 0.38) / (S * 0.1), 0, 1))[..., None]
    save(img, 'lua.png', alpha=disc)

def juta():
    S = 512
    rng = np.random.default_rng(4)
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    t = weave(S, S, 6.0, rng)
    img = mixc('lona', 'tabua', 0.55)[None, None] * (0.8 + 0.3 * t[..., None])
    n = fbm(S, S, 64, rng, 3)
    img *= (0.85 + 0.25 * n)[..., None]
    # letreiro de lote pintado (sem texto: só faixas)
    m = (np.abs(y - S * 0.45) < 18) & (np.abs(x - S * 0.5) < 120)
    img[m] = img[m] * 0.4 + C('tabua_esc') * 0.6
    save(img, 'juta.png')

if __name__ == '__main__':
    which = sys.argv[2:] or ['telao', 'arvores', 'praticavel', 'lona', 'lua', 'juta']
    if 'lona' in which: lona_listrada()
    if 'lua' in which: lua_papel()
    if 'juta' in which: juta()
    if 'arvores' in which:
        for i in range(3):
            bastidor_arvore('arvore%d.png' % i, 100 + i)
    if 'praticavel' in which: praticavel()
    if 'telao' in which: telao()

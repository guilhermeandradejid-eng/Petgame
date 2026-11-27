# Os Descascados: azulejos que o salitre arrancou das paredes e remontou errado.
# Cacos com espessura real (frente pintada, borda de biscoito, verso de argamassa), crosta de
# salitre em cristais, rosto "errado" (a pintura original remontada torta).
import math, random
import numpy as np
from mathutils import Vector
import geo as G
import pintura as PT
import pincel as K
import texturas as TX

def broken_poly(w, h, rng, n=7, jag=0.18):
    """Contorno de caco: polígono convexo-ish com quebras em zigue-zague."""
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n + rng.uniform(-0.25, 0.25)
        r = 1.0 - rng.uniform(0, jag)
        pts.append((math.cos(a) * w / 2 * r, math.sin(a) * h / 2 * r))
    return pts

def paint_eye(w, h, seed, rot=0):
    """Olho de figura de painel (amêndoa, pálpebra, pupila), pintado a pincel."""
    rng = np.random.default_rng(seed)
    D = np.zeros((h, w), np.float32); S = np.zeros_like(D)
    cx, cy = w / 2, h / 2
    top = [(cx - w * 0.36, cy), (cx - w * 0.12, cy - h * 0.2), (cx + w * 0.14, cy - h * 0.2), (cx + w * 0.36, cy + h * 0.02)]
    bot = [(cx - w * 0.36, cy), (cx - w * 0.1, cy + h * 0.16), (cx + w * 0.16, cy + h * 0.14), (cx + w * 0.36, cy + h * 0.02)]
    K.stroke(S, top, 6, 3, load=1.0, pool=0.3, seed=1)
    K.stroke(S, bot, 3.5, 2, load=0.9, pool=0.2, seed=2)
    D = np.maximum(D, K.ellipse_mask(h, w, cx + 2, cy - 2, w * 0.11, h * 0.15) * 0.95)
    D = np.maximum(D, K.ellipse_mask(h, w, cx - 4, cy - 8, w * 0.035, h * 0.04) * 0.0)
    K.stroke(S, [(cx - w * 0.3, cy - h * 0.34), (cx, cy - h * 0.42), (cx + w * 0.3, cy - h * 0.33)], 5, 2.5, load=0.95, pool=0.2, seed=3)
    for k in range(5):
        x = cx - w * 0.25 + k * w * 0.12
        K.stroke(S, [(x, cy - h * 0.19), (x - 2, cy - h * 0.27)], 2, 1, load=0.9, pool=0, seed=10 + k)
    D = np.maximum(D, S)
    D = np.maximum(D, K.wash(K.ellipse_mask(h, w, cx, cy + h * 0.32, w * 0.4, h * 0.12), 0.33, seed, 0))
    img = TX.compose(D, seed, TX.glaze_base(h, w, seed))
    return np.rot90(img, rot).copy() if rot else img

def paint_bigface(w, h, seed):
    """Rosto grande de uma figura de painel (para o Ladrilheiro), que depois é remontado errado."""
    rng = np.random.default_rng(seed)
    D = np.zeros((h, w), np.float32); S = np.zeros_like(D)
    cx = w / 2
    face = [(cx + w * 0.38 * math.cos(a), h * 0.52 + h * 0.36 * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 26)]
    # fundo de cobalto médio com a figura em reserva branca: o painel lê como massa média sobre a parede clara
    fm = K.poly_mask(h, w, [face])
    D = np.maximum(D, K.wash(np.ones((h, w), np.float32), 0.8, seed + 5, 80) * (1 - fm))
    K.stroke(S, face, 7, 6, load=0.98, pool=0.1, seed=1)
    for k in range(9):  # cabelo em ondas
        y = h * 0.13 + k * 9
        K.stroke(S, [(cx - w * 0.42, y + 20), (cx - w * 0.2, y), (cx, y + 14), (cx + w * 0.2, y), (cx + w * 0.42, y + 20)], 6, 3, load=0.95, pool=0.2, seed=20 + k)
    for sx in (-1, 1):
        ex = cx + sx * w * 0.17; ey = h * 0.45
        K.stroke(S, [(ex - 40, ey), (ex - 10, ey - 22), (ex + 20, ey - 20), (ex + 42, ey + 2)], 7, 4, load=1.0, pool=0.3, seed=30 + sx)
        K.stroke(S, [(ex - 40, ey), (ex - 8, ey + 16), (ex + 22, ey + 14), (ex + 42, ey + 2)], 4, 3, load=0.9, pool=0.2, seed=40 + sx)
        D = np.maximum(D, K.ellipse_mask(h, w, ex, ey - 2, 15, 17) * 0.95)
        K.stroke(S, [(ex - 44, ey - 48), (ex, ey - 60), (ex + 44, ey - 46)], 6, 3, load=0.95, pool=0.2, seed=50 + sx)
    K.stroke(S, [(cx + 4, h * 0.47), (cx - 6, h * 0.6), (cx + 10, h * 0.64)], 5, 3, load=0.95, pool=0.2, seed=60)
    K.stroke(S, [(cx - 60, h * 0.72), (cx - 20, h * 0.75), (cx + 20, h * 0.75), (cx + 60, h * 0.71)], 7, 4, load=0.98, pool=0.3, seed=61)
    D = np.maximum(D, K.wash(K.ellipse_mask(h, w, cx - w * 0.22, h * 0.63, 40, 26), 0.36, seed + 1, 0))
    D = np.maximum(D, K.wash(K.ellipse_mask(h, w, cx + w * 0.22, h * 0.63, 40, 26), 0.36, seed + 2, 0))
    for k in range(10):  # gola rendada embaixo
        x = k * w / 10
        K.stroke(S, [(x, h * 0.92), (x + w / 20, h * 0.97), (x + w / 10, h * 0.92)], 4, 3, load=0.95, pool=0.1, seed=70 + k)
    D = np.maximum(K.granulate(D, seed, 0.1, 1.3), S)
    return TX.compose(K.rough_edge(D, seed, 0.9, 2.5), seed, TX.glaze_base(h, w, seed))

def mortar(w, h, seed):
    n = K.value_noise(h, w, 3, seed) * 0.6 + K.value_noise(h, w, 12, seed + 1) * 0.4
    return PT.two('ferro', 'rejunte', (n > 0.5).astype(np.float32) * 0.8) * 0.9 + 0.05

def crystal_cluster(F, c, n, size, rng, bone, region='salitre', up=Vector((0, 0, 1)), spread=0.6, fat=0.16):
    """Cristais de salitre: bipirâmides alongadas que brotam de um ponto."""
    for k in range(n):
        d = (up + Vector((rng.uniform(-spread, spread), rng.uniform(-spread, spread), rng.uniform(-spread, spread)))).normalized()
        L = size * rng.uniform(0.6, 1.3)
        a = Vector(c) - d * L * 0.15
        b = Vector(c) + d * L
        F.add(G.tube(tuple(a), tuple(b), [(0, 0.0), (0.35, L * fat), (1, 0.0)], 5, p=1.0), region, bone, spec=0.0, mat=0.5, smooth=False, oline=0.7)

ENEMY_BONES = {
    'lasca': [('root', (0, 0, 0), (0, 0, 0.1), None), ('corpo', (0, 0, 0.18), (0, 0, 0.5), 'root'), ('cabeca', (0, 0, 0.62), (0, 0, 0.85), 'corpo'),
              ('pe.L', (0.08, 0, 0.16), (0.12, -0.05, 0.02), 'root'), ('pe.R', (-0.08, 0, 0.16), (-0.12, -0.05, 0.02), 'root'),
              ('lasca1', (0.2, 0, 0.45), (0.3, 0, 0.5), 'corpo'), ('lasca2', (-0.2, 0, 0.35), (-0.3, 0, 0.4), 'corpo')],
}

def _common_regions(F, seed, tile_fn=TX.tile_diamond, tile_fn2=None):
    A = F.atlas
    A.region('frente', 256, 256, lambda w, h: tile_fn(seed))
    A.region('frente2', 256, 256, lambda w, h: (tile_fn2 or tile_fn)(seed + 1))
    A.region('biscoito', 64, 64, lambda w, h: PT.terracota(w, h, seed + 2))
    A.region('argamassa', 64, 64, lambda w, h: mortar(w, h, seed + 3))
    A.region('salitre', 64, 64, lambda w, h: PT.salitre_v(w, h, seed + 4))

# ================================================================== LASCA
def lasca():
    """Pilha de cacos de azulejo vidrados, mais alta que larga, inclinada para o alvo (frente = -Y).
    Os dois lados de cada caco são vidrados (padrão de azulejo); o miolo à mostra é terracota crua.
    O 'olho' é um pedaço de painel pintado fora do lugar, de lado, como o da Crosta."""
    rng = random.Random(41)
    nr = np.random.default_rng(41)
    F = G.Fig(ENEMY_BONES['lasca'], seed=41)
    _common_regions(F, 141, TX.tile_barra, TX.tile_diamond)
    F.atlas.region('olho', 128, 128, lambda w, h: paint_eye(w, h, 143, rot=1))
    R3 = ['frente', 'biscoito', 'frente2']
    R3b = ['frente2', 'biscoito', 'frente']
    SP = [1, 0, 1]; MT = [0, 0.25, 0]
    # base: caco largo e baixo, quase deitado (o pé da pilha)
    b0 = G.slab(broken_poly(0.34, 0.24, nr, 7, 0.2), 0.06, 0.012)
    G.xf(b0, rot=(70, 0, 8), loc=(0, 0.02, 0.15)); F.add(b0, R3b, 'corpo', spec=SP, mat=MT)
    # corpo: caco alto em pé, inclinado para a frente (para o alvo)
    body = G.slab(broken_poly(0.30, 0.52, nr, 7, 0.2), 0.06, 0.012)
    G.xf(body, rot=(16, 0, -5), loc=(0, -0.01, 0.42)); F.add(body, R3, 'corpo', spec=SP, mat=MT)
    # segundo caco cruzado atrás (dá volume visto de cima)
    b2 = G.slab(broken_poly(0.24, 0.42, nr, 6, 0.22), 0.055, 0.012)
    G.xf(b2, rot=(10, 0, 62), loc=(0.03, 0.06, 0.40)); F.add(b2, R3b, 'corpo', spec=SP, mat=MT)
    # cabeça: caco com o olho errado (de lado), inclinado para a frente
    hd = G.slab(broken_poly(0.26, 0.22, nr, 6, 0.15), 0.05, 0.01)
    G.xf(hd, rot=(28, 0, 14), loc=(0.02, -0.07, 0.74)); F.add(hd, ['olho', 'biscoito', 'frente'], 'cabeca', spec=SP, mat=MT)
    # pés: dois cacos deitados
    for s, sx in (('L', 1), ('R', -1)):
        ft = G.slab(broken_poly(0.16, 0.11, nr, 5, 0.2), 0.04, 0.008)
        G.xf(ft, rot=(80, 0, sx * 15), loc=(sx * 0.11, -0.06, 0.05)); F.add(ft, R3, 'pe.' + s, spec=SP, mat=MT)
    # lascas soltas que orbitam
    for bn, p in (('lasca1', (0.25, -0.02, 0.58)), ('lasca2', (-0.24, 0.0, 0.44))):
        ch = G.slab(broken_poly(0.10, 0.08, nr, 5, 0.25), 0.03, 0.006)
        G.xf(ch, rot=(rng.uniform(-40, 40), rng.uniform(-40, 40), rng.uniform(-40, 40)), loc=p); F.add(ch, R3, bn, spec=SP, mat=MT, oline=0.8)
    # salitre branco-esverdeado brotando das quebras
    crystal_cluster(F, (0.06, 0.03, 0.20), 6, 0.10, rng, 'corpo')
    crystal_cluster(F, (-0.12, 0.02, 0.48), 4, 0.08, rng, 'corpo', up=Vector((-1, 0.2, 0.6)))
    F.meta = dict(kind='inimigo')
    return F

# ================================================================== LADRILHEIRO TORTO
def ladrilheiro():
    nr = np.random.default_rng(51)
    rng = random.Random(51)
    bones = [('root', (0, 0, 0), (0, 0, 0.1), None), ('painel', (0, 0, 0.35), (0, 0, 2.3), 'root'),
             ('perna.L', (0.25, 0, 0.42), (0.27, 0, 0.02), 'root'), ('perna.R', (-0.25, 0, 0.42), (-0.27, 0, 0.02), 'root'),
             ('braco.L', (0.55, 0, 1.5), (0.75, -0.1, 1.0), 'painel'), ('braco.R', (-0.55, 0, 1.5), (-0.75, -0.1, 1.0), 'painel')]
    F = G.Fig(bones, seed=51)
    _common_regions(F, 151, TX.tile_folha)
    A = F.atlas
    A.region('rosto', 512, 1024 - 256 - 64, lambda w, h: paint_bigface(w, h, 153))
    # 4 x 8 azulejos com folga de rejunte; alguns girados (remontado errado), dois faltando
    W, H = 1.0, 2.0
    nx, nz = 4, 8
    tw, th = W / nx, H / nz
    missing = {(1, 5), (3, 2)}
    for i in range(nx):
        for j in range(nz):
            if (i, j) in missing:
                continue
            bm = G.box(tw - 0.012, 0.07, th - 0.012, 0.004)
            # UV: pedaço do rosto que caberia nesta posição, com troca e rotação "erradas"
            si, sj = i, j
            if (i + j * 3) % 5 == 0:
                si, sj = (nx - 1 - i), (nz - 1 - j)
            rot = (i * 7 + j * 3) % 4 if (i + j) % 3 == 0 else 0
            uvl = bm.loops.layers.uv.active
            for f in bm.faces:
                for lo in f.loops:
                    u, v = lo[uvl].uv
                    if f.normal.y < -0.7:
                        for _ in range(rot):
                            u, v = v, 1 - u
                        u = (si + u) / nx; v = 1 - (sj + v) / nz
                    lo[uvl].uv = (u, v)
            G.xf(bm, loc=(-W / 2 + (i + 0.5) * tw, 0, 0.4 + (j + 0.5) * th))
            F.add(bm, 'rosto', 'painel', spec=1.0, mat=0.0, oline=0.6)
    # verso de argamassa
    back = G.box(W + 0.02, 0.03, H + 0.02, 0.006); G.xf(back, loc=(0, 0.05, 0.4 + H / 2)); F.add(back, 'argamassa', 'painel', spec=0.0, mat=0.75)
    # pernas e braços de cacos
    for s, sx in (('L', 1), ('R', -1)):
        lg = G.slab(broken_poly(0.16, 0.46, nr, 6, 0.2), 0.05); G.xf(lg, rot=(0, 0, sx * 6), loc=(sx * 0.26, 0, 0.22))
        F.add(lg, ['frente', 'biscoito', 'argamassa'], 'perna.' + s, spec=[1, 0, 0], mat=[0, 0.25, 0.75])
        ar = G.slab(broken_poly(0.14, 0.55, nr, 6, 0.2), 0.045); G.xf(ar, rot=(0, 0, sx * 20), loc=(sx * 0.64, -0.05, 1.25))
        F.add(ar, ['frente2', 'biscoito', 'argamassa'], 'braco.' + s, spec=[1, 0, 0], mat=[0, 0.25, 0.75])
    crystal_cluster(F, (0.3, 0.0, 0.45), 6, 0.11, rng, 'painel')
    crystal_cluster(F, (-0.45, 0.0, 1.0), 4, 0.08, rng, 'painel', up=Vector((-1, 0, 0.3)))
    crystal_cluster(F, (-0.25, -0.03, 1.79), 3, 0.07, rng, 'painel', up=Vector((0, -1, 0.3)))
    F.meta = dict(kind='inimigo')
    return F

# ================================================================== CROSTA
def crosta():
    """Brutamontes de pedaços de barra de parede (azul-noite), coberto de cristais de salitre."""
    nr = np.random.default_rng(61)
    rng = random.Random(61)
    bones = [('root', (0, 0, 0), (0, 0, 0.1), None), ('corpo', (0, 0, 0.45), (0, 0, 1.2), 'root'), ('cabeca', (0, -0.15, 1.15), (0, -0.2, 1.4), 'corpo'),
             ('braco.L', (0.42, 0, 1.05), (0.62, -0.1, 0.55), 'corpo'), ('braco.R', (-0.42, 0, 1.05), (-0.62, -0.1, 0.55), 'corpo'),
             ('perna.L', (0.2, 0, 0.45), (0.24, 0, 0.02), 'root'), ('perna.R', (-0.2, 0, 0.45), (-0.24, 0, 0.02), 'root')]
    F = G.Fig(bones, seed=61)
    _common_regions(F, 161, TX.tile_barra)
    F.atlas.region('boca', 128, 128, lambda w, h: paint_eye(w, h, 163, rot=2))
    RT = ['frente', 'frente2', 'argamassa']   # pedaço de parede: azulejo na frente e nos lados quebrados
    RB = ['frente', 'biscoito', 'argamassa']
    SP = [1, 1, 0]; MT = [0, 0, 0.75]
    # tronco: dois blocos de parede empilhados e tortos, ombros largos
    body = G.slab([(-0.42, -0.2), (0.40, -0.24), (0.46, 0.22), (-0.38, 0.26)], 0.52, 0.03)
    G.xf(body, rot=(4, 3, 3), loc=(0, 0.04, 0.72)); F.add(body, RT, 'corpo', spec=SP, mat=MT)
    top = G.slab([(-0.55, -0.16), (0.52, -0.2), (0.58, 0.14), (0.0, 0.22), (-0.6, 0.12)], 0.56, 0.03)
    G.xf(top, rot=(-4, -4, -3), loc=(0.02, 0.0, 1.06)); F.add(top, RT, 'corpo', spec=SP, mat=MT)
    hd = G.slab(broken_poly(0.32, 0.26, nr, 6, 0.15), 0.14); G.xf(hd, rot=(25, 0, -8), loc=(0, -0.24, 1.3)); F.add(hd, ['boca', 'biscoito', 'argamassa'], 'cabeca', spec=[1, 0, 0], mat=[0, 0.25, 0.75])
    for s, sx in (('L', 1), ('R', -1)):
        ar = G.slab(broken_poly(0.26, 0.6, nr, 6, 0.15), 0.2); G.xf(ar, rot=(10, 0, sx * 14), loc=(sx * 0.6, -0.06, 0.78))
        F.add(ar, RT, 'braco.' + s, spec=SP, mat=MT)
        fs = G.slab(broken_poly(0.34, 0.3, nr, 6, 0.15), 0.3); G.xf(fs, rot=(0, 0, sx * 10), loc=(sx * 0.68, -0.1, 0.42))
        F.add(fs, RB, 'braco.' + s, spec=[1, 0, 0], mat=[0, 0.25, 0.75])
        lg = G.slab(broken_poly(0.24, 0.44, nr, 6, 0.15), 0.22); G.xf(lg, loc=(sx * 0.22, 0, 0.22))
        F.add(lg, RT, 'perna.' + s, spec=SP, mat=MT)
    # crosta de salitre: cachos grandes no dorso, ombros, cabeça e punhos
    for c, n, s_, up in [((0, 0.22, 1.32), 14, 0.30, Vector((0, 0.5, 1))), ((0.45, 0.02, 1.3), 9, 0.24, Vector((0.6, 0, 1))), ((-0.47, 0.02, 1.28), 9, 0.24, Vector((-0.6, 0, 1))),
                         ((0.2, 0.3, 0.85), 8, 0.2, Vector((0.2, 1, 0.3))), ((-0.25, 0.28, 0.6), 6, 0.18, Vector((-0.2, 1, 0.1))),
                         ((0.72, -0.1, 0.28), 6, 0.16, Vector((0.6, -0.3, -0.2))), ((-0.72, -0.1, 0.28), 6, 0.16, Vector((-0.6, -0.3, -0.2))), ((0.1, -0.3, 1.45), 5, 0.14, Vector((0, -0.3, 1)))]:
        bone = 'corpo' if abs(c[0]) < 0.6 else ('braco.L' if c[0] > 0 else 'braco.R')
        crystal_cluster(F, c, n, s_ * 1.35, rng, bone, up=up, spread=0.6, fat=0.27)
    for k in range(10):
        c = (rng.uniform(-0.45, 0.45), rng.uniform(-0.1, 0.25), rng.uniform(1.25, 1.36))
        crystal_cluster(F, c, 3, 0.22, rng, 'corpo', up=Vector((0, 0.2, 1)), spread=0.7, fat=0.3)
    F.meta = dict(kind='inimigo')
    return F

ENEMIES = {'lasca': lasca, 'ladrilheiro': ladrilheiro, 'crosta': crosta}

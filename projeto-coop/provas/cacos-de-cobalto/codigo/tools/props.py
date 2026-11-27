# Adereços do cais (materiais do porto: madeira, corda, ferro; foscos, sem pintura) e peças de
# louça da parede (carranca do chafariz). Cada um é uma figura de um osso com casca de contorno.
import math, random
import numpy as np
from mathutils import Vector
import geo as G
import pintura as PT
import pincel as K
import texturas as TX

ROOT = [('root', (0, 0, 0), (0, 0, 0.3), None)]

def _wood_regions(F, seed):
    A = F.atlas
    A.region('madeira', 128, 256, lambda w, h: PT.wood(w, h, seed))
    A.region('madeira_e', 64, 64, lambda w, h: PT.flat('madeira_e', w, h, seed + 1, 0.08))
    A.region('ferro', 64, 64, lambda w, h: PT.iron(w, h, seed + 2))
    A.region('corda', 128, 128, lambda w, h: PT.rope(w, h, seed + 3))
    A.region('oleo', 64, 64, lambda w, h: PT.flat('oleo', w, h, seed + 4, 0.1))

def barril():
    F = G.Fig(ROOT, seed=71); _wood_regions(F, 171)
    prof = [(0.0, 0, 0, 0), (0.005, 0.27, 0.27, 0.27), (0.2, 0.31, 0.31, 0.31), (0.45, 0.335, 0.335, 0.335), (0.7, 0.31, 0.31, 0.31), (0.895, 0.27, 0.27, 0.27), (0.9, 0, 0, 0)]
    F.add(G.loft(prof, 20, 2.0, fold=lambda i, th: 1 + 0.012 * math.cos(20 * th)), 'madeira', spec=0.0, mat=0.75, smooth=True)
    for z, r in ((0.12, 0.30), (0.33, 0.333), (0.57, 0.333), (0.78, 0.30)):
        F.add(G.loft([(z - 0.03, 0, 0, 0), (z - 0.028, r + 0.012, r + 0.012, r + 0.012), (z + 0.028, r + 0.012, r + 0.012, r + 0.012), (z + 0.03, 0, 0, 0)], 20), 'ferro', spec=0.2, mat=1.0, oline=0.5)
    # escorrido de óleo (castanho-manganês: interage)
    F.add(G.tube((0.12, -0.31, 0.88), (0.15, -0.335, 0.4), [(0, 0.0), (0.1, 0.035), (0.8, 0.03), (1, 0.0)], 8, flat=0.35), 'oleo', spec=0.9, mat=0.0, oline=0.6)
    F.add(G.loft([(0.895, 0, 0, 0), (0.9, 0.25, 0.25, 0.25), (0.905, 0, 0, 0)], 20), 'oleo', spec=1.0, oline=0.0)
    return F

def cabeco():
    """Cabeço de amarração de ferro com corda enrolada."""
    F = G.Fig(ROOT, seed=72); _wood_regions(F, 172)
    prof = [(0.0, 0, 0, 0), (0.005, 0.2, 0.2, 0.2), (0.08, 0.19, 0.19, 0.19), (0.12, 0.13, 0.13, 0.13), (0.42, 0.11, 0.11, 0.11), (0.5, 0.17, 0.17, 0.17), (0.58, 0.16, 0.16, 0.16), (0.6, 0, 0, 0)]
    F.add(G.loft(prof, 16), 'ferro', spec=0.35, mat=1.0)
    for k in range(5):
        z = 0.16 + k * 0.05
        F.add(G.loft([(z - 0.025, 0, 0, 0), (z - 0.02, 0.15, 0.15, 0.15), (z + 0.02, 0.15, 0.15, 0.15), (z + 0.025, 0, 0, 0)], 16, fold=lambda i, th: 1 + 0.05 * math.sin(3 * th + k)), 'corda', spec=0.0, mat=0.75, oline=0.7)
    # rolo de corda no chão
    rng = random.Random(3)
    pts = []
    for k in range(70):
        a = k * 0.45
        r = 0.18 + 0.006 * k
        pts.append(Vector((0.55 + r * math.cos(a), -0.1 + r * math.sin(a), 0.035 + 0.01 * (k % 3))))
    for a, b in zip(pts[:-1], pts[1:]):
        F.add(G.tube(tuple(a), tuple(b), [(0, 0.032), (1, 0.032)], 6), 'corda', spec=0.0, mat=0.75, oline=0.5)
    return F

def caixote():
    F = G.Fig(ROOT, seed=73); _wood_regions(F, 173)
    for i, (dx, dz, sz, rz) in enumerate([(0, 0, 0.6, 3), (0.05, 0.6, 0.5, -6)]):
        for k in range(4):  # tábuas
            b = G.box(sz, sz, sz / 4 - 0.01, 0.006); G.xf(b, rot=(0, 0, rz), loc=(dx, 0, dz + sz / 8 + k * sz / 4))
            F.add(b, 'madeira', spec=0.0, mat=0.75, oline=0.8)
        for sx in (-1, 1):
            for sy in (-1, 1):
                p = G.box(0.05, 0.05, sz, 0.004); G.xf(p, rot=(0, 0, rz), loc=(dx + sx * (sz / 2 - 0.01), sy * (sz / 2 - 0.01), dz + sz / 2))
                F.add(p, 'madeira_e', spec=0.0, mat=0.75, oline=0.8)
    return F

def rede():
    """Monte de rede de pesca com boias (corda, fosca)."""
    F = G.Fig(ROOT, seed=74); _wood_regions(F, 174)
    A = F.atlas
    A.region('rede', 128, 128, lambda w, h: PT.two('corda', 'madeira_e', (((np.indices((h, w))[0] + np.indices((h, w))[1]) % 12 < 2) | ((np.indices((h, w))[0] - np.indices((h, w))[1]) % 12 < 2)).astype(np.float32) * 0.9))
    A.region('boia', 64, 64, lambda w, h: PT.flat('estanho', w, h, 5, 0.04))
    rng = random.Random(5)
    for k in range(4):
        c = Vector((rng.uniform(-0.35, 0.35), rng.uniform(-0.3, 0.3), 0))
        r = rng.uniform(0.28, 0.42)
        bm = G.loft([(0.0, 0, 0, 0), (0.005, r, r * 0.9, r * 0.85), (r * 0.35, r * 0.8, r * 0.75, r * 0.7), (r * 0.6, 0, 0, 0)], 14, 2.0, fold=lambda i, th: 1 + 0.08 * math.sin(5 * th + i))
        G.xf(bm, loc=tuple(c)); F.add(bm, 'rede', spec=0.0, mat=0.75)
    for k in range(5):
        b = G.sphere(1.0, 10, 7); G.xf(b, scale=(0.06, 0.06, 0.05), loc=(rng.uniform(-0.5, 0.5), rng.uniform(-0.4, 0.4), rng.uniform(0.15, 0.3)))
        F.add(b, 'boia', spec=0.0, mat=0.75)
    return F

def porta():
    F = G.Fig(ROOT, seed=75); _wood_regions(F, 175)
    W, H = 1.5, 2.5
    for s in (-1, 1):
        for k in range(5):
            b = G.box(W / 10 - 0.01, 0.06, H - 0.02, 0.008); G.xf(b, rot=(0, s * 1.5, 0), loc=(s * (W / 4) + (k - 2) * W / 10, 0, H / 2))
            F.add(b, 'madeira', spec=0.0, mat=0.75, oline=0.6)
        for z in (0.4, 2.1):
            hg = G.box(W / 2 - 0.08, 0.02, 0.07, 0.005); G.xf(hg, loc=(s * W / 4, -0.04, z)); F.add(hg, 'ferro', spec=0.3, mat=1.0, oline=0.6)
        tb = G.box(0.08, 0.07, H - 0.2, 0.006); G.xf(tb, rot=(0, s * 30, 0), loc=(s * W / 4, -0.045, H / 2)); F.add(tb, 'madeira_e', spec=0.0, mat=0.75, oline=0.6)
    fr = G.box(W + 0.2, 0.12, 0.12, 0.01); G.xf(fr, loc=(0, -0.02, H + 0.06)); F.add(fr, 'madeira_e', spec=0.0, mat=0.75)
    for s in (-1, 1):
        f2 = G.box(0.12, 0.12, H, 0.01); G.xf(f2, loc=(s * (W / 2 + 0.06), -0.02, H / 2)); F.add(f2, 'madeira_e', spec=0.0, mat=0.75)
    return F

def carranca():
    """Chafariz de parede: máscara de louça azul-noite pintada de branco, bica e bacia."""
    F = G.Fig(ROOT, seed=76)
    A = F.atlas
    A.region('mascara', 256, 192, lambda w, h: PT.face_region(w, h, 176, face_s=(0.35, 0.65), face_t=(0.25, 0.9), hair=None))
    A.region('bacia', 256, 64, lambda w, h: PT.white_panel(w, h, 177, PT.compose_deco(PT.deco_bands([0.2, 0.8], 4), PT.deco_scallops(0.35, 10, 0.25, 2.5))))
    A.region('liso', 64, 64, lambda w, h: PT.navy(w, h, 178, PT.deco_dots(14, 2.2)))
    A.region('agua', 64, 64, lambda w, h: PT.flat('aguado', w, h, 179, 0.05))
    mk = G.loft([(0.0, 0, 0, 0), (0.03, 0.18, 0.05, 0.02), (0.15, 0.24, 0.12, 0.03), (0.32, 0.22, 0.12, 0.03), (0.42, 0.14, 0.08, 0.03), (0.46, 0, 0, 0)], 20, 2.2)
    G.xf(mk, loc=(0, 0, 1.05)); F.add(mk, 'mascara', spec=1.0)
    for sx in (-1, 1):  # bochechas infladas (a carranca sopra)
        ch = G.sphere(1.0, 10, 7); G.xf(ch, scale=(0.07, 0.06, 0.06), loc=(sx * 0.11, -0.1, 1.15)); F.add(ch, 'mascara', spec=1.0)
    sp = G.tube((0, -0.08, 1.12), (0, -0.26, 1.08), [(0, 0.04), (0.8, 0.035), (1, 0.0)], 10); F.add(sp, 'liso', spec=1.0)
    bowl = G.loft([(0.0, 0, 0, 0), (0.005, 0.2, 0.3, 0.02), (0.18, 0.34, 0.42, 0.02), (0.2, 0.0, 0.0, 0.0)], 20, 2.0)
    G.xf(bowl, loc=(0, 0.0, 0.55)); F.add(bowl, 'bacia', spec=1.0)
    ped = G.tube((0, -0.12, 0.0), (0, -0.12, 0.56), [(0, 0.13), (0.15, 0.1), (0.85, 0.08), (1, 0.12)], 12); F.add(ped, 'liso', spec=1.0)
    w = G.tube((0, -0.25, 1.07), (0, -0.27, 0.72), [(0, 0.018), (1, 0.03)], 8); F.add(w, 'agua', spec=1.0, oline=0.0)
    return F

def borda_cais():
    """Viga de madeira na borda do cais, 18 m em módulos de 2 m, com face vertical de tábuas."""
    F = G.Fig(ROOT, seed=77); _wood_regions(F, 177)
    for k in range(5):
        b = G.box(2.0, 0.32, 0.18, 0.02); G.xf(b, loc=(k * 2.02 - 4.04, 0, 0.0)); F.add(b, 'madeira', spec=0.0, mat=0.75)
        f = G.box(2.0, 0.1, 0.6, 0.02); G.xf(f, loc=(k * 2.02 - 4.04, -0.16, -0.38)); F.add(f, 'madeira_e', spec=0.0, mat=0.75, oline=0.6)
    return F

PROPS = {'barril': barril, 'cabeco': cabeco, 'caixote': caixote, 'rede': rede, 'porta': porta, 'carranca': carranca, 'borda_cais': borda_cais}

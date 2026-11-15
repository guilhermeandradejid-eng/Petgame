"""en_sentinela.py: Sentinela de Ruina, golem de blocos de ruina com musgo (2,2 m, elite)."""
import math

from mathutils import Vector

import lp
import en_base as eb
import en_golem as eg
from en_base import C

ID = 'sentinela'
NAME = 'Sentinela de Ruína'
RADIUS = 0.80
HEIGHT = 2.20
S = 1.0
BONES = eg.rig(S)
GOL = eg.Golem(S, 1.0)

STONE = C('#8d86a8')
STONE_HI = C('#b6aec6')
STONE_LO = C('#544d78')
DARKST = C('#6a6390')
MOSS = C('#6cbf4a')
MOSS_LO = C('#2f8a58')
CLAY = C('#c9643e')


def stone(g, seed=0, lo=STONE_LO, mid=STONE, hi=STONE_HI, moss=0.9):
    """Pinta um bloco: base mais escura e fria, topo claro, musgo no que olha para cima."""
    b0, b1 = g.bounds()
    eb.paint3(g, [(b0[2], eb.mixc(lo, mid, 0.35)), (b0[2] + (b1[2] - b0[2]) * 0.45, mid), (b1[2], eb.mixc(mid, hi, 0.6))])
    eb.speckle(g, 0.05, seed)
    if moss:
        k = 5.0 + seed
        eb.top_tint(g, MOSS, thresh=0.45, soft=0.35, amount=moss,
                    noise=lambda p: 0.45 * math.sin(p.x * 9 + k) + 0.45 * math.sin(p.y * 11 + k * 1.7))
    return g


def tuft(pos, r, seed):
    t = lp.icosphere(r, 1, jitter=0.18, seed=seed)
    t.scale(1.0, 1.0, 0.55)
    eb.paint(t, -r * 0.5, r * 0.5, MOSS_LO, MOSS)
    return t.move(*pos)


def model():
    g = lp.Geo()

    def add(geo, bone, seed=0, **kw):
        g.add(stone(geo, seed, **kw).bind(bone))

    # ---- quadril e cintura (tambor de coluna)
    add(eb.cbox(0.64, 0.46, 0.30, 0.05, center=(0, 0, 0.98), taper=0.88), 'body', 1, moss=0.3)
    add(lp.cyl(0.25, 0.17, n=8, r_top=0.23, center=(0, 0, 1.165), smooth=False), 'body', 2, lo=DARKST, mid=DARKST, moss=0)
    # ---- peito com a runa
    add(eb.cbox(0.94, 0.60, 0.72, 0.07, center=(0, 0.02, 1.50), taper=1.16), 'torso', 3)
    add(eb.cbox(1.14, 0.20, 0.10, 0.03, center=(0, -0.24, 1.80)).rot('X', 12, (0, -0.24, 1.80)), 'torso', 4, hi=STONE_HI, moss=0.5)
    frame = lp.lathe([(0.16, 0.0), (0.245, 0.0), (0.245, 0.07), (0.17, 0.085)], n=8, smooth=False, phase=0.5)
    frame.rot('X', 90).move(0, -0.285, 1.42)
    add(frame, 'torso', 5, lo=STONE_LO, mid=DARKST, hi=STONE, moss=0)
    gem = lp.lathe([(0.175, 0.0), (0.12, 0.05), (0.0, 0.075)], n=8, smooth=False, mat='glow', phase=0.5)
    gem.rot('X', 90).move(0, -0.305, 1.42)
    gem.tint(lambda p, c: eb.mixc(eb.GLOW_LO, eb.GLOW_HI, max(0.0, 1.0 - math.hypot(p.x, p.z - 1.42) / 0.17)))
    g.add(gem.bind('core'))
    for a in (-1, 1):   # marcas da runa
        m = eb.cbox(0.035, 0.03, 0.17, 0.008, center=(0.33 * a, -0.335, 1.42), mat='glow').color(eb.GLOW_LO)
        m.rot('Y', 24 * a, (0.33 * a, -0.335, 1.42))
        g.add(m.bind('core'))
    # ---- cabeca pequena
    hd = eb.cbox(0.40, 0.38, 0.33, 0.05, center=(0, -0.02, 2.02), taper=0.90)
    hd.rot('Z', 5, (0, 0, 2.0))
    add(hd, 'noggin', 6)
    brow = eb.cbox(0.46, 0.14, 0.08, 0.02, center=(0, -0.17, 2.115)).rot('X', 14, (0, -0.17, 2.115))
    add(brow, 'noggin', 7, lo=STONE_LO, mid=DARKST, hi=STONE, moss=0.4)
    for a in (-1, 1):
        e = eb.cbox(0.105, 0.03, 0.050, 0.008, center=(0.092 * a, -0.212, 2.03), mat='glow').color(eb.mixc(eb.GLOW_LO, eb.GLOW_HI, 0.5))
        e.rot('Y', 10 * a, (0.092 * a, -0.212, 2.03))
        g.add(e.bind('eyes'))
    g.add(tuft((0.08, 0.02, 2.19), 0.12, 3).bind('noggin'))
    sp, _ = eb.leaf(0.17, 0.09, n=3, droop=60, thickness=0.01)
    eb.paint(sp, 0, 0.16, MOSS_LO, C('#a8e85a'))
    g.add(sp.copy().rot('Z', 60).rot('Y', 20).move(0.10, 0.02, 2.22).bind('noggin'))
    g.add(sp.copy().rot('Z', -120).rot('Y', -28).move(0.10, 0.02, 2.22).bind('noggin'))
    # ---- lados
    for a in (1, -1):
        sf = '.L' if a > 0 else '.R'
        sd = 10 if a > 0 else 20
        sh = eb.cbox(0.46, 0.50, 0.44, 0.06, center=(0.74 * a, 0, 1.66))
        sh.rot('Y', 9 * a, (0.74 * a, 0, 1.66)).rot('Z', 6, (0.74 * a, 0, 1.66))
        add(sh, 'armU' + sf, sd)
        add(eb.cbox(0.22, 0.24, 0.30, 0.04, center=(0.80 * a, 0.01, 1.32)), 'armU' + sf, sd + 1, lo=STONE_LO, mid=DARKST, hi=STONE, moss=0)
        col = lp.stack([(0.59, 0.25, 0.25, 0.85 * a, -0.02), (1.15, 0.205, 0.205, 0.85 * a, -0.02)], n=8, smooth=False)
        add(col, 'armF' + sf, sd + 2, moss=0)
        for z, r in ((1.12, 0.265), (0.62, 0.30)):
            add(lp.cyl(r, 0.085, n=8, center=(0.85 * a, -0.02, z), smooth=False), 'armF' + sf, sd + 3, hi=STONE_HI, moss=0.6)
        band = lp.cyl(0.250, 0.09, n=8, r_top=0.240, center=(0.85 * a, -0.02, 0.86), smooth=False)
        band.color(CLAY)
        eb.under_shade(band, 0.6)
        g.add(band.bind('armF' + sf))
        add(eb.cbox(0.52, 0.54, 0.40, 0.07, center=(0.86 * a, -0.06, 0.34), taper=0.92), 'fist' + sf, sd + 4, moss=0.2)
        for k in (-1, 0, 1):
            kn = eb.cbox(0.13, 0.08, 0.20, 0.025, center=(0.86 * a + 0.165 * k, -0.345, 0.30))
            add(kn, 'fist' + sf, sd + 5 + k, lo=STONE_LO, mid=DARKST, hi=STONE, moss=0)
        add(eb.cbox(0.30, 0.34, 0.34, 0.05, center=(0.28 * a, 0, 0.70)), 'legU' + sf, sd + 6, moss=0.3)
        add(eb.cbox(0.24, 0.28, 0.26, 0.04, center=(0.29 * a, -0.01, 0.37)), 'legF' + sf, sd + 7, lo=STONE_LO, mid=DARKST, hi=STONE, moss=0)
        add(eb.cbox(0.42, 0.62, 0.24, 0.05, center=(0.30 * a, -0.08, 0.12), taper=0.84), 'paw' + sf, sd + 8, moss=0.6)
    # assimetrias: toco de coluna e musgo num ombro, trepadeira no antebraco esquerdo
    add(lp.cyl(0.13, 0.20, n=8, r_top=0.115, center=(0.80, 0.06, 1.96), smooth=False).rot('Y', 8, (0.8, 0, 1.9)), 'armU.L', 40)
    g.add(tuft((-0.78, -0.08, 1.90), 0.15, 5).bind('armU.R'))
    g.add(tuft((-0.66, 0.14, 1.88), 0.10, 6).bind('armU.R'))
    g.add(tuft((0.30, 0.18, 1.90), 0.12, 8).bind('torso'))
    pts = []
    for i in range(13):
        t = i / 12.0
        ang = t * math.tau * 1.6 + 0.6
        r = 0.262 - 0.045 * t
        pts.append((0.85 + math.cos(ang) * r, -0.02 + math.sin(ang) * r, 0.60 + 0.56 * t))
    vine = lp.tube(pts, [0.020 + 0.012 * math.sin(i / 12.0 * math.pi) for i in range(13)], n=4)
    eb.paint(vine, 0.6, 1.16, MOSS_LO, MOSS)
    g.add(vine.bind('armF.L'))
    lp.bake_ao(g, strength=0.55, dist=0.5, samples=18, floor_z=0.0)
    return g


def clips(sk, g):
    G = GOL
    slam, sh = G.slam(sk)
    sweep, wh = G.sweep(sk)
    return [(G.idle(sk), None), (G.move(sk), None), (slam, sh), (sweep, wh), (G.hit(sk), None), (G.die(sk, g=g), None),
            (G.assemble(sk, g=g), None)]

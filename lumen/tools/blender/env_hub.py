"""env_hub.py: kit "Vila do Farol" (o acampamento aconchegante entre as expedicoes).

    python3 tools/blender/env_hub.py [--out caminho.glb] [--only cottage_a,well]

Usa os ajudantes de env_forest.py (casco, pintura por faceta, AO azulada, folhagem). Madeira
quente, reboco creme, telhados verde-agua e coral, pano mostarda e luz de ambar.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import lp  # noqa: E402
from mathutils import Vector  # noqa: E402
from lp import Geo, box, lathe, loft, merge, poly_extrude, ring_pts, sheet, stack, tube  # noqa: E402,F401
import env_forest as F  # noqa: E402
from env_forest import H, WHITE, mixc, mul  # noqa: E402
from kit import Kit  # noqa: E402

TAU = math.tau
kit = Kit('env_hub')

WOOD = H('#b07a4f')
WOOD_D = H('#8a5a3c')
WOOD_L = H('#cf9a6a')
PLASTER = mixc(H('#f1e3c8'), H('#ffd9a0'), 0.35)
TEAL = H('#3d8f9e')
CORAL = H('#e2665a')
MUSTARD = H('#f2b632')
CREAM = H('#fff3df')
STRAW = H('#e9c46a')
IRON = H('#3b3350')
DARK = H('#3b2a48')
SOIL = H('#5a3b4a')
AMBER = F.AMBER
STONE = mixc(F.STONE, PLASTER, 0.18)


def P(g, col, seed=0, var=0.05, top=None, sun=0.10):
    """Pinta uma parte: cor base + variacao por faceta + luz quente do lado do sol."""
    return F.facet(g, col, top, var=var, seed=seed, sun=sun, under=(0.78, 0.75, 0.93))


def finish(g, lo=(0.84, 0.80, 0.90), strength=0.6, dist=0.7, zmax=None):
    """Degrade frio na base (menos no 'glow') e AO azulada."""
    glow = {i for f, m in zip(g.f, g.fm) if m == 'glow' for i in f}
    b0, b1 = g.bounds()
    zmax = b1[2] if zmax is None else zmax
    out = []
    for i, (p, c) in enumerate(zip(g.v, g.c)):
        if i in glow:
            out.append(c)
        else:
            t = max(0.0, min(1.0, p.z / max(1e-6, zmax * 0.55)))
            out.append(mul(c, mixc(lo, WHITE, t)))
    g.c = out
    return F.ao(g, strength, dist=dist)


def bar(p0, p1, w=0.1, col=WOOD_D, seed=0, n=4):
    """Sarrafo/viga de secao quadrada entre dois pontos."""
    g = tube([p0, p1], w * 0.707, n, phase=0.5).flat()
    return P(g, col, seed, var=0.06)


def plank(x0, x1, y0, y1, z0, z1, col=WOOD, seed=0, j=0.015, chips=(), **kw):
    return P(F.block(x0, x1, y0, y1, z0, z1, seed=seed, j=j, chips=chips, **kw), col, seed, var=0.07)


def roof_slope(y0, y1, ridge_z, eave_z, half_w, over=0.42, ny=4, nu=3, th=0.16, sag=0.12, kick=0.12, col=TEAL, seed=0):
    """Agua do lado +X de um telhado com cumeeira ao longo de Y: selada no meio, beiral arrebitado."""
    rows = []
    for j in range(ny + 1):
        v = j / ny
        y = y0 + (y1 - y0) * v
        s = sag * math.sin(math.pi * v)
        row = []
        for i in range(nu + 1):
            u = i / nu
            x = (half_w + over) * u
            z = ridge_z - s * (1.0 - 0.6 * u) - (ridge_z - eave_z) * u + (kick if i == nu else 0.0)
            row.append((x, y, z))
        rows.append(row)
    g = sheet(rows, 'vcol', thickness=th)
    zr = ridge_z - eave_z

    def fn(n, cen, c):
        return mul(c, mixc((0.80, 0.84, 0.98), (1.08, 1.05, 1.0), max(0.0, min(1.0, (cen.z - eave_z) / zr))))
    return F.facet(g, col, var=0.09, seed=seed, sun=0.08, fn=fn, under=(0.6, 0.6, 0.8))


def gable_roof(y0, y1, ridge_z, eave_z, half_w, col=TEAL, seed=0, **kw):
    a = roof_slope(y0, y1, ridge_z, eave_z, half_w, col=col, seed=seed, **kw)
    b = roof_slope(y0, y1, ridge_z, eave_z, half_w, col=col, seed=seed + 5, **kw).mirrored()
    sag = kw.get('sag', 0.12)
    path = [(0.0, y0 - 0.05 + (y1 - y0 + 0.1) * i / 4, ridge_z + 0.03 - sag * math.sin(math.pi * i / 4)) for i in range(5)]
    cap = tube(path, 0.12, 4, phase=0.5).flat()
    P(cap, mul(col, (0.8, 0.8, 0.9)), seed + 2, var=0.05)
    return merge(a, b, cap)


def round_window(r=0.34, n=10, depth=0.12, frame=WOOD_D, seed=0):
    """Janela redonda virada para -Y, centro na origem: aro, vidro de luz e cruzeta."""
    def ring(rr, y):
        return [(math.cos(TAU * i / n) * rr, y, math.sin(TAU * i / n) * rr) for i in range(n)]
    fr = loft([ring(r + 0.14, 0.0), ring(r + 0.11, -depth), ring(r, -depth), ring(r, -0.03)], cap_a=False, cap_b=False, smooth=False)
    P(fr, frame, seed, var=0.06)
    pane = Geo()
    c = pane.add_vert((0, -0.03, 0), None, mul(AMBER, (0.95, 0.9, 0.8)))
    rg = [pane.add_vert(p, None, mul(AMBER, (0.9, 0.55, 0.32))) for p in ring(r, -0.03)]
    for i in range(n):
        pane.add_face((c, rg[i], rg[(i + 1) % n]), 'glow', False)
    m1 = plank(-0.03, 0.03, -depth - 0.01, -0.035, -r, r, frame, seed + 1, j=0.0)
    m2 = plank(-r, r, -depth - 0.01, -0.035, -0.03, 0.03, frame, seed + 2, j=0.0)
    return merge(fr, pane, m1, m2)


def door(w=0.9, h=1.7, seed=0, col=WOOD):
    """Porta de tabuas com topo em arco, virada para -Y, base em z=0."""
    def prof(ww, hh):
        return [(-ww / 2, 0), (ww / 2, 0), (ww / 2, hh * 0.72), (ww * 0.3, hh * 0.93), (0, hh), (-ww * 0.3, hh * 0.93), (-ww / 2, hh * 0.72)]
    fr = P(poly_extrude(prof(w + 0.24, h + 0.13), 0.16), WOOD_D, seed, var=0.05)
    leafd = P(poly_extrude(prof(w, h), 0.1), col, seed + 1, var=0.05).move(0, -0.06, 0)
    s1 = plank(-w / 2 + 0.03, w / 2 - 0.03, -0.14, -0.08, h * 0.2, h * 0.2 + 0.08, IRON, seed + 2, j=0.0)
    s2 = plank(-w / 2 + 0.03, w / 2 - 0.03, -0.14, -0.08, h * 0.62, h * 0.62 + 0.08, IRON, seed + 3, j=0.0)
    knob = F.gem((w * 0.3, -0.15, h * 0.45), 0.045, 0.05, col=MUSTARD, n=5)
    return merge(fr, leafd, s1, s2, knob)


def lantern(pos, s=1.0, rope=0.0):
    """Lampiao pendurado: corpo de luz, tampa e fundo de madeira escura. pos = fundo do corpo."""
    body = stack([(0.0, 0.07 * s, 0.07 * s), (0.05 * s, 0.115 * s, 0.115 * s), (0.25 * s, 0.125 * s, 0.125 * s), (0.31 * s, 0.07 * s, 0.07 * s)],
                 5, 'glow', phase=0.3).flat()
    body.tint(lambda p, c: mixc((0.85, 0.30, 0.10), mul(AMBER, (0.9, 0.82, 0.7)), min(1.0, max(0.0, p.z / (0.3 * s)))))
    cap = lathe([(0.16 * s, 0.30 * s), (0.07 * s, 0.39 * s), (0.0, 0.44 * s)], 5, phase=0.3, smooth=False)
    foot = lathe([(0.0, -0.06 * s), (0.09 * s, -0.01 * s), (0.07 * s, 0.01 * s)], 5, phase=0.3, smooth=False)
    P(cap, WOOD_D, 1, var=0.06)
    P(foot, WOOD_D, 2, var=0.06)
    g = merge(body, cap, foot)
    if rope > 0:
        g.add(tube([(0, 0, 0.42 * s), (0.0, 0.0, 0.42 * s + rope)], 0.014, 3, cap_a=False, cap_b=False).flat().color(mul(WOOD_D, (0.7, 0.7, 0.8))))
    return g.move(*pos)


def flower_dots(specs, seed=0):
    """Florzinhas de canteiro. specs = [(x, y, z, cor)...]"""
    g = Geo()
    rnd = random.Random(seed)
    for x, y, z, col in specs:
        hd = F._head(0.075, 5, col, MUSTARD if col != MUSTARD else CREAM)
        hd.rot('X', rnd.uniform(-25, 25)).rot('Y', rnd.uniform(-25, 25)).rot('Z', rnd.uniform(0, 72))
        g.add(hd.move(x, y, z))
    return g


BLUE = H('#7fb8ff')


# =========================================================================== CASAS
@kit.prop('cottage_a', collider=('box', 4.9, 3.9, 3.2), tags=['building', 'cottage'],
          light=dict(color='#ffc46b', energy=1.2, height=1.8, range=5.0, offset=[-0.05, -2.1]))
def cottage_a():
    # empena de frente, telhado verde-agua selado, chamine torta, janela redonda no sotao
    W, D = 2.2, 1.75
    yf = -D - 0.06
    base = P(F.block(-W - 0.14, W + 0.14, -D - 0.14, D + 0.14, 0.0, 0.55, seed=1, j=0.03, chips=(4, 5), chip=0.2, bevel=0.05), STONE, 1, var=0.06)
    quoins = merge(*[P(F.block(sx * (W + 0.02) - 0.26, sx * (W + 0.02) + 0.26, -D - 0.2, -D + 0.2, z, z + 0.42, seed=7 + i, j=0.02, bevel=0.04), STONE, 3 + i, var=0.08)
                     for i, (sx, z) in enumerate(((-1, 0.5), (1, 0.52), (1, 0.98)))])
    walls = F.hull([(sx * W, sy * D, 0.5) for sx in (-1, 1) for sy in (-1, 1)] + [(sx * (W + 0.14), sy * (D + 0.05), 2.7) for sx in (-1, 1) for sy in (-1, 1)]
                   + [(0.05, sy * (D + 0.05), 4.75) for sy in (-1, 1)])
    P(walls, PLASTER, 2, var=0.03)
    beams = merge(
        plank(-W - 0.2, -W + 0.02, yf - 0.07, yf + 0.1, 0.5, 2.72, WOOD_D, 1),
        plank(W - 0.0, W + 0.22, yf - 0.07, yf + 0.1, 0.5, 2.72, WOOD_D, 2),
        plank(-W - 0.3, W + 0.32, yf - 0.1, yf + 0.1, 2.62, 2.82, WOOD_D, 3),
        plank(-0.8, 0.9, yf - 0.07, yf + 0.1, 4.08, 4.2, WOOD_D, 4),
        plank(0.05, 0.2, yf - 0.07, yf + 0.1, 0.5, 2.62, WOOD_D, 5),
        bar((-1.5, yf - 0.02, 2.85), (-0.7, yf - 0.02, 3.95), 0.12, WOOD_D, 6),
        bar((1.6, yf - 0.02, 2.85), (0.8, yf - 0.02, 3.95), 0.12, WOOD_D, 7),
    )
    roof = gable_roof(-D - 0.55, D + 0.45, 4.98, 2.5, W + 0.14, col=TEAL, seed=3)
    roof.warp(lambda p: Vector((p.x + 0.04 * math.sin(p.y * 1.3), p.y, p.z)))
    ch = merge(
        F.chunk(1.25, 0.7, 3.5, 4.45, 0.66, 0.6, seed=2, n=4, sq=0.9, taper=0.92, jit=0.04)[0],
        F.chunk(1.31, 0.7, 4.35, 5.15, 0.58, 0.54, seed=5, n=4, sq=0.9, taper=0.93, jit=0.04, off=(0.07, 0.0))[0],
        F.chunk(1.42, 0.72, 5.05, 5.62, 0.52, 0.5, seed=8, n=4, sq=0.9, taper=0.95, jit=0.04, off=(0.08, 0.02))[0],
        F.chunk(1.52, 0.74, 5.6, 5.74, 0.7, 0.66, seed=9, n=4, sq=0.9, taper=0.9, jit=0.03)[0],
    )
    P(ch, STONE, 4, var=0.08)
    pot = P(stack([(5.72, 0.15, 0.15), (5.98, 0.12, 0.12)], 6).move(1.52, 0.74, 0), CORAL, 2)
    dr = door(0.9, 1.7, seed=1).move(-0.85, yf - 0.02, 0.42)
    step = P(F.block(-1.5, -0.2, -D - 0.8, -D - 0.1, 0.0, 0.32, seed=3, j=0.03, chips=(4,), chip=0.12), STONE, 6, var=0.06, top=F.STONE_L)
    awn = F.hull([(-1.5, yf, 2.5), (-0.2, yf, 2.5), (-1.55, yf - 0.7, 2.18), (-0.15, yf - 0.7, 2.18),
                  (-1.5, yf, 2.42), (-0.2, yf, 2.42), (-1.55, yf - 0.7, 2.12), (-0.15, yf - 0.7, 2.12)])
    P(awn, MUSTARD, 3, var=0.04)
    awn_b = merge(bar((-1.45, yf, 1.95), (-1.5, yf - 0.66, 2.14), 0.05, WOOD_D, 1), bar((-0.25, yf, 1.95), (-0.2, yf - 0.66, 2.14), 0.05, WOOD_D, 2))
    w1 = round_window(0.36, seed=1).move(1.15, yf, 1.68)
    w2 = round_window(0.40, seed=3).move(0.05, yf - 0.02, 3.45)
    w3 = round_window(0.34, seed=5).rot('Z', 90).move(W + 0.1, 0.2, 1.7)
    fbox = plank(0.62, 1.68, yf - 0.34, yf - 0.02, 0.95, 1.17, WOOD, 9)
    green = F.leafy(F.blob(0.2, (2.4, 0.7, 0.6), (1.15, yf - 0.18, 1.22), seed=3, mat='vcol'), seed=2)
    fl = flower_dots([(0.78, yf - 0.2, 1.36, F.PINK), (1.05, yf - 0.24, 1.38, CREAM), (1.3, yf - 0.18, 1.37, F.PINK), (1.55, yf - 0.22, 1.34, MUSTARD)], 2)
    lamp = merge(bar((-0.08, yf, 2.2), (-0.08, yf - 0.3, 2.26), 0.05, IRON, 4), lantern((-0.08, yf - 0.28, 1.76), 1.0, rope=0.06))
    g = merge(base, quoins, walls, beams, roof, ch, pot, dr, step, awn, awn_b, w1, w2, w3, fbox, green, fl, lamp)
    g.add(F.tuft([(2.5, -1.6, 0.34, 0.07, 20, 0.1, True), (2.62, -1.48, 0.22, 0.06, 80, 0.07, False), (-2.5, -1.7, 0.28, 0.06, -30, 0.08, True)], seed=3))
    return finish(g, zmax=5.0)


@kit.prop('cottage_b', collider=('box', 4.4, 3.6, 3.2), tags=['building', 'cottage'],
          light=dict(color='#ffc46b', energy=1.2, height=1.8, range=5.0, offset=[0.2, -2.0]))
def cottage_b():
    # sobrado de pedra e reboco, telhado coral com agua-furtada, puxadinho de pano e chamine por fora
    W, D = 1.9, 1.6
    yf = -D - 0.04
    ground = P(F.block(-W, W, -D, D, 0.0, 2.25, seed=2, j=0.03), STONE, 1, var=0.05)
    quoins = merge(*[P(F.block(sx * W - 0.24 + sx * 0.05, sx * W + 0.24 + sx * 0.05, -D - 0.08, -D + 0.2, z, z + 0.4, seed=4 + i, j=0.02, bevel=0.04), STONE, 5 + i, var=0.1)
                     for i, (sx, z) in enumerate(((-1, 0.0), (-1, 0.82), (-1, 1.6), (1, 0.42), (1, 1.22)))])
    jetty = plank(-W - 0.2, W + 0.2, -D - 0.22, D + 0.2, 2.2, 2.4, WOOD_D, 3)
    up = F.hull([(sx * (W + 0.12), sy * (D + 0.14), 2.38) for sx in (-1, 1) for sy in (-1, 1)]
                + [(sx * (W + 0.18), sy * (D + 0.2), 3.5) for sx in (-1, 1) for sy in (-1, 1)] + [(sx * (W + 0.18), 0.0, 5.0) for sx in (-1, 1)])
    P(up, PLASTER, 4, var=0.03)
    yu = -D - 0.2
    beams = merge(plank(-W - 0.26, -W - 0.04, yu - 0.06, yu + 0.1, 2.4, 3.5, WOOD_D, 1), plank(W + 0.04, W + 0.26, yu - 0.06, yu + 0.1, 2.4, 3.5, WOOD_D, 2),
                  plank(0.25, 0.4, yu - 0.06, yu + 0.1, 2.4, 3.5, WOOD_D, 3), bar((-W, yu - 0.02, 2.5), (-0.2 - 1.0, yu - 0.02, 3.4), 0.12, WOOD_D, 4))
    roof = gable_roof(-W - 0.55, W + 0.6, 5.28, 3.3, D + 0.2, col=CORAL, seed=7, over=0.45).rot('Z', 90)
    # agua-furtada
    dx = -0.6
    dorm = F.hull([(dx - 0.55, -2.0, 3.55), (dx + 0.55, -2.0, 3.55), (dx - 0.55, -0.7, 3.55), (dx + 0.55, -0.7, 3.55),
                   (dx - 0.55, -2.0, 4.3), (dx + 0.55, -2.0, 4.3), (dx - 0.55, -0.4, 4.3), (dx + 0.55, -0.4, 4.3), (dx, -2.0, 4.85), (dx, -0.2, 4.85)])
    P(dorm, PLASTER, 6, var=0.03)
    dr_ = Geo()
    for sx in (-1, 1):
        dr_.add(F.hull([(dx, -2.2, 4.98), (dx, -0.1, 4.98), (dx + sx * 0.8, -2.2, 4.2), (dx + sx * 0.8, -0.5, 4.2),
                        (dx, -2.2, 4.86), (dx, -0.1, 4.86), (dx + sx * 0.8, -2.2, 4.1), (dx + sx * 0.8, -0.5, 4.1)]))
    P(dr_, mul(CORAL, (0.92, 0.92, 0.98)), 8, var=0.08)
    wd = round_window(0.3, seed=2).move(dx, -2.02, 4.12)
    dr = door(0.9, 1.7, seed=4, col=TEAL).move(0.85, yf - 0.02, 0.12)
    step = P(F.block(0.25, 1.45, -D - 0.7, -D - 0.05, 0.0, 0.14, seed=3, j=0.03, chips=(5,), chip=0.12), F.STONE, 6, var=0.06, top=F.STONE_L)
    w1 = round_window(0.36, seed=6).move(-0.85, yf, 1.3)
    # janela de cima com folhas de madeira verde-agua
    pane = box(0.6, 0.04, 0.7, 'glow', center=(1.1, yu - 0.02, 2.98))
    pane.color(AMBER).grad('z', 2.6, 3.35, (1.0, 0.7, 0.45), (1.0, 1.0, 0.92))
    sh = merge(plank(0.5, 0.78, yu - 0.1, yu - 0.03, 2.58, 3.38, TEAL, 1, j=0.01), plank(1.42, 1.7, yu - 0.1, yu - 0.03, 2.58, 3.38, TEAL, 2, j=0.01),
               plank(0.74, 1.46, yu - 0.12, yu + 0.02, 2.5, 2.6, WOOD_D, 3, j=0.01), plank(1.07, 1.13, yu - 0.07, yu - 0.03, 2.6, 3.36, WOOD_D, 4, j=0.0))
    # chamine externa torta
    cx = W + 0.28
    ch = merge(
        F.chunk(cx, 0.3, 0.0, 2.5, 0.8, 0.95, seed=2, n=4, sq=0.9, taper=0.82, jit=0.04)[0],
        F.chunk(cx, 0.3, 2.4, 4.3, 0.62, 0.66, seed=5, n=4, sq=0.9, taper=0.9, jit=0.04, off=(0.06, 0.0))[0],
        F.chunk(cx + 0.08, 0.32, 4.2, 5.7, 0.54, 0.56, seed=8, n=4, sq=0.9, taper=0.92, jit=0.04, off=(0.16, 0.03))[0],
        F.chunk(cx + 0.26, 0.36, 5.68, 5.84, 0.74, 0.74, seed=9, n=4, sq=0.9, taper=0.9, jit=0.03)[0],
    )
    P(ch, STONE, 9, var=0.08)
    pot = P(stack([(5.82, 0.15, 0.15), (6.06, 0.12, 0.12)], 6).move(cx + 0.26, 0.36, 0), TEAL, 2)
    # puxadinho: toldo mostarda em dois paus, barril e caixote
    xs = -W - 1.15
    cloth = F.hull([(-W, -1.2, 2.05), (-W, 0.9, 2.05), (xs, -1.25, 1.62), (xs, 0.95, 1.62), (-W, -1.2, 1.98), (-W, 0.9, 1.98), (xs, -1.25, 1.56), (xs, 0.95, 1.56)])
    P(cloth, MUSTARD, 5, var=0.05)
    posts = merge(bar((xs + 0.08, -1.15, 0.0), (xs + 0.1, -1.15, 1.6), 0.1, WOOD, 1), bar((xs + 0.08, 0.85, 0.0), (xs + 0.06, 0.85, 1.6), 0.1, WOOD, 2))
    barrel = stack([(0.0, 0.3, 0.3), (0.4, 0.37, 0.37), (0.8, 0.3, 0.3)], 8).flat().move(-W - 0.5, 0.35, 0)
    P(barrel, WOOD, 3, var=0.08, top=WOOD_D)
    hoop = merge(stack([(0.2, 0.355, 0.355), (0.27, 0.365, 0.365)], 8, cap_a=False, cap_b=False), stack([(0.55, 0.36, 0.36), (0.62, 0.35, 0.35)], 8, cap_a=False, cap_b=False))
    P(hoop.flat().move(-W - 0.5, 0.35, 0), IRON, 1)
    crate = plank(-W - 0.85, -W - 0.25, -1.0, -0.45, 0.0, 0.45, WOOD_L, 6, j=0.02, bevel=0.03).rot('Z', 12, (-W - 0.55, -0.7, 0))
    lamp = merge(bar((0.2, yf, 2.02), (0.2, yf - 0.3, 2.08), 0.05, IRON, 4), lantern((0.2, yf - 0.28, 1.58), 1.0, rope=0.06))
    g = merge(ground, quoins, jetty, up, beams, roof, dorm, dr_, wd, dr, step, w1, pane, sh, ch, pot, cloth, posts, barrel, hoop, crate, lamp)
    g.add(F.tuft([(-2.1, -1.75, 0.3, 0.07, 20, 0.1, True), (-2.22, -1.66, 0.2, 0.06, 80, 0.07, False), (1.75, -1.8, 0.26, 0.06, -30, 0.08, True)], seed=5))
    return finish(g, zmax=5.2)


@kit.prop('tent', collider=('cyl', 2.0, 3.0), tags=['building', 'tent'])
def tent():
    # barraca grande de listras mostarda e creme, entrada aberta, flamula coral
    n = 8
    body = stack([(0.0, 1.85, 1.85), (1.45, 1.95, 1.95), (1.52, 2.12, 2.12), (2.3, 0.95, 0.95), (3.2, 0.12, 0.12)], n, cap_a=False, phase=0.5)

    def stripes(nr, cen, c):
        k = int(((math.atan2(cen.y, cen.x) % TAU) / TAU) * n + 0.001) % 2
        col = MUSTARD if k else CREAM
        return mul(col, (0.86, 0.84, 0.95)) if cen.z < 1.5 else col
    F.facet(body, fn=stripes, var=0.03, seed=1, sun=0.10)
    ya = -1.9 * math.cos(math.pi / 8) - 0.02
    hole = poly_extrude([(-0.55, 0.0), (0.55, 0.0), (0.12, 1.36), (-0.12, 1.36)], 0.05).color(DARK).move(0, ya, 0)
    fl_l = P(poly_extrude([(-0.82, 0.0), (-0.5, 0.0), (-0.02, 1.42), (-0.2, 1.3)], 0.05), mul(CREAM, (0.9, 0.86, 0.9)), 2).move(0, ya - 0.04, 0)
    fl_r = P(poly_extrude([(0.5, 0.0), (0.86, 0.0), (0.22, 1.28), (0.02, 1.42)], 0.05), mul(CREAM, (0.94, 0.9, 0.92)), 3).move(0, ya - 0.04, 0)
    val = Geo()
    pts = ring_pts(n, 2.14, 2.14, 0.0, 0.5)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        for k in range(2):
            p0 = (a[0] + (b[0] - a[0]) * k / 2, a[1] + (b[1] - a[1]) * k / 2)
            p1 = (a[0] + (b[0] - a[0]) * (k + 1) / 2, a[1] + (b[1] - a[1]) * (k + 1) / 2)
            idx = [val.add_vert((p0[0], p0[1], 1.52), None, TEAL), val.add_vert(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, 1.22), None, mul(TEAL, (0.8, 0.85, 0.95))),
                   val.add_vert((p1[0], p1[1], 1.52), None, TEAL)]
            val.add_face(idx, 'vcol_wind', False)
            val.add_face(tuple(reversed(idx)), 'vcol_wind', False)
    pole = P(stack([(3.15, 0.05, 0.05), (3.8, 0.035, 0.035)], 5).flat(), WOOD_D, 1)
    flag = Geo()
    idx = [flag.add_vert((0.03, 0, 3.76), None, CORAL), flag.add_vert((0.72, 0.05, 3.6), None, mul(CORAL, (1.1, 1.0, 0.9))), flag.add_vert((0.03, 0, 3.42), None, mul(CORAL, (0.85, 0.8, 0.9)))]
    flag.add_face(idx, 'vcol_wind', False)
    flag.add_face(tuple(reversed(idx)), 'vcol_wind', False)
    ropes = Geo()
    for k in (0, 3, 4, 7):
        a = pts[k]
        d = math.hypot(*a)
        gx, gy = a[0] / d * 2.75, a[1] / d * 2.75
        ropes.add(tube([(a[0], a[1], 1.5), (gx, gy, 0.05)], 0.016, 3, cap_a=False, cap_b=False).flat().color(mul(CREAM, (0.7, 0.66, 0.7))))
        ropes.add(P(F.spike((gx, gy, 0.0), (gx + a[0] / d * 0.08, gy + a[1] / d * 0.08, 0.22), 0.035, 0.3, None, 1.0, 4, 'vcol'), WOOD_D, k))
    g = merge(body, hole, fl_l, fl_r, val, pole, flag, ropes)
    return finish(g, zmax=3.4, strength=0.5)


# =========================================================================== MARCO
LANTERNS = [(-2.6, -0.5, 3.3, 4.9), (-1.3, -1.25, 2.85, 4.85), (0.55, -2.2, 3.2, 4.7), (1.7, -1.0, 2.7, 5.2), (2.95, -0.6, 3.5, 5.2), (-0.45, -1.95, 3.75, 4.7)]


@kit.prop('lantern_tree', collider=('cyl', 1.3, 3.0), tags=['landmark', 'tree'],
          light=dict(color='#ffc46b', energy=2.4, height=3.2, range=12.0), lanterns=[[x, y, z + 0.15] for x, y, z, _ in LANTERNS])
def lantern_tree():
    # a arvore grande da praca: tronco gordo, copa quente, lampioes pendurados e um anel de pedras
    wood = merge(
        F.limb([(0, 0, -0.1), (0.12, 0, 1.0), (-0.15, 0.05, 2.3), (0.05, 0, 3.6)], [1.05, 0.74, 0.62, 0.48], 8),
        F.limb([(-0.1, 0, 2.4), (-1.1, 0.05, 3.6), (-2.1, 0.1, 4.7)], [0.36, 0.28, 0.15], 6),
        F.limb([(0.0, 0, 2.6), (1.1, -0.1, 3.8), (2.2, -0.2, 4.9)], [0.36, 0.27, 0.15], 6),
        F.limb([(0.0, 0, 3.4), (0.15, 0.2, 4.6), (0.2, 0.3, 5.6)], [0.4, 0.28, 0.16], 6),
        F.limb([(0.0, -0.2, 2.5), (0.35, -1.0, 3.6), (0.6, -1.6, 4.3)], [0.28, 0.2, 0.12], 5),
        F.roots(0.9, 5, seed=4, length=1.0, h=0.9, n=5),
    )
    F.bark(wood, seed=5, z0=0, z1=5.0, c0=H('#7a5248'), c1=WOOD)
    crown = merge(F.blob(2.1, (1.25, 1.1, 0.72), (0.1, 0.1, 6.5), seed=61), F.blob(1.6, (1.2, 1.05, 0.72), (-2.3, 0.0, 5.3), seed=62),
                  F.blob(1.6, (1.2, 1.05, 0.72), (2.4, -0.2, 5.6), seed=63), F.blob(1.3, (1.2, 1.0, 0.70), (0.6, -1.5, 5.0), seed=64),
                  F.blob(1.1, (1.1, 1.0, 0.75), (-1.0, 0.3, 7.2), seed=65))
    F.leafy(crown, dark=H('#2e8f77'), mid=H('#4fb070'), light=H('#a6d86a'), deep=H('#236f6c'), seed=6)
    lamps = Geo()
    for i, (x, y, z, zt) in enumerate(LANTERNS):
        lamps.add(lantern((x, y, z), 1.25 if i % 2 else 1.05, rope=zt - z - 0.4))
    ringg = Geo()
    for i in range(9):
        a = TAU * i / 9 + 0.2
        st = F.boulder(0.36, 0.27, 0.3 + 0.06 * (i % 3), seed=20 + i, n=6, top_r=0.6).rot('Z', math.degrees(a) + 90)
        ringg.add(st.move(math.cos(a) * 1.85, math.sin(a) * 1.85, 0))
    F.stone_paint(ringg, seed=3, moss=F.MOSS, z0=0, z1=0.45)
    soil = P(lathe([(1.85, 0.12), (0.6, 0.2)], 9, smooth=False), SOIL, 2, var=0.05)
    fl = flower_dots([(1.3, -0.6, 0.3, F.PINK), (1.0, -1.1, 0.3, CREAM), (-1.2, -0.8, 0.3, MUSTARD), (-0.4, -1.4, 0.3, F.PINK), (0.4, -1.45, 0.28, BLUE),
                      (-1.45, 0.2, 0.28, CREAM)], 4)
    g = merge(wood, crown, ringg, soil, fl, lamps)
    g.add(F.tuft([(1.2, -0.9, 0.3, 0.06, 0, 0.08, True), (-0.9, -1.2, 0.26, 0.06, 60, 0.08, True), (0.0, -1.5, 0.2, 0.05, -40, 0.06, False)], seed=2).move(0, 0, 0.14))
    return finish(g, zmax=6.0, dist=1.2)


# =========================================================================== PRACA
@kit.prop('well', collider=('cyl', 1.0, 2.9), tags=['well'])
def well():
    n = 10

    def ring(r, z):
        return [(math.cos(TAU * i / n) * r, math.sin(TAU * i / n) * r, z) for i in range(n)]
    wall = loft([ring(0.92, 0.0), ring(0.86, 0.66), ring(0.95, 0.70), ring(0.95, 0.82), ring(0.62, 0.82), ring(0.62, 0.40)], cap_a=False, cap_b=False, smooth=False)

    def fn(nr, cen, c):
        k = int(((math.atan2(cen.y, cen.x) % TAU) / TAU) * n) % 3
        return mul(c, (1.0, 1.0, 1.0) if k == 0 else ((0.9, 0.9, 0.96) if k == 1 else (1.04, 0.98, 0.98)))
    F.facet(wall, STONE, F.STONE_L, top_n=0.7, var=0.05, seed=2, fn=fn)
    water = Geo()
    c = water.add_vert((0, 0, 0.42), None, H('#4fc3d9'))
    rg = [water.add_vert(p, None, H('#2a7fa8')) for p in ring(0.62, 0.42)]
    for i in range(n):
        water.add_face((c, rg[i], rg[(i + 1) % n]), 'water', False)
    posts = merge(plank(-0.98, -0.82, -0.09, 0.09, 0.0, 2.4, WOOD_D, 1), plank(0.82, 0.98, -0.09, 0.09, 0.0, 2.4, WOOD_D, 2))
    roller = P(tube([(-0.9, 0, 1.7), (0.9, 0, 1.7)], 0.07, 6).flat(), WOOD, 3)
    crank = merge(bar((0.98, 0, 1.7), (1.14, 0, 1.7), 0.05, IRON, 1), bar((1.14, 0, 1.7), (1.14, 0.0, 1.42), 0.05, IRON, 2), bar((1.14, 0, 1.42), (1.32, 0, 1.42), 0.05, IRON, 3))
    rope = tube([(0.15, 0, 1.7), (0.15, 0.0, 1.05)], 0.02, 3, cap_a=False, cap_b=False).flat().color(mul(CREAM, (0.7, 0.66, 0.7)))
    wrap = P(stack([(-0.14, 0.095, 0.095), (0.14, 0.095, 0.095)], 6).flat().rot('Y', 90).move(0.12, 0, 1.7), mul(CREAM, (0.8, 0.76, 0.78)), 2)
    bucket = P(stack([(0.0, 0.13, 0.13), (0.28, 0.17, 0.17)], 7).flat(), WOOD_L, 4, top=DARK)
    bucket.move(0.15, 0, 0.8)
    roof = gable_roof(-0.72, 0.72, 3.05, 2.3, 0.92, col=TEAL, seed=11, over=0.3, ny=2, nu=2, th=0.1, sag=0.05, kick=0.08)
    for sy in (-1, 1):
        roof.add(P(poly_extrude([(-0.98, 2.26), (0.98, 2.26), (0.0, 2.98)], 0.07), WOOD, 5 + sy, var=0.06).move(0, sy * 0.5, 0))
    g = merge(wall, water, posts, roller, crank, rope, wrap, bucket, roof)
    g.add(F.tuft([(0.9, -0.5, 0.3, 0.06, 20, 0.09, True), (1.0, -0.38, 0.2, 0.05, 80, 0.06, False), (-0.95, 0.4, 0.24, 0.05, 200, 0.07, False)], seed=1))
    return finish(g, zmax=3.0)


def _post(h=1.12, w=0.16, seed=0, lean=(0.0, 0.0), col=WOOD):
    """Mourao de cerca: afina para cima e termina em ponta lascada."""
    rnd = random.Random(seed)
    k = w / 2
    pts = [(sx * k, sy * k, -0.02) for sx in (-1, 1) for sy in (-1, 1)]
    pts += [(sx * k * 0.86 + lean[0], sy * k * 0.86 + lean[1], h - 0.12 + rnd.uniform(-0.02, 0.02)) for sx in (-1, 1) for sy in (-1, 1)]
    pts += [(sx * k * 0.3 + lean[0] * 1.1, sy * k * 0.3 + lean[1] * 1.1, h) for sx in (-1, 1) for sy in (-1, 1)]
    g = F.hull(pts)
    g.rot('Z', rnd.uniform(-12, 12))
    g.color(WHITE).grad('z', 0, h, (0.72, 0.68, 0.85), WHITE)
    return P(g, col, seed, var=0.07)


@kit.prop('fence', collider=('box', 2.0, 0.25, 1.0), tags=['fence'])
def fence():
    # um mourao na ponta esquerda + duas travessas tortas; feche a fileira com fence_post
    g = merge(
        _post(1.12, 0.17, seed=1, lean=(0.02, 0.01)).move(-1.0, 0, 0),
        _post(0.86, 0.11, seed=4, lean=(-0.03, 0.0), col=WOOD_L).move(0.08, 0.05, 0),
        P(tube([(-1.02, -0.07, 0.80), (0.0, -0.05, 0.75), (1.02, -0.08, 0.83)], 0.05, 4, phase=0.5).flat(), WOOD_L, 2, var=0.07),
        P(tube([(-1.02, -0.08, 0.40), (0.1, -0.06, 0.44), (1.02, -0.07, 0.38)], 0.048, 4, phase=0.5).flat(), WOOD, 3, var=0.07),
    )
    g.add(F.tuft([(-0.85, -0.12, 0.26, 0.05, 10, 0.07, True), (-0.75, -0.08, 0.16, 0.05, 80, 0.05, False)], seed=1))
    return finish(g, zmax=1.4, strength=0.5, dist=0.4)


@kit.prop('fence_post', collider=('cyl', 0.13, 1.1), tags=['fence_post'])
def fence_post():
    return finish(_post(1.12, 0.17, seed=7, lean=(-0.02, 0.01)), zmax=1.4, strength=0.5, dist=0.4)


@kit.prop('lamp_post', collider=('cyl', 0.16, 3.0), tags=['lamp_post', 'light'],
          light=dict(color='#ffc46b', energy=2.0, height=2.45, range=8.0, offset=[0.62, 0.0]))
def lamp_post():
    post = P(tube([(0, 0, -0.05), (0.02, 0, 1.4), (-0.03, 0, 2.6), (0.0, 0, 3.05)], [0.115, 0.095, 0.08, 0.07], 5).flat(), WOOD_D, 1, var=0.07)
    arm = P(tube([(0.0, 0, 2.7), (0.28, 0, 2.96), (0.55, 0, 2.94), (0.62, 0, 2.78)], 0.035, 4, phase=0.5).flat(), IRON, 2)
    brace = bar((0.0, 0, 2.35), (0.3, 0, 2.9), 0.045, IRON, 3)
    topc = P(lathe([(0.11, 3.03), (0.13, 3.1), (0.0, 3.2)], 5, smooth=False), WOOD, 4)
    stones = merge(F.boulder(0.2, 0.17, 0.18, seed=3, n=5, top_r=0.6).move(0.16, -0.1, 0), F.boulder(0.16, 0.14, 0.14, seed=5, n=5, top_r=0.6).move(-0.16, 0.06, 0),
                   F.boulder(0.13, 0.12, 0.1, seed=8, n=5, top_r=0.6).move(0.02, 0.2, 0))
    F.stone_paint(stones, seed=2, z0=0, z1=0.3)
    g = merge(post, arm, brace, topc, stones, lantern((0.62, 0, 2.26), 1.35, rope=0.06))
    return finish(g, zmax=3.2, strength=0.5, dist=0.4)


@kit.prop('gate', collider=None, tags=['gate'], posts=[[-1.55, 0.0], [1.55, 0.0]], post_r=0.26, clear_w=2.6,
          light=dict(color='#ffc46b', energy=1.6, height=2.4, range=7.0))
def gate():
    # portal de madeira: dois moirões grossos, viga arqueada com telhadinho, placa e dois lampioes
    g = Geo()
    for sx, sd in ((-1, 1), (1, 2)):
        x = sx * 1.55
        g.add(P(F.hull([(x + a * 0.2, b * 0.2, 0.25) for a in (-1, 1) for b in (-1, 1)] + [(x + a * 0.16 + sx * 0.03, b * 0.16, 3.05) for a in (-1, 1) for b in (-1, 1)]), WOOD, sd, var=0.07))
        foot = F.chunk(x, 0, 0.0, 0.4, 0.66, 0.62, seed=sd + 3, n=6, taper=0.8, jit=0.06, sq=0.4)[0]
        g.add(F.stone_paint(F.nofloor(foot), seed=sd, z0=0, z1=0.45))
        g.add(bar((x, 0, 2.15), (sx * 0.85, 0, 2.62), 0.11, WOOD_D, sd))
        g.add(lantern((sx * 2.05, 0, 2.2), 1.25, rope=0.3))
    g.add(P(tube([(-2.3, 0, 3.0), (-1.0, 0, 3.22), (0, 0, 3.3), (1.0, 0, 3.22), (2.3, 0, 2.98)], 0.16, 4, phase=0.5).flat(), WOOD_D, 3, var=0.06))
    g.add(P(tube([(-1.6, 0, 2.62), (0.0, 0, 2.66), (1.6, 0, 2.6)], 0.1, 4, phase=0.5).flat(), WOOD, 4, var=0.06))
    g.add(gable_roof(-2.45, 2.45, 3.72, 3.44, 0.3, col=TEAL, seed=4, over=0.22, ny=4, nu=2, th=0.08, sag=-0.14, kick=0.05).rot('Z', 90))
    sign = plank(-0.5, 0.5, -0.04, 0.04, 1.86, 2.36, WOOD_L, 5, j=0.02, chips=(4,), chip=0.08)
    sign.add(tube([(-0.38, 0, 2.36), (-0.38, 0, 2.62)], 0.014, 3, cap_a=False, cap_b=False).flat().color(IRON))
    sign.add(tube([(0.38, 0, 2.36), (0.38, 0, 2.62)], 0.014, 3, cap_a=False, cap_b=False).flat().color(IRON))
    for sy in (-1, 1):
        star = F._head(0.17, 4, F.LUMEN, WHITE, droop=0.0, mat='glow', notch=0.34)
        star.fm = ['glow'] * len(star.fm)
        sign.add(star.rot('X', 90 * sy).move(0, sy * -0.055, 2.11))
    g.add(sign)
    return finish(g, zmax=3.6, dist=0.5)


def _crate(sx, sy, sz, seed=0, col=WOOD):
    hx, hy = sx / 2, sy / 2
    g = P(F.block(-hx, hx, -hy, hy, 0.0, sz * 0.86, seed=seed, j=0.012), col, seed, var=0.07, top=mul(SOIL, (0.8, 0.8, 0.9)))
    for ax in (-1, 1):
        for ay in (-1, 1):
            g.add(plank(ax * hx - 0.035, ax * hx + 0.035, ay * hy - 0.035, ay * hy + 0.035, 0.0, sz, WOOD_D, seed + 3, j=0.006))
    g.add(plank(-hx - 0.01, hx + 0.01, -hy - 0.02, -hy + 0.01, sz * 0.52, sz * 0.92, WOOD_L, seed + 5, j=0.008))
    g.add(plank(-hx - 0.01, hx + 0.01, hy - 0.01, hy + 0.02, sz * 0.52, sz * 0.92, WOOD_L, seed + 6, j=0.008))
    return g


def _fruit(x, y, z, r, col, seed=0):
    g = lp.icosphere(r, 0, 'vcol', jitter=0.06, seed=seed).scale(1.0, 1.0, 0.9)
    g.rot('Z', seed * 37.0).rot('X', seed * 11.0)
    g.color(col).grad('z', -r, r, (0.7, 0.66, 0.85), (1.1, 1.06, 1.0))
    F.facet(g, var=0.06, seed=seed, sun=0.1)
    return g.move(x, y, z)


@kit.prop('market_crates', collider=('box', 1.7, 1.1, 0.9), tags=['market_crates', 'market'])
def market_crates():
    APPLE, ORANGE, MELON = CORAL, H('#f59a3c'), H('#58b58a')
    a = _crate(0.78, 0.56, 0.42, 1)
    for i, (x, y) in enumerate(((-0.2, -0.1), (0.08, -0.12), (0.26, 0.1), (-0.06, 0.12), (-0.28, 0.14))):
        a.add(_fruit(x, y, 0.43, 0.125, APPLE if i != 2 else H('#f0c05a'), i + 1))
    a.rot('Z', -8).move(-0.42, -0.1, 0)
    b = _crate(0.7, 0.52, 0.4, 2, col=WOOD_L)
    for i, (x, y) in enumerate(((-0.18, -0.08), (0.12, -0.1), (0.2, 0.12), (-0.08, 0.13))):
        b.add(_fruit(x, y, 0.42, 0.135, ORANGE, i + 7))
    b.rot('X', 24).rot('Z', 14).move(0.42, -0.12, 0.1)
    c = _crate(0.62, 0.5, 0.36, 3)
    for i, (x, y) in enumerate(((-0.12, 0.0), (0.14, 0.03))):
        c.add(_fruit(x, y, 0.42, 0.19, MELON, i + 12))
    c.rot('Z', 20).move(0.4, 0.42, 0)
    prop = plank(0.2, 0.7, 0.05, 0.3, 0.0, 0.2, WOOD_D, 4, j=0.02)
    loose = merge(_fruit(-0.1, -0.52, 0.11, 0.12, APPLE, 21), _fruit(0.95, -0.42, 0.12, 0.13, ORANGE, 22))
    return finish(merge(a, b, c, prop, loose), zmax=1.0, strength=0.6, dist=0.35)


def wheel(r=0.42, w=0.09, n=10):
    g = stack([(-w / 2, r, r), (w / 2, r, r)], n)
    hub = stack([(-w / 2 - 0.05, 0.1, 0.1), (w / 2 + 0.05, 0.1, 0.1)], 6, phase=0.3)

    def fn(nr, cen, c):
        if abs(nr.z) > 0.7:
            k = int(((math.atan2(cen.y, cen.x) % TAU) / TAU) * n) % 2
            return WOOD_L if k else WOOD
        return WOOD_D
    F.facet(g, fn=fn, var=0.04, seed=1, sun=0.0, under=WHITE)
    P(hub, IRON, 2)
    return merge(g, hub).rot('X', 90)


@kit.prop('cart', collider=('box', 2.7, 1.3, 1.0), tags=['cart'])
def cart():
    bed = plank(-0.95, 0.8, -0.5, 0.5, 0.52, 0.62, WOOD, 1)
    sides = merge(plank(-0.98, 0.83, -0.56, -0.5, 0.6, 0.96, WOOD_L, 2).rot('X', 8, (0, -0.5, 0.6)), plank(-0.98, 0.83, 0.5, 0.56, 0.6, 0.96, WOOD_L, 3).rot('X', -8, (0, 0.5, 0.6)),
                  plank(-1.0, -0.94, -0.54, 0.54, 0.6, 0.98, WOOD, 4), plank(0.78, 0.84, -0.54, 0.54, 0.6, 0.86, WOOD, 5))
    wh = merge(wheel().move(-0.1, -0.66, 0.42), wheel().rot('Y', 40).move(-0.1, 0.66, 0.42))
    axle = bar((-0.1, -0.72, 0.42), (-0.1, 0.72, 0.42), 0.08, WOOD_D, 6)
    handles = merge(bar((0.8, -0.4, 0.57), (1.75, -0.44, 0.74), 0.07, WOOD_D, 7), bar((0.8, 0.4, 0.57), (1.75, 0.44, 0.74), 0.07, WOOD_D, 8),
                    bar((1.68, -0.5, 0.73), (1.68, 0.5, 0.73), 0.06, WOOD, 9), bar((0.7, 0.0, 0.52), (0.82, 0.0, 0.0), 0.08, WOOD_D, 10))
    sack1 = F.blob(0.3, (1.0, 0.9, 0.8), (-0.55, -0.1, 0.84), seed=3, mat='vcol', floor=-0.5)
    sack2 = F.blob(0.26, (1.0, 0.9, 0.85), (-0.1, 0.16, 0.82), seed=5, mat='vcol', floor=-0.5)
    sacks = P(merge(sack1, sack2), mul(CREAM, (0.92, 0.86, 0.8)), 4, var=0.05)
    load = merge(_fruit(0.36, -0.2, 0.78, 0.2, H('#f59a3c'), 3), _fruit(0.5, 0.18, 0.74, 0.16, H('#f0c05a'), 4), _fruit(0.14, 0.3, 0.72, 0.12, CORAL, 6))
    g = merge(bed, sides, wh, axle, handles, sacks, load)
    g.rot('Y', -3.0, (-0.1, 0, 0.42))
    return finish(g, zmax=1.2, strength=0.6, dist=0.4)


def _bale(sx, sy, sz, seed=0):
    g = F.block(-sx / 2, sx / 2, -sy / 2, sy / 2, 0.0, sz, seed=seed, j=0.02, chips=(0, 1, 2, 3, 4, 5, 6, 7), chip=0.07)
    P(g, STRAW, seed, var=0.09, top=mixc(STRAW, CREAM, 0.35))
    for x in (-sx * 0.25, sx * 0.25):
        g.add(P(F.block(x - 0.025, x + 0.025, -sy / 2 - 0.012, sy / 2 + 0.012, -0.0, sz + 0.012, seed=1, j=0.0), WOOD_D, 3))
    return g


@kit.prop('hay', collider=('box', 1.5, 1.0, 1.0), tags=['hay'])
def hay():
    a = _bale(1.15, 0.62, 0.5, 1).rot('Z', 6)
    b = _bale(1.0, 0.56, 0.46, 2).rot('Y', -9).rot('Z', -28).move(0.1, 0.02, 0.52)
    c = _bale(0.7, 0.5, 0.42, 3).rot('X', 62).rot('Z', 80).move(-0.72, 0.38, 0.12)
    straw = F.tuft([(0.5, -0.42, 0.26, 0.05, 20, 0.1, True), (0.62, -0.38, 0.16, 0.05, 80, 0.08, False), (-0.3, -0.42, 0.2, 0.05, -40, 0.1, False),
                    (0.72, 0.2, 0.2, 0.05, 150, 0.08, False)], seed=2, c0=mul(STRAW, (0.8, 0.75, 0.8)), c1=mixc(STRAW, CREAM, 0.4), mat='vcol')
    fork = merge(bar((0.82, -0.3, 0.0), (0.62, 0.05, 1.4), 0.05, WOOD_D, 1), bar((0.5, 0.0, 1.38), (0.74, 0.1, 1.42), 0.035, IRON, 2))
    for k in (-1, 0, 1):
        fork.add(bar((0.62 + k * 0.1, 0.05 + k * 0.045, 1.4), (0.58 + k * 0.11, 0.1 + k * 0.05, 1.68), 0.03, IRON, 3 + k))
    return finish(merge(a, b, c, straw, fork), zmax=1.2, strength=0.6, dist=0.4)


@kit.prop('flower_bed', collider=('box', 1.8, 0.75, 0.5), tags=['flower_bed'])
def flower_bed():
    g = merge(plank(-0.85, 0.85, -0.34, -0.28, 0.0, 0.34, WOOD, 1, j=0.02), plank(-0.85, 0.85, 0.28, 0.34, 0.0, 0.36, WOOD_L, 2, j=0.02),
              plank(-0.88, -0.82, -0.3, 0.3, 0.0, 0.33, WOOD_L, 3, j=0.02), plank(0.82, 0.88, -0.3, 0.3, 0.0, 0.35, WOOD, 4, j=0.02))
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        g.add(_post(0.46, 0.1, seed=10 + i, col=WOOD_D).move(sx * 0.86, sy * 0.32, 0))
    g.add(P(F.block(-0.82, 0.82, -0.28, 0.28, 0.2, 0.29, seed=2, j=0.01), SOIL, 3, var=0.05))
    green = merge(F.blob(0.2, (1.5, 1.0, 0.8), (-0.5, 0.02, 0.4), seed=3), F.blob(0.22, (1.4, 1.0, 0.8), (0.1, -0.02, 0.42), seed=5),
                  F.blob(0.18, (1.4, 1.0, 0.8), (0.6, 0.03, 0.39), seed=7))
    F.leafy(green, seed=4)
    g.add(green)
    g.add(flower_dots([(-0.68, -0.08, 0.56, F.PINK), (-0.42, 0.1, 0.6, CREAM), (-0.22, -0.1, 0.56, BLUE), (0.02, 0.08, 0.63, F.PINK), (0.24, -0.1, 0.6, MUSTARD),
                       (0.46, 0.08, 0.56, CREAM), (0.68, -0.06, 0.56, F.PINK), (0.74, 0.14, 0.52, BLUE)], 6))
    return finish(g, zmax=0.9, strength=0.55, dist=0.3)


@kit.prop('plaza_tile', collider=None, tags=['plaza_tile', 'tile'])
def plaza_tile():
    # 2 x 2 m de calcamento; as bordas fecham certinho em +-1 para ladrilhar
    rnd = random.Random(8)
    ys = [-1.0, -0.52, -0.04, 0.5, 1.0]
    cuts = [[-1.0, -0.3, 0.42, 1.0], [-1.0, -0.62, 0.05, 0.62, 1.0], [-1.0, -0.18, 0.3, 1.0], [-1.0, -0.5, 0.2, 0.72, 1.0]]
    nodes = {}

    def node(x, y):
        k = (round(x, 3), round(y, 3))
        if k not in nodes:
            jx = 0.0 if abs(x) > 0.999 else rnd.uniform(-0.04, 0.04)
            jy = 0.0 if abs(y) > 0.999 else rnd.uniform(-0.04, 0.04)
            nodes[k] = (x + jx, y + jy)
        return nodes[k]
    g = Geo()
    tones = [(1.0, 1.0, 1.0), (0.9, 0.9, 0.97), (1.06, 1.0, 0.99), (0.95, 0.98, 0.95), (1.0, 0.97, 1.02)]
    for r in range(4):
        y0, y1 = ys[r], ys[r + 1]
        for xa, xb in zip(cuts[r], cuts[r][1:]):
            poly = [node(xa, y0), node(xb, y0), node(xb, y1), node(xa, y1)]
            cx = sum(p[0] for p in poly) / 4
            cy = sum(p[1] for p in poly) / 4
            poly = [(x + (cx - x) / max(1e-6, math.hypot(cx - x, cy - y)) * 0.022, y + (cy - y) / max(1e-6, math.hypot(cx - x, cy - y)) * 0.022) for x, y in poly]
            s = F.slab(poly, th=rnd.uniform(0.04, 0.055), inset=0.035, z0=0.012)
            s.color(rnd.choice(tones))
            g.add(s)

    def fn(nr, cen, c):
        return mul(c, mixc(STONE, F.STONE_L, 0.3) if nr.z > 0.7 else F.STONE_D)
    F.facet(g, fn=fn, var=0.05, seed=3, sun=0.0, under=WHITE)
    basep = Geo()
    idx = [basep.add_vert(p, None, mul(SOIL, (0.9, 0.9, 1.0))) for p in ((-1, -1, 0.012), (1, -1, 0.012), (1, 1, 0.012), (-1, 1, 0.012))]
    basep.add_face(idx, 'vcol', False)
    return F.ao(merge(basep, g), 0.5, dist=0.12)


@kit.prop('bunting', collider=None, tags=['bunting'], attach=[[-2.0, 0.0, 0.85], [2.0, 0.0, 0.85]])
def bunting():
    # varal de bandeirinhas de 4 m; as pontas ficam em z = 0,85 (veja 'attach' no manifesto)
    n = 10
    sag = 0.42

    def pt(t):
        x = -2.0 + 4.0 * t
        return (x, 0.0, 0.85 - sag * (1.0 - (2 * t - 1) ** 2))
    g = tube([pt(i / n) for i in range(n + 1)], 0.014, 3, 'vcol_wind', cap_a=False, cap_b=False).flat().color(mul(CREAM, (0.72, 0.68, 0.74)))
    cols = [MUSTARD, CREAM, CORAL, TEAL]
    for i in range(9):
        t = (i + 0.72) / 10.0
        a, b = pt(t - 0.034), pt(t + 0.034)
        c = cols[i % 4]
        tip = ((a[0] + b[0]) / 2 + 0.01, 0.0, min(a[2], b[2]) - 0.3)
        idx = [g.add_vert(a, None, c), g.add_vert(tip, None, mul(c, (0.8, 0.78, 0.9))), g.add_vert(b, None, c)]
        g.add_face(idx, 'vcol_wind', False)
        g.add_face(tuple(reversed(idx)), 'vcol_wind', False)
    zmin = min(p.z for p in g.v)
    return F.ao(g.move(0, 0, 0.0 if zmin >= 0 else -zmin), 0.0, dist=0.1)


@kit.prop('stone_stairs', collider=None, tags=['stone_stairs'], ramp=dict(w=2.0, d=1.4, h=0.8))
def stone_stairs():
    # quatro degraus (sobe para +Y); sem colisor: use 'ramp' do manifesto para montar a rampa
    rnd = random.Random(3)
    g = Geo()
    for i in range(4):
        y0 = -0.7 + i * 0.35
        cutx = rnd.uniform(-0.35, 0.35)
        for xa, xb in ((-1.0, cutx), (cutx, 1.0)):
            b = F.block(xa, xb, y0, 0.72, 0.0, 0.2 * (i + 1), seed=rnd.randrange(999), j=0.015)
            k = rnd.uniform(-0.07, 0.06)
            g.add(b.color((1 + k * 1.2, 1 + k, 1 + k * 0.6)))
    for sx in (-1, 1):
        g.add(F.block(sx * 1.14 - 0.14, sx * 1.14 + 0.14, -0.78, 0.0, 0.0, 0.5, seed=5 + sx, j=0.02, chips=(4 if sx < 0 else 5,), chip=0.1).color((0.95, 0.95, 1.0)))
        g.add(F.block(sx * 1.14 - 0.14, sx * 1.14 + 0.14, 0.0, 0.74, 0.0, 1.0, seed=8 + sx, j=0.02, chips=(6,), chip=0.1).color((1.03, 1.01, 1.0)))
    F._wall_paint(g, 4, 1.0, moss=0.22)
    g.add(F.tuft([(1.34, -0.6, 0.26, 0.06, 20, 0.08, True), (1.4, -0.48, 0.18, 0.05, 80, 0.06, False), (-1.36, -0.2, 0.2, 0.05, 200, 0.06, False)], seed=2))
    return F.ao(g, 0.6, dist=0.4)


@kit.prop('mailbox', collider=('cyl', 0.2, 1.25), tags=['mailbox'])
def mailbox():
    post = _post(0.95, 0.12, seed=3, lean=(0.01, 0.0), col=WOOD_D)
    brace = bar((0.0, -0.02, 0.6), (0.0, -0.2, 0.92), 0.05, WOOD, 2)
    shelf = plank(-0.2, 0.2, -0.3, 0.22, 0.92, 0.97, WOOD, 4)
    prof = [(-0.17, 0.0), (0.17, 0.0), (0.17, 0.17), (0.12, 0.28), (0.0, 0.32), (-0.12, 0.28), (-0.17, 0.17)]
    body = P(poly_extrude(prof, 0.5), CORAL, 1, var=0.05).move(0, -0.04, 0.97)
    face = P(poly_extrude([(x * 0.8, z * 0.8 + 0.03) for x, z in prof], 0.03), CREAM, 2, var=0.03).move(0, -0.3, 0.97)
    slot = plank(-0.09, 0.09, -0.325, -0.31, 1.1, 1.13, IRON, 5, j=0.0)
    flag = merge(plank(0.17, 0.19, -0.02, 0.02, 1.05, 1.42, WOOD_D, 6, j=0.0), plank(0.17, 0.19, -0.02, 0.16, 1.3, 1.42, MUSTARD, 7, j=0.0))
    letter = plank(-0.07, 0.07, -0.42, -0.26, 1.12, 1.125, CREAM, 8, j=0.0).rot('X', 14, (0, -0.3, 1.12))
    g = merge(post, brace, shelf, body, face, slot, flag, letter)
    g.rot('Y', 3).rot('Z', -8)
    g.add(flower_dots([(0.18, -0.12, 0.16, F.PINK), (-0.16, -0.16, 0.12, CREAM)], 3))
    g.add(F.tuft([(0.14, -0.1, 0.2, 0.05, 20, 0.06, False), (-0.14, -0.12, 0.18, 0.05, 80, 0.06, False), (0.02, 0.16, 0.24, 0.05, 200, 0.07, True)], seed=4))
    return finish(g, zmax=1.5, strength=0.5, dist=0.3)


# =========================================================================== MOINHO
HUB_POS = [0.0, -2.05, 6.7]


@kit.prop('windmill', collider=None, tags=['backdrop', 'windmill'], blades=dict(piece='windmill_blades', pos=HUB_POS, axis=[0, 1, 0]))
def windmill():
    n = 8
    base = P(stack([(0.0, 2.35, 2.35), (1.1, 2.2, 2.2), (1.2, 2.05, 2.05)], n, phase=0.5).flat(), STONE, 1, var=0.07)
    tower = stack([(1.15, 2.05, 2.05), (3.6, 1.8, 1.8), (6.3, 1.52, 1.52)], n, phase=0.5).flat()
    P(tower, PLASTER, 2, var=0.035)
    bands = merge(stack([(3.5, 1.86, 1.86), (3.72, 1.84, 1.84)], n, cap_a=False, cap_b=False, phase=0.5), stack([(6.2, 1.6, 1.6), (6.42, 1.72, 1.72)], n, phase=0.5))
    P(bands.flat(), WOOD_D, 3, var=0.06)
    cap = lathe([(1.86, 6.4), (1.8, 6.9), (1.3, 7.8), (0.55, 8.45), (0.0, 8.7)], n, phase=0.5, smooth=False)
    cap.warp(lambda p: Vector((p.x, p.y - 0.25 * max(0.0, (p.z - 6.4) / 2.3), p.z)))
    F.facet(cap, CORAL, var=0.09, seed=4, sun=0.1, fn=lambda nr, cen, c: mul(c, mixc((0.8, 0.8, 0.95), (1.08, 1.04, 1.0), max(0.0, min(1.0, (cen.z - 6.4) / 2.3)))))
    fin = P(stack([(8.6, 0.07, 0.07), (9.1, 0.03, 0.03)], 5).flat().move(0, -0.25, 0), WOOD_D, 5)
    axle = P(tube([(0, -0.9, 6.7), (0, HUB_POS[1] + 0.1, 6.7)], 0.2, 6).flat(), WOOD_D, 6)
    gallery = loft([[(x * 2.75, y * 2.75, 2.5) for x, y in ring_pts(n, 1, 1, 0, 0.5)], [(x * 2.75, y * 2.75, 2.62) for x, y in ring_pts(n, 1, 1, 0, 0.5)],
                    [(x * 1.9, y * 1.9, 2.62) for x, y in ring_pts(n, 1, 1, 0, 0.5)]], cap_a=True, cap_b=False, smooth=False)
    P(gallery, WOOD, 7, var=0.07)
    rail = Geo()
    pts = ring_pts(n, 2.68, 2.68, 0.0, 0.5)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        rail.add(bar((a[0], a[1], 2.6), (a[0], a[1], 3.3), 0.09, WOOD_D, i))
        rail.add(bar((a[0], a[1], 3.25), (b[0], b[1], 3.25), 0.07, WOOD_L, i + 9))
        rail.add(bar((a[0] * 0.74, a[1] * 0.74, 1.7), (a[0] * 0.98, a[1] * 0.98, 2.5), 0.09, WOOD_D, i + 20))
    yb = -2.2 * math.cos(math.pi / 8)
    dr = door(1.0, 1.8, seed=3).move(0, yb - 0.02, 0.0)
    ws = merge(round_window(0.4, seed=1).move(0, -1.74 * math.cos(math.pi / 8) - 0.02, 4.6),
               round_window(0.34, seed=2).move(0, -1.92 * math.cos(math.pi / 8) - 0.02, 2.0 + 1.0).rot('Z', 90),
               round_window(0.34, seed=3).move(0, -1.66 * math.cos(math.pi / 8) - 0.02, 5.3).rot('Z', -45))
    g = merge(base, tower, bands, cap, fin, axle, gallery, rail, dr, ws)
    return finish(g, zmax=7.0, dist=1.0)


@kit.prop('windmill_blades', collider=None, tags=['windmill_blades'], spin_axis=[0, 1, 0])
def windmill_blades():
    # helice centrada no eixo (origem), gira em torno de Y; frente para -Y
    hub = P(stack([(-0.2, 0.3, 0.3), (0.12, 0.26, 0.26)], 8).flat().rot('X', 90), WOOD_D, 1)
    nose = P(lathe([(0.24, 0.0), (0.14, 0.2), (0.0, 0.3)], 6, smooth=False).rot('X', 90).move(0, -0.1, 0), CORAL, 2)
    g = merge(hub, nose)
    for k in range(4):
        b = merge(
            plank(-0.07, 0.07, -0.05, 0.05, 0.2, 3.9, WOOD_D, k, j=0.01),
            plank(0.07, 0.95, -0.03, 0.03, 0.95, 1.03, WOOD, k + 4, j=0.01), plank(0.07, 0.95, -0.03, 0.03, 2.3, 2.38, WOOD, k + 8, j=0.01),
            plank(0.07, 0.95, -0.03, 0.03, 3.68, 3.76, WOOD, k + 12, j=0.01), plank(0.9, 0.97, -0.03, 0.03, 0.95, 3.76, WOOD, k + 16, j=0.01),
        )
        sail = Geo()
        idx = [sail.add_vert(p, None, c) for p, c in (((0.08, -0.02, 1.03), mul(CREAM, (0.9, 0.86, 0.9))), ((0.9, -0.06, 1.03), CREAM),
                                                      ((0.9, -0.06, 3.68), CREAM), ((0.08, -0.02, 3.68), mul(CREAM, (0.94, 0.9, 0.92))))]
        sail.add_face(idx, 'vcol', False)
        sail.add_face(tuple(reversed(idx)), 'vcol', False)
        b.add(sail)
        g.add(b.rot('Y', 90 * k + 12))
    return F.ao(g, 0.35, dist=0.3, floor=None)


if __name__ == '__main__':
    kit.build()

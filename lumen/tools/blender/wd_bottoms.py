"""wd_bottoms.py: roupas de baixo (pernas + pes).

Cada peca traz as duas pernas (do alto da coxa, z~0.41, para baixo) e os pes. Nada passa da
largura da perna de referencia acima de z~0.33, para caber debaixo do saiote de qualquer top.
"""
import math

from mathutils import Vector

import lp
from lp import Geo, box, cone, cyl, ellipsoid, icosphere, lathe, loft, merge, poly_extrude, ring_pts, sheet, stack, tube
import hero_body as hb
from hero_body import HEAD_C, HEAD_R
import wd_base
from wd_base import piece, scalp, hair_cap, tuft, hair_shade, skirt_weights, belt, to_hand

CX = 0.088                      # eixo da perna esquerda
FRIO = (0.70, 0.66, 0.80)
OURO = lp.hexc('#f4c542')


# ================================================================= ajudantes
def _perna(secs, mat, n=8, cap_a=False, cap_b=False):
    """Trecho da perna esquerda: secs = [(z, r[, ry[, dy]])] na ordem do loft (em geral subindo)."""
    s = []
    for sec in secs:
        z, r = sec[0], sec[1]
        ry = sec[2] if len(sec) > 2 else r
        dy = sec[3] if len(sec) > 3 else 0.0
        s.append((z, r, ry, CX + (0.004 if z > 0.3 else 0.0), dy))
    return stack(s, n, mat, cap_a=cap_a, cap_b=cap_b).bind_fn(hb.leg_weights)


def _sola(mat='dark', w=0.070, h=0.022, bico=0.006):
    """Sola: um pe achatado e um pouco mais largo por baixo do sapato."""
    return hb.make_foot(mat, width=w, height=h, toe_up=bico, n=6)


def _tira_pe(y0, y1, w, h, mat, n=5):
    """Tira por cima do pe: meio arco no plano XZ, de y0 (bico) ate y1 (calcanhar)."""
    rows = []
    for y in (y1, y0):
        rows.append([(0.09 + w * math.cos(math.pi * i / n), y, 0.010 + h * math.sin(math.pi * i / n))
                     for i in range(n + 1)])
    return sheet(rows, mat).bind('foot.L')


# ================================================================= pecas
@piece('bottom', 'bottom_botas', 'Calção e Botas')
def bottom_botas():
    return wd_base.ref_bottom()


@piece('bottom', 'bottom_calca', 'Calça e Sapatos')
def bottom_calca():
    leg = _perna([(0.086, 0.066), (0.118, 0.064), (0.205, 0.061), (0.235, 0.060), (0.265, 0.062), (0.350, 0.068),
                  (0.410, 0.048)], 'secondary', cap_a=True, cap_b=True)
    leg.grad('z', 0.086, 0.43, hb.SHADE_LO, lp.WHITE)
    # barra dobrada
    leg.add(_perna([(0.084, 0.064), (0.088, 0.073), (0.122, 0.072), (0.126, 0.063)], 'secondary')
            .color((0.84, 0.80, 0.90)))
    leg.add(hb.make_foot('leather', width=0.064, height=0.066))
    leg.add(_sola('dark', 0.069))
    g = leg.both()
    # remendo so no joelho esquerdo
    rm = Geo()
    ids = [rm.add_vert((CX + x, -0.0625 - 0.004 * (1 - abs(x) / 0.03), z))
           for x, z in ((-0.028, 0.212), (0.028, 0.216), (0.030, 0.262), (-0.026, 0.258))]
    rm.add_face(ids, 'accent')
    g.add(rm.bind_fn(hb.leg_weights))
    return g


@piece('bottom', 'bottom_bermuda', 'Bermuda e Sandálias', cost=60)
def bottom_bermuda():
    leg = _perna([(0.075, 0.050), (0.115, 0.050), (0.205, 0.053), (0.235, 0.052), (0.268, 0.055)], 'skin',
                 cap_a=True)
    leg.grad('z', 0.075, 0.30, (0.86, 0.78, 0.82), lp.WHITE)
    # bermuda larga: comeca por dentro (boca escura) e sobe ate a coxa
    ber = _perna([(0.270, 0.056), (0.250, 0.075), (0.262, 0.077), (0.350, 0.074), (0.410, 0.050)], 'secondary',
                 cap_b=True)
    ber.grad('z', 0.25, 0.43, hb.SHADE_LO, lp.WHITE)
    leg.add(ber)
    leg.add(_perna([(0.252, 0.0785), (0.276, 0.0785)], 'accent'))
    # sandalia: pe de pele, sola e tiras
    leg.add(hb.make_foot('skin', width=0.060, height=0.058, toe_up=0.008))
    leg.add(_sola('leather', 0.068, 0.022, 0.004))
    leg.add(_tira_pe(-0.088, -0.050, 0.069, 0.050, 'leather'))
    leg.add(_perna([(0.080, 0.055), (0.100, 0.056)], 'leather').bind('foot.L'))
    leg.add(box(0.014, 0.022, 0.022, 'vcol', center=(CX + 0.058, -0.004, 0.090)).color(OURO).bind('foot.L'))
    return leg.both()


@piece('bottom', 'bottom_saia', 'Saia Plissada e Meias', cost=100)
def bottom_saia():
    leg = hb.make_leg('skin', 'white', split=0.205, r_hip=0.062, r_knee=0.054, r_ankle=0.056)
    leg.add(_perna([(0.184, 0.060), (0.208, 0.060)], 'accent'))
    # sapatinho de boneca com tira e fivela
    leg.add(hb.make_foot('dark', width=0.064, height=0.060))
    leg.add(_perna([(0.086, 0.061), (0.103, 0.061)], 'dark').bind('foot.L'))
    leg.add(box(0.014, 0.020, 0.020, 'vcol', center=(CX + 0.062, -0.006, 0.094)).color(OURO).bind('foot.L'))
    g = leg.both()
    # saia de pregas (cabe por baixo dos saiotes dos tops)
    n = 20

    def anel(z, k, esc=1.0):
        rx, ry = (0.138 + (0.42 - z) * 0.28) * esc, (0.112 + (0.42 - z) * 0.25) * esc
        return [(x * (1 + (k if i % 2 else -k)), 0.004 + y * (1 + (k if i % 2 else -k)), z)
                for i, (x, y) in enumerate(ring_pts(n, rx, ry, 0.1))]
    sk = loft([anel(0.266, 0.036), anel(0.340, 0.022), anel(0.418, 0.0)], 'primary', cap_a=True, cap_b=False).flat()
    sk.grad('z', 0.266, 0.42, FRIO, lp.WHITE)
    sk.add(loft([anel(0.278, 0.036, 1.012), anel(0.296, 0.032, 1.012)], 'accent', cap_a=False, cap_b=False).flat())
    g.add(sk.bind_fn(skirt_weights(0.266, 0.43)))
    g.add(stack([(0.410, 0.143, 0.117, 0, 0.004, 0.15), (0.434, 0.141, 0.115, 0, 0.004, 0.15)], 10, 'primary',
                cap_a=False, cap_b=False).bind('hips'))
    return g


@piece('bottom', 'bottom_sultao', 'Calça Bufante e Babuchas', rarity=1, cost=180)
def bottom_sultao():
    leg = _perna([(0.092, 0.046), (0.108, 0.060), (0.150, 0.081), (0.205, 0.088), (0.235, 0.089), (0.265, 0.088),
                  (0.310, 0.080), (0.355, 0.068), (0.410, 0.048)], 'secondary', cap_a=True, cap_b=True)
    leg.grad('z', 0.092, 0.43, hb.SHADE_LO, lp.WHITE)
    leg.add(_perna([(0.084, 0.050), (0.090, 0.057), (0.110, 0.057), (0.116, 0.050)], 'accent'))
    # babucha de bico enrolado com pompom
    leg.add(hb.make_foot('accent', width=0.062, height=0.058, toe_up=0.016))
    bico = tube([(0.09, -0.112, 0.034), (0.09, -0.158, 0.040), (0.09, -0.180, 0.066), (0.09, -0.164, 0.090)],
                [0.026, 0.018, 0.011, 0.005], 5, 'accent', up=(1, 0, 0))
    bico.add(ellipsoid(0.015, 0.015, 0.015, 5, 3, 'vcol', center=(0.09, -0.160, 0.094)).color(OURO))
    leg.add(bico.bind('foot.L'))
    return leg.both()


@piece('bottom', 'bottom_cano_alto', 'Botas de Cano Alto', rarity=1, cost=260)
def bottom_cano_alto():
    leg = hb.make_leg('secondary', 'leather', split=0.265, r_hip=0.064, r_knee=0.060, r_ankle=0.063)
    # cano dobrado acima do joelho
    cano = _perna([(0.262, 0.066), (0.312, 0.079), (0.312, 0.067)], 'leather')
    cano.grad('z', 0.262, 0.312, (0.80, 0.76, 0.88), (1.08, 1.06, 1.02))
    leg.add(cano)
    leg.add(hb.make_foot('leather', width=0.068, height=0.080))
    leg.add(_sola('dark', 0.073, 0.026))
    # tiras com fivela no tornozelo e abaixo do joelho
    for z, r in ((0.118, 0.067), (0.196, 0.066)):
        leg.add(_perna([(z - 0.011, r), (z + 0.011, r)], 'dark'))
        leg.add(box(0.016, 0.026, 0.028, 'vcol', center=(CX + r + 0.002, -0.004, z)).color(OURO)
                .bind_fn(hb.leg_weights))
    return leg.both()


@piece('bottom', 'bottom_grevas', 'Grevas de Aço', rarity=1, cost=240)
def bottom_grevas():
    leg = _perna([(0.200, 0.055), (0.235, 0.056), (0.265, 0.060), (0.350, 0.067), (0.410, 0.048)], 'dark',
                 cap_b=True)
    leg.grad('z', 0.20, 0.43, hb.SHADE_LO, lp.WHITE)
    # greva: canela de metal abrindo no joelho, com friso
    gr = _perna([(0.080, 0.063), (0.112, 0.060), (0.180, 0.064), (0.216, 0.071), (0.222, 0.057)], 'metal', cap_a=True)
    gr.grad('z', 0.08, 0.22, (0.72, 0.70, 0.88), lp.WHITE)
    leg.add(gr)
    leg.add(_perna([(0.198, 0.072), (0.220, 0.075)], 'accent'))
    # joelheira e placa da coxa
    leg.add(ellipsoid(0.046, 0.040, 0.050, 6, 3, 'metal', center=(CX, -0.038, 0.238)).bind_fn(hb.leg_weights))
    cx = ellipsoid(0.040, 0.056, 0.062, 6, 3, 'metal', center=(CX + 0.040, -0.014, 0.328))
    cx.grad('z', 0.27, 0.39, (0.74, 0.72, 0.88), lp.WHITE)
    leg.add(cx.bind('thigh.L'))
    # sabato com biqueira
    leg.add(hb.make_foot('metal', width=0.070, height=0.082, toe_up=0.010))
    leg.add(_tira_pe(-0.070, -0.040, 0.076, 0.076, 'accent'))
    leg.add(_sola('dark', 0.074, 0.020))
    return leg.both()

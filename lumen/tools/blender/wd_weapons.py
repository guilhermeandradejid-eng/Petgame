"""wd_weapons.py: armas (espadas, arcos, cajados, martelos com escudo)."""
import math

from mathutils import Vector

import lp
from lp import Geo, box, cone, cyl, ellipsoid, icosphere, lathe, loft, merge, poly_extrude, ring_pts, sheet, stack, tube
import hero_body as hb
from hero_body import HEAD_C, HEAD_R
import wd_base
from wd_base import piece, scalp, hair_cap, tuft, hair_shade, skirt_weights, belt, to_hand


@piece('weapon', 'sword_ferro', 'Espada de Ferro', wt='sword')
def sword_ferro():
    g = Geo()
    blade = stack([(0.09, 0.050, 0.014), (0.50, 0.044, 0.012), (0.60, 0.028, 0.008), (0.68, 0.002, 0.002)], 4, 'metal')
    blade.grad('z', 0.09, 0.68, (0.80, 0.80, 0.90), lp.WHITE)
    g.add(blade)
    g.add(box(0.21, 0.046, 0.04, 'vcol', center=(0, 0, 0.075)).color(lp.hexc('#e9b949')))
    g.add(cyl(0.02, 0.12, 6, 'leather', center=(0, 0, 0.0)))
    g.add(ellipsoid(0.032, 0.032, 0.028, 6, 4, 'vcol', center=(0, 0, -0.075)).color(lp.hexc('#e9b949')))
    return to_hand(g, 'R')

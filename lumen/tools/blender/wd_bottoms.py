"""wd_bottoms.py: roupas de baixo (pernas + pes)."""
import math

from mathutils import Vector

import lp
from lp import Geo, box, cone, cyl, ellipsoid, icosphere, lathe, loft, merge, poly_extrude, ring_pts, sheet, stack, tube
import hero_body as hb
from hero_body import HEAD_C, HEAD_R
import wd_base
from wd_base import piece, scalp, hair_cap, tuft, hair_shade, skirt_weights, belt, to_hand


@piece('bottom', 'bottom_botas', 'Calção e Botas')
def bottom_botas():
    return wd_base.ref_bottom()
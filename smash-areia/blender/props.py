"""Veleiro do horizonte (o resto do cenário fica em scenery.py)."""
import math

from mathutils import Vector

import build_assets as B


def build_sailboat():
    B.reset_scene()
    hull = B.material("BoatHull", "#ffffff")
    stripe = B.material("BoatStripe", "#ff4b3e")
    sail = B.material("Sail", "#fff4e0")
    sail2 = B.material("Sail2", "#ffd23f")
    mast = B.material("Mast", "#6b4a2b")
    b = B.Builder("Sailboat")
    b.sphere((0, 0, 0.3), 1.0, hull, scale=(0.9, 3.0, 0.5), seg=16, rings=8, cut_above=0.45)
    b.sphere((0, 0, 0.42), 1.0, stripe, scale=(0.92, 3.02, 0.06), seg=16, rings=4)
    b.cone((0, 0.2, 0.4), (0, 0, 1), 5.0, 0.06, 0.04, mast, seg=6)
    bm = b.bm
    for (pts, m) in (([(0, 0.25, 0.9), (0, 0.25, 5.2), (0, 2.6, 0.9)], sail),
                     ([(0, 0.15, 1.0), (0, 0.15, 4.6), (0, -2.2, 1.0)], sail2)):
        vs = [bm.verts.new(p) for p in pts]
        f = bm.faces.new(vs)
        f.material_index = b._mi(m)
        vs2 = [bm.verts.new((p[0] + 0.02, p[1], p[2])) for p in reversed(pts)]
        f2 = bm.faces.new(vs2)
        f2.material_index = b._mi(m)
    b.build()
    B.export("sailboat")

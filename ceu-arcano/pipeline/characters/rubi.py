"""Rubi Trovoada, a Lutadora da Tempestade. Rushdown: manoplas elétricas, cachecol longo, raios."""
from __future__ import annotations

import math

from common import skeleton, face_decals
from pixelrig.raster import Material, Part
from pixelrig.rig import Chain
from pixelrig.shapes import (Shape, sd_circle, sd_ellipse, sd_capsule, sd_poly, sd_ribbon,
                             smooth_poly, sd_smooth_union, sd_union, chaikin)

ID = "rubi"


def materials(alt=False):
    M = Material
    if not alt:
        hair = ["#2e0612", "#6e1424", "#b8263a", "#ec5258", "#ff9c90"]
        scarf = ["#3a0808", "#8e1a1a", "#d8332a", "#ff6e45", "#ffb48a"]
        top = ["#09080e", "#17141f", "#28233a", "#3d3656", "#5a5180"]
        pants = ["#30294a", "#7d77a0", "#c8c3dc", "#ebe8f6", "#ffffff"]
        metal = ["#141824", "#2f3850", "#56627f", "#8d9ab8", "#d8e2f5"]
        volt = ["#1d8ab8", "#3fd0ff", "#8ff0ff", "#d8ffff", "#ffffff"]
        eye = ["#2a1404", "#8a5a0a", "#f0b020", "#ffe060", "#ffffff"]
        smear = ["#1d4a8a", "#5fd8ff", "#b8f4ff", "#ffffff", "#ffffff"]
    else:
        hair = ["#06081a", "#141a3a", "#26306a", "#3e52a8", "#7a90e0"]
        scarf = ["#1e0a30", "#46186a", "#7a2aa8", "#b052d8", "#e09af4"]
        top = ["#3a3450", "#8a84a8", "#d0cce2", "#eeecf8", "#ffffff"]
        pants = ["#08070c", "#16131e", "#262134", "#3a3350", "#57507a"]
        metal = ["#2a1606", "#6a3c10", "#b0742a", "#e6b25a", "#fff0b0"]
        volt = ["#b81d8a", "#ff3fd0", "#ff8ff0", "#ffd8ff", "#ffffff"]
        eye = ["#04142a", "#0a3a8a", "#20a0f0", "#80e0ff", "#ffffff"]
        smear = ["#6a1d8a", "#ff5fd8", "#ffb8f4", "#ffffff", "#ffffff"]
    return [
        M("skin", ["#4a1f1a", "#a85a45", "#dd9a78", "#f5c3a0", "#ffe2cc"], shadow=0.22, light=0.82, hi=9),
        M("hair", hair, shadow=0.24, light=0.74, hi=0.9),
        M("scarf", scarf, shadow=0.22, light=0.78, hi=9),
        M("top", top, shadow=0.2, light=0.8, hi=0.95),
        M("pants", pants, shadow=0.2, light=0.82, hi=9),
        M("wrap", ["#1a1420", "#3a3142", "#5e5268", "#8a7d94", "#b5a8be"], shadow=0.2, light=0.8, hi=9),
        M("gold", ["#4a2a0c", "#9c5a17", "#e0a038", "#ffd66b", "#fff4b8"], shadow=0.25, light=0.7, hi=0.88),
        M("metal", metal, shadow=0.28, light=0.68, hi=0.86),
        M("volt", volt, emissive=True),
        M("eye", eye),
        M("white", ["#3a3050", "#b8b0d0", "#f4f0ff", "#ffffff", "#ffffff"]),
        M("mouth", ["#3a0f1a", "#7a2a3a", "#c25a6a", "#f0a0a0", "#ffffff"]),
        M("smear", smear, emissive=True),
    ]


def S(sdf, mat, **kw):
    return Shape(sdf, mat, **kw)


def head_shapes():
    skull = sd_circle(1, -10.5, 9.0)
    jaw = smooth_poly([(-5, -7), (9.6, -9), (9.4, -4.5), (7.6, -1.4), (5.0, 0.2), (1.5, -0.6), (-3, -3.5)], 1)
    out = [S(sd_smooth_union(skull, jaw, 2.0), "skin", bevel=4.5, bias=0.08)]
    out.append(S(sd_ellipse(-3.0, -7.5, 1.6, 2.4), "skin", bevel=1.5, bias=-0.1))
    out += face_decals()
    # curativo no rosto (charme)
    out.append(S(sd_poly([(5.6, -5.4), (8.4, -6.4), (8.8, -5.2), (6.0, -4.2)], 0.2), "white", level=3, line=False))
    cap = sd_poly(chaikin([(-11.5, -4), (-12, -13), (-7, -21), (2, -22.5), (9, -20), (12, -14), (11.5, -11.5),
                           (6, -14.5), (0, -14), (-3.5, -11), (-4.6, -6.5), (-7, -1), (-10, 1.5), (-9.5, -3.5),
                           (-13.5, 0.5)], 1))
    out.append(S(cap, "hair", bevel=4.0, bias=0.05))
    bangs = sd_poly(chaikin([(-2, -17), (12.5, -18.5), (13.6, -13.5), (11.4, -10.6), (10.8, -14), (8.4, -8.6),
                             (7.4, -13.6), (5.0, -9.6), (3.8, -13.8), (1.4, -10.4), (0, -14), (-3.4, -12)], 1))
    out.append(S(bangs, "hair", bevel=3.0, bias=0.12))
    # espetos laterais
    out.append(S(sd_ribbon([(-3, -13), (-5.5, -6), (-6.8, 0.5)], [2.6, 1.8, 0.5]), "hair", bevel=2.0))
    out.append(S(sd_ribbon([(-6, -17), (-12.5, -14.5), (-15.5, -10)], [2.8, 1.6, 0.4]), "hair", bevel=2.0, bias=-0.05))
    out.append(S(sd_ribbon([(-4, -20), (-9, -23.5), (-13, -23)], [2.4, 1.4, 0.4]), "hair", bevel=2.0))
    out.append(S(sd_ribbon([(-5, -15.5), (0, -19.6), (6, -19.0)], [0.7, 0.9, 0.6]), "hair", level=4, line=False, shadow=False))
    # prendedor dourado do rabo de cavalo
    out.append(S(sd_capsule((-7.2, -19.2), (-8.6, -16.8), 1.6), "gold", bevel=1.2))
    return out


def neck_shapes():
    return [S(sd_capsule((0, -1.5), (0.5, 3.5), 2.5, 2.7), "skin", bevel=2, bias=-0.2)]


def scarf_collar_shapes():
    collar = smooth_poly([(-6.5, -9.5), (1, -11.5), (6.8, -9.8), (7.2, -5.6), (2, -4.4), (-5, -5.2), (-7.4, -7.5)], 2)
    return [S(collar, "scarf", bevel=3.0, bias=0.05),
            S(sd_ribbon([(-5, -7.5), (1, -8.6), (6.0, -7.4)], [0.5, 0.6, 0.5]), "scarf", level=1, line=False, shadow=False)]


def torso_shapes():
    body = smooth_poly([(-6.2, -8), (4.5, -8.5), (6.8, -6), (6.2, 0), (4.6, 4.5), (-4.6, 4.5), (-6.6, 0)], 2)
    return [S(body, "top", bevel=4.0),
            S(sd_ribbon([(1.6, -6), (3.2, -1), (2.8, 4.4)], [0.6, 0.6, 0.6]), "gold", bevel=1, line=False),
            S(sd_ribbon([(-4.6, 4.0), (0, 4.6), (4.6, 4.0)], [0.6, 0.6, 0.6]), "gold", bevel=1, line=False)]


def abdomen_shapes():
    belly = smooth_poly([(-4.6, -3), (4.6, -3), (5.0, 3.0), (-5.0, 3.0)], 1)
    sash = smooth_poly([(-5.6, 1.6), (5.8, 1.6), (6.4, 6.6), (-6.4, 6.6)], 1)
    return [S(belly, "skin", bevel=3.0),
            S(sash, "scarf", bevel=2.4),
            S(sd_circle(4.8, 4.0, 1.8), "scarf", bevel=1.4, bias=0.1)]


def pelvis_shapes():
    hips = smooth_poly([(-6.4, -4), (6.4, -4), (7.4, 4), (-7.4, 4)], 1)
    return [S(hips, "pants", bevel=3.5)]


def thigh_shapes():
    return [S(sd_capsule((0, 0), (0.6, 19), 4.6, 4.0), "pants", bevel=3.4)]


def shin_shapes():
    leg = sd_capsule((0, 0), (0.4, 13.5), 4.0, 4.6)
    return [S(leg, "pants", bevel=3.2),
            S(sd_capsule((0.1, 13.0), (0.2, 18.0), 2.6, 2.2), "wrap", bevel=1.6),
            S(sd_ribbon([(-2.4, 14.4), (2.4, 15.6)], [0.4, 0.4]), "wrap", level=1, line=False, shadow=False),
            S(sd_ribbon([(-2.2, 16.6), (2.2, 17.6)], [0.4, 0.4]), "wrap", level=1, line=False, shadow=False)]


def foot_shapes():
    shoe = smooth_poly([(-2.6, -1.0), (2.4, -1.2), (6.4, 1.6), (7.0, 3.9), (-3.0, 4.0), (-3.2, 0.6)], 1)
    return [S(shoe, "top", bevel=2.0),
            S(sd_poly([(-3.2, 3.0), (7.1, 3.0), (7.1, 4.0), (-3.2, 4.0)]), "wrap", level=2, line=False, shadow=False)]


def upper_arm_shapes():
    return [S(sd_capsule((0, 0), (0, 10.5), 2.8, 2.4), "skin", bevel=2.4),
            S(sd_capsule((0, -0.6), (0, 2.6), 3.2, 3.0), "top", bevel=2.0)]


def forearm_shapes():
    g = sd_capsule((0, 1.2), (0, 9.0), 3.2, 3.8)
    return [S(sd_capsule((0, 0), (0, 3), 2.4, 2.4), "skin", bevel=2),
            S(g, "metal", bevel=2.6),
            S(sd_capsule((0, 1.0), (0, 2.2), 3.6, 3.6), "gold", bevel=1.2),
            S(sd_ribbon([(1.4, 3.4), (2.6, 5.6), (1.2, 7.2), (2.4, 8.8)], [0.55, 0.55, 0.55, 0.55]), "volt",
              line=False, shadow=False)]


def hand_shapes():
    fist = sd_union(sd_circle(0.2, 2.2, 3.0), sd_capsule((1.2, 0.4), (2.8, 3.0), 1.3))
    openh = sd_union(sd_ellipse(0.4, 2.8, 2.4, 3.2), sd_capsule((1.4, 0.8), (3.8, 2.8), 1.1))
    return [S(fist, "metal", bevel=2.0, when=("hand", (None, "fist"))),
            S(sd_ribbon([(2.2, 0.6), (3.0, 3.6)], [0.6, 0.6]), "gold", bevel=1.0, line=False,
              when=("hand", (None, "fist"))),
            S(openh, "metal", bevel=2.0, when=("hand", "open")),
            S(sd_circle(0.6, 3.0, 1.1), "volt", line=False, shadow=False, when=("hand", "open"))]


CHAINS = [
    Chain("ponytail", "head", (-8.0, -18.5), 5, 5.4, 52, curl=-10, stiffness=0.18, damping=0.86, gravity=0.3, drag=1.0),
    Chain("scarf_a", "chest", (-5.5, -7.5), 7, 5.0, 64, curl=-4, stiffness=0.08, damping=0.88, gravity=0.18, drag=1.5),
    Chain("scarf_b", "chest", (-5.0, -6.0), 6, 4.8, 46, curl=-6, stiffness=0.08, damping=0.88, gravity=0.2, drag=1.4),
    Chain("sash", "spine", (5.0, 4.5), 3, 3.6, -8, curl=4, stiffness=0.16, damping=0.84, gravity=0.35, drag=1.2),
]


def style_ponytail(pts, ctx, xfs):
    radii = [3.0, 4.4, 4.2, 3.4, 2.2, 0.8]
    return [(1.0, Shape(sd_ribbon(pts, radii), "hair", bevel=3.2, bias=-0.04)),
            (1.01, Shape(sd_ribbon(pts[1:4], [0.4, 0.5, 0.4]), "hair", level=1, line=False, shadow=False))]


def style_scarf(width, z):
    def f(pts, ctx, xfs):
        n = len(pts)
        radii = [width * (1.0 - 0.15 * i / n) for i in range(n)]
        radii[-1] = width * 0.55
        sh = Shape(sd_ribbon(pts, radii), "scarf", bevel=2.2, bias=-0.06)
        stripe = Shape(sd_ribbon(pts[-3:], [r * 0.45 for r in radii[-3:]]), "gold", level=2, line=False, shadow=False)
        return [(z, sh), (z + 0.01, stripe)]
    return f


def style_sash(pts, ctx, xfs):
    return [(7.6, Shape(sd_ribbon(pts, [1.2, 1.8, 1.6, 0.9]), "scarf", bevel=1.6))]


CHAIN_STYLE = {"ponytail": style_ponytail, "scarf_a": style_scarf(2.6, 0.5), "scarf_b": style_scarf(2.3, 0.6),
               "sash": style_sash}


def parts():
    return [
        Part("arm_b_up", "sh_b", 3.0, upper_arm_shapes(), bias=-0.18),
        Part("forearm_b", "el_b", 3.2, forearm_shapes(), bias=-0.15),
        Part("hand_b", "hand_b", 3.3, hand_shapes(), bias=-0.12),
        Part("thigh_b", "hip_b", 4.0, thigh_shapes(), bias=-0.16),
        Part("shin_b", "knee_b", 4.1, shin_shapes(), bias=-0.16),
        Part("foot_b", "foot_b", 4.2, foot_shapes(), bias=-0.16),
        Part("thigh_f", "hip_f", 5.0, thigh_shapes()),
        Part("shin_f", "knee_f", 5.1, shin_shapes()),
        Part("foot_f", "foot_f", 5.2, foot_shapes()),
        Part("pelvis", "pelvis", 6.0, pelvis_shapes()),
        Part("abdomen", "spine", 7.0, abdomen_shapes()),
        Part("torso", "chest", 8.0, torso_shapes()),
        Part("neck", "neck", 8.5, neck_shapes()),
        Part("arm_f_up", "sh_f", 9.0, upper_arm_shapes()),
        Part("collar", "chest", 9.5, scarf_collar_shapes()),
        Part("forearm_f", "el_f", 10.9, forearm_shapes()),
        Part("hand_f", "hand_f", 11.0, hand_shapes()),
        Part("head", "head", 12.0, head_shapes()),
    ]


def build_skeleton():
    return skeleton()


HURT = {
    "head": ["head"],
    "body": ["torso", "abdomen", "pelvis", "collar", "arm_f_up", "arm_b_up", "neck"],
    "legs": ["thigh_f", "shin_f", "foot_f", "thigh_b", "shin_b", "foot_b"],
    "limb": ["forearm_f", "hand_f", "forearm_b", "hand_b"],
}

POINTS = {
    "hand_f": ("hand_f", (0.6, 2.4)),
    "hand_b": ("hand_b", (0.6, 2.4)),
    "foot_f": ("foot_f", (3.0, 2.0)),
    "head": ("head", (1.0, -10.0)),
    "chest": ("chest", (1.0, -2.0)),
}

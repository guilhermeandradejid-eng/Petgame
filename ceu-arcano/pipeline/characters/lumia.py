"""Lumia, a Bruxa dos Vagalumes. Zoneadora: lanterna num cajado, vagalumes, estrelas e aurora."""
from __future__ import annotations

import math

from common import skeleton, face_decals
from pixelrig.raster import Material, Part
from pixelrig.rig import Bone, Chain
from pixelrig.shapes import (Shape, Decal, sd_circle, sd_ellipse, sd_capsule, sd_poly, sd_ribbon,
                             smooth_poly, sd_smooth_union, sd_union, sd_subtract, chaikin)

ID = "lumia"

# ---------------------------------------------------------------- paletas

def materials(alt=False):
    M = Material
    if not alt:
        hair = ["#11304a", "#1f5e6e", "#33999a", "#77d6c2", "#d0fff0"]
        coat = ["#0c1030", "#1b2354", "#2c3a88", "#4660bc", "#7a98e6"]
        lining = ["#2a0f33", "#5a1c62", "#8e3290", "#c05cbc", "#e79be0"]
        eye = ["#2a0c06", "#8a3d10", "#e8952a", "#ffd25a", "#ffffff"]
    else:
        hair = ["#3a2a52", "#7a68a8", "#b3a6dc", "#e2daf6", "#ffffff"]
        coat = ["#1c0a14", "#40142c", "#6c2244", "#9a3a5e", "#cf6a88"]
        lining = ["#0c2a2c", "#18575a", "#2a8a86", "#52bdae", "#a0ecd8"]
        eye = ["#081a2a", "#1a4a7a", "#3aa0e0", "#8fdcff", "#ffffff"]
    return [
        M("skin", ["#5e2b35", "#c9787a", "#f5c3ac", "#ffe3d3", "#fff3ea"], shadow=0.22, light=0.82, hi=9),
        M("hair", hair, shadow=0.24, light=0.74, hi=0.9),
        M("coat", coat, shadow=0.2, light=0.8, hi=9),
        M("lining", lining, shadow=0.2, light=0.8, hi=9),
        M("gold", ["#4a2a0c", "#9c5a17", "#e0a038", "#ffd66b", "#fff4b8"], shadow=0.25, light=0.7, hi=0.88),
        M("cream", ["#3e3247", "#9b8aa6", "#dcd2e0", "#f6f1f7", "#ffffff"], shadow=0.18, light=0.8, hi=9),
        M("stock", ["#0b0912", "#1a1626", "#2c2540", "#43395f", "#5e5282"], shadow=0.2, light=0.82, hi=9),
        M("boot", ["#170f17", "#3b2531", "#5f3b47", "#8a5a62", "#b8888a"], shadow=0.2, light=0.78, hi=0.95),
        M("wood", ["#1f0f14", "#4a2a2a", "#7a4a3a", "#a8715a", "#d8a487"], shadow=0.2, light=0.75, hi=9),
        M("glass", ["#ff9a3a", "#ffb84d", "#ffd76a", "#fff0a8", "#ffffff"], emissive=True),
        M("eye", eye),
        M("white", ["#3a3050", "#b8b0d0", "#f4f0ff", "#ffffff", "#ffffff"]),
        M("mouth", ["#3a0f1a", "#7a2a3a", "#c25a6a", "#f0a0a0", "#ffffff"]),
        M("smear", ["#8a5a1a", "#ffc860", "#ffe7a0", "#fff8e0", "#ffffff"], emissive=True),
    ]


# ---------------------------------------------------------------- formas

def S(sdf, mat, **kw):
    return Shape(sdf, mat, **kw)


def head_shapes():
    skull = sd_circle(1, -10.5, 9.2)
    jaw = smooth_poly([(-5, -7), (9.8, -9), (9.6, -4.5), (7.8, -1.4), (5.2, 0.3), (1.5, -0.6), (-3, -3.5)], 1)
    head = sd_smooth_union(skull, jaw, 2.0)
    out = [S(head, "skin", bevel=4.5, bias=0.08)]
    # orelha (lado perto)
    out.append(S(sd_ellipse(-3.2, -7.5, 1.6, 2.4), "skin", bevel=1.5, bias=-0.1))
    out += face_decals()
    # cabelo: calota
    cap = smooth_poly([(-11, -6), (-10.5, -15), (-5, -21), (3, -22), (9, -19), (11.6, -13.5), (11, -11),
                       (6, -14), (0, -14), (-3, -11.5), (-4.6, -7.5), (-6, -3), (-9.5, -1.5)], 2)
    out.append(S(cap, "hair", bevel=4.0, bias=0.05))
    # franja em mechas
    bangs = sd_poly(chaikin([(-1.5, -16), (11.8, -17), (12.2, -11.5), (10.6, -8.6), (9.4, -12.2),
                             (8.0, -8.0), (6.4, -12.6), (4.6, -7.6), (2.8, -12.4), (1.2, -9.0), (-0.6, -12.6),
                             (-3.2, -10)], 1))
    out.append(S(bangs, "hair", bevel=3.0, bias=0.12))
    # mecha lateral na frente da orelha
    out.append(S(sd_ribbon([(-2.0, -12), (-3.2, -6), (-3.0, -1), (-2.0, 3)], [2.4, 2.1, 1.6, 0.8]), "hair", bevel=2.0))
    # anel de brilho no cabelo
    out.append(S(sd_ribbon([(-6, -16.5), (-1, -19.2), (5, -18.8)], [0.7, 0.9, 0.6]), "hair", level=4, line=False, shadow=False))
    # presilha de estrela
    out.append(S(star(-5.5, -15.5, 2.8, 1.2, -10), "gold", bevel=1.5))
    # ahoge
    out.append(S(sd_ribbon([(1, -21), (3.5, -25.5), (7, -26), (8, -24.5)], [1.3, 1.0, 0.7, 0.4]), "hair", bevel=1.2))
    return out


def star(cx, cy, r1, r2, rot_deg=0.0, n=5):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot_deg - 90 + i * 180.0 / n)
        r = r1 if i % 2 == 0 else r2
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return sd_poly(pts, 0.25)


def hair_back_shapes():
    mass = smooth_poly([(-12, -13), (-7, -21), (4, -21.5), (9.5, -16), (8, -6), (4, 2), (-2, 8),
                        (-9, 9), (-13.5, 2)], 2)
    return [S(mass, "hair", bevel=4.0, bias=-0.12)]


def neck_shapes():
    return [S(sd_capsule((0, -1.5), (0.5, 3.5), 2.4, 2.6), "skin", bevel=2, bias=-0.2),
            # gola alta da blusa
            S(smooth_poly([(-3, 0.5), (3.6, 0.2), (4.2, 3.8), (-3.4, 4.2)], 1), "cream", bevel=2)]


def torso_shapes():
    coat = smooth_poly([(-6.2, -8), (4.5, -8.5), (6.8, -6), (6.4, 0), (5, 6.5), (-5, 6.5), (-6.8, 0)], 2)
    out = [S(coat, "coat", bevel=4.5)]
    # blusa na abertura da frente
    out.append(S(smooth_poly([(1.2, -8.4), (4.6, -8.6), (5.2, -3), (3.8, 6.5), (1.4, 6.5)], 1), "cream", bevel=2.5))
    # botões
    for y in (-3.5, 0.5, 4.0):
        out.append(S(sd_circle(3.0, y, 0.7), "gold", level=3, line=False))
    # acabamento dourado da lapela
    out.append(S(sd_ribbon([(1.2, -8), (0.9, -2), (1.1, 6.4)], [0.7, 0.7, 0.7]), "gold", bevel=1, line=False))
    return out


def capelet_shapes():
    cap = smooth_poly([(-8.6, -9.5), (2, -11), (7.5, -8.5), (8.8, -4), (6.5, -1.0), (0, -0.2), (-7, -2.2),
                       (-10, -5.5)], 2)
    hem = smooth_poly([(-10.3, -5.7), (-7, -2.0), (0, 0.4), (6.7, -0.6), (9.0, -4.0), (8.6, -2.2), (6.6, 0.8),
                       (0, 1.6), (-7.4, -0.8), (-10.5, -4.2)], 1)
    return [S(cap, "coat", bevel=4.0, bias=0.06),
            S(hem, "gold", bevel=1.2),
            S(star(3.4, -8.6, 2.6, 1.1, 0), "gold", bevel=1.4),
            S(sd_circle(3.4, -8.6, 0.8), "glass", line=False)]


def abdomen_shapes():
    waist = smooth_poly([(-5.2, -3.5), (5.2, -3.5), (5.4, 3), (6, 6.5), (-6, 6.5), (-5.4, 3)], 1)
    return [S(waist, "coat", bevel=4.0),
            S(smooth_poly([(1.4, -3.5), (3.9, -3.5), (3.8, 1.0), (1.6, 1.0)], 1), "cream", bevel=2),
            S(sd_poly([(-5.7, 1.0), (5.7, 1.0), (5.9, 3.4), (-5.9, 3.4)], 0.2), "boot", bevel=1.5),
            S(sd_poly([(2.0, 0.6), (4.6, 0.6), (4.6, 3.8), (2.0, 3.8)], 0.3), "gold", bevel=1.2)]


def skirt_shapes():
    outer = smooth_poly([(-6.4, -4), (6.4, -4), (9.6, 5), (10.8, 11.5), (3, 13.6), (-6, 13.2), (-10.6, 11)], 2)
    inner = smooth_poly([(-6.2, -4), (6.2, -4), (9.2, 5), (10.0, 10.0), (3, 12.0), (-6, 11.7), (-10.0, 9.6)], 2)
    out = [S(outer, "gold", bevel=2.5), S(inner, "coat", bevel=4.0, group=55)]
    # dobras
    out.append(S(sd_ribbon([(1.0, 1), (0.2, 7), (-0.6, 11.4)], [0.45, 0.6, 0.8]), "coat", level=1, line=False, shadow=False))
    out.append(S(sd_ribbon([(5.5, 2), (6.3, 7), (6.8, 10.8)], [0.4, 0.55, 0.7]), "coat", level=1, line=False, shadow=False))
    return out


def skirt_back_shapes():
    back = smooth_poly([(-6, -2), (2, -2), (-3, 12.5), (-11.5, 12.2), (-9, 4)], 1)
    return [S(back, "lining", bevel=3.0, bias=-0.15)]


def thigh_shapes():
    return [S(sd_capsule((0, 0), (0, 19), 4.0, 3.1), "stock", bevel=3.0)]


def shin_shapes():
    return [S(sd_capsule((0, 0), (0, 17.5), 3.1, 2.2), "stock", bevel=2.6),
            S(sd_capsule((0, 6.5), (0.2, 17.6), 3.4, 2.7), "boot", bevel=2.6),
            S(sd_capsule((-0.1, 6.6), (0.1, 7.2), 3.35, 3.3), "gold", bevel=1.0, line=False)]


def foot_shapes():
    boot = smooth_poly([(-2.6, -1.5), (2.6, -1.5), (6.2, 1.4), (7.2, 3.9), (-3.3, 4.0), (-3.4, 0.5)], 1)
    return [S(boot, "boot", bevel=2.2),
            S(sd_poly([(-3.4, 3.0), (7.3, 3.0), (7.3, 4.0), (-3.4, 4.0)]), "boot", level=1, line=False, shadow=False)]


def upper_arm_shapes():
    return [S(sd_capsule((0, 0), (0, 10.5), 3.0, 2.6), "coat", bevel=2.6)]


def forearm_shapes():
    sleeve = sd_capsule((0, 0), (0, 7.6), 2.6, 3.4)
    return [S(sleeve, "coat", bevel=2.6),
            S(sd_capsule((0, 7.2), (0, 8.6), 3.6, 3.6), "gold", bevel=1.3),
            S(sd_capsule((0, 8.8), (0, 10.4), 3.0, 2.6), "lining", bevel=1.5, bias=-0.1)]


def hand_shapes():
    fist = sd_union(sd_circle(0, 2.0, 2.4), sd_capsule((0.8, 0.5), (2.2, 2.6), 1.0))
    openh = sd_union(sd_ellipse(0.2, 2.6, 2.0, 3.0), sd_capsule((1.2, 0.8), (3.4, 2.6), 0.9))
    return [S(fist, "skin", bevel=1.8, when=("hand", (None, "fist"))),
            S(openh, "skin", bevel=1.8, when=("hand", "open"))]


def staff_shapes():
    rod = sd_capsule((0, 15), (0, -33), 1.15, 1.15)
    hook = sd_ribbon([(0, -33), (0.6, -37.5), (3.4, -40.4), (7, -40), (8.8, -37.4), (8.6, -35.2)],
                     [1.4, 1.3, 1.2, 1.1, 1.0, 0.9])
    return [S(rod, "wood", bevel=1.2),
            S(sd_capsule((0, 13), (0, 16.2), 1.6, 1.3), "gold", bevel=1.2),
            S(sd_capsule((0, -30), (0, -33.5), 1.8, 1.8), "gold", bevel=1.2),
            S(hook, "gold", bevel=1.3),
            S(star(0.2, -36.5, 2.2, 1.0, 0), "glass", line=False)]


# ---------------------------------------------------------------- correntes

CHAINS = [
    Chain("hair", "head", (-6.5, -7), 6, 6.2, 22, curl=-4, stiffness=0.16, damping=0.86, gravity=0.32, drag=1.0),
    Chain("lantern", "staff", (8.6, -35.0), 2, 3.4, 0, stiffness=0.05, damping=0.92, gravity=0.55,
          drag=0.6, world_rest=True, min_y=None),
    Chain("ribbon_a", "spine", (-5.5, 2.0), 3, 5.0, 38, curl=8, stiffness=0.14, damping=0.84, gravity=0.3, drag=1.3),
    Chain("ribbon_b", "spine", (-5.0, 2.6), 3, 4.6, 14, curl=-6, stiffness=0.14, damping=0.84, gravity=0.3, drag=1.3),
]


def style_hair(pts, ctx, xfs):
    radii = [5.6, 6.0, 5.4, 4.6, 3.6, 2.4, 1.2]
    body = Shape(sd_ribbon(pts, radii), "hair", bevel=3.8, bias=-0.05)
    # mechas mais escuras para dar textura
    mid = [((pts[i][0] + pts[i + 1][0]) / 2 + 1.0, (pts[i][1] + pts[i + 1][1]) / 2) for i in range(len(pts) - 1)]
    strand = Shape(sd_ribbon(mid[1:], [0.5] * (len(mid) - 1)), "hair", level=1, line=False, shadow=False)
    return [(1.0, body), (1.01, strand)]


def style_lantern(pts, ctx, xfs):
    out = []
    cord = Shape(sd_ribbon(pts[:2] + [pts[2]], [0.45, 0.45, 0.45]), "gold", level=2, line=False, shadow=False)
    out.append((10.75, cord))
    ex, ey = pts[-1]
    px, py = pts[-2]
    ang = math.degrees(math.atan2(ex - px, ey - py))
    c, s = math.cos(math.radians(-ang)), math.sin(math.radians(-ang))

    def tr(x, y):
        return (ex + c * x - s * y, ey + s * x + c * y)
    body = sd_poly(chaikin([tr(-3.2, 1.4), tr(3.2, 1.4), tr(4.4, 5.6), tr(3.2, 9.8), tr(-3.2, 9.8), tr(-4.4, 5.6)], 2))
    core = sd_ellipse(*tr(-0.6, 5.0), 1.6, 2.6)
    cap_t = sd_capsule(tr(0, 0.6), tr(0, 1.8), 2.8, 3.4)
    cap_b = sd_capsule(tr(0, 9.6), tr(0, 10.8), 3.4, 2.0)
    lit = ctx.get("lantern", "on") != "off"
    out.append((10.76, Shape(body, "glass" if lit else "boot", level=2 if lit else None, bevel=2)))
    if lit:
        out.append((10.761, Shape(core, "glass", level=4, line=False, shadow=False)))
    out.append((10.77, Shape(sd_capsule(tr(2.4, 2.2), tr(2.6, 9.0), 0.5, 0.5), "gold", level=1, line=False, shadow=False)))
    out.append((10.77, Shape(sd_capsule(tr(-2.4, 2.2), tr(-2.6, 9.0), 0.5, 0.5), "gold", level=3, line=False, shadow=False)))
    out.append((10.78, Shape(cap_t, "gold", bevel=1.2)))
    out.append((10.78, Shape(cap_b, "gold", bevel=1.2)))
    return out


def style_ribbon(pts, ctx, xfs):
    radii = [1.4, 2.4, 2.0, 1.0]
    return [(4.4, Shape(sd_ribbon(pts, radii), "lining", bevel=1.8, bias=-0.05))]


CHAIN_STYLE = {"hair": style_hair, "lantern": style_lantern, "ribbon_a": style_ribbon, "ribbon_b": style_ribbon}


def parts():
    return [
        Part("hair_back", "head", 2.0, hair_back_shapes()),
        Part("arm_b_up", "sh_b", 3.0, upper_arm_shapes(), bias=-0.18),
        Part("forearm_b", "el_b", 3.2, forearm_shapes(), bias=-0.18),
        Part("hand_b", "hand_b", 3.3, hand_shapes(), bias=-0.15),
        Part("thigh_b", "hip_b", 4.0, thigh_shapes(), bias=-0.16),
        Part("shin_b", "knee_b", 4.1, shin_shapes(), bias=-0.16),
        Part("foot_b", "foot_b", 4.2, foot_shapes(), bias=-0.16),
        Part("skirt_back", "pelvis", 4.6, skirt_back_shapes()),
        Part("thigh_f", "hip_f", 5.0, thigh_shapes()),
        Part("shin_f", "knee_f", 5.1, shin_shapes()),
        Part("foot_f", "foot_f", 5.2, foot_shapes()),
        Part("skirt", "pelvis", 6.0, skirt_shapes()),
        Part("abdomen", "spine", 7.0, abdomen_shapes()),
        Part("torso", "chest", 8.0, torso_shapes()),
        Part("neck", "neck", 8.5, neck_shapes()),
        Part("arm_f_up", "sh_f", 9.0, upper_arm_shapes()),
        Part("capelet", "chest", 10.0, capelet_shapes()),
        Part("staff", "staff", 10.6, staff_shapes()),
        Part("forearm_f", "el_f", 10.9, forearm_shapes()),
        Part("hand_f", "hand_f", 11.0, hand_shapes()),
        Part("head", "head", 12.0, head_shapes()),
    ]


def build_skeleton():
    return skeleton([Bone("staff", "hand_f", (2, -38))])


HURT = {
    "head": ["head", "hair_back"],
    "body": ["torso", "abdomen", "skirt", "capelet", "arm_f_up", "arm_b_up", "neck"],
    "legs": ["thigh_f", "shin_f", "foot_f", "thigh_b", "shin_b", "foot_b"],
    "limb": ["forearm_f", "hand_f", "forearm_b", "hand_b", "staff"],
}

POINTS = {
    "hand_f": ("hand_f", (0.5, 2.0)),
    "hand_b": ("hand_b", (0.5, 2.0)),
    "staff_tip": ("staff", (8.6, -36.0)),
    "staff_star": ("staff", (0.2, -36.5)),
    "head": ("head", (1.0, -10.0)),
    "chest": ("chest", (1.0, -2.0)),
}

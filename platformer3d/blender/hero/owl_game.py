"""The owl companion, game version: open-wing rest pose so the wings can fold and flap,
fur colour and length baked into vertex colours for the Godot shell-fur shader."""
import math

import bpy
from mathutils import Vector

from vinyl import Piece, make_armature, skin
from anim import Clip, wave, add_pose
import hero as H

BROWN = (0.37, 0.26, 0.19)
DARK = (0.22, 0.15, 0.1)
CREAM = (0.9, 0.82, 0.69)

HEAD = Vector((0, -0.005, 0.085))


def bones():
    bl = [
        ("root", (0, 0, -0.08), (0, 0, 0.0), None),
        ("body", (0, 0, -0.07), (0, 0, 0.05), "root"),
        ("head", (0, 0, 0.05), (0, 0, 0.17), "body"),
        ("tail", (0, 0.06, -0.04), (0, 0.11, -0.07), "body"),
    ]
    for side, sx in (("L", 1), ("R", -1)):
        bl += [
            ("tuft." + side, (sx * 0.045, 0.0, 0.14), (sx * 0.055, 0.0, 0.18), "head"),
            ("wing1." + side, (sx * 0.06, 0.01, 0.03), (sx * 0.16, 0.02, 0.035), "body"),
            ("wing2." + side, (sx * 0.16, 0.02, 0.035), (sx * 0.29, 0.04, 0.02), "wing1." + side),
            ("foot." + side, (sx * 0.025, -0.02, -0.06), (sx * 0.025, -0.04, -0.09), "body"),
            ("eye." + side, (sx * 0.032, -0.062, 0.09), (sx * 0.04, -0.1, 0.09), "head"),
        ]
    return bl


def colour_owl(o, kind):
    me = o.data
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for v in me.vertices:
        q = o.matrix_world @ v.co
        c, ln = BROWN, 0.45
        if kind == "body":
            face = (q - (HEAD + Vector((0, -0.065, 0)))).length < 0.065
            belly = q.y < -0.04 and q.z < 0.03
            hole = min((q - (HEAD + Vector((sx * 0.032, -0.066, 0.005)))).length for sx in (-1, 1)) < 0.026
            if face:
                c, ln = CREAM, 0.25
            elif belly:
                bar = int((q.z + 0.2) * 70) % 3 == 0
                c, ln = (BROWN if bar else CREAM), 0.45
            if hole:
                ln = 0.0
        elif kind == "wing":
            bar = int(abs(q.x) * 45) % 2 == 0
            c, ln = (DARK if bar else BROWN), 0.18
        col.data[v.index].color = (*c, ln)


def build(material):
    body = Piece("OwlBody", material("fur", "#5e4330"))
    body.ellip((0, 0, 0), 0.075, (1.05, 0.95, 0.95))
    body.ellip(tuple(HEAD), 0.072, (1.15, 1.0, 0.9))
    for sx in (-1, 1):
        body.ellip((sx * 0.05, 0.005, 0.155), 0.022, (0.6, 0.5, 1.4))
    body.ellip((0, 0.08, -0.05), 0.035, (1.1, 1.3, 0.3))   # tail fan
    ob = body.build(voxel=0.004, smooth=6)
    from game_b import decimate
    decimate(ob, 5000)
    from game_b import unwrap
    unwrap(ob)
    colour_owl(ob, "body")
    wings = []
    for side, sx in (("L", 1), ("R", -1)):
        w = Piece("OwlWing." + side, material("fur", "#5e4330"))
        w.ellip((sx * 0.12, 0.02, 0.032), 0.06, (1.2, 0.75, 0.16))
        for k in range(5):  # primaries fanning out from the hand
            a = math.radians(-30 + 15 * k)
            base = Vector((sx * 0.2, 0.03, 0.028))
            tip = base + Vector((sx * math.cos(a) * 0.1, math.sin(a) * 0.05 + 0.03, -0.004))
            w.caps(tuple(base), tuple(tip), 0.018, 0.011)
        wo = w.build(voxel=0.003, smooth=6)
        decimate(wo, 1500)
        unwrap(wo)
        colour_owl(wo, "wing")
        wings.append((side, wo))

    arm = make_armature("OwlRig", bones())
    skin(ob, arm, ["body", "head", "tuft.L", "tuft.R", "tail"], power=6)
    for side, wo in wings:
        skin(wo, arm, ["wing1." + side, "wing2." + side])
    for side, sx in (("L", 1), ("R", -1)):
        c = HEAD + Vector((sx * 0.032, -0.062, 0.005))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.026, location=c, segments=24, ring_count=12)
        e = bpy.context.active_object
        e.name = "OwlEye." + side
        e.data.materials.append(material("owl_eye", "#ffffff"))
        bpy.ops.object.shade_smooth()
        from game_b import eye_uvs
        eye_uvs(e, c, Vector((sx * 0.25, -1, 0)).normalized())
        skin(e, arm, [], rigid="eye." + side)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.014, location=(sx * 0.025, -0.03, -0.075), segments=12, ring_count=6)
        f = bpy.context.active_object
        f.scale = (1, 1.4, 0.6)
        f.data.materials.append(material("talon", "#cdb37a"))
        skin(f, arm, [], rigid="foot." + side)
    bpy.ops.mesh.primitive_cone_add(radius1=0.013, depth=0.03, location=HEAD + Vector((0, -0.078, -0.02)), vertices=16)
    bk = bpy.context.active_object
    bk.rotation_euler = (math.radians(110), 0, 0)
    bpy.ops.object.transform_apply(rotation=True)
    bk.data.materials.append(material("beak", "#d9c48a"))
    skin(bk, arm, [], rigid="head")
    return arm


# ----------------------------------------------------------------------------- animation

def folded():
    """Wings folded down along the body (from the open rest pose)."""
    return {"wing1.L": {"r": (0, 80, -25)}, "wing1.R": {"r": (0, -80, 25)},
            "wing2.L": {"r": (0, 60, -90)}, "wing2.R": {"r": (0, -60, 90)}}


def flap(f, period, amp=55.0, lag=0.9, base=0.0):
    w1 = base + amp * wave(f, period)
    w2 = base * 0.5 + amp * 0.75 * wave(f, period, -lag)
    return {"wing1.L": {"r": (0, w1, 0)}, "wing1.R": {"r": (0, -w1, 0)},
            "wing2.L": {"r": (0, w2, 0)}, "wing2.R": {"r": (0, -w2, 0)}}


def bob(f, period, amp=0.015, squash=0.06):
    w = wave(f, period, math.pi)
    return {"root": {"l": (0, 0, amp * w)}, "body": {"s": (1 + squash * 0.5 * w, 1, 1 - squash * w)}}


def blink(f, at, n=4):
    if at <= f <= at + n:
        k = 1 - 0.9 * math.sin(math.pi * (f - at) / n)
        return {"eye.L": {"s": (1, 1, k)}, "eye.R": {"s": (1, 1, k)}}
    return {}


def perch():
    """Sitting on Bolo's head: looks around with the owl's famous head turns, blinks slowly."""
    n = 120
    base = add_pose(folded(), {"foot.L": {"r": (-20, 0, 0)}, "foot.R": {"r": (-20, 0, 0)}})
    c = Clip("perch", n, loop=True)
    c.k(0, base, "inout").k(20, add_pose(base, {"head": {"r": (0, 0, 70)}}), "inout")
    c.k(45, add_pose(base, {"head": {"r": (0, 18, 70)}}), "inout").k(60, base, "inout")
    c.k(80, add_pose(base, {"head": {"r": (0, 0, -60)}}), "out").k(100, add_pose(base, {"head": {"r": (0, -12, -60)}}), "inout").k(n, base)
    c.overlay(lambda f: add_pose({"body": {"s": (1 + 0.015 * wave(f, 60), 1, 1 - 0.02 * wave(f, 60))}}, blink(f, 30, 6) or blink(f, 90, 6)))
    return c


def loop(name, n, period, amp, extra=None):
    c = Clip(name, n, loop=True).k(0, {}).k(n, {})
    c.overlay(lambda f: flap(f, period, amp)).overlay(lambda f: bob(f, period))
    if extra:
        c.overlay(extra)
    return c


def fly():
    return loop("fly", 12, 6, 60, lambda f: add_pose({"body": {"r": (15, 0, 0)}, "tail": {"r": (-10, 0, 0)}}, blink(f, 7)))


def hover():
    return loop("hover", 24, 12, 42, lambda f: add_pose({"body": {"r": (0, 4 * wave(f, 24), 0)}}, blink(f, 18)))


def carry():
    """Holding Bolo up: fast hard strokes, talons clenched below, eyes squeezed with effort."""
    def strain(f):
        return {"body": {"r": (-10, 0, 0), "s": (0.95, 0.95, 1.1)},
                "foot.L": {"r": (-30, 0, 0)}, "foot.R": {"r": (-30, 0, 0)},
                "eye.L": {"s": (1, 1, 0.45)}, "eye.R": {"s": (1, 1, 0.45)}}
    return loop("carry", 8, 4, 65, strain)


def boost():
    """Dives under Bolo's feet, gets squashed by the push, then tumbles away flapping."""
    flat = add_pose(folded(), {"body": {"s": (1.4, 1.4, 0.55)}, "eye.L": {"s": (1, 1, 0.2)}, "eye.R": {"s": (1, 1, 0.2)}})
    pop = {"body": {"s": (0.85, 0.85, 1.3)}, "wing1.L": {"r": (0, -60, 0)}, "wing1.R": {"r": (0, 60, 0)},
           "wing2.L": {"r": (0, -40, 0)}, "wing2.R": {"r": (0, 40, 0)}}
    c = Clip("boost", 18)
    c.k(0, folded(), "out").k(2, flat, "inout").k(5, flat, "out").k(8, pop, "inout").k(18, {})
    c.overlay(lambda f: {"root": {"r": (0, 0, 360 * min(1, max(0, (f - 6) / 10)) ** 0.7)}})
    return c


def tease():
    """Hops off when Bolo reaches for it: wiggles side to side and flicks its wings."""
    n = 24
    c = Clip("tease", n, loop=True).k(0, {}).k(n, {})
    c.overlay(lambda f: flap(f, 8, 45)).overlay(lambda f: bob(f, 8))
    c.overlay(lambda f: {"body": {"r": (0, 16 * wave(f, 12), 10 * wave(f, 24))},
                         "head": {"r": (0, -12 * wave(f, 12, -1), 0)},
                         "tuft.L": {"r": (0, 15 * wave(f, 12, -1), 0)}, "tuft.R": {"r": (0, -15 * wave(f, 12, -1), 0)}})
    return c


ALL = [perch, fly, hover, carry, boost, tease]

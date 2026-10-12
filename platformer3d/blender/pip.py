"""Pip the bat: Bolo's flying companion. Origin at the body centre (Pip never touches the ground)."""
import math

from mathutils import Vector

from vinyl import Piece, vinyl, simple_sphere, make_armature, skin

BODY_R = 0.2

BONES = [
    ("root", (0, 0, -0.1), (0, 0, 0.1), None),
    ("body", (0, 0, -0.12), (0, 0, 0.16), "root"),
]
for side, sx in (("L", 1), ("R", -1)):
    BONES += [
        ("ear." + side, (sx * 0.1, 0.02, 0.14), (sx * 0.16, 0.02, 0.38), "body"),
        ("wing1." + side, (sx * 0.15, 0.04, 0.04), (sx * 0.4, 0.06, 0.08), "body"),
        ("wing2." + side, (sx * 0.4, 0.06, 0.08), (sx * 0.68, 0.08, 0.02), "wing1." + side),
        ("foot." + side, (sx * 0.06, 0.02, -0.15), (sx * 0.07, 0.0, -0.26), "body"),
    ]
EYES = []
for sx in (-1, 1):
    a = math.radians(26) * sx
    d = Vector((math.sin(a), -math.cos(a), math.sin(math.radians(10)))).normalized()
    EYES.append((sx, d * (BODY_R * 0.92)))
for sx, p in EYES:
    side = "L" if sx > 0 else "R"
    BONES.append(("eye." + side, tuple(p), tuple(p * 1.4), "body"))


def build():
    fur = vinyl("pip_fur", "#6d4ba3")
    belly = vinyl("pip_belly", "#a98bd6")
    wing = vinyl("pip_wing", "#3f2a66", rough=0.45)
    inner = vinyl("pip_inner", "#e7a6c4")
    eye_m = vinyl("eye", "#16121c", rough=0.06, coat=1.0)
    shine = vinyl("shine", "#ffffff", rough=0.2, coat=0.0)
    fang = vinyl("fang", "#fffaf0", rough=0.3)

    body = Piece("PipBody", fur)
    body.ellip((0, 0, 0), BODY_R, (1.0, 0.95, 1.05))
    for sx in (-1, 1):
        body.ellip((sx * 0.13, 0.02, 0.27), 0.085, (0.65, 0.4, 1.5), rot=(0, math.radians(sx * 22), 0))
    bel = Piece("PipBelly", belly)
    bel.ellip((0, -0.12, -0.06), 0.12, (1.0, 0.55, 1.0))
    ins = Piece("PipEarIn", inner)
    for sx in (-1, 1):
        ins.ellip((sx * 0.13, -0.01, 0.27), 0.055, (0.6, 0.25, 1.3), rot=(0, math.radians(sx * 22), 0))
    wings = {}
    for side, sx in (("L", 1), ("R", -1)):
        w = Piece("PipWing." + side, wing)
        w.ellip((sx * 0.3, 0.05, 0.06), 0.15, (1.05, 0.75, 0.12))
        w.ellip((sx * 0.55, 0.07, 0.05), 0.15, (1.0, 0.85, 0.1))
        for k in range(3):  # scalloped trailing edge
            w.ball((sx * (0.36 + 0.13 * k), 0.15, 0.04), 0.055)
        wings[side] = w
    feet = Piece("PipFeet", inner)
    for sx in (-1, 1):
        feet.ellip((sx * 0.07, -0.01, -0.22), 0.045, (1.0, 1.2, 0.8))

    m = {
        "PipBody": body.build(voxel=0.008, target_faces=2400),
        "PipBelly": bel.build(voxel=0.008, target_faces=600),
        "PipEarIn": ins.build(voxel=0.006, target_faces=600),
        "PipFeet": feet.build(voxel=0.006, target_faces=400),
    }
    for side, w in wings.items():
        m["PipWing." + side] = w.build(voxel=0.008, target_faces=900)
    eyes = {}
    for sx, p in EYES:
        side = "L" if sx > 0 else "R"
        e = simple_sphere("PipEye." + side, tuple(p), 0.045, eye_m, (0.8, 0.5, 1.2))
        s = simple_sphere("PipShine." + side, tuple(p + Vector((-0.012, -0.025, 0.02))), 0.014, shine)
        eyes[side] = (e, s)
    fangs = [simple_sphere("PipFang%d" % i, (sx * 0.035, -0.185, -0.07), 0.018, fang, (0.7, 0.6, 1.4)) for i, sx in enumerate((-1, 1))]

    arm = make_armature("PipRig", BONES)
    skin(m["PipBody"], arm, ["body", "ear.L", "ear.R"], power=6)
    skin(m["PipBelly"], arm, [], rigid="body")
    skin(m["PipEarIn"], arm, ["ear.L", "ear.R"])
    skin(m["PipFeet"], arm, ["foot.L", "foot.R"])
    for side in ("L", "R"):
        skin(m["PipWing." + side], arm, ["wing1." + side, "wing2." + side])
        e, s = eyes[side]
        skin(e, arm, [], rigid="eye." + side)
        skin(s, arm, [], rigid="eye." + side)
    for f in fangs:
        skin(f, arm, [], rigid="body")
    return arm

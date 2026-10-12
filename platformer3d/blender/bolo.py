"""Bolo the red panda: vinyl-toy mesh, armature and skinning.

Built facing -Y (Blender front), z up, about 2 m tall with the ears. The pose rig uses
world-axis rotations (see anim.py): +X leans forward, +Z turns to the character's left.
"""
import math

import bpy
from mathutils import Vector

from vinyl import Piece, vinyl, simple_sphere, make_armature, skin

C = {
    "rust": "#c9562c",
    "cream": "#f4e6cc",
    "dark": "#3a2420",
    "eye": "#16121c",
    "nose": "#241414",
}

HEAD_C = Vector((0, -0.05, 1.45))
HEAD_R = 0.55


def eye_points():
    pts = []
    for sx in (-1, 1):
        a = math.radians(23) * sx
        d = Vector((math.sin(a), -math.cos(a), math.sin(math.radians(8)))).normalized()
        pts.append((sx, HEAD_C + d * (HEAD_R * 0.93)))
    return pts


BONES = [
    ("root", (0, 0, 0), (0, 0, 0.2), None),
    ("squash", (0, 0, 0), (0, 0, 0.25), "root"),
    ("hips", (0, 0, 0.45), (0, 0, 0.7), "squash"),
    ("spine", (0, 0, 0.7), (0, 0, 0.95), "hips"),
    ("chest", (0, 0, 0.95), (0, 0, 1.12), "spine"),
    ("head", (0, 0, 1.12), (0, 0, 1.75), "chest"),
]
for side, sx in (("L", 1), ("R", -1)):
    BONES += [
        ("ear." + side, (sx * 0.3, 0.0, 1.8), (sx * 0.4, 0.02, 2.06), "head"),
        ("arm_upper." + side, (sx * 0.36, -0.02, 1.0), (sx * 0.6, -0.06, 0.82), "chest"),
        ("arm_lower." + side, (sx * 0.6, -0.06, 0.82), (sx * 0.78, -0.1, 0.66), "arm_upper." + side),
        ("hand." + side, (sx * 0.78, -0.1, 0.66), (sx * 0.9, -0.14, 0.57), "arm_lower." + side),
        ("leg_upper." + side, (sx * 0.2, 0.0, 0.42), (sx * 0.22, -0.02, 0.23), "hips"),
        ("leg_lower." + side, (sx * 0.22, -0.02, 0.23), (sx * 0.23, -0.04, 0.09), "leg_upper." + side),
        ("foot." + side, (sx * 0.23, -0.04, 0.09), (sx * 0.24, -0.26, 0.06), "leg_lower." + side),
    ]
for sx, p in eye_points():
    side = "L" if sx > 0 else "R"
    q = p + (p - HEAD_C).normalized() * 0.12
    BONES.append(("eye." + side, tuple(p), tuple(q), "head"))


def tail_points(n):
    pts = []
    for i in range(n):
        t = i / (n - 1)
        ang = math.radians(-10 + 120 * t)
        pts.append(Vector((0.12 + 0.1 * t, 0.45 + 0.42 * math.cos(ang), 0.3 + 0.95 * math.sin(ang))))
    return pts


TP = tail_points(6)
for i in range(5):
    BONES.append(("tail%d" % (i + 1), tuple(TP[i]), tuple(TP[i + 1]), "hips" if i == 0 else "tail%d" % i))


def build():
    rust = vinyl("rust", C["rust"])
    cream = vinyl("cream", C["cream"])
    dark = vinyl("dark", C["dark"])
    eye_m = vinyl("eye", C["eye"], rough=0.06, coat=1.0)
    shine = vinyl("shine", "#ffffff", rough=0.2, coat=0.0)
    nose_m = vinyl("nose", C["nose"], rough=0.12, coat=1.0)

    body = Piece("Body", rust)
    body.ellip((0, 0, 0.62), 0.5, (1.0, 0.9, 1.1))

    head = Piece("Head", rust)
    head.ball(tuple(HEAD_C), HEAD_R)
    for sx in (-1, 1):
        head.ellip((sx * 0.47, -0.12, 1.32), 0.2, (1.2, 0.8, 0.8))
        head.ellip((sx * 0.36, 0.02, 1.93), 0.18, (1.0, 0.5, 1.15), rot=(0, math.radians(sx * 20), 0))

    face = Piece("Face", cream)
    face.ellip((0, -0.5, 1.32), 0.2, (1.35, 0.8, 0.8))
    for sx in (-1, 1):
        face.ball((sx * 0.22, -0.47, 1.66), 0.08)
        face.ellip((sx * 0.36, -0.04, 1.92), 0.11, (1.0, 0.4, 1.0), rot=(0, math.radians(sx * 20), 0))

    belly = Piece("Belly", cream)
    belly.ellip((0, -0.36, 0.62), 0.3, (1.0, 0.45, 1.25))

    limbs = {}
    for side, sx in (("L", 1), ("R", -1)):
        a = Piece("Arm." + side, dark)
        a.caps((sx * 0.36, -0.02, 1.0), (sx * 0.6, -0.06, 0.82), 0.12, 0.11)
        a.caps((sx * 0.6, -0.06, 0.82), (sx * 0.8, -0.1, 0.64), 0.11, 0.135)
        a.ellip((sx * 0.84, -0.12, 0.6), 0.14, (1.0, 1.0, 0.9))
        limbs["Arm." + side] = a
        lg = Piece("Leg." + side, dark)
        lg.caps((sx * 0.2, 0.0, 0.4), (sx * 0.22, -0.02, 0.22), 0.16, 0.15)
        lg.caps((sx * 0.22, -0.02, 0.22), (sx * 0.23, -0.04, 0.1), 0.15, 0.14)
        lg.ellip((sx * 0.24, -0.14, 0.07), 0.15, (1.0, 1.45, 0.6))
        limbs["Leg." + side] = lg

    rings = []
    for i, p in enumerate(tail_points(8)):
        r = Piece("Tail%d" % i, rust if i % 2 == 0 else cream)
        r.ball(tuple(p), 0.22 - 0.01 * i)
        rings.append(r)

    meshes = {
        "Body": body.build(target_faces=2600),
        "Head": head.build(target_faces=4200),
        "Face": face.build(voxel=0.015, target_faces=1600),
        "Belly": belly.build(target_faces=900),
    }
    for k, p in limbs.items():
        meshes[k] = p.build(voxel=0.016, target_faces=1000)
    tail_meshes = [r.build(voxel=0.018, target_faces=500) for r in rings]

    eyes = {}
    for sx, p in eye_points():
        side = "L" if sx > 0 else "R"
        e = simple_sphere("Eye." + side, tuple(p), 0.098, eye_m, (0.8, 0.5, 1.2))
        s = simple_sphere("Shine." + side, tuple(p + Vector((-0.03, -0.05, 0.045))), 0.03, shine)
        eyes[side] = (e, s)
    nose = simple_sphere("Nose", (0, -0.66, 1.38), 0.075, nose_m, (1.3, 1.0, 0.85))

    arm = make_armature("BoloRig", BONES)
    skin(meshes["Body"], arm, ["hips", "spine", "chest"])
    skin(meshes["Belly"], arm, ["hips", "spine", "chest"])
    skin(meshes["Head"], arm, ["head", "ear.L", "ear.R"], power=6)
    skin(meshes["Face"], arm, ["head", "ear.L", "ear.R"], power=6)
    for side in ("L", "R"):
        skin(meshes["Arm." + side], arm, ["arm_upper." + side, "arm_lower." + side, "hand." + side])
        skin(meshes["Leg." + side], arm, ["leg_upper." + side, "leg_lower." + side, "foot." + side])
        e, s = eyes[side]
        skin(e, arm, [], rigid="eye." + side)
        skin(s, arm, [], rigid="eye." + side)
    skin(nose, arm, [], rigid="head")
    for t in tail_meshes:
        skin(t, arm, ["tail%d" % (i + 1) for i in range(5)])
    return arm

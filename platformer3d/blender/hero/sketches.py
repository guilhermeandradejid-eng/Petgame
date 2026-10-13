"""Cheap silhouette sketches (no fur): three chubby proportion variants, front and profile.

    /opt/bpyenv/bin/python sketches.py -- out.png
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from vinyl import Piece, hexc  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, color, rough=0.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = hexc(color)
    b.inputs["Roughness"].default_value = rough
    return m


M = {k: mat(k, c) for k, c in {
    "rust": "#c4561f", "cream": "#efe3cf", "dark": "#3b2015", "boot": "#7a4a2c",
    "teal": "#2f6f73", "brass": "#c9a24a", "bag": "#5a3320", "owl": "#6b5038", "eye": "#141010"}.items()}


def character(x0, head_r, head_z, belly_r, belly_z, leg_len, arm_len, tail=True):
    """A chubby red panda: big head, ball belly, short legs, mittens with thumb, soft boots."""
    o = Vector((x0, 0, 0))
    ank = 0.09
    hip_z = ank + leg_len
    body = Piece("body%s" % x0, M["rust"])
    body.ellip(tuple(o + Vector((0, -0.01, head_z))), head_r, (1.1, 1.0, 0.96))
    body.ellip(tuple(o + Vector((0, -0.02, belly_z))), belly_r, (1.0, 0.95, 1.05))       # the belly ball
    body.caps(tuple(o + Vector((0, 0, belly_z + belly_r * 0.6))), tuple(o + Vector((0, 0, head_z - head_r * 0.7))), belly_r * 0.55)
    for sx in (-1, 1):
        body.ellip(tuple(o + Vector((sx * head_r * 0.8, 0.0, head_z + head_r * 0.82))), head_r * 0.36, (1.0, 0.42, 1.2),
                   rot=(0, math.radians(-sx * 28), 0))
    if tail:
        for k in range(6):
            t = k / 5
            body.ball(tuple(o + Vector((0.04 * t, belly_r * 0.8 + 0.35 * t, belly_z - 0.1 + 0.5 * t * t))), belly_r * (0.45 - 0.12 * t))
    body.build(voxel=0.008, smooth=8)
    face = Piece("face%s" % x0, M["cream"])
    face.ellip(tuple(o + Vector((0, -head_r * 0.95, head_z - head_r * 0.25))), head_r * 0.36, (1.15, 0.85, 0.8))
    face.ellip(tuple(o + Vector((0, -belly_r * 0.62, belly_z - 0.01))), belly_r * 0.7, (1.0, 0.5, 1.05))   # cream belly patch
    for sx in (-1, 1):
        face.ball(tuple(o + Vector((sx * head_r * 0.62, -head_r * 0.7, head_z - head_r * 0.3))), head_r * 0.24)
    face.build(voxel=0.006, smooth=6)
    limbs = Piece("limbs%s" % x0, M["dark"])
    sh_z = belly_z + belly_r * 0.55
    for sx in (-1, 1):
        sh = o + Vector((sx * belly_r * 0.85, 0, sh_z))
        hand = sh + Vector((sx * arm_len * 0.55, -0.05, -arm_len * 0.8))
        limbs.caps(tuple(sh), tuple(hand), 0.045, 0.05)
        hip = o + Vector((sx * belly_r * 0.42, 0, hip_z))
        limbs.caps(tuple(hip), tuple(o + Vector((sx * belly_r * 0.45, 0, ank + 0.02))), 0.06, 0.055)
    limbs.build(voxel=0.006, smooth=6)
    mitt = Piece("mitt%s" % x0, M["dark"])
    for sx in (-1, 1):
        sh = o + Vector((sx * belly_r * 0.85, 0, sh_z))
        hand = sh + Vector((sx * arm_len * 0.55, -0.05, -arm_len * 0.8))
        mitt.ellip(tuple(hand + Vector((sx * 0.01, -0.01, -0.03))), 0.07, (0.85, 0.8, 1.1))          # mitten block
        mitt.ellip(tuple(hand + Vector((-sx * 0.035, -0.045, -0.005))), 0.03, (0.8, 0.8, 1.2))      # thumb
    mitt.build(voxel=0.005, smooth=6)
    boots = Piece("boots%s" % x0, M["boot"])
    for sx in (-1, 1):
        a = o + Vector((sx * belly_r * 0.45, 0, ank))
        boots.ellip(tuple(a + Vector((0, -0.05, -0.02))), 0.085, (0.95, 1.4, 0.7))
        boots.caps(tuple(a + Vector((0, 0.0, 0.0))), tuple(a + Vector((0, 0, 0.07))), 0.07, 0.072)
    boots.build(voxel=0.006, smooth=8)
    scarf = Piece("scarf%s" % x0, M["teal"])
    nz = head_z - head_r * 0.85
    for k in range(14):
        a = k / 14 * math.tau
        scarf.ball(tuple(o + Vector((math.cos(a) * belly_r * 0.62, math.sin(a) * belly_r * 0.58 - 0.01, nz))), 0.045)
    scarf.caps(tuple(o + Vector((belly_r * 0.35, -belly_r * 0.55, nz))), tuple(o + Vector((belly_r * 0.45, -belly_r * 0.75, nz - 0.18))), 0.04)
    scarf.build(voxel=0.006, smooth=6)
    bag = Piece("bag%s" % x0, M["bag"])
    bag.ellip(tuple(o + Vector((-belly_r * 0.8, -0.04, belly_z - belly_r * 0.45))), 0.085, (0.75, 0.55, 0.85))
    bag.caps(tuple(o + Vector((-belly_r * 0.75, -belly_r * 0.75, belly_z - belly_r * 0.3))),
             tuple(o + Vector((belly_r * 0.5, -belly_r * 0.7, belly_z + belly_r * 0.9))), 0.014)
    bag.build(voxel=0.005, smooth=4)
    gog = Piece("gog%s" % x0, M["brass"])
    for sx in (-1, 1):
        gog.ellip(tuple(o + Vector((sx * head_r * 0.36, -head_r * 0.82, head_z + head_r * 0.48))), head_r * 0.2, (1, 0.5, 1))
    gog.build(voxel=0.005, smooth=4)
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=head_r * 0.17, location=o + Vector((sx * head_r * 0.38, -head_r * 0.86, head_z + head_r * 0.08)))
        e = bpy.context.active_object
        e.scale = (0.8, 0.6, 1.05)
        e.data.materials.append(M["eye"])
    owl = Piece("owl%s" % x0, M["owl"])
    top = o + Vector((0, 0.01, head_z + head_r * 0.95 + 0.07))
    owl.ellip(tuple(top), 0.075, (1.05, 0.95, 1.0))
    owl.ellip(tuple(top + Vector((0, 0, 0.08))), 0.065, (1.15, 1.0, 0.9))
    for sx in (-1, 1):
        owl.ellip(tuple(top + Vector((sx * 0.045, 0, 0.14))), 0.02, (0.6, 0.5, 1.4))
    owl.build(voxel=0.004, smooth=4)


# three proportion variants, all chubby
VARIANTS = [
    ("A  Mario", dict(head_r=0.24, head_z=1.0, belly_r=0.24, belly_z=0.5, leg_len=0.14, arm_len=0.3)),
    ("B  Ursinho", dict(head_r=0.28, head_z=0.95, belly_r=0.27, belly_z=0.44, leg_len=0.08, arm_len=0.24)),
    ("C  Aventureiro", dict(head_r=0.22, head_z=1.06, belly_r=0.21, belly_z=0.56, leg_len=0.22, arm_len=0.34)),
]
for i, (_, kw) in enumerate(VARIANTS):
    character(-1.4 + i * 1.4, **kw)

w = bpy.data.worlds.new("w")
scene.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = hexc("#dfe3ea")
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 4.4
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "CYCLES"
scene.cycles.samples = 12
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1500, 600
scene.view_settings.view_transform = "Standard"
paths = []
for name, rot in (("front", 0), ("side", -90)):
    a = math.radians(rot)
    for o in scene.objects:
        if o.type in ("MESH",):
            pass
    # turn every character in place for the profile view
    for i in range(3):
        x0 = -1.4 + i * 1.4
        for o in scene.objects:
            if o.type == "MESH" and abs(o.matrix_world.translation.x - x0) < 0.7:
                pass
    cam.location = (0, -6, 0.75)
    cam.rotation_euler = (math.radians(90), 0, 0)
    if rot:
        # rotate each mesh about its own character centre
        for i in range(3):
            x0 = -1.4 + i * 1.4
            piv = bpy.data.objects.new("piv%d" % i, None)
            piv.location = (x0, 0, 0)
            scene.collection.objects.link(piv)
            for o in list(scene.objects):
                if o.type == "MESH" and o.parent is None:
                    c = o.matrix_world @ Vector(o.bound_box[0]) * 0.5 + o.matrix_world @ Vector(o.bound_box[6]) * 0.5
                    if abs(c.x - x0) < 0.7:
                        mw = o.matrix_world.copy()
                        o.parent = piv
                        o.matrix_world = mw
            piv.rotation_euler.z = a
    p = OUT.replace(".png", "_%s.png" % name)
    scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    paths.append(p)
print("done", paths)

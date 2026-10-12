"""Concept lineup: three vinyl-toy character proposals, blocked out with metaballs.

    /opt/bpyenv/bin/python concepts.py -- out_dir [samples]
Renders lineup.png (lit) and silhouettes.png (pure black on white, to check readability).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else "."
SAMPLES = int(args[1]) if len(args) > 1 else 96

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
col = scene.collection


def hexc(h, a=1.0):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, a)


MATS = {}


def vinyl(name, color, rough=0.34, coat=0.7, sss=0.05):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = hexc(color)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = 0.18
    b.inputs["Subsurface Weight"].default_value = sss
    b.inputs["Subsurface Radius"].default_value = (0.3, 0.15, 0.1)
    b.inputs["Subsurface Scale"].default_value = 0.05
    MATS[name] = m
    return m


FAMILY = {}


def blob(family, mat, x0=0.0):
    """A group of primitives that will be fused into one soft vinyl piece (voxel remesh + smooth)."""
    if family not in FAMILY:
        FAMILY[family] = {"mat": mat, "x0": x0, "objs": []}
    return FAMILY[family]


def _add(fam, o):
    f = FAMILY[fam]
    o.location.x += f["x0"]
    f["objs"].append(o)
    return o


def ball(fam, p, r, stiff=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=p, segments=32, ring_count=16)
    return _add(fam, bpy.context.active_object)


def ellip(fam, p, r, sx, sy, sz, stiff=None, rot=None):
    o = ball(fam, p, r)
    o.scale = (sx, sy, sz)
    if rot is not None:
        o.rotation_euler = rot
    return o


def caps(fam, a, b, r, stiff=None, r2=None):
    a, b = Vector(a), Vector(b)
    r2 = r if r2 is None else r2
    d = b - a
    bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=d.length, vertices=32, location=(a + b) / 2)
    o = bpy.context.active_object
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
    _add(fam, o)
    ball(fam, tuple(a), r)
    ball(fam, tuple(b), r2)
    return o


def fuse_all(voxel=0.016):
    for name, f in FAMILY.items():
        objs = f["objs"]
        if not objs:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        o = bpy.context.active_object
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        m = o.modifiers.new("remesh", "REMESH")
        m.mode = "VOXEL"
        m.voxel_size = voxel
        bpy.ops.object.modifier_apply(modifier="remesh")
        sm = o.modifiers.new("smooth", "SMOOTH")
        sm.factor = 0.8
        sm.iterations = 8
        bpy.ops.object.modifier_apply(modifier="smooth")
        o.data.materials.clear()
        o.data.materials.append(f["mat"])
        bpy.ops.object.shade_smooth()
        o.name = name


def sphere(p, r, mat, scale=(1, 1, 1), x0=0.0, seg=32):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(p[0] + x0, p[1], p[2]), segments=seg, ring_count=seg // 2)
    o = bpy.context.active_object
    o.scale = scale
    o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return o


def leaf(p, length, width, mat, rot, x0=0.0):
    o = sphere(p, 1.0, mat, (length, width, 0.05), x0)
    o.rotation_euler = rot
    return o


def eyes(head, r_head, spacing, size, x0, tilt=0.0, height=0.0):
    black = vinyl("eye", "#16121c", rough=0.08, coat=1.0)
    white = vinyl("eyeshine", "#ffffff", rough=0.2, coat=0.0)
    for sx in (-1, 1):
        a = math.radians(spacing) * sx
        d = Vector((math.sin(a), -math.cos(a), math.sin(math.radians(height))))
        d.normalize()
        c = Vector(head) + d * (r_head * 0.93)
        sphere(c, size, black, (0.8, 0.55, 1.0 + tilt), x0)
        sphere(c + Vector((0.25 * size * sx * -0.3 - 0.2 * size, -0.45 * size, 0.35 * size)), size * 0.28, white, (1, 1, 1), x0)


# ---------------------------------------------------------------------------- A: Bolo & Pip

def bolo(x0):
    rust = vinyl("rust", "#c9562c")
    cream = vinyl("cream", "#f4e6cc")
    dark = vinyl("darkfur", "#3a2420")
    teal = vinyl("pack", "#2f8f8a", rough=0.45)
    bat = vinyl("bat", "#6d4ba3")
    batin = vinyl("batin", "#e7a6c4")
    blob("BoloBody", rust)
    ellip("BoloBody", (0, 0, 0.62), 0.5, 1.0, 0.9, 1.1)            # pear body
    ball("BoloBody", (0, -0.05, 1.45), 0.55)                        # big head
    for sx in (-1, 1):
        ellip("BoloBody", (sx * 0.47, -0.12, 1.32), 0.2, 1.2, 0.8, 0.8)   # cheek fluff
        ellip("BoloBody", (sx * 0.36, 0.02, 1.93), 0.18, 1.0, 0.5, 1.15, rot=(0, math.radians(sx * 20), 0))  # ears
    blob("BoloLimb", dark)
    for sx in (-1, 1):
        caps("BoloLimb", (sx * 0.4, -0.05, 0.95), (sx * 0.56, -0.2, 0.58), 0.13, r2=0.16)
        caps("BoloLimb", (sx * 0.22, 0.0, 0.3), (sx * 0.24, -0.06, 0.1), 0.17)
        ellip("BoloLimb", (sx * 0.24, -0.16, 0.08), 0.15, 1.0, 1.4, 0.6)
    blob("BoloFace", cream)
    ellip("BoloFace", (0, -0.5, 1.32), 0.2, 1.35, 0.8, 0.8)         # muzzle
    for sx in (-1, 1):
        ball("BoloFace", (sx * 0.22, -0.47, 1.66), 0.08)             # brow spots
        ellip("BoloFace", (sx * 0.36, -0.04, 1.92), 0.11, 1.0, 0.4, 1.0, rot=(0, math.radians(sx * 20), 0))
    ellip("BoloFace", (0, -0.36, 0.62), 0.3, 1.0, 0.45, 1.25)       # belly
    sphere((0, -0.66, 1.38), 0.075, vinyl("nose", "#241414", rough=0.15), (1.3, 1, 0.85), x0)
    eyes((0, -0.05, 1.45), 0.55, 23, 0.075, x0, height=8)
    for i in range(8):  # ringed tail curling up behind, alternating colours
        t = i / 7
        ang = math.radians(-10 + 120 * t)
        p = (0.12 + 0.1 * t, 0.45 + 0.42 * math.cos(ang), 0.3 + 0.95 * math.sin(ang))
        fam = "TailA" if i % 2 == 0 else "TailB"
        blob(fam, rust if i % 2 == 0 else cream)
        ball(fam, p, 0.22 - 0.01 * i)
    blob("Pack", teal)
    ellip("Pack", (0, 0.48, 0.95), 0.32, 1.05, 0.7, 1.05)
    for sx in (-1, 1):
        caps("Pack", (sx * 0.3, 0.3, 1.18), (sx * 0.34, -0.3, 0.95), 0.05)   # straps
    # Pip the bat rides the pack and peeks over Bolo's shoulder
    blob("Pip", bat)
    ball("Pip", (0.42, 0.3, 1.38), 0.2)
    for sx in (-1, 1):
        ellip("Pip", (0.42 + sx * 0.14, 0.32, 1.6), 0.1, 0.6, 0.35, 1.5, rot=(0, math.radians(sx * 18), 0))
        ellip("Pip", (0.42 + sx * 0.26, 0.42, 1.18), 0.2, 0.45, 1.0, 1.3)   # folded wings
    blob("PipIn", batin)
    ellip("PipIn", (0.42, 0.13, 1.33), 0.08, 1.2, 0.5, 0.7)
    eyes((0.42, 0.3, 1.38), 0.2, 26, 0.04, x0, height=12)


def tatu(x0):
    shell = vinyl("shell", "#d8a443")
    band = vinyl("band", "#a46a2b")
    skin = vinyl("skin", "#e9b59d")
    leafm = vinyl("leaf", "#5db34d", rough=0.4)
    scarf = vinyl("scarf", "#e2483a")
    blob("TatuSkin", skin)
    ellip("TatuSkin", (0, 0, 0.82), 0.52, 1.1, 0.9, 1.05)           # torso core
    ball("TatuSkin", (0, -0.2, 1.55), 0.36)                          # small head, set forward
    caps("TatuSkin", (0, -0.45, 1.5), (0, -0.78, 1.42), 0.17, r2=0.11)  # long snout
    for sx in (-1, 1):
        ellip("TatuSkin", (sx * 0.2, -0.12, 1.95), 0.14, 0.55, 0.35, 1.5, rot=(0, math.radians(sx * 12), 0))
        caps("TatuSkin", (sx * 0.6, -0.02, 1.15), (sx * 0.84, -0.16, 0.72), 0.17)    # heavy arms
        caps("TatuSkin", (sx * 0.84, -0.16, 0.72), (sx * 0.9, -0.3, 0.38), 0.19, r2=0.22)
        ball("TatuSkin", (sx * 0.92, -0.34, 0.3), 0.27)                              # big fists
        caps("TatuSkin", (sx * 0.3, 0.0, 0.42), (sx * 0.32, -0.04, 0.12), 0.18)
        ellip("TatuSkin", (sx * 0.32, -0.16, 0.08), 0.17, 1.0, 1.5, 0.55)
    blob("TatuBelly", vinyl("belly", "#f3d3c2"))
    ellip("TatuBelly", (0, -0.4, 0.8), 0.32, 1.1, 0.5, 1.3)
    for i in range(6):  # banded shell over the back
        t = i / 5
        z = 0.38 + 0.82 * t
        r = 0.6 - 0.18 * abs(t - 0.4) * 1.6
        fam = "ShellA" if i % 2 == 0 else "ShellB"
        blob(fam, shell if i % 2 == 0 else band)
        ellip(fam, (0, 0.16, z), r, 1.1, 0.95, 0.24)
    blob("ShellA", shell)
    ellip("ShellA", (0, -0.12, 1.8), 0.24, 1.0, 1.1, 0.45)           # head plate
    sphere((0, -0.9, 1.43), 0.07, vinyl("nose", "#241414"), (1.3, 1, 1), x0)
    eyes((0, -0.2, 1.55), 0.36, 32, 0.06, x0, height=12)
    blob("Scarf", scarf)
    for k in range(12):
        a = k / 12 * math.tau
        ball("Scarf", (math.cos(a) * 0.38, math.sin(a) * 0.34 - 0.12, 1.28), 0.12)
    caps("Scarf", (0.18, 0.2, 1.25), (0.32, 0.5, 0.95), 0.1, r2=0.07)
    leaf((0, 0.7, 1.05), 0.6, 0.32, leafm, (math.radians(72), 0, 0), x0)       # leaf glider on the back
    sphere((0, 0.55, 1.5), 0.04, vinyl("stem", "#4c7a2c"), (1, 1, 4), x0)


# ---------------------------------------------------------------------------- C: Nino

def nino(x0):
    skin = vinyl("skinc", "#f6c7a4")
    shirt = vinyl("shirt", "#f2c230")
    over = vinyl("over", "#3d6fd6")
    boot = vinyl("boot", "#d8433a")
    leafm = vinyl("leafc", "#62c44a", rough=0.38)
    hair = vinyl("hair", "#6b3d25")
    blob("NinoSkin", skin, x0)
    ball("NinoSkin", (0, 0, 1.33), 0.5)                            # head ~45% of height
    ball("NinoSkin", (0, -0.5, 1.26), 0.12)                        # round nose
    for sx in (-1, 1):
        ball("NinoSkin", (sx * 0.5, 0.0, 1.3), 0.1)               # ears
        ball("NinoSkin", (sx * 0.5, -0.08, 0.5), 0.12)            # hands
    blob("Shirt", shirt, x0)
    ellip("Shirt", (0, 0, 0.72), 0.34, 1.0, 0.85, 0.9)
    for sx in (-1, 1):
        caps("Shirt", (sx * 0.26, 0, 0.84), (sx * 0.46, -0.05, 0.58), 0.1)
    blob("Over", over, x0)
    ellip("Over", (0, -0.02, 0.48), 0.34, 1.05, 0.9, 0.75)
    for sx in (-1, 1):
        caps("Over", (sx * 0.15, 0, 0.36), (sx * 0.17, -0.02, 0.16), 0.13)
    blob("Boot", boot, x0)
    for sx in (-1, 1):
        ellip("Boot", (sx * 0.18, -0.08, 0.08), 0.16, 1.0, 1.4, 0.7)
    blob("Hair", hair, x0)
    ellip("Hair", (0, 0.05, 1.62), 0.42, 1.15, 1.05, 0.55)
    eyes((0, 0, 1.33), 0.5, 20, 0.08, x0, tilt=0.5, height=8)
    # propeller hat: stem and two big leaves
    sphere((0, 0, 1.92), 0.05, vinyl("stemc", "#4c7a2c"), (1, 1, 3), x0)
    for a in (20, 200):
        r = math.radians(a)
        leaf((math.cos(r) * 0.36, math.sin(r) * 0.36, 2.08), 0.42, 0.17, leafm, (0, math.radians(-8 if a < 90 else 8), r), x0)


# ---------------------------------------------------------------------------- stage

def stage():
    ground = vinyl("ground", "#bfe3d0", rough=0.6, coat=0.0)
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    bpy.context.active_object.data.materials.append(ground)
    ped = vinyl("ped", "#f7f1e6", rough=0.5, coat=0.2)
    for x in (-2.6, 0, 2.6):
        bpy.ops.mesh.primitive_cylinder_add(radius=1.05, depth=0.12, location=(x, 0, 0.06), vertices=64)
        o = bpy.context.active_object
        o.data.materials.append(ped)
        bpy.ops.object.shade_smooth()
    w = bpy.data.worlds.new("w")
    scene.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = hexc("#cfe9ff")
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    def light(name, kind, loc, energy, size, color="#ffffff"):
        ld = bpy.data.lights.new(name, kind)
        ld.energy = energy
        ld.color = hexc(color)[:3]
        if kind == "AREA":
            ld.size = size
        o = bpy.data.objects.new(name, ld)
        o.location = loc
        o.rotation_euler = (Vector((0, 0, 0.8)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        col.objects.link(o)
    light("key", "AREA", (-4, -6, 6), 900, 5, "#fff3e0")
    light("rim", "AREA", (4, 5, 4), 600, 4, "#cfe0ff")
    light("fill", "AREA", (5, -6, 2), 250, 6, "#ffe6f0")
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 55
    cam.location = (0.6, -11.5, 3.1)
    cam.rotation_euler = (Vector((0, 0, 1.0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    col.objects.link(cam)
    scene.camera = cam


def build(fn, x0, yaw):
    before = set(bpy.data.objects)
    FAMILY.clear()
    fn(0.0)
    fuse_all()
    pivot = bpy.data.objects.new("pivot_" + fn.__name__, None)
    col.objects.link(pivot)
    for o in set(bpy.data.objects) - before:
        if o is not pivot:
            o.parent = pivot
    pivot.location.x = x0
    pivot.rotation_euler.z = math.radians(yaw)


build(bolo, -2.6, -28)
build(tatu, 0.0, -20)
build(nino, 2.6, -28)
stage()

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
scene.render.resolution_x = 1600
scene.render.resolution_y = 760
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.render.filepath = os.path.join(OUT, "lineup.png")
bpy.ops.render.render(write_still=True)

# silhouettes: every character material black, no ground, white background
sil = vinyl("sil", "#000000", rough=1.0, coat=0.0)
for o in list(scene.objects):
    if o.type in ("MESH", "META"):
        if o.data.materials and o.data.materials[0].name in ("ground", "ped"):
            o.hide_render = True
            continue
        for i in range(len(o.data.materials)):
            o.data.materials[i] = sil
for o in scene.objects:
    if o.type == "LIGHT":
        o.hide_render = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.cycles.samples = 8
scene.render.resolution_x = 800
scene.render.resolution_y = 380
scene.render.filepath = os.path.join(OUT, "silhouettes.png")
bpy.ops.render.render(write_still=True)
print("done")

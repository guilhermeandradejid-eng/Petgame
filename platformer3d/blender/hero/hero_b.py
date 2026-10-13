"""Bolo v2, variant B ("ursinho"): big head, ball belly, almost no legs, accessories only.

    /opt/bpyenv/bin/python hero_b.py -- out_dir [samples] [views] [fur_density]
Reuses the materials and fur helpers from hero.py with the chosen proportions.
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hero as H  # noqa: E402  (parses the same argv and resets the scene)
from vinyl import Piece  # noqa: E402

# ----------------------------------------------------------------------------- proportions (variant B)
HEAD = Vector((0, -0.01, 0.95))
HEAD_R = 0.28
HEAD_S = Vector((1.1, 1.0, 0.96))
BELLY = Vector((0, -0.02, 0.44))
BELLY_R = 0.27
BELLY_S = Vector((1.0, 0.95, 1.05))
EYE_R = 0.066


def on_head(yaw_deg, pitch_deg, lift=0.0):
    y, p = math.radians(yaw_deg), math.radians(pitch_deg)
    d = Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p)))
    s = Vector((d.x * HEAD_S.x, d.y * HEAD_S.y, d.z * HEAD_S.z))
    return HEAD + s * (HEAD_R + lift), s.normalized()


def on_belly(yaw_deg, pitch_deg, lift=0.0):
    y, p = math.radians(yaw_deg), math.radians(pitch_deg)
    d = Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p)))
    s = Vector((d.x * BELLY_S.x, d.y * BELLY_S.y, d.z * BELLY_S.z))
    return BELLY + s * (BELLY_R + lift), s.normalized()


EYES = [on_head(sx * 24, 4, -0.05)[0] for sx in (-1, 1)]
MUZZLE = on_head(0, -16, -0.03)[0]
NOSE = MUZZLE + Vector((0, -0.085, 0.03))
EARS = [on_head(sx * 52, 50, -0.02)[0] for sx in (-1, 1)]
SHOULDER = [Vector((sx * 0.22, -0.01, 0.6)) for sx in (-1, 1)]
HAND = [Vector((sx * 0.355, -0.06, 0.4)) for sx in (-1, 1)]
LEG_TOP = [Vector((sx * 0.12, 0.0, 0.22)) for sx in (-1, 1)]
ANKLE = [Vector((sx * 0.125, -0.01, 0.1)) for sx in (-1, 1)]
TAIL = [Vector(p) for p in ((0, 0.2, 0.3), (0.02, 0.38, 0.28), (0.05, 0.54, 0.38), (0.08, 0.64, 0.56), (0.08, 0.66, 0.74), (0.06, 0.62, 0.88))]
TAIL_R = [0.07, 0.09, 0.1, 0.095, 0.08, 0.055]


def tail_param(p):
    best, bt = 9.0, 0.0
    for i in range(len(TAIL) - 1):
        d, t = H.seg_dist(p, TAIL[i], TAIL[i + 1])
        if d < best:
            best, bt = d, (i + t) / (len(TAIL) - 1)
    return best, bt


# ----------------------------------------------------------------------------- body

def build_body():
    skin = H.mat_skin("skin", "#8a3416")
    p = Piece("Body", skin)
    p.ellip(tuple(HEAD), HEAD_R, tuple(HEAD_S))
    p.ellip(tuple(HEAD + Vector((0, -0.05, -0.1))), 0.2, (1.3, 0.95, 0.72))   # cheeks and jaw
    p.ellip(tuple(MUZZLE), 0.09, (1.2, 1.0, 0.72))
    for sx in (-1, 1):
        bc, _ = on_head(sx * 22, 22, -0.035)
        p.ellip(tuple(bc), 0.06, (1.3, 0.8, 0.55))
        e = EARS[0 if sx < 0 else 1]
        p.ellip(tuple(e), 0.1, (1.0, 0.45, 1.15), rot=(0, math.radians(-sx * 30), 0))
    p.ellip(tuple(BELLY), BELLY_R, tuple(BELLY_S))
    p.caps(tuple(BELLY + Vector((0, 0, 0.18))), tuple(HEAD + Vector((0, 0, -0.18))), 0.15)
    for i in range(2):
        p.caps(tuple(SHOULDER[i]), tuple(HAND[i]), 0.05, 0.046)
        p.caps(tuple(LEG_TOP[i]), tuple(ANKLE[i]), 0.07, 0.06)
    for i in range(len(TAIL) - 1):
        p.caps(tuple(TAIL[i]), tuple(TAIL[i + 1]), TAIL_R[i] * 0.7, TAIL_R[i + 1] * 0.7)
    return p.build(voxel=0.005, smooth=10, target_faces=70000)


def region_weights(o):
    groups = {n: o.vertex_groups.new(name=n) for n in ("rust", "cream", "dark", "ochre", "len")}
    brows = [on_head(sx * 20, 24, 0)[0] for sx in (-1, 1)]
    cheeks = [on_head(sx * 55, -16, 0)[0] for sx in (-1, 1)]
    tear_a = [on_head(sx * 22, -8, 0)[0] for sx in (-1, 1)]
    tear_b = [on_head(sx * 13, -30, 0)[0] for sx in (-1, 1)]
    belly_c = on_belly(0, -5, 0)[0]
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        w = {"rust": 1.0, "cream": 0.0, "dark": 0.0, "ochre": 0.0}
        length = 0.8
        d_eye = min((p - e).length for e in EYES)
        td, tt = tail_param(p)
        on_tail = td < 0.12 and p.y > 0.18
        limb = any(H.seg_dist(p, SHOULDER[i], HAND[i])[0] < 0.075 and p.x * SHOULDER[i].x > 0 and abs(p.x) > 0.21 for i in range(2)) \
            or any(H.seg_dist(p, LEG_TOP[i], ANKLE[i])[0] < 0.09 and p.z < 0.22 for i in range(2))
        if on_tail:
            ring = int(tt * 8) % 2 == 1
            w = {"rust": 0.0 if ring else 1.0, "cream": 0.0, "dark": 0.0, "ochre": 1.0 if ring else 0.0}
            length = 2.2 if tt < 0.9 else 1.4
        elif limb:
            w = {"rust": 0.0, "cream": 0.0, "dark": 1.0, "ochre": 0.0}
            length = 0.55
        elif p.z > 0.7:
            mz = Vector(((p.x - MUZZLE.x) / 0.11, (p.y - MUZZLE.y) / 0.1, (p.z - MUZZLE.z) / 0.075)).length
            brow = min((p - c).length for c in brows)
            cheek = min((p - c).length for c in cheeks)
            tear = min(H.seg_dist(p, tear_a[k], tear_b[k])[0] for k in range(2))
            ear_i = 0 if p.x < 0 else 1
            ear_d = (p - EARS[ear_i]).length
            if tear < 0.022 and p.y < -0.12:
                w = {"rust": 0.0, "cream": 0.0, "dark": 1.0, "ochre": 0.0}
                length = 0.35
            elif mz < 1.15 or brow < 0.04 or cheek < 0.075:
                w = {"rust": 0.0, "cream": 1.0, "dark": 0.0, "ochre": 0.0}
                length = 0.3 if mz < 1.15 else (0.35 if brow < 0.04 else 0.9)
            elif ear_d < 0.15 and p.z > 1.05:
                rim = ear_d > 0.095 or p.y < EARS[ear_i].y - 0.02
                w = {"rust": 0.0 if rim else 1.0, "cream": 1.0 if rim else 0.0, "dark": 0.0, "ochre": 0.0}
                length = 0.4 if rim else 0.3
            else:
                length = 0.5 if p.z > 1.0 else 0.75
        else:
            # belly: soft cream patch on the front of the ball
            q = Vector(((p.x - belly_c.x) / 0.2, (p.y - belly_c.y) / 0.2, (p.z - belly_c.z) / 0.22))
            if q.length < 1.0 and p.y < BELLY.y - 0.12:
                w = {"rust": 0.0, "cream": 1.0, "dark": 0.0, "ochre": 0.0}
                length = 0.6
        if d_eye < EYE_R + 0.012 or (p - NOSE).length < 0.045 or p.z < 0.16:
            w = {k: 0.0 for k in w}
        elif d_eye < EYE_R + 0.035:
            length *= 0.3
        for n, val in w.items():
            groups[n].add([v.index], val, "REPLACE")
        groups["len"].add([v.index], min(length / 2.2, 1.0), "REPLACE")


# ----------------------------------------------------------------------------- face

def build_eyes():
    eye_m = H.mat_eye("eye", iris="#7a3d12", ring="#1e0d05", radius=EYE_R)
    cornea = H.mat_glass("cornea", "#ffffff")
    for e in EYES:
        d = ((e - HEAD).normalized() + Vector((0, -1.6, 0))).normalized()
        rot = Vector((0, -1, 0)).rotation_difference(d).to_euler()
        ball = H.uv_sphere("Eye", tuple(e), EYE_R, eye_m, seg=48)
        ball.rotation_euler = rot
        c = H.uv_sphere("Cornea", tuple(e + d * 0.005), EYE_R * 1.04, cornea, seg=48)
        c.rotation_euler = rot
        bpy.ops.mesh.primitive_uv_sphere_add(radius=EYE_R * 1.1, location=e, segments=48, ring_count=24)
        lid = bpy.context.active_object
        bm = bmesh.new()
        bm.from_mesh(lid.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < EYE_R * 0.32], context="VERTS")
        bm.to_mesh(lid.data)
        bm.free()
        lid.rotation_euler = (rot.x + math.radians(-10), rot.y, rot.z)
        lid.data.materials.append(bpy.data.materials["skin"])
        bpy.ops.object.shade_smooth()
        lid.vertex_groups.new(name="all").add([v.index for v in lid.data.vertices], 1.0, "REPLACE")
        lid.vertex_groups.new(name="len").add([v.index for v in lid.data.vertices], 1.0, "REPLACE")
        lp = H.add_fur(lid, "lid", "all", bpy.data.materials["fur_rust"], 500, 20, 0.007, clump=0.3)
        lp.settings.object_align_factor = (0, 0, 0.004)
    H.uv_sphere("Nose", tuple(NOSE), 0.03, H.mat_nose(), (1.35, 0.95, 0.8))


# ----------------------------------------------------------------------------- accessories

def build_mittens():
    """Soft leather mittens: one block for the fingers and a separate thumb, stitched cuff."""
    leather = H.mat_leather("mitten", "#3e2418", 0.5)
    cuff_m = H.mat_leather("mitten_cuff", "#6b4228", 0.55)
    for i, sx in enumerate((-1, 1)):
        d = (HAND[i] - SHOULDER[i]).normalized()
        c = HAND[i] + d * 0.05
        p = Piece("Mitten.%d" % i, leather)
        p.ellip(tuple(c), 0.072, (0.85, 0.75, 1.15))
        p.ellip(tuple(c + Vector((-sx * 0.05, -0.04, 0.025))), 0.032, (0.85, 0.85, 1.25))   # thumb
        p.build(voxel=0.003, smooth=8, target_faces=7000)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.058, minor_radius=0.016, location=HAND[i] - d * 0.01)
        cf = bpy.context.active_object
        cf.rotation_euler = Vector((0, 0, 1)).rotation_difference(d).to_euler()
        cf.data.materials.append(cuff_m)
        bpy.ops.object.shade_smooth()


def build_boots():
    """Short, soft leather booties with a folded cuff, no hardware."""
    leather = H.mat_leather("boot_soft", "#9a6a42", 0.55)
    cuff_m = H.mat_leather("boot_cuff", "#7a5032", 0.6)
    sole_m = H.mat_skin("sole", "#3a2f28")
    for i in range(2):
        a = ANKLE[i]
        p = Piece("Bootie.%d" % i, leather)
        p.ellip(tuple(a + Vector((0, -0.04, -0.03))), 0.095, (1.0, 1.35, 0.72))
        p.caps(tuple(a + Vector((0, 0.005, -0.02))), tuple(a + Vector((0, 0.0, 0.05))), 0.075, 0.07)
        p.build(voxel=0.004, smooth=10, target_faces=9000)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.07, minor_radius=0.02, location=a + Vector((0, 0, 0.055)))
        cf = bpy.context.active_object
        cf.scale = (1.0, 1.0, 1.2)
        cf.data.materials.append(cuff_m)
        bpy.ops.object.shade_smooth()
        bpy.ops.mesh.primitive_cylinder_add(radius=0.09, depth=0.02, location=a + Vector((0, -0.04, -0.088)), vertices=48)
        s = bpy.context.active_object
        s.scale = (0.98, 1.3, 1.0)
        H.add_mod(s, "BEVEL", width=0.008, segments=3)
        s.data.materials.append(sole_m)
        bpy.ops.object.shade_smooth()


def build_scarf():
    knit = H.mat_knit("knit", "#2f6f73")
    p = Piece("Scarf", knit)
    nz = 0.705
    for k in range(20):
        a = k / 20 * math.tau
        p.ball((math.cos(a) * 0.19, math.sin(a) * 0.175 - 0.02, nz + 0.015 * math.sin(a * 2)), 0.052)
    p.ellip((0.11, -0.19, 0.68), 0.055, (1.2, 0.7, 1.0))
    p.caps((0.11, -0.2, 0.67), (0.15, -0.25, 0.55), 0.048, 0.046)
    p.caps((0.15, -0.25, 0.55), (0.16, -0.27, 0.45), 0.046, 0.05)
    p.build(voxel=0.005, smooth=6, target_faces=14000)


def build_bag():
    """Crossbody satchel: strap from the right shoulder to the left hip, brass clasp."""
    leather = H.mat_leather("bag", "#5a3320")
    brass = H.mat_metal("brass", "#c9a24a", 0.3)
    pts = []
    for k in range(40):
        t = k / 39
        yaw = -50 + 100 * t                     # across the front of the belly
        pitch = 48 - 70 * t
        pts.append(on_belly(yaw, pitch, 0.02)[0])
    cu = bpy.data.curves.new("Strap", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.012
    cu.bevel_resolution = 2
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for k, q in enumerate(pts):
        sp.points[k].co = (*q, 1.0)
    st = bpy.data.objects.new("Strap", cu)
    H.scene.collection.objects.link(st)
    st.data.materials.append(leather)
    c, n = on_belly(70, -25, 0.05)
    bpy.ops.mesh.primitive_cube_add(size=0.16, location=c)
    bag = bpy.context.active_object
    bag.scale = (0.75, 0.4, 0.7)
    bag.rotation_euler = (0, 0, math.atan2(n.x, -n.y))
    H.add_mod(bag, "BEVEL", width=0.03, segments=5)
    H.add_mod(bag, "SUBSURF", levels=1, render_levels=2)
    bag.data.materials.append(leather)
    bpy.ops.object.shade_smooth()
    fl = c + n * 0.03 + Vector((0, 0, 0.03))
    bpy.ops.mesh.primitive_cube_add(size=0.16, location=fl)
    flap = bpy.context.active_object
    flap.scale = (0.78, 0.1, 0.42)
    flap.rotation_euler = (math.radians(8), 0, math.atan2(n.x, -n.y))
    H.add_mod(flap, "BEVEL", width=0.012, segments=3)
    flap.data.materials.append(leather)
    bpy.ops.object.shade_smooth()
    H.uv_sphere("Clasp", tuple(fl + n * 0.012 + Vector((0, 0, -0.025))), 0.013, brass, (1.3, 0.6, 1.0), seg=16)


def build_goggles():
    leather = bpy.data.materials["bag"]
    brass = bpy.data.materials["brass"]
    glass = H.mat_glass("lens", "#bfe4ff")
    pts = []
    for k in range(72):
        yaw = k / 72 * 360.0
        pitch = 40 - 12 * math.cos(math.radians(yaw))
        pts.append(on_head(yaw, pitch, 0.014)[0])
    bm = bmesh.new()
    ring = [(bm.verts.new(q + Vector((0, 0, -0.017))), bm.verts.new(q + Vector((0, 0, 0.017)))) for q in pts]
    for k in range(72):
        a, b = ring[k], ring[(k + 1) % 72]
        bm.faces.new((a[0], b[0], b[1], a[1]))
    s = H.obj_from_bmesh("GoggleStrap", bm, leather)
    H.add_mod(s, "SOLIDIFY", thickness=0.006, offset=0.0)
    for sx in (-1, 1):
        c, n = on_head(sx * 17, 40, 0.025)
        rot = Vector((0, 0, 1)).rotation_difference(n).to_euler()
        bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=0.032, location=c, vertices=48)
        cup = bpy.context.active_object
        cup.rotation_euler = rot
        H.add_mod(cup, "BEVEL", width=0.006, segments=3)
        cup.data.materials.append(brass)
        bpy.ops.object.shade_smooth()
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.044, location=c + n * 0.009, segments=32, ring_count=16)
        lens = bpy.context.active_object
        lens.scale = (1, 1, 0.35)
        lens.rotation_euler = rot
        lens.data.materials.append(glass)
        bpy.ops.object.shade_smooth()


def build_owl():
    base = on_head(0, 68, 0.085)[0] + Vector((0, 0.03, 0))
    skin = H.mat_skin("owl_skin", "#5e4330")
    p = Piece("Owl", skin)
    p.ellip(tuple(base), 0.075, (1.05, 0.95, 0.95))
    p.ellip(tuple(base + Vector((0, -0.005, 0.085))), 0.072, (1.15, 1.0, 0.9))
    for sx in (-1, 1):
        p.ellip(tuple(base + Vector((sx * 0.05, 0.005, 0.155))), 0.022, (0.6, 0.5, 1.4))
        p.ellip(tuple(base + Vector((sx * 0.072, 0.01, 0.0))), 0.045, (0.45, 0.9, 1.2))
    owl = p.build(voxel=0.003, smooth=6, target_faces=16000)
    head = base + Vector((0, -0.005, 0.085))
    g = {n: owl.vertex_groups.new(name=n) for n in ("brown", "cream", "len")}
    for v in owl.data.vertices:
        q = owl.matrix_world @ v.co
        face = (q - (head + Vector((0, -0.065, 0)))).length < 0.065
        hole = min((q - (head + Vector((sx * 0.032, -0.066, 0.005)))).length for sx in (-1, 1)) < 0.026
        g["brown"].add([v.index], 0.0 if (face or hole) else 1.0, "REPLACE")
        g["cream"].add([v.index], 0.0 if hole else (1.0 if face else 0.0), "REPLACE")
        g["len"].add([v.index], 0.35 if face else 0.8, "REPLACE")
    fb = H.mat_fur("owl_brown", "#5e4330", "#9a7656", "#2e1f15")
    fc = H.mat_fur("owl_cream", "#e6d2b0", "#f7ead2", "#a68c68")
    for name, grp, mat, n in (("owl_brown", "brown", fb, 3000), ("owl_cream", "cream", fc, 1800)):
        ps = H.add_fur(owl, name, grp, mat, n, 40, 0.011, clump=0.3)
        ps.settings.radius_scale = 0.0006
        ps.settings.object_align_factor = (0, 0.3 * 0.011, -0.7 * 0.011)
        ps.settings.roughness_2 = 0.003
    eye_m = H.mat_eye("owl_eye", iris="#f2b51c", ring="#5a3a08", radius=0.026)
    cornea = bpy.data.materials["cornea"]
    for sx in (-1, 1):
        c = head + Vector((sx * 0.032, -0.062, 0.005))
        d = Vector((sx * 0.25, -1, 0)).normalized()
        rot = Vector((0, -1, 0)).rotation_difference(d).to_euler()
        e = H.uv_sphere("OwlEye", tuple(c), 0.026, eye_m, seg=32)
        e.rotation_euler = rot
        k = H.uv_sphere("OwlCornea", tuple(c + d * 0.002), 0.027, cornea, seg=32)
        k.rotation_euler = rot
    beak = H.mat_leather("beak", "#d9c48a", 0.35)
    bpy.ops.mesh.primitive_cone_add(radius1=0.013, depth=0.03, location=head + Vector((0, -0.078, -0.02)), vertices=24)
    bk = bpy.context.active_object
    bk.rotation_euler = (math.radians(110), 0, 0)
    bk.data.materials.append(beak)
    bpy.ops.object.shade_smooth()


# ----------------------------------------------------------------------------- main

if __name__ == "__main__":
    body = build_body()
    region_weights(body)
    furs = [
        ("rust", H.mat_fur("fur_rust", "#b8471c", "#e8823c", "#5a1f0c"), 10000, 0.03),
        ("cream", H.mat_fur("fur_cream", "#f1e6d2", "#fffaf0", "#c9b393"), 4500, 0.03),
        ("dark", H.mat_fur("fur_dark", "#3a1d12", "#5e3424", "#1a0c08"), 4000, 0.03),
        ("ochre", H.mat_fur("fur_ochre", "#d98a45", "#f4b878", "#8a4a1c"), 2500, 0.03),
    ]
    for name, mat, count, ln in furs:
        H.add_fur(body, name, name, mat, count, 70, ln)
    build_eyes()
    build_mittens()
    build_boots()
    build_scarf()
    build_bag()
    build_goggles()
    build_owl()
    H.stage()
    os.makedirs(H.OUT, exist_ok=True)
    shots = {
        "front": (0, 0.62, 3.6, 50, 0.85, 900, 1100),
        "three": (-35, 0.62, 3.6, 50, 0.95, 900, 1100),
        "side": (-90, 0.62, 3.6, 50, 0.85, 900, 1100),
        "face": (-25, 1.0, 2.0, 65, 1.12, 1000, 1000),
    }
    for v in H.VIEWS:
        yaw, tz, dist, lens, hgt, w, h = shots[v]
        H.camera(v, yaw, tz, dist, lens, hgt)
        H.render(os.path.join(H.OUT, "b_%s.png" % v), w, h)
    print("done")

"""Game version of Bolo B: light mesh, fur colour and length baked into vertex colours,
accessories as separate pieces, armature and region-aware skinning.

The fur itself is drawn in Godot with a shell shader that reads COLOR.rgb (fur colour)
and COLOR.a (fur length), so the render look of hero_b.py carries over to the game.
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
if "--" not in sys.argv:
    sys.argv += ["--", "/tmp"]
import hero_b as B  # noqa: E402  (also imports hero.py and resets the scene)
import hero as H  # noqa: E402
from vinyl import Piece, make_armature, skin  # noqa: E402

FUR = {"rust": (0.72, 0.28, 0.11), "cream": (0.95, 0.9, 0.82), "dark": (0.23, 0.12, 0.07), "ochre": (0.85, 0.54, 0.27)}


def mat(name, color):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = H.hexc(color)
    return m


M = {}


def material(name, color):
    if name not in M:
        M[name] = mat(name, color)
    return M[name]


# ----------------------------------------------------------------------------- rig

def bones():
    bl = [
        ("root", (0, 0, 0), (0, 0, 0.15), None),
        ("squash", (0, 0, 0), (0, 0, 0.2), "root"),
        ("hips", (0, 0, 0.2), (0, 0, 0.45), "squash"),
        ("chest", (0, 0, 0.45), (0, 0, 0.7), "hips"),
        ("head", (0, 0, 0.7), (0, 0, 1.2), "chest"),
    ]
    for i, side in ((0, "R"), (1, "L")):
        e = B.EARS[i]
        bl.append(("ear." + side, tuple(e - Vector((0, 0, 0.06))), tuple(e + Vector((0, 0, 0.1))), "head"))
        s, h = B.SHOULDER[i], B.HAND[i]
        mid = s + (h - s) * 0.5
        d = (h - s).normalized()
        bl += [
            ("arm_upper." + side, tuple(s), tuple(mid), "chest"),
            ("arm_lower." + side, tuple(mid), tuple(h), "arm_upper." + side),
            ("hand." + side, tuple(h), tuple(h + d * 0.1), "arm_lower." + side),
        ]
        lt, an = B.LEG_TOP[i], B.ANKLE[i]
        lm = lt + (an - lt) * 0.5
        bl += [
            ("leg_upper." + side, tuple(lt), tuple(lm), "hips"),
            ("leg_lower." + side, tuple(lm), tuple(an), "leg_upper." + side),
            ("foot." + side, tuple(an), tuple(an + Vector((0, -0.12, -0.04))), "leg_lower." + side),
        ]
        ec = B.EYES[i]
        fwd = ((ec - B.HEAD).normalized() + Vector((0, -1.6, 0))).normalized()
        bl.append(("eye." + side, tuple(ec), tuple(ec + fwd * 0.08), "head"))
    for k in range(5):
        bl.append(("tail%d" % (k + 1), tuple(B.TAIL[k]), tuple(B.TAIL[k + 1]), "hips" if k == 0 else "tail%d" % k))
    return bl


def region_of(p):
    """Which bones may influence a body vertex: keeps belly, arms, head and tail apart."""
    for i, side in ((0, "R"), (1, "L")):
        d, t = H.seg_dist(p, B.SHOULDER[i], B.HAND[i])
        inside_belly = (Vector(((p - B.BELLY).x / (B.BELLY_R * B.BELLY_S.x), (p - B.BELLY).y / (B.BELLY_R * B.BELLY_S.y),
                                (p - B.BELLY).z / (B.BELLY_R * B.BELLY_S.z)))).length < 1.0
        if d < 0.07 and p.x * B.SHOULDER[i].x > 0 and (t > 0.25 or not inside_belly):
            return ["arm_upper." + side, "arm_lower." + side, "hand." + side, "chest"]
        if p.z < 0.2 and p.x * B.LEG_TOP[i].x > 0:
            return ["leg_upper." + side, "leg_lower." + side, "foot." + side]
    td, _ = B.tail_param(p)
    if td < 0.12 and p.y > 0.17:
        return ["tail%d" % k for k in range(1, 6)] + ["hips"]
    if p.z > 0.72:
        return ["head", "ear.L", "ear.R"]
    return ["hips", "chest", "head"]


def skin_body(o, arm):
    segs = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones}
    groups = {b.name: o.vertex_groups.new(name=b.name) for b in arm.data.bones}
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        cand = region_of(p)
        ws = []
        for bn in cand:
            a, b = segs[bn]
            d, _ = H.seg_dist(p, a, b)
            ws.append((1.0 / (d + 0.02) ** 5, bn))
        ws.sort(reverse=True)
        ws = ws[:2]
        tot = sum(w for w, _ in ws)
        for w, bn in ws:
            groups[bn].add([v.index], w / tot, "REPLACE")
    mod = o.modifiers.new("armature", "ARMATURE")
    mod.object = arm
    o.parent = arm


def bake_fur_colours(o):
    """COLOR.rgb = fur colour, COLOR.a = fur length (0..1), from the same regions as the render."""
    B.region_weights(o)
    vg = {g.name: g.index for g in o.vertex_groups}
    me = o.data
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for v in me.vertices:
        w = {n: 0.0 for n in FUR}
        length = 0.0
        for g in v.groups:
            name = o.vertex_groups[g.group].name
            if name in w:
                w[name] = g.weight
            elif name == "len":
                length = g.weight
        tot = sum(w.values())
        if tot <= 1e-6:
            c = FUR["rust"]
            length = 0.0
        else:
            c = tuple(sum(FUR[n][k] * w[n] for n in w) / tot for k in range(3))
        col.data[v.index].color = (c[0], c[1], c[2], length)
    for g in list(o.vertex_groups):
        o.vertex_groups.remove(g)


# ----------------------------------------------------------------------------- pieces

def decimate(o, faces):
    if len(o.data.polygons) > faces:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        m = o.modifiers.new("dec", "DECIMATE")
        m.ratio = faces / len(o.data.polygons)
        bpy.ops.object.modifier_apply(modifier="dec")


def unwrap(o):
    """UVs for the fur strands in the Godot shell shader (even texel density across islands)."""
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def piece(name, mat_name, color, builder, faces):
    p = Piece(name, material(mat_name, color))
    builder(p)
    o = p.build(voxel=0.004, smooth=8)
    decimate(o, faces)
    return o


def sphere(name, c, r, mat_name, color, scale=(1, 1, 1), seg=24):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=c, segments=seg, ring_count=seg // 2)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material(mat_name, color))
    bpy.ops.object.shade_smooth()
    return o


def eye_uvs(o, centre, fwd):
    """Planar UVs looking down the eye's axis so a radial iris texture lands on the front."""
    up = Vector((0, 0, 1))
    right = fwd.cross(up).normalized()
    up = right.cross(fwd).normalized()
    me = o.data
    uv = me.uv_layers.new(name="UVMap")
    r = max((v.co - centre).length for v in me.vertices)
    for loop in me.loops:
        q = me.vertices[loop.vertex_index].co - centre
        front = q.dot(fwd) > 0
        x, y = q.dot(right) / r, q.dot(up) / r
        if not front:
            x, y = 0.99, 0.99  # back of the eye: sclera corner
        uv.data[loop.index].uv = (0.5 + 0.5 * x, 0.5 + 0.5 * y)


def build_game(out_glb):
    body_piece = Piece("Body", material("fur", "#b8471c"))
    # same shapes as hero_b.build_body
    p = body_piece
    p.ellip(tuple(B.HEAD), B.HEAD_R, tuple(B.HEAD_S))
    p.ellip(tuple(B.HEAD + Vector((0, -0.05, -0.1))), 0.2, (1.3, 0.95, 0.72))
    p.ellip(tuple(B.MUZZLE), 0.09, (1.2, 1.0, 0.72))
    for sx in (-1, 1):
        bc, _ = B.on_head(sx * 22, 22, -0.035)
        p.ellip(tuple(bc), 0.06, (1.3, 0.8, 0.55))
        e = B.EARS[0 if sx < 0 else 1]
        p.ellip(tuple(e), 0.1, (1.0, 0.45, 1.15), rot=(0, math.radians(-sx * 30), 0))
    p.ellip(tuple(B.BELLY), B.BELLY_R, tuple(B.BELLY_S))
    p.caps(tuple(B.BELLY + Vector((0, 0, 0.18))), tuple(B.HEAD + Vector((0, 0, -0.18))), 0.15)
    for i in range(2):
        p.caps(tuple(B.SHOULDER[i]), tuple(B.HAND[i]), 0.05, 0.046)
        p.caps(tuple(B.LEG_TOP[i]), tuple(B.ANKLE[i]), 0.07, 0.06)
    for i in range(len(B.TAIL) - 1):
        p.caps(tuple(B.TAIL[i]), tuple(B.TAIL[i + 1]), B.TAIL_R[i] * 0.95, B.TAIL_R[i + 1] * 0.95)
    body = p.build(voxel=0.009, smooth=10)
    decimate(body, 14000)
    unwrap(body)
    bake_fur_colours(body)

    arm = make_armature("BoloRig", bones())
    skin_body(body, arm)

    # eyes, lids and nose
    for i, side in ((0, "R"), (1, "L")):
        ec = B.EYES[i]
        fwd = ((ec - B.HEAD).normalized() + Vector((0, -1.6, 0))).normalized()
        e = sphere("Eye." + side, tuple(ec), B.EYE_R, "eye", "#ffffff", seg=32)
        eye_uvs(e, ec, fwd)
        skin(e, arm, [], rigid="eye." + side)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=B.EYE_R * 1.1, location=ec, segments=32, ring_count=16)
        lid = bpy.context.active_object
        lid.name = "Lid." + side
        bm = bmesh.new()
        bm.from_mesh(lid.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if (v.co - ec).z < B.EYE_R * 0.32], context="VERTS")
        bm.to_mesh(lid.data)
        bm.free()
        lid.data.materials.append(material("lid", "#a8401a"))
        bpy.ops.object.shade_smooth()
        skin(lid, arm, [], rigid="head")
    nose = sphere("Nose", tuple(B.NOSE), 0.03, "nose", "#1b1210", (1.35, 0.95, 0.8))
    skin(nose, arm, [], rigid="head")

    # mittens
    for i, side in ((0, "R"), (1, "L")):
        sx = -1 if side == "R" else 1
        d = (B.HAND[i] - B.SHOULDER[i]).normalized()
        c = B.HAND[i] + d * 0.05

        def mit(p, c=c, sx=sx, i=i, d=d):
            p.ellip(tuple(c), 0.072, (0.85, 0.75, 1.15))
            p.ellip(tuple(c + Vector((-sx * 0.05, -0.04, 0.025))), 0.032, (0.85, 0.85, 1.25))
            p.caps(tuple(B.HAND[i] - d * 0.02), tuple(B.HAND[i] + d * 0.01), 0.06, 0.062)
        m = piece("Mitten." + side, "mitten", "#3e2418", mit, 1800)
        skin(m, arm, [], rigid="hand." + side)

    # booties
    for i, side in ((0, "R"), (1, "L")):
        a = B.ANKLE[i]

        def boot(p, a=a):
            p.ellip(tuple(a + Vector((0, -0.04, -0.03))), 0.095, (1.0, 1.35, 0.72))
            p.caps(tuple(a + Vector((0, 0.005, -0.02))), tuple(a + Vector((0, 0.0, 0.05))), 0.075, 0.07)
            p.ellip(tuple(a + Vector((0, 0, 0.055))), 0.085, (1.0, 1.0, 0.35))
        bt = piece("Boot." + side, "boot", "#9a6a42", boot, 1800)
        skin(bt, arm, [], rigid="foot." + side)

        def sole(p, a=a):
            p.ellip(tuple(a + Vector((0, -0.04, -0.085))), 0.09, (1.0, 1.3, 0.2))
        so = piece("Sole." + side, "sole", "#3a2f28", sole, 800)
        skin(so, arm, [], rigid="foot." + side)

    # scarf
    def scarf(p):
        nz = 0.705
        for k in range(20):
            a = k / 20 * math.tau
            p.ball((math.cos(a) * 0.19, math.sin(a) * 0.175 - 0.02, nz + 0.015 * math.sin(a * 2)), 0.052)
        p.ellip((0.11, -0.19, 0.68), 0.055, (1.2, 0.7, 1.0))
        p.caps((0.11, -0.2, 0.67), (0.15, -0.25, 0.55), 0.048, 0.046)
        p.caps((0.15, -0.25, 0.55), (0.16, -0.27, 0.45), 0.046, 0.05)
    sc = piece("Scarf", "knit", "#2f6f73", scarf, 4000)
    skin(sc, arm, ["chest", "head"])

    # satchel and strap
    def bag(p):
        pts = [B.on_belly(-50 + 100 * k / 19, 48 - 70 * k / 19, 0.02)[0] for k in range(20)]
        for k in range(19):
            p.caps(tuple(pts[k]), tuple(pts[k + 1]), 0.012)
        c, n = B.on_belly(70, -25, 0.06)
        p.ellip(tuple(c), 0.075, (1.0, 0.6, 0.8))
    bg = piece("Bag", "bag", "#5a3320", bag, 2500)
    skin(bg, arm, ["hips", "chest"])
    c, n = B.on_belly(70, -25, 0.06)
    clasp = sphere("Clasp", tuple(c + n * 0.045 + Vector((0, 0, 0.02))), 0.014, "brass", "#c9a24a", (1.3, 0.6, 1.0), seg=12)
    skin(clasp, arm, [], rigid="hips")

    # goggles
    def strap(p):
        pts = [B.on_head(k / 48 * 360.0, 40 - 12 * math.cos(math.radians(k / 48 * 360.0)), 0.012)[0] for k in range(49)]
        for k in range(48):
            p.caps(tuple(pts[k]), tuple(pts[k + 1]), 0.014)
    gs = piece("GoggleStrap", "bag", "#5a3320", strap, 2000)
    skin(gs, arm, [], rigid="head")
    for sx in (-1, 1):
        cc, nn = B.on_head(sx * 17, 40, 0.025)
        rot = Vector((0, 0, 1)).rotation_difference(nn).to_euler()
        bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=0.032, location=cc, vertices=24)
        cup = bpy.context.active_object
        cup.rotation_euler = rot
        bpy.ops.object.transform_apply(rotation=True)
        cup.data.materials.append(material("brass", "#c9a24a"))
        bpy.ops.object.shade_smooth()
        skin(cup, arm, [], rigid="head")
        lens = sphere("Lens", tuple(cc + nn * 0.009), 0.044, "lens", "#bfe4ff", seg=16)
        lens.scale = (1, 1, 0.35)
        lens.rotation_euler = rot
        bpy.ops.object.transform_apply(rotation=True, scale=True)
        skin(lens, arm, [], rigid="head")
    return arm

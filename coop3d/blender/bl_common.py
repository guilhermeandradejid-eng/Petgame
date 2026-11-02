"""Helpers shared by the Blender generator scripts.

Everything is built procedurally with bmesh so the models can be regenerated
from the command line (`python build_all.py` with the `bpy` module, or
`blender -b -P build_all.py`). Shapes are parametric "blobs": a UV sphere whose
vertices are pushed around by small Python functions, then smoothed with a
Subdivision Surface modifier that is applied on export.
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "models"))


# ---------------------------------------------------------------- scene utils
def reset_scene():
    _mat_cache.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.objects, bpy.data.curves):
        for block in list(coll):
            coll.remove(block)


_mat_cache = {}


def mat(name, color, rough=0.6, emission=None, metallic=0.0):
    """Principled material. Godot replaces it with a toon ShaderMaterial by name
    prefix (M_Glow*, M_Eye*, ...), keeping the base color."""
    if name in _mat_cache:
        return _mat_cache[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    c = hex_rgb(color) if isinstance(color, str) else color
    bsdf.inputs["Base Color"].default_value = (*c, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        e = hex_rgb(emission) if isinstance(emission, str) else emission
        bsdf.inputs["Emission Color"].default_value = (*e, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 2.0
    m.diffuse_color = (*c, 1.0)
    _mat_cache[name] = m
    return m


def hex_rgb(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    # Blender colors are linear
    return tuple(((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in srgb)


def empty(name, loc=(0, 0, 0), parent=None, rot=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    o.empty_display_size = 0.08
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    if parent:
        o.parent = parent
    return o


def link_mesh(name, bm, material, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), subsurf=1, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(material)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    if subsurf:
        mod = o.modifiers.new("subd", "SUBSURF")
        mod.levels = subsurf
        mod.render_levels = subsurf
    o.location = loc
    o.rotation_euler = rot
    if parent:
        o.parent = parent
    return o


# ------------------------------------------------------------- shape helpers
def blob(radius=(1, 1, 1), seg=24, rings=16, deform=None):
    """UV sphere scaled to `radius`; `deform(v: Vector, n: Vector) -> Vector`
    receives the unit-sphere position and returns the new local position."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in bm.verts:
        p = v.co.copy()
        n = p.normalized()
        q = Vector((p.x * radius[0], p.y * radius[1], p.z * radius[2]))
        if deform:
            q = deform(q, n)
        v.co = q
    return bm


def tube(points, radii, seg=12, cap=True):
    """Lofted tube along a polyline with per-point radius (for limbs, tails,
    antennae). Ends are closed with a fan so the result is watertight."""
    bm = bmesh.new()
    rings = []
    pts = [Vector(p) for p in points]
    for i, p in enumerate(pts):
        if i == 0:
            t = (pts[1] - pts[0]).normalized()
        elif i == len(pts) - 1:
            t = (pts[-1] - pts[-2]).normalized()
        else:
            t = (pts[i + 1] - pts[i - 1]).normalized()
        a = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        u = t.cross(a).normalized()
        w = t.cross(u).normalized()
        ring = []
        for k in range(seg):
            ang = 2 * math.pi * k / seg
            ring.append(bm.verts.new(p + (u * math.cos(ang) + w * math.sin(ang)) * radii[i]))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(seg):
            a, b = rings[i][k], rings[i][(k + 1) % seg]
            c, d = rings[i + 1][(k + 1) % seg], rings[i + 1][k]
            bm.faces.new((a, b, c, d))
    if cap:
        for ring, rev in ((rings[0], True), (rings[-1], False)):
            center = sum((v.co for v in ring), Vector()) / len(ring)
            tip = bm.verts.new(center)
            for k in range(seg):
                a, b = ring[k], ring[(k + 1) % seg]
                bm.faces.new((b, a, tip) if rev else (a, b, tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def bezier_points(p0, p1, p2, n=8):
    out = []
    for i in range(n):
        t = i / (n - 1)
        a = Vector(p0).lerp(Vector(p1), t)
        b = Vector(p1).lerp(Vector(p2), t)
        out.append(tuple(a.lerp(b, t)))
    return out


def torus(major=0.3, minor=0.06, seg=32, ring_seg=10, squash_z=1.0):
    bm = bmesh.new()
    verts = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        row = []
        for j in range(ring_seg):
            b = 2 * math.pi * j / ring_seg
            r = major + minor * math.cos(b)
            row.append(bm.verts.new((r * math.cos(a), r * math.sin(a), minor * math.sin(b) * squash_z)))
        verts.append(row)
    for i in range(seg):
        for j in range(ring_seg):
            a = verts[i][j]
            b = verts[(i + 1) % seg][j]
            c = verts[(i + 1) % seg][(j + 1) % ring_seg]
            d = verts[i][(j + 1) % ring_seg]
            bm.faces.new((a, b, c, d))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def cone(r1, r2, depth, seg=16):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=depth)
    return bm


def mirror_x(fn, side):
    """Run a builder for the left (+1) or right (-1) side."""
    return fn(side)


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# ----------------------------------------------------------------- exporting
def export_glb(filename, root):
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        o.select_set(True)
    path = os.path.join(OUT_DIR, filename)
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_normals=True,
        export_materials="EXPORT",
        export_animations=False,
    )
    print("exported", path)
    return path

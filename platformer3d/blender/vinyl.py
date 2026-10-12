"""Shared helpers for building vinyl-toy characters with bpy: materials, fused primitives,
armatures, distance-based skinning and pose keyframing."""
import math

import bpy
import bmesh
from mathutils import Vector, Euler, Quaternion


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    s = bpy.context.scene
    s.render.fps = 30
    return s


def hexc(h, a=1.0):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, a)


_MATS = {}


def vinyl(name, color, rough=0.34, coat=0.7):
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = hexc(color)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = 0.18
    _MATS[name] = m
    return m


class Piece:
    """Primitives fused into one soft mesh (voxel remesh + smooth), like one moulded vinyl part."""

    def __init__(self, name, mat):
        self.name = name
        self.mat = mat
        self.objs = []

    def _take(self):
        o = bpy.context.active_object
        self.objs.append(o)
        return o

    def ball(self, p, r):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=p, segments=32, ring_count=16)
        return self._take()

    def ellip(self, p, r, s, rot=(0, 0, 0)):
        o = self.ball(p, r)
        o.scale = s
        o.rotation_euler = rot
        return o

    def caps(self, a, b, r, r2=None):
        a, b = Vector(a), Vector(b)
        r2 = r if r2 is None else r2
        d = b - a
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=d.length, vertices=32, location=(a + b) / 2)
        o = self._take()
        o.rotation_euler = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
        self.ball(tuple(a), r)
        self.ball(tuple(b), r2)
        return o

    def build(self, voxel=0.02, smooth=8, target_faces=None):
        bpy.ops.object.select_all(action="DESELECT")
        for o in self.objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.objs[0]
        if len(self.objs) > 1:
            bpy.ops.object.join()
        o = bpy.context.active_object
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        m = o.modifiers.new("remesh", "REMESH")
        m.mode = "VOXEL"
        m.voxel_size = voxel
        bpy.ops.object.modifier_apply(modifier="remesh")
        sm = o.modifiers.new("smooth", "SMOOTH")
        sm.factor = 0.8
        sm.iterations = smooth
        bpy.ops.object.modifier_apply(modifier="smooth")
        if target_faces and len(o.data.polygons) > target_faces:
            dc = o.modifiers.new("dec", "DECIMATE")
            dc.ratio = target_faces / len(o.data.polygons)
            bpy.ops.object.modifier_apply(modifier="dec")
        o.data.materials.clear()
        o.data.materials.append(self.mat)
        bpy.ops.object.shade_smooth()
        o.name = self.name
        o.data.name = self.name
        return o


def simple_sphere(name, p, r, mat, scale=(1, 1, 1), seg=24):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=p, segments=seg, ring_count=seg // 2)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    o.name = name
    return o


# ---------------------------------------------------------------------------- armature

def make_armature(name, bones):
    """bones: list of (name, head, tail, parent or None, roll)."""
    arm = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for b in bones:
        bn, head, tail, parent = b[:4]
        roll = b[4] if len(b) > 4 else 0.0
        eb = arm.edit_bones.new(bn)
        eb.head = head
        eb.tail = tail
        eb.roll = roll
        if parent:
            eb.parent = arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "XYZ"
    return ob


def bone_segments(arm_ob):
    out = {}
    for b in arm_ob.data.bones:
        out[b.name] = (arm_ob.matrix_world @ b.head_local, arm_ob.matrix_world @ b.tail_local)
    return out


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def skin(obj, arm_ob, bones, power=4.0, keep=2, rigid=None):
    """Weight every vertex of obj to the closest of `bones` (inverse distance^power, top `keep`).
    rigid: a single bone name to bind the whole piece to."""
    segs = bone_segments(arm_ob)
    for v in obj.vertex_groups:
        obj.vertex_groups.remove(v)
    groups = {}
    use = [rigid] if rigid else bones
    for bn in use:
        groups[bn] = obj.vertex_groups.new(name=bn)
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        if rigid:
            groups[rigid].add([v.index], 1.0, "REPLACE")
            continue
        ws = []
        for bn in bones:
            a, b = segs[bn]
            d = _seg_dist(p, a, b)
            ws.append((1.0 / (d + 0.02) ** power, bn))
        ws.sort(reverse=True)
        ws = ws[:keep]
        tot = sum(w for w, _ in ws)
        for w, bn in ws:
            groups[bn].add([v.index], w / tot, "REPLACE")
    mod = obj.modifiers.new("armature", "ARMATURE")
    mod.object = arm_ob
    obj.parent = arm_ob


# ---------------------------------------------------------------------------- animation

def new_action(arm_ob, name):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if arm_ob.animation_data is None:
        arm_ob.animation_data_create()
    arm_ob.animation_data.action = act
    for pb in arm_ob.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)
    return act


def key(arm_ob, frame, pose, all_bones=True):
    """pose: {bone: {"r": (x,y,z) degrees, "l": (x,y,z), "s": (x,y,z) or float}}.
    Bones not in pose are keyed at rest so every key is a full pose (pose-to-pose)."""
    for pb in arm_ob.pose.bones:
        spec = pose.get(pb.name)
        if spec is None and not all_bones:
            continue
        spec = spec or {}
        r = spec.get("r", (0, 0, 0))
        pb.rotation_euler = Euler([math.radians(a) for a in r], "XYZ")
        pb.location = spec.get("l", (0, 0, 0))
        s = spec.get("s", 1.0)
        pb.scale = (s, s, s) if isinstance(s, (int, float)) else s
        pb.keyframe_insert("rotation_euler", frame=frame, group=pb.name)
        pb.keyframe_insert("location", frame=frame, group=pb.name)
        pb.keyframe_insert("scale", frame=frame, group=pb.name)


def finish_action(arm_ob, act, cyclic=False, interp="BEZIER"):
    for fc in _fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = interp
            kp.handle_left_type = "AUTO_CLAMPED"
            kp.handle_right_type = "AUTO_CLAMPED"
        if cyclic:
            fc.modifiers.new("CYCLES")
        fc.update()
    arm_ob.animation_data.action = None


def _fcurves(act):
    # Blender 4.4+ layered actions keep fcurves inside channelbags
    if hasattr(act, "layers") and len(act.layers):
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    yield from cb.fcurves
    else:
        yield from act.fcurves


def mix(a, b, t):
    """Blend two pose dicts (for breakdowns between keys)."""
    out = {}
    for bn in set(a) | set(b):
        sa, sb = a.get(bn, {}), b.get(bn, {})
        d = {}
        for k, rest in (("r", (0, 0, 0)), ("l", (0, 0, 0))):
            va, vb = sa.get(k, rest), sb.get(k, rest)
            d[k] = tuple(x + (y - x) * t for x, y in zip(va, vb))
        def sv(s):
            s = s.get("s", 1.0)
            return (s, s, s) if isinstance(s, (int, float)) else s
        d["s"] = tuple(x + (y - x) * t for x, y in zip(sv(sa), sv(sb)))
        out[bn] = d
    return out

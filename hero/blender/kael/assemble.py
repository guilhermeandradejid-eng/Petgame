"""Builder -> Blender mesh object, armature creation, skin binding."""
import bpy, bmesh
from mathutils import Vector
from . import look, model, skel


def clean_weights(w, limit=4):
    items = sorted(w.items(), key=lambda kv: -kv[1])[:limit]
    t = sum(v for _, v in items)
    return {k: v / t for k, v in items if v / t > 0.004}


def mesh_object(b, name, scene, bone_names=None, rigid=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in b.v], [], b.f)
    for n in b.mats:
        me.materials.append(bpy.data.materials[n])
    me.polygons.foreach_set("material_index", b.fm)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    uvs = [0.0] * (2 * len(me.loops))
    for lp in me.loops:
        u, v = b.uv[lp.vertex_index]
        uvs[2 * lp.index], uvs[2 * lp.index + 1] = u, v
    uvl.data.foreach_set("uv", uvs)
    if b.sharp:
        ek = {tuple(sorted(e.vertices)): e.index for e in me.edges}
        for k in b.sharp:
            if k in ek:
                me.edges[ek[k]].use_edge_sharp = True
    obj = bpy.data.objects.new(name, me)
    scene.collection.objects.link(obj)

    if not rigid:
        vgs = {n: obj.vertex_groups.new(name=n) for n in bone_names}
        for i, w in enumerate(b.w):
            for bn, val in clean_weights(w).items():
                vgs[bn].add([i], val, "REPLACE")
    og = obj.vertex_groups.new(name="outline")
    for i, o in enumerate(b.ol):
        og.add([i], o, "REPLACE")

    # custom normals (flattened, sphere-like face shading)
    fixes = [(b.parts[p], fn) for p, fn in model.NORMAL_FIX.items() if p in b.parts]
    if fixes:
        vfix = {}
        for (v0, v1), fn in fixes:
            for i in range(v0, v1):
                vfix[i] = fn
        normals = []
        cn = me.corner_normals
        for lp in me.loops:
            n = Vector(cn[lp.index].vector)
            fn = vfix.get(lp.vertex_index)
            if fn:
                n = fn(me.vertices[lp.vertex_index].co, n)
            normals.append(tuple(n))
        me.normals_split_custom_set(normals)
    return obj


def armature(scene, extra):
    B = skel.bones(extra)
    data = bpy.data.armatures.new("KaelRig")
    arm = bpy.data.objects.new("Kael", data)
    scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, head, tail in B:
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = head, tail
        if parent:
            eb.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    data.display_type = "STICK"
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm, B


def bind(obj, arm):
    obj.parent = arm
    obj.modifiers.new("Armature", "ARMATURE").object = arm

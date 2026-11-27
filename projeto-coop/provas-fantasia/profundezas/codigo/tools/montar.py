# Montagem e "pintura assada": junta as duas malhas do Builder (a 'sub' recebe Catmull-Clark nível 1, a 'flat'
# fica dura), e assa por vértice o que o pintor de miniatura pinta à mão:
#   UV2.x = oclusão (lavagem nos vãos), UV2.y = curvatura média com sinal (luz de aresta nas convexas),
#   UV.x  = ruído de lascas em 3D na pose de descanso (a tinta lasca e mostra o chumbo), UV.y = altura relativa
#   (para o desbotar de cima para baixo), e o brilho pintado de velas e geodos somado à cor de vértice.
import bpy, bmesh, math, random
from mathutils import Vector, noise
from mathutils.bvhtree import BVHTree
from malha import MATS, hexc

def _obj_from_bm(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for mname in MATS:
        m = bpy.data.materials.get(mname) or bpy.data.materials.new(mname)
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob

def hemis(n=18, seed=3):
    rng = random.Random(seed)
    out = []
    for i in range(n):
        u, v = (i + rng.random()) / n, rng.random()
        r = math.sqrt(u); t = 2 * math.pi * v
        out.append(Vector((r * math.cos(t), r * math.sin(t), math.sqrt(max(0.0, 1 - u)))))
    return out

def bake(ob, groups, glows=(), ao_dist=0.3, ao_n=24, chip_scale=22.0, curv_scale=0.03, height=None, skip_ao=False):
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    bm.normal_update()
    dl = bm.verts.layers.deform.verify()
    gi = groups.index('contorno') if 'contorno' in groups else -1
    col = bm.loops.layers.float_color.get('Col') or bm.loops.layers.float_color.new('Col')
    uv1 = bm.loops.layers.uv.get('UVMap') or bm.loops.layers.uv.new('UVMap')
    uv2 = bm.loops.layers.uv.get('UV2') or bm.loops.layers.uv.new('UV2')
    eye = MATS.index('olho'); cont = MATS.index('contorno')
    hull = set()
    for v in bm.verts:
        if gi >= 0 and v[dl].get(gi, 0.0) > 0.0:
            hull.add(v.index)
    faces = [f for f in bm.faces if f.material_index not in (eye, cont)]
    bvh = BVHTree.FromPolygons([v.co for v in bm.verts], [[v.index for v in f.verts] for f in faces], epsilon=0.0) if not skip_ao else None
    H = hemis(ao_n)
    zs = [v.co.z for v in bm.verts]
    z0, z1 = (min(zs), max(zs)) if height is None else height
    ao, cv = {}, {}
    for v in bm.verts:
        if v.index in hull:
            continue
        n = v.normal
        if bvh is not None:
            t = n.orthogonal().normalized(); b = n.cross(t)
            occ = 0.0
            o = v.co + n * 0.004
            for d in H:
                w = (t * d.x + b * d.y + n * d.z).normalized()
                hit = bvh.ray_cast(o, w, ao_dist)
                if hit[0] is not None:
                    occ += 1.0 - 0.5 * (hit[3] / ao_dist)
            ao[v.index] = 1.0 - occ / len(H)
        else:
            ao[v.index] = 1.0
        s, q = 0.0, 0.0
        for e in v.link_edges:
            d = v.co - e.other_vert(v).co
            s += n.dot(d); q += d.length_squared
        cv[v.index] = (2.0 * s / q) if q > 1e-12 else 0.0   # ~ 1/raio (positivo = convexo)
    for f in bm.faces:
        if f.material_index == cont:
            continue
        for lo in f.loops:
            v = lo.vert
            if v.index in hull:
                continue
            a = ao.get(v.index, 1.0)
            c = cv.get(v.index, 0.0) * curv_scale
            lo[uv2].uv = (a, max(-1.0, min(1.0, c)))
            if f.material_index != eye:
                p = v.co
                ch = noise.noise(p * chip_scale) * 0.6 + noise.noise(p * chip_scale * 2.7 + Vector((5, 1, 3))) * 0.4
                lo[uv1].uv = (0.5 + 0.5 * ch, (p.z - z0) / max(1e-4, z1 - z0))
                if glows:
                    r, g, b_, al = lo[col]
                    for (gc, gr, gcol, gk) in glows:
                        dd = (p - Vector(gc)).length
                        k = gk * max(0.0, 1.0 - dd / gr) ** 1.6
                        if k > 0:
                            cc = hexc(gcol)
                            r += (cc[0] - r) * k * 0.7 + cc[0] * k * 0.25
                            g += (cc[1] - g) * k * 0.7 + cc[1] * k * 0.25
                            b_ += (cc[2] - b_) * k * 0.7 + cc[2] * k * 0.25
                    lo[col] = (r, g, b_, al)
    import statistics
    if ao: print('  AO quantis', [round(x, 2) for x in statistics.quantiles(list(ao.values()), n=10)], 'curv', [round(x * curv_scale, 2) for x in statistics.quantiles(list(cv.values()), n=10)])
    bm.to_mesh(me); bm.free()

def assemble(B, name, armature=True, subd=1, bake_kw=None):
    obs = []
    for k in ('sub', 'flat'):
        bm = B.bms[k]
        if len(bm.verts) == 0:
            bm.free(); continue
        ob = _obj_from_bm(bm, name + '_' + k)
        for g in B.groups:
            ob.vertex_groups.new(name=g)
        if k == 'sub' and subd > 0:
            bpy.context.view_layer.objects.active = ob
            mod = ob.modifiers.new('cc', 'SUBSURF'); mod.levels = subd; mod.render_levels = subd
            mod.uv_smooth = 'PRESERVE_BOUNDARIES'
            bpy.ops.object.modifier_apply(modifier='cc')
        obs.append(ob)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    if len(obs) > 1:
        bpy.ops.object.join()
    ob = obs[0]
    ob.name = name; ob.data.name = name
    ob.data.color_attributes.active_color_name = 'Col'
    bake(ob, B.groups, B.glows, **(bake_kw or {}))
    if not armature:
        return None, ob
    ad = bpy.data.armatures.new(name + '_rig')
    arm = bpy.data.objects.new(name + '_rig', ad)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = {}
    for bn, h, t, p in B.bones:
        b = ad.edit_bones.new(bn)
        h, t = Vector(h), Vector(t)
        if (t - h).length < 1e-4:
            t = h + Vector((0, 0, 0.05))
        b.head, b.tail = h, t
        if p:
            b.parent = eb[p]
            b.use_connect = False
        eb[bn] = b
    bpy.ops.object.mode_set(mode='OBJECT')
    ob.parent = arm
    mod = ob.modifiers.new('Armature', 'ARMATURE'); mod.object = arm
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    return arm, ob

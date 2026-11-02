"""
Personagens com esqueleto (armature) para o Smash na Areia.

O corpo é UMA malha contínua gerada pelo modificador Skin do Blender a partir
de um "esqueleto de palitos" (juntas + raios), suavizada com Subdivision
Surface. Isso dá o visual limpo de boneco de borracha, sem emendas, e permite
dobrar joelhos e cotovelos. A cabeça é uma esfera grande com rosto simples
(olhos ovais, sorriso), e os cabelos são malhas presas ao osso da cabeça.

Também gera a raquete (anexada à mão no Godot) e os torcedores da plateia.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import build_assets as B


# ---------------------------------------------------------------- esqueleto

def mirror(name):
    return name.replace(".R", ".L")


def sym(points):
    """Completa um dicionário de juntas .R com as .L espelhadas em X."""
    out = dict(points)
    for k, v in points.items():
        if k.endswith(".R"):
            out[mirror(k)] = (-v[0], v[1], v[2]) if len(v) == 3 else v
    return out


PLAYER_J = sym({
    "pelvis": (0, 0, 0.96), "spine": (0, 0, 1.13), "chest": (0, 0, 1.33), "neck": (0, 0, 1.47),
    "headbase": (0, 0, 1.55), "headtop": (0, 0, 2.02),
    "shoulder.R": (-0.2, 0, 1.4), "elbow.R": (-0.25, 0.01, 1.15), "wrist.R": (-0.28, 0, 0.93),
    "hand.R": (-0.29, -0.005, 0.85),
    "hip.R": (-0.1, 0, 0.93), "knee.R": (-0.11, -0.012, 0.52), "ankle.R": (-0.115, 0.0, 0.1),
    "toe.R": (-0.115, -0.15, 0.045),
})

PLAYER_R = sym({
    "pelvis": (0.165, 0.125), "spine": (0.15, 0.112), "chest": (0.19, 0.13), "neck": (0.062, 0.062),
    "shoulder.R": (0.072, 0.072), "elbow.R": (0.056, 0.056), "wrist.R": (0.046, 0.046), "hand.R": (0.056, 0.05),
    "hip.R": (0.088, 0.088), "knee.R": (0.068, 0.068), "ankle.R": (0.05, 0.05), "toe.R": (0.052, 0.04),
})

PLAYER_EDGES = [("pelvis", "spine"), ("spine", "chest"), ("chest", "neck")]
for _s in (".R", ".L"):
    PLAYER_EDGES += [("chest", "shoulder" + _s), ("shoulder" + _s, "elbow" + _s), ("elbow" + _s, "wrist" + _s),
                     ("wrist" + _s, "hand" + _s), ("pelvis", "hip" + _s), ("hip" + _s, "knee" + _s),
                     ("knee" + _s, "ankle" + _s), ("ankle" + _s, "toe" + _s)]

# (osso, junta inicial, junta final, pai)
PLAYER_BONES = [("Hips", "pelvis", "spine", None), ("Spine", "spine", "chest", "Hips"),
                ("Chest", "chest", "neck", "Spine"), ("Neck", "neck", "headbase", "Chest"),
                ("Head", "headbase", "headtop", "Neck")]
for _s in (".R", ".L"):
    PLAYER_BONES += [("UpperArm" + _s, "shoulder" + _s, "elbow" + _s, "Chest"),
                     ("LowerArm" + _s, "elbow" + _s, "wrist" + _s, "UpperArm" + _s),
                     ("Hand" + _s, "wrist" + _s, "hand" + _s, "LowerArm" + _s),
                     ("UpperLeg" + _s, "hip" + _s, "knee" + _s, "Hips"),
                     ("LowerLeg" + _s, "knee" + _s, "ankle" + _s, "UpperLeg" + _s),
                     ("Foot" + _s, "ankle" + _s, "toe" + _s, "LowerLeg" + _s)]


def skin_mesh(name, joints, radii, edges, root, subsurf=2):
    """Malha contínua pelo modificador Skin + Subdivision (já aplicados)."""
    used = {n for e in edges for n in e}
    names = [n for n in joints.keys() if n in used]
    idx = {n: i for i, n in enumerate(names)}
    me = bpy.data.meshes.new(name + "_skel")
    me.from_pydata([joints[n] for n in names], [(idx[a], idx[b]) for a, b in edges], [])
    ob = bpy.data.objects.new(name + "_skel", me)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("skin", "SKIN")
    mod.use_smooth_shade = True
    mod.branch_smoothing = 0.6
    layer = me.skin_vertices[0].data
    for n in names:
        layer[idx[n]].radius = radii[n]
        layer[idx[n]].use_root = (n == root)
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = subsurf
    sub.render_levels = subsurf
    dg = bpy.context.evaluated_depsgraph_get()
    out = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    return out


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def bone_segments(joints, bones):
    return [(bn, Vector(joints[h]), Vector(joints[t])) for bn, h, t, _ in bones]


BONE_R = {"Hips": 0.16, "Spine": 0.15, "Chest": 0.18, "Neck": 0.06, "Head": 0.3,
          "UpperArm": 0.068, "LowerArm": 0.052, "Hand": 0.052, "UpperLeg": 0.085, "LowerLeg": 0.062,
          "Foot": 0.05}


def bone_radius(bn):
    return BONE_R.get(bn.split(".")[0], 0.08)


def nearest_bone(p, segs, skip=()):
    """Osso mais próximo em distância normalizada pela grossura do membro."""
    best, bd = None, 1e9
    for bn, a, b in segs:
        if bn in skip:
            continue
        d = seg_dist(p, a, b) / bone_radius(bn)
        if d < bd:
            best, bd = bn, d
    return best, bd


def make_armature(name, joints, bones):
    data = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bn, h, t, parent in bones:
        eb = data.edit_bones.new(bn)
        eb.head = joints[h]
        eb.tail = joints[t]
        eb.roll = 0.0
        if parent:
            eb.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def bind(ob, arm, weights):
    """weights: lista (por vértice) de dicionários osso -> peso."""
    groups = {}
    for vi, wd in enumerate(weights):
        for bn, w in wd.items():
            if bn not in groups:
                groups[bn] = ob.vertex_groups.new(name=bn)
            groups[bn].add([vi], w, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def smooth_weights(me, segs, skip=(), sharp=6.0):
    out = []
    for v in me.vertices:
        p = v.co
        ds = []
        for bn, a, b in segs:
            if bn in skip:
                continue
            ds.append((seg_dist(p, a, b) / bone_radius(bn), bn))
        ds.sort()
        dmin = ds[0][0]
        cand = [(d, bn) for d, bn in ds[:3] if d < dmin * 1.35 + 0.1]
        ws = {bn: 1.0 / (d + 0.1) ** sharp for d, bn in cand}
        tot = sum(ws.values())
        out.append({bn: w / tot for bn, w in ws.items()})
    return out


def rigid_weights(me, bone):
    return [{bone: 1.0} for _ in me.vertices]


# ---------------------------------------------------------------- jogador

def player_materials():
    return {
        "skin": B.material("Skin", "#f2b98a"),
        "shirt": B.material("Shirt", "#2f8cff"),
        "shorts": B.material("Shorts", "#ffd23f"),
        "hair": B.material("Hair", "#3b2416"),
        "pupil": B.material("Pupil", "#1a1226", 0.3),
        "shine": B.material("EyeShine", "#ffffff", 0.3),
        "mouth": B.material("Mouth", "#5a1a2a"),
        "cheek": B.material("Cheek", "#ff8f8f"),
        "band": B.material("Band", "#ff3b3b"),
        "trim": B.material("ShirtTrim", "#ffffff"),
        "shades": B.material("Shades", "#151020", 0.2),
    }


def player_body(M):
    me = skin_mesh("Body", PLAYER_J, PLAYER_R, PLAYER_EDGES, "pelvis", subsurf=2)
    segs = bone_segments(PLAYER_J, PLAYER_BONES)
    for m in (M["skin"], M["shirt"], M["shorts"], M["trim"]):
        me.materials.append(m)
    sleeve_z = PLAYER_J["shoulder.R"][2] - 0.1
    for poly in me.polygons:
        c = poly.center
        bn, _ = nearest_bone(c, segs, skip=("Head",))
        mat = 0
        if bn in ("Spine", "Chest", "Hips") and c.z > 1.03:
            mat = 1
            if c.z > 1.43 and abs(c.x) < 0.085:
                mat = 0          # gola: pescoço aparece
        elif bn in ("Spine", "Chest", "Hips"):
            mat = 2
        elif bn.startswith("UpperArm") and c.z > sleeve_z:
            mat = 1
        elif bn.startswith("UpperLeg") and c.z > 0.66:
            mat = 2
        poly.material_index = mat
        poly.use_smooth = True
    me.name = "Body"
    ob = bpy.data.objects.new("Body", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob, smooth_weights(me, segs, skip=("Head",))


def player_head(M):
    b = B.Builder("HeadMesh")
    hc = (0, 0, 1.76)
    b.sphere(hc, 0.3, M["skin"], scale=(1.0, 0.97, 0.95), seg=28, rings=18)
    for s in (-1, 1):
        x = 0.105 * s
        b.sphere((x, -0.262, 1.79), 1.0, M["pupil"], scale=(0.044, 0.024, 0.066), seg=16, rings=10)
        b.sphere((x - 0.014 * s, -0.287, 1.815), 0.016, M["shine"], seg=8, rings=6)
        b.sphere((x * 1.05, -0.282, 1.878), 1.0, M["hair"], scale=(0.05, 0.018, 0.015), seg=10, rings=6,
                 rot=B.rot_y(-14 * s))
        b.sphere((0.175 * s, -0.228, 1.69), 1.0, M["cheek"], scale=(0.048, 0.02, 0.028), seg=10, rings=6)
        b.sphere((0.293 * s, 0.0, 1.75), 1.0, M["skin"], scale=(0.04, 0.055, 0.07), seg=10, rings=8)
    b.sphere((0, -0.296, 1.73), 0.032, M["skin"], seg=10, rings=8)
    b.sphere((0, -0.276, 1.676), 1.0, M["mouth"], scale=(0.058, 0.02, 0.03), seg=14, rings=10, cut_above=1.676)
    ob = b.build()
    return ob


def hair_variants(M):
    out = []
    # Tuca: espetado limpo (poucas mechas grandes)
    b = B.Builder("Hair_Spiky")
    b.sphere((0, 0.035, 1.86), 1.0, M["hair"], scale=(0.316, 0.312, 0.245), seg=22, rings=12, cut_below=1.73)
    for ax, ay, az in [(0, 0.4, 1), (-0.55, 0.2, 0.9), (0.55, 0.2, 0.9), (-0.3, 0.75, 0.7), (0.3, 0.75, 0.7)]:
        d = Vector((ax, ay, az)).normalized()
        base = Vector((0, 0.04, 1.88)) + d * 0.2
        b.cone(base, d, 0.2, 0.1, 0.012, M["hair"], seg=8)
    out.append(b.build())
    # Bia: rabo de cavalo
    b = B.Builder("Hair_Pony")
    b.sphere((0, 0.035, 1.85), 1.0, M["hair"], scale=(0.318, 0.315, 0.255), seg=22, rings=12, cut_below=1.7)
    for i in range(5):
        t = i / 4.0
        b.sphere((0, 0.31 + t * 0.12, 1.95 - t * 0.33), 0.1 - t * 0.035, M["hair"], seg=12, rings=8)
    b.sphere((0, 0.29, 1.95), 1.0, M["band"], scale=(0.07, 0.04, 0.07), seg=10, rings=6)
    out.append(b.build())
    # Zeca: boné
    b = B.Builder("Cap")
    b.sphere((0, 0.02, 1.86), 1.0, M["band"], scale=(0.322, 0.322, 0.25), seg=22, rings=12, cut_below=1.875)
    b.sphere((0, -0.31, 1.89), 1.0, M["band"], scale=(0.2, 0.16, 0.022), seg=18, rings=6)
    b.sphere((0, 0.02, 2.1), 0.035, M["trim"], seg=8, rings=6)
    b.sphere((0, 0.08, 1.78), 1.0, M["hair"], scale=(0.3, 0.27, 0.12), seg=16, rings=8, cut_below=1.72)
    out.append(b.build())
    # Lola: dois coques afro + faixa
    b = B.Builder("Hair_Puffs")
    b.sphere((0, 0.04, 1.86), 1.0, M["hair"], scale=(0.33, 0.325, 0.26), seg=22, rings=12, cut_below=1.7)
    for s in (-1, 1):
        b.sphere((0.22 * s, 0.06, 2.0), 0.16, M["hair"], seg=16, rings=10)
    b.sphere((0, -0.0, 1.93), 1.0, M["band"], scale=(0.335, 0.33, 0.035), seg=22, rings=6)
    out.append(b.build())
    # Juiz: viseira + óculos escuros
    b = B.Builder("Shades")
    b.box((0, -0.282, 1.8), (0.32, 0.03, 0.07), M["shades"], smooth=True)
    b.sphere((0, 0.03, 1.87), 1.0, M["trim"], scale=(0.31, 0.31, 0.04), seg=20, rings=6)
    b.sphere((0, -0.3, 1.88), 1.0, M["trim"], scale=(0.19, 0.14, 0.02), seg=16, rings=6)
    b.sphere((0, 0.06, 1.83), 1.0, M["hair"], scale=(0.3, 0.27, 0.12), seg=16, rings=8, cut_below=1.78)
    out.append(b.build())
    return out


def player_trims(M, arm):
    """Faixas que escondem as emendas: cós, barra do short e mangas."""
    parts = []
    b = B.Builder("Waist")
    b.sphere((0, 0, 1.03), 1.0, M["trim"], scale=(0.172, 0.135, 0.03), seg=24, rings=6)
    parts.append((b.build(), "Hips"))
    b = B.Builder("Collar")
    b.sphere((0, 0.0, 1.435), 1.0, M["trim"], scale=(0.098, 0.09, 0.022), seg=18, rings=6)
    parts.append((b.build(), "Chest"))
    for s, sx in ((".R", -1), (".L", 1)):
        b = B.Builder("Cuff" + s)
        b.sphere((0.1 * sx, 0, 0.665), 1.0, M["shorts"], scale=(0.095, 0.095, 0.026), seg=18, rings=6)
        parts.append((b.build(), "UpperLeg" + s))
        b = B.Builder("Sleeve" + s)
        sh = Vector(PLAYER_J["shoulder" + s])
        el = Vector(PLAYER_J["elbow" + s])
        c = sh.lerp(el, 0.36)
        d = (el - sh).normalized()
        rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        b.sphere(tuple(c), 1.0, M["trim"], scale=(0.078, 0.078, 0.022), seg=16, rings=6, rot=rot)
        parts.append((b.build(), "UpperArm" + s))
    for ob, bone in parts:
        bind(ob, arm, rigid_weights(ob.data, bone))


def build_player():
    B.reset_scene()
    M = player_materials()
    arm = make_armature("Rig", PLAYER_J, PLAYER_BONES)
    body, w = player_body(M)
    bind(body, arm, w)
    player_trims(M, arm)
    head = player_head(M)
    bind(head, arm, rigid_weights(head.data, "Head"))
    for h in hair_variants(M):
        bind(h, arm, rigid_weights(h.data, "Head"))
    B.export("player")


def build_racket():
    B.reset_scene()
    racket = B.material("Racket", "#ff5fa2", 0.5)
    rim = B.material("RacketRim", "#1d1d2b", 0.5)
    grip = B.material("Grip", "#ffffff")
    b = B.Builder("Racket")
    b.cone((0, 0, 0.05), (0, 0, -1), 0.21, 0.024, 0.022, grip, seg=10)
    b.cone((0, 0, -0.16), (0, 0, -1), 0.07, 0.028, 0.05, rim, seg=10)
    b.sphere((0, 0, -0.42), 1.0, rim, scale=(0.15, 0.03, 0.19), seg=24, rings=10)
    b.sphere((0, 0, -0.42), 1.0, racket, scale=(0.14, 0.036, 0.178), seg=24, rings=10)
    for ix, iz in [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (-1, 1), (1, -1), (0, 2), (0, -2)]:
        for fy in (-1, 1):
            b.sphere((ix * 0.055, 0.035 * fy, -0.42 + iz * 0.055), 0.014, rim, seg=6, rings=4)
    b.build()
    B.export("racket")


# ---------------------------------------------------------------- plateia

FAN_J = sym({
    "pelvis": (0, 0, 0.82), "chest": (0, 0, 1.18), "neck": (0, 0, 1.3),
    "shoulder.R": (-0.17, 0, 1.24), "elbow.R": (-0.22, -0.04, 1.0), "hand.R": (-0.2, -0.12, 0.84),
    "hip.R": (-0.09, 0, 0.8), "knee.R": (-0.095, -0.02, 0.44), "foot.R": (-0.095, -0.06, 0.05),
})
FAN_R = sym({
    "pelvis": (0.15, 0.11), "chest": (0.17, 0.12), "neck": (0.055, 0.055),
    "shoulder.R": (0.06, 0.06), "elbow.R": (0.048, 0.048), "hand.R": (0.05, 0.05),
    "hip.R": (0.075, 0.075), "knee.R": (0.06, 0.06), "foot.R": (0.055, 0.06),
})
FAN_EDGES = [("pelvis", "chest"), ("chest", "neck")]
for _s in (".R", ".L"):
    FAN_EDGES += [("chest", "shoulder" + _s), ("shoulder" + _s, "elbow" + _s), ("elbow" + _s, "hand" + _s),
                  ("pelvis", "hip" + _s), ("hip" + _s, "knee" + _s), ("knee" + _s, "foot" + _s)]

REGION_UV = {"Shirt": 0.1, "Skin": 0.3, "Hair": 0.5, "Prop": 0.7, "Pants": 0.9}


def fan_pose(variant):
    j = dict(FAN_J)
    if variant in ("up", "sign"):
        for s, sx in ((".R", -1), (".L", 1)):
            j["elbow" + s] = (0.24 * sx, -0.02, 1.48)
            j["hand" + s] = (0.2 * sx if variant == "up" else 0.15 * sx, -0.04, 1.72 if variant == "up" else 1.7)
    elif variant == "finger":
        j["elbow.R"] = (-0.24, -0.04, 1.47)
        j["hand.R"] = (-0.22, -0.08, 1.7)
    elif variant == "clap":
        for s, sx in ((".R", -1), (".L", 1)):
            j["elbow" + s] = (0.2 * sx, -0.14, 1.06)
            j["hand" + s] = (0.03 * sx, -0.24, 1.18)
    return j


def build_fan(variant):
    B.reset_scene()
    mats = {k: B.material("Fan" + k, "#ffffff") for k in REGION_UV}
    j = fan_pose(variant)
    me = skin_mesh("Fan", j, FAN_R, FAN_EDGES, "pelvis", subsurf=1)
    b = B.Builder("Fan_" + variant)
    b.bm.from_mesh(me)
    for k in REGION_UV:
        b._mi(mats[k])
    arm_segs = []
    for s in (".R", ".L"):
        arm_segs.append((Vector(j["shoulder" + s]), Vector(j["elbow" + s]), Vector(j["hand" + s])))
    for f in b.bm.faces:
        c = f.calc_center_median()
        reg = "Shirt"
        if c.z < 0.72:
            reg = "Pants" if c.z > 0.16 else "Skin"
        elif c.z < 0.86 and abs(c.x) < 0.2:
            reg = "Pants"
        for sh, el, ha in arm_segs:
            if seg_dist(c, el, ha) < 0.07 or (seg_dist(c, sh, el) < 0.065 and (c - sh).length > 0.12):
                reg = "Skin"
        if c.z > 1.27 and abs(c.x) < 0.08:
            reg = "Skin"
        f.material_index = b._mi(mats[reg])
        f.smooth = True
    # cabeça e cabelo/chapéu
    b.sphere((0, 0, 1.47), 0.19, mats["Skin"], seg=14, rings=10)
    hat = {"up": 0, "sign": 1, "finger": 2, "clap": 3}[variant]
    if hat == 0:
        b.sphere((0, 0.02, 1.53), 1.0, mats["Hair"], scale=(0.2, 0.2, 0.17), seg=14, rings=8, cut_below=1.47)
    elif hat == 1:
        b.sphere((0, 0, 1.55), 1.0, mats["Hair"], scale=(0.2, 0.2, 0.14), seg=14, rings=8, cut_below=1.55)
        b.sphere((0, -0.2, 1.56), 1.0, mats["Hair"], scale=(0.13, 0.1, 0.015), seg=12, rings=4)
    elif hat == 2:
        b.sphere((0, 0, 1.53), 1.0, mats["Hair"], scale=(0.34, 0.34, 0.03), seg=16, rings=4)
        b.sphere((0, 0, 1.58), 1.0, mats["Hair"], scale=(0.16, 0.16, 0.1), seg=12, rings=6, cut_below=1.56)
    else:
        b.sphere((0, 0.04, 1.54), 0.2, mats["Hair"], seg=12, rings=8, cut_below=1.46)
    # adereços
    if variant == "sign":
        b.box((0, -0.06, 1.86), (0.62, 0.03, 0.34), mats["Prop"], smooth=False)
    elif variant == "finger":
        b.sphere((-0.22, -0.1, 1.8), 1.0, mats["Prop"], scale=(0.08, 0.05, 0.13), seg=10, rings=8)
        b.sphere((-0.22, -0.11, 1.95), 1.0, mats["Prop"], scale=(0.03, 0.03, 0.08), seg=8, rings=6)
    for f in b.bm.faces:
        f.smooth = f.smooth or True
    ob = b.build()
    # UV: x = região (cor escolhida no shader), y = quanto o vértice é "braço" (para acenar)
    me2 = ob.data
    uv = me2.uv_layers.new(name="UVMap")
    names = [m.name for m in me2.materials]
    for poly in me2.polygons:
        code = REGION_UV[names[poly.material_index][3:]]
        for li in poly.loop_indices:
            z = me2.vertices[me2.loops[li].vertex_index].co.z
            arm = max(0.0, min(1.0, (z - 1.3) / 0.5)) if variant != "clap" else 0.0
            uv.data[li].uv = (code, arm)
    B.export("fan_" + variant)


def build_all():
    build_player()
    build_racket()
    for v in ("up", "sign", "finger", "clap"):
        build_fan(v)

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
    """Corpo inteiro na cor da pele; a roupa é outra malha por cima.
    O tronco é mais fino que a roupa para nunca atravessar o tecido."""
    radii = dict(PLAYER_R)
    for k, d in (("pelvis", 0.05), ("spine", 0.045), ("chest", 0.05), ("hip.R", 0.025), ("hip.L", 0.025),
                 ("shoulder.R", 0.016), ("shoulder.L", 0.016)):
        radii[k] = (radii[k][0] - d, radii[k][1] - d * 0.8)
    me = skin_mesh("Body", PLAYER_J, radii, PLAYER_EDGES, "pelvis", subsurf=2)
    segs = bone_segments(PLAYER_J, PLAYER_BONES)
    me.materials.append(M["skin"])
    for poly in me.polygons:
        poly.material_index = 0
        poly.use_smooth = True
    me.name = "Body"
    ob = bpy.data.objects.new("Body", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob, smooth_weights(me, segs, skip=("Head",))


def _lerp(a, b, t):
    return tuple(a[k] + (b[k] - a[k]) * t for k in range(3))


def clothing(M, name, joints, radii, edges, root, mat):
    """Peça de roupa: malha Skin um pouco maior que o corpo, com bordas
    arredondadas (barra, manga, gola), presa aos mesmos ossos."""
    me = skin_mesh(name, joints, radii, edges, root, subsurf=2)
    me.materials.append(mat)
    for poly in me.polygons:
        poly.use_smooth = True
    me.name = name
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    segs = bone_segments(PLAYER_J, PLAYER_BONES)
    return ob, smooth_weights(me, segs, skip=("Head",))


def player_clothes(M):
    J = PLAYER_J
    shirt_j = {"hem": (0, 0, 0.98), "spine": J["spine"], "chest": J["chest"], "collar": (0, 0, 1.47)}
    shirt_r = {"hem": (0.19, 0.15), "spine": (0.166, 0.128), "chest": (0.205, 0.146), "collar": (0.085, 0.082)}
    edges = [("hem", "spine"), ("spine", "chest"), ("chest", "collar")]
    for sd in (".R", ".L"):
        shirt_j["sh" + sd] = J["shoulder" + sd]
        shirt_j["sl" + sd] = _lerp(J["shoulder" + sd], J["elbow" + sd], 0.42)
        shirt_r["sh" + sd] = (0.088, 0.088)
        shirt_r["sl" + sd] = (0.074, 0.074)
        edges += [("chest", "sh" + sd), ("sh" + sd, "sl" + sd)]
    out = [clothing(M, "Shirt", shirt_j, shirt_r, edges, "hem", M["shirt"])]
    sj = {"waist": (0, 0, 0.95)}
    sr = {"waist": (0.15, 0.114)}
    se = []
    for sd in (".R", ".L"):
        sj["hp" + sd] = J["hip" + sd]
        sj["lg" + sd] = _lerp(J["hip" + sd], J["knee" + sd], 0.55)
        sr["hp" + sd] = (0.1, 0.1)
        sr["lg" + sd] = (0.096, 0.096)
        se += [("waist", "hp" + sd), ("hp" + sd, "lg" + sd)]
    out.append(clothing(M, "Shorts", sj, sr, se, "waist", M["shorts"]))
    # regata: sem mangas, gola mais aberta
    tank_j = {k: shirt_j[k] for k in ("hem", "spine", "chest")}
    tank_j["collar"] = (0, 0, 1.43)
    tank_r = {"hem": (0.188, 0.148), "spine": (0.164, 0.126), "chest": (0.2, 0.142), "collar": (0.13, 0.1)}
    out.append(clothing(M, "Tank", tank_j, tank_r, [("hem", "spine"), ("spine", "chest"), ("chest", "collar")],
                        "hem", M["shirt"]))
    # listras da camiseta: anéis finos um pouco maiores que o tecido
    for i, z in enumerate((1.12, 1.26)):
        kz = (z - 0.98) / (1.36 - 0.98)
        rx = 0.19 + (0.205 - 0.19) * kz + 0.01
        ry = 0.15 + (0.146 - 0.15) * kz + 0.01
        sj2 = {"a": (0, 0, z - 0.045), "b": (0, 0, z + 0.045)}
        sr2 = {"a": (rx, ry), "b": (rx, ry)}
        out.append(clothing(M, "Stripe%d" % i, sj2, sr2, [("a", "b")], "a", M["trim"]))
    # bermuda: perna mais longa, até perto do joelho
    bj = {"waist": (0, 0, 0.95)}
    br = {"waist": (0.152, 0.116)}
    be = []
    for sd in (".R", ".L"):
        bj["hp" + sd] = J["hip" + sd]
        bj["lg" + sd] = _lerp(J["hip" + sd], J["knee" + sd], 0.86)
        br["hp" + sd] = (0.102, 0.102)
        br["lg" + sd] = (0.088, 0.088)
        be += [("waist", "hp" + sd), ("hp" + sd, "lg" + sd)]
    out.append(clothing(M, "Bermuda", bj, br, be, "waist", M["shorts"]))
    # faixa da bermuda (cor de detalhe)
    for sd in (".R", ".L"):
        c = _lerp(J["hip" + sd], J["knee" + sd], 0.8)
        d = _lerp(J["hip" + sd], J["knee" + sd], 0.86)
        out.append(clothing(M, "BermudaBand" + sd, {"a": c, "b": d}, {"a": (0.093, 0.093), "b": (0.093, 0.093)},
                            [("a", "b")], "a", M["trim"]))
    return out


def player_head(M):
    b = B.Builder("HeadMesh")
    b.sphere((0, 0, 1.76), 0.3, M["skin"], scale=(1.0, 0.97, 0.95), seg=32, rings=20)
    for s in (-1, 1):
        x = 0.105 * s
        b.sphere((x, -0.262, 1.79), 1.0, M["pupil"], scale=(0.046, 0.026, 0.068), seg=16, rings=10)
        b.sphere((x - 0.014 * s, -0.288, 1.815), 0.017, M["shine"], seg=8, rings=6)
        b.sphere((0.172 * s, -0.226, 1.69), 1.0, M["cheek"], scale=(0.05, 0.022, 0.03), seg=12, rings=6)
        b.sphere((0.292 * s, 0.0, 1.75), 1.0, M["skin"], scale=(0.04, 0.055, 0.07), seg=12, rings=8)
    b.sphere((0, -0.279, 1.68), 1.0, M["mouth"], scale=(0.055, 0.02, 0.028), seg=16, rings=10, cut_above=1.68)
    return b.build()


def _hair_cap(b, M, scale=(0.316, 0.31, 0.255), center=(0, 0.06, 1.86)):
    # forma fechada: a linha do cabelo nasce da interseção com a cabeça (sem corte reto)
    b.sphere(center, 1.0, M["hair"], scale=scale, seg=26, rings=14)


def hair_variants(M):
    out = []
    b = B.Builder("Hair_Spiky")
    _hair_cap(b, M)
    for ax, ay, az in [(0, 0.35, 1), (-0.55, 0.2, 0.9), (0.55, 0.2, 0.9), (-0.3, 0.75, 0.7), (0.3, 0.75, 0.7)]:
        d = Vector((ax, ay, az)).normalized()
        base = Vector((0, 0.05, 1.88)) + d * 0.19
        b.cone(base, d, 0.2, 0.105, 0.015, M["hair"], seg=10)
    out.append(b.build())
    b = B.Builder("Hair_Pony")
    _hair_cap(b, M, (0.32, 0.315, 0.262), (0, 0.06, 1.85))
    for i in range(4):
        t = i / 3.0
        b.sphere((0, 0.32 + t * 0.1, 1.92 - t * 0.3), 0.1 - t * 0.03, M["hair"], seg=14, rings=10)
    out.append(b.build())
    b = B.Builder("Cap")
    b.sphere((0, 0.02, 1.9), 1.0, M["band"], scale=(0.326, 0.326, 0.2), seg=26, rings=14)
    b.sphere((0, -0.29, 1.9), 1.0, M["band"], scale=(0.2, 0.17, 0.026), seg=20, rings=8)
    b.sphere((0, 0.1, 1.8), 1.0, M["hair"], scale=(0.29, 0.24, 0.15), seg=18, rings=10)
    out.append(b.build())
    b = B.Builder("Hair_Puffs")
    _hair_cap(b, M, (0.325, 0.32, 0.26))
    for s in (-1, 1):
        b.sphere((0.21 * s, 0.07, 2.0), 0.15, M["hair"], seg=18, rings=12)
    out.append(b.build())
    b = B.Builder("Shades")
    b.box((0, -0.282, 1.8), (0.32, 0.03, 0.07), M["shades"], smooth=True)
    b.sphere((0, 0.02, 1.9), 1.0, M["trim"], scale=(0.326, 0.326, 0.2), seg=26, rings=14)
    b.sphere((0, -0.29, 1.9), 1.0, M["trim"], scale=(0.2, 0.17, 0.026), seg=20, rings=8)
    out.append(b.build())
    return out


def build_player():
    B.reset_scene()
    M = player_materials()
    arm = make_armature("Rig", PLAYER_J, PLAYER_BONES)
    body, w = player_body(M)
    bind(body, arm, w)
    for ob, cw in player_clothes(M):
        bind(ob, arm, cw)
    head = player_head(M)
    bind(head, arm, rigid_weights(head.data, "Head"))
    for h in hair_variants(M):
        bind(h, arm, rigid_weights(h.data, "Head"))
    B.export("player")


def _racket_handle(b, rim, grip):
    b.cone((0, 0, 0.05), (0, 0, -1), 0.21, 0.024, 0.022, grip, seg=10)
    b.cone((0, 0, -0.16), (0, 0, -1), 0.07, 0.028, 0.05, rim, seg=10)


def _racket_holes(b, rim, pts, cz, step=0.055, y=0.035):
    for ix, iz in pts:
        for fy in (-1, 1):
            b.sphere((ix * step, y * fy, cz + iz * step), 0.014, rim, seg=6, rings=4)


def build_racket():
    """Três modelos de raquete (mesmo cabo, cabeça centrada em z = -0.42)."""
    holes = [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (-1, 1), (1, -1), (0, 2), (0, -2)]
    # clássica: redonda
    B.reset_scene()
    racket = B.material("Racket", "#ff5fa2", 0.5)
    rim = B.material("RacketRim", "#1d1d2b", 0.5)
    grip = B.material("Grip", "#ffffff")
    b = B.Builder("Racket")
    _racket_handle(b, rim, grip)
    b.sphere((0, 0, -0.42), 1.0, rim, scale=(0.15, 0.03, 0.19), seg=24, rings=10)
    b.sphere((0, 0, -0.42), 1.0, racket, scale=(0.14, 0.036, 0.178), seg=24, rings=10)
    _racket_holes(b, rim, holes, -0.42)
    b.build()
    B.export("racket")
    # gota: cabeça mais longa e estreita, com detalhe claro (controle)
    B.reset_scene()
    racket = B.material("Racket", "#35e0a1", 0.5)
    rim = B.material("RacketRim", "#1d1d2b", 0.5)
    grip = B.material("Grip", "#ffffff")
    deco = B.material("RacketDeco", "#ffffff", 0.5)
    b = B.Builder("Racket")
    _racket_handle(b, rim, grip)
    b.sphere((0, 0, -0.44), 1.0, rim, scale=(0.13, 0.03, 0.215), seg=24, rings=10)
    b.sphere((0, 0, -0.44), 1.0, racket, scale=(0.12, 0.036, 0.203), seg=24, rings=10)
    b.sphere((0, 0, -0.3), 1.0, rim, scale=(0.07, 0.034, 0.06), seg=16, rings=8)
    b.sphere((0, 0, -0.5), 1.0, deco, scale=(0.08, 0.038, 0.09), seg=20, rings=8)
    _racket_holes(b, rim, [(0, 0), (0, 1), (0, -1), (0, 2), (-1, 0), (1, 0), (-1, 1), (1, 1), (0, -2), (0, 3)], -0.44,
                  step=0.05)
    b.build()
    B.export("racket_gota")
    # power: cabeça larga e mais grossa, aro duplo (força)
    B.reset_scene()
    racket = B.material("Racket", "#ff9f1c", 0.5)
    rim = B.material("RacketRim", "#1d1d2b", 0.5)
    grip = B.material("Grip", "#ffffff")
    deco = B.material("RacketDeco", "#ffffff", 0.5)
    b = B.Builder("Racket")
    _racket_handle(b, rim, grip)
    b.sphere((0, 0, -0.41), 1.0, rim, scale=(0.172, 0.036, 0.18), seg=28, rings=10)
    b.sphere((0, 0, -0.41), 1.0, deco, scale=(0.162, 0.04, 0.17), seg=28, rings=10)
    b.sphere((0, 0, -0.41), 1.0, racket, scale=(0.146, 0.044, 0.154), seg=28, rings=10)
    _racket_holes(b, rim, holes + [(-2, 0), (2, 0)], -0.41, step=0.052, y=0.043)
    b.build()
    B.export("racket_power")


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

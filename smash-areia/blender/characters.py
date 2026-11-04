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
    # estilo "cavaleirinho" de aventura fofa: tronco de feijão (barriguinha cheia),
    # membros roliços que afinam pouco, como um bonequinho de vinil
    "pelvis": (0.19, 0.15), "spine": (0.175, 0.135), "chest": (0.198, 0.142), "neck": (0.07, 0.07),
    "shoulder.R": (0.086, 0.086), "elbow.R": (0.071, 0.071), "wrist.R": (0.06, 0.06), "hand.R": (0.05, 0.046),
    "hip.R": (0.102, 0.102), "knee.R": (0.083, 0.083), "ankle.R": (0.064, 0.064), "toe.R": (0.046, 0.04),
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
        layer[idx[n]].use_root = (n in root) if isinstance(root, (list, tuple)) else (n == root)
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
        "shoe": B.material("Shoe", "#f7f5f0"),
        "eyewhite": B.material("EyeWhite", "#ffffff", 0.3),
        "brow": B.material("Brow", "#3b2416"),
        "tongue": B.material("Tongue", "#ff7a8a"),
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


def leg_plane(bone, t):
    """Plano perpendicular ao osso, na fração t do comprimento."""
    for bn, h, tl, _ in PLAYER_BONES:
        if bn == bone:
            a, b = Vector(PLAYER_J[h]), Vector(PLAYER_J[tl])
            return (a + (b - a) * t, (b - a).normalized())
    raise KeyError(bone)


def body_shell(name, body_me, body_w, mat, keep, offset, cuts=()):
    """Roupa feita de uma "casca" do próprio corpo: copia as faces escolhidas,
    afasta pela normal e herda exatamente os pesos de cada vértice do corpo.
    Assim o tecido deforma igual à pele e nada atravessa, em qualquer pose.
    keep(centro, osso, t_no_osso) -> bool; offset(osso) -> distância."""
    segs = bone_segments(PLAYER_J, PLAYER_BONES)
    seg_by = {bn: (a, b) for bn, a, b in segs}
    bm = bmesh.new()
    bm.from_mesh(body_me)
    bm.normal_update()
    # pesos por posição: vértices originais mantêm o peso exato; os criados
    # pelos cortes misturam os vizinhos originais mais próximos (KD-tree)
    from mathutils import kdtree
    kd = kdtree.KDTree(len(body_me.vertices))
    for i, v in enumerate(body_me.vertices):
        kd.insert(v.co, i)
    kd.balance()
    for co, no in cuts:
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=no)

    def weight_at(p):
        hits = kd.find_n(p, 3)
        if hits[0][2] < 1e-6:
            return body_w[hits[0][1]]
        acc, tot = {}, 0.0
        for _, i, d in hits[:2]:
            k = 1.0 / max(d, 1e-6)
            tot += k
            for bn, w in body_w[i].items():
                acc[bn] = acc.get(bn, 0.0) + w * k
        return {bn: w / tot for bn, w in acc.items()}

    bm.normal_update()
    kill = []
    for f in bm.faces:
        c = f.calc_center_median()
        bn, _ = nearest_bone(c, segs, skip=("Head",))
        a, b = seg_by[bn]
        ab = b - a
        t = (c - a).dot(ab) / max(ab.length_squared, 1e-9)
        if not keep(c, bn, t):
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.verts.index_update()
    weights = [weight_at(v.co) for v in bm.verts]
    for v in bm.verts:
        bn, _ = nearest_bone(v.co, segs, skip=("Head",))
        v.co += v.normal * offset(bn)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.clear()
    me.materials.append(mat)
    for poly in me.polygons:
        poly.material_index = 0
        poly.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob, weights


TORSO = ("Hips", "Spine", "Chest")


def player_clothes(M, body_me, body_w):
    UP = Vector((0, 0, 1))
    X = Vector((1, 0, 0))

    def torso_off(bn):
        return 0.042 if bn in TORSO else 0.03

    def shirt(c, bn, t):
        if bn in TORSO:
            return 1.0 <= c.z <= 1.455
        return bn.startswith("UpperArm") and t <= 0.4

    shirt_cuts = [(Vector((0, 0, 1.0)), UP), (Vector((0, 0, 1.455)), UP),
                  leg_plane("UpperArm.R", 0.4), leg_plane("UpperArm.L", 0.4)]

    def tank(c, bn, t):
        if bn not in TORSO or not (1.0 <= c.z <= 1.42):
            return False
        return not (abs(c.x) > 0.13 and c.z > 1.3)   # cava da regata

    tank_cuts = [(Vector((0, 0, 1.0)), UP), (Vector((0, 0, 1.42)), UP), (Vector((0, 0, 1.3)), UP),
                 (Vector((0.13, 0, 0)), X), (Vector((-0.13, 0, 0)), X)]

    def band(z0, z1):
        return (lambda c, bn, t: bn in TORSO and z0 <= c.z <= z1), [(Vector((0, 0, z0)), UP), (Vector((0, 0, z1)), UP)]

    def shorts(length):
        def k(c, bn, t):
            if bn == "Hips":
                return c.z <= 1.05
            return bn.startswith("UpperLeg") and t <= length
        return k, [(Vector((0, 0, 1.05)), UP), leg_plane("UpperLeg.R", length), leg_plane("UpperLeg.L", length)]

    def legs_off(bn):
        return 0.034 if bn == "Hips" else 0.028

    s0, c0 = band(1.09, 1.15)
    s1, c1 = band(1.23, 1.29)
    sk, sc = shorts(0.55)
    bk, bc = shorts(0.84)

    # tênis: casca do pé + tornozelo, com um solado mais largo na cor do personagem
    def shoe(c, bn, t):
        return bn.startswith("Foot") or (bn.startswith("LowerLeg") and t >= 0.84)

    def sole(c, bn, t):
        return shoe(c, bn, t) and c.z <= 0.07

    shoe_cuts = [leg_plane("LowerLeg.R", 0.84), leg_plane("LowerLeg.L", 0.84)]
    sole_cuts = shoe_cuts + [(Vector((0, 0, 0.07)), UP)]

    # munhequeiras nos dois pulsos (cor do personagem)
    def wrist(c, bn, t):
        return bn.startswith("LowerArm") and 0.72 <= t <= 0.9

    wrist_cuts = [leg_plane("LowerArm.R", 0.72), leg_plane("LowerArm.R", 0.9),
                  leg_plane("LowerArm.L", 0.72), leg_plane("LowerArm.L", 0.9)]
    out = [
        body_shell("Shirt", body_me, body_w, M["shirt"], shirt, torso_off, shirt_cuts),
        body_shell("Tank", body_me, body_w, M["shirt"], tank, torso_off, tank_cuts),
        body_shell("Stripe0", body_me, body_w, M["trim"], s0, lambda bn: 0.05, c0),
        body_shell("Stripe1", body_me, body_w, M["trim"], s1, lambda bn: 0.05, c1),
        body_shell("Shorts", body_me, body_w, M["shorts"], sk, legs_off, sc),
        body_shell("Bermuda", body_me, body_w, M["shorts"], bk, legs_off, bc),
        body_shell("Wristbands", body_me, body_w, M["band"], wrist, lambda bn: 0.02, wrist_cuts),
    ]
    return out


# A cabeça é modelada no "espaço antigo" (centro 1.76, raio 0.3) e depois
# ampliada em volta do pescoço (HEAD_XF): proporção de desenho, ~2,7 cabeças de
# altura, sem precisar redesenhar cada detalhe do rosto e do cabelo.
HEAD_C = Vector((0, 0, 1.76))
HEAD_K = 1.42     # cabeção chibi (~2,2 cabeças de altura)
HEAD_XF = Matrix.Translation(Vector((0, 0, 1.885))) @ Matrix.Diagonal((HEAD_K, HEAD_K, HEAD_K, 1.0)) \
    @ Matrix.Translation(-HEAD_C)


def head_fit(ob):
    """Aplica a ampliação da cabeça numa malha feita no espaço antigo."""
    ob.data.transform(HEAD_XF)
    return ob


def face_rot(x, z, tilt=0.0):
    """Rotação que deita um detalhe do rosto sobre a curvatura da cabeça."""
    yaw = math.asin(max(-0.95, min(0.95, x / 0.3)))
    pitch = math.asin(max(-0.95, min(0.95, (z - 1.76) / 0.3)))
    return Matrix.Rotation(-yaw, 4, "Z") @ Matrix.Rotation(pitch, 4, "X") @ Matrix.Rotation(tilt, 4, "Y")


def player_head(M):
    b = B.Builder("HeadMesh")
    vs = b.sphere((0, 0, 1.76), 0.3, M["skin"], seg=40, rings=24)
    # formato de desenho: bochechas cheias embaixo, topo um pouco achatado, rosto
    # levemente chato na frente (os olhos assentam melhor)
    for v in vs:
        r = v.co - HEAD_C
        zn = r.z / 0.3
        wide = 1.0 + 0.09 * max(0.0, 0.25 - zn) - 0.03 * max(0.0, zn - 0.5)
        r.x *= wide
        r.y *= wide * (0.95 if r.y < 0 else 1.0)
        if zn > 0.55:
            r.z *= 0.97
        v.co = HEAD_C + r
    for sd in (-1, 1):
        # bochechas rosadas bem redondas (logo abaixo e por fora dos olhos) e orelhinhas
        b.sphere((0.17 * sd, -0.238, 1.682), 1.0, M["cheek"], scale=(0.05, 0.02, 0.032), seg=16, rings=8,
                 rot=face_rot(0.17 * sd, 1.682))
        b.sphere((0.3 * sd, 0.01, 1.74), 1.0, M["skin"], scale=(0.04, 0.055, 0.065), seg=14, rings=8)
    # narizinho quase imperceptível (só um volume)
    b.sphere((0, -0.292, 1.716), 1.0, M["skin"], scale=(0.022, 0.016, 0.016), seg=12, rings=6)
    # boquinha pequena e sorridente (meia-lua) com a língua aparecendo
    b.sphere((0, -0.279, 1.668), 1.0, M["mouth"], scale=(0.046, 0.02, 0.034), seg=18, rings=10, cut_above=1.668)
    b.sphere((0, -0.287, 1.648), 1.0, M["tongue"], scale=(0.024, 0.012, 0.011), seg=12, rings=6)
    return head_fit(b.build())


def _brow(b, M, s, z):
    """Sobrancelha curtinha e arredondada (traço de feijão)."""
    x = 0.104 * s
    b.sphere((x, -0.268, z), 1.0, M["brow"], scale=(0.036, 0.014, 0.013), seg=14, rings=8,
             rot=face_rot(x, z, 0.12 * s))


def eye_variants(M):
    """Olhos de desenho (ovais altos, branco, pupila grande e dois brilhos)."""
    out = []
    # olhos de "feijão": ovais pretos brilhantes, bem separados e na metade de baixo
    # do rosto (fofura de jogo de aventura chibi), com um brilho grande e um pequeno
    b = B.Builder("Eyes_Round")
    for s in (-1, 1):
        x, z = 0.112 * s, 1.752
        rot = face_rot(x, z)
        b.sphere((x, -0.262, z), 1.0, M["pupil"], scale=(0.042, 0.03, 0.066), seg=22, rings=14, rot=rot)
        b.sphere((x - 0.012 * s, -0.29, z + 0.026), 1.0, M["shine"], scale=(0.016, 0.01, 0.02), seg=10, rings=6,
                 rot=rot)
        b.sphere((x + 0.014 * s, -0.291, z - 0.028), 0.008, M["shine"], seg=8, rings=4)
        _brow(b, M, s, 1.85)
    out.append(head_fit(b.build()))
    # amendoados (Nath): feijão deitado com o canto de fora puxado para cima e um cílio
    b = B.Builder("Eyes_Almond")
    for s in (-1, 1):
        x, z = 0.114 * s, 1.758
        rot = face_rot(x, z, -0.25 * s)
        b.sphere((x, -0.262, z), 1.0, M["pupil"], scale=(0.052, 0.03, 0.044), seg=20, rings=12, rot=rot)
        b.sphere((x + 0.05 * s, -0.255, z + 0.026), 1.0, M["pupil"], scale=(0.022, 0.016, 0.008), seg=10, rings=6,
                 rot=face_rot(x + 0.05 * s, z + 0.026, -0.6 * s))
        b.sphere((x - 0.014 * s, -0.29, z + 0.014), 1.0, M["shine"], scale=(0.014, 0.01, 0.014), seg=10, rings=6,
                 rot=rot)
        _brow(b, M, s, 1.845)
    out.append(head_fit(b.build()))
    return out


def _hair_cap(b, M, scale=(0.316, 0.31, 0.255), center=(0, 0.06, 1.86)):
    # forma fechada: a linha do cabelo nasce da interseção com a cabeça (sem corte reto)
    b.sphere(center, 1.0, M["hair"], scale=scale, seg=26, rings=14)


def _lock(b, M, base, d, length, r1, r2=0.012, mat=None):
    """Mecha de cabelo de desenho: cone afinando com a raiz arredondada."""
    d = Vector(d).normalized()
    m = mat or M["hair"]
    b.sphere(tuple(base), r1, m, seg=12, rings=8)
    b.cone(Vector(base), d, length, r1, r2, m, seg=12)


def _band_arc(b, M, pts, r, flat=0.65):
    """Faixa (tiara/faixa de suor) feita de esferas achatadas ao longo de pontos."""
    for i in range(len(pts) - 1):
        a, c = Vector(pts[i]), Vector(pts[i + 1])
        for k in range(4):
            p = a.lerp(c, k / 4.0)
            b.sphere(tuple(p), 1.0, M["band"], scale=(r, r, r * flat), seg=10, rings=6)


def hair_variants(M):
    out = []
    # TUCA: espetado para trás, com duas mechas laterais na franja
    b = B.Builder("Hair_Spiky")
    _hair_cap(b, M)
    for d in [(0, -0.25, 1), (-0.55, 0.05, 0.85), (0.55, 0.05, 0.85), (-0.35, 0.6, 0.72), (0.35, 0.6, 0.72),
              (0, 0.85, 0.5), (-0.2, 0.25, 1), (0.2, 0.25, 1)]:
        dn = Vector(d).normalized()
        _lock(b, M, Vector((0, 0.05, 1.86)) + dn * 0.2, dn, 0.17, 0.1, 0.03)
    out.append(head_fit(b.build()))
    # BIA: franja de lado + rabo de cavalo com xuxinha
    b = B.Builder("Hair_Pony")
    _hair_cap(b, M, (0.32, 0.315, 0.262), (0, 0.06, 1.85))
    b.sphere((-0.05, -0.215, 1.975), 1.0, M["hair"], scale=(0.2, 0.075, 0.07), seg=20, rings=10,
             rot=Matrix.Rotation(-0.25, 4, "Y"))
    ctrl = [(0.31, 1.93, 0.085), (0.37, 1.84, 0.08), (0.39, 1.72, 0.072), (0.37, 1.6, 0.058)]
    for i in range(len(ctrl) - 1):
        (y0, z0, r0), (y1, z1, r1) = ctrl[i], ctrl[i + 1]
        for k in range(3):
            f = k / 3.0
            b.sphere((0, y0 + (y1 - y0) * f, z0 + (z1 - z0) * f), r0 + (r1 - r0) * f, M["hair"], seg=14, rings=10)
    _lock(b, M, (0, 0.37, 1.6), (0, -0.25, -1), 0.12, 0.055, 0.01)
    b.sphere((0, 0.3, 1.94), 1.0, M["band"], scale=(0.075, 0.05, 0.075), seg=14, rings=8)
    out.append(head_fit(b.build()))
    # ZECA: boné com botão e cabelo aparecendo nas laterais e na nuca
    b = B.Builder("Cap")
    b.sphere((0, 0.02, 1.9), 1.0, M["band"], scale=(0.33, 0.33, 0.21), seg=30, rings=16)
    b.sphere((0, -0.3, 1.895), 1.0, M["band"], scale=(0.21, 0.18, 0.026), seg=24, rings=8)
    b.sphere((0, 0.02, 2.11), 0.03, M["trim"], seg=10, rings=6)
    for sd in (-1, 1):
        b.sphere((0.27 * sd, 0.07, 1.79), 1.0, M["hair"], scale=(0.06, 0.13, 0.1), seg=14, rings=8)
    b.sphere((0, 0.21, 1.76), 1.0, M["hair"], scale=(0.25, 0.11, 0.13), seg=18, rings=10)
    out.append(head_fit(b.build()))
    # LOLA: dois coques grandes com elástico e franjinha arredondada
    b = B.Builder("Hair_Puffs")
    _hair_cap(b, M, (0.325, 0.32, 0.26))
    for sd in (-1, 1):
        b.sphere((0.22 * sd, 0.06, 2.03), 0.155, M["hair"], seg=20, rings=14)
        b.sphere((0.17 * sd, 0.05, 1.96), 1.0, M["band"], scale=(0.06, 0.06, 0.03), seg=12, rings=6,
                 rot=Matrix.Rotation(0.6 * sd, 4, "Y"))
    b.sphere((0, -0.22, 1.975), 1.0, M["hair"], scale=(0.23, 0.07, 0.06), seg=20, rings=10)
    out.append(head_fit(b.build()))
    # rabo de cavalo alto com franja reta (lisa, estilo japonês)
    b = B.Builder("Hair_PonyHigh")
    # cabelo liso: calota justa e lisa, franja reta cortada na horizontal,
    # mechas retas emoldurando o rosto e rabo de cavalo reto caindo nas costas
    _hair_cap(b, M, (0.318, 0.314, 0.262), (0, 0.055, 1.86))
    b.sphere((0, -0.215, 1.965), 1.0, M["hair"], scale=(0.24, 0.085, 0.085), seg=24, rings=10)
    for sd in (-1, 1):
        # uma mecha lisa de cada lado, do topo até a altura do queixo
        b.sphere((0.272 * sd, -0.085, 1.78), 1.0, M["hair"], scale=(0.05, 0.08, 0.19), seg=16, rings=12)
    ctrl = [(0.30, 2.02, 0.085), (0.36, 1.95, 0.08), (0.38, 1.83, 0.076), (0.385, 1.68, 0.07),
            (0.38, 1.53, 0.06), (0.37, 1.42, 0.045)]
    for i in range(len(ctrl) - 1):
        (y0, z0, r0), (y1, z1, r1) = ctrl[i], ctrl[i + 1]
        for k in range(4):
            f = k / 4.0
            b.sphere((0, y0 + (y1 - y0) * f, z0 + (z1 - z0) * f), r0 + (r1 - r0) * f, M["hair"], seg=14, rings=10)
    b.sphere((0, 0.29, 2.04), 1.0, M["band"], scale=(0.062, 0.05, 0.045), seg=12, rings=8)
    out.append(head_fit(b.build()))
    # YHAM: black power redondo, com montinhos na borda
    b = B.Builder("Hair_Afro")
    b.sphere((0, 0.12, 1.95), 1.0, M["hair"], scale=(0.43, 0.405, 0.35), seg=32, rings=18)
    for ang in range(0, 360, 30):
        a = math.radians(ang)
        x, z = math.cos(a) * 0.37, 1.95 + math.sin(a) * 0.3
        if z < 1.72:
            continue
        b.sphere((x, 0.16, z), 0.12, M["hair"], seg=12, rings=8)
    out.append(head_fit(b.build()))
    b = B.Builder("Shades")
    b.box((0, -0.282, 1.8), (0.32, 0.03, 0.07), M["shades"], smooth=True)
    b.sphere((0, 0.02, 1.9), 1.0, M["trim"], scale=(0.326, 0.326, 0.2), seg=26, rings=14)
    b.sphere((0, -0.29, 1.9), 1.0, M["trim"], scale=(0.2, 0.17, 0.026), seg=20, rings=8)
    out.append(head_fit(b.build()))
    return out


# ---------------------------------------------------------------- mãos e tênis de desenho

def mittens(M):
    """Mãos de luva-mitene (palma arredondada + polegar), presas ao osso da mão."""
    out = []
    for sd, side in ((-1, ".R"), (1, ".L")):
        b = B.Builder("Hand" + side + "Mesh")
        hx, hy, hz = PLAYER_J["hand" + side]
        # mãozinha de bonequinho: bolinha cheia + polegar rechonchudo
        b.sphere((hx, hy - 0.005, hz - 0.022), 1.0, M["skin"], scale=(0.058, 0.07, 0.078), seg=18, rings=12)
        b.sphere((hx - 0.014 * sd, hy - 0.062, hz + 0.006), 1.0, M["skin"], scale=(0.03, 0.032, 0.04), seg=12, rings=8,
                 rot=Matrix.Rotation(0.5, 4, "X"))
        ob = b.build()
        ob.name = "Mitten" + side
        out.append((ob, "Hand" + side))
    return out


def bare_feet(M):
    """Pés descalços (na areia ninguém joga de tênis): sola de feijão, calcanhar
    redondo, cinco dedinhos e uma tornozeleira de miçangas na cor do personagem."""
    out = []
    for sd, side in ((-1, ".R"), (1, ".L")):
        b = B.Builder("Foot" + side + "Mesh")
        ax, ay, az = PLAYER_J["ankle" + side]
        x = ax
        inner = -sd    # o dedão fica do lado de dentro
        # peito do pé e sola (achatados embaixo, apoiados no chão)
        b.sphere((x, -0.06, 0.042), 1.0, M["skin"], scale=(0.07, 0.128, 0.046), seg=22, rings=12, cut_below=0.0)
        b.sphere((x, -0.058, 0.004), 1.0, M["skin"], scale=(0.068, 0.124, 0.008), seg=22, rings=6)
        # calcanhar e tornozelo
        b.sphere((x, 0.018, 0.06), 1.0, M["skin"], scale=(0.06, 0.058, 0.062), seg=16, rings=10, cut_below=0.0)
        b.sphere((x, 0.0, 0.1), 0.064, M["skin"], seg=16, rings=10)
        # dedinhos em arco (dedão maior, do lado de dentro)
        toes = [(0.042, -0.176, 0.025, 0.024), (0.012, -0.186, 0.02, 0.018), (-0.014, -0.181, 0.018, 0.016),
                (-0.036, -0.17, 0.016, 0.014), (-0.054, -0.152, 0.014, 0.012)]
        for ox, oy, oz, r in toes:
            b.sphere((x + ox * inner, oy, oz), 1.0, M["skin"], scale=(r, r * 1.15, r * 0.9), seg=10, rings=6)
        # tornozeleira de miçangas
        for i in range(14):
            a = i / 14.0 * math.tau
            b.sphere((x + math.cos(a) * 0.068, math.sin(a) * 0.068, 0.142 + 0.008 * math.sin(a * 2.0)), 0.014,
                     M["band"] if i % 2 == 0 else M["trim"], seg=8, rings=5)
        ob = b.build()
        ob.name = "BareFoot" + side
        out.append((ob, "Foot" + side))
    return out


def build_player():
    B.reset_scene()
    M = player_materials()
    arm = make_armature("Rig", PLAYER_J, PLAYER_BONES)
    body, w = player_body(M)
    bind(body, arm, w)
    for ob, cw in player_clothes(M, body.data, w):
        bind(ob, arm, cw)
    head = player_head(M)
    bind(head, arm, rigid_weights(head.data, "Head"))
    for e in eye_variants(M):
        bind(e, arm, rigid_weights(e.data, "Head"))
    for h in hair_variants(M):
        bind(h, arm, rigid_weights(h.data, "Head"))
    for ob, bone in mittens(M) + bare_feet(M):
        bind(ob, arm, rigid_weights(ob.data, bone))
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

# Torcedores chibi: corpo de pera, cabeção, mãozinhas e olhinhos. Seis tipos
# (sentado batendo palma, sentado torcendo, sentado inclinado, em pé, em pé com
# placa e criança), cada um com um cabelo/chapéu. As cores saem do shader da
# torcida por instância (UV.x = região) e UV.y marca o "braço" para animar.
REGION_UV = {"Eye": 0.02, "Shirt": 0.1, "Skin": 0.3, "Hair": 0.5, "Prop": 0.7, "Pants": 0.9}

FAN_R = sym({
    "pelvis": (0.17, 0.13), "chest": (0.2, 0.15), "neck": (0.06, 0.06),
    "shoulder.R": (0.065, 0.065), "elbow.R": (0.052, 0.052), "hand.R": (0.06, 0.06),
    "hip.R": (0.08, 0.08), "knee.R": (0.065, 0.065), "foot.R": (0.06, 0.065),
})
FAN_EDGES = [("pelvis", "chest"), ("chest", "neck")]
for _s in (".R", ".L"):
    FAN_EDGES += [("chest", "shoulder" + _s), ("shoulder" + _s, "elbow" + _s), ("elbow" + _s, "hand" + _s),
                  ("pelvis", "hip" + _s), ("hip" + _s, "knee" + _s), ("knee" + _s, "foot" + _s)]

FAN_VARIANTS = ("sit_clap", "sit_cheer", "sit_lean", "stand_up", "stand_sign", "kid")
FAN_HAIR = {"sit_clap": "bob", "sit_cheer": "cap", "sit_lean": "afro", "stand_up": "spikes", "stand_sign": "bun",
            "kid": "pony"}


def fan_pose(variant):
    """Juntas no espaço do torcedor (pés na origem, olhando para -Y)."""
    seated = variant.startswith("sit")
    if seated:
        # sentado: quadril 0,47 acima do piso do degrau e 0,27 para trás (em cima do assento)
        j = sym({
            "pelvis": (0, 0.27, 0.5), "chest": (0, 0.27 - (0.08 if variant == "sit_lean" else 0.0), 0.84),
            "neck": (0, 0.27 - (0.12 if variant == "sit_lean" else 0.0), 0.96),
            "shoulder.R": (-0.16, 0.27, 0.9), "elbow.R": (-0.21, 0.12, 0.72), "hand.R": (-0.12, -0.02, 0.76),
            "hip.R": (-0.09, 0.27, 0.48), "knee.R": (-0.1, -0.06, 0.5), "foot.R": (-0.1, -0.1, 0.06),
        })
    else:
        j = sym({
            "pelvis": (0, 0, 0.8), "chest": (0, 0, 1.14), "neck": (0, 0, 1.26),
            "shoulder.R": (-0.16, 0, 1.2), "elbow.R": (-0.22, -0.04, 0.98), "hand.R": (-0.2, -0.1, 0.8),
            "hip.R": (-0.09, 0, 0.78), "knee.R": (-0.095, -0.02, 0.43), "foot.R": (-0.095, -0.06, 0.05),
        })
    sh = j["shoulder.R"][2]
    if variant == "sit_clap":
        for s, sx in ((".R", -1), (".L", 1)):
            j["elbow" + s] = (0.2 * sx, 0.05, sh - 0.16)
            j["hand" + s] = (0.04 * sx, -0.12, sh - 0.02)
    elif variant == "sit_cheer":
        j["elbow.R"] = (-0.24, 0.24, sh + 0.24)
        j["hand.R"] = (-0.2, 0.2, sh + 0.48)
    elif variant == "stand_up":
        for s, sx in ((".R", -1), (".L", 1)):
            j["elbow" + s] = (0.25 * sx, -0.02, sh + 0.24)
            j["hand" + s] = (0.22 * sx, -0.04, sh + 0.5)
    elif variant == "stand_sign":
        for s, sx in ((".R", -1), (".L", 1)):
            j["elbow" + s] = (0.24 * sx, -0.04, sh + 0.32)
            j["hand" + s] = (0.16 * sx, -0.06, sh + 0.64)
    elif variant == "kid":
        for s, sx in ((".R", -1), (".L", 1)):
            j["elbow" + s] = (0.24 * sx, -0.02, sh + 0.2)
            j["hand" + s] = (0.26 * sx, -0.04, sh + 0.44)
    return j


def _fan_hair(b, mats, kind, hc, R):
    H, P = mats["Hair"], mats["Prop"]
    x, y, z = hc
    if kind == "bob":
        b.sphere((x, y + 0.22 * R, z + 0.12 * R), 1.0, H, scale=(1.1 * R, 1.02 * R, 0.98 * R), seg=16, rings=10,
                 cut_below=z - 0.45 * R)
        b.sphere((x, y - 0.66 * R, z + 0.55 * R), 1.0, H, scale=(0.8 * R, 0.3 * R, 0.3 * R), seg=14, rings=8)
    elif kind == "bun":
        b.sphere((x, y + 0.2 * R, z + 0.18 * R), 1.0, H, scale=(1.05 * R, 1.0 * R, 0.92 * R), seg=16, rings=10,
                 cut_below=z)
        b.sphere((x, y + 0.35 * R, z + 1.0 * R), 0.45 * R, H, seg=12, rings=8)
    elif kind == "afro":
        b.sphere((x, y + 0.42 * R, z + 0.3 * R), 1.0, H, scale=(1.4 * R, 1.25 * R, 1.2 * R), seg=16, rings=10,
                 cut_below=z - 0.3 * R)
    elif kind == "cap":
        b.sphere((x, y + 0.05 * R, z + 0.2 * R), 1.0, P, scale=(1.06 * R, 1.06 * R, 0.86 * R), seg=16, rings=10,
                 cut_below=z + 0.1 * R)
        rbox_simple(b, (x, y - 0.95 * R, z + 0.2 * R), (1.1 * R, 0.7 * R, 0.08 * R), P)
    elif kind == "spikes":
        b.sphere((x, y + 0.2 * R, z + 0.2 * R), 1.0, H, scale=(1.05 * R, 1.0 * R, 0.86 * R), seg=16, rings=10,
                 cut_below=z)
        for dx, dy in ((-0.4, 0.1), (0.0, -0.15), (0.4, 0.1)):
            b.cone((x + dx * R, y + dy * R, z + 0.7 * R), (dx * 0.6, dy, 1), 0.55 * R, 0.28 * R, 0.04 * R, H, seg=8)
    elif kind == "pony":
        b.sphere((x, y + 0.2 * R, z + 0.15 * R), 1.0, H, scale=(1.05 * R, 1.0 * R, 0.9 * R), seg=16, rings=10,
                 cut_below=z - 0.1 * R)
        for k in range(3):
            b.sphere((x, y + (1.0 + 0.15 * k) * R, z + (0.3 - 0.4 * k) * R), (0.4 - 0.06 * k) * R, H, seg=10, rings=8)


def rbox_simple(b, center, size, mat):
    b.box(center, size, mat, smooth=False)


def build_fan(variant):
    B.reset_scene()
    mats = {k: B.material("Fan" + k, "#ffffff") for k in REGION_UV}
    j = fan_pose(variant)
    me = skin_mesh("Fan", j, FAN_R, FAN_EDGES, "pelvis", subsurf=1)
    b = B.Builder("Fan_" + variant)
    b.bm.from_mesh(me)
    for k in REGION_UV:
        b._mi(mats[k])
    segs = {}
    for s in (".R", ".L"):
        segs["upper" + s] = (Vector(j["shoulder" + s]), Vector(j["elbow" + s]))
        segs["lower" + s] = (Vector(j["elbow" + s]), Vector(j["hand" + s]))
        segs["thigh" + s] = (Vector(j["hip" + s]), Vector(j["knee" + s]))
        segs["shin" + s] = (Vector(j["knee" + s]), Vector(j["foot" + s]))
    segs["torso"] = (Vector(j["pelvis"]), Vector(j["chest"]))
    segs["neck"] = (Vector(j["chest"]), Vector(j["neck"]))
    for f in b.bm.faces:
        c = f.calc_center_median()
        best, bd = "torso", 1e9
        for n, (a, e) in segs.items():
            d = seg_dist(c, a, e) / (0.2 if n == "torso" else 0.08)
            if d < bd:
                best, bd = n, d
        reg = "Shirt"
        if best.startswith("lower") or best.startswith("shin") or best == "neck":
            reg = "Skin"
        elif best.startswith("thigh"):
            reg = "Pants"
        elif best.startswith("upper"):
            a, e = segs[best]
            reg = "Shirt" if (c - a).length < 0.07 else "Skin"
        elif best == "torso" and c.z < Vector(j["pelvis"]).z + 0.04:
            reg = "Pants"
        f.material_index = b._mi(mats[reg])
        f.smooth = True
    # mãozinhas e cabeção
    for s in (".R", ".L"):
        b.sphere(j["hand" + s], 0.062, mats["Skin"], seg=10, rings=6)
    R = 0.27
    nk = Vector(j["neck"])
    hc = (nk.x, nk.y, nk.z + R * 0.82)
    b.sphere(hc, R, mats["Skin"], seg=16, rings=10)
    for sd in (-1, 1):
        b.sphere((hc[0] + 0.32 * R * sd, hc[1] - 0.9 * R, hc[2] - 0.05 * R), 1.0, mats["Eye"],
                 scale=(0.09 * R, 0.08 * R, 0.13 * R), seg=8, rings=6)
    _fan_hair(b, mats, FAN_HAIR[variant], hc, R)
    if variant == "stand_sign":
        hz = j["hand.R"][2]
        b.box((0, -0.08, hz + 0.18), (0.72, 0.04, 0.4), mats["Prop"], smooth=False)
    if variant == "sit_cheer":
        hx, hy, hz = j["hand.R"]
        b.sphere((hx, hy - 0.02, hz + 0.1), 1.0, mats["Prop"], scale=(0.09, 0.05, 0.14), seg=10, rings=8)
        b.sphere((hx, hy - 0.03, hz + 0.27), 1.0, mats["Prop"], scale=(0.035, 0.035, 0.09), seg=8, rings=6)
    ob = b.build()
    me2 = ob.data
    if variant == "kid":
        # criança: corpo 0,75, cabeça proporcionalmente 1,2x maior (em volta do pescoço)
        k_body = 0.75
        for v in me2.vertices:
            p = v.co.copy()
            if p.z > nk.z:
                p = nk + (p - nk) * 1.2
            v.co = p * k_body
    # UV: x = região (cor escolhida no shader), y = quanto o vértice é "mão/antebraço" (para animar)
    uv = me2.uv_layers.new(name="UVMap")
    names = [m.name for m in me2.materials]
    hands = [Vector(j["hand.R"]), Vector(j["hand.L"])]
    els = [Vector(j["elbow.R"]), Vector(j["elbow.L"])]
    ks = 0.75 if variant == "kid" else 1.0
    for poly in me2.polygons:
        code = REGION_UV[names[poly.material_index][3:]]
        for li in poly.loop_indices:
            co = me2.vertices[me2.loops[li].vertex_index].co / ks
            arm = 0.0
            for hnd, el in zip(hands, els):
                d = seg_dist(co, el, hnd)
                if d < 0.11 and names[poly.material_index][3:] in ("Skin", "Prop", "Shirt"):
                    t = (co - el).length / max((hnd - el).length, 1e-4)
                    arm = max(arm, min(1.0, 0.35 + 0.65 * t))
            if names[poly.material_index][3:] == "Prop" and variant in ("stand_sign", "sit_cheer"):
                arm = max(arm, 1.0)
            uv.data[li].uv = (code, arm)
    B.export("fan_" + variant)


def build_all():
    build_player()
    build_racket()
    for v in FAN_VARIANTS:
        build_fan(v)

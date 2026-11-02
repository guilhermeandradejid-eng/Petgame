"""
Smash na Areia - gera todos os modelos 3D do jogo com o Blender (bpy).

Uso:
    blender -b -P blender/build_assets.py            # com o Blender instalado
    python blender/build_assets.py                    # com o modulo `bpy` (pip install bpy)

Os .glb sao gravados em godot/assets/models/. Tudo e modelado por codigo
(esferas achatadas, cones e caixas) para dar o visual "boneco de borracha"
de desenho animado: cabecas grandes, narizes redondos, olhos de botao.

Convencoes:
  * Blender e Z-up e o personagem olha para -Y. O exportador glTF converte
    para Y-up, entao no Godot o personagem olha para +Z (MODEL_FRONT).
  * Cada parte do corpo e um objeto separado com a origem no "joelho/ombro"
    (pivo da articulacao). O Godot monta a hierarquia e anima por codigo.
  * Os nomes dos materiais (Skin, Shirt, Shorts, Hair, ...) sao usados pelo
    Godot para trocar as cores de cada personagem e time.
"""

import math
import os
import sys

import bpy  # precisa vir antes do bmesh quando usado como modulo
import bmesh
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "godot", "assets", "models"))


# ---------------------------------------------------------------- utilidades

def srgb(hex_color):
    """Converte '#rrggbb' (sRGB) para o RGB linear usado pelo Blender."""
    h = hex_color.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, hex_color, rough=0.85):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    col = (*srgb(hex_color), 1.0)
    m.diffuse_color = col
    if m.node_tree is None:
        try:
            m.use_nodes = True
        except Exception:
            pass
    if m.node_tree:
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            for n in m.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED":
                    bsdf = n
        if bsdf:
            bsdf.inputs["Base Color"].default_value = col
            bsdf.inputs["Roughness"].default_value = rough
            if "Metallic" in bsdf.inputs:
                bsdf.inputs["Metallic"].default_value = 0.0
    return m


class Builder:
    """Acumula primitivas num bmesh, cada uma com um indice de material."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def _mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _tag(self, verts, mat, smooth=True):
        mi = self._mi(mat)
        faces = set()
        for v in verts:
            faces.update(v.link_faces)
        for f in faces:
            f.material_index = mi
            f.smooth = smooth
        return verts

    def sphere(self, center, radius, mat, scale=(1, 1, 1), seg=18, rings=12, rot=None, cut_below=None,
               cut_above=None):
        m = Matrix.Translation(Vector(center))
        if rot:
            m = m @ rot
        m = m @ Matrix.Diagonal((*scale, 1.0))
        ret = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=radius, matrix=m)
        verts = ret["verts"]
        self._tag(verts, mat)
        if cut_below is not None:
            kill = [v for v in verts if v.co.z < cut_below]
            bmesh.ops.delete(self.bm, geom=kill, context="VERTS")
            verts = [v for v in verts if v.is_valid]
        if cut_above is not None:
            kill = [v for v in verts if v.co.z > cut_above]
            bmesh.ops.delete(self.bm, geom=kill, context="VERTS")
            verts = [v for v in verts if v.is_valid]
        return verts

    def cone(self, base, tip_dir, length, r1, r2, mat, seg=10, smooth=True):
        """Cone/cilindro que sai de `base` na direcao `tip_dir`."""
        d = Vector(tip_dir).normalized()
        rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        center = Vector(base) + d * (length * 0.5)
        m = Matrix.Translation(center) @ rot
        ret = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                    radius1=r1, radius2=r2, depth=length, matrix=m)
        return self._tag(ret["verts"], mat, smooth)

    def box(self, center, size, mat, rot=None, smooth=False):
        m = Matrix.Translation(Vector(center))
        if rot:
            m = m @ rot
        m = m @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
        ret = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        return self._tag(ret["verts"], mat, smooth)

    def build(self, pivot=(0, 0, 0)):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0001)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        p = Vector(pivot)
        me.transform(Matrix.Translation(-p))
        ob.location = p
        return ob


def rot_x(deg):
    return Matrix.Rotation(math.radians(deg), 4, "X")


def rot_y(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Y")


def rot_z(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


def export(name):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False,
                              export_apply=True, export_yup=True)
    print("  ->", path)


# ---------------------------------------------------------------- cenario

def build_palm():
    reset_scene()
    trunk = material("Trunk", "#a8743f")
    leaf = material("Leaf", "#3fbf4f")
    leaf_dark = material("LeafDark", "#2fa043")
    coco = material("Coconut", "#6b4a2b")
    b = Builder("Palm")
    # tronco liso e curvado (cones encadeados sem degraus)
    pts = []
    for i in range(11):
        t = i / 10.0
        pts.append(Vector((0.9 * t * t * 1.6, 0.0, 5.6 * t)))
    for i in range(10):
        r1 = 0.3 - i * 0.012
        d = pts[i + 1] - pts[i]
        b.cone(pts[i] - d.normalized() * 0.04, d, d.length + 0.08, r1, r1 - 0.012, trunk, seg=12)
    top = pts[-1]
    for k in range(3):
        a = k * 2.1
        b.sphere(top + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, -0.22)), 0.16, coco, seg=12, rings=8)
    # folhas: elipsoides achatados e curvados para baixo (formas fechadas)
    for k in range(7):
        ang = k * math.tau / 7 + 0.3
        length = 2.4
        verts = b.sphere((0, 0, 0), 1.0, leaf if k % 2 == 0 else leaf_dark,
                         scale=(length * 0.5, 0.36, 0.06), seg=16, rings=8)
        ca, sa = math.cos(ang), math.sin(ang)
        for v in verts:
            x = v.co.x + length * 0.5          # 0..length ao longo da folha
            t = x / length
            z = v.co.z + 0.45 * math.sin(t * math.pi * 0.7) - 1.25 * t * t
            y = v.co.y * (1.0 - 0.75 * t * t)  # afina na ponta
            v.co = top + Vector((x * ca - y * sa, x * sa + y * ca, z + 0.05))
    b.sphere(top + Vector((0, 0, 0.05)), 0.26, leaf_dark, seg=12, rings=8)
    b.build()
    export("palm")


def build_umbrella():
    reset_scene()
    red = material("UmbrellaA", "#ff4b3e")
    white = material("UmbrellaB", "#fff4e0")
    pole = material("Pole", "#ffffff")
    b = Builder("Umbrella")
    b.cone((0, 0, -0.3), (0, 0, 1), 2.75, 0.035, 0.035, pole, seg=8)
    bm = b.bm
    segs = 12
    apex = bm.verts.new((0, 0, 2.6))
    ring = []
    for i in range(segs):
        a = i * math.tau / segs
        ring.append(bm.verts.new((math.cos(a) * 1.55, math.sin(a) * 1.55, 1.98)))
    center_low = bm.verts.new((0, 0, 2.2))
    for i in range(segs):
        f = bm.faces.new((apex, ring[i], ring[(i + 1) % segs]))
        f.material_index = b._mi(red if i % 2 == 0 else white)
        f.smooth = False
        f2 = bm.faces.new((center_low, ring[(i + 1) % segs], ring[i]))
        f2.material_index = b._mi(white)
    b.sphere((0, 0, 2.63), 0.07, pole, seg=10, rings=6)
    b.build()
    export("umbrella")


def build_chair():
    reset_scene()
    frame = material("ChairFrame", "#ffffff")
    cloth_a = material("ChairA", "#2fb5ff")
    cloth_b = material("ChairB", "#ffe14d")
    b = Builder("Chair")
    for sx in (-0.3, 0.3):
        b.box((sx, 0.0, 0.25), (0.04, 0.9, 0.04), frame, rot=rot_x(20))
        b.box((sx, 0.35, 0.55), (0.04, 0.04, 0.9), frame, rot=rot_x(-30))
    for i in range(5):
        mat = cloth_a if i % 2 == 0 else cloth_b
        b.box((-0.24 + i * 0.12, 0.05, 0.3), (0.12, 0.8, 0.02), mat, rot=rot_x(20))
        b.box((-0.24 + i * 0.12, 0.38, 0.62), (0.12, 0.02, 0.7), mat, rot=rot_x(-30))
    b.build()
    export("chair")


def build_tower():
    reset_scene()
    wood = material("TowerWood", "#ffffff")
    red = material("TowerRed", "#ff4b3e")
    roof = material("TowerRoof", "#ffd23f")
    b = Builder("Tower")
    for sx in (-0.8, 0.8):
        for sy in (-0.8, 0.8):
            b.box((sx, sy, 1.2), (0.14, 0.14, 2.4), wood)
    b.box((0, 0, 2.45), (2.0, 2.0, 0.15), red)
    b.box((0, 0.2, 3.1), (1.6, 1.2, 1.2), wood)
    b.box((0, -0.42, 3.15), (1.0, 0.04, 0.6), red)
    b.cone((0, 0.2, 3.7), (0, 0, 1), 0.7, 1.3, 0.05, roof, seg=4, smooth=False)
    for i in range(6):
        b.box((0, -1.25 - i * 0.18, 0.2 + i * 0.4), (0.9, 0.25, 0.06), wood)
    b.box((0, -0.9, 1.2), (0.06, 0.6, 2.4), wood, rot=rot_x(-25))
    b.build()
    export("tower")


def build_cloud():
    reset_scene()
    w = material("Cloud", "#ffffff")
    s = material("CloudShade", "#dfe9ff")
    b = Builder("Cloud")
    blobs = [((0, 0, 0), 1.2), ((1.3, 0.1, -0.2), 0.95), ((-1.3, 0, -0.25), 0.9),
             ((0.6, 0.2, 0.6), 0.85), ((-0.5, -0.1, 0.5), 0.8), ((2.3, 0, -0.45), 0.6), ((-2.2, 0.1, -0.45), 0.55)]
    for i, (c, r) in enumerate(blobs):
        b.sphere(c, r, w if i % 3 else s, scale=(1, 0.8, 0.85), seg=14, rings=10)
    b.build()
    export("cloud")


def build_post():
    reset_scene()
    metal = material("PostMetal", "#ffffff")
    stripe = material("PostStripe", "#2f8cff")
    b = Builder("Post")
    b.cone((0, 0, -0.2), (0, 0, 1), 2.05, 0.06, 0.06, metal, seg=10)
    for i in range(4):
        b.cone((0, 0, 0.25 + i * 0.4), (0, 0, 1), 0.16, 0.065, 0.065, stripe, seg=10)
    b.sphere((0, 0, 1.88), 0.1, stripe, seg=10, rings=8)
    b.build()
    export("post")


def build_stands():
    reset_scene()
    a = material("StandA", "#ffffff")
    c = material("StandB", "#2fb5ff")
    b = Builder("Stands")
    for i in range(4):
        b.box((0, i * 0.8, 0.25 + i * 0.5), (14.0, 0.8, 0.5 + i * 1.0), a if i % 2 == 0 else c)
    b.build()
    export("stands")


def build_surfboard():
    reset_scene()
    base = material("BoardBase", "#ffe14d")
    stripe = material("BoardStripe", "#ff4b3e")
    b = Builder("Surfboard")
    b.sphere((0, 0, 1.05), 1.0, base, scale=(0.32, 0.06, 1.1), seg=18, rings=12)
    b.sphere((0, -0.012, 1.05), 1.0, stripe, scale=(0.08, 0.055, 1.08), seg=10, rings=12)
    b.build()
    export("surfboard")


def build_island():
    reset_scene()
    rock = material("IslandRock", "#9c8ab8")
    grass = material("IslandGreen", "#4fcf6b")
    sand = material("IslandSand", "#ffe2a8")
    b = Builder("Island")
    b.sphere((0, 0, 0), 1.0, sand, scale=(9, 5, 1.2), seg=16, rings=8)
    b.sphere((0, 0, 1.5), 1.0, rock, scale=(5, 3.5, 4), seg=12, rings=8)
    b.sphere((-1, 0.5, 4.8), 1.0, grass, scale=(3.8, 2.8, 1.8), seg=12, rings=8)
    b.sphere((3.5, -0.5, 1.2), 1.0, grass, scale=(2.2, 1.8, 1.4), seg=10, rings=6)
    b.build()
    export("island")


def build_crab():
    reset_scene()
    red = material("CrabRed", "#ff5a36")
    eye = material("CrabEye", "#ffffff")
    pup = material("CrabPupil", "#151020")
    b = Builder("Crab")
    b.sphere((0, 0, 0.12), 1.0, red, scale=(0.22, 0.16, 0.1), seg=14, rings=8)
    for s in (-1, 1):
        b.cone((0.06 * s, -0.08, 0.18), (0.1 * s, -0.3, 1), 0.14, 0.015, 0.015, red, seg=6)
        b.sphere((0.08 * s, -0.12, 0.32), 0.04, eye, seg=8, rings=6)
        b.sphere((0.08 * s, -0.155, 0.325), 0.02, pup, seg=6, rings=4)
        b.sphere((0.27 * s, -0.12, 0.13), 1.0, red, scale=(0.08, 0.06, 0.05), seg=10, rings=6)
        for k in range(3):
            b.cone((0.15 * s, 0.05 - k * 0.07, 0.1), (s, 0, -0.6), 0.16, 0.015, 0.008, red, seg=5)
    b.build()
    export("crab")


def main():
    print("Gerando modelos em", OUT_DIR)
    sys.path.insert(0, HERE)
    import characters
    import props
    characters.build_all()
    props.build_all()
    build_palm()
    build_umbrella()
    build_chair()
    build_tower()
    build_cloud()
    build_post()
    build_surfboard()
    build_island()
    build_crab()
    print("Pronto!")


if __name__ == "__main__":
    main()

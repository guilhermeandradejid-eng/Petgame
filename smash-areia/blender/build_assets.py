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
# (palmeiras, guarda-sóis, quiosque, arquibancada etc. ficam em scenery.py)

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
    import scenery
    characters.build_all()
    props.build_sailboat()
    scenery.build_all()
    build_crab()
    print("Pronto!")


if __name__ == "__main__":
    main()

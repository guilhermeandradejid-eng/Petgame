"""Palette, Blender materials (PBR for glTF export, toon for EEVEE), outline, lights, camera, rendering."""
import bpy, os
from math import radians
from mathutils import Vector, Euler


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# name -> base colour, shadow colour (hue-shifted, not just darker), kind, outline colour
PALETTE = {
    "skin":    dict(base=(1.0, 0.895, 0.815), shade=hexc("#eeb3a4"), kind="toon", line=hexc("#7a3b3a")),
    "face":    dict(base=(1.0, 0.895, 0.815), shade=hexc("#f2bfb0"), kind="face", line=hexc("#7a3b3a")),
    "hair":    dict(base=hexc("#eceef6"), shade=hexc("#a3a9d2"), kind="hair", line=hexc("#3b3f66")),
    "coat":    dict(base=hexc("#31429a"), shade=hexc("#1c2160"), kind="toon", line=hexc("#0d0f2e")),
    "pants":   dict(base=hexc("#262a45"), shade=hexc("#15162b"), kind="toon", line=hexc("#07070f")),
    "cream":   dict(base=hexc("#f7f0df"), shade=hexc("#c9b9c4"), kind="toon", line=hexc("#5a4a5c")),
    "crimson": dict(base=hexc("#dc2f3c"), shade=hexc("#8f1438"), kind="toon", line=hexc("#3d0718")),
    "leather": dict(base=hexc("#7a4a2e"), shade=hexc("#472522"), kind="toon", line=hexc("#1f0f10")),
    "gold":    dict(base=hexc("#ffc94d"), shade=hexc("#c9782a"), kind="metal", line=hexc("#5a2e0a")),
    "steel":   dict(base=hexc("#e4eefc"), shade=hexc("#8fa3d6"), kind="metal", line=hexc("#2a3157")),
    "dark":    dict(base=hexc("#1d1a2b"), shade=hexc("#0e0c18"), kind="toon", line=hexc("#050409")),
    "glow":    dict(base=hexc("#58f2e2"), shade=hexc("#58f2e2"), kind="glow", line=hexc("#0b5a66")),
}
MAT_NAMES = list(PALETTE.keys())
SUN_ROT = (radians(52), radians(-4), radians(32))
LIGHT_DIR = tuple(Euler(SUN_ROT).to_matrix() @ Vector((0, 0, 1)))
BG = hexc("#cfd6ee")


def lin(c):
    return tuple(((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in c)


def _reset(mat):
    try:
        mat.use_nodes = True
    except Exception:
        pass
    mat.node_tree.nodes.clear()
    return mat.node_tree


def make_image(name, arr, path=None):
    """numpy RGBA (row 0 = top) -> packed Blender image."""
    h, w = arr.shape[:2]
    img = bpy.data.images.get(name) or bpy.data.images.new(name, w, h, alpha=False)
    img.pixels.foreach_set(arr[::-1].ravel())
    if path:
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
    img.pack()
    return img


def shade_tint(name):
    """Shadow colour as a multiplier of the painted base colour (keeps the hue shift of the palette)."""
    spec = PALETTE[name]
    return tuple(min(1.15, s / max(b, 0.06)) for s, b in zip(spec["shade"], spec["base"]))


def make_pbr(name, face_img, atlas_img):
    """Plain Principled material with the painted atlas as base colour: this is what the glTF exporter reads."""
    spec = PALETTE[name]
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    nt = _reset(mat)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    metal = spec["kind"] == "metal"
    b.inputs["Roughness"].default_value = 0.35 if metal else 0.9
    b.inputs["Metallic"].default_value = 0.7 if metal else 0.0
    if spec["kind"] == "glow":
        b.inputs["Emission Color"].default_value = lin(spec["base"]) + (1.0,)
        b.inputs["Emission Strength"].default_value = 2.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = face_img if name == "face" else atlas_img
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(b.outputs[0], out.inputs[0])
    mat.diffuse_color = lin(spec["base"]) + (1.0,)
    return mat


class G:
    """Tiny node-graph helper."""

    def __init__(self, nt):
        self.nt = nt

    def _in(self, sock, v):
        if hasattr(v, "is_output") or hasattr(v, "links"):
            self.nt.links.new(v, sock)
        else:
            sock.default_value = v

    def math(self, op, a, b=0.0, clamp=False):
        n = self.nt.nodes.new("ShaderNodeMath")
        n.operation, n.use_clamp = op, clamp
        self._in(n.inputs[0], a)
        self._in(n.inputs[1], b)
        return n.outputs[0]

    def dot(self, a, b):
        n = self.nt.nodes.new("ShaderNodeVectorMath")
        n.operation = "DOT_PRODUCT"
        self._in(n.inputs[0], a)
        self._in(n.inputs[1], b)
        return n.outputs["Value"]

    def vadd(self, a, b, normalize=False):
        n = self.nt.nodes.new("ShaderNodeVectorMath")
        n.operation = "ADD"
        self._in(n.inputs[0], a)
        self._in(n.inputs[1], b)
        if not normalize:
            return n.outputs[0]
        m = self.nt.nodes.new("ShaderNodeVectorMath")
        m.operation = "NORMALIZE"
        self.nt.links.new(n.outputs[0], m.inputs[0])
        return m.outputs[0]

    def step(self, v, lo, hi):
        n = self.nt.nodes.new("ShaderNodeMapRange")
        n.clamp = True
        self._in(n.inputs["Value"], v)
        n.inputs["From Min"].default_value = lo
        n.inputs["From Max"].default_value = hi
        return n.outputs[0]

    def mix(self, fac, a, b, blend="MIX"):
        n = self.nt.nodes.new("ShaderNodeMix")
        n.data_type, n.blend_type = "RGBA", blend
        self._in(n.inputs[0], fac)
        self._in(n.inputs[6], a)
        self._in(n.inputs[7], b)
        return n.outputs[2]

    def rgb(self, c):
        return lin(c) + (1.0,)


def make_toon(name, face_img, atlas_img):
    """Cel shading as an emission graph: painted base colour, N.L step into a hue-shifted shadow,
    rim light, stepped speculars."""
    spec = PALETTE[name]
    mat = bpy.data.materials[name]
    nt = _reset(mat)
    g = G(nt)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emi = nt.nodes.new("ShaderNodeEmission")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    N, I = geo.outputs["Normal"], geo.outputs["Incoming"]
    kind = spec["kind"]
    if kind == "glow":
        emi.inputs[0].default_value = g.rgb(spec["base"])
        emi.inputs[1].default_value = 1.6
        nt.links.new(emi.outputs[0], out.inputs[0])
        return mat
    ndl = g.dot(N, LIGHT_DIR)
    ndv = g.dot(N, I)
    tex = nt.nodes.new("ShaderNodeTexImage")
    uv = nt.nodes.new("ShaderNodeUVMap")
    if kind == "face":
        tex.image = face_img
        tex.name = "FaceTex"
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.name = "FaceUV"
        nt.links.new(uv.outputs[0], mp.inputs[0])
        nt.links.new(mp.outputs[0], tex.inputs[0])
        lit = g.step(ndl, -0.32, -0.26)
    else:
        tex.image = atlas_img
        nt.links.new(uv.outputs[0], tex.inputs[0])
        if kind == "metal":
            lit = g.step(g.math("ADD", g.math("MULTIPLY", ndl, 0.6), g.math("MULTIPLY", ndv, 0.4)), 0.20, 0.24)
        else:
            lit = g.step(ndl, 0.02, 0.06)
    base = tex.outputs["Color"]
    shade = g.mix(1.0, base, shade_tint(name) + (1.0,), "MULTIPLY")
    col = g.mix(lit, shade, base)
    if kind == "metal":
        h = g.vadd(I, LIGHT_DIR, normalize=True)
        sp = g.step(g.dot(N, h), 0.93, 0.95)
        col = g.mix(g.math("MULTIPLY", sp, 0.85), col, (1, 1, 1, 1))
    if kind in ("toon", "hair", "metal"):
        rim = g.math("MULTIPLY", g.step(g.math("SUBTRACT", 1.0, ndv), 0.66, 0.72), g.step(ndl, 0.0, 0.35))
        col = g.mix(g.math("MULTIPLY", rim, 0.45), col, (1, 1, 1, 1), "SCREEN")
    nt.links.new(col, emi.inputs[0])
    nt.links.new(emi.outputs[0], out.inputs[0])
    return mat


def outline_material():
    ol = bpy.data.materials.get("outline") or bpy.data.materials.new("outline")
    nt = _reset(ol)
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value = lin(hexc("#1c1630")) + (1,)
    nt.links.new(e.outputs[0], o.inputs[0])
    ol.use_backface_culling = True
    return ol


def add_outline(obj, thickness=0.0042, group="outline"):
    me = obj.data
    if "outline" not in [m.name for m in me.materials if m]:
        me.materials.append(outline_material())
    sol = obj.modifiers.new("Outline", "SOLIDIFY")
    sol.thickness = thickness
    sol.offset = 1.0
    sol.use_flip_normals = True
    sol.use_rim = False
    sol.material_offset = len(me.materials)
    if group in obj.vertex_groups:
        sol.vertex_group = group
        sol.thickness_vertex_group = 0.0
    return sol


def setup_scene(scene, ground=True):
    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    try:
        world.use_nodes = True
    except Exception:
        pass
    nt = world.node_tree
    bg = nt.nodes.get("Background") or nt.nodes.new("ShaderNodeBackground")
    bg.inputs[0].default_value = lin(BG) + (1,)
    wo = nt.nodes.get("World Output") or nt.nodes.new("ShaderNodeOutputWorld")
    if not bg.outputs[0].links:
        nt.links.new(bg.outputs[0], wo.inputs[0])
    scene.world = world

    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = SUN_ROT
    scene.collection.objects.link(sun)

    if ground:
        gm = bpy.data.meshes.new("Ground")
        gm.from_pydata([(-30, -30, 0), (30, -30, 0), (30, 30, 0), (-30, 30, 0)], [], [(0, 1, 2, 3)])
        gobj = bpy.data.objects.new("Ground", gm)
        scene.collection.objects.link(gobj)
        gmat = bpy.data.materials.new("ground")
        nt = _reset(gmat)
        o = nt.nodes.new("ShaderNodeOutputMaterial")
        e = nt.nodes.new("ShaderNodeEmission")
        dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
        s2r = nt.nodes.new("ShaderNodeShaderToRGB")
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        ramp.color_ramp.elements[0].color = lin(hexc("#a9acd6")) + (1,)
        ramp.color_ramp.elements[1].position = 1.0
        ramp.color_ramp.elements[1].color = lin(BG) + (1,)
        nt.links.new(dif.outputs[0], s2r.inputs[0])
        nt.links.new(s2r.outputs[0], ramp.inputs[0])
        nt.links.new(ramp.outputs[0], e.inputs[0])
        nt.links.new(e.outputs[0], o.inputs[0])
        gm.materials.append(gmat)

    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.lens = 85
    scene.render.engine = "BLENDER_EEVEE"
    try:
        scene.eevee.taa_render_samples = 16
    except Exception:
        pass
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    return cam


def aim(cam, loc, target, lens=None):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    if lens:
        cam.data.lens = lens


def render(scene, path, res=(800, 800), samples=None):
    scene.render.resolution_x, scene.render.resolution_y = res
    if samples:
        try:
            scene.eevee.taa_render_samples = samples
        except Exception:
            pass
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

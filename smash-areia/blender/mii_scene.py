"""
Cena de render dos personagens Mii: luzes de estudio, chao de areia, contorno
cartoon (casco invertido) e camera. Usado pelos scripts de amostras.
"""
import math

import bpy
from mathutils import Matrix, Vector

import mii as MII


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MII.reset_materials()


def outline_material(color="#2b2034"):
    m = bpy.data.materials.new("Outline")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dark = nt.nodes.new("ShaderNodeEmission")
    dark.inputs["Color"].default_value = (*MII.srgb(color), 1.0)
    dark.inputs["Strength"].default_value = 1.0
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(dark.outputs[0], mix.inputs[1])
    nt.links.new(clear.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def add_outlines(objs, px=2.2, color="#2b2034"):
    """Contorno cartoon com Freestyle (linhas de silhueta, borda e vinco). Objetos com
    a propriedade `outline` = False (olhos, boca, sobrancelhas...) ficam sem linha propria,
    mas continuam ocultando as linhas de quem esta atras."""
    sc = bpy.context.scene
    vl = bpy.context.view_layer
    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = "ABSOLUTE"
    sc.render.line_thickness = px
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    fs.crease_angle = math.radians(125)
    fs.as_render_pass = False
    for ls in list(fs.linesets):
        fs.linesets.remove(ls)
    col = bpy.data.collections.new("LineArt")
    sc.collection.children.link(col)
    for ob in objs:
        if ob.get("outline"):
            for c in list(ob.users_collection):
                c.objects.unlink(ob)
            col.objects.link(ob)
    ls = fs.linesets.new("Outline")
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = True
    ls.select_contour = False
    ls.select_external_contour = False
    ls.select_material_boundary = False
    ls.select_by_visibility = True
    ls.select_by_collection = True
    ls.collection = col
    ls.collection_negation = "INCLUSIVE"
    st = bpy.data.linestyles.new("OutlineStyle")
    st.color = MII.srgb(color)
    st.thickness = px
    st.thickness_position = "CENTER"
    st.caps = "ROUND"
    st.use_chaining = True
    st.chaining = "PLAIN"
    ls.linestyle = st
    return []


def ground(center=(0, 0, 0), size=(0.62, 0.42), color="#dcc093", name="Sand"):
    """Mancha de areia elíptica sob os pes (como no desenho de referencia)."""
    verts = [(0, 0, 0.0)]
    faces = []
    n = 64
    rng = 0
    for k in range(n):
        t = 2 * math.pi * k / n
        wob = 1 + 0.07 * math.sin(t * 3 + 0.7) + 0.045 * math.sin(t * 5 + 2.1)
        verts.append((size[0] * wob * math.cos(t), size[1] * wob * math.sin(t), 0.0))
    for k in range(n):
        faces.append((0, 1 + k, 1 + (k + 1) % n))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    me.materials.append(MII.mat("Sand", color, rough=0.95))
    ob = bpy.data.objects.new(name, me)
    ob.location = Vector(center) + Vector((0, 0, 0.0005))
    bpy.context.scene.collection.objects.link(ob)
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    ob["outline"] = False
    return ob


def world(top="#fdf8ef", bottom="#eadfcb", strength=1.0):
    w = bpy.data.worlds.new("World")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*MII.srgb(bottom), 1)
    ramp.color_ramp.elements[1].color = (*MII.srgb(top), 1)
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[1].position = 0.75
    nt.links.new(coord.outputs["Window"], sep.inputs[0])
    nt.links.new(sep.outputs["Y"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength
    nt.links.new(bg.outputs[0], out.inputs["Surface"])


def light(name, kind, loc, target, energy, size, color="#ffffff"):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = MII.srgb(color)
    if kind == "AREA":
        ld.size = size
    ob = bpy.data.objects.new(name, ld)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    d = Vector(target) - Vector(loc)
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return ob


def studio(center=(0, 0, 0.9), scale=1.0):
    c = Vector(center)
    light("Key", "AREA", c + Vector((-2.6, -3.4, 3.4)) * scale, c, 330 * scale ** 2, 3.2 * scale, "#fff1dc")
    light("Fill", "AREA", c + Vector((3.2, -2.6, 1.4)) * scale, c, 110 * scale ** 2, 3.0 * scale, "#d9ecff")
    light("Rim", "AREA", c + Vector((1.5, 3.4, 2.6)) * scale, c, 230 * scale ** 2, 2.0 * scale, "#ffe9c9")
    light("Top", "AREA", c + Vector((0, -0.5, 4.2)) * scale, c, 90 * scale ** 2, 3.0 * scale, "#ffffff")


def camera(loc, target, ortho_scale=None, lens=60, name="Cam"):
    cd = bpy.data.cameras.new(name)
    if ortho_scale:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho_scale
    else:
        cd.lens = lens
    ob = bpy.data.objects.new(name, cd)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    d = Vector(target) - Vector(loc)
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = ob
    return ob


def setup_render(w, h, samples=64, denoise=True):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = denoise
    try:
        sc.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        pass
    sc.cycles.max_bounces = 6
    sc.cycles.transparent_max_bounces = 16
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.adaptive_threshold = 0.02
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    try:
        sc.view_settings.view_transform = "Standard"
    except Exception:
        pass
    sc.view_settings.look = "None"
    sc.view_settings.exposure = -0.05
    sc.view_settings.gamma = 1.0
    sc.render.film_transparent = False


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path

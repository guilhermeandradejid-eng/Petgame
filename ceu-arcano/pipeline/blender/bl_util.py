"""Blender helpers for the Ceu Arcano stage pipeline.

Conventions
-----------
* 1 Blender unit = 1 art pixel.
* Layer pixel space: x to the right, y DOWN (Godot style).  Blender: X = x,
  Z = -y, Y = depth (positive = further away from the camera).
* Every material carries two shaders:
    - a *light* shader (white diffuse, optional bump, or emission for glowing
      things) used to render a clean lighting pass, and
    - an *id* emission that encodes (class, ramp-offset, depth) exactly.
  `set_pass()` relinks every material output to one or the other.
  The post-processor (pixelize.py) turns (class, offset, light) into palette
  indices, so the final colours are 100% controlled by the curated palette.
"""
import math
import os
import random

import bpy  # noqa: F401  (must be imported before bmesh)
import bmesh
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector, noise

CLS_SCALE = 64.0      # R = cls / CLS_SCALE
OFF_SCALE = 16.0      # G = 0.5 + off / OFF_SCALE

MATERIALS = []        # list of (material, out_node, light_socket, id_socket)


# ----------------------------------------------------------------------------
# colour helpers
# ----------------------------------------------------------------------------
def srgb_to_lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_lin(h):
    h = h.lstrip('#')
    return tuple(srgb_to_lin(int(h[i:i + 2], 16)) for i in (0, 2, 4))


# ----------------------------------------------------------------------------
# scene
# ----------------------------------------------------------------------------
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATERIALS.clear()
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    cy = sc.cycles
    cy.device = 'CPU'
    cy.seed = 7
    cy.use_animated_seed = False
    cy.caustics_reflective = False
    cy.caustics_refractive = False
    cy.sample_clamp_indirect = 4.0
    sc.render.threads_mode = 'FIXED'
    sc.render.threads = 4
    sc.render.film_transparent = True
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'OPEN_EXR'
    sc.render.image_settings.color_depth = '32'
    sc.render.image_settings.exr_codec = 'ZIP'
    sc.render.use_compositing = False
    sc.render.use_sequencer = False
    world = bpy.data.worlds.new('World')
    sc.world = world
    nt = world.node_tree
    bg = nt.nodes.get('Background') or nt.nodes.new('ShaderNodeBackground')
    out = nt.nodes.get('World Output') or nt.nodes.new('ShaderNodeOutputWorld')
    nt.links.new(bg.outputs[0], out.inputs[0])
    return sc


def collection(name):
    sc = bpy.context.scene
    if name in bpy.data.collections:
        return bpy.data.collections[name]
    c = bpy.data.collections.new(name)
    sc.collection.children.link(c)
    return c


def only_collections(names):
    vl = bpy.context.view_layer
    for lc in vl.layer_collection.children:
        lc.exclude = lc.name not in names


def set_world(color_hex, strength):
    nt = bpy.context.scene.world.node_tree
    bg = nt.nodes['Background']
    r, g, b = hex_lin(color_hex)
    bg.inputs['Color'].default_value = (r, g, b, 1.0)
    bg.inputs['Strength'].default_value = strength


def add_sun(name, color_hex, strength, direction, coll, angle_deg=2.0):
    """direction = direction the light TRAVELS (from light to scene)."""
    ld = bpy.data.lights.new(name, 'SUN')
    ld.color = hex_lin(color_hex)
    ld.energy = strength
    ld.angle = math.radians(angle_deg)
    ob = bpy.data.objects.new(name, ld)
    d = Vector(direction).normalized()
    ob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    coll.objects.link(ob)
    return ob


def ortho_camera(name, coll):
    cd = bpy.data.cameras.new(name)
    cd.type = 'ORTHO'
    cd.clip_start = 1.0
    cd.clip_end = 20000.0
    ob = bpy.data.objects.new(name, cd)
    coll.objects.link(ob)
    return ob


def setup_layer_camera(cam, origin, size, tilt_deg=0.0, dist=6000.0):
    """Place an ortho camera so that layer pixel (u, v) maps to world point
    x = origin.x + u, y = origin.y + v on the plane through the world origin
    (for a tilted camera: y measured on the camera's up axis)."""
    sc = bpy.context.scene
    W, H = size
    sc.render.resolution_x = W
    sc.render.resolution_y = H
    sc.render.pixel_aspect_x = 1
    sc.render.pixel_aspect_y = 1
    cam.data.ortho_scale = float(max(W, H))
    cam.data.sensor_fit = 'AUTO'
    th = math.radians(tilt_deg)
    fwd = Vector((0.0, math.cos(th), -math.sin(th)))
    up = Vector((0.0, math.sin(th), math.cos(th)))
    cx = origin[0] + W / 2.0
    cy = origin[1] + H / 2.0          # pixel space, y down
    target = Vector((cx, 0.0, 0.0)) + up * (-cy)
    cam.location = target - fwd * dist
    cam.rotation_euler = (math.pi / 2 - th, 0.0, 0.0)
    sc.camera = cam
    bpy.context.view_layer.update()


def project(cam, co):
    """World coordinate -> layer pixel (u, v), float."""
    sc = bpy.context.scene
    p = world_to_camera_view(sc, cam, Vector(co))
    return p.x * sc.render.resolution_x, (1.0 - p.y) * sc.render.resolution_y


# ----------------------------------------------------------------------------
# node building
# ----------------------------------------------------------------------------
class NB:
    """Tiny node-graph helper.  Inputs can be floats or sockets."""

    def __init__(self, mat):
        self.mat = mat
        self.nt = mat.node_tree
        self.nodes = self.nt.nodes
        self.links = self.nt.links

    def new(self, kind, **props):
        n = self.nodes.new(kind)
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def _in(self, sock, val):
        if isinstance(val, bpy.types.NodeSocket):
            self.links.new(val, sock)
        elif val is not None:
            sock.default_value = val

    def math(self, op, a, b=None, c=None, clamp=False):
        n = self.new('ShaderNodeMath', operation=op, use_clamp=clamp)
        self._in(n.inputs[0], a)
        if b is not None:
            self._in(n.inputs[1], b)
        if c is not None:
            self._in(n.inputs[2], c)
        return n.outputs[0]

    def add(self, a, b):
        return self.math('ADD', a, b)

    def mul(self, a, b):
        return self.math('MULTIPLY', a, b)

    def gt(self, a, t):
        return self.math('GREATER_THAN', a, t)

    def lt(self, a, t):
        return self.math('LESS_THAN', a, t)

    def lerp(self, a, b, t):
        # a + (b - a) * t
        d = self.math('SUBTRACT', b, a)
        return self.math('MULTIPLY_ADD', d, t, a)

    def coord(self, kind='Object'):
        n = self.new('ShaderNodeTexCoord')
        return n.outputs[kind]

    def scale_vec(self, vec, s):
        n = self.new('ShaderNodeVectorMath', operation='MULTIPLY')
        self._in(n.inputs[0], vec)
        n.inputs[1].default_value = s if isinstance(s, (tuple, list)) else (s, s, s)
        return n.outputs[0]

    def noise(self, scale, detail=2.0, rough=0.5, vec=None, w=None, distortion=0.0):
        n = self.new('ShaderNodeTexNoise')
        if w is not None:
            n.noise_dimensions = '4D'
            n.inputs['W'].default_value = w
        n.inputs['Scale'].default_value = scale
        n.inputs['Detail'].default_value = detail
        n.inputs['Roughness'].default_value = rough
        n.inputs['Distortion'].default_value = distortion
        self._in(n.inputs['Vector'], vec if vec is not None else self.coord('Object'))
        return n.outputs['Factor']

    def voronoi(self, scale, feature='F1', vec=None, rand=1.0, out='Distance', w=None):
        n = self.new('ShaderNodeTexVoronoi', feature=feature)
        if w is not None:
            n.voronoi_dimensions = '4D'
            n.inputs['W'].default_value = w
        n.inputs['Scale'].default_value = scale
        n.inputs['Randomness'].default_value = rand
        self._in(n.inputs['Vector'], vec if vec is not None else self.coord('Object'))
        return n.outputs[out]

    def sep(self, vec):
        n = self.new('ShaderNodeSeparateXYZ')
        self._in(n.inputs[0], vec)
        return n.outputs

    def normal_z(self):
        g = self.new('ShaderNodeNewGeometry')
        return self.sep(g.outputs['Normal'])[2]

    def normal(self):
        return self.new('ShaderNodeNewGeometry').outputs['Normal']

    def position(self):
        return self.new('ShaderNodeNewGeometry').outputs['Position']

    def attr(self, name, kind='GEOMETRY', out='Factor'):
        n = self.new('ShaderNodeAttribute', attribute_name=name, attribute_type=kind)
        return n.outputs[out]

    def obj_random(self):
        return self.new('ShaderNodeObjectInfo').outputs['Random']

    def facing(self, blend=0.5):
        n = self.new('ShaderNodeLayerWeight')
        n.inputs['Blend'].default_value = blend
        return n.outputs['Facing']

    def diffuse(self, color=(0.8, 0.8, 0.8), bump=None, bump_strength=0.5, bump_dist=1.0):
        d = self.new('ShaderNodeBsdfDiffuse')
        d.inputs['Color'].default_value = (*color, 1.0)
        if bump is not None:
            b = self.new('ShaderNodeBump')
            b.inputs['Strength'].default_value = bump_strength
            b.inputs['Distance'].default_value = bump_dist
            self._in(b.inputs['Height'], bump)
            self.links.new(b.outputs['Normal'], d.inputs['Normal'])
        return d.outputs[0]

    def emission(self, color, strength):
        e = self.new('ShaderNodeEmission')
        if isinstance(color, bpy.types.NodeSocket):
            self.links.new(color, e.inputs['Color'])
        else:
            e.inputs['Color'].default_value = (*color, 1.0)
        self._in(e.inputs['Strength'], strength)
        return e.outputs[0]

    def add_shader(self, a, b):
        n = self.new('ShaderNodeAddShader')
        self.links.new(a, n.inputs[0])
        self.links.new(b, n.inputs[1])
        return n.outputs[0]

    def combine(self, r, g, b):
        n = self.new('ShaderNodeCombineColor')
        self._in(n.inputs['Red'], r)
        self._in(n.inputs['Green'], g)
        self._in(n.inputs['Blue'], b)
        return n.outputs[0]


def make_material(name, cls, off=0.0, light=None):
    """cls / off: number, or callable(nb) -> socket.
    light: callable(nb) -> shader socket (default: plain white diffuse)."""
    mat = bpy.data.materials.new(name)
    nt = mat.node_tree
    nt.nodes.clear()
    nb = NB(mat)
    out = nb.new('ShaderNodeOutputMaterial')
    out.target = 'CYCLES'
    cls_s = cls(nb) if callable(cls) else float(cls)
    off_s = off(nb) if callable(off) else float(off)
    r = nb.math('DIVIDE', cls_s, CLS_SCALE)
    g = nb.math('MULTIPLY_ADD', off_s, 1.0 / OFF_SCALE, 0.5)
    depth = nb.new('ShaderNodeCameraData').outputs['View Z Depth']
    col = nb.combine(r, g, depth)
    id_sock = nb.emission(col, 1.0)
    light_sock = light(nb) if light is not None else nb.diffuse()
    nt.links.new(light_sock, out.inputs['Surface'])
    MATERIALS.append((mat, out, light_sock, id_sock))
    return mat


def set_pass(mode):
    for mat, out, light_sock, id_sock in MATERIALS:
        src = id_sock if mode == 'id' else light_sock
        mat.node_tree.links.new(src, out.inputs['Surface'])


# ----------------------------------------------------------------------------
# rendering
# ----------------------------------------------------------------------------
def load_exr(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    a = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return np.flipud(a.reshape(h, w, 4)).copy()


def render_passes(tmp_dir, tag, samples=48, world=('#6a5aa8', 0.6), denoise=True,
                  light_filter=1.0):
    sc = bpy.context.scene
    cy = sc.cycles
    os.makedirs(tmp_dir, exist_ok=True)
    # --- id pass: exact, point sampled, no lighting
    set_pass('id')
    cy.samples = 1
    cy.use_adaptive_sampling = False
    cy.use_denoising = False
    cy.pixel_filter_type = 'BOX'
    cy.filter_width = 0.01
    cy.max_bounces = 0
    cy.transparent_max_bounces = 0
    set_world('#000000', 0.0)
    p_id = os.path.join(tmp_dir, f'{tag}_id.exr')
    sc.render.filepath = p_id
    bpy.ops.render.render(write_still=True)
    ida = load_exr(p_id)
    # --- light pass
    set_pass('light')
    cy.samples = samples
    cy.use_adaptive_sampling = False
    cy.use_denoising = denoise
    if denoise:
        cy.denoiser = 'OPENIMAGEDENOISE'
        cy.denoising_input_passes = 'RGB_ALBEDO_NORMAL'
    cy.pixel_filter_type = 'BOX'
    cy.filter_width = light_filter
    cy.max_bounces = 3
    cy.diffuse_bounces = 2
    cy.glossy_bounces = 0
    cy.transmission_bounces = 0
    cy.volume_bounces = 0
    cy.transparent_max_bounces = 2
    set_world(*world)
    p_l = os.path.join(tmp_dir, f'{tag}_light.exr')
    sc.render.filepath = p_l
    bpy.ops.render.render(write_still=True)
    la = load_exr(p_l)
    return ida, la


# ----------------------------------------------------------------------------
# mesh helpers
# ----------------------------------------------------------------------------
def obj_from_bm(name, bm, mats, coll, smooth=False, loc=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if not isinstance(mats, (list, tuple)):
        mats = [mats]
    for m in mats:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    coll.objects.link(ob)
    return ob


def bm_ico(radius=1.0, subdiv=3):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    return bm


def bm_uvsphere(radius=1.0, segs=24, rings=12):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    return bm


def bm_box(sx, sy, sz, center=(0, 0, 0), bevel=0.0, bevel_segs=1):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=bevel_segs,
                        affect='EDGES', profile=0.5)
    return bm


def bm_cyl(r1, r2, depth, segs=16, center=(0, 0, 0), axis='Z', cap=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=segs,
                          radius1=r1, radius2=r2, depth=depth)
    if axis == 'Y':
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, 'X'))
    elif axis == 'X':
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, 'Y'))
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    return bm


def bm_merge(dst, src):
    """Append bmesh src into dst (src is freed)."""
    me = bpy.data.meshes.new('_tmp')
    src.to_mesh(me)
    src.free()
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)
    return dst


def fbm(p, octaves=4, basis='PERLIN_NEW'):
    return noise.fractal(Vector(p), 0.6, 2.0, octaves, noise_basis=basis)


def curve_obj(name, pts, radii, mat, coll, bevel=1.0, res=2, kind='POLY'):
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = bevel
    cu.bevel_resolution = res
    cu.use_fill_caps = True
    sp = cu.splines.new(kind)
    sp.points.add(len(pts) - 1)
    for i, (p, r) in enumerate(zip(pts, radii)):
        sp.points[i].co = (p[0], p[1], p[2], 1.0)
        sp.points[i].radius = r
    if kind == 'NURBS':
        sp.use_endpoint_u = True
        sp.order_u = 3
    sp.resolution_u = 6
    cu.materials.append(mat)
    ob = bpy.data.objects.new(name, cu)
    coll.objects.link(ob)
    return ob


def catenary(p0, p1, sag, n=24):
    """Points of a hanging string between p0 and p1 (Blender coords, Z up)."""
    p0, p1 = Vector(p0), Vector(p1)
    out = []
    for i in range(n + 1):
        t = i / n
        p = p0.lerp(p1, t)
        p.z -= sag * 4 * t * (1 - t)
        out.append(p)
    return out


def rng(seed):
    return random.Random(seed)

"""Bolo v2: red panda adventurer, built for a modern rendered look (fur, canvas, leather, brass, glass).

    /opt/bpyenv/bin/python hero.py -- out_dir [samples] [views]
Static model sheet only: front, profile, 3/4 and a face close-up. Facing -Y, z up, metres.
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from vinyl import Piece, hexc  # noqa: E402  (fused-primitive helper reused for base shapes)

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else "."
SAMPLES = int(args[1]) if len(args) > 1 else 64
DENSITY = float(args[3]) if len(args) > 3 else 1.0  # fur children multiplier for quick previews
VIEWS = args[2].split(",") if len(args) > 2 else ["front", "side", "three", "face"]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ----------------------------------------------------------------------------- proportions
# Ratchet-like: big head (about a third of the height), slim torso, long-ish legs, big hands and feet.
HEAD = Vector((0, -0.02, 1.0))
HEAD_R = 0.235
HEAD_S = Vector((1.08, 1.0, 0.98))


def on_head(yaw_deg, pitch_deg, lift=0.0):
    """Point on the head ellipsoid surface: yaw 0 = straight ahead (-Y), + to the character's left."""
    y, p = math.radians(yaw_deg), math.radians(pitch_deg)
    d = Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p)))
    s = Vector((d.x * HEAD_S.x, d.y * HEAD_S.y, d.z * HEAD_S.z))
    return HEAD + s * (HEAD_R + lift), s.normalized()


EYES = [on_head(sx * 25, 6, -0.042)[0] for sx in (-1, 1)]
EYE_R = 0.056
MUZZLE = on_head(0, -16, -0.02)[0] + Vector((0, -0.02, 0))
NOSE = MUZZLE + Vector((0, -0.075, 0.025))
EAR = [Vector((sx * 0.19, 0.01, 1.2)) for sx in (-1, 1)]
SHOULDER = [Vector((sx * 0.165, 0.0, 0.8)) for sx in (-1, 1)]
ELBOW = [Vector((sx * 0.29, -0.02, 0.62)) for sx in (-1, 1)]
WRIST = [Vector((sx * 0.37, -0.05, 0.46)) for sx in (-1, 1)]
HIP = [Vector((sx * 0.085, 0.0, 0.42)) for sx in (-1, 1)]
KNEE = [Vector((sx * 0.1, -0.03, 0.24)) for sx in (-1, 1)]
ANKLE = [Vector((sx * 0.105, 0.0, 0.1)) for sx in (-1, 1)]
TAIL = [Vector(p) for p in ((0, 0.11, 0.46), (0.02, 0.27, 0.4), (0.06, 0.45, 0.46), (0.1, 0.6, 0.62), (0.12, 0.68, 0.82), (0.11, 0.68, 0.98))]
TAIL_R = [0.06, 0.08, 0.09, 0.085, 0.07, 0.045]


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length, t


def tail_param(p):
    best, bt = 9.0, 0.0
    for i in range(len(TAIL) - 1):
        d, t = seg_dist(p, TAIL[i], TAIL[i + 1])
        if d < best:
            best, bt = d, (i + t) / (len(TAIL) - 1)
    return best, bt


# ----------------------------------------------------------------------------- materials

def node_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    return m, nt, out


def principled(nt, color, rough=0.5, **kw):
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value = hexc(color)
    b.inputs["Roughness"].default_value = rough
    for k, v in kw.items():
        b.inputs[k].default_value = v
    return b


def bump(nt, height_socket, strength=0.3, distance=0.002):
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = strength
    bp.inputs["Distance"].default_value = distance
    nt.links.new(height_socket, bp.inputs["Height"])
    return bp


def noise(nt, scale, detail=6.0, rough=0.6):
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = rough
    return n


def mix_rgb(nt, a, b, fac):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = "MIX"
    if isinstance(fac, float):
        m.inputs["Factor"].default_value = fac
    else:
        nt.links.new(fac, m.inputs["Factor"])
    for sock, v in ((m.inputs[6], a), (m.inputs[7], b)):
        if isinstance(v, str):
            sock.default_value = hexc(v)
        else:
            nt.links.new(v, sock)
    return m.outputs[2]


def mat_fur(name, color, tip, root):
    """Principled hair with root-to-tip gradient and per-strand variation."""
    m, nt, out = node_mat(name)
    h = nt.nodes.new("ShaderNodeBsdfHairPrincipled")
    h.parametrization = "COLOR"
    h.inputs["Roughness"].default_value = 0.32
    h.inputs["Radial Roughness"].default_value = 0.45
    h.inputs["Coat"].default_value = 0.15
    info = nt.nodes.new("ShaderNodeHairInfo")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = hexc(root)
    ramp.color_ramp.elements[1].color = hexc(tip)
    ramp.color_ramp.elements.new(0.45).color = hexc(color)
    nt.links.new(info.outputs["Intercept"], ramp.inputs[0])
    var = nt.nodes.new("ShaderNodeMath")
    var.operation = "MULTIPLY_ADD"
    var.inputs[1].default_value = 0.25
    var.inputs[2].default_value = 0.88
    nt.links.new(info.outputs["Random"], var.inputs[0])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(ramp.outputs[0], mul.inputs[6])
    nt.links.new(var.outputs[0], mul.inputs[7])
    nt.links.new(mul.outputs[2], h.inputs["Color"])
    nt.links.new(h.outputs[0], out.inputs[0])
    return m


def mat_skin(name, color):
    m, nt, out = node_mat(name)
    b = principled(nt, color, 0.8)
    nt.links.new(b.outputs[0], out.inputs[0])
    return m


def mat_canvas(name, color):
    """Waxed canvas: fine weave, soft folds, slightly lighter wear patches, dark crevices."""
    m, nt, out = node_mat(name)
    b = principled(nt, color, 0.7, **{"Sheen Weight": 0.12, "Sheen Roughness": 0.5})
    tc = nt.nodes.new("ShaderNodeTexCoord")
    w1 = nt.nodes.new("ShaderNodeTexWave")
    w1.inputs["Scale"].default_value = 180.0
    w1.bands_direction = "X"
    w2 = nt.nodes.new("ShaderNodeTexWave")
    w2.inputs["Scale"].default_value = 180.0
    w2.bands_direction = "Z"
    for w in (w1, w2):
        nt.links.new(tc.outputs["Object"], w.inputs["Vector"])
    weave = nt.nodes.new("ShaderNodeMath")
    weave.operation = "ADD"
    nt.links.new(w1.outputs["Fac"], weave.inputs[0])
    nt.links.new(w2.outputs["Fac"], weave.inputs[1])
    folds = noise(nt, 7.0, 3.0, 0.5)
    nt.links.new(tc.outputs["Object"], folds.inputs["Vector"])
    h = nt.nodes.new("ShaderNodeMath")
    h.operation = "MULTIPLY_ADD"
    h.inputs[1].default_value = 0.08
    nt.links.new(weave.outputs[0], h.inputs[0])
    nt.links.new(folds.outputs["Fac"], h.inputs[2])
    bp = bump(nt, h.outputs[0], 0.35, 0.01)
    nt.links.new(bp.outputs[0], b.inputs["Normal"])
    mott = noise(nt, 22.0)
    nt.links.new(tc.outputs["Object"], mott.inputs["Vector"])
    wear = nt.nodes.new("ShaderNodeMapRange")
    wear.inputs["From Min"].default_value = 0.55
    wear.inputs["From Max"].default_value = 0.85
    wear.inputs["To Max"].default_value = 0.35
    nt.links.new(mott.outputs["Fac"], wear.inputs["Value"])
    col = mix_rgb(nt, color, "#d6a84e", wear.outputs["Result"])
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(b.outputs[0], out.inputs[0])
    return m


def mat_leather(name, color, rough=0.42):
    m, nt, out = node_mat(name)
    b = principled(nt, color, rough, **{"Coat Weight": 0.25, "Coat Roughness": 0.3})
    tc = nt.nodes.new("ShaderNodeTexCoord")
    v = nt.nodes.new("ShaderNodeTexVoronoi")
    v.inputs["Scale"].default_value = 220.0
    nt.links.new(tc.outputs["Object"], v.inputs["Vector"])
    n = noise(nt, 30.0)
    nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
    bp = bump(nt, v.outputs["Distance"], 0.25)
    nt.links.new(bp.outputs[0], b.inputs["Normal"])
    col = mix_rgb(nt, color, "#1c0f08", n.outputs["Fac"])
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(b.outputs[0], out.inputs[0])
    return m


def mat_metal(name, color, rough=0.28):
    m, nt, out = node_mat(name)
    b = principled(nt, color, rough, **{"Metallic": 1.0})
    n = noise(nt, 60.0)
    r = nt.nodes.new("ShaderNodeMapRange")
    r.inputs["To Min"].default_value = rough * 0.6
    r.inputs["To Max"].default_value = rough * 1.6
    nt.links.new(n.outputs["Fac"], r.inputs["Value"])
    nt.links.new(r.outputs["Result"], b.inputs["Roughness"])
    nt.links.new(b.outputs[0], out.inputs[0])
    return m


def mat_knit(name, color):
    m, nt, out = node_mat(name)
    b = principled(nt, color, 0.85, **{"Sheen Weight": 0.8, "Sheen Roughness": 0.5})
    tc = nt.nodes.new("ShaderNodeTexCoord")
    w = nt.nodes.new("ShaderNodeTexWave")
    w.inputs["Scale"].default_value = 70.0
    w.inputs["Distortion"].default_value = 2.0
    w.bands_direction = "Z"
    w.wave_profile = "SIN"
    nt.links.new(tc.outputs["Object"], w.inputs["Vector"])
    bp = bump(nt, w.outputs["Fac"], 0.5, 0.004)
    nt.links.new(bp.outputs[0], b.inputs["Normal"])
    nt.links.new(b.outputs[0], out.inputs[0])
    return m


def mat_glass(name, tint="#d8ecff"):
    m, nt, out = node_mat(name)
    b = principled(nt, tint, 0.02, **{"Transmission Weight": 1.0, "IOR": 1.45})
    nt.links.new(b.outputs[0], out.inputs[0])
    return m


def mat_eye(name, iris="#9a5a1a", ring="#2a1406", radius=1.0):
    """Sclera, iris with radial streaks and a dark limbal ring, pupil, all from the local
    angle to the eye's forward axis (-Y in object space)."""
    m, nt, out = node_mat(name)
    b = principled(nt, "#f4efe6", 0.35, **{"Subsurface Weight": 0.15})
    tc = nt.nodes.new("ShaderNodeTexCoord")
    unit = nt.nodes.new("ShaderNodeVectorMath")
    unit.operation = "SCALE"
    unit.inputs["Scale"].default_value = 1.0 / radius
    nt.links.new(tc.outputs["Object"], unit.inputs[0])
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(unit.outputs[0], sep.inputs[0])
    # radial distance from the eye axis, normalised by radius 1 in object space
    xx = nt.nodes.new("ShaderNodeVectorMath")
    xx.operation = "LENGTH"
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(sep.outputs["X"], comb.inputs["X"])
    nt.links.new(sep.outputs["Z"], comb.inputs["Z"])
    nt.links.new(comb.outputs[0], xx.inputs[0])
    front = nt.nodes.new("ShaderNodeMath")
    front.operation = "LESS_THAN"
    front.inputs[1].default_value = 0.0
    nt.links.new(sep.outputs["Y"], front.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    e = ramp.color_ramp.elements
    e[0].position, e[0].color = 0.0, hexc("#050302")
    e[1].position, e[1].color = 1.0, hexc("#f4efe6")
    for pos, c in ((0.3, "#050302"), (0.34, iris), (0.55, "#e8a24e"), (0.66, ring), (0.71, "#f4efe6")):
        el = e.new(pos)
        el.color = hexc(c)
    nt.links.new(xx.outputs["Value"], ramp.inputs[0])
    streak = nt.nodes.new("ShaderNodeTexWave")
    streak.wave_type = "RINGS"
    streak.inputs["Scale"].default_value = 3.0
    streak.inputs["Distortion"].default_value = 6.0
    nt.links.new(unit.outputs[0], streak.inputs["Vector"])
    sel = mix_rgb(nt, "#f4efe6", ramp.outputs[0], front.outputs[0])
    nt.links.new(sel, b.inputs["Base Color"])
    nt.links.new(b.outputs[0], out.inputs[0])
    return m


def mat_nose():
    m, nt, out = node_mat("nose")
    b = principled(nt, "#1b1210", 0.45, **{"Coat Weight": 0.3, "Coat Roughness": 0.3})
    v = nt.nodes.new("ShaderNodeTexVoronoi")
    v.inputs["Scale"].default_value = 300.0
    bp = bump(nt, v.outputs["Distance"], 0.4)
    nt.links.new(bp.outputs[0], b.inputs["Normal"])
    nt.links.new(b.outputs[0], out.inputs[0])
    return m


# ----------------------------------------------------------------------------- helpers

def obj_from_bmesh(name, bm, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    o.data.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = True
    return o


def add_mod(o, kind, **kw):
    m = o.modifiers.new(kind.lower(), kind)
    for k, v in kw.items():
        setattr(m, k, v)
    return m


def apply_all(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        if m.type != "PARTICLE_SYSTEM":
            bpy.ops.object.modifier_apply(modifier=m.name)


def uv_sphere(name, c, r, mat, scale=(1, 1, 1), seg=48):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=c, segments=seg, ring_count=seg // 2)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return o


# ----------------------------------------------------------------------------- body

def build_body():
    skin = mat_skin("skin", "#8a3416")
    p = Piece("Body", skin)
    p.ellip(tuple(HEAD), HEAD_R, tuple(HEAD_S))
    p.ellip((0, -0.07, 0.92), 0.17, (1.25, 0.95, 0.72))            # jaw and cheeks
    p.ellip(tuple(MUZZLE), 0.08, (1.2, 1.0, 0.75))
    for sx in (-1, 1):
        bc, _ = on_head(sx * 22, 20, -0.03)
        p.ellip(tuple(bc), 0.055, (1.3, 0.8, 0.55))                 # brow ridges
        e = EAR[0 if sx < 0 else 1]
        p.ellip(tuple(e), 0.088, (1.0, 0.42, 1.2), rot=(0, math.radians(-sx * 28), 0))
    p.ellip((0, 0.0, 0.66), 0.14, (1.12, 0.85, 1.35))              # slim chest
    p.ellip((0, 0.01, 0.47), 0.13, (1.15, 0.95, 0.85))             # pelvis
    p.caps((0, 0, 0.8), (0, -0.01, 0.9), 0.075)                     # neck
    for i in range(2):
        p.caps(tuple(SHOULDER[i]), tuple(ELBOW[i]), 0.05, 0.044)
        p.caps(tuple(ELBOW[i]), tuple(WRIST[i]), 0.044, 0.046)
        p.caps(tuple(HIP[i]), tuple(KNEE[i]), 0.062, 0.05)
        p.caps(tuple(KNEE[i]), tuple(ANKLE[i]), 0.05, 0.042)
    for i in range(len(TAIL) - 1):
        p.caps(tuple(TAIL[i]), tuple(TAIL[i + 1]), TAIL_R[i] * 0.7, TAIL_R[i + 1] * 0.7)
    return p.build(voxel=0.005, smooth=10, target_faces=70000)


def build_hands():
    """Full leather gloves with four chunky fingers: hands have to read from far away."""
    glove = mat_leather("glove", "#4a2a1a", 0.45)
    hands = []
    for i, sx in enumerate((-1, 1)):
        d = (WRIST[i] - ELBOW[i]).normalized()
        palm_c = WRIST[i] + d * 0.06
        side = Vector((0, -1, 0)).cross(d).normalized()
        p = Piece("Glove.%s" % ("R" if sx < 0 else "L"), glove)
        p.ellip(tuple(palm_c), 0.058, (1.0, 0.72, 1.1))
        p.caps(tuple(WRIST[i] - d * 0.01), tuple(WRIST[i] + d * 0.03), 0.06, 0.058)   # cuff
        for k in range(4):
            base = palm_c + d * 0.04 + side * (0.03 * (k - 1.5)) * sx + Vector((0, -0.014, 0))
            mid = base + d * 0.035 + Vector((0, -0.02, 0))
            tip = mid + d * 0.012 + Vector((0, -0.028, 0))
            p.caps(tuple(base), tuple(mid), 0.02, 0.019)
            p.caps(tuple(mid), tuple(tip), 0.019, 0.017)
        th0 = palm_c + Vector((0, -0.045, 0.012)) - side * sx * 0.025
        p.caps(tuple(th0), tuple(th0 + Vector((0, -0.04, -0.025))), 0.021, 0.018)
        hands.append(p.build(voxel=0.003, smooth=6, target_faces=9000))
    return hands


# ----------------------------------------------------------------------------- fur regions

def region_weights(o):
    """Per-vertex fur colour and length, following real red panda markings."""
    groups = {n: o.vertex_groups.new(name=n) for n in ("rust", "cream", "dark", "ochre", "len")}
    covered = clothes_mask_fn()
    brows = [on_head(sx * 20, 24, 0)[0] for sx in (-1, 1)]
    cheeks = [on_head(sx * 58, -14, 0)[0] for sx in (-1, 1)]
    tear_a = [on_head(sx * 22, -6, 0)[0] for sx in (-1, 1)]
    tear_b = [on_head(sx * 14, -26, 0)[0] for sx in (-1, 1)]
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        w = {"rust": 1.0, "cream": 0.0, "dark": 0.0, "ochre": 0.0}
        length = 0.8
        d_eye = min((p - e).length for e in EYES)
        td, tt = tail_param(p)
        on_tail = td < 0.12 and p.y > 0.1 and p.z < 1.05
        limb = False
        for i in range(2):
            if seg_dist(p, SHOULDER[i], WRIST[i])[0] < 0.08 and (p.x * SHOULDER[i].x) > 0 and abs(p.x) > 0.15:
                limb = True
            if seg_dist(p, HIP[i], ANKLE[i])[0] < 0.085 and p.z < 0.4 and (p.x * HIP[i].x) > 0:
                limb = True
        if limb:
            w = {"rust": 0.0, "cream": 0.0, "dark": 1.0, "ochre": 0.0}
            length = 0.55
        elif on_tail:
            ring = int(tt * 8) % 2 == 1
            w = {"rust": 0.0 if ring else 1.0, "cream": 0.0, "dark": 0.0, "ochre": 1.0 if ring else 0.0}
            length = 2.0 if tt < 0.9 else 1.3
        elif p.z > 0.82:
            mz = Vector(((p.x - MUZZLE.x) / 0.1, (p.y - MUZZLE.y) / 0.1, (p.z - MUZZLE.z) / 0.07)).length
            brow = min((p - c).length for c in brows)
            cheek = min((p - c).length for c in cheeks)
            tear = min(seg_dist(p, tear_a[k], tear_b[k])[0] for k in range(2))
            ear_i = 0 if p.x < 0 else 1
            ear_d = (p - EAR[ear_i]).length
            if tear < 0.02 and p.y < -0.1:
                w = {"rust": 0.0, "cream": 0.0, "dark": 1.0, "ochre": 0.0}
                length = 0.35
            elif mz < 1.15 or brow < 0.035 or cheek < 0.065:
                w = {"rust": 0.0, "cream": 1.0, "dark": 0.0, "ochre": 0.0}
                length = 0.3 if mz < 1.15 else (0.35 if brow < 0.035 else 0.85)
            elif ear_d < 0.13 and p.z > 1.12:
                rim = ear_d > 0.085 or p.y < EAR[ear_i].y - 0.02
                w = {"rust": 0.0 if rim else 1.0, "cream": 1.0 if rim else 0.0, "dark": 0.0, "ochre": 0.0}
                length = 0.38 if rim else 0.3
            else:
                length = 0.5 if p.z > 1.05 else 0.7
                if abs(p.x) > 0.19 and p.z < 1.0:
                    length = 1.05  # cheek ruff
        if d_eye < EYE_R + 0.012 or (p - NOSE).length < 0.04 or covered(p) or p.z < 0.12:
            w = {k: 0.0 for k in w}
        elif d_eye < EYE_R + 0.035:
            length *= 0.3
        for n, val in w.items():
            groups[n].add([v.index], val, "REPLACE")
        groups["len"].add([v.index], min(length / 2.0, 1.0), "REPLACE")


def add_fur(o, name, group, mat, count, children, base_len, clump=0.5):
    o.data.materials.append(mat)
    o.modifiers.new("fur_" + name, "PARTICLE_SYSTEM")
    psys = o.particle_systems[-1]
    s = psys.settings
    s.name = "fur_" + name
    s.type = "HAIR"
    s.use_advanced_hair = True
    s.count = count
    s.emit_from = "FACE"
    s.use_even_distribution = True
    # advanced hair: the emission velocity sets both length and direction
    s.normal_factor = base_len
    s.object_align_factor = (0.0, 0.3 * base_len, -0.85 * base_len)   # combed down and back
    s.child_type = "INTERPOLATED"
    s.child_percent = 4
    s.rendered_child_count = max(2, int(children * DENSITY))
    s.child_length = 1.0
    s.clump_factor = clump
    s.clump_shape = -0.4
    s.roughness_1 = 0.0015
    s.roughness_2 = 0.0035
    s.roughness_endpoint = 0.0015
    s.radius_scale = 0.00075
    s.root_radius = 1.0
    s.tip_radius = 0.1
    s.shape = -0.3
    s.material = len(o.data.materials)
    s.display_step = 3
    s.render_step = 4
    psys.vertex_group_density = group
    psys.vertex_group_length = "len"
    return psys


# ----------------------------------------------------------------------------- outfit

def _on_arm_upper(p, reach=0.8):
    for i in range(2):
        d, t = seg_dist(p, SHOULDER[i], ELBOW[i])
        if d < 0.085 and t < reach and (p.x * SHOULDER[i].x) > 0:
            return True
    return False


def jacket_inside(p):
    if p.z < 0.5 or p.z > 0.86:
        return False
    if p.y > 0.09 and abs(p.x) < 0.09 and p.z < 0.56:
        return False
    torso = abs(p.x) < 0.2
    front_open = p.y < -0.09 and abs(p.x) < 0.04 and p.z < 0.8
    return (torso or _on_arm_upper(p)) and not front_open


def shorts_inside(p):
    if p.z > 0.56 or p.z < 0.29:
        return False
    if p.y > 0.09 and abs(p.x) < 0.09 and p.z > 0.38:
        return False  # tail hole
    return abs(p.x) < 0.21


def clothes_mask_fn():
    return lambda p: jacket_inside(p) or shorts_inside(p)


def shell_from(body, inside, name, mat, offset, thickness, hem=None):
    bm = bmesh.new()
    bm.from_mesh(body.data)
    kill = [v for v in bm.verts if not inside(body.matrix_world @ v.co)]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    for v in bm.verts:
        v.co += v.normal * offset
    if hem is not None:
        _hem_tubes(bm, name + "Hem", hem)
    o = obj_from_bmesh(name, bm, mat)
    add_mod(o, "SMOOTH", factor=0.7, iterations=8)
    add_mod(o, "SOLIDIFY", thickness=thickness, offset=-1.0)
    add_mod(o, "SUBSURF", levels=1, render_levels=1)
    apply_all(o)
    return o


def _hem_tubes(bm, name, mat):
    """A rolled hem along every open edge of a garment shell (reads as stitching and piping)."""
    edges = [e for e in bm.edges if e.is_boundary]
    if not edges:
        return
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.0065
    cu.bevel_resolution = 3
    for e in edges:
        sp = cu.splines.new("POLY")
        sp.points.add(1)
        for k, v in enumerate(e.verts):
            sp.points[k].co = (*v.co, 1.0)
    o = bpy.data.objects.new(name, cu)
    scene.collection.objects.link(o)
    o.data.materials.append(mat)


def build_jacket(body):
    canvas = mat_canvas("canvas", "#9c6608")
    o = shell_from(body, jacket_inside, "Jacket", canvas, 0.026, 0.011, hem=mat_canvas("canvas_hem", "#8f6514"))
    sher = mat_skin("sherpa_base", "#efe2c8")
    for i in range(2):
        d = (ELBOW[i] - SHOULDER[i]).normalized()
        c = SHOULDER[i] + (ELBOW[i] - SHOULDER[i]) * 0.8
        bpy.ops.mesh.primitive_torus_add(major_radius=0.066, minor_radius=0.018, location=c)
        cuff = bpy.context.active_object
        cuff.rotation_euler = Vector((0, 0, 1)).rotation_difference(d).to_euler()
        cuff.data.materials.append(canvas)
        bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_torus_add(major_radius=0.105, minor_radius=0.035, location=(0, 0.0, 0.835))
    collar = bpy.context.active_object
    collar.name = "Collar"
    collar.scale = (1.12, 1.0, 0.7)
    collar.rotation_euler = (math.radians(-14), 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    collar.data.materials.append(sher)
    bpy.ops.object.shade_smooth()
    fleece = mat_fur("fleece", "#efe2c8", "#fff8ea", "#cdb894")
    collar.vertex_groups.new(name="all").add([v.index for v in collar.data.vertices], 1.0, "REPLACE")
    collar.vertex_groups.new(name="len").add([v.index for v in collar.data.vertices], 1.0, "REPLACE")
    ps = add_fur(collar, "fleece", "all", fleece, 1500, 30, 0.012, clump=0.75)
    ps.settings.object_align_factor = (0, 0, 0)
    ps.settings.roughness_2 = 0.008
    return o


def build_shorts(body):
    khaki = mat_canvas("khaki", "#5d5636")
    return shell_from(body, shorts_inside, "Shorts", khaki, 0.02, 0.01, hem=mat_canvas("khaki_hem", "#3f3a22"))


def build_belt_and_gear():
    leather = mat_leather("leather", "#5a3320")
    brass = mat_metal("brass", "#c9a24a", 0.3)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.16, minor_radius=0.02, location=(0, 0.01, 0.53), major_segments=64)
    belt = bpy.context.active_object
    belt.name = "Belt"
    belt.scale = (1.0, 0.86, 1.7)
    bpy.ops.object.transform_apply(scale=True)
    belt.data.materials.append(leather)
    bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_cube_add(size=0.055, location=(0, -0.152, 0.53))
    b = bpy.context.active_object
    b.scale = (1.0, 0.25, 0.85)
    add_mod(b, "BEVEL", width=0.008, segments=3)
    b.data.materials.append(brass)
    bpy.ops.object.shade_smooth()
    for sx in (-1, 1):
        a = math.radians(sx * 60)
        c = Vector((math.sin(a) * 0.17, -math.cos(a) * 0.15, 0.47))
        bpy.ops.mesh.primitive_cube_add(size=0.1, location=c)
        p = bpy.context.active_object
        p.scale = (0.7, 0.42, 0.85)
        p.rotation_euler = (0, 0, a)
        add_mod(p, "BEVEL", width=0.018, segments=4)
        add_mod(p, "SUBSURF", levels=1, render_levels=2)
        p.data.materials.append(leather)
        bpy.ops.object.shade_smooth()
        f = c + Vector((math.sin(a), -math.cos(a), 0)) * 0.022 + Vector((0, 0, 0.03))
        bpy.ops.mesh.primitive_cube_add(size=0.1, location=f)
        flap = bpy.context.active_object
        flap.scale = (0.74, 0.12, 0.42)
        flap.rotation_euler = (math.radians(8), 0, a)
        add_mod(flap, "BEVEL", width=0.01, segments=3)
        flap.data.materials.append(leather)
        bpy.ops.object.shade_smooth()
        uv_sphere("Stud", f + Vector((math.sin(a), -math.cos(a), 0)) * 0.008 + Vector((0, 0, -0.012)), 0.009, brass, seg=16)


def build_boots():
    boot_l = mat_leather("boot_leather", "#6b3d22", 0.48)
    rubber = mat_skin("rubber", "#2a2522")
    brass = bpy.data.materials["brass"]
    for i in range(2):
        a = ANKLE[i]
        p = Piece("Boot.%d" % i, boot_l)
        p.caps(tuple(a + Vector((0, 0.005, 0.1))), tuple(a + Vector((0, 0.0, -0.03))), 0.07, 0.074)
        p.ellip(tuple(a + Vector((0, -0.095, -0.045))), 0.085, (1.0, 1.55, 0.62))  # big rounded toe box
        p.build(voxel=0.004, smooth=6, target_faces=9000)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.088, depth=0.026, location=a + Vector((0, -0.055, -0.088)), vertices=48)
        sole = bpy.context.active_object
        sole.scale = (1.0, 1.75, 1.0)
        add_mod(sole, "BEVEL", width=0.009, segments=3)
        sole.data.materials.append(rubber)
        bpy.ops.object.shade_smooth()
        bpy.ops.mesh.primitive_torus_add(major_radius=0.074, minor_radius=0.009, location=a + Vector((0, 0.004, 0.065)))
        strap = bpy.context.active_object
        strap.data.materials.append(boot_l)
        bpy.ops.object.shade_smooth()
        bpy.ops.mesh.primitive_cube_add(size=0.024, location=a + Vector((ANKLE[i].x * 0.6, -0.05, 0.065)))
        bk = bpy.context.active_object
        bk.scale = (1.0, 0.35, 0.9)
        add_mod(bk, "BEVEL", width=0.004, segments=2)
        bk.data.materials.append(brass)


def build_scarf():
    knit = mat_knit("knit", "#2f6f73")
    p = Piece("Scarf", knit)
    for k in range(18):
        a = k / 18 * math.tau
        p.ball((math.cos(a) * 0.108, math.sin(a) * 0.1 - 0.015, 0.875 + 0.014 * math.sin(a * 2)), 0.05)
    p.ellip((0.075, -0.125, 0.83), 0.05, (1.2, 0.7, 1.0))          # knot
    p.caps((0.08, -0.13, 0.82), (0.12, -0.17, 0.68), 0.045, 0.042)
    p.caps((0.12, -0.17, 0.68), (0.13, -0.175, 0.56), 0.042, 0.044)
    return p.build(voxel=0.005, smooth=6, target_faces=12000)


def build_goggles():
    leather = bpy.data.materials["leather"]
    brass = bpy.data.materials["brass"]
    glass = mat_glass("lens", "#bfe4ff")
    # strap hugging the head over the brow, under the ears
    pts = []
    for k in range(64):
        yaw = k / 64 * 360.0
        pitch = 34 - 14 * math.cos(math.radians(yaw))  # higher at the back
        pts.append(on_head(yaw, pitch, 0.012)[0])
    bm = bmesh.new()
    ring = []
    for q in pts:
        ring.append((bm.verts.new(q + Vector((0, 0, -0.016))), bm.verts.new(q + Vector((0, 0, 0.016)))))
    for k in range(64):
        a, b = ring[k], ring[(k + 1) % 64]
        bm.faces.new((a[0], b[0], b[1], a[1]))
    strap = obj_from_bmesh("Strap", bm, leather)
    add_mod(strap, "SOLIDIFY", thickness=0.006, offset=0.0)
    for sx in (-1, 1):
        c, n = on_head(sx * 17, 33, 0.022)
        rot = Vector((0, 0, 1)).rotation_difference(n).to_euler()
        bpy.ops.mesh.primitive_cylinder_add(radius=0.045, depth=0.03, location=c, vertices=48)
        cup = bpy.context.active_object
        cup.rotation_euler = rot
        add_mod(cup, "BEVEL", width=0.006, segments=3)
        cup.data.materials.append(brass)
        bpy.ops.object.shade_smooth()
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.039, location=c + n * 0.008, segments=32, ring_count=16)
        lens = bpy.context.active_object
        lens.scale = (1, 1, 0.35)
        lens.rotation_euler = rot
        lens.data.materials.append(glass)
        bpy.ops.object.shade_smooth()


def build_eyes():
    eye_m = mat_eye("eye", iris="#7a3d12", ring="#1e0d05", radius=EYE_R)
    cornea = mat_glass("cornea", "#ffffff")
    lid_m = bpy.data.materials["skin"]
    for e in EYES:
        d = (e - HEAD).normalized()
        d = (d + Vector((0, -1.6, 0))).normalized()
        rot = Vector((0, -1, 0)).rotation_difference(d).to_euler()
        ball = uv_sphere("Eye", tuple(e), EYE_R, eye_m, seg=48)
        ball.rotation_euler = rot
        c = uv_sphere("Cornea", tuple(e + d * 0.005), EYE_R * 1.04, cornea, seg=48)
        c.rotation_euler = rot
        bpy.ops.mesh.primitive_uv_sphere_add(radius=EYE_R * 1.1, location=e, segments=48, ring_count=24)
        lid = bpy.context.active_object
        lid.name = "Lid"
        bm = bmesh.new()
        bm.from_mesh(lid.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < EYE_R * 0.3], context="VERTS")
        bm.to_mesh(lid.data)
        bm.free()
        lid.rotation_euler = (rot.x + math.radians(-10), rot.y, rot.z)
        lid.data.materials.append(lid_m)
        bpy.ops.object.shade_smooth()
        lid.vertex_groups.new(name="all").add([v.index for v in lid.data.vertices], 1.0, "REPLACE")
        lid.vertex_groups.new(name="len").add([v.index for v in lid.data.vertices], 1.0, "REPLACE")
        lp = add_fur(lid, "lid", "all", bpy.data.materials["fur_rust"], 500, 20, 0.007, clump=0.3)
        lp.settings.object_align_factor = (0, 0, 0.004)
    return uv_sphere("Nose", tuple(NOSE), 0.026, mat_nose(), (1.35, 0.95, 0.8))


# ----------------------------------------------------------------------------- owlet

def build_owl():
    """A little owl perched on Bolo's right shoulder."""
    base = on_head(0, 72, 0.08)[0] + Vector((0, 0.02, 0.0))
    skin = mat_skin("owl_skin", "#6b5440")
    p = Piece("Owl", skin)
    p.ellip(tuple(base), 0.07, (1.05, 0.95, 0.95))
    p.ellip(tuple(base + Vector((0, -0.005, 0.08))), 0.068, (1.15, 1.0, 0.9))
    for sx in (-1, 1):
        p.ellip(tuple(base + Vector((sx * 0.045, 0.005, 0.145))), 0.022, (0.6, 0.5, 1.4))  # ear tufts
        p.ellip(tuple(base + Vector((sx * 0.07, 0.01, 0.0))), 0.045, (0.45, 0.9, 1.2))     # folded wings
    owl = p.build(voxel=0.003, smooth=6, target_faces=16000)
    head = base + Vector((0, -0.005, 0.085))
    g = {n: owl.vertex_groups.new(name=n) for n in ("brown", "cream", "len")}
    for v in owl.data.vertices:
        q = owl.matrix_world @ v.co
        face = (q - (head + Vector((0, -0.06, 0)))).length < 0.06
        belly = q.y < base.y - 0.04 and q.z < head.z - 0.03
        eye_hole = min((q - (head + Vector((sx * 0.03, -0.062, 0.005)))).length for sx in (-1, 1)) < 0.024
        cream = face
        g["brown"].add([v.index], 0.0 if (cream or eye_hole) else 1.0, "REPLACE")
        g["cream"].add([v.index], 0.0 if eye_hole else (1.0 if cream else 0.0), "REPLACE")
        g["len"].add([v.index], 0.35 if face else 0.8, "REPLACE")
    fb = mat_fur("owl_brown", "#5e4330", "#9a7656", "#2e1f15")
    fc = mat_fur("owl_cream", "#e6d2b0", "#f7ead2", "#a68c68")
    for name, grp, mat, n in (("owl_brown", "brown", fb, 3000), ("owl_cream", "cream", fc, 1800)):
        ps = add_fur(owl, name, grp, mat, n, 40, 0.011, clump=0.3)
        ps.settings.radius_scale = 0.0006
        ps.settings.object_align_factor = (0, 0.3 * 0.011, -0.7 * 0.011)
        ps.settings.roughness_2 = 0.003
    eye_m = mat_eye("owl_eye", iris="#f2b51c", ring="#5a3a08", radius=0.026)
    cornea = bpy.data.materials["cornea"]
    for sx in (-1, 1):
        c = head + Vector((sx * 0.03, -0.058, 0.005))
        d = Vector((sx * 0.25, -1, 0)).normalized()
        rot = Vector((0, -1, 0)).rotation_difference(d).to_euler()
        e = uv_sphere("OwlEye", tuple(c), 0.021, eye_m, seg=32)
        e.rotation_euler = rot
        k = uv_sphere("OwlCornea", tuple(c + d * 0.002), 0.022, cornea, seg=32)
        k.rotation_euler = rot
    beak = mat_leather("beak", "#d9c48a", 0.35)
    bpy.ops.mesh.primitive_cone_add(radius1=0.012, depth=0.028, location=head + Vector((0, -0.072, -0.018)), vertices=24)
    bk = bpy.context.active_object
    bk.rotation_euler = (math.radians(110), 0, 0)
    bk.data.materials.append(beak)
    bpy.ops.object.shade_smooth()
    talon = mat_skin("talon", "#cdb37a")
    for sx in (-1, 1):
        uv_sphere("Foot", tuple(base + Vector((sx * 0.025, -0.03, -0.072))), 0.014, talon, (1.0, 1.4, 0.6), seg=16)


# ----------------------------------------------------------------------------- stage and render

def stage():
    m, nt, out = node_mat("cyc")
    b = principled(nt, "#b9c2cf", 0.9)
    nt.links.new(b.outputs[0], out.inputs[0])
    bm = bmesh.new()
    # cyclorama: floor curving up into a back wall
    prof = []
    for k in range(13):
        a = k / 12 * math.pi / 2
        prof.append((0.0, 1.5 + 0.8 * math.sin(a) if False else 1.2 + 0.8 * (1 - math.cos(a)) * 0 + 0.8 * math.sin(a), 0.8 * (1 - math.cos(a))))
    verts = []
    for x in (-6, 6):
        row = []
        for (_, y, z) in [(0, -6, 0)] + prof + [(0, 2.0, 5)]:
            row.append(bm.verts.new((x, y, z)))
        verts.append(row)
    for j in range(len(verts[0]) - 1):
        bm.faces.new((verts[0][j], verts[1][j], verts[1][j + 1], verts[0][j + 1]))
    cyc = obj_from_bmesh("Cyc", bm, m)
    w = bpy.data.worlds.new("w")
    scene.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = hexc("#9fb0c8")
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.2

    def light(name, loc, energy, size, color, target=(0, 0, 0.75)):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = energy
        ld.size = size
        ld.color = hexc(color)[:3]
        o = bpy.data.objects.new(name, ld)
        o.location = loc
        o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(o)
    light("key", (-2.2, -2.6, 2.8), 300, 1.6, "#fff1de")
    light("fill", (2.6, -2.2, 1.4), 60, 2.5, "#dfe8ff")
    light("rimL", (-1.6, 2.2, 2.2), 260, 1.0, "#ffe2c0")
    light("rimR", (1.8, 2.0, 1.8), 220, 1.0, "#cfe0ff")


def camera(name, yaw, target_z, dist, lens, height):
    cam = bpy.data.objects.get("cam")
    if cam is None:
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
    cam.data.lens = lens
    a = math.radians(yaw)
    cam.location = (math.sin(a) * dist, -math.cos(a) * dist, height)
    cam.rotation_euler = (Vector((0, 0, target_z)) - cam.location).to_track_quat("-Z", "Y").to_euler()


def render(path, w, h):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Base Contrast"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    import time
    T0 = time.time()
    body = build_body()
    print("T body", time.time() - T0)
    hands = build_hands()
    region_weights(body)
    print("T weights", time.time() - T0)
    furs = [
        ("rust", mat_fur("fur_rust", "#b8471c", "#e8823c", "#5a1f0c"), 9000, 0.03),
        ("cream", mat_fur("fur_cream", "#f1e6d2", "#fffaf0", "#c9b393"), 4000, 0.03),
        ("dark", mat_fur("fur_dark", "#3a1d12", "#5e3424", "#1a0c08"), 5000, 0.03),
        ("ochre", mat_fur("fur_ochre", "#d98a45", "#f4b878", "#8a4a1c"), 2200, 0.03),
    ]
    for name, mat, count, ln in furs:
        add_fur(body, name, name, mat, count, 70, ln)
    build_jacket(body)
    build_shorts(body)
    build_belt_and_gear()
    build_boots()
    build_scarf()
    build_goggles()
    build_eyes()
    build_owl()
    stage()
    print("T built", time.time() - T0)
    os.makedirs(OUT, exist_ok=True)
    shots = {
        "front": (0, 0.72, 4.2, 50, 0.95, 900, 1200),
        "three": (-35, 0.72, 4.2, 50, 1.05, 900, 1200),
        "side": (-90, 0.72, 4.2, 50, 0.95, 900, 1200),
        "face": (-25, 1.08, 1.7, 70, 1.2, 1000, 1000),
    }
    for v in VIEWS:
        yaw, tz, dist, lens, hgt, w, h = shots[v]
        camera(v, yaw, tz, dist, lens, hgt)
        render(os.path.join(OUT, "hero_%s.png" % v), w, h)
    print("done")

"""
Kael — JRPG hack-and-slash hero, built 100% procedurally with Blender (bpy).

Usage (Blender 4.4+/5.x, or the `bpy` pip module):
    blender -b -P hero/blender/build_hero.py -- [--render sheet|full|none]
    python3 hero/blender/build_hero.py --render full

Outputs:
    hero/hero.glb            rigged + animated character (glTF binary, 7 clips)
    hero/blender/hero.blend  Blender scene (toon shading, outline, NLA clips)
    hero/preview/...         rendered frames (when --render is sheet/full)

The animation is authored as pose functions (key poses + splines for attacks,
procedural cycles for idle/run), solved with a tiny FK/IK rig solver and baked
per frame, with verlet-rope secondary motion for scarf, ponytail and coat tails.
"""
import bpy, bmesh, sys, os, math
from math import sin, cos, pi, radians, sqrt
from mathutils import Vector, Matrix, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
HERO = os.path.dirname(HERE)
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
RENDER = argv[argv.index("--render") + 1] if "--render" in argv else "none"
ONLY = argv[argv.index("--only") + 1].split(",") if "--only" in argv else None
FPS = 30

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS

# ----------------------------------------------------------------------------
# Palette
# ----------------------------------------------------------------------------
PALETTE = {
    "skin":   (1.00, 0.80, 0.66),
    "hair":   (0.16, 0.30, 0.62),
    "tunic":  (0.96, 0.93, 0.84),
    "navy":   (0.11, 0.14, 0.30),
    "scarf":  (0.86, 0.13, 0.16),
    "leather": (0.42, 0.24, 0.13),
    "gold":   (1.00, 0.74, 0.20),
    "steel":  (0.78, 0.90, 1.00),
    "dark":   (0.06, 0.06, 0.12),
    "iris":   (0.10, 0.72, 0.78),
    "white":  (1.00, 1.00, 1.00),
    "mouth":  (0.62, 0.22, 0.22),
}
MAT_NAMES = list(PALETTE.keys())


def srgb_to_lin(c):
    return tuple(((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in c)


def reset_tree(mat):
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    nt.nodes.clear()
    return nt


def make_pbr(name):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    nt = reset_tree(mat)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    col = srgb_to_lin(PALETTE[name]) + (1.0,)
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = 0.35 if name in ("steel", "gold") else 0.9
    bsdf.inputs["Metallic"].default_value = 0.6 if name in ("steel", "gold") else 0.0
    if name == "steel":
        bsdf.inputs["Emission Color"].default_value = srgb_to_lin((0.25, 0.6, 1.0)) + (1.0,)
        bsdf.inputs["Emission Strength"].default_value = 0.35
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    mat.diffuse_color = col
    return mat


def make_toon(mat, flat=False):
    """Cel shading for EEVEE renders: N.L -> stepped ramp -> emission."""
    name = mat.name
    nt = reset_tree(mat)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emi = nt.nodes.new("ShaderNodeEmission")
    base = srgb_to_lin(PALETTE[name]) + (1.0,)
    if flat:
        emi.inputs[0].default_value = base
    else:
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        dot = nt.nodes.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        dot.inputs[1].default_value = LIGHT_DIR
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        e = ramp.color_ramp.elements
        e[0].position = 0.0
        e[0].color = (0.58, 0.56, 0.74, 1)       # cool shadow tint
        e[1].position = 0.08
        e[1].color = (1, 1, 1, 1)
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[6].default_value = base
        nt.links.new(geo.outputs["Normal"], dot.inputs[0])
        nt.links.new(dot.outputs["Value"], ramp.inputs[0])
        nt.links.new(ramp.outputs[0], mix.inputs[7])
        nt.links.new(mix.outputs[2], emi.inputs[0])
    nt.links.new(emi.outputs[0], out.inputs[0])


MATS = [make_pbr(n) for n in MAT_NAMES]
MI = {n: i for i, n in enumerate(MAT_NAMES)}

# ----------------------------------------------------------------------------
# Mesh builder (pure python lists -> one skinned mesh)
# ----------------------------------------------------------------------------
VERTS, FACES, FMAT, FSMOOTH, VW = [], [], [], [], []


def add_vert(p, w):
    VERTS.append(tuple(p))
    VW.append(w)
    return len(VERTS) - 1


def add_face(idx, mat, smooth=True):
    FACES.append(tuple(idx))
    FMAT.append(MI[mat])
    FSMOOTH.append(smooth)


def tube(rings, mat, segs=10, caps=(True, True), smooth=True):
    """rings: list of dict(c, u, v, w). Cross-section = c + u cos a + v sin a."""
    loops = []
    for r in rings:
        loop = []
        for j in range(segs):
            a = 2 * pi * j / segs
            loop.append(add_vert(r["c"] + r["u"] * cos(a) + r["v"] * sin(a), r["w"]))
        loops.append(loop)
    for a, b in zip(loops, loops[1:]):
        for j in range(segs):
            k = (j + 1) % segs
            add_face((a[j], a[k], b[k], b[j]), mat, smooth)
    if caps[0]:
        c = add_vert(rings[0]["c"], rings[0]["w"])
        for j in range(segs):
            add_face((c, loops[0][(j + 1) % segs], loops[0][j]), mat, smooth)
    if caps[1]:
        c = add_vert(rings[-1]["c"], rings[-1]["w"])
        for j in range(segs):
            add_face((c, loops[-1][j], loops[-1][(j + 1) % segs]), mat, smooth)


def ellipsoid(center, radii, w, mat, rot=None, segs=14, rows=9, fn=None):
    center = Vector(center)
    rot = rot or Matrix.Identity(3)
    grid = []
    for i in range(rows + 1):
        th = pi * i / rows
        row = []
        for j in range(segs):
            ph = 2 * pi * j / segs
            if i in (0, rows) and j > 0:
                row.append(row[0])
                continue
            p = Vector((radii[0] * sin(th) * cos(ph), radii[1] * sin(th) * sin(ph), radii[2] * cos(th)))
            p = center + rot @ p
            if fn:
                p = fn(p)
            row.append(add_vert(p, w))
        grid.append(row)
    for i in range(rows):
        for j in range(segs):
            k = (j + 1) % segs
            a, b, c, d = grid[i][j], grid[i][k], grid[i + 1][k], grid[i + 1][j]
            if i == 0:
                add_face((a, c, d), mat)
            elif i == rows - 1:
                add_face((a, b, c), mat)
            else:
                add_face((a, b, c, d), mat)


def rz(z, rx, ry, w, cx=0.0, cy=0.0):
    return dict(c=Vector((cx, cy, z)), u=Vector((rx, 0, 0)), v=Vector((0, ry, 0)), w=w)


def rx_(x, r, w, z=1.17, ry=None):
    return dict(c=Vector((x, 0, z)), u=Vector((0, r, 0)), v=Vector((0, 0, ry or r)), w=w)


def spike(base, tip, r, w, mat, bend=(0, 0, 0), segs=7):
    base, tip = Vector(base), Vector(tip)
    ax = (tip - base).normalized()
    side = ax.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(ax)
    rings = []
    for t, k in ((0.0, 1.0), (0.3, 0.85), (0.65, 0.5), (0.9, 0.18), (1.0, 0.02)):
        c = base.lerp(tip, t) + Vector(bend) * (4 * t * (1 - t))
        rings.append(dict(c=c, u=side * r * k, v=up * r * k, w=w))
    tube(rings, mat, segs)


def ribbon(start, direction, length, bones, seg_len, hw0, hw1, wide, thin, mat, thick=0.009, step=None):
    """Flat strip weighted along a bone chain (bones split every seg_len)."""
    direction = Vector(direction).normalized()
    step = step or seg_len / 2
    n = int(round(length / step))
    rings = []
    for i in range(n + 1):
        d = i * step
        f = d / seg_len
        a = min(int(f), len(bones) - 1)
        frac = f - int(f)
        if i > 0 and frac < 1e-6 and int(f) <= len(bones) - 1 and int(f) >= 1:
            w = {bones[a - 1]: 0.5, bones[a]: 0.5}
        else:
            w = {bones[a]: 1.0}
        t = d / length
        hw = hw0 + (hw1 - hw0) * t
        bulge = 1.0 + 0.25 * sin(pi * min(t * 1.3, 1.0))
        rings.append(dict(c=Vector(start) + direction * d, u=Vector(wide) * hw * bulge,
                          v=Vector(thin) * thick, w=w))
    tube(rings, mat, 6)


# ---- body -------------------------------------------------------------------
H, SP, CH, NK, HD = "hips", "spine", "chest", "neck", "head"

# torso (tunic)
tube([
    rz(0.795, 0.128, 0.098, {H: 1}),
    rz(0.83, 0.132, 0.100, {H: 1}),
    rz(0.89, 0.122, 0.092, {H: 0.8, SP: 0.2}),
    rz(0.94, 0.108, 0.082, {H: 0.5, SP: 0.5}),
    rz(1.00, 0.108, 0.082, {SP: 1}),
    rz(1.08, 0.128, 0.092, {SP: 0.5, CH: 0.5}),
    rz(1.15, 0.148, 0.097, {CH: 1}),
    rz(1.205, 0.135, 0.088, {CH: 1}),
    rz(1.24, 0.065, 0.058, {CH: 0.7, NK: 0.3}),
], "tunic", 14)
# hem trim + belt + buckle + chest gem
tube([rz(0.79, 0.131, 0.101, {H: 1}), rz(0.80, 0.137, 0.105, {H: 1}),
      rz(0.825, 0.137, 0.105, {H: 1}), rz(0.835, 0.131, 0.100, {H: 1})], "navy", 14)
tube([rz(0.905, 0.118, 0.089, {H: 0.7, SP: 0.3}), rz(0.915, 0.127, 0.097, {H: 0.7, SP: 0.3}),
      rz(0.955, 0.120, 0.092, {H: 0.5, SP: 0.5}), rz(0.965, 0.106, 0.081, {H: 0.5, SP: 0.5})], "leather", 14)
ellipsoid((0, -0.097, 0.935), (0.032, 0.014, 0.028), {H: 0.6, SP: 0.4}, "gold", segs=10, rows=6)
ellipsoid((0, -0.094, 1.135), (0.024, 0.014, 0.030), {CH: 1}, "iris", segs=10, rows=6)
ellipsoid((0, -0.090, 1.135), (0.034, 0.012, 0.040), {CH: 1}, "gold", segs=10, rows=6)
# navy collar stripe down the front
tube([dict(c=Vector((0, -0.088, 1.20)), u=Vector((0.022, 0, 0)), v=Vector((0, 0.012, 0)), w={CH: 1}),
      dict(c=Vector((0, -0.097, 1.15)), u=Vector((0.022, 0, 0)), v=Vector((0, 0.012, 0)), w={CH: 1}),
      dict(c=Vector((0, -0.093, 1.08)), u=Vector((0.022, 0, 0)), v=Vector((0, 0.012, 0)), w={SP: 0.5, CH: 0.5}),
      dict(c=Vector((0, -0.083, 0.99)), u=Vector((0.022, 0, 0)), v=Vector((0, 0.012, 0)), w={SP: 1}),
      dict(c=Vector((0, -0.083, 0.96)), u=Vector((0.022, 0, 0)), v=Vector((0, 0.012, 0)), w={SP: 0.6, H: 0.4})],
     "navy", 6)

# neck
tube([rz(1.21, 0.042, 0.042, {CH: 0.5, NK: 0.5}), rz(1.27, 0.040, 0.040, {NK: 1}),
      rz(1.32, 0.040, 0.040, {NK: 0.4, HD: 0.6})], "skin", 8)

for S, sx in (("L", 1), ("R", -1)):
    TH, SH, FT = "thigh." + S, "shin." + S, "foot." + S
    UA, FA, HA = "upper_arm." + S, "forearm." + S, "hand." + S
    x = 0.09 * sx
    # leg (pants)
    tube([
        rz(0.87, 0.078, 0.082, {H: 1}, x),
        rz(0.80, 0.086, 0.088, {H: 0.5, TH: 0.5}, x),
        rz(0.72, 0.082, 0.084, {TH: 1}, x),
        rz(0.58, 0.070, 0.072, {TH: 1}, x),
        rz(0.48, 0.062, 0.064, {TH: 0.8, SH: 0.2}, x),
        rz(0.44, 0.061, 0.063, {TH: 0.5, SH: 0.5}, x),
        rz(0.40, 0.060, 0.062, {TH: 0.2, SH: 0.8}, x),
        rz(0.30, 0.058, 0.060, {SH: 1}, x),
    ], "navy", 10)
    # knee guard
    ellipsoid((x, -0.05, 0.445), (0.042, 0.03, 0.05), {TH: 0.5, SH: 0.5}, "gold", segs=8, rows=6)
    # boot
    tube([
        rz(0.385, 0.060, 0.062, {SH: 1}, x),
        rz(0.375, 0.076, 0.078, {SH: 1}, x),
        rz(0.335, 0.072, 0.074, {SH: 1}, x),
        rz(0.20, 0.062, 0.064, {SH: 1}, x),
        rz(0.10, 0.058, 0.060, {SH: 0.6, FT: 0.4}, x),
        rz(0.045, 0.058, 0.064, {FT: 1}, x),
        rz(0.0, 0.052, 0.058, {FT: 1}, x),
    ], "leather", 10)
    ellipsoid((x, -0.075, 0.042), (0.058, 0.12, 0.045), {FT: 1}, "leather", segs=10, rows=7,
              fn=lambda p: Vector((p.x, p.y, max(p.z, 0.0))))
    # shoulder + sleeve
    ellipsoid((0.165 * sx, 0, 1.17), (0.072, 0.07, 0.068), {CH: 0.4, UA: 0.6}, "tunic", segs=10, rows=7)
    tube([
        rx_(0.15 * sx, 0.060, {CH: 0.5, UA: 0.5}),
        rx_(0.20 * sx, 0.066, {UA: 1}),
        rx_(0.28 * sx, 0.062, {UA: 1}),
        rx_(0.345 * sx, 0.064, {UA: 1}),
        rx_(0.36 * sx, 0.050, {UA: 1}),
    ], "tunic", 10)
    tube([rx_(0.335 * sx, 0.066, {UA: 1}), rx_(0.35 * sx, 0.069, {UA: 1}),
          rx_(0.365 * sx, 0.066, {UA: 1})], "navy", 10)
    # arm skin
    tube([
        rx_(0.32 * sx, 0.044, {UA: 1}),
        rx_(0.38 * sx, 0.043, {UA: 0.8, FA: 0.2}),
        rx_(0.41 * sx, 0.044, {UA: 0.5, FA: 0.5}),
        rx_(0.44 * sx, 0.043, {UA: 0.2, FA: 0.8}),
        rx_(0.50 * sx, 0.044, {FA: 1}),
    ], "skin", 8)
    # bracer + glove
    tube([
        rx_(0.465 * sx, 0.044, {FA: 1}),
        rx_(0.475 * sx, 0.058, {FA: 1}),
        rx_(0.50 * sx, 0.055, {FA: 1}),
        rx_(0.60 * sx, 0.044, {FA: 1}),
        rx_(0.635 * sx, 0.042, {FA: 0.5, HA: 0.5}),
    ], "leather", 10)
    tube([rx_(0.468 * sx, 0.056, {FA: 1}), rx_(0.478 * sx, 0.062, {FA: 1}),
          rx_(0.492 * sx, 0.060, {FA: 1}), rx_(0.50 * sx, 0.054, {FA: 1})], "gold", 10)
    ellipsoid((0.68 * sx, 0, 1.17), (0.052, 0.046, 0.042), {HA: 1}, "leather", segs=10, rows=7)
    # coat tails (rope bones)
    ribbon((0.068 * sx, 0.094, 0.875), (0, 0, -1), 0.36, ["tail.%s1" % S, "tail.%s2" % S], 0.18,
           0.062, 0.02, (1, 0, 0), (0, 1, 0), "tunic")

# asymmetric pauldron on the left shoulder
ellipsoid((0.19, 0, 1.205), (0.095, 0.085, 0.062), {CH: 0.45, "upper_arm.L": 0.55}, "navy", segs=12, rows=7)
ellipsoid((0.19, 0, 1.19), (0.103, 0.092, 0.035), {CH: 0.45, "upper_arm.L": 0.55}, "gold", segs=12, rows=6)

# ---- head ---------------------------------------------------------------------
HC = Vector((0, -0.005, 1.455))
HR = (0.165, 0.170, 0.175)


def chin(p):
    if p.z < HC.z:
        k = ((HC.z - p.z) / HR[2]) ** 1.6
        p = Vector((p.x * (1 - 0.30 * k), p.y + 0.012 * k, p.z))
    return p


def face_y(x, z):
    p = chin(Vector((x, 0, z)))
    t = 1 - (x / HR[0]) ** 2 - ((z - HC.z) / HR[2]) ** 2
    return HC.y - HR[1] * sqrt(max(t, 0)) + (p.y)


ellipsoid(HC, HR, {HD: 1}, "skin", segs=20, rows=14, fn=chin)
for sx in (1, -1):
    ellipsoid((0.162 * sx, 0.01, 1.435), (0.02, 0.03, 0.04), {HD: 1}, "skin", segs=8, rows=6)
    # eyes: sclera, iris, pupil, highlight, lash, brow — thin shells on the face
    ex, ez = 0.068 * sx, 1.432
    yaw = radians(25 * sx)
    R = Matrix.Rotation(yaw, 3, "Z")
    n = R @ Vector((0, -1, 0))
    ec = Vector((ex, face_y(ex, ez) + 0.004, ez))
    ellipsoid(ec, (0.035, 0.010, 0.047), {HD: 1}, "white", R, 12, 8)
    ic = ec + n * 0.004 + Vector((-0.004 * sx, 0, -0.004))
    ellipsoid(ic, (0.026, 0.010, 0.038), {HD: 1}, "iris", R, 12, 8)
    ellipsoid(ic + n * 0.004 + Vector((0, 0, -0.004)), (0.014, 0.009, 0.024), {HD: 1}, "dark", R, 10, 6)
    ellipsoid(ic + n * 0.009 + Vector((0.009, 0, 0.016)), (0.008, 0.006, 0.010), {HD: 1}, "white", R, 8, 5)
    tilt = Matrix.Rotation(radians(-10 * sx), 3, "Y")
    ellipsoid(ec + n * 0.004 + Vector((0.002 * sx, 0, 0.042)), (0.040, 0.011, 0.011), {HD: 1}, "dark", R @ tilt, 10, 6)
    tilt = Matrix.Rotation(radians(16 * sx), 3, "Y")
    ellipsoid(Vector((ex, face_y(ex, ez + 0.078) - 0.002, ez + 0.078)), (0.036, 0.008, 0.007), {HD: 1}, "hair",
              R @ tilt, 10, 6)
ellipsoid((0, face_y(0, 1.352) - 0.001, 1.352), (0.016, 0.006, 0.0045), {HD: 1}, "mouth", None, 8, 5)

# hair: cap + spikes
HAIRC = Vector((0, 0.032, 1.482))
ellipsoid(HAIRC, (0.181, 0.182, 0.176), {HD: 1}, "hair", segs=18, rows=12)
for x, tz, r in ((-0.118, 1.43, 0.05), (-0.06, 1.475, 0.052), (0.0, 1.49, 0.05), (0.062, 1.47, 0.052), (0.12, 1.435, 0.05)):
    spike((x * 0.85, -0.105, 1.615), (x * 1.18 + 0.012, -0.186 + abs(x) * 0.25, tz), r, {HD: 1}, "hair",
          bend=(0, -0.035, 0.0))
for sx in (1, -1):
    spike((0.15 * sx, -0.03, 1.55), (0.172 * sx, -0.085, 1.30), 0.045, {HD: 1}, "hair", bend=(0.012 * sx, -0.01, 0))
    spike((0.155 * sx, 0.04, 1.52), (0.19 * sx, 0.07, 1.33), 0.045, {HD: 1}, "hair", bend=(0.02 * sx, 0.02, 0))
SPIKES = [(0, 62, .20), (38, 50, .19), (-38, 50, .19), (78, 38, .17), (-78, 38, .17), (0, 28, .20), (36, 14, .18),
          (-36, 14, .18), (72, 2, .15), (-72, 2, .15), (0, 86, .17), (150, 62, .15), (-150, 62, .15),
          (112, 60, .16), (-112, 60, .16), (18, -12, .15), (-18, -12, .15)]
for az, el, ln in SPIKES:
    a, e = radians(az), radians(el)
    d = Vector((sin(a) * cos(e), cos(a) * cos(e), sin(e)))
    sweep = Vector((0, 0.07, -0.02)) if abs(az) < 100 else Vector((0, -0.03, 0.03))
    spike(HAIRC + d * 0.11, HAIRC + d * (0.17 + ln * 0.75) + sweep, 0.072, {HD: 1}, "hair", bend=sweep * 0.3)
# ponytail (rope bones)
PONY0, PONYD = Vector((0, 0.17, 1.50)), Vector((0, 0.6, -0.8)).normalized()
rings = []
for i, r in enumerate((0.038, 0.05, 0.05, 0.045, 0.036, 0.024, 0.006)):
    d = i * 0.05
    f = d / 0.10
    a = min(int(f), 2)
    w = {"pony%d" % (a + 1): 1.0} if (f - int(f)) > 1e-6 or a == 0 or int(f) > 2 else \
        {"pony%d" % a: 0.5, "pony%d" % (a + 1): 0.5}
    rings.append(dict(c=PONY0 + PONYD * d, u=Vector((r, 0, 0)), v=Vector((0, 0.8, 0.6)) * r, w=w))
tube(rings, "hair", 8)
ellipsoid(PONY0 + PONYD * 0.012, (0.042, 0.03, 0.042), {HD: 1}, "gold", segs=8, rows=6)

# scarf: neck wrap + long tail (rope bones)
tube([rz(1.195, 0.07, 0.065, {CH: 0.7, NK: 0.3}), rz(1.215, 0.10, 0.092, {CH: 0.7, NK: 0.3}),
      rz(1.262, 0.102, 0.094, {CH: 0.5, NK: 0.5}), rz(1.292, 0.07, 0.066, {CH: 0.4, NK: 0.6})], "scarf", 12)
ellipsoid((0.045, 0.085, 1.245), (0.04, 0.035, 0.038), {CH: 0.6, NK: 0.4}, "scarf", segs=8, rows=6)
SCARF0 = Vector((0.045, 0.09, 1.245))
ribbon(SCARF0, (0, 1, 0), 0.60, ["scarf1", "scarf2", "scarf3", "scarf4"], 0.15, 0.05, 0.03, (1, 0, 0), (0, 0, 1),
       "scarf", thick=0.010)

# sword (weapon bone, flat shaded) — blade points -Y in the T-pose
WP = "weapon"
HX = -0.68


def ry_(y, hw, ht):
    return dict(c=Vector((HX, y, 1.17)), u=Vector((hw, 0, 0)), v=Vector((0, 0, ht)), w={WP: 1})


tube([ry_(0.075, 0.016, 0.016), ry_(-0.075, 0.014, 0.014)], "dark", 8)
ellipsoid((HX, 0.09, 1.17), (0.026, 0.026, 0.026), {WP: 1}, "gold", segs=8, rows=6)
tube([ry_(-0.07, 0.02, 0.02), ry_(-0.078, 0.095, 0.026), ry_(-0.098, 0.105, 0.022), ry_(-0.106, 0.03, 0.015)],
     "gold", 8, smooth=False)
ellipsoid((HX, -0.088, 1.17), (0.022, 0.016, 0.03), {WP: 1}, "iris", segs=8, rows=6)
tube([ry_(-0.10, 0.042, 0.010), ry_(-0.16, 0.050, 0.011), ry_(-0.70, 0.044, 0.009), ry_(-0.80, 0.03, 0.007),
      ry_(-0.88, 0.002, 0.002)], "steel", 4, smooth=False)

# ----------------------------------------------------------------------------
# Armature
# ----------------------------------------------------------------------------
BONES = [  # name, parent, head, tail, deform
    ("root", None, (0, 0, 0), (0, 0.25, 0)),
    ("hips", "root", (0, 0, 0.84), (0, 0, 0.94)),
    ("spine", "hips", (0, 0, 0.94), (0, 0, 1.08)),
    ("chest", "spine", (0, 0, 1.08), (0, 0, 1.23)),
    ("neck", "chest", (0, 0, 1.23), (0, 0, 1.31)),
    ("head", "neck", (0, 0, 1.31), (0, 0, 1.62)),
]
for S, sx in (("L", 1), ("R", -1)):
    BONES += [
        ("upper_arm." + S, "chest", (0.17 * sx, 0, 1.17), (0.41 * sx, 0, 1.17)),
        ("forearm." + S, "upper_arm." + S, (0.41 * sx, 0, 1.17), (0.63 * sx, 0, 1.17)),
        ("hand." + S, "forearm." + S, (0.63 * sx, 0, 1.17), (0.73 * sx, 0, 1.17)),
        ("thigh." + S, "hips", (0.09 * sx, 0, 0.82), (0.09 * sx, 0, 0.44)),
        ("shin." + S, "thigh." + S, (0.09 * sx, 0, 0.44), (0.09 * sx, 0, 0.08)),
        ("foot." + S, "shin." + S, (0.09 * sx, 0, 0.08), (0.09 * sx, -0.16, 0.02)),
        ("tail.%s1" % S, "hips", (0.068 * sx, 0.094, 0.875), (0.068 * sx, 0.094, 0.695)),
        ("tail.%s2" % S, "tail.%s1" % S, (0.068 * sx, 0.094, 0.695), (0.068 * sx, 0.094, 0.515)),
    ]
BONES.append(("weapon", "hand.R", (HX, 0, 1.17), (HX, -0.25, 1.17)))
for i in range(4):
    BONES.append(("scarf%d" % (i + 1), "chest" if i == 0 else "scarf%d" % i,
                  tuple(SCARF0 + Vector((0, 0.15 * i, 0))), tuple(SCARF0 + Vector((0, 0.15 * (i + 1), 0)))))
for i in range(3):
    BONES.append(("pony%d" % (i + 1), "head" if i == 0 else "pony%d" % i,
                  tuple(PONY0 + PONYD * 0.10 * i), tuple(PONY0 + PONYD * 0.10 * (i + 1))))

arm_data = bpy.data.armatures.new("HeroRig")
arm = bpy.data.objects.new("Hero", arm_data)
scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for name, parent, head, tail in BONES:
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = head, tail
    if parent:
        eb.parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")
arm_data.display_type = "STICK"
PARENT = {b[0]: b[1] for b in BONES}
RH = {b[0]: Vector(b[2]) for b in BONES}
RT = {b[0]: Vector(b[3]) for b in BONES}
RQ = {b.name: b.matrix_local.to_3x3().to_quaternion() for b in arm_data.bones}

mesh = bpy.data.meshes.new("HeroMesh")
mesh.from_pydata(VERTS, [], FACES)
for m in MATS:
    mesh.materials.append(m)
mesh.polygons.foreach_set("material_index", FMAT)
mesh.polygons.foreach_set("use_smooth", FSMOOTH)
bm = bmesh.new()
bm.from_mesh(mesh)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(mesh)
bm.free()
mesh.update()
body = bpy.data.objects.new("HeroBody", mesh)
scene.collection.objects.link(body)
body.parent = arm
vgs = {b[0]: body.vertex_groups.new(name=b[0]) for b in BONES}
for i, w in enumerate(VW):
    tot = sum(w.values())
    for bn, val in w.items():
        vgs[bn].add([i], val / tot, "REPLACE")
body.modifiers.new("Armature", "ARMATURE").object = arm
print("mesh: %d verts, %d faces" % (len(VERTS), len(FACES)))

# ----------------------------------------------------------------------------
# Rig solver: pose dict -> per-bone world deltas -> local quaternions
# ----------------------------------------------------------------------------
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def V(side, fwd, up):
    """Character space: +side = character's left, +fwd = facing direction."""
    return Vector((side, -fwd, up))


def eul(pitch, lean, turn):
    """Degrees. pitch>0 bows forward, lean>0 leans left, turn>0 turns left."""
    return (Matrix.Rotation(radians(turn), 3, "Z") @ Matrix.Rotation(radians(pitch), 3, "X")
            @ Matrix.Rotation(radians(lean), 3, "Y")).to_quaternion()


def arc(a, b):
    return a.normalized().rotation_difference(b.normalized())


def frame(d, axis):
    y = d.normalized()
    x = (axis - y * axis.dot(y)).normalized()
    z = x.cross(y)
    return Matrix((x, y, z)).transposed()


FREST_INV = frame(Vector((0, 0, -1)), X).transposed()
L1 = (RT["thigh.L"] - RH["thigh.L"]).length
L2 = (RT["shin.L"] - RH["shin.L"]).length

CHAINS = [  # bones, parent, stiffness, collision plane (parent-local min y), gravity scale
    (["scarf1", "scarf2", "scarf3", "scarf4"], "chest", 0.0, 0.125, 0.55),
    (["pony1", "pony2", "pony3"], "head", 0.10, 0.17, 1.0),
    (["tail.L1", "tail.L2"], "hips", 0.02, 0.105, 1.0),
    (["tail.R1", "tail.R2"], "hips", 0.02, 0.105, 1.0),
]


class Ropes:
    def __init__(self):
        self.pts = None

    def step(self, D, pos, wind, t):
        dt = 1.0 / FPS
        sub = 4
        h = dt / sub
        if self.pts is None:
            self.pts, self.prev = [], []
            for bones, par, *_ in CHAINS:
                p = [pos[par] + D[par] @ (RH[bones[0]] - RH[par])]
                for b in bones:
                    p.append(p[-1] + D[par] @ (RT[b] - RH[b]))
                self.pts.append(p)
                self.prev.append([q.copy() for q in p])
        out = {}
        for ci, (bones, par, stiff, miny, gsc) in enumerate(CHAINS):
            p, pv = self.pts[ci], self.prev[ci]
            anchor = pos[par] + D[par] @ (RH[bones[0]] - RH[par])
            Dinv = D[par].inverted()
            for s in range(sub):
                tt = t + s * h
                p[0] = anchor
                for i in range(1, len(p)):
                    gust = Vector((sin(tt * 2 * pi * 1.0 + i * 1.3 + ci), 0.6 * sin(tt * 2 * pi * 2.0 + i * 0.9),
                                   0.8 * sin(tt * 2 * pi * 2.0 + i * 1.7 + ci * 2))) * (0.25 * wind.length + 0.6)
                    acc = Vector((0, 0, -9.0 * gsc)) + wind + gust
                    vel = (p[i] - pv[i]) * 0.965
                    pv[i] = p[i].copy()
                    p[i] = p[i] + vel + acc * h * h
                for _ in range(3):
                    for i in range(1, len(p)):
                        b = bones[i - 1]
                        ln = (RT[b] - RH[b]).length
                        if stiff:
                            base = D[par] if i == 1 else None
                            rest_dir = (D[par] @ (RT[b] - RH[b])).normalized()
                            p[i] = p[i].lerp(p[i - 1] + rest_dir * ln, stiff)
                        loc = Dinv @ (p[i] - pos[par])
                        rest_loc = RT[b] - RH[par]
                        if loc.y < miny and loc.z < rest_loc.z + 0.12:
                            loc.y = miny
                            p[i] = pos[par] + D[par] @ loc
                        d = p[i] - p[i - 1]
                        p[i] = p[i - 1] + d.normalized() * ln
            Dp = D[par]
            for i, b in enumerate(bones):
                rest = RT[b] - RH[b]
                Db = arc(Dp @ rest, p[i + 1] - p[i]) @ Dp
                out[b] = Db
                Dp = Db
        return out


def solve(P):
    D, pos = {"root": Quaternion()}, {}
    D["hips"] = eul(*P["hips"])
    pos["hips"] = RH["hips"] + V(*P["hips_pos"])
    for b in ("spine", "chest", "neck", "head"):
        p = PARENT[b]
        D[b] = D[p] @ eul(*P[b])
        pos[b] = pos[p] + D[p] @ (RH[b] - RH[p])
    C = D["chest"]
    for S, sx in (("L", 1), ("R", -1)):
        rest = Vector((sx, 0, 0))
        du, df = V(*P["a%su" % S]), V(*P["a%sf" % S])
        qu = arc(rest, du)
        qf = arc(du, df) @ qu
        qh = qf
        if S == "R":
            qh = arc(qf @ Vector((0, -1, 0)), V(*P["blade"])) @ qf
            # keep the blade's flat side consistent: roll the edge toward the swing plane hint
        D["upper_arm." + S], D["forearm." + S], D["hand." + S] = C @ qu, C @ qf, C @ qh
        # leg IK
        hj = pos["hips"] + D["hips"] @ (RH["thigh." + S] - RH["hips"])
        tgt = V(*P["f" + S])
        axis = Matrix.Rotation(radians(P["k" + S][0]), 3, "Z") @ X
        to = tgt - hj
        dist = min(to.length, (L1 + L2) * 0.999)
        along = to.normalized()
        tgt = hj + along * dist
        a = (L1 * L1 - L2 * L2 + dist * dist) / (2 * dist)
        hgt = sqrt(max(L1 * L1 - a * a, 0.0))
        fwd = along.cross(axis)
        if fwd.length < 1e-4:
            fwd = Vector((0, -1, 0))
        knee = hj + along * a + fwd.normalized() * hgt
        D["thigh." + S] = (frame(knee - hj, axis) @ FREST_INV).to_quaternion()
        D["shin." + S] = (frame(tgt - knee, axis) @ FREST_INV).to_quaternion()
        pitch, yaw = P["f%sr" % S]
        D["foot." + S] = (Matrix.Rotation(radians(yaw), 3, "Z") @ Matrix.Rotation(radians(pitch), 3, "X")).to_quaternion()
    D["weapon"] = D["hand.R"]
    return D, pos


def to_local(D):
    out = {}
    for b, par in PARENT.items():
        if par is None:
            out[b] = Quaternion()
            continue
        out[b] = RQ[b].inverted() @ D[par].inverted() @ D[b] @ RQ[b]
    return out


# ----------------------------------------------------------------------------
# Animation authoring
# ----------------------------------------------------------------------------
P0 = dict(
    hips_pos=(0, 0, -0.11), hips=(6, 0, -24), spine=(3, 0, -6), chest=(4, 0, -8), neck=(-3, 0, 14), head=(-6, 0, 20),
    aLu=(0.45, 0.15, -1), aLf=(0.05, 0.85, -0.1), aRu=(-0.45, -0.25, -1), aRf=(-0.2, 0.8, -0.2),
    blade=(0.25, 0.8, 0.75),
    fL=(0.15, 0.21, 0.08), fLr=(0, 10), kL=(12,), fR=(-0.18, -0.20, 0.08), fRr=(0, -42), kR=(-38,),
)


def K(base=None, **kw):
    p = dict(base or P0)
    p.update(kw)
    return p


def add(p, **kw):
    q = dict(p)
    for k, v in kw.items():
        q[k] = tuple(a + b for a, b in zip(q[k], v))
    return q


def spline(keys):
    """Non-uniform Catmull-Rom (Hermite) over pose dicts. keys: [(frame, pose)]."""
    ts = [k[0] for k in keys]
    names = list(P0.keys())

    def tangent(i, name, c):
        if i == 0 or i == len(keys) - 1:
            return 0.0
        p0, p1, p2 = keys[i - 1][1][name][c], keys[i][1][name][c], keys[i + 1][1][name][c]
        d0, d1 = ts[i] - ts[i - 1], ts[i + 1] - ts[i]
        return ((p1 - p0) / d0 * d1 + (p2 - p1) / d1 * d0) / (d0 + d1)

    def f(fr):
        fr = max(ts[0], min(ts[-1], fr))
        i = max(j for j in range(len(ts) - 1) if ts[j] <= fr)
        h = ts[i + 1] - ts[i]
        u = (fr - ts[i]) / h
        h00, h10 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u
        h01, h11 = -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
        out = {}
        for n in names:
            a, b = keys[i][1][n], keys[i + 1][1][n]
            out[n] = tuple(h00 * a[c] + h10 * h * tangent(i, n, c) + h01 * b[c] + h11 * h * tangent(i + 1, n, c)
                           for c in range(len(a)))
        return out
    return f


def idle(fr, n=60):
    w = 2 * pi * fr / n
    s, s2, c = sin(w), sin(w - 0.9), cos(w)
    return add(P0, hips_pos=(0.004 * c, 0, 0.012 * s), spine=(0.8 * s, 0, 0), chest=(1.6 * s, 0, 0.8 * c),
               head=(-1.2 * s2, 0, 0), aLu=(0.02 * s2, 0, 0.0), aLf=(0, 0, 0.06 * s2),
               aRu=(-0.02 * s2, 0, 0), aRf=(0, 0, 0.05 * s2), blade=(0.03 * c, 0, 0.07 * s2))


def run(fr, n=20):
    ph = fr / n

    def foot(p, sx):
        w = 2 * pi * p
        fwd = 0.36 * sin(w) - 0.05
        lift = max(0.0, cos(w + 0.75))
        up = 0.08 + 0.26 * lift ** 1.3 + 0.03 * max(0.0, cos(w))
        pitch = 62 * max(0.0, cos(w + 1.15)) - 18 * max(0.0, sin(w)) ** 2
        return (0.085 * sx, fwd, up), (pitch, 4 * sx)

    fL, fLr = foot(ph, 1)
    fR, fRr = foot(ph + 0.5, -1)
    w = 2 * pi * ph
    s, c = sin(w), cos(w)
    bob = 0.035 * cos(2 * w + 0.6)
    return dict(
        hips_pos=(0.012 * s, 0.02, -0.10 + bob), hips=(20, -2.5 * s, 9 * s), spine=(5, 2 * s, -7 * s),
        chest=(5, 1.5 * s, -12 * s), neck=(-10, 0, 5 * s), head=(-14 + 1.5 * cos(2 * w), 0, 5 * s),
        aLu=(0.28, -0.55 * s + 0.05, -1), aLf=(0.02, -0.5 * s + 0.75, -0.35 - 0.3 * s),
        aRu=(-0.42, -0.5 + 0.12 * s, -1), aRf=(-0.4, -0.75 + 0.1 * s, -0.55),
        blade=(-0.55 + 0.05 * c, -1, -0.15 + 0.06 * sin(2 * w)),
        fL=fL, fLr=fLr, kL=(4,), fR=fR, fRr=fRr, kR=(-4,))


A1 = spline([
    (0, P0),
    (5, K(hips_pos=(-0.03, -0.05, -0.11), hips=(2, 0, -42), spine=(0, 0, -14), chest=(0, 0, -20), neck=(0, 0, 28),
          head=(-4, 0, 38), aRu=(-0.9, -0.5, 0.15), aRf=(-0.7, -0.6, 0.5), blade=(-0.5, -0.9, 0.35),
          aLu=(0.5, 0.5, -0.6), aLf=(0.1, 1, 0.1), fRr=(8, -45))),
    (7, K(hips_pos=(0.02, 0.10, -0.15), hips=(8, 0, 5), spine=(4, 0, 5), chest=(4, 0, 10), neck=(-2, 0, -4),
          head=(-8, 0, -8), aRu=(-0.6, 0.8, 0.05), aRf=(-0.1, 1, 0.05), blade=(0.3, 1, 0.0),
          aLu=(0.7, -0.2, -0.7), aLf=(0.6, -0.5, -0.2), fL=(0.13, 0.24, 0.08), fR=(-0.15, -0.15, 0.10),
          fRr=(22, -32))),
    (9, K(hips_pos=(0.05, 0.16, -0.17), hips=(10, 0, 30), spine=(5, 0, 12), chest=(5, 0, 18), neck=(0, 0, -20),
          head=(-8, 0, -30), aRu=(0.3, 0.9, -0.15), aRf=(0.9, 0.4, -0.1), blade=(0.9, -0.35, -0.15),
          aLu=(0.6, -0.6, -0.6), aLf=(0.5, -0.8, 0.1), fL=(0.13, 0.26, 0.08), fR=(-0.15, -0.14, 0.11),
          fRr=(28, -30))),
    (13, K(hips_pos=(0.05, 0.15, -0.15), hips=(9, 0, 27), spine=(4, 0, 10), chest=(4, 0, 15), neck=(0, 0, -17),
           head=(-7, 0, -26), aRu=(0.34, 0.85, -0.22), aRf=(0.9, 0.3, -0.18), blade=(0.85, -0.45, -0.22),
           aLu=(0.6, -0.55, -0.65), aLf=(0.5, -0.75, 0.05), fL=(0.13, 0.26, 0.08), fR=(-0.15, -0.14, 0.10),
           fRr=(24, -30))),
    (21, P0),
])

A2 = spline([
    (0, P0),
    (4, K(hips_pos=(0.03, 0.05, -0.15), hips=(6, 0, 25), spine=(4, 0, 10), chest=(4, 0, 15), neck=(0, 0, -18),
          head=(-6, 0, -28), aRu=(0.35, 0.85, -0.3), aRf=(0.9, 0.2, -0.35), blade=(0.8, -0.5, -0.45),
          aLu=(0.6, -0.4, -0.7), aLf=(0.4, -0.6, -0.1), fRr=(15, -30))),
    (6, K(hips_pos=(0.0, 0.10, -0.12), hips=(4, 0, -5), spine=(0, 0, -4), chest=(-2, 0, -6), neck=(0, 0, 4),
          head=(-4, 0, 8), aRu=(-0.5, 0.85, 0.0), aRf=(-0.2, 1, 0.25), blade=(-0.1, 1, 0.5),
          aLu=(0.7, 0.0, -0.6), aLf=(0.5, 0.1, 0.0), fR=(-0.15, -0.02, 0.14), fRr=(20, -20))),
    (8, K(hips_pos=(-0.02, 0.14, -0.17), hips=(-2, 0, -38), spine=(-4, 0, -14), chest=(-6, 0, -20), neck=(0, 0, 25),
          head=(0, 0, 40), aRu=(-0.9, -0.1, 0.5), aRf=(-0.75, -0.35, 0.75), blade=(-0.6, -0.6, 0.8),
          aLu=(0.8, 0.4, -0.5), aLf=(0.6, 0.7, 0.2), fR=(-0.2, 0.2, 0.08), fRr=(0, -18), fL=(0.15, -0.06, 0.1), fLr=(25, 20))),
    (12, K(hips_pos=(-0.02, 0.13, -0.15), hips=(-1, 0, -35), spine=(-3, 0, -12), chest=(-5, 0, -17), neck=(0, 0, 22),
           head=(0, 0, 37), aRu=(-0.9, -0.15, 0.42), aRf=(-0.75, -0.42, 0.68), blade=(-0.62, -0.66, 0.7),
           aLu=(0.8, 0.35, -0.55), aLf=(0.6, 0.65, 0.15), fR=(-0.2, 0.2, 0.08), fRr=(0, -18),
           fL=(0.15, -0.06, 0.1), fLr=(25, 20))),
    (16, K(hips_pos=(-0.01, 0.05, -0.06), fR=(-0.15, -0.04, 0.13), fRr=(12, -30), fL=(0.13, 0.14, 0.08))),
    (20, P0),
])

A3 = spline([
    (0, P0),
    (6, K(hips_pos=(0, -0.04, -0.23), hips=(14, 0, -10), spine=(8, 0, -4), chest=(6, 0, -4), neck=(-8, 0, 6),
          head=(-18, 0, 10), aRu=(-0.5, -0.4, -0.6), aRf=(-0.3, -0.8, 0.2), blade=(-0.2, -1, 0.3),
          aLu=(0.5, 0.3, -0.8), aLf=(0.2, 0.9, -0.2))),
    (11, K(hips_pos=(0, 0.05, 0.30), hips=(-12, 0, 0), spine=(-8, 0, 0), chest=(-10, 0, 0), neck=(4, 0, 0),
           head=(10, 0, 0), aRu=(-0.4, 0.0, 1), aRf=(-0.15, -0.3, 1), blade=(-0.1, -0.45, 1),
           aLu=(0.45, 0.5, 0.6), aLf=(0.1, 0.6, 0.75), fL=(0.12, 0.14, 0.56), fLr=(40, 5), kL=(8,),
           fR=(-0.12, -0.22, 0.66), fRr=(60, -10), kR=(-12,))),
    (14, K(hips_pos=(0, 0.14, -0.27), hips=(22, 0, -5), spine=(14, 0, 0), chest=(12, 0, 0), neck=(-12, 0, 0),
           head=(-24, 0, 5), aRu=(-0.3, 0.9, -0.2), aRf=(-0.05, 1, 0.25), blade=(0.05, 1, 0.6),
           aLu=(0.5, -0.3, -0.7), aLf=(0.7, -0.5, 0.1), fL=(0.16, 0.30, 0.08), fLr=(0, 10), kL=(14,),
           fR=(-0.18, -0.26, 0.09), fRr=(18, -35), kR=(-40,))),
    (19, K(hips_pos=(0, 0.13, -0.24), hips=(20, 0, -5), spine=(12, 0, 0), chest=(10, 0, 0), neck=(-10, 0, 0),
           head=(-21, 0, 5), aRu=(-0.3, 0.9, -0.15), aRf=(-0.05, 1, 0.3), blade=(0.05, 1, 0.68),
           aLu=(0.5, -0.3, -0.7), aLf=(0.7, -0.45, 0.05), fL=(0.16, 0.30, 0.08), fLr=(0, 10), kL=(14,),
           fR=(-0.18, -0.26, 0.09), fRr=(18, -35), kR=(-40,))),
    (30, P0),
])

DASH_POSE = K(hips_pos=(0, 0.10, -0.23), hips=(38, 0, -10), spine=(10, 0, 0), chest=(8, 0, 0), neck=(-18, 0, 4),
              head=(-26, 0, 6), aLu=(0.35, -0.3, -0.9), aLf=(0.3, -0.5, -0.8), aRu=(-0.45, -0.3, -0.9),
              aRf=(-0.4, -0.5, -0.8), blade=(-0.45, -0.6, -0.75), fL=(0.10, 0.38, 0.10), fLr=(-12, 4), kL=(4,),
              fR=(-0.12, -0.45, 0.15), fRr=(55, -10), kR=(-8,))
DASH = spline([
    (0, P0),
    (3, DASH_POSE),
    (9, add(DASH_POSE, hips_pos=(0, 0.02, 0.02), hips=(-3, 0, 0), aLf=(0, -0.1, 0.0), aRf=(0, -0.1, 0.0),
            blade=(0, -0.1, 0.05), fR=(0, 0.03, -0.02))),
    (16, P0),
])

HIT = spline([
    (0, P0),
    (2, K(hips_pos=(0, -0.10, -0.05), hips=(-12, 3, -12), spine=(-10, 0, 5), chest=(-13, 0, 8), neck=(10, 0, 8),
          head=(16, 4, 14), aLu=(0.85, -0.1, -0.5), aLf=(0.75, 0.4, 0.1), aRu=(-0.85, -0.2, -0.4),
          aRf=(-0.8, 0.3, -0.1), blade=(-0.3, 0.6, 0.8), fR=(-0.15, -0.25, 0.08))),
    (5, K(hips_pos=(0, -0.08, -0.10), hips=(-4, 2, -18), spine=(-4, 0, 0), chest=(-4, 0, 0), neck=(-6, 0, 12),
          head=(-10, -3, 20), aLu=(0.7, 0.0, -0.8), aLf=(0.5, 0.6, -0.1), aRu=(-0.7, -0.25, -0.8),
          aRf=(-0.55, 0.5, -0.3), blade=(0.0, 0.9, 0.7), fR=(-0.15, -0.25, 0.08))),
    (9, K(hips_pos=(0, -0.03, -0.09), hips=(6, 0, -22), fR=(-0.15, -0.20, 0.08))),
    (14, P0),
])

CLIPS = [  # name, pose fn, frames, loop, wind (rope drag acceleration, character space)
    ("Idle", idle, 60, True, V(0.6, -2.2, 0)),
    ("Run", run, 20, True, V(0, -13, 2.5)),
    ("Attack1", A1, 21, False, V(0.6, -2.2, 0)),
    ("Attack2", A2, 20, False, V(0.6, -2.2, 0)),
    ("Attack3", A3, 30, False, V(0.6, -2.2, 0)),
    ("Dash", DASH, 16, False, V(0, -9, 1.5)),
    ("Hit", HIT, 14, False, V(0.6, -2.2, 0)),
]

arm.animation_data_create()
bpy.context.view_layer.objects.active = arm
for pb in arm.pose.bones:
    pb.rotation_mode = "QUATERNION"
ACTIONS = {}
for name, fn, nfr, loop, wind in CLIPS:
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    ropes = Ropes()
    # warm up the cloth so the first frame is already settled (loops: steady state)
    warm = [fn(f % nfr) for f in range(nfr * 3)] if loop else [fn(0)] * 45
    for i, P in enumerate(warm):
        D, pos = solve(P)
        ropes.step(D, pos, wind, i / FPS)
    prev = {}
    for f in range(nfr + 1):
        P = fn(f % nfr if loop else f)
        D, pos = solve(P)
        D.update(ropes.step(D, pos, wind, f / FPS))
        loc = to_local(D)
        for pb in arm.pose.bones:
            q = loc[pb.name]
            if pb.name in prev and prev[pb.name].dot(q) < 0:
                q = -q
            prev[pb.name] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f, group=pb.name)
        hp = arm.pose.bones["hips"]
        hp.location = RQ["hips"].inverted() @ V(*P["hips_pos"])
        hp.keyframe_insert("location", frame=f, group="hips")
    ACTIONS[name] = (act, nfr)
    print("clip", name, nfr, "frames")


def use_action(name):
    ad = arm.animation_data
    act = ACTIONS[name][0]
    ad.action = act
    try:
        if ad.action_slot is None and len(act.slots):
            ad.action_slot = act.slots[0]
    except Exception:
        pass


# ----------------------------------------------------------------------------
# Export GLB (one NLA track per clip -> one glTF animation per clip)
# ----------------------------------------------------------------------------
ad = arm.animation_data
ad.action = None
for pb in arm.pose.bones:
    pb.rotation_quaternion = Quaternion()
    pb.location = (0, 0, 0)
for name, (act, nfr) in ACTIONS.items():
    tr = ad.nla_tracks.new()
    tr.name = name
    st = tr.strips.new(name, 0, act)
    st.name = name
    try:
        if st.action_slot is None and len(act.slots):
            st.action_slot = act.slots[0]
    except Exception:
        pass
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
body.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(HERO, "hero.glb"), export_format="GLB", use_selection=True,
                          export_animation_mode="NLA_TRACKS", export_yup=True, export_skins=True,
                          export_def_bones=False, export_optimize_animation_size=False,
                          export_anim_slide_to_zero=True)
print("exported hero.glb")

# ----------------------------------------------------------------------------
# Look-dev for Blender: toon materials, outline, light, camera, ground
# ----------------------------------------------------------------------------
from mathutils import Euler
SUN_ROT = (radians(50), radians(-6), radians(28))
LIGHT_DIR = tuple(Euler(SUN_ROT).to_matrix() @ Vector((0, 0, 1)))
for m in MATS:
    make_toon(m, flat=m.name in ("white", "dark", "iris", "mouth"))
ol = bpy.data.materials.new("outline")
nt = reset_tree(ol)
o = nt.nodes.new("ShaderNodeOutputMaterial")
e = nt.nodes.new("ShaderNodeEmission")
e.inputs[0].default_value = (0.03, 0.02, 0.06, 1)
nt.links.new(e.outputs[0], o.inputs[0])
ol.use_backface_culling = True
mesh.materials.append(ol)
sol = body.modifiers.new("Outline", "SOLIDIFY")
sol.thickness = 0.011
sol.offset = 1.0
sol.use_flip_normals = True
sol.use_rim = False
sol.material_offset = len(mesh.materials)

world = bpy.data.worlds.new("World")
try:
    world.use_nodes = True
except Exception:
    pass
bg = world.node_tree.nodes.get("Background") or world.node_tree.nodes.new("ShaderNodeBackground")
bg.inputs[0].default_value = srgb_to_lin((0.93, 0.90, 0.98)) + (1,)
if not bg.outputs[0].links:
    wo = world.node_tree.nodes.get("World Output") or world.node_tree.nodes.new("ShaderNodeOutputWorld")
    world.node_tree.links.new(bg.outputs[0], wo.inputs[0])
scene.world = world

sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 4.0
sun.rotation_euler = SUN_ROT
scene.collection.objects.link(sun)

gm = bpy.data.meshes.new("Ground")
gm.from_pydata([(-9, -9, 0), (9, -9, 0), (9, 9, 0), (-9, 9, 0)], [], [(0, 1, 2, 3)])
ground = bpy.data.objects.new("Ground", gm)
scene.collection.objects.link(ground)
gmat = bpy.data.materials.new("ground")
nt = reset_tree(gmat)
o = nt.nodes.new("ShaderNodeOutputMaterial")
e = nt.nodes.new("ShaderNodeEmission")
dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
s2r = nt.nodes.new("ShaderNodeShaderToRGB")
ramp = nt.nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.interpolation = "CONSTANT"
ramp.color_ramp.elements[0].color = srgb_to_lin((0.70, 0.66, 0.86)) + (1,)
ramp.color_ramp.elements[1].position = 1.0
ramp.color_ramp.elements[1].color = srgb_to_lin((0.93, 0.90, 0.98)) + (1,)
nt.links.new(dif.outputs[0], s2r.inputs[0])
nt.links.new(s2r.outputs[0], ramp.inputs[0])
nt.links.new(ramp.outputs[0], e.inputs[0])
nt.links.new(e.outputs[0], o.inputs[0])
gm.materials.append(gmat)

cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.lens = 85


def aim(loc, target):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


aim((-3.4, -5.5, 2.0), (0, -0.1, 0.88))
scene.render.engine = "BLENDER_EEVEE"
try:
    scene.eevee.taa_render_samples = 16
except Exception:
    pass
scene.view_settings.view_transform = "Standard"
scene.render.image_settings.file_format = "PNG"

for tr in ad.nla_tracks:
    tr.mute = True
use_action("Idle")
scene.frame_start, scene.frame_end = 0, ACTIONS["Idle"][1]
scene.frame_set(0)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "hero.blend"), compress=True)
print("saved hero.blend")

# ----------------------------------------------------------------------------
# Renders
# ----------------------------------------------------------------------------
STILLS = argv[argv.index("--stills") + 1] if "--stills" in argv else None
if STILLS:
    outdir = argv[argv.index("--out") + 1]
    scene.render.resolution_x = scene.render.resolution_y = 640
    for item in STILLS.split(","):
        name, f = item.split(":")
        use_action(name)
        scene.frame_set(int(f))
        scene.render.filepath = os.path.join(outdir, "%s_%03d.png" % (name, int(f)))
        bpy.ops.render.render(write_still=True)
elif RENDER != "none":
    outdir = os.path.join(HERO, "preview", "frames")
    os.makedirs(outdir, exist_ok=True)
    size, step = (360, 3) if RENDER == "sheet" else (600, 1)
    scene.render.resolution_x = scene.render.resolution_y = size
    if RENDER == "sheet":
        scene.eevee.taa_render_samples = 4
    for name, (act, nfr) in ACTIONS.items():
        if ONLY and name not in ONLY:
            continue
        use_action(name)
        for f in range(0, nfr, step):
            scene.frame_set(f)
            scene.render.filepath = os.path.join(outdir, "%s_%03d.png" % (name, f))
            bpy.ops.render.render(write_still=True)
    if RENDER == "full":
        # hero shots: T-pose front + turnaround of the idle stance
        scene.render.resolution_x, scene.render.resolution_y = 900, 1100
        use_action("Idle")
        scene.frame_set(0)
        for i, ang in enumerate((-28, 35, 150, 215)):
            a = radians(ang)
            aim((6.2 * sin(a), -6.2 * cos(a), 1.7), (0, 0, 0.86))
            scene.render.filepath = os.path.join(HERO, "preview", "turn_%d.png" % i)
            bpy.ops.render.render(write_still=True)
print("done")

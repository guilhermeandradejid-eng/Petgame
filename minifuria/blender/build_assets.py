"""
Mini Fúria: modelagem procedural dos assets no Blender.

Gera todos os carros (em peças destrutíveis) e props low-poly e exporta para ../assets/minicars.glb (projeto Godot).

Uso (Blender instalado):
    blender -b -P build_assets.py
ou com o módulo bpy do pip (pip install bpy):
    python build_assets.py [--render preview.png]

Convenções:
- 1 unidade = 1 metro. A frente dos carros aponta para -Y no Blender (vira +Z no glTF/Three.js).
- Cada carro é um Empty "car_<nome>" com filhos: "<nome>_body" e as rodas "<nome>_wFL/wFR/wRL/wRR"
  (origem no centro do eixo, para o jogo girar e esterçar).
- O material "Paint" é a pintura, o jogo troca a cor por carro.
- Materiais "Headlight"/"Taillight" são emissivos, o jogo aumenta o brilho ao frear/turbo.
"""
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "minicars.glb")

# ---------------------------------------------------------------- cena limpa
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
col = scene.collection

# ---------------------------------------------------------------- materiais
MATS = {}


def hexcol(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    # Blender trabalha em linear
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, 1.0)


def mat(name, color, rough=0.5, metal=0.0, emit=None, strength=1.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = hexcol(color)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit:
        bsdf.inputs["Emission Color"].default_value = hexcol(emit)
        bsdf.inputs["Emission Strength"].default_value = strength
    MATS[name] = m
    return m


M = {
    "paint": mat("Paint", "#e8352b", 0.35, 0.1),
    "paint2": mat("Paint2", "#f4f1ea", 0.4),
    "glass": mat("Glass", "#1c2a3a", 0.08, 0.3),
    "tire": mat("Tire", "#1d1d22", 0.9),
    "rim": mat("Rim", "#c9ccd4", 0.25, 0.85),
    "trim": mat("Trim", "#2b2d33", 0.6),
    "chrome": mat("Chrome", "#e6e8ee", 0.15, 1.0),
    "head": mat("Headlight", "#fff6d8", 0.2, 0, "#fff3c4", 2.0),
    "tail": mat("Taillight", "#ff2a3a", 0.3, 0, "#ff1f30", 1.5),
    "exhaust": mat("Exhaust", "#555a63", 0.3, 0.9),
    "taxi": mat("TaxiSign", "#ffd23a", 0.4, 0, "#ffcf33", 0.8),
    "siren_r": mat("SirenR", "#ff2d4a", 0.3, 0, "#ff2d4a", 2.0),
    "siren_b": mat("SirenB", "#2d7bff", 0.3, 0, "#2d7bff", 2.0),
    "wood": mat("Wood", "#b07a43", 0.8),
    "wood_dark": mat("WoodDark", "#7a5230", 0.85),
    "cone": mat("ConeOrange", "#ff6a1a", 0.5),
    "white": mat("White", "#f6f6f2", 0.5),
    "concrete": mat("Concrete", "#c8c2b6", 0.85),
    "red": mat("BarrierRed", "#e23b33", 0.6),
    "barrel": mat("BarrelBlue", "#2f6fd6", 0.45, 0.3),
    "leaf": mat("Leaf", "#4cbf4f", 0.8),
    "leaf2": mat("Leaf2", "#2f9e5a", 0.8),
    "trunk": mat("Trunk", "#8a5a36", 0.9),
    "rock": mat("Rock", "#9a9da6", 0.9),
    "bldg1": mat("Bldg1", "#f2c66d", 0.8),
    "bldg2": mat("Bldg2", "#7fc8d9", 0.8),
    "bldg3": mat("Bldg3", "#f08a7a", 0.8),
    "roof": mat("Roof", "#4b4f5c", 0.8),
    "window": mat("Window", "#bfe6ff", 0.2, 0, "#cfeeff", 0.6),
    "lamp": mat("LampGlow", "#fff1c1", 0.2, 0, "#ffe9a8", 3.0),
    "metal": mat("Metal", "#6d7380", 0.4, 0.7),
    "ramp": mat("RampYellow", "#ffc629", 0.5),
    "stripe": mat("RampStripe", "#26272d", 0.6),
    "seat": mat("Seat", "#3d3f47", 0.8),
    "well": mat("Well", "#121216", 0.95),
    "rim_dark": mat("RimDark", "#2a2d34", 0.35, 0.8),
    "sidewall": mat("Sidewall", "#2c2c33", 0.85),
    "moss": mat("Moss", "#4f6b2a", 0.95),
    "reed": mat("Reed", "#7a8f3a", 0.85),
    "cattail": mat("Cattail", "#5a3a22", 0.9),
    "deadwood": mat("DeadWood", "#5b4a3c", 0.95),
    "grass_isle": mat("GrassIsle", "#6cc24a", 0.9),
    "earth": mat("Earth", "#8a6a4a", 0.95),
    "balloon_a": mat("BalloonA", "#ff5a4d", 0.6),
    "balloon_b": mat("BalloonB", "#ffd23a", 0.6),
    "balloon_c": mat("BalloonC", "#4db8ff", 0.6),
    "wicker": mat("Wicker", "#a0703c", 0.9),
    "groove": mat("Groove", "#0c0c0f", 0.95),
    "tire_stripe": mat("TireStripe", "#ffd23a", 0.55),
    "lug": mat("LugNut", "#d7dae0", 0.2, 1.0),
}


# ---------------------------------------------------------------- helpers
def new_obj(name, bm, material_list):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m_ in material_list:
        me.materials.append(m_)
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    return ob


def box(name, size, loc, material, bevel=0.0, taper=None, segs=2):
    """Caixa com chanfro opcional. taper=(sx, sy) escala o topo (cabines, para-brisas)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    if taper:
        top = max(v.co.z for v in bm.verts)
        for v in bm.verts:
            if abs(v.co.z - top) < 1e-5:
                v.co.x *= taper[0]
                v.co.y = v.co.y * taper[1] + (taper[2] if len(taper) > 2 else 0)
    ob = new_obj(name, bm, [material])
    ob.location = loc
    if bevel > 0:
        md = ob.modifiers.new("bevel", "BEVEL")
        md.width = bevel
        md.segments = segs
        md.limit_method = "ANGLE"
    return ob


def cyl(name, r, depth, loc, material, verts=16, axis="X", r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts,
                          radius1=r, radius2=r if r2 is None else r2, depth=depth)
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0),
                         matrix=__import__("mathutils").Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0),
                         matrix=__import__("mathutils").Matrix.Rotation(math.pi / 2, 3, "X"))
    ob = new_obj(name, bm, [material])
    ob.location = loc
    return ob


def ico(name, r, loc, material, sub=1, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    for v in bm.verts:
        v.co.x *= scale[0]
        v.co.y *= scale[1]
        v.co.z *= scale[2]
    ob = new_obj(name, bm, [material])
    ob.location = loc
    return ob


def apply_mods(ob):
    bpy.context.view_layer.objects.active = ob
    for md in list(ob.modifiers):
        with bpy.context.temp_override(object=ob, active_object=ob):
            bpy.ops.object.modifier_apply(modifier=md.name)


def join(name, objs):
    """Aplica modificadores e junta vários objetos num só mesh (multi-material)."""
    for o in objs:
        apply_mods(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs,
                                   selected_objects=objs):
        bpy.ops.object.join()
    ob = objs[0]
    ob.name = name
    ob.data.name = name
    # origem no chão (0,0,0) do grupo
    return ob


def flat(ob):
    for p in ob.data.polygons:
        p.use_smooth = False


def empty(name, loc=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "PLAIN_AXES"
    e.location = loc
    col.objects.link(e)
    return e


def parent(child, par):
    child.parent = par


# ---------------------------------------------------------------- rodas
def wheel(name, r, w, loc, side):
    """Roda com banda de rodagem em blocos, flanco do pneu, aro escuro com 5 raios metálicos e cubo.
    Os blocos e os raios deixam o giro visível (um cilindro liso parece parado)."""
    parts = []
    tire = cyl(name + "_t", r * 0.965, w, (0, 0, 0), M["tire"], verts=24)
    md = tire.modifiers.new("bevel", "BEVEL")
    md.width = r * 0.12
    md.segments = 2
    parts.append(tire)
    n = 16
    for k in range(n):
        th = 2 * math.pi * k / n
        radial = (0, -math.sin(th), math.cos(th))
        blk = box(f"{name}_tr{k}", (w * 0.84, 2 * math.pi * r / n * 0.52, 0.07),
                  (0, radial[1] * (r * 0.965 + 0.015), radial[2] * (r * 0.965 + 0.015)), M["tire"])
        blk.rotation_euler = (th, 0, 0)
        parts.append(blk)
    # flanco (anel um pouco mais claro) e aro
    parts.append(cyl(name + "_sw", r * 0.82, w * 0.06, (side * w * 0.48, 0, 0), M["sidewall"], verts=24))
    parts.append(cyl(name + "_r", r * 0.6, w * 0.12, (side * w * 0.5, 0, 0), M["rim_dark"], verts=20))
    parts.append(cyl(name + "_rl", r * 0.62, w * 0.05, (side * w * 0.53, 0, 0), M["rim"], verts=20))
    for k in range(5):
        th = 2 * math.pi * k / 5
        radial = (0, -math.sin(th), math.cos(th))
        sp = box(f"{name}_sp{k}", (w * 0.08, 0.09, r * 0.46), (side * w * 0.55, radial[1] * r * 0.3, radial[2] * r * 0.3), M["rim"], bevel=0.015)
        sp.rotation_euler = (th, 0, 0)
        parts.append(sp)
    parts.append(cyl(name + "_h", r * 0.17, w * 0.16, (side * w * 0.58, 0, 0), M["chrome"], verts=10))
    ob = join(name, parts)
    flat(ob)
    ob.location = loc
    return ob


# ---------------------------------------------------------------- pneus (variantes / upgrade "PNEUS")
def _tilted(name, size, rr, th, tilt, x, material, bevel=0.0):
    """Bloco na banda de rodagem: inclinado 'tilt' sobre o próprio eixo radial e girado 'th' em volta do eixo da roda."""
    b = box(name, size, (x, -math.sin(th) * rr, math.cos(th) * rr), material, bevel=bevel)
    b.rotation_mode = "ZYX"            # aplica Z (inclinação na banda) e depois X (posição na volta)
    b.rotation_euler = (th, 0, tilt)
    return b


def _smooth_round(ob):
    """Banda e ombros lisos (sombreamento suave), tampas e raios chapados."""
    for p in ob.data.polygons:
        p.use_smooth = abs(p.normal.x) < 0.6


def _rim(name, r, w, kind):
    """Aros: rua = 6 raios; esportivo = 10 raios finos (aro grande); slick = 5 raios largos + porca central."""
    parts = []
    s = 1
    if kind == "sport":
        rr = r * 0.72
    elif kind == "slick":
        rr = r * 0.64
    else:
        rr = r * 0.6
    parts.append(cyl(name + "_barrel", rr, w * 0.14, (s * w * 0.47, 0, 0), M["rim_dark"], verts=28))
    parts.append(cyl(name + "_lip", rr * 1.04, w * 0.05, (s * w * 0.53, 0, 0), M["rim"], verts=28))
    if kind == "street":
        for k in range(6):
            th = 2 * math.pi * k / 6
            sp = box(f"{name}_sp{k}", (w * 0.07, 0.07, rr * 0.86), (s * w * 0.55, -math.sin(th) * rr * 0.5, math.cos(th) * rr * 0.5), M["rim"], bevel=0.012)
            sp.rotation_euler = (th, 0, 0)
            parts.append(sp)
        parts.append(cyl(name + "_hub", r * 0.16, w * 0.14, (s * w * 0.57, 0, 0), M["chrome"], verts=12))
        for k in range(5):
            th = 2 * math.pi * (k + 0.5) / 5
            parts.append(cyl(f"{name}_lug{k}", r * 0.025, w * 0.06, (s * w * 0.62, -math.sin(th) * r * 0.1, math.cos(th) * r * 0.1), M["lug"], verts=6))
    elif kind == "sport":
        for k in range(10):
            th = 2 * math.pi * (k // 2) / 5 + (0.17 if k % 2 else -0.17)
            sp = box(f"{name}_sp{k}", (w * 0.05, 0.035, rr * 0.86), (s * w * 0.55, -math.sin(th) * rr * 0.5, math.cos(th) * rr * 0.5), M["rim"], bevel=0.008)
            sp.rotation_euler = (th, 0, 0)
            parts.append(sp)
        parts.append(cyl(name + "_hub", r * 0.15, w * 0.14, (s * w * 0.57, 0, 0), M["rim"], verts=10))
        parts.append(cyl(name + "_cap", r * 0.08, w * 0.06, (s * w * 0.63, 0, 0), M["chrome"], verts=10))
    else:   # slick: 5 raios largos e porca central (corrida)
        for k in range(5):
            th = 2 * math.pi * k / 5
            sp = box(f"{name}_sp{k}", (w * 0.09, 0.13, rr * 0.84), (s * w * 0.55, -math.sin(th) * rr * 0.5, math.cos(th) * rr * 0.5), M["rim"], bevel=0.02)
            sp.rotation_euler = (th, 0, 0)
            parts.append(sp)
        parts.append(cyl(name + "_hub", r * 0.2, w * 0.16, (s * w * 0.57, 0, 0), M["rim"], verts=12))
        parts.append(cyl(name + "_nut", r * 0.1, w * 0.1, (s * w * 0.66, 0, 0), M["chrome"], verts=6))
        parts.append(cyl(name + "_pin", r * 0.035, w * 0.06, (s * w * 0.72, 0, 0), M["tail"], verts=8))
    return parts


def tire_model(name, kind):
    """Roda padrão (r = 0,5, largura = 0,5, aro para +X). O jogo ajusta ao tamanho de cada carro e espelha a esquerda.
    street = pneu de rua (banda em V baixinha); sport = perfil baixo, aro grande; slick = corrida liso com faixa
    colorida no flanco; knobby = cravos fora-de-estrada (buggy)."""
    r, w = 0.5, 0.5
    if kind == "knobby":
        ob = wheel(name, r, w, (0, 0, 0), 1)
        return ob
    parts = []
    base_r = r * (0.955 if kind != "slick" else 0.985)
    tire = cyl(name + "_t", base_r, w * 0.94, (0, 0, 0), M["tire"], verts=32)
    md = tire.modifiers.new("bevel", "BEVEL")
    md.width = r * (0.15 if kind == "street" else 0.1)
    md.segments = 3
    md.limit_method = "ANGLE"
    parts.append(tire)
    if kind in ("street", "sport"):
        n = 26 if kind == "street" else 30
        tilt = 0.32 if kind == "street" else 0.5
        arc = 2 * math.pi * r / n
        for k in range(n):
            th = 2 * math.pi * k / n
            for side, x in ((1, w * 0.2), (-1, -w * 0.2)):
                th2 = th + (math.pi / n if side < 0 else 0.0)
                parts.append(_tilted(f"{name}_b{k}{'l' if side < 0 else 'r'}",
                                     (w * 0.3, arc * (0.62 if kind == "street" else 0.74), 0.05),
                                     base_r + 0.003, th2, tilt * side, x, M["tire"]))
        # nervura central contínua
        parts.append(cyl(name + "_rib", base_r + 0.026, w * (0.08 if kind == "street" else 0.06), (0, 0, 0), M["tire"], verts=32))
    else:
        # slick: faixas de "desgaste" quase invisíveis para o giro aparecer no asfalto
        for k in range(6):
            th = 2 * math.pi * k / 6
            parts.append(_tilted(f"{name}_wear{k}", (w * 0.7, 0.05, 0.004), base_r + 0.001, th, 0.0, 0.0, M["groove"]))
    # flanco: mais fino no esportivo (perfil baixo); faixa colorida no slick (marca de corrida)
    sw_r = {"street": 0.86, "sport": 0.9, "slick": 0.9}[kind]
    parts.append(cyl(name + "_sw", r * sw_r, w * 0.05, (w * 0.47, 0, 0), M["sidewall"], verts=36))
    if kind == "slick":
        parts.append(cyl(name + "_st", r * 0.8, w * 0.04, (w * 0.485, 0, 0), M["tire_stripe"], verts=36))
        parts.append(cyl(name + "_st2", r * 0.74, w * 0.045, (w * 0.49, 0, 0), M["sidewall"], verts=36))
        for k in range(3):   # "letreiro" no flanco: mostra o giro
            th = 2 * math.pi * k / 3
            parts.append(_tilted(f"{name}_logo{k}", (w * 0.03, 0.14, 0.03), r * 0.86, th, 0.0, w * 0.49, M["tire_stripe"]))
    elif kind == "sport":
        parts.append(cyl(name + "_st", r * 0.84, w * 0.04, (w * 0.485, 0, 0), M["tire_stripe"], verts=36))
        parts.append(cyl(name + "_st2", r * 0.81, w * 0.045, (w * 0.49, 0, 0), M["sidewall"], verts=36))
    parts += _rim(name, r, w, kind)
    ob = join(name, parts)
    _smooth_round(ob)
    return ob


# ---------------------------------------------------------------- carros
def arch(name, r_in, r_out, width, loc, material, a0=20.0, a1=160.0, segs=12):
    """Para-lama em arco (casca de cilindro) por cima da roda. Ângulo medido a partir de +Y (traseira)."""
    bm = bmesh.new()
    rings = []
    for i in range(segs + 1):
        th = math.radians(a0 + (a1 - a0) * i / segs)
        cy, sz = math.cos(th), math.sin(th)
        ring = [bm.verts.new((x, r * cy, r * sz)) for (r, x) in
                ((r_out, -width / 2), (r_out, width / 2), (r_in, width / 2), (r_in, -width / 2))]
        rings.append(ring)
    for i in range(segs):
        a, b = rings[i], rings[i + 1]
        for k in range(4):
            k2 = (k + 1) % 4
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_obj(name, bm, [material])
    ob.location = loc
    md = ob.modifiers.new("bevel", "BEVEL")
    md.width = 0.025
    md.segments = 2
    md.limit_method = "ANGLE"
    return ob


def cut_wells(body, wells):
    """Recorta as caixas de roda no chassi (o pneu nunca atravessa a lataria)."""
    cutters = []
    for i, (x0, x1, y, z, r) in enumerate(wells):
        c = cyl(f"{body.name}_cut{i}", r, abs(x1 - x0), ((x0 + x1) / 2, y, z), M["well"], verts=28, axis="X")
        md = body.modifiers.new(f"well{i}", "BOOLEAN")
        md.operation = "DIFFERENCE"
        md.object = c
        md.solver = "EXACT"
        try:
            md.material_mode = "TRANSFER"
        except Exception:
            pass
        cutters.append(c)
    apply_mods(body)
    for c in cutters:
        bpy.data.objects.remove(c, do_unlink=True)


def subdiv_box(name, size, loc, material, cuts=(4, 6, 2), bevel=0.0, wedge=0.0):
    """Caixa com malha subdividida (para amassar no jogo) e chanfro.
    wedge: quanto o topo desce até a ponta da frente (-Y) — perfil em cunha, mais aerodinâmico."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
        if wedge > 0 and v.co.z > 0 and v.co.y < 0:
            v.co.z -= wedge * (-v.co.y / (size[1] / 2))
    ob = new_obj(name, bm, [material])
    ob.location = loc
    if bevel > 0:
        md = ob.modifiers.new("bevel", "BEVEL")
        md.width = bevel
        md.segments = 2
        md.limit_method = "ANGLE"
    # subdivisão simples depois do chanfro: mais vértices nas faces grandes
    md2 = ob.modifiers.new("sub", "SUBSURF")
    md2.subdivision_type = "SIMPLE"
    md2.levels = 2
    md2.render_levels = 2
    return ob


def build_car(key, spec):
    """
    Cada carro sai em PEÇAS separadas para o jogo poder destruir:
      <key>_body (chassi, amassa), <key>_hood (capô), <key>_bumperF / _bumperR (com faróis/lanternas),
      <key>_doorL / _doorR (painéis laterais), <key>_cabin (cabine, vidros, teto, extras de teto),
      <key>_spoiler (se houver), <key>_cargo (caçamba/baú, se houver) e as rodas <key>_wFL/wFR/wRL/wRR.
    spec: L comprimento, W largura, H altura da carroceria, clr vão livre, wr raio da roda, wb entre-eixos,
          cab=(comprimento, recuo, altura, taper_x, taper_y), extras.
    """
    L, W, H = spec["L"], spec["W"], spec["H"]
    clr, wr = spec["clr"], spec["wr"]
    wb = spec["wb"]
    root = empty("car_" + key)
    P = {n: [] for n in ("body", "hood", "bumperF", "bumperR", "doorL", "doorR", "cabin", "spoiler", "cargo")}
    z0 = clr + H / 2
    shift = spec.get("cab_shift", 0.0)
    ww = spec.get("ww", 0.42)
    tw = W / 2 - spec.get("inset", 0.12)
    # rodas: (lado, posição no eixo Y, raio, é dianteira)
    WH = {}
    for n, (sd, y) in {"FL": (-1, -wb / 2), "FR": (1, -wb / 2), "RL": (-1, wb / 2), "RR": (1, wb / 2)}.items():
        rs = spec.get("rear_scale", 1.0) if n[0] == "R" else 1.0
        WH[n] = (sd, y, wr * rs, n[0] == "F")
    wedge = spec.get("wedge", 0.0)
    body = subdiv_box(key + "_b", (W * 0.96, L, H), (0, 0, z0), M["paint"], bevel=spec.get("bev", 0.18), wedge=wedge)
    # caixas de roda: furo cilíndrico um pouco maior que o pneu; na dianteira mais fundo (roda esterça)
    wells = []
    for n, (sd, y, r, fr) in WH.items():
        inner = tw - ww / 2 - (0.24 if fr else 0.07)
        x0, x1 = sd * inner, sd * (W / 2 + 0.5)
        wells.append((x0, x1, y, r, r + 0.08))
    cut_wells(body, wells)
    P["body"].append(body)
    # para-lamas em arco por cima de cada roda (cobrem o topo do pneu, que é mais alto que o capô)
    fender_mat = M["trim"] if spec.get("fender_trim") else M["paint"]
    for n, (sd, y, r, fr) in WH.items():
        P["body"].append(arch(key + f"_fd{n}", r + 0.055, r + 0.13, ww + 0.1, (sd * (tw + 0.02), y, r), fender_mat))
    # escapamento duplo saindo por baixo do para-choque traseiro, com ponteira cromada
    for sd in (-1, 1):
        P["bumperR"].append(cyl(key + f"_ex{sd}", 0.075, 0.5, (sd * W * 0.26, L / 2 + 0.07, clr - 0.03), M["exhaust"], verts=12, axis="Y"))
        P["bumperR"].append(cyl(key + f"_ext{sd}", 0.095, 0.12, (sd * W * 0.26, L / 2 + 0.3, clr - 0.03), M["chrome"], verts=12, axis="Y"))
        P["bumperR"].append(cyl(key + f"_exi{sd}", 0.06, 0.02, (sd * W * 0.26, L / 2 + 0.365, clr - 0.03), M["well"], verts=12, axis="Y"))
        ex = empty(key + ("_exR" if sd > 0 else "_exL"), (sd * W * 0.26, L / 2 + 0.38, clr - 0.03))
        parent(ex, root)
    # capô: painel fino entre os para-lamas
    hood_l = L * 0.32
    hood_w = min(W * 0.82, 2.0 * (tw - (ww + 0.16) / 2 + 0.02) - 0.08)
    hood_y = -L / 2 + hood_l / 2 + 0.12
    hood_drop = wedge * (-hood_y / (L / 2))
    hood_ang = math.atan2(wedge, L / 2)
    P["hood"].append(box(key + "_hd", (hood_w, hood_l, 0.08), (0, hood_y, clr + H + 0.02), M["paint"], bevel=0.03))
    # para-choques com faróis / lanternas
    P["bumperF"].append(box(key + "_bf", (W * 0.98, 0.3, H * 0.45), (0, -L / 2 - 0.04, clr + H * 0.25), M["trim"], bevel=0.08))
    P["bumperR"].append(box(key + "_br", (W * 0.98, 0.3, H * 0.45), (0, L / 2 + 0.04, clr + H * 0.25), M["trim"], bevel=0.08))
    front_top = clr + H - wedge
    P["bumperF"].append(box(key + "_gr", (W * 0.66, 0.08, H * 0.2), (0, -L / 2 - 0.17, clr + H * 0.14), M["trim"], bevel=0.02))
    for s in (-1, 1):
        # farol de LED fino dentro de uma carcaça escura (rasgado, estilo atual)
        hz = clr + (front_top - clr) * 0.66
        P["bumperF"].append(box(key + f"_hh{s}", (0.6, 0.06, 0.16), (s * W * 0.31, -L / 2 - 0.0, hz), M["trim"], bevel=0.03))
        P["bumperF"].append(box(key + f"_hl{s}", (0.52, 0.08, 0.075), (s * W * 0.31, -L / 2 - 0.03, hz + 0.01), M["head"], bevel=0.02))
        P["bumperF"].append(box(key + f"_in{s}", (0.3, 0.06, H * 0.14), (s * W * 0.36, -L / 2 - 0.17, clr + H * 0.3), M["trim"], bevel=0.02))
        P["bumperR"].append(box(key + f"_tl{s}", (0.34, 0.1, 0.13), (s * W * 0.34, L / 2 + 0.0, z0 + H * 0.18), M["tail"], bevel=0.03))
    # barra de LED de ponta a ponta na traseira e difusor com aletas
    P["bumperR"].append(box(key + "_tlb", (W * 0.62, 0.07, 0.05), (0, L / 2 + 0.01, z0 + H * 0.2), M["tail"]))
    for k in range(3):
        P["bumperR"].append(box(key + f"_df{k}", (0.04, 0.26, 0.15), ((k - 1) * W * 0.18, L / 2 + 0.08, clr + 0.05), M["trim"]))
    # portas: painéis laterais entre os para-lamas, saia lateral e retrovisor
    r_f = WH["FL"][2]
    r_r = WH["RL"][2]
    gap_f = r_f + 0.2
    gap_r = r_r + 0.2
    dl = max(0.4, wb - gap_f - gap_r)
    dy = (gap_f - gap_r) * 0.5
    cl, coff, ch, tx, ty = spec["cab"]
    for s, n in ((-1, "doorL"), (1, "doorR")):
        P[n].append(box(key + f"_d{s}", (0.1, dl, H * 0.8), (s * (W * 0.48 + 0.04), dy, z0 + 0.02), M["paint"], bevel=0.03))
        P[n].append(box(key + f"_dh{s}", (0.06, 0.24, 0.06), (s * (W * 0.48 + 0.1), dy + dl * 0.15, z0 + H * 0.2), M["chrome"]))
        P[n].append(box(key + f"_sk{s}", (0.14, dl + 0.1, 0.12), (s * (W * 0.48 + 0.05), dy, clr + 0.05), M["trim"], bevel=0.03))
        if not spec.get("no_mirror"):
            mx = s * (W * 0.43 + 0.12)
            my = coff - cl / 2 + 0.22
            P[n].append(box(key + f"_ms{s}", (0.16, 0.06, 0.05), (s * (W * 0.43 + 0.03), my, clr + H + 0.16), M["trim"]))
            P[n].append(box(key + f"_mh{s}", (0.1, 0.16, 0.13), (mx, my, clr + H + 0.18), M["paint"], bevel=0.03))
            P[n].append(box(key + f"_mg{s}", (0.02, 0.12, 0.09), (mx + s * 0.0, my - 0.07, clr + H + 0.18), M["chrome"]))
    # cabine
    cab_z = clr + H + ch / 2 - 0.02
    P["cabin"].append(box(key + "_c", (W * 0.86, cl, ch), (0, coff, cab_z), M["paint"], bevel=0.1, taper=(tx, ty, shift)))
    glass = box(key + "_g", (W * 0.86 * 1.035, cl * 1.045, ch * 0.995), (0, coff, cab_z), M["glass"], bevel=0.1, taper=(tx, ty, shift))
    slab = box(key + "_gs", (W * 3.0, cl * 3.0, ch * 0.56), (0, coff, cab_z + ch * 0.04), M["glass"])
    mdb = glass.modifiers.new("win", "BOOLEAN")
    mdb.operation = "INTERSECT"
    mdb.object = slab
    mdb.solver = "EXACT"
    apply_mods(glass)
    bpy.data.objects.remove(slab, do_unlink=True)
    P["cabin"].append(glass)
    P["cabin"].append(box(key + "_rf", (W * 0.86 * tx * 0.96, cl * ty * 0.9, 0.1), (0, coff + shift, clr + H + ch - 0.06), M["paint"], bevel=0.04))

    for ex in spec.get("extras", []):
        kind = ex[0]
        if kind == "spoiler":
            h = ex[1]
            P["spoiler"].append(box(key + "_sp", (W * 0.92, 0.42, 0.08), (0, L / 2 - 0.25, clr + H + h), M["trim"], bevel=0.03))
            for s in (-1, 1):
                P["spoiler"].append(box(key + f"_sps{s}", (0.08, 0.2, h), (s * W * 0.36, L / 2 - 0.25, clr + H + h / 2), M["trim"]))
        elif kind == "stripe":
            P["hood"].append(box(key + "_st", (0.36, hood_l * 1.01, 0.1), (0, -L / 2 + hood_l / 2 + 0.12, clr + H + 0.03), M["paint2"], bevel=0.02))
            P["cabin"].append(box(key + "_st2", (0.36, cl * 0.95, 0.12), (0, coff + shift, clr + H + ch - 0.02), M["paint2"], bevel=0.03))
            P["body"].append(box(key + "_st3", (0.36, L * 0.4, 0.06), (0, L * 0.25, clr + H + 0.0), M["paint2"], bevel=0.02))
        elif kind == "hood_scoop":
            P["hood"].append(box(key + "_hs", (0.6, 0.6, 0.18), (0, -L * 0.28, clr + H + 0.1), M["trim"], bevel=0.05, taper=(0.8, 0.7)))
        elif kind == "taxi":
            P["cabin"].append(box(key + "_tx", (0.7, 0.32, 0.24), (0, coff, clr + H + ch + 0.1), M["taxi"], bevel=0.05))
        elif kind == "siren":
            P["cabin"].append(box(key + "_sr", (0.42, 0.3, 0.18), (-0.24, coff, clr + H + ch + 0.08), M["siren_r"], bevel=0.04))
            P["cabin"].append(box(key + "_sb", (0.42, 0.3, 0.18), (0.24, coff, clr + H + ch + 0.08), M["siren_b"], bevel=0.04))
        elif kind == "bed":
            bl = ex[1]
            yb = L / 2 - bl / 2 - 0.05
            P["cargo"].append(box(key + "_bed", (W * 0.82, bl * 0.92, 0.1), (0, yb, clr + H + 0.02), M["trim"]))
            for s in (-1, 1):
                P["cargo"].append(box(key + f"_bw{s}", (0.1, bl, 0.38), (s * W * 0.44, yb, clr + H + 0.18), M["paint"], bevel=0.03))
            P["cargo"].append(box(key + "_bt", (W * 0.86, 0.1, 0.38), (0, L / 2 - 0.08, clr + H + 0.18), M["paint"], bevel=0.03))
            P["cargo"].append(box(key + "_bar", (W * 0.86, 0.1, 0.1), (0, yb - bl / 2 + 0.05, clr + H + 0.55), M["chrome"]))
        elif kind == "cargo":
            bl, bh = ex[1], ex[2]
            P["cargo"].append(box(key + "_cg", (W * 1.02, bl, bh), (0, L / 2 - bl / 2, clr + H + bh / 2 - 0.05), M["paint2"], bevel=0.1))
            P["cargo"].append(box(key + "_cgs", (W * 1.03, bl * 0.7, 0.3), (0, L / 2 - bl / 2, clr + H + bh * 0.55), M["paint"], bevel=0.02))
        elif kind == "seats":
            P["cabin"].append(box(key + "_seat", (W * 0.7, 0.5, 0.4), (0, coff + 0.3, clr + H + 0.2), M["seat"], bevel=0.08))
        elif kind == "rollbar":
            P["cabin"].append(box(key + "_rb", (W * 0.66, 0.12, 0.12), (0, coff + 0.5, clr + H + 0.75), M["chrome"]))
            for s in (-1, 1):
                P["cabin"].append(box(key + f"_rbl{s}", (0.12, 0.12, 0.75), (s * W * 0.3, coff + 0.5, clr + H + 0.37), M["chrome"]))
        elif kind == "bullbar":
            P["bumperF"].append(box(key + "_bb", (W * 0.9, 0.12, 0.55), (0, -L / 2 - 0.2, clr + H * 0.5), M["chrome"], bevel=0.04))

    for n, objs in P.items():
        if not objs:
            continue
        ob = join(f"{key}_{n}", objs)
        flat(ob)
        if n == "hood" and wedge > 0:
            ob.rotation_euler = (hood_ang, 0, 0)
            ob.location.z -= hood_drop
        parent(ob, root)

    for n, (sd, y, r, fr) in WH.items():
        # marcador da roda (posição, raio, largura): o jogo troca pela variante de pneu (tire_*)
        w = cyl(f"{key}_w{n}", r, ww, (sd * tw, y, r), M["tire"], verts=12)
        parent(w, root)
    # ponto de montagem da arma: em cima do teto, no centro (o jogo lê este "empty")
    mnt = empty(key + "_mount", (0, coff + shift, clr + H + ch - 0.01))
    parent(mnt, root)
    return root


CARS = {
    # carro do jogador: cupê esportivo gordinho, rodas grandes
    "faisca": dict(L=3.7, W=2.0, H=0.62, clr=0.34, wr=0.5, wb=2.35, ww=0.5, wedge=0.22,
                   cab=(1.8, 0.28, 0.54, 0.84, 0.52), cab_shift=0.2, bev=0.22,
                   rear_scale=1.08, extras=[("spoiler", 0.36), ("stripe",), ("hood_scoop",)]),
    # rival: muscle car comprido e baixo
    "trovao": dict(L=4.1, W=2.1, H=0.6, clr=0.3, wr=0.5, wb=2.6, ww=0.52, wedge=0.16,
                   cab=(1.75, 0.5, 0.52, 0.82, 0.5), cab_shift=0.24, bev=0.16,
                   rear_scale=1.1, extras=[("hood_scoop",), ("spoiler", 0.22)]),
    # rival: buggy esportivo aberto
    "vespa": dict(L=3.4, W=2.0, H=0.55, clr=0.45, wr=0.55, wb=2.2, ww=0.55, inset=0.0, fender_trim=True,
                  cab=(1.3, 0.2, 0.5, 0.8, 0.55), bev=0.2, extras=[("rollbar",), ("bullbar",)]),
    # tráfego
    "sedan": dict(L=3.9, W=1.95, H=0.66, clr=0.3, wr=0.44, wb=2.4, wedge=0.06,
                  cab=(2.0, 0.1, 0.66, 0.9, 0.7), bev=0.2, extras=[]),
    "taxi": dict(L=3.9, W=1.95, H=0.66, clr=0.3, wr=0.44, wb=2.4,
                 cab=(2.0, 0.1, 0.66, 0.9, 0.7), bev=0.2, extras=[("taxi",)]),
    "policia": dict(L=3.9, W=1.95, H=0.66, clr=0.3, wr=0.44, wb=2.4,
                    cab=(2.0, 0.1, 0.66, 0.9, 0.7), bev=0.2, extras=[("siren",), ("stripe",)]),
    "picape": dict(L=4.3, W=2.1, H=0.8, clr=0.45, wr=0.52, wb=2.7, ww=0.5, fender_trim=True,
                   cab=(1.3, -0.55, 0.7, 0.92, 0.82), bev=0.16, extras=[("bed", 1.7), ("bullbar",)]),
    "van": dict(L=4.4, W=2.1, H=0.85, clr=0.35, wr=0.46, wb=2.8,
                cab=(1.0, -1.2, 0.7, 0.9, 0.7), cab_shift=-0.1, bev=0.18, extras=[("cargo", 3.1, 1.3)]),
}


# ================================================================== carros v2 (remodelados)
# Método: carroceria INTEIRIÇA a partir do perfil lateral (silhueta) extrudado na largura e chanfrado;
# para-lamas retos fundidos ao corpo e caixas de roda recortadas; rodas EMBUTIDAS (face externa rente à
# lateral); cabine em "estufa" (vidro inclinado para dentro, colunas e teto); portas = vincos na lataria.
from mathutils import Vector, Matrix


def prism(name, prof, hb, ht, zb, zt, material, bevel=0.0, segs=3, angle=35.0):
    """Extruda o perfil (y, z) na largura. Meia-largura varia linear com z de hb (em zb) até ht (em zt):
    lateral inclinada para dentro e tampas planas."""
    bm = bmesh.new()
    def hw(z):
        if zt == zb:
            return hb
        u = min(1.0, max(0.0, (z - zb) / (zt - zb)))
        return hb + (ht - hb) * u
    L_ = [bm.verts.new((-hw(z), y, z)) for (y, z) in prof]
    R_ = [bm.verts.new((hw(z), y, z)) for (y, z) in prof]
    n = len(prof)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((L_[i], L_[j], R_[j], R_[i]))
    bm.faces.new(R_)
    bm.faces.new(list(reversed(L_)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_obj(name, bm, [material])
    if bevel > 0:
        md = ob.modifiers.new("bevel", "BEVEL")
        md.width = bevel
        md.segments = segs
        md.limit_method = "ANGLE"
        md.angle_limit = math.radians(angle)
    return ob


def beam(name, p0, p1, w, h, material, bevel=0.0):
    """Barra retangular de p0 a p1 (colunas, tubos de gaiola, suportes)."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    ob = box(name, (w, d.length, h), tuple((a + b) / 2), material, bevel=bevel)
    q = Vector((0, 1, 0)).rotation_difference(d.normalized())
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = q
    return ob


def boolean(ob, other, op):
    md = ob.modifiers.new("b_" + other.name, "BOOLEAN")
    md.operation = op
    md.object = other
    md.solver = "EXACT"
    try:
        md.material_mode = "TRANSFER"
    except Exception:
        pass
    apply_mods(ob)
    bpy.data.objects.remove(other, do_unlink=True)


def build_car2(key, s):
    L, W, clr = s["L"], s["W"], s["clr"]
    wr, wrr, wb, ww = s["wr"], s.get("wrr", s["wr"]), s["wb"], s["ww"]
    zb, nose, tail = s["zb"], s["nose"], s["tail"]
    yF, yR = -L / 2, L / 2
    cowl, deck = s["cowl"], s["deck"]
    root = empty("car_" + key)
    P = {n: [] for n in ("body", "hood", "bumperF", "bumperR", "doorL", "doorR", "cabin", "spoiler", "cargo")}
    paint = M["paint"]
    # ---- rodas (posição) — face externa rente à lateral do carro
    wx = W / 2 - ww / 2 - 0.03
    oy = s.get("axle_off", 0.0)
    WH = {"FL": (-1, -wb / 2 + oy, wr, True), "FR": (1, -wb / 2 + oy, wr, True),
          "RL": (-1, wb / 2 + oy, wrr, False), "RR": (1, wb / 2 + oy, wrr, False)}
    # ---- corpo: perfil lateral (frente = -Y)
    prof = [(yF + 0.2, clr), (yF + 0.03, clr + 0.12), (yF, nose - 0.1), (yF + 0.16, nose), (cowl, zb),
            (deck, zb), (yR - 0.12, tail), (yR, tail - 0.12), (yR, clr + 0.14), (yR - 0.2, clr)]
    if s.get("flat_hood"):
        prof[4] = (cowl, nose + 0.02)
        prof.insert(5, (cowl + 0.05, zb))
    body = prism(key + "_b", prof, W / 2, W / 2, 0, 0, paint, bevel=s.get("bev", 0.1))
    apply_mods(body)
    # para-lamas retos, fundidos à carroceria (cobrem o pneu que passa da linha de cintura)
    for n, (sd, y, r, fr) in WH.items():
        top = 2 * r + 0.1
        if 2 * r + 0.08 > zb:
            fw = ww + 0.18
            z0_ = zb - 0.2
            f = box(f"{key}_fl{n}", (fw, 2 * r + 0.6, top - z0_), (sd * (W / 2 - fw / 2 + 0.035), y, (top + z0_) / 2), paint, bevel=0.09)
            apply_mods(f)
            boolean(body, f, "UNION")
    # caixas de roda (frente mais funda: a roda esterça)
    for n, (sd, y, r, fr) in WH.items():
        inner = W / 2 - ww - (0.3 if fr else 0.14)
        c = cyl(f"{key}_cut{n}", r + 0.075, (W / 2 + 0.5) - inner, (sd * (inner + (W / 2 + 0.5)) / 2, y, r), M["well"], verts=32, axis="X")
        boolean(body, c, "DIFFERENCE")
    # interior escuro da caixa de roda (some o "vazio" atrás do pneu)
    for n, (sd, y, r, fr) in WH.items():
        P["body"].append(cyl(f"{key}_wl{n}", r + 0.06, 0.04, (sd * (W / 2 - ww - (0.28 if fr else 0.12)), y, r), M["well"], verts=24))
    P["body"].append(body)
    # assoalho/saia escura, friso cromado na linha de cintura e saia lateral (quebram a lateral chapada)
    P["body"].append(box(key + "_fl", (W * 0.94, wb + 0.4, 0.08), (0, oy, clr + 0.02), M["trim"]))
    for sd in (-1, 1):
        fy0 = WH["FL"][1] + WH["FL"][2] + 0.12
        fy1 = WH["RL"][1] - WH["RL"][2] - 0.12
        if fy1 > fy0:
            P["body"].append(box(f"{key}_sk{sd}", (0.05, fy1 - fy0, 0.12), (sd * (W / 2 + 0.01), (fy0 + fy1) / 2, clr + 0.08), M["trim"], bevel=0.02))
        P["body"].append(box(f"{key}_bl{sd}", (0.015, deck - cowl + 0.3, 0.025), (sd * (W / 2 + 0.004), (cowl + deck) / 2, zb - 0.1), M["chrome"]))
    # ---- capô (painel levemente saliente, destacável)
    if not s.get("no_hood"):
        hy0, hz0 = yF + 0.3, nose + 0.012
        hy1, hz1 = cowl - 0.12, zb + 0.012 if not s.get("flat_hood") else nose + 0.02
        P["hood"].append(beam(key + "_hd", (0, hy0, hz0), (0, hy1, hz1), W * 0.72, 0.035, paint, bevel=0.012))
        for ex in s.get("extras", []):
            if ex[0] == "scoop":
                P["hood"].append(box(key + "_hs", (0.55, 0.55, 0.16), (0, (hy0 + hy1) / 2 + 0.1, (hz0 + hz1) / 2 + 0.07), M["trim"], bevel=0.04, taper=(0.8, 0.6)))
            if ex[0] == "blower":
                P["hood"].append(box(key + "_bw", (0.5, 0.6, 0.32), (0, (hy0 + hy1) / 2, (hz0 + hz1) / 2 + 0.16), M["chrome"], bevel=0.05))
                P["hood"].append(box(key + "_bwt", (0.6, 0.22, 0.18), (0, (hy0 + hy1) / 2 - 0.1, (hz0 + hz1) / 2 + 0.38), M["trim"], bevel=0.03))
            if ex[0] == "vents":
                for k in range(3):
                    P["hood"].append(box(f"{key}_hv{k}", (0.5, 0.06, 0.03), (0, hy1 - 0.18 - k * 0.12, hz1 - 0.01 + 0.02 * k), M["well"]))
    # ---- frente: para-choque, grade e faróis rasgados
    P["bumperF"].append(box(key + "_bf", (W * 0.97, 0.26, 0.22), (0, yF + 0.08, clr + 0.11), M["trim"], bevel=0.06))
    P["bumperF"].append(box(key + "_gr", (W * 0.5, 0.06, max(0.08, nose - clr - 0.38)), (0, yF - 0.005, (nose + clr) / 2 + 0.02), M["well"], bevel=0.02))
    for sd in (-1, 1):
        hl = box(f"{key}_hl{sd}", (W * 0.24, 0.07, 0.07), (sd * W * 0.32, yF + 0.07, nose - 0.06), M["head"], bevel=0.02)
        hl.rotation_euler = (math.atan2(nose - (nose - 0.1), 0.16) * 0.6, 0, 0)
        P["bumperF"].append(hl)
        P["bumperF"].append(box(f"{key}_hh{sd}", (W * 0.27, 0.06, 0.11), (sd * W * 0.32, yF + 0.09, nose - 0.07), M["trim"], bevel=0.02))
    # ---- traseira: para-choque, lanternas, escapamento
    P["bumperR"].append(box(key + "_br", (W * 0.97, 0.26, 0.22), (0, yR - 0.08, clr + 0.11), M["trim"], bevel=0.06))
    P["bumperR"].append(box(key + "_tlb", (W * 0.7, 0.05, 0.06), (0, yR + 0.005, tail - 0.18), M["tail"]))
    for sd in (-1, 1):
        P["bumperR"].append(box(f"{key}_tl{sd}", (W * 0.2, 0.06, 0.12), (sd * W * 0.36, yR + 0.004, tail - 0.18), M["tail"], bevel=0.02))
        P["bumperR"].append(cyl(f"{key}_ex{sd}", 0.07, 0.3, (sd * W * 0.25, yR + 0.05, clr + 0.02), M["exhaust"], verts=12, axis="Y"))
        P["bumperR"].append(cyl(f"{key}_ext{sd}", 0.085, 0.08, (sd * W * 0.25, yR + 0.2, clr + 0.02), M["chrome"], verts=12, axis="Y"))
        ex = empty(key + ("_exR" if sd > 0 else "_exL"), (sd * W * 0.25, yR + 0.26, clr + 0.02))
        parent(ex, root)
    # ---- cabine em estufa: vidro inclinado, teto e colunas (cor do carro)
    cab = s.get("cab")
    mount_z = zb + 0.05
    mount_y = (cowl + deck) / 2
    if cab:
        y0, y1, y2, y3, zt, bw, tw = cab
        hb, ht = W / 2 * bw, W / 2 * tw
        gl = prism(key + "_g", [(y0, zb - 0.03), (y1, zt), (y2, zt), (y3, zb - 0.03)], hb, ht, zb - 0.03, zt, M["glass"], bevel=0.04)
        P["cabin"].append(gl)
        P["cabin"].append(prism(key + "_rf", [(y1 - 0.02, zt - 0.03), (y1 + 0.08, zt + 0.05), (y2 - 0.08, zt + 0.05), (y2 + 0.02, zt - 0.03)],
                                ht + 0.03, ht + 0.03, 0, 0, paint, bevel=0.03))
        for sd in (-1, 1):
            # colunas A e C (e B se a cabine for longa), seguindo a inclinação do vidro
            P["cabin"].append(beam(f"{key}_pa{sd}", (sd * (hb + 0.01), y0 + 0.02, zb), (sd * (ht + 0.02), y1 + 0.02, zt), 0.09, 0.09, paint))
            P["cabin"].append(beam(f"{key}_pc{sd}", (sd * (hb + 0.01), y3 - 0.02, zb), (sd * (ht + 0.02), y2 - 0.02, zt), 0.11, 0.1, paint))
            if y3 - y0 > 1.4:
                ym = (y1 + y2) / 2
                P["cabin"].append(beam(f"{key}_pb{sd}", (sd * (hb + 0.01), ym, zb), (sd * (ht + 0.02), ym, zt), 0.08, 0.08, paint))
            # retrovisor
            P["doorL" if sd < 0 else "doorR"].append(box(f"{key}_ms{sd}", (0.14, 0.05, 0.05), (sd * (hb + 0.07), y0 + 0.22, zb + 0.06), M["trim"]))
            P["doorL" if sd < 0 else "doorR"].append(box(f"{key}_mh{sd}", (0.1, 0.15, 0.11), (sd * (hb + 0.16), y0 + 0.22, zb + 0.09), paint, bevel=0.02))
        mount_z = zt + 0.04
        mount_y = (y1 + y2) / 2
    # ---- portas: vincos gravados na lataria + maçaneta (nada colado por fora)
    if not s.get("no_doors"):
        d0 = s.get("door", (cowl - 0.05, cowl + 1.05))
        for sd, n in ((-1, "doorL"), (1, "doorR")):
            x = sd * (W / 2 + 0.003)
            for yy in d0:
                P[n].append(box(f"{key}_ds{sd}{yy:.2f}", (0.012, 0.025, zb - clr - 0.2), (x, yy, (zb + clr) / 2 + 0.03), M["well"]))
            P[n].append(box(f"{key}_dh{sd}", (0.02, 0.2, 0.045), (sd * (W / 2 + 0.008), d0[1] - 0.25, zb - 0.15), M["chrome"]))
    # ---- extras de cada tipo
    for ex in s.get("extras", []):
        k = ex[0]
        if k == "wing":
            h = ex[1]
            P["spoiler"].append(box(key + "_wg", (W * 0.94, 0.38, 0.06), (0, yR - 0.22, tail + h), M["trim"], bevel=0.02))
            for sd in (-1, 1):
                P["spoiler"].append(box(f"{key}_we{sd}", (0.04, 0.42, 0.22), (sd * W * 0.47, yR - 0.22, tail + h - 0.04), M["trim"]))
                P["spoiler"].append(beam(f"{key}_ws{sd}", (sd * W * 0.3, yR - 0.3, tail - 0.02), (sd * W * 0.3, yR - 0.2, tail + h), 0.06, 0.12, M["trim"]))
        elif k == "ducktail":
            P["spoiler"].append(box(key + "_dt", (W * 0.9, 0.3, 0.1), (0, yR - 0.12, tail + 0.04), paint, bevel=0.03, taper=(1.0, 0.6, 0.06)))
        elif k == "intakes":
            for sd in (-1, 1):
                P["body"].append(box(f"{key}_it{sd}", (0.03, 0.42, 0.2), (sd * (W / 2 + 0.002), deck - 0.35, clr + 0.32), M["well"]))
        elif k == "stripe":
            P["hood"].append(beam(key + "_st", (0, yF + 0.32, nose + 0.035), (0, cowl - 0.14, zb + 0.035), 0.3, 0.02, M["paint2"]))
        elif k == "cage":
            # santo-antônio tubular por cima da cabine aberta (buggy / trophy truck)
            y0, y1, zt = ex[1], ex[2], ex[3]
            for sd in (-1, 1):
                P["cabin"].append(beam(f"{key}_cg{sd}a", (sd * W * 0.36, y0, zb), (sd * W * 0.3, y0 + 0.35, zt), 0.07, 0.07, M["chrome"]))
                P["cabin"].append(beam(f"{key}_cg{sd}b", (sd * W * 0.3, y0 + 0.35, zt), (sd * W * 0.3, y1 - 0.2, zt), 0.07, 0.07, M["chrome"]))
                P["cabin"].append(beam(f"{key}_cg{sd}c", (sd * W * 0.3, y1 - 0.2, zt), (sd * W * 0.36, y1, zb), 0.07, 0.07, M["chrome"]))
            P["cabin"].append(beam(key + "_cgx0", (-W * 0.3, y0 + 0.35, zt), (W * 0.3, y0 + 0.35, zt), 0.07, 0.07, M["chrome"]))
            P["cabin"].append(beam(key + "_cgx1", (-W * 0.3, y1 - 0.2, zt), (W * 0.3, y1 - 0.2, zt), 0.07, 0.07, M["chrome"]))
            P["cabin"].append(box(key + "_seat", (W * 0.5, 0.45, 0.42), (0, (y0 + y1) / 2 + 0.1, zb + 0.18), M["seat"], bevel=0.06))
            P["cabin"].append(box(key + "_ws", (W * 0.62, 0.05, 0.28), (0, y0 + 0.15, zb + 0.18), M["glass"], bevel=0.02))
            mount_z = zt + 0.05
            mount_y = (y0 + y1) / 2
        elif k == "lightbar":
            y, z = ex[1], ex[2]
            P["cabin"].append(box(key + "_lb", (W * 0.6, 0.12, 0.1), (0, y, z), M["trim"], bevel=0.02))
            for i in range(4):
                P["cabin"].append(box(f"{key}_lbl{i}", (0.14, 0.04, 0.07), ((i - 1.5) * W * 0.14, y - 0.07, z), M["head"]))
        elif k == "spare":
            P["cargo"].append(cyl(key + "_sp", 0.42, 0.26, (0, yR - 0.45, zb + 0.25), M["tire"], verts=20, axis="Z"))
            P["cargo"].append(cyl(key + "_spr", 0.26, 0.28, (0, yR - 0.45, zb + 0.25), M["rim_dark"], verts=12, axis="Z"))
        elif k == "skid":
            P["bumperF"].append(beam(key + "_sk", (0, yF + 0.05, clr + 0.02), (0, yF - 0.18, clr + 0.32), W * 0.75, 0.06, M["chrome"]))
        elif k == "bullbar":
            P["bumperF"].append(box(key + "_bb", (W * 0.86, 0.1, 0.1), (0, yF - 0.14, clr + 0.4), M["chrome"], bevel=0.02))
            P["bumperF"].append(box(key + "_bb2", (W * 0.86, 0.1, 0.1), (0, yF - 0.14, clr + 0.18), M["chrome"], bevel=0.02))
            for sd in (-1, 1):
                P["bumperF"].append(box(f"{key}_bbv{sd}", (0.1, 0.1, 0.36), (sd * W * 0.28, yF - 0.14, clr + 0.29), M["chrome"]))
        elif k == "armor":
            # placas de blindagem rentes à lateral, com rebites
            for sd in (-1, 1):
                pl = box(f"{key}_ar{sd}", (0.04, ex[1], zb - clr - 0.32), (sd * (W / 2 + 0.02), (cowl + deck) / 2, (zb + clr) / 2 + 0.02), M["gunmetal"] if "gunmetal" in M else M["trim"], bevel=0.015)
                P["doorL" if sd < 0 else "doorR"].append(pl)
                for i in range(4):
                    P["doorL" if sd < 0 else "doorR"].append(cyl(f"{key}_rv{sd}{i}", 0.03, 0.03, (sd * (W / 2 + 0.045), (cowl + deck) / 2 + (i - 1.5) * ex[1] * 0.28, zb - 0.12), M["chrome"], verts=6))
        elif k == "slits":
            # janelas estreitas blindadas (tiras de chapa por cima do vidro)
            y0, y1, y2, y3, zt, bw, tw = cab
            P["cabin"].append(prism(key + "_sl", [(y0 - 0.01, zb - 0.02), (y0 + (y1 - y0) * 0.5, (zb + zt) / 2 + 0.02), (y3 - (y3 - y2) * 0.5, (zb + zt) / 2 + 0.02), (y3 + 0.01, zb - 0.02)],
                                    W / 2 * bw + 0.015, W / 2 * (bw + tw) / 2 + 0.015, zb - 0.02, (zb + zt) / 2 + 0.02, paint, bevel=0.02))
        elif k == "bed":
            # caçamba: paredes rentes ao corpo, assoalho escuro
            y0, y1, h = ex[1], ex[2], ex[3]
            P["cargo"].append(box(key + "_bd", (W * 0.86, y1 - y0, 0.06), (0, (y0 + y1) / 2, zb + 0.02), M["well"]))
            for sd in (-1, 1):
                P["cargo"].append(box(f"{key}_bw{sd}", (0.1, y1 - y0, h), (sd * (W / 2 - 0.05), (y0 + y1) / 2, zb + h / 2), paint, bevel=0.03))
            P["cargo"].append(box(key + "_bt", (W, 0.1, h), (0, y1 - 0.05, zb + h / 2), paint, bevel=0.03))
            P["cargo"].append(beam(key + "_brl", (-W * 0.42, y0 + 0.1, zb + h + 0.35), (W * 0.42, y0 + 0.1, zb + h + 0.35), 0.08, 0.08, M["chrome"]))
            for sd in (-1, 1):
                P["cargo"].append(beam(f"{key}_brs{sd}", (sd * W * 0.42, y0 + 0.1, zb + h), (sd * W * 0.42, y0 + 0.1, zb + h + 0.35), 0.08, 0.08, M["chrome"]))
        elif k == "stacks":
            for sd in (-1, 1):
                P["cargo"].append(cyl(f"{key}_sk{sd}", 0.08, 0.9, (sd * W * 0.42, ex[1], zb + 0.45), M["chrome"], verts=10, axis="Z"))
        elif k == "box":
            # baú (van): caixa alta atrás da cabine
            y0, y1, zt = ex[1], ex[2], ex[3]
            P["cargo"].append(prism(key + "_bx", [(y0, zb - 0.02), (y0 + 0.05, zt), (y1, zt), (y1, zb - 0.02)], W / 2 + 0.005, W / 2 - 0.03, zb, zt, M["paint2"], bevel=0.06))
            P["cargo"].append(box(key + "_bxs", (W + 0.03, (y1 - y0) * 0.7, 0.18), (0, (y0 + y1) / 2 + 0.1, zb + (zt - zb) * 0.55), paint))
            mount_z = zt + 0.02
            mount_y = (y0 + y1) / 2
        elif k == "siren":
            P["cabin"].append(box(key + "_srb", (0.95, 0.26, 0.08), (0, mount_y, mount_z + 0.03), M["trim"]))
            P["cabin"].append(box(key + "_sr", (0.4, 0.24, 0.16), (-0.24, mount_y, mount_z + 0.12), M["siren_r"], bevel=0.04))
            P["cabin"].append(box(key + "_sb", (0.4, 0.24, 0.16), (0.24, mount_y, mount_z + 0.12), M["siren_b"], bevel=0.04))
            mount_y += 0.5
        elif k == "taxi":
            P["cabin"].append(box(key + "_tx", (0.7, 0.3, 0.22), (0, mount_y, mount_z + 0.1), M["taxi"], bevel=0.05))
            mount_y += 0.5
    for n, objs in P.items():
        if not objs:
            continue
        ob = join(f"{key}_{n}", objs)
        flat(ob)
        parent(ob, root)
    for n, (sd, y, r, fr) in WH.items():
        w = cyl(f"{key}_w{n}", r, ww, (sd * wx, y, r), M["tire"], verts=12)
        parent(w, root)
    mnt = empty(key + "_mount", (0, mount_y, mount_z))
    parent(mnt, root)
    return root


# medidas: L/W como antes (colisão do jogo); zb = linha de cintura; cab = (y para-brisa, y teto frente, y teto trás,
# y vidro traseiro, z teto, largura base, largura topo)
CARS2 = {
    # esportivo de combate (Marauder): cunha baixa, capô longo, cabine recuada, asa alta
    "faisca": dict(L=3.7, W=2.0, clr=0.24, wr=0.36, wrr=0.38, wb=2.3, ww=0.5, zb=0.88, nose=0.6, tail=0.9,
                   cowl=-0.3, deck=0.95, cab=(-0.3, 0.22, 0.7, 1.02, 1.3, 0.84, 0.62), door=(-0.28, 0.75),
                   extras=[("wing", 0.42), ("intakes",), ("stripe",), ("vents",)]),
    # trophy truck (Dirt Devil): alto, rodas enormes dentro dos para-lamas, gaiola, sem teto
    "vespa": dict(L=3.4, W=2.0, clr=0.48, wr=0.5, wb=2.15, ww=0.55, zb=1.14, nose=0.98, tail=1.1, bev=0.08,
                  cowl=-0.5, deck=1.05, no_doors=True, extras=[("cage", -0.45, 0.85, 1.85), ("lightbar", -0.2, 1.9), ("spare",), ("skid",)]),
    # muscle blindado (Havac): comprido, capô plano com blower, janelas em fresta, chapas laterais
    "trovao": dict(L=4.1, W=2.1, clr=0.26, wr=0.38, wrr=0.4, wb=2.55, ww=0.52, zb=0.93, nose=0.82, tail=0.94, flat_hood=True,
                   cowl=-0.1, deck=1.25, cab=(-0.1, 0.35, 0.9, 1.3, 1.4, 0.86, 0.66), door=(-0.05, 1.0),
                   extras=[("blower",), ("armor", 1.4), ("slits",), ("ducktail",), ("bullbar",)]),
    # picape monstro (Battle Trak): alta, larga, cabine dupla curta, caçamba com santo-antônio, para-choque de impulsão
    "picape": dict(L=4.3, W=2.1, clr=0.48, wr=0.5, wb=2.65, ww=0.5, zb=1.14, nose=1.0, tail=1.1, flat_hood=True,
                   cowl=-0.75, deck=0.55, cab=(-0.75, -0.42, 0.25, 0.55, 1.85, 0.9, 0.78), door=(-0.7, 0.45),
                   extras=[("bed", 0.6, 2.1, 0.32), ("bullbar",), ("stacks", 0.7), ("lightbar", -0.3, 1.97)]),
    "sedan": dict(L=3.9, W=1.95, clr=0.26, wr=0.36, wb=2.4, ww=0.42, zb=0.86, nose=0.68, tail=0.86,
                  cowl=-0.55, deck=0.95, cab=(-0.55, -0.05, 0.6, 1.0, 1.36, 0.86, 0.68), door=(-0.5, 0.9), extras=[]),
    "taxi": dict(L=3.9, W=1.95, clr=0.26, wr=0.36, wb=2.4, ww=0.42, zb=0.86, nose=0.68, tail=0.86,
                 cowl=-0.55, deck=0.95, cab=(-0.55, -0.05, 0.6, 1.0, 1.36, 0.86, 0.68), door=(-0.5, 0.9), extras=[("taxi",)]),
    "policia": dict(L=3.9, W=1.95, clr=0.26, wr=0.36, wb=2.4, ww=0.42, zb=0.86, nose=0.68, tail=0.86,
                    cowl=-0.55, deck=0.95, cab=(-0.55, -0.05, 0.6, 1.0, 1.36, 0.86, 0.68), door=(-0.5, 0.9),
                    extras=[("siren",), ("bullbar",)]),
    "van": dict(L=4.4, W=2.1, clr=0.3, wr=0.4, wb=2.8, ww=0.46, zb=1.0, nose=0.82, tail=1.0, flat_hood=True,
                cowl=-1.45, deck=2.1, cab=(-1.45, -1.05, -0.62, -0.5, 1.95, 0.9, 0.82), door=(-1.4, -0.6),
                extras=[("box", -0.55, 2.2, 2.05)]),
}

car_roots = {}
for i, (k, s_) in enumerate(CARS2.items()):
    car_roots[k] = build_car2(k, s_)

# variantes de pneu (o jogo troca a malha das rodas conforme o upgrade PNEUS)
tire_models = {}
for tk in ("street", "sport", "slick", "knobby"):
    tire_models[tk] = tire_model("tire_" + tk, tk)

# ---------------------------------------------------------------- props
props = {}


def prop(name, objs):
    ob = join(name, objs)
    flat(ob)
    props[name] = ob
    return ob


# cone de trânsito
prop("prop_cone", [
    box("cone_base", (0.7, 0.7, 0.1), (0, 0, 0.05), M["cone"], bevel=0.04),
    cyl("cone_body", 0.27, 0.8, (0, 0, 0.5), M["cone"], verts=12, axis="Z", r2=0.06),
    cyl("cone_band", 0.2, 0.16, (0, 0, 0.5), M["white"], verts=12, axis="Z", r2=0.165),
])
# barril
prop("prop_barrel", [
    cyl("barrel_b", 0.45, 1.1, (0, 0, 0.55), M["barrel"], verts=14, axis="Z"),
    cyl("barrel_r1", 0.47, 0.08, (0, 0, 0.3), M["metal"], verts=14, axis="Z"),
    cyl("barrel_r2", 0.47, 0.08, (0, 0, 0.8), M["metal"], verts=14, axis="Z"),
    cyl("barrel_top", 0.38, 0.04, (0, 0, 1.11), M["white"], verts=14, axis="Z"),
])
# caixote de madeira
crate_parts = [box("crate_b", (1.1, 1.1, 1.1), (0, 0, 0.55), M["wood"], bevel=0.04)]
for s in (-1, 1):
    crate_parts.append(box(f"crate_px{s}", (0.06, 1.14, 0.18), (s * 0.55, 0, 0.55), M["wood_dark"]))
    crate_parts.append(box(f"crate_py{s}", (1.14, 0.06, 0.18), (0, s * 0.55, 0.55), M["wood_dark"]))
prop("prop_crate", crate_parts)
# pilha de pneus
prop("prop_tires", [cyl(f"tire_{i}", 0.5, 0.32, (0, 0, 0.16 + i * 0.3), M["tire"], verts=14, axis="Z") for i in range(3)] +
     [cyl("tire_hole", 0.26, 0.95, (0, 0, 0.47), M["trim"], verts=10, axis="Z")])
# barreira de concreto (jersey) — 4m
jer = [box("jersey_lo", (0.8, 4.0, 0.4), (0, 0, 0.2), M["concrete"], bevel=0.05),
       box("jersey_hi", (0.8, 4.0, 0.6), (0, 0, 0.68), M["concrete"], bevel=0.05, taper=(0.45, 1.0))]
for i in range(2):
    jer.append(box(f"jersey_s{i}", (0.84, 0.9, 0.36), (0, -1.0 + i * 2.0, 0.55), M["red"], bevel=0.03, taper=(0.6, 1.0)))
prop("prop_barrier", jer)
# árvore low-poly
prop("prop_tree", [
    cyl("tree_trunk", 0.22, 1.6, (0, 0, 0.8), M["trunk"], verts=7, axis="Z", r2=0.16),
    ico("tree_a", 1.3, (0, 0, 2.3), M["leaf"], sub=1, scale=(1, 1, 0.9)),
    ico("tree_b", 0.9, (0.5, 0.3, 3.1), M["leaf2"], sub=1),
])
# pinheiro
prop("prop_pine", [
    cyl("pine_trunk", 0.2, 1.0, (0, 0, 0.5), M["trunk"], verts=6, axis="Z"),
    cyl("pine_1", 1.4, 1.6, (0, 0, 1.6), M["leaf2"], verts=8, axis="Z", r2=0.3),
    cyl("pine_2", 1.05, 1.4, (0, 0, 2.6), M["leaf2"], verts=8, axis="Z", r2=0.15),
    cyl("pine_3", 0.7, 1.2, (0, 0, 3.5), M["leaf"], verts=8, axis="Z", r2=0.0),
])
# ---- pântano: taboas, árvore morta, toco com musgo
reeds = []
for i in range(9):
    ang = i * 2.399
    rr = 0.25 + (i % 4) * 0.18
    x, y = math.cos(ang) * rr, math.sin(ang) * rr
    h = 1.2 + (i * 37 % 7) * 0.12
    st = cyl(f"reed_s{i}", 0.035, h, (x, y, h / 2), M["reed"], verts=5, axis="Z")
    st.rotation_euler = (x * 0.25, y * 0.25, 0)
    reeds.append(st)
    if i % 2 == 0:
        reeds.append(cyl(f"reed_c{i}", 0.07, 0.32, (x * 1.1, y * 1.1, h * 0.86), M["cattail"], verts=6, axis="Z"))
    lf = box(f"reed_l{i}", (0.06, 0.02, h * 0.8), (x + 0.08, y, h * 0.4), M["reed"])
    lf.rotation_euler = (0.3 * (1 if i % 2 else -1), 0.2, ang)
    reeds.append(lf)
prop("prop_reeds", reeds)
dead = [cyl("dt_trunk", 0.32, 3.4, (0, 0, 1.7), M["deadwood"], verts=7, axis="Z", r2=0.14)]
for i, (a, h, l) in enumerate([(0.4, 2.2, 1.6), (2.6, 2.8, 1.3), (4.3, 1.7, 1.1), (1.5, 3.2, 0.9)]):
    br = cyl(f"dt_b{i}", 0.09, l, (math.cos(a) * l * 0.4, math.sin(a) * l * 0.4, h + 0.3), M["deadwood"], verts=5, axis="Z", r2=0.03)
    br.rotation_euler = (math.sin(a) * 0.9, -math.cos(a) * 0.9, 0)
    dead.append(br)
dead.append(ico("dt_moss", 0.5, (0.15, 0.1, 0.15), M["moss"], sub=1, scale=(1.3, 1.1, 0.35)))
prop("prop_deadtree", dead)
prop("prop_stump", [
    cyl("stump_b", 0.5, 0.7, (0, 0, 0.35), M["deadwood"], verts=8, axis="Z", r2=0.42),
    cyl("stump_t", 0.43, 0.05, (0, 0, 0.71), M["wood"], verts=8, axis="Z"),
    ico("stump_m", 0.45, (0.25, 0, 0.55), M["moss"], sub=1, scale=(0.8, 1.2, 0.5)),
])
# ---- céu: ilha flutuante (rocha + gramado + arvorezinha) e balão
isle = [cyl("isle_rock", 4.2, 3.4, (0, 0, -1.6), M["earth"], verts=9, axis="Z", r2=0.6),
        cyl("isle_rock2", 2.0, 2.0, (0.8, 0.5, -4.0), M["rock"], verts=7, axis="Z", r2=0.2),
        cyl("isle_grass", 4.35, 0.5, (0, 0, 0.2), M["grass_isle"], verts=9, axis="Z"),
        cyl("isle_tt", 0.18, 1.2, (1.2, -0.8, 1.0), M["trunk"], verts=6, axis="Z"),
        ico("isle_tl", 1.0, (1.2, -0.8, 2.1), M["leaf"], sub=1),
        ico("isle_r1", 0.6, (-1.6, 1.0, 0.6), M["rock"], sub=1, scale=(1.2, 1.0, 0.7))]
prop("prop_island", isle)
bal = []
for i in range(8):
    sl = ico(f"bal_{i}", 2.2, (0, 0, 4.6), [M["balloon_a"], M["balloon_b"], M["balloon_c"]][i % 3], sub=2, scale=(0.45, 1.0, 1.15))
    sl.rotation_euler = (0, 0, i * math.pi / 8)
    bal.append(sl)
bal.append(box("bal_basket", (0.9, 0.9, 0.7), (0, 0, 0.35), M["wicker"], bevel=0.06))
for sx in (-1, 1):
    for sy in (-1, 1):
        rp = cyl(f"bal_rope{sx}{sy}", 0.025, 2.4, (sx * 0.5, sy * 0.5, 1.8), M["wood_dark"], verts=4, axis="Z")
        rp.rotation_euler = (-sy * 0.12, sx * 0.12, 0)
        bal.append(rp)
prop("prop_balloon", bal)
# pedra
prop("prop_rock", [ico("rock", 1.0, (0, 0, 0.45), M["rock"], sub=1, scale=(1.3, 1.0, 0.7))])
# poste de luz
prop("prop_lamp", [
    cyl("lamp_pole", 0.1, 5.0, (0, 0, 2.5), M["metal"], verts=8, axis="Z"),
    box("lamp_arm", (0.14, 1.4, 0.14), (0, -0.6, 4.95), M["metal"]),
    box("lamp_head", (0.5, 0.7, 0.2), (0, -1.25, 4.85), M["metal"], bevel=0.05),
    box("lamp_glow", (0.4, 0.55, 0.06), (0, -1.25, 4.73), M["lamp"]),
    cyl("lamp_base", 0.25, 0.4, (0, 0, 0.2), M["metal"], verts=8, axis="Z"),
])


# prédios simples com janelas emissivas
def building(name, w, d, floors, mcol):
    fh = 1.5
    h = floors * fh
    parts = [box(name + "_b", (w, d, h), (0, 0, h / 2), mcol, bevel=0.1),
             box(name + "_r", (w * 1.04, d * 1.04, 0.3), (0, 0, h + 0.1), M["roof"], bevel=0.05)]
    for f in range(floors):
        z = 0.85 + f * fh
        nx = max(1, int(w / 1.6))
        for i in range(nx):
            x = -w / 2 + (i + 0.5) * w / nx
            parts.append(box(f"{name}_wf{f}_{i}", (0.7, 0.08, 0.7), (x, -d / 2 - 0.02, z), M["window"]))
            parts.append(box(f"{name}_wb{f}_{i}", (0.7, 0.08, 0.7), (x, d / 2 + 0.02, z), M["window"]))
        ny = max(1, int(d / 1.6))
        for i in range(ny):
            y = -d / 2 + (i + 0.5) * d / ny
            parts.append(box(f"{name}_wl{f}_{i}", (0.08, 0.7, 0.7), (-w / 2 - 0.02, y, z), M["window"]))
            parts.append(box(f"{name}_wr{f}_{i}", (0.08, 0.7, 0.7), (w / 2 + 0.02, y, z), M["window"]))
    # caixa d'água
    parts.append(cyl(name + "_tank", 0.6, 1.0, (w * 0.2, d * 0.15, h + 0.75), M["metal"], verts=10, axis="Z"))
    return prop(name, parts)


building("prop_bldgA", 6, 6, 4, M["bldg1"])
building("prop_bldgB", 5, 8, 6, M["bldg2"])
building("prop_bldgC", 8, 5, 3, M["bldg3"])

# rampa (frente baixa em -Y, sobe para +Y; o jogo orienta no sentido da pista)
bm = bmesh.new()
RW, RL, RH = 7.0, 6.0, 1.6
vs = [bm.verts.new(p) for p in [(-RW / 2, -RL / 2, 0), (RW / 2, -RL / 2, 0), (RW / 2, RL / 2, 0), (-RW / 2, RL / 2, 0),
                                (-RW / 2, RL / 2, RH), (RW / 2, RL / 2, RH)]]
for f in [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]:
    bm.faces.new([vs[i] for i in f])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
ramp = new_obj("ramp_core", bm, [M["ramp"]])
stripes = []
for i in range(4):
    t = (i + 0.5) / 4
    stripes.append(box(f"ramp_st{i}", (0.6, 0.6, 0.04), (-RW / 2 + 0.9 + i * 1.75, -RL / 2 + RL * 0.45, RH * 0.45 + 0.03),
                       M["stripe"]))
    stripes[-1].rotation_euler = (math.atan2(RH, RL), 0, 0)
prop("prop_ramp", [ramp] + stripes)

# arco de largada (o tabuleiro xadrez é textura do jogo; aqui a estrutura)
prop("prop_gate", [
    box("gate_l", (0.8, 0.8, 6.0), (-13, 0, 3.0), M["red"], bevel=0.08),
    box("gate_r", (0.8, 0.8, 6.0), (13, 0, 3.0), M["red"], bevel=0.08),
    box("gate_t", (27.0, 1.0, 1.4), (0, 0, 6.3), M["trim"], bevel=0.1),
    box("gate_lt", (25.0, 0.2, 0.3), (0, -0.55, 5.85), M["lamp"]),
])

# arquibancada
stand = []
for i in range(4):
    stand.append(box(f"stand_{i}", (14.0, 1.4, 0.6 + i * 0.6), (0, i * 1.4, (0.6 + i * 0.6) / 2), M["concrete"], bevel=0.04))
for i in range(12):
    for j in range(4):
        c = [M["bldg1"], M["bldg2"], M["bldg3"], M["leaf"]][(i * 3 + j) % 4]
        stand.append(box(f"fan_{i}_{j}", (0.4, 0.4, 0.55), (-6.0 + i * 1.08, j * 1.4 + 0.1, 0.6 + j * 0.6 + 0.3), c, bevel=0.1))
stand.append(box("stand_roof", (14.6, 6.4, 0.2), (0, 2.1, 4.8), M["red"], bevel=0.05))
for s in (-1, 1):
    stand.append(box(f"stand_post{s}", (0.2, 0.2, 4.8), (s * 7.0, 4.9, 2.4), M["metal"]))
prop("prop_stand", stand)

# detritos de batida (pedaços de lataria e vidro)
prop("debris_panel", [box("dp", (0.8, 0.6, 0.08), (0, 0, 0), M["paint"], bevel=0.02)])
prop("debris_glass", [box("dg", (0.35, 0.3, 0.04), (0, 0, 0), M["glass"])])
prop("debris_bolt", [box("db", (0.25, 0.25, 0.25), (0, 0, 0), M["trim"], bevel=0.04)])

# ---------------------------------------------------------------- ambientação (temas das pistas)
M.update({
    "cactus": mat("Cactus", "#4f9a4a", 0.8),
    "palm_leaf": mat("PalmLeaf", "#3fae54", 0.8),
    "palm_trunk": mat("PalmTrunk", "#a97b4f", 0.9),
    "cont_r": mat("ContainerR", "#c9473a", 0.7, 0.2),
    "cont_b": mat("ContainerB", "#2f6db5", 0.7, 0.2),
    "cont_y": mat("ContainerY", "#e6a92e", 0.7, 0.2),
    "crystal_c": mat("CrystalC", "#5ff2ff", 0.2, 0.0, "#4ee8ff", 2.5),
    "crystal_m": mat("CrystalM", "#ff5fd2", 0.2, 0.0, "#ff4fc8", 2.5),
    "snow": mat("Snow", "#f4f8ff", 0.6),
    "sign_y": mat("SignYellow", "#ffcc1f", 0.5),
    "sign_k": mat("SignBlack", "#1b1b22", 0.6),
    "board": mat("Billboard", "#ff3d7f", 0.4, 0.0, "#ff3d7f", 1.6),
    "board2": mat("Billboard2", "#2ee6ff", 0.4, 0.0, "#2ee6ff", 1.6),
    "flag": mat("FlagRed", "#ff3048", 0.7),
    "gunmetal": mat("Gunmetal", "#3a3f4a", 0.35, 0.8),
    "rocket": mat("RocketRed", "#e8372f", 0.4, 0.2),
    "rocket_w": mat("RocketWhite", "#f2f2f2", 0.4),
    "mine": mat("MineDark", "#2a2c33", 0.5, 0.5),
    "mine_y": mat("MineYellow", "#ffc61f", 0.5),
    "red_light": mat("RedLight", "#ff2030", 0.3, 0.0, "#ff2030", 4.0),
    "ammo": mat("AmmoGreen", "#4c8a3a", 0.6),
    "nitro_b": mat("NitroBlue", "#2b8cff", 0.3, 0.4, "#2b8cff", 0.8),
})

prop("prop_cactus", [
    cyl("cac_t", 0.35, 3.2, (0, 0, 1.6), M["cactus"], verts=8, axis="Z", r2=0.3),
    cyl("cac_a1", 0.22, 1.0, (0.65, 0, 1.6), M["cactus"], verts=8, axis="X"),
    cyl("cac_a1u", 0.22, 1.1, (1.05, 0, 2.15), M["cactus"], verts=8, axis="Z", r2=0.18),
    cyl("cac_a2", 0.2, 0.8, (-0.55, 0, 2.2), M["cactus"], verts=8, axis="X"),
    cyl("cac_a2u", 0.2, 0.8, (-0.85, 0, 2.6), M["cactus"], verts=8, axis="Z", r2=0.16),
])
palm = []
for i in range(6):
    t = i / 5
    palm.append(cyl(f"palm_t{i}", 0.26 - t * 0.08, 1.05, (t * t * 0.9, 0, 0.5 + i * 0.95), M["palm_trunk"], verts=7, axis="Z", r2=0.22 - t * 0.08))
for k in range(7):
    a = k / 7 * math.tau
    lf = box(f"palm_l{k}", (0.6, 2.6, 0.08), (0.9 + math.cos(a) * 1.2, math.sin(a) * 1.2, 5.9), M["palm_leaf"], taper=(0.2, 1.0))
    lf.rotation_euler = (0.35, 0, a + math.pi / 2)
    palm.append(lf)
prop("prop_palm", palm)
for key, mk in (("prop_containerR", "cont_r"), ("prop_containerB", "cont_b"), ("prop_containerY", "cont_y")):
    parts = [box(key + "_b", (2.4, 6.0, 2.6), (0, 0, 1.3), M[mk], bevel=0.04)]
    for i in range(9):
        y = -2.7 + i * 0.675
        for sx in (-1, 1):
            parts.append(box(f"{key}_r{i}{sx}", (0.06, 0.18, 2.4), (sx * 1.22, y, 1.3), M[mk]))
    parts.append(box(key + "_d", (2.3, 0.06, 2.4), (0, 3.02, 1.3), M["trim"]))
    prop(key, parts)
for key, mk in (("prop_crystal", "crystal_c"), ("prop_crystalM", "crystal_m")):
    parts = []
    for i, (x, y, h, r) in enumerate([(0, 0, 3.2, 0.5), (0.7, 0.3, 2.0, 0.35), (-0.6, 0.4, 1.6, 0.3), (0.2, -0.7, 2.4, 0.38)]):
        c = cyl(f"{key}_{i}", r, h, (x, y, h / 2), M[mk], verts=6, axis="Z", r2=0.02)
        c.rotation_euler = (x * 0.25, y * 0.25, 0)
        parts.append(c)
    parts.append(ico(key + "_base", 0.9, (0, 0, 0.2), M["rock"], sub=1, scale=(1.3, 1.3, 0.5)))
    prop(key, parts)
prop("prop_snowpine", [
    cyl("sp_trunk", 0.2, 1.0, (0, 0, 0.5), M["trunk"], verts=6, axis="Z"),
    cyl("sp_1", 1.5, 1.7, (0, 0, 1.6), M["leaf2"], verts=8, axis="Z", r2=0.3),
    cyl("sp_1s", 1.1, 0.5, (0, 0, 2.2), M["snow"], verts=8, axis="Z", r2=0.3),
    cyl("sp_2", 1.1, 1.4, (0, 0, 2.7), M["leaf2"], verts=8, axis="Z", r2=0.15),
    cyl("sp_2s", 0.8, 0.5, (0, 0, 3.2), M["snow"], verts=8, axis="Z", r2=0.15),
    cyl("sp_3", 0.75, 1.3, (0, 0, 3.7), M["snow"], verts=8, axis="Z", r2=0.0),
])
# placa de curva: chevrons apontando para +X; a face olha para -Y (vira +Z no jogo)
sign = [cyl("sg_p1", 0.08, 1.6, (-0.9, 0.05, 0.8), M["metal"], verts=6, axis="Z"),
        cyl("sg_p2", 0.08, 1.6, (0.9, 0.05, 0.8), M["metal"], verts=6, axis="Z"),
        box("sg_b", (2.6, 0.1, 1.0), (0, 0, 1.9), M["sign_y"], bevel=0.03)]
for i in range(3):
    x = -0.75 + i * 0.75
    a1 = box(f"sg_c{i}a", (0.14, 0.12, 0.5), (x, -0.04, 2.05), M["sign_k"])
    a1.rotation_euler = (0, -0.75, 0)
    a2 = box(f"sg_c{i}b", (0.14, 0.12, 0.5), (x, -0.04, 1.75), M["sign_k"])
    a2.rotation_euler = (0, 0.75, 0)
    sign += [a1, a2]
prop("prop_sign", sign)
prop("prop_billboard", [
    box("bb_p1", (0.25, 0.25, 4.0), (-2.6, 0.2, 2.0), M["metal"]),
    box("bb_p2", (0.25, 0.25, 4.0), (2.6, 0.2, 2.0), M["metal"]),
    box("bb_frame", (7.0, 0.3, 2.8), (0, 0, 4.6), M["trim"], bevel=0.05),
    box("bb_panel", (6.6, 0.1, 2.4), (0, -0.16, 4.6), M["board"]),
    box("bb_stripe", (6.6, 0.12, 0.5), (0, -0.2, 4.1), M["board2"]),
])
prop("prop_flag", [
    cyl("fl_pole", 0.06, 5.0, (0, 0, 2.5), M["metal"], verts=6, axis="Z"),
    box("fl_cloth", (0.04, 1.6, 1.0), (0, -0.82, 4.4), M["flag"]),
])
tirewall = []
for i in range(5):
    for j in range(2):
        tirewall.append(cyl(f"tw_{i}_{j}", 0.42, 0.3, (0, -2.0 + i * 0.9, 0.16 + j * 0.3), M["tire"], verts=10, axis="Z"))
prop("prop_tirewall", tirewall)

# ---------------------------------------------------------------- armas e itens (frente = -Y)
prop("wpn_gun", [
    box("wg_base", (0.5, 0.6, 0.18), (0, 0, 0.09), M["gunmetal"], bevel=0.03),
    box("wg_body", (0.36, 0.5, 0.26), (0, -0.05, 0.3), M["gunmetal"], bevel=0.04),
    cyl("wg_b1", 0.05, 0.9, (-0.08, -0.6, 0.32), M["chrome"], verts=8, axis="Y"),
    cyl("wg_b2", 0.05, 0.9, (0.08, -0.6, 0.32), M["chrome"], verts=8, axis="Y"),
    box("wg_ammo", (0.18, 0.3, 0.2), (0.28, 0.05, 0.25), M["ammo"], bevel=0.02),
])
pod = [box("wp_box", (0.62, 0.9, 0.42), (0, 0, 0.3), M["gunmetal"], bevel=0.05),
       box("wp_stripe", (0.64, 0.2, 0.44), (0, 0.2, 0.3), M["mine_y"])]
for i, (x, z) in enumerate([(-0.15, 0.2), (0.15, 0.2), (-0.15, 0.4), (0.15, 0.4)]):
    pod.append(cyl(f"wp_t{i}", 0.09, 0.08, (x, -0.46, z), M["rocket"], verts=8, axis="Y"))
prop("wpn_pod", pod)
# foguete: corpo branco com faixas, ogiva em dois estágios, bocal de motor e aletas em cruz
rk = [cyl("rk_b", 0.13, 0.8, (0, 0, 0), M["rocket_w"], verts=14, axis="Y"),
      cyl("rk_bd", 0.137, 0.1, (0, -0.27, 0), M["rocket"], verts=14, axis="Y"),
      cyl("rk_bd2", 0.137, 0.07, (0, 0.27, 0), M["mine_y"], verts=14, axis="Y"),
      cyl("rk_n", 0.13, 0.2, (0, -0.5, 0), M["rocket"], verts=14, axis="Y", r2=0.075),
      cyl("rk_n2", 0.075, 0.16, (0, -0.68, 0), M["rocket"], verts=14, axis="Y", r2=0.0),
      cyl("rk_nz", 0.085, 0.14, (0, 0.47, 0), M["gunmetal"], verts=12, axis="Y", r2=0.115)]
for k in range(2):
    f = box(f"rk_f{k}", (0.035, 0.3, 0.5), (0, 0.27, 0), M["rocket"], bevel=0.01)
    f.rotation_euler = (0, k * math.pi / 2, 0)
    rk.append(f)
prop("proj_rocket", rk)
prop("proj_mine", [
    cyl("mn_b", 0.45, 0.16, (0, 0, 0.08), M["mine"], verts=12, axis="Z"),
    cyl("mn_s", 0.47, 0.06, (0, 0, 0.12), M["mine_y"], verts=12, axis="Z"),
    ico("mn_l", 0.12, (0, 0, 0.2), M["red_light"], sub=1),
])
prop("pickup_ammo", [
    box("pa_b", (1.0, 1.0, 0.8), (0, 0, 0.4), M["ammo"], bevel=0.06),
    box("pa_s", (1.04, 0.3, 0.84), (0, 0, 0.4), M["mine_y"], bevel=0.02),
])
prop("pickup_repair", [
    box("pr_b", (1.0, 1.0, 0.8), (0, 0, 0.4), M["white"], bevel=0.06),
    box("pr_c1", (0.6, 1.04, 0.18), (0, 0, 0.4), M["red"]),
    box("pr_c2", (0.18, 1.04, 0.6), (0, 0, 0.4), M["red"]),
])
prop("pickup_nitro", [
    cyl("pn_b", 0.35, 1.0, (0, 0, 0.5), M["nitro_b"], verts=12, axis="Z"),
    cyl("pn_t", 0.2, 0.2, (0, 0, 1.1), M["chrome"], verts=10, axis="Z"),
])

# ---------------------------------------------------------------- layout para preview / organização
x = 0
for k, r in car_roots.items():
    r.location = (x, 0, 0)
    x += 3.2
x = 0
for k, p in props.items():
    if k.startswith("prop_bldg") or k in ("prop_gate", "prop_stand"):
        continue
    p.location = (x, 8, 0)
    x += 3.0

# ---------------------------------------------------------------- oclusão ambiente "assada" nos vértices
# Dá o acabamento de render (cantos e frestas escurecidos) mesmo no renderizador leve do jogo/web.
def bake_ao():
    roots = list(car_roots.values()) + list(props.values()) + list(tire_models.values())
    saved = {r: r.location.copy() for r in roots}
    for i, r in enumerate(roots):  # afasta tudo para um objeto não sombrear o outro
        r.location = ((i % 10) * 40.0, (i // 10) * 40.0, 0)
    bpy.context.view_layer.update()
    meshes = [o for o in scene.objects if o.type == "MESH"]
    for o in meshes:
        me = o.data
        ca = me.color_attributes.new("AO", "BYTE_COLOR", "CORNER")
        me.color_attributes.active_color = ca
        me.attributes.render_color_index = me.color_attributes.active_color_index
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 64
    w = bpy.data.worlds.new("bake")
    scene.world = w
    w.light_settings.distance = 0.7
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
    # suaviza: AO estilizado, sem preto chapado
    for o in meshes:
        data = o.data.color_attributes["AO"].data
        for c in data:
            v = c.color[0]
            v = 0.42 + 0.58 * (v ** 0.85)
            c.color = (v, v, v, 1.0)
    for r, loc in saved.items():
        r.location = loc


bake_ao()
print("AO assado")

# ---------------------------------------------------------------- export
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format="GLB",
    export_apply=True,
    export_yup=True,
    export_materials="EXPORT",
    export_vertex_color="ACTIVE",
    export_cameras=False,
    export_lights=False,
)
print("exportado:", os.path.abspath(OUT))

# ---------------------------------------------------------------- preview opcional (Cycles CPU)
if "--render" in sys.argv:
    path = sys.argv[sys.argv.index("--render") + 1]
    # cores bonitas pros carros no preview
    paints = ["#e8352b", "#2f6fd6", "#ffb31a", "#5cc26b", "#ffd23a", "#f6f6f2", "#8a5cd6", "#f08a7a"]
    for i, (k, r) in enumerate(car_roots.items()):
        m = MATS["Paint"].copy()
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = hexcol(paints[i % len(paints)])
        for part in r.children:
            for slot in part.material_slots:
                if slot.material and slot.material.name == "Paint":
                    slot.material = m
    # esconde o que é grande demais para o enquadramento
    for k, p in props.items():
        if k.startswith("prop_bldg") or k in ("prop_gate", "prop_stand", "prop_ramp", "prop_lamp") or k.startswith("debris"):
            p.hide_render = True
    for i, (k, r) in enumerate(car_roots.items()):
        r.location = ((i % 4) * 3.4, (i // 4) * 5.5, 0)
    small = [k for k in props if k in ("prop_cone", "prop_barrel", "prop_crate", "prop_tires", "prop_tree", "prop_pine", "prop_rock", "prop_barrier")]
    for i, k in enumerate(small):
        props[k].location = (-3.0 + i * 2.6, 11.5, 0)
    # chão
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=60)
    g = new_obj("floor", bm, [mat("Floor", "#e9e4f2", 0.9)])
    g.location = (10, 4, 0)
    # luz e câmera "isométrica"
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.5
    sun.angle = 0.15
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(30))
    col.objects.link(so)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = hexcol("#cfd8ff")
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = 22
    co = bpy.data.objects.new("cam", cam)
    col.objects.link(co)
    target = Vector((6.0, 6.0, 0.6))
    co.location = target + Vector((-22, -22, 20))
    co.rotation_euler = (target - co.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = co
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 800
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("preview:", path)

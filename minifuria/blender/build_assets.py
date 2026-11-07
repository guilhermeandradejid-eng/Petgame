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
    tire = cyl(name + "_t", r, w, (0, 0, 0), M["tire"], verts=18)
    md = tire.modifiers.new("bevel", "BEVEL")
    md.width = r * 0.18
    md.segments = 2
    # aro saliente no lado de fora
    rim = cyl(name + "_r", r * 0.58, w * 0.3, (side * w * 0.38, 0, 0), M["rim"], verts=10)
    hub = cyl(name + "_h", r * 0.2, w * 0.36, (side * w * 0.45, 0, 0), M["trim"], verts=8)
    ob = join(name, [tire, rim, hub])
    flat(ob)
    ob.location = loc
    return ob


# ---------------------------------------------------------------- carros
def subdiv_box(name, size, loc, material, cuts=(4, 6, 2), bevel=0.0):
    """Caixa com malha subdividida (para amassar no jogo) e chanfro."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
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
    P["body"].append(subdiv_box(key + "_b", (W * 0.96, L, H), (0, 0, z0), M["paint"], bevel=spec.get("bev", 0.18)))
    # caixas de roda, grade, escapamento ficam no chassi
    for s in (-1, 1):
        for y in (-wb / 2, wb / 2):
            P["body"].append(box(key + f"_arch{s}{y}", (0.12, wr * 2.25, wr * 1.1), (s * (W / 2 + 0.01), y, clr + wr * 0.35), M["trim"], bevel=0.04))
    P["body"].append(cyl(key + "_ex", 0.09, 0.3, (W * 0.28, L / 2 + 0.12, clr + 0.12), M["exhaust"], verts=8, axis="Y"))
    # capô: painel fino em cima da frente
    hood_l = L * 0.32
    P["hood"].append(box(key + "_hd", (W * 0.82, hood_l, 0.08), (0, -L / 2 + hood_l / 2 + 0.12, clr + H + 0.02), M["paint"], bevel=0.03))
    # para-choques com faróis / lanternas
    P["bumperF"].append(box(key + "_bf", (W * 0.98, 0.3, H * 0.45), (0, -L / 2 - 0.04, clr + H * 0.25), M["trim"], bevel=0.08))
    P["bumperR"].append(box(key + "_br", (W * 0.98, 0.3, H * 0.45), (0, L / 2 + 0.04, clr + H * 0.25), M["trim"], bevel=0.08))
    P["bumperF"].append(box(key + "_gr", (W * 0.4, 0.08, H * 0.28), (0, -L / 2 - 0.02, z0 + H * 0.05), M["trim"], bevel=0.02))
    for s in (-1, 1):
        P["bumperF"].append(box(key + f"_hl{s}", (0.42, 0.12, 0.2), (s * W * 0.32, -L / 2 - 0.0, z0 + H * 0.12), M["head"], bevel=0.04))
        P["bumperR"].append(box(key + f"_tl{s}", (0.46, 0.12, 0.18), (s * W * 0.32, L / 2 + 0.0, z0 + H * 0.15), M["tail"], bevel=0.03))
    # portas: painéis laterais entre as rodas
    dl = wb - wr * 2.4
    for s, n in ((-1, "doorL"), (1, "doorR")):
        P[n].append(box(key + f"_d{s}", (0.1, dl, H * 0.8), (s * (W * 0.48 + 0.04), 0, z0 + 0.02), M["paint"], bevel=0.03))
        P[n].append(box(key + f"_dh{s}", (0.06, 0.24, 0.06), (s * (W * 0.48 + 0.1), dl * 0.15, z0 + H * 0.2), M["chrome"]))
    # cabine
    cl, coff, ch, tx, ty = spec["cab"]
    cab_z = clr + H + ch / 2 - 0.02
    P["cabin"].append(box(key + "_c", (W * 0.86, cl, ch), (0, coff, cab_z), M["paint"], bevel=0.1, taper=(tx, ty, shift)))
    P["cabin"].append(box(key + "_g", (W * 0.88, cl * 0.92, ch * 0.7), (0, coff, cab_z + 0.02), M["glass"], bevel=0.05, taper=(tx * 0.98, ty * 0.98, shift)))
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
            P["cabin"].append(box(key + "_rb", (W * 0.8, 0.12, 0.12), (0, coff + 0.5, clr + H + 0.75), M["chrome"]))
            for s in (-1, 1):
                P["cabin"].append(box(key + f"_rbl{s}", (0.12, 0.12, 0.75), (s * W * 0.37, coff + 0.5, clr + H + 0.37), M["chrome"]))
        elif kind == "bullbar":
            P["bumperF"].append(box(key + "_bb", (W * 0.9, 0.12, 0.55), (0, -L / 2 - 0.2, clr + H * 0.5), M["chrome"], bevel=0.04))

    for n, objs in P.items():
        if not objs:
            continue
        ob = join(f"{key}_{n}", objs)
        flat(ob)
        parent(ob, root)

    tw = W / 2 - spec.get("inset", 0.12)
    names = {"FL": (-1, -wb / 2), "FR": (1, -wb / 2), "RL": (-1, wb / 2), "RR": (1, wb / 2)}
    for n, (s, y) in names.items():
        rs = spec.get("rear_scale", 1.0) if n[0] == "R" else 1.0
        w = wheel(f"{key}_w{n}", wr * rs, spec.get("ww", 0.42), (s * tw, y, wr * rs), s)
        parent(w, root)
    return root


CARS = {
    # carro do jogador: cupê esportivo gordinho, rodas grandes
    "faisca": dict(L=3.7, W=2.0, H=0.62, clr=0.34, wr=0.5, wb=2.35, ww=0.5,
                   cab=(1.75, 0.25, 0.62, 0.86, 0.62), cab_shift=0.12, bev=0.22,
                   rear_scale=1.08, extras=[("spoiler", 0.36), ("stripe",), ("hood_scoop",)]),
    # rival: muscle car comprido e baixo
    "trovao": dict(L=4.1, W=2.1, H=0.6, clr=0.3, wr=0.5, wb=2.6, ww=0.52,
                   cab=(1.7, 0.45, 0.58, 0.84, 0.58), cab_shift=0.15, bev=0.16,
                   rear_scale=1.1, extras=[("hood_scoop",), ("spoiler", 0.22)]),
    # rival: buggy esportivo aberto
    "vespa": dict(L=3.4, W=2.0, H=0.55, clr=0.45, wr=0.55, wb=2.2, ww=0.55, inset=0.0,
                  cab=(1.3, 0.2, 0.5, 0.8, 0.55), bev=0.2, extras=[("rollbar",), ("bullbar",)]),
    # tráfego
    "sedan": dict(L=3.9, W=1.95, H=0.66, clr=0.3, wr=0.44, wb=2.4,
                  cab=(2.0, 0.1, 0.66, 0.9, 0.7), bev=0.2, extras=[]),
    "taxi": dict(L=3.9, W=1.95, H=0.66, clr=0.3, wr=0.44, wb=2.4,
                 cab=(2.0, 0.1, 0.66, 0.9, 0.7), bev=0.2, extras=[("taxi",)]),
    "policia": dict(L=3.9, W=1.95, H=0.66, clr=0.3, wr=0.44, wb=2.4,
                    cab=(2.0, 0.1, 0.66, 0.9, 0.7), bev=0.2, extras=[("siren",), ("stripe",)]),
    "picape": dict(L=4.3, W=2.1, H=0.8, clr=0.45, wr=0.52, wb=2.7, ww=0.5,
                   cab=(1.3, -0.55, 0.7, 0.92, 0.82), bev=0.16, extras=[("bed", 1.7), ("bullbar",)]),
    "van": dict(L=4.4, W=2.1, H=0.85, clr=0.35, wr=0.46, wb=2.8,
                cab=(1.0, -1.2, 0.7, 0.9, 0.7), cab_shift=-0.1, bev=0.18, extras=[("cargo", 3.1, 1.3)]),
}

car_roots = {}
for i, (k, s) in enumerate(CARS.items()):
    car_roots[k] = build_car(k, s)

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

# ---------------------------------------------------------------- export
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format="GLB",
    export_apply=True,
    export_yup=True,
    export_materials="EXPORT",
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

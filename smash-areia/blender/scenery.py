"""
Cenário do Smash na Areia (rodada de direção de arte).

Regras de forma (vindas da revisão de arte):
  * formas gordinhas, arredondadas e afinando, levemente assimétricas;
  * nada mais fino que ~0,10 m perto da câmera (não serrilha no celular);
  * ritmo grande / médio / pequeno em cada peça; caixas com bisel;
  * paleta fechada (ver PAL) para o cenário não brigar com a quadra.

Os nomes dos materiais são usados pelo Godot (vento nas folhas, cores por
instância via paleta), então ficam estáveis.
"""
import math

import bmesh
from mathutils import Matrix, Vector

import build_assets as B

PAL = {
    "trunk": "#b7854f", "trunk_ring": "#8a5a33",
    "leaf": "#6cd34a", "leaf_mid": "#3fae45", "leaf_dark": "#237a3e",
    "wood": "#c98b55", "wood_dark": "#8c5a35", "thatch": "#e8b860", "thatch_dark": "#c9923f",
    "blue": "#2f7bff", "blue_dark": "#1f4fbf", "red": "#ff4d4d", "red_dark": "#c8333a",
    "yellow": "#ffc93c", "coral": "#ff7a59", "mint": "#3fd6a8", "white": "#fffdf6", "navy": "#1f3a8a",
    "hill": "#7cc7a2", "hill_cliff": "#a9b8e0", "island": "#4fb06e", "island_cliff": "#9c8cc4",
    "island_sand": "#f6dda4",
}


# ---------------------------------------------------------------- utilidades de forma

def rbox(b, center, size, mat, bevel=0.04, rot=None, segments=2):
    """Caixa com quinas arredondadas (bisel), na escala real (sem matriz de escala)."""
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    bv = min(bevel, min(size) * 0.45)
    if bv > 0.001:
        bmesh.ops.bevel(bm, geom=list(bm.verts) + list(bm.edges), offset=bv, segments=segments,
                        affect="EDGES", profile=0.5, clamp_overlap=True)
    m = Matrix.Translation(Vector(center))
    if rot:
        m = m @ rot
    bm.transform(m)
    _merge(b, bm, mat)


def hull(b, points, mat, smooth=False):
    """Casco convexo de uma nuvem de pontos (peças facetadas sólidas)."""
    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=list(bm.verts))
    for f in bm.faces:
        f.smooth = smooth
    _merge(b, bm, mat, smooth)


def tube(b, a, c, r1, r2, mat, seg=10):
    a, c = Vector(a), Vector(c)
    d = c - a
    b.cone(a, d, d.length, r1, r2, mat, seg=seg)


def _merge(b, bm, mat, smooth=True):
    me_tmp = bmesh.new()
    mi = b._mi(mat)
    vmap = {}
    for v in bm.verts:
        vmap[v] = b.bm.verts.new(v.co)
    for f in bm.faces:
        try:
            nf = b.bm.faces.new([vmap[v] for v in f.verts])
        except ValueError:
            continue
        nf.material_index = mi
        nf.smooth = smooth if smooth is not None else f.smooth
    bm.free()
    me_tmp.free()


def ribbon_frond(b, base, yaw, length, width, lift, droop, mat, sections=17, teeth=True, twist=0.0):
    """Folha de palmeira em "remo" com borda serrilhada e vinco no meio.
    Malha fechada (vinco em cima, barriga embaixo) para o contorno funcionar."""
    base = Vector(base)
    d = Vector((math.cos(yaw), math.sin(yaw), 0.0))
    side = Vector((-d.y, d.x, 0.0))
    up = Vector((0, 0, 1))
    rows = []
    for i in range(sections + 1):
        t = i / sections
        p = base + d * (length * t) + up * (lift * math.sin(math.pi * t * 0.8) - droop * t * t)
        w = width * 0.5 * max(0.0, math.sin(math.pi * (t ** 0.75)))
        if teeth and 0 < i < sections:
            w *= 1.0 if i % 2 == 0 else 0.72
        if i == 0:
            w = width * 0.08
        # vinco: a nervura sobe, as bordas caem um pouco (folha em "V" aberto)
        crease = 0.06 * (1.0 - t * 0.6)
        tw = twist * t
        sd = side * math.cos(tw) + up * math.sin(tw)
        left = p + sd * w - up * crease * 0.6
        right = p - sd * w - up * crease * 0.6
        top = p + up * crease
        bot = p - up * (crease * 0.35 + 0.015)
        rows.append([left, top, right, bot])
    bm = b.bm
    mi = b._mi(mat)
    vr = [[bm.verts.new(q) for q in row] for row in rows]
    for i in range(sections):
        a, c = vr[i], vr[i + 1]
        for k in range(4):
            k2 = (k + 1) % 4
            f = bm.faces.new((a[k], a[k2], c[k2], c[k]))
            f.material_index = mi
            f.smooth = True
    for row, rev in ((vr[0], True), (vr[-1], False)):
        f = bm.faces.new(list(reversed(row)) if rev else row)
        f.material_index = mi
        f.smooth = True


# ---------------------------------------------------------------- palmeiras e mato

def _palm(name, height, lean, fronds=8, scale_leaf=1.0, seed=0):
    B.reset_scene()
    trunk = B.material("Trunk", PAL["trunk"])
    ring = B.material("TrunkRing", PAL["trunk_ring"])
    leaf = B.material("Leaf", PAL["leaf"])
    leaf_dark = B.material("LeafDark", "#4fbf4a")   # o escuro vem da camada de baixo, não da sombra
    coco = B.material("Coconut", "#6b4a2b")
    b = B.Builder("Palm")
    # tronco em "S" suave com anéis salientes (silhueta serrilhada de desenho)
    n = 9
    pts = []
    for i in range(n + 1):
        t = i / n
        x = lean * (1.3 * t * t - 0.3 * t)
        pts.append(Vector((x, 0.12 * math.sin(t * math.pi * 1.3), height * t)))
    for i in range(n):
        t = i / n
        r = 0.42 - (0.42 - 0.24) * t
        r_top = 0.42 - (0.42 - 0.24) * ((i + 1) / n)
        d = pts[i + 1] - pts[i]
        b.cone(pts[i] - d.normalized() * 0.02, d, d.length + 0.03, r + 0.05, r_top, trunk if i % 2 == 0 else ring,
               seg=12)
    top = pts[-1] + Vector((0, 0, 0.05))
    # coroa: 5 folhas de cima (claras) e 3 de baixo (escuras, mais caídas)
    import random
    rnd = random.Random(seed)
    for k in range(fronds):
        upper = k < 5
        yaw = (k * math.tau / 5 + 0.2) if upper else ((k - 5) * math.tau / 3 + 0.9)
        yaw += rnd.uniform(-0.18, 0.18)
        L = (2.8 if upper else 2.5) * scale_leaf * rnd.uniform(0.92, 1.08)
        ribbon_frond(b, top, yaw, L, 0.9 * scale_leaf, 0.5 if upper else 0.25, 1.6 if upper else 2.2,
                     leaf if upper else leaf_dark, twist=rnd.uniform(-0.25, 0.25))
    for k in range(3):
        a = k * 2.1 + 0.4
        b.sphere(top + Vector((math.cos(a) * 0.22, math.sin(a) * 0.22, -0.25)), 0.2, coco, seg=12, rings=8)
    b.sphere(top + Vector((0, 0, 0.05)), 0.3, leaf_dark, seg=12, rings=8)
    b.build()
    B.export(name)


def build_palms():
    _palm("palm", 6.5, 1.6, seed=3)
    _palm("palm_b", 4.8, 2.4, scale_leaf=0.92, seed=11)


def build_bush():
    B.reset_scene()
    a = B.material("Bush", PAL["leaf_mid"])
    c = B.material("BushDark", PAL["leaf_dark"])
    b = B.Builder("Bush")
    for (x, y, z, r, m) in ((0, 0, 0.32, 0.55, a), (0.48, 0.1, 0.24, 0.42, c), (-0.45, -0.05, 0.22, 0.4, c),
                            (0.1, -0.3, 0.2, 0.36, a)):
        b.sphere((x, y, z), r, m, scale=(1.0, 0.9, 0.72), seg=10, rings=7, cut_below=0.0)
    b.build()
    B.export("bush")


# ---------------------------------------------------------------- guarda-sol, toalha, caixa térmica

def build_umbrella():
    B.reset_scene()
    pa = B.material("UmbrellaA", PAL["coral"])
    pb = B.material("UmbrellaB", PAL["white"])
    pole = B.material("Pole", PAL["white"])
    b = B.Builder("Umbrella")
    b.cone((0, 0, -0.35), (0, 0, 1), 3.05, 0.05, 0.045, pole, seg=10)
    bm = b.bm
    segs = 8
    apex = bm.verts.new((0, 0, 2.7))
    apex_lo = bm.verts.new((0, 0, 2.6))
    ring, ring_lo, rim, mid = [], [], [], []
    for i in range(segs):
        a = i * math.tau / segs
        am = (i + 0.5) * math.tau / segs
        ring.append(bm.verts.new((math.cos(am - math.pi / segs) * 1.1, math.sin(am - math.pi / segs) * 1.1, 2.45)))
        ring_lo.append(bm.verts.new((math.cos(a) * 1.02, math.sin(a) * 1.02, 2.36)))
        rim.append(bm.verts.new((math.cos(a) * 1.9, math.sin(a) * 1.9, 2.05)))
        mid.append(bm.verts.new((math.cos(am) * 1.78, math.sin(am) * 1.78, 1.93)))   # festão: o meio do gomo cai
    for i in range(segs):
        j = (i + 1) % segs
        m = b._mi(pa if i % 2 == 0 else pb)
        for f in ((apex, ring[i], ring[j]), (ring[i], rim[i], mid[i]), (ring[i], mid[i], ring[j]),
                  (ring[j], mid[i], rim[j])):
            nf = bm.faces.new(f)
            nf.material_index = m
            nf.smooth = False
        # parte de baixo (branca), fechando a malha na borda
        mw = b._mi(pb)
        for f in ((apex_lo, ring_lo[j], ring_lo[i]), (ring_lo[i], mid[i], rim[i]), (ring_lo[i], ring_lo[j], mid[i]),
                  (ring_lo[j], rim[j], mid[i])):
            nf = bm.faces.new(f)
            nf.material_index = mw
            nf.smooth = False
    b.sphere((0, 0, 2.74), 0.08, pole, seg=10, rings=6)
    b.build()
    B.export("umbrella")


def build_towel():
    B.reset_scene()
    a = B.material("TowelA", PAL["yellow"])
    c = B.material("TowelB", PAL["white"])
    b = B.Builder("Towel")
    for i in range(5):
        rbox(b, (0, -0.72 + i * 0.36, 0.018), (0.9, 0.36, 0.035), a if i % 2 == 0 else c, bevel=0.012)
    b.build()
    B.export("towel")


def build_cooler():
    B.reset_scene()
    body = B.material("CoolerBody", PAL["mint"])
    lid = B.material("CoolerLid", PAL["white"])
    b = B.Builder("Cooler")
    rbox(b, (0, 0, 0.18), (0.62, 0.42, 0.36), body, bevel=0.06)
    rbox(b, (0, 0, 0.39), (0.66, 0.46, 0.08), lid, bevel=0.035)
    rbox(b, (0, 0, 0.46), (0.3, 0.1, 0.06), lid, bevel=0.025)
    b.build()
    B.export("cooler")


def build_chair():
    """Cadeira de praia de lona: armação grossa e lona listrada (2 peças grandes)."""
    B.reset_scene()
    frame = B.material("ChairFrame", PAL["white"])
    ca = B.material("ChairA", PAL["blue"])
    cb = B.material("ChairB", PAL["white"])
    b = B.Builder("Chair")
    for sx in (-0.32, 0.32):
        tube(b, (sx, -0.35, 0.0), (sx, 0.45, 0.62), 0.035, 0.035, frame, seg=8)
        tube(b, (sx, 0.35, 0.0), (sx, -0.15, 0.36), 0.035, 0.035, frame, seg=8)
    for i in range(3):
        m = ca if i % 2 == 0 else cb
        x = -0.2 + i * 0.2
        rbox(b, (x, -0.05, 0.3), (0.2, 0.55, 0.03), m, bevel=0.01, rot=B.rot_x(8))
        rbox(b, (x, 0.34, 0.55), (0.2, 0.03, 0.5), m, bevel=0.01, rot=B.rot_x(-28))
    b.build()
    B.export("chair")


# ---------------------------------------------------------------- rede, placas, cadeira do juiz

def build_post():
    B.reset_scene()
    metal = B.material("PostMetal", PAL["white"])
    stripe = B.material("PostStripe", PAL["blue"])
    b = B.Builder("Post")
    b.cone((0, 0, -0.2), (0, 0, 1), 2.2, 0.14, 0.13, stripe, seg=14)
    b.cone((0, 0, 0.94), (0, 0, 1), 0.14, 0.145, 0.145, metal, seg=14)
    b.sphere((0, 0, 2.02), 0.17, metal, seg=14, rings=10)
    b.build()
    B.export("post")


def build_adboard():
    B.reset_scene()
    frame = B.material("BoardFrame", PAL["white"])
    face = B.material("BoardFace", PAL["blue"])
    b = B.Builder("AdBoard")
    rbox(b, (0, 0, 0.45), (3.6, 0.16, 0.9), frame, bevel=0.06)
    rbox(b, (0, 0, 0.47), (3.36, 0.2, 0.7), face, bevel=0.03)
    for sx in (-1.5, 1.5):
        rbox(b, (sx, 0.12, 0.25), (0.12, 0.2, 0.5), frame, bevel=0.03)
    b.build()
    B.export("adboard")


def build_refchair():
    B.reset_scene()
    metal = B.material("RefMetal", PAL["white"])
    seat = B.material("RefSeat", PAL["blue"])
    b = B.Builder("RefChair")
    # "A" gordinho: 4 pernas de 0,12 m que se fecham para cima, 3 degraus na frente
    for sx in (-1, 1):
        for sy in (-1, 1):
            tube(b, (sx * 0.5, sy * 0.48, 0.0), (sx * 0.36, sy * 0.3, 1.9), 0.065, 0.055, metal, seg=10)
    for i, z in enumerate((0.5, 1.0, 1.5)):
        f = z / 1.9
        w = (0.5 - 0.14 * f) * 2
        rbox(b, (0, -(0.48 - 0.18 * f), z), (w + 0.1, 0.14, 0.1), metal, bevel=0.03)
    for sx in (-1, 1):
        rbox(b, (sx * (0.5 - 0.07), 0, 0.85), (0.1, 0.9, 0.1), metal, bevel=0.03)
    rbox(b, (0, 0.0, 1.95), (0.9, 0.8, 0.14), seat, bevel=0.05)
    rbox(b, (0, 0.38, 2.32), (0.9, 0.12, 0.62), seat, bevel=0.05)
    for sx in (-1, 1):
        rbox(b, (sx * 0.46, 0.02, 2.17), (0.1, 0.72, 0.1), metal, bevel=0.03)
    b.build()
    B.export("refchair")


# ---------------------------------------------------------------- quiosque e torre do salva-vidas

def build_kiosk():
    B.reset_scene()
    wood = B.material("KioskWood", PAL["wood"])
    roof = B.material("KioskRoof", PAL["thatch"])
    roof2 = B.material("KioskRoof2", PAL["thatch_dark"])
    counter = B.material("KioskCounter", PAL["white"])
    stripe = B.material("KioskStripe", PAL["mint"])
    sign = B.material("KioskSign", PAL["coral"])
    coco = B.material("Coco", "#5fbf3f")
    b = B.Builder("Kiosk")
    for sx in (-1.3, 1.3):
        for sy in (-1.0, 1.0):
            b.cone((sx, sy, 0), (0, 0, 1), 2.65, 0.13, 0.11, wood, seg=8)
    rbox(b, (0, -0.95, 0.55), (3.0, 0.9, 1.1), counter, bevel=0.06)
    rbox(b, (0, -1.41, 0.6), (3.0, 0.05, 0.22), stripe, bevel=0.02)
    rbox(b, (0, -0.95, 1.14), (3.2, 1.0, 0.1), wood, bevel=0.04)
    # telhado de palha em duas camadas, com a barra recortada
    for (z, h, r_lo, mat, drop) in ((2.45, 1.45, 2.55, roof, 0.15), (2.4, 0.3, 2.7, roof2, 0.18)):
        bm = b.bm
        mi = b._mi(mat)
        segn = 16
        apex = bm.verts.new((0, 0, z + h))
        hem = []
        for i in range(segn):
            a = i * math.tau / segn
            hem.append(bm.verts.new((math.cos(a) * r_lo, math.sin(a) * r_lo, z - (drop if i % 2 else 0.0))))
        inner = bm.verts.new((0, 0, z + 0.2))
        for i in range(segn):
            j = (i + 1) % segn
            f = bm.faces.new((apex, hem[i], hem[j]))
            f.material_index = mi
            f.smooth = False
            f2 = bm.faces.new((inner, hem[j], hem[i]))
            f2.material_index = mi
            f2.smooth = False
    rbox(b, (0, -1.55, 2.35), (1.8, 0.1, 0.5), sign, bevel=0.04)
    for i in range(5):
        b.sphere((-0.9 + i * 0.45, -0.95, 1.33), 0.16, coco, seg=10, rings=8)
    b.build()
    B.export("kiosk")


def build_tower():
    B.reset_scene()
    wood = B.material("TowerWood", PAL["white"])
    red = B.material("TowerRed", PAL["red"])
    roof = B.material("TowerRoof", PAL["yellow"])
    b = B.Builder("Tower")
    for sx in (-0.8, 0.8):
        for sy in (-0.8, 0.8):
            tube(b, (sx * 1.1, sy * 1.1, 0), (sx, sy, 2.45), 0.09, 0.08, wood, seg=8)
    rbox(b, (0, 0, 2.5), (2.1, 2.1, 0.16), red, bevel=0.05)
    rbox(b, (0, 0.2, 3.15), (1.7, 1.3, 1.15), wood, bevel=0.08)
    rbox(b, (0, -0.47, 3.2), (1.1, 0.06, 0.55), red, bevel=0.03)
    hull(b, [(-1.15, -0.65, 3.72), (1.15, -0.65, 3.72), (-1.15, 1.05, 3.72), (1.15, 1.05, 3.72),
             (-0.2, 0.2, 4.35), (0.2, 0.2, 4.35)], roof)
    for i in range(5):
        rbox(b, (0, -1.35 - i * 0.2, 0.25 + i * 0.45), (0.95, 0.28, 0.08), wood, bevel=0.025)
    for sx in (-0.5, 0.5):
        tube(b, (sx, -2.35, 0.0), (sx, -1.05, 2.45), 0.05, 0.05, wood, seg=8)
    b.build()
    B.export("tower")


def build_surfboard():
    B.reset_scene()
    base = B.material("BoardBase", PAL["yellow"])
    stripe = B.material("BoardStripe", PAL["red"])
    b = B.Builder("Surfboard")
    b.sphere((0, 0, 1.05), 1.0, base, scale=(0.32, 0.07, 1.1), seg=18, rings=12)
    b.sphere((0, -0.014, 1.05), 1.0, stripe, scale=(0.09, 0.062, 1.08), seg=10, rings=12)
    b.build()
    B.export("surfboard")


# ---------------------------------------------------------------- arquibancada

def build_bleachers():
    """Arquibancada de 15 m x 5 degraus (degrau de 0,75 m x 0,5 m: o Godot depende
    disso para sentar a torcida). Assentos e laterais na cor do time (paleta)."""
    B.reset_scene()
    frame = B.material("BleachFrame", PAL["white"])
    seat_a = B.material("BleachSeatA", PAL["blue"])
    seat_b = B.material("BleachSeatB", PAL["blue"])
    skirt = B.material("BleachSkirt", PAL["blue_dark"])
    team = B.material("BleachTeam", PAL["blue"])
    canopy_b = B.material("BleachCanopyB", PAL["white"])
    b = B.Builder("Bleachers")
    rows = 5
    length = 15.0
    top_z = 0.45 + rows * 0.5
    for i in range(rows):
        y = i * 0.75
        z = 0.45 + i * 0.5
        rbox(b, (0, y, z - 0.05), (length, 0.75, 0.1), frame, bevel=0.03)                # piso do degrau
        rbox(b, (0, y - 0.36, z * 0.5 - 0.05), (length, 0.06, z - 0.1), frame if i else skirt, bevel=0.02)
        rbox(b, (0, y + 0.18, z + 0.36), (length - 0.3, 0.32, 0.12), seat_a if i % 2 == 0 else seat_b, bevel=0.04)
        for k in range(6):
            x = -length / 2 + 0.6 + k * (length - 1.2) / 5
            rbox(b, (x, y + 0.18, z + 0.15), (0.12, 0.2, 0.3), frame, bevel=0.02)
    # saia da frente com 3 placas brancas
    for k in (-1, 0, 1):
        rbox(b, (k * 4.6, -0.42, 0.24), (2.6, 0.05, 0.3), canopy_b, bevel=0.02)
    # laterais em trapézio na cor do time, com uma faixa branca
    back_y = rows * 0.75 - 0.38
    for sx in (-1, 1):
        x = sx * (length / 2 + 0.08)
        pts = []
        for dx in (-0.08, 0.08):
            pts += [(x + dx, -0.4, 0.0), (x + dx, back_y, 0.0), (x + dx, back_y, top_z + 0.45), (x + dx, -0.4, 0.75)]
        hull(b, pts, team)
        pts = []
        for dx in (-0.09, 0.09):
            pts += [(x + dx, -0.4, 0.5), (x + dx, back_y, top_z - 0.3), (x + dx, back_y, top_z - 0.1),
                    (x + dx, -0.4, 0.68)]
        hull(b, pts, canopy_b)
    # encosto do fundo
    rbox(b, (0, back_y + 0.05, top_z + 0.42), (length, 0.1, 0.12), frame, bevel=0.03)
    for k in range(7):
        x = -length / 2 + 0.3 + k * (length - 0.6) / 6
        rbox(b, (x, back_y + 0.05, top_z / 2 + 0.2), (0.12, 0.12, top_z + 0.4), frame, bevel=0.03)
    # toldo listrado sobre a última fileira (4 postes)
    cz = top_z + 2.1
    for sx in (-1, 1):
        for y in (back_y - 1.2, back_y + 0.05):
            tube(b, (sx * (length / 2 - 0.2), y, top_z), (sx * (length / 2 - 0.2), y, cz), 0.06, 0.06, frame, seg=8)
    for k in range(6):
        w = length / 6
        x = -length / 2 + w * (k + 0.5)
        rbox(b, (x, back_y - 0.7, cz + 0.05), (w + 0.01, 2.0, 0.12), team if k % 2 == 0 else canopy_b, bevel=0.03,
             rot=Matrix.Rotation(-0.12, 4, "X"))
    b.build()
    B.export("bleachers")


# ---------------------------------------------------------------- fundo: morros, ilhas, nuvens

def build_mountains():
    """Morro herói (pão de açúcar inclinado) + dois morros baixos arredondados."""
    B.reset_scene()
    rock = B.material("MorroRock", PAL["hill_cliff"])
    green = B.material("MorroGreen", PAL["hill"])
    green2 = B.material("MorroGreen2", "#69b893")
    b = B.Builder("Mountains")
    tilt = Matrix.Rotation(math.radians(10), 4, "Y")
    b.sphere((0, 0, 0), 1.0, rock, scale=(14, 12, 32), seg=18, rings=12, rot=tilt, cut_below=0)
    b.sphere((-4.2, 0, 23.5), 1.0, green, scale=(10.5, 9.5, 8), seg=16, rings=8, rot=tilt, cut_below=19)
    b.sphere((24, 8, 0), 1.0, green2, scale=(16, 12, 13), seg=14, rings=8, cut_below=0)
    b.sphere((-22, 10, 0), 1.0, green2, scale=(14, 11, 9), seg=14, rings=8, cut_below=0)
    b.build()
    B.export("mountains")


def build_island():
    B.reset_scene()
    rock = B.material("IslandRock", PAL["island_cliff"])
    grass = B.material("IslandGreen", PAL["island"])
    sand = B.material("IslandSand", PAL["island_sand"])
    b = B.Builder("Island")
    b.sphere((0, 0, 0), 1.0, sand, scale=(10, 5.5, 1.0), seg=18, rings=6, cut_below=0)
    b.sphere((-0.5, 0, 0.4), 1.0, rock, scale=(5.2, 3.6, 4.2), seg=14, rings=8, cut_below=0)
    b.sphere((-1.0, 0.3, 3.7), 1.0, grass, scale=(4.4, 3.2, 1.9), seg=14, rings=8, cut_below=3.0)
    b.sphere((3.6, -0.4, 0.5), 1.0, grass, scale=(2.6, 2.0, 1.6), seg=12, rings=6, cut_below=0)
    b.build()
    B.export("island")


def build_cloud():
    """Cúmulos de base reta e lente achatada, com 3 ou 4 montinhos (grande, médio, pequeno)."""
    variants = {
        "cloud": [((0.0, 0, 0.75), 1.2), ((1.35, 0.1, 0.45), 0.9), ((-1.3, 0, 0.4), 0.72), ((0.55, 0.2, 1.4), 0.62)],
        "cloud_puff": [((0, 0, 0.6), 0.95), ((0.95, 0, 0.35), 0.62), ((-0.8, 0.05, 0.3), 0.5)],
        "cloud_long": [((-2.0, 0, 0.4), 0.7), ((-0.7, 0.1, 0.65), 1.0), ((0.8, 0, 0.55), 0.9), ((2.1, 0.1, 0.32), 0.6)],
    }
    for name, blobs in variants.items():
        B.reset_scene()
        w = B.material("Cloud", "#ffffff")
        b = B.Builder("Cloud")
        span = max(abs(c[0]) + r for c, r in blobs)
        b.sphere((0, 0, 0.1), 1.0, w, scale=(span * 0.95, 1.15, 0.38), seg=24, rings=10, cut_below=0.05)
        for c, r in blobs:
            b.sphere(c, r, w, scale=(1, 0.85, 0.92), seg=16, rings=10, cut_below=0.05)
        b.build()
        B.export(name)


def build_all():
    build_palms()
    build_bush()
    build_umbrella()
    build_towel()
    build_cooler()
    build_chair()
    build_post()
    build_adboard()
    build_refchair()
    build_kiosk()
    build_tower()
    build_surfboard()
    build_bleachers()
    build_mountains()
    build_island()
    build_cloud()

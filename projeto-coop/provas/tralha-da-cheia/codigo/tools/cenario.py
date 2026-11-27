# Cenário do Trapiche Velho, gerado pelo mesmo módulo de facetas e pintura dos bonecos (regra 9).
# Miriti cru e tinta desbotada pela água (saturação baixa), tinta que falha nas arestas, manchas de água.
# Coordenadas escritas como no Godot (x direita, y cima, z para a câmera) e convertidas para o Blender por G().
# Uso: python3 cenario.py PROJ [grupo ...]   grupos: trapiche objetos fundo frente marolas
import sys, os, math, random, time, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix
from malha import *
from bonecos import limb, assemble
import pintura as PT

def G(x, y, z):
    return Vector((x, -z, y))

def box(c, size, rot=(0, 0, 0), bevel=0.18, cuts=0):
    """caixa facetada (tábua, ripa, viga) centrada em c (coordenadas do Godot), size=(x, y, z) do Godot."""
    bm = mk('cube', bevel=bevel, bseg=1) if not cuts else mk('cube', cuts=cuts)
    place(bm, (0, 0, 0), (size[0] / 2, size[2] / 2, size[1] / 2))
    M = Matrix.Translation(G(*c)) @ Matrix.Rotation(math.radians(-rot[1]), 4, 'Z') @ Matrix.Rotation(math.radians(rot[0]), 4, 'X') @ Matrix.Rotation(math.radians(rot[2]), 4, 'Y')
    return xform(bm, M)

def post(a, b, r0, r1=None, seg=7):
    return limb(G(*a), G(*b), r0, r1 if r1 else r0 * 0.9, seg_n=seg, rings=3, bulge=r0 * 0.05)

FADED = ['tabua_azul', 'tabua_verde', 'tabua_ocre', 'tabua_rosa', 'miriti_som']

def nails(c0, c1, y, z):
    return [('disco', tuple(G(x, y, z + dz)), 0.011, 'tinta') for x in (c0 + 0.08, c1 - 0.08) for dz in (-0.07, 0.07)]

# ------------------------------------------------------------------ trapiche: tábuas, vigas, palafitas
X0, X1 = -11.0, 11.0
PLACA = {}
Z0, Z1 = -2.7, 2.8          # fundo e frente do piso
def build_trapiche(B, rng):
    w = 0.3
    nrow = int((Z1 - Z0) / w)
    for i in range(nrow):
        z = Z0 + (i + 0.5) * (Z1 - Z0) / nrow
        x = X0 + rng.uniform(-0.6, 0.0)
        while x < X1:
            L = rng.uniform(1.6, 4.2)
            x1 = min(X1 + 0.2, x + L)
            if rng.random() < 0.025 and abs(z) < 2.0:   # tábua faltando: vão escuro
                x = x1 + 0.03
                continue
            # v2: a cor vai por placa (remendo de 5 fileiras por ~3,6 m), só 2 matizes claros e dessaturados, para
            # o piso ficar no meio-tom claro e os bonecos e inimigos nos extremos de valor
            col = PLACA.setdefault((i // 5, int((0.5 * (x + x1) - X0 + 1.8 * ((i // 5) % 2)) // 3.6)), rng.choice(['miriti', 'tabua_cinza', 'miriti']))
            h = 0.06
            y = -h / 2 + rng.uniform(-0.012, 0.012)
            tilt = (rng.uniform(-1.2, 1.2), 0, rng.uniform(-0.8, 0.8))
            pb = box(((x + x1) / 2, y, z), (x1 - x - 0.025, h, w - 0.022), tilt, bevel=0.22)
            sp = {'base': col, 'wear': 1.0, 'wear_w': 1.4, 'mancha': 0.12, 'marks': nails(x, x1, 0.0, z),
                  'brush': (1, 0.05, 0.1)}
            B.piece(pb, paint=sp, bone='root', jitter=0.004, hull=False)
            x = x1 + 0.025
    # vigas de borda (frente e fundo) e travessas
    for zz in (Z1 + 0.06, Z0 - 0.06):
        x = X0
        while x < X1:
            x1 = min(X1, x + rng.uniform(3.0, 5.0))
            B.piece(box(((x + x1) / 2, -0.17, zz), (x1 - x - 0.02, 0.24, 0.14), bevel=0.2), paint={'base': rng.choice(['tabua_azul', 'lama', 'tabua_verde']), 'wear': 1.0, 'mancha': 1.0},
                    bone='root', jitter=0.006, hull=False)
            x = x1 + 0.02
    # palafitas: estacas na frente e no fundo, entrando na água, com amarras
    x = X0 + 0.4
    while x < X1:
        for zz in (Z1 + 0.18, Z0 - 0.18):
            r = rng.uniform(0.09, 0.12)
            top = rng.uniform(0.02, 0.25) if zz > 0 else rng.uniform(0.0, 0.5)
            B.piece(post((x, -2.4, zz), (x + rng.uniform(-0.05, 0.05), top, zz + rng.uniform(-0.03, 0.03)), r, seg=7),
                    paint={'base': 'lama', 'wear': 0.8, 'sob': 'miriti_som', 'descasca': 0.25, 'mancha': 1.0}, bone='root', jitter=0.008, hull=False)
            B.piece(post((x - 0.13, -0.25, zz + 0.02), (x + 0.13, -0.25, zz + 0.02), 0.035, seg=5), paint={'base': 'miriti_som', 'cru': True}, bone='root', hull=False)
        x += rng.uniform(1.6, 2.2)
    # travessas em X sob a frente (aparecem acima da água)
    x = X0 + 0.4
    while x < X1 - 2:
        B.piece(post((x, -0.55, Z1 + 0.25), (x + 1.9, -0.32, Z1 + 0.25), 0.04, seg=5), paint={'base': 'lama', 'mancha': 1.0, 'wear': 0.5}, bone='root', hull=False)
        x += 3.7
    # escada para a água
    ex = -1.6
    for k in range(4):
        B.piece(box((ex, -0.35 - k * 0.3, Z1 + 0.36), (0.8, 0.05, 0.22), bevel=0.2), paint={'base': 'miriti_som', 'wear': 1.0, 'mancha': 1.0}, bone='root', jitter=0.004, hull=False)
    for sx in (-0.42, 0.42):
        B.piece(post((ex + sx, -1.5, Z1 + 0.4), (ex + sx, 0.45, Z1 + 0.32), 0.035, seg=5), paint={'base': 'tabua_ocre', 'wear': 1.0}, bone='root', hull=False)

# ------------------------------------------------------------------ objetos no trapiche
def caixote(B, c, s, rng, col=None):
    x, y, z = c
    col = col or rng.choice(FADED)
    for k in range(3):
        yy = y + s * (0.18 + 0.32 * k)
        for dz in (-s * 0.47, s * 0.47):
            B.piece(box((x, yy, z + dz), (s, s * 0.22, s * 0.06), bevel=0.25), paint={'base': col if k == 1 else 'miriti_som', 'cru': k != 1, 'wear': 1.0}, bone='root', jitter=0.003, hull=False)
        for dx in (-s * 0.47, s * 0.47):
            B.piece(box((x + dx, yy, z), (s * 0.06, s * 0.22, s), bevel=0.25), paint={'base': col if k == 1 else 'miriti_som', 'cru': k != 1, 'wear': 1.0}, bone='root', jitter=0.003, hull=False)
    for dx in (-s * 0.45, s * 0.45):
        for dz in (-s * 0.45, s * 0.45):
            B.piece(box((x + dx, y + s * 0.5, z + dz), (s * 0.09, s, s * 0.09), bevel=0.2), paint={'base': 'miriti_som', 'cru': True}, bone='root', hull=False)

def barril(B, c, r, h, rng):
    x, y, z = c
    bm = loft([(0, r * 0.85, r * 0.85, 0, 2.0), (h * 0.5, r, r, 0, 2.0), (h, r * 0.85, r * 0.85, 0, 2.0)], seg_n=9)
    place(bm, G(x, y, z))
    B.piece(bm, paint={'base': rng.choice(['tabua_azul', 'ferrugem', 'tabua_verde']), 'descasca': 0.3, 'sob': 'ferrugem', 'pat': 'faixas', 'c1': 'lama', 'axis': (0, 0, 1),
            'bands': [(y + h * 0.15, y + h * 0.2), (y + h * 0.8, y + h * 0.85)], 'wear': 1.0}, bone='root', jitter=0.006, hull=False)

def build_objetos(B, rng):
    # barraca de feira com lona listrada (fundo, à esquerda)
    bx, bz = -6.2, -1.7
    for dx in (-1.2, 1.2):
        for dz in (-0.7, 0.7):
            B.piece(post((bx + dx, 0, bz + dz), (bx + dx, 2.25 + (0.25 if dz < 0 else 0), bz + dz), 0.05, seg=6), paint={'base': 'miriti_som', 'cru': True}, bone='root', hull=False)
    B.piece(box((bx, 0.78, bz + 0.1), (2.3, 0.08, 1.1), bevel=0.15), paint={'base': 'tabua_verde', 'wear': 1.0, 'mancha': 0.6}, bone='root', jitter=0.004, hull=False)
    B.piece(box((bx, 0.4, bz + 0.62), (2.2, 0.7, 0.05), bevel=0.15), paint={'base': 'tabua_rosa', 'pat': 'listras', 'c1': 'miriti_som', 's': 0.25, 'w': 0.3, 'axis': (1, 0, 0), 'wear': 1.0}, bone='root', jitter=0.004, hull=False)
    # lona: folha caída em gomos facetados, com barra em festão
    lona = bmesh.new()
    NX, NZ = 8, 4
    vs = {}
    for i in range(NX + 1):
        for j in range(NZ + 1):
            u, v = i / NX, j / NZ
            xx = bx - 1.45 + 2.9 * u
            zz = bz - 0.95 + 1.9 * v
            yy = 2.5 - 0.5 * v - 0.12 * math.sin(math.pi * u * 4) ** 2 * (0.4 + v)
            vs[i, j] = lona.verts.new(G(xx, yy, zz))
    for i in range(NX):
        for j in range(NZ):
            lona.faces.new([vs[i, j], vs[i + 1, j], vs[i + 1, j + 1], vs[i, j + 1]])
    for i in range(NX):  # festão
        a, b = vs[i, NZ], vs[i + 1, NZ]
        m = lona.verts.new((a.co + b.co) / 2 + Vector((0, -0.02, -0.16)))
        lona.faces.new([a, m, b][::-1])
    bmesh.ops.solidify(lona, geom=lona.faces[:], thickness=0.025)
    B.piece(lona, paint={'base': 'tabua_rosa', 'pat': 'listras', 'c1': 'miriti', 's': 0.36, 'w': 0.5, 'axis': (1, 0, 0), 'wear': 0.6, 'mancha': 0.5}, bone='root', mat='pano', hull=False)
    # cestos com frutos de palmeira em cima da mesa
    for k, dx in enumerate((-0.7, 0.05, 0.75)):
        cb = loft([(0, 0.16, 0.16, 0, 2.0), (0.14, 0.22, 0.22, 0, 2.0)], seg_n=9, cap_top=False)
        place(cb, G(bx + dx, 0.82, bz + 0.1))
        B.piece(cb, paint={'base': 'miriti_som', 'pat': 'listras', 'c1': 'lama', 's': 0.05, 'w': 0.4, 'axis': (0, 0, 1)}, bone='root', hull=False)
        for q in range(7):
            a = q * 0.9 + k
            fr = place(mk('ico', sub=1), G(bx + dx + 0.1 * math.cos(a), 0.97 + 0.04 * (q % 2), bz + 0.1 + 0.1 * math.sin(a)), (0.065, 0.065, 0.06))
            B.piece(fr, paint={'base': ['escuro', 'ferrugem', 'tabua_ocre'][k], 'wear': 0.3}, bone='root', jitter=0.004, hull=False)
    # caixotes empilhados (fundo, à direita) e barris
    for (x, y, z, s) in ((5.6, 0, -2.0, 0.62), (6.3, 0, -2.0, 0.62), (5.95, 0.62, -2.05, 0.62), (7.0, 0, -1.9, 0.62), (6.6, 0.62, -2.0, 0.62), (7.6, 0, -1.2, 0.55), (-9.2, 0, -1.9, 0.6), (-8.6, 0, -2.1, 0.6)):
        caixote(B, (x, y, z), s, rng)
    barril(B, (8.4, 0, -1.6), 0.3, 0.85, rng)
    barril(B, (8.3, 0, -0.9), 0.3, 0.85, rng)
    barril(B, (-3.6, 0, -2.2), 0.28, 0.8, rng)
    # Âncora de Balsa (Tralha Grande) deitada no piso, com as duas pontas para erguer
    ax, az = 2.6, -1.75
    B.piece(post((ax - 1.3, 0.12, az), (ax + 1.0, 0.12, az + 0.1), 0.085, seg=7), paint={'base': 'ferrugem', 'descasca': 0.4, 'sob': 'tabua_azul', 'wear': 1.0}, bone='root', jitter=0.006, hull=False)
    B.piece(post((ax - 1.25, 0.1, az - 0.6), (ax - 1.25, 0.1, az + 0.6), 0.06, seg=6), paint={'base': 'lama', 'wear': 1.0}, bone='root', jitter=0.004, hull=False)
    for s in (-1, 1):
        arm_ = [G(ax + 1.0, 0.12, az + 0.1), G(ax + 1.25, 0.14, az + 0.1 + s * 0.45), G(ax + 0.95, 0.16, az + 0.1 + s * 0.8)]
        B.piece(tube(arm_, [0.08, 0.075, 0.05], seg_n=7), paint={'base': 'ferrugem', 'descasca': 0.4, 'sob': 'tabua_azul', 'wear': 1.0}, bone='root', jitter=0.005, hull=False)
        fl = place(mk('cube', bevel=0.3, bseg=1), G(ax + 0.95, 0.14, az + 0.1 + s * 0.82), (0.16, 0.12, 0.05))
        B.piece(fl, paint={'base': 'ferrugem', 'descasca': 0.4, 'sob': 'tabua_azul', 'wear': 1.0}, bone='root', jitter=0.01, hull=False)
    ring = [G(ax - 1.45 + 0.12 * math.cos(t), 0.14 + 0.12 * math.sin(t), az) for t in [k * 2 * math.pi / 8 for k in range(9)]]
    B.piece(tube(ring, [0.025] * 9, seg_n=5, cap=False), paint='lama', bone='root', hull=False)
    # rolo de corda
    rx, rz = -2.9, 1.9
    pts = [G(rx + (0.32 - 0.012 * t) * math.cos(t * 0.9), 0.05 + 0.035 * (t // 7), rz + (0.32 - 0.012 * t) * math.sin(t * 0.9)) for t in range(0, 22)]
    B.piece(tube(pts, [0.035] * len(pts), seg_n=5), paint={'base': 'miriti_som', 'pat': 'listras', 'c1': 'tabua_ocre', 's': 0.04, 'w': 0.5, 'axis': (1, 1, 0)}, bone='root', hull=False)
    # cesto de peixe e balde perto da borda
    cb = loft([(0, 0.2, 0.2, 0, 2.0), (0.3, 0.26, 0.26, 0, 2.0)], seg_n=9, cap_top=False)
    B.piece(place(cb, G(-7.8, 0, 1.6)), paint={'base': 'miriti_som', 'pat': 'listras', 'c1': 'lama', 's': 0.06, 'w': 0.4, 'axis': (0, 0, 1)}, bone='root', hull=False)

def build_tralha_chao(B, rng):
    # tralha que a cheia trouxe, largada no piso: bicheiro, remo partido, rede embolada, balde, tampinhas
    B.piece(post((-1.9, 0.05, 2.25), (-0.5, 0.05, 1.95), 0.025, seg=6), paint={'base': 'tabua_ocre', 'wear': 1.0}, bone='root', hull=False)
    hk = [G(-0.5 + 0.14 * math.sin(t), 0.05, 1.95 - 0.14 + 0.14 * math.cos(t)) for t in [math.radians(a) for a in range(0, 240, 30)]]
    B.piece(tube(hk, [0.025] * len(hk), seg_n=5), paint={'base': 'ferrugem', 'wear': 1.0}, bone='root', hull=False)
    B.piece(post((3.0, 0.04, 2.3), (4.0, 0.04, 2.05), 0.024, seg=6), paint={'base': 'tabua_azul', 'pat': 'faixas', 'c1': 'miriti', 'axis': (1, 0, 0), 'bands': [(3.3, 3.4)], 'wear': 1.0}, bone='root', hull=False)
    pa = loft([(0.0, 0.03, 0.02, 0, 2.0), (0.08, 0.08, 0.022, 0, 2.6), (0.22, 0.09, 0.022, 0, 3.0), (0.26, 0.05, 0.02, 0, 2.0)], seg_n=7)
    xform(pa, Matrix.Translation(G(4.0, 0.04, 2.05)) @ Matrix.Rotation(math.radians(-104), 4, 'Z') @ Matrix.Rotation(math.radians(90), 4, 'X'))
    B.piece(pa, paint={'base': 'tabua_ocre', 'pat': 'listras', 'c1': 'tabua_rosa', 's': 0.08, 'w': 0.4, 'axis': (1, 1, 0), 'wear': 1.0}, bone='root', jitter=0.003, hull=False)
    rede = loft([(0.0, 0.5, 0.35, 0, 2.0), (0.08, 0.45, 0.32, 0, 2.2), (0.16, 0.25, 0.2, 0, 2.0), (0.2, 0.06, 0.06, 0, 2.0)], seg_n=10)
    place(rede, G(-5.4, 0.0, 1.9))
    B.piece(rede, paint={'base': 'tabua_verde', 'pat': ['listras', 'listras'], 'pats': [{'c1': 'miriti_som', 's': 0.06, 'w': 0.25, 'axis': (1, 1, 0.3)}, {'c1': 'miriti_som', 's': 0.06, 'w': 0.25, 'axis': (1, -1, 0.3)}], 'wear': 0.6},
            bone='root', jitter=0.02, mat='pano', hull=False)
    for k in range(5):
        a = rng.uniform(0, 6.28)
        B.piece(place(loft([(0, 0.035, 0.035, 0, 2.0), (0.015, 0.035, 0.035, 0, 2.0)], seg_n=7), G(-5.0 + 0.6 * math.cos(a), 0.0, 1.3 + 0.4 * math.sin(a))),
                paint={'base': rng.choice(['tabua_rosa', 'tabua_azul', 'miriti_som']), 'wear': 0.5}, bone='root', hull=False)
    bal = loft([(0, 0.13, 0.13, 0, 2.0), (0.26, 0.17, 0.17, 0, 2.0)], seg_n=8, cap_top=False)
    B.piece(place(bal, G(5.3, 0, 1.4)), paint={'base': 'tabua_azul', 'pat': 'faixas', 'c1': 'miriti', 'axis': (0, 0, 1), 'bands': [(0.18, 0.21)], 'wear': 1.0}, bone='root', jitter=0.004, hull=False)

# ------------------------------------------------------------------ fundo: balsa com guindaste, casa flutuante, canoas
def canoa(B, c, L, yaw, rng, col):
    """canoa facetada: casco cheio (meia-elipse com borda reta) e o fundo de dentro em lama, um degrau abaixo da borda."""
    x, y, z = c
    rings = []
    for k in range(9):
        t = k / 8
        wdt = 0.36 * math.sin(math.pi * (0.06 + 0.88 * t)) + 0.02
        rings.append((t * L - L / 2, wdt, 0.22, 0.0, 2.6))
    bm = loft(rings, seg_n=10, cap_bot=True, cap_top=True)
    xform(bm, Matrix.Rotation(math.radians(90), 4, 'Y'))
    for v in bm.verts:   # achata a metade de cima: vira a borda da canoa
        if v.co.z > 0.0:
            v.co.z = 0.0
        v.co.z += 0.12 * (abs(v.co.x) / (L / 2)) ** 3
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.002)
    xform(bm, Matrix.Translation(G(x, y, z)) @ Matrix.Rotation(math.radians(yaw), 4, 'Z'))
    B.piece(bm, paint={'base': col, 'pat': 'faixas', 'c1': 'tabua_rosa', 'axis': (0, 0, 1), 'bands': [(y - 0.06, y - 0.02)], 'wear': 1.0, 'mancha': 0.8}, bone='root', jitter=0.004, hull=False)
    inner = []
    for k in range(9):
        t = k / 8
        wdt = (0.36 * math.sin(math.pi * (0.06 + 0.88 * t)) + 0.02) * 0.78
        inner.append((t * L * 0.86 - L * 0.43, wdt, 0.01, 0.0, 2.6))
    fl = loft(inner, seg_n=10)
    xform(fl, Matrix.Rotation(math.radians(90), 4, 'Y'))
    xform(fl, Matrix.Translation(G(x, y + 0.012, z)) @ Matrix.Rotation(math.radians(yaw), 4, 'Z'))
    B.piece(fl, paint={'base': 'lama', 'pat': 'listras', 'c1': 'miriti_som', 's': 0.3, 'w': 0.08, 'axis': (1, 0, 0), 'wear': 0.5}, bone='root', hull=False)
    for k in (-0.25, 0.1):
        B.piece(box((x + k * L, y + 0.02, z), (0.1, 0.04, 0.62), (0, yaw, 0), bevel=0.2), paint={'base': 'miriti_som', 'cru': True}, bone='root', hull=False)

def build_fundo(B, rng):
    # balsa com guindaste de madeira (direita, atrás)
    gx, gz = 5.6, -5.8
    B.piece(box((gx, -0.45, gz), (6.5, 0.5, 2.8), bevel=0.12), paint={'base': 'tabua_azul', 'wear': 1.0, 'mancha': 1.0}, bone='root', jitter=0.01, hull=False)
    for k in range(6):
        B.piece(box((gx - 3 + k * 1.2, -0.16, gz), (1.1, 0.06, 2.7), bevel=0.2), paint={'base': rng.choice(FADED), 'wear': 1.0, 'mancha': 0.8}, bone='root', jitter=0.004, hull=False)
    mx = gx + 1.2
    B.piece(post((mx, -0.15, gz), (mx, 4.2, gz + 0.1), 0.13, 0.1, seg=7), paint={'base': 'tabua_ocre', 'wear': 1.0, 'mancha': 0.6}, bone='root', jitter=0.006, hull=False)
    for s in (-1, 1):
        B.piece(post((mx + s * 1.0, -0.15, gz + 0.9), (mx, 2.4, gz + 0.1), 0.06, seg=6), paint={'base': 'lama', 'wear': 0.8}, bone='root', hull=False)
    boom_top = (gx - 3.6, 5.2, gz + 3.2)
    B.piece(post((mx, 0.6, gz + 0.1), boom_top, 0.1, 0.07, seg=7), paint={'base': 'tabua_ocre', 'pat': 'faixas', 'c1': 'ferrugem', 'axis': (-0.6, 0.5, 0.5), 'bands': [(1.0, 1.3), (2.5, 2.8)], 'wear': 1.0}, bone='root', jitter=0.006, hull=False)
    B.piece(post((mx, 4.1, gz + 0.1), boom_top, 0.02, seg=4), paint='lama', bone='root', hull=False)
    hook_y = 1.9
    B.piece(post(boom_top, (boom_top[0], hook_y, boom_top[2]), 0.018, seg=4), paint='miriti_som', bone='root', hull=False)
    hk = [G(boom_top[0] + 0.25 * math.sin(t), hook_y - 0.25 + 0.25 * math.cos(t), boom_top[2]) for t in [math.radians(a) for a in range(0, 230, 30)]]
    B.piece(tube(hk, [0.045] * len(hk), seg_n=6), paint={'base': 'ferrugem', 'wear': 1.0}, bone='root', jitter=0.003, hull=False)
    B.piece(box((mx + 0.9, 0.35, gz - 0.3), (1.0, 0.9, 1.0), bevel=0.15), paint={'base': 'inchado_esc', 'pat': 'faixas', 'c1': 'tabua_ocre', 'axis': (0, 0, 1), 'bands': [(0.6, 0.7)], 'wear': 1.0}, bone='root', jitter=0.01, hull=False)
    # casa flutuante (esquerda, atrás)
    hx, hz = -6.0, -6.4
    B.piece(box((hx, -0.45, hz), (4.4, 0.4, 3.0), bevel=0.12), paint={'base': 'lama', 'wear': 1.0, 'mancha': 1.0}, bone='root', jitter=0.01, hull=False)
    for k in range(11):
        xx = hx - 1.8 + k * 0.36
        B.piece(box((xx, 1.0, hz + 0.9), (0.34, 2.3, 0.08), bevel=0.2), paint={'base': 'tabua_verde', 'wear': 1.0, 'mancha': 0.7}, bone='root', jitter=0.004, hull=False)
    for sx in (-1, 1):
        B.piece(box((hx + sx * 1.95, 1.0, hz), (0.08, 2.3, 1.8), bevel=0.2), paint={'base': 'tabua_verde', 'wear': 1.0, 'mancha': 0.7}, bone='root', jitter=0.004, hull=False)
    B.piece(box((hx - 0.6, 1.25, hz + 0.95), (0.8, 0.7, 0.04), bevel=0.2), paint={'base': 'lama', 'wear': 1.0, 'mancha': 0.5}, bone='root', hull=False)
    B.piece(box((hx + 0.9, 0.85, hz + 0.95), (0.7, 1.5, 0.04), bevel=0.2), paint={'base': 'tabua_rosa', 'wear': 1.0}, bone='root', hull=False)
    for sx in (-1, 1):
        rf = box((hx + sx * 1.15, 2.55, hz + 0.1), (2.5, 0.08, 2.4), (0, 0, -sx * 28), bevel=0.15)
        B.piece(rf, paint={'base': 'ferrugem', 'pat': 'listras', 'c1': 'lama', 's': 0.2, 'w': 0.35, 'axis': (0, 0, 1), 'wear': 1.0, 'mancha': 0.6}, bone='root', jitter=0.01, hull=False)
    # canoas amarradas atrás do trapiche
    canoa(B, (-1.0, -0.5, -3.6), 4.2, 6, rng, 'tabua_azul')
    canoa(B, (1.6, -0.5, -4.4), 3.6, -10, rng, 'tabua_ocre')
    for x in (-3.0, 0.6, 9.5):
        B.piece(post((x, -2.0, -3.4), (x, 0.4, -3.4), 0.09, seg=7), paint={'base': 'lama', 'mancha': 1.0, 'wear': 0.8}, bone='root', jitter=0.006, hull=False)

def build_frente(B, rng):
    # canoa no primeiro plano (esquerda) e poste de amarração (direita)
    canoa(B, (-4.6, -0.5, 4.1), 4.6, -6, rng, 'tabua_verde')
    B.piece(post((3.9, -2.0, 3.55), (3.9, 0.9, 3.55), 0.2, 0.17, seg=8), paint={'base': 'tabua_ocre', 'descasca': 0.4, 'sob': 'lama', 'wear': 1.0, 'mancha': 1.0}, bone='root', jitter=0.012, hull=False)
    B.piece(limb(G(3.9, 0.88, 3.55), G(3.9, 1.02, 3.55), 0.2, 0.12, seg_n=8, rings=2), paint={'base': 'tabua_azul', 'wear': 1.0}, bone='root', jitter=0.006, hull=False)
    for k in range(3):
        ring = [G(3.9 + 0.23 * math.cos(t), 0.45 + 0.08 * k + 0.05 * math.sin(t * 2), 3.55 + 0.23 * math.sin(t)) for t in [j * 2 * math.pi / 10 for j in range(11)]]
        B.piece(tube(ring, [0.035] * 11, seg_n=5, cap=False), paint={'base': 'miriti_som', 'pat': 'listras', 'c1': 'tabua_ocre', 's': 0.05, 'w': 0.5, 'axis': (1, 1, 0)}, bone='root', hull=False)
    rope = [G(3.9, 0.5, 3.35), G(3.3, 0.0, 3.2), G(2.6, -0.1, 3.05), G(2.0, 0.0, 2.95)]
    B.piece(tube(rope, [0.03] * 4, seg_n=5), paint='miriti_som', bone='root', hull=False)

def marola_strip(B, x0, x1, z, h, col, rng, kind=0):
    """marola recortada: uma faixa de pétalas pontudas (cristas), em pé na água, pintada chapada."""
    bm = bmesh.new()
    pts = [(x0, -0.9)]
    x = x0
    k = 0
    while x < x1:
        wv = rng.uniform(0.5, 0.75)
        if kind == 0:
            pts += [(x + wv * 0.35, h * rng.uniform(0.8, 1.05)), (x + wv * 0.5, h * 0.55), (x + wv, h * 0.1)]
        else:
            pts += [(x + wv * 0.5, h * rng.uniform(0.85, 1.0)), (x + wv, h * 0.25)]
        x += wv
        k += 1
    pts += [(x, -0.9)]
    front = [bm.verts.new(G(px, py - 0.55, z)) for px, py in pts]
    bm.faces.new(front)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.05)
    B.piece(bm, paint={'base': col, 'pat': 'faixas', 'c1': 'rio_claro' if col != 'rio_claro' else 'miriti', 'axis': (0, 0, 1), 'bands': [(-0.55 + h * 0.45, -0.55 + h * 0.6)], 'wear': 0.5},
            bone='root', hull=False)

def build_marolas(B, rng, rows):
    for (z, h, col, kind) in rows:
        x = -14.0
        while x < 14.0:
            x1 = x + 5.0
            marola_strip(B, x, x1, z, h, col, rng, kind)
            x = x1

GROUPS = {
    'trapiche': (lambda B, r: build_trapiche(B, r), 170.0, 4096),
    'objetos': (lambda B, r: (build_objetos(B, r), build_tralha_chao(B, r)), 220.0, 4096),
    'fundo': (lambda B, r: build_fundo(B, r), 130.0, 4096),
    'frente': (lambda B, r: build_frente(B, r), 200.0, 2048),
    'marolas_f': (lambda B, r: build_marolas(B, r, [(3.35, 0.32, 'rio_medio', 0), (4.6, 0.36, 'rio_claro', 1)]), 110.0, 2048),
    'marolas_t': (lambda B, r: build_marolas(B, r, [(-3.3, 0.3, 'rio_claro', 1), (-4.9, 0.32, 'rio_medio', 0), (-7.4, 0.36, 'rio_claro', 1)]), 90.0, 2048),
}

if __name__ == '__main__':
    PROJ = sys.argv[1]
    only = sys.argv[2:]
    stats = {}
    for name, (fn, dens, W) in GROUPS.items():
        if only and name not in only:
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        t0 = time.time()
        import zlib
        rng = random.Random(zlib.crc32(name.encode()) % 1000 + 7)   # v2: semente estável (hash() de str muda a cada processo)
        B = Builder(5, ['root'], outline=0.0)
        fn(B, rng)
        t1 = time.time()
        d, size = PT.bake(B, os.path.join(PROJ, 'assets', 'tex', name + '.png'), dens=dens, W=W, maxH=4096, pad=2)
        t2 = time.time()
        _, ob = assemble(B, name, armature=False)
        bpy.ops.object.select_all(action='DESELECT')
        ob.select_set(True)
        path = os.path.join(PROJ, 'assets', 'glb', name + '.glb')
        bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_vertex_color='NAME', export_vertex_color_name='Col',
                                  export_materials='EXPORT', export_yup=True, export_animations=False)
        me = ob.data
        me.calc_loop_triangles()
        stats[name] = dict(tris=len(me.loop_triangles), pecas=len(B.specs), atlas=list(size), dens=round(d), t_build=round(t1 - t0, 2), t_tinta=round(t2 - t1, 2))
        print(name, stats[name], flush=True)
    p = os.path.join(PROJ, 'assets', 'glb', 'cenario_stats.json')
    prev = json.load(open(p)) if os.path.exists(p) else {}
    prev.update(stats)
    json.dump(prev, open(p, 'w'), indent=1)

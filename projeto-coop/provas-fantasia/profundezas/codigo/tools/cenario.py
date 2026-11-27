# Cenário da Mata de Lume (Andar 1), tudo por código: o terraço de musgo com a poça e as lajes do acampamento
# queimado, os degraus que descem até a floresta de fungos, o Poço, a parede distante da caverna, rochas,
# fungos gigantes e pequenos, tufos de musgo e grama de maquete, a coluna de pedra com a estaca da guilda,
# a Cascata do Beiral, o Sino de Thessimor lá embaixo e as posições de instâncias em mundo.json.
# Coordenadas do Blender (Z para cima; a câmera olha para +Y). O glTF vira Y-up com -Y do Blender = +Z do Godot.
# Terreno: cor de vértice (pedra escovada, musgo, terra), UV2 = (oclusão, curvatura) para o pincel seco em 3 degraus.
import sys, os, math, json, random, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import bpy, bmesh
from mathutils import Vector, Matrix, noise
from malha import hexc, MATS, Builder, loft, place, mk, xform, tube
import montar as MT

PROJ = sys.argv[1] if len(sys.argv) > 1 else '../proj'
GLB = os.path.join(PROJ, 'assets', 'glb'); os.makedirs(GLB, exist_ok=True)
RNG = np.random.default_rng(1234)

def lin(h):
    return np.array(hexc(h)[:3])

# ------------------------------------------------------------------ ruído
def fbm(x, y, oct=4, seed=0):
    out = np.zeros_like(x)
    a, f = 1.0, 1.0
    for o in range(oct):
        out += a * np.vectorize(lambda u, v: noise.noise(Vector((u * f, v * f, seed * 7.31 + o * 3.1))))(x, y)
        a *= 0.5; f *= 2.03
    return out

def smooth(t):
    t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)

def blur(a, r):
    from numpy.lib.stride_tricks import sliding_window_view
    p = np.pad(a, r, mode='edge')
    k = 2 * r + 1
    c = np.cumsum(np.cumsum(p, 0), 1)
    c = np.pad(c, ((1, 0), (1, 0)))
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return s / (k * k)

# ------------------------------------------------------------------ exportação de malha estática (numpy -> GLB)
def mesh_obj(name, V, F, C, UV2, UV1=None, mat='cor'):
    me = bpy.data.meshes.new(name)
    me.vertices.add(len(V)); me.vertices.foreach_set('co', V.astype(np.float32).ravel())
    nl = F.shape[1]
    me.loops.add(len(F) * nl); me.loops.foreach_set('vertex_index', F.astype(np.int32).ravel())
    me.polygons.add(len(F)); me.polygons.foreach_set('loop_start', np.arange(0, len(F) * nl, nl, dtype=np.int32))
    me.update(calc_edges=True)
    for p in me.polygons: p.use_smooth = True
    ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    ca.data.foreach_set('color', np.concatenate([C, np.ones((len(C), 1))], 1).astype(np.float32).ravel())
    li = F.astype(np.int32).ravel()
    u1 = me.uv_layers.new(name='UVMap')
    u1.data.foreach_set('uv', (UV1 if UV1 is not None else np.zeros((len(V), 2)))[li].astype(np.float32).ravel())
    u2 = me.uv_layers.new(name='UV2')
    u2.data.foreach_set('uv', UV2[li].astype(np.float32).ravel())
    m = bpy.data.materials.get(mat) or bpy.data.materials.new(mat)
    me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob

def export(objs, name):
    for o in bpy.context.scene.objects: o.select_set(False)
    for o in objs: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(GLB, name + '.glb'), export_format='GLB', use_selection=True,
                              export_vertex_color='NAME', export_vertex_color_name='Col', export_all_vertex_colors=True, export_texcoords=True,
                              export_materials='EXPORT', export_yup=True, export_animations=False, export_skins=False)
    for o in objs:
        bpy.data.objects.remove(o)
    print('exportado', name, flush=True)

def grid(x0, x1, y0, y1, res):
    xs = np.arange(x0, x1 + 1e-6, res); ys = np.arange(y0, y1 + 1e-6, res)
    X, Y = np.meshgrid(xs, ys)
    return X, Y

def faces_grid(ny, nx):
    i = np.arange(ny - 1)[:, None] * nx + np.arange(nx - 1)[None, :]
    return np.stack([i, i + 1, i + nx + 1, i + nx], -1).reshape(-1, 4)

def paint_terrain(X, Y, Z, res, extra=None, wet=None):
    """cor de vértice por inclinação e ruído; oclusão por altura relativa; curvatura por laplaciano."""
    gy, gx = np.gradient(Z, res)
    slope = np.sqrt(gx ** 2 + gy ** 2)
    n = fbm(X * 0.8, Y * 0.8, 3, seed=4) * 0.7 + fbm(X * 0.2, Y * 0.2, 2, seed=14) * 0.5
    n2 = fbm(X * 1.7, Y * 1.7, 2, seed=8)
    stone_a, stone_b, stone_c = lin('ardosia_funda'), lin('ardosia'), lin('aresta_pedra')
    moss, moss2 = lin('musgo'), lin('#3E5A3A')
    soil = lin('#3A3430')
    st = np.where((n2 > 0.25)[..., None], stone_b * 1.05, stone_b * 0.85)
    flat = smooth((0.55 - slope) / 0.35)
    mossk = flat * smooth((n - 0.12) / 0.2) * 0.85
    C = st * (1 - mossk[..., None]) + (moss * (1 - smooth(n2)[..., None]) + moss2 * smooth(n2)[..., None]) * mossk[..., None]
    if wet is not None:
        C = C * (1 - wet[..., None]) + soil * wet[..., None]
    # oclusão (vãos) por altura relativa em duas escalas
    k1 = max(1, int(round(1.0 / res))); k2 = max(1, int(round(4.0 / res)))
    d = (Z - blur(Z, k1)) * 1.2 + (Z - blur(Z, k2)) * 0.25
    ao = np.clip(0.8 + d * 1.6 / max(res, 0.25) ** 0.3, 0.15, 1.0)
    lap = (blur(Z, k1) - Z)
    curv = np.clip(-lap * 6.0 / max(res, 0.25) ** 0.5, -1, 1)
    return C, ao, curv

# ================================================================== LAYOUT AUTORADO (v2)
# Tudo em coordenadas do Blender (x, y; a câmera olha para +y). Trilhas batidas que saem da tela, a ruína de
# Thessimor (piso que desabou e abriu a descida para um Cofre), a ponte de tronco de fungo sobre a fenda, o
# guincho da guilda na beira do penhasco e as colônias de fungo presas a umidade e fendas.
TRILHAS = [
    [(-3.6, -18.0), (-3.0, -9.0), (-2.4, -4.6), (-4.4, -1.6), (-5.2, 0.2)],                       # vem de trás da câmera até a ruína
    [(-2.4, -4.6), (0.6, -4.3), (4.4, -3.0), (5.2, -0.4), (5.0, 3.0), (9.4, 3.2), (10.4, 3.4)],    # contorna a poça, cruza a ponte, chega ao guincho
    [(10.4, 3.4), (14.0, 2.2), (20.0, 2.6), (30.0, 3.6)],                                            # segue a beira e sai pela direita
    [(-5.2, 0.2), (-9.0, -1.4), (-12.0, -0.4), (-16.0, 2.4), (-22.0, 6.0)],                          # sobe pela rampa da parede e sai pela esquerda
]
RUINA = dict(x0=-10.6, x1=-4.4, y0=-0.6, y1=4.0, poco=(-7.4, 1.9), r=1.25, ang=0.14)
PONTE = ((5.1, 3.0), (9.6, 3.1))
GUINCHO = (10.6, 4.25)
COLONIAS = [(-12.8, -3.2, 'parede'), (-9.6, 4.3, 'ruina'), (8.9, -0.9, 'fenda'), (-1.4, 6.0, 'beira'), (12.6, -4.6, 'parede'),
            (-6.4, -8.0, 'frente'), (6.4, -7.6, 'frente'), (3.4, 7.2, 'beira'), (-17.0, 5.0, 'parede')]

def dist_trilha(X, Y):
    d = np.full(X.shape, 1e9)
    for tr in TRILHAS:
        for (ax, ay), (bx, by) in zip(tr[:-1], tr[1:]):
            vx, vy = bx - ax, by - ay
            L2 = vx * vx + vy * vy
            t = np.clip(((X - ax) * vx + (Y - ay) * vy) / L2, 0, 1)
            d = np.minimum(d, np.hypot(X - ax - t * vx, Y - ay - t * vy))
    return d

def em_ruina(X, Y, m=0.0):
    R = RUINA
    return (X > R['x0'] - m) & (X < R['x1'] + m) & (Y > R['y0'] - m) & (Y < R['y1'] + m)

# ================================================================== o TERRAÇO (plano de jogo e degraus)
def h_terraco(X, Y):
    e = 4.6 + 1.4 * fbm(X * 0.07, X * 0.0 + 3.0, 3, seed=1)            # borda do terraço (em y)
    jag = 0.6 * fbm(X * 0.4, Y * 0.4, 2, seed=2)
    Z = 0.12 * fbm(X * 0.18, Y * 0.18, 3, seed=3)
    # a poça: bacia rasa
    r2 = ((X - 0.3) / 4.4) ** 2 + ((Y + 0.2) / 3.0) ** 2
    Z -= 0.16 * np.exp(-r2 * 1.6)
    # degraus: -5 m, -12 m, depois o penhasco até a floresta
    t = Y - e + jag
    Z -= 3.2 * smooth(t / 1.2)
    Z -= 52.0 * smooth((t - 4.5) / 5.0)
    Z += 0.5 * fbm(X * 0.25, Y * 0.25, 3, seed=5) * smooth(t / 1.0)
    # parede rochosa à esquerda (moldura natural) e subida à direita
    Z += 7.5 * smooth((-X - 15.0) / 6.0) * (1 + 0.4 * fbm(X * 0.2, Y * 0.2, 2, seed=6))
    Z += 2.5 * smooth((X - 17.0) / 6.0)
    Z -= 60.0 * smooth((np.abs(X) - 30.0 + 2.0 * fbm(Y * 0.1, X * 0.0 + 9.0, 2, seed=15)) / 4.0)
    # a FENDA: rasgo estreito que vai da poça até a beirada; lá embaixo, o Sino
    cx = 6.6 + 0.6 * np.sin(Y * 0.5)
    w = 0.85 + 0.25 * fbm(Y * 0.5, X * 0.0, 2, seed=7)
    infenda = smooth((w - np.abs(X - cx)) / 0.35) * smooth((Y + 1.2) / 1.5)
    Z = Z * (1 - infenda) + (-45.0) * infenda
    # v2: trilha batida (rebaixo de 4 cm com bordas), piso da ruína nivelado e o poço do desabamento
    dtr = dist_trilha(X, Y)
    Z -= 0.045 * smooth((0.75 - dtr) / 0.35)
    R = RUINA
    kr = smooth((0.6 - np.maximum(np.maximum(R['x0'] - X, X - R['x1']), np.maximum(R['y0'] - Y, Y - R['y1']))) / 0.9)
    Z = Z * (1 - kr * 0.85) + (-0.08) * kr * 0.85
    rp = np.hypot(X - R['poco'][0], (Y - R['poco'][1]) * 1.15) + 0.25 * fbm(X * 1.3, Y * 1.3, 2, seed=21)
    Z -= 9.0 * smooth((R['r'] + 0.15 - rp) / 0.45)
    return Z

def fluxo(Z):
    """acúmulo de fluxo D8: cada célula manda a água para o vizinho mais baixo (de cima para baixo)."""
    ny, nx = Z.shape
    pad = np.pad(Z, 1, constant_values=1e9)
    offs = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
    st = np.stack([pad[1 + dy:1 + dy + ny, 1 + dx:1 + dx + nx] + 0.0 * (abs(dy) + abs(dx) == 2) for dy, dx in offs], 0)
    k = np.argmin(st, 0)
    mn = np.min(st, 0)
    iy, ix = np.mgrid[0:ny, 0:nx]
    ty = iy + np.array([o[0] for o in offs])[k]; tx = ix + np.array([o[1] for o in offs])[k]
    tgt = np.where(mn < Z, ty * nx + tx, -1).ravel()
    acc = np.ones(ny * nx)
    order = np.argsort(-Z.ravel(), kind='stable')
    for i in order:
        t = tgt[i]
        if t >= 0:
            acc[t] += acc[i]
    return acc.reshape(ny, nx)

def paint_terraco(X, Y, Z, res):
    """v2: pintura com causa. Pedra seca nas lombadas, pedra molhada e escura nos regos que levam a água para a
    poça e para o penhasco, musgo onde é côncavo e úmido (pé da parede, regos, beira da poça), terra batida
    nas trilhas, cal e pó claro no piso da ruína."""
    C0, ao, curv = paint_terrain(X, Y, Z, res)
    gy, gx = np.gradient(Z, res)
    slope = np.sqrt(gx ** 2 + gy ** 2)
    acc = fluxo(Z)
    # regos: só onde a água de verdade se junta (acúmulo de 30 a 900 células), finos e ramificados
    la = np.log(acc)
    rego = smooth((la - math.log(30)) / (math.log(900) - math.log(30)))
    margem = np.clip(blur(rego, 2) * 2.5, 0, 1)
    k1 = max(1, int(round(1.5 / res)))
    conc = np.clip((blur(Z, k1) - Z) * 9.0, -1, 1)
    r2 = ((X - 0.3) / 4.4) ** 2 + ((Y + 0.2) / 3.0) ** 2
    beira_poca = np.exp(-np.maximum(r2 - 1.0, 0) * 3.0) * (r2 > 0.8)
    Xw = X + 2.2 * fbm(Y * 0.18, X * 0.05, 2, seed=37)
    pe_parede = smooth((-Xw - 12.5) / 1.5) * (1 - smooth((-Xw - 16.5) / 1.5)) + 0.7 * smooth((Xw - 15.0) / 1.5) * (1 - smooth((Xw - 18.5) / 1.5))
    dtr = dist_trilha(X, Y)
    trilha = smooth((0.62 - dtr) / 0.3) * (0.75 + 0.25 * smooth(fbm(X * 2.2, Y * 2.2, 2, seed=31) + 0.4))
    umido = np.clip(rego + beira_poca * 0.8 + pe_parede * 0.5, 0, 1)
    n = fbm(X * 0.55, Y * 0.55, 3, seed=33)
    flat = smooth((0.6 - slope) / 0.4)
    musgo = smooth((margem * 0.9 + beira_poca * 0.6 + pe_parede * 0.9 + np.maximum(conc, 0) * 1.3 + n * 0.35 - 0.42) / 0.2) * flat * (1 - trilha)
    # pedra: ardósia neutra (menos azul), lombadas secas mais claras e com líquen
    base = lin('ardosia') * 0.55 + lin('#4E4C4A') * 0.45
    pedra = base * (0.94 + 0.12 * smooth(fbm(X * 0.9, Y * 0.9, 2, seed=34) + 0.5))[..., None]
    lomba = smooth((-conc - 0.15) / 0.3) * (1 - umido)
    pedra = pedra * (1 - lomba[..., None] * 0.25) + lin('aresta_pedra') * lomba[..., None] * 0.25
    liquen = smooth((fbm(X * 1.1, Y * 1.1, 2, seed=36) - 0.3) / 0.08) * lomba * 0.45
    pedra = pedra * (1 - liquen[..., None]) + lin('#8A8A70') * liquen[..., None]
    molhada = lin('ardosia_funda') * 0.8
    C = pedra * (1 - umido[..., None] * 0.8) + molhada * umido[..., None] * 0.8
    mus = lin('musgo') * (1 - smooth(n + 0.2)[..., None]) + lin('#41603C') * smooth(n + 0.2)[..., None]
    mus = mus * (1 - umido[..., None] * 0.3) + lin('#24382A') * umido[..., None] * 0.3
    C = C * (1 - musgo[..., None]) + mus * musgo[..., None]
    terra = lin('#4C4640') * (0.9 + 0.2 * smooth(fbm(X * 3.0, Y * 3.0, 2, seed=35) + 0.5))[..., None]
    C = C * (1 - trilha[..., None]) + terra * trilha[..., None]
    R = RUINA
    rui = em_ruina(X, Y, 0.5).astype(float) * smooth((np.hypot(X - R['poco'][0], Y - R['poco'][1]) - R['r'] - 0.3) / 0.6)
    C = C * (1 - rui[..., None] * 0.4) + lin('#55524C') * rui[..., None] * 0.4
    fundo = smooth((-Z - 0.6) / 1.2) * smooth((3.0 - np.hypot(X - R['poco'][0], Y - R['poco'][1])))
    C = C * (1 - fundo[..., None] * 0.85) + lin('primer') * fundo[..., None] * 0.85
    masks = dict(musgo=musgo, umido=umido, trilha=trilha, rego=rego)
    return C, ao, curv, masks

TERR = {}
def build_terraco():
    res = 0.25
    X, Y = grid(-40, 40, -16, 34, res)
    Z = h_terraco(X, Y)
    C, ao, curv, masks = paint_terraco(X, Y, Z, res)
    TERR.update(X=X, Y=Y, Z=Z, res=res, **masks)
    V = np.stack([X, Y, Z], -1).reshape(-1, 3)
    F = faces_grid(*X.shape)
    ob = mesh_obj('terraco', V, F, C.reshape(-1, 3), np.stack([ao, curv], -1).reshape(-1, 2))
    export([ob], 'terraco')
    return X, Y, Z

def build_abismo():
    res = 5.0
    X, Y = grid(-560, 560, -60, 980, res)
    n = fbm(X * 0.012, Y * 0.012, 4, seed=11)
    floor = -92.0 - np.maximum(Y - 20, 0) * 0.4 + 9 * n
    poco = -140 - np.maximum(Y - 160, 0) * 2.0 + 30 * n
    Z = np.where(Y < 160, floor, np.minimum(floor, poco))
    Z = np.maximum(Z, -950)
    wall = -950 + np.maximum(Y - 700, 0) * 9.0 + 60 * fbm(X * 0.02, Y * 0.02, 3, seed=12)
    side = -950 + np.maximum(np.abs(X) - 300, 0) * 6.0 + 40 * n
    Z = np.maximum(Z, np.maximum(wall, side))
    Z = np.minimum(Z, 300)
    # ressaltos (terraços naturais) nas paredes distantes
    Z += 18 * np.round(fbm(X * 0.01, Y * 0.01, 2, seed=13) * 2) * (Y > 650)
    C, ao, curv = paint_terrain(X, Y, Z, res)
    V = np.stack([X, Y, Z], -1).reshape(-1, 3)
    F = faces_grid(*X.shape)
    ob = mesh_obj('abismo', V, F, C.reshape(-1, 3), np.stack([ao, curv], -1).reshape(-1, 2))
    export([ob], 'abismo')
    return X, Y, Z

# ================================================================== peças instanciadas (Builder + montar.bake)
def builder_export(B, name, ao_dist=0.6, curv_scale=0.03):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    B.bones = [('root', (0, 0, 0), (0, 0, 0.1), None)]
    arm, ob = MT.assemble(B, name, armature=False, bake_kw=dict(ao_dist=ao_dist, curv_scale=curv_scale))
    bpy.ops.export_scene.gltf(filepath=os.path.join(GLB, name + '.glb'), export_format='GLB',
                              export_vertex_color='NAME', export_vertex_color_name='Col', export_all_vertex_colors=True, export_texcoords=True,
                              export_materials='EXPORT', export_yup=True, export_animations=False, export_skins=False)
    print('exportado', name, flush=True)

def rocha(seed, s=1.0):
    B = Builder(seed, ['root'], outline=0.0); B.wash = 'azul_negro'
    rr = random.Random(seed)
    bm = mk('ico', sub=2)
    off = Vector((rr.random() * 9, rr.random() * 9, rr.random() * 9))
    for v in bm.verts:
        p = v.co.copy()
        d = 1 + 0.35 * noise.noise(p * 1.3 + off) + 0.12 * noise.noise(p * 3.7 + off)
        v.co = p * d
        v.co.z *= 0.62
        # facetas planas de pedra lascada (corte em degraus)
        v.co.z = math.floor(v.co.z * 4) / 4 * 0.35 + v.co.z * 0.65
    place(bm, (0, 0, 0.15), (s, s * rr.uniform(0.7, 1.1), s))
    B.piece(bm, paint='ardosia', bone='root', hull=False, sub=False)
    return B

def fungo(seed, kind='grande', estado='inteiro'):
    """fungo com forma de cogumelo de verdade: haste com anel e véu, chapéu translúcido com lamelas por baixo.
    estado: 'inteiro', 'rasgado' (chapéu comido em gomos) ou 'podre' (chapéu caído, haste torta, manchas)."""
    B = Builder(seed, ['root'], outline=0.0); B.wash = 'azul_negro'
    rr = random.Random(seed)
    H = 1.0
    lean = rr.uniform(-0.12, 0.12) + (0.22 if estado == 'podre' else 0.0)
    stem = [(0.0, 0.11, 0.11, 0, 2.0), (0.05, 0.08, 0.08, 0, 2.0), (0.4, 0.06, 0.06, 0, 2.0), (0.8, 0.055, 0.055, 0, 2.0), (0.92, 0.06, 0.06, 0, 2.0)]
    st = loft(stem, seg_n=10)
    for v in st.verts:
        v.co.x += lean * v.co.z ** 2
    B.piece(st, paint='osso' if kind == 'grande' else 'gesso', bone='root', hull=False)
    # anel (véu rasgado)
    an = loft([(0.0, 0.075, 0.075, 0, 2.0), (0.025, 0.1, 0.1, 0, 2.0), (0.035, 0.11, 0.11, 0, 2.0)], seg_n=12, cap_bot=False, cap_top=False)
    bmesh.ops.solidify(an, geom=an.faces[:], thickness=0.008)
    for v in an.verts:
        v.co.z -= 0.02 * abs(math.sin(math.atan2(v.co.y, v.co.x) * 4))
    B.piece(place(an, (lean * 0.55, 0, 0.7)), paint='osso', bone='root', hull=False)
    # chapéu: domo de resina translúcida (material 'resina')
    R = rr.uniform(0.32, 0.42)
    cap = loft([(0.0, R, R, 0, 2.0), (0.04, R * 0.98, R * 0.98, 0, 2.0), (0.12, R * 0.85, R * 0.85, 0, 2.0), (0.2, R * 0.55, R * 0.55, 0, 2.0), (0.24, R * 0.2, R * 0.2, 0, 2.0),
                (0.25, 0.0, 0.0, 0, 2.0)], seg_n=16, cap_bot=False)
    for v in cap.verts:
        a = math.atan2(v.co.y, v.co.x)
        r = math.hypot(v.co.x, v.co.y)
        if v.co.z < 0.05:
            v.co.z -= 0.03 * (1 + math.sin(a * 7)) * 0.5
        if estado == 'rasgado':
            # gomos arrancados: dois cortes em V na borda e a borda serrilhada
            for a0 in (0.6, 2.9):
                da = abs((a - a0 + math.pi) % (2 * math.pi) - math.pi)
                if da < 0.5 and r > R * 0.3:
                    k = (0.5 - da) / 0.5
                    v.co.x *= 1 - 0.55 * k; v.co.y *= 1 - 0.55 * k; v.co.z -= 0.04 * k
            if r > R * 0.8:
                v.co.z -= 0.025 * abs(math.sin(a * 13))
        elif estado == 'podre':
            # o chapéu murcha e cai de um lado
            v.co.z -= 0.22 * (r / R) ** 2 * (0.6 + 0.4 * math.cos(a - 0.4))
            v.co.x *= 0.92; v.co.y *= 0.92
    capcor = {'inteiro': '#5E9C98', 'rasgado': '#5A8E8C', 'podre': '#6A7A6C'}[estado]
    B.piece(place(cap, (lean, 0, 0.88)), paint=capcor, bone='root', mat='resina', hull=False)
    if estado == 'podre':
        for k in range(7):
            a = rr.uniform(0, 6.28); r = rr.uniform(0.05, R * 0.75)
            zc = 0.88 + 0.24 * (1 - (r / R) ** 2) ** 0.5 - 0.22 * (r / R) ** 2 * (0.6 + 0.4 * math.cos(a - 0.4))
            B.piece(place(mk('sphere', u=6, v=4), (lean + math.cos(a) * r * 0.92, math.sin(a) * r * 0.92, zc), (0.05, 0.05, 0.02)), paint='#3A3430', bone='root', hull=False, sub=False)
    # lamelas por baixo (disco com raios) e manchas claras em cima
    lm = bmesh.new()
    cvx = lm.verts.new((0, 0, 0.0))
    N = 24
    rim = [lm.verts.new((math.cos(2 * math.pi * k / N) * R * 0.97, math.sin(2 * math.pi * k / N) * R * 0.97, -0.03 if k % 2 else 0.0)) for k in range(N)]
    for k in range(N):
        lm.faces.new([cvx, rim[(k + 1) % N], rim[k]])
    B.piece(place(lm, (lean, 0, 0.885 - (0.12 if estado == 'podre' else 0.0))), paint='#3A5E5E', bone='root', mat='resina', hull=False, sub=False)
    for k in range(5 if estado != 'podre' else 0):
        a = rr.uniform(0, 6.28); r = rr.uniform(0.05, R * 0.7)
        B.piece(place(mk('sphere', u=6, v=4), (lean + math.cos(a) * r, math.sin(a) * r, 0.88 + 0.24 * (1 - (r / R) ** 2) ** 0.5 + 0.005), (0.03, 0.03, 0.01)), paint='#A8C8C2', bone='root', mat='resina', hull=False)
    return B

def tufo(seed, kind):
    """musgo de maquete (almofada de bolinhas) ou grama estática (lâminas finas)."""
    B = Builder(seed, ['root'], outline=0.0); B.wash = 'azul_negro'
    rr = random.Random(seed)
    if kind == 'musgo':
        for k in range(9):
            a = rr.uniform(0, 6.28); r = rr.uniform(0, 0.05)
            s = rr.uniform(0.025, 0.045)
            B.piece(place(mk('sphere', u=6, v=4), (math.cos(a) * r, math.sin(a) * r, s * 0.4), (s, s, s * 0.7)),
                    paint=rr.choice(['#3E5A3A', '#4E6A3E', '#2F4632']), bone='root', hull=False, sub=False)
    else:
        for k in range(14):
            a = rr.uniform(0, 6.28); r = rr.uniform(0, 0.03)
            h = rr.uniform(0.05, 0.09)
            lean = Vector((math.cos(a), math.sin(a), 0)) * rr.uniform(0.01, 0.03)
            p0 = Vector((math.cos(a) * r, math.sin(a) * r, 0))
            bm = bmesh.new()
            w = 0.006
            side = Vector((-math.sin(a), math.cos(a), 0)) * w
            v0 = bm.verts.new(p0 - side); v1 = bm.verts.new(p0 + side); v2 = bm.verts.new(p0 + lean + Vector((0, 0, h)))
            bm.faces.new([v0, v1, v2])
            B.piece(bm, paint=rr.choice(['#6E7A48', '#8A8A54', '#5A6A3E']), bone='root', hull=False, sub=False)
    return B

def laje(seed):
    B = Builder(seed, ['root'], outline=0.0); B.wash = 'azul_negro'
    rr = random.Random(seed)
    bm = mk('cube', bevel=0.06, bseg=2)
    place(bm, (0, 0, 0), (0.42 * rr.uniform(0.8, 1.15), 0.36 * rr.uniform(0.8, 1.15), 0.07))
    for v in bm.verts:
        v.co.z += 0.02 * noise.noise(v.co * 3 + Vector((seed, 0, 0)))
    B.piece(bm, paint=rr.choice(['ardosia', 'aresta_pedra', 'ardosia']), bone='root', hull=False, sub=False)
    return B

def coluna_pedra():
    """coluna de pedra à direita com a estaca da guilda cravada e o pitão da corda."""
    B = Builder(91, ['root'], outline=0.0); B.wash = 'azul_negro'
    rings = []
    rr = random.Random(91)
    for k in range(9):
        z = k * 1.4
        r = 1.6 - k * 0.06 + rr.uniform(-0.15, 0.15)
        rings.append((z, r, r * 0.85, rr.uniform(-0.1, 0.1), 2.2))
    rings.append((12.2, 0.9, 0.8, 0, 2.0))
    bm = loft(rings, seg_n=14)
    for v in bm.verts:
        v.co += v.normal * 0.0 + Vector((0.18 * noise.noise(v.co * 0.8), 0.18 * noise.noise(v.co * 0.8 + Vector((3, 0, 0))), 0))
        v.co.z = math.floor(v.co.z / 0.7) * 0.7 * 0.4 + v.co.z * 0.6
    B.piece(bm, paint='ardosia', bone='root', hull=False, sub=False)
    # estaca da guilda: haste de ferro cravada, argola, corda e a bandeirola com a chave engolida pelo peixe
    B.piece(tube([(0.6, -1.1, 11.0), (0.95, -1.6, 12.6)], [0.07, 0.05], seg_n=8), paint='ferro', bone='root', mat='metal', hull=False)
    B.piece(xform(MT_torus(0.16, 0.035), Matrix.Translation((0.95, -1.62, 12.7))), paint='latao', bone='root', mat='metal', hull=False)
    return B

def MT_torus(R, r, nu=16, nv=6):
    bm = bmesh.new()
    rings = []
    for i in range(nu):
        a = 2 * math.pi * i / nu
        rings.append([bm.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
                      for b in [2 * math.pi * j / nv for j in range(nv)]])
    for i in range(nu):
        for j in range(nv):
            bm.faces.new([rings[i][j], rings[(i + 1) % nu][j], rings[(i + 1) % nu][(j + 1) % nv], rings[i][(j + 1) % nv]])
    return bm

def sino():
    """o Sino de Thessimor (30 m), visto 500 m abaixo pela fenda: bronze aceso pela Forja."""
    B = Builder(92, ['root'], outline=0.0); B.wash = 'lavagem'
    prof = [(0.0, 0.48, 0.48, 0, 2.0), (0.05, 0.47, 0.47, 0, 2.0), (0.2, 0.38, 0.38, 0, 2.0), (0.5, 0.3, 0.3, 0, 2.0), (0.8, 0.28, 0.28, 0, 2.0),
            (0.92, 0.2, 0.2, 0, 2.0), (1.0, 0.0, 0.0, 0, 2.0)]
    B.piece(place(loft(prof, seg_n=16), (0, 0, -1.0)), paint='bronze', bone='root', mat='metal', hull=False)
    return B

# ================================================================== peças autorais da v2
def ladrilho(seed):
    """laje de Thessimor: bloco chanfrado (família de formas do que a cidade construiu), gasta, às vezes lascada."""
    B = Builder(seed, ['root'], outline=0.0); B.wash = 'azul_negro'
    rr = random.Random(seed)
    bm = mk('cube', bevel=0.12, bseg=1)
    place(bm, (0, 0, -0.04), (0.3, 0.3, 0.045))
    for v in bm.verts:
        v.co.z += 0.012 * noise.noise(v.co * 4 + Vector((seed, 0, 0)))
        if seed % 3 == 1 and v.co.x > 0.12 and v.co.y > 0.12:      # canto quebrado
            v.co.z -= 0.05; v.co.x -= 0.06; v.co.y -= 0.05
    B.piece(bm, paint=rr.choice(['#76726C', '#6C6A66', '#807A70']), bone='root', hull=False, sub=False)
    if seed % 3 == 2:   # racha funda atravessando a laje
        B.piece(bevel_box2((0.02, 0.0, 0.012), (0.012, 0.3, 0.004)), paint='primer', bone='root', hull=False, sub=False)
    return B

def bevel_box2(c, s):
    bm = mk('cube')
    return place(bm, c, s)

def coluna_ruina(seed):
    """toco de coluna octogonal com o topo quebrado; deitado vira tambor caído."""
    B = Builder(seed, ['root'], outline=0.0); B.wash = 'azul_negro'
    rr = random.Random(seed)
    rings = [(0.0, 0.46, 0.46, 0, 2.0), (0.12, 0.46, 0.46, 0, 2.0), (0.14, 0.38, 0.38, 0, 2.0)] + [(0.14 + 0.86 * k / 6, 0.37, 0.37, 0, 2.0) for k in range(1, 7)]
    bm = loft(rings, seg_n=8, phase=math.pi / 8)
    for v in bm.verts:
        if v.co.z > 0.9:
            v.co.z -= 0.25 * abs(noise.noise(v.co * 3.0 + Vector((seed, 1, 2)))) + 0.12 * (v.co.x > 0)
    B.piece(bm, paint='#8A8880', bone='root', hull=False, sub=False)
    # anel de capitel quebrado no chão, ao pé do toco
    B.piece(place(loft([(0, 0.5, 0.5, 0, 2.0), (0.08, 0.5, 0.5, 0, 2.0)], seg_n=8, phase=math.pi / 8), (0, 0, 0.0)), paint='#6A6862', bone='root', hull=False, sub=False)
    return B

def tronco():
    """haste de fungo gigante caída sobre a fenda: a ponte natural. A guilda pôs um corrimão de corda."""
    B = Builder(71, ['root'], outline=0.0); B.wash = 'azul_negro'
    rr = random.Random(71)
    L = 4.8
    rings = []
    for k in range(13):
        z = L * k / 12
        r = 0.46 + 0.05 * math.sin(k * 1.7) + (0.12 if k == 0 else 0.0)
        rings.append((z, r, r * 0.92, 0, 2.0))
    bm = loft(rings, seg_n=14)
    for v in bm.verts:
        v.co += Vector((0.03 * noise.noise(v.co * 2.0), 0.03 * noise.noise(v.co * 2.0 + Vector((5, 0, 0))), 0))
        if v.co.z > L - 0.05:      # ponta quebrada, fibrosa
            v.co.z += 0.25 * abs(noise.noise(v.co * 6.0))
    xform(bm, Matrix.Rotation(math.radians(90), 4, 'Y'))
    B.piece(bm, paint='#9A907E', bone='root', hull=False, sub=False)
    # fibras escuras ao longo da haste (veios) e musgo por cima
    for k in range(9):
        a = rr.uniform(0, 6.28)
        B.piece(tube([(0.3 + k * 0.45, math.cos(a) * 0.47, math.sin(a) * 0.45), (0.7 + k * 0.45, math.cos(a + 0.2) * 0.47, math.sin(a + 0.2) * 0.45)], [0.015, 0.012], seg_n=4), paint='#5A5246', bone='root', hull=False)
    for k in range(14):
        x = rr.uniform(0.2, L - 0.3); a = rr.uniform(-0.9, 0.9)
        B.piece(place(mk('sphere', u=6, v=4), (x, math.sin(a) * 0.42, math.cos(a) * 0.44), (rr.uniform(0.08, 0.18), 0.12, 0.05)), paint=rr.choice(['musgo', '#41603C']), bone='root', hull=False, sub=False)
    # chapéu partido preso na base, meio enterrado
    cap = loft([(0.0, 1.1, 1.1, 0, 2.0), (0.12, 1.0, 1.0, 0, 2.0), (0.3, 0.6, 0.6, 0, 2.0), (0.36, 0.0, 0.0, 0, 2.0)], seg_n=16, cap_bot=False)
    for v in cap.verts:
        if math.atan2(v.co.y, v.co.x) > 0.9:
            v.co *= 0.6
    xform(cap, Matrix.Translation((-0.25, 0, 0.05)) @ Matrix.Rotation(math.radians(-80), 4, 'Y'))
    B.piece(cap, paint='#5A7C78', bone='root', mat='resina', hull=False, sub=False)
    # corrimão: dois pares de estacas e a corda frouxa
    for x in (0.3, L - 0.3):
        for sy in (-1, 1):
            B.piece(place(mk('cyl', seg=6), (x, sy * 0.42, 0.75), (0.035, 0.035, 0.45)), paint='madeira', bone='root', hull=False, sub=False)
    for sy in (-1, 1):
        pts = [(0.3 + (L - 0.6) * t, sy * 0.42, 1.15 - 0.28 * 4 * t * (1 - t)) for t in [i / 10 for i in range(11)]]
        B.piece(tube(pts, [0.018] * len(pts), seg_n=5), paint='corda', bone='root', hull=False)
    return B

def guincho():
    """guincho da guilda na beira do penhasco: cavalete em A, lança sobre o vazio, roda, tambor com duas manivelas
    (é maquinaria de dupla), contrapeso de chumbo e a jaula pendurada 9 m abaixo."""
    B = Builder(81, ['root'], outline=0.0); B.wash = 'lavagem'
    def viga(a, b, r=0.07, paint='madeira'):
        a, b = Vector(a), Vector(b)
        d = b - a
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        bm = mk('cube', bevel=0.15, bseg=1)
        xform(bm, Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((r, r, d.length / 2, 1)))
        B.piece(bm, paint=paint, bone='root', hull=False, sub=False)
    for sx in (-1, 1):
        viga((sx * 0.9, -0.8, 0), (sx * 0.75, 0.0, 2.9)); viga((sx * 0.9, 0.8, 0), (sx * 0.75, 0.0, 2.9))
        viga((sx * 0.86, -0.6, 0.9), (sx * 0.86, 0.6, 0.9), 0.05)
    viga((-0.85, 0, 2.9), (0.85, 0, 2.9), 0.08)
    viga((0, -1.3, 2.75), (0, 3.6, 3.25), 0.09, 'madeira_clara')     # a lança sobre o vazio
    viga((0, 3.6, 3.25), (0, 2.0, 2.95), 0.04)
    # roda na ponta e tambor com as duas manivelas
    B.piece(xform(MT_torus(0.32, 0.04, 16, 6), Matrix.Translation((0, 3.55, 3.15)) @ Matrix.Rotation(math.pi / 2, 4, 'Y')), paint='ferro', bone='root', mat='metal', hull=False)
    for k in range(4):
        a = k * math.pi / 4
        viga((0, 3.55 + math.cos(a) * 0.3, 3.15 + math.sin(a) * 0.3), (0, 3.55 - math.cos(a) * 0.3, 3.15 - math.sin(a) * 0.3), 0.02, 'ferro')
    B.piece(place(mk('cyl', seg=12), (0, 0, 0.9), (0.24, 0.24, 0.8), (0, 90, 0)), paint='corda_esc', bone='root', hull=False, sub=False)
    for sx in (-1, 1):
        viga((sx * 1.0, 0, 0.9), (sx * 1.0, 0, 0.55), 0.025, 'ferro'); viga((sx * 1.0, 0, 0.55), (sx * 1.18, 0, 0.55), 0.03, 'madeira_clara')
    # corda do tambor até a roda e da roda até a jaula
    B.piece(tube([(0, 0.15, 1.05), (0, 3.4, 3.0)], [0.025, 0.025], seg_n=5), paint='corda', bone='root', hull=False)
    B.piece(tube([(0, 3.87, 3.15), (0, 3.87, -8.0)], [0.025, 0.025], seg_n=5), paint='corda', bone='root', hull=False)
    # a jaula: quadro de barras
    c = Vector((0, 3.87, -9.0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            viga(c + Vector((sx * 0.6, sy * 0.6, -0.8)), c + Vector((sx * 0.6, sy * 0.6, 0.8)), 0.035, 'ferro')
    for z in (-0.8, 0.8):
        for sx in (-1, 1):
            viga(c + Vector((sx * 0.6, -0.6, z)), c + Vector((sx * 0.6, 0.6, z)), 0.035, 'ferro')
            viga(c + Vector((-0.6, sx * 0.6, z)), c + Vector((0.6, sx * 0.6, z)), 0.035, 'ferro')
    B.piece(place(mk('cube'), c + Vector((0, 0, -0.82)), (0.6, 0.6, 0.03)), paint='madeira', bone='root', hull=False, sub=False)
    for sx in (-1, 1):
        viga(c + Vector((0, 0, 0.8)), c + Vector((sx * 0.6, sx * 0.6, 0.8)), 0.02, 'corda')
    # contrapeso de chumbo na cauda da lança
    B.piece(tube([(0, -1.25, 2.75), (0, -1.25, 1.5)], [0.02, 0.02], seg_n=4), paint='corda', bone='root', hull=False)
    B.piece(place(mk('cube', bevel=0.12, bseg=1), (0, -1.25, 1.25), (0.25, 0.25, 0.25)), paint='chumbo', bone='root', mat='metal', hull=False, sub=False)
    # lanterna pendurada na lança
    B.piece(tube([(0, 1.6, 3.0), (0, 1.6, 2.6)], [0.012, 0.012], seg_n=4), paint='ferro', bone='root', hull=False)
    B.piece(place(mk('cyl', seg=6), (0, 1.6, 2.45), (0.09, 0.09, 0.13)), paint='geodo', bone='root', mat='emis', hull=False, sub=False)
    return B

def poste():
    """poste de lanterna da guilda: estaca torta, braço e lanterna de ferro com vela."""
    B = Builder(82, ['root'], outline=0.0); B.wash = 'lavagem'
    B.piece(place(mk('cyl', seg=6), (0, 0, 0.85), (0.05, 0.05, 0.85)), paint='madeira', bone='root', hull=False, sub=False)
    B.piece(place(mk('cube'), (0.17, 0, 1.62), (0.2, 0.03, 0.03)), paint='madeira', bone='root', hull=False, sub=False)
    B.piece(tube([(0.33, 0, 1.6), (0.33, 0, 1.48)], [0.008, 0.008], seg_n=4), paint='ferro', bone='root', hull=False)
    B.piece(place(mk('cyl', seg=6, r2=0.6), (0.33, 0, 1.47), (0.07, 0.07, 0.02)), paint='ferro', bone='root', mat='metal', hull=False, sub=False)
    B.piece(place(mk('cyl', seg=6), (0.33, 0, 1.36), (0.06, 0.06, 0.09)), paint='geodo', bone='root', mat='emis', hull=False, sub=False)
    B.piece(place(mk('cyl', seg=6), (0.33, 0, 1.26), (0.07, 0.07, 0.015)), paint='ferro', bone='root', mat='metal', hull=False, sub=False)
    # fita de giz da guilda (marca de rota) e o pó de cal no pé
    B.piece(place(mk('cube'), (0.0, -0.052, 1.2), (0.05, 0.004, 0.09)), paint='giz', bone='root', hull=False, sub=False)
    return B

def dente():
    """O Dente: estalagmite de 480 m com o mosteiro escavado; janelas que acendem uma a uma."""
    B = Builder(83, ['root'], outline=0.0); B.wash = 'azul_negro'
    rr = random.Random(83)
    rings = []
    N = 26
    for k in range(N + 1):
        t = k / N
        r = 58 * (1 - t) ** 1.25 + 4.0
        if 0.35 < t < 0.4 or 0.62 < t < 0.66:
            r *= 1.18      # ressaltos onde estão os terraços do mosteiro
        rings.append((480 * t, r, r * 0.9, 0, 2.0))
    bm = loft(rings, seg_n=18)
    for v in bm.verts:
        v.co += Vector((7 * noise.noise(v.co * 0.02), 7 * noise.noise(v.co * 0.02 + Vector((3, 0, 0))), 0)) * (1 - v.co.z / 520)
        if v.co.z > 470:
            v.co.z -= 30 * abs(noise.noise(v.co * 0.2))
    B.piece(bm, paint='ardosia', bone='root', hull=False, sub=False)
    for k in range(46):
        t = rr.uniform(0.12, 0.85)
        z = 480 * t
        r = 58 * (1 - t) ** 1.25 + 4.0
        a = rr.uniform(-2.3, -0.8)
        p = Vector((math.cos(a) * r * 0.97, math.sin(a) * r * 0.87, z))
        B.piece(place(mk('cube'), p, (2.0, 2.0, 3.2), (0, 0, math.degrees(a))), paint='forja', bone='root', mat='emis', hull=False, sub=False)
    return B

# ================================================================== instâncias
def scatter():
    rr = random.Random(55)
    d = {}
    Hf = lambda x, y: float(h_terraco(np.array([[x]]), np.array([[y]]))[0, 0])
    T = TERR
    def mask(nome, x, y):
        ix = int(round((x + 40) / T['res'])); iy = int(round((y + 16) / T['res']))
        ix = min(max(ix, 0), T['X'].shape[1] - 1); iy = min(max(iy, 0), T['X'].shape[0] - 1)
        return float(T[nome][iy, ix])
    def na_poca(x, y, m=1.0):
        return ((x - 0.3) / (4.6 * m)) ** 2 + ((y + 0.2) / (3.3 * m)) ** 2 < 1.0
    def na_fenda(x, y, m=0.0):
        return abs(x - 6.6 - 0.6 * math.sin(y * 0.5)) < 1.3 + m and y > -2
    def na_trilha(x, y, m=0.0):
        return float(dist_trilha(np.array([[x]]), np.array([[y]]))[0, 0]) < 0.75 + m
    R = RUINA
    def no_poco(x, y, m=0.3):
        return math.hypot(x - R['poco'][0], y - R['poco'][1]) < R['r'] + m
    # musgo e grama por máscara: musgo onde é côncavo e úmido, grama seca na beira das trilhas e nas lombadas
    mus, gra = [], []
    for i in range(16000):
        x = rr.uniform(-26, 26); y = rr.uniform(-14, 24)
        if na_poca(x, y) or na_fenda(x, y) or no_poco(x, y, 0.6):
            continue
        z = Hf(x, y)
        if z < -3.6:
            continue
        m = mask('musgo', x, y); tr = mask('trilha', x, y); um = mask('umido', x, y)
        g = [x, y, z, rr.uniform(0, 6.28), rr.uniform(0.7, 1.6)]
        if rr.random() < m * 0.55:
            mus.append(g)
        elif tr < 0.15 and rr.random() < 0.09 * (1 - um) + 0.25 * float(0.62 < float(dist_trilha(np.array([[x]]), np.array([[y]]))[0, 0]) < 1.4):
            gra.append(g)
    # rochas: tombadas do pé da parede, na beira do penhasco e no entulho da ruína (nada solto no meio do piso)
    ped = []
    def pedra(x, y, s, k=None):
        if na_poca(x, y, 1.05) or na_trilha(x, y, 0.1) or no_poco(x, y):
            return
        z = Hf(x, y)
        if z < -14: return
        ped.append([x, y, z - 0.12 * s, rr.uniform(0, 6.28), s, rr.randint(0, 2) if k is None else k])
    for i in range(34):
        y = rr.uniform(-12, 10); x = -14.5 + rr.gauss(0, 1.4) + 0.25 * y
        pedra(x, y, rr.uniform(0.6, 1.9))
    for i in range(18):
        y = rr.uniform(-12, 8); x = 16.5 + rr.gauss(0, 1.5)
        pedra(x, y, rr.uniform(0.6, 1.7))
    for i in range(22):
        x = rr.uniform(-12, 22)
        e = 4.6 + 1.4 * float(fbm(np.array([[x * 0.07]]), np.array([[3.0]]), 3, seed=1)[0, 0])
        pedra(x, e - 0.4 + rr.gauss(0, 0.5), rr.uniform(0.35, 1.0))
    for i in range(10):
        a = rr.uniform(0, 6.28); r = rr.uniform(R['r'] + 0.4, 3.4)
        pedra(R['poco'][0] + math.cos(a) * r, R['poco'][1] + math.sin(a) * r, rr.uniform(0.2, 0.45))
    # ruína: lajes em grade antiga, com faltas, afundando e inclinando para dentro do poço; tocos de coluna
    rui = []
    ca, sa = math.cos(R['ang']), math.sin(R['ang'])
    cx, cy = (R['x0'] + R['x1']) / 2, (R['y0'] + R['y1']) / 2
    sp = 0.62
    for i in range(-6, 7):
        for j in range(-5, 6):
            u, v = i * sp, j * sp
            x = cx + u * ca - v * sa; y = cy + u * sa + v * ca
            if not em_ruina(np.array(x), np.array(y)):
                continue
            borda = min(x - R['x0'], R['x1'] - x, y - R['y0'], R['y1'] - y)
            nz = noise.noise(Vector((x * 0.7, y * 0.7, 4.2)))
            if borda < 1.2 and nz + borda * 0.6 < 0.25:
                continue          # borda quebrada, irregular
            if nz < -0.45 and rr.random() < 0.5:
                continue          # buracos no piso
            dp = math.hypot(x - R['poco'][0], y - R['poco'][1])
            if dp < R['r'] + 0.05:
                continue
            z = Hf(x, y) + 0.07
            ang = 0.0; ax = az = 0.0
            if dp < 2.6:
                k = (2.6 - dp) / (2.6 - R['r'])
                ang = 0.42 * k ** 1.4 + rr.uniform(-0.04, 0.04)
                z -= 0.4 * k ** 1.6
                dxg, dzg = (R['poco'][0] - x) / dp, -(R['poco'][1] - y) / dp
                ax, az = dzg, -dxg
            elif rr.random() < 0.18:
                a2 = rr.uniform(0, 6.28); ax, az = math.cos(a2), math.sin(a2); ang = rr.uniform(0.04, 0.12)
                z += rr.uniform(-0.03, 0.05)
            rui.append([x, y, z, R['ang'] + rr.choice([0, 1.5708]) + rr.uniform(-0.04, 0.04), rr.uniform(0.96, 1.03), rr.randint(0, 2), ax, az, ang])
    for k in range(4):     # lajes soltas arrancadas, perto da ruína, de pé ou de lado
        x = rr.uniform(R['x0'] - 1.5, R['x1'] + 1.0); y = rr.uniform(R['y0'] - 1.5, R['y1'] + 0.8)
        if em_ruina(np.array(x), np.array(y)) or na_trilha(x, y) or na_poca(x, y, 1.1):
            continue
        a2 = rr.uniform(0, 6.28)
        rui.append([x, y, Hf(x, y) + 0.12, rr.uniform(0, 6.28), 1.0, rr.randint(0, 2), math.cos(a2), math.sin(a2), rr.uniform(0.4, 1.3)])
    cols = [[R['x0'] + 0.35, R['y0'] + 0.35, 1.8, 0.0, 0.0, 0.0], [R['x1'] - 0.3, R['y0'] + 0.2, 0.75, 0.0, 0.0, 0.0],
            [R['x0'] + 0.3, R['y1'] - 0.4, 2.6, 0.0, 0.0, 0.0], [R['x1'] - 0.4, R['y1'] - 0.3, 1.2, 0.08, 1.0, 0.0],
            [R['x1'] + 1.0, 2.7, 1.0, 1.571, 0.3, 0.95]]       # [x, y, altura, inclinação, eixo x, eixo z] ; o último está caído
    colunas = []
    for c in cols:
        z = Hf(c[0], c[1]) + (0.37 if c[3] > 1.0 else 0.0)
        colunas.append([c[0], c[1], z, rr.uniform(0, 0.8), c[2], 0, c[4], c[5], c[3]])
    # fungos em COLÔNIAS: 1 gigante, 3 a 5 médios e um enxame pequeno, presos à umidade, às fendas e à parede
    peq = []
    est = {'parede': 0, 'ruina': 2, 'fenda': 1, 'beira': 0, 'frente': 0}
    for (cx_, cy_, tipo) in COLONIAS:
        def fungo_em(x, y, s, k, tilt=0.0):
            if na_poca(x, y, 1.05) or na_trilha(x, y, 0.2 * s) or na_fenda(x, y, 0.2) or no_poco(x, y, 0.5) or em_ruina(np.array(x), np.array(y), -0.6):
                return
            z = Hf(x, y)
            if z < -3.0: return
            a2 = rr.uniform(0, 6.28)
            peq.append([x, y, z, rr.uniform(0, 6.28), s, k, math.cos(a2) * (tilt > 0), math.sin(a2) * (tilt > 0), tilt])
        k0 = est[tipo]
        big = rr.uniform(2.6, 3.4) * (1.25 if tipo == 'frente' else 1.0)
        fungo_em(cx_, cy_, big, k0 if rr.random() < 0.6 else rr.randint(0, 2), 0.0 if tipo != 'ruina' else 1.25)
        for m in range(rr.randint(3, 5)):
            a = rr.uniform(0, 6.28); r = rr.uniform(0.9, 2.0)
            fungo_em(cx_ + math.cos(a) * r, cy_ + math.sin(a) * r, rr.uniform(1.0, 1.7), rr.choice([k0, k0, 0, 1, 2]), 0.0 if rr.random() < 0.8 else rr.uniform(0.25, 0.5))
        for m in range(rr.randint(10, 16)):
            a = rr.uniform(0, 6.28); r = rr.uniform(0.5, 2.6)
            fungo_em(cx_ + math.cos(a) * r, cy_ + math.sin(a) * r, rr.uniform(0.18, 0.45), rr.choice([0, 0, 1, 2]), rr.uniform(0.0, 0.25))
    # floresta de fungos gigantes lá embaixo (20 a 60 m), mais densa na direção da Coluna
    gig = []
    centros = [(rr.uniform(-300, 300), rr.uniform(70, 320)) for _ in range(26)]
    centros = [c for c in centros if abs(c[0] - 6) > 34 and abs(c[0] + 72) > 26] + [(-40, 70), (60, 90), (-140, 110), (130, 150)]
    for i in range(150):
        cx2, cy2 = centros[i % len(centros)]
        x = cx2 + rr.gauss(0, 10); y = max(55.0, cy2 + rr.gauss(0, 9))
        z = -92.0 - max(y - 20, 0) * 0.4 + 9 * noise.noise(Vector((x * 0.012, y * 0.012, 11 * 7.31)))
        if y > 160:
            z = min(z, -140 - (y - 160) * 2.0)
        s = rr.uniform(10, 24) * (0.7 if y < 100 else 1.0)
        gig.append([x, y, z, rr.uniform(0, 6.28), s, rr.choice([0, 0, 1, 2])])
    # marcos perto: ponte, guincho, postes de lanterna ao longo das trilhas
    ponte = [PONTE[0][0], PONTE[0][1], Hf(*PONTE[0]) + 0.32, math.atan2(PONTE[1][1] - PONTE[0][1], PONTE[1][0] - PONTE[0][0])]
    gu = [GUINCHO[0], GUINCHO[1], Hf(*GUINCHO), 0.12]
    postes = []
    for (x, y) in [(-2.4, -8.6), (-1.6, -4.9), (-5.9, 0.9), (4.1, -3.4), (4.6, 2.5), (9.7, 2.5), (14.2, 1.4), (-10.8, -1.9)]:
        postes.append([x, y, Hf(x, y), rr.uniform(-0.3, 0.3) + (math.pi if x > 0 else 0.0)])
    d.update(musgo=mus, grama=gra, pedra=ped, fungo_peq=peq, fungo_gig=gig, laje=[], ruina=rui, colunas=colunas, ponte=ponte, guincho=gu, postes=postes)
    return d

def catenaria(a, b, sag, n):
    a, b = np.array(a, float), np.array(b, float)
    pts = []
    for i in range(n):
        t = i / (n - 1)
        p = a + (b - a) * t
        p[2] -= sag * 4 * t * (1 - t)
        pts.append(p.tolist())
    return pts

def lanternas():
    rr = random.Random(77)
    L = []
    # fileira da guilda descendo pela coluna de pedra à direita até os degraus
    L += catenaria((13.5, -6.0, 0.6), (10.5, 5.2, 0.2), 0.5, 14)
    L += catenaria((10.5, 5.2, 0.2), (14.0, 9.5, -16.0), 2.0, 12)
    L += catenaria((14.0, 9.5, -16.0), (20.0, 16.0, -46.0), 3.0, 14)
    # fios da guilda na parede distante (contas de colar descendo) e o acampamento rival
    for k in range(5):
        x0 = rr.uniform(-260, 280); y0 = rr.uniform(700, 760)
        z0 = rr.uniform(-150, 60)
        L += catenaria((x0, y0, z0), (x0 + rr.uniform(-60, 60), y0 - rr.uniform(0, 20), z0 - rr.uniform(150, 320)), 30, 28)
    for k in range(3):
        x0 = rr.uniform(-200, 200)
        L += catenaria((x0, 640, -260), (x0 + 140, 650, -300), 25, 22)
    rival = [[150.0, 690.0, -340.0], [158.0, 690.0, -338.0], [146.0, 692.0, -342.0]]
    # v2: Pendura de Baixo, um povoado de guilda pendurado na parede distante (janelas em cachos, não pontos soltos)
    jan = []
    for (cx, cz, n) in [(-150, -110, 30), (30, -40, 38), (210, -190, 22), (-40, -260, 16)]:
        for k in range(n):
            x = cx + rr.gauss(0, 22); z = cz + rr.gauss(0, 14) - abs(x - cx) * 0.25
            y = 700 + (z + 950) / 9.0 - 14
            jan.append([round(x, 1), round(y, 1), round(z, 1), round(rr.uniform(0.7, 1.3), 2)])
        L += catenaria((cx - 40, 700 + (cz + 950) / 9.0 - 16, cz + 10), (cx + 40, 700 + (cz + 950) / 9.0 - 16, cz + 6), 12, 16)
    return L, rival, jan

def main():
    t0 = __import__('time').time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_terraco()
    build_abismo()
    for i in range(3):
        builder_export(rocha(300 + i), 'rocha%d' % i, ao_dist=0.8)
        builder_export(fungo(400 + i, estado=['inteiro', 'rasgado', 'podre'][i]), 'fungo%d' % i, ao_dist=0.25)
        builder_export(laje(500 + i), 'laje%d' % i, ao_dist=0.3)
        builder_export(ladrilho(510 + i), 'ladrilho%d' % i, ao_dist=0.2)
    builder_export(coluna_ruina(520), 'coluna_ruina', ao_dist=0.4)
    builder_export(tronco(), 'tronco', ao_dist=0.5)
    builder_export(guincho(), 'guincho', ao_dist=0.6)
    builder_export(poste(), 'poste', ao_dist=0.2)
    builder_export(dente(), 'dente', ao_dist=40.0, curv_scale=3.0)
    builder_export(tufo(600, 'musgo'), 'musgo', ao_dist=0.05)
    builder_export(tufo(601, 'grama'), 'grama', ao_dist=0.05)
    builder_export(coluna_pedra(), 'coluna', ao_dist=3.0, curv_scale=0.6)
    builder_export(sino(), 'sino', ao_dist=0.3)
    d = scatter()
    L, rival, jan = lanternas()
    d['lanternas'] = L; d['rival'] = rival; d['janelas'] = jan
    d['dente'] = [-85.0, 300.0, -470.0]
    d['coluna_pos'] = [14.2, 3.6, -0.2]
    xs = np.arange(-14, 14.01, 0.25); ys = np.arange(-12, 10.01, 0.25)
    XX, YY = np.meshgrid(xs, ys)
    d['altura'] = dict(x0=-14, y0=-12, res=0.25, nx=len(xs), ny=len(ys), z=[round(float(v), 3) for v in h_terraco(XX, YY).ravel()])
    json.dump(d, open(os.path.join(PROJ, 'assets', 'mundo.json'), 'w'))
    print('mundo.json', {k: len(v) for k, v in d.items() if isinstance(v, list)}, round(__import__('time').time() - t0, 1), 's')

if os.environ.get('SO_MAPA'):
    from PIL import Image
    X, Y = grid(-26, 26, -16, 20, 0.25)
    Z = h_terraco(X, Y)
    C, ao, curv, m = paint_terraco(X, Y, Z, 0.25)
    srgb = np.where(C <= 0.0031308, C * 12.92, 1.055 * np.power(np.clip(C, 0, 1), 1 / 2.4) - 0.055)
    Image.fromarray((np.clip(srgb[::-1], 0, 1) * 255).astype(np.uint8)).resize((X.shape[1] * 3, X.shape[0] * 3)).save(os.environ['SO_MAPA'])
    print('lum media', float((0.2126*srgb[...,0]+0.7152*srgb[...,1]+0.0722*srgb[...,2]).mean()))
    sys.exit(0)
main()

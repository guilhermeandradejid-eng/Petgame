"""
Smash na Areia - personagens estilo Mii (bonequinhos personalizaveis).

Gerador PARAMETRICO: um dicionario de configuracao (`cfg`) descreve o personagem
inteiro e `build_character(cfg)` constroi a malha no Blender. Nao ha nada
modelado a mao: corpo, rosto, cabelo, roupa e acessorios saem de funcoes, entao
trocar tom de pele, cabelo, olhos, bone, oculos, camisa etc. e so mudar o cfg.

Uso (com o modulo `bpy`):
    from mii import build_character, MALE, FEMALE, merge
    objs = build_character(merge(MALE, {"skin": "tan", "hair": {"style": "afro"}}))

Convencoes (as mesmas do resto do projeto):
  * Blender e Z-up e o personagem olha para -Y.
  * Unidades em metros; o boneco mede ~1,75 m (cabecao de ~24% da altura).
  * Cada objeto leva a propriedade `outline` (True/False): o render cria o
    contorno de "casco invertido" so nos que pedem.
"""
import copy
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
DECAL_DIR = os.path.join(HERE, "_decals")

# ================================================================== paletas

SKIN_TONES = {
    "porcelana": "#f9d5bd", "pessego": "#f2b58c", "dourada": "#e3a56e",
    "morena": "#c98a57", "marrom": "#9a623b", "escura": "#6a3f26", "ebano": "#4b2c1c",
}
HAIR_COLORS = {
    "castanho": "#4a2a1c", "preto": "#1e1a20", "loiro": "#e6b95a", "ruivo": "#c4561f",
    "grisalho": "#b9b4bd", "azul": "#2f74dc", "rosa": "#ff7db4", "roxo": "#7a47d8",
    "verde": "#2fb985", "branco": "#efeaf2",
}
EYE_COLORS = {
    "preto": "#16121a", "castanho": "#5a3220", "azul": "#2d6fd8", "verde": "#2f9a62",
    "mel": "#b9792b", "cinza": "#6b7686",
}

# ================================================================== configs

MALE = {
    "name": "Rafa", "gender": "male",
    "height": 1.0, "weight": 1.0, "head_scale": 1.0, "shoulders": 1.0,
    "skin": "pessego",
    "face": {
        "shape": "round",            # round | oval | square
        "eyes": "round",             # round | dot | wide | sleepy
        "eye_color": "preto", "eye_size": 1.0, "eye_gap": 1.0,
        "brows": "soft",             # soft | thick | thin | none
        "nose": "button",            # button | long | small | none
        "mouth": "smile",            # smile | grin | neutral | determined | open | smirk
        "cheeks": True, "freckles": False, "lashes": False,
    },
    "hair": {"style": "short", "color": "castanho"},
    "accessories": {
        "visor": "#2f7fe0",          # cor ou None
        "cap": None, "headband": None,
        "sunglasses": None,          # {"style": "sport|round|square|aviator", "color": "mirror|azul|preta|verde|rosa"}
        "glasses": None,             # {"style": "round", "color": "#222"}
        "wristband": "#f08a2c", "wristband_side": "R",
    },
    "outfit": {
        "top": {"style": "tank", "color_a": "#37a8f0", "color_b": "#f58a2a", "number": "10",
                "emblem": "wave", "trim": "#ffffff"},
        "bottom": {"style": "shorts", "color": "#183f6e", "stripe_a": "#ffffff", "stripe_b": "#f58a2a"},
    },
}

FEMALE = {
    "name": "Bia", "gender": "female",
    "height": 0.945, "weight": 1.0, "head_scale": 1.0, "shoulders": 1.0,
    "skin": "pessego",
    "face": {
        "shape": "oval", "eyes": "round", "eye_color": "castanho", "eye_size": 1.1, "eye_gap": 1.0,
        "brows": "thin", "nose": "small", "mouth": "smile",
        "cheeks": True, "freckles": False, "lashes": True,
    },
    "hair": {"style": "ponytail", "color": "castanho"},
    "accessories": {
        "visor": "#ff5f8f", "cap": None, "headband": None,
        "sunglasses": None,
        "glasses": None,
        "wristband": "#ffffff", "wristband_side": "R",
    },
    "outfit": {
        "top": {"style": "tank", "color_a": "#ff7aa8", "color_b": "#ffb347", "number": "7",
                "emblem": "wave", "trim": "#ffffff"},
        "bottom": {"style": "skirt", "color": "#1f4d8f", "stripe_a": "#ffffff", "stripe_b": "#ffb347"},
    },
}


def merge(base, over):
    """Mescla recursivamente `over` em uma copia de `base`."""
    out = copy.deepcopy(base)
    for k, v in (over or {}).items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = merge(out[k], v)
        else:
            out[k] = copy.deepcopy(v)
    return out


# ================================================================== utilidades

def srgb(hex_color):
    h = hex_color.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def shade(hex_color, f):
    """Escurece (f<1) ou clareia (f>1) uma cor hex."""
    h = hex_color.lstrip("#")
    c = [int(h[i:i + 2], 16) for i in (0, 2, 4)]
    if f <= 1:
        c = [int(v * f) for v in c]
    else:
        c = [int(v + (255 - v) * (f - 1)) for v in c]
    return "#%02x%02x%02x" % tuple(max(0, min(255, v)) for v in c)


def col(value, table=None):
    """Aceita nome de paleta ou '#rrggbb'."""
    if table and value in table:
        return table[value]
    return value


def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def smooth(t):
    t = clamp(t)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


_MAT_CACHE = {}


def reset_materials():
    _MAT_CACHE.clear()


def _bsdf(m):
    m.use_nodes = True
    return m.node_tree.nodes.get("Principled BSDF")


def _set(bsdf, name, value):
    if name in bsdf.inputs:
        bsdf.inputs[name].default_value = value


def mat(name, color, rough=0.55, metallic=0.0, sss=0.0, sheen=0.0, coat=0.0, spec=0.5, emit=None,
        emit_strength=1.0):
    key = (name, color, rough, metallic, sss, sheen, coat, spec, emit)
    if key in _MAT_CACHE:
        return _MAT_CACHE[key]
    m = bpy.data.materials.new(name)
    b = _bsdf(m)
    rgba = (*srgb(color), 1.0)
    m.diffuse_color = rgba
    _set(b, "Base Color", rgba)
    _set(b, "Roughness", rough)
    _set(b, "Metallic", metallic)
    _set(b, "Specular IOR Level", spec)
    _set(b, "Subsurface Weight", sss)
    _set(b, "Subsurface Radius", (1.0, 0.35, 0.2))
    _set(b, "Subsurface Scale", 0.05)
    _set(b, "Sheen Weight", sheen)
    _set(b, "Coat Weight", coat)
    _set(b, "Coat Roughness", 0.25)
    if emit:
        _set(b, "Emission Color", (*srgb(emit), 1.0))
        _set(b, "Emission Strength", emit_strength)
    _MAT_CACHE[key] = m
    return m


def skin_mat(color):
    return mat("Skin", color, rough=0.5, sss=0.18, coat=0.08, spec=0.45)


def hair_mat(color):
    return mat("Hair", color, rough=0.5, coat=0.12, spec=0.5)


def cloth_mat(name, color):
    return mat(name, color, rough=0.72, sheen=0.35)


def blush_mat():
    key = ("Blush",)
    if key in _MAT_CACHE:
        return _MAT_CACHE[key]
    m = bpy.data.materials.new("Blush")
    b = _bsdf(m)
    nt = m.node_tree
    _set(b, "Base Color", (*srgb("#ff7f86"), 1.0))
    _set(b, "Roughness", 0.9)
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.35
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[1].position = 0.95
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    # Layer Weight "Facing" = 0 de frente e sobe para as bordas: invertemos
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 0.55
    nt.links.new(lw.outputs["Facing"], inv.inputs[1])
    nt.links.new(inv.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], b.inputs["Alpha"])
    _MAT_CACHE[key] = m
    return m


def mirror_mat(kind="mirror"):
    """Lente espelhada laranja->azul (como no modelo de referencia)."""
    key = ("Lens", kind)
    if key in _MAT_CACHE:
        return _MAT_CACHE[key]
    m = bpy.data.materials.new("Lens")
    b = _bsdf(m)
    nt = m.node_tree
    _set(b, "Roughness", 0.08)
    _set(b, "Metallic", 0.55)
    _set(b, "Coat Weight", 0.8)
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    cols = {
        "mirror": ["#ff9a2e", "#ff5a2a", "#3b6fe0"],
        "azul": ["#7fd0ff", "#2f74dc", "#14336e"],
        "preta": ["#3a3f4d", "#1a1c26", "#0a0b10"],
        "verde": ["#b8ff7a", "#38b36a", "#0d4a3a"],
        "rosa": ["#ffd0e6", "#ff6fae", "#7a2a6a"],
    }[kind]
    ramp.color_ramp.elements[0].color = (*srgb(cols[0]), 1)
    e = ramp.color_ramp.elements.new(0.5)
    e.color = (*srgb(cols[1]), 1)
    ramp.color_ramp.elements[2].color = (*srgb(cols[2]), 1)
    mp = nt.nodes.new("ShaderNodeMapRange")
    mp.inputs["From Min"].default_value = 0.0
    mp.inputs["From Max"].default_value = 1.0
    nt.links.new(coord.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], b.inputs["Base Color"])
    _MAT_CACHE[key] = m
    return m


# ---------------------------------------------------------------- malhas

def grid_faces(nu, nv, closed_u=True, flip=False):
    faces = []
    for j in range(nv - 1):
        for i in range(nu if closed_u else nu - 1):
            a = j * nu + i
            b = j * nu + (i + 1) % nu
            c = (j + 1) * nu + (i + 1) % nu
            d = (j + 1) * nu + i
            faces.append((a, d, c, b) if flip else (a, b, c, d))
    return faces


def _orient(verts, faces, inside):
    """Inverte todas as faces se, em media, as normais apontarem para `inside`
    (um ponto dentro da forma) ou para o eixo Z ('axis')."""
    tot = 0.0
    for f in faces:
        vs = [Vector(verts[i]) for i in f]
        n = Vector((0, 0, 0))
        for k in range(len(vs)):
            a, b = vs[k], vs[(k + 1) % len(vs)]
            n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
        c = sum(vs, Vector()) / len(vs)
        if inside == "axis":
            r = Vector((c.x, c.y, 0))
        else:
            r = c - Vector(inside)
        tot += n.normalized().dot(r.normalized()) if n.length > 1e-12 and r.length > 1e-9 else 0.0
    if tot < 0:
        return [tuple(reversed(f)) for f in faces]
    return faces


def make_obj(name, verts, faces, mats, M=None, smooth_shade=True, subsurf=0, solidify=0.0,
             solidify_offset=-1.0, outline=True, face_mats=None, merge=True, recalc=True, inside=None):
    me = bpy.data.meshes.new(name)
    if inside is not None:
        faces = _orient(verts, faces, inside)
    if M is not None:
        verts = [M @ Vector(v) for v in verts]
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    if merge or recalc:
        bm = bmesh.new()
        bm.from_mesh(me)
        if merge:
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        if recalc:
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
    for m in mats:
        me.materials.append(m)
    if face_mats is not None and not merge:
        for p, i in zip(me.polygons, face_mats):
            p.material_index = i
    me.polygons.foreach_set("use_smooth", [smooth_shade] * len(me.polygons))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if solidify:
        md = ob.modifiers.new("solid", "SOLIDIFY")
        md.thickness = solidify
        md.offset = solidify_offset
        md.use_even_offset = True
    if subsurf:
        md = ob.modifiers.new("sub", "SUBSURF")
        md.levels = subsurf
        md.render_levels = subsurf
    ob["outline"] = bool(outline)
    return ob


def ellipsoid(name, center, radii, mats, M=None, rot=None, nu=28, nv=16, **kw):
    """Elipsoide; `rot` e uma Matrix 3x3/4x4 de orientacao local."""
    verts = []
    for j in range(nv + 1):
        a = math.pi * j / nv
        for i in range(nu):
            t = 2 * math.pi * i / nu
            verts.append(Vector((radii[0] * math.sin(a) * math.cos(t),
                                 radii[1] * math.sin(a) * math.sin(t),
                                 -radii[2] * math.cos(a))))
    R = rot.to_4x4() if rot is not None else Matrix.Identity(4)
    verts = [R @ v + Vector(center) for v in verts]
    return make_obj(name, verts, grid_faces(nu, nv + 1, True), mats, M=M, **kw)


def catmull(pts, per=6, closed=False):
    """Pontos amostrados por spline Catmull-Rom; devolve (pontos, [(seg, t)])."""
    n = len(pts)
    out, info = [], []
    segs = n if closed else n - 1
    for i in range(segs):
        p0 = pts[(i - 1) % n] if (closed or i > 0) else pts[0] * 2 - pts[1]
        p1 = pts[i % n]
        p2 = pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if (closed or i + 2 < n) else pts[-1] * 2 - pts[-2]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            p = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                       + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            out.append(p)
            info.append((i, t))
    if not closed:
        out.append(pts[-1])
        info.append((n - 2, 1.0))
    return out, info


def tube(name, points, radii, mats, ref=(1, 0, 0), M=None, n=18, per=6, cap0=True, cap1=True,
         closed=False, cap_rings=4, **kw):
    """Tubo de secao elipse ao longo de uma curva. radii: float ou (rx, ry) por ponto.
    rx fica na direcao de `ref` projetada, ry na perpendicular."""
    pts = [Vector(p) for p in points]
    rr = [(r, r) if not isinstance(r, (tuple, list)) else tuple(r) for r in radii]
    path, info = catmull(pts, per, closed)
    nseg = len(pts)
    rads = []
    for (i, t) in info:
        a, b = rr[i % nseg], rr[(i + 1) % nseg]
        s = smooth(t)
        rads.append((lerp(a[0], b[0], s), lerp(a[1], b[1], s)))
    ref = Vector(ref).normalized()
    m = len(path)
    rings = []
    last_N = None
    for i in range(m):
        if closed:
            T = (path[(i + 1) % m] - path[(i - 1) % m])
        else:
            T = path[min(i + 1, m - 1)] - path[max(i - 1, 0)]
        T.normalize()
        N = ref - T * ref.dot(T)
        if N.length < 1e-4:
            N = last_N if last_N is not None else Vector((1, 0, 0))
        N.normalize()
        last_N = N
        B = T.cross(N)
        rings.append((path[i], T, N, B, rads[i]))

    def ring_verts(c, N, B, rx, ry):
        return [c + N * (math.cos(2 * math.pi * k / n) * rx) + B * (math.sin(2 * math.pi * k / n) * ry)
                for k in range(n)]

    verts = []
    ring_list = []
    if cap0 and not closed:
        c, T, N, B, (rx, ry) = rings[0]
        rm = (rx + ry) / 2
        for j in range(cap_rings, 0, -1):
            phi = (j / cap_rings) * math.pi / 2
            ring_list.append(ring_verts(c - T * (rm * math.sin(phi)), N, B, rx * math.cos(phi), ry * math.cos(phi)))
    for (c, T, N, B, (rx, ry)) in rings:
        ring_list.append(ring_verts(c, N, B, rx, ry))
    if cap1 and not closed:
        c, T, N, B, (rx, ry) = rings[-1]
        rm = (rx + ry) / 2
        for j in range(1, cap_rings + 1):
            phi = (j / cap_rings) * math.pi / 2
            ring_list.append(ring_verts(c + T * (rm * math.sin(phi)), N, B, rx * math.cos(phi), ry * math.cos(phi)))
    for r in ring_list:
        verts.extend(r)
    faces = grid_faces(n, len(ring_list), True)
    if closed:
        # fecha o anel de aneis
        k = len(ring_list)
        faces = []
        for j in range(k):
            for i in range(n):
                a = j * n + i
                b = j * n + (i + 1) % n
                c2 = ((j + 1) % k) * n + (i + 1) % n
                d = ((j + 1) % k) * n + i
                faces.append((a, b, c2, d))
    return make_obj(name, verts, faces, mats, M=M, **kw)


def sheet(name, fn, nu, nv, mats, M=None, closed_u=False, flip=False, inside="axis", **kw):
    """Superficie parametrica: fn(i, j) -> Vector, i em [0,nu), j em [0,nv).
    `inside`: ponto interno (ou 'axis') usado para apontar as normais para fora."""
    verts = [fn(i, j) for j in range(nv) for i in range(nu)]
    return make_obj(name, verts, grid_faces(nu, nv, closed_u, flip), mats, M=M, recalc=False, inside=inside, **kw)


# ================================================================== cabeca

class Head:
    """Cabeca em coordenadas locais: centro na origem, rosto para -Y.
    phi = angulo ao redor (0 = frente, +pi/2 = lado esquerdo do boneco, pi = nuca)
    al  = angulo polar (0 = queixo, pi = topo)."""

    SHAPES = {   # hx, hy, hz, taper (queixo), square (caixa)
        "round": (0.238, 0.226, 0.215, 0.10, 0.0),
        "oval": (0.226, 0.222, 0.225, 0.20, 0.0),
        "square": (0.240, 0.226, 0.212, 0.04, 0.55),
    }

    def __init__(self, shape="round", scale=1.0):
        hx, hy, hz, tp, sq = self.SHAPES[shape]
        self.hx, self.hy, self.hz = hx * scale, hy * scale, hz * scale
        self.taper, self.square = tp, sq

    def _r(self, al):
        s = al / math.pi
        lower = clamp(1 - s * 2.0)       # so afeta a metade de baixo
        g = 1 - self.taper * (lower ** 2) * 1.3
        p = 1 - self.square * 0.32 * (lower ** 1.2)
        return (math.sin(al) ** p) * g

    def point(self, phi, al):
        r = self._r(al)
        return Vector((self.hx * r * math.sin(phi), -self.hy * r * math.cos(phi), -self.hz * math.cos(al)))

    def normal(self, phi, al):
        e = 1e-3
        al = clamp(al, 0.02, math.pi - 0.02)
        dp = (self.point(phi + e, al) - self.point(phi - e, al))
        da = (self.point(phi, al + e) - self.point(phi, al - e))
        n = dp.cross(da)
        if n.length < 1e-9:
            return Vector((0, -1, 0))
        n.normalize()
        # orienta para fora
        if n.dot(self.point(phi, al)) < 0:
            n = -n
        return n

    def angles_at(self, x, z):
        """(phi, al) do ponto da face (frente) em (x, z)."""
        al = math.acos(clamp(-z / self.hz, -1, 1))
        r = max(self._r(al), 1e-3)
        s = clamp(x / (self.hx * r), -1, 1)
        return math.asin(s), al

    def surf(self, x, z, off=0.0):
        """Ponto e normal na superficie da face em (x, z), com deslocamento `off` pela normal."""
        phi, al = self.angles_at(x, z)
        p = self.point(phi, al)
        n = self.normal(phi, al)
        return p + n * off, n


def basis_from_normal(n, up=Vector((0, 0, 1))):
    """Matriz cujas colunas sao X (largura), Y (normal), Z (altura)."""
    y = n.normalized()
    z = (up - y * up.dot(y))
    if z.length < 1e-4:
        z = Vector((0, 1, 0))
    z.normalize()
    x = z.cross(y).normalized()
    return Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z)))


# ---------------------------------------------------------------- rosto

# ---------------------------------------------------------------- rosto em sprites 2D
# O rosto (olhos, sobrancelhas, boca, bochechas, sardas, cilios) e uma textura 2D desenhada por
# expressao e projetada na frente da cabeca: da para trocar a expressao so trocando o PNG
# (e e exatamente o que o jogo faz com sprites). Nariz e orelhas continuam 3D.

FACE_X = 0.205          # metade da largura coberta pelo sprite (m)
FACE_Z0, FACE_Z1 = -0.18, 0.125
FACE_PX = 4200          # pixels por metro da textura


def _catmull_pts(pts, n=24):
    out = []
    P = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n
            out.append(tuple(0.5 * ((2 * p1[c]) + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t * t
                                   + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t ** 3) for c in (0, 1)))
    out.append(tuple(pts[-1]))
    return out


def face_texture(cfg, expression=None):
    """Desenha o sprite do rosto (PNG RGBA) e devolve o caminho."""
    from PIL import Image, ImageDraw, ImageFilter
    f = cfg["face"]
    mouth = expression or f.get("mouth", "smile")
    sk = col(cfg["skin"], SKIN_TONES)
    hair_c = col(cfg["hair"]["color"], HAIR_COLORS)
    iris_c = col(f.get("eye_color", "preto"), EYE_COLORS)
    key = "%s_%s_%s_%s_%s_%s_%s_%s_%s_%s_%s" % (
        mouth, f.get("eyes"), iris_c[1:], f.get("eye_size"), f.get("eye_gap"), f.get("brows"),
        hair_c[1:], f.get("cheeks"), f.get("freckles"), f.get("lashes"), sk[1:])
    os.makedirs(DECAL_DIR, exist_ok=True)
    path = os.path.join(DECAL_DIR, "face_%s.png" % key)
    if os.path.exists(path):
        return path
    SS = 2
    W = int(2 * FACE_X * FACE_PX)
    H = int((FACE_Z1 - FACE_Z0) * FACE_PX)
    img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    k = FACE_PX * SS

    def P(x, z):
        return ((x + FACE_X) * k, (FACE_Z1 - z) * k)

    def ell(d, cx, cz, rx, rz, fill=None, outline=None, width=0):
        x0, y0 = P(cx - rx, cz + rz)
        x1, y1 = P(cx + rx, cz - rz)
        d.ellipse([x0, y0, x1, y1], fill=fill, outline=outline, width=int(width * k))

    def stroke(d, pts, w0, w1, color):
        cp = _catmull_pts(pts, 18)
        n = len(cp)
        for i, (x, z) in enumerate(cp):
            t = i / max(n - 1, 1)
            w = (w0 + (w1 - w0) * t) / 2
            ell(d, x, z, w, w, fill=color)

    ink = "#1c1218"
    d = ImageDraw.Draw(img)
    gap = 0.093 * f.get("eye_gap", 1.0)
    ez = -0.016
    esz = f.get("eyes_size", f.get("eye_size", 1.0))
    eyes = f.get("eyes", "round")

    # --- bochechas (camada borrada)
    if f.get("cheeks", True):
        ch = Image.new("RGBA", img.size, (0, 0, 0, 0))
        cd = ImageDraw.Draw(ch)
        for sgn in (-1, 1):
            ell(cd, sgn * 0.145, ez - 0.066, 0.036, 0.025, fill=(255, 112, 126, 150))
        ch = ch.filter(ImageFilter.GaussianBlur(0.011 * k))
        img = Image.alpha_composite(img, ch)
        d = ImageDraw.Draw(img)
    if f.get("freckles"):
        for sgn in (-1, 1):
            for (dx, dz) in ((0.115, -0.045), (0.145, -0.04), (0.13, -0.066), (0.165, -0.062), (0.1, -0.067),
                             (0.15, -0.085)):
                ell(d, sgn * dx, ez + dz, 0.0055, 0.0055, fill=shade(sk, 0.7))

    # --- olhos
    sizes = {"round": (0.043, 0.057), "dot": (0.025, 0.038), "wide": (0.052, 0.058), "sleepy": (0.046, 0.04)}[eyes]
    rx, rz = sizes[0] * esz, sizes[1] * esz
    squint = {"determined": 0.18, "smirk": 0.0}.get(mouth, 0.0)
    for sgn in (-1, 1):
        cx = sgn * gap
        if eyes == "dot":
            ell(d, cx, ez, rx, rz, fill=ink)
            ell(d, cx + rx * 0.3, ez + rz * 0.35, rx * 0.34, rx * 0.34, fill="#ffffff")
            ell(d, cx - rx * 0.25, ez - rz * 0.35, rx * 0.16, rx * 0.16, fill="#ffffff")
        else:
            ell(d, cx, ez, rx, rz, fill="#ffffff", outline=ink, width=0.0034)
            ir = rx * (0.8 if eyes == "wide" else 0.7)
            look = -sgn * 0.003
            ell(d, cx + look, ez - 0.002, ir, ir * 1.16, fill=iris_c)
            ell(d, cx + look, ez - 0.002, ir * 0.56, ir * 0.66, fill=ink)
            ell(d, cx + look + ir * 0.4, ez + ir * 0.55, ir * 0.25, ir * 0.25, fill="#ffffff")
            ell(d, cx + look - ir * 0.35, ez - ir * 0.4, ir * 0.11, ir * 0.11, fill="#ffffff")
            if eyes == "sleepy" or squint:
                lid = squint if squint else 0.3
                x0, y0 = P(cx - rx * 1.2, ez + rz * 1.2)
                x1, y1 = P(cx + rx * 1.2, ez + rz * (1 - 2 * lid))
                d.rectangle([x0, y0, x1, y1], fill=sk)
                stroke(d, [(cx - rx * 1.02, ez + rz * (1 - 2 * lid)), (cx, ez + rz * (1 - 2 * lid) - 0.002),
                           (cx + rx * 1.02, ez + rz * (1 - 2 * lid))], 0.0045, 0.0045, ink)
        if f.get("lashes"):
            o = 1 if sgn > 0 else -1
            for (dx, dz, ex, ez2) in ((0.78, 0.55, 1.3, 0.85), (0.95, 0.15, 1.55, 0.3), (0.55, 0.85, 0.95, 1.25)):
                stroke(d, [(cx + o * rx * dx, ez + rz * dz), (cx + o * rx * ex, ez + rz * ez2)], 0.0055, 0.003, ink)

    # --- sobrancelhas
    brows = f.get("brows", "soft")
    if brows != "none":
        th = {"soft": 0.0085, "thick": 0.0135, "thin": 0.0055}[brows]
        ang = {"determined": 0.04, "grin": -0.012, "smile": -0.004, "open": -0.018}.get(mouth, 0.0)
        bz = ez + 0.083 * (esz ** 0.3) - (0.012 if mouth == "determined" else 0.0)
        for sgn in (-1, 1):
            inner = (sgn * (gap - 0.04), bz - ang)
            mid = (sgn * gap, bz + 0.013 - ang * 0.2)
            outer = (sgn * (gap + 0.045), bz - 0.002 + ang * 0.8)
            stroke(d, [inner, mid, outer], th * 1.4, th * 0.9, hair_c)

    # --- boca
    mz = -0.128
    mc = "#6e2432"
    dark = "#7a1f33"
    if mouth == "smile":
        stroke(d, [(-0.042, mz + 0.014), (-0.02, mz - 0.006), (0.02, mz - 0.006), (0.042, mz + 0.014)], 0.0072, 0.0072, mc)
    elif mouth == "smirk":
        stroke(d, [(-0.034, mz + 0.003), (-0.01, mz - 0.003), (0.022, mz - 0.003), (0.046, mz + 0.018)], 0.0072, 0.0072, mc)
    elif mouth == "neutral":
        stroke(d, [(-0.028, mz), (0, mz - 0.002), (0.028, mz)], 0.007, 0.007, mc)
    elif mouth == "determined":
        stroke(d, [(-0.034, mz - 0.01), (-0.013, mz + 0.002), (0.013, mz + 0.002), (0.034, mz - 0.01)], 0.0075, 0.0075, mc)
    else:   # grin | open
        w, h = (0.062, 0.05) if mouth == "grin" else (0.034, 0.042)
        pts = [(-w, mz + 0.02)]
        for kk in range(0, 21):
            t = math.pi * kk / 20
            pts.append((-w * math.cos(t) * 0.98, mz + 0.012 - h * math.sin(t)))
        pts.append((w, mz + 0.02))
        poly = [P(x, z) for (x, z) in [(-w, mz + 0.014)] + [(-w * math.cos(math.pi * kk / 20), mz + 0.014 - h * math.sin(math.pi * kk / 20))
                                                             for kk in range(0, 21)] + [(w, mz + 0.014)]]
        d.polygon(poly, fill=dark)
        # lingua e dentes (recortados pela boca)
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ell(ld, 0, mz - h * 0.78, w * 0.62, h * 0.4, fill="#ff7a86")
        x0, y0 = P(-w * 1.1, mz + 0.016)
        x1, y1 = P(w * 1.1, mz + 0.016 - h * 0.28)
        ld.rectangle([x0, y0, x1, y1], fill="#ffffff")
        mask = Image.new("L", img.size, 0)
        ImageDraw.Draw(mask).polygon(poly, fill=255)
        layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", img.size, 0), mask))
        img = Image.alpha_composite(img, layer)
        d = ImageDraw.Draw(img)
        d.line(poly + [poly[0]], fill=mc, width=int(0.0045 * k), joint="curve")
    img = img.resize((W, H), Image.LANCZOS)
    img.save(path)
    return path


def face_material(path):
    key = ("FaceSprite", path)
    if key in _MAT_CACHE:
        return _MAT_CACHE[key]
    m = bpy.data.materials.new("FaceSprite")
    b = _bsdf(m)
    nt = m.node_tree
    _set(b, "Roughness", 0.55)
    _set(b, "Specular IOR Level", 0.2)
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(path)
    img.image.colorspace_settings.name = "sRGB"
    img.extension = "CLIP"
    nt.links.new(img.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(img.outputs["Alpha"], b.inputs["Alpha"])
    _MAT_CACHE[key] = m
    return m


def build_face(cfg, head, M, out, expression=None):
    f = cfg["face"]
    sk = col(cfg["skin"], SKIN_TONES)
    skin_m = skin_mat(sk)
    # sprite do rosto: grade (x, z) projetada na superficie da cabeca
    path = face_texture(cfg, expression)
    nu, nv = 44, 40
    uvs = []
    verts = []
    for j in range(nv):
        for i in range(nu):
            u = i / (nu - 1)
            v = j / (nv - 1)
            x = lerp(-FACE_X, FACE_X, u) * 0.98
            z = lerp(FACE_Z0, FACE_Z1, v)
            p, n = head.surf(x, z, 0.0014)
            verts.append(p)
            uvs.append((u, v))
    ob = make_obj("FaceSprite", verts, grid_faces(nu, nv, False), [face_material(path)], M=M, recalc=False,
                  merge=False, outline=False, inside=(0, 0, 0))
    uv = ob.data.uv_layers.new(name="UVMap")
    for loop in ob.data.loops:
        uv.data[loop.index].uv = uvs[loop.vertex_index]
    out.append(ob)

    # ---- nariz (3D, pequeno)
    nose = f.get("nose", "button")
    if nose != "none":
        nz = -0.062
        sz = {"button": (0.024, 0.020, 0.02), "long": (0.02, 0.024, 0.032), "small": (0.017, 0.015, 0.015)}[nose]
        p, n = head.surf(0, nz, 0.0)
        B = basis_from_normal(n)
        nose_m = mat("Nose", shade(sk, 0.93), rough=0.5, sss=0.12)
        out.append(ellipsoid("Nose", p + n * 0.006, sz, [nose_m], M=M, rot=B, nu=18, nv=12, outline=False))
        out.append(ellipsoid("NoseShine", p + n * 0.006 + B @ Vector((0.004, -sz[1] * 0.85, sz[2] * 0.35)),
                             (0.007, 0.004, 0.005), [mat("NoseShine", shade(sk, 1.25), rough=0.3)], M=M, rot=B,
                             nu=8, nv=6, outline=False))
    # ---- orelhas
    for s in (-1, 1):
        p = Vector((s * head.hx * 0.985, 0.012, -0.012))
        out.append(ellipsoid("Ear", p, (0.017, 0.026, 0.044), [skin_m], M=M,
                             rot=Matrix.Rotation(math.radians(-10 * s), 3, "Y"), nu=16, nv=10))


def export_face_sprites(cfg, outdir, expressions=("smile", "grin", "determined", "smirk", "neutral", "open")):
    """Grava um PNG por expressao (para usar como sprite no jogo)."""
    import shutil
    os.makedirs(outdir, exist_ok=True)
    paths = []
    for e in expressions:
        src = face_texture(cfg, e)
        dst = os.path.join(outdir, "face_%s_%s.png" % (cfg.get("name", "mii").lower(), e))
        shutil.copyfile(src, dst)
        paths.append(dst)
    return paths


def build_head_skin(cfg, head, M, out):
    sk = skin_mat(col(cfg["skin"], SKIN_TONES))
    nu, nv = 56, 40
    def fn(i, j):
        return head.point(2 * math.pi * i / nu, math.pi * j / (nv - 1))
    verts = [fn(i, j) for j in range(nv) for i in range(nu)]
    ob = make_obj("Head", verts, grid_faces(nu, nv, True), [sk], M=M, subsurf=1)
    out.append(ob)


# ---------------------------------------------------------------- cabelo

HAIR_STYLES = ["short", "buzz", "spiky", "afro", "ponytail", "bun", "bob", "long", "pigtails"]


HAIRLINES = {   # (angulo desde a frente em rad, z local): frente alta (testa e sobrancelhas livres), orelha livre
    "short": [(0, 0.105), (0.7, 0.098), (1.2, 0.062), (1.65, 0.034), (2.3, -0.04), (3.14, -0.09)],
    "buzz": [(0, 0.09), (0.7, 0.084), (1.2, 0.05), (1.65, 0.022), (2.3, -0.05), (3.14, -0.1)],
    "afro": [(0, 0.095), (0.7, 0.09), (1.2, 0.05), (1.65, 0.0), (2.3, -0.06), (3.14, -0.09)],
    "ponytail": [(0, 0.098), (0.7, 0.092), (1.2, 0.058), (1.65, 0.03), (2.3, -0.03), (3.14, -0.07)],
    "bob": [(0, 0.095), (0.7, 0.088), (1.2, 0.02), (1.65, -0.13), (2.3, -0.17), (3.14, -0.17)],
}
HAIRLINE_ALIAS = {"spiky": "short", "mohawk": "short", "bun": "ponytail", "pigtails": "ponytail", "long": "bob"}


def _hairline(style):
    """Altura minima (z local) do cabelo por angulo phi (0 frente, pi nuca)."""
    tab = HAIRLINES[HAIRLINE_ALIAS.get(style, style)]
    def f(phi):
        a = abs(((phi + math.pi) % (2 * math.pi)) - math.pi)
        for (a0, z0), (a1, z1) in zip(tab, tab[1:]):
            if a <= a1:
                return lerp(z0, z1, smooth((a - a0) / (a1 - a0)))
        return tab[-1][1]
    return f


def hair_cap(name, head, hairline, mats, M, thick=0.012, bulge=None, nu=64, nv=34, solid=0.012, extra_off=0.0,
             part=0.0):
    """Casco de cabelo sobre a cabeca, do hairline(phi) ate o topo."""
    def pos(i, j):
        phi = 2 * math.pi * i / nu
        zl = hairline(phi)
        al0 = math.acos(clamp(-zl / head.hz, -1, 1))
        al = lerp(al0, math.pi, j / (nv - 1))
        p = head.point(phi, al)
        n = head.normal(phi, al)
        k = thick + extra_off
        if bulge:
            k += bulge(phi, al, j / (nv - 1))
        return p + n * k
    verts = [pos(i, j) for j in range(nv) for i in range(nu)]
    ob = make_obj(name, verts, grid_faces(nu, nv, True), mats, M=M, subsurf=1, solidify=solid,
                  solidify_offset=-1.0, recalc=False, merge=True, inside=(0, 0, 0))
    return ob


def build_hair(cfg, head, M, out):
    h = cfg["hair"]
    style = h.get("style", "short")
    if style == "none":
        return
    hc = col(h.get("color", "castanho"), HAIR_COLORS)
    hm = hair_mat(hc)
    hm2 = hair_mat(shade(hc, 0.82))
    hl = _hairline(style)
    ang = lambda phi: abs(((phi + math.pi) % (2 * math.pi)) - math.pi)

    if style == "buzz":
        out.append(hair_cap("Hair", head, hl, [hm], M, thick=0.006, solid=0.004))
        return

    def top_bulge(amount, width=1.0):
        def b(phi, al, v):
            up = smooth((al - math.pi * 0.35) / (math.pi * 0.45))
            return amount * up
        return b

    if style in ("short", "spiky", "mohawk"):
        def bulge(phi, al, v):
            a = ang(phi)
            front_roll = 0.014 * smooth(1 - a / 1.0) * smooth((al - math.pi * 0.45) / 0.8) * \
                (1 - smooth((al - math.pi * 0.76) / (math.pi * 0.22)))   # topete na frente (some no polo)
            return 0.016 * smooth((al - math.pi * 0.35) / 0.9) + front_roll
        if style == "mohawk":
            out.append(hair_cap("HairShaved", head, _hairline("buzz"), [skin_mat(shade(col(cfg["skin"], SKIN_TONES), 0.86))], M, thick=0.005,
                                solid=0.004))
        else:
            out.append(hair_cap("Hair", head, hl, [hm], M, thick=0.01, bulge=bulge, solid=0.014))
        if style == "spiky":
            for k in range(9):
                phi = [0.0, 0.5, -0.5, 1.15, -1.15, 1.9, -1.9, 2.6, -2.6][k]
                al = math.pi * (0.78 if abs(phi) < 1.3 else 0.64)
                p = head.point(phi, al) + head.normal(phi, al) * 0.02
                n = head.normal(phi, al)
                up = (n * 1.0 + Vector((0, 0, 0.5))).normalized()
                out.append(tube("Spike", [p, p + up * 0.045, p + up * 0.095], [0.032, 0.02, 0.0035], [hm],
                                ref=(1, 0, 0), M=M, n=10, per=3, cap0=False, cap1=True))
        if style == "mohawk":
            pts = []
            for k in range(7):
                al = math.pi * (0.40 + k * 0.095)
                p = head.point(0, al) + head.normal(0, al) * 0.02
                pts.append(p + Vector((0, 0, 0.03 + 0.02 * math.sin(k / 6 * math.pi))))
            out.append(tube("Mohawk", pts, [(0.02, 0.026), (0.024, 0.04), (0.026, 0.055), (0.026, 0.062),
                                           (0.024, 0.055), (0.02, 0.04), (0.016, 0.025)], [hm],
                            ref=(1, 0, 0), M=M, n=12, per=4))
    elif style == "afro":
        def bulge(phi, al, v):
            fr = smooth(1 - ang(phi) / 1.3)
            return 0.01 + (0.17 - 0.07 * fr) * (smooth(v / 0.55) ** 0.8)
        out.append(hair_cap("Hair", head, hl, [hm], M, thick=0.012, bulge=bulge, solid=0.03, nv=44))
    elif style in ("ponytail", "pigtails", "bun"):
        def bulge(phi, al, v):
            return 0.012 * smooth((al - math.pi * 0.3) / 0.9)
        out.append(hair_cap("Hair", head, hl, [hm], M, thick=0.011, bulge=bulge, solid=0.014))
        if style == "ponytail":
            base = head.point(math.pi, math.pi * 0.74) + Vector((0, 0.03, 0))
            pts = [base, base + Vector((0, 0.065, 0.045)), base + Vector((0, 0.115, -0.03)),
                   base + Vector((0, 0.115, -0.15)), base + Vector((0, 0.085, -0.26)),
                   base + Vector((0, 0.095, -0.31))]
            out.append(tube("Ponytail", pts, [0.03, 0.04, 0.047, 0.044, 0.03, 0.006], [hm], ref=(1, 0, 0), M=M,
                            n=14, per=5))
            tie = mat("HairTie", "#ff5f8f", rough=0.5)
            out.append(tube("Tie", [base + Vector((-0.03, 0.045, 0.01)), base + Vector((0, 0.058, 0.02)),
                                    base + Vector((0.03, 0.045, 0.01))], [0.016, 0.018, 0.016], [tie],
                            ref=(0, 0, 1), M=M, n=10, per=4))
        elif style == "bun":
            c = head.point(math.pi, math.pi * 0.86) + Vector((0, -0.02, 0.07))
            out.append(ellipsoid("Bun", c + Vector((0, 0.02, 0.0)), (0.07, 0.07, 0.065), [hm], M=M, nu=24, nv=14))
            tie = mat("HairTie", "#ff5f8f", rough=0.5)
            out.append(tube("Tie", [c + Vector((-0.06, 0.02, -0.05)), c + Vector((0, 0.07, -0.05)),
                                    c + Vector((0.06, 0.02, -0.05)), c + Vector((0, -0.03, -0.05))],
                            [0.01, 0.012, 0.01, 0.012], [tie], ref=(0, 0, 1), M=M, n=8, per=4, closed=True))
        else:
            for s in (-1, 1):
                base = head.point(s * 1.9, math.pi * 0.7) + Vector((s * 0.045, 0.01, 0.0))
                pts = [base, base + Vector((s * 0.05, 0.02, -0.02)), base + Vector((s * 0.1, 0.03, -0.1)),
                       base + Vector((s * 0.1, 0.03, -0.2)), base + Vector((s * 0.085, 0.03, -0.27))]
                out.append(tube("Pigtail", pts, [0.03, 0.04, 0.043, 0.036, 0.008], [hm], ref=(1, 0, 0), M=M,
                                n=14, per=5))
                tie = mat("HairTie", "#ff5f8f", rough=0.5)
                out.append(ellipsoid("Tie", base + Vector((s * 0.052, 0.02, -0.022)), (0.022, 0.022, 0.016), [tie],
                                     M=M, nu=12, nv=8))
    elif style in ("bob", "long"):
        def bulge(phi, al, v):
            return 0.014 * smooth((al - math.pi * 0.3) / 0.9)
        out.append(hair_cap("Hair", head, _hairline("ponytail"), [hm], M, thick=0.012, bulge=bulge, solid=0.014))
        L = 0.2 if style == "bob" else 0.5
        flare = 0.03 if style == "bob" else 0.05
        curl = 0.04 if style == "bob" else 0.03
        def cur(i, j):
            u = i / 39
            phi = math.pi + (u - 0.5) * 2 * 1.52
            v = j / 11
            z0 = 0.02
            zz = z0 - v * (L + 0.02)
            rr = 1.0 + 0.06 + flare * v - curl * smooth((v - 0.7) / 0.3)
            r0 = head._r(math.acos(clamp(-max(zz, -head.hz * 0.95) / head.hz, -1, 1)))
            r0 = max(r0, 0.78)
            taper = 1 - 0.16 * smooth(abs(u - 0.5) * 2) ** 2 * v
            return Vector((head.hx * r0 * math.sin(phi) * rr * 1.02, -head.hy * r0 * math.cos(phi) * rr * 1.02
                           + 0.012, zz))
        out.append(sheet("HairBack", cur, 40, 12, [hm], M=M, solidify=0.016, solidify_offset=-1.0,
                         subsurf=1, merge=False, inside="axis"))
        # mechas laterais
        for s in (-1, 1):
            a = head.surf(s * 0.205, 0.0, 0.01)[0]
            b = head.surf(s * 0.215, -0.08, 0.016)[0]
            c = b + Vector((s * 0.0, 0.0, -(0.07 if style == "bob" else 0.22)))
            c += Vector((-s * 0.02, -0.01, 0))
            out.append(tube("SideLock", [a, b, c], [(0.014, 0.03), (0.02, 0.035), (0.011, 0.02)], [hm],
                            ref=(1, 0, 0), M=M, n=10, per=4))


# ---------------------------------------------------------------- acessorios

def _head_ring(head, zb, off, n=32):
    """Pontos de um anel horizontal ao redor da cabeca na altura zb, afastado `off` da pele."""
    al = math.acos(clamp(-zb / head.hz, -1, 1))
    return [head.point(2 * math.pi * k / n, al) + head.normal(2 * math.pi * k / n, al) * off for k in range(n)]


def _brim(name, head, zb, off, length, mat_, M, out, arc=1.15, thick=0.009, droop=0.032):
    """Aba curva presa na frente do anel (arredondada nas pontas e acompanhando a cabeca)."""
    al = math.acos(clamp(-zb / head.hz, -1, 1))

    def fn(i, j):
        u = i / 20
        phi = (u - 0.5) * 2 * arc
        v = j / 7
        e = abs(phi) / arc
        p = head.point(phi, al) + head.normal(phi, al) * off
        d = Vector((math.sin(phi), -math.cos(phi), 0)).normalized()
        L = length * math.sqrt(max(1 - e ** 3, 0.0)) * v
        z = zb - 0.006 - droop * v * v - 0.03 * e * e * v
        return Vector((p.x, p.y, z)) + d * L
    out.append(sheet(name, fn, 21, 8, [mat_], M=M, solidify=thick, solidify_offset=-1.0, subsurf=1, merge=False,
                     inside=(0, -0.1, -3.0)))


def build_accessories(cfg, head, M, out):
    acc = cfg["accessories"]
    if acc.get("visor"):    # viseira: faixa na testa + aba curva (sem coroa: o cabelo aparece)
        vm = cloth_mat("Visor", acc["visor"])
        zb = 0.1
        out.append(tube("VisorBand", _head_ring(head, zb, 0.038), [(0.028, 0.011)] * 32, [vm], ref=(0, 0, 1), M=M,
                        n=12, per=2, closed=True))
        _brim("VisorBrim", head, zb + 0.002, 0.044, 0.095, vm, M, out, arc=1.05, droop=0.03)
    if acc.get("cap"):      # bone: coroa + aba + botao
        cm = cloth_mat("Cap", acc["cap"])
        zb = 0.07
        out.append(hair_cap("CapDome", head, lambda phi: zb, [cm], M, thick=0.056, solid=0.012,
                            bulge=lambda phi, al, v: 0.012 * smooth(v / 0.4)))
        out.append(tube("CapBand", _head_ring(head, zb + 0.004, 0.056), [(0.014, 0.01)] * 32,
                        [cloth_mat("CapTrim", shade(acc["cap"], 0.8))], ref=(0, 0, 1), M=M, n=10, per=2, closed=True))
        _brim("CapBrim", head, zb + 0.012, 0.062, 0.13, cm, M, out, arc=1.25, droop=0.04)
        out.append(ellipsoid("CapButton", Vector((0, 0, head.hz + 0.062)), (0.017, 0.017, 0.012), [cm], M=M,
                             nu=12, nv=8))
    if acc.get("headband"):
        hb = cloth_mat("Headband", acc["headband"])
        out.append(tube("Headband", _head_ring(head, 0.07, 0.05), [(0.024, 0.011)] * 32, [hb], ref=(0, 0, 1), M=M,
                        n=10, per=2, closed=True))

    # --- oculos escuros / de grau (sempre usados nos olhos)
    for key in ("sunglasses", "glasses"):
        g = acc.get(key)
        if not g:
            continue
        style = g.get("style", "sport" if key == "sunglasses" else "round")
        gap = 0.093 * cfg["face"].get("eye_gap", 1.0)
        z0 = -0.016
        if key == "sunglasses":
            lens = mirror_mat(g.get("color", "mirror") if g.get("color") in ("mirror", "azul", "preta", "verde", "rosa")
                              else "mirror")
            frame = mat("FrameDark", "#1a1a24", rough=0.35, spec=0.7)
        else:
            lens = mat("GlassLens", "#d6ecff", rough=0.05, spec=1.0, coat=1.0)
            fc = g.get("color") or "#222222"
            frame = mat("Frame", fc if fc.startswith("#") else "#222222", rough=0.35, spec=0.7)
        rx, rz = {"sport": (0.074, 0.05), "round": (0.058, 0.058), "square": (0.066, 0.052),
                  "aviator": (0.07, 0.06)}[style]
        pw = {"sport": 3.2, "round": 2.0, "square": 4.0, "aviator": 2.4}[style]
        off = 0.036
        for s_ in (-1, 1):
            p, n = head.surf(s_ * gap, z0, off)
            B = basis_from_normal(n)

            def lensfn(i, j, B=B, p=p, rx=rx, rz=rz, pw=pw):
                t = 2 * math.pi * i / 36
                r = j / 5
                cx, sx = math.cos(t), math.sin(t)
                x = rx * r * (abs(cx) ** (2 / pw)) * (1 if cx >= 0 else -1)
                z = rz * r * (abs(sx) ** (2 / pw)) * (1 if sx >= 0 else -1)
                return p + B @ Vector((x, 0.004 * (1 - r * r), z))
            out.append(sheet("Lens", lensfn, 36, 6, [lens], M=M, closed_u=True, solidify=0.006, solidify_offset=0.0,
                             subsurf=1, merge=False, outline=False, inside=(0, 0.3, 0)))
            ring = []
            for k in range(36):
                t = 2 * math.pi * k / 36
                cx, sx = math.cos(t), math.sin(t)
                x = rx * (abs(cx) ** (2 / pw)) * (1 if cx >= 0 else -1)
                z = rz * (abs(sx) ** (2 / pw)) * (1 if sx >= 0 else -1)
                ring.append(p + B @ Vector((x, 0.0, z)))
            thick = 0.0075 if key == "sunglasses" else 0.0048
            out.append(tube("Rim", ring, [thick] * 36, [frame], ref=(0, 0, 1), M=M, n=8, per=2, closed=True,
                            outline=False))
            # haste: da lente ate a orelha, colada na lateral da cabeca
            a_ = head.surf(s_ * (gap + rx), z0, off * 0.8)[0]
            b_ = head.surf(s_ * 0.205, z0 + 0.0, 0.016)[0]
            c_ = head.point(s_ * 1.46, math.acos(clamp(-z0 / head.hz, -1, 1))) + Vector((0, 0.0, 0))
            out.append(tube("Temple", [a_, b_, c_], [0.0065, 0.0065, 0.006], [frame], ref=(0, 0, 1), M=M, n=8, per=4,
                            outline=False))
        a_ = head.surf(-gap + rx * 0.95, z0 + rz * 0.25, off)[0]
        b_ = head.surf(0, z0 + rz * 0.3, off + 0.004)[0]
        c_ = head.surf(gap - rx * 0.95, z0 + rz * 0.25, off)[0]
        out.append(tube("Bridge", [a_, b_, c_], [0.006, 0.006, 0.006], [frame], ref=(0, 0, 1), M=M, n=8, per=4,
                        outline=False))


# ================================================================== corpo

BODY = {
    "male": dict(
        shoulder_x=0.19, shoulder_z=1.3, elbow=(0.295, 0.0, 1.03), wrist=(0.365, -0.01, 0.83),
        hip_x=0.098, hip_z=0.905, knee=(0.108, -0.004, 0.482), ankle=(0.112, 0.0, 0.085),
        torso=[(0.935, 0.136, 0.096), (1.05, 0.141, 0.1), (1.17, 0.155, 0.104), (1.27, 0.178, 0.104),
               (1.335, 0.172, 0.098), (1.385, 0.12, 0.08), (1.425, 0.066, 0.062)],
        thigh=0.075, calf=0.055, arm=0.044, forearm=0.039, neck=0.058, head_z=1.645, belly=0.0,
        hips=(0.158, 0.108),
    ),
    "female": dict(
        shoulder_x=0.165, shoulder_z=1.3, elbow=(0.262, 0.0, 1.04), wrist=(0.322, -0.01, 0.85),
        hip_x=0.098, hip_z=0.915, knee=(0.106, -0.004, 0.488), ankle=(0.108, 0.0, 0.085),
        torso=[(0.945, 0.118, 0.09), (1.04, 0.124, 0.094), (1.17, 0.134, 0.098), (1.265, 0.152, 0.099),
               (1.33, 0.146, 0.093), (1.38, 0.105, 0.076), (1.42, 0.062, 0.058)],
        thigh=0.07, calf=0.05, arm=0.038, forearm=0.034, neck=0.05, head_z=1.64, belly=0.0,
        hips=(0.158, 0.106),
    ),
}


def profile(table, z, which):
    """Interpola o perfil do torso: which 1=rx 2=ry."""
    if z <= table[0][0]:
        return table[0][which]
    for a, b in zip(table, table[1:]):
        if z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return lerp(a[which], b[which], smooth(t))
    return table[-1][which]


def default_pose(gender):
    return {}


POSES = {
    "stand": {},
    "ready": {   # postura de espera: joelhos dobrados, raquete a frente
        "root": (0, 0, -0.07), "yaw": 20.0, "lean": 10.0, "twist": -12.0, "stance": 0.1,
        "arm_r": "ready_r", "arm_l": "ready_l", "foot_y": (0.06, -0.07), "head_turn": -8.0,
    },
    "forehand": {
        "root": (0.0, 0.0, -0.075), "yaw": -20.0, "lean": 12.0, "twist": 30.0, "stance": 0.13,
        "arm_r": "swing_r", "arm_l": "swing_l", "foot_y": (0.1, -0.1), "head_turn": -14.0,
    },
    "smash": {
        "root": (0.0, 0.0, 0.07), "yaw": 10.0, "lean": -10.0, "twist": 24.0, "stance": 0.05,
        "arm_r": "smash_r", "arm_l": "smash_l", "lift": 0.16, "foot_y": (0.05, -0.1), "head_turn": -10.0,
    },
    "cheer": {
        "root": (0.0, 0.0, 0.0), "yaw": 0.0, "lean": 0.0, "twist": 0.0, "stance": 0.03,
        "arm_r": "cheer_r", "arm_l": "cheer_l",
    },
}

# (cotovelo, pulso) como deslocamento do ombro: (para fora, para frente(-y), altura). Valores "para fora"
# valem para o lado de cada braco (o codigo espelha).
ARM_POSES = {
    "ready_r": ((0.1, -0.1, -0.22), (0.02, -0.3, -0.3)),
    "ready_l": ((0.11, -0.1, -0.22), (0.05, -0.3, -0.32)),
    "swing_r": ((0.18, -0.02, -0.06), (0.39, -0.17, 0.02)),
    "swing_l": ((0.13, -0.12, -0.2), (0.0, -0.28, -0.17)),
    "smash_r": ((0.14, 0.02, 0.16), (0.12, 0.0, 0.4)),
    "smash_l": ((0.16, -0.1, 0.1), (0.2, -0.26, 0.26)),
    "cheer_r": ((0.17, -0.03, 0.12), (0.22, -0.06, 0.37)),
    "cheer_l": ((0.17, -0.03, 0.12), (0.22, -0.06, 0.37)),
}

# raquete (eixo cabo->cabeca, normal da face) por pose; direcoes no espaco do boneco
RACKET = {
    "ready": ((-0.75, -0.25, 0.6), (0.0, -1.0, 0.0)),
    "forehand": ((-0.6, -0.2, 0.78), (0.0, -1.0, 0.0)),
    "smash": ((-0.15, -0.1, 1.0), (0.0, -1.0, 0.05)),
    "stand": ((-0.35, -0.15, 1.0), (0.0, -1.0, 0.0)),
    "cheer": ((-0.3, -0.1, 1.0), (0.0, -1.0, 0.0)),
}


def two_bone(hip, ank, L1, L2, fwd=Vector((0, -1, 0))):
    """Joelho por IK de dois ossos, dobrando para a frente."""
    d = ank - hip
    dist = min(d.length, (L1 + L2) * 0.9995)
    dirv = d.normalized()
    a = (L1 * L1 - L2 * L2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    perp = fwd - dirv * fwd.dot(dirv)
    perp.normalize()
    return hip + dirv * a + perp * h


def build_body(cfg, M, pose_name, out, head_info):
    """Corpo, roupa e acessorios de mao. Devolve dados de posicao da mao para a raquete."""
    g = cfg["gender"]
    B = BODY[g]
    pose = pose_name if isinstance(pose_name, dict) else POSES.get(pose_name, {})
    sk = skin_mat(col(cfg["skin"], SKIN_TONES))
    w = cfg.get("weight", 1.0)
    sh = cfg.get("shoulders", 1.0)
    root = Vector(pose.get("root", (0, 0, 0)))
    twist = math.radians(pose.get("twist", 0.0))
    lean = math.radians(pose.get("lean", 0.0))
    stance = pose.get("stance", 0.0)
    lift = pose.get("lift", 0.0)
    foot_y = pose.get("foot_y", (0.0, 0.0))     # (R, L) deslocamento em y dos pes

    pivot = Vector((0, 0, 0.935)) + root
    Mu = Matrix.Translation(pivot) @ Matrix.Rotation(twist, 4, "Z") @ Matrix.Rotation(lean, 4, "X") @ \
        Matrix.Translation(-pivot)

    def U(p):
        """Tronco torcido de forma progressiva: a pelve gira pouco, o peito gira todo."""
        p = Vector(p)
        t = smooth(clamp((p.z - root.z - 0.935) / 0.47))
        R = Matrix.Rotation(twist * lerp(0.3, 1.0, t), 3, "Z") @ Matrix.Rotation(lean * lerp(0.45, 1.0, t), 3, "X")
        return pivot + R @ (p - pivot)

    ref = Matrix.Rotation(twist * 0.65, 3, "Z") @ Vector((1, 0, 0))

    # ---------- pernas (IK: pes plantados, quadril acompanha o tronco)
    L1 = (Vector((B["hip_x"], 0, B["hip_z"])) - Vector(B["knee"])).length
    L2 = (Vector(B["knee"]) - Vector((B["ankle"][0], 0, B["ankle"][2]))).length
    legs_data = {}
    for s, nm, fy in ((-1, "R", foot_y[0]), (1, "L", foot_y[1])):
        hip = U(Vector((s * B["hip_x"], 0, B["hip_z"])) + root)
        ank = Vector((s * (B["ankle"][0] + stance), B["ankle"][1] + fy, B["ankle"][2] + (lift if s < 0 else lift * 0.7)))
        knee = two_bone(hip, ank, L1, L2)
        legs_data[nm] = (hip, knee, ank, s)
    hipR, kneeR, ankR, _ = legs_data["R"]
    hipL, kneeL, ankL, _ = legs_data["L"]

    thigh, calf = B["thigh"] * w, B["calf"] * w
    for nm in ("R", "L"):
        hip, knee, ank, s = legs_data[nm]
        mid = hip.lerp(knee, 0.5)
        calf_mid = knee.lerp(ank, 0.45) + Vector((0, 0.008, 0))
        out.append(tube("Leg" + nm, [hip + Vector((0, 0, -0.01)), mid, knee, calf_mid, ank],
                        [thigh * 0.82, thigh * 0.92, thigh * 0.74, calf * 1.0, calf * 0.8], [sk], ref=(1, 0, 0), M=M,
                        n=16, per=5))
        # pe descalco: tornozelo -> calcanhar -> peito do pe -> dedos
        zf = ank.z - 0.085
        heel = Vector((ank.x, ank.y + 0.04, 0.047 + zf))
        arch = Vector((ank.x, ank.y - 0.06, 0.04 + zf))
        ball = Vector((ank.x + s * 0.004, ank.y - 0.122, 0.033 + zf))
        toe = Vector((ank.x + s * 0.01, ank.y - 0.168, 0.042 + zf))
        out.append(tube("Foot" + nm, [heel + Vector((0, 0, 0.012)), arch, ball, toe],
                        [(0.046, 0.04), (0.05, 0.034), (0.056, 0.03), (0.046, 0.024)], [sk], ref=(1, 0, 0), M=M,
                        n=14, per=5))
        out.append(ellipsoid("Ankle" + nm, ank + Vector((0, 0.004, -0.004)), (0.042, 0.047, 0.042), [sk], M=M,
                             nu=16, nv=10))
        for k, (dx, r) in enumerate(((-0.03, 0.0135), (-0.015, 0.0125), (0.0, 0.0115), (0.015, 0.0105),
                                      (0.029, 0.0095))):
            tx = ank.x + s * 0.012 + dx * (1 if s < 0 else -1) * -1
            out.append(ellipsoid("Toe", Vector((tx, toe.y - 0.004 - abs(dx) * 0.12, 0.028 + zf)),
                                 (r, r * 1.2, r * 0.85), [sk], M=M, nu=10, nv=8))

    # ---------- tronco
    tor = B["torso"]
    def tprof(z, which):
        v = profile(tor, z, which)
        return v * (sh if which == 1 else 1.0) * (w if which == 1 else (w ** 0.5)) if False else \
            (v * sh * (w ** 0.5) if which == 1 else v * w)
    path, radii = [], []
    for z in (0.935, 1.0, 1.08, 1.17, 1.26, 1.33, 1.385, 1.425):
        path.append(U(Vector((0, 0, z)) + root))
        radii.append((tprof(z, 1), tprof(z, 2)))
    out.append(tube("Torso", path, radii, [sk], ref=ref, M=M, n=24, per=5))
    neck = Vector((0, 0, 1.40)) + root
    out.append(tube("Neck", [U(neck), U(neck + Vector((0, 0, 0.06)))], [B["neck"], B["neck"] * 0.95], [sk],
                    ref=ref, M=M, n=14, per=3, cap0=False, cap1=False))

    # ---------- bracos
    arm_r, arm_l = B["arm"] * w, B["forearm"] * w
    hand_info = {}
    for s, nm, key in ((-1, "R", "arm_r"), (1, "L", "arm_l")):
        sho = Vector((s * B["shoulder_x"] * sh, 0.0, B["shoulder_z"])) + root
        spec = pose.get(key)
        if isinstance(spec, str):
            spec = ARM_POSES.get(spec)
        if spec:
            de, dw = spec     # (cotovelo, pulso) relativos ao ombro: (fora, frente(-y), altura)
            elbow = sho + Vector((s * de[0], de[1], de[2]))
            wrist = sho + Vector((s * dw[0], dw[1], dw[2]))
        else:
            e0, wr0 = B["elbow"], B["wrist"]
            elbow = Vector((s * e0[0] * sh, e0[1], e0[2])) + root
            wrist = Vector((s * wr0[0] * sh, wr0[1], wr0[2])) + root
        shoU, elbU, wriU = U(sho), U(elbow), U(wrist)
        mid = elbU.lerp(wriU, 0.5)
        out.append(ellipsoid("Shoulder" + nm, shoU, (arm_r * 1.12, arm_r * 1.1, arm_r * 1.1), [sk], M=M, nu=18, nv=12))
        out.append(tube("Arm" + nm, [shoU, shoU.lerp(elbU, 0.5), elbU, mid, wriU],
                        [arm_r * 1.08, arm_r, arm_r * 0.88, arm_l * 0.95, arm_l * 0.85], [sk], ref=(0, 1, 0), M=M,
                        n=14, per=5))
        axis = (wriU - elbU).normalized()
        hand = wriU + axis * 0.05
        hand_info[nm] = {"wrist": wriU, "hand": hand, "axis": axis, "elbow": elbU, "shoulder": shoU}
        hs = 0.066 * (w ** 0.4)
        out.append(ellipsoid("Hand" + nm, hand, (hs, hs, hs), [sk], M=M, nu=22, nv=14))
        top_cfg = cfg["outfit"]["top"]
        if top_cfg.get("style", "tank") == "tee":
            lo_z = (M @ Vector((0, 0, 0.93))).z
            hi_z = (M @ Vector((0, 0, 1.42))).z
            sl_m = shirt_material(top_cfg, lo_z, hi_z, decal=False)
            e_ = shoU.lerp(elbU, 0.5)
            sd = (e_ - shoU).normalized()
            out.append(tube("Sleeve" + nm, [shoU - sd * 0.03, shoU.lerp(e_, 0.5), e_],
                            [arm_r * 1.12 + 0.017, arm_r * 1.1 + 0.017, arm_r * 1.02 + 0.021], [sl_m], ref=(0, 1, 0),
                            M=M, n=18, per=5, cap0=True, cap1=False))
            ua = sd.cross(Vector((0, 1, 0)))
            if ua.length < 1e-3:
                ua = sd.cross(Vector((1, 0, 0)))
            ua.normalize()
            va = sd.cross(ua).normalized()
            rr = arm_r * 1.02 + 0.023
            ring = [e_ + (ua * math.cos(t) + va * math.sin(t)) * rr for t in [2 * math.pi * kq / 20 for kq in range(20)]]
            out.append(tube("SleeveHem" + nm, ring, [(0.009, 0.007)] * 20, [cloth_mat("Trim", top_cfg.get("trim", "#ffffff"))],
                            ref=tuple(sd), M=M, n=8, per=2, closed=True, outline=False))

    # ---------- roupa
    build_outfit(cfg, M, Mu, U, root, out, ref, tor, w, sh, B,
                 (hipR, kneeR, hipL, kneeL), pose)

    # ---------- munhequeira
    wb = cfg["accessories"].get("wristband")
    if wb:
        nm = cfg["accessories"].get("wristband_side", "R")
        hi = hand_info[nm]
        c = hi["wrist"] - hi["axis"] * 0.012
        ax = hi["axis"]
        u = ax.cross(Vector((0, 1, 0)))
        if u.length < 1e-3:
            u = ax.cross(Vector((1, 0, 0)))
        u.normalize()
        v = ax.cross(u).normalized()
        r = arm_l * 1.0 + 0.011
        pts = [c + (u * math.cos(t) + v * math.sin(t)) * r for t in [2 * math.pi * k / 18 for k in range(18)]]
        bandm = cloth_mat("Wristband", wb)
        out.append(tube("Wristband", pts, [(0.03, 0.012)] * 18, [bandm], ref=tuple(ax), M=M, n=10, per=2,
                        closed=True))
    return hand_info, Mu


# ---------------------------------------------------------------- roupa

def torso_surface(Mu, root, tor, w, sh, z, phi, off):
    rx = profile(tor, z, 1) * sh * (w ** 0.5) + off
    ry = profile(tor, z, 2) * w + off
    return Mu @ (Vector((rx * math.sin(phi), -ry * math.cos(phi), z)) + root)


def make_decal(top):
    """Gera o PNG (numero + emblema de onda) que vai no peito da camisa."""
    from PIL import Image, ImageDraw, ImageFont
    os.makedirs(DECAL_DIR, exist_ok=True)
    key = "%s_%s_%s_%s" % (top.get("number", ""), top.get("emblem", ""), top["color_a"][1:], top["color_b"][1:])
    path = os.path.join(DECAL_DIR, "decal_%s.png" % key)
    S = 1024
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    em = top.get("emblem", "wave")
    trim = top.get("trim", "#ffffff")
    def pt(x, y):
        return (x * S, (1 - y) * S)
    if em == "wave":
        import math as m
        W = int(S * 0.056)
        # sol atras da onda
        cx, cy, r = 0.56, 0.37, 0.15
        d.ellipse([pt(cx - r, cy + r)[0], pt(cx - r, cy + r)[1], pt(cx + r, cy - r)[0], pt(cx + r, cy - r)[1]],
                  fill=top["color_b"])
        # crista da onda: sobe da esquerda, enrola e volta
        crest = []
        for k in range(0, 61):
            t = k / 60
            crest.append(pt(0.12 + 0.46 * t, 0.12 + 0.34 * (m.sin(t * m.pi * 0.5) ** 1.3)))
        for k in range(1, 56):
            t = k / 55 * 1.5 * m.pi
            rr = 0.115 * (1 - 0.45 * k / 55)
            crest.append(pt(0.62 + rr * m.sin(t * 0.95), 0.34 + rr * m.cos(t * 0.95)))
        d.line(crest, fill="#ffffff", width=W, joint="curve")
        for p in (crest[0], crest[-1]):
            d.ellipse([p[0] - W / 2, p[1] - W / 2, p[0] + W / 2, p[1] + W / 2], fill="#ffffff")
        for yy in (0.085, 0.03):
            wv = [pt(0.12 + 0.62 * t, yy + 0.02 * m.sin(t * 13)) for t in [k / 50 for k in range(51)]]
            d.line(wv, fill="#ffffff", width=int(S * 0.034), joint="curve")
    elif em == "star":
        import math as m
        pts = []
        for k in range(10):
            r = 0.2 if k % 2 == 0 else 0.085
            a = -m.pi / 2 + k * m.pi / 5
            pts.append(pt(0.38 + r * m.cos(a), 0.3 - r * m.sin(a) * -1))
        d.polygon(pts, fill=top["color_b"], outline="#ffffff")
    elif em == "ball":
        d.ellipse([S * 0.22, S * 0.12, S * 0.58, S * 0.48], fill="#d9f53c")
        d.arc([S * 0.12, S * 0.12, S * 0.46, S * 0.5], 300, 60, fill="#ffffff", width=int(S * 0.022))
        d.arc([S * 0.34, S * 0.12, S * 0.68, S * 0.5], 120, 240, fill="#ffffff", width=int(S * 0.022))
    num = top.get("number")
    if num:
        font = None
        for fp in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                   "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"):
            if os.path.exists(fp):
                font = ImageFont.truetype(fp, int(S * 0.2))
                break
        txt_pos = (S * 0.68, S * (1 - 0.69))
        if font:
            d.text(txt_pos, str(num), font=font, fill=trim, anchor="mm")
    img.save(path)
    return path


def shirt_material(top, z_lo=None, z_hi=None, decal=True):
    """Camisa com degrade vertical em coordenadas de mundo (continua entre corpo e mangas)."""
    key = ("Shirt", top["color_a"], top["color_b"], top.get("number"), top.get("emblem"), round(z_lo or 0, 3),
           round(z_hi or 0, 3), decal)
    if key in _MAT_CACHE:
        return _MAT_CACHE[key]
    m = bpy.data.materials.new("Shirt")
    b = _bsdf(m)
    nt = m.node_tree
    _set(b, "Roughness", 0.7)
    _set(b, "Sheen Weight", 0.35)
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sepo = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Object"], sepo.inputs[0])
    mp = nt.nodes.new("ShaderNodeMapRange")
    mp.inputs["From Min"].default_value = z_lo if z_lo is not None else 0.93
    mp.inputs["From Max"].default_value = z_hi if z_hi is not None else 1.42
    nt.links.new(sepo.outputs["Z"], mp.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.12
    ramp.color_ramp.elements[0].color = (*srgb(top["color_b"]), 1)
    ramp.color_ramp.elements[1].position = 0.82
    ramp.color_ramp.elements[1].color = (*srgb(top["color_a"]), 1)
    nt.links.new(mp.outputs[0], ramp.inputs[0])
    if not decal:
        nt.links.new(ramp.outputs[0], b.inputs["Base Color"])
        _MAT_CACHE[key] = m
        return m
    path = make_decal(top)
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Generated"], sep.inputs[0])
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(path)
    img.image.colorspace_settings.name = "sRGB"
    img.extension = "CLIP"
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(sep.outputs["X"], comb.inputs["X"])
    nt.links.new(sep.outputs["Z"], comb.inputs["Y"])
    nt.links.new(comb.outputs[0], img.inputs["Vector"])
    front = nt.nodes.new("ShaderNodeMath")
    front.operation = "LESS_THAN"
    front.inputs[1].default_value = 0.5
    nt.links.new(sep.outputs["Y"], front.inputs[0])
    am = nt.nodes.new("ShaderNodeMath")
    am.operation = "MULTIPLY"
    nt.links.new(img.outputs["Alpha"], am.inputs[0])
    nt.links.new(front.outputs[0], am.inputs[1])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(am.outputs[0], mix.inputs["Factor"])
    nt.links.new(ramp.outputs[0], mix.inputs["A"])
    nt.links.new(img.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    _MAT_CACHE[key] = m
    return m


def build_outfit(cfg, M, Mu, U, root, out, ref, tor, w, sh, B, legs, pose):
    top = cfg["outfit"]["top"]
    bot = cfg["outfit"]["bottom"]
    female = cfg["gender"] == "female"
    trim = cloth_mat("Trim", top.get("trim", "#ffffff"))
    sm = shirt_material(top, (M @ Vector((0, 0, 0.93))).z, (M @ Vector((0, 0, 1.42))).z)
    off = 0.011

    # ---- camiseta regata (grade phi x altura com decote e cavas)
    z_bot = 0.925 if not female else 0.945
    tee = top.get("style", "tank") == "tee"
    def top_z(phi):
        a = abs(math.sin(phi))               # 0 centro, 1 lado
        fb = math.cos(phi)                   # +1 frente, -1 costas
        strap = 1.405
        if tee:    # gola careca, sem cava: a manga cobre o ombro
            neck_f = lerp(1.352, strap, smooth((a - 0.12) / 0.2))
            neck_b = lerp(1.392, strap, smooth((a - 0.1) / 0.2))
            return neck_f if fb > 0 else neck_b
        armhole = 1.18 if not female else 1.19
        neck_f = lerp(1.305 if not female else 1.295, strap, smooth((a - 0.2) / 0.3))
        neck_b = lerp(1.365, strap, smooth((a - 0.12) / 0.26))
        neck = neck_f if fb > 0 else neck_b
        ah = lerp(strap, armhole, smooth((a - 0.8) / 0.19))     # alca larga: cobre o ombro
        return min(neck, ah)
    nu, nv = 64, 12
    def shirt(i, j):
        phi = 2 * math.pi * i / nu
        z = lerp(z_bot, top_z(phi), j / (nv - 1))
        flare = 1 + 0.025 * (1 - j / (nv - 1)) ** 2
        return U(Vector((((profile(tor, z, 1) * sh * (w ** 0.5)) + off) * flare * math.sin(phi),
                         -((profile(tor, z, 2) * w) + off) * flare * math.cos(phi), z)) + root)
    out.append(sheet("Shirt", shirt, nu, nv, [sm], M=M, closed_u=True, solidify=0.012,
                     solidify_offset=-1.0, subsurf=1, merge=False))
    # barra branca no decote e cavas
    for nm, cond in (("TrimNeck", None),):
        pass

    # ---- shorts / saia
    pc = cloth_mat("Shorts", bot["color"])
    stripe_a = cloth_mat("StripeA", bot.get("stripe_a", "#ffffff"))
    stripe_b = cloth_mat("StripeB", bot.get("stripe_b", "#f58a2a"))
    hips = B["hips"]
    hips = (hips[0] * sh ** 0.5 * (w ** 0.5), hips[1] * w)
    def pelvis_r(z):
        t = clamp((0.975 - z) / 0.16)
        wx = lerp(tor[0][1] * (w ** 0.5) * 1.0 + 0.012, hips[0] + 0.016, smooth(t * 1.4))
        wy = lerp(tor[0][2] * w + 0.012, hips[1] + 0.012, smooth(t * 1.4))
        return wx, wy
    zw = 0.985
    if bot.get("style", "shorts") in ("shorts", "long_shorts"):
        pw = pelvis_r(0.9)
        pel_pts = [U(Vector((0, 0, 0.83)) + root), U(Vector((0, 0, 0.88)) + root), U(Vector((0, 0, 0.94)) + root),
                   U(Vector((0, 0, 0.99)) + root)]
        pel_r = [(hips[0] + 0.012, hips[1] + 0.012), (hips[0] + 0.018, hips[1] + 0.016),
                 (hips[0] + 0.008, hips[1] + 0.012), (pelvis_r(0.985)[0] + 0.001, pelvis_r(0.985)[1])]
        out.append(tube("ShortsPelvis", pel_pts, pel_r, [pc], ref=ref, M=M, n=36, per=5, cap0=True, cap1=False))
        hem = 0.60 if bot.get("style") == "shorts" else 0.5
        if female and bot.get("style") == "shorts":
            hem = 0.66
        thr = B["thigh"] * w
        for (s_, hip, knee) in ((-1, legs[0], legs[1]), (1, legs[2], legs[3])):
            t_hem = (hip.z - hem) / (hip.z - knee.z)
            p0 = hip + Vector((0, 0, 0.0))
            p1 = hip.lerp(knee, 0.28)
            p2 = hip.lerp(knee, t_hem)
            rs = [thr * 0.95 + 0.015, thr * 1.0 + 0.019, thr * 0.9 + 0.024]
            out.append(tube("ShortsLeg", [p0, p1, p2], rs, [pc], ref=(1, 0, 0), M=M, n=22, per=6, cap0=True,
                            cap1=False))
            e = p2
            dl = (p2 - p1).normalized()
            ua = dl.cross(Vector((0, 1, 0)))
            if ua.length < 1e-3:
                ua = dl.cross(Vector((1, 0, 0)))
            ua.normalize()
            va = dl.cross(ua).normalized()
            ring = [e + (ua * math.cos(t) + va * math.sin(t)) * (rs[-1] + 0.003) for t in
                    [2 * math.pi * k / 24 for k in range(24)]]
            out.append(tube("Hem", ring, [(0.011, 0.007)] * 24, [stripe_a], ref=tuple(dl), M=M, n=8, per=2,
                            closed=True, outline=False))
            # listras laterais (branca + laranja) do cos ate a barra, seguindo o lado de fora
            top_o = U(Vector((s_ * (pelvis_r(0.955)[0] + 0.002), 0.0, 0.955)) + root)
            mid_o = U(Vector((s_ * (hips[0] + 0.02), 0.0, 0.905)) + root)
            path_o = [top_o, mid_o, p0 + Vector((s_ * (rs[0] + 0.004), 0, 0.0)),
                      p1 + Vector((s_ * (rs[1] + 0.004), 0, 0)), p2 + Vector((s_ * (rs[2] + 0.004), 0, 0.015))]
            for tag, dy, mt in (("StripeW", -0.011, stripe_a), ("StripeO", 0.011, stripe_b)):
                out.append(tube(tag, [p + Vector((0, dy, 0)) for p in path_o], [(0.006, 0.0105)] * 5, [mt],
                                ref=(1, 0, 0), M=M, n=8, per=6, outline=False))
    else:   # saia de tenis plissada
        zh = 0.73 if cfg["gender"] == "female" else 0.7
        nv3 = 8
        hipR_, kneeR_, hipL_, kneeL_ = legs

        def leg_extent(z, v, d):
            """Raio minimo da saia na direcao horizontal d para cobrir as duas coxas na altura z."""
            mg = 0.012 + 0.022 * smooth(v / 0.5)
            need = 0.0
            for hp, kn in ((hipR_, kneeR_), (hipL_, kneeL_)):
                t = clamp((hp.z - z) / max(hp.z - kn.z, 1e-3), 0.0, 1.0)
                c = hp.lerp(kn, t)
                r = thr_s * lerp(0.95, 0.78, t)
                need = max(need, c.x * d.x + c.y * d.y + r * 1.05 + mg)
            return need
        thr_s = B["thigh"] * w

        def skirt_r(phi, v, z, flare):
            rx0 = (pelvis_r(zw - 0.002)[0] + 0.008) * 1.04 * flare
            ry0 = (pelvis_r(zw - 0.002)[1] + 0.008) * 1.04 * flare
            d = Vector((math.sin(phi), -math.cos(phi), 0))
            base = (rx0 * ry0) / math.sqrt((ry0 * d.x) ** 2 + (rx0 * d.y) ** 2)
            return d, max(base, leg_extent(z + root.z, v, d))

        def skirt(i, j):
            phi = 2 * math.pi * i / 72
            v = j / (nv3 - 1)
            z = lerp(zw, zh, v)
            flare = 1 + 0.26 * smooth(v) ** 1.2
            d, r = skirt_r(phi, v, z, flare)
            pleat = 1 + 0.03 * math.sin(phi * 18) * v
            return Vector((d.x * r * pleat, d.y * r * pleat, z)) + root
        out.append(sheet("Skirt", skirt, 72, nv3, [pc], M=M, closed_u=True, solidify=0.008,
                         solidify_offset=-1.0, subsurf=1, merge=False))
        # barra listrada
        ring = []
        for k in range(48):
            phi = 2 * math.pi * k / 48
            d, r = skirt_r(phi, 1.0, zh, 1.26)
            ring.append(Vector((d.x * r, d.y * r, zh)) + root)
        out.append(tube("SkirtHem", ring, [(0.011, 0.006)] * 48, [stripe_b], ref=(0, 0, 1), M=M, n=8, per=2,
                        closed=True, outline=False))
        # shorts por baixo (shortinho tenis)
        def under(i, j):
            phi = 2 * math.pi * i / 40
            z = lerp(0.9, 0.7, j / 5)
            rx, ry = pelvis_r(0.9)
            return Vector((rx * 1.0 * math.sin(phi), -ry * math.cos(phi), z)) + root
    # ---- cos / cordao
    band = cloth_mat("Waistband", shade(bot["color"], 0.8))
    ring = []
    for k in range(40):
        phi = 2 * math.pi * k / 40
        rx, ry = pelvis_r(zw)
        ring.append(U(Vector((rx * math.sin(phi), -ry * math.cos(phi), zw)) + root))
    out.append(tube("Waistband", ring, [(0.015, 0.011)] * 40, [band], ref=(0, 0, 1), M=M, n=10, per=2, closed=True))
    cord = mat("Cord", "#ffffff", rough=0.6)
    rx, ry = pelvis_r(zw - 0.005)
    for s in (-1, 1):
        a = U(Vector((s * 0.022, -ry - 0.012, zw - 0.004)) + root)
        b = U(Vector((s * 0.034, -ry - 0.026, zw - 0.045)) + root)
        c = U(Vector((s * 0.03, -ry - 0.024, zw - 0.085)) + root)
        out.append(tube("Cord", [a, b, c], [0.0042, 0.0042, 0.0042], [cord], ref=(1, 0, 0), M=M, n=8, per=4,
                        outline=False))
    # tiras da regata e barra do decote
    for s in (-1, 1):
        pass


# ================================================================== raquete

def build_racket(M, hand_pos, axis_dir, face_dir, out, colors=None, ball=True, ball_pos=(0.0, -0.26, 0.66)):
    """Raquete de beach tennis: placa macica com furos. `axis_dir` = direcao do cabo -> cabeca,
    `face_dir` = normal da face. A origem fica no meio do cabo (onde a mao segura)."""
    axis = Vector(axis_dir).normalized()
    fd = Vector(face_dir)
    fd = (fd - axis * fd.dot(axis)).normalized()
    side = axis.cross(fd).normalized()
    R = Matrix(((side.x, fd.x, axis.x), (side.y, fd.y, axis.y), (side.z, fd.z, axis.z))).to_4x4()
    Mr = M @ Matrix.Translation(hand_pos) @ R @ Matrix.Translation((0, 0, -0.02))

    grip = mat("Grip", "#232330", rough=0.8, sheen=0.2)
    rim = mat("RacketRim", "#1e1d2c", rough=0.4, spec=0.7)
    # face com gradiente "splash" colorido
    m = bpy.data.materials.new("RacketFace")
    b = _bsdf(m)
    nt = m.node_tree
    _set(b, "Roughness", 0.32)
    _set(b, "Coat Weight", 0.5)
    coord = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 2.2
    noise.inputs["Detail"].default_value = 2.0
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Generated"], sep.inputs[0])
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    nt.links.new(sep.outputs["Z"], add.inputs[0])
    nt.links.new(noise.outputs["Fac"], add.inputs[1])
    nt.links.new(coord.outputs["Generated"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    cl = colors or ["#ff4fa0", "#ff9a2e", "#ffe14a", "#4fd36a", "#2fa8f0", "#8a4fe8"]
    ramp.color_ramp.elements[0].color = (*srgb(cl[0]), 1)
    ramp.color_ramp.elements[1].color = (*srgb(cl[-1]), 1)
    ramp.color_ramp.elements[0].position = 0.25
    ramp.color_ramp.elements[1].position = 1.15
    for k in range(1, len(cl) - 1):
        e = ramp.color_ramp.elements.new(0.25 + 0.9 * k / (len(cl) - 1))
        e.color = (*srgb(cl[k]), 1)
    nt.links.new(add.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], b.inputs["Base Color"])
    face = m

    # cabo
    out.append(tube("RacketHandle", [(0, 0, -0.05), (0, 0, 0.1), (0, 0, 0.2)], [0.0215, 0.0225, 0.021], [grip],
                    ref=(1, 0, 0), M=Mr, n=14, per=4, cap0=True, cap1=False))
    for k in range(5):
        z = -0.0 + k * 0.032
        out.append(tube("GripWrap", [(0.0, 0.0, z), (0.0, 0.0, z + 0.012)], [0.0243, 0.0243], [
            mat("GripWrap", "#ff9a2e", rough=0.6)], ref=(1, 0, 0), M=Mr, n=12, per=2, cap0=False, cap1=False,
            outline=False))
    # garganta + aro
    cz, rx, rz = 0.4, 0.118, 0.155
    ringpts = []
    for k in range(40):
        t = 2 * math.pi * k / 40
        x = rx * math.cos(t) * (1 - 0.1 * (math.sin(t) < 0) * 0.8)
        z = cz + rz * math.sin(t)
        ringpts.append((x, 0.0, z))
    out.append(tube("RacketRim", ringpts, [(0.016, 0.0165)] * 40, [rim], ref=(0, 1, 0), M=Mr, n=12, per=2,
                    closed=True))
    for s in (-1, 1):
        out.append(tube("Throat", [(0, 0, 0.18), (s * 0.03, 0.0, 0.25), (s * 0.075, 0.0, cz - rz + 0.012)],
                        [0.016, 0.014, 0.014], [rim], ref=(0, 1, 0), M=Mr, n=10, per=4, cap0=False, cap1=False))
    # placa
    def plate(i, j):
        t = 2 * math.pi * i / 40
        r = j / 5
        x = rx * 0.985 * r * math.cos(t) * (1 - 0.1 * (math.sin(t) < 0) * 0.8)
        z = cz + rz * 0.985 * r * math.sin(t)
        return Vector((x, 0.0, z))
    out.append(sheet("RacketFace", plate, 40, 6, [face], M=Mr, closed_u=True, solidify=0.022,
                     solidify_offset=0.0, merge=False, outline=False))
    # furos (discos escuros em ambas as faces)
    holes = []
    hole_verts, hole_faces = [], []
    step = 0.0395
    r_h = 0.0098
    k0 = 0
    for iy in range(-6, 7):
        for ix in range(-6, 7):
            x = ix * step + (0.5 * step if iy % 2 else 0)
            z = cz + iy * step * 0.88
            if (x / (rx * 0.82)) ** 2 + ((z - cz) / (rz * 0.84)) ** 2 > 1.0:
                continue
            for sgn in (-1, 1):
                base = len(hole_verts)
                for k in range(10):
                    a = 2 * math.pi * k / 10
                    hole_verts.append((x + r_h * math.cos(a), sgn * 0.0124, z + r_h * math.sin(a)))
                hole_verts.append((x, sgn * 0.0124, z))
                for k in range(10):
                    hole_faces.append((base + k, base + (k + 1) % 10, base + 10) if sgn > 0 else
                                      (base + (k + 1) % 10, base + k, base + 10))
    out.append(make_obj("RacketHoles", hole_verts, hole_faces, [mat("Hole", "#15141f", rough=0.5)], M=Mr,
                        smooth_shade=False, outline=False, merge=False, recalc=False))
    if ball:
        ballm = mat("Ball", "#d4f03a", rough=0.8, sheen=0.5)
        bp = Mr @ Vector(ball_pos)
        out.append(ellipsoid("Ball", bp, (0.04, 0.04, 0.04), [ballm], nu=24, nv=14))
    return Mr


# ================================================================== personagem

def build_character(cfg, pose="stand", origin=(0, 0, 0), yaw=0.0, with_racket=False, ball=False, head_only=False,
                    expression=None, racket_colors=None, ball_pos=(0.0, -0.26, 0.66)):
    """Constroi o personagem inteiro. Devolve a lista de objetos criados."""
    cfg = merge(MALE if cfg.get("gender", "male") == "male" else FEMALE, cfg) if "outfit" not in cfg else cfg
    cfg = copy.deepcopy(cfg)
    if expression:
        cfg["face"]["mouth"] = expression
    pose_d = pose if isinstance(pose, dict) else POSES.get(pose, {})
    sc = cfg.get("height", 1.0)
    yaw_t = Matrix.Rotation(math.radians(yaw + pose_d.get("yaw", 0.0)), 4, "Z")
    M = Matrix.Translation(Vector(origin)) @ yaw_t @ Matrix.Scale(sc, 4)
    out = []
    shape = cfg["face"].get("shape", "round")
    head = Head(shape, cfg.get("head_scale", 1.0))
    B = BODY[cfg["gender"]]
    hz = B["head_z"]
    hinfo = None
    if head_only:
        Mh = Matrix.Translation(Vector(origin)) @ yaw_t @ Matrix.Scale(sc, 4)
        Mh_head = Mh
        hairhead = Mh_head
    else:
        hinfo, Mu = build_body(cfg, M, pose, out, None)
        pr = pose_d
        root = Vector(pr.get("root", (0, 0, 0)))
        neck = Vector((0, 0, 1.36)) + root
        head_c = Vector((0, 0, hz + head.hz * 0.0)) + root
        look = math.radians(pr.get("head_turn", 0.0))
        tilt = math.radians(pr.get("head_tilt", 0.0))
        Mhead = Mu @ Matrix.Translation(Vector((0, 0, 0))) if False else Mu
        # cabeca acompanha o tronco, com leve contra-giro para olhar a frente
        counter = -0.45 * math.radians(pr.get("twist", 0.0))
        Mh_head = M @ Mu @ Matrix.Translation(head_c) @ Matrix.Rotation(counter, 4, "Z") @ \
            Matrix.Rotation(-math.radians(pr.get("lean", 0.0)) * 0.7 + tilt, 4, "X") @ Matrix.Rotation(look, 4, "Z")
        # Mu esta embutida em Mh_head; M ja multiplica os objetos do corpo
    if head_only:
        Mh_head = Matrix.Translation(Vector(origin)) @ yaw_t @ Matrix.Scale(sc, 4)
    build_head_skin(cfg, head, Mh_head, out)
    build_face(cfg, head, Mh_head, out, expression)
    build_hair(cfg, head, Mh_head, out)
    build_accessories(cfg, head, Mh_head, out)
    if with_racket and hinfo:
        hi = hinfo["R"]
        ax, fd = pose_d.get("racket") or RACKET.get(pose, RACKET["stand"])
        build_racket(M, hi["hand"], ax, fd, out, colors=racket_colors, ball=ball, ball_pos=ball_pos)
    return out

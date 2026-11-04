"""
Mock de gameplay (GIF) com os personagens Mii: partida 2x2 de beach tenis renderizada no Blender,
com a camera e o HUD do jogo. NAO e o Godot rodando: e uma animacao parametrica (poses por
parametros, sem armature) so para validar como os modelos novos ficam em quadra.

Uso:
    python blender/mii_gameplay.py frame <n> <saida.png>     # um quadro (teste)
    python blender/mii_gameplay.py all <pasta_de_quadros>    # todos os quadros
    (depois: ffmpeg -> GIF, veja o final deste arquivo / README)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402  (bpy antes de bmesh)
from mathutils import Matrix, Vector  # noqa: E402

import mii as MII  # noqa: E402
import mii_scene as S  # noqa: E402

FPS = 20
N_FRAMES = 84
RES = (720, 405)


# ================================================================== poses (interpoladas)

def P(**kw):
    base = dict(root=(0, 0, -0.07), lean=10.0, twist=-8.0, stance=0.10, lift=0.0, foot_y=(0.05, -0.06),
                arm_r=((0.1, -0.1, -0.22), (0.02, -0.3, -0.3)), arm_l=((0.11, -0.1, -0.22), (0.05, -0.3, -0.32)),
                head_turn=0.0, racket=((-0.75, -0.25, 0.6), (0, -1, 0)))
    base.update(kw)
    return base


READY = P()
BACK = P(root=(0, 0, -0.08), lean=12.0, twist=-38.0, stance=0.14, foot_y=(0.08, -0.08),
         arm_r=((0.2, 0.12, -0.04), (0.38, 0.22, 0.02)), arm_l=((0.14, -0.14, -0.18), (0.02, -0.3, -0.2)),
         racket=((-0.5, 0.5, 0.7), (0, -1, 0.3)))
HIT = P(root=(0, 0, -0.075), lean=12.0, twist=32.0, stance=0.13, foot_y=(0.1, -0.1),
        arm_r=((0.18, -0.02, -0.06), (0.39, -0.17, 0.02)), arm_l=((0.13, -0.12, -0.2), (0.0, -0.28, -0.17)),
        racket=((-0.6, -0.2, 0.78), (0, -1, 0)))
FOLLOW = P(root=(0, 0, -0.06), lean=8.0, twist=52.0, stance=0.12, foot_y=(0.09, -0.09),
           arm_r=((0.1, -0.12, 0.06), (-0.1, -0.28, 0.14)), arm_l=((0.1, -0.08, -0.2), (-0.05, -0.2, -0.28)),
           racket=((0.55, -0.35, 0.7), (0, -1, 0)))
SM_PREP = P(root=(0, 0, 0.0), lean=-14.0, twist=-22.0, stance=0.07, foot_y=(0.05, -0.05), lift=0.05,
            arm_r=((0.14, 0.06, 0.14), (0.12, 0.12, 0.38)), arm_l=((0.16, -0.1, 0.1), (0.2, -0.26, 0.26)),
            racket=((-0.15, 0.45, 0.9), (0, -1, 0.1)))
SM_HIT = P(root=(0, 0, 0.1), lean=6.0, twist=30.0, stance=0.06, foot_y=(0.05, -0.1), lift=0.2,
           arm_r=((0.12, 0.0, 0.18), (0.1, -0.12, 0.42)), arm_l=((0.12, -0.1, 0.0), (0.05, -0.2, -0.1)),
           racket=((-0.1, -0.6, 0.8), (0, -1, 0.2)))
LAND = P(root=(0, 0, -0.1), lean=16.0, twist=40.0, stance=0.1, arm_r=((0.14, -0.1, 0.0), (0.02, -0.28, 0.0)),
         racket=((-0.3, -0.5, 0.8), (0, -1, 0)))


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    if isinstance(a, dict):
        return {k: mix(a[k], b[k], t) for k in a}
    if isinstance(a, (tuple, list)):
        return tuple(mix(x, y, t) for x, y in zip(a, b))
    return a + (b - a) * t


def track(keys, f):
    """keys: [(frame, valor)] -> valor interpolado (suave) em f."""
    if f <= keys[0][0]:
        return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if f <= f1:
            return mix(v0, v1, ease((f - f0) / max(f1 - f0, 1e-6)))
    return keys[-1][1]


# ================================================================== elenco

def team(cfg, top_a, top_b, bottom, visor, number):
    c = MII.merge(cfg, {"outfit": {"top": {"color_a": top_a, "color_b": top_b, "number": number},
                                   "bottom": {"color": bottom, "stripe_b": top_b}},
                        "accessories": {"visor": visor, "wristband": "#ffffff"}})
    return c


BLUE = ("#2f7bff", "#8fd3ff", "#12306a")
RED = ("#ff4d4d", "#ffb199", "#6a1b1b")

CAST = {
    # time azul (perto da camera, de costas)
    "A": dict(cfg=team(MII.FEMALE, BLUE[0], BLUE[1], BLUE[2], "#2f7bff", "7"), yaw=180.0),
    "B": dict(cfg=team(MII.MALE, BLUE[0], BLUE[1], BLUE[2], "#2f7bff", "10"), yaw=180.0),
    # time vermelho (longe, de frente)
    "C": dict(cfg=team(MII.merge(MII.MALE, {"skin": "morena", "hair": {"style": "spiky", "color": "ruivo"},
                                            "face": {"mouth": "grin", "brows": "thick"}}),
                       RED[0], RED[1], RED[2], "#ff4d4d", "4"), yaw=0.0),
    "D": dict(cfg=team(MII.merge(MII.FEMALE, {"skin": "escura", "hair": {"style": "pigtails", "color": "preto"},
                                              "face": {"eye_color": "castanho"}}),
                       RED[0], RED[1], RED[2], "#ff4d4d", "9"), yaw=0.0),
}

# posicoes (x, y) ao longo do tempo
MOVES = {
    "A": [(0, (-2.4, -4.4)), (22, (-1.7, -3.6)), (34, (-2.2, -4.3)), (84, (-2.2, -4.3))],
    "B": [(0, (2.0, -4.5)), (46, (1.6, -4.4)), (64, (1.5, -3.3)), (80, (1.5, -3.6)), (84, (1.5, -3.6))],
    "C": [(0, (-2.0, 5.2)), (40, (-1.4, 4.3)), (58, (-1.9, 5.0)), (72, (-0.7, 4.2)), (84, (-0.6, 4.1))],
    "D": [(0, (1.7, 4.7)), (14, (1.9, 5.1)), (60, (1.8, 5.2)), (84, (0.9, 4.3))],
}

# fases de pose por jogador: [(frame, pose)]
PHASES = {
    "A": [(0, READY), (10, READY), (17, BACK), (23, HIT), (30, FOLLOW), (40, READY), (84, READY)],
    "B": [(0, READY), (50, READY), (58, SM_PREP), (65, SM_HIT), (71, LAND), (78, READY), (84, READY)],
    "C": [(0, READY), (36, READY), (42, BACK), (47, HIT), (54, FOLLOW), (64, READY), (72, LAND), (84, READY)],
    "D": [(0, FOLLOW), (8, READY), (84, READY)],
}
EXPR = {"A": [(0, "smile"), (84, "smile")], "B": [(0, "determined"), (64, "determined"), (66, "grin"), (84, "grin")],
        "C": [(0, "grin")], "D": [(0, "grin"), (10, "smile")]}

# eventos de rebatida: (quadro, jogador); a bola vai de uma raquete a outra
EVENTS = [(0, "D"), (23, "A"), (47, "C"), (65, "B")]
LAND_POINT = (0.4, 3.0, 0.12)
BOUNCE_END = 84
ARC = [3.1, 3.4, 5.4, 1.4]      # altura do arco de cada trecho


def pose_for(name, f):
    p = track(PHASES[name], f)
    out = dict(p)
    out["racket"] = p["racket"]
    return out


def expr_for(name, f):
    cur = EXPR[name][0][1]
    for fr, e in EXPR[name]:
        if f >= fr:
            cur = e
    return cur


def pos_for(name, f):
    return track(MOVES[name], f)


# ================================================================== cenario

def box_mesh(name, boxes, mat_, outline=False):
    verts, faces = [], []
    for (cx, cy, cz, sx, sy, sz) in boxes:
        b = len(verts)
        for dx in (-1, 1):
            for dy in (-1, 1):
                for dz in (-1, 1):
                    verts.append((cx + dx * sx / 2, cy + dy * sy / 2, cz + dz * sz / 2))
        for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            faces.append(tuple(b + i for i in q))
    return MII.make_obj(name, verts, faces, [mat_], smooth_shade=False, outline=outline)


def plane(name, x0, x1, y0, y1, z, mat_):
    return MII.make_obj(name, [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], [(0, 1, 2, 3)], [mat_],
                        smooth_shade=False, outline=False, recalc=False, merge=False)


def banner_texture(path, text, c1, c2):
    from PIL import Image, ImageDraw, ImageFont
    W, H = 1600, 160
    img = Image.new("RGB", (W, H), c1)
    d = ImageDraw.Draw(img)
    for i in range(0, W, 400):
        d.rectangle([i, 0, i + 200, H], fill=c2)
    f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 78)
    d.text((W / 2, H / 2), text, font=f, fill="#ffffff", anchor="mm")
    img.save(path)


def palm(x, y, lean, h, rot, mats):
    trunk, leaf = mats
    pts = [Vector((x, y, 0)), Vector((x + lean * 0.35, y, h * 0.45)), Vector((x + lean * 0.8, y, h * 0.8)),
           Vector((x + lean, y, h))]
    objs = [MII.tube("PalmTrunk", pts, [0.28, 0.22, 0.17, 0.14], [trunk], ref=(0, 1, 0), n=10, per=5,
                     outline=False)]
    top = pts[-1]
    for k in range(9):
        a = rot + k * 2 * math.pi / 9
        d = Vector((math.cos(a), math.sin(a), 0))
        lp = [top, top + d * 0.9 + Vector((0, 0, 0.35)), top + d * 1.8 + Vector((0, 0, 0.1)),
              top + d * 2.5 + Vector((0, 0, -0.7))]
        objs.append(MII.tube("PalmLeaf", lp, [(0.05, 0.28), (0.05, 0.34), (0.04, 0.28), (0.02, 0.05)], [leaf],
                             ref=(0, 0, 1), n=8, per=5, outline=False))
    return objs


def build_scenery():
    objs = []
    sand = MII.mat("SandGround", "#f1d08c", rough=0.95)
    sand2 = MII.mat("SandCourt", "#f6dc9e", rough=0.95)
    sea = MII.mat("Sea", "#27c7d6", rough=0.25, emit="#1aa9c9", emit_strength=0.25)
    sea2 = MII.mat("Sea2", "#3ee3d0", rough=0.3, emit="#3ee3d0", emit_strength=0.3)
    foam = MII.mat("Foam", "#ffffff", rough=0.6)
    objs.append(plane("Ground", -70, 70, -40, 12.5, 0.0, sand))
    objs.append(plane("Court", -4.6, 4.6, -7.6, 7.6, 0.004, sand2))
    objs.append(plane("Sea", -140, 140, 12.5, 120, -0.05, sea))
    objs.append(plane("SeaNear", -140, 140, 12.5, 24, -0.04, sea2))
    objs.append(plane("Foam", -140, 140, 12.1, 12.9, 0.01, foam))
    line = MII.mat("CourtLine", "#2c5fe0", rough=0.8)
    w = 0.1
    L = [(0, -7.5, 0.012, 9.1, w, 0.01), (0, 7.5, 0.012, 9.1, w, 0.01), (-4.5, 0, 0.012, w, 15.1, 0.01),
         (4.5, 0, 0.012, w, 15.1, 0.01)]
    objs.append(box_mesh("CourtLines", L, line))
    # rede
    post = MII.mat("Post", "#2a5ad6", rough=0.5)
    for sx in (-4.75, 4.75):
        objs.append(MII.tube("Post", [(sx, 0, 0), (sx, 0, 1.0), (sx, 0, 1.95)], [0.09, 0.08, 0.08], [post],
                             ref=(1, 0, 0), n=12, per=3, outline=False))
    net = MII.mat("Net", "#1d2644", rough=0.9)
    strands = []
    for k in range(10):
        strands.append((0, 0, 0.9 + k * 0.1, 9.4, 0.012, 0.012))
    for k in range(75):
        strands.append((-4.7 + k * 0.127, 0, 1.35, 0.012, 0.012, 0.9))
    objs.append(box_mesh("Net", strands, net))
    tape = MII.mat("NetTape", "#ffffff", rough=0.6)
    objs.append(box_mesh("NetTape", [(0, 0, 1.84, 9.5, 0.03, 0.1), (0, 0, 0.88, 9.5, 0.02, 0.05)], tape))
    # placas de publicidade
    tex = os.path.join(MII.DECAL_DIR, "banner.png")
    os.makedirs(MII.DECAL_DIR, exist_ok=True)
    banner_texture(tex, "SMASH NA AREIA  ·  BEACH TENNIS", "#2a5ad6", "#2f6bf0")
    bm = bpy.data.materials.new("Banner")
    bm.use_nodes = True
    nt = bm.node_tree
    bs = nt.nodes.get("Principled BSDF")
    im = nt.nodes.new("ShaderNodeTexImage")
    im.image = bpy.data.images.load(tex)
    nt.links.new(im.outputs["Color"], bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value = 0.7
    verts = [(-4.6, 7.9, 0.0), (4.6, 7.9, 0.0), (4.6, 7.9, 0.85), (-4.6, 7.9, 0.85)]
    ban = bpy.data.meshes.new("Banner")
    ban.from_pydata(verts, [], [(0, 1, 2, 3)])
    uv = ban.uv_layers.new()
    for l, (u, v) in zip(ban.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        uv.data[l.index].uv = (u, v)
    ban.materials.append(bm)
    bo = bpy.data.objects.new("Banner", ban)
    bpy.context.scene.collection.objects.link(bo)
    objs.append(bo)
    # palmeiras, guarda-sol
    trunk = MII.mat("Trunk", "#9a6a43", rough=0.8)
    leaf = MII.mat("Leaf", "#2fae5b", rough=0.6)
    for (x, y, lean, h, rot) in ((-7.4, 10.2, 0.9, 6.2, 0.3), (-5.2, 11.5, -0.5, 5.4, 1.1), (6.8, 10.0, -0.9, 6.6, 2.2),
                                 (8.9, 11.8, 0.4, 5.0, 0.6)):
        objs += palm(x, y, lean, h, rot, (trunk, leaf))
    pole = MII.mat("Pole", "#f4f4f4", rough=0.5)
    red = MII.mat("ParasolRed", "#ff4d4d", rough=0.6)
    objs.append(MII.tube("ParasolPole", [(6.6, 6.2, 0), (6.6, 6.2, 2.0)], [0.04, 0.04], [pole], ref=(1, 0, 0), n=8,
                         outline=False))
    objs.append(MII.ellipsoid("Parasol", (6.6, 6.2, 2.1), (1.25, 1.25, 0.4), [red], nu=28, nv=10, outline=False))
    # nuvens
    cloud = MII.mat("Cloud", "#ffffff", rough=1.0, emit="#ffffff", emit_strength=0.5)
    for (x, y, z, sc) in ((-12, 60, 14, 5), (6, 70, 18, 7), (20, 62, 12, 5), (-30, 75, 20, 6)):
        for k in range(4):
            objs.append(MII.ellipsoid("Cloud", (x + k * 0.9 * sc / 3, y, z + (k % 2) * 0.4 * sc / 3),
                                      (1.4 * sc / 3 + 0.3 * k, 0.9 * sc / 3, 0.7 * sc / 3), [cloud], nu=20, nv=10,
                                      outline=False))
    # arquibancada simples (laterais)
    for sx in (-1, 1):
        for step in range(3):
            objs.append(box_mesh("Stand", [(sx * (7.2 + step * 0.9), 0, 0.3 + step * 0.45, 0.9, 7.0, 0.6 + step * 0.9)],
                                 MII.mat("Stand", "#3a62c8" if sx < 0 else "#c84a4a", rough=0.8)))
    return objs


def setup_world_and_light():
    S.world(top="#5aa9f5", bottom="#eaf6ff", strength=1.0)
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(4)
    sun.color = (1.0, 0.95, 0.86)
    ob = bpy.data.objects.new("Sun", sun)
    bpy.context.scene.collection.objects.link(ob)
    d = Vector((0.45, 0.55, -0.7))
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    S.light("Fill", "AREA", (3, -9, 6), (0, 0, 1), 220, 8, "#cfe6ff")


# ================================================================== linhas (Freestyle) e quadros

def setup_lineart(px):
    sc = bpy.context.scene
    vl = bpy.context.view_layer
    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = "ABSOLUTE"
    sc.render.line_thickness = px * 2.0
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    fs.crease_angle = math.radians(125)
    for ls in list(fs.linesets):
        fs.linesets.remove(ls)
    col = bpy.data.collections.new("LineArt")
    sc.collection.children.link(col)
    ls = fs.linesets.new("Outline")
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = True
    ls.select_contour = False
    ls.select_external_contour = False
    ls.select_by_visibility = True
    ls.select_by_collection = True
    ls.collection = col
    st = bpy.data.linestyles.new("OutlineStyle")
    st.color = MII.srgb("#2b2034")
    st.thickness = 1.0
    st.caps = "ROUND"
    st.use_chaining = True
    ls.linestyle = st
    return col


def send_to_lineart(objs, col):
    for ob in objs:
        if ob.get("outline"):
            for c in list(ob.users_collection):
                c.objects.unlink(ob)
            col.objects.link(ob)


def purge(objs):
    for ob in objs:
        me = ob.data
        bpy.data.objects.remove(ob)
        if me is not None and me.users == 0:
            bpy.data.meshes.remove(me)


def racket_center(objs):
    for ob in objs:
        if ob.name.startswith("RacketFace"):
            bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
            return sum(bb, Vector()) / 8.0
    return None


def build_players(f, ball_hint=None, centers_only=False):
    objs, rackets = [], {}
    for name, c in CAST.items():
        x, y = pos_for(name, f)
        o = MII.build_character(c["cfg"], pose=pose_for(name, f), origin=(x, y, 0), yaw=c["yaw"], with_racket=True,
                                ball=False, expression=expr_for(name, f))
        rackets[name] = racket_center(o)
        objs += o
        sh = MII.ellipsoid("Shadow", (x, y, 0.01), (0.55, 0.4, 0.01), [MII.mat("ShadowBlob", "#b89b62", rough=1.0)],
                           nu=20, nv=6, outline=False)
        objs.append(sh)
    return objs, rackets


def ball_position(f, hit_points):
    """Posicao da bola no quadro f, dados os pontos de rebatida (centro da raquete) de cada evento."""
    seq = [(fr, hit_points[i]) for i, (fr, _) in enumerate(EVENTS)]
    for i in range(len(seq)):
        f0, p0 = seq[i]
        if i + 1 < len(seq):
            f1, p1 = seq[i + 1]
            arc = ARC[i]
        else:
            f1, p1 = BOUNCE_END - 4, Vector(LAND_POINT)
            arc = ARC[i]
        if f0 <= f <= f1:
            u = (f - f0) / max(f1 - f0, 1)
            p = p0.lerp(p1, u)
            p.z += arc * 4 * u * (1 - u) * (1 if i + 1 < len(seq) else 0.55)
            return p
    last = Vector(LAND_POINT)
    t = (f - (BOUNCE_END - 4)) / 4.0
    return Vector((last.x + 0.15 * t, last.y + 0.2 * t, 0.12 + 0.35 * 4 * t * (1 - t) * (1 if t < 1 else 0)))


def hit_points():
    """Pre-calcula onde esta a raquete de quem rebate no quadro do golpe."""
    pts = []
    for fr, who in EVENTS:
        objs, rk = build_players(fr)
        c = rk.get(who)
        pts.append(c if c else Vector((0, 0, 1.2)))
        purge(objs)
    return pts


# ================================================================== HUD

def hud(png_in, png_out, f, score_a, score_b):
    from PIL import Image, ImageDraw, ImageFont
    im = Image.open(png_in).convert("RGBA")
    W, H = im.size
    k = W / 960.0
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    fb = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    F = lambda s: ImageFont.truetype(fb, int(s * k))

    def poly(pts, fill, outline="#ffffff", w=3):
        d.polygon([(x * k, y * k) for x, y in pts], fill=fill)
        d.line([(x * k, y * k) for x, y in pts + [pts[0]]], fill=outline, width=int(w * k))
    poly([(275, 10), (410, 10), (410, 55), (285, 57)], "#2f6bf0")
    poly([(550, 10), (680, 10), (688, 57), (550, 55)], "#ff4d4d")
    d.text((345 * k, 24 * k), "TUBARÕES", font=F(17), fill="#ffffff", anchor="mm")
    d.text((620 * k, 24 * k), "SIRIS", font=F(17), fill="#ffffff", anchor="mm")
    for x0, c in ((410, "#ffffff"), (500, "#ffffff")):
        d.rectangle([x0 * k, 14 * k, (x0 + 50 * k / k) * k, 54 * k], fill=c, outline="#222244", width=int(2 * k))
    d.rectangle([460 * k, 20 * k, 500 * k, 48 * k], fill="#ffd23f")
    d.text((435 * k, 35 * k), str(score_a), font=F(30), fill="#1b1b3a", anchor="mm")
    d.text((480 * k, 35 * k), "x", font=F(20), fill="#1b1b3a", anchor="mm")
    d.text((525 * k, 35 * k), str(score_b), font=F(30), fill="#1b1b3a", anchor="mm")
    d.rectangle([280 * k, 62 * k, 685 * k, 70 * k], fill="#ff9f1c")
    # botoes
    def btn(cx, cy, r, color, text):
        d.ellipse([(cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k], fill=color, outline="#ffffff", width=int(3 * k))
        d.text((cx * k, cy * k), text, font=F(r * (0.42 if len(text) < 5 else 0.27)), fill="#ffffff", anchor="mm")
    btn(865, 400, 38, "#8e44d8", "LOB")
    btn(915, 450, 36, "#e0383e", "SMASH")
    btn(810, 450, 36, "#f0861f", "FORTE")
    btn(865, 500, 36, "#3b9fd8", "CURTA")
    btn(760, 440, 28, "#9aa0aa", "DEFESA")
    btn(770, 505, 26, "#9aa0aa", "PEIXINHO")
    d.ellipse([45 * k, 395 * k, 145 * k, 495 * k], outline="#ffffff", width=int(3 * k), fill=(255, 255, 255, 50))
    d.text((95 * k, 445 * k), "MOVER", font=F(15), fill="#ffffffcc", anchor="mm")
    # onomatopeia no smash
    if 64 <= f <= 76:
        t = (f - 64) / 12.0
        sz = 70 + 18 * math.sin(min(t * 2, 1) * math.pi)
        txt = Image.new("RGBA", im.size, (0, 0, 0, 0))
        td = ImageDraw.Draw(txt)
        cx, cy = 560 * k, 190 * k
        for dx, dy in ((-4, -4), (4, -4), (-4, 4), (4, 4), (0, 6), (0, -6), (6, 0), (-6, 0)):
            td.text((cx + dx * k, cy + dy * k), "SMASH!", font=F(sz), fill="#1b1b3a", anchor="mm")
        td.text((cx, cy), "SMASH!", font=F(sz), fill="#ffd23f", anchor="mm")
        txt = txt.rotate(8, resample=Image.BICUBIC, center=(cx, cy))
        ov = Image.alpha_composite(ov, txt)
    Image.alpha_composite(im, ov).convert("RGB").save(png_out)


# ================================================================== principal

def setup_scene():
    S.reset()
    scenery = build_scenery()
    setup_world_and_light()
    S.camera((0, -12.5, 5.0), (0, 1.8, 1.0), lens=34)
    S.setup_render(RES[0], RES[1], samples=14)
    bpy.context.scene.view_settings.exposure = 0.0
    col = setup_lineart(px=0.8)
    return scenery, col


def render_frame(f, hit_pts, col, out):
    objs, _ = build_players(f)
    bp = ball_position(f, hit_pts)
    ball = MII.ellipsoid("Ball", bp, (0.09, 0.09, 0.09), [MII.mat("Ball", "#d4f03a", rough=0.8, sheen=0.5)],
                         nu=18, nv=10)
    ballshadow = MII.ellipsoid("BallShadow", (bp.x, bp.y, 0.011), (0.14, 0.1, 0.005),
                               [MII.mat("BallShadow", "#c9ab72", rough=1.0)], nu=12, nv=4, outline=False)
    objs += [ball, ballshadow]
    send_to_lineart(objs, col)
    raw = out + ".raw.png"
    S.render(raw)
    score = (15, 0) if f < 76 else (30, 0)
    hud(raw, out, f, *score)
    os.remove(raw)
    purge(objs)


if __name__ == "__main__":
    mode = sys.argv[1]
    scenery, col = setup_scene()
    hp = hit_points()
    if mode == "frame":
        render_frame(int(sys.argv[2]), hp, col, sys.argv[3])
        print("OK", sys.argv[3])
    else:
        outdir = sys.argv[2]
        os.makedirs(outdir, exist_ok=True)
        a = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        b = int(sys.argv[4]) if len(sys.argv) > 4 else N_FRAMES
        for f in range(a, b):
            render_frame(f, hp, col, os.path.join(outdir, "f%03d.png" % f))
            print("frame", f, flush=True)
        print("ALLDONE")

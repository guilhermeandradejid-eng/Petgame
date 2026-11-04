"""
Amostras de validacao dos personagens Mii (Smash na Areia).

Uso:  python blender/mii_samples.py <modelo> <saida.png> [genero] [qualidade]
  modelo:  sheet | actions | custom | hero | faces
  genero:  male | female
  qualidade: draft | final

Gera as imagens em docs/mii/.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import mii as MII  # noqa: E402
import mii_scene as S  # noqa: E402

Q = {"draft": 0.5, "final": 1.0}


def base(gender):
    return MII.MALE if gender == "male" else MII.FEMALE


def finish(objs, w, h, samples, ortho=None, cam=None, target=None, lens=60, light_center=(0, 0, 0.9), light_scale=1.6,
           px=2.6, out=None):
    S.add_outlines(objs, px=px)
    S.world()
    S.studio(light_center, scale=light_scale)
    S.camera(cam, target, ortho_scale=ortho, lens=lens)
    S.setup_render(w, h, samples=samples)
    S.render(out)


# ---------------------------------------------------------------- prancha de modelo (turnaround + expressoes)

def sheet(gender, out, q):
    S.reset()
    cfg = base(gender)
    objs = []
    zrow = 2.12
    # linha de cima: frente / lado / costas
    for x, yaw in ((-2.35, 0), (-0.75, -90), (0.85, 180)):
        objs += MII.build_character(cfg, origin=(x, 0, zrow), yaw=yaw)
        objs.append(S.ground((x, -0.02, zrow)))
    # expressoes (cabecas) na lateral
    exps = (("grin", 1.0), ("determined", 1.0), ("smirk", 1.0))
    for k, (e, _) in enumerate(exps):
        objs += MII.build_character(cfg, origin=(2.55 + (0.62 if k == 1 else 0.0), 0, zrow + 1.55 - k * 0.66), yaw=(-14, 12, -10)[k],
                                    head_only=True, expression=e)
    # linha de baixo: poses de jogo
    for x, pose, yaw, bp in ((-2.0, "forehand", 0, (0.0, -0.26, 0.66)), (0.0, "smash", 0, (0.1, -0.2, 0.7)),
                              (2.0, "ready", 0, (0.0, -0.3, 0.62))):
        objs += MII.build_character(cfg, origin=(x, 0, 0), yaw=yaw, pose=pose, with_racket=True,
                                    ball=(pose != "ready"), ball_pos=bp)
        objs.append(S.ground((x, -0.02, 0), size=(0.7, 0.45)))
    w, h = int(2400 * Q[q]), int(1500 * Q[q])
    finish(objs, w, h, 96 if q == "final" else 24, ortho=7.3, cam=(0, -12, 4.0), target=(0, 0, 2.02),
           light_center=(0, 0, 1.6), light_scale=2.4, px=2.4 * Q[q], out=out)


# ---------------------------------------------------------------- grade de personalizacao

MALE_VARIANTS = [
    ("porcelana + buzz", {"skin": "porcelana", "hair": {"style": "buzz", "color": "preto"},
                          "accessories": {"visor": None, "cap": "#e63946", "sunglasses": None},
                          "outfit": {"top": {"color_a": "#ff5d73", "color_b": "#ffd166", "number": "3"},
                                     "bottom": {"color": "#22325a"}}}),
    ("dourada + spiky ruivo", {"skin": "dourada", "hair": {"style": "spiky", "color": "ruivo"},
                               "face": {"eyes": "wide", "mouth": "grin", "brows": "thick"},
                               "accessories": {"visor": "#ffd23f", "sunglasses": {"style": "sport", "color": "mirror"}},
                               "outfit": {"top": {"style": "tee", "color_a": "#2ec4b6", "color_b": "#ff9f1c", "number": "8", "emblem": "ball"},
                                          "bottom": {"color": "#243b53"}}}),
    ("morena + afro", {"skin": "morena", "hair": {"style": "afro", "color": "preto"}, "weight": 1.12,
                       "face": {"eyes": "dot", "nose": "long", "mouth": "smirk"},
                       "accessories": {"visor": None, "headband": "#f25c54", "glasses": {"style": "round", "color": "#1d3557"}, "sunglasses": None},
                       "outfit": {"top": {"color_a": "#845ef7", "color_b": "#f783ac", "number": "21", "emblem": "star"},
                                  "bottom": {"color": "#343a40"}}}),
    ("escura + mohawk azul", {"skin": "escura", "hair": {"style": "spiky", "color": "azul"}, "height": 1.05,
                              "face": {"eyes": "round", "eye_color": "verde", "mouth": "determined", "freckles": False},
                              "accessories": {"visor": None, "sunglasses": {"style": "square", "color": "azul"}},
                              "outfit": {"top": {"style": "tee", "color_a": "#fcc419", "color_b": "#ff6b6b", "number": "99", "emblem": "wave"},
                                         "bottom": {"color": "#101828"}}}),
    ("ebano + curto grisalho", {"skin": "ebano", "hair": {"style": "short", "color": "grisalho"}, "weight": 0.92,
                                "face": {"shape": "square", "eyes": "sleepy", "brows": "thick", "mouth": "smile"},
                                "accessories": {"visor": "#ffffff", "sunglasses": None, "wristband": "#e03131"},
                                "outfit": {"top": {"color_a": "#51cf66", "color_b": "#fff3bf", "number": "5", "emblem": "wave"},
                                           "bottom": {"color": "#0b7285"}}}),
]
FEMALE_VARIANTS = [
    ("porcelana + coque", {"skin": "porcelana", "hair": {"style": "bun", "color": "loiro"},
                           "face": {"eye_color": "azul", "freckles": True},
                           "accessories": {"visor": None, "headband": "#ff6b9d", "sunglasses": None},
                           "outfit": {"top": {"color_a": "#74c0fc", "color_b": "#fff3bf", "number": "9"},
                                      "bottom": {"style": "skirt", "color": "#f06595"}}}),
    ("dourada + maria-chiquinha", {"skin": "dourada", "hair": {"style": "pigtails", "color": "rosa"},
                                   "face": {"eye_color": "mel", "mouth": "grin"},
                                   "accessories": {"visor": "#74c0fc", "sunglasses": None},
                                   "outfit": {"top": {"color_a": "#da77f2", "color_b": "#ffd43b", "number": "14", "emblem": "star"},
                                              "bottom": {"style": "shorts", "color": "#364fc7"}}}),
    ("morena + bob", {"skin": "morena", "hair": {"style": "bob", "color": "roxo"},
                      "face": {"eyes": "wide", "eye_color": "verde", "mouth": "smirk"},
                      "accessories": {"visor": None, "sunglasses": {"style": "round", "color": "rosa"}},
                      "outfit": {"top": {"style": "tee", "color_a": "#38d9a9", "color_b": "#ffe066", "number": "11", "emblem": "ball"},
                                 "bottom": {"style": "skirt", "color": "#087f5b"}}}),
    ("marrom + cabelao", {"skin": "marrom", "hair": {"style": "long", "color": "preto"},
                          "face": {"shape": "round", "eye_color": "castanho", "mouth": "smile", "brows": "soft"},
                          "accessories": {"visor": "#ffa94d", "sunglasses": None, "wristband": "#ffffff"},
                          "outfit": {"top": {"color_a": "#ff8787", "color_b": "#ffd8a8", "number": "6", "emblem": "wave"},
                                     "bottom": {"style": "shorts", "color": "#1c7ed6"}}}),
    ("escura + afro", {"skin": "escura", "hair": {"style": "afro", "color": "castanho"}, "weight": 1.1,
                       "face": {"eyes": "dot", "mouth": "grin", "nose": "button"},
                       "accessories": {"visor": None, "headband": "#fab005", "glasses": {"style": "round", "color": "#c2255c"}, "sunglasses": None},
                       "outfit": {"top": {"style": "tee", "color_a": "#ffa8a8", "color_b": "#ffe8cc", "number": "1", "emblem": "star"},
                                  "bottom": {"style": "skirt", "color": "#5f3dc4"}}}),
]


def custom(gender, out, q):
    S.reset()
    objs = []
    variants = MALE_VARIANTS if gender == "male" else FEMALE_VARIANTS
    cfg0 = base(gender)
    for i, (label, over) in enumerate(variants):
        x = (i - 2) * 1.55
        cfg = MII.merge(cfg0, over)
        objs += MII.build_character(cfg, origin=(x, 0, 0), yaw=(-14, 10, -8, 12, -10)[i])
        objs.append(S.ground((x, -0.02, 0), size=(0.62, 0.4)))
    w, h = int(2400 * Q[q]), int(900 * Q[q])
    finish(objs, w, h, 96 if q == "final" else 24, ortho=7.9, cam=(0, -12, 3.0), target=(0, 0, 0.93),
           light_center=(0, 0, 1.0), light_scale=2.6, px=2.4 * Q[q], out=out)


# ---------------------------------------------------------------- retrato / hero

def hero(gender, out, q):
    S.reset()
    cfg = base(gender)
    objs = MII.build_character(cfg, pose="ready", yaw=0, with_racket=True, ball=False)
    objs.append(S.ground((0, -0.02, 0)))
    w, h = int(1500 * Q[q]), int(1500 * Q[q])
    finish(objs, w, h, 128 if q == "final" else 24, cam=(1.5, -3.5, 1.35), target=(0, 0, 0.92), lens=50,
           light_center=(0, 0, 1.0), light_scale=1.6, px=3.0 * Q[q], out=out)


# ---------------------------------------------------------------- close de rostos

def faces(gender, out, q):
    S.reset()
    cfg = base(gender)
    objs = []
    for i, (e, yaw) in enumerate((("smile", -18), ("grin", 14), ("determined", -10), ("smirk", 16))):
        objs += MII.build_character(cfg, origin=((i - 1.5) * 0.8, 0, 0), yaw=yaw, head_only=True, expression=e)
    w, h = int(2400 * Q[q]), int(780 * Q[q])
    finish(objs, w, h, 96 if q == "final" else 24, cam=(0, -6.0, 0.35), target=(0, 0, 0.02), lens=85,
           light_center=(0, 0, 0.0), light_scale=1.2, px=3.0 * Q[q], out=out)


def sprites(gender, out, q):
    """Grava os sprites de expressao (PNG com transparencia) do rosto, em <out>/ (pasta)."""
    S.reset()
    cfg = base(gender)
    for p in MII.export_face_sprites(cfg, out):
        print("sprite", p)


if __name__ == "__main__":
    kind, out = sys.argv[1], sys.argv[2]
    gender = sys.argv[3] if len(sys.argv) > 3 else "male"
    q = sys.argv[4] if len(sys.argv) > 4 else "draft"
    if kind != "sprites":
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    {"sheet": sheet, "custom": custom, "hero": hero, "faces": faces, "sprites": sprites}[kind](gender, out, q)
    print("OK", out)

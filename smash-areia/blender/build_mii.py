"""
Monta UM personagem Mii a partir de um JSON (ou de argumentos) e renderiza / salva.

Exemplos (com o modulo `bpy`:  pip install bpy):

    python blender/build_mii.py --gender female --out docs/mii/minha_bia.png
    python blender/build_mii.py --gender male --pose forehand --racket \
        --set skin=morena --set hair.style=afro --set hair.color=preto --out saque.png
    python blender/build_mii.py --config meu_personagem.json --blend meu.blend --out meu.png

`--set caminho.com.pontos=valor` sobrescreve qualquer campo do cfg (veja OPCOES em
`mii_options.md` ou os dicionarios MALE/FEMALE em mii.py). Valores sao lidos como JSON
quando possivel ("true", "1.05", "null", "{...}"), senao como texto.
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import mii as MII  # noqa: E402
import mii_scene as S  # noqa: E402


def set_path(d, path, value):
    keys = path.split(".")
    for k in keys[:-1]:
        d = d.setdefault(k, {})
    d[keys[-1]] = value


def parse_value(v):
    try:
        return json.loads(v)
    except ValueError:
        return v


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--gender", choices=["male", "female"], default="male")
    ap.add_argument("--config", help="JSON com sobrescritas do cfg padrao")
    ap.add_argument("--set", action="append", default=[], help="campo.sub=valor (pode repetir)")
    ap.add_argument("--pose", default="stand", choices=list(MII.POSES.keys()))
    ap.add_argument("--racket", action="store_true", help="coloca a raquete (e a bola) na mao direita")
    ap.add_argument("--view", choices=["front", "side", "back", "three"], default="three")
    ap.add_argument("--quality", choices=["draft", "final"], default="draft")
    ap.add_argument("--out", required=True, help="PNG de saida")
    ap.add_argument("--blend", help="tambem salva um .blend (imagens empacotadas)")
    a = ap.parse_args()

    over = {}
    if a.config:
        with open(a.config, encoding="utf-8") as f:
            over = json.load(f)
    for item in a.set:
        k, _, v = item.partition("=")
        set_path(over, k, parse_value(v))
    over.setdefault("gender", a.gender)
    base = MII.MALE if over["gender"] == "male" else MII.FEMALE
    cfg = MII.merge(base, over)

    S.reset()
    yaw = {"front": 0, "side": -90, "back": 180, "three": -25}[a.view]
    objs = MII.build_character(cfg, pose=a.pose, yaw=yaw, with_racket=a.racket, ball=a.racket and a.pose != "stand")
    objs.append(S.ground((0, -0.02, 0)))
    f = 1.0 if a.quality == "final" else 0.5
    S.add_outlines(objs, px=3.2 * f + 0.6)
    S.world()
    S.studio((0, 0, 0.95), scale=1.6)
    S.camera((0, -7.5, 1.9), (0, 0, 0.93), ortho_scale=2.5)
    S.setup_render(int(1200 * f), int(1500 * f), samples=128 if a.quality == "final" else 24)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    S.render(a.out)
    if a.blend:
        for img in bpy.data.images:
            if img.filepath:
                try:
                    img.pack()
                except RuntimeError:
                    pass
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(a.blend))
        print("blend ->", a.blend)
    print("OK", a.out)


if __name__ == "__main__":
    main()

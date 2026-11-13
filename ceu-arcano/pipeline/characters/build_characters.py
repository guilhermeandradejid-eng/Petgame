"""Gera os atlas e os dados de luta das personagens para o Godot.

    python3 pipeline/characters/build_characters.py [lumia|rubi ...]
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, ".."))

from PIL import Image  # noqa: E402

from preview import build  # noqa: E402
from pixelrig.bake import export_character, render_preview  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, "..", "..", "game", "assets", "characters"))


def main(ids):
    for cid in ids:
        t0 = time.time()
        mod, am, ch = build(cid)
        out = os.path.join(OUT, cid)
        print(f"[{cid}] {len(ch.anims)} animações -> {out}")
        export_character(ch, out, am.REST)
        for label, mats in (("a", ch.mats_a), ("b", ch.mats_b)):
            img = render_preview(ch, "portrait", am.REST, mats=mats, scale=1)
            img.crop(img.getbbox()).save(os.path.join(out, f"portrait_{label}.png"))
        print(f"[{cid}] ok em {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main(sys.argv[1:] or ["lumia", "rubi"])

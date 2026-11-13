"""Pré-visualização rápida: python3 preview.py <personagem> <anim|pose> [t] [saida.png]"""
import os, sys, importlib
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from PIL import Image
from pixelrig.bake import Character, Anim, render_preview, bake_anim, render_frame


def build(cid):
    mod = importlib.import_module(cid)
    anims_mod = importlib.import_module("anims_" + cid) if os.path.exists(os.path.join(os.path.dirname(__file__), f"anims_{cid}.py")) else None
    anims = anims_mod.anims() if anims_mod else []
    ch = Character(cid, mod.build_skeleton(), mod.parts(), mod.CHAINS, mod.materials(False), mod.materials(True),
                   anims, mod.CHAIN_STYLE, mod.POINTS, mod.HURT)
    return mod, anims_mod, ch


def sheet(ch, anim, rest, mats, scale=3, bg=(40, 36, 70, 255)):
    frames = bake_anim(ch, anim, rest)
    imgs = []
    for fr in frames:
        cv, _ = render_frame(ch, fr["pose"], fr["chains"], fr["t"], anim, mats, fr["smears"])
        imgs.append(Image.fromarray(cv.rgba(mats), "RGBA"))
    import numpy as np
    boxes = [im.getbbox() for im in imgs if im.getbbox()]
    bb = (min(b[0] for b in boxes) - 2, min(b[1] for b in boxes) - 2, max(b[2] for b in boxes) + 2, max(b[3] for b in boxes) + 2)
    imgs = [im.crop(bb) for im in imgs]
    W, H = imgs[0].size
    cols = min(len(imgs), 8)
    rows = (len(imgs) + cols - 1) // cols
    out = Image.new("RGBA", (W * cols, H * rows), bg)
    for i, im in enumerate(imgs):
        out.alpha_composite(im, ((i % cols) * W, (i // cols) * H))
    return out.resize((out.width * scale, out.height * scale), Image.NEAREST)


if __name__ == "__main__":
    cid = sys.argv[1]
    what = sys.argv[2] if len(sys.argv) > 2 else "rest"
    out = sys.argv[3] if len(sys.argv) > 3 else f"/tmp/preview_{cid}_{what}.png"
    alt = "--alt" in sys.argv
    mod, am, ch = build(cid)
    mats = ch.mats_b if alt else ch.mats_a
    rest = am.REST if am else {}
    if what == "rest" or (am and what in getattr(am, "POSES", {})):
        pose = rest if what == "rest" else am.POSES[what]
        a = Anim("x", 1, [(0, pose)])
        ch.anims = [a]
        img = sheet(ch, a, rest, mats, scale=4)
    else:
        a = next(x for x in ch.anims if x.name == what)
        img = sheet(ch, a, rest, mats, scale=3)
    img.save(out)
    print(out, img.size)

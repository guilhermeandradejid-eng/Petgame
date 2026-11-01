"""QA gate for generated characters.  usage: python3 qa.py ren [capmook ...]  (exit 1 on any failure)

Checks the frozen contract, animation quality floors, pixel hygiene and anchors.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MIN_FLUIDITY = 0.6          # sub-frames per logical frame (milestone-1 floor)
MIN_ATTACK_FRAMES = 5
MIN_HELD_TICKS = 6
ANCHORS = ("hand", "hand_dir", "off_hand", "head", "chest", "weapon_tip")


def check(char):
    errs = []
    cdir = os.path.join(ROOT, "art", "chars", char)
    contract = json.load(open(os.path.join(ROOT, "art", "contracts", f"{char}.contract.json")))
    sheet = json.load(open(os.path.join(cdir, "sheet.json")))
    img = np.array(Image.open(os.path.join(cdir, "sheet.png")).convert("RGBA"))
    nimg = Image.open(os.path.join(cdir, "normal.png"))
    cell = contract["cell"]
    if nimg.size != (img.shape[1], img.shape[0]):
        errs.append("normal sheet size != color sheet size")
    if set(sheet["anims"]) != set(contract["anims"]):
        errs.append(f"animation set differs from contract: {set(sheet['anims']) ^ set(contract['anims'])}")
    logical = subs = 0
    heights = []
    for name, ca in contract["anims"].items():
        sa = sheet["anims"].get(name)
        if not sa:
            continue
        if sa["ticks"] != ca["ticks"]:
            errs.append(f"{name}: tick budget changed")
        mains = [f for f in sa["frames"] if not f["sub"]]
        if [f["logical"] for f in mains] != list(range(len(ca["ticks"]))):
            errs.append(f"{name}: logical frame count changed")
        logical += len(mains)
        subs += len(sa["frames"]) - len(mains)
        for c in ca.get("contact", []):
            if len(ca["ticks"]) < MIN_ATTACK_FRAMES:
                errs.append(f"{name}: attack has {len(ca['ticks'])} frames (<{MIN_ATTACK_FRAMES})")
            if ca["ticks"][c] < MIN_HELD_TICKS:
                errs.append(f"{name}: contact frame held {ca['ticks'][c]} ticks (<{MIN_HELD_TICKS})")
        for f in sa["frames"]:
            x, y = (f["i"] % sheet["cols"]) * cell, (f["i"] // sheet["cols"]) * cell
            tile = img[y:y + cell, x:x + cell]
            a = tile[..., 3]
            if not set(np.unique(a)) <= {0, 255}:
                errs.append(f"{name}[{f['i']}]: semi-transparent pixels")
            if a[0, :].any() or a[-1, :].any() or a[:, 0].any() or a[:, -1].any():
                errs.append(f"{name}[{f['i']}]: sprite touches cell border")
            for k in ANCHORS:
                if k not in f["anchors"]:
                    errs.append(f"{name}[{f['i']}]: missing anchor {k}")
            if name == "idle" and not f["sub"] and f["logical"] == 0:
                ys = np.nonzero(a.any(1))[0]
                heights.append(int(ys.max() - ys.min() + 1))
    flu = subs / max(logical, 1)
    if flu < MIN_FLUIDITY:
        errs.append(f"fluidity {flu:.2f} < {MIN_FLUIDITY}")
    tgt = contract["target_height_px"]
    if heights and abs(heights[0] - tgt) > tgt * 0.2:
        errs.append(f"idle height {heights[0]}px vs target {tgt}px (>20%)")
    print(f"{char}: anims={len(contract['anims'])} logical={logical} fluidity={flu:.2f} "
          f"height={heights[0] if heights else '?'}px -> {'FAIL' if errs else 'PASS'}")
    for e in errs[:20]:
        print("   -", e)
    return not errs


if __name__ == "__main__":
    ok = all([check(c) for c in (sys.argv[1:] or ["ren", "capmook"])])
    sys.exit(0 if ok else 1)

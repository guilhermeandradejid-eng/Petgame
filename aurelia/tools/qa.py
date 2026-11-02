"""QA gate for generated characters.  usage: python3 qa.py ren [capmook ...]  (exit 1 on any failure)

Checks the frozen contract, animation quality floors, pixel hygiene, anchors and the size budget.
sheet.json v3: every anim lists display frames {i, logical, at, sub, anchors}; the frame shown at tick t is the
last entry of its logical frame with at <= (t - logical start).
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MIN_FRAMES_PER_TICK = 0.45     # display frames per game tick (smoothness floor)
MIN_ATTACK_FRAMES = 5
MIN_HELD_TICKS = 6
ANCHORS = ("hand", "hand_dir", "off_hand", "head", "chest", "weapon_tip")
BUDGET_KB = {"ren": 1024}      # per png; everything else 600 (ren: both pngs together must stay <= 2 MB)
DEFAULT_BUDGET_KB = 600
MAX_TEXTURE = 4096
MAX_SEG_ERR = 0.05            # arm / leg segment length constancy (fraction)
MAX_GRIP_ERR = 0.6            # px: far hand distance from the shaft of a two-handed weapon


def check(char):
    errs = []
    cdir = os.path.join(ROOT, "art", "chars", char)
    contract = json.load(open(os.path.join(ROOT, "art", "contracts", f"{char}.contract.json")))
    sheet = json.load(open(os.path.join(cdir, "sheet.json")))
    img = np.array(Image.open(os.path.join(cdir, "sheet.png")).convert("RGBA"))
    nimg = Image.open(os.path.join(cdir, "normal.png"))
    cell = contract["cell"]
    if sheet.get("cell") != cell:
        errs.append(f"sheet cell {sheet.get('cell')} != contract cell {cell}")
    if "ground" in contract and sheet.get("ground") != contract["ground"]:
        errs.append(f"sheet ground {sheet.get('ground')} != contract ground {contract['ground']}")
    if max(img.shape[0], img.shape[1]) > MAX_TEXTURE:
        errs.append(f"texture {img.shape[1]}x{img.shape[0]} exceeds {MAX_TEXTURE}")
    geo = sheet.get("geometry")
    if geo:
        if geo["seg"] > MAX_SEG_ERR:
            errs.append(f"segment length varies by {geo['seg'] * 100:.1f}% (> {MAX_SEG_ERR * 100:.0f}%)")
        if geo["grip"] > MAX_GRIP_ERR:
            errs.append(f"two-handed grip off the shaft by {geo['grip']:.2f} px (> {MAX_GRIP_ERR})")
    if nimg.size != (img.shape[1], img.shape[0]):
        errs.append("normal sheet size != color sheet size")
    for fn in ("sheet.png", "normal.png"):
        kb = os.path.getsize(os.path.join(cdir, fn)) / 1024
        cap = BUDGET_KB.get(char, DEFAULT_BUDGET_KB)
        if kb > cap:
            errs.append(f"{fn} is {kb:.0f} KB (> {cap} KB budget)")
    tot = sum(os.path.getsize(os.path.join(cdir, fn)) for fn in ("sheet.png", "normal.png")) / 1024
    if char == "ren" and tot > 2048:
        errs.append(f"sheet.png + normal.png = {tot:.0f} KB (> 2048 KB)")
    if set(sheet["anims"]) != set(contract["anims"]):
        errs.append(f"animation set differs from contract: {set(sheet['anims']) ^ set(contract['anims'])}")
    total_ticks = total_frames = 0
    heights = []
    checked_cells = set()
    for name, ca in contract["anims"].items():
        sa = sheet["anims"].get(name)
        if not sa:
            continue
        if sa["ticks"] != ca["ticks"]:
            errs.append(f"{name}: tick budget changed")
        n = len(ca["ticks"])
        by_l = {}
        for f in sa["frames"]:
            by_l.setdefault(f["logical"], []).append(f)
        if sorted(by_l) != list(range(n)):
            errs.append(f"{name}: logical frame set changed")
        order = [(f["logical"], f["at"]) for f in sa["frames"]]
        if order != sorted(order):
            errs.append(f"{name}: frames not sorted by (logical, at)")
        frozen = set(ca.get("hold", []))
        contacts = ca.get("contact", [])
        if contacts:
            frozen.add(contacts[-1])
        for l, fl in by_l.items():
            if fl[0]["at"] != 0:
                errs.append(f"{name}: logical frame {l} has no key frame at tick offset 0")
            if any(f["at"] >= ca["ticks"][l] for f in fl):
                errs.append(f"{name}: logical frame {l} has a display frame beyond its tick budget")
            if l in frozen:       # held/contact frames stay on their exact key: the blade/hand never moves
                a0 = fl[0]["anchors"]
                if any(f["anchors"] != a0 for f in fl[1:]):
                    errs.append(f"{name}: held frame {l} moves (anchors differ between its display frames)")
        total_ticks += sum(ca["ticks"])
        total_frames += len(sa["frames"])
        if contacts:
            if n < MIN_ATTACK_FRAMES:
                errs.append(f"{name}: attack has {n} frames (<{MIN_ATTACK_FRAMES})")
            # single hit: the contact frame is held; multi-hit: the LAST contact frame is held
            if ca["ticks"][contacts[-1]] < MIN_HELD_TICKS:
                errs.append(f"{name}: last contact frame held {ca['ticks'][contacts[-1]]} ticks (<{MIN_HELD_TICKS})")
        for f in sa["frames"]:
            for k in ANCHORS:
                if k not in f["anchors"]:
                    errs.append(f"{name}[{f['i']}]: missing anchor {k}")
            if f["i"] in checked_cells:
                continue
            checked_cells.add(f["i"])
            x, y = (f["i"] % sheet["cols"]) * cell, (f["i"] // sheet["cols"]) * cell
            tile = img[y:y + cell, x:x + cell]
            a = tile[..., 3]
            if not set(np.unique(a)) <= {0, 255}:
                errs.append(f"{name}[{f['i']}]: semi-transparent pixels")
            if a[0, :].any() or a[-1, :].any() or a[:, 0].any() or a[:, -1].any():
                errs.append(f"{name}[{f['i']}]: sprite touches cell border")
            if (name == "idle" or name == "sword.idle") and f["logical"] == 0 and f["at"] == 0:
                ys = np.nonzero(a.any(1))[0]
                heights.append(int(ys.max() - ys.min() + 1))
    fpt = total_frames / max(total_ticks, 1)
    if fpt < MIN_FRAMES_PER_TICK:
        errs.append(f"display frames per tick {fpt:.2f} < {MIN_FRAMES_PER_TICK}")
    tgt = contract["target_height_px"]
    if heights and abs(heights[0] - tgt) > tgt * 0.2:
        errs.append(f"idle height {heights[0]}px vs target {tgt}px (>20%)")
    print(f"{char}: anims={len(contract['anims'])} display_frames={total_frames} ticks={total_ticks} per_tick={fpt:.2f} "
          f"unique_cells={sheet['frames']} height={heights[0] if heights else '?'}px -> {'FAIL' if errs else 'PASS'}")
    for e in errs[:20]:
        print("   -", e)
    return not errs


if __name__ == "__main__":
    ok = all([check(c) for c in (sys.argv[1:] or ["ren", "capmook", "hopkin"])])
    sys.exit(0 if ok else 1)

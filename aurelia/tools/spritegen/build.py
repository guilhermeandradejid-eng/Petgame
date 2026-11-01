"""Build sprite sheets for a character from its frozen contract.

usage: python3 build.py ren [capmook ...]      (default: all)
Writes art/chars/<id>/{sheet.png, normal.png, sheet.json, contract.json, contact.png}
"""
import importlib
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from engine import lerp_pose, normal_map  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
COLS = 16
MIN_SUB_TICKS = 3


def display_plan(contract_anim):
    """Which display frames exist: list of (logical, t) with t=0 main, 0.5 = sub after it."""
    ticks = contract_anim["ticks"]
    hold = set(contract_anim.get("hold", []))
    contact = set(contract_anim.get("contact", []))
    loop = contract_anim.get("loop", False)
    n = len(ticks)
    plan = []
    for i in range(n):
        plan.append((i, 0.0))
        has_next = loop or i < n - 1
        if has_next and ticks[i] >= MIN_SUB_TICKS and i not in hold and i not in contact:
            plan.append((i, 0.5))
    return plan


def build(char):
    mod = importlib.import_module(f"chars.{char}")
    contract = json.load(open(os.path.join(ROOT, "art", "contracts", f"{char}.contract.json")))
    cell = contract["cell"]
    frames, nframes = [], []
    sheet_anims = {}
    cv_last = None
    for name, ca in contract["anims"].items():
        n = len(ca["ticks"])
        keyed = mod.poses(name, n)
        assert len(keyed) == n, f"{char}.{name}: {len(keyed)} poses for {n} logical frames"
        plan = display_plan(ca)
        dposes = []
        for (i, t) in plan:
            if t == 0:
                dposes.append(keyed[i])
            else:
                dposes.append(lerp_pose(keyed[i], keyed[(i + 1) % n], 0.5))
        sks = [mod.skeleton(p) for p in dposes]
        chains = mod.simulate(sks, dposes, ca.get("loop", False))
        entries = []
        for k, ((i, t), p, sk) in enumerate(zip(plan, dposes, sks)):
            cv, buf = mod.draw(sk, chains[k], p)
            cv_last = cv
            rgba = buf["rgba"]
            nrm = normal_map(buf)
            idx = len(frames)
            frames.append(rgba)
            nframes.append(nrm)
            anc = mod.anchors(sk)
            entries.append({"i": idx, "logical": i, "sub": t > 0,
                            "anchors": {a: [round(float(v), 2) for v in val] for a, val in anc.items()}})
        sheet_anims[name] = {"loop": ca.get("loop", False), "ticks": ca["ticks"],
                             "contact": ca.get("contact", []), "hold": ca.get("hold", []),
                             "frames": entries}
    rows = (len(frames) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * cell, rows * cell), (0, 0, 0, 0))
    nsheet = Image.new("RGBA", (COLS * cell, rows * cell), (128, 128, 255, 0))
    for i, (f, nf) in enumerate(zip(frames, nframes)):
        sheet.paste(Image.fromarray(f, "RGBA"), ((i % COLS) * cell, (i // COLS) * cell))
        nsheet.paste(Image.fromarray(nf, "RGBA"), ((i % COLS) * cell, (i // COLS) * cell))
    out = os.path.join(ROOT, "art", "chars", char)
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, "sheet.png"))
    nsheet.save(os.path.join(out, "normal.png"))
    json.dump({"id": char, "cell": cell, "cols": COLS, "frames": len(frames), "anims": sheet_anims},
              open(os.path.join(out, "sheet.json"), "w"), indent=1)
    json.dump(contract, open(os.path.join(out, "contract.json"), "w"), indent=1)
    contact_sheet(char, out, sheet_anims, frames, cell)
    print(f"{char}: {len(frames)} display frames, sheet {sheet.size}")


def contact_sheet(char, out, anims, frames, cell, scale=3):
    rows = []
    for name, a in anims.items():
        rows.append((name, [e["i"] for e in a["frames"]], [e["sub"] for e in a["frames"]]))
    maxn = max(len(r[1]) for r in rows)
    W, H = maxn * cell * scale + 90, len(rows) * (cell * scale + 6)
    img = Image.new("RGBA", (W, H), (70, 78, 70, 255))
    d = ImageDraw.Draw(img)
    for r, (name, idxs, subs) in enumerate(rows):
        y = r * (cell * scale + 6)
        d.text((4, y + 4), name, fill=(255, 255, 255, 255))
        for c, (fi, sub) in enumerate(zip(idxs, subs)):
            f = Image.fromarray(frames[fi], "RGBA").resize((cell * scale, cell * scale), Image.NEAREST)
            x = 90 + c * cell * scale
            d.rectangle([x, y, x + cell * scale - 1, y + cell * scale - 1], fill=(92, 104, 92, 255) if sub else (110, 124, 110, 255))
            d.line([x, y + 59 * scale, x + cell * scale, y + 59 * scale], fill=(60, 66, 60, 255))
            img.alpha_composite(f, (x, y))
    img.convert("RGB").save(os.path.join(out, "contact.png"))


if __name__ == "__main__":
    chars = sys.argv[1:] or ["ren", "capmook"]
    for c in chars:
        build(c)

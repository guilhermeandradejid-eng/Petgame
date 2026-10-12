"""Quality gate. Fails a character that is not done, instead of trusting "looks good to me".

    python3 qa_hero.py mage
Thresholds are the MVP floor, not the ceiling: passing every row and still looking bad is a fail.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GEN = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "gen"))

MIN = dict(fluidity=0.85, attack_frames=5, held_ticks=6)


def check(name):
    contract = json.load(open(os.path.join(HERE, "contracts", name + ".json")))
    meta = json.load(open(os.path.join(GEN, name, name + ".json")))
    rows, ok = [], True

    def row(metric, value, need, passed):
        nonlocal ok
        ok &= passed
        rows.append((metric, str(value), str(need), "ok" if passed else "FAIL"))

    names_c = list(contract["animations"])
    names_m = list(meta["animations"])
    row("contract animations", len(names_m), len(names_c), names_c == names_m)
    for an, ca in contract["animations"].items():
        ma = meta["animations"].get(an)
        if ma is None:
            continue
        same = [f["ticks"] for f in ca["frames"]] == [f["ticks"] for f in ma["logical"]]
        row(f"{an}: logical frames/ticks frozen", len(ma["logical"]), len(ca["frames"]), same)
        sheet = np.asarray(Image.open(os.path.join(GEN, name, ma["sheet"])))
        fw, fh = meta["frame_size"]
        empty = 0
        for k in range(8):
            for i in range(len(ma["frames"])):
                if sheet[k * fh:(k + 1) * fh, i * fw:(i + 1) * fw, 3].max() == 0:
                    empty += 1
        row(f"{an}: empty frames", empty, 0, empty == 0)
        anch = all(len(ma["anchors"][k]) == len(ma["frames"]) for k in range(8))
        row(f"{an}: anchors on every frame", anch, True, anch)
        if ca.get("attack"):
            n = len(ca["frames"])
            row(f"{an}: frames per attack", n, MIN["attack_frames"], n >= MIN["attack_frames"])
            held = max(f["ticks"] for f in ma["frames"])
            row(f"{an}: one frame held (ticks)", held, MIN["held_ticks"], held >= MIN["held_ticks"])
            ev = any(f.get("event") for f in ma["logical"])
            row(f"{an}: gameplay event on a key frame", ev, True, ev)
    logical = sum(len(a["logical"]) for a in meta["animations"].values())
    sprite = sum(len(a["frames"]) for a in meta["animations"].values())
    flu = round((sprite - logical) / logical, 2)
    row("fluidity (sub-frames per logical frame)", flu, MIN["fluidity"], flu >= MIN["fluidity"])

    # silhouette height, idle facing the camera
    idle = np.asarray(Image.open(os.path.join(GEN, name, "idle.png")))
    fw, fh = meta["frame_size"]
    ys = np.where(idle[:fh, :fw, 3].max(axis=1) > 0)[0]
    row("idle height (px)", int(ys.max() - ys.min() + 1), "-", True)

    w = max(len(r[0]) for r in rows)
    print(f"== {name}")
    for r in rows:
        print(f"  {r[0]:<{w}}  {r[1]:>6}  min {r[2]:>5}  {r[3]}")
    print(f"  => {'PASS' if ok else 'FAIL'}")
    return ok


if __name__ == "__main__":
    names = sys.argv[1:] or ["mage", "slime"]
    results = [check(n) for n in names]
    sys.exit(0 if all(results) else 1)

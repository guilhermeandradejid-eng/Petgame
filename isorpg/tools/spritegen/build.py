"""Render characters into sprite sheets for the game.

    python3 build.py            # every character
    python3 build.py mage       # just one

Per character it writes, under isorpg/assets/gen/<name>/:
  <anim>.png      colour sheet, one row per direction, one column per sprite frame
  <anim>_n.png    generated normal map with the same layout
  <name>.json     frame size, origin, timing (logical frames + sub-frames) and anchors
and a contact sheet under isorpg/docs/ for review by eye.
"""
import importlib
import json
import math
import os
import sys
from concurrent.futures import ProcessPoolExecutor
from concurrent.futures.process import BrokenProcessPool

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from raster import Canvas, compose  # noqa: E402
from rig import rot_z, v3  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "gen")
DOCS = os.path.join(ROOT, "docs")

# 0=S (toward the camera), then clockwise on screen: SE, E, NE, N, NW, W, SW.
DIRS = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]


def facing(k):
    return rot_z(-180.0 + 45.0 * k)


def load_contract(name):
    with open(os.path.join(HERE, "contracts", name + ".json")) as f:
        return json.load(f)


def frame_plan(contract_anim, subs):
    """Split each logical frame into 1 + sub slices. Returns list of dicts."""
    frames = []
    t = 0
    for i, (lf, sub) in enumerate(zip(contract_anim["frames"], subs)):
        n = sub + 1
        base, extra = divmod(lf["ticks"], n)
        start = t
        for j in range(n):
            dur = base + (1 if j < extra else 0)
            frames.append(dict(logical=i, sub=j, t=float(start), ticks=dur))
            start += dur
        t += lf["ticks"]
    return frames, t


def simulate(mod, anim, length, loop, times):
    """Run the spring chains through the animation and record them at the given tick times."""
    chains = mod.make_chains()
    speed = anim["root_speed"]
    sample = anim["sample"]
    want = sorted(set(int(round(t)) for t in times))
    rec = {}

    def offset(t):
        return v3(0, speed * t, 0)

    def wind(t):
        ph = 2 * math.pi * (t / length)
        return v3(0.015 * math.sin(ph), -0.02 + 0.015 * math.sin(ph * 2 + 1), 0)

    def step(t, tick_for_pose):
        s = mod.solve(sample(tick_for_pose, length))
        out = {}
        for key, (ch, anchor, rotkey) in chains.items():
            pts = ch.step(s[anchor] + offset(t), s[rotkey], wind(t))
            out[key] = pts - offset(t)
        return out

    if loop:
        total = int(length) * 4
        for t in range(total):
            st = step(t, t % length)
            if t >= total - length:
                rec[t - (total - length)] = st
    else:
        pre = 120
        for t in range(pre):
            step(t - pre, 0)
        for t in range(int(length) + 1):
            rec[t] = step(t, t)
    return {t: rec[min(t, max(rec))] for t in want}


def render_dir(args):
    name, k, jobs, size, origin = args
    mod = importlib.import_module(name)
    R = facing(k)
    results = []
    for pose, chains in jobs:
        cv = Canvas(size[0], size[1], origin[0], origin[1])
        s = mod.solve(pose)
        mod.draw(cv, s, chains, R)
        out = compose(cv)
        if hasattr(mod, "paint_face"):
            mod.paint_face(out, cv, s, R)
        anchors = {}
        for a in mod.ANCHORS:
            x, y, d = cv.to_px(R @ s[a])
            anchors[a] = [round(x - origin[0], 2), round(y - origin[1], 2), round(float(d), 2)]
        results.append((out["rgba"], out["normal"], anchors))
    return k, results


def build(name, pool):
    mod = importlib.import_module(name)
    contract = load_contract(name)
    anims = mod.animations(contract)
    size = getattr(mod, "FRAME", (128, 128))
    origin = getattr(mod, "ORIGIN", (64, 116))
    outdir = os.path.join(OUT, name)
    os.makedirs(outdir, exist_ok=True)
    meta = dict(character=name, tick_rate=contract["tick_rate"], frame_size=list(size), origin=list(origin),
                directions=DIRS, animations={})
    if hasattr(mod, "META"):
        meta.update(mod.META)
    contact_rows = []
    for an, ca in contract["animations"].items():
        if an not in anims:
            raise SystemExit(f"{name}: contract animation '{an}' is not rendered")
        subs = mod.SUBFRAMES[an]
        if len(subs) != len(ca["frames"]):
            raise SystemExit(f"{name}/{an}: renderer has {len(subs)} logical frames, contract says {len(ca['frames'])}")
        plan, length = frame_plan(ca, subs)
        anim = anims[an]
        chains = simulate(mod, anim, length, ca["loop"], [f["t"] for f in plan])
        jobs = []
        for f in plan:
            pose = anim["sample"](f["t"], length)
            jobs.append((pose, chains[int(round(f["t"]))]))
        tasks = [(name, k, jobs, size, origin) for k in range(8)]
        try:
            res = dict(pool.map(render_dir, tasks)) if pool else None
        except BrokenProcessPool as e:
            print("  worker pool broke (%s), rendering sequentially" % e)
            res = None
        if res is None:
            res = dict(render_dir(t) for t in tasks)
        nf = len(plan)
        sheet = np.zeros((size[1] * 8, size[0] * nf, 4), dtype=np.uint8)
        nsheet = np.zeros((size[1] * 8, size[0] * nf, 4), dtype=np.uint8)
        anchors = []
        for k in range(8):
            row = []
            for i, (rgba, nrm, anc) in enumerate(res[k]):
                ys, xs = k * size[1], i * size[0]
                sheet[ys:ys + size[1], xs:xs + size[0]] = rgba
                nsheet[ys:ys + size[1], xs:xs + size[0], :3] = nrm
                nsheet[ys:ys + size[1], xs:xs + size[0], 3] = rgba[..., 3]
                row.append(anc)
            anchors.append(row)
        Image.fromarray(sheet).save(os.path.join(outdir, an + ".png"))
        Image.fromarray(nsheet).save(os.path.join(outdir, an + "_n.png"))
        meta["animations"][an] = dict(
            loop=ca["loop"], attack=ca.get("attack", False), length=length,
            logical=[dict(ticks=f["ticks"], event=f.get("event")) for f in ca["frames"]],
            frames=[dict(logical=f["logical"], ticks=f["ticks"]) for f in plan],
            anchors=anchors, sheet=an + ".png", normal=an + "_n.png",
        )
        if "root_speed" in anim:
            meta["animations"][an]["root_speed"] = anim["root_speed"] * contract["tick_rate"]
        contact_rows.append((an, sheet, nf))
        print(f"  {name}/{an}: {len(ca['frames'])} logical, {nf} sprite frames")
    with open(os.path.join(outdir, name + ".json"), "w") as f:
        json.dump(meta, f, indent=1)
    contact_sheet(name, contact_rows, size)


def contact_sheet(name, rows, size, scale=2):
    """Every animation, directions S, E, N, W side by side, on a mid grey checker."""
    os.makedirs(DOCS, exist_ok=True)
    picks = [0, 2, 4, 6, 1]
    w = max(nf for _, _, nf in rows) * size[0]
    h = len(rows) * len(picks) * size[1]
    bg = np.zeros((h, w, 3), dtype=np.uint8)
    yy, xx = np.mgrid[0:h, 0:w]
    bg[...] = np.where(((xx // 16 + yy // 16) % 2 == 0)[..., None], (92, 104, 88), (84, 96, 80))
    img = Image.fromarray(bg)
    y = 0
    for an, sheet, nf in rows:
        for k in picks:
            strip = sheet[k * size[1]:(k + 1) * size[1]]
            tile = Image.fromarray(strip)
            img.paste(tile, (0, y), tile)
            y += size[1]
    img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(os.path.join(DOCS, f"contact_{name}.png"))


if __name__ == "__main__":
    names = sys.argv[1:] or [n for n in ("mage", "slime") if os.path.exists(os.path.join(HERE, "contracts", n + ".json"))]
    for n in names:
        print("building", n, flush=True)
        with ProcessPoolExecutor(max_workers=min(8, os.cpu_count() or 4)) as pool:
            build(n, pool)
    import tiles
    tiles.main()

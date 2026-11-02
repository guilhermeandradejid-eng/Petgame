"""Build dense sprite sheets for a character from its frozen contract.

usage: python3 build.py ren [capmook hopkin ...]      (default: all)
Writes art/chars/<id>/{sheet.png, normal.png, sheet.json, contract.json, contact.png}

How a frame is made (v3, "dense"):
  * the character module authors one KEY pose per logical frame (contract frame);
  * every game tick gets a pose sampled from a cubic Hermite spline through the keys
    (zero tangent at held/contact/"stop" keys, per-key easing tags: in / out / snap / lin),
    angles unwrapped along the shortest arc;
  * secondary motion (scarf, ponytail, ears, cap...) is simulated over the per-tick timeline;
  * a display frame is emitted at the key tick of every logical frame and then every 2 ticks
    (every tick for 3-tick frames); held/contact frames stay on the exact key (only the springs
    keep moving); pixel-identical frames are deduplicated into one sheet cell;
  * fast weapon sweeps get a dithered smear drawn from the last two ticks of blade motion.
"""
import hashlib
import importlib
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import engine  # noqa: E402
from engine import normal_map  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
COLS = 16
MAX_TEX = 4096
META = {"ease", "stop"}
ANGLE_KEYS = {"sw", "spin"}
STEP_AT_END = {"weapon", "carry", "grip", "far_front", "autohip", "plant", "mouth"}     # discrete values switch exactly on the next key
HOLD_PULSE = 3                                                # springs-only frames inside held frames


# ----------------------------------------------------------------- interpolation


def ease_u(u, tag):
    if tag == "snap":                       # fast in, ~4% overshoot, settles on the key
        c1 = 1.2
        c3 = c1 + 1.0
        return 1.0 + c3 * (u - 1.0) ** 3 + c1 * (u - 1.0) ** 2
    if tag == "in":
        return u * u * (1.0 + 0.6 * (1.0 - u))
    if tag == "out":
        return 1.0 - (1.0 - u) ** 2
    if tag == "inout":
        return u * u * (3 - 2 * u)
    return u


def _num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _unwrap(seq, loop):
    """Make a list of angles continuous along the shortest arc (None entries break the chain)."""
    out = list(seq)
    prev = None
    for i, v in enumerate(out):
        if v is None:
            prev = None
            continue
        if prev is not None:
            d = (v - prev + 180.0) % 360.0 - 180.0
            v = prev + d
            out[i] = v
        prev = v
    return out


class Timeline:
    """Spline through the keys of one animation."""

    def __init__(self, keys, ca):
        self.keys = keys
        self.n = len(keys)
        self.loop = ca.get("loop", False)
        contact = list(ca.get("contact", []))
        self.frozen = set(ca.get("hold", []))
        if contact:
            self.frozen.add(contact[-1])
        self.stop = {i for i, k in enumerate(keys) if k.get("stop")}
        names = [k for k in keys[0] if k not in META]
        self.cols = {}
        for name in names:
            col = [k[name] for k in keys]
            if name in ANGLE_KEYS:
                col = _unwrap(col, self.loop)
            self.cols[name] = col

    def _idx(self, i):
        if self.loop:
            return i % self.n
        return max(0, min(self.n - 1, i))

    def pose(self, l, u):
        """Pose at logical frame l, fraction u (0 = the key itself)."""
        k0 = self.keys[l]
        if u <= 0.0 or l in self.frozen or (not self.loop and l >= self.n - 1):
            return {k: v for k, v in k0.items() if k not in META}
        j = self._idx(l + 1)
        tag = k0.get("ease")
        ue = ease_u(u, tag)
        out = {}
        for name, col in self.cols.items():
            a, b = col[l], col[j]
            out[name] = self._blend_value(name, col, l, j, a, b, ue, u)
        return out

    def _blend_value(self, name, col, l, j, a, b, ue, u):
        if _num(a) and _num(b):
            return self._herm_scalar(col, l, j, ue)
        if isinstance(a, (tuple, list)) and isinstance(b, (tuple, list)) and all(_num(x) for x in a):
            comps = []
            for c in range(len(a)):
                sub = [v[c] if isinstance(v, (tuple, list)) else a[c] for v in col]
                comps.append(self._herm_scalar(sub, l, j, ue))
            return tuple(comps)
        # discrete values
        if name in STEP_AT_END:
            return a
        return a if u < 0.5 else b

    def _herm_scalar(self, col, i, j, u):
        p1, p2 = col[i], col[j]
        m1 = self._tan(col, i)
        m2 = self._tan(col, j)
        u2, u3 = u * u, u * u * u
        return (2 * u3 - 3 * u2 + 1) * p1 + (u3 - 2 * u2 + u) * m1 + (-2 * u3 + 3 * u2) * p2 + (u3 - u2) * m2

    def _tan(self, col, i):
        if i in self.frozen or i in self.stop:
            return 0.0
        if not self.loop and (i == self.n - 1 or i == 0):
            return 0.0
        a, b = col[self._idx(i - 1)], col[self._idx(i + 1)]
        if not (_num(a) and _num(b)):
            return 0.0
        return 0.42 * (b - a)


# ------------------------------------------------------------------- planning


def emit_plan(ca, hold_pulse=HOLD_PULSE):
    """List of (logical, at) display frames to render for one animation."""
    ticks = ca["ticks"]
    frozen = set(ca.get("hold", []))
    contact = list(ca.get("contact", []))
    if contact:
        frozen.add(contact[-1])
    last_contact = max(contact) if contact else -1
    short_anim = sum(ticks) <= 20
    plan = []
    for l, T in enumerate(ticks):
        if l in frozen:
            at = 0
            while at < T:
                plan.append((l, at))
                at += hold_pulse if (hold_pulse and T >= 6) else T
            continue
        step = 1 if (T <= 3 or short_anim or l <= last_contact) else 2     # strikes get every tick
        for at in range(0, T, step):
            plan.append((l, at))
    return plan


def tick_table(ca):
    starts, acc = [], 0
    for T in ca["ticks"]:
        starts.append(acc)
        acc += T
    return starts, acc


# ---------------------------------------------------------------------- build


def quantize_normals(nrm):
    out = nrm.copy()
    rgb = out[..., :3].astype(np.float32) / 255.0
    rgb = np.round(rgb * 15.0) / 15.0
    out[..., :3] = np.clip(rgb * 255.0 + 0.5, 0, 255).astype(np.uint8)
    return out


def save_palette_png(arr, path, max_colors=256):
    """Save an RGBA array (alpha 0/255) as an indexed PNG (exact if it has <=255 colours)."""
    h, w = arr.shape[:2]
    solid = arr[..., 3] > 0
    packed = (arr[..., 0].astype(np.uint32) << 16) | (arr[..., 1].astype(np.uint32) << 8) | arr[..., 2].astype(np.uint32)
    cols = np.unique(packed[solid])
    idx = np.zeros((h, w), np.uint8)
    if len(cols) <= max_colors - 1:
        lut = {int(c): i + 1 for i, c in enumerate(cols)}
        pal = [(0, 0, 0)] + [((int(c) >> 16) & 255, (int(c) >> 8) & 255, int(c) & 255) for c in cols]
        flat = packed[solid]
        mapped = np.searchsorted(cols, flat) + 1
        idx[solid] = mapped.astype(np.uint8)
    else:
        rgb = Image.fromarray(arr[..., :3], "RGB").quantize(colors=max_colors - 1, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        q = np.array(rgb)
        idx[solid] = q[solid] + 1
        p = rgb.getpalette()[: 3 * (max_colors - 1)]
        pal = [(0, 0, 0)] + [tuple(p[i:i + 3]) for i in range(0, len(p), 3)]
    img = Image.fromarray(idx, "P")
    flatpal = []
    for c in pal:
        flatpal += list(c)
    img.putpalette(flatpal + [0] * (768 - len(flatpal)))
    img.save(path, optimize=True, transparency=0)
    return len(pal)


def render_anim(mod, name, ca):
    """Render every display frame of one animation. Returns a list of dicts
    {logical, at, rgba, nrm, anchors}."""
    n = len(ca["ticks"])
    keys = mod.poses(name, n)
    assert len(keys) == n, f"{mod.__name__}.{name}: {len(keys)} poses for {n} logical frames"
    loop = ca.get("loop", False)
    starts, total = tick_table(ca)
    proc = getattr(mod, "PROCEDURAL", {}).get(name)
    tl = Timeline(keys, ca)
    tick_pose = []
    for l, T in enumerate(ca["ticks"]):
        for w in range(T):
            tick_pose.append(proc((starts[l] + w) / total) if proc else tl.pose(l, w / T))
    sks = [mod.skeleton(p) for p in tick_pose]
    chains = mod.simulate(sks, tick_pose, loop)
    out = []
    geo = {"seg": 0.0, "grip": 0.0}
    for (l, at) in emit_plan(ca, getattr(mod, "HOLD_PULSE", HOLD_PULSE)):
        t = starts[l] + at
        p, sk = tick_pose[t], sks[t]
        if hasattr(mod, "SUPPORTS_TRAIL"):
            trail = [sks[max(t - 1, 0)], sks[max(t - 2, 0)]] if (t > 0 and l not in tl.frozen) else None
            cv, buf = mod.draw(sk, chains[t], p, trail=trail)
        else:
            cv, buf = mod.draw(sk, chains[t], p)
        if hasattr(mod, "validate"):
            m = mod.validate(sk)
            geo["seg"] = max(geo["seg"], m["seg"])
            geo["grip"] = max(geo["grip"], m["grip"])
        rgba = buf["rgba"]
        nrm = quantize_normals(normal_map(buf))
        missing = (rgba[..., 3] > 0) & (nrm[..., 3] == 0)      # smear pixels: flat normal
        nrm[missing] = (128, 128, 255, 255)
        anc = mod.anchors(sk)
        out.append({"logical": l, "at": at, "rgba": rgba, "nrm": nrm,
                    "anchors": {a: [round(float(v), 2) for v in val] for a, val in anc.items()}})
    return out, geo


def load_char(char):
    engine.CHAIN_SUBSTEPS = 2
    mod = importlib.import_module(f"chars.{char}")
    contract = json.load(open(os.path.join(ROOT, "art", "contracts", f"{char}.contract.json")))
    return mod, contract


def build(char):
    mod, contract = load_char(char)
    cell = contract["cell"]
    cells, normals, seen = [], [], {}
    sheet_anims = {}
    geometry = {"seg": 0.0, "grip": 0.0}
    stats = {"display": 0, "ticks": 0}
    for name, ca in contract["anims"].items():
        loop = ca.get("loop", False)
        starts, total = tick_table(ca)
        entries = []
        frames_, geo = render_anim(mod, name, ca)
        geometry["seg"] = max(geometry["seg"], geo["seg"])
        geometry["grip"] = max(geometry["grip"], geo["grip"])
        for fr in frames_:
            key = hashlib.md5(fr["rgba"].tobytes()).hexdigest()
            if key in seen:
                idx = seen[key]
            else:
                idx = len(cells)
                seen[key] = idx
                cells.append(fr["rgba"])
                normals.append(fr["nrm"])
            entries.append({"i": idx, "logical": fr["logical"], "at": fr["at"], "sub": fr["at"] > 0, "anchors": fr["anchors"]})
        stats["display"] += len(entries)
        stats["ticks"] += total
        sheet_anims[name] = {"loop": loop, "ticks": ca["ticks"], "contact": ca.get("contact", []),
                             "hold": ca.get("hold", []), "frames": entries}
        if name in getattr(mod, "REF_SPEED", {}):
            sheet_anims[name]["ref_speed_mps"] = mod.REF_SPEED[name]
    cols = COLS
    while ((len(cells) + cols - 1) // cols) * cell > MAX_TEX and cols * cell + 8 * cell <= MAX_TEX:
        cols += 8
    rows = (len(cells) + cols - 1) // cols
    ground = list(contract.get("ground", [cell // 2, cell - 5]))
    sheet = np.zeros((rows * cell, cols * cell, 4), np.uint8)
    nsheet = np.zeros((rows * cell, cols * cell, 4), np.uint8)
    nsheet[..., :3] = (128, 128, 255)
    for i, (f, nf) in enumerate(zip(cells, normals)):
        y, x = (i // cols) * cell, (i % cols) * cell
        sheet[y:y + cell, x:x + cell] = f
        nsheet[y:y + cell, x:x + cell] = nf
    out = os.path.join(ROOT, "art", "chars", char)
    os.makedirs(out, exist_ok=True)
    ncol = save_palette_png(sheet, os.path.join(out, "sheet.png"))
    ncoln = save_palette_png(nsheet, os.path.join(out, "normal.png"))
    json.dump({"id": char, "cell": cell, "ground": ground, "cols": cols, "frames": len(cells), "format": 3,
               "geometry": {k: round(v, 4) for k, v in geometry.items()}, "anims": sheet_anims},
              open(os.path.join(out, "sheet.json"), "w"))
    json.dump(contract, open(os.path.join(out, "contract.json"), "w"), indent=1)
    contact_sheet(char, out, sheet_anims, cells, cell, ground=ground)
    sz = os.path.getsize(os.path.join(out, "sheet.png")) / 1024
    szn = os.path.getsize(os.path.join(out, "normal.png")) / 1024
    print(f"{char}: {stats['display']} display frames over {stats['ticks']} ticks "
          f"({stats['display'] / max(stats['ticks'], 1):.2f}/tick), {len(cells)} unique cells, sheet {COLS * cell}x{rows * cell}, "
          f"sheet.png {sz:.0f} KB ({ncol} colours), normal.png {szn:.0f} KB ({ncoln} colours)")


def contact_sheet(char, out, anims, cells, cell, scale=2, per_row=22, ground=None):
    """One strip per animation (wrapped), every display frame in order; key frames have a lighter backdrop."""
    blocks = []
    for name, a in anims.items():
        frames = a["frames"]
        for r0 in range(0, len(frames), per_row):
            blocks.append((name if r0 == 0 else "", frames[r0:r0 + per_row]))
    scale = 1 if cell > 64 else scale
    W = per_row * cell * scale + 90
    H = len(blocks) * (cell * scale + 4)
    img = Image.new("RGBA", (W, H), (70, 78, 70, 255))
    d = ImageDraw.Draw(img)
    for r, (name, fr) in enumerate(blocks):
        y = r * (cell * scale + 4)
        d.text((4, y + 4), name, fill=(255, 255, 255, 255))
        for c, e in enumerate(fr):
            f = Image.fromarray(cells[e["i"]], "RGBA").resize((cell * scale, cell * scale), Image.NEAREST)
            x = 90 + c * cell * scale
            d.rectangle([x, y, x + cell * scale - 1, y + cell * scale - 1], fill=(112, 126, 112, 255) if e["at"] == 0 else (92, 104, 92, 255))
            d.line([x, y + (ground[1] if ground else 59) * scale, x + cell * scale, y + (ground[1] if ground else 59) * scale], fill=(60, 66, 60, 255))
            img.alpha_composite(f, (x, y))
    img.convert("RGB").save(os.path.join(out, "contact.png"))


if __name__ == "__main__":
    chars = sys.argv[1:] or ["ren", "capmook", "hopkin"]
    for c in chars:
        build(c)

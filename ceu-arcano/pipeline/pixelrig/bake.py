"""Animação por keyframes -> quadros de pixel art + dados de luta.

Fluxo por animação:
  1. interpola as poses (com easing) a cada frame de jogo (60 fps)
  2. simula as correntes (cabelo, cachecol, lanterna) frame a frame, com aquecimento
  3. amostra quadros a cada `step` frames + nos tempos de keyframe, hitbox e evento
  4. desenha cada quadro (partes, correntes, rastro do golpe) e mede hurtboxes/hitboxes
Depois empacota todos os quadros num atlas, dedupando iguais, e exporta PNG + JSON.
"""
from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass, field

import numpy as np
from PIL import Image

from .raster import Canvas, Part
from .rig import ChainState, rot
from .shapes import Shape, sd_ribbon, sd_capsule, sd_union

# ---------------------------------------------------------------- easing

EASE = {
    "linear": lambda t: t,
    "in": lambda t: t * t * t,
    "out": lambda t: 1 - (1 - t) ** 3,
    "inout": lambda t: t * t * (3 - 2 * t),
    "snap": lambda t: 1 - (1 - t) ** 5,
    "hold": lambda t: 0.0,
    "back": lambda t: 1 + 2.70158 * (t - 1) ** 3 + 1.70158 * (t - 1) ** 2,
}


def _mix(a, b, t):
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return a + (b - a) * t
    if isinstance(a, tuple) and isinstance(b, tuple) and len(a) == len(b):
        return tuple(_mix(x, y, t) if x is not None and y is not None else x for x, y in zip(a, b))
    if isinstance(a, dict) and isinstance(b, dict):
        out = dict(a)
        for k, v in b.items():
            out[k] = _mix(a[k], v, t) if k in a else v
        return out
    return a if t < 0.999 else b


def _zero(v):
    if isinstance(v, (int, float)):
        return 0.0
    if isinstance(v, tuple):
        return tuple(0.0 for _ in v)
    return v


def blend(pa, pb, t):
    out = {}
    for k in set(pa) | set(pb):
        if k == "ease":
            continue
        if k in pa and k in pb:
            out[k] = _mix(pa[k], pb[k], t)
        elif k in pa:
            out[k] = _mix(pa[k], _zero(pa[k]), t)
        else:
            out[k] = _mix(_zero(pb[k]), pb[k], t)
    return out


@dataclass
class Hit:
    t0: int
    t1: int
    bone: str
    off: tuple
    r: float
    rx: float | None = None  # caixa elíptica opcional


@dataclass
class Smear:
    t0: int
    t1: int
    bone: str
    off: tuple
    width: float = 4.0
    trail: float = 4.0       # frames de rastro
    mat: str = "smear"
    z: float = 25.0


@dataclass
class Anim:
    name: str
    length: int
    keys: list                     # [(t, pose)]
    loop: bool = False
    step: int = 3
    hits: list = field(default_factory=list)
    events: list = field(default_factory=list)
    smears: list = field(default_factory=list)
    wind: object = (0.0, 0.0)      # tupla ou função t -> (x, y)
    loop_start: int = 0
    breaks: list = field(default_factory=list)
    prewarm: int = 40
    hold_last: bool = False        # quadro final fica parado (ex.: agachar)

    def pose_at(self, t):
        keys = self.keys
        if t <= keys[0][0]:
            return dict(keys[0][1])
        for i in range(len(keys) - 1):
            ta, pa = keys[i]
            tb, pb = keys[i + 1]
            if ta <= t <= tb:
                if tb == ta:
                    return dict(pb)
                u = (t - ta) / (tb - ta)
                e = EASE[pa.get("ease", "inout")](u)
                return blend(pa, pb, e)
        if self.loop:
            # volta para o primeiro keyframe no fim do loop
            ta, pa = keys[-1]
            tb = self.length
            if tb > ta:
                u = (t - ta) / (tb - ta)
                e = EASE[pa.get("ease", "inout")](u)
                return blend(pa, keys[0][1], e)
        return dict(keys[-1][1])

    def wind_at(self, t):
        return self.wind(t) if callable(self.wind) else self.wind


class Character:
    def __init__(self, cid, skeleton, parts, chains, materials_a, materials_b, anims,
                 chain_style, points, hurt_groups, canvas=(220, 200, 110, 165)):
        self.id = cid
        self.sk = skeleton
        self.parts = parts
        self.chains = chains
        self.mats_a = materials_a
        self.mats_b = materials_b
        self.anims = anims
        self.chain_style = chain_style     # nome -> função(points, ctx) -> [(z, Shape)]
        self.points = points               # nome -> (osso, offset)
        self.hurt_groups = hurt_groups     # grupo -> [nomes de partes]
        self.canvas = canvas


# ---------------------------------------------------------------- bake de uma animação

def simulate(ch, anim, rest_pose):
    """Retorna dict t -> {chain: pontos} para cada frame de jogo 0..length."""
    states = None
    out = {}

    def xf_for(pose):
        return ch.sk.solve(pose)

    # aquecimento: pose de repouso -> primeira pose
    first = anim.pose_at(0)
    warm = []
    for i in range(anim.prewarm):
        u = min(1.0, i / max(1, anim.prewarm * 0.5))
        warm.append(blend(rest_pose, first, EASE["inout"](u)))
    if anim.loop:
        for _ in range(2):
            warm += [anim.pose_at(t) for t in range(anim.length)]
    for p in warm:
        xfs = xf_for(p)
        if states is None:
            states = {c.name: ChainState(c, xfs[c.bone]) for c in ch.chains}
        for c in ch.chains:
            for _ in range(2):
                states[c.name].step(xfs[c.bone], wind=_scale_wind(p.get("wind", anim.wind_at(0)), 0.5), dt=0.5)
    for t in range(anim.length + 1):
        p = anim.pose_at(t)
        xfs = xf_for(p)
        if states is None:
            states = {c.name: ChainState(c, xfs[c.bone]) for c in ch.chains}
        w = p.get("wind", anim.wind_at(t))
        for c in ch.chains:
            for _ in range(2):
                states[c.name].step(xfs[c.bone], wind=_scale_wind(w, 0.5), dt=0.5)
        out[t] = {c.name: list(states[c.name].p) for c in ch.chains}
    return out


def _scale_wind(w, k):
    return (w[0] * k, w[1] * k)


def sample_times(anim):
    ts = set(range(0, anim.length, max(1, anim.step)))
    for t, _ in anim.keys:
        if 0 <= t < anim.length:
            ts.add(int(t))
    for h in anim.hits:
        ts.add(h.t0)
        if h.t1 < anim.length:
            ts.add(h.t1)
    for t, _ in anim.events:
        if 0 <= t < anim.length:
            ts.add(int(t))
    for t in anim.breaks:
        ts.add(int(t))
    ts = sorted(t for t in ts if 0 <= t < anim.length)
    # junta quadros curtos demais (1 frame) que não sejam fronteiras importantes
    return ts


def render_frame(ch, pose, chains_pts, t, anim, materials, smear_paths=None):
    W, H, OX, OY = ch.canvas
    cv = Canvas(W, H, OX, OY, materials)
    xfs = ch.sk.solve(pose)
    ctx = {"face": "neutral"}
    ctx.update({k: v for k, v in pose.items() if isinstance(v, str)})
    items = []
    for part in ch.parts:
        z = pose.get("z." + part.name, part.z)
        items.append((z, "part", part))
    for cname, pts in chains_pts.items():
        style = ch.chain_style.get(cname)
        if style is None:
            continue
        for z, shape in style(pts, ctx, xfs):
            items.append((z, "shape", (cname, shape)))
    if smear_paths:
        for sm, path in smear_paths:
            for z, shape in smear_shapes(sm, path):
                items.append((z, "shape", ("smear", shape)))
    items.sort(key=lambda it: it[0])
    for z, kind, obj in items:
        if kind == "part":
            if obj.bone is None or obj.bone not in xfs:
                continue
            cv.draw_part(obj, xfs[obj.bone], ctx)
        else:
            name, shape = obj
            cv.draw_world_shape(shape, name, ctx)
    cv.finish()
    return cv, xfs


def smear_shapes(sm, path):
    if len(path) < 2:
        return []
    n = len(path)
    radii = [sm.width * (0.15 + 0.85 * (i / (n - 1)) ** 1.5) for i in range(n)]
    inner = [r * 0.45 for r in radii]
    outer = Shape(sd_ribbon(path, radii), sm.mat, level=2, line=False, shadow=False, group=7777)
    core = Shape(sd_ribbon(path, inner), sm.mat, level=4, line=False, shadow=False, group=7777)
    return [(sm.z, outer), (sm.z + 0.01, core)]


def point_world(ch, xfs, bone, off):
    return xfs[bone].apply(off)


def bake_anim(ch, anim, rest_pose):
    sims = simulate(ch, anim, rest_pose)
    ts = sample_times(anim)
    frames = []
    for idx, t in enumerate(ts):
        dur = (ts[idx + 1] if idx + 1 < len(ts) else anim.length) - t
        pose = anim.pose_at(t)
        paths = []
        for sm in anim.smears:
            if sm.t0 <= t <= sm.t1:
                path = []
                tt = t - sm.trail
                k = 0
                while tt <= t + 1e-6:
                    p = anim.pose_at(tt)
                    xf = ch.sk.solve(p)
                    path.append(point_world(ch, xf, sm.bone, sm.off))
                    tt += 0.5
                    k += 1
                if len(path) >= 3:
                    paths.append((sm, path))
        frames.append({"t": t, "dur": dur, "pose": pose, "chains": sims[t], "smears": paths})
    return frames


# ---------------------------------------------------------------- caixas

def bbox_of(mask):
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def frame_boxes(ch, cv, xfs, anim, t):
    OX, OY = ch.canvas[2], ch.canvas[3]
    hurt = []
    name_to_pid = {}
    for pid, n in enumerate(cv.part_names):
        name_to_pid.setdefault(n, []).append(pid)
    active_attack = any(h.t0 <= t < h.t1 for h in anim.hits)
    for grp, names in ch.hurt_groups.items():
        if grp == "limb" and not active_attack:
            continue
        pids = [p for n in names for p in name_to_pid.get(n, [])]
        if not pids:
            continue
        mask = np.isin(cv.part, pids)
        bb = bbox_of(mask)
        if bb is None:
            continue
        x0, y0, x1, y1 = bb
        shrink = 1
        hurt.append([x0 - OX + shrink, y0 - OY + shrink, (x1 - x0) - 2 * shrink, (y1 - y0) - 2 * shrink])
    hits = []
    for h in anim.hits:
        if h.t0 <= t < h.t1:
            c = xfs[h.bone].apply(h.off)
            rx = h.rx if h.rx is not None else h.r
            hits.append([round(c[0] - rx, 1), round(c[1] - h.r, 1), round(2 * rx, 1), round(2 * h.r, 1)])
    pts = {}
    for name, (bone, off) in ch.points.items():
        if bone in xfs:
            p = xfs[bone].apply(off)
            pts[name] = [round(p[0], 1), round(p[1], 1)]
    return hurt, hits, pts


# ---------------------------------------------------------------- atlas

class Packer:
    def __init__(self, width):
        self.width = width
        self.x = 0
        self.y = 0
        self.row_h = 0

    def place(self, w, h):
        if self.x + w > self.width:
            self.x = 0
            self.y += self.row_h + 1
            self.row_h = 0
        pos = (self.x, self.y)
        self.x += w + 1
        self.row_h = max(self.row_h, h)
        return pos

    @property
    def height(self):
        return self.y + self.row_h


def export_character(ch, out_dir, rest_pose, extra_rest=None, log=print):
    import os
    os.makedirs(out_dir, exist_ok=True)
    W, H, OX, OY = ch.canvas
    uniq = {}          # hash -> (idx_mat, idx_lev, bbox)
    anim_out = {}
    order = []
    for anim in ch.anims:
        frames = bake_anim(ch, anim, rest_pose)
        recs = []
        for fr in frames:
            cv, xfs = render_frame(ch, fr["pose"], fr["chains"], fr["t"], anim, ch.mats_a, fr["smears"])
            bb = bbox_of(cv.mat >= 0)
            if bb is None:
                bb = (OX, OY, OX + 1, OY + 1)
            x0, y0, x1, y1 = bb
            m = cv.mat[y0:y1, x0:x1].copy()
            lv = cv.lev[y0:y1, x0:x1].copy()
            key = hashlib.sha1(m.tobytes() + lv.tobytes() + bytes(str(m.shape), "ascii")).hexdigest()
            if key not in uniq:
                uniq[key] = (m, lv)
                order.append(key)
            hurt, hits, pts = frame_boxes(ch, cv, xfs, anim, fr["t"])
            recs.append({"k": key, "o": [OX - x0, OY - y0], "d": fr["dur"], "t": fr["t"],
                         "hurt": hurt, "hit": hits, "pts": pts})
        anim_out[anim.name] = {"loop": anim.loop, "length": anim.length, "loop_start": anim.loop_start,
                               "hold_last": anim.hold_last,
                               "events": [[int(t), n] for t, n in anim.events], "frames": recs}
        log(f"  {anim.name:16s} {len(recs):3d} quadros")
    # empacota (mais altos primeiro)
    keys_sorted = sorted(order, key=lambda k: -uniq[k][0].shape[0])
    width = 2048
    pk = Packer(width)
    rects = {}
    for k in keys_sorted:
        h, w = uniq[k][0].shape
        rects[k] = pk.place(w, h)
    ah = pk.height
    ah = 1 << (ah - 1).bit_length()
    for label, mats in (("a", ch.mats_a), ("b", ch.mats_b)):
        lut = np.zeros((len(mats), 5, 4), np.uint8)
        for i, mt in enumerate(mats):
            for j in range(5):
                lut[i, j] = mt.ramp[j]
        atlas = np.zeros((ah, width, 4), np.uint8)
        for k in order:
            m, lv = uniq[k]
            x, y = rects[k]
            h, w = m.shape
            f = m >= 0
            blk = atlas[y:y + h, x:x + w]
            blk[f] = lut[m[f], lv[f]]
        Image.fromarray(atlas, "RGBA").save(os.path.join(out_dir, f"{ch.id}_{label}.png"), optimize=True)
    for an in anim_out.values():
        for r in an["frames"]:
            k = r.pop("k")
            x, y = rects[k]
            h, w = uniq[k][0].shape
            r["r"] = [x, y, w, h]
    meta = {"id": ch.id, "atlas": [width, ah], "anims": anim_out}
    with open(os.path.join(out_dir, f"{ch.id}.json"), "w") as f:
        json.dump(meta, f, separators=(",", ":"))
    log(f"  atlas {width}x{ah}, {len(order)} quadros únicos")
    return meta


def render_preview(ch, anim_name, rest_pose, t=None, mats=None, scale=4):
    anim = next(a for a in ch.anims if a.name == anim_name)
    frames = bake_anim(ch, anim, rest_pose)
    fr = frames[0] if t is None else min(frames, key=lambda f: abs(f["t"] - t))
    cv, _ = render_frame(ch, fr["pose"], fr["chains"], fr["t"], anim, mats or ch.mats_a, fr["smears"])
    img = Image.fromarray(cv.rgba(mats or ch.mats_a), "RGBA")
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)

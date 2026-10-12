"""Test enemy: a jelly slime with a leaf sprout on a spring. Same pipeline as the mage."""
import math
import numpy as np

from raster import Material, hexpal
from rig import v3, norm, rot_x, rot_z, Chain, Timeline

NAME = "slime"
FRAME = (64, 64)
ORIGIN = (32, 52)

MAT = {
    "jelly": Material("jelly", hexpal("#e6ffb0", "#9be25a", "#5fb146", "#3a7d3c", "#22492e")),
    "belly": Material("belly", hexpal("#f4ffd6", "#c8f08c", "#8fcf62", "#5a9a48", "#2f5a32")),
    "leaf": Material("leaf", hexpal("#d8ff9a", "#62c443", "#3e9440", "#2a6534", "#173d22")),
    "stem": Material("stem", hexpal("#c79a64", "#93673f", "#6b472c", "#4a2f1f", "#2b1a12")),
}
EYE = (24, 26, 34)
SHINE = (255, 255, 255)

BASE = dict(root=(0, 0, 0), sq=1.0, lean=0.0, tilt=0.0, expr="neutral")


def P(**kw):
    d = dict(BASE)
    d.update(kw)
    return d


def solve(pose):
    root = v3(pose["root"])
    sq = pose["sq"]
    rx, rz = 9.5 / math.sqrt(sq), 8.5 * sq
    R = rot_x(-pose["lean"]) @ rot_z(pose["tilt"])
    c = root + v3(0, 0, rz)
    top = c + R @ v3(0, -0.5, rz - 0.6)
    return dict(pose=pose, R=R, center=c, rx=rx, rz=rz, top=top, head=c, chest=c,
                eye=c + R @ v3(0, rx * 0.9, rz * 0.15))


def make_chains():
    sprout = Chain([(0, -0.2, 1), (0, -0.4, 1), (0, -0.2, 1)], [2.2, 2.2, 2.0],
                   stiffness=0.18, damping=0.10, gravity=0.04, drag=0.05)
    return {"sprout": (sprout, "top", "R")}


def _ellipsoid(c, R, rx, ry, rz, nlat=9, nlon=18):
    rings, norms = [], []
    th = np.linspace(0, 2 * math.pi, nlon, endpoint=False)
    for i in range(nlat + 1):
        phi = -math.pi / 2 + math.pi * i / nlat
        cp, sp = math.cos(phi), math.sin(phi)
        z = rz * sp if i < nlat else rz
        flat = 1.0 if sp > -0.55 else 0.75  # flat bottom where it sits on the ground
        pts = np.stack([rx * cp * np.cos(th), ry * cp * np.sin(th), np.full_like(th, z * flat)], -1)
        nn = np.stack([cp * np.cos(th) / rx, cp * np.sin(th) / ry, np.full_like(th, sp / rz)], -1)
        rings.append(c + pts @ R.T)
        norms.append((nn / np.linalg.norm(nn, axis=-1, keepdims=True)) @ R.T)
    return rings, norms


def draw(cv, s, chains, Rf):
    W = lambda p: np.asarray(p) @ Rf.T
    body = cv.part("body", MAT["jelly"], group="body", bands=(1.6, 3.6), highlight=1.4)
    rings, norms = _ellipsoid(s["center"], s["R"], s["rx"], s["rx"] * 0.92, s["rz"])
    body.loft([W(r) for r in rings], [W(n) for n in norms])
    sp = chains["sprout"]
    stem = cv.part("stem", MAT["stem"], group="stem", vote=3.0, shade=False)
    for i in range(len(sp) - 1):
        stem.capsule(W(sp[i]), W(sp[i + 1]), 0.7, 0.6)
    leaf = cv.part("leaf", MAT["leaf"], group="leaf", bands=(0.8, 1.6))
    tip = sp[-1]
    d = norm(sp[-1] - sp[-2])
    side = norm(np.cross(d, v3(0, 1, 0))) if abs(d[1]) < 0.9 else v3(1, 0, 0)
    for sx in (-1, 1):
        a = tip + side * sx * 0.5
        b = tip + side * sx * 4.2 + d * 1.4
        leaf.capsule(W(a), W(b), 1.4, 0.8)


def paint_face(out, cv, s, Rf):
    names = [p.name for p in out["parts"]]
    if "body" not in names:
        return
    bi = names.index("body")
    owner, img = out["owner"], out["rgba"]
    expr = s["pose"]["expr"]
    c, R = s["center"], s["R"]
    for sx in (-1, 1):
        local = v3(sx * 3.2, s["rx"] * 0.86, s["rz"] * 0.2)
        nrm = Rf @ (R @ norm(local))
        if -nrm[1] * 0.866 + nrm[2] * 0.5 < 0.2:
            continue
        x, y, _ = cv.to_px(Rf @ (c + R @ local))
        x, y = int(math.floor(x)), int(math.floor(y))
        def put(px, py, col):
            if 0 <= py < img.shape[0] and 0 <= px < img.shape[1] and owner[py, px] == bi:
                img[py, px, :3] = col
        if expr in ("hurt", "dead"):
            put(x, y, EYE)
            put(x + (1 if expr == "dead" else 0), y + 1, EYE)
        else:
            put(x, y, EYE)
            put(x, y + 1, EYE)
            put(x, y - 1, EYE)
            put(x, y - 1, SHINE) if False else None


def _idle(t, length):
    p = (t / length) % 1.0
    b = math.sin(2 * math.pi * p)
    return P(sq=1.0 + 0.07 * b, lean=1.5 * b)


def _hop(t, length):
    p = (t / length) % 1.0
    if p < 0.2:  # squash before take off
        u = p / 0.2
        return P(sq=1.0 - 0.25 * math.sin(math.pi * u * 0.5), lean=-4 * u)
    if p < 0.8:
        u = (p - 0.2) / 0.6
        h = 9.0 * math.sin(math.pi * u)
        return P(root=(0, 0, h), sq=1.18 - 0.3 * u, lean=6 * math.cos(math.pi * u))
    u = (p - 0.8) / 0.2
    return P(sq=0.82 + 0.18 * u, lean=-2 * (1 - u))


HURT = [P(sq=0.7, lean=-14, root=(0, -2, 0), expr="hurt"), P(sq=1.2, lean=-6, root=(0, -1.5, 0), expr="hurt"), P()]
DEATH = [P(sq=0.65, lean=-14, expr="hurt"), P(sq=1.3, root=(0, 0, 3), expr="dead"),
         P(sq=0.45, expr="dead"), P(sq=0.25, expr="dead")]


def keyed(keys, ca):
    times, t = [], 0
    for f in ca["frames"]:
        times.append(t)
        t += f["ticks"]
    tl = Timeline(keys, times, t, ca["loop"])
    return lambda tt, length: tl.sample(tt)


def animations(contract):
    a = contract["animations"]
    hop_len = sum(f["ticks"] for f in a["walk"]["frames"])
    return {
        "idle": dict(sample=_idle, root_speed=0.0),
        "walk": dict(sample=_hop, root_speed=0.0),
        "hurt": dict(sample=keyed(HURT, a["hurt"]), root_speed=0.0),
        "death": dict(sample=keyed(DEATH, a["death"]), root_speed=0.0),
    }


ANCHORS = ("head", "top")
SUBFRAMES = {"idle": [1, 1, 1, 1], "walk": [1] * 6, "hurt": [1, 1, 1], "death": [1, 1, 1, 0]}

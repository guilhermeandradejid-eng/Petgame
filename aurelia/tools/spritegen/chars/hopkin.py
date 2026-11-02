"""Hopkin v3 - a round bunny-blob that hops and pounces, arcade hi-bit. ~28 px tall with ears. Faces right.

Body = one squashable ellipse pivoting around the ground contact, two floppy spring-chain ears,
tiny planted feet, a cream belly and a cotton tail. Big painted eyes, angry when it attacks.
"""
import math

from engine import Canvas, Mask, simulate_chain, hexc
from chars._cute import eyes, put

CELL = 64
G = (32.0, 59.0)
S = 0.86                  # global size factor vs v2 (target idle height ~28 px incl. ears)
MATERIALS = {             # hand-authored 5-tone ramps: violet shadows, warm lights
    "fur": ("#9A8AE6", False, ["#2C2A6A", "#5E58B0", "#9A8AE6", "#C4B6FB", "#E8E0FF"]),
    "belly": ("#FFD4B8", False, ["#7A4C6A", "#D09AA0", "#FFD4B8", "#FFEADB", "#FFF8F0"]),
    "ear": ("#9A88EA", False, ["#32286E", "#5F52B8", "#9A88EA", "#BFB0FA", "#E0D8FF"]),
    "earin": ("#FF98B4", False, ["#82305A", "#CF5F8E", "#FF98B4", "#FFC0D0", "#FFE6EE"]),
    "foot": ("#6A5CC8", False, ["#1E1A52", "#3E3890", "#6A5CC8", "#8C80E4", "#B0A8F6"]),
    "tail": ("#FFF0E4", False, ["#7A6A90", "#C4B4C8", "#FFF0E4", "#FFFAF2", "#FFFFFF"]),
}
NO_SEAM = {("body", "tail"), ("earA", "body"), ("earB", "body"), ("earA", "earinA"), ("earB", "earinB"),
           ("footF", "body"), ("footB", "body"), ("body", "belly")}

DEFAULT = dict(hx=0.0, lift=0.0, lean=0.0, bw=11.0, bh=9.5, ff=(4.6, 0.0), bf=(-4.6, 0.0),
               earback=0.0, droop=0.0, rage=0.0, expr="neutral", mouth="smile", wind=0.0)


def P(**kw):
    d = dict(DEFAULT)
    d.update(kw)
    for k in ("bw", "bh", "hx", "lift"):
        d[k] = d[k] * S
    for k in ("ff", "bf"):
        d[k] = (d[k][0] * S, d[k][1] * S)
    return d


def sq(s):
    """Volume-preserving squash/stretch: s>1 stretches tall, s<1 squashes flat (area stays constant)."""
    return {"bh": 9.5 * s, "bw": 11.0 / s}


def poses(anim, n):
    """Disney checklist per anim: anticipation, squash & stretch (volume kept), arcs, overlap (ears are
    springs), slow in/out (ease tags), exaggeration, a clear tell before every attack."""
    if anim == "idle":
        return [
            P(**sq(1.0)),
            P(**sq(0.985), earback=0.15),
            P(**sq(0.965), earback=0.5, lean=1.2),                     # breath in, ear twitch
            P(**sq(0.985), earback=-0.1, expr="blink"),
        ][:n]
    if anim == "walk":    # hop cycle on an arc: squat -> stretch-launch -> peak -> tuck/fall -> land squash -> settle
        return [
            P(**sq(0.8), ff=(5.0, 0), bf=(-5.0, 0), earback=-0.5, expr="happy", ease="in"),
            P(**sq(1.20), lift=2.4, lean=8, ff=(2.2, -2.0), bf=(-3.4, -2.6), earback=0.6, hx=0.6, ease="out"),
            P(**sq(1.08), lift=6.6, lean=4, ff=(3.6, -6.2), bf=(-2.8, -6.6), earback=0.8, hx=1.4),
            P(**sq(0.98), lift=4.4, lean=-6, ff=(4.4, -4.2), bf=(-2.6, -4.6), earback=0.2, hx=1.9, ease="in"),
            P(**sq(0.70), ff=(5.6, 0), bf=(-5.4, 0), earback=-1.0, lean=3, hx=1.9, ease="out"),
            P(**sq(1.05), earback=-0.2, hx=1.2),
        ][:n]
    if anim == "windup":   # the tell: pin ears, coil, shiver, glare
        return [
            P(**sq(0.84), hx=-0.7, earback=0.5, expr="angry", mouth="fang", ff=(5.0, 0), bf=(-5.0, 0), ease="inout"),
            P(**sq(0.8), hx=0.9, earback=0.7, expr="angry", mouth="fang", ff=(5.5, 0), bf=(-5.4, 0)),
            P(**sq(0.72), lean=-9, hx=-0.5, earback=0.9, expr="angry", mouth="fang", ff=(6.0, 0), bf=(-5.8, 0)),
        ][:n]
    if anim == "pounce":
        return [
            P(**sq(0.7), lean=-12, hx=-1.6, earback=0.95, expr="angry", mouth="fang", ff=(6.0, 0), bf=(-5.8, 0), ease="in"),
            P(**sq(1.24), lean=30, hx=1.6, lift=8.0, earback=1.15, expr="angry", mouth="open", ff=(-1.0, -9.0), bf=(-4.6, -9.8), ease="snap"),
            P(**sq(1.12), lean=34, hx=3.0, lift=4.8, earback=1.0, expr="angry", mouth="open", ff=(1.0, -5.8), bf=(-4.2, -6.4)),
            P(**sq(0.88), lean=38, hx=4.0, earback=1.2, expr="angry", mouth="wide", ff=(3.2, 0), bf=(-5.6, 0)),
            P(**sq(0.72), lean=12, hx=3.2, earback=-0.6, expr="angry", mouth="fang", ff=(5.2, 0), bf=(-5.6, 0), ease="out"),
            P(**sq(1.03), lean=-1, hx=1.2, earback=0.3, expr="neutral"),
        ][:n]
    if anim == "hurt":
        return [
            P(**sq(1.22), lean=-24, hx=-2.6, lift=1.0, expr="hurt", mouth="o", earback=1.4, ff=(3.5, -0.5), bf=(-5, -0.5), ease="snap"),
            P(**sq(0.76), lean=-12, hx=-3.2, expr="hurt", mouth="o", earback=0.5),
            P(**sq(1.0), lean=-3, hx=-1.4, expr="hurt", mouth="o", earback=-0.3),
        ][:n]
    if anim == "death":
        return [
            P(**sq(1.2), lean=-24, hx=-2.6, lift=1.0, expr="hurt", mouth="o", earback=1.4, ease="snap"),
            P(**sq(0.74), lean=-8, hx=-2.6, expr="dead", mouth="tongue", earback=-1.0, droop=0.4),
            P(bw=15.0, bh=5.6, hx=-2.6, expr="dead", mouth="tongue", droop=0.8, earback=-1.0),
            P(bw=16.2, bh=4.7, hx=-2.6, expr="dead", mouth="tongue", droop=1.0, earback=-1.0),
            P(bw=16.6, bh=4.3, hx=-2.6, expr="dead", mouth="tongue", droop=1.0, earback=-1.0),
        ][:n]
    raise KeyError(anim)


def _rot(v, deg):
    a = math.radians(deg)
    return (v[0] * math.cos(a) - v[1] * math.sin(a), v[0] * math.sin(a) + v[1] * math.cos(a))


def skeleton(p):
    lr = math.radians(p["lean"])
    td = (math.sin(lr), -math.cos(lr))
    pivot = (G[0] + p["hx"], G[1] - p["lift"] - 1.5)
    c = (pivot[0] + td[0] * p["bh"], pivot[1] + td[1] * p["bh"])
    return {"pivot": pivot, "c": c, "lean": p["lean"], "earback": p["earback"], "droop": p["droop"],
            "footn": (G[0] + p["ff"][0], G[1] + p["ff"][1]), "footf": (G[0] + p["bf"][0], G[1] + p["bf"][1]),
            "bw": p["bw"], "bh": p["bh"]}


EAR_A = [(-1.8, -4.6), (-4.6, -8.6), (-8.6, -10.2)]      # back ear: flops back
EAR_B = [(1.4, -4.8), (3.4, -9.0), (7.4, -11.2)]         # front ear: flops forward
EAR_A_FLAT = [(-3.4, -1.0), (-6.8, 0.2), (-10.2, 1.2)]
EAR_B_FLAT = [(3.2, -0.8), (6.6, 0.4), (10.0, 1.3)]


def _ear_rest(sk, which):
    base, flat = (EAR_A, EAR_A_FLAT) if which == "A" else (EAR_B, EAR_B_FLAT)
    d = sk["droop"]
    ang = sk["lean"] + (-sk["earback"] * (45 if which == "A" else 70))
    out = []
    for (bx, by), (fx, fy) in zip(base, flat):
        v = _rot((bx * S, by * S), ang)
        v = (v[0] * (1 - d) + fx * S * d, v[1] * (1 - d) + fy * S * d)
        out.append(v)
    return out


def _ear_anchor(sk, which):
    bw, bh = sk["bw"], sk["bh"]
    c = sk["c"]
    lr = sk["lean"]
    off = _rot((-3.0 if which == "A" else 2.5, -bh * 0.82), lr)
    return (c[0] + off[0], c[1] + off[1])


def simulate(sks, poses_, loop):
    out = [dict() for _ in sks]
    for which in ("A", "B"):
        anchors = [_ear_anchor(s, which) for s in sks]
        rests = []
        for s, a in zip(sks, anchors):
            rests.append([(a[0] + dx, a[1] + dy) for dx, dy in _ear_rest(s, which)])
        res = simulate_chain(anchors, rests, stiffness=0.11, damping=0.80, gravity=0.34, loop=loop, floor=G[1] - 1.8)
        for i, pts in enumerate(res):
            out[i]["ear" + which] = pts
    return out


def _mix(a, b, t):
    return "#%02X%02X%02X" % tuple(int(round(x + (y - x) * t)) for x, y in zip(hexc(a), hexc(b)))


def draw(sk, chains, p):
    cv = Canvas(CELL, MATERIALS)
    c, bw, bh, lean = sk["c"], p["bw"], p["bh"], sk["lean"]
    # ears behind the head
    cv.paint("ear", Mask(CELL).ribbon(chains["earA"], 3.5, 1.8), group="earA", k=3, deep=True, hi=False)
    cv.paint("earin", Mask(CELL).ribbon(chains["earA"][:], 1.8, 0.8), group="earinA", k=2, deep=False, hi=False)
    cv.paint("ear", Mask(CELL).ribbon(chains["earB"], 3.7, 1.9), group="earB", k=3, deep=True, hi=False)
    cv.paint("earin", Mask(CELL).ribbon(chains["earB"][:], 1.9, 0.9), group="earinB", k=2, deep=False, hi=False)
    # cotton tail peeking out behind
    tl = _rot((-bw + 0.8, 2.2), lean)
    cv.paint("tail", Mask(CELL).circle((c[0] + tl[0], c[1] + tl[1]), 3.4), group="tail", k=3, deep=False)
    # planted feet
    for tag, grp in (("footf", "footB"), ("footn", "footF")):
        f = sk[tag]
        cv.paint("foot", Mask(CELL).ellipse((f[0] + 0.5, f[1] - 1.9), 3.4, 2.2), group=grp, k=3)
    # body + belly
    body = Mask(CELL).ellipse(c, bw, bh, lean)
    cv.paint("fur", body, group="body", k=6, cast=4)
    bo = _rot((bw * 0.12, bh * 0.50), lean)
    belly = Mask(CELL).ellipse((c[0] + bo[0], c[1] + bo[1]), bw * 0.50, bh * 0.42, lean).array() & body.array()
    cv.paint("belly", belly, group="body", k=5, deep=False)
    buf = cv.finish(NO_SEAM)
    # ---- face ----
    ok = {cv.matidx["fur"], cv.matidx["belly"]}
    fo = _rot((bw * 0.22, -bh * 0.06), lean)
    fx, fy = int(round(c[0] + fo[0])), int(round(c[1] + fo[1]))
    eyes(buf, ok, fx, fy - 1, p["expr"], 3, 4, 4)
    pink, dark, white, tongue = (246, 150, 170), (92, 40, 60), (255, 255, 255), (240, 110, 130)
    if p["expr"] in ("neutral", "blink", "happy"):
        for dx in (-7, 7):
            for dy in (4, 5):
                put(buf, fx + dx, fy + dy, pink, ok)
        put(buf, fx, fy + 4, (220, 100, 130), ok)
        for dx, dy in ((-1, 5), (0, 6), (1, 5)):
            put(buf, fx + dx, fy + dy, dark, ok)
    else:
        for dx in (-7, 7):
            put(buf, fx + dx, fy + 4, pink, ok)
        put(buf, fx, fy + 4, (220, 100, 130), ok)
        m = p["mouth"]
        if m in ("open", "wide"):
            w = 2 if m == "open" else 3
            for dx in range(-w, w + 1):
                for dy in range(5, 8 if m == "wide" else 7):
                    put(buf, fx + dx, fy + dy, dark, ok)
            put(buf, fx - w + 1, fy + 5, white, ok)
            put(buf, fx + w - 1, fy + 5, white, ok)
            for dx in range(-1, 2):
                put(buf, fx + dx, fy + (6 if m == "open" else 7), tongue, ok)
        elif m == "fang":
            for dx in range(-2, 3):
                put(buf, fx + dx, fy + 6, dark, ok)
            put(buf, fx - 1, fy + 7, white, ok)
            put(buf, fx + 1, fy + 7, white, ok)
        elif m == "o":
            for dx, dy in ((0, 6), (1, 6), (0, 7), (1, 7)):
                put(buf, fx + dx, fy + dy, dark, ok)
        elif m == "tongue":
            for dx in range(-1, 3):
                put(buf, fx + dx, fy + 5, dark, ok)
            put(buf, fx + 1, fy + 6, tongue, ok)
            put(buf, fx + 2, fy + 6, tongue, ok)
    return cv, buf


def anchors(sk):
    c, lean = sk["c"], sk["lean"]
    tipo = _rot((sk["bw"], 1.0), lean)
    top = _rot((0.0, -sk["bh"]), lean)
    ang = math.radians(lean)
    return {"hand": (c[0] + tipo[0], c[1] + tipo[1]), "hand_dir": (math.cos(ang), math.sin(ang)),
            "off_hand": sk["pivot"], "head": (c[0] + top[0], c[1] + top[1]), "chest": c,
            "weapon_tip": (c[0] + tipo[0], c[1] + tipo[1])}

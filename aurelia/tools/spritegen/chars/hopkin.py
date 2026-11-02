"""Hopkin - a round bunny-blob that hops and pounces. ~30 px tall with ears. Faces right.

Body = one squashable ellipse pivoting around the ground contact, two floppy spring-chain ears,
tiny planted feet, a cream belly and a cotton tail. Big painted eyes, angry when it attacks.
"""
import math

from engine import Canvas, Mask, simulate_chain, hexc
from chars._cute import eyes, put

CELL = 64
G = (32.0, 59.0)
FUR = "#B8A3EC"
RAGE = "#EE8FC2"
MATERIALS = {
    "fur": (FUR, False), "belly": ("#FFE6CC", False), "ear": ("#A28AE0", False),
    "earin": ("#F9B6CB", False), "foot": ("#7A5FC2", False), "tail": ("#FFF6EA", False),
}
NO_SEAM = {("body", "tail"), ("earA", "body"), ("earB", "body"), ("earA", "earinA"), ("earB", "earinB"),
           ("footF", "body"), ("footB", "body"), ("body", "belly")}

DEFAULT = dict(hx=0.0, lift=0.0, lean=0.0, bw=11.0, bh=9.5, ff=(4.6, 0.0), bf=(-4.6, 0.0),
               earback=0.0, droop=0.0, rage=0.0, expr="neutral", mouth="smile", wind=0.0)


def P(**kw):
    d = dict(DEFAULT)
    d.update(kw)
    return d


def poses(anim, n):
    if anim == "idle":
        return [
            P(bw=11.0, bh=9.5, earback=0.0),
            P(bw=11.25, bh=9.3, earback=0.25, ff=(4.7, 0), bf=(-4.7, 0)),
            P(bw=11.5, bh=9.1, earback=0.8, lean=1.5),                     # ear twitch
            P(bw=11.2, bh=9.4, earback=-0.1, expr="blink"),
        ][:n]
    if anim == "walk":    # the hop cycle: squat, stretch-launch, air, air-tuck, land squash, settle
        return [
            P(bw=12.8, bh=7.8, ff=(5.0, 0), bf=(-5.0, 0), earback=-0.4),
            P(bw=9.4, bh=11.2, lift=2.5, lean=6, ff=(3.0, -2.0), bf=(-3.0, -2.2), earback=0.4, hx=0.5),
            P(bw=10.0, bh=10.6, lift=6.0, lean=9, ff=(3.8, -6.0), bf=(-3.2, -6.4), earback=0.7, hx=1.0),
            P(bw=11.0, bh=10.0, lift=5.0, lean=13, ff=(4.4, -5.0), bf=(-2.8, -5.4), earback=0.55, hx=1.5, expr="happy"),
            P(bw=13.2, bh=7.3, ff=(5.4, 0), bf=(-5.2, 0), earback=-0.8, lean=2, hx=1.5),
            P(bw=11.8, bh=9.0, earback=-0.2, hx=1.0),
        ][:n]
    if anim == "windup":
        return [
            P(bw=12.8, bh=8.0, hx=-0.8, rage=0.3, earback=0.3, expr="angry", ff=(5.0, 0), bf=(-5.0, 0)),
            P(bw=13.6, bh=7.3, hx=0.8, rage=0.65, earback=0.65, expr="angry", ff=(5.4, 0), bf=(-5.4, 0)),
            P(bw=14.2, bh=6.8, lean=-7, rage=1.0, earback=1.0, expr="angry", mouth="fang", ff=(5.8, 0), bf=(-5.6, 0)),
        ][:n]
    if anim == "pounce":
        return [
            P(bw=14.0, bh=6.6, lean=-10, hx=-1.5, rage=1.0, earback=1.0, expr="angry", mouth="fang", ff=(5.8, 0), bf=(-5.6, 0)),
            P(bw=9.0, bh=11.4, lean=28, hx=1.5, lift=8.0, rage=1.0, earback=0.75, expr="angry", mouth="open", ff=(-1.0, -9.0), bf=(-4.5, -9.6)),
            P(bw=10.0, bh=10.4, lean=36, hx=3.0, lift=4.5, rage=1.0, earback=0.8, expr="angry", mouth="open", ff=(1.0, -5.5), bf=(-4.0, -6.0)),
            P(bw=12.2, bh=8.6, lean=36, hx=3.8, rage=1.0, earback=1.1, expr="angry", mouth="wide", ff=(3.0, 0), bf=(-5.5, 0)),
            P(bw=13.5, bh=7.2, lean=14, hx=3.0, rage=0.5, earback=0.3, expr="angry", mouth="fang", ff=(5.0, 0), bf=(-5.4, 0)),
            P(bw=11.8, bh=9.0, lean=1, hx=1.2, rage=0.1, earback=-0.2, expr="neutral"),
        ][:n]
    if anim == "hurt":
        return [
            P(bw=9.0, bh=11.4, lean=-22, hx=-2.5, lift=1.0, expr="hurt", mouth="o", earback=1.3, ff=(3.5, -0.5), bf=(-5, -0.5)),
            P(bw=13.0, bh=8.0, lean=-12, hx=-3.0, expr="hurt", mouth="o", earback=0.7),
            P(bw=11.6, bh=9.2, lean=-4, hx=-1.5, expr="hurt", mouth="o", earback=0.1),
        ][:n]
    if anim == "death":
        return [
            P(bw=9.4, bh=11.0, lean=-22, hx=-2.5, lift=1.0, expr="hurt", mouth="o", earback=1.3),
            P(bw=13.6, bh=7.0, lean=-6, hx=-2.5, expr="dead", mouth="tongue", earback=-1.0, droop=0.4),
            P(bw=15.2, bh=5.6, hx=-2.5, expr="dead", mouth="tongue", droop=0.8, earback=-1.0),
            P(bw=16.2, bh=4.7, hx=-2.5, expr="dead", mouth="tongue", droop=1.0, earback=-1.0),
            P(bw=16.6, bh=4.3, hx=-2.5, expr="dead", mouth="tongue", droop=1.0, earback=-1.0),
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
        v = _rot((bx, by), ang)
        v = (v[0] * (1 - d) + fx * d, v[1] * (1 - d) + fy * d)
        out.append(v)
    return out


def _ear_anchor(sk, which):
    bw, bh = sk["bw"], sk["bh"]
    c = sk["c"]
    lr = sk["lean"]
    off = _rot((-3.4 if which == "A" else 2.8, -bh * 0.82), lr)
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
    mats = dict(MATERIALS)
    mats["fur"] = (_mix(FUR, RAGE, p["rage"]), False)
    cv = Canvas(CELL, mats)
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
    bo = _rot((bw * 0.22, bh * 0.28), lean)
    belly = Mask(CELL).ellipse((c[0] + bo[0], c[1] + bo[1]), bw * 0.62, bh * 0.6, lean).array() & body.array()
    cv.paint("belly", belly, group="body", k=5, deep=False)
    buf = cv.finish(NO_SEAM)
    # ---- face ----
    ok = {cv.matidx["fur"], cv.matidx["belly"]}
    fo = _rot((bw * 0.17, -bh * 0.16), lean)
    fx, fy = int(round(c[0] + fo[0])), int(round(c[1] + fo[1]))
    eyes(buf, ok, fx, fy, p["expr"], 3, 4, 5)
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

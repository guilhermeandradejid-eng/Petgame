"""Capmook v2 - a grumpy walking toadstool. ~38 px tall. Faces right (mirrored in-engine).

Body = two ellipses (bulb + neck) pivoting around the foot contact point, so squash, lean and
crouch stay planted on the ground. The cap is a spring particle (jiggle) and can be knocked off.
"""
import math

from engine import Canvas, Mask, simulate_chain, hexc
from chars._cute import eyes, put, DARK

CELL = 64
G = (32.0, 59.0)
CAP = "#D8403A"
HOT = "#FF9A2E"
MATERIALS = {
    "stem": ("#EDDDB8", False), "cap": (CAP, True), "spot": ("#FBF1D8", False),
    "gills": ("#C9A27A", False), "foot": ("#7A4A34", False),
}
NO_SEAM = {("cap", "gills"), ("gills", "body"), ("cap", "spots"), ("footF", "body"), ("footB", "body"), ("neck", "body")}

DEFAULT = dict(hx=0.0, lift=0.0, lean=0.0, bw=7.4, bh=9.4, nr=5.8, nk=4.2, ff=(3.0, 0.0), bf=(-3.4, 0.0),
               capoff=(0.0, 0.0), capabs=(0.0, 0.0), capfree=0.0, caprot=0.0, glow=0.0, expr="neutral", mouth="smile", wind=0.0)


def P(**kw):
    d = dict(DEFAULT)
    d.update(kw)
    return d


def _foot(t, stride, lift):
    t %= 1.0
    if t < 0.5:
        return (stride * (1 - 4 * t), 0.0)
    u = (t - 0.5) * 2
    s = u * u * (3 - 2 * u)
    return (-stride + 2 * stride * s, -lift * math.sin(math.pi * u))


def poses(anim, n):
    if anim == "idle":
        # breathing: bulb widens as the stem shortens, cap bobs, one blink
        v = [(0.0, 7.4, 9.4), (0.2, 7.55, 9.25), (0.5, 7.75, 9.0), (0.7, 7.8, 8.9), (0.35, 7.65, 9.1), (0.1, 7.5, 9.3)]
        return [P(bw=b, bh=h, nk=4.2 - d, expr="blink" if i == 4 else "neutral", lean=(-1.0 if i in (2, 3) else 0.0))
                for i, (d, b, h) in enumerate(v)][:n]
    if anim == "walk":
        out = []
        for i in range(n):
            t = i / n
            ff, bf = _foot(t, 3.4, 2.6), _foot(t + 0.5, 3.4, 2.6)
            out.append(P(lean=5.0 * math.sin(2 * math.pi * t), lift=0.0, bw=7.4 + 0.35 * math.cos(4 * math.pi * t),
                         bh=9.4 - 0.5 * math.cos(4 * math.pi * t), ff=ff, bf=bf, hx=0.6 * math.sin(2 * math.pi * t)))
        return out
    if anim == "windup":      # squat + shake + cap heats up
        return [
            P(bw=8.2, bh=8.0, nk=3.6, lean=-5, glow=0.3, expr="angry", ff=(3.2, 0), bf=(-3.6, 0)),
            P(bw=8.9, bh=7.0, nk=3.0, lean=-11, glow=0.6, expr="angry", hx=-1.0, ff=(3.6, 0), bf=(-4.0, 0), capoff=(0, 0.5)),
            P(bw=9.4, bh=6.3, nk=2.6, lean=-15, glow=0.9, expr="angry", hx=1.0, ff=(3.9, 0), bf=(-4.3, 0), capoff=(-0.5, 1.0), mouth="grit"),
            P(bw=9.7, bh=6.0, nk=2.4, lean=-18, glow=1.0, expr="angry", ff=(4.1, 0), bf=(-4.5, 0), capoff=(-1.0, 1.4), mouth="grit"),
        ][:n]
    if anim == "headbutt":
        return [
            P(bw=9.7, bh=6.0, nk=2.4, lean=-22, glow=1.0, expr="angry", hx=-1.0, ff=(4.2, 0), bf=(-4.6, 0), capoff=(-1.5, 1.6), mouth="grit"),
            P(bw=9.9, bh=5.7, nk=2.2, lean=-26, glow=1.0, expr="angry", hx=-2.5, ff=(4.4, 0), bf=(-4.8, 0), capoff=(-2.5, 1.8), mouth="grit"),
            P(bw=6.6, bh=10.4, nk=5.0, lean=14, glow=1.0, expr="angry", hx=2.0, lift=3.0, ff=(5.5, -1.5), bf=(-3.5, -2.5), mouth="open"),
            P(bw=6.8, bh=10.0, nk=5.0, lean=27, glow=1.0, expr="angry", hx=3.5, lift=1.0, ff=(7.0, 0), bf=(-2.5, -0.5), capoff=(1.6, 0.6), mouth="open"),
            P(bw=7.6, bh=9.0, nk=4.0, lean=18, glow=0.5, expr="angry", hx=3.5, ff=(6.0, 0), bf=(-3.0, 0), capoff=(1.0, 0.5), mouth="open"),
            P(bw=8.6, bh=7.4, nk=3.0, lean=7, glow=0.15, expr="neutral", hx=2.5, ff=(4.5, 0), bf=(-3.5, 0), mouth="grit"),
            P(bw=7.8, bh=8.6, nk=3.8, lean=1, hx=1.0, expr="neutral"),
        ][:n]
    if anim == "hurt":
        return [
            P(bw=6.6, bh=10.0, nk=4.8, lean=-20, hx=-2.0, lift=0.8, expr="hurt", capoff=(-1.0, -0.3), ff=(3.5, -0.5), bf=(-4, 0), mouth="o"),
            P(bw=8.2, bh=7.8, nk=3.2, lean=-14, hx=-2.5, expr="hurt", capoff=(-1.0, 0.6), mouth="o"),
            P(bw=7.7, bh=8.8, nk=3.8, lean=-5, hx=-1.0, expr="hurt", mouth="o"),
        ][:n]
    if anim == "death":
        return [
            P(bw=6.6, bh=10.0, nk=4.8, lean=-20, hx=-2.0, expr="hurt", capoff=(-1.0, -0.3), mouth="o"),
            P(bw=8.4, bh=7.0, nk=2.6, lean=-8, hx=-2.0, expr="dead", capfree=1, capabs=(2.0, -33.0), caprot=-45.0, mouth="o"),
            P(bw=9.4, bh=5.2, nk=1.4, lean=0, hx=-2.0, expr="dead", capfree=1, capabs=(5.0, -40.0), caprot=60.0, mouth="o"),
            P(bw=10.2, bh=4.4, nk=0.8, lean=0, hx=-2.5, expr="dead", capfree=1, capabs=(9.0, -26.0), caprot=210.0, mouth="o"),
            P(bw=10.6, bh=4.0, nk=0.5, lean=0, hx=-3.0, expr="dead", capfree=1, capabs=(11.0, -9.0), caprot=330.0, mouth="o"),
            P(bw=10.8, bh=3.8, nk=0.4, lean=0, hx=-3.0, expr="dead", capfree=1, capabs=(11.0, -7.0), caprot=345.0, mouth="o"),
        ][:n]
    raise KeyError(anim)


def _rot(v, deg):
    a = math.radians(deg)
    return (v[0] * math.cos(a) - v[1] * math.sin(a), v[0] * math.sin(a) + v[1] * math.cos(a))


def skeleton(p):
    lr = math.radians(p["lean"])
    td = (math.sin(lr), -math.cos(lr))
    pivot = (G[0] + p["hx"], G[1] - p["lift"] - 1.8)   # body hovers a hair above the planted stubby feet
    bulb = (pivot[0] + td[0] * p["bh"], pivot[1] + td[1] * p["bh"])
    neck_len = p["bh"] + p["nk"]
    neck = (pivot[0] + td[0] * neck_len, pivot[1] + td[1] * neck_len)
    top = (pivot[0] + td[0] * (neck_len + p["nr"] * 0.7), pivot[1] + td[1] * (neck_len + p["nr"] * 0.7))
    face_h = p["bh"] * 0.95
    off = _rot((0.0, 0.0), p["lean"])
    face = (pivot[0] + td[0] * face_h + off[0], pivot[1] + td[1] * face_h + off[1])
    return {"pivot": pivot, "bulb": bulb, "neck": neck, "top": top, "face": face, "lean": p["lean"],
            "footn": (G[0] + p["ff"][0], G[1] + p["ff"][1]), "footf": (G[0] + p["bf"][0], G[1] + p["bf"][1])}


def simulate(sks, poses_, loop):
    anchors, rests = [], []
    for s in sks:
        lr = math.radians(s["lean"])
        a = s["top"]
        anchors.append(a)
        rests.append([(a[0] + math.sin(lr) * 7.6, a[1] - math.cos(lr) * 7.6)])
    res = simulate_chain(anchors, rests, stiffness=0.20, damping=0.70, gravity=0.38, loop=loop)
    return [{"cap": r} for r in res]


def _mix(a, b, t):
    return "#%02X%02X%02X" % tuple(int(round(x + (y - x) * t)) for x, y in zip(hexc(a), hexc(b)))


def draw(sk, chains, p):
    mats = dict(MATERIALS)
    mats["cap"] = (_mix(CAP, HOT, p["glow"]), True)
    cv = Canvas(CELL, mats)
    xs, ys = cv.xs, cv.ys
    piv, bulb, neck, top = sk["pivot"], sk["bulb"], sk["neck"], sk["top"]
    # stubby feet (planted): drawn first so the body overlaps them
    for tag, grp in (("footf", "footB"), ("footn", "footF")):
        f = sk[tag]
        cv.paint("foot", Mask(CELL).ellipse((f[0] + 0.6, f[1] - 1.8), 3.0, 2.0), group=grp, k=3, deep=True)
    # body: bulb + neck
    body = Mask(CELL).ellipse(bulb, p["bw"], p["bh"], sk["lean"])
    cv.paint("stem", body, group="body", k=5)
    nk = Mask(CELL).ellipse(neck, p["bw"] * 0.86, p["nr"], sk["lean"])
    cv.paint("stem", nk.array(), group="body", k=5)
    # cap (spring driven, or flying free when knocked off)
    if p["capfree"] >= 0.5:
        cx, cy = G[0] + p["capabs"][0], G[1] + p["capabs"][1]
        tilt = p["caprot"]
    else:
        cp = chains["cap"][1]
        cx, cy = cp[0] + p["capoff"][0], cp[1] + p["capoff"][1]
        spring = math.degrees(math.atan2(cp[0] - top[0], -(cp[1] - top[1])))
        tilt = sk["lean"] * 0.45 + max(-14.0, min(14.0, (spring - sk["lean"]) * 0.6)) + p["caprot"]
    t = math.radians(tilt)
    dx, dy = xs - cx, ys - cy
    lx = dx * math.cos(t) + dy * math.sin(t)
    ly = -dx * math.sin(t) + dy * math.cos(t)
    cap = ((lx / 14.2) ** 2 + (ly / 9.8) ** 2 <= 1.0) & (ly < 1.4)
    gills = ((lx / 12.9) ** 2 + ((ly - 0.8) / 3.6) ** 2 <= 1.0) & (ly >= -0.6)
    cv.paint("gills", gills & ~cap, group="gills", k=3, deep=True, hi=False)
    # a lip: darker rim row under the cap edge reads as thickness
    cv.paint("cap", cap, group="cap", k=6, cast=4)
    spots = (Mask(CELL).array() & False)
    for (sx, sy, r) in ((-7.0, -4.5, 2.5), (-1.0, -7.2, 2.1), (4.2, -6.0, 3.0), (9.6, -2.2, 1.9), (-9.5, -0.6, 1.4), (1.6, -2.0, 1.3)):
        gx = cx + sx * math.cos(t) - sy * math.sin(t)
        gy = cy + sx * math.sin(t) + sy * math.cos(t)
        spots |= Mask(CELL).circle((gx, gy), r).array()
    cv.paint("spot", spots & cap, group="cap", k=3, deep=False)
    buf = cv.finish(NO_SEAM)
    # ---- face (painted at final resolution on the stem) ----
    ok = {cv.matidx["stem"]}
    fx, fy = int(round(sk["face"][0])), int(round(sk["face"][1])) - 1
    eyes(buf, ok, fx, fy, p["expr"], 3, 4, 4)
    mouth = p["mouth"]
    my = fy + 5
    pink, dark = (214, 112, 120), (96, 40, 52)
    if p["expr"] in ("neutral", "blink"):
        for dx, dy in ((-1, 0), (0, 1), (1, 1), (2, 0)):
            put(buf, fx + dx, my + dy - 1, dark, ok)
        for dx in (-5, 5):
            put(buf, fx + dx, fy + 4, pink, ok)
    elif mouth == "open":
        for dx in range(-1, 3):
            for dy in range(0, 2):
                put(buf, fx + dx, my + dy, dark, ok)
        put(buf, fx, my + 1, pink, ok)
        put(buf, fx + 1, my + 1, pink, ok)
    elif mouth == "grit":
        for dx in range(-2, 4):
            put(buf, fx + dx, my + 1, dark, ok)
        for dx in (-1, 1, 3):
            put(buf, fx + dx, my + 1, (250, 244, 228), ok)
    elif mouth == "o":
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            put(buf, fx + dx, my + dy, dark, ok)
    else:
        for dx in range(0, 2):
            put(buf, fx + dx, my + 1, dark, ok)
    sk["_cap"] = (cx, cy, tilt)
    return cv, buf


def anchors(sk):
    cx, cy, tilt = sk.get("_cap", (sk["top"][0], sk["top"][1] - 7, 0.0))
    t = math.radians(tilt)
    tip = (cx + 12.5 * math.cos(t), cy + 12.5 * math.sin(t) - 1.0)
    return {"hand": sk["top"], "hand_dir": (math.cos(t), math.sin(t)), "off_hand": sk["pivot"], "head": (cx, cy),
            "chest": sk["bulb"], "weapon_tip": tip}

"""Capmook v3 - a grumpy walking toadstool, arcade hi-bit. ~34 px tall. Faces right (mirrored in-engine).

Construction: one egg-shaped stem pivoting around the planted feet (squash, lean and crouch never lift
the feet off the floor) with a cap that sits ON the stem and jiggles on a spring. Two stubby boots.
Hand-authored 5-tone ramps with hue shifts (warm lights, violet shadows). No glow, smear or dither is
drawn here: the engine adds telegraphs and the windup tint.
"""
import math

from engine import Canvas, Mask, simulate_chain
from chars._cute import eyes, put

CELL = 64
HOLD_PULSE = 0            # held frames stay exactly on their key (springs would swing the cap)
G = (32.0, 59.0)
CAP_RX, CAP_RY = 12.6, 8.8
MATERIALS = {
    "stem": ("#E9D6B4", False, ["#4F3454", "#9C7C86", "#E9D6B4", "#F8EAD0", "#FFFAF0"]),
    "cap": ("#D03C40", True, ["#3F1030", "#862236", "#D03C40", "#EE6A4C", "#FFB890"]),
    "spot": ("#F8ECD6", False, ["#7E5E78", "#CDB1B0", "#F8ECD6", "#FFF6E4", "#FFFFFF"]),
    "gills": ("#B98263", False, ["#36202E", "#744C4E", "#B98263", "#D9A67A", "#EFC896"]),
    "foot": ("#8A5038", False, ["#261430", "#523040", "#8A5038", "#B07050", "#D89A70"]),
}
NO_SEAM = {("cap", "gills"), ("gills", "body"), ("cap", "spots"), ("footF", "body"), ("footB", "body")}

DEFAULT = dict(hx=0.0, lift=0.0, lean=0.0, bw=6.6, bh=10.6, ff=(3.0, 0.0), bf=(-3.2, 0.0),
               capoff=(0.0, 0.0), capabs=(0.0, 0.0), capfree=0.0, caprot=0.0, expr="neutral", mouth="smile")


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
        # slow breathing: stem swells while it shortens, cap bobs a touch behind, one slow blink
        v = [(0.0, 6.6, 10.6), (0.2, 6.75, 10.45), (0.55, 6.95, 10.2), (0.7, 7.0, 10.1), (0.4, 6.85, 10.3), (0.1, 6.7, 10.5)]
        return [P(bw=b, bh=h, lean=(-1.2 if i in (2, 3) else 0.0), expr="blink" if i == 4 else "neutral",
                  capoff=(0.0, 0.25 * d * 4)) for i, (d, b, h) in enumerate(v)][:n]
    if anim == "walk":     # waddle: lean into each step, body drops on contact, boots planted
        out = []
        for i in range(n):
            t = i / n
            ff, bf = _foot(t, 3.4, 2.4), _foot(t + 0.5, 3.4, 2.4)
            down = 0.5 + 0.5 * math.cos(4 * math.pi * t)          # 1 at foot contact
            out.append(P(lean=5.5 * math.sin(2 * math.pi * t), bw=6.6 + 0.4 * down, bh=10.6 - 0.8 * down,
                         ff=ff, bf=bf, hx=0.7 * math.sin(2 * math.pi * t), capoff=(0.0, 0.5 * down),
                         expr="neutral"))
        return out
    if anim == "windup":    # squat, shake and glare
        return [
            P(bw=7.4, bh=9.2, lean=-5, expr="angry", ff=(3.3, 0), bf=(-3.5, 0), capoff=(0, 0.6), mouth="grit", ease="inout"),
            P(bw=8.2, bh=8.0, lean=-10, hx=-0.9, expr="angry", ff=(3.7, 0), bf=(-3.9, 0), capoff=(0.0, 1.2), mouth="grit"),
            P(bw=8.7, bh=7.3, lean=-13, hx=0.9, expr="angry", ff=(4.0, 0), bf=(-4.2, 0), capoff=(-0.4, 1.6), mouth="grit"),
            P(bw=8.9, bh=7.0, lean=-15, hx=-0.5, expr="angry", ff=(4.1, 0), bf=(-4.3, 0), capoff=(-0.6, 1.8), mouth="grit"),
        ][:n]
    if anim == "headbutt":
        return [
            P(bw=8.9, bh=7.0, lean=-19, hx=-1.2, expr="angry", ff=(4.1, 0), bf=(-4.4, 0), capoff=(-1.0, 1.8), mouth="grit", ease="in"),
            P(bw=9.2, bh=6.6, lean=-24, hx=-2.6, expr="angry", ff=(4.3, 0), bf=(-4.6, 0), capoff=(-1.8, 2.0), mouth="grit", stop=True, ease="in"),
            P(bw=6.0, bh=11.6, lean=12, hx=1.8, lift=3.2, expr="angry", ff=(5.2, -1.6), bf=(-3.4, -2.6), mouth="open", ease="snap"),
            P(bw=6.2, bh=11.0, lean=26, hx=3.8, lift=1.0, expr="angry", ff=(7.0, 0), bf=(-2.4, -0.6), capoff=(2.2, 1.2), mouth="open"),
            P(bw=7.2, bh=9.6, lean=18, hx=3.8, expr="angry", ff=(6.0, 0), bf=(-3.0, 0), capoff=(1.4, 0.8), mouth="open"),
            P(bw=8.2, bh=8.0, lean=8, hx=2.6, expr="neutral", ff=(4.6, 0), bf=(-3.6, 0), capoff=(0.4, 1.2), mouth="grit"),
            P(bw=7.2, bh=9.8, lean=1, hx=1.0, expr="neutral", ff=(3.4, 0), bf=(-3.4, 0)),
        ][:n]
    if anim == "hurt":
        return [
            P(bw=6.0, bh=11.2, lean=-20, hx=-2.2, lift=0.8, expr="hurt", capoff=(-1.2, -0.4), ff=(3.6, -0.5), bf=(-4.2, 0), mouth="o", ease="snap"),
            P(bw=8.0, bh=8.6, lean=-14, hx=-2.6, expr="hurt", capoff=(-1.0, 0.8), mouth="o"),
            P(bw=7.2, bh=9.8, lean=-4, hx=-1.0, expr="hurt", mouth="o"),
        ][:n]
    if anim == "death":
        return [
            P(bw=6.0, bh=11.2, lean=-20, hx=-2.2, expr="hurt", capoff=(-1.2, -0.4), mouth="o", ease="snap"),
            P(bw=7.4, bh=8.4, lean=-9, hx=-2.2, expr="dead", capfree=1, capabs=(2.0, -30.0), caprot=-40.0, mouth="o"),
            P(bw=8.4, bh=6.4, lean=-2, hx=-2.4, expr="dead", capfree=1, capabs=(6.0, -37.0), caprot=55.0, mouth="o"),
            P(bw=9.4, bh=5.0, hx=-2.6, expr="dead", capfree=1, capabs=(10.0, -24.0), caprot=170.0, mouth="o"),
            P(bw=10.0, bh=4.2, hx=-3.0, expr="dead", capfree=1, capabs=(12.0, -9.0), caprot=305.0, mouth="o"),
            P(bw=10.2, bh=3.9, hx=-3.0, expr="dead", capfree=1, capabs=(12.0, -7.4), caprot=348.0, mouth="o"),
        ][:n]
    raise KeyError(anim)


def skeleton(p):
    lr = math.radians(p["lean"])
    td = (math.sin(lr), -math.cos(lr))
    pivot = (G[0] + p["hx"], G[1] - p["lift"] - 1.6)       # the egg rests just above the planted boots
    bulb = (pivot[0] + td[0] * p["bh"], pivot[1] + td[1] * p["bh"])
    top = (pivot[0] + td[0] * 2 * p["bh"], pivot[1] + td[1] * 2 * p["bh"])
    face = (pivot[0] + td[0] * p["bh"] * 0.98, pivot[1] + td[1] * p["bh"] * 0.98)
    return {"pivot": pivot, "bulb": bulb, "top": top, "face": face, "lean": p["lean"],
            "footn": (G[0] + p["ff"][0], G[1] + p["ff"][1]), "footf": (G[0] + p["bf"][0], G[1] + p["bf"][1])}


def simulate(sks, poses_, loop):
    anchors, rests = [], []
    for s in sks:
        lr = math.radians(s["lean"])
        a = s["top"]
        anchors.append(a)
        rests.append([(a[0] + math.sin(lr) * 1.0, a[1] - math.cos(lr) * 1.0)])    # cap rests right on the stem
    res = simulate_chain(anchors, rests, stiffness=0.22, damping=0.72, gravity=0.06, loop=loop)
    return [{"cap": r} for r in res]


def draw(sk, chains, p):
    cv = Canvas(CELL, MATERIALS)
    xs, ys = cv.xs, cv.ys
    piv, bulb, top = sk["pivot"], sk["bulb"], sk["top"]
    # planted boots first so the body overlaps them
    for tag, grp in (("footf", "footB"), ("footn", "footF")):
        f = sk[tag]
        cv.paint("foot", Mask(CELL).ellipse((f[0] + 0.7, f[1] - 1.9), 3.1, 2.0), group=grp, k=3, deep=True)
    body = Mask(CELL).ellipse(bulb, p["bw"], p["bh"], sk["lean"])
    cv.paint("stem", body, group="body", k=5)
    # cap: spring-driven, or flying free when knocked off
    if p["capfree"] >= 0.5:
        cx, cy = G[0] + p["capabs"][0], G[1] + p["capabs"][1]
        tilt = p["caprot"]
    else:
        cp = chains["cap"][1]
        cx, cy = cp[0] + p["capoff"][0], cp[1] + p["capoff"][1]
        spring = math.degrees(math.atan2(cp[0] - top[0], -(cp[1] - top[1]) + 1e-6))
        tilt = sk["lean"] * 0.55 + max(-10.0, min(10.0, spring * 0.4)) + p["caprot"]
    t = math.radians(tilt)
    reach = CAP_RX * abs(math.cos(t)) + CAP_RY * abs(math.sin(t)) + 1.8
    cx = max(reach, min(CELL - reach, cx))
    dx, dy = xs - cx, ys - cy
    lx = dx * math.cos(t) + dy * math.sin(t)
    ly = -dx * math.sin(t) + dy * math.cos(t)
    cap = ((lx / CAP_RX) ** 2 + (ly / CAP_RY) ** 2 <= 1.0) & (ly < 1.5)
    gills = ((lx / (CAP_RX - 1.3)) ** 2 + ((ly - 0.9) / 3.4) ** 2 <= 1.0) & (ly >= -0.6)
    cv.paint("gills", gills & ~cap, group="gills", k=3, deep=True, hi=False)
    cv.paint("cap", cap, group="cap", k=6, cast=4)
    spots = Mask(CELL).array() & False
    for (sx, sy, r) in ((-6.6, -3.6, 2.2), (-1.2, -6.2, 1.9), (3.8, -5.0, 2.6), (8.6, -1.6, 1.6), (-9.0, -0.4, 1.2), (1.4, -1.4, 1.1)):
        gx = cx + sx * math.cos(t) - sy * math.sin(t)
        gy = cy + sx * math.sin(t) + sy * math.cos(t)
        spots |= Mask(CELL).circle((gx, gy), r).array()
    cv.paint("spot", spots & cap, group="cap", k=3, deep=False)
    buf = cv.finish(NO_SEAM)
    # ---- face (painted at final resolution on the stem, below the cap rim) ----
    ok = {cv.matidx["stem"]}
    fx, fy = int(round(sk["face"][0])), int(round(sk["face"][1])) - 1
    eyes(buf, ok, fx, fy, p["expr"], 3, 4, 4)
    my = fy + 5
    pink, dark = (222, 118, 126), (92, 38, 52)
    mouth = p["mouth"]
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
    cx, cy, tilt = sk.get("_cap", (sk["top"][0], sk["top"][1] - 3, 0.0))
    t = math.radians(tilt)
    tip = (cx + (CAP_RX - 1.0) * math.cos(t), cy + (CAP_RX - 1.0) * math.sin(t) - 1.0)
    return {"hand": sk["top"], "hand_dir": (math.cos(t), math.sin(t)), "off_hand": sk["pivot"], "head": (cx, cy),
            "chest": sk["bulb"], "weapon_tip": tip}

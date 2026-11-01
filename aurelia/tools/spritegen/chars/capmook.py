"""Capmook — a walking toadstool. ~36 px tall. Faces right (mirrored in-engine)."""
import math

from engine import Canvas, Mask, paint_face, simulate_chain

CELL = 64
G = (32.0, 59.0)
MATERIALS = {
    "stem": ("#EBD9B4", False), "cap": ("#D8403A", True), "spot": ("#F6EBD2", False),
    "gills": ("#C9A97A", False), "foot": ("#6B4630", False),
}
HOT = "#FF9A2E"
NO_SEAM = {("cap", "gills"), ("gills", "body")}

DEFAULT = dict(hx=0.0, hy=0.0, lean=0.0, bl=10.0, br=6.2, ff=(3.0, 0.0), bf=(-3.5, 0.0),
               capoff=(0.0, 0.0), glow=0.0, expr="neutral", wind=0.0)


def P(**kw):
    d = dict(DEFAULT)
    d.update(kw)
    return d


def poses(anim, n):
    if anim == "idle":
        return [P(), P(hy=0.8, br=6.4), P(hy=1.3, br=6.6, bl=9.6), P(hy=0.5, expr="blink")][:n]
    if anim == "walk":
        return [P(lean=5, hy=0.5, ff=(5, -1.5), bf=(-5, 0)), P(lean=1, hy=-0.4, ff=(2, 0), bf=(-2, 0)),
                P(lean=-4, hy=0.5, ff=(-5, 0), bf=(5, -1.5)), P(lean=1, hy=-0.4, ff=(-2, 0), bf=(2, 0))][:n]
    if anim == "windup":
        return [P(hy=2.0, lean=-6, br=6.8, bl=9, expr="angry"),
                P(hy=3.5, lean=-14, br=7.2, bl=8.2, glow=1.0, expr="angry", ff=(2, 0), bf=(-4, 0)),
                P(hy=4.0, lean=-17, br=7.4, bl=8.0, glow=1.0, expr="angry", ff=(2, 0), bf=(-4, 0))][:n]
    if anim == "headbutt":
        return [P(hy=3.5, lean=-20, br=7.4, bl=8, glow=1, expr="angry", bf=(-5, 0)),
                P(hx=3.0, hy=1.0, lean=16, bl=11, br=5.8, glow=1, expr="angry", ff=(7, -1), bf=(-5, 0)),
                P(hx=7.0, hy=1.0, lean=34, bl=11.5, br=5.6, glow=1, expr="angry", ff=(9, 0), bf=(-4, 0)),
                P(hx=5.0, hy=1.0, lean=20, glow=0.5, expr="angry", ff=(7, 0), bf=(-4, 0)),
                P(hx=2.0, lean=5, expr="neutral")][:n]
    if anim == "hurt":
        return [P(hx=-3.0, hy=1.5, lean=-22, br=6.9, bl=8.5, expr="hurt", capoff=(-1.5, 0.5)),
                P(hx=-1.5, hy=1.0, lean=-10, br=6.5, expr="hurt")][:n]
    if anim == "death":
        return [P(hx=-3.0, hy=1.5, lean=-22, br=6.9, bl=8.5, expr="hurt"),
                P(hx=-2.0, hy=4.0, lean=-8, br=8.2, bl=6.0, expr="dead", capoff=(2.0, -6.0)),
                P(hx=-1.0, hy=6.0, lean=0, br=9.0, bl=4.5, expr="dead", capoff=(4.0, -11.0)),
                P(hx=0.0, hy=7.5, lean=0, br=9.6, bl=3.2, expr="dead", capoff=(6.0, -3.0)),
                P(hx=0.0, hy=8.0, lean=0, br=9.8, bl=3.0, expr="dead", capoff=(7.0, 1.0))][:n]
    raise KeyError(anim)


def skeleton(p):
    lr = math.radians(p["lean"])
    hip = (G[0] + p["hx"], min(G[1] - 6.0 + p["hy"], G[1] - p["br"] * 0.97))
    td = (math.sin(lr), -math.cos(lr))
    neck = (hip[0] + td[0] * p["bl"], hip[1] + td[1] * p["bl"])
    return {"hip": hip, "neck": neck, "lean": p["lean"],
            "footn": (G[0] + p["ff"][0], G[1] + p["ff"][1]), "footf": (G[0] + p["bf"][0], G[1] + p["bf"][1])}


def simulate(sks, poses_, loop):
    anchors, rests = [], []
    for s in sks:
        lr = math.radians(s["lean"])
        a = s["neck"]
        anchors.append(a)
        rests.append([(a[0] + math.sin(lr) * 8.0, a[1] - math.cos(lr) * 8.0)])
    res = simulate_chain(anchors, rests, stiffness=0.22, damping=0.72, gravity=0.35, loop=loop)
    return [{"cap": r} for r in res]


def draw(sk, chains, p):
    mats = dict(MATERIALS)
    if p["glow"] > 0.4:
        mats["cap"] = (HOT, True)
    cv = Canvas(CELL, mats)
    xs, ys = cv.xs, cv.ys
    hip, neck = sk["hip"], sk["neck"]
    # feet
    for tag, grp in (("footf", "legB"), ("footn", "legF")):
        f = sk[tag]
        cv.paint("foot", Mask(CELL).capsule((f[0] - 0.3, f[1] - 3.2), (f[0] + 0.8, f[1] - 1.0), 2.0, 2.3)
                 .capsule((f[0] - 1.0, f[1] - 1.0), (f[0] + 2.4, f[1] - 0.8), 1.8, 1.6), group=grp, k=3)
    # body
    body = Mask(CELL).capsule(hip, neck, p["br"], p["br"] * 0.92)
    cv.paint("stem", body, group="body", k=5)
    # cap (spring-driven)
    cp = chains["cap"][1]
    cx, cy = cp[0] + p["capoff"][0], cp[1] + p["capoff"][1]
    spring = math.degrees(math.atan2(cp[0] - neck[0], -(cp[1] - neck[1])))
    tilt = sk["lean"] * 0.45 + max(-14.0, min(14.0, (spring - sk["lean"]) * 0.6))
    t = math.radians(tilt)
    dx, dy = xs - cx, ys - cy
    lx = dx * math.cos(t) + dy * math.sin(t)
    ly = -dx * math.sin(t) + dy * math.cos(t)
    cap = ((lx / 15.0) ** 2 + (ly / 10.5) ** 2 <= 1.0) & (ly < 1.5)
    gills = ((lx / 14.0) ** 2 + ((ly - 1.0) / 3.6) ** 2 <= 1.0) & (ly >= -1.0)
    cv.paint("gills", gills & ~cap, group="gills", k=3, deep=True, hi=False)
    cv.paint("cap", cap, group="cap", k=6, cast=4)
    spots = np_zero(cap)
    for (sx, sy, r) in ((-6.0, -5.0, 2.5), (3.0, -7.0, 3.1), (9.0, -3.0, 1.9), (-1.5, -2.0, 1.3)):
        gx = cx + sx * math.cos(t) - sy * math.sin(t)
        gy = cy + sx * math.sin(t) + sy * math.cos(t)
        spots |= Mask(CELL).circle((gx, gy), r).array()
    cv.paint("spot", spots & cap, group="cap", k=3, deep=False)
    buf = cv.finish(NO_SEAM)
    face_c = (hip[0] - 2.4 + p["hx"] * 0.0, hip[1] - 3.0)
    paint_face(buf, cv, face_c, p["expr"], skin="stem")
    return cv, buf


def np_zero(a):
    import numpy as np
    return np.zeros_like(a)


def anchors(sk):
    return {"hand": sk["neck"], "hand_dir": (1.0, 0.0), "off_hand": sk["hip"], "head": sk["neck"],
            "chest": sk["hip"], "weapon_tip": (sk["neck"][0] + 9.0, sk["neck"][1] - 4.0)}

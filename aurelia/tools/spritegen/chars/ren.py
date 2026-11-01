"""Ren — the wandering blade. 46 px tall chibi hero, faces right (mirrored in-engine)."""
import math

from engine import (Canvas, Mask, grid, ik2, paint_face, simulate_chain, smooth)

MATERIALS = {
    "skin": ("#F2C6A0", False),
    "hair": ("#A8502E", True),
    "scarf": ("#2FA79A", False),
    "tunic": ("#EDE3C8", False),
    "sash": ("#E07A2E", False),
    "leather": ("#6B4A33", False),
    "metal": ("#B9C4CC", True),
    "pants": ("#4D5C7E", False),
    "boots": ("#5C3B2B", False),
}
CELL = 64
G = (32.0, 59.0)  # ground point inside the cell
HIP_H = 17.0
NO_SEAM = {("hair", "head"), ("scarf", "head"), ("scarf", "torso"), ("hair", "scarf"),
           ("tail1", "hair"), ("tail1", "torso"), ("tail2", "torso"), ("tail1", "scarf"),
           ("tail2", "scarf"), ("pony", "hair"), ("pony", "head")}

DEFAULT = dict(hx=0.0, hy=0.0, lean=0.0, head=0.0, ff=(3.0, 0.0), bf=(-3.0, 0.0),
               nh=(3.5, 9.5), fh=(-2.5, 9.0), sw=158.0, expr="neutral", wind=0.0)


def P(**kw):
    d = dict(DEFAULT)
    d.update(kw)
    return d


# ---------------------------------------------------------------- animation


def _foot(t, stride, lift):
    t %= 1.0
    if t < 0.5:
        return (stride * (1 - 4 * t), 0.0)
    u = (t - 0.5) * 2
    return (-stride + 2 * stride * smooth(u), -lift * math.sin(math.pi * u))


def _locomotion(n, stride, lift, bob, lean, arms, wind, sw, hand_y):
    out = []
    for i in range(n):
        t = i / n
        ff, bf = _foot(t, stride, lift), _foot(t + 0.5, stride, lift)
        s = -ff[0] / stride
        out.append(P(
            hy=bob * math.cos(4 * math.pi * t) + bob, lean=lean, ff=ff, bf=bf,
            nh=(3.5 + arms * 0.5 * s, hand_y - 0.6 * abs(s)),
            fh=(-2.5 - arms * s, hand_y - 0.4 * abs(s)), sw=sw, wind=wind,
            expr="neutral"))
    return out


def poses(anim, n):
    if anim == "idle":
        return [P(hy=0.0, expr="neutral"), P(hy=0.6, head=1.5, nh=(3.5, 9.8), fh=(-2.5, 9.4)),
                P(hy=1.0, head=2.5, lean=1.0, nh=(3.6, 10.2), fh=(-2.5, 9.8), expr="neutral"),
                P(hy=0.4, head=1.0, expr="blink")][:n]
    if anim == "walk":
        return _locomotion(n, 4.6, 3.2, 0.6, 3.0, 5.0, -0.03, 160, 9.0)
    if anim == "run":
        return _locomotion(n, 7.0, 5.5, 1.1, 14.0, 7.0, -0.2, 212, 7.0)
    if anim == "dash":
        return [
            P(hy=2.5, lean=14, ff=(-5, 0), bf=(-9, -1), nh=(-3, 7), fh=(-3, 7), sw=205, expr="focus", wind=-0.1),
            P(hx=3, hy=3.5, lean=34, ff=(10, -1), bf=(-13, -4), nh=(-6, 6), fh=(-5, 6), sw=235, expr="focus", wind=-0.35),
            P(hx=2, hy=2.5, lean=26, ff=(8, 0), bf=(-9, -2), nh=(-5, 7), fh=(-4, 7), sw=225, expr="focus", wind=-0.3),
            P(hy=1, lean=8, ff=(5, 0), bf=(-4, 0), nh=(2, 9), fh=(-3, 9), sw=180, wind=-0.1),
        ][:n]
    if anim == "jump":
        return [
            P(hy=3.0, lean=4, ff=(4, 0), bf=(-4, 0), nh=(2, 8), fh=(-3, 8), sw=170),
            P(hy=-6.0, lean=-3, ff=(5, -6), bf=(-3, -4), nh=(6, 2), fh=(-6, 3), sw=120, expr="happy"),
            P(hy=3.5, lean=6, ff=(5, 0), bf=(-5, 0), nh=(3, 8), fh=(-3, 8), sw=165),
        ][:n]
    if anim == "sword.1":
        return [
            P(hy=1.5, lean=-6, ff=(5, 0), bf=(-5, 0), nh=(-4, 4), fh=(1, 8), sw=-50, expr="focus"),
            P(hy=2.0, lean=-11, hx=-1.5, ff=(5, 0), bf=(-6, 0), nh=(-6, -1), fh=(2, 7), sw=-78, expr="focus"),
            P(hx=2.5, hy=2.0, lean=17, ff=(10, 0), bf=(-6, 0), nh=(10, 2), fh=(-4, 6), sw=82, expr="angry"),
            P(hx=1.5, hy=1.5, lean=12, ff=(8, 0), bf=(-5, 0), nh=(8, 8), fh=(-4, 6), sw=128, expr="focus"),
            P(hx=0.5, hy=0.5, lean=4, ff=(5, 0), bf=(-3, 0), nh=(4, 9), fh=(-3, 9), sw=152),
        ][:n]
    if anim == "sword.2":
        return [
            P(hy=2.5, lean=8, ff=(6, 0), bf=(-6, 0), nh=(6, 10), fh=(-2, 7), sw=172, expr="focus"),
            P(hy=2.5, lean=10, hx=0.5, ff=(7, 0), bf=(-6, 0), nh=(8, 10), fh=(-3, 7), sw=150, expr="focus"),
            P(hx=2, hy=1.5, lean=-2, ff=(9, 0), bf=(-5, 0), nh=(10, -4), fh=(-5, 6), sw=38, expr="angry"),
            P(hx=1, hy=0.5, lean=-5, ff=(7, 0), bf=(-4, 0), nh=(5, -9), fh=(-4, 7), sw=-12, expr="focus"),
            P(hx=0.5, lean=2, ff=(5, 0), bf=(-3, 0), nh=(4, 6), fh=(-3, 9), sw=120),
        ][:n]
    if anim == "sword.3":
        return [
            P(hy=3.5, lean=-6, ff=(5, 0), bf=(-5, 0), nh=(3, 9), fh=(-3, 8), sw=150, expr="focus"),
            P(hy=-3.0, lean=-8, ff=(3, -4), bf=(-2, -3), nh=(1, -7), fh=(-3, -5), sw=5, expr="focus"),
            P(hy=-4.5, lean=-3, ff=(4, -5), bf=(-2, -4), nh=(3, -8), fh=(-2, -7), sw=30, expr="angry"),
            P(hx=3, hy=2.0, lean=25, ff=(11, 0), bf=(-4, 0), nh=(11, 6), fh=(-3, 4), sw=112, expr="angry"),
            P(hx=2, hy=2.5, lean=18, ff=(9, 0), bf=(-4, 0), nh=(9, 9), fh=(-3, 7), sw=138, expr="focus"),
            P(hx=0.5, hy=1.0, lean=6, ff=(5, 0), bf=(-3, 0), nh=(5, 9), fh=(-3, 9), sw=154),
        ][:n]
    if anim == "cast":
        return [
            P(hy=1.0, lean=-4, nh=(1, 8), fh=(3, 6), sw=175, expr="focus"),
            P(hy=1.0, lean=-2, nh=(-2, 8), fh=(8, 1), sw=190, expr="focus"),
            P(hx=1.0, hy=0.5, lean=9, ff=(6, 0), bf=(-5, 0), nh=(-2, 8), fh=(13, -1), sw=198, expr="angry"),
            P(hx=0.5, hy=0.5, lean=7, ff=(5, 0), bf=(-4, 0), nh=(-2, 8), fh=(12, -1), sw=198, expr="focus"),
            P(lean=2, nh=(3, 9), fh=(-2, 9), sw=165),
        ][:n]
    if anim == "hurt":
        return [
            P(hx=-2.0, hy=1.0, lean=-17, head=-12, ff=(5, -0.5), bf=(-5, 0), nh=(-3, 6), fh=(-5, 4), sw=205, expr="hurt"),
            P(hx=-1.0, hy=1.5, lean=-9, head=-5, ff=(4, 0), bf=(-4, 0), nh=(0, 8), fh=(-4, 7), sw=190, expr="hurt"),
        ][:n]
    if anim == "death":
        return [
            P(hx=-2.0, hy=1.0, lean=-24, head=-12, ff=(5, -0.5), bf=(-3, 0), nh=(-3, 6), fh=(-5, 4), sw=205, expr="hurt"),
            P(hx=2.0, hy=5.0, lean=-48, head=-6, ff=(7, 0), bf=(-1, 0), nh=(-4, 5), fh=(-6, 3), sw=215, expr="dead"),
            P(hx=6.0, hy=8.5, lean=-72, head=0, ff=(14, -2), bf=(10, -1), nh=(-2, 5), fh=(-6, 5), sw=235, expr="dead"),
            P(hx=10.0, hy=9.3, lean=-88, head=2, ff=(21, -2.5), bf=(17, -1.5), nh=(-3, 5), fh=(-5, 5), sw=250, expr="dead"),
            P(hx=10.0, hy=9.3, lean=-90, head=2, ff=(22, -2.0), bf=(18, -1.5), nh=(-3, 6), fh=(-5, 6), sw=250, expr="dead"),
        ][:n]
    raise KeyError(anim)


# ----------------------------------------------------------------- skeleton


def _rot(v, deg):
    a = math.radians(deg)
    return (v[0] * math.cos(a) - v[1] * math.sin(a), v[0] * math.sin(a) + v[1] * math.cos(a))


def skeleton(p):
    lean = p["lean"]
    lr = math.radians(lean)
    hip = (G[0] + p["hx"], G[1] - HIP_H + p["hy"])
    td = (math.sin(lr), -math.cos(lr))
    perp = (math.cos(lr), math.sin(lr))
    sh = (hip[0] + td[0] * 11.0, hip[1] + td[1] * 11.0)
    nsh = (sh[0] + perp[0] * 1.3, sh[1] + perp[1] * 1.3)
    fsh = (sh[0] - perp[0] * 2.2, sh[1] - perp[1] * 2.2)
    hr = math.radians(lean + p["head"])
    head = (sh[0] + math.sin(hr) * 8.2 + perp[0] * 0.8, sh[1] - math.cos(hr) * 8.2 + perp[1] * 0.8)
    sk = {"hip": hip, "sh": sh, "nsh": nsh, "fsh": fsh, "head": head, "lean": lean}
    # legs
    for tag, hp, foot in (("n", (hip[0] + 1.0, hip[1]), p["ff"]), ("f", (hip[0] - 1.0, hip[1]), p["bf"])):
        ankle = (G[0] + foot[0], G[1] + foot[1] - 1.5)
        knee, ankle = ik2(hp, ankle, 8.6, 8.6, -1)
        sk["hip" + tag], sk["knee" + tag], sk["ankle" + tag] = hp, knee, ankle
    # arms (hand targets are authored in the torso frame)
    for tag, s, rel in (("n", nsh, p["nh"]), ("f", fsh, p["fh"])):
        off = _rot(rel, lean)
        elbow, hand = ik2(s, (s[0] + off[0], s[1] + off[1]), 6.6, 6.6, 1)
        sk["elbow" + tag], sk["hand" + tag] = elbow, hand
    sa = math.radians(p["sw"])
    sk["sdir"] = (math.sin(sa), -math.cos(sa))
    sk["tip"] = (sk["handn"][0] + sk["sdir"][0] * 15.0, sk["handn"][1] + sk["sdir"][1] * 15.0)
    return sk


def chain_specs(sk, p):
    lr = sk["lean"]
    def rests(anchor, offs):
        return [(anchor[0] + _rot(o, lr)[0], anchor[1] + _rot(o, lr)[1]) for o in offs]
    a1 = (sk["sh"][0] - 3.0 * math.cos(math.radians(lr)), sk["sh"][1] - 3.0 * math.sin(math.radians(lr)) - 0.3)
    a2 = (a1[0] + 0.5, a1[1] + 1.2)
    ap = (sk["head"][0] - 6.0, sk["head"][1] - 3.2)
    return {
        "tail1": (a1, rests(a1, [(-3, 1.2), (-6, 2.8), (-9, 5.0), (-11.5, 7.5)])),
        "tail2": (a2, rests(a2, [(-2.5, 2.6), (-4.5, 5.5), (-5.5, 8.6), (-5.5, 11.5)])),
        "pony": (ap, rests(ap, [(-2.4, 2.0), (-4.2, 4.8), (-4.6, 8.0)])),
    }


def simulate(sks, poses_, loop):
    """Run the spring chains over the display frames. Returns per frame dict."""
    specs = [chain_specs(s, p) for s, p in zip(sks, poses_)]
    wind = sum(p["wind"] for p in poses_) / len(poses_)
    out = [dict() for _ in sks]
    cfg = {"tail1": (0.10, 0.80, 0.16), "tail2": (0.12, 0.78, 0.22), "pony": (0.16, 0.78, 0.20)}
    for name, (st, dm, gr) in cfg.items():
        anchors = [sp[name][0] for sp in specs]
        rests = [sp[name][1] for sp in specs]
        res = simulate_chain(anchors, rests, stiffness=st, damping=dm, gravity=gr, wind=wind, loop=loop)
        for i, pts in enumerate(res):
            out[i][name] = pts
    return out


# ---------------------------------------------------------------------- draw


def draw(sk, chains, p):
    cv = Canvas(CELL, MATERIALS)
    xs, ys = cv.xs, cv.ys
    lr = math.radians(sk["lean"])
    head = sk["head"]

    # secondary motion first (behind everything)
    cv.paint("scarf", Mask(CELL).ribbon(chains["tail1"], 2.6, 1.2), group="tail1", k=3, deep=False, hi=False)
    cv.paint("scarf", Mask(CELL).ribbon(chains["tail2"], 2.2, 1.0), group="tail2", k=3, deep=False, hi=False)
    cv.paint("hair", Mask(CELL).ribbon(chains["pony"], 2.4, 0.8), group="pony", k=3, deep=False)
    # back hair mass
    cv.paint("hair", Mask(CELL).circle((head[0] - 1.6, head[1] - 1.0), 8.0), group="hair", k=4)
    # far arm
    m = Mask(CELL).capsule(sk["fsh"], sk["elbowf"], 1.8, 1.6)
    cv.paint("tunic", m, group="armB", k=3)
    cv.paint("skin", Mask(CELL).capsule(sk["elbowf"], sk["handf"], 1.4, 1.3).circle(sk["handf"], 1.7), group="armB2", k=3)
    # far leg
    cv.paint("pants", Mask(CELL).capsule(sk["hipf"], sk["kneef"], 2.9, 2.4).capsule(sk["kneef"], sk["anklef"], 2.4, 1.8),
             group="legB", k=4)
    af = sk["anklef"]
    cv.paint("boots", Mask(CELL).capsule((af[0] - 0.4, af[1] - 0.3), (af[0] + 3.0, af[1] + 1.3), 2.1, 1.7), group="bootB", k=3)
    # torso + sash
    hip, sh = sk["hip"], sk["sh"]
    torso = Mask(CELL).capsule(hip, sh, 4.7, 4.3)
    cv.paint("tunic", torso, group="torso", k=5)
    sash = Mask(CELL).ellipse((hip[0] + math.sin(lr) * 1.6, hip[1] - math.cos(lr) * 1.6), 5.0, 1.9, sk["lean"])
    cv.paint("sash", sash.array() & torso.array(), group="torso", k=3, deep=False)
    # near leg
    cv.paint("pants", Mask(CELL).capsule(sk["hipn"], sk["kneen"], 3.0, 2.5).capsule(sk["kneen"], sk["anklen"], 2.5, 1.9),
             group="legF", k=4)
    an = sk["anklen"]
    cv.paint("boots", Mask(CELL).capsule((an[0] - 0.4, an[1] - 0.3), (an[0] + 3.2, an[1] + 1.4), 2.2, 1.8), group="bootF", k=3)
    # head
    face = Mask(CELL).circle(head, 7.4)
    cv.paint("skin", face, group="head", k=4, cast=4)
    fa = face.array()
    hx, hy = head
    # hair: fringe over forehead + side lock over the back of the head
    bang = (Mask(CELL).circle((hx - 0.8, hy - 2.7), 7.9).array() & fa & (ys < hy - 1.7 + 0.35 * (xs - hx)))
    side = fa & (xs < hx - 3.2)
    cv.paint("hair", bang | side, group="hair", k=4)
    cv.paint("hair", Mask(CELL).capsule((hx + 0.4, hy - 6.6), (hx + 3.3, hy - 10.2), 1.1, 0.4), group="hair", k=2, deep=False)
    # scarf collar
    collar = Mask(CELL).ellipse((sh[0] + 0.6, sh[1] - 0.3), 5.6, 2.4, sk["lean"])
    cv.paint("scarf", collar, group="scarf", k=3, cast=3)
    # near arm
    cv.paint("tunic", Mask(CELL).capsule(sk["nsh"], sk["elbown"], 1.9, 1.7), group="armF", k=3, cast=3)
    cv.paint("skin", Mask(CELL).capsule(sk["elbown"], sk["handn"], 1.4, 1.3).circle(sk["handn"], 1.8), group="armF2", k=3)
    # sword
    hn, d = sk["handn"], sk["sdir"]
    nx, ny = -d[1], d[0]
    grip = Mask(CELL).capsule((hn[0] - d[0] * 2.4, hn[1] - d[1] * 2.4), (hn[0] + d[0] * 0.8, hn[1] + d[1] * 0.8), 0.9, 0.9)
    cv.paint("leather", grip, group="sword", k=2, deep=False)
    g0 = (hn[0] + d[0] * 1.2, hn[1] + d[1] * 1.2)
    cv.paint("leather", Mask(CELL).capsule((g0[0] - nx * 2.4, g0[1] - ny * 2.4), (g0[0] + nx * 2.4, g0[1] + ny * 2.4), 0.8, 0.8),
             group="guard", k=2, deep=False, hi=False)
    b0 = (hn[0] + d[0] * 1.8, hn[1] + d[1] * 1.8)
    tip = sk["tip"]
    blade = Mask(CELL).poly([(b0[0] + nx * 1.4, b0[1] + ny * 1.4), (tip[0] + d[0] * 1.4, tip[1] + d[1] * 1.4),
                             (b0[0] - nx * 1.4, b0[1] - ny * 1.4)])
    cv.paint("metal", blade, group="blade", k=2, deep=False)

    buf = cv.finish(NO_SEAM)
    paint_face(buf, cv, head, p["expr"])
    return cv, buf


def anchors(sk):
    d = sk["sdir"]
    return {
        "hand": sk["handn"], "hand_dir": d, "off_hand": sk["handf"], "head": sk["head"],
        "chest": sk["sh"], "weapon_tip": sk["tip"],
    }

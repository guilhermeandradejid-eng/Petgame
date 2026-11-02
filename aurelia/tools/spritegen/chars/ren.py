"""Ren v4 - arcade hi-bit (KOF / Metal Slug proportions, ~1:4.6), 52 px tall in an 80x80 cell.

Rig
  * a pose is a dict of numbers: hip offset, spine lean/bend/twist, foot targets (+ pitch), near/far
    hand targets in the torso frame, weapon angle, grip mode (one / two handed), expression;
  * legs and arms are 2-bone IK chains with FIXED segment lengths and a pole vector (knees forward, elbows
    down/back) so elbows never flip; the hip is lowered automatically when a grounded foot would be
    out of reach; hands are attached to real grip points: the near hand IS the weapon grip, the far hand of
    a two-handed weapon slides along the shaft to the nearest reachable grip;
  * scarf tails, ponytail and hair locks are spring chains simulated on the dense timeline;
  * spins squash the body horizontally (Canvas.warp_x) and mirror it, the face is painted after the downsample.
"""
import math

from engine import Canvas, Mask, simulate_chain

CELL = 80
G = (40.0, 74.0)                 # feet row / centre column inside the cell
HIP_H = 23.8                     # standing hip height above the floor
THIGH = SHIN = 11.7
ANKLE_H = 2.0
TORSO_LO, TORSO_HI = 5.8, 7.6    # pelvis->waist, waist->shoulder line
HEAD_OFF = 8.3                   # shoulder line -> head centre
UARM, FARM = 8.8, 8.3            # upper arm / forearm (0.17 H, 0.16 H)
REACH_LEG = THIGH + SHIN
REACH_ARM = UARM + FARM

MATERIALS = {
    # name: (base hex, glossy, [deep, shade, base, light, highlight]) - hand-tuned, hue-shifted ramps
    "skin": ("#E8A07A", False, ["#6E3A4C", "#B8665E", "#E8A07A", "#F8C79C", "#FFE6C4"]),
    "skin_f": ("#C4805F", False, ["#58303F", "#90504E", "#C07A5C", "#D89C78", "#ECC09A"]),
    "hair": ("#B8512C", True, ["#3A1630", "#7A2F2E", "#B8512C", "#E27A38", "#FFB866"]),
    "scarf": ("#22A69A", False, ["#0E3A46", "#15667A", "#22A69A", "#5CD6B4", "#B6F6D6"]),
    "tunic": ("#EFE0C0", False, ["#665266", "#AE9C98", "#EFE0C0", "#FFF3D8", "#FFFFFF"]),
    "tunic_f": ("#B8A890", False, ["#4A3A52", "#85737A", "#B6A68E", "#D0C2A8", "#E8DCC4"]),
    "leather": ("#86502C", False, ["#2E1A22", "#5A3426", "#86502C", "#B87A3E", "#DEA25A"]),
    "pants": ("#4F5F98", False, ["#1C2040", "#343E6E", "#4F5F98", "#7486C0", "#A4B4E4"]),
    "pants_f": ("#3A4878", False, ["#141834", "#262E58", "#3A4878", "#566AA0", "#7E92C8"]),
    "boots": ("#5E3A2A", False, ["#20121C", "#402620", "#5E3A2A", "#84563A", "#AA7A4E"]),
    "bronze": ("#C07A2E", True, ["#3A1E24", "#7A4426", "#C07A2E", "#EAA840", "#FFF0A0"]),
    "steel": ("#9CACC8", True, ["#2A3050", "#56648C", "#9CACC8", "#D4E0F0", "#FFFFFF"]),
    "wood": ("#8A5A34", False, ["#2E1A1A", "#5A3422", "#8A5A34", "#B98450", "#DCAE72"]),
}

WEAPONS = ("sword", "spear", "axe")

DEFAULT = dict(
    weapon="sword", carry="hand", grip="one", span=11.0,
    hx=0.0, hy=0.0, lean=0.0, bend=0.0, twist=0.0, head=0.0,
    ff=(3.5, 0.0), bf=(-3.5, 0.0), fa=0.0, ba=0.0,
    nh=(5.0, 13.0), fh=(1.5, 13.5), sw=150.0, far_front=False,
    spin=0.0, expr="neutral", wind=0.0, autohip=True, kpole=(1.0, 0.12),
)


def P(**kw):
    d = dict(DEFAULT)
    d.update(kw)
    return d


def _rot(v, deg):
    a = math.radians(deg)
    return (v[0] * math.cos(a) - v[1] * math.sin(a), v[0] * math.sin(a) + v[1] * math.cos(a))


def _add(a, b, k=1.0):
    return (a[0] + b[0] * k, a[1] + b[1] * k)


def _dir(deg):
    """Angle convention: 0 = up, 90 = forward (right), 180 = down."""
    r = math.radians(deg)
    return (math.sin(r), -math.cos(r))


def _dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


# ------------------------------------------------------------------- IK with a pole

def ik_pole(root, target, l1, l2, pole, min_d=3.2, max_frac=0.985):
    """2-bone IK. Of the two mirror solutions choose the joint closer to the pole direction (so knees stay
    forward and elbows down/back). Returns (joint, end); segment lengths are exact."""
    dx, dy = target[0] - root[0], target[1] - root[1]
    raw = math.hypot(dx, dy)
    d = max(min(raw, (l1 + l2) * max_frac), max(abs(l1 - l2) + 0.3, min_d))
    if raw < 1e-6:
        ux, uy = 0.0, 1.0
    else:
        ux, uy = dx / raw, dy / raw
    end = (root[0] + ux * d, root[1] + uy * d)
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    mid = (root[0] + ux * a, root[1] + uy * a)
    cands = [(mid[0] + (-uy) * h * s, mid[1] + ux * h * s) for s in (1.0, -1.0)]
    best = max(cands, key=lambda j: (j[0] - mid[0]) * pole[0] + (j[1] - mid[1]) * pole[1])
    return best, end


# ------------------------------------------------------------------- weapons

def weapon_pts(kind, g0, d):
    """Key points of a weapon held with the grip at g0 and its axis along d (unit)."""
    n = (-d[1], d[0])

    def at(u, v=0.0):
        return (g0[0] + d[0] * u + n[0] * v, g0[1] + d[1] * u + n[1] * v)
    if kind == "sword":
        return {"at": at, "tip": at(19.8), "back": 4.0, "front": 19.8}
    if kind == "spear":
        return {"at": at, "tip": at(28.5), "back": 8.0, "front": 28.5}
    return {"at": at, "tip": at(27.0, 6.0), "back": 6.0, "front": 28.5}


# ------------------------------------------------------------------- skeleton

BOX = (3.0, 77.0, 3.0, G[1] - 0.4)      # keep the weapon tip inside the cell and above the floor


def clamp_dir(kind, hand, sw):
    """Rotate the weapon axis (nearest angle) so its tip / head / butt stay inside the cell and above the floor."""
    L = {"sword": 19.8, "spear": 28.5, "axe": 28.5}[kind]
    back = {"sword": 4.0, "spear": 8.0, "axe": 6.0}[kind]
    m = 6.5 if kind == "axe" else 0.0
    mf = 2.5 if kind == "axe" else 0.0         # the axe head may rest on the floor

    def ok(a):
        d = _dir(a)
        tip = (hand[0] + d[0] * L, hand[1] + d[1] * L)
        butt = (hand[0] - d[0] * back, hand[1] - d[1] * back)
        for q, mm in ((tip, m), (butt, 0.0)):
            if q[0] < BOX[0] + mm or q[0] > BOX[1] - mm or q[1] < BOX[2] + mm or q[1] > BOX[3] - (mf if q is tip else 0.0):
                return False
        return True
    if ok(sw):
        return sw
    for k in range(1, 91):
        for sgn in (1, -1):
            a = sw + sgn * k * 2.0
            if ok(a):
                return a
    return sw


def skeleton(p):
    lean = p["lean"]
    lr = math.radians(lean)
    ub = lean + p["bend"]
    ur = math.radians(ub)
    hip = [G[0] + p["hx"], G[1] - HIP_H + p["hy"]]
    perp = (math.cos(lr), math.sin(lr))
    nhip_off, fhip_off = 0.9, -1.4
    ank_n = (G[0] + p["ff"][0], G[1] + p["ff"][1] - ANKLE_H)
    ank_f = (G[0] + p["bf"][0], G[1] + p["bf"][1] - ANKLE_H)
    if p["autohip"]:
        for ank, off, fy in ((ank_n, nhip_off, p["ff"][1]), (ank_f, fhip_off, p["bf"][1])):
            if fy >= -0.6:       # grounded foot: the hip must be low enough for the leg to reach it
                hj_x = hip[0] + perp[0] * off
                dxx = ank[0] - hj_x
                dy_max = math.sqrt(max((REACH_LEG * 0.975) ** 2 - dxx * dxx, 1.0))
                hip[1] = max(hip[1], ank[1] - dy_max - perp[1] * off)
    hip = (hip[0], hip[1])
    td = (math.sin(lr), -math.cos(lr))
    waist = (hip[0] + td[0] * TORSO_LO, hip[1] + td[1] * TORSO_LO)
    tu = (math.sin(ur), -math.cos(ur))
    perpu = (math.cos(ur), math.sin(ur))
    S = (waist[0] + tu[0] * TORSO_HI, waist[1] + tu[1] * TORSO_HI)
    hr = math.radians(ub + p["head"])
    hd = (math.sin(hr), -math.cos(hr))
    C = (S[0] + hd[0] * HEAD_OFF + perpu[0] * 0.5, S[1] + hd[1] * HEAD_OFF + perpu[1] * 0.5)
    sk = {"hip": hip, "waist": waist, "S": S, "C": C, "lean": lean, "ub": ub, "perp": perp, "perpu": perpu,
          "tu": tu, "td": td, "p": p}
    knee_pole = tuple(p["kpole"])
    for tag, off, ank in (("n", nhip_off, ank_n), ("f", fhip_off, ank_f)):
        hj = (hip[0] + perp[0] * off, hip[1] + perp[1] * off)
        knee, an = ik_pole(hj, ank, THIGH, SHIN, knee_pole, min_d=6.0, max_frac=1.0)
        sk["hj" + tag], sk["knee" + tag], sk["ank" + tag] = hj, knee, an
    sk["fa_n"], sk["fa_f"] = p["fa"], p["ba"]
    tw = p["twist"]
    nsh = (S[0] + perpu[0] * (-1.3 + 2.3 * tw), S[1] + perpu[1] * (-1.3 + 2.3 * tw) + 0.3)
    fsh = (S[0] + perpu[0] * (2.2 - 1.6 * tw), S[1] + perpu[1] * (2.2 - 1.6 * tw) + 0.5)
    sk["nsh"], sk["fsh"] = nsh, fsh
    arm_pole = (-0.4, 1.0)
    kind = p["weapon"] if p["carry"] == "hand" else None
    d = _dir(p["sw"])
    sk["kind"] = kind
    tgt = _add(nsh, _rot(p["nh"], ub))
    two = bool(kind and p["grip"] == "two")
    best = None
    for _it in range(16):
        elbow, hand = ik_pole(nsh, tgt, UARM, FARM, arm_pole)
        if kind:
            d = _dir(clamp_dir(kind, hand, p["sw"]))
        W = weapon_pts(p["weapon"], hand, d) if kind else None
        if not two:
            break
        # far hand: the nearest grip on the shaft that the far arm can reach; if none exists the near hand
        # is pulled toward the far shoulder (both hands stay on the shaft, the pose just reaches less far)
        s0 = p["span"]
        lo, hi = 3.0, min(W["front"] - 7.0, 24.0)
        best = None
        for k in range(0, 80):
            for sgn in ((1,) if k == 0 else (1, -1)):
                s = s0 + k * 0.5 * sgn
                if s < lo or s > hi:
                    continue
                gp = (hand[0] + d[0] * s, hand[1] + d[1] * s)
                if 3.2 <= _dist(fsh, gp) <= REACH_ARM * 0.985:
                    best = gp
                    break
            if best:
                break
        if best:
            break
        tgt = (tgt[0] + (fsh[0] - tgt[0]) * 0.12, tgt[1] + (fsh[1] - tgt[1]) * 0.12)
    sk["elbown"], sk["handn"] = elbow, hand
    sk["d"] = d
    sk["W"] = W
    if two:
        if best is None:
            best = (hand[0] + d[0] * p["span"], hand[1] + d[1] * p["span"])
        felbow, fhand = ik_pole(fsh, best, UARM, FARM, arm_pole)
    else:
        tgtf = _add(fsh, _rot(p["fh"], ub))
        felbow, fhand = ik_pole(fsh, tgtf, UARM, FARM, arm_pole)
    sk["elbowf"], sk["handf"] = felbow, fhand
    return sk


def validate(sk):
    """Geometry metrics for QA: segment-length constancy and far-hand-to-shaft distance."""
    seg = 0.0
    for tag in ("n", "f"):
        a, b, c = sk["hj" + tag], sk["knee" + tag], sk["ank" + tag]
        seg = max(seg, abs(_dist(a, b) - THIGH) / THIGH, abs(_dist(b, c) - SHIN) / SHIN)
    for tag, shk in (("n", "nsh"), ("f", "fsh")):
        a, b, c = sk[shk], sk["elbow" + tag], sk["hand" + tag]
        seg = max(seg, abs(_dist(a, b) - UARM) / UARM, abs(_dist(b, c) - FARM) / FARM)
    grip = 0.0
    p = sk["p"]
    if sk["kind"] and p["grip"] == "two":
        d, h = sk["d"], sk["handn"]
        v = (sk["handf"][0] - h[0], sk["handf"][1] - h[1])
        grip = abs(v[0] * d[1] - v[1] * d[0])
        s = v[0] * d[0] + v[1] * d[1]
        if s < 2.0 or s > sk["W"]["front"]:
            grip = max(grip, 99.0)
    return {"seg": seg, "grip": grip}


# ------------------------------------------------------------------- spring chains

def chain_specs(sk, p):
    ub = sk["ub"]
    S, C = sk["S"], sk["C"]
    pu = sk["perpu"]

    def rests(anchor, offs):
        return [(anchor[0] + _rot(o, ub)[0], anchor[1] + _rot(o, ub)[1]) for o in offs]
    a1 = (S[0] - pu[0] * 2.4, S[1] - pu[1] * 2.4 - 0.2)
    a2 = (a1[0] + 0.4, a1[1] + 1.3)
    ap = (C[0] - 4.8, C[1] - 1.0)
    ah1 = (C[0] - 3.0, C[1] - 4.8)
    ah2 = (C[0] - 0.6, C[1] - 5.4)
    return {
        "tail1": (a1, rests(a1, [(-3.2, 1.0), (-6.4, 2.4), (-9.6, 4.4), (-12.6, 6.8), (-15.0, 9.6)])),
        "tail2": (a2, rests(a2, [(-2.4, 2.8), (-4.6, 5.8), (-6.0, 9.0), (-6.6, 12.2)])),
        "pony": (ap, rests(ap, [(-2.6, 1.8), (-4.6, 4.6), (-5.4, 8.0), (-5.4, 11.2)])),
        "lock1": (ah1, rests(ah1, [(-2.6, -0.6), (-5.0, 0.4)])),
        "lock2": (ah2, rests(ah2, [(-2.2, -1.4), (-4.4, -0.6)])),
    }


def simulate(sks, poses_, loop):
    specs = [chain_specs(s, p) for s, p in zip(sks, poses_)]
    wind = [p["wind"] for p in poses_]
    out = [dict() for _ in sks]
    cfg = {"tail1": (0.09, 0.80, 0.16), "tail2": (0.11, 0.78, 0.22), "pony": (0.14, 0.78, 0.20),
           "lock1": (0.20, 0.74, 0.10), "lock2": (0.20, 0.74, 0.10)}
    for name, (st, dm, gr) in cfg.items():
        anchors = [sp[name][0] for sp in specs]
        rests = [sp[name][1] for sp in specs]
        res = simulate_chain(anchors, rests, stiffness=st, damping=dm, gravity=gr, wind=wind, loop=loop,
                             floor=G[1] - 1.5)
        for i, pts in enumerate(res):
            out[i][name] = pts
    return out


# ------------------------------------------------------------------- face

EYE = (28, 18, 48)
IRIS = (58, 150, 184)
BROW = (92, 38, 36)
MOUTH = (120, 52, 58)
OPEN = (150, 40, 52)


def paint_face(buf, cv, head, expr, show=True):
    if not show:
        return
    rgba, mat, filled = buf["rgba"], buf["mat"], buf["filled"]
    sm = cv.matidx["skin"]
    hx, hy = int(round(head[0])), int(round(head[1]))

    def put(dx, dy, col):
        x, y = hx + dx, hy + dy
        if 0 <= x < rgba.shape[1] and 0 <= y < rgba.shape[0] and filled[y, x] and mat[y, x] == sm:
            rgba[y, x, :3] = col

    n, f = 0, 3                      # eye columns: the far eye sits next to the profile edge
    if expr == "neutral":
        for c in (n, f):
            put(c, 0, IRIS); put(c, 1, EYE)
        put(n, -1, BROW); put(f, -1, BROW)
        put(1, 3, MOUTH)
    elif expr == "blink":
        put(n, 1, EYE); put(f, 1, EYE)
        put(1, 3, MOUTH)
    elif expr in ("focus", "angry"):
        for c in (n, f):
            put(c, 0, EYE if expr == "angry" else IRIS); put(c, 1, EYE)
        put(n, -1, BROW); put(n + 1, -1, BROW); put(f - 1, -1 if expr == "focus" else 0, BROW); put(f, -1, BROW)
        if expr == "angry":
            put(1, 3, OPEN); put(2, 3, OPEN)
        else:
            put(1, 3, MOUTH)
    elif expr == "happy":
        put(n, 0, EYE); put(f, 0, EYE)
        put(1, 3, OPEN); put(2, 3, OPEN); put(1, 4, OPEN)
    elif expr == "hurt":
        put(n, 0, EYE); put(n + 1, 1, EYE); put(f - 1, 1, EYE); put(f, 0, EYE)
        put(n, -1, BROW); put(f, -1, BROW)
        put(1, 3, OPEN); put(2, 3, OPEN); put(1, 4, OPEN)
    elif expr == "dead":
        put(n, 0, EYE); put(n, 1, EYE); put(f, 0, EYE); put(f, 1, EYE)
        put(1, 3, MOUTH)


# ------------------------------------------------------------------- drawing helpers

SEAMS = {("armN", "torso"), ("armF", "torso"), ("legN", "legF"), ("legN", "pelvis"), ("legF", "pelvis"),
         ("bootN", "legN"), ("bootF", "legF"), ("pauldron", "torso"), ("pauldron", "armN"), ("head", "neck")}


def _cap(cv, mat, a, b, ra, rb, group, k=4, **kw):
    return cv.paint(mat, Mask(CELL).capsule(a, b, ra, rb), group=group, k=k, **kw)


def _poly(cv, mat, pts, group, k=3, **kw):
    return cv.paint(mat, Mask(CELL).poly(pts), group=group, k=k, **kw)


def _foot_poly(ank, ang):
    """Boot silhouette in world coords. ang > 0 raises the toe."""
    loc = [(-2.5, -2.0), (0.9, -2.5), (3.8, -1.2), (6.0, 0.7), (6.0, 2.0), (-2.7, 2.0), (-3.1, 0.2)]
    out = []
    for x, y in loc:
        rx, ry = _rot((x, y), -ang)
        out.append((ank[0] + rx, ank[1] + ry))
    return out


def _arm(cv, sk, tag):
    sh = sk["nsh" if tag == "n" else "fsh"]
    el = sk["elbow" + tag]
    wr = sk["hand" + tag]
    far = tag == "f"
    sleeve = "tunic_f" if far else "tunic"
    skin = "skin_f" if far else "skin"
    grp = "armN" if tag == "n" else "armF"
    _cap(cv, sleeve, sh, el, 2.5, 2.0, grp, k=3)
    _cap(cv, skin, el, wr, 1.9, 1.5, grp, k=3)
    mid = (el[0] + (wr[0] - el[0]) * 0.42, el[1] + (wr[1] - el[1]) * 0.42)
    _cap(cv, "leather" if far else "bronze", mid, (wr[0] + (el[0] - wr[0]) * 0.12, wr[1] + (el[1] - wr[1]) * 0.12),
         2.0, 1.75, grp, k=3, deep=False)


def _hand(cv, sk, tag):
    wr = sk["hand" + tag]
    cv.paint("skin_f" if tag == "f" else "skin", Mask(CELL).circle(wr, 1.9), group="hand" + tag, k=3, deep=False)


def _draw_weapon(cv, sk):
    kind, W = sk["kind"], sk["W"]
    at = W["at"]
    if kind == "sword":
        _cap(cv, "leather", at(-3.0), at(2.0), 1.0, 1.0, "wpn", k=2, deep=False)
        cv.paint("bronze", Mask(CELL).circle(at(-4.0), 1.5), group="wpn", k=2, deep=False)
        _cap(cv, "bronze", at(2.4, -3.4), at(2.4, 3.4), 1.0, 1.0, "wpn", k=2, deep=False)
        _poly(cv, "steel", [at(3.0, 1.7), at(16.0, 1.3), at(19.8, 0.0), at(16.0, -1.3), at(3.0, -1.7)], "wpn", k=2, deep=False)
    elif kind == "spear":
        _cap(cv, "wood", at(-8.0), at(21.0), 1.0, 1.0, "wpn", k=2, deep=False)
        cv.paint("bronze", Mask(CELL).circle(at(-8.0), 1.4), group="wpn", k=2, deep=False)
        _cap(cv, "bronze", at(19.0), at(22.0), 1.4, 1.4, "wpn", k=2, deep=False)
        _poly(cv, "steel", [at(21.4, 0.0), at(22.4, 2.0), at(24.8, 2.5), at(28.8, 0.0), at(24.8, -2.5), at(22.4, -2.0)], "wpn", k=2, deep=False)
        _poly(cv, "scarf", [at(18.0, 0.0), at(19.0, 2.2), at(16.0, 4.0), at(16.5, 1.6)], "wpn", k=2, deep=False, hi=False)
    else:   # axe
        _cap(cv, "wood", at(-6.0), at(26.0), 1.1, 1.0, "wpn", k=2, deep=False)
        cv.paint("bronze", Mask(CELL).circle(at(-6.0), 1.5), group="wpn", k=2, deep=False)
        _poly(cv, "steel", [at(21.0, 0.9), at(22.4, 5.0), at(25.8, 7.6), at(29.0, 6.6), at(28.0, 3.0), at(28.6, 0.9), at(27.4, -1.9), at(22.0, -2.0)], "wpn", k=2, deep=False)
        _poly(cv, "steel", [at(25.0, -1.6), at(29.4, -1.2), at(30.6, -2.6), at(26.0, -3.4)], "wpn", k=2, deep=False)
        _cap(cv, "bronze", at(20.4, -1.8), at(20.4, 1.6), 0.9, 0.9, "wpn", k=2, deep=False)


def _draw_sheath(cv, sk):
    """Sword on the back (casting / death): scabbard diagonal behind the torso."""
    hip, waist, S, pu, tu = sk["hip"], sk["waist"], sk["S"], sk["perpu"], sk["tu"]
    a = (waist[0] + pu[0] * 2.4, waist[1] + pu[1] * 2.4 + 2.0)           # scabbard tip rests near the far hip
    b = (S[0] - pu[0] * 3.4 + tu[0] * 3.0, S[1] - pu[1] * 3.4 + tu[1] * 3.0)
    _cap(cv, "leather", a, b, 1.1, 1.1, "sheath", k=2, deep=False)
    _cap(cv, "bronze", b, (b[0] + (b[0] - a[0]) * 0.20, b[1] + (b[1] - a[1]) * 0.20), 0.9, 0.9, "sheath", k=2, deep=False)
    g = (b[0] + (b[0] - a[0]) * 0.07, b[1] + (b[1] - a[1]) * 0.07)
    _cap(cv, "bronze", (g[0] - 1.8, g[1] + 0.8), (g[0] + 1.8, g[1] - 0.8), 0.8, 0.8, "sheath", k=2, deep=False)


# ------------------------------------------------------------------- draw

def draw(sk, chains, p):
    cv = Canvas(CELL, MATERIALS)
    xs = cv.xs
    hip, waist, S, C = sk["hip"], sk["waist"], sk["S"], sk["C"]
    pu, pl = sk["perpu"], sk["perp"]
    cv.paint("scarf", Mask(CELL).ribbon(chains["tail1"], 3.3, 1.2), group="tail1", k=3, deep=False, hi=False)
    cv.paint("scarf", Mask(CELL).ribbon(chains["tail2"], 2.8, 1.1), group="tail2", k=3, deep=False, hi=False)
    cv.paint("hair", Mask(CELL).ribbon(chains["pony"], 2.9, 0.9), group="pony", k=3, deep=False)
    far_front = bool(p["far_front"]) or bool(sk["kind"] and p["grip"] == "two")
    if not far_front:
        _arm(cv, sk, "f")
        _hand(cv, sk, "f")
    # far leg
    kf, af = sk["kneef"], sk["ankf"]
    _cap(cv, "pants_f", sk["hjf"], kf, 3.6, 2.7, "legF", k=4)
    _cap(cv, "pants_f", kf, af, 2.7, 2.1, "legF", k=3)
    _cap(cv, "boots", (kf[0] + (af[0] - kf[0]) * 0.45, kf[1] + (af[1] - kf[1]) * 0.45), af, 2.7, 2.3, "bootF", k=3)
    cv.paint("boots", Mask(CELL).poly(_foot_poly(af, sk["fa_f"])), group="bootF", k=3)
    # pelvis + torso
    _cap(cv, "pants", (hip[0] - pl[0] * 0.5, hip[1] + 1.2), (hip[0] + pl[0] * 0.8, hip[1] - 0.2), 4.0, 3.9, "pelvis", k=4)
    torso = Mask(CELL).capsule(waist, hip, 3.3, 3.8).capsule(S, waist, 4.5, 3.3)
    torso.poly([(S[0] - pu[0] * 4.2, S[1] - pu[1] * 4.2), (S[0] + pu[0] * 4.8, S[1] + pu[1] * 4.8),
                (waist[0] + pu[0] * 3.4, waist[1] + pu[1] * 3.4), (waist[0] - pu[0] * 3.6, waist[1] - pu[1] * 3.6)])
    cv.paint("tunic", torso, group="torso", k=5)
    hem = [(waist[0] - pl[0] * 3.8, waist[1] - pl[1] * 3.8), (waist[0] + pl[0] * 3.9, waist[1] + pl[1] * 3.9),
           (hip[0] + pl[0] * 5.6, hip[1] + 5.6), (hip[0] - pl[0] * 5.2, hip[1] + 5.4)]
    cv.paint("tunic", Mask(CELL).poly(hem), group="torso", k=4, deep=True)
    bl = (waist[0] - pl[0] * 3.6, waist[1] - pl[1] * 3.6)
    br = (waist[0] + pl[0] * 3.9, waist[1] + pl[1] * 3.9)
    _cap(cv, "leather", bl, br, 1.2, 1.2, "belt", k=2, deep=False)
    cv.paint("bronze", Mask(CELL).circle((waist[0] + pl[0] * 1.4, waist[1] + pl[1] * 1.4), 1.2), group="belt", k=2, deep=False)
    _cap(cv, "leather", (S[0] - pu[0] * 2.8, S[1] - pu[1] * 2.8 + 0.6), (waist[0] + pu[0] * 2.8, waist[1] + pu[1] * 2.8 + 1.0), 0.9, 0.9, "strap", k=2, deep=False)
    # near leg
    kn, an = sk["kneen"], sk["ankn"]
    _cap(cv, "pants", sk["hjn"], kn, 3.8, 2.9, "legN", k=4)
    _cap(cv, "pants", kn, an, 2.9, 2.2, "legN", k=3)
    cv.paint("bronze", Mask(CELL).ellipse((kn[0] + 0.6, kn[1] - 0.2), 2.0, 1.7, 0), group="legN", k=2, deep=False)
    _cap(cv, "boots", (kn[0] + (an[0] - kn[0]) * 0.42, kn[1] + (an[1] - kn[1]) * 0.42), an, 2.9, 2.4, "bootN", k=3)
    cv.paint("boots", Mask(CELL).poly(_foot_poly(an, sk["fa_n"])), group="bootN", k=3)
    if far_front:
        _arm(cv, sk, "f")
    if p["carry"] == "back":
        _draw_sheath(cv, sk)
    # head
    skull = Mask(CELL).ellipse(C, 5.0, 5.4, 0)
    skull.poly([(C[0] - 3.0, C[1] + 1.0), (C[0] + 4.9, C[1] + 0.2), (C[0] + 4.6, C[1] + 3.5), (C[0] + 2.4, C[1] + 5.7),
                (C[0] - 1.6, C[1] + 5.2), (C[0] - 3.2, C[1] + 3.0)])
    nk = (S[0] + sk["tu"][0] * 1.0, S[1] + sk["tu"][1] * 1.0)
    cv.paint("skin_f", Mask(CELL).capsule(nk, (C[0] + 0.5, C[1] + 3.6), 1.9, 2.2), group="neck", k=3)
    cv.paint("hair", Mask(CELL).ellipse((C[0] - 1.8, C[1] - 1.0), 5.6, 5.8, 0), group="hair", k=4)
    for key in ("lock1", "lock2"):
        cv.paint("hair", Mask(CELL).ribbon(chains[key], 2.2, 0.8), group="hair", k=3, deep=False)
    cv.paint("skin", skull, group="head", k=4, cast=3)
    sk_arr = skull.array()
    cv.paint("hair", sk_arr & (xs < C[0] - 2.0), group="hair", k=4)
    fringe = [(C[0] - 5.8, C[1] - 4.8), (C[0] + 1.2, C[1] - 6.8), (C[0] + 5.2, C[1] - 4.2), (C[0] + 5.6, C[1] - 1.0),
              (C[0] + 3.6, C[1] - 2.6), (C[0] + 3.2, C[1] - 0.6), (C[0] + 1.6, C[1] - 2.4), (C[0] + 0.2, C[1] - 1.2), (C[0] - 1.2, C[1] - 2.8)]
    cv.paint("hair", Mask(CELL).poly(fringe).array() & (Mask(CELL).ellipse(C, 5.9, 6.2, 0).array() | sk_arr), group="hair", k=3)
    collar = Mask(CELL).ellipse((S[0] + pu[0] * 0.2, S[1] + pu[1] * 0.2 - 0.2), 5.2, 2.0, sk["ub"])
    cv.paint("scarf", collar, group="scarf", k=3, cast=3)
    # near arm + pauldron + weapon + hands
    _arm(cv, sk, "n")
    nsh = sk["nsh"]
    cv.paint("bronze", Mask(CELL).ellipse((nsh[0] + 0.2, nsh[1] + 0.1), 3.9, 2.9, sk["ub"] * 0.7), group="pauldron", k=3)
    if sk["kind"]:
        _draw_weapon(cv, sk)
        _hand(cv, sk, "n")
        if p["grip"] == "two":
            _hand(cv, sk, "f")
    else:
        _hand(cv, sk, "n")
    cs = math.cos(math.radians(p["spin"]))
    if abs(cs) < 0.995:
        cv.warp_x(hip[0], max(abs(cs), 0.22), mirror=cs < 0)
    groups = set(cv.group.values())
    no_seam = {(a, b) for a in groups for b in groups} - SEAMS
    buf = cv.finish(no_seam)
    paint_face(buf, cv, C, p["expr"], show=cs > 0.55)
    return cv, buf


def anchors(sk):
    if sk["kind"]:
        tip = sk["W"]["tip"]
    else:
        tip = sk["handn"]
    return {"hand": sk["handn"], "hand_dir": sk["d"], "off_hand": sk["handf"], "head": sk["C"],
            "chest": sk["S"], "weapon_tip": tip}


from chars import ren_anim as _anim  # noqa: E402  (animation authoring lives next door)

PROCEDURAL = _anim.PROCEDURAL
REF_SPEED = _anim.REF_SPEED
poses = _anim.poses

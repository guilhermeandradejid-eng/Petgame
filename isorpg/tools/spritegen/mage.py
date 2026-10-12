"""Vesper, the mage. Costume, skeleton and animations, all as code.

A pose is a dict of angles and targets. IK places elbows and knees, springs move hair,
scarf, hat tip and the robe hem, and the renderer turns the result into pixels.
"""
import math
import numpy as np

from raster import Material, hexpal
from rig import v3, norm, rot_x, rot_y, rot_z, body_rot, two_bone_ik, Chain, Timeline

NAME = "mage"

MAT = {
    "robe": Material("robe", hexpal("#8f9cff", "#5864de", "#3d40b0", "#2a2a80", "#1a1850")),
    "robe_in": Material("robe_in", hexpal("#4a4fbf", "#34379a", "#262876", "#1c1c58", "#121038")),
    "trim": Material("trim", hexpal("#fff1b0", "#f5c451", "#c98a2e", "#8f5a22", "#5a3418")),
    "scarf": Material("scarf", hexpal("#ffb08a", "#ec5b43", "#bb3a3c", "#85243b", "#521530")),
    "skin": Material("skin", hexpal("#ffe8d2", "#f9c49d", "#de9876", "#ac6a5c", "#6b3d3f")),
    "hair": Material("hair", hexpal("#ffffff", "#e4e1fb", "#b9b2e3", "#8b81bb", "#544a7f")),
    "hat": Material("hat", hexpal("#8f9cff", "#5864de", "#3d40b0", "#2a2a80", "#1a1850")),
    "pants": Material("pants", hexpal("#6e6688", "#4c4462", "#38314a", "#262034", "#18121f")),
    "boot": Material("boot", hexpal("#b47e5c", "#86553d", "#62392c", "#432221", "#281518")),
    "wood": Material("wood", hexpal("#e0b07a", "#ae7643", "#83522e", "#5a351f", "#361e13")),
    "crystal": Material("crystal", hexpal("#ffffff", "#bafff7", "#55e2ea", "#2c9ec6", "#1d5b8e")),
}
EYE = (34, 20, 56)
MOUTH = (120, 52, 60)

# Skeleton, in pixels. ~80 px tall with the hat, about 1:4.6 head to body.
HIP_Z = 29.0
HIP_X = 3.4
THIGH, SHIN = 13.2, 13.2
SPINE = 13.0
NECK = 5.0
HEAD_C = 5.0
HEAD_R = 6.6
SH_X, SH_Z = 7.2, 3.0
UPPER_ARM, FOREARM = 9.5, 9.0
STAFF_LEN, STAFF_GRIP = 66.0, 27.0

BASE = dict(
    root=(0, 0, 0), lean=3.0, twist=0.0, roll=0.0,
    head=(0, 0, 0),  # pitch (down +), yaw (left +), roll
    hand_r=(10.5, 4.0, 30.0), hand_l=(-9.5, 1.5, 29.0),
    pole_r=(0.8, -0.7, -0.3), pole_l=(-0.8, -0.6, -0.3),
    foot_r=(3.8, 0.8, 3.0), foot_l=(-3.8, -0.6, 3.0),
    toe_r=0.0, toe_l=0.0,
    staff=(0.10, 0.20, 1.0),
    glow=0.0, expr="neutral",
)


def P(**kw):
    d = dict(BASE)
    d.update(kw)
    return d


# ----------------------------------------------------------------------------- skeleton

def solve(pose):
    s = {}
    root = v3(pose["root"])
    T = body_rot(pose["lean"], pose["twist"], pose["roll"])
    pelvis = root + v3(0, 0, HIP_Z)
    chest = pelvis + T @ v3(0, 0, SPINE)
    neck = chest + T @ v3(0, 0, NECK)
    hp, hy, hr = pose["head"]
    Hr = T @ rot_z(hy) @ rot_x(-hp) @ rot_y(hr)
    head = neck + Hr @ v3(0, 0, HEAD_C)
    s.update(root=root, T=T, H=Hr, pelvis=pelvis, chest=chest, neck=neck, head=head)

    for side, sx in (("r", 1), ("l", -1)):
        sh = chest + T @ v3(sx * SH_X, 0, SH_Z)
        target = root + v3(pose["hand_" + side])
        elbow, wrist = two_bone_ik(sh, target, UPPER_ARM, FOREARM, T @ norm(v3(pose["pole_" + side])))
        s["sh_" + side], s["elbow_" + side], s["hand_" + side] = sh, elbow, wrist

        hip = pelvis + rot_z(pose["twist"] * -0.4) @ v3(sx * HIP_X, 0, -1.5)
        knee, ankle = two_bone_ik(hip, v3(pose["foot_" + side]), THIGH, SHIN, rot_z(pose["twist"] * -0.4) @ v3(0, 1, 0.2))
        F = rot_x(pose["toe_" + side])
        s["hip_" + side], s["knee_" + side], s["ankle_" + side] = hip, knee, ankle
        s["toe_" + side] = ankle + F @ v3(sx * 0.3, 4.6, -1.4)

    d = norm(v3(pose["staff"]))
    bottom = s["hand_r"] - d * STAFF_GRIP
    s["staff_dir"] = d
    s["staff_bottom"] = bottom
    s["staff_top"] = bottom + d * STAFF_LEN
    s["staff_tip"] = s["staff_top"] + d * 3.6
    s["waist"] = pelvis + T @ v3(0, 0, 4.5)
    s["hat_rot"] = Hr @ rot_x(24)
    s["hat_base"] = head + Hr @ v3(0, -1.4, 5.0)
    s["hair_root"] = head + Hr @ v3(0, -4.3, -0.6)
    s["scarf_r"] = neck + T @ v3(1.8, -3.6, -0.6)
    s["scarf_l"] = neck + T @ v3(-1.4, -3.9, -0.2)
    s["pose"] = pose
    return s


# ----------------------------------------------------------------------------- springs

def make_chains():
    hat = Chain([(0, -0.25, 1), (0, -0.5, 1), (0, -1.0, 0.9), (0, -1.5, 0.3)], [5.2, 4.6, 4.0, 3.6],
                stiffness=0.30, damping=0.10, gravity=0.05, drag=0.05)
    hair = Chain([(0, -0.25, -1), (0, -0.2, -1), (0, -0.05, -1)], [3.4, 3.4, 3.0],
                 stiffness=0.22, damping=0.12, gravity=0.06, drag=0.05)
    scarf_r = Chain([(0.2, -0.5, -1)] + [(0.1, -0.35, -1)] * 3, [3.4, 3.4, 3.2, 3.0],
                    stiffness=0.10, damping=0.08, gravity=0.07, drag=0.06)
    scarf_l = Chain([(-0.2, -0.5, -1)] + [(-0.1, -0.35, -1)] * 2, [3.4, 3.2, 3.0],
                    stiffness=0.10, damping=0.08, gravity=0.07, drag=0.06)
    hem = Chain([(0, 0, -1)], [26.0], stiffness=0.20, damping=0.16, gravity=0.04, drag=0.05)
    return {
        "hat": (hat, "hat_base", "hat_rot"),
        "hair": (hair, "hair_root", "H"),
        "scarf_r": (scarf_r, "scarf_r", "T"),
        "scarf_l": (scarf_l, "scarf_l", "T"),
        "hem": (hem, "waist", "T"),
    }


# ----------------------------------------------------------------------------- costume

def _ring(center, rot, rx, ry, n, z=None):
    th = np.linspace(0, 2 * math.pi, n, endpoint=False)
    pts = np.stack([rx * np.cos(th), ry * np.sin(th), np.zeros(n) if z is None else z], axis=-1)
    return center + pts @ rot.T, th


def _frame_from_dir(d, ref):
    d = norm(d)
    a = norm(np.cross(ref, d))
    if np.linalg.norm(a) < 1e-6:
        a = norm(np.cross(v3(0, 1, 0), d))
    b = np.cross(d, a)
    return np.stack([a, b, d], axis=-1)  # columns: x, y, z(=d)


def draw(cv, s, chains, R):
    """Draw the character into canvas cv. R turns local space into the facing world space."""
    W = lambda p: np.asarray(p) @ R.T
    pose = s["pose"]
    T, Hr = s["T"], s["H"]
    m = MAT

    # legs and boots
    for side in ("r", "l"):
        leg = cv.part("leg_" + side, m["pants"], group="leg_" + side)
        leg.capsule(W(s["hip_" + side]), W(s["knee_" + side]), 2.9, 2.4)
        leg.capsule(W(s["knee_" + side]), W(s["ankle_" + side]), 2.3, 1.9)
        boot = cv.part("boot_" + side, m["boot"], group="boot_" + side, bands=(1.0, 2.0))
        boot.capsule(W(s["ankle_" + side] + v3(0, 0, 0.6)), W(s["toe_" + side]), 2.5, 2.1)

    # robe skirt: waist ring -> mid -> hem, hem follows the pendulum and makes room for the feet
    n = 24
    hem_end = chains["hem"][-1]
    waist_c = s["waist"]
    hem_c = hem_end.copy()
    hem_c[2] = max(hem_c[2], 3.5)
    waist, th = _ring(waist_c, T, 7.0, 5.6, n)
    hrx, hry = 12.6, 10.8
    scallop = 0.7 * np.sin(th * 5 + 0.5)
    hem = np.stack([hem_c[0] + hrx * np.cos(th), hem_c[1] + hry * np.sin(th), hem_c[2] + scallop], -1)
    for side in ("r", "l"):
        a = s["ankle_" + side]
        off = a[:2] - hem_c[:2]
        dist = np.linalg.norm(off)
        if dist < 1e-6:
            continue
        u = np.stack([np.cos(th), np.sin(th)], -1)
        w = np.maximum(0, u @ (off / dist)) ** 4
        r_dir = 1.0 / np.sqrt((np.cos(th) / hrx) ** 2 + (np.sin(th) / hry) ** 2)
        ext = np.maximum(0, dist + 2.5 - r_dir)
        hem[:, :2] += u * (w * ext)[:, None]
        hem[:, 2] += w * ext * 0.35 + w * max(0, a[2] - 3) * 0.6
    mid = waist * 0.42 + hem * 0.58
    mid_c = waist_c * 0.42 + hem_c * 0.58
    mid = mid_c + (mid - mid_c) * 1.06
    rings = [waist, mid, hem]
    centers = [waist_c, mid_c, hem_c]
    normals = []
    for rg, c in zip(rings, centers):
        nn = rg - c
        nn[:, 2] = 0.35 * np.linalg.norm(nn[:, :2], axis=-1)
        normals.append(nn / np.linalg.norm(nn, axis=-1, keepdims=True))
    wr = [W(r) for r in rings]
    wn = [W(r) for r in normals]
    sectors = 6
    per = n // sectors
    for k in range(sectors):
        idx = [(k * per + j) % n for j in range(per + 1)]
        part = cv.part("robe_%d" % k, m["robe"], group="robe", bands=(1.3, 3.2))
        part.loft([r[idx] for r in wr], [q[idx] for q in wn], closed=False)
    inner = cv.part("robe_in", m["robe_in"], group="robe", shade=False, base_tone=2)
    inner.loft([W(c + (r - c) * 0.97 + v3(0, 0, -0.3)) for r, c in ((rings[1], centers[1]), (rings[2], centers[2]))], closed=True)
    trim = cv.part("trim_hem", m["trim"], group="trim", bands=(1.0, 2.0), highlight=0.5)
    up = hem * 0.86 + mid * 0.14
    trim.loft([W(hem_c + (up - hem_c) * 1.025), W(hem_c + (hem - hem_c) * 1.03)],
              [W(normals[2]), W(normals[2])], closed=True)

    front = cv.part("trim_front", m["trim"], group="trim", bands=(0.6, 1.2), highlight=0.0, vote=2.0)
    j = n // 4  # theta = 90 degrees, the front of the robe
    for r0, r1, c0, c1 in ((waist, mid, waist_c, mid_c), (mid, hem, mid_c, hem_c)):
        a0 = c0 + (r0[j] - c0) * 1.03
        a1 = c1 + (r1[j] - c1) * 1.03
        front.capsule(W(a0), W(a1), 0.9, 1.5)

    # torso, belt, scarf
    torso = cv.part("torso", m["robe"], group="robe", bands=(1.3, 3.0))
    for sx in (-1.9, 1.9):
        torso.capsule(W(s["pelvis"] + T @ v3(sx, 0, 3.5)), W(s["chest"] + T @ v3(sx * 1.2, 0, 1.0)), 5.4, 5.9)
    belt = cv.part("belt", m["trim"], group="belt", bands=(1.0, 2.0))
    b0, _ = _ring(s["waist"] + T @ v3(0, 0, -1.6), T, 7.45, 6.05, 20)
    b1, _ = _ring(s["waist"] + T @ v3(0, 0, 0.6), T, 7.35, 5.95, 20)
    belt.loft([W(b0), W(b1)])
    belt.sphere(W(s["waist"] + T @ v3(0, 6.1, -0.5)), 1.5)

    scarf = cv.part("scarf", m["scarf"], group="scarf", bands=(1.0, 2.2))
    ring, _ = _ring(s["neck"] + T @ v3(0, 0, -2.0), T, 4.8, 4.4, 10)
    for i in range(len(ring)):
        scarf.capsule(W(ring[i]), W(ring[(i + 1) % len(ring)]), 2.0)
    for key in ("scarf_r", "scarf_l"):
        pts = chains[key]
        tail = cv.part(key, m["scarf"], group="scarf_tail", bands=(1.0, 2.0))
        for i in range(len(pts) - 1):
            r0 = 2.2 - 0.25 * i
            tail.capsule(W(pts[i]), W(pts[i + 1]), r0, r0 - 0.25)

    # arms
    for side, sx in (("r", 1), ("l", -1)):
        sh, el, ha = s["sh_" + side], s["elbow_" + side], s["hand_" + side]
        arm = cv.part("arm_" + side, m["robe"], group="arm_" + side, bands=(1.1, 2.6))
        arm.capsule(W(sh), W(el), 3.0, 2.6)
        fd = norm(ha - el)
        cuff_a = ha - fd * 2.4
        arm.capsule(W(el), W(cuff_a), 2.6, 3.4)
        cuff = cv.part("cuff_" + side, m["trim"], group="cuff_" + side, bands=(0.8, 1.6), highlight=0.5)
        cuff.capsule(W(cuff_a), W(ha - fd * 1.5), 3.3, 3.4)
        hand = cv.part("hand_" + side, m["skin"], group="hand_" + side, bands=(0.8, 1.6), vote=1.5)
        hand.sphere(W(ha + fd * 0.6), 2.3)
        hand.sphere(W(ha + fd * 1.8), 1.8)

    # head and hair
    head = cv.part("head", m["skin"], group="head", bands=(1.2, 2.8))
    head.sphere(W(s["head"]), HEAD_R)
    head.sphere(W(s["head"] + Hr @ v3(0, 1.0, -2.2)), HEAD_R * 0.82)
    hair = cv.part("hair", m["hair"], group="hair", bands=(1.0, 2.4))
    hair.sphere(W(s["head"] + Hr @ v3(0, -2.0, 1.0)), HEAD_R - 0.2)
    for sx in (-1, 1):
        hair.capsule(W(s["head"] + Hr @ v3(sx * 4.8, -0.6, 3.0)), W(s["head"] + Hr @ v3(sx * 5.7, -1.0, -4.8)), 2.0, 1.1)
    hp = chains["hair"]
    hair.capsule(W(s["head"] + Hr @ v3(0, -3.0, 1.0)), W(hp[0]), 4.6, 4.2)
    for i in range(len(hp) - 1):
        hair.capsule(W(hp[i]), W(hp[i + 1]), 4.0 - 0.8 * i, 3.2 - 0.8 * i)

    # hat: brim, band and a cone lofted along the spring chain
    brim = cv.part("brim", m["hat"], group="brim", bands=(1.0, 2.2))
    hb = s["hat_base"]
    Hh = s["hat_rot"]
    inner_r, _ = _ring(hb + Hh @ v3(0, 0, 0.2), Hh, 4.0, 4.0, 22)
    outer_r, th2 = _ring(hb + Hh @ v3(0, 0, -0.8), Hh, 9.8, 9.8, 22)
    up_n = np.repeat((Hh @ v3(0, 0, 1))[None], 22, axis=0)
    brim.loft([W(inner_r), W(outer_r)], [W(up_n), W(up_n)])
    hat = cv.part("hat", m["hat"], group="hat", bands=(1.3, 3.0))
    hc = chains["hat"]
    radii = [6.6, 5.0, 3.5, 2.1, 0.7]
    hrings, hnorms = [], []
    for i, p in enumerate(hc):
        d = hc[min(i + 1, len(hc) - 1)] - hc[max(i - 1, 0)]
        F = _frame_from_dir(d, Hh @ v3(1, 0, 0))
        rg, _ = _ring(p, F, radii[i], radii[i], 16)
        hrings.append(W(rg))
        hnorms.append(W(norm_rows(rg - p)))
    hat.loft(hrings, hnorms)
    band = cv.part("hatband", m["trim"], group="hatband", bands=(0.8, 1.6), highlight=0.5)
    F0 = _frame_from_dir(hc[1] - hc[0], Hh @ v3(1, 0, 0))
    b0, _ = _ring(hc[0] + F0 @ v3(0, 0, 0.4), F0, 6.75, 6.75, 16)
    b1, _ = _ring(hc[0] + F0 @ v3(0, 0, 2.2), F0, 6.2, 6.2, 16)
    band.loft([W(b0), W(b1)], [W(norm_rows(b0 - hc[0])), W(norm_rows(b1 - hc[0]))])

    # staff
    d = s["staff_dir"]
    shaft = cv.part("staff", m["wood"], group="staff", bands=(0.6, 1.2), highlight=0.4, vote=3.0)
    shaft.capsule(W(s["staff_bottom"]), W(s["staff_top"]), 1.05, 1.25)
    F = _frame_from_dir(d, v3(1, 0, 0))
    prong = cv.part("prongs", m["trim"], group="prongs", bands=(0.5, 1.0), highlight=0.4, vote=3.0)
    top = s["staff_top"]
    c = s["staff_tip"]
    for a in range(3):
        ang = a * 2 * math.pi / 3
        off = F @ v3(math.cos(ang), math.sin(ang), 0)
        prong.capsule(W(top - d * 0.5), W(top + off * 2.6 + d * 1.6), 0.9, 0.8)
        prong.capsule(W(top + off * 2.6 + d * 1.6), W(c + off * 1.4 + d * 2.0), 0.8, 0.6)
    crystal = cv.part("crystal", m["crystal"], group="crystal", bands=(0.8, 1.6), highlight=0.8, vote=2.0)
    ax, bx = F @ v3(1, 0, 0) * 2.3, F @ v3(0, 1, 0) * 2.3
    tip, bot = c + d * 3.6, c - d * 2.6
    ring4 = [c + ax, c + bx, c - ax, c - bx]
    for i in range(4):
        q0, q1 = ring4[i], ring4[(i + 1) % 4]
        crystal.tri([W(tip), W(q0), W(q1)])
        crystal.tri([W(bot), W(q1), W(q0)])


def norm_rows(a):
    return a / np.maximum(np.linalg.norm(a, axis=-1, keepdims=True), 1e-9)


def paint_face(out, cv, s, R):
    """Eyes and mouth are 1-2 px features, painted after the vote so they stay crisp."""
    pose = s["pose"]
    Hr = s["H"]
    names = [p.name for p in out["parts"]]
    if "head" not in names:
        return
    hi = names.index("head")
    owner = out["owner"]
    img = out["rgba"]
    expr = pose["expr"]
    skin = MAT["skin"].tones

    def spot(local):
        p = s["head"] + Hr @ v3(local)
        nrm = (R @ (Hr @ norm(v3(local)))) if True else None
        facing = -nrm[1] * 0.866 + nrm[2] * 0.5  # toward the camera
        x, y, _ = cv.to_px(R @ p)
        return int(math.floor(x)), int(math.floor(y)), facing

    def put(x, y, col):
        if 0 <= y < img.shape[0] and 0 <= x < img.shape[1] and owner[y, x] == hi:
            img[y, x, :3] = col

    eyes = [spot((sx * 2.2, 6.0, 0.2)) for sx in (-1, 1)]
    for (x, y, f) in eyes:
        if f < 0.25:
            continue
        if expr in ("blink", "hurt", "dead"):
            put(x, y + 1, skin[4])
            if expr == "hurt":
                put(x, y, skin[3])
        elif expr == "focus":
            put(x, y + 1, EYE)
            put(x, y, skin[3])
        else:
            put(x, y, EYE)
            put(x, y + 1, EYE)
    mx, my, mf = spot((0, 6.1, -2.9))
    if mf > 0.3:
        if expr in ("shout", "hurt"):
            put(mx, my, MOUTH)
            put(mx, my + 1, MOUTH)
        elif expr == "neutral":
            put(mx, my, skin[3])


# ----------------------------------------------------------------------------- animations

def _walk(t, length):
    p = (t / length) % 1.0
    A = 9.0

    def foot(ph, sx):
        ph %= 1.0
        if ph < 0.5:
            y = A * (1 - 4 * ph)
            z = 3.0
            toe = 0.0
        else:
            u = (ph - 0.5) * 2
            sm = u * u * (3 - 2 * u)
            y = -A + 2 * A * sm
            z = 3.0 + 4.2 * math.sin(math.pi * u)
            toe = -18 * math.sin(math.pi * u)
        return (sx * 3.8, y, z), toe

    fr, tr = foot(p, 1)
    fl, tl = foot(p + 0.5, -1)
    c = math.cos(2 * math.pi * p)
    bob = -0.3 - 0.9 * math.cos(4 * math.pi * p)
    return P(
        root=(0, 0, bob), lean=7.0, twist=-7.0 * c, roll=1.5 * c,
        head=(-2.0, 4.0 * c, -1.0 * c),
        foot_r=fr, foot_l=fl, toe_r=tr, toe_l=tl,
        hand_r=(10.0, 5.0 - 2.5 * c, 30.0 + bob), hand_l=(-9.0, 2.0 + 6.5 * c, 28.5 - 1.2 * abs(c)),
        staff=(0.12, 0.42 - 0.12 * c, 1.0),
    )


def _idle(t, length):
    p = (t / length) % 1.0
    b = math.sin(2 * math.pi * p)
    return P(
        root=(0, 0, -0.5 + 0.6 * b), lean=3.0 + 1.2 * b,
        head=(1.5 * b, 0, 0),
        hand_l=(-9.5, 1.5 + 0.6 * b, 29.0 + 0.8 * b),
        hand_r=(10.5, 4.0, 30.0 + 0.4 * b),
        staff=(0.10, 0.20 + 0.03 * b, 1.0),
        expr="blink" if 0.86 < p < 0.96 else "neutral",
    )


CAST_KEYS = [
    P(lean=-6, twist=16, root=(0, -1, -1.5), hand_r=(9, -4, 30), hand_l=(-6, 7, 34), staff=(0.1, -0.45, 1),
      head=(-6, 0, 0), foot_r=(3.8, -1.5, 3), foot_l=(-3.8, 1.5, 3), expr="focus"),
    P(lean=-4, twist=6, root=(0, 0, 0), hand_r=(8, 3, 48), hand_l=(-8.5, 4, 38), staff=(0.05, 0.1, 1),
      head=(-10, 0, 0), expr="focus", glow=0.5),
    P(lean=-2, twist=0, root=(0, 0, 0.6), hand_r=(7, 6, 52), hand_l=(-8, 6, 42), staff=(0, 0.3, 1),
      head=(-10, 0, 0), expr="focus", glow=1.0),
    P(lean=13, twist=-14, root=(0, 2.5, -1.5), hand_r=(6.5, 15, 40), hand_l=(-10, -3, 31), staff=(0, 1, 0.55),
      head=(-4, -4, 0), foot_r=(3.8, 6.5, 3), foot_l=(-3.8, -5.5, 3), toe_l=12, expr="shout", glow=1.0),
    P(lean=9, twist=-9, root=(0, 2, -1.0), hand_r=(7, 12, 36), hand_l=(-10, -1.5, 30), staff=(0, 0.8, 0.75),
      head=(-2, -2, 0), foot_r=(3.8, 6.5, 3), foot_l=(-3.8, -5.5, 3), toe_l=6, expr="neutral", glow=0.3),
    P(lean=4, twist=-2, root=(0, 0.5, -0.3), hand_r=(10, 6, 31), hand_l=(-9.5, 1.5, 29), staff=(0.1, 0.3, 1),
      foot_r=(3.8, 2.0, 3), foot_l=(-3.8, -1.5, 3), expr="neutral"),
]

HURT_KEYS = [
    P(lean=-13, root=(0, -2.5, -1.2), head=(-16, 0, 9), hand_r=(10.5, -1, 34), hand_l=(-12, 1, 36),
      staff=(0.25, -0.25, 1), expr="hurt"),
    P(lean=-7, root=(0, -2, -1.8), head=(-6, 0, 4), hand_r=(10.5, 1, 31), hand_l=(-11, 1, 32),
      staff=(0.2, -0.05, 1), expr="hurt"),
    P(lean=2, root=(0, -0.5, -0.6), head=(2, 0, 0), expr="neutral"),
]

DEATH_KEYS = [
    P(lean=-13, root=(0, -2.5, -1.2), head=(-16, 0, 9), hand_r=(10.5, -1, 34), hand_l=(-12, 1, 36),
      staff=(0.25, -0.25, 1), expr="hurt"),
    P(lean=-4, root=(0, -2, -6), head=(8, 0, 6), hand_r=(10, 2, 26), hand_l=(-10, 2, 25),
      staff=(0.35, 0.1, 1), foot_r=(3.8, 1, 3), foot_l=(-3.8, -1, 3), expr="hurt"),
    P(lean=14, root=(0, -1, -13), head=(18, 0, 4), hand_r=(9, 7, 17), hand_l=(-9, 6, 16),
      staff=(0.6, 0.45, 0.7), foot_r=(3.8, -3, 3), foot_l=(-3.8, -5, 3), toe_r=30, toe_l=30, expr="dead"),
    P(lean=55, root=(0, 5, -20), head=(25, 0, 6), hand_r=(10, 22, 8), hand_l=(-9, 21, 7),
      staff=(0.8, 0.6, 0.15), foot_r=(3.8, -9, 3), foot_l=(-3.8, -11, 3), toe_r=60, toe_l=60, expr="dead"),
    P(lean=82, root=(0, 10, -23.5), head=(10, 0, 12), hand_r=(10, 34, 3), hand_l=(-9, 33, 3),
      staff=(0.9, 0.42, 0.0), foot_r=(3.8, -15, 2.5), foot_l=(-4.5, -16, 2.5), toe_r=85, toe_l=85, expr="dead"),
]


def keyed(keys, contract_anim):
    times, t = [], 0
    for f in contract_anim["frames"]:
        times.append(t)
        t += f["ticks"]
    tl = Timeline(keys, times, t, contract_anim["loop"])
    return lambda tt, length: tl.sample(tt)


def animations(contract):
    a = contract["animations"]
    return {
        "idle": dict(sample=_idle, root_speed=0.0),
        "walk": dict(sample=_walk, root_speed=4 * 9.0 / sum(f["ticks"] for f in a["walk"]["frames"])),
        "cast": dict(sample=keyed(CAST_KEYS, a["cast"]), root_speed=0.0),
        "hurt": dict(sample=keyed(HURT_KEYS, a["hurt"]), root_speed=0.0),
        "death": dict(sample=keyed(DEATH_KEYS, a["death"]), root_speed=0.0),
    }


ANCHORS = ("staff_tip", "hand_r", "hand_l", "head", "chest")

# Sub-frames are a renderer choice, the contract never sees them.
SUBFRAMES = {
    "idle": [2, 2, 2, 2],
    "walk": [1] * 8,
    "cast": [2, 1, 1, 0, 1, 1],
    "hurt": [1, 1, 1],
    "death": [1, 1, 1, 1, 0],
}

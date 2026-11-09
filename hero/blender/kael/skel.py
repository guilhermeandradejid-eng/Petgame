"""Rest skeleton (A-pose) and position-based skin-weight fields."""
from math import sin, cos, radians
from mathutils import Vector
from .geo import ss

A_POSE = 45.0
LU, LF, LH = 0.255, 0.235, 0.085          # upper arm, forearm, hand (wrist -> knuckles)


def arm_dir(sx):
    return Vector((cos(radians(A_POSE)) * sx, 0.0, -sin(radians(A_POSE))))


def shoulder(sx):
    return Vector((0.150 * sx, 0.0, 1.278))


def elbow(sx):
    return shoulder(sx) + arm_dir(sx) * LU


def wrist(sx):
    return shoulder(sx) + arm_dir(sx) * (LU + LF)


def hip(sx):
    return Vector((0.082 * sx, 0.0, 0.875))


def knee(sx):
    return Vector((0.085 * sx, -0.004, 0.475))


def ankle(sx):
    return Vector((0.088 * sx, 0.010, 0.085))


def ball(sx):
    return Vector((0.090 * sx, -0.112, 0.022))


def hand_frame(sx):
    """Hand axes in the rest pose: X along the fingers, Y toward the thumb (character's front), Z back of the hand."""
    X = arm_dir(sx)
    Y = Vector((0.0, -1.0, 0.0))
    Z = Vector((cos(radians(A_POSE)) * sx, 0.0, sin(radians(A_POSE))))
    Z = (Z - X * Z.dot(X)).normalized()
    return X, Y, Z


GRIP_LOCAL = (0.060, 0.0, -0.026)         # sword grip centre in right-hand local coords


def grip_point():
    X, Y, Z = hand_frame(-1)
    return wrist(-1) + X * GRIP_LOCAL[0] + Y * GRIP_LOCAL[1] + Z * GRIP_LOCAL[2]


def bones(extra=()):
    """[(name, parent, head, tail)] in parent-first order."""
    B = [
        ("root", None, (0, 0, 0), (0, 0.2, 0)),
        ("hips", "root", (0, 0.004, 0.915), (0, 0.004, 1.0)),
        ("spine", "hips", (0, 0.004, 1.0), (0, 0.0, 1.12)),
        ("chest", "spine", (0, 0.0, 1.12), (0, 0.0, 1.30)),
        ("neck", "chest", (0, 0.010, 1.305), (0, 0.013, 1.375)),
        ("head", "neck", (0, 0.013, 1.375), (0, 0.013, 1.60)),
    ]
    for S, sx in (("L", 1), ("R", -1)):
        sh, el, wr = shoulder(sx), elbow(sx), wrist(sx)
        d = arm_dir(sx)
        B += [
            ("clavicle." + S, "chest", (0.022 * sx, 0.0, 1.272), tuple(sh - Vector((0.012 * sx, 0, 0)))),
            ("upper_arm." + S, "clavicle." + S, tuple(sh), tuple(el)),
            ("forearm." + S, "upper_arm." + S, tuple(el), tuple(wr)),
            ("forearm_twist." + S, "forearm." + S, tuple(el + d * (LF * 0.5)), tuple(wr)),
            ("hand." + S, "forearm." + S, tuple(wr), tuple(wr + d * LH)),
            ("thigh." + S, "hips", tuple(hip(sx)), tuple(knee(sx))),
            ("shin." + S, "thigh." + S, tuple(knee(sx)), tuple(ankle(sx))),
            ("foot." + S, "shin." + S, tuple(ankle(sx)), tuple(ball(sx))),
            ("toe." + S, "foot." + S, tuple(ball(sx)), (0.091 * sx, -0.192, 0.022)),
        ]
    g = grip_point()
    B.append(("weapon", "hand.R", tuple(g), tuple(g + Vector((0, -0.25, 0)))))
    for ch in extra:
        pts = ch["pts"]
        for i in range(len(pts) - 1):
            B.append(("%s%d" % (ch["name"], i + 1), ch["parent"] if i == 0 else "%s%d" % (ch["name"], i),
                      tuple(pts[i]), tuple(pts[i + 1])))
    return B


# ----------------------------------------------------------------------------
# weight fields
# ----------------------------------------------------------------------------
def _norm(w):
    w = {k: v for k, v in w.items() if v > 1e-4}
    t = sum(w.values())
    return {k: v / t for k, v in w.items()}


def w_torso(p):
    z, ax = p.z, abs(p.x)
    S = "L" if p.x >= 0 else "R"
    a = ss(0.955, 1.045, z)
    c = ss(1.07, 1.17, z)
    n = ss(1.285, 1.335, z)
    h = ss(1.352, 1.392, z)
    w = {"hips": 1 - a, "spine": a * (1 - c), "chest": c * (1 - n), "neck": n * (1 - h), "head": h}
    k = ss(0.075, 0.150, ax) * ss(1.175, 1.255, z) * (1 - n) * 0.7
    if k > 0:
        w["chest"] *= (1 - k)
        w["clavicle." + S] = k * c
    t = ss(0.905, 0.835, z) * ss(0.025, 0.075, ax) * 0.55
    if t > 0:
        w["hips"] *= (1 - t)
        w["thigh." + S] = t
    return _norm(w)


def w_arm(sx):
    S = "L" if sx > 0 else "R"
    sh, d = shoulder(sx), arm_dir(sx)

    def f(p):
        s = (p - sh).dot(d)
        k = 1 - ss(-0.045, 0.045, s)                 # shoulder cap follows clavicle/chest a little
        e = ss(LU - 0.04, LU + 0.04, s)
        t = ss(LU + 0.07, LU + LF - 0.03, s) * 0.8   # forearm twist share
        h = ss(LU + LF - 0.022, LU + LF + 0.012, s)
        w = {"clavicle." + S: k * 0.75, "chest": k * 0.25,
             "upper_arm." + S: (1 - k) * (1 - e),
             "forearm." + S: e * (1 - t) * (1 - h),
             "forearm_twist." + S: e * t * (1 - h),
             "hand." + S: h}
        return _norm(w)
    return f


def w_leg(sx):
    S = "L" if sx > 0 else "R"

    def f(p):
        z = p.z
        top = ss(0.80, 0.93, z)
        k = ss(0.475 + 0.05, 0.475 - 0.05, z)
        a = ss(0.155, 0.075, z)
        t = ss(-0.098, -0.128, p.y) * ss(0.095, 0.06, z)
        w = {"hips": top, "thigh." + S: (1 - top) * (1 - k), "shin." + S: k * (1 - a),
             "foot." + S: a * (1 - t), "toe." + S: a * t}
        return _norm(w)
    return f

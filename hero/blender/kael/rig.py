"""Pose solver (controls -> bone transforms) and spring-bone secondary motion.

Controls are written in "character space": V(side, forward, up) with +side = the character's left,
relative to the root bone. Arms are solved with IK from hand targets, legs with IK from foot plants,
the sword hand is oriented from the blade direction.
"""
from math import radians, degrees, sin, cos, sqrt, acos, atan2, pi
from mathutils import Vector, Matrix, Quaternion
from . import skel

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
FPS = 60


def V(s, f, u):
    return Vector((s, -f, u))


def eul(pitch, lean, turn):
    """Degrees. pitch>0 bows forward, lean>0 leans to the character's left, turn>0 turns left."""
    return (Matrix.Rotation(radians(turn), 3, "Z") @ Matrix.Rotation(radians(pitch), 3, "X")
            @ Matrix.Rotation(radians(lean), 3, "Y")).to_quaternion()


def frame(d, axis):
    y = d.normalized()
    x = axis - y * axis.dot(y)
    if x.length < 1e-6:
        x = y.orthogonal()
    x.normalize()
    return Matrix((x, y, x.cross(y))).transposed()


def arc(a, b):
    return a.normalized().rotation_difference(b.normalized())


def clampf(x, a, b):
    return max(a, min(b, x))


def smooth(a, b, x):
    t = clampf((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


AH = 0.085                                  # ankle height when the foot is flat
HEEL = Vector((0.0, 0.052, 0.0))            # contact points relative to the ankle's floor projection
BALL = Vector((0.0, -0.122, 0.022))
SHOULDER_C = Vector((0.0, 0.0, 1.278))      # origin of "chest space" (between the shoulders)
GRIP2 = -0.088                              # second hand, along the blade axis from the grip centre


class Rig:
    def __init__(self, bones):
        self.bones = bones
        self.names = [b[0] for b in bones]
        self.parent = {b[0]: b[1] for b in bones}
        self.RH = {b[0]: Vector(b[2]) for b in bones}
        self.RT = {b[0]: Vector(b[3]) for b in bones}
        self.RQ = None
        self.L1 = (self.RT["thigh.L"] - self.RH["thigh.L"]).length
        self.L2 = (self.RT["shin.L"] - self.RH["shin.L"]).length
        self.FR_T = {S: frame(self.RT["thigh." + S] - self.RH["thigh." + S], X).inverted() for S in "LR"}
        self.FR_S = {S: frame(self.RT["shin." + S] - self.RH["shin." + S], X).inverted() for S in "LR"}
        self.FR_A = {S: frame(skel.arm_dir(sx), Y).inverted() for S, sx in (("L", 1), ("R", -1))}
        self.M0 = {}
        for S, sx in (("L", 1), ("R", -1)):
            e0, b0, _ = skel.blade_axes(sx)
            self.M0[S] = frame(b0, e0).inverted()
        self.body = [n for n in self.names if n.split(".")[0] in (
            "root", "hips", "spine", "chest", "neck", "head", "clavicle", "upper_arm", "upper_arm_twist", "forearm",
            "forearm_twist",
            "hand", "thigh", "shin", "foot", "toe", "weapon")]
        self.dyn = [n for n in self.names if n not in self.body]
        self.edge_prev = None
        self.warn = {}

    def set_rest(self, arm):
        self.RQ = {b.name: b.matrix_local.to_3x3().to_quaternion() for b in arm.data.bones}

    # -- torso -----------------------------------------------------------------
    def torso(self, P, hip_pos=None):
        D, pos = {"root": Quaternion()}, {"root": Vector((0, 0, 0))}
        RH = self.RH
        D["hips"] = eul(*P["hipR"])
        pos["hips"] = (RH["hips"] + V(*P["hip"])) if hip_pos is None else hip_pos
        D["spine"] = D["hips"] @ eul(*P["spine"])
        pos["spine"] = pos["hips"] + D["hips"] @ (RH["spine"] - RH["hips"])
        D["chest"] = D["spine"] @ eul(*P["chest"])
        pos["chest"] = pos["spine"] + D["spine"] @ (RH["chest"] - RH["spine"])
        return D, pos

    def chest_space(self, D, pos):
        return pos["chest"] + D["chest"] @ (SHOULDER_C - self.RH["chest"]), D["chest"]

    def to_chest(self, P, v, direction=False):
        """Character-space point/direction -> chest-space tuple (side, fwd, up) for pose P."""
        D, pos = self.torso(P)
        C0, Dc = self.chest_space(D, pos)
        w = V(*v) if direction else (V(*v) - C0)
        l = Dc.inverted() @ w
        return (l.x, -l.y, l.z)

    # -- feet ------------------------------------------------------------------
    def ankle(self, foot, rot):
        s, f, lift = foot
        pitch, yaw = rot[0], rot[1]
        Rz = Matrix.Rotation(radians(yaw), 3, "Z")
        Rx = Matrix.Rotation(radians(-pitch), 3, "X")
        a = Vector((0, 0, AH))
        piv = HEEL if pitch > 0 else BALL
        A = V(s, f, 0) + Rz @ (piv + Rx @ (a - piv)) + Vector((0, 0, lift))
        g = clampf(1.0 - lift / 0.05, 0.0, 1.0)
        tp = pitch if pitch > 0 else pitch * (1.0 - g)
        return A, (Rz @ Rx).to_quaternion(), (Rz @ Matrix.Rotation(radians(-tp), 3, "X")).to_quaternion()

    # -- full solve --------------------------------------------------------------
    def solve(self, P):
        RH, RT = self.RH, self.RT
        feet = {S: self.ankle(P["foot" + S], P["foot" + S + "r"]) for S in "LR"}
        # keep planted feet reachable: pull the pelvis toward a foot that would over-extend the leg
        hip_pos = RH["hips"] + V(*P["hip"])
        Dh = eul(*P["hipR"])
        lmax = (self.L1 + self.L2) * 0.992
        for _ in range(4):
            for S in "LR":
                if P["foot" + S][2] > 0.03:
                    continue
                H = hip_pos + Dh @ (RH["thigh." + S] - RH["hips"])
                d = feet[S][0] - H
                if d.length > lmax:
                    hip_pos = hip_pos + d.normalized() * (d.length - lmax)
        D, pos = self.torso(P, hip_pos)
        Dc = D["chest"]
        C0 = pos["chest"] + Dc @ (SHOULDER_C - RH["chest"])
        # head: absolute look direction, shared 40/60 by neck and head, limited relative to the chest
        rel = Dc.inverted() @ eul(*P["look"])
        if rel.w < 0:
            rel = -rel
        ang = 2 * acos(clampf(rel.w, -1, 1))
        if ang > radians(78):
            rel = Quaternion(Vector((rel.x, rel.y, rel.z)).normalized(), radians(78))
        D["neck"] = Dc @ Quaternion().slerp(rel, 0.4)
        D["head"] = Dc @ rel
        pos["neck"] = pos["chest"] + Dc @ (RH["neck"] - RH["chest"])
        pos["head"] = pos["neck"] + D["neck"] @ (RH["head"] - RH["neck"])

        # arms
        blade = (Dc @ V(*P["blade"])).normalized()
        info = {}

        def arm(S, sx, Wt, hint, nat=None):
            cl, ua, fa, tw, ha = ("clavicle." + S, "upper_arm." + S, "forearm." + S, "forearm_twist." + S, "hand." + S)
            ut = "upper_arm_twist." + S
            sh0 = pos["chest"] + Dc @ (RH[ua] - RH["chest"])
            v = Dc.inverted() @ (Wt - sh0)
            r = max(v.length, 1e-4)
            up = clampf((v.z / r) * 26.0 + 3.0, -5.0, 26.0) + P["clav" + S][0]
            fw = clampf((-v.y / r) * 12.0 + (9.0 if v.x * sx < 0.02 else 0.0), -8.0, 18.0) + P["clav" + S][1]
            Qc = (Matrix.Rotation(radians(-sx * fw), 3, "Z") @ Matrix.Rotation(radians(-sx * up), 3, "Y")).to_quaternion()
            D[cl] = Dc @ Qc
            pos[cl] = pos["chest"] + Dc @ (RH[cl] - RH["chest"])
            Sh = pos[cl] + D[cl] @ (RH[ua] - RH[cl])
            d = Wt - Sh
            dist = clampf(d.length, 0.06, (skel.LU + skel.LF) * 0.997)
            along = d.normalized()
            a = (skel.LU ** 2 - skel.LF ** 2 + dist * dist) / (2 * dist)
            h = sqrt(max(skel.LU ** 2 - a * a, 0.0))
            hp = hint - along * hint.dot(along)
            if hp.length < 1e-4:
                hp = along.orthogonal()
            hp.normalize()
            if nat is not None:
                # the elbow follows the hand: with a relaxed forearm it points away from the thumb / blade,
                # which keeps pronation small instead of wringing the forearm
                nq = nat - along * nat.dot(along)
                c = nq.length
                if c > 1e-3:
                    hp = (hp * (1.0 - 0.6 * c) + nq * 0.6).normalized()
            El = Sh + along * a + hp * h
            Wr = Sh + along * dist
            # shoulder end: swing only (no roll against the torso); the roll lives in the twist bone further down
            D[ua] = arc(D[cl] @ skel.arm_dir(sx), El - Sh) @ D[cl]
            D[ut] = (frame(El - Sh, hp) @ self.FR_A[S]).to_quaternion()
            D[fa] = (frame(Wr - El, hp) @ self.FR_A[S]).to_quaternion()
            pos[ua], pos[fa], pos[ha] = Sh, El, Wr
            pos[ut] = Sh + (El - Sh) * 0.5
            pos[tw] = El + (Wr - El) * 0.5
            return Sh, El, Wr, (Wr - El).normalized()

        def twist(S, df):
            fa, tw, ha = "forearm." + S, "forearm_twist." + S, "hand." + S
            R = D[ha] @ D[fa].inverted()
            ax = Vector((R.x, R.y, R.z))
            pr = df * ax.dot(df)
            q = Quaternion((R.w, pr.x, pr.y, pr.z))
            if q.magnitude < 1e-6:
                q = Quaternion()
            q.normalize()
            if q.w < 0:
                q = -q
            D[tw] = Quaternion().slerp(q, 0.65) @ D[fa]
            return degrees(2 * atan2(Vector((q.x, q.y, q.z)).length, q.w))

        ShR, ElR, WrR, dfR = arm("R", -1, C0 + Dc @ V(*P["handR"]), Dc @ V(*P["elbR"]), -blade)
        # Blade roll. Free: least wrist strain (the edge lies in the forearm/blade plane, so a blade that lags
        # the forearm cuts edge-first). Keyed: an explicit roll angle about the blade, so the forearm can
        # pronate smoothly between a forehand and a backhand instead of flipping.
        refs = {"Y": Dc @ V(0, 0, 1), "P": Dc @ V(1, 0, 0)}

        def perp(v):
            r = v - blade * v.dot(blade)
            return r.normalized() if r.length > 1e-5 else blade.orthogonal().normalized()
        e = dfR - blade * dfR.dot(blade)
        conf = e.length
        if conf < 0.2 and self.edge_prev is not None:
            ep = self.edge_prev - blade * self.edge_prev.dot(blade)
            e = e + ep.normalized() * (0.2 - conf) * 4.0 if ep.length > 1e-4 else e
        if e.length < 1e-5:
            e = blade.orthogonal()
        e.normalize()
        if P["rollK"][0] > 0.5:
            # relaxed wrist wherever it is well defined; the keyed roll bridges the moments when the blade
            # lines up with the forearm (and two-handed swings, where it is forced)
            m = "P" if P["rollRef"][0] > 0.5 else "Y"
            ek = Quaternion(blade, radians(P["roll" + m][0])) @ perp(refs[m])
            wk = max(P["edgeW"][0], 1.0 - smooth(0.25, 0.6, conf))
            e = perp(e * (1 - wk) + ek * wk)
        self.edge_prev = e.copy()
        for m in "YP":
            r = perp(refs[m])
            info["roll" + m] = degrees(atan2(r.cross(e).dot(blade), r.dot(e)))
        D["hand.R"] = (frame(blade, e) @ self.M0["R"]).to_quaternion()
        info["pron"] = twist("R", dfR)
        D["weapon"] = D["hand.R"]
        pos["weapon"] = WrR + D["hand.R"] @ (RH["weapon"] - RH["hand.R"])
        info["wrist_dev"] = degrees(acos(clampf((D["hand.R"] @ skel.arm_dir(-1)).dot(dfR), -1, 1)))
        info["blade_fore"] = degrees(acos(clampf(blade.dot(dfR), -1, 1)))
        info["edge"], info["blade"] = e, blade
        info["tip"] = pos["weapon"] + blade * 0.915

        # left arm: free, or holding the grip below the right hand
        Wl = C0 + Dc @ V(*P["handL"])
        gw = clampf(P["gripL"][0], 0.0, 1.0)
        Dg, natL = None, None
        if gw > 0.001:
            Gp = pos["weapon"] + blade * GRIP2
            shl = pos["chest"] + Dc @ (RH["upper_arm.L"] - RH["chest"])
            eL = (Gp - shl)
            eL = eL - blade * eL.dot(blade)
            if eL.length < 1e-4:
                eL = e
            Dg = (frame(blade, eL) @ self.M0["L"]).to_quaternion()
            natL = -blade
            Xh, Yh, Zh = skel.hand_frame(1)
            Wg = Gp - Dg @ (Xh * skel.GRIP_LOCAL[0] + Zh * skel.GRIP_LOCAL[2])
            Wl = Wl.lerp(Wg, gw)
        ShL, ElL, WrL, dfL = arm("L", 1, Wl, Dc @ V(*P["elbL"]), natL if gw > 0.5 else None)
        fx, dv, tw = P["wristL"]
        Xh, Yh, Zh = skel.hand_frame(1)
        Qw = Quaternion(Xh, radians(tw)) @ Quaternion(Zh, radians(dv)) @ Quaternion(Yh, radians(fx))
        Df = D["forearm.L"] @ Qw
        D["hand.L"] = Df if Dg is None else Df.slerp(Dg, gw)
        twist("L", dfL)

        # legs
        for S, sx in (("L", 1), ("R", -1)):
            th, sn, ft, to = "thigh." + S, "shin." + S, "foot." + S, "toe." + S
            A, Dft, Dto = feet[S]
            H = pos["hips"] + D["hips"] @ (RH[th] - RH["hips"])
            kyaw = P["knee" + S][0] + 0.45 * P["hipR"][2] + 0.55 * P["foot" + S + "r"][1]
            hinge = Matrix.Rotation(radians(kyaw), 3, "Z") @ X
            to_ = A - H
            L = self.L1 + self.L2
            dist = to_.length
            if dist > L * 0.94:             # soft knee: never snaps fully straight
                da = L * 0.94
                dist = da + (L * 0.999 - da) * (1 - pow(2.718281828, -(dist - da) / (L * 0.999 - da)))
            dist = max(dist, 0.12)
            along = to_.normalized()
            A2 = H + along * dist
            a = (self.L1 ** 2 - self.L2 ** 2 + dist * dist) / (2 * dist)
            h = sqrt(max(self.L1 ** 2 - a * a, 0.0))
            fwd = along.cross(hinge)
            if fwd.length < 1e-4:
                fwd = Vector((0, -1, 0))
            Kn = H + along * a + fwd.normalized() * h
            D[th] = (frame(Kn - H, hinge) @ self.FR_T[S]).to_quaternion()
            D[sn] = (frame(A2 - Kn, hinge) @ self.FR_S[S]).to_quaternion()
            D[ft], D[to] = Dft, Dto
            pos[th], pos[sn], pos[ft] = H, Kn, A2
            pos[to] = A2 + Dft @ (RH[to] - RH[ft])
            info["leg" + S] = to_.length / L
        return D, pos, info

    def follow(self, D, pos):
        """Spring bones default to rigidly following their parents."""
        for n in self.dyn:
            p = self.parent[n]
            D[n] = D[p]
            pos[n] = pos[p] + D[p] @ (self.RH[n] - self.RH[p])

    def to_world(self, D, pos, root):
        """Character space -> stage space, given root (side, fwd, yaw)."""
        q = Quaternion(Z, radians(root[2]))
        o = V(root[0], root[1], 0.0)
        return {k: q @ v for k, v in D.items()}, {k: o + q @ v for k, v in pos.items()}

    def local(self, D):
        out = {}
        for b in self.names:
            p = self.parent[b]
            if b not in D:
                continue
            if p is None:
                out[b] = self.RQ[b].inverted() @ D[b] @ self.RQ[b]
            else:
                out[b] = self.RQ[b].inverted() @ D[p].inverted() @ D[b] @ self.RQ[b]
        return out


# ----------------------------------------------------------------------------
# spring bones (VRM-style verlet, shared 1:1 with the web viewer)
# ----------------------------------------------------------------------------
#          stiffness  drag  gravity  hit radius
SPRING = {
    "scarfA": (0.18, 0.20, 0.60, 0.030), "scarfB": (0.22, 0.22, 0.60, 0.030),
    "tail.L": (0.85, 0.24, 0.75, 0.030), "tail.R": (0.85, 0.24, 0.75, 0.030),
    "pony": (1.3, 0.30, 0.45, 0.022),
    "lock.L": (2.4, 0.36, 0.20, 0.012), "lock.R": (2.4, 0.36, 0.20, 0.012),
    "bang.C": (3.6, 0.45, 0.05, 0.0), "bang.L": (3.6, 0.45, 0.05, 0.0), "bang.R": (3.6, 0.45, 0.05, 0.0),
    "ahoge": (3.2, 0.34, 0.0, 0.0),
}
#            bone      centre (rest, metres)     radius   groups
COLLIDERS = [
    ("head", (0.0, 0.020, 1.490), 0.112, "hp"),
    ("head", (0.0, -0.012, 1.440), 0.094, "l"),
    ("chest", (0.0, 0.012, 1.270), 0.085, "hp"),
    ("chest", (0.0, 0.004, 1.180), 0.118, "s"),
    ("chest", (0.105, 0.012, 1.250), 0.070, "s"),
    ("chest", (-0.105, 0.012, 1.250), 0.070, "s"),
    ("spine", (0.0, 0.004, 1.040), 0.100, "s"),
    ("hips", (0.0, 0.008, 0.930), 0.118, "st"),
    ("thigh.L", (0.083, 0.0, 0.760), 0.082, "t"), ("thigh.R", (-0.083, 0.0, 0.760), 0.082, "t"),
    ("thigh.L", (0.085, 0.0, 0.610), 0.072, "t"), ("thigh.R", (-0.085, 0.0, 0.610), 0.072, "t"),
    ("shin.L", (0.086, 0.0, 0.430), 0.066, "t"), ("shin.R", (-0.086, 0.0, 0.430), 0.066, "t"),
]
GROUP = {"scarfA": "s", "scarfB": "s", "tail.L": "t", "tail.R": "t", "pony": "p", "lock.L": "l", "lock.R": "l",
         "ahoge": "", "bang.C": "", "bang.L": "", "bang.R": ""}


class Springs:
    def __init__(self, rig, chains):
        self.rig = rig
        self.chains = []
        for ch in chains:
            n = len(ch["pts"]) - 1
            names = ["%s%d" % (ch["name"], i + 1) for i in range(n)]
            self.chains.append(dict(name=ch["name"], parent=ch["parent"], bones=names,
                                    cols=[c for c in COLLIDERS if GROUP[ch["name"]] and GROUP[ch["name"]] in c[3]]))
        self.cur = None
        self.t = 0.0

    def reset(self, D, pos):
        rig = self.rig
        self.cur, self.prev = {}, {}
        for ch in self.chains:
            p = ch["parent"]
            for b in ch["bones"]:
                tail = pos[p] + D[p] @ (rig.RT[b] - rig.RH[p])
                self.cur[b] = tail.copy()
                self.prev[b] = tail.copy()

    def step(self, D, pos, dt=1.0 / FPS, breeze=1.0):
        """D/pos: stage-space body transforms. Writes spring bones into D/pos."""
        rig = self.rig
        if self.cur is None:
            self.reset(D, pos)
        self.t += dt
        t = self.t
        for ci, ch in enumerate(self.chains):
            stiff, drag, grav, hit = SPRING[ch["name"]]
            p = ch["parent"]
            head = pos[p] + D[p] @ (rig.RH[ch["bones"][0]] - rig.RH[p])
            Dp = D[p]
            cols = [(pos[c[0]] + D[c[0]] @ (Vector(c[1]) - rig.RH[c[0]]), c[2] + hit) for c in ch["cols"]]
            for i, b in enumerate(ch["bones"]):
                rest = rig.RT[b] - rig.RH[b]
                ln = rest.length
                rd = (Dp @ rest).normalized()
                cur, prev = self.cur[b], self.prev[b]
                gust = Vector((sin(t * 2.1 + i * 0.9 + ci * 1.7), 0.6 * sin(t * 1.3 + i * 0.6 + ci),
                               0.25 * sin(t * 3.3 + i * 1.3))) * (0.10 * breeze * grav)
                nxt = cur + (cur - prev) * (1.0 - drag) + rd * (stiff * dt) + (Vector((0, 0, -grav)) + gust) * dt
                nxt = head + (nxt - head).normalized() * ln
                for c, r in cols:
                    d = nxt - c
                    if d.length < r:
                        nxt = c + d.normalized() * r
                        nxt = head + (nxt - head).normalized() * ln
                self.prev[b], self.cur[b] = cur, nxt
                Db = arc(Dp @ rest, nxt - head) @ Dp
                D[b], pos[b] = Db, head
                head, Dp = nxt, Db

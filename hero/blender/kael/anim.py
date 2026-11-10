"""Animation clips, authored in code at 60 fps.

Method (see hero/ANIMATION.md):
  * key poses in character space (hand targets, blade direction, pelvis, torso twist, look target);
  * per-key 'hold' / 'pass' tangents + per-segment timing warps: slow anticipation, 3-5 frame strikes that
    pass through the contact pose at peak speed, overshoot, long settle;
  * successive breaking of joints: pelvis leads, then spine, chest, arm and blade, each a few frames later;
  * feet are plants in stage space with real steps (no sliding); attacks carry root motion;
  * every attack starts on the previous attack's hold pose, so combos chain without a pop;
  * hair / scarf / coat tails are spring bones simulated on top.
"""
from math import sin, cos, pi, radians, degrees, atan2, asin, sqrt
from .geo import ss, lerp, Curve

RIG = None
FPS = 60

DEFAULT = {
    "root": (0.0, 0.0, 0.0),
    "hip": (0.0, 0.0, 0.0), "hipR": (0.0, 0.0, 0.0), "spine": (0.0, 0.0, 0.0), "chest": (0.0, 0.0, 0.0),
    "look": (0.0, 0.0, 0.0), "clavL": (0.0, 0.0), "clavR": (0.0, 0.0),
    "handR": (-0.2, 0.1, -0.4), "elbR": (-0.5, -0.6, -0.6), "blade": (0.0, 1.0, 0.0),
    "rollY": (0.0,), "rollP": (0.0,), "edgeW": (0.0,), "rollRef": (0.0,), "rollK": (0.0,),
    "handL": (0.2, 0.1, -0.4), "elbL": (0.5, -0.6, -0.6), "wristL": (0.0, 0.0, 0.0), "gripL": (0.0,),
    "kneeL": (0.0,), "kneeR": (0.0,),
}
C2L = {"handR_c": ("handR", False), "handL_c": ("handL", False), "blade_c": ("blade", True),
       "elbR_c": ("elbR", True), "elbL_c": ("elbL", True)}
STAND = {"footL": (0.105, 0.02, 0.0), "footLr": (0.0, 8.0), "footR": (-0.165, 0.10, 0.0), "footRr": (0.0, -22.0)}


def init(rig):
    global RIG
    RIG = rig


def pose(base=None, **kw):
    """Build a pose. *_c entries are character-space and are converted to chest space with this pose's torso."""
    p = dict(DEFAULT if base is None else base)
    cs = {k: v for k, v in kw.items() if k in C2L}
    arms = {k: kw.pop(k) for k in ("armR", "armL") if k in kw}
    p.update({k: tuple(v) for k, v in kw.items() if k not in C2L})
    for k, (a, e, ext) in arms.items():
        # arm pointing along azimuth/elevation from the shoulder, `ext` of full reach
        S = k[-1]
        D, pos = RIG.torso(p)
        C0, Dc = RIG.chest_space(D, pos)
        sh = pos["chest"] + Dc @ (RIG.RH["upper_arm." + S] - RIG.RH["chest"])
        d = ang_to_dir((a, e), "yaw")
        from .rig import V
        from . import skel
        h = sh + V(*d) * ((skel.LU + skel.LF) * ext)
        l = Dc.inverted() @ (h - C0)
        p["hand" + S] = (l.x, -l.y, l.z)
    for k, v in cs.items():
        ch, is_dir = C2L[k]
        p[ch] = RIG.to_chest(p, v, is_dir)
    # blade roll of this pose with a relaxed wrist; keyed so it travels smoothly between poses
    RIG.edge_prev = None
    info = RIG.solve(dict(p, edgeW=(0.0,), rollK=(0.0,), **STAND))[2]
    forced = False
    for m in "YP":
        if "roll" + m in kw:
            forced = True
        else:
            p["roll" + m] = (info["roll" + m],)
    p["rollK"] = (1.0,)
    p["edgeW"] = (1.0,) if forced else (0.0,)
    return p


def warp(u, a, b):
    """Asymmetric ease: a>1 delays the start, b>1 stretches the settle."""
    if a == 1.0 and b == 1.0:
        return u
    if u <= 0.0:
        return 0.0
    if u >= 1.0:
        return 1.0
    x, y = u ** a, (1.0 - u) ** b
    return x / (x + y)


def dir_to_ang(v, mode):
    """Direction -> two angles (degrees). 'yaw': azimuth about the up axis (0 = forward, + = left) and elevation.
    'pitch': angle in the sagittal plane (0 = forward, 90 = up, 180 = back) and side tilt."""
    s, f, u = v
    n = sqrt(s * s + f * f + u * u) or 1.0
    if mode == "yaw":
        return [degrees(atan2(s, f)), degrees(asin(max(-1.0, min(1.0, u / n))))]
    return [degrees(atan2(u, f)), degrees(asin(max(-1.0, min(1.0, s / n))))]


def ang_to_dir(a, mode):
    x, y = radians(a[0]), radians(a[1])
    if mode == "yaw":
        return (sin(x) * cos(y), cos(x) * cos(y), sin(y))
    return (sin(y), cos(x) * cos(y), sin(x) * cos(y))


class Track:
    def __init__(self):
        self.keys = []
        self.dirmode = "yaw"      # how the blade direction travels between keys: arcs, never straight lines
        self._ang = None

    def angles(self):
        """Blade direction of every key as unwrapped angles, so interpolation always takes the short arc."""
        if self._ang is None or len(self._ang) != len(self.keys):
            out = []
            for i, k in enumerate(self.keys):
                a = dir_to_ang(k[1]["blade"], self.dirmode)
                if i:
                    a[0] += 360.0 * round((out[-1][0] - a[0]) / 360.0)
                a[0] += 360.0 * k[1].get("_turn", 0)
                out.append(a)
            self._ang = out
        return self._ang

    def key(self, f, p, mode="hold", ease=(1.0, 1.0)):
        """ease = (a, b) timing warp of the segment that ARRIVES at this key."""
        self.keys.append((float(f), p, mode, ease))
        self.keys.sort(key=lambda k: k[0])

    def rolls(self, ch):
        key = "_" + ch
        cur = getattr(self, key, None)
        if cur is None or len(cur) != len(self.keys):
            cur = []
            for i, k in enumerate(self.keys):
                a = k[1][ch][0]
                if i:
                    a += 360.0 * round((cur[-1] - a) / 360.0)
                cur.append(a)
            setattr(self, key, cur)
        return cur

    def _tan(self, i, ch, c):
        k = self.keys
        if i == 0 or i == len(k) - 1 or k[i][2] == "hold":
            return 0.0
        sc = k[i][2][1] if isinstance(k[i][2], tuple) else 1.0
        return sc * (k[i + 1][1][ch][c] - k[i - 1][1][ch][c]) / (k[i + 1][0] - k[i - 1][0])

    def sample(self, ch, f):
        k = self.keys
        if f <= k[0][0]:
            return k[0][1][ch]
        if f >= k[-1][0]:
            return k[-1][1][ch]
        i = 0
        while k[i + 1][0] < f:
            i += 1
        h = k[i + 1][0] - k[i][0]
        u = warp((f - k[i][0]) / h, *k[i + 1][3])
        h00, h10 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u
        h01, h11 = -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
        if ch in ("blade", "rollY", "rollP"):
            A = self.angles() if ch == "blade" else [[x] for x in self.rolls(ch)]
            nc = 2 if ch == "blade" else 1

            def tan(j, c):
                if j == 0 or j == len(k) - 1 or k[j][2] == "hold":
                    return 0.0
                return (A[j + 1][c] - A[j - 1][c]) / (k[j + 1][0] - k[j - 1][0])
            ang = [h00 * A[i][c] + h10 * h * tan(i, c) + h01 * A[i + 1][c] + h11 * h * tan(i + 1, c) for c in range(nc)]
            return ang_to_dir(ang, self.dirmode) if ch == "blade" else (ang[0],)
        a, b = k[i][1][ch], k[i + 1][1][ch]
        return tuple(h00 * a[c] + h10 * h * self._tan(i, ch, c) + h01 * b[c] + h11 * h * self._tan(i + 1, ch, c)
                     for c in range(len(a)))


class Foot:
    """Foot track in stage space: plants, eased steps, and root-relative flight phases."""

    def __init__(self, s, f, yaw):
        self.start = (s, f, yaw)
        self.segs = []          # (f0, f1, kind, data)
        self.heel = None        # Curve over frames: extra pitch (negative = heel raised) while planted

    def step(self, f0, f1, s, f, yaw=None, lift=0.06, off=18.0, land=5.0, e=(1.4, 1.4)):
        self.segs.append((float(f0), float(f1), "step", dict(to=(s, f), yaw=yaw, lift=lift, off=off, land=land, e=e)))

    def air(self, f0, f1, keys):
        """keys: [(frame, s, f, lift, pitch, yaw)] relative to the root; the last key is the landing."""
        self.segs.append((float(f0), float(f1), "air", dict(keys=keys)))

    def heels(self, *rows):
        self.heel = Curve(rows)

    def at(self, fr, root_at):
        s, f, yaw = self.start
        out = None
        for f0, f1, kind, d in sorted(self.segs, key=lambda x: x[0]):
            if kind == "step":
                ts, tf = d["to"]
                ty = yaw if d["yaw"] is None else d["yaw"]
            else:
                kk = d["keys"][-1]
                r = root_at(f1)
                c, sn = cos(radians(r[2])), sin(radians(r[2]))
                ts, tf = r[0] + kk[1] * c + kk[2] * sn, r[1] - kk[1] * sn + kk[2] * c
                ty = r[2] + kk[5]
            if fr >= f1:
                s, f, yaw = ts, tf, ty
                continue
            if fr <= f0:
                break
            u = (fr - f0) / (f1 - f0)
            if kind == "step":
                w = warp(u, *d["e"])
                lift = d["lift"] * sin(pi * u) ** 0.85
                pit = -d["off"] * sin(pi * min(u * 1.6, 1.0)) * (1 - u) + d["land"] * ss(0.55, 0.85, u) * (1 - ss(0.88, 1.0, u))
                out = (lerp(s, ts, w), lerp(f, tf, w), lift, pit, lerp(yaw, ty, ss(0, 1, u)))
            else:
                r0 = root_at(f0)
                c, sn = cos(radians(r0[2])), sin(radians(r0[2]))
                ds, df = s - r0[0], f - r0[1]
                rows = [(f0, ds * c - df * sn, ds * sn + df * c, 0.0, 0.0, yaw - r0[2])] + [tuple(k) for k in d["keys"]]
                v = Curve(rows)(fr)
                r = root_at(fr)
                c, sn = cos(radians(r[2])), sin(radians(r[2]))
                out = (r[0] + v[0] * c + v[1] * sn, r[1] - v[0] * sn + v[1] * c, v[2], v[3], r[2] + v[4])
            break
        if out is None:
            out = (s, f, 0.0, 0.0, yaw)
        if self.heel is not None:
            out = (out[0], out[1], out[2], out[3] + self.heel(fr)[0], out[4])
        return out


def breathe(P, t, amt=1.0):
    """Layered breathing / moving hold: belly -> chest -> shoulders -> head, exhale faster than inhale."""
    w = 2 * pi * t / 3.2

    def br(ph):
        x = sin(w - ph)
        return x + 0.22 * sin(2 * (w - ph))
    a = amt
    sway = sin(2 * pi * t / 6.4)
    P["hip"] = (P["hip"][0] + 0.004 * sway * a, P["hip"][1], P["hip"][2] + 0.0035 * br(0.0) * a)
    P["hipR"] = (P["hipR"][0] + 0.3 * br(0.2) * a, P["hipR"][1] + 0.5 * sway * a, P["hipR"][2])
    P["spine"] = (P["spine"][0] - 0.9 * br(0.35) * a, P["spine"][1] - 0.3 * sway * a, P["spine"][2])
    P["chest"] = (P["chest"][0] - 1.5 * br(0.7) * a, P["chest"][1] - 0.2 * sway * a, P["chest"][2] + 0.5 * sway * a)
    P["clavL"] = (P["clavL"][0] + 1.6 * br(1.1) * a, P["clavL"][1])
    P["clavR"] = (P["clavR"][0] + 1.6 * br(1.1) * a, P["clavR"][1])
    P["look"] = (P["look"][0] + 0.7 * br(1.6) * a, P["look"][1], P["look"][2] + 0.6 * sway * a)
    P["handR"] = (P["handR"][0] - 0.003 * br(1.3) * a, P["handR"][1] + 0.004 * br(1.5) * a, P["handR"][2] + 0.004 * br(1.2) * a)
    P["handL"] = (P["handL"][0] + 0.003 * br(1.3) * a, P["handL"][1] + 0.003 * br(1.7) * a, P["handL"][2] + 0.005 * br(1.25) * a)
    b = P["blade"]
    P["blade"] = (b[0] + 0.012 * br(1.9) * a, b[1], b[2] + 0.018 * br(1.7) * a)
    return P


SETTLE = {"hip": (10.0, 0.72), "hipR": (11.0, 0.62), "spine": (11.5, 0.56), "chest": (11.5, 0.56), "look": (12.0, 0.8)}


class Clip:
    def __init__(self, name, n, loop=False, speed=0.0):
        self.name, self.n, self.loop, self.speed = name, n, loop, speed
        self.track = Track()
        self.delay = {}
        self.feet = {}
        self.fn = None
        self.rootfn = None
        self.events = {}
        self.breath = 0.35
        self.settle = True
        self._baked = None

    def root(self, f):
        if self.fn:
            return (0.0, 0.0, 0.0)
        if self.rootfn:
            return self.rootfn(f)
        return self.track.sample("root", f)

    def raw(self, f):
        if self.fn:
            return self.fn(f)
        dl = dict(self.delay)
        dl["rollY"] = dl["rollP"] = dl.get("blade", 0.0)
        P = {ch: self.track.sample(ch, f - dl.get(ch, 0.0)) for ch in DEFAULT}
        r = P["root"] = self.root(f)
        P["rollRef"] = (1.0 if self.track.dirmode == "pitch" else 0.0,)
        c, sn = cos(radians(r[2])), sin(radians(r[2]))
        for S in "LR":
            s, fw, lift, pit, yaw = self.feet[S].at(f, self.root)
            ds, df = s - r[0], fw - r[1]
            P["foot" + S] = (ds * c - df * sn, ds * sn + df * c, lift)
            P["foot" + S + "r"] = (pit, yaw - r[2])
        breathe(P, f / FPS, self.breath)
        return P

    def controls(self, f):
        fi = int(round(f))
        if self.fn or not self.settle or abs(f - fi) > 1e-6 or fi < 0 or fi > self.n:
            return self.raw(f)
        if self._baked is None:
            self._bake()
        return dict(self._baked[fi])

    def _bake(self):
        """Pelvis, spine and head ride on under-damped springs: the body overshoots and settles after every
        key instead of stopping dead, which is most of what reads as weight."""
        frames = [self.raw(f) for f in range(self.n + 1)]
        st = {ch: [list(frames[0][ch]), [0.0] * len(frames[0][ch])] for ch in SETTLE}
        sub, dt = 4, 1.0 / (FPS * 4)
        for P in frames:
            for ch, (hz, zeta) in SETTLE.items():
                x, v = st[ch]
                w = 2 * pi * hz
                for _ in range(sub):
                    for i in range(len(x)):
                        v[i] += (w * w * (P[ch][i] - x[i]) - 2 * zeta * w * v[i]) * dt
                        x[i] += v[i] * dt
                P[ch] = tuple(x)
        self._baked = frames


# ----------------------------------------------------------------------------
# key poses
# ----------------------------------------------------------------------------
FEET = {"L": (0.105, 0.020, 8.0), "R": (-0.165, 0.100, -22.0)}
ELB_R, ELB_L = (-0.55, -0.70, -0.25), (0.60, -0.55, -0.35)
DELAY = {"spine": 1.0, "chest": 1.6, "handR": 2.4, "elbR": 2.4, "blade": 3.0, "handL": 1.8, "elbL": 1.8,
         "wristL": 2.5, "look": 0.5}


def az(a, e):
    """Blade direction from azimuth (0 = forward, + = left) and elevation, degrees."""
    return ang_to_dir((a, e), "yaw")


def idle_pose():
    """Weight on the left leg, sword resting on the right shoulder, left hand on the hip."""
    return pose(hip=(0.035, 0.0, -0.022), hipR=(1, -5, -12), spine=(-1, 3, -3), chest=(-2, 3, -3), look=(-2, 1.5, 0),
                handR_c=(-0.185, 0.135, 1.225), blade_c=az(-172, 28), elbR_c=(-0.3, 0.25, -0.9),
                handL_c=(0.225, 0.02, 0.935), elbL_c=(0.75, -0.6, 0.05), wristL=(25, 0, -30))


def keyed(name, n, rows, mode="yaw", delay=None):
    """rows: (frame, pose, hold|pass, ease, root forward[, root yaw])."""
    c = Clip(name, n)
    c.track.dirmode = mode
    for r in rows:
        f, p, m, e, rf = r[:5]
        c.track.key(f, dict(p, root=(0.0, rf, r[5] if len(r) > 5 else 0.0)), m, e)
    c.delay = dict(DELAY if delay is None else delay)
    return c


def make_clips():
    I = idle_pose()
    clips = []
    lr = FEET["L"], FEET["R"]

    # ---- Idle ------------------------------------------------------------------
    c = Clip("Idle", 384, loop=True)

    def idle_fn(f, I=I):
        P = dict(I, edgeW=(0.0,), rollK=(0.0,))
        for S in "LR":
            P["foot" + S] = (FEET[S][0], FEET[S][1], 0.0)
            P["foot" + S + "r"] = (0.0, FEET[S][2])
        return breathe(P, f / FPS, 1.0)
    c.fn = idle_fn
    clips.append(c)

    # ---- Run -------------------------------------------------------------------
    clips.append(run_clip())

    # recovery breakdown: sword travels over the top back to the shoulder
    def back_to_shoulder(yaw, e=78):
        return pose(I, hip=(0.025, 0.03, -0.07), hipR=(5, -2, yaw * 0.3), spine=(2, 1, yaw * 0.1), chest=(1, 2, yaw * 0.15),
                    look=(0, 0, 2), armR=(-30, 18, 0.62), blade_c=az(-70 if yaw <= 0 else -55, e), elbR_c=(-0.5, 0.2, -0.8),
                    armL=(120, -55, 0.70), elbL_c=(0.7, -0.6, -0.2), wristL=(15, 0, -15))

    # ---- Attack 1: diagonal cut off the shoulder, high right -> low left, stomping lunge ----------
    A1 = pose(I, hip=(-0.03, -0.04, 0.005), hipR=(-5, -3, -32), spine=(-4, -2, -9), chest=(-7, -3, -13), look=(2, 0, -4),
              armR=(-66, 66, 0.86), blade_c=az(-160, 30), elbR_c=(-0.7, 0.2, -0.6),
              armL=(10, -8, 0.78), elbL_c=(0.7, -0.3, -0.6), wristL=(0, 0, -30))
    C1 = pose(I, hip=(0.0, 0.05, -0.12), hipR=(10, 1, -4), spine=(6, 1, 4), chest=(6, 2, 8), look=(4, 0, 0),
              armR=(-6, 4, 0.97), blade_c=az(-40, 42), elbR_c=(-0.6, -0.3, -0.7),
              armL=(95, -60, 0.60), elbL_c=ELB_L, wristL=(20, 0, -10))
    F1 = pose(I, hip=(0.05, 0.08, -0.25), hipR=(18, 4, 28), spine=(10, 4, 10), chest=(9, 4, 15), look=(6, -2, 6),
              armR=(60, -50, 0.96), blade_c=az(20, -38), elbR_c=(-0.4, 0.2, -0.9),
              armL=(162, 24, 0.94), elbL_c=(0.5, -0.6, -0.6), wristL=(0, 0, -20))
    H1 = pose(I, hip=(0.045, 0.07, -0.225), hipR=(16, 4, 25), spine=(9, 4, 9), chest=(8, 4, 14), look=(5, -2, 5),
              armR=(58, -48, 0.94), blade_c=az(26, -35), elbR_c=(-0.4, 0.2, -0.9),
              armL=(158, 18, 0.90), elbL_c=(0.5, -0.6, -0.6), wristL=(0, 0, -20))
    H1b = pose(H1, hip=(0.043, 0.068, -0.22), armR=(57.5, -47.5, 0.935), blade_c=az(28, -34))
    adv = 0.34
    c = keyed("Attack1", 56, ((0, I, "hold", (1, 1), 0.0), (5.5, A1, "hold", (1.0, 1.8), 0.02),
                              (10, C1, "pass", (2.0, 1.0), 0.24), (13.5, F1, "hold", (1.0, 1.9), adv - 0.01),
                              (18.5, H1, "hold", (1.3, 1.6), adv), (27, H1b, "hold", (1, 1), adv),
                              (38, back_to_shoulder(8), "pass", (1.6, 1.0), adv), (52, I, "hold", (1.0, 1.8), adv)))
    L, R = Foot(*lr[0]), Foot(*lr[1])
    L.step(4, 10.5, 0.13, 0.50, yaw=6, lift=0.08, off=8, land=4, e=(1.2, 2.2))
    R.heels((0, 0), (7, 0), (11, -30), (18, -44), (36, -40), (37, 0), (56, 0))
    R.step(12, 18, -0.175, 0.20, yaw=-16, lift=0.012, off=0, land=0)
    R.step(37, 47, -0.165, 0.10 + adv, yaw=-22, lift=0.05, off=8, land=4)
    L.step(44, 52, 0.105, 0.02 + adv, yaw=8, lift=0.03, off=0, land=0)
    c.feet = {"L": L, "R": R}
    c.events = {"hit": 12, "cancel": 22, "move": 34, "stomp": 10}
    clips.append(c)

    # ---- Attack 2: wide horizontal backhand, left -> right, passing step ------------------------
    A2 = pose(I, hip=(0.045, 0.04, -0.21), hipR=(12, 3, 32), spine=(6, 3, 12), chest=(6, 3, 18), look=(6, 0, 10),
              armR=(88, -20, 0.70), blade_c=az(134, -8), elbR_c=(-0.3, 0.6, -0.7),
              armL=(140, -30, 0.75), elbL_c=(0.5, -0.7, -0.3), wristL=(10, 0, -20))
    C2 = pose(I, hip=(-0.03, 0.07, -0.20), hipR=(9, -2, -6), spine=(4, -2, -2), chest=(4, -3, -2), look=(4, 2, 0),
              armR=(8, -4, 0.97), blade_c=az(62, 2), elbR_c=(-0.6, -0.2, -0.75),
              armL=(70, -40, 0.65), elbL_c=ELB_L, wristL=(10, 0, -10))
    F2 = pose(I, hip=(-0.10, 0.07, -0.25), hipR=(8, 2, -38), spine=(2, 4, -12), chest=(-2, 5, -18), look=(2, -3, 4),
              armR=(-112, 28, 0.985), blade_c=az(-64, 36), elbR_c=(-0.3, -0.6, -0.7),
              armL=(118, -52, 0.90), elbL_c=(0.6, -0.6, -0.4), wristL=(0, 0, -20))
    H2 = pose(I, hip=(-0.09, 0.065, -0.23), hipR=(8, 2, -34), spine=(2, 3, -10), chest=(-1, 4, -15), look=(2, -3, 3),
              armR=(-111, 24, 0.975), blade_c=az(-70, 32), elbR_c=(-0.3, -0.6, -0.7),
              armL=(116, -54, 0.88), elbL_c=(0.6, -0.6, -0.4), wristL=(0, 0, -20))
    H2b = pose(H2, hip=(-0.088, 0.063, -0.225), armR=(-110.5, 23, 0.97), blade_c=az(-72, 30))
    adv2 = 0.36
    c = keyed("Attack2", 56, ((0, H1b, "hold", (1, 1), 0.0), (6, A2, "hold", (1.3, 1.6), 0.03),
                              (10, C2, "pass", (2.0, 1.0), 0.25), (13.5, F2, "hold", (1.0, 1.9), adv2 - 0.01),
                              (18.5, H2, "hold", (1.3, 1.6), adv2), (27, H2b, "hold", (1, 1), adv2),
                              (38, back_to_shoulder(-12, 72), "pass", (1.6, 1.0), adv2), (52, I, "hold", (1.0, 1.8), adv2)))
    L, R = Foot(0.13, 0.50 - adv, 6.0), Foot(-0.175, 0.20 - adv, -16.0)
    R.heels((0, -40), (3, -40), (4, 0), (56, 0))
    R.step(3, 10.5, -0.36, 0.54, yaw=-30, lift=0.08, off=0, land=6, e=(1.2, 2.0))
    L.heels((0, 0), (10, 0), (15, -30), (36, -34), (37, 0), (56, 0))
    L.step(37, 47, 0.105, 0.02 + adv2, yaw=8, lift=0.05, off=8, land=4)
    R.step(42, 52, -0.165, 0.10 + adv2, yaw=-22, lift=0.04, off=6, land=4)
    c.feet = {"L": L, "R": R}
    c.events = {"hit": 13, "cancel": 23, "move": 35, "stomp": 10}
    clips.append(c)

    # ---- Attack 3: hop and a full clockwise spin, the blade comes round as one wide slash ---------
    W3 = pose(I, hip=(-0.02, 0.02, -0.24), hipR=(10, -2, -34), spine=(4, -2, -12), chest=(2, -3, -16), look=(2, 0, -8),
              armR=(-128, 6, 0.97), blade_c=az(-86, 10), elbR_c=(-0.3, -0.6, -0.7),
              armL=(40, -12, 0.80), elbL_c=(0.6, -0.4, -0.6), wristL=(0, 0, -20))
    S3 = pose(I, hip=(0.0, 0.03, 0.15), hipR=(6, 6, -12), spine=(3, 4, -4), chest=(4, 4, -8), look=(4, 0, -14),
              armR=(-100, -2, 0.99), blade_c=az(-58, 0), elbR_c=(-0.3, -0.6, -0.7),
              armL=(75, -48, 0.45), elbL_c=(0.5, -0.5, -0.7), wristL=(30, 0, 0))
    L3 = pose(I, hip=(0.02, 0.05, -0.29), hipR=(14, -3, -34), spine=(7, -3, -12), chest=(6, -4, -18), look=(4, 0, 0),
              armR=(-126, -8, 0.98), blade_c=az(-80, -6), elbR_c=(-0.3, -0.6, -0.7),
              armL=(30, -64, 0.94), elbL_c=(0.7, -0.2, -0.3), wristL=(-30, 0, 0))
    H3 = pose(L3, hip=(0.02, 0.05, -0.255), hipR=(12, -3, -32), armR=(-125, -7, 0.975), blade_c=az(-82, -5),
              armL=(34, -62, 0.90))
    H3b = pose(H3, hip=(0.02, 0.048, -0.25), blade_c=az(-83, -4))
    adv3 = 0.30

    def root3(f):
        u = max(0.0, min(1.0, (f - 3.5) / 13.5))
        return (0.0, adv3 * ss(3.0, 16.5, f), -360.0 * warp(u, 1.7, 1.5))
    c = keyed("Attack3", 62, ((0, H2b, "hold", (1, 1), 0.0), (4, W3, "hold", (1.0, 1.5), 0.0), (10, S3, "pass", (1.2, 1.0), 0.0),
                              (16.5, L3, "hold", (1.0, 1.3), 0.0), (22, H3, "hold", (1, 1), 0.0), (30, H3b, "hold", (1, 1), 0.0),
                              (44, back_to_shoulder(-12, 72), "pass", (1.6, 1.0), 0.0), (58, I, "hold", (1.0, 1.8), 0.0)),
              delay={"spine": 0.6, "chest": 1.0, "handR": 1.6, "elbR": 1.6, "blade": 2.2, "handL": 1.2, "elbL": 1.2, "look": 0.3})
    c.rootfn = root3
    L, R = Foot(0.13, 0.16 - adv2, 6.0), Foot(-0.36, 0.54 - adv2, -30.0)
    L.heels((0, -34), (3, -42), (4, 0), (62, 0))
    R.heels((0, 0), (2, 0), (4.5, -36), (5, 0), (16, 0), (17, -8), (39, -8), (40, 0), (62, 0))
    L.air(4, 16, [(9, 0.11, 0.10, 0.34, -35, 8), (13, 0.13, 0.20, 0.20, -8, 10), (16, 0.14, 0.24, 0.0, 6, 12)])
    R.air(4.5, 16.5, [(9, -0.14, -0.14, 0.30, -55, -20), (13, -0.17, -0.22, 0.16, -35, -30),
                      (16.5, -0.19, -0.24, 0.0, -24, -34)])
    L.step(40, 50, 0.105, 0.02 + adv3, yaw=8 - 360, lift=0.04, off=0, land=3)
    R.step(46, 56, -0.165, 0.10 + adv3, yaw=-22 - 360, lift=0.04, off=6, land=3)
    c.feet = {"L": L, "R": R}
    c.events = {"hit": 13, "cancel": 25, "move": 38, "stomp": 16}
    clips.append(c)

    # ---- Attack 4: leap and two-handed helm breaker ------------------------------------------------
    ROLL4 = -90.0
    G4 = pose(I, rollP=(ROLL4,), hip=(0.0, -0.01, -0.17), hipR=(8, 0, -16), spine=(4, 0, -5), chest=(4, 0, -7), look=(2, 0, 0),
              handR_c=(-0.16, 0.02, 1.47), blade_c=(-0.10, -0.70, 0.70), elbR_c=(-0.8, 0.1, -0.5),
              handL_c=(0.20, 0.20, 1.10), elbL_c=(0.8, 0.0, -0.6), gripL=(0.5,))
    A4 = pose(I, rollP=(ROLL4,), hip=(0.0, 0.0, -0.26), hipR=(15, 0, -6), spine=(6, 0, -2), chest=(6, 0, -2), look=(-8, 0, 0),
              handR_c=(-0.08, -0.02, 1.42), blade_c=(0.0, -0.97, 0.05), elbR_c=(-0.9, 0.3, -0.2),
              elbL_c=(0.9, 0.3, -0.2), gripL=(1.0,))
    TO = pose(I, rollP=(ROLL4,), hip=(0.0, 0.10, 0.0), hipR=(4, 0, 0), spine=(0, 0, 0), chest=(-4, 0, 0), look=(-6, 0, 0),
              handR_c=(-0.06, -0.06, 1.74), blade_c=(0.0, -0.90, 0.35), elbR_c=(-0.9, 0.3, 0.0),
              elbL_c=(0.9, 0.3, 0.0), gripL=(1.0,))
    AP = pose(I, rollP=(ROLL4,), hip=(0.0, 0.0, 0.44), hipR=(-14, 0, 0), spine=(-9, 0, 0), chest=(-11, 0, 0), look=(4, 0, 0),
              handR_c=(-0.05, -0.28, 2.10), blade_c=(0.0, -0.75, -0.55), elbR_c=(-0.9, 0.2, 0.2),
              elbL_c=(0.9, 0.2, 0.2), gripL=(1.0,))
    C4 = pose(I, rollP=(ROLL4,), hip=(0.0, 0.0, 0.16), hipR=(16, 0, 0), spine=(8, 0, 0), chest=(10, 0, 0), look=(10, 0, 0),
              handR_c=(-0.03, 0.46, 1.52), blade_c=(0.0, 0.45, 0.88), elbR_c=(-0.9, -0.2, -0.3),
              elbL_c=(0.9, -0.2, -0.3), gripL=(1.0,))
    LD = pose(I, rollP=(ROLL4,), hip=(0.0, 0.02, -0.40), hipR=(26, 0, 4), spine=(11, 0, 2), chest=(11, 0, 2), look=(18, 0, 0),
              handR_c=(-0.02, 0.50, 0.60), blade_c=(0.0, 0.80, -0.60), elbR_c=(-0.9, -0.3, -0.3),
              elbL_c=(0.9, -0.3, -0.3), gripL=(1.0,))
    OV = pose(LD, hip=(0.0, 0.03, -0.35), hipR=(22, 0, 4), handR_c=(-0.02, 0.50, 0.68), blade_c=(0.0, 0.85, -0.52))
    H4 = pose(LD, hip=(0.0, 0.02, -0.37), handR_c=(-0.02, 0.50, 0.625), blade_c=(0.0, 0.81, -0.585), look=(14, 0, 0))
    H4b = pose(H4, hip=(0.0, 0.02, -0.36), look=(10, 0, 0))
    R4 = pose(I, rollP=(ROLL4,), hip=(0.02, 0.02, -0.10), hipR=(6, -2, -4), spine=(2, 1, -1), chest=(1, 2, -2), look=(0, 0, 0),
              handR_c=(-0.14, 0.26, 1.16), blade_c=(-0.10, 0.25, 0.96), elbR_c=(-0.6, 0.1, -0.8),
              handL_c=(0.24, 0.10, 0.95), elbL_c=(0.7, -0.6, -0.2), gripL=(0.0,))
    adv4, rise = 1.10, 0.24
    c = keyed("Attack4", 86, ((0, H3b, "hold", (1, 1), 0.0), (7, G4, "pass", (1, 1), 0.0), (12, A4, "hold", (1.0, 1.5), 0.02),
                              (14.5, TO, "pass", (1.8, 1.0), 0.16), (20.5, AP, "pass", (1, 1), 0.62),
                              (24.5, C4, "pass", (1, 1), 0.92), (27.5, LD, "hold", (1.0, 1.2), adv4 - 0.02),
                              (30.5, OV, "hold", (1, 1), adv4), (36, H4, "hold", (1, 1), adv4), (48, H4b, "hold", (1, 1), adv4),
                              (66, R4, "pass", (1.6, 1.0), adv4 + rise * 0.8), (80, I, "hold", (1.0, 1.8), adv4 + rise)),
              mode="pitch",
              delay={"spine": 0.5, "chest": 0.9, "handR": 1.2, "elbR": 1.2, "elbL": 1.2, "blade": 1.8, "handL": 1.2, "look": 0.4})
    L, R = Foot(0.14, 0.24, 12.0), Foot(-0.19, -0.24, -34.0)
    R.heels((0, -8), (8, -4), (12, -10), (14.5, -42), (15.5, 0), (27, 0), (28, -8), (53, -8), (54, 0), (86, 0))
    L.heels((0, 0), (12, 0), (14.5, -30), (15.5, 0), (86, 0))
    L.air(14.5, 26.5, [(17.5, 0.13, -0.24, 0.34, -60, 12), (21.5, 0.13, 0.04, 0.62, -20, 12), (24.5, 0.14, 0.24, 0.26, 0, 10),
                       (26.5, 0.14, 0.26, 0.0, 6, 10)])
    R.air(14.5, 27, [(17.5, -0.16, -0.14, 0.40, -55, -12), (21.5, -0.15, -0.32, 0.70, -72, -20),
                     (24.5, -0.16, -0.26, 0.26, -40, -32), (27, -0.165, -0.20, 0.0, -30, -36)])
    R.step(54, 66, -0.165, 0.10 + adv4 + rise, yaw=-22, lift=0.05, off=8, land=3)
    L.step(70, 78, 0.105, 0.02 + adv4 + rise, yaw=8, lift=0.02, off=0, land=0)
    c.feet = {"L": L, "R": R}
    c.events = {"hit": 27, "cancel": 50, "move": 58, "stomp": 27}
    clips.append(c)

    # ---- Stinger: chamber, then one long gliding thrust ---------------------------------------------
    CH = pose(I, hip=(-0.02, -0.04, -0.20), hipR=(8, -2, -42), spine=(4, -2, -10), chest=(4, -2, -12), look=(4, 0, 0),
              armR=(-142, -28, 0.55), blade_c=az(-6, 2), elbR_c=(-0.3, -0.9, 0.1),
              armL=(4, -6, 0.90), elbL_c=(0.6, -0.3, -0.7), wristL=(0, 0, -40))
    TH = pose(I, hip=(0.02, 0.14, -0.31), hipR=(32, 2, 24), spine=(9, 2, 9), chest=(9, 2, 13), look=(4, 0, 0),
              armR=(-8, 0, 1.0), blade_c=az(-4, 1), elbR_c=(-0.5, -0.2, -0.8),
              armL=(170, -8, 0.96), elbL_c=(0.5, -0.5, -0.6), wristL=(0, 0, -20))
    GL = pose(TH, hip=(0.02, 0.12, -0.32), hipR=(31, 2, 22), armR=(-7, -0.5, 0.995), blade_c=az(-3, 0), armL=(168, -10, 0.94))
    GL2 = pose(GL, hip=(0.02, 0.11, -0.315), armL=(164, -14, 0.92))
    BR = pose(I, hip=(0.01, 0.02, -0.21), hipR=(16, 1, 14), spine=(6, 1, 6), chest=(6, 1, 8), look=(5, 0, 0),
              armR=(-6, -5, 0.96), blade_c=az(-2, -3), elbR_c=(-0.5, -0.2, -0.8),
              armL=(150, -32, 0.80), elbL_c=(0.5, -0.5, -0.6), wristL=(0, 0, -20))
    dist_s = 3.42

    def sroot(f):
        if f <= 8.0:
            return (0.0, 0.0525 * max(f, 0.0), 0.0)
        u = min(1.0, (f - 8.0) / 15.0)
        return (0.0, 0.42 + 3.0 * (1 - (1 - u) ** 2.6), 0.0)
    # it starts from the dash glide, scoops the trailing blade down and forward, then commits
    DS = pose(I, hip=(0.0, 0.02, -0.18), hipR=(32, 0, -6), spine=(8, 0, 0), chest=(6, 0, 0), look=(6, 0, 0),
              handR_c=(-0.30, -0.02, 0.76), blade_c=(-0.20, -0.88, -0.43), elbR_c=(-0.6, -0.6, 0.5),
              handL_c=(0.30, -0.02, 0.80), elbL_c=(0.6, -0.6, 0.5), wristL=(10, 0, 0))
    c = keyed("Stinger", 62, ((0, DS, "hold", (1, 1), 0.0), (7, CH, "hold", (1.3, 1.6), 0.0), (11.5, TH, "pass", (2.2, 1.0), 0.0),
                              (14, GL, "hold", (1.0, 1.2), 0.0), (22, GL2, "hold", (1, 1), 0.0),
                              (28, BR, "hold", (1.2, 1.5), 0.0), (43, back_to_shoulder(6), "pass", (1.6, 1.0), 0.0),
                              (57, I, "hold", (1.0, 1.8), 0.0)),
              mode="pitch",
              delay={"spine": 0.5, "chest": 0.9, "handR": 1.4, "elbR": 1.4, "blade": 1.4, "handL": 1.6, "elbL": 1.6, "look": 0.3})
    c.rootfn = sroot
    L, R = Foot(0.12, 0.30, 6.0), Foot(-0.165, -0.40, -12.0)
    L.air(0, 23, [(7, 0.11, 0.30, 0.04, 0, 4), (12, 0.11, 0.50, 0.03, -6, 4), (19, 0.11, 0.52, 0.02, 0, 4),
                  (23, 0.11, 0.46, 0.0, 0, 6)])
    R.air(0, 30, [(7, -0.17, -0.30, 0.05, -30, -30), (13, -0.16, -0.72, 0.09, -64, -18), (22, -0.16, -0.70, 0.06, -60, -18),
                  (30, -0.165, -0.26, 0.0, -12, -22)])
    R.step(35, 45, -0.165, 0.10 + dist_s, yaw=-22, lift=0.05, off=8, land=4)
    L.step(43, 53, 0.105, 0.02 + dist_s, yaw=8, lift=0.03, off=0, land=0)
    c.feet = {"L": L, "R": R}
    c.events = {"hit": 12, "hitEnd": 22, "cancel": 31, "move": 37}
    clips.append(c)

    # ---- Dash ----------------------------------------------------------------------
    D1 = pose(I, hip=(0.0, 0.06, -0.16), hipR=(26, 0, -10), spine=(8, 0, -2), chest=(8, 0, -3), look=(-2, 0, 0),
              handR_c=(-0.30, -0.10, 0.80), blade_c=(-0.25, -0.75, -0.60), elbR_c=(-0.6, -0.7, 0.2),
              handL_c=(0.28, -0.10, 0.84), elbL_c=(0.6, -0.7, 0.2), wristL=(10, 0, 0))
    D2 = pose(I, hip=(0.0, 0.04, -0.22), hipR=(40, 0, -4), spine=(8, 0, 0), chest=(6, 0, 0), look=(6, 0, 0),
              handR_c=(-0.30, -0.02, 0.72), blade_c=(-0.20, -0.88, -0.43), elbR_c=(-0.6, -0.6, 0.5),
              handL_c=(0.30, -0.02, 0.76), elbL_c=(0.6, -0.6, 0.5), wristL=(10, 0, 0))
    D3 = pose(D2, hip=(0.0, 0.02, -0.18), hipR=(32, 0, -6), handR_c=(-0.30, -0.02, 0.76), handL_c=(0.30, -0.02, 0.80))
    D4 = pose(I, hip=(0.0, -0.05, -0.14), hipR=(6, 0, -22), spine=(0, 0, -5), chest=(-2, 0, -5), look=(2, 0, 0),
              handR_c=(-0.30, 0.22, 0.90), blade_c=(-0.30, 0.85, -0.40), elbR_c=ELB_R,
              handL_c=(0.30, 0.34, 1.00), elbL_c=ELB_L, wristL=(0, 0, -10))
    dist = 2.60

    def droot(f):
        u = max(0.0, min(1.0, (f - 2.0) / 16.0))
        return (0.0, dist * (1 - (1 - u) ** 2.2), 0.0)
    c = keyed("Dash", 40, ((0, I, "hold", (1, 1), 0.0), (3, D1, "pass", (1, 1), 0.0), (7, D2, "hold", (1, 1.3), 0.0),
                           (14, D3, "pass", (1, 1), 0.0), (19, D4, "hold", (1.0, 1.4), 0.0),
                           (36, I, "hold", (1.5, 1.8), 0.0)),
              delay={"spine": 0.6, "chest": 1.0, "handR": 2.0, "elbR": 2.0, "blade": 3.0, "handL": 2.0, "elbL": 2.0, "look": 0.3})
    c.rootfn = droot
    L, R = Foot(*lr[0]), Foot(*lr[1])
    R.heels((0, 0), (1, -10), (3, -45), (4, 0), (40, 0))
    R.air(3, 24, [(7, -0.165, -0.52, 0.22, -65, -10), (14, -0.165, -0.46, 0.20, -60, -10),
                  (19, -0.165, -0.12, 0.10, -20, -18), (24, -0.165, 0.10, 0.0, 0, -22)])
    L.air(2, 16, [(6, 0.12, 0.30, 0.14, -10, 6), (12, 0.12, 0.34, 0.10, 5, 8), (16, 0.105, 0.047, 0.0, 6, 8)])
    c.feet = {"L": L, "R": R}
    c.events = {"cancel": 18, "move": 20}
    clips.append(c)

    # ---- Hit reaction ---------------------------------------------------------------
    X1 = pose(I, hip=(0.0, -0.09, -0.02), hipR=(-14, 3, -18), spine=(-10, 2, -2), chest=(-16, 2, 2), look=(16, -5, 8),
              armR=(-60, 20, 0.80), blade_c=az(-130, 50), elbR_c=(-0.8, -0.4, -0.3),
              armL=(40, -10, 0.80), elbL_c=(0.8, -0.4, -0.3), wristL=(-20, 0, 0), clavL=(8, 0), clavR=(8, 0))
    X2 = pose(I, hip=(0.0, -0.05, -0.08), hipR=(-6, 1, -24), spine=(-4, 1, -4), chest=(-5, 1, -4), look=(-20, 5, -4),
              armR=(-50, -10, 0.82), blade_c=az(-100, 30), elbR_c=ELB_R,
              armL=(50, -30, 0.80), elbL_c=ELB_L, wristL=(0, 0, -10))
    X3 = pose(I, hip=(-0.01, -0.01, -0.11), hipR=(10, 0, -24), spine=(6, 0, -6), chest=(8, 0, -6), look=(6, 0, 0),
              armR=(-40, -30, 0.72), blade_c=az(-50, 35), elbR_c=ELB_R,
              armL=(60, -45, 0.70), elbL_c=ELB_L, wristL=(10, 0, -10))
    back = -0.38
    c = keyed("Hit", 44, ((0, I, "hold", (1, 1), 0.0), (2.5, X1, "pass", (0.8, 1.0), -0.10),
                          (7, X2, "hold", (1.0, 1.3), -0.30), (14, X3, "hold", (1.2, 1.4), back),
                          (38, I, "hold", (1.5, 1.8), back)),
              delay={"spine": 0.5, "chest": 0.9, "look": 2.2, "handR": 1.8, "elbR": 1.8, "blade": 2.8, "handL": 2.0, "elbL": 2.0})
    L, R = Foot(*lr[0]), Foot(*lr[1])
    R.step(2, 9, -0.165, 0.10 + back, lift=0.04, off=0, land=0)
    L.heels((0, 0), (3, 0), (9, -16), (10, 0), (44, 0))
    L.step(10, 19, 0.105, 0.02 + back, lift=0.035, off=0, land=0)
    c.feet = {"L": L, "R": R}
    c.events = {"move": 26}
    clips.append(c)
    return clips


# ----------------------------------------------------------------------------
# run cycle (procedural, 36 frames, stance foot moves at exactly RUN_SPEED)
# ----------------------------------------------------------------------------
RUN_N = 36
RUN_STANCE = 10 / 36.0
RUN_STRIDE = 0.73
RUN_SPEED = RUN_STRIDE / (RUN_STANCE * RUN_N / FPS)       # m/s
SWING_LIFT = Curve([(0.0, 0.0), (0.12, 0.11), (0.38, 0.40), (0.65, 0.27), (0.86, 0.085), (1.0, 0.0)])
SWING_PITCH = Curve([(0.0, -55.0), (0.2, -76.0), (0.5, -38.0), (0.8, 2.0), (1.0, 7.0)])


def run_foot(p, sx):
    c0 = 0.27
    if p < RUN_STANCE:
        u = p / RUN_STANCE
        f = c0 - RUN_STRIDE * u
        pit = 7.0 * (1 - ss(0.0, 0.22, u)) - 55.0 * ss(0.45, 1.0, u) ** 1.25
        lift = 0.0
    else:
        u = (p - RUN_STANCE) / (1 - RUN_STANCE)
        m = -RUN_SPEED * (1 - RUN_STANCE) * RUN_N / FPS
        h00, h10 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u
        h01, h11 = -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
        f = h00 * (c0 - RUN_STRIDE) + h10 * m + h01 * c0 + h11 * m
        lift = SWING_LIFT(u)[0]
        pit = SWING_PITCH(u)[0]
    return (0.062 * sx, f, lift), (pit, 5.0 * sx)


def run_clip():
    c = Clip("Run", RUN_N, loop=True, speed=RUN_SPEED)

    def fn(f):
        ph = (f % RUN_N) / RUN_N
        w = 2 * pi * ph
        a = cos(w)                       # +1 at left-foot contact, -1 at right-foot contact
        st = 2 * pi * f / (RUN_N / 2)    # per-step phase
        P = dict(DEFAULT)
        P["footL"], P["footLr"] = run_foot(ph, 1)
        P["footR"], P["footRr"] = run_foot((ph + 0.5) % 1.0, -1)
        low = 2 * pi * 4.0 / (RUN_N / 2)
        P["hip"] = (0.016 * cos(w - 2 * pi * 4 / RUN_N), 0.012 * sin(st - 0.7), -0.088 - 0.034 * cos(st - low))
        P["hipR"] = (13.0 + 1.5 * cos(st - low), -4.0 * cos(w - 2 * pi * 4 / RUN_N), -9.0 * a)
        P["spine"] = (5.0, 1.5 * cos(w - 0.6), 7.0 * cos(w - 0.35))
        P["chest"] = (5.0, 1.5 * cos(w - 0.8), 9.0 * cos(w - 0.6))
        P["look"] = (5.0 + 1.6 * cos(st - low - 0.9), 0.0, 0.0)
        # free arm: pendulum arc, opposite to the left leg
        s = cos(w - 0.5)
        back, fwd, mid = (0.235, -0.215, 0.99), (0.165, 0.300, 1.15), (0.250, 0.060, 0.915)
        hl = tuple(mid[i] + (back[i] - fwd[i]) * 0.5 * s + ((fwd[i] + back[i]) * 0.5 - mid[i]) * s * s for i in range(3))
        hr = (-0.305, -0.135 - 0.055 * s, 0.905 + 0.02 * cos(st - low))
        bl = (-0.30 + 0.04 * s, -0.80, -0.50 + 0.05 * cos(st - low - 0.8))
        P["handL"] = RIG.to_chest(P, hl)
        P["handR"] = RIG.to_chest(P, hr)
        P["blade"] = RIG.to_chest(P, bl, True)
        P["elbL"] = RIG.to_chest(P, (0.75, -0.55, -0.1), True)
        P["elbR"] = RIG.to_chest(P, (-0.6, -0.75, 0.15), True)
        P["wristL"] = (15.0, 0.0, -10.0)
        return P
    c.fn = fn
    return c

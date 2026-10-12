"""Rig math: rotations, two-bone IK, pose interpolation and spring chains.

Character local space: x to the character's right, y forward, z up. One unit = one final pixel.
"""
import math
import numpy as np


def v3(*a):
    if len(a) == 1:
        return np.asarray(a[0], dtype=np.float64)
    return np.array(a, dtype=np.float64)


def norm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v * 0


def rot_x(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_y(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_z(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def body_rot(lean=0.0, twist=0.0, roll=0.0):
    """lean > 0 tips forward, twist > 0 turns left, roll > 0 tips to the right."""
    return rot_z(twist) @ rot_x(-lean) @ rot_y(roll)


def two_bone_ik(root, target, l1, l2, pole):
    """Returns (middle joint, end) for a two-bone limb reaching for target."""
    d = target - root
    dist = np.linalg.norm(d)
    dist_c = min(max(dist, abs(l1 - l2) + 1e-3), l1 + l2 - 1e-3)
    axis = norm(d) if dist > 1e-9 else v3(0, 0, -1)
    cos_a = (l1 * l1 + dist_c * dist_c - l2 * l2) / (2 * l1 * dist_c)
    cos_a = min(max(cos_a, -1.0), 1.0)
    sin_a = math.sqrt(1 - cos_a * cos_a)
    perp = pole - axis * np.dot(pole, axis)
    perp = norm(perp)
    if np.linalg.norm(perp) < 1e-9:
        perp = norm(np.cross(axis, v3(1, 0, 0)))
    mid = root + axis * (l1 * cos_a) + perp * (l1 * sin_a)
    end = root + axis * dist_c
    return mid, end


# ----------------------------------------------------------------------------- poses

def _lerp(a, b, u):
    if isinstance(a, str):
        return a if u < 0.999 else b
    return a + (b - a) * u


def _catmull(p0, p1, p2, p3, u):
    if isinstance(p1, str):
        return p1
    u2, u3 = u * u, u * u * u
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3)


def as_pose(d):
    return {k: (np.asarray(v, dtype=np.float64) if isinstance(v, (tuple, list)) else v) for k, v in d.items()}


class Timeline:
    """Key poses at tick times. Catmull-Rom between keys so sub-frames ease naturally."""

    def __init__(self, keys, times, length, loop):
        self.keys = [as_pose(k) for k in keys]
        self.times = list(times)
        self.length = length
        self.loop = loop

    def _key(self, i):
        n = len(self.keys)
        if self.loop:
            return self.keys[i % n]
        return self.keys[min(max(i, 0), n - 1)]

    def _time(self, i):
        n = len(self.keys)
        if self.loop:
            return self.times[i % n] + (i // n) * self.length
        return self.times[min(max(i, 0), n - 1)]

    def sample(self, t):
        n = len(self.keys)
        if self.loop:
            t = t % self.length
        else:
            t = min(max(t, 0), self.times[-1])
        i = 0
        while i + 1 < n and self.times[i + 1] <= t:
            i += 1
        t0 = self._time(i)
        t1 = self._time(i + 1) if (self.loop or i + 1 < n) else t0
        u = 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
        k0, k1, k2, k3 = self._key(i - 1), self._key(i), self._key(i + 1), self._key(i + 2)
        out = {}
        for name, v in k1.items():
            out[name] = _catmull(k0.get(name, v), v, k2.get(name, v), k3.get(name, v), u)
        return out


# ----------------------------------------------------------------------------- springs

class Chain:
    """Hair, cloth and hat tips: a chain of point masses with rest angles.

    Each node is pulled toward where the rest pose puts it relative to its parent (stiffness),
    plus gravity, damping and wind. Secondary motion is never keyed, it falls out of this.
    """

    def __init__(self, rest_dirs, seg, stiffness=0.25, damping=0.12, gravity=0.06, drag=0.04):
        self.rest_dirs = [norm(v3(d)) for d in rest_dirs]
        self.seg = seg if isinstance(seg, (list, tuple)) else [seg] * len(rest_dirs)
        self.k = stiffness
        self.damp = damping
        self.g = gravity
        self.drag = drag
        self.p = None
        self.v = None

    def reset(self, anchor, rot):
        pts = [anchor]
        for d, s in zip(self.rest_dirs, self.seg):
            pts.append(pts[-1] + rot @ d * s)
        self.p = np.array(pts)
        self.v = np.zeros_like(self.p)

    def step(self, anchor, rot, wind, substeps=4):
        if self.p is None:
            self.reset(anchor, rot)
        dt = 1.0 / substeps
        prev_anchor = self.p[0].copy()
        for s in range(substeps):
            a = prev_anchor + (anchor - prev_anchor) * ((s + 1) / substeps)
            self.p[0] = a
            for i in range(1, len(self.p)):
                target = self.p[i - 1] + rot @ self.rest_dirs[i - 1] * self.seg[i - 1]
                f = (target - self.p[i]) * self.k
                f[2] -= self.g
                f += (wind - self.v[i]) * self.drag
                self.v[i] = self.v[i] * (1 - self.damp * dt) + f * dt
                self.p[i] = self.p[i] + self.v[i] * dt
            for i in range(1, len(self.p)):  # inextensible
                d = self.p[i] - self.p[i - 1]
                n = np.linalg.norm(d)
                if n > 1e-9:
                    fixed = self.p[i - 1] + d / n * self.seg[i - 1]
                    self.v[i] += (fixed - self.p[i]) * 0.5
                    self.p[i] = fixed
        return self.p.copy()

"""Pose-to-pose animation authoring for bpy rigs.

A pose is {bone: {"r": (x, y, z) degrees about WORLD axes at rest, "l": world offset, "s": world scale}}.
Rotations apply Y first, then X, then Z. For a character facing -Y: +X leans/nods forward
(and swings a hanging limb backward), +Z turns to the character's left, +Y tips toward the
character's left side (lowers the left arm, raises the right one).

Clips are keyed pose to pose with an easing per segment (slow in / slow out by default), then
procedural overlays add follow-through and overlapping action, and everything is baked per frame.
"""
import math

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

from vinyl import _fcurves

FPS = 30


def ease(kind, u):
    if kind == "linear":
        return u
    if kind == "in":          # slow out of the first key, accelerating
        return u * u * u
    if kind == "out":         # fast start, settles into the next key
        return 1 - (1 - u) ** 3
    if kind == "hold":
        return 0.0
    if kind == "snap":
        return 1.0 if u > 0.5 else 0.0
    return u * u * (3 - 2 * u)  # inout: slow in and slow out


def _get(spec, k, rest):
    v = spec.get(k, rest)
    if k == "s" and isinstance(v, (int, float)):
        return (v, v, v)
    return tuple(v)


def lerp_pose(a, b, w):
    out = {}
    for bn in set(a) | set(b):
        sa, sb = a.get(bn, {}), b.get(bn, {})
        d = {}
        for k, rest in (("r", (0, 0, 0)), ("l", (0, 0, 0)), ("s", (1, 1, 1))):
            va, vb = _get(sa, k, rest), _get(sb, k, rest)
            d[k] = tuple(x + (y - x) * w for x, y in zip(va, vb))
        out[bn] = d
    return out


def add_pose(base, extra):
    out = {bn: dict(v) for bn, v in base.items()}
    for bn, spec in extra.items():
        d = out.setdefault(bn, {})
        for k, rest in (("r", (0, 0, 0)), ("l", (0, 0, 0))):
            if k in spec:
                d[k] = tuple(x + y for x, y in zip(_get(d, k, rest), _get(spec, k, rest)))
        if "s" in spec:
            d["s"] = tuple(x * y for x, y in zip(_get(d, "s", (1, 1, 1)), _get(spec, "s", (1, 1, 1))))
    return out


class Clip:
    def __init__(self, name, length, loop=False):
        self.name = name
        self.length = length
        self.loop = loop
        self.keys = []      # (frame, pose, ease into the NEXT key)
        self.overlays = []  # f(frame) -> partial pose added on top

    def k(self, frame, pose, ease_next="inout"):
        self.keys.append((frame, pose, ease_next))
        self.keys.sort(key=lambda x: x[0])
        return self

    def overlay(self, fn):
        self.overlays.append(fn)
        return self

    def pose_at(self, f):
        ks = self.keys
        if f <= ks[0][0]:
            p = ks[0][1]
        elif f >= ks[-1][0]:
            p = ks[-1][1]
        else:
            i = max(j for j in range(len(ks)) if ks[j][0] <= f)
            f0, p0, e = ks[i]
            f1, p1, _ = ks[i + 1]
            p = lerp_pose(p0, p1, ease(e, (f - f0) / (f1 - f0)))
        for fn in self.overlays:
            p = add_pose(p, fn(f))
        return p


class Rig:
    def __init__(self, arm_ob):
        self.ob = arm_ob
        self.rest = {}
        for b in arm_ob.data.bones:
            self.rest[b.name] = b.matrix_local.to_3x3()
        for pb in arm_ob.pose.bones:
            pb.rotation_mode = "QUATERNION"

    def _local(self, bn, spec, prev_q):
        B = self.rest[bn]
        Bi = B.inverted()
        rx, ry, rz = [math.radians(a) for a in _get(spec, "r", (0, 0, 0))]
        qw = (Quaternion((0, 0, 1), rz) @ Quaternion((1, 0, 0), rx) @ Quaternion((0, 1, 0), ry))
        ql = (Bi @ qw.to_matrix() @ B).to_quaternion()
        if prev_q is not None and ql.dot(prev_q) < 0:
            ql.negate()
        loc = Bi @ Vector(_get(spec, "l", (0, 0, 0)))
        sw = _get(spec, "s", (1, 1, 1))
        sl = []
        for i in range(3):
            axis = B.col[i]
            j = max(range(3), key=lambda c: abs(axis[c]))
            sl.append(sw[j])
        return ql, loc, sl

    def bake(self, clip):
        act = bpy.data.actions.new(clip.name)
        act.use_fake_user = True
        if self.ob.animation_data is None:
            self.ob.animation_data_create()
        self.ob.animation_data.action = act
        prev = {}
        for f in range(0, clip.length + 1):
            pose = clip.pose_at(f)
            for pb in self.ob.pose.bones:
                spec = pose.get(pb.name, {})
                q, loc, s = self._local(pb.name, spec, prev.get(pb.name))
                prev[pb.name] = q
                pb.rotation_quaternion = q
                pb.location = loc
                pb.scale = s
                pb.keyframe_insert("rotation_quaternion", frame=f, group=pb.name)
                pb.keyframe_insert("location", frame=f, group=pb.name)
                pb.keyframe_insert("scale", frame=f, group=pb.name)
        for fc in _fcurves(act):
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
        act.frame_range = (0, clip.length)
        # keep each clip as its own NLA track so the glTF exporter writes one animation per clip
        track = self.ob.animation_data.nla_tracks.new()
        track.name = clip.name
        strip = track.strips.new(clip.name, 0, act)
        strip.name = clip.name
        track.mute = True
        self.ob.animation_data.action = None
        return act

    def set_pose(self, pose):
        for pb in self.ob.pose.bones:
            q, loc, s = self._local(pb.name, pose.get(pb.name, {}), None)
            pb.rotation_quaternion = q
            pb.location = loc
            pb.scale = s


def wave(f, period, phase=0.0):
    return math.sin(2 * math.pi * (f / period) + phase)

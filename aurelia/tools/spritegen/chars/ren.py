"""Ren v2 — the wandering blade. Chibi (~2.4 heads), ~46 px tall, 3/4 facing right (mirrored in-engine).

Rig: pose = dict of numbers (lean, hand targets, foot targets, weapon angle...). 2-bone IK for legs/arms,
spring chains for scarf/ponytail, weapons are drawn from the pose ('sword' | 'spear' | 'axe' | None),
spins squash the body horizontally (engine.Canvas.warp_x) and flip it, face painted after downsampling.
"""
import math

import numpy as np

from engine import (SS as SSF, Canvas, Mask, ik2, simulate_chain, smooth)

MATERIALS = {
    # name: (base hex, glossy, [deep, shade, base, light, highlight])  - hand-tuned, hue-shifted ramps
    "skin": ("#F6CBA6", False, ["#8E4A5A", "#DE9484", "#F6CBA6", "#FFE2C2", "#FFF1DA"]),
    "hair": ("#C4502A", True, ["#54202F", "#94362E", "#C8552B", "#EE7A38", "#FFB468"]),
    "scarf": ("#27B3A3", False, ["#103E5C", "#187C86", "#27B3A3", "#62DEB8", "#C2FFDC"]),
    "tunic": ("#F4EAD2", False, ["#6E5878", "#C2A8AE", "#F4EAD2", "#FFF7E6", "#FFFFFF"]),
    "sash": ("#E8782A", False, ["#6E1E3A", "#BC4A32", "#E8782A", "#FFA248", "#FFD27E"]),
    "leather": ("#7A5236", False, ["#341C2A", "#5C3A2E", "#7A5236", "#A67A4A", "#D2A66C"]),
    "metal": ("#C4D4E2", True, ["#323E6A", "#7488B4", "#C4D4E2", "#E6F0F8", "#FFFFFF"]),
    "pants": ("#4A5C86", False, ["#1E2046", "#363E72", "#4A5C86", "#6C86B4", "#A4BCDE"]),
    "boots": ("#6A4030", False, ["#2C1624", "#4E2C2C", "#704430", "#9C6844", "#C89468"]),
    "bronze": ("#D9A141", True, ["#58283A", "#A25E34", "#D9A141", "#F6CB60", "#FFF0A8"]),
    "wood": ("#9A6A3C", False, ["#3C2030", "#704232", "#9A6A3C", "#C08C50", "#E4B878"]),
}
CELL = 64
G = (32.0, 59.0)
HIP_H = 14.0
TORSO = 8.0
HEAD_OFF = 9.6
THIGH = SHIN = 6.6
ANKLE_H = 3.1
UARM, FARM = 5.5, 5.3
WEAPON_LEN = {"sword": 14.5, "spear": 18.5, "axe": 12.0}

NO_SEAM = {("hair", "head"), ("scarf", "head"), ("scarf", "torso"), ("hair", "scarf"), ("hair", "torso"),
           ("tail1", "hair"), ("tail1", "torso"), ("tail2", "torso"), ("tail1", "scarf"),
           ("tail2", "scarf"), ("pony", "hair"), ("pony", "head"), ("pony", "torso"), ("pony", "scarf"),
           ("tail1", "tail2"), ("tail1", "head"), ("tail2", "head"), ("pauldron", "armF"), ("pauldron", "torso"),
           ("armF2", "pauldron"), ("armF", "armF2"), ("armB", "armB2"), ("belt", "torso"), ("strap", "torso"),
           ("hem", "torso"), ("hem", "legF"), ("hem", "legB"), ("bootF", "legF"), ("bootB", "legB"),
           ("sword", "guard"), ("guard", "blade"), ("sword", "blade")}

DEFAULT = dict(plant=False, str=1.0, hx=0.0, hy=0.0, lean=0.0, head=0.0, ff=(3.2, 0.0), bf=(-3.2, 0.0),
               nh=(3.2, 6.6), fh=(-2.4, 6.4), sw=165.0, weapon="sword", two=None, wscale=1.0,
               spin=None, expr="neutral", wind=0.0)


def P(**kw):
    d = dict(DEFAULT)
    d.update(kw)
    return d


def blend(a, b, t):
    """Pose interpolation for sub-frames: numbers linear, angles shortest-path."""
    out = {}
    for k in a:
        va, vb = a[k], b[k]
        if k in ("sw", "spin") and va is not None and vb is not None:
            d = (vb - va + 180.0) % 360.0 - 180.0
            out[k] = va + d * t
        elif k == "two":
            out[k] = va if (va is None or vb is None) else va + (vb - va) * t
        elif isinstance(va, (tuple, list)):
            out[k] = tuple(x + (y - x) * t for x, y in zip(va, vb))
        elif isinstance(va, (int, float)):
            out[k] = va + (vb - va) * t
        else:
            out[k] = va if t < 0.5 else vb
    return out


# ------------------------------------------------------------------ poses
#
# Every logical frame of the contract gets ONE key pose. build.py samples a Hermite spline through
# the keys for every game tick. Per-key tags steer the in-betweens leaving that key:
#   ease = "in" (accelerate), "out" (decelerate), "snap" (fast, ~4% overshoot), None (spline flow)
#   stop = True  -> velocity is zero on that key (anticipation extremes, apexes)
# Hold / last-contact frames of the contract are frozen on their exact key by the builder.

REF_SPEED = {}            # filled below: m/s the walk/run cycles were authored for (32 px = 1 m)
S_WALK, S_RUN, F_STANCE_RUN = 9.0, 10.0, 0.45


def _foot_walk(phi):
    phi %= 1.0
    if phi < 0.5:                         # stance: sole glued to the floor, moving back at constant speed
        return (S_WALK * (1 - 4 * phi), 0.0)
    u = (phi - 0.5) * 2.0                 # swing
    e = u * u * (3 - 2 * u)
    return (-S_WALK + 2 * S_WALK * e, -3.9 * math.sin(math.pi * u) ** 0.85)


def walk_pose(phi):
    ff, bf = _foot_walk(phi), _foot_walk(phi + 0.5)
    s = -ff[0] / S_WALK                   # +1: near foot is back, near hand forward
    c2 = math.cos(4 * math.pi * phi)      # +1 at foot contact, -1 at passing
    lean = 3.4 + 0.9 * c2
    return P(hx=0.35 * math.sin(2 * math.pi * phi), hy=0.7 + 0.95 * c2, lean=lean, head=-0.55 * (lean - 3.4) - 0.6 * math.sin(2 * math.pi * phi),
             ff=ff, bf=bf, str=1.0 + 0.012 * c2,
             nh=(3.2 + 3.0 * s, 6.5 - (1.0 * s if s > 0 else -0.35 * s)),
             fh=(-2.4 - 3.2 * s, 6.3 - (-1.0 * s if s < 0 else 0.35 * s)),
             sw=165 - 11 * s, wind=-0.035, expr="neutral")


def _foot_run(phi):
    phi %= 1.0
    if phi < F_STANCE_RUN:                # stance
        psi = phi / F_STANCE_RUN
        return (S_RUN * (1 - 2 * psi), 0.0)
    u = (phi - F_STANCE_RUN) / (1 - F_STANCE_RUN)
    e = u * u * (3 - 2 * u)
    x = -S_RUN + 2 * S_RUN * e - 2.8 * math.sin(math.pi * min(u / 0.4, 1.0))        # heel kick-back first
    return (x, -8.0 * math.sin(math.pi * u ** 0.8) ** 0.8)


def run_pose(phi):
    ff, bf = _foot_run(phi), _foot_run(phi + 0.5)
    s = -ff[0] / S_RUN
    # hip: low through each stance, springs up over the short flight window
    def hip(ph):
        ph %= 0.5
        if ph < F_STANCE_RUN:
            return 2.6 - 1.3 * math.sin(math.pi * ph / F_STANCE_RUN)
        v = (ph - F_STANCE_RUN) / (0.5 - F_STANCE_RUN)
        return 2.6 - 5.0 * math.sin(math.pi * v)
    c2 = math.cos(4 * math.pi * phi)
    return P(hx=0.3 * math.sin(2 * math.pi * phi), hy=hip(phi), lean=15.5 + 1.6 * c2, head=-4.0 + 0.8 * c2, ff=ff, bf=bf, str=1.0 + 0.02 * c2,
             nh=(2.0 + 3.8 * s, 4.5 - 1.2 * abs(s) - (0.8 if s > 0 else 0.0)),
             fh=(-3.0 - 4.2 * s, 4.3 - 1.2 * abs(s) - (0.8 if s < 0 else 0.0)),
             sw=208 - 13 * s, wind=-0.24, expr="focus")


PROCEDURAL = {"walk": walk_pose, "run": run_pose}
REF_SPEED["walk"] = round((2 * S_WALK) / 20.0 * 60.0 / 32.0, 3)                       # stance = half of the 40-tick cycle
REF_SPEED["run"] = round((2 * S_RUN) / (F_STANCE_RUN * 32.0) * 60.0 / 32.0, 3)        # stance = 45% of the 32-tick cycle


def _spin(phi, weapon, **kw):
    """Spin frame: weapon extended around the body; vx/vy = horizontal-plane vector seen from the camera."""
    r = math.radians(phi)
    vx, vy = math.cos(r), 0.45 * math.sin(r)
    sw = math.degrees(math.atan2(vx, -vy)) % 360.0
    ws = max(0.45, min(1.0, math.hypot(vx, vy)))
    base = dict(sw=sw, wscale=ws, spin=phi, weapon=weapon, nh=(6.0 * vx + 1.0, 5.0 * vy + 3.2),
                fh=(-4.5 * vx, -3.0 * vy + 3.4), ff=(2.6, 0.0), bf=(-2.6, 0.0), lean=5.0, expr="angry", wind=-0.25)
    base.update(kw)
    return P(**base)


# a neutral stance every attack settles into (matches idle frame 0, so the hand-off to idle is invisible)
def _rest(**kw):
    d = dict(hx=0.2, hy=0.3, lean=1.5, ff=(3.8, 0.0), bf=(-3.6, 0.0), nh=(3.3, 6.6), fh=(-2.4, 6.4), sw=164)
    d.update(kw)
    return P(**d)


def poses(anim, n):
    out = _poses(anim, n)
    if anim.startswith(("spear", "axe")):
        for p in out:
            p["hx"] = p["hx"] * 0.55
            nh = p["nh"]
            p["nh"] = (nh[0] * 0.88 if nh[0] > 0 else nh[0], nh[1])
            ff = p["ff"]
            p["ff"] = (ff[0] * 0.88 if ff[0] > 0 else ff[0], ff[1])
    return out


def _poses(anim, n):
    S = "sword"
    if anim == "idle":              # breathing + weight shift + one blink + a scarf flutter
        out = []
        for i in range(6):
            ph = i / 6.0
            out.append(P(hx=0.45 * math.sin(2 * math.pi * ph), hy=0.5 - 0.5 * math.cos(2 * math.pi * ph), lean=0.4 + 0.7 * math.sin(2 * math.pi * ph + 0.6),
                         head=1.0 + 1.0 * math.sin(2 * math.pi * ph - 0.8), str=1.0 + 0.012 * math.sin(2 * math.pi * ph - 1.2),
                         ff=(3.2 + 0.25 * math.sin(2 * math.pi * ph), 0.0), bf=(-3.2 + 0.25 * math.sin(2 * math.pi * ph), 0.0),
                         nh=(3.2, 6.6 - 0.35 * math.sin(2 * math.pi * ph - 0.4)), fh=(-2.4, 6.4 - 0.3 * math.sin(2 * math.pi * ph - 0.4)),
                         sw=164 + 2.0 * math.sin(2 * math.pi * ph), wind=0.03 + (0.07 if i == 2 else 0.0),
                         expr="blink" if i == 4 else "neutral"))
        return out[:n]
    if anim == "ready":             # battle stance: knees bent, weapon up, bouncing on the toes
        out = []
        for i in range(6):
            ph = i / 6.0
            b = 0.5 - 0.5 * math.cos(2 * math.pi * ph)
            out.append(P(hy=2.9 + 0.7 * b - 0.0, hx=0.5, lean=6.5 + 0.8 * math.sin(2 * math.pi * ph), head=-1.5, ff=(6.4, -0.35 * b), bf=(-5.4, -0.2 * b),
                         nh=(6.0, 2.9 - 0.5 * b), fh=(-1.5, 4.9 + 0.3 * b), sw=28 + 3.5 * b, str=1.0 - 0.015 * b, expr="focus", wind=-0.05 + 0.05 * b))
        return out[:n]
    if anim == "walk":
        return [walk_pose(i / 8.0) for i in range(8)][:n]
    if anim == "run":
        return [run_pose(i / 8.0) for i in range(8)][:n]
    if anim == "dash":              # crouch -> explosive launch -> long stretched glide -> brake -> settle
        return [
            P(hx=-2.0, hy=3.6, lean=7, head=-3, ff=(6, 0), bf=(-6.5, 0), nh=(-1.5, 6.5), fh=(-3.5, 6), sw=220, str=0.94, expr="focus", wind=-0.15, ease="snap"),
            P(hx=2.2, hy=3.4, lean=30, head=-8, ff=(10, -1.5), bf=(-13, -2.5), nh=(-3.8, 4.5), fh=(-5.2, 4), sw=236, str=1.06, expr="angry", wind=-0.45),
            P(hx=3.8, hy=3.0, lean=42, head=-15, ff=(12, -3.0), bf=(-15, -6.0), nh=(-5.5, 3.5), fh=(-6.5, 3), sw=246, str=1.1, expr="angry", wind=-0.55),
            P(hx=2.4, hy=2.8, lean=28, head=-9, ff=(10.5, -0.6), bf=(-11, -2.4), nh=(-3.5, 4.2), fh=(-5, 3.8), sw=238, str=1.03, expr="focus", wind=-0.35, ease="out"),
            _rest(hx=0.8, hy=1.6, lean=8, ff=(6.5, 0), bf=(-5.0, 0), nh=(2.0, 6.2), sw=186, wind=-0.1),
        ][:n]
    if anim == "jump":
        return [
            P(hy=4.2, lean=6, head=-2, ff=(4.8, 0), bf=(-4.8, 0), nh=(2.5, 6.8), fh=(-3, 6.8), sw=176, str=0.93, expr="focus", ease="snap"),
            P(hy=-4.8, lean=-4, head=-2, ff=(3, -7), bf=(-3.5, -5), nh=(5, 0.2), fh=(-5, 1.2), sw=105, str=1.1, expr="happy"),
            P(hy=-3.6, lean=3, head=3, ff=(4.5, -4.4), bf=(-1.5, -5.4), nh=(5.5, -3.8), fh=(-4.5, -3.8), sw=75, str=0.97, expr="neutral"),
            P(hy=5.0, lean=8, head=-3, ff=(5.4, 0), bf=(-5.4, 0), nh=(3, 7.2), fh=(-3, 7.2), sw=170, str=0.9, expr="blink", ease="out"),
        ][:n]
    if anim == "sword.1":           # diagonal down-slash: coil back, snap forward, lunge, drag
        return [
            P(hx=-1.0, hy=1.9, lean=-4, ff=(5, 0), bf=(-5, 0), nh=(1.0, 3.8), fh=(1, 5.5), sw=262, str=0.97, expr="focus", ease="in"),
            P(hx=-3.2, hy=3.0, lean=-15, head=-5, ff=(5.5, 0), bf=(-7, 0), nh=(-5.2, -3.6), fh=(2.2, 3), sw=316, str=0.95, expr="focus", wind=-0.05, stop=True, ease="in"),
            P(hx=1.2, hy=1.0, lean=7, head=1, ff=(8.5, -2.6), bf=(-7.6, 0), nh=(2.0, -7.6), fh=(-4, 3), sw=2, str=1.07, expr="angry", wind=-0.25, ease="snap"),
            P(hx=4.4, hy=2.7, lean=21, head=3, ff=(11.5, 0), bf=(-8.6, 0), nh=(8.6, 2.8), fh=(-5.2, 3.2), sw=122, str=1.04, expr="angry", wind=-0.3),
            P(hx=5.0, hy=3.3, lean=25, head=1, ff=(11.5, 0), bf=(-8.2, 0), nh=(8.0, 6.2), fh=(-5.6, 4.0), sw=150, str=0.99, expr="focus", wind=-0.2, ease="out"),
            P(hx=2.8, hy=2.2, lean=12, ff=(8.5, 0), bf=(-5.2, 0), nh=(5.6, 7.0), fh=(-3.6, 6.0), sw=157, wind=-0.1),
            _rest(),
        ][:n]
    if anim == "sword.2":           # rising reverse slash with a stepping lunge
        return [
            P(hx=0.0, hy=2.6, lean=8, ff=(6, 0), bf=(-6, 0), nh=(5.0, 7.0), fh=(-2, 6), sw=172, str=0.97, expr="focus", ease="in"),
            P(hx=-2.6, hy=3.8, lean=11, head=1, ff=(7, 0), bf=(-8.4, 0), nh=(-0.6, 9.6), fh=(-1.4, 6), sw=214, str=0.94, expr="focus", wind=-0.05, stop=True, ease="in"),
            P(hx=1.6, hy=2.4, lean=2, ff=(9.6, -2.8), bf=(-7.2, 0), nh=(7.2, 5.2), fh=(-4.2, 4.6), sw=120, str=1.04, expr="angry", wind=-0.25, ease="snap"),
            P(hx=3.8, hy=1.0, lean=-7, head=-1, ff=(11, 0), bf=(-7.6, 0), nh=(7.6, -3.6), fh=(-5.2, 5.2), sw=38, str=1.07, expr="angry", wind=-0.3),
            P(hx=3.4, hy=0.4, lean=-12, head=-3, ff=(10, 0), bf=(-6.6, 0), nh=(4.6, -8.2), fh=(-3.6, 6.2), sw=340, str=1.04, expr="focus", wind=-0.15, ease="out"),
            P(hx=1.6, hy=0.8, lean=-4, ff=(6.6, 0), bf=(-4.4, 0), nh=(2.4, -3.6), fh=(-2.2, 6.2), sw=330, wind=-0.05),
            _rest(),
        ][:n]
    if anim == "sword.3":           # finisher: crouch, leap, arch back, hammer down
        return [
            P(hy=5.0, lean=-6, ff=(5.5, 0), bf=(-5.5, 0), nh=(2.6, 7.6), fh=(-2, 6.6), sw=172, str=0.9, expr="focus", ease="snap"),
            P(hy=-6.2, lean=-9, ff=(3, -5.8), bf=(-2.5, -4.8), nh=(0.6, -8.6), fh=(-3, -6.6), sw=352, str=1.12, expr="focus", wind=-0.1),
            P(hy=-10.2, lean=-13, head=-7, ff=(4, -6.8), bf=(-3, -5.8), nh=(1.6, -10.6), fh=(-1.6, -9.4), sw=330, str=1.05, expr="angry", wind=0.1, stop=True, ease="in"),
            P(hx=4.6, hy=3.6, lean=33, head=4, ff=(11.8, 0), bf=(-6, 0), nh=(9.6, 5.4), fh=(-3, 4.2), sw=117, str=0.96, expr="angry", wind=-0.3),
            P(hx=4.4, hy=5.2, lean=31, ff=(12.4, 0), bf=(-6.2, 0), nh=(8.9, 7.4), fh=(-3.2, 5.4), sw=138, str=0.92, expr="focus", wind=-0.1, ease="out"),
            P(hx=2.6, hy=3.0, lean=16, ff=(9, 0), bf=(-4.4, 0), nh=(6, 7.2), fh=(-2.4, 6.2), sw=152, str=0.97),
            _rest(),
        ][:n]
    if anim == "spear.1":           # long straight thrust: rear-leg drive, recoil
        W = dict(weapon="spear", two=6.0)
        return [
            P(hx=-0.6, hy=2.4, lean=-3, ff=(6, 0), bf=(-5.6, 0), nh=(0.4, 4.6), sw=88, str=0.97, expr="focus", ease="in", **W),
            P(hx=-3.2, hy=3.2, lean=-11, head=-3, ff=(6, 0), bf=(-7.8, 0), nh=(-5.8, 3.8), sw=84, str=0.95, expr="focus", stop=True, ease="in", **W),
            P(hx=1.8, hy=2.2, lean=7, ff=(9.8, -2.2), bf=(-8.2, 0), nh=(2.8, 3.9), sw=88, str=1.05, expr="angry", wind=-0.25, ease="snap", **W),
            P(hx=5.2, hy=2.8, lean=19, ff=(12.8, 0), bf=(-9, 0), nh=(9.6, 3.2), sw=90, str=1.06, expr="angry", wind=-0.3, **W),
            P(hx=3.8, hy=2.6, lean=12, ff=(12.2, 0), bf=(-8.4, 0), nh=(6.6, 3.8), sw=94, str=1.0, expr="focus", ease="out", **W),
            P(hx=2.2, hy=2.0, lean=7, ff=(9, 0), bf=(-5.4, 0), nh=(4.2, 4.6), sw=64, **W),
            _rest(sw=36, nh=(3.4, 6.0), **W),
        ][:n]
    if anim == "spear.2":           # rising stab
        W = dict(weapon="spear", two=6.0)
        return [
            P(hy=3.0, lean=3, ff=(6, 0), bf=(-6, 0), nh=(0.5, 8), sw=120, str=0.96, expr="focus", ease="in", **W),
            P(hx=-2.6, hy=4.0, lean=-1, ff=(6.5, 0), bf=(-7.4, 0), nh=(-2.4, 9.4), sw=130, str=0.93, expr="focus", stop=True, ease="in", **W),
            P(hx=1.8, hy=2.8, lean=5, ff=(9.2, -2.2), bf=(-7.4, 0), nh=(4.2, 5.4), sw=94, str=1.03, expr="angry", wind=-0.25, ease="snap", **W),
            P(hx=5.0, hy=2.4, lean=13, ff=(12.4, 0), bf=(-8, 0), nh=(9.2, -0.8), sw=55, str=1.07, expr="angry", wind=-0.3, **W),
            P(hx=4.0, hy=2.3, lean=10, ff=(12, 0), bf=(-7.6, 0), nh=(7.0, -0.4), sw=50, str=1.02, expr="focus", ease="out", **W),
            P(hx=2.2, hy=1.8, lean=6, ff=(9, 0), bf=(-5, 0), nh=(4.5, 2.5), sw=44, **W),
            _rest(sw=36, nh=(3.4, 6.0), **W),
        ][:n]
    if anim == "spear.3":           # wide sweeping finisher
        W = dict(weapon="spear", two=6.0)
        return [
            P(hy=3.4, lean=-4, ff=(6, 0), bf=(-6, 0), nh=(-2, 8), sw=214, str=0.95, expr="focus", ease="in", **W),
            P(hx=-3.6, hy=3.0, lean=-14, head=-5, ff=(6, 0), bf=(-8, 0), nh=(-5.6, 3), sw=258, str=0.95, expr="focus", stop=True, ease="in", **W),
            P(hx=-0.6, hy=0.2, lean=-9, ff=(7.4, -2), bf=(-6.4, 0), nh=(-2, -6), sw=336, str=1.08, expr="angry", wind=0.05, ease="snap", **W),
            P(hx=5.0, hy=3.2, lean=27, head=3, ff=(12.4, 0), bf=(-7.4, 0), nh=(8.4, 3.6), sw=102, str=1.02, expr="angry", wind=-0.3, **W),
            P(hx=4.4, hy=3.6, lean=23, ff=(12.2, 0), bf=(-7.2, 0), nh=(7.8, 5.2), sw=118, str=0.97, expr="focus", ease="out", **W),
            P(hx=2.4, hy=2.4, lean=12, ff=(9, 0), bf=(-5, 0), nh=(5.2, 5.8), sw=86, **W),
            _rest(sw=36, nh=(3.4, 6.0), **W),
        ][:n]
    if anim == "axe.1":             # heavy wind-up, huge arc, ground-shake settle
        W = dict(weapon="axe", two=4.5)
        return [
            P(hx=-1.6, hy=3.0, lean=-10, ff=(6, 0), bf=(-6, 0), nh=(-3, 3.5), sw=300, str=0.95, expr="focus", ease="in", **W),
            P(hx=-3.8, hy=3.6, lean=-19, head=-6, ff=(6, 0), bf=(-7.6, 0), nh=(-5.6, -1.6), sw=284, str=0.93, expr="focus", wind=-0.05, stop=True, ease="in", **W),
            P(hx=0.4, hy=1.8, lean=-1, ff=(8.4, -2.4), bf=(-6.4, 0), nh=(2, -7), sw=352, str=1.08, expr="angry", wind=-0.3, ease="snap", **W),
            P(hx=4.0, hy=3.0, lean=23, head=3, ff=(11.6, 0), bf=(-7.6, 0), nh=(7.8, 1.2), sw=97, str=1.03, expr="angry", wind=-0.35, **W),
            P(hx=3.8, hy=4.0, lean=25, ff=(11.6, 0), bf=(-7.4, 0), nh=(7.2, 5.4), sw=130, str=0.93, expr="focus", ease="out", **W),
            P(hx=2.2, hy=2.6, lean=13, ff=(8.4, 0), bf=(-5, 0), nh=(5, 6.6), sw=146, str=0.98, **W),
            _rest(hy=0.8, sw=163, nh=(3.4, 6.4), **W),
        ][:n]
    if anim == "axe.2":
        W = dict(weapon="axe", two=4.5)
        return [
            P(hy=3.2, lean=8, ff=(6, 0), bf=(-6, 0), nh=(5.5, 7.5), sw=172, str=0.95, expr="focus", ease="in", **W),
            P(hx=-2.4, hy=4.0, lean=2, ff=(6, 0), bf=(-7.6, 0), nh=(0.4, 8.8), sw=218, str=0.92, expr="focus", stop=True, ease="in", **W),
            P(hx=1.6, hy=2.8, lean=-3, ff=(9, -2.6), bf=(-6.4, 0), nh=(7, 4.4), sw=128, str=1.04, expr="angry", wind=-0.3, ease="snap", **W),
            P(hx=3.4, hy=1.8, lean=-8, ff=(10.4, 0), bf=(-6.6, 0), nh=(8, -2.4), sw=60, str=1.07, expr="angry", wind=-0.35, **W),
            P(hx=2.8, hy=1.0, lean=-12, ff=(9.4, 0), bf=(-5.4, 0), nh=(5, -7.2), sw=16, str=1.04, expr="focus", ease="out", **W),
            P(hx=1.4, hy=1.2, lean=-4, ff=(6, 0), bf=(-4, 0), nh=(2.5, -3), sw=335, **W),
            _rest(hy=0.8, sw=163, nh=(3.4, 6.4), **W),
        ][:n]
    if anim == "axe.3":             # overhead leap + slam
        W = dict(weapon="axe", two=4.5)
        return [
            P(hy=5.0, lean=-9, ff=(5.5, 0), bf=(-5.5, 0), nh=(2.5, 7.6), sw=170, str=0.9, expr="focus", ease="in", **W),
            P(hy=-5.8, lean=-12, ff=(3, -6.4), bf=(-2.5, -5.2), nh=(0.4, -8.8), sw=352, str=1.12, expr="focus", **W),
            P(hy=-10.6, lean=-9, head=-4, ff=(4, -7.4), bf=(-3, -6.4), nh=(2, -9.8), sw=346, str=1.06, expr="angry", wind=0.1, stop=True, ease="in", **W),
            P(hx=4.4, hy=3.8, lean=36, head=4, ff=(12.4, 0), bf=(-5.4, 0), nh=(9.2, 6.2), sw=124, str=0.96, expr="angry", wind=-0.35, **W),
            P(hx=3.8, hy=5.0, lean=31, ff=(12.4, 0), bf=(-5.4, 0), nh=(9, 7.6), sw=140, str=0.9, expr="focus", ease="out", **W),
            P(hx=2.2, hy=3.4, lean=19, ff=(9.4, 0), bf=(-4.4, 0), nh=(6.2, 7.2), sw=152, str=0.96, **W),
            _rest(hy=0.8, sw=163, nh=(3.4, 6.4), **W),
        ][:n]
    if anim == "sword.sp1":         # Whirlwind: wind-up, full 360 spin, finishing flourish
        ph = [-30, 40, 110, 180, 250]
        out = [P(hy=3.4, lean=-13, ff=(5, 0), bf=(-5, 0), nh=(-5, 3), fh=(-3, 4), sw=268, str=0.95, expr="focus", ease="in"),
               P(hx=-1.8, hy=4.0, lean=-19, head=-7, ff=(5, 0), bf=(-5.4, 0), nh=(-6.4, 1.5), fh=(-2, 3.5), sw=250, str=0.94, expr="angry", wind=-0.15, stop=True, ease="snap")]
        out += [_spin(p, S, hy=-1.4 - 0.8 * math.sin(i * 1.4), lean=7.0 + 2 * math.sin(i * 1.4)) for i, p in enumerate(ph)]
        out += [P(hx=1.4, hy=2.0, lean=14, ff=(7.5, 0), bf=(-5.5, 0), nh=(7.4, 3.5), fh=(-4, 5), sw=96, str=1.04, expr="angry", wind=-0.3),
                P(hx=1.0, hy=2.6, lean=10, ff=(6.6, 0), bf=(-5.0, 0), nh=(5.6, 4.8), fh=(-3, 5), sw=118, expr="focus", wind=-0.2, ease="out"),
                _rest()]
        return out[:n]
    if anim == "axe.sp2":           # Hurricane Axe
        ph = [-30, 40, 110, 180, 250]
        W = "axe"
        out = [P(hy=3.8, lean=-14, ff=(5, 0), bf=(-5, 0), nh=(-5.5, 2), sw=272, weapon=W, two=4.5, str=0.94, expr="focus", ease="in"),
               P(hx=-1.4, hy=4.4, lean=-19, ff=(5, 0), bf=(-5.6, 0), nh=(-6.2, 0), sw=255, weapon=W, two=4.5, str=0.93, expr="angry", wind=-0.15, stop=True, ease="snap")]
        out += [_spin(p, W, hy=-3.2 - 1.4 * math.sin(i * 1.3), two=4.5, ff=(2.4, -2.6), bf=(-2.4, -1.6), lean=7.0 + 2 * math.sin(i * 1.3)) for i, p in enumerate(ph)]
        out += [P(hx=1.4, hy=3.8, lean=16, ff=(7, 0), bf=(-6, 0), nh=(7.2, 5.6), sw=118, weapon=W, two=4.5, str=0.95, expr="angry", wind=-0.3),
                P(hx=0.8, hy=3.0, lean=10, ff=(6.4, 0), bf=(-5, 0), nh=(5.6, 6.2), sw=140, weapon=W, two=4.5, expr="focus", ease="out"),
                _rest(hy=0.8, sw=163, nh=(3.4, 6.4), weapon=W, two=4.5)]
        return out[:n]
    if anim == "sword.sp2":         # Meteor Dive
        return [
            P(hy=4.8, lean=-6, ff=(5, 0), bf=(-5, 0), nh=(3, 8), fh=(-2, 7), sw=172, str=0.9, expr="focus", ease="snap"),
            P(hx=1, hy=-6.4, lean=-6, ff=(3, -6.8), bf=(-3, -5.2), nh=(3, -8.8), fh=(-2, -7.2), sw=355, str=1.14, expr="angry"),
            P(hx=2, hy=-12.6, lean=-2, ff=(3, -9.4), bf=(-2, -8.4), nh=(2.5, -10.4), fh=(-1.5, -10.4), sw=2, str=1.06, expr="angry", wind=0.05, ease="snap"),
            P(hx=5, hy=-9.4, lean=118, head=-12, ff=(-5, -17.5), bf=(-9, -14.5), nh=(6.5, 3.5), fh=(4.5, 1), sw=150, str=1.1, expr="angry", wind=-0.45),
            P(hx=5.6, hy=5.6, lean=44, ff=(10.4, 0), bf=(-3.4, 0), nh=(8, 8), fh=(3, 6.5), sw=179, str=0.9, expr="angry", plant=True),
            P(hx=4, hy=5.0, lean=30, ff=(9, 0), bf=(-3, 0), nh=(7.5, 8), fh=(2, 7), sw=176, str=0.94, expr="focus", plant=True, ease="out"),
            _rest(hx=1, hy=1.0, lean=4),
        ][:n]
    if anim == "spear.sp1":         # Gale Thrusts: rapid alternating jabs, then a big finishing lunge
        W = dict(weapon="spear", two=6.0)
        T = lambda hx, lean, nh, sw, ff, bf, **k: P(hx=hx, hy=2.6, lean=lean, ff=ff, bf=bf, nh=nh, sw=sw, expr="angry", wind=-0.2, **W, **k)
        out = [P(hx=-2.4, hy=2.8, lean=-9, ff=(6, 0), bf=(-6.6, 0), nh=(-3.4, 4), sw=86, str=0.95, expr="focus", ease="in", **W)]
        out += [T(5.0, 19, (9.4, 3.5), 90, (12.6, 0), (-7, 0), str=1.06),
                T(1.4, 6, (3.0, 3.9), 96, (8.6, -1.2), (-8.8, 0), str=0.96),
                T(5.2, 20, (9.4, 1.2), 78, (13.2, 0), (-6, 0), str=1.06),
                T(1.4, 6, (3.2, 5.8), 104, (8.4, -1.2), (-9.4, 0), str=0.96),
                T(5.4, 21, (9.6, 3.0), 86, (13.6, 0), (-6.5, 0), str=1.07),
                T(1.8, 8, (3.6, 2.0), 80, (9, -1.0), (-9, 0), str=0.97)]
        out += [P(hx=6.4, hy=3.0, lean=26, ff=(14.4, 0), bf=(-6.4, 0), nh=(9.6, 3.2), sw=88, str=1.08, expr="angry", wind=-0.35, **W),
                P(hx=3.5, hy=2.4, lean=12, ff=(10, 0), bf=(-5, 0), nh=(6, 4.5), sw=66, str=1.0, expr="focus", ease="out", **W),
                _rest(sw=36, nh=(3.4, 6.0), **W)]
        return out[:n]
    if anim == "spear.sp2":         # Javelin Toss (empty-handed from the release frame on)
        return [
            P(hx=-2, hy=2.4, lean=-12, ff=(6, 0), bf=(-5, 0), nh=(-3.5, 1.5), fh=(5.5, 1.5), sw=84, weapon="spear", str=0.96, expr="focus", ease="in"),
            P(hx=-3.8, hy=2.9, lean=-21, head=-7, ff=(6, 0), bf=(-7.4, 0), nh=(-6.8, -0.5), fh=(6.6, 1.0), sw=74, weapon="spear", str=0.94, expr="angry", stop=True, ease="in"),
            P(hx=0.8, hy=2.0, lean=2, ff=(8.4, -2), bf=(-6.4, 0), nh=(2.6, -2.5), fh=(5.5, 2.5), sw=70, weapon="spear", expr="angry", wind=-0.25, str=1.05, ease="snap"),
            P(hx=3.8, hy=2.6, lean=26, ff=(11.4, 0), bf=(-6.4, 0), nh=(9.0, -3.0), fh=(-3, 4.5), sw=80, weapon=None, str=1.07, expr="shout", wind=-0.35),
            P(hx=3.8, hy=2.9, lean=21, ff=(11.2, 0), bf=(-6.2, 0), nh=(7.8, 1.5), fh=(-3, 5), sw=100, weapon=None, expr="focus", ease="out"),
            P(hx=1.0, hy=1.2, lean=6, ff=(7, 0), bf=(-4, 0), nh=(4, 5.5), fh=(-2.4, 6), sw=130, weapon=None),
        ][:n]
    if anim == "axe.sp1":           # Quake Cleave: huge overhead wind-up, slam into the ground
        W = dict(weapon="axe", two=4.5)
        return [
            P(hx=-2, hy=3.6, lean=-14, ff=(6, 0), bf=(-6.5, 0), nh=(-3.5, 0.5), sw=318, str=0.94, expr="focus", ease="in", **W),
            P(hx=-2.8, hy=-1.4, lean=-22, head=-9, ff=(6, 0), bf=(-7.4, 0), nh=(-1.5, -10), sw=358, str=1.12, expr="angry", wind=0.1, stop=True, ease="snap", **W),
            P(hx=1.0, hy=2.0, lean=7, ff=(8.4, -2.4), bf=(-6.4, 0), nh=(5, -4), sw=50, str=1.06, expr="angry", wind=-0.3, ease="snap", **W),
            P(hx=5.2, hy=4.6, lean=40, ff=(13.4, 0), bf=(-5, 0), nh=(10, 8), sw=132, str=0.92, expr="shout", plant=True, **W),
            P(hx=4.6, hy=5.0, lean=35, ff=(13.4, 0), bf=(-5, 0), nh=(9.8, 8.6), sw=138, str=0.9, expr="angry", plant=True, ease="out", **W),
            _rest(hx=2.0, hy=2.4, lean=14, ff=(8, 0), bf=(-4, 0), nh=(6, 7), sw=152, expr="focus", **W),
        ][:n]
    if anim == "cast":              # Ice Lance: gather, push forward
        return [
            P(hy=1.4, lean=-5, nh=(2, 6.5), fh=(2.5, 4.5), sw=175, str=0.98, expr="focus", ease="in"),
            P(hx=-1.8, hy=1.9, lean=-11, head=-5, ff=(5, 0), bf=(-5.4, 0), nh=(1.5, 7), fh=(-1.4, 1), sw=185, str=0.96, expr="focus", stop=True, ease="in"),
            P(hx=0.6, hy=1.2, lean=4, ff=(6.2, 0), bf=(-5.2, 0), nh=(-1.5, 3.5), fh=(6.5, 0.5), sw=335, str=1.03, expr="angry", ease="snap"),
            P(hx=2.4, hy=1.0, lean=13, ff=(8.4, 0), bf=(-5.4, 0), nh=(-2.0, 2.5), fh=(10.8, -3.6), sw=330, str=1.06, expr="shout", wind=0.15),
            P(hx=1.8, hy=1.0, lean=9, ff=(7.2, 0), bf=(-4.6, 0), nh=(-2.0, 3.5), fh=(10.0, -2.8), sw=332, expr="focus", ease="out"),
            _rest(),
        ][:n]
    if anim == "cast.ring":         # Ring of Fire: crouch, arms sweep out and up
        return [
            P(hy=3.4, lean=6, ff=(5, 0), bf=(-5, 0), nh=(1.5, 8.5), fh=(0, 8.5), sw=178, str=0.93, expr="focus", ease="in"),
            P(hy=5.4, lean=11, head=3, ff=(6.4, 0), bf=(-6.4, 0), nh=(1, 9.2), fh=(0.5, 9.2), sw=180, str=0.9, expr="focus", stop=True, ease="snap"),
            P(hy=1.4, lean=0, ff=(5.6, 0), bf=(-5.6, 0), nh=(5, 5.5), fh=(-5, 5.5), sw=172, str=1.04, expr="angry"),
            P(hy=-2.0, lean=-6, head=-9, ff=(5.6, -0.6), bf=(-5.6, -0.6), nh=(8.8, 2.4), fh=(-8.4, 2.6), sw=138, str=1.1, expr="shout", wind=0.35),
            P(hy=-0.6, lean=-3, head=-5, ff=(5.5, 0), bf=(-5.5, 0), nh=(8.4, 3.8), fh=(-7.6, 4.0), sw=142, expr="angry", wind=0.2, ease="out"),
            _rest(),
        ][:n]
    if anim == "cast.sky":          # Comet: both... one arm hauls up to the sky
        return [
            P(hy=1.6, lean=-3, nh=(2.5, 6.5), fh=(-1.5, 2), sw=175, str=0.98, expr="focus", ease="in"),
            P(hy=0.6, lean=-7, head=-11, ff=(4.5, 0), bf=(-4.5, 0), nh=(2, 7), fh=(-3.5, -5), sw=180, str=1.02, expr="focus"),
            P(hy=-1.0, lean=-9, head=-17, ff=(4.5, 0), bf=(-4.5, 0), nh=(2, 7), fh=(-4.0, -9.0), sw=182, str=1.08, expr="angry", stop=True, ease="snap"),
            P(hy=-2.8, lean=-11, head=-21, ff=(4.0, -0.5), bf=(-4.0, -0.5), nh=(2, 7), fh=(-4.5, -9.4), sw=184, str=1.1, expr="shout", wind=0.3),
            P(hy=-1.6, lean=-8, head=-16, ff=(4.0, 0), bf=(-4.0, 0), nh=(2, 7), fh=(-4.2, -8.6), sw=184, str=1.04, expr="focus", ease="out"),
            _rest(),
        ][:n]
    if anim == "hurt":              # instant impact, overshoot, recover
        return [
            P(hx=-3.4, hy=1.8, lean=-24, head=-17, ff=(5, -1), bf=(-5.4, 0), nh=(-2, 2), fh=(-4, 1), sw=216, str=0.94, expr="hurt", wind=0.3, ease="snap"),
            P(hx=-4.6, hy=2.8, lean=-30, head=-20, ff=(5, -0.5), bf=(-6.4, 0), nh=(-3, 4), fh=(-5, 3), sw=226, str=0.92, expr="hurt", wind=0.2, ease="out"),
            P(hx=-1.4, hy=1.8, lean=-11, head=-6, ff=(4.5, 0), bf=(-4.5, 0), nh=(1, 6.5), fh=(-3.5, 6), sw=195, expr="hurt"),
        ][:n]
    if anim == "death":
        return [
            P(hx=-3.2, hy=1.8, lean=-27, head=-17, ff=(5, -1), bf=(-4, 0), nh=(-2, 2), fh=(-4, 1), sw=215, str=0.95, expr="hurt", ease="snap"),
            P(hx=-1.0, hy=3.6, lean=-53, head=-10, ff=(8, -1), bf=(0, 0), nh=(-4, 3), fh=(-5, 2), sw=225, expr="hurt", ease="in"),
            P(hx=3.0, hy=6.2, lean=-77, head=-4, ff=(14, -3), bf=(9, -1.5), nh=(-1, 4), fh=(-3, 4), sw=240, expr="dead", weapon=None, ease="out"),
            P(hx=8.0, hy=6.8, lean=-92, head=2, ff=(20, -3.5), bf=(16, -2), nh=(2, 4.5), fh=(0.5, 6.5), sw=250, expr="dead", weapon=None, ease="out"),
            P(hx=8.0, hy=6.5, lean=-93, head=3, ff=(21, -3), bf=(17, -1.5), nh=(2.2, 4.8), fh=(0.5, 6.8), sw=252, expr="dead", weapon=None),
            P(hx=8.0, hy=6.5, lean=-94, head=3, ff=(21, -3), bf=(17, -1.5), nh=(2.4, 5), fh=(0.5, 7.0), sw=255, expr="dead", weapon=None),
        ][:n]
    if anim == "victory":
        return [
            P(hy=4.4, lean=5, ff=(5, 0), bf=(-5, 0), nh=(3, 7.5), fh=(-2.5, 7.5), sw=170, str=0.9, expr="happy", ease="snap"),
            P(hy=-6.8, lean=-4, head=-6, ff=(3, -6.2), bf=(-3.5, -4.8), nh=(3.5, -8.2), fh=(-4, -3), sw=12, str=1.12, expr="happy", wind=0.1),
            P(hy=-9.0, lean=-6, head=-9, ff=(3.5, -7.2), bf=(-3, -6.2), nh=(3, -9.8), fh=(-5, -6), sw=18, str=1.06, expr="shout", wind=0.2, stop=True, ease="snap"),
            P(hy=4.4, lean=6, ff=(5.5, 0), bf=(-5.5, 0), nh=(3.5, 1.5), fh=(-3, 5), sw=30, str=0.9, expr="happy", ease="out"),
            P(hy=1.0, lean=-2, head=-4, ff=(4.5, 0), bf=(-4, 0), nh=(3.5, -3), fh=(-2.2, 4.5), sw=14, expr="happy"),
            P(hy=0.8, lean=-3, head=-5, ff=(4.5, 0), bf=(-4, 0), nh=(3.5, -3.5), fh=(-2.2, 4.5), sw=12, expr="happy"),
        ][:n]
    raise KeyError(anim)


# ----------------------------------------------------------------- skeleton


def _rot(v, deg):
    a = math.radians(deg)
    return (v[0] * math.cos(a) - v[1] * math.sin(a), v[0] * math.sin(a) + v[1] * math.cos(a))


def skeleton(p, _depth=0):
    lean = p["lean"]
    lr = math.radians(lean)
    hip = (G[0] + p["hx"], G[1] - HIP_H + p["hy"])
    td = (math.sin(lr), -math.cos(lr))
    perp = (math.cos(lr), math.sin(lr))
    sh = (hip[0] + td[0] * TORSO * p["str"], hip[1] + td[1] * TORSO * p["str"])
    nsh = (sh[0] + perp[0] * 1.5, sh[1] + perp[1] * 1.5)
    fsh = (sh[0] - perp[0] * 2.6, sh[1] - perp[1] * 2.6)
    hr = math.radians(lean + p["head"])
    head = (sh[0] + math.sin(hr) * HEAD_OFF + perp[0] * 0.9, sh[1] - math.cos(hr) * HEAD_OFF + perp[1] * 0.9)
    if _depth < 8 and (head[0] > 50.0 or head[0] < 11.0):      # keep the big head inside the cell
        q = dict(p)
        q["hx"] = p["hx"] - (head[0] - 49.0) if head[0] > 50.0 else p["hx"] + (12.0 - head[0])
        return skeleton(q, _depth + 1)
    sk = {"hip": hip, "sh": sh, "nsh": nsh, "fsh": fsh, "head": head, "lean": lean, "td": td}
    for tag, hp, foot in (("n", (hip[0] + 1.2, hip[1]), p["ff"]), ("f", (hip[0] - 1.4, hip[1]), p["bf"])):
        ankle = (G[0] + foot[0], G[1] + min(foot[1], 0.0) - ANKLE_H)
        knee, ankle = ik2(hp, ankle, THIGH, SHIN, -1)
        sk["hip" + tag], sk["knee" + tag], sk["ankle" + tag] = hp, knee, ankle
    sa = math.radians(p["sw"])
    sk["sdir"] = (math.sin(sa), -math.cos(sa))
    off = _rot(p["nh"], lean)
    elbow, hand = ik2(nsh, (nsh[0] + off[0], nsh[1] + off[1]), UARM, FARM, 1)
    sk["elbown"], sk["handn"] = elbow, hand
    if p.get("two") is not None and p.get("weapon"):
        tgt = (hand[0] + sk["sdir"][0] * p["two"] * p["wscale"], hand[1] + sk["sdir"][1] * p["two"] * p["wscale"])
    else:
        o2 = _rot(p["fh"], lean)
        tgt = (fsh[0] + o2[0], fsh[1] + o2[1])
    elbow, hand = ik2(fsh, tgt, UARM, FARM, 1)
    sk["elbowf"], sk["handf"] = elbow, hand
    w = p.get("weapon")
    L = WEAPON_LEN.get(w, 0.0) * p["wscale"]
    sk["tip"] = (sk["handn"][0] + sk["sdir"][0] * L, sk["handn"][1] + sk["sdir"][1] * L)
    if _depth < 8:           # keep every extremity inside the cell (shift the whole body, never the pose shape)
        right = max(sk["handn"][0] + 3.2, sk["handf"][0] + 3.2, sk["anklen"][0] + 5.0, sk["ankled"][0] + 5.0 if "ankled" in sk else 0, sk["anklef"][0] + 5.0, head[0] + 13.0,
                    sk["tip"][0] + (1.5 if w else 0.0))
        left = min(sk["handn"][0] - 3.2, sk["handf"][0] - 3.2, sk["anklen"][0] - 4.0, sk["anklef"][0] - 4.0, head[0] - 13.0,
                   sk["tip"][0] - (1.5 if w else 0.0))
        if right > 59.4:
            q = dict(p)
            q["hx"] = p["hx"] - (right - 59.4)
            return skeleton(q, _depth + 1)
        if left < 2.8:
            q = dict(p)
            q["hx"] = p["hx"] + (2.8 - left)
            return skeleton(q, _depth + 1)
    if w and _depth < 8:
        # keep the weapon inside the cell and (unless planted) above the ground
        tx, ty = sk["tip"]
        if w == "axe":      # the head hangs sideways off the haft: measure its lowest corner
            d = sk["sdir"]
            ty = max(ty, sk["handn"][1] + (d[1] * 9.8 + d[0] * 8.2) * p["wscale"])
        limit = 59.6 if p.get("plant") else 58.4
        q = dict(p)
        changed = False
        if ty > limit and (sk["sdir"][1] > 0 or w == "axe"):
            a = p["sw"]
            for _ in range(60):          # swing the blade towards horizontal until it clears the floor
                a += -3.0 if math.sin(math.radians(a)) > 0 else 3.0
                dy = -math.cos(math.radians(a))
                dx = math.sin(math.radians(a))
                low = sk["handn"][1] + dy * L
                if w == "axe":
                    low = max(low, sk["handn"][1] + (dy * 9.8 + dx * 8.2) * p["wscale"])
                if low <= limit or abs(math.sin(math.radians(a))) > 0.995:
                    break
            q["sw"] = a % 360.0
            changed = True
        elif ty > limit + 0.5:       # blade already horizontal but the hand itself is too low: lift the body
            q["hy"] = p["hy"] - (ty - limit) * 0.9
            changed = True
        if tx > 59.0:
            q["hx"] = p["hx"] - (tx - 59.0) * 0.8
            q["nh"] = (p["nh"][0] - (tx - 59.0) * 0.4, p["nh"][1])
            changed = True
        elif tx < 3.0:
            q["hx"] = p["hx"] + (3.0 - tx) * 0.7
            changed = True
        if ty < 2.0:
            q["hy"] = p["hy"] + (2.0 - ty)
            changed = True
        if changed:
            return skeleton(q, _depth + 1)
    return sk


def chain_specs(sk, p):
    lr = sk["lean"]

    def rests(anchor, offs):
        return [(anchor[0] + _rot(o, lr)[0], min(anchor[1] + _rot(o, lr)[1], 57.0)) for o in offs]
    a1 = (sk["sh"][0] + _rot((-4.8, -0.8), lr)[0], sk["sh"][1] + _rot((-4.8, -0.8), lr)[1])
    a2 = (a1[0] + 0.4, a1[1] + 1.6)
    hr = math.radians(lr + p["head"])
    ap = (sk["head"][0] + _rot((-8.4, -3.2), lr + p["head"])[0], sk["head"][1] + _rot((-8.4, -3.2), lr + p["head"])[1])
    a1, a2, ap = ((a[0], min(a[1], 55.0)) for a in (a1, a2, ap))
    return {
        "tail1": (a1, rests(a1, [(-3, 1.6), (-6, 3.8), (-8.6, 6.8), (-10.6, 10.2), (-11.6, 13.6)])),
        "tail2": (a2, rests(a2, [(-2.6, 3.2), (-4.6, 6.8), (-5.6, 10.2), (-5.6, 13.4)])),
        "pony": (ap, rests(ap, [(-2.6, 2.6), (-4.2, 6.2), (-4.6, 10.0)])),
    }


def simulate(sks, poses_, loop):
    specs = [chain_specs(s, p) for s, p in zip(sks, poses_)]
    wind = [p["wind"] for p in poses_]
    out = [dict() for _ in sks]
    cfg = {"tail1": (0.10, 0.80, 0.16), "tail2": (0.12, 0.78, 0.22), "pony": (0.15, 0.78, 0.20)}
    for name, (st, dm, gr) in cfg.items():
        anchors = [sp[name][0] for sp in specs]
        rests = [sp[name][1] for sp in specs]
        res = simulate_chain(anchors, rests, stiffness=st, damping=dm, gravity=gr, wind=wind, loop=loop)
        for i, pts in enumerate(res):
            out[i][name] = pts
    return out


# --------------------------------------------------------------------- face

EYE = (36, 28, 62)
IRIS = (74, 156, 178)
BROW = (120, 52, 30)
MOUTH = (118, 52, 62)
TONGUE = (226, 110, 120)
BLUSH = (240, 140, 130)


def paint_face(buf, cv, head, expr):
    rgba, mat, filled = buf["rgba"], buf["mat"], buf["filled"]
    sm = cv.matidx["skin"]
    hx, hy = int(round(head[0])), int(round(head[1]))

    def put(dx, dy, col):
        x, y = hx + dx, hy + dy
        if 0 <= x < rgba.shape[1] and 0 <= y < rgba.shape[0] and filled[y, x] and mat[y, x] == sm:
            rgba[y, x, :3] = col

    def eye(c0, r0, kind):
        if kind == "open":           # 2x3 with a highlight and an iris glint
            put(c0, r0, (255, 255, 255)); put(c0 + 1, r0, EYE)
            put(c0, r0 + 1, EYE); put(c0 + 1, r0 + 1, EYE)
            put(c0, r0 + 2, IRIS); put(c0 + 1, r0 + 2, EYE)
        elif kind == "narrow":       # 2x2 (focused / angry)
            put(c0, r0 + 1, (255, 255, 255)); put(c0 + 1, r0 + 1, EYE)
            put(c0, r0 + 2, EYE); put(c0 + 1, r0 + 2, EYE)
        elif kind == "blink":
            put(c0, r0 + 2, EYE); put(c0 + 1, r0 + 2, EYE)
        elif kind == "happy":        # ^ ^
            put(c0, r0 + 2, EYE); put(c0 + 1, r0 + 1, EYE); put(c0 + 2, r0 + 2, EYE)
        elif kind == "hurt_l":       # >
            put(c0, r0, EYE); put(c0 + 1, r0 + 1, EYE); put(c0, r0 + 2, EYE)
        elif kind == "hurt_r":       # <
            put(c0 + 1, r0, EYE); put(c0, r0 + 1, EYE); put(c0 + 1, r0 + 2, EYE)
        elif kind == "dead":         # x
            put(c0, r0, EYE); put(c0 + 1, r0 + 1, EYE); put(c0, r0 + 2, EYE); put(c0 + 1, r0, EYE); put(c0, r0 + 1, EYE); put(c0 + 1, r0 + 2, EYE)

    back, front = 0, 5      # column of the far and near eye
    r0 = 1
    kinds = {
        "neutral": ("open", "open"), "blink": ("blink", "blink"), "focus": ("narrow", "narrow"),
        "angry": ("narrow", "narrow"), "shout": ("narrow", "narrow"), "happy": ("happy", "happy"),
        "hurt": ("hurt_l", "hurt_r"), "dead": ("dead", "dead"),
    }[expr]
    eye(back, r0, kinds[0])
    eye(front, r0, kinds[1])
    if expr in ("angry", "shout"):       # slanted brows
        put(back - 1, r0, BROW); put(back, r0, BROW); put(back + 1, r0 + 1 - 1, BROW)
        put(front + 2, r0, BROW); put(front + 1, r0, BROW); put(front, r0 + 1 - 1, BROW)
        put(back + 1, r0 - 0, BROW)
    elif expr == "focus":
        put(back, r0, BROW); put(back + 1, r0, BROW); put(front, r0, BROW); put(front + 1, r0, BROW)
    if expr in ("neutral", "blink", "happy", "focus"):
        put(back - 2, r0 + 3, BLUSH); put(back - 1, r0 + 3, BLUSH)
        put(front + 2, r0 + 3, BLUSH); put(front + 3, r0 + 3, BLUSH)
    # mouth
    if expr == "shout":
        for dx, dy, c in ((2, 5, MOUTH), (3, 5, MOUTH), (4, 5, MOUTH), (2, 6, MOUTH), (3, 6, TONGUE), (4, 6, MOUTH), (3, 7, MOUTH)):
            put(dx, dy, c)
    elif expr == "happy":
        for dx, dy in ((1, 5), (2, 6), (3, 6), (4, 6), (5, 5)):
            put(dx, dy, MOUTH)
        put(3, 7, TONGUE)
    elif expr == "hurt":
        for dx, dy in ((2, 6), (3, 6), (4, 6), (3, 7)):
            put(dx, dy, MOUTH)
    elif expr == "dead":
        put(3, 6, MOUTH); put(4, 6, MOUTH)
    elif expr in ("angry", "focus"):
        put(2, 6, MOUTH); put(3, 6, MOUTH); put(4, 6, MOUTH)
    else:
        put(3, 6, MOUTH); put(4, 6, MOUTH); put(5, 5, MOUTH)


# --------------------------------------------------------------------- draw


def _w(hand, d, a, n=0.0):
    nx, ny = -d[1], d[0]
    return (hand[0] + d[0] * a + nx * n, hand[1] + d[1] * a + ny * n)


def _draw_weapon(cv, kind, hand, d, ws):
    if kind == "sword":
        g0 = _w(hand, d, -2.8 * ws)
        cv.paint("leather", Mask(CELL).capsule(g0, _w(hand, d, 0.8 * ws), 1.0, 1.0), group="sword", k=2, deep=False)
        cv.paint("bronze", Mask(CELL).circle(_w(hand, d, -3.2 * ws), 1.3), group="sword", k=2, deep=False)
        cv.paint("bronze", Mask(CELL).capsule(_w(hand, d, 1.0 * ws, -3.0), _w(hand, d, 1.0 * ws, 3.0), 0.9, 0.9), group="guard", k=2, deep=False, hi=False)
        b0, tip = _w(hand, d, 1.8 * ws), _w(hand, d, WEAPON_LEN["sword"] * ws)
        cv.paint("metal", Mask(CELL).poly([_w(hand, d, 1.8 * ws, 1.9), _w(hand, d, 12.5 * ws, 1.8), tip, _w(hand, d, 12.5 * ws, -1.8),
                                           _w(hand, d, 1.8 * ws, -1.9)]), group="blade", k=2, deep=False)
    elif kind == "spear":
        s0, s1 = _w(hand, d, -5.5 * ws), _w(hand, d, 12.0 * ws)
        cv.paint("wood", Mask(CELL).capsule(s0, s1, 0.85, 0.85), group="sword", k=2, deep=False)
        cv.paint("bronze", Mask(CELL).circle(_w(hand, d, -5.6 * ws), 1.1), group="sword", k=2, deep=False, hi=False)
        cv.paint("sash", Mask(CELL).ribbon([_w(hand, d, 11.2 * ws), _w(hand, d, 9.6 * ws, 2.4), _w(hand, d, 6.4 * ws, 3.4)], 1.0, 0.5), group="tassel", k=2, deep=False, hi=False)
        tip = _w(hand, d, WEAPON_LEN["spear"] * ws)
        cv.paint("metal", Mask(CELL).poly([_w(hand, d, 12.0 * ws, 1.3), _w(hand, d, 14.4 * ws, 2.3), tip, _w(hand, d, 14.4 * ws, -2.3),
                                           _w(hand, d, 12.0 * ws, -1.3)]), group="blade", k=2, deep=False)
    elif kind == "axe":
        h0, h1 = _w(hand, d, -3.5 * ws), _w(hand, d, 10.6 * ws)
        cv.paint("wood", Mask(CELL).capsule(h0, h1, 1.0, 1.0), group="sword", k=2, deep=False)
        cv.paint("bronze", Mask(CELL).circle(_w(hand, d, -4.0 * ws), 1.3), group="sword", k=2, deep=False, hi=False)
        cv.paint("metal", Mask(CELL).poly([_w(hand, d, 7.2 * ws, 0.6), _w(hand, d, 6.0 * ws, 4.4), _w(hand, d, 7.2 * ws, 7.2),
                                           _w(hand, d, 9.8 * ws, 8.2), _w(hand, d, 11.6 * ws, 6.2), _w(hand, d, 10.8 * ws, 1.0)]), group="blade", k=2, deep=False)
        cv.paint("bronze", Mask(CELL).poly([_w(hand, d, 7.8 * ws, -0.6), _w(hand, d, 7.2 * ws, -3.0), _w(hand, d, 9.6 * ws, -2.0), _w(hand, d, 10.4 * ws, -0.4)]),
                 group="guard", k=2, deep=False, hi=False)


def _arm(cv, sk, tag, front):
    sh = sk["nsh"] if tag == "n" else sk["fsh"]
    elbow, hand = sk["elbow" + tag], sk["hand" + tag]
    g = "armF" if tag == "n" else "armB"
    cv.paint("tunic", Mask(CELL).capsule(sh, elbow, 2.1, 1.8), group=g, k=3)
    cv.paint("skin", Mask(CELL).capsule(elbow, hand, 1.4, 1.2).circle(hand, 1.7), group=g + "2", k=3)
    cv.paint("leather", Mask(CELL).capsule((elbow[0] * 0.5 + hand[0] * 0.5, elbow[1] * 0.5 + hand[1] * 0.5),
                                          (elbow[0] * 0.15 + hand[0] * 0.85, elbow[1] * 0.15 + hand[1] * 0.85), 1.65, 1.55),
             group=g + "2", k=2, deep=False, hi=False)
    if tag == "n":
        cv.paint("bronze", Mask(CELL).circle((sh[0] + 0.2, sh[1] - 0.2), 2.8), group="pauldron", k=3, cast=3)


SUPPORTS_TRAIL = True
SMEAR_COL = (232, 242, 255)


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0


def _smear(buf, sk, trail, p):
    """Dithered, outline-less motion smear: the outer part of the blade swept over the last two ticks.
    Dense next to the current blade, thinning out behind it."""
    w = p.get("weapon")
    if not w or not trail:
        return
    ws = p["wscale"]
    L = WEAPON_LEN[w] * ws
    inner = 0.55 if w != "axe" else 0.5

    def state(s_):
        d, h = s_["sdir"], s_["handn"]
        return h, math.degrees(math.atan2(d[0], -d[1]))

    cur, prev1, prev2 = state(sk), state(trail[0]), state(trail[1])
    tip_c = (cur[0][0] + sk["sdir"][0] * L, cur[0][1] + sk["sdir"][1] * L)
    tip_p = (prev1[0][0] + trail[0]["sdir"][0] * L, prev1[0][1] + trail[0]["sdir"][1] * L)
    sp = math.hypot(tip_c[0] - tip_p[0], tip_c[1] - tip_p[1])
    if sp < 6.5:
        return

    def mix(a, b, f):
        d = (b[1] - a[1] + 180.0) % 360.0 - 180.0
        return ((a[0][0] + (b[0][0] - a[0][0]) * f, a[0][1] + (b[0][1] - a[0][1]) * f), a[1] + d * f)

    K = 10
    age = np.full((CELL, CELL), 9.0, np.float32)
    for k in range(K + 1):
        f = k / K                                   # 0 = now, 1 = two ticks ago
        st_ = mix(cur, prev1, f * 2.0) if f <= 0.5 else mix(prev1, prev2, (f - 0.5) * 2.0)
        (hx, hy), ang = st_
        d = (math.sin(math.radians(ang)), -math.cos(math.radians(ang)))
        a0 = (hx + d[0] * L * inner, hy + d[1] * L * inner)
        a1 = (hx + d[0] * L, hy + d[1] * L)
        m = Mask(CELL).capsule(a0, a1, 0.6, 0.9).array().reshape(CELL, SSF, CELL, SSF).mean(axis=(1, 3)) > 0.3
        age = np.where(m & (age > f), f, age)
    show = (age < 9.0) & ~buf["filled"]
    show &= BAYER4[np.arange(CELL)[:, None] % 4, np.arange(CELL)[None, :] % 4] < (1.0 - age) * 0.95
    show[0, :] = show[-1, :] = False
    show[:, 0] = show[:, -1] = False
    show[55:, :] = False                      # never smear along the floor
    rgba = buf["rgba"]
    rgba[show, :3] = SMEAR_COL
    rgba[show, 3] = 255


def draw(sk, chains, p, trail=None):
    cv = Canvas(CELL, MATERIALS)
    xs, ys = cv.xs, cv.ys
    lr = math.radians(sk["lean"])
    head = sk["head"]
    hx, hy = head
    spin = p.get("spin")
    fh = p["fh"]
    late_far = spin is not None or (p.get("two") is not None and p.get("weapon")) or fh[0] > 3.5 or fh[1] < 1.0

    cv.paint("scarf", Mask(CELL).ribbon(chains["tail1"], 3.0, 1.2), group="tail1", k=3, deep=False, hi=False)
    cv.paint("scarf", Mask(CELL).ribbon(chains["tail2"], 2.5, 1.0), group="tail2", k=3, deep=False, hi=False)
    cv.paint("hair", Mask(CELL).ribbon(chains["pony"], 3.0, 1.1), group="pony", k=3, deep=False)
    cv.paint("hair", Mask(CELL).circle((hx - 2.0, hy - 1.6), 9.7), group="hair", k=5)
    if not late_far and spin is None:
        _arm(cv, sk, "f", False)
    # far leg
    cv.paint("pants", Mask(CELL).capsule(sk["hipf"], sk["kneef"], 3.0, 2.6), group="legB", k=4)
    kf, af = sk["kneef"], sk["anklef"]
    cv.paint("boots", Mask(CELL).capsule(kf, af, 2.7, 2.2).capsule((af[0] - 0.9, af[1] + 0.9), (af[0] + 3.4, af[1] + 1.2), 2.2, 1.9), group="bootB", k=3)
    cv.paint("leather", Mask(CELL).capsule((kf[0] * 0.78 + af[0] * 0.22, kf[1] * 0.78 + af[1] * 0.22), (kf[0] * 0.62 + af[0] * 0.38, kf[1] * 0.62 + af[1] * 0.38), 2.9, 2.9),
             group="bootB", k=2, deep=False, hi=False)
    # torso: tunic, hem, belt, strap
    hip, sh = sk["hip"], sk["sh"]
    torso = Mask(CELL).capsule(hip, sh, 4.7, 4.2)
    cv.paint("tunic", torso, group="torso", k=5)
    ta = torso.array()
    hem = Mask(CELL).ellipse((hip[0] + math.sin(lr) * 0.8, hip[1] - math.cos(lr) * 0.8 + 1.0), 5.8, 2.6, sk["lean"])
    cv.paint("tunic", hem.array(), group="hem", k=3, deep=True)
    belt = Mask(CELL).ellipse((hip[0] + math.sin(lr) * 2.6, hip[1] - math.cos(lr) * 2.6), 5.3, 1.7, sk["lean"])
    cv.paint("sash", belt.array() & (ta | hem.array()), group="belt", k=3, deep=False)
    bk = (hip[0] + math.sin(lr) * 2.6 + math.cos(lr) * 1.8, hip[1] - math.cos(lr) * 2.6 + math.sin(lr) * 1.8)
    cv.paint("bronze", Mask(CELL).circle(bk, 1.15), group="belt", k=2, deep=False)
    strap = Mask(CELL).capsule((sh[0] - 3.4, sh[1] - 0.4), (hip[0] + 3.2, hip[1] - 0.6), 0.9, 0.9)
    cv.paint("leather", strap.array() & ta, group="strap", k=2, deep=False, hi=False)
    # near leg
    cv.paint("pants", Mask(CELL).capsule(sk["hipn"], sk["kneen"], 3.1, 2.7), group="legF", k=4)
    kn, an = sk["kneen"], sk["anklen"]
    cv.paint("boots", Mask(CELL).capsule(kn, an, 2.8, 2.3).capsule((an[0] - 0.9, an[1] + 0.9), (an[0] + 3.6, an[1] + 1.2), 2.3, 2.0), group="bootF", k=3)
    cv.paint("leather", Mask(CELL).capsule((kn[0] * 0.78 + an[0] * 0.22, kn[1] * 0.78 + an[1] * 0.22), (kn[0] * 0.62 + an[0] * 0.38, kn[1] * 0.62 + an[1] * 0.38), 3.0, 3.0),
             group="bootF", k=2, deep=False, hi=False)
    # head
    face = Mask(CELL).circle(head, 9.0)
    cv.paint("skin", face, group="head", k=5, cast=5)
    fa = face.array()
    bang = Mask(CELL).poly([(hx - 11, hy - 12), (hx + 11, hy - 12), (hx + 10.4, hy - 3.2), (hx + 8.2, hy - 0.6), (hx + 6.9, hy - 3.4),
                            (hx + 4.4, hy - 0.4), (hx + 2.6, hy - 3.8), (hx - 0.6, hy - 1.0), (hx - 2.8, hy - 3.6), (hx - 6.0, hy - 2.2), (hx - 11, hy - 1.6)])
    hair_front = (bang.array() & Mask(CELL).circle((hx - 0.3, hy - 0.8), 9.7).array()) | (fa & (xs < hx - 4.6))
    cv.paint("hair", hair_front, group="hair", k=4)
    cv.paint("hair", Mask(CELL).ellipse((hx - 0.8, hy - 8.3), 8.6, 3.2, -4), group="hair", k=4)
    cv.paint("hair", Mask(CELL).capsule((hx + 1.2, hy - 9.4), (hx + 4.6, hy - 14.2), 1.5, 0.35), group="hair", k=2, deep=False)
    cv.paint("hair", Mask(CELL).capsule((hx - 2.0, hy - 9.6), (hx - 3.4, hy - 13.4), 1.3, 0.35), group="hair", k=2, deep=False)
    # scarf collar + knot
    collar = Mask(CELL).ellipse((sh[0] + 0.6, sh[1] - 0.1), 6.4, 2.9, sk["lean"])
    cv.paint("scarf", collar, group="scarf", k=3, cast=3)
    cv.paint("scarf", Mask(CELL).circle(_w(sh, (math.cos(lr), math.sin(lr)), -4.4, 0.2), 2.2), group="scarf", k=2, deep=False)
    if late_far:
        _arm(cv, sk, "f", False)
    if spin is not None:
        c = math.cos(math.radians(spin))
        cv.warp_x(sk["hip"][0], max(abs(c), 0.42), mirror=c < 0)
        if c < 0:      # we are looking at the back of the head
            cv.paint("hair", Mask(CELL).circle((hx, hy - 0.2), 9.3), group="hair", k=5)
    _arm(cv, sk, "n", True)
    if p.get("weapon"):
        _draw_weapon(cv, p["weapon"], sk["handn"], sk["sdir"], p["wscale"])
    buf = cv.finish(NO_SEAM)
    if spin is None or math.cos(math.radians(spin)) > 0.35:
        paint_face(buf, cv, head, p["expr"])
    _smear(buf, sk, trail, p)
    return cv, buf


def anchors(sk):
    d = sk["sdir"]
    return {"hand": sk["handn"], "hand_dir": d, "off_hand": sk["handf"], "head": sk["head"],
            "chest": sk["sh"], "weapon_tip": sk["tip"]}

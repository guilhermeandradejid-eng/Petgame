"""Bolo B animations. Same clip names and game contract as before, poses rebuilt for a round body:
almost no legs (he waddles), short arms, big head. Each clip names the Disney principles it uses.

Axes (anim.py): +X leans forward / swings a hanging limb back, -X swings it forward; +Y lowers the
left arm and raises the right one; +Z turns to the character's left.
"""
import math

from anim import Clip, wave, add_pose

TAIL = ["tail%d" % i for i in range(1, 6)]


def arms(up_l=0.0, up_r=0.0, fwd_l=0.0, fwd_r=0.0, elbow_l=-10.0, elbow_r=-10.0):
    """up: degrees raised sideways from rest; fwd: swung forward; elbow: bend forward."""
    return {
        "arm_upper.L": {"r": (-fwd_l, -up_l, 0)},
        "arm_upper.R": {"r": (-fwd_r, up_r, 0)},
        "arm_lower.L": {"r": (elbow_l, 0, 0)},
        "arm_lower.R": {"r": (elbow_r, 0, 0)},
    }


def legs(fwd_l=0.0, fwd_r=0.0, knee_l=0.0, knee_r=0.0, toe_l=0.0, toe_r=0.0):
    return {
        "leg_upper.L": {"r": (-fwd_l, 0, 0)}, "leg_lower.L": {"r": (knee_l, 0, 0)}, "foot.L": {"r": (toe_l, 0, 0)},
        "leg_upper.R": {"r": (-fwd_r, 0, 0)}, "leg_lower.R": {"r": (knee_r, 0, 0)}, "foot.R": {"r": (toe_r, 0, 0)},
    }


def P(*parts, **bones):
    out = {}
    for p in parts:
        out = add_pose(out, p)
    return add_pose(out, bones)


BASE = P(arms(0, 0, 8, 8), {"head": {"r": (-2, 0, 0)}})


def tail_wave(amp_z=6.0, amp_x=0.0, period=60, lag=0.55, base_x=0.0):
    def fn(f):
        return {t: {"r": (base_x + amp_x * wave(f, period, -lag * i), 0, amp_z * wave(f, period, -lag * i - 0.3))}
                for i, t in enumerate(TAIL)}
    return fn


def ears(amp=4.0, period=60, lag=1.0, droop=0.0):
    def fn(f):
        w = amp * wave(f, period, -lag)
        return {"ear.L": {"r": (0, droop + w, 0)}, "ear.R": {"r": (0, -droop - w, 0)}}
    return fn


def blink_at(frames, length=5):
    def fn(f):
        for b in frames:
            if b <= f <= b + length:
                k = 1 - 0.9 * math.sin(math.pi * (f - b) / length)
                return {"eye.L": {"s": (1, 1, k)}, "eye.R": {"s": (1, 1, k)}}
        return {}
    return fn


def idle():
    """Belly breathing (squash and stretch, slow in/out), head lags (overlap), tail and ear drift."""
    n = 64
    c = Clip("idle", n, loop=True).k(0, BASE).k(n, BASE)

    def breathe(f):
        w = wave(f, n)
        lag = wave(f, n, -0.8)
        return {"squash": {"s": (1 + 0.018 * w, 1 + 0.018 * w, 1 - 0.022 * w)},
                "chest": {"r": (-1.5 * w, 0, 0)},
                "head": {"r": (2.0 * lag, 0, 0)},
                "arm_upper.L": {"r": (0, -3 * lag, 0)}, "arm_upper.R": {"r": (0, 3 * lag, 0)}}
    c.overlay(breathe).overlay(tail_wave(7, 3, n)).overlay(ears(5, n)).overlay(blink_at([44]))
    return c


def walk():
    """A waddle: the whole ball rocks onto each foot (arcs), arms counter-swing, head lags."""
    n = 28

    def pose(f):
        a = 2 * math.pi * f / n
        c = math.cos(a)
        s = math.sin(a)
        lift_l = max(0.0, -s)
        lift_r = max(0.0, s)
        return P(arms(4, 4, -20 * c, 20 * c, -15, -15),
                 legs(30 * c, -30 * c, 25 * lift_l, 25 * lift_r, -15 * lift_l, -15 * lift_r),
                 squash={"r": (0, 7 * s, 0), "l": (0, 0, 0.025 * abs(s)), "s": (1 + 0.02 * math.cos(2 * a), 1, 1 - 0.03 * math.cos(2 * a))},
                 hips={"r": (4, 0, 7 * c)},
                 head={"r": (-3 + 2 * math.cos(2 * a - 0.8), -3 * math.sin(a - 0.6), -4 * math.cos(a - 0.5))})
    c = Clip("walk", n, loop=True)
    for f in range(0, n + 1, 2):
        c.k(f, pose(f % n), "linear")
    c.overlay(tail_wave(12, 4, n, 0.6)).overlay(ears(6, n // 2, 1.2))
    return c


def run():
    """Leans into the run with arms pumping, little hops on every step: squash on contact, stretch in the air."""
    n = 16

    def pose(f):
        a = 2 * math.pi * f / n
        c, s = math.cos(a), math.sin(a)
        air = abs(s)
        return P(arms(10, 10, -45 * c - 15, 45 * c - 15, -40, -40),
                 legs(55 * c, -55 * c, 50 * max(0.0, -s), 50 * max(0.0, s), -25 * max(0.0, -s), -25 * max(0.0, s)),
                 squash={"r": (16, 5 * s, 0), "l": (0, 0, 0.06 * air),
                         "s": (1 + 0.05 * (1 - air) - 0.02 * air, 1, 1 - 0.07 * (1 - air) + 0.06 * air)},
                 hips={"r": (0, 0, 10 * c)},
                 head={"r": (-14 + 3 * math.cos(2 * a - 0.9), 0, -5 * math.cos(a - 0.5))})
    c = Clip("run", n, loop=True)
    for f in range(0, n + 1):
        c.k(f, pose(f % n), "linear")
    c.overlay(lambda f: {t: {"r": (30 + 8 * wave(f, n / 2, -0.7 * i), 0, 14 * wave(f, n, -0.6 * i))} for i, t in enumerate(TAIL)})
    c.overlay(lambda f: {"ear.L": {"r": (-20, 6 * wave(f, n / 2), 0)}, "ear.R": {"r": (-20, -6 * wave(f, n / 2), 0)}})
    return c


def skid():
    """Digs both heels in and leans back with the arms thrown up: exaggeration and follow-through."""
    plant = P(arms(70, 45, 35, 50, -20, -10), legs(45, 30, 0, 10, -25, -15),
              squash={"r": (-22, 0, 0), "s": (1.1, 1.05, 0.88)}, head={"r": (-10, 0, 0)},
              **{"eye.L": {"s": 1.2}, "eye.R": {"s": 1.2}})
    c = Clip("skid", 18)
    c.k(0, P(BASE, squash={"r": (10, 0, 0)}), "out").k(4, plant, "inout")
    c.k(10, add_pose(plant, {"squash": {"r": (5, 0, 0), "s": (0.97, 0.97, 1.04)}}), "inout").k(18, plant)
    c.overlay(lambda f: {t: {"r": (-30 * min(1, f / 6), 0, 12 * wave(f, 12, -0.7 * i) * max(0, 1 - f / 18))} for i, t in enumerate(TAIL)})
    c.overlay(lambda f: {"ear.L": {"r": (25, 0, 0)}, "ear.R": {"r": (25, 0, 0)}})
    return c


CROUCH = P(arms(-5, -5, -30, -30, -10, -10), legs(20, 20, 40, 40, -20, -20),
           squash={"s": (1.15, 1.15, 0.78), "r": (10, 0, 0)}, head={"r": (-8, 0, 0)})
TAKEOFF = P(arms(80, 80, 25, 25, -5, -5), legs(-10, -10, 0, 0, 40, 40),
            squash={"s": (0.88, 0.88, 1.22)}, head={"r": (-12, 0, 0)}, **{"eye.L": {"s": 1.1}, "eye.R": {"s": 1.1}})
RISE = P(arms(60, 50, 20, 10, -20, -20), legs(25, -10, 30, 15, 10, 20), squash={"s": (0.95, 0.95, 1.08)}, head={"r": (-10, 0, 0)})
APEX = P(arms(45, 45, 15, 15, -25, -25), legs(35, 20, 45, 35, 0, 0), squash={"s": (1.05, 1.05, 0.93)}, head={"r": (-4, 0, 0)})
FALL = P(arms(95, 95, 10, 10, -15, -15), legs(-10, 10, 10, 20, 25, 15), squash={"s": (0.95, 0.95, 1.08)},
         head={"r": (-14, 0, 0)}, **{"eye.L": {"s": 1.12}, "eye.R": {"s": 1.12}})


def jump():
    """Short anticipation crouch, then the stretch of take-off easing into the rise."""
    c = Clip("jump", 14)
    c.k(0, BASE, "out").k(2, CROUCH, "linear").k(4, TAKEOFF, "out").k(14, RISE)
    c.overlay(lambda f: {t: {"r": (-25 * min(1, f / 5) + 10 * max(0, f - 5) / 9, 0, 0)} for t in TAIL})
    c.overlay(lambda f: {"ear.L": {"r": (35 if f > 3 else 0, 0, 0)}, "ear.R": {"r": (35 if f > 3 else 0, 0, 0)}})
    return c


def apex():
    c = Clip("apex", 10)
    c.k(0, RISE, "inout").k(5, APEX, "inout").k(10, add_pose(APEX, {"squash": {"s": (0.98, 0.98, 1.03)}}))
    c.overlay(lambda f: {t: {"r": (10 * wave(f, 20, -0.5 * i), 0, 0)} for i, t in enumerate(TAIL)})
    return c


def fall():
    n = 16
    c = Clip("fall", n, loop=True).k(0, FALL).k(n, FALL)
    c.overlay(lambda f: P(arms(8 * wave(f, n), 8 * wave(f, n, 1.2)), legs(10 * wave(f, n, 0.5), 10 * wave(f, n, 2.0))))
    c.overlay(lambda f: {t: {"r": (-35 + 6 * wave(f, n / 2, -0.6 * i), 0, 6 * wave(f, n, -0.5 * i))} for i, t in enumerate(TAIL)})
    c.overlay(lambda f: {"ear.L": {"r": (-30 + 8 * wave(f, n / 2), 0, 0)}, "ear.R": {"r": (-30 + 8 * wave(f, n / 2, 0.8), 0, 0)}})
    return c


def land():
    """The ball squashes on impact, overshoots a little and settles (ease out of the hit)."""
    hit = P(arms(30, 30, 10, 10, -25, -25), legs(15, 15, 40, 40, -20, -20), squash={"s": (1.2, 1.2, 0.74)}, head={"r": (8, 0, 0)})
    c = Clip("land", 14)
    c.k(0, hit, "out").k(4, P(BASE, squash={"s": (0.96, 0.96, 1.06)}), "inout").k(9, BASE, "inout").k(14, BASE)
    c.overlay(lambda f: {t: {"r": (20 * math.exp(-f / 4) * math.cos(f * 0.8 - 0.4 * i), 0, 0)} for i, t in enumerate(TAIL)})
    c.overlay(lambda f: {"ear.L": {"r": (25 * math.exp(-f / 4) * math.cos(f * 0.9), 0, 0)}, "ear.R": {"r": (25 * math.exp(-f / 4) * math.cos(f * 0.9), 0, 0)}})
    return c


def land_heavy():
    """Big drop: a deep squash, eyes squeezed, ears and tail slap down, then he wobbles back up."""
    hit = P(arms(60, 60, 20, 20, -30, -30), legs(30, 30, 50, 50, -25, -25), squash={"s": (1.35, 1.35, 0.6)},
            head={"r": (14, 0, 0)}, **{"eye.L": {"s": (1, 1, 0.3)}, "eye.R": {"s": (1, 1, 0.3)}})
    rec = P(arms(20, 20, 10, 10, -20, -20), squash={"s": (1.06, 1.06, 0.9)}, head={"r": (-4, 0, 0)})
    c = Clip("land_heavy", 30)
    c.k(0, hit, "out").k(3, add_pose(hit, {"squash": {"s": (1.02, 1.02, 0.96)}}), "inout")
    c.k(14, rec, "inout").k(20, P(BASE, squash={"s": (0.94, 0.94, 1.08)}), "inout").k(26, BASE, "inout").k(30, BASE)
    c.overlay(lambda f: {t: {"r": (45 * math.exp(-f / 7) * math.cos(f * 0.55 - 0.5 * i), 0, 0)} for i, t in enumerate(TAIL)})
    c.overlay(lambda f: {"ear.L": {"r": (50 * math.exp(-f / 6) * math.cos(f * 0.7), 0, 0)}, "ear.R": {"r": (50 * math.exp(-f / 6) * math.cos(f * 0.7 + 0.4), 0, 0)}})
    return c


def double_jump():
    """The owl gives him a boost and he rolls forward like a ball around his own centre (arcs)."""
    n = 22
    tuck = P(arms(-10, -10, 50, 50, -60, -60), legs(60, 60, 60, 60, 0, 0), head={"r": (20, 0, 0)},
             squash={"s": (1.05, 1.05, 0.9)})
    kick = P(arms(90, 90, 15, 15, 0, 0), legs(-15, 25, 0, 20, 40, 10), squash={"s": (0.88, 0.88, 1.2)})
    c = Clip("double_jump", n)
    c.k(0, kick, "out").k(5, tuck, "inout").k(16, tuck, "inout").k(n, FALL)
    centre, pivot = 0.55, 0.0

    def flip(f):
        u = min(1.0, max(0.0, (f - 3) / 13.0))
        u = u * u * (3 - 2 * u)
        t = math.radians(360.0 * u)
        r = centre - pivot
        return {"squash": {"r": (360.0 * u, 0, 0), "l": (0, math.sin(t) * r, r - math.cos(t) * r)}}
    c.overlay(flip)
    c.overlay(lambda f: {t: {"r": (-30 * math.sin(min(1, f / n) * math.pi), 0, 0)} for t in TAIL})
    return c


def glide():
    """The owl carries him by the scarf: he spreads out like a skydiver, the tail steers (pendulum arcs)."""
    n = 32
    spread = P(arms(85, 85, 10, 10, -10, -10), legs(-25, -25, 20, 20, 25, 25),
               squash={"r": (18, 0, 0)}, head={"r": (-22, 0, 0)}, **{"eye.L": {"s": 1.1}, "eye.R": {"s": 1.1}})
    c = Clip("glide", n, loop=True).k(0, spread).k(n, spread)
    c.overlay(lambda f: P(arms(6 * wave(f, n / 2), 6 * wave(f, n / 2, 0.8)), legs(10 * wave(f, n / 2), -10 * wave(f, n / 2)),
                          squash={"r": (3 * wave(f, n, 0.5), 6 * wave(f, n), 0)}, head={"r": (0, -3 * wave(f, n, -0.6), 0)}))
    c.overlay(lambda f: {t: {"r": (-55 + 6 * wave(f, n / 2, -0.6 * i), 0, 10 * wave(f, n, -0.5 * i))} for i, t in enumerate(TAIL)})
    c.overlay(lambda f: {"ear.L": {"r": (-25, 10 * wave(f, 6), 0)}, "ear.R": {"r": (-25, -10 * wave(f, 6, 1.0), 0)}})
    return c


# Hanging: mittens on top of the ledge in front of his face, the round body hangs below.
HANG = P(arms(10, 10, 150, 150, -10, -10), legs(-10, -5, 20, 25, 30, 30), head={"r": (-10, 0, 0)}, squash={"s": (0.97, 0.97, 1.04)})
HANG_HANDS = (0.0, -0.3, 0.8)   # measured on the rig by build_b.py and written to the Godot constants
HANG_FRONT_Y = -0.32


def ledge_hang():
    n = 48
    c = Clip("ledge_hang", n, loop=True).k(0, HANG).k(n, HANG)
    c.overlay(lambda f: P(legs(12 * wave(f, n), 12 * wave(f, n, 2.0), 10 * max(0, wave(f, n / 2)), 0),
                          squash={"r": (3 * wave(f, n), 0, 0)}, head={"r": (0, 0, 6 * wave(f, n * 2))}))
    c.overlay(tail_wave(8, 4, n))
    return c


def ledge_climb(hand_z=None):
    hz = HANG_HANDS[2] if hand_z is None else hand_z
    pull = P(arms(10, 10, 110, 110, -90, -90), legs(30, 10, 50, 30, 0, 0), squash={"r": (15, 0, 0), "s": (0.95, 0.95, 1.06)},
             root={"l": (0, -0.05, hz * 0.6)})
    knee = P(arms(10, 10, 40, 40, -40, -40), legs(70, 10, 60, 20, 0, 0), squash={"r": (25, 0, 0)}, root={"l": (0, -0.3, hz * 0.97)})
    stand = P(BASE, root={"l": (0, -0.55, hz)})
    c = Clip("ledge_climb", 24)
    c.k(0, HANG, "in").k(8, pull, "inout").k(15, knee, "inout").k(20, add_pose(stand, {"squash": {"s": (1.06, 1.06, 0.92)}}), "inout").k(24, stand)
    c.overlay(lambda f: {t: {"r": (15 * wave(f, 18, -0.6 * i), 0, 0)} for i, t in enumerate(TAIL)})
    return c


def idle_fidget():
    """He looks up at the owl on his head, reaches up to pat it, it hops away, he shrugs (staging, appeal)."""
    look = P(BASE, head={"r": (-25, 0, 10)}, **{"eye.L": {"s": 1.15}, "eye.R": {"s": 1.15}})
    reach = P(arms(0, 150, 0, 40, -10, -60), head={"r": (-28, 0, 14)}, squash={"s": (0.95, 0.95, 1.06)})
    miss = P(arms(0, 160, 0, 30, -10, -40), head={"r": (-35, 0, 30)}, squash={"s": (0.96, 0.96, 1.05)})
    shrug = P(arms(40, 40, 20, 20, -40, -40), head={"r": (6, 0, -10)}, squash={"s": (1.04, 1.04, 0.95)},
              **{"ear.L": {"r": (0, 20, 0)}, "ear.R": {"r": (0, -20, 0)}})
    c = Clip("idle_fidget", 90)
    c.k(0, BASE, "inout").k(12, look, "inout").k(24, look, "in").k(32, reach, "out").k(44, miss, "inout")
    c.k(56, shrug, "inout").k(74, shrug, "inout").k(90, BASE)
    c.overlay(tail_wave(8, 3, 30)).overlay(blink_at([14, 66]))
    return c


ALL = [idle, idle_fidget, walk, run, skid, jump, apex, fall, land, land_heavy, double_jump, glide, ledge_hang, ledge_climb]

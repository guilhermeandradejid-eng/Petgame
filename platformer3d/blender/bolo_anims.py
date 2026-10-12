"""Bolo's animations. Every clip names the Disney principles it leans on.

Conventions (anim.py): +X leans forward and swings a hanging limb back, -X swings it forward;
+Y lowers the left arm / raises the right one; +Z turns to the character's left.
"""
import math

from anim import Clip, wave, lerp_pose, add_pose

L, R = "L", "R"


def arms(down_l, down_r, fwd_l=0.0, fwd_r=0.0, elbow_l=-15.0, elbow_r=-15.0):
    """Arm helper: degrees down from the A-pose, forward swing (+ = hand forward), elbow bend."""
    return {
        "arm_upper.L": {"r": (-fwd_l, down_l, 0)},
        "arm_upper.R": {"r": (-fwd_r, -down_r, 0)},
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


BASE = P(arms(38, 38, 4, 4), {"spine": {"r": (3, 0, 0)}, "head": {"r": (-3, 0, 0)}})
TAIL = ["tail%d" % i for i in range(1, 6)]


def tail_wave(amp_z=6.0, amp_x=0.0, period=60, lag=0.55, base_x=0.0):
    """Overlapping action: every tail segment follows the previous one a little later."""
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
    """A quick vertical squash of the eyes, the classic cartoon blink."""
    def fn(f):
        for b in frames:
            if b <= f <= b + length:
                u = (f - b) / length
                k = 1 - 0.9 * math.sin(math.pi * u)
                return {"eye.L": {"s": (1, 1, k)}, "eye.R": {"s": (1, 1, k)}}
        return {}
    return fn


# ----------------------------------------------------------------------------- idle

def idle():
    """Slow in/out breathing, overlapping head and tail, secondary ears, a blink."""
    n = 60
    c = Clip("idle", n, loop=True).k(0, BASE).k(n, BASE)

    def breathe(f):
        w = wave(f, n)
        lag = wave(f, n, -0.7)
        return {
            "squash": {"s": (1 - 0.012 * w, 1 - 0.012 * w, 1 + 0.026 * w)},
            "chest": {"r": (-2.0 * w, 0, 0)},
            "head": {"r": (2.2 * lag, 0, 1.5 * wave(f, n * 2, 0.4) if False else 0)},
            "arm_upper.L": {"r": (0, 3 * lag, 0)}, "arm_upper.R": {"r": (0, -3 * lag, 0)},
        }
    c.overlay(breathe).overlay(tail_wave(6, 2, n)).overlay(ears(4, n)).overlay(blink_at([40]))
    return c


# ----------------------------------------------------------------------------- locomotion

def walk():
    """A short-legged waddle: weight shifts side to side, arms counter-swing, head lags (arcs)."""
    n = 32

    def pose(f):
        p = f / n
        a = 2 * math.pi * p
        swing = 28 * math.cos(a)
        lift_l = max(0.0, -math.sin(a))
        lift_r = max(0.0, math.sin(a))
        bob = -0.035 * math.cos(2 * a)
        return P(BASE, arms(36, 36, -22 * math.cos(a), 22 * math.cos(a), -20, -20),
                 legs(swing, -swing, 40 * lift_l, 40 * lift_r, -20 * lift_l, -20 * lift_r),
                 hips={"l": (0, 0, bob), "r": (0, 5 * math.sin(a), 6 * math.cos(a))},
                 spine={"r": (5, -3 * math.sin(a), -9 * math.cos(a))},
                 head={"r": (-2 + 2 * math.cos(2 * a - 0.8), 3 * math.sin(a - 0.6), 4 * math.cos(a - 0.4))},
                 squash={"s": (1 + 0.02 * math.cos(2 * a), 1, 1 - 0.03 * math.cos(2 * a))})
    c = Clip("walk", n, loop=True)
    for f in range(0, n + 1, 2):
        c.k(f, pose(f % n), "linear")
    c.overlay(tail_wave(10, 3, n // 2, 0.6)).overlay(ears(5, n // 2, 1.2))
    return c


def run():
    """Leans in, arms swept back (Bolo's signature), feet whirl, squash on contact, stretch in the air."""
    n = 18

    def pose(f):
        a = 2 * math.pi * f / n
        swing = 55 * math.cos(a)
        lift_l = max(0.0, -math.sin(a))
        lift_r = max(0.0, math.sin(a))
        air = abs(math.sin(a))  # mid stride is the flight phase
        return P(arms(-5, -5, -55 + 8 * math.cos(a), -55 - 8 * math.cos(a), 20, 20),
                 legs(swing, -swing, 75 * lift_l + 10, 75 * lift_r + 10, -25 * lift_l, -25 * lift_r),
                 hips={"l": (0, 0, 0.06 * air - 0.02), "r": (0, 4 * math.sin(a), 8 * math.cos(a))},
                 spine={"r": (20, 0, -10 * math.cos(a))},
                 chest={"r": (6, 0, 0)},
                 head={"r": (-20 + 3 * math.cos(2 * a - 0.9), 0, 5 * math.cos(a - 0.5))},
                 squash={"s": (1 - 0.03 * air + 0.04 * (1 - air), 1, 1 + 0.06 * air - 0.07 * (1 - air))})
    c = Clip("run", n, loop=True)
    for f in range(0, n + 1):
        c.k(f, pose(f % n), "linear")
    c.overlay(lambda f: {t: {"r": (35 + 6 * wave(f, n / 2, -0.7 * i), 0, 12 * wave(f, n, -0.6 * i))} for i, t in enumerate(TAIL)})
    c.overlay(lambda f: {"ear.L": {"r": (-25, 6 * wave(f, n / 2), 0)}, "ear.R": {"r": (-25, -6 * wave(f, n / 2), 0)}})
    return c


def skid():
    """Brakes on the front foot and leans back, arms flail: exaggeration plus follow-through."""
    plant = P(arms(-30, -10, 40, 60, -30, -10), legs(55, -25, 0, 50, -20, 0),
              spine={"r": (-28, 0, 0)}, head={"r": (-12, 0, 0)}, hips={"l": (0, 0.08, -0.1)},
              squash={"s": (1.1, 1.05, 0.86)}, **{"eye.L": {"s": 1.2}, "eye.R": {"s": 1.2}})
    c = Clip("skid", 18)
    c.k(0, P(BASE, spine={"r": (10, 0, 0)}), "out")
    c.k(4, plant, "inout")
    c.k(10, add_pose(plant, {"spine": {"r": (6, 0, 0)}, "arm_upper.L": {"r": (-15, 0, 0)}, "squash": {"s": (0.97, 0.97, 1.04)}}), "inout")
    c.k(18, add_pose(plant, {"spine": {"r": (4, 0, 0)}}))
    c.overlay(lambda f: {t: {"r": (-30 * min(1, f / 6), 0, 10 * wave(f, 12, -0.7 * i) * max(0, 1 - f / 18))} for i, t in enumerate(TAIL)})
    c.overlay(lambda f: {"ear.L": {"r": (25, 0, 0)}, "ear.R": {"r": (25, 0, 0)}})
    return c


# ----------------------------------------------------------------------------- jumping

CROUCH = P(arms(10, 10, -40, -40, -10, -10), legs(25, 25, 50, 50, -25, -25),
           hips={"l": (0, 0.03, -0.12)}, spine={"r": (16, 0, 0)}, head={"r": (-10, 0, 0)},
           squash={"s": (1.12, 1.12, 0.8)})
TAKEOFF = P(arms(-70, -70, 30, 30, -5, -5), legs(-8, -8, 5, 5, 35, 35),
            spine={"r": (-6, 0, 0)}, head={"r": (-12, 0, 0)},
            squash={"s": (0.9, 0.9, 1.2)}, **{"eye.L": {"s": 1.1}, "eye.R": {"s": 1.1}})
RISE = P(arms(-55, -40, 25, 10, -20, -25), legs(20, -10, 45, 20, 10, 20),
         spine={"r": (-2, 0, 0)}, head={"r": (-10, 0, 0)}, squash={"s": (0.95, 0.95, 1.08)})
APEX = P(arms(-35, -35, 20, 20, -30, -30), legs(30, 15, 70, 55, 0, 0),
         spine={"r": (6, 0, 0)}, head={"r": (-4, 0, 0)}, squash={"s": (1.05, 1.05, 0.93)})
FALL = P(arms(-80, -80, 10, 10, -15, -15), legs(-10, 10, 15, 25, 25, 15),
         spine={"r": (-4, 0, 0)}, head={"r": (-14, 0, 0)}, squash={"s": (0.96, 0.96, 1.07)},
         **{"eye.L": {"s": 1.12}, "eye.R": {"s": 1.12}})


def jump():
    """2-frame anticipation crouch, then the stretch of take-off easing into the rise."""
    c = Clip("jump", 14)
    c.k(0, BASE, "out").k(2, CROUCH, "linear").k(4, TAKEOFF, "out").k(14, RISE)
    c.overlay(lambda f: {t: {"r": (-25 * min(1, f / 5) + 10 * max(0, f - 5) / 9, 0, 0)} for t in TAIL})
    c.overlay(lambda f: {"ear.L": {"r": (35 if f > 3 else 0, 0, 0)}, "ear.R": {"r": (35 if f > 3 else 0, 0, 0)}})
    return c


def apex():
    """Hang time: a little squash at the top of the arc."""
    c = Clip("apex", 10)
    c.k(0, RISE, "inout").k(5, APEX, "inout").k(10, add_pose(APEX, {"squash": {"s": (0.98, 0.98, 1.03)}}))
    c.overlay(lambda f: {t: {"r": (10 * wave(f, 20, -0.5 * i), 0, 0)} for i, t in enumerate(TAIL)})
    return c


def fall():
    """Falling loop: arms up, stretched, ears and tail streaming upward (follow-through)."""
    n = 16
    c = Clip("fall", n, loop=True).k(0, FALL).k(n, FALL)
    c.overlay(lambda f: P(arms(6 * wave(f, n), 6 * wave(f, n, 1.2)), legs(8 * wave(f, n, 0.5), 8 * wave(f, n, 2.0))))
    c.overlay(lambda f: {t: {"r": (-35 + 6 * wave(f, n / 2, -0.6 * i), 0, 6 * wave(f, n, -0.5 * i))} for i, t in enumerate(TAIL)})
    c.overlay(lambda f: {"ear.L": {"r": (-30 + 8 * wave(f, n / 2), 0, 0)}, "ear.R": {"r": (-30 + 8 * wave(f, n / 2, 0.8), 0, 0)}})
    return c


def land():
    """Impact squash, a small overshoot, settle. Ease out of the hit."""
    hit = P(arms(25, 25, 10, 10, -25, -25), legs(15, 15, 55, 55, -20, -20), hips={"l": (0, 0, -0.1)},
            spine={"r": (14, 0, 0)}, head={"r": (6, 0, 0)}, squash={"s": (1.15, 1.15, 0.76)})
    c = Clip("land", 14)
    c.k(0, hit, "out").k(4, P(BASE, squash={"s": (0.97, 0.97, 1.05)}), "inout").k(9, BASE, "inout").k(14, BASE)
    c.overlay(lambda f: {t: {"r": (20 * math.exp(-f / 4) * math.cos(f * 0.8 - 0.4 * i), 0, 0)} for i, t in enumerate(TAIL)})
    c.overlay(lambda f: {"ear.L": {"r": (25 * math.exp(-f / 4) * math.cos(f * 0.9), 0, 0)}, "ear.R": {"r": (25 * math.exp(-f / 4) * math.cos(f * 0.9), 0, 0)}})
    return c


def land_heavy():
    """Big drop: deep squash, ears and tail slap down, wobble back up (exaggeration, follow-through)."""
    hit = P(arms(-10, -10, 30, 30, -40, -40), legs(30, 30, 65, 65, -30, -30), hips={"l": (0, 0.02, -0.12)},
            spine={"r": (16, 0, 0)}, head={"r": (12, 0, 0)}, squash={"s": (1.2, 1.2, 0.72)},
            **{"eye.L": {"s": (1, 1, 0.35)}, "eye.R": {"s": (1, 1, 0.35)}})
    recover = P(arms(30, 30, 10, 10, -20, -20), legs(15, 15, 40, 40, -10, -10), hips={"l": (0, 0, -0.08)},
                spine={"r": (12, 0, 0)}, head={"r": (-4, 0, 0)}, squash={"s": (1.06, 1.06, 0.9)})
    c = Clip("land_heavy", 30)
    c.k(0, hit, "out").k(3, add_pose(hit, {"squash": {"s": (1.03, 1.03, 0.95)}}), "inout")
    c.k(14, recover, "inout").k(20, P(BASE, squash={"s": (0.95, 0.95, 1.07)}), "inout").k(26, BASE, "inout").k(30, BASE)
    c.overlay(lambda f: {t: {"r": (45 * math.exp(-f / 7) * math.cos(f * 0.55 - 0.5 * i), 0, 0)} for i, t in enumerate(TAIL)})
    c.overlay(lambda f: {"ear.L": {"r": (50 * math.exp(-f / 6) * math.cos(f * 0.7), 0, 0)}, "ear.R": {"r": (50 * math.exp(-f / 6) * math.cos(f * 0.7 + 0.4), 0, 0)}})
    return c


def double_jump():
    """Kicks off Pip, then a tucked forward somersault around the body's centre (arcs)."""
    n = 22
    tuck = P(arms(10, 10, 60, 60, -80, -80), legs(70, 70, 110, 110, 0, 0), spine={"r": (20, 0, 0)},
             head={"r": (20, 0, 0)}, squash={"s": (1.05, 1.05, 0.88)})
    kick = P(arms(-80, -80, 20, 20, 0, 0), legs(-15, 25, 0, 30, 40, 10), squash={"s": (0.9, 0.9, 1.18)})
    c = Clip("double_jump", n)
    c.k(0, kick, "out").k(5, tuck, "inout").k(16, tuck, "inout").k(n, FALL)
    centre, hip = 0.95, 0.45

    def flip(f):
        u = min(1.0, max(0.0, (f - 3) / 13.0))
        u = u * u * (3 - 2 * u)
        th = 360.0 * u
        t = math.radians(th)
        # rotate about the body's centre instead of the hip joint: offset = (I - R)(c - h)
        dy = -(-math.sin(t) * (centre - hip))
        dz = (centre - hip) - math.cos(t) * (centre - hip)
        return {"hips": {"r": (th, 0, 0), "l": (0, dy, dz)}}
    c.overlay(flip)
    c.overlay(lambda f: {t: {"r": (-30 * math.sin(min(1, f / n) * math.pi), 0, 0)} for t in TAIL})
    return c


def glide():
    """Pip carries Bolo by the tuft on his head: Bolo spreads out like a skydiver and steers
    with the tail. The body swings under the grip like a pendulum (arcs, secondary action)."""
    n = 32
    spread = P(arms(-38, -38, 15, 15, -12, -12), legs(-20, -20, 25, 25, 25, 25),
               **{"leg_upper.L": {"r": (20, -18, 0)}, "leg_upper.R": {"r": (20, 18, 0)}},
               spine={"r": (14, 0, 0)}, head={"r": (-26, 0, 0)}, squash={"s": (1.03, 1.03, 0.97)},
               **{"eye.L": {"s": 1.1}, "eye.R": {"s": 1.1}})
    c = Clip("glide", n, loop=True).k(0, spread).k(n, spread)
    c.overlay(lambda f: P(arms(6 * wave(f, n / 2), 6 * wave(f, n / 2, 0.8)),
                          legs(10 * wave(f, n / 2), -10 * wave(f, n / 2)),
                          hips={"r": (3 * wave(f, n, 0.5), 6 * wave(f, n), 0)},
                          head={"r": (0, -3 * wave(f, n, -0.6), 0)}))
    c.overlay(lambda f: {t: {"r": (-55 + 6 * wave(f, n / 2, -0.6 * i), 0, 10 * wave(f, n, -0.5 * i))} for i, t in enumerate(TAIL)})
    c.overlay(lambda f: {"ear.L": {"r": (-25, 10 * wave(f, 6), 0)}, "ear.R": {"r": (-25, -10 * wave(f, 6, 1.0), 0)}})
    return c


# ----------------------------------------------------------------------------- ledges

# Hanging: the palms rest on top of the ledge and the big head peeks over it. Bolo's arms are
# short next to his head, so the face (not the hands) touches the wall: measured in Blender,
# the hands sit at HANG_HANDS and the front of the head at HANG_FRONT_Y.
HANG = P(arms(48, 48, 125, 125, -10, -10), legs(-12, -6, 25, 30, 30, 30),
         spine={"r": (-18, 0, 0)}, head={"r": (-5, 0, 0)}, squash={"s": (0.98, 0.98, 1.03)})
HANG_HANDS = (0.0, -0.18, 1.56)
HANG_FRONT_Y = -0.36


def ledge_hang():
    """Hangs from the ledge: the body swings slowly below the grip, legs dangle and kick."""
    n = 48
    c = Clip("ledge_hang", n, loop=True).k(0, HANG).k(n, HANG)
    c.overlay(lambda f: P(legs(10 * wave(f, n), 10 * wave(f, n, 2.0), 10 * max(0, wave(f, n / 2)), 0),
                          hips={"r": (3 * wave(f, n), 0, 0)}, head={"r": (0, 0, 6 * wave(f, n * 2))}))
    c.overlay(tail_wave(8, 4, n))
    return c


def ledge_climb():
    """Pull-up: the root rises to the ledge and steps onto it; the game moves the body to match."""
    hz = HANG_HANDS[2]
    pull = P(arms(48, 48, 70, 70, -100, -100), legs(30, 10, 70, 40, 0, 0), spine={"r": (18, 0, 0)},
             root={"l": (0, -0.05, hz * 0.55)}, squash={"s": (0.95, 0.95, 1.06)})
    knee = P(arms(30, 30, 30, 30, -40, -40), legs(80, 10, 120, 30, 0, 0), spine={"r": (30, 0, 0)},
             head={"r": (-10, 0, 0)}, root={"l": (0, -0.3, hz * 0.95)})
    stand = P(BASE, root={"l": (0, -0.75, hz)})
    c = Clip("ledge_climb", 24)
    c.k(0, HANG, "in").k(8, pull, "inout").k(15, knee, "inout").k(20, add_pose(stand, {"squash": {"s": (1.05, 1.05, 0.93)}}), "inout").k(24, stand)
    c.overlay(lambda f: {t: {"r": (15 * wave(f, 18, -0.6 * i), 0, 0)} for i, t in enumerate(TAIL)})
    return c


# ----------------------------------------------------------------------------- personality

def idle_fidget():
    """Notices Pip, winds up, swipes, misses, scratches his head. Staging, anticipation, appeal."""
    notice = P(BASE, head={"r": (-22, 0, 28)}, spine={"r": (-4, 0, 10)}, **{"eye.L": {"s": 1.18}, "eye.R": {"s": 1.18}})
    wind = P(arms(30, 38, -35, 4), legs(20, 20, 40, 40, -15, -15), head={"r": (-25, 0, 30)}, spine={"r": (12, 0, 12)},
             hips={"l": (0, 0, -0.08)}, squash={"s": (1.08, 1.08, 0.86)})
    swipe = P(arms(-150, 30, 30, 4, -10, -15), legs(-5, -5, 0, 0, 30, 30), head={"r": (-35, 0, 24)}, spine={"r": (-10, 8, 18)},
              root={"l": (0, 0, 0.16)}, squash={"s": (0.92, 0.92, 1.15)}, **{"eye.L": {"s": 1.2}, "eye.R": {"s": 1.2}})
    miss = P(arms(-120, 34, 20, 4, -30, -15), head={"r": (-30, 0, 40)}, spine={"r": (-6, 6, 20)}, root={"l": (0, 0, 0.18)})
    down = P(BASE, legs(15, 15, 40, 40, -15, -15), hips={"l": (0, 0, -0.07)}, squash={"s": (1.1, 1.1, 0.85)})
    sulk = P(BASE, head={"r": (14, 0, -8)}, spine={"r": (8, 0, 0)}, **{"ear.L": {"r": (0, 30, 0)}, "ear.R": {"r": (0, -30, 0)}})
    scratch = P(arms(38, -150, 4, 30, -15, -110), head={"r": (8, 0, -12)}, spine={"r": (4, -6, 0)},
                **{"ear.L": {"r": (0, 20, 0)}, "ear.R": {"r": (0, -20, 0)}})
    c = Clip("idle_fidget", 96)
    c.k(0, BASE, "inout").k(10, notice, "inout").k(22, notice, "in").k(28, wind, "linear").k(31, swipe, "out")
    c.k(38, miss, "in").k(43, down, "out").k(52, sulk, "inout").k(60, scratch, "inout")
    c.k(84, scratch, "inout").k(96, BASE)

    def scratching(f):
        if 60 <= f <= 84:
            w = math.sin((f - 60) * 1.4)
            return {"hand.R": {"r": (25 * w, 0, 0)}, "arm_lower.R": {"r": (8 * w, 0, 0)}}
        return {}
    c.overlay(scratching).overlay(tail_wave(8, 3, 32)).overlay(blink_at([12, 70]))
    return c


ALL = [idle, idle_fidget, walk, run, skid, jump, apex, fall, land, land_heavy, double_jump, glide, ledge_hang, ledge_climb]

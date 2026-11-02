"""Ren v4 animation authoring (keys + procedural locomotion).

Conventions (torso frame): nh / fh = hand targets relative to the near / far shoulder, x forward, y DOWN.
sw = weapon axis angle (0 up, 90 forward, 180 down). ff / bf = near / far ankle (ground contact) in px from the
feet origin. lean = whole spine, bend = extra chest lean, twist = chest rotation toward the target (-1..1).
hy < 0 lifts the hip, hx > 0 moves the body forward. ease tags sit on the key that STARTS a segment.

Principles applied (see the report): anticipation keys coil AGAINST the strike (lean back, blade away, weight on the
rear foot); strike segments use 'in' then 'snap' (slow in, fast out, tiny overshoot); the contact key is the
staging pose (clear silhouette: planted feet, lean, blade on a clean line) and is held by the contract;
follow-through keys keep the torso moving after the arm stops, the weapon lags the arm and the scarf/hair
(spring chains) lag everything; hips and shoulders (twist) lead the arm; the head tracks the target; the off hand
counter-balances; footwork alternates step-in / pivot / cross-step / back-step; locomotion plants the stance foot
and moves it back at constant speed.
"""
import math

from chars import ren as R

P = R.P
TAU = math.tau

# ------------------------------------------------------------------ carries per weapon

CARRY = {
    "sword": {
        "idle": dict(nh=(4.5, 12.5), sw=150, grip="one", fh=(1.0, 13.0)),
        "ready": dict(nh=(11, 3.5), sw=48, grip="one", fh=(5.5, 8.5)),
        "walk": dict(nh=(5, 12), sw=146, grip="one", fh=(1.0, 13.0)),
        "run": dict(nh=(1.5, 9.5), sw=212, grip="one", fh=(3, 6)),
        "dash": dict(nh=(-3, 6.5), sw=252, grip="one", fh=(-5, 7)),
        "air": dict(nh=(8, -2), sw=64, grip="one", fh=(-3, 3)),
        "hurt": dict(nh=(-2, 7), sw=205, grip="one", fh=(-4, 5)),
    },
    "spear": {
        "idle": dict(nh=(7.5, 11.5), sw=6, grip="one", fh=(1.0, 13.0)),
        "ready": dict(nh=(4, 9.5), sw=60, grip="two", span=11.5),
        "walk": dict(nh=(7.5, 11.5), sw=6, grip="one", fh=(1.0, 13.0)),
        "run": dict(nh=(3, 8.5), sw=32, grip="two", span=11),
        "dash": dict(nh=(0, 6), sw=78, grip="two", span=11),
        "air": dict(nh=(6, 0), sw=40, grip="two", span=11),
        "hurt": dict(nh=(-1, 8), sw=205, grip="one", fh=(-4, 5)),
    },
    "axe": {
        "idle": dict(nh=(4.5, 4.5), sw=-42, grip="one", fh=(1.0, 13.0)),
        "ready": dict(nh=(6, 9), sw=36, grip="two", span=9),
        "walk": dict(nh=(4.5, 4.5), sw=-42, grip="one", fh=(1.0, 13.0)),
        "run": dict(nh=(3.5, 5.5), sw=-36, grip="one", fh=(3, 6)),
        "dash": dict(nh=(-2, 6), sw=235, grip="one", fh=(-5, 7)),
        "air": dict(nh=(6, -3), sw=20, grip="two", span=9),
        "hurt": dict(nh=(-1, 7), sw=215, grip="one", fh=(-4, 5)),
    },
}


def cp(w, mode, **over):
    d = dict(CARRY[w][mode])
    d.update(over)
    d["weapon"] = w
    return d


def A(w, mode=None, **kw):
    """Pose for weapon w starting from a carry mode, overridden by kw."""
    base = dict(CARRY[w][mode]) if mode else {}
    base.update(kw)
    base["weapon"] = w
    return P(**base)


# ------------------------------------------------------------------ locomotion (procedural)

def _sm(u):
    return u * u * (3 - 2 * u)


def foot_cycle(tau, S, duty, lift):
    """(x, y, pitch) of one foot for phase tau in [0,1): constant-speed stance, lifted swing."""
    tau %= 1.0
    if tau < duty:
        u = tau / duty
        x = S * (1 - 2 * u)
        if u < 0.16:
            pitch = 15 * (1 - u / 0.16)                 # heel strike: toe up
        elif u > 0.68:
            pitch = -36 * ((u - 0.68) / 0.32)           # toe-off
        else:
            pitch = 0.0
        y = -2.0 * max(0.0, (u - 0.68) / 0.32) ** 1.4
        return x, y, pitch
    u = (tau - duty) / (1 - duty)
    ue = _sm(u)
    x = -S + 2 * S * ue
    y = -2.0 * (1 - u) - lift * math.sin(math.pi * u ** 0.8)
    pitch = -36 * (1 - ue) + 15 * ue * ue
    return x, y, pitch


def loco_pose(w, run, phi):
    S = 13.5 if run else 9.5
    duty = 0.40 if run else 0.62
    lift = 8.0 if run else 3.6
    xn, yn, an = foot_cycle(phi, S, duty, lift)
    xf, yf, af = foot_cycle(phi + 0.5, S, duty, lift)
    c = math.cos(TAU * phi)
    s = math.sin(TAU * phi)
    if run:
        hy = 1.6 + 2.4 * math.cos(2 * TAU * (phi - 0.2))
        lean = 13 + 1.2 * math.cos(2 * TAU * (phi - 0.2))
        mode = "run"
    else:
        hy = 0.2 + 1.25 * math.cos(2 * TAU * phi)
        lean = 2.5
        mode = "walk"
    base = dict(CARRY[w][mode])
    nh, fh = base["nh"], base.get("fh", (1, 13))
    if run:
        fh = (3 + 7 * c, 6 - 2.5 * c)
        nh = (nh[0] - 1.6 * c, nh[1] - 0.9 * math.cos(2 * TAU * phi))
    else:
        fh = (1.5 + 6.0 * c, 13.0 - 1.4 * abs(c))
        nh = (nh[0] - 1.0 * c, nh[1] + 0.5 * math.cos(2 * TAU * phi))
    kw = dict(base)
    kw.update(nh=nh, fh=fh)
    kw["weapon"] = w
    return P(hx=0.0, hy=hy, lean=lean, head=-0.5 * lean + 1.5, twist=0.32 * s, ff=(xn, yn), bf=(xf, yf), fa=an, ba=af,
             wind=-0.30 if run else -0.06, expr="focus" if run else "neutral", **kw)


def _ref_speed(S, duty, ticks):
    return round((2 * S) / (duty * ticks / 60.0) / 32.0, 3)


REF = {"walk": _ref_speed(9.5, 0.62, 48), "run": _ref_speed(13.5, 0.40, 40)}

PROCEDURAL = {}
REF_SPEED = {}
for _w in R.WEAPONS:
    PROCEDURAL[f"{_w}.walk"] = (lambda w: (lambda u: loco_pose(w, False, u)))(_w)
    PROCEDURAL[f"{_w}.run"] = (lambda w: (lambda u: loco_pose(w, True, u)))(_w)
    REF_SPEED[f"{_w}.walk"] = REF["walk"]
    REF_SPEED[f"{_w}.run"] = REF["run"]


# ------------------------------------------------------------------ basic keys per weapon

def idle_keys(w):
    st = dict(ff=(3.5, 0), bf=(-4.0, 0))
    k = []
    for i, (hy, bend, hd, wob, ex) in enumerate([
            (0.4, 0.5, 0.6, -0.4, "neutral"), (-0.4, -0.9, -0.9, 0.8, "neutral"), (-1.1, -1.8, -1.5, 1.4, "neutral"),
            (-0.6, -0.9, -0.8, 0.8, "neutral"), (0.3, 0.5, 0.6, -0.3, "blink"), (0.6, 0.9, 1.0, -0.7, "neutral")]):
        c = dict(CARRY[w]["idle"])
        nh = c["nh"]
        c["nh"] = (nh[0], nh[1] + wob * 0.5)
        k.append(P(hy=hy, bend=bend, head=hd, lean=1.0 + 0.5 * i / 5, hx=0.35 * math.sin(i / 6 * TAU), expr=ex,
                   wind=0.02, weapon=w, **c, **st))
    return k


def ready_keys(w):
    k = []
    for i in range(6):
        ph = i / 6 * TAU
        bob = 0.5 + 0.5 * math.cos(ph)
        c = dict(CARRY[w]["ready"])
        c["nh"] = (c["nh"][0] + 0.5 * math.sin(ph), c["nh"][1] + 0.5 * (1 - bob))
        k.append(P(hy=1.6 + 1.1 * bob, lean=5 + 1.5 * bob, bend=-1.0, twist=0.35, head=-2.0, hx=0.8 * math.sin(ph),
                   ff=(5.5, 0), bf=(-6.5, 0), fa=0, ba=-6 * (1 - bob), wind=0.04, expr="focus", weapon=w, **c))
    return k


def dash_keys(w):
    c = CARRY[w]["dash"]
    return [
        A(w, "dash", hy=3.8, lean=10, bend=3, twist=-0.5, hx=-2.0, ff=(4, 0), bf=(-10, 0), ba=-30, expr="focus", ease="in", wind=-0.1),
        A(w, "dash", hy=2.4, lean=26, bend=4, twist=0.3, hx=2.0, ff=(9, -1.5), bf=(-12, -1.0), fa=-12, ba=-35, expr="angry", ease="snap", wind=-0.4),
        A(w, "dash", hy=0.0, lean=36, bend=6, twist=0.5, hx=3.0, head=-14, ff=(13, -4.5), bf=(-14, -6.5), fa=-20, ba=-45, expr="angry", wind=-0.6, stop=True),
        A(w, "dash", hy=2.0, lean=22, bend=2, twist=0.2, hx=2.0, head=-6, ff=(9, 0), bf=(-6, -0.5), fa=8, ba=-20, expr="focus", wind=-0.3, ease="out"),
        A(w, "ready", hy=1.4, lean=7, hx=0.5, ff=(5, 0), bf=(-5, 0), expr="neutral", wind=-0.08),
    ]


def jump_keys(w):
    return [
        A(w, "idle", hy=4.8, lean=9, bend=3, head=-4, hx=-1.0, ff=(5, 0), bf=(-5, 0), nh=(2, 9), fh=(-1, 9), expr="focus", ease="in"),
        A(w, "air", hy=-3.0, lean=-3, bend=-3, head=-4, ff=(3, -6.5), bf=(-5, -3.5), fa=-30, ba=-20, expr="happy", ease="out", wind=-0.2),
        A(w, "air", hy=-1.0, lean=5, bend=2, head=2, ff=(5, -7.5), bf=(0, -5.5), fa=-8, ba=-10, expr="focus", wind=-0.15, stop=True),
        A(w, "idle", hy=5.6, lean=11, bend=4, head=-6, hx=-0.5, ff=(6, 0), bf=(-6, 0), fa=5, nh=(3, 10), fh=(0, 10), expr="focus", ease="out"),
    ]


def hurt_keys(w):
    return [
        A(w, "hurt", hy=2.0, lean=-14, bend=-5, head=-10, hx=-3.0, ff=(5, 0), bf=(-7, 0), expr="hurt", ease="snap", wind=0.2),
        A(w, "hurt", hy=3.4, lean=-24, bend=-8, head=-15, hx=-6.0, ff=(4, -1.5), bf=(-9, 0), fa=-10, expr="hurt", wind=0.3),
        A(w, "hurt", hy=1.0, lean=-8, bend=-2, head=-4, hx=-2.0, ff=(4, 0), bf=(-6, 0), expr="neutral", ease="out"),
    ]


def victory_keys(w):
    up = {"sword": (6, -15, 14), "spear": (6, -14, 4), "axe": (5, -15, 8)}[w]
    return [
        A(w, "idle", hy=4.5, lean=6, bend=2, ff=(4, 0), bf=(-5, 0), nh=(3, 9), fh=(0, 10), expr="focus", ease="in"),
        A(w, "air", hy=-5.0, lean=-4, bend=-4, head=-6, ff=(3, -7), bf=(-4, -6), nh=(up[0], up[1] + 3), sw=up[2], fh=(5, -8), expr="happy", grip="one", ease="out"),
        A(w, "air", hy=-4.0, lean=-2, bend=-3, head=-5, ff=(3, -6), bf=(-4, -5), nh=up[:2], sw=up[2], fh=(5, -10), expr="happy", grip="one", stop=True),
        A(w, "idle", hy=5.0, lean=7, bend=2, head=-2, ff=(5, 0), bf=(-6, 0), nh=(5, -2), sw=up[2] + 10, fh=(2, 9), grip="one", expr="happy", ease="out"),
        A(w, "idle", hy=1.0, lean=-2, bend=-4, head=-8, ff=(4, 0), bf=(-6, 0), nh=up[:2], sw=up[2], fh=(1, 9), grip="one", expr="happy", ease="out"),
        A(w, "idle", hy=0.2, lean=-1, bend=-3, head=-6, ff=(4, 0), bf=(-6, 0), nh=up[:2], sw=up[2], fh=(2, 9), grip="one", expr="happy", wind=0.02),
    ]


# ------------------------------------------------------------------ sword combo

def sword_1():
    w = "sword"
    return [
        # 0 anticipation: sink, coil away from the target, blade swings back
        A(w, "idle", hy=2.8, lean=-6, bend=-3, twist=-0.5, head=3, hx=-2.0, ff=(3, 0), bf=(-9, 0), ba=-8, nh=(-1, 1), sw=-5, fh=(7, 6), expr="focus", ease="in", wind=0.1),
        # 1 wind-up peak: blade high behind the head, off hand forward for balance, weight on the rear foot
        A(w, "idle", hy=3.2, lean=-10, bend=-4, twist=-1.0, head=6, hx=-3.5, ff=(2, 0), bf=(-10, 0), ba=-12, nh=(-6, -10), sw=-62, fh=(9, 4), expr="focus", ease="in", wind=0.15),
        # 2 pre-strike: hips already turning, front foot lifts to step in, blade crossing the top of the arc
        A(w, "idle", hy=2.4, lean=3, bend=1, twist=-0.1, head=3, hx=0.0, ff=(7, -2.8), fa=-8, bf=(-9, 0), ba=-22, nh=(6, -13), sw=24, fh=(5, 6), expr="angry", ease="snap"),
        # 3 CONTACT: step landed, rear heel up, torso lunged and twisted, blade on a clean diagonal line
        A(w, "idle", hy=3.4, lean=19, bend=5, twist=0.9, head=-7, hx=5.5, ff=(12, 0), fa=6, bf=(-5, 0), ba=-34, nh=(14, 5), sw=112, fh=(-4, 7), expr="angry", ease="out"),
        # 4 follow-through: torso keeps going, arm stops, blade overshoots low
        A(w, "idle", hy=3.8, lean=15, bend=3, twist=0.6, head=-4, hx=6.5, ff=(12, 0), bf=(-4, 0), ba=-30, nh=(11, 13), sw=150, fh=(-2, 9), expr="focus"),
        # 5 recover: back foot drags up, weight comes back
        A(w, "idle", hy=2.2, lean=9, bend=1, twist=0.3, head=-1, hx=4.5, ff=(10, 0), bf=(0, 0), ba=-12, nh=(9, 12), sw=158, fh=(1, 11), expr="neutral", ease="out"),
        # 6 settle into guard (ready for hit 2)
        A(w, "ready", hy=1.8, lean=6, hx=2.0, ff=(7, 0), bf=(-3, 0), expr="focus"),
    ]


def sword_2():
    w = "sword"
    return [
        # 0 pick up the momentum of hit 1: shoulders already turned, blade drags low and back
        A(w, "ready", hy=3.2, lean=7, bend=2, twist=0.8, head=-3, hx=2.0, ff=(7, 0), bf=(-3, 0), nh=(8, 10), sw=140, fh=(-2, 8), expr="focus", ease="in"),
        # 1 wind-up: low reverse chamber, body sinks and winds, rear arm counter-balances
        A(w, "ready", hy=4.4, lean=3, bend=1, twist=-0.4, head=1, hx=-1.0, ff=(5, 0), bf=(-6, 0), ba=-10, nh=(-3, 13), sw=205, fh=(8, 5), expr="focus", ease="in", wind=0.1),
        # 2 pre-strike: the far foot cross-steps forward past the planted one, hips lead
        A(w, "ready", hy=3.4, lean=4, bend=-1, twist=0.5, head=1, hx=2.0, ff=(0, 0), fa=0, bf=(5, -2.6), ba=-6, nh=(5, 14), sw=168, fh=(3, 6), expr="angry", ease="snap"),
        # 3 CONTACT: rising reverse slash, pivot on the near foot (heel up), cross foot planted forward
        A(w, "ready", hy=3.0, lean=9, bend=-4, twist=1.0, head=3, hx=3.0, ff=(-1, 0), fa=-30, bf=(12, 0), nh=(14, -4), sw=58, fh=(-3, 5), expr="angry", ease="out"),
        # 4 follow-through: blade climbs overhead, chest opens, scarf whips
        A(w, "ready", hy=2.4, lean=3, bend=-7, twist=0.7, head=6, hx=3.0, ff=(0, 0), fa=-20, bf=(11, 0), nh=(9, -12), sw=14, fh=(-5, 3), expr="focus"),
        # 5 recover: arm falls, feet gather
        A(w, "ready", hy=2.0, lean=3, bend=-2, twist=0.3, head=1, hx=2.5, ff=(3, 0), bf=(9, 0), nh=(8, 6), sw=60, fh=(1, 9), expr="neutral", ease="out"),
        A(w, "ready", hy=1.8, lean=5, hx=1.5, ff=(3, 0), bf=(-5, 0), expr="focus"),
    ]


def sword_3():
    w = "sword"
    return [
        # 0 crouch deep: coil, blade trailing low behind
        A(w, "ready", hy=6.2, lean=12, bend=4, twist=-0.8, head=-4, hx=-2.5, ff=(3, 0), bf=(-9, 0), ba=-12, nh=(-4, 12), sw=205, fh=(8, 7), expr="focus", ease="in", spin=0),
        # 1 launch: legs extend, body stretches, blade swings up; the turn starts
        A(w, "ready", hy=-7.0, lean=-4, bend=-4, twist=-1.0, head=-4, hx=0.0, ff=(2, -9), fa=-30, bf=(-4, -7), ba=-30, nh=(0, -6), sw=-20, fh=(5, -5), expr="angry", ease="in", spin=65, wind=0.25),
        # 2 mid-air: full turn (back to camera) with the blade high
        A(w, "ready", hy=-9.0, lean=6, bend=3, twist=0.0, head=0, hx=2.0, ff=(5, -9), fa=-20, bf=(0, -8), ba=-15, nh=(8, -12), sw=14, fh=(-4, 0), expr="angry", ease="snap", spin=215, wind=0.1),
        # 3 CONTACT: landing slam, deep lunge, blade driven diagonally down-forward
        A(w, "ready", hy=4.4, lean=22, bend=6, twist=1.0, head=-8, hx=6.0, ff=(13, 0), fa=8, bf=(-7, 0), ba=-36, nh=(14, 5), sw=132, fh=(-5, 8), expr="angry", ease="out", spin=360),
        # 4 follow-through: sinks into the impact
        A(w, "ready", hy=5.4, lean=18, bend=4, twist=0.7, head=-5, hx=6.0, ff=(13, 0), bf=(-6, 0), ba=-30, nh=(12, 11), sw=160, fh=(-3, 9), expr="focus", spin=360),
        # 5 recover: rise
        A(w, "ready", hy=3.0, lean=10, bend=1, twist=0.4, head=-2, hx=4.0, ff=(10, 0), bf=(-1, 0), ba=-12, nh=(9, 10), sw=150, fh=(0, 10), expr="neutral", ease="out", spin=360),
        A(w, "ready", hy=1.8, lean=6, hx=2.0, ff=(7, 0), bf=(-3, 0), expr="focus", spin=360),
    ]


# ------------------------------------------------------------------ spear combo (two handed)

def _left(keys, start=1, hx=-6.0, fx=-4.0):
    """Spear thrusts reach far: the body works further to the left inside the 80 px cell (root motion)."""
    out = []
    for i, k in enumerate(keys):
        k = dict(k)
        if i >= start:
            k["hx"] = k["hx"] + hx
            k["ff"] = (k["ff"][0] + fx, k["ff"][1])
            k["bf"] = (k["bf"][0] + fx, k["bf"][1])
        out.append(k)
    return out


def spear_1():
    w = "spear"
    two = dict(grip="two", span=11.5)
    return [
        A(w, "ready", hy=2.6, lean=-5, bend=-2, twist=-0.5, head=2, hx=-2.0, ff=(3, 0), bf=(-9, 0), ba=-6, nh=(0, 9), sw=58, ease="in", expr="focus", **two),
        # wind-up: shaft drawn back, rear leg braced for the drive
        A(w, "ready", hy=3.4, lean=-8, bend=-3, twist=-1.0, head=3, hx=-4.0, ff=(2, 0), bf=(-11, 0), ba=-14, nh=(-6, 8), sw=54, ease="in", expr="focus", wind=0.15, **two),
        # pre-strike: rear heel lifts, hips drive forward
        A(w, "ready", hy=2.8, lean=3, bend=1, twist=0.0, head=0, hx=-1.0, ff=(6, 0), bf=(-11, 0), ba=-34, nh=(3, 8), sw=64, ease="snap", expr="angry", **two),
        # CONTACT: full extension, rear leg straight, front knee deep
        A(w, "ready", hy=3.6, lean=17, bend=3, twist=0.85, head=-5, hx=3.0, ff=(12, 0), fa=4, bf=(-12, 0), ba=-42, nh=(13, 6), sw=76, ease="out", expr="angry", **two),
        # recoil: shaft pulled back, torso rebounds
        A(w, "ready", hy=2.6, lean=10, bend=1, twist=0.5, head=-2, hx=1.0, ff=(10, 0), bf=(-10, 0), ba=-30, nh=(7, 8), sw=68, expr="focus", **two),
        A(w, "ready", hy=2.0, lean=7, twist=0.3, hx=1.0, ff=(8, 0), bf=(-6, 0), ba=-12, nh=(5, 9), sw=62, ease="out", expr="neutral", **two),
        A(w, "ready", hy=1.8, lean=6, hx=1.0, ff=(6, 0), bf=(-5, 0), expr="focus"),
    ]


def spear_2():
    w = "spear"
    two = dict(grip="two", span=11.5)
    return [
        A(w, "ready", hy=2.2, lean=7, bend=1, twist=0.5, head=-2, hx=1.0, ff=(6, 0), bf=(-5, 0), nh=(6, 10), sw=66, ease="in", expr="focus", **two),
        # wind-up: low, weapon cocked at the hip, rear foot slides back
        A(w, "ready", hy=4.0, lean=-3, bend=-2, twist=-0.7, head=2, hx=-2.0, ff=(4, 0), bf=(-9, 0), ba=-10, nh=(-2, 11), sw=40, ease="in", expr="focus", wind=0.12, **two),
        # pre-strike: step forward with the rear foot (back-step becomes a step-in), angle up
        A(w, "ready", hy=3.0, lean=5, bend=-1, twist=0.2, head=0, hx=1.5, ff=(5, 0), bf=(2, -2.5), ba=-8, nh=(4, 9), sw=60, ease="snap", expr="angry", **two),
        # CONTACT: high thrust, chest up
        A(w, "ready", hy=3.4, lean=14, bend=-2, twist=0.9, head=-1, hx=3.0, ff=(3, 0), fa=-26, bf=(13, 0), nh=(13, 3), sw=64, ease="out", expr="angry", **two),
        A(w, "ready", hy=2.8, lean=9, bend=-1, twist=0.6, head=1, hx=2.0, ff=(3, 0), fa=-14, bf=(12, 0), nh=(8, 7), sw=62, expr="focus", **two),
        A(w, "ready", hy=2.0, lean=6, twist=0.3, hx=1.5, ff=(4, 0), bf=(9, 0), nh=(5, 9), sw=60, ease="out", expr="neutral", **two),
        A(w, "ready", hy=1.8, lean=6, hx=1.0, ff=(7, 0), bf=(-3, 0), expr="focus"),
    ]


def spear_3():
    w = "spear"
    two = dict(grip="two", span=11.5)
    return [
        A(w, "ready", hy=4.8, lean=10, bend=3, twist=-0.8, head=-3, hx=-2.0, ff=(4, 0), bf=(-9, 0), ba=-10, nh=(-3, 11), sw=205, ease="in", expr="focus", **two),
        # wind-up: shaft swung far back and low (pole across the hips), the whole body wound
        A(w, "ready", hy=5.4, lean=-6, bend=-3, twist=-1.0, head=5, hx=-3.5, ff=(2, 0), bf=(-10, 0), ba=-16, nh=(-5, 12), sw=232, ease="in", expr="focus", wind=0.2, **two),
        # pre-strike: the sweep starts from the legs, shaft crosses the front
        A(w, "ready", hy=4.0, lean=8, bend=2, twist=0.2, head=0, hx=1.0, ff=(8, -1.0), bf=(-7, 0), ba=-24, nh=(7, 12), sw=160, ease="snap", expr="angry", **two),
        # CONTACT: wide horizontal sweep at the end of a deep lunge
        A(w, "ready", hy=4.2, lean=20, bend=5, twist=1.0, head=-8, hx=5.0, ff=(13, 0), fa=6, bf=(-7, 0), ba=-36, nh=(12, 9), sw=98, ease="out", expr="angry", **two),
        A(w, "ready", hy=3.6, lean=14, bend=3, twist=0.8, head=-4, hx=4.0, ff=(12, 0), bf=(-6, 0), ba=-26, nh=(9, 5), sw=60, expr="focus", **two),
        A(w, "ready", hy=2.4, lean=8, twist=0.4, hx=2.5, ff=(9, 0), bf=(-2, 0), ba=-10, nh=(6, 8), sw=58, ease="out", expr="neutral", **two),
        A(w, "ready", hy=1.8, lean=6, hx=1.5, ff=(6, 0), bf=(-4, 0), expr="focus"),
    ]


# ------------------------------------------------------------------ axe combo (heavy)

def axe_1():
    w = "axe"
    two = dict(grip="two", span=9)
    return [
        # slow anticipation: crouch and gather, head of the axe goes back
        A(w, "ready", hy=3.6, lean=-6, bend=-3, twist=-0.5, head=3, hx=-2.0, ff=(4, 0), bf=(-9, 0), nh=(2, 3), sw=10, ease="in", expr="focus", **two),
        # wind-up: axe far behind the shoulder, spine arched, rear leg loaded
        A(w, "ready", hy=4.4, lean=-12, bend=-6, twist=-1.0, head=7, hx=-4.0, ff=(3, 0), bf=(-11, 0), ba=-16, nh=(-5, -9), sw=-48, ease="in", expr="focus", wind=0.2, **two),
        # pre-strike: over the top, chest falls forward
        A(w, "ready", hy=3.6, lean=2, bend=2, twist=0.0, head=3, hx=0.0, ff=(7, -2.0), bf=(-10, 0), ba=-26, nh=(5, -13), sw=18, ease="snap", expr="angry", **two),
        # CONTACT: heavy chop, deep stance
        A(w, "ready", hy=5.0, lean=22, bend=6, twist=1.0, head=-10, hx=5.0, ff=(12, 0), fa=5, bf=(-7, 0), ba=-36, nh=(12, 7), sw=122, ease="out", expr="angry", **two),
        A(w, "ready", hy=5.6, lean=19, bend=5, twist=0.8, head=-7, hx=5.5, ff=(12, 0), bf=(-6, 0), ba=-30, nh=(11, 11), sw=138, expr="focus", **two),
        A(w, "ready", hy=3.4, lean=11, bend=2, twist=0.4, head=-3, hx=3.5, ff=(10, 0), bf=(-2, 0), ba=-12, nh=(8, 10), sw=100, ease="out", expr="neutral", **two),
        A(w, "ready", hy=2.0, lean=7, hx=2.0, ff=(7, 0), bf=(-4, 0), expr="focus"),
    ]


def axe_2():
    w = "axe"
    two = dict(grip="two", span=9)
    return [
        A(w, "ready", hy=3.6, lean=8, bend=2, twist=0.6, head=-3, hx=1.5, ff=(7, 0), bf=(-4, 0), nh=(7, 11), sw=90, ease="in", expr="focus", **two),
        # wind-up: swing axe out low to the rear (horizontal chamber), body winds opposite
        A(w, "ready", hy=4.8, lean=0.0, bend=-2, twist=-1.0, head=3, hx=-2.0, ff=(5, 0), bf=(-9, 0), ba=-12, nh=(-4, 9), sw=250, ease="in", expr="focus", wind=0.2, **two),
        A(w, "ready", hy=4.0, lean=6, bend=1, twist=0.1, head=0, hx=1.0, ff=(9, -2.0), bf=(-8, 0), ba=-24, nh=(5, 11), sw=190, ease="snap", expr="angry", **two),
        # CONTACT: wide horizontal swing
        A(w, "ready", hy=4.6, lean=18, bend=4, twist=1.0, head=-8, hx=4.5, ff=(12, 0), fa=4, bf=(-6, 0), ba=-34, nh=(13, 7), sw=95, ease="out", expr="angry", **two),
        A(w, "ready", hy=4.4, lean=14, bend=3, twist=0.8, head=-4, hx=5.0, ff=(12, 0), bf=(-5, 0), ba=-26, nh=(8, 5), sw=40, expr="focus", **two),
        A(w, "ready", hy=3.0, lean=9, bend=1, twist=0.4, head=-2, hx=3.0, ff=(9, 0), bf=(-2, 0), ba=-10, nh=(6, 7), sw=50, ease="out", expr="neutral", **two),
        A(w, "ready", hy=2.0, lean=7, hx=2.0, ff=(7, 0), bf=(-4, 0), expr="focus"),
    ]


def axe_3():
    w = "axe"
    two = dict(grip="two", span=9)
    return [
        A(w, "ready", hy=5.0, lean=-4, bend=-2, twist=-0.4, head=2, hx=-2.0, ff=(4, 0), bf=(-9, 0), nh=(2, 3), sw=8, ease="in", expr="focus", **two),
        # rise on the toes with the axe fully overhead: whole body stretched (anticipation + stretch)
        A(w, "ready", hy=-2.0, lean=-8, bend=-6, twist=-0.6, head=8, hx=-2.5, ff=(3, 0), fa=-26, bf=(-8, 0), ba=-26, nh=(-1, -16), sw=-18, ease="in", expr="focus", wind=0.25, **two),
        A(w, "ready", hy=-3.0, lean=-5, bend=-6, twist=-0.3, head=6, hx=-1.5, ff=(4, 0), fa=-34, bf=(-7, 0), ba=-34, nh=(2, -17), sw=0, ease="snap", expr="angry", stop=True, **two),
        # CONTACT: the cleave lands, knees buckle, axe buried
        A(w, "ready", hy=6.6, lean=26, bend=8, twist=1.0, head=-12, hx=6.0, ff=(12, 0), fa=6, bf=(-8, 0), ba=-30, nh=(11, 12), sw=165, ease="out", expr="angry", **two),
        A(w, "ready", hy=7.0, lean=22, bend=6, twist=0.9, head=-9, hx=6.0, ff=(12, 0), bf=(-7, 0), ba=-24, nh=(11, 14), sw=170, expr="focus", **two),
        A(w, "ready", hy=4.6, lean=14, bend=3, twist=0.5, head=-4, hx=4.0, ff=(10, 0), bf=(-3, 0), ba=-10, nh=(9, 12), sw=150, ease="out", expr="neutral", **two),
        A(w, "ready", hy=2.2, lean=8, hx=2.0, ff=(7, 0), bf=(-4, 0), expr="focus"),
    ]


# ------------------------------------------------------------------ specials

def _spin_keys(w, sp, reach_sw, two=None, extra=None):
    """Whirlwind / Hurricane: crouch, coil, six contact spins (60-70 deg each), a held finish, dizzy recover, guard."""
    tw = dict(grip="two", span=9) if two else {}
    a = dict(spin=0)
    ks = [
        A(w, "ready", hy=4.8, lean=6, bend=2, twist=-0.6, head=-2, hx=-1.0, ff=(4, 0), bf=(-8, 0), nh=(2, 10), sw=170, ease="in", expr="focus", **tw),
        A(w, "ready", hy=5.6, lean=-3, bend=-3, twist=-1.0, head=3, hx=-2.0, ff=(3, 0), bf=(-9, 0), ba=-10, nh=(-4, 7), sw=reach_sw + 60, ease="in", expr="angry", wind=0.2, spin=0, **tw),
    ]
    angs = [60, 130, 200, 270, 330, 360]
    for i, an in enumerate(angs):
        ks.append(A(w, "ready", hy=3.8 - (1.2 if i % 2 else 0), lean=10, bend=2, twist=0.4, head=0, hx=0.5 * (1 if i % 2 else -1),
                    ff=(6, 0) if i % 2 else (3, 0), bf=(-5, 0) if i % 2 else (-4, 0), nh=(11, 3), sw=reach_sw, expr="angry",
                    spin=an, wind=0.2, stop=(i == 5), **tw))
    ks.append(A(w, "ready", hy=4.0, lean=8, bend=1, twist=0.3, head=2, ff=(6, 0), bf=(-5, 0), nh=(9, 6), sw=reach_sw + 30, expr="neutral", spin=360, ease="out", **tw))
    ks.append(A(w, "ready", hy=2.0, lean=6, bend=0, ff=(6, 0), bf=(-4, 0), expr="focus", spin=360, **tw))
    return ks


def sword_sp1():
    ks = _spin_keys("sword", True, 92)
    # contract: 10 keys
    return ks


def sword_sp2():
    w = "sword"
    return [
        # 0 crouch deep (the jump needs a load), blade trailing
        A(w, "ready", hy=7.0, lean=14, bend=6, twist=-0.5, head=-6, hx=-1.0, ff=(5, 0), bf=(-6, 0), nh=(1, 11), sw=185, ease="in", expr="focus"),
        # 1 leap: stretched, feet leave the floor, blade drawn overhead
        A(w, "ready", hy=-9.0, lean=-3, bend=-5, head=-6, ff=(3, -10), fa=-34, bf=(-4, -8), ba=-26, nh=(3, -14), sw=6, ease="out", expr="angry", wind=0.3),
        # 2 apex (held): tucked, blade high, scarf floating
        A(w, "ready", hy=-15.0, lean=5, bend=-2, head=-4, ff=(4, -14), fa=-10, bf=(-2, -12), ba=-18, nh=(5, -16), sw=-6, fh=(-4, -3), expr="angry", stop=True, wind=0.05),
        # 3 dive: head-first diagonal, blade pointed down-forward, trailing legs
        A(w, "ready", hy=-8.0, lean=52, bend=8, head=-30, hx=2.0, ff=(-6, -13), fa=10, bf=(-11, -16), ba=20, nh=(11, 4), sw=150, fh=(-5, 8), ease="snap", expr="angry", wind=-0.5),
        # 4 CONTACT: impact crouch, blade in the ground
        A(w, "ready", hy=8.0, lean=30, bend=10, twist=0.8, head=-16, hx=5.0, ff=(9, 0), fa=4, bf=(-9, 0), ba=-14, nh=(11, 12), sw=172, fh=(-4, 10), expr="angry", ease="out"),
        # 5 shock recover: rising out of the crater
        A(w, "ready", hy=5.0, lean=14, bend=3, hx=3.0, ff=(7, 0), bf=(-6, 0), nh=(9, 12), sw=160, fh=(0, 10), expr="focus", ease="out"),
        A(w, "ready", hy=1.8, lean=6, hx=1.0, ff=(6, 0), bf=(-4, 0), expr="focus"),
    ]


def spear_sp1():
    w = "spear"
    two = dict(grip="two", span=11.5)
    ks = [A(w, "ready", hy=3.4, lean=-4, twist=-0.6, hx=-2.0, ff=(3, 0), bf=(-10, 0), ba=-8, nh=(-2, 9), sw=56, ease="in", expr="focus", **two)]
    pulses = [
        dict(nh=(13, 5), sw=78, lean=16, ff=(12, 0), bf=(-12, 0), hx=2.5, ba=-38),     # full thrust
        dict(nh=(7, 8), sw=66, lean=10, ff=(10, 0), bf=(-10, 0), hx=1.0, ba=-28),      # recoil
        dict(nh=(13, 2), sw=62, lean=14, ff=(11, 0), bf=(-11, 0), hx=2.5, ba=-36),     # high thrust
        dict(nh=(7, 9), sw=70, lean=10, ff=(10, 0), bf=(-10, 0), hx=1.0, ba=-28),
        dict(nh=(13, 8), sw=86, lean=16, ff=(12, 0), bf=(-12, 0), hx=2.5, ba=-38),     # low thrust
        dict(nh=(8, 8), sw=68, lean=11, ff=(10, 0), bf=(-10, 0), hx=1.0, ba=-30),
    ]
    ks.append(A(w, "ready", hy=3.8, lean=-6, twist=-0.9, hx=-3.0, ff=(2, 0), bf=(-11, 0), ba=-14, nh=(-5, 8), sw=54, ease="in", expr="angry", wind=0.15, **two))
    # the contract has contact frames 1..7: 6 alternating pulses + the final held thrust
    ks = [ks[0]]
    for i, pu in enumerate(pulses):
        ks.append(A(w, "ready", hy=3.4, twist=0.8 if i % 2 == 0 else 0.4, head=-4, expr="angry", wind=0.2, ease=("snap" if i % 2 == 0 else "out"), **two, **pu))
    ks.append(A(w, "ready", hy=3.8, lean=19, twist=1.0, head=-7, hx=4.0, ff=(13, 0), bf=(-13, 0), ba=-42, nh=(14, 6), sw=76, expr="angry", stop=True, **two))
    ks.append(A(w, "ready", hy=2.6, lean=10, twist=0.5, hx=2.0, ff=(10, 0), bf=(-9, 0), ba=-24, nh=(7, 8), sw=66, expr="focus", ease="out", **two))
    ks.append(A(w, "ready", hy=1.8, lean=6, hx=1.0, ff=(6, 0), bf=(-4, 0), expr="neutral", **two))
    return ks


def spear_sp2():
    w = "spear"
    return [
        # 0 crouch, spear lifted to the throwing line (one hand)
        A(w, "idle", hy=4.4, lean=-4, bend=-2, twist=-0.6, hx=-2.0, ff=(4, 0), bf=(-9, 0), ba=-10, nh=(0, 3), sw=58, fh=(8, 3), ease="in", expr="focus"),
        # 1 wind-up: arm cocked behind the head, off hand points at the target
        A(w, "idle", hy=3.8, lean=-12, bend=-6, twist=-1.0, head=5, hx=-4.0, ff=(3, 0), bf=(-11, 0), ba=-16, nh=(-5, -6), sw=62, fh=(11, 1), ease="in", expr="angry", wind=0.2),
        # 2 pre-release: hip and shoulder drive, arm arrives
        A(w, "idle", hy=3.4, lean=4, bend=2, twist=0.3, head=-1, hx=0.0, ff=(8, -1.0), bf=(-10, 0), ba=-30, nh=(8, -9), sw=76, fh=(2, 4), ease="snap", expr="angry"),
        # 3 CONTACT: spear released (gone), arm fully extended, rear heel off, body behind the throw
        A(w, "idle", hy=3.6, lean=18, bend=5, twist=1.0, head=-5, hx=4.0, ff=(12, 0), fa=4, bf=(-9, 0), ba=-40, nh=(14, -4), sw=80, fh=(-4, 6), ease="out", expr="angry", carry="none"),
        A(w, "idle", hy=3.8, lean=15, bend=3, twist=0.7, head=-3, hx=4.5, ff=(12, 0), bf=(-7, 0), ba=-28, nh=(12, 2), sw=80, fh=(-2, 8), expr="focus", carry="none"),
        # 5 a fresh spear is in hand again as the stance recovers
        A(w, "ready", hy=2.0, lean=8, hx=2.5, ff=(8, 0), bf=(-4, 0), ba=-10, expr="neutral"),
    ]


def axe_sp1():
    w = "axe"
    two = dict(grip="two", span=9)
    return [
        A(w, "ready", hy=5.0, lean=-6, bend=-3, twist=-0.6, hx=-2.0, ff=(4, 0), bf=(-9, 0), nh=(2, 3), sw=10, ease="in", expr="focus", **two),
        # huge wind-up with the whole body: legs spread, spine arched, axe far over the head
        A(w, "ready", hy=-3.0, lean=-14, bend=-8, twist=-1.0, head=9, hx=-4.0, ff=(4, 0), fa=-30, bf=(-10, 0), ba=-30, nh=(-3, -17), sw=-26, ease="in", expr="angry", wind=0.3, **two),
        A(w, "ready", hy=-3.6, lean=-8, bend=-7, twist=-0.5, head=7, hx=-2.0, ff=(5, 0), fa=-34, bf=(-9, 0), ba=-34, nh=(1, -17), sw=-4, ease="snap", expr="angry", stop=True, **two),
        # CONTACT: the axe drives into the ground in front, body folded over it
        A(w, "ready", hy=8.0, lean=30, bend=10, twist=1.0, head=-14, hx=6.0, ff=(12, 0), fa=6, bf=(-9, 0), ba=-26, nh=(10, 15), sw=176, ease="out", expr="angry", **two),
        A(w, "ready", hy=6.0, lean=22, bend=6, twist=0.6, head=-6, hx=5.0, ff=(11, 0), bf=(-7, 0), ba=-16, nh=(10, 14), sw=172, expr="focus", **two),
        A(w, "ready", hy=2.4, lean=9, hx=2.0, ff=(7, 0), bf=(-4, 0), nh=(7, 9), sw=120, expr="neutral", ease="out", **two),
    ]


def axe_sp2():
    return _spin_keys("axe", True, 98, two=False)


# ------------------------------------------------------------------ casting (weapon sheathed) + death

def _cast_base(**kw):
    return P(weapon="sword", carry="back", grip="one", **kw)


def cast_1():
    return [
        _cast_base(hy=2.4, lean=-4, bend=-2, twist=-0.4, hx=-1.0, ff=(4, 0), bf=(-7, 0), nh=(6, 8), fh=(6, 8), expr="focus", ease="in", sw=170),
        _cast_base(hy=3.2, lean=-8, bend=-4, twist=-0.8, head=4, hx=-3.0, ff=(3, 0), bf=(-9, 0), ba=-8, nh=(-2, 0), fh=(8, 1), expr="focus", ease="in", wind=0.15, sw=170),
        _cast_base(hy=2.8, lean=3, bend=1, twist=0.2, hx=0.0, ff=(6, 0), bf=(-9, 0), ba=-14, nh=(9, -1), fh=(3, 6), expr="angry", ease="snap", sw=170),
        _cast_base(hy=3.2, lean=11, bend=3, twist=0.9, head=-3, hx=3.0, ff=(10, 0), fa=4, bf=(-8, 0), ba=-30, nh=(14, -1), fh=(-4, 7), expr="angry", ease="out", sw=170),
        _cast_base(hy=3.0, lean=9, bend=2, twist=0.7, hx=3.0, ff=(10, 0), bf=(-7, 0), ba=-24, nh=(13, 0), fh=(-3, 8), expr="focus", sw=170),
        _cast_base(hy=1.8, lean=5, hx=1.5, ff=(7, 0), bf=(-4, 0), nh=(6, 11), fh=(1, 12), expr="neutral", ease="out", sw=170),
    ]


def cast_ring():
    return [
        _cast_base(hy=3.0, lean=4, bend=2, ff=(4, 0), bf=(-6, 0), nh=(6, 7), fh=(5, 7), expr="focus", ease="in", sw=170),
        # hands rise together overhead while the body stretches
        _cast_base(hy=-1.2, lean=-5, bend=-6, head=-6, hx=-1.0, ff=(3, 0), fa=-20, bf=(-5, 0), ba=-20, nh=(3, -15), fh=(2, -15), expr="focus", ease="in", wind=0.2, sw=170),
        _cast_base(hy=2.0, lean=8, bend=4, head=2, hx=0.5, ff=(5, 0), bf=(-6, 0), nh=(6, -4), fh=(4, -3), expr="angry", ease="snap", sw=170),
        # CONTACT: crouch and slam both hands to the floor, arms wide
        _cast_base(hy=8.0, lean=16, bend=9, head=-12, hx=1.0, ff=(7, 0), bf=(-8, 0), nh=(9, 15), fh=(-4, 15), expr="angry", ease="out", sw=170),
        _cast_base(hy=7.0, lean=13, bend=7, head=-9, hx=1.0, ff=(7, 0), bf=(-8, 0), nh=(10, 14), fh=(-5, 14), expr="focus", sw=170),
        _cast_base(hy=2.4, lean=6, hx=0.5, ff=(5, 0), bf=(-5, 0), nh=(5, 11), fh=(1, 12), expr="neutral", ease="out", sw=170),
    ]


def cast_sky():
    return [
        _cast_base(hy=2.6, lean=-2, ff=(4, 0), bf=(-6, 0), nh=(6, 8), fh=(3, 9), expr="focus", ease="in", sw=170),
        _cast_base(hy=3.4, lean=-6, bend=-4, head=-4, hx=-1.5, ff=(3, 0), bf=(-8, 0), ba=-8, nh=(0, 3), fh=(7, 7), expr="focus", ease="in", wind=0.15, sw=170),
        _cast_base(hy=0.6, lean=-3, bend=-8, head=-10, hx=-0.5, ff=(4, 0), fa=-14, bf=(-6, 0), ba=-14, nh=(5, -10), fh=(-1, 9), expr="focus", ease="snap", sw=170),
        # CONTACT: arm thrust straight up at the sky, other fist on the hip, head tipped back
        _cast_base(hy=0.0, lean=-5, bend=-10, head=-16, hx=0.0, ff=(4, 0), fa=-26, bf=(-6, 0), ba=-26, nh=(7, -17), fh=(-1, 9), expr="angry", ease="out", sw=170),
        _cast_base(hy=0.4, lean=-4, bend=-9, head=-14, ff=(4, 0), fa=-20, bf=(-6, 0), ba=-20, nh=(7, -16), fh=(-1, 9), expr="focus", sw=170),
        _cast_base(hy=2.0, lean=3, hx=0.5, ff=(5, 0), bf=(-5, 0), nh=(6, 9), fh=(1, 12), expr="neutral", ease="out", sw=170),
    ]


def death():
    b = dict(weapon="sword", carry="back", grip="one", sw=170)
    return [
        P(hy=2.0, lean=-16, bend=-6, head=-10, hx=-3.0, ff=(5, 0), bf=(-8, 0), nh=(-4, 6), fh=(-6, 4), expr="hurt", ease="snap", wind=0.3, **b),
        P(hy=4.0, lean=-30, bend=-8, head=-14, hx=-7.0, ff=(5, -2.0), fa=-12, bf=(-7, 0), nh=(-6, 3), fh=(-8, 2), expr="hurt", ease="in", wind=0.3, **b),
        # falling: legs buckle, body rotating back
        P(hy=9.0, lean=-52, bend=-6, head=-8, hx=-8.0, ff=(7, -3.0), fa=-14, bf=(1, -1.0), nh=(2, -6), fh=(-3, -5), expr="dead", ease="in", autohip=False, wind=0.2, **b),
        # hits the ground: arms flop up onto the chest, legs slide out straight
        P(hy=17.0, lean=-80, bend=-4, head=-4, hx=1.0, ff=(24, -3.0), fa=-20, bf=(21, -1.5), nh=(6, 0), fh=(4, 2), expr="dead", ease="snap", autohip=False, kpole=(0.2, -1.0), **b),
        P(hy=19.5, lean=-90, bend=0, head=0, hx=3.0, ff=(26, -2.5), fa=-14, bf=(23, -2.0), nh=(5, 2), fh=(3, 3), expr="dead", ease="out", autohip=False, kpole=(0.2, -1.0), **b),
        P(hy=19.5, lean=-90, bend=0, head=0, hx=3.0, ff=(26, -2.5), fa=-14, bf=(23, -2.0), nh=(5, 2), fh=(3, 3), expr="dead", autohip=False, kpole=(0.2, -1.0), **b),
    ]


# ------------------------------------------------------------------ registry

def poses(name, n):
    if "." in name and name.split(".")[0] in R.WEAPONS:
        w, tail = name.split(".", 1)
    else:
        w, tail = None, name
    table = {
        "idle": lambda: idle_keys(w), "ready": lambda: ready_keys(w), "dash": lambda: dash_keys(w),
        "jump": lambda: jump_keys(w), "hurt": lambda: hurt_keys(w), "victory": lambda: victory_keys(w),
    }
    if tail in ("walk", "run"):
        proc = PROCEDURAL[name]
        # keys at the logical frame starts; the procedural curve takes over in build.py
        return [proc(i / n) for i in range(n)]
    if tail in table and w:
        keys = table[tail]()
    else:
        keys = {
            "sword.1": sword_1, "sword.2": sword_2, "sword.3": sword_3,
            "spear.1": lambda: _left(spear_1()), "spear.2": lambda: _left(spear_2()), "spear.3": lambda: _left(spear_3(), hx=-5.0, fx=-3.0),
            "axe.1": lambda: _left(axe_1(), start=2, hx=-5.0, fx=-3.0), "axe.2": lambda: _left(axe_2(), start=2, hx=-5.0, fx=-3.0), "axe.3": lambda: _left(axe_3(), start=3, hx=-5.0, fx=-3.0),
            "sword.sp1": sword_sp1, "sword.sp2": sword_sp2, "spear.sp1": lambda: _left(spear_sp1(), hx=-5.0, fx=-3.0), "spear.sp2": spear_sp2,
            "axe.sp1": axe_sp1, "axe.sp2": axe_sp2,
            "cast": cast_1, "cast.ring": cast_ring, "cast.sky": cast_sky, "death": death,
        }[name]()
    if len(keys) != n:
        raise ValueError(f"{name}: authored {len(keys)} keys, contract has {n} logical frames")
    return keys

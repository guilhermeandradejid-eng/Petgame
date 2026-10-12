"""Pip's animations. Wings flap with the tip lagging the arm (overlap); the body bobs against
the stroke (action/reaction) and squashes on every downstroke."""
import math

from anim import Clip, wave, add_pose


def flap(f, period, amp=45.0, lag=0.9, base=0.0):
    w1 = base + amp * wave(f, period)
    w2 = base * 0.5 + amp * 0.8 * wave(f, period, -lag)
    return {
        "wing1.L": {"r": (0, w1, 0)}, "wing1.R": {"r": (0, -w1, 0)},
        "wing2.L": {"r": (0, w2, 0)}, "wing2.R": {"r": (0, -w2, 0)},
    }


def body_bob(f, period, amp=0.03, squash=0.06):
    w = wave(f, period, math.pi)  # body rises while the wings push down
    return {"root": {"l": (0, 0, amp * w)},
            "body": {"s": (1 + squash * 0.5 * w, 1, 1 - squash * w)}}


def ears_follow(f, period, amp=10.0):
    w = amp * wave(f, period, -1.4)
    return {"ear.L": {"r": (0, w, 0)}, "ear.R": {"r": (0, -w, 0)}}


def blink(f, at, n=4):
    if at <= f <= at + n:
        k = 1 - 0.9 * math.sin(math.pi * (f - at) / n)
        return {"eye.L": {"s": (1, 1, k)}, "eye.R": {"s": (1, 1, k)}}
    return {}


def loop(name, n, period, amp, extra=None):
    c = Clip(name, n, loop=True).k(0, {}).k(n, {})
    c.overlay(lambda f: flap(f, period, amp)).overlay(lambda f: body_bob(f, period)).overlay(lambda f: ears_follow(f, period))
    if extra:
        c.overlay(extra)
    return c


def fly():
    return loop("fly", 16, 8, 50, lambda f: add_pose({"body": {"r": (12, 0, 0)}}, blink(f, 10)))


def hover():
    return loop("hover", 32, 16, 32, lambda f: add_pose({"body": {"r": (0, 4 * wave(f, 32), 0)}}, blink(f, 22)))


def carry():
    """Lifting Bolo: fast hard strokes, feet clenched below, eyes squeezed with effort."""
    def strain(f):
        return {"body": {"r": (-8, 0, 0), "s": (0.95, 0.95, 1.1)},
                "foot.L": {"r": (-20, 0, 0)}, "foot.R": {"r": (-20, 0, 0)},
                "eye.L": {"s": (1, 1, 0.45)}, "eye.R": {"s": (1, 1, 0.45)}}
    return loop("carry", 12, 6, 62, strain)


def boost():
    """Springboard for the double jump: flattens under Bolo's foot, then pops away spinning."""
    flat = {"body": {"s": (1.45, 1.45, 0.5)}, "wing1.L": {"r": (0, -5, 0)}, "wing1.R": {"r": (0, 5, 0)},
            "eye.L": {"s": (1, 1, 0.2)}, "eye.R": {"s": (1, 1, 0.2)}}
    pop = {"body": {"s": (0.8, 0.8, 1.35)}, "wing1.L": {"r": (0, 70, 0)}, "wing1.R": {"r": (0, -70, 0)},
           "wing2.L": {"r": (0, 60, 0)}, "wing2.R": {"r": (0, -60, 0)}}
    c = Clip("boost", 18)
    c.k(0, {}, "out").k(2, flat, "inout").k(5, flat, "out").k(8, pop, "inout").k(18, {})
    c.overlay(lambda f: {"root": {"r": (0, 0, 360 * min(1, max(0, (f - 6) / 10)) ** 0.7)}})
    return c


def tease():
    """Dodges Bolo's swipe and giggles: quick side wiggle, wings flicking."""
    n = 24
    c = Clip("tease", n, loop=True).k(0, {}).k(n, {})
    c.overlay(lambda f: flap(f, 6, 40)).overlay(lambda f: body_bob(f, 6))
    c.overlay(lambda f: {"body": {"r": (0, 18 * wave(f, 12), 10 * wave(f, 24))},
                         "ear.L": {"r": (0, 15 * wave(f, 12, -1), 0)}, "ear.R": {"r": (0, -15 * wave(f, 12, -1), 0)}})
    return c


ALL = [fly, hover, carry, boost, tease]

"""Sound effects for Céu Arcano.

Every effect is a function ``fn(rng) -> mono float array`` registered in
``SFX``.  ``render(name)`` adds the shared finishing chain (DC cut, silence
trim, click-free fades, peak normalisation to -1 dBFS).
"""
from __future__ import annotations

import math

import numpy as np

import synth as S
from synth import SR, ns, tvec

SFX: dict = {}
# Suggested playback trims (dB) for the game mixer.  All files are peak
# normalised to -1 dBFS per the asset spec, so very frequent sounds should be
# played quieter than the big hits.
VOLUME_HINT_DB: dict = {}


def sfx(name, volume_db=0.0):
    def deco(fn):
        SFX[name] = fn
        VOLUME_HINT_DB[name] = volume_db
        return fn
    return deco


# --------------------------------------------------------------------------
# building blocks
# --------------------------------------------------------------------------

def buf(dur):
    return np.zeros(ns(dur))


def add(dst, src, at=0.0, gain=1.0):
    S.mix_into(dst, src, ns(at), gain)
    return dst


def thump(dur, f0, f1, tau_f, tau_a, attack=0.0008):
    n = ns(dur)
    t = tvec(n)
    f = f1 + (f0 - f1) * np.exp(-t / tau_f)
    return S.sine(f, n) * S.expdec(n, tau_a, attack)


def burst(dur, rng, tau, lp=None, hp=None, bp=None, q=1.0, attack=0.0004):
    n = ns(dur)
    x = S.noise(n, rng) * 2.0
    if bp:
        x = S.bandpass(x, bp, q)
    if lp:
        x = S.lowpass(x, lp, 2)
    if hp:
        x = S.highpass(x, hp, 2)
    return x * S.expdec(n, tau, attack)


def nburst(dur, rng, tau, **kw):
    """burst() normalised to unit peak, so gains are comparable across bands."""
    return norm(burst(dur, rng, tau, **kw))


def click(rng, hp=3000.0, dur=0.004, amp=1.0):
    n = ns(dur)
    x = S.noise(n, rng) * 2.0
    x = S.highpass(x, hp, 2)
    return x * np.exp(-tvec(n) / (dur / 4)) * amp


def whoosh(dur, rng, f_pts, amp_pts, q=1.2, amp_kind="lin", air=0.0):
    """Band-pass noise whoosh: centre-frequency and amplitude breakpoints [(t, v)]."""
    n = ns(dur)
    ft = np.array([p[0] for p in f_pts])
    fv = np.log(np.array([p[1] for p in f_pts]))
    at = np.array([p[0] for p in amp_pts])
    av = np.array([p[1] for p in amp_pts])

    def mag(t, f):
        fc = np.exp(np.interp(t, ft, fv))
        a = np.interp(t, at, av)
        m = S.H_bp(f, fc, q)
        if air:
            m = m + air * S.H_hp(f, fc * 2.5, 1)
        tilt = (np.maximum(f, 30.0) / fc) ** -0.6
        return a * m * tilt

    return S.shaped_noise(n, rng, mag) * 2.0


def ping(freq, dur, tau, partials=((1.0, 1.0),), attack=0.0015, vib=0.0, rng=None):
    n = ns(dur)
    t = tvec(n)
    f = freq * (1.0 + vib * np.sin(2 * math.pi * 6.0 * t))
    out = np.zeros(n)
    for k, (r, a) in enumerate(partials):
        if freq * r > SR * 0.45:
            continue
        out += a * S.sine(f * r, n, 0.0 if rng is None else rng.random()) * np.exp(-t * (1 + 0.6 * k) / tau)
    return out * np.clip(t / attack, 0, 1)


def fm_bell(freq, dur, tau, ratio=3.5, index=2.0, itau=None, attack=0.001):
    n = ns(dur)
    t = tvec(n)
    idx = index * np.exp(-t / (itau or tau * 0.4))
    return S.fm(freq, n, ratio, idx) * S.expdec(n, tau, attack)


def bell(freq, dur, base_tau=1.0, partials=None, rng=None, attack=0.001):
    partials = partials or [(0.5, 0.2, 1.4), (1.0, 1.0, 1.0), (2.0, 0.45, 0.55),
                            (2.76, 0.22, 0.32), (4.07, 0.1, 0.18), (5.4, 0.06, 0.1)]
    n = ns(dur)
    t = tvec(n)
    out = np.zeros(n)
    for r, a, d in partials:
        if freq * r > SR * 0.45:
            continue
        ph = 0.0 if rng is None else rng.random()
        out += a * S.sine(freq * r, n, ph) * np.exp(-t / (d * base_tau))
    return out * np.clip(t / attack, 0, 1)


def chime(freq, dur, tau=0.8, rng=None):
    """Tubular wind-chime partials."""
    parts = [(1.0, 1.0, 1.0), (2.76, 0.5, 0.45), (5.40, 0.25, 0.22), (8.93, 0.12, 0.11)]
    return bell(freq, dur, tau, parts, rng=rng, attack=0.0008)


def grains(dur, rng, count, fmin, fmax, t0=0.0, t1=None, tau=(0.01, 0.05), amp_curve=None,
           partials=((1.0, 1.0), (2.0, 0.25))):
    """Scatter of tiny sine pings (sparkles, glass)."""
    t1 = dur * 0.8 if t1 is None else t1
    out = buf(dur)
    times = np.sort(rng.uniform(t0, t1, count))
    for i, tt in enumerate(times):
        f = math.exp(rng.uniform(math.log(fmin), math.log(fmax)))
        ta = rng.uniform(*tau)
        a = rng.uniform(0.4, 1.0)
        if amp_curve is not None:
            a *= amp_curve((tt - t0) / max(1e-6, (t1 - t0)))
        g = ping(f, min(ta * 6, dur), ta, partials, attack=0.0008, rng=rng)
        add(out, g, tt, a)
    return out


def crackle(dur, rng, rate, hp=2000.0, tau=0.002, amp_fn=None):
    n = ns(dur)
    x = np.zeros(n)
    count = int(rate * dur)
    pos = rng.integers(0, max(1, n - 1), count)
    amps = rng.uniform(0.3, 1.0, count) * rng.choice([-1, 1], count)
    if amp_fn is not None:
        amps *= amp_fn(pos / SR)
    np.add.at(x, pos, amps)
    k = np.exp(-np.arange(ns(tau * 6)) / (tau * SR))
    x = np.convolve(x, k)[:n]
    return S.highpass(x, hp, 2)


def room(x, t60=0.6, mix=0.2, damp=0.3, size=0.6, tail=None, predelay=0.008):
    tail = t60 * 0.7 if tail is None else tail
    wet = S.mono(S.fdn_reverb(x, t60=t60, damp=damp, size=size, tail=tail, predelay=predelay))
    dry = S.pad_to(x, len(wet))
    return dry + mix * wet


def env(dur, pts, kind="lin"):
    return S.env_pts(ns(dur), pts, kind)


def drive(x, amount):
    pk = np.max(np.abs(x)) + 1e-12
    return S.softclip(x / pk, amount) * pk


def norm(x):
    return x / (np.max(np.abs(x)) + 1e-12)


# --------------------------------------------------------------------------
# UI
# --------------------------------------------------------------------------

@sfx("ui_move", -6)
def ui_move(rng):
    d = 0.09
    n = ns(d)
    t = tvec(n)
    f = 1568.0 - 90.0 * np.exp(-t / 0.006)
    x = S.sine(f, n) * S.expdec(n, 0.024, 0.001)
    x += 0.16 * S.sine(2 * f, n) * S.expdec(n, 0.010, 0.001)
    c = click(rng, 5000, 0.002, 0.18)
    add(x, c)
    return S.lowpass(x, 9000)


@sfx("ui_confirm", -3)
def ui_confirm(rng):
    d = 0.7
    out = buf(d)
    for at, fr, g in ((0.0, 1318.5, 0.8), (0.075, 1975.5, 1.0)):
        b = fm_bell(fr, 0.55, 0.22, ratio=2.0, index=1.4, itau=0.05)
        add(b, ping(fr * 3.0, 0.3, 0.06), 0, 0.18)
        add(b, ping(fr * 0.5, 0.45, 0.15), 0, 0.25)
        add(out, b, at, g)
    add(out, click(rng, 6000, 0.002, 0.15))
    return room(out, 0.9, 0.18, damp=0.2, size=0.5)


@sfx("ui_back", -6)
def ui_back(rng):
    d = 0.13
    n = ns(d)
    t = tvec(n)
    f = 660.0 + 260.0 * np.exp(-t / 0.025)
    x = S.sine(f, n) * S.expdec(n, 0.035, 0.0015)
    x += 0.12 * S.sine(2 * f, n) * S.expdec(n, 0.015, 0.0015)
    add(x, click(rng, 3500, 0.002, 0.1))
    return S.lowpass(x, 5000)


@sfx("ui_error", -8)
def ui_error(rng):
    d = 0.3
    out = buf(d)
    for at, fr in ((0.0, 233.1), (0.105, 220.0)):
        n = ns(0.11)
        s = 0.6 * S.square(fr, n, 0.35) + 0.4 * S.saw(fr * 1.006, n)
        s = S.svf(s, 1400.0, 1.2) * S.adsr(n, 0.003, 0.05, 0.7, 0.03, 0.075)
        add(out, s, at)
    return drive(out, 1.1)


# --------------------------------------------------------------------------
# movement
# --------------------------------------------------------------------------

@sfx("jump", -4)
def jump(rng):
    d = 0.3
    out = whoosh(d, rng, [(0, 450), (0.22, 3200)], [(0, 0), (0.03, 1), (0.09, 0.55), (0.28, 0)], q=1.1, air=0.15)
    n = ns(0.16)
    t = tvec(n)
    b = S.sine(260 * (2.4 ** (t / 0.16)), n) * S.expdec(n, 0.045, 0.004)
    add(out, b, 0.005, 0.18)
    add(out, burst(0.03, rng, 0.006, lp=2500), 0.0, 0.25)
    return out


@sfx("land", -3)
def land(rng):
    d = 0.32
    out = buf(d)
    add(out, thump(0.2, 115, 48, 0.02, 0.055), 0.0, 1.0)
    dust = whoosh(0.3, rng, [(0, 1400), (0.25, 450)], [(0, 0), (0.006, 1), (0.08, 0.35), (0.3, 0)], q=0.8)
    add(out, norm(dust), 0.002, 0.6)
    add(out, burst(0.02, rng, 0.004, lp=3000), 0.0, 0.4)
    return drive(out, 1.4)


@sfx("dash", -3)
def dash(rng):
    d = 0.3
    out = whoosh(d, rng, [(0, 900), (0.06, 3000), (0.28, 700)], [(0, 0), (0.05, 1), (0.13, 0.45), (0.3, 0)],
                 q=1.0, air=0.2)
    low = whoosh(d, rng, [(0, 250), (0.28, 180)], [(0, 0), (0.04, 1), (0.25, 0)], q=0.7)
    add(out, low, 0, 0.45)
    return out


@sfx("step", -9)
def step(rng):
    d = 0.07
    out = burst(d, rng, 0.007, lp=2200) * 0.7
    add(out, thump(0.06, 170, 95, 0.01, 0.015), 0, 0.6)
    return out - np.mean(out) * np.hanning(len(out)) / 0.5


@sfx("flight", -6)
def flight(rng):
    d = 0.45
    n = ns(d)
    out = whoosh(d, rng, [(0, 600), (0.2, 1150), (0.45, 750)], [(0, 0), (0.15, 1), (0.3, 0.8), (0.45, 0)], q=0.75)
    t = tvec(n)
    out *= 1.0 - 0.22 * (0.5 + 0.5 * np.sin(2 * math.pi * 9.0 * t))
    hi = whoosh(d, rng, [(0, 3500), (0.45, 4500)], [(0, 0), (0.2, 1), (0.45, 0)], q=0.6)
    out += 0.25 * hi
    return out * np.sin(np.linspace(0, math.pi, n)) ** 0.6


# --------------------------------------------------------------------------
# melee
# --------------------------------------------------------------------------

@sfx("swing_light", -4)
def swing_light(rng):
    d = 0.17
    return whoosh(d, rng, [(0, 1100), (0.06, 2900), (0.17, 1500)], [(0, 0), (0.045, 1), (0.17, 0)], q=1.4, air=0.2)


@sfx("swing_heavy", -3)
def swing_heavy(rng):
    d = 0.34
    out = whoosh(d, rng, [(0, 380), (0.13, 1500), (0.34, 650)], [(0, 0), (0.11, 1), (0.2, 0.5), (0.34, 0)], q=1.1)
    rum = whoosh(d, rng, [(0, 160), (0.3, 120)], [(0, 0), (0.1, 1), (0.34, 0)], q=0.8)
    add(out, rum, 0, 0.6)
    n = ns(0.3)
    t = tvec(n)
    v = S.sine(120 - 40 * t / 0.3, n) * np.sin(np.linspace(0, math.pi, n)) ** 2
    add(out, v, 0.02, 0.18)
    return out


@sfx("hit_light", -3)
def hit_light(rng):
    d = 0.16
    out = buf(d)
    add(out, norm(click(rng, 3000, 0.003)), 0, 0.55)
    add(out, thump(0.12, 300, 150, 0.01, 0.03), 0, 0.75)
    add(out, nburst(0.1, rng, 0.022, bp=2200, q=0.8), 0.0005, 2.0)
    add(out, ping(950.0, 0.06, 0.012), 0, 0.25)
    return drive(out, 1.8)


@sfx("hit_medium", -2)
def hit_medium(rng):
    d = 0.3
    out = buf(d)
    add(out, norm(click(rng, 2500, 0.004)), 0, 0.6)
    add(out, thump(0.25, 210, 85, 0.02, 0.06), 0, 0.9)
    add(out, thump(0.1, 520, 240, 0.01, 0.025), 0, 0.8)
    add(out, nburst(0.2, rng, 0.04, bp=1600, q=0.7), 0.0008, 2.2)
    out = drive(out, 2.2)
    return room(out, 0.45, 0.12, size=0.5)


def _heavy_core(rng, weight=1.0):
    d = 0.6
    out = buf(d)
    add(out, norm(click(rng, 2200, 0.005)), 0, 0.65)
    add(out, thump(0.5, 150, 42, 0.04 * weight, 0.15 * weight), 0, 1.0)
    add(out, thump(0.2, 380, 120, 0.025, 0.04), 0, 1.0)
    add(out, nburst(0.35, rng, 0.06, bp=1100, q=0.6), 0.001, 2.4)
    add(out, nburst(0.08, rng, 0.01, hp=4000), 0.0, 0.35)
    out = drive(out, 2.6)
    return room(out, 0.7, 0.15, size=0.7)


@sfx("hit_heavy", 0)
def hit_heavy(rng):
    return _heavy_core(rng)


@sfx("hit_counter", 0)
def hit_counter(rng):
    out = S.pad_to(_heavy_core(rng), ns(1.0))
    n = ns(0.9)
    t = tvec(n)
    sting = S.fm(2200.0, n, 1.414, 2.6 * np.exp(-t / 0.08) + 0.5) * S.expdec(n, 0.32, 0.0015)
    for r, a, tau in ((1.0, 0.6, 0.4), (1.502, 0.4, 0.3), (2.27, 0.3, 0.2), (2.96, 0.2, 0.15)):
        sting += a * S.sine(2640.0 * r, n) * np.exp(-t / tau) * (1 + 0.3 * np.sin(2 * math.pi * 11 * t))
    add(sting, burst(0.15, rng, 0.03, hp=5000), 0, 0.5)
    sting = room(sting, 1.0, 0.2, damp=0.15)
    add(out, sting, 0.006, 0.42)
    return out


@sfx("block", -2)
def block(rng):
    d = 0.45
    out = buf(d)
    add(out, nburst(0.06, rng, 0.012, lp=1800), 0, 0.9)
    clack = ping(620, 0.1, 0.03, ((1.0, 1.0), (1.68, 0.6)))
    add(out, clack, 0, 0.7)
    add(out, thump(0.1, 190, 120, 0.02, 0.03), 0, 0.7)
    n = ns(0.4)
    t = tvec(n)
    sh = np.zeros(n)
    for k, fr in enumerate((3520.0, 4186.0, 5274.0, 6272.0)):
        sh += S.sine(fr, n, rng.random()) * (0.6 + 0.4 * np.sin(2 * math.pi * (17 + 3 * k) * t + k))
    sh *= S.expdec(n, 0.12, 0.004) * 0.25
    add(out, sh, 0.004, 0.3)
    add(out, grains(0.4, rng, 8, 4000, 8000, 0.01, 0.2, (0.01, 0.03)), 0, 0.1)
    return out


@sfx("guard_crush", 0)
def guard_crush(rng):
    d = 1.1
    out = buf(d)
    add(out, click(rng, 2000, 0.006, 1.0))
    glass = grains(0.7, rng, 90, 2200, 9500, 0.0, 0.5, (0.004, 0.03),
                   amp_curve=lambda u: np.exp(-3.0 * u), partials=((1.0, 1.0), (2.31, 0.4)))
    add(out, norm(glass), 0.003, 1.8)
    crk = whoosh(0.5, rng, [(0, 6000), (0.5, 4500)], [(0, 1), (0.03, 0.8), (0.5, 0)], q=0.6)
    add(out, norm(crk), 0, 1.0)
    add(out, nburst(0.25, rng, 0.04, bp=1500, q=0.7), 0, 1.2)
    add(out, thump(0.9, 95, 32, 0.08, 0.32), 0.01, 0.8)
    add(out, nburst(0.6, rng, 0.2, lp=300), 0.01, 0.5)
    out = drive(out, 1.8)
    return room(out, 1.3, 0.22, damp=0.25, size=0.9)


# --------------------------------------------------------------------------
# bullets / magic
# --------------------------------------------------------------------------

@sfx("shot_firefly", -12)
def shot_firefly(rng):
    d = 0.12
    n = ns(d)
    t = tvec(n)
    f = 1700 + 800 * np.exp(-t / 0.018)
    x = S.sine(f, n) * S.expdec(n, 0.028, 0.002)
    sp = S.fm(3520.0, n, 2.5, 0.8) * S.expdec(n, 0.014, 0.001)
    add(x, sp, 0.012, 0.25)
    return S.lowpass(x, 6500)


@sfx("shot_star", -6)
def shot_star(rng):
    d = 0.42
    out = buf(d)
    for i, fr in enumerate((2093.0, 2637.0, 3136.0)):
        add(out, fm_bell(fr, 0.3, 0.07, ratio=2.0, index=1.0), 0.022 * i, 0.55 + 0.2 * i)
    add(out, ping(2093.0, 0.4, 0.15, ((1.0, 1.0), (3.0, 0.15))), 0.06, 0.5)
    add(out, burst(0.2, rng, 0.05, hp=6000), 0.0, 0.18)
    return room(out, 0.7, 0.15, damp=0.15, size=0.5)


@sfx("comet", -3)
def comet(rng):
    d = 0.68
    out = whoosh(d, rng, [(0, 2600), (0.6, 700)], [(0, 0), (0.04, 1), (0.2, 0.6), (0.65, 0)], q=0.9, air=0.25)
    tail = grains(0.68, rng, 45, 3000, 8500, 0.06, 0.55, (0.01, 0.05), amp_curve=lambda u: 1.0 - 0.7 * u)
    add(out, tail, 0, 0.45)
    n = ns(0.5)
    t = tvec(n)
    fz = S.sine(1800 * np.exp(-t / 0.6), n) * S.expdec(n, 0.18, 0.01) * (0.6 + 0.4 * np.sin(2 * math.pi * 30 * t))
    add(out, fz, 0.02, 0.15)
    return room(out, 0.8, 0.12, damp=0.2)


@sfx("moth", -6)
def moth(rng):
    d = 0.5
    n = ns(d)
    t = tvec(n)
    flap = np.abs(np.sin(2 * math.pi * 12.0 * t)) ** 2
    out = whoosh(d, rng, [(0, 800), (0.25, 1100), (0.5, 900)], [(0, 0), (0.08, 1), (0.35, 0.7), (0.5, 0)], q=1.4)
    out *= 0.35 + 0.65 * flap
    sh = S.sine(1760.0 * (1 + 0.012 * np.sin(2 * math.pi * 6.5 * t)), n) * np.sin(np.linspace(0, math.pi, n)) ** 2
    sh += 0.4 * S.sine(2637.0 * (1 + 0.012 * np.sin(2 * math.pi * 7.1 * t)), n) * np.sin(np.linspace(0, math.pi, n)) ** 3
    out += 0.22 * sh
    add(out, grains(0.5, rng, 6, 3000, 6000, 0.05, 0.35, (0.01, 0.03)), 0, 0.2)
    return room(out, 0.7, 0.15, damp=0.2)


@sfx("lantern_place", -4)
def lantern_place(rng):
    d = 1.4
    out = buf(d)
    add(out, bell(659.25, 1.3, 1.0, rng=rng, attack=0.0015), 0, 1.0)
    add(out, fm_bell(1318.5, 0.3, 0.06, ratio=3.0, index=1.5), 0, 0.15)
    add(out, burst(0.03, rng, 0.004, bp=3000, q=1.0), 0, 0.12)
    return room(out, 1.2, 0.18, damp=0.3)


@sfx("beam", -2)
def beam(rng):
    d = 2.4
    n = ns(d)
    t = tvec(n)
    amp = S.env_pts(n, [(0, 0), (0.28, 1.0), (0.45, 0.85), (1.8, 0.9), (2.4, 0.0)])
    amp = amp ** 1.2
    core = np.zeros(n)
    for m, g in ((50, 0.5), (57, 0.45), (62, 0.4), (66, 0.32), (69, 0.3), (74, 0.2)):
        f = S.midi_hz(m) * (1 + 0.003 * np.sin(2 * math.pi * 0.7 * t + m))
        core += g * S.mono(S.supersaw(f, n, 5, 14, rng))
    cut = S.env_pts(n, [(0, 400), (0.5, 2600), (1.6, 3600), (2.4, 900)], "exp")
    core = S.svf(core, cut, 1.4)
    shimmer = np.zeros(n)
    for k, m in enumerate((86, 90, 93, 98, 102)):
        trem = 0.55 + 0.45 * np.sin(2 * math.pi * (5.5 + 1.3 * k) * t + rng.random() * 6)
        shimmer += S.sine(S.midi_hz(m), n, rng.random()) * trem / (1 + 0.3 * k)
    hiss = S.shaped_noise(n, rng, lambda tt, f: S.H_bp(f, 2500 + 1200 * np.sin(2 * math.pi * 1.3 * tt), 1.5))
    hum = S.sine(73.42, n) * 0.6 + S.sine(146.8 * (1 + 0.004 * np.sin(2 * math.pi * 5 * t)), n) * 0.35
    hum *= 0.75 + 0.25 * np.sin(2 * math.pi * 7.0 * t)
    out = 0.55 * core + 0.12 * shimmer + 0.35 * hiss + 0.45 * hum
    out = out * amp
    return room(out, 1.2, 0.2, damp=0.25, tail=0.4)


def _zap(dur, rng, fmin=500.0, fmax=2600.0, hold=0.004, tau=0.05):
    n = ns(dur)
    steps = int(dur / hold) + 2
    fr = np.exp(rng.uniform(math.log(fmin), math.log(fmax), steps))
    f = np.repeat(fr, ns(hold))[:n]
    f = S.pad_to(f, n)
    f[f == 0] = fmin
    x = 0.6 * S.square(f, n, 0.4) + 0.4 * S.saw(f * 1.5, n)
    x *= S.expdec(n, tau, 0.0008)
    return S.highpass(x, 300, 1)


@sfx("spark_shot", -4)
def spark_shot(rng):
    d = 0.17
    out = _zap(d, rng, 600, 2800, 0.003, 0.045) * 0.6
    add(out, crackle(d, rng, 220, 3000, 0.0015, lambda tt: np.exp(-tt / 0.06)), 0, 1.6)
    add(out, click(rng, 4000, 0.003, 0.8))
    return drive(S.lowpass(out, 10000), 1.5)


@sfx("electric_orb", -4)
def electric_orb(rng):
    d = 0.85
    n = ns(d)
    t = tvec(n)
    buzz = S.saw(110.0 * (1 + 0.01 * np.sin(2 * math.pi * 3 * t)), n) + 0.7 * S.saw(165.6, n) + 0.4 * S.square(55.0, n)
    buzz = S.svf(buzz, 1400 + 600 * np.sin(2 * math.pi * 4 * t), 2.5, "bp")
    sh = np.repeat(rng.uniform(0.3, 1.0, int(d / 0.02) + 2), ns(0.02))[:n]
    buzz *= S.onepole_lp(S.pad_to(sh, n), 60)
    crk = crackle(d, rng, 90, 2500, 0.002)
    sizzle = S.highpass(S.noise(n, rng), 6000, 2) * (0.5 + 0.5 * S.pad_to(np.repeat(rng.random(int(d / 0.01) + 2), ns(0.01)), n))
    out = 0.6 * buzz + 1.3 * crk + 0.12 * sizzle
    out *= S.env_pts(n, [(0, 0), (0.05, 1), (0.6, 0.9), (0.85, 0)])
    return drive(out, 1.6)


@sfx("thunder_crack", 0)
def thunder_crack(rng):
    d = 1.65
    out = buf(d)
    add(out, burst(0.08, rng, 0.012, hp=1200), 0, 1.0)
    add(out, crackle(0.12, rng, 400, 1500, 0.002, lambda tt: np.exp(-tt / 0.04)), 0.0, 2.0)
    n = ns(0.12)
    tt = tvec(n)
    add(out, S.saw(3000 * np.exp(-tt / 0.03) + 200, n) * S.expdec(n, 0.03), 0, 0.25)
    n = ns(d)
    t = tvec(n)
    rumble_env = np.zeros(n)
    for _ in range(9):
        c = rng.uniform(0.06, 1.0)
        w = rng.uniform(0.08, 0.3)
        rumble_env += rng.uniform(0.4, 1.0) * np.exp(-((t - c) / w) ** 2) * np.exp(-c / 0.7)
    rumble_env += 0.5 * np.exp(-t / 0.5) * np.clip(t / 0.02, 0, 1)
    rum = S.shaped_noise(n, rng, lambda ti, f: S.H_lp(f, 320 * np.exp(-ti / 1.2) + 90, 2))
    sub = S.sine(38.0, n) * (0.5 + 0.5 * S.onepole_lp(rng.standard_normal(n), 8) * 6)
    rumble = (rum * 3.0 + 0.4 * sub) * rumble_env
    rumble *= np.clip((d - t) / 0.25, 0, 1)
    add(out, rumble, 0.01, 1.0)
    out = drive(out, 1.5)
    return room(out, 1.8, 0.25, damp=0.3, size=1.0)


@sfx("uppercut", -2)
def uppercut(rng):
    d = 0.5
    out = whoosh(d, rng, [(0, 350), (0.22, 2600), (0.4, 1800)], [(0, 0), (0.12, 1), (0.25, 0.4), (0.45, 0)], q=1.1)
    n = ns(0.25)
    t = tvec(n)
    add(out, S.sine(200 * 3 ** (t / 0.25), n) * np.sin(np.linspace(0, math.pi, n)), 0.0, 0.25)
    zap = _zap(0.22, rng, 700, 3200, 0.003, 0.06)
    add(zap, crackle(0.22, rng, 200, 3000, 0.0015, lambda tt: np.exp(-tt / 0.07)), 0, 1.4)
    add(out, zap, 0.11, 0.7)
    return drive(out, 1.4)


@sfx("explosion", 0)
def explosion(rng):
    d = 1.4
    out = buf(d)
    add(out, click(rng, 1500, 0.006, 0.8))
    add(out, thump(1.0, 90, 30, 0.1, 0.38), 0, 1.0)
    add(out, burst(1.0, rng, 0.35, lp=220), 0, 0.9)
    blast = S.shaped_noise(ns(1.0), rng, lambda t, f: S.H_lp(f, 4200 * np.exp(-t / 0.18) + 250, 2) * np.exp(-t / 0.28))
    add(out, blast, 0.002, 1.3)
    add(out, crackle(0.8, rng, 120, 1500, 0.003, lambda tt: np.exp(-tt / 0.25)), 0.02, 0.9)
    sp = grains(1.2, rng, 40, 2500, 7500, 0.08, 0.9, (0.02, 0.08), amp_curve=lambda u: 1 - 0.8 * u,
                partials=((1.0, 1.0), (2.0, 0.3), (3.0, 0.1)))
    add(out, sp, 0, 0.35)
    out = drive(out, 2.2)
    return room(out, 1.6, 0.25, damp=0.3, size=1.0)


@sfx("bullet_cancel", -10)
def bullet_cancel(rng):
    d = 0.06
    x = thump(d, 1300, 480, 0.008, 0.013, attack=0.0005)
    add(x, click(rng, 5000, 0.0015, 0.25))
    return S.lowpass(x, 7000)


@sfx("graze", -14)
def graze(rng):
    d = 0.055
    x = burst(d, rng, 0.008, bp=6500, q=1.2)
    add(x, ping(6272.0, 0.05, 0.012), 0.002, 0.35)
    return S.lowpass(x, 12000)


# --------------------------------------------------------------------------
# system
# --------------------------------------------------------------------------

@sfx("card_gain", -3)
def card_gain(rng):
    d = 0.7
    out = buf(d)
    add(out, burst(0.02, rng, 0.004, bp=2600, q=0.8), 0.0, 0.9)
    add(out, burst(0.02, rng, 0.004, bp=3400, q=0.8), 0.009, 0.7)
    sw = whoosh(0.09, rng, [(0, 1800), (0.08, 5200)], [(0, 0.4), (0.03, 1), (0.09, 0)], q=1.0)
    add(out, sw, 0.0, 0.6)
    for at, fr, g in ((0.05, 1568.0, 0.7), (0.05, 2349.3, 0.45), (0.11, 3136.0, 0.35)):
        add(out, fm_bell(fr, 0.55, 0.22, ratio=2.0, index=1.2, itau=0.04), at, g)
    return room(out, 0.9, 0.15, damp=0.15)


@sfx("card_select", -6)
def card_select(rng):
    d = 0.05
    x = burst(d, rng, 0.005, bp=3000, q=1.0)
    add(x, ping(2200.0, 0.04, 0.008), 0.0, 0.35)
    return x


def choir(midis, dur, rng, vowel=((730, 1.0, 6), (1090, 0.6, 7), (2440, 0.3, 9)), vib=0.006):
    """Formant-filtered saw stack ("aah" pad)."""
    n = ns(dur)
    t = tvec(n)
    src = np.zeros(n)
    for m in midis:
        for k in range(3):
            f = S.midi_hz(m) * 2 ** ((k - 1) * 0.08 / 12) * (1 + vib * np.sin(2 * math.pi * (5.0 + 0.4 * k) * t + rng.random() * 6))
            src += S.saw(f, n, rng.random())
    def H(f):
        h = np.zeros_like(f)
        for fc, a, q in vowel:
            h += a * S.H_bp(f, fc, q)
        return h * S.H_lp(f, 4000, 2) + 0.05 * S.H_lp(f, 500, 1)
    return S.fft_filter(src, H)


@sfx("spell_declare", 0)
def spell_declare(rng):
    d = 2.0
    out = buf(d)
    rise = whoosh(0.62, rng, [(0, 700), (0.6, 7500)], [(0, 0), (0.55, 1), (0.62, 0.2)], q=1.0, air=0.3)
    add(out, rise, 0, 0.55)
    for i, m in enumerate((74, 76, 78, 81, 83, 86, 88, 90, 93, 95)):
        add(out, ping(S.midi_hz(m), 0.3, 0.07, ((1.0, 1.0), (2.0, 0.2))), 0.05 + 0.055 * i, 0.12 + 0.03 * i)
    hit = 0.6
    add(out, click(rng, 1800, 0.006, 0.8), hit)
    add(out, thump(1.0, 85, 34, 0.07, 0.4), hit, 1.0)
    add(out, burst(0.6, rng, 0.2, lp=350), hit, 0.6)
    n = ns(1.05)
    ch = choir((50, 57, 62, 65, 69, 76), 1.05, rng)
    ch *= S.env_pts(n, [(0, 0), (0.06, 1), (0.45, 0.75), (1.05, 0)]) ** 1.3
    add(out, ch, hit - 0.02, 0.22)
    add(out, ping(S.midi_hz(86), 1.0, 0.4, ((1.0, 1.0), (2.0, 0.3), (3.0, 0.1))), hit, 0.18)
    out = drive(out, 1.4)
    return room(out, 1.6, 0.3, damp=0.25, size=1.0, tail=0.4)


@sfx("super_flash", -1)
def super_flash(rng):
    d = 0.6
    out = buf(d)
    n = ns(0.05)
    t = tvec(n)
    add(out, S.sine(1000 * 6 ** (t / 0.05), n) * np.sin(np.linspace(0, math.pi, n)), 0, 0.3)
    add(out, burst(0.2, rng, 0.04, hp=4500), 0.035, 0.6)
    n = ns(0.55)
    t = tvec(n)
    m = np.zeros(n)
    for fr, a, tau in ((2637, 0.7, 0.35), (3951, 0.6, 0.28), (5274, 0.5, 0.22), (7040, 0.35, 0.15), (8372, 0.25, 0.1)):
        m += a * S.sine(fr * (1 + 0.002 * np.sin(2 * math.pi * 13 * t)), n, rng.random()) * np.exp(-t / tau)
    m *= np.clip(t / 0.002, 0, 1)
    add(out, m, 0.04, 0.55)
    return room(out, 0.9, 0.18, damp=0.15)


@sfx("heal", -4)
def heal(rng):
    d = 1.1
    out = buf(d)
    for i, m in enumerate((74, 78, 81, 86, 90, 93)):
        add(out, ping(S.midi_hz(m), 0.5, 0.18, ((1.0, 1.0), (2.0, 0.18))), 0.065 * i, 0.5 + 0.06 * i)
    sh = whoosh(0.8, rng, [(0, 4000), (0.8, 7000)], [(0, 0), (0.4, 1), (0.8, 0)], q=0.8)
    add(out, sh, 0.0, 0.12)
    return room(out, 1.2, 0.25, damp=0.2)


@sfx("spirit_refill", -5)
def spirit_refill(rng):
    d = 0.55
    out = buf(d)
    for i, m in enumerate((81, 85, 88, 93, 97, 100)):
        n = ns(0.05)
        f = S.midi_hz(m)
        b = 0.7 * S.square(f, n, 0.25) + 0.3 * S.sine(f, n)
        b = S.lowpass(b, 6000) * S.adsr(n, 0.002, 0.03, 0.4, 0.012, 0.035)
        add(out, b, 0.05 * i, 0.4 + 0.08 * i)
    wet = S.mono(S.pingpong_delay(S.pad_to(out, ns(0.9)), 0.075, 0.3, 7000, 500))
    out = S.pad_to(out, ns(0.9)) + 0.25 * wet
    return out


@sfx("weather_change", -3)
def weather_change(rng):
    d = 1.75
    out = buf(d)
    pent = [74, 76, 78, 81, 83, 86, 88, 90, 93, 95]
    times = np.concatenate([[0.0], np.sort(np.clip(rng.normal(0.55, 0.25, 24), 0.02, 1.0))])
    for k, tt in enumerate(times):
        m = pent[rng.integers(0, len(pent))]
        g = rng.uniform(0.25, 0.6) * (1.0 - 0.5 * max(0.0, tt - 0.6))
        add(out, chime(S.midi_hz(m), 0.8, 0.55, rng=rng), float(tt), g)
    wind = whoosh(1.5, rng, [(0, 500), (0.6, 1400), (1.5, 700)], [(0, 0.1), (0.6, 1), (1.5, 0)], q=0.7)
    add(out, wind, 0.0, 0.4)
    out = room(out, 1.2, 0.25, damp=0.2, tail=0.2)
    n = len(out)
    return out * np.clip((S.ns(1.75) - np.arange(n)) / S.ns(0.4), 0, 1) ** 1.5


@sfx("round_announce", 0)
def round_announce(rng):
    d = 1.8
    out = buf(d)
    n = ns(1.7)
    t = tvec(n)
    g = np.zeros(n)
    f0 = 110.0
    for r, a, tau in ((1.0, 1.0, 0.95), (1.52, 0.7, 0.7), (2.03, 0.5, 0.6), (2.48, 0.45, 0.5), (2.97, 0.3, 0.42),
                      (3.53, 0.25, 0.32), (4.2, 0.18, 0.25), (5.11, 0.12, 0.18)):
        for det in (0.0, 0.7):
            g += a * 0.5 * S.sine(f0 * r + det * r, n, rng.random()) * np.exp(-t / tau)
    g *= np.clip(t / 0.006, 0, 1) * (1 + 0.4 * np.exp(-t / 0.15))
    add(out, g, 0, 0.7)
    add(out, thump(0.3, 140, 70, 0.03, 0.08), 0, 0.5)
    add(out, fm_bell(1174.7, 1.4, 0.5, ratio=3.5, index=1.6, itau=0.15), 0.0, 0.3)
    add(out, ping(587.33, 1.5, 0.7, ((1.0, 1.0), (2.0, 0.4), (3.0, 0.15))), 0.0, 0.35)
    add(out, burst(0.4, rng, 0.12, hp=5000), 0.0, 0.12)
    out = drive(out, 1.3)
    out = room(out, 1.5, 0.25, damp=0.25, size=1.0, tail=0.3)
    n = len(out)
    return out * np.clip((S.ns(1.8) - np.arange(n)) / S.ns(0.45), 0, 1) ** 1.5


@sfx("fight_start", 0)
def fight_start(rng):
    d = 0.95
    out = buf(d)
    n = ns(0.6)
    st = np.zeros(n)
    for m in (50, 57, 62, 66, 69, 74):
        st += S.mono(S.supersaw(S.midi_hz(m), n, 5, 16, rng))
    st = S.svf(st, S.env_pts(n, [(0, 7000), (0.25, 1500), (0.6, 800)], "exp"), 1.0)
    st *= S.adsr(n, 0.002, 0.2, 0.3, 0.2, 0.3)
    br = np.zeros(n)
    t = tvec(n)
    for m in (62, 66, 69):
        br += S.fm(S.midi_hz(m), n, 1.0, 3.0 * np.exp(-t / 0.15) + 0.8)
    br *= S.adsr(n, 0.008, 0.2, 0.5, 0.2, 0.3)
    add(out, st, 0, 0.35)
    add(out, br, 0, 0.18)
    add(out, thump(0.4, 160, 45, 0.03, 0.12), 0, 0.9)
    add(out, burst(0.3, rng, 0.07, bp=2000, q=0.6), 0, 0.6)
    add(out, burst(0.8, rng, 0.3, hp=5000), 0, 0.25)
    out = drive(out, 1.6)
    return room(out, 1.2, 0.2, damp=0.25)


@sfx("ko", 0)
def ko(rng):
    d = 3.2
    out = buf(d)
    add(out, click(rng, 1500, 0.008, 1.0))
    add(out, thump(1.6, 75, 24, 0.15, 0.7), 0, 1.0)
    add(out, thump(0.4, 220, 70, 0.04, 0.09), 0, 0.6)
    add(out, nburst(0.6, rng, 0.09, bp=1000, q=0.6), 0, 2.2)
    add(out, nburst(0.15, rng, 0.02, hp=3500), 0, 0.35)
    add(out, thump(0.3, 420, 130, 0.03, 0.06), 0, 1.0)
    n = ns(0.7)
    t = tvec(n)
    add(out, S.sine(400 * np.exp(-t / 0.15) + 55, n) * S.expdec(n, 0.25, 0.01), 0.0, 0.3)
    add(out, burst(1.2, rng, 0.45, lp=250), 0, 0.6)
    out = drive(out, 3.0)
    wet = S.mono(S.fdn_reverb(out, t60=3.6, damp=0.22, size=1.3, predelay=0.02, tail=1.0))
    return S.pad_to(out, len(wet)) + 0.8 * wet


@sfx("timer_tick", -6)
def timer_tick(rng):
    d = 0.06
    x = ping(1900.0, d, 0.012, ((1.0, 1.0), (2.71, 0.4)), attack=0.0005)
    add(x, click(rng, 3000, 0.0015, 0.3))
    return S.lowpass(x, 9000)


@sfx("combo_break", -4)
def combo_break(rng):
    d = 0.5
    out = buf(d)
    add(out, fm_bell(987.8, 0.3, 0.08, ratio=2.0, index=1.0), 0, 0.6)
    add(out, fm_bell(698.5, 0.4, 0.12, ratio=2.0, index=1.0), 0.07, 0.6)
    add(out, thump(0.2, 140, 70, 0.03, 0.05), 0.07, 0.4)
    return room(out, 0.6, 0.15)


@sfx("slowmo", -2)
def slowmo(rng):
    d = 1.05
    fwd = buf(1.2)
    add(fwd, thump(0.9, 70, 32, 0.1, 0.3), 0, 1.0)
    add(fwd, burst(0.9, rng, 0.25, lp=400), 0, 0.8)
    wh = whoosh(1.0, rng, [(0, 1800), (0.9, 300)], [(0, 1), (0.9, 0)], q=0.9)
    add(fwd, wh, 0, 0.5)
    fwd = fwd + 0.9 * S.mono(S.fdn_reverb(fwd, t60=1.6, damp=0.3, size=1.0))
    rev = fwd[::-1][-ns(d):]
    n = len(rev)
    t = tvec(n)
    tape = S.sine(240 * (0.25 ** (t / d)), n) * (t / d) ** 2 * 0.5
    out = rev / (np.max(np.abs(rev)) + 1e-9) + 0.25 * tape
    return out


# --------------------------------------------------------------------------
# finishing
# --------------------------------------------------------------------------

def finalize(x: np.ndarray, peak_db: float = -1.0) -> np.ndarray:
    x = np.asarray(x, dtype=float)
    x = S.highpass(x, 22.0, 2)
    pk = np.max(np.abs(x)) + 1e-12
    # leading trim (-50 dB rel. peak), keep 1 ms
    thr = pk * S.db(-50)
    idx = np.nonzero(np.abs(x) > thr)[0]
    start = max(0, idx[0] - ns(0.001)) if len(idx) else 0
    x = x[start:]
    # trailing trim: last 5 ms window above -60 dB rel. peak
    w = ns(0.005)
    nb = len(x) // w
    if nb > 1:
        r = np.sqrt(np.mean(x[: nb * w].reshape(nb, w) ** 2, axis=1))
        live = np.nonzero(r > pk * S.db(-60))[0]
        end = min(len(x), (live[-1] + 2) * w) if len(live) else len(x)
        x = x[:end]
    x = S.fade_edges(x, 0.0005, min(0.012, len(x) / SR * 0.2))
    x = x / (np.max(np.abs(x)) + 1e-12) * S.db(peak_db)
    return x


def render(name: str) -> np.ndarray:
    rng = S.rng_for("sfx:" + name)
    x = SFX[name](rng)
    if not np.all(np.isfinite(x)):
        raise ValueError(f"{name}: non-finite samples")
    return finalize(x)

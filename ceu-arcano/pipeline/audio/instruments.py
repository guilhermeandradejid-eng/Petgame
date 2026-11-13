"""Synth patches used by the music renderer.

Each patch is a cached pure function of hashable arguments that returns a
(mono or stereo) numpy array.  Returned arrays are shared by the cache, so
callers must never modify them in place.
"""
from __future__ import annotations

import functools
import math
from functools import lru_cache

import numpy as np

import synth as S
from synth import SR, ns, tvec, midi_hz


def _rng(*key):
    return S.rng_for("inst:" + ":".join(str(k) for k in key))


def patch(fn):
    """Cache a patch and guarantee a click-free ending (25 ms fade-out)."""
    @lru_cache(maxsize=None)
    @functools.wraps(fn)
    def wrapper(*a, **k):
        x = fn(*a, **k)
        return S.fade_edges(x, 0.0, min(0.025, len(x) / SR * 0.25))
    return wrapper


# --------------------------------------------------------------------------
# mallets, bells, plucks
# --------------------------------------------------------------------------

@patch
def celesta(m: int, dur: float, ring: float = 2.2) -> np.ndarray:
    f = float(midi_hz(m))
    n = ns(dur + ring)
    t = tvec(n)
    sc = (880.0 / f) ** 0.35
    rng = _rng("cel", m)
    parts = [(1.0, 1.0, 1.5 * sc), (2.0, 0.30, 0.45 * sc), (3.0, 0.09, 0.2 * sc),
             (4.16, 0.05, 0.09 * sc), (5.43, 0.025, 0.05 * sc)]
    x = np.zeros(n)
    for r, a, d in parts:
        if f * r < SR * 0.45:
            x += a * S.sine(f * r, n, rng.random()) * np.exp(-t / d)
    x *= np.clip(t / 0.0015, 0, 1)
    hn = ns(0.006)
    hammer = S.bandpass(rng.standard_normal(hn), min(5 * f, 10000), 0.8) * np.exp(-np.arange(hn) / (0.0012 * SR))
    x[:hn] += 0.12 * hammer
    if 8.0 * f < SR * 0.45:
        x += 0.03 * S.sine(8.0 * f, n) * np.exp(-t / 0.03)
    rel_t = dur + 0.4
    x *= np.where(t > rel_t, np.exp(-(t - rel_t) / 0.22), 1.0)
    return x


@patch
def musicbox(m: int, dur: float) -> np.ndarray:
    f = float(midi_hz(m)) * 2 ** (((m * 7919) % 7 - 3) / 1200.0)
    n = ns(min(dur, 1.0) + 2.2)
    t = tvec(n)
    rng = _rng("mbox", m)
    x = S.sine(f, n, rng.random()) * np.exp(-t / (1.0 * (1046.0 / f) ** 0.3))
    x += 0.07 * S.sine(2 * f, n) * np.exp(-t / 0.3)
    if 6.27 * f < SR * 0.45:
        x += 0.22 * S.sine(6.27 * f, n, rng.random()) * np.exp(-t / 0.06)
    if 17.55 * f < SR * 0.45:
        x += 0.05 * S.sine(17.55 * f, n) * np.exp(-t / 0.02)
    x *= np.clip(t / 0.0006, 0, 1)
    return x


@patch
def harp(m: int, dur: float, bright: float = 1.0) -> np.ndarray:
    f = float(midi_hz(m))
    n = ns(max(dur, 0.25) + 1.4)
    t = tvec(n)
    idx = 1.7 * bright * np.exp(-t / 0.045) + 0.22
    x = 0.8 * S.fm(f, n, 1.0, idx) + 0.2 * S.fm(f * 1.002, n, 2.0, 0.6 * np.exp(-t / 0.08))
    x *= np.exp(-t / (0.85 * (440.0 / f) ** 0.3)) * np.clip(t / 0.002, 0, 1)
    rel = max(dur, 0.25) + 0.6
    x *= np.where(t > rel, np.exp(-(t - rel) / 0.2), 1.0)
    return S.lowpass(x, 7500, 1)


@patch
def fm_bell(m: int, dur: float, ratio: float = 3.5, index: float = 2.2, tau: float = 1.4) -> np.ndarray:
    f = float(midi_hz(m))
    n = ns(dur + tau * 2.2)
    t = tvec(n)
    tt = tau * (660.0 / f) ** 0.3
    index = index * min(1.0, 1400.0 / f)  # keep FM sidebands below Nyquist on high notes
    x = S.fm(f, n, ratio, index * np.exp(-t / (tt * 0.35)) + 0.15) * np.exp(-t / tt)
    x += 0.35 * S.sine(f, n) * np.exp(-t / (tt * 1.4))
    return x * np.clip(t / 0.001, 0, 1)


@patch
def epiano(m: int, dur: float, vel: float = 0.8) -> np.ndarray:
    """FM 'tine' electric piano with stereo tremolo."""
    f = float(midi_hz(m))
    n = ns(dur + 0.9)
    t = tvec(n)
    body = S.fm(f, n, 1.0, (0.7 + 1.5 * vel) * np.exp(-t / 0.5) + 0.2)
    tine = S.fm(f, n, 14.0, 1.2 * vel * np.exp(-t / 0.012)) * np.exp(-t / 0.06)
    x = body * np.exp(-t / (2.0 * (261.0 / f) ** 0.4)) + 0.22 * vel * tine
    x *= np.clip(t / 0.0015, 0, 1)
    x *= np.where(t > dur, np.exp(-(t - dur) / 0.12), 1.0)
    x = S.lowpass(x, 6000, 1)
    lfo = np.sin(2 * math.pi * 3.1 * t + m)
    return np.stack([x * (1 + 0.22 * lfo), x * (1 - 0.22 * lfo)], axis=1) * 0.7


@patch
def pluck(m: int, dur: float, vel: float = 0.8) -> np.ndarray:
    """Bright FM pluck used for counter lines."""
    f = float(midi_hz(m))
    n = ns(dur + 0.6)
    t = tvec(n)
    body = S.fm(f, n, 1.0, 1.5 * np.exp(-t / 0.18) + 0.35) * np.exp(-t / 0.45)
    tine = S.fm(f, n, 7.0, 1.4 * np.exp(-t / 0.01)) * np.exp(-t / 0.04)
    x = body + 0.25 * tine
    x *= np.clip(t / 0.0015, 0, 1) * np.where(t > dur, np.exp(-(t - dur) / 0.06), 1.0)
    return x * vel


@patch
def arp_pluck(m: int, bright: float = 1.0) -> np.ndarray:
    f = float(midi_hz(m))
    n = ns(0.22)
    t = tvec(n)
    x = 0.6 * S.square(f, n, 0.3) + 0.4 * S.saw(f * 1.003, n)
    cut = 500 + 4200 * bright * np.exp(-t / 0.035)
    x = S.svf(x, cut, 1.6)
    return x * S.adsr(n, 0.0015, 0.08, 0.25, 0.05, 0.16)


# --------------------------------------------------------------------------
# leads
# --------------------------------------------------------------------------

def _vibrato(n, rate=5.5, depth=0.005, delay=0.18, ramp=0.25):
    t = tvec(n)
    return 1.0 + depth * np.sin(2 * math.pi * rate * t) * np.clip((t - delay) / ramp, 0, 1)


@patch
def supersaw_lead(m: int, dur: float, vel: float = 0.9) -> np.ndarray:
    f = float(midi_hz(m))
    n = ns(dur + 0.25)
    vib = _vibrato(n, 5.6, 0.0045, 0.16)
    x = S.supersaw(f * vib, n, 7, 20, _rng("ssl", m), spread=0.75)
    sub = 0.3 * S.square(f * vib, n, 0.5)
    x = x + sub[:, None] * 0.7
    x = S.fft_filter(x, lambda fr: S.H_lp(fr, 6200, 2) * S.H_hp(fr, 180, 1))
    env = S.adsr(n, 0.006, 0.3, 0.72, 0.16, dur)
    t = tvec(n)
    bite = 1.0 + 0.35 * np.exp(-t / 0.05)
    return x * (env * bite * vel)[:, None]


@patch
def brass(m: int, dur: float, vel: float = 0.9) -> np.ndarray:
    """FM brass/trumpet-ish lead."""
    f = float(midi_hz(m))
    n = ns(dur + 0.2)
    t = tvec(n)
    vib = _vibrato(n, 5.2, 0.0055, 0.2)
    idx = (1.0 + 2.6 * vel) * (1 - np.exp(-t / 0.018)) * (0.6 + 0.4 * np.exp(-t / 0.15))
    x = S.fm(f * vib, n, 1.0, idx) + 0.5 * S.fm(f * vib * 1.0035, n, 1.0, idx * 0.85, mod_phase0=0.3)
    rng = _rng("brass", m)
    breath = S.bandpass(rng.standard_normal(n), min(2.2 * f, 8000), 2.0) * np.exp(-t / 0.04) * 0.08
    x = (x + breath) * S.adsr(n, 0.016, 0.15, 0.82, 0.1, dur)
    return S.lowpass(x, 7500, 2) * 0.7


@patch
def glass_lead(m: int, dur: float, vel: float = 0.85) -> np.ndarray:
    f = float(midi_hz(m))
    n = ns(dur + 0.35)
    t = tvec(n)
    vib = _vibrato(n, 5.0, 0.004, 0.22, 0.3)
    x = S.fm(f * vib, n, 2.0, 0.9 * np.exp(-t / 0.25) + 0.35) + 0.18 * S.square(f * vib, n, 0.5)
    x += 0.25 * S.sine(f * 2 * vib, n)
    x = S.lowpass(x, 4500, 2)
    return x * S.adsr(n, 0.02, 0.3, 0.75, 0.3, dur) * vel


# --------------------------------------------------------------------------
# bass
# --------------------------------------------------------------------------

@patch
def synth_bass(m: int, dur: float, acc: float = 1.0, open_: float = 1.0) -> np.ndarray:
    f = float(midi_hz(m))
    n = ns(dur + 0.05)
    t = tvec(n)
    x = 0.55 * S.saw(f, n) + 0.3 * S.square(f * 1.004, n, 0.5) + 0.45 * S.sine(f, n)
    cut = 160 + 2300 * acc * open_ * np.exp(-t / 0.055) + 260 * open_
    x = S.svf(x, cut, 1.25)
    x = S.softclip(x * 1.6, 1.0)
    return x * S.adsr(n, 0.002, 0.09, 0.8, 0.035, dur * 0.9)


@patch
def soft_bass(m: int, dur: float) -> np.ndarray:
    f = float(midi_hz(m))
    n = ns(dur + 0.35)
    x = S.sine(f, n) + 0.22 * S.triangle(f, n) + 0.1 * S.sine(2 * f, n)
    x = S.lowpass(x, 900, 2)
    return x * S.adsr(n, 0.015, 0.4, 0.7, 0.3, dur)


@patch
def pulse_bass(m: int, dur: float, open_: float = 1.0) -> np.ndarray:
    f = float(midi_hz(m))
    n = ns(dur + 0.08)
    t = tvec(n)
    x = 0.8 * S.sine(f, n) + 0.35 * S.saw(f, n)
    x = S.svf(x, 180 + 900 * open_ * np.exp(-t / 0.06) + 150 * open_, 1.0)
    return x * S.adsr(n, 0.004, 0.12, 0.6, 0.05, dur * 0.85)


# --------------------------------------------------------------------------
# chords / pads
# --------------------------------------------------------------------------

@patch
def warm_pad(chord: tuple, dur: float, cutoff: float = 1300.0, attack: float = 0.7,
             release: float = 1.6, detune: float = 9.0) -> np.ndarray:
    n = ns(dur + release)
    t = tvec(n)
    out = np.zeros((n, 2))
    rng = _rng("pad", chord, cutoff)
    for m in chord:
        f = float(midi_hz(m))
        for k, (c, p) in enumerate(((-detune, -0.7), (0.0, 0.0), (detune, 0.7))):
            lfo = 1 + 0.0018 * np.sin(2 * math.pi * (0.23 + 0.07 * k) * t + rng.random() * 6)
            s = S.saw(f * 2 ** (c / 1200) * lfo, n, rng.random())
            th = (p + 1) * math.pi / 4
            out[:, 0] += s * math.cos(th)
            out[:, 1] += s * math.sin(th)
    out = S.fft_filter(out, lambda fr: S.H_lp(fr, cutoff, 2) * S.H_hp(fr, 120, 1))
    env = S.adsr(n, attack, 1.0, 0.85, release, dur, curve=1.5)
    return out * env[:, None] / math.sqrt(3 * len(chord))


@patch
def stab(chord: tuple, dur: float, bright: float = 1.0) -> np.ndarray:
    n = ns(dur + 0.12)
    t = tvec(n)
    x = np.zeros((n, 2))
    rng = _rng("stab", chord)
    for m in chord:
        x += S.supersaw(float(midi_hz(m)), n, 5, 16, rng, spread=0.9)
    cut = 500 + 5200 * bright * np.exp(-t / 0.075) + 400 * bright
    x = S.svf(x, cut, 1.1)
    env = S.adsr(n, 0.002, 0.12, 0.55, 0.08, dur)
    return x * env[:, None] / math.sqrt(len(chord))


@patch
def choir_pad(chord: tuple, dur: float) -> np.ndarray:
    n = ns(dur + 1.2)
    t = tvec(n)
    rng = _rng("choir", chord)
    out = np.zeros((n, 2))
    for i, m in enumerate(chord):
        for k in range(2):
            f = float(midi_hz(m)) * 2 ** ((k - 0.5) * 0.1 / 12) * \
                (1 + 0.005 * np.sin(2 * math.pi * (4.8 + 0.5 * k + 0.2 * i) * t + rng.random() * 6))
            s = S.saw(f, n, rng.random())
            out[:, k] += s
    def H(fr):
        h = 1.0 * S.H_bp(fr, 650, 5) + 0.6 * S.H_bp(fr, 1080, 6) + 0.28 * S.H_bp(fr, 2650, 8)
        return h * S.H_lp(fr, 5000, 2) + 0.05 * S.H_lp(fr, 450, 1)
    out = S.fft_filter(out, H)
    env = S.adsr(n, 0.5, 1.0, 0.85, 1.2, dur, curve=1.5)
    return out * env[:, None] / math.sqrt(2 * len(chord))


# --------------------------------------------------------------------------
# drums & percussion
# --------------------------------------------------------------------------

@patch
def kick(var: int = 0, punch: float = 1.0) -> np.ndarray:
    rng = _rng("kick", var)
    n = ns(0.5)
    t = tvec(n)
    f = 47 + 150 * punch * np.exp(-t / 0.032) + 40 * np.exp(-t / 0.006)
    body = S.sine(f, n) * S.expdec(n, 0.21, 0.0006)
    cl = S.highpass(rng.standard_normal(n), 2500, 2) * np.exp(-t / 0.0025) * 0.35
    blip = S.sine(2400.0, n) * np.exp(-t / 0.003) * 0.25
    x = body + cl + blip
    return S.softclip(x * 1.5, 1.0) * 0.95


@patch
def kick808(var: int = 0) -> np.ndarray:
    n = ns(0.95)
    t = tvec(n)
    f = 49 + 70 * np.exp(-t / 0.03)
    x = S.sine(f, n) * S.expdec(n, 0.38, 0.001)
    x += 0.15 * S.sine(f * 2, n) * np.exp(-t / 0.04)
    return S.softclip(x * 1.3, 1.0)


@patch
def soft_kick(var: int = 0) -> np.ndarray:
    n = ns(0.55)
    t = tvec(n)
    f = 52 + 60 * np.exp(-t / 0.02)
    x = S.sine(f, n) * S.expdec(n, 0.16, 0.002)
    return S.lowpass(x, 400, 2)


@patch
def snare(var: int = 0) -> np.ndarray:
    rng = _rng("snare", var)
    n = ns(0.35)
    t = tvec(n)
    body = S.sine(185 + 50 * np.exp(-t / 0.01), n) * np.exp(-t / 0.055)
    body += 0.5 * S.sine(330 + 40 * np.exp(-t / 0.01), n) * np.exp(-t / 0.035)
    nz = rng.standard_normal(n)
    nz = S.fft_filter(nz, lambda f: S.H_bp(f, 4200, 0.55) + 0.4 * S.H_hp(f, 7000, 2))
    nz *= np.exp(-t / 0.11) * np.clip(t / 0.0007, 0, 1)
    cl = S.highpass(rng.standard_normal(n), 3000, 2) * np.exp(-t / 0.002) * 0.4
    x = 0.8 * body + 0.6 * nz + cl
    return S.softclip(x * 1.4, 1.0)


@patch
def clap(var: int = 0) -> np.ndarray:
    rng = _rng("clap", var)
    n = ns(0.35)
    t = tvec(n)
    env = np.zeros(n)
    for k, d in enumerate((0.0, 0.009, 0.018, 0.028)):
        tt = t - d
        env += np.where(tt >= 0, np.exp(-np.maximum(tt, 0) / 0.0035), 0) * (0.8 if k < 3 else 1.0)
    env += np.where(t > 0.028, np.exp(-(t - 0.028) / 0.11), 0) * 0.55
    x = S.fft_filter(rng.standard_normal(n), lambda f: S.H_bp(f, 1350, 1.1) + 0.3 * S.H_bp(f, 3200, 1.0))
    return x * env


@patch
def hat(var: int = 0, open_: bool = False) -> np.ndarray:
    rng = _rng("hat", var, open_)
    n = ns(0.5 if open_ else 0.09)
    t = tvec(n)
    x = np.zeros(n)
    for fr in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0):
        x += S.square(fr * 1.7, n, 0.5, rng.random())
    x += 0.8 * rng.standard_normal(n)
    x = S.fft_filter(x, lambda f: S.H_bp(f, 9500, 0.9) * S.H_hp(f, 6500, 3))
    tau = 0.16 if open_ else 0.022
    env = np.exp(-t / tau) * np.clip(t / 0.0005, 0, 1)
    return x * env * 0.5


@patch
def crash(var: int = 0, dur: float = 2.4) -> np.ndarray:
    rng = _rng("crash", var)
    n = ns(dur)
    t = tvec(n)
    out = np.zeros((n, 2))
    for c in range(2):
        x = rng.standard_normal(n)
        for fr in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0):
            x += 0.5 * S.square(fr * 3.3 * (1 + 0.01 * c), n, 0.5, rng.random())
        x = S.fft_filter(x, lambda f: S.H_hp(f, 3200, 2) * (S.H_lp(f, 14000, 2)) * (1 + 0.6 * S.H_bp(f, 6000, 0.8)))
        env = (0.65 * np.exp(-t / 0.75) + 0.35 * np.exp(-t / 0.08)) * np.clip(t / 0.001, 0, 1)
        env *= np.clip((dur - t) / 0.2, 0, 1)
        out[:, c] = x * env
    return out * 0.35


@patch
def rev_cymbal(dur: float) -> np.ndarray:
    c = crash(3, dur + 0.05)
    x = c[::-1][: ns(dur)].copy()
    x *= np.linspace(0.0, 1.0, len(x))[:, None] ** 1.5
    return S.fade_edges(x, 0.002, 0.006)


@patch
def tom(freq: float, var: int = 0) -> np.ndarray:
    rng = _rng("tom", freq, var)
    n = ns(0.6)
    t = tvec(n)
    x = S.sine(freq * (1 + 0.45 * np.exp(-t / 0.04)), n) * np.exp(-t / 0.2)
    x += 0.35 * S.bandpass(rng.standard_normal(n), freq * 3.5, 1.0) * np.exp(-t / 0.03)
    return S.softclip(x * 1.3, 1.0)


@patch
def shaker(var: int = 0) -> np.ndarray:
    rng = _rng("shaker", var)
    n = ns(0.12)
    t = tvec(n)
    env = np.exp(-t / 0.02) * np.clip(t / 0.006, 0, 1) + 0.5 * np.exp(-np.maximum(t - 0.03, 0) / 0.015) * (t > 0.03)
    x = S.fft_filter(rng.standard_normal(n), lambda f: S.H_bp(f, 7500, 1.2) * S.H_hp(f, 4000, 2))
    return x * env * 0.6


@patch
def rim(var: int = 0) -> np.ndarray:
    rng = _rng("rim", var)
    n = ns(0.08)
    t = tvec(n)
    x = S.sine(1750.0, n) * np.exp(-t / 0.012) + 0.6 * S.sine(520.0, n) * np.exp(-t / 0.02)
    x += S.highpass(rng.standard_normal(n), 3000, 2) * np.exp(-t / 0.002) * 0.5
    return x * 0.8


@patch
def snap(var: int = 0) -> np.ndarray:
    rng = _rng("snap", var)
    n = ns(0.16)
    t = tvec(n)
    x = S.bandpass(rng.standard_normal(n), 2100, 1.3) * (np.exp(-t / 0.018) + 0.3 * np.exp(-t / 0.06))
    x += 0.4 * S.sine(900, n) * np.exp(-t / 0.01)
    return x


@patch
def timpani(m: int, var: int = 0) -> np.ndarray:
    f = float(midi_hz(m))
    rng = _rng("timp", m, var)
    n = ns(2.0)
    t = tvec(n)
    x = np.zeros(n)
    for r, a, d in ((1.0, 1.0, 0.9), (1.5, 0.45, 0.6), (1.99, 0.25, 0.4), (2.44, 0.12, 0.3)):
        x += a * S.sine(f * r * (1 + 0.04 * np.exp(-t / 0.03)), n, rng.random()) * np.exp(-t / d)
    x += 0.3 * S.lowpass(rng.standard_normal(n), 800, 2) * np.exp(-t / 0.03)
    return S.softclip(x * np.clip(t / 0.002, 0, 1) * 1.2, 1.0)


@patch
def riser(dur: float, f0: float = 300.0, f1: float = 9000.0) -> np.ndarray:
    n = ns(dur)
    out = np.zeros((n, 2))
    T = dur

    def mag(t, f):
        u = np.clip(t / T, 0, 1)
        fc = f0 * (f1 / f0) ** u
        return S.H_bp(f, fc, 1.6) * (0.15 + 0.85 * u ** 2)

    for c in range(2):
        out[:, c] = S.shaped_noise(n, _rng("riser", dur, c), mag)
    t = tvec(n)
    sw = S.saw(110 * (8.0 ** (t / T)), n) * (t / T) ** 2 * 0.12
    sw = S.lowpass(sw, 5000, 1)
    out += sw[:, None]
    return S.fade_edges(out, 0.01, 0.01)


@patch
def impact() -> np.ndarray:
    n = ns(1.8)
    t = tvec(n)
    x = S.sine(58 * (1 + 0.8 * np.exp(-t / 0.05)), n) * np.exp(-t / 0.55)
    rng = _rng("impact")
    x += 0.4 * S.lowpass(rng.standard_normal(n), 300, 2) * np.exp(-t / 0.3)
    return S.softclip(x * 1.2, 1.0) * np.clip(t / 0.001, 0, 1)

"""Shared DSP toolkit for the Céu Arcano audio pipeline (numpy only).

Everything here is deterministic: random sources always take an explicit
``numpy.random.Generator``.  Signals are float64 numpy arrays, mono ``(n,)``
or stereo ``(n, 2)``.
"""
from __future__ import annotations

import math
import os
import subprocess
import wave
import zlib

import numpy as np

SR = 44100
TWO_PI = 2.0 * math.pi


# --------------------------------------------------------------------------
# basic helpers
# --------------------------------------------------------------------------

def seed_for(name: str) -> int:
    return zlib.crc32(name.encode("utf-8")) & 0xFFFFFFFF


def rng_for(name: str) -> np.random.Generator:
    return np.random.default_rng(seed_for(name))


def db(x):
    return 10.0 ** (np.asarray(x, dtype=float) / 20.0)


def to_db(x, floor=1e-12):
    return 20.0 * np.log10(np.maximum(np.abs(x), floor))


def ns(sec: float) -> int:
    return max(0, int(round(sec * SR)))


def tvec(n: int) -> np.ndarray:
    return np.arange(n) / SR


def midi_hz(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=float) - 69.0) / 12.0)


_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note(name: str) -> int:
    """'C#4' -> 61, 'Bb3' -> 58, 'E5' -> 76."""
    name = name.strip()
    pc = _PC[name[0].upper()]
    i = 1
    while i < len(name) and name[i] in "#b":
        pc += 1 if name[i] == "#" else -1
        i += 1
    octave = int(name[i:])
    return 12 * (octave + 1) + pc


def fast_len(n: int) -> int:
    """Smallest 2^a 3^b 5^c >= n (fast FFT size)."""
    best = 1 << (max(1, n - 1)).bit_length()
    f5 = 1
    while f5 < best:
        f35 = f5
        while f35 < best:
            v = f35
            while v < n:
                v *= 2
            best = min(best, v)
            f35 *= 3
        f5 *= 5
    return best


def pad_to(x: np.ndarray, n: int) -> np.ndarray:
    if len(x) >= n:
        return x[:n]
    pad = [(0, n - len(x))] + [(0, 0)] * (x.ndim - 1)
    return np.pad(x, pad)


def mix_into(dst: np.ndarray, src: np.ndarray, start: int, gain: float = 1.0):
    """Add ``src`` into ``dst`` starting at sample ``start`` (clipped to bounds)."""
    if start >= len(dst):
        return
    s0 = 0
    if start < 0:
        s0 = -start
        start = 0
    end = min(len(dst), start + len(src) - s0)
    if end <= start:
        return
    dst[start:end] += gain * src[s0:s0 + end - start]


def mono(x: np.ndarray) -> np.ndarray:
    return x.mean(axis=1) if x.ndim == 2 else x


def pan(x: np.ndarray, p: float) -> np.ndarray:
    """Constant-power pan of a mono signal (p in [-1, 1]); stereo input is balanced."""
    th = (np.clip(p, -1, 1) + 1.0) * math.pi / 4.0
    gl, gr = math.cos(th) * math.sqrt(2), math.sin(th) * math.sqrt(2)
    if x.ndim == 1:
        return np.stack([x * gl * 0.7071, x * gr * 0.7071], axis=1)
    out = x.copy()
    out[:, 0] *= min(1.0, gl)
    out[:, 1] *= min(1.0, gr)
    return out


# --------------------------------------------------------------------------
# oscillators
# --------------------------------------------------------------------------

def phase(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    """Phase in cycles for a scalar or per-sample frequency."""
    if np.isscalar(freq):
        return phase0 + np.arange(n) * (float(freq) / SR)
    f = np.asarray(freq, dtype=float)[:n]
    ph = np.cumsum(f) / SR
    return phase0 + ph - f[0] / SR


def sine(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    return np.sin(TWO_PI * phase(freq, n, phase0))


def _polyblep(t: np.ndarray, dt: np.ndarray) -> np.ndarray:
    out = np.zeros_like(t)
    m = t < dt
    if np.any(m):
        x = t[m] / dt[m]
        out[m] = x + x - x * x - 1.0
    m = t > 1.0 - dt
    if np.any(m):
        x = (t[m] - 1.0) / dt[m]
        out[m] = x * x + x + x + 1.0
    return out


def _dt(freq, n: int) -> np.ndarray:
    if np.isscalar(freq):
        return np.full(n, min(max(abs(float(freq)) / SR, 1e-9), 0.5))
    return np.clip(np.abs(np.asarray(freq, dtype=float)[:n]) / SR, 1e-9, 0.5)


def saw(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    """Band-limited (polyBLEP) sawtooth."""
    t = phase(freq, n, phase0) % 1.0
    return 2.0 * t - 1.0 - _polyblep(t, _dt(freq, n))


def square(freq, n: int, pw: float = 0.5, phase0: float = 0.0) -> np.ndarray:
    """Band-limited (polyBLEP) pulse wave (DC removed)."""
    t = phase(freq, n, phase0) % 1.0
    dt = _dt(freq, n)
    s = np.where(t < pw, 1.0, -1.0)
    s = s + _polyblep(t, dt) - _polyblep((t - pw) % 1.0, dt)
    return s - (2 * pw - 1)


def triangle(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    t = phase(freq, n, phase0 + 0.25) % 1.0
    return 2.0 * np.abs(2.0 * t - 1.0) - 1.0


def additive(freq, n: int, partials, phase0=None, rng=None) -> np.ndarray:
    """Sum of sine partials.

    partials: iterable of (ratio, amp, decay_sec or None). Partials above
    Nyquist are skipped.
    """
    out = np.zeros(n)
    t = tvec(n)
    f0 = float(freq) if np.isscalar(freq) else None
    for k, (ratio, amp, dec) in enumerate(partials):
        fk = (f0 * ratio) if f0 is not None else np.asarray(freq) * ratio
        if np.max(fk) >= SR * 0.45:
            continue
        p0 = 0.0 if rng is None else rng.random()
        s = sine(fk, n, p0) * amp
        if dec is not None:
            s *= np.exp(-t / dec)
        out += s
    return out


def supersaw(freq, n: int, voices: int = 7, detune: float = 18.0, rng=None,
             spread: float = 0.85, center_gain: float = 1.0) -> np.ndarray:
    """Stereo detuned saw stack. ``detune`` is the outer voice offset in cents."""
    rng = rng or np.random.default_rng(1)
    out = np.zeros((n, 2))
    offs = np.linspace(-1.0, 1.0, voices)
    offs = np.sign(offs) * np.abs(offs) ** 1.3 * detune
    pans = np.linspace(-spread, spread, voices)
    order = rng.permutation(voices)
    pans = pans[order]
    for i in range(voices):
        f = np.asarray(freq, dtype=float) * 2.0 ** (offs[i] / 1200.0)
        s = saw(f if not np.isscalar(freq) else float(f), n, rng.random())
        g = center_gain if abs(offs[i]) < 1e-6 else 1.0
        th = (pans[i] + 1.0) * math.pi / 4.0
        out[:, 0] += s * g * math.cos(th)
        out[:, 1] += s * g * math.sin(th)
    return out * (1.2 / math.sqrt(voices))


def fm(freq, n: int, ratio: float, index, fb: float = 0.0, phase0=0.0, mod_phase0=0.0) -> np.ndarray:
    """Two-operator phase modulation: sin(wc t + I(t) sin(wm t))."""
    pm = phase(np.asarray(freq) * ratio if not np.isscalar(freq) else freq * ratio, n, mod_phase0)
    mod = np.sin(TWO_PI * pm)
    if fb:
        mod = np.sin(TWO_PI * pm + fb * mod)
    pc = phase(freq, n, phase0)
    return np.sin(TWO_PI * pc + np.asarray(index) * mod)


def noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n) * 0.5


# --------------------------------------------------------------------------
# envelopes
# --------------------------------------------------------------------------

def adsr(n: int, a: float, d: float, s: float, r: float, gate: float, curve: float = 1.0) -> np.ndarray:
    """ADSR envelope of length n samples. Times in seconds; ``gate`` = note-on length."""
    t = tvec(n)
    a = max(a, 1e-4)
    env = np.empty(n)
    att = t < a
    env[att] = (t[att] / a) ** curve
    tau_d = max(d, 1e-4) / 4.0
    dec = ~att
    env[dec] = s + (1.0 - s) * np.exp(-(t[dec] - a) / tau_d)
    # level at gate
    if gate < a:
        lg = (gate / a) ** curve
    else:
        lg = s + (1.0 - s) * math.exp(-(gate - a) / tau_d)
    rel = t >= gate
    tau_r = max(r, 1e-4) / 5.0
    env[rel] = lg * np.exp(-(t[rel] - gate) / tau_r)
    # hard end with tiny fade
    end = gate + r
    fade = np.clip((end - t) / 0.004, 0.0, 1.0)
    return env * fade


def expdec(n: int, tau: float, attack: float = 0.001) -> np.ndarray:
    t = tvec(n)
    e = np.exp(-t / max(tau, 1e-5))
    if attack > 0:
        e *= np.clip(t / attack, 0.0, 1.0)
    return e


def env_pts(n: int, pts, kind: str = "lin") -> np.ndarray:
    """Breakpoint envelope. pts = [(time_sec, value), ...]."""
    tt = np.array([p[0] for p in pts], dtype=float)
    vv = np.array([p[1] for p in pts], dtype=float)
    t = tvec(n)
    if kind == "exp":
        lv = np.log(np.maximum(vv, 1e-6))
        return np.exp(np.interp(t, tt, lv))
    return np.interp(t, tt, vv)


def sweep(n: int, f0: float, f1: float, kind: str = "exp", shape: float = 1.0) -> np.ndarray:
    """Frequency trajectory from f0 to f1 over n samples."""
    x = np.linspace(0.0, 1.0, n) ** shape
    if kind == "exp":
        return f0 * (f1 / f0) ** x
    return f0 + (f1 - f0) * x


def fade_edges(x: np.ndarray, fin: float = 0.001, fout: float = 0.005) -> np.ndarray:
    x = x.copy()
    n = len(x)
    a, b = min(n, ns(fin)), min(n, ns(fout))
    if a > 0:
        r = np.sin(np.linspace(0, math.pi / 2, a)) ** 2
        x[:a] *= r if x.ndim == 1 else r[:, None]
    if b > 0:
        r = np.cos(np.linspace(0, math.pi / 2, b)) ** 2
        x[n - b:] *= r if x.ndim == 1 else r[:, None]
    return x


# --------------------------------------------------------------------------
# filters
# --------------------------------------------------------------------------

def svf(x: np.ndarray, cutoff, q: float = 0.707, mode: str = "lp") -> np.ndarray:
    """Topology-preserving state-variable filter (Zavalishin) with per-sample cutoff.

    ``mode`` in {'lp', 'bp', 'hp', 'notch'}. Works on mono or stereo input.
    """
    if x.ndim == 2:
        return np.stack([svf(x[:, c], cutoff, q, mode) for c in range(x.shape[1])], axis=1)
    n = len(x)
    k = 1.0 / max(q, 0.05)
    if np.isscalar(cutoff):
        g = math.tan(math.pi * min(max(cutoff, 10.0), SR * 0.45) / SR)
        a1 = 1.0 / (1.0 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
        xs = x.tolist()
        lo = [0.0] * n
        bp = [0.0] * n
        ic1 = ic2 = 0.0
        for i in range(n):
            v3 = xs[i] - ic2
            v1 = a1 * ic1 + a2 * v3
            v2 = ic2 + a2 * ic1 + a3 * v3
            ic1 = 2.0 * v1 - ic1
            ic2 = 2.0 * v2 - ic2
            lo[i] = v2
            bp[i] = v1
    else:
        fc = np.clip(np.asarray(cutoff, dtype=float)[:n], 10.0, SR * 0.45)
        g = np.tan(np.pi * fc / SR)
        A1 = 1.0 / (1.0 + g * (g + k))
        A2 = g * A1
        A3 = g * A2
        A1, A2, A3 = A1.tolist(), A2.tolist(), A3.tolist()
        xs = x.tolist()
        lo = [0.0] * n
        bp = [0.0] * n
        ic1 = ic2 = 0.0
        for i in range(n):
            a2 = A2[i]
            v3 = xs[i] - ic2
            v1 = A1[i] * ic1 + a2 * v3
            v2 = ic2 + a2 * ic1 + A3[i] * v3
            ic1 = 2.0 * v1 - ic1
            ic2 = 2.0 * v2 - ic2
            lo[i] = v2
            bp[i] = v1
    lo = np.asarray(lo)
    bp = np.asarray(bp)
    if mode == "lp":
        return lo
    if mode == "bp":
        return bp * k  # unity gain at centre
    if mode == "hp":
        return x - k * bp - lo
    if mode == "notch":
        return x - k * bp
    raise ValueError(mode)


def onepole_lp(x: np.ndarray, fc: float) -> np.ndarray:
    """Causal one-pole low-pass (per-sample loop, use for short signals)."""
    if x.ndim == 2:
        return np.stack([onepole_lp(x[:, c], fc) for c in range(x.shape[1])], axis=1)
    a = math.exp(-TWO_PI * fc / SR)
    b = 1.0 - a
    xs = x.tolist()
    out = [0.0] * len(xs)
    y = 0.0
    for i, v in enumerate(xs):
        y = b * v + a * y
        out[i] = y
    return np.asarray(out)


# magnitude responses for FFT (zero-phase) filtering --------------------------

def H_lp(f, fc, order=2):
    return 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def H_hp(f, fc, order=2):
    with np.errstate(divide="ignore"):
        r = np.where(f > 0, fc / np.maximum(f, 1e-9), 1e9)
    return 1.0 / np.sqrt(1.0 + r ** (2 * order))


def H_bp(f, fc, q=1.0):
    """2nd-order band-pass magnitude (peak 1 at fc)."""
    x = np.maximum(f, 1e-9) / fc
    return 1.0 / np.sqrt(1.0 + (q * (x - 1.0 / x)) ** 2)


def H_reslp(f, fc, q=0.707):
    x = f / fc
    return 1.0 / np.sqrt((1.0 - x * x) ** 2 + (x / q) ** 2)


def H_shelf(f, fc, gain_db, high=True, slope=1.0):
    """Smooth shelf (logistic in log-frequency)."""
    g = db(gain_db)
    x = np.log2(np.maximum(f, 1e-3) / fc) * 2.5 * slope
    s = 1.0 / (1.0 + np.exp(-x)) if high else 1.0 / (1.0 + np.exp(x))
    return 1.0 + (g - 1.0) * s


def H_peak(f, fc, gain_db, q=1.0):
    g = db(gain_db)
    return 1.0 + (g - 1.0) * H_bp(f, fc, q) ** 2


def fft_filter(x: np.ndarray, H, pad: float = 0.25, circular: bool = False) -> np.ndarray:
    """Zero-phase filtering by multiplying the spectrum with ``H(freqs)``.

    ``circular=True`` treats ``x`` as periodic (used on music loops so the
    filtered loop is still seamless).
    """
    n = len(x)
    N = n if circular else fast_len(n + ns(pad))
    X = np.fft.rfft(x, N, axis=0)
    f = np.fft.rfftfreq(N, 1.0 / SR)
    h = H(f)
    Y = X * (h[:, None] if x.ndim == 2 else h)
    return np.fft.irfft(Y, N, axis=0)[:n]


def lowpass(x, fc, order=2, **kw):
    return fft_filter(x, lambda f: H_lp(f, fc, order), **kw)


def highpass(x, fc, order=2, **kw):
    return fft_filter(x, lambda f: H_hp(f, fc, order), **kw)


def bandpass(x, fc, q=1.0, **kw):
    return fft_filter(x, lambda f: H_bp(f, fc, q), **kw)


def shaped_noise(n: int, rng: np.random.Generator, mag, nfft: int = 1024, hop: int = 256) -> np.ndarray:
    """Noise with a time-varying spectrum, built by random-phase overlap-add.

    ``mag(t, f)`` receives frame times (frames, 1) and bin freqs (1, bins) and
    returns magnitudes (frames, bins).
    """
    frames = n // hop + nfft // hop + 2
    t = ((np.arange(frames) * hop) / SR)[:, None]
    f = np.fft.rfftfreq(nfft, 1.0 / SR)[None, :]
    M = np.broadcast_to(mag(np.maximum(t, 0.0), f), (frames, f.shape[1]))
    ph = rng.uniform(0, TWO_PI, M.shape)
    spec = M * np.exp(1j * ph)
    spec[:, 0] = 0.0
    fr = np.fft.irfft(spec, nfft, axis=1)
    win = np.hanning(nfft)
    fr *= win[None, :]
    out = np.zeros(frames * hop + nfft)
    for i in range(frames):
        out[i * hop:i * hop + nfft] += fr[i]
    norm = np.sum(win ** 2) / hop
    out = out[nfft // 2: nfft // 2 + n] / math.sqrt(norm) * math.sqrt(nfft) * 0.5
    return out


# --------------------------------------------------------------------------
# dynamics / distortion
# --------------------------------------------------------------------------

def softclip(x, drive=1.0):
    return np.tanh(x * drive) / math.tanh(drive) if drive > 0 else x


def compressor(x: np.ndarray, thresh_db=-18.0, ratio=3.0, attack=0.01, release=0.15,
               knee=6.0, makeup_db=0.0, block=64, detector=None) -> np.ndarray:
    """Feed-forward RMS compressor with soft knee (block-rate gain computer)."""
    det = x if detector is None else detector
    d = np.abs(det).max(axis=1) if det.ndim == 2 else np.abs(det)
    n = len(d)
    nb = (n + block - 1) // block
    dp = pad_to(d, nb * block).reshape(nb, block)
    lvl = to_db(np.sqrt(np.mean(dp ** 2, axis=1)) * 1.41)
    over = lvl - thresh_db
    gr = np.where(over <= -knee / 2, 0.0,
                  np.where(over >= knee / 2, over * (1 - 1 / ratio),
                           (1 - 1 / ratio) * (over + knee / 2) ** 2 / (2 * knee)))
    dtb = block / SR
    ca = math.exp(-dtb / max(attack, 1e-4))
    cr = math.exp(-dtb / max(release, 1e-4))
    g = gr.tolist()
    sm = [0.0] * nb
    s = 0.0
    for i in range(nb):
        v = g[i]
        c = ca if v > s else cr
        s = c * s + (1 - c) * v
        sm[i] = s
    sm = np.asarray(sm)
    centers = (np.arange(nb) + 0.5) * block
    gain = db(makeup_db - np.interp(np.arange(n), centers, sm))
    return x * (gain[:, None] if x.ndim == 2 else gain)


def limiter(x: np.ndarray, ceiling_db=-1.5, release=0.08, attack_ms=2.5, block=32) -> np.ndarray:
    """Look-ahead brick-wall limiter. Guarantees |y| <= ceiling."""
    ceil = float(db(ceiling_db))
    pk = np.abs(x).max(axis=1) if x.ndim == 2 else np.abs(x)
    n = len(pk)
    req = np.minimum(1.0, ceil / np.maximum(pk, 1e-12))
    nb = (n + block - 1) // block
    gb = pad_to(req, nb * block)
    gb[n:] = 1.0
    gb = gb.reshape(nb, block).min(axis=1)
    cr = math.exp(-(block / SR) / max(release, 1e-4))
    gl = gb.tolist()
    out = [1.0] * nb
    s = 1.0
    for i in range(nb):
        v = gl[i]
        s = 1.0 - cr * (1.0 - s)  # recover toward 1
        if v < s:
            s = v
        out[i] = s
    gs = np.asarray(out)
    W = max(2, int(attack_ms * SR / 1000))
    k = int(math.ceil(W / (2 * block))) + 1
    gm = gs.copy()
    for sh in range(1, k + 1):
        gm[sh:] = np.minimum(gm[sh:], gs[:-sh])
        gm[:-sh] = np.minimum(gm[:-sh], gs[sh:])
    g1 = np.repeat(gm, block)[:n]
    c = np.cumsum(np.concatenate([[0.0], np.pad(g1, (W // 2, W - W // 2), mode="edge")]))
    g2 = (c[W:W + n] - c[:n]) / W
    g2 = np.minimum(g2, 1.0)
    y = x * (g2[:, None] if x.ndim == 2 else g2)
    return np.clip(y, -ceil, ceil)


def cyclic(fn, x: np.ndarray, pre: float = 2.0, post: float = 0.05, **kw) -> np.ndarray:
    """Run a stateful processor on a loop so its state wraps around the seam."""
    n = len(x)
    P, Q = min(n, ns(pre)), min(n, ns(post))
    z = np.concatenate([x[n - P:], x, x[:Q]], axis=0)
    return fn(z, **kw)[P:P + n]


# --------------------------------------------------------------------------
# time-based effects
# --------------------------------------------------------------------------

def _hadamard(n):
    h = np.array([[1.0]])
    while h.shape[0] < n:
        h = np.block([[h, h], [h, -h]])
    return h / math.sqrt(n)


def fdn_reverb(x: np.ndarray, t60: float = 2.2, damp: float = 0.25, size: float = 1.0,
               predelay: float = 0.015, tail: float = 0.0, lowcut: float = 150.0,
               highcut: float = 9000.0, er: float = 0.35, seed: int = 7) -> np.ndarray:
    """16-line feedback delay network reverb (block-vectorised) with early reflections.

    Returns a wet-only stereo signal of length len(x) + tail seconds.
    """
    rng = np.random.default_rng(seed)
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    n_out = len(x) + ns(tail)
    xin = pad_to(x, n_out)
    xin = fft_filter(xin, lambda f: H_hp(f, lowcut, 1) * H_lp(f, highcut, 2))
    pd = ns(predelay)
    if pd:
        xin = np.concatenate([np.zeros((pd, 2)), xin[:n_out - pd]], axis=0)
    N = 16
    base_ms = np.array([31.1, 33.7, 36.3, 39.1, 41.9, 44.3, 47.9, 50.3,
                        53.9, 57.7, 61.3, 64.9, 69.1, 73.3, 77.9, 83.1])
    D = np.round(base_ms * size * SR / 1000).astype(np.int64)
    D = D + (D % 2 == 0)  # odd lengths
    B = int(D.min()) - 2
    A = _hadamard(N)
    g = 10.0 ** (-3.0 * D / (t60 * SR))
    dl = np.clip(damp * (D / D.mean()), 0.0, 0.49)
    bL = rng.choice([-1.0, 1.0], N) / math.sqrt(N)
    bR = rng.choice([-1.0, 1.0], N) / math.sqrt(N)
    cL = rng.choice([-1.0, 1.0], N) / math.sqrt(N) * 1.6
    cR = rng.choice([-1.0, 1.0], N) / math.sqrt(N) * 1.6
    Lbuf = 1 << int(D.max() + B + 8).bit_length()
    mask = Lbuf - 1
    s = np.zeros((N, Lbuf))
    rows = np.arange(N)[:, None]
    yL = np.zeros(n_out)
    yR = np.zeros(n_out)
    inL, inR = xin[:, 0], xin[:, 1]
    Dc = D[:, None]
    gcol = g[:, None]
    dcol = dl[:, None]
    ar = np.arange(B)
    for start in range(0, n_out, B):
        blk = min(B, n_out - start)
        idx = start + ar[:blk]
        pos = (idx[None, :] - Dc) & mask
        o = s[rows, pos]
        op = s[rows, (pos - 1) & mask]
        damped = ((1.0 - dcol) * o + dcol * op) * gcol
        fb = A @ damped
        s[:, idx & mask] = fb + bL[:, None] * inL[idx][None, :] + bR[:, None] * inR[idx][None, :]
        yL[idx] = cL @ o
        yR[idx] = cR @ o
    wet = np.stack([yL, yR], axis=1)
    if er > 0:
        taps = rng.uniform(0.006, 0.055, (2, 10)) * size
        gains = np.linspace(1.0, 0.35, 10) * er / math.sqrt(10) * 1.8
        for c in range(2):
            for k in range(10):
                d = ns(taps[c, k])
                sgn = 1.0 if (k + c) % 3 else -1.0
                wet[d:, c] += sgn * gains[k] * xin[:n_out - d, (c + k) % 2]
    return wet


def pingpong_delay(x: np.ndarray, delay: float, feedback: float = 0.35, lp: float = 5000.0,
                   hp: float = 250.0, width: float = 1.0) -> np.ndarray:
    """Frequency-domain ping-pong delay (exact IIR, circular). Returns wet-only stereo."""
    m = mono(x) if x.ndim == 2 else x
    n = len(m)
    X = np.fft.rfft(m)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    D = delay * SR
    h = H_lp(f, lp, 1) * H_hp(f, hp, 1) * np.exp(-2j * math.pi * f * D / SR)
    a = feedback * h
    den = 1.0 - a * a
    L = np.fft.irfft(X * h / den, n)
    R = np.fft.irfft(X * h * a / den, n)
    mid = 0.5 * (L + R)
    L = mid + width * (L - mid)
    R = mid + width * (R - mid)
    return np.stack([L, R], axis=1)


# --------------------------------------------------------------------------
# loudness (ITU-R BS.1770 / EBU R128 integrated)
# --------------------------------------------------------------------------

def _biquad_mag(f, b, a):
    w = 2 * math.pi * f / SR
    z1 = np.exp(-1j * w)
    z2 = z1 * z1
    return np.abs((b[0] + b[1] * z1 + b[2] * z2) / (a[0] + a[1] * z1 + a[2] * z2))


def _kweight_H(f):
    """K-weighting magnitude (libebur128 sample-rate independent design)."""
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = math.tan(math.pi * f0 / SR)
    Vh = 10.0 ** (G / 20.0)
    Vb = Vh ** 0.4996667741545416
    a0 = 1.0 + K / Q + K * K
    b1 = [(Vh + Vb * K / Q + K * K) / a0, 2.0 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a1 = [1.0, 2.0 * (K * K - 1.0) / a0, (1.0 - K / Q + K * K) / a0]
    f0, Q = 38.13547087613982, 0.5003270373253953
    K = math.tan(math.pi * f0 / SR)
    d = 1.0 + K / Q + K * K
    b2 = [1.0, -2.0, 1.0]
    a2 = [1.0, 2.0 * (K * K - 1.0) / d, (1.0 - K / Q + K * K) / d]
    return _biquad_mag(f, b1, a1) * _biquad_mag(f, b2, a2)


def lufs(x: np.ndarray) -> float:
    if x.ndim == 1:
        x = x[:, None]
    y = fft_filter(x, _kweight_H, pad=0.1)
    blk, hop = ns(0.4), ns(0.1)
    if len(y) < blk:
        y = pad_to(y, blk)
    nbk = 1 + (len(y) - blk) // hop
    sq = np.cumsum(np.concatenate([np.zeros((1, y.shape[1])), y ** 2]), axis=0)
    starts = np.arange(nbk) * hop
    z = (sq[starts + blk] - sq[starts]) / blk
    zs = z.sum(axis=1)
    lk = -0.691 + 10 * np.log10(np.maximum(zs, 1e-15))
    m = lk > -70
    if not np.any(m):
        return -100.0
    rel = -0.691 + 10 * math.log10(zs[m].mean()) - 10
    m2 = m & (lk > rel)
    return -0.691 + 10 * math.log10(zs[m2].mean())


def true_peak_db(x: np.ndarray, os_factor: int = 4) -> float:
    """Approximate true peak via FFT oversampling of overlapping chunks."""
    if x.ndim == 1:
        x = x[:, None]
    peak = float(np.abs(x).max())
    chunk, ov = 1 << 15, 256
    for s0 in range(0, len(x), chunk):
        a = max(0, s0 - ov)
        seg = x[a: s0 + chunk + ov]
        n = len(seg)
        if n < 8:
            continue
        y = np.fft.irfft(np.fft.rfft(seg, axis=0), n * os_factor, axis=0) * os_factor
        lo = (s0 - a) * os_factor
        hi = lo + min(chunk, len(x) - s0) * os_factor
        peak = max(peak, float(np.abs(y[lo:hi]).max()))
    return float(to_db(peak))


# --------------------------------------------------------------------------
# file io
# --------------------------------------------------------------------------

def write_wav(path: str, x: np.ndarray, sr: int = SR):
    x = np.asarray(x, dtype=float)
    if not np.all(np.isfinite(x)):
        raise ValueError(f"non-finite samples in {path}")
    ch = 1 if x.ndim == 1 else x.shape[1]
    q = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(q.tobytes())


def read_wav(path: str) -> tuple[np.ndarray, int]:
    with wave.open(path, "rb") as w:
        ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    assert sw == 2
    x = np.frombuffer(raw, dtype="<i2").astype(float) / 32768.0
    if ch > 1:
        x = x.reshape(-1, ch)
    return x, sr


_CODEC = None


def vorbis_codec() -> list[str]:
    global _CODEC
    if _CODEC is not None:
        return _CODEC
    try:
        out = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], capture_output=True, text=True).stdout
    except FileNotFoundError:
        raise RuntimeError("ffmpeg not found")
    if "libvorbis" in out:
        _CODEC = ["-c:a", "libvorbis", "-q:a", "6"]
    else:
        _CODEC = ["-c:a", "vorbis", "-strict", "-2", "-q:a", "6"]
    return _CODEC


def encode_ogg(wav_path: str, ogg_path: str):
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-fflags", "+bitexact", "-i", wav_path] + vorbis_codec() + \
          ["-ar", str(SR), "-map_metadata", "-1", "-flags:a", "+bitexact", "-fflags", "+bitexact", ogg_path]
    subprocess.run(cmd, check=True)


def decode_audio(path: str) -> np.ndarray:
    """Decode any file with ffmpeg to float (n, ch)."""
    probe = subprocess.run(["ffmpeg", "-hide_banner", "-i", path], capture_output=True, text=True).stderr
    ch = 2 if "stereo" in probe else 1
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", str(ch),
                          "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype="<f4").astype(float)
    return x.reshape(-1, ch) if ch > 1 else x


def ensure_dir(p: str):
    os.makedirs(p, exist_ok=True)

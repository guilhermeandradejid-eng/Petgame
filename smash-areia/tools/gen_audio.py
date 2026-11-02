"""Smash na Areia - design de som (v2).

    python3 tools/gen_audio.py        # precisa de numpy, scipy e ffmpeg (para .ogg)

Tudo é sintetizado com técnicas de design de som (síntese modal, granular,
formantes, Karplus-Strong, FM) e camadas de impactos gravados da Kenney
(CC0, em tools/kenney/). Cada efeito tem variações para não repetir, e há
reverb por convolução com respostas ao impulso sintéticas.

Saída:
  godot/assets/audio/sfx/*.wav     efeitos curtos, mono 44,1 kHz (tocados em 3D)
  godot/assets/audio/amb/*.ogg     torcida, mar e reações (estéreo)
  godot/assets/audio/music/*.ogg   música adaptativa em camadas (estéreo, em loop)
"""
import os
import subprocess
import wave

import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(ROOT, "..", "godot", "assets", "audio"))
KENNEY = os.path.join(ROOT, "kenney")
rng = np.random.default_rng(2026)


# ---------------------------------------------------------------- utilidades DSP

def T(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur, color="white"):
    n = rng.standard_normal(int(SR * dur))
    if color == "pink":
        b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
        a = [1, -2.494956002, 2.017265875, -0.522189400]
        n = signal.lfilter(b, a, n) * 4
    elif color == "brown":
        n = np.cumsum(n)
        n = n - signal.savgol_filter(n, 2001 if len(n) > 2001 else (len(n) // 2) * 2 - 1, 2)
        n /= np.max(np.abs(n)) + 1e-9
    return n


def sos(kind, f, order=2, q=None):
    nyq = SR / 2
    if kind == "bp":
        lo, hi = f
        return signal.butter(order, [lo / nyq, min(hi / nyq, 0.999)], btype="band", output="sos")
    return signal.butter(order, min(f / nyq, 0.999), btype=kind, output="sos")


def lp(x, f, order=2):
    return signal.sosfilt(sos("low", f, order), x)


def hp(x, f, order=2):
    return signal.sosfilt(sos("high", f, order), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(sos("bp", (lo, hi), order), x)


def peak(x, f, q):
    b, a = signal.iirpeak(f / (SR / 2), q)
    return signal.lfilter(b, a, x)


def env_exp(dur, decay, attack=0.001):
    t = T(dur)
    return np.clip(t / max(attack, 1e-5), 0, 1) * np.exp(-t / decay)


def env_adsr(dur, a, d, s, r):
    n = int(SR * dur)
    e = np.zeros(n)
    ia, idd, ir = int(SR * a), int(SR * d), int(SR * r)
    e[:ia] = np.linspace(0, 1, max(ia, 1))[:ia]
    e[ia:ia + idd] = np.linspace(1, s, max(idd, 1))[: len(e[ia:ia + idd])]
    e[ia + idd: n - ir] = s
    e[n - ir:] = np.linspace(s, 0, max(ir, 1))[: len(e[n - ir:])]
    return e


def pad(x, n):
    return np.pad(x, (0, max(0, n - len(x))))[:n] if x.ndim == 1 else np.pad(x, ((0, max(0, n - len(x))), (0, 0)))[:n]


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def place(buf, x, at):
    s = int(at * SR)
    if s >= len(buf):
        return
    e = min(len(buf), s + len(x))
    buf[s:e] += x[: e - s]


def sat(x, drive=2.0):
    return np.tanh(x * drive) / np.tanh(drive)


def modal(freqs, decays, amps, dur, detune=0.0):
    t = T(dur)
    out = np.zeros_like(t)
    for f, d, a in zip(freqs, decays, amps):
        f *= 1.0 + rng.uniform(-detune, detune)
        out += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / d)
    return out


def sweep_sine(f0, f1, dur, curve=3.0):
    t = T(dur)
    f = f1 + (f0 - f1) * np.exp(-t * curve / dur * 3)
    return np.sin(np.cumsum(2 * np.pi * f / SR))


def make_ir(dur, decay, stereo=True, brightness=6000, predelay=0.01):
    """Resposta ao impulso sintética (ruído decaindo + reflexões iniciais)."""
    n = int(SR * dur)
    chans = []
    for c in range(2 if stereo else 1):
        x = rng.standard_normal(n) * np.exp(-T(dur) / decay)
        x = lp(x, brightness)
        x[: int(predelay * SR)] = 0
        for k in range(6):   # reflexões iniciais
            d = int(SR * (predelay + rng.uniform(0.004, 0.035)))
            if d < n:
                x[d] += rng.uniform(0.3, 0.8) * (1 if rng.random() < 0.5 else -1)
        chans.append(x / np.sqrt(np.sum(x ** 2)))
    return np.stack(chans, axis=1) if stereo else chans[0]


IR_ROOM = make_ir(0.35, 0.06, stereo=False, brightness=3200)
IR_BEACH = make_ir(1.6, 0.35, stereo=True, brightness=5000, predelay=0.02)
IR_HALL = make_ir(2.6, 0.7, stereo=True, brightness=4000, predelay=0.03)


def reverb(x, ir, wet=0.2):
    if x.ndim == 1 and ir.ndim == 1:
        w = signal.fftconvolve(x, ir)[: len(x) + len(ir)]
        dry = pad(x, len(w))
        return dry * (1 - wet) + w * wet
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    if ir.ndim == 1:
        ir = np.stack([ir, ir], axis=1)
    w = np.stack([signal.fftconvolve(x[:, c], ir[:, c]) for c in range(2)], axis=1)
    dry = pad(x, len(w))
    return dry * (1 - wet) + w * wet


def fade(x, fin=0.002, fout=0.01):
    n = len(x)
    a, b = int(fin * SR), int(fout * SR)
    e = np.ones(n)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if b:
        e[n - b:] = np.linspace(1, 0, b)
    return x * (e if x.ndim == 1 else e[:, None])


def trim_silence(x, thresh=1e-4):
    mono = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=1)
    idx = np.where(mono > thresh * np.max(mono))[0]
    return x[: idx[-1] + 1] if len(idx) else x


def norm(x, db=-1.0):
    p = np.max(np.abs(x)) or 1.0
    return x / p * (10 ** (db / 20))


def load_ogg(name):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", os.path.join(KENNEY, name),
                          "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True).stdout
    x = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
    return x / (np.max(np.abs(x)) + 1e-9)


def save_wav(path, x, db=-1.0):
    x = fade(trim_silence(np.asarray(x, dtype=np.float64)), 0.0005, 0.008)
    x = norm(x, db)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1 if x.ndim == 1 else 2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def save_ogg(path, x, db=-1.0, q=5, loop=False, normalize=True):
    x = np.asarray(x, dtype=np.float64)
    if not loop:
        x = fade(trim_silence(x), 0.001, 0.05)
    if normalize:
        x = norm(x, db)
    tmp = path + ".tmp.wav"
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1 if x.ndim == 1 else 2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    os.remove(tmp)


def sfx(name, x, db=-1.0):
    save_wav(os.path.join(OUT, "sfx", name + ".wav"), x, db)
    print("  sfx", name, f"{len(x) / SR:.2f}s")


# ---------------------------------------------------------------- golpes

K_HIT = load_ogg("hit.ogg")
K_IMPACT = load_ogg("impact.ogg")
K_LAND = load_ogg("land.ogg")
K_KILL = load_ogg("kill.ogg")


def paddle(hardness=1.0, size=1.0, ball=1.0):
    """Raquete de beach tennis (pá de carbono/EVA) acertando a bola de borracha:
    clique do impacto + modos do quadro + 'pop' da bola."""
    dur = 0.35
    click = hp(noise(0.004), 2500) * env_exp(0.004, 0.0012)
    s = rng.uniform(0.94, 1.06) / size
    body = modal([410 * s, 930 * s, 1580 * s, 2470 * s, 3900 * s],
                 [0.055, 0.035, 0.022, 0.014, 0.008],
                 [1.0, 0.7, 0.45, 0.3, 0.15], dur, detune=0.03)
    ballpop = np.sin(np.cumsum(2 * np.pi * (230 * ball + 140 * np.exp(-T(dur) * 60)) / SR)) * env_exp(dur, 0.022)
    thump = lp(noise(dur), 600) * env_exp(dur, 0.012) * 0.6
    k = pad(K_HIT * rng.uniform(0.25, 0.4), int(SR * dur))
    x = mix(click * 1.4 * hardness, body * 0.55 * (0.6 + 0.4 * hardness), ballpop * 0.9, thump, k)
    x = sat(x * 1.2, 1.5)
    return reverb(x, IR_ROOM, 0.07)


def whoosh(dur=0.28, f0=500, f1=2600, f2=800, power=1.0):
    n = noise(dur, "pink")
    t = T(dur)
    k = t / dur
    fc = np.where(k < 0.55, f0 + (f1 - f0) * (k / 0.55) ** 1.4, f1 + (f2 - f1) * ((k - 0.55) / 0.45))
    out = np.zeros_like(n)
    # filtro passa-banda variando no tempo (em blocos)
    blk = 256
    zi = None
    for i in range(0, len(n), blk):
        c = float(fc[min(i, len(fc) - 1)])
        so = sos("bp", (c * 0.7, c * 1.4), 2)
        if zi is None or zi.shape != (so.shape[0], 2):
            zi = np.zeros((so.shape[0], 2))
        y, zi = signal.sosfilt(so, n[i:i + blk], zi=zi)
        out[i:i + blk] = y
    amp = np.sin(np.pi * np.clip(k, 0, 1)) ** 1.6
    tone = np.sin(np.cumsum(2 * np.pi * (fc * 0.5) / SR)) * 0.08
    return (out * 1.0 + tone) * amp * power


def build_hits():
    for i in range(4):
        sfx(f"hit_drive_{i}", paddle(1.0, 1.0, 1.0))
    for i in range(3):
        sfx(f"hit_lob_{i}", paddle(0.7, 1.08, 0.85) * 0.9, -2)
    for i in range(3):
        x = paddle(0.45, 1.15, 1.25)
        sfx(f"hit_drop_{i}", x, -4)
    for i in range(2):
        x = mix(paddle(0.6, 1.2, 0.7), lp(noise(0.2), 400) * env_exp(0.2, 0.03) * 0.8)
        sfx(f"hit_block_{i}", x, -2)
    for i in range(3):
        dur = 0.9
        crack = hp(noise(0.03), 1800) * env_exp(0.03, 0.006) * 1.5
        boom = sweep_sine(140, 48, dur, 2.5) * env_exp(dur, 0.16) * 1.2
        k = pad(K_IMPACT * 0.9, int(SR * dur))
        x = mix(paddle(1.4, 0.95, 1.1) * 1.3, crack, boom, k * 0.8)
        x = sat(x, 2.2)
        sfx(f"hit_smash_{i}", reverb(x, IR_BEACH[:, 0], 0.22))
    # super: riser + pancada gigante + cauda brilhante
    dur = 1.6
    riser = whoosh(0.55, 300, 5000, 5000, 1.0)
    boom = sweep_sine(110, 35, dur, 1.6) * env_exp(dur, 0.35) * 1.4
    crack = hp(noise(0.05), 1500) * env_exp(0.05, 0.01) * 1.6
    shimmer = sum(np.sin(2 * np.pi * f * T(dur)) * env_exp(dur, 0.5) * 0.08 for f in (1760, 2217, 2637, 3520))
    hitpart = mix(crack, boom, pad(K_IMPACT, int(SR * dur)), paddle(1.5, 0.9, 1.0) * 1.2, shimmer)
    x = np.zeros(int(SR * 2.3))
    place(x, riser, 0.0)
    place(x, sat(hitpart, 2.5), 0.5)
    sfx("hit_super", reverb(x, IR_HALL[:, 0], 0.3))
    # rajadas de ar da raquete
    for i in range(4):
        sfx(f"swing_{i}", whoosh(rng.uniform(0.22, 0.3), rng.uniform(400, 600), rng.uniform(2200, 3000), 900, 1.0), -6)
    sfx("swing_smash", whoosh(0.38, 300, 3800, 700, 1.0), -3)
    sfx("charge_full", mix(*[np.sin(2 * np.pi * f * T(0.5)) * env_exp(0.5, 0.15) * a
                             for f, a in ((1318.5, 0.6), (1975.5, 0.4), (2637, 0.25))]), -8)


# ---------------------------------------------------------------- areia, rede, corpo

def grains(dur, rate, f_lo, f_hi, amp_env, size=0.004):
    """Granular: milhares de grãozinhos de areia (cliques filtrados)."""
    out = np.zeros(int(SR * dur))
    n = int(rate * dur)
    g = hp(noise(size), 800) * np.hanning(int(SR * size))
    for _ in range(n):
        t0 = rng.uniform(0, dur)
        e = amp_env(t0 / dur)
        place(out, g * e * rng.uniform(0.3, 1.0), t0)
    return bp(out, f_lo, f_hi)


def build_sand():
    for i in range(6):
        dur = 0.22
        thud = lp(noise(dur), 300) * env_exp(dur, 0.035) * 1.2
        crunch = grains(dur, 900, 1500, 7000, lambda k: np.exp(-k * 5))
        sfx(f"step_{i}", mix(thud, crunch * 0.8), -10)
    for i in range(3):
        dur = 0.6
        thud = pad(K_LAND, int(SR * dur)) * 0.9
        spray = grains(dur, 1600, 1200, 8000, lambda k: np.exp(-k * 4))
        sfx(f"ball_sand_{i}", reverb(mix(thud, spray * 0.9, lp(noise(dur), 200) * env_exp(dur, 0.06)), IR_ROOM, 0.1))
    dur = 0.9
    slide = grains(dur, 3000, 600, 6000, lambda k: np.sin(np.pi * min(k * 1.6, 1.0)) * np.exp(-k * 1.5))
    sfx("dive", mix(slide, pad(K_LAND, int(SR * dur)) * 0.8, lp(noise(dur), 250) * env_exp(dur, 0.12) * 0.8))
    dur = 0.3
    sfx("jump", mix(grains(dur, 800, 1000, 6000, lambda k: np.exp(-k * 6)) * 0.7,
                    lp(noise(dur), 400) * env_exp(dur, 0.04) * 0.5), -9)
    dur = 0.35
    sfx("land", mix(pad(K_KILL, int(SR * dur)) * 0.6, grains(dur, 900, 1000, 6000, lambda k: np.exp(-k * 7))), -6)
    # rede: chicote da malha + corda grave + bola amortecida
    for i in range(2):
        dur = 0.9
        rattle = bp(noise(dur), 300, 2500) * env_exp(dur, 0.08)
        rattle = peak(rattle, 700, 4) * 0.5 + rattle
        rope = ks_string(rng.uniform(80, 95), dur, 0.996) * 0.9
        sfx(f"net_{i}", reverb(mix(rattle, rope, paddle(0.3, 1.3, 0.8) * 0.4), IR_ROOM, 0.15))


# ---------------------------------------------------------------- vozes, torcida, apito

FORMANTS = {"a": (800, 1150, 2900), "e": (400, 2000, 2550), "o": (450, 800, 2830),
            "u": (325, 700, 2530), "i": (300, 2300, 3000)}


def voice(dur, f0_curve, vowel="a", breath=0.25, jitter=0.02):
    """Voz sintética: pulsos glotais filtrados por formantes."""
    t = T(dur)
    f0 = f0_curve(t / dur) * (1 + jitter * lp(rng.standard_normal(len(t)), 8) * 5)
    ph = np.cumsum(f0 / SR)
    src = (ph % 1.0) * 2 - 1
    src = src - lp(src, 60)
    src += noise(dur) * breath
    out = np.zeros_like(t)
    for k, f in enumerate(FORMANTS[vowel]):
        f *= rng.uniform(0.92, 1.08)
        out += peak(src, f, 6 + k * 2) * (1.0, 0.6, 0.25)[k]
    return out


def babble(dur, n, excite=0.3, vowels="aeo"):
    out = np.zeros(int(SR * dur))
    for _ in range(n):
        d = rng.uniform(0.25, 0.9)
        base = rng.choice([110, 130, 165, 200, 230, 260]) * rng.uniform(0.9, 1.1)
        rise = rng.uniform(-0.1, 0.25 + excite)
        v = voice(d, lambda k, b=base, r=rise: b * (1 + r * np.sin(np.pi * k)), rng.choice(list(vowels)))
        place(out, v * env_adsr(d, 0.05, 0.1, 0.7, 0.2) * rng.uniform(0.2, 1.0), rng.uniform(0, dur - d))
    return out


def clap():
    d = rng.uniform(0.008, 0.02)
    c = bp(noise(d), rng.uniform(700, 1400), rng.uniform(2500, 5000)) * env_exp(d, d * 0.3, 0.0005)
    return c


CLAPS = [clap() for _ in range(24)]


def applause(dur, people, rate=6.0, swell=lambda k: 1.0):
    out = np.zeros(int(SR * dur))
    for p in range(people):
        r = rate * rng.uniform(0.7, 1.3)
        t = rng.uniform(0, 0.2)
        g = rng.uniform(0.3, 1.0)
        while t < dur:
            place(out, CLAPS[rng.integers(len(CLAPS))] * g * swell(t / dur), t)
            t += 1.0 / r * rng.uniform(0.85, 1.15)
    return out


def human_whistle(dur):
    t = T(dur)
    f = 1800 + 900 * np.sin(np.pi * t / dur) + 30 * np.sin(2 * np.pi * 6 * t)
    return np.sin(np.cumsum(2 * np.pi * f / SR)) * env_adsr(dur, 0.05, 0.1, 0.8, 0.2) * 0.3


def stereo_spread(mono_parts):
    """Distribui fontes mono num campo estéreo."""
    n = max(len(m) for m in mono_parts)
    out = np.zeros((n, 2))
    for m in mono_parts:
        pan = rng.uniform(-0.9, 0.9)
        out[: len(m), 0] += m * np.sqrt((1 - pan) / 2)
        out[: len(m), 1] += m * np.sqrt((1 + pan) / 2)
    return out


def amb(name, x, db=-1.0, loop=False):
    save_ogg(os.path.join(OUT, "amb", name + ".ogg"), x, db, loop=loop)
    print("  amb", name, f"{len(x) / SR:.2f}s")


def build_crowd():
    # leito da torcida (loop): murmúrio de muita gente + palmas esparsas + mar distante
    dur = 16.0
    parts = [lp(babble(dur, 70, 0.05), 2500) * 0.5 for _ in range(4)]
    parts.append(applause(dur, 6, 2.0) * 0.15)
    bed = stereo_spread(parts)
    bed = reverb(bed, IR_HALL, 0.45)[: int(SR * dur)]
    n = int(SR * 1.0)   # loop sem emenda: cruza o fim com o começo
    bed[:n] = bed[:n] * np.linspace(0, 1, n)[:, None] + bed[-n:] * np.linspace(1, 0, n)[:, None]
    bed = bed[:-n]
    amb("crowd_bed", bed, -6, loop=True)
    # comemorações
    for i in range(3):
        dur = 3.2
        sw = lambda k: np.clip(k * 8, 0, 1) * np.exp(-max(k - 0.25, 0) * 2.2)
        voices = [babble(dur, 60, 0.7, "aei") * np.array([sw(k) for k in np.linspace(0, 1, int(SR * dur))]) for _ in range(3)]
        claps = applause(dur, 40, 7.0, sw)
        wh = [human_whistle(rng.uniform(0.4, 0.8)) for _ in range(3)]
        pw = []
        for w in wh:
            b = np.zeros(int(SR * dur))
            place(b, w, rng.uniform(0.2, 1.4))
            pw.append(b)
        x = stereo_spread([v * 0.6 for v in voices] + [claps * 0.9, claps * 0.5] + pw)
        amb(f"cheer_{i}", reverb(x, IR_HALL, 0.35), -2)
    # "uhhh!" (lance perigoso) e "aaah..." (decepção)
    for i, vow in enumerate(["o", "u"]):
        dur = 1.8
        vs = []
        for _ in range(45):
            d = rng.uniform(1.0, 1.6)
            b = rng.choice([120, 150, 190, 230]) * rng.uniform(0.9, 1.1)
            v = voice(d, lambda k, b=b: b * (1.25 - 0.35 * k), vow)
            buf = np.zeros(int(SR * dur))
            place(buf, v * env_adsr(d, 0.12, 0.2, 0.8, 0.5) * rng.uniform(0.3, 1.0), rng.uniform(0, 0.15))
            vs.append(buf)
        amb(f"ooh_{i}", reverb(stereo_spread(vs), IR_HALL, 0.35), -3)
    dur = 2.0
    vs = []
    for _ in range(45):
        d = rng.uniform(1.2, 1.8)
        b = rng.choice([130, 160, 200]) * rng.uniform(0.9, 1.1)
        v = voice(d, lambda k, b=b: b * (1.1 - 0.4 * k), "a")
        buf = np.zeros(int(SR * dur))
        place(buf, v * env_adsr(d, 0.08, 0.2, 0.8, 0.6) * rng.uniform(0.3, 1.0), rng.uniform(0, 0.2))
        vs.append(buf)
    amb("aww", reverb(stereo_spread(vs), IR_HALL, 0.35), -4)
    dur = 4.5
    amb("applause", reverb(stereo_spread([applause(dur, 30, 6.5, lambda k: np.clip(k * 6, 0, 1) * np.exp(-max(k - 0.4, 0) * 2.5))
                                          for _ in range(2)]), IR_HALL, 0.3), -3)
    # mar (loop)
    dur = 12.0
    waves = []
    for c in range(2):
        w = lp(noise(dur, "pink"), 900) * 0.6 + hp(lp(noise(dur), 5000), 2500) * 0.15
        swell = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * T(dur) / 6.0 - 1.5 + c * 0.6)) ** 2
        waves.append(w * swell)
    sea = np.stack(waves, axis=1)
    n = int(SR * 1.0)
    sea[:n] = sea[:n] * np.linspace(0, 1, n)[:, None] + sea[-n:] * np.linspace(1, 0, n)[:, None]
    amb("sea", sea[:-n], -8, loop=True)


def pea_whistle(dur, short=True):
    """Apito de juiz com 'ervilha': portadora ~3 kHz com trinado irregular."""
    t = T(dur)
    trill = 40 + 8 * lp(rng.standard_normal(len(t)), 4) * 10
    fm = 140 * np.sign(np.sin(np.cumsum(2 * np.pi * trill / SR)))
    fm = lp(fm, 300)
    f = 2950 + fm
    ph = np.cumsum(2 * np.pi * f / SR)
    tone = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    breath = bp(noise(dur), 2000, 6000) * 0.18
    e = env_adsr(dur, 0.015, 0.05, 0.85, 0.06 if short else 0.15)
    return reverb((tone + breath) * e, IR_BEACH[:, 0], 0.2)


def build_misc():
    sfx("whistle", pea_whistle(0.45), -3)
    x = np.zeros(int(SR * 1.6))
    place(x, pea_whistle(0.35), 0)
    place(x, pea_whistle(0.9, False), 0.5)
    sfx("whistle_long", x, -3)
    # interface
    def tick(f, d=0.08, a=0.6):
        return mix(modal([f, f * 2.76, f * 5.4], [d * 0.6, d * 0.3, d * 0.15], [1, 0.4, 0.15], d * 2) * a,
                   hp(noise(0.003), 3000) * env_exp(0.003, 0.0008) * 0.3)
    sfx("ui_click", tick(1500), -8)
    sfx("ui_move", tick(1100, 0.05, 0.5), -12)
    x = np.zeros(int(SR * 0.9))
    for k, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        place(x, fm_bell(f, 0.6) * 0.5, k * 0.07)
    sfx("ui_start", reverb(x, IR_ROOM, 0.25), -4)
    # estrela de chance: brilho em arpejo
    x = np.zeros(int(SR * 0.8))
    for k, f in enumerate([1318.5, 1760, 2217.5]):
        place(x, fm_bell(f, 0.45) * 0.4, k * 0.05)
    sfx("chance", reverb(x, IR_ROOM, 0.3), -9)
    # super pronto
    dur = 1.0
    sh = sum(fm_bell(f, dur) * 0.2 for f in (880, 1318.5, 1760, 2637))
    sfx("super_ready", reverb(sh * env_adsr(dur, 0.2, 0.2, 0.6, 0.4), IR_HALL[:, 0], 0.4), -7)
    # empurrão do super
    dur = 0.6
    sfx("knock", mix(lp(noise(dur), 500) * env_exp(dur, 0.08), whoosh(0.4, 900, 300, 200, 0.8),
                     pad(K_KILL, int(SR * dur)) * 0.6), -4)


def fm_bell(f, dur, ratio=3.5, index=2.0):
    t = T(dur)
    mod = np.sin(2 * np.pi * f * ratio * t) * index * np.exp(-t * 6)
    return np.sin(2 * np.pi * f * t + mod) * np.exp(-t * 4.5)


# ---------------------------------------------------------------- música

def ks_string(f, dur, damp=0.995, bright=0.5):
    """Karplus-Strong: violão/cavaquinho dedilhado."""
    n = int(SR * dur)
    period = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, period)
    buf = lp(buf, 2000 + bright * 6000, 1) if period > 16 else buf
    out = np.zeros(n)
    idx = 0
    prev = 0.0
    for i in range(n):
        v = buf[idx]
        out[i] = v
        nv = damp * 0.5 * (v + prev)
        prev = v
        buf[idx] = nv
        idx = (idx + 1) % period
    return out


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def steelpan(f, dur):
    """Steel drum sintético: parciais quase harmônicas com decaimentos diferentes."""
    t = T(dur)
    f_t = f * (1 + 0.012 * np.exp(-t * 60))   # leve queda de afinação no ataque
    ph = 2 * np.pi * np.cumsum(f_t) / SR
    x = (np.sin(ph) * np.exp(-t * 3.2) + 0.55 * np.sin(2 * ph + 0.3) * np.exp(-t * 5.5)
         + 0.28 * np.sin(3.01 * ph) * np.exp(-t * 9) + 0.12 * np.sin(4.03 * ph) * np.exp(-t * 14))
    x += bp(noise(dur), 2000, 7000) * np.exp(-t * 90) * 0.15
    return x * np.minimum(1, t / 0.003)


def slap_bass(f, dur):
    t = T(dur)
    saw = signal.sawtooth(2 * np.pi * f * t) * 0.6 + np.sin(2 * np.pi * f * t)
    # filtro que abre e fecha (ataque estalado)
    bright = lp(saw, 2400, 2) * np.exp(-t * 18)
    body = lp(saw, 600, 2)
    return (body + bright * 0.8) * env_adsr(dur, 0.003, 0.12, 0.55, 0.06)


def build_music():
    """Trilha de praia animada (samba-pop, 122 bpm, Fá maior) em 3 camadas:
    base (uke, baixo, bumbo), perc (batucada do rali) e lead (refrão no steel drum)."""
    bpm = 122
    beat = 60 / bpm
    bars = 32
    dur = bars * 4 * beat
    n = int(SR * dur)
    F, C, Dm, Bb, Am, C7 = ([65, 69, 72], [64, 67, 72], [62, 65, 69], [62, 65, 70], [64, 69, 72], [64, 70, 72])
    verse = [F, C, Dm, Bb] * 2
    bridge = [Bb, C, Am, Dm, Bb, C, F, C7]
    prog = verse + verse + bridge + verse
    rmap = {id(F): 41, id(C): 36, id(Dm): 38, id(Bb): 34, id(Am): 33, id(C7): 36}
    roots = [rmap[id(c)] for c in prog]

    base_l, base_r = np.zeros(n + SR * 2), np.zeros(n + SR * 2)
    perc_l, perc_r = np.zeros(n + SR * 2), np.zeros(n + SR * 2)
    lead_l, lead_r = np.zeros(n + SR * 2), np.zeros(n + SR * 2)

    def put(lbuf, rbuf, x, at, pan=0.0):
        s = max(0, int(at * SR))
        e = min(len(lbuf), s + len(x))
        lbuf[s:e] += x[: e - s] * np.sqrt((1 - pan) / 2)
        rbuf[s:e] += x[: e - s] * np.sqrt((1 + pan) / 2)

    cache = {}

    def uke(m, d=0.32):
        key = ("u", m)
        if key not in cache:
            cache[key] = ks_string(midi(m), d, 0.990, 0.8) * env_adsr(d, 0.001, 0.08, 0.5, 0.12)
        return cache[key]

    def pan_note(m, d=0.9):
        key = ("p", m)
        if key not in cache:
            cache[key] = steelpan(midi(m), d)
        return cache[key]

    kick_t = T(0.3)
    KICK = np.sin(2 * np.pi * (50 + 110 * np.exp(-kick_t * 40)) * kick_t) * np.exp(-kick_t * 11)
    KICK += bp(noise(0.3), 1500, 5000) * np.exp(-kick_t * 200) * 0.3
    sn_t = T(0.2)
    SNARE = bp(noise(0.2), 1200, 8000) * np.exp(-sn_t * 22) * 0.7 + np.sin(2 * np.pi * 190 * sn_t) * np.exp(-sn_t * 30) * 0.5

    for bar in range(bars):
        b0 = bar * 4 * beat
        ch = prog[bar]
        # cavaquinho/uke no contratempo (a "pegada" alegre)
        for off in (0.5, 1.5, 2.5, 3.25, 3.5):
            for k, m in enumerate(ch + [ch[0] + 12]):
                put(base_l, base_r, uke(m) * (0.2 if off != 3.25 else 0.13), b0 + off * beat + k * 0.006, -0.4)
        # baixo sincopado
        r = roots[bar]
        for off, m, d in ((0, r, 0.42), (0.75, r + 12, 0.2), (1.5, r, 0.3), (2, r + 7, 0.4), (2.75, r + 12, 0.2),
                          (3.5, r + 7 if bar % 2 else r + 4, 0.3)):
            put(base_l, base_r, slap_bass(midi(m), d) * 0.34, b0 + off * beat)
        # bumbo, caixa leve e chocalho
        for off in (0, 1.75, 2):
            put(base_l, base_r, KICK * (0.7 if off != 1.75 else 0.4), b0 + off * beat)
        for off in (1, 3):
            put(base_l, base_r, SNARE * 0.32, b0 + off * beat, 0.1)
        for e8 in range(8):
            sh = hp(noise(0.05), 7000) * env_exp(0.05, 0.01)
            put(base_l, base_r, sh * (0.12 if e8 % 2 else 0.07), b0 + e8 * 0.5 * beat, 0.45)

    # batucada do rali: surdo, tamborim, agogô, congas e palmas
    TAMB = hp(bp(noise(0.06), 3000, 9000), 2500) * env_exp(0.06, 0.012) + modal([2600], [0.03], [0.4], 0.06)
    tamb_pat = [1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0]
    for bar in range(bars):
        b0 = bar * 4 * beat
        for s16, on in enumerate(tamb_pat):
            if on:
                put(perc_l, perc_r, TAMB * (0.2 if s16 % 4 == 0 else 0.13), b0 + s16 * 0.25 * beat, 0.35)
        for off, f, a in ((1, 62, 0.55), (3, 55, 0.7), (3.5, 62, 0.3)):
            tt = T(0.55)
            su = np.sin(2 * np.pi * f * tt * (1 + 0.25 * np.exp(-tt * 22))) * np.exp(-tt * 5)
            put(perc_l, perc_r, su * a, b0 + off * beat, -0.1)
        for off, f in ((0, 880), (0.75, 660), (1.5, 880), (2.5, 660), (3, 660)):
            ag = fm_bell(f, 0.25, ratio=2.76, index=1.5) * 0.12
            put(perc_l, perc_r, ag, b0 + off * beat, 0.55)
        for off, f in ((0.5, 300), (1.25, 220), (2.5, 300), (3.25, 220), (3.75, 220)):
            tt = T(0.16)
            cg = np.sin(2 * np.pi * f * tt * (1 + 0.1 * np.exp(-tt * 40))) * np.exp(-tt * 24) + bp(noise(0.16), 500, 2500) * np.exp(-tt * 50) * 0.4
            put(perc_l, perc_r, cg * 0.22, b0 + off * beat, -0.5)
        for off in (1, 3):
            cl = sum(np.roll(pad(CLAPS[rng.integers(len(CLAPS))], int(SR * 0.05)), int(SR * j * 0.007)) for j in range(3))
            put(perc_l, perc_r, cl * 0.3, b0 + off * beat, 0.05)
        # virada de caixa e apito de samba no fim de cada parte
        if bar % 8 == 7:
            for s16 in range(8, 16):
                put(perc_l, perc_r, SNARE * (0.12 + 0.03 * (s16 - 8)), b0 + s16 * 0.25 * beat, -0.15)
            wh = pea_whistle(0.16, True)
            for k in range(3):
                put(perc_l, perc_r, wh * 0.22, b0 + (2 + k * 0.5) * beat, 0.2)

    # refrão no steel drum (grudento) + metais na ponte
    hook = [
        [72, None, 72, 74, None, 77, None, 74, 72, None, 69, None, 72, 74, None, None],
        [72, None, 72, 74, None, 77, None, 79, 81, None, 79, 77, None, 74, None, None],
        [77, None, 76, 74, None, 72, None, 69, 70, None, 72, None, 74, None, 72, None],
        [69, None, 72, None, 76, None, 79, 77, 77, None, None, None, None, None, 72, 74],
    ]
    def play_hook(start_bar, octave=0, vol=0.3):
        for ph_i, ph in enumerate(hook):
            for i, m in enumerate(ph):
                if m is None:
                    continue
                at = ((start_bar + ph_i * 2) * 4 + i * 0.5) * beat
                put(lead_l, lead_r, pan_note(m + octave) * vol, at, 0.2 if i % 2 else -0.2)
                put(lead_l, lead_r, pan_note(m + octave) * vol * 0.35, at + beat * 0.75, 0.7)   # eco
    play_hook(0, 0, 0.32)
    play_hook(8, 0, 0.36)
    play_hook(24, 0, 0.36)
    for bar in range(16, 24):
        ch = prog[bar]
        b0 = bar * 4 * beat
        # arpejo sincopado (3-3-2)
        for k, off in enumerate((0, 0.75, 1.5, 2, 2.75, 3.5)):
            m = (ch + [ch[0] + 12, ch[1] + 12])[k % 5] + 12
            put(lead_l, lead_r, pan_note(m, 0.5) * 0.18, b0 + off * beat, -0.3 if k % 2 else 0.3)
        # metais curtos
        for off in (1.5, 3.5) if bar % 2 == 0 else (0.5, 2.5):
            tt = T(0.22)
            stab = sum(signal.sawtooth(2 * np.pi * midi(m) * tt) + signal.sawtooth(2 * np.pi * midi(m) * 1.005 * tt) for m in ch)
            stab = lp(stab, 3200) * env_adsr(0.22, 0.008, 0.06, 0.6, 0.08)
            put(lead_l, lead_r, stab * 0.07, b0 + off * beat, 0.0)

    def finish(lb, rb):
        x = np.stack([lb, rb], axis=1)
        tail = x[n:]
        x = x[:n].copy()
        x[: len(tail)] += tail   # rabo de volta no começo: loop contínuo
        return reverb(x, IR_BEACH, 0.18)[:n]

    base = finish(base_l, base_r)
    perc = finish(perc_l, perc_r)
    lead = finish(lead_l, lead_r)
    peakv = max(np.max(np.abs(base + perc + lead)), 1e-9)
    for name, x in (("music_base", base), ("music_perc", perc), ("music_lead", lead)):
        # as camadas mantêm o volume relativo da mixagem (tocam juntas no jogo)
        save_ogg(os.path.join(OUT, "music", name + ".ogg"), x / peakv * 0.8, q=5, loop=True, normalize=False)
        print("  music", name, f"{dur:.1f}s")
    # vinhetas
    def stinger(notes, step, dur=1.6, brass=False):
        x = np.zeros(int(SR * dur))
        for i, m in enumerate(notes):
            if m is None:
                continue
            if brass:
                t = T(0.5)
                v = lp(signal.sawtooth(2 * np.pi * midi(m) * t) + signal.sawtooth(2 * np.pi * midi(m) * 1.004 * t), 3000)
                v *= env_adsr(0.5, 0.02, 0.1, 0.7, 0.2) * 0.25
            else:
                v = ks_string(midi(m), 0.9, 0.995, 0.6) * 0.5 + fm_bell(midi(m), 0.9, 4.0, 1.0) * 0.3
            place(x, v, i * step)
        return reverb(x, IR_BEACH[:, 0], 0.25)

    sfx("sting_point", stinger([67, 72, 76], 0.07, 1.0), -4)
    sfx("sting_lose", stinger([64, 60, 55], 0.12, 1.2), -6)
    sfx("sting_game", stinger([60, 64, 67, 72, None, 67, 72, 76], 0.1, 1.8, True), -3)
    sfx("sting_win", stinger([60, 64, 67, 72, 76, 79, None, 84], 0.12, 2.4, True), -2)
    sfx("sting_defeat", stinger([67, 66, 65, 64, None, 55], 0.22, 2.2, True), -4)


def main():
    for sub in ("sfx", "amb", "music"):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    print("Sintetizando audio em", OUT)
    build_hits()
    build_sand()
    build_misc()
    build_crowd()
    build_music()


if __name__ == "__main__":
    main()

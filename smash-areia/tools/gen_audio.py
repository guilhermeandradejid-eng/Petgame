"""Sintetiza todos os efeitos sonoros e a musica do jogo (WAV mono 16 bits).

    python3 tools/gen_audio.py

Nada de samples de terceiros: tudo nasce de senoides, ruido filtrado e
envelopes, entao o audio e 100% original e livre.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "audio")
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.005, decay=None, curve=4.0):
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-t * curve / (decay or dur))
    return a * d


def lowpass(x, cutoff):
    # filtro de um polo, simples e suficiente
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("  ", name, f"{len(x) / SR:.2f}s")


def pop(freq, dur, nz=0.4, bend=0.6):
    t = t_axis(dur)
    f = freq * (1 + bend * np.exp(-t * 60))
    ph = np.cumsum(2 * np.pi * f / SR)
    tone = np.sin(ph)
    n = highpass(noise(dur), 1500) * np.exp(-t * 90)
    return (tone * (1 - nz) + n * nz) * env(dur, 0.001, dur * 0.5)


def main():
    print("Gerando audio em", os.path.normpath(OUT))
    # golpes
    save("hit", pop(520, 0.16, 0.45))
    save("drop", pop(780, 0.12, 0.25, 0.3), 0.6)
    save("lob", pop(380, 0.22, 0.3, 0.9), 0.75)
    t = t_axis(0.42)
    crack = highpass(noise(0.42), 900) * np.exp(-t * 28)
    thump = np.sin(2 * np.pi * 95 * t * (1 + 2 * np.exp(-t * 30))) * np.exp(-t * 12)
    save("smash", crack * 0.8 + thump + pop(300, 0.42, 0.6) * 0.6, 1.0)
    save("defense", pop(260, 0.2, 0.5, 0.2), 0.75)
    # areia, rede, mergulho, pulo
    t = t_axis(0.3)
    save("sand", lowpass(noise(0.3), 900) * np.exp(-t * 14), 0.7)
    t = t_axis(0.5)
    save("dive", lowpass(noise(0.5), 1400) * np.exp(-t * 6) * np.clip(t / 0.03, 0, 1), 0.7)
    t = t_axis(0.35)
    net = lowpass(noise(0.35), 600) * np.exp(-t * 10) + np.sin(2 * np.pi * 70 * t) * np.exp(-t * 14)
    save("net", net, 0.8)
    t = t_axis(0.25)
    f = 300 + 900 * t / 0.25
    save("jump", np.sin(np.cumsum(2 * np.pi * f / SR)) * env(0.25, 0.005, 0.15) * 0.6)
    t = t_axis(0.3)
    sw = noise(0.3)
    sw = lowpass(highpass(sw, 400), 3500) * np.sin(np.pi * t / 0.3) ** 2
    save("swoosh", sw, 0.55)
    # apito do juiz (com trinado)
    t = t_axis(0.7)
    f = 2900 + 140 * np.sign(np.sin(2 * np.pi * 28 * t))
    wh = np.sin(np.cumsum(2 * np.pi * f / SR)) + 0.3 * highpass(noise(0.7), 3000)
    wh *= np.clip(t / 0.02, 0, 1) * np.clip((0.7 - t) / 0.08, 0, 1)
    save("whistle", wh, 0.55)
    # interface
    save("click", pop(1200, 0.06, 0.1, 0.2), 0.5)
    t = t_axis(0.18)
    save("tick", np.sin(2 * np.pi * 1600 * t) * np.exp(-t * 40), 0.4)
    # torcida: ruido em bandas com "ondas" de entusiasmo
    dur = 2.2
    t = t_axis(dur)
    crowd = np.zeros_like(t)
    for k in range(18):
        f0 = rng.uniform(300, 1400)
        band = lowpass(highpass(noise(dur), f0 * 0.7), f0 * 1.4)
        crowd += band * (0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(2, 7) * t + rng.uniform(0, 6)))
    crowd *= np.clip(t / 0.15, 0, 1) * np.exp(-np.clip(t - 0.8, 0, None) * 2.2)
    save("cheer", crowd, 0.7)
    t = t_axis(1.3)
    aww = np.zeros_like(t)
    for k in range(10):
        f = rng.uniform(180, 320) * (1 - 0.25 * t / 1.3)
        ph = np.cumsum(2 * np.pi * f / SR)
        aww += np.sin(ph) * 0.3 + np.sin(ph * 2) * 0.15
    aww += lowpass(noise(1.3), 1200) * 0.4
    aww *= np.clip(t / 0.1, 0, 1) * np.clip((1.3 - t) / 0.5, 0, 1)
    save("aww", aww, 0.5)

    # jingles
    def note(freq, dur, kind="pluck"):
        tt = t_axis(dur)
        if kind == "pluck":
            return (np.sin(2 * np.pi * freq * tt) + 0.35 * np.sin(4 * np.pi * freq * tt)) * np.exp(-tt * 7)
        sq = np.sign(np.sin(2 * np.pi * freq * tt)) * 0.4 + np.sin(2 * np.pi * freq * tt)
        return sq * np.exp(-tt * 3) * np.clip((dur - tt) / 0.03, 0, 1)

    def seq(notes, step, kind="pluck"):
        out = np.zeros(int(SR * (step * len(notes) + 0.6)))
        for i, n in enumerate(notes):
            if n is None:
                continue
            x = note(n, 0.6, kind)
            s = int(i * step * SR)
            out[s:s + len(x)] += x
        return out

    C5, D5, E5, G5, A5, C6 = 523.25, 587.33, 659.25, 783.99, 880.0, 1046.5
    save("point", seq([G5, C6], 0.09), 0.6)
    save("lose_point", seq([E5, C5 * 0.75], 0.12), 0.5)
    a = seq([C5, E5, G5, C6, None, G5, C6], 0.11, "square")
    b = seq([C5 / 2, None, G5 / 2, None, C5 / 2], 0.15)
    n = max(len(a), len(b))
    save("win", np.pad(a, (0, n - len(a))) + np.pad(b, (0, n - len(b))), 0.7)
    save("lose", seq([G5, E5, D5, C5 * 0.94], 0.2, "square"), 0.6)

    # ambiente: ondas do mar (loop)
    dur = 6.0
    t = t_axis(dur)
    w = lowpass(noise(dur), 500)
    w *= 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * t / dur * 2 - 1.5)) ** 2
    save("waves", w, 0.35)

    # musica: loop tropical (marimba + baixo + chocalho), 112 bpm
    bpm = 112
    beat = 60 / bpm
    bars = 8
    dur = bars * 4 * beat
    total = int(SR * dur)
    mus = np.zeros(total + SR)
    chords = [(0, 4, 7), (5, 9, 12), (7, 11, 14), (0, 4, 7), (9, 12, 16), (5, 9, 12), (7, 11, 14), (7, 11, 14)]
    root = 261.63

    def st(n):
        return root * 2 ** (n / 12)

    def marimba(freq, length=0.5):
        tt = t_axis(length)
        return (np.sin(2 * np.pi * freq * tt) + 0.25 * np.sin(2 * np.pi * freq * 4 * tt) * np.exp(-tt * 30)) * np.exp(-tt * 9)

    def bass(freq, length):
        tt = t_axis(length)
        return (np.sin(2 * np.pi * freq * tt) + 0.3 * np.sin(4 * np.pi * freq * tt)) * np.exp(-tt * 3) * np.clip((length - tt) / 0.02, 0, 1)

    pattern = [0, 2, 1, 2, 0, 1, 2, 1]  # arpejo em colcheias
    melody = [12, None, 14, 16, None, 14, 12, None, 9, None, 12, None, 7, None, None, None,
              17, None, 16, 14, None, 12, 14, None, 16, None, 14, 12, 11, None, 7, None]
    for bar in range(bars):
        ch = chords[bar]
        for i in range(8):
            s = int((bar * 4 + i * 0.5) * beat * SR)
            x = marimba(st(ch[pattern[i]] + 12), 0.45) * 0.35
            mus[s:s + len(x)] += x
            sh = highpass(noise(0.05), 5000) * np.exp(-t_axis(0.05) * 80) * (0.12 if i % 2 else 0.2)
            mus[s:s + len(sh)] += sh
        for i, off in enumerate((0, 1.5, 2, 3.5)):
            s = int((bar * 4 + off) * beat * SR)
            x = bass(st(ch[0] - 12) if i % 2 == 0 else st(ch[2] - 24), beat * 0.9) * 0.5
            mus[s:s + len(x)] += x
        # bumbo e caixa
        for off in (0, 2):
            s = int((bar * 4 + off) * beat * SR)
            tt = t_axis(0.2)
            k = np.sin(2 * np.pi * 60 * tt * (1 + 3 * np.exp(-tt * 40))) * np.exp(-tt * 18) * 0.6
            mus[s:s + len(k)] += k
        for off in (1, 3):
            s = int((bar * 4 + off) * beat * SR)
            sn = highpass(noise(0.15), 1800) * np.exp(-t_axis(0.15) * 30) * 0.25
            mus[s:s + len(sn)] += sn
    for i, n in enumerate(melody * 2):
        if n is None:
            continue
        s = int(i * 0.5 * beat * SR)
        if s >= total:
            break
        x = marimba(st(n + 12), 0.6) * 0.45
        x[:int(SR * 0.3)] += marimba(st(n + 24), 0.3) * 0.1
        mus[s:s + len(x)] += x
    # dobra o rabo de volta no comeco para o loop ficar contínuo
    tail = mus[total:]
    mus = mus[:total]
    mus[:len(tail)] += tail
    save("music", mus, 0.6)


if __name__ == "__main__":
    main()

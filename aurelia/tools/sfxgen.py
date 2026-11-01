"""Procedural placeholder SFX (numpy + wave only). usage: python3 sfxgen.py"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "art", "sfx")
rng = np.random.default_rng(7)


def t(d):
    return np.linspace(0, d, int(SR * d), endpoint=False)


def env(n, a=0.005, r=0.2, power=2.0):
    x = np.linspace(0, 1, n)
    att = np.clip(x / max(a, 1e-4) / (n / SR), 0, 1)
    return att * (1 - x) ** power


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lp(x, k=0.15):
    y = np.zeros_like(x)
    a = 0.0
    for i, v in enumerate(x):
        a += k * (v - a)
        y[i] = a
    return y


def sweep(f0, f1, d):
    tt = t(d)
    f = np.linspace(f0, f1, len(tt))
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def save(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def main():
    d = 0.18
    save("swing", lp(noise(d), 0.35) * np.sin(np.linspace(0, np.pi, int(SR * d))) ** 1.5 + 0.2 * sweep(900, 300, d) * env(int(SR * d)))
    d = 0.26
    save("swing_heavy", lp(noise(d), 0.2) * np.sin(np.linspace(0, np.pi, int(SR * d))) ** 1.3 + 0.35 * sweep(500, 120, d) * env(int(SR * d)))
    d = 0.16
    n = int(SR * d)
    save("hit", 0.9 * sweep(220, 70, d) * env(n, 0.001, power=3) + 0.7 * lp(noise(d), 0.6) * env(n, 0.001, power=5))
    d = 0.3
    n = int(SR * d)
    save("hit_heavy", 1.0 * sweep(160, 40, d) * env(n, 0.001, power=2.5) + 0.8 * lp(noise(d), 0.5) * env(n, 0.001, power=4) + 0.3 * sweep(1200, 300, d) * env(n, power=6))
    d = 0.22
    n = int(SR * d)
    save("dash", lp(noise(d), 0.25) * np.sin(np.linspace(0, np.pi, n)) ** 0.8 * 0.8 + 0.2 * sweep(300, 900, d) * env(n))
    d = 0.07
    n = int(SR * d)
    save("step", lp(noise(d), 0.3) * env(n, 0.001, power=4), 0.5)
    d = 0.5
    n = int(SR * d)
    save("cast", (sweep(400, 1400, d) * 0.5 + sweep(600, 2100, d) * 0.3 + 0.15 * noise(d)) * np.sin(np.linspace(0, np.pi, n)) ** 0.7)
    d = 0.35
    n = int(SR * d)
    save("lance", (lp(noise(d), 0.5) * 0.4 + sweep(1800, 600, d) * 0.5) * env(n, 0.01, power=1.4))
    d = 0.4
    n = int(SR * d)
    crackle = noise(d) * (rng.random(n) > 0.93)
    save("ice_shatter", (0.7 * crackle + 0.5 * sweep(2600, 900, d) * env(n, 0.001, power=3) + 0.3 * lp(noise(d), 0.7)) * env(n, 0.001, power=2))
    d = 0.5
    n = int(SR * d)
    save("enemy_die", (sweep(500, 90, d) * 0.7 + lp(noise(d), 0.3) * 0.5) * env(n, 0.002, power=1.8))
    d = 0.22
    n = int(SR * d)
    save("hurt", (sweep(520, 260, d) * 0.7 + lp(noise(d), 0.5) * 0.4) * env(n, 0.002, power=2))
    d = 0.18
    n = int(SR * d)
    save("alert", (np.sin(2 * np.pi * 880 * t(d)) * 0.5 + np.sin(2 * np.pi * 1320 * t(d)) * 0.4) * env(n, 0.002, power=2.5), 0.5)
    d = 0.3
    n = int(SR * d)
    save("windup", sweep(180, 420, d) * env(n, 0.05, power=1.2) * 0.8, 0.5)
    print("wrote", len(os.listdir(OUT)), "sfx to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()

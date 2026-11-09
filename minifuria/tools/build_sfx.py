"""
Wreck 'n' Roll: monta a biblioteca de sons REAIS do jogo (minifuria/sfx/) a partir de pacotes livres.

Fontes (veja sfx/CREDITOS.txt para autores e licenças de cada arquivo):
  - Stunt Rally 3 (github.com/stuntrally/stuntrally3, data/sounds): motores gravados no engine-sim em rotações
    fixas (CC-BY 4.0, CryHam), batidas de metal (CC-BY 4.0, Halleck/CryHam), turbo (CC-BY 4.0), água e lama
    (CC-BY 4.0), motor elétrico (CC0).
  - Red Eclipse (github.com/redeclipse/sounds): armas, explosões e vento (CC-BY-SA 4.0).
  - Yorg (github.com/cflavio/yorg, assets/sfx): pneu cantando/freada e pouso (CC-BY-SA), explosão de
    Michel Baradari (CC-BY 3.0).
  - Kenney (kenney.nl, via github.com/Mcamento8/open-game-sfx-index): impactos, interface, fichas,
    vinhetas e narrador (CC0).

Uso (precisa de ffmpeg e numpy):
    git clone --depth 1 https://github.com/stuntrally/stuntrally3 SRC/sr3          (só data/sounds)
    git clone --depth 1 https://github.com/redeclipse/sounds SRC/re_sounds
    git clone --depth 1 https://github.com/cflavio/yorg SRC/yorg                     (só assets/sfx)
    (Kenney: baixe os .ogg listados abaixo do index.json do open-game-sfx-index para SRC/ogsi/dl/)
    python3 tools/build_sfx.py SRC sfx

O que faz: decodifica para mono 44,1 kHz, corta o silêncio do começo, normaliza o volume (RMS da parte ativa,
com pico limitado) e grava OGG Vorbis. Loops (motor, pneu, raspada, vento, turbo) saem SEM EMENDA: um trecho
do meio da gravação com o fim mesclado no começo (crossfade de potência constante).
"""
import json
import os
import subprocess
import sys

import numpy as np

SR = 44100


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def encode(x, out, q=4):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    x = np.clip(x, -1.0, 1.0).astype(np.float32)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), out], input=x.tobytes(), check=True)


def db(v):
    return 10 ** (v / 20.0)


def trim_lead(x, thr_db=-42.0):
    a = np.abs(x)
    idx = np.where(a > db(thr_db) * max(1e-9, a.max()))[0]
    if len(idx) == 0:
        return x
    s = max(0, idx[0] - int(0.004 * SR))
    return x[s:]


def active_rms(x):
    # RMS da parte "acesa" (janelas acima de -30 dB do pico), para comparar sons curtos e longos
    w = int(0.02 * SR)
    n = len(x) // w
    if n == 0:
        return float(np.sqrt(np.mean(x ** 2)) + 1e-9)
    e = np.sqrt(np.mean(x[: n * w].reshape(n, w) ** 2, axis=1))
    on = e[e > e.max() * db(-30)]
    return float(np.sqrt(np.mean(on ** 2)) + 1e-9)


def level(x, rms_db, peak_db=-0.8):
    x = x * (db(rms_db) / active_rms(x))
    p = np.abs(x).max()
    if p > db(peak_db):
        x = x * (db(peak_db) / p)
    return x


def fade(x, fin=0.003, fout=0.04):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0 and b < len(x):
        x[-b:] *= np.linspace(1, 0, b) ** 2
    return x


def make_loop(x, length, xf=0.12, start=None, linear=False):
    """Loop sem emenda: crossfade de potência constante (ruído) ou linear (som periódico, como motor)."""
    L, X = int(length * SR), int(xf * SR)
    if start is None:
        start = max(0, (len(x) - L - X) // 2)
    seg = x[start: start + L + X]
    if len(seg) < L + X:
        seg = np.concatenate([seg, seg[: L + X - len(seg)]])
    out = seg[:L].copy()
    if linear:
        t = np.linspace(0, 1, X)
        out[:X] = seg[:X] * t + seg[L: L + X] * (1 - t)
    else:
        t = np.linspace(0, np.pi / 2, X)
        out[:X] = seg[:X] * np.sin(t) + seg[L: L + X] * np.cos(t)
    return out


def presence(x, amt_db=-6.0):
    """Realça os harmônicos do próprio motor (saturação suave, filtrada entre ~400 Hz e ~4,5 kHz) e mistura por baixo.
    As gravações do engine-sim são quase só grave (<250 Hz), que alto-falante de celular não toca: com os
    harmônicos, o ouvido "reconstrói" o grave e o ronco aparece. O filtro é feito na FFT do loop inteiro
    (convolução circular) e a saturação não tem memória, então o loop continua sem emenda."""
    r = float(np.sqrt(np.mean(x ** 2))) + 1e-9
    h = np.tanh(x / r * 1.2)
    f = np.fft.rfftfreq(len(h), 1.0 / SR)
    mask = (1.0 - 1.0 / (1.0 + (f / 400.0) ** 4)) / (1.0 + (f / 4500.0) ** 4)
    h = np.fft.irfft(np.fft.rfft(h) * mask, len(h))
    h *= r / (float(np.sqrt(np.mean(h ** 2))) + 1e-9) * db(amt_db)
    return x + h


def remove_dc(x):
    return x - np.mean(x)


# ------------------------------------------------------------------ catálogo
K = "ogsi/dl/"
SR3 = "sr3/data/sounds/"
RE = "re_sounds/"
YO = "yorg/assets/sfx/"

# nome do evento: [arquivos], RMS alvo (dB), duração máxima (s)
ONESHOTS = {
    # carro
    "crash": ([SR3 + "crash/%02d.wav" % i for i in (6, 7, 8, 9, 10, 11, 12)], -14, 1.2),
    "bump": ([SR3 + "crash/%02d.wav" % i for i in (2, 3, 4, 5)] + [K + "impact-sounds__impactPlate_medium_00%d.ogg" % i for i in (0, 1, 2)], -17, 0.6),
    "metal": ([K + "impact-sounds__impactMetal_heavy_00%d.ogg" % i for i in range(5)], -16, 0.9),
    "tink": ([RE + "weapons/tink.ogg", RE + "weapons/ricochet.ogg"] + [K + "impact-sounds__impactMetal_light_00%d.ogg" % i for i in range(3)], -18, 0.4),
    "glass": ([K + "impact-sounds__impactGlass_heavy_00%d.ogg" % i for i in range(5)], -16, 1.0),
    "smash": ([K + "impact-sounds__impactWood_heavy_00%d.ogg" % i for i in range(3)] + [K + "impact-sounds__impactPunch_heavy_00%d.ogg" % i for i in range(2)], -16, 0.7),
    "land": ([YO + "landing.ogg"] + [SR3 + "hit/terrain%d.wav" % i for i in (3, 4, 5)], -16, 0.8),
    "splash": ([SR3 + "fluids/water%d.wav" % i for i in (1, 2, 3)], -16, 1.6),
    "splat": ([SR3 + "fluids/mud1.wav"], -17, 0.9),
    "whoosh": ([RE + "weapons/whizz.ogg"] + ["ogsi/dl/oga-battle__swish_%d.wav" % i for i in (2, 3, 4)], -17, 0.6),
    "nitro": ([K + "sci-fi-sounds__thrusterFire_00%d.ogg" % i for i in range(5)], -14, 1.4),
    "backfire": ([RE + "weapons/smallblastfar2.ogg"], -15, 0.45),
    "shift": ([SR3 + "engines/gear_shift1.wav", SR3 + "engines/gear_shift4a.wav", SR3 + "engines/gear_shift4b.wav"], -20, 0.25),
    # armas
    "gun": ([RE + "weapons/smg/primary.ogg", RE + "weapons/smg/primary2.ogg"], -16, 0.35),
    "rocket": ([RE + "weapons/rocket/primary.ogg"], -14, 1.2),
    "boom": ([RE + "weapons/explode.ogg", RE + "weapons/explode2.ogg", YO + "crash_high_speed.ogg"], -12, 2.0),
    "boom_small": ([RE + "weapons/smallblast.ogg", RE + "weapons/mine/explode.ogg"], -13, 1.4),
    "zap": ([RE + "weapons/bzap.ogg", RE + "weapons/bzzt.ogg"], -15, 0.4),
    "laser": ([K + "sci-fi-sounds__laserLarge_00%d.ogg" % i for i in range(5)], -18, 0.5),
    "plasma": ([RE + "weapons/plasma/primary.ogg"], -16, 0.7),
    "rail": ([RE + "weapons/rifle/primary.ogg"], -13, 1.2),
    "mortar": ([RE + "weapons/grenade/primary.ogg"], -14, 0.5),
    "harpoon": (["ogsi/dl/oga-battle__Bow.wav"], -15, 0.8),
    "freeze": ([K + "sci-fi-sounds__forceField_00%d.ogg" % i for i in range(3)], -17, 0.8),
    "flame": ([RE + "weapons/flamer/primary_begin.ogg"], -17, 0.6),
    "emp": ([RE + "weapons/plasma/vortex.ogg"], -15, 1.1),
    "deploy": ([K + "impact-sounds__impactMetal_light_00%d.ogg" % i for i in (3, 4)] + [K + "impact-sounds__impactTin_medium_00%d.ogg" % i for i in range(3)], -18, 0.5),
    # interface
    "click": ([K + "interface-sounds__select_00%d.ogg" % i for i in (1, 2, 3)], -22, 0.4),
    "ui_drop": ([K + "interface-sounds__drop_00%d.ogg" % i for i in (1, 2, 3, 4)], -22, 0.5),
    "buy": ([K + "casino-audio__chips-stack-%d.ogg" % i for i in (1, 2, 3, 4)], -18, 0.9),
    "pickup": ([K + "interface-sounds__maximize_00%d.ogg" % i for i in (1, 2, 3, 4)], -18, 0.6),
    "error": ([K + "interface-sounds__error_00%d.ogg" % i for i in (1, 2)], -20, 0.5),
    "warn": ([K + "interface-sounds__bong_001.ogg"], -16, 1.0),
    "fanfare": ([K + "music-jingles__jingles_HIT0%d.ogg" % i for i in (0, 3, 6)], -15, 4.0),
}

# loops: arquivo, comprimento do loop (s), RMS alvo, início (s ou None = meio)
LOOPS = {
    "loop_skid": (YO + "brake.ogg", 1.6, -16, None),
    "loop_scrape": (SR3 + "crash/screech.wav", 2.2, -17, 0.4),
    "loop_wind": (RE + "ambience/wind.ogg", 3.0, -20, 4.0),
    "loop_turbo": (SR3 + "engines/turbo4.wav", 2.0, -18, None),
}

# motores: série -> lista de (rpm, arquivo). Cada um vira um loop curto de rotação constante.
ENGINES = {
    "b-i6r": [(r * 1000, SR3 + "engines/b-i6r-%d.wav" % r) for r in range(1, 9)],
    "su-mid": [(r * 1000, SR3 + "engines/su-mid-%d.wav" % r) for r in range(1, 9)],
    "su-sz": [(r * 1000, SR3 + "engines/su-sz-%d.wav" % r) for r in range(1, 9)],
    "exh": [(r * 1000, SR3 + "engines/exh-%d.wav" % r) for r in range(1, 10)],
    "tsu": [(r * 1000, SR3 + "engines/tsu-%d.wav" % r) for r in range(1, 10)],
    "gv8": [(r * 1000, SR3 + "engines/gv8-%d.wav" % r) for r in range(1, 7)],
    "ct-v8": [(r * 1000, SR3 + "engines/ct-v8-%d.wav" % r) for r in range(1, 8)],
    "v12d": [(r * 1000, SR3 + "engines/v12d-%d.wav" % r) for r in range(1, 11)],
    "v8f": [(r * 1000, SR3 + "engines/v8f-%d.wav" % r) for r in range(1, 11)],
    "dsl": [(300, SR3 + "engines/ds8-0.wav"), (630, SR3 + "engines/ds8-1.wav"), (1000, SR3 + "engines/ds8-2.wav"),
            (1500, SR3 + "engines/ds8-3.wav"), (2000, SR3 + "engines/ds8-4.wav"), (2350, SR3 + "engines/ds8-5.wav")],
    "elec": [(4000, SR3 + "engines/hover_r2.wav")],
}


def main():
    src, out = sys.argv[1], sys.argv[2]
    manifest = {"oneshots": {}, "engines": {}}
    for name, (files, rms, maxd) in ONESHOTS.items():
        n = 0
        for f in files:
            p = os.path.join(src, f)
            if not os.path.exists(p):
                print("faltando", p)
                continue
            x = remove_dc(decode(p))
            x = trim_lead(x)
            x = x[: int(maxd * SR)]
            x = fade(level(x, rms), fout=min(0.08, maxd * 0.25))
            encode(x, os.path.join(out, "%s_%d.ogg" % (name, n)))
            n += 1
        manifest["oneshots"][name] = n
    for name, (f, ln, rms, st) in LOOPS.items():
        x = remove_dc(decode(os.path.join(src, f)))
        x = make_loop(x, ln, 0.15, None if st is None else int(st * SR), linear=(name == "loop_turbo"))
        encode(level(x, rms), os.path.join(out, name + ".ogg"))
    for name, lst in ENGINES.items():
        segs = []
        for rpm, f in lst:
            x = remove_dc(decode(os.path.join(src, f)))
            # trecho estável do meio; quanto mais alta a rotação, mais curto o ciclo (loop menor basta)
            lp = make_loop(x, 1.2, 0.1, linear=True)
            segs.append((rpm, lp if name == "elec" else presence(lp)))
        # mesma escala para a série toda (a mais forte em -15 dB RMS): o volume natural sobe com a rotação
        g = db(-15) / max(active_rms(s) for _, s in segs)
        manifest["engines"][name] = []
        for rpm, s in segs:
            s = s * g
            p = np.abs(s).max()
            if p > db(-0.8):
                s = s * db(-0.8) / p
            encode(s, os.path.join(out, "engine", "%s_%d.ogg" % (name, rpm)), q=3)
            manifest["engines"][name].append(rpm)
    with open(os.path.join(out, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=1)
    print("ok:", sum(manifest["oneshots"].values()), "efeitos,", len(LOOPS), "loops,",
          sum(len(v) for v in manifest["engines"].values()), "amostras de motor")


if __name__ == "__main__":
    main()

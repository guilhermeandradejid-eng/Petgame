"""
Wreck 'n' Roll: monta o trailer (≈40 s, 1920x1080, 30 fps) a partir das gravações do próprio jogo.

1) gravações: o jogo grava cenas limpas com o Movie Maker do Godot (--write-movie) no modo trailer
   (--trailer: sem HUD, sem música e sem narrador; os momentos de ação vão para o log como "TEV quadro tipo");
   a contagem (--trailerhud) e as telas (--trailerui) são gravadas em cada idioma.
2) cartões: tools/trailer_cards.gd (PNG transparentes no visual do jogo); narração: tools/trailer_voice.py.
3) este script escolhe os melhores trechos (movimento + clarões de explosão + eventos do log), corta no ritmo
   da música (GIGA METAL, 142 BPM; o "VAI!" da largada cai na entrada da banda), aplica cartões, clarões,
   "soco" de zoom nos cortes, abaixa a música sob a narração e grava o MP4.

Uso:
    python3 tools/make_trailer.py --lang en --rec GRAVACOES --cards CARTOES_en --narr NARRACAO \
        --samples AMOSTRAS --out trailer_en.mp4
"""
import argparse
import json
import os
import re
import subprocess
import wave

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

FPS = 30
W, H = 1920, 1080
SR = 48000
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)

# grade da música (boss.ogg = "GIGA METAL", Loyalty Freak Music, CC0): a banda entra em 5,18 s
DROP = 5.18
BEAT = 0.4235
END = 40.5


def bt(n):
    """tempo da n-ésima batida depois da entrada da banda"""
    return DROP + n * BEAT


# ------------------------------------------------------------------ análise das gravações
def frames_small(path, w=160, h=90):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-vf", "scale=%d:%d" % (w, h), "-f", "rawvideo",
                          "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, h, w, 3)


def events(log):
    out = []
    if os.path.exists(log):
        for ln in open(log, errors="ignore"):
            m = re.match(r"TEV (\d+) (\w+)", ln)
            if m:
                out.append((int(m.group(1)), m.group(2)))
    return out


def analyse(rec, name):
    """nota de ação por quadro: movimento, clarões (explosões) e eventos do log"""
    cache = os.path.join(rec, name + ".score3.npz")
    avi = os.path.join(rec, name + ".avi")
    if os.path.exists(cache) and os.path.getmtime(cache) > os.path.getmtime(avi):
        d = np.load(cache)
        return d["motion"], d["flash"], d["ev"]
    fr = frames_small(avi).astype(np.float32)
    n = len(fr)
    lum = fr.mean(3)
    motion = np.zeros(n, np.float32)
    motion[1:] = np.abs(np.diff(lum, axis=0)).mean((1, 2))
    # clarão: cor de fogo/explosão (conta sempre) e branco que ACENDE de repente (o fundo branco das pistas
    # do céu e de brinquedo não conta)
    r, g, b = fr[..., 0], fr[..., 1], fr[..., 2]
    fire = ((r > 220) & (g > 110) & (g < 215) & (b < 120)).mean((1, 2))
    white = ((r > 245) & (g > 245) & (b > 235)).mean((1, 2))
    hot = fire + white
    base = np.convolve(hot, np.ones(31) / 31, "same")
    flash = np.maximum(0, hot - base) * 40.0 + fire * 10.0
    ev = np.zeros(n, np.float32)
    for f, kind in events(os.path.join(rec, name + ".log")):
        if 0 <= f < n:
            wgt = {"wreck": 3.0, "boss": 2.0, "air": 1.5}.get(kind, 1.0)
            lo, hi = max(0, f - 12), min(n, f + 20)
            ev[lo:hi] += wgt
    np.savez(cache, motion=motion, flash=flash, ev=ev)
    return motion, flash, ev


class Pool:
    """trechos já usados de cada gravação (não repete o mesmo momento)"""

    def __init__(self, rec, names, start=150):
        self.rec = rec
        # só gravações completas (o script de gravação cria NOME.done ao terminar cada uma)
        self.names = [nm for nm in names if os.path.exists(os.path.join(rec, nm + ".avi"))
                      and os.path.exists(os.path.join(rec, nm + ".done"))]
        raw = {nm: analyse(rec, nm) for nm in self.names}
        # movimento normalizado com a MESMA régua para todas as gravações (a cena mais agitada ganha)
        ref = np.median([np.percentile(raw[nm][0][start:], 90) for nm in self.names]) if self.names else 1.0
        self.data = {}
        for nm, (motion, flash, ev) in raw.items():
            score = np.clip(motion / (ref + 1e-6), 0, 2.0) + flash + ev * 0.6
            self.data[nm] = (score, flash)
        self.used = {nm: np.zeros(len(self.data[nm][0]), bool) for nm in self.names}
        self.start = start
        for nm in self.names:
            self.used[nm][:start] = True

    def best(self, nm, n, flash_k=0.0, early=True):
        score, flash = self.data[nm]
        s = score + flash * flash_k
        tot = len(s)
        best = None
        cs = np.concatenate([[0], np.cumsum(s)])
        for a in range(self.start, tot - n - 2, 2):
            if self.used[nm][a:a + n].any():
                continue
            v = (cs[a + n] - cs[a]) / n
            if early:
                # o pico logo no começo do corte (o impacto cai na batida)
                v += 0.5 * s[a:a + min(n, 12)].max()
            if best is None or v > best[0]:
                best = (v, a)
        if best is None:
            return None
        a = best[1]
        self.used[nm][max(0, a - 45):a + n + 45] = True
        return (nm, a, best[0])

    def best_any(self, n, flash_k=0.0, order=None):
        cands = []
        for nm in (order or self.names):
            if nm not in self.data:
                continue
            b = self.best_dry(nm, n, flash_k)
            if b:
                cands.append(b)
        if not cands:
            return None
        cands.sort(key=lambda c: -c[2])
        return self.best(cands[0][0], n, flash_k)

    def best_dry(self, nm, n, flash_k):
        saved = self.used[nm].copy()
        r = self.best(nm, n, flash_k)
        self.used[nm] = saved
        return r


# ------------------------------------------------------------------ plano do trailer
def plan(lang, rec, narr_d):
    """lista de trechos: (início_s, fim_s, fonte) e eventos de cartão, narração e efeitos"""
    shots = []    # dict(t0, t1, clip, f0, speed, fx)
    cards = []    # (t0, t1, nome)
    voice = []    # (t, chave)
    # (a gravação do chefe da neve ficou clara demais com o desfoque de velocidade: fica de fora)
    act = Pool(rec, ["r_neon", "r_dunes", "r_loops", "b_emperor", "b_blackout", "b_brutus"])
    races = ["r_neon", "r_dunes", "r_loops"]
    bosses = ["b_emperor", "b_brutus", "b_blackout", "b_emperor"]

    def add(t0, t1, clip, f0, speed=1.0, fx="punch"):
        shots.append({"t0": t0, "t1": t1, "clip": clip, "f0": f0, "speed": speed, "fx": fx})

    # abertura: preto, entra a largada (título da pista, 3, 2, 1) e o "VAI!" cai na entrada da banda
    go_f = 129
    cd = "cd_" + lang
    t_in = DROP - go_f / FPS
    add(t_in, bt(2), cd, 0, fx="fadein")
    voice.append((0.55, "n1"))
    # A) ação nas pistas: corte a cada 2 batidas (às vezes 1), alternando as gravações
    t = bt(2)
    pattern = [2, 2, 1, 1, 2, 2, 2, 1, 1, 2, 2, 2, 1, 1, 2, 2, 2, 2]
    k = 0
    cycle = ["r_neon", "r_dunes", "r_neon", "r_loops", "r_dunes", "r_neon", "r_dunes"]
    while t < bt(32) - 0.01:
        nb = pattern[k % len(pattern)]
        t1 = min(bt(32), t + nb * BEAT)
        n = int(round((t1 - t) * FPS)) + 1
        want = cycle[k % len(cycle)]
        pick = act.best(want, n, 1.0) if want in act.names else None
        if pick is None:
            pick = act.best_any(n, 1.0, races)
        if pick:
            add(t, t1, pick[0], pick[1], fx="flash" if nb == 1 else "punch")
        t = t1
        k += 1
    cards.append((bt(2) + 0.05, bt(2) + 2.6, "tracks"))
    cards.append((bt(16), bt(16) + 2.6, "weapons"))
    voice.append((bt(16) + 0.15, "n3"))   # narração enxuta: abertura, armas, chefes e o nome no fim
    # B) chefes: trechos de 4 batidas (dá tempo de ver o ataque)
    t = bt(32)
    for i, bnm in enumerate(bosses):
        t1 = bt(32 + 4 * (i + 1))
        n = int(round((t1 - t) * FPS)) + 1
        pick = act.best(bnm, n, 0.8) if bnm in act.names else act.best_any(n, 0.8, bosses)
        if pick:
            add(t, t1, pick[0], pick[1], fx="flash" if i == 0 else "punch")
        t = t1
    cards.append((bt(32) + 0.05, bt(32) + 2.8, "bosses"))
    voice.append((bt(32) + 0.2, "n4"))
    # C) tela dividida (4 jogadores)
    sp = Pool(rec, ["split4"], start=160)
    t0, t1 = bt(48), bt(56)
    pick = sp.best("split4", int(round((t1 - t0) * FPS)) + 1) if sp.names else None
    if pick:
        add(t0, t1, pick[0], pick[1], fx="flash")
    cards.append((t0 + 0.05, t1 - 0.1, "multi"))
    # D) garagem e menu (no idioma do trailer)
    ui = "ui_" + lang
    ev = dict((k2, f) for f, k2 in events(os.path.join(rec, ui + ".log")))
    g0 = ev.get("ui_garage", 300)
    add(bt(56), bt(60), ui, 70, fx="flash")          # menu: logo e o carro na vitrine
    add(bt(60), bt(64), ui, g0 + 40, fx="punch")     # garagem
    cards.append((bt(60) + 0.05, bt(64) - 0.1, "garage"))   # o menu aparece limpo (já tem o logo)
    # E) final frenético: um corte por batida, os maiores clarões
    t = bt(64)
    order = ["r_dunes", "b_emperor", "r_neon", "b_brutus", "r_dunes", "b_blackout", "r_neon", "r_dunes"]
    for i in range(8):
        t1 = bt(65 + i)
        n = int(round((t1 - t) * FPS)) + 1
        pick = act.best(order[i], n, 2.5) if order[i] in act.names else None
        if pick is None:
            pick = act.best_any(n, 2.5)
        if pick:
            add(t, t1, pick[0], pick[1], fx="flash")
        t = t1
    # F) logo: fundo em câmera lenta, escuro e desfocado
    t = bt(72)
    n = int(round((END - t) * FPS * 0.5)) + 2
    pick = act.best_any(n, 2.0, ["b_emperor", "r_neon", "b_blackout"])
    if pick:
        add(t, END, pick[0], pick[1], speed=0.5, fx="logo")
    cards.append((t, END, "logo"))
    voice.append((t + 0.35, "n7"))
    return shots, cards, voice


# ------------------------------------------------------------------ vídeo
def read_frames(avi, f0, n):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", "%.4f" % (f0 / FPS), "-i", avi, "-frames:v", str(n),
                          "-vf", "scale=%d:%d:flags=lanczos" % (W, H), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         capture_output=True, check=True).stdout
    arr = np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3)
    return [Image.fromarray(a) for a in arr]


def ease_out(u):
    return 1 - (1 - u) ** 3


def card_frame(img, age, left):
    """cartão entrando com 'soco' (escala 1,35 -> 1) e saindo deslizando"""
    a_in = min(1.0, age / 0.14)
    sc = 1.0 + 0.35 * (1 - ease_out(a_in))
    out_u = max(0.0, min(1.0, (0.16 - left) / 0.16))
    alpha = a_in * (1 - out_u)
    if alpha <= 0.01:
        return None
    im = img
    if abs(sc - 1.0) > 0.003:
        w2, h2 = int(W * sc), int(H * sc)
        im = img.resize((w2, h2), Image.BILINEAR).crop(((w2 - W) // 2, (h2 - H) // 2, (w2 - W) // 2 + W, (h2 - H) // 2 + H))
    if out_u > 0:
        im = im.transform(im.size, Image.AFFINE, (1, 0, -60 * out_u, 0, 1, 0))
    if alpha < 0.999:
        a = im.getchannel("A").point(lambda v: int(v * alpha))
        im = im.copy()
        im.putalpha(a)
    return im


def render_video(shots, cards, cards_dir, rec, out_raw_cmd):
    total = int(round(END * FPS))
    card_img = {}
    for t0, t1, nm in cards:
        card_img[nm] = Image.open(os.path.join(cards_dir, nm + ".png")).convert("RGBA")
    enc = subprocess.Popen(out_raw_cmd, stdin=subprocess.PIPE)
    black = Image.new("RGB", (W, H), (8, 7, 14))
    shots = sorted(shots, key=lambda s: s["t0"])
    cache = {}
    for fi in range(total):
        t = fi / FPS
        sh = None
        for s in shots:
            if s["t0"] <= t < s["t1"]:
                sh = s
        frame = black.copy()
        if sh:
            key = id(sh)
            if key not in cache:
                n = int(round((sh["t1"] - sh["t0"]) * FPS * sh["speed"])) + 3
                cache.clear()
                cache[key] = read_frames(os.path.join(rec, sh["clip"] + ".avi"), sh["f0"], n)
            frs = cache[key]
            age = t - sh["t0"]
            j = min(len(frs) - 1, int(age * FPS * sh["speed"]))
            frame = frs[j].copy()
            fx = sh["fx"]
            if fx == "fadein" and age < 0.45:
                frame = Image.blend(black, frame, age / 0.45)
            if fx in ("punch", "flash") and age < 0.2:
                sc = 1.0 + 0.07 * (1 - ease_out(age / 0.2))
                w2, h2 = int(W * sc), int(H * sc)
                frame = frame.resize((w2, h2), Image.BILINEAR).crop(((w2 - W) // 2, (h2 - H) // 2, (w2 - W) // 2 + W, (h2 - H) // 2 + H))
            if fx == "flash" and age < 0.14:
                frame = Image.blend(frame, Image.new("RGB", (W, H), (255, 250, 235)), 0.75 * (1 - age / 0.14))
            if fx == "logo":
                frame = frame.filter(ImageFilter.GaussianBlur(5))
                frame = ImageEnhance.Brightness(frame).enhance(0.42)
                if age < 0.2:
                    frame = Image.blend(frame, Image.new("RGB", (W, H), (255, 245, 225)), 0.9 * (1 - age / 0.2))
            # o "VAI!" da largada: clarão na entrada da banda
            if abs(t - DROP) < 0.12 and sh["clip"].startswith("cd_"):
                frame = Image.blend(frame, Image.new("RGB", (W, H), (255, 255, 255)), 0.5 * (1 - abs(t - DROP) / 0.12))
        fr = frame.convert("RGBA")
        for t0, t1, nm in cards:
            if t0 <= t < t1:
                if nm == "logo":
                    age = t - t0
                    sc = 1.0 + 1.1 * (1 - ease_out(min(1.0, age / 0.22)))
                    im = card_img[nm]
                    if sc > 1.003:
                        w2, h2 = int(W * sc), int(H * sc)
                        im = im.resize((w2, h2), Image.BILINEAR).crop(((w2 - W) // 2, (h2 - H) // 2, (w2 - W) // 2 + W, (h2 - H) // 2 + H))
                    shake = max(0.0, 1 - age / 0.6) * 14
                    if shake > 0.5:
                        im = im.transform(im.size, Image.AFFINE, (1, 0, np.sin(age * 90) * shake, 0, 1, np.cos(age * 77) * shake))
                    fr.alpha_composite(im)
                else:
                    ci = card_frame(card_img[nm], t - t0, t1 - t)
                    if ci is not None:
                        fr.alpha_composite(ci)
        # fade final
        if t > END - 0.6:
            fr = Image.blend(fr, Image.new("RGBA", (W, H), (0, 0, 0, 255)), (t - (END - 0.6)) / 0.6)
        enc.stdin.write(fr.convert("RGB").tobytes())
        if fi % 150 == 0:
            print("  quadro %d/%d" % (fi, total), flush=True)
    enc.stdin.close()
    enc.wait()


# ------------------------------------------------------------------ áudio
def load_audio(path, ss=0.0, dur=None, ch=2):
    cmd = ["ffmpeg", "-v", "error", "-ss", "%.4f" % ss]
    if dur:
        cmd += ["-t", "%.4f" % dur]
    cmd += ["-i", path, "-ac", str(ch), "-ar", str(SR), "-f", "f32le", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, ch).copy()


def put(buf, x, t, gain=1.0):
    i = int(t * SR)
    if i >= len(buf):
        return
    n = min(len(x), len(buf) - i)
    buf[i:i + n] += x[:n] * gain


def render_audio(shots, voice, lang, narr_dir, samples, music, out_wav):
    n = int(END * SR) + SR
    mus = np.zeros((n, 2), np.float32)
    m = load_audio(music, 0, END + 1)
    mus[:len(m)] += m[:n]
    # fim: a música some depois do logo
    f0, f1 = int((END - 3.2) * SR), int(END * SR)
    mus[f0:f1] *= np.linspace(1, 0, f1 - f0)[:, None] ** 2
    mus[f1:] = 0
    vo = np.zeros((n, 2), np.float32)
    for t, key in voice:
        p = os.path.join(narr_dir, "%s_%s.wav" % (lang, key))
        if os.path.exists(p):
            v = load_audio(p, ch=1)
            put(vo, np.repeat(v, 2, 1), t, 1.15)
    # música abaixa (-8 dB) enquanto o Decibel fala
    act = (np.abs(vo[:, 0]) > 0.003).astype(np.float32)
    win = int(0.25 * SR)
    act = np.minimum(1, np.convolve(act, np.ones(win) / win * 4, "same"))
    duck = 1 - act * (1 - 10 ** (-8 / 20))
    mus *= duck[:, None]
    fx = np.zeros((n, 2), np.float32)
    for s in shots:
        if s["speed"] != 1.0 or s["clip"].startswith("ui_"):
            continue   # câmera lenta e telas do menu (gravadas com a música do menu) ficam sem o som da cena
        dur = s["t1"] - s["t0"]
        a = load_audio(os.path.join(s.get("rec"), s["clip"] + ".avi"), s["f0"] / FPS, dur + 0.05)
        e = int(0.008 * SR)
        if len(a) > 2 * e:
            a[:e] *= np.linspace(0, 1, e)[:, None]
            a[-e:] *= np.linspace(1, 0, e)[:, None]
        g = 0.55 if s["clip"].startswith("cd_") else 0.5
        put(fx, a, s["t0"], g)
    # logo: explosão grande + acorde de guitarra + prato
    t_logo = bt(72)
    boom = os.path.join(GAME, "sfx", "boom_2.ogg")
    if os.path.exists(boom):
        put(fx, load_audio(boom), t_logo, 0.9)
    for nm, g in (("guit_e_fifths.flac", 0.55), ("drum_cymbal_hard.flac", 0.5)):
        p = os.path.join(samples, nm)
        if os.path.exists(p):
            put(fx, load_audio(p), t_logo, g)
    mix = mus * 0.62 + vo + fx
    # limitador simples: compressão suave dos picos e pico final em -1 dBFS
    mix = np.tanh(mix * 1.1) / np.tanh(1.1)
    mix *= 10 ** (-2.5 / 20) / max(1e-6, np.abs(mix).max())   # folga para o AAC (sem picos acima de 0 dB)
    mix = mix[: int(END * SR)]
    pcm = (np.clip(mix, -1, 1) * 32767).astype("<i2")
    with wave.open(out_wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", default="en")
    ap.add_argument("--rec", required=True)
    ap.add_argument("--cards", required=True)
    ap.add_argument("--narr", required=True)
    ap.add_argument("--samples", default="")
    ap.add_argument("--music", default=os.path.join(GAME, "music", "boss.ogg"))
    ap.add_argument("--out", required=True)
    ap.add_argument("--plan-only", action="store_true")
    a = ap.parse_args()
    narr_d = json.load(open(os.path.join(a.narr, "narr.json")))
    shots, cards, voice = plan(a.lang, a.rec, narr_d)
    for s in shots:
        s["rec"] = a.rec
    for s in sorted(shots, key=lambda s: s["t0"]):
        print("%6.2f-%6.2f  %-12s quadro %5d  %s" % (s["t0"], s["t1"], s["clip"], s["f0"], s["fx"]))
    if a.plan_only:
        return
    wav = a.out + ".wav"
    render_audio(shots, voice, a.lang, a.narr, a.samples, a.music, wav)
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H), "-r", str(FPS),
           "-i", "-", "-i", wav, "-c:v", "libx264", "-preset", "slow", "-crf", "21", "-maxrate", "10M", "-bufsize", "20M", "-pix_fmt", "yuv420p",
           "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", a.out]
    render_video(shots, cards, a.cards, a.rec, cmd)
    os.remove(wav)
    print("ok:", a.out)


if __name__ == "__main__":
    main()

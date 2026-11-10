"""
Wreck 'n' Roll: falas do narrador DECIBEL com voz EXPRESSIVA (substitui o Kokoro de tools/build_voice.py).

O Kokoro lê o texto com entonação de leitura: soava "IA" e pouco animado. Aqui a voz é do Chatterbox
Multilingual (Resemble AI, licença MIT), um modelo com controle de EXAGERO de emoção: exaggeration alta e
cfg_weight baixo dão a fala gritada e cheia de altos e baixos de um locutor de arena (é o ajuste que o próprio
modelo recomenda para fala expressiva). O timbre vem de um trecho de referência sintético (tools/decibel_ref_*.wav,
vozes do Kokoro: nenhuma voz de pessoa real é clonada).

Cada fala é gerada até 3 vezes; o Whisper (faster-whisper) transcreve e fica a tomada que bate com o texto
(com emoção no máximo o modelo às vezes repete ou engole palavras). Depois vem o mesmo tratamento leve de
build_voice.py (equalização, compressão, ambiência curta e as vinhetas de guitarra/prato).

Uso (ambiente com chatterbox-tts e faster-whisper):
    python tools/build_voice_cb.py PASTA_DAS_AMOSTRAS voice scripts/voice_lines.gd
    ONLY=intro,lead python tools/build_voice_cb.py ...      (refaz só essas chaves)
    TRAILER=PASTA python tools/build_voice_cb.py ...         (só as falas do trailer, em PASTA/<idioma>_<chave>.wav)
"""
import difflib
import json
import os
import re
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_voice as bv  # noqa: E402
import trailer_voice as tv  # noqa: E402

EXAG = 0.85     # emoção (0,5 = neutro; acima de ~1 começa a repetir palavras)
CFG = 0.3       # menor = fala mais solta e menos "lida"
TEMP = 0.8
TRIES = 2
# palavras soltas da contagem: alongadas como um locutor faz (e o modelo não trava em uma sílaba só)
LONG = {"Um!": "Uuuum!", "Dois!": "Dooois!", "Três!": "Trêêês!", "One!": "Ooone!", "Two!": "Twooo!", "Three!": "Threeee!"}


def norm(s):
    # o nome do jogo fica de fora da comparação (o reconhecedor escreve cada vez de um jeito)
    s = s.lower().replace("wreck 'n' roll", " ")
    w = re.sub(r"[^a-z0-9à-úç ]+", " ", s).split()
    return [x for x in w if x not in ("wreck", "n", "and", "roll", "rock", "réquen", "rôu", "hacking", "hole")]


class Gen:
    def __init__(self):
        import perth
        import torch
        if getattr(perth, "PerthImplicitWatermarker", None) is None:
            perth.PerthImplicitWatermarker = perth.DummyWatermarker
        from chatterbox.mtl_tts import ChatterboxMultilingualTTS
        from faster_whisper import WhisperModel
        torch.set_num_threads(os.cpu_count() or 4)
        self.torch = torch
        self.tts = ChatterboxMultilingualTTS.from_pretrained(device="cpu")
        self.asr = WhisperModel("small", device="cpu", compute_type="int8")

    def _hear(self, x, sr, lang):
        import subprocess
        y = np.frombuffer(subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(sr), "-ac", "1", "-i", "-",
                                          "-ar", "16000", "-f", "f32le", "-"], input=x.tobytes(), capture_output=True,
                                         check=True).stdout, np.float32).copy()
        seg, _ = self.asr.transcribe(y.astype(np.float32), language=lang)
        return " ".join(s.text for s in seg)

    def say(self, text, lang):
        spoken = LONG.get(text, text)
        for a, b in bv.SAY_TEXT.get(lang, []):
            spoken = spoken.replace(a, b)
        ref = os.path.join(HERE, "decibel_ref_%s.wav" % lang)
        best = None
        short = len(norm(text)) <= 2
        for k in range(TRIES + (3 if short else 0)):
            self.torch.manual_seed(1000 + k * 77 + len(text))
            # palavra solta ("Um!") às vezes trava o modelo ou sai embolada: alonga a vogal como locutor ("Uuum!")
            say_txt = spoken if k < 2 or not short else re.sub(r"([aeiouáéíóúãõê])", r"\1\1\1", spoken, count=1, flags=re.I)
            try:
                w = self.tts.generate(say_txt, language_id=lang, audio_prompt_path=ref, exaggeration=EXAG,
                                      cfg_weight=CFG, temperature=TEMP)
            except (IndexError, RuntimeError) as e:
                print("   (falhou: %s)" % e, flush=True)
                continue
            x = w.squeeze(0).cpu().numpy().astype(np.float32)
            heard = self._hear(x, self.tts.sr, lang)
            a, b = norm(text), norm(heard)
            sim = difflib.SequenceMatcher(None, a, b).ratio()
            # fala esticada demais = repetiu ou travou
            dur = len(x) / self.tts.sr
            slow = dur > 1.5 + 0.45 * len(a)
            score = sim - (0.3 if slow else 0.0)
            if best is None or score > best[0]:
                best = (score, x, heard)
            if sim >= 0.85 and not slow:
                break
        if best is None:
            raise RuntimeError("não deu para gerar: " + text)
        print("   %.2f  %s  <- ouvido: %s" % (best[0], text, best[2].strip()), flush=True)
        return best[1], self.tts.sr


def process(g, text, lang, key, smp):
    x, sr = g.say(text, lang)
    v = bv.voice_fx(x, sr)
    if key in bv.STING and smp:
        v = bv.mix_sting(v, bv.STING[key], smp)
    return bv.level(v)


def main():
    smp_dir, out_dir, gd_out = sys.argv[1:4]
    g = Gen()
    smp = None
    if os.path.isdir(smp_dir):
        smp = {"fifths": bv.dec(os.path.join(smp_dir, "guit_e_fifths.flac")), "slide": bv.dec(os.path.join(smp_dir, "guit_e_slide.flac")),
               "crash": bv.dec(os.path.join(smp_dir, "drum_cymbal_hard.flac"))}
    tdir = os.environ.get("TRAILER", "")
    if tdir:
        os.makedirs(tdir, exist_ok=True)
        durs = {}
        for key, (en, pt) in tv.LINES.items():
            for lang, text in (("en", en), ("pt", pt)):
                v = process(g, text, lang, "", None)
                tv.save_wav(v, os.path.join(tdir, "%s_%s.wav" % (lang, key)))
                durs["%s_%s" % (lang, key)] = round(len(v) / bv.SR, 3)
        json.dump(durs, open(os.path.join(tdir, "narr.json"), "w"), indent=1)
        return
    only = [x for x in os.environ.get("ONLY", "").split(",") if x]
    old = {}
    if os.path.exists(gd_out):
        for ln in open(gd_out, encoding="utf-8"):
            if ln.startswith('\t"'):
                old[ln.split('"')[1]] = ln.rstrip("\n")
    rows = []
    for key, lines in bv.LINES.items():
        if only and key not in only and key in old:
            rows.append(old[key])
            continue
        print(key, flush=True)
        items = []
        for n, (en, pt) in enumerate(lines):
            durs = {}
            for lang, text in (("en", en), ("pt", pt)):
                v = process(g, text, lang, key, smp)
                os.makedirs(os.path.join(out_dir, lang), exist_ok=True)
                bv.encode(v, os.path.join(out_dir, lang, "%s_%d.ogg" % (key, n)))
                durs[lang] = len(v) / bv.SR
            items.append("[%s, %s, %.2f, %.2f]" % (bv.gd(pt), bv.gd(en), durs["en"], durs["pt"]))
        rows.append("\t%s: [%s]," % (bv.gd(key), ", ".join(items)))
        # grava a cada chave (dá para interromper e continuar com ONLY)
        with open(gd_out, "w", encoding="utf-8") as fh:
            fh.write("class_name VoiceLines\n")
            fh.write("## Gerado por tools/build_voice_cb.py (não edite à mão): falas do narrador DECIBEL.\n")
            fh.write("## chave -> [[fala em português, fala em inglês, duração em inglês (s), duração em português (s)], ...]\n")
            done = {r.split('"')[1]: r for r in rows}
            rest = [old[k] for k in old if k not in done]
            fh.write("const LINES := {\n" + "\n".join(rows + rest) + "\n}\n")
    print("ok")


if __name__ == "__main__":
    main()

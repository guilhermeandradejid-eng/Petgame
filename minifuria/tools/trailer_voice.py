"""
Wreck 'n' Roll: narração do trailer (DECIBEL), em inglês e português, com a mesma voz e o mesmo tratamento
das falas do jogo (tools/build_voice.py: Kokoro-82M, am_fenrir / pm_santa, pronúncia ajustada do título).

Uso (no ambiente com kokoro-onnx):
    python tools/trailer_voice.py PASTA_DO_MODELO PASTA_DE_SAIDA
Gera PASTA_DE_SAIDA/<idioma>_<chave>.wav (44,1 kHz, mono) e PASTA_DE_SAIDA/narr.json com as durações.
"""
import json
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_voice as bv  # noqa: E402

# chave: (inglês, português) — na ordem em que entram no trailer
LINES = {
    "n1": ("Ladies and gentlemen... start your weapons!", "Senhoras e senhores... liguem suas armas!"),
    "n2": ("Twenty-six tracks of pure chaos!", "Vinte e seis pistas de puro caos!"),
    "n3": ("Rockets! Mines! Lasers! No rules out here!", "Foguetes! Minas! Laser! Aqui não tem regra!"),
    "n4": ("And the bosses? They are HUGE!", "E os chefes? São GIGANTES!"),
    "n5": ("Grab your friends... same screen!", "Chama a galera... na mesma tela!"),
    "n6": ("Upgrade it! Arm it! Wreck it!", "Turbina! Arma! E destrói!"),
    "n7": ("Wreck 'n' Roll! Crank it up!", "Wreck 'n' Roll! Aumenta o som!"),
}


def save_wav(x, path):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(bv.SR)
        w.writeframes(pcm.tobytes())


def main():
    model_dir, out = sys.argv[1:3]
    os.makedirs(out, exist_ok=True)
    from kokoro_onnx import Kokoro
    k = Kokoro(os.path.join(model_dir, bv.MODEL), os.path.join(model_dir, "voices-v1.0.bin"))
    durs = {}
    for key, (en, pt) in LINES.items():
        for lang, text in (("en", en), ("pt", pt)):
            s, sr = bv.speak(k, text, lang)
            v = bv.level(bv.voice_fx(s, sr))
            save_wav(v, os.path.join(out, "%s_%s.wav" % (lang, key)))
            durs["%s_%s" % (lang, key)] = round(len(v) / bv.SR, 3)
    with open(os.path.join(out, "narr.json"), "w") as fh:
        json.dump(durs, fh, indent=1)
    print(durs)


if __name__ == "__main__":
    main()

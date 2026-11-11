"""
Wreck 'n' Roll: gera as falas do narrador DECIBEL (pasta voice/), locutor de arena no estilo rock and roll.

Voz sintetizada por IA: Kokoro-82M (Apache 2.0, hexgrad) via kokoro-onnx (MIT). Arquivos do modelo em
github.com/thewh1teagle/kokoro-onnx/releases (model-files-v1.0: kokoro-v1.0.fp16.onnx e voices-v1.0.bin).
  - inglês (padrão, como os jogos de corrida clássicos): voz am_fenrir — a mais expressiva das vozes masculinas
    (variação de entonação ~3,9 semitons contra ~2,7 da voz em português usada antes);
  - português (opção nas configurações): voz pm_santa.
Cada fala tem o texto em inglês (falado) e em português (legenda na tela; e a fala da versão em português).

Tratamento LIMPO (a versão anterior soava robótica: a mudança de tom por esticamento de tempo e a voz
dobrada criavam o "chiado metálico"): a voz sai como o modelo gera, só com equalização leve, compressão suave
e uma ambiência curta de sala; nos momentos grandes, guitarra elétrica de verdade (acorde em quintas, slide)
ou prato de bateria entra antes da voz e abaixa por baixo dela. Guitarra e prato: amostras CC0 do Sonic Pi
(github.com/sonic-pi-net/sonic-pi, etc/samples: guit_e_fifths, guit_e_slide, drum_cymbal_hard).

Uso:
    pip install kokoro-onnx soundfile        (e ffmpeg no sistema)
    python tools/build_voice.py PASTA_DO_MODELO PASTA_DAS_AMOSTRAS voice scripts/voice_lines.gd
    ONLY=intro,go python tools/build_voice.py ...   (refaz só essas chaves e mantém as outras no .gd)
"""
import os
import subprocess
import sys

import numpy as np

SR = 44100

# chave: [(inglês, português), ...]
# Estilo: locutor desbocado, agressivo e engraçado, que zoa todo mundo (validado pelo dono do jogo).
LINES = {
    "intro": [
        ('Alright, you bunch of maniacs! Time to break some cars!', 'Bora, cambada de maluco! Hora de quebrar carro!'),
        ("Five idiots, one track, zero brains! Let's go!", 'Cinco doidos, uma pista e nenhum juízo! Partiu!'),
        ("Buckle up, losers! Somebody's going home in a bucket!", 'Aperta o cinto, bando de barbeiro! Alguém vai pra casa num balde!'),
        ('No rules, no brakes, no mercy! Floor it!', 'Sem regra, sem freio, sem dó! Mete o pé!'),
    ],
    "count3": [
        ('Three!', 'Três!'),
    ],
    "count2": [
        ('Two!', 'Dois!'),
    ],
    "count1": [
        ('And one!', 'E agora, um!'),
    ],
    "go": [
        ('Go, go, go! Floor it!', 'Vai, vai, vai! Mete o pé!'),
        ('Hit the gas, you lunatics!', 'Acelera, seus malucos!'),
    ],
    "perfect_start": [
        ('Holy crap, what a launch!', 'Caramba, que largada!'),
        ("Left 'em eating dust!", 'Deixou geral comendo poeira!'),
    ],
    "lead": [
        ('First place! Suck it, everybody!', 'Primeiro lugar! Vem me pegar, se for capaz!'),
        ('Out in front! Eat my dust, losers!', 'Na frente! Come poeira, otário!'),
        ('Leading the pack and talking trash!', 'Liderando e tirando onda!'),
        ("Nobody's touching this guy!", 'Ninguém encosta nesse doido!'),
    ],
    "overtake": [
        ('Move it, grandpa!', 'Sai da frente, vovô!'),
        ('See ya, slowpoke!', 'Tchau, lesma!'),
        ('Passed him like he was parked!', 'Passou como se ele tivesse estacionado!'),
        ('Too slow, buddy!', 'Lerdo demais, parceiro!'),
    ],
    "overtaken": [
        ('Wake up, sleepyhead!', 'Acorda pra vida!'),
        ('Getting passed? Seriously?!', 'Tão te passando? Sério?!'),
        ('Hey! Was that a minivan?!', 'Ô! Te passaram de fusca?!'),
    ],
    "kill": [
        ('Boom! Eat that!', 'Toma! Engole essa!'),
        ('Scrap metal, baby!', 'Virou sucata, meu filho!'),
        ("Oh, that's gotta suck!", 'Ih, essa doeu na alma!'),
        ('Sent him straight to the junkyard!', 'Mandou direto pro ferro-velho!'),
        ('Go cry to your mommy!', 'Vai chorar pra mamãe!'),
        ('Total wreck! Ha!', 'Destruiu! Que vergonha pra ele!'),
    ],
    "killed": [
        ('You got owned!', 'Se ferrou bonito!'),
        ("Ouch! That's embarrassing!", 'Ai! Que vexame!'),
        ('Pieces everywhere! Nice driving, genius!', 'Pedaço pra todo lado! Belo piloto, gênio!'),
        ('Who taught you to drive, a toaster?!', 'Quem te ensinou a dirigir, uma torradeira?!'),
        ('Payback time! Get mad!', 'Hora da vingança! Fica bravo!'),
    ],
    "fall": [
        ('Off the edge! What an idiot!', 'Voou pra fora! Que mané!'),
        ('Where the hell is he going?!', 'Pra onde diabos ele vai?!'),
        ('Bye bye, dumbass!', 'Tchau, tchau, sem noção!'),
    ],
    "air": [
        ('Look at that idiot fly!', 'Olha o doido voando!'),
        ('Big air, baby!', 'Que pulo, meu filho!'),
        ('Airborne! Pray for the landing!', 'Decolou! Reza pra pousar!'),
    ],
    "drift": [
        ('Sideways like a boss!', 'De lado igual patrão!'),
        ('Burn that rubber!', 'Queima esse pneu!'),
    ],
    "nitro": [
        ('Nitro! Hold on to your butt!', 'Nitro! Segura a peruca!'),
        ('Punch it!', 'Pisa fundo!'),
    ],
    "lowhp": [
        ("That car's held together with gum!", 'Esse carro tá colado com chiclete!'),
        ("One more hit and you're toast!", 'Mais uma e já era!'),
    ],
    "final_lap": [
        ('Final lap! Now or never!', 'Última volta! É agora ou nunca!'),
        ("Last lap! Don't screw it up!", 'Última volta! Não vai fazer cagada!'),
        ('One lap left! Floor it!', 'Falta uma! Enfia o pé!'),
    ],
    "win": [
        ('Winner! Suck it, everybody!', 'Venceu! Atropelou geral!'),
        ('Checkered flag! Absolute legend!', 'Que corrida! Que monstro!'),
        ('Number one! Bow down!', 'Número um! Respeita!'),
        ('And the trophy goes to the maniac!', 'E o troféu vai pro maluco!'),
    ],
    "podium": [
        ('On the podium! Not bad, kid!', 'Subiu no pódio! Nada mal, moleque!'),
        ('Top three! Could be worse!', 'Entre os três! Podia ser pior!'),
    ],
    "lose": [
        ('That was pathetic!', 'Que vergonha, hein!'),
        ('Go home and practice!', 'Vai pra casa treinar!'),
        ('My grandma drives better!', 'Até minha avó dirige melhor!'),
    ],
    "boss_brutus": [
        ('Here comes Brutus! Run, you fools!', 'Lá vem o Brutus! Corre, seus doidos!'),
    ],
    "boss_croc": [
        ('The Croc is hungry! Hide your tires!', 'O Crocodilo tá com fome! Esconde os pneus!'),
    ],
    "boss_xerife": [
        ("The Sheriff's in town! You're all under arrest!", 'O Xerife chegou! Tá todo mundo preso!'),
    ],
    "boss_avalanche": [
        ('Avalanche! Freeze your butts off!', 'Avalanche! Vai congelar até a alma!'),
    ],
    "boss_blackout": [
        ('Blackout! Who forgot to pay the light bill?!', 'Blackout! Quem esqueceu de pagar a conta de luz?!'),
    ],
    "boss_imperador": [
        ("The Emperor's here! Kiss the asphalt!", 'O Imperador chegou! Beija o asfalto!'),
    ],
    "boss_attack": [
        ('Incoming! Duck!', 'Lá vem! Abaixa!'),
        ("He's pissed now!", 'Ele ficou puto!'),
        ('Watch your back, idiot!', 'Olha pra trás, mané!'),
    ],
    "boss_beaten": [
        ('The big guy is down! Hell yeah!', 'Derrubou o grandão! É isso aí!'),
        ('Giant slayer! Somebody call a tow truck!', 'Derrubou o gigante! Chama o guincho!'),
    ],
    "idle": [
        ('Come on, wreck something!', 'Vamos, quebra alguma coisa!'),
        ('This is boring! Hit somebody!', 'Tá chato! Bate em alguém!'),
        ('Smell that? Burning rubber and fear!', 'Sente o cheiro? Pneu queimado e medo!'),
    ],
}

# vinheta de rock antes da voz nos momentos grandes
STING = {"intro": "fifths", "win": "fifths", "boss_beaten": "fifths", "lead": "slide", "final_lap": "slide",
         "kill": "crash", "perfect_start": "crash", "podium": "crash"}
for _k in LINES:
    if _k.startswith("boss_") and _k not in ("boss_attack", "boss_beaten"):
        STING[_k] = "fifths"

# voz, velocidade, idioma (velocidade 1.0: acelerar o modelo também deixa a voz mais artificial)
VOICE = {"en": ("am_fenrir", 1.0, "en-us"), "pt": ("pm_santa", 1.0, "pt-br")}
MODEL = "kokoro-v1.0.onnx"   # precisão completa (a versão fp16 tem um pouco mais de artefato)


def dec(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def ff(x, sr, chain):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(sr), "-ac", "1", "-i", "-", "-af", chain,
                          "-ar", str(SR), "-ac", "1", "-f", "f32le", "-"], input=x.astype(np.float32).tobytes(),
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def rms(x):
    on = x[np.abs(x) > 0.01]
    return float(np.sqrt(np.mean(on ** 2))) if len(on) else 1e-3


def trim(x, thr=0.01):
    idx = np.where(np.abs(x) > thr)[0]
    if len(idx) == 0:
        return x
    return x[max(0, idx[0] - int(0.01 * SR)): idx[-1] + int(0.08 * SR)]


def conv(x, ir):
    n = len(x) + len(ir) - 1
    m = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m)[:n].astype(np.float32)


def room_ir():
    # ambiência curta (sala grande), sem eco marcado: só dá corpo à voz
    rng = np.random.default_rng(7)
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n).astype(np.float32) * np.exp(-t / 0.12)
    ir = np.convolve(ir, np.ones(11) / 11.0, mode="same")
    ir[: int(0.012 * SR)] = 0.0
    return ir / np.sqrt(np.sum(ir ** 2))


IR = room_ir()


def voice_fx(x, sr):
    chain = ("aresample=%d,highpass=f=80,equalizer=f=3000:t=o:w=1.0:g=2.5,"
             "acompressor=threshold=-20dB:ratio=2.5:attack=5:release=150:makeup=3" % SR)
    y = trim(ff(x, sr, chain))
    wet = conv(y, IR)
    out = np.zeros(len(wet), dtype=np.float32)
    out[: len(y)] += y
    out += wet * 0.1
    return out


def sting(kind, smp):
    if kind == "fifths":
        g = smp["fifths"][: int(2.6 * SR)].copy()
        delay = 0.56
    elif kind == "slide":
        g = smp["slide"][: int(1.8 * SR)].copy()
        delay = 0.28
    else:
        g = smp["crash"][: int(1.6 * SR)].copy()
        delay = 0.08
    g *= np.linspace(1.0, 0.0, len(g)) ** 1.5
    g *= 10 ** (-17 / 20.0) / rms(g)
    return g, delay


def mix_sting(v, kind, smp):
    g, delay = sting(kind, smp)
    d = int(delay * SR)
    n = max(len(g), d + len(v))
    out = np.zeros(n, dtype=np.float32)
    # a guitarra abaixa (-9 dB) quando a voz entra
    env = np.ones(len(g), dtype=np.float32)
    duck = 10 ** (-9 / 20.0)
    ramp = int(0.08 * SR)
    if d < len(g):
        env[d:] = duck
        env[max(0, d - ramp): d] = np.linspace(1.0, duck, d - max(0, d - ramp))
    out[: len(g)] += g * env
    out[d: d + len(v)] += v
    return out


def level(x, rms_db=-15.0, peak_db=-1.0):
    x = x * (10 ** (rms_db / 20.0) / rms(x))
    p = float(np.abs(x).max())
    if p > 10 ** (peak_db / 20.0):
        x = x * (10 ** (peak_db / 20.0) / p)
    fade = int(0.03 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x


def encode(x, out):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "4", out], input=np.clip(x, -1, 1).astype(np.float32).tobytes(), check=True)


# pronúncia: o texto da legenda fica igual; só o que a voz lê muda
SAY_TEXT = {"pt": [("Wreck 'n' Roll", "Réquen Rôu"), ("rock and roll", "róquen rôu"), ("Rock and roll", "Róquen rôu")]}
SAY_PHON = {"en": [("ɹˈɛk ˈɛn ɹˈoʊl", "ɹˈɛk ən ɹˈoʊl")]}


def speak(k, text, lang):
    """voz crua do Kokoro com as correções de pronúncia do título"""
    voice, speed, code = VOICE[lang]
    for a, b in SAY_TEXT.get(lang, []):
        text = text.replace(a, b)
    ph = k.tokenizer.phonemize(text, code)
    for a, b in SAY_PHON.get(lang, []):
        ph = ph.replace(a, b)
    s, sr = k.create(ph, voice=voice, speed=speed, lang=code, is_phonemes=True)
    return np.asarray(s, dtype=np.float32), sr


def gd(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    model_dir, smp_dir, out_dir, gd_out = sys.argv[1:5]
    from kokoro_onnx import Kokoro
    k = Kokoro(os.path.join(model_dir, MODEL), os.path.join(model_dir, "voices-v1.0.bin"))
    smp = {"fifths": dec(os.path.join(smp_dir, "guit_e_fifths.flac")), "slide": dec(os.path.join(smp_dir, "guit_e_slide.flac")),
           "crash": dec(os.path.join(smp_dir, "drum_cymbal_hard.flac"))}
    only = [x for x in os.environ.get("ONLY", "").split(",") if x]
    old = {}
    if only and os.path.exists(gd_out):
        for ln in open(gd_out, encoding="utf-8"):
            if ln.startswith('\t"'):
                old[ln.split('"')[1]] = ln.rstrip("\n")
    rows = []
    total = 0.0
    for key, lines in LINES.items():
        if only and key not in only and key in old:
            rows.append(old[key])
            continue
        items = []
        for n, (en, pt) in enumerate(lines):
            durs = {}
            for lang, text in (("en", en), ("pt", pt)):
                s, sr = speak(k, text, lang)
                v = voice_fx(s, sr)
                if key in STING:
                    v = mix_sting(v, STING[key], smp)
                v = level(v)
                os.makedirs(os.path.join(out_dir, lang), exist_ok=True)
                encode(v, os.path.join(out_dir, lang, "%s_%d.ogg" % (key, n)))
                durs[lang] = len(v) / SR
                total += durs[lang]
            items.append("[%s, %s, %.2f, %.2f]" % (gd(pt), gd(en), durs["en"], durs["pt"]))
        rows.append("\t%s: [%s]," % (gd(key), ", ".join(items)))
    with open(gd_out, "w", encoding="utf-8") as fh:
        fh.write("class_name VoiceLines\n")
        fh.write("## Gerado por tools/build_voice.py (não edite à mão): falas do narrador DECIBEL.\n")
        fh.write("## chave -> [[legenda em português, fala em inglês, duração em inglês (s), duração em português (s)], ...]\n")
        fh.write("const LINES := {\n" + "\n".join(rows) + "\n}\n")
    print("ok: %d falas x 2 idiomas, %.0f s de áudio" % (sum(len(v) for v in LINES.values()), total))


if __name__ == "__main__":
    main()

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
# Estilo: locutor esportivo empolgado de corrida de combate (falas curtas, rápidas, provocadoras). A
# personalidade vem da atitude, não de repetir "rock" ou o nome do jogo.
LINES = {
    "intro": [
        ("Here we go! Drivers, it's showtime!", "Atenção, pilotos! Hora do show!"),
        ("Ladies and gentlemen, start your engines, and your weapons!", "Senhoras e senhores, liguem os motores e as armas!"),
        ("Five cars, one winner! Let's go!", "Cinco carros, um vencedor! Vamos lá!"),
        ("No rules, no brakes! Let's race!", "Sem regras, sem freio! Valendo!"),
    ],
    "count3": [("Three!", "Três!")],
    "count2": [("Two!", "Dois!")],
    "count1": [("And one!", "E um!")],
    "go": [("Go, go, go!", "Vai, vai, vai!"), ("And they're off!", "E lá vão eles!")],
    "perfect_start": [("What a launch!", "Que largada!"), ("Rocket start!", "Saiu voando!")],
    "lead": [
        ("Taking the lead!", "Assumiu a liderança!"),
        ("Out in front!", "Na frente de todo mundo!"),
        ("First place, baby!", "Primeiro lugar, meu amigo!"),
        ("Nobody can catch him now!", "Ninguém segura agora!"),
        ("Leading the pack!", "Lidera o pelotão!"),
    ],
    "overtake": [
        ("Nice pass!", "Que ultrapassagem!"),
        ("Coming through!", "Passou por dentro!"),
        ("See ya!", "Tchau, tchau!"),
        ("Blew right past him!", "Passou voando!"),
        ("Too easy!", "Fácil demais!"),
    ],
    "overtaken": [
        ("Lost a spot!", "Perdeu uma posição!"),
        ("Wake up out there!", "Acorda aí!"),
        ("He's getting away!", "Tá fugindo!"),
        ("Don't let him go!", "Não deixa escapar!"),
    ],
    "kill": [
        ("Ooh, that's gotta hurt!", "Ih, essa doeu!"),
        ("Scrap metal!", "Virou ferro-velho!"),
        ("Boom! Got him!", "Explodiu! Pegou!"),
        ("Total wreck!", "Destruição total!"),
        ("He's toast!", "Já era!"),
        ("Right in the bumper!", "Bem no para-choque!"),
    ],
    "killed": [
        ("You got wrecked!", "Destruído!"),
        ("Ouch! Back to the shop!", "Ai! Desmontou todo!"),
        ("That was ugly!", "Que feio!"),
        ("Pieces everywhere!", "Pedaço pra todo lado!"),
        ("Revenge time!", "Hora da vingança!"),
    ],
    "fall": [
        ("Off the edge!", "Voou pra fora!"),
        ("Where's he going?!", "Pra onde ele vai?!"),
        ("Long way down!", "Lá embaixo!"),
        ("Gravity wins!", "A gravidade venceu!"),
    ],
    "air": [
        ("Big air!", "Que salto!"),
        ("Look at him fly!", "Olha ele voando!"),
        ("Airborne!", "Decolou!"),
        ("Sky high!", "Lá no alto!"),
    ],
    "drift": [("Sideways!", "De lado!"), ("Look at that drift!", "Que derrapada!"), ("Smoking those tires!", "Queimando pneu!")],
    "nitro": [("Nitro!", "Nitro!"), ("Punch it!", "Pisa fundo!"), ("Hold on tight!", "Segura firme!"), ("Full throttle!", "Acelerador no talo!")],
    "lowhp": [("He's smoking bad!", "Tá soltando fumaça!"), ("One more hit and he's done!", "Mais uma e acabou!"), ("Hanging by a thread!", "Por um fio!")],
    "final_lap": [
        ("Final lap!", "Última volta!"),
        ("Last lap, it's now or never!", "Última volta, é agora ou nunca!"),
        ("One lap to go!", "Falta uma volta!"),
        ("Here comes the final lap!", "Lá vem a última volta!"),
    ],
    "win": [
        ("Winner!", "Vencedor!"),
        ("And he takes it!", "E leva a corrida!"),
        ("Checkered flag! What a race!", "Bandeirada! Que corrida!"),
        ("Number one!", "Número um!"),
        ("Unbeatable!", "Imbatível!"),
    ],
    "podium": [("On the podium!", "No pódio!"), ("Not bad at all!", "Nada mal!"), ("Top three!", "Entre os três!")],
    "lose": [
        ("Better luck next time!", "Fica pra próxima!"),
        ("Ouch, not his day!", "Não foi o dia dele!"),
        ("Back to the garage!", "Volta pra garagem!"),
        ("He'll be back!", "Ele vai voltar!"),
    ],
    "boss_brutus": [("Here comes Brutus! Get out of the way!", "Lá vem o Brutus! Sai da frente!")],
    "boss_croc": [("The Croc is hungry!", "O Crocodilo tá com fome!")],
    "boss_xerife": [("The Sheriff is in town!", "O Xerife chegou!")],
    "boss_avalanche": [("Avalanche! Watch the ice!", "Avalanche! Cuidado com o gelo!")],
    "boss_blackout": [("Blackout! Lights out!", "Blackout! Apagaram as luzes!")],
    "boss_imperador": [("The Emperor is here! Bow down!", "O Imperador chegou! Abram caminho!")],
    "boss_attack": [("Incoming!", "Lá vem!"), ("Watch out!", "Cuidado!"), ("He's mad now!", "Ele ficou bravo!"), ("Look out, look out!", "Olha, olha!")],
    "boss_beaten": [("The boss is down!", "Derrubou o chefe!"), ("No way! He did it!", "Inacreditável!"), ("Giant slayer!", "Derrubou o gigante!")],
    "idle": [
        ("The crowd wants blood!", "A galera quer pancada!"),
        ("Somebody make a move!", "Alguém faz alguma coisa!"),
        ("Smell that burning rubber!", "Que cheiro de pneu queimado!"),
        ("This is getting good!", "Tá ficando bom!"),
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

"""
Mini Fúria: gera as falas do narrador DECIBEL (pasta voice/), locutor de arena no estilo rock and roll.

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
"""
import os
import subprocess
import sys

import numpy as np

SR = 44100

# chave: [(inglês falado, português), ...]
LINES = {
    "intro": [
        ("Welcome to Mini Fury! Tonight, somebody goes home in a bucket!", "Bem-vindos à Mini Fúria! Hoje alguém volta pra casa num balde!"),
        ("Crank it up! It's time to rock and roll... and wreck and roll!", "Aumenta o som! Hora do rock and roll... e do pancadão sobre rodas!"),
        ("No rules! No brakes! No mercy! Let's ride!", "Sem regras! Sem freio! Sem piedade! Bora!"),
        ("The crowd is screaming, the engines are screaming, and soon, the drivers will be screaming!", "A galera grita, os motores gritam... e daqui a pouco os pilotos também!"),
        ("Ladies and gentlemen, lock and load! This is gonna be loud!", "Senhoras e senhores, armas carregadas! Isso vai ser barulhento!"),
        ("Gentlemen, start your weapons!", "Senhores, liguem suas armas!"),
    ],
    "count3": [("Three!", "Três!")],
    "count2": [("Two!", "Dois!")],
    "count1": [("One!", "Um!")],
    "go": [("Go, go, go!", "Vai, vai, vai!"), ("Rock and roll!", "Rock and roll!")],
    "perfect_start": [("What a launch!", "Que largada!"), ("Out of the gate like a cannonball!", "Saiu que nem bala de canhão!")],
    "lead": [
        ("Taking the lead! Nobody can touch this!", "Assumiu a ponta! Ninguém encosta!"),
        ("Number one, baby! Number one!", "Número um, baby! Número um!"),
        ("Leader of the pack! Rock on!", "Líder do bando! Rock on!"),
        ("First place! Eat my dust!", "Primeiro lugar! Come poeira!"),
        ("Out in front and rocking hard!", "Na frente e no volume máximo!"),
    ],
    "overtake": [
        ("Passing! See ya, slowpoke!", "Ultrapassou! Tchau, lerdo!"),
        ("Blew right past him!", "Passou voando!"),
        ("Move over! Coming through!", "Sai da frente! Passando!"),
        ("Another one bites the asphalt!", "Mais um comeu asfalto!"),
        ("Smooth move, rocker!", "Bela manobra, roqueiro!"),
    ],
    "overtaken": [
        ("Ouch! Lost a spot!", "Ai! Perdeu uma posição!"),
        ("Getting passed! Wake up out there!", "Tão te passando! Acorda!"),
        ("Don't just sit there, hit the gas!", "Não fica parado, pisa fundo!"),
        ("Dropping back! That's ugly!", "Ficando pra trás! Que feio!"),
        ("Somebody just stole your lunch!", "Roubaram teu lanche!"),
    ],
    "kill": [
        ("Boom! Scrap metal!", "Bum! Virou sucata!"),
        ("Kaboom! Send in the tow truck!", "Cabum! Chama o guincho!"),
        ("Blown to bits! I love it!", "Explodiu em pedacinhos! Eu adoro!"),
        ("Total destruction!", "Destruição total!"),
        ("That's gonna leave a mark!", "Isso vai deixar marca!"),
        ("Turned him into a tin can!", "Virou latinha!"),
    ],
    "killed": [
        ("You got wrecked!", "Te destruíram!"),
        ("Busted! Back to the pits!", "Já era! De volta pros boxes!"),
        ("Ooh, that's a bad day at the office!", "Ih, dia ruim no trabalho!"),
        ("Wrecked! But the show must go on!", "Destruído! Mas o show tem que continuar!"),
        ("Ka-blammo! Somebody call your mama!", "Cabrum! Alguém liga pra tua mãe!"),
    ],
    "fall": [
        ("Off the edge! Bye bye!", "Caiu da beirada! Tchau tchau!"),
        ("Flying lessons, anyone?", "Alguém quer aula de voo?"),
        ("Gravity wins again!", "A gravidade venceu de novo!"),
        ("That's a long way down!", "Que tombo!"),
    ],
    "air": [
        ("Big air! Look at him fly!", "Pulão! Olha ele voando!"),
        ("Hang time, baby!", "Tempo no ar, baby!"),
        ("Sky high!", "Lá nas alturas!"),
        ("Somebody get this driver a pilot's license!", "Alguém dá um brevê pra esse piloto!"),
    ],
    "drift": [
        ("Sideways and stylish!", "De lado e com estilo!"),
        ("Look at that slide!", "Olha essa derrapada!"),
        ("Smoking tires!", "Pneu fumegando!"),
    ],
    "nitro": [
        ("Nitro! Hold on to your hair!", "Nitro! Segura o cabelo!"),
        ("Light it up!", "Acende o turbo!"),
        ("Full throttle!", "Pé no fundo!"),
        ("Burning rubber!", "Queimando borracha!"),
    ],
    "lowhp": [
        ("That car is held together with duct tape!", "Esse carro tá colado com fita!"),
        ("Smoke is pouring out! Careful!", "Saindo fumaça! Cuidado!"),
        ("One more hit and it's game over!", "Mais uma pancada e acabou!"),
    ],
    "final_lap": [
        ("Final lap! Now or never!", "Última volta! Agora ou nunca!"),
        ("Last lap! Floor it!", "Última volta! Afunda o pé!"),
        ("One lap to go! Give it everything!", "Falta uma volta! Dá tudo!"),
        ("Final lap! Rock and roll!", "Última volta! Rock and roll!"),
    ],
    "win": [
        ("Winner! Rock and roll champion!", "Vencedor! Campeão do rock and roll!"),
        ("Victory! The crowd goes wild!", "Vitória! A galera enlouquece!"),
        ("Number one! What a race!", "Número um! Que corrida!"),
        ("Champion! Crank up the music!", "Campeão! Aumenta o som!"),
        ("And the winner is... you! Yeah!", "E o vencedor é... você! Yeah!"),
    ],
    "podium": [
        ("On the podium! Not bad, rocker!", "No pódio! Nada mal, roqueiro!"),
        ("Podium finish! So close!", "Pódio! Faltou pouco!"),
        ("Medal time! Next time, the gold!", "Medalha no peito! Na próxima, o ouro!"),
    ],
    "lose": [
        ("Out of the medals! Better luck next time!", "Fora do pódio! Mais sorte na próxima!"),
        ("Not your day, rocker! Back to the garage!", "Não foi teu dia, roqueiro! Volta pra garagem!"),
        ("Ouch! Time for some upgrades!", "Ai! Hora de comprar uns upgrades!"),
        ("You finished! That counts... right?", "Terminou! Isso conta... né?"),
    ],
    "boss_brutus": [("Brutus is on the track! Run for your lives!", "O Brutus tá na pista! Salve-se quem puder!")],
    "boss_croc": [("The Swamp Croc is hungry! Watch your tires!", "O Crocodilo do Brejo tá com fome! Cuida dos pneus!")],
    "boss_xerife": [("The Iron Sheriff is in town! Nobody breaks the law but him!", "O Xerife de Aço chegou! Só ele pode quebrar a lei!")],
    "boss_avalanche": [("Avalanche incoming! Bundle up, rockers!", "Lá vem a Avalanche! Se agasalhem, roqueiros!")],
    "boss_blackout": [("Blackout! Somebody forgot to pay the light bill!", "Blackout! Alguém esqueceu de pagar a conta de luz!")],
    "boss_imperador": [("Bow down! The Emperor has entered the arena!", "Curvem-se! O Imperador entrou na arena!")],
    "boss_attack": [
        ("Incoming! The boss is mad!", "Lá vem! O chefe tá bravo!"),
        ("Watch out! Here comes the pain!", "Cuidado! Lá vem dor!"),
        ("Dodge it! Dodge it!", "Desvia! Desvia!"),
        ("Boss attack! Move it!", "Ataque do chefe! Sai daí!"),
    ],
    "boss_beaten": [
        ("The boss is down! Unbelievable!", "O chefe caiu! Inacreditável!"),
        ("You beat the boss! Legend!", "Venceu o chefe! Lenda!"),
        ("Boss destroyed! Long live rock!", "Chefe destruído! Viva o rock!"),
    ],
    "idle": [
        ("I love the smell of burning rubber!", "Adoro cheiro de borracha queimada!"),
        ("Is this a race or a demolition derby? Both!", "Isso é corrida ou demolição? Os dois!"),
        ("Turn it up! Louder!", "Aumenta! Mais alto!"),
        ("Rock and roll never dies... but cars do!", "O rock nunca morre... mas os carros sim!"),
        ("Keep the pedal down and the volume up!", "Pé embaixo e volume lá em cima!"),
        ("The crowd wants blood... and spare parts!", "A galera quer sangue... e peças de reposição!"),
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


def gd(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    model_dir, smp_dir, out_dir, gd_out = sys.argv[1:5]
    from kokoro_onnx import Kokoro
    k = Kokoro(os.path.join(model_dir, MODEL), os.path.join(model_dir, "voices-v1.0.bin"))
    smp = {"fifths": dec(os.path.join(smp_dir, "guit_e_fifths.flac")), "slide": dec(os.path.join(smp_dir, "guit_e_slide.flac")),
           "crash": dec(os.path.join(smp_dir, "drum_cymbal_hard.flac"))}
    rows = []
    total = 0.0
    for key, lines in LINES.items():
        items = []
        for n, (en, pt) in enumerate(lines):
            durs = {}
            for lang, text in (("en", en), ("pt", pt)):
                voice, speed, code = VOICE[lang]
                s, sr = k.create(text, voice=voice, speed=speed, lang=code)
                v = voice_fx(np.asarray(s, dtype=np.float32), sr)
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

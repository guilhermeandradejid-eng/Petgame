"""
Mini Fúria: gera as falas do NARRADOR (pasta voice/) com voz sintetizada por IA, em português do Brasil.

Personagens (originais):
  ZECA TURBO  - narrador empolgado e exagerado (voz pm_alex do Kokoro, mais rápida, com "som de estádio":
                equalização de alto-falante, compressão e um eco curto)
  TIA GRAXA   - mecânica sarcástica que comenta pelo rádio (voz pf_dora, com filtro de rádio)

Voz: Kokoro-82M (Apache 2.0, hexgrad) rodando pelo kokoro-onnx (MIT). Arquivos do modelo em
github.com/thewh1teagle/kokoro-onnx/releases (model-files-v1.0: kokoro-v1.0.fp16.onnx e voices-v1.0.bin).

Uso:
    pip install kokoro-onnx soundfile        (e ffmpeg no sistema)
    python tools/build_voice.py PASTA_DO_MODELO voice scripts/voice_lines.gd

Saída: voice/<chave>_<n>.ogg e scripts/voice_lines.gd (tabela com o texto de cada fala, usada pela legenda).
"""
import os
import subprocess
import sys

import numpy as np

# ------------------------------------------------------------------ roteiro
# chave: [(quem, texto), ...]   — "z" = Zeca Turbo, "g" = Tia Graxa
LINES = {
    "intro": [
        ("z", "Senhoras e senhores, apertem os cintos e soltem os parafusos! Vai começar a Mini Fúria!"),
        ("z", "Boa noite, boa tarde, bom dia, sei lá! O que importa é que tem corrida!"),
        ("z", "Motores roncando, para-choques tremendo... hoje alguém volta pra casa de guincho!"),
        ("z", "Bem-vindos à corrida onde a regra é clara: não tem regra!"),
        ("z", "O seguro não cobre, a mãe não sabe, e a pista tá pronta! Vamos nessa!"),
        ("z", "Respirem fundo, pilotos! Hoje o asfalto vai pedir socorro!"),
    ],
    "count3": [("z", "Três!")],
    "count2": [("z", "Dois!")],
    "count1": [("z", "Um!")],
    "go": [("z", "Acelera!"), ("z", "Vai, vai, vai!")],
    "perfect_start": [
        ("z", "Largada perfeita! Saiu que nem foguete!"),
        ("z", "Que largada! Deixou a turma na saudade!"),
    ],
    "lead": [
        ("z", "E assumiu a liderança! Olha esse carrinho voando baixo!"),
        ("z", "Primeiro lugar! Alguém avisa os outros que a corrida já começou!"),
        ("z", "Ponta da corrida! Tá deixando todo mundo comendo poeira!"),
        ("z", "Lá na frente! Esse aí almoçou turbina!"),
        ("z", "Liderança! E o retrovisor só serve pra ver os outros chorando!"),
    ],
    "overtake": [
        ("z", "Ultrapassou! Com licença, com licença, passando!"),
        ("z", "Passou por fora! Nem deu tchau!"),
        ("z", "Mais um pra trás! A fila andou!"),
        ("z", "Ultrapassagem bonita! Pena que o outro nem viu."),
        ("z", "Subiu uma posição! A mãe tá orgulhosa!"),
    ],
    "overtaken": [
        ("z", "Opa, perdeu a posição! Acorda, piloto!"),
        ("z", "Levou uma ultrapassagem! Isso doeu no orgulho!"),
        ("z", "Ficou pra trás! Quer que eu chame um táxi?"),
        ("z", "Passaram por você que nem se você fosse um cone!"),
        ("z", "Caiu uma posição! Pisa nesse acelerador, criatura!"),
    ],
    "kill": [
        ("z", "Kabum! Mandou direto pro ferro-velho!"),
        ("z", "Destruído! Alguém junta as peças, por favor!"),
        ("z", "Olha a explosão! Isso aí vai virar latinha!"),
        ("z", "Pá! Pum! Acabou! Próximo!"),
        ("z", "Desmontou o adversário! Agora é kit de montar!"),
        ("z", "Que pancada! O seguro desse aí vai lá nas alturas!"),
    ],
    "killed": [
        ("z", "Ih, virou sucata! Mas calma, a gente tem peça de reposição!"),
        ("z", "Explodiu! Pelo menos foi bonito!"),
        ("z", "Destruído! Alguém chama o guincho!"),
        ("z", "Ai, ai, ai! Isso vai sair caro na oficina!"),
        ("z", "Já era! Mas volta logo, piloto, que a corrida não para!"),
    ],
    "fall": [
        ("z", "Saiu voando da pista! Isso aqui não é aeroporto!"),
        ("z", "Caiu! Tchau, asfalto! Oi, gravidade!"),
        ("z", "Lá se vai ele, ladeira abaixo! Volta, volta!"),
        ("z", "Despencou! Alguém esqueceu de frear!"),
        ("z", "Pulou fora da pista! Achou um atalho pro chão!"),
    ],
    "air": [
        ("z", "Voa, passarinho! Olha a altura disso!"),
        ("z", "Decolou! Já pode pedir o lanchinho de bordo!"),
        ("z", "Que salto! Os jurados dão nota dez!"),
        ("z", "Ficou mais tempo no ar do que no chão!"),
    ],
    "drift": [
        ("z", "Que drift! De lado é mais bonito!"),
        ("z", "Olha essa derrapada! O pneu tá chorando!"),
        ("z", "Desliza que é uma beleza! Parece novela!"),
    ],
    "nitro": [
        ("z", "Nitro na veia!"),
        ("z", "Botou fogo no escapamento!"),
        ("z", "Turbo ligado! Segura o cabelo!"),
        ("z", "Chama no nitro e reza!"),
    ],
    "lowhp": [
        ("z", "Tá saindo fumaça até da buzina! Cuidado!"),
        ("z", "Esse carro tá segurando com fita adesiva!"),
        ("z", "Mais uma batida e vira bicicleta!"),
    ],
    "final_lap": [
        ("z", "Última volta! Quem piscar, perdeu!"),
        ("z", "É a última volta! Agora é tudo ou nada!"),
        ("z", "Última volta, pessoal! Esqueçam os freios!"),
        ("z", "O sino tocou! Última volta! Vai que dá!"),
    ],
    "win": [
        ("z", "Vitória! Que pilotagem! É campeão, é campeão!"),
        ("z", "Ganhou! Pode estourar o champanhe... e o carro dos outros!"),
        ("z", "Primeiro lugar! A pista inteira se curva!"),
        ("z", "Vitória! Ninguém segura esse carrinho!"),
        ("z", "É campeão! Hoje é festa na oficina!"),
    ],
    "podium": [
        ("z", "Pódio! Não foi ouro, mas brilha igual!"),
        ("z", "Medalha no peito! Faltou pouquinho!"),
        ("z", "No pódio! Quase lá, quase lá!"),
        ("z", "Pódio garantido! Na próxima é o topo!"),
    ],
    "lose": [
        ("z", "Fora do pódio... Bom, pelo menos o carro voltou inteiro. Mais ou menos."),
        ("z", "Não deu dessa vez! Treina mais e volta!"),
        ("z", "Chegou! Isso conta como chegar, né?"),
        ("z", "Hoje não foi o dia. Amanhã tem revanche!"),
        ("z", "Terminou! E já tá liberado pra tentar de novo!"),
    ],
    "boss_brutus": [("z", "Atenção! O Brutus tá na pista! Esse aí passa o rolo em tudo!")],
    "boss_croc": [("z", "Olha o Crocodilo do Brejo! Cuidado que ele morde!")],
    "boss_xerife": [("z", "O Xerife de Aço chegou! Esconde a carteira de motorista!")],
    "boss_avalanche": [("z", "Lá vem a Avalanche! Agasalhem-se, pilotos!")],
    "boss_blackout": [("z", "É o Blackout! Quem não pagou a conta de luz, se prepare!")],
    "boss_imperador": [("z", "Curvem-se! O Imperador entrou na pista, e ele odeia perder!")],
    "boss_attack": [
        ("z", "Lá vem presente do chefe!"),
        ("z", "O chefão tá nervoso! Desvia!"),
        ("z", "Cuidado com o chão! Isso não é decoração!"),
        ("z", "Ataque do chefe! Sai da frente!"),
    ],
    "boss_beaten": [
        ("z", "O chefão caiu! Que dia histórico!"),
        ("z", "Venceu o chefe! Agora ele vai ter que lavar o seu carro!"),
        ("z", "Derrotou o chefão! Alguém filmou isso?"),
    ],
    "idle": [
        ("z", "Que dia lindo pra amassar uns carros!"),
        ("z", "Lembrando: o patrocinador desta corrida é a Funilaria do Zé!"),
        ("z", "Enquanto isso, na arquibancada, ninguém entende nada!"),
        ("z", "Isso aqui tá mais animado que fila de banco!"),
        ("z", "Eu tô narrando tão rápido que já tô na próxima corrida!"),
        ("z", "Recado da organização: favor não atropelar o narrador!"),
        ("z", "Os pneus tão gritando mais que a torcida!"),
        ("z", "Quem precisa de freio quando se tem coragem?"),
    ],
    # Tia Graxa responde pelo rádio (depois de algumas falas do Zeca)
    "g_kill": [
        ("g", "Mais um pra minha oficina!"),
        ("g", "Eu cobro por peça, viu?"),
        ("g", "Ai, que dó... de mim, que vou consertar!"),
    ],
    "g_killed": [
        ("g", "Eu disse que esse para-choque era de enfeite!"),
        ("g", "Lá vou eu buscar as peças de novo..."),
        ("g", "Vou cobrar hora extra!"),
    ],
    "g_fall": [
        ("g", "E o meu macaco hidráulico não alcança aí!"),
        ("g", "Alguém traz uma corda?"),
    ],
    "g_win": [
        ("g", "Tá bom, tá bom, foi bonito!"),
        ("g", "Esse carro só anda assim porque eu regulei!"),
    ],
    "g_lose": [
        ("g", "Eu falei pra trocar o óleo!"),
        ("g", "Calma, a culpa é sempre do carro."),
    ],
    "g_idle": [
        ("g", "Zeca, você não cansa de falar?"),
        ("g", "Eu só vim pelo cafezinho da oficina."),
    ],
    "g_overtaken": [("g", "Ai, essa doeu até em mim.")],
    "g_lead": [("g", "Agora não para, hein!")],
}

VOICE = {"z": ("pm_alex", 1.12), "g": ("pf_dora", 1.04)}
SR = 44100


def ffmpeg(x, sr, chain):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(sr), "-ac", "1", "-i", "-", "-af", chain,
                          "-ar", str(SR), "-ac", "1", "-f", "f32le", "-"], input=x.astype(np.float32).tobytes(),
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def trim(x, thr=0.01):
    idx = np.where(np.abs(x) > thr)[0]
    if len(idx) == 0:
        return x
    a = max(0, idx[0] - int(0.02 * SR))
    b = min(len(x), idx[-1] + int(0.12 * SR))
    return x[a:b]


def level(x, rms_db=-16.0, peak_db=-1.0):
    on = x[np.abs(x) > 0.01]
    r = float(np.sqrt(np.mean(on ** 2))) if len(on) else 1e-3
    x = x * (10 ** (rms_db / 20.0) / r)
    p = float(np.abs(x).max())
    if p > 10 ** (peak_db / 20.0):
        x = x * (10 ** (peak_db / 20.0) / p)
    return x


def process(x, sr, who):
    if who == "z":
        # um semitom acima (mais empolgado), som de alto-falante de estádio: corta o grave e o agudo extremos,
        # comprime (voz sempre "na cara") e um eco curto de arquibancada
        chain = ("asetrate=%d,atempo=%.5f,aresample=%d,highpass=f=120,lowpass=f=8500,"
                 "acompressor=threshold=-20dB:ratio=3.5:attack=4:release=90:makeup=5,"
                 "aecho=0.85:0.55:55|110:0.16|0.08" % (int(sr * 1.059), 1 / 1.059, sr))
    else:
        # rádio de oficina: banda estreita, um pouco de saturação
        chain = ("highpass=f=320,lowpass=f=3600,acompressor=threshold=-22dB:ratio=4:attack=3:release=60:makeup=6,"
                 "asoftclip=type=tanh")
    return level(trim(ffmpeg(x, sr, chain)))


def encode(x, out):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "4", out], input=np.clip(x, -1, 1).astype(np.float32).tobytes(), check=True)


def gd_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    model_dir, out_dir, gd_out = sys.argv[1], sys.argv[2], sys.argv[3]
    from kokoro_onnx import Kokoro
    k = Kokoro(os.path.join(model_dir, "kokoro-v1.0.fp16.onnx"), os.path.join(model_dir, "voices-v1.0.bin"))
    os.makedirs(out_dir, exist_ok=True)
    total = 0.0
    rows = []
    for key, lines in LINES.items():
        items = []
        for n, (who, text) in enumerate(lines):
            voice, speed = VOICE[who]
            s, sr = k.create(text, voice=voice, speed=speed, lang="pt-br")
            x = process(np.asarray(s, dtype=np.float32), sr, who)
            encode(x, os.path.join(out_dir, "%s_%d.ogg" % (key, n)))
            total += len(x) / SR
            items.append("[%s, %s, %.2f]" % (gd_str(who), gd_str(text), len(x) / SR))
        rows.append("\t%s: [%s]," % (gd_str(key), ", ".join(items)))
    with open(gd_out, "w", encoding="utf-8") as fh:
        fh.write("class_name VoiceLines\n")
        fh.write("## Gerado por tools/build_voice.py (não edite à mão): falas do narrador.\n")
        fh.write("## chave -> [[quem (\"z\" Zeca Turbo, \"g\" Tia Graxa), texto da legenda, duração em s], ...]\n")
        fh.write("const LINES := {\n" + "\n".join(rows) + "\n}\n")
    print("ok: %d falas, %.0f s de áudio" % (sum(len(v) for v in LINES.values()), total))


if __name__ == "__main__":
    main()

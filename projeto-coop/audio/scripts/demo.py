"""Trilha de demonstracao do som do Plumbdeep (cerca de 43 s), montada offline com a MESMA logica do som.gd
(eventos.json: camadas, escolha sem repetir, variacao, peso, alvos, ducking) sobre o ambiente da caverna.
Saidas: demo/plumbdeep_demo.wav (48 kHz/24 bits), demo/plumbdeep_demo.ogg, demo/linha_do_tempo.md, demo/demo_espectro.png
uso: python3 -I scripts/demo.py"""
import os, sys, json, subprocess, tempfile
import numpy as np, soundfile as sf
from scipy.signal import butter, sosfilt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import motor
from motor import SR, RAIZ, db

EVJ = json.load(open(os.path.join(RAIZ, 'godot', 'eventos.json')))
EV, G = EVJ['eventos'], EVJ['grupos']
DUR = 43.0
N = int(DUR * SR)
esc = motor.Escolhedor(G, seed=2026)
BUS = {'Golpes': np.zeros((N, 2)), 'SFX': np.zeros((N, 2)), 'UI': np.zeros((N, 2)), 'Musica': np.zeros((N, 2)), 'Ambiente': np.zeros((N, 2))}
ENVIO = np.zeros((N, 2))           # envio para o reverb de caverna
DUCK = []                          # (t, db, ms)
LINHA = []                         # (t, secao, evento, nota)
SECAO = ['']
VOL_BUS = {'Golpes': 0.0, 'SFX': 0.0, 'UI': -4.0, 'Musica': -6.0, 'Ambiente': -3.0}


def poe(bus, x, t, envio=0.3):
    i = int(round(t * SR))
    if i >= N:
        return
    x = x[:N - i]
    BUS[bus][i:i + len(x)] += x
    if envio > 0:
        ENVIO[i:i + len(x)] += x * envio


def tocar(evento, t, pan=0.0, peso=1.0, alvo=None, vol=0.0, pitch=1.0, envio=0.3, nota='', distante=False, mostrar=True, dur=None, indice0=None):
    ev = dict(EV[evento])
    ev['pitch'] = ev.get('pitch', 1.0) * pitch
    ev['volume_db'] = ev.get('volume_db', 0.0) + vol
    vozes = motor.instancia(ev, esc, peso=peso, alvo=alvo, indice0=indice0)
    x = motor.renderiza(vozes, ch=2, pan=pan)
    if dur:  # laco parado pelo jogo (Som.parar) com fade
        x = motor.corta(x, dur, fade_s=0.35)
    if distante:
        x = sosfilt(butter(2, 2500, 'lp', fs=SR, output='sos'), x, axis=0)
    poe(ev['bus'], x, t, envio * (1.6 if distante else 1.0))
    if ev.get('duck_db', 0) < 0:
        DUCK.append((t, ev['duck_db'] * min(1.0, peso), ev.get('duck_ms', 0)))
    if mostrar:
        LINHA.append((t, SECAO[0], evento, nota or ev['descricao'].split('.')[0], [os.path.basename(v['arquivo']) for v in vozes]))
    return vozes


def antes_do_contato(evento, t_contato, pan=0.0, peso=1.0, antecipa=0.025, nota=''):
    """igual ao Som.tocar_antes_do_contato: o pico do sopro cai 25 ms antes do contato."""
    ev = EV[evento]
    c0 = ev['camadas'][0]
    i, _ = esc.escolhe(c0['grupo'], c0.get('indices'))
    pico = G[c0['grupo']]['pico_em_s'][i] / c0.get('pitch', 1.0)
    t = t_contato - antecipa - pico
    tocar(evento, t, pan, peso, nota=nota or f'sopro (pico do arquivo em {t + pico:.2f} s)', mostrar=True, indice0=i)
    return t


def secao(nome):
    SECAO[0] = nome


# ------------------------------------------------------------------ ambiente
def cama(grupo, idx, vol, pan_largura=1.0, mono_pan=None, lp=None, mod=None, t0=0.0):
    rel = G[grupo]['arquivos'][idx]
    x = motor.carrega(rel)
    while len(x) < N:
        x = np.vstack([x, motor.carrega(rel)])  # os lacos foram feitos para emendar sem estalo
    x = x[:N].copy()
    if x.shape[1] == 1:
        a = ((mono_pan or 0.0) + 1) * np.pi / 4
        x = np.hstack([x * np.cos(a), x * np.sin(a)])
    if lp:
        x = sosfilt(butter(2, lp, 'lp', fs=SR, output='sos'), x, axis=0)
    g = np.full(N, db(vol))
    if mod is not None:
        g *= mod
    BUS['Ambiente'][:] += x * g[:, None]
    LINHA.append((t0, 'Ambiente', grupo, f'cama em laco ({os.path.basename(rel)}), {vol:+.0f} dB', [os.path.basename(rel)]))


def respiracao():
    t = np.arange(N) / SR
    fase = np.zeros(N)
    per, acc, ini = 9.0, 0.0, 0
    rng = np.random.default_rng(3)
    while ini < N:  # ciclos de 7 a 11 s, como o ambiente.gd
        per = rng.uniform(7, 11)
        fim = min(N, ini + int(per * SR))
        fase[ini:fim] = np.linspace(0, 1, fim - ini, endpoint=False)
        ini = fim
    r = np.sin(np.pi * fase) ** 2
    return db(-7 + 8 * r)


def rajadas():
    rng = np.random.default_rng(5)
    e = np.zeros(N)
    t = 5.0
    while t < DUR:
        a, d = int(t * SR), int(rng.uniform(2.5, 5) * SR)
        seg = np.sin(np.linspace(0, np.pi, min(d, N - a))) * rng.uniform(0.5, 1.0)
        e[a:a + len(seg)] = np.maximum(e[a:a + len(seg)], seg)
        t += rng.uniform(8, 16)
    return db(8 * e)


def ambiente():
    secao('Ambiente')
    cama('amb_caverna_base', 1, -3)
    cama('amb_abismo_respiracao', 0, -4, mod=respiracao())
    cama('amb_vento_caverna', 1, -11, mod=rajadas())
    cama('amb_goteiras', 1, -6)
    cama('lanterna_crepitar', 0, -12, mono_pan=0.55)
    cama('amb_cascata', 0, -9, lp=2200)
    rng = np.random.default_rng(11)
    t = 0.8
    while t < DUR - 1:
        tocar('gota_eco', t, pan=rng.uniform(-0.9, 0.9), vol=rng.uniform(-8, -2), envio=0.6, mostrar=False)
        t += rng.uniform(0.9, 3.2)
    LINHA.append((0.8, 'Ambiente', 'gota_eco', 'gotas isoladas com eco em pontos aleatorios, ~28/min', []))


# ------------------------------------------------------------------ roteiro
def roteiro():
    secao('Escorador (viga): curto-curto-LONGO')
    tocar('passo_pedra_pesado', 1.25, -0.2, nota='passo pesado'); tocar('passo_pedra_pesado', 1.78, -0.15, nota='passo pesado')
    antes_do_contato('escorador_swing_leve', 2.30, 0.0)
    tocar('escorador_impacto_leve', 2.30, 0.1, peso=0.6, alvo='carne', nota='golpe 1 (contato)')
    tocar('ouvidor_dor', 2.36, 0.3, nota='Ouvidor ferido')
    antes_do_contato('escorador_swing_leve', 2.68, 0.0)
    tocar('escorador_impacto_leve', 2.68, 0.1, peso=0.7, alvo='carne', pitch=1.03, nota='golpe 2 (contato, 0,38 s depois)')
    antes_do_contato('escorador_swing_pesado', 3.50, 0.0)
    tocar('escorador_impacto_final', 3.50, 0.1, peso=1.0, alvo='carne', nota='golpe 3 LONGO (contato, 0,82 s depois) + hit-stop 110 ms + ducking -7 dB')
    tocar('ouvidor_morte', 3.66, 0.3, nota='Ouvidor morre')

    secao('Cristaleira (geodo/raio)')
    antes_do_contato('cristaleira_carga', 5.60, -0.1)
    tocar('cristaleira_impacto_leve', 5.60, 0.35, peso=0.6, alvo='gosma', nota='raio 1 (contato) no Bocalume')
    tocar('bocalume_gorgolejo', 5.70, 0.4, nota='Bocalume reage')
    tocar('cristaleira_impacto_leve', 5.95, 0.35, peso=0.7, alvo='gosma', pitch=1.03, nota='raio 2 (contato, 0,35 s depois)')
    antes_do_contato('cristaleira_carga', 6.80, -0.1)
    tocar('cristaleira_impacto_final', 6.80, 0.35, peso=1.0, alvo='gosma', nota='descarga final (contato) + hit-stop 70 ms')
    tocar('bocalume_morte', 6.95, 0.4, nota='Bocalume morre')

    secao('Coveira (pa + turibulo)')
    tocar('coveira_turibulo', 8.55, -0.3, nota='turibulo balancando')
    antes_do_contato('coveira_swing', 9.10, -0.2)
    tocar('coveira_impacto_leve', 9.10, -0.25, peso=0.6, alvo='carne', nota='pazada 1 (contato)')
    tocar('criatura_grunhido', 9.16, -0.45, nota='criatura grunhe')
    antes_do_contato('coveira_swing', 9.48, -0.2)
    tocar('coveira_impacto_leve', 9.48, -0.25, peso=0.7, alvo='carne', pitch=1.03, nota='pazada 2 (contato, 0,38 s depois)')
    antes_do_contato('coveira_swing', 10.30, -0.2)
    tocar('coveira_impacto_final', 10.30, -0.25, peso=1.0, alvo='carne', nota='pazada final (contato) + hit-stop 90 ms')

    secao('Gancheiro (punhais): rapido e seco')
    tocar('esquiva', 11.75, 0.2, nota='esquiva')
    antes_do_contato('gancheiro_swing', 12.20, 0.15)
    tocar('gancheiro_impacto_leve', 12.20, 0.2, peso=0.5, alvo='carne', nota='punhalada 1 (contato)')
    tocar('ouvidor_dor', 12.26, 0.45)
    antes_do_contato('gancheiro_swing', 12.42, 0.15)
    tocar('gancheiro_impacto_leve', 12.42, 0.2, peso=0.6, alvo='carne', pitch=1.04, nota='punhalada 2 (contato, 0,22 s depois)')
    antes_do_contato('gancheiro_swing', 12.95, 0.15)
    tocar('gancheiro_impacto_final', 12.95, 0.2, peso=1.0, alvo='carne', nota='finalizador: corda + punhalada dupla (contato)')
    tocar('ouvidor_morte', 13.20, 0.45, nota='Ouvidor morre')

    secao('Reacao Corrente (raio na poca)')
    tocar('passo_agua', 14.60, -0.3, nota='passo na poca'); tocar('passo_agua', 14.95, -0.25, nota='passo na poca')
    tocar('ouvidor_guincho', 15.10, 0.5, nota='Ouvidor dentro da poca guincha')
    antes_do_contato('cristaleira_carga', 15.90, -0.1)
    tocar('corrente_reacao', 15.90, 0.4, nota='CORRENTE: eletricidade na agua (contato)')
    z = tocar('corrente_zumbido', 16.0, 0.4, vol=-2, dur=1.8, nota='laco da poca eletrificada (1,8 s, fade)')
    tocar('ouvidor_dor', 16.05, 0.5); tocar('ouvidor_morte', 16.45, 0.5, nota='Ouvidor eletrocutado')

    secao('Prumo: lance e recepcao')
    tocar('pegar', 18.30, -0.4, nota='Escorador pega o Prumo')
    tocar('prumo_lancar', 18.60, -0.4, nota='lance')
    tocar('escorador_swing_leve', 18.92, 0.0, vol=-6, pitch=0.92, nota='Prumo cruzando o ar')
    tocar('prumo_recepcao', 19.35, 0.45, peso=0.8, nota='recepcao comum')
    tocar('passo_pedra_pesado', 19.85, 0.45); tocar('passo_pedra_pesado', 20.25, 0.4)
    tocar('prumo_lancar', 20.70, 0.4, nota='lance de volta')
    tocar('escorador_swing_leve', 21.05, 0.0, vol=-6, pitch=0.9, nota='Prumo cruzando o ar')
    tocar('prumo_recepcao_golpe', 21.45, -0.35, peso=1.0, nota='GOLPE DE RECEPCAO no tempo certo + hit-stop 90 ms')
    tocar('saco_saque', 22.15, -0.2, nota='saco de saque pesado'); tocar('moedas', 22.40, -0.2)

    secao('Guincho e elevador')
    for k in range(9):
        tocar('guincho_catraca', 23.0 + k * 0.26, 0.3, nota='catraca (um clique por passo da manivela)' if k == 0 else '', mostrar=k == 0)
    tocar('guincho_corrente', 23.15, 0.3, nota='corrente do guincho')
    tocar('corda_rangido', 23.70, 0.1, nota='corda sob tensao')
    tocar('roldana_rangido', 24.10, 0.2, nota='roldana')
    tocar('guincho_corrente', 24.50, 0.3)
    tocar('corda_puxar', 24.90, 0.1, nota='puxao na corda')
    tocar('roldana_rangido', 25.30, 0.2)
    tocar('elevador_trava', 26.10, 0.2, peso=1.0, nota='elevador trava (baque + sub)')

    secao('Inimigos, elite e morte')
    tocar('ouvidor_telegrafia', 27.20, 0.6, nota='telegrafia: aviso do ataque do Ouvidor')
    tocar('ouvidor_guincho', 27.95, 0.6)
    tocar('bocalume_gorgolejo', 28.35, -0.6, nota='Bocalume se aproxima')
    tocar('bocalume_ataque', 29.00, -0.5, nota='bote do Bocalume')
    tocar('jogador_dano', 29.08, -0.1, peso=0.8, nota='heroi leva dano')
    antes_do_contato('escorador_swing_leve', 29.90, -0.2)
    tocar('escorador_impacto_leve', 29.90, -0.4, peso=0.6, alvo='gosma', nota='viga na gosma (alvo gosma)')
    antes_do_contato('escorador_swing_leve', 30.28, -0.2)
    tocar('escorador_impacto_leve', 30.28, -0.4, peso=0.7, alvo='gosma', pitch=1.03)
    antes_do_contato('escorador_swing_pesado', 31.10, -0.2)
    tocar('escorador_impacto_final', 31.10, -0.4, peso=1.0, alvo='gosma', nota='golpe final na gosma')
    tocar('bocalume_morte', 31.25, -0.5, nota='Bocalume morre')
    tocar('elite_rugido', 32.30, 0.25, nota='ELITE ruge')
    tocar('fulgor', 33.40, 0.2, peso=1.0, nota='FULGOR: explosao de poeira de esporos')
    antes_do_contato('coveira_swing', 34.20, 0.1)
    tocar('coveira_impacto_final', 34.20, 0.2, peso=1.0, alvo='carne', nota='pazada final na elite')
    tocar('elite_rugido', 34.32, 0.25, pitch=0.85, vol=-3, nota='elite morre (rugido grave)')
    tocar('aterrissagem_pesada', 34.95, 0.3, peso=1.0, nota='corpo da elite cai')
    tocar('stinger_vitoria', 35.60, 0.0, envio=0.0, nota='vinheta de vitoria')
    return z


def duck_curva():
    """ducking do bus Ambiente como no som.gd: ataque 60 dB/s, volta 9 dB/s."""
    alvo = np.zeros(N)
    for t, d, ms in DUCK:
        a, b = int(t * SR), min(N, int((t + ms / 1000) * SR))
        alvo[a:b] = np.minimum(alvo[a:b], d)
    hop = 240
    cur, out = 0.0, np.zeros(N // hop + 1)
    for k in range(len(out)):
        a = alvo[min(k * hop, N - 1)]
        cur = max(a, cur - 60 * hop / SR) if a < cur else min(a, cur + 9 * hop / SR)
        out[k] = cur
    return db(np.repeat(out, hop)[:N])


def reverb(x):
    with tempfile.TemporaryDirectory() as d:
        a, b = os.path.join(d, 'a.wav'), os.path.join(d, 'b.wav')
        sf.write(a, x.astype(np.float32), SR, subtype='FLOAT')
        # caverna: reverberancia alta, abafamento medio, sala grande, 40 ms de pre-atraso; so o sinal molhado
        subprocess.run(['sox', a, b, 'reverb', '-w', '75', '55', '100', '100', '40', '0'], check=True)
        y, _ = sf.read(b, always_2d=True)
    return y[:N] if len(y) >= N else np.vstack([y, np.zeros((N - len(y), 2))])


def main():
    ambiente()
    z = roteiro()
    # corta o laco do zumbido em 1,8 s com fade (o jogo para a voz com Som.parar)
    duck = duck_curva()
    mix = np.zeros((N, 2))
    for b, x in BUS.items():
        g = db(VOL_BUS[b])
        if b == 'Ambiente':
            x = x * duck[:, None]
        if b == 'Musica':
            x = x * np.sqrt(duck)[:, None]
        mix += x * g
    mix += reverb(ENVIO) * db(-4)
    fi = int(1.0 * SR); mix[:fi] *= np.linspace(0, 1, fi)[:, None] ** 2
    fo = int(2.0 * SR); mix[-fo:] *= np.linspace(1, 0, fo)[:, None] ** 2
    # master: ganho para ~-18 LUFS (deixa os golpes respirarem) e limitador de pico verdadeiro (como o HardLimiter do Master)
    l = motor.lufs(mix)
    mix *= db(-18.0 - l)
    mix, gr = motor.limitador(mix, -1.6, ataque_ms=1.5, soltura_ms=80)
    os.makedirs(os.path.join(RAIZ, 'demo'), exist_ok=True)
    wav = os.path.join(RAIZ, 'demo', 'plumbdeep_demo.wav')
    ogg = os.path.join(RAIZ, 'demo', 'plumbdeep_demo.ogg')
    for _ in range(3):
        sf.write(wav, mix.astype(np.float32), SR, subtype='PCM_24')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '6', ogg], check=True)
        motor._cache.pop('demo/plumbdeep_demo.ogg', None)
        y = motor.carrega('demo/plumbdeep_demo.ogg')
        tp = motor.tp_db(y)
        if tp <= -1.0:
            break
        mix *= db(-1.1 - tp)
    info = dict(lufs=round(motor.lufs(y), 1), tp=round(float(tp), 2), reducao_limitador_db=round(gr, 1), dur=round(len(y) / SR, 2))
    print(info)
    json.dump(dict(info=info, linha=LINHA, duck=DUCK), open(os.path.join(RAIZ, 'demo', 'linha_do_tempo.json'), 'w'), ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()

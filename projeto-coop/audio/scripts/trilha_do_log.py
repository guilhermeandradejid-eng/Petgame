"""Monta a trilha de um clipe a partir do log de eventos do Som (user://som_log.jsonl), quadro a quadro.
Use quando o clipe foi gravado sem audio (ex.: saida .png do Movie Maker, ou captura de tela) ou para
remixar a trilha sem regravar o video. Mesma logica de camadas do som.gd (eventos.json).

uso: python3 -I scripts/trilha_do_log.py som_log.jsonl saida.wav [--fps 60] [--duracao S] [--ambiente] [--atraso_quadros 1] [--seed 1]
depois: ffmpeg -i clipe.mp4 -i saida.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -shortest clipe_com_som.mp4

Tempo de cada evento = (quadro - inicio_quadro + atraso_quadros) / fps + atraso_s.
atraso_quadros=1 reproduz o que o Movie Maker grava (o som disparado no _process do quadro N sai no quadro N+1);
use 0 se quiser o som exatamente no quadro do evento."""
import os, sys, json, re, argparse
import numpy as np, soundfile as sf
from scipy.signal import butter, sosfilt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import motor
from motor import SR, RAIZ, db

ap = argparse.ArgumentParser()
ap.add_argument('log'); ap.add_argument('saida')
ap.add_argument('--fps', type=float, default=None)
ap.add_argument('--duracao', type=float, default=None)
ap.add_argument('--ambiente', action='store_true', help='mistura a cama da caverna por baixo')
ap.add_argument('--atraso_quadros', type=float, default=1.0)
ap.add_argument('--seed', type=int, default=1)
ap.add_argument('--eventos', default=os.path.join(RAIZ, 'godot', 'eventos.json'))
a = ap.parse_args()

EVJ = json.load(open(a.eventos))
EV, G = EVJ['eventos'], EVJ['grupos']
esc = motor.Escolhedor(G, seed=a.seed)
linhas = [json.loads(l) for l in open(a.log) if l.strip()]
cab = linhas[0] if 'inicio_quadro' in linhas[0] else {'inicio_quadro': 0}
evs = [l for l in linhas if 'evento' in l]
fps = a.fps or cab.get('fps_movie_writer', 60)
q0 = cab.get('inicio_quadro', 0)
tempos = [(l['quadro'] - q0 + a.atraso_quadros) / fps + l.get('atraso_s', 0.0) for l in evs]
dur = a.duracao or (max(tempos) + 3.0 if tempos else 3.0)
N = int(dur * SR)
mix = np.zeros((N, 2))
envio = np.zeros((N, 2))
for l, t in zip(evs, tempos):
    if l['evento'] not in EV:
        print('evento desconhecido', l['evento']); continue
    ev = dict(EV[l['evento']])
    ev['pitch'] = ev.get('pitch', 1.0) * l.get('pitch', 1.0)
    ev['volume_db'] = ev.get('volume_db', 0.0) + l.get('volume_db', 0.0) + {'UI': -4, 'Musica': -6}.get(ev['bus'], 0)
    m = re.findall(r'-?[\d.]+', l.get('pos') or '')
    pan = float(np.clip(float(m[0]) / 8.0, -1, 1)) if m else 0.0  # x do mundo -> pan simples
    x = motor.renderiza(motor.instancia(ev, esc, peso=l.get('peso', 1.0), alvo=l.get('alvo')), ch=2, pan=pan)
    x = x[int(l.get('desde_s', 0.0) * SR):]
    i = int(round(t * SR))
    if i >= N: continue
    x = x[:N - i]
    mix[i:i + len(x)] += x
    if ev['bus'] in ('SFX', 'Golpes'):
        envio[i:i + len(x)] += x * 0.3
if a.ambiente:
    for g, idx, v in [('amb_caverna_base', 1, -6), ('amb_abismo_respiracao', 0, -7), ('amb_goteiras', 1, -9)]:
        y = motor.carrega(G[g]['arquivos'][idx])
        while len(y) < N: y = np.vstack([y, y])
        mix += y[:N] * db(v)
# reverb de caverna simples (sox), so o molhado
import subprocess, tempfile
with tempfile.TemporaryDirectory() as d:
    p1, p2 = os.path.join(d, 'a.wav'), os.path.join(d, 'b.wav')
    sf.write(p1, envio.astype(np.float32), SR, subtype='FLOAT')
    subprocess.run(['sox', '-V1', p1, p2, 'reverb', '-w', '75', '55', '100', '100', '40', '0'], check=True)
    w, _ = sf.read(p2, always_2d=True)
mix += np.vstack([w, np.zeros((max(0, N - len(w)), 2))])[:N] * db(-4)
mix, gr = motor.limitador(mix, -1.2)
sf.write(a.saida, mix.astype(np.float32), SR, subtype='PCM_24')
print(f'{len(evs)} eventos, {dur:.2f} s, fps {fps}, limitador {gr:.1f} dB -> {a.saida}')

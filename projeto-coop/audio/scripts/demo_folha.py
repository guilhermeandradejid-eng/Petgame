"""Gera demo/linha_do_tempo.md e demo/demo_espectro.png a partir de demo/linha_do_tempo.json.
uso: python3 -I scripts/demo_folha.py"""
import os, sys, json
import numpy as np
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
from scipy.signal import spectrogram
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import motor
from motor import SR, RAIZ

D = json.load(open(os.path.join(RAIZ, 'demo', 'linha_do_tempo.json')))
L = sorted(D['linha'], key=lambda r: r[0])
info = D['info']

# ---------------------------------------------------------------- folha
sec_ini = {}
for t, s, e, n, f in L:
    sec_ini.setdefault(s, t)
out = ['# Demo de som do Plumbdeep: linha do tempo', '',
       f'Arquivo: `plumbdeep_demo.ogg` (e `plumbdeep_demo.wav`, 48 kHz/24 bits, so no scratchpad). Duracao {info["dur"]:.0f} s, '
       f'{info["lufs"]} LUFS integrado, pico verdadeiro {info["tp"]} dBTP.', '',
       'Montada por `scripts/demo.py` com a mesma logica do `som.gd` (camadas do `eventos.json`, escolha sem repetir, '
       'variacao de pitch/volume, peso, alvo, ducking do ambiente), mais um envio de reverb de caverna (sox reverb, so o sinal molhado, -4 dB) '
       'e um limitador no master. Os sopros (swing) foram posicionados como faz `Som.tocar_antes_do_contato`: o pico do arquivo cai 25 ms antes do contato.', '',
       'Os tempos de golpe sao **tempos de contato** (o quadro em que a arma encosta). O ritmo de cada classe e curto-curto-LONGO:', '',
       '| Classe | Golpe 1 -> 2 | Golpe 2 -> final | Carater |', '|---|---|---|---|',
       '| Escorador (viga) | 0,38 s | 0,82 s | grave, longo, sub forte, ducking -7 dB e hit-stop 110 ms no final |',
       '| Cristaleira (raio) | 0,35 s | 0,85 s | estalo seco + descarga eletrica; hit-stop 70 ms |',
       '| Coveira (pa) | 0,38 s | 0,82 s | pancada metalica oca, corrente do turibulo na cauda; hit-stop 90 ms |',
       '| Gancheiro (punhais) | 0,22 s | 0,53 s | curto e seco, sem sub; final = estalo da corda + punhalada dupla |', '',
       '## Secoes', '']
for s, t in sorted(sec_ini.items(), key=lambda r: r[1]):
    out.append(f'- **{t:5.2f} s** {s}')
out += ['', '## Eventos', '', '| Tempo (s) | Secao | Evento | O que se ouve | Arquivos sorteados |', '|---:|---|---|---|---|']
for t, s, e, n, f in L:
    out.append(f'| {t:.3f} | {s} | `{e}` | {n} | {", ".join(f) if f else "-"} |')
out += ['', '## Ducking aplicado ao ambiente', '', '| Tempo (s) | Atenuacao (dB) | Duracao (ms) |', '|---:|---:|---:|']
for t, d, ms in sorted(D['duck']):
    out.append(f'| {t:.2f} | {d:.1f} | {ms} |')
out += ['', '## Limites honestos', '',
        '- A trilha foi montada e medida, mas **nao foi ouvida** por quem a montou. Os tempos, niveis e espectro foram verificados por medicao e pelo espectrograma (`demo_espectro.png`).',
        '- No jogo o hit-stop tambem baixa o pitch das outras vozes por ~0,1 s; a demo nao simula isso (o ambiente so sofre o ducking).',
        '- O reverb da demo e o `reverb` do sox, parecido mas nao igual ao AudioEffectReverb do bus Caverna.']
open(os.path.join(RAIZ, 'demo', 'linha_do_tempo.md'), 'w').write('\n'.join(out) + '\n')

# ---------------------------------------------------------------- espectrograma
x = motor.carrega('demo/plumbdeep_demo.ogg').mean(1)
fig, (a0, a1) = plt.subplots(2, 1, figsize=(22, 8), gridspec_kw={'height_ratios': [1, 3]}, sharex=True)
w = int(0.02 * SR)
k = len(x) // w
rms = 20 * np.log10(np.sqrt((x[:k * w].reshape(k, w) ** 2).mean(1)) + 1e-9)
pk = 20 * np.log10(np.abs(x[:k * w]).reshape(k, w).max(1) + 1e-9)
tt = np.arange(k) * w / SR
a0.plot(tt, pk, lw=.5, color='#888', label='pico (20 ms)')
a0.plot(tt, rms, lw=.7, color='k', label='RMS (20 ms)')
a0.set_ylim(-70, 0); a0.set_ylabel('dBFS'); a0.legend(loc='lower right', fontsize=7); a0.grid(alpha=.3)
f, t, S = spectrogram(x, SR, nperseg=2048, noverlap=1536)
a1.pcolormesh(t, f, 10 * np.log10(S + 1e-14), vmin=-120, vmax=-30, cmap='magma', shading='auto')
a1.set_yscale('symlog', linthresh=200); a1.set_ylim(20, 20000); a1.set_ylabel('Hz (escala log)')
a1.set_xlabel('s')
cores = {}
pal = ['#4cc9f0', '#f72585', '#b5e48c', '#ffd166', '#ff9f1c', '#c77dff', '#90e0ef', '#ef476f']
for s, t0 in sorted(sec_ini.items(), key=lambda r: r[1]):
    if s == 'Ambiente':
        continue
    c = pal[len(cores) % len(pal)]; cores[s] = c
    a0.axvline(t0, color=c, lw=1.2)
    a0.text(t0 + 0.05, -8, s.split(':')[0].split('(')[0].strip(), fontsize=8, color=c, va='top', rotation=0,
            bbox=dict(facecolor='white', alpha=.7, lw=0))
for t0, s, e, n, fl in L:
    if s == 'Ambiente' or 'swing' in e or 'carga' in e:
        continue
    if any(p in e for p in ('impacto', 'recepcao', 'corrente_reacao', 'fulgor', 'elevador_trava')):
        a1.axvline(t0, color=cores.get(s, 'w'), lw=.8, alpha=.8, ls='--')
a1.set_xlim(0, len(x) / SR)
fig.suptitle(f'Plumbdeep - demo de som ({info["lufs"]} LUFS, {info["tp"]} dBTP). Linhas tracejadas: quadros de contato dos golpes/reacoes', fontsize=10)
plt.tight_layout()
plt.savefig(os.path.join(RAIZ, 'demo', 'demo_espectro.png'), dpi=80)
print('ok', len(L), 'linhas')

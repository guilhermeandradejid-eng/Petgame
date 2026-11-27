"""Desenho de som em camadas do Plumbdeep.
- Define os eventos de jogo (golpes, passos, maquinas, reacoes, inimigos, ambiente, UI, musica)
  como camadas de grupos da biblioteca (transiente + corpo + cauda + sub).
- Assa os golpes de combate em biblioteca/compostos/ (camadas fixas com atrasos de poucos ms,
  que o motor do jogo nao agenda com precisao de amostra), com 6 variacoes cada.
- Escreve godot/eventos.json (lido pelo som.gd) e acrescenta os compostos ao catalogo.json.
uso: python3 -I scripts/compor.py"""
import os, sys, json, copy
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import motor
from motor import SR, RAIZ

CAT = json.load(open(os.path.join(RAIZ, 'catalogo.json')))
N_COMP = 6


def L(grupo, papel, vol=0.0, atraso=0.0, pitch=1.0, pv=None, prob=1.0, peso=False, peso_min=None, max_s=None, atraso_var=0.0, vv=None, idx=None):
    c = dict(grupo=grupo, papel=papel, volume_db=vol, atraso_ms=atraso, pitch=pitch)
    if idx is not None: c['indices'] = idx
    if pv is not None: c['pitch_var'] = pv
    if vv is not None: c['volume_var_db'] = vv
    if prob < 1.0: c['probabilidade'] = prob
    if peso:
        c['escala_peso'] = True
        if peso_min is not None: c['peso_min'] = peso_min
    if max_s: c['max_s'] = max_s
    if atraso_var: c['atraso_var_ms'] = atraso_var
    return c


EV = {}


def E(nome, bus, camadas, descricao, **kw):
    ev = dict(descricao=descricao, bus=bus, espacial=kw.pop('espacial', bus not in ('UI', 'Musica')),
              prioridade=kw.pop('prioridade', 5), max_vozes=kw.pop('max_vozes', 4), cooldown_ms=kw.pop('cooldown_ms', 0),
              volume_db=kw.pop('vol', 0.0), pitch=kw.pop('pitch', 1.0), pitch_var=kw.pop('pv', 0.04),
              volume_var_db=kw.pop('vv', 1.5), camadas=camadas)
    ev.update(kw)
    EV[nome] = ev


# alvos (superficie atingida): camada escolhida em tempo de jogo, depende do que o golpe acertou
def alvos(nivel, atraso=8.0, vol=0.0):
    carne = {'leve': 'carne_leve', 'medio': 'carne_medio', 'pesado': 'carne_pesado'}[nivel]
    d = {
        'carne': [L(carne, 'superficie', vol - 3, atraso)],
        'gosma': [L('gosma_esmaga', 'superficie', vol - 4, atraso, pitch=0.95)],
        'pedra': [L('passo_pedra_pesado', 'superficie', vol - 6, atraso, pitch=0.9)],
        'nada': [],
    }
    if nivel == 'pesado':
        d['carne'].append(L('osso_quebra', 'superficie', vol - 9, atraso + 25, prob=0.5))
    return d


# ---------------------------------------------------------------- combate: Escorador (viga, pesado e lento)
E('escorador_swing_leve', 'Golpes', [L('viga_whoosh', 'sopro', -1, pv=0.03)],
  'Viga cortando o ar (golpes 1 e 2). Use tocar_antes_do_contato para o pico cair 1-2 quadros antes do impacto.',
  prioridade=4, max_vozes=2, antecipa_pico=True, pv=0.05)
E('escorador_swing_pesado', 'Golpes', [L('viga_whoosh', 'sopro', 0, pitch=0.86), L('viga_whoosh', 'corpo', -7, 45, pitch=0.74)],
  'Golpe final da viga: dois sopros graves sobrepostos, mais longos.', prioridade=5, max_vozes=2, antecipa_pico=True, pv=0.04)
E('escorador_impacto_leve', 'Golpes',
  [L('viga_impacto', 'transiente', 0, 0, pv=0.03), L('peso_thump', 'sub', -9, 6, pitch=1.05)],
  'Viga acertando (golpes 1 e 2 do combo curto-curto-LONGO).', prioridade=7, max_vozes=3,
  compor=True, alvo_lufs=-17, alvos=alvos('medio'), alvo_padrao='carne', peso_pitch=0.06, peso_volume_db=4, duck_db=-2.5, duck_ms=250)
E('escorador_impacto_final', 'Golpes',
  [L('viga_impacto', 'transiente', 0, 0, pitch=0.9), L('viga_impacto', 'corpo', -5, 14, pitch=0.76),
   L('peso_thump', 'sub', 0, 4, pitch=0.88), L('aterrissagem_pesada', 'cauda', -10, 28, pitch=0.8)],
  'Golpe final da viga: madeira + madeira mais grave + baque sub + poeira caindo. Acompanha hit-stop.',
  prioridade=9, max_vozes=2, compor=True, alvo_lufs=-14, alvos=alvos('pesado', 10, 1), alvo_padrao='carne',
  peso_pitch=0.08, peso_volume_db=4, duck_db=-7, duck_ms=650, hit_stop_ms=110)
E('escorador_arrasto', 'SFX', [L('viga_arrasto', 'corpo', -6, pv=0.03)], 'Viga arrastando no chao (andar carregando).', prioridade=3, max_vozes=1)

# ---------------------------------------------------------------- Cristaleira (raio, medio)
E('cristaleira_carga', 'Golpes', [L('raio_carga', 'sopro', -3)], 'Geodo carregando antes do disparo.', prioridade=4, max_vozes=2, antecipa_pico=True)
E('cristaleira_impacto_leve', 'Golpes',
  [L('raio_estalo', 'transiente', 0, idx=[0, 1, 2, 5]), L('raio_descarga', 'cauda', -14, 10, pitch=1.12, max_s=0.45)],
  'Raio curto acertando.', prioridade=6, max_vozes=3, compor=True, alvo_lufs=-18, alvos={'carne': [L('carne_leve', 'superficie', -8, 6)], 'gosma': [L('gosma_esmaga', 'superficie', -9, 6)], 'nada': []},
  alvo_padrao='carne', peso_pitch=0.05, peso_volume_db=3, duck_db=-2, duck_ms=200)
E('cristaleira_impacto_final', 'Golpes',
  [L('raio_estalo', 'transiente', 0, 0, idx=[0, 1, 2]), L('raio_descarga', 'corpo', -7, 0, pitch=0.92, max_s=1.3), L('peso_thump', 'sub', -4, 6, pitch=1.0),
   L('raio_estalo', 'cauda', -13, 140, pitch=0.8)],
  'Descarga final do geodo: estalo + descarga + sub + estalo residual.', prioridade=8, max_vozes=2, compor=True, alvo_lufs=-14.5,
  alvos={'carne': [L('carne_medio', 'superficie', -7, 8)], 'gosma': [L('gosma_esmaga', 'superficie', -8, 8)], 'nada': []},
  alvo_padrao='carne', peso_pitch=0.06, peso_volume_db=4, duck_db=-5, duck_ms=500, hit_stop_ms=70)

# ---------------------------------------------------------------- Coveira (pa + turibulo, medio-pesado)
E('coveira_swing', 'Golpes', [L('pa_whoosh', 'sopro', -2), L('turibulo_corrente', 'cauda', -10, 60, prob=0.7)],
  'Pa cortando o ar com o turibulo chacoalhando.', prioridade=4, max_vozes=2, antecipa_pico=True, pv=0.05)
E('coveira_impacto_leve', 'Golpes',
  [L('pa_pancada', 'transiente', 0, 0, max_s=0.55), L('peso_thump', 'sub', -12, 5, pitch=1.1)],
  'Pa de ferro acertando (oca, metalica).', prioridade=7, max_vozes=3, compor=True, alvo_lufs=-18, alvos=alvos('medio'), alvo_padrao='carne',
  peso_pitch=0.05, peso_volume_db=4, duck_db=-2.5, duck_ms=250)
E('coveira_impacto_final', 'Golpes',
  [L('pa_pancada', 'transiente', 0, 0, pitch=0.86, max_s=0.9), L('pa_pancada', 'corpo', -8, 10, pitch=0.74, max_s=0.7),
   L('peso_thump', 'sub', -2, 4, pitch=0.95), L('turibulo_corrente', 'cauda', -9, 70)],
  'Pazada final: pa grave dobrada + sub + corrente do turibulo.', prioridade=9, max_vozes=2, compor=True, alvo_lufs=-15,
  alvos=alvos('pesado', 8), alvo_padrao='carne', peso_pitch=0.07, peso_volume_db=4, duck_db=-6, duck_ms=550, hit_stop_ms=90)
E('coveira_turibulo', 'SFX', [L('turibulo_corrente', 'corpo', -4), L('pa_whoosh', 'sopro', -16, 20, pitch=0.7, prob=0.6)],
  'Balanco do turibulo (provisorio: corrente + sopro leve; falta gravacao de incensario).', prioridade=3, max_vozes=2)

# ---------------------------------------------------------------- Gancheiro (punhais, rapido e seco)
E('gancheiro_swing', 'Golpes', [L('punhal_whoosh', 'sopro', -3, pv=0.04)], 'Punhal cortando o ar, curto e seco.',
  prioridade=3, max_vozes=3, antecipa_pico=True, pv=0.07)
E('gancheiro_impacto_leve', 'Golpes',
  [L('punhal_corte', 'transiente', 0, idx=[0, 1, 2, 3, 4]), L('punhal_metal', 'corpo', -8, 3, pitch=1.05)],
  'Punhalada curta.', prioridade=6, max_vozes=4, compor=True, alvo_lufs=-20,
  alvos={'carne': [L('carne_leve', 'superficie', -7, 5)], 'gosma': [L('gosma_esmaga', 'superficie', -10, 5, pitch=1.1)], 'nada': []},
  alvo_padrao='carne', peso_pitch=0.04, peso_volume_db=3, pv=0.06, duck_db=-1, duck_ms=120)
E('gancheiro_impacto_final', 'Golpes',
  [L('corda_chicote', 'transiente', -5, 0), L('punhal_corte', 'transiente', 0, 22), L('punhal_corte', 'corpo', -1, 100, pitch=1.04),
   L('punhal_metal', 'corpo', -6, 100), L('peso_thump', 'sub', -16, 24, pitch=1.3)],
  'Finalizador do Gancheiro: estalo da corda + punhalada dupla (sem sub pesado: seco).', prioridade=8, max_vozes=2, compor=True, alvo_lufs=-17,
  alvos={'carne': [L('carne_medio', 'superficie', -6, 24)], 'gosma': [L('gosma_esmaga', 'superficie', -8, 24)], 'nada': []},
  alvo_padrao='carne', peso_pitch=0.04, peso_volume_db=3, pv=0.05, duck_db=-3, duck_ms=300, hit_stop_ms=45)

# ---------------------------------------------------------------- acertos genericos / superficies
for n, g, pr in [('acerto_carne_leve', 'carne_leve', 5), ('acerto_carne_medio', 'carne_medio', 6), ('acerto_carne_pesado', 'carne_pesado', 7),
                 ('acerto_gosma', 'gosma_esmaga', 6), ('osso_quebra', 'osso_quebra', 6)]:
    E(n, 'Golpes', [L(g, 'corpo', 0)], f'Superficie atingida ({g}). Ja incluida nos impactos via "alvo"; use para dano de inimigos/armadilhas.', prioridade=pr, max_vozes=3)
E('jogador_dano', 'Golpes', [L('carne_medio', 'corpo', -2), L('peso_thump', 'sub', -10, 4, peso=True)], 'Heroi levando dano.', prioridade=8, max_vozes=2, duck_db=-3, duck_ms=300)

# ---------------------------------------------------------------- movimento
for n, g, vol, extra in [
        ('passo_pedra', 'passo_pedra', -4, []), ('passo_pedra_pesado', 'passo_pedra_pesado', -2, [L('peso_thump', 'sub', -18, 3, pitch=1.4, peso=True, peso_min=0.6)]),
        ('passo_agua', 'passo_agua', -4, []), ('passo_agua_pesado', 'passo_agua_pesado', -2, []),
        ('passo_lama', 'passo_lama', -4, []), ('passo_madeira', 'passo_madeira', -4, []),
        ('passo_madeira_pesado', 'passo_madeira_pesado', -2, [L('corda_rangido', 'cauda', -16, 20, prob=0.3)])]:
    E(n, 'SFX', [L(g, 'corpo', 0)] + extra, f'Passo ({g}).', prioridade=2, max_vozes=4, vol=vol, pv=0.06, vv=2.0)
E('passo_lama_pesado', 'SFX', [L('passo_lama', 'corpo', 0, pitch=0.85)], 'Lama pesada (passo_lama com pitch 0,85; falta variante gravada).', prioridade=2, max_vozes=4, vol=-2, pv=0.05, vv=2.0)
E('pulo', 'SFX', [L('pulo', 'corpo', -3)], 'Impulso do pulo.', prioridade=3, max_vozes=2)
E('aterrissagem', 'SFX', [L('aterrissagem', 'corpo', -2)], 'Aterrissagem leve.', prioridade=4, max_vozes=2)
E('aterrissagem_pesada', 'SFX', [L('aterrissagem_pesada', 'corpo', 0), L('peso_thump', 'sub', -8, 4, pitch=0.95, peso=True)],
  'Aterrissagem do Escorador ou queda alta; peso escala o sub.', prioridade=6, max_vozes=2, duck_db=-3, duck_ms=300)
E('esquiva', 'SFX', [L('esquiva', 'corpo', -3)], 'Esquiva/rolamento (tecido rapido; falta corpo rolando na pedra).', prioridade=4, max_vozes=2, pv=0.06)

# ---------------------------------------------------------------- corda, gancho, rapel
E('gancho_lancar', 'SFX', [L('corda_chicote', 'corpo', -2), L('punhal_whoosh', 'sopro', -9, 0, pitch=0.9)], 'Gancho lancado.', prioridade=5, max_vozes=2)
E('gancho_prender', 'SFX', [L('punhal_metal', 'transiente', -3, 0, pitch=0.85), L('corda_rangido', 'cauda', -10, 40)], 'Gancho crava na pedra e a corda estica.', prioridade=5, max_vozes=2)
E('corda_puxar', 'SFX', [L('corda_puxar', 'corpo', -3)], 'Puxao na corda.', prioridade=3, max_vozes=2)
E('corda_rangido', 'SFX', [L('corda_rangido', 'corpo', -4)], 'Corda/madeira sob tensao.', prioridade=2, max_vozes=2, cooldown_ms=250)
E('corda_estalo', 'SFX', [L('corda_chicote', 'transiente', 0, pitch=0.8), L('peso_thump', 'sub', -12, 5, pitch=1.2)],
  'Corda arrebentando (PROVISORIO: nao ha gravacao de corda partindo).', prioridade=7, max_vozes=1)
E('rapel', 'SFX', [L('rapel_atrito', 'corpo', -4)], 'Descida de rapel (atrito).', prioridade=3, max_vozes=1)

# ---------------------------------------------------------------- maquinas
E('guincho_catraca', 'SFX', [L('guincho_catraca', 'transiente', -2, pv=0.02)], 'Um clique por passo da manivela; encadear no ritmo do giro.', prioridade=4, max_vozes=3, pv=0.03, vv=1.0)
E('guincho_corrente', 'SFX', [L('guincho_corrente', 'corpo', -3)], 'Corrente correndo no guincho.', prioridade=4, max_vozes=2)
E('roldana_rangido', 'SFX', [L('roldana_rangido', 'corpo', -5)], 'Roldana rangendo.', prioridade=3, max_vozes=2, cooldown_ms=200)
E('elevador_trava', 'SFX', [L('elevador_trava', 'transiente', 0), L('peso_thump', 'sub', -6, 3, pitch=0.85)], 'Elevador chegando/travando.', prioridade=7, max_vozes=1, duck_db=-4, duck_ms=400)

# ---------------------------------------------------------------- itens e o Prumo
E('prumo_lancar', 'SFX', [L('lancar', 'corpo', 0, pitch=0.9), L('viga_whoosh', 'sopro', -7, 30, pitch=0.95)], 'Prumo lancado no ar.', prioridade=6, max_vozes=2)
E('prumo_recepcao', 'Golpes',
  [L('recepcao_pesada', 'transiente', 0), L('peso_thump', 'sub', -3, 4, pitch=0.92), L('pegar', 'cauda', -12, 45)],
  'Prumo recebido (couro contra o corpo + baque grave).', prioridade=8, max_vozes=2, compor=True, alvo_lufs=-17, peso_pitch=0.06, peso_volume_db=4, duck_db=-4, duck_ms=350)
E('prumo_recepcao_golpe', 'Golpes',
  [L('recepcao_pesada', 'transiente', 0), L('viga_impacto', 'corpo', -5, 6, pitch=0.85), L('peso_thump', 'sub', 0, 4, pitch=0.85),
   L('moedas', 'cauda', -16, 60, pitch=0.8)],
  'Golpe de recepcao perfeito: o Prumo e rebatido/recebido no tempo certo (mais forte que a recepcao comum).', prioridade=9, max_vozes=1,
  compor=True, alvo_lufs=-14.5, peso_pitch=0.06, peso_volume_db=4, duck_db=-7, duck_ms=600, hit_stop_ms=90)
E('saco_saque', 'SFX', [L('saco_saque', 'corpo', -2), L('moedas', 'cauda', -10, 30, prob=0.6)], 'Saco de saque pesado.', prioridade=4, max_vozes=2)
E('moedas', 'SFX', [L('moedas', 'corpo', -3)], 'Moedas.', prioridade=3, max_vozes=3)
E('pegar', 'SFX', [L('pegar', 'corpo', -3)], 'Pegar item.', prioridade=4, max_vozes=2)

# ---------------------------------------------------------------- reacoes
E('corrente_reacao', 'Golpes',
  [L('corrente_choque_agua', 'corpo', 0), L('raio_estalo', 'transiente', -3, 0, idx=[0, 1, 2, 5]), L('raio_descarga', 'cauda', -9, 35, pitch=0.9, max_s=1.0),
   L('passo_agua_pesado', 'superficie', -10, 5, pitch=0.9)],
  'Corrente: eletricidade na agua. Depois disso, ligar o laco corrente_zumbido na poca enquanto durar.', prioridade=8, max_vozes=2,
  compor=True, alvo_lufs=-14.5, duck_db=-4, duck_ms=400)
E('corrente_zumbido', 'SFX', [L('raio_zumbido_agua', 'corpo', -6)], 'Laco da poca eletrificada (emissor posicional).', prioridade=4, max_vozes=3, laco=True, pv=0.03)
E('fervura', 'SFX', [L('fervura_chiado', 'corpo', 0)], 'Fervura (cal + agua): chiado e bolha.', prioridade=6, max_vozes=2)
E('fervura_laco', 'SFX', [L('fervura_laco', 'corpo', -6)], 'Laco da agua fervendo.', prioridade=3, max_vozes=2, laco=True)
E('fulgor', 'Golpes', [L('poeira_explosao', 'corpo', 0), L('peso_thump', 'sub', -4, 6, pitch=0.8, peso=True)],
  'Fulgor: explosao de poeira de esporos.', prioridade=8, max_vozes=2, duck_db=-6, duck_ms=600)
E('ambar_visgo', 'SFX', [L('resina_visgo', 'corpo', 0)], 'Ambar/Visgo: resina gruda.', prioridade=5, max_vozes=2)
E('floracao', 'SFX', [L('floracao', 'corpo', 0)], 'Floracao: cogumelo cresce (solucao de design).', prioridade=5, max_vozes=2)

# ---------------------------------------------------------------- inimigos
for n, g, pr, mv, extra, d in [
        ('ouvidor_telegrafia', 'ouvidor_telegrafia', 7, 2, [], 'Aviso antes do ataque do Ouvidor (leitura do jogador).'),
        ('ouvidor_guincho', 'ouvidor_guincho', 5, 3, [], 'Guincho do Ouvidor.'),
        ('ouvidor_dor', 'ouvidor_dor', 6, 3, [], 'Ouvidor ferido.'),
        ('ouvidor_morte', 'ouvidor_morte', 7, 2, [L('carne_pesado', 'cauda', -12, 150, pitch=0.9)], 'Morte do Ouvidor + corpo caindo.'),
        ('bocalume_gorgolejo', 'bocalume_gorgolejo', 3, 2, [], 'Lesma gorgolejando (ocioso).'),
        ('bocalume_ataque', 'bocalume_ataque', 7, 2, [], 'Bote do Bocalume.'),
        ('bocalume_morte', 'bocalume_morte', 7, 2, [L('gosma_esmaga', 'cauda', -5, 90, pitch=0.85)], 'Morte do Bocalume (gosma desabando).'),
        ('criatura_grunhido', 'criatura_grunhido', 4, 3, [], 'Grunhido generico de criatura.'),
        ('elite_rugido', 'elite_rugido', 8, 1, [], 'Rugido de elite.'),
        ('chefe_rugido', 'chefe_rugido', 9, 1, [L('peso_thump', 'sub', -8, 20, pitch=0.7, peso=True)], 'Rugido de chefe.')]:
    E(n, 'SFX', [L(g, 'corpo', 0)] + extra, d, prioridade=pr, max_vozes=mv, pv=0.05, cooldown_ms=120,
      **({'duck_db': -5, 'duck_ms': 900} if n in ('elite_rugido', 'chefe_rugido') else {}))

# ---------------------------------------------------------------- ambiente (usado pelo ambiente.gd)
for n, g, d in [('amb_caverna_base', 'amb_caverna_base', 'Cama estereo da caverna.'), ('amb_abismo_respiracao', 'amb_abismo_respiracao', '"Respiracao" do abismo: volume modulado lentamente pelo ambiente.gd.'),
                ('amb_vento_caverna', 'amb_vento_caverna', 'Vento com rajadas (modulado).'), ('amb_goteiras', 'amb_goteiras', 'Cama de goteiras.'),
                ('amb_cascata', 'amb_cascata', 'Cascata (emissor posicional).'), ('amb_rio_subterraneo', 'amb_rio_subterraneo', 'Rio subterraneo (emissor posicional).'),
                ('lanterna_crepitar', 'lanterna_crepitar', 'Lanterna da guilda (emissor posicional mono).'), ('fungos_zumbido', 'fungos_zumbido', 'Cogumelos bioluminescentes (emissor posicional mono).')]:
    E(n, 'Ambiente', [L(g, 'corpo', 0)], d, prioridade=1, max_vozes=8, laco=True, pv=0.0, vv=0.0, espacial=n not in ('amb_caverna_base', 'amb_abismo_respiracao', 'amb_vento_caverna', 'amb_goteiras'))
E('gota_eco', 'Ambiente', [L('gota_eco', 'corpo', -4, pv=0.08)], 'Gota isolada com eco (disparada em pontos aleatorios).', prioridade=1, max_vozes=3, pv=0.06, vv=4.0)

# ---------------------------------------------------------------- UI e musica
for g in ['ui_cancelar', 'ui_confirmar', 'ui_inventario', 'ui_navegar', 'ui_nivel', 'ui_saque_raro']:
    E(g, 'UI', [L(g, 'corpo', 0)], 'Interface.', prioridade=6, max_vozes=2, pv=0.0 if g in ('ui_nivel', 'ui_saque_raro') else 0.02, vv=0.5)
for g in ['stinger_vitoria', 'stinger_derrota']:
    E(g, 'Musica', [L(g, 'corpo', 0)], 'Vinheta.', prioridade=9, max_vozes=1, pv=0.0, vv=0.0)
MUSICA = {g: [a['arquivo'] for a in CAT['eventos'][g]['arquivos']] for g in ['exploracao', 'tensao', 'abismo']}


# ---------------------------------------------------------------- grupos
EQUALIZA = ('combate', 'impacto', 'itens', 'reacoes', 'movimento', 'corda', 'maquina')


def grupos_da_biblioteca():
    """grupos = eventos da biblioteca. Para efeitos pontuais, ganho_db aproxima o loudness das variacoes de um grupo
    (a biblioteca foi normalizada por pico, entao variacoes densas soam mais altas que as secas)."""
    G = {}
    for k, v in CAT['eventos'].items():
        if v['categoria'] == 'compostos':
            continue
        ar = v['arquivos']
        g = dict(arquivos=[a['arquivo'] for a in ar], pico_em_s=[a['pico_em_s'] for a in ar],
                 duracao_s=[a['duracao_s'] for a in ar], laco=v['laco'], canais=v['canais'])
        if v['categoria'] in EQUALIZA and not v['laco'] and len(ar) > 1:
            l = np.array([a['lufs'] if a['lufs'] is not None else np.nan for a in ar], float)
            ref = np.nanpercentile(l, 30)
            g['ganho_db'] = [round(float(np.clip(0.7 * (ref - x), -6, 0)), 2) if np.isfinite(x) else 0.0 for x in l]
        g['ataque_em_s'] = [ataque(a['arquivo']) for a in ar] if not v['laco'] and v['categoria'] != 'musica' else [0.0] * len(ar)
        G[k] = g
    return G


def ataque(rel):
    """instante do ataque (primeira amostra a 12 dB do pico): e o que deve cair no quadro de contato."""
    x = motor.carrega(rel)
    m = np.abs(x).max(1)
    return round(float(np.argmax(m > m.max() * motor.db(-12)) / SR), 3)


def _codifica(x, rel):
    import soundfile as sf, subprocess, tempfile
    dst = os.path.join(RAIZ, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    for _ in range(4):
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as t:
            tmp = t.name
        sf.write(tmp, x.astype(np.float32), SR, subtype='FLOAT')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '6', '-ar', str(SR), dst], check=True)
        os.unlink(tmp)
        motor._cache.pop(rel, None)
        y = motor.carrega(rel)
        tp = motor.tp_db(y)
        if tp <= -1.0:
            return y, tp
        x = x * motor.db(-1.2 - tp)
    return y, tp


def assa(G):
    """assa os eventos com compor=True em biblioteca/compostos/<evento>_<i>.ogg.
    Gera ate 12 candidatos por evento, descarta os que tem o pico tarde demais (o transiente tem de estar no contato),
    leva cada um ao loudness momentaneo maximo do evento (alvo_lufs: define o peso relativo entre classes) com um
    limitador de pico a -1,3 dBTP e descarta quem precisaria de mais de 4 dB de reducao (transiente esmagado).
    Ficam os 6 com menos limitacao, preferindo transientes diferentes."""
    org = {a['arquivo']: a['origem'] for v in CAT['eventos'].values() for a in v['arquivos'] if v['categoria'] != 'compostos'}
    novos = {}
    for f in os.listdir(os.path.join(RAIZ, 'biblioteca', 'compostos')) if os.path.isdir(os.path.join(RAIZ, 'biblioteca', 'compostos')) else []:
        os.unlink(os.path.join(RAIZ, 'biblioteca', 'compostos', f))
    for nome, ev in EV.items():
        if not ev.get('compor'):
            continue
        esc = motor.Escolhedor(G, seed=sum(map(ord, nome)) * 101)
        cands = []
        vistos = set()
        for _ in range(40):
            ev2 = dict(ev, pitch_var=0.035, volume_var_db=0.0)
            vozes = motor.instancia(ev2, esc, peso=1.0, camadas=ev['camadas'])
            chave = tuple((v['grupo'], v['indice']) for v in vozes)
            if chave in vistos:
                continue
            vistos.add(chave)
            x = motor.apara_inicio(motor.renderiza(vozes, ch=1))
            m = np.abs(x).max(1)
            pico_em = np.argmax(m) / SR
            if pico_em > ev.get('pico_max_s', 0.13):
                continue
            gr = 0.0
            for _ in range(2):  # normaliza, limita e corrige de novo a perda de loudness do limitador
                x = x * motor.db(ev['alvo_lufs'] - motor.momentaneo_max(x))
                x, g = motor.limitador(x, -1.3)
                gr = max(gr, g)
            if gr > 4.0:  # precisaria esmagar o transiente: descarta
                continue
            ating = -gr
            cands.append((ating, x, vozes))
            if len(cands) >= 12:
                break
        # prefere transientes diferentes entre as 6 escolhidas
        cands.sort(key=lambda c: -c[0])
        esc6, usados = [], set()
        for c in cands:
            t = (c[2][0]['grupo'], c[2][0]['indice'])
            if t not in usados or len(cands) - len(esc6) <= 0:
                esc6.append(c); usados.add(t)
            if len(esc6) == N_COMP:
                break
        for c in cands:
            if len(esc6) >= N_COMP: break
            if not any(c is e for e in esc6): esc6.append(c)
        arqs = []
        for i, (_, x, vozes) in enumerate(esc6, 1):
            rel = f'biblioteca/compostos/{nome}_{i}.ogg'
            y, tp = _codifica(x, rel)
            m = np.abs(y).max(1)
            origem = []
            for v in vozes:
                for o in org[v['arquivo']]:
                    o2 = dict(o)
                    o2['camada'] = dict(arquivo_biblioteca=v['arquivo'], papel=v['papel'], atraso_ms=round(v['atraso_s'] * 1000, 1),
                                        pitch=round(v['pitch'], 4), ganho_db=round(20 * np.log10(v['ganho']), 2))
                    origem.append(o2)
            arqs.append(dict(arquivo=rel, duracao_s=round(len(y) / SR, 3), pico_em_s=round(float(np.argmax(m) / SR), 3),
                             lufs=round(motor.lufs(y), 1), lufs_momentaneo_max=round(motor.momentaneo_max(y), 1), pico_dbfs=round(float(20 * np.log10(m.max())), 2), pico_verdadeiro_dbtp=round(tp, 2), origem=origem))
            print(f'  {rel}  {arqs[-1]["duracao_s"]}s pico_em={arqs[-1]["pico_em_s"]} lufs={arqs[-1]["lufs"]} tp={tp:.2f}')
        print(f'{nome}: {len(cands)} candidatos, alvo {ev["alvo_lufs"]} LUFS momentaneo max, reducao do limitador ate {max(-c[0] for c in esc6):.1f} dB')
        novos['comp_' + nome] = dict(categoria='compostos', canais=1, laco=False,
                                     nota=f'Composto assado de {nome}: ' + ' + '.join(f"{c['grupo']}({c['papel']}, {c['volume_db']:+g} dB, +{c['atraso_ms']:g} ms, pitch {c['pitch']:g})" for c in ev['camadas']),
                                     arquivos=arqs)
    return novos


def main():
    G = grupos_da_biblioteca()
    novos = assa(G)
    for k in [k for k, v in CAT['eventos'].items() if v['categoria'] == 'compostos']:
        del CAT['eventos'][k]
    CAT['eventos'].update(novos)
    json.dump(CAT, open(os.path.join(RAIZ, 'catalogo.json'), 'w'), ensure_ascii=False, indent=1)
    for k, v in novos.items():
        G[k] = dict(arquivos=[a['arquivo'] for a in v['arquivos']], pico_em_s=[a['pico_em_s'] for a in v['arquivos']],
                    duracao_s=[a['duracao_s'] for a in v['arquivos']], laco=False, canais=1,
                    ataque_em_s=[ataque(a['arquivo']) for a in v['arquivos']])
    eventos = {}
    for nome, ev in EV.items():
        e = copy.deepcopy(ev)
        if e.pop('compor', False):
            e['receita_composto'] = e['camadas']
            e['camadas'] = [L('comp_' + nome, 'composto', 0, pv=0.02)]
            e['pitch_var'] = min(e['pitch_var'], 0.04)
            e.pop('alvo_lufs', None)
        for c in motor.camadas_do_evento(e) + e.get('receita_composto', []):
            assert c['grupo'] in G, (nome, c['grupo'])
        for al in (e.get('alvos') or {}).values():
            for c in al:
                assert c['grupo'] in G, (nome, c['grupo'])
        eventos[nome] = e
    out = dict(
        versao=1,
        descricao='Mapa evento -> camadas do Plumbdeep. Gerado por som/scripts/compor.py; edite la e rode de novo. '
                  'Caminhos relativos a raiz de audio (padrao res://audio/). Volumes em dB, atrasos em ms, pitch como fator (pitch_var = +-fracao).',
        buses=['Master', 'Mundo', 'SFX', 'Golpes', 'Ambiente', 'Caverna', 'Musica', 'UI'],
        grupos=G, eventos=eventos, musica=MUSICA)
    os.makedirs(os.path.join(RAIZ, 'godot'), exist_ok=True)
    json.dump(out, open(os.path.join(RAIZ, 'godot', 'eventos.json'), 'w'), ensure_ascii=False, indent=1)
    print(len(eventos), 'eventos,', len(G), 'grupos,', sum(len(v['arquivos']) for v in novos.values()), 'compostos')


if __name__ == '__main__':
    main()

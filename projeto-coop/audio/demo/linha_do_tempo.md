# Demo de som do Plumbdeep: linha do tempo

Arquivo: `plumbdeep_demo.ogg` (e `plumbdeep_demo.wav`, 48 kHz/24 bits, so no scratchpad). Duracao 43 s, -18.4 LUFS integrado, pico verdadeiro -1.17 dBTP.

Montada por `scripts/demo.py` com a mesma logica do `som.gd` (camadas do `eventos.json`, escolha sem repetir, variacao de pitch/volume, peso, alvo, ducking do ambiente), mais um envio de reverb de caverna (sox reverb, so o sinal molhado, -4 dB) e um limitador no master. Os sopros (swing) foram posicionados como faz `Som.tocar_antes_do_contato`: o pico do arquivo cai 25 ms antes do contato.

Os tempos de golpe sao **tempos de contato** (o quadro em que a arma encosta). O ritmo de cada classe e curto-curto-LONGO:

| Classe | Golpe 1 -> 2 | Golpe 2 -> final | Carater |
|---|---|---|---|
| Escorador (viga) | 0,38 s | 0,82 s | grave, longo, sub forte, ducking -7 dB e hit-stop 110 ms no final |
| Cristaleira (raio) | 0,35 s | 0,85 s | estalo seco + descarga eletrica; hit-stop 70 ms |
| Coveira (pa) | 0,38 s | 0,82 s | pancada metalica oca, corrente do turibulo na cauda; hit-stop 90 ms |
| Gancheiro (punhais) | 0,22 s | 0,53 s | curto e seco, sem sub; final = estalo da corda + punhalada dupla |

## Secoes

- ** 0.00 s** Ambiente
- ** 1.25 s** Escorador (viga): curto-curto-LONGO
- ** 5.29 s** Cristaleira (geodo/raio)
- ** 8.55 s** Coveira (pa + turibulo)
- **11.75 s** Gancheiro (punhais): rapido e seco
- **14.60 s** Reacao Corrente (raio na poca)
- **18.30 s** Prumo: lance e recepcao
- **23.00 s** Guincho e elevador
- **27.20 s** Inimigos, elite e morte

## Eventos

| Tempo (s) | Secao | Evento | O que se ouve | Arquivos sorteados |
|---:|---|---|---|---|
| 0.000 | Ambiente | `amb_caverna_base` | cama em laco (amb_caverna_base_2.ogg), -3 dB | amb_caverna_base_2.ogg |
| 0.000 | Ambiente | `amb_abismo_respiracao` | cama em laco (amb_abismo_respiracao_1.ogg), -4 dB | amb_abismo_respiracao_1.ogg |
| 0.000 | Ambiente | `amb_vento_caverna` | cama em laco (amb_vento_caverna_2.ogg), -11 dB | amb_vento_caverna_2.ogg |
| 0.000 | Ambiente | `amb_goteiras` | cama em laco (amb_goteiras_2.ogg), -6 dB | amb_goteiras_2.ogg |
| 0.000 | Ambiente | `lanterna_crepitar` | cama em laco (lanterna_crepitar_1.ogg), -12 dB | lanterna_crepitar_1.ogg |
| 0.000 | Ambiente | `amb_cascata` | cama em laco (amb_cascata_1.ogg), -9 dB | amb_cascata_1.ogg |
| 0.800 | Ambiente | `gota_eco` | gotas isoladas com eco em pontos aleatorios, ~28/min | - |
| 1.250 | Escorador (viga): curto-curto-LONGO | `passo_pedra_pesado` | passo pesado | passo_pedra_pesado_3.ogg, peso_thump_4.ogg |
| 1.780 | Escorador (viga): curto-curto-LONGO | `passo_pedra_pesado` | passo pesado | passo_pedra_pesado_2.ogg, peso_thump_3.ogg |
| 2.206 | Escorador (viga): curto-curto-LONGO | `escorador_swing_leve` | sopro (pico do arquivo em 2.27 s) | viga_whoosh_5.ogg |
| 2.300 | Escorador (viga): curto-curto-LONGO | `escorador_impacto_leve` | golpe 1 (contato) | escorador_impacto_leve_5.ogg, carne_medio_2.ogg |
| 2.360 | Escorador (viga): curto-curto-LONGO | `ouvidor_dor` | Ouvidor ferido | ouvidor_dor_1.ogg |
| 2.446 | Escorador (viga): curto-curto-LONGO | `escorador_swing_leve` | sopro (pico do arquivo em 2.66 s) | viga_whoosh_4.ogg |
| 2.680 | Escorador (viga): curto-curto-LONGO | `escorador_impacto_leve` | golpe 2 (contato, 0,38 s depois) | escorador_impacto_leve_4.ogg, carne_medio_5.ogg |
| 3.385 | Escorador (viga): curto-curto-LONGO | `escorador_swing_pesado` | sopro (pico do arquivo em 3.48 s) | viga_whoosh_6.ogg, viga_whoosh_2.ogg |
| 3.500 | Escorador (viga): curto-curto-LONGO | `escorador_impacto_final` | golpe 3 LONGO (contato, 0,82 s depois) + hit-stop 110 ms + ducking -7 dB | escorador_impacto_final_6.ogg, carne_pesado_6.ogg, osso_quebra_3.ogg |
| 3.660 | Escorador (viga): curto-curto-LONGO | `ouvidor_morte` | Ouvidor morre | ouvidor_morte_3.ogg, carne_pesado_4.ogg |
| 5.293 | Cristaleira (geodo/raio) | `cristaleira_carga` | sopro (pico do arquivo em 5.57 s) | raio_carga_2.ogg |
| 5.600 | Cristaleira (geodo/raio) | `cristaleira_impacto_leve` | raio 1 (contato) no Bocalume | cristaleira_impacto_leve_5.ogg, gosma_esmaga_4.ogg |
| 5.700 | Cristaleira (geodo/raio) | `bocalume_gorgolejo` | Bocalume reage | bocalume_gorgolejo_2.ogg |
| 5.950 | Cristaleira (geodo/raio) | `cristaleira_impacto_leve` | raio 2 (contato, 0,35 s depois) | cristaleira_impacto_leve_4.ogg, gosma_esmaga_1.ogg |
| 5.976 | Cristaleira (geodo/raio) | `cristaleira_carga` | sopro (pico do arquivo em 6.77 s) | raio_carga_3.ogg |
| 6.800 | Cristaleira (geodo/raio) | `cristaleira_impacto_final` | descarga final (contato) + hit-stop 70 ms | cristaleira_impacto_final_3.ogg, gosma_esmaga_4.ogg |
| 6.950 | Cristaleira (geodo/raio) | `bocalume_morte` | Bocalume morre | bocalume_morte_1.ogg, gosma_esmaga_1.ogg |
| 8.550 | Coveira (pa + turibulo) | `coveira_turibulo` | turibulo balancando | turibulo_corrente_5.ogg |
| 8.846 | Coveira (pa + turibulo) | `coveira_swing` | sopro (pico do arquivo em 9.07 s) | pa_whoosh_2.ogg, turibulo_corrente_3.ogg |
| 9.100 | Coveira (pa + turibulo) | `coveira_impacto_leve` | pazada 1 (contato) | coveira_impacto_leve_6.ogg, carne_medio_3.ogg |
| 9.160 | Coveira (pa + turibulo) | `criatura_grunhido` | criatura grunhe | criatura_grunhido_2.ogg |
| 9.350 | Coveira (pa + turibulo) | `coveira_swing` | sopro (pico do arquivo em 9.46 s) | pa_whoosh_4.ogg |
| 9.480 | Coveira (pa + turibulo) | `coveira_impacto_leve` | pazada 2 (contato, 0,38 s depois) | coveira_impacto_leve_5.ogg, carne_medio_5.ogg |
| 10.046 | Coveira (pa + turibulo) | `coveira_swing` | sopro (pico do arquivo em 10.28 s) | pa_whoosh_2.ogg, turibulo_corrente_1.ogg |
| 10.300 | Coveira (pa + turibulo) | `coveira_impacto_final` | pazada final (contato) + hit-stop 90 ms | coveira_impacto_final_1.ogg, carne_pesado_1.ogg |
| 11.750 | Gancheiro (punhais): rapido e seco | `esquiva` | esquiva | esquiva_2.ogg |
| 12.133 | Gancheiro (punhais): rapido e seco | `gancheiro_swing` | sopro (pico do arquivo em 12.17 s) | punhal_whoosh_5.ogg |
| 12.200 | Gancheiro (punhais): rapido e seco | `gancheiro_impacto_leve` | punhalada 1 (contato) | gancheiro_impacto_leve_3.ogg, carne_leve_5.ogg |
| 12.260 | Gancheiro (punhais): rapido e seco | `ouvidor_dor` | Ouvidor ferido | ouvidor_dor_3.ogg |
| 12.326 | Gancheiro (punhais): rapido e seco | `gancheiro_swing` | sopro (pico do arquivo em 12.39 s) | punhal_whoosh_4.ogg |
| 12.420 | Gancheiro (punhais): rapido e seco | `gancheiro_impacto_leve` | punhalada 2 (contato, 0,22 s depois) | gancheiro_impacto_leve_4.ogg, carne_leve_3.ogg |
| 12.884 | Gancheiro (punhais): rapido e seco | `gancheiro_swing` | sopro (pico do arquivo em 12.92 s) | punhal_whoosh_2.ogg |
| 12.950 | Gancheiro (punhais): rapido e seco | `gancheiro_impacto_final` | finalizador: corda + punhalada dupla (contato) | gancheiro_impacto_final_6.ogg, carne_medio_6.ogg |
| 13.200 | Gancheiro (punhais): rapido e seco | `ouvidor_morte` | Ouvidor morre | ouvidor_morte_1.ogg, carne_pesado_3.ogg |
| 14.600 | Reacao Corrente (raio na poca) | `passo_agua` | passo na poca | passo_agua_6.ogg |
| 14.950 | Reacao Corrente (raio na poca) | `passo_agua` | passo na poca | passo_agua_3.ogg |
| 15.100 | Reacao Corrente (raio na poca) | `ouvidor_guincho` | Ouvidor dentro da poca guincha | ouvidor_guincho_4.ogg |
| 15.593 | Reacao Corrente (raio na poca) | `cristaleira_carga` | sopro (pico do arquivo em 15.88 s) | raio_carga_2.ogg |
| 15.900 | Reacao Corrente (raio na poca) | `corrente_reacao` | CORRENTE: eletricidade na agua (contato) | corrente_reacao_1.ogg |
| 16.000 | Reacao Corrente (raio na poca) | `corrente_zumbido` | laco da poca eletrificada (1,8 s, fade) | raio_zumbido_agua_2.ogg |
| 16.050 | Reacao Corrente (raio na poca) | `ouvidor_dor` | Ouvidor ferido | ouvidor_dor_1.ogg |
| 16.450 | Reacao Corrente (raio na poca) | `ouvidor_morte` | Ouvidor eletrocutado | ouvidor_morte_4.ogg, carne_pesado_1.ogg |
| 18.300 | Prumo: lance e recepcao | `pegar` | Escorador pega o Prumo | pegar_3.ogg |
| 18.600 | Prumo: lance e recepcao | `prumo_lancar` | lance | lancar_3.ogg, viga_whoosh_1.ogg |
| 18.920 | Prumo: lance e recepcao | `escorador_swing_leve` | Prumo cruzando o ar | viga_whoosh_5.ogg |
| 19.350 | Prumo: lance e recepcao | `prumo_recepcao` | recepcao comum | prumo_recepcao_5.ogg |
| 19.850 | Prumo: lance e recepcao | `passo_pedra_pesado` | Passo (passo_pedra_pesado) | passo_pedra_pesado_5.ogg, peso_thump_1.ogg |
| 20.250 | Prumo: lance e recepcao | `passo_pedra_pesado` | Passo (passo_pedra_pesado) | passo_pedra_pesado_2.ogg, peso_thump_5.ogg |
| 20.700 | Prumo: lance e recepcao | `prumo_lancar` | lance de volta | lancar_1.ogg, viga_whoosh_2.ogg |
| 21.050 | Prumo: lance e recepcao | `escorador_swing_leve` | Prumo cruzando o ar | viga_whoosh_4.ogg |
| 21.450 | Prumo: lance e recepcao | `prumo_recepcao_golpe` | GOLPE DE RECEPCAO no tempo certo + hit-stop 90 ms | prumo_recepcao_golpe_2.ogg |
| 22.150 | Prumo: lance e recepcao | `saco_saque` | saco de saque pesado | saco_saque_1.ogg, moedas_4.ogg |
| 22.400 | Prumo: lance e recepcao | `moedas` | Moedas | moedas_3.ogg |
| 23.000 | Guincho e elevador | `guincho_catraca` | catraca (um clique por passo da manivela) | guincho_catraca_3.ogg |
| 23.150 | Guincho e elevador | `guincho_corrente` | corrente do guincho | guincho_corrente_4.ogg |
| 23.700 | Guincho e elevador | `corda_rangido` | corda sob tensao | corda_rangido_4.ogg |
| 24.100 | Guincho e elevador | `roldana_rangido` | roldana | roldana_rangido_2.ogg |
| 24.500 | Guincho e elevador | `guincho_corrente` | Corrente correndo no guincho | guincho_corrente_1.ogg |
| 24.900 | Guincho e elevador | `corda_puxar` | puxao na corda | corda_puxar_3.ogg |
| 25.300 | Guincho e elevador | `roldana_rangido` | Roldana rangendo | roldana_rangido_1.ogg |
| 26.100 | Guincho e elevador | `elevador_trava` | elevador trava (baque + sub) | elevador_trava_4.ogg, peso_thump_1.ogg |
| 27.200 | Inimigos, elite e morte | `ouvidor_telegrafia` | telegrafia: aviso do ataque do Ouvidor | ouvidor_telegrafia_3.ogg |
| 27.950 | Inimigos, elite e morte | `ouvidor_guincho` | Guincho do Ouvidor | ouvidor_guincho_1.ogg |
| 28.350 | Inimigos, elite e morte | `bocalume_gorgolejo` | Bocalume se aproxima | bocalume_gorgolejo_4.ogg |
| 29.000 | Inimigos, elite e morte | `bocalume_ataque` | bote do Bocalume | bocalume_ataque_3.ogg |
| 29.080 | Inimigos, elite e morte | `jogador_dano` | heroi leva dano | carne_medio_4.ogg, peso_thump_4.ogg |
| 29.806 | Inimigos, elite e morte | `escorador_swing_leve` | sopro (pico do arquivo em 29.88 s) | viga_whoosh_5.ogg |
| 29.900 | Inimigos, elite e morte | `escorador_impacto_leve` | viga na gosma (alvo gosma) | escorador_impacto_leve_5.ogg, gosma_esmaga_3.ogg |
| 30.100 | Inimigos, elite e morte | `escorador_swing_leve` | sopro (pico do arquivo em 30.26 s) | viga_whoosh_3.ogg |
| 30.280 | Inimigos, elite e morte | `escorador_impacto_leve` | Viga acertando (golpes 1 e 2 do combo curto-curto-LONGO) | escorador_impacto_leve_6.ogg, gosma_esmaga_4.ogg |
| 30.870 | Inimigos, elite e morte | `escorador_swing_pesado` | sopro (pico do arquivo em 31.08 s) | viga_whoosh_1.ogg, viga_whoosh_5.ogg |
| 31.100 | Inimigos, elite e morte | `escorador_impacto_final` | golpe final na gosma | escorador_impacto_final_2.ogg, gosma_esmaga_2.ogg |
| 31.250 | Inimigos, elite e morte | `bocalume_morte` | Bocalume morre | bocalume_morte_3.ogg, gosma_esmaga_3.ogg |
| 32.300 | Inimigos, elite e morte | `elite_rugido` | ELITE ruge | elite_rugido_5.ogg |
| 33.400 | Inimigos, elite e morte | `fulgor` | FULGOR: explosao de poeira de esporos | poeira_explosao_6.ogg, peso_thump_2.ogg |
| 34.070 | Inimigos, elite e morte | `coveira_swing` | sopro (pico do arquivo em 34.18 s) | pa_whoosh_4.ogg |
| 34.200 | Inimigos, elite e morte | `coveira_impacto_final` | pazada final na elite | coveira_impacto_final_4.ogg, carne_pesado_2.ogg |
| 34.320 | Inimigos, elite e morte | `elite_rugido` | elite morre (rugido grave) | elite_rugido_6.ogg |
| 34.950 | Inimigos, elite e morte | `aterrissagem_pesada` | corpo da elite cai | aterrissagem_pesada_1.ogg, peso_thump_1.ogg |
| 35.600 | Inimigos, elite e morte | `stinger_vitoria` | vinheta de vitoria | stinger_vitoria_1.ogg |

## Ducking aplicado ao ambiente

| Tempo (s) | Atenuacao (dB) | Duracao (ms) |
|---:|---:|---:|
| 2.30 | -1.5 | 250 |
| 2.68 | -1.8 | 250 |
| 3.50 | -7.0 | 650 |
| 5.60 | -1.2 | 200 |
| 5.95 | -1.4 | 200 |
| 6.80 | -5.0 | 500 |
| 9.10 | -1.5 | 250 |
| 9.48 | -1.8 | 250 |
| 10.30 | -6.0 | 550 |
| 12.20 | -0.5 | 120 |
| 12.42 | -0.6 | 120 |
| 12.95 | -3.0 | 300 |
| 15.90 | -4.0 | 400 |
| 19.35 | -3.2 | 350 |
| 21.45 | -7.0 | 600 |
| 26.10 | -4.0 | 400 |
| 29.08 | -2.4 | 300 |
| 29.90 | -1.5 | 250 |
| 30.28 | -1.8 | 250 |
| 31.10 | -7.0 | 650 |
| 32.30 | -5.0 | 900 |
| 33.40 | -6.0 | 600 |
| 34.20 | -6.0 | 550 |
| 34.32 | -5.0 | 900 |
| 34.95 | -3.0 | 300 |

## Limites honestos

- A trilha foi montada e medida, mas **nao foi ouvida** por quem a montou. Os tempos, niveis e espectro foram verificados por medicao e pelo espectrograma (`demo_espectro.png`).
- No jogo o hit-stop tambem baixa o pitch das outras vozes por ~0,1 s; a demo nao simula isso (o ambiente so sofre o ducking).
- O reverb da demo e o `reverb` do sox, parecido mas nao igual ao AudioEffectReverb do bus Caverna.

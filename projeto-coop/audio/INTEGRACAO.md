# Integração do som no Plumbdeep (Godot 4.7)

Este guia explica como ligar a biblioteca de som ao jogo:

- como os golpes ganham peso;
- como disparar o som no quadro de contato;
- como sincronizar os clipes de prova do Movie Maker;
- o que muda na prévia web no iPhone.

Todos os sons são gravações reais de bancos com licença aberta. A origem de cada arquivo está em `catalogo.json` e os créditos em `CREDITOS.md`. Nenhum som é procedural.

## 1. O que tem aqui

| Caminho | O que é |
|---|---|
| `biblioteca/<categoria>/*.ogg` | 337 sons da coleta (Vorbis 48 kHz) |
| `biblioteca/compostos/*.ogg` | 65 golpes **assados** em camadas (seção 3) |
| `godot/som.gd` | Autoload `Som`: pools de vozes, camadas, variação, prioridade, ducking, hit-stop, reverb, abafado, música e log |
| `godot/ambiente.gd` | `AmbienteCaverna`: camas estéreo, respiração do abismo, rajadas, gotas e emissores posicionais |
| `godot/audio_bus_layout.tres` | Buses e efeitos |
| `godot/eventos.json` | Mapa evento → camadas → arquivos → parâmetros. **É gerado**: edite `scripts/compor.py` e rode `python3 -I scripts/compor.py` (refaz também os compostos e o `catalogo.json`) |
| `catalogo.json` | Origem, licença, duração, `pico_em_s` e loudness de cada arquivo, inclusive dos compostos |
| `demo/` | Trilha de demonstração (43 s), linha do tempo e espectrograma |
| `scripts/` | Mixagem offline com a mesma lógica do `som.gd`: compostos, demo e trilha a partir de log |

## 2. Instalação no projeto

1. Copie a pasta `audio/` para a raiz do projeto Godot, de modo que exista `res://audio/godot/som.gd`.
2. Em **Projeto > Configurações > Áudio > Buses**, aponte `Default Bus Layout` para `res://audio/godot/audio_bus_layout.tres`.
3. Em **Autoload**, registre `res://audio/godot/som.gd` com o nome **`Som`**.
4. Em cada nível, coloque um nó `AmbienteCaverna` e adicione os nós de som aos grupos certos:
   - cascatas: `som_cascata`
   - rio: `som_rio`
   - lanternas da guilda: `som_lanterna`
   - cogumelos: `som_fungo`
   - poças de cal fervendo: `som_fervura`
   - poças eletrificadas: `som_poca_eletrica`
5. Opcional: numa tela de carregamento, chame `Som.precarregar()`, que decodifica e guarda todos os streams.

Os caminhos dentro de `eventos.json` são relativos a `Som.raiz` (padrão `res://audio/`).

### Buses

```
Master   Compressor (-10 dB, 2,5:1) + HardLimiter (-1 dBTP)
├─ Mundo     LowPass "Abafado" (desligado; Som.abafar liga)
│  ├─ SFX
│  │  └─ Golpes   HighPass 32 Hz (limpa sub inútil)
│  ├─ Ambiente    Compressor com sidechain = Golpes (ducking automático)
│  └─ Caverna     Reverb 100 % molhado (bus de ENVIO)
├─ Musica    Compressor com sidechain = Golpes (ducking leve)
└─ UI
```

- **Envio de reverb.** As vozes 3D mandam uma parte do sinal para o bus `Caverna` através de uma `Area3D` com `reverb_bus_enabled`.
  - O `Som` cria uma área global enorme (camada de física 20) e controla a quantidade com `Som.definir_espaco(0..1)`: 0 = túnel apertado, 1 = salão ou abismo amplo. O tamanho da sala, o pre-delay e o abafamento do reverb acompanham.
  - Para salas específicas, ponha uma `Area3D` na **camada 20**, com `reverb_bus_enabled`, `reverb_bus_name = "Caverna"` e prioridade maior que -100.
- **Ducking em duas camadas.**
  - O compressor com sidechain no `Ambiente` abaixa o ambiente sozinho em qualquer golpe.
  - Os eventos pesados (`duck_db` e `duck_ms` no JSON, escalados pelo `peso`) aplicam um ducking extra por script, com ataque de 60 dB/s e volta de 9 dB/s. Por exemplo, o golpe final da viga tira 7 dB do ambiente por 0,65 s.
  - Na música, o ducking é metade disso.
- **Abafado.** `Som.abafar(true, 700)` serve para debaixo d'água, atordoado ou pausa. Afeta o mundo, mas não a música nem a UI. `Som.abafar(false)` volta ao normal.

## 3. Desenho em camadas: de onde vem o peso

Cada golpe tem até quatro papéis de camada:

- **transiente**: o estalo de contato, a primeira coisa que se ouve;
- **corpo**: a massa do golpe;
- **cauda**: poeira, corrente ou estalo residual;
- **sub**: o baque grave do `peso_thump`, só nos golpes pesados.

Além disso, uma camada de **superfície** depende do que foi atingido. Ela é escolhida em tempo de jogo pela opção `alvo`: `carne`, `gosma`, `pedra` ou `nada`.

| Evento | Camadas (atraso) | Alvo LUFS-M | Hit-stop | Ducking |
|---|---|---|---|---|
| `escorador_impacto_leve` | viga (0) + sub −9 dB (6 ms) | −17 | – | −2,5 dB |
| `escorador_impacto_final` | viga 0,9× (0) + viga 0,76× −5 dB (14 ms) + sub 0,88× (4 ms) + poeira −10 dB (28 ms) | **−14** | 110 ms | −7 dB |
| `cristaleira_impacto_leve` | estalo (0) + descarga curta −14 dB (10 ms) | −18 | – | −2 dB |
| `cristaleira_impacto_final` | estalo (0) + descarga −7 dB + sub −4 dB (6 ms) + estalo residual (140 ms) | −14,5 | 70 ms | −5 dB |
| `coveira_impacto_leve` | pá de ferro (0) + sub −12 dB (5 ms) | −18 | – | −2,5 dB |
| `coveira_impacto_final` | pá 0,86× + pá 0,74× (10 ms) + sub (4 ms) + corrente do turíbulo (70 ms) | −15 | 90 ms | −6 dB |
| `gancheiro_impacto_leve` | corte (0) + metal −8 dB (3 ms) | **−20** | – | −1 dB |
| `gancheiro_impacto_final` | estalo da corda (0) + punhal (22 ms) + punhal (100 ms) + metal (100 ms) + sub quase nulo | −17 | 45 ms | −3 dB |
| `prumo_recepcao` | couro contra o corpo (0) + sub (4 ms) + mão pegando (45 ms) | −17 | – | −4 dB |
| `prumo_recepcao_golpe` | couro (0) + viga −5 dB (6 ms) + sub (4 ms) + tilintar (60 ms) | −14,5 | 90 ms | −7 dB |
| `corrente_reacao` | choque na água + estalo + descarga (35 ms) + respingo pesado | −14,5 | – | −4 dB |

**Por que assar.**

- O motor só dispara camadas atrasadas no próximo quadro, com cerca de 16 ms de imprecisão. Atrasos de 3 a 14 ms entre transiente e sub precisam ser exatos, senão o golpe "desgruda".
- Cada composto conta como **uma voz** em vez de quatro, o que importa no iPhone.

Por isso os golpes acima viraram `biblioteca/compostos/<evento>_N.ogg`.

**Como os compostos foram feitos.** Para cada evento, o script:

1. gerou até 12 candidatos com sorteio e variação de pitch de ±3,5 %;
2. descartou os que têm o pico depois de 130 ms (o estalo tem de estar no contato);
3. levou cada candidato ao loudness momentâneo máximo da tabela, com limitador de pico em −1,3 dBTP;
4. descartou quem precisaria de mais de 4 dB de limitação (transiente esmagado);
5. ficou com os 6 mais limpos, preferindo transientes diferentes.

O resultado são variações com até ~1,5 dB de diferença entre si, e não 10 dB, como acontecia quando se normalizava por pico. Desligue `Som.usar_compostos` para montar as mesmas camadas em tempo de jogo a partir de `receita_composto` (útil para ajustar a mixagem no editor).

**O peso relativo entre classes está no loudness:**

- viga final −14;
- pá final −15;
- raio final −14,5;
- punhal final −17;
- golpes leves 3 a 4 dB abaixo do final da mesma classe;
- punhal leve em −20.

O punhal é curto e seco: sub quase nulo e banda alta. A viga é grave e longa: o sub de 30 a 90 Hz fica 24 dB acima do ambiente na demo.

### Variação, sem repetição robótica

Em cada disparo o `Som`:

1. sorteia um arquivo do grupo **sem repetir o último** (com 6 variações, nunca toca a mesma duas vezes seguidas);
2. aplica uma variação de pitch compartilhada pelo evento (±4 a 7 %: punhal ±6 a 7 %, viga ±4 %), mais ±2 % por camada;
3. varia o volume em ±1,5 dB, mais ±0,75 dB por camada;
4. aplica as probabilidades por camada; por exemplo, o osso quebrando aparece em 50 % dos golpes finais em carne;
5. aplica o `ganho_db` por arquivo. A coleta normalizou por pico, então variações densas soavam mais altas que as secas; `ganho_db` puxa as mais altas até 6 dB para baixo.

### `peso` (0 a 1,5)

O terceiro argumento de `Som.tocar` controla o peso do golpe:

- **sub:** camadas com `escala_peso` ganham 12 dB por unidade de peso e somem abaixo de `peso_min`;
- **pitch:** mais peso, mais grave (`peso_pitch`);
- **volume:** mais peso, mais alto (`peso_volume_db`);
- **ducking:** proporcional ao peso;
- **hit-stop automático:** só com peso ≥ 0,5.

Use o peso para carga do ataque, crítico, ou o Escorador carregando o Prumo.

## 4. Ligando às animações: o quadro de contato

Regra de ouro: **o som do impacto sai no quadro em que a arma encosta**, nunca no início da animação. O sopro (swing) deve ter o **pico 1 a 2 quadros antes** do contato.

### Impacto: method track ou sinal

No `AnimationPlayer` do ataque, adicione uma *Call Method Track* que chama `_contato()` no quadro de contato. Melhor ainda: emita um sinal da hitbox quando ela confirmar o acerto, para não tocar som de carne no ar.

```gdscript
# arma.gd (Escorador)
@export var peso_combo := [0.6, 0.7, 1.0]  # curto, curto, LONGO
@export var quadros_ate_contato := [9, 9, 18]  # do início do movimento até o contato, por golpe
var passo_combo := 0

func _contato(acertou: Node3D) -> void:  # chamado pela hitbox no quadro de contato
	var final := passo_combo == 2
	var evento := "escorador_impacto_final" if final else "escorador_impacto_leve"
	var alvo := "nada"
	if acertou:
		alvo = acertou.get_meta("material_som", "carne")  # Bocalume = "gosma", pedra = "pedra"
	Som.tocar(evento, global_position, peso_combo[passo_combo], {"alvo": alvo, "pitch": 1.0 + 0.03 * passo_combo})
	if final:
		hit_stop(0.11)  # o Som já baixa o pitch das outras vozes durante o hit-stop

func _inicio_do_golpe() -> void:  # primeiro quadro do movimento para frente
	var ate_contato := quadros_ate_contato[passo_combo] / 60.0
	Som.tocar_antes_do_contato("escorador_swing_pesado" if passo_combo == 2 else "escorador_swing_leve",
		global_position, ate_contato)
```

- **`tocar_antes_do_contato(evento, pos, segundos_ate_contato)`** escolhe o arquivo do sopro e lê o `pico_em_s` dele no JSON. Depois agenda o início para que o pico caia 25 ms antes do contato. Se o contato estiver mais perto que o pico, começa o arquivo já adiantado.
- **Miss (golpe no ar):** toque só o sopro.
- **Bloqueio ou parede:** use `alvo: "pedra"` ou `"nada"`.

### Ritmo curto-curto-LONGO sugerido (60 fps)

| Classe | Contato 1 → 2 | Contato 2 → final | Antecipação do final | Hit-stop do final |
|---|---|---|---|---|
| Escorador | 23 quadros (0,38 s) | 49 quadros (0,82 s) | 15 a 20 quadros, sopro duplo grave | 6 a 7 quadros |
| Cristaleira | 21 quadros | 51 quadros (carga audível) | `cristaleira_carga` em `tocar_antes_do_contato` | 4 quadros |
| Coveira | 23 quadros | 49 quadros | sopro + corrente do turíbulo | 5 a 6 quadros |
| Gancheiro | 13 quadros (0,22 s) | 32 quadros | curta | 2 a 3 quadros |

É o ritmo da demo. Ajuste à animação real, mas mantenha a proporção: o terceiro golpe tem de **demorar** para o peso se acumular.

### Hit-stop e câmera lenta

- **Hit-stop:** se o jogo zera ou reduz o `Engine.time_scale`, o `Som` percebe (`seguir_time_scale`) e desce o pitch de todas as vozes até no mínimo 0,55×.
  - Nos eventos com `hit_stop_ms`, as *outras* vozes descem para 0,82× durante o hit-stop. O impacto continua inteiro.
  - Fades e ducking do `Som` usam tempo real, então não congelam durante o hit-stop.
- **Câmera lenta manual:** `Som.definir_camera_lenta(0.5)`.

### Movimento, corda, máquinas e reações

- **Passos:** dispare no quadro em que o pé apoia, com `passo_<superficie>[_pesado]`. O `passo_pedra_pesado` tem sub escalado pelo peso, para o Escorador com a viga ou o Prumo nos ombros.
- **Guincho:** um `guincho_catraca` por "dente" da manivela, no ritmo do giro (a demo usa 0,26 s). Depois `guincho_corrente` enquanto a carga sobe, e `elevador_trava` na parada.
- **Corrente (raio na água):** `Som.tocar("corrente_reacao", pos)`. Depois ponha a poça no grupo `som_poca_eletrica` enquanto ela estiver eletrificada, ou use `var id = Som.tocar("corrente_zumbido", pos)` e `Som.parar(id, 0.4)`.
- **Laços com id:** `Som.mover(id, pos)` move a voz. A opção `{"seguir": no}` faz a voz acompanhar um nó.

## 5. Clipes de prova do Movie Maker

### A) Gravar o áudio junto (recomendado)

O Movie Maker mistura o áudio do jogo no mesmo relógio dos quadros. Com saída **`.avi`** ele grava vídeo MJPEG e áudio PCM 48 kHz estéreo no mesmo arquivo. Com saída `.png`, o áudio sai num `.wav` ao lado.

**Verificado nesta máquina com o Godot 4.7.2** (`godot_teste/filme.tscn`, no scratchpad):

```bash
xvfb-run -a godot --path proj --rendering-driver opengl3 \
  --write-movie /tmp/clipe.avi --fixed-fps 60 res://cenas/prova.tscn
ffmpeg -i /tmp/clipe.avi -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k clipe.mp4
```

- O AVI saiu com `mjpeg` + `pcm_s16le 48000 Hz 2 canais`.
- Os ataques caíram 17 a 33 ms (1 a 2 quadros) depois do quadro em que `Som.tocar` foi chamado. O som disparado no `_process` do quadro N sai a partir do quadro N+1. Para o contato visual coincidir, dispare no próprio quadro de contato; esse atraso é o mesmo do jogo real.
- **Não use `--headless`**: o Movie Maker precisa renderizar. Use `xvfb-run`.

### B) Montar a trilha com ffmpeg a partir do log

Use quando o clipe foi gravado sem áudio ou quando quiser remixar sem regravar.

1. Ligue `Som.registrar_log = true`. Isso pode ser feito no `_ready` da cena. Cada `Som.tocar` grava uma linha em `user://som_log.jsonl` com:
   - quadro desenhado e quadro de física;
   - evento, peso, alvo e posição;
   - `atraso_s` e `desde_s`.

   A primeira linha guarda o quadro inicial e o fps do Movie Maker.
2. Monte a trilha:
   ```bash
   python3 -I scripts/trilha_do_log.py ~/.local/share/godot/app_userdata/<Projeto>/som_log.jsonl trilha.wav --fps 60 [--ambiente]
   ffmpeg -i clipe.mp4 -i trilha.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -shortest clipe_com_som.mp4
   ```

O script usa a mesma lógica de camadas (`eventos.json`), com `tempo = (quadro − quadro_inicial + 1) / fps + atraso_s`. No teste, os ataques da trilha montada pelo log ficaram a até cerca de 20 ms dos do AVI gravado pelo Godot. O sorteio das variações é outro (semente própria), então os arquivos escolhidos não são os mesmos da gravação.

Os scripts Python (`motor.py`, `compor.py`, `demo.py`, `demo_folha.py`, `trilha_do_log.py`) estão em `audio/scripts/` e precisam de numpy, scipy, soundfile, pyloudnorm, ffmpeg e sox. Rode a partir da pasta `audio/` (ex.: `python3 -I scripts/trilha_do_log.py ...`).

## 6. Web e iPhone

- **Desbloqueio de áudio.** O Safari só libera o `AudioContext` depois de um gesto do usuário.
  - Na web, o `Som` começa **bloqueado**: guarda os pedidos de ambiente e música e os toca no primeiro toque, clique ou tecla.
  - A prévia deve abrir com uma tela "Toque para descer", para que o primeiro toque aconteça antes da ação.
  - Efeitos pontuais disparados antes do desbloqueio também entram na fila. Evite disparar muitos.
- **Formato.** Todos os arquivos são Ogg Vorbis 48 kHz.
  - O Godot importa e decodifica os `.ogg` pelo próprio motor.
  - Mesmo assim, **teste no aparelho**: não verifiquei aqui como o modo *Sample* do Godot web trata Vorbis no Safari do iOS.
  - Se algum som não tocar no iPhone, a saída é reimportar só aquele arquivo como WAV, que custa mais memória.
- **Limite de vozes.** Na web, o `Som` reduz os pools para 20 vozes 3D, 8 2D e 8 planas, e o `AmbienteCaverna` liga metade dos emissores por tipo.
  - Os compostos ficam sempre ligados na web: uma voz por golpe em vez de três a cinco.
  - Em quatro jogadores com inimigos, a prioridade dos eventos (9 = golpe final ou chefe, 1 = gota de ambiente) decide quem perde a voz.
- **Efeitos de bus na web.** Desde o Godot 4.3, a exportação web usa por padrão o modo de reprodução *Sample* (`audio/general/default_playback_type.web`), que toca direto no Web Audio. Pela documentação do Godot que conheço, nesse modo **os efeitos de bus não são aplicados**: compressor, limitador, reverb, low-pass e sidechain. O volume dos buses e o pitch das vozes funcionam. Confira nas notas da versão em uso.
  - **O que continua funcionando nesse modo:** compostos pré-mixados, variação, ducking por script (via volume do bus) e hit-stop por pitch.
  - **O que se perde:** o reverb de caverna e o abafado. Os sons ficam secos.
  - **Alternativa:** exportar com *Stream* e threads, o que exige cabeçalhos COOP/COEP no servidor e custa mais CPU no iPhone. Só vale se a prévia precisar do reverb.
- **Tamanho.** A pasta de áudio tem cerca de 46 MB, dos quais 27 MB são música. Na prévia web, leve uma faixa de exploração e uma de tensão, e deixe as demais fora da exportação (filtro de exportação), para o download inicial não pesar.
- **Latência.** Na web, o som sai com algumas dezenas de ms a mais que no PC (`audio/driver/output_latency.web`). Isso não muda o lugar do disparo, que continua sendo o quadro de contato.

## 7. Testes feitos

- **`godot_teste/` (scratchpad), Godot 4.7.2, `--headless` e também `xvfb-run --audio-driver Dummy`:**
  - importa e carrega os **402** arquivos (337 + 65 compostos) e as 7 músicas como `AudioStreamOggVorbis`;
  - dispara os **83** eventos (3D, 2D e sem posição, com todos os alvos);
  - roda a receita em tempo real, o sopro antes do contato, o limite de vozes por evento (12 disparos → 4 vozes), o roubo por prioridade com o pool cheio, o hit-stop com câmera lenta (pitch 0,525×), o ducking (−10 dB no bus Ambiente), o abafado, o reverb por espaço, a música e o `AmbienteCaverna` com 4 camas e 7 emissores.

  Resultado `TESTE_OK`, 0 falhas. Na saída, o Godot avisa de objetos ainda vivos ao sair, por causa do `quit()` no meio de tweens e vozes. Isso é do teste, não do jogo.
- **Movie Maker:** gravou o AVI com áudio. Os ataques caíram nos quadros esperados, como descrito na seção 5.
- **Demo** (`demo/linha_do_tempo.md`): −18,4 LUFS, −1,17 dBTP, 43 s, espectrograma em `demo/demo_espectro.png`.

## 8. Limites honestos

- **Nada disso foi ouvido.** As escolhas se apoiam em medições (loudness, pico verdadeiro, instante do pico e do ataque, bandas), espectrogramas e na reputação das fontes. Antes de travar a mixagem, faça uma passada de escuta, de preferência em fone e no alto-falante do iPhone.
- **Lacunas de gravação** (ver `notas_coleta.md`): corda arrebentando (`corda_estalo` é provisório), turíbulo (`coveira_turibulo` é corrente + sopro), rolamento, motor do elevador, sons próprios do Ouvidor (orelhas) e lama pesada (pitch 0,85).
- **Calibração.** Os níveis relativos (−14 a −20 LUFS-M nos golpes, ambientes a −26 LUFS, bus Ambiente a −3 dB) são um ponto de partida medido, não uma mixagem final.

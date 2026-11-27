# Prova de estilo: Tolda Viva (v2, depois da crítica)

Cena de demonstração, não é o jogo. Tudo foi gerado por código neste container (bpy + numpy + Godot 4.7.2), sem modelos, texturas ou fontes baixadas. Personagens e cenário são originais.

A v1 completa (imagens, clipe e estas notas como estavam) está em `entrega/v1/`. O código da v1 está em `bak_v1/` (cópia de `tools/` e `proj/` antes de qualquer mudança).

## O que mudou na v2, pela ordem da crítica

### 1. Valores e cores (piso, inimigo e herói em famílias separadas)

- **Piso:** pinho claro e pouco saturado (`#C2B399`, saturação ~0,2). A textura agora só dá o detalhe:
  - o shader `chao` lê a claridade da textura e aplica sobre uma cor fixa, com o contraste comprimido a 42% (variação de cerca de ±5% no valor entre tábuas);
  - os discos das luas e a luz "de noite" ficaram menos amarelos.
- **Carunchos:** laca vermelho-sangue (`laca #7A1622`) com pernas, antenas e furos em laca quase preta (`laca_esc #2B0C12`). O `boneco.gdshader` ganhou:
  - uma banda de especular dura (degrau em N·H), só no casco vermelho, não nas pernas finas;
  - uma contraluz fria (`rim_amt`).
- **Heróis:** continuam quentes. A cor do jogador entrou no modelo, nos punhos dos quatro: magenta, folha, ciano e gema. O lenço do Tarugo e a fita do chapéu da Anilina já tinham.
- **Paleta:** foi para 26 cores (+2 lacas).
- **Verde-folha do jogador:** foi escurecido para `#2E7D22`. Com o anel fino, a separação em deuteranopia tinha caído para 0,049.
- **Não fiz o pós-processo em cinza ligado por tecla.** Quem valida é o portão de cinza, que já existia, e a folha `portoes.png`.

### 2. Câmera e rostos

- **Cabeças 1,2 a 1,3× maiores** (Tarugo 1,2, porque a cabeça dele já era 1,12; os outros 1,28 a 1,3):
  - no bpy, as peças da cabeça escalam em volta da base do crânio;
  - os ossos `jaw`, `hat` e `cap*` são escalados junto, então o rig continua certo;
  - o teste de colisão do adereço segue com **0 violações**.
- **Aba da Anilina** 25% menor (raio de 0,40 para 0,31) e inclinada 26° para trás (era 17°).
- **Câmera:**
  - quadro bonito com inclinação de 30°;
  - clipe com 34°;
  - estresse com 36° e 12 m (antes, 38° e 13 m em todos).
- **Quadro bonito recomposto:** Tarugo e Anilina se encaram em 3/4, de frente para a plateia; os dois rostos aparecem.
- **O "pitch de 60°" da crítica não existia:** a câmera já estava em 38°. O que escondia os rostos eram a cabeça pequena, a aba e a composição de costas.

### 3. Anéis e telegrafias

- **Anel do jogador** (`anel.gdshader`):
  - 40% da espessura e alfa de 0,68;
  - sem a seta;
  - o símbolo de forma (quadrado, triângulo, círculo, losango) ficou pequeno e assentado no próprio anel, do lado da câmera, como um tique. O símbolo continua, porque é ele que garante a leitura em daltonismo.
- **Telegrafia** (`perigo.gdshader`, reescrito):
  - sem preto e sem zebra;
  - a borda é uma costura de marcação em ponto-atrás tracejado, com cada ponto inclinado como linha de verdade e passo constante em metros;
  - um preenchimento de vermelhão translúcido avança de fora para dentro (anel e retângulo) ou da praga para a ponta (faixa de avanço, com divisas internas), para mostrar o tempo da preparação;
  - o vermelhão continua reservado ao perigo.

### 4. Texturas em degrau de pixel

A causa não era textura. Eram faces chapadas com ruído de talho num toon de 2 degraus: cada face caía de um lado do limiar, e o conjunto lia como xadrez. Mudei assim:

- **Normais suaves em todas as peças de madeira:**
  - quina viva só onde o ângulo entre faces passa de 50° (chanfro de verdade);
  - ruído de talho com 45% da amplitude.
- **Cores por face que faziam blocos:**
  - a faixa de cabelo do Tarugo tinha faces claras na frente;
  - o topo do macete tinha anéis por face;
  - os respingos claros do chapéu da Anilina (agora só 9 respingos azuis);
  - o casco do caruncho tinha 26 furos (agora 9).
- **Veio de madeira:** um veio em baixa frequência no shader (`veio`, ±5%) entra só na madeira lisa dos heróis.
- **Bevel modifier:** não usei, porque as peças já são chanfradas na construção (`mk('cube', bevel=…)`).

### 5. Efeitos: uma forma por arma, a cor do jogador só no clarão

- **Macete (Serragem):**
  - anel de choque achatado, com borda irregular de lasca, em 2 cores de matéria (serragem e madeira). Magenta e folha só nos 2 primeiros quadros;
  - lascas escuras de maravalha;
  - grãos de serragem;
  - nuvem de serragem em flipbook de 4 quadros a 12 por segundo (`nuvem.gdshader`: incha e se desfaz por erosão), rente ao chão e dos lados, para a estátua de machê ficar à vista.
- **Broxa (Tinta):** respingo de gota assimétrica com satélites em leque (`respingo.gdshader`), só em anilina e no azul escuro da borda.
- **Removidos:** a estrela verde, a estrela rosa e a estrela branca do estouro.
- **Estouro Machê:**
  - a forma dominante é a dos cacos creme de papel machê;
  - as cores dos dois jogadores ficam em só 6 retalhos de seda de 0,9 s (antes, 12 retalhos de 1,6 s). É a assinatura da reação cruzada.
- **Vida dos detritos:**
  - serragem e gotas, 0,8 a 1,3 s (antes, até 6 s), encolhendo no fim;
  - cacos afundam no praticável 0,15 s depois de pousar (afundam em 0,35 s), com teto de 0,7 s mesmo se ainda quicam. No clipe, o chão fica limpo cerca de 1,2 s depois do estouro (a v1 deixava cacos até o fim);
  - as contagens caíram (serragem de 140 para 70 grãos no golpe).
- **Clarão branco no alvo:** de 2 quadros (já existia; era de 3).

### 6. Animação visível no jogo

- **Idle vivo:** "balanço de marionete pendurada nos fios" por código, contínuo a 60, como manda o conceito (a mão do bonequeiro é contínua; a pose continua segurada):
  - sobe e desce 2,2 cm em 1,7 s;
  - pêndulo de 1,8° em 2,3 s;
  - entra nos dois heróis, por cima do idle de poses (que já respirava o peito).
- **Antecipação do Tarugo:**
  - o tronco gira 44° no total (o peito tinha 20°; a coluna ganhou mais 18° e o peito passou para 26°);
  - o agachamento ficou mais fundo.
- **Não fiz o achatamento de 10% no root:** o conceito proíbe deformar madeira (regra 2). O achatamento fica na saia, 1,12 × 0,86.
- **Hit-stop do atacante:** de 10 para **6 quadros**. O alvo continua parado por 14 quadros, porque vira estátua (9) e racha (4) antes de estourar.
- **Soco de escala no alvo:** 1,15 → 1,12 → 1,08 → 1,04.
- **Tremor de câmera medido em pixels:** até 5 px em 720p, com decaimento; soco de 4 px para baixo no contato, de 3 px no estouro e soco de zoom de 3%.
- **Reação dos inimigos** (ações novas no bpy: `susto` e `andar`):
  - os carunchos a até 3,6 m do estouro pulam de susto, com pernas abertas, antenas em pé e olhos arregalados (pupila de 0,42 para 0,2 por 30 quadros), e recuam até 0,75 m;
  - dois carunchos andam (trípode a 15 poses/s) até 1,6 m dos heróis;
  - todos tremem de leve a 20 poses/s e respiram na escala.
- **Depois do golpe:**
  - o Tarugo olha para a plateia e dá um pulinho de vaidade;
  - a Anilina dá um pulinho também;
  - o clipe foi encurtado para 250 quadros (4,2 s).

### 7. Rastro de Tinta

- Largura afunilando em ease-in até zero na cauda.
- Erosão de alfa por manchas de cerda (sem fios de 1 px).
- Borda no mesmo azul 30% mais escuro, sem o verde.
- Histórico de 0,25 s (15 quadros).
- Largura de 0,16 para 0,13 m.

### 8. Quatro jogadores

- **Contorno na cor do jogador:**
  - 1,6 px por fora do traço de tinta;
  - feito como `next_pass` da casca, recuado 16 cm em profundidade, para só a silhueta externa aparecer, sem linhas internas;
  - em volta dos pés, o chão esconde parte dele.
- **Inimigos:**
  - tamanho variando de 0,8 a 1,2;
  - segundo arquétipo de silhueta: o **caruncho-de-chifre**, com chifre de rinoceronte, élitros abertos e asa de papel.
- **Não fiz o raio-x por stencil** (silhueta vista através de quem cobre). Não validei o stencil do Godot 4.7 no Compatibility a tempo. Também **não reduzi o alfa do efeito de aliado só sobre outros jogadores**: o rastro do estresse ficou com 0,8 de alfa em tudo.

### 9. Luz de palco

- **Luz-chave:**
  - mais alta (sombras reais curtas no quadro bonito);
  - mais fraca (energia de 1,0 para 0,85).
- **Canhões seguidores de verdade:** um `SpotLight3D` por herói, vindo do balcão. O toon (`boneco` e `chao`) foi corrigido para que spot só some dentro do cone; antes, qualquer luz extra somava a tinta de sombra no quadro todo.
- **Vinheta de palco** presa à câmera (bordas escurecidas).
- **Sombra do braço do bonequeiro:** mais curta (2,6 para 1,8 m) e mais leve (75%).

### 10. Sanefas e pregos

- **Bambinela e empanada:**
  - metade da altura;
  - listras 2× mais largas;
  - mais escuras;
  - a de baixo virou só uma franja.
- **Pregos:** 1 par a cada 3 tábuas, com 60% menos contraste. O praticável foi regenerado.

### Bug corrigido no caminho

`source_color` num uniforme posto por código chegava sem conversão sRGB no Compatibility, e o chão ficava quase branco só nesse renderer. A cor do pinho agora vai em linear, sem a dica, e os dois renderers batem.

## Portões no quadro de estresse (Compatibility, 4 heróis, 20 inimigos, 3 efeitos)

Números em `out2/portoes_v2.json`; folha visual em `entrega/portoes.png`.

| Portão | v1 | v2 |
|---|---|---|
| Cinza: ΔL dos heróis, mínimo / mediana | 0,226 / 0,285 | **0,320 / 0,385** |
| Borrão de 4 px: heróis, mínimo | 0,121 (no limite) | **0,138** |
| Borrão de 4 px: inimigos, mediana / abaixo de 0,12 | 0,120 / 10 de 19 | **0,206 / 2 de 19** |
| Miniatura 320×180: altura dos heróis | 29 a 51 px | **38 a 55 px** |
| Miniatura: inimigos (mediana) | 28 px | 23 px (pior: o enxame agora vai de 0,8 a 1,2×) |
| Anéis: separação mínima normal / deuteranopia / protanopia | 0,140 / 0,056 / 0,141 | 0,160 / **0,069** / 0,092 (protanopia piorou, mas passa de 0,05) |
| Separação pela cor média do corpo | 0,006 a 0,017 | 0,030 a 0,055 |

- **Todos passam**, e os dois que estavam no limite (borrão dos heróis e dos inimigos) ganharam folga.
- **Draw calls do estresse:** 146 (antes, 141), com 4 spots.

## Tempo de render (CPU, lavapipe/llvmpipe)

| Peça | Renderer | Tempo |
|---|---|---|
| beauty.png 1920×1080 (simula 79 quadros) | Forward+ com sombra real, glow e 2 canhões | 8 s |
| stress.png 1280×720 | Compatibility | 7 s; 146 draw calls |
| clipe (250 quadros a 1280×720, Movie Maker a 60 fps; 4,15 s; mp4 de 4,7 MB; gif de 640 px a 15 fps, 2,6 MB) | Forward+ com sombra real, glow e 2 canhões | 4 min 14 s (cerca de 1 s por quadro) |
| folha de modelo (5 faixas de 2400 px) | Forward+ | cerca de 4 s por faixa |
| 9 GLB (com o caruncho-de-chifre), ações, smear e teste de colisão | bpy | 2,6 s |
| praticável regenerado | numpy | 10,6 s |

## O que não deu para corrigir, e por quê

- **Achatamento de 10% no root** (crítica 6): não fiz, porque contraria a regra 2 do conceito ("madeira nunca dobra"). A antecipação cresceu por torção e agachamento.
- **Raio-x por stencil e alfa de 0,5 do efeito de aliado sobre outros jogadores** (crítica 8): não fiz. O contorno na cor do jogador resolve a identidade, mas um herói inteiro atrás do Bastidor ainda some.
- **Pós-processo em cinza por tecla de debug** (crítica 1): não fiz, porque não há "jogo" com teclas nesta cena. A validação em cinza é o portão automático.
- **Brilho da laca:** em alguns ângulos, ainda recorta em formas retas sobre o casco facetado (dá para ver no caruncho de baixo, à direita, no quadro bonito). Pediria mais segmentos no élitro ou uma normal suavizada à parte.
- **Hit-stop:** o conceito pede 10 quadros no estouro, e a crítica pede de 4 a 6. Fiquei com 6 no atacante e 14 de estátua no alvo.
- **Miniatura dos inimigos:** caiu de 28 para 23 px (mediana), por causa da variação de tamanho. Os portões de contraste subiram bastante, então troquei tamanho por leitura.

## O que ainda é fraco (honesto)

- **Ainda não é "além de triple A".** É um toon de boneco de indie caprichado: luz de palco melhor, mas sem textura pintada à mão nos rostos, sem oclusão de contato e sem pós-processo autoral.
- **Os cacos de machê voando ainda leem como "pedaços brancos"** nos quadros do meio do clipe. Falta a tira impressa de jornal aparecer mais.
- **O rastro de Tinta é um arco largo e liso.** Está melhor no fim (sem fios), mas no meio ainda é azul chapado, sem cerdas fortes.
- **Desempenho no celular:** não foi medido. O estresse agora tem 4 spots.
- **Paridade de renderer:** está razoável depois da correção do sRGB, mas o Compatibility ainda fica um pouco mais claro e amarelo que o Forward+ (compare `stress.png` com `beauty.png`).
- **A Anilina continua com 13 mil triângulos** (aba do chapéu).

## Arquivos

Entregas, em `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/provas/tolda-viva/entrega/`:
- `beauty.png`, `stress.png`, `clip.mp4`, `clip.gif`, `modelo.png` e `portoes.png` (extra);
- `notas.md`;
- `v1/`, com as versões anteriores de todas as entregas.

Código novo ou alterado na v2:
- **shaders novos:** `proj/shaders/nuvem`, `respingo`, `vinheta`;
- **shaders reescritos:** `anel`, `perigo`, `fita`, `onda`;
- **shaders alterados:**
  - `boneco` (laca, contraluz, veio e luz de spot correta);
  - `chao` (pinho fixo e contraste comprimido);
  - `contorno` (recuo para o contorno do jogador);
- **scripts do Godot:**
  - `proj/main.gd` (linha do tempo do duelo e do estresse);
  - `proj/vfx.gd` (nuvem, respingo, vidas e histórico do rastro);
  - `proj/boneco.gd` (laca e contorno do jogador);
  - `proj/palco.gd` (canhões, vinheta e sanefas);
- **geradores e animação:**
  - `tools/malha.py` (normais suaves com quina viva e cabeça escalada);
  - `tools/bonecos.py` (cabeças, aba, punhos, caruncho de laca e caruncho-de-chifre);
  - `tools/poses.py` (torção da antecipação, `susto` e `andar`);
  - `tools/exportar.py` (ações por família);
  - `tools/cenario.py` (pregos);
  - `tools/paleta.py` (+2 lacas e o verde-folha);
  - `tools/folha_modelo.py`.

Comandos (a partir da pasta da prova):
- **quadro bonito:** `tools/run.sh fplus 1920x1080 out2/beauty_final.png cena=duelo beauty=1 pc=1 quadro=79 yawT=35 c0x=-0.4 c0z=0.8 nx=1.9 nz=-0.2 yawN=-35 c1x=0.85 c1z=0.15 yawC1=60 dist=6.6 tx=0.3 tz=0.0 pitch=30`
- **estresse:** `tools/run.sh compat 1280x720 out2/stress_v2.png cena=estresse frames=40 canhao_e=0.75`
- **máscaras:** os mesmos argumentos, com `mask=1` e `mask=2`. Depois, `python3 tools/portoes.py out2/stress_v2.png out2/mask_stress.png out2/mask_aneis.png out2/portoes_v2`.
- **clipe:** `EXTRA="--write-movie <pasta>/q.png" tools/run.sh fplus 1280x720 <pasta>/run.png cena=duelo pc=1 frames=250`, seguido de `tools/codificar.sh <pasta> entrega/clip`.
- **bonecos:** `python3 tools/exportar.py proj/assets/glb`.

A descrição de base da prova (o momento, os personagens, o cenário a têmpera e a lista de efeitos da v1) continua válida e está em `entrega/v1/notas.md`.

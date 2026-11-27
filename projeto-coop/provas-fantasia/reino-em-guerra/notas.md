# Prova de estilo: A Pequena Hoste, "O Vau da Tempestade" (v2)

Esta é uma cena de demonstração, não o jogo. Tudo foi gerado por código neste container. Os personagens foram feitos em bmesh no Blender 5.3 (bpy) e exportados como GLB com esqueleto e ações. O terreno, a água, o trigo, as pedras, a ponte, a casa, o forte em ruína, o moinho queimado, a árvore-forca, a cerca, as estacas, os estandartes queimados, os corvos, o céu, a névoa e as partículas foram feitos no próprio Godot 4.7.2. Nenhum modelo, textura ou fonte foi baixado. As únicas texturas são um grão de aquatinta e uma fibra de papel de 256 × 256 px, geradas em numpy.

A v2 responde à crítica independente da v1 ("aprovar a linguagem, reprovar a cena"). As entregas da v1 estão guardadas em `entrega/v1/`, e o código da v1 está em `out/v1_codigo/`.

Pasta: `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/provas-fantasia3/reino-em-guerra/`

## Entregas

| Arquivo | O que é | Renderer | Tempo |
|---|---|---|---|
| `entrega/beauty.png` | 1920×1080. É o quadro global 351 (quadro 194 da cena de combate), logo depois do raio. Usa a câmera nova de combate: 22°, FOV de 42°, 15 m, yaw de 50° e curvatura de 0,008. Tem sombra direcional, névoa volumétrica, 4 FogVolumes de altura, 2 feixes de sol na névoa, glow e MSAA 2× | Forward+ | 24 s |
| `entrega/stress.png` | 1280×720 na mesma câmera, com 4 heróis com anel e símbolo, 20 mortos em gravura negativa e 3 efeitos: vau eletrificado pelo Raio de Contrato, chão consagrado e Incêndio de Breu na margem norte. Também há 6 lanças de perigo e o relógio da Carpideira. É a atmosfera barata da Web | Compatibility | cerca de 10 s |
| `entrega/portoes.png` e `portoes.json` | Portões do estresse: cinza, borrão de 4 px, miniatura, daltonismo, paleta e V mínimo | — | 3 s |
| `entrega/clip.mp4` e `clip.gif` | 17 s (1.022 quadros a 60 fps), renderizados em 1080p pelo Movie Maker e reduzidos para 1280×720. Mostram a chegada, o combate inteiro com os 4 heróis e a travessia até a brecha da cerca | Forward+ | veja a seção do clipe |
| `entrega/modelo.png` | 2400×4880. As 4 classes e 2 inimigos aparecem de frente, de 3/4 e de perfil. Há 3 faixas de poses-chave (Sineira, Porta-Estandarte e Bruxa) e o **teste de silhueta preta a 64 px** na câmera do jogo | Forward+ | cerca de 45 s |

## O que mudou, correção por correção

### 1. Composição em profundidade, mundo aberto (era "arena em faixas horizontais")

- **Câmera nova:** inclinação de 34° para 22°, FOV de 30° para 42° e distância de 19 m para 15 m. A curvatura do "tronco que rola" ficou mais leve (de 0,065 para 0,008, começando a 8 m). Ela agora cai na direção em que a câmera olha (`curva_dir` global em todos os shaders), e não mais no eixo norte do mundo. Por isso dá para girar a câmera.
- **O rio corre na diagonal.** A câmera tem yaw de 50° e olha rio acima. O rio ainda dobra para o norte a leste (`bend()` em `mundo.gd`, repetido no shader da água). Na tela, o vau atravessa o quadro a cerca de 25° e leva o olho até a ponte e o forte.
- **Três pontos de interesse em profundidades diferentes:** a árvore-forca com gaiola e corvos a 10 m, o forte em ruína com a torre de 13 m e o portão escuro da masmorra (com luz fraca dentro) a cerca de 30 m, e o moinho de poste queimado a cerca de 35 m. Ao fundo há 4 planos de colina em silhueta, cada vez mais claros e com crista mais fina, além do Campanário e da Prensa em silhueta clara.
- **A cerca virou cerca de verdade:** são mourões tortos na margem norte, com uma brecha onde passa a estrada. A faixa que lia como "cerca" na v1 era a hachura vertical dos cartões de colina, que foi trocada por silhuetas sem hachura (`silhueta.gdshader`).
- **Estradas que saem do quadro:** a estrada do sul sai pela borda de baixo. A do norte passa pela brecha, sobe ao forte e tem um ramo que sai pela esquerda. As duas têm sulcos de roda e barro pisado no shader do terreno.
- **Névoa em camadas:** há névoa de altura no próprio shader da gravura (`nevoa_alt`). Como o mundo cai com a curvatura, ela engrossa sozinha com a distância. Somam-se 4 cartões de aquatinta (rio, margem norte, vale do forte e várzea) e, no PC, 4 FogVolumes de densidade crescente (0,02 → 0,08).
- **Oclusores de primeiro plano:** estacas de cerco afiadas e cardos secos nos cantos de baixo, e uma árvore morta junto da câmera, cujos galhos entram pelo canto de cima na chegada.
- **Terreno maior:** a grade não é uniforme. É fina (0,35 m) no meio e cresce 18% por célula até ±110 m, com 194 × 173 vértices indexados. As normais saem da própria grade.

### 2. Os mortos saltam do fundo (eram "hachura cinza sobre margem cinza")

- **Gravura em negativo para a Procissão** (`grav_neg` em `grav.gdshaderinc`). O morto é tinta cheia e a luz é cavada em linhas de papel, como na matriz entalhada. A borda tem um fio de papel (rim). O contorno ficou 1,5 vez mais grosso.
- O olho verde ganhou um **halo de aquatinta** (`halo.gdshader`), um cartão preso ao osso da cabeça com grão verde que rareia para fora. É o "bloom" da gravura, feito de pontos e não de degradê. O pós devolve todo verde brilhante para o verde exato da paleta.
- O fundo atrás deles (margem norte e água rasa) ficou mais claro com a névoa. No estresse, o contraste dos mortos subiu de **0,111 para 0,324**.

### 3. Onda de choque na água (era "grade de debug sobre o rio inteiro")

- A grade radial foi apagada. O eletrificado agora são **fios curtos em zigue-zague até 5,5 m**, que afinam nas pontas, somem para a borda e trocam a cada 3 quadros.
- O impacto é desenhado em **anéis de pena** (`onda.gdshader`): 2 ou 3 anéis concêntricos em arcos com afinamento, quebrados por ruído, na cor do papel em grão e com vida de 0,4 s (24 quadros). São 4 ondas: Investida (2,2 m), raio (6 m), Dobre Duplo (7 m, em cera) e breu caindo.

### 4. Raio (era "polilinha de UI")

- O traçado é feito por **deslocamento de ponto médio recursivo** (5 níveis), com 5 galhos que afinam até zero. A fita afina ao longo do canal e tem miolo branco-papel, fio azul e **halo de tinta**.
- O impacto segue esta sequência: 2 quadros de prova em negativo **dentro da paleta** (o claro vira tinta e o escuro vira papel, sem o rosa e o azul da v1), 2 quadros de **clarão** em que o papel estoura e a linha fica, e reimpressão desalinhada. No PC, por 7 quadros, o sol pula para a direção do raio com **sombra dura** (sem penumbra). Fica uma **marca de queimado** (estrela de rachaduras) no pé do mastro.

### 5. Cores da Bruxa e do Sapador (eram "materiais padrão")

- As roupas passaram para pigmento: **roxo-amora `#6B2A63`** e **anil `#2F4677`**. A paleta foi para 22 cores. As cores vivas de identificação (múrice e ultramar) ficaram só no anel do jogador. As duas novas cores passam do limiar de saturação do pós e por isso também levam o desalinho de registro.

### 6. Silhuetas de cima (o Sapador era um "disco marrom")

- **Sapador:** ganhou pá e enxadão cruzados nas costas, saindo acima da aba e formando um X lido de cima. Tem lanterna pendurada com mola, que acende e apaga a tinta num raio de 2,4 m, e cachecol de anil com 2 ossos de mola que voam com o vento.
- **Sineira:** a coroa passou a ter 8 velas, 1,35 vez maiores e com chamas maiores. O apagador da coroa vai a 3 m e faz uma poça de papel quente no chão. O sino ficou 1,3 vez maior e o braço que o segura abriu 22°, então o sino fica fora da saia.
- A **folha tem o teste de silhueta preta a 64 px** na câmera de 22°, de 3/4 de frente, de 3/4 de costas e de perfil. As 6 figuras se distinguem: balde com mastro, coroa de velas com sino, X de ferramentas, chapéu torto, pique comprido e capuz.

### 7. Telegrafia (o verde do perigo era o mesmo dos olhos)

- **Vermelhão de perigo `#B5301F`** só para telegrafia. O verde-mordente agora fica só nos mortos (olhos, boca e halo).
- A investida dos piques é desenhada como uma **lança**: larga no pé (no morto) e fina na ponta. O contorno é em **traço de pena**, de largura variável, e o preenchimento sobe do pé à ponta mostrando o tempo até o golpe, com uma linha de tinta na frente. O resto da lança é hachura animada.
- O círculo da Carpideira e o aviso do raio do clima (6 m) viraram **relógios**: o contorno é de pena, o setor já cumprido leva hachura fina e há um ponteiro de tinta.

### 8. Os "espinhos" laranja e brancos na água

- Eram o breu em chamas, que flutuava no rio. Agora o **Incêndio de Breu** fica na margem norte e tem forma de fogo de verdade. É uma poça de breu (tinta com borda de sombra) com um barril do Sapador tombado. As línguas de fogo (`fogo.gdshader`) são cartões em gota, com pé largo, contorno de tinta, corpo laranja-mínio e miolo de cera, e mudam de forma a cada 3 quadros. Há também brasas subindo e uma coluna de fumaça em aquatinta. No clipe, o fogo nasce do fio do raio que chega ao breu (reação de dois jogadores: o breu do Sapador mais o raio do contrato da Bruxa).

### 9. Dark fantasy em low key (era "livro ilustrado claro")

- **`escuro_mundo`:** é tinta a mais só no mundo. Os heróis continuam claros. Passando de 4 camadas, a sombra funda fecha em **aquatinta** (o grão de resina vira tinta). A margem sul virou sombra-queimada, e o trigal é sombra que só acende em ocre perto de tochas, velas e lanterna (`trigo.gdshader` lê os apagadores).
- O **ocre agora é ilha de luz:** a reserva de papel em volta de cada herói é papel quente. As tochas da milícia, a coroa da Sineira, a lanterna do Sapador, a janela da casa e o portão do forte abrem poças na tinta.
- **Céu de tempestade** em 5 famílias de linha que se somam (chega a 93% de tinta no alto). O horizonte fica claro de névoa e há o rasgo âmbar a leste.
- **Vinheta de buril:** são linhas a 50° e a 155° que engrossam para os cantos (a largura é o tom), não grão. Há também **manchas d'água no papel** (áreas âmbar com borda de maré).
- **Cenário:** há 5 mortos de batalhas antigas meio afundados no rio, 3 estandartes queimados e rasgados, 2 bandos de corvos (árvore-forca e torre) e a Carpideira no plano médio, a 7 m.
- A luminância média caiu de 0,529 para 0,375 no `beauty` e de 0,546 para 0,346 no `stress`.

### 10. Animação (pouca demonstração)

- O **clipe de 17 s** mostra os 4 heróis: chegada correndo pela estrada, Unção, Pote de Breu, Investida, Fincar, Contrato da Bruxa, raio, Incêndio de Breu, passe do sino, Recepção, devolução desajeitada e a travessia do grupo até a brecha da cerca. A câmera faz um movimento contínuo, descendo da altura de exploração (30°, 24 m) para a de combate (22°, 15 m) e depois recuando e girando para a estrada do norte (21°, 16,5 m).
- **Hit-stop global no contato:** a linha do tempo do mundo congela 4 quadros na Investida, 3 no raio e 3 na Recepção, com chuva, névoa e molas parados (`g_para_f`). Só a câmera treme, 3 quadros em cada contato.
- **Milícia dessincronizada:** cada um tem fase própria e velocidade sorteada entre 0,92 e 1,08. Eles param espalhados na margem norte, e não mais em bloco.
- **Estandarte em pano simulado:** é um verlet de 11 × 7 pontos preso ao mastro, com vento em rajadas e tremular. Ele abre no Fincar e balança nas costas durante a corrida. As velas tremem em degrau. Uma rajada global de vento entra nas molas (chapéu, cachecol, véu, saia e tabardo).
- Ações novas: corrida e "olha para os lados" do Sapador, e corrida e **Contrato** da Bruxa. O Contrato tem antecipação com puxão de ombro, aponta o céu, segura, achata a 0,8 no raio, estica a 1,1, admira e volta.
- **Correção de rig:** a escala das poses era aplicada nos eixos locais do osso, e por isso "achatar na vertical" achatava de frente para trás e torcia a cabeça da Bruxa em 90°. Agora a escala é convertida dos eixos do esqueleto para os do osso (`animar.apply_q`). Todos os achatamentos e esticamentos passaram a ser verticais, como sempre deveriam ter sido.

### 11. Borda e salto de câmera

- O plano near passou para 0,3 m. A chuva a menos de 7 m da câmera é descartada, porque eram esses traços gigantes colados na lente. A casa saiu da frente da câmera.
- A câmera é uma mola amortecida simulada desde o quadro 0, mirando o centro do grupo na altura do terreno. Não há corte. Pitch, distância e yaw mudam por curva suave.

## Portões (`stress.png`, Compatibility), v1 → v2

| Portão | v1 | v2 | Passa? |
|---|---|---|---|
| Cinza: ΔL herói × entorno (mínimo / mediana) | 0,162 / 0,229 | **0,212 / 0,300** | sim, e melhorou |
| Cinza: inimigos (mediana) | 0,111 | **0,324** | sim, quase triplicou |
| Borrão de 4 px: heróis (mínimo) | 0,078 | **0,113** | melhorou, mas ainda fica abaixo da régua de 0,12 |
| Miniatura 320×180: heróis contados | 4 de 4 (21 a 32 px) | 4 de 4 (19 a 39 px) | sim |
| Fora da paleta | 0,02% | **0,01%** (22 cores) | sim |
| Pixels do mundo abaixo de V 11% | 0,000% | 0,000% (V mínimo 12,9%) | sim |
| Perigo × verde dos mortos (ΔE OKLab) | 0 (era a mesma cor) | **0,406** | sim |
| Perigo × vermelhão do jogador 1 (ΔE / ΔL) | — | 0,088 / 0,087 | **fraco**: são do mesmo matiz. O que separa é a forma (lança e relógio contra o anel com torre) e o valor |
| Cores de jogador no anel (normal / deuteranopia / protanopia) | 0,162 / 0,078 / 0,062 | igual | por pouco. O símbolo do anel segura a leitura |

Para chegar a esses números, o estresse teve as posições ajustadas. O Porta-Estandarte e o Sapador ficam na água rasa clareada pela névoa, onde leem escuro sobre claro, e não têm disco de contato. Contra o barro escuro, o Sapador de anil caía para ΔL 0,05.

## O clipe

- São 1.022 quadros a 60 fps (17,0 s), de 1920×1080, reduzidos para 1280×720.
- O mp4 do scratchpad tem crf 21 e 58,6 MB. O do repositório tem crf 24 e 34,5 MB. O grão da gravura pesa na compressão.
- O gif tem 3,8 MB (12 fps, 48 cores).
- O render foi feito em partes de 120 quadros por `tools/clipe_em_partes.sh`, que retoma de onde parou, porque outro processo do container encerrou o render inteiro no quadro 150. Em cada emenda (a cada 119 quadros), o pano do estandarte e as molas recomeçam com 80 passos de assentamento. Pode haver um tranco pequeno ali.
- O render a 1080p custou cerca de 2 s por quadro com o container livre. Sombra em 2 cascatas de 45 m, terreno sem projetar sombra e névoa volumétrica de 64 m baixaram o custo da v2, que tem 3 vezes mais geometria.

| Quadro global | Quadro da cena | O que acontece |
|---|---|---|
| 0 a 150 | chegada | Os 4 heróis correm pela estrada do sul, no meio do trigal escuro, cada um com sua poça de luz. A câmera desce de 30° e 24 m para 22° e 15 m e gira 12° |
| 150 a 213 | 0 a 63 | Unção (o pote de cera voa), Pote de Breu do Sapador (cai na margem norte no 48 e abre um anel de tinta), as lanças vermelhãs enchem e o Porta corre |
| 213 a 217 | 63 | **Hit-stop global de 4 quadros** com tremor. Os 2 Piqueiros voam |
| 217 a 340 | 64 a 190 | Fincar (o pano abre no vento), o relógio vermelhão de 6 m enche e a Bruxa assina o contrato apontando o céu |
| 340 a 343 | 190 | **RAIO**: negativo, clarão, sombra dura, 3 anéis de pena de 6 m, fios elétricos até 5,5 m e marca de queimado |
| 349 a 400 | 196 a 250 | O fio do raio acende o breu e começa o Incêndio de Breu. Os mortos tremem e são prensados em tinta. A Carpideira inspira |
| 400 a 437 | 242 a 280 | Passe do sino e Recepção (**hit-stop de 3**), Dobre Duplo com anéis de cera de 7 m. O consagrado apaga o relógio da Carpideira, e ela recua para a névoa |
| 437 a 530 | 280 a 370 | A milícia atravessa, dessincronizada. Vem a devolução desajeitada do sino |
| 530 a 1022 | 370 a 862 | O grupo atravessa o vau e sobe a estrada do norte até a brecha da cerca. A câmera recua, gira para 54° e mostra o forte e a árvore-forca |

## Versão reduzida para o iPhone (como a captura foi montada)

- O shader da gravura, o negativo dos mortos, a névoa de altura, as lanças, os anéis, o fogo, o apagador por uniform, a reserva, a curvatura e o pós são os mesmos do PC.
- **Ficam de fora:** névoa volumétrica, FogVolume, feixes de luz na névoa, glow, sombra real (troca pelo disco de contato) e as 2 camadas de névoa mais distantes.
- **Fica reduzido:** chuva (480 traços), cinzas (120), trigo (4.000) e brasas (40).
- O que não foi testado: o export Web, o FPS no iPhone e a perda de contexto WebGL. Os 20 mortos ainda são esqueletos completos, e no iPhone deveriam ser VAT.

## O que ficou bom

- **A cena agora lê como mundo.** O rio leva o olho ao fundo, as estradas saem do quadro, a cerca tem brecha e há 3 marcos em 3 profundidades, com a névoa clareando cada plano. A chegada pelo trigal no começo do clipe é o melhor quadro de mundo aberto da prova.
- **A Procissão em gravura negativa** é a melhor ideia nova. Os mortos são uma família visual própria (matriz entalhada), leem de longe como manchas escuras com olhos verdes e não brigam com os heróis coloridos.
- **A semântica de cor** ficou limpa: verde é morto, vermelhão é perigo, a cor viva é jogador e o ocre é luz.
- **O low key** veio da própria linguagem: "luz apaga tinta" virou a ilha ocre em volta dos heróis, das tochas e da lanterna.

## O que é fraco (honesto)

- **Os heróis ainda são pequenos** na câmera de combate (cerca de 90 px a 1080p). Os rostos não leem durante a ação.
- **O ruído do grão:** na névoa sobre áreas escuras e na aquatinta das sombras fundas, o grão de 1 px vira chiado em tela pequena, e mais ainda no gif. A 1080p ele lê como tom.
- **O perigo e o jogador 1 dividem o matiz vermelho** (ΔE 0,088). A forma resolve, mas a cor não.
- **O borrão de 4 px** melhorou (0,078 → 0,113), mas não chegou à régua de 0,12.
- O **relógio vermelhão de 6 m** do raio do clima, com hachura do setor cumprido, ainda pesa demais no quadro durante os 48 quadros de aviso.
- O **fim do clipe** tem um terreno escuro grande e pouco desenhado no primeiro plano da margem norte.
- As **molas na hora do hit-stop** param e voltam de uma vez. A Bruxa achatada no raio fica com o chapéu baixo demais por 2 quadros.
- **Modelos:** continuam lofts sem escultura, com mãos em bloco. Os corpos dos mortos são grandes demais quando vistos de perto (folha), porque a gravura negativa tapa os detalhes do esqueleto.
- **Ficou de fora:** reflexo real dos personagens na água, som, VAT, medição de FPS e o export Web.
- **Mudança contra o documento do conceito:** a câmera de combate da seção 11.6 (34°, FOV 30°, 19 m, curvatura 0,02) foi trocada pela desta prova (22°, 42°, 15 m, 0,008 e yaw por setor). Se aprovada, a seção 11.6 precisa ser atualizada.

## Arquivos de código

Ferramentas (`tools/`):

- `paleta.py`: as 22 cores;
- `malha.py`;
- `herois.py`: o Sapador com ferramentas, lanterna e cachecol, a Sineira com coroa e sino maiores, e as roupas em anil e amora;
- `animar.py`: escala convertida para os eixos do osso;
- `poses.py`: corrida e "olha" do Sapador, corrida e Contrato da Bruxa;
- `exportar.py`;
- `portoes.py`: paleta de 22 cores e semântica de perigo;
- `folha_modelo.py`: faixa da Bruxa e teste de silhueta a 64 px;
- `run.sh` e `codificar.sh`.

Motor (`proj/`):

- `main.gd`: modo máscara na folha e paleta de 22 cores;
- `boneco.gd`: negativo dos mortos, halo dos olhos e molas com vento;
- `mola.gd`: rajada global;
- `mundo.gd`: grade não uniforme, rio curvo, estradas, forte, moinho, árvore-forca, cerca, estacas, árvore de primeiro plano, estandartes queimados, corvos, colinas em silhueta e névoa em 4 planos;
- `cena_vau.gd`: linha do tempo de 17 s, hit-stop global, pano verlet, raio por ponto médio, anéis, incêndio e câmera;
- `cena_estresse.gd`.

Shaders (`proj/shaders/`):

- novos: `onda`, `fogo`, `silhueta` e `halo`;
- alterados: `grav.gdshaderinc` (névoa de altura, `escuro_mundo`, aquatinta de sombra funda, negativo e reserva quente), `agua`, `perigo`, `pos` (paleta de 22 cores, vinheta de buril, manchas d'água, clarão e negativo na paleta), `ceu`, `trigo`, `terreno`, `mundo`, `chuva` (brasas), `fx` (raio em 3 faixas) e `aquatinta` (marca de queimado).

Comandos (a partir da pasta da prova):

- modelos: `python3 tools/exportar.py proj`;
- quadro bonito: `tools/run.sh fplus 1920x1080 entrega/beauty.png cena=vau pc=1 f0=351 frames=3 msaa=2`;
- estresse: `tools/run.sh compat 1280x720 entrega/stress.png cena=estresse frames=4`;
- máscara dos portões: o mesmo comando com `mascara=1 pos=0`, seguido de `python3 tools/portoes.py entrega/stress.png <máscara> entrega/portoes`;
- clipe: `tools/clipe_em_partes.sh`, que chama `cena=vau pc=1 f0=<início> frames=120 msaa=2` com Movie Maker em partes, seguido de `tools/codificar.sh out/clipv2 entrega/clip`;
- folha: `cena=folha who=... [yaws=... mask=1 pos=0 bg=#FFFFFF]` e `cena=poses who=... anim=... ts=...`, seguidos de `python3 tools/folha_modelo.py out/folha2 entrega/modelo.png`.

Nada foi commitado.

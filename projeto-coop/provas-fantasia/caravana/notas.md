# Prova de estilo: Wickwain, a caravana do pavio longo (v2)

Esta é uma cena de demonstração no motor, não o jogo. Tudo foi gerado por código neste container: personagens, adereços, terreno, vegetação, rochas, ruínas, a Wain e os marcos do horizonte em bmesh (Blender 5.3 como módulo Python); cena, shaders, efeitos e animação em Godot 4.7.2. Nenhum modelo, textura ou fonte foi baixado. Não há referência brasileira ou ibérica, nem moldura de palco.

A v2 aplica as 11 correções da crítica independente, na ordem de prioridade. As entregas da v1 estão guardadas em `entrega/v1/`, com as notas antigas.

## O momento mostrado

No Brejo das Lamparinas Afogadas, no fim do crepúsculo, sob chuva fina, com a câmera de combate do jogo (16,5 m, 52°, 30° de campo de visão):

1. A **Rodeira** (manto Carmim) já untou o lodo: as manchas de óleo têm um filete Carmim, a cor de quem untou.
2. O **Apagador** arqueia o cabo de latão sobre a lanterna do **Pavieiro** (Ouro velho), e a telegrafia verde-ácido se fecha em volta dele.
3. O Pavieiro faz o **Lance** da lanterna no meio da **Fagulha**. A luz dele vai embora com a lanterna, e as pernas começam a virar hachura.
4. A Rodeira pega a lanterna no ar (**Eixo**, congelamento de 4 quadros) e a crava no óleo. A Fagulha toca o óleo no mesmo quadro (hit-stop de 4 quadros e tremor de câmera por trauma²).
5. Sai a **Labareda**. A luz do fogo cresce de 0 a 4 m em 0,4 s e repinta o chão de gravura para guache. Os Fuligentos atingidos ficam 4 quadros parados com clarão branco, achatam, voam girando e quicam. Os que estão longe fogem da borda da luz aos pulos. O Apagador recua.
6. A Rodeira gira em volta da lanterna cravada e volta ao idle com respiração. O Pavieiro segura a pose de susto e depois volta a respirar. Capas, mangas, trança e chama balançam com a rajada de vento da chuva.

## Entregas

Todas em `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/provas-fantasia3/caravana/entrega/`.

| Arquivo | O que é | Renderer | Tempo |
|---|---|---|---|
| `beauty.png` | 1920×1080, quadro 112 do clipe, câmera real do jogo. Névoa volumétrica, névoa exponencial de altura, glow, sombras, DOF de perto e de longe, distorção de calor, 3 luzes de fogo com tremor | Forward+ | cerca de 200 s (simula os quadros anteriores por causa das molas) |
| `stress.png` | 1280×720. 4 heróis, 20 inimigos (17 Fuligentos e 3 Apagadores), 3 efeitos (Labareda, Badalada Funda com sal, Pederneira na poça) e 3 telegrafias. Atmosfera barata da prévia web, sem sombra do motor | Compatibility | cerca de 11 s; 205 chamadas de desenho |
| `portoes.png` e `portoes.json` | Portões sobre o `stress.png`: cinza, borrão de 4 px, miniatura de 320×180 e daltonismo | — | 3 s |
| `clip.mp4` e `clip.gif` | 4,65 s (279 quadros a 60 fps), 1280×720, nível PC. MP4 H.264 crf 24 com 2,4 MB; GIF de 512 px a 15 fps com 3,9 MB | Forward+ (Movie Maker, `--fixed-fps 60`) | 400 s de render (1,43 s por quadro) |
| `modelo.png` | Folha de modelo: as 4 classes em frente, 3/4 e perfil; Fuligento e Apagador na luz e na Treva; as 8 poses do Eixo; e um teste de silhueta em preto chapado com o herói a 64 px | Compatibility, ortográfica | cerca de 2 s por faixa |

## O que mudou da v1 para a v2 (pela ordem da crítica)

### 1. A poça de luz agora é luz, não decalque

- **Máscara de luz calculada no shader.** As fontes de pavio (até 8 `vec4` globais) são somadas por log-soma-exp num campo em metros. A borda não é mais um corte: é uma faixa de dissolve de 0,8 m, recortada por um ruído de pincel largo em world-space (0,5 m) e por uma escova seca fina (12 cm). O resultado parece pincel com pouca tinta, não um adesivo.
- **Rampa de valor.** Dentro da luz, o guache cai do núcleo quente e claro (×1,38, âmbar) para a borda fria e escura (×0,42, azulada). Assim a borda da luz tem quase o mesmo valor da gravura e a transição some.
- **Albedo real do chão.** O terreno ganhou um albedo procedural por cima da cor de vértice: manchas de ocre, grama rala e seixos raros. O lodo molhado continua escuro. Na luz, aparece o chão de verdade, não um marrom único.
- **Cada chama acende a máscara.** O núcleo da Labareda e mais dois grupos de chamas são fontes de pavio com tremor no raio. No PC, cada grupo tem a sua `OmniLight3D` com tremor; a principal projeta sombra.
- O guache foi dessaturado em 18% (parâmetro `desat`).

### 2. A hachura deixou de ser disco de vinil

- A gravura agora é um **tonal art map**: a primeira camada de linha só entra a partir de tom 0,12, e a segunda (cruzada, meia densidade) só nos tons altos. O tom vem da luminância do albedo e da curvatura (bordas ganham linha).
- **Direção.** No chão plano, as linhas são traços deitados com ondulação leve. Só os barrancos íngremes seguem o fluxo da superfície. Os anéis e as curvas de nível sumiram.
- **Densidade e contraste.** A frequência do terreno caiu de 9 para 4,5 linhas por metro. O fundo da gravura tem valor de cerca de 0,25, e a linha, cerca de 0,45 (antes era 0,57 sobre 0,22).
- **Distância.** As linhas somem entre 20 e 48 m e viram tom de névoa. Assim, os personagens e os olhos dos inimigos são o ponto de maior contraste.

### 3. Personagens maiores na tela

- Os personagens estão 1,3× maiores, e a câmera passou de 16 m para 16,5 m. Na miniatura de 320×180 os heróis medem de 23 a 26 px (v1: 18,5 a 21 px), o que dá de 139 a 157 px em 1080p, contando chapéu, sino e saco.
- Há luz de borda (fresnel) na cor do jogador e contorno de 4 px nos heróis (antes 3 px).
- A Rodeira, vista de cima, mostrava só o fundo da panela. Agora a panela é de estanho claro com um brasão pintado: uma roda de seis raios em Carmim. É o que a câmera alta lê.

### 4. Indicadores de jogador mais limpos

- O anel de jogador agora é um só anel fino na cor do jogador, com 45% de alfa e um símbolo pequeno na frente. O disco de preenchimento e o anel duplo saíram.
- A telegrafia inimiga não tem mais disco: é um anel fino que se fecha, com o limite externo tracejado em 20% de alfa e setas pequenas.

### 5. Fogo de verdade

- Cada chama é um billboard alinhado ao eixo Y, inclinado para a câmera alta. O ruído corre para cima por vértice (lambida) e por pixel. Há erosão de alfa pela altura e pela vida, e um gradiente emissivo branco, amarelo, laranja e vermelho do núcleo à ponta, quantizado em 5 faixas macias para combinar com o guache.
- A Labareda tem um núcleo de 5 chamas altas (1,7 a 2,5 m) e 11 menores nas manchas de óleo. Todas deitam juntas com o vento. Cada chama tem largura, curva e respiração próprias.
- No PC, há distorção de calor (textura de tela) atrás do fogo e glow.
- As manchas de óleo queimadas carbonizam, e as rachaduras viram brasa.

### 6. Fumaça macia

- A fumaça usa partículas com dados por instância (vida e semente). A forma vem de ruído, com erosão de alfa ao longo da vida e opacidade máxima de 0,6.
- A cor é fuligem fria; a barriga da nuvem esquenta só onde a chama ilumina.
- Ela sai da ponta das chamas e é levada pelo vento da chuva.
- Ela some perto dos heróis (até 2,4 m de altura) e perto da câmera. No PC há depth fade (soft particles).

### 7. Mundo aberto em vez de tigela

- **Névoa exponencial de altura** em tom malva de crepúsculo: os vales e o fundo dobrado afundam na névoa, e o perto fica limpo.
- **Quatro camadas de profundidade.** No primeiro plano há touceiras altas nos cantos de baixo, desfocadas no PC por DOF de perto. No plano médio há um arco de pedra quebrado com estandarte rasgado e um braseiro aceso (à esquerda) e uma carroça tombada com uma lanterna caída acesa (à direita). No fundo ficam a Wain iluminada, a capela com a janela acesa, o farol, a torre e o gigante.
- **Caminhos que saem da tela.** Agora são quatro: as duas passarelas antigas, um ramal com postes de lanterna até a capela (fundo à direita) e uma passarela que some pela borda de baixo (o caminho de onde o grupo veio). Há também uma trilha de pedras de pisar até o farol.
- **Pontos de luz ao longe.** O braseiro e a lanterna caída também são fontes de pavio: abrem guache longe do combate e puxam o olhar.
- A clareira perdeu a simetria: a ruína e a carroça invadem as bordas, e os restos ficam espalhados.

### 8. Tom mais dark fantasy

- **Fuligentos.** Os olhos brancos redondos saíram. Agora são buracos de pavio queimado com uma brasa em fenda, que fecha e esquenta na telegrafia. A boca é uma rachadura em brasa, há um pavio carbonizado na cabeça com a ponta acesa, e cera escorre pelo corpo. A leitura é a de uma vela que a Treva apagou.
- **Heróis.** O rosto agora é de cera talhada: facetado, sem suavização e sem bochecha rosada, com olhos de botão de fuligem e um vinco talhado sob cada olho. A pele ficou mais cera que carne.
- **Restos no chão.** Há poças de cera com tocos de vela, cascas de Fuligentos apagados e estandartes rasgados.

### 9. Silhuetas de classe

- **Gatuno.** As duas orelhas redondas saíram. Agora ele tem um capuz justo e facetado com uma única ponta angular jogada para trás e para um lado, e uma corcunda de saque num ombro só, com o castiçal espetado para cima.
- **Sineira.** O cabo ficou mais longo e mais grosso, e ganhou um gancho de ferro na ponta. O sino, menor, fica pendurado atrás do ombro, longe do capuz, e não atravessa mais.
- A folha de modelo ganhou uma faixa com as silhuetas em preto chapado, com o herói a 64 px. As seis se distinguem: panela com roda, vela, capuz pontudo com sino, capuz de ponta com corcunda, Fuligento espinhento e Apagador de cone.

### 10. Animação em jogo

- O hit-stop da Labareda caiu de 8 para 4 quadros, e a pegada continua com 4.
- **Reação de dano.** O Fuligento atingido fica 4 quadros parado com clarão branco, achata e estica com mola amortecida (exp × cos), voa 2,8 m girando e quica no chão.
- **Fuga da luz.** Os Fuligentos que estão longe recuam aos pulos para fora da borda da luz quando a frente chega perto deles. É a mecânica que o visual promete.
- **Idle.** A Rodeira e o Pavieiro voltam à pose de espera com respiração depois das ações. Uma rajada de vento entra nas molas e faz capas, mangas, trança e chama balançarem.

### 11. Brasas e vaga-lumes

- As gotas de tinta laranja espalhadas, que pareciam confete, saíram. Os respingos agora só existem na borda da frente enquanto ela corre e duram 0,3 s.
- As brasas nascem nas chamas, no contato com o chão e no corpo. Sobem com um rotacional falso, têm tamanho e brilho variados e cintilam. Vivem de 1 a 2 s e apagam ao sair da luz.
- Na Treva há só 9 vaga-lumes frios, verde-azulados, que piscam devagar.

## Portões no `stress.png` (Compatibility)

Os critérios são os mesmos da v1. No cinza, os heróis precisam de ΔL mínimo de 0,12, e a mediana dos inimigos de pelo menos 0,10. No borrão de 4 px, a mediana dos heróis precisa ser de pelo menos 0,12, e a dos inimigos de pelo menos 0,08.

| Portão | v1 | v2 | Passa? |
|---|---|---|---|
| Cinza, heróis (mín. / mediana) | 0,128 / 0,305 | **0,148** / 0,183 | sim |
| Cinza, inimigos (mediana; abaixo de 0,10) | 0,144; 3 de 20 | **0,135**; 3 de 20 | sim |
| Borrão de 4 px, heróis (mín. / mediana) | 0,092 / 0,179 | **0,116** / 0,125 | sim |
| Borrão de 4 px, inimigos (mediana; abaixo de 0,10) | 0,102; 9 de 20 | **0,089**; 15 de 20 | sim, por pouco |
| Miniatura 320×180: altura dos heróis | 18,5 a 20,8 px | **23,2 a 26,2 px** (inimigo menor: 13,8 px) | sim |
| Jogadores, ΔE mínimo (normal / deuteranopia / protanopia) | 0,174 / 0,071 / 0,134 | igual | sim; o símbolo de forma segura o resto |

**O que reprovou no caminho e o que eu corrigi:**

1. **A Rodeira caiu para ΔL de 0,076 e depois para 0,014.** A rampa de luz escureceu os heróis, e a panela de ferro tinha o mesmo valor do lodo claro. A correção teve duas partes. Os heróis agora ficam sempre na faixa clara da rampa, como se carregassem luz própria pela lanterna do cinto. A panela passou a ser de estanho claro. A sombra de contato dos heróis também ficou maior.
2. **Os inimigos perderam contraste no borrão.** O fundo da gravura ficou mais claro (pedido da crítica), e o sulco claro no contorno dos bichos se misturava com o chão. O sulco caiu de 50% para 22%, e a mediana subiu de 0,080 para 0,089. Continua abaixo da v1 (0,102): é o custo de uma gravura com menos contraste.
3. **As chamadas de desenho subiram de 164 para 205** por causa da ruína, da carroça, da capela, dos postes, dos restos e das pedras de pisar. Na prévia web, isso pede LOD e juntar as peças do plano médio num MultiMesh só.

## Armadilha nova (importante para o projeto)

**No Compatibility do Godot 4.7.2, material `unshaded` não converte linear para sRGB na saída**, e as cores `source_color` chegam sem linearizar. Um `ALBEDO = vec3(0.05)` sai como 13/255 no Compatibility e como 63/255 no Forward+. Os materiais com luz (`light()`) convertem normalmente.

Isso explica dois sintomas da v1: as poças, que pareciam buracos pretos na prévia web, e a gravura "leitosa" no PC. A correção está em `comum.gdshaderinc`, com `CURRENT_RENDERER`:

- `entrada()` lineariza as cores `source_color` só no Compatibility;
- `saida()` converte o `ALBEDO` final de todo material unshaded só no Compatibility.

Com isso, os dois renderers dão o mesmo valor. A regra para o projeto é usar sempre `saida()` e `entrada()` em shader unshaded.

Outras armadilhas encontradas na v2:

- **`E` é constante interna dos shaders do Godot.** Uma variável local chamada `E` dá "Redefinition of 'E'".
- **A mola de continuidade descartava ossos de personagem escalado.** O teste "osso achatado" comparava o determinante com 1. Com o personagem em 1,3×, o determinante é 2,197, e todas as molas paravam. A correção foi comparar com o determinante do esqueleto.
- **Billboard de chama vista de cima.** Inclinar o quad PARA a câmera piora o encurtamento. O certo é inclinar para longe da câmera (`up = Y − dir_câmera × 0,5`).

As armadilhas da v1 continuam valendo: bug de sombra de nome de uniform no Forward+, Movie Maker no tamanho da viewport, `custom_aabb` nos MultiMesh por causa da curvatura e sombra direcional que triplica as chamadas no Compatibility.

## Tempos

- **Modelos.** 7 personagens e adereços em cerca de 1,5 s; o cenário inteiro em cerca de 5 s (o terreno tem o dobro da resolução perto do combate).
- **Quadro bonito.** Forward+ por software (lavapipe) a 1920×1080: cerca de 200 s, com 112 quadros simulados.
- **Estresse.** Compatibility: cerca de 11 s.
- **Clipe.** Forward+ a 1280×720: 400 s para 280 quadros.

## O que ficou bom

- A luz agora lê como luz: núcleo quente, queda fria e borda de pincel seco. O chão mostra ocre, grama e seixos dentro dela.
- A Labareda é uma fogueira só, que ruge e lambe com o vento, com glow, calor e brasas, e acende o chão em volta.
- A gravura recuou para o fundo. Os personagens, as brasas dos olhos e o fogo mandam na leitura.
- **O mundo continua para fora do quadro.** Há caminhos nas quatro direções, ruína e carroça com luz no plano médio, a Wain iluminada e a capela no fundo, e touceiras no primeiro plano.
- Os Fuligentos agora são velas apagadas pela Treva, não bolinhas de fuligem fofas.
- **Silhuetas.** No teste a 64 px, as seis se distinguem.

## O que é fraco (honesto)

- **"Além de triple A" não foi alcançado.** É um 3D estilizado bem amarrado, de indie bom. Os corpos são lofts facetados por código, sem escultura, e as mãos são luvas de bloco.
- **A borda da luz melhorou, mas ainda se lê como uma mancha grande** quando a Labareda está no máximo (raio de 4 m mais a lanterna). Em jogo, o raio da Labareda deveria cair com o tempo.
- **A câmera alta esconde os rostos.** Os rostos de cera talhada só aparecem na folha de modelo. Em jogo, quem identifica o herói é a silhueta, a cor e o brasão do topo.
- **Fogo no estresse.** As 14 chamas sobre 4 manchas de óleo ainda formam um canteiro regular. No clipe, com núcleo e satélites, a leitura é melhor.
- **A fumaça** é macia, mas ainda tem cara de nuvem de desenho, sem volume de verdade.
- **Inimigos no borrão.** A mediana é de 0,089, abaixo da v1 (0,102), por causa do fundo de gravura mais claro.
- **Fuga da luz.** Ela existe, mas na câmera de combate os pulos de fuga são curtos e pouco legíveis.
- **Desempenho real não foi medido no iPhone.** São 205 chamadas de desenho por software e 834 mil primitivas. A perda de contexto WebGL também não foi testada.
- **Não foram feitos:** Mariposa (o caído), Feixe da Torre-Lanterna, Rolar a Roda, som e a silhueta dos heróis atrás de obstáculos.

## Código

Pasta: `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/provas-fantasia3/caravana/`.

**Ferramentas** (`tools/`):

- `paleta.py`: paleta mestra (pele de cera e estanho novos);
- `malha.py`: o Builder de peças com casca de contorno;
- `personagens.py`: os 4 heróis, os 2 inimigos e a lanterna;
- `poses.py` e `animar.py`: poses-chave em chaves CONSTANT;
- `exportar.py`: GLB a 60 fps;
- `cenario.py`: terreno, vegetação, pedras, passarelas, ruína, carroça, capela, postes, restos, touceiras, Wain, Graxo, marcos e `mundo.json`;
- `portoes.py`: portões;
- `folha_modelo.py` (agora com o teste de silhueta) e `folha_clip.py`: folhas;
- `run.sh` e `codificar.sh` (MP4 crf 24, GIF até 4 MB): execução e codificação.

**Motor** (`proj/`):

- `main.gd`: cenas `folha`, `poses`, `cena` e `estresse`;
- `mundo.gd`: o brejo e o plano médio;
- `vfx.gd`: partículas com dados por instância, fogo em billboard, calor, marcas e névoa;
- `boneco.gd` (escala 1,3, cor do jogador) e `mola.gd` (vento nas molas);
- `shaders/`:
  - `comum.gdshaderinc`: máscara de luz, curvatura, pincel, tonal art map, `saida()` e `entrada()`;
  - `pintado.gdshader`: o shader-base, com chão procedural, rampa e dessaturação;
  - `fogo` e `calor`, novos;
  - `particula`, reescrito;
  - `contorno`, `olho` (botão de fuligem e brasa em fenda), `emis`, `agua`, `ceu`, `nevoa`, `chao_fx`, `muralha` e `feixe`.

**Comandos** (a partir da pasta da prova):

- **Modelos:** `cd tools && python3 exportar.py ../proj && python3 cenario.py ../proj`.
- **Quadro bonito:** `TMO=1500 tools/run.sh fplus 1920x1080 entrega/beauty.png cena=cena frames=112 pc=1`.
- **Estresse:** `tools/run.sh compat 1280x720 entrega/stress.png cena=estresse frames=40 sombra=0`. Para a máscara, acrescente `mascara=1`. Depois rode `python3 tools/portoes.py entrega/stress.png <máscara> entrega/portoes 4`.
- **Clipe:** `EXTRA="--write-movie <pasta absoluta>/q.png" tools/run.sh fplus 1280x720 out2/x.png cena=cena frames=280 pc=1` e depois `tools/codificar.sh <pasta> entrega/clip`.
- **Folha de modelo:**
  - Faixas 1 e 2: `cena=folha who=rodeira,pavieiro anim=espera size=2.75 dx=1.43 cy=0.72` (resolução 2400x760).
  - Inimigos: `size=3.0 dx=1.5 cy=1.15`; para a Treva, acrescente `pint=0 grav=1 bg=#2b3a52`.
  - Poses: `cena=poses who=rodeira anim=folha q=0,1,2,3,4,5,6,7 dx=1.15 size=2.4 cy=0.62` (resolução 2400x600).
  - Depois rode `python3 tools/folha_modelo.py out2/folha entrega/modelo.png`.

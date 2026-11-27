# Direção de arte: parecer premium sem "cara de IA slop" com assets 100% gerados por código

Pesquisa feita em 26/11/2026. Etapa só de pesquisa: nada do jogo foi construído.

**Como ler a confiança das informações**

- **[doc]**: lido direto no repositório oficial `godotengine/godot-docs` (branches 4.5, 4.6, 4.7 e master).
- **[teste]**: medido aqui, no container (Godot 4.5.1 sob Xvfb com llvmpipe, Blender 5.3 como módulo Python). Arquivos em `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-direcao-de-arte/` (pasta temporária, pode ser apagada).
- **[fonte]**: veio de entrevista, palestra ou matéria, com link. Atenção: a ferramenta de leitura de páginas só alcança o GitHub neste ambiente, então quase tudo fora do GitHub foi lido pelo resumo da busca, não pelo texto integral.
- **[não verificado]**: não consegui confirmar; tratar como hipótese.
- **[proposta]**: recomendação minha, derivada das fontes, não uma regra publicada.

---

## 1. Resumo e recomendação

1. **O que derruba um jogo para "slop" é a falta de decisão, e não a ferramenta.** Os sinais que as pessoas apontam são incoerência (estilos misturados, luz sem direção), acabamento genérico (brilho plástico, detalhe demais sem hierarquia, padrões do motor) e arte de loja que não bate com o jogo. A contramedida é um conjunto de restrições explícitas e verificáveis por script (seção 5).
2. **Todos os jogos pequenos de aparência premium que pesquisei usam uma restrição radical como estilo**: Tunic não tem texturas, Sable não tem iluminação convencional, Obra Dinn tem 1 bit, Dead Cells renderiza 3D a cerca de 50 px de altura, Guilty Gear Xrd proíbe interpolação de animação. A nossa restrição já existe (tudo é gerado por script); falta escolher o material fictício que a justifica.
3. **Ranking das direções** (seção 6): 1º xilogravura de cordel em papel recortado (4,60), 2º teatro de mamulengo (4,40), 3º papercraft/origami/pop-up (4,20), 4º azulejo (4,15), 5º massinha/barro em stop motion (3,80), 6º folclore noturno de silhueta e brilho (3,45), 7º HD-2D com sprites pré-renderizados (3,35), 8º brinquedo/diorama de plástico (3,15).
4. **Recomendação: fundir as três primeiras em uma só linguagem, "teatro de cordel".** Cenário de papel impresso em xilogravura (papel cru, tinta preta, uma ou duas cores chapadas por região), personagens como bonecos de madeira pintada com roupa de chita (cor saturada), efeitos como papel de seda, fita, confete e fumaça de tinta. A separação personagem/cenário por material e saturação resolve a legibilidade por construção, e as três tradições são formas simples e facetadas, que é exatamente o que script modela bem.
5. **Projetar primeiro para o renderer Compatibility (Web) e tratar o Forward+ como camada de luxo.** Os testes mostraram três armadilhas reais ao portar um look entre os dois renderers (seção 2.2), e o usuário joga pelo navegador do celular.
6. **Não encontrei nenhum jogo com estética de mamulengo nem jogo brasileiro com estética de azulejo.** Xilogravura de cordel já foi usada, inclusive em um roguelite co-op de 2026 (Cordels & Spells), então a novidade teria de vir da forma (3D de papel e boneco, não 2D).

---

## 2. Limites técnicos que moldam a direção de arte

### 2.1 Compatibility (Web) contra Forward+ [doc]

Fonte: `tutorials/rendering/renderers.rst` do `godot-docs`, comparado entre branches ([4.5](https://github.com/godotengine/godot-docs/blob/4.5/tutorials/rendering/renderers.rst), [4.6](https://github.com/godotengine/godot-docs/blob/4.6/tutorials/rendering/renderers.rst), [4.7](https://github.com/godotengine/godot-docs/blob/4.7/tutorials/rendering/renderers.rst), [master](https://github.com/godotengine/godot-docs/blob/master/tutorials/rendering/renderers.rst)).

| Recurso | Compatibility 4.5 | Mudou depois? | Forward+ | Impacto na arte |
|---|---|---|---|---|
| Glow | Sim, implementação própria, sem Levels/Blend Mode/Mix/Map | Não | Sim | Brilho de magia funciona na Web, com menos controle |
| Névoa por profundidade e altura | Sim | Não | Sim | Atmosfera barata disponível |
| Névoa volumétrica, SDFGI, VoxelGI, SSR, SSIL | Não | Não | Sim | Raios de luz e luz rebatida só no desktop |
| SSAO | Não | **Sim no 4.6** | Sim | No 4.5 a oclusão tem de ser pintada no vértice ou assada |
| Profundidade de campo (DOF) | Não | Não (nem no master) | Sim | O tilt-shift do HD-2D exige shader próprio na Web |
| Decals | Não | **Só no master (8 por superfície)** | Sim | Sombra-bolha e marcador de área viram malha plana |
| Textura de tela e de profundidade em shader | Sim | Não | Sim | Contorno e desfoque por pós-processo são possíveis |
| Buffer de normal/rugosidade | Não | Não | Sim | Contorno por normal não existe na Web: usar profundidade ou casco invertido |
| CompositorEffects | Não | Não | Sim | Pós-processo na Web só por quad de tela cheia |
| LightmapGI | Renderiza; assar exige RenderingDevice | Não | Sim | Dá para assar no desktop e usar na Web [não verificado se assa com lavapipe] |
| Luzes Omni/Spot | 8 por malha | Não | 512 por cluster | Cada feitiço com luz própria estoura o limite na Web |
| Luz com sombra | "multi-pass, blending menos preciso" (texto do 4.7) | — | Preciso | Ver achado 1 abaixo |
| Trilhas de partícula | Não (linha aparece na tabela do 4.6) | Não | Sim | Rastro de espada e de projétil vira malha de fita |
| Subsurface scattering | Não | Não | Sim | Massinha e pele translúcida precisam de truque |
| Precisão de cor | RGBA8, baixa faixa dinâmica, sem debanding (tabela do 4.7) | — | RGBA16F | Degradê suave faz faixas na Web; cor chapada e retícula não |
| MSAA 3D | Sim | Não | Sim | Bordas limpas possíveis nos dois |
| TAA, FXAA, FSR2 | Não | Não | Sim | — |

Conclusão: estilos que dependem de **cor chapada, traço, textura impressa e luz simples** saem iguais nos dois renderers. Estilos que dependem de **reflexo, luz rebatida, translucidez e desfoque** perdem a assinatura na Web.

### 2.2 Achados dos testes práticos [teste]

Cena mínima feita por script (4 bonecos de primitivas, caixas, sol com sombra, luz omni, névoa, glow, um `Sprite3D` billboard e um quad de pós-processo), capturada em 1280×720 nos dois renderers. Projeto em `.../pesquisa-direcao-de-arte/godot-teste/`.

| # | Achado | Números medidos | Consequência |
|---|---|---|---|
| 1 | **Luz com sombra estoura a imagem no Compatibility quando há luz ambiente, névoa ou outras luzes.** | Mesma cena: luminância média 0,959 e 82,5% dos pixels acima de 0,98 no Compatibility, contra 0,832 e 0,1% no Forward+. Com a sombra do sol desligada: 0,803 nos dois, pixels idênticos. Só o sol com sombra, sem ambiente: 0,688 nos dois | Calibrar a luz no Compatibility primeiro, ou usar sombra falsa (bolha/malha) e luz sem sombra na Web. Bate com a frase do doc 4.7 sobre "blending menos preciso" |
| 2 | **Um quad de pós-processo em shader `spatial` reaplica o tonemapper no Compatibility.** | Repassar a tela sem alterar: exato no Forward+. No Compatibility com Filmic, o piso foi de (0,92 0,83 0,67) para (0,96 0,91 0,80). Com tonemapper Linear: diferença média 0,0012 entre renderers | Na Web, usar tonemapper Linear e fazer a curva de tom dentro do próprio shader de pós-processo |
| 3 | **A textura de tela vem em espaços de cor diferentes.** | Limiar `luminância > 0,5`: 93,5% de pixels brancos no Compatibility (previsto para valores sRGB: 93,5%) e 24,3% no Forward+ (previsto para valores lineares: 24,6%) | Todo limiar, posterização ou hachura por tela precisa de ramo `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY`. O mesmo shader de xilogravura cobriu 4% da tela de tinta em um e 31% no outro |
| 4 | **Sampler de profundidade dentro de função global não compila no Compatibility** (`depth_buffer undeclared`). | — | Passar o `sampler2D` como parâmetro da função, ou amostrar dentro de `fragment()` |
| 5 | **Contorno por profundidade e tilt-shift caseiro funcionam na Web.** | Contorno pelo laplaciano da profundidade (5 amostras) e desfoque em espiral de 24 amostras guiado pela profundidade. Diferença média do tilt-shift entre renderers: 0,0046 | O visual HD-2D de foco seletivo é viável na Web com shader próprio. O `Sprite3D` com alpha prepass projeta sombra e recebe contorno |
| 6 | Custo no container | 50 a 110 ms por quadro a 720p nos dois renderers (cena trivial, MSAA 2×) | Serve para captura e revisão, não para sentir o jogo |
| 7 | Blender sem GPU | Cycles 16 amostras, 512×512: 4,9 s. EEVEE também renderiza sem display: 20 a 29 s por quadro. Freestyle (traço) funciona no Cycles em 1,6 s, mas só depois de atribuir um `linestyle` ao lineset (cena vazia vem com `None` e dá "strokes set empty") | Traço de tinta gerado offline é viável. "Shader to RGB" é só do EEVEE, então toon offline em volume é melhor compor a partir de passes do Cycles |

**Regra prática que sai daqui:** estilizar no **material** (função `light()` própria, casco invertido para contorno, cor de vértice) em vez de estilizar na **tela**. O material dá o mesmo resultado nos dois renderers; a tela não. Reservar o pós-processo para grão de papel, vinheta e foco seletivo.

---

## 3. (a) Como o HD-2D e seus parentes funcionam

### 3.1 A receita do HD-2D

| Componente | O que é | Fonte |
|---|---|---|
| Sprites em billboard dentro de cenário 3D real | Personagens em pixel art que encaram a câmera, sobre geometria 3D | [Wikipedia HD-2D](https://en.wikipedia.org/wiki/HD-2D) |
| Textura crua, luz em alta definição | Texturas ficam em baixa resolução e sem filtro; luz, desfoque e bloom rodam em resolução cheia | [issue de reconstrução em Godot](https://github.com/Phaazoid/Godoiosis/issues/176) [fonte secundária] |
| Foco seletivo (tilt-shift) | Desfoque no topo e na base do quadro, que dá o ar de maquete | Wikipedia HD-2D |
| Luz pontual junto com cada efeito | A equipe do Octopath achou os efeitos de batalha fracos e passou a acender uma luz pontual junto com o VFX | [Unreal Engine, 2019](https://www.unrealengine.com/spotlights/octopath-traveler-s-hd-2d-art-style-and-story-make-for-a-jrpg-dream-come-true) |
| Sombra do sprite | O sprite projeta sombra de verdade, o que o prende ao chão | [guia Zerocade](https://www.zerocade.in/guides/what-is-hd-2d) [fonte secundária]; viabilidade confirmada no teste 5 |
| Bloom restrito, névoa, gradação de cor, vinheta | Bloom só em tocha, fogo e magia | issue do Godoiosis [fonte secundária] |

Fatos de produção que importam para nós:

- **Octopath Traveler** (Acquire, Unreal Engine 4): no pico tinha só 6 programadores. O difícil foi fazer o sprite, "uma folha de papel", parecer natural no fundo 3D ([Unreal Engine](https://www.unrealengine.com/spotlights/octopath-traveler-s-hd-2d-art-style-and-story-make-for-a-jrpg-dream-come-true)).
- **Octopath Traveler II**: luz dinâmica de dia e noite, câmera que gira até quase 90° em efeitos de batalha e 180° em eventos, personagens com cabeça proporcionalmente menor para caber mais ação. Meta declarada: toda captura de tela ser "perfeita" ([Unreal Engine](https://www.unrealengine.com/en-us/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style), [Nintendo Life](https://www.nintendolife.com/news/2022/10/octopath-traveler-ii-devs-aimed-to-make-its-hd-2d-visuals-picture-perfect)).
- **Triangle Strategy** (Artdink): a Square Enix pediu demos a vários estúdios e só a Artdink acertou o HD-2D "de verdade"; os outros fizeram imagem fotorrealista e reduziram. O produtor diz que o estilo "custa mais do que parece" ([Nintendo Life](https://www.nintendolife.com/news/2022/05/triangle-strategy-producers-talk-hd-2d-and-why-other-devs-havent-used-it), [Nintendo Everything](https://nintendoeverything.com/triangle-strategy-producers-say-hd-2d-costs-more-than-youd-think-internal-teams-shared-knowledge-to-help-with-its-implementation/)). Lição: HD-2D não é 3D realista com filtro de pixel.
- **Dragon Quest III HD-2D** e **Live A Live**: o produtor de DQ3 veio do Octopath e reaproveitou o aprendizado; a Square Enix diz que o sabor muda a cada título ([PlayStation Blog](https://blog.playstation.com/2024/11/08/dragon-quest-iii-hd-2d-remake-interview-how-the-classic-rpg-was-revamped-for-its-ps5-debut/)). Detalhes de pipeline desses dois: [não verificado].
- "HD-2D" é marca registrada da Square Enix; as técnicas não são patenteadas [fonte secundária, não verificado]. Não usar o termo no nome ou no marketing.

### 3.2 Parentes do HD-2D

| Jogo | Truque central | Lição para um pipeline por script | Fonte |
|---|---|---|---|
| **Sea of Stars** (Sabotage, Unity) | Pipeline de render próprio: sprites com normal map, escrita de profundidade por pixel, recebem sombra; luz volumétrica e indireta em espaço de tela. Um programador cuidou só disso desde 2018, e todo asset é produzido para atender à luz | Luz dinâmica sobre pixel art exige normal map por sprite. Renderizando o sprite a partir de 3D, o normal map sai de graça | [Kickstarter](https://www.kickstarter.com/projects/sabotagestudio/sea-of-stars), [MobileSyrup](https://mobilesyrup.com/2023/09/11/sea-of-stars-level-design-sabotage-studio-thierry-boulanger-interview/) |
| **Eastward** (Pixpil) | Motor próprio. Luz 3D sobre pixel art; a técnica exata (normal map, deferred) é discutida em fóruns sem confirmação | Não dá para copiar o que não está documentado | [Game Developer](https://www.gamedeveloper.com/art/eastward-s-creators-share-insights-on-making-pixel-art-adventures) [técnica não verificada] |
| **Dead Cells** (Motion Twin) | Modelo 3D simples no 3ds Max, exportado em FBX, renderizado por ferramenta caseira em tamanho minúsculo e sem antialiasing, salvando PNG e normal map por quadro; toon shader no jogo. Personagem com cerca de 50 px de altura. Um artista só por um ano. Mudar o tempo de uma animação leva minutos | **É o pipeline mais próximo do nosso.** A baixa resolução esconde modelo fraco. Problema declarado: pixels piscando entre quadros, que o artista limpava à mão. Script não limpa à mão, então é preciso resolver no render (travar subpixel, quantizar paleta, filtro temporal) | [Game Anim](https://www.gameanim.com/2018/01/31/dead-cells-3d-pipeline-2d-animation/), [Habr](https://habr.com/en/articles/416589/), [80.lv](https://80.lv/articles/case-study-dead-cells-character-art-pipeline) |
| **Guilty Gear Xrd** (Arc System Works, GDC 2015) | 3D que parece 2D: normais de vértice editadas à mão para a sombra cair onde o desenhista quer, contorno por casco invertido, linhas internas por textura, cor de vértice como controle, e **animação limitada: só quadros-chave, sem interpolação**. Frase do palestrante: "se algo parece 3D, ache um jeito de evitar" | Normal editada é procedural por natureza: dá para transferir normais de uma esfera ou cápsula para o rosto por script. Animação sem interpolação combina com boneco e stop motion | [GDC Vault](https://gdcvault.com/play/1022031/GuiltyGearXrd-s-Art-Style-The), [PDF da palestra](https://www.ggxrd.com/Motomura_Junya_GuiltyGearXrd.pdf), [Impress Watch](https://game.watch.impress.co.jp/docs/news/20150307_691725.html) |
| **Hades** (Supergiant) | Arte 2D no Photoshop; personagens modelados e animados no Maya e pós-processados no After Effects. Quase todos os NPCs nascem de 2 modelos-base | Poucos modelos-base com muita variação por cima é o que um gerador faz bem | [MCV](https://mcvuk.com/business-news/behind-the-art-of-hades-we-value-artistic-integrity-and-excellence-in-artistic-craft-at-supergiant-however-were-first-and-foremost-a-game-design-lead-team/), [GoNintendo](https://gonintendo.com/stories/371221-supergiant-games-shows-off-the-3d-modeling-rigging-process-for) |
| **Vanillaware** (Dragon's Crown, 13 Sentinels) | Ilustração pintada à mão animada por partes | Depende de pintura humana de altíssimo nível; não é reproduzível por script | Pipeline [não verificado] |
| **Cult of the Lamb** (Massive Monster) | Personagens 2D desenhados à mão num mundo 3D; os autores citam Don't Starve como precursor e dizem que a luz é grande parte do visual | Boneco 2D recortado em mundo 3D é barato de animar e tem cara de produto | [PC Gamer](https://pcgamer.com/games/action/the-making-of-cult-of-the-lamb-a-lot-of-the-design-was-trying-to-encourage-the-player-to-be-evil), [Unity](https://unity.com/blog/games/recipe-behind-smash-hit-cult-of-the-lamb) |

### 3.3 O que a receita vira no Godot

| Peça | Forward+ | Compatibility (Web) |
|---|---|---|
| Sprite | `Sprite3D`, billboard Y fixo, filtro nearest, alpha prepass, `shaded` | Igual (testado) |
| Sombra do sprite | Sombra real ou Decal | Sombra real com a ressalva do achado 1, ou disco de malha |
| Foco seletivo | `CameraAttributesPractical` | Shader próprio de 24 amostras (testado) |
| Raios de luz | Névoa volumétrica | Cartões de gradiente aditivos |
| Luz junto do feitiço | OmniLight por efeito | Máximo de 8 por malha: priorizar os 2 ou 3 mais próximos |
| Luz rebatida | SDFGI | Luz ambiente colorida e cor de vértice |

Conta de resolução **[proposta]**: com 14 m de mundo na altura da tela, 720p dá 51 px por metro, 1080p dá 77 e 4K dá 154. Um personagem de 1,8 m ocupa 92 px em 720p. Um sprite de 64 px de altura ficaria com 1,44 px de tela por texel, razão não inteira, que causa cintilação. Ou a câmera é travada para razão inteira, ou se assume textura filtrada em vez de pixel art estrito.

---

## 4. (b) Looks 3D premium de equipe pequena ou com truque claro

| Jogo | Equipe e motor | Truque central | Serve para modelo procedural? | Fonte |
|---|---|---|---|---|
| **Tunic** | Praticamente um autor; Unity, Blender, ProBuilder | "Sem texturas, extremamente low poly, cubista", por limitação assumida do autor. Texturas rolantes para iluminar elementos | Sim, é o caso mais próximo: geometria mínima e cor por material | [Unity](https://blog.unity.com/games/smoke-mirrors-and-scrolling-textures-behind-the-scenes-of-tunic), [Game Developer](https://www.gamedeveloper.com/road-to-igf-2023/how-tunic-weaves-wondrous-unknowable-worlds-inspired-by-inscrutable-nes-manuals) |
| **Death's Door** | 2 pessoas no núcleo; arte terceirizada | Personagens em toon sutil contra cenário de luz natural; o contraste entre os dois é o estilo. Câmera, luz e leve desfoque dão sensação de diorama | Sim: separar personagem e cenário por modelo de luz | [MCV](https://mcvuk.com/?p=217809), [Unity](https://blog.unity.com/games/crafting-intricate-environments-deaths-door) |
| **Link's Awakening (2019)** | Nintendo | Mundo de diorama em que Link seria um boneco de uns 10 cm; tilt-shift; tudo com brilho de plástico | Formas sim; o brilho depende de reflexo, fraco na Web | [Zelda Dungeon](https://www.zeldadungeon.net/links-awakening-graphics-director-sheds-light-on-the-remakes-diorama-inspired-visuals/) |
| **Astro Bot** | Team Asobi, motor próprio | Materiais muito táteis e física de partículas | Depende de motor e materiais de primeira linha | [PlayStation Blog](https://blog.playstation.com/2019/01/24/astro-bot-rescue-mission-inside-the-art-and-animation-of-japan-studios-ps-vr-hit/) [detalhes de material não verificados] |
| **Hi-Fi Rush** | Tango, Unreal 4 modificado | Renderer toon deferred para o mundo inteiro, a 60 fps. Ninguém na equipe tinha feito cel shading antes | Mostra que toon no mundo todo exige renderer sob medida; no Godot, fazer no material | [80.lv](https://80.lv/articles/the-making-of-hi-fi-rush-s-3d-toon-rendering-style), [GDC Vault](https://gdcvault.com/play/1034330/3D-Toon-Rendering-in-Hi), [Unreal Engine](https://www.unrealengine.com/en-US/developer-interviews/hi-fi-rush-was-inspired-by-shaun-of-the-dead-and-futurama) |
| **Sable** | 2 pessoas no núcleo; Unity | Traço no estilo Moebius feito por pós-processo; estilo escolhido por ser rápido de produzir e consistente. Palestra: "imperfeição, limitação" | Sim: contorno resolve a forma, cor chapada dispensa textura | [Game Developer](https://www.gamedeveloper.com/marketing/how-shedworks-refined-the-art-of-sable-in-pursuit-of-readability), [GDC Vault](https://gdcvault.com/play/1027721/The-Art-of-Sable-Imperfection) |
| **Okami** | Clover | Cel shading inspirado em sumi-e; a troca de realismo por traço nasceu para reduzir processamento e virou a mecânica do pincel | A restrição virou identidade e mecânica | [Wikipedia](https://en.wikipedia.org/wiki/%C5%8Ckami) |
| **Tearaway** | Media Molecule, motor próprio | Mundo inteiro de papel que dobra, rasga e amassa; o jogador imprime moldes reais dos personagens. A equipe defende a imperfeição como algo pessoal | Sim: low poly é o próprio origami | [GDC Vault](https://www.gdcvault.com/play/1017845/Building-the-Touchy-Feely-World), [Game Developer](https://gamedeveloper.com/design/how-i-tearaway-i-s-emphasis-on-imperfection-made-the-game-more-personal) |
| **Yoshi's Crafted World / Kirby's Epic Yarn** | Good-Feel | Cenário de caixa de sapato com papel, papelão e lã; tilt-shift e luz de foto | Formas sim; o encanto vem dos materiais reconhecíveis | [Nintendo Everything](https://nintendoeverything.com/yoshis-crafted-world-devs-on-the-art-style-kindergarten-inspiration-flip-side-gimmick-more), [Kotaku](https://kotaku.com/damn-yoshis-crafted-world-looks-gorgeous-1833217032) |
| **Paper Mario: Color Splash / Origami King** | Intelligent Systems | A equipe comprou e estudou vários papéis reais, e usa papel diferente para ambiente duro e macio | Gramatura e fibra por tipo de objeto dão para parametrizar | [Game Informer](https://gameinformer.com/b/features/archive/2016/12/28/afterwords-paper-mario-color-splash), [VGC](https://www.videogameschronicle.com/features/interviews/paper-mario-origami-king/) |
| **Hirogami** (2025) | Bandai Namco Singapura e Malásia | Mundo de origami com animação "picada" de stop motion. Elogiado no visual, criticado em câmera e combate; um crítico notou que os menus não seguem o estilo | Estilo forte não salva jogo fraco, e UI fora do estilo é notada | [COGconnected](https://cogconnected.com/review/hirogami-review/), [Push Square](https://www.pushsquare.com/reviews/ps5/hirogami) |
| **Harold Halibut** | Slow Bros; 11 a 14 anos | Cenários e bonecos físicos escaneados em 3D; captura de movimento "estragada" com menos quadros e articulação dura | O truque de animação (baixar fps, endurecer) é reproduzível | [Creative Bloq](https://www.creativebloq.com/features/making-harold-halibut), [Game Informer](https://www.gameinformer.com/preview/2024/02/07/the-stop-motion-adventure-11-years-in-the-making) |
| **The Midnight Walk** | MoonHood, Unreal 5 | Mais de 700 modelos de argila feitos à mão e escaneados | Não reproduzível; só a leitura de argila | [Yahoo Tech](https://tech.yahoo.com/gaming/articles/stop-motion-game-made-possible-090000893.html) |
| **South of Midnight** | Compulsion | Stop motion só na animação: jogo a 60 fps, personagens "em dois". Cada modelo recebeu quantidade diferente do efeito. O efeito pode ser desligado no jogo | Guia direto para a nossa animação: jogo fluido, pose segurada, opção de desligar | [Creative Bloq](https://www.creativebloq.com/3d/video-game-design/how-the-south-of-midnight-art-team-achieved-its-artisan-animation-style-inspired-by-stop-motion), [SIGGRAPH](https://blog.siggraph.org/2026/04/stop-motion-southern-gothic-and-games-the-visual-language-of-south-of-midnight.html/) |
| **Spider-Verse** | Sony Imageworks | Animação em dois com trocas para um e três; retícula de impressão para sombra e brilho; hachura; "erro de registro" de cores no lugar do desfoque; pontos de Kirby para energia | Tudo isso é shader e regra, não pintura | [Cartoon Brew](https://www.cartoonbrew.com/?p=167321), [AWN](https://www.awn.com/animationworld/creating-stylized-universe-sonys-spider-man-spider-verse), [Foundry](https://www.foundry.com/insights/film-tv/graphic-look-in-comp-spiderman) |
| **Arcane** | Fortiche | Pintura projetada sobre cenário 3D simples; linhas à mão de propósito tremidas | A pintura é humana; aproveitável só a ideia de traço imperfeito | [80.lv](https://80.lv/articles/arcane-artists-show-how-they-combine-traditional-art-3d-for-backgrounds) |
| **Cuphead** | Studio MDHR | Lápis e tinta em papel, cor digital, animação a 24 fps em um com jogo a 60 fps; cerca de 45 a 50 mil quadros | Prova que animação e jogo podem ter taxas diferentes | [Inverse](https://www.inverse.com/article/36647-xbox-one-cuphead-animation), [Guinness](https://www.guinnessworldrecords.de/world-records/508061-most-hand-drawn-frames-of-animation-in-a-videogame) |
| **Return of the Obra Dinn** | 1 autor | 1 bit com dithering; trocou Bayer por ruído azul próprio e mapeou o padrão numa esfera para ele não tremer com a câmera | O defeito de todo filtro de tela (padrão que nada) tem solução conhecida | [PlayStation Blog](https://blog.playstation.com/archive/2019/10/17/lucas-pope-on-return-of-the-obra-dinns-art-style), [PC Gamer](https://www.pcgamer.com/lucas-pope-on-the-challenge-of-creating-obra-dinns-1-bit-aesthetic) |
| **Dordogne** | Un Je Ne Sais Quoi | Aquarelas reais como base das cenas | Não reproduzível | [Game Developer](https://gamedeveloper.com/design/q-a-hand-painting-the-watercolor-world-of-i-dordogne-i-) |
| **Guacamelee** | Drinkbox | "Parte arte popular mexicana, parte jogo de 16 bits": formas simplificadas, angulosas e quadradas, paletas vivas equilibradas | Melhor exemplo de identidade popular transformada em formas vetoriais simples num brawler co-op | [Game Developer](https://gamedeveloper.com/design/road-to-the-igf-em-guacamelee-em-), [GDC Vault](https://gdcvault.com/play/1020419/) |
| **Pentiment** | Obsidian | Xilogravura e iluminura do Renascimento do Norte como estilo principal | Precedente comercial de gravura como estilo de jogo inteiro | [Game Developer](https://gamedeveloper.com/art/deep-dive-the-art-of-pentiment) |
| **Book of Demons** | Thing Trunk | Hack and slash dentro de um livro pop-up. Levaram quase 2 anos para fechar o estilo: "o meio sozinho ainda não é um estilo" | Papel não basta; é preciso regra de forma, cor e traço | [IndieDB](https://www.indiedb.com/members/thingtrunk/blogs) |
| **Ravenswatch** | Passtech | Contorno grosso, cel shading, inspiração em Ivan Bilibin; co-op para 4 em câmera alta | Referência direta de legibilidade no nosso gênero | [Passtech](https://www.passtechgames.com/ravenswatch-news/ravenswatch-artstation-blast/) |
| **Lumino City** | State of Play | Cidade de 3 m de altura em papel, cartão, luzes e motores, filmada | Inspiração de materiais | [MCV](https://mcvuk.com/development-news/crafting-the-lumino-city) |

**Padrões que se repetem**

1. **Uma restrição dura, declarada e mantida** (sem textura, sem interpolação, 1 bit, 50 px).
2. **Um material fictício único para o mundo** (papel, argila, lã, tinta), que explica todas as imperfeições.
3. **Personagem e cenário separados por tratamento**, não só por cor (Death's Door, HD-2D, Cult of the Lamb).
4. **Escala de maquete**: foco seletivo, câmera fixa, objetos reconhecíveis.
5. **Animação com taxa própria, menor que a do jogo** (South of Midnight, Cuphead, Guilty Gear, Harold Halibut).
6. **Imperfeição com causa física** (traço tremido, registro deslocado, dedo na argila), nunca ruído uniforme.
7. **UI no mesmo sistema** (o deslize do Hirogami foi notado em resenha).

---

## 5. (c) O que as pessoas chamam de "AI slop" e como não cair nisso

### 5.1 Contexto

- Em outubro de 2026, 49,9% dos lançamentos do mês na Steam declararam uso de IA; no acumulado de 2026, cerca de 40%. Entre jogos com menos de 10 análises, 47% declaram; entre os com 1.000 análises ou mais, 14% ([Dexerto](https://dexerto.com/gaming/almost-half-of-all-new-steam-games-use-ai-now-3423933), [Outlook Respawn](https://respawn.outlookindia.com/gaming/gaming-news/steam-ai-disclosures-near-50-in-october-2026)). Em 2025 eram 7.818 títulos, 7% do catálogo ([Tom's Hardware](https://www.tomshardware.com/video-games/pc-gaming/1-in-5-steam-games-released-in-2025-use-generative-ai-up-nearly-700-percent-year-on-year-7-818-titles-disclose-genai-asset-usage-7-percent-of-entire-steam-library)).
- O Steam Next Fest de 2026 foi descrito como inundado de demos "vibe coded" ([PC Gamer](https://www.pcgamer.com/gaming-industry/steam-week-in-review-steam-next-fest-has-over-8-000-demos-as-worthless-vibe-coded-slop-levels-up/), [dev.ua](https://dev.ua/en/news/steam-zapolonyv-ai-slop-1792568516)).
- Jogos grandes foram criticados por arte gerada: Clair Obscur foi desclassificado do Indie Game Awards; Black Ops 6 e 7, Anno 117, Battlefield 6 e Crimson Desert tiveram imagens apontadas ([TechSpot](https://www.techspot.com/news/110274-developers-respond-black-ops-7-anno-117-arc.html), [Creative Bloq](https://www.creativebloq.com/3d/video-game-design/does-the-crimson-desert-ai-art-controversy-matter)).
- Há falso positivo: desenvolvedores são acusados mesmo sem usar IA ([AITopics](https://aitopics.org/doc/news:CCB4ADCC)), e parte das acusações contra Fortnite parecia errada ([Futurism](https://futurism.com/artificial-intelligence/gamers-accuse-fortnite-ai-slop)). **Um jogo com cara genérica será chamado de slop de qualquer forma**, então a defesa é ter autoria visível.

### 5.2 Sinais objetivos e contramedidas

| # | Sinal apontado | Onde aparece | Contramedida verificável |
|---|---|---|---|
| 1 | **Estilos misturados**: personagem num tratamento, cenário em outro que não conversa; cara de "asset flip" | [StraySpark](https://www.strayspark.studio/blog/ai-slop-game-development-using-ai-responsibly), [Wayline](https://www.wayline.io/blog/asset-packs-vs-indie-visual-identity) | Um único gerador de formas e um único shader-base. Diferença entre personagem e cenário é regra escrita, não acidente |
| 2 | **Arte de loja polida que não bate com o jogo** | StraySpark | Capa, ícone e capturas saem do próprio motor e dos mesmos geradores |
| 3 | **Brilho plástico, superfície lisa demais, "acabamento" uniforme** | [Is It AI](https://isitai.com/blog/how-to-spot-ai-art), [itsme](https://itsme.biz/resources/how-to-spot-ai-art/) | Rugosidade alta por padrão, sem especular genérico. Material fictício com textura de processo (fibra, veio, goiva) |
| 4 | **Detalhe demais sem hierarquia**, "greeble" espalhado, tudo no mesmo nível | [Keith Kisser](https://medium.com/@keithkisser/why-does-all-ai-art-look-like-that-f74e2a9e1c87) | Orçamento 70/25/5 de formas grandes, médias e pequenas **[proposta]**. Áreas de descanso obrigatórias (o guia do Dota pede o mesmo) |
| 5 | **Luz "cinematográfica" sem direção definida**, sombras que não batem | Is It AI | Uma direção de luz-chave fixa para o jogo todo; sombra de uma só cor |
| 6 | **Texto e símbolos sem sentido**, objetos que se fundem | Is It AI | Todo texto em cena é texto real, de fonte licenciada. Nada de textura com letra "sugerida" |
| 7 | **Trechos fotorrealistas ao lado de trechos pintados** | itsme | Um só nível de abstração; proibido misturar foto com desenho |
| 8 | **Anatomia e contagem erradas** (dedos, dentes) | [Futurism](https://futurism.com/artificial-intelligence/gamers-accuse-fortnite-ai-slop) | Mãos e rostos simplificados por projeto (luva, 3 dedos, olhos pintados) |
| 9 | **Composição centrada, dramática e igual a todas**; estética "capa de prog rock" | [Sam Goree](https://samgoree.github.io/2025/07/11/Why_does_ai_art_look_like_that.html), [Fast Company](https://fastcompany.com/91001568/one-year-in-the-gen-ai-aesthetic-is-already-a-tired-trope) | Referência em arte popular e gravura, não em "fantasia genérica" |
| 10 | **UI de modelo pronto**: degradê roxo, sans-serif padrão, cartões arredondados | [Vandelay](https://www.vandelaydesign.com/?p=61673) | UI diegética no material do jogo; duas famílias tipográficas escolhidas; nenhuma fonte padrão do motor |
| 11 | **Malha 3D derretida**, topologia suja, geometria que só convence de um ângulo | [Tripo](https://www.tripo3d.ai/blog/why-ai-3d-models-look-bad), [Level Up Coding](https://levelup.gitconnected.com/3d-artists-arent-being-replaced-by-ai-not-yet-in-real-game-pipelines-cf75a6ee3947) | Modelagem construtiva com arestas intencionais. Girar todo modelo 360° na revisão |
| 12 | **Imitar um processo sem evocar o processo físico** | Sam Goree | Simular o processo: goiva remove madeira, tinta falha onde o papel é áspero, dobra tem vinco. Não aplicar "filtro de xilogravura" numa imagem pronta |
| 13 | **Clonar jogo de sucesso** | [games.gg](https://games.gg/news/ai-vibe-coding-clone-bury-games/) | Mundo, nomes e personagens próprios |

### 5.3 O "slop procedural", que é o nosso risco específico [proposta]

Arte gerada por código tem tiques próprios, não cobertos pelas discussões acima:

| Tique | Por que denuncia | Correção |
|---|---|---|
| Primitiva visível (cápsula, esfera UV, cubo de quina viva) | Todo mundo reconhece a forma padrão | Chanfro único em tudo, facetas assimétricas, perfis desenhados por curva |
| Ruído Perlin uniforme em tudo | Textura sem escala nem causa | Ruído só onde há causa física, em duas escalas no máximo |
| Simetria perfeita e repetição exata | Parece carimbo | Quebra de simetria de 1 a 3% com semente fixa; variantes por instância |
| Degradê liso de vértice | Faz faixas no RGBA8 da Web e parece demo técnica | Cor chapada em degraus, retícula ou hachura |
| Céu, luz, sombra e partícula padrão do motor | Assinatura do "projeto novo" | Ambiente, tonemap e material de partícula definidos por cena; nada com valor padrão |
| Paleta de cores "puras" (vermelho 255, verde 255) | Falta de decisão | Paleta mestra em OKLCH com no máximo 24 cores e rampas definidas |
| Animação interpolada linear, sem pose | Movimento de robô | Poses-chave fortes, seguradas, com antecipação e excesso (ver seção 6.3) |
| Tudo com o mesmo tamanho de detalhe | Sem foco | Densidade de detalhe sobe no rosto e nas mãos e cai no resto |

### 5.4 Contrato anti-slop: 12 regras checáveis por script [proposta]

1. **Paleta mestra de no máximo 24 cores**, definida em OKLCH. Teste: quantizar capturas e exigir menos de 2% de pixels fora da paleta (fora VFX).
2. **Três tintas por cena, mais o papel.** Cada região tem cor dominante, secundária e de acento na proporção aproximada 60/30/10.
3. **Uma família de formas**: ângulos permitidos, um raio de chanfro, proporção de personagem fixa (por exemplo 2,5 a 3 cabeças).
4. **Uma densidade de texel**: 128 px por metro cobre 1080p com folga de 1,6×; 256 cobre 4K. Um script mede e reprova desvio acima de 25%. (O guia de densidade de texel da indústria trata o número como alvo, não regra: [Vertex School](https://www.vertexschool.com/texel-density-guide).)
5. **Uma espessura de traço em pixels de tela** (por exemplo 3 px em 1080p), com variação de ±20% por pressão simulada.
6. **Uma direção de luz-chave em todo o jogo** e sombra de uma só cor (multiplicar por tinta, nunca preto puro).
7. **Imperfeição com orçamento e semente fixa**: tremor de vértice de 0,5 a 1,5%, registro de cor deslocado 1 a 2 px, "fervura" do traço a 6 ou 8 fps.
8. **Duas famílias tipográficas** com licença OFL; números de dano na fonte de título.
9. **Ícones gerados no mesmo sistema**, sem emoji e sem pacote genérico.
10. **Nenhum valor padrão do motor à vista** (lista de verificação automática na cena).
11. **Taxas de animação decididas uma vez**: personagem em 12 poses por segundo, VFX e câmera a 60.
12. **Portão de revisão por captura**: teste em cinza, teste de borrão, miniatura 320×180, simulação de daltonismo, e a captura lado a lado com 3 referências.

---

## 6. (d) Ranking de 8 direções de arte

### 6.1 Critérios e notas [proposta]

Pesos: esconde ou valoriza a modelagem procedural (25%), identidade e distância do slop (20%), legibilidade com 4 jogadores e muito VFX (15%), viabilidade no Compatibility (15%), custo e risco de produção (15%, nota alta significa barato), teto de impacto no Forward+ (10%). Notas de 1 a 5.

| # | Direção | Procedural | Identidade | Legibilidade | Web | Custo | Teto | **Total** |
|---|---|---|---|---|---|---|---|---|
| 1 | Xilogravura de cordel em papel recortado | 5 | 5 | 4 | 5 | 4 | 4 | **4,60** |
| 2 | Teatro de mamulengo (boneco de madeira e chita) | 5 | 5 | 4 | 4 | 3 | 5 | **4,40** |
| 3 | Papercraft, origami e livro pop-up | 5 | 3 | 4 | 5 | 4 | 4 | **4,20** |
| 4 | Azulejo vivo | 5 | 5 | 3 | 4 | 3 | 4 | **4,15** |
| 5 | Massinha ou barro em stop motion | 4 | 4 | 4 | 3 | 3 | 5 | **3,80** |
| 6 | Folclore noturno (silhueta e brilho) | 4 | 3 | 3 | 3 | 3 | 5 | **3,45** |
| 7 | HD-2D com sprites pré-renderizados | 4 | 3 | 4 | 3 | 2 | 4 | **3,35** |
| 8 | Brinquedo e diorama de plástico | 4 | 2 | 4 | 2 | 3 | 4 | **3,15** |

As notas são julgamento meu; a etapa de provas no motor deve confirmá-las ou derrubá-las.

### 6.2 Fichas

#### 1º Xilogravura de cordel em papel recortado (4,60)

- **O que é:** mundo impresso. Papel cru, tinta preta em massas grandes, linhas brancas "cavadas", uma ou duas cores chapadas por região. Em 3D, as figuras são folhas recortadas em camadas, como teatro de papel ou livro pop-up.
- **Referências:** capas de folheto de cordel e as gravuras coloridas de J. Borges (1935–2024, Bezerros, PE; madeira umburana; desenho, corte, entintagem e impressão: [Wikipedia](https://en.wikipedia.org/wiki/Jos%C3%A9_Francisco_Borges), [Vermelho](https://vermelho.org.br/2017/06/16/a-vida-do-povo-nordestino-pelas-maos-e-tintas-de-j-borges/)); Movimento Armorial; Pentiment; Book of Demons; Spider-Verse (retícula e erro de registro); Obra Dinn (padrão estável).
- **Jogos que já usaram:** Xilo (Paraíba, 2012, ação 2D, trilha da Cabruêra: [Lampião Aceso](https://lampiaoaceso.blogspot.com/2012/05/xilo-game-brasileiro-que-e-cabra-da.html)); **Cordels & Spells** (Supernova, CE, roguelite de ação co-op twin-stick, setembro de 2026: [Expresso Nerd](https://www.expressonerd.com.br/cordels-spells-jogo-brasileiro-que-mistura-cordeis-e-roguelike-chega-na-steam/), [Steam](https://store.steampowered.com/app/3543070)); Obscurium (cartas, previsto para 2027: [GameBlast](https://www.gameblast.com.br/2026/10/impressoes-obscurium-folclore-brasileiro-em-um-duelo-de-cartas-e-sacrificios.html)); Boitatá: Cobra de Fogo (mobile: [Drops de Jogos](https://dropsdejogos.uai.com.br/noticias/indie/com-simplicidade-e-narrativa-de-cordel-boitata-cobra-de-fogo-traz-o-regionalismo-e-a-cultura-popular-brasileira-aos-games/)); Vem, Exu ([Tarde de Games](https://tardedegames.com.br/noticias/vem-exu-indie-brasileiro-que-mistura-puzzles-e-narrativa-visual/)); Nordeste: A Cordel Story ([itch.io](https://rfc-studios.itch.io/nordeste-a-cordel-story/devlog/161487/launching-nordeste-a-cordel-story)); o jogo de cartas físico Cangaço ([SBGames](https://sol.sbc.org.br/index.php/sbgames/article/download/45454/45215/)). Todos 2D. Não achei nenhum em 3D de papel [não verificado que não exista].
- **Por que valoriza o procedural:** a figura de cordel é chapada, frontal e sem perspectiva por tradição; não há escultura orgânica a acertar. A textura é o processo de corte, que se simula (campo de distância, ruído direcional de veio, falha de tinta).
- **Riscos:** (a) virar "filtro" sobre render 3D, que é o sinal 12 da tabela de slop; o teste 3 mostrou que o filtro de tela nem sequer sai igual nos dois renderers; (b) preto sobre preto em cena cheia; (c) comparação direta com Cordels & Spells; (d) cuidado cultural: personagens originais, sem copiar gravuras de artistas, sem caricatura do sertanejo.
- **Custo:** baixo a médio. Boneco recortado de 8 a 12 peças anima mais barato que rig 3D completo. O gerador de textura de gravura é o item de pesquisa.
- **Compatibility:** sim, por inteiro. Materiais sem luz ou com luz em dois degraus, nenhuma dependência de GI. **Forward+ acrescenta:** translucidez do papel contra a luz, sombra suave entre camadas, foco seletivo nativo.

#### 2º Teatro de mamulengo (4,40)

- **O que é:** o jogo é um palco de bonecos. Cabeças de madeira talhada e pintada, corpo de luva de pano estampado (chita), cenário de tolda, cortina e telão pintado.
- **Referências:** Teatro de Bonecos Popular do Nordeste, patrimônio cultural do Brasil desde março de 2015 (mamulengo em PE, babau na PB, João Redondo no RN, Cassimiro Coco: [Carta Capital](https://www.cartacapital.com.br/?p=78236)); os bonecos "falam, dançam, brigam e quase sempre morrem" ([Móin-Móin](https://revistas.udesc.br/index.php/moin/article/download/1059652595034701032007016/7981/40896)); Link's Awakening e Yoshi's Crafted World (escala de maquete); South of Midnight e Harold Halibut (animação de boneco); Death's Door.
- **Jogos que já usaram:** **nenhum encontrado** em duas buscas (português e inglês) [não verificado que não exista].
- **Por que valoriza o procedural:** boneco de luva **não tem pernas**; é cabeça, cone de pano e dois braços. Elimina ciclo de caminhada, IK de pé e deslizamento, os pontos onde animação gerada por código mais falha. Cabeça talhada é faceta, e o pano se resolve com mola simples. A tradição já é de pancadaria cômica, que casa com co-op caótico no estilo Magicka.
- **Riscos:** (a) teatro é frontal; a câmera natural é de palco (belt-scroll, como Lost Castle), não isométrica alta; (b) madeira e pano dependem de boa luz, e na Web vale o achado 1; (c) muitos bonecos distintos para inimigos; (d) cuidado cultural: tradição viva, pede crédito e personagens próprios.
- **Custo:** médio. Rig simples, mas material e luz pedem mais ajuste que o papel.
- **Compatibility:** sim, com luz calibrada e tilt-shift por shader. **Forward+ acrescenta:** luz de ribalta com névoa volumétrica, SDFGI no interior do palco, foco seletivo nativo. É a direção com maior teto.

#### 3º Papercraft, origami e livro pop-up (4,20)

- **O que é:** tudo é papel dobrado ou recortado; o mundo abre como página de livro.
- **Referências:** Tearaway, Paper Mario, Hirogami, Book of Demons, Lumino City.
- **Jogos brasileiros que usaram:** não encontrei [não verificado].
- **Por que valoriza o procedural:** low poly facetado é literalmente origami. O addon [Export Paper Model](https://github.com/addam/Export-Paper-Model-from-Blender) gera o molde imprimível de qualquer malha, o que permite oferecer os personagens para montar, como o Tearaway fez.
- **Riscos:** terreno conhecido, com menos novidade que as opções brasileiras; "papel sozinho não é estilo" (lição do Book of Demons, que levou quase 2 anos).
- **Custo:** baixo a médio. **Compatibility:** sim. **Forward+ acrescenta:** translucidez e sombra de contato.
- **Observação:** é mais um suporte que uma identidade. Rende mais como base das direções 1 e 2.

#### 4º Azulejo vivo (4,15)

- **O que é:** mundo de cerâmica vidrada. Azul-cobalto sobre branco, padrões que se repetem de 4 em 4 peças, painéis figurativos que ganham vida, rejunte e craquelado.
- **Referências:** azulejaria portuguesa e o centro histórico de São Luís; a tradição de cobrir a parede inteira ([Wikipedia](https://en.wikipedia.org/wiki/Azulejo)).
- **Jogos que já usaram:** o jogo de tabuleiro Azul ([Wikipedia](https://en.wikipedia.org/wiki/Azul_(board_game))); Twin Tile (memória, azulejo espanhol: [Steam](https://store.steampowered.com/app/3937800/)). Lunar Axe (OPS Studio, MA, 2022) reproduz locais reais do centro de São Luís, mas as fontes não confirmam azulejo como linguagem visual ([Steam](https://store.steampowered.com/app/1305820/Lunar_Axe)). Nenhum jogo de ação encontrado.
- **Por que valoriza o procedural:** padrão de azulejo é simetria e repetição, exatamente o que código faz melhor que mão. A grade organiza o cenário.
- **Riscos:** (a) padrão denso é ruído visual e briga com VFX, o oposto do que a Riot pede; (b) fadiga de um mundo azul e branco; (c) os 4 jogadores precisam de código de cor fora do azul; (d) falta decidir como é o personagem (figura pintada ou estatueta), o que cria duas linguagens.
- **Custo:** médio. **Compatibility:** sim, com brilho por matcap (sem SSR). **Forward+ acrescenta:** reflexo real no esmalte.
- **Melhor uso:** como bioma ou como linguagem de UI e de piso dentro de outra direção.

#### 5º Massinha ou barro em stop motion (3,80)

- **O que é:** personagens de argila com marca de dedo, animados em 12 poses por segundo.
- **Referências:** The Midnight Walk, Harold Halibut, South of Midnight; Vokabulantis/Out of Words (co-op em stop motion, bonecos reais escaneados: [Engadget](https://www.engadget.com/vokabulantis-stop-motion-video-game-kickstarter-202836987.html)). Versão brasileira: os bonecos de barro de Caruaru na tradição de Mestre Vitalino (1909–1963), com cenas do cotidiano do sertão ([Google Arts & Culture](https://artsandculture.google.com/story/fQXBDUT5UM7r3g)).
- **Jogos que já usaram a versão brasileira:** nenhum encontrado.
- **Por que valoriza o procedural:** forma arredondada por campo de distância é o que o Blender gera com facilidade. Mas "malha derretida" também é sinal de 3D gerado por IA (sinal 11), então a marca de processo (dedo, emenda, tinta fosca) tem de ser evidente.
- **Riscos:** argila convence por translucidez e luz macia, que a Web não tem (sem SSS). Todas as referências fortes são de objetos reais escaneados.
- **Custo:** médio. **Compatibility:** parcial. **Forward+ acrescenta:** SSS, que muda tudo.

#### 6º Folclore noturno: silhueta e brilho (3,45)

- **O que é:** direção guiada pela luz. Mata e sertão à noite, criaturas encantadas como silhuetas com partes luminosas (o fogo do Boitatá, os olhos da Cuca), lanterna dos jogadores como zona de leitura.
- **Jogos de folclore brasileiro:** FolcDark ([Steam](https://store.steampowered.com/app/2372910)), Saci: The Cursed Hunt ([Steam](https://store.steampowered.com/app/3265750)), Curupira the Forest Guardian ([Steam](https://store.steampowered.com/app/4055450)), Lunar Axe, Aritana e a Pena da Harpia, Dandara ([Game Developer](https://www.gamedeveloper.com/design/-you-can-deliver-empathy-why-i-dandara-i-s-devs-drew-inspiration-from-brazilian-culture)), Árida ([Wikipedia](https://en.wikipedia.org/wiki/ARIDA:_Backland%27s_Awakening)). Predominam terror e 2D; não achei RPG de ação co-op.
- **Por que esconde o procedural:** silhueta e névoa escondem modelagem fraca melhor que qualquer outra opção; o brilho leva o olho para onde se quer.
- **Riscos:** (a) cena escura com 4 jogadores e muito efeito é o pior caso de legibilidade (a crítica ao Diablo IV foi essa: [fórum da Blizzard](https://us.forums.blizzard.com/en/d4/t/art-style-its-really-not-very-good/83067?page=2)); (b) tela de celular ao ar livre; (c) grafismos indígenas pertencem a povos específicos e não devem ser copiados.
- **Custo:** médio. **Compatibility:** parcial (sem névoa volumétrica). **Forward+ acrescenta:** névoa volumétrica e SDFGI.
- **Observação:** folclore é conteúdo, não técnica. Cabe em qualquer direção acima, e rende mais como elenco de criaturas do "teatro de cordel".

#### 7º HD-2D com sprites pré-renderizados (3,35)

- **O que é:** pipeline do Dead Cells aplicado ao HD-2D. Modelo no Blender, render de sprite e normal map em baixa resolução, sprite com luz dinâmica em cenário 3D.
- **Referências:** Octopath, Sea of Stars, Dead Cells, Hades. No GitHub há vários modelos de HD-2D em Godot sem licença, úteis só como leitura ([Meowa-AI/HD2D-template-meowa](https://github.com/Meowa-AI/HD2D-template-meowa), Godot 4.6).
- **Por que esconde o procedural:** reduzir para cerca de 50 a 90 px de altura apaga defeitos do modelo. Já existe experiência no repositório (pixelrig do Céu Arcano).
- **Riscos:** (a) "belos sprites muito bem animados" no nível de Sea of Stars são ofício manual, e o caminho por 3D dá outro resultado, mais para Dead Cells; (b) pixels piscando entre quadros, limpos à mão no Dead Cells; (c) câmera alta pede 8 direções vezes todas as animações vezes todas as criaturas, com peso de memória e de download na Web; (d) o estilo é imediatamente associado à Square Enix; (e) a assinatura (foco seletivo e raios de luz) é o que falta na Web.
- **Custo:** alto em volume de sprites. **Compatibility:** parcial, com tilt-shift próprio. **Forward+ acrescenta:** DOF, névoa volumétrica, decals.

#### 8º Brinquedo e diorama de plástico (3,15)

- **O que é:** mundo de brinquedo, com plástico, madeira envernizada e metal pintado, em escala de maquete.
- **Referências:** Link's Awakening, Astro Bot, Captain Toad.
- **Por que valoriza o procedural:** primitivas chanfradas viram brinquedo com naturalidade.
- **Riscos:** é a direção mais próxima do "3D padrão". Sem reflexo, oclusão e desfoque de primeira, cai no visual de jogo casual de celular, que é o slop que o usuário quer evitar. Brilho plástico é o sinal 3.
- **Custo:** médio. **Compatibility:** fraco: depende justamente de SSR, SSAO (só no 4.6) e DOF. **Forward+ acrescenta:** tudo o que faz o estilo funcionar.

### 6.3 Síntese recomendada: "teatro de cordel" [proposta]

| Camada | Material fictício | Regra visual | Origem |
|---|---|---|---|
| Cenário | Papel impresso em xilogravura, recortado em camadas | Papel cru, preto, 1 ou 2 cores chapadas por região; saturação baixa | Direções 1 e 3 |
| Personagens e inimigos | Boneco de madeira pintada com roupa de chita | Cor saturada, cabeça grande, contorno escuro, sombra em 2 degraus | Direção 2 |
| Efeitos | Papel de seda, fita, confete, fumaça de tinta, brasa | Valor e saturação mais altos da cena; picos curtos | Seção 7 |
| Criaturas | Folclore reinterpretado como boneco ou gravura | Silhueta única por criatura | Direção 6 |
| Interface | Folheto, cartaz de feira, barbante com folhetos | Tipografia de madeira e papel | Seção 8 |
| Biomas opcionais | Azulejo (cidade), barro (feira) | Trocam a paleta, mantêm as regras | Direções 4 e 5 |

Por que funciona: (1) personagem e cenário têm materiais e saturações diferentes por regra, que é o truque de Death's Door e do HD-2D; (2) nada depende de recurso ausente na Web; (3) cada imperfeição tem causa física; (4) os três materiais são formas facetadas simples; (5) boneco de luva dispensa pernas.

**Animação nessa direção** (12 princípios aplicados a boneco): poses-chave seguradas a 12 por segundo com o jogo a 60 (South of Midnight, Cuphead); comprimir e esticar no pano, não na madeira; antecipação pelo recuo da cabeça; ação secundária no pano e nos adereços por mola; exagero nas poses de golpe; opção de desligar o efeito de stop motion, como South of Midnight oferece. Resposta ao comando não pode esperar a pose: o deslocamento é contínuo, só a pose é segurada.

**Dúvida a resolver na prova de estilo:** câmera. Mamulengo pede palco frontal (belt-scroll); Magicka é isométrico. A prova deve capturar os dois enquadramentos.

---

## 7. (e) Cor, luz e composição para legibilidade com 4 jogadores e muito VFX

### 7.1 O que as fontes dizem

| Regra | Fonte |
|---|---|
| Três objetivos de clareza: jogabilidade claramente transmitida, hierarquia sempre preservada, ruído mínimo. "Todo efeito audiovisual precisa ter uma causa" | [Riot, Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/) |
| A atenção que uma habilidade atrai deve ser proporcional à sua importância. A importância se controla por tamanho, forma, tempo, valor, saturação e opacidade | [Guia de estilo de VFX da Riot (PDF)](https://nexus.leagueoflegends.com/wp-content/uploads/2017/10/VFX_Styleguide_final_public_hidpjqwx7lqyx0pjj3ss.pdf), [post](https://nexus.leagueoflegends.com/en-us/2017/10/dev-leagues-vfx-style-guide/) |
| Elementos primários: faixa de valor alta, contraste forte, silhueta nítida, opacidade alta. Secundários: faixa menor, pequenos, silhueta borrada, opacidade baixa | Guia da Riot |
| VFX usa faixa de valor e saturação mais larga e alta que personagem e cenário, mas abaixo dos extremos da interface. Evitar 0% e 100% puros em VFX | Guia da Riot, via [VFX Apprentice](https://www.vfxapprentice.com/blog/10-league-of-legends-vfx-design-tips) e [gdad.wiki](https://gdad.wiki/wiki/sources/source-lol-vfx-style-guide) [resumos secundários] |
| Todo efeito tem antecipação e dissipação. O clarão de impacto é o pico de valor e saturação e acontece no primeiro quarto da vida do efeito; a saída usa valor, saturação e opacidade menores | Guia da Riot [resumo secundário] |
| O desenho no chão mostra o raio real da área de efeito (exemplos corrigidos: cogumelo do Teemo, ultimate da Sona) | Guia da Riot [resumo secundário] |
| Silhueta é o fator mais importante para reconhecer um personagem | Riot, Clarity in League |
| Gradiente de valor: mais escuro embaixo, mais claro no tronco e na cabeça. Mais contraste em cima. Testar o padrão de valor em cinza, dentro do jogo, antes de pôr cor. Reduzir a saturação geral e subir só nos pontos focais. Áreas de descanso equilibram áreas complexas | [Guia de arte de personagem do Dota 2](https://help.steampowered.com/faqs/view/0688-7692-4D5A-1935) |
| Luz de borda clara no lugar de contorno escuro; silhuetas distintas por classe; quente contra frio para separar times | [Illustrative Rendering in Team Fortress 2](https://www.cs.princeton.edu/courses/archive/fall07/cos597B/papers/mitchell-team-fortress.pdf), [slides GDC 2008](https://cdn.steamstatic.com/apps/valve/2008/GDC2008_StylizationWithAPurpose_TF2.pdf) |
| Para a câmera isométrica: formas maiores na armadura, menos detalhe secundário e terciário, o cenário escolhe onde tirar detalhe para liberar o espaço de jogo | [Blizzard, Diablo IV, junho de 2021](https://news.blizzard.com/en-us/article/23665024/diablo-iv-quarterly-updatejune-2021) |
| "Legibilidade é o princípio mais importante" da direção visual do Diablo III | [Gameranx, GDC 2012](https://gameranx.com/features/id/5666/article/gdc-2012-the-art-of-diablo-iii/) |
| Contraexemplo: Hades II é criticado por não deixar claro o raio dos ataques inimigos | [nex-3](https://nex-3.com/blog/hades-ii-has-a-legibility-problem/) |
| Contorno é ferramenta de profundidade e leitura | [Sable](https://www.gamedeveloper.com/marketing/how-shedworks-refined-the-art-of-sable-in-pursuit-of-readability) |
| Magicka 2: fogo amigo sempre ligado; o jogador precisa vigiar toda área que ele mesmo incendeia | [Game Informer](https://gameinformer.com/games/magicka_2/b/pc/archive/2015/06/02/friendly-fire-fulminations.aspx) |

### 7.2 Orçamento de valor e saturação para este projeto [proposta]

Valores em HSV, medidos na captura final. Os princípios são da Riot e do Dota; os números são ponto de partida meu.

| Camada | Valor | Saturação | Observação |
|---|---|---|---|
| Chão e cenário jogável | 25 a 55% | até 35% | Sem padrão de alto contraste sob os pés |
| Cenário de fundo e bordas | 15 a 45% | até 30% | Pode receber desfoque e vinheta |
| Inimigos comuns | 35 a 70% | 30 a 55% | Silhueta escura com um ponto de cor |
| Jogadores | 50 a 85% | 55 a 80% | Cabeça e ombros mais claros que os pés |
| VFX de jogador | 60 a 95% | 60 a 95% | Pico no primeiro quarto do efeito |
| Aviso de ataque inimigo | 70 a 95% | 85 a 100% | **Matiz reservado**, não usado em mais nada |
| Interface | 0 a 100% | livre | Única camada com preto e branco puros |

### 7.3 Regras [proposta, salvo indicação]

**Cor**

1. **Quatro matizes de jogador separados por cerca de 90°**, repetidos no anel do chão, no retrato e nos números de dano.
2. **Cor nunca é o único código.** Cada jogador tem também forma (chapéu, arma, estampa) e símbolo no anel.
3. **Perigo tem um matiz só**, independentemente de quem o criou. Com fogo amigo no estilo Magicka, o que machuca usa a linguagem de perigo mesmo vindo de aliado.
4. **Elemento se lê por forma e movimento além de cor**: fogo sobe e tremula, gelo é anguloso e parado, raio é linha quebrada instantânea.
5. **Cenário de saturação baixa libera a saturação para o jogo.** É a vantagem estrutural do papel com tinta preta.

**Luz**

6. **Personagem tem luz própria**: luz de borda ou reforço sem sombra (TF2, Death's Door).
7. **Sombra de contato sempre.** Na Web, disco ou malha projetada (sem decals antes do master).
8. **Cada feitiço acende uma luz** (lição do Octopath), limitada a 2 ou 3 simultâneas na Web.
9. **Névoa nunca no plano de jogo**; só atrás e nas bordas.
10. **Glow com teto**: só VFX e brasa passam do limiar.

**Composição e câmera**

11. **Desfoque só fora do plano de jogo**: faixas no topo e na base.
12. **Vinheta leve** para escurecer as bordas.
13. **Marcador de área no chão com o raio verdadeiro**, como malha plana.
14. **Tamanho mínimo**: jogador com pelo menos 9% da altura da tela (cerca de 64 px em 720p), pensando no celular.
15. **Tempo de efeito**: antecipação curta, impacto de 2 a 4 quadros no pico, dissipação mais longa e mais fraca. Resíduo no chão com opacidade abaixo de 40%.
16. **Orçamento de ruído**: no máximo 3 efeitos primários na tela; o resto cai para secundário.
17. **Jogador encoberto aparece** em silhueta chapada por trás do obstáculo.

**Portões de teste em toda captura**

- Cinza: jogadores e avisos ainda se destacam?
- Borrão (gaussiano de 8 px) e miniatura 320×180: dá para contar os 4 jogadores?
- Simulação de daltonismo (deuteranopia e protanopia): os 4 jogadores e o perigo continuam distintos?
- Estresse: 4 jogadores, 20 inimigos e 6 efeitos simultâneos em uma captura obrigatória por bioma.
- Paridade: a mesma captura no Compatibility e no Forward+, com diferença média abaixo de um limite definido.

---

## 8. Tipografia e interface

Fontes com licença OFL confirmadas no repositório `google/fonts` (acessível por `raw.githubusercontent.com`; pasta `ofl/<nome>/`) [teste]:

| Uso | Fonte | Nota |
|---|---|---|
| Título com sotaque brasileiro | **Londrina Solid, Shadow, Sketch** (Marcelo Magalhães) | Desenho brasileiro; a escolha mais natural para cartaz de feira |
| Tipo de madeira, cartaz | Rye, Sancreek, Ewert, Vast Shadow, Alfa Slab One, Bowlby One, Chango | Lembram tipos de madeira de impressão popular |
| Texto antigo impresso | IM Fell English, IM Fell DW Pica | Imperfeição de impressão embutida no desenho |
| Fantasia medieval e armorial | Almendra, Grenze Gotisch, Macondo, New Rocker | Usar com parcimônia |
| Texto de leitura | Fraunces, Bricolage Grotesque, Gloock, DM Serif Display | Legíveis em tela pequena |
| Números de dano | Bungee, Titan One, Lilita One, Bangers | Pesadas, leem bem em movimento |

Não encontradas nesse repositório: Xilosa, Cordel, Smokum, Luckiest Guy (404 na pasta `ofl/`).

Regras de UI **[proposta]**: interface feita do material do mundo (folheto pendurado em barbante como inventário, cartaz de feira como seleção de fase, bilhete de papel como diálogo); duas famílias no máximo; ícones gerados pelo mesmo sistema de formas; nenhum degradê liso, nenhum cartão arredondado padrão, nenhum emoji.

---

## 9. Ferramentas baixáveis e verificadas

Todas responderam a `git ls-remote <url> HEAD` neste ambiente [teste]. O hash é o HEAD no dia da pesquisa.

| Repositório | HEAD | Licença | Para que serve |
|---|---|---|---|
| [godotengine/godot-docs](https://github.com/godotengine/godot-docs) | 4f24246d | CC-BY 3.0 | Documentação oficial offline |
| [godotengine/godot-demo-projects](https://github.com/godotengine/godot-demo-projects) | 281a99f0 | MIT | Demos oficiais de shader e pós-processo |
| [gdquest-demos/godot-shaders](https://github.com/gdquest-demos/godot-shaders) | 158a4905 | Código MIT, arte CC-BY 4.0 | Biblioteca de shaders estilizados para estudo |
| [GDQuest/godot-visual-effects](https://github.com/GDQuest/godot-visual-effects) | 647a8f1b | Código MIT, arte CC-BY 4.0 | Receitas de VFX |
| [gdquest-demos/godot-4-stylized-sky](https://github.com/gdquest-demos/godot-4-stylized-sky) | a52b0874 | Duas licenças | Céu estilizado |
| [CaptainProton42/FlexibleToonShaderGD](https://github.com/CaptainProton42/FlexibleToonShaderGD) | dacf9a41 | MIT | Toon por material, o caminho estável entre renderers |
| [lrplrplrp/Godot-ToonShader](https://github.com/lrplrplrp/Godot-ToonShader) | 59f9b101 | MIT | Toon recente (2026) |
| [jocamar/Godot-Post-Process-Outlines](https://github.com/jocamar/Godot-Post-Process-Outlines) | 12a9e0e9 | MIT | Contorno por pós-processo |
| [leopeltola/Godot-3d-pixelart-demo](https://github.com/leopeltola/Godot-3d-pixelart-demo) | 6118473c | MIT | Pixel art 3D à moda do t3ssel8r |
| [paddy-exe/GodotVisualShader-Extras](https://github.com/paddy-exe/GodotVisualShader-Extras) | 0e86e427 | MIT | Nós extras de shader |
| [HungryProton/scatter](https://github.com/HungryProton/scatter) | 7198cc00 | MIT | Espalhar objetos por regra |
| [GarrettGunnell/Post-Processing](https://github.com/GarrettGunnell/Post-Processing) | 871a7ffc | MIT | Referência (Unity) de Kuwahara, dithering e retícula para portar |
| [Zengkailin/parametric-topdown-pixel-architecture](https://github.com/Zengkailin/parametric-topdown-pixel-architecture) | 406c2f09 | MIT | Arquitetura 3D paramétrica renderizada como pixel top-down |
| [addam/Export-Paper-Model-from-Blender](https://github.com/addam/Export-Paper-Model-from-Blender) | d688dcd1 | GPL-3.0-or-later | Molde de papel imprimível; versão 1.4.2 pede Blender 5.0 ou mais novo |
| [mrven/Blender-Texel-Density-Checker](https://github.com/mrven/Blender-Texel-Density-Checker) | 3737a8c9 | GPL | Medir densidade de texel |
| [bnpr/Malt](https://github.com/bnpr/Malt) | 0346b178 | MIT | Render não fotorrealista para Blender [compatibilidade com 5.3 não verificada] |
| [azagaya/laigter](https://github.com/azagaya/laigter) | 8e14e60b | GPL-3.0 | Normal map a partir de sprite [compilação não testada] |
| [Orama-Interactive/Pixelorama](https://github.com/Orama-Interactive/Pixelorama) | 60dd36a0 | MIT | Editor de sprite feito em Godot |
| [google/fonts](https://github.com/google/fonts) | 50268007 | OFL por família | Tipografia (seção 8) |

Sem arquivo de licença na raiz, só para leitura: `Meowa-AI/HD2D-template-meowa`, `Phaazoid/Godoiosis`, `jeeve-javari/lantern-crossing-vita`, `galloscript/GGXrdShading`, `SamsonStarmerLee/TF2_Shaders`, `lettier/3d-game-shaders-for-beginners`.

Pacotes no PyPI confirmados com `pip index versions` [teste]: numpy 2.5.5, scipy 1.18.1, scikit-image 0.26.0, opencv-python-headless 5.1.0.95, opensimplex 0.4.5.1, noise 1.2.2, shapely 2.2.0, pyclipper 1.4.0, trimesh 5.2.2, coloraide 8.17 (OKLCH), colour-science 0.4.7, svgwrite 1.4.3, pycairo 1.29.2, skia-python 144.1, potracer 0.0.4, vtracer 0.6.15, fonttools 4.69.1, pyvips 3.2.0. Não existe: hitherdither.

Recursos do próprio Blender úteis aqui: Freestyle (testado), modificador Line Art do Grease Pencil, nó Kuwahara do compositor, Geometry Nodes [os três últimos não testados nesta etapa].

---

## 10. Pontos em aberto

1. Quase todas as fontes fora do GitHub foram lidas por resumo de busca. Antes de citar número ou frase em material público, conferir o original, em especial o PDF do guia de VFX da Riot e o PDF da palestra do Guilty Gear Xrd.
2. Os achados 1 a 3 da seção 2.2 foram medidos no Godot 4.5.1 com renderização por software. Falta confirmar em GPU real, no navegador e nas versões 4.6 e 4.7.
3. Não sei se o LightmapGI assa com Vulkan por software neste container.
4. Não achei jogo com estética de mamulengo nem jogo de ação com estética de azulejo. Ausência em busca não prova inexistência.
5. Cordels & Spells é o concorrente temático direto. Há divergência entre fontes sobre a situação na Steam e não li análises de jogadores.
6. Pipelines de Vanillaware, Eastward, Astro Bot (materiais), Dragon Quest III HD-2D e Live A Live: sem confirmação.
7. Os números de valor, saturação, densidade de texel e as notas do ranking são propostas minhas, a validar nas provas de estilo.
8. Câmera de palco ou isométrica para o "teatro de cordel": decisão de design que a prova de estilo precisa informar.
9. Cordel e mamulengo são tradições vivas. Vale decidir cedo como dar crédito e evitar caricatura. O registro do cordel como patrimônio imaterial pelo IPHAN (2018, pelo que lembro) não foi confirmado nesta pesquisa.
10. Se o jogo for publicado na Steam, a regra de divulgação de IA (desde janeiro de 2026 focada em conteúdo que o jogador vê ou ouve) provavelmente se aplica. Não pesquisei o texto da regra.

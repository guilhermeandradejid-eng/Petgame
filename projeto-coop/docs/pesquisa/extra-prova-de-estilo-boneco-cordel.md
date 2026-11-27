# Prova de estilo: boneco de mamulengo sobre palco de xilogravura (bpy + Godot 4.7.2)

Pesquisa e teste prático feitos em 27/11/2026. É só uma prova de estilo: nada do jogo foi construído. Personagens, nomes e arte são originais e foram gerados por script.

**Pergunta.** Um boneco de madeira e chita, com cerca de 25 ossos, casca invertida e toon por `light()`, feito só por `bpy`, sobre cenário de papel em xilogravura e com um efeito de papel de seda, chega a um nível que não pareça slop no renderer Compatibility? E qual câmera funciona melhor com 4 jogadores e 20 inimigos: palco (belt-scroll) ou isométrica?

**Como ler a confiança de cada informação.** **[teste]** quer dizer medido aqui, no container (4 CPUs, sem GPU, Blender 5.3.0 como módulo `bpy`, Godot 4.7.2-stable sob Xvfb, Compatibility por llvmpipe e Forward+ por lavapipe). **[fonte]** aponta para um link. **[opinião]** é julgamento meu. **[não verificado]** é o que não consegui confirmar.

**Onde estão os arquivos.** Scripts, projeto Godot, capturas e folhas de contato ficam em `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-prova-estilo/`, uma pasta temporária. **As quatro folhas para o usuário julgar** estão em `.../pesquisa-prova-estilo/out/folhas/`:

| Folha | Conteúdo |
|---|---|
| `folha1_cameras.png` | duelo e estresse (4 + 20) nas três câmeras: palco, camarote e alta |
| `folha2_portoes.png` | estresse: original, cinza, borrão, miniatura 320×180, deuteranopia, protanopia |
| `folha3_variantes.png` | tinta toda preta × hierarquia de tinta × chão pardo; Compatibility × Forward+ |
| `folha4_boneco.png` | folha de modelo, ciclo de ataque (perfil e 3/4), sprite do Cycles × 3D no motor |

---

## 1. Resposta curta

1. **O estilo funcionou e não tem cara de slop.** O boneco gerado só por código parece um boneco articulado de madeira pintada com roupa de chita, não um "personagem 3D genérico" [opinião, ver `folha4_boneco.png`]. O que o salva:
   - peças rígidas de madeira presas a um osso cada, com juntas visíveis (joelho de bola, maxilar solto, pescoço em anel);
   - facetas de talho por ruído com semente fixa;
   - chita com padrão de flor gerado em numpy;
   - rosto pintado com peças finas;
   - pose segurada em 2s.

   O resultado **é idêntico nos dois renderers**: diferença média de 1,3 a 1,9 níveis em 255, e 1,6% a 5,9% dos pixels diferem mais de 8 níveis, quase tudo na borda do papel de seda [teste].
2. **Câmera: nenhuma das duas puras.** Recomendo a **câmera de "camarote"**: perspectiva de 30°, inclinação de 38°, distância de 15,5 m.
   - **Palco** (7° de inclinação) é a mais bonita, com rosto, maxilar, chita e tolda. Mas com 20 inimigos vira um muro: inimigos na frente cobrem os heróis, e as costas dos inimigos é o que mais aparece.
   - **Alta estilo Magicka** (55°) separa todo mundo no chão, mas o chapéu de aba larga esconde o rosto e o boneco vira "chapéu sobre vestido".
   - **Camarote** mantém o telão e os recortes de papel no quadro, mostra parte do rosto e separa os 24 personagens. Heróis medem 116 a 155 px de altura em 720p e inimigos 32 px na miniatura 320×180 [teste, `folha1_cameras.png`].
3. **3D toon, não sprite pré-renderizado.** O sprite do Cycles sai um pouco mais nítido: contorno mais grosso e antisserrilhamento por amostragem. Custa só 0,3 s por quadro de 400 px. Mas exige 8 direções × todas as animações × variantes de jogador. O ganho visual se recupera no 3D engrossando o contorno [teste, `cmp_sprite.png`].
4. **Problemas reais que os portões acharam:**
   - **Heróis em tons claros e saturados sobre papel cru claro somem no teste de cinza e no de borrão.** Na vista alta, a mediana de ΔL é 0,073 e 2 dos 4 heróis ficam abaixo de 0,10.
   - **Os 4 jogadores colapsam em deuteranopia e protanopia.** O ΔE OKLab mínimo entre médias de cor cai de 0,055 para 0,005 a 0,032.
   - **O orçamento de valor da seção 7.2 do relatório de direção de arte não serve para estilo de papel.** O fundo mede V 78 a 85%, contra o alvo de 25 a 55%.
   - **51 cores distintas** no código, contra o limite de 24 da regra 1.

   Todos têm conserto de direção de arte (seção 7). Nenhum derruba a direção.
5. **Duas armadilhas técnicas novas** [teste]:
   - **No Compatibility do 4.7.2, a cor de vértice (`COLOR`) de um GLB chega ao shader escurecida**, como se recebesse uma segunda conversão de sRGB para linear: #E0B54A sai (190,117,13) contra (224,180,73) no Forward+. Quadrados de teste com `StandardMaterial3D`, `ShaderMaterial` com e sem `light()` e unshaded deram (224,181,74) idêntico nos dois. Só o `COLOR` difere.
   - **O exportador glTF do Blender 5.3 ignora `export_vertex_color='ACTIVE'`** para um atributo `float_color` criado por bmesh. Só `'NAME'` com `export_vertex_color_name='Col'` gravou o `COLOR_0`. E `preferences.edit.keyframe_new_interpolation_type='CONSTANT'` não vale para `keyframe_insert` via `bpy`: saiu `CUBICSPLINE`, e foi preciso marcar cada chave como CONSTANT pelo channelbag.

---

## 2. O que foi construído (todo o pipeline por script)

| Etapa | Ferramenta | O que faz | Tempo medido |
|---|---|---|---|
| Texturas | numpy + Pillow (`tools/tex.py`, `tools/chao.py`) | 5 chitas em tile de 512 px (4 jogadores e 1 inimigo); 3 mapas de xilogravura RGBA (R tinta, G cor 1, B cor 2, A recorte) a 128 px/m: telão 18×7 m, camada recortada 18×3,2 m, chão 20×14 m | ~2 min o conjunto; chão 25 s |
| Boneco | `bpy`/`bmesh` (`tools/boneco.py`) | gerador paramétrico: cabeça talhada (cubo subdividido e "cast" 0,72) ou cabaça; maxilar articulado; rosto pintado; 4 chapéus (palha, cone de reisado, coroa de flores, meia-lua de couro); vestido por torno com barra em festão; mangas de sino; pernas de pau; espada de pau listrada | 0,02 s por boneco |
| Rig | `bpy` (edit bones) | **25 ossos**: root, hips, spine, chest, neck, head, jaw, hat, 4 por braço, weapon, 3 por perna, skirt.F e skirt.B. Madeira com peso 1 em um osso, chita com pesos misturados | incluso |
| Contorno | `bmesh` | casca gerada junto: cópia de cada peça deslocada pela normal suave (0,018 m × peso), material `contorno`, peso do vertex group `contorno` gravado no alfa da cor de vértice. Peças finas do rosto ficam sem casca | incluso |
| Animação | `bpy` | `idle`, `ataque` (24 quadros a 24 fps, 10 poses-chave CONSTANT em 2s) e `golpeado`. Pose dada em eixos do armature e convertida para o espaço do osso | 0,01 s |
| Exportação | glTF-Blender-IO embutido | GLB com 3 animações STEP, `COLOR_0` VEC4, 3 materiais | 0,13 a 0,21 s; 307 a 346 KB |
| Motor | Godot 4.7.2 (`proj/main.gd` + 6 shaders) | carrega o GLB em tempo de execução (`GLTFDocument`, bake de 24 fps, trilhas importadas como `INTERPOLATION_NEAREST`), troca os materiais por nome, monta a arena e captura | 70 a 260 ms por quadro sob software |
| Sprite | Cycles CPU (`tools/sprite.py`) | mesmo gerador; toon por emissão (N·L contra vetor fixo, degrau em −0,05) e casca com `Backfacing`; 16 amostras, 400×400, fundo transparente | **0,29 a 0,30 s por quadro** |
| Portões | numpy (`tools/gates.py`) | cinza, borrão, miniatura, daltonismo de Machado (2009), orçamento HSV, paridade | 2,7 min para 26 capturas |
| Folhas | Pillow (`tools/folhas.py`) | 4 folhas de contato | segundos |

São cerca de 1.570 linhas no total (Python, GDScript e shaders).

**Malha por boneco** [teste]:

| Boneco | Triângulos | Madeira | Contorno | Chita | GLB |
|---|---|---|---|---|---|
| herói P1 | 3.612 | 1.448 | 1.612 | 552 | 346 KB |
| inimigo | 3.212 | 1.156 | 1.504 | 552 | 308 KB |

São 3 superfícies, portanto **3 draw calls por boneco**. A casca dobra a contagem de triângulos, o que é aceitável nessa faixa.

### 2.1 Shaders (todos no material, nenhum filtro de tela)

| Shader | Técnica | Por quê |
|---|---|---|
| `boneco.gdshader` | `light()` próprio: `smoothstep` em N·L (degrau em −0,05, largura 0,015); sombra = albedo × tinta única (0,62; 0,50; 0,64), nunca preto (regra 6); albedo = cor de vértice ou chita; ramo `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY` que desfaz a conversão extra da cor de vértice | toon igual nos dois renderers. Base: o `light()` padrão da doc 4.7, `DIFFUSE_LIGHT += ... * LIGHT_COLOR / PI` |
| `contorno.gdshader` | `cull_front`, unshaded; soma à casca do Blender uma espessura constante em pixels de tela (`px_width` × alfa × `VIEWPORT_SIZE`), com variação de pressão de ±20% por hash do vértice (regra 5) | contorno que não afina com a distância; funciona em perspectiva e em ortográfica |
| `papel.gdshader` | lê o mapa RGBA de xilogravura; fibra do papel por 2 ruídos anisotrópicos (±3%); cor chapada com **registro deslocado** (UV + 0,0012/−0,0016); pressão de tinta 0,88 a 1,0; recorte por alpha scissor | imperfeição com causa física (regra 12 do relatório de direção de arte) |
| `tolda.gdshader` | chita da tolda com pregas em 2 degraus e barra em festão | empanada (pano da frente) e bambinela (pano de cima) do mamulengo |
| `seda.gdshader` | retalho rasgado (borda por ruído angular em 2 escalas), estrela de impacto de 8 pontas, fita; opacidade 0,72 a 0,8 (sobreposição deixa ver o de baixo), fibras, vinco; semente por `NODE_POSITION_WORLD` | o único VFX: impacto em papel de seda, sem textura |
| `sombra.gdshader` | elipse com borda rasgada, `blend_mul` pela tinta de sombra | sombra de contato sem luz com sombra, que estoura no Compatibility (achado 1 do relatório de direção de arte) |

### 2.2 Gouge, ou "goiva por material"

A goiva não é filtro. Cada golpe é uma fileira de traços em V que afinam nas pontas (largura = `w·sin(πt)^0,7`), com quebra aleatória por fileira e onda opcional. Os entalhes seguem a forma: fileiras horizontais nos morros, verticais nos mandacarus, tijolo na casa. Por cima entram três camadas de imperfeição:

- borda irregular por fBm (±3 a 3,5 px);
- falha de tinta onde o grão do papel é alto;
- estrias do veio da madeira nas massas pretas.

O sol leva anéis entalhados e raios em cunha. A cor chapada ocre vai por baixo, fora de registro.

---

## 3. Resultados por pergunta

### 3.1 Chega a não parecer slop? [opinião, sustentada pelas folhas]

**Sim, com ressalvas.** O que lê como "feito à mão":

- **Articulação rígida.** Madeira não deforma e as juntas aparecem. Isso dispensa skinning bonito, que é o ponto fraco de um modelador por script. Bate com a regra "comprimir e esticar no pano, não na madeira" do relatório de direção de arte: só `skirt.F` e `skirt.B` mudam de escala (1,12/0,86 na antecipação; 0,94/1,12 no golpe).
- **Pose em 2s.** A antecipação longa (quadros 5 a 10) com a cabeça recuada e a boca aberta, o contato curto (11 e 12) e o excesso segurado (13 a 18) lêem como teatro de boneco "duro" de propósito.
- **Chita.** A estampa grande, com contorno escuro e miolo de bolinhas, carrega identidade nordestina sem citar personagem real.
- **Papel em xilogravura com goiva e registro deslocado.** Ninguém confunde com textura de pacote.
- **Tolda de chita** (empanada embaixo, bambinela em cima): enquadra o palco como o mamulengo, em que o boneco brinca acima do pano ([Revista Móin-Móin, UDESC](https://revistas.udesc.br/index.php/moin/article/download/1059652595034701032007016/7981/40896); [Revista Mamulengo nº 16, ABTB/CBTIJ](https://cbtij.org.br/wp-content/uploads/2020/06/cbtij-revista-abtb-cub-mamulengo-16-2020.pdf)).

O que ainda denuncia "feito por script" e precisa de trabalho:

1. **Cabeça cilíndrica empilhada sobre pescoço em anel**, que lê como totem. Falta queixo, testa e nariz com intenção de escultura. Corrigir com perfil por curva (silhueta de frente e de lado), não com cubo e "cast".
2. **Mão em luva e manga em tubo**: genéricas.
3. **Contorno fino demais** no 3D (cerca de 1,5 a 2,5 px no palco), comparado ao sprite do Cycles.
4. **Uma única "cara"**: todos os heróis compartilham a mesma cabeça. Variar a forma da cabeça por jogador, não só o chapéu.
5. **A espada atravessa o chão** no excesso (quadros 13 a 17). O pivô e o ângulo da arma precisam de limite ou de IK com o chão.

Para comparação com a mesma lógica de "boneco no palco": Puppeteer (Sony, 2013) usou câmera de palco fixa, troca de cenário à vista e iluminação teatral. Ganhou indicações ao D.I.C.E. em animação e direção de arte ([Wikipedia](https://www.wikipedia.org/wiki/Puppeteer_(video_game)), [Kill Screen](https://www.killscreen.com/puppeteer-shows-you-its-strings-and-gives-you-scissors/)). Tearaway, da Media Molecule, fez o papel se comportar como papel (vinco, dobra, rasgo) em vez de ser só "pouco polígono", e assumiu a imperfeição ([VentureBeat](https://gamesbeat.com/tearaway-is-a-love-letter-to-paper/), [Game Developer](https://gamedeveloper.com/design/how-i-tearaway-i-s-emphasis-on-imperfection-made-the-game-more-personal)). As duas lições valem aqui.

### 3.2 Paridade Compatibility × Forward+ [teste]

| Cena | Diferença média (0 a 255) | Pixels com diferença > 8 |
|---|---|---|
| duelo, palco | 1,53 | 3,09% |
| duelo, camarote | 1,36 | 1,83% |
| duelo, alta | 1,28 | 1,61% |
| estresse, palco | 1,90 | 5,93% |
| estresse, camarote | 1,63 | 4,29% |
| estresse, alta | 1,52 | 3,90% |

A diferença se concentra no papel de seda (mistura alfa) e nas bordas do MSAA 2×; o mapa ×8 está em `folha3_variantes.png`. A paridade existe por construção: luz sem sombra, ambiente preto, tonemapper linear, cenário unshaded e toon no `light()`. Isso confirma a "regra prática" do relatório de direção de arte: estilizar no material.

**Desempenho, apenas relativo** (renderer por software, não é jogável):

| Cena | Draw calls | Primitivas | Compatibility | Forward+ |
|---|---|---|---|---|
| duelo | 37 a 39 | 13,5 mil | 77 a 101 ms | 103 a 135 ms |
| estresse (24 bonecos, 3 explosões) | **153 a 155** | 78 mil | 106 a 141 ms | 159 a 172 ms |

O estresse passa do teto de 100 a 150 draw calls para a Web proposto no relatório de render. A conta: 72 vêm dos bonecos, 24 das sombras e cerca de 54 dos retalhos de seda, um quad por draw. Com as sombras e os retalhos em `MultiMeshInstance3D` (ou partículas), a cena cai para cerca de 80 [estimativa, não medido].

### 3.3 Câmera: palco, camarote ou alta [teste + opinião]

Altura em pixels de cada personagem e contraste de luminância (ΔL OKLab entre a mediana do personagem e um anel de fundo de 6 px; mais alto é melhor; abaixo de 0,10 é fraco):

| Câmera (estresse, Compatibility, tinta em hierarquia) | Herói em 720p | Herói na miniatura 320×180 | Inimigo na miniatura (mediana) | ΔL heróis (mín./med.) | ΔL inimigos (med.; n < 0,10) | Borrão 4 px: ΔL inimigos (med.; n < 0,10) |
|---|---|---|---|---|---|---|
| Palco (fov 26°, inclinação 7°) | 188 a 201 px | 47 a 50 px | 43 px | 0,095 / 0,127 | 0,143; 3 de 19 | 0,120; **9 de 19** |
| Camarote (fov 30°, 38°, 15,5 m) | 116 a 155 px | 29 a 38 px | 32 px | 0,030 / 0,112 | 0,290; 1 de 18 | 0,177; 1 de 18 |
| Alta tipo Magicka (fov 30°, 55°, 16 m) | 99 a 133 px | 24 a 33 px | 24 px | 0,024 / 0,073 | 0,267; 0 de 18 | 0,182; 0 de 18 |

Leitura:

- **Palco** dá o maior personagem e o melhor rosto. Mas a faixa de profundidade de 6 m comprime os 20 inimigos numa parede: inimigos na frente cobrem heróis (o P4 roxo quase some) e 9 de 19 inimigos perdem o contraste no borrão. Para palco, o projeto teria de limitar a cerca de 6 a 10 inimigos ativos, à moda de Castle Crashers e Lost Castle 2, que são side-scrollers 2D/2,5D ([Softpedia](https://www.softpedia.com/reviews/games/pc/lost-castle-2-review-538185.shtml)), e usar X-ray por stencil. Uma resenha de Castle Crashers diz que com 4 jogadores a tela "fica avassaladora" ([Giant Bomb](https://giantbomb.com/reviews/castle-crashers-review/1900-51/)).
- **Alta** separa melhor os inimigos, mas o herói vira o chapéu: no sprite e no 3D, a aba de palha cobre o rosto (`folha4_boneco.png`, linha do sprite em vista alta). Os heróis têm o pior ΔL (0,073). A câmera compartilhada do Magicka 2, que não dá zoom, é criticada por perder jogadores na borda ([PC Gamer](https://www.pcgamer.com/magicka-2-review/), [God is a Geek](https://godisageek.com/reviews/magicka-2-review/)).
- **Camarote** fica com o melhor dos dois:
  - telão, recortes e casa continuam no quadro, então o "teatro" se mantém;
  - inimigos legíveis: ΔL mediano 0,29, só 1 abaixo de 0,10;
  - heróis com 116 a 155 px.

  Custa perder a tolda (a empanada sai do quadro) e mostrar os cantos da arena, que é só alargar o telão.

**Sugestão de design** [opinião]: câmera camarote em combate, com zoom dinâmico pelo centro do grupo (técnica de [Game Developer, "Single camera system for four players"](https://gamedeveloper.com/programming/single-camera-system-for-four-players)), e **câmera de palco nas cenas de diálogo, loja e chefe**. Essa troca é a própria linguagem do teatro de bonecos.

### 3.4 3D toon × sprite pré-renderizado [teste]

| Critério | 3D toon no motor | Sprite do Cycles em `Sprite3D` |
|---|---|---|
| Visual medido | contorno de 1,5 a 2,5 px, MSAA 2× | contorno mais grosso e limpo, AA por 16 amostras; levemente mais "acabado" |
| Custo de produção | 1 GLB de 0,3 MB por boneco, qualquer ângulo | 0,3 s por quadro × 8 direções × quadros × animações × 4 variantes de jogador. Ex.: 8 × 24 × 6 × 4 ≈ 4.600 quadros ≈ 23 min por rodada, além da memória de textura |
| Câmera | troca palco/camarote livre | um conjunto de sprites por inclinação de câmera |
| Luz e relevo | luz do jogo (um sol), sombra em degrau | sombra congelada no ângulo do render |
| Draw calls | 3 por boneco | 1 por boneco |
| Risco | contorno fino e skinning em pano | cintilação de texel em perspectiva (relatado no fórum do Godot, ver relatório de render) |

**Escolha: 3D toon.** Antes de decidir de vez, vale engrossar `px_width` para cerca de 2,5 e testar MSAA 4× ou FXAA na Web [não testado aqui]. O sprite do Cycles continua útil para retratos, cartazes e a interface.

---

## 4. Portões do contrato de 12 regras (estresse, camarote, Compatibility)

| Regra / portão | Resultado | Passa? |
|---|---|---|
| 1. Paleta de no máximo 24 cores | **51** hexadecimais distintos no código (muitos quase iguais: 4 madeiras, 3 brancos, 3 tons de terra) | **Não**: consolidar numa paleta mestra em OKLab |
| 5. Uma espessura de traço com ±20% | casca no Blender + pixels de tela no Godot + pressão por hash | Sim |
| 6. Uma luz-chave, sombra de uma cor | sol (−4, 8, 6), sem sombra; sombra = × (0,62; 0,50; 0,64) | Sim |
| 7. Imperfeição com semente | facetas ±1,2%, borda fBm, registro 1 a 2 px, falha de tinta | Sim; "fervura" do traço a 6 a 8 fps não feita |
| 10. Nenhum valor padrão à vista | ambiente, tonemap, céu, materiais e sombras definidos por script | Sim |
| 11. Taxas de animação decididas uma vez | personagem em 12 poses por segundo (2s, STEP), motor livre | Sim |
| 12a. Teste de cinza | inimigos: mediana 0,29. **Heróis: mín. 0,030, mediana 0,112** | Inimigos sim; **heróis no limite** |
| 12b. Teste de borrão (4 px) | inimigos 0,177; **heróis 0,054 (3 de 4 abaixo de 0,10)** | **Heróis não**: lêem pelo contorno e pela cor, não pela massa de valor |
| 12c. Miniatura 320×180 | heróis com 29 a 38 px, inimigos com 32 px; heróis ainda se distinguem pelo chapéu e pela cor | Sim |
| 12d. Daltonismo (Machado 2009, severidade 1,0) | separação de classe herói × inimigo mantida (ΔE de 0,078 a 0,099). **Entre jogadores: ΔE mínimo de 0,055 (normal), 0,006 (deuteranopia), 0,025 (protanopia)**. O papel de seda também vira amarelo, igual aos heróis | **Não para cor de jogador**: o chapéu salva, mas falta marcador |
| Orçamento HSV da seção 7.2 | fundo V 84% (alvo 25 a 55%); heróis V 78%, S 59% (alvo V 50 a 85, S 55 a 80: ok); inimigos V 47%, S 48% (alvo V 35 a 70, S 30 a 55: ok) | **O fundo viola, porque papel é claro por natureza**: reescrever a regra para esta direção |

As matrizes de daltonismo foram conferidas no código do colour-science (`colour/blindness/datasets/machado2010.py`, baixado do GitHub). Fontes do método: [UFRGS, Machado, Oliveira e Fernandes](https://www.inf.ufrgs.br/~oliveira/pubs_files/CVD_Simulation/CVD_Simulation.html) e [documentação do colour](https://colour.readthedocs.io/en/latest/_modules/colour/blindness/machado2009.html). O ΔE "médio" por personagem é uma métrica grosseira, porque a chita é multicolorida. Use-a para comparar variantes, não como valor absoluto.

### 4.1 Variantes de tinta e chão (estresse, Compatibility)

| Variante | Palco: ΔL inimigos (med.; n < 0,10) | Alta: ΔL heróis (med.; mín.) | Alta: ΔL inimigos (med.; n < 0,10) | Leitura |
|---|---|---|---|---|
| Tudo em tinta preta (cordel puro) | 0,135; **8 de 19** | 0,073; 0,006 | 0,266; 0 | morros pretos atrás dos inimigos escuros: o cenário compete com o personagem |
| **Hierarquia de tinta** (fundo #A39C8C, meio #5F5C50, chão terra #9C8670; preto só nos bonecos) | 0,143; 3 de 19 | 0,073; 0,024 | 0,267; 0 | **a melhor no geral** |
| Chão de papel pardo (V 53%) | 0,096; **11 de 19** | **0,158**; 0,008 | 0,026; **18 de 18** | heróis saltam, inimigos somem |

Conclusão [teste + opinião]: o valor do chão precisa ficar **entre** o dos heróis e o dos inimigos, e longe dos dois. A gravura em várias matrizes (fundo em tinta clara, primeiro plano em preto) é o jeito "de processo físico" de criar a profundidade de valor. É também a resposta para a seção 7.2.

---

## 5. Achados técnicos novos (para o pipeline)

| # | Achado | Números | Consequência |
|---|---|---|---|
| 1 | Cor de vértice no Compatibility 4.7.2 chega ao shader escurecida (sRGB→linear aplicado de novo) | #E0B54A: Compatibility (190,117,13), Forward+ (224,180,73). Com `StandardMaterial3D`, uniforms e unshaded: idêntico | Ramo `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY` que reconverte para sRGB. Depois da correção: (224,180,73) nos dois. Não achei relato oficial; o tema próximo é luz com sombra em sRGB ([issue 88214](https://github.com/godotengine/godot/issues/88214)) [causa não verificada] |
| 2 | Blender 5.3, glTF: `export_vertex_color='ACTIVE'` não exportou `float_color` de canto criado por bmesh | sem `COLOR_0`; com `'NAME'` + `'Col'`: VEC4 normalizado em uint16 | usar `NAME` |
| 3 | `keyframe_new_interpolation_type` é ignorado por `keyframe_insert` no `bpy` | saiu `CUBICSPLINE`; com `kp.interpolation='CONSTANT'` via `action_get_channelbag_for_slot`: `STEP` | marcar as chaves explicitamente |
| 4 | Tempo das chaves no glTF = quadro ÷ fps (o quadro 1 cai em 1/24 s) | o contato (quadro 11) é t = 0,458 s, não 0,417 | ao amostrar pose no Godot, usar `f/24` |
| 5 | `GLTFDocument.generate_scene(state, 24.0)` em tempo de execução preserva STEP | as trilhas chegam com `INTERPOLATION_NEAREST` (tipo 0); 23, 21 e 21 trilhas | dispensa editar o `.import` (alternativa ao import do editor) |
| 6 | Pivô da arma: arma em repouso ao longo do braço, não para a frente | com a arma apontando para frente, as rotações do braço mandavam a lâmina para trás na guarda | regra de rig: osso da arma alinhado ao antebraço |
| 7 | Casca invertida dentro do mesmo GLB (3ª superfície), com peso no alfa | 1.500 a 1.600 triângulos a mais; funciona nos dois renderers e no Cycles (mesma geometria, sem `Solidify`) | uma fonte de contorno para motor e sprite |
| 8 | Voronoi de chão sem distância mínima gera "células pretas" | corrigido com amostragem com rejeição (95 px) | regra de geração |

---

## 6. Ranking revisto (só as duas direções testadas) [opinião baseada nas imagens]

O relatório de direção de arte deu 4,60 ao cordel em papel e 4,40 ao mamulengo, sem imagem. Depois da prova:

| Critério | Nota | Justificativa medida |
|---|---|---|
| Esconde ou valoriza a modelagem procedural | 5 | articulação rígida e facetas transformam a limitação em estilo |
| Identidade e distância do slop | 4 | chita, tolda e goiva são fortes; a cabeça ainda é genérica |
| Legibilidade com 4 + 20 | 3 (palco) / 4 (camarote) | inimigos ótimos; heróis falham no borrão e no daltonismo |
| Viabilidade no Compatibility | 5 | paridade de 1,3 a 1,9/255 |
| Custo e risco | 4 | o pipeline inteiro roda em segundos; sem sprites |
| Teto no Forward+ | 3 | o estilo não usa os extras; o Forward+ não acrescenta nada aqui |

Média ponderada com os pesos do relatório (25/20/15/15/15/10), na versão camarote: 0,25·5 + 0,20·4 + 0,15·4 + 0,15·5 + 0,15·4 + 0,10·3 = **4,30**. A fusão "teatro de cordel" se sustenta com imagem.

---

## 7. Recomendações (próximas iterações da prova, em ordem)

1. **Adotar a câmera camarote** (38°, fov 30°, zoom pelo centro do grupo) no combate e o palco frontal em diálogo e chefe. Atualizar os relatórios de rede e de referência, que assumem 55°.
2. **Hierarquia de tinta como regra do cenário**: fundo em tinta clara, meio em tinta média, chão em tinta de terra de baixo contraste, e preto só em personagem, contorno e aviso. Reescrever a seção 7.2: papel V 75 a 90%, heróis com massa escura no pé, inimigos V 30 a 50%.
3. **Dar massa de valor aos heróis**: barra escura no vestido e meia de cor escura, ou chita de fundo médio-escuro com flor clara, para passar no borrão (alvo: ΔL ≥ 0,12). Mais o marcador de jogador no chão em forma distinta (círculo, quadrado, triângulo, losango), que resolve o daltonismo (hoje o ΔE entre jogadores cai a 0,006).
4. **Matiz reservado para o VFX do jogador ≠ amarelo dos heróis.** Em deuteranopia o papel de seda e as chitas viram o mesmo amarelo; usar magenta e ciano como seda do jogador e laranja-vermelho só no aviso inimigo.
5. **Paleta mestra de 24 cores em OKLab** num único `paleta.py` lido por `tex.py`, `boneco.py` e pelos shaders. Hoje são 51 hexadecimais.
6. **Cabeça por perfil**: curvas de silhueta de frente e de lado, revolvidas e talhadas; queixo e testa com intenção; 3 ou 4 formas de cabeça por arquétipo. Testar mão de 3 dedos em bloco.
7. **Contorno em ~2,5 px** e MSAA 4× ou FXAA no Web, para chegar ao acabamento do sprite do Cycles.
8. **Produção em `MultiMesh`** para sombras e retalhos de seda (de cerca de 155 para cerca de 80 draws).
9. **Secundário por mola** no chapéu, na saia e nas fitas (`SpringBoneSimulator3D` ou código), mantendo a pose segurada no corpo. A animação já reserva os ossos `hat` e `skirt`.
10. **Limite de inimigos ativos** de 8 a 12 em palco, se o palco for usado em arena; X-ray por stencil sempre ligado.

---

## 8. Fontes consultadas

- Mamulengo, construção em mulungu e chita: [Revista Móin-Móin (UDESC)](https://revistas.udesc.br/index.php/moin/article/download/1059652595034701032007016/7981/40896); [Revista Mamulengo nº 16 (2020)](https://cbtij.org.br/wp-content/uploads/2020/06/cbtij-revista-abtb-cub-mamulengo-16-2020.pdf); [Revista Pesquisa FAPESP, teatro de bonecos (PDF)](https://revistapesquisa.fapesp.br/wp-content/uploads/2025/09/082-085_teatro-de-bonecos_355.pdf).
- Puppeteer: [Wikipedia](https://www.wikipedia.org/wiki/Puppeteer_(video_game)), [Kill Screen](https://www.killscreen.com/puppeteer-shows-you-its-strings-and-gives-you-scissors/), [Digital Trends](https://digitaltrends.com/gaming/exclusive-interview-puppeteer-for-playstation-move-has-players-pulling-the-strings).
- Tearaway: [VentureBeat](https://gamesbeat.com/tearaway-is-a-love-letter-to-paper/), [Game Developer](https://gamedeveloper.com/design/how-i-tearaway-i-s-emphasis-on-imperfection-made-the-game-more-personal), [Game Informer](https://gameinformer.com/b/news/archive/2013/03/28/media-molecule-talks-about-crafting-the-world-of-tearaway.aspx).
- Câmera co-op: [Game Developer, câmera única para 4 jogadores](https://gamedeveloper.com/programming/single-camera-system-for-four-players); [Giant Bomb, belt scrolling](https://giantbomb.com/wiki/Concepts/Belt_Scrolling); [resenha de Castle Crashers](https://giantbomb.com/reviews/castle-crashers-review/1900-51/); Magicka 2: [PC Gamer](https://www.pcgamer.com/magicka-2-review/), [God is a Geek](https://godisageek.com/reviews/magicka-2-review/); Lost Castle 2: [Softpedia](https://www.softpedia.com/reviews/games/pc/lost-castle-2-review-538185.shtml), [Game8](https://game8.co/articles/reviews/lost-castle-2-review-early-access).
- Toon e contorno no Godot: [hexaquo, light shader](https://hexaquo.at/pages/understanding-godot-light-shaders-and-light-calculations-by-implementing-a-toon-light-shader/); [fórum Godot, toon com light()](https://forum.godotengine.org/t/tutorial-about-toon-shading-and-the-light-function-in-shaders/135038); [EXPWorlds/Godot-Cel-Shader](https://github.com/EXPWorlds/Godot-Cel-Shader); doc oficial 4.7 `spatial_shader.rst` (lida pelo repositório godot-docs, branch 4.7); diferenças entre renderers: [issue 88214](https://github.com/godotengine/godot/issues/88214), [fórum](https://forum.godotengine.org/t/how-to-minimize-the-visual-difference-between-rendering-backends/57945).
- Daltonismo: [Machado et al. 2009 (UFRGS)](https://www.inf.ufrgs.br/~oliveira/pubs_files/CVD_Simulation/CVD_Simulation.html); matrizes de `colour-science/colour` no GitHub (BSD-3-Clause [não verificado neste relatório; ver LICENSE do repositório]).

Nada novo foi baixado para o jogo. Só foi lido o arquivo de matrizes do colour-science. Godot 4.7.2 e Blender 5.3 já estavam no ambiente.

---

## 9. Pontos em aberto

- Desempenho real na Web e no celular: tudo aqui roda em renderer por software. Os 153 draws precisam ser medidos num celular de verdade [não verificado].
- A causa exata da cor de vértice escurecida no Compatibility (motor ou importador `GLTFDocument` em tempo de execução). Não testei o mesmo GLB pelo importador do editor [não verificado].
- O ΔL de mediana é uma métrica proxy; falta teste com pessoas (inclusive daltônicas).
- A opinião de "não parece slop" é minha. **Quem decide é o usuário, olhando as 4 folhas.**
- Movimento: as capturas são quadros parados. O ciclo de ataque em 2s não foi visto em vídeo (o Movie Maker do Godot funciona aqui, segundo o relatório de render).
- Cuidado cultural: o mamulengo é patrimônio vivo (Teatro de Bonecos Popular do Nordeste). Vale crédito e consulta, e nenhum personagem tradicional foi copiado.

# Prova de estilo: Cacos de Cobalto ("Condução no Cais da Salga")

Feita em 27/11/2026 (rodada 2 no mesmo dia, depois da crítica independente; a rodada 1 está guardada em `entrega/v1/`), toda gerada por código: Blender 5.3 (`bpy`) para modelos, rig, poses e atlas, numpy para pincel e estampilha, e Godot 4.7.2 para cena, shaders, efeitos e captura. Não usei asset baixado. É uma cena de demonstração, não o jogo.

## Entregas (rodada 2)

| Arquivo | O que é | Renderer | Tempo de render (CPU, lavapipe/llvmpipe) |
|---|---|---|---|
| `beauty.png` | 1920×1080, câmera de combate (perspectiva de 30°, inclinação de **45°** (era 40°), zoom de grupo a 11,2 m), sombra real, glow, reflexo do molhado, profundidade de campo leve, supersample 2× | Forward+ | 58 s (CPU dividida com outro render; 26 quadros de pré-rolagem para as molas, 133 draw calls) |
| `stress.png` | 1280×720, câmera de camarote a **13 m** (era 16 m) e 44°: 4 heróis com anel e símbolo, 20 inimigos, Condução, Incêndio e Lufada ao mesmo tempo | Compatibility | 5 s (119 draw calls) |
| `clip.mp4` / `clip.gif` | 4,35 s a 60 fps, 1280×720 (MP4 de 4,6 MB; GIF de 640 px a 15 fps, 3,7 MB) | Forward+ (Movie Maker, `--fixed-fps 60`) | 216 s para 262 quadros (0,82 s por quadro; a película de reflexo custa uns 25%, e a CPU estava dividida) |
| `modelo.png` | 4 heróis, a Lasca nova e a Crosta de frente, 3/4 e perfil (heróis na espera); 9 poses-chave do golpe da Lamparina; 5 do arremesso de cal do Bento | Forward+, ortográfica | cerca de 3 a 5 s por folha parcial |
| `portoes_stress.png` / `.json` | portões de cinza, borrão, miniatura e daltonismo sobre o `stress.png` | — | 3 s |
| `v1/` | as entregas da rodada 1, intactas, para comparar | — | — |

O que acontece no clipe é o gancho co-op do conceito, "eu preparo o chão, você detona, e o mesmo sistema que machuca também protege":

1. Bento sai do contraposto (rodo no ombro) e joga o balde. A cal voa em gotas **brancas e leitosas, com borda verde-cobre**, e o chão molha azulejo por azulejo, a partir de onde cai. Cada gota que pousa levanta um sopro de pó de cal.
2. Uma Lasca telegrafa contra ele: agacha, acende o miolo de terracota em vermelho-lacre, e o retângulo fino enche da base para a ponta.
3. Tia Lamparina gira a lamparina. O corpo inteiro inclina e gira como bloco; na descida o quadril sai 2 quadros antes do peito e da cabeça. No smear, 3 fantasmas da lanterna ficam ao longo do arco por 2 quadros. Na soltura há hit-stop de 3 quadros, **tremor seco de 3 px** e brasas incandescentes pequenas saindo da lanterna.
4. A faísca voa em parábola (miolo quente com 3 arcos curtos, não estrela), com sombra-bolha no chão, e cai na poça: 1 quadro de lampejo, o azulejo **racha** em linha de tinta com a fenda acesa de antimônio, e cacos do esmalte saltam e assentam.
5. A Condução corre **pelas juntas**: em linha reta na junta corrida e em zigue-zague, mais devagar, na amarração.
6. Cada Lasca atingida leva hit-stop local de 5 quadros: 1 quadro de **silhueta branca**, 2 de negativo amarelo, rachadura que se abre sobre ela, 8 estilhaços vidrados com miolo de terracota (ease-out, gravidade, quique seco, dissolve por ruído). Depois vem o recuo, os cacos soltos caem e a queda levanta pó.
7. O Bento está untado (esmalte molhado: janela de brilho maior e filete âmbar duro). O choque chega no pé dele e contorna. Ele dá um pulo de susto, levanta pó de cal ao pousar e depois faz pose de esnobe.
8. O avental, a saia, a lanterna, o balde, o chapéu e o lenço chegam depois do corpo, por osso de mola simulado no motor. O chão molhado reflete os personagens.

## Rodada 2: o que mudou por causa da crítica

A crítica independente da rodada 1 deu 7 em "não parece slop", 6,5 em apelo, 4 em legibilidade com 4 jogadores e 4,5 em VFX, com 11 correções. Apliquei na ordem de prioridade:

| # | Problema | O que fiz | Estado |
|---|---|---|---|
| 1 | Heróis, inimigos e cenário na mesma paleta | Piso e parede: padrão misturado ao estanho em 50% (parede 45%) e mais ainda ao fundo (até 72%, `pat_far`); o padrão do chão agora fica entre 0,75 e 0,9 de valor. **Peça de vidrado na cor do jogador** trocada no shader por região do atlas (lenço e faixa da cintura da Lamparina, chapéu do Bento, pás do cata-vento da Nina, boné e garrafa do Galvão), mais rim duro na cor do jogador. Inimigos ganharam **terracota crua** (miolo dos cacos) e **salitre branco-esverdeado**, que nenhum herói usa | Feito |
| 2 | Contorno arco-íris do untado | Saiu o fresnel com matiz. Rim de cor única na cor do jogador, corte duro, só do lado oposto à luz. O brilho do esmalte virou **decalque de janela de 4 vidraças** que segue a normal, com limiar duro. O untado agora é "esmalte molhado": janela 60% maior e filete âmbar duro do lado da luz | Feito |
| 3 | Estrela de impacto de clip-art | Estrela removida de todas as entregas. Novo impacto de caco (`racha`, `caco_fx`, `po`): 1 quadro de lampejo (silhueta branca no alvo, estouro branco no chão), fenda angulosa em linha de tinta que abre em 2 a 3 quadros com a matéria acesa dentro, e 6 a 10 estilhaços quadrados vidrados (branco por fora, biscoito ou terracota por dentro) com ease-out, gravidade e dissolve por limiar de ruído. Por matéria: Faísca com fenda amarela e arcos, Brasa com brasas incandescentes, Cal com pó branco em flipbook | Feito |
| 4 | Poça verde de lodo | Nenhuma camada verde. O esmalte molhado escurece uns 20% e puxa para o azul do céu; a borda é uma **linha de tinta ondulada** (ruído na máscara) com **franja de cal branca** granulada por fora. No Forward+, uma película faz **reflexo em espaço de tela** dos personagens (ver achados técnicos). A eletricidade no rejunte ficou como estava | Feito; no Compatibility não há reflexo |
| 5 | Vermelho sobrecarregado | Telegrafia com linha fina (meia largura de 2,2 cm, uns 8 px a 1080 na câmera de combate), preenchimento que cresce do centro (círculo) ou da base (retângulo) com alfa 0,25 e frente de onda, sem dentes nem hachura. A Crosta não acende mais os cristais em vermelho; os cristais são de salitre branco-esverdeado | Feito |
| 6 | Câmera longe, anel branco do P4, arcos da Nina | Câmera de estresse de 16 para 13 m (−19%) e de 40° para 44°. Cabeças 20 a 25% maiores (`head_xf` no construtor; o rosto escala junto). **P4 virou verde-lima `#9BE03C`**, não amarelo-ouro (ver abaixo). Anéis com contorno escuro de uns 3 px a 720p. Arcos da Lufada na cor do jogador, com alfa decrescente, desenhados antes dela (`render_priority −1`) e só atrás e dos lados | Feito, menos o limite de zoom-out dinâmico, que só existe no jogo |
| 7 | Lascas como entulho de pedra | Remodelada como **pilha de cacos de azulejo vidrados**: mais alta que larga (0,85 m), inclinada para o alvo, vidrado dos dois lados (frente de barra azul-noite e verso de losango claro), bordas chanfradas em terracota, olho de painel fora do lugar na cabeça, salitre branco-esverdeado nas quebras. A sombra dos inimigos virou mancha mais escura com **borda quebrada em cacos** | Feito |
| 8 | Fogo de triângulos | Reescrito: língua em gota com barriga e ponta em S enrolada, contorno de cobalto, ocre e laranja-ferro em pinceladas no sentido da chama, flipbook de 4 quadros a 12 fps, fase própria por instância. Base em brasa: chão chamuscado com veios que respiram (ruído animado) e borda dura | Feito |
| 9 | Bento fraco | Pescoço 30% mais curto, cabeça 25% maior, ombros mais estreitos, **chapéu de jornal com aba larga** (mais largo que os ombros, silhueta de cravo) inclinado 12°. Espera em **contraposto** (peso na perna esquerda, quadril deslocado, ombros no contra) com o rodo na diagonal apoiado no ombro; o ângulo do rodo saiu de uma busca numérica (`rodosearch.py`) | Feito |
| 10 | Animação dura | Golpe da Lamparina refeito com o corpo como bloco: tilt de 10 a 16° do quadril na antecipação e giro defasado (quadril no quadro 13, peito no 17, cabeça no 19). Smear com 3 malhas-fantasma da lanterna por 2 quadros e um traço fino do cabo seguindo a curva (saiu o leque marrom). Tremor seco de 3 px com o hit-stop da soltura. Pó de cal no pouso do Bento, na queda das Lascas e nas gotas | Parcial (ver o que ainda é fraco) |
| 11 | Parede compete com a ação | AO pintado na base da parede (−20% nos últimos 32 cm, em 3 degraus de aguada), faixa de losangos com 55% menos saturação, padrão da parede misturado ao estanho. Câmera do beauty de 40° para 45° | Parcial: a parede ainda ocupa cerca de 1/4 do beauty, porque a 48° a placa "RUA DA SALGA" saía do quadro e ela é o detalhe mais convincente |

**Por que lima e não amarelo-ouro no P4.** O conceito tem a regra "se tem cor quente, interage": anel de jogador não pode usar cor de matéria. O amarelo-ouro brigaria com a Faísca, e a Condução acende o rejunte de amarelo justamente embaixo dos anéis. O lima não é cor de matéria, contrasta com o piso claro e mantém os mínimos de ΔE entre anéis em visão normal, protanopia e deuteranopia. O custo: em tritanopia, ciano × lima caiu de 0,185 para 0,10, e em protanopia e deuteranopia o lima vira um amarelo parecido com a Faísca. O símbolo (losango) continua sendo a garantia.

**Comparação com a rodada 1, olhando as imagens.**
- *Beauty.* Saíram o contorno arco-íris, as estrelas, a poça verde e o vermelho nos cristais. Bento lê como personagem, não como manequim, e aparece refletido na poça. Os heróis se separam do chão pelo valor e pela cor do jogador. A cena ficou mais clara e mais calma.
- *Estresse.* Os 4 heróis se acham num relance pela peça colorida (lenço, chapéu, pás, boné), não só pelo anel. O fogo virou pintura. As Lascas leem como ameaça pequena e não como pedra.
- *Clipe.* Tem lampejo, fenda e estilhaço no lugar da estrela, pó de cal e corpo girando.
- *Folha de modelo.* Os heróis estão na pose de espera, e a Lasca nova ganhou uma linha.
- *Regressões que vi e corrigi no caminho.* Chapéu do Bento como "caixa ciano" (ganhou aba), rachadura com cara de aranha (miolo removido, fenda acesa domina), pó de cal que não sumia no clipe (bug de índice), lampejo de 5 quadros (agora é 1), Lasca cortada e Crosta sobreposta na folha.

## O que foi feito

- **Pincel e estampilha** (`pincel.py`, `texturas.py`). O traço tem carga de tinta: começa carregado, afina, seca e deixa uma poça de pigmento no fim. A aguada tem estrias na direção do pincel e acúmulo na borda. O molde vazado tem erro de registro de 1 a 2 px por cor. A granulação é leve e a borda é irregular.
  - A cor sai de uma rampa de 3 valores de cobalto mais o estanho, sem degradê liso.
  - Padrões gerados: losango de laçaria (piso), folha em quadrante 2×2 (parede), barra azul-noite, friso de corda e um painel figurativo de 2×1 m, "barco na tempestade", composto por uma biblioteca de motivos (nuvem, onda, barco, gaivota, chuva, raio).
  - A placa "RUA DA SALGA" é pintada a pincel com letras definidas por traço. Não usei fonte.
- **Figuras de faiança** (`geo.py`, `herois.py`, `inimigos.py`, `props.py`).
  - Cada figura é feita de peças rígidas por osso: louça não estica, e o "comprimir" fica no pano por mola.
  - Os volumes vêm de loft por perfil (seção superelíptica com frente e costas diferentes). As cabeças são desenhadas por perfil: bochecha larga na Lamparina; queixo e nariz longos no Bento.
  - As mãos são luvas de 3 dedos com polegar, fechadas no cabo.
  - O contorno é uma casca invertida gerada no Blender, com espessura de **2,75 px a 1080 linhas e pressão de ±20%**, constante em tela por uniform da câmera.
  - Atlas de 1024 px pintado por peça. Heróis em negativo: esmalte azul-noite pintado de branco, pele e avental em reserva branca, um acento na cor da matéria.
  - Inimigos são cacos com espessura real: frente pintada, borda de terracota crua, cristais de salitre branco-esverdeado (a Lasca é vidrada dos dois lados; Crosta e Ladrilheiro mantêm o verso de argamassa). O Ladrilheiro tem o rosto de um painel remontado errado, com azulejos trocados, girados e faltando.
  - Triângulos com casca: heróis de 7,1 a 10,9 mil; Lasca 1,2 mil; Crosta 3,0 mil.
- **Shaders** (`proj/shaders/`).
  - `figura`: toon de 2 degraus por `light()`, sombra que multiplica por cobalto, brilho em janela de 4 vidraças, rim duro na cor do jogador, peça de vidrado na cor do jogador por região do atlas, rosto de 3 traços com olhos, boca e sobrancelha por parâmetro, esmalte molhado do untado, negativo, lampejo e vermelho-lacre só no miolo de terracota. (A rodada 1 tinha furta-cor do óleo no corpo; saiu.)
  - `piso`: assentamento com erro de ±1 mm e ±0,8°, rejunte real e inclinação do esmalte por peça (mosaico de brilho que some com a distância). Estados do chão por forma: molhado com escurecimento, ondulação, linha de tinta ondulada e franja de cal (sem verde); óleo com borda furta-cor; queimado com craquelado de Voronoi; salitre granulado. A Condução lê uma textura de chegada por segmento de junta.
  - `parede`, `mar` (ondas a pincel "fervendo" a 8 fps), `marca` (anel e símbolo do jogador, telegrafia que se fecha, sombra), `raio` (fita com núcleo, corpo e borda azul-noite quebrada), `fogo` (língua de fogo pintada em flipbook de 4 quadros a 12 fps), `racha` (lampejo e fenda), `caco_fx` (estilhaço vidrado), `po` (pó de cal), `faisca` (faísca em voo), `reflexo` (película de reflexo do molhado). O `estrela` ficou no projeto, sem uso.
- **Condução pelo rejunte** (`cena.gd`). É um Dijkstra no grafo das juntas, com custo menor para seguir reto e bloqueio onde está seco. Na amarração as juntas horizontais são desencontradas, então o choque desce em escada, mais devagar. Trilhas principais até as vítimas ficam mais fortes.
- **Animação** (`anims.py`, `fig.gd`, `clip.gd`).
  - Chaves CONSTANT a 60 fps feitas no Blender. Heróis em pose a pose (golpe da Lamparina em 9 poses-chave, com o corpo girando como bloco, segurando o extremo da antecipação). Inimigos em 3s.
  - O motor cuida do resto: hit-stop local (a animação anda só 8% durante a pausa), molas com limite de 75°, smear com fantasmas da lanterna, rastro de arco, tremor por trauma² (que continua durante o hit-stop), recuo com desaceleração exponencial e troca de expressão por evento.
  - Os ângulos da lamparina foram acertados por busca numérica (`posesearch.py`) para o giro passar **por fora do corpo**, legível de cima.

## Portões no `stress.png` (Compatibility)

Rodada 2 (a rodada 1 entre parênteses). A câmera chegou 19% mais perto, então os heróis também ficaram maiores na tela.

| Portão | Heróis (4) | Inimigos (18 visíveis de 20) |
|---|---|---|
| Cinza, ΔL OKLab contra anel de 6 px | mínimo **0,338** (0,237); mediana 0,465 (0,439) | mínimo **0,165** (0,003); mediana 0,337 (0,25); **nenhum abaixo de 0,10** (1) |
| Borrão gaussiano de 4 px | mínimo **0,144** (0,108); mediana 0,21 (0,205) | mediana **0,174** (0,126); **1 abaixo de 0,10** (6): um Ladrilheiro contra a parede, com 0,091 |
| Miniatura 320×180 | 33 a 51 px de altura (28 a 41); ΔL mínimo 0,284 (0,205) | 20,5 px (16); nenhum abaixo de 0,10 (1) |
| Altura dos heróis a 720p | 135 a 204 px (110 a 161) | — |
| Daltonismo, cinza dos heróis | deuteranopia 0,371; protanopia 0,366; tritanopia 0,369 (mínimos) | — |
| Cores dos anéis, ΔE mínimo entre jogadores | normal 0,177; deuteranopia 0,115; protanopia 0,116; tritanopia **0,10** (0,185): ciano × lima | — |

Ajustes feitos por causa dos portões nesta rodada:
- A Lasca dentro do fogo (ΔL 0,03 contra a base em brasa) foi tirada de lá.
- As Lascas ganharam a frente escura de barra azul-noite (valor médio na média, contraste alto por dentro).
- O fundo do rosto do Ladrilheiro ficou mais escuro (aguada de 0,66 para 0,8).

## O que ficou bom (opinião)

- **Separação por valor e cor do jogador.** O chão virou palco claro, e cada herói carrega a própria cor numa peça grande de vidrado. No estresse, dá para dizer quem é quem pela cabeça (lenço magenta, chapéu ciano, pás lilás, boné lima) antes de olhar o anel.
- **O Bento agora tem carisma.** Chapéu de aba larga, contraposto e rodo no ombro: a silhueta de cravo lê de cima e de lado.
- **Efeitos com tema.** O azulejo que racha onde a faísca cai, os estilhaços de esmalte com miolo de terracota e o fogo pintado com contorno de cobalto conversam com o resto. Nada é estrela genérica nem bolha.
- **A Condução pelas juntas** continua sendo a imagem do jogo, agora sobre um chão molhado que reflete.
- **O negativo, a placa a pincel, o painel figurativo e o Ladrilheiro** continuam de pé.

## O que ainda é fraco (honesto)

1. **O chão ficou claro e calmo demais.** Resolveu a camuflagem, mas no beauty o piso lê como "banheiro limpo". Faltam desgaste por tráfego, manchas e variação de lote.
   - A poça no Compatibility é só uma mancha cinza com borda; o reflexo é só do Forward+.
   - O reflexo tem pequenas faixas na borda dos objetos (passo do ray-march, mesmo com refino binário).
2. **Animação ainda pose a pose e dura em partes.** O corpo gira como bloco e há defasagem, mas não há overlap nos braços nem ciclo de andar. O "spring bone na corrente" é o mesmo osso de mola da lanterna da rodada 1: não fiz uma corrente com elos. Os fantasmas do smear são caixas amarelas translúcidas, não cópias da malha da lanterna, e quase não se veem a 720p.
3. **O lampejo do impacto no chão** (estouro branco com contorno) dura 1 quadro, mas, congelado, parece um balão de fala.
4. **A rachadura sobre o alvo** às vezes lê como "estrela de linhas" quando se sobrepõe ao negativo amarelo da Lasca.
5. **As Lascas viraram figurinhas** (lembram um pinguim de cacos). Leem como inimigo, mas pouco como ameaça. Falta uma pose de bote mais agressiva.
6. **A Crosta continua blocada.** Só trocou de cores.
7. **A parede ainda ocupa 1/4 do beauty.** Escolhi manter a placa no quadro.
8. **A paleta cresceu.** São 25 cores na mestra (+terracota, +salitre esverdeado, lima no lugar do branco). Em protanopia e deuteranopia, o lima do P4 vira um amarelo próximo da Faísca. Só o símbolo de losango separa os dois.
9. Seguem da rodada 1 sem mudança:
   - o "voltar para a parede" não entrou;
   - não houve comparação do painel figurativo com azulejo real;
   - só a Lasca tem reação completa ao golpe.

## Achados técnicos novos (Godot 4.7.2)

- **Contorno por casca invertida.**
  - No `vertex()`, escrever `POSITION` **não deslocou** a casca.
  - A conta de metros por pixel com `PROJECTION_MATRIX` e `VIEWPORT_SIZE` também zerou o deslocamento: escrito com ternário ou `mix`, só a casca não aparece; cada termo sozinho funcionou.
  - Solução: deslocar `VERTEX` pela normal e passar os metros por pixel da câmera por uniform, a cada quadro.
- **Movie Maker.** Ignora `--resolution` e grava no tamanho de janela do projeto (1920×1080). Para 720p, usei uma cópia do projeto com o tamanho de janela trocado (`proj720/`). Na rodada 2, os arquivos foram copiados de `proj/` sem o `project.godot`.
- **Dijkstra em GDScript.** Com `PackedFloat32Array`, comparar a distância do heap (float64) com a guardada (float32) descarta nós. É preciso tolerância.
- **UV do loft.** A UV do loft do Blender sai com o V invertido em relação ao atlas pintado de cima para baixo. A correção está no construtor.
- **SSR com `light()` próprio (rodada 2).** Com `Environment.ssr_enabled`, `ROUGHNESS` 0,06 e até `METALLIC` 0,5 no material do piso (que tem `light()` próprio), não apareceu reflexo nenhum no llvmpipe; o metálico só acinzentou a poça. A solução foi uma película transparente sobre o piso (`reflexo.gdshader`).
  - Ela lê `hint_screen_texture` e `hint_depth_texture`.
  - Faz um ray-march de 40 passos crescentes na direção refletida, em espaço de vista, com refino binário de 5 passos.
  - É mascarada pelo mesmo mapa de molhado do piso, e a normal treme com ruído (reflexo quebrado).
  - No Compatibility ela faz `discard` por `CURRENT_RENDERER`.
  - Custa uns 25% a mais por quadro no clipe.
- **`SPECULAR_LIGHT` serve para o rim.** O rim na cor do jogador vai em `SPECULAR_LIGHT`, que não é multiplicado pelo albedo. Em `DIFFUSE_LIGHT` ele sairia escuro sobre o esmalte azul-noite. Funciona igual no Compatibility.
- **Cor do jogador sem reexportar.** O GLB leva as regiões do atlas no `_meta.json`. O shader recolore a região por luminância (modo 0: o branco vira a cor; modo 1: o azul-noite vira a cor), então qualquer herói pode ser qualquer jogador.

## Arquivos de código

Na pasta `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/provas/cacos-de-cobalto/`, cerca de 5.000 linhas no total. As renders de trabalho da rodada 2 estão em `out2/`.

- `tools/paleta.py`: paleta mestra (rodada 2: `terracota`, `salitre_v`, `p_lima`).
- `tools/pincel.py`: pincel com carga, aguada, estampilha, granulação, rampa de 3 valores.
- `tools/texturas.py`: azulejos de piso e parede, painel do barco, placa.
- `tools/pintura.py`: pintores do atlas das figuras (rodada 2: `terracota`, `salitre_v`).
- `tools/geo.py`: loft, tubo, caco, atlas, construtor com casca, poses e chaves CONSTANT (rodada 2: `head_xf` para escalar a cabeça e os ossos dela).
- `tools/herois.py`: Lamparina, Bento, Nina, Galvão (rodada 2: cabeças maiores, regiões de cor do jogador, faixa da Lamparina, Bento novo).
- `tools/inimigos.py`: Lasca (refeita), Ladrilheiro Torto, Crosta.
- `tools/props.py`: barril, cabeço com corda, caixote, rede, porta, carranca, borda do cais.
- `tools/anims.py`: clipes pose a pose (rodada 2: contraposto do Bento, golpe da Lamparina com o corpo em bloco).
- `tools/export_glb.py`: monta, pinta, anima e exporta GLB, atlas e metadados.
- `tools/posecheck.py`, `tools/posesearch.py`, `tools/rodosearch.py`: diagnóstico e busca numérica de pose.
- `tools/gates.py`, `tools/perchar.py`: portões e contraste por personagem.
- `tools/folhas.py`: folha de modelo.
- `tools/run.sh`: execução do Godot sob Xvfb.
- `proj/main.gd`: modos `beauty`, `stress` (com `mask=1` para os portões), `clip`, `sheet` (rodada 2: `anim=`, `cy=`), `poses`.
- `proj/fig.gd`: figura, hit-stop local, ossos de mola, cor do jogador.
- `proj/cena.gd`: piso, película de reflexo, parede, mar, mapas de estado, Condução pelo rejunte.
- `proj/clip.gd`: roteiro do clipe.
- `proj/vfx.gd`: fitas, marcas, rachadura, estilhaços (posição analítica), pó, faísca.
- `proj/shaders/*.gdshader`: `figura`, `contorno`, `piso`, `reflexo`, `parede`, `mar`, `marca`, `raio`, `fogo`, `racha`, `caco_fx`, `po`, `faisca` (e `estrela`, sem uso).
- `proj720/`: cópia do projeto com janela de 1280×720, usada só pelo Movie Maker.

Comandos usados (rodada 2):

- Modelos: `cd tools && python3 export_glb.py ../proj/assets` (todos em cerca de 6 s).
- Beauty: `tools/run.sh fplus out2/beauty.png 1920x1080 mode=beauty frames=26 dist=11.2 tz=-2.95 tx=-0.4 sun_el=42 lyaw=-35 ss=2 dofn=9.0 pitch=45`
- Estresse: `tools/run.sh compat out2/stress.png 1280x720 mode=stress frames=24`, e o mesmo com `mask=1`. Depois, `python3 tools/gates.py out2/stress.png out2/stress_mask.png out2/gf`.
- Folha: `mode=sheet who=<nome> anim=idle` para os heróis; `mode=poses who=lamparina anim=lancar t=1,5,9,13,15,17,19,25,41`; depois `python3 tools/folhas.py out2 out2/modelo.png`.
- Clipe: Godot `--path proj720 --rendering-method forward_plus --fixed-fps 60 --write-movie out2/clip/f.png -- mode=clip frames=262`, depois `ffmpeg` (x264 com CRF 18; GIF de 640 px a 15 fps com paleta de 128 cores).

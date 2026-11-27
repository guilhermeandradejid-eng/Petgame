# Prova de estilo: Plumbdeep, a Guilda do Prumo ("A Poça sob a Cascata"), versão 2

Esta é uma cena de demonstração no motor, não o jogo. Tudo foi gerado por código neste container: personagens, adereços, terreno, ruína, ponte, guincho, postes, o Dente, rochas, fungos, musgo e grama em bmesh e numpy (Blender 5.3 como módulo Python); cena, shaders, efeitos e animação em Godot 4.7.2. Nenhum modelo, textura ou fonte foi baixado. Não há referência brasileira ou ibérica, nem palco ou moldura.

A versão 2 aplica, pela ordem de prioridade, as 10 correções da crítica independente da versão 1. As entregas anteriores estão guardadas em `entrega/v1/`, e o código anterior está em `bak_v1/`.

## O que a crítica pediu e o que foi feito

| # | Problema apontado | O que mudou na v2 | Resultado medido |
|---|---|---|---|
| 1 | Heróis com cerca de 40 px em 1080p; o T da viga sumia | **Câmera de combate** passou de 22 m, 52° e 28° para **16 m, 46° e 28°**. A câmera de exploração do `beauty.png` passou de 28 m, 38° e 32° para **19 m, 27° e 30°**. **Ícones exagerados só no modelo de jogo** (escala de osso por cima da animação, em `boneco.gd`): viga 1,3x, chapéu-geodo 1,2x, aba da Coveira 1,4x e rosca de corda 1,2x. A folha de modelo mostra a proporção real e uma faixa com o modelo de jogo. Teste de silhueta preta em 1080p em `silhuetas.png` | Em 1080p, a caixa de cada herói, com chapéu e adereço, mede de 107 a 161 px (Escorador 161, Coveira 132, Gancheiro 127, Cristaleira 107). Na miniatura 320x180, os heróis medem de 18 a 27 px (eram de 10,5 a 17,8). **A silhueta preta passa para o Escorador (o T) e para a Coveira (aba e pá), mas não para a Cristaleira nem para o Gancheiro**: vistos de cima e de costas, o chapéu e a rosca viram um disco (veja "O que é fraco") |
| 2 | Chão de Voronoi repetido, musgo idêntico e lajes soltas | O Voronoi saiu (`placas = 0`). A pintura do terraço agora tem **causa**: acúmulo de fluxo D8 sobre a grade de alturas, com regos finos e ramificados que levam a água para a poça e para o penhasco; musgo onde é côncavo e úmido (margem dos regos, beira da poça, pé da parede); pedra seca e líquen nas lombadas; e **trilhas de terra batida** rebaixadas 4,5 cm. As lajes soltas viraram uma **ruína legível**: um piso de Thessimor em grade antiga (lajes chanfradas, 3 variantes, uma lascada e uma rachada), com borda quebrada, faltas, lajes que afundam e inclinam para dentro do **poço de um desabamento** (a descida para um Cofre), tocos de coluna octogonal e um tambor caído | O mapa de cor do terraço está em `out/mapa.png`. O musgo agora segue os regos e o pé da parede |
| 3 | Cogumelos-turquesa espalhados por igual | **9 colônias** com hierarquia (1 grande de 2,6 a 3,4 m, 3 a 5 médios, enxame de 10 a 16 pequenos), presas a umidade, fenda, parede, ruína e beira. Três estados de fungo: **inteiro, rasgado** (gomos arrancados, borda serrilhada) e **podre** (chapéu murcho e caído de um lado, haste torta, manchas). Alguns caídos ou tombados. Os chapéus perderam de 30 a 38% de saturação (`dessat` no shader de resina): o ciano pleno ficou só para a magia | — |
| 4 | Arena num platô, sem caminho, sem marcos e com chuva numa caverna | **Quatro trilhas** saem da tela (para trás da câmera, para a esquerda pela rampa da parede e para a direita pela beira). **Marcos perto:** a ponte de tronco de fungo caído sobre a fenda, com corrimão de corda; o **guincho da guilda** na beira do penhasco, com cavalete em A, lança sobre o vazio, tambor de duas manivelas, contrapeso de chumbo e jaula pendurada 9 m abaixo (é a maquinaria de dupla do conceito); a ruína com o poço; e 8 postes de lanterna ao longo das trilhas. **Marcos longe:** a Coluna do Meio-Dia, o **Dente** (estalagmite de 480 m com o mosteiro e janelas acesas) e a **Pendura de Baixo**, um povoado pendurado na parede distante com 106 janelas em quatro cachos ligados por fios de lanterna. A chuva saiu: agora há **4 cortinas de goteira** que caem de rasgos do teto, cada uma com um fio de luz fria e respingos no chão, e um gotejar esparso | — |
| 5 | VFX sem linguagem única | **Bíblia de VFX** aplicada em todos os sistemas: forma recortada, sem alfa gaussiano; 2 ou 3 tons chapados; beirada mais escura do próprio tom, como a casca dos personagens. Raios, linha do Prumo e borrão dos punhais são desenhados em três passadas (beirada escura, corpo e miolo claro), com mistura normal em vez de aditiva. Esporos, faíscas, gesso, pó, resina e nuvem de esporos são bolhas cel. A névoa (lâminas e a névoa que sobe pela beira do penhasco) virou volume cel em dois degraus, com borda dura e uma linha clara na beirada. A fumaça e o pó passaram para a paleta fria (`#808C99`). O **rastro cinza no topo do quadro 9** era o anel de névoa da frente da Respiração; ele foi removido, e a frente agora só acende fungos e grama. As linhas de ruído da Corrente na água que pareciam letras foram removidas | — |
| 6 | Raio do Cristal toma o centro e estoura o branco | Os raios começam a 0,8 m da Cristaleira, têm 60% da largura anterior, alfa de 0,85 e mistura normal. O clarão caiu de 0,7 para 0,4 e o halo âmbar de 0,8 para 0,45. **Anel do jogador sempre por cima dos efeitos:** anel grosso na cor do jogador, com beirada escura e o sinal de forma, desenhado depois de todos os efeitos (prioridade 40). **Seta sobre a cabeça** na cor do jogador, sem teste de profundidade | No `stress.png`, os 4 anéis e as 4 setas se leem por cima da Corrente |
| 7 | Ouvidores viram rabiscos; a boca magenta não aparece | Membros do Ouvidor 35 a 40% mais grossos. **Boca 2x** no Ouvidor e no Bocalume, e **isca 2x** no Bocalume. **Aresta fria pintada** (faixa recortada, sem degradê) em todos os inimigos. As orelhas ganharam material próprio (`orelha`), para piscar na telegrafia. O corpo continua escuro de propósito: o portão de cinza pede contraste contra o chão | Cinza, mediana dos inimigos: **0,174** (era 0,127) |
| 8 | Heróis com a mesma pele, o mesmo rosto e o mesmo corpo | **Proporção por classe:** Escorador atarracado e largo (1,14 × 0,93), Cristaleira alta e estreita (0,9 × 1,08), Coveira encurvada (peito, pescoço e cabeça girados para a frente) e Gancheiro magro (0,88 × 1,04). **Pele por herói:** curtida (Escorador), pálida (Cristaleira), cinza de quem vela os mortos (Coveira) e escura (Gancheiro). **Marcas:** fuligem da vela na testa e na bochecha do Escorador, olheiras fundas da Coveira e cicatriz atravessando a sobrancelha do Gancheiro. **Olhos em cavidade:** branco de osso escurecido, pupila maior, brilho menor e sombra da pálpebra sobre o terço de cima | — |
| 9 | Animação não aparece; corda reta; golpe sem impacto | **Hit-stop global** de 3 a 4 quadros (50 a 67 ms) nos dois golpes de punhal, na recepção do Prumo e em cada faísca do Enxame: a história para, mas a câmera treme e as goteiras continuam. **Corda de verlet** de 16 pontos, com catenária de verdade: frouxa no voo e no chão, esticada no puxão, com um estalo lateral que corre pela corda nos quadros 226 e 238. **Achatamento** de 0,68 nos Ouvidores no impacto das faíscas, depois esticam; esticam 1,2 quando a Corrente pega; e achatam 0,66 na queda. Com a câmera nova, as poses do Gancheiro e da Cristaleira se leem no clipe | — |
| 10 | Luz chapada, sem névoa em camadas e sem luz quente dos heróis | A luz-chave agora é **fria e direcional** (`#9FB4D0`), vinda dos rasgos do teto. **Poças de luz quente pintadas** (10 globais `lq0` a `lq9`, em 3 degraus de pincel): o geodo da Cristaleira, a isca do Bocalume, os 8 postes e o guincho. Elas saem iguais nos dois renderers e custam pouco no iPhone. **[PC]** Cada poste também tem uma `OmniLight3D` de 3,8 m, com sombra nas duas mais próximas. **Vinheta pintada** presa à câmera, que escurece e esfria as bordas. Há névoa cel subindo do abismo pela beira do penhasco | Luz real desligada contra ligada: diferença média de 3,0/255 (`luz_real_on_off.png`) |

## Entregas

Todas ficam em `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/provas-fantasia3/profundezas/entrega/`.

| Arquivo | O que é | Renderer |
|---|---|---|
| `beauty.png` | 1920×1080, quadro 62 (pico da Corrente), na câmera de exploração nova (19 m, 27°, 30°). Tem névoa volumétrica, glow, sombras, DOF fraco, as cortinas de goteira, a Coluna, o Dente, a Pendura de Baixo, a ruína, a ponte e os postes | Forward+ |
| `stress.png` | 1280×720 na câmera de combate nova: 4 heróis, 20 inimigos e 3 efeitos, com a atmosfera barata | Compatibility |
| `portoes.png` e `portoes.json` | Cinza, borrão de 4 px, miniatura 320×180, deuteranopia e protanopia sobre o estresse | — |
| `silhuetas.png` | Teste de silhueta preta dos 4 heróis na câmera de jogo, em 1920×1080 | máscara Forward+ |
| `luz_real_on_off.png` | O estresse com as luzes do motor ligadas e desligadas | Compatibility |
| `clip.mp4`, `clip.gif` e `clip_folha.png` | 5,0 s (300 quadros a 60 fps) a 1280×720 na câmera de combate nova, com hit-stop e corda de verlet; GIF de 640 px e 15 fps; folha de 12 quadros | Forward+ (Movie Maker) |
| `modelo.png` | Folha de modelo: as 4 classes com proporção, pele e marcas novas; Ouvidor (3 vistas e 5 poses); Bocalume; 8 poses do Gancheiro; a faixa do **modelo de jogo** com os ícones exagerados; e o teste de silhueta | Forward+, ortográfica |

## Portões no `stress.png` (Compatibility), v1 contra v2

Os critérios são os mesmos da v1. No cinza, o ΔL mínimo dos heróis precisa ser de pelo menos 0,12 e a mediana dos inimigos de pelo menos 0,10. No borrão, a mediana dos heróis precisa ser de pelo menos 0,12 e a dos inimigos de pelo menos 0,08.

| Portão | v1 | v2 | Passa? |
|---|---|---|---|
| Cinza, heróis (mín. / mediana) | 0,244 / 0,250 | **0,188 / 0,202** | sim, mas ficou menor (veja abaixo) |
| Cinza, inimigos (mediana; abaixo de 0,10) | 0,127; 5 de 20 | **0,174; 4 de 20** | sim, melhorou |
| Borrão de 4 px, heróis (mín. / mediana) | 0,113 / 0,126 | **0,108 / 0,137** | sim; a mediana melhorou e o mínimo (Escorador) caiu 0,005 |
| Borrão de 4 px, inimigos (mediana) | 0,083 | **0,081** | sim, por pouco, como na v1 |
| Miniatura 320×180 | heróis de 10,5 a 17,8 px; menor inimigo com 8,5 px | **heróis de 18 a 27 px; menor inimigo com 10,8 px** | sim, melhorou |
| Jogadores, ΔE mínimo em deuteranopia | 0,025 | 0,025 | **não**: as cores dos jogadores não mudaram; agora o sinal de forma é grande, no anel e na seta |

**Por que o contraste dos heróis no cinza caiu.** Ele caiu de 0,244 para 0,188, mas continua bem acima do critério de 0,12. A causa é uma troca consciente: o chão do terraço subiu de valor (`tom` 0,66 → 0,8) para que os inimigos escuros, agora maiores, se destacassem. As poças de luz quente dos postes também clareiam o chão em volta dos heróis. Para compensar, o piso de valor dos heróis subiu de 30% para 35%, que é o valor que o conceito pede. No caminho, a v2 passou por estados piores (mediana dos inimigos no borrão de 0,042 e ΔL de 0,069 na Cristaleira), que foram corrigidos antes da entrega.

**Paridade.** O quadro 1, sem volumétrica, sem glow e sem DOF, foi medido de novo nos dois renderers: veja a seção "Medidas finais".

## Medidas finais

- **Paridade.** No quadro 1, sem volumétrica, sem glow e sem DOF, a diferença média entre Forward+ e Compatibility é de **4,8/255** (era 6,7).
- **Luz real.** Desligar as luzes do motor muda em média **3,0/255** (era 3,4). Os heróis e as poças quentes continuam, porque estão pintados.
- **Clipe.** São 299 quadros a 60 fps (4,98 s) a 1280×720, renderizados em 583 s (cerca de 2 s por quadro). O MP4 da entrega tem 5,0 MB (crf 17). No repositório, o MP4 tem 2,2 MB (crf 24, sem áudio) e o GIF tem 3,8 MB (640 px, 15 fps, 96 cores).
- **DOF.** O DOF da câmera nova acompanha a distância: o desfoque perto começa a 0,55 da distância e o longe a +14 m. Com os valores fixos da v1 (perto a 17 m), a câmera de 16 m desfocava o plano de jogo inteiro. O primeiro render do clipe da v2 saiu assim e foi refeito.

## Comparação com a v1 (lida quadro a quadro)

- **`beauty.png`.** Os heróis têm cerca de 3 vezes a altura da v1. Aparecem trilha, ruína com poço, postes, ponte, cortinas de goteira, Coluna, janelas do Dente e da Pendura de Baixo. Sumiram o Voronoi, as lajes soltas e os cogumelos-turquesa em grade. O que regrediu: o primeiro plano ficou maior e mais vazio, com manchas de pincel grandes, e o horizonte aparece menos que na câmera de 28 m da v1.
- **`stress.png`.** Os anéis e as setas dos jogadores, as bocas magenta e os Bocalumes se leem. A Corrente não estoura mais o branco. O preço: mais inimigos e efeitos saem da tela, porque a área visível ficou menor (a formação do estresse foi apertada de 6,8 m para 5,0 m de raio).
- **Clipe.** A corda tem catenária, há hit-stop nos golpes e faíscas, e a nuvem de esporos e o pó são cel e frios. O que piorou: a nuvem de esporos ficou grande e cobre o Bocalume entre os quadros 120 e 180.

## Armadilhas novas (úteis para o projeto)

- **`POSITION` escrito só num ramo do `vertex()`.** Se o shader escreve `POSITION` em algum lugar, o Godot usa esse valor sempre, e o ramo que não escreve fica com lixo (o objeto some). Isso escondia o anel do jogador e também o cartão de luz não virado para a câmera da v1 (a poça de luz da Coluna no chão da floresta nunca apareceu). A correção é escrever `POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0)` no outro ramo.
- **Silhueta por profundidade (raio X) não ficou pronta.** O shader `xray.gdshader` lê `hint_depth_texture` e compara com a profundidade do herói. Mesmo com a margem do volume inteiro do herói (1,3 m), ele ainda marcava o próprio herói na câmera de cima, nos dois renderers. Ele ficou desligado (`xray=0`), e a leitura de quem está tampado depende do anel e da seta, que ficam sempre por cima.
- **Movie Maker e o tempo limite do terminal.** Um render longo lançado em primeiro plano é morto quando o terminal passa a segundo plano. É preciso usar `nohup` ou rodar em segundo plano desde o início.
- **Portão contra ambiente.** Clarear inimigos, como a crítica sugeriu, derruba o portão de cinza, porque eles ficam com o valor do chão. O que funcionou foi corpo escuro, aresta fria fina e chão um degrau mais claro.

## O que ficou bom

- **Os heróis aparecem.** Na câmera de combate nova, eles têm o dobro do tamanho na miniatura, e o anel e a seta na cor do jogador sobrevivem a 20 inimigos e à Corrente.
- **O mundo tem lugares.** Há trilha que sai da tela, ruína com um buraco que promete masmorra, ponte de tronco, guincho na beira do vazio, postes de lanterna marcando a rota, cortinas de goteira com fio de luz, e, ao longe, Coluna, Dente e povoado. O chão tem causa: a água escorre em regos para a poça e para o penhasco.
- **O VFX fala uma língua só.** Tudo é recortado, em 2 ou 3 tons, com beirada escura, e não estoura mais o branco.
- **Impacto.** O hit-stop, o achatamento e a corda com catenária e estalo dão peso aos golpes.

## O que é fraco (honesto)

- **O teste de silhueta preta passa em 2 de 4.** De cima e de costas, a rosca do Gancheiro é um disco, e o chapéu de aba larga da Cristaleira também. Faltam formas que furem o disco: o gancho e as pontas do capuz para fora da rosca, um cone mais alto e uma aba mais estreita na Cristaleira, ou a câmera mais baixa.
- **O chão ainda tem cara de "pincel em 3 degraus".** De perto, no `beauty.png`, os degraus de curvatura e oclusão formam manchas grandes parecidas com camuflagem. Os regos só se leem de perto. Uma máscara pintada à mão ainda seria melhor.
- **"Além de AAA" continua longe.** Os personagens melhoraram (pele, marcas, olhos em cavidade, proporção), mas ainda leem como vinil e chibi, e não como chumbo pintado de concurso.
- **Os marcos distantes são pequenos.** O Dente quase não se lê, porque fica escuro contra a parede escura e só as janelas aparecem. A Pendura de Baixo lê como cachos de luz, não como casas.
- **As janelas e as cortinas de goteira** de longe ainda lembram chuva e pontos.
- **O raio X ficou desligado** (veja as armadilhas).
- **Faltam** o Escorador e a Coveira em ação no clipe, o som, a perda de contexto WebGL no iPhone e a medição de desempenho real.

## Código

Pasta: `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/provas-fantasia3/profundezas/`.

**Novo ou mudado na v2:**

- `tools/cenario.py`: `TRILHAS`, `RUINA`, `PONTE`, `GUINCHO`, `COLONIAS`; `fluxo()` (D8); `paint_terraco()`; `ladrilho`, `coluna_ruina`, `tronco`, `guincho`, `poste`, `dente`; fungo com estados; `scatter()` autoral; e as janelas da Pendura. Com `SO_MAPA=arquivo.png`, salva só o mapa de cor do terraço.
- `tools/personagens.py`, `tools/malha.py` (`remap` de tinta por personagem, material `orelha`) e `tools/paleta.py` (peles e marcas).
- `tools/folha.sh` (a folha inteira), `tools/silhueta.py` (o teste de silhueta preta) e `tools/render_tudo.sh` (o quadro bonito e o clipe).
- `proj/boneco.gd`: proporção por classe, corcunda, ícones de jogo e raio X experimental.
- `proj/cena_poca.gd`: câmera, vinheta, hit-stop (`HOLDS`), corda de verlet, anel e seta, poças pintadas e postes acesos.
- `proj/mundo.gd`: `multi2` (instâncias inclinadas), marcos, goteiras e poças dos postes.
- `proj/vfx.gd`: goteiras e respingos no lugar da chuva, e `fita_cel`.
- **Shaders novos:** `anel`, `anel_chao`, `xray`, `vinheta`, `janela` e `cortina`.
- **Shaders mudados:** `particula` (cel), `nevoa` (cel), `comum` (poças `lq0` a `lq9`), `mini` (aresta fria), `olho` (cavidade), `resina` (`dessat`), `terreno` (degraus mais suaves), `agua` (sem as "letras") e `halo` (correção de `POSITION`).

**Comandos** (a partir da pasta da prova):

- **Modelos e cenário:** `cd tools && python3 exportar.py ../proj && python3 cenario.py ../proj`. Leva cerca de 7 s e 15 s.
- **Quadro bonito e clipe:** `tools/render_tudo.sh`, seguido de `tools/codificar.sh out/clip4 entrega/clip`.
- **Estresse:** `tools/run.sh compat 1280x720 entrega/stress.png cena=estresse frames=30`.
- **Portões:** `tools/run.sh fplus 1280x720 out/stress_mask.png cena=estresse frames=30 mascara=1`, seguido de `python3 tools/portoes.py entrega/stress.png out/stress_mask.png entrega/portoes 4`.
- **Silhueta:** `tools/run.sh fplus 1920x1080 out/herois_mask1080.png cena=estresse frames=30 mascara=1 so_herois=1`, seguido de `python3 tools/silhueta.py out/herois_mask1080.png entrega/silhuetas.png`.
- **Folha de modelo:** `tools/folha.sh` (depois da silhueta).
- **Opções:** `hitstop=0` desliga o hit-stop, `xray=1` liga o raio X experimental e `vinheta=0` tira a vinheta.

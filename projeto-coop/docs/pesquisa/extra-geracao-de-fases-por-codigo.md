# Geração de fases só por código: grafo de expedição, salas montadas por script e tamanho do kit por bioma

Pesquisa e protótipo feitos em 27/11/2026. **Só pesquisa: nada do jogo foi construído.** O kit de papel, os nomes de peça e o bioma de teste são marcadores originais, feitos só para medir.

**Pergunta.** Como gerar por código as salas de uma expedição de 12 a 20 minutos com variedade suficiente? As opções são salas pré-montadas e sorteadas, gramática de grafos ou WFC. E quantas peças de cenário de papel cada bioma precisa para não parecer repetido?

**Marcas de confiança.**
- **[teste]**: medido aqui (4 CPUs, sem GPU, Python 3.13, Blender 5.3.0 como módulo `bpy`, Godot 4.5.1 headless).
- **[fonte]**: tem link.
- **[resumo]**: só vi o resumo do WebSearch, não a página.
- **[opinião]**: julgamento meu.
- **[não verificado]**: não consegui confirmar.

**Limitações desta rodada.**
- A cota de WebSearch da sessão acabou depois de 7 buscas. A cota é compartilhada entre os agentes.
- O WebFetch não resolve `kotaku.com`, `threadreaderapp.com` nem `jbsiraudin.github.io`. Por isso, o que se diz sobre Hades vem de resumos de busca.
- Não achei nada técnico sobre a geração de Ravenswatch, Rotwood e Windblown. Essas três ficam marcadas como **[não verificado]**.

**Arquivos do protótipo** (pasta temporária `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-geracao-fases/`):

| Arquivo | O que é |
|---|---|
| `gerador.py` (422 linhas) | gramática do grafo, montagem de sala, validação e 3 políticas anti-repetição. `gerador_v1.py` é a versão com o defeito da seção 4.2 |
| `analise.py`, `analise2.py` | medição de variedade, tempo e varredura de tamanho de kit |
| `kit_bpy.py` (516 linhas) | 19 peças de papel/papelão em `bpy`, montagem da sala, render Cycles e export GLB |
| `godot/bench.gd`, `godot/bench.py` | carga do kit GLB em tempo de execução, instanciação de salas e o mesmo algoritmo em GDScript e Python |
| `out/folha_kit.png` | folha do kit |
| `out/folha_3_expedicoes.png` | v1: 3 expedições, telões neutros |
| `out/folha_v1_x_v4.png` (e as metades `_a`, `_b`) | **comparação principal para o usuário julgar** |
| `out/glb/` | 16 GLBs, 163 KB no total |

---

## 1. Resposta curta

1. **Os jogos de referência confirmados não geram a sala; geram a ordem.**
   - Hades usa salas feitas à mão com um kit (paredes de cobertura total e de meia altura, armadilhas, pilares, mesas, urnas, saídas). As salas são **espelhadas** para a entrada casar com a saída anterior, e o que se sorteia é a sequência e as recompensas [resumo: fio de Ed Gorinstein, 2020].
   - Dead Cells fixa o mapa-múndi à mão e monta cada bioma a partir de um "grafo conceitual", preenchido com **tiles** (trechos de sala) feitos à mão [fonte].
   - The Riftbreaker encaixa tiles feitos à mão por regra de borda, no estilo Wang [resumo]. Binding of Isaac sorteia salas feitas à mão [resumo].
   - **Ninguém do gênero gera a arena de combate por WFC.**
2. **Recomendação [opinião, sustentada pelo teste]: híbrido em 3 camadas.**
   - (a) **Gramática de grafo** para a expedição.
   - (b) **Sala = gabarito de planta paramétrico + kit de papel**, posicionado por regra e validado por inundação de grade (flood fill).
   - (c) **Escolha conjunta anti-repetição** da tupla (planta, telão, marco) ao longo do caminho que o jogador percorre.
   - Chefes em arena fixa escrita por script. WFC só para padrão decorativo, se tanto.
3. **Medido [teste]:**
   - O gerador produz expedições de **8 a 12 salas visitadas** (média 9,9) e **12,0 a 19,0 min** (mediana 14,1) pelo modelo de tempo.
   - São **281 topologias e 478 sequências de tipos distintas em 500 sementes**.
   - Gerar leva **48 ms** por expedição em Python (p95 70 ms).
   - O mesmo algoritmo de sala roda em **GDScript na mesma velocidade que CPython**: 3,6 ms contra 3,8 ms por sala.
   - Instanciar uma sala de cerca de 35 nós a partir do kit GLB leva **0,65 ms**, e carregar os 16 GLBs, **7 a 12 ms**.
4. **O achado mais importante:** evitar repetição **dimensão por dimensão** (saco embaralhado ou "menos usado") **não basta**.
   - Com 6 plantas, 3 telões e 3 marcos, sortear cada dimensão em separado deixa **56% a 78% dos caminhos com pelo menos uma sala "repetida"** (mesma planta, telão e marco). A regra "menos usado por dimensão" é a **pior**, porque os ciclos de período 6, 3 e 3 entram em fase e a mesma combinação volta a cada 6 salas.
   - **Escolher a tupla inteira** pela distância ao que o jogador já viu derruba isso para **6% a 8%**, sem custo de tempo mensurável.
5. **Quantas peças por bioma [teste + modelo]:**
   - **6 gabaritos de planta** (código, compartilháveis entre biomas).
   - **3 estados de telão bem distintos em cor e valor**: com 1 telão, 92% dos caminhos repetem.
   - **6 marcos**: com 3, cada caminho repete cerca de 2 marcos; com 6, cerca de 0,35.
   - **5 objetos genéricos de cobertura**, **1 ou 2 perigos do "verbo"**, **2 pendurados**.
   - Peças comuns ao jogo: bastidor, portal, praticável, ponte, base de alçapão.
   - Total: **cerca de 17 peças novas por bioma + 5 comuns**. Com 4 biomas, **cerca de 73 peças + 6 a 8 gabaritos + 4 arenas de chefe**.
6. **O que a folha de contato mostrou e o número não mostra [teste + opinião]:**
   - Na câmera de camarote, os **objetos de cobertura somem**: caixote e pedra têm menos de 10 px na miniatura.
   - Quem diferencia uma sala de outra é, em ordem: **(1) a cor e o valor do telão, (2) o marco, (3) a planta** (ilhas, L e funil se leem; praticável quase não).
   - Telões em cinza claro parecidos fizeram as 3 expedições v1 parecerem uma só.
   - Sala sem marco parece vazia. Hoje **cerca de 42% das salas ficam sem marco** porque a colocação aleatória falha (seção 4.3).

---

## 2. Como os jogos de referência fazem

| Jogo | Sala de combate | Sequência ou mapa | Confiança |
|---|---|---|---|
| **Hades** (Supergiant, 2020) | Feita à mão com kit: paredes de cobertura total (bloqueia tiro e movimento) e meia (só movimento), armadilhas, pilares, mesas, urnas, saídas. Tártaro: salas médias quase sempre muradas, mais gentis com o novato. Elísio: pilares e armadilhas que renascem. Asfódelo: armadilhas que escalam a cada onda. As salas **se espelham** para a entrada bater com a saída anterior. O número de saídas influi no balanço (quantas recompensas se oferecem) | Ordem e recompensas sorteadas dentro de uma estrutura fixa por bioma. Chefes em profundidade fixa: Tártaro na câmara 14, Asfódelo na 24, Elísio na 36 (wiki); 72 câmaras possíveis por run (wiki). Um blog cita 24 salas comuns no Tártaro, 11 em Asfódelo e 13 no Elísio, sem verificação | [resumo] [fio de Ed Gorinstein](https://threadreaderapp.com/thread/1311777010239193088); [Kotaku](https://kotaku.com/hades-level-design-is-less-random-than-it-seems-1845254545); [Hades Wiki](https://hades.fandom.com/wiki/Chambers_and_Encounters); [blog jbsiraudin](https://jbsiraudin.github.io/blog/arrangements-hell-hades) (números conflitantes) |
| **Dead Cells** (Motion Twin) | "Tiles" feitos à mão: trechos de sala com variação por configuração | Mapa-múndi fixo à mão; por bioma, um "grafo conceitual" (entrada, saída, tesouro, loja, teleporte) preenchido com tiles. Diretor de IA para inimigos | [fonte] [Game Developer, Sébastien Bénard](https://www.gamedeveloper.com/design/building-the-level-design-of-a-procedurally-generated-metroidvania-a-hybrid-approach-); [deepnight.net](https://deepnight.net/tutorial/the-level-design-of-dead-cells-a-hybrid-approach/); [Edgar reproduz o esquema](https://ondrejnepozitek.github.io/Edgar-Unity/docs/examples/dead-cells) |
| **The Riftbreaker** | Tiles feitos à mão, girados e encaixados por regra de borda (problema de Wang); o sorteio escolhe tiles, pontos de spawn e rotação | Mapa inteiro montado por tiles | [resumo] [Game Developer](https://www.gamedeveloper.com/design/systematic-chaos-procedural-map-generation-in-the-riftbreaker) |
| **Binding of Isaac** (via devlog) | Salas feitas à mão, sorteadas de um conjunto | Só a planta do andar é aleatória | [resumo] [painsperdus](https://painsperdus.github.io/gboi-kirby/mapgen/2020/06/24/mapgen-part1.html) |
| **Lost Castle 2** | Fases divididas em "salas" aleatórias, algumas de loja, refúgio, desafio ou elite | O LC1 foi criticado: 5 fases menores que uma fase de Rogue Legacy, "não conectadas de modo aleatório nem interessante" | [resumo] [Game8](https://game8.co/articles/reviews/lost-castle-2-review-early-access); [Operation Rainfall](https://operationrainfall.com/?p=218393); [Niche Gamer](https://nichegamer.com/lost-castle-2-preview) |
| **Windblown** | "Teia de ilhas flutuantes divididas em biomas"; a geração foi elogiada ("runs diferentes o bastante") | Método não publicado; pela herança de Dead Cells, provavelmente híbrido | [resumo] [Gaming Trend](https://gamingtrend.com/feature/previews/windblown-preview-a-snappy-roguelike-with-potential), [Rogueliker](https://rogueliker.com/windblown-early-access-review/); **método [não verificado]** |
| **Ravenswatch**, **Rotwood** | — | Busca sem resultado técnico | **[não verificado]** |
| **Magicka 2** | Fases lineares | Crítica: "ondas e ondas de inimigos idênticos" | [M2c] em `jogos-referencia.md` ([Slant](https://www.slantmagazine.com/games/magicka-2/)) |

**Leitura [opinião].**
- A repetição que pesou contra Magicka 2 é de **ondas** (composição de inimigos), não de chão. A variedade de cenário precisa vir junto com uma gramática de encontros (seção 7).
- Nos jogos citados, a mão humana está no **conteúdo da sala**; o algoritmo cuida da ordem e do encaixe.
- Aqui não há mão humana. Por isso a sala vira **gabarito paramétrico escrito pelo agente**, com o algoritmo preenchendo os detalhes e um **portão de curadoria** (folha de contato + métricas) fazendo o papel do olho do designer.

---

## 3. O protótipo [teste]

### 3.1 Camada 1: gramática do grafo da expedição

- **Regras** (estilo Dormans, gerar e testar), em `gerador.py`:
  - `EXPEDICAO → ABERTURA MIOLO CLIMAX`.
  - `MIOLO → TRECHO TRECHO (TRECHO)`.
  - `TRECHO → combate ESCOLHA | ESCOLHA combate | combate combate RECOMPENSA | DESAFIO`.
  - `ESCOLHA → <ramo | ramo | ramo>`: o jogador escolhe a porta, como em Hades.
  - `CLIMAX → (loja) descanso chefe`.
- **Restrições testadas em todos os caminhos:**
  - 8 a 12 salas e 12 a 20 min;
  - nada de duas elites seguidas nem "elite, combate, elite";
  - no máximo 3 combates seguidos;
  - ao menos 1 sala do "verbo" do bioma.
- **Modelo de tempo:** entrada 20 s, combate 90, verbo 80, elite 130, evento 40, loja 45, descanso 30, tesouro 25, chefe 210, transição 6 s. São estimativas para calibrar no protótipo jogável.

| Métrica (500 sementes, política final) | Valor |
|---|---|
| Salas visitadas por caminho | 8 a 12 (média 9,9; moda 10) |
| Duração estimada por caminho | 12,0 a 19,0 min (mediana 14,1) |
| Nós no grafo (com ramos não visitados) | 8 a 16 (média 11,6) |
| Caminhos possíveis por expedição | 1 a 12 (média 2,5) |
| Topologias distintas / sequências de tipos distintas | 281 / 478 |
| Tentativas até o grafo passar nas restrições | média 6,7, máx. 54 |
| Mistura de salas visitadas | combate 33%, verbo 13%, entrada 10%, chefe 10%, loja 8%, descanso 8%, evento 6%, elite 6%, tesouro 5% |

### 3.2 Camada 2: sala montada a partir do kit

Para cada nó do grafo, a sala é montada assim:

1. **Planta**: um de 6 gabaritos paramétricos, todos de 17 a 22 m de largura por 10 a 12,5 m de fundo, com espelho aleatório:
   - retângulo;
   - L;
   - anel com fosso central;
   - 3 ilhas com 4 pontes;
   - dois níveis (praticável no fundo);
   - funil.
2. **Entrada** na borda da frente (baixo da tela) e **portais** no fundo, um por aresta de saída. É a convenção de Hades, que combina com o palco.
3. **Marco** (casa, moinho, coreto e, na v4, igreja, caixa-d'água e roda) no fundo, à esquerda ou à direita.
4. **Coberturas** por disco de Poisson com rejeição:
   - 4 a 7 em combate, 2 a 4 na sala do verbo, 1 a 3 em sala calma;
   - clareira central de 3,2 m;
   - 2,6 m de folga de saídas e entrada.
5. **Perigos** do verbo (alçapão): 3 a 5 na sala do verbo, 0 a 2 em combate. Mais **pendurados** (nuvem, lua).
6. **Validação** por inundação em grade de 0,5 m: a entrada precisa alcançar todas as saídas, e a área livre deve ficar em pelo menos 55% da área bruta, ajustada por planta. Se falhar, sorteia de novo (até 60 vezes).

Para o render, a sala vira cena `bpy`:
- chão de tábuas por `Wave Texture`;
- telão em 3 camadas de recorte;
- 4 bastidores serrilhados;
- peças com mão-francesa de papelão atrás.

A câmera é a de camarote do relatório de prova de estilo (38°, fov 30°), afastada para caber a sala inteira.

### 3.3 Kit de papel em `bpy` [teste]

| Peça | Tipo | Tempo de geração | Triângulos | GLB |
|---|---|---|---|---|
| caixote, pedra, fardo | cobertura 3D (caixa com fita, icosfera achatada, rolo) | 0,9 a 2,2 ms | 12 a 20 | 2,6 a 3,5 KB |
| cerca, árvore | recorte de pé, com escora | 1,8 a 2,5 ms | 57 a 115 | 8 a 10 KB |
| casa, moinho, coreto (+ igreja, caixa-d'água, roda) | marco | 2,6 a 13,8 ms | 45 a 83 | 12 a 20 KB |
| nuvem, lua | pendurado com fio | 2,3 a 5 ms | 62 a 80 | 7,6 a 8,1 KB |
| alçapão, portal, bastidor | perigo, saída, moldura | 0,3 a 1,6 ms | 12 a 88 | 2,9 a 8,5 KB |
| telão (morros, casario, mata) | 3 camadas de recorte | 1,9 a 4 ms | 258 | 19,6 KB |

Totais:
- os 16 GLBs somam **163 KB**;
- uma sala montada no Blender tem de 21 a 49 objetos e de 2.000 a 3.300 faces;
- o render Cycles em CPU, 480×270 com 8 amostras e denoise, leva **1,0 a 2,2 s por sala**;
- uma folha de 12 salas sai em cerca de 20 s;
- **uma folha de 100 salas para curadoria leva cerca de 3 min**.

Uma armadilha técnica apareceu no `bpy`: `bmesh.ops.triangulate` em face côncava criada por `bm.faces.new` gerou triângulos invertidos e lascas pretas no portal, na copa e no telão. A correção foi triangular com `mathutils.geometry.tessellate_polygon` e montar frente, verso e laterais à mão (`recorte()` em `kit_bpy.py`).

### 3.4 Tempo no Godot [teste]

| Medida | Resultado |
|---|---|
| Carregar 16 GLBs com `GLTFDocument.append_from_file` + `generate_scene` | 7,3 a 11,9 ms no total |
| Instanciar uma sala do JSON (chão em `BoxMesh` + `duplicate()` das peças) | mediana 0,65 a 0,75 ms, máx. 0,9 a 2,1 ms; cerca de 35 nós por sala |
| Mesmo algoritmo de sala (Poisson + inundação), 300 salas | **GDScript 3,6 a 3,8 ms por sala; CPython 3,75 a 3,76 ms por sala** |
| Expedição inteira em Python (grafo + 12 salas) | mediana 48 ms, p95 70 ms |

**Consequência:** gerar em tempo de execução, no próprio Godot, cabe numa tela de carregamento (cerca de 50 ms no desktop). Na Web (wasm, sem threads) e no celular, isso deve subir algumas vezes; o fator real não foi medido [não verificado]. Gerar *offline* em Python e mandar JSON também funciona, e é o que a curadoria pede (seção 6).

---

## 4. Variedade: o que se mede e o que se vê

### 4.1 Definições usadas

- **Repetição fraca**: duas salas do mesmo caminho com a mesma planta, o mesmo telão e o mesmo marco (ou ambas sem marco). Ignora espelho e a posição das coberturas, que a folha mostrou serem quase invisíveis.
- **Repetição forte**: a fraca, mais o mesmo espelho e diferença de no máximo 2 células na grade 4×3 de ocupação das coberturas.
- **Vizinhas iguais**: duas salas seguidas com a mesma planta e o mesmo telão.

### 4.2 Gerador real: política de sorteio × tamanho do kit (300 a 1.000 sementes, cerca de 2.500 caminhos)

| Configuração | Caminhos com repetição fraca | Pares fracos por caminho | Vizinhas iguais | Marcos repetidos por caminho |
|---|---|---|---|---|
| v1: saco embaralhado por dimensão, F6 T3 L3, com defeito de validação | 47,7% | 0,65 | 0,21 | 4,38 |
| B: v2, saco por dimensão, F6 T3 L3 | 56,3% | 0,78 | 0,12 | 2,26 |
| C: v2, "menos usado pelos ancestrais" por dimensão, F6 T3 L3 | **77,9%** | 1,52 | 0,00 | 1,96 |
| D: idem, L6 | 74,8% | 1,17 | 0,00 | 0,37 |
| G: saco por dimensão, L6 | 46,0% | 0,59 | 0,12 | 1,08 |
| **H: v4, tupla conjunta mais distante, F6 T3 L3** | **7,9%** | 0,08 | 0,01 | 1,99 |
| **I: v4, tupla conjunta, F6 T3 L6** | **6,0%** | 0,06 | 0,00 | **0,33** |
| J: v4, tupla conjunta, kit menor F4 T2 L3 | 20,8% | 0,21 | 0,00 | 3,94 |
| K: v4, tupla conjunta, F8 T3 L6 | 7,1% | 0,07 | 0,00 | 0,58 |
| F: v2, menos usado por dimensão, F6 **T1** L6 | 92,4% | 1,64 | 0,26 | 0,36 |

F = plantas, T = telões, L = marcos.

Leitura:
- **Política conjunta.** Para cada sala, testa todas as tuplas (de 54 a 144) e pontua cada uma pela soma, sobre os ancestrais no caminho, de (iguais²) × recência. Os pesos são planta 1,0, telão 0,6 e marco 1,4. Escolhe o mínimo, com desempate aleatório. É cerca de 30 linhas e não mudou o tempo (45 ms por expedição).
- **Por que "menos usado por dimensão" piora.** Cada dimensão entra num ciclo do tamanho do seu conjunto (6, 3, 3), e o mínimo múltiplo comum, 6, faz a tupla inteira voltar. A regra boa por dimensão é ruim para o conjunto. Isso vale para qualquer coisa sorteada "sem repetir" em paralelo: inimigos, músicas, falas.
- **F8 não melhora sobre F6** com T3 e L6. O gargalo passa a ser o marco que não cabe (seção 4.3).
- **Defeito pego pela medição (v1 → v2).** A margem de "dentro da planta" era testada por retângulo, então a emenda entre dois retângulos virava parede.
  - Taxa de rejeição antes da correção: funil **100%**, L **68%**, ilhas **53%**. Esses gabaritos quase nunca apareciam.
  - Depois: funil 0%, L 0%, retângulo 0,3%, ilhas 33%. O marco grande no meio de ilha estreita era a outra causa.
  - Regra de produção: **medir a taxa de rejeição por gabarito e a distribuição final, sempre**. Um gabarito rejeitado some do jogo sem aviso.

### 4.3 Modelo abstrato: quantos itens por dimensão (10 salas, 4.000 runs, 85% das salas com marco)

| F | T | L | Uniforme: P(≥1 repetição) | Saco por dimensão: P(≥1 repetição) |
|---|---|---|---|---|
| 4 | 2 | 3 | 81% | 62% |
| 6 | 1 | 6 | 68% | 38% |
| 6 | 2 | 6 | 41% | 21% |
| 6 | 3 | 3 | 49% | 29% |
| 6 | 3 | 6 | 29% | 15% |
| 6 | 4 | 6 | 23% | 10% |
| 8 | 3 | 6 | 25% | 7% |
| 8 | 4 | 6 | 18% | 6% |

O sorteio conjunta (seção 4.2) dá com F6 T3 L3 o que o saco só alcança com F8 T4 L6. **A política vale mais que dobrar o kit.**

### 4.4 Folha de contato: o que o olho diz [teste + opinião]

`out/folha_v1_x_v4.png`, linha 1: v1, telões neutros. Linhas 2 e 3: v4, tupla conjunta, 6 marcos, telão com cor.

1. **v1:** as 12 salas parecem a mesma, com o marco mudando de lugar. O telão cinza claro, os bastidores vermelhos e o chão de tábuas dominam a miniatura. A métrica dizia "47% de caminhos com repetição"; o olho diria "quase 100% parecidas".
2. **v4 com telões de matiz e valor distintos** (dia ocre e verde, entardecer rosado, noite azul): as salas se separam de imediato, mesmo sem marco. O telão é a peça de maior área na tela, e por isso é o maior botão de variedade.
3. **Ordem de leitura medida a olho:** telão, depois marco, depois planta (ilhas, funil e L se leem; anel se lê pelo buraco preto; dois níveis quase não), depois perigo vermelho. As coberturas pequenas (caixote, pedra, fardo) não diferenciam nada.
4. **Problemas novos:**
   - (a) A tupla conjunta fez os telões alternarem em ciclo A-B-C. Um padrão visível em sequência também é repetição.
   - (b) **58% das salas têm marco e 42% saem vazias**, porque a colocação sorteada falha em funil e ilhas. Sala vazia é a que mais parece "gerada".
   - (c) O praticável de dois níveis, na mesma cor do chão, não aparece.

**Correções propostas [opinião]:**
- (a) Telão por **ato**, não por sala: manhã, tarde e noite, seguindo o progresso até o chefe. A tupla conjunta escolhe só planta e marco.
- (b) Cada gabarito declara **2 a 4 encaixes de marco** (anchors escritos pelo agente), em vez de posição aleatória. Marco sempre presente em sala de combate.
- (c) Praticável em tinta média com borda escura, seguindo a hierarquia de tinta do relatório de prova de estilo.

### 4.5 Variedade combinatória (para a ficha de escopo)

- 1.000 expedições da v1 geraram **9.547 assinaturas de sala distintas**, contando espelho e grade 4×3, em cerca de 12.000 salas. Foram **1.409 padrões de cobertura distintos**.
- Combinações **perceptíveis** (planta × telão × marco): 6 × 3 × 4 = **72** na v1 e 6 × 3 × 7 = **126** na v4.
- Com cerca de 10 salas por expedição, o jogador vê cada combinação perceptível uma vez a cada 7 a 13 expedições. Entre expedições a repetição é aceitável; Hades repete salas fixas a cada run [opinião]. O que precisa de controle é a repetição **dentro** de uma expedição, e isso a política conjunta resolve.

---

## 5. WFC, gramática de grafos, salas pré-montadas: comparação para este projeto

| Técnica | Serve para | Não serve para | Custo para o agente | Veredito [opinião] |
|---|---|---|---|---|
| **Gramática de grafo + gerar e testar** | Ritmo da expedição (ordem, escolhas, chefe, loja), duração alvo, garantias ("1 sala do verbo") | Geometria | Baixo: cerca de 150 linhas; 6,7 tentativas em média, 1 ms | **Usar** (camada 1) |
| **Gabarito de planta paramétrico + kit + Poisson + inundação** (o "pré-montado por script") | Arena de combate legível na câmera de camarote: clareira, saídas no fundo, marco no fundo | Mapas grandes contínuos | Médio: cerca de 270 linhas + 1 gabarito novo de cerca de 15 linhas por planta | **Usar** (camada 2), com curadoria |
| **Salas fixas escritas por script** (como os de Hades, mas em código) | Chefes, tutorial, sala do verbo de apresentação | Volume | Alto por sala, garantido | **Usar** para 1 chefe + 1 a 2 salas especiais por bioma |
| **Layout por grafo com encaixe de salas** (Edgar, SimpleDungeons) | Masmorra contínua com corredores, câmera seguindo | Arena separada com transição | — | **Não usar**: o projeto tem salas-arena discretas, e o grafo já resolve a ordem |
| **WFC** (godot-constraint-solving) | Padrões locais coerentes em grade: piso de azulejo, telão de casario, borda de mata | Composição de arena: o README admite **sem restrições globais de caminho e sem 3D** | Médio e lento com backtracking | **Opcional**, só para decoração; nada de geometria de combate |
| **Mapa aberto procedural** (ao estilo Ravenswatch, [não verificado]) | Exploração | Web/celular (memória, `NavigationMesh` grande), legibilidade com 4 jogadores, 12 a 20 min | Alto | **Não** neste escopo |

**Arena fixa ou mapa procedural?** Nenhum dos dois puro. Uma **sequência de arenas pequenas montadas por gabarito**, com transição de cortina (troca de cena de teatro), resolve várias coisas de uma vez:
- o escopo (cada sala cabe em uma tela);
- a legibilidade, porque a câmera de camarote não precisa seguir longe;
- o online: o host manda o JSON da sala, de 2 a 5 KB [estimativa];
- o celular: 35 nós e menos de 3.500 triângulos de cenário por sala.

---

## 6. Fluxo de produção recomendado (feito por agente) [opinião baseada no teste]

1. **Gabaritos em Python** (fonte da verdade) e o mesmo código portado para GDScript. A velocidade é a mesma (3,6 contra 3,8 ms por sala). Ou gerar só offline e embarcar JSON.
2. **Portão automático** por gabarito, rodado a cada mudança, com 200 sementes:
   - taxa de rejeição menor que 10%;
   - área livre;
   - número de coberturas;
   - marco presente;
   - distância da entrada às saídas;
   - distribuição final de plantas (cada uma dentro de ±30% da média).
3. **Folha de contato Cycles** (100 salas em cerca de 3 min) lida pelo próprio agente como imagem, como fiz aqui. Rejeitar à mão as feias e guardar as **sementes aprovadas num catálogo** por bioma. Exemplo: 40 salas aprovadas por bioma. É o equivalente ao "feito à mão" de Hades, com o código como pincel.
4. **Em tempo de execução**, o grafo é gerado ao vivo e cada nó escolhe do catálogo pela **tupla conjunta**. O catálogo elimina a chance de sala ruim e fixa as amostras para teste e para rede.
5. **Teste com GUT** (já testado no relatório de addons): para 1.000 sementes, 0 falhas de conectividade, duração de 12 a 20 min e no máximo 10% de repetição fraca.
6. **Determinismo na rede:** enviar o JSON da sala do host em vez de só a semente. Não verifiquei se `RandomNumberGenerator` com ponto flutuante dá resultado idêntico entre desktop e wasm.

---

## 7. Volume de conteúdo e plano de escopo

### 7.1 Kit por bioma

| Item | Quantidade | Mínimo medido | Observação |
|---|---|---|---|
| Gabaritos de planta | **6** (compartilhados; +1 assinatura por bioma, opcional) | F4 já dá 21% de repetição com a política conjunta; F6, 6 a 8%; F8 não melhora | É código, não arte. O bioma muda parâmetros (estreito, alagado) |
| Telão | **3 estados por bioma**, distintos em matiz **e** valor; podem ser 1 silhueta × 3 luzes | T1 → 92% de repetição | Peça de maior área; maior alavanca |
| Marcos | **6** | L3 → 2 marcos repetidos por caminho; L6 → 0,33 | Com encaixes declarados no gabarito |
| Cobertura genérica | **5** | invisíveis na miniatura; servem ao combate, não à variedade | Recolor por bioma possível |
| Perigo do "verbo" | **1 a 2** | — | É o que muda o combate (recomendação de `jogos-referencia.md`) |
| Pendurados | **2** | — | Leem-se bem contra o telão |
| Comuns ao jogo | bastidor, portal, praticável, ponte, base de alçapão (**5**) | — | Recolor por paleta |
| Arena de chefe | **1** escrita por script | — | — |

**Contagem:** cerca de **17 peças novas por bioma**. Com 4 biomas, **68 + 5 comuns ≈ 73 peças**, mais 6 a 8 gabaritos e 4 arenas de chefe.

Custo medido do protótipo: 19 peças em cerca de 516 linhas de `bpy` (incluídos montagem e render), de 0,3 a 14 ms de geração e 3 a 20 KB de GLB cada. **O gargalo não é máquina, é o tempo do agente escrevendo e revisando cada peça na folha.**

### 7.2 Encontros (a crítica real a Magicka 2)

A variedade de cenário não salva onda repetida. A mesma política conjunta deve escolher a **composição** de cada sala de combate:
- 4 a 5 tipos de inimigo por bioma, mais 1 elite;
- 12 a 16 modelos de onda como dados;
- tags de sala: "ilhas" pede atirador, "anel" pede empurrão para o fosso.

Isso é proposta, não testada aqui; uma prova de encontros fica para depois. A métrica é a mesma: tupla (planta, marco, composição) sem repetição fraca no caminho.

---

## 8. Ferramentas no GitHub (conferidas com `git ls-remote` e clone raso; licença lida no arquivo)

| Repositório | Licença | Último commit | Serve? |
|---|---|---|---|
| [majikayogames/SimpleDungeons](https://github.com/majikayogames/SimpleDungeons) | CC0 | 02/04/2025 (`15b3240`) | Não para arenas discretas. Masmorra 3D em voxels com corredores; 142 ms para 7 salas e 62 corredores (relatório de addons) |
| [AlexeyBond/godot-constraint-solving](https://github.com/AlexeyBond/godot-constraint-solving) | MIT | 13/05/2025 (`45e3edd`) | Só decoração: WFC 2D e fatia de `GridMap`, com backtracking e threads. O README diz que não tem 3D nem restrições globais de caminho |
| [BenjaTK/Gaea](https://github.com/BenjaTK/Gaea) | MIT | 18/10/2026 (`79461f6`), `v2.0.0-beta6`, Godot 4.4+ | Grafo de nós para terreno em grade (`TileMap`/`GridMap`): ruído, `floor_walker`, `snake_path_2d`, `rules_placer`. O próprio README diz "início de desenvolvimento". Não é para arena |
| [gdquest-demos/godot-procedural-generation](https://github.com/gdquest-demos/godot-procedural-generation) | Código MIT, arte CC-BY 4.0 | 26/06/2026; pasta `godot4` com `config/features` 4.7 | Referência didática (`mst_dungeon`, `random_walker`, `cellular_automata`, `basic_dungeon`) |
| [ondrejnepozitek/Edgar-DotNet](https://github.com/ondrejnepozitek/Edgar-DotNet) | MIT | 03/01/2021, .NET Core 2.2/3.1 | Só como leitura de algoritmo (layout por grafo). **C# no Godot 4 não exporta para Web**: a documentação oficial diz "Projects written in C# using Godot 4 currently cannot be exported to the web" ([godot-docs, exporting_for_web.rst](https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/export/exporting_for_web.rst)) |
| [mxgmn/MarkovJunior](https://github.com/mxgmn/MarkovJunior) | MIT | 19/03/2026 | C#; reescrita de grade. Só offline e só se houver `dotnet` (não há no container) |
| [mxgmn/WaveFunctionCollapse](https://github.com/mxgmn/WaveFunctionCollapse) | MIT | acessível | Referência do WFC original |
| [ikarth/wfc_2019f](https://github.com/ikarth/wfc_2019f) | MIT | 18/08/2023 | WFC em Python, para padrão offline, se preciso |
| [BorisTheBrave/DeBroglie](https://github.com/BorisTheBrave/DeBroglie) | MIT | 21/12/2025 | C#; restrições de caminho em WFC. Referência |
| [marian42/wavefunctioncollapse](https://github.com/marian42/wavefunctioncollapse) | MIT | 28/03/2021 | Unity; referência de WFC 3D infinito |

Inexistentes ou inacessíveis (`git ls-remote` pediu credencial): `Zylann/godot_wfc`, `ondrejnepozitek/Edgar-Godot`, `Hoimar/godot-wfc` e outros nomes chutados. **Não existe Edgar para Godot acessível.**

**Nada disso é necessário para o caminho recomendado.** O gerador do protótipo é Python e GDScript puros, sem dependência. Nada foi instalado; os clones ficaram em `.../pesquisa-geracao-fases/ext/`.

Leituras de método citadas pelos resultados de busca, não lidas por inteiro:
- [Unexplored: cyclic dungeon generation](https://gamedeveloper.com/design/unexplored-s-secret-cyclic-dungeon-generation-) (gramática cíclica, Joris Dormans);
- [Rooms and Mazes](https://journal.stuffwithstuff.com/2014/12/21/rooms-and-mazes);
- [Cogmind, map composition](https://www.moddb.com/games/cogmind/news/map-composition);
- [Bombslinger, editor de salas](https://www.moddb.com/features/crafting-the-rooms-and-levels-of-bombslinger);
- [Edgar, level graphs](https://ondrejnepozitek.github.io/Edgar-Unity/docs/basics/level-graphs).

---

## 9. Recomendações (em ordem)

1. **Adotar o híbrido em 3 camadas:** gramática de grafo, depois gabarito paramétrico + kit, depois catálogo curado escolhido por tupla conjunta. Chefe e sala de apresentação do verbo ficam fixos, por script.
2. **Política anti-repetição conjunta desde o primeiro dia**, aplicada também a ondas, músicas e falas. Nunca usar "sem repetir por dimensão" em paralelo.
3. **Telão por ato** (3 estados de luz por bioma, separados em matiz e valor), não por sala. É a peça que mais muda a percepção.
4. **Marco obrigatório em sala de combate, com encaixes declarados no gabarito.** Meta: 100% das salas de combate com marco; hoje são 58%.
5. **Kit de cerca de 17 peças novas por bioma** (3 telões, 6 marcos, 5 coberturas, 1 ou 2 perigos, 2 pendurados), mais 5 comuns e 6 gabaritos de código.
6. **Portão automático por gabarito**: rejeição, distribuição e conectividade. Mais **folha de contato** a cada mudança de kit. A medição pegou um defeito que tirava 2 de 6 plantas do jogo.
7. **Ilhas precisam de regra própria:** ainda há 33% de rejeição, e a ponte de 2 m com 4 jogadores pode ser estreita demais. Testar no protótipo jogável.
8. **Praticável e diferença de nível** em tinta mais escura, senão não se lê.
9. **Duração de 12 a 20 min como restrição do grafo**, com o modelo de tempo calibrado por telemetria do primeiro protótipo.
10. **WFC fica fora da geometria de combate**; se entrar, é para piso e telão.

---

## 10. Pontos em aberto

- Métodos de Ravenswatch, Rotwood e Windblown: não confirmados (busca sem resultado técnico; cota de busca esgotada).
- Números de Hades (salas por bioma): fontes em conflito; só resumo de busca.
- Tempo do gerador em wasm e no celular: não medido. O mesmo algoritmo em GDScript desktop leva cerca de 3,7 ms por sala.
- Determinismo de semente entre desktop e Web: não testado. Por isso, enviar JSON da sala.
- "Repetição percebida" foi julgada por mim nas folhas e por uma métrica proxy, não com jogadores.
- O modelo de tempo das salas (90 s por combate etc.) é estimativa.
- As peças do protótipo são de nível de layout, não arte final. Não servem para julgar o estilo, só a leitura de variedade.
- A gramática de encontros (seção 7.2) é proposta não testada.

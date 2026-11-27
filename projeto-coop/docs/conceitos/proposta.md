# Proposta: os 3 finalistas

Documento do diretor criativo, 27/11/2026, revisado depois do red team no mesmo dia. **Nada aqui está decidido.** É a proposta que vai ao usuário antes de qualquer execução. Ela parte dos quatro conceitos desta pasta e das notas de três juízes com lentes diferentes: co-op e sistemas, arte e animação, e viabilidade técnica. A seção 6 lista o que o red team pediu, o que mudou e o que foi recusado.

**Como ler.** Cada finalista aproveita a base de um conceito e recebe enxertos dos outros. Todo enxerto diz de onde veio: **[A]** Rejunte (o conceito que deu origem a Cacos de Cobalto), **[B]** Tralha da Cheia, **[C]** Tolda Viva, **[D]** Lumaréu. **[pesquisa]** aponta um achado de `docs/pesquisa/`. **[mudança]** marca uma decisão minha que corrige um problema apontado pelos juízes. **[red team]** marca uma correção pedida na revisão.

### Glossário curto

| Termo | O que quer dizer aqui |
|---|---|
| Tolda | A barraca de pano que serve de palco ao teatro de bonecos de luva. Embaixo fica a **empanada** (o pano que esconde o bonequeiro); em cima, a **bambinela** (a faixa de pano que enquadra o palco) |
| Coxia | A lateral escondida do palco, de onde entram e saem pessoas e cenários |
| Praticável | O chão de tábuas onde a cena acontece |
| Contrarregra | Quem troca o cenário à vista, vestido de escuro |
| Demão | Uma camada de matéria aplicada num inimigo. Duas matérias diferentes no mesmo alvo dão uma reação |
| Deixa | Ponto que o jogador caído junta para voltar sozinho |
| Pose segurada | Uma pose que fica parada alguns quadros, em vez de o corpo se mover sem parar. Dá peso e leitura |
| Congelamento de impacto (hit-stop) | A imagem para por alguns quadros no instante do golpe, para o golpe "pesar" |
| Quadro de borrão (smear) | Um único quadro com o objeto esticado na direção do movimento, para sugerir velocidade |
| Teste de borrão e teste de daltonismo | Checagens automáticas: a imagem é desfocada (ou passada por um filtro de daltonismo) para ver se o herói continua se destacando do fundo e dos outros jogadores |
| Compatibility e Forward+ | Os dois modos de render do Godot. Compatibility roda no navegador e no celular; Forward+ é o do PC, com mais recursos |
| Draw call | Cada pedido de desenho que o jogo faz à placa de vídeo. O celular aguenta poucos por quadro |
| Fatia vertical | Um pedaço pequeno do jogo, mas completo e com acabamento final, para testar se a ideia funciona |
| Anfitrião | O aparelho que decide as regras da partida online; os outros mandam os comandos para ele |

---

## 0. Resumo em uma página

### Notas dos juízes (soma de três notas de 0 a 10)

| Conceito | Co-op e sistemas | Arte e animação | Viabilidade | Soma | Destino |
|---|---|---|---|---|---|
| C, Tolda Viva | 8,5 | 8 | 8 | **24,5** | **Finalista 1**, enxugado; favorita provisória |
| B, Tralha da Cheia | 8 | 6 | 7,5 | 21,5 | **Finalista 3**, com a animação refeita |
| A, Rejunte | 7,5 | 7 | 6,5 | 21 | **Finalista 2**, agora **Cacos de Cobalto**, com os heróis invertidos e o rejunte como sistema |
| D, Lumaréu | 6 | 6,5 | 5,5 | 18 | Não passa. Vira **doador de ideias** para os três |

As notas foram dadas antes do red team e não foram refeitas.

### Por que estes três, e não uma fusão grande

Os três cobrem o que o usuário pediu, cada um por um caminho:

- **Tolda Viva** é o meio-termo: pancadaria de brawler com combinação de matérias entre amigos e um palco que os próprios jogadores operam.
- **Cacos de Cobalto** é o mais perto de **Magicka 2**: magia física, combinação no chão e fogo amigo cômico.
- **Tralha da Cheia** é o mais perto de **Lost Castle 2**: arsenal que muda a cada partida, armas que quebram e corpo a corpo com peso.

Fundir dois deles num só (por exemplo, o chão de azulejo de A dentro do teatro de C) custaria duas linguagens de material e somaria os riscos dos dois. Em vez disso, cada finalista recebe **as peças baratas e fortes** dos outros: regras, sistemas e técnicas que não mudam a identidade dele.

### O que o Lumaréu (D) doa

D não passou porque a mecânica central (pregar a sombra) depende de uma técnica nunca testada no Compatibility, é difícil de ler numa tela de celular escura e não tem um material próprio que dê identidade. Quatro ideias dele são boas demais para jogar fora:

1. **"O perigo encolhe, a ajuda cresce."** Toda telegrafia de inimigo é uma forma que se fecha; todo efeito de herói é uma forma que se abre. Um script consegue conferir isso em cada efeito. Vai para os três finalistas.
2. **Rosto controlado por shader** com 4 parâmetros (abertura, inclinação, curva e pupila). Fica nítido em qualquer resolução e dispensa rig facial e troca de textura. Vai para os olhos pintados de C e de B e para o rosto de 3 traços de A.
3. **Ritmo de poses como personalidade.** Cada herói anda num ritmo de poses próprio (por exemplo, 12, 15, 20 e 30 poses por segundo). Vai para B, onde ajuda a combater a uniformidade, junto com poses próprias por herói (seção 3).
4. **Mecânica por posição, não por tempo exato.** Posição tolera 150 ms de rede entre celulares; tempo exato não tolera. Vai para a maquinaria de duas pessoas de C e para a Tralha Grande de B.

### O tema é uma camada que pode ser trocada **[red team]**

O usuário não pediu tema brasileiro. Os três finalistas usam um artesanato brasileiro (boneco de luva, azulejo, brinquedo de miriti) num mundo inventado, e isso é uma camada de tema, não o jogo. Se a resposta à pergunta 2 da seção 5 for "pouco" ou "nenhuma referência regional", a variante abaixo entra no lugar, e a prova de estilo é feita com ela.

| Finalista | Com referência brasileira | Variante sem referência regional |
|---|---|---|
| Tolda Viva | Teatro de bonecos de luva inspirado no mamulengo, com crédito explícito | **Teatro de oficina** inventado: bonecos de luva de uma companhia sem nação, tecidos sem chita (xadrez, listrado, poá, lona), nenhuma tradição citada. Nessa variante, "mamulengo" entra na lista de palavras que reprovam a checagem de 3 palavras |
| Cacos de Cobalto | Azulejo de fundo azul e reserva branca | **Porto de cerâmica inventado**, com padrões geométricos próprios e outra cor de fundo |
| Tralha da Cheia | Brinquedo de miriti, com crédito a Abaetetuba | Brinquedo de **madeira leve facetada** genérico, sem nomear a origem |

### Recomendação curta

**Favorita provisória: Tolda Viva**, na versão enxugada da seção 1. O pipeline do boneco gerado por código já foi provado; o visual próprio da Tolda (telão pintado, cabeças por curva, tecidos escuros) ainda não. Ela tem o co-op mais pensado como jogo de grupo e a melhor solução para quem morre.

A recomendação final só sai depois de três passos, nesta ordem:

1. o usuário responde às **3 perguntas que mudam as provas** (seção 5, grupo 1);
2. sai o **resultado do teste de desempenho** no celular real dele;
3. as três **provas de estilo em movimento**, com 4 heróis e 20 inimigos, ficam prontas (abaixo).

Os detalhes estão na seção 4.

### Como as provas de estilo vão ser feitas (vale para os três) **[red team]**

Uma imagem parada com 2 heróis não prova o que o usuário pediu (animação pelos princípios da Disney) nem o que falhou na prova anterior (4 heróis legíveis no meio de 20 inimigos). Por isso, cada prova tem quatro peças:

| Peça | O que é | Para que serve |
|---|---|---|
| **(a) Quadro bonito** | A cena descrita no fim de cada seção, em 1280 × 720, no Compatibility | Julgar se é bonito e se não parece slop |
| **(b) Quadro de estresse** | A mesma arena com **4 heróis, 20 inimigos e efeitos**, na câmera de combate | Passar pelos portões automáticos: cinza, borrão, miniatura de 320 × 180, deuteranopia e protanopia **entre os 4 jogadores** |
| **(c) Clipe de 3 a 5 s a 30 fps** (WebM ou GIF) | O efeito-assinatura principal e a locomoção de dois heróis | Julgar o movimento: antecipação, sobreposição, congelamento de impacto |
| **(d) Quadro no nível PC** | O quadro (a) no Forward+, com os extras do PC ligados | Mostrar o que o PC acrescenta (ver a seção seguinte) |

Cada prova também roda como **build Web no celular real do usuário**, com o contador de draw calls e de quadros por segundo na tela.

**Quem julga.** As provas são publicadas numa página com um formulário de 3 palavras ("descreva em 3 palavras o que você vê") que grava as respostas, para o usuário e os amigos dele responderem. É o grupo co-op real, e é o único teste com pessoas. Os portões automáticos (borrão, daltonismo, paleta, palavras proibidas num texto gerado) passam a se chamar **checagem interna**, não "teste cego", porque são feitos por máquina sobre o próprio render.

### O que "efeitos além de triple A" quer dizer aqui **[red team]**

Vale dizer ao usuário com clareza o que dá e o que não dá:

- **Dá:** acabamento de animação e de impacto no nível de jogos indie premiados: poses fortes, antecipação, sobreposição, congelamento de impacto, partículas com material próprio, som casado com o golpe, um estilo coeso que não parece pacote de assets.
- **Não dá:** fidelidade de jogo AAA de grande estúdio: rostos realistas, simulação de pano, iluminação global, captura de movimento. Todo asset sai de código, e o jogo precisa rodar num celular de entrada.
- **O que o PC acrescenta de fato:** sombra real, feixes de luz volumétricos (por exemplo, a luz das luas ou do farol atravessando o pó), mais partículas por efeito, distorção de tela nos golpes grandes e serrilhado mais limpo (MSAA 4×). A regra de paridade passa a valer só para a **camada base**, com os extras desligados; o quadro (d) de cada prova mostra os extras ligados. A prova anterior deu nota 3 ao "teto no Forward+" justamente porque o estilo não usava nada disso.

Frases como "o momento que todo mundo vai gravar" saíram do texto: só o clipe pode dizer se é verdade.

---

## 1. Finalista 1: **Tolda Viva** (base C, versão enxugada)

### Nome e frase

**Tolda Viva.** A tolda é a barraca de pano que serve de palco ao teatro de bonecos de luva; aqui, o palco está vivo e os jogadores o operam.

> **"Calce o boneco, abra o pano e brigue num palco que vocês mesmos operam: puxem as cordas, abram os alçapões e combinem cola, serragem, tinta e estalo contra as pragas que estão comendo o teatro, junto com até três amigos."**

Versão curta: *"Eu pinto, você estoura, e a gente derruba o palco em cima deles."*

**[red team] O eixo do pitch** é o que nenhum vizinho tem: **maquinaria de palco operada por duas pessoas** e **reação entre matérias de oficina**. A plateia e a troca de cenário à vista ficam como ambientação, não como mecânica.

### Como se joga

Você é um boneco de luva, com cabeça de madeira talhada, corpo de pano e um adereço do seu ofício (macete, agulhão, baladeira, broxa). Cada cena é uma arena de palco com 4 a 8 pragas (carunchos, traças, bastidores mofados) e duas peças de maquinaria à vista, como um contrapeso pendurado e um alçapão marcado com fita. Você golpeia com o adereço e aplica a sua **matéria de palco** (Linha, Goma, Serragem, Tinta ou Estalo). Cada aplicação deixa uma **demão**, mostrada por uma plaquinha de madeira sobre o inimigo. Quando um amigo acerta o mesmo alvo com outra matéria, sai uma **reação**: Serragem com Tinta vira **Machê** e o inimigo endurece para ser quebrado; Linha com Estalo vira **Rastilho**, uma faísca que corre por todos os amarrados. Três demãos de Tinta fazem o inimigo **"virar cenário"**: ele achata num recorte pintado e sai de cena. Entre as cenas, o cenário é trocado à vista, sem tela de carregamento. Um **ato** tem de 8 a 11 cenas geradas por regra e termina num chefe, em 14 a 20 minutos.

### O gancho co-op

**"A sua matéria prepara, a do amigo detona, e quem cai continua jogando dos bastidores."**

- **Reação cruzada.** Feita por duas pessoas, a reação tem força 1,0. **[red team]** Feita por uma pessoa só, tem força **0,5** (era 0,6). É incentivo, nunca trava.
- **Mira que procura o alvo do amigo.** **[red team]** No toque, a mira é automática. Sem ajuda, cada jogador miraria o inimigo mais perto dele e a combinação viraria acaso. Agora a mira automática **prefere o alvo preparado por outra pessoa**: um inimigo com demão de um amigo atrai a mira, e a plaquinha pisca na cor de quem preparou. Quem joga com controle ou mouse pode ignorar a preferência.
- **Maquinaria de duas pessoas, por posição.** **[mudança, ideia de D]** Na versão original, a maquinaria dividia o botão "Mão" com outras quatro ações, e com 4 jogadores amontoados quem queria puxar a alavanca acabava erguendo o amigo. Agora a maquinaria responde a **posição e golpe**: o alçapão abre quando alguém fica em cima do **pedal** e outro atrai inimigos para a tampa; a vara de manobra desce quando dois bonecos ficam em cima de dois pedais; o contrapeso cai quando alguém **golpeia a corda**. Não há botão novo, e a posição tolera a latência do celular.
- **Erguer e arremessar o amigo.** O botão **Mão** faz só coisas de contexto: erguer ou arremessar um boneco vivo, vestir um boneco caído e pegar objetos de cena (como o pote de Goma da fatia). Quem é carregado continua atacando de cima, com 1,5 m a mais de alcance. Arremessado, ele cai com uma **Queda de Palco**. No online, erguer e arremessar exige trocar quem controla o movimento entre aparelhos; isso é testado a 150 ms simulados antes de entrar (ver a fatia).
- **O Contrarregra.** Quem cai vira o **Contrarregra-jogador**: uma silhueta escura que os inimigos não veem, **com o símbolo de chão dele e uma lanterna e uma fita na cor do jogador** **[red team]**, para que o grupo saiba qual silhueta é o amigo. Ele opera a maquinaria na velocidade normal e puxa uma cortina lateral que bloqueia projéteis por 3 s. Ele volta de dois jeitos: um vivo o veste (2 s), ou ele junta 25 deixas sozinho e sobe por um alçapão.
- **Reviver sistêmico.** **[enxerto de A]** No conceito Rejunte, jogar água no herói caído revivia na hora. Aqui, **acertar a luva murcha com Linha costura o boneco de volta** e reduz o vestir de 2 s para 0,5 s. É fogo amigo útil, e dá à Retrós um papel de socorro.
- **Madeira viva, no lugar do Aplauso (marco 2).** **[red team]** O medidor de plateia saiu, porque Foul Play (2013) já tem um medidor de humor da plateia num brawler co-op de palco. A plateia continua só como som. No lugar, as **tábuas do palco racham**: cada queda de boneco e cada golpe pesado de inimigo que erra deixa uma tábua rachada, que atrasa quem passa. Reações cruzadas e maquinaria acionada em dupla **remendam** as rachaduras e enchem a **seiva do palco**, que mais tarde paga o Pano Rápido, o especial do grupo. Morrer, assim, sempre custa algo ao grupo. O "Bis!" saiu.
- **Placar de fim de cena.** **[enxerto de A]** "Pavio estourou o Tarugo 3 vezes." É rivalidade leve, sem punição.

**Sozinho: as duas mãos do bonequeiro.** O bonequeiro brinca com um boneco em cada mão. No solo você escolhe dois heróis: controla um, e a IA controla o outro. A **Troca de Mão** faz o ativo descer atrás do pano e o outro subir com um golpe de entrada. A reação montada assim conta como cruzada. A IA só aplica a própria matéria em alvos que você já marcou e obedece a um toque de "ping". **[red team]** No celular sem controle, este é o modo que cabe num aparelho só; o co-op entre pessoas no celular depende do online (ver a fatia).

### Heróis (4)

Cada um tem uma forma de cabeça desenhada por curva (o conserto que a prova pediu para o defeito de "totem"), um símbolo de chão (quadrado, triângulo, círculo, losango) e um corpo de pano de fundo escuro, para passar no teste de borrão. Cada herói aparece uma vez por grupo.

| Herói | Silhueta | Matéria de ofício | Ritmo de animação | Pulinho **[red team]** |
|---|---|---|---|---|
| **Tarugo**, o valentão | Bloco: cabeça cúbica chanfrada, queixo enorme, macete do tamanho do corpo | Serragem | Antecipação grande na forma e curta no tempo; o pano do peito estufa 15% | Baixo e pesado: altura pequena, ritmo lento, aterrissagem segurada 2 quadros com o peito afundando |
| **Retrós**, a costureira | Vertical: cabeça em carretel, coque espetado de alfinetes, agulhão maior que ela | Linha | A única linear: estocadas sem arco, ida e volta em 2 quadros, paradas secas | Curto e seco: pouca altura, ritmo rápido, sem inclinação |
| **Pavio**, o esperto | Pequeno e redondo: cabeça de cabaça, gorro comprido com pompom de pavio aceso | Estalo | Rei da sobreposição: o gorro atrasa de 3 a 6 quadros em toda virada | Alto e saltitante: o maior pulo do elenco, com o gorro chicoteando |
| **Mestra Anilina**, a pintora de telão | Larga e baixa: cabeça oval deitada, chapéu de feltro de aba enorme, broxa de cabo longo | Tinta | Arcos amplos e desaceleração longa; o oposto da Retrós | Balanço largo: pulo lento com inclinação de lado a lado |

A segunda matéria de cada herói começa como Goma e pode ser trocada na oficina. Os 12 adereços variantes usam o **esqueleto comum com o adereço preso ao osso da mão** **[enxerto de B]**, então variante nova custa malha, não clipe. **[red team]** Por isso a Tolda também recebe o **teste automático de colisão** da Tralha: em cada quadro de cada golpe, o adereço não pode entrar na cápsula do corpo nem passar do plano do chão (a prova anterior mostrou a espada atravessando o chão).

### Direção de arte: regras concretas

1. **Três materiais e uma regra para cada um.** Madeira (cabeça, mãos, pernas): **nunca deforma**, mostra facetas de talho e juntas. Pano (corpo, saia, chapéu): é o único que estica e comprime. Telão (cenário): pintado a têmpera sobre lona, com marcas de cerda e pincel seco que falha onde a trama é alta.
2. **Sem xilogravura, sem goiva, sem sertão, sem cordel, sem rima.** O mundo é inventado e feito de maquinaria de palco: pomar de luas penduradas, mar de rolos de onda, céu de varal.
3. **[mudança] Menos sinal de "São João".** Um juiz apontou que chita florida com zabumba, rabeca e pífano ainda diz "Nordeste junino" a qualquer brasileiro. Na versão enxugada:
   - **cada herói veste um tecido diferente** (Tarugo em xadrez escuro, Retrós em listrado de colchão, Pavio em poá, Anilina em chita de fundo escuro). A chita vira um tecido entre vários, não a estampa do jogo. Nenhum herói usa chita florida de fundo claro nem chapéu de palha, que eram a cara do boneco da prova anterior;
   - a tolda é de **lona listrada remendada**, como barraca de feira e de circo-teatro;
   - a trilha passa a ser **banda de circo-teatro**: trombone, clarinete, caixa, bumbo, realejo e xilofone de madeira nos golpes. Saem zabumba, rabeca e pífano. O Cordame fala por um **serrote musical**;
   - a checagem de 3 palavras reprova se aparecer, entre as duas primeiras, "cordel", "xilogravura", "nordestino", "São João", "junino" ou "forró" (e também "mamulengo", na variante sem referência regional).
4. **Paleta mestra de 24 cores** num único arquivo de paleta lido por todos os geradores e shaders (a prova tinha 51 cores espalhadas no código).
5. **Hierarquia de valor medida na prova:** telão claro e pouco saturado, meio em tinta média, chão de tábua com valor **entre** o dos heróis e o dos inimigos. **[red team]** O preto puro fica só no contorno dos bonecos e no aviso. Os contrarregras de cenário são **cinza-carvão, sem símbolo**; o Contrarregra-jogador tem símbolo, lanterna e fita na cor dele.
6. **Matizes reservados:** jogadores em magenta, ciano, amarelo-gema e verde-folha, sempre junto do símbolo de chão; perigo inimigo em vermelhão **com divisas** (padrão, não só cor); matérias lidas por forma e movimento (fio reto, gota que brilha, grão que cai, mancha, estrela de faísca).
7. **"O perigo encolhe, a ajuda cresce"** **[enxerto de D]**: toda telegrafia de inimigo é um anel ou faixa que se fecha; toda demão, reação e cura de herói é uma forma que se abre.
8. **Todo efeito é um objeto que poderia estar numa oficina** (papel de seda, confete, serragem, fio, borrifo, fumaça de estalo). Se não dá para dizer de que é feito, sai.
9. **Uma luz-chave fixa, sem sombra real na camada base.** A sombra multiplica por uma tinta, nunca é preta. As luas e a ribalta iluminam por um disco pintado no chão. No PC, sombra real e feixes das luas entram como extras.
10. **Olhos pintados animados por shader** **[enxerto de D]**: amêndoa com ponto de brilho, controlada por abertura e pupila, para piscar e reagir sem trocar textura. A boca continua sendo o maxilar articulado.
11. **Câmera de camarote** (perspectiva de 30°, inclinação de 38°, 15,5 m) no combate, medida na prova com 4 heróis e 20 inimigos. **Palco frontal** (7°) na troca de cenário, no diálogo e na entrada de chefe.
12. **[red team] A tolda nunca sai do quadro de combate.** A prova anterior admitiu que o camarote "perde a tolda": vistos de cima, são bonecos pequenos andando num chão. No combate ficam sempre: a **bambinela listrada na borda de cima** da tela, a **borda da empanada como moldura em primeiro plano** na borda de baixo (no máximo 6% da altura), e a **sombra da mão e da manga do bonequeiro** projetada no chão sob cada herói durante o pulinho. A checagem de 3 palavras roda também no quadro de estresse do camarote, e a meta é que "boneco" ou "teatro" apareça.

### Animação pelos 12 princípios

Regras de base: Blender e Godot a 60 fps, otimizador de animação desligado. O corpo anda em **poses seguradas** (15 poses por segundo na locomoção, 20 nos golpes, 1 quadro de borrão no impacto). O deslocamento é contínuo, então o comando responde no quadro seguinte. **O boneco não tem ciclo de passos:** ele é carregado pela mão do bonequeiro e anda num **pulinho contínuo feito por código**, com as pernas soltas balançando em mola. Isso elimina pé deslizando e ciclo de caminhada, os pontos em que a animação por script mais falha. **[red team]** Para o pulinho não sair igual em todo mundo, ele tem parâmetros por herói (altura, ritmo, inclinação e uma pose de aterrissagem segurada por 2 quadros; ver a tabela de heróis) e por família de inimigo.

| Princípio | Como aparece |
|---|---|
| 1. Comprimir e esticar | Só no pano: a saia vai a 1,12 × 0,86 na antecipação e 0,94 × 1,12 no impacto. A madeira nunca deforma. O chefe Cordame é todo madeira laqueada e não deforma nada, e essa rigidez é o contraste dele |
| 2. Antecipação | Heróis: 4 a 6 quadros. Inimigos: 24 a 54 quadros, sempre com a forma no chão. O fio do Cordame que estica e vibra é a antecipação da pisada (42 quadros) |
| 3. Encenação | O Bastidor Mofado vira a frente pintada para a câmera antes de tombar, e o retângulo do impacto aparece no chão. A entrada do chefe é em palco frontal, uma ação por vez |
| 4. Direto e pose a pose | Pose a pose em toda ação-chave. O enxame de carunchos é direto, por ruído em código. Na fase 3, o Cordame sem fios rasteja animado em uns, trêmulo |
| 5. Continuidade e sobreposição | Chapéu, saia e perninhas em mola; o gorro do Pavio atrasa de 3 a 6 quadros; os fios do Cordame vibram e se acalmam em 20 quadros |
| 6. Aceleração e desaceleração | Contraste como personalidade: a Retrós é linear e seca, a Anilina desacelera longamente. O Mané-Prego acelera o braço para o arremesso ficar legível no quadro 36 |
| 7. Arcos | A broxa e o macete traçam arcos largos. O mergulho da Traça é uma reta: **reta é perigo, arco é herói** |
| 8. Ação secundária | O maxilar bate com a voz de palheta; a Retrós ajeita os óculos parada; os olhos de flandres do Cordame giram para seguir as luas |
| 9. Tempo | Congelamento de impacto local de 3 a 5 quadros no golpe leve, 8 a 12 no pesado e 30 no golpe final do chefe. O Bastidor leva 48 quadros para cair e 6 para bater |
| 10. Exagero | Na queda, a cabeça salta 1,5 m e gira duas vezes; o caruncho atordoado fica de ponta-cabeça; a reverência do Cordame dobra o corpo em 90° |
| 11. Desenho sólido | Cabeças por curva de perfil, testadas girando 360°; silhueta única por inimigo, testada em preto chapado |
| 12. Apelo | Assimetria de 1 a 3% (um olho maior, tinta lascada num canto, alfinete torto). A vilã, a Desbrincada, "ferve" a cada quadro: quem está vivo por dentro anda em poses, quem está oco treme |

### 3 efeitos-assinatura

1. **Virou cenário.** Com 3 demãos de Tinta, o inimigo gira para a câmera e achata num recorte pintado com um "fump" de lona esticada. No golpe seguinte, dois contrarregras cinza-carvão entram correndo **pela coxia mais próxima, pelo caminho mais curto**, pegam o recorte pelas bordas e saem com passos exagerados, como quem carrega uma porta. Dura 1,2 s. **[red team]** Só um "virou cenário" com carregadores acontece por vez; os seguintes são puxados por uma corda até a coxia, o que é mais barato e enche menos a tela.
2. **Contrapeso.** A sombra do saco de areia cresce no chão com a fita de perigo, a corda assobia na roldana e o saco cai em 0,9 s. A juta arrebenta, a areia se espalha em anel e a câmera dá um tranco de 4 px para baixo. Sobre um alvo com Serragem, o dano dobra.
3. **Estouro (Serragem + Estalo).** Uma nuvem de pó incha por 6 quadros, como quem prende o fôlego, e estoura em confete de serragem colorida e cachos de maravalha. Congelamento de 10 quadros e um "PÁ" de bumbo grave.

### Fatia vertical **[red team: dividida em dois marcos]**

Um juiz apontou que a fatia original juntava sistemas demais, e o red team mostrou que a versão enxugada ainda tinha vários itens de uma semana de risco cada. A fatia agora tem dois marcos.

**Marco 1a** responde: **"Reação entre duas pessoas, palco operado em dupla e morte como contrarregra são divertidos, legíveis e cabem no aparelho do grupo?"**

| Item | Conteúdo |
|---|---|
| Heróis | Tarugo (Serragem) e Mestra Anilina (Tinta) |
| Matérias e reações | 3 matérias e 3 reações (Massa, Verniz, Machê), mais o "virou cenário". **[red team]** A Goma não é dada de graça aos dois: ela vem num **pote de cena** que qualquer um pega com o botão Mão e arremessa. O pote ganha a cor de quem o pegou, então fica claro quem preparou |
| Inimigos | Caruncho, Traça e Bastidor Mofado |
| Maquinaria | Só o contrapeso (golpe na corda) |
| Fases | 1 arena do Pomar das Luas, com a troca de cenário feita por corte de cortina (a troca animada à vista fica para depois) |
| Morte | Contrarregra com as duas formas de voltar |
| Modos | Solo com duas mãos (IA em Beehave, um addon grátis de árvores de comportamento) e, conforme a resposta à pergunta 1 da seção 5: **2 controles no PC** ou **online mínimo para 2 jogadores** (ver abaixo) |
| Controle por toque **[red team]** | 4 botões à vista: Golpe, Matéria, Pulo de Tolda e Mão (que só aparece quando há algo para pegar, erguer ou vestir). A Troca de Mão é um deslizar no retrato do segundo boneco; o ping é um toque duplo no inimigo. O layout é publicado com a fatia e testado em celular real: o polegar precisa alcançar tudo sem levantar a mão |
| Builds | Web (Compatibility, sem threads) e desktop (Forward+) |

**Se a resposta for "cada um no seu celular"**, o online sai do marco 2 e entra no 1a, para 2 jogadores: rede em estrela com WebRTC, o único transporte que funciona entre navegadores; a reação cruzada decidida no anfitrião, com janela de pelo menos 250 ms; e erguer e arremessar o amigo testados com 150 ms de atraso simulado. Atenção: ao contrário do que o red team supôs, o WebRTC **ainda não foi testado** no container (só ENet e WebSocket foram), e no 4G brasileiro, com operadoras que compartilham endereço, vai ser preciso um servidor de repasse (TURN) [pesquisa: `coop-rede.md`, seções 1 e 3]. Isso vira a primeira tarefa da fatia.

**Se a resposta for "PC com controles"**, o critério de 30 fps no celular sai da fatia, e entra o de 4 controles na mesma tela.

**Marco 1b:** o chefe Cordame numa fase só, com os fios feitos como ossos com mola (o antigo plano B vira o plano A), os nós, o ajoelhar ao cortar as duas pernas e a cruzeta segurada por dois que faz o chefe estapear a própria cara. Entram também o alçapão de pedal e a troca de cenário animada. A simulação de fio por partículas (verlet) só entra se medir menos de 2 ms por quadro no celular.

**Ficam para o marco 2:** Linha e a costura de reviver (dependem da Retrós), madeira viva e Pano Rápido, fases 2 e 3 do chefe, 4 jogadores online.

**Critério de aprovação [red team: medível]:**

- quadros por segundo **por faixa de aparelho**, como na tabela da seção 4 de `extra-contexto-real-celular-coop.md`: 30 fps estáveis com 10 a 12 inimigos visíveis num aparelho de entrada (classe Galaxy A06) e com 15 a 20 na faixa intermediária, sempre com o contador de draw calls na tela;
- **reações cruzadas de propósito, medidas por registro**: mais da metade das reações tem a segunda matéria aplicada por outra pessoa até 2 s depois de o alvo ser preparado; a parcela feita por uma pessoa só é registrada à parte;
- ninguém fica parado quando cai (tempo de Contrarregra sem nenhuma ação abaixo de 20%);
- a checagem de 3 palavras do grupo do usuário sem as palavras proibidas.

### Principais riscos

| Risco | Mitigação |
|---|---|
| **[red team] Lembrar jogos de palco e de bonecos que já existem.** Foul Play (Mediatonic, 2013) é um brawler co-op passado num palco de teatro, com cenário trocado atrás dos jogadores e medidor de humor da plateia. Puppeteer (Sony, 2013) tem troca de cenário à vista e reação de plateia. Segundo a busca do red team, em 2026 também existem PuppetOFF (palco de bonecos, 1 a 4 jogadores), Toypunk (roguelite co-op de bonecos), Puppeteer: No Strings Attached e Marionette, e Puppet Showdown (itch.io) é um brawler de boneco de luva com o jogador escondido embaixo do palco | O medidor de plateia saiu; a plateia é só som. O pitch passa a ser o que nenhum deles tem: maquinaria operada em dupla e reações entre matérias de oficina. A troca de cenário fica como ambientação. Conferir esses jogos de perto antes de fechar o desenho |
| Ainda lembrar Cordels & Spells ou "São João" para quem conhece a cena brasileira | Tecidos variados, banda de circo-teatro, mundo de maquinaria, lista ampliada de palavras proibidas. Se a checagem reprovar, a chita sai de vez. Se o usuário quiser menos Brasil, entra a variante "teatro de oficina" |
| O gerador de telão a têmpera nunca foi testado (a prova fez xilogravura) | É o item principal da prova de estilo abaixo. Se não passar, o telão vira cor chapada com recorte, que já funciona |
| **[red team] A identidade de teatro some na câmera de combate** | Regra 12 da direção de arte e checagem de 3 palavras no quadro de estresse |
| **[red team] Virar "um jogador vezes quatro"**: cada um mira o seu inimigo e as reações saem por acaso | Mira com preferência pelo alvo do amigo, força solo de 0,5, Goma em pote de cena, meta medida por registro |
| Sistemas demais para explicar | Fatia com 3 matérias, maquinaria sem botão novo, plaquinhas só no alvo mirado, saturação só na Tinta |
| **[red team] Celular de entrada** (classe Mali-G52 de 2 núcleos) com 10 a 12 inimigos, abaixo dos 16 prometidos antes. A prova anterior deu 153 a 155 draw calls no estresse, acima do teto de 100 a 150, e a queda para cerca de 80 com instâncias agrupadas é só estimativa | Medir as sombras e os efeitos agrupados (MultiMesh) antes de prometer número de inimigos; critério por faixa de aparelho |
| "Jogador usado como clava" pelo chefe e erguer o amigo no online | Troca explícita de quem controla o movimento, testada a 150 ms; a clava fica fora da fatia |
| **[red team] Pulinho igual para todos e adereço grande atravessando o corpo ou o chão** | Pulinho com parâmetros por herói; teste automático de colisão em cada quadro de cada golpe |
| Respeito ao mamulengo, que é tradição viva | Personagens 100% próprios, só a função dos tipos tradicionais, crédito explícito e conversa com um grupo de mamulengo antes de lançar |

### Prova de estilo: quadro, estresse e clipe

**"Virou cenário no Pomar das Luas."**

- **(a) Quadro bonito.**
  - **Cena.** Um praticável de tábuas de 18 × 12 m. Ao fundo, um **telão a têmpera** do Pomar das Luas, gerado pelo novo gerador de pinceladas: anil escuro, copas em verde-musgo, marcas de cerda e pincel seco sobre trama de lona. À frente dele, dois **bastidores recortados** de árvore. Três **luas de papel** penduradas por cordas, cada uma projetando um disco de luz pintado no chão. Um **contrapeso** pendurado sobre o centro, com a fita de perigo já no chão. A bambinela de lona listrada no alto do quadro e a borda da empanada embaixo.
  - **Câmera.** Camarote: perspectiva de 30°, inclinação de 38°, 15,5 m, 1280 × 720, renderer **Compatibility**.
  - **Personagens.** Tarugo (cabeça de bloco, corpo em xadrez escuro) no quadro de contato de uma marretada, com o quadro de borrão. Mestra Anilina (cabeça oval deitada, chapéu respingado) no fim de uma pincelada, com a tinta ainda voando. Seis carunchos, uma traça pairando e um Bastidor Mofado inclinado para trás, com o retângulo de impacto no chão.
  - **Efeitos.** Um caruncho já **achatado em recorte pintado**, com dois **contrarregras** cinza-carvão entrando da coxia para carregá-lo. Outro caruncho com 2 demãos de Tinta (pinceladas espessas e plaquinha com 2 entalhes). Estrela de papel de seda no impacto do macete, na cor do Tarugo.
- **(b) Quadro de estresse.** Os 4 heróis (com Retrós e Pavio), 20 inimigos, 3 reações ao mesmo tempo e um Contrarregra-jogador em cena.
- **(c) Clipe.** O "virou cenário" completo (do terceiro golpe de Tinta à saída pela coxia) e o pulinho de Tarugo e Anilina lado a lado, para ver se os dois andam de jeitos diferentes.
- **(d) Nível PC.** O quadro (a) com sombra real e feixes de luz das luas atravessando o pó.
- **O que precisa provar.**
  1. O telão a têmpera **não parece slop** e não lembra xilogravura: comparação lado a lado com a folha 4 da prova anterior, conferindo que a chita florida de fundo claro e o chapéu de palha sumiram.
  2. As cabeças por perfil já não leem como "totem", e cada herói tem cara própria.
  3. No quadro de estresse, os 4 heróis passam no **borrão** (diferença de claridade de pelo menos 0,12 entre herói e fundo) e se separam entre si em **deuteranopia e protanopia** com o símbolo de chão. A prova anterior falhou exatamente aqui (0,054 no borrão e diferença de cor de 0,006 entre jogadores em deuteranopia).
  4. O "virou cenário" é legível **no clipe**: quem olha entende que o inimigo virou peça de cenário.
  5. A paleta fica em **24 cores ou menos**; a camada base fica com diferença abaixo de 3 em 255 entre Compatibility e Forward+; o quadro (d) mostra um ganho visível.
  6. Na checagem de 3 palavras do grupo do usuário, nenhuma palavra proibida entre as duas primeiras, e "boneco" ou "teatro" aparecem no quadro de estresse.
  7. No celular real, o quadro de estresse fica dentro do teto de draw calls da faixa do aparelho.

---

## 2. Finalista 2: **Cacos de Cobalto** (base A, heróis invertidos, antes chamado Rejunte)

### Nome e frase

**Cacos de Cobalto.** **[red team]** "Rejunte" é palavra comum de loja de material de construção: difícil de achar numa busca e de registrar como marca. O nome reserva vira o principal. Os cacos pintados que o grupo junta restauram o painel da taberna; o **rejunte**, a massa entre os azulejos, continua sendo o coração do jogo, agora como sistema.

> **"Um co-op de 1 a 4 onde o chão é de azulejo e o choque, a cal e o fogo correm pelas juntas: molhe, unte, sopre e eletrifique uma cidade portuária inteira, de preferência sem eletrocutar o amigo."**

Versão curta: *"Você molha, eu eletrifico. Às vezes, você também."*

### Como se joga

Você é uma figura pintada que se descolou de um painel de azulejos para salvar Porto Cobalto, uma cidade portuária inventada. Cada herói lança uma **matéria** (Brasa, Cal, Lufada ou Faísca, e Óleo como secundária): toque para arremessar, segure para um jato. O que você joga fica **no chão**, numa grade de células de 0,5 m: o azulejo fica molhado de cal, untado, em chamas ou com salitre, e lembra disso até o fim da sala.

**[red team] O rejunte é o sistema.** O choque, a cal e o fogo **correm pelas juntas** entre os azulejos, não por um círculo em volta do alvo. E cada sala tem um **padrão de assentamento** que muda a forma de propagar: na **junta corrida**, as linhas são longas e o choque dispara em linha reta; na **amarração** (juntas desencontradas), ele anda em zigue-zague e mais devagar; no **assentamento diagonal**, ele corre em diagonal. Um golpe pesado **quebra o azulejo** e corta a junta, o que interrompe a propagação; a Cal **rejunta**, criando caminho novo. Ler e mudar as juntas é a parte que não existe em Magicka nem em Divinity: Original Sin 2.

As combinações acontecem no mundo: Cal com Faísca é **Condução**, um choque que corre pelo rejunte de toda a área molhada e pega quem estiver dentro, amigo incluído; Brasa com Óleo é **Incêndio** em cadeia; Óleo com Faísca é **Isolante**, que protege quem está untado. O ciclo é **preparar, detonar e sair da área**. Uma expedição tem de 5 a 7 salas e um chefe, em 14 a 18 minutos. Os cacos pintados ganhos restauram o painel da taberna, onde o progresso fica visível na parede.

### O gancho co-op

**"Eu preparo o chão, você detona, e o mesmo sistema que machuca o amigo também protege."**

- **Isolante:** untar o amigo antes de eletrificar a poça com ele dentro. Um protege, o outro ataca.
- **Abrir e fechar caminho:** um quebra a junta para proteger o grupo, o outro rejunta com Cal para levar o choque até o inimigo.
- **"Banho":** acertar o aliado com a sua matéria unta a mão dele, e o próximo arremesso dele leva as duas matérias.
- **Reações duplas:** duas pessoas lançando a mesma matéria no mesmo lugar, com até 0,4 s de diferença, fazem uma versão maior (Brasa com Brasa é Fornalha).
- **Passe de objeto.** **[enxerto de B]** Barril, balde e garrafa de faísca podem ser arremessados para o amigo. Quem pega no ar **carrega o objeto com a própria matéria** (o balde de Cal, recebido pelo Seu Galvão, vira um balde elétrico). É o passe de Tralha da Cheia, traduzido para matéria.
- **Morte ativa: voltar para a parede.** **[mudança, ideia de C; red team]** O caído não se parte em cacos (essa é a imagem central de Kiln). Ele **achata e volta a ser pintura** no azulejo mais próximo. Como pintura, ele corre pelo chão de azulejo em azulejo, invisível aos inimigos, e **opera o ambiente**: abre chafariz e comporta, rola barril, vira garrafa. Com o tempo, a pintura **desbota**, e isso mostra quanto falta para ele precisar de ajuda. Reviver continua barato (1,5 s para um vivo descolá-lo do chão), e jogar Cal na pintura revive na hora, porque "a cal fixa a pintura".
- **Placar de fim de sala:** "Galvão eletrocutou Bento 3 vezes".

**Fogo amigo** **[mudança]**: o padrão é **consequência inteira e dano zero** (molhar, untar, empurrar e eletrocutar valem; a vida não cai). Os 30% de dano viram opção, para grupos de amigos que querem o caos de Magicka.

**Sozinho:** dupla obrigatória. Você controla um herói e a IA controla o outro, com troca a qualquer momento. A IA **prepara e você detona**, e um toque de "ping" diz o alvo.

### Heróis (4)

| Herói | Silhueta | Matéria | Ritmo de animação |
|---|---|---|---|
| **Tia Lamparina**, cozinheira | Pera larga com lamparina de cabo longo no ombro | Brasa | Peso e atraso: o avental chega 4 a 6 quadros depois do corpo; antecipação mais curta do elenco |
| **Bento Rodo**, caiador de calçada | Linha vertical alta, rodo em T e balde de cal | Cal | Arcos limpos e precisos; perde a compostura só quando é untado e se sacode de forma direta |
| **Nina Catavento**, criança do cais | Dois círculos: corpo pequeno e cata-vento gigante nas costas | Lufada | A mais rápida, com o cata-vento girando na velocidade dela e parando passando do ponto |
| **Seu Galvão**, faroleiro | Ponto de interrogação: corcunda, garrafa de Leyden nas costas, vareta de cobre | Faísca | Contraste de tempo: preparo lento, quase cochilando, e estalo de 2 quadros |

**[mudança] Variedade.** A secundária de cada herói pode ser trocada no azulejeiro ambulante (ideia da oficina de C), e os azulejos de padrão podem mudar o verbo de uma matéria ("a condução também salta por óleo"). Assim a dupla de jogadores não define sozinha quais reações existem. **[red team]** Cada herói aparece uma vez por grupo, então dois jogadores nunca têm a mesma matéria principal.

**[red team] Identidade de cada jogador.** Antes, os 4 heróis eram todos azul-noite e o único acento era a cor da matéria, a mesma cor do chão que ele mesmo cria: o herói se misturava à própria poça. Agora valem as regras da Tolda: **símbolo de chão por jogador** (quadrado, triângulo, círculo, losango) e um **anel na base e cor do nome** em matizes fora da família das matérias (magenta, ciano, lilás e branco com borda preta). A forma do símbolo é o que garante a leitura em daltonismo; a cor é reforço.

### Direção de arte: regras concretas

1. **Três materiais, só três.** Faiança pintada (mundo e heróis); materiais do porto (madeira de cais, corda, lona, ferro), foscos e sem pintura; e Salitre (o inimigo), branco-acinzentado, granulado e fosco.
2. **[mudança] O herói é o negativo do mundo.** Os juízes apontaram que heróis de louça branca sobre um mundo branco e azul repetem a falha medida na prova (heróis claros sobre fundo claro somem no borrão). Agora **o mundo é branco pintado de cobalto, e os heróis são esmalte azul-noite pintado de branco**, com um acento na cor da sua matéria e o anel do jogador na base. A massa escura passa no borrão, a regra tem lógica de ofício (é a técnica do fundo azul com reserva branca) e o herói se acha num relance.
3. **A cor da matéria vem dos pigmentos históricos de azulejo:** laranja-ferro (Brasa), verde-cobre (Cal), amarelo-antimônio (Faísca), castanho-manganês (Óleo), branco-leite com borda roxa (Lufada). **"Se tem cor quente, interage."** Nenhuma decoração estática usa essas cores, nem o anel de jogador.
4. **Perigo só em vermelho-lacre**, a única cor quente fora da paleta de pigmentos, sempre como forma que se fecha **[enxerto de D]**.
5. **Estados do chão com forma, não só cor:** molhado tem brilho e ondulação; untado, borda furta-cor; fogo, pincelada vertical; choque, rejunte aceso; salitre, textura granulada.
6. **[mudança] Pincel com ambição medida.** O gerador de pincel simula carga de tinta (o traço começa carregado, afina e deixa uma poça de pigmento onde para). Padrões de piso e parede saem de **12 estruturas geométricas** reais, estampilhadas com erro de registro de 1 a 2 px, o que é viável. Os painéis figurativos ficam **raros e compostos por uma biblioteca de motivos** (barco, onda, peixe, nuvem, gaivota, casa) desenhados por regra, não "qualquer cena". Os rostos dos heróis são **3 traços controlados por shader** **[enxerto de D]**, sem pintura figurativa sobre o volume.
7. **Assentamento imperfeito com causa:** cada azulejo tem desvio de ±1 mm e ±0,8° e inclinação de até 1,5° no brilho, que esmaece com a distância para não cintilar no celular. O padrão de assentamento de cada sala é visível de longe, porque é regra de jogo.
8. **Uma luz-chave** (sol de fim de tarde a sudoeste). A sombra multiplica por cobalto. Proibido degradê liso, que faz faixas na Web.
9. **Checagem interna:** no máximo 2% dos pixels fora da paleta de 22 cores e no máximo 2% do mundo com saturação acima de 0,15.
10. **[mudança] Câmera de camarote** (perspectiva de 30°, inclinação de 40°, cerca de 16 m), no lugar dos 52° a 22 m do conceito original. Os heróis passam de 60 a 70 px para cerca de 110 a 150 px de altura em 720p, e a grade do chão ainda lê como mapa.
11. **[red team] Clarões só locais.** A inversão de cor da Condução acontece só no personagem atingido, nunca na tela inteira, e no máximo 2 personagens invertem ao mesmo tempo. A opção "reduzir clarões" vem ligada por padrão no celular.

### Animação pelos 12 princípios

Regras de base: heróis com golpes a 30 poses por segundo (uma pose a cada 2 quadros) e locomoção suave; inimigos a 20 poses por segundo, o que dá o "clac-clac" de azulejo; chefe a 15. Pose de impacto segurada por pelo menos 2 quadros, para aparecer mesmo a 30 fps.

| Princípio | Como aparece |
|---|---|
| 1. Comprimir e esticar | **[mudança, regra de C]** Louça não estica. O comprimir fica no que é pano (avental, lenço, saia) e no cata-vento. O corpo "comprime" por **trinca**: 2 quadros de compressão e uma rachadura desenhada que some |
| 2. Antecipação | Heróis de 3 a 6 quadros; o Seu Galvão é a exceção cômica, com 20 quadros na habilidade. Inimigos de 24 a 42 quadros, sempre com a forma no chão |
| 3. Encenação | Toda pose de golpe é lida de cima: braço e matéria abertos para fora do corpo. O Ladrilheiro Torto vira de frente para a câmera ao erguer o painel |
| 4. Direto e pose a pose | Golpes pose a pose; a sacudida do Bento untado é direta. O desmoronamento do chefe é simulado com instâncias agrupadas |
| 5. Continuidade e sobreposição | Avental, balde, cata-vento e garrafa chegam de 4 a 8 quadros depois do corpo, por osso de mola |
| 6. Aceleração e desaceleração | Locomoção com aceleração em 4 quadros e freada em 6; a Crosta acelera devagar e freia de repente |
| 7. Arcos | O rodo do Bento traça um arco perfeito antes do golpe; todo arremesso tem parábola visível com sombra-bolha |
| 8. Ação secundária | A Lamparina tamborila os dedos; o Galvão coça a orelha com a vareta; o rosto pintado do chefe acompanha o jogador mais próximo |
| 9. Tempo | Cada herói tem um tempo próprio (Lamparina rápida e pesada, Bento regular, Nina frenética, Galvão lento com estalo) |
| 10. Exagero | **[red team]** Ao reviver, a pintura se descola do chão **errada** por 4 quadros (de ponta-cabeça) e se corrige com um "plim" de louça |
| 11. Desenho sólido | Volumes chanfrados, girados 360° na revisão; o painel do chefe mostra o reboco atrás ao se curvar |
| 12. Apelo | Rosto de 3 traços com 8 expressões por parâmetro; Descascados com a pintura remontada torta |

### 3 efeitos-assinatura

1. **Condução.** A área molhada escurece e ganha brilho. Um raio amarelo-antimônio corre **pelas linhas de rejunte**, junta por junta, seguindo o padrão de assentamento da sala. Cada vítima trava 4 quadros e, por 2 quadros, a pintura **dela** inverte de cor, como um negativo (no máximo 2 vítimas invertidas ao mesmo tempo). O som se desloca no estéreo seguindo o raio.
2. **Incêndio de óleo.** A frente de fogo avança célula por célula num "fuuump" em cadeia, com o tom subindo. As chamas são pinceladas laranja em 8 quadros desenhados, e o azulejo embaixo fica com **craquelado queimado** até o fim da sala.
3. **Voltar para a parede.** **[red team: substitui "cair em cacos"]** O herói perde o volume em 8 quadros e achata como um decalque no azulejo mais próximo, com um "tlec" de louça. A pintura dele **desbota** em ondas, azulejo por azulejo, de azul-noite para azul-claro. Ao reviver, a figura se descola do chão como uma folha, monta errada por 4 quadros e se corrige.

### Fatia vertical: "Cais da Salga, maré baixa"

| Item | Conteúdo |
|---|---|
| Heróis | Tia Lamparina (Brasa) e Bento Rodo (Cal) |
| Matérias e reações | 4 matérias (Faísca e Óleo como secundárias) e 9 reações: Vapor, Estalo, Incêndio, Condução, Mancha, Isolante, Fornalha, Alagar e Estouro de salitre |
| Padrões de assentamento | Junta corrida e amarração |
| Inimigos | Lasca, Ladrilheiro Torto e Crosta |
| Salas | 3 moldes do Cais, um com a maré que sobe |
| Chefe | O "Painel do Armazém": versão menor da Fachada que Andou, com 150 azulejos, 2 ataques e 3 zonas de salitre |
| Co-op | Solo com IA e troca; e, conforme a pergunta 1 da seção 5, 2 controles no PC ou online mínimo para 2 |
| Morte | Voltar para a parede, operar o ambiente, reviver por Cal |
| Critério de aprovação | Quadros por segundo por faixa de aparelho, com o contador de draw calls na tela; pelo menos 4 reações cruzadas por minuto, medidas por registro; num quadro de estresse com **4 heróis e 20 inimigos**, cada jogador acha o próprio herói em menos de 1 s; pelo menos um "lembra quando..." por sessão |

### Principais riscos

| Risco | Mitigação |
|---|---|
| **O pincel procedural é fraco** (o maior risco de arte, segundo o próprio conceito) | É o centro da prova de estilo. Se não passar, o jogo não segue nesta direção |
| **[red team] Núcleo de magia parecido com Magicka e Divinity: Original Sin 2** (molhado com raio, óleo com fogo) | A propagação pelo rejunte e o padrão de assentamento são o diferencial; a água virou Cal, que rejunta e fixa a pintura |
| Caos ilegível com 4 jogadores no celular | Heróis em negativo, anel e símbolo de jogador, câmera de camarote, efeitos de aliados a 40%, estados do chão por forma, Condução limitada a 60 células |
| Grade com cara de tabuleiro | Borda dos estados com ruído ao longo do rejunte; espalhar contínuo no shader, mesmo com lógica discreta |
| Cintilação do brilho por azulejo em resolução reduzida | Brilho que esmaece com a distância e limite na variação de inclinação |
| **[red team] Custo no celular**: brilho por azulejo e a textura de dados no piso somam ao custo do contorno | Medir no aparelho real na prova; o brilho por azulejo pode ficar só no nível PC |
| Pouca variação entre partidas | Secundária trocável, azulejos de padrão que mudam o verbo, padrões de assentamento, 17 reações no jogo completo |
| **[red team] Colidir com Kiln** (Double Fine, lançado em abril de 2026, brawler de cerâmica com potes que se quebram) | Nada de vaso, torno, forno ou esmalte como matéria. A morte em cacos saiu; o herói volta a ser pintura. Os cacos aparecem só como recompensa que restaura o painel |
| Azulejo carrega passado colonial | Cidade inventada, nenhuma figura histórica, inspiração só na técnica |

### Prova de estilo: quadro, estresse e clipe

**"Condução no Cais da Salga."**

- **(a) Quadro bonito.**
  - **Cena.** Um trecho de cais de 18 × 12 m. O chão é de **azulejo estampilhado** com a estrutura de ponta de diamante, em **junta corrida** numa metade e **amarração** na outra. Ao fundo, a parede de um armazém com um **painel figurativo de 2 × 1 m** (barco na tempestade, montado pela biblioteca de motivos) e a placa pintada "Rua da Salga" numa fonte de licença livre. Um barril de óleo, uma carranca de chafariz e um poste de corda e rede. No canto, um trecho de chão com **craquelado queimado** e outro com **crosta de salitre**, mostrando a memória da sala.
  - **Câmera.** Camarote: perspectiva de 30°, inclinação de 40°, cerca de 16 m, 1280 × 720, renderer **Compatibility**.
  - **Personagens.** **Bento Rodo e Tia Lamparina em negativo** (esmalte azul-noite com pintura branca, acento verde-cobre e laranja-ferro, anel de jogador na base). Bento está **dentro** da área molhada, untado (borda furta-cor), ileso. Lamparina está fora, na pose de lançar. Três Lascas, um Ladrilheiro Torto e uma Crosta salitrada.
  - **Efeito.** A **Condução** no meio do caminho: o raio amarelo corre pelo rejunte e muda de forma ao passar da junta corrida para a amarração; duas Lascas estão no quadro de "negativo"; Bento segue intacto por estar untado. Uma telegrafia vermelho-lacre da Crosta se fecha no chão.
- **(b) Quadro de estresse.** 4 heróis, 20 inimigos, uma Condução e um Incêndio ao mesmo tempo, e um herói caído como pintura no chão.
- **(c) Clipe.** A Condução correndo pelas juntas nos dois padrões de assentamento, e o "voltar para a parede" com o reviver.
- **(d) Nível PC.** O quadro (a) com sombra real e reflexo do sol no chão molhado.
- **O que precisa provar.**
  1. O **pincel e a estampilha** não parecem slop. O painel e o piso são comparados lado a lado com 3 fotos de azulejo real, fornecidas pelo usuário ou tiradas de um conjunto de imagens de licença livre hospedado no GitHub (os sites de imagens estão bloqueados aqui).
  2. Os **heróis em negativo** passam no borrão (diferença de claridade de pelo menos 0,12) e, no quadro de estresse, os 4 se separam entre si em cinza, em miniatura de 320 × 180 e em deuteranopia e protanopia.
  3. Os **estados do chão** (molhado, untado, queimado, salitre, choque) são distinguíveis em cinza e em deuteranopia, só pela forma.
  4. A grade **não tem cara de tabuleiro**, e a diferença entre os padrões de assentamento se lê de longe.
  5. A ideia "o amigo untado não leva o choque" é **legível no clipe**.
  6. Paleta dentro das 22 cores; camada base com diferença abaixo de 3 em 255 entre Compatibility e Forward+. A cintilação do brilho é julgada no clipe.

---

## 3. Finalista 3: **Tralha da Cheia** (base B, animação refeita)

### Nome e frase

**Tralha da Cheia.** "Tralha" é cacareco e também o equipamento de pesca; "cheia" é a enchente do rio. Nome para a loja em inglês: *Floodhaul*.

> **"O rio subiu e trouxe de tudo. Pegue um remo, um anzol ou uma âncora, passe a arma para o amigo no meio do golpe e quebre tudo rio abaixo."**

### Como se joga

Você é um boneco de miriti, leve, facetado e pintado à mão, num rio de palafitas que não baixou. Você luta com o que a enchente trouxe: remos, ganchos, malhos, redes, âncoras e mais 3 famílias de armas, 40 armas no jogo completo. Cada família tem um combo leve, um golpe pesado que **marca** o inimigo (enganchado, tonto, amarrado ou atolado) e um arremesso. Duas marcas diferentes no mesmo inimigo dão uma **reação**: tonto com enganchado é a **Fisgada**, e o próximo puxão arremessa o inimigo contra os outros. **A arma acaba:** cada uma tem um número de golpes, e o último é a **Despedida**, um estouro em lascas pintadas com o maior impacto do jogo. Quebrar não é castigo; cada arma quebrada deixa uma lasca no **Mural**, e com três lascas ela pode sair como arma inicial. Uma expedição desce um trecho do rio em 9 a 11 salas e termina num chefe, em 12 a 18 minutos.

### O gancho co-op

**"A arma melhora quando passa de mão."**

- **Passe e recepção.** Você arremessa a arma para o amigo. Ela voa em 0,45 s, e quem pega tem 1,5 s para soltar o **golpe de recepção**: o finalizador da família, com 50% a mais de dano e marca garantida.
- **[mudança] Passe para quem pediu.** Com 4 pessoas, o passe automático para "o mais próximo" ia para a pessoa errada. Agora o passe vai **na direção mirada** (analógico direito, ou arrastar até o retrato do aliado no toque) e, sem mira, para **quem apertou "me passa!"** por último. Pedir a arma vira parte da conversa do grupo.
- **Tralha Grande.** Âncora de balsa, remo de batelão, canoa virada. Uma pessoa só arrasta. **[mudança, ideia de D]** Duas pessoas erguem e o golpe sai quando as duas estão **nas duas pontas marcadas no chão**, não quando apertam dentro de 0,3 s. Posição tolera a latência; fora de posição, o golpe sai fraco e engraçado.
- **Gaiola.** O inimigo Gaiola prende um jogador, que só sai com a ajuda de outro, mas continua arremessando de dentro.
- **Boia.** Quem cai não morre: boia, porque miriti flutua. A Boia nada, **apita** para atrair inimigos e pega e devolve passes. **[red team]** Para reviver, um amigo **lança uma linha de pesca** até a Boia e puxa. A água tem marolas que sobem e descem num ritmo visível; puxar quando a Boia está na crista revive na metade do tempo. A janela é larga (meio segundo), para tolerar a rede.
- **[enxerto de A] O rio tem memória.** O chão de palafita guarda estados numa textura de dados: água rasa (escorrega e espirra), lama (atola) e breu (gruda). Quem derruba a Tralha Grande na água levanta uma onda que empurra todos, inimigos e amigos. Isso traz de volta parte do caos físico que os juízes sentiram falta.
- **Placar de fim de sala** **[enxerto de A]**: "Piaba lançou a Marola no rio 4 vezes".

**[mudança] Sozinho no celular: passe-troca como padrão.** Um juiz apontou que passar a arma para um robô que sempre pega vira rotina. No solo, você controla dois heróis: arremessa a arma e, no ar, **assume o outro herói** para pegá-la e soltar a recepção você mesmo. O momento continua sendo seu. O parceiro de IA autônomo fica como opção.

### Heróis (4)

**[mudança]** Os quatro dividem o mesmo esqueleto, mas o comprimento dos ossos varia no máximo 15% entre eles. A diferença de silhueta vem da cabeça, do chapéu e dos objetos, não de membros muito diferentes. Isso evita a arma atravessando o corpo quando o mesmo golpe é reaplicado.

| Herói | Silhueta | Papel | Ritmo de poses **[enxerto de D]** |
|---|---|---|---|
| **Tiá Marola**, estivadora | Trapézio: ombros largos, lenço com duas pontas, caixote nas costas | Carrega Tralha Grande sozinha a 70%; não é interrompida ao receber passe | **15 poses/s**, antecipação longa, contato sem tremor |
| **Seu Remanso**, balseiro | Linha vertical: chapéu cônico de palha alto e zinga apoiada no ombro | +25% de alcance em armas longas; salta sobre inimigos | **12 poses/s** na locomoção e nas esperas longas; **20 poses/s** no contato, que é súbito |
| **Piaba**, mergulhador | Bola: máscara de mergulho enorme, pés de pato, **boia de câmara de ar** na cintura | Pega arremessos de longe; mergulha e reaparece 6 m à frente | **30 poses/s**, arcos largos e quique ao parar |
| **Mestra Breu**, calafate | Assimétrica: um braço com luva de couro enorme presa a um malho, balde de breu na cintura | Conserta a arma dos aliados; área de breu que atola | **20 poses/s**, peso sempre do lado da luva |

### Direção de arte: regras concretas

1. **Material: brinquedo de miriti.** Toda forma é **facetada a faca** (6 a 12 cortes planos por peça, semente fixa); proibido esfera lisa e cápsula. Personagem em **peças rígidas, um osso por peça**, com junta à mostra.
2. **[mudança, regra de C] Miriti nunca dobra.** Só esticam e comprimem o que é pano ou borracha: lenço, saia, redes, a boia de câmara de ar do Piaba. O comprimir do Piaba mora na boia, não no corpo.
3. **Superfície fosca:** rugosidade máxima, sem brilho especular, poro do miolo visível só de perto. Nunca brilho plástico, que é o que faria o jogo parecer "casual de celular".
4. **No máximo 3 tintas por peça**, padrões pintados (bolinhas, listras, escamas, folhas) com tremor de pincel, e **a tinta falha nas arestas mais expostas**, mostrando o creme cru do miriti.
5. **A água é faixa pintada** em 3 tons chapados, com marolas recortadas que sobem e descem em degrau. Nunca água realista.
6. **[mudança] Paleta em três famílias, sem cor solta.** Cenário em miriti cru e tinta desbotada (saturação até 30%); heróis em tinta nova e saturada, com uma massa escura no pé; inimigos com tinta descascada e um só ponto de cor (o olho). **Os efeitos usam a cor de quem os fez**, e não existe mais uma paleta de efeitos à parte. **[red team]** Cada jogador tem também o símbolo de chão (quadrado, triângulo, círculo, losango), como na Tolda.
7. **Perigo em faixa listrada preta e amarela**, como pintura de aviso de cais. É padrão, não só cor, e é sempre uma forma que se fecha **[enxerto de D]**.
8. **Rosto por shader** **[enxerto de D]**: olhos de ponto pintado e boca em traço, controlados por parâmetro; o Piaba se expressa pela máscara que embaça ou brilha.
9. **Um gerador de facetas e um shader-base para tudo:** heróis, inimigos, armas, cenário e ícones da interface saem do mesmo módulo.
10. **Respeito ao miriti:** nenhum santo, berlinda, procissão ou elemento religioso; nenhuma peça copiada de brinquedo existente; crédito explícito a Abaetetuba e conversa com artesãos antes de lançar.
11. **Câmera de camarote** (30°, 38°, 15,5 m) no combate; palco frontal na abertura e no fim de chefe.
12. **[red team] Clarões só locais.** Na Despedida, só a arma e o alvo viram 2 tons, nunca a tela inteira. No máximo uma piscada de tela a cada 2 s no grupo todo, e a opção "reduzir clarões" vem ligada por padrão no celular.

### Animação pelos 12 princípios

**[mudança] O conserto principal.** No original, um conjunto de golpes por família de arma era reaplicado aos quatro heróis, o que gera **uniformidade**, o maior sinal de animação gerada. A versão nova mantém a economia, mas acrescenta camadas por herói:

- **Ritmo próprio:** as mesmas poses-chave são tocadas no ritmo de cada herói (15, 12/20, 30 e 20 poses por segundo, com esperas e antecipações diferentes). Isso muda o ritmo, mas não a silhueta; por isso vêm as duas camadas seguintes.
- **[red team] Duas poses próprias por herói em cada família:** a **antecipação** e o **contato** são desenhados para cada herói. São 8 famílias × 4 heróis × 2 = **64 poses**, não 64 clipes. A recuperação continua comum.
- **[red team] Dano preso à pose:** a área de dano do golpe liga no quadro em que a pose de contato aparece, e não num tempo fixo do clipe. Assim o dano nunca fica desencontrado da imagem, nem no herói de ritmo mais lento.
- **Teste automático de colisão:** em cada quadro de cada golpe, a malha da arma não pode entrar na cápsula do corpo nem passar do plano do chão.

| Princípio | Como aparece |
|---|---|
| 1. Comprimir e esticar | Só no pano e na borracha: a boia do Piaba estica a 1,4 no mergulho e achata a 0,7 na queda. O inimigo Bucho incha de 1,0 a 1,3 antes do bote |
| 2. Antecipação | Heróis de 3 a 5 quadros, com pose própria; a Marola é a exceção, com 8 quadros no pesado. Inimigos de 24 a 48 quadros, com faixa no chão e som no fim da espera |
| 3. Encenação | O golpe de recepção ganha 4 quadros de zoom leve no recebedor, para todos verem quem pegou. O Capataz vira o escudo para a câmera antes do golpe |
| 4. Direto e pose a pose | Pose a pose em todos os golpes. Direto só nas placas de tinta que soltam do chefe na morte |
| 5. Continuidade e sobreposição | A arma passa do alvo de 15 a 30°; as pontas do lenço da Marola e o chapéu do Remanso chegam de 3 a 6 quadros depois |
| 6. Aceleração e desaceleração | A Lata-Velha acelera no rolo e para seco ao bater na parede, sem desacelerar |
| 7. Arcos | O remo traça arco largo e plano; o malho, arco vertical alto; a arma arremessada segue parábola visível |
| 8. Ação secundária | O balde da Mestra Breu pinga em degrau e mancha o chão; a máscara do Piaba embaça quando ele apanha |
| 9. Tempo | Ritmo de poses diferente por herói; congelamento de impacto de 3 a 4 quadros no leve, 10 a 14 no pesado e 14 na Despedida |
| 10. Exagero | No contato, o braço estica 15% além do comprimento real por 1 quadro; o Bucho estoura achatado como uma panqueca |
| 11. Desenho sólido | Peso que se desloca de verdade: a Mestra Breu sempre inclinada para o lado da luva; toda peça facetada tem volume |
| 12. Apelo | Silhuetas que se reconhecem na miniatura de 320 × 180 (trapézio, linha, bola, assimetria); a chefe Garça é bonita e, quando perde, volta a ser garça e vai embora |

### 3 efeitos-assinatura

1. **Despedida.** No contato, a imagem congela por 14 quadros. A arma treme e racha em linhas claras **ao longo das próprias facetas**. Num quadro, a arma e o alvo viram 2 tons. A arma explode em 18 a 30 lascas pintadas nas cores dela, que quicam duas vezes; uma lasca brilha e voa para o Mural. Som: estalo de madeira leve e um glissando de marimba.
2. **Pegada no ar.** A arma chega girando com um rastro de fita na cor de quem lançou. Na pegada, um anel achatado na cor de quem pegou se abre no chão, a boia ou a saia do recebedor comprime, e um acorde curto de metais sobe meio tom a cada passe seguido na mesma sala. A sala vira música.
3. **Golpe da Tralha Grande.** As duas pessoas nas pontas: câmera lenta de 0,5× por 6 quadros, os dois anéis de jogador se fundem num só, um anel recortado se abre no chão e as tábuas do piso pulam em sequência a partir do impacto. Na água, levanta uma coroa recortada de 6 pétalas. **[red team]** A distorção da tela fica só no nível PC, porque no celular ela exige copiar a tela inteira a cada quadro.

### Fatia vertical

| Item | Conteúdo |
|---|---|
| Heróis | Tiá Marola e Piaba, os dois extremos de massa e de ritmo |
| Armas | 3 famílias (Remos, Ganchos, Malhos) com 2 armas cada, Despedida e Mural |
| Marcas e reações | Atolado, Enganchado e Tonto, com Fisgada, Atracado e Estaca |
| Tralha Grande | Âncora de Balsa |
| Inimigos | Bucho, Gaiola e Lata-Velha |
| Salas | 1 trecho do Trapiche Velho: 6 salas geradas e 1 oficina |
| Chefe | Garça-Guindaste nas fases 1 e 3 (a fase 3 é a Âncora contra o pé dela) |
| Modos | Solo com passe-troca; e, conforme a pergunta 1 da seção 5, 2 controles no PC ou online mínimo para 2, com o passe decidido no anfitrião |
| Critério de aprovação | Quadros por segundo por faixa de aparelho; o teste de colisão arma × corpo × chão sem falhas nos 2 heróis; passes de propósito na segunda sala, medidos por registro (passe pedido ou mirado, e não para "o mais próximo"); checagem de 3 palavras do grupo do usuário sem "plástico", "casual" ou "Lost Castle" |

### Principais riscos

| Risco | Mitigação |
|---|---|
| Animação corpo a corpo com cara de gerada (uniformidade) | Ritmo, antecipação e contato próprios por herói, dano preso à pose, proporções próximas, teste automático de colisão |
| Volume de polimento: 56 clipes de arma e 64 poses próprias | 3 famílias na fatia; família nova só entra com Despedida, som e recepção prontos |
| Passe com pegada no ar e Tralha Grande na rede, com 150 ms | Passe decidido no anfitrião com janela de 300 ms; Tralha Grande por posição |
| Ler como "jogo casual de celular" numa captura parada | Fosco absoluto, facetas visíveis, tinta que falha, paleta em três famílias |
| **[red team] Câmera lenta e clarões no celular** | Distorção só no PC; clarões locais e limitados |
| Ficar parecido com Tolda Viva (dois mundos de bonecos pintados) | Só importa se os dois forem feitos. A diferença é real: miriti facetado no rio contra madeira e pano no palco |
| Apropriação de um artesanato vivo de Abaetetuba | Peças originais, nada religioso, crédito e conversa com artesãos |

### Prova de estilo: quadro, estresse e clipe

**"O passe no Trapiche Velho."**

- **(a) Quadro bonito.**
  - **Cena.** Um trapiche de palafitas de 18 × 12 m, com tábuas facetadas e pintura desbotada que falha nas arestas. A água aparece na frente e ao fundo como **faixa pintada** de 3 tons, com marolas recortadas. Uma barraca de feira coberta de lona, pilhas de caixotes e, no telão do fundo, um guindaste e a margem.
  - **Câmera.** Camarote: 30°, 38°, 15,5 m, 1280 × 720, **Compatibility**.
  - **Personagens.** **Piaba** no fim do arremesso, com o braço passando do ponto e a boia ainda esticada. **Tiá Marola** na antecipação da recepção, braços abertos. **Um remo no ar** entre os dois, girando, com o rastro de fita na cor do Piaba. Três Buchos, uma Gaiola e uma Lata-Velha.
  - **Efeitos.** Um **malho em Despedida** contra um Bucho, no quadro do racho pelas facetas, com as primeiras lascas pintadas saindo. A **faixa listrada** de telegrafia da Lata-Velha fechando no chão. Uma **coroa de respingo** recortada onde um golpe pesado bateu na água rasa.
- **(b) Quadro de estresse.** 4 heróis, 20 inimigos, uma Despedida, um passe no ar e uma Boia na água.
- **(c) Clipe.** O passe completo com a recepção, e **a mesma remada feita por Marola e por Piaba lado a lado**, para julgar se a animação compartilhada parece de dois personagens diferentes.
- **(d) Nível PC.** O quadro (a) com sombra real e a distorção do golpe da Tralha Grande.
- **O que precisa provar.**
  1. O miriti facetado e fosco **não lê como plástico nem como jogo casual** (checagem de 3 palavras com o grupo do usuário).
  2. Dois heróis do **mesmo esqueleto** com proporções diferentes, cada um com antecipação e contato próprios, **sem a arma atravessar o corpo**; no clipe lado a lado, a remada parece de dois personagens.
  3. O passe é legível no clipe: dá para ver quem jogou, o que voa e quem vai pegar.
  4. A paleta em três famílias funciona: o perigo listrado se destaca em deuteranopia, e no quadro de estresse os 4 heróis passam no borrão e se separam entre si.
  5. A água em faixa pintada convence ao lado do resto, sem parecer provisória.
  6. 24 cores ou menos; camada base com diferença abaixo de 3 em 255 entre Compatibility e Forward+.

---

## 4. Recomendação

**Favorita provisória: Tolda Viva**, na versão enxugada da seção 1. **[red team]** Ela só vira recomendação depois das três provas novas, do teste de desempenho no celular real e das respostas às 3 primeiras perguntas da seção 5. Os motivos de ela estar na frente, em ordem de peso:

1. **O pipeline do boneco está provado; o visual da Tolda ainda não.** **[red team: reescrito]** O boneco de madeira e pano gerado só por código no Blender já existe, tem rig rígido simples e sai praticamente igual na Web e no PC (diferença de 1,3 a 1,9 em 255). Mas a prova anterior foi feita num cenário de sertão em xilogravura, com chita florida e chapéu de palha, que é exatamente o que a Tolda agora proíbe, e o boneco ainda tem cinco defeitos abertos (cabeça de totem, mão e manga genéricas, contorno fino, cara única, espada atravessando o chão). Ele também falhou no borrão e no daltonismo com 4 heróis. O que a Tolda tem a mais é caminho técnico percorrido, não visual aprovado. Cacos de Cobalto depende de um pincel figurativo que ninguém testou; Tralha da Cheia depende de um reaproveitamento de golpes que ninguém testou.
2. **Foi a primeira nas três lentes.** Os três juízes a puseram em primeiro lugar, cada um por um motivo diferente: o co-op, a coerência da arte e o quanto ela aproveita do que já foi medido.
3. **O co-op é de grupo, não de "um jogador vezes quatro"**, desde que a mira ajude. Reação cruzada com a mira que procura o alvo do amigo, maquinaria de duas pessoas e erguer e arremessar o amigo geram as histórias de "lembra quando...". A fatia mede isso por registro, e a meta é mais da metade das reações cruzadas.
4. **Quem morre continua jogando.** O Contrarregra resolve o pior problema do gênero, o jogador morto parado olhando a tela.
5. **Funciona em qualquer resposta à pergunta "onde e com quem".** **[red team: reescrito]** No PC com controles, até 4 na mesma tela. Cada um no seu celular: o online mínimo para 2 entra na fatia, e a maquinaria por posição tolera a rede. Sozinho: as duas mãos do bonequeiro. O ponto fraco é erguer e arremessar o amigo no online, que precisa passar no teste a 150 ms.
6. **A regra de material protege contra a animação gerada.** "Madeira nunca dobra" e o andar em pulinho tiram do caminho o corpo que dobra mal, o ciclo de passos e o pé deslizando, que é onde o código mais falha. O pulinho tem parâmetros por herói para não sair uniforme.

**O que ainda pode derrubá-la:** a vizinhança de jogos de palco e de bonecos (Foul Play, Puppeteer e os lançamentos de 2026), o telão a têmpera que nunca foi testado e a identidade de teatro na câmera de combate. As três coisas são testadas na prova.

**Quando escolher outro:**

- **Cacos de Cobalto**, se o usuário quiser o jogo mais perto de **Magicka**, com magia física e caos de fogo amigo, e aceitar que a primeira semana é uma aposta no pincel procedural.
- **Tralha da Cheia**, se o usuário quiser o jogo mais perto de **Lost Castle 2**, com arsenal e corpo a corpo com peso, e se o jogo principal for **no PC com amigos**, onde o passe brilha mais.

**Próximos passos propostos, nesta ordem [red team]:**

1. Fazer ao usuário as **3 perguntas do grupo 1** da seção 5 (onde e com quem joga, quanto de Brasil, 3D ou HD-2D). Elas mudam as próprias provas.
2. Obter o **resultado do teste de desempenho** no celular dele e fixar a faixa de aparelho.
3. Fazer as **três provas**, cada uma com as quatro peças (quadro bonito, quadro de estresse, clipe e quadro de PC), mais o build Web no celular real. Cada uma custa de 2 a 3 dias de trabalho por script.
4. Publicar as provas numa página com o formulário de 3 palavras para o usuário e os amigos dele.
5. Só então recomendar um finalista e fazer as outras perguntas.

---

## 5. Decisões que só o usuário pode tomar

**[red team: reordenadas]** As decisões estão em dois grupos. As do grupo 1 vêm antes das provas, porque mudam o que vai ser desenhado. As do grupo 2 vêm depois que ele vir as imagens e os clipes.

### Grupo 1: antes das provas

1. **Onde e com quem vai jogar.**
   - Onde: navegador do celular, PC, TV, ou mais de um. E **qual é o modelo do celular** em que testou o jogo anterior: isso define o orçamento de render. O teste de desempenho já publicado (`https://claude.ai/artifact/34DxYCDCstTXbcdrgEPpxv`) mede isso e grava o resultado.
   - Com quem: quantas pessoas, que aparelhos (algum iPhone?) e se alguém tem controle de videogame.
   - Como: sozinho com parceiro de IA; cada um no seu celular pela internet; todos na mesma tela do PC com controles; ou uma mistura. Se for "cada um no seu celular", o online deixa de ser o marco 2 e vira parte da fatia vertical.
2. **Quanto de Brasil no tema.** Os três usam um artesanato brasileiro (boneco de luva, azulejo, brinquedo de miriti) num mundo inventado. O usuário pode preferir mais, menos ou nenhuma referência regional; para "nenhuma", cada finalista tem uma variante (seção 0).
3. **3D toon ou HD-2D com sprites.** A pesquisa e a prova recomendam 3D toon, porque o sprite pré-renderizado custaria milhares de quadros por personagem. O usuário citou as duas opções e precisa confirmar.

### Grupo 2: depois de ver as provas

4. **Qual dos três finalistas** (ou se quer trocar algum enxerto entre eles).
5. **Fogo amigo padrão.** Só comédia sem dano (melhor com desconhecidos e no celular) ou com dano (o caos de Magicka entre amigos).
6. **Duração da sessão.** A unidade proposta é uma expedição de 15 a 20 minutos, com a campanha inteira de cerca de 50 minutos como opção.
7. **Idioma e público.** Só português do Brasil no começo, ou inglês desde cedo (afeta nomes e textos em cena).
8. **Nome.** A busca na web de 27/11/2026 não achou jogo com os nomes Tolda Viva, Tralha da Cheia, Floodhaul ou Cacos de Cobalto, mas Steam, itch.io e INPI (classes 9 e 41) precisam ser conferidos a partir de outra rede antes de qualquer divulgação.
9. **Destino do jogo.** Jogar com amigos de graça no navegador, publicar no itch.io ou vender na Steam. Isso muda o peso do PC e do online.

---

## 6. Revisão do red team

O red team leu a proposta, buscou os nomes e os vizinhos na web e apontou 21 problemas. Quase todos foram aceitos; alguns foram aceitos com outra solução, e um ponto do próprio red team estava errado. Os jogos citados por ele (Foul Play, Kiln, Toypunk, PuppetOFF, Puppet Showdown, Puppeteer: No Strings Attached, Marionette) vieram da busca dele e **não foram conferidos de novo nesta revisão**; Puppeteer (Sony, 2013) e Kiln já estavam na pesquisa.

| # | Problema apontado | Decisão | O que mudou, ou por que não |
|---|---|---|---|
| 1 | Tolda parecida com Foul Play, Puppeteer e os jogos de bonecos de 2026 | **Aceito, com outra solução** | Os vizinhos entraram na tabela de riscos. O Aplauso saiu, e com ele o "Bis!". No lugar do medidor de plateia, para o marco 2, entrou a **madeira viva**: tábuas que racham com quedas e são remendadas por reações cruzadas, pagando o Pano Rápido. O pitch passou a ter como eixo a maquinaria operada em dupla e as matérias de oficina |
| 2 | Provas paradas, com 2 heróis, não provam animação nem legibilidade com 4 | **Aceito** | Cada prova tem agora quadro bonito, quadro de estresse com 4 heróis e 20 inimigos, clipe de 3 a 5 s e quadro de PC, mais o build Web no celular (seção 0). O custo subiu de 1 a 2 para 2 a 3 dias por prova |
| 3 | "A única com prova" exagera | **Aceito** | O argumento 1 virou "o pipeline está provado; o visual da Tolda ainda não", com os cinco defeitos e as falhas de borrão e daltonismo. A Tolda passou a "favorita provisória". A prova compara com a folha 4 para conferir que a chita florida e o chapéu de palha sumiram |
| 4 | Co-op entre pessoas não é testado no celular; o argumento 5 premiava o solo | **Aceito, com uma correção** | As 3 perguntas vêm antes das provas; a fatia muda conforme a resposta (online mínimo para 2 ou 4 controles no PC); o argumento 5 virou "funciona em qualquer resposta". **Correção:** o red team disse que o WebRTC já foi provado no container. Não foi: `coop-rede.md` registra que só ENet e WebSocket foram testados, e que no 4G brasileiro vai ser preciso servidor de repasse (TURN). Isso virou a primeira tarefa da fatia online |
| 5 | Risco de "um jogador vezes quatro" na Tolda | **Aceito, com outra solução para a Goma** | Mira que prefere o alvo preparado por outra pessoa, plaquinha piscando na cor de quem preparou, força solo de 0,5, meta medida por registro. Em vez de tirar a Goma da fatia, ela virou **pote de cena** que qualquer um pega: mantém 3 matérias, deixa claro quem preparou e não gasta botão |
| 6 | Jogadores sem identidade visual no Rejunte | **Aceito** | Símbolo de chão por jogador, anel na base e cor do nome fora da família das matérias, um herói por grupo, teste com 4 heróis em daltonismo |
| 7 | Magia genérica (fogo, água, vento, raio) e morte em cacos parecida com Kiln | **Aceito em parte** | Aceito: o **rejunte virou o sistema** (propagação pelas juntas e padrão de assentamento), e a morte em cacos virou "voltar para a parede", com a pintura que desbota. Aceito em parte: só a água mudou, para **Cal**, que rejunta e fixa a pintura. Recusado: trocar todas as matérias por materiais de azulejaria. "Esmalte" e "forno" colidem com Kiln, e o usuário veio atrás do Magicka, cujos verbos (molhar, queimar, soprar, eletrificar) são o que ele reconhece. A regra "nunca fogo, água, raio ou terra" da pesquisa foi escrita para a opção de teatro de bonecos, não para esta |
| 8 | A identidade de teatro some na câmera de combate | **Aceito** | Regra 12 da Tolda: bambinela fixa em cima, borda da empanada embaixo, sombra da mão do bonequeiro; checagem de 3 palavras no quadro de estresse |
| 9 | O preto tem papéis demais; "virou cenário" entope a tela | **Aceito** | Contrarregra-jogador com símbolo, lanterna e fita na cor dele; contrarregras de cenário em cinza-carvão, pelo caminho mais curto; um "virou cenário" com carregadores por vez, os outros puxados por corda |
| 10 | Escopo da fatia grande demais | **Aceito** | Marco 1a (uma arena, contrapeso, Contrarregra, solo, troca por corte de cortina) e marco 1b (chefe numa fase, fios como ossos com mola, cruzeta, alçapão). Verlet só abaixo de 2 ms no celular |
| 11 | O toque não cabe em 5 botões | **Aceito** | 4 botões à vista, Troca de Mão por deslizar no retrato, ping por toque duplo, Mão só por contexto; o layout é publicado e testado em celular real |
| 12 | Pulinho uniforme e adereço sem teste de colisão na Tolda | **Aceito** | Parâmetros de pulinho por herói (nova coluna na tabela) e teste de colisão com corpo e chão |
| 13 | Conserto fraco da animação da Tralha | **Aceito** | Antecipação e contato próprios por herói (64 poses), dano preso à pose de contato, clipe da mesma remada lado a lado. O contato do Seu Remanso sobe para 20 poses por segundo, para não ficar com degraus de 83 ms |
| 14 | Não diz o que "AAA" quer dizer | **Aceito** | Nova parte na seção 0: o que dá, o que não dá e o que o PC acrescenta. A paridade vale só para a camada base, e o quadro (d) mostra os extras. A frase "o momento que todo mundo vai gravar" saiu |
| 15 | Risco no celular subestimado | **Aceito** | Critério por faixa de aparelho (10 a 12 inimigos na faixa de entrada), contador de draw calls no build de cada prova, MultiMesh medido antes de prometer número de inimigos, custos próprios de cada finalista nas tabelas de risco |
| 16 | Três artesanatos brasileiros; escolha estreita | **Aceito** | O tema virou camada trocável, com variante sem referência regional para os três (seção 0), e a pergunta sobre Brasil subiu para antes das provas. "Mamulengo" entra nas palavras proibidas só na variante sem referência regional, porque na versão brasileira a inspiração é declarada e creditada |
| 17 | "Teste cego" sem pessoas; fotos de azulejo bloqueadas | **Aceito** | Formulário de 3 palavras numa página para o usuário e os amigos; os portões automáticos viraram "checagem interna"; fotos de azulejo do usuário ou de conjunto livre no GitHub |
| 18 | Piscadas de tela inteira | **Aceito, com uma ressalva** | Na Tralha, a Despedida deixou de pintar a tela inteira. No Rejunte, a inversão já era só no personagem; ganhou limite de 2 ao mesmo tempo. Limite de uma piscada de tela a cada 2 s e "reduzir clarões" ligado por padrão no celular |
| 19 | Empréstimos nomeados na Tralha | **Aceito** | O reviver virou a linha de pesca com a marola certa, e a citação a Lost Castle 2 saiu do texto do jogo. A Despedida ficou, porque o Mural é a parte original dela |
| 20 | Nomes: "Rejunte" é palavra comum | **Aceito** | O finalista 2 passou a se chamar **Cacos de Cobalto**; "rejunte" ficou como nome do sistema. Steam, itch.io e INPI continuam pendentes |
| 21 | Jargão demais e 11 decisões sem ordem | **Aceito** | Glossário no topo (com 14 linhas, um pouco mais que as 10 sugeridas), termos trocados por palavras simples no texto, decisões em dois grupos: 3 antes das provas e 6 depois |

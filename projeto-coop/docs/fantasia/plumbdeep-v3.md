# Plumbdeep v3: a Guilda do Prumo (roguelite co-op)

**Mudanças da revisão (27/11/2026):** a pedido do usuário ("não é genérico ter cavaleiro, arqueiro etc., é normal; estilize para que não fique genérico"), as quatro classes inventadas (Escorador, Cristaleira, Coveira e Gancheiro) viraram **arquétipos clássicos de RPG estilizados: Cavaleiro, Arqueira, Maga e Clérigo**. As cinco desbloqueáveis viraram **Ladino, Bárbaro, Druida, Bardo e Paladino**. Os inimigos foram redesenhados como **criaturas de dark fantasy reconhecíveis** (carniçais, aranhas cegas, morcegos, cultistas, um elite blindado). A Cal virou **Sal** (sal bento do Clérigo), e as reações dela foram renomeadas (Água Benta, Clarão, Crosta de Sal, Purga). A cor do jogador saiu do corpo do herói e virou um **acento pequeno**, porque cada herói agora tem **figurino com paleta própria**. A estrutura roguelite, o mundo e as interações co-op ficaram como estavam.

Conceito de jogo, versão 3, 27/11/2026. Reescreve `profundezas.md` (v1 e v2) depois da escolha do usuário entre os três conceitos (`proposta.md`). **Base:** a Guilda do Prumo, seu abismo e sua atmosfera. **Personagens:** arquétipos clássicos de RPG, no padrão de acabamento dos heróis de Wickwain. **Animação:** com a fluidez e o lado cinematográfico da Pequena Hoste. **Forma de jogo:** roguelite co-op, que foi o que o usuário mais gostou.

**Como ler.** Os números são propostas para teste, não medições, exceto onde está marcado **[medido]** (provas v2 e pesquisas em `docs/pesquisa/`). **[PC]** é o nível Forward+; **[iPhone]** é a prévia Web em Compatibility/WebGL2. Tudo roda a 60 quadros por segundo; "q" quer dizer quadro.

### Glossário curto

| Termo | O que quer dizer |
|---|---|
| A Goela | O abismo de 3 km de boca que engoliu o reino de Thessimor há 212 anos |
| Pendura | Cidade de andaimes e guindastes pendurada na borda da Goela. É onde fica a Sede da guilda |
| Descida | Uma corrida: o grupo desce, atravessa de 1 a 4 Andares e precisa voltar vivo com a Carga |
| Andar | Cada camada do abismo. Tem uma **espinha fixa** (marcos, âncoras, horizonte) e um **miolo** que a Goela remexe a cada Descida |
| Trecho | Um bloco jogável feito à mão (de 36 × 36 m a 48 × 48 m), encaixado por código no miolo do andar |
| Patamar | Os dois trechos fixos de cada andar: o de **chegada** (onde a jaula desce) e o de **decisão** (subir ou descer mais) |
| Içamento | A Subida da v3: a jaula da guilda subindo pelo Poço com a Carga dentro, sob ataque |
| Carga | O saque carregado, em quilos. Pesa no movimento, faz barulho e só vira dinheiro lá em cima |
| Âncora | Ponto de rocha-mãe na espinha do andar. Quem acende uma âncora pendura uma linha de lanternas que **fica entre corridas** |
| O Prumo | O peso de chumbo da guilda, um por grupo. Arma, sonda e item de passe com recepção diferente por classe |
| Chapéu | O item que define a classe (elmo, capuz ou chapéu). Trocar de chapéu na Sede é trocar de classe |
| A Respiração | O ciclo do abismo: Inspira (vento sobe), Prende (silêncio), Expira (bafo morno de esporos) |
| Pincelada | Uma matéria aplicada num alvo ou numa célula do chão. Duas matérias diferentes no mesmo lugar dão reação |
| Desbotado | O herói caído: perde a cor, vira cinza e continua jogando (gira guinchos, sopra, assusta) |
| Afundado | Explorador que nunca voltou, fundido à própria mochila. Às vezes é **você**, de uma Descida anterior |
| Penduricalho | Relíquia pequena da corrida, pendurada no cinto do herói (visível no modelo). Some ao morrer |
| Veio | Regra de química que muda a cada Descida e reescreve uma reação |

---

## 0. O que mudou da v2 e por quê

| O que o usuário ou a crítica disse | Resposta da v3 |
|---|---|
| Gostou do cenário e da ambientação de Plumbdeep | Ficam: cascatas e cortinas de goteira, colônias de fungos, postes de lanterna da guilda, a ruína de Thessimor, a Coluna do Meio-Dia, o Dente com janelas acesas, a Pendura de Baixo, névoa subindo do abismo, luz fria de cima e poças de luz quente. A v3 melhora o que estava cru: rochas e chão (seção 10) |
| Personagens e efeitos "mal acabados" | Heróis refeitos no padrão Wickwain, com deformação de verdade, textura pintada e shader por material (seções 6.1 e 6.2). Efeitos com linguagem única, camadas e timing (seção 11). Inimigos refeitos como dark fantasy ameaçador (seção 8) |
| Gostou mais dos personagens de Wickwain | Corpo atarracado de 2,25 cabeças, rosto de cera talhada com olhos de botão, mãos com polegar, adereço-símbolo grande, contorno de casca invertida, materiais foscos pintados |
| "Por que inventou isso? Use conceitos mais naturais" (sobre o Gancheiro e o Escorador) | As classes viram **arquétipos clássicos**: Cavaleiro, Arqueira, Maga e Clérigo, e as desbloqueáveis Ladino, Bárbaro, Druida, Bardo e Paladino. A originalidade vem da **estilização**: proporção, rosto, forma, figurino e detalhes de guilda do abismo (seção 6) |
| O escudo-roda da Rodeira de Wickwain parecia atraente | O Cavaleiro usa um escudo redondo grande de madeira com aro de ferro e cravos, na mesma linha (seção 6.3) |
| "O acabamento está genérico; não se prenda a cores, quero que cada um seja estiloso independente da cor" | Cada herói tem **figurino com paleta própria** e 3 ganchos visuais. A cor do jogador vira um acento trocável de 5 a 8% da área, mais luz de borda e anel (seção 6.1) |
| "Fique atento à deformação 3D, só reposição de partes" | Malha contínua com pesos suaves, ossos de ajuste e blend shapes corretivas. Peças rígidas só no que é rígido (seção 6.2) |
| A Pequena Hoste tem animação fluida e cinematográfica | Ciclos de andar e correr, idle com respiração e microgestos, antecipação, smear, molas, hit-stop e câmera que acompanha o golpe (seção 7) |
| "Animações de ataque coerentes e bem feitas, com ritmo e peso" | Cada classe tem ritmo próprio, ficha de timing e tira de poses-chave, e o contato acontece no mesmo quadro para tudo: hitbox, hit-stop, flash, faísca, tremor e som (seção 7) |
| "Bastante game juice, tudo acabado, animado e iluminado" | Tabela de juice por peso de golpe, mundo que reage, nada parado em cena e luz como protagonista (seções 7.3, 10 e 11) |
| Mundo vertical briga com a câmera do co-op local | O jogo acontece em **bandejas largas**. A verticalidade fica no horizonte e nas transições, que o grupo faz junto na jaula (seção 9) |
| A Subida pode virar tarefa | Vira o **Içamento**: um combate em arena móvel de 60 a 90 s por andar, com decisões de jogar Carga fora (seção 2.6) |
| Custo de produção de três andares abertos de 1,4 a 2 km | Cada andar vira um **kit** de cerca de 16 trechos feitos à mão, mais uma espinha fixa e um horizonte. O código monta 7 a 10 trechos por Descida (seção 2.3) |
| O roguelite foi a parte de que o usuário mais gostou | Vira a estrutura central (seção 2) |

**O que ficou da v1 e da v2 porque funcionava:** o Visgo isolante; o Prumo com recepção por classe; o caído que gira guinchos com força total; a Subida com a Carga (agora Içamento); as masmorras de mesa de RPG; os mapas que mentem; a Respiração do abismo; Carga visível e audível; reações de química que o jogador consegue adivinhar.

---

## 1. Nome, frase e premissa

**Plumbdeep: a Guilda do Prumo.** A frase é **"Desça leve. Volte pesado. Mas volte."** A versão de capa é *"Eu te grudo, você eletrifica a poça, e a gente sobe rico."*

Há 212 anos, o chão se abriu sob o reino de **Thessimor** numa noite sem vento, **a Mordida**. A capital, os campos e o rei caíram num buraco de 3 km de boca, **a Goela**, que nunca fechou e que **respira**. Na borda cresceu **Pendura**, uma cidade de andaimes que vive do que sobe. Os jogadores são os últimos membros da **Guilda do Prumo**, a mais antiga e a mais endividada de Pendura: ela deve **40.000 de ouro** à Guilda da Roldana. A guilda aceita qualquer um que saiba descer por uma corda: um cavaleiro sem ordem, uma caçadora das bordas, uma aprendiz expulsa da Academia e um capelão que reza para a luz que cai pela boca da Goela.

**Por que a Descida muda a cada vez (a ficção do roguelite).** A Goela não é parada. Entre uma Descida e outra ela dá uma **Respiração Longa**, que remexe o miolo de cada andar: desaba pontes, abre fendas e muda de lugar as florestas de fungo e as casas tombadas. Só a **rocha-mãe** fica: as paredes, os grandes marcos e as âncoras. Por isso os mapas envelhecem em uma noite, e mapas de mortos mentem. É também por isso que a guilda acende lanternas nas âncoras: são as únicas coisas que ficam.

**Tom.** Dark fantasy com humor ácido, nunca infantil. Os Ouvidores são os súditos engolidos que viraram carniçais cegos. Os Afundados são exploradores de verdade, com nome bordado na capa, e um deles pode ser o seu herói da Descida passada. O humor vem do grupo, da ganância e da burocracia da morte: o Clérigo cobra "taxa de bênção" das botas de quem ficou embaixo, e o Cavaleiro jura lealdade a uma ordem que só tem ele e uma dívida. Ninguém sangra. A tinta lasca, a cera racha, e os inimigos se partem em gesso, osso, quitina, cinza e pó.

---

## 2. Estrutura roguelite

### 2.1 O ciclo

1. **Na Sede, em Pendura** (2 a 4 min): escolher 1 de 3 contratos, ler o Veio da Descida, trocar de chapéu, gastar ouro e Lastro, pôr as miniaturas na Mesa.
2. **A Descida da jaula** (15 a 25 s, jogável): a jaula desce pelo Poço até o Patamar de chegada do andar mais fundo que a guilda já liberou.
3. **O Andar** (11 a 16 min): de 7 a 10 trechos em grafo com rotas paralelas, de 0 a 1 masmorra de mesa, eventos, âncoras e o **chefe do andar**.
4. **Patamar de Decisão** (30 s): **subir agora** (Içamento) ou **descer mais** (próximo andar, com a Carga nas costas).
5. **O Içamento** (60 a 90 s por andar subido): a jaula sobe com a Carga, sob ataque.
6. **De volta à Sede** (1 a 3 min): vender, expor relíquias, registrar chapéus, pagar dívida, ver a rede de lanternas crescer na Mesa.

### 2.2 Duração

| Formato | O que inclui | Duração |
|---|---|---|
| **Mergulho** | 1 andar e 1 lance de Içamento | 14 a 19 min |
| **Descida média** | Andares 1 e 2, 2 lances | 28 a 36 min |
| **Descida completa** | Andares 1 a 3 com os 3 chefes, 3 lances | 42 a 55 min |
| **Descida ao Fundo** | Andar 4 (depois da Coroa), 4 lances | 55 a 68 min |
| Descida que acaba em morte | Típica nas 10 primeiras corridas | 8 a 25 min |

Começar mais fundo encurta as Descidas: com âncoras acesas (seção 3.4), o grupo pode começar no Andar 2 ou 3. A **campanha** (trazer a Coroa) leva de **15 a 25 Descidas, ou cerca de 12 a 18 horas**. O conteúdo completo (Andar 3, a Senhora das Âncoras, o Fundo, as 9 classes e os Juros) leva de **35 a 45 horas**.

### 2.3 Como um andar é gerado (blocos feitos à mão, montados por código)

O método segue o que a pesquisa mediu em `extra-geracao-de-fases-por-codigo.md` **[medido]**: os jogos do gênero sorteiam a **ordem** de salas feitas à mão, não a geometria. Três camadas:

**Camada 1: a espinha fixa (feita à mão, uma por andar).** É a forma da caverna: um anel de paredes de cerca de 1 km com os grandes marcos no horizonte (Coluna do Meio-Dia, Cascata, Dente, Pendura de Baixo, Sino, Forja). O chão da caverna é dividido numa **macrogrelha de 6 × 5 células**. Cada célula pode receber um trecho. A espinha fixa:
- o Patamar de chegada e o Patamar de decisão;
- as **12 âncoras** de rocha-mãe, em células fixas;
- a arena do chefe;
- de 2 a 3 "bordas de vazio", onde o trecho encosta no Poço e mostra o andar de baixo.

**Camada 2: o grafo do miolo (código).** Uma gramática de grafo escolhe de 7 a 10 células e liga o Patamar de chegada ao chefe por **2 ou 3 rotas paralelas** que se cruzam pelo menos uma vez. Restrições:
- passar por no mínimo **3 âncoras**;
- ter **1 Capela de Corda**, de **0 a 1 masmorra de mesa**, **1 ou 2 eventos** e **1 Penhorista** (loja);
- caber em **11 a 16 min** pelo modelo de tempo (calibrado depois por telemetria);
- ter pelo menos 1 atalho que só abre com máquina em dupla.

Gerar um andar leva menos de **60 ms** (o protótipo da pesquisa mediu 48 ms por expedição em Python e o mesmo tempo em GDScript **[medido]**).

**Camada 3: o trecho (feito à mão) e seus estados (código).** Cada trecho é desenhado à mão no Blender por script: piso, bordas, cobertura, encaixes de marco, de inimigo e de evento. O código só varia o que não estraga o desenho:
- **orientação:** 4 rotações ou espelhamentos, para casar as saídas;
- **estado:** inteiro, desabado (uma borda cai e vira beirada), alagado (poças e estado molhado) ou esporado (colônias crescem e o chão começa esporado);
- **telão:** a luz do fundo segue a fase da Respiração (Inspira azul-ardósia clara, Prende quase preta e parada, Expira verde-ciano morna). São os 3 estados de telão que a pesquisa pede, separados em matiz e valor, e saem de graça do ciclo do mundo;
- **decoração por regra:** musgo e regos de água por acúmulo de fluxo sobre a grade de alturas (o método da v2 **[medido]**), colônias de fungo com hierarquia (1 grande, 3 a 5 médios, enxame) presas à umidade, e postes de lanterna da guilda ao longo das trilhas;
- **composição de inimigos:** de 12 a 16 modelos de onda por andar, guardados como dados.

**Anti-repetição.** A escolha é feita pela **tupla inteira** (trecho, estado, telão, marco, onda), pela distância ao que o grupo já viu nas últimas 3 Descidas. A pesquisa mediu que sortear cada dimensão em separado repete uma sala inteira em 56% a 78% dos caminhos; a tupla conjunta derruba isso para 6% a 8% **[medido]**.

**Variedade por andar.** São 16 trechos × 4 orientações × 4 estados × 3 telões = **768 combinações de trecho por andar**, antes de inimigos e eventos.

**Custo de produção por andar (o problema 3 resolvido):**

| Peça | Quantidade por andar | Observação |
|---|---|---|
| Espinha (paredes e horizonte) | 1 | A peça mais cara. Paredes de 1 km em 3 lâminas de profundidade, feitas uma vez |
| Trechos jogáveis | 16 (12 no lançamento do primeiro andar) | De 36 × 36 a 48 × 48 m, na grade de 1,5 m |
| Patamares e arena de chefe | 3 | Fixos, com roteiro |
| Marcos médios (dentro do trecho) | 6 | Guincho, ruína com poço, ponte de tronco de fungo, carcaça de jaula, estátua, cofre |
| Cobertura e adereços | 5 | Recoloridos por andar |
| Perigos do "verbo" do andar | 2 | Andar 1: poça e colônia de esporos. Andar 2: brasa da Forja e laje rachada. Andar 3: água funda e névoa baixa |
| Pendurados | 2 | Raízes, correntes, lanternas de outras guildas |
| Masmorra de mesa | 8 salas-módulo | Montadas de 3 a 5 por masmorra |

Isso dá cerca de **35 peças por andar**, contra um mundo contínuo de 1,4 a 2 km na v1.

### 2.4 Os trechos que formam o miolo

| Tipo de nó | Parcela | O que tem |
|---|---|---|
| **Combate** | cerca de 40% | 1 a 3 ondas e 1 marco obrigatório. Termina com uma pequena recompensa (ouro, matéria, Penduricalho em 1 de cada 4) |
| **Saque** | 15% | Pouco combate e muita Carga: carroças de Thessimor, mochilas de Afundados, cofres pequenos. O barulho atrai patrulhas |
| **Âncora** | 10 a 15% | Uma âncora de rocha-mãe. Acender leva 8 s (seção 3.4) |
| **Evento** | 10 a 15% | Um dos eventos da tabela 3.3 |
| **Máquina** | 10% | Uma máquina em dupla que abre atalho, ponte ou cofre (seção 4.3) |
| **Capela de Corda** | 1 por andar | Escolher 1 de 3 Graças |
| **Penhorista** | 1 por andar | Loja pendurada numa corda: troca Carga por Penduricalhos, cura e corda |
| **Masmorra de mesa** | 0 a 1 por andar | Porta para 3 a 5 salas numeradas na grade de 1,5 m, com placas de pressão, portas de contrapeso para dois, armadilhas e uma relíquia grande no fim. O Escriba narra a entrada de cada sala num cartão, como um módulo de aventura. De 3 a 5 min |

### 2.5 Mapas que mentem

No Patamar de chegada, o grupo recebe o **Mapa do Escriba**: o grafo do andar desenhado em pergaminho, com um ícone por nó. O mapa é de ontem, e a Goela já respirou. **1 em cada 5 ícones está errado** (2 em cada 5 com Juros altos): um "cofre" que é ninho de Pingentes, uma "capela" que é um Altar da Boca cheio de cultistas. Formas de saber:
- **Mapas de Afundados**, derrubados pela elite, mostram a verdade de 3 nós, ou mentem de propósito, com uma armadilha preparada por quem já morreu (25%).
- **O Prumo-sonda:** jogado num poço, o som diz se o nó de baixo está vazio, cheio de água ou habitado.
- **A Inspira:** paredes que "fumam para dentro" escondem passagens para nós secretos.
- **O Bardo** (classe por chapéu) toca um acorde, e o eco desenha o contorno de nós vizinhos por 3 s.

### 2.6 O Içamento (a Subida da v3)

**Por que mudou.** Na v1, a Subida era carregar peso devagar por 8 a 15 minutos, por um mundo vertical que a câmera de co-op local não aguentava. Agora ela é a **cena final de cada corrida**: curta, intensa, numa arena de câmera estável, e cheia de decisões.

**Como funciona.** No Patamar de Decisão, o grupo entra na **Jaula da Guilda**, uma plataforma de ferro e tábuas de **9 × 9 m** (6 × 6 células) presa a um cabo. A Carga fica empilhada no centro da jaula como sacos de verdade, visíveis e físicos. A jaula sobe pelo Poço, e cada andar subido é um **lance de 60 a 90 s**. A câmera fica presa à jaula (seção 9). Por fora passam as paredes do Poço, as linhas de lanternas que a guilda já acendeu, os andares de cima e, no último lance, a boca da Goela com o céu.

**O que ataca a jaula:**
- **Ouvidores** (carniçais) sobem pelas grades;
- **Pingentes** (morcegos de pedra) caem do teto do Poço e **apagam as lanternas da jaula**;
- **Roicordas** roem o cabo. O cabo tem 300 de vida; se chegar a zero, a jaula despenca 10 m até a trava de segurança anterior e perde 15 s;
- **Cultistas da Boca** rezam das saliências do Poço e abrem poças de Fundo no piso da jaula;
- **Afundados** saltam das paredes;
- inimigos **roubam sacos** e pulam com eles. O saco pode ser pego no ar com o Lance ou com a **flecha de corda** da Arqueira.

**Perseguição pela Carga.** A cada 25 kg de Carga total do grupo, o Içamento ganha **um nível de perseguição**, que soma uma onda e um tipo de inimigo. Com 0 a 24 kg, um lance é quase tranquilo. Com mais de 100 kg, é o combate mais difícil do jogo.

**As decisões dentro do Içamento:**
- **Lastrar.** Jogar sacos para fora acelera a jaula em 4% para cada 5 kg jogados, até 40%. É a decisão de ganância mais clara do jogo, e cada saco que cai faz barulho de moeda até sumir no escuro.
- **Manivela em dupla.** Dois jogadores girando as duas manivelas sobem 35% mais rápido, mas ficam sem atacar. Os Desbotados giram com força total, então um grupo em apuros sobe empurrado pelos próprios mortos.
- **Freio.** Em cada lance há 1 **patamar intermediário** com um prêmio à vista (um cofre pendurado, um explorador vivo). Travar o freio para por 15 s: dá tempo de pegar o prêmio, e dá tempo dos inimigos subirem.
- **Relíquias grandes** (de 30 a 60 kg, com duas alças) precisam ser carregadas até a jaula: duas pessoas a 70% da velocidade (na v1 eram 60%), sem atacar, por no máximo 1 ou 2 trechos. Elas valem o Içamento inteiro.

**Duração total:** de 1 a 1,5 min (Mergulho) até 4 a 6 min (subindo do Andar 3).

### 2.7 Risco e recompensa: descer mais ou subir agora

| Escolha no Patamar de Decisão | O que ganha | O que arrisca |
|---|---|---|
| **Subir agora** | Converte a Carga em ouro com o **Prêmio de Fundura** do andar atual | Nada, além do Içamento |
| **Descer mais** | O próximo andar paga mais: Prêmio de Fundura de **×1,0** no Andar 1, **×1,4** no 2, **×1,9** no 3 e **×2,6** no 4. Abre chefes e relíquias melhores | A Carga desce junto (pesa e faz barulho), e o Içamento terá mais lances |
| **Despachar numa âncora** | Até 20 kg por âncora acesa sobem pelo cabo da guilda e ficam **salvos** | Leva 15 s de defesa, e o que é despachado vale só ×1,0, sem prêmio de fundura |
| **Penhorar** | Trocar Carga por Penduricalhos ou cura no Penhorista | Perde valor (o Penhorista paga 60%) |

**O que pesa na decisão:** a Carga nas costas (velocidade −0,5% por kg acima de 10 kg, até −30% com 70 kg), o barulho (+1 m no raio de audição dos Ouvidores a cada 10 kg), a vida que sobra e as Graças da corrida.

### 2.8 O que se perde e o que se leva

**Ao morrer** (todos os heróis desbotados ao mesmo tempo, ou o cabo do Içamento rompido duas vezes no mesmo lance):

| Perde | Leva |
|---|---|
| Toda a Carga não despachada | **Lastro** (100%): a moeda de experiência da guilda |
| Ouro carregado | Chapéus registrados e relíquias despachadas |
| Penduricalhos, Graças e Pactos da corrida | Âncoras acesas (a rede de lanternas) |
| Matérias e consumíveis da corrida | Entradas no Livro de Óbitos, mapas copiados e o nível de classe |

**A Pilha do Afundado.** Na Descida seguinte, os sacos perdidos aparecem no andar onde o grupo caiu, guardados por um **Afundado com a cara e o figurino do seu herói**, cinza e com a mochila fundida às costas. Derrotá-lo devolve **50% da Carga** perdida e o mapa daquele andar com os nós verdadeiros.

### 2.9 Meta-progressão: a Sede que cresce

**Moedas.**
- **Ouro de Pendura:** só existe depois do Içamento. Paga a Sede, a dívida e o guindaste.
- **Lastro:** nunca se perde. Rende 1 a cada 10 m descidos, mais feitos (chefe, âncora, resgate, reação nova descoberta). Sobe o **Grau da Guilda**, de 1 a 30.
- **Relíquias:** objetos grandes que viram peças da Sede.

**A Sede: a Casa do Prumo**, um sobrado de andaimes pendurado na borda, que cresce **para baixo** a cada melhoria, com andares novos aparafusados sob os antigos:

| Cômodo | Como se abre | O que faz |
|---|---|---|
| **A Mesa** | Início | Diorama do abismo: cada âncora acesa é um alfinete com fio de lã aceso; cada morte é uma miniatura tombada no lugar. Escolher o ponto de partida é pôr a miniatura na Mesa |
| **Quadro de Contratos** | Início | 3 contratos por Descida |
| **Guindaste da Guilda** | 5 níveis: 800 / 2.000 / 4.500 / 8.000 / 12.000 de ouro | +1 lance de cabo de despacho, a jaula começa com +50 de vida de cabo, e a manivela fica 8% mais rápida por nível |
| **Cabideiro de Chapéus** | Primeiro chapéu registrado | Troca de classe entre corridas. Mostra os 9 chapéus (elmos, capuzes e chapéus), com os vazios em silhueta |
| **Sala das Relíquias** | Primeira relíquia | De 3 a 24 prateleiras. Cada relíquia exposta dá um bônus pequeno e permanente (exemplo: o Sino de Bolso de Thessimor dá +0,05 s em toda janela de recepção) |
| **Ferraria do Poço** | Relíquia "Bigorna Real" (Andar 2) | Forja 1 peça permanente por classe (3 variantes de arma, com outro golpe final no combo) |
| **Capela da Corda** | 1.500 de ouro | Começa cada Descida com 1 Graça nível 1 escolhida de 2 |
| **Varanda do Escriba** | 3.000 de ouro e 6 âncoras | Escolher o Veio entre 2 em vez de sorteá-lo, e ver 1 nó mentiroso por andar |
| **Cozinha da Viúva** | 1.200 de ouro | Uma refeição antes da Descida: +20 de vida, ou +5 kg de capacidade, ou +1 pincelada inicial |
| **Cripta dos Afundados** | Primeira mochila de Afundado trazida | Enterrar o que vem dos Afundados dá Lastro e conta a história de quem era |
| **Pintor de Brasões** | 600 de ouro | Cosméticos: 2 variantes de figurino por classe (a mesma forma com outra paleta), padrões de pano e brasões. Nunca com dinheiro real |

**A dívida.** São 40.000 de ouro devidos à Guilda da Roldana, em 8 parcelas de 5.000. Cada parcela paga muda Pendura (a rival para de sabotar contratos, o mercado vende mais, o guindaste rival passa a emprestar cabo). A dívida é o relógio narrativo da campanha.

**Grau da Guilda** (por Lastro, de 150 a 600 por grau): cada grau dá 1 escolha entre 2 benefícios. Exemplos: +10 m de corda de rapel; +1 espaço de Penduricalho (de 4 até 7); +5 kg de capacidade; o primeiro Desbotado de cada andar volta sozinho em 6 s; o Mapa do Escriba começa com 1 nó verdadeiro marcado.

**Nível de classe** (de 1 a 10, ganho jogando a classe): destrava variantes de habilidade e 2 **hábitos** por classe, que passam para as outras classes no nível 5.

**Contratos.** São 3 por Descida, e o contrato muda a geração do andar:

| Tipo | Objetivo | Efeito no andar | Recompensa |
|---|---|---|---|
| Recuperar | Trazer uma relíquia nomeada | Garante uma masmorra de mesa | Relíquia + 800 a 2.000 de ouro |
| Resgatar | Subir com um explorador vivo | Insere um nó de resgate; o explorador vira um ajudante lento | Lastro alto e um item de NPC |
| Abater | Matar uma criatura com nome | Insere uma elite nomeada com Penduricalho próprio | Penduricalho raro |
| Cartografar | Acender 3 âncoras novas | Mais nós de âncora | Melhora a rede e dá Lastro |
| Lacrar | Fechar uma fenda que sobe para Pendura | Evento de defesa de 90 s | Parcela de dívida descontada |

**Juros (dificuldade crescente).** Depois da primeira Coroa, cada Descida pode levar de 0 a 12 níveis de Juros. Cada nível soma uma regra e +8% de ouro. Exemplos:
- Juros 1: os mapas mentem 2 em 5;
- Juros 3: as Roicordas roem 2× mais rápido;
- Juros 5: os Afundados deixam rastro de Fundo;
- Juros 8: o Içamento ganha um nível de perseguição a mais.

**Nenhum nível de Juros encurta telegrafias abaixo de 24 quadros.**

### 2.10 Poder dentro da corrida: Penduricalhos, Graças, Pactos e Veios

São quatro fontes, que mudam a cada Descida e se combinam.

**Penduricalhos** (cerca de 40 no lançamento, 4 espaços no início). São relíquias pequenas que aparecem **penduradas no cinto do herói**, como peças do modelo: muda a silhueta e tilinta. Exemplos:

| Penduricalho | Efeito |
|---|---|
| Dente de Ouvidor | A Corrente atordoa +0,6 s |
| Fivela de Cobre | Quem está envisgado e absorve eletricidade guarda a carga: o próximo golpe aplica Estalo |
| Prumo de Bolso | Janela de recepção do Lance +0,08 s; golpe de recepção +25% de dano |
| Saquinho de Salitre | O Clarão explode: +20 de dano e empurrão de 2 m |
| Lanterna Rachada | Acender uma âncora cura 30 de vida de todos |
| Corda de Três Nós | Um Desbotado que segura um guincho por 4 s se repinta sozinho (1 vez por andar) |
| Moeda do Barqueiro | +3% de dano a cada 10 kg de Carga do próprio herói (a ganância como build) |
| Ferradura de Gesso | O golpe final do combo racha a laje e deixa a célula consagrada (pincelada de Sal) |
| Olho de Vidro do Escriba | Revela 1 nó mentiroso por andar |
| Âmbar com Mosca | O Âmbar em aliado dura +2 s e reflete projéteis |
| Chave Engolida | Abre 1 cofre por andar sem a máquina em dupla |
| Esporo em Vidro | A cada 8 s, a esquiva deixa uma pincelada de Esporo |

**Graças das Capelas de Corda** (1 por andar, escolher 1 de 3, cada uma com 3 níveis na corrida). Vêm dos três Padroeiros da Corda, fundadores de guildas que "ficaram embaixo":
- **Mestre Nó** (cordas e máquinas). Exemplo: guinchos giram 30% mais rápido, e o cabo da jaula tem +100 de vida.
- **A Viúva da Roldana** (Lance e recepção). Exemplo: o Lance não deixa quem arremessa sem arma; ele saca uma arma reserva em 0,5 s.
- **O Velho Peso** (Carga e impacto). Exemplo: o finalizador ganha +10% de dano para cada 10 kg de Carga do herói, e a esquiva com Carga alta vira tombo que derruba.

**Pactos do Fundo** (Altares da Boca, opcionais). Dão poder grande com um custo que dura a corrida inteira:
- **Fome:** +35% de dano; cada 10 kg de Carga custa 3 de vida máxima.
- **Eco Errado:** o Fogo Fundo passa a puxar só inimigos, mas a Corrente passa a ferir quem está envisgado.
- **Lábio Costurado:** a perseguição do Içamento ignora 50 kg de Carga, mas o grupo não ouve as telegrafias (só as vê).

**O Veio da Descida** (um por corrida, sorteado entre 8). É a Sonda do Escriba lida antes de descer, e ela reescreve uma regra de química. É ele que faz as sinergias entre matérias mudarem de corrida para corrida:

| Veio | Regra nesta Descida |
|---|---|
| Cobre | A Corrente salta até 3 células de água conectada (normal: só a poça), e Pingentes molhados conduzem |
| Salitre | Sal + Brasa vira explosão: o Clarão causa 40 de dano além de cegar |
| Resina Doce | O Visgo em aliado cura 4 por segundo enquanto dura |
| Esporada | A Expira dura o dobro, e o Fulgor causa ×1,5 |
| Água Pesada | Poças não secam, e a Água Benta dura o dobro e deixa a célula molhada e consagrada |
| Ferrugem | Estalo em metal (correntes, grades, a jaula, a armadura do Guarda Engolido) vira Corrente sem precisar de água |
| Cinza Fria | A Brasa apaga em 2 s, mas o Piche Ardente dura o dobro |
| Fundo Raso | O Fundo aparece em todo andar. A Purga também cura aliados em 3 m |

**Como as quatro fontes se cruzam (exemplos de corrida):**
- **Corrida de Cobre:** Veio de Cobre + Dente de Ouvidor + Fivela de Cobre. A poça vira uma rede elétrica do trecho inteiro, e o Visgo isolante da Arqueira deixa de ser truque e vira a estratégia central.
- **Corrida da ganância:** Moeda do Barqueiro + Graça do Velho Peso + Pacto da Fome. O herói mais pesado vira o que bate mais forte, mas fica lento e frágil, e o grupo precisa protegê-lo como uma relíquia.

---

## 3. "Mundo aberto e atmosfera elaborada" dentro do roguelite

### 3.1 Andares largos com caminhos múltiplos

- Cada Descida percorre de 7 a 10 trechos de um andar de cerca de **1 km de horizonte**. A área jogável é de cerca de **0,02 km² por Descida**, escolhida entre cerca de 0,05 km² possíveis por andar.
- Os trechos têm de **2 a 4 saídas**. O grafo sempre oferece **2 ou 3 rotas paralelas**, com custo e prêmio visíveis ("pela ponte de tronco, perto da âncora", "pelo cofre, com Pingentes").
- Os trechos **não são salas fechadas**. As bordas são encostas, vazios para o Poço e paredes baixas que deixam ver o trecho vizinho e o horizonte. Entre um trecho e outro não há porta nem carregamento: o código carrega o vizinho enquanto o grupo cruza uma faixa de transição de 6 m (uma ponte, uma rampa, uma fenda).

### 3.2 Marcos visíveis (a espinha)

Os marcos ficam fixos de Descida para Descida e servem de bússola. O jogador aprende o andar pelo horizonte, mesmo com o miolo mudando.

| Andar | Marcos no horizonte |
|---|---|
| 1. Mata de Lume | A **Coluna do Meio-Dia** (feixe de sol poeirento da boca da Goela), a **Cascata do Beiral** (900 m, vira névoa antes do chão), **o Dente** (estalagmite de 480 m com um mosteiro e janelas acesas), a **Pendura de Baixo** (povoado na parede, com cerca de 100 janelas em cachos ligados por fios de lanterna), as **cortinas de goteira** com fio de luz fria |
| 2. Thessimor Engolida | A capital tombada para o leste, o **Sino** de 30 m preso ao teto por raízes, a **Forja que Não Apaga** (brilho laranja), o **Salão do Trono** pendurado sobre o Poço |
| 3. O Mar Calado | O espelho negro do lago refletindo as algas violetas do teto, ilhas brancas, cais que descem para dentro da água, o **Olho** (a Coluna refletida como ponto branco) |
| 4. O Fundo | A **Língua**: uma rampa de carne-pedra que desce para um brilho que respira |

A **rede de lanternas da guilda** é um marco que o próprio grupo constrói (seção 3.4).

### 3.3 Segredos e eventos

**Segredos** (de 1 a 3 por andar):
- uma parede que fuma para dentro na Inspira (passagem para um nó secreto);
- um poço sem fundo (o Prumo não bate: bolsão com cofre);
- uma marca de giz de explorador morto (às vezes mente);
- uma laje rachada que cede com um golpe pesado (desce para um Cofre);
- uma janela acesa da Pendura de Baixo que pisca em código (um contrato secreto).

**Eventos** (1 ou 2 por andar, sorteados entre 15):

| Evento | O que acontece | Decisão |
|---|---|---|
| Linha comida | Roicordas roendo uma linha de lanternas da guilda | Defender por 30 s, ou deixar a linha cair e a rede perder 1 âncora |
| Sino fora de hora | Uma Prende extra de 40 s: elites andam e os Ouvidores ouvem ×1,5 | Esconder-se ou caçar |
| Explorador no Âmbar | Um rival preso em resina | Libertar (vira ajudante por 1 andar) ou saquear a mochila (+15 kg, e ele vira Afundado depois) |
| O Penhorista em balanço | Uma loja extra, mas a corda dele está sendo roída | Comprar rápido |
| Altar da Boca | Um Pacto do Fundo, guardado por 2 Cultistas | Aceitar ou não |
| Desabamento | O chão cede no meio do trecho | Cair no Cofre de baixo (ganha um nó) ou segurar a borda: o Cavaleiro crava o escudo, a Arqueira prende uma flecha de corda |
| Guilda rival | 3 exploradores da Roldana disputando um cofre | Lutar, ajudar (eles dividem) ou esperar e roubar |
| A Pilha do Afundado | O seu Afundado de uma corrida anterior | Recuperar 50% da Carga |
| Respiração Longa | A Expira dobra e o chão esporado se espalha | Usar a seu favor (Fulgor) ou fugir |
| Chuva de Cima | A Cascata engrossa, as goteiras viram cortinas, poças por toda parte | A Corrente fica perigosa e poderosa |
| Poço do Prumo | Uma aposta de sonda: jogar o Prumo e escolher a profundidade | Mais fundo dá mais prêmio, mas o Prumo pode ficar preso por 1 trecho |
| Mapa no chão | O mapa de um Afundado | 50% de chance de ser verdade |
| Ninho aberto | Casulos de ovos de Bocalume na teia, depois de reação grande | Limpar (rende Penduricalho) ou contornar |
| Caravana de mulas-besouro | Besouros cegos carregando o saque de outra guilda | Escoltar (ouro) ou assaltar (Carga e inimigos) |
| Procissão da Boca | Cultistas levando um explorador vivo amarrado até um Altar | Emboscar (resgate e Lastro) ou deixar passar e saquear o Altar vazio depois |

### 3.4 A rede de lanternas: o que persiste entre corridas

Cada andar tem **12 âncoras** de rocha-mãe na espinha, que nunca mudam de lugar. **Acender** uma âncora leva 8 s com o botão segurado. Durante esse tempo a âncora atrai uma onda, e a luz sobe pela corda em sequência, uma lanterna a cada 0,08 s, como um pavio. Uma âncora acesa:
1. **fica acesa para sempre** (salvo pelo evento "Linha comida") e pendura uma linha de lanternas até a âncora acesa mais próxima, visível do horizonte em todas as Descidas seguintes;
2. **ilumina os trechos vizinhos**: postes da guilda acesos em até 20 m, menos emboscada e uma zona segura de 6 m em volta da âncora;
3. **libera o cabo de despacho** (até 20 kg por âncora, por Descida);
4. **abre atalhos**: com 4 âncoras acesas num andar, a jaula pode começar a Descida no andar seguinte;
5. **aparece na Mesa** como um alfinete com fio de lã aceso, e **no Içamento** como linhas de luz quente passando do lado de fora da jaula.

O progresso da campanha **se vê no horizonte**: depois de 20 Descidas, as paredes da Goela estão costuradas de fios de luz quente. É a coisa mais bonita que o jogador constrói.

### 3.5 A Respiração dentro do roguelite

O ciclo foi comprimido para caber num andar: **6 min no total**, com Inspira de 2 min 40 s, Prende de 40 s e Expira de 2 min 40 s. Um andar vê de 2 a 3 ciclos.

| Fase | O que se vê e ouve | Efeito de jogo |
|---|---|---|
| **Inspira** | Vento frio sobe; névoa se desmancha; capas, a crista do Cavaleiro, a ponta do chapéu da Maga e as chamas das lanternas apontam para cima; esporos sobem para dentro das fendas | Visibilidade alta. Paredes falsas "fumam para dentro" |
| **Prende** | O Sino badala; tudo para; poeira, esporos e gotas ficam suspensos no ar | Elites andam; Ouvidores ouvem ×1,5. É o melhor momento para passar escondido |
| **Expira** | Uma frente de névoa morna sobe do Poço a 15 m/s; os fungos acendem um a um do fundo para fora | O chão aberto ganha estado esporado aos poucos; os inimigos ficam mais ativos; os fungos chegam ao máximo do brilho |

---

## 4. As quatro interações co-op dentro do roguelite

### 4.1 Chão que guarda estados e reações montadas por duas pessoas

O chão é uma grade de **células de 1,5 m**, e cada célula guarda até 2 pinceladas. Estados: molhado, envisgado, em brasa, eletrificado, consagrado, esporado e afundado.

**Força da reação:**
- montada por duas pessoas diferentes: **1,0**;
- por uma pessoa só: **0,5**;
- com o ambiente fornecendo uma das matérias (poça, esporos da Expira, cuspe de inimigo): **0,75**;
- jogador com ajudante de IA: **0,8**.

**No roguelite:** os trechos têm estado (alagado, esporado), o Veio reescreve uma reação por corrida e os Penduricalhos modificam reações. A química que o grupo domina muda a cada Descida.

**Matérias das classes iniciais:**
- **Brasa:** Cavaleiro (a Lâmina Acesa, a espada passada na chama da lanterna de cinto);
- **Visgo e Água:** Arqueira (flecha de resina e flecha d'água);
- **Estalo:** Maga (o raio do cristal do cajado);
- **Sal:** Clérigo (sal bento da Coluna; a célula salgada fica **consagrada**).

Esporo vem do ambiente e do Druida. Fundo vem da Goela, dos Cultistas e do Bárbaro.

| Matérias | Reação | Efeito com força 1,0 |
|---|---|---|
| Sal + Água | **Água Benta** | 30 de dano em mortos-vivos e Afundados, depois 8/s neles por 4 s em 3 m; aliados na área curam 6/s; cega mortos-vivos por 2 s |
| Estalo + Água | **Corrente** | 30 de dano e atordoa por 1,2 s tudo o que estiver molhado na poça. **Quem está envisgado não toma nada** |
| Brasa + Esporo | **Fulgor** | Explosão de poeira: 60 de dano em 4 m, empurrão de 3 m, ilumina 10 m por 5 s |
| Brasa + Visgo | **Piche Ardente** | Chão em chamas e grudento por 6 s: 10/s e lentidão de 50% |
| Visgo + Estalo | **Âmbar** | Em inimigo: casulo de 2,5 s. Em aliado: casca que absorve 40 de dano |
| Sal + Brasa | **Clarão** | Luz branca de 8 m por 0,6 s: cega por 2 s e **interrompe qualquer telegrafia** |
| Sal + Visgo | **Crosta de Sal** | Parede de 3 × 1,5 m por 8 s; bloqueia projéteis e tapa fendas |
| Esporo + Água | **Floração** | Cogumelo de 2 m de altura em 0,4 s; dura 12 s e cura 3/s quem está em cima |
| Estalo + Esporo | **Enxame de Lume** | 6 faíscas de 8 de dano que caçam inimigos em 8 m |
| Sal + Fundo | **Purga** | 60 de dano em Afundados e Cultistas, limpa o chão afundado e devolve a cor ao lugar |
| Brasa + Fundo | **Fogo Fundo** (ruim) | Suga todos em 5 m para o centro por 2 s e queima 8/s, aliados incluídos |
| Estalo + Fundo | **Estática Morta** (ruim) | A descarga salta para o aliado mais próximo: 25 de dano |

**Fogo amigo construtivo.** O núcleo é o **Visgo isolante**: a Arqueira acerta a Maga com uma **flecha de resina** (15% mais lenta por 6 s, **imune a eletricidade**), ela entra na poça cercada e eletrifica a água. Outros usos no aliado:
- **Floração** debaixo do amigo o levanta 2 m até uma beirada;
- **Sal** no amigo em chamas apaga o fogo e o esconde dos mortos-vivos por 4 s;
- **Esporo** no amigo o transforma numa lanterna andante (5 m de luz por 10 s). Se alguém o acender, ele explode num Fulgor e leva metade do dano;
- **Lâmina Acesa** no escudo envisgado do Cavaleiro: o escudo vira uma tocha de Piche que ele empurra contra o bando.

O dano de reação em aliados é de 100% com até 2 jogadores, 70% com 3 e 50% com 4.

**Pares naturais das classes iniciais:** Arqueira + Maga (Corrente e Âmbar, o Visgo isolante); Cavaleiro + Arqueira (Piche Ardente: ela envisga o bando, ele acende); Cavaleiro + Clérigo (Clarão: interrompe a telegrafia de elite e chefe); Clérigo + Arqueira (Água Benta: a flecha d'água no sal consagrado cura o grupo e queima mortos-vivos); Maga + ambiente (Enxame de Lume na Expira).

### 4.2 Lance: passar a arma ou o item no meio do golpe

- **Quando:** entre o fim da antecipação e o fim da janela de cancelamento de qualquer golpe (a janela de cada golpe está nas fichas da seção 7). Pode-se soltar a arma, o Prumo, a lanterna ou um saco de saque em arco para um aliado a até 12 m.
- **Voo:** 0,45 s.
- **Recepção:** quem aperta **Pegar** nos últimos 0,25 s do voo (0,35 s no toque) faz o golpe de recepção da sua classe.
- **Custo:** quem arremessa fica 3 s sem arma (luta com os punhos, 6 de dano) ou até pegar outra.

| Item | Cavaleiro | Arqueira | Maga | Clérigo |
|---|---|---|---|---|
| **O Prumo** (1 por grupo) | **Mangual:** enrola a corda do Prumo no punho e dá um golpe descendente de mangual; 70 de dano em 3 m; racha lajes | **Tiro de Lastro:** prende o Prumo numa flecha e o dispara num arco alto; cai a até 16 m com 55 de dano em 2,5 m e deixa a célula afundada como armadilha | **Para-raio:** o Prumo carrega no cristal e volta como dardo; 50 de dano + Estalo | **Consagração:** crava o Prumo como estaca e bate nele com a maça; onda de 4 m que derruba e pincela Sal |
| Arma de aliado | Usa a arma com a força dele | Atira de volta como flecha, com dano dobrado | Encanta com Estalo por 6 s e devolve | Abençoa (+30% por 8 s) e devolve |
| Saco de saque | Apara no escudo e segue sem perder velocidade | Puxa no ar com a flecha de corda a até 18 m | — | — |

**No roguelite:** o Prumo é o único item que todos querem. Penduricalhos e Graças modificam as recepções, e o Lance de sacos é o verbo central do Içamento (pegar o saco que uma Roicorda roubou antes que ela pule).

### 4.3 Maquinaria em dupla e o caído que continua jogando

| Máquina | Onde | Como funciona |
|---|---|---|
| **Jaula da Guilda** | Descida e Içamento | Duas manivelas (subir mais rápido), um freio (parar no patamar intermediário) e o cabo para defender |
| **Guinchos de ponte** | Nós de Máquina | Dois guinchos em lados opostos, girados ao mesmo tempo, sobem uma ponte que abre um atalho |
| **Contrapesos dos Cofreiros** | Masmorras de mesa | Um sobe no prato, o outro solta a trava |
| **Comportas** | Andar 3 | Abrir uma alaga uma área e seca outra |
| **Prumo-sonda** | Poço do Prumo | Um desce o Prumo, o outro escuta e marca o mapa |
| **Barco de dois remos** | Andar 3 | Um remo por lado; com um só, o barco gira |
| **Cabo de despacho** | Âncoras | Um prende o saco, o outro gira |

Toda máquina funciona por **posição e por segurar**, não por ritmo exato, para tolerar 150 ms de rede.

**O Desbotado** (herói caído há mais de 6 s):
- vira um herói cinza, um pouco transparente, que anda a 1,2× a velocidade, não toma dano e não ataca;
- **gira guinchos e manivelas com força total** ("os que ficaram embaixo puxam corda") e opera alavancas com metade da força;
- **sopra:** espalha esporo ou água para as células vizinhas e conta como segunda pessoa numa reação (força 0,75);
- **assusta** um inimigo comum por 1 s (recarga de 6 s);
- volta quando um aliado o **repinta** (2 s segurando o botão; a cor sobe da base à cabeça) ou ao tocar numa âncora acesa (5 s). Volta com 50% de vida;
- **custo:** derruba 30% da Carga dele em sacos que qualquer um pode pegar.

No Içamento, os Desbotados giram as manivelas: um grupo com dois mortos ainda sobe.

### 4.4 Manchas de matéria nos inimigos

Nos inimigos, a matéria aparece como **pincelada de tinta** na cor do jogador que aplicou, com um ícone de forma própria: gota (Água), losango (Estalo), chama (Brasa), cristal de três pontas (Sal), fio (Visgo), ponto (Esporo). Dura 5 s, com até 2 por alvo. A mira automática **prefere o alvo pincelado por outra pessoa**, e a pincelada pisca na cor de quem preparou. **Reação feita em alvo preparado por outra pessoa** dá +10% de Lastro na corrida: o roguelite premia a autoria cruzada.

### 4.5 Solo com ajudante

Quem joga sozinho leva um de dois ajudantes:
- **Mercenário de chapéu:** uma classe à escolha, que prepara alvos e nunca detona reação ruim perto do jogador;
- **Besouro-de-carga:** não luta, carrega 40 kg, opera qualquer metade de máquina por comando e serve de segunda alça nas relíquias.

**Ordens:** siga, segure aqui, prepare o meu alvo, pegue o Lance. **Regra de ouro:** o ajudante nunca eletrifica poça com o jogador molhado e sem Visgo, nunca bloqueia passagem, e o fogo amigo dele no jogador é de 25%. O ajudante sai quando chega outro jogador e volta quando ele sai.

**Como o mercenário joga cada classe inicial:**

| Mercenário | Comportamento |
|---|---|
| **Cavaleiro** | Fica entre o jogador e o maior grupo de inimigos, bloqueia projéteis que vêm na direção do jogador e usa a Pancada de Escudo para empurrar o bando para dentro das poças. Acende a lâmina quando vê Visgo ou Esporo no chão |
| **Arqueira** | Fica a 8 a 10 m. Prepara poças com flecha d'água perto dos inimigos, envisga o jogador antes que ele (ou um inimigo) eletrifique a poça e pega no ar os sacos roubados |
| **Maga** | Só eletrifica poça com o jogador seco ou envisgado. Guarda o Estalo carregado para alvos pincelados pelo jogador e usa o Lampejo para sair de perto quando é cercada |
| **Clérigo** | Fica a 4 m do jogador. Abençoa quando ele perde 40% da vida, pincela Sal sob elites para o jogador fazer o Clarão e levanta o jogador caído em 1 s |

---

## 5. Escala e combate: números gerais

| Grandeza | Valor |
|---|---|
| Vida dos heróis | Cavaleiro 170, Clérigo 140, Arqueira 100, Maga 90 |
| Esquiva | 2 q de início, 12 q invulnerável, 10 q de recuperação, 4,5 m, recarga de 0,6 s. A Arqueira rola para trás; os outros dão um passo largo com rolamento curto |
| Esquiva com Carga acima de 50 kg | Vira tombo: 2,5 m, 8 q invulnerável, 16 q de recuperação |
| Telegrafia de inimigo comum | 24 a 36 q, sempre com som no fim |
| Telegrafia de elite | 40 a 54 q |
| Telegrafia de chefe | 45 a 90 q, com marca no chão do tamanho real |
| Cor de perigo | **Magenta `#F03C9E`**, só em telegrafia e em reação que fere |
| Golpe pelas costas | +50% para todos; +100% para o Ladino |
| Dano de queda | Cair no vazio leva o herói de volta à beirada em 2 s, com 15 de dano. Nunca é morte instantânea |
| Escala por número de jogadores (1/2/3/4) | Inimigos ×1,00/1,35/1,70/2,05; vida de comuns ×1,00/1,15/1,30/1,45; elite e chefe ×1,00/1,60/2,20/2,80 |

---

## 6. Classes

As classes são **arquétipos clássicos de RPG**, reconhecíveis em um segundo: Cavaleiro, Arqueira, Maga e Clérigo no início, e Ladino, Bárbaro, Druida, Bardo e Paladino como desbloqueáveis. Não há gimmick inventado. O que faz cada um ser deste jogo, e não de outro, é a **estilização**: a proporção cabeçuda, o rosto talhado, a forma forte vista de cima, o figurino em camadas com paleta própria e os detalhes de explorador do abismo (lanterna de guilda no cinto, corda, fuligem, remendos, Penduricalhos tilintando).

### 6.1 O padrão de personagem (herdado de Wickwain)

Todo herói segue o mesmo contrato de modelo, para que os nove pareçam do mesmo jogo e com o mesmo acabamento:

- **Proporção:** 2,25 cabeças; 0,9 m de altura; cabeça de 0,4 m; corpo atarracado, de base larga e pés grandes, que **plantam** no chão.
- **Rosto de cera talhada:** facetado, sem bochecha rosada de boneco. Plano de bochecha marcado, nariz em bloco, vinco talhado sob cada olho, boca recortada. Expressão por **blend shapes**: piscar, sobrancelhas (2 eixos), boca neutra, esforço/brado no golpe, dor, alegria e o canto torto da ironia.
- **Rosto sempre visível, de frente e de cima** (câmera a 46°): nada cobre o rosto. A viseira do Cavaleiro fica levantada, a aba do chapéu da Maga é virada para cima na frente, o capuz da Arqueira é curto e recuado.
- **Olhos de botão:** um botão escuro de fuligem com brilho de 1 px. O shader `olho` desenha o branco, a pupila, o brilho e a pálpebra, com 4 parâmetros (abertura, inclinação, curva e pupila). A sobrancelha é uma peça talhada separada, que faz metade da expressão.
- **Mãos:** luvas de 3 dedos **com polegar separado** e com forma, em três poses (punho fechado, mão aberta e pegada real no cabo da arma).
- **Adereço-símbolo:** grande e **legível de cima**. Esse é o defeito que a v2 não resolveu: dois heróis viravam discos na câmera de jogo **[medido em `silhuetas.png`]**. Na v3, cada classe é desenhada primeiro pela **silhueta vista a 46° de cima**, e só depois de frente.
- **Contorno:** casca invertida de 1,5 a 2 px em 1080p, na cor escura do próprio material (marrom de lavagem nos quentes, azul-negro nos frios), nunca preta.
- **Figurino com paleta própria:** cada herói tem 2 ou 3 cores principais e um acento, com valores bem distribuídos (um claro, um médio, um escuro), e **pelo menos 4 materiais que contrastam** (metal escurecido com latão, couro envelhecido, tecido tingido com barra bordada, pele, madeira, corda). Nada de herói de uma cor só.
- **Ganchos visuais:** cada herói tem 3 detalhes memoráveis com história (está em cada ficha), que sobrevivem à miniatura de 320 × 180.
- **A identidade nunca depende da cor do jogador.** A cor do jogador entra só como **acento pequeno e trocável**, de 5 a 8% da área vista de cima (uma fita, um lenço, um forro, um cordão), mais a **luz de borda** e o **anel da base** com sinal de forma (círculo, quadrado, triângulo, losango). O acento leva o **padrão de pano** do jogador (liso, listras diagonais, xadrez, barra de losangos), porque cor nunca é o único código: a v2 falhou no portão de deuteranopia entre Âmbar e Verde-veneno **[medido]**.
- **Jogadores:** Âmbar `#F0A030`, Verde-veneno `#7CD04A`, Cobalto `#3E7CF0` e Branco-giz `#F2EEE6`.
- **Dois jogadores com a mesma classe:** distinguem-se pelo acento, pelo anel e pelo padrão, e podem escolher uma das 2 **variantes de figurino** da classe (mesma forma, paleta alternativa, no Pintor de Brasões).
- **Dano visível:** a cada 25% de vida perdida, a tinta lasca e a cera do rosto racha em mais lugares (máscara na textura). Curar fecha as rachaduras.
- **Escala de jogo:** os ícones são exagerados só no modelo de jogo (escudo 1,25×, arco 1,2×, cajado e cristal 1,25×, maça 1,3×).

### 6.2 Acabamento técnico (o que tira o herói do "genérico")

- **Deformação de verdade, sem reposição de partes.** Tronco, pescoço, braços, mãos e pernas formam **uma malha contínua**, com pesos suaves de 2 a 4 ossos por vértice e falloff nas juntas (ombro, cotovelo, punho, quadril, joelho, tornozelo, pescoço e coluna), loops de aresta extras nas juntas, ossos de twist no braço e no antebraço, ossos de ajuste no cotovelo, no joelho e no ombro, e shape keys corretivas exportadas como blend shapes acionadas pelo ângulo da junta no Godot. **Pano mole** (capa, manto, tabardo, capuz, saia de malha) deforma por pesos e molas sem atravessar o corpo. **Peças rígidas** só no que é rígido de verdade (lâmina, escudo, elmo, placas, maça, arco fora da puxada), coladas à malha sem fresta.
- **Texturas pintadas por código.** UV por peça, bake no Blender de AO, curvatura e cavidade, e um atlas de 1024 a 2048 por herói com gradiente de luz de cima para baixo, desgaste nas arestas, sujeira nas cavidades, trama, costuras e remendos no tecido, grão e rachaduras no couro, riscos, polido nas bordas e ferrugem leve no metal, veios e lascas na madeira, e blush e variação na pele. Mapas de rugosidade, metal e normal (costuras, rebites, trama) compostos por código. Tudo **fosco**: nada de plástico brilhante. Compressão VRAM no PC e ETC2/ASTC na web, com mipmaps.
- **Renderização de qualidade.** Difuso com rampa suave pintada (terminador com leve cor quente na pele, o falso subsurface), AO assada e oclusão de contato, especular por material (metal com reflexo nítido e leve anisotropia; couro com brilho fosco; tecido sem brilho e com sheen na borda; pele com brilho só na ponta do nariz e nas bochechas), luz de borda controlada na cor do jogador, sombras próprias nítidas e sombra de contato no chão. **[PC]** SSAO, sombra suave, a lanterna de cinto iluminando o próprio herói e reflexo de ambiente simples no metal. **[iPhone]** a mesma leitura com AO e luz assadas.
- **Provas obrigatórias:** folha de deformação (cotovelo e joelho dobrados de 90° a 130°, ombro erguido, quadril torcido e agachamento, sem quebra, buraco, interseção ou perda de volume); close de rosto e busto na luz da caverna (fria de cima e quente da lanterna) ao lado da versão anterior; cada herói com as 4 cores de jogador; o grupo com dois jogadores da mesma classe.

### 6.3 O Cavaleiro (tanque, corpo a corpo, Brasa)

- **Silhueta de cima:** **um D com crista.** O escudo redondo preso ao braço esquerdo fica à frente do corpo como um arco grosso de madeira e ferro; a **crista de crina** do elmo corre da testa à nuca e risca a cabeça redonda com uma linha clara; a espada de lâmina larga, apoiada no ombro em guarda, faz uma diagonal curta para trás.
- **Adereço-símbolo:** o **escudo-roda**, de 0,6 m: tábuas de carvalho mel em raios, aro de ferro preto, 8 cravos de latão e umbo de ferro no centro; uma tábua remendada com chapa rebitada e **riscos de giz** contando as Descidas que ele voltou vivo. A **espada** de lâmina larga (0,55 m), com gume polido, miolo escurecido, guarda reta de latão e punho de couro enfaixado.
- **Elmo:** bacinete de aço escurecido com **viseira de bico levantada** (o rosto fica livre de frente e de cima) e a crista de crina tingida de ferrugem-escura.
- **Rosto:** maxilar largo, **nariz quebrado torto**, **bigode espesso caído**, sobrancelha grossa talhada num bloco só, cicatriz no queixo, olhos de botão firmes. No esforço, mostra os dentes cerrados por baixo do bigode.
- **Corpo:** o mais largo (1,15 × 0,93). Peitoral e ombreiras de placa sobre **gibão acolchoado com costura em losango**, cota de malha nas axilas e na saia, cinto largo de fivela de latão, **lanterna de óleo da guilda** pendurada no quadril e um rolo de corda no ombro.
- **Figurino e paleta:** aço escurecido azul-grafite com bordas polidas, latão velho, gibão **bordô profundo**, couro castanho, carvalho mel. **Acento do jogador:** a fita na ponta da crista e o lenço amarrado na alça do escudo.
- **Ganchos visuais:** o escudo-roda com remendo e contagem de giz; a crista de crina; o bigode e o nariz quebrado emoldurados pela viseira levantada.
- **Personalidade:** honrado, teimoso e meio fora de época: o último sentinela da Ordem da Borda, que penhorou o cavalo para pagar a guilda. Antes do especial, bate a espada duas vezes no aro do escudo ("tém, tém", 14 q).
- **Habilidades:** **Escudo** (segurar: bloqueio de 80% num cone de 120°, com aparar nos 8 primeiros quadros; tocar: **Pancada de Escudo**, investida de 3 m com empurrão de 3 m e atordoamento de 0,6 s; recarga de 6 s); **Lâmina Acesa** (passa a lâmina na chama da lanterna do cinto: por 8 s, cada golpe pincela Brasa e deixa um rastro de fagulhas; recarga de 12 s); **Último Posto** (especial: crava o escudo no chão por 5 s; provoca todos os inimigos em 8 m, e os aliados atrás dele tomam 50% menos dano).

### 6.4 A Arqueira (dano à distância, Visgo e Água)

- **Silhueta de cima:** **um arco atravessado com leque.** Em guarda, o arco longo fica atravessado na diagonal do ombro ao quadril oposto e passa do corpo dos dois lados; a aljava às costas abre um **leque de penas** atrás da cabeça; o capuz curto termina numa ponta que cai para trás. Mirando, o arco fica de pé e a silhueta vira uma linha com uma seta à frente.
- **Adereço-símbolo:** o **arco longo** de teixo vermelho-escuro, de 1,25 m (mais alto que ela), com empunhadura de couro trançado e pontas de chifre; a **aljava** de couro com três maços de flechas que se leem pela ponta: ferro, **bexiga d'água** azul-cinza e **resina âmbar** que brilha fraco. Braçadeira de couro gravado no antebraço do arco.
- **Rosto:** rosto em coração, nariz fino e reto, sardas talhadas, um **risco de fuligem sob cada olho** (contra o brilho da Coluna), olhos de botão atentos, com uma sobrancelha sempre mais alta que a outra. Uma mecha castanho-escura presa por uma pena. Ao mirar, fecha um olho e morde o lábio.
- **Corpo:** magro e firme (0,9 × 1,04), pernas longas para a proporção, botas macias de cano alto amarradas, luva de três dedos na mão da corda.
- **Figurino e paleta:** capa curta e capuz de lã **verde-oliva escuro** com barra bordada em fio de cobre (um friso de andorinhas), gibão de **couro de cervo mel** com costuras aparentes, linho cru, cinto de bolsas e uma **lanterna de cinto pequena**. **Acento do jogador:** o forro do capuz e a fita da aljava.
- **Ganchos visuais:** o arco maior que ela; o leque de penas da aljava; os riscos de fuligem sob os olhos.
- **Personalidade:** calma, precisa, de poucas palavras e humor seco; caçadora das bordas de Pendura, que conhece o abismo pelo som. Parada, gira uma flecha entre os dedos e testa a corda com um "tum" baixo.
- **Habilidades:** **Flecha de Resina** (a ponta estoura numa poça de Visgo de 2,5 m por 6 s; inimigos 40% mais lentos; aliados atingidos ficam envisgados e **imunes a eletricidade**; recarga de 6 s); **Flecha d'Água** (a bexiga estoura e alaga 3 células em linha; molha quem estiver nelas; recarga de 5 s); **Chuva de Flechas** (especial: atira para o alto e, 30 q depois, 12 flechas caem num círculo de 4 m, cada uma com a última matéria usada). A **flecha de corda** (pegar sacos no ar e prender bordas) é a variante do tiro carregado quando mira um saco ou uma beirada.

### 6.5 A Maga (controle elemental, Estalo)

- **Silhueta de cima:** **uma vírgula com estrela.** Chapéu pontudo de aba larga com a **ponta torta caída para trás**, passando da aba (de cima, um círculo com rabo, não um disco); o **cajado** segurado inclinado à frente termina no cristal aceso (de cima, uma linha que acaba numa estrela de luz, deslocada do corpo).
- **Adereço-símbolo:** o **cajado** de 1,1 m, de madeira escura de raiz retorcida, com cintas de cobre e uma **garra de cobre de 4 dedos** segurando um cristal de quartzo do tamanho de um punho. **O cristal fica no cajado, não no chapéu.** Em repouso, ele guarda uma luz âmbar-mel, quente como os heróis; ao carregar, esfria para ciano-elétrico e ilumina 5 m.
- **Chapéu:** feltro gasto e remendado, **aba virada para cima na frente** e presa por um broche de latão (o rosto aparece de cima), com amuletos pendurados na aba: um sininho, um dente de Ouvidor, uma pena.
- **Rosto:** jovem, nariz arrebitado, sardas, sobrancelhas arqueadas e muito expressivas, olhos de botão grandes com o reflexo do cristal, **óculos redondos de latão** empurrados para a testa. Uma **trança grossa cor de cobre** sobre o ombro, presa com mola.
- **Corpo:** estreito em cima e largo embaixo, um sino (0,9 × 1,08). Manto até as canelas com a barra chamuscada; botas pontudas aparecem no passo.
- **Figurino e paleta:** feltro e lã **cor de berinjela desbotada**, forro e barra bordada em **mostarda** com runas, cobre e latão, couro tabaco. Um **livro de feitiços preso ao cinto por corrente**, com páginas soltas, e um mapa enrolado. **Acento do jogador:** a fita da base do chapéu e o forro da gola.
- **Ganchos visuais:** o chapéu de ponta torta com amuletos; o cajado com garra de cobre e cristal que ilumina o rosto; os óculos e o livro acorrentado.
- **Personalidade:** nervosa, curiosa e orgulhosa; aprendiz expulsa da Academia de Pendura por explodir o telhado. Toda magia termina com uma pose de "olha só" de 8 q.
- **Habilidades:** **Estalo em Cadeia** (raio que salta entre 3 alvos: 20/14/10 de dano, pincela Estalo; recarga de 5 s); **Lampejo** (teleporte de 5 m que deixa no ponto de partida um eco de estática que pincela Estalo na célula; recarga de 7 s); **Tempestade de Bolso** (especial: nuvem de 4 m por 5 s que solta 8 raios nos alvos molhados ou pincelados, antes dos outros).

### 6.6 O Clérigo (suporte e cura, Sal)

- **Silhueta de cima:** **um haltere.** Ombros largos e redondos, com a **maça** de cabeça enorme de um lado e a **lanterna-relicário** erguida do outro, as duas além da largura dos ombros; a tonsura faz um círculo claro no alto da cabeça.
- **Adereço-símbolo:** a **maça de guerra**, com cabeça de ferro escurecido de 6 flanges e cabo de freixo enfaixado em couro; e a **lanterna-relicário** de latão, com vidro âmbar e o **Sol-Prumo** (um sol atravessado por um fio de prumo) recortado na tampa, presa numa haste curta. É o símbolo sagrado dos Clérigos da Coluna, que veneram a luz do meio-dia que desce pela boca da Goela.
- **Rosto:** bochechas largas, nariz em bola, **tonsura**, **barba cheia grisalha trançada em duas pontas com contas de latão**, sobrancelhas espessas, pés de galinha talhados, olhos de botão bondosos. No golpe, a boca abre num brado.
- **Corpo:** barrigudo e firme (1,1 × 0,95), pernas curtas e plantadas. Túnica de lã longa, **tabardo** com o sol bordado, cota de malha curta nos ombros, cordão na cintura com **frascos de sal** e um livro de orações.
- **Figurino e paleta:** lã **cor de osso** com a barra manchada de fuligem, tabardo **cinza-ardósia** com o Sol-Prumo em fio de **ouro velho**, malha escurecida, couro preto e latão. **Acento do jogador:** a fita da lanterna e o cordão da cintura.
- **Ganchos visuais:** a lanterna-relicário erguida; a maça de cabeça enorme; a barba trançada com contas.
- **Personalidade:** caloroso, barulhento e firme; capelão da guilda que cobra "taxa de bênção" e perdoa a dívida de quem está morrendo. No reviver, bate de leve com a lanterna na testa do aliado. Levanta um caído em 1 s.
- **Habilidades:** **Bênção** (ergue a lanterna: anel de luz de 5 m que cura 30 nos aliados e pincela Sal nas células; recarga de 9 s); **Sal Bento** (punhado de sal num cone de 4 m: pincela Sal e cega mortos-vivos por 1 s; recarga de 6 s); **Chão Consagrado** (especial: 5 m de chão consagrado por 6 s, onde mortos-vivos e Afundados param de avançar, aliados não desbotam e curam 6/s).

### 6.7 As cinco classes desbloqueáveis (chapéus achados)

Os chapéus (elmos, capuzes e chapéus) aparecem em nós específicos com uma chance por Descida. Usar o chapéu na hora é grátis. Para **registrá-lo** na Sede, é preciso subir com ele (pesa 2 kg e vai na Carga) ou despachá-lo numa âncora. As cinco seguem a mesma regra das iniciais: arquétipo clássico, estilização própria, figurino com paleta própria.

| Classe | Onde se acha | Silhueta de cima, adereço e figurino | Matéria e papel | Recepção do Prumo |
|---|---|---|---|---|
| **Ladino** (furtivo, punhais) | Fundo do "Cofre do Peixe" e de outras masmorras de mesa | **Um S**: cachecol longo que esvoaça atrás e dois punhais curvos. Capuz de feltro carvão, colete de couro preto com mil bolsos, gazua no cinto e lanterna furta-fogo (a de portinhola) | Sem matéria própria. **Surrupiar:** rouba a pincelada de um inimigo e a guarda para o próximo golpe. +100% pelas costas | **Malabarismo:** joga o Prumo por cima do alvo, some numa nuvem de fuligem e reaparece atrás para pegá-lo; 45 de dano pelas costas |
| **Bárbaro** (dano corpo a corpo, fúria) | Altar da Boca, depois de aceitar 3 Pactos | **Um machado**: machado de duas lâminas enorme nas costas, ombreira de pele de urso-das-cavernas com o crânio. Pele tatuada a fuligem, tranças com argolas de ferro | Fundo, a matéria perigosa. **Fúria:** transforma reações ruins (Fogo Fundo, Estática Morta) em armas, com custo de vida | **Arremesso Bruto:** gira o Prumo duas vezes pela corda e o solta em linha; 60 de dano e empurrão de 4 m em tudo que estiver no caminho |
| **Druida** (cura e controle, Esporo) | Colônia gigante do Andar 1, na Expira | **Uma galhada**: coroa de raízes ramificadas com cogumelos pequenos crescendo nela, manto de musgo e casca, cajado de raiz. Pode virar um **texugo-das-cavernas** por 8 s | Esporo. Faz crescer Florações e colônias; cura | **Brotar:** o Prumo cai e vira um anel de 6 cogumelos que levantam e curam |
| **Bardo** (apoio, som) | Sob o Sino de Thessimor (Andar 2) | **Uma pera com braço**: alaúde de costas com braço longo e cravelhas, chapéu de aba com uma pluma longa curvada. Gibão listrado gasto, botas de bico | Sem matéria própria. **Ressoa:** duplica a próxima pincelada aplicada por um aliado num raio de 6 m; o eco revela nós vizinhos | **Acorde:** bate o Prumo nas cordas do alaúde; onda de som de 6 m que atordoa 1,5 s |
| **Paladino** (tanque sagrado) | Elmo do Cavaleiro Tombado (elite do Andar 2) | **Um martelo e um halo**: martelo de guerra de duas mãos e uma auréola de latão presa numa haste atrás do elmo aberto. Armadura escurecida com filetes dourados, capa longa | Sal (como o Clérigo, mas pelo martelo). **Juramento:** aliados em 4 m tomam 20% menos dano; o golpe pesado consagra a célula | **Selo:** crava o Prumo no chão sob o martelo; cúpula de 3 m que bloqueia projéteis por 3 s |

---

## 7. Animação de ataque: ritmo, peso e coerência

Este é o pedido explícito do usuário: **"que as animações de ataques sejam coerentes e bem feitas, com ritmo e peso."** As regras abaixo valem para as quatro classes e para todos os inimigos, e são critério de aprovação.

### 7.1 Regras de peso (valem para todos)

1. **O movimento nasce no quadril e nos pés.** A sucessão é sempre: pé de apoio planta, depois quadril gira (2 a 3 q antes do ombro), ombro (2 q antes do braço), braço, e a arma por último.
2. **Pés não deslizam.** O pé de apoio fica travado por IK do quadro em que planta até o fim do contato. O deslocamento do golpe vem de **root motion** (tabela exportada do Blender, com a mesma curva usada pela lógica e pela rede).
3. **Transferência de peso visível.** Na antecipação, o peso vai para o pé de trás. No contato, passa para o da frente. Os joelhos dobram de 10° a 20° para absorver, e mais no golpe pesado.
4. **Antecipação proporcional ao peso:** de 5 a 7 q num tiro rápido ou numa Faísca, de 6 a 8 q num corte de espada, de 14 a 16 q no golpe descendente do Cavaleiro e no esmagamento da maça.
5. **Arma pesada tem inércia.** Ela atrasa de 3 a 4 q em relação à mão no começo do golpe e passa de 25° a 40° além do alvo depois do contato (a maça do Clérigo é o caso extremo: a cabeça atrasa 4 q). Arma média (a espada) atrasa 1 a 2 q e passa de 15° a 20°. O arco não tem inércia de golpe, mas tem recuo.
6. **Follow-through e sobreposição** em tudo o que é solto (crista do Cavaleiro, capa e capuz da Arqueira, flechas na aljava, ponta do chapéu, trança e amuletos da Maga, barba trançada, tabardo e lanterna-relicário do Clérigo, lanternas de cinto, Penduricalhos), com molas a 60 q por segundo por cima do corpo. As molas sobrevivem ao cancelamento.
7. **Recuperação que mostra o esforço:** o corpo respira fundo, a arma pesa, e o herói volta à guarda com aceleração lenta. Cada quadro da recuperação é uma pose que mistura bem com a guarda e com a esquiva, porque ela pode ser cortada.
8. **Arcos limpos.** A ponta da arma desenha um arco de raio constante. O rastro (smear) segue esse arco e dura de 4 a 8 q.

### 7.2 Ritmo de combo

- **Musical:** o tempo entre os contatos segue **curto, curto, longo**. O último golpe tem mais antecipação, uma pausa (hold) antes do contato, mais hit-stop e câmera.
- **Buffer de comando** nos últimos 10 q de cada golpe. O próximo golpe sai no primeiro quadro cancelável.
- **Janela de cancelamento clara:** golpe em golpe, a partir do fim do ativo mais N quadros (está em cada ficha); esquiva cancela tudo depois do ativo; **nada cancela a antecipação do pesado, exceto a esquiva**.
- **Sinal da janela:** no primeiro quadro cancelável, a arma dá um brilho de 2 q na luz de aresta e soa um clique curto (desligável). O jogador aprende o ritmo pelo olho e pelo ouvido.
- **Cadência por classe:** cada classe anima num ritmo de poses próprio (Clérigo 15 poses por segundo, Cavaleiro e Maga 20, Arqueira 24). Os adereços e as molas rodam sempre a 60.

### 7.3 Coerência: o pacote de impacto no mesmo quadro

**No quadro de contato da animação (marcado na trilha pelo Blender e lido pelo Godot), tudo acontece junto:**
- hitbox ativa;
- hit-stop local (atacante e alvo; os outros jogadores continuam);
- flash no alvo;
- faísca de impacto;
- chute direcional de câmera e trauma;
- som do impacto;
- a pincelada da matéria.

**Nada é disparado por temporizador separado.** A lógica, o efeito e o som ouvem o mesmo sinal `contato(golpe_id, peso)`. Nos projéteis (flechas, Faíscas), o contato é o quadro em que o projétil acerta; o quadro de **soltura** tem seu próprio pacote menor (recuo do arco ou do cajado, clarão na ponta, som de corda ou estalo).

| Quadro relativo ao contato | Evento |
|---|---|
| 0 | Hit-stop começa. Flash branco-quente no alvo (85 a 90% de valor, nunca 100% branco). Faísca, som e anel de impacto. Chute de câmera na direção do golpe |
| 0 até o fim do hit-stop | O alvo treme na horizontal (na vertical se estiver no ar), com amplitude decrescente. O atacante avança 5 a 10% do movimento restante (nunca congela 100%). A arma vibra |
| Fim do hit-stop | O knockback começa na velocidade máxima e desacelera por atrito, com poeira no chão. A pose de dano do alvo chega em 4 q |
| +1 a +4 | Detritos com física simples, poeira, lascas de gesso, osso ou quitina, respingo de poça |
| +6 a +30 | O efeito se dissolve devagar (ataque rápido, decaimento lento). O número de dano sobe e some, se estiver ligado |
| +30 a +600 | Permanência: marca no chão, laje rachada, sal no piso |

**Proporção.** Tudo escala pelo peso do golpe. A reação do inimigo é proporcional ao golpe que ele levou.

| Peso | Exemplo | Hit-stop | Flash | Trauma da câmera | Chute | Faíscas e detritos | Reação do inimigo |
|---|---|---|---|---|---|---|---|
| **Leve** | Tiro Rápido, Faísca | 3 q | 1 q | 0 (nada) | 0 | 4 a 6 faíscas pequenas | Tremor e achatamento 0,92; recua 0,2 m |
| **Médio** | Cortes 1 e 2 do Cavaleiro, Maçadas 1 e 2, Tiro Firme, Arco Voltaico | 6 a 7 q | 2 q | 0,15 | 0,08 m | 8 faíscas, poeira baixa | Achata 0,85; recua 0,6 m e dá um passo para trás |
| **Pesado** | Golpe Descendente, Pancada de Escudo, Tiro e Estalo carregados | 8 a 10 q | 2 q | 0,25 a 0,3 | 0,15 m | 12 faíscas, lascas, anel de 2 m | Achata 0,78; knockback de 1,5 a 2 m com rastro de poeira; tropeça |
| **Finalizador pesado** | Esmagamento do Clérigo, recepção do Prumo | 12 q + câmera lenta 0,5× por 10 q | 2 q | 0,45 | 0,25 m + zoom de 4% | 16 faíscas, detritos, anel de 3 m, poça espirra | Achata 0,7; lançado 3 m, quica 2 vezes, cai e levanta em 40 q |
| **Golpe que mata uma elite** | Qualquer | 16 q + câmera lenta 0,4× por 20 q | 2 q | 0,5 | 0,3 m | Explosão de gesso, osso ou quitina | Parte-se em pedaços com física |
| **Chefe derrotado** | Qualquer | 30 q global + câmera lenta 0,3× por 30 q | 3 q | 0,8 | — | Tudo | Sequência própria |

**Tremor da câmera:** trauma de 0 a 1, tremor = trauma² × amplitude máxima (0,3 m de deslocamento, 2,5° de rolagem), ruído suave de 18 Hz, decaimento de 2 por segundo. Em co-op na mesma tela, o tremor usa **60% do valor da tabela**, e o chute direcional (de 3 a 6 q) fica inteiro: chutar a câmera não atrapalha os outros três, tremer muito atrapalha.

### 7.4 Fichas de timing por classe

**Legenda:**
- **Ant.:** antecipação;
- **Ativo:** quadros em que a hitbox está ligada (o contato é o primeiro);
- **HS:** hit-stop;
- **Rec.:** recuperação;
- **Canc.:** a partir de quando se pode encadear o golpe seguinte e a esquiva, contado a partir do fim do ativo;
- **Δ contato:** quadros entre este contato e o anterior, com o combo jogado no ritmo ideal. No corpo a corpo, Δ = ativo + HS + canc. + ant. seguinte; nos projéteis o hit-stop fica no alvo, e Δ = ativo + canc. + ant. seguinte.

#### Cavaleiro: firme, com o terceiro pesadíssimo ("tchá-tchá ... TUM")

| Golpe | Ant. | Ativo | HS | Rec. | Canc. (golpe / esquiva) | Δ contato | Dano | Peso |
|---|---|---|---|---|---|---|---|---|
| 1. Corte | 8 | 3 | 6 | 16 | +5 / +3 | — | 16 | Médio |
| 2. Revés | 6 | 3 | 6 | 16 | +5 / +3 | 20 | 16 | Médio |
| 3. Golpe Descendente | 14 (das quais 4 de pausa no alto) | 4 | 10 | 30 | — / +12 | 28 | 36, racha a laje | Pesado, trauma 0,3 |
| Pancada de Escudo | 6 + investida de 3 m em 8 | 8 (durante a investida) | 8 | 20 | — / +8 | — | 20, empurrão de 3 m, atordoa 0,6 s | Pesado |
| Bloqueio (segurar) | 4 para erguer | aparar nos 8 primeiros | 4 por golpe bloqueado | 6 para baixar | esquiva a qualquer momento | — | 80% de redução num cone de 120° | — |

Os contatos caem nos quadros 8, 28 e 56. O combo inteiro dura cerca de 1,7 s. O Cavaleiro é o mais lento a matar e o único que segura uma linha: bloqueia, empurra o bando para dentro das poças e protege quem está carregando.

**Tira de poses-chave do combo:**
1. **Guarda (q0):** escudo à frente na altura do peito, espada sobre o ombro, pés afastados, joelhos dobrados, a crista balançando.
2. **Corte, carrega (q0 a q8):** o quadril gira 25° para trás, o peso vai ao pé de trás, a espada recua por cima do ombro (atrasa 1 q), o escudo abre para o lado.
3. **Corte, contato (q8):** o pé da frente planta, o quadril gira à frente 2 q antes do ombro, a lâmina corta na horizontal com smear de 4 q, o escudo fecha no peito.
4. **Revés (contato no q28):** sem voltar à guarda, a lâmina sobe na diagonal de baixo para cima; o tronco gira de volta; a crista atrasa 3 q.
5. **Golpe Descendente, ergue (q0 a q8):** as duas mãos levam a espada acima da cabeça, o escudo baixa para proteger o flanco, o corpo arqueia para trás, o peso vai ao pé de trás e os calcanhares sobem.
6. **Pausa (q8 a q12):** hold no alto, com tremor de esforço de 1° a 2°; a lâmina dá o brilho de leitura.
7. **Desce (q12 a q14):** o pé da frente planta com anel de poeira, o quadril lidera, a lâmina cai com smear vertical.
8. **Crava (q14, contato):** os joelhos absorvem 20°, o corpo achata a 0,88, a lâmina morde a laje e a racha; faíscas e tremor grande.
9. **Arranca e assenta (q28 a q58):** a lâmina fica presa 6 q, ele a arranca com um tranco de quadril, gira a espada no punho e volta à guarda batendo-a de leve no escudo.

**Tira da Pancada de Escudo:** (1) abaixa o ombro e cola o escudo no corpo (q0 a q6); (2) investida de passos largos, cada pé planta a cada 4 q; (3) contato: o escudo achata o alvo, a crista e o lenço chicoteiam à frente; (4) freia em dois passos curtos com poeira, o escudo vibra no braço.

#### Arqueira: tensão e soltura ("tic, tic ... tuuum")

| Golpe | Ant. | Ativo | HS no alvo | Rec. | Canc. (golpe / esquiva) | Δ contato | Dano | Peso |
|---|---|---|---|---|---|---|---|---|
| 1. Tiro Rápido | 7 (puxa até o peito) | 1 (soltura) | 3 | 9 | +4 / +2 | — | 10 | Leve |
| 2. Tiro Rápido | 6 | 1 | 3 | 9 | +4 / +2 | 11 | 10 | Leve |
| 3. Tiro Firme | 12 (das quais 4 de mira parada) | 1 (2 flechas) | 6 | 18 | — / +8 | 17 | 2 × 12, empurrão de 1 m | Médio |
| Tiro Carregado (segurar) | de 24 a 54 de puxada | 1 (perfura até 3) | de 6 a 10, pelo tempo de carga | 20 | — / +8 | — | de 30 a 70 | Pesado |

- **Puxar com o corpo inteiro:** os pés ficam em linha, o quadril gira de lado, as escápulas se fecham, o cotovelo de trás sobe acima do ombro e a corda chega ao canto da boca. O arco **dobra de verdade** (2 ossos por braço do arco) e a corda é uma linha com 3 pontos.
- **Tiro rápido:** puxa só até o peito e solta; a mão da corda volta para a aljava sem parar.
- **Tiro carregado:** pausa viva no pico, com o arco tremendo 0,5° a 10 Hz, a respiração presa (o peito para) e a ponta da flecha acendendo na cor da matéria. A carga máxima dá um brilho de 2 q no gume.
- **Soltura:** a corda vibra 6 q, o **arco salta à frente e gira 15° no punho**, o tronco recua 8° e o pé de trás planta; a capa chicoteia para a frente; a mão da corda segue até a orelha.

**Tira de poses-chave do Tiro Carregado:**
1. Guarda: arco baixo atravessado, flecha encaixada, peso no pé de trás.
2. Encaixa (q0 a q6): gira de lado, pés em linha, o arco sobe na vertical.
3. Puxa (q6 a q24): o corpo inteiro puxa, o cotovelo sobe, o arco curva, a capa assenta.
4. Pico (q24 a q54, segurar): hold vivo, tremor, a ponta acesa, um olho fechado.
5. Solta (quadro de soltura): os dedos abrem, o arco salta e gira, o tronco recua.
6. Acompanha: a mão segue até a orelha, a capa e o capuz chicoteiam.
7. Volta: puxa outra flecha da aljava em 10 q, com as penas da aljava balançando.

#### Maga: conjuração ("ti-ti ... CRAC")

| Golpe | Ant. | Ativo | HS no alvo | Rec. | Canc. (golpe / esquiva) | Δ disparo | Dano | Peso |
|---|---|---|---|---|---|---|---|---|
| 1. Faísca | 6 | 1 (disparo) | 3 | 10 | +4 / +2 | — | 12 | Leve |
| 2. Faísca | 5 | 1 | 3 | 10 | +4 / +2 | 10 | 12 | Leve |
| 3. Arco Voltaico | 14 | 1 (leque de 3 raios curtos) | 6 | 20 | — / +8 | 19 | 3 × 12, pincela Estalo, empurrão de 1 m | Médio |
| Estalo carregado (segurar) | de 30 a 60 de carga | 1 | de 6 a 10, pelo tempo de carga | 22 | — / +10 | — | de 30 a 70 | Pesado |

- **Carga:** o cajado sobe da altura do peito até acima da cabeça. O cristal passa de âmbar para ciano e o raio de luz cresce de 3 para 6 m. **O manto infla com a estática**, a trança e os amuletos do chapéu sobem, os pés afundam de leve e faíscas correm pelas cintas de cobre do cajado. Em carga máxima, o cristal pisca a 6 Hz.
- **Soltura:** o **recuo do corpo** leva o tronco 12° para trás e a Maga **dá um passo de 0,35 m para trás, com o pé plantando** (não desliza). A trança chicoteia para a frente, a ponta do chapéu dá uma volta e o manto desinfla em 8 q.
- **Fim:** pose de exibição de 8 q, com o queixo para cima e os óculos escorregando.
- **As Faíscas saem do cristal** e descrevem um arco curto antes de seguir reto, para que o tiro leia como "saiu do cajado".

**Tira de poses-chave do Estalo carregado:**
1. Guarda: o cajado inclinado, o cristal morno.
2. Carrega: as duas mãos no cajado, o cristal subindo, os ombros tensos, o manto começando a inflar.
3. Carga máxima: o cristal acima da cabeça, a trança no ar, o manto inflado, os olhos brancos de brilho.
4. Solta (disparo): o cajado aponta, o raio sai e o corpo recua.
5. Passo atrás: o pé de trás planta e o joelho absorve.
6. Exibição: o queixo para cima, a mão na cintura, ajeita os óculos.

#### Clérigo: pesado e firme ("TUM ... TUM ...... TUMM-uá")

| Golpe | Ant. | Ativo | HS | Rec. | Canc. (golpe / esquiva) | Δ contato | Dano | Peso |
|---|---|---|---|---|---|---|---|---|
| 1. Maçada | 10 | 4 | 7 | 18 | +8 / +4 | — | 18 | Médio |
| 2. Revés de Maça | 9 | 4 | 7 | 18 | +8 / +4 | 28 | 18 | Médio |
| 3. Esmagamento | 16 (das quais 4 de pausa no alto) | 4 + 1 do pulso de luz | 12 + câmera lenta; 3 no pulso | 32 | — / +12 | 35 | 34 + 10 do pulso, pincela Sal | Finalizador pesado |
| Bênção | 10 (ergue a lanterna) | 4 (o anel abre) | — | 14 | — / +6 | — | cura 30 | — |

- **A cabeça da maça tem inércia:** atrasa 4 q em relação à mão no começo e continua 30° além do braço depois do contato; os flanges arrastam no chão.
- **A lanterna-relicário é o contrapeso:** quando a maça vai à frente, a lanterna vai para trás. No Esmagamento, 5 q depois do contato a lanterna erguida solta um **pulso de luz sagrada** de 3 m: um segundo impacto menor, com hit-stop de 3. É isso que dá o "TUMM-uá".
- **A lanterna continua balançando 40 q** depois que ele para.

**Tira de poses-chave do Esmagamento:**
1. Ergue (q0 a q10): a maça sobe por cima do ombro em arco largo, com a cabeça atrasada; a lanterna vai para trás; o peso vai ao pé de trás; a barba balança.
2. Pausa (q10 a q14): hold no alto, o corpo arqueado, a boca abrindo no brado.
3. Desce (q14 a q16): o pé da frente planta e o quadril gira; a maça cai.
4. Esmaga (q16, contato): os joelhos absorvem 20°, o corpo achata a 0,85, a maça afunda na laje e a racha.
5. Pulso (5 q depois): a lanterna erguida acende, anel de luz e sal no chão.
6. Apoia: o peso no cabo cravado, respira fundo, enxuga a testa com o antebraço.
7. Arranca e volta: tranco de quadril, a maça volta ao ombro, a lanterna balança 40 q.

**Tira da Bênção:** (1) firma os pés e ergue a lanterna acima da cabeça em 10 q, o corpo estica a 1,06; (2) a luz abre em anel em 4 q e a barba e o tabardo sobem; (3) desce a lanterna em 14 q com um aceno de cabeça.

### 7.5 Corpo, ciclos e idle

| Item | Valor |
|---|---|
| Andar | Ciclo de 40 q (passo de 20). O quadril sobe e desce 3 cm, gira 6° e rola 4°. Os braços balançam em oposição |
| Correr | Ciclo de 28 q na Arqueira, 32 q no Cavaleiro e na Maga e 34 q no Clérigo, com 2 q de voo por passo. O tronco inclina 10° |
| Correr com Carga | Ciclo de 36 q. O tronco inclina 18° para a frente. A mochila (4 tamanhos) quica com mola e atrasa 4 q |
| Idle | Respiração de 4 s: o peito sobe 2%, os ombros 1 cm. Um microgesto a cada 5 a 9 s: o Cavaleiro sopra o bigode e ajeita a crista; a Arqueira gira uma flecha e testa a corda; a Maga empurra os óculos e folheia o livro; o Clérigo sopra a chama da lanterna e conta as contas da barba. As piscadas ficam entre 2 e 6 s |
| Olhar | A cabeça segue o inimigo mais próximo até 60°, com 6 q de atraso |
| Pouso | Achata a 0,85 por 4 q, sobe pó e o joelho absorve 15° |
| Reação a dano | Leve: tremor e piscada. Médio: recua um passo. Pesado: cai sentado e levanta em 30 q |
| Morte e desbotar | A cor escorre da cabeça para os pés em 12 pinceladas em 40 q. A lanterna de cinto, o cristal ou o relicário apagam com um fio de fumaça |

O achatar e esticar sempre preserva o volume. Achata no pouso e no contato pesado, estica na antecipação do salto e no lançamento. O aço da espada, o escudo, o elmo, a maça e as placas nunca deformam; o arco só dobra pelos próprios ossos na puxada; quem deforma é o corpo e o pano.

### 7.6 Inimigos também têm peso e ritmo

- **Telegrafia:** um hold vivo de 24 a 36 q para comuns, com tremor de 1° a 2° a 10 Hz, o ponto de cor acendendo em magenta e o som no **último** quadro da espera.
- **Recuperação:** a punição longa (de 24 a 40 q) aparece no corpo: o Ouvidor fica com a cara no chão, o Pingente fica atordoado de asas abertas, o Guarda Engolido fica com a alabarda cravada e o peito aberto.
- **Ritmo por massa:** o Ouvidor e a Roicorda atacam em rajadas rápidas; o Bocalume e o Cultista são lentos e preparam o chão; o Guarda Engolido anda em passos plantados e pesados, como o Cavaleiro ao contrário.
- **Reação proporcional:** o mesmo pacote de impacto da seção 7.3, lido pelo peso do golpe recebido.

---

## 8. Inimigos

**Regra de leitura:**
- **criaturas de dark fantasy reconhecíveis à primeira vista**: carniçal, aranha, morcego, rato, zumbi de fungo, cultista, cavaleiro morto-vivo, estátua animada. Nada de bonecos-palito nem de criatura incompreensível;
- forma forte, desenhada pela silhueta vista de cima: membros grossos, massa nos ombros, peso no chão, postura de caça;
- corpo escuro (valor de 15 a 25%) com uma **aresta fria pintada** e contorno de casca;
- **um único ponto de cor** (olho, isca, boca, chama do elmo), que acende em **magenta** na telegrafia;
- o mesmo acabamento dos heróis: malha com deformação, textura pintada (osso, quitina, pele cinza, pano podre, ferro enferrujado, gesso) e shader por material;
- o **tamanho da base** diz o perigo (comum, elite, chefe).

**Família de formas:** o que nasce do abismo tem forma de **cogumelo, pata e quitina**; o que Thessimor construiu ou enterrou é **bloco chanfrado, placa e gesso**; o que caça do teto ou da água é **ponta**.

**Dark fantasy, mas legível:** ameaça por massa, postura e boca. Não há sangue: os inimigos se partem em gesso, osso, quitina, cinza e pó.

### 8.1 Andar 1: Mata de Lume

| Inimigo | Papel | Aparência (silhueta de cima e forma) | Ataque e telegrafia | Vida |
|---|---|---|---|---|
| **Ouvidor** (carniçal) | Comum, bando de 3 a 6 | **Um M agachado.** Carniçal de Thessimor: os súditos engolidos que viraram mortos-vivos cegos. Tem 1,0 m de pé, um palmo **mais alto que os heróis**. Corcunda, massa nos ombros, antebraços grossos com **garras de osso** que apoiam nos nós dos dedos, pele cinza-lívida esticada sobre costelas, mandíbula larga de dentes de agulha. Sem olhos: só as pálpebras fundidas. As **orelhas enormes de morcego** são rasgadas, com veias claras que **ficam translúcidas contra a luz quente**. Restos do tabardo de Thessimor (a chave engolida por um peixe) e um elo de corrente no tornozelo | **Pulo-mordida** de 5 m, 14 de dano. Telegrafia de 30 q: as orelhas se abrem (a silhueta passa de M a T), a boca se abre e acende magenta, e soa um estalo de língua no fim. Ouve passos (Carga = barulho) | 40 |
| **Bocalume** (aranha-isca) | Comum, suporte | **Um oito com lanterna.** Aranha cega do tamanho de um javali (1,6 m de envergadura), abdômen inchado de **placas de quitina sobrepostas**, pernas grossas cobertas de cerdas e quelíceras curvas. Do abdômen sai um fio de teia com uma **lanterna de guilda roubada**, que ela balança sobre a cabeça: a isca é **quente**, a mentira da luz amiga | **Cuspe de teia esporada** em cone de 5 m: 10 de dano, lentidão e chão esporado. Telegrafia de 36 q: o abdômen se contrai a 0,7, **a isca apaga** e as quelíceras se abrem acesas. Prepara o Fulgor para os jogadores | 90 |
| **Pingente** (morcego de pedra) | Comum, emboscada | **Uma estrela de asas.** Morcego gigante de 1,4 m de envergadura, que dorme no teto **enrolado nas próprias asas**, com crosta de calcário nas costas, e parece uma estalactite. Focinho de dentes para fora e orelhas em ponta | **Queda** de 30 de dano em 1,8 m. Telegrafia de 48 q: poeira cai num fio, um círculo magenta do tamanho real cresce no chão e um guincho sobe de tom. Fica 2 s atordoado de asas abertas. Depois voa, **apaga lanternas** e mergulha no herói com mais luz (12 de dano; telegrafia de 28 q: para no ar e as asas tremem) | 60, crosta −50% até um golpe pesado |
| **Roicorda** | Comum, praga e ladrão | **Uma cunha com rabo.** Rato sem pelo do tamanho de um cão, pele rosada-cinza enrugada, focinho longo, **dentes de roer laranja** (o ponto de cor) e cauda segmentada | Rói cordas, lanternas e o cabo da jaula; **rouba sacos** e foge. Mordida de 8. Telegrafia de 24 q: os dentes batem e acendem | 30 |
| **Brotado** (zumbi de fungo) | Comum, lento | **Um guarda-chuva em pé.** Explorador morto tomado por fungo, de 1,1 m, ombros caídos e braços pesados. A cabeça virou um **chapéu de cogumelo aberto**, com lamelas que brilham por baixo. Arrasta uma perna e a mochila podre | **Nuvem de esporos** ao ser atingido. **Abraço** de 18 de dano. Telegrafia de 34 q: as lamelas acendem magenta. Explode num Fulgor se for aceso | 110 |
| **Cultista da Boca** | Comum, conjurador | **Um triângulo com dentes.** Humano vivo de Pendura que adora a Goela, de 0,95 m: manto de lona encerada cor de piche, cordas de oferenda cruzadas no peito, **máscara feita da mandíbula de um Ouvidor** com um único olho pintado (o ponto de cor) e um turíbulo de Fundo. Anda em pares, atrás dos carniçais | **Chamado da Boca:** poça de Fundo de 2 m sob um herói (telegrafia de 40 q: a máscara acende, ele ergue o turíbulo e a reza sobe de tom). **Levantar:** a cada 12 s, ergue um Ouvidor caído com 50% de vida (telegrafia de 54 q, interrompida pelo Clarão). Foge quando fica sozinho | 55 |
| **Guarda Engolido** | Elite blindado | **Um bloco com escudo-torre.** Soldado da guarda de Thessimor, de 1,8 m, morto-vivo dentro de uma **armadura de placas completa**, enferrujada e incrustada de cracas de calcário. Elmo fechado em grade com uma **chama fria acesa por dentro** (o ponto de cor), escudo-torre com o brasão do reino, alabarda. Anda devagar, plantando cada passo | **Muralha:** avança com o escudo e é imune pela frente. **Alabardada** em arco de 3,5 m, 36 de dano (telegrafia de 44 q: a alabarda recua, a chama do elmo vira magenta e as placas rangem). **Pancada de escudo** com empurrão de 3 m (telegrafia de 40 q). **Ponto fraco:** as correias das costas; Estalo na armadura molhada (ou o Veio de Ferrugem) derruba a guarda dele por 3 s | 460 |
| **Afundado** | Elite (e guardião da Pilha) | **Um corcunda com picareta.** Tem 1,9 m. Explorador morto-vivo, cinza e sem cor, com a **mochila fundida às costas** como uma corcunda de saque. Lanterna de capacete, picareta, capa com nome bordado. Na Pilha, usa o rosto e o figurino do seu herói | **Picaretada** em linha de 3 m, 40 de dano (telegrafia de 42 q: a lanterna passa a magenta e a picareta sobe). **Giro da mochila** de 3,5 m, empurrão de 4 m (54 q). Deixa rastro de chão afundado. **Ponto fraco:** as correias pelas costas | 420 |
| **Chefe: a Isca-Mãe** | Chefe | Aranha-rainha cega de **12 m de envergadura**, enrolada num casulo de teia e fungos gigantes, com o abdômen coberto de filhotes. A isca, pendurada num fio grosso como corda de navio, é **a lanterna dourada da primeira expedição da Guilda do Prumo**, perdida há 200 anos | Ver 8.4 | 4.800 |

### 8.2 Andar 2: Thessimor Engolida

| Inimigo | Papel | Aparência | Ataque e telegrafia | Vida |
|---|---|---|---|---|
| **Soldado de Gesso** | Comum pesado | **Um obelisco com lança.** Estátua animada de soldado de 2,1 m, gesso rachado com o vazio escuro por dentro e um **olho de vela** aceso na rachadura do elmo. Anda pose a pose, como estátua (6 poses por segundo, em degrau) | **Estocada** de 4 m, 28 de dano. Telegrafia de 36 q: recua a lança, a vela acende magenta e o gesso range | 160 |
| **Sineiro Oco** | Comum, suporte | **Um sino sobre um manto.** Monge morto-vivo com um sino de bronze no lugar da cabeça e o badalo incandescente | **Dobre:** anel de som de 6 m, atordoa 0,8 s e **enfurece Ouvidores** em 15 m. Telegrafia de 40 q: o sino balança para trás e o badalo acende | 120 |
| **Cofreiro Mudo** | Comum, guarda | **Um retângulo com disco.** Guarda morto-vivo fundido à porta do cofre que vigiava, com uma corrente com cadeado-mangual. O buraco da fechadura brilha | **Mangual** em arco de 3 m, 24 de dano (telegrafia de 34 q: a corrente gira 2 vezes). Imune pela frente | 150 |
| **Golem de Escória** | Comum | **Uma gota pesada com braços.** Criatura de escória da Forja, de 1,3 m, que pinga metal e tem a boca em brasa | **Respingo** que deixa o chão em brasa. Telegrafia de 30 q: incha e a boca acende | 80 |
| **Enforcado** | Comum, emboscada | **Um círculo com fio**, visto de cima. Morto-vivo pendurado do teto por raízes, que desce em silêncio. Os olhos são o ponto de cor | **Laço:** puxa um herói 2 m para cima por 2 s (aliados cortam a raiz). Telegrafia de 44 q: a raiz estala e uma sombra magenta aparece no chão | 70 |
| **Roicorda**, **Ouvidor de Brasão** e **Cultista da Boca** | Comuns | Variantes do Andar 1. O Ouvidor de Brasão usa um elmo amassado e um escudo de tábua | — | 40 / 70 / 55 |
| **Cavaleiro Tombado** | Elite | Cavaleiro morto-vivo de armadura negra, montado num cavalo de gesso partido ao meio, que se arrasta pelas patas da frente. O elmo dele é o chapéu do Paladino | **Carga em linha** de 10 m (telegrafia de 50 q: raspa o casco 3 vezes) | 520 |
| **Chefe: o Rei Pendurado** | Chefe | O último rei de Thessimor, de 8 m, fundido ao trono e às correntes, **de cabeça para baixo** sobre o Salão do Trono. A Coroa balança presa por um fio de ouro derretido | Ver 8.4 | 6.000 |

### 8.3 Andar 3: o Mar Calado

| Inimigo | Papel | Aparência | Ataque e telegrafia | Vida |
|---|---|---|---|---|
| **Lavadeira Afogada** | Comum | **Uma meia-lua na água.** Morta-viva curvada, meio submersa, com braços longos e cabelo de alga | **Puxão** para a água (estado molhado e 12 de dano). Telegrafia de 32 q: os braços saem da água e as unhas acendem | 60 |
| **Lampreia de Cais** | Comum | **Um traço com boca.** Enguia de 4 m que salta de um lado do cais para o outro | **Salto** em linha de 6 m, 22 de dano. Telegrafia de 36 q: um anel de ondas magenta e a boca acesa sob a água | 70 |
| **Remador sem Barco** | Comum | **Um remo em pé.** Esqueleto de remador de guilda que **anda sobre o reflexo** da água, com o remo como arma | **Remada** em arco de 3 m (telegrafia de 34 q) | 90 |
| **Ouvidor do Lago** | Comum | Carniçal de orelhas coladas à cabeça, nadador | Pulo da água | 45 |
| **Coral de Afogados** | Comum, estático | **Um coral de cabeças fundidas** que canta | Deixa o chão afundado em 4 m e puxa devagar. Telegrafia: as bocas acendem em sequência | 200 |
| **Aranha-Pescadora** | Elite | Bocalume de 6 m que vive numa ilha e pesca com 3 iscas | Cuspe triplo | 700 |
| **Chefe: a Senhora das Âncoras** | Chefe | Figura de **20 m** feita das âncoras, correntes e cordas de todas as guildas perdidas. Ergue-se do lago e **puxa as cordas da Guilda do Prumo**: durante a luta, a rede de lanternas no horizonte pisca | Ver 8.4 | 7.500 |

### 8.4 Os chefes (um por andar)

**A Isca-Mãe (Andar 1, cerca de 3 min).** A arena é uma clareira de poças com 4 colônias de fungo, uma cortina de goteira e teia esticada entre as colônias.
- **Fase 1, a Luz Amiga:** a lanterna dourada atrai lentamente o herói que olhar para ela, com um puxão de 1,5 m/s. O grupo quebra o efeito com o Clarão (Sal + Brasa) na isca ou passando o Prumo pelo puxado.
- **Fase 2, Esporos:** ela cospe teia esporada em leque e solta filhotes. O grupo responde com Fulgor contra ela (Brasa na nuvem).
- **Fase 3, Alçapão:** ela se enterra e emerge sob as poças, com um círculo magenta de 60 q. A Corrente na poça onde ela vai emergir causa o dobro de dano.
- **Final:** o Prumo lançado na isca arrebenta o fio. A lanterna da primeira expedição vira uma relíquia de 30 kg.

**O Rei Pendurado (Andar 2, cerca de 4 min).** É o chefe da v1, comprimido em três fases:
- **Pêndulo:** dois jogadores giram os guinchos do mesmo lado para bater o rei na beirada (6 s vulnerável). Os Desbotados giram com força total.
- **Coroação:** ele cai e rasteja. As cisternas quebradas alagam o salão; Estalo na corrente molhada causa 80 de dano.
- **Queda:** o salão cai 20 m, em câmera lenta de 0,5× por 1 s. O fim é o Cortador: um no contrapeso, o outro na trava.
- A **Coroa** é a relíquia de 60 kg da campanha, e o Içamento a partir daqui é o mais difícil.

**A Senhora das Âncoras (Andar 3, cerca de 4 min).**
- **Cabo de guerra:** ela puxa a jaula da guilda pelo cabo, e dois jogadores no guincho seguram.
- **Correntes molhadas:** Corrente nas correntes que saem do lago (envisgar antes quem está na água).
- **Âncoras:** ela arremessa âncoras com marca magenta de 70 q. Quem cortar suas 4 cordas-mestras (com flechas carregadas, golpes pesados ou o Mangual do Prumo) a desmonta.

**O Fundo (Andar 4, final da campanha).** **A Língua**, chefe e lugar ao mesmo tempo, fica para depois da fatia vertical.

---

## 9. Câmera, co-op local e online

### 9.1 Como o mundo vertical deixou de brigar com a câmera

1. **Os trechos são bandejas.** Cada trecho tem um plano principal e no máximo 2 patamares de ±3 m, ligados por rampas ou escadas de pelo menos 3 m de largura. Não há teto sobre a área jogável (exceto nas masmorras de mesa).
2. **A verticalidade é vista, não jogada.** As bordas de vazio mostram o andar de baixo e o Poço do lado e embaixo da bandeja. O teto da caverna fica no horizonte, como telão, e a Coluna atravessa o quadro de cima.
3. **As transições entre andares são feitas pelo grupo junto, na jaula.** São 15 a 25 s jogáveis: a câmera abre e mostra o andar inteiro chegando, e todos estão no mesmo lugar ao sair.
4. **Masmorras de mesa** têm câmera própria, mais perto, e as paredes do lado da câmera somem por dissolução pontilhada a 6 m dos heróis.
5. **O Içamento** tem câmera presa à jaula, que é uma arena de 9 × 9 m.

### 9.2 Câmera

| Modo | Distância | Inclinação | Campo de visão | Uso |
|---|---|---|---|---|
| Combate, de 1 a 2 jogadores | 16 m | 46° | 28° | A câmera nova da v2; o herói ocupa de 10 a 15% da altura |
| Combate, de 3 a 4 jogadores espalhados | Até 22 m | 50° | 28° | Abre suavemente conforme o grupo se espalha |
| Exploração | 19 m | 30° | 30° | Os 25% de cima mostram o horizonte e os marcos |
| Masmorra de mesa | 13 m | 55° | 28° | Mais perto, paredes dissolvem |
| Içamento | 15 m | 42°, girando 20° em volta da jaula durante o lance | 30° | As paredes do Poço passam por fora |
| Chefe | De 20 a 26 m | 55° | 30° | Arena inteira |

**A câmera acompanha o golpe:** chute direcional no contato, zoom de 3 a 4% no finalizador, câmera lenta curta no golpe final e no ultimate. Nos finalizadores dos chefes, há um corte para um ângulo baixo de 1,5 s (só sem ninguém em perigo).

### 9.3 Co-op local na mesma tela (até 4)

- Uma câmera compartilhada que enquadra todos e **nunca divide a tela**.
- **Coleira:** 18 m de raio na horizontal com 2 jogadores, 24 m com 4. Quem passa disso encontra uma **parede macia**: o movimento perde força a partir de 85% do limite, e a câmera mostra uma seta na borda. **Não há teletransporte**, exceto ao cair no vazio (volta à beirada em 2 s com 15 de dano).
- Saídas de trecho e portas de masmorra pedem a maioria do grupo perto. Quem fica para trás é puxado depois de 3 s com uma corda da guilda (animação de 0,6 s).
- Os anéis da base e as setas na cor do jogador são desenhados **por cima de todos os efeitos**. Herói atrás de obstáculo aparece como silhueta chapada na cor dele.
- O co-op local usa um roteador de dispositivos para separar teclado e controles.

### 9.4 Online (opcional, de 2 a 4)

- **Entrada:** a qualquer momento, no próximo Patamar ou Içamento.
- **Autoridade:** o anfitrião decide inimigos, dano, saque, sorteio da geração (a semente do andar é enviada uma vez), estado do chão, máquinas e âncoras. Cada cliente é dono do próprio movimento.
- **Separação:** cada jogador tem a própria câmera e pode se separar pelo andar inteiro, mas transições de andar e o Içamento pedem todos na jaula.
- **Misto:** dois jogadores locais num PC entram online com mais dois.
- As máquinas funcionam por posição e segurar, e as janelas de recepção do Lance são verificadas no cliente que pega, com compensação de até 150 ms.

### 9.5 Controles

**PC, teclado e mouse:**

| Ação | Tecla |
|---|---|
| Mover / mirar | W A S D / mouse |
| Ataque e combo (segurar carrega na Arqueira e na Maga) | Botão esquerdo |
| Habilidade 1 / 2 / especial (o Cavaleiro bloqueia segurando a Habilidade 1) | Botão direito / Q / R |
| Esquiva | Espaço |
| Interagir, pegar, segurar máquina, reviver, repintar, acender âncora | E (segurar) |
| Lance (para o aliado mais perto da mira) | F durante o golpe |
| Caminhar em silêncio | Shift |
| Ping | Botão do meio |
| Mapa do Escriba | Tab |

**PC, controle:**

| Ação | Botão |
|---|---|
| Mover / mirar | Analógico esquerdo / direito (mira automática leve quando o direito está solto) |
| Ataque | RT |
| Habilidade 1 / 2 | RB / LB |
| Especial | RB + LB |
| Esquiva | A |
| Interagir | X |
| Lance | B durante o golpe |
| Caminhar em silêncio | LT |
| Ping | Direcional para cima |
| Mapa | Select |

**iPhone (toque, paisagem).** No celular a prévia é **1 jogador com ajudante** ou **online**.
- **Esquerda:** direcional dinâmico.
- **Direita:** botão de ataque de 110 px. Tocar ataca com mira automática; segurar carrega; arrastar e soltar mira.
- **Em arco em volta do ataque:** Habilidade 1, Habilidade 2 e Especial. A esquiva tem botão próprio, maior.
- **Botão contextual** no alto do arco: Pegar (pulsa na cor de quem lançou, janela de 0,35 s), Lançar, Segurar, Repintar, Acender.
- **Ping:** toque duplo no chão.
- **Caminhar em silêncio:** inclinar o direcional até a metade.
- **Combo no toque:** o buffer de comando sobe de 10 para 14 q.

---

## 10. Luz, cenário e atmosfera ("tudo bem iluminado e animado")

### 10.1 Luz como protagonista

| Camada | Como é | [PC] | [iPhone] |
|---|---|---|---|
| **Luz-chave fria de cima** | `#9FB4D0`, entra pelos rasgos do teto e pela boca da Goela | Direcional com sombra suave | Direcional sem sombra; luz zenital pintada no material |
| **Poças de luz quente** | Lanternas e postes da guilda, âncoras acesas, a jaula | Uma `OmniLight3D` por poste próximo (até 40), sombra nas 2 mais perto | Poças pintadas no chão em 3 degraus de pincel, por uniformes globais (`lq0` a `lq9`, como na v2) |
| **Luz própria dos heróis** | A lanterna de cinto de cada herói ilumina o próprio rosto e 2 m em volta; o cristal do cajado da Maga, 5 m (âmbar, ciano na carga); a lanterna-relicário do Clérigo, 4 m, que balança com a maça e se ergue na Bênção; a Lâmina Acesa do Cavaleiro; a ponta de resina das flechas da Arqueira, fraca | 4 luzes de herói com sombra | 4 omnis sem sombra, só perto da ação |
| **Luz de borda na cor do jogador** | Contorno de luz de 1 a 2 px na cor do jogador, mais forte no escuro | Shader | Shader (igual) |
| **Luz dos efeitos** | A Corrente acende a caverna em azul por 0,4 s; o Fulgor em branco-dourado; o Clarão e a Bênção em branco-quente; o Piche em laranja | Luz real de curta duração | Até 3 ao mesmo tempo, e as mais fracas cedem |
| **Fungos bioluminescentes** | Ciano dessaturado (até 56%), pulsam devagar (de 3 a 5 s), acendem em onda na Expira | Emissão + luz rebatida (SDFGI) | Emissão + poça pintada |
| **Raios de luz (god rays)** | Atravessam as cortinas de goteira e a Coluna do Meio-Dia | Névoa volumétrica (`FogVolume`) | Cartões aditivos desenhados, com poeira em partículas de CPU |
| **Glow** | Controlado: limiar alto, só em emissivos, nunca nos heróis | Glow do `Environment` | Desligado; halo pintado no cartão |

**Regras de luz:**
- **Quente é gente, frio é abismo.** Toda luz carregada pela guilda é quente; o mundo de baixo é frio. A chama fria no elmo do Guarda Engolido é a exceção que assusta.
- **O magenta nunca ilumina o cenário.** Ele só aparece em telegrafia e em reação que fere.
- **O herói tem valor mínimo de 35%** mesmo com a luz real desligada.

### 10.2 Cenário: o que fica e o que melhora

**Fica (do que o usuário gostou na v2):**
- as cascatas e as 4 cortinas de goteira com fio de luz fria;
- as colônias de fungo com hierarquia e com estados inteiro, rasgado e podre;
- os postes de lanterna da guilda ao longo das trilhas;
- a ruína de Thessimor (piso em grade antiga, lajes chanfradas, tocos de coluna octogonal, poço de desabamento);
- a ponte de tronco de fungo e o guincho da guilda na beira do vazio;
- no horizonte, a Coluna do Meio-Dia, o Dente e a Pendura de Baixo;
- a névoa cel subindo do abismo, a luz fria de cima e as poças de luz quente;
- o chão com causa (regos de água por acúmulo de fluxo, musgo no úmido, trilhas de terra batida).

**Melhora (o que estava cru):**
- **Rochas:** deixam de ser chapadas. Ganham **estratos de sedimento** em camadas inclinadas com chanfro, quinas lascadas, fendas com sombra pintada, **musgo só nos topos e nas faces viradas para a umidade**, escorrido escuro de água abaixo das goteiras, depósito de cal branca nas bordas onde a água seca, e 3 degraus de pincel seco por curvatura.
- **Chão:** lajes com desgaste nas bordas e no centro das trilhas, sujeira acumulada nos cantos, raízes cruzando, cascalho solto que **pula no impacto**, poças com borda de lodo e reflexo.
- **Fungos:** lamelas visíveis por baixo, véu e anel na haste, escamas no chapéu, esporos saindo das lamelas na Expira.
- **Postes da guilda:** madeira com placa de cobre da guilda, corda enrolada, lanterna de ferro com vidro sujo e mariposas pequenas.
- **Teias:** fios de teia entre colônias e postes, que brilham na luz de borda e vibram quando algo encosta (mostram que há Bocalumes por perto).

### 10.3 Nada fica parado em cena

| Elemento | Movimento |
|---|---|
| Heróis | Respiração, microgestos, piscadas, olhar que segue inimigos, adereços em mola (crista, capa, ponta do chapéu, trança, barba, lanterna-relicário), chama da lanterna de cinto |
| Inimigos | Respiram: orelhas do Ouvidor que tremem, abdômen do Bocalume que pulsa e isca que balança, asas do Pingente que se ajeitam no teto, turíbulo do Cultista que fumega, chama fria do Guarda Engolido que tremula, sino do Sineiro balançando, gesso soltando pó |
| Fungos | Pulsam (de 3 a 5 s), abrem e fecham com a Respiração, soltam esporos |
| Água | Cascatas correndo (rolagem de UV com 3 camadas), goteiras com respingos e anéis nas poças, regos com fluxo |
| Lanternas | A chama treme a 6 a 9 Hz, a lanterna balança com o vento da Respiração e **com o choque dos golpes próximos** |
| Névoa | 3 lâminas que sobem na Expira e se desmancham na Inspira; névoa saindo do Poço |
| Partículas | Esporos flutuando, poeira na Coluna, pó caindo do teto com golpes pesados, mariposas nas lanternas |
| Corda, teia e pano | Vento na corda da jaula, nos fios de lanterna, nas teias, nas capas e nos estandartes |

### 10.4 O mundo reage ao golpe (juice no cenário)

| Gatilho | Reação |
|---|---|
| Herói passa | Cogumelos pequenos e grama se curvam (deslocamento de vértice por posição dos heróis, 8 posições) e voltam com mola em 0,6 s; esporos soltam do chapéu tocado |
| Golpe pesado a até 6 m | Cogumelos achatam (0,85) e voltam; lanternas balançam até 15°; pó cai do teto; cascalho pula |
| Pisar ou cair em poça | Respingo em coroa de 6 a 10 gotas, anel que se espalha, o herói fica molhado (escurece 10%) |
| Aterrissar | Pó sobe em anel achatado, proporcional à altura |
| Corrente na poça | A água acende, os fungos próximos piscam, as gotas no ar viram faíscas por 4 q |
| Corda sob tensão (guincho, flecha de corda, jaula) | Vibra em onda que corre pela corda e estala lateralmente (verlet de 16 pontos, catenária real, como na v2) |
| Flecha que erra | Crava na rocha ou no fungo e fica vibrando 12 q; no fungo, solta esporos |
| Reação grande | Lanternas de toda a tela tremem; o teto solta cascalho em áreas marcadas |
| Âncora acesa | A luz corre pela corda lanterna a lanterna, e os fungos em volta respondem com brilho |

---

## 11. Efeitos: linguagem e acabamento

**Linguagem única: "talhado e pintado".**
- Formas **desenhadas e recortadas**, nunca ruído genérico nem discos brancos.
- 2 ou 3 tons chapados, com **beirada mais escura do próprio tom**, do mesmo jeito que a casca dos personagens.
- O núcleo é claro, mas nunca branco puro.

**Timing:** ataque rápido (o efeito chega ao tamanho máximo em 2 a 4 q, sempre no quadro de contato) e decaimento lento (de 12 a 40 q, encolhendo e perdendo contraste).

**Camadas de cada efeito:**
1. **Núcleo:** a forma principal (raio, onda, clarão);
2. **Corpo:** a massa ao redor (nuvem, poça, chama);
3. **Partículas secundárias:** faíscas, gotas, lascas, esporos, cristais de sal;
4. **Rastros:** smear da arma, rastro das faíscas e das flechas;
5. **Luz que ilumina o entorno** ([PC] luz real; [iPhone] poça pintada);
6. **[PC] Distorção:** onda de calor no Piche e anel de choque no finalizador.

**Exemplos:**
- **Corrente:** linhas elétricas desenhadas em 3 passadas (beirada escura, corpo ciano, miolo claro) que correm pela poça em 6 q e ramificam; anel de vapor; gotas que viram faíscas; a caverna pisca em azul.
- **Visgo:** gota âmbar translúcida com fios que esticam e estalam; o aliado envisgado ganha um **halo âmbar** que contorna a eletricidade (separa o aliado do perigo).
- **Fulgor:** bolha de poeira que acende de dentro para fora em 3 anéis, com fagulhas douradas e fumaça fria residual.
- **Lâmina Acesa:** chama laranja desenhada em 3 línguas que lambem a lâmina para trás no movimento, fagulhas que caem e um smear quente com beirada vermelho-escura.
- **Bênção e Clarão:** anel de luz branco-quente com raios recortados do Sol-Prumo; cristais de sal que caem como neve curta e ficam brilhando no chão.
- **Flechas:** rastro fino da cor da ponta (cinza, azul-cinza ou âmbar), penas que deixam 2 q de smear; a bexiga d'água estoura numa coroa de gotas.
- **Smears:** leque de malha na cor da arma com beirada escura, de 4 a 8 q, curvado no arco do golpe.

**Legibilidade:** o anel e a seta do jogador ficam por cima de todo efeito. Nenhum efeito do jogador usa magenta. O efeito nunca cobre o herói que o lançou por mais de 6 q.

---

## 12. Fatia vertical: "A Primeira Descida" (um andar jogável)

**Conteúdo:** 1 andar (Mata de Lume) completo, com 1 a 4 jogadores, de 14 a 19 min por corrida, e a Sede mínima.

1. **A Sede**, com a Mesa, o Quadro de Contratos (3 contratos), o Cabideiro (4 classes), a Sala das Relíquias (3 prateleiras) e a Varanda do Escriba (lê o Veio).
2. **Descida da jaula**, com uma onda de Pingentes. Ensina a telegrafia e o primeiro Lance do Prumo, num momento seguro.
3. **A espinha da Mata de Lume** com a Coluna, a Cascata, o Dente, a Pendura de Baixo, 4 cortinas de goteira e **6 âncoras**.
4. **O miolo:** um kit de **12 trechos** com 4 estados e 3 telões. A geração monta de 7 a 9 nós por corrida, com 2 rotas, 1 Capela, 1 Penhorista, 1 evento (entre 6) e 1 masmorra de mesa de 3 salas (o "Cofre do Peixe").
5. **O chefe:** a Isca-Mãe.
6. **O Içamento:** 1 lance de 60 a 90 s, com perseguição pela Carga, lastrar, manivela em dupla e freio.
7. **De volta à Mesa:** as âncoras acesas aparecem como fios, e uma Pilha do Afundado aparece se o grupo tiver morrido.

**Elenco e sistemas:**
- **4 classes completas: Cavaleiro, Arqueira, Maga e Clérigo**, com os 3 golpes do combo, 2 habilidades, especial e recepção do Prumo. As fichas de timing e as tiras de poses da seção 7 são implementadas e medidas.
- **Inimigos:** Ouvidor, Bocalume, Pingente, Roicorda, Brotado e Cultista da Boca, mais o Guarda Engolido e o Afundado como elites e a Isca-Mãe como chefe.
- **6 reações:** Água Benta, Corrente, Fulgor, Âmbar, Clarão e Floração.
- **Poder por corrida:** 12 Penduricalhos, 3 Graças (uma por Padroeiro) e 3 Veios (Cobre, Esporada, Resina Doce).

**Metas de aprovação:**
- **Ataques:** em captura a 60 q por segundo, o quadro de contato de cada golpe tem hitbox, hit-stop, flash, faísca, chute e som **no mesmo quadro** (verificado por log de eventos com número de quadro). Os pés de apoio não deslizam mais de 1 cm do plantar até o fim do contato. Os intervalos entre contatos batem com as fichas com tolerância de ±1 q.
- **Juice:** cada evento da tabela 7.3 e da tabela 10.4 aparece num clipe de teste.
- **Nada parado:** numa captura de 10 s de idle, todos os elementos da tabela 10.3 se movem.
- **Luz:** a captura com luz real desligada mantém os heróis com valor mínimo de 35%; a diferença Forward+ contra Compatibility fica abaixo de 6/255 (a v2 mediu 4,8 **[medido]**).
- **Legibilidade:** silhueta preta dos 4 heróis na câmera de jogo distinta (D com crista, arco atravessado com leque, vírgula com estrela, haltere). A v2 falhou com 2 de 4.
- **Personagens:** folha de deformação sem quebra nem interseção; close de rosto e busto na luz da caverna comparado com a versão anterior; cada herói com as 4 cores de jogador, e uma dupla da mesma classe, continua estiloso e distinguível; reconhecimento do arquétipo em 1 s por 5 pessoas sem explicação.
- **Inimigos:** cada inimigo é nomeado pelo tipo ("carniçal", "aranha", "morcego", "cultista", "cavaleiro morto-vivo") por 5 pessoas que veem só a folha de modelo em cinza.
- **Portões de imagem:** cinza, borrão, miniatura 320 × 180, deuteranopia e protanopia (agora com o padrão de pano), e estresse com 4 heróis, 20 inimigos e 6 efeitos.
- **PC:** 60 q por segundo em 1080p, com 2 jogadores locais e 2 online ao mesmo tempo.
- **iPhone:** abre no Safari, roda a 30 q por segundo com 1 jogador e ajudante, download de até 40 MB, e volta da perda de contexto WebGL no último Patamar sem perder a Carga.
- **Geração:** 500 sementes sem andar impossível (portão de conectividade), menos de 10% de caminhos com trecho repetido e geração em menos de 60 ms.
- **Teste com pessoas:** 5 duplas sem instrução. Pelo menos 3 descobrem o Visgo isolante sozinhas (a flecha de resina na Maga), pelo menos 3 em 5 escolhem lastrar no Içamento pelo menos uma vez, e ninguém abandona durante o Içamento.

---

## 13. Riscos

| Risco | Por que é real | Mitigação |
|---|---|---|
| **Os trechos se repetem e o andar parece pequeno** | 12 a 16 trechos por andar é pouco para dezenas de corridas | Tupla conjunta anti-repetição, 4 estados e 3 telões por trecho, eventos e Veios que mudam a química. Medir a repetição percebida com uma folha de contato a cada novo kit |
| **O "mundo aberto" se perder no roguelite** | Grafo de salas tende a parecer corredor | Bordas abertas com vista para os trechos vizinhos, rotas paralelas, espinha com marcos fixos no horizonte e a rede de lanternas persistente |
| **O Içamento ficar repetitivo** | É o fim de toda corrida | Perseguição pela Carga, patamar intermediário com prêmio, decisões de lastrar, inimigos que roubam sacos e o horizonte que muda com a rede. Medir o abandono |
| **Arquétipos clássicos parecerem genéricos** | Cavaleiro, arqueira, maga e clérigo existem em todo jogo | A originalidade está na estilização: proporção de 2,25 cabeças, rosto talhado, silhueta de cima, figurino com paleta própria, 3 ganchos com história por herói e detalhes de guilda do abismo. Folha de modelo revista ao lado de heróis de jogos do gênero, procurando o que só existe aqui |
| **Acabamento voltar a parecer "boneco de peças"** | O pipeline antigo montava peças rígidas por osso | Malha contínua com pesos suaves, ossos de ajuste, blend shapes corretivas e folha de deformação como portão obrigatório (seção 6.2) |
| **A cor do jogador apagar o figurino, ou o figurino apagar o jogador** | Cor forte no corpo inteiro deixava todos parecidos; sem cor, o co-op confunde | Acento de 5 a 8%, luz de borda, anel com forma e padrão de pano; teste com as 4 cores e com dupla da mesma classe |
| **Animação de ataque cara** | 4 classes × 3 golpes × fichas precisas, mais inimigos com telegrafia viva | Fichas como dados (o Blender exporta marcadores de contato e janela; o Godot lê). Um pacote de impacto único para todo golpe. Medição automática de quadro de contato e deslize de pé |
| **Hit-stop e câmera lenta em co-op** | Congelar a tela prejudica 3 para premiar 1 | Hit-stop local por entidade. Câmera lenta global só em morte de elite, finalizador da recepção e chefe |
| **Muita luz e juice viram ruído** | Juice demais apaga a leitura | Hierarquia: o anel do jogador e a telegrafia magenta ficam sempre por cima; o tremor da câmera é reduzido a 60% em co-op; o glow só nos emissivos; portões de imagem em todo build |
| **Silhuetas voltarem a virar discos** | Aconteceu na v2 com 2 de 4 heróis; o chapéu largo da Maga é o maior risco | Desenhar pela silhueta vista de cima primeiro (ponta torta do chapéu e cajado com cristal à frente); teste de silhueta preta como portão obrigatório |
| **Inimigos "fofos", genéricos ou incompreensíveis** | Aconteceu nos três conceitos | Criaturas reconhecíveis (carniçal, aranha, morcego, cultista, morto-vivo blindado) com massa, boca e postura; um ponto de cor; nada de olhos redondos brancos; folha de modelo revista em cinza |
| **iPhone: memória e perda de contexto** | iOS derruba abas pesadas | Trechos de até cerca de 35 nós (0,65 ms para instanciar **[medido]**), só 3 trechos carregados por vez, salvamento em todo Patamar e âncora |
| **Escopo dos 4 andares e das 9 classes** | Muito conteúdo para uma equipe pequena | A fatia é 1 andar. O lançamento pode ser 3 andares e 6 classes; o Fundo e 3 classes podem vir depois |
| **Nome** | A busca de 27/11/2026 não achou jogo, mas isso não é checagem de marca | Checagem formal antes de anúncio. Alternativa reserva: "Plumbline Guild" |

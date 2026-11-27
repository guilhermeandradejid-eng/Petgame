# Desmontagem de design dos jogos de referência (RPG de ação cooperativo)

Pesquisa feita em 26/11/2026. Etapa de pesquisa: nada aqui é decisão de projeto, é matéria-prima para as ideias.

## 0. Como ler este relatório (método e limites)

- **Fontes.** Cerca de 75 buscas na web (inglês e português). Nesta sessão a leitura direta de páginas ficou bloqueada (gamedeveloper.com, en.wikipedia.org e co-optimus.com não resolvem; para ler os artigos na íntegra, esses domínios precisam ser liberados na rede da sessão). Por isso **as fontes foram lidas pelos resumos e trechos devolvidos pelo buscador**, não pela página inteira. As URLs estão na seção 11, por código (ex.: `[M4]`).
- **Marcação.** Afirmação com código de fonte = saiu de um trecho da fonte. **(nv)** = *não verificado nesta pesquisa*: é conhecimento geral do gênero, vale conferir antes de tratar como fato. Opinião minha está escrita como opinião ("avaliação", "leitura", "hipótese").
- **Datas.** Vários jogos mudaram depois do lançamento (acesso antecipado, patches). Sempre que a fonte é da época do lançamento, isso está dito.
- **Teste prático.** Um cálculo rápido de tamanho de espaço de combinações (seção 7, mecânica 2), em `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-jogos-referencia/combos.py`.

## 1. Resumo executivo

1. **O que vende Magicka não é a magia, é a consequência social da magia.** O sistema de 8 elementos gera centenas de feitiços, mas o que os críticos lembram é matar o amigo sem querer e reviver em um segundo. Reviver barato é o que transforma fogo amigo em piada e não em frustração [M2e][M2a]. Sem reviver (jogo solo), a mesma mecânica vira "game killer" [M2d].
2. **O que vende Lost Castle é a variedade de arma por partida** ("as armas moldam o estilo de jogo inteiro da run") [LC8], em cima de um beat 'em up acessível com cara de desenho animado. As reclamações são de infraestrutura (netcode, reconexão, desempenho) e dificuldade irregular [LC12][LC9].
3. **Quase todo roguelite co-op recente é "single-player vezes N".** Sworn, Wizard of Legend 2, Risk of Rain 2 e Ravenswatch recebem a mesma crítica: sem saque instanciado, escalonamento torto por número de jogadores, solo sem graça ou injusto [X6][W5][RR4][R9]. Jogos desenhados para interdependência desde o início (It Takes Two, Overcooked, Deep Rock Galactic) são os mais elogiados e os que mais vendem [IT1][O1][X14].
4. **Interdependência por trava dura fracassa; por incentivo, funciona.** Full Metal Furies obrigava a classe certa a quebrar o escudo da cor certa: nota 85 no PC e fracasso comercial ("a pretty massive failure") [F6][F2]. Deep Rock Galactic faz as ferramentas de cada classe *ajudarem* as outras sem bloquear ninguém [X14].
5. **Legibilidade com 4 jogadores é a reclamação mais repetida do gênero**: Castle Crashers ("caótico demais") [CC2], Dragon's Crown ("perco completamente meu personagem") [X10], Rotwood ("fogos de artifício constantes") [X4], Wizard of Legend 2 ("cenas poluídas que escondem a ação") [W5], e até Hades II jogando sozinho [HA6][HA7].
6. **Jogador morto ocioso continua mal resolvido.** As melhores soluções: reviver instantâneo por habilidade (Magicka), reserva de vidas do grupo (Ravenswatch, Gauntlet), fantasma que ajuda (Rampage Knights), sobrevivente que "paga" o retorno matando inimigos (Wizard of Legend, Gauntlet). As piores: esperar a próxima fase (Risk of Rain 2) e punir o time inteiro (morte súbita do Windblown, que gerou revolta) [RR2][WB1].
7. **Solo é o calcanhar de Aquiles**: Magicka 2 ("mal passável") [M2c], Nine Parchments ("arrastado") [NP1], Ravenswatch e Nightreign (tiveram de ser reequilibrados depois) [R1][X9]. Quem resolveu bem: Full Metal Furies (controlar 2 personagens com troca rápida) [F1] e Nightreign pós-patch (reviver automático uma vez por chefe) [X9].
8. **Identidade visual vale mais que fidelidade.** Wizard of Legend trocou pixel art por 3D e ouviu "agora é só um estilo genérico" (Steam "Mixed") [W9][W6]. Hades usa 3D pré-renderizado em sprites 2D com traço pintado à mão por cima (942.489 quadros de animação) [HA1][HA5]; Dead Cells usa 3D simples convertido em pixel art [DC1]. Ambos são caminhos viáveis para um pipeline 100% por script.
9. **A linhagem Magicka está parada.** Não achei sucessor anunciado para 2025–2026; o Magicka original "só continua jogável graças a um fã" [M9]. O parente mais próximo recente é The Spell Brigade, um survivors-like com fogo amigo (OpenCritic 70) [X16]. Há espaço para "magia sistêmica entre jogadores" feita de outro jeito.
10. **Recomendação central desta pesquisa:** o núcleo do jogo deve ser a *reação entre as ações de jogadores diferentes* (eu preparo, você detona), com poucos elementos e matriz pequena e legível; morte barata e ativa; fogo amigo cômico e regulável; solo com companheiro desde o protótipo; sessões de 12 a 20 minutos; regras de legibilidade como parte da direção de arte.

## 2. Tabela comparativa

Legenda: **comp.** = tela compartilhada; **indiv.** = cada jogador com a sua câmera; **AA** = acesso antecipado; **n/a** = não se aplica. Rótulos de avaliação do Steam aparecem em inglês entre aspas quando a tradução poderia confundir.

| Jogo (ano) | Jogadores | Câmera | Fogo amigo | Queda / reviver | Progressão | Sessão | Arte |
|---|---|---|---|---|---|---|---|
| Magicka (2011) | 1–4 local/online [M8] | comp. [M11] | sempre ligado [M7] | Magick de reviver instantâneo, qualquer um lança [M7] | campanha linear; itens achados; sem atributos (nv) | capítulos 30–45 min (nv) | 3D estilizado simples, paródia |
| Magicka 2 (2015) | 1–4, entrada a quente [M2l] | comp. [M11] | sempre ligado [M2c] | idem; solo sem reviver [M2d] | 9 capítulos; artefatos (modificadores) [M2h][M2i] | ~30 min por capítulo [M2i] | 3D estilizado, mais polido |
| Lost Castle (2016) | 1–4 local/online [LC2] | comp. lateral | não (nv) | aliado revive (nv) | roguelite: morrer libera upgrades; 190+ armas, 60+ armaduras [LC1] | run 30–60 min (nv) | 2D cartoon desenhado |
| Lost Castle 2 (AA 2024, 1.0 jun/2026) | 1–4 online; local veio depois [LC10] | comp. lateral | não (nv) | reviver a alma do aliado com ponto ideal de tempo dá mais vida [LC16] | ~200 armas, encantamentos, Pesadelo 1–5 [LC18][LC11] | (nv) | 2D cartoon |
| Nine Parchments (2017) | 1–4 local/online [NP8] | comp. (nv) | incentivado; há modo/ajuste [NP2][NP8] | aliado revive (nv) | 32 fases; personagens por cajados; 9 feitiços [NP2][NP7][NP5] | campanha 8–10 h (nv) | 3D pictórico (universo Trine) |
| Wizard of Legend (2018) | 1–2 local, sem online [W3] | comp. | não (nv) | parceiro volta se o vivo derrotar inimigos [W4] | arcana + relíquias por run | run 20–40 min (nv) | pixel art |
| Wizard of Legend 2 (1.0 jun/2025) | 1–4 online/local [W7] | (nv) | (nv) | (nv) | saque não instanciado [W5] | (nv) | 3D cel-shaded |
| Ravenswatch (1.0 set/2024) | 1–4 só online [R7] | indiv. (nv) | não (nv) | Penas do Corvo: reserva dividida pelo grupo [R1] | talentos na run; 9→12 heróis [R4][R5] | ~1h15 a run [R5] | 3D com traço de HQ |
| Children of Morta (2019) | 1–2 [C6] | comp. | não | reviver parceiro [C6] | árvore por personagem + bônus de família; fadiga [C5] | incursão 20–40 min (nv) | pixel art pintado + luz dinâmica [C1] |
| Castle Crashers (2008) | 1–4 entra-e-sai [CC1] | comp. com parede invisível [CC6] | só na arena pós-chefe [CC4] | reanimação por aliado [CC3] | XP → atributos; armas; mascotes (nv) | fases 5–10 min (nv) | 2D cartoon vetorial |
| Full Metal Furies (2018) | 1–4 [F1] | comp. (nv) | não | aliado revive; tanque protege [F4] | 4 classes fixas, árvore, enigmas ocultos [F3][F5] | fases curtas (nv) | pixel art |
| Gauntlet (2014) | 1–4 | comp. (nv) | não; disputa por ouro e coroa [G5] | Skull Coins: vidas compartilhadas [G5] | relíquias, maestrias por ação, ouro [G5][G6] | média 4 h no total [G7] | 3D escuro |
| Heroes of Hammerwatch (2018) / II (2025) | 1–4 online [H1][H5] | indiv. (nv) | não | (nv) | cidade com 10 prédios; NG+ [H1][H2] | campanha 19,5 h [H7] | pixel art miúdo |
| Windblown (AA out/2024) | 1–3 só online [WB7] | indiv. | não | reviver + "morte súbita" [WB1] | saque compartilhado [WB2] | (nv) | 3D low-poly cel-shaded |
| Risk of Rain 2 (2019–20) | 1–4 online | 3ª pessoa | não (nv) | morto só volta na fase seguinte [RR2] | itens empilháveis; dificuldade sobe com o tempo [RR1] | 30–90 min (nv) | 3D low-poly |
| Helldivers (2015) / 2 (2024) | 1–4 | H1 comp. até online [HD5]; H2 3ª pessoa | sempre ligado, "é a lei" [HD3] | "Reforçar": chamar o morto de volta (nv) | desbloqueio de estratagemas | missões 10–40 min (nv) | H1 vista de cima; H2 realista |
| It Takes Two (2021) / Split Fiction (2025) | exatamente 2 [IT1] | tela dividida | n/a | retorno imediato (nv) | nenhuma: mecânica nova a cada fase (nv) | campanha 12–14 h (nv) | 3D AAA estilizado |
| Overcooked (2016) / 2 (2018) | 1–4 | tela única fixa | n/a | n/a | estrelas por fase | fases 3–4 min (nv) | 3D low-poly fofo |
| Hades (2020) / Hades II (1.0 set/2025) | 1 | indiv. | n/a | n/a | bênçãos por run + meta | run 20–45 min (nv) | 3D pré-renderizado em sprite 2D [HA3] |

## 3. Fichas dos jogos

### 3.1 Magicka (Arrowhead / Paradox, 2011)

- **Loop.** Campanha linear de fantasia paródica; combate é conjurar. 8 elementos nas teclas QWER/ASDF, fila de até 5, modos de conjurar (à frente, em área, em si mesmo, na arma) [M8]. Elementos opostos se anulam; água+fogo vira vapor e água+frio vira gelo (10 elementos lançáveis) [M7]. A combinação define força, alcance e duração [M7]. Fórmulas especiais ("Magicks": reviver, pressa, teleporte etc.) são sequências decoradas (nv).
- **Co-op.** Até 4, local ou rede, câmera única [M8][M11]. Fogo amigo nunca desliga [M7]. Qualquer sobrevivente invoca o morto de volta [M7]. No postmortem, a equipe conta que conselheiros experientes pediram para tirar o fogo amigo e que recusar foi proteger "a visão" do jogo [M1].
- **Números.** 30 mil cópias em 24 h [M6]; 1,3 milhão em um ano mais 4 milhões de pacotes de DLC [M4]; 1,8 milhão em dois anos [M5]. Equipe de estudantes; o trabalho foi subestimado em 700% segundo relato posterior [M10]; a campanha deu "sensação de que nunca terminaríamos" e a lição "se uma campanha já é difícil, nunca faça duas" [M1].
- **Elogios.** Humor, experimentação, caos entre amigos [M4][M7].
- **Críticas.** Lançamento quebrado ("não sabíamos que o jogo estava sendo lançado") [M3]; online "abismal" no começo, local funcionava [M2]; hoje depende de correção feita por fã [M9].
- **Arte e animação.** 3D simples; personagens encapuzados sem rosto (barato de animar, legível, vira ícone). Leitura minha: o capuz é uma solução de produção disfarçada de estilo, exatamente o tipo de decisão que este projeto precisa.
- **Lição.** Regras físicas consistentes e poucas (molhado conduz raio, fogo seca, frio congela molhado) geram comédia sem roteiro. O custo é uma interface de 8 teclas e centenas de combinações.

### 3.2 Magicka 2 (Pieces Interactive / Paradox, 2015)

- **Loop.** O mesmo, com 4 Magicks em atalhos de um botão [M2i], campanha de 9 capítulos de ~30 min [M2i], "artefatos" que ligam modificadores de regra para rejogar [M2h], entrada a quente e checkpoints [M2l].
- **Elogios.** "A melhor implementação da mecânica de combinar magias" (GameGrin, via busca); "a aventura co-op que você esperava", nota 79 [M2a]; fogo amigo "hilário" [M2e].
- **Críticas.** "Só uma reprise", 5,5/10 [M2b]; "não tão diferente do primeiro" [M2d]; ondas e ondas de inimigos idênticos, lógica elemental em conflito com o resto do jogo [M2c]; solo "mal passável" e sem reviver [M2c][M2d]; "difícil controlar um mago" no controle [M2g]; curto, e o caos que diverte também cansa [M2j]; qualquer jogador pula a cena para todos [M2f].
- **Lição.** O sistema de magia sozinho não segura uma sequência. Faltaram inimigos e fases que *pedissem* combinações diferentes. O teto de conteúdo é o design de encontros, não o número de feitiços.

### 3.3 Lost Castle (Hunter Studio, 2016)

- **Loop.** Beat 'em up lateral com profundidade, salas aleatórias, arma sorteada no início (cada tipo de arma tem golpes próprios) (nv). Morrer libera itens e upgrades permanentes para o próximo caçador [LC1].
- **Co-op.** Até 4, local e online [LC2]. Itens são do primeiro que pegar [LC3]. "Ótima experiência de festa" [LC3].
- **Números.** Steam "Very Positive", ~18 mil análises [LC1]; 1–2 milhões de donos por estimativa do SteamSpy [LC4] (não é número oficial).
- **Críticas.** Controles "travados", combate simples e repetitivo [LC6]; "precisa de polimento, passa como mediano" [LC5].
- **Arte.** 2D cartoon com contorno grosso, poucas poses fortes.
- **Lição.** Com base simples, o que segura é variedade de arma + progressão permanente + co-op de sofá.

### 3.4 Lost Castle 2 (Hunter Studio, acesso antecipado 24/07/2024, versão 1.0 em 10–11/06/2026)

- **Loop.** O mesmo esqueleto com muito mais sistema: quase 200 armas [LC18], encantamentos de arma, bônus permanentes, armadura e saque no meio da run [LC11], sistema de "ressonância de inscrições" para builds [LC16].
- **Co-op.** Online 2–4; co-op local chegou em atualização posterior porque a falta dele, somada a servidores instáveis no lançamento, pesou [LC10]. Reviver: resgatar a "alma" do aliado; soltar no ponto ideal devolve mais vida [LC16]. Guias insistem: alguém vivo para reviver vale mais que dano bruto [LC16].
- **1.0.** Final da história, dificuldades Pesadelo 4 e 5, chefe oculto, armas liberadas por chefes [LC11][LC15]. Mais de 700 mil jogadores no acesso antecipado [LC14]. Steam "Mostly Positive" (~11 mil análises), com análises recentes piorando em algumas regiões por desempenho após a 1.0 [LC15].
- **Elogios.** "Possível sucessor de Castle Crashers", 74/100; armas definem a run [LC8]; "muito divertido e ainda melhor em co-op" [LC13].
- **Críticas.** Dificuldade irregular e escalonamento [LC9][LC12]; netcode ruim, impossível reconectar após queda [LC12]; história fraca [LC19][LC13]; problemas técnicos [LC13].
- **Lição.** Reviver com *habilidade* (ponto ideal) transforma uma espera em microjogo. E infraestrutura de rede derruba nota de jogo bom.

### 3.5 Nine Parchments (Frozenbyte, 2017)

- **Loop.** Tiro com dois analógicos e feitiços; aprendizes de mago colecionam até 9 pergaminhos [NP5]. Seis elementos em pares opostos (fogo/gelo, vida/morte, raio/vapor) mais um grupo sem elemento; inimigos têm imunidades que forçam a trocar de feitiço [NP5]. Feixes canalizados são o tipo mais comum e **podem ser combinados com feixes de outro elemento** [NP5].
- **Co-op.** Até 4 local e online [NP8]; fogo amigo "não só permitido como incentivado" [NP2]; personagens novos por cajados e missões [NP7].
- **Recepção.** OpenCritic 65, 27% recomendam [NP1].
- **Elogios.** Visual "lindíssimo" [NP4]; divertido em grupo.
- **Críticas.** Sistema de salvamento "desconcertante" que prejudicava o multiplayer [NP3]; 32 fases parecidas, pouca profundidade [NP2]; combate "não evolui desde a primeira fase" [NP1]; solo arrastado [NP1].
- **Lição.** Bonito + sistema elemental + co-op não bastam. Faltou variação de verbo ao longo da campanha e progresso sem atrito entre amigos.

### 3.6 Wizard of Legend (Contingent99, 2018) e Wizard of Legend 2 (Dead Mage / Humble, 1.0 em jun/2025)

- **WoL1.** Roguelite de magia rápida, quase um jogo de luta visto de cima: 4 arcanas equipadas e relíquias. Co-op só local, 2 jogadores [W3]; o caído volta se o sobrevivente derrotar inimigos [W4]. Elogiado por combate e pixel art [W1]; criticado por pouca variedade de inimigos e cenários [W2] e por ser difícil acompanhar a tela em dupla [W3].
- **WoL2.** 4 jogadores online/local, 3D [W12]. Críticos: média ~85 no OpenCritic [W5]. Jogadores: Steam "Mixed" (análises neutras), cerca de 1.950 análises [W6]. Reclamações: estilo "genérico" que perdeu a identidade do pixel art [W9][W10]; cenas poluídas que escondem a ação [W5]; saque não instanciado, "feito para solo com co-op colado" [W5]; lag e travamentos no acesso antecipado [W8]. Elogio: co-op a 4 é "o caos mais divertido" quando funciona [W7].
- **Lição.** Trocar de estilo visual sem ganhar personalidade é perda líquida. E co-op "colado" é percebido na hora.

### 3.7 Ravenswatch (Passtech / Nacon, 1.0 em 26/09/2024)

- **Loop.** Run de 3 capítulos (Dark Hills, Storm Island, Avalon); em cada um, pouco menos de 20 min de exploração contra o relógio (dias e noites) para ficar forte antes do chefe; run completa ~1h15 [R5]. Heróis de contos (Chapeuzinho que vira lobisomem à noite, Flautista, Beowulf, Rainha da Neve, Aladdin, Melusina, Gepeto, Sun Wukong, Carmilla; depois Romeu e Julieta e Merlin, chegando a 12) [R4][R5][R6].
- **Co-op.** Até 4, só online; o estúdio disse que tela dividida/sofá era complicado demais [R7]. Heróis não se repetem no grupo [R1]. Reserva de Penas do Corvo para reviver, dividida entre os jogadores [R1][R3].
- **Escalonamento.** Cada jogador extra somava +17% de inimigos; a atualização 1.010 (mai/2025) baixou para +13% [R6]. Jogadores reclamavam que vida e resistência a atordoamento extras deixavam tudo lento mesmo em dupla [R9].
- **Elogios.** Co-op "mais divertido e mais fácil que o solo" [R1]; heróis muito distintos.
- **Críticas.** "Feito para 4, não escala bem para solo" [R3]; inimigos que matam com um golpe pioram em grupo [R2].
- **Arte.** 3D com sombra chapada e contorno de tinta de HQ (herdado de Curse of the Dead Gods): estilo que nasce de shader, portanto de código.
- **Lição.** Relógio dá urgência e divide o grupo de forma saudável ("você pega aquilo, eu pego isto"), mas 1h15 é longo. Escalar atordoamento/vida deixa o jogo esponjoso; escalar quantidade é melhor aceito.

### 3.8 Children of Morta (Dead Mage / 11 bit, 2019)

- **Loop.** Família Bergson, cada parente é uma classe; masmorras procedurais intercaladas com cenas da casa. Árvore por personagem e bônus de família que valem para todos (subir um parente melhora os outros) [C5]. "Fadiga de corrupção" reduz a vida máxima de quem joga demais com o mesmo personagem e empurra a troca [C5].
- **Co-op.** 2 jogadores locais; online veio depois [C4][C6]. Em dupla os inimigos têm mais vida, mas dá para reviver [C6]. Atritos: dividir orbes, itens e poções; não poder abandonar o caído [C5]. O tanque é "quase injogável sozinho" [C4]; crítica de design: classes pensadas para grupo sofrem no solo [C7].
- **Arte.** Pixel art pintado à mão, animação quadro a quadro e **luz dinâmica em alta resolução por cima** [C1]; pipeline de renderização próprio [C2]. A equipe achou que pixel art seria mais fácil e descobriu que dá muito trabalho [C9].
- **Críticas.** Tedioso e repetitivo para parte da crítica [C4].
- **Lição.** Progresso que beneficia o grupo todo elimina a inveja de saque. Luz moderna sobre sprite é um "truque de AAA" barato.

### 3.9 Castle Crashers (The Behemoth, 2008)

- **Loop.** Beat 'em up com XP e atributos, magias por cavaleiro, mascotes, mapa-múndi com seleção de fase [CC1].
- **Co-op.** 4 jogadores, entra e sai a qualquer momento [CC1]. Todos presos na mesma tela por parede invisível [CC6]. Reanimar o caído é "incrível, divertido até quando você morre" [CC3]. Depois do chefe, os cavaleiros brigam entre si pelo beijo da princesa [CC4]; todos disputam o golpe final no chefe [CC3].
- **Números.** Em 2012: mais de 2 milhões de cópias só no Xbox Live Arcade e mais de 3 milhões de jogadores registrados [CC5]. Totais maiores circulam, mas não confirmei.
- **Críticas.** Com 4, "caótico demais", escondendo a profundidade do solo [CC2]; arma nova não é compartilhada [CC1].
- **Arte.** Cartoon 2D de Dan Paladin: formas grandes, cores chapadas, humor nas animações de reação. Envelheceu bem porque não tenta ser realista (leitura minha).
- **Lição.** Rivalidade leve dentro da cooperação gera história para contar. Humor na animação é parte do produto.

### 3.10 Full Metal Furies (Cellar Door Games, 2018)

- **Loop.** Brawler com 4 classes (tanque, lutadora, engenheira, atiradora) e uma camada de enigmas ocultos no estilo "The Witness" [F3][F5].
- **Co-op.** Inimigos nascem dentro de escudos coloridos que só a personagem da cor quebra [F2]. No solo, o jogador controla 2 personagens e alterna; a que sai recarrega as habilidades em segundo plano [F1].
- **Texto de design do estúdio** [F1]: três abordagens comuns e seus defeitos: *sem escalonamento* (existe um ponto em que o jogo quebra, fácil ou difícil demais), *número forçado de jogadores* e *escalonamento fixo por algoritmo*. Fazer solo e co-op igualmente bons "somou dois anos ao cronograma".
- **Resultado.** Metacritic 85 (PC) e 75 (Xbox); não se pagou; o estúdio chamou de "fracasso bem grande" [F6]. A Destructoid aponta a confusão do público: muita gente tratou os enigmas como missão secundária quando eram metade do jogo [F3]. Edge: combos de equipe difíceis de coordenar e o tanque vira "babá" [F4]. PC Gamer: escudos frustram no solo quando a personagem certa caiu [F2].
- **Lição.** Trava dura de cor = alguém sempre esperando. Mistura de gêneros que não cabe numa frase é difícil de vender. Solo com troca de personagem funciona.

### 3.11 Gauntlet (Arrowhead / WB, 2014)

- **Loop.** Masmorras em tela compartilhada, 4 classes com *esquemas de controle diferentes*: Guerreiro (clássico), Valquíria (ação tipo Zelda), Elfo (dois analógicos), Mago (combina elementos como em Magicka) [G1].
- **Co-op.** Skull Coins são continues do grupo, ganhos matando; sem moedas, o último vivo precisa lutar para encher o medidor e trazer alguém de volta [G5]. Quem estiver de coroa no fim da fase leva 500 de ouro a mais [G5]. Maestrias liberadas por ações (quebrar cenário, vencer chefe) [G5].
- **Elogios.** Polido, fiel, trabalho em equipe no centro [G3].
- **Críticas.** "Diversão passageira" [G2]; ambientes repetitivos [G4]; Elfo forte demais [G4]; solo chato (Outerhaven, via busca); média de 4 h jogadas [G7].
- **Lição.** Assimetria de *controle* entre classes deixa cada jogador num "jogo diferente" na mesma tela. Rivalidade por ouro é tempero barato. Faltou motivo para voltar.

### 3.12 Heroes of Hammerwatch (Crackshell, 2018) e II (2025)

- **Loop.** Roguelite de masmorra com cidade: 10 prédios para melhorar, dando upgrades a todos os personagens e liberando recursos [H1]; XP persiste; NG+ [H1][H2]. No segundo, progresso é compartilhado entre personagens, menos o nível [H6]; dá para visitar a cidade de outros jogadores [H2].
- **Co-op.** Até 4 online; a falta de co-op local foi a reclamação mais comum (local veio depois no primeiro) [H5][H7].
- **Recepção.** HoH II "perfeição roguelike" [H3]; críticas a grind e à mecânica de maldição das sombras [H6]; "tudo é pequeno demais na tela" [H5].
- **Lição.** Base que cresce é meta-progressão que o grupo sente junta. Sprite miúdo mata legibilidade.

### 3.13 Windblown (Motion Twin, acesso antecipado desde 24/10/2024)

- **Loop.** Roguelite 3D isométrico muito rápido, baseado em dash, com meta de "intensidade de Devil May Cry com co-op online" [WB3]. A equipe jogou fora dois anos de combate e refez em três semanas: "é preciso ousar matar um recurso que não funciona" [WB4].
- **Co-op.** 1–3, só online [WB7]; todo saque é compartilhado, segundo análises do acesso antecipado [WB1][WB2]. **Morte súbita**: se um caído não é revivido, o resto fica extremamente vulnerável; gerou consternação e mudança planejada [WB1].
- **Estado.** 1.0 prevista para 2026 [WB6]; não confirmei se já saiu.
- **Arte.** Low-poly cel-shaded colorido, silhuetas simples, efeitos de velocidade.
- **Lição.** Punir o time pelo erro de um mata a boa vontade. Saque compartilhado é o padrão esperado.

### 3.14 Risk of Rain 2 (Hopoo, 2019–2020)

- **Loop.** Terceira pessoa; a dificuldade sobe com o tempo por um coeficiente global; em grupo o relógio pesa mais [RR1]. Itens empilham até o absurdo.
- **Co-op.** Morreu, só volta na fase seguinte: "se o parceiro morre cedo, vira inútil" [RR2]. Saque é de quem pega primeiro; o mod ShareSuite existe porque "jogadores têm itens roubados ou um domina a partida" [RR4].
- **Recepção dividida.** "Fácil solo, dificílimo com 4" [RR7] contra "quatro jogadores coordenados ficam ridiculamente fortes" [RR6]; "não jogue sozinho" [RR3].
- **Lição.** Relógio como dificuldade cria tensão entre "explorar mais" e "avançar". Saque disputado e morto ocioso são os dois defeitos que a comunidade corrige com mod.

### 3.15 Helldivers (2015) e Helldivers 2 (2024), Arrowhead

- **Fogo amigo como princípio.** Johan Pilestedt: um único conjunto de regras para o mundo; se a bala mata o inimigo, mata o aliado; tirar isso exigiria tirar o dano das balas ("é a lei") [HD3][HD1]. Morte acidental "é engraçada" e combina com a sátira [HD4]; torna o jogador parte interativa do campo, afetando posicionamento [HD2].
- **Tensão nos comandos.** Estratagemas são chamados com sequências de direcional, como código de trapaça antigo [HD8]; o próprio ato de pedir ajuda é uma tarefa sob pressão.
- **Câmera.** O primeiro usa tela compartilhada até online; jogadores reclamaram que não dá para se afastar; defensores dizem que força formação [HD5]. O segundo abandonou a tela compartilhada.
- **Números.** Helldivers 2: 12 milhões em 12 semanas [HD6].
- **Lição.** Fogo amigo funciona quando é *coerente com as regras do mundo* e o tom é cômico. Parte do público sempre vai pedir para desligar [HD2].

### 3.16 It Takes Two (2021) e Split Fiction (2025), Hazelight

- **Princípio.** Josef Fares: desenhar co-op desde o começo é diferente de fazer single-player e adaptar; "não dá para jogar sozinho, é impossível"; o segredo é achar "mecânicas que se comunicam bem entre si" [IT1][IT2]. História e mecânica andam juntas [IT3].
- **Estrutura.** Ferramentas assimétricas e complementares que mudam a cada capítulo (nv nos detalhes); nenhuma progressão numérica.
- **Números.** It Takes Two: 20–23 milhões [IT6]. Split Fiction: 1 milhão em 48 h, 2 milhões em uma semana, 4 milhões em dois meses, Metacritic 91 [IT4][IT5][IT6].
- **Lição.** Variedade de verbo vence profundidade de sistema quando o objetivo é diversão a dois. Assimetria complementar é o padrão ouro de interdependência.

### 3.17 Overcooked (2016) e Overcooked 2 (2018), Ghost Town Games

- **Princípio.** "Tarefas demais para o número de jogadores, mais nuances que trazem o pânico" (Phil Duncan) [O3]. Todos são igualmente responsáveis; ninguém carrega o time [O1]. Comunicação é *a* habilidade [O1]. Cada fase começa pela "história" de como os jogadores devem se comportar [O4]. O projeto pensa em liberdade contra restrição [O4].
- **Lição.** A interdependência vem do *espaço* (cozinha que separa, esteira, balcão único), não de classes. Qualquer pessoa entende em 30 segundos.

### 3.18 Hades (2020) e Hades II (1.0 em 25/09/2025), Supergiant

- **Pipeline de arte.** Personagens modelados em 3D e animados; depois, "milhares e milhares de quadros" renderizados de vários ângulos viram sprites 2D; o jogo não renderiza 3D em tempo real [HA3]. Hades saiu com 942.489 quadros de animação de personagens e inimigos; captura de movimento serviu de base para boa parte [HA5]. Quase todos os NPCs partem de 2 modelos-base; a arte 2D do retrato é a referência; cores em camadas e uma camada de **contorno preto pintado à mão** aproximam o 3D do traço 2D [HA1][HA2]. Câmera ortográfica do jogo é replicada no programa 3D para pré-visualizar [HA2]. Cenários são pintura 2D; efeitos são animações 2D [HA3]; efeitos estilizados feitos por um único artista de VFX/UI [HA4].
- **Legibilidade.** Hades é citado por intenções de inimigo "cristalinas" pela animação [HA10]. Hades II recebeu a crítica "tem um problema de legibilidade": densidade e caos na tela decidem quais estilos de jogo parecem seguros [HA6]; tópicos de Steam dizem que a animação do inimigo não revela o raio do ataque [HA7]; a luta contra Cronos tem problema de visibilidade [HA9].
- **Notas.** Metacritic 93 (Hades) e 94–95 (Hades II) [HA8].
- **Lição para este projeto.** O caminho "3D do Blender renderizado em folhas de sprite com contorno e sombra chapada" é o mesmo do jogo mais elogiado do gênero, e é automatizável. Mas até o melhor estúdio perde legibilidade quando aumenta a densidade de efeitos: com 4 jogadores o orçamento de VFX tem de ser regra escrita.

### 3.19 Outros jogos consultados (notas curtas)

| Jogo | O que interessa |
|---|---|
| **Rotwood** (Klei; acesso antecipado abr/2024, lançamento completo 03/03/2026 [X2]) | 1–4, animação 2D desenhada com rig; combate entre os melhores do gênero em sensação [X1]. Reclamações: com 4 é "fogo de artifício constante" [X4]; a câmera compartilhada "te faz refém", indo para onde está a maioria [X3]; laço roguelite raso. |
| **Absolum** (Dotemu, out/2025) | Só 1–2 jogadores; beat 'em up roguelite; OpenCritic ~86, 96% recomendam; 500 mil cópias rápido [X5]. Crítica: "pouco rogue no roguelite", e dois jogadores "já é caótico" [X5]. |
| **Sworn** (Windwalk) | "Hades com co-op" a 4. Solo "plano e básico"; balanço varia com o tamanho do grupo; balões de comunicação minúsculos [X6]. |
| **TMNT: Shredder's Revenge** (2022) | Até 6. "Toca aqui" transfere 2 unidades da própria vida; 3 golpes de equipe (sanduíche, giro, rebatida); número de inimigos escala com jogadores [X7]. |
| **33 Immortals** (Thunder Lotus) | 33 jogadores. Poderes cooperativos só disparam com outros jogadores parados em ladrilhos brilhantes ao lado [X8]. Crítica: combate raso, pouca variedade [X8]. |
| **Elden Ring Nightreign** (2025) | Revive-se o aliado **batendo nele** até esvaziar a barra; cada queda aumenta a barra (até 3 segmentos); os criadores acharam "engraçado" [X9]. Solo injusto no lançamento; patch deu reviver automático uma vez por chefe [X9]. |
| **Dragon's Crown** (2013) | Personagens grandes: 4 enchem a tela; "perco completamente onde meu personagem está" [X10]. |
| **Deep Rock Galactic** | 4 classes com ferramenta de travessia própria que se complementam; botão de chamar atenção "quase dispensa voz" [X14]. |
| **Left 4 Dead** | Diretor de IA controla ritmo; infectados especiais não podem ser resolvidos sozinho [X15]. |
| **Spellbreak** | Interações elementais valem "independentemente de quem lançou": tornado absorve raio, gelo congela nuvem tóxica em barreira, fogo + veneno vira "fogo de dragão" [X12]. |
| **Genshin Impact** | Reação em dois tempos: uma aura aplicada no alvo e um gatilho de outro elemento [X13]. Modelo fácil de ler e de ensinar. |
| **The Spell Brigade** (1.0 em 2026) | Survivors-like 1–4 com fogo amigo e sinergias de magia; OpenCritic 70; solo fraco, grind pesado [X16]. |
| **Peak, R.E.P.O. e a onda "friendslop"** (2025) | Jogos co-op baratos (US$ 5–20) de comédia física e voz por proximidade: estimativas de 18,5 e 15,4 milhões de cópias [X11]. O motor é o momento compartilhável: fracasso tem de ser engraçado [X11]. |
| **Cordels & Spells** (Nuntius Games, Brasil) | Roguelite de ação 2D com co-op em fantasia brasileira (cangaço, cordel) [X17]. Mostra que "tema brasileiro + co-op de ação" já tem alguém explorando. |

## 4. Pilares do co-op divertido

1. **Interdependência positiva: eu fico melhor por sua causa.** Ferramentas assimétricas e complementares (It Takes Two [IT1]), travessia que serve aos outros (Deep Rock [X14]), espaço que obriga a passar o prato (Overcooked [O4]). A versão que falha é a trava dura (Full Metal Furies [F2][F4]).
2. **Caos controlado por regras coerentes.** Um conjunto pequeno de regras físicas que vale para todos, inclusive aliados (Magicka, Helldivers [HD3]). O caos é engraçado porque é *consequência* e não sorteio.
3. **Erro barato, recuperação rápida.** Fogo amigo só é piada se reviver custa um segundo (Magicka [M7]); reviver que parece ridículo ajuda no tom (Nightreign [X9], Castle Crashers [CC3]).
4. **Viradas.** O último vivo que salva o grupo: medidor de Skull Coin (Gauntlet [G5]), sobrevivente que traz o parceiro matando inimigos (Wizard of Legend [W4]). O sistema precisa *permitir* a virada.
5. **Papéis legíveis sem dependência obrigatória.** Classes que jogam diferente (Gauntlet [G1], Ravenswatch [R1]) e que funcionam sozinhas. Classe "só de grupo" vira peso no solo [C7].
6. **Comunicação como habilidade, com apoio do jogo.** Overcooked torna falar a habilidade central [O1]; Deep Rock dá um botão que substitui a voz [X14]. Sworn erra com balões minúsculos [X6].
7. **Rivalidade leve dentro do time.** Coroa de ouro (Gauntlet [G5]), arena da princesa (Castle Crashers [CC4]), placar de fim de sala. Opcional e sem prejudicar o objetivo comum.
8. **Progresso sem inveja.** Saque compartilhado (Windblown [WB2]), bônus de família (Children of Morta [C5]), cidade comum (Hammerwatch [H1]). O contrário gera mod de correção (Risk of Rain 2 [RR4]) e nota baixa (Wizard of Legend 2 [W5]).
9. **Histórias para contar.** A onda de 2025 mostra que o produto é o "lembra quando você me explodiu?" [X11]. Vale medir por sessão: quantos momentos desses o jogo gerou.
10. **Entrar e sair fácil.** Entra-e-sai de Castle Crashers [CC1], entrada a quente de Magicka 2 [M2l], passe de amigo da Hazelight [IT4].

## 5. Problemas clássicos e como os bons jogos resolvem

### 5.1 Legibilidade com 4 jogadores e muito efeito

| Sintoma relatado | Onde | O que fazer |
|---|---|---|
| "Perco meu personagem" | Dragon's Crown [X10], Castle Crashers [CC2] | Personagem pequeno em relação à tela; anel/contorno de cor fixa por jogador; marcador acima da cabeça; silhuetas muito diferentes entre heróis. |
| "Fogos de artifício constantes" | Rotwood [X4], WoL2 [W5] | Orçamento de VFX por jogador. Guia de estilo da Riot: clareza de jogo acima de tema; formas primária e secundária nítidas, pouco ruído; valor (claro/escuro) dirige o foco; evitar 0% e 100% de valor, que se confundem com cenário e interface [D8]. |
| "Não sei o raio do ataque" | Hades II [HA7][HA9] | Telegrafia padronizada: toda ameaça inimiga com a mesma cor e a mesma forma no chão, antes do golpe. Cor reservada: nenhum efeito de jogador pode usá-la. |
| Efeito de aliado tapa o inimigo | geral; até guildas de WoW escurecem a tela para enxergar [D11] | Efeitos de aliados com opacidade reduzida para quem não lançou; duração curta; partículas somem antes do próximo golpe. |
| Sprite miúdo | Hammerwatch [H5] | Limite de zoom mínimo; se não couber, a câmera não é a solução (ver 5.2). |

Leitura minha: para um jogo gerado por código isso é vantagem. Regra é fácil de impor por script (paleta por papel, faixa de valor, tempo máximo de partícula) e "menos partículas, mais forma" combina com estilo deliberado e foge da cara de efeito genérico.

### 5.2 Câmera

| Abordagem | Exemplo | Prós | Contras |
|---|---|---|---|
| Tela única com parede invisível | Castle Crashers [CC6], Magicka [M11] | Mantém o grupo junto, simples | Um jogador segura os outros; bagunça no centro |
| Tela única até online | Helldivers 1 [HD5] | Força formação | Queixa de não poder se afastar |
| Câmera que segue a maioria | Rotwood local [X3] | Simples | Minoria fica fora da tela, "refém" |
| Zoom até um limite, depois dividir a tela | artigo de design [D9] | Liberdade | Complexo; ruim em tela pequena |
| Teletransporte / bolha de retorno / indicador fora da tela | devlogs e fóruns [D10] | Barato | Pode irritar se frequente |
| Câmera individual online | Ravenswatch, Windblown [R7][WB7] | Sem conflito | Exige rede; sem sofá |

Recomendação: online = câmera individual; local = tela única com zoom limitado, centro ponderado e bolha de retorno. O addon PhantomCamera tem modo de seguir grupo (seção 9).

### 5.3 Jogador morto ocioso

| Solução | Exemplo | Avaliação |
|---|---|---|
| Reviver instantâneo por habilidade de qualquer um | Magicka [M7] | Melhor para tom cômico; exige custo de oportunidade (parar de atacar) |
| Reviver com microjogo | Lost Castle 2 (ponto ideal) [LC16], Nightreign (bater no aliado, barra cresce a cada queda) [X9] | Tira a passividade do salvador; escala a tensão |
| Reserva de vidas do grupo | Ravenswatch [R1], Gauntlet [G5] | Decisão coletiva; "gastei a última pena" vira drama |
| Sobrevivente "paga" matando | Wizard of Legend [W4], Gauntlet [G5] | Gera virada; pode demorar |
| Fantasma que atrapalha inimigos | Rampage Knights: volta após 10 abates; revive com vida cheia, então dá para se revezar morrendo [D2] | Morto continua jogando; cuidado com exploração |
| Caixão/ponto fixo | Spelunky [D2] | Mortos "ficam entediados" [D2] |
| Só na próxima fase | Risk of Rain 2 [RR2] | Pior caso |
| Punir os vivos | Windblown (morte súbita) [WB1]; proposta de temporizador + penalidade aos vivos [D1] | Risco alto de frustração |
| Temporizador que cresce a cada morte + ficha de reviver | relato de desenvolvedor: "transformação da noite para o dia" [D3] | Simples e eficaz |
| Reviver automático no solo | Nightreign pós-patch [X9] | Necessário quando não há parceiro |

### 5.4 Dificuldade por número de jogadores

- **Tipos**, segundo a Cellar Door [F1]: sem escalonamento (quebra em algum ponto), número forçado, algoritmo fixo. Eles fizeram escalonamento dinâmico de 1 a 4 e pagaram dois anos.
- **Números reais.** Ravenswatch: +13% de inimigos por jogador (era +17%) [R6]. TMNT: mais inimigos conforme o grupo [X7]. Children of Morta: mais vida nos inimigos em dupla [C6]. Risk of Rain 2: o relógio de dificuldade anda mais rápido em grupo [RR1]. Nightreign: vida de inimigo no solo teve de ser reduzida depois [X9].
- **O que os jogadores rejeitam.** Inimigo esponja e resistência a atordoamento que anula o golpe de cada um [R9]; grupo coordenado trivializando tudo [RR6].
- **Recomendação.** Escalar primeiro *quantidade e composição* (mais inimigos, mais tipos que exigem resposta diferente), depois vida com retorno decrescente; não escalar atordoamento; inimigos especiais que punem quem se isola (Left 4 Dead [X15]; "ficar separado fica mais difícil" [D5]).

### 5.5 Jogador solo

| Solução | Exemplo | Nota |
|---|---|---|
| Controlar 2 personagens com troca rápida | Full Metal Furies [F1] | Mantém as sinergias; quem sai recarrega |
| Companheiro de IA | Children of Morta (às vezes) [C5], Left 4 Dead [X15] | Mantém interdependência; exige IA decente |
| Reviver automático limitado | Nightreign [X9] | Mínimo necessário |
| Nenhuma adaptação | Magicka 2 [M2d], Nine Parchments [NP1] | Solo vira castigo |

Para este projeto isso é crítico: o usuário testou o jogo anterior sozinho, pelo navegador do celular. O primeiro contato será solo. O companheiro (IA ou segundo personagem) tem de existir no protótipo.

### 5.6 Outros problemas recorrentes

- **Saque disputado.** Lost Castle [LC3], WoL2 [W5], Risk of Rain 2 [RR4]. Solução: instanciar ou compartilhar.
- **Rede.** Reconexão impossível (Lost Castle 2 [LC12]), online abismal (Magicka [M2]), lag (WoL2 [W8]). Solução de escopo: nascer local/solo com bots e tratar online como etapa própria.
- **Combate que não evolui.** Nine Parchments [NP1], Magicka 2 [M2c], Gauntlet [G4], WoL1 [W2]. Solução: verbo novo por bioma; inimigos que pedem respostas diferentes.
- **Proposta difícil de explicar.** Full Metal Furies [F3]. Solução: o jogo cabe em uma frase.
- **Run longa.** Ravenswatch 1h15 [R5]; Nightreign com "30 minutos até voltar ao chefe" [X9]. Para teste em celular, 12–20 min.

## 6. Lacunas e oportunidades para um conceito original

1. **Combinação entre jogadores, não dentro da mão de um.** Em Magicka a combinação nasce na fila de um jogador; a interação entre jogadores é sobretudo acidente (feixes, fogo amigo). Spellbreak mostrou combinações entre feitiços de pessoas diferentes, mas em PvP [X12]; Nine Parchments combina feixes [NP5]. **Um co-op PvE cujo núcleo é "o seu efeito + o meu efeito = um terceiro" está pouco explorado.**
2. **Fogo amigo construtivo.** O gênero trata acertar o aliado como dano (Magicka, Helldivers) ou como nada. Falta o meio: acertar o aliado *faz algo útil e arriscado* (encantar a arma dele, refratar meu feixe no escudo dele, carregá-lo como bateria). Mantém a comédia e adiciona técnica.
3. **Morte como segundo modo de jogo.** As soluções existentes são temporizador ou fantasma fraco. Um estado de "espírito" com verbos próprios e úteis (marcar, possuir objetos do cenário, alimentar a reação dos vivos) ainda não é padrão em nenhum dos jogos analisados.
4. **Co-op de ação desenhado para interdependência.** Os Hades-likes co-op são acusados de single-player multiplicado [X6][W5]. O espaço entre "It Takes Two" (interdependência total, sem rejogo) e "Ravenswatch" (rejogo, pouca interdependência) está aberto.
5. **Legibilidade como estética.** Ninguém vende "o co-op de 4 que você entende de relance". Um estilo de formas limpas, pouca partícula e cor com função é diferencial e é o que um pipeline por script faz melhor.
6. **Solo de primeira classe com parceiro.** Quase todos tratam solo como modo de segunda. Um companheiro com personalidade (familiar, criatura, segundo herói) resolve o solo e vira identidade.
7. **Sessão curta.** A maioria pede 40–75 min. Expedições de 12–20 min com entrada fácil combinam com navegador e celular.
8. **Tema fora do mago de capuz.** Magicka, Nine Parchments, WoL e Spell Brigade são todos "magos". Ravenswatch foi para contos europeus. Fantasia brasileira já tem Cordels & Spells [X17], então não é terreno vazio, mas é pouco ocupado. Hipótese minha, não medida: um mundo original com lógica própria de "matérias" (não os 4 elementos clássicos) diferencia mais que trocar o cenário.
9. **Reviver com graça.** Bater no amigo para reviver (Nightreign [X9]) e a reanimação de Castle Crashers [CC3] mostram que a *animação de reviver* é oportunidade de humor e de aplicar os princípios da Disney (antecipação, exagero, apelo).

**Sementes de direção** (não são conceitos fechados):
- *Reação em cadeia*: cada herói controla uma "matéria"; o cenário e os inimigos guardam o estado; o combate é montar reações a duas ou três mãos.
- *Elo*: os jogadores são ligados por algo físico (corda, feixe, corrente de energia) que é arma e ferramenta.
- *Vivos e espíritos*: cair muda o jogador de plano; os dois planos precisam um do outro para vencer o chefe.

## 7. Mecânicas candidatas (15), com prós e contras

Colunas da avaliação final: são julgamentos meus a partir do que foi levantado, não medições.

**1. Reação entre jogadores (preparar e detonar).** Um jogador aplica um estado (no inimigo ou no chão); outro elemento, de outro jogador, detona. Referências: Genshin [X13], Spellbreak [X12].
- Prós: interdependência sem trava; ensina-se em um minuto; matriz pequena; funciona com 1 botão por habilidade (toque); cada reação é um efeito visual assinável por script.
- Contras: precisa de estados muito legíveis sobre o inimigo; com 4 jogadores as reações podem disparar "sozinhas" e perder a intenção; solo exige companheiro ou segundo elemento no próprio herói.

**2. Fila de elementos na mão (estilo Magicka), reduzida.** Combinar 2–3 elementos antes de lançar.
- Prós: profundidade e descoberta; identidade forte.
- Contras: é a assinatura de Magicka (risco de clone); difícil no controle [M2g] e pior no toque; explosão de conteúdo. Cálculo feito aqui: 8 elementos com opostos se anulando e fila de até 5 dão **584 combinações válidas**, vezes 4 modos de conjurar = até 2.336 feitiços; uma matriz de pares com 5 elementos tem **15 células**, com 6 tem 21. Para um time de um agente, a matriz é produzível com qualidade; a fila, não.

**3. Feixes que se cruzam.** Feixes de jogadores diferentes se fundem ou explodem conforme o par. Referências: Nine Parchments [NP5], Magicka (nv).
- Prós: exige mira e posição conjunta; espetáculo visual barato (shader de feixe); ótimo para chefes.
- Contras: canalizar prende o jogador; ruim no toque sem mira assistida; ilegível com 4 feixes.

**4. Fogo amigo cômico e regulável.** Aliados sofrem empurrão/estado e dano reduzido; opção de desligar.
- Prós: mantém as histórias; não afasta quem odeia [HD2]; simples.
- Contras: menos tensão que o "é a lei" de Helldivers [HD3]; precisa de reviver barato para ter graça.

**5. Fogo amigo construtivo (aliado como alvo útil).** Lançar no aliado encanta a arma, refrata o feixe ou o carrega.
- Prós: original; transforma erro em técnica; alimenta a mecânica 1.
- Contras: mais regras para explicar; IA do companheiro precisa entender; pode confundir com o dano de fogo amigo se as duas coisas coexistirem.

**6. Estado de espírito ativo ao cair.** O caído vira espírito com verbos próprios (marcar, empurrar, possuir objeto) e volta ao cumprir algo.
- Prós: zera a ociosidade; virada dramática; diferencial claro.
- Contras: um segundo conjunto de regras e animações; risco de morrer ser vantajoso [D2]; precisa de limite.

**7. Reviver com microjogo.** Ponto ideal de tempo (Lost Castle 2 [LC16]) ou bater no aliado com barra crescente (Nightreign [X9]).
- Prós: barato; engraçado; tensão escala.
- Contras: frustra se o custo crescer demais; no solo não existe.

**8. Reserva de vidas do grupo.** Penas/moedas compartilhadas [R1][G5].
- Prós: decisão coletiva; fácil de balancear; serve ao solo.
- Contras: novato "gasta" as vidas dos outros e gera culpa; não resolve a espera em si.

**9. Papéis por ferramenta de utilidade.** Cada herói tem um verbo que ajuda os outros (ponte, gancho, parede, luz). Referência: Deep Rock [X14].
- Prós: interdependência suave; identidade por herói; rende quebra-cabeça leve de cenário.
- Contras: exige fases que usem as ferramentas (custo de design de nível); solo perde opções.

**10. Afinidade em vez de trava.** Inimigos com fraqueza que acelera a quebra, sem exclusividade. Versão suave de Full Metal Furies [F2].
- Prós: dá alvo a cada papel; orienta foco.
- Contras: se a diferença for pequena ninguém liga; se for grande vira trava.

**11. Golpes sincronizados em dupla.** Dois jogadores acionam juntos numa janela ou em posição (TMNT [X7], 33 Immortals [X8]).
- Prós: momentos de "toca aqui"; ótimo palco para animação exagerada; legível.
- Contras: coordenar sem voz é difícil [F4]; precisa de sinalização clara e de parceiro-IA que responda.

**12. Elo físico entre jogadores.** Uma ligação que dá bônus por proximidade ou vira arma (o que cruza o fio é atingido).
- Prós: resolve a câmera por design (ninguém se afasta); muito original no gênero; visual forte e barato.
- Contras: restringe liberdade (queixa do Helldivers 1 [HD5]); com 4 jogadores a topologia complica; exige física estável.

**13. Diretor de ritmo e escalonamento por composição.** Sistema que dosa ondas, descanso e especiais conforme o estado do grupo (Left 4 Dead [X15]), com +X% de inimigos por jogador (Ravenswatch [R6]).
- Prós: rejogo sem conteúdo manual; resolve 1–4 jogadores; é puro código.
- Contras: invisível para o jogador; difícil de afinar sem testes humanos.

**14. Rivalidade leve.** Coroa, placar de sala, minidisputa após chefe [G5][CC4].
- Prós: barato; gera história; bom para sofá.
- Contras: pode incentivar comportamento egoísta; sem sentido no solo.

**15. Expedição curta com base que cresce.** Runs de 12–20 min; recursos melhoram uma base comum (Hammerwatch [H1], Children of Morta [C5]).
- Prós: meta-progressão sentida pelo grupo; sessão compatível com celular; base é vitrine de arte.
- Contras: grind se mal dosado [H6]; mais interface.

**Quadro de avaliação** (A = alto, M = médio, B = baixo; "custo" = esforço de produção por script):

| # | Mecânica | Diversão co-op | Funciona solo | Toque / navegador | Custo | Originalidade |
|---|---|---|---|---|---|---|
| 1 | Reação entre jogadores | A | M (com companheiro) | A | M | M–A |
| 2 | Fila de elementos | A | A | B | A | B |
| 3 | Feixes cruzados | A | B | B–M | B–M | M |
| 4 | Fogo amigo cômico | A | n/a | A | B | B |
| 5 | Fogo amigo construtivo | A | M | M | M | A |
| 6 | Espírito ativo | A | B–M | A | M–A | A |
| 7 | Reviver com microjogo | M–A | B | A | B | M |
| 8 | Vidas do grupo | M | A | A | B | B |
| 9 | Ferramentas de utilidade | A | M | M | A | M |
| 10 | Afinidade suave | M | A | A | B | B |
| 11 | Golpes sincronizados | A | M | M | M | M |
| 12 | Elo físico | A | M | A | M | A |
| 13 | Diretor de ritmo | M (invisível) | A | A | M | B |
| 14 | Rivalidade leve | M | B | A | B | B |
| 15 | Expedição curta + base | M | A | A | M | B |

Combinação que eu testaria primeiro: **1 + 5 + 6 + 8 + 13 + 15**, com 4 como opção e 11 para chefes.

## 8. Notas de arte e animação que saem das referências

| Caminho | Quem usa | Viabilidade por script |
|---|---|---|
| 3D pré-renderizado em folhas de sprite, contorno pintado, cenário 2D | Hades [HA1][HA3] | Alta: Blender por Python renderiza N direções por animação. Combina com HD-2D. Custo: memória de textura (Hades tem quase 1 milhão de quadros [HA5]; aqui seria preciso poucas direções e poucos quadros bem escolhidos). |
| 3D simples convertido em pixel art com mapa de normais | Dead Cells [DC1] | Alta: mesma base, render em baixa resolução; a luz dinâmica vem dos mapas de normais. |
| Pixel art com luz dinâmica de alta resolução | Children of Morta [C1][C2] | Média: o projeto anterior já tem rig de pixel art; somar normais e luzes 2D. |
| 3D em tempo real com sombra chapada e tinta | Ravenswatch, Windblown | Alta em PC; no navegador só o que o renderizador Compatibility permite. O estilo vem do shader. |
| 2D cartoon com rig | Castle Crashers, Lost Castle, Rotwood | Média: exige desenho de peças; gerar por código é possível, mas o risco de "cara genérica" é maior. |

Observações:
- **Capuz, máscara, forma simples.** Magicka esconde o rosto; Castle Crashers usa cabeças-capacete. Rosto é o ponto onde arte gerada mais denuncia. Vale escolher heróis cuja expressão venha de silhueta, postura e adereço.
- **Animação vende o golpe.** Hades e Rotwood são elogiados por antecipação clara e recuperação curta [HA10][X1]. Os princípios da Disney entram aqui: antecipação = telegrafia justa; exagero e acompanhamento = impacto; tempo = responsividade.
- **Humor em animação de falha.** Reviver, cair, levar raio molhado: são os momentos que viram clipe [X11].
- **Não trocar identidade por "mais gráfico".** O caso WoL2 [W9] é o aviso.

## 9. Ferramentas ligadas aos problemas de co-op (GitHub, verificadas)

`git ls-remote <url> HEAD` respondeu para todas em 26/11/2026; licença lida no arquivo do repositório.

| Problema | Repositório | Licença | Uso |
|---|---|---|---|
| Câmera compartilhada com grupo | https://github.com/ramokz/phantom-camera | MIT | Addon Godot 4 para Camera2D/3D com modo "Group" (enquadra vários alvos) e "Framed" |
| Companheiro de IA / bots para solo | https://github.com/limbonaut/limboai | MIT | Árvores de comportamento e máquinas de estado (Godot 4) |
| Idem, alternativa em GDScript puro | https://github.com/bitbrain/beehave | MIT | Árvores de comportamento como addon |
| Online (previsão e reconciliação) | https://github.com/foxssake/netfox | MIT | Netcode para Godot 4 |
| Online entre PC e navegador | https://github.com/godotengine/webrtc-native | MIT | WebRTC para builds de PC; no export Web o Godot usa o WebRTC do próprio navegador (nv) |

Não testei nenhum deles nesta etapa; a compatibilidade exata com Godot 4.5.1 e com o export Web fica para a pesquisa técnica.

## 10. Recomendações práticas

1. **Escrever o jogo em uma frase antes de qualquer arte.** Lição de Full Metal Furies.
2. **Núcleo = reação entre jogadores, com 4 ou 5 "matérias" e matriz de 10–15 reações.** Cada reação com forma, cor e som próprios.
3. **Protótipo vertical mínimo:** 1 arena, 2 heróis, 4 matérias, 6 reações, 3 tipos de inimigo, 1 companheiro de IA. Se não for divertido assim, conteúdo não salva (Windblown refez o combate em 3 semanas depois de 2 anos perdidos).
4. **Solo com companheiro desde o primeiro dia**, porque o primeiro teste será solo no celular.
5. **Morte barata e ativa:** reviver em até 2 segundos com gesto engraçado; caído vira espírito com algo a fazer; reserva de vidas do grupo como limite.
6. **Fogo amigo em três níveis** (desligado, cômico, total), padrão "cômico".
7. **Saque e progresso sempre compartilhados.**
8. **Sessões de 12–20 min**; nada de run de uma hora.
9. **Legibilidade como regra de arte escrita:** cor reservada para ameaça inimiga, cor fixa por jogador, limite de partículas e de duração por efeito, efeitos de aliados atenuados, personagem com silhueta única.
10. **Escalar por quantidade e composição de inimigos**, começando em +13% a +17% por jogador (faixa do Ravenswatch) e ajustando; não escalar atordoamento.
11. **Verbo novo a cada bioma** para não cair no "combate que não evolui".
12. **Online é etapa separada.** Primeiro solo + local; depois rede. Rede ruim derruba avaliação.
13. **Evitar:** fila de 8 elementos, travas duras por classe, enigmas ocultos como metade do jogo, punição coletiva por morte individual, sprite pequeno demais, trocar identidade por fidelidade.
14. **Medir nos testes:** momentos de riso ou de virada por sessão, tempo médio de espera do caído, quantas reações foram intencionais.

## 11. Fontes

**Magicka** — [M1] https://gamedeveloper.com/business/postmortem-arrowhead-game-studios-i-magicka-i- · [M2] https://gamedeveloper.com/production/feature-i-magicka-i-almost-a-victim-of-poor-planning · [M3] https://www.pcgamer.com/magickas-buggy-launch-we-didnt-know-the-game-was-being-released · [M4] https://gamedeveloper.com/business/-i-magicka-i-sells-1-3m-copies-4m-dlc-packs-worldwide e https://www.engadget.com/2012-01-19-magicka-summons-1-3-million-in-sales-new-expansion-in-the-works.html · [M5] https://gamingbolt.com/?p=133802 · [M6] https://www.pcgamer.com/magicka-sells-30000-copies-in-24-hours · [M7] https://shacknews.com/article/89356/co-optimized-magicka · [M8] https://magicka.fandom.com/wiki/Controls , https://magicka.fandom.com/wiki/Multiplayer e https://www.giantbomb.com/wd/3030-28914 · [M9] https://www.pcgamer.com/games/adventure/more-than-a-decade-before-helldivers-2-arrowhead-made-one-of-my-favourite-co-op-games-which-only-remains-playable-thanks-to-a-fan · [M10] https://destructoid.com/?p=588808 · [M11] https://steamcommunity.com/app/238370/discussions/0/615086038671601272

**Magicka 2** — [M2a] https://www.pcgamer.com/magicka-2-review/ · [M2b] https://destructoid.com/reviews/review-magicka-2 · [M2c] https://www.slantmagazine.com/games/magicka-2/ · [M2d] https://www.trustedreviews.com/reviews/magicka-2 · [M2e] https://pushsquare.com/reviews/ps4/magicka_2 · [M2f] https://www.playstationlifestyle.net/2015/06/01/magicka-2-review-working-together-ps4/ · [M2g] https://pcgamer.com/magicka-2-preview-its-still-fun-but-hard-to-control-a-wizard · [M2h] https://www.paradoxinteractive.com/games/magicka-2 · [M2i] https://www.newgamenetwork.com/article/1264/magicka-2-review · [M2j] https://www.pcgamesn.com/magicka-2/magicka-2-pc-review · [M2l] https://shacknews.com/article/89792/co-optimized-magicka-2

**Lost Castle 1 e 2** — [LC1] https://store.steampowered.com/app/434650 · [LC2] https://store.epicgames.com/p/lost-castle-abb2e2 · [LC3] https://co-optimus.com/review/1964/page/2/lost-castle-co-op-review.html · [LC4] https://www.steamspy.com/app/434650 · [LC5] https://www.geeksundergrace.com/gaming/review-lost-castle-switch/ · [LC6] https://gamingtrend.com/reviews/lost-castle-review · [LC8] https://game8.co/articles/reviews/lost-castle-2-review-early-access · [LC9] https://www.noobfeed.com/reviews/lost-castle-2-review-pc · [LC10] https://rogueliker.com/lost-castle-2-early-access/ e https://rogueliker.com/lost-castle-2-local-co-op/ · [LC11] https://www.gematsu.com/2026/04/lost-castle-2-launches-june-11 · [LC12] https://vaporlens.app/app/2445690/lost_castle_2 · [LC13] https://playday.one/2026/07/06/lost-castle-2-review/ · [LC14] https://gamesunit.de/artikel/over-700-000-early-access-players-can-t-be-wrong-lost-castle-2-launches-1-0-today-with-new-gameplay-trailer-232264.html · [LC15] https://opencritic.com/news/32861/co-op-steam-game-with-castle-crashers-vibes-finally-launches-and-hits-a-major-milestone · [LC16] https://www.gamebrief.net/blog/lost-castle-2-co-op-guide-2026 · [LC18] https://www.pcgamesn.com/lost-castle-2/steam-early-access · [LC19] https://www.digit.in/features/gaming/lost-castle-2-review-the-rogue-like-fix-i-didnt-know-i-needed.html

**Nine Parchments** — [NP1] https://opencritic.com/game/5256/nine-parchments · [NP2] https://wccftech.com/review/nine-parchments-book-of-blank-pages/ · [NP3] https://nintendoworldreport.com/review/45941 · [NP4] https://www.windowscentral.com/nine-parchments-xbox-one-review-gorgeous-visuals-restricted-world · [NP5] https://frozenbyte.com/?p=10629 · [NP7] https://news.xbox.com/en-us/2017/11/21/nine-parchments-coming-soon-xbox-one/ · [NP8] https://massivelyop.com/2026/10/19/the-stream-team-turning-on-friendly-fire-mode-in-nine-parchments/ e https://www.co-optimus.com/game/4296/platform/game.html

**Wizard of Legend 1 e 2** — [W1] https://Gamespot.com/reviews/wizard-of-legend-review-fast-paced-action/1900-6416917/ · [W2] https://www.windowscentral.com/wizard-legend-xbox-one-review-excellent-foundation-disappointing-depth · [W3] https://twinfinite.net/guides/wizard-of-legend-online-co-op-multiplayer-is-there/ · [W4] https://sirusgaming.com/wizard-of-legend-review · [W5] https://opencritic.com/game/18710/wizard-of-legend-2 · [W6] https://store.steampowered.com/app/2193540/Wizard_of_Legend_2 · [W7] https://ztgd.com/?p=167668 · [W8] https://www.gamegrin.com/previews/wizard-of-legend-2-preview · [W9] https://steamcommunity.com/app/2193540/discussions/0/3833171151458766366 · [W10] https://vaporlens.app/app/2193540/wizard_of_legend_2 · [W12] https://pcgamer.com/wizard-of-legend-is-getting-a-sequel-with-improved-3d-graphics-an-expanded-storyline-and-even-online-multiplayer

**Ravenswatch** — [R1] https://godisageek.com/reviews/ravenswatch-review/ · [R2] https://www.gamegrin.com/reviews/ravenswatch-review/ · [R3] https://noobfeed.com/reviews/ravenswatch-review · [R4] https://news.xbox.com/en-us/2024/11/28/ravenswatch-dlc-heroes · [R5] https://primagames.com/tips/how-to-unlock-each-hero-in-ravenswatch-1-0 · [R6] https://mp1st.com/title-updates-and-patches/ravenswatch-update-1-010-000-out-for-free-romeo-juliet-dlc · [R7] https://www.gamepressure.com/newsroom/ravenswatch-is-there-local-co-op/zd7330 · [R9] https://steamcommunity.com/app/2071280/discussions/0/575995078023065507/

**Children of Morta** — [C1] https://techraptor.net/content/how-dead-mage-created-the-art-for-children-of-morta · [C2] https://gamedeveloper.com/design/postmortem-children-of-morta · [C4] https://screenrant.com/children-of-morta-review/ · [C5] https://gamespot.com/reviews/children-of-morta-review/1900-6417304/ · [C6] https://www.gameinformer.com/review/children-of-morta/children-of-morta-review-family-matters · [C7] https://game-wisdom.com/analysis/children-of-morta · [C9] https://gamedeveloper.com/design/making-family-matter-in-i-children-of-morta-i-

**Castle Crashers** — [CC1] https://gamedeveloper.com/design/design-lesson-101---i-castle-crashers-i- · [CC2] https://giantbomb.com/reviews/castle-crashers-review/1900-51/ · [CC3] https://www.co-optimus.com/review/66/page/1/Castle_Crashers_Co-Op_Review.html · [CC4] https://www.hardcoregaming101.net/castle-crashers/ · [CC5] https://www.engadget.com/2012-09-13-castle-crashers-clocks-in-over-3-million-knights-in-the-making.html · [CC6] https://www.gamesradar.com/castle-crashers-hands-on

**Full Metal Furies** — [F1] https://www.gamedeveloper.com/game-platforms/making-a-better-single-player-and-co-op-experience · [F2] https://www.pcgamer.com/full-metal-furies-review/ · [F3] https://www.destructoid.com/why-is-rogue-legacys-follow-up-considered-a-pretty-massive-failure/ · [F4] https://www.pressreader.com/australia/edge/20180301/281530816505494 · [F5] https://Gamespot.com/reviews/full-metal-furies-review-puzzle-brawler/1900-6417034/ · [F6] https://en.wikipedia.org/wiki/Full_Metal_Furies

**Gauntlet (2014)** — [G1] https://www.avclub.com/gauntlet-review-slaughtering-through-the-oldies · [G2] https://gameinformer.com/games/gauntlet/b/pc/archive/2014/09/29/fleeting-fun · [G3] https://www.destructoid.com/reviews/review-gauntlet/ · [G4] https://www.denofgeek.com/games/gauntlet-review · [G5] https://www.godisageek.com/reviews/gauntlet-slayer-edition-review · [G6] https://blog.playstation.com/archive/2015/08/11/gauntlet-slayer-edition-hits-ps4-tomorrow-new-features-detailed · [G7] https://rawg.io/games/gauntlet-slayer-edition

**Heroes of Hammerwatch** — [H1] https://store.steampowered.com/app/677120 · [H2] https://store.steampowered.com/app/619820/Heroes_of_Hammerwatch_II · [H3] https://www.thesixthaxis.com/2025/01/24/heroes-of-hammerwatch-2-review-roguelike-perfection/ · [H5] https://www.nintendolife.com/reviews/switch-eshop/heroes_of_hammerwatch_-_ultimate_edition · [H6] https://vaporlens.app/app/619820/heroes_of_hammerwatch_ii · [H7] https://www.gog.com/en/game/heroes_of_hammerwatch

**Windblown** — [WB1] https://rogueliker.com/windblown-early-access-review/ · [WB2] https://www.pcgamer.com/games/roguelike/im-terrified-for-my-free-time-after-a-few-hours-with-the-dead-cells-developers-new-frantic-co-op-roguelike-out-this-month · [WB3] https://www.pcgamer.com/games/roguelike/the-new-roguelite-from-the-developers-of-dead-cells-has-one-big-goal-matching-the-intensity-of-japanese-action-games-like-devil-may-cry-but-with-online-co-op · [WB4] https://www.inkl.com/news/for-their-new-roguelite-the-dead-cells-team-scrapped-2-years-of-work-on-combat-and-redid-it-in-just-3-weeks-we-need-to-be-able-to-dare-to-kill-a-feature-when-it-doesn-t-work · [WB6] https://en.wikipedia.org/wiki/Windblown · [WB7] https://store.steampowered.com/app/1911610/Windblown/

**Risk of Rain 2** — [RR1] https://riskofrain2.wiki.gg/wiki/Difficulty · [RR2] https://www.destructoid.com/review-risk-of-rain-2/ · [RR3] https://www.pcgamer.com/risk-of-rain-2-already-kicks-ass-just-dont-play-it-alone · [RR4] https://thunderstore.io/package/FunkFrog-and-Sipondo/ShareSuite · [RR6] https://www.gamerevolution.com/?p=655404 · [RR7] https://steamcommunity.com/app/632360/discussions/0/2141966124582714590

**Helldivers** — [HD1] https://blog.playstation.com/2024/03/12/helldivers-2-how-arrowhead-turned-the-twin-stick-shooter-original-into-a-bombastic-ps5-sequel/ · [HD2] https://kotaku.com/helldivers-2-friendly-fire-always-on-arrowhead-ps5-pc-1851329269 · [HD3] https://gamesradar.com/helldivers-2s-friendly-fire-will-never-change-because-if-it-did-the-devs-would-have-to-turn-off-bullet-damage-against-enemies-as-well · [HD4] https://pcgamer.com/games/third-person-shooter/helldivers-2s-friendly-fire-and-killer-bugs-show-the-fragility-of-humans-and-are-also-just-funny-creative-director-says · [HD5] https://steamcommunity.com/app/394510/discussions/0/135511027321969177 · [HD6] https://pcgamer.com/games/third-person-shooter/helldivers-2-has-more-players-than-the-population-of-sweden-making-it-playstations-fastest-selling-game-of-all-time · [HD8] https://blog.playstation.com/?p=388965

**Hazelight** — [IT1] https://www.avclub.com/josef-fares-it-takes-two-interview · [IT2] https://www.theringer.com/2021/4/22/22396763/josef-fares-it-takes-two-interview-co-op-gaming · [IT3] https://www.unrealengine.com/developer-interviews/it-takes-two-lovingly-marries-story-and-gameplay-together · [IT4] https://pcgamer.com/games/action/split-fiction-sells-1-million-copies-over-2-days · [IT5] https://www.gematsu.com/2025/05/split-fiction-sales-top-four-million · [IT6] https://gamesradar.com/games/co-op/split-fiction-blows-it-takes-two-out-of-the-water-by-selling-1-million-copies-in-2-days-becoming-hazelights-fastest-selling-game-ever

**Overcooked** — [O1] https://gamedeveloper.com/design/road-to-the-igf-ghost-town-games-i-overcooked-i- · [O3] https://pcgamer.com/how-overcookeds-tiny-team-took-over-our-living-rooms · [O4] https://www.pushsquare.com/news/2018/08/interview_chewing_the_fat_with_overcooked_2_developer_ghost_town_games

**Hades e pipelines de arte** — [HA1] https://gamedeveloper.com/art/learn-how-supergiant-brought-i-hades-i-hand-painted-characters-to-life · [HA2] https://dtf.ru/id64954/238431-sozdanie-materi-nochi-process-modelirovaniya-nikty-iz-hades · [HA3] https://steamcommunity.com/app/1145360/discussions/0/1738883810796606862 · [HA4] https://80.lv/articles/a-behind-the-scenes-look-at-the-effects-in-hades · [HA5] https://kotaku.com/the-art-of-hades-1845443438 e https://mcvuk.com/business-news/behind-the-art-of-hades-we-value-artistic-integrity-and-excellence-in-artistic-craft-at-supergiant-however-were-first-and-foremost-a-game-design-lead-team/ · [HA6] https://nex-3.com/blog/hades-ii-has-a-legibility-problem/ · [HA7] https://steamcommunity.com/app/1145350/discussions/0/591769824782233841 · [HA8] https://www.pcgamesn.com/hades-2/critic-review-scores-expedition-33 · [HA9] https://www.ggrecon.com/articles/hades-2-players-have-a-massive-problem-with-the-chronos-boss-battle/ · [HA10] https://medium.com/@Nat.Rowley/how-hades-creates-a-responsive-underworld-915715a7c2a · [DC1] https://www.jikguard.com/news/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-dead-cells e https://80.lv/articles/case-study-dead-cells-character-art-pipeline

**Outros jogos** — [X1] https://www.pcgamer.com/games/action/rotwood-early-access-launch · [X2] https://www.gematsu.com/2026/03/rotwood-now-available-for-switch-2-pc · [X3] https://forums.kleientertainment.com/forums/topic/150962-the-camera-holds-you-hostage-a-lot-of-the-time/ · [X4] https://forums.kleientertainment.com/forums/topic/157200-what-is-rotwood/ · [X5] https://www.pcgamer.com/games/action/absolum-review , https://www.thesixthaxis.com/2025/10/09/absolum-review/ e https://psu.com/reviews/absolum-ps5-review · [X6] https://www.co-optimus.com/review/2521/page/1/sworn-co-op-review.html , https://rogueliker.com/sworn-review/ e https://www.thesixthaxis.com/?p=464049 · [X7] https://www.co-optimus.com/review/2439/page/1/tmnt-shredder-s-revenge-co-op-review.html · [X8] https://www.thesixthaxis.com/2026/07/10/33-immortals-review/ e https://store.epicgames.com/news/how-33-immortals-nails-a-33-player-roguelike · [X9] https://opencritic.com/news/12094/you-can-revive-teammates-in-elden-ring-nightreign-by-attacking-them , https://automaton-media.com/en/news/elden-ring-nightreigns-devs-thought-it-looked-funny-to-revive-teammates-by-attacking-them/ , https://www.pcgamer.com/games/rpg/elden-rings-first-major-patch-sees-fromsoft-belatedly-admit-singleplayer-is-all-sorts-of-unfair-adds-an-auto-resurrect-and-buffs-the-levelling-curve e https://www.pcgamer.com/games/action/singleplayer-elden-ring-nightreign-is-no-longer-hell-to-play-but-its-still-a-compromised-game-of-30-minute-boss-runbacks · [X10] https://gamesbeat.com/dragons-crown-review/2 · [X11] https://www.pcgamer.com/games/2025-was-the-year-friendslop-reigned-and-so-many-low-cost-ways-to-have-fun-with-your-pals-couldnt-have-come-at-a-better-time , https://appmagic.rocks/blog/friendslop-steam-games-2025 e https://www.avclub.com/not-every-co-op-game-is-friendslop · [X12] https://store.epicgames.com/news/combine-the-power-of-the-elements-in-spellbreak · [X13] https://dotesports.com/genshin-impact/guides/elemental-reactions-explainer · [X14] https://pcgamer.com/deep-rock-galactic-review e https://gamerant.com/deep-rock-galactic-interview-season-1-co-op-design-battle-pass-progression/ · [X15] https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf e https://developer.valvesoftware.com/wiki/Left_4_Dead_Design_Theory · [X16] https://www.thesixthaxis.com/2026/04/28/the-spell-brigade-review-a-co-op-survivors-like-thats-all-about-the-grind/ e https://opencritic.com/game/18951/- · [X17] https://store.steampowered.com/app/3543070

**Textos de design** — [D1] https://gamedeveloper.com/design/co-op-revive-mechanics · [D2] https://bigosaur.com/blog/165-soaw-death · [D3] https://co-optimus.com/editorial/976/page/3/indie-ana-co-op-and-the-dev-stories-you-re-all-in-this-together.html · [D4] https://www.gamedeveloper.com/business/the-challenges-of-cooperative-game-design · [D5] https://www.co-optimus.com/article/5783/splinter-cell-conviction-s-co-op-design-core-principles-to-encourage-co-op-behavior.html · [D6] palestra GDC 2015, Kevin Martens, "Those that Slay Together: A Co-op Manifesto": https://gdcvault.com/play/1022336/Those-that-Slay-Together-A (conteúdo não lido) · [D7] palestra GDC Next 2013, Amy Jo Kim, "Co-op First: 10 Rules": https://gdcvault.com/play/1019662/Co-op-First-10-Rules (conteúdo não lido) · [D8] https://nexus.leagueoflegends.com/en-us/2017/10/dev-leagues-vfx-style-guide/ , https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/ e https://www.vfxapprentice.com/blog/10-league-of-legends-vfx-design-tips · [D9] https://gamedeveloper.com/design/shared-multi-split-screen-design · [D10] https://pandaqi.itch.io/package-party/devlog/105217/9-camera-kung-fu · [D11] https://www.pcgamer.com/wows-telegraphs-are-so-cluttered-that-even-the-best-guild-in-the-world-is-using-darkening-potions-during-raids-so-they-can-fight-more-effectively

## 12. Pontos não verificados ou em aberto

- Nenhuma página foi lida na íntegra; citações vêm de trechos do buscador. Conferir os artigos-chave ([M1], [F1], [HA1], [D8]) quando a rede permitir.
- Itens marcados (nv) nas tabelas e fichas: durações de sessão da maioria dos jogos, detalhes de reviver de Lost Castle 1, Nine Parchments e WoL2, existência de fogo amigo em vários títulos, câmera de Gauntlet e Full Metal Furies, estrutura exata de It Takes Two.
- Lost Castle 2: data da 1.0 aparece como 10 e como 11 de junho de 2026; nota agregada de crítica não confirmada; uma fonte fala em 3 jogadores e as demais em 4.
- Ravenswatch: número de Penas do Corvo (5 ou 6) e de ciclos dia/noite variam entre fontes e versões.
- Windblown: não confirmei se a 1.0 saiu nem se a "morte súbita" foi alterada.
- Wizard of Legend 2: média de crítica (~85) veio de um resumo do OpenCritic e contrasta com o "Misto" do Steam; desenvolvedora Dead Mage é conhecimento meu, o buscador não confirmou.
- Castle Crashers: vendas totais atuais não confirmadas.
- Hades: o número de 942.489 quadros veio de um trecho atribuído a uma sessão de perguntas com a diretora de arte Jen Zee; não confirmei em qual das duas páginas de [HA5] ele está.
- Cordels & Spells: o identificador do aplicativo na URL [X17] foi deduzido da lista de resultados, não conferido na página.
- Nightreign: o teto de 3 segmentos na barra de reviver vem do relato de um guia, não de documentação oficial.
- Risk of Rain 2: fórmula exata de escalonamento por jogador não recuperada.
- Vendas de R.E.P.O. e Peak são estimativas de terceiros.
- A afirmação "não há sucessor de Magicka em 2025–2026" vale para o que as buscas mostraram; pode existir projeto não indexado.
- Fora do tema desta pesquisa, mas decisivo para escolher mecânicas: como o co-op será entregue (mesmo aparelho, rede local, online pelo navegador) e o que o renderizador Compatibility aguenta em efeitos.

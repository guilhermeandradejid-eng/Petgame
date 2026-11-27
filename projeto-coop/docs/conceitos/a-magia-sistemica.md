# Conceito A: magia sistêmica — "Rejunte"

Documento de conceito, 27/11/2026. Ângulo: magia combinada entre jogadores no estilo Magicka, com câmera alta, fogo amigo cômico e ambiente sistêmico. **Nada aqui está decidido.** É uma proposta para o usuário comparar com os outros conceitos antes de qualquer execução.

Marcas usadas: **[pesquisa]** = está comprovado num relatório de `docs/pesquisa/`; **[busca]** = conferido por busca na web nesta etapa; **[proposta]** = decisão de design minha, a validar em teste.

---

## 1. Nome, frase de venda e fantasia do jogador

### Nome: **Rejunte**

"Rejunte" é a massa que fica entre os azulejos e os mantém presos na parede. No jogo, os heróis são exatamente isso: o que segura a cidade inteira. A palavra é curta, brasileira sem ser regional e carrega o tema do co-op (sozinho, um azulejo cai; juntos, formam o painel).

Conferência de nome [busca, 27/11/2026]: buscas por "Rejunte", "Cacos de Cobalto" e "Caco a Caco" como jogo não acharam nenhum título. "Craquelê" e "Salitre" também estão livres. **"Fornada" foi descartado**: existe "Fornada D'Pancada", um jogo de padaria. A busca não prova que não exista nada com o nome. Antes de publicar, é preciso conferir no INPI e nas lojas. Nome reserva: *Cacos de Cobalto*.

Descoberta importante na mesma busca: **Kiln**, da Double Fine (publicado pela Xbox, 2026), é um brawler multijogador de **cerâmica de torno** com esmaltes ([Xbox Wire](https://news.xbox.com/en-us/2026/01/22/kiln-developer-direct-double-fine-hands-on-preview/), [PC Gamer](https://www.pcgamer.com/games/action/create-beautiful-pots-and-use-them-to-smash-your-friends-to-pieces-in-double-fines-new-online-multiplayer-pottery-party-brawler/)). Por isso este conceito **não usa vaso, torno nem forno** como identidade. A linguagem é a do **azulejo pintado**: superfície plana, pincelada de cobalto, painel figurativo e grade de ladrilhos. Na busca por jogo de ação com estética de azulejo, só apareceu um jogo de memória (Twin Tile) [busca].

### Frase de venda

> **"Um co-op de 1 a 4 onde o chão é de azulejo e cada azulejo lembra o que você jogou nele: molhe, unte, sopre e eletrifique uma cidade portuária inteira, de preferência sem eletrocutar o amigo."**

Versão curta para loja: *"Você molha, eu eletrifico. Às vezes, você também."*

### Fantasia do jogador

Você é uma **figura pintada de um painel de azulejos** que se descolou da parede para salvar a sua cidade. Seu corpo é de louça branca pintada a pincel de cobalto e você trinca, lasca e se desmonta em cacos quando apanha. Sua magia é física e honesta: água escorre e faz poça, óleo boia, fogo corre com o vento, faísca segue a água. A graça não é decorar combinações. É olhar para o chão, ver uma poça enorme com três inimigos dentro e o seu amigo no meio, e decidir se vale a pena.

---

## 2. Ciclo de jogo

| Escala | Duração | O que acontece |
|---|---|---|
| **30 segundos** | 20 a 40 s | **Preparar → detonar → reposicionar.** Um jogador espalha um estado no chão ou nos inimigos (molhado, untado). Outro detona com a matéria certa (faísca, brasa). Todos saem da área que vai pegar fogo, recolhem cacos e leem a próxima telegrafia. |
| **Uma sala** | 60 a 120 s | Arena de 18 × 12 a 24 × 16 m com **fontes de matéria no cenário** (chafariz, barril de óleo, garrafa de faísca, janela de vento). Duas ou três ondas. A sala termina quando o último inimigo cai e um **painel de recompensa** se monta na parede: 3 azulejos de padrão para escolher. |
| **Uma expedição** | **14 a 18 min** | 5 a 7 salas num grafo curto com bifurcação (sala de risco, sala de loja, sala de descanso), mais o chefe do bioma. O mapa é um painel de azulejos na parede da taberna, que se "pinta" conforme o grupo avança. |
| **Meta-progressão** | entre expedições | O **Painel da Taberna do Polvo** (o hub) está quebrado. Os cacos pintados ganhos nas expedições restauram trechos dele. Cada trecho restaurado libera um herói, uma matéria secundária, novos padrões no sorteio ou uma pintura cosmética. O progresso fica **visível na parede**, não num menu. |
| **Sessão típica** | 20 a 40 min | Uma ou duas expedições. Cabe no "vamos jogar uma rapidinha" do celular e no sofá. |

Fases geradas por regra, como em `extra-geracao-de-fases-por-codigo.md` [pesquisa]: o código **gera a ordem e o recheio**, não a arena inteira. Cada bioma tem 10 a 14 "moldes" de sala feitos por script, espelháveis, com pontos de encaixe para fontes de matéria e ondas.

---

## 3. Co-op

### 3.1 O que só existe porque há 2 a 4 pessoas

1. **Reações cruzadas valem mais.** Uma reação montada por dois jogadores diferentes dá **+25% de efeito** e enche o **medidor de Rejunte** do grupo. A mesma reação montada sozinho (com a própria matéria secundária) é mais lenta, porque a secundária tem recarga.
2. **"Banho" (fogo amigo construtivo).** Acertar um aliado com a sua matéria **unta a mão dele**: o próximo arremesso dele leva a sua matéria junto e explode como reação no alvo. Acertar o amigo de propósito vira técnica, com risco: ele leva 30% do dano.
3. **Reações duplas.** Duas pessoas lançando a **mesma** matéria no mesmo lugar, com até 0,4 s de diferença, criam uma versão maior (Brasa + Brasa = Fornalha; Faísca + Faísca = Corrente). Só acontece com duas mãos.
4. **Proteção pela física.** Untar o amigo com óleo o deixa **isolado**: ele não toma a condução elétrica da poça. Um protege, outro eletrifica a água com o primeiro dentro.
5. **Carregar e arremessar.** Qualquer herói pega barris, baldes, garrafas de faísca e **o próprio aliado** (2 s de fôlego). Jogar o Bento untado de óleo dentro de um grupo de inimigos e o Seu Galvão acender: é o tipo de história que o jogo quer produzir.
6. **Medidor de Rejunte → Painel.** Cheio (cerca de 12 reações cruzadas), qualquer um ativa e os outros têm 1,5 s para entrar. Cada herói que entra acrescenta sua figura ao golpe (seção 9, efeito 7). Com 4 pessoas, o golpe é 4 vezes mais largo.
7. **Chefe que pede divisão de tarefas.** Na fase 2 do chefe, alguém precisa atrair a pintura para a água enquanto outro eletrifica (seção 4.5).

Nada disso é trava dura. Todo inimigo morre com qualquer matéria; as reações só fazem morrer **mais rápido e de forma mais divertida**. É a lição de Full Metal Furies contra Deep Rock Galactic [pesquisa: `jogos-referencia.md` §4].

### 3.2 Sozinho

O primeiro contato do usuário provavelmente será solo, no celular [pesquisa: `extra-contexto-real-celular-coop.md`]. Por isso o solo é um modo de primeira classe:

- **Dupla obrigatória no solo:** você escolhe 2 heróis. Um é controlado por você; o outro, por IA (Beehave). O parceiro de IA **prepara e você detona**, a regra recomendada em `coop-rede.md` §6.2 [pesquisa].
- **Troca de controle a qualquer momento** (botão Trocar, 0,3 s, no estilo Full Metal Furies): você assume o outro herói e a IA passa a cuidar do primeiro. Assim dá para montar reação cruzada sozinho, no seu ritmo.
- **Comando de um botão ("ping")**: tocar num inimigo = "prepara esse"; tocar no chão = "vem cá"; segurar = "combo agora" (a IA gasta a habilidade no alvo).
- **Fogo amigo da IA contra você: zero.** O seu contra ela: normal, e ela reage com fala e pose cômica, nunca com rancor.
- Escala de inimigos no solo: vida × 0,55 em relação à dupla e uma onda a menos por sala.
- **1 autorremendo por sala**: ao cair, você volta sozinho em 3 s se a IA não chegar antes.

### 3.3 Local no mesmo aparelho

- **PC/TV com controles, 1 a 4** (cenário S4 de `extra-contexto-real-celular-coop.md` [pesquisa]): câmera única que enquadra o grupo (Phantom Camera em modo GROUP, testado no 4.7.2 com 4 alvos [pesquisa: `extra-pilha-unica-godot-4-7.md` §2.3]), zoom entre 0,85 e 1,15, centro ponderado e **bolha de retorno**: quem fica 2 s fora do quadro é puxado de volta como um caco que quica até o grupo.
- **Celular/tablet:** 1 jogador no toque e, se houver controle Bluetooth, um segundo no controle. Mais que isso no mesmo celular não é realista [pesquisa].
- **Entra e sai a quente:** apertar um botão num controle novo faz aparecer um azulejo em branco na parede, que vira o herói escolhido. Se alguém sai, o herói dele vira IA até o fim da sala.

### 3.4 Caminho para o online

A arquitetura nasce online desde o primeiro dia, mesmo que a rede só entre no marco 2:

- **Host autoritativo com entradas por jogador.** Teclado, controle, toque, IA e peer remoto passam pela mesma interface de "intenção de entrada" [pesquisa: `extra-contexto-real-celular-coop.md` §6].
- **O estado do chão é uma grade de células de 0,5 m** (até 48 × 32 = 1.536 células por sala). Cada célula cabe em 1 byte (molhado, untado, em chamas, eletrificado, salitrado, mais intensidade). Mudanças vão por delta, com um quadro completo de no máximo 1,5 KB a cada segundo. É barato de replicar, o que é raro em jogo sistêmico.
- **Reações calculadas só no host**, por tick de física (30 Hz). O cliente mostra uma prévia só cosmética até o host confirmar. Janela de combinação **≥ 250 ms**, que cobre o RTT de ~150 ms estimado entre celulares [pesquisa: `extra-contexto-real-celular-coop.md` §5.1].
- **Transporte:** WebRTC no navegador (host + 3 clientes testado em estrela, 300/300 snapshots [pesquisa]) e ENet no desktop. Mais tarde, Steam Remote Play Together para o co-op local do PC.
- **Câmera individual no online**: cada aparelho segue o próprio herói.
- **Host em segundo plano congela o jogo para todos** [pesquisa]: pausa automática com o aviso "esperando quem abriu a sala" no evento `visibilitychange`.

### 3.5 Fogo amigo

| Situação | Regra [proposta] |
|---|---|
| Dano de matéria em aliado | 30% do normal (opções: 0, 30, 60, 100%). Online: 30% fixo por padrão, com **favor da vítima**: só conta se o host também vê o aliado dentro da área [pesquisa: `extra-contexto-real-celular-coop.md` §5.2] |
| Empurrão, estado e reação em aliado | **Sempre valem por completo.** Molhar, untar, empurrar para a poça e eletrocutar o amigo é a comédia do jogo. O dano é baixo; a consequência física é inteira |
| Choque em aliado | Atordoa 0,6 s (inimigo: 1 s) com a pose "negativo" (seção 9, efeito 1) |
| Reação que mata aliado | Ele vira cacos normalmente, mas o placar de fim de sala registra: "Galvão eletrocutou Bento 3 vezes" (rivalidade leve, sem punição) |
| Telegrafia | Toda área de reação desenha a borda no chão **300 ms antes** de detonar, inclusive para aliados |

### 3.6 Morte e reviver

- **Cair = virar cacos.** O herói se desmonta em 8 pedaços de azulejo; o caco do rosto quica por último e fica olhando para cima.
- **O morto continua jogando como "Caco-mestre"**: o caco do rosto pula pelo chão (velocidade 70%) com dois verbos. *Marcar*: pinta um X de cobalto num inimigo, que passa a levar +15% de dano de reação. *Chamar*: pula até um aliado e corta o tempo de reviver dele pela metade. É a oportunidade de "morte como segundo modo" apontada em `jogos-referencia.md` §6 [pesquisa].
- **Reviver ("rejuntar")**: ficar em cima dos cacos segurando Interagir por 1,5 s. Cada nova queda na mesma sala acrescenta +1 s. **Atalho sistêmico:** jogar Maré nos cacos revive na hora, com 40% de vida. Água cola o rejunte.
- **Marca visível**: o herói revivido fica com uma linha de rejunte cinza atravessando o corpo até o fim da sala. Dá para ver quem caiu mais.
- **Grupo inteiro em cacos**: uma vez por expedição, o **Remendo de Grupo** devolve todos ao começo da sala com 50% de vida. Na segunda vez, a expedição termina e o grupo **mantém 60% dos cacos ganhos**.

### 3.7 Saque

- **Cacos pintados** (moeda): vão para um **cofre comum** do grupo. Ninguém disputa.
- **Azulejos de padrão** (relíquias que mudam regras): ao fim de cada sala, cada jogador vê **o seu próprio painel de 3** (saque instanciado [pesquisa: `jogos-referencia.md` §5.6]). Exemplo: "Ponta de Diamante — a condução também salta por óleo"; "Estrela e Cruz — vapor cega por 2 s a mais"; "Folha Torta — seu empurrão unta quem você empurra".
- **Padrões de grupo** (1 a cada 2 salas): afetam todos e são votados pisando no azulejo; o empate se resolve por sorteio.
- **Loja da sala de descanso:** o azulejeiro ambulante troca cacos por reroll, cura ou padrão.

---

## 4. Combate e sistemas

### 4.1 Verbos do jogador

| Verbo | O que faz | Números iniciais [proposta] |
|---|---|---|
| Andar | 5,5 m/s | Aceleração em 4 quadros, freada em 6 (para ter peso sem atrasar) |
| **Arremesso** (toque na matéria principal) | Bola de matéria que cai no ponto mirado e cria estado no chão | Alcance 9 m, área 1,5 m, 12 de dano, cadência 0,45 s |
| **Jato** (segurar a matéria principal) | Cone ou feixe contínuo que aplica estado no que tocar | Alcance 5 m, 20 de dano/s, anda a 55% da velocidade |
| **Matéria secundária** | Uma forma só (arremesso), escolhida no começo da expedição | Recarga 6 s |
| **Habilidade de herói** | Golpe-assinatura de cada um (seção 5) | Recarga 12 a 18 s |
| Esquiva | Rolagem curta com invencibilidade | 3,5 m, 14 quadros, invencível do 2º ao 9º |
| **Empurrão** | Ombrada sem dano | Joga a 1,5 m. Funciona em inimigos, aliados e barris |
| Interagir / carregar | Pegar barril, balde, garrafa, aliado; abrir comporta; reviver | Arremesso de objeto a 7 m |

Não há fila de elementos na mão. A fila é a assinatura de Magicka e é difícil no controle e pior no toque [pesquisa: `jogos-referencia.md` §7, mecânica 2]. Aqui **cada herói tem uma matéria fixa** e a combinação acontece **no mundo**, entre heróis, no chão e nos inimigos.

### 4.2 As 5 matérias

| Matéria | Cor (óxido de azulejo) | Estado que deixa | Herói nativo |
|---|---|---|---|
| **Brasa** | Laranja-ferro | *Em brasa* (3 s, 8 dano/s); acende óleo | Tia Lamparina |
| **Maré** (água salgada) | Verde-cobre | *Molhado* (6 s) e *poça* no chão (12 s) | Bento Rodo |
| **Lufada** (vento) | Branco-leite com borda roxo-manganês | Empurra 3 m; desloca nuvens, chamas e manchas | Nina Catavento |
| **Faísca** | Amarelo-antimônio | *Carregado* (2 s): o próximo dano recebido salta para 1 vizinho | Seu Galvão |
| **Óleo** | Castanho-manganês com borda furta-cor | *Untado* (8 s, −30% de velocidade, inflamável, isolante) | Nenhum (só como secundária) |

A paleta das matérias é a paleta histórica dos **cinco óxidos do azulejo** (cobalto fica para o mundo; ferro, cobre, antimônio e manganês vão para a magia). Assim, a regra de cor não é arbitrária: a matéria tem a cor do pigmento que a representaria num painel.

O **Salitre** é a matéria do inimigo: uma crosta branca granulada que cobre chão e inimigos, cura os Descascados e bloqueia reações em cima dela. Os jogadores não usam salitre, mas reagem com ele.

### 4.3 Matriz de reações: 17 no total

**10 cruzadas (pares diferentes):**

| # | Par | Reação | Efeito |
|---|---|---|---|
| 1 | Brasa + Maré | **Vapor** | Nuvem de 3 × 3 células por 4 s. Quem está dentro perde e não ganha alvo. Sem dano. Lufada empurra a nuvem |
| 2 | Brasa + Lufada | **Labareda** | O fogo corre 2 células/s na direção do vento por 3 s, com dano de fogo × 1,5 |
| 3 | Brasa + Faísca | **Estalo** | Explosão de 1,5 m, 30 de dano e empurrão de 2 m |
| 4 | Brasa + Óleo | **Incêndio** | O óleo acende em cadeia a 6 células/s e queima por 6 s, com 12 de dano/s. A maior reação de área |
| 5 | Maré + Lufada | **Ressaca** | Onda pintada de 4 m que empurra tudo ao longo da água e apaga fogo |
| 6 | Maré + Faísca | **Condução** | Toda célula molhada conectada e toda entidade molhada nela leva 40 de dano e atordoamento de 1 s. Limite de 60 células. **Pega aliados** |
| 7 | Maré + Óleo | **Mancha** | O óleo boia e se espalha por toda a poça (até 40 células). Prepara um incêndio gigante |
| 8 | Lufada + Faísca | **Arco viajante** | Bola elétrica que deriva com o vento por 4 s e dá choque de 15 em quem estiver a até 1,5 m, a cada 0,5 s |
| 9 | Lufada + Óleo | **Borrifo** | Cone de 6 m que unta todos os inimigos atingidos |
| 10 | Faísca + Óleo | **Isolante** | Quem está untado fica imune à Condução. É defensiva: unte o amigo antes de eletrificar a poça |

**5 duplas (mesma matéria de dois jogadores com até 0,4 s de diferença):** Brasa + Brasa = **Fornalha** (chão em chamas pelo dobro do tempo); Maré + Maré = **Alagar** (poça 2× maior); Lufada + Lufada = **Redemoinho** (puxa em vez de empurrar, por 2 s); Faísca + Faísca = **Corrente** (salta entre 6 alvos); Óleo + Óleo = **Piche** (prende no lugar por 1,5 s).

**2 com o Salitre:** Salitre + Brasa = **Estouro de salitre** (60 de dano em 2 m, arranca a armadura; o salitre de verdade é ingrediente de pólvora); Salitre + Maré = **Dissolver** (tira a armadura devagar, em 3 s, sem risco para o grupo).

São 15 células na matriz de pares, o tamanho que `jogos-referencia.md` considera produzível com qualidade por um agente, mais 2 reações de inimigo [pesquisa]. Cada reação é **um efeito visual e um som próprios**, sem variantes.

### 4.4 Ambiente sistêmico

- **Fogo espalha:** caixotes, redes, cordas, lona e fardos de algodão queimam e passam fogo à célula vizinha a cada 0,5 s, se ela for inflamável ou estiver untada.
- **Água conduz:** poças são conectadas por flood fill na grade. O choque segue o **rejunte** dos azulejos molhados, que serve de leitura visual e de regra.
- **Vento empurra:** janelas e becos têm **corrente de vento** fixa, marcada por roupas no varal e fumaça. Ela desloca nuvens, chamas e o óleo que boia.
- **Fontes de matéria no cenário:** chafariz (Maré infinita, só com o Bento ou com balde), barril de óleo (arremessável; estoura em mancha de 3 × 3), garrafa de Leyden (Faísca de 3 cargas), fogareiro (Brasa) e comporta de maré (inunda metade da sala).
- **Marcas que ficam:** azulejo queimado escurece com craquelado até o fim da sala; o óleo deixa brilho furta-cor; o salitre deixa crosta. A sala conta o que aconteceu nela.

### 4.5 Inimigos: os Descascados

Inimigos são **azulejos que o Salitre arrancou das paredes** e remontou errado. Telegrafia padronizada: toda ameaça desenha no chão uma forma em **vermelho-lacre**, a única cor do jogo fora da paleta de óxidos, reservada só para perigo [pesquisa: `jogos-referencia.md` §5.1]. Tempos a 60 fps, dentro da faixa de 400 a 700 ms de `animacao-principios.md` [pesquisa].

| Arquétipo | Forma e papel | Vida | Telegrafia | Resposta que ensina |
|---|---|---|---|---|
| **Lasca** | Cachos de 3 a 5 cacos que pulam em bando (6 a 10 por onda) | 20 | Agacha 24 quadros; as bordas dos cacos piscam vermelho; avança 3 m | Área: Condução, Incêndio. Ensina que uma poça bem colocada vale mais que mira |
| **Ladrilheiro Torto** | Um painel de 2 × 1 m que anda em pé, como uma porta; frente imune | 80 | Ergue o painel em 36 quadros; um retângulo vermelho de 2 × 1 m no chão; despenca | Lufada ou empurrão o viram de costas; molhar e eletrificar por trás |
| **Carranca** | Boca de chafariz de louça, fixa ou lenta; cospe água salgada em arco | 40 | Bochechas incham em 30 quadros; um arco vermelho até o círculo de queda | **Inimigo que ajuda sem querer**: as poças que ele cria servem para a sua Condução |
| **Crosta** | Brutamontes coberto de cristais de salitre; armadura de 70% enquanto está salitrado | 160 | Os cristais brilham vermelho por 42 quadros; pancada no chão em círculo de 3 m | Escolha de risco: Brasa faz o Estouro (rápido, empurra aliados por perto) ou Maré dissolve (lento, seguro) |
| **Caiador** | Figura magra com balde e brocha que pinta faixas de salitre no chão | 50 | Arrasta a brocha por 30 quadros; a linha vermelha mostra onde a faixa vai nascer | Prioridade: o salitre dele cura os outros e bloqueia reações. Ensina a escolher alvo |

Escala por número de jogadores: primeiro quantidade e composição (mais Lascas, mais um Caiador), depois vida com retorno decrescente (2p ×1, 3p ×1,3, 4p ×1,55). Atordoamento nunca escala [pesquisa: `coop-rede.md` §7].

### 4.6 Chefe: **A Fachada que Andou**

Fim do bioma 4, no pátio do Palacete Branco. A fachada inteira do palacete, um painel de azulejos de 12 m com a pintura de uma "Senhora das Ondas" segurando um barco, está tomada de salitre. Ela se descola da parede como um tapete que se levanta e vira criatura: o painel curvo é o corpo, as grades das sacadas são os braços e o rosto pintado fica no centro. São cerca de 400 azulejos, animados como instâncias (MultiMesh).

**Arena:** pátio de 20 × 14 m com chafariz central (Maré), 4 postes de lampião com barril de óleo, canaletas de drenagem e o portão para o mar a leste.

**Entrada (sem controle do jogador, 6 s):** os azulejos da fachada estalam um a um, de baixo para cima, com o som subindo de tom. A pintura da Senhora vira o rosto para a câmera e pisca, um único quadro segurado de 4 quadros. O painel se descola num arco lento (slow in) e cai para a frente, parando a 1 m do chão (slow out e overshoot).

**Fase 1 — Salitrada (100% a 65%).** Armadura de 70% em três zonas (braço esquerdo, braço direito e rosto).
- *Varredura*: o painel varre um terço do pátio como uma onda. Telegrafia: faixa vermelha de 54 quadros com uma fresta segura. Resposta: esquivar pela fresta.
- *Chuva de cacos*: 12 azulejos caem do alto em círculos vermelhos de 40 quadros.
- *Caiação*: pinta duas faixas de salitre no chão que cortam a arena.
- **Para quebrar cada zona:** Estouro (Brasa no salitre, rápido mas empurra quem está perto) ou Dissolver (Maré por 3 s, seguro). Um barril de óleo jogado no braço e aceso é a resposta mais forte. Com as três zonas quebradas, a Fachada cambaleia (12 s vulnerável, dano × 2).

**Fase 2 — Rachada (65% a 30%).** A Fachada mergulha no chafariz e **alaga o pátio**: 70% do chão vira poça. A **pintura da Senhora sai do painel** e passa a deslizar pelo chão e pelas paredes, de azulejo em azulejo, como uma figura 2D pintada (um shader desloca a pintura pela grade).
- Ela só leva dano **enquanto está pintada no chão molhado**.
- Telegrafia: uma ondulação e o contorno vermelho do lugar onde ela vai emergir (48 quadros), seguidos de um golpe de remo em linha.
- **Divisão de tarefas:** um jogador fica perto da borda para atraí-la (ela persegue quem estiver mais longe da água). Outro eletrifica a poça quando ela emerge. Quem estiver na água leva o choque junto, a menos que alguém o tenha untado (Isolante).
- O corpo do painel, no chafariz, solta *Maré alta* a cada 10 s: uma onda que empurra todos 4 m para oeste.

**Fase 3 — Desmoronando (30% a 0%).** O painel se parte. Os pedaços formam um anel que fecha a arena em 20% a cada 20 s. O portão do mar se abre, e uma **rajada de vento** varre o pátio de leste para oeste a cada 8 s, com aviso de roupas voando 1 s antes. No centro fica exposto o **Coração de Salitre**: o salitre reage a Brasa com Estouro, e a rajada transforma qualquer fogo em Labareda na direção dele. O grupo aprende a usar o ambiente contra o chefe: acender no lado leste e deixar o vento levar.

**Golpe final:** hit-stop de 30 quadros (o limite de Smash citado em `animacao-principios.md` [pesquisa]), a tela inteira segura e os 400 azulejos explodem para o alto em câmera lenta. Eles caem como chuva e **se assentam sozinhos no chão do pátio, formando um painel novo**: a figura dos heróis que participaram, na pose do último golpe. Essa imagem vira o troféu do hub.

Vida: 3.000 com 2 jogadores (solo 1.650; 4 jogadores 4.650). Duração-alvo: 4 a 6 minutos.

---

## 5. Heróis

Os quatro saem do mesmo painel quebrado da Taberna do Polvo. Não há heróis repetidos num grupo, então **herói = jogador**, o que resolve a identidade com 4 pessoas por construção. Proporção comum de 2,5 cabeças, mãos de luva com 3 dedos e olhos pintados [pesquisa: `direcao-de-arte.md` §5.2, sinal 8].

### Tia Lamparina (Brasa)

- **Silhueta:** pera larga, base pesada, avental enorme e uma lamparina de cabo longo apoiada no ombro. É um triângulo com a ponta para cima.
- **Personalidade:** cozinheira da taberna, mandona, calorosa e impaciente. Fala alto e decide pelo grupo.
- **Kit:** Arremesso de panelinha em brasa; Jato do bico da lamparina; **Tampa de Tacho** (habilidade): bate a tampa no chão e abre um anel de fogo de 3 m que empurra para fora.
- **Animação que expressa isso:** tudo nela tem peso e atraso. O avental chega 4 a 6 quadros depois do corpo (follow-through com osso de mola). Ao pousar da esquiva, faz squash de 0,8 e segura 3 quadros. Na espera, bate o pé em ritmo impaciente; depois de 6 s parada, cruza os braços. Seu golpe tem a antecipação mais curta do elenco (3 quadros): ela não espera ninguém.

### Bento Rodo (Maré)

- **Silhueta:** linha vertical alta e fina com um rodo em T e um balde pendurado. É a figura mais alta do elenco.
- **Personalidade:** lavador de calçada obcecado por limpeza, educado e meticuloso. Reclama de toda sujeira (inclusive do óleo que os outros jogam).
- **Kit:** Arremesso de balde (poça de 3 × 3); Jato de mangueira; **Esfregão** (habilidade): desliza 8 m sobre o chão molhado empurrando tudo que estiver na frente, como surfe.
- **Animação:** precisão e arcos limpos. Membros finos com ação sobreposta delicada. Gira o rodo em arco perfeito antes de cada golpe. Ao deslizar, mantém a pose de bailarino sem tremer. Quando fica untado de óleo, a única vez em que perde a compostura, sacode o corpo inteiro em straight ahead, desordenado de propósito.

### Nina Catavento (Lufada)

- **Silhueta:** pequena e redonda, com um cata-vento gigante preso às costas. São dois círculos, um pequeno embaixo e um grande em cima, a forma mais fácil de achar na tela.
- **Personalidade:** criança do cais, hiperativa e travessa. É a maior fonte de fogo amigo do grupo e não sente culpa nenhuma.
- **Kit:** Arremesso de "bolha de ar" que estoura empurrando para fora; Jato de rajada em cone; **Rodopio** (habilidade): vira um redemoinho de 3 s que **carrega junto** a nuvem, chama ou mancha que tocar.
- **Animação:** a mais elástica do elenco. Squash e stretch até 0,7 / 1,35 (com volume preservado), antecipação quase nula e muita ação secundária: o cata-vento gira na velocidade dela e para com overshoot. É o único herói animado "em um" nos golpes, porque a sua energia não cabe em poses seguradas.

### Seu Galvão (Faísca)

- **Silhueta:** velho faroleiro corcunda com uma garrafa de Leyden nas costas e uma vareta de cobre alta. É um ponto de interrogação.
- **Personalidade:** rabugento, seco, distraído. Esquece o que estava fazendo no meio da frase.
- **Kit:** Arremesso de faísca (salta para o alvo molhado mais próximo num raio de 3 m); Jato de arco contínuo; **Para-raios** (habilidade): finca a vareta, que atrai toda Faísca da sala e descarrega na poça mais próxima a cada 1 s, por 6 s.
- **Animação:** contraste de timing. Lento para se preparar (slow in exagerado, quase cochilando) e um estalo súbito de 2 quadros no golpe. Os cabelos ficam em pé por 10 quadros depois de cada descarga. Nos golpes elétricos, alterna poses seguradas com quadros únicos de tremor, um ritmo "quebrado" que é dele.

---

## 6. Mundo, biomas, tom e história

**Porto Cobalto** é uma cidade portuária inventada, de ladeiras, cais e fachadas inteiramente cobertas de azulejo. Ali, as figuras pintadas nos painéis guardam as casas. Uma névoa do mar trouxe o **Salitre**: uma crosta branca que come o rejunte, descola os azulejos e os remonta como Descascados. Quatro figuras de um painel rachado da taberna se descolam da parede para rejuntar a cidade antes que ela inteira caia no mar.

**Tom:** comédia de bairro portuário. Falas curtas, implicância entre os heróis, perigo de verdade sem crueldade. Nada de cangaço, sertão, rima ou forró, e nenhuma figura histórica ou colonial. A inspiração vem da **técnica** do azulejo (painel figurativo, padrão de repetição, figura de convite), não de uma cidade ou época real.

| Bioma | Visual (período de pintura) | Novidade de sistema |
|---|---|---|
| **1. Cais da Salga** | Azul e branco puro. Madeira de cais, redes, barris de peixe salgado (óleo), armazéns de azulejo | **Maré que sobe e desce** a cada 40 s e alaga metade da sala: a Condução fica enorme e perigosa |
| **2. Lavadouro da Fonte Grande** | Azul e amarelo de padrão estampilhado. Tanques, canaletas, lençóis no varal | **Comportas** que o grupo abre e fecha; sabão (escorregadio, empurrões levam o dobro); lençóis que queimam e abrem linha de visão |
| **3. Fábrica de Ladrilhos** | Policromado (verde-cobre, manganês). Pilhas de ladrilho cru, tonéis de esmalte, vagonetes em trilho | **Vagonetes** que o vento empurra pelos trilhos, como projéteis do ambiente; pilhas que desabam e criam cobertura |
| **4. Palacete Branco** | Quase todo branco de salitre, com o azul aparecendo só onde o grupo limpa | **Salitre em toda parte**: o Estouro é a ferramenta e o risco. Termina na Fachada que Andou |

---

## 7. Direção de arte: "Azulejo de corpo inteiro"

### 7.1 Linguagem visual

Três famílias de material, e só três:

1. **Faiança pintada** (mundo e heróis): esmalte branco-estanho levemente quente, nunca branco puro, com pintura a pincel de **cobalto em três valores** (aguado, médio e azul-noite). Cada azulejo tem 14 cm, como os reais. A cada 0,5 m, um módulo de 4 × 4 azulejos coincide com uma célula da simulação.
2. **Materiais do porto** (madeira de cais, corda, lona, ferro): castanhos e cinzas foscos de baixa saturação, sem pintura.
3. **Salitre** (inimigo): branco-acinzentado **granulado e fosco**. É o único branco sobre branco. Ele se separa do esmalte pela textura: o esmalte é liso e brilha, o salitre é áspero e apagado.

Os heróis são **faiança figurativa em volume**: corpo branco, pintura de cobalto que segue a forma (dobras do avental, cabelo, rosto) e **um único acento** no óxido da sua matéria. Os Descascados são cacos de azulejo com a borda quebrada mostrando o biscoito por dentro, num bege rosado.

### 7.2 Paleta

| Papel | Cores | Regra |
|---|---|---|
| Mundo | Branco-estanho (L 0,93 em OKLCH), cobalto em 3 valores, biscoito bege, 4 neutros do porto | Cerca de 80% da tela. Saturação ≤ 0,12, exceto o cobalto |
| Magia e interativos | Laranja-ferro, verde-cobre, amarelo-antimônio, castanho-manganês, branco-leite com borda roxa | **"Se tem cor quente, interage."** Nenhuma decoração estática usa essas cores |
| Perigo | Vermelho-lacre | Só telegrafia de inimigo. Nenhum efeito de jogador pode usar |
| Total | 22 cores em OKLCH | Dentro do limite de 24 do contrato anti-slop [pesquisa: `direcao-de-arte.md` §5.4] |

A legibilidade vem da construção: o mundo é frio e quase monocromático, e a magia é quente e saturada. O fogo laranja sobre azulejo azul é complementar. A Maré verde-cobre se separa do cobalto pelo matiz e pelas linhas de espuma brancas.

### 7.3 Regras anti-slop específicas deste estilo

1. **Toda pintura é pincelada com começo, corpo e fim.** O gerador de pincel (numpy) simula a carga de tinta: o traço começa carregado, afina e deixa uma **poça de pigmento** onde o pincel para. Nada de linha de largura constante.
2. **Dois processos históricos, dois geradores.** Padrões de repetição são **estampilhados** (molde vazado: borda nítida, pequeno erro de registro de 1 a 2 px entre cores). Painéis figurativos são **pintados à mão livre** (traço variável). Não existe um terceiro "estilo azulejo" genérico.
3. **12 matrizes de padrão, não ornamento aleatório.** Cada padrão de piso e parede deriva de uma de 12 estruturas geométricas (ponta de diamante, estrela e cruz, maçaroca, folha em quadrante etc.), com variação de pincel por azulejo, a partir de uma semente fixa.
4. **Assentamento imperfeito com causa.** Cada azulejo tem desvio de ±1 mm e ±0,8° e uma **inclinação de normal de até 1,5°**. É o que faz o azulejo de verdade refletir a luz em mosaico. O brilho especular varia por azulejo e cintila quando a câmera anda.
5. **Desgaste só onde há tráfego.** Lascas nas quinas de degrau, rejunte escurecido perto do chão, salitre subindo da base das paredes (como a umidade de verdade). Nunca ruído uniforme.
6. **Painéis contam cenas de verdade** (feira de peixe, barco na tempestade, procissão de lanternas), compostas por regra de primeiro plano, meio e fundo. **Todo texto pintado é texto real** ("Taberna do Polvo", "Rua da Salga"), numa fonte de licença OFL pintada com o mesmo pincel.
7. **Uma luz-chave para o jogo inteiro:** sol de fim de tarde vindo de sudoeste a 50°. A sombra nunca é preta: ela multiplica por cobalto.
8. **Proibido:** degradê liso (faz faixas no RGBA8 da Web [pesquisa]), brilho plástico em tudo (o especular existe só no esmalte, numa faixa toon com tamanho fixo), primitiva padrão sem chanfro e céu ou partícula com valor padrão do motor.
9. **Teste automático:** em toda captura, ≤ 2% dos pixels fora da paleta (sem contar VFX) e ≤ 2% dos pixels do mundo com saturação acima de 0,15.

### 7.4 Por que não parece arte gerada

A arte gerada por IA de "azulejo" costuma ser uma textura plana com ornamento que não se repete direito, pincel sem pressão e cobalto em degradê. Aqui, cada imagem sai de um **processo físico simulado** (carga do pincel, molde vazado, assentamento, desgaste por tráfego). O padrão obedece a uma geometria real de repetição, a luz tem uma só direção e o próprio chão **muda com o jogo** (molhado, queimado, salitrado). Isso é autoria por regra, que é a defesa que `direcao-de-arte.md` §5 recomenda [pesquisa]. A restrição radical também é declarada: **o mundo é azul e branco, e só a magia tem cor**.

### 7.5 Câmera

- Inclinação de 52°, FOV de 30° (quase teleobjetiva, pouca distorção, para a grade do chão ler como mapa) e distância de cerca de 22 m.
- Um herói de 1,4 m ocupa cerca de 60 a 70 px CSS de altura num celular de 412 px CSS, a mesma faixa da conta em `extra-contexto-real-celular-coop.md` §4 [pesquisa].
- Local: enquadramento de grupo com zoom limitado. Online: câmera individual.
- Só no desktop (Forward+): desfoque leve nas bordas de cima e de baixo (15% da tela) para dar escala de maquete. Na Web, o desfoque fica desligado ou usa o shader caseiro já validado [pesquisa: `direcao-de-arte.md` §2.2, achado 5].

---

## 8. Animação pelos 12 princípios

### 8.1 Exemplos por princípio

| Princípio | Heróis | Inimigos | Chefe |
|---|---|---|---|
| **1. Squash and stretch** | Nina: 0,7 no pouso e 1,35 no salto da esquiva. Lamparina: 0,8 segurado por 3 quadros ao pousar. **Volume sempre preservado** (sx = sz = 1/√sy) | Lascas não esticam (são de louça): fazem "squash de rachadura", com 2 quadros de compressão e uma trinca desenhada | O painel inteiro faz squash de 0,9 ao bater no chão, com uma onda que percorre os 400 azulejos |
| **2. Antecipação** | Curta: 3 a 6 quadros nos golpes leves [pesquisa: `animacao-principios.md` §1]. Galvão é a exceção cômica: antecipação lenta na habilidade (20 quadros), compensada pelo estalo | Longa e legível: 24 a 42 quadros (Lasca, Crosta), sincronizada com a telegrafia | Varredura com 54 quadros: o painel se curva para trás antes de varrer |
| **3. Encenação** | Toda pose de golpe é lida de cima: braço e matéria abertos para fora do corpo, nunca à frente do rosto | O Ladrilheiro se vira de frente para a câmera ao erguer o painel, para a leitura ser inconfundível | A entrada de 6 s é encenada com a pintura virando o rosto para a câmera |
| **4. Straight ahead e pose a pose** | Golpes são pose a pose (chaves fortes, quebras CONSTANT). A sacudida do Bento quando untado é straight ahead | Pose a pose em 3s, que dá o "clac-clac" de azulejo | Desmoronamento da fase 3 é straight ahead simulado (física dos azulejos em MultiMesh) |
| **5. Continuidade e ação sobreposta** | Avental da Lamparina, balde do Bento, cata-vento da Nina e garrafa do Galvão chegam 4 a 8 quadros depois do corpo (`SpringBoneSimulator3D` [pesquisa]) | Cacos soltos da Lasca continuam quicando 6 quadros depois que ela para | Grades das sacadas (braços) oscilam depois de cada golpe |
| **6. Slow in e slow out** | Locomoção com aceleração em 4 quadros e freada em 6. Golpe com saída rápida (ease-out forte) e recuperação lenta | A Crosta acelera lento e freia de repente, porque é pesada demais para frear suave | Descolar da parede em arco lento com overshoot de 1 m |
| **7. Arcos** | O rodo do Bento traça arco perfeito antes do golpe. Os arremessos têm parábola visível com sombra-bolha no chão | O cuspe da Carranca tem arco desenhado pela telegrafia | A pintura da Senhora salta de parede para chão em arco |
| **8. Ação secundária** | Lamparina tamborila os dedos na lamparina, o Galvão coça a orelha com a vareta e a Nina gira o cata-vento com o dedo | O Caiador sacode a brocha antes de pintar | O rosto pintado pisca e acompanha o jogador mais próximo (`LookAtModifier3D` [pesquisa]) |
| **9. Timing** | Cada herói tem tempo próprio: Lamparina rápida e pesada, Bento regular, Nina frenética, Galvão lento com estalo | Lasca rápida, Crosta lenta. A diferença de timing é a leitura de ameaça | Fase 3 acelera 15% a cada 20 s junto com o anel que fecha |
| **10. Exagero** | Remontagem depois do reviver: os cacos se juntam **errado** por 4 quadros (cabeça de ponta-cabeça) e se corrigem com um "plim" | A Carranca incha as bochechas a 1,6 vez do tamanho | O golpe final segura 30 quadros |
| **11. Desenho sólido** | Volumes simples e chanfrados que leem de cima em qualquer rotação. A revisão gira todo modelo em 360° [pesquisa: `direcao-de-arte.md` §5.2, sinal 11] | Cacos com espessura real (1,2 cm em escala), nunca planos sem volume | O painel tem espessura de reboco atrás, visível quando se curva |
| **12. Apelo** | Rosto pintado de 3 traços (dois olhos e uma boca) que troca de pintura por expressão (8 expressões por herói) | Descascados com rosto "errado": a pintura original do azulejo remontada torta | A Senhora das Ondas é bonita, e por isso a cena final dá pena e satisfação |

### 8.2 Taxa de poses

- **Blender e importador a 60 fps, otimizador de animação desligado**, como fixado em `extra-pilha-unica-godot-4-7.md` §3 [pesquisa]. Pose de impacto com hold mínimo de 2 quadros em CONSTANT, para aparecer mesmo se o celular cair para 30 fps.
- **Heróis:** locomoção interpolada (60). Golpes em 2s (30 poses/s, chaves CONSTANT). Nina em 1s nos golpes.
- **Descascados:** em 3s (20 poses/s), com degraus. A rigidez de azulejo vem do próprio degrau.
- **Chefe:** corpo em 4s (15 poses/s) para dar peso. A onda dos 400 azulejos é procedural, a 60.
- **Pincel "fervendo"** (o contorno pintado que treme de leve) a 8 fps; VFX e câmera a 60. Opção de desligar a fervura nas configurações.

### 8.3 O que é Blender e o que é Godot em tempo real

| Blender (bpy, sem tela) | Godot 4.7.2 em tempo real |
|---|---|
| Modelos dos heróis (Skin modifier + Subsurf + bevel, cerca de 6 mil triângulos) e dos inimigos (2 a 3 mil) [pesquisa: `pipeline-blender.md` §1] | `AnimationTree` com mistura de locomoção e golpes |
| Rig próprio de cerca de 22 ossos com osso de escala para squash | Ossos de mola (avental, balde, cata-vento, garrafa), `LookAtModifier3D` no rosto |
| Todos os clipes-chave: andar, correr, esquiva, 2 formas de lançar, habilidade, dano, queda em cacos, remontagem e 8 expressões | Smear por shader de vértice ao longo da velocidade (funciona no Compatibility [pesquisa]) |
| **Pré-fratura** de cada herói e inimigo em 8 a 12 cacos (bisect por planos em bmesh; o addon Cell Fracture depende do site de extensões, que é bloqueado) | Hit-stop **local** (congela atacante e alvo, não o jogo) [pesquisa: `animacao-principios.md` §11.4] |
| Texturas pintadas: o gerador de pincel e de estampilha roda em numpy, e o Blender só aplica e faz bake de oclusão no vértice | Grade de estados do chão como **textura de dados** de 64 × 64 que o shader do piso lê (molhado, untado, fogo, choque, salitre) |
| Painel do chefe como 400 azulejos com pivôs | MultiMesh do chefe e dos cacos: onda, desmoronamento e remontagem |
| | Deslizar a pintura da Senhora pela grade (shader de UV no piso e nas paredes) |

---

## 9. VFX e game juice: 9 efeitos-assinatura

1. **Condução.** A poça escurece e ganha brilho. Um raio amarelo-antimônio **corre pelas linhas de rejunte** dos azulejos molhados, em grade, de célula em célula, a partir do ponto do choque. Cada inimigo atingido trava 4 quadros. Por 2 quadros, a pintura de cobalto de quem levou o choque (aliado incluído) **inverte para amarelo**, como um negativo. Som: estalo seco que se desloca no estéreo seguindo o raio, mais um "zzt" curto por vítima.
2. **Incêndio de óleo.** A frente de fogo avança célula por célula, num "fuuump" em cadeia com o tom subindo. As chamas são pinceladas laranjas animadas em flipbook de 8 quadros, não partículas redondas. O azulejo embaixo fica com **craquelado queimado** até o fim da sala.
3. **Vapor.** Nasce uma nuvem desenhada **como as nuvens dos painéis de azulejo**: cúmulo branco com contorno de cobalto, que incha em 6 quadros e se desfaz em fiapos. Os inimigos dentro viram a cabeça de um lado para o outro, perdidos. Som: chiado agudo que abafa a música em 30% enquanto você está dentro.
4. **Estouro de salitre.** Os cristais brancos piscam 6 quadros e explodem num anel de lascas de sal, com **trauma de câmera** médio. Som: "pop" grave com estalo de cristal e uma chuva fina de tilintar.
5. **Ressaca.** Uma **onda pintada** de painel (crista enrolada, traço de cobalto, espuma branca) rola pelo chão e empurra tudo. As células que ela cobre ficam molhadas. Som: arrebentação e um grasnado de gaivota a cada 3 ondas (sem repetir o mesmo arquivo seguido).
6. **Cair em cacos.** O herói se parte em 8 cacos que quicam com física. O rosto quica por último e para olhando para cima. Hit-stop de 8 quadros e um "plim" de louça. A **remontagem** puxa os cacos de volta em arco, monta errado por 4 quadros e corrige com um estalo.
7. **Painel (golpe de Rejunte).** A câmera sobe 15%. Os azulejos do chão viram como dominós numa onda a partir de quem ativou e formam um **mural de cobalto gigante** com as figuras dos heróis que entraram. As figuras pintadas então "correm" pelo chão como desenho 2D e acertam tudo na linha. Som: um acorde que soma o tema curto de cada herói participante.
8. **Golpe em Descascado.** Um caco voa, uma **trinca de cobalto** é desenhada na hora sobre o azulejo do inimigo e há hit-stop de 3 quadros. Som: "tink" de louça com o tom variando pelo tamanho do caco (grande = grave).
9. **Onda de brilho.** Em toda reação grande, um anel de reflexo especular percorre os azulejos do chão a partir do centro. É o "raio" da reação desenhado pela própria luz do esmalte. Custa um anel no shader do piso, sem partícula.

### Legibilidade com 4 jogadores

- **Cor tem função:** óxidos = matéria; vermelho-lacre = perigo inimigo; cobalto e branco = mundo. Nenhuma exceção.
- **Estados do chão com forma, não só cor:** molhado = brilho e linhas de ondulação; untado = borda furta-cor; fogo = pincelada vertical; choque = rejunte aceso; salitre = textura granulada. Funciona com daltonismo.
- **Efeitos de aliados com 60% de opacidade** para quem não lançou; efeito de jogador some em ≤ 0,6 s (só estados de chão duram mais) [pesquisa: `jogos-referencia.md` §5.1].
- **Orçamento de partículas na Web:** 80 por jogador e 160 para inimigos e ambiente. Os efeitos-assinatura são majoritariamente **shader de piso**, não partícula, e é aí que o estilo economiza.
- **Anel do jogador:** cada herói tem um anel de azulejo no chão com número e padrão próprio (listra, ponto, xadrez, onda).

---

## 10. Som e música

1. Todo impacto é **louça**: tilintar, estalo, trinca e "plim", gerados por síntese modal em numpy e afinados numa escala, para que o caos de 4 jogadores soe como percussão e não como ruído.
2. A música é uma **banda de coreto de porto** (metais, caixa, bombo) com uma **marimba de azulejos afinados**, longe de fado, forró e trilha épica genérica.
3. Ela é adaptativa em camadas: exploração só com marimba; combate com metais; e cada reação cruzada dispara um **floreio curto no tom da música**, para que combinar soe bem.
4. Cada herói tem um motivo de 4 notas (Lamparina na tuba, Bento no clarinete, Nina no flautim, Galvão no trombone com surdina), que se somam no golpe Painel.
5. O ambiente vive da cidade: gaivotas, cordame, água em canaleta e o **chiado do salitre crescendo**, que serve de aviso sonoro de área perigosa.

---

## 11. Controles

Uma camada só de entrada com G.U.I.D.E 0.15.1 para teclado, controle, toque e remapeamento (testado no 4.7.2, inclusive multitoque na Web) [pesquisa: `extra-pilha-unica-godot-4-7.md` §2.5].

| Ação | Teclado e mouse | Controle | Toque (paisagem) |
|---|---|---|---|
| Mover | WASD | Analógico esquerdo | Metade esquerda: direcional dinâmico (aparece onde o polegar encosta) |
| Mirar | Mouse | Analógico direito (com mira assistida leve) | Mira automática; arrastar o botão principal para mirar à mão |
| Matéria principal | Botão esquerdo: toque = Arremesso, segurar = Jato | RT: toque e segurar | Botão grande (Ø 110 px): tocar = Arremesso no alvo automático; arrastar e soltar = mirado; segurar parado 0,25 s = Jato |
| Matéria secundária | Botão direito | LT | Botão em arco acima do principal |
| Habilidade | F | Y / Triângulo | Botão em arco à esquerda do principal |
| Esquiva | Espaço | A / X (PS) | Botão separado, maior que as habilidades |
| Empurrão | Q | B / Círculo | Botão em arco; vira **Interagir/Reviver** quando há algo por perto |
| Interagir / carregar / reviver | E | X / Quadrado | Contextual, no lugar do empurrão |
| Ping (comando à IA) | R ou botão do meio | RB | Tocar num inimigo ou no chão com dois dedos |
| Trocar de herói (solo) | Tab | LB | Retrato do parceiro no canto (tocar) |

No toque são **4 botões de ação mais a esquiva**, o limite recomendado para o polegar [pesquisa: `coop-rede.md` §5.1]. Como não há fila de elementos, o toque não perde profundidade: a profundidade está no chão.

---

## 12. Fatia vertical e marcos

### Fatia vertical: "Cais da Salga, maré baixa"

O menor pedaço que prova o jogo é **combinar no chão, entre dois heróis, com fogo amigo engraçado, legível no celular**.

| Item | Conteúdo exato |
|---|---|
| Heróis | **Tia Lamparina (Brasa) e Bento Rodo (Maré)**, completos em modelo, rig, clipes e expressões |
| Matérias | 4: Brasa, Maré, Faísca e Óleo. As duas últimas como secundárias, para o par montar as 6 reações entre elas |
| Reações | 6 cruzadas (Vapor, Estalo, Incêndio, Condução, Mancha, Isolante) + Fornalha + Alagar + Estouro de salitre = **9** |
| Inimigos | 3: Lasca, Ladrilheiro Torto e Crosta |
| Salas | 3 moldes de sala do Cais (uma com a maré que sobe), em sequência fixa |
| Chefe | **Fase 1 da Fachada** numa versão menor (o "Painel do Armazém", 150 azulejos, 1.200 de vida, 2 ataques e as 3 zonas de salitre) |
| Co-op | Solo com IA e troca; 2 locais no PC (controles); toque no celular |
| Morte | Cacos, Caco-mestre, rejuntar e reviver por Maré |
| VFX | Efeitos 1, 2, 3, 4, 6, 8 e 9 |
| Builds | Web (Compatibility) e desktop (Forward+) a partir do mesmo projeto |
| Critérios de aprovação | 30 fps estáveis no celular do usuário com 3D a 70%; ≥ 4 reações cruzadas por minuto num teste de 10 min; numa captura com 2 heróis e 15 inimigos, um observador acha o próprio herói em menos de 1 s; ao menos um "lembra quando..." por sessão |

### Marcos depois da fatia

1. **Marco 2 — Grupo completo (bioma 1 e 2):** os 4 heróis, as 5 matérias com as 17 reações, os 5 inimigos, o Lavadouro, o Painel da Taberna como hub de meta-progressão, os azulejos de padrão e o **online de 2 jogadores** por WebRTC (sala por código, GitHub Pages e sinalização própria).
2. **Marco 3 — Expedição inteira:** os 4 biomas, a Fachada que Andou completa nas 3 fases, o golpe Painel, o online de 4 com TURN e reconexão (o herói de quem caiu vira IA), e o balanceamento por número de jogadores.
3. **Marco 4 — Acabamento:** modos de rejogo (padrões "amaldiçoados" que mudam regras, como Magicka 2 fazia com artefatos [pesquisa]), cosméticos de pintura, acessibilidade (fervura desligável, daltonismo, fogo amigo 0%), trilha completa e build desktop para Steam com Remote Play Together.

---

## 13. Viabilidade neste pipeline

### O que a pesquisa já comprova

- **Pilha inteira no 4.7.2:** addons fixados, import com 0 erros, Compatibility, Forward+ e Web testados [pesquisa: `extra-pilha-unica-godot-4-7.md`].
- **Squash e degrau de animação chegam exatos ao Godot** com 60 fps e o otimizador desligado [pesquisa]. Os poses segurados do estilo (heróis em 2s, inimigos em 3s) têm caminho testado.
- **Toque multidedo na Web** pelo G.U.I.D.E [pesquisa].
- **WebRTC com host no navegador e 4 jogadores** [pesquisa]; o estado em grade deste conceito é mais leve que os snapshots de 440 bytes testados.
- **Shaders no material funcionam igual nos dois renderers** [pesquisa: `direcao-de-arte.md` §2.2]. Este estilo é quase todo material: cor chapada, pincel em textura, especular toon por azulejo e contorno por casca invertida.
- **Phantom Camera em grupo de 4** [pesquisa]; Beehave para a IA [pesquisa].

### O que ainda é risco (precisa de prova de estilo)

- **Qualidade do pincel procedural.** É o ativo que decide se o jogo parece autoral ou genérico. Precisa de uma prova de estilo antes de tudo: um painel figurativo de 2 × 1 m e um piso estampilhado, comparados lado a lado com 3 referências reais de azulejo.
- **Cintilação do especular por azulejo** em resolução reduzida no celular (serrilhado ou "chuvisco"). A mitigação planejada é esmaecer o brilho com a distância e limitar a variação de normal.
- **Grade visível demais** (cara de tabuleiro). Os estados do chão precisam de borda irregular que siga o rejunte com ruído, não quadrados perfeitos.
- **Pré-fratura por script**, sem o Cell Fracture.
- **Legibilidade de 4 heróis brancos sobre mundo branco e azul.** O contorno escuro de cobalto e o acento de óxido devem resolver; precisa do teste de borrão e do de miniatura do contrato anti-slop.

### Custo de render na Web (estimativa a validar no aparelho)

| Item | Custo estimado [proposta] | Base |
|---|---|---|
| Piso da sala inteira | 1 a 4 draw calls (quad grande com shader procedural de azulejo + textura de estado de 64 × 64 atualizada a 30 Hz, cerca de 16 KB por atualização) | Não existe um azulejo como geometria: são até 57 mil azulejos de 14 cm, desenhados só no shader |
| Paredes e painéis | 20 a 40 draw calls; painéis em atlas de 2048² gerado em numpy | Memória de vídeo medida de 36 a 52 MB numa cena parecida [pesquisa] |
| Heróis | 4 × cerca de 6 mil triângulos **com** contorno por casca | O contorno por stencil dobrou os triângulos no teste; usar só em heróis e chefe [pesquisa] |
| Inimigos | 15 a 20 × 2 a 3 mil triângulos, **sem contorno** (rim escuro) | Ondas de 20 visíveis como padrão [pesquisa] |
| Cacos e chefe | MultiMesh: 400 instâncias numa draw call | — |
| Luz | 1 direcional **sem sombra** + sombra-bolha pintada como mancha de cobalto. **O brilho do fogo vem do shader do piso lendo a grade**, não de luzes omni | Sombra real custou +64% [pesquisa]; Compatibility aceita só 8 luzes por malha [pesquisa] |
| Resolução | 3D a 70% (`scaling_3d_scale`), DPR efetivo ≤ 1,5, HUD nítido | −31% de tempo de quadro em DPR alto [pesquisa] |
| Alvo | 30 fps travados no celular de entrada; 60 no desktop | Faixa do Galaxy A06 / Mali-G52 [pesquisa] |

O estilo é **barato por natureza**: um mundo de cor chapada, pouca geometria e efeitos no piso cai do lado bom de todas as medições do teste de estresse. O número real ainda depende do usuário rodar o teste publicado no celular dele.

---

## 14. Riscos e como mitigar

| Risco | Probabilidade | Mitigação |
|---|---|---|
| **Parecer clone de Magicka** | Média | Sem fila de elementos; matéria por herói; combinação no chão em grade; mundo, nomes e personagens próprios. Nesse ponto, o parente mais próximo nem é Magicka: são as superfícies no chão de RPGs táticos como Divinity: Original Sin, aqui levadas para ação em tempo real |
| **Parecer derivado de Kiln** (cerâmica, 2026) | Baixa a média | Nada de vaso, torno ou forno. Linguagem de azulejo plano e painel pintado; PvE co-op, não PvP de arena |
| **Caos ilegível com 4 jogadores** | Alta | Regras de cor fechadas, estados com forma, opacidade de aliado, orçamento de partículas, telegrafia de 300 ms nas reações e testes de captura no portão de revisão |
| **Fogo amigo frustrante** | Média | Dano de 30%, reviver de 1,5 s, reviver instantâneo por Maré, Isolante como defesa, opção 0%. O risco vira técnica (Banho), não só punição |
| **Solo sem graça** | Média | Dupla obrigatória com IA que prepara, troca de controle e 1 autorremendo por sala. O solo é testado já na fatia |
| **Monotonia de azul e branco em 4 biomas** | Média | Cada bioma muda de período de pintura (azul e branco, azul e amarelo, policromado, branco de salitre) e de sistema próprio (maré, comporta, vagonete, salitre) |
| **Pincel procedural fraco** | Alta (é o maior risco de arte) | Prova de estilo antes de qualquer outra coisa; comparação com referências reais; parar se não passar |
| **Grade com cara de tabuleiro** | Média | Borda dos estados com ruído ao longo do rejunte; animação de espalhar contínua no shader, mesmo com a lógica discreta |
| **Desempenho no celular de entrada** | Média | Sem sombra real, sem luzes dinâmicas, contorno só em heróis, efeitos no shader do piso e 3D a 70%. Medir na fatia com o teste publicado |
| **Online instável no celular** (host em segundo plano, CGNAT) | Alta se o usuário quiser cada um no seu celular | Host autoritativo desde o início, pausa automática, TURN no marco 3, reações só no host com janela de 250 ms |
| **Sensibilidade cultural** (azulejo e passado colonial) | Baixa | Cidade inventada, nenhuma figura histórica, inspiração só na técnica. Os painéis mostram a vida do porto inventado |
| **Escopo de 17 reações × 5 inimigos × 4 biomas** | Média | A fatia prova 9 reações; cada reação nova só entra com efeito e som prontos. O conteúdo cresce por moldes de sala gerados por regra, não por fases feitas à mão |
| **Nome registrado por outro** | Baixa | Conferir no INPI e nas lojas antes de divulgar; o nome reserva é *Cacos de Cobalto* |

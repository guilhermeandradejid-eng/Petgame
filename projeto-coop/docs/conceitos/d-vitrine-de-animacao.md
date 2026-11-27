# Conceito D: vitrine de animação — "Lumaréu"

Documento de conceito, 27/11/2026. Ângulo: **o curinga, o conceito que mais exibe animação de nível AAA**. A pergunta que guia tudo aqui é: que jogo faz um pipeline 100% por código (bpy, numpy, GDScript) parecer animado à mão por um estúdio grande, também no celular?

**Nada aqui está decidido.** É uma proposta para o usuário comparar com os outros conceitos antes de qualquer execução.

Marcas usadas:
- **[pesquisa]**: comprovado num relatório de `docs/pesquisa/` (o arquivo vem citado).
- **[busca]**: conferido por busca na web nesta etapa.
- **[proposta]**: decisão de design minha, a validar em protótipo.
- **[risco]**: ainda não testado e pode derrubar a ideia.

---

## Por que esta direção e não outra

Considerei as quatro linguagens sugeridas e escolhi **silhueta e brilho**, com um desvio importante: aqui a luz não é decoração. **Os heróis são as fontes de luz, e a sombra é uma peça do combate.**

| Linguagem | Por que não foi a escolhida |
|---|---|
| Papercraft, origami, pop-up | A moldura de livro que se abre é justamente o que mais elogiam em Cordels & Spells (`extra-diferenciacao-cordels-and-spells.md`, item 3). Além disso, o terreno já é de Tearaway e Hirogami |
| Massinha e stop motion | É ótima para squash and stretch, mas o nicho de "brawler co-op de argila" já tem Clodhoppers (Claymatic Games, até 8 jogadores, 2021) e Knuckle Creek (mesma equipe, 2026). Clay Rumbles sai em 2027 [busca]. Também perde a translucidez na Web, que não tem SSS, e as marcas de dedo somem na tela de 6 polegadas [pesquisa: `direcao-de-arte.md` 2.1 e 6.2] |
| Azulejo | Já é o conceito A ("Rejunte") |
| **Silhueta e brilho** | **Escolhida.** Três motivos: (1) sem textura para esconder defeitos, **a pose e o tempo carregam tudo**, e a animação vira o centro do jogo; (2) é a linguagem mais barata no Compatibility: sem contorno por stencil, sem sombra real e com material quase sem luz; (3) silhueta escura contra luz forte é o contraste que melhor sobrevive numa tela pequena |

O argumento central da vitrine é este: **neste jogo, cada animação aparece até três vezes**. Aparece no corpo do personagem, na sombra dele no chão e, em certas fases, na sombra projetada em lençóis estendidos. Cada pose bem-feita rende o triplo, e cada pose fraca também se denuncia três vezes. Isso obriga e recompensa a disciplina dos 12 princípios.

---

## 1. Nome, frase de venda e fantasia do jogador

### Nome: **Lumaréu**

"Lumaréu" é uma palavra do português para **fogueira grande, clarão, muitas luzes juntas**. No jogo, o Lumaréu é a fogueira da vila que os heróis precisam manter acesa durante a Noite Comprida. Também é o que acontece quando quatro jogadores juntam as luzes: um clarão.

**Conferência de nome** [busca, 27/11/2026]:
- "Lumaréu" e "Lumareu" com Steam, itch.io e lojas de aplicativo não devolveram nenhum jogo.
- O nome mais parecido é **Lumara**, um quebra-cabeça 2D sobre um peixe-lanterna, ainda não lançado na Steam ([Steam](https://store.steampowered.com/app/4064840)). O som é próximo, mas o gênero, o tema e a escrita são diferentes. Ainda assim, convém registrar isso como risco de confusão em busca.
- Ressalva: a Steam é bloqueada neste ambiente, e a busca cobre só o que o buscador indexou. Antes de publicar, é preciso conferir no INPI e nas lojas a partir de outra rede.
- Nome reserva (não conferido): *Prego de Sombra*.

**Vizinhos de tema encontrados na mesma busca**, e como este conceito se afasta deles:
- **Lanterns** (bullet-heaven aconchegante para 1 ou 2 jogadores, feito em Godot 4): um Guardião, um enxame de mariposas e "a luz suave que segura a noite" ([site](https://lanterns-site.pages.dev/)). **Por isso este conceito não usa mariposas.** Os inimigos aqui são coisas que apagam a luz (sopro, abafador, goteira, fuligem, bocejo), não coisas atraídas por ela.
- **Schatte the Witch and the Fake Shadow**: a bruxa trava o inimigo pisando na sombra dele ([VGDB](https://www.vgdb.co/games/schatte-the-witch-and-the-fake-shadow)). O gesto de "pregar a sombra" é um motivo de folclore antigo, e lá ele é solo. Aqui a mecânica é **geométrica e cooperativa**: uma pessoa posiciona a luz, a outra prega, e duas luzes criam duas sombras.
- **Sky e Journey** (figuras de capa que brilham): este conceito evita capa luminosa e "criança de luz". Os heróis são criaturas atarracadas e cômicas, de formas geométricas, com uma lanterna própria.

### Frase de venda

> **"A noite quer dormir para sempre, e vocês são as últimas luzes acesas: um co-op de 1 a 4 em que a sua lanterna projeta a sombra do inimigo e o seu amigo prega essa sombra no chão."**

Versão curta para a loja: *"Eu acendo, você prega."*

### Fantasia do jogador

Você é **uma luz que anda**. Seu corpo é uma silhueta escura, cômica e expressiva, e dentro dele mora uma chama que reage a tudo: ela encolhe quando você leva um susto, estala quando você golpeia, se inclina quando o vento chega e quase apaga quando você apanha. Lá fora está a Noite Comprida, cheia de criaturas sonolentas que só querem soprar, abafar e pingar em cima de cada chama até o mundo inteiro dormir.

O prazer central não é decorar combos. É **ler a luz**. Você olha para o chão, vê a sombra comprida de um inimigo apontando para a sua amiga e grita "prega!". Ela finca a sombra, o inimigo congela no meio do pulo, e vocês dois descem a lanterna nele.

---

## 2. Ciclo de jogo

### 30 segundos

1. Um **Bochecha** começa a inflar. Todas as chamas da sala se inclinam na direção dele, e a música perde os agudos.
2. Você se afasta do sopro e, ao mesmo tempo, **ergue a lanterna** do lado oposto ao de um **Abafador**. A sombra do Abafador se estica pelo chão até os pés da sua parceira.
3. Ela aperta atacar em cima da sombra: **pregou**. O Abafador congela com um tremor.
4. Você corre, bate três vezes com a lanterna na corrente, e o Abafador estoura em fuligem.
5. O Bochecha sopra no vazio, murcha, e fica 2 segundos mole no chão. Vocês dois batem nele.

O ciclo de 30 segundos é sempre **posicionar a luz, ler a sombra, pregar, punir, desviar da telegrafia**.

### Uma sala (60 a 90 segundos)

- Arena de cerca de 18 × 12 m, com cantos escuros e de 2 a 4 **lampadários apagados**.
- **Acender um lampadário** custa 10% da sua chama e cria uma fonte de luz fixa. Ela faz duas coisas: dá uma zona segura e cria um ângulo novo de sombra para pregar. A sala é um quebra-cabeça leve de geometria de luz.
- De 2 a 3 ondas de inimigos. Ao final, a sala libera uma **brasa** (moeda da expedição) e, às vezes, uma escolha de **pavio** (modificador, ver 4.4).

### Uma expedição (12 a 16 minutos)

- Um bioma tem 6 salas de combate, 1 sala de descanso (troca de pavios, recarga da chama) e 1 sala de guardião.
- O mapa é um caminho com bifurcações curtas, gerado por regra (`extra-geracao-de-fases-por-codigo.md`). Cada bifurcação mostra o que vem: uma sala mais escura (mais brasas, menos lampadários) ou uma sala mais clara (mais segura).
- A expedição termina na volta à vila, com as brasas depositadas no Lumaréu.

### A Noite inteira (cerca de 50 minutos, salva entre biomas)

São três biomas seguidos e o chefe final, o **Fole**, na Forja Fria. O progresso salva ao fim de cada bioma, porque no celular a sessão real é de 15 minutos.

### Meta-progressão: o Lumaréu cresce

- As brasas alimentam a fogueira central da vila, que tem **10 estágios**. A cada estágio, **a vila fica literalmente mais clara**: janelas se acendem, ruas aparecem, vizinhos saem de casa. A progressão é visível, não uma tela de números.
- O que cada estágio libera:

| Estágio | O que libera |
|---|---|
| 1 | Pavios novos no sorteio (8 → 12) |
| 2 | Heroína **Lumeira** |
| 3 | Bioma Varal dos Lençóis |
| 4 | Herói **Seu Farolete** |
| 5 | Oficina de lata: o jogador desenha o padrão de furos da própria lanterna (cosmético, gerado por regra) |
| 6 | Bioma Chaminés de Breu |
| 7 | Pavios novos (12 → 24) |
| 8 | Segunda arma para cada herói |
| 9 | Forja Fria (chefe final) |
| 10 | Modo "Noite sem Lua": salas mais escuras, inimigos mais rápidos, Lumaréu de ouro |

- Nada da meta-progressão aumenta dano de forma permanente. Ela abre opções e conteúdo. Isso mantém o equilíbrio entre amigos com tempos de jogo diferentes.

**Duração de sessão:** 15 minutos (uma expedição) é a unidade pensada para o celular. 50 minutos é a Noite inteira, para sofá ou PC.

---

## 3. Co-op

### 3.1 O que só existe porque há 2 a 4 pessoas

Todas as mecânicas abaixo dependem de **posição**, não de tempo exato. Isso é proposital: posição tolera 150 ms de latência, e tempo exato não (`extra-contexto-real-celular-coop.md`, seção 5.2).

1. **Pregar a sombra.** A sombra de um inimigo aponta para longe da luz mais forte perto dele. A sua própria luz joga a sombra para longe de você. **A luz do seu amigo joga a sombra na sua direção.** Pregar sozinho é possível, mas exige dar a volta no inimigo. Em dupla, é natural: um ilumina, o outro prega.
2. **Sombra partida.** Com **duas luzes** perto, o inimigo tem **duas sombras**. Pregar as duas causa "Sombra Partida": o inimigo fica imóvel por 3 segundos e leva **dano triplicado**. É o maior prêmio do jogo, e só sai fácil com duas pessoas posicionadas.
3. **Interseção de luzes.** O inimigo dentro das poças de luz de **2 heróis** fica *Exposto* (+30% de dano recebido). Dentro de **3**, fica *Ofuscado* (−50% de velocidade, cancela telegrafias de 1 segundo ou menos). Cada par de heróis ainda dá um efeito próprio (tabela em 4.3).
4. **Brilho é ameaça.** Os inimigos perseguem a luz mais forte. Todo herói tem os verbos **Brilhar** (poça +50%, atrai inimigos, gasta chama) e **Abafar** (poça −60%, quase invisível, recupera chama devagar). Um puxa a atenção enquanto os outros contornam no escuro para pregar sombras. É o papel de "tanque" sem classe fixa.
5. **Passar o fogo.** Encostar a chama na de um aliado e segurar o botão transfere chama. Serve para reviver (3.6) e para "sobrecarregar" quem vai receber o golpe do chefe.
6. **Clarão.** Quando 2 ou mais heróis com a barra de Clarão cheia apertam o botão numa janela de 0,5 segundo e as poças se tocam, dispara um clarão branco-dourado. Ele atordoa todos os inimigos na tela por 2 segundos e vira todas as sombras para fora, em leque. Com 4 jogadores, o Clarão também acende todos os lampadários da sala.

### 3.2 Sozinho

O jogo solo tem **um companheiro de IA** por padrão e a **troca de personagem** como opção.

- O companheiro (o "lume de companhia") tem um comportamento principal simples de programar: **ficar do lado oposto ao inimigo mais perto de você**, para que a sombra desse inimigo aponte para você. Ele não prega sombras por conta própria, a não ser quando você pede com um toque (botão "Prega!"). Assim o jogador continua sendo o autor da jogada.
- Ele também revive você uma vez por sala, Abafa quando você Brilha e entra no Clarão sempre que você entrar.
- **Troca:** um botão alterna o controle entre os dois heróis. O que fica sem controle passa a ser IA. Isso permite jogar a dupla Candeia + Risco "a quatro mãos" sozinho.
- Escala do solo: os inimigos têm 70% da vida, e o chefe pede 2 sombras pregadas em vez de 4 (ver 4.6).

### 3.3 Local no mesmo aparelho

- **PC ou TV com controles:** de 2 a 4 jogadores na mesma tela, câmera compartilhada que afasta até um limite e depois puxa quem ficou para trás com uma corda de luz (nunca deixa alguém fora da tela). É o modo com melhor visual (Forward+).
- **Celular:** o toque atende um jogador só. Um segundo jogador entra apenas com controle Bluetooth ou USB, o que é raro (`extra-contexto-real-celular-coop.md`, 3.3). No celular, o modo realista é **solo com IA** ou **cada um no seu celular** (3.4).
- **Tablet ou TV com celulares como controle** (modelo AirConsole): previsto para o terceiro marco, depois do online.

### 3.4 Caminho para o online

- A arquitetura nasce **com host autoritativo e entradas por jogador**: teclado, controle, toque, bot e jogador remoto passam pela mesma interface. O modo local é o mesmo código com os "remotos" na mesma máquina [pesquisa: `coop-rede.md`, `extra-contexto-real-celular-coop.md` 14].
- **Web:** WebRTC com host no navegador. Já funcionou neste projeto com 1 host e 3 clientes, sem GDExtension [pesquisa: `extra-contexto-real-celular-coop.md` 5.1]. Precisa de sinalização própria, de TURN por causa do CGNAT das operadoras e de pausa automática quando o host sai do aplicativo.
- **Regras de rede próprias deste conceito [proposta]:**
  - A pregada é decidida no host com **250 ms de tolerância**: se a sombra estava sob o seu pé em qualquer momento nessa janela, conta.
  - A sombra é calculada no host a partir das posições, mas cada aparelho a desenha na hora com as posições locais, interpoladas.
  - O Clarão tem janela de 500 ms, que cobre a latência típica de celular para celular (cerca de 150 ms).
  - Telegrafias de inimigo têm 450 ms ou mais.
- **PC:** ENet entre computadores e, depois, Steam Remote Play Together, que transforma o co-op local em online sem escrever rede [pesquisa].
- Em online, **cada aparelho segue o próprio herói**, então as arenas podem ser maiores do que a tela.

### 3.5 Fogo amigo

O fogo amigo existe, é leve e sempre é cômico, nunca punitivo.

| Fonte | O que faz no aliado | Dano |
|---|---|---|
| Lanterna na corrente da Candeia | Empurra 1,5 m, com um "plém" de lata | 0 |
| Explosão Cabeça Quente do Risco | Empurra 3 m e chamusca (a silhueta fica com fumacinha por 2 s) | 25% do dano normal |
| Feixe do Farolete | Ofusca: a poça do aliado pisca e diminui 20% por 1 s | 0 |
| Clarão | Nunca afeta aliados | 0 |

Há uma opção de sala de estar, "Sem fogo amigo", que zera o empurrão e o dano. Em online, todo acerto em aliado é decidido no host com favor da vítima: só conta se o aliado também estava na área na visão do host.

### 3.6 Morte e reviver

- A vida é a **chama**, de 0 a 100. Ela aparece no próprio personagem (o tamanho e o brilho da chama) e numa barra discreta.
- Com a chama em 0, o herói fica **Apagado**: vira uma silhueta com um pavio fumegando e olhos quase apagados. Ele não morre de imediato. Pode **andar devagar** (40% da velocidade) até um aliado. Ter algo a fazer enquanto está caído reduz a frustração.
- **Reviver = passar o fogo.** O aliado encosta a chama e segura 1,5 s, gastando 15% da própria chama. A Lumeira revive à distância, mandando um vaga-lume.
- O Apagado volta com 35 de chama.
- Se todos se apagarem, a vila tem **uma brasa de reserva** por expedição, que reacende o grupo inteiro uma única vez. Na segunda vez, a expedição acaba e o grupo guarda 50% das brasas.

### 3.7 Saque

- **Brasas** (moeda): são compartilhadas e divididas automaticamente. Ninguém disputa.
- **Pavios** (modificadores): aparecem num altar com **uma escolha por jogador**. Cada um vê 3 opções e pega 1. O que um pega não some para o outro.
- **Óleos** (consumíveis, até 2 por herói): caem no chão com a cor de quem pode pegar. No online, o saque é instanciado por jogador.
- Não existe item que só um jogador do grupo pode ter. Isso evita briga em grupo de amigos.

---

## 4. Combate e sistemas

### 4.1 Verbos do jogador (8)

| Verbo | Entrada | Detalhe e números |
|---|---|---|
| Andar | analógico | 5,5 m/s (varia por herói, 4,5 a 7) |
| Atacar | botão | Combo de 3 golpes, início de 3 a 6 quadros [pesquisa: `animacao-principios.md` 1] |
| Habilidade | botão | Uma por herói, recarga de 6 a 10 s |
| Esquivar | botão | Rolamento de 0,35 s, 0,2 s de invulnerabilidade. A chama vira um risco de luz no ar |
| Brilhar | segurar | Poça +50%, atrai inimigos, gasta 4 de chama por segundo |
| Abafar | segurar (outro botão) | Poça −60%, inimigos perdem o rastro em 1,5 s, recupera 2 de chama por segundo |
| Pregar | atacar em cima de uma sombra | Automático quando o golpe acerta a sombra. Trava o inimigo por 2 s (inimigo comum) ou 1 s (elite) |
| Passar o fogo / interagir | botão | Reviver, acender lampadário, transferir chama |

O **Clarão** é Habilidade + Brilhar ao mesmo tempo, com a barra cheia. Assim não ocupa um botão próprio no celular.

### 4.2 Sombras: as regras exatas

- Cada inimigo projeta sombra das **2 luzes mais fortes** num raio de 8 m (heróis, lampadários, efeitos fortes). A força da luz é o brilho dividido pela distância.
- O comprimento da sombra cresce quando a luz fica mais baixa ou mais perto: varia de 1,5 m (luz alta, longe) a 6 m (lanterna rente ao chão, perto). **Agachar com a lanterna (Abafar perto do inimigo) produz a sombra mais comprida**, o que dá mais um uso tático para o Abafar.
- A área "pregável" é a **metade de cima da sombra** (a parte da cabeça). Isso evita pregar sem querer quando se está colado no inimigo.
- Inimigo pregado não se move, mas termina a telegrafia que já tinha começado, se ela estiver no último terço. Isso mantém a honestidade do perigo.
- Chefes e elites têm sombras com **resistência**: precisam de 2 golpes na sombra para pregar.

### 4.3 Luzes dos heróis e interseções

Cada herói tem uma **qualidade de luz** com cor, padrão projetado no chão e efeito. Os padrões existem para que os heróis se distingam mesmo para quem tem daltonismo.

| Herói | Cor da luz | Padrão no chão | Efeito da própria luz |
|---|---|---|---|
| Candeia | âmbar `#FFB347` | pontinhos de lata furada | Inimigos na poça levam empurrão maior (+30%) |
| Risco | rosa-fósforo `#FF5C8A` | riscos irregulares que piscam | Golpes na poça deixam brasa (2 de dano por segundo, 3 s) |
| Lumeira | verde-limão `#C8F560` | pontos que se movem (os vaga-lumes) | Aliados na poça recuperam 1 de chama por segundo |
| Seu Farolete | ciano-gelo `#6FE3FF` | faixas que giram, como as de um farol | Sombras na poça ficam 50% mais compridas |

Interseções de par (as 6 combinações):

| Par | Nome | Efeito no inimigo dentro das duas poças |
|---|---|---|
| Candeia + Risco | Chamusco | A brasa vira chama: 5 de dano por segundo e o inimigo corre em pânico por 1 s |
| Candeia + Lumeira | Aconchego | Aliados ali dentro ficam com −30% de dano recebido |
| Candeia + Farolete | Sombra de Ferro | Sombras pregadas ali duram o dobro |
| Risco + Lumeira | Faísca-Viva | Cada golpe solta um vaga-lume que pula para o inimigo mais perto (4 de dano) |
| Risco + Farolete | Rastro | Esquivas ali deixam um risco de fogo no chão por 2 s |
| Lumeira + Farolete | Farol de Bolso | Inimigos ali ficam marcados e visíveis através de paredes por 5 s |

Com 3 luzes, valem *Ofuscado* e os efeitos de todos os pares presentes. Com 4, o Clarão fica 30% mais barato.

### 4.4 Pavios (modificadores)

O jogo completo tem **24 pavios**, e a fatia vertical tem 8. Eles **mudam a geometria da luz**, não só os números. Exemplos:

| Pavio | Efeito |
|---|---|
| Pavio Torto | A poça vira um cone de 90° à sua frente: sombras mais longas e direcionais, ruim para defesa |
| Pavio Duplo | Você conta como duas luzes, separadas por 1 m: sozinho, já cria duas sombras |
| Pavio de Sebo | Poça +40%, dano −15% |
| Pavio Curto | Dano +35%, mas a chama gasta 1 por segundo o tempo todo |
| Pavio de Cera Mole | Esquiva vira um rolamento duplo, e cada um deixa uma gota de luz por 3 s |
| Pavio Teimoso | Uma vez por sala, quando a chama chegaria a 0, ela fica em 1 |
| Pavio de Brejo | A poça fica verde-escura e esconde você de inimigos a mais de 6 m |
| Pavio Trançado | Passar o fogo é instantâneo e não custa chama |

### 4.5 Inimigos: os Apagadores (5 arquétipos)

Os inimigos não são malvados. São criaturas da noite que **querem dormir**, e a luz incomoda. O tom é de vizinho rabugento, não de horror. Todos têm olhos no **lilás-frio reservado** (`#C39BFF`), e toda telegrafia de inimigo **encolhe na direção do impacto**. As ajudas dos heróis sempre **crescem**. Essa é a regra de leitura do jogo: **o perigo encolhe, a ajuda cresce**.

| Inimigo | Silhueta | Comportamento | Telegrafia | Punição |
|---|---|---|---|---|
| **Abafador** | Cone (um apagador de vela que anda) | Persegue a luz mais forte e pula para tampar o herói | Agacha, o cone sobe e mostra a borda lilás, e um anel lilás encolhe no alvo: **500 ms** | Se acertar, o herói fica tampado: chama −30 e 3 s preso. **Um aliado precisa chutar o cone** (1 golpe) para soltá-lo. Errou o pulo: fica 1,5 s entalado no chão |
| **Bochecha** | Balão ou saco de bochechas | Mantém distância e sopra um cone de vento | Infla até 1,6× o tamanho, **todas as chamas perto se inclinam para ele**, e partículas de fuligem são sugadas: **700 ms** | Sopro: chama −15 e empurrão de 4 m. Depois murcha e fica **2 s mole** no chão, com +50% de dano recebido |
| **Goteira** | Gota pendurada num fio, que desce do escuro | Fica fora das poças de luz e solta gotas em área | A gota incha na ponta do fio e um anel lilás encolhe no chão, embaixo dela: **800 ms** | Gota: chama −20. A Goteira só pode ser atingida quando desce para recarregar (1,2 s), ou depois que uma luz a pega (ela cai) |
| **Fuligem** | Rabisco em bando (de 6 a 12) | Gruda nas chamas e pesa | Quase nenhuma, porque o perigo é o número. Chegam por uma trilha de pó visível | Cada uma grudada tira 2 de chama por segundo (até 5 grudadas). Brilhar espanta todas em 1 s |
| **Bocejo** (elite) | Bolo enorme e mole, com braços curtos | Anda devagar e boceja em área | Espreguiça e abre a boca devagar, de forma cômica: **1.200 ms**. Os heróis dentro da área também começam a bocejar | Bocejo: chamas na área caem para brasa (−40) e o herói fica 1 s lento. Depois do bocejo, ele cochila por 3 s: é a hora de pregar as duas sombras |

Números de vida (inimigo comum, grupo de 2): Abafador 40, Bochecha 55, Goteira 30, Fuligem 6 cada, Bocejo 260. Escala: +35% de vida por jogador extra.

Dano dos heróis (golpe básico): Candeia 12, Risco 8 (mais rápido), Lumeira 6, Farolete 10 por pulso de feixe. Pregado: ×1,5. Sombra Partida: ×3.

### 4.6 Chefe: **o Fole**

**Quem é.** Um fole de forja do tamanho de uma casa, que acordou com fome de ar. O corpo é uma sanfona de couro escuro entre duas tábuas, que servem de braços. O focinho é um bico de ferro, e os olhos lilás piscam nos vincos do couro. Ele não é mau: tem asma e quer silêncio. Engoliu todas as chamas que encontrou, e elas brilham presas dentro das dobras.

**A arena: a Forja Fria.** É um salão circular de 22 m de diâmetro, com uma bigorna no centro e **4 braseiros apagados** nos cantos. A única luz no começo são os heróis.

**Introdução (20 s, pulável).** O Fole está dormindo e ronca: cada ronco faz as chamas dos heróis se inclinarem para ele. Quando a luz dos heróis chega perto, ele espirra. A câmera treme, todas as poças piscam, e o chefe abre os olhos, irritado, com uma gota de chama presa no bico.

**Fase 1, "Puxa e Sopra" (100% a 65%)**
- Ciclo: **inspira por 1,5 s** (todas as chamas da arena se inclinam para ele, a fuligem corre pelo chão e o som perde os agudos), depois **sopra um cone de 90° por 1,2 s** (chama −25 e empurrão até a parede).
- Entre os sopros, ele dá **pulos de sanfona**: comprime, estica alto e cai num ponto marcado por um anel lilás que encolhe (800 ms).
- **Janela de punição:** depois de soprar, fica **vazio e chato por 2,5 s**, com o couro murcho. Os golpes nas dobras valem dobrado.
- **Tarefa:** acender os braseiros. Cada braseiro aceso vira uma luz fixa que projeta uma sombra do Fole.

**Fase 2, "Fuligem" (65% a 30%)**
- O Fole passa a aspirar a fuligem do chão e cuspir **bolas de fuligem** que se abrem em bandos de Fuligem.
- Ele **tenta apagar os braseiros**: vira o bico para um deles e inspira por 2 s. Um herói perto do braseiro pode Brilhar para "segurar a chama" (a barra do braseiro desce mais devagar) ou pregar a sombra do Fole para interromper a inspiração.
- O jogo pede uma divisão natural de papéis: um defende os braseiros, outro espanta a fuligem, outro bate.

**Fase 3, "O Grande Fôlego" (30% a 0%)**
- O Fole planta as tábuas no chão e começa uma inspiração **contínua**. Fitas de luz saem de cada herói, na cor dele, e correm para o bico. A chama de todos desce 3 por segundo.
- Com os braseiros acesos, ele tem **até 4 sombras** (uma por braseiro). Cada sombra pregada corta 25% da força da inspiração.
- **Quantas sombras é preciso pregar ao mesmo tempo:** o número de jogadores (mínimo 2; solo com IA, 2). Quando todas estão pregadas, o Fole trava, enche além do limite e **estoura**.
- Se os heróis não conseguirem, depois de 25 s ele termina a inspiração e solta um supersopro que apaga quem estiver sem Abafar. Abafar perto do chão salva o herói, porque a chama baixa não é sugada.

**Morte (6 s).** Ele infla até 2,2× o tamanho, a sanfona estica até ficar lisa, e há um **hold de tensão de 0,75 s** com as pupilas encolhendo. Então ele estoura. Centenas de chamas presas saem voando em arcos, cada uma na cor de uma janela da vila. A câmera sobe e mostra as chamas cruzando o céu e entrando nas casas. O couro vazio cai como um lençol, e o Fole, pequeno e murcho, ronca em paz no chão.

**Duração:** de 6 a 8 minutos. A vida escala com o número de jogadores (2.400 para 2, +35% por jogador extra).

---

## 5. Heróis (4)

As quatro silhuetas vêm de quatro formas básicas diferentes: **triângulo, pirulito, bola e torre**. Qualquer uma pode ser reconhecida só pela sombra, que é exatamente o teste deste jogo.

### Dona Candeia, a vigia

- **Silhueta:** triângulo baixo, em forma de pera. Capuz largo, saia de sino, braços curtos e fortes. Na mão, uma lanterna de lata furada pendurada numa corrente de 1,2 m.
- **Personalidade:** a vigia noturna da vila. É brava, protetora e ri alto. Fala com os inimigos como quem expulsa gato do quintal.
- **Kit:**
  - *Básico:* três balanços de lanterna na corrente, largos (arco de 160°).
  - *Habilidade "Roda":* gira a lanterna em volta do corpo por 2 s e puxa os inimigos para perto.
  - *Brilhar especial "Lata Acesa":* bate a lanterna no chão e cria uma poça enorme por 4 s.
- **Como a animação mostra a personalidade:** peso e chão. O centro de gravidade é baixo, e ela anda com um balanço de pata. A corrente é o grande **follow-through** do jogo: a lanterna chega sempre 3 a 5 quadros depois da mão. Ela segura as poses de vitória com orgulho, mãos na cintura. Antecipação curta no braço, mas o corpo inteiro "carrega" com um afundo de quadril.
- **Taxa de poses:** 20 poses por segundo (cada pose dura 3 quadros a 60), com o contato em 1s.

### Risco, o fósforo

- **Silhueta:** pirulito. Corpo de palito alto e fino, cabeça redonda e grande, que é a própria cabeça de fósforo. Ela acende quando ele ataca.
- **Personalidade:** afobado, exibido, pavio curto. Chega primeiro, se queima primeiro e pede desculpa depois.
- **Kit:**
  - *Básico:* estocadas rápidas com um graveto em brasa (combo de 4, 8 de dano).
  - *Habilidade "Riscada":* uma investida de 5 m que deixa um risco de fogo no chão por 3 s. O risco ilumina e cria sombras ao longo da linha.
  - *Brilhar especial "Cabeça Quente":* uma explosão de 3 m em volta dele (com fogo amigo de 25%).
  - *Passivo:* a cabeça gasta. A cada 12 golpes, ele precisa "se riscar" de novo na manga de lixa (0,4 s), um momento de vulnerabilidade com graça.
- **Como a animação mostra a personalidade:** staccato. É o herói mais "elástico": o corpo de palito dobra como borracha, com squash and stretch extremo (0,6 a 1,5), smears de 1 quadro em todo golpe e reações exageradas (*takes*) quando leva susto. Quase nenhuma antecipação. Ele é o Miles Morales do grupo, em 2s, contra a calma dos outros.
- **Taxa de poses:** 30 poses por segundo (2s), com o contato em 1s.

### Lumeira, a dos vaga-lumes

- **Silhueta:** bola. Uma criatura gorducha e baixa que carrega nas costas, como um caracol, um pote de vidro com tampa de pano. Dentro do pote, os vaga-lumes piscam.
- **Personalidade:** tímida, curiosa, gentil. Pede licença até para o inimigo. Fica corajosa quando alguém do grupo cai.
- **Kit:**
  - *Básico:* solta vaga-lumes que voam até o alvo (6 de dano cada, alcance de 7 m).
  - *Habilidade "Enxame":* um bando segue um inimigo por 5 s, deixando-o visível, lento (−30%) e com mais uma luz em cima, o que cria mais uma sombra.
  - *Brilhar especial "Tampa Aberta":* solta todos os vaga-lumes. Cura 25 de chama dos aliados num raio de 6 m e marca todos os inimigos.
  - *Passivo:* revive à distância.
- **Como a animação mostra a personalidade:** hesitação. Muito *slow in e slow out*, pausas curtas antes de agir (holds de 6 a 8 quadros que parecem dúvida), ação secundária constante (ajeita a tampa do pote, olha para trás). Quando se assusta, dá um pulinho e o pote chacoalha, e os vaga-lumes demoram a se acalmar (overlapping). É a mais "fofa", então o **apelo** mora nela.
- **Taxa de poses:** 15 poses por segundo (4 quadros), com o contato em 2s. Ela é deliberadamente mais "devagar" que os outros.

### Seu Farolete, o faroleiro

- **Silhueta:** torre. Alto, sobre pernas de pau, com um casaco comprido e uma cabeça que é uma lente de farol coberta por um chapéu. A lente tem uma persiana, que funciona como pálpebra.
- **Personalidade:** sério, seco, de poucas palavras. Faz piada sem mudar de cara. Tem um carinho escondido por Risco, que vive se metendo em encrenca.
- **Kit:**
  - *Básico:* um feixe em cone (segurar para canalizar, 10 de dano por pulso a cada 0,4 s, alcance de 10 m).
  - *Habilidade "Giro":* gira o feixe em 360° por 1,5 s. As sombras de todos os inimigos varrem o chão como ponteiros de relógio, e qualquer aliado em cima de uma sombra que passa prega aquela sombra.
  - *Brilhar especial "Lampejo":* alinha todas as sombras da tela na mesma direção por 3 s, o que cria um "corredor de sombras" para os aliados pregarem em fila.
- **Como a animação mostra a personalidade:** pose a pose. Poses muito claras e seguradas por bastante tempo, com movimentos raros mas precisos. Quando ele finalmente se mexe rápido, faz isso em 1s, de repente, e o contraste fica engraçado. O casaco faz o follow-through, e a persiana da lente faz piscadas lentas que são as piadas dele.
- **Taxa de poses:** 12 poses por segundo (5 quadros), com explosões de 1s nos golpes.

### Expressão facial sem rig facial

Nenhum herói tem rosto modelado. **Os olhos e a boca são buracos de luz**, desenhados por shader (SDF) na máscara ou no capuz. Eles são controlados por 4 parâmetros: abertura, inclinação, curva e tamanho da pupila. Isso produz raiva, alegria, susto, sono e dor com nitidez em qualquer resolução e custa quase nada. É o princípio da abóbora de Halloween, só que animado.

---

## 6. Mundo, biomas, tom e história

**História em poucas linhas.** No mundo de Lumaréu, a noite às vezes esquece de acabar. Quando a Noite Comprida chega, os moradores mantêm uma fogueira no meio da vila, o Lumaréu, até o dia voltar. Desta vez, as criaturas que gostam do escuro (os Apagadores) se cansaram da claridade e, guiadas pelo Fole, saíram apagando cada vela, cada janela e cada brasa. A vila tem quatro luzes que ainda andam. Elas saem toda noite para trazer de volta as chamas roubadas, uma brasa por vez.

**Tom.** Comédia noturna e aconchegante, com um pouco de assombro. Os inimigos são rabugentos e sonolentos, não malignos. Ninguém morre: quem apaga, reacende. A noite é bonita, não assustadora.

**Vocabulário próprio.** Lumaréu, chama, pavio, brasa, Apagadores, pregar, Sombra Partida, Clarão, Noite Comprida. **Nenhum texto do jogo usa** "cordel", "encantado", "sertão", "cangaço", "spells" nem "lampião" (este último por lembrar o cangaceiro).

| Bioma | O que é | Assinatura visual | Inimigos principais | Mecânica de lugar |
|---|---|---|---|---|
| **Vila do Pavio** (centro) | A vila em volta do Lumaréu | Casas escuras com janelas que se acendem conforme a meta-progressão | — | Escolha de herói, oficina de lata, altar de pavios |
| **Brejo das Velas** | Alagado com vitórias-régias que seguram tocos de vela | Água escura que reflete as poças de luz (reflexo simples na Web, real no PC). Neblina baixa só nas bordas | Goteira, Fuligem | Velas boiando são lampadários móveis: empurrá-las muda os ângulos de sombra |
| **Varal dos Lençóis** | Morros de capim com varais de lençóis brancos ao vento | **Os lençóis recebem sombras**: personagens e inimigos aparecem projetados neles, como num teatro de sombras gigante | Bochecha, Abafador | Uma sombra projetada num lençol também pode ser pregada. O vento muda de direção e inclina todas as chamas |
| **Chaminés de Breu** | Telhados e chaminés de uma cidade abandonada, cobertos de fuligem | Telhas em degraus, chaminés que soltam fumaça escura em ciclos | Abafador, Fuligem, Bocejo | Chaminés "respiram": quando soltam fumaça, apagam as poças em volta. Tampar uma chaminé com um Abafador pregado é um atalho |
| **Forja Fria** (chefe) | O covil do Fole | Bigorna, braseiros, correntes penduradas | Fole | Braseiros como fontes de sombra (4.6) |

---

## 7. Direção de arte: "luz recortada"

### 7.1 Linguagem visual

- **Personagens:** silhuetas em **tinta noturna** (`#14111F`, nunca preto puro), com toon de 2 faixas e um **contorno de luz** (rim) calculado no shader a partir das luzes próximas, na cor da luz que bate. As únicas partes que brilham são a fonte de luz (lanterna, cabeça de fósforo, pote, lente) e os buracos dos olhos e da boca.
- **Luz:** a luz é desenhada como **forma gráfica recortada**, não como névoa suave. Cada poça de luz no chão tem **3 faixas com borda dura** (100%, 60% e 30% de intensidade) e o padrão próprio do herói recortado dentro dela, como luz de lanterna de lata furada ou de projetor de teatro. É uma luz de ilustração, pensada como as manchas chapadas de animação de TV dos anos 2000, não como fotografia.
- **Cenário:** formas grandes e simples, cor chapada em degraus, valores médios e frios. O cenário é "pintado" pelo luar (uma luz-chave azulada, fixa, vinda de cima e da esquerda em todo o jogo) e "recortado" pelas poças de luz quente dos heróis.
- **Família de formas:** **gota e cone**, as duas formas da chama. Heróis são arredondados (gotas, bolas, curvas), inimigos são cones, sacos e gotas penduradas. O cenário usa cones (telhados, chaminés, juncos) e gotas (pedras, moitas).

### 7.2 Paleta (22 cores no total)

| Papel | Cores | Valor (V em HSV) |
|---|---|---|
| Fundo distante e céu | anil-noite `#1E2340`, azul-fundo `#2A3156` | 20 a 35% |
| Chão e cenário jogável | ardósia `#3A4258`, musgo-noturno `#33423B`, terra-fria `#4A4550` | 25 a 40% (sobe para 45 a 65% dentro das poças) |
| Luar e destaques | cinza-luar `#8C93A8`, branco-luar `#C9CEDD` | 55 a 85%, em pouca área |
| Personagens | tinta noturna `#14111F`, tinta-viva `#221C33` | 7 a 20% (corpo), rim de 60 a 90% |
| Luzes dos heróis | âmbar `#FFB347`, rosa-fósforo `#FF5C8A`, verde-limão `#C8F560`, ciano-gelo `#6FE3FF` | 85 a 100% |
| Clarão | branco-dourado `#FFF1C9` | 100% |
| Perigo (reservado) | lilás-frio `#C39BFF` e lilás-escuro `#6E4FB8` | 60 a 95% |
| Interface | papel-de-vela `#F3E9D2`, tinta noturna, âmbar | livre |

O orçamento de valor de `direcao-de-arte.md` 7.2 foi pensado para cenário claro, e a prova de estilo do mamulengo mostrou que ele quebra com papel cru claro [pesquisa: `extra-prova-de-estilo-boneco-cordel.md` 1.4]. Aqui ele se inverte com regra própria: **o chão é médio, os corpos são escuros, as luzes são as mais claras**. Os heróis se destacam pelo brilho e pela borda de luz, não pela cor do corpo.

### 7.3 Regras anti-slop específicas deste estilo

"Lanterninhas brilhando na noite" é um dos clichês mais comuns de imagem gerada por IA: bokeh, poeira de brilho flutuando, névoa dourada em tudo. Este conceito precisa fugir disso com regras que um script consiga conferir:

1. **Proibido bokeh e proibido "pó mágico" ocioso.** Partícula flutuante só existe se tiver causa (fuligem, vaga-lume com rota, brasa que saiu de um golpe). No máximo 40 partículas ociosas na tela.
2. **Toda luz tem fonte visível no quadro ou a 2 m da borda.** Não existe brilho sem dono.
3. **Bordas duras nas poças de luz.** Degradê suave só no núcleo da fonte, com raio de no máximo 0,3 m. Teste: o histograma da poça precisa ter 3 picos (as faixas), não uma rampa.
4. **Glow com teto:** só os núcleos das fontes e o Clarão passam do limiar. O resto da cena nunca brilha.
5. **Pontilhado (dithering) obrigatório** em todo degradê escuro, para evitar as faixas do RGBA8 da Web [pesquisa: `direcao-de-arte.md` 2.1].
6. **Cintilação da chama por ruído de 2 oitavas com eventos**, nunca por seno. A chama dá um "estalo" quando o herói golpeia, se encolhe quando ele apanha e se inclina com o vento. Nunca pisca de forma regular.
7. **Padrões de lata gerados por regra com variação:** furos com jitter de 3 a 8% por instância e semente fixa. Nada de simetria perfeita.
8. **Silhueta primeiro:** cada pose-chave passa por um teste automático em preto chapado. Duas poses do mesmo clipe com sobreposição (IoU) acima de 0,92 reprovam, porque não se distinguem.
9. **Nenhuma névoa volumétrica no plano de jogo**, só atrás e nas bordas. No PC, raios de luz volumétricos só saem do Lumaréu e dos braseiros.
10. **Sem textura de "superfície detalhada" nos personagens.** O corpo é chapado. O detalhe mora na pose e no contorno de luz.

### 7.4 Por que não parece arte gerada

- **Arte gerada costuma esconder a pose atrás de textura, brilho e detalhe.** Este jogo faz o contrário: tira a textura e expõe a pose. Uma silhueta mal posada é feia de imediato, e uma bem posada parece animação de estúdio.
- **A luz é uma regra de jogo, não um efeito.** A poça tem o raio verdadeiro da mecânica, e a sombra é a área pregável. Quando arte e regra são a mesma coisa, o resultado parece decidido, que é o contrário do slop.
- **Uma direção de luz-chave em todo o jogo** (o luar) e **4 luzes com dono**. Não existe iluminação "cinematográfica" genérica.
- **As referências são de animação desenhada e de ilustração gráfica** (manchas chapadas, luz recortada), não de "fantasia sombria" genérica.

### 7.5 Câmera

- **Padrão: a câmera de "camarote" testada na prova de estilo**, com perspectiva de 30°, inclinação de 38° e distância de cerca de 15,5 m. Ela separou 24 personagens e manteve heróis de 116 a 155 px de altura em 720p [pesquisa: `extra-prova-de-estilo-boneco-cordel.md` 1.2].
- Neste conceito, a inclinação de 38° é também a melhor para ler **sombras no chão**: numa câmera muito alta, a sombra fica embaixo do corpo, e numa câmera muito baixa, ela some atrás dele.
- Os heróis são **altos de propósito** (lanterna acima da cabeça, cabeça de fósforo, lente sobre pernas de pau), para que a fonte de luz nunca fique escondida pelo próprio corpo vista de cima.
- **Momentos de vitrine:** na entrada do chefe, na morte do chefe e no Clarão, a câmera baixa para 15° por 1 a 2 s, para mostrar as silhuetas contra o céu. Ela nunca faz isso no meio de um combate ativo.

---

## 8. Animação pelos 12 princípios

### 8.1 Exemplos concretos por princípio

| Princípio | Heróis | Inimigos | Chefe (Fole) |
|---|---|---|---|
| **Squash and stretch** | Risco estica para 1,5× no golpe e achata para 0,6× ao cair, com volume constante. A chama de todos achata no impacto recebido e estica ao Brilhar | O Bochecha infla para 1,6× (squash para os lados) e estica para frente ao soprar | A sanfona inteira é squash and stretch: comprime para 0,5× antes do pulo e estica para 1,8× no ar |
| **Antecipação** | Curta e escondida: Candeia afunda o quadril 3 quadros antes do balanço. O golpe 1 do combo já começa na pose de carga | Longa e legível: Abafador agacha 500 ms, Bocejo se espreguiça 1.200 ms | A inspiração de 1,5 s é a antecipação do sopro, e **a arena inteira participa** (as chamas se inclinam) |
| **Encenação (staging)** | Cada golpe tem uma pose de contato que se lê em silhueta. A fonte de luz nunca fica atrás do corpo, vista da câmera | Inimigos telegrafam virados para o alvo, de perfil para a câmera quando possível | Entrada e morte com a câmera baixa e o céu por trás: silhueta pura |
| **Pose a pose e direto** | Pose a pose em tudo que o jogador controla. Ações diretas só nas chamas (flipbook desenhado em sequência) | Fuligem é "direta": o bando segue regras de enxame, não poses | Pose a pose no corpo. As chamas presas nas dobras se movem de forma direta, por simulação |
| **Continuidade e sobreposição** | A corrente da Candeia chega 3 a 5 quadros depois da mão. O casaco do Farolete e a tampa do pote da Lumeira continuam depois que o corpo para | O cone do Abafador balança 2 vezes depois de cair. O fio da Goteira oscila depois que ela sobe | As tábuas param antes da sanfona, que ainda ondula 3 vezes. O bico de ferro balança por último |
| **Aceleração e desaceleração** | Lumeira tem slow in e slow out exagerados. Risco quase não tem: é "slow out" seco, sem chegar devagar, de propósito | O Bochecha murcha com desaceleração lenta (2 s), o que comunica "agora pode bater" | O estouro final: aceleração forte na inflação, hold, e a explosão sem desaceleração nenhuma |
| **Arcos** | O balanço da lanterna desenha um arco limpo, e a trilha de luz segue esse arco. O pulo do Risco é uma parábola com a cabeça liderando | A Goteira desce em arco de pêndulo, não em linha reta | As chamas libertadas voam em arcos até as janelas da vila |
| **Ação secundária** | **A chama é o rosto**: encolhe de susto, estala de raiva, se inclina de curiosidade. A Lumeira ajeita a tampa do pote enquanto anda | O Abafador ajeita o cone como quem ajeita um chapéu. O Bocejo coça a barriga enquanto anda | O Fole funga e coça o bico com a tábua entre os ataques. Chamas presas batem contra o couro por dentro |
| **Tempo (timing)** | Cada herói tem a própria taxa de poses (20, 30, 15 e 12 por segundo). O ritmo é parte da personalidade | Inimigos leves em 15 poses por segundo. O Bocejo em 10, para parecer pesado e sonolento | 12 poses por segundo no corpo, para parecer enorme. As fitas de luz e o vento ficam a 60 |
| **Exagero** | No quadro de contato, o braço fica 15% mais comprido por 1 quadro. O "take" do Risco ao se queimar: olhos de 2× por 4 quadros | O Abafador se entala no chão até a cintura quando erra o pulo | Inflação final de 2,2× com as pupilas virando pontinhos |
| **Forma sólida (solid drawing)** | Quatro silhuetas de formas básicas diferentes, que funcionam vistas de qualquer ângulo. Teste: girar 360° na revisão | Cone, saco, gota, rabisco e bolo: nenhum se confunde com outro na miniatura 320×180 | Volume claro de sanfona entre duas tábuas, legível do alto |
| **Apelo** | Olhos de luz com 4 parâmetros. Proporções de 2 a 2,5 cabeças. Cada herói tem uma pose de descanso própria (Candeia de mãos na cintura, Risco batendo o pé, Lumeira abraçando o pote, Farolete imóvel) | Inimigos são "rabugentos fofos": olhos lilás semicerrados, nunca dentes | O chefe dorme e ronca no final. O jogador termina com simpatia por ele |

### 8.2 Taxa de poses e regras de tempo

Os números seguem a regra de animação em 2s de `animacao-principios.md` 7.2:

- **Render, física, câmera, VFX e interface rodam a 60.** Só a pose do esqueleto anda em degraus.
- **A primeira pose depois de um comando aparece na hora.** O relógio das poses reinicia no comando, e o jogador nunca espera pelo próximo degrau.
- **O contato sempre é em 1s** (2 a 4 quadros em volta do impacto), com smear de 1 quadro (2 no golpe pesado).
- **O deslocamento no mundo é contínuo.** Só a pose é em degrau.
- **A sombra herda o degrau**, porque usa o mesmo esqueleto. As sombras "batem" junto com o corpo, o que reforça o estilo.
- **As chamas são flipbooks a 12 quadros por segundo**, como o fogo desenhado à mão das animações clássicas. A cintilação de brilho por cima delas roda a 60.

| Personagem | Poses por segundo | Golpe | Ocioso |
|---|---|---|---|
| Candeia | 20 (3 quadros) | 1s no contato | 4 quadros |
| Risco | 30 (2s) | 1s no contato | 3 quadros |
| Lumeira | 15 (4 quadros) | 2s no contato | 5 quadros, com holds de dúvida |
| Seu Farolete | 12 (5 quadros) | 1s, de repente | 6 quadros |
| Inimigos comuns | 15 | 1s no contato | 4 quadros |
| Bocejo | 10 | 2s | 6 quadros |
| Fole | 12 no corpo | 1s no estouro | 5 quadros |

Números de impacto [pesquisa: `animacao-principios.md` 1 e 6.6]: hit-stop **local** de 4 quadros no golpe leve, 10 no pesado, 18 na pregada que fecha uma Sombra Partida e 30 no estouro do Fole. O atacante continua a 10% da velocidade durante o hit-stop. O alvo treme na horizontal, com amplitude que diminui.

### 8.3 O que é Blender e o que é Godot em tempo real

| Camada | Onde | Como |
|---|---|---|
| Modelagem dos corpos | Blender (`bpy`) | Skin modifier + Subsurf para corpos arredondados (2.912 triângulos em 8 ms no teste) e primitivas com bevel para lanterna, cone e tábuas [pesquisa: `pipeline-blender.md` 7]. Alvo: 4.000 a 6.000 triângulos por herói, 1.500 a 2.500 por inimigo comum |
| Esqueleto | Blender | Um gerador de rig paramétrico com 3 proporções (baixo e largo, alto e fino, bola). De 18 a 26 ossos por herói. A corrente da Candeia tem 6 ossos |
| Poses-chave e breakdowns | Blender | Animação em Bezier a 60 fps como fonte de verdade, com defasagem por osso. Depois, um script "assa" num clone com chaves CONSTANT, seguindo o mapa de holds de cada trecho (1s no contato, 2s a 5s no resto) [pesquisa: `animacao-principios.md` 7.3] |
| Shape keys | Blender | Inflação do Bochecha, sanfona do Fole, bocejo do Bocejo. Viram blend shapes no Godot [pesquisa: `pipeline-blender.md`] |
| Malhas de smear | Blender | Uma casca de arco por golpe, presa ao osso da arma, visível por 1 quadro [pesquisa: `animacao-principios.md` 8.3] |
| Flipbooks de chama | numpy ou Cycles | 12 quadros de chama por SDF 2D desenhados por regra (formas de gota com bordas duras), em atlas de 512 px. Um conjunto por herói, com formas diferentes |
| Exportação | Blender → glTF | Chaves CONSTANT viram STEP. Import a 60 fps, **otimizador de animação desligado e compressão desligada** [pesquisa: `extra-pilha-unica-godot-4-7.md` 0] |
| Máquina de estados | Godot | `AnimationTree` com State Charts v0.22.5 [pesquisa: `extra-pilha-unica-godot-4-7.md`] |
| Follow-through procedural | Godot | `SpringBoneSimulator3D` no casaco, no capuz e no fio da Goteira. Mola de segunda ordem (`SecondOrder`) na corrente da Candeia (f = 2,2, ζ = 0,35) e na inclinação das chamas [pesquisa: `animacao-principios.md` 11.3] |
| Olhar | Godot | `LookAtModifier3D` com limites: a cabeça segue o inimigo mais perto |
| Olhos e boca | Godot | Shader SDF na máscara, com 4 parâmetros animados por trilha e por estado (susto, raiva, sono) |
| Squash procedural | Godot | Shader de vértice com volume preservado e smear pela velocidade, já testado no Compatibility [pesquisa: `animacao-principios.md` 8.3] |
| Sombras | Godot | **Sombra planar projetada** por shader de vértice: o próprio esqueleto, achatado no chão a partir da posição da luz (ver 13.2) |
| Poças de luz | Godot | Shader do chão que recebe até 8 luzes (posição, raio, cor e padrão) por um array de uniforms. Nenhuma luz real do motor é usada para isso |
| Inclinação das chamas pelo vento | Godot | Um campo de vento por sala (vetor global + fontes pontuais como o Bochecha), lido por todas as chamas |
| Hit-stop, tremor e câmera | Godot | Hit-stop local num autoload. Phantom Camera v0.12 com "trauma" de câmera [pesquisa] |

---

## 9. VFX e game juice: 9 efeitos-assinatura

1. **Passar o fogo.** O aliado apagado está caído, com um fio de fumaça. Você encosta a sua chama e segura. Uma chaminha pequena sai da sua lanterna, **pula em três arcos** como um bichinho até o pavio dele e entra com um "fum" grave. A poça dele cresce de 0 até as 3 faixas em 6 quadros, os olhos de luz se abrem de baixo para cima, e o herói levanta num stretch de 1,3×. Som: um acorde de violão que sobe.
2. **A pregada.** A sombra de um Abafador se estica até você. Você golpeia o chão. Uma estaca de luz na sua cor finca a sombra com um "toc" de madeira, a sombra ondula como pano e **estica até ficar tensa** com um "plim" de corda. O Abafador congela no meio do passo, tremendo, com um anel na sua cor girando no pé. Hit-stop local de 6 quadros.
3. **Sombra Partida.** Com duas estacas, uma em cada sombra, as duas sombras rasgam no meio com uma linha branca. O inimigo fica cinza-claro por 3 s (o único momento em que um inimigo não é escuro). Os golpes nele soltam lascas de sombra que caem e evaporam. Som: um acorde dissonante que resolve em maior quando ele estoura.
4. **Clarão.** Os heróis erguem as luzes. Por 4 quadros, **todas as poças da sala se contraem** e o som é sugado. Então um disco branco-dourado de borda dura se expande em 3 faixas, e **todas as sombras da sala giram para fora**, em leque, a partir do centro. Os inimigos ficam brancos por 2 quadros e depois tontos, com estrelinhas lilás. Som: um tutti da banda inteira, com um sino.
5. **Inspiração do Bochecha.** Ele começa a inflar. Todas as chamas num raio de 8 m **se inclinam para ele**, a fuligem do chão corre em fios, o lençol mais perto se curva para dentro e a música passa por um filtro de graves. No sopro, as chamas deitam para o outro lado, fitas de vento com listras rolando atravessam o cone, e os lençóis estalam como vela de barco.
6. **A riscada do Risco.** Um smear de 1 quadro em forma de gota rosa. Na cabeça dele, uma estrela de 6 pontas branca e rosa por 2 quadros. Um risco de fogo fica no chão por 3 s, com chamas pequenas em flipbook de 12 quadros, e cria uma fileira de sombras curtas ao longo da linha. Som: "tssk" de fósforo, seguido de um chiado que vai sumindo.
7. **O balanço da Candeia.** A lanterna desenha um arco de luz âmbar feito dos **pontinhos da lata esticados** em traços. No impacto, a lata soa como um sino de lata, e os pontos de luz se espalham no chão como moedas, sumindo em 20 quadros. A poça dela pulsa uma vez.
8. **O Giro do Farolete.** O feixe dá uma volta completa em 1,5 s, com faixas girando dentro do cone. **As sombras de todos os inimigos varrem o chão como ponteiros de relógio**, e toda vez que uma sombra passa por um aliado ouve-se um "tic" de relógio e ela é pregada. Som: uma sirene de nevoeiro grave por baixo.
9. **O estouro do Fole.** Inflação de 2,2×, a sanfona fica lisa, hold de 0,75 s com um apito subindo, silêncio de 2 quadros, e então o estouro: as chamas presas saem em centenas de arcos coloridos, o couro cai como lençol e a câmera sobe para seguir as chamas até as janelas da vila. Som: um estampido seco, uma chuva de sininhos e, por fim, o ronco do Fole pequeno.

### Legibilidade com 4 jogadores

- **O perigo encolhe, a ajuda cresce.** Só os inimigos usam anéis que se fecham e a cor lilás. Só os heróis usam formas que se abrem. A regra vale para todo efeito do jogo, e um script pode conferir isso.
- **Cada jogador é identificado por 4 canais:** cor da luz, padrão no chão, forma da silhueta e um marcador de interface (triângulo, círculo, quadrado e losango). Mesmo que a cor colapse com daltonismo, os outros três seguem distintos [pesquisa: a prova de estilo mostrou o colapso de cor em `extra-prova-de-estilo-boneco-cordel.md` 1.4].
- **Herói nunca fica escuro por inteiro:** os olhos e a fonte de luz ficam sempre acesos, mesmo quando Abafa (ficam a 40%). Atrás de parede, o herói aparece em silhueta chapada na cor dele (raio-X por stencil, que funciona no Compatibility) [pesquisa: `godot-render-vfx.md` 0.4].
- **No máximo 3 efeitos primários por vez.** Os efeitos dos aliados aparecem com 60% de opacidade na tela de cada jogador, no online.
- **Inimigos comuns ficam sempre mais escuros que os heróis** e só têm olhos lilás. A forma de cada inimigo se distingue na miniatura 320×180.
- Portões em toda captura de bioma, como pede `direcao-de-arte.md`: cinza, borrão, miniatura, daltonismo e o estresse de 4 heróis, 20 inimigos e 6 efeitos.

---

## 10. Som e música em 5 linhas

1. A trilha é uma **banda de serenata noturna**: violão de sete cordas, clarinete, flauta, cavaquinho e uma percussão de latas e **caixa de fósforo**, longe do forró e do baião de Cordels & Spells.
2. A música tem camadas que seguem a luz: sala escura toca só baixo e caixa de fósforo, cada lampadário aceso soma um instrumento, e o Clarão toca a banda inteira.
3. Cada luz tem um timbre: a Candeia soa a lata e sino, o Risco a chiado de enxofre, a Lumeira a vidro e sininho, e o Farolete a sirene de nevoeiro.
4. A inspiração dos inimigos **suga o som** (filtro de graves e volume baixando), e o silêncio antes do sopro é a telegrafia sonora mais forte do jogo.
5. As vozes são resmungos e assobios sem palavras, gerados por síntese com regra, e cada herói tem 12 sons-base (susto, esforço, riso, "prega!", "vai!").

---

## 11. Controles

| Ação | Teclado e mouse | Controle | Toque (celular deitado) |
|---|---|---|---|
| Andar | WASD | Analógico esquerdo | Analógico virtual à esquerda (aparece onde o dedo toca) |
| Mirar | Mouse | Analógico direito (com auxílio de mira de 15°) | Automático: mira o inimigo mais perto na direção do movimento. Arrastar o botão de ataque mira manualmente |
| Atacar / pregar | Botão esquerdo | X / Quadrado | Botão grande à direita. Prega sozinho quando o golpe acerta uma sombra |
| Habilidade | Botão direito | Y / Triângulo | Botão médio acima do ataque |
| Esquivar | Espaço | A / Xis | Botão médio à esquerda do ataque, ou deslizar o polegar direito |
| Brilhar | Shift (segurar) | RT / R2 (segurar) | Botão de luz: segurar = Brilhar |
| Abafar | Ctrl (segurar) | LT / L2 (segurar) | Botão de luz: tocar duas vezes = alterna Abafar |
| Clarão | Botão direito + Shift | Y + RT | Botão de Clarão que aparece só quando a barra enche |
| Passar o fogo / interagir | E (segurar) | B / Bola (segurar) | Aparece como botão contextual ao lado do ataque, só perto de um aliado ou lampadário |
| "Prega!" (pedido à IA) e emotes | Q | Direcional para cima | Botão pequeno no topo direito |
| Trocar de herói (solo) | Tab | Select / Share | Tocar no retrato do outro herói |

As entradas usam G.U.I.D.E v0.15.1 (`GUIDEVirtualStick` e `GUIDEVirtualButton` no toque) [pesquisa: `extra-pilha-unica-godot-4-7.md` 0]. No celular, o modo padrão é "assistido": a mira é automática e a pregada acontece sozinha. Para quem quer controle total, há o modo "preciso".

---

## 12. Fatia vertical e marcos

### Fatia vertical: "Varal dos Lençóis, primeira noite"

O objetivo é provar quatro coisas: **(1) a pregada de sombra é divertida em dupla; (2) a animação parece de estúdio também no celular; (3) a luz recortada não parece slop; (4) o jogo roda a 30 FPS estáveis num celular intermediário pela Web.**

Conteúdo exato:
- **Vila mínima:** o Lumaréu com 2 estágios (0 e 1), 4 casas cujas janelas acendem no estágio 1 e 1 morador que explica as regras com 3 falas.
- **2 heróis jogáveis:** Dona Candeia e Risco, com kit completo (básico, habilidade, Brilhar, Abafar, esquiva, passar o fogo e Clarão em dupla).
- **Companheiro de IA** com o comportamento de "ficar do lado oposto" e a troca de herói.
- **3 inimigos:** Abafador, Bochecha e Fuligem.
- **4 salas do Varal dos Lençóis**, com lampadários e pelo menos 2 varais de lençol que recebem sombra, e 1 sala de descanso.
- **O Fole completo** (3 fases, introdução e morte), numa versão menor da Forja Fria com **2 braseiros** (o modo de 2 jogadores).
- **8 pavios.**
- **9 efeitos-assinatura** (todos os da seção 9, com o Giro do Farolete substituído por um efeito da Candeia, porque o Farolete fica fora da fatia).
- **Modos:** solo com IA, 2 jogadores locais com controles (PC), Web no celular com toque. **O online fica fora da fatia.**
- **Animação:** cerca de 30 clipes por herói (a lista mínima de `animacao-principios.md` 16.1), 12 por inimigo e 20 para o Fole.
- **Medição:** a ficha de desempenho do teste já publicado, rodada sobre a fatia no celular do usuário [pesquisa: `extra-contexto-real-celular-coop.md` 2].

Antes da fatia, há uma **prova de estilo de 1 semana**: 1 herói, 1 Abafador, 1 sala do Varal, a sombra planar no esqueleto, as poças no chão, os olhos SDF e os portões em cena escura. Se a prova falhar nos portões de legibilidade, o conceito muda antes de gastar a fatia.

### Os 3 marcos depois da fatia

1. **Marco 1, "Quatro luzes e rede":** Lumeira e Seu Farolete com kit completo, as 6 interseções de par, **online por WebRTC de 2 a 4** com sinalização e TURN, pausa automática quando o host sai do aplicativo, e o bioma Brejo das Velas com Goteira. Teste com o grupo real do usuário.
2. **Marco 2, "A Noite inteira":** o bioma Chaminés de Breu com o Bocejo, a Forja Fria com 4 braseiros, a meta-progressão de 10 estágios, os 24 pavios, a oficina de lata e o salvamento entre biomas.
3. **Marco 3, "Polimento e lançamento":** modo Noite sem Lua, a segunda arma de cada herói, celulares como controle numa tela grande (modelo AirConsole), versão desktop em Forward+ com névoa volumétrica nos braseiros e no Lumaréu, e a preparação para a Steam com Remote Play Together.

---

## 13. Viabilidade neste pipeline

### 13.1 O que a pesquisa já comprova

- **Animação em degraus do Blender ao Godot sem perder poses:** chaves CONSTANT viram STEP e depois NEAREST, com import a 60 fps e o otimizador desligado (erro zero em todos os casos) [pesquisa: `animacao-principios.md` 7.3 e `extra-pilha-unica-godot-4-7.md` 0].
- **Smear e squash por shader de vértice no Compatibility** [pesquisa: `animacao-principios.md` 8.3].
- **`SpringBoneSimulator3D` e `LookAtModifier3D`** prontos no motor [pesquisa: `animacao-principios.md` 1.6].
- **Toon por `light()` e contorno idênticos nos dois renderers**, com diferença média de 1,3 a 1,9 níveis em 255 [pesquisa: `extra-prova-de-estilo-boneco-cordel.md` 1.1].
- **Raio-X por stencil, glow e distorção de tela funcionam em WebGL2 real** [pesquisa: `godot-render-vfx.md` 0].
- **Personagem com esqueleto gerado só por `bpy`**, com rig de 25 ossos em 0,02 s [pesquisa: `extra-prova-de-estilo-boneco-cordel.md` 2].
- **WebRTC com host no navegador** para 4 jogadores [pesquisa: `extra-contexto-real-celular-coop.md` 5.1].
- **Sombra real é proibitiva na Web** (+64% de tempo de quadro, primitivas ×3) [pesquisa: `extra-contexto-real-celular-coop.md` 2.4]. Este conceito **não usa sombra real**, e é justamente aí que ele economiza.
- **O contorno por stencil dobra os triângulos.** Este conceito **não precisa dele** nos personagens, porque a silhueta já é a borda e o rim vem do shader.

### 13.2 O que ainda é risco (precisa de prova)

1. **Sombra planar em malha com esqueleto no Compatibility [risco].** É a peça central e não foi testada aqui. A técnica é antiga e simples (achatar os vértices já deformados no plano do chão, a partir da posição da luz, num segundo material), mas é preciso confirmar três coisas: que o shader de vértice recebe o vértice já deformado pelo esqueleto no Compatibility, que a sombra sobre lençóis verticais funciona com o mesmo shader e qual é o custo real com 20 inimigos. **Plano B:** sombras de inimigos comuns como cartões de silhueta (um quad esticado com a silhueta assada no Blender em 8 direções), e sombra de pose completa só para heróis, elites e chefe.
2. **Array de uniforms no shader do chão na Web [risco baixo].** 8 luzes × 2 `vec4` é pouco para o WebGL2, mas é preciso confirmar como o Godot 4.7.2 passa arrays por shader global ou por material. **Plano B:** uma textura de dados de 8×2 pixels atualizada a cada quadro.
3. **Faixas de cor (banding) em cena escura no RGBA8 [risco].** O pontilhado resolve na teoria, mas precisa ser medido em tela de celular de verdade.
4. **Legibilidade de cena escura em celular ao ar livre [risco].** Há uma opção "Noite clara" que sobe o valor do chão em 15 pontos e aumenta o rim. Precisa passar nos portões de cinza e borrão.
5. **A cor de vértice chega escurecida no Compatibility** [pesquisa: `extra-prova-de-estilo-boneco-cordel.md` 1.5]. Por isso, este conceito não usa cor de vértice nos personagens: o corpo é cor chapada por material, e as variações vêm de uniforms por instância.
6. **Volume de animação.** São 4 heróis × 30 clipes, 5 inimigos × 12 e um chefe com 20, cerca de 200 clipes no total. O gerador de rig compartilhado (3 proporções) e um "dicionário de poses" reaproveitado entre heróis da mesma proporção reduzem o custo, mas o tempo de autoria por script ainda não foi medido.

### 13.3 Custo de render na Web (estimativa a validar no aparelho)

Referência: a cena de estresse publicada, cuja etapa D (sem contorno e sem glow, 3D a 70%) foi a mais barata, com 72 draw calls e 72 mil primitivas [pesquisa: `extra-contexto-real-celular-coop.md` 2.4]. Os números do container servem só para comparação relativa.

| Item | Estimativa para 4 heróis + 20 inimigos + 6 efeitos |
|---|---|
| Heróis (4 × 5.000 triângulos) | 20 mil triângulos, 8 draw calls |
| Sombras de pose dos heróis (2 por herói, malha de 1.500 triângulos) | 12 mil triângulos, 8 draw calls |
| Inimigos (20 × 2.000) | 40 mil triângulos, 20 draw calls |
| Sombras de inimigos (Web: cartões, 2 por inimigo, com MultiMesh) | menos de 1 mil triângulos, 2 draw calls |
| Cenário (chão com o shader de poças + peças em MultiMesh) | cerca de 15 mil triângulos, 20 a 30 draw calls |
| Efeitos (flipbooks, fitas, halos em quads aditivos) | de 10 a 20 draw calls |
| Pós-processo | glow do Compatibility apenas nos núcleos, ou **halos em quads no lugar do glow** em aparelhos fracos |
| **Total** | **cerca de 90 mil triângulos e de 70 a 90 draw calls**, perto da etapa D (a mais barata), sem contorno por stencil e sem sombra real |

Regras de orçamento herdadas da pesquisa: 3D a 60–75% da resolução física, DPR efetivo limitado a 1,5, alvo de 30 FPS travados no celular intermediário, ondas de 15 a 20 inimigos visíveis e picos curtos de 30 [pesquisa: `extra-contexto-real-celular-coop.md` 4]. O shader do chão com 8 luzes custa por pixel. É o item a medir primeiro, porque ele cobre quase toda a tela.

**No PC (Forward+):** névoa volumétrica nos braseiros e no Lumaréu, reflexo real (SSR) na água do Brejo, sombra de pose para todos os inimigos e mais luzes de efeito. A arte continua a mesma: o PC soma atmosfera, não muda o estilo.

---

## 14. Riscos e como mitigar

| # | Risco | Gravidade | Mitigação |
|---|---|---|---|
| 1 | **"Lanterninha na noite" é um clichê de imagem gerada por IA** | Alta | Luz recortada com bordas duras, proibição de bokeh e de pó mágico, glow com teto e as 10 regras de 7.3 conferidas por script. Na prova de estilo, um teste cego: se "parece imagem de IA" aparecer entre as 3 palavras de quem olha, a direção é revista |
| 2 | **Cena escura ilegível no celular** (sol, brilho baixo, 4 jogadores) | Alta | Chão em valor médio, não preto. Heróis sempre com olhos e fonte acesos. Opção "Noite clara". Portões de cinza, borrão e miniatura em toda captura |
| 3 | **A sombra planar não funcionar bem em malha com esqueleto no Compatibility** | Alta | É a primeira coisa a testar, na primeira semana. O plano B (cartões de silhueta assados) mantém a mecânica e perde só um pouco da vitrine nos inimigos comuns |
| 4 | **A pregada é difícil de entender** ("onde está a sombra que eu posso pregar?") | Média | A metade pregável da sombra recebe uma borda fina na cor de quem pode pregar. A primeira sala do Varal ensina com lençóis, onde a sombra é grande e óbvia. No toque, a pregada é automática |
| 5 | **Vizinhos de tema** (Lanterns com mariposas; Schatte, que prega sombras no solo; Sky e Journey, com capas que brilham) | Média | Sem mariposas, sem capas luminosas e sem "criança de luz". A mecânica é cooperativa e geométrica. Heróis cômicos e atarracados |
| 6 | **Confusão de nome com Lumara** | Baixa | O som é parecido, mas a escrita e o gênero não. Conferir no INPI e nas lojas antes de publicar e manter o nome reserva |
| 7 | **Daltonismo:** âmbar e verde-limão se aproximam na deuteranopia | Média | Os 4 canais de identidade (cor, padrão, silhueta e marcador) e o teste de daltonismo nos portões |
| 8 | **Volume de animação** (cerca de 200 clipes) | Média | Gerador de rig com 3 proporções, poses compartilhadas, a fatia com 2 heróis e a rubrica de `animacao-principios.md` 15 para cortar cedo o que não presta |
| 9 | **Latência no online** quebra a pregada e o Clarão | Média | Mecânicas de posição, não de reflexo. Tolerância de 250 ms na pregada, janela de 500 ms no Clarão e telegrafias de 450 ms ou mais |
| 10 | **Host do celular congela ao sair do aplicativo** | Média | Pausa automática com aviso em `visibilitychange`. Quando houver um PC no grupo, o PC hospeda |
| 11 | **O shader do chão com 8 luzes pesa em celular de entrada** | Média | Reduzir para 4 luzes e 2 faixas no nível mais baixo. Medir na ficha de desempenho antes da fatia |
| 12 | **Tom fofo demais** para quem queria algo como Magicka | Baixa | O fogo amigo cômico, o caos do Clarão e a pancadaria da Candeia e do Risco mantêm o lado de "bagunça entre amigos". O teste com o grupo real decide |

---

## Fontes desta etapa

- Conferência de nome e vizinhos [busca, 27/11/2026]: [Lumara na Steam](https://store.steampowered.com/app/4064840), [Lanterns](https://lanterns-site.pages.dev/), [Schatte the Witch and the Fake Shadow](https://www.vgdb.co/games/schatte-the-witch-and-the-fake-shadow), [Clodhoppers](https://claymatic.games/clodhoppers), [Knuckle Creek](https://www.gamingonlinux.com/2026/11/claymation-slapstick-comedy-brawler-knuckle-creek-is-out-now-and-looks-awesome/), [Out of Words / Vokabulantis](https://berkeleyhistoricalsociety.org/?p=5994).
- Relatórios do projeto: `direcao-de-arte.md`, `animacao-principios.md`, `godot-render-vfx.md`, `pipeline-blender.md`, `extra-contexto-real-celular-coop.md`, `extra-diferenciacao-cordels-and-spells.md`, `extra-prova-de-estilo-boneco-cordel.md`, `extra-pilha-unica-godot-4-7.md`, `extra-geracao-de-fases-por-codigo.md`, `coop-rede.md`.

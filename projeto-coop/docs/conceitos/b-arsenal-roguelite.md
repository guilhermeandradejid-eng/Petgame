# Conceito B: Tralha da Cheia

**Ângulo:** roguelite de arsenal no estilo Lost Castle. É um brawler co-op de expedições curtas: as armas que você acha definem cada partida, e o corpo a corpo tem peso e muito *game juice*.

**Situação:** proposta para o usuário julgar. Nada está decidido. Data: 27/11/2026.

**Como ler as marcas.** **[pesquisa]** aponta um número ou achado de `docs/pesquisa/` (o arquivo vem citado). **[fonte]** aponta um link externo conferido nesta etapa. **[proposta]** é decisão de design minha, a validar em protótipo. **[não verificado]** é o que não consegui confirmar.

---

## 1. Nome, frase de venda e fantasia do jogador

### Nome: **Tralha da Cheia**

"Tralha" é a palavra do Norte e do Nordeste para traste, cacareco e também para o equipamento de pesca ("tralha de pesca"). "Cheia" é a enchente do rio. O nome diz o jogo: você luta com o que a enchente trouxe.

**Conferência de colisão** (buscas feitas em 27/11/2026):
- a busca pela frase exata "Tralha da Cheia" não devolveu jogo, produto ou obra; só lojas de pesca e um restaurante chamado "Tralha" ([busca](https://m.magazineluiza.com.br/busca/tralha/), [restaurante](https://booked.ai/restaurants/tralha-restaurant));
- "Tralha" com Steam, itch.io, roguelite e beat 'em up não encontrou jogo com esse título;
- um nome em inglês para a loja, "Floodhaul", também não colidiu. Os jogos mais próximos são *Flood* (battle royale) e *Flooded* (sobrevivência) ([Steam](https://store.steampowered.com/app/2986340), [RAWG](https://rawg.io/games/flood-2024)).

Ressalva: a Steam e a CDN de imagens estão bloqueadas neste ambiente (ver `extra-diferenciacao-cordels-and-spells.md`), então a busca cobre só o que o buscador indexou. Antes de registrar marca ou domínio, conferir no INPI e na Steam a partir de outra rede.

### Frase de venda

> **"O rio subiu e trouxe de tudo. Pegue um remo, um anzol ou uma âncora, passe a arma para o amigo no meio do golpe e quebre tudo rio abaixo."**

Versão curta, para a loja: *brawler co-op de 1 a 4 pessoas, num mundo de brinquedos de miriti, em que cada arma racha, voa de mão em mão e explode em lascas pintadas.*

### Fantasia do jogador

Você é um boneco de miriti, leve e pintado à mão, que vive num rio de palafitas. A **Cheia que não baixa** inundou tudo e trouxe criaturas inchadas de água. Você não é um guerreiro de armadura. Você é estivadora, balseiro, menino mergulhador ou calafate, e luta com ferramenta de porto: remo, bicheiro, pilão, tarrafa, âncora.

O prazer é o do Lost Castle (cada partida dá armas diferentes e você joga de outro jeito) com três coisas que ele não tem:

1. **A arma é um objeto físico do grupo.** Você arremessa a arma para o amigo, ele pega no ar e solta o golpe mais forte daquela arma.
2. **A arma acaba.** Cada uma tem um número de golpes. O último golpe é uma **Despedida**: um estouro em lascas pintadas, com o maior impacto do jogo. Quebrar é bom, não castigo.
3. **Há tralha grande demais para uma pessoa.** Uma âncora de balsa precisa de dois para girar.

O tema que amarra tudo é o **desapego**. O vilão é um acumulador que represou o rio para guardar tudo o que a correnteza traz. Os heróis vencem usando e largando.

---

## 2. Ciclo de jogo

### 30 segundos

1. Você entra numa sala de palafitas e vê **4 a 8 inimigos** com sinais claros de ataque (faixas pretas e amarelas no chão).
2. Combina golpes leves e pesados com a arma da mão. O golpe pesado **marca** o inimigo (enganchado, tonto, amarrado ou atolado).
3. Um parceiro aplica **outra** marca no mesmo inimigo e sai uma **reação** (a fisgada arremessa o inimigo tonto como projétil contra os outros).
4. Sua arma está no último entalhe. Você **arremessa** para a estivadora, que pega no ar e solta o **golpe de recepção**: a arma estoura em lascas e três inimigos saem voando.
5. Você pega uma arma nova do chão, que sobrou de um inimigo, e o ritmo recomeça.

### Uma sala (60 a 100 segundos)

- **Entrada:** a balsa encosta. A câmera mostra a sala inteira por 1 segundo, o tempo de ler a planta e o marco.
- **2 ou 3 ondas**, escolhidas de 12 a 16 modelos de onda por bioma (`extra-geracao-de-fases-por-codigo.md`, seção 7.2) **[pesquisa]**.
- **Saque instanciado:** cada jogador recebe o **próprio fardo** com etiqueta na sua cor, contendo 1 arma ou 1 remendo. Ninguém disputa.
- **Saída:** 2 portas mostram o tipo da próxima sala (combate, banca de achados, oficina, evento, desafio). O grupo vota entrando na porta; maioria em 3 segundos, empate resolvido pela ordem de chegada.

### Uma expedição (12 a 18 minutos)

Cada expedição desce **um bioma** do rio e termina num chefe.

| Trecho | Conteúdo | Tempo |
|---|---|---|
| Embarque | Escolha de herói; 1 arma inicial sorteada entre as já penduradas no Mural (ver meta) | 0,5 min |
| Corredeira 1 | 3 salas de combate e 1 banca de achados | 5 min |
| Remanso | Oficina da balsa: consertar arma, aplicar remendo, comprar com tampinhas | 1 min |
| Corredeira 2 | 3 salas (uma pode ser desafio: "só arremesso" ou "Tralha Grande") e 1 evento | 5 min |
| Chefe | Arena fixa, escrita por script | 3 a 5 min |

São **9 a 11 salas visitadas**, dentro da faixa de 8 a 12 salas e 12 a 19 minutos que o gerador de expedições já produz em teste (`extra-geracao-de-fases-por-codigo.md`, seção 1) **[pesquisa]**.

### A Grande Descida (opcional, cerca de 45 minutos)

Para quem joga no PC com amigos: as 3 expedições de bioma encadeadas numa só partida, com a quarta (a Comporta) no final. A arma não volta ao rio entre biomas. No celular, cada expedição se encerra sozinha e a vitória libera "embarcar direto" no bioma seguinte.

### Meta-progressão: o Flutuante

A base é um **flutuante** (casa-barco ancorada), que cresce entre expedições.

- **Mural de Lascas.** Toda arma que estoura deixa **1 lasca**. Com **3 lascas** da mesma arma, ela é **pendurada** no Mural: passa a poder sair como arma inicial e ganha 1 variação de pintura. Quebrar arma faz o jogo crescer. É a tradução mecânica do tema.
- **Tampinhas** (moeda da expedição) zeram ao fim da partida. **Lembranças** (moeda da base) vêm de chefes e desafios.
- **Cômodos do Flutuante**, com 3 níveis cada: Oficina da Mestra Breu (remendos novos no sorteio), Cozinha (+10 de vida inicial por nível), Rádio (mostra o tipo das salas 2 portas à frente), Varal (mais um espaço de achado), Cais (Tralha Grande nova liberada para as salas de desafio).
- **Progresso sempre do grupo.** O Flutuante é um só, salvo no aparelho do anfitrião e espelhado nos convidados. Lembranças ganhas em co-op valem para todos, sem inveja (`jogos-referencia.md`, pilar 8) **[pesquisa]**.

**Duração de sessão:** 15 minutos é a unidade (uma expedição). Três sessões curtas, ou uma Grande Descida, fecham um "ciclo" de história.

---

## 3. Co-op

### O que só existe porque há 2 a 4 pessoas

| Mecânica | Como funciona | Por que é co-op de verdade |
|---|---|---|
| **Passe e recepção** | Segurar *arremessar* mira o aliado mais próximo dentro de 9 m. A arma voa em arco de 0,45 s. Quem pega no ar tem **1,5 s** para soltar o **golpe de recepção**: finalizador da família da arma, com +50% de dano e marca garantida | A arma melhora ao passar de mão. É interdependência por incentivo, nunca por trava (`jogos-referencia.md`, resumo 4) **[pesquisa]** |
| **Reação de marcas cruzadas** | A reação vale 100% quando as duas marcas vêm de pessoas diferentes. Vinda de uma pessoa só, vale 60% | "Eu preparo, você detona", a recomendação central da pesquisa (`jogos-referencia.md`, seção 6, lacuna 1) |
| **Tralha Grande** | Âncora de balsa, remo de batelão, canoa virada, poste de trapiche. Uma pessoa só **arrasta** (40% da velocidade, sem atacar). Duas pessoas **erguem**, e cada uma controla um lado do giro. O golpe sai quando as duas apertam ataque dentro de **0,3 s**; fora da janela, sai fraco e engraçado | Golpe sincronizado com um palco claro para a animação (mecânica 11 da pesquisa). O parceiro de IA sempre responde |
| **Fogo amigo construtivo** | O bicheiro **puxa** o aliado agarrado por um inimigo. Um golpe pesado num aliado o **lança** 4 m, o que serve para atravessar vão. A rede num aliado vira **escudo** de 1 golpe | Errar vira técnica (`jogos-referencia.md`, lacuna 2) **[pesquisa]** |
| **Gaiola** | O inimigo Gaiola prende um jogador. Só outro jogador solta, batendo na gaiola (3 golpes) ou puxando com gancho | Pede socorro sem tirar o preso do jogo: dentro da gaiola, ele ainda pode arremessar |

### Sozinho

Duas opções, escolhidas no embarque:

1. **Parceiro de IA** (padrão). Outro herói, controlado por árvore de comportamento em **Beehave** (GDScript puro, roda na Web; `coop-rede.md`, seção 0, ponto 12) **[pesquisa]**. Regras do parceiro, adaptadas do Bosco e da Ellie:
   - ele **prepara** (aplica marca) e deixa você detonar;
   - ele **sempre** pega o seu passe e devolve no golpe de recepção;
   - na Tralha Grande, ele segura o outro lado e ataca na janela, com 85% de acerto;
   - nunca rouba saque nem o último golpe no chefe; corre para reviver você uma vez por sala;
   - um botão de **chamado**: tocar num inimigo diz "foque esse"; segurar diz "me passa a arma".
2. **Troca de herói** (no estilo Full Metal Furies). Você controla dois heróis e alterna com um botão. O que fica de fora segue a IA. O passe vira troca: arremessar a arma e trocar de herói no ar faz você mesmo pegar a arma.

Escala de dificuldade: o parceiro de IA conta como **0,5 jogador** na fórmula de inimigos (`coop-rede.md`, seção 7.2) **[pesquisa]**.

### Local, no mesmo aparelho

- **PC ou TV:** 1 a 4 jogadores com 2 teclados (metade esquerda e metade direita) e controles, entrando e saindo a qualquer momento. Câmera de grupo com limite de zoom, parede invisível na borda e teleporte de quem ficar 2,5 s fora do quadro (`coop-rede.md`, seção 0, ponto 4) **[pesquisa]**.
- **Celular:** 1 pessoa no toque. A segunda só entra com controle Bluetooth, raro nesse público (`extra-contexto-real-celular-coop.md`, ponto 5) **[pesquisa]**. Por isso o solo com parceiro de IA é o modo principal no celular.
- **Tablet:** 2 pessoas no toque é possível mas apertado. Não prometer.

### Caminho para online

A arquitetura nasce pronta para rede, mesmo sem rede: cada jogador é `(peer_id, slot)`, a entrada é um dado serializável e inimigos, dano, saque e sorteio rodam só no anfitrião (`coop-rede.md`, seção 8) **[pesquisa]**. Em seguida:

1. **Fase 2:** WebRTC no navegador, com o anfitrião no navegador e sala por código. Isso já foi provado com 1 anfitrião e 3 clientes, RTT de 33 a 37 ms em localhost (`extra-contexto-real-celular-coop.md`, ponto 6) **[pesquisa]**.
2. **Fase 3:** sinalização própria e TURN (Cloudflare), reconexão, e o herói de quem caiu da rede vira IA até a pessoa voltar.
3. **PC:** Remote Play Together da Steam transforma o co-op local em online sem escrever rede.

**Regras pensadas para 150 ms de ida e volta**, que é o orçamento de celular para celular (`extra-contexto-real-celular-coop.md`, seção 5) **[pesquisa]**:
- passe decidido no anfitrião, com **janela de pegada de 300 ms**. O cliente mostra a pegada na hora, como efeito cosmético, e o anfitrião confirma;
- marcas duram 4 s, então a reação nunca depende de sincronia fina;
- a janela da Tralha Grande sobe de 0,3 s para **0,45 s** no online;
- telegrafia de inimigo comum de no mínimo 400 ms;
- se o anfitrião sair do aplicativo, a partida pausa com aviso "aguardando o barqueiro".

### Fogo amigo

Três níveis no menu. O padrão é **Brincadeira**:

| Nível | Dano em aliado | Empurrão e marca em aliado | Uso |
|---|---|---|---|
| Desligado | 0 | não | crianças, celular com mira automática |
| **Brincadeira** (padrão) | 0 | sim: empurra, lança, puxa, enrola | comédia e técnica, sem punir |
| Rio Bravo | 25% (cai para 15% com 4 jogadores) | sim | grupos que querem o caos do Magicka |

Todo golpe que pode atingir aliado usa a **mesma linguagem de perigo** dos inimigos (`direcao-de-arte.md`, seção 7.3, regra 3) **[pesquisa]**.

### Morte e reviver: a Boia

- Com 0 de vida, o boneco **não morre: boia**. Miriti flutua, e é por isso que o mundo funciona assim. O herói vira uma boia pintada com a cabeça para fora e continua jogando:
  - nada a 50% da velocidade;
  - pode **apitar**: atrai a atenção de 1 inimigo por 2 s (recarga de 6 s), o que cria viradas;
  - pode pegar e devolver passes, mas não ataca.
- **Reviver:** um aliado segura *interagir* perto da boia e joga a corda. Um anel diminui em volta da boia; soltar dentro da faixa ideal revive com 50% de vida, fora dela com 25% (ponto ideal no estilo Lost Castle 2, `jogos-referencia.md`, seção 3.4) **[pesquisa]**. Tempo base: **2,0 s + 0,25 s por jogador extra** (`coop-rede.md`, seção 7.2) **[pesquisa]**.
- **Limite:** cada nova queda na mesma sala aumenta o tempo de reviver em 1 s. Se todos boiarem ao mesmo tempo, a expedição acaba.
- **Solo:** o parceiro de IA revive uma vez por sala. Sem parceiro (modo troca de herói), há **uma reanimação automática por chefe**, a correção que o Nightreign teve de fazer depois do lançamento (`jogos-referencia.md`, seção 5.3) **[pesquisa]**.

### Saque

- **Armas e remendos:** instanciados, um fardo por jogador, com etiqueta pintada na cor dele. Trocar é passar a arma.
- **Achados** (efeitos passivos): na banca de achados, cada jogador escolhe 1 entre 3 opções próprias.
- **Tampinhas:** caixa comum do grupo. Qualquer um compra na oficina, e as compras aparecem no painel de todos.
- O parceiro de IA não pega saque. O dele é gerado à parte, pelo sistema.

---

## 4. Combate e sistemas

### Verbos do jogador (7)

| Verbo | Entrada | Detalhe |
|---|---|---|
| Golpe leve | toque | combo de 3 por família de arma |
| Golpe pesado | segurar (0,25 s ou mais) | aplica a marca da família; carga até 0,8 s |
| Esquiva | botão | 8 a 14 quadros invulnerável; cancela a recuperação dos golpes |
| Arremessar ou passar | toque arremessa para a frente; segurar mira um aliado | a arma arremessada fere e marca; no chão, quem chegar primeiro pega |
| Trocar | botão | 2 espaços (mão e costas). **A troca é um golpe**: tirar a arma das costas já ataca |
| Pegar ou interagir | contextual | pegar arma, erguer Tralha Grande, reviver, abrir fardo |
| Chamado | botão (controle e teclado) ou toque longo no inimigo | marca alvo para o grupo e para o parceiro de IA |

### Armas: 8 famílias e 40 armas na versão completa

Cada família tem **1 conjunto de golpes** (3 leves, 1 pesado, 1 arremesso, 1 recepção, 1 Despedida). As 5 armas de cada família mudam números, alcance, remendo de fábrica e pintura. Isso mantém a animação produzível (ver seção 8).

| Família | Papel | Marca no pesado | Fôlego (golpes até a Despedida) | Dano leve / pesado | Exemplos (5 por família) |
|---|---|---|---|---|---|
| **Remos** | arco largo, empurra em grupo | Atolado (espirra lama) | 30 | 9 / 26 | Remo de Faia, Remo-Pá Largo, Remo Quebrado (2 mãos, curto), Remo de Proa, Remo Pintado |
| **Ganchos** | puxa e controla | Enganchado | 26 | 8 / 22 | Bicheiro, Arpão de Corda (vai e volta), Gancho de Estiva, Fateixa Pequena, Anzol de Pirarucu |
| **Malhos** | lento, atordoa | Tonto | 20 | 14 / 40 | Malho de Calafate, Mão de Pilão, Marreta de Estaca, Batedor de Roupa, Maço de Telha |
| **Redes** | à distância curta, área | Amarrado | 6 lances | 6 / 18 (área) | Tarrafa, Puçá, Rede de Dormir (enrola 2), Rede de Arrasto, Matapi (armadilha que fica no chão) |
| **Cutelos** | rápido, dupla mão | não marca: **afia** (+30% de dano em alvo marcado e +1 s na marca) | 40 | 6 / 16 | Cutelo de Peixeiro, Faca de Escama, Par de Colheres de Pau, Tesoura de Rede, Raspador |
| **Varas** | alcance de 3,2 m, salto | não marca: **varejada** (salto sobre inimigos) | 32 | 8 / 20 | Zinga, Vara de Pescar, Cabo de Vassoura, Bambu de Varal, Mastro Partido |
| **Âncoras** | giro, peso máximo | Atolado e empurrão | 16 | 18 / 48 | Fateixa, Âncora de Canoa, Corrente com Cadeado, Peso de Rede, Poita de Pedra |
| **Bodoques** | à distância | Amarrado (caroço com linha) em 1 de 3 tiros | 24 disparos | 7 / 15 | Bodoque de Forquilha, Zarabatana de Talo, Estilingue Duplo, Atiradeira de Caroço, Funda |

Mais **4 Tralhas Grandes** (Âncora de Balsa, Remo de Batelão, Canoa Virada, Poste de Trapiche), que aparecem em salas de desafio e na luta contra o chefe e não podem ser carregadas para fora da sala.

**Fôlego e Despedida.** O fôlego aparece como entalhes na arma e no ícone. No último entalhe, o próximo golpe que acertar vira a **Despedida** automaticamente: dano ×3, empurrão em área de 2,5 m, hit-stop de 14 quadros e estouro em lascas (ver VFX). A Mestra Breu repara armas: +10 entalhes por uso, uma vez por sala.

**Remendos (12 na versão completa).** São objetos presos visivelmente na arma, um por arma, aplicados na oficina ou achados no fardo: Fita (chance de amarrar), Prego Torto (chance de atordoar), Breu (gruda: o arremesso fica preso no inimigo), Chumbada (mais pesada: +40% de empurrão e hit-stop, −15% de velocidade), Boia de Isopor (a arma arremessada volta), Lata (bloqueia 1 projétil), Sino (o golpe de recepção cura 5 do aliado), Pena, Corda Comprida, Ponta de Prego, Pintura Fresca, Rolha.

**Achados (30 na versão completa).** Efeitos passivos de expedição, como:
- *Rolha da Sorte:* +4 de fôlego em toda arma que você pegar;
- *Mão Boa:* cada pegada no ar devolve 3 entalhes;
- *Fita de Arremate:* arremessos voltam para a sua mão;
- *Apito Rachado:* o apito da Boia dura 4 s;
- *Cuia de Lama:* toda esquiva deixa uma poça que atola;
- *Ombro de Estiva:* arrastar Tralha Grande sozinho a 70% da velocidade.

### Marcas e reações

**4 marcas** (duram 4 s, cada inimigo carrega no máximo 2) e **6 reações**, uma para cada par:

| Marca A + Marca B | Reação | O que acontece |
|---|---|---|
| Enganchado + Tonto | **Fisgada** | o próximo puxão arremessa o inimigo como projétil (dano 30 em quem ele atingir) |
| Enganchado + Amarrado | **Varal** | liga 2 inimigos por linha até 5 m; o que bate num derruba o outro |
| Enganchado + Atolado | **Atracado** | o inimigo vira ponto de amarra por 5 s: qualquer jogador com gancho ou vara se puxa até ele (mobilidade) |
| Tonto + Amarrado | **Pião** | o inimigo gira 2 s batendo nos vizinhos (12 por toque) |
| Tonto + Atolado | **Estaca** | o inimigo afunda até a cintura por 3 s e leva crítico ×1,5 de todos |
| Amarrado + Atolado | **Trouxa** | vira um fardo de lama que qualquer jogador ergue e arremessa (dano 35 em área) |

É a matriz pequena e legível que a pesquisa recomenda (`jogos-referencia.md`, recomendação 2) **[pesquisa]**, com uma diferença deliberada: **as matérias são consequências de ferramentas de porto**, nunca fogo, gelo ou raio.

### Inimigos: 5 arquétipos do primeiro bioma

Todos são "**Inchados**": coisas do rio que beberam Cheia demais e ganharam vida. Toda telegrafia segue a mesma regra: **pose segurada + faixas pretas e amarelas no chão com o raio real + som característico no fim da espera**. Números em quadros a 60 fps (tabela-base em `animacao-principios.md`, seção 5.1) **[pesquisa]**.

| Inimigo | Silhueta | Ataque e telegrafia | Resposta esperada |
|---|---|---|---|
| **Bucho** (comum) | bexiga de peixe redonda com pezinhos | Incha (squash de 1,0 para 1,3 com volume constante), **30 quadros**, e se joga de barriga num círculo de 1,6 m. Fica 40 quadros no chão | Esquivar e bater na janela. Estoura e desincha ao morrer |
| **Gaiola** (agarrador) | caranguejo feito de gaiola de passarinho | Abre a porta da gaiola e range, **36 quadros**, e avança 3 m numa faixa reta. Prende 1 jogador | Aliado solta (3 golpes ou gancho). Preso ainda arremessa |
| **Caroceiro** (à distância) | cacho de frutos de palmeira com boca | Linha de mira listrada visível por **40 quadros**, cospe 3 caroços em leque. Recua se alguém chega perto | Fechar distância, ou pegar o caroço caído e jogar de volta |
| **Lata-Velha** (pesado) | lata de querosene amassada que rola | Se fecha e treme **45 quadros**, com a faixa da rota no chão, e rola reto até bater em parede. **Golpes desviam a rota** | Bater de lado para mandá-la contra outros inimigos (é fogo amigo dos inimigos a seu favor) |
| **Capataz da Comporta** (elite) | homem-porta com escudo de folha de comporta | Escudo frontal bloqueia tudo. Golpe de porta: **48 quadros** de levantada, onda de 4 m em cone. A cada 3 golpes, crava o escudo no chão por 60 quadros | Flanquear, ou **enganchar o escudo** e puxar. Pede dois lados: um puxa, outro bate |

Escala por número de jogadores: quantidade `1 + 0,35·(n_eff − 1)` e vida `1 + 0,15·(n_eff − 1)`, recalculadas ao entrar na sala, sem escalar atordoamento (`coop-rede.md`, seção 7.2) **[pesquisa]**. No celular, no máximo **10 a 12 inimigos visíveis**, com picos de 15 (seção 13).

### Chefe do Trapiche Velho: a **Garça-Guindaste**

Uma garça de miriti do tamanho de uma casa, fundida a um guindaste de carga, num trapiche que está afundando. Ela pesca tralha do rio para levar ao acumulador rio acima.

**Arena.** Trapiche Grande de 24 × 14 m, com 3 baias de contêiner nas laterais e água no fundo e na frente. O piso tem 3 zonas de tábua que podem ceder.

**Abertura (câmera de palco).** A câmera desce para a vista frontal de teatro de brinquedo. A garça ergue o pescoço em três tempos (antecipação longa), abre o bico, solta um rangido de polia e um contêiner cai na arena. A câmera sobe para a vista de camarote e a luta começa.

**Fase 1 (100% a 65%): "Pesca".**
- **Bicada-Anzol:** a cabeça recua e treme **54 quadros**. Um alvo listrado de 2 m segue o jogador e trava nos últimos 18 quadros. O bico crava no chão por **70 quadros**: é a janela de punição. Se acertar, o jogador é fisgado, carregado e largado na água (vira Boia na hora, mas pode nadar de volta).
- **Varrida de Pescoço:** gira o pescoço em arco de 180° rente ao chão. Telegrafia de **60 quadros**: o pescoço se enrola como mola, com faixa em arco. Pula-se com varejada ou se esquiva.
- **Lição da fase:** quando o bico crava, um gancho **prende o bico** (Enganchado) e um malho **atordoa** (Tonto). A Fisgada arranca a garça do lugar e ela cai de lado: 4 s de golpes livres.

**Fase 2 (65% a 30%): "Carga".**
- A garça larga **contêineres** do guindaste: sombra listrada de 3 × 3 m por **75 quadros**, e o contêiner cai. Cada contêiner vira **obstáculo** e **baú**: 3 golpes o abrem, e dentro há armas (a chefe alimenta o arsenal do grupo).
- Um contêiner em cada três traz **2 Buchos**.
- A partir de 3 jogadores, ela usa os dois ataques da fase 1 ao mesmo tempo, em alvos diferentes (o "+1 padrão" de `coop-rede.md`, seção 7.2) **[pesquisa]**.

**Fase 3 (30% a 0%): "O trapiche inclina".**
- A garça puxa o próprio trapiche com o guindaste. O piso **inclina 8°** para o lado dela a cada 12 s e tudo o que está solto escorrega: armas no chão, Lata-Velha, jogadores parados.
- Uma **Âncora de Balsa** (Tralha Grande) aparece encalhada no centro. Dois jogadores erguem a âncora e acertam o **pé** da garça no golpe sincronizado: **Atracada**. A garça fica presa por 6 s e abaixa a cabeça, que é o único alvo crítico (×2).
- Solo: o parceiro de IA vai para a âncora assim que você chega perto dela.
- São necessárias 2 Atracadas para vencer, com 3 jogadores ou mais, ou 1 com até 2 jogadores, somadas ao dano normal.

**Fim.** O último golpe dispara **hit-stop global de 36 quadros** (a única pausa global do bioma), seguido de câmera lenta a 0,3× por 30 quadros. A câmera volta ao palco frontal: a garça perde a tinta em placas, o guindaste desaba na água e ela sai voando, como garça de novo, rio acima. Recompensa: 1 Lembrança por jogador e a liberação do Arpão de Corda no Mural.

**Durações-alvo:** de 3 a 5 minutos com 2 jogadores. Vida escalada por `1 + 0,60·(n_eff − 1)` (`coop-rede.md`, seção 7.2) **[pesquisa]**.

---

## 5. Heróis

Os 4 heróis compartilham **a mesma topologia de esqueleto** (mesmos nomes de osso, proporções diferentes). Assim as 8 famílias de armas são animadas uma vez e ajustadas por herói (seção 8). Cada um tem uma **massa escura** no corpo (saia, calça ou avental em tinta escura) para passar no teste de borrão, que a prova de estilo reprovou nos heróis claros (`extra-prova-de-estilo-boneco-cordel.md`, seção 4) **[pesquisa]**. Cada um tem também uma **forma de marcador no chão** (círculo, quadrado, triângulo, losango) para o daltonismo.

### Tiá Marola, a estivadora

- **Silhueta:** trapézio de base larga, ombros enormes, cabeça pequena com lenço amarrado no alto (um nó com duas pontas, que balançam em mola). Carrega um caixote nas costas que serve de espaço de arma.
- **Personalidade:** calma, lenta para começar e impossível de parar. Nunca corre se pode andar firme.
- **Kit:**
  - *Passiva Lombo:* carrega Tralha Grande sozinha a 70% da velocidade (os outros, 40%) e o pesado carrega 30% mais rápido;
  - *Habilidade Ombrada* (recarga de 8 s): investida de 4 m que leva junto todos os inimigos à frente e os larga em pilha;
  - *Recepção:* quando pega um passe, ganha 2 s de superarmadura.
- **Animação que expressa a personalidade:** antecipação mais longa do elenco (o peso se lê na espera), contato sem tremor nenhum e follow-through mínimo no corpo, como se o golpe não custasse esforço. Toda a ação secundária fica nas pontas do lenço e no caixote. O ciclo de andar tem 4 poses fortes, em 4s, com o quadril balançando.

### Seu Remanso, o balseiro

- **Silhueta:** uma linha vertical. Muito alto, muito magro, chapéu cônico de palha alto, sempre com uma zinga (vara de empurrar balsa) apoiada no ombro, mesmo quando segura outra arma.
- **Personalidade:** econômico, seco, irônico. Faz o mínimo de movimento e acerta.
- **Kit:**
  - *Passiva Alcance:* +25% de alcance em varas, remos e ganchos;
  - *Habilidade Varejada* (recarga de 6 s): salta 5 m sobre inimigos usando qualquer arma longa como vara e cai marcando Tonto;
  - *Recepção:* golpe de recepção sempre em área.
- **Animação:** poucas poses, holds longos e precisos. É o personagem em 3s e 4s: parece imóvel e de repente já bateu. Smear de 1 quadro bem comprido no contato. O chapéu é a única parte com mola. O idle é o único do elenco quase parado, com um piscar a cada 4 s.

### Piaba, o mergulhador

- **Silhueta:** pequena e redonda, máscara de mergulho enorme que cobre metade do rosto (a expressão vem da máscara embaçando ou brilhando, não de feições), pés de pato grandes.
- **Personalidade:** elétrico, exibido, sem noção do perigo. Comemora tudo.
- **Kit:**
  - *Passiva Mão de Goleiro:* pega arremessos automaticamente num raio de 2,5 m (os outros precisam estar parados ou a 1,2 m);
  - *Habilidade Mergulho* (recarga de 5 s): some no piso ou na água por 0,6 s e reaparece 6 m à frente, derrubando quem estiver em cima;
  - *Arremesso:* +40% de velocidade e de dano nos arremessos.
- **Animação:** o personagem do squash and stretch. Esticamento de 1,4 no início do mergulho, achatamento de 0,7 ao cair, quique de 2 a 3 vezes ao parar. Arcos largos e exagerados. Os pés de pato fazem *flap* atrasado no andar (overlapping action). Tem uma pose de comemoração própria para cada reação que ele dispara.

### Mestra Breu, a calafate

- **Silhueta:** assimétrica. Um braço normal e outro com uma luva de couro enorme presa a um malho de calafate. Carrega um balde de breu na cintura que pinga.
- **Personalidade:** artesã meticulosa e ranzinza. Inspeciona a arma antes de usar e reclama quando alguém quebra a dela.
- **Kit:**
  - *Passiva Remendo:* conserta a arma de um aliado ao bater nela de leve (+6 entalhes, recarga de 20 s);
  - *Habilidade Calafeto* (recarga de 10 s): passa breu numa área de 3 m; inimigos ficam Atolados e projéteis grudam no chão;
  - *Recepção:* a arma recebida ganha um remendo aleatório temporário.
- **Animação:** a pose de inspeção (olhar a arma de lado, com a cabeça inclinada) aparece no idle e depois de cada troca. É o "desenho sólido" do elenco: muda o peso de um lado para o outro por causa da luva. O balde pinga em degrau (ação secundária), e cada pingo deixa uma mancha pequena no chão por 2 s.

Na fatia vertical entram **Tiá Marola e Piaba**, os dois extremos de massa e de ritmo.

---

## 6. Mundo, biomas, tom e história

**O mundo.** O Rio de Mil Margens, um rio largo de palafitas, trapiches, igapós e serrarias. Todos os habitantes são **bonecos de miriti**: leves, pintados e flutuantes. Não há época histórica, não há sertão, cangaço, coronel nem cordel. O mundo é inventado. Ele toma a **linguagem material** do brinquedo de miriti, não personagens, festas nem lugares reais (seção 7, riscos na seção 14).

**A história em cinco linhas.** Todo ano o rio enche e baixa. Neste ano, não baixou. Rio acima, o **Açambarcador** construiu uma comporta para represar a correnteza e guardar tudo o que ela traz, porque não suporta perder nada. A água parada fez as coisas incharem e ganharem vida. Quatro trabalhadores do cais pegam o que sobrou e descem e sobem o rio para abrir a comporta, quebrando tralha pelo caminho. No fim, eles não derrotam o acumulador a pancadas: eles o fazem largar a última coisa que segura.

**Tom.** Comédia física de oficina e de cais. Os bonecos falam pouco, em frases curtas e bordões de trabalho ("Segura do teu lado!", "Essa era minha!", "Larga que eu pego!"). Nada de profecia, escolhido ou cristal mágico.

### Biomas (4), cada um com um verbo novo

| Bioma | Visual (telão em 3 estados de luz) | Perigo e verbo novo | Chefe |
|---|---|---|---|
| **Trapiche Velho** | cais de palafitas, barracas de feira cobertas de lona, guindastes; tons de ocre e verde-água | **tábuas-catapulta**: pisar na ponta lança o que está na outra ponta (armas, inimigos, aliados) | Garça-Guindaste |
| **Igapó dos Remos** | floresta alagada em que canoas ficaram presas no alto das árvores; verde-escuro e azul-petróleo | **correnteza**: faixas de água que empurram tudo, inclusive armas arremessadas, que fazem curva | Jacaré-Rabeta (jacaré de miriti com motor de popa no rabo) |
| **Serraria Alagada** | galpões de madeira, toras boiando, serra de fita parada; ferrugem e creme | **toras rolando**: podem ser chutadas como arma de sala | Mestre-Serra (homem-serra que corta o chão em listras) |
| **A Comporta** | represa gigante e depósito do Açambarcador, pilhas de coisas até o teto; cinza-azulado e dourado | **comportas cíclicas**: metade da sala inunda a cada 20 s, e quem está na água vira Boia temporária | O Açambarcador |

Kit de cenário por bioma, conforme o gerador testado: 3 telões, 6 marcos, 5 coberturas, 1 ou 2 perigos e 2 pendurados, cerca de **17 peças novas por bioma** (`extra-geracao-de-fases-por-codigo.md`, seção 7.1) **[pesquisa]**.

---

## 7. Direção de arte

### Escolha técnica: 3D toon, com sprites pré-renderizados só na interface

**Defesa com a pesquisa:**

1. **Um jogo de arsenal precisa mostrar a arma na mão.** São 40 armas, 12 remendos visíveis e 4 Tralhas Grandes, em 4 heróis. Em sprite, cada combinação de arma e remendo vezes direção vezes quadro vira atlas novo. Um único personagem com 12 animações em 8 direções já dá cerca de 960 quadros e 3 atlas de 4096 × 2048 (`godot-render-vfx.md`, seção 6.2) **[pesquisa]**. No 3D, a arma é uma malha presa ao osso da mão: **troca grátis**.
2. **A prova de estilo já comparou os dois** no mesmo boneco e escolheu 3D toon. O sprite do Cycles saiu só "um pouco mais nítido", e o ganho se recupera engrossando o contorno no 3D (`extra-prova-de-estilo-boneco-cordel.md`, seção 3.4) **[pesquisa]**.
3. **Paridade Compatibility × Forward+ medida:** diferença média de 1,3 a 1,9 em 255, desde que a estilização fique no material (`extra-prova-de-estilo-boneco-cordel.md`, seção 3.2) **[pesquisa]**.
4. **Câmera livre:** o 3D permite a troca entre camarote (combate) e palco (abertura de chefe, Flutuante), que em sprite exigiria um conjunto de sprites por inclinação.
5. **Memória e download na Web:** um boneco tem cerca de 0,3 MB em GLB, contra centenas de MB em atlas.

**O sprite pré-renderizado (Cycles com toon por emissão, 0,2 a 0,3 s por quadro)** fica para os ícones de arma, os retratos e os cartazes (`pipeline-blender.md`, seção 7) **[pesquisa]**. Assim, ícone e jogo saem do mesmo modelo, o que é uma regra anti-slop.

### Linguagem visual: "brinquedo de miriti"

O brinquedo de miriti é feito do talo da palmeira *Mauritia flexuosa*, um material leve e macio, cortado a faca e pintado em cores fortes. Abaetetuba (PA) é conhecida como a capital desse brinquedo, e ele é reconhecido como patrimônio cultural do Pará ([UFPA, Revista Margens](https://www.periodicos.ufpa.br/index.php/revistamargens/article/download/20523/13412), [Redalyc](https://www.redalyc.org/pdf/715/71523347002.pdf), [O Liberal](https://www.oliberal.com/estudio/brinquedos-de-miriti-maos-que-esculpem-a-alegria-1.1177460)) **[fonte]**. Uma artesã descreve tinta acrílica de tecido e cola branca diluída para dar textura (pele de cobra) **[fonte, relato]**. A data exata do reconhecimento varia entre as fontes **[não verificado]**.

Não achei nenhum jogo com essa estética (busca em português e inglês, 27/11/2026) **[fonte: ausência na busca, não prova]**.

O que a linguagem pede, e por que combina com modelagem por código:

| Traço físico do miriti | Regra de geração por script |
|---|---|
| Material macio cortado a faca | Toda forma é **facetada**: 6 a 12 cortes planos visíveis por peça, com semente fixa. Proibido esfera UV e cápsula lisa |
| Peças separadas, coladas ou presas com palito | Personagem em **peças rígidas, um osso por peça**, com junta à mostra. É o que fez a prova de estilo não parecer slop: dispensa skinning bonito (`extra-prova-de-estilo-boneco-cordel.md`, seção 3.1) **[pesquisa]** |
| Superfície porosa e fosca | Rugosidade 1,0, **especular zero**, poro de miolo em uma escala só (Voronoi fino), visível apenas de perto. Nunca brilho plástico, o risco que derrubou "brinquedo de plástico" para o último lugar no ranking (`direcao-de-arte.md`, seção 6.2) **[pesquisa]** |
| Pintura chapada à mão | **No máximo 3 tintas por peça** e padrões pintados (bolinhas, listras, escamas, folhas) gerados por numpy com tremor de pincel. A tinta **falha nas arestas dos cortes** por curvatura, deixando ver o creme do miriti. A imperfeição tem causa física |
| Água de verdade não existe no brinquedo | A água do jogo é **faixa pintada**: bandas chapadas de 3 tons e marolas recortadas como peças, que sobem e descem em degrau |

**Onde o miriti não entra:** nenhum santo, berlinda, procissão, imagem do Círio ou elemento religioso. Nenhuma peça é cópia de um brinquedo existente. Os personagens são originais.

### Paleta e valores

- **Paleta mestra de 24 cores em OKLab**, num único `paleta.py` lido por Blender, numpy e shaders. A prova de estilo usou 51 hexadecimais e reprovou nessa regra (`extra-prova-de-estilo-boneco-cordel.md`, seção 4) **[pesquisa]**.
- **Cenário:** miriti cru (creme-acinzentado) com tinta **desbotada pela água**: saturação de no máximo 30%. Hierarquia de tinta em 3 planos (fundo claro, meio médio, chão em tom de terra molhada), que foi a melhor variante medida (`extra-prova-de-estilo-boneco-cordel.md`, seção 4.1) **[pesquisa]**.
- **Personagens:** tinta nova e saturada (55 a 80%), com a massa escura no pé.
- **Inimigos Inchados:** tinta **descascada** e cores apagadas, valor de 30 a 50%, com um único ponto de cor forte (o olho). A leitura de herói contra inimigo vem do material: tinta nova contra tinta estufada.
- **Cores de jogador:** vermelho-urucum, azul-anil, verde-folha, roxo-açaí, separadas em cerca de 90° de matiz e repetidas no marcador do chão, no retrato e nos números.
- **Perigo:** **faixa listrada preta e amarela**, como pintura de aviso de cais. É um padrão, não só uma cor, então resiste ao daltonismo. Nenhum objeto do jogador usa listra preta e amarela.
- **VFX do jogador:** magenta e ciano, que não se confundem com o amarelo do perigo nem com os heróis em deuteranopia, o problema medido na prova de estilo (`extra-prova-de-estilo-boneco-cordel.md`, seção 7, recomendação 4) **[pesquisa]**.

### Regras anti-slop específicas deste conceito

1. **Um gerador de forma para tudo:** heróis, inimigos, armas, cenário e ícones saem do mesmo módulo de facetas e do mesmo shader-base.
2. **Toda arma é girada 360° na folha de revisão** antes de entrar, porque é o objeto mais visto do jogo.
3. **Rostos simples por projeto:** olhos de ponto pintado, boca em traço, 6 expressões por troca de textura em degrau. Piaba usa máscara e Remanso usa sombra do chapéu: a expressão vem do corpo.
4. **Cabeça por perfil**, nunca cilindro empilhado (o defeito "totem" da prova de estilo). Cada herói tem formato de cabeça próprio.
5. **Mãos em bloco de 3 dedos.** Nenhuma contagem de dedos para errar.
6. **Nenhum texto falso em cena.** Os nomes pintados nos barcos, nos contêineres e nas bancas são palavras reais, em fonte OFL escolhida, desenhada no estilo de **letra pintada de barco**. Se a pesquisa de licenças não achar uma fonte adequada, a letra é desenhada por script e não copiada de pintor nenhum.
7. **Luz-chave única** (sol da tarde, sempre do mesmo lado), sombra de uma só cor (multiplicar por roxo-acinzentado, nunca preto).
8. **Contorno de cerca de 2,5 px** com variação de ±20%, só em heróis, elites, chefes e na arma da mão.
9. **Capturas da loja saem do motor**, com o mesmo gerador. Nada de arte de capa feita em outro processo.
10. **Teste cego de 3 palavras** em 3 capturas: se aparecer "cordel", "xilogravura" ou "Lost Castle" entre as duas primeiras, a direção está perto demais de alguém (`extra-diferenciacao-cordels-and-spells.md`, seção 7.4) **[pesquisa]**.

### Por que não parece arte gerada

- Tudo tem um **processo físico** por trás (corte, pintura, desgaste da água) em vez de um filtro aplicado sobre uma imagem pronta (`direcao-de-arte.md`, seção 5.2, sinal 12) **[pesquisa]**.
- **Restrição radical como estilo:** nenhuma superfície lisa, nenhum brilho, nenhuma água realista. É a mesma lógica de Tunic e Dead Cells (`direcao-de-arte.md`, seção 1, ponto 2) **[pesquisa]**.
- Uma referência popular específica e pouco usada, em vez de "fantasia genérica".
- Animação em poses fortes seguradas, nunca interpolação linear uniforme (seção 8).

### Câmera

- **Combate:** câmera de **camarote** (perspectiva de 30°, inclinação de 38°, 15,5 m), validada na prova de estilo: herói com 116 a 155 px em 720p e inimigos legíveis com 4 jogadores e 20 inimigos (`extra-prova-de-estilo-boneco-cordel.md`, seção 3.3) **[pesquisa]**. Zoom pelo centro do grupo com Phantom Camera no modo grupo.
- **Palco frontal** (7°): Flutuante, abertura e fim de chefe, Despedida de Tralha Grande. A troca de câmera é a linguagem do teatro de brinquedo.
- **Online:** cada aparelho segue o próprio herói, então as arenas podem passar do tamanho da tela.

---

## 8. Animação pelos 12 princípios

### Taxa de poses

- **Render, física, câmera, VFX e interface a 60 fps.** Só a pose do personagem anda em degrau (`animacao-principios.md`, seção 7.2) **[pesquisa]**.
- **Heróis:** golpes em 2s (pose a cada 2 quadros de jogo, 30 poses/s), locomoção e idle em 3s e 4s (20 e 15 poses/s), **contato em 1s** com smear.
- **Inimigos Inchados:** em 4s e 5s (15 e 12 poses/s), mais "brinquedo duro". A antecipação deles tem moving hold com tremor de 1 a 2°.
- **Chefe:** em 3s, com a antecipação em 5s para pesar.
- O primeiro quadro depois do comando aparece **na hora**: o relógio da pose reinicia no comando (`animacao-principios.md`, seção 7.2, regra 2) **[pesquisa]**.

### Exemplos concretos, princípio por princípio

| Princípio | Heróis | Inimigos | Chefe |
|---|---|---|---|
| **1. Achatar e esticar** | Piaba estica a 1,4 no mergulho e achata a 0,7 na queda (volume constante, laterais a 1/√s). Na madeira não: o squash fica em saia, lenço e balde | Bucho incha de 1,0 a 1,3 antes do bote e desincha como bexiga ao morrer | O pescoço da garça se enrola (comprime em 0,75) antes da varrida |
| **2. Antecipação** | Curta: 3 a 5 quadros no leve. Tiá Marola é exceção: 8 quadros no pesado, porque o peso dela se lê na espera | 24 a 48 quadros, com faixa no chão e som no fim da espera | Bicada-Anzol com 54 quadros: cabeça recua, treme e o alvo trava nos últimos 18 |
| **3. Encenação** | Golpe de recepção ganha 4 quadros de zoom leve (3%) no recebedor, para que todos vejam quem pegou | O Capataz vira o escudo para a câmera antes do golpe de porta | Abertura e fim na câmera de palco, com tudo parado e só a garça em movimento |
| **4. Direto e pose a pose** | Pose a pose em todos os golpes (chaves em CONSTANT) | Pose a pose | Pose a pose no corpo. **Direto** só nas placas de tinta que soltam na morte (simulação gravada no Blender) |
| **5. Continuidade e sobreposição** | A arma passa do alvo 15 a 30°. As pontas do lenço da Marola e o chapéu do Remanso chegam 3 a 6 quadros depois do corpo (mola) | Pezinhos do Bucho continuam pedalando 8 quadros depois do pouso | O guindaste balança depois da cabeça; correntes em mola |
| **6. Aceleração e desaceleração** | Recuperação com slow out para a guarda; a esquiva sai rápida e freia | A Lata-Velha acelera no rolo (ease in) e freia batendo na parede (sem ease: para seco) | O pescoço desce lento e sobe rápido |
| **7. Arcos** | O remo descreve arco largo e plano; o malho, arco vertical alto. A arma arremessada segue parábola visível | Os caroços do Caroceiro saem em leque com arco baixo | A cabeça da garça percorre um arco largo na varrida, marcado no chão |
| **8. Ação secundária** | Mestra Breu: balde pingando em degrau. Piaba: máscara embaça quando ele leva dano | A porta da Gaiola bate sozinha enquanto ela anda | Penas de miriti soltam e caem a cada golpe crítico |
| **9. Tempo** | Leve: 18 a 24 quadros no total; pesado: 40 a 55; hit-stop leve de 3 a 4, pesado de 10 a 14, Despedida de 14 (`animacao-principios.md`, seções 5.1 e 6.4) **[pesquisa]** | Comum: 55 a 80 quadros por ataque, janela de punição de 24 a 40 | Golpe grande de 100 a 170 quadros; janela de 70 depois da bicada |
| **10. Exagero** | Na pose de contato, o braço estica 15% além do comprimento real; a Ombrada inclina o corpo 35° | O Bucho estoura achatado no chão como uma panqueca | A garça estica o pescoço o dobro do normal no último ataque da fase 3 |
| **11. Desenho sólido** | Peso desloca de verdade: Mestra Breu sempre inclinada para o lado da luva; Marola com base larga e centro baixo. Toda peça facetada tem volume, sem planos finos | A Lata-Velha amassa em placas, sem deformar como borracha | Proporções de brinquedo grande: pernas finas e corpo pesado, sempre com o centro sobre o pé de apoio |
| **12. Apelo** | Silhuetas que se reconhecem em miniatura 320 × 180 (trapézio, linha, bola, assimetria) | Inimigos engraçados e não nojentos: olho único brilhante, pezinhos | A garça é bonita, não monstruosa: quando perde, volta a ser garça e vai embora |

### O que é Blender e o que é Godot

| Blender (offline, `bpy` 5.3 sem tela) | Godot 4.7.2 (tempo real) |
|---|---|
| Modelagem facetada, pintura por numpy, casca de contorno dentro do GLB | Shader toon próprio em `light()`, contorno, troca de textura do rosto |
| Poses-chave a 60 fps, assadas em chaves CONSTANT, com mapa de holds por trecho (1s, 2s, 3s) | `AnimationTree` com máquina de estados e janelas de cancelamento vindas da trilha |
| **Um conjunto de golpes por família de arma** feito no "rig-mãe" e reaplicado aos 4 heróis pelos mesmos nomes de osso, com deslocamentos por herói | Arma presa ao osso da mão em tempo real (troca, arremesso, pegada), sem clipe por arma |
| Malhas de smear (casca de arco) com visibilidade de 1 quadro | Smear por shader de vértice no corpo, testado no Compatibility (`animacao-principios.md`, seção 8.3) **[pesquisa]** |
| Curvas de deslocamento de golpe exportadas como dado (root motion) para o anfitrião | Locomoção por código; golpe com root motion; hit-stop **local** em atacante e alvo |
| Simulação de queda das placas de tinta do chefe (gravada) | `SpringBoneSimulator3D` em lenço, chapéu, redes e correntes; `LookAtModifier3D` na cabeça mirando o alvo |
| — | Squash procedural da recepção e do pouso por escala de osso; IK de dois ossos (`TwoBoneIK3D`, 4.6 em diante) para as mãos na Tralha Grande |

**Configuração obrigatória** (`extra-pilha-unica-godot-4-7.md`, seção 3.6) **[pesquisa]**: Blender a 60 fps; exportação glTF com amostragem forçada; Godot com `animation/fps = 60` e **otimizador de animação desligado**; sem compressão em clipe em degrau. Sem isso, a pose de 1 quadro de contato some.

**Lista de clipes:** 8 famílias × 7 clipes (3 leves, pesado, arremesso, recepção, Despedida) = **56 clipes de arma**, mais cerca de 14 de locomoção, reação e Boia por herói, mais 4 de assinatura por herói. Sem o esqueleto comum seriam 4 × 56.

---

## 9. VFX e game juice

Gramática de todo efeito: antecipação curta, clímax nos primeiros 25% da vida do efeito, dissipação longa e fraca, com orçamento de no máximo 3 efeitos primários na tela (`direcao-de-arte.md`, seção 7.3) **[pesquisa]**. Os efeitos são **objetos de brinquedo**: lascas, tinta, lama pintada, linha de pesca, respingo recortado.

### 9 efeitos-assinatura

1. **Despedida.** No contato, a imagem congela por 14 quadros. A arma treme na horizontal e racha em linhas claras que seguem as facetas. Num quadro de impacto, a tela vira 2 tons. A arma explode em **18 a 30 lascas pintadas** com as cores da própria arma, que quicam duas vezes e ficam 3 s no chão. Som: estalo seco de madeira leve, seguido de um glissando descendente de marimba e do "uuh" curto da plateia de bonecos. Uma lasca brilha e voa para o Mural (o jogador vê o progresso).
2. **Pegada no ar.** A arma chega girando com rastro de fita na cor de quem lançou. Na pegada, um anel achatado na cor de quem pegou se abre no chão, o boneco faz squash de 0,8 e a arma ganha um brilho de 6 quadros. Som: "tchak" de couro e um acorde curto de metais que sobe meio tom a cada passe seguido na mesma sala (a sala vira música).
3. **Fisgada.** Uma linha de pesca branca risca do gancho ao inimigo (malha de fita, sem partícula de rastro, que não existe no Compatibility). Puxão: o inimigo vira projétil com 3 múltiplos em alfa decrescente. Ao bater nos outros, explode em respingo de lama pintada. Som: zumbido de carretilha e um "plof" grave.
4. **Respingo de Cheia.** Todo golpe pesado no chão molhado levanta uma **coroa de água recortada**: 6 pétalas planas em 3 tons de azul-tinta, que sobem e descem em 3 poses (degrau de 4 quadros). Som: tapa de água com cauda curta.
5. **Golpe da Tralha Grande.** As duas pessoas acertam na janela: câmera lenta de 0,5× por 6 quadros, os dois anéis de jogador se fundem num só, a onda de choque distorce a tela (shader testado no Compatibility, `godot-render-vfx.md`, apêndice A.4) **[pesquisa]** e as tábuas do piso pulam em sequência a partir do ponto de impacto. Som: sino de navio, corrente arrastando e um "tum" sub-grave de 50 Hz.
6. **Desinchar.** O inimigo derrotado esvazia: perde volume em 3 poses, solta um assobio cômico e cai plano no chão como uma folha de miriti pintada, que se desfaz em tampinhas. Som: assobio de bexiga com afinação aleatória (4 a 6 variações).
7. **Pião.** O inimigo amarrado gira com 4 cópias em leque. A linha que o amarra solta um rastro de fita em espiral. Cada vizinho atingido faz "toc" de madeira, subindo a escala.
8. **Boia e corda.** Ao cair, o boneco afunda até o pescoço e a boia "infla" em 2 poses. Quando o aliado arremessa a corda, a corda desenha uma parábola e o anel do ponto ideal pisca no ritmo da música. Ao reviver, o boneco salta da água com esticamento de 1,3 e chacoalha a água (gotas pintadas). Som: "fuuu" de boia, corda zunindo, "splash" e o herói dizendo o bordão dele.
9. **Atracada do chefe.** A âncora crava no pé da garça, correntes recortadas surgem em volta dela e são cravadas no trapiche uma a uma (4 batidas, no ritmo), e a tela tem um impact frame. Som: 4 marteladas em cascata e um rangido de madeira gigante.

### Legibilidade com 4 jogadores

- **Efeitos de aliados com 40% de opacidade** para quem não os lançou; o seu efeito aparece cheio.
- **Lascas, respingos e tampinhas** não podem ter listra preta e amarela nem ficar mais de 3 s no chão, a menos de 40% de opacidade.
- **Marcas nos inimigos** são ícones pintados sobre a cabeça (anzol, estrelinhas, nó, gota de lama), um formato por marca e em tinta clara com contorno, legíveis a 32 px na miniatura.
- **Jogador encoberto** aparece em silhueta chapada na cor dele (stencil, testado no Compatibility, `godot-render-vfx.md`, seção 0) **[pesquisa]**.
- **Hit-stop local:** só atacante e alvo congelam; os outros três jogadores seguem (`animacao-principios.md`, seção 6.4) **[pesquisa]**. Pausas globais só na morte de chefe.
- Opção de acessibilidade: reduzir tremor de tela, impact frames e piscadas.
- Portões de toda captura: cinza, borrão, miniatura 320 × 180, deuteranopia e protanopia, e estresse com 4 heróis, 12 a 20 inimigos e 6 efeitos (`direcao-de-arte.md`, seção 7.3) **[pesquisa]**.

---

## 10. Som e música

1. **Trilha:** uma **banda de cais** inventada, com metais de fanfarra, marimba e blocos de madeira, tambores de lata e um baixo de tuba, longe de forró, baião e de qualquer gênero que já identifique Cordels & Spells (`extra-diferenciacao-cordels-and-spells.md`, seção 7.1) **[pesquisa]**.
2. **Trilha adaptativa em camadas:** percussão sempre; metais entram com 3 ou mais inimigos; uma frase "de vitória" toca em cima de cada reação; cada passe seguido sobe a afinação da frase.
3. **Impactos em camadas renderizadas offline:** transiente, corpo, textura (madeira leve, lata, corda, água) e cauda, com 4 a 6 variações por evento para evitar efeito metralhadora (`ferramentas-ia.md`, seção 6.4) **[pesquisa]**. Cada família de arma tem uma textura própria de som.
4. **Produção:** MIDI por script e samples CC0 (VSCO-2-CE e VCSL) com mixagem no pedalboard e `BrickwallLimiter(-1)`, cerca de −14 LUFS na Web (`ferramentas-ia.md`, seção 6.3) **[pesquisa]**. Na Web, todo efeito de barramento é assado no arquivo, porque o modo de áudio padrão não tem reverb (`godot-render-vfx.md`, seção 10.1) **[pesquisa]**.
5. **Vozes:** sem diálogo falado; bonecos "falam" com sílabas assobiadas ou de apito curto, com bordões legendados, e cada herói tem um timbre de instrumento (Marola: tuba; Remanso: clarinete grave; Piaba: apito; Breu: trompete com surdina).

---

## 11. Controles

| Ação | Teclado (jogador 1 / jogador 2 no mesmo teclado) | Controle | Toque (celular, paisagem) |
|---|---|---|---|
| Mover | WASD / setas | analógico esquerdo | joystick dinâmico na metade esquerda da tela |
| Golpe leve | J / Num1 | X (ou Quadrado) | **toque** no botão grande de ataque (Ø 104 px) com mira automática |
| Golpe pesado (marca) | segurar J / segurar Num1 | segurar X | **segurar** o botão de ataque; arrastar mira, soltar golpeia |
| Esquiva | K / Num2 | A (ou X do PlayStation) | botão de esquiva ao lado do ataque |
| Arremessar / passar | L (toque e segurar) / Num3 | B (toque e segurar); segurando, o analógico direito escolhe o aliado | botão de arremesso no arco: toque arremessa à frente, **arrastar até o retrato de um aliado** passa a arma para ele |
| Trocar arma | I / Num4 | RB | tocar o ícone da arma das costas |
| Habilidade do herói | U / Num5 | Y | botão no arco |
| Pegar, erguer, reviver | E / Num0 | LB ou contextual em A | botão contextual que aparece só quando há o que fazer, no lugar da habilidade |
| Chamado | Q / Num7 | direcional para cima | toque longo num inimigo |

**Entrada:** G.U.I.D.E com `GUIDEVirtualStick` e `GUIDEVirtualButton` para o toque, um só caminho de entrada para teclado, controle e toque (`extra-pilha-unica-godot-4-7.md`, seção 0) **[pesquisa]**.

**Mira automática no toque:** pontua por ângulo em relação ao movimento, distância e ameaça (quem está telegrafando), com histerese de 30% para não pular de alvo (`coop-rede.md`, seção 5.1) **[pesquisa]**. Na Tralha Grande pelo toque, o golpe sincronizado tem janela de 0,45 s e o parceiro de IA sempre acompanha.

---

## 12. Fatia vertical e marcos

### Fatia vertical: o menor pedaço que prova o jogo

**Pergunta que ela responde:** passar a arma, quebrar a arma e marcar em dupla é divertido o bastante para segurar uma expedição de 15 minutos, sozinho com IA no celular e em 2 a 4 no PC?

**Conteúdo exato:**

| Item | Quantidade | Detalhe |
|---|---|---|
| Bioma | 1 | Trapiche Velho, com 3 telões, 6 marcos, 5 coberturas, 1 perigo (tábua-catapulta) e 2 pendurados |
| Expedição | 1 | 6 salas de combate geradas, 1 banca de achados, 1 oficina, 1 chefe (cerca de 12 min) |
| Heróis | 2 | Tiá Marola e Piaba, cada um com kit completo |
| Famílias de arma | 3 | Remos, Ganchos, Malhos |
| Armas | 6 | Remo de Faia, Remo-Pá Largo, Bicheiro, Arpão de Corda, Malho de Calafate, Mão de Pilão |
| Tralha Grande | 1 | Âncora de Balsa (sala de desafio e chefe) |
| Marcas e reações | 3 e 3 | Enganchado, Tonto, Atolado → Fisgada, Atracado, Estaca |
| Remendos | 3 | Fita, Chumbada, Boia de Isopor |
| Achados | 8 | Rolha da Sorte, Mão Boa, Fita de Arremate, Apito Rachado, Cuia de Lama, Ombro de Estiva, e mais 2 |
| Inimigos | 3 | Bucho, Gaiola, Caroceiro (a Lata-Velha entra se sobrar tempo) |
| Chefe | 1 | Garça-Guindaste, 3 fases completas |
| Co-op | completo | passe, pegada, Boia e reviver, fogo amigo em 3 níveis, saque instanciado, 1 a 4 locais no PC |
| Solo | completo | parceiro de IA em Beehave com as regras da seção 3 |
| Meta | mínimo | Mural de Lascas funcionando (pendurar 1 arma); o Flutuante é uma tela de palco sem cômodos |
| VFX | 6 | Despedida, Pegada, Fisgada, Respingo, Desinchar, Boia |
| Plataformas | 2 | export desktop em Forward+ e Web em Compatibility (artifact e GitHub Pages), toque, teclado e controle |

**Critérios de pronto (medidos):**
- 1 jogador e IA terminam a expedição no celular do usuário a **30 FPS estáveis**;
- 4 jogadores locais no PC passam pelos portões de legibilidade em captura de estresse;
- **telemetria por sessão:** passes por minuto, porcentagem de reações vindas de 2 pessoas, Despedidas por sala, tempo médio na Boia (meta: menos de 8 s) e momentos de riso relatados no teste.

### O que vem depois, em 3 marcos

1. **Marco 1: "Arsenal inteiro".** As 8 famílias com 3 armas cada (24 armas), 4 marcas e 6 reações, 4 Tralhas Grandes, 12 remendos, 20 achados, os 4 heróis, a Lata-Velha e o Capataz. Teste principal: o arsenal muda o jeito de jogar a cada expedição? (medir a variedade de armas usadas por partida).
2. **Marco 2: "O rio todo".** Os 4 biomas com kits, 4 chefes, a Grande Descida, o Flutuante com 5 cômodos e 3 níveis, as 40 armas e 30 achados, trilha completa por bioma, história e falas.
3. **Marco 3: "Online e acabamento".** WebRTC de 2 a 4 com anfitrião no navegador (sinalização própria e TURN), reconexão com IA no lugar de quem caiu, acessibilidade, idiomas, build de PC para Steam com Remote Play Together, e uma rodada de polimento de animação e VFX guiada pela rubrica de `animacao-principios.md`, seção 15.

---

## 13. Viabilidade neste pipeline

### O que a pesquisa já comprova

| Necessidade do conceito | Evidência |
|---|---|
| Boneco de peças rígidas facetadas e pintadas, feito só por `bpy`, que não parece slop | Prova de estilo do mamulengo: mesma lógica de peça rígida, faceta e estampa por numpy (`extra-prova-de-estilo-boneco-cordel.md`, seção 3.1) |
| Mesmo visual na Web e no PC | Diferença média de 1,3 a 1,9 em 255 com estilização no material (mesma fonte, seção 3.2) |
| Câmera camarote com 4 heróis e 20 inimigos legíveis | Mesma fonte, seção 3.3 |
| Poses em degrau, contato de 1 quadro e squash por escala de osso chegando intactos ao Godot | 60 fps nos dois lados e otimizador desligado, erro 0,00000 (`extra-pilha-unica-godot-4-7.md`, seção 3) |
| Smear por shader e hit-stop local | Smear testado no Compatibility; receita de hit-stop por entidade (`animacao-principios.md`, seções 6.4 e 8.3) |
| Onda de choque, contorno, stencil para silhueta encoberta | Testados em WebGL2 real (`godot-render-vfx.md`, seção 0 e apêndice A) |
| Salas geradas com variedade sem repetição | Gerador em 3 camadas, 9,9 salas por expedição, 6 a 8% de repetição com escolha conjunta (`extra-geracao-de-fases-por-codigo.md`, seção 1) |
| Anfitrião no navegador com 4 jogadores | WebRTC 1 + 3 testado (`extra-contexto-real-celular-coop.md`, ponto 6) |
| Ícones de arma do mesmo modelo | Cycles toon por emissão a 0,2 a 0,3 s por quadro (`pipeline-blender.md`, seção 7.1) |
| Áudio de impacto em camadas e trilha com samples livres | `ferramentas-ia.md`, seção 6 |

### O que ainda é risco técnico

- **Desempenho no celular real:** nenhum número de aparelho ainda. O teste de desempenho está publicado e espera o usuário (`extra-contexto-real-celular-coop.md`, seção 2) **[pesquisa]**.
- **Esqueleto comum para 4 silhuetas muito diferentes** (Marola larga, Remanso de 3 cabeças de altura a mais): reaproveitar o golpe da família sem a arma atravessar o corpo exige deslocamentos por herói. Não testado.
- **Arma arremessada e pegada no ar** em rede com 150 ms: a regra existe, mas não foi testada.
- **Tralha Grande carregada por dois** (física de objeto com duas pegas): não testada.
- **Pintura que falha nas arestas por curvatura** e poro de miriti sem parecer ruído uniforme: não testado.
- **Cor de vértice escurecida no Compatibility 4.7.2:** já tem correção, mas precisa ficar em todo shader (`extra-prova-de-estilo-boneco-cordel.md`, seção 5) **[pesquisa]**.

### Custo de render na Web (Compatibility, celular)

Base medida: na prova de estilo, 24 bonecos e 3 explosões deram **153 a 155 draw calls** (72 dos bonecos, 24 das sombras e cerca de 54 dos retalhos de efeito). Com sombras e retalhos em `MultiMesh`, a estimativa cai para cerca de 80 (`extra-prova-de-estilo-boneco-cordel.md`, seção 3.2) **[pesquisa]**.

Estimativa para este conceito no pico [proposta]:

| Parte | Draw calls |
|---|---|
| 4 heróis (corpo, contorno e arma da mão com contorno) | cerca de 20 |
| Armas nas costas (sem contorno) | 4 |
| 12 inimigos (sem contorno, contorno só na elite) | cerca de 26 |
| Sombras em bolha (1 MultiMesh) | 1 |
| Cenário da sala (kit de cerca de 35 nós, com instâncias repetidas em MultiMesh) | 20 a 30 |
| Lascas, tampinhas e respingos (CPUParticles e MultiMesh) | 6 a 10 |
| Pós-processo (vinheta e impact frame) | 2 |
| **Total** | **cerca de 80 a 95** |

Isso fica abaixo do teto de 100 a 150 draw calls proposto para a Web (`godot-render-vfx.md`, seção 10.2) **[pesquisa]**. Regras fixas: sem sombra dinâmica (custava +64% de tempo de quadro), resolução 3D entre 0,6 e 0,75, DPR efetivo de no máximo 1,5, contorno orçado por personagem, alvo de **30 FPS travados** em aparelho de entrada (`extra-contexto-real-celular-coop.md`, seção 4) **[pesquisa]**. Download: cerca de 10 MB de motor comprimido e um `.pck` pequeno, porque tudo é procedural.

---

## 14. Riscos e como mitigar

| # | Risco | Mitigação |
|---|---|---|
| 1 | **Parecer clone de Lost Castle** | Nome, mundo, armas, inimigos e heróis originais; os três diferenciais (passe, Despedida, Tralha Grande) aparecem no primeiro minuto do trailer; nenhuma arma ou nome do jogo de referência |
| 2 | **Uso indevido de uma tradição artesanal real** (miriti de Abaetetuba, letra pintada de barco) | Usar só a linguagem do material, nunca copiar peças; crédito explícito no jogo e na loja; nenhum elemento religioso do Círio; antes de divulgar, procurar diálogo com artesãos e associações de Abaetetuba e considerar parceria ou licença de padrões desenhados por eles |
| 3 | **"Brinquedo" lido como jogo casual de celular** (a direção que ficou em último no ranking) | Superfície fosca, facetas de faca, tinta gasta e contorno; nada de plástico. Teste cego de 3 palavras e teste da miniatura antes de fixar |
| 4 | **Arma que quebra frustra** | Fôlego generoso (16 a 40 golpes), Despedida como melhor golpe, conserto na oficina e pela Mestra Breu, Mural que transforma quebra em progresso. Medir no teste quantas vezes a pessoa fica sem arma (meta: nunca mais de 3 s) |
| 5 | **Explosão de animação** (8 famílias × 4 heróis) | Esqueleto comum, um conjunto de golpes por família, deslocamentos por herói; 56 clipes de arma em vez de 224 |
| 6 | **Caos ilegível com 4 jogadores, lascas e respingos** | Orçamento de 3 efeitos primários, efeitos de aliados a 40%, lascas com vida de 3 s, listra de perigo exclusiva, portões automáticos de captura |
| 7 | **Desempenho no celular de entrada** | Testar no aparelho do usuário antes de fixar a arte; 10 a 12 inimigos visíveis; sem sombra real; MultiMesh; se o aparelho ficar abaixo de 20 FPS, o celular vira controle (modelo de tela grande) |
| 8 | **Passe e Tralha Grande em rede** | Janelas generosas no online (300 ms e 0,45 s), decisão no anfitrião, efeito cosmético imediato no cliente; teste headless com 150 ms e 2% de perda antes de abrir para amigos |
| 9 | **Solo sem graça** | Parceiro de IA na fatia vertical desde o primeiro dia, que prepara, pega passes e segura a âncora; modo troca de herói como alternativa |
| 10 | **Sobreposição com o conceito de mamulengo** (ambos são bonecos de madeira pintada) | Se os dois chegarem à final, escolher um. Este se separa pelo material (miriti fosco e cortado a faca, não madeira de luva com chita), pelo lugar (rio de palafitas, não palco de feira) e pelo núcleo (arsenal, não reações de matéria) |
| 11 | **Pouca variedade percebida, a crítica que Cordels & Spells e Magicka 2 receberam** | 40 armas, remendos visíveis, verbo novo por bioma, escolha conjunta anti-repetição também para ondas e músicas |
| 12 | **Nome colidir com algo não indexado** | Conferir no INPI e na Steam de outra rede antes de anunciar; manter "Floodhaul" como alternativa internacional |

---

## Fontes externas desta etapa

- Nome: [busca "tralha"](https://m.magazineluiza.com.br/busca/tralha/), [restaurante Tralha](https://booked.ai/restaurants/tralha-restaurant), [Flood (Steam)](https://store.steampowered.com/app/2986340), [Flood 2024 (RAWG)](https://rawg.io/games/flood-2024).
- Miriti: [Revista Margens, UFPA](https://www.periodicos.ufpa.br/index.php/revistamargens/article/download/20523/13412), [Redalyc](https://www.redalyc.org/pdf/715/71523347002.pdf), [O Liberal](https://www.oliberal.com/estudio/brinquedos-de-miriti-maos-que-esculpem-a-alegria-1.1177460), [Artesol](https://artesol.org.br/wp-content/uploads/tainacan-items/6414/7250/trab_20160912141833000000762-1.pdf), [dissertação UFPA, entalhadores](https://repositorio.ufpa.br/bitstream/2011/10909/1/Dissertacao_EntalhadoresEfemeroVida.pdf).
- Todo o resto vem de `docs/pesquisa/`, citado arquivo por arquivo no texto.

# Wickwain: a caravana do pavio longo

Conceito de jogo, 27/11/2026. Um dos três conceitos de fantasia escritos em paralelo: este é a **caravana mágica**. Os outros dois são uma guerra para retomar um reino amaldiçoado e uma descida a um mundo subterrâneo aberto. Nada aqui está decidido.

**Como ler.** As seções seguem a ordem pedida. Números marcados **[pesquisa]** vêm de `docs/pesquisa/`. Os demais são proposta minha e servem de ponto de partida para teste. **[PC]** marca o que só existe no Forward+; **[iPhone]** marca a versão leve da prévia no Safari.

### Glossário curto

| Termo | O que quer dizer aqui |
|---|---|
| Wain | Palavra antiga do inglês para carroção. A caravana inteira se chama "a Wain" |
| Treva | A escuridão viva que cobre o mundo desde que o sol foi abafado. Ela come o que não está aceso |
| Halo | O círculo de luz das lanternas da caravana. Dentro dele o mundo é pintado e seguro |
| Fuligem | Medidor que enche no herói quando ele fica fora de qualquer luz |
| Gravado | Inimigo (ou objeto) que está na Treva. Aparece como gravura em linhas e recebe menos dano |
| Mancha | Uma matéria aplicada num alvo ou no chão. Duas matérias diferentes no mesmo lugar dão uma reação |
| Braseiro | Farolete de pedra abandonado na paisagem. Reacendido, vira luz permanente e ponto de rota |
| Mariposa | O estado do herói caído: uma mariposa pequena que continua jogando e volta à vida entrando numa luz |
| Graxo | A fera de sebo que puxa a caravana. O sebo das costas dela alimenta as lanternas |

---

## 1. Nome e frase

**Wickwain** (pronúncia "uík-uêin"; *wick* é pavio, *wain* é carroção). Subtítulo em português: **a caravana do pavio longo**.

Busca feita em 27/11/2026 por "Wickwain" em buscador geral, Steam e itch.io: nenhum jogo, jogo de tabuleiro ou marca com esse nome. Os nomes mais próximos são *Wickwise* (jogo de cartas de navegador sobre velas, no ModDB) e *Wickland* (videogame listado no VideoGameGeek); os dois têm grafia e gênero diferentes. Também conferi "Emberwain" e "Pavio Longo": nenhum resultado, mas "Ember..." está saturado (Emberwake, Emberward, Emberwind) e por isso foi descartado. A checagem de marca registrada formal (INPI, USPTO, EUIPO) fica para antes de qualquer anúncio.

> **"Enquanto o pavio queimar, a estrada é de vocês."**

Versão longa do pitch: *"Quatro aventureiros pequenos, uma caravana de três vagões puxada por uma fera de sebo e um mundo inteiro afogado na Treva. A luz das lanternas pinta o mundo e mantém a escuridão longe. Saia do halo para saquear ruínas e masmorras, unte o amigo, acenda o chão, jogue a lanterna para quem está no escuro, e volte antes que o pavio acabe."*

Versão curta, para a capa: *"Eu unto, você acende, e a Treva aprende a ter medo."*

---

## 2. Premissa e tom

### O mundo

Há quarenta anos, alguma coisa abafou o sol, como quem apaga uma vela com os dedos. O sol não morreu: ele ainda nasce por algumas horas, pardo e fraco, atrás de um céu de cinza. É o **Sol Velho**. No resto do tempo, a **Treva** sobe dos vales como maré e come tudo o que não estiver aceso: plantações, cidades, estradas e gente. O que a Treva come não some; vira **gravura**, um desenho de linhas frias que ainda se mexe e ainda tem fome.

As cidades que sobraram vivem atrás de muralhas de fogueiras e não saem de casa. O único jeito de atravessar o mundo é a **Wain**, uma caravana de três vagões puxada por **Graxo**, uma fera de seis patas, cega e enorme, cujas costas soltam sebo sem parar. O sebo de Graxo vira as velas e o óleo das lanternas. Graxo não parece se importar. Muito.

O grupo de jogadores é a companhia contratada para levar a caravana até o **Poente**, o lugar no fim do mundo onde o sol foi abafado, e descobrir o que fez isso. No caminho, eles fazem o que aventureiros sempre fazem: aceitam contratos duvidosos, saqueiam ruínas, abrem masmorras e brigam pelo baú.

### O tom

- **Dark fantasy com humor ácido, nunca infantil.** O mundo é cruel e triste: aldeias gravadas, gente presa em linhas, canções de quem desistiu. O humor vem do grupo e da situação, não de piadas de cenário. Exemplo: o mago é queimado vivo pelo amigo de propósito para virar uma tocha viva, e isso salva a expedição.
- **Mesa de RPG.** A taverna da caravana tem uma mesa com o mapa do mundo feito em miniatura, onde o grupo escolhe a rota movendo bonecos de chumbo pintados. Os contratos são lidos em voz alta pela taverneira, como um mestre de jogo lendo o gancho da aventura.
- **Violência cômica de corpo pequeno.** Heróis de cabeça grande voam longe com o estouro, quicam, perdem o chapéu e saem correndo atrás dele. Ninguém sangra; inimigos se desfazem em linhas, fuligem e cera derretida.
- **A luz é carinho.** O calor das lanternas é a única coisa bonita do mundo. Toda a direção de arte serve a esta ideia: luz quente é casa, escuro frio é fome.

### O que torna este conceito diferente dos outros dois

| Eixo | Wickwain (caravana) | Reino amaldiçoado (guerra) | Mundo subterrâneo (descida) |
|---|---|---|---|
| Movimento do mundo | Horizontal, estrada longa, viagem | Território a reconquistar, frentes de batalha | Vertical, camadas para baixo |
| O recurso que manda | **Luz que se move** (halo da caravana, óleo da lanterna) | Território e tropas | Profundidade, ar e retorno |
| A base | Uma base **móvel** que os jogadores dirigem | Fortaleza fixa que cresce | Acampamento que desce |
| Linguagem visual | **Guache à luz da lanterna sobre gravura de Treva**: o mundo muda de técnica de pintura conforme a luz | Escolha deles | Escolha deles |

---

## 3. Estrutura de mundo aberto

### Como se viaja

O mundo é contínuo, sem telas de carregamento entre regiões, montado em blocos de 64 × 64 m que entram e saem conforme a câmera. Cada região tem cerca de 700 × 700 m jogáveis e mais um anel de cenário de fundo de até 3 km para o horizonte.

- **A caravana anda pelas estradas.** As estradas são trilhos invisíveis com bifurcações. A Wain anda a até 4 m/s, sobe ladeira a 2 m/s e só sai da estrada em "trilhas de terra" marcadas, a 1,5 m/s. Os heróis andam a 5,5 m/s e correm a 7,5 m/s fora de combate. Isso quer dizer que dá para se afastar da caravana, explorar e voltar a tempo, mas não por muito tempo.
- **A caravana precisa de dois condutores.** Um jogador assume as **rédeas** (direção nas bifurcações e velocidade) e outro o **freio e o guincho** (descidas, pontes, atoleiros). Sem freio, a Wain desembesta na descida e Graxo tropeça. Ninguém é obrigado a ficar: a caravana também anda sozinha, devagar (2 m/s), seguindo a rota marcada na mesa.
- **O halo anda junto.** O círculo de luz da caravana tem 18 m de raio no começo e chega a 26 m com melhorias. Ele se move com a Wain. Quem fica para trás sai do halo.
- **Braseiros e rotas de lume.** Cada região tem de 8 a 12 **braseiros** apagados na paisagem. Reacender um braseiro cria uma luz permanente de 12 m de raio e um ponto de rota. Dois braseiros acesos ligados por estrada formam uma **rota de lume**: durante o dia, a caravana viaja por ela sem precisar escoltar, e os heróis podem se teletransportar entre braseiros pelo fogo. É a viagem rápida, e ela é conquistada.

### Marcos no horizonte

Cada região tem dois ou três marcos visíveis de quase qualquer ponto. A câmera de exploração é inclinada para deixar o céu e esses marcos sempre na faixa de cima da tela.

- **O Farol Cego** (Brejo): um farol rachado num rochedo sobre o mar. A lente ainda pisca uma vez a cada 40 s, com um feixe pálido que varre a névoa. É a toca do chefe.
- **A Torre Torta** (Brejo): o campanário de uma capela afundada, inclinado 20 graus, com um sino que toca sozinho quando venta.
- **A Ponte dos Mil Sinos** (Mata Vergada): uma ponte de madeira de 300 m entre duas copas, toda pendurada de sinos de defunto.
- **O Gigante Ajoelhado** (Planalto das Cinzas): uma estátua de 120 m, de joelhos, segurando nas mãos um disco solar apagado e rachado. Ela é vista desde o Brejo como uma silhueta na névoa.
- **A Muralha de Treva**: no horizonte, a borda da Treva aparece como uma parede de hachuras que sobe e desce com o ciclo do dia.

### Caminhos opcionais e segredos

- **Lanternas afogadas.** No Brejo há lanternas antigas sob a água rasa. Acendê-las debaixo d'água (com óleo e chama, ver as reações) revela trilhas submersas e baús.
- **Estalagens gravadas.** Casas tomadas pela Treva aparecem em linhas. Quando a luz as toca, elas voltam a ser pintadas por alguns segundos e mostram o que havia dentro: um mapa, um morador preso, um baú. Quem leva luz suficiente (dois heróis com a lanterna erguida, ou uma Labareda) devolve a casa de vez.
- **Esconderijos dos Mudos.** Os bandoleiros guardam saque em ocos de árvore marcados com um laço de pano. O ladino enxerga esses laços de longe.
- **Sinos soltos.** Na Mata, sinos caídos podem ser levados de volta à Ponte. Cada sino pendurado abre um atalho e deixa uma recompensa.
- **Contratos secretos.** Alguns contratos só aparecem na mesa da taverna se o grupo trouxer um objeto achado no campo (um dente de Graxo antigo, uma carta lacrada, um chapéu de classe rara).

### Masmorras que se abrem na paisagem

As masmorras não ficam atrás de portas num menu: elas se abrem no terreno, à vista. Cada região tem de 4 a 6, de 6 a 14 minutos cada.

- **Bocas.** Reacender um braseiro perto de uma depressão faz o chão ceder e abrir uma boca de pedra com escada: é a cripta que a Treva escondia.
- **Ocos de raiz.** Na Mata, troncos vergados formam túneis que descem.
- **Capelas afundadas.** No Brejo, a maré baixa da noite descobre portas no lodo. De dia, a entrada está debaixo d'água.
- **Fendas do Gigante.** No Planalto, rachaduras no corpo da estátua levam para dentro dela.

**Regra de luz das masmorras.** Dentro delas não há halo de caravana. Só existe a luz que o grupo carrega (lanternas de mão, tochas vivas, reações de fogo) e os braseiros internos, que podem ser acesos. O interior é feito à mão, com salas de 15 a 30 m e trechos montados por regra entre salas fixas.

### Ciclo de luz e clima

Um ciclo completo dura **24 minutos reais**.

| Fase | Duração | O que acontece |
|---|---|---|
| **Lusco** (amanhecer) | 3 min | A Treva recua dos morros para os vales. Neblina baixa, luz rosada e fria, pássaros. Bom momento para sair do halo |
| **Dia Pardo** | 8 min | O Sol Velho dá uma luz fraca de cinza dourada. A Fuligem enche três vezes mais devagar. É a hora de explorar longe e de viajar por rotas de lume |
| **Crepúsculo** | 3 min | A Treva começa a subir. O céu fica laranja contra violeta. Os inimigos gravados acordam |
| **Noite Longa** | 10 min | Fora das luzes, só Treva. A caravana para e monta **acampamento**: os vagões se fecham em círculo e o grupo defende Graxo e as lanternas contra ondas. Também é a hora das masmorras, que não dependem de luz de fora |

**Clima** (sorteado por região, com tendência fixa):

- **Chuva** deixa tudo molhado (o chão e os heróis), apaga chama comum em 6 s e conduz faísca.
- **Vento** inclina as chamas, carrega fumaça e vapor na direção dele e faz a Labareda se espalhar 50% mais rápido a favor do vento.
- **Neve de cinza** (Planalto) reduz a visão em 20% e cobre o chão de pó que mostra pegadas, inclusive as de inimigos gravados.
- **Névoa de maré** (Brejo) sobe no Crepúsculo e esconde o chão até a canela.

---

## 4. Estrutura de RPG

### Missões

- **Fio principal: a rota até o Poente.** Cada região termina num marco que precisa ser vencido para a estrada seguir (no Brejo, o Farol Cego).
- **Contratos da taverna.** A taverneira lê na mesa de 3 a 5 contratos por parada. Tipos: **escolta** (levar um passageiro até um braseiro), **resgate** (outra caravana atolada na Treva), **acendimento** (reacender uma sequência de braseiros antes da Noite Longa), **caçada** (um inimigo nomeado), **recuperação** (trazer uma relíquia pesada de uma masmorra, carregada em dupla), **entrega maldita** (levar um objeto que atrai a Treva).
- **Passageiros.** A caravana leva passageiros que pagam. Alguns têm histórias que viram missões: o cartógrafo cego, a viúva que quer achar a casa gravada do marido, o anão de cera que derrete se ficar perto demais das lanternas.

### Saque e equipamento visível no herói pequeno

O herói tem só **quatro peças de equipamento visível**, todas grandes o bastante para ler a 64 px de altura de tela [pesquisa: `direcao-de-arte.md`, regra 14]:

| Encaixe | O que muda no corpo | Exemplo |
|---|---|---|
| **Chapéu de ofício** | Define a classe e o rosto da silhueta | O chapéu-vela do mago, o elmo-panela da guerreira |
| **Ferramenta** | A arma principal, sempre maior que o braço | A roda de carroça, o sino no cabo |
| **Manto** | A capa e a cor de jogador. Balança com o vento | Manto de lona remendada, capa de pele de lobo-gravado |
| **Cinto** | A lanterna de mão e uma bugiganga pendurada | Lanterna de latão, cantil de óleo, chocalho de ossos |

Raridades: **Comum, Remendado, Bom, de Mestre, Lendário**. Cada raridade acima de Comum muda a forma da peça, não só o brilho: a roda Boa tem raios de ferro, a de Mestre tem pregos, a Lendária é uma roda de moinho dentada. Não existe brilho mágico genérico em item.

Atributos ficam poucos e legíveis: **Força** (dano da ferramenta), **Pavio** (capacidade da matéria), **Couro** (vida e resistência à Fuligem) e **Lume** (raio da lanterna de mão e duração das reações de luz).

### Progressão por classe e troca de classe por equipamento

- **A classe está no chapéu.** Como em Fat Princess, quem pega um chapéu de ofício vira aquela classe na hora: muda a matéria, a ferramenta padrão e as habilidades. A diferença é que aqui o chapéu é um item de equipamento de verdade, com nível e raridade.
- **Onde se troca.** No vagão-oficina há o **cabideiro**, com todos os chapéus que o grupo já achou. No campo, chapéus aparecem em baús, caem de inimigos nomeados e caem do herói que vira mariposa (o amigo pode vestir o chapéu do caído por um tempo).
- **Nível por classe.** Cada chapéu tem nível de 1 a 10, ganho usando aquela classe. Os níveis 3, 6 e 9 liberam uma **Medalha de Ofício**: uma variação do kit (por exemplo, a roda da guerreira passa a quicar duas vezes). O jogador escolhe uma medalha em cada nível.
- **Nível de herói.** Um nível geral de 1 a 30 sobe com tudo e só aumenta Couro e espaço de cinto. Assim, trocar de classe não zera o progresso.

### A base: a Wain

A caravana é base, taverna e progressão ao mesmo tempo. Começa com três vagões e chega a cinco.

| Vagão | Função | Melhorias |
|---|---|---|
| **O Tonel** (taverna) | Mesa do mapa, contratos, passageiros, mercenários para jogar solo, bebidas que dão um efeito por expedição | Mais contratos, mercenários melhores, uma lareira que cura no acampamento |
| **A Oficina** | Cabideiro (troca de classe), forja, alfaiate, refino de sebo em óleo | Medalhas extras, conserto de peças, novas formas de equipamento |
| **A Torre-Lanterna** | A Grande Lanterna da caravana e o **Feixe** operado em dupla (ver os efeitos-assinatura) | Raio do halo (18 → 26 m), duração do Feixe, menor consumo |
| **A Capela** (achado no Brejo) | Sal consagrado, ressurreição de passageiros gravados | Água benta que limpa Fuligem |
| **O Estábulo do Graxo** (achado na Mata) | Melhora Graxo: mais sebo, mais velocidade, uma investida que esmaga o que estiver na estrada | Selas para os heróis subirem nas costas dele |

O sebo é a moeda de base. Graxo produz 1 unidade por minuto de viagem; o grupo gasta sebo em óleo de lanterna, em melhorias e em velas para os braseiros.

---

## 5. Ciclo de jogo e duração de sessão

**O ciclo curto (2 a 5 min):** a caravana avança; um ou dois heróis se afastam para uma ruína ou um braseiro; brigam, saqueiam e voltam correndo antes que a Fuligem encha.

**O ciclo médio, uma jornada (24 min, um ciclo de luz):**

1. **Lusco.** Planejar na mesa: escolher a rota e dois contratos.
2. **Dia Pardo.** Viajar, explorar longe, acender braseiros, cumprir um contrato de campo.
3. **Crepúsculo.** Voltar para a caravana. Escolher entre montar acampamento ou entrar numa masmorra próxima.
4. **Noite Longa.** Defender o acampamento contra 3 ondas (cerca de 8 min) **ou** fazer uma masmorra (6 a 14 min) enquanto a caravana se defende sozinha com mais risco (Graxo perde sebo se for atacado).
5. **Fim da jornada.** Repartir saque na taverna, trocar chapéus, gastar sebo.

**O ciclo longo:** uma região leva de 4 a 6 jornadas (cerca de 2 horas) e termina no chefe dela. A campanha principal tem 3 regiões na versão 1.0 (cerca de 7 horas), com o Poente como expansão.

**Duração de sessão.** Uma sessão típica tem uma ou duas jornadas: **25 a 50 minutos**. O jogo salva no fim de cada fase do ciclo, então dá para parar no meio de uma jornada sem perder mais que 10 minutos. Uma jornada também cabe numa partida de teste no celular.

**O que se perde ao morrer.** O mundo é persistente e não reinicia. Se o grupo inteiro vira mariposa ao mesmo tempo, a expedição volta para a caravana (ou para o último braseiro dentro da masmorra) e deixa para trás **o saco de saque** de cada um: ele fica no lugar, marcado por uma chama verde-pálida no mapa, até a próxima Noite Longa, quando a Treva o come.

---

## 6. Co-op

### As quatro interações que o usuário gostou, adaptadas a este mundo

**(1) Chão que guarda estados e reações montadas por duas pessoas.** O chão guarda até duas manchas por célula de 1 m. Os estados do chão são **molhado** (chuva, poças, barris), **untado** (óleo), **em chamas** (chama), **eletrificado** (faísca), **consagrado** (sal) e **enegrecido** (Treva, o estado amaldiçoado dos inimigos). Reação feita por duas pessoas diferentes tem força **1,0**; feita por uma pessoa só tem força **0,5** [pesquisa: valor da Tolda Viva após o red team]. O ambiente (chuva, poça natural, piche dos inimigos) conta como "outra pessoa" com força **0,75**, para que o jogador solo também tenha reações boas sem que o mundo faça o trabalho todo.

**O fogo amigo construtivo deste conceito** é o **óleo como isolante e combustível**: untar o amigo antes de eletrificar a poça deixa ele imune ao choque (o óleo isola), mas agora ele pega fogo fácil. Molhar o amigo em chamas apaga ele. E acender o amigo untado de propósito transforma ele numa **Tocha Viva**: ele vira uma fonte de luz de 6 m de raio por 8 s, perde 3 de vida por segundo e todo golpe dele deixa chama. Numa masmorra escura, isso é a diferença entre sair ou não.

**(2) Passar a arma ou o item no meio do golpe.** Qualquer golpe pode ser cancelado num **Lance**: o herói solta a ferramenta (ou a lanterna) em arco para um aliado. O voo dura 0,45 s. Quem aperta **Pegar** dentro dos últimos 0,25 s do voo faz um **golpe de recepção**, próprio da classe de quem pega e do item que chega. O item mais importante a passar aqui é a **lanterna de mão**: quem joga a lanterna fica no escuro, e quem pega faz a recepção **"Aceso"**, um giro de 360° que pinta todos os gravados num raio de 4 m e deixa eles vulneráveis. Isso cria a decisão central de luz do jogo: quem carrega a luz agora?

**(3) Maquinaria operada em dupla e o caído que continua jogando.** A maior máquina é a própria caravana (rédeas e freio). Além dela: **o Feixe** da Torre-Lanterna (um gira a manivela que dá energia, outro mira); **pontes de corda** que precisam de dois guinchos ao mesmo tempo; **contrapesos** em ruínas (um sobe na plataforma, outro solta a trava); **alçapões** em masmorras (um segura a corda, outro atrai inimigos para cima); **sinos de alarme** que atordoam a área se dois puxarem as cordas em lados opostos. Toda máquina funciona por **posição e por segurar**, não por tempo exato, para tolerar 150 ms de rede [pesquisa: "mecânica por posição, não por tempo"]. O caído vira **mariposa** (ver Morte e reviver) e pode girar manivelas com metade da força, levar uma fagulha para acender um pavio e puxar cordas leves.

**(4) Matérias que reagem quando outra pessoa aplica a segunda.** Nos inimigos, a matéria fica como **mancha**: uma pincelada de guache no corpo, com contorno na cor do jogador que aplicou e um ícone de forma própria (gota para óleo, chama para chama, cristal para sal, raio para faísca). A mancha dura 5 s e cada alvo guarda até duas. A mira automática **prefere o alvo manchado por outra pessoa**, e a mancha pisca na cor de quem preparou [pesquisa: correção da Tolda Viva no red team]. Com mouse ou controle, a preferência pode ser ignorada.

### As matérias e as reações

Cada classe traz uma matéria. Água e Treva vêm do ambiente e dos inimigos.

| Matérias | Reação | Efeito com força 1,0 |
|---|---|---|
| Óleo + Chama | **Labareda** | 40 de dano, depois 10/s por 4 s numa área de 4 m. Cria luz de 8 m por 6 s: pinta todos os gravados dentro |
| Água + Faísca | **Poça Viva** | 30 de dano e atordoa por 1,2 s tudo que estiver molhado na poça. Quem está untado não toma nada |
| Óleo + Faísca | **Estouro** | 55 de dano em 3 m e empurrão de 4 m. Derruba gravados de pontes e beiradas |
| Água + Chama | **Vapor** | Nuvem de 5 m por 5 s. Inimigos dentro perdem o alvo; o ladino fica invisível dentro |
| Óleo + Água | **Lodo** | Chão escorregadio por 6 s. Inimigos que correm derrapam e caem por 1 s |
| Sal + Treva | **Purga** | 60 de dano em gravados, limpa o chão enegrecido e devolve a cor ao lugar |
| Sal + Chama | **Clarão de Sal** | Luz branca de 6 m por 0,5 s: cega inimigos por 2 s e interrompe qualquer telegrafia |
| Sal + Água | **Salmoura** | Chão consagrado fraco por 8 s: a Treva não entra e cura 3/s |
| Faísca + Sal | **Chiado** | Cristais que estalam: 8 de dano por segundo por 4 s em quem pisar, aliados incluídos |
| Chama + Treva | **Fumo Negro** | **Reação ruim.** O fogo fica preto, não ilumina, espalha chão enegrecido e queima aliados em 8/s. Evita-se com Sal antes |

### Solo com IA

Quem joga sozinho contrata na taverna até **um mercenário** (dois com melhoria). O mercenário segue o padrão do Bosco de Deep Rock Galactic: entra quando o jogador está sozinho, some quando chega gente, obedece a um "ping" e corre para reviver [pesquisa: `coop-rede.md`, item 12].

- **Ordens de um botão:** *siga*, *segure aqui*, *prepare o meu alvo* (aplica a matéria dele no inimigo que eu miro) e *pegue a lanterna*.
- **Regra de ouro:** o mercenário **nunca** faz Fumo Negro, nunca eletrifica uma poça com o jogador molhado dentro e sempre espera o jogador sair da área antes de detonar. Ele não pode irritar.
- **Troca de corpo.** O jogador solo pode trocar de corpo com o mercenário a qualquer momento (1 s de recarga), como em Full Metal Furies [pesquisa]. Assim, a maquinaria em dupla funciona sozinho: segura a manivela com um, troca, mira o Feixe com o outro.
- **Força das reações com IA:** reação montada por jogador + mercenário vale **0,8**.

### Fogo amigo

Todas as matérias afetam aliados. O dano direto de ferramenta entre aliados é desligado; o dano de reação não. O fogo amigo segue a escala da pesquisa: 100% até 2 jogadores, 70% com 3 e 50% com 4 [pesquisa: `coop-rede.md`, 7.2]. O que machuca sempre usa a cor de perigo, mesmo quando foi feito por um aliado [pesquisa: `direcao-de-arte.md`, regra 3].

### Morte e reviver

1. **Caído (6 s).** Com 0 de vida, o herói cai sentado, sem o chapéu. Qualquer aliado levanta ele segurando o botão por 2 s (mais 0,25 s por jogador extra) [pesquisa]. O caído pode se arrastar devagar.
2. **Mariposa.** Se ninguém chega, o herói vira uma mariposa do tamanho de uma mão, na cor do jogador, e o chapéu fica no chão. A mariposa voa a 1,5× a velocidade normal, atravessa a Treva sem encher Fuligem e não ataca. Ela pode: girar manivelas com metade da força; levar uma fagulha de uma chama para acender um pavio, um braseiro ou uma mancha de óleo (conta como chama dela, então vale como **segunda pessoa** numa reação); pousar no rosto de um inimigo comum e cegá-lo por 1 s (uma vez a cada 6 s).
3. **Voltar.** A mariposa volta à vida ao entrar em qualquer luz segurada por um aliado: a lanterna de mão erguida, uma Tocha Viva ou o halo da caravana. O aliado precisa ficar parado com a lanterna erguida por 1 s ("Acolher"). Um braseiro aceso também revive, mas leva 4 s. O herói volta com 50% da vida e precisa buscar o chapéu (sem ele, usa a classe básica **Andarilho**, com um pau e sem matéria).
4. **Custo.** Virar mariposa derruba 30% do conteúdo do saco de saque no chão, para quem quiser pegar.

### Saque compartilhado

- **Equipamento é individual.** Cada jogador vê os próprios itens caídos, na cor dele. Ninguém rouba a peça boa do amigo.
- **Sebo, ouro e materiais de forja são do grupo.** Vão para o cofre da caravana.
- **Relíquias são pesadas.** Os baús grandes e as relíquias de contrato precisam ser **carregados por dois**, um em cada alça, a 60% da velocidade e sem atacar. Um sozinho arrasta a relíquia a 25% da velocidade. Isso põe os outros dois de escolta e cria o momento clássico de "corre, corre, corre" com a Treva subindo.
- **O saco de saque** de cada herói cresce visivelmente nas costas conforme ele carrega moedas e materiais. Com o saco cheio, o herói anda 10% mais devagar. Esvazia-se na caravana.

### Local e online no PC

- **Local na mesma tela, até 4.** Câmera compartilhada que enquadra o grupo entre 16 e 24 m de distância. Passou disso, há parede invisível na borda e o retardatário é levado, depois de 3 s, para dentro da luz do aliado mais próximo [pesquisa: `coop-rede.md`, item 4]. A própria luz mantém o grupo junto: ninguém quer ficar no escuro sozinho.
- **Online, até 4, entrada a quente.** Cada um tem a própria câmera e pode se separar livremente (é aí que o mundo aberto respira). O anfitrião decide inimigos, dano, saque, sorteio e a posição da caravana. Cada cliente é dono do próprio movimento [pesquisa: item 8]. A caravana anda sobre a estrada como um trilho, então sincronizar a Wain custa só posição na curva, velocidade e estado do freio.
- **Misto.** Dois jogadores locais num PC podem entrar online numa sala com mais dois.
- **Escala por número de jogadores** [pesquisa: `coop-rede.md`, 7.2]: quantidade de inimigos 1,00 / 1,35 / 1,70 / 2,05; vida de comuns 1,00 / 1,15 / 1,30 / 1,45; vida de chefe 1,00 / 1,60 / 2,20 / 2,80, para 1 a 4 jogadores. O dano por golpe não muda.

---

## 7. Combate com números concretos

Tudo a 60 quadros por segundo. Contagens de quadro seguem a tabela-base de `animacao-principios.md` [pesquisa].

### Regras gerais

| Grandeza | Valor |
|---|---|
| Esquiva | 0 a 2 quadros de início, 12 quadros invulnerável, 10 de recuperação, 4,5 m. Recarga de 0,6 s |
| Bloqueio (só a guerreira) | Frontal de 120°, reduz 80% do dano |
| Congelamento de impacto | 3 a 4 quadros no golpe leve, 10 no pesado, 18 na reação, local ao atacante e ao alvo [pesquisa] |
| Telegrafia de inimigo comum | 24 a 36 quadros (0,4 a 0,6 s), sempre com som próprio no fim da espera [pesquisa] |
| Telegrafia de chefe | 45 a 90 quadros, com marca no chão do tamanho real |
| Manchas | Duram 5 s; até 2 por alvo; até 2 por célula de chão de 1 m |
| Dano em **gravados** | Inimigo dentro da Treva recebe **50% do dano**. Iluminado (por qualquer luz), recebe 100%. Pintado por reação de luz (Labareda, Aceso, Clarão, Feixe), recebe **125%** por 4 s |

### A luz como regra de combate

| Fonte de luz | Raio | Duração |
|---|---|---|
| Halo da caravana | 18 m (até 26 m) | Contínua, gasta 1 sebo a cada 2 min |
| Braseiro aceso | 12 m | Permanente |
| Lanterna de mão | 5 m (7,5 m erguida) | 120 s de óleo; erguida gasta o dobro |
| Tocha Viva | 6 m | 8 s |
| Labareda | 8 m | 6 s |

**Fuligem** (0 a 100): fora de qualquer luz, sobe 6/s de noite e 2/s de dia. Dentro da luz, desce 25/s. Com 50, a borda da tela começa a ser hachurada e o som fica abafado. Com 100, o herói fica **Apagado**: anda 30% mais devagar, perde 4 de vida por segundo e, a cada 4 s, uma **Mão de Breu** sai do chão perto dele e tenta segurá-lo por 1,5 s (telegrafia de 30 quadros).

### Vida dos heróis

Guerreira 160, Clériga 120, Ladino 100, Mago 90.

---

## 8. Quatro classes jogáveis

Proporção comum: **2,25 cabeças** de altura; herói com 0,9 m no mundo, cabeça de 0,4 m; mãos de luva com 3 dedos; rosto pintado por shader com 4 parâmetros (abertura, inclinação, curva e pupila) [pesquisa: doação do Lumaréu]. Cada classe anima num **ritmo de poses próprio** para ganhar personalidade [pesquisa]; capa, chapéu, chama e sino rodam a 60 quadros por segundo por cima, com `SpringBoneSimulator3D`.

### 8.1 A Rodeira (guerreira)

**Silhueta:** um elmo-panela amassado, que cobre os olhos até a metade, e uma **roda de carroça** inteira presa no braço como escudo, maior que o corpo dela. De qualquer distância, é "uma roda com perninhas".

**Matéria: Óleo** (graxa de eixo, num balde no cinto).

**Kit:**
- **Combo de roda** (3 golpes): 14 / 14 / 26 de dano; início de 5 / 5 / 9 quadros; recuperação de 14 / 14 / 24.
- **Escudo de roda:** segurar bloqueia na frente (120°, −80%).
- **Rolar a Roda** (recarga 6 s): ela solta a roda, que rola em linha reta por 12 m, dá 40 de dano, quica em paredes duas vezes e para. Sem a roda, ela briga **no tapa** (8 de dano, 4 quadros), muito brava, até buscar a roda ou alguém devolver com um Lance.
- **Untar** (botão de matéria): joga um balde de graxa num cone de 3 m. Mancha os inimigos e o chão de Óleo. Num aliado, unta ele (isolante e inflamável).
- **Recepção** (quando pega um item no ar): **"Eixo"**, ela crava o item no chão como pivô e gira em volta dele, empurrando tudo a 3 m.

**Equipamento visível:** a roda (raios de madeira, de ferro, cravejada, dentada de moinho); o elmo-panela (com amassados, com pluma de crina, com viseira de grade); manto de lona com manchas de graxa; balde de graxa no cinto.

**Personalidade pela animação:** teimosa, pesada, corajosa e um pouco bruta.
- *Ritmo de poses:* 12 por segundo, com **poses seguradas longas**. Ela para e encara.
- *Antecipação:* curta no golpe (5 quadros), mas no Rolar a Roda ela recua o corpo inteiro e quase cai para trás (16 quadros, só porque é golpe pesado).
- *Achatar e esticar:* o corpo achata 0,8 a cada passo pesado; a roda nunca deforma (é ferro e madeira, desenho sólido).
- *Continuidade:* depois do golpe, o elmo continua girando meio quarto de volta e cai sobre o olho; ela empurra ele de volta com o dedo, como ação secundária.
- *Exagero:* sem a roda, o tapa é rápido demais e ela bufa, com uma nuvem de vapor saindo do elmo.
- *Apelo:* ela é a única que sorri depois de apanhar.

### 8.2 O Pavieiro (mago)

**Silhueta:** um **chapéu cônico que é uma vela**, de cera amarela escorrida, com o pavio aceso na ponta. A altura do chapéu é o recurso de magia: **o chapéu derrete conforme ele lança feitiços** e cresce de novo dentro da luz. Corpo magro, manga larga, barba de cera.

**Matéria: Chama.**

**Recurso Pavio:** 100. Regenera 5/s **só dentro de uma luz**; no escuro, não regenera. O mago depende do grupo para ficar perto da luz e é o que mais sofre com a Treva.

**Kit:**
- **Fagulha** (projétil): 12 de dano, 6 quadros de início, custa 5 de Pavio. Deixa mancha de Chama.
- **Sopro** (canalizado): cone de 4 m, 6 de dano a cada 0,2 s, custa 15/s. Acende óleo, seca água, ilumina 3 m na frente.
- **Pavio Longo** (recarga 10 s): estende um **fio de pavio** do chapéu até um ponto a 10 m. O fio fica no chão por 8 s; qualquer chama que toque nele corre pela linha inteira em 0,5 s. Serve para levar fogo até um óleo distante, até um braseiro alto ou até a mancha do amigo.
- **Recepção:** **"Mecha"**, ele acende o item que recebeu: a próxima ação com aquele item deixa Chama.

**Equipamento visível:** o chapéu-vela (cera amarela, cera vermelha de lacre, cera negra de igreja, vela de três pavios); cajado curto com castiçal; manto com queimaduras; cinto de velas de reserva.

**Personalidade pela animação:** nervoso, vaidoso e um pouco covarde, mas brilhante.
- *Ritmo de poses:* 15 por segundo, com tremor fino nas mãos entre poses.
- *Ação secundária:* a chama do chapéu reage a tudo. Ela se encolhe quando ele leva susto, estica quando ele lança um feitiço grande e se inclina com o vento.
- *Arcos:* os gestos de mão desenham arcos largos e teatrais, sempre maiores do que o feitiço precisa.
- *Tempo:* quando o Pavio acaba, ele faz uma pose segurada de 20 quadros olhando para o toco do chapéu, de boca aberta.
- *Aceleração e desaceleração:* anda com aceleração rápida e parada lenta, como quem tropeça no manto.
- *Exagero:* quando vira Tocha Viva, ele corre em círculos de braços para cima, gritando, e solta fogo melhor do que nunca.

### 8.3 A Sineira (clériga)

**Silhueta:** um **sino de bronze do tamanho do corpo dela**, pendurado na ponta de um cabo comprido, que ela leva no ombro. Capuz pontudo de freira-guerreira, com uma faixa de pano que cai até os pés.

**Matéria: Sal** (num saquinho no cinto, jogado em punhados).

**Kit:**
- **Badaladas** (combo de 2): 18 / 28 de dano, início de 8 / 14 quadros, com o sino em arco largo.
- **Badalada Funda** (recarga 8 s): ela crava o cabo no chão e toca o sino. Onda de 5 m, 10 de dano, **pinta todos os gravados por 4 s** e **interrompe a telegrafia de qualquer inimigo comum**.
- **Punhado de Sal:** mancha de Sal num arco de 3 m. No chão, vira **consagrado** por 6 s (a Treva não entra, aliados curam 4/s). Num aliado, limpa 40 de Fuligem.
- **Recepção:** **"Repique"**, ela toca o item no sino; o golpe dele dá 50% a mais e espalha sal.

**Equipamento visível:** o sino (bronze liso, bronze rachado, sino de navio, sino de defunto com badalo de osso); o capuz e a faixa; um terço de dentes de lobo; o saquinho de sal.

**Personalidade pela animação:** solene, séria e seca, com humor de quem já enterrou muita gente.
- *Ritmo de poses:* 10 por segundo, o mais lento do grupo, com **poses seguradas** longas e paradas.
- *Continuidade e ação sobreposta:* o sino é pesado; ele sempre chega depois do corpo dela e continua balançando 3 vezes depois que ela para, puxando os ombros.
- *Encenação:* antes da Badalada Funda, ela fecha os olhos e espera 2 quadros parada. É a única pausa calma da tela inteira.
- *Desenho sólido:* o sino nunca deforma; o corpo dela inclina para compensar o peso, com a linha de ação sempre curva.
- *Apelo:* quando revive alguém, ela bate de leve no chapéu da pessoa, com cara de impaciência.

### 8.4 O Gatuno (ladino)

**Silhueta:** um **capuz enorme com duas pontas caídas** como orelhas de lebre e um **saco de saque nas costas** que cresce de verdade conforme ele carrega coisas. Corpo pequeno e curvado, pés grandes e silenciosos.

**Matéria: Faísca** (pederneira e pavios curtos).

**Kit:**
- **Facadas** (combo de 4): 7 / 7 / 7 / 16, início de 3 quadros, o mais rápido do jogo. Pelas costas, ×2,5.
- **Pederneira:** joga uma pedra que estala e deixa mancha de Faísca numa área de 1,5 m. Na água, faz Poça Viva.
- **Gancho** (recarga 5 s): corda de 9 m. Puxa um inimigo comum para perto, puxa ele próprio até um ponto alto, ou **puxa um aliado** para fora do perigo.
- **Bolso:** rouba um item de inimigo que estiver atordoado (flechas do besteiro, a vela do Apagador, o óleo do saco dos Mudos).
- **Recepção:** **"Bote"**, ele pega o item, some numa rolagem e reaparece atrás do alvo mais próximo com um golpe pelas costas.

**Equipamento visível:** o capuz (de pano, de couro, com chocalhos, com orelhas de pele de gato-gravado); o saco (que vira um baú com pernas na raridade Lendária); dois punhais; um rolo de corda no ombro.

**Personalidade pela animação:** guloso, rápido e sem vergonha.
- *Ritmo de poses:* 20 por segundo, rápido e cheio de poses curtas.
- *Achatar e esticar:* o maior do grupo. Ele estica 1,3 na esquiva e achata 0,7 ao pousar. O saco achata junto e espalha moedas.
- *Antecipação:* quase nenhuma no golpe; mas antes de roubar, ele olha para os dois lados, numa pose de 6 quadros.
- *Ação secundária:* as pontas do capuz se mexem como orelhas de bicho, levantando quando ele vê saque e caindo quando ele toma dano.
- *Arcos:* o pulo do gancho faz um arco alto e exagerado, com o saco atrasado na ponta.
- *Straight ahead:* a fuga com saque cheio é animada direto, sem poses-chave, de propósito desajeitada.

### Resumo dos 12 princípios por classe

| Princípio | Rodeira | Pavieiro | Sineira | Gatuno |
|---|---|---|---|---|
| Achatar e esticar | 0,8 no passo, roda rígida | Chapéu-vela estica no feitiço | Mínimo, corpo sólido | 0,7 a 1,3, o maior |
| Antecipação | Curta, longa só no Rolar | Média, teatral | Pausa calma antes da Funda | Quase nenhuma |
| Encenação | Encara de frente | Sempre de lado, se mostrando | Centro, parada | De costas, olhando por cima |
| Pose a pose / direto | Pose a pose | Pose a pose com tremor | Pose a pose | Direto na fuga |
| Continuidade | Elmo gira e cai no olho | Barba de cera balança | Sino balança 3 vezes | Saco atrasado |
| Aceleração e desaceleração | Partida lenta, parada seca | Partida rápida, parada lenta | Tudo lento | Tudo seco |
| Arcos | Curtos e retos | Largos e floreados | Longos e pesados | Altos no pulo |
| Ação secundária | Empurra o elmo | Chama reage | Ajeita a faixa | Orelhas do capuz |
| Tempo (poses/s) | 12 | 15 | 10 | 20 |
| Exagero | Tapa furioso | Tocha Viva em pânico | Nenhum, é o contraste | Moedas voando |
| Desenho sólido | Roda e elmo indeformáveis | Cera com volume | Sino indeformável | Saco com volume |
| Apelo | Sorri depois de apanhar | Vaidade derretida | Impaciência carinhosa | Gula |

As 4 cores de jogador ficam separadas por cerca de 90° e repetem no manto, no anel do chão, na mariposa e nos números de dano [pesquisa]: **Carmim** (cerca de 20°), **Ouro velho** (cerca de 60°), **Celeste** (cerca de 200°) e **Lilás** (cerca de 290°). Cada jogador também tem um símbolo de forma no anel (círculo, triângulo, quadrado e losango) para não depender de cor.

---

## 9. Inimigos

**Regra de telegrafia, herdada do Lumaréu** [pesquisa]: o perigo encolhe, a ajuda cresce. Toda telegrafia inimiga é uma forma que se fecha, na cor de perigo reservada (verde-ácido, ver a paleta). Todo efeito de herói é uma forma que se abre.

### 9.1 Fuligento (comum, em bando)

Um bicho do tamanho do herói, feito de fuligem e linhas de gravura, com dois olhos brancos. Vem em bandos de 4 a 8.
- **Vida:** 30. **Dano:** 8 por mordida.
- **Telegrafia:** agacha, e os dois olhos passam de pontos redondos para fendas finas (24 quadros), com um estalo seco no fim. Depois pula 4 m em linha reta.
- **Punição:** fica 30 quadros caído depois do pulo.
- **Fraqueza:** queima rápido; uma Labareda limpa um bando inteiro. Iluminado, ele foge da luz por 1 s antes de voltar.

### 9.2 Apagador (elite)

Uma figura alta e magra, com o dobro da altura do herói, de túnica preta, e no lugar da cabeça um **apagador de vela de latão**, aquele cone com cabo. Ele anda direto para a luz mais próxima: a lanterna do herói, um braseiro, a caravana.
- **Vida:** 140. **Dano:** 30 na pancada do cone.
- **Telegrafia principal, Abafar:** ergue o cone acima da fonte de luz por 48 quadros (0,8 s). Um anel verde-ácido se fecha em volta da luz alvo. Se completar, apaga a lanterna do herói (o óleo fica, mas precisa reacender com chama) ou apaga um braseiro (precisa reacender). Interrompe-se com dano de 30 dentro da janela, com a Badalada Funda ou com Clarão de Sal.
- **Telegrafia secundária, Pancada:** levanta o cone de lado, 30 quadros, e bate num arco de 2,5 m.
- **Fraqueza:** o Gatuno pode roubar o cone com Bolso quando ele está atordoado. Sem o cone, o Apagador vira um gravado comum que foge.

### 9.3 Cão-de-Breu (comum, corredor)

Um cachorro magro de piche que escorre. Deixa um rastro de **chão enegrecido** por onde passa.
- **Vida:** 90. **Dano:** 22 na investida.
- **Telegrafia:** as orelhas deitam, o piche pinga mais rápido e uma linha de piche escorre no chão na direção da investida (36 quadros). A linha marca o caminho verdadeiro.
- **Armadilha:** fogo no rastro dele vira **Fumo Negro**. Sal antes (Purga) limpa o rastro e dá 60 de dano. É o inimigo que ensina a ordem das matérias.

### 9.4 Mudo Besteiro (comum, à distância, humano)

Bandoleiros que vivem na Treva com **lanternas costuradas sobre o rosto**, apagadas, e a boca coberta. Não falam. Roubam caravanas.
- **Vida:** 70. **Dano:** 18 por virote.
- **Telegrafia:** levanta a besta; uma linha fina verde-ácido sai da besta até o alvo e encurta (42 quadros, 0,7 s). No fim, a linha some e o virote sai.
- **Comportamento:** dois Mudos sempre tentam chegar à caravana e roubar sebo; se conseguirem, correm para a Treva. O grupo precisa escolher entre perseguir ou deixar ir.
- **Fraqueza:** o Gatuno rouba a aljava; sem virotes, o Mudo puxa uma faca e luta mal. Untado, ele escorrega e cai da besta.

### 9.5 Chefe: a Mãe-Traça do Farol Cego

**Quem é.** Uma mariposa negra gigante, com 12 m de envergadura, que vive no Farol Cego, na ponta do Brejo. Ela come luz. Foi ela que cegou o farol, e a luz do farol ainda está dentro dela, fazendo o corpo dela pulsar por dentro como uma lanterna suja. O pó das asas dela é a fuligem que neva sobre o Brejo.

**A chegada.** O farol é visto desde o começo do jogo. O contrato final do Brejo pede para reacender a lente. A estrada até o rochedo é uma subida em espiral que a caravana só faz com freio e rédeas em dupla, com Fuligentos caindo do penhasco. A Wain para no pátio do farol, e o halo dela é a arena: um terreno aberto de 40 m no alto do rochedo, com o mar à esquerda, o farol à direita e o Brejo inteiro lá embaixo, sob a névoa.

**Vida:** 2.000 com 1 jogador, 3.200 com 2, 4.400 com 3 e 5.600 com 4 [pesquisa: fórmula 1 + 0,6 × (n − 1)].

**Fase 1, o céu (100% a 65%).** Ela voa em círculos fora do halo, na Treva, onde recebe só 50% do dano.
- **Mergulho** (telegrafia de 60 quadros): ela some no escuro, e uma sombra elíptica verde-ácido se fecha no chão onde vai cair. Ao cair, dá 35 de dano em 4 m e fica 90 quadros no chão, iluminada e vulnerável.
- **Comer a Luz** (telegrafia de 75 quadros): ela pousa no telhado de um vagão e abre as asas. Um anel se fecha em volta da Grande Lanterna. Se completar, o halo da caravana encolhe 4 m (até 10 m no mínimo). Interrompe-se com 120 de dano nela durante a janela ou com o Feixe.
- **Neve de pó:** o tempo todo, o pó das asas cai como neve e enche Fuligem 1/s mesmo dentro do halo.

**Fase 2, o chão (65% a 30%).** Ela se cansa e pousa, rastejando pelo pátio.
- **O Feixe.** Dois jogadores sobem na Torre-Lanterna: um gira a manivela (segurar perto da manivela, carrega 0% a 100% em 5 s) e outro mira. O Feixe aceso por 3 s pinta a Mãe-Traça inteira (125% de dano) e a deixa atordoada por 2 s. A mariposa de um caído pode ajudar a girar com metade da força.
- **Varrida de asa** (telegrafia de 45 quadros): ela recolhe uma asa; um leque verde-ácido de 120° se fecha. 28 de dano e empurrão de 5 m, que pode jogar o herói para fora do halo.
- **Ovos de fuligem:** a cada 20 s, deixa 3 ovos que viram Fuligentos em 8 s. Labareda neles evita o bando.
- **Cordas da lente.** No lado do farol há duas cordas presas à lente antiga. Se dois heróis puxarem ao mesmo tempo enquanto ela está atordoada, a lente cai sobre ela: 300 de dano e ela fica presa por 4 s.

**Fase 3, a lanterna suja (30% a 0%).** Ela se agarra ao próprio farol e começa a sugar toda a luz do rochedo: o halo da caravana encolhe 1 m a cada 5 s, sem parar.
- **A saída:** o grupo precisa sobrecarregar a lente do farol. Um herói unta a lente (Óleo), outro acende (Chama), e a Labareda dentro da lente vira o farol de novo. Enquanto o óleo arde, o feixe do farol queima a Mãe-Traça por 40 de dano por segundo. Cada sobrecarga dura 6 s e precisa ser refeita.
- **Grito escuro** (telegrafia de 90 quadros): ela fecha as asas em volta do corpo e o pátio inteiro escurece de fora para dentro, com o anel se fechando até 6 m do centro. Quem estiver fora dele no fim fica **Apagado** na hora. A saída é correr para o centro, para um chão consagrado ou para perto de uma Tocha Viva.
- **Morte:** a Mãe-Traça se desfaz em milhares de mariposas pequenas, que voam para a lente acesa e queimam como faíscas. O farol volta a funcionar de verdade pela primeira vez em quarenta anos, e o feixe passa sobre o Brejo inteiro e o pinta: por alguns segundos, a região toda vira guache. A rota para a Mata Vergada abre.

**Recompensa:** o chapéu-vela de três pavios (Lendário), o vagão-Capela e uma melhoria do Feixe.

---

## 10. Três regiões

### 10.1 O Brejo das Lamparinas Afogadas

Um pântano raso e largo, cortado por passarelas de tábua sobre palafitas, com juncos altos, árvores mortas de galhos brancos e centenas de lanternas antigas afundadas na água, que piscam fraco lá embaixo. Termina num rochedo sobre o mar, com o Farol Cego.
- **Matéria do ambiente:** água por toda parte; chuva frequente.
- **Inimigos:** Fuligentos, Cães-de-Breu e luzes falsas (lanternas que andam e levam o herói para a Treva).
- **Mecânica própria:** a maré. De noite, a água baixa e descobre capelas afundadas; de dia, sobe.

### 10.2 A Mata Vergada

Uma floresta de árvores velhíssimas cujos troncos se curvaram sobre a estrada como arcos, formando túneis de 40 m de altura. Folhas caem o tempo todo. A Ponte dos Mil Sinos atravessa a copa.
- **Matéria do ambiente:** madeira seca e resina (pega fogo fácil, o óleo do mundo) e teias.
- **Inimigos:** Apagadores, Mudos Besteiros nos galhos, aranhas gravadas.
- **Mecânica própria:** o vento muda de direção a cada fase do dia e decide para onde o fogo vai. Incêndio na floresta é arma e perigo.

### 10.3 O Planalto das Cinzas

Um planalto alto e aberto, coberto de cinza que cai como neve, com ruínas de templos do sol e o Gigante Ajoelhado no centro. Faz frio; o vento corta.
- **Matéria do ambiente:** cinza (abafa chama, mostra pegadas) e gelo nas poças.
- **Inimigos:** todos, mais os Gravados Antigos, sacerdotes do sol presos em linhas.
- **Mecânica própria:** a altitude. Quanto mais alto, mais rápido a lanterna gasta óleo; a caravana precisa de braseiros a cada 150 m.

---

## 11. Direção de arte: regras concretas

### A ideia: a luz pinta, a Treva grava

A linguagem visual nasce da regra central do mundo. **O que está na luz é pintado em guache**; **o que está na Treva é uma gravura em água-forte**, desenhada em linhas finas sobre fundo azul-noite. O mesmo objeto muda de técnica conforme a luz chega ou vai embora. A fronteira entre as duas é uma **frente de pincel**: uma borda irregular onde a tinta escorre para dentro da gravura quando a luz se aproxima, e onde a tinta seca e se desfaz em linhas quando a luz se afasta.

Por que isso nasce do mundo: a Treva transforma as coisas em gravura (é a história), a luz é a única coisa que devolve a cor (é a mecânica) e o jogador **vê** a regra de dano (gravado recebe 50%) sem precisar de ícone. Por que é legível: a escuridão nunca é preta; ela é desenhada.

Tudo é **3D toon** com modelos do Blender, heróis pequenos de cabeça grande, câmera de cima em perspectiva.

### Material

- **Um único shader-base** (`pintado_pela_luz.gdshader`) para personagens e cenário, com um parâmetro global: a lista de até 8 **luzes de pavio** (posição, raio e força) passada como uniforme global. Cada pixel calcula o quanto está iluminado por essas luzes com uma conta simples de distância. Isso roda igual no Compatibility e no Forward+, porque não depende das luzes do motor.
- **Na luz (guache):** 3 faixas de tom (luz, meia-luz e sombra), sem degradê. A borda entre faixas é recortada por uma textura de pincelada em projeção triplanar, com 0,5 m de escala no mundo. A tinta é opaca e fosca, sem brilho especular, a não ser um ponto de luz pintado em metais e no bronze do sino. A sombra é multiplicada pela tinta de sombra (violeta-fuligem), nunca preta [pesquisa: regra 6 do contrato anti-slop].
- **Na Treva (gravura):** a cor some e vira tinta azul-noite. O tom passa a ser feito por **hachuras** de linhas claras. A densidade das linhas cresce com a escuridão e a direção delas segue a forma (projeção triplanar com 3 orientações de linha, rotacionadas por face). As linhas "fervem" a 8 quadros por segundo, com semente fixa [pesquisa: regra 7].
- **A frente de pincel:** uma faixa de 0,6 a 1,2 m na borda de cada luz, com ruído animado, onde a tinta tem aspecto de guache molhado, mais saturado, escorrendo.

### Paleta com valores

Valores medidos em HSV na captura final, seguindo o orçamento da pesquisa (chão de 25 a 55% de valor, jogadores de 50 a 85%, aviso de 70 a 95% com matiz reservado) [pesquisa: `direcao-de-arte.md`, 7.2]. Paleta mestra de 24 cores no máximo.

| Nome | Hex | Valor | Saturação | Uso |
|---|---|---|---|---|
| Sebo | `#F2DDB0` | 95% | 27% | Luz mais alta pintada, cera, papel |
| Âmbar de lanterna | `#E8A24A` | 91% | 68% | Coração da luz quente, chamas |
| Telha queimada | `#B5583A` | 71% | 68% | Madeira de vagão, terra quente |
| Couro velho | `#7A4A2E` | 48% | 62% | Sombra quente, tábuas |
| Musgo seco | `#6B7340` | 45% | 44% | Vegetação na luz |
| Violeta-fuligem | `#3E3350` | 31% | 36% | Tinta de sombra em tudo que é pintado |
| Azul-gravura | `#2B3A52` | 32% | 48% | Fundo da Treva, perto |
| Tinta-noite | `#161C2A` | 16% | 48% | Fundo da Treva, longe; valor mínimo do cenário |
| Linha de água-forte | `#8296B0` | 69% | 26% | Hachuras da Treva |
| Cinza de céu | `#5A5F6E` | 43% | 19% | Céu de dia, perspectiva atmosférica |
| **Verde-ácido (perigo)** | `#C6EE3A` | 93% | 76% | **Só telegrafia inimiga**. Nenhum outro uso |
| Carmim (jogador 1) | `#E0503C` | 88% | 73% | |
| Ouro velho (jogador 2) | `#E8C34A` | 91% | 68% | |
| Celeste (jogador 3) | `#5CB8EE` | 93% | 61% | |
| Lilás (jogador 4) | `#B07BE6` | 90% | 46% | |

Regra 60/30/10 por região: o Brejo é Azul-gravura / Musgo / Âmbar; a Mata é Couro / Violeta / Âmbar; o Planalto é Cinza de céu / Sebo / Âmbar. O âmbar é sempre o acento: a luz é o único 10% que se repete no jogo inteiro.

### Luz

- **Uma direção de luz-chave no jogo inteiro:** o Sol Velho, de cima e da esquerda, frio e fraco (de dia) ou a lua parda (de noite). Ela só faz as faixas de tom; quem decide pintado ou gravado são as luzes de pavio.
- **Quente é seguro, frio é ameaça.** Toda luz de jogador e da caravana é quente; tudo que vem da Treva é frio.
- **Heróis sempre têm a própria luz:** um reforço de borda quente vindo da lanterna de cinto, mesmo quando o óleo acaba (aí fica fraco e bruxuleante). Um herói nunca vira gravura por inteiro; com Fuligem alta, só as pernas começam a ser hachuradas, de baixo para cima.
- **Cada reação de fogo ou sal acende uma luz de pavio**; no máximo 8 ao mesmo tempo no iPhone, as mais fracas cedem lugar.
- **[PC]** As lanternas também são luzes do motor com sombra (1 com sombra PCSS para a Grande Lanterna, até 6 sem sombra), e há uma GI leve no fundo.

### Névoa

- **Névoa de altura** nos vales, cor Azul-gravura, só de valor 25 a 35%. Nunca cobre o plano de jogo; fica atrás e nas bordas [pesquisa: regra 9].
- **Três camadas de "névoa pintada":** lâminas transparentes com forma de pincelada, que andam em velocidades diferentes (0,2, 0,5 e 1,1 m/s) a 8, 25 e 80 m da câmera. Dentro do halo, a névoa pega o âmbar da luz; fora dele, vira linhas de hachura horizontais.
- **[PC]** Névoa volumétrica de verdade com `FogVolume` em volta das lanternas, que faz halos visíveis e feixes onde a luz atravessa galhos, juncos e as tábuas dos vagões.
- **[iPhone]** Névoa por profundidade e altura do `Environment`, 2 das 3 camadas pintadas e cones aditivos falsos no lugar dos feixes.

### Contorno

- **Na luz:** traço de 2 px em 1080p, cor Couro velho escurecido, com variação de ±20% como pressão de pincel [pesquisa: regra 5].
- **Na Treva:** traço de 3,5 px, cor Tinta-noite, com uma segunda linha clara de 1 px por dentro, como o sulco da gravura.
- **Heróis:** 3 px sempre, na cor escura do jogador, e silhueta chapada na cor do jogador quando ficam atrás de um objeto [pesquisa: regra 17].
- Técnica: casca invertida com espessura constante em tela, validada no Compatibility [pesquisa: `godot-render-vfx.md`, apêndice A.1].

### Proporção

Heróis com 2,25 cabeças e 0,9 m. Inimigos comuns entre 0,9 e 1,2 m; elites com 1,8 m; chefe muito maior que tudo. Os vagões têm 3 m de altura e Graxo tem 5 m: a escala da caravana faz os heróis parecerem miniaturas de mesa. **Família de formas:** a gota de cera (topo redondo, base achatada) para tudo que é vivo e quente; o chanfro de roda (octógono com cantos cortados) para tudo que é construído; a lasca (triângulo fino e quebrado) para tudo que vem da Treva.

### Câmera

| Modo | Distância | Inclinação | Campo de visão | O que mostra |
|---|---|---|---|---|
| **Combate** | 16 m | 52° | 30° | Arena de cerca de 20 m; os 12% de cima da tela mostram horizonte e céu |
| **Exploração** | 22 m | 44° | 32° | A faixa de cima (cerca de 22%) mostra marcos ao longe |
| **Caravana** (conduzindo) | 26 m | 40° | 34° | Graxo, os vagões e a estrada à frente |

Com essa câmera de combate, o herói ocupa cerca de 10% da altura da tela, acima do mínimo de 9% da pesquisa. O fundo além de 60 m ganha desfoque leve (DOF no PC, tilt-shift por shader no iPhone) [pesquisa: `godot-render-vfx.md`, 10.3].

### Como a escuridão fica legível

1. A Treva tem **valor mínimo de 16%** (Tinta-noite). Nada no cenário jogável é preto.
2. Os contornos dos objetos na Treva são **mais claros** que o fundo (o sulco claro da gravura), então a forma do terreno se lê mesmo sem luz.
3. Inimigos gravados mostram **olhos brancos** e contorno claro; a telegrafia deles é verde-ácido e sem sombreamento, igual em qualquer luz.
4. Perigos no chão (piche, cristais, poças elétricas) são emissivos e se leem dentro e fora da luz.
5. A vinheta de Fuligem avisa antes do perigo: com 50, as bordas da tela começam a ser hachuradas.
6. Portões de teste em toda captura: cinza, borrão de 8 px, miniatura de 320 × 180, deuteranopia e protanopia entre os 4 jogadores [pesquisa].

### Como fugir de fantasia genérica

- **Proibido:** runas brilhando em tudo, magia roxa em redemoinho, metal plástico brilhante, caveiras como enfeite, dragões de capa, castelos de cartão-postal, a palavra "épico".
- **Os motivos vêm do mundo, não do gênero:** sebo, cera escorrida, pavios, mariposas, sinos, rodas, latão de lanterna, discos solares quebrados. Toda peça de cenário tem que responder à pergunta "o que esta coisa tem a ver com luz ou com a estrada?".
- **A arquitetura é de um culto do sol que perdeu o sol:** templos com aberturas para um céu que não brilha mais, candelabros do tamanho de torres, estátuas de mãos em concha.
- **Checagem de 3 palavras** com o grupo de amigos do usuário: se aparecer "genérico", "Diablo" ou "mobile", a captura reprova.
- **Imperfeição com orçamento:** registro de cor deslocado de 1 a 2 px na tinta pintada, linhas de gravura com semente fixa, tremor de vértice de 0,5 a 1% [pesquisa: regra 7].
- **Duas famílias tipográficas** de licença OFL: uma serifada de gravura para títulos e números de dano, uma sem serifa humanista para a interface.

---

## 12. Atmosfera

### Brejo das Lamparinas Afogadas

- **O que se vê:** água parada que reflete as lanternas da caravana em listras douradas; lanternas afundadas piscando como olhos verdes lá embaixo; juncos que balançam em ondas com o vento; chuva fina que só aparece como riscos dourados dentro da luz e some na Treva; vaga-lumes que são, na verdade, as luzes falsas; o Farol Cego piscando a cada 40 s; névoa de maré até a canela.
- **O que se ouve:** sapos que param todos ao mesmo tempo quando um inimigo se aproxima; tábuas rangendo sob Graxo; o sino da Torre Torta tocando sozinho com o vento; gotas na lona dos vagões; a respiração lenta e molhada de Graxo.
- **O que se sente:** vibração leve do controle a cada passo de Graxo; a câmera balança 0,5° quando a caravana passa por uma tábua solta; as pegadas dos heróis deixam ondas na água rasa.

### A Mata Vergada

- **O que se vê:** feixes de luz pálida entre os troncos curvos, de dia; folhas caindo sem parar, pintadas na luz e em linhas na Treva; teias com gotas que brilham quando a lanterna passa; a Ponte dos Mil Sinos lá no alto, balançando; brasas de resina subindo depois de uma Labareda; os mantos dos heróis e os estandartes da caravana virando com a mudança de vento.
- **O que se ouve:** mil sinos ao longe que soam diferente para cada direção de vento; galhos estalando; o silêncio pesado quando um Apagador está perto (os pássaros calam e as chamas encolhem); a resina estourando no fogo.
- **O que se sente:** o vento empurra 0,3 m/s na direção dele; os heróis inclinam o corpo contra o vento em rajadas; a vibração do controle acompanha os sinos durante a Badalada Funda.

### O Planalto das Cinzas

- **O que se vê:** cinza caindo como neve grossa; o Gigante Ajoelhado enorme no centro, com o disco solar rachado; céu baixo, com nuvens em camadas e um sol que mal se vê; pegadas na cinza (inclusive as de coisas que não se veem); ruínas com raios de sol de pedra; a Muralha de Treva bem perto no horizonte, subindo à noite.
- **O que se ouve:** vento contínuo, que muda de tom nas fendas da estátua; o estalo da cinza sob as rodas; uma voz muito grave e muito longe, que é a estátua; nenhum bicho.
- **O que se sente:** a lanterna treme mais (gasta mais óleo); a respiração dos heróis vira fumaça; tudo pesa: a caravana sobe devagar e o freio range.

---

## 13. Três efeitos-assinatura

### 13.1 A Frente de Pincel (o efeito do jogo inteiro)

Quando uma luz se acende (Labareda, Aceso, Clarão, braseiro), um anel de tinta sai do centro e **pinta o mundo**: a gravura azul vira guache quente em 0,4 s, com a borda molhada e escorrida, gotas de tinta respingando para fora e as hachuras se desfazendo como poeira de linha. Os inimigos gravados atingidos fazem um achatamento de susto (0,75 por 4 quadros) e ficam coloridos (125% de dano). Quando a luz acaba, o contrário acontece mais devagar (1,2 s): a tinta seca, racha e vira linhas de novo.
- **Base (iPhone):** máscara de luz no shader-base, ruído animado na borda, 24 partículas de gota.
- **[PC]:** a névoa volumétrica acende junto, a frente passa por partículas no ar (cinza, chuva, folhas), que mudam de linha para tinta ao atravessar, e há distorção de tela leve na borda.

### 13.2 A Mariposa que volta

A mariposa do caído voa em espiral para a lanterna erguida do aliado, deixando pó dourado na cor do jogador. Ao tocar a luz, a lanterna estoura de brilho por 6 quadros (congelamento de impacto), e o herói se refaz como **cera que escorre para cima**: gotas sobem do chão, formam as pernas, o corpo e a cabeça, com antecipação (a forma achata 0,6), estica 1,15 e assenta com 3 balanços. O chapéu, se estiver por perto, voa sozinho para a cabeça dele.
- **Base:** malha do herói com dissolve de baixo para cima e gotas por `CPUParticles3D` (até 32).
- **[PC]:** trilhas de pó por GPUParticles e uma luz pontual que acende a névoa em volta.

### 13.3 O Feixe da Torre-Lanterna

Dois jogadores operam o Feixe da caravana. Enquanto um gira a manivela, a lente da Torre-Lanterna esquenta (a cor sobe de couro para âmbar e depois sebo). Quando o outro solta, um feixe de luz de 3 m de largura e até 60 m de comprimento corta a paisagem. Tudo que ele toca é pintado; a névoa em camadas é **rasgada** ao longo do feixe; partículas no ar ficam visíveis como poeira dourada; e o horizonte, longe, recebe um risco de luz que mostra um marco ou um segredo. Inimigos no feixe ficam atordoados por 2 s.
- **Base:** malha cônica aditiva com textura rolando, uma luz de pavio móvel na ponta, faixa de pintura no shader-base, 1 cartão de névoa recortado.
- **[PC]:** feixe volumétrico de verdade (`FogVolume` + luz spot com sombra), as árvores e juncos projetam sombras longas no feixe, e o mar, ao fundo, reflete a luz.

---

## 14. Controles

### PC: teclado e mouse

| Ação | Tecla |
|---|---|
| Mover | WASD |
| Mirar | Mouse |
| Golpe | Botão esquerdo |
| Matéria | Botão direito |
| Esquiva | Espaço |
| Habilidade de classe | Q |
| Lance (passar item para o aliado sob o cursor ou mais perto da mira) | E |
| Interagir, pegar, operar máquina, levantar caído, acolher mariposa | F |
| Erguer a lanterna | Shift segurado |
| Ping e ordem ao mercenário | Botão do meio, ou roda de ordens com Z |
| Mapa (mesa da taverna) | Tab |
| Consumíveis | 1 a 4 |

### PC: controle

| Ação | Botão |
|---|---|
| Mover e mirar | Analógico esquerdo e direito (sem o direito, a mira segue o movimento com ajuda) |
| Golpe / Matéria | RT / LT |
| Esquiva | A |
| Habilidade | Y |
| Lance | X |
| Interagir | B |
| Erguer a lanterna | RB segurado |
| Ping | LB |
| Mapa | Select |

**Co-op local:** até 4 controles, ou teclado inteiro para um jogador e controles para os outros. Há um roteador próprio de dispositivos para que teclado e primeiro controle não colidam [pesquisa: `coop-rede.md`, item 3].

### Toque, só para a prévia no iPhone

Tela deitada, obrigatória (com aviso "gire o aparelho"), porque o Safari no iPhone não trava a orientação [pesquisa].
- **Esquerda:** direcional dinâmico (`VirtualJoystick` do Godot 4.7, modo dinâmico) [pesquisa].
- **Direita:** um **botão de golpe grande**; tocar dá mira automática que prefere o alvo manchado por outra pessoa; arrastar mira na mão [pesquisa: esquema do Brawl Stars].
- Em arco em volta do golpe: **Matéria** (tocar aplica no alvo da mira; arrastar escolhe o ponto), **Esquiva** (desliza na direção do direcional), **Habilidade**.
- **Botão de contexto** acima do arco, que muda de ícone: Pegar, Operar, Levantar, Acolher, **Lance** (aparece quando um aliado está a até 8 m).
- **Lanterna:** tocar no ícone da lanterna no canto direito de cima ergue e abaixa.
- Pausa no canto de cima à esquerda; o mapa abre com dois dedos para dentro.

---

## 15. Plataforma: PC primeiro, prévia no iPhone

O jogo é para PC. A versão Web serve só para o usuário testar no iPhone dele agora. O mesmo conteúdo roda nos dois, autorado para funcionar primeiro no Compatibility, e o PC soma por cima [pesquisa: `godot-render-vfx.md`, decisão 2]. Versão de base: **Godot 4.7.2-stable** [pesquisa].

| Item | PC (Forward+) | Prévia no iPhone (WebGL2, Compatibility) |
|---|---|---|
| Pintado e gravado | Shader-base com 8 luzes de pavio + luzes do motor com sombra | Mesmo shader-base, 8 luzes de pavio, sem luz do motor com sombra |
| Névoa | Volumétrica com `FogVolume`, 3 camadas pintadas | Profundidade e altura, 2 camadas pintadas |
| Feixes de luz | Volumétricos | Cones aditivos falsos |
| Partículas | GPUParticles com trilhas, centenas por efeito | `CPUParticles3D`, até 32 por efeito, poucas centenas no total [pesquisa] |
| Sombras | PCSS na Grande Lanterna, sombra do sol | Sombras de contato em disco |
| Resolução | Nativa, MSAA 4× | Escala 3D de 0,6 a 0,7 [pesquisa] |
| Draw calls | Sem teto prático | Até cerca de 120 por quadro [pesquisa] |
| Quadros por segundo | 60 a 144 | 30 estáveis |
| Mundo | Blocos de 64 m, anel de fundo de 3 km | Um trecho de 200 × 200 m, anel de fundo como cartões pintados |
| Áudio | Reverb e filtros em tempo real | Efeitos assados nos arquivos (modo Sample) [pesquisa] |

**Perda de contexto WebGL no iOS** [pesquisa: relato do fórum do Godot]: o jogo salva o estado da sessão a cada 30 s e no fim de cada fase do ciclo, em `user://` (IndexedDB), com tratamento de falha para modo anônimo. Ao perder o contexto, a página mostra "a luz apagou, toque para reacender" e recarrega no último salvamento. Para diminuir o risco: texturas em atlas de 2048, memória de vídeo abaixo de 150 MB, todos os materiais pré-aquecidos na tela de carregamento e nenhum `SubViewport` [pesquisa].

---

## 16. Fatia vertical

Dividida em dois marcos, como os finalistas anteriores [pesquisa: `proposta.md`].

### Marco 1, prova de estilo (3 a 4 semanas)

- O shader-base **pintado pela luz** com a frente de pincel, no Compatibility e no Forward+.
- Rodeira e Pavieiro modelados, rigados e animados (andar, correr, combo, matéria, Lance, recepção, cair, mariposa, voltar).
- Fuligento e Apagador animados.
- Um trecho de 120 × 120 m do Brejo, com a caravana parada, Graxo respirando, o Farol Cego e a Torre Torta no horizonte, chuva e névoa.
- A cena da prova de estilo (seção 18), entregue nas quatro peças da pesquisa: quadro bonito, quadro de estresse com 4 heróis e 20 inimigos, clipe de 3 a 5 s e quadro no nível PC [pesquisa: `proposta.md`].
- Build Web rodando no iPhone do usuário, com contador de draw calls e de quadros na tela.

### Marco 2, fatia jogável (8 a 10 semanas depois)

- **O Brejo inteiro em versão pequena:** 300 × 300 m, uma estrada com uma bifurcação, 4 braseiros, uma estalagem gravada, um esconderijo dos Mudos e uma lanterna afogada.
- **A caravana:** três vagões, rédeas e freio em dupla, halo, Feixe.
- **Um ciclo de luz completo** (24 min) com chuva e névoa de maré.
- **Uma masmorra:** a Capela Afundada (8 min), que só abre na maré baixa da noite.
- **Uma Noite Longa** de acampamento com 3 ondas.
- **As 4 classes** completas, troca de chapéu no cabideiro, Lance e recepção de todas.
- **Os 4 inimigos** e **a Mãe-Traça** de ponta a ponta.
- Co-op local de até 4 no PC, solo com mercenário, e uma sessão online de 2 jogadores.

**O que a fatia precisa provar:** que sair do halo dá medo e vale a pena; que as reações entre duas pessoas acontecem sem combinar antes; que passar a lanterna vira uma decisão; que dirigir a caravana em dupla é divertido por pelo menos 3 minutos seguidos; e que o mundo pintado-gravado não parece filtro.

---

## 17. Riscos

| Risco | Por que preocupa | O que fazer |
|---|---|---|
| **A gravura parecer filtro** | Filtro de tela sobre render 3D é sinal de slop [pesquisa: sinal 12] | A hachura fica no material de cada objeto, com direção seguindo a forma, nunca num passe de tela. Quadro lado a lado com 3 referências de gravura de verdade |
| **Cintilação e moiré das hachuras** em resolução baixa no iPhone | Linhas finas a 0,6 de escala tremem | Linhas com espessura mínima de 1,5 px de tela, densidade que cai com a distância, fervura a 8 quadros por segundo (o tremor vira estilo) |
| **Escuridão ilegível** | Jogo de luz e trevas costuma ser escuro demais no celular | Valor mínimo de 16%, contornos claros na Treva, portões de cinza e borrão em toda captura |
| **Custo das 8 luzes de pavio no shader** | Conta por pixel em celular | Luzes ordenadas por distância à câmera, só as 4 mais perto no iPhone; medir no aparelho no Marco 1 |
| **Mundo aberto grande demais** para assets gerados por código | Muito chão para pouca equipe | Regiões de 700 m com 60% feitas por regra (vegetação, rochas, ruínas modulares) e 40% à mão (marcos, masmorras) |
| **Dirigir a caravana ficar chato** | Tarefa de escolta repetitiva | Trechos curtos (no máximo 3 min), ladeiras e pontes que pedem dupla, ataques à caravana, e a opção de deixar ela andar sozinha |
| **Câmera compartilhada no mundo aberto** | No co-op local, um quer explorar e outro quer seguir | A luz e a Fuligem já seguram o grupo; parede invisível e teleporte para a luz do aliado |
| **Online e a caravana** | Um objeto grande e compartilhado | A Wain anda sobre trilho; o anfitrião manda só a posição na curva e o estado do freio |
| **Troca de classe por chapéu confundir** | Quem é quem depois de uma troca | Cor de jogador e símbolo do anel não mudam com o chapéu; só a silhueta muda |
| **Tom desequilibrado** | Escuro demais cansa; cômico demais vira infantil | Regra: o mundo é triste, o grupo é engraçado. Nenhuma piada em texto de cenário |
| **Perda de contexto WebGL no iOS** | Pode derrubar a prévia | Salvamento a cada 30 s, tela de "reacender", memória de vídeo abaixo de 150 MB |
| **Proximidade com os outros dois conceitos** | Três jogos de fantasia sombria podem parecer o mesmo | A identidade deste é a luz que anda e o mundo que muda de técnica de pintura; se outro conceito também usar gravura, este fica com a mistura guache-gravura e o outro deve escolher outra técnica |

---

## 18. Cena da prova de estilo

**Onde:** o Brejo das Lamparinas Afogadas, no fim do Crepúsculo, sob chuva fina. Câmera de combate do jogo: 16 m de distância, inclinação de 52°, campo de visão de 30°, quadro de 1280 × 720.

**O quadro, de trás para a frente:**

- **Horizonte (os 12% de cima):** céu em três camadas de nuvem, do laranja-queimado perto do horizonte para o violeta-fuligem no alto. À esquerda, sobre o rochedo, o **Farol Cego** com o feixe pálido no meio da varredura, cortando a névoa do mar. À direita, a **Torre Torta** inclinada, recortada contra o céu. No meio, muito longe, a silhueta azulada do **Gigante Ajoelhado** apagada pela perspectiva atmosférica. Entre eles, a **Muralha de Treva** subindo em hachuras horizontais.
- **Fundo (60 m em diante):** o Brejo em gravura, juncos e árvores mortas em linhas claras sobre azul-noite, lanternas afundadas piscando fraco sob a água. Desfoque leve.
- **Meio (25 m atrás dos heróis):** a **Wain** parada na passarela de tábuas, com os três vagões e Graxo de cabeça baixa, respirando vapor. O halo dela é uma bolha de guache âmbar recortada na noite; as lanternas da Torre-Lanterna balançam; os estandartes de lona batem com o vento. A chuva aparece como riscos dourados dentro do halo e some na gravura.
- **Plano de jogo:** um trecho largo de lodo raso entre duas passarelas. Seis **Fuligentos** saem da Treva pela direita, ainda em gravura, olhos brancos. Um **Apagador** vem atrás deles, alto, com o cone de latão erguido sobre a lanterna do Pavieiro: o anel verde-ácido já se fechou pela metade.

**A interação co-op (Óleo + Chama, com fogo amigo construtivo e Lance):**

1. A **Rodeira** (manto Carmim) já correu para o meio do bando e jogou o balde de graxa: o lodo e quatro Fuligentos estão untados, com manchas de óleo com contorno Carmim. Ela mesma está molhada da chuva, o que a protege do fogo (molhado reduz a chama pela metade).
2. O **Pavieiro** (manto Ouro velho), sabendo que vai perder a luz para o Apagador, faz um **Lance** da própria lanterna para a Rodeira no meio da Fagulha. A lanterna voa em arco.
3. **O instante do quadro:** a Rodeira pega a lanterna no ar com a recepção **"Eixo"**, crava a lanterna no lodo como pivô, e a Fagulha do Pavieiro toca o óleo ao mesmo tempo. A **Labareda** acontece: o anel de tinta da **Frente de Pincel** se espalha pelo lodo e pinta os Fuligentos de gravura para guache no meio do pulo deles, achatados de susto. O Apagador, apanhado pela luz, fica pintado pela metade, com o cone ainda erguido e o anel de perigo interrompido. A chuva vira vapor sobre as chamas.

**As poses (o que cada princípio mostra neste quadro):**

- **Rodeira:** agachada atrás da roda, com a linha de ação curva do pé até o elmo; o elmo caído sobre um olho (continuidade); a lanterna cravada ao lado; o corpo achatado 0,8 na pose de recepção.
- **Pavieiro:** na pose de continuidade da Fagulha, braço estendido em arco largo, manga voando, o chapéu-vela esticado e a chama do topo inclinada para a frente (ação secundária). Ele está sem lanterna, e as pernas dele já começam a ser hachuradas (a Fuligem subindo), uma deixa visual de que ele precisa voltar para a luz.
- **Fuligentos:** no ar, olhos em fenda, metade pintados e metade em linhas, na borda da Frente de Pincel.
- **Apagador:** na pose segurada da telegrafia, mas com o corpo começando a recuar da luz.

**Atmosfera completa no quadro:** névoa de maré na altura da canela fora do halo; três camadas de névoa pintada (a mais perto, âmbar por causa da Labareda); brasas de resina e gotas de vapor subindo; chuva fina inclinada pelo vento da esquerda; o reflexo da Labareda e das lanternas da caravana em listras douradas no lodo; mariposas pequenas atraídas pela luz, em volta do halo.

**O que esta cena precisa provar:** que dá para contar os 2 heróis e os 7 inimigos numa miniatura de 320 × 180; que a diferença entre pintado e gravado se lê em cinza; que o verde-ácido do perigo continua distinto em deuteranopia e protanopia; que a Labareda tem antecipação, impacto e dissipação claros no clipe; e que, no nível PC, a névoa volumétrica, o feixe do farol e as sombras longas das lanternas acrescentam profundidade sem mudar o estilo.

# Os 12 princípios da Disney aplicados a animação e VFX de jogo, com números

Pesquisa feita em 27/11/2026 para o RPG de ação cooperativo novo (Godot + Blender, tudo gerado por script). Etapa só de pesquisa: nada do jogo foi construído.

**Legenda de confiança**

- **[fonte]**: veio de livro, palestra, artigo ou documentação, com link. Atenção: neste ambiente a leitura de páginas (WebFetch) só alcança o GitHub. Gamedeveloper.com, nexus.leagueoflegends.com, amara.org e similares deram "host não resolvido", então quase todo o material fora do GitHub foi lido **pelo resumo da ferramenta de busca, não pelo texto integral**.
- **[doc]**: lido direto da referência de classes do Godot (`godotengine/godot`, tag `4.5-stable` ou `4.6-stable`, pasta `doc/classes/`) ou do código-fonte do motor.
- **[teste]**: medido aqui, no container (Blender 5.3 como módulo Python, Godot 4.5.1 sob Xvfb, renderer Compatibility). Arquivos em `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-animacao/` (pasta temporária, pode sumir).
- **[proposta]**: número ou regra que eu derivei das fontes para este projeto. Não é regra publicada; serve de ponto de partida e deve ser ajustado jogando.
- **[não verificado]**: não consegui confirmar.

Convenção: **todas as contagens de quadros são a 60 fps** (1 quadro = 16,7 ms), salvo quando dito. "Startup" = quadros desde o aperto do botão até o primeiro quadro ativo, sem contá-lo.

---

## 1. Resumo para quem tem pressa

1. **Em jogo, o princípio que manda é a responsividade.** Cooper chama a antecipação de "tópico controverso": o designer quer o mínimo de quadros, o animador quer o máximo ([Game Developer, excerto do Game Anim](https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games)) [fonte]. Regra do projeto: **o jogador antecipa pouco e se recupera muito; o inimigo antecipa muito e se recupera o bastante para ser punido.** O peso do golpe do jogador vem de pose, contato, hit-stop e follow-through, não de antecipação longa.
2. **Números-âncora [proposta, derivados das fontes]:** startup do golpe leve do herói 3 a 6 quadros; telegrafia de inimigo comum 24 a 36 quadros (400 a 600 ms, acima dos ~250 ms de reação de um "bom jogador" segundo a tabela citada pela [Blur Busters](https://www.blurbusters.com/human-reflex-part1-input-lag-and-the-limits-of-human-reaction-time)); hit-stop de 3 a 5 quadros no leve, 8 a 12 no pesado, até 30 no golpe final (o Smash 4 limita em 30, [Kuroganehammer](https://kuroganehammer.com/Smash4/Formulas)); overshoot de 5 a 15%; squash de 0,7 a 0,85 com preservação de volume.
3. **Uma descoberta prática que muda o pipeline [teste + doc]:** o importador de glTF do Godot **reamostra toda animação de osso a 30 fps por padrão** (`animation/fps = 30`, interpolação linear). Uma pose de 1 quadro a 60 fps (smear, impacto, overshoot) pode simplesmente desaparecer. Configurar `animation/fps = 60` em todo import.
4. **Animação em 2s (estilo Spider-Verse / Guilty Gear Xrd) tem caminho limpo [teste]:** chaves `CONSTANT` no Blender viram `STEP` no glTF, que o Godot importa como `INTERPOLATION_NEAREST`. O modificador `STEPPED` do Blender **não** sobrevive ao export sem amostragem e, com amostragem, vira interpolação linear, que o import a 30 fps alisa de novo.
5. **Blender 5.3 removeu `Action.fcurves` [teste]:** o acesso às curvas agora é por `bpy_extras.anim_utils.action_get_channelbag_for_slot(action, slot)`. Todo script antigo de keyframe quebra.
6. **O Godot 4.5 já tem o kit de "animação secundária procedural"** [doc]: `SpringBoneSimulator3D` (cabelo, capa, cauda, com rigidez, arrasto e gravidade por junta), `LookAtModifier3D` (cabeça e olhos com limites, amortecimento e interpolação por tempo), `AimModifier3D`, `CopyTransformModifier3D`, `BoneConstraint3D`. IK de dois ossos (`TwoBoneIK3D`) e `LimitAngularVelocityModifier3D` só existem no 4.6 em diante.
7. **Smear por shader de vértice funciona no renderer Compatibility (Web)** [teste]: shader de 25 linhas faz squash com volume preservado e arrasta só o lado de trás da malha ao longo da velocidade (imagem em §8.3).
8. **VFX segue a mesma gramática da animação:** antecipação, clímax, dissipação. O guia da Riot manda evitar preto e branco puros e reservar saturação, opacidade e faixa de valor máximas para os efeitos que mudam a luta; partículas ociosas ficam com opacidade baixa e formas borradas ([resumo do guia via busca](https://www.vfxapprentice.com/blog/10-league-of-legends-vfx-design-tips), [Riot Nexus](https://nexus.leagueoflegends.com/en-us/2017/10/dev-leagues-vfx-style-guide/)) [fonte].
9. **Hit-stop em co-op deve ser local** (atacante e alvo), com tremor horizontal no alvo que decai, nunca `Engine.time_scale = 0` para todos a cada golpe. Sakurai lista 8 técnicas de hit-stop, entre elas tremer mais quem apanha, manter a hitbox parada e reduzir o tremor gradualmente ([NintendoWire](https://nintendowire.com/news/2022/12/12/this-week-in-sakurai-12-5-12-11-fine-tuning-hit-stop-and-cheating-the-system/)) [fonte].
10. **Para agentes de IA, o maior risco de "cara de animação gerada" é a uniformidade:** tudo com a mesma suavização (ease in/out em todas as chaves), todos os ossos começando juntos, nenhuma pausa e nenhum contraste de espaçamento. A rubrica da §15 mede justamente isso a partir de quadros e curvas.

---

## 2. Tabelas de conversão usadas no resto do relatório

### 2.1 Tempo e quadros a 60 fps [cálculo]

| ms | 33 | 50 | 67 | 83 | 100 | 133 | 167 | 200 | 250 | 300 | 400 | 500 | 1000 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| quadros a 60 | 2 | 3 | 4 | 5 | 6 | 8 | 10 | 12 | 15 | 18 | 24 | 30 | 60 |
| quadros a 24 (filme) | 0,8 | 1,2 | 1,6 | 2 | 2,4 | 3,2 | 4 | 4,8 | 6 | 7,2 | 9,6 | 12 | 24 |

"Em 2s" a 24 fps (cinema) = 12 poses/s = **uma pose a cada 5 quadros do jogo a 60 fps**. "Em 2s" a 30 fps = 15 poses/s = pose a cada 4 quadros a 60. Para não dar trepidação irregular, usar **holds de 2, 3 ou 4 quadros de jogo** (30, 20 ou 15 poses/s), nunca 2,5.

### 2.2 Overshoot e antecipação das curvas de easing [cálculo]

Curva `BACK` de Penner (é a mesma família da interpolação `BACK` do Blender e de `Tween.TRANS_BACK` do Godot):

| Parâmetro `s` (Blender: `back`) | Overshoot (ease out) | Recuo antes de sair (ease in) | Pico em |
|---|---|---|---|
| 1,0 | 3,7% | -3,7% | 67% do tempo |
| **1,70158 (padrão de Penner)** | **10,0%** | **-10,0%** | 58% |
| 2,5 | 18,9% | — | 52% |
| 3,0 | 25,0% | -25,0% | 50% |

Sistema de 2ª ordem (mola amortecida), overshoot na resposta a degrau em função do amortecimento ζ:

| ζ | 0,3 | 0,5 | 0,7 | 1,0 |
|---|---|---|---|---|
| overshoot | 37% | 16% | 4,6% | 0% |

Uso: ζ 0,3 a 0,5 para cabelo, rabo, orelhas, fitas; ζ 0,6 a 0,8 para corpo, arma, câmera; ζ = 1 para UI e câmera de mira [proposta].

### 2.3 Squash and stretch com volume constante [cálculo]

Escala `s` no eixo do movimento e `1/√s` nos outros dois eixos mantém volume 1,000:

| s (eixo do movimento) | 0,6 | 0,7 | 0,8 | 1,0 | 1,15 | 1,25 | 1,5 |
|---|---|---|---|---|---|---|---|
| escala nos outros eixos | 1,291 | 1,195 | 1,118 | 1,000 | 0,933 | 0,894 | 0,816 |

Em 2D (área constante) o fator lateral é `1/s`, não `1/√s`.

---

## 3. Os 5 fundamentos de Jonathan Cooper (Game Anim, cap. 4)

O livro *Game Anim: Video Game Animation Explained* (CRC Press, 2ª ed. 2021) reinterpreta os 12 princípios no cap. 3 e propõe 5 fundamentos próprios de animação de jogo no cap. 4 ([Routledge](https://www.routledge.com/Game-Anim-Video-Game-Animation-Explained/Cooper/p/book/9780367707651)). Os nomes são **Feel, Fluidity, Readability, Context, Elegance**; as definições abaixo vêm de resumo secundário ([blog de tese UAL](https://yufeizheng.myblog.arts.ac.uk/2021/10/24/thesis-research-week-3-the-five-fundamentals-of-game-animation/)) e da minha leitura do conjunto [fonte secundária; texto do livro não lido].

| Fundamento | O que significa | Como medir neste projeto [proposta] |
|---|---|---|
| **Feel (sensação)** | A interatividade separa a animação de jogo da linear: a animação serve ao controle. Resposta imediata ao comando, peso que não atrapalha | Quadros entre o input e a primeira mudança visível de pose: **≤ 2** (andar, virar, esquiva), **≤ 4** (ataque leve). Medir gravando input e quadros |
| **Fluidity (fluidez)** | Transições sem estalos entre estados; animações que se encadeiam (blends, cancelamentos, poses de saída compatíveis) | Nenhum osso com salto angular > 25° em 1 quadro numa transição; crossfade 4 a 10 quadros; nenhum "pop" de pé |
| **Readability (legibilidade)** | A intenção é entendida instantaneamente, inclusive de longe e no meio do caos (no nosso caso: câmera alta, 4 jogadores, dezenas de efeitos) | Teste de silhueta preta sobre branco a 64 px de altura: dá para dizer qual ação é? Telegrafia identificável sem som |
| **Context (contexto)** | A animação conversa com o mundo e com o estado: terreno, arma, ferimento, inclinação, quem está perto | IK de pé em rampa, cabeça olhando para alvo (`LookAtModifier3D`), variações de idle por estado (ferido, com pouca vida) |
| **Elegance (elegância)** | Sistemas simples e reaproveitáveis, poucos assets fazendo muito; economia de produção | Quantas animações uma camada procedural substitui (inclinação, respiração, olhar, molas). Meta: o herói inteiro em ≤ 40 clipes (§16) |

Para um projeto 100% gerado por script, "Elegance" é a palavra decisiva: cada animação feita à mão em código custa caro, então tudo que pode ser **procedural por cima de poucas poses fortes** (molas, inclinação, olhar, squash, hit-stop) deve ser.

---

## 4. Os 12 princípios, um por um

Formato de cada item: **definição → em jogo (respeitando responsividade) → números → Blender (bpy) → Godot (tempo de execução) → sprite 2D.** Fonte geral dos princípios: Thomas & Johnston, *The Illusion of Life* (1981); leitura para jogos: Cooper (acima) e a série de Christopher Totten ([12 principles for game animation](https://www.gamedeveloper.com/game-platforms/12-principles-for-game-animation)) [fonte via busca].

### 4.1 Squash and stretch (achatar e esticar)

- **Definição:** a forma deforma com a força (achata no impacto, estica na velocidade) mantendo o volume.
- **Em jogo:** dá peso e elasticidade sem custar quadros de resposta, porque é aplicado *por cima* da ação. Usar em: aterrissagem, início de pulo/esquiva, recebimento de golpe, inimigos gelatinosos, projéteis, UI. Em personagem humano estilizado, aplicar em ossos de controle (tronco, cabeça, membros), nunca escala não uniforme na raiz se houver `SpringBoneSimulator3D` (a doc avisa que esqueleto escalado comporta mal [doc]).
- **Números [proposta]:**

| Evento | Fator no eixo | Duração | Retorno |
|---|---|---|---|
| Aterrissagem leve | 0,85 | 2 a 3 quadros | mola ζ 0,5, 8 a 12 quadros |
| Aterrissagem pesada / golpe recebido forte | 0,70 a 0,75 | 3 a 4 quadros | mola ζ 0,4 |
| Saída de pulo / dash | 1,15 a 1,25 | 2 a 4 quadros | |
| Projétil rápido | 1,3 a 1,6 ao longo da velocidade | contínuo, proporcional à velocidade | |
| Personagem cartunesco extremo (estilo Overwatch/Tracer) | até 0,6 / 1,5 | 1 a 2 quadros | |

- **Blender (bpy):** osso de controle com `inherit_scale` adequado; chave de escala com volume preservado (`sx = sz = 1/sqrt(sy)`), ou o modo "Volume Preservation" do Rigify / restrição `Maintain Volume` (`constraint type 'MAINTAIN_VOLUME'`). Interpolação da chave de impacto `CONSTANT` ou `LINEAR` (o achatamento aparece de uma vez), retorno `ELASTIC`/`BACK` com `easing='EASE_OUT'`.
- **Godot:** squash procedural na malha ou num `Node3D` pai do visual, nunca no `CharacterBody3D` (colisão). Mola de 2ª ordem por código (ver §11.3) ou `Tween` com `TRANS_BACK`/`TRANS_ELASTIC`. Shader de vértice com volume preservado ao longo da velocidade (testado, §8.3). Referências reaproveitáveis: [TheAllenChou/godot-squash-and-stretch](https://github.com/TheAllenChou/godot-squash-and-stretch) (MIT, mas **exige C#**, o que impede export Web no Godot 4 [não verificado para 4.5]) e [Kelpekk/Juicee](https://github.com/Kelpekk/Juicee) (MIT, GDScript, Godot 4.3+, 117 efeitos, inclui squash).
- **2D:** `scale` do `Sprite2D` com área constante (`sx = 1/sy`) ou quadros desenhados achatados. Pivô no pé para aterrissagem, no centro para golpe recebido.

### 4.2 Anticipation (antecipação)

- **Definição:** movimento preparatório oposto à ação principal, que avisa e dá força.
- **Em jogo:** é o princípio em conflito direto com a responsividade (Cooper). Solução padrão: **antecipação curta ou embutida no jogador, longa no inimigo** ([bugnet.io](https://bugnet.io/blog/animation-basics-that-make-your-game-feel-alive), [80.lv sobre Skullgirls](https://80.lv/articles/tips-on-making-fluid-and-powerful-animations): "um único quadro de preparação já melhora a leitura") [fonte secundária]. Truques para o jogador: (1) começar o clipe já no meio da antecipação (a pose 1 já é a pose de carga); (2) usar o fim do golpe anterior como antecipação do próximo no combo; (3) antecipação "de 1 quadro" em smear; (4) golpes carregados, em que a antecipação é o próprio botão segurado. Sakurai descreve o ataque de Smash em 4 fases, *standby, windup, strike, follow-through*, e diz que golpes rápidos usam pouco ou nenhum *lead-in*, reservando o windup suave para golpes grandes ou personagens pesados ([GoNintendo](https://www.gonintendo.com/contents/13757-sakurai-details-the-process-of-making-snappy-attack-animations), [Game Developer, Brawl na GDC](https://www.gamedeveloper.com/game-platforms/best-of-gdc-developing-i-super-smash-bros-brawl-i-)) [fonte].
- **Números [proposta]:** ver tabela completa na §5.1. Herói leve 3 a 6 quadros; herói pesado 12 a 20; feitiço instantâneo 4 a 8; inimigo comum 24 a 36; elite 30 a 45; chefe, golpe grande 45 a 90. Amplitude: recuo de 10 a 25% do arco total do golpe (curva `BACK` de 1,7 a 3,0, §2.2).
- **Blender:** chave de antecipação a 10 a 25% do arco, *oposta* ao golpe, e o golpe com espaçamento rápido (poucos quadros). Para o inimigo, um "hold" vibrante na antecipação (§4.12 e §5.4).
- **Godot:** a telegrafia do inimigo é animação + VFX + som: decal ou anel no chão crescendo durante a antecipação, brilho no osso que vai atacar (parâmetro de shader animado por trilha), `LookAtModifier3D` travando no alvo. Em co-op, a telegrafia precisa indicar **quem** é o alvo (linha ou marca colorida no jogador-alvo).
- **2D:** 2 a 4 desenhos de antecipação com o maior hold no último (o "cocking frame"); no inimigo, flash de 2 quadros de cor clara no fim da antecipação.

### 4.3 Staging (encenação)

- **Definição:** apresentar a ideia de modo inconfundível: pose, ângulo, composição, foco.
- **Em jogo:** a câmera é do jogador (ou compartilhada no co-op), então o staging vira **legibilidade sob qualquer ângulo de câmera prevista**. Com câmera alta 3/4 (padrão de Magicka/co-op de sofá), golpes devem ler no plano do chão: arcos horizontais largos, braços afastados do tronco, armas que saem da silhueta. Staging de VFX: um só elemento dominante por vez (o clímax), o resto subordinado.
- **Números [proposta]:** a 3/4 com o herói ocupando 60 a 90 px de altura numa tela 720p, o membro ativo do golpe deve sair da silhueta do corpo em **≥ 30% da altura do personagem**; contraste de valor personagem/fundo ≥ 30 pontos de L* (CIELAB); cada jogador com cor de identificação saturada em ≥ 15% da área do sprite.
- **Blender:** script de verificação que renderiza a silhueta (material emissivo preto, fundo branco) na câmera do jogo nas poses-chave e calcula a área fora do "casco" do tronco.
- **Godot:** câmera co-op que enquadra todos os jogadores com margem; contorno ou aro de cor do jogador; "spotlight" de valor (o fundo escurece 10 a 20% em golpes de clímax).
- **2D:** pose-chave lida em silhueta; nunca deixar a arma cruzar o tronco na pose de contato.

### 4.4 Straight ahead e pose to pose

- **Definição:** desenhar em sequência livre (straight ahead) ou definir poses-chave e preencher depois (pose to pose).
- **Em jogo:** pose to pose é o padrão para ações de gameplay, porque as poses-chave coincidem com eventos de design (startup, ativo, recuperação). Straight ahead vira **simulação** (molas, partículas, tecido), feita por código.
- **Números:** fluxo de Dead Cells: o animador primeiro deixa a animação legível com o **mínimo de quadros-chave** e só depois acrescenta quadros de interpolação antes ou depois das chaves ([resumo da busca do artigo de Thomas Vasseur](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-), [Game Anim](https://www.gameanim.com/2018/01/31/dead-cells-3d-pipeline-2d-animation/)) [fonte].
- **Blender (como o agente deve trabalhar) [proposta]:** 3 passadas, cada uma renderizada em folha de contato e criticada antes da próxima:
  1. **Blocking em CONSTANT:** só poses-chave (contato, extremos, passagem), interpolação `CONSTANT`.
  2. **Breakdowns:** uma pose intermediária por par de chaves que define o arco e o *favoring* (perto de qual chave o meio fica), ainda `CONSTANT`.
  3. **Spline:** troca para `BEZIER` com alças ajustadas *por chave* (nunca "auto-clamped em tudo"), aplica defasagem entre ossos (§4.5), e só então decide se o estilo final é em 1s ou em 2s (§7).
- **Godot:** o equivalente de straight ahead é `SpringBoneSimulator3D`, `GPUParticles3D` e física de ragdoll parcial.
- **2D:** idem: desenhar ou renderizar as chaves, testar em loop, então intercalar.

### 4.5 Follow through and overlapping action (continuidade e ação sobreposta)

- **Definição:** partes do corpo não param ao mesmo tempo; o que é solto (cabelo, capa, rabo, carne) continua depois que o corpo para, e partes começam defasadas.
- **Em jogo:** é o princípio mais barato de terceirizar para o motor. A recuperação do golpe é onde ele vive, e a recuperação do jogador pode ser cancelada (§5.3), então **o follow-through deve estar nas molas e não no clipe**, para sobreviver ao cancelamento.
- **Números [proposta]:** defasagem de 1 a 2 quadros por osso da cadeia (ombro → cotovelo → punho → arma) no golpe; 2 a 4 quadros por osso em cabelo/capa animados à mão; overshoot de 5 a 15% no último elo; assentamento em 8 a 20 quadros.
- **Blender [teste]:** deslocar as chaves de cada osso filho em `k` quadros (no teste usei 1 quadro por nível da cadeia: `keyframe_insert(..., frame=f + k)`), mais uma chave de overshoot e uma de assentamento. Interpolação `ELASTIC` (`amplitude`, `period`) ou `BACK` (`back`) com `easing='EASE_OUT'` só na chave de assentamento do último elo; os padrões RNA desses parâmetros são 0, então **definir explicitamente** (`back = 1.70158`).
- **Godot [doc]:** `SpringBoneSimulator3D` (Godot ≥ 4.4): cadeia por `root_bone`/`end_bone` (sem bifurcação em Y), `stiffness`, `drag`, `gravity` e `radius` por cadeia com `Curve` de amortecimento ao longo da cadeia, ou por junta com `individual_config`; `external_force` para vento; colisões próprias (`SpringBoneCollision3D`) independentes do motor de física; tenta voltar à pose original, diferentemente do `PhysicalBoneSimulator3D` ([referência 4.5](https://github.com/godotengine/godot/blob/4.5-stable/doc/classes/SpringBoneSimulator3D.xml)). Para cadeias que não são ossos (fitas de VFX, chapéu solto), mola de 2ª ordem em código (§11.3). Addon alternativo: [godot-jigglebones](https://github.com/yaelatletl/godot-jigglebones) (MIT, Godot 4.0).
- **2D:** partes separadas (cabelo, capa) como sprites filhos com mola em código, ou desenhadas com 1 a 2 quadros de atraso. Em pixel art, o follow-through do cabelo pode ser só 2 desenhos alternados.

### 4.6 Slow in and slow out (aceleração e desaceleração)

- **Definição:** mais desenhos perto das poses extremas, menos no meio: o movimento acelera saindo de uma pose e freia chegando.
- **Em jogo:** *o erro amador é aplicar isso igualmente em tudo*. Em golpes, o padrão bom é **assimétrico**: slow in na antecipação (carrega), **quase nenhum slow out na chegada ao contato** (o golpe chega rápido e para de repente, a parada é o impacto), slow out longo na recuperação.
- **Números [proposta]:** espaçamento do golpe: 60 a 80% do deslocamento total do membro acontece nos 2 a 3 quadros antes do contato; na recuperação, decaimento tipo exponencial com meia-vida de 4 a 8 quadros.
- **Blender:** alça da chave de contato com `handle_left_type='VECTOR'` (chegada dura) e `handle_right_type='AUTO_CLAMPED'`; ou interpolação `EXPO`/`QUART` com `easing='EASE_IN'` antes do contato e `EASE_OUT` depois. Enum disponível no 5.3 [teste]: `CONSTANT, LINEAR, BEZIER, SINE, QUAD, CUBIC, QUART, QUINT, EXPO, CIRC, BACK, BOUNCE, ELASTIC`, `easing` em `AUTO, EASE_IN, EASE_OUT, EASE_IN_OUT`.
- **Godot:** `xfade_curve` nas transições do `AnimationNodeStateMachineTransition` e `fadein_curve`/`fadeout_curve` no `AnimationNodeOneShot` (curvas unitárias; vazias = linear) [doc]. Em `Tween`, escolher `TRANS_EXPO`/`TRANS_QUART` + `EASE_OUT` para chegadas de UI e câmera.
- **2D:** distribuir os desenhos intermediários perto dos extremos; num golpe de 6 quadros, a regra útil é 2 de antecipação, 1 smear, 1 contato com hold, 2 de recuperação.

### 4.7 Arcs (arcos)

- **Definição:** membros e objetos se movem em trajetórias curvas, não em linhas retas.
- **Em jogo:** interpolação de rotação de ossos já gera arcos, mas blends lineares de posição (root motion, IK, translação de mão) geram retas. VFX de golpe (trilha de arma, arco de malha) deve seguir o mesmo arco do pulso.
- **Números [proposta]:** desvio do arco do pulso em relação à corda ≥ 10% do comprimento da corda em golpes horizontais; trilha de arma cobrindo 90° a 180° de arco em golpes leves, até 270° em giros.
- **Blender:** script de verificação que amostra a posição global da ponta da arma por quadro e mede a curvatura (traçar a trajetória como curva e renderizar junto: a "trajectory trace" que o animador humano olharia). Corrigir arco com chaves de rotação no ombro em vez de translação do controle de IK.
- **Godot:** `IKModifier3D`/`TwoBoneIK3D` só no 4.6+ [doc]; no 4.5, mão em IK só via script ou `SkeletonIK3D` (legado). Rastro do golpe por malha de fita (trilhas de partícula não existem no Compatibility, ver relatório `godot-render-vfx.md`).
- **2D:** desenhar a curva-guia antes; o smear segue o arco, não a reta.

### 4.8 Secondary action (ação secundária)

- **Definição:** ações menores que reforçam a principal (expressão, mão livre, respiração, olhar), sem competir com ela.
- **Em jogo:** quase tudo pode ser camada aditiva ou modificador: respiração, olhar para o alvo, mão livre que se abre no golpe, expressão de dor, cabeça que se vira para o colega que chamou. Em co-op, ação secundária de **comunicação** vale ouro: aceno, apontar, comemorar.
- **Números [proposta]:** respiração: escala do peito 1 a 2%, ciclo 2,5 a 4 s (150 a 240 quadros), deslocamento dos ombros 0,5 a 1 cm. Olhar: cabeça começa a girar 3 a 6 quadros depois dos olhos e alcança em 10 a 20 quadros; limite de 60 a 75° na cabeça.
- **Blender:** clipes aditivos curtos e separados (respiração, flinch de impacto, "mão abre"), em ação própria, exportados como animações independentes.
- **Godot [doc]:** `AnimationNodeAdd2/Add3` para aditivos (com `amount` > 1 amplifica, < 0 inverte) e `filters` para limitar a camada a ossos; `LookAtModifier3D` com `duration` + `transition_type`/`ease_type` (interpolação por tempo ao trocar de alvo), `use_angle_limitation`, limites primário/secundário e `*_damp_threshold` (amortecimento não linear perto do limite) [doc 4.5]. A doc pede para os `LookAtModifier3D` dos ossos pais ficarem acima dos filhos na lista. [não verificado] se o Add2 do Godot 4.5 soma o delta em relação à pose `RESET` ou ao primeiro quadro: testar antes de produzir aditivos em massa.
- **2D:** camada separada (rosto, mão livre) por `AnimationPlayer` diferente; respiração por `scale` de 1 a 2 px.

### 4.9 Timing (tempo)

- **Definição:** o número de quadros de uma ação define peso, humor e física.
- **Em jogo:** timing é desenho de jogo: startup, ativo, recuperação, janelas de cancelamento e de esquiva são tempo. O animador e o designer escolhem juntos, e o código lê os eventos da trilha (não de constantes duplicadas).
- **Números:** tabelas completas na §5. Âncoras: pancada leve 18 a 30 quadros no total; pesada 40 a 60; esquiva 20 a 30; feitiço de canal em loop 30 a 60 quadros por ciclo.
- **Blender:** tempo em quadros a 60 fps desde o início (`scene.render.fps = 60`), mesmo que o estilo final seja em 2s, porque o hit-stop e os eventos precisam de resolução de 1 quadro. Marcadores (`scene.timeline_markers` ou `action.pose_markers`) nos eventos `hit_on`, `hit_off`, `cancel_open`, `step_L`, `step_R`, `vfx_*`, `sfx_*`.
- **Godot [doc + teste]:** importar com `animation/fps = 60` (o padrão é 30 e reamostra tudo com interpolação linear; ver §7.3). Eventos por trilha de método (`Call Method Track`) ou lendo marcadores convertidos em trilhas no script de import. `AnimationNodeTimeScale` para variar velocidade (0 pausa) [doc].
- **2D:** `SpriteFrames` aceita duração relativa por quadro (`add_frame(anim, textura, duração)`), que é o jeito de fazer holds sem duplicar imagens.

### 4.10 Exaggeration (exagero)

- **Definição:** empurrar pose, timing e forma além do real para ficar mais claro e mais vivo.
- **Em jogo:** com câmera alta e personagens pequenos na tela, exagero é obrigação, não estilo. Sakurai defende que movimentos mais exagerados ficam melhores que os moderados ([GoNintendo](https://www.gonintendo.com/contents/11218-masahiro-sakurai-s-latest-video-details-over-exaggeration-in-animation)) [fonte]. Overwatch empurra squash e smear "um pouco além do normal" e usa smears para compensar a falta de motion blur ([Kotaku](https://kotaku.com/this-is-not-an-overwatch-glitch-1777612546)) [fonte].
- **Números [proposta]:** poses-chave com ângulos 20 a 40% além da referência realista; pulo com 1,5 a 2× a altura "física" no ápice com hold; arma 10 a 25% maior que o real; reação a golpe pesado com deslocamento de tronco ≥ 30° em 2 a 3 quadros.
- **Blender:** script de "exaggeration pass": multiplica a rotação de cada chave em relação à pose de descanso por 1,2 a 1,4 nos ossos de tronco e braço, antes do spline; recalcular IK de pé depois.
- **Godot:** multiplicar parâmetros procedurais (inclinação, squash, recuo) em vez de clipes; amplitude de camada aditiva > 1 no `AnimationNodeAdd2` para "golpe crítico".
- **2D:** exagero nos smears e no comprimento do membro no quadro de contato (braço 10 a 20% mais longo por 1 quadro é aceitável e invisível em movimento).

### 4.11 Solid drawing (desenho sólido / forma)

- **Definição:** volume, peso e equilíbrio tridimensionais coerentes; sem "achatamento" nem gêmeos simétricos.
- **Em jogo 3D:** vira **qualidade de deformação e de pose**: pesos de skin sem colapso de cotovelo e ombro, centro de massa sobre a base de apoio, assimetria. Em 2D pré-renderizado, vira consistência de volume entre quadros e de escala (pixels por metro fixo).
- **Números [proposta]:** centro de massa projetado no chão dentro do polígono de apoio em poses paradas; em poses dinâmicas, fora no máximo 1 comprimento de pé na direção do movimento; perda de volume no cotovelo a 120° < 15% (medido pela seção transversal no Blender); diferença de ângulo entre lados esquerdo e direito ≥ 10° em qualquer pose parada.
- **Blender:** Rigify (`rigify` embutido) gera rig com "Volume Preservation" nos membros; se a malha for gerada por script, usar `armature` com pesos automáticos e checar colapso renderizando o cotovelo a 0°, 90°, 140°. Script de "anti-twinning": somar ruído de 3 a 8° aos ossos espelhados nas poses de idle e corrida.
- **Godot:** nada a fazer em tempo de execução além de não escalar ossos sem preservar volume.
- **2D:** mesma altura em pixels por metro para todos (Dead Cells é citado como 3D renderizado em sprites para manter consistência, [Nintendo Life](https://www.nintendolife.com/news/2018/05/feature_reanimating_the_roguelike_with_dead_cells_developer_motiontwin)) [fonte].

### 4.12 Appeal (apelo)

- **Definição:** o personagem é interessante de olhar: design claro, formas simples com contraste de tamanho, personalidade no movimento.
- **Em jogo:** personalidade vem de **assinaturas** de movimento: um idle próprio, um jeito de correr, uma comemoração, a esquiva com floreio. Para o projeto 100% por script, apelo vem de formas grandes e legíveis (grande/médio/pequeno), silhuetas distintas por classe e cada personagem com uma regra de movimento própria (ex.: um herói sempre se move em 2s duros, outro em 1s fluido, como Miles e Peter em Spider-Verse, [ver §7.1](#71-referências-de-estilo)).
- **Números [proposta]:** proporção de formas 1:3:9 (pequena/média/grande) no design; cada herói com ≥ 3 animações "de personalidade" (idle longo, vitória, emote) além das funcionais.
- **Blender / Godot / 2D:** ver §16 (lista mínima) e a rubrica §15 (critério "personalidade").

### 4.13 Tabela-resumo dos 12 princípios: onde cada um mora

| Princípio | Clipe do Blender | Camada procedural no Godot | VFX / câmera | Em sprite 2D |
|---|---|---|---|---|
| Squash & stretch | Escala de ossos de controle | Mola + shader de vértice | Partículas esticadas pela velocidade | `scale` com área constante, quadros deformados |
| Antecipação | Chave de recuo | Telegrafia (decal, brilho, olhar) | Fase 1 do VFX | 2 a 4 desenhos, hold no último |
| Staging | Pose de contato | Câmera co-op, aro de cor | Hierarquia de valor | Silhueta |
| Straight/pose | Blocking → breakdown → spline | Simulação | Partículas | Chaves primeiro |
| Follow-through/overlap | Defasagem de chaves | `SpringBoneSimulator3D`, molas | Rastro, fumaça | Partes com atraso |
| Slow in/out | Alças por chave | Curvas de crossfade, tweens | Curvas de alfa e escala | Espaçamento |
| Arcos | Rotação no ombro | — | Trilha seguindo o pulso | Curva-guia |
| Secundária | Clipes aditivos | `Add2`, `LookAtModifier3D` | Brilhos menores | Camadas |
| Timing | 60 fps, marcadores | `TimeScale`, hit-stop | Duração do VFX | Duração por quadro |
| Exagero | Passe de exagero | Amplitude de aditivos | Shake, flash | Smear, membros esticados |
| Volume | Rig com preservação | Não escalar sem compensar | — | Pixels por metro fixo |
| Apelo | Poses de assinatura | Idle e emotes | Cor por personagem | Design |

---

## 5. Ataques, cancelamento, root motion, holds, ciclos e pose

### 5.1 Fases do ataque e contagens de quadros

Fontes do modelo de fases: Sakurai (*standby, windup, strike, follow-through*) [fonte]; análise de Dark Souls 3 dividindo o ataque inimigo em 5 fases sobre o trabalho de Eric Jacobus, com hitbox ativa de 2 a 4 quadros e resposta de input medida em 60 a 100 ms ([Game Developer](https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3)) [fonte via busca]; vocabulário de jogos de luta (startup, ativo, recuperação, cancelamento) ([glossário Wiktionary](https://en.wiktionary.org/wiki/Appendix:Glossary_of_fighting_games), [Capcom SF Seminar](https://game.capcom.com/cfn/sfv/column/131432?lang=en)) [fonte]. Uma planilha de fã de Hades lista um ataque de lança com 8 quadros de startup e 10 de "endlag" [não verificado, fonte não oficial].

**Tabela-base para este projeto [proposta]:**

| Ação | Antecipação/startup | Ativo | Recuperação | Cancelável a partir de | Total | Hit-stop |
|---|---|---|---|---|---|---|
| Herói, golpe leve 1 | 3 a 5 | 2 a 4 | 12 a 16 | fim do ativo + 2 (para próximo golpe e esquiva) | 18 a 24 | 3 a 4 |
| Herói, golpe leve 2 | 3 a 5 | 2 a 4 | 12 a 18 | idem | 18 a 26 | 3 a 4 |
| Herói, finalizador do combo | 6 a 10 | 3 a 6 | 20 a 30 | fim do ativo + 8 (só esquiva) | 30 a 45 | 8 a 12 |
| Herói, pesado / carregado | 12 a 20 (ou carga segurada) | 4 a 6 | 20 a 30 | fim do ativo + 6 | 40 a 55 | 10 a 14 |
| Herói, feitiço projétil | 4 a 8 | 1 (spawn) | 8 a 14 | spawn + 4 | 14 a 22 | 0 no lançador, 3 a 6 no alvo |
| Herói, feitiço de área | 10 a 16 | 2 a 6 | 16 a 24 | spawn + 10 | 30 a 45 | 6 a 10 |
| Herói, esquiva | 0 a 2 | invulnerável 8 a 14 | 8 a 12 | ataque a partir do quadro 12 a 16 | 20 a 30 | — |
| Inimigo comum, corpo a corpo | **24 a 36** | 3 a 6 | 24 a 40 (janela de punição) | — | 55 a 80 | 3 a 5 (no jogador atingido) |
| Inimigo comum, à distância | 30 a 45 (mira visível) | 1 | 20 a 30 | — | 50 a 75 | — |
| Elite | 30 a 45 | 4 a 8 | 30 a 45 | — | 70 a 100 | 6 a 8 |
| Chefe, golpe grande | 45 a 90 (com marcação no chão) | 4 a 12 | 40 a 70 | — | 100 a 170 | 10 a 20 |
| Chefe, "jab" rápido (pune quem fica perto) | 16 a 22 com som característico | 3 | 20 | — | 40 a 45 | 4 |

Por que 24 quadros como piso da telegrafia: 400 ms = reação visual (~250 a 300 ms para jogador bom a médio, tabela citada pela [Blur Busters](https://www.blurbusters.com/human-reflex-part1-input-lag-and-the-limits-of-human-reaction-time)) + tempo de decidir + latência de input e de rede no co-op online. Para variar sem frustrar: atrasar (hold mais longo na pose carregada) é aceitável **se** a pose for a mesma e o sinal sonoro ocorrer no fim da espera, não no começo; o "fakeout" que atrasa sem aviso irrita ([Steam, críticas a chefes de Elden Ring](https://steamcommunity.com/app/1245620/discussions/0/3719440044270966891)) [fonte].

### 5.2 Anatomia visual de um golpe do herói (leve, 22 quadros) [proposta]

| Quadros | Fase | Pose | Princípios |
|---|---|---|---|
| 1 a 3 | Startup | Já começa carregado (o clipe pula a parte lenta da antecipação), ombro recuado, quadril começa a girar | Antecipação curta, arco |
| 4 | Smear | Arma em leque (malha ou shader), corpo já na direção do golpe | Exagero, smear |
| 5 a 7 | Ativo | Pose de contato: linha de ação máxima, membro estendido além do real | Staging, exagero |
| contato | Hit-stop 3 a 4 | Atacante quase parado (Sakurai: manter um pouco de movimento no atacante), alvo tremendo na horizontal | Timing |
| 8 a 10 | Follow-through | Arma passa do alvo 15 a 30°, tronco continua a girar, cabelo e capa em mola | Follow-through |
| 11 a 22 | Recuperação | Volta à guarda com slow out; cancelável a partir do quadro 9 | Slow out |

### 5.3 Cancelamento

- **O que é:** pular a recuperação para outra ação ([glossário](https://en.wiktionary.org/wiki/Appendix:Glossary_of_fighting_games)) [fonte]. Em ação-RPG, cancelar em esquiva é o que torna golpes com recuperação longa toleráveis.
- **Hierarquia [proposta]:** esquiva cancela quase tudo depois do ativo; golpe leve cancela em golpe leve seguinte (combo) e em feitiço; feitiço não cancela em golpe; nada cancela a antecipação do pesado, exceto esquiva (com custo).
- **Buffer de input:** guardar o próximo comando nos últimos 8 a 12 quadros da ação atual e executar no primeiro quadro cancelável [proposta].
- **Implementação no Godot:** a janela vem da trilha (método `open_cancel()` chamado pela trilha de método, ou marcador), não de constantes. `AnimationNodeStateMachineTransition` com `switch_mode` imediato e `xfade_time` de 3 a 6 quadros (0,05 a 0,1 s) para cancelamentos; `reset = true` para a animação de destino começar do quadro 1 [doc].
- **Consequência para a animação:** como a recuperação pode ser cortada em qualquer ponto, cada quadro dela deve ser uma pose "blendável" para a guarda e para a esquiva, e o follow-through de tecido deve estar em molas (sobrevive ao corte).

### 5.4 Holds e holds em movimento

- **Hold:** manter uma pose. Em jogo, holds puros parecem travamento; o padrão é o **moving hold**: a pose se mantém mas continua viva com respiração, olhar, leve deriva ou tremor ([Animation Mentor](https://animationmentor.com/blog/why-all-animators-need-to-master-the-moving-hold), [AnimSchool](https://blog.animschool.edu/?p=858)) [fonte].
- **Onde usar em jogo [proposta]:** pose de contato (2 a 4 quadros + hit-stop), ápice do pulo (4 a 8), antecipação do inimigo (o hold mais importante do jogo: 8 a 20 quadros com tremor de 1 a 2° e brilho crescendo), pose final de vitória.
- **Números de moving hold [proposta]:** deriva de 1 a 3% da amplitude da pose ao longo do hold, com ease; tremor de "esforço" 1 a 2° a 8 a 12 Hz só no inimigo carregando.
- **2D:** hold por duração de quadro + 1 pixel de deriva a cada 6 a 10 quadros.

### 5.5 Root motion

- **O que é:** o deslocamento vem do osso raiz da animação, não do código. Bom para golpes com avanço, esquivas e reações, em que pé e chão precisam bater.
- **Godot [doc]:** `AnimationMixer.root_motion_track` aponta o osso; `get_root_motion_position()`, `get_root_motion_rotation()` e acumuladores dão o delta por quadro, e a doc mostra o padrão `velocity = rotação_atual * get_root_motion_position() / delta`. `root_motion_local` extrai como translação local antes do blend.
- **Política [proposta]:** locomoção (andar, correr) **sem** root motion, dirigida por código com sincronização de passada (velocidade do clipe = velocidade real / velocidade nominal do clipe) para resposta imediata; golpes, esquivas, quedas e reações **com** root motion, com o deslocamento máximo combinado com o design (ex.: golpe leve avança 0,4 a 0,8 m). Em co-op online, o servidor deve conhecer as curvas de deslocamento (tabela exportada do Blender), não confiar na animação do cliente.
- **Blender:** manter o osso raiz no chão com chaves só em XY e rotação em Z; exportar uma curva por clipe (CSV/JSON) com deslocamento por quadro para a lógica.

### 5.6 Ciclos de andar e correr

| Fonte / contexto | Passo (um pé) | Ciclo (dois passos) | A 60 fps |
|---|---|---|---|
| Richard Williams, andar normal "em 12s" a 24 fps | 12 quadros = 0,5 s | 1,0 s | 30 / 60 |
| Williams, andar rápido "em 8s" | 8 = 0,33 s | 0,67 s | 20 / 40 |
| Williams, corrida "em 6s" | 6 = 0,25 s | 0,5 s | 15 / 30 |
| Williams, corrida muito rápida "em 4s" | 4 = 0,17 s | 0,33 s | 10 / 20 |
| Jogos 3D, corrida (média citada) | — | 12 a 16 quadros a 30 fps (0,4 a 0,53 s) | 24 a 32 |

Fontes: [Monmouth University, adaptado do *Animator's Survival Kit*](https://animation.monmouth.edu/instruct/?p=351), [blog UAL](https://advancedandexperimentalanimationunit.myblog.arts.ac.uk/2022/03/14/week-8-walk-and-run-animation-cycle/), [gamedev.net](https://gamedev.net/forums/topic/642655-understanding-2d-walkingrun-animation-in-games/5059674/) [fonte]. Atenção: as fontes secundárias confundem "passo" e "ciclo"; o livro não foi conferido.

**Para o projeto [proposta]:** corrida do herói 30 a 36 quadros por ciclo a 60 fps (0,5 a 0,6 s), 4 poses-chave por passo (contato, descida, passagem, subida); andar 50 a 60 quadros; corrida de inimigo pequeno 20 a 24 (mais nervosa). Em sprite 2D: corrida de 6 a 8 desenhos, andar 8 a 12. Detalhes que denunciam qualidade: quadril cai no quadro de descida (5 a 8 cm em escala humana), tronco inclina 5 a 12° para frente na corrida, braços em oposição com 1 a 2 quadros de atraso em relação às pernas, cabeça estabiliza (desloca menos que o quadril).

**Inclinação procedural:** ângulo = `atan2(aceleração_horizontal, g)`, suavizado e limitado; 5 m/s² dá ~27°, e a própria fonte observa que o valor físico costuma ser exagerado para personagens estilizados ([tutorial Vulkan de lean procedural](https://docs.vulkan.org/tutorial/latest/Advanced_glTF/Procedural_Animation_IK/06_physics_driven_lean.html)) [fonte]. Proposta: fator 0,3 a 0,5 do físico, limite 8 a 15° no tronco, mais inclinação lateral nas curvas a partir da aceleração centrípeta, mola ζ 0,6.

### 5.7 Pose: linha de ação, silhueta, assimetria

- **Linha de ação:** uma curva (C ou S) que atravessa o corpo da cabeça ao pé de apoio. Em poses-chave de ataque, uma C forte; em idle, uma S suave. Nunca uma linha reta vertical (pose "manequim").
- **Silhueta:** o teste é a pose em preto chapado. Braços afastados do tronco, arma fora do corpo, pernas abertas em ângulo diferente.
- **Assimetria ("twinning"):** os dois braços ou as duas pernas não fazem a mesma coisa ao mesmo tempo nem no mesmo ângulo. Em poses geradas por script, este é o erro mais comum.
- **Verificação automática [proposta]:** (1) renderizar silhueta e medir a "razão de recorte" (área do casco convexo menos área da silhueta, dividida pela área da silhueta; poses fortes ficam acima de 0,35); (2) ângulos espelhados com diferença ≥ 10°; (3) projeção do centro de massa vs. pés (§4.11); (4) linha de ação: ajustar uma curva aos pontos cabeça, peito, quadril, pé de apoio e exigir curvatura não nula.

---

## 6. Game feel e juice

### 6.1 Steve Swink, *Game Feel* (2008)

Definição: "controle em tempo real de objetos virtuais num espaço simulado, com interações enfatizadas por polimento" ([arXiv 2011.09201](https://arxiv.org/pdf/2011.09201), [capítulo 1](https://puccjogos.github.io/balanceamento-2017-1s/materiais/GameFeel_Chap1.pdf)) [fonte]. Os três componentes viram três camadas do nosso trabalho:

| Componente de Swink | O que é para nós | Quem faz |
|---|---|---|
| Controle em tempo real | Latência de input, startup curto, cancelamento, buffer | Código + timing dos clipes |
| Espaço simulado | Colisão, empurrão, knockback, root motion, contato com o chão | Código + root motion |
| Polimento | Animação, partículas, som, câmera, hit-stop | Animação + VFX + áudio |

### 6.2 Vlambeer, "The Art of Screenshake" (Jan Willem Nijman, 2013)

Palestra de ~45 min que pega um shooter sem graça e adiciona cerca de 30 ajustes pequenos ([Game Developer](https://gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games)) [fonte]. Itens confirmados por uma reconstrução da palestra: aumentar a cadência e o tamanho do tiro, clarão de boca, tiro mais rápido, **hit pause**, **knockback do inimigo**, **permanência** (cápsulas, cadáveres, fumaça que ficam), **câmera com lerp**, **recuo da arma** ([DK Liao, reconstrução](https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects)) [fonte]. Em entrevista sobre Nuclear Throne, Nijman cita empurrar a câmera 6 px para trás da mira e somar 4 ao valor de tremor por tiro [fonte via busca, não conferida].

Lições para nós: **permanência** combina com o estilo (marcas de queimado e gelo no chão que ficam por 10 a 30 s), **knockback** é animação (o inimigo precisa de reação que mostra a direção), e tremor de tela é tempero, não base.

### 6.3 Câmera: trauma (Squirrel Eiserloh, GDC 2016 "Juicing Your Cameras With Math")

Modelo usado amplamente: cada evento soma "trauma" (0 a 1), o tremor usa `trauma²` (ou `³`) vezes amplitude máxima, ruído Perlin/simplex em vez de aleatório puro, e o trauma decai linearmente ([implementação comunitária](https://community.gamedev.tv/t/enhanced-camera-shake-with-perlin-noise/204230)) [fonte secundária; palestra não vista].

Números [proposta, para câmera 3/4 alta]: deslocamento máximo 0,15 a 0,3 m, rotação de rolagem máxima 1,5 a 3°, frequência do ruído 15 a 25 Hz, decaimento de 1,5 a 2,5 trauma/s. Trauma por evento: golpe leve do herói 0 (nada!), pesado 0,2, explosão própria 0,35, golpe de chefe recebido 0,5, morte de chefe 0,8. Em co-op de tela compartilhada, tremor muito forte prejudica 3 pessoas para premiar 1; preferir **chute direcional** curto (3 a 6 quadros na direção do golpe) a tremor aleatório.

### 6.4 Masahiro Sakurai: hit-stop e animação de ataque

- **"Stop for Big Moments" e "boss stop":** hit-stop congela atacante e alvo alguns quadros; congelar a tela inteira ao derrotar chefe ([TV Tropes, resumo da série](https://tvtropes.org/pmwiki/pmwiki.php/WebVideo/MasahiroSakuraiOnCreatingGames)) [fonte].
- **8 técnicas de hit-stop** (resumo do vídeo): (1) tremer mais o personagem atingido; (2) manter a hitbox parada; (3) tremer na horizontal no chão e na vertical no ar; (4) reduzir o tremor gradualmente; (5) controlar a duração; (6) interpolar quadros até a pose de dano; (7) manter o atacante se mexendo levemente; (8) escalar o tremor pela distância da câmera ([NintendoWire](https://nintendowire.com/news/2022/12/12/this-week-in-sakurai-12-5-12-11-fine-tuning-hit-stop-and-cheating-the-system/)) [fonte].
- **Coluna da Famitsu (2015):** durante o hit-stop, 4 quadros para passar suavemente da contração inicial à animação de dano ([Source Gaming](https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/)) [fonte].
- **Fórmulas de hitlag do Smash (fãs):** Melee `⌊d/3 + 3⌋`; Smash 4 `(d/2,6 + 5) × multiplicadores`, limite 30 quadros, agachado ×0,67, elétrico ×1,5; exemplo: golpe de 15% dá ~8 quadros no Melee, 9 no Brawl/Smash 4, 15 no Ultimate ([SmashWiki](https://www.ssbwiki.com/Hitlag), [Kuroganehammer](https://kuroganehammer.com/Smash4/Formulas)) [fonte de fãs].
- **Animação:** 4 fases (*standby, windup, strike, follow-through*); golpes rápidos com pouco ou nenhum lead-in; exagero acima do moderado [fonte, §4.2 e §4.10].

**Tabela de hit-stop para o projeto [proposta, calibrada pelas fontes acima]:** `hitstop = clamp(round(dano_relativo × 6 + 2), 2, 14)` quadros para golpes normais, onde `dano_relativo` = dano / dano do golpe leve básico. Resultado: leve 3 a 4, médio 6 a 8, pesado 10 a 14; finalizador e morte de elite 16 a 20; morte de chefe 30 a 40 + câmera lenta 0,3× por 30 quadros. A biblioteca Juicee usa 0,08 s (~5 quadros) como padrão e descreve 50 a 100 ms como "faixa ideal" ([código](https://github.com/Kelpekk/Juicee)) [fonte].

**Hit-stop em co-op [proposta]:** local por entidade (`AnimationTree`/`AnimationPlayer` com `speed_scale = 0` ou `AnimationNodeTimeScale` = 0, velocidade física zerada, partículas da entidade pausadas) para atacante e alvo; os outros jogadores continuam. Hit-stop global só para morte de chefe e eventos de roteiro. Restaurar com timer que ignora a escala de tempo (quarto argumento de `create_timer`) e num nó que não morre com o inimigo ([fórum Godot](https://forum.godotengine.org/t/tutorial-hit-stop-and-screen-shake-in-godot-4-autoload-trauma-camera-mit/145240)) [fonte].

### 6.5 Juice it or lose it (Jonasson e Purho, 2012) e Dead Cells

"Juice it or lose it" (GDC Europe 2012) é a outra palestra clássica: um Breakout recebe tweens, squash, partículas, som e câmera até "ganhar vida" [fonte de memória, não reconferida nesta busca]. Dead Cells usou jogos de luta como referência para dar impacto às armas ([PC Gamer](https://www.pcgamer.com/dead-cells-combat-evolved-from-tower-defense-games-and-team-fortress-2)) [fonte].

### 6.6 O "pacote de impacto" de um golpe (ordem de eventos no quadro de contato) [proposta]

| Quadro relativo ao contato | Evento |
|---|---|
| 0 | Hit-stop local começa; flash branco-quente no alvo (shader, 2 quadros, **não** 100% branco: 85 a 90% de valor); som de impacto com ataque forte; faísca de impacto (clímax do VFX) |
| 0 a hit-stop | Alvo treme horizontal 2 a 4 px (ou 2 a 4 cm), amplitude decrescente; atacante avança 5 a 10% do movimento restante (não congela 100%) |
| fim do hit-stop | Knockback começa com velocidade máxima e desacelera (atrito); pose de dano chega em 4 quadros (Sakurai) |
| +1 a +4 | Chute de câmera direcional (pesados apenas); partículas secundárias (lascas, poeira) |
| +6 a +30 | Dissipação do VFX com baixo contraste; número de dano sobe e some |
| +30 a +600 | Permanência: marca no chão |

---

## 7. Animação em 2s e animação limitada como estilo

### 7.1 Referências de estilo

| Obra | O que fazem | Lição para nós | Fonte |
|---|---|---|---|
| **Spider-Verse** (filmes) | Maioria em 2s ("12 imagens por segundo"), com escala fluida; Miles em 2s ("staccato") contra Peter em 1s; sem motion blur, resolvendo pans rápidos de outro jeito | Taxa de pose como traço de personalidade; usar smear/linhas em vez de blur | [AWN](https://www.awn.com/animationworld/creating-stylized-universe-sonys-spider-man-spider-verse), [CG Spectrum](https://www.cgspectrum.com/blog/spider-man-into-the-spider-verse-how-they-got-that-mind-blowing-look) |
| **South of Midnight** (Compulsion, 2025) | Jogo roda a 60 fps; rostos nas cinemáticas perto de 15 fps imitando 2s; tratamento de stop motion mais leve no corpo do que o planejado por falta de tempo para treinar animadores | Separar taxa de render (60) da taxa de pose; aplicar o stepped onde o jogador não controla ou em partes do corpo | [Engadget](https://www.engadget.com/gaming/xbox/south-of-midnight-preview-stopped-motion-160003119.html), [GamesRadar](https://www.gamesradar.com/games/action/yes-south-of-midnight-will-still-run-at-60fps-despite-its-stop-motion-animation-youre-still-in-this-crafted-world-without-making-it-you-know-too-nauseating), [SIGGRAPH](https://blog.siggraph.org/2026/04/stop-motion-southern-gothic-and-games-the-visual-language-of-south-of-midnight.html/) |
| **Hi-Fi Rush** (Tango) | Animações interpoladas para terminar no tempo da batida, mesmo se o input veio adiantado ou atrasado; lead-ins retemporizados para o ponto final cair na batida | A batida como "grade de tempo"; útil se o jogo tiver música dirigindo ataques | [Unreal Engine](https://www.unrealengine.com/developer-interviews/hi-fi-rush-was-inspired-by-shaun-of-the-dead-and-futurama), [GDC 2024](https://schedule.gdconf.com/session/developing-hi-fi-rush-backwards-and-finding-our-positive-gameplay-loop/899845) |
| **Guilty Gear Xrd** (Arc System Works) | Pararam de interpolar entre chaves para imitar os jogos 2D antigos; cada quadro é chave; malha deformada por chave; luz ajustada por quadro; câmera em taxa baixa fica ruim porque o cenário salta | Stepped só no personagem; câmera e cenário a 60; deformação por pose é parte do estilo | [Handout de Motomura](https://www.ggxrd.com/Motomura_Junya_GuiltyGearXrd.pdf), [GDC Vault](https://gdcvault.com/play/1022031/GuiltyGearXrd-s-Art-Style-The), [BlenderNation](https://www.blendernation.com/2015/07/26/junya-c-motomura-behind-the-scenes-of-guilty-gear-xrd/) |

Todas lidas por resumo de busca [fonte secundária]. A informação de que alguns personagens do Xrd eram em 1s e outros em 2s ou 4s vem de comentário de fórum [não verificado].

### 7.2 Regras para usar 2s sem perder resposta [proposta]

1. **Render, física, câmera, VFX e UI a 60.** Só a pose do personagem é stepped.
2. **Primeiro quadro após o input é sempre mostrado imediatamente** (o "relógio" das poses reinicia no input). Nunca esperar o próximo degrau.
3. **Contato em 1s:** os 2 a 4 quadros em volta do contato rodam em 1s (ou com smear) para não perder a leitura do golpe.
4. **Holds de 2 a 4 quadros de jogo** (30 a 15 poses/s), escolhidos por personagem e por ação: idle e corrida em 3s ou 4s; golpe em 2s; impacto em 1s.
5. **Deslocamento do corpo no mundo é contínuo**; só a pose é em degrau (senão o personagem "teleporta" e a colisão parece errada).
6. **Molas (`SpringBoneSimulator3D`) contínuas ou quantizadas junto?** Contínuas brigam com o estilo; quantizar o resultado exige modificador próprio. [não verificado] Testar as duas opções antes de decidir.

### 7.3 Pipeline testado: do Blender ao Godot sem perder o degrau [teste + doc]

Testes em `teste_bpy.py` e `teste_const.py` (pasta temporária). Resultados:

| Configuração no Blender | glTF exportado | O que o Godot faz | Veredito |
|---|---|---|---|
| Chaves `BEZIER` + modificador `STEPPED` (frame_step 2), **export sem amostragem** | Canal só com Bezier sai como `CUBICSPLINE` com as 4 chaves originais: **o modificador some** | Interpola suave | Errado |
| Mesmo, **com amostragem** (`export_force_sampling=True`) | `LINEAR`, 1 amostra por quadro, valores em pares repetidos (degrau preservado nos dados) | Reamostra a `animation/fps` (padrão **30**) com interpolação linear: degraus de 2 quadros a 60 viram rampas | Errado com o padrão; aceitável só com import a 60 |
| Chaves com interpolação **`CONSTANT`** a cada 2 quadros | **`STEP`** (com ou sem amostragem) | Importa como `INTERPOLATION_NEAREST` (código em `modules/gltf/gltf_document.cpp`, 4.5) | **Certo** |
| Canal com interpolações mistas | O exportador avisa "Baking animation because there are keyframes with different interpolation methods in one channel" e amostra | — | Evitar misturar |

Receita [proposta]: animar em Bezier a 60 fps (fonte de verdade) → script "assa" a ação final num clone com chaves `CONSTANT` nos quadros escolhidos (com o mapa de holds por trecho: 1s no contato, 2s no golpe, 3s no idle) → exporta → import no Godot com `animation/fps = 60`. O Godot reamostra mesmo assim (bake por `bake_fps` em todo canal de transformação, vi no código), mas com `NEAREST` os degraus ficam intactos se o fps do import for igual ao do Blender.

Também confirmado no teste: no Blender 5.3 `bpy.types.Action` **não tem mais** `fcurves`; usar:

```python
from bpy_extras import anim_utils
cb = anim_utils.action_get_channelbag_for_slot(obj.animation_data.action, obj.animation_data.action_slot)
for fc in cb.fcurves:
    for k in fc.keyframe_points:
        k.interpolation = 'CONSTANT'      # ou 'BACK' (k.back), 'ELASTIC' (k.amplitude, k.period), k.easing
```

### 7.4 Sprite 2D em "2s"

Em sprite, ser stepped é natural; o erro é o contrário: renderizar 60 imagens por segundo do 3D e parecer vídeo. Dead Cells (§9) e Guilty Gear convergem: **poucas poses fortes, holds variados**. Proposta: renderizar do Blender só os quadros-chave e breakdowns escolhidos, com duração por quadro no `SpriteFrames`.

---

## 8. Smears e múltiplos

### 8.1 O que são e quem usa

- **Smear:** quadro intermediário esticado ao longo da trajetória, substituto estilizado do motion blur ([Wikipedia](https://www.wikipedia.org/wiki/Smear_frame)); comum em golpes de espada de Hollow Knight, Genshin Impact e outros ([Bloop Animation](https://www.bloopanimation.com/the-art-of-smear-frames/)) [fonte].
- **Múltiplos:** a forma (ou parte dela) duplicada várias vezes ao longo do caminho ([tese de Hagenberg sobre smear frames](https://theses.fh-hagenberg.at/index.php/system/files/pdf/Lendenfeld18.pdf), que tem capítulo sobre Overwatch; só vi o índice) [fonte parcial].
- **Overwatch:** David Gibson (GDC 2016, Animation Bootcamp, caso Mei) explicou smears e squash exagerado "100% intencionais", que aparecem por instantes e compensam a falta de motion blur; Tracer é o exemplo mais extremo ([Kotaku](https://kotaku.com/this-is-not-an-overwatch-glitch-1777612546), [80.lv](https://80.lv/articles/david-gibson-animating-mei-in-overwatch)) [fonte]. Smears ficam mais visíveis em poses de câmera fixa (destaques); em primeira pessoa e em velocidade normal, quase não se veem conscientemente.

### 8.2 Regras numéricas [proposta]

| Tipo | Duração | Comprimento | Onde |
|---|---|---|---|
| Smear de membro/arma | **1 quadro** (2 no máximo, só em golpe pesado) | 1 a 2× o comprimento do membro, nunca mais que 1,5× a largura do corpo atrás do objeto | Quadro imediatamente antes do contato |
| Múltiplos | 1 a 2 quadros | 2 a 4 cópias, alfa decrescente 70 → 20%, ou contornos | Giros, chutes rápidos, esquiva |
| Esticamento de corpo inteiro (dash) | 2 a 3 quadros | 1,3 a 1,6× | Início do dash |
| Arco de VFX (trilha de arma) | 6 a 12 quadros | Arco completo do golpe | Junto com o smear, persiste mais |

### 8.3 Três formas de fazer smear no nosso pipeline

1. **Malha de smear no Blender (melhor controle):** forma esculpida por script (casca de arco) anexada ao osso da arma, com visibilidade por chave `CONSTANT` (aparece 1 quadro). Exporta como objeto separado; no Godot, a trilha de visibilidade ou de `instance_shader_parameter` liga e desliga.
2. **Deformação de vértice por shader (mais genérico) [teste]:** shader espacial que recebe a velocidade em espaço de mundo; faz squash com volume preservado no eixo do movimento e arrasta para trás só os vértices cuja normal aponta contra a velocidade, com ruído de quebra. Funcionou no renderer **Compatibility** (o da Web) sob Xvfb:

   Captura do teste (fora do repositório, pasta temporária): `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-animacao/godot-smear/smear_teste.png`. Resultado observado: da esquerda para a direita, parado; 12 m/s com squash +25%; 24 m/s com squash +45%; achatado −30% (fica mais alto e mais estreito, volume constante). Problemas vistos: com `velocidade × smear_time` = 1,9 m o rastro fica comprido demais (regra da tabela 8.2 confirmada); as normais não são recalculadas, então o lado esticado fica com sombreamento "riscado", aceitável por 1 quadro e feio por mais. Código-base:

   ```glsl
   // dentro de vertex(): v_obj = velocidade em espaço do objeto
   vec3 d = v_obj / spd;  float s = 1.0 + squash;
   float along = dot(VERTEX, d);  vec3 ortho = VERTEX - along * d;
   VERTEX = d * along * s + ortho / sqrt(s);                 // volume constante
   float back = clamp(-dot(NORMAL, d), 0.0, 1.0);            // só o lado de trás
   VERTEX -= d * spd * smear_time * back * mix(0.55, 1.0, hash(floor(VERTEX * 6.0)));
   ```

   Gists de referência verificados (`git ls-remote` ok, sem licença declarada, então só como leitura): [ducklin5, smear 2D Godot](https://gist.github.com/ducklin5/c3a13bc0b852be34db9c4e66e2a23007), [itspacchu, smear 3D Godot 3](https://gist.github.com/itspacchu/88c9d557295c9225364d8a1f1eed088c), [cjacobwade (Unity)](https://gist.github.com/cjacobwade/c0c524af3e29aacb340ace33729043fb).
3. **Smear desenhado em sprite:** em 2D, 1 quadro desenhado (forma de gota ou leque na cor da arma), ou o renderizador do Blender produz o quadro de smear a partir da malha de smear do item 1.

---

## 9. O pipeline de Dead Cells (3D animado, renderizado como pixel art)

Artigo: Thomas Vasseur, "Art Design Deep Dive: Using a 3D pipeline for 2D animation in Dead Cells" (Gamasutra, jan/2018) ([Game Developer](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-), [resumo do Game Anim](https://www.gameanim.com/2018/01/31/dead-cells-3d-pipeline-2d-animation/), [tradução no Habr](https://habr.com/post/416589)). Lido só via resumo de busca [fonte secundária].

| Ponto | O que se sabe | Status |
|---|---|---|
| Por quê | Um artista sozinho por um ano; precisava de pixel art sem redesenhar cada retake; trocar equipamento no modelo e reaproveitar animação entre modelos | [fonte] |
| Ferramentas | Modelos e animação no 3ds Max; ferramenta caseira de "pixelização" que renderiza o 3D em baixa resolução | [fonte] |
| Método | Animação por quadros-chave como em 2D; só depois que a animação convence com o **mínimo de quadros** é que entram quadros de interpolação antes ou depois das chaves | [fonte] |
| Cenários | Desenhados à mão; só personagens e animações em 3D | [fonte] (Steve Filby) |
| Resolução, antisserrilhado, sombreamento | Não encontrado nas buscas | [não verificado] |

O que isso significa para nós: é exatamente o caminho do "Céu Arcano" (rig por SDF) e do relatório `direcao-de-arte.md` (HD-2D com sprites pré-renderizados). A lição central de Dead Cells, **chaves primeiro, interpolação por último e com parcimônia**, é a mesma da §4.4 e serve também para 3D.

---

## 10. VFX: o guia de estilo da Riot e a gramática do efeito

Guia público de VFX de League of Legends (Riot, 2017; autoria atribuída ao diretor de arte Jin Ho Yang): [anúncio](https://nexus.leagueoflegends.com/en-us/2017/10/dev-leagues-vfx-style-guide/), [PDF](https://nexus.leagueoflegends.com/wp-content/uploads/2017/10/VFX_Styleguide_final_public_hidpjqwx7lqyx0pjj3ss.pdf) (host bloqueado aqui), resumos em [VFX Apprentice](https://www.vfxapprentice.com/blog/10-league-of-legends-vfx-design-tips) e [80.lv](https://80.lv/articles/vfx-staples-shape-color-and-motion/) [fonte secundária].

### 10.1 Regras confirmadas pelos resumos

- **Objetivo número 1: clareza de gameplay.** O guia existe porque cada equipe fazia VFX num padrão diferente.
- **Valor:** evitar extremos (0% preto, 100% branco) para não se fundir com personagens, mapa e UI.
- **Saturação e contraste dirigem o foco:** mais saturação puxa mais atenção; contraste cria a área de foco.
- **Hierarquia por importância:** partículas ociosas com opacidade baixa, formas borradas e movimento sutil; efeitos que mudam a luta e ultimates com a maior saturação, opacidade e faixa de valor, silhueta clara e movimento intenso.
- **Ciclo de vida em 3 fases, não linear:** antecipação curta que avisa o inimigo (tempo definido pelo design), clímax/impacto com o maior número de elementos, maior contraste e saturação alta, dissipação breve com baixo contraste e baixa opacidade para não distrair. "Curvas lineares prejudicam a imersão."
- **Projéteis:** a ponta é o que o olho deve seguir, porque é a parte a evitar ([Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/), [análise de míssil no RealtimeVFX](https://realtimevfx.com/t/anatomy-of-a-league-of-legends-missile-part-2-what-are-we-communicating-with-our-vfx/13062)).

### 10.2 Números para o projeto [proposta]

| Fase do VFX | Fração da duração | Valor (V em HSV) | Saturação | Opacidade | Curva |
|---|---|---|---|---|---|
| Antecipação | 20 a 40% (igual à telegrafia em inimigos) | 40 a 70% | média | sobe de 30 a 80% | ease in (acelera para o clímax) |
| Clímax | 10 a 20% (2 a 6 quadros no pico) | 85 a 92% no núcleo, nunca 100% | máxima do jogo | 100% | degrau ou ease out muito rápido |
| Dissipação | 40 a 60% | cai para 30 a 50% | cai 30 a 50% | cai até 0 com ease out | exponencial, não linear |

Hierarquia de valor e saturação em co-op (do mais forte ao mais fraco): (1) telegrafias de dano inimigo; (2) projéteis inimigos; (3) impacto no próprio jogador; (4) feitiços dos jogadores no clímax; (5) personagens; (6) efeitos persistentes (poças, marcas); (7) ambiente. Regra: os efeitos de jogadores **nunca** usam a cor e a forma reservadas ao perigo inimigo (ex.: vermelho-alaranjado e anéis serrilhados só para inimigos).

Para elementos combináveis à la Magicka (fogo, gelo, raio, água, terra, vida, escudo, arcano), cada elemento precisa de **forma + movimento + cor** próprios, não só cor, para jogadores daltônicos e para leitura em silhueta [proposta].

---

## 11. Receitas de implementação

### 11.1 Blender: esqueleto de script pose a pose com breakdowns e defasagem [teste parcial]

```python
import bpy
from bpy_extras import anim_utils
scn = bpy.context.scene; scn.render.fps = 60

def key_pose(rig, frame, pose, interp='CONSTANT'):
    """pose = {osso: (rx, ry, rz)}; blocking em CONSTANT."""
    for name, rot in pose.items():
        pb = rig.pose.bones[name]; pb.rotation_mode = 'XYZ'; pb.rotation_euler = rot
        pb.keyframe_insert("rotation_euler", frame=frame)

def overlap(rig, chain, frames_per_link=1):
    """Ação sobreposta: atrasa as chaves de cada elo da cadeia."""
    cb = anim_utils.action_get_channelbag_for_slot(rig.animation_data.action, rig.animation_data.action_slot)
    for depth, bone in enumerate(chain):
        for fc in cb.fcurves:
            if f'"{bone}"' in fc.data_path:
                for k in fc.keyframe_points:
                    k.co.x += depth * frames_per_link
                    k.handle_left.x += depth * frames_per_link; k.handle_right.x += depth * frames_per_link

def spline(rig, contact_frames=()):
    """Passa para Bezier; chegada dura nos contatos; settle elástico na última chave."""
    cb = anim_utils.action_get_channelbag_for_slot(rig.animation_data.action, rig.animation_data.action_slot)
    for fc in cb.fcurves:
        kps = fc.keyframe_points
        for k in kps:
            k.interpolation = 'BEZIER'
            if round(k.co.x) in contact_frames:
                k.handle_left_type = 'VECTOR'
        if len(kps) >= 2:
            kps[-2].interpolation = 'BACK'; kps[-2].easing = 'EASE_OUT'; kps[-2].back = 1.70158
```

Fluxo de autocrítica do agente: renderizar folha de contato (grade de quadros) + traço de trajetória da ponta da arma + gráfico de espaçamento (distância percorrida por quadro) depois de cada passada e pontuar pela rubrica (§15).

### 11.2 Godot: estrutura da `AnimationTree` do herói [proposta]

```
BlendTree
├─ StateMachine "base"        (locomoção: BlendSpace1D idle/andar/correr com sync; esquiva; reações; morte)
├─ OneShot "ataque"           (clipes de golpe; fadein 0,03 s; fadeout 0,08 s; filtro: tronco+braços quando em movimento)
├─ Add2 "aditivo_impacto"     (flinch aditivo, amount animado 0→1→0 em 10 quadros)
├─ Add2 "respiracao"          (loop aditivo; amount 0,6 em combate, 1,0 no idle)
└─ TimeScale "hitstop"        (0 durante hit-stop local)
Skeleton3D
├─ LookAtModifier3D (pescoço, duration 0,25, limite 70°) → LookAtModifier3D (cabeça)
├─ SpringBoneSimulator3D (cabelo, capa, cinto; stiffness/drag por curva)
└─ [4.6+] TwoBoneIK3D (pés no chão, mão secundária na arma)
```

Lembretes [doc]: modificadores sempre rodam depois da reprodução do `AnimationMixer`; `influence` mistura cada modificador; `LookAtModifier3D` do osso pai antes do filho; `SpringBoneSimulator3D` sem escala no esqueleto.

### 11.3 Godot: mola de 2ª ordem (follow-through, inclinação, squash, câmera)

Forma de t3ssel8r ("Giving Personality to Procedural Animations using Math"): parâmetros `f` (frequência), `ζ` (amortecimento) e `r` (resposta inicial; `r > 1` dá overshoot imediato, `r < 0` dá antecipação), integrada com Euler semi-implícito e passo estável ([Hackaday](https://hackaday.com/2022/06/30/a-math-based-personality-for-games), [notas do autor](https://www.patreon.com/posts/procedural-video-82487305)) [fonte via resumo; o efeito de `r < 0` como antecipação é da minha memória do vídeo, não confirmado na busca].

```gdscript
class_name SecondOrder
var k1: float; var k2: float; var k3: float
var xp; var y; var yd
func _init(f: float, z: float, r: float, x0):
	k1 = z / (PI * f); k2 = 1.0 / pow(TAU * f, 2); k3 = r * z / (TAU * f)
	xp = x0; y = x0; yd = x0 * 0.0
func update(dt: float, x, xd = null):
	if xd == null: xd = (x - xp) / dt; xp = x
	var k2s = max(k2, max(dt * dt / 2.0 + dt * k1 / 2.0, dt * k1))  # estabilidade
	y = y + dt * yd
	yd = yd + dt * (x + k3 * xd - y - k1 * yd) / k2s
	return y
```

Presets [proposta]: cabelo/fita `f=2.5, ζ=0.35, r=0`; capa `f=1.8, ζ=0.5, r=0`; inclinação de tronco `f=3, ζ=0.6, r=0`; squash de aterrissagem `f=4, ζ=0.4, r=2` (bate e volta); câmera `f=1.5, ζ=0.9, r=0`; arma "com peso" na troca de mira `f=3, ζ=0.5, r=-0.5` (pequena antecipação). Alternativas prontas: [orangeduck/Spring-It-On](https://github.com/orangeduck/Spring-It-On) (MIT, C, molas críticas, inércia "dead blending", base para portar) e [TheAllenChou/numeric-springing](https://github.com/TheAllenChou/numeric-springing) (MIT).

### 11.4 Godot: hit-stop local para co-op [proposta]

```gdscript
func hitstop(entities: Array, frames: int) -> void:
	for e in entities:
		e.anim_tree.set("parameters/hitstop/scale", 0.0)
		e.set_physics_process(false)
		e.shake_visual(Vector3.RIGHT if e.is_on_floor() else Vector3.UP, 0.03, frames)  # decai
	await get_tree().create_timer(frames / 60.0, true, false, true).timeout  # ignora time_scale
	for e in entities:
		if is_instance_valid(e):
			e.anim_tree.set("parameters/hitstop/scale", 1.0); e.set_physics_process(true)
```

Rodar num autoload (sobrevive à morte do inimigo). Atacante: escala 0,1 em vez de 0 (Sakurai: atacante continua se movendo levemente).

---

## 12. Ferramentas e repositórios verificados

Todos verificados com `git ls-remote <url> HEAD` neste container (27/11/2026); licença lida no arquivo `LICENSE` após clone raso.

| Repositório | O que é | Licença | Observação |
|---|---|---|---|
| [Kelpekk/Juicee](https://github.com/Kelpekk/Juicee) | Juice para Godot 4.3+: tremor, hit-stop, squash, partículas, números de dano, 117 efeitos, sequências | MIT | GDScript; hit-stop global por `Engine.time_scale` (adaptar para local no co-op) |
| [TheAllenChou/godot-squash-and-stretch](https://github.com/TheAllenChou/godot-squash-and-stretch) | Squash and stretch por velocidade, 2D e 3D | MIT | **C#** (`project.godot` com feature "C#"): não serve para export Web; ler a matemática e portar |
| [yaelatletl/godot-jigglebones](https://github.com/yaelatletl/godot-jigglebones) | Jiggle bones para Godot 4.0 | MIT | Redundante com `SpringBoneSimulator3D` no 4.4+ |
| [orangeduck/Spring-It-On](https://github.com/orangeduck/Spring-It-On) | Molas, amortecedores, dead blending, controlador, em C | MIT | Referência matemática |
| [TheAllenChou/numeric-springing](https://github.com/TheAllenChou/numeric-springing) | Molas numéricas (2D, 3D, rotação) | MIT | Referência matemática |
| [godotengine/godot-demo-projects](https://github.com/godotengine/godot-demo-projects) | Demos oficiais (inclui 3D com AnimationTree) | MIT | Exemplos de máquina de estados |
| Gists de smear ([ducklin5](https://gist.github.com/ducklin5/c3a13bc0b852be34db9c4e66e2a23007), [itspacchu](https://gist.github.com/itspacchu/88c9d557295c9225364d8a1f1eed088c), [cjacobwade](https://gist.github.com/cjacobwade/c0c524af3e29aacb340ace33729043fb)) | Smear por shader | sem licença declarada | Só como leitura; reescrever |
| `aarriagadap/AnimAide` (addon de Blender) | — | — | **Inalcançável** (`git ls-remote` pede credencial: repositório privado, renomeado ou inexistente) |

Embutidos e sem download: Blender `rigify` (rig com preservação de volume), interpolações `BACK/ELASTIC/BOUNCE`, modificadores de F-curve (`STEPPED`, `NOISE`, `CYCLES`); Godot `SpringBoneSimulator3D`, `LookAtModifier3D`, `AimModifier3D`, `CopyTransformModifier3D`, `BoneConstraint3D`, `RetargetModifier3D`, `ModifierBoneTarget3D` (4.5), `TwoBoneIK3D`, `IKModifier3D`, `LimitAngularVelocityModifier3D` (4.6+).

---

## 13. Testes práticos feitos nesta pesquisa

| # | Teste | Resultado |
|---|---|---|
| T1 | API de keyframes do Blender 5.3 | `Action.fcurves` não existe mais; ação em camadas com 1 camada e 1 slot (`OBRig`); curvas via `anim_utils.action_get_channelbag_for_slot` |
| T2 | Defasagem de 1 quadro por osso numa cadeia de 3 | Chaves em 1/7/9/16, 2/8/10/17, 3/9/11/18, como esperado |
| T3 | Modificador `STEPPED` (step 2) | Avaliação: quadros 3, 4, 5 = -0,494, 0,152, 0,152 (degrau funciona no Blender) |
| T4 | Export glTF com `STEPPED` | Sem amostragem: canal puro Bezier sai `CUBICSPLINE` com chaves originais (modificador ignorado); com amostragem: `LINEAR` por quadro com valores repetidos |
| T5 | Export glTF com chaves `CONSTANT` | `STEP` com e sem amostragem |
| T6 | Código do importador glTF do Godot 4.5 | `STEP` → `INTERPOLATION_NEAREST`; todo canal de transformação reamostrado a `bake_fps` (= `animation/fps`, padrão 30) |
| T7 | Shader de squash com volume + smear no Compatibility (Godot 4.5.1, Xvfb) | Compila e renderiza; volume preservado; rastro longo demais acima de ~1,5× a largura; sombreamento riscado por normais não recalculadas |
| T8 | Tabelas de easing e mola | §2.2 |

---

## 14. (i) Bíblia de animação do projeto: checklist prático

Para cada animação ou efeito, o agente percorre esta lista **antes** de considerar pronto. Cada item é verificável por script ou por leitura de quadros.

**A. Planejamento**

- [ ] A animação tem uma ficha: nome, função de jogo, duração em quadros a 60, quadros de startup/ativo/recuperação/cancelamento, eventos (hitbox, VFX, SFX, passos), se tem root motion e quanto desloca.
- [ ] Existe uma frase de intenção ("golpe rápido e cortante, termina equilibrado") e a personalidade do personagem (§4.12) está escrita.
- [ ] Taxa de pose escolhida por trecho (1s, 2s, 3s) e documentada.

**B. Poses (blocking em CONSTANT)**

- [ ] Cada pose-chave passa no teste de silhueta preta a 64 px (razão de recorte ≥ 0,35 nas poses de ação).
- [ ] Linha de ação em C ou S nas poses-chave; nenhuma pose "manequim" reta.
- [ ] Sem gêmeos: lados espelhados diferem ≥ 10°.
- [ ] Centro de massa coerente com o apoio (§4.11).
- [ ] Pose de contato com o membro ativo além do real (exagero de 20 a 40%).
- [ ] Antecipação existe e aponta para o lado oposto (herói curta, inimigo longa com hold vivo).

**C. Timing e espaçamento**

- [ ] Números dentro da tabela §5.1 (ou desvio justificado na ficha).
- [ ] Espaçamento assimétrico: chegada ao contato rápida (60 a 80% do deslocamento nos últimos 2 a 3 quadros), saída com slow out.
- [ ] Pelo menos um hold ou moving hold onde a leitura importa (contato, ápice, carga).
- [ ] Nenhuma interpolação linear em rotação de membro fora de contato/smear.
- [ ] Gráfico de espaçamento não é uma curva simétrica igual em todas as chaves (sinal de "ease in/out automático em tudo").

**D. Arcos e sobreposição**

- [ ] Trajetória da ponta da arma/mão é curva (desvio ≥ 10% da corda).
- [ ] Cadeias defasadas 1 a 2 quadros por elo; partes soltas em mola ou com 2 a 4 quadros de atraso.
- [ ] Overshoot de 5 a 15% no último elo e assentamento sem tremedeira infinita (para em ≤ 20 quadros).

**E. Contato com o mundo**

- [ ] Pé apoiado desliza < 1 cm por quadro (ou < 0,5 px em sprite) enquanto planta.
- [ ] Root motion bate com o deslocamento declarado na ficha (± 5%).
- [ ] Em locomoção, velocidade do clipe sincronizada com a velocidade real (sem "patinar").

**F. Transições e jogo**

- [ ] Primeiro quadro visivelmente diferente em ≤ 2 quadros do input (≤ 4 para ataques).
- [ ] Toda pose da recuperação blenda para guarda e esquiva sem salto > 25° num osso em 1 quadro.
- [ ] Crossfades entre 3 e 10 quadros; nada de 0,2 s padrão em tudo.
- [ ] Eventos vêm da trilha (método/marcador), não de constantes no código.
- [ ] Import no Godot com `animation/fps = 60`; clipes stepped exportados com chaves `CONSTANT`.

**G. Impacto**

- [ ] Hit-stop pela fórmula §6.4, local em co-op.
- [ ] Flash de impacto ≤ 92% de valor, 2 quadros.
- [ ] Alvo treme na horizontal (chão) ou vertical (ar), amplitude decrescente.
- [ ] Smear de 1 quadro (2 no pesado) ou trilha; nunca smear visível parado.
- [ ] Knockback desacelera; pose de dano chega em ~4 quadros.
- [ ] Tremor de câmera só a partir de golpes pesados; trauma ao quadrado; chute direcional preferido.

**H. VFX**

- [ ] Três fases com proporções §10.2; curvas não lineares.
- [ ] Nada em 0% ou 100% de valor; clímax é o único momento de saturação máxima.
- [ ] Hierarquia de perigo respeitada (cores e formas de inimigo reservadas).
- [ ] Forma + movimento + cor distintos por elemento.
- [ ] Dissipação some antes de 1 s (exceto permanência deliberada no chão).
- [ ] Lê em escala de cinza (teste de valor) e com 4 jogadores na tela.

**I. Estilo e personalidade**

- [ ] Coerência de taxa de pose com o personagem.
- [ ] Pelo menos uma "assinatura" visível (jeito de girar a arma, postura, floreio).
- [ ] Idle com moving hold e variação (2 a 3 variações raras a cada 8 a 15 s).

---

## 15. (ii) Rubrica 0 a 5 para avaliar animação ou VFX olhando quadros

**Material que o agente gera para avaliar:** (a) folha de contato com todos os quadros numerados na câmera do jogo; (b) a mesma folha em silhueta preta; (c) folha em escala de cinza; (d) traço da trajetória de 2 a 3 pontos (ponta da arma, mão, pé, cabeça) sobreposto à pose-chave; (e) gráfico de espaçamento (deslocamento por quadro) desses pontos; (f) GIF a 60 fps e a 15 fps; (g) para VFX: gráfico de valor médio, saturação e área coberta por quadro.

Descritores: 0 = ausente ou quebrado; 1 = presente mas errado; 3 = correto e funcional; 5 = excelente, referência de estilo. 2 e 4 são intermediários.

### 15.1 Animação de personagem

| # | Critério | 0 | 1 | 3 | 5 | Como medir |
|---|---|---|---|---|---|---|
| 1 | **Pose e silhueta** | Silhueta não diz a ação | Ação lê só em uma pose | Todas as poses-chave leem em silhueta | Silhueta legível a 48 px, linha de ação clara, sem gêmeos | (b); razão de recorte; diferença de lados |
| 2 | **Timing (contraste)** | Velocidade uniforme | Tem extremos mas sem contraste | Golpe rápido, recuperação mais lenta, dentro da tabela §5.1 | Ritmo memorável: rápido/lento/hold com intenção clara | (e): variância do espaçamento; contagem de quadros |
| 3 | **Espaçamento / easing** | Linear | Ease in/out idêntico em tudo | Assimetria correta (chegada dura, saída suave) | Cada chave com curva própria; impacto "estala" | (e): forma da curva perto do contato |
| 4 | **Antecipação / telegrafia** | Nenhuma | Existe mas no sentido errado ou longa demais no herói | Herói curta, inimigo com 24+ quadros e hold vivo | Inimigo lido sem som e sem VFX, só pela pose | (a), contagem; teste de leitura cega |
| 5 | **Arcos** | Retas | Arcos quebrados (bicos) | Arcos limpos nos membros principais | Arcos limpos em todos os pontos rastreados, VFX segue o arco | (d) |
| 6 | **Sobreposição / follow-through** | Tudo para junto | Defasagem aleatória | Cadeias defasadas, partes soltas assentam | Overlap com peso e personalidade, sem tremedeira | (a), (d); quadro em que cada elo para |
| 7 | **Peso e contato** | Flutua, pé desliza | Peso só no impacto | Quadril cai, pés plantados, root motion coerente | Massa sentida em todo o clipe (anticipação, impacto, recuperação) | deslizamento do pé por quadro; curva do quadril |
| 8 | **Squash / exagero** | Rígido ou deformado sem volume | Exagero em lugar errado | Exagero onde importa, volume preservado | Exagero dá estilo sem quebrar o modelo | escala por eixo; volume |
| 9 | **Responsividade** | > 8 quadros até reagir | 5 a 8 | ≤ 4 (ataque), ≤ 2 (movimento) | Reação no quadro seguinte, mesmo com pose forte | log de input × quadros |
| 10 | **Transições** | Estalos | Blend visível (mush) | Blends curtos e limpos | Encadeamentos parecem uma animação só | salto angular máx./quadro na transição |
| 11 | **Impacto** | Nada acontece no contato | Só número de dano | Hit-stop + reação + VFX sincronizados | Pacote §6.6 completo, sente-se o golpe de olhos fechados (som) | quadro do contato vs. eventos |
| 12 | **Personalidade / apelo** | Genérico | Neutro | Coerente com o personagem | Assinatura reconhecível só pela animação | comparação lado a lado com outro herói |
| 13 | **Coerência de estilo** | Mistura taxas sem critério | Taxa única mas fora do estilo | Taxa de pose conforme a ficha | Taxa variando por trecho a serviço da leitura (1s no contato) | (f) a 15 fps vs. 60 fps |

**Aprovação [proposta]:** média ≥ 3,5 e nenhum critério abaixo de 3 nos itens 1, 4, 7, 9 e 11 (os de jogabilidade).

### 15.2 VFX

| # | Critério | 0 | 1 | 3 | 5 | Como medir |
|---|---|---|---|---|---|---|
| 1 | **Fases** (antecipação/clímax/dissipação) | Aparece e some | Duas fases | Três fases com proporções §10.2 | Fases com curvas próprias, clímax "estala" | (g) valor por quadro |
| 2 | **Hierarquia de valor** | Branco puro / preto puro | Valor alto o tempo todo | Pico só no clímax, ≤ 92% | Valor guia o olho para o ponto de perigo/impacto | (c), histograma |
| 3 | **Saturação e cor** | Arco-íris ou cor de perigo errada | Saturação uniforme | Saturação máxima só no clímax, cores reservadas respeitadas | Paleta do elemento inconfundível e coerente com o mundo | (g) |
| 4 | **Forma** | Ruído sem forma | Forma genérica (bola, anel) | Forma lê em silhueta e indica direção | Forma com estilo próprio (corte, grafismo do mundo) | (b) |
| 5 | **Movimento** | Linear | Movimento único | Aceleração/desaceleração, direção clara | Movimento com antecipação e follow-through próprios | (e) do centroide |
| 6 | **Legibilidade em co-op** | Esconde inimigos ou telegrafias | Atrapalha às vezes | Não cobre telegrafias, some rápido | Lê com 4 jogadores e 20 inimigos | captura de cena cheia |
| 7 | **Sincronia** | Fora do quadro do impacto | ±3 quadros | No quadro do evento | Sincronizado com som e hit-stop | eventos vs. quadros |
| 8 | **Limpeza da dissipação** | Fica sujando a tela | Some com corte | Dissipa com baixa opacidade < 1 s | Dissipa deixando permanência intencional | área coberta por quadro |
| 9 | **Custo** | Derruba o fps | Acima do orçamento | Dentro do orçamento (overdraw, partículas) | Barato e funciona igual no Compatibility | contagem de partículas, tempo de GPU |

---

## 16. (iii) Lista mínima de animações

Durações a 60 fps [proposta]. "C" = cancelável a partir do quadro indicado. Princípios entre parênteses.

### 16.1 Herói (por arquétipo; armas diferentes trocam o bloco de combate)

| # | Animação | Quadros | Notas de princípio |
|---|---|---|---|
| 1 | Idle de exploração (loop) | 180 a 240 | Moving hold, respiração 1 a 2%, S suave, assimetria (secundária, apelo) |
| 2 | Idle de combate (loop) | 90 a 120 | Guarda baixa, peso nos dois pés, pequena oscilação; base para blends de golpe |
| 3 | 2 variações raras de idle | 120 a 240 cada | Personalidade; tocam a cada 8 a 15 s parado |
| 4 | Andar (loop) | 50 a 60 | Quadril cai na descida, braços em oposição atrasados 1 a 2 quadros (arcos, overlap) |
| 5 | Correr (loop) | 30 a 36 | Tronco 5 a 12° à frente, voo curto; inclinação lateral procedural (exagero, timing) |
| 6 | Arranque | 8 a 12 | Antecipação mínima (1 a 2 quadros), inclinação forte; C: 1 |
| 7 | Parada | 12 a 18 | Overshoot do tronco 5 a 10%, pé de freio; C: 4 (follow-through) |
| 8 | Virada de 180° em corrida | 10 a 14 | Pode ser procedural (giro + inclinação) se o estilo permitir |
| 9 | Esquiva / rolamento | 20 a 30 | Invulnerável 8 a 14; esticamento 1,2 a 1,4 nos 2 primeiros quadros, squash na saída; C ataque: 12 a 16 |
| 10 | Golpe leve 1, 2, 3 (combo) | 18 a 26, 18 a 26, 30 a 45 | Fim de cada um é a antecipação do próximo; smear 1 quadro; finalizador com hold no contato |
| 11 | Golpe pesado: início de carga, loop de carga, liberação | 10 + loop 30 + 30 a 40 | Hold vivo na carga (tremor 1 a 2°, brilho crescendo), liberação com smear e hit-stop 10 a 14 |
| 12 | Golpe em corrida (dash attack) | 24 a 32 | Root motion 1,5 a 2,5 m; esticamento; follow-through longo |
| 13 | Feitiço projétil (parte superior, aditivo/filtrado) | 14 a 22 | Funciona andando (filtro tronco+braços); recuo do braço 1 a 2 quadros após o spawn |
| 14 | Feitiço de canal (início, loop, fim) | 8 + loop 30 a 60 + 12 | Raio/jato contínuo; loop com tremor de esforço; fim com recuo (estilo Magicka) |
| 15 | Feitiço de área (golpe no chão) | 30 a 45 | Antecipação 10 a 16 com subida do corpo; contato com squash 0,75; VFX sincronizado |
| 16 | Escudo/guarda (início, loop, impacto no escudo, fim) | 6 + loop + 10 + 8 | Impacto no escudo com empurrão e hit-stop 3 a 4 |
| 17 | Reação leve (aditiva) | 10 a 16 | Flinch aditivo por cima de qualquer ação; não interrompe ataque (hyperarmor visual) |
| 18 | Reação pesada / derrubada | 40 a 60 | Knockback com root motion, hold no chão 6 a 10 |
| 19 | Levantar | 30 a 40 | C esquiva: 12; invulnerável nos primeiros 10 |
| 20 | Caído/aguardando resgate (loop) | 90 a 120 | Estado de co-op essencial: pose legível de longe, gesto pedindo ajuda |
| 21 | Reviver colega (início, loop, fim) | 10 + loop 60 + 20 | Interação de co-op; a ação mais "de equipe" do jogo; ver também ser revivido |
| 22 | Ser revivido (levantar com ajuda) | 30 a 45 | Pode compartilhar timing com o 21 |
| 23 | Morte definitiva | 45 a 75 | Hold final; dissolução de VFX |
| 24 | Pulo / queda / aterrissagem (se houver verticalidade) | 8 + loop + 10 a 16 | Ápice com hold 4 a 8; aterrissagem squash 0,8 a 0,85 |
| 25 | Interagir / pegar item | 18 a 30 | Curto, cancelável |
| 26 | Usar poção / consumível | 30 a 45 | Vulnerável de propósito (risco), andar lento |
| 27 | Emotes de comunicação: apontar, acenar, comemorar | 40 a 90 cada | Co-op: comunicação sem voz; aditivo de tronco quando possível |
| 28 | Entrada (spawn) e vitória | 60 a 120 cada | Apelo, assinatura do personagem |
| Camadas procedurais | Olhar (`LookAtModifier3D`), molas (`SpringBoneSimulator3D`), inclinação, squash, respiração aditiva, IK de pé (4.6+) | — | Substituem dezenas de clipes (Elegance) |

Total: cerca de 35 a 40 clipes por herói + camadas procedurais.

### 16.2 Inimigo comum de corpo a corpo

| # | Animação | Quadros | Notas de princípio |
|---|---|---|---|
| 1 | Idle (loop) | 90 a 150 | Silhueta característica do tipo; respiração exagerada |
| 2 | Patrulha/andar (loop) | 40 a 60 | Ritmo diferente do herói (mais pesado ou mais nervoso) |
| 3 | Alerta / notar o jogador | 20 a 30 | **Crucial para leitura**: hold de 6 a 10 quadros + sinal visual; vira a cabeça antes do corpo (overlap) |
| 4 | Perseguir/correr (loop) | 20 a 36 | Inclinação forte, sem disputar a atenção do golpe |
| 5 | Ataque principal | antecipação 24 a 36 + ativo 3 a 6 + recuperação 24 a 40 | Antecipação com hold vivo e flash nos últimos 6 a 10 quadros; recuperação **visivelmente vulnerável** (pose aberta, cabeça baixa) |
| 6 | Ataque secundário (variação de ritmo) | antecipação 16 a 22 | Mesmo sinal de pose do principal com som diferente, para não virar adivinhação |
| 7 | Reação leve (aditiva) | 10 a 14 | Tremor horizontal no hit-stop, não cancela ataque se tiver armadura |
| 8 | Atordoamento / stagger | 40 a 60 | Recompensa o jogador: pose cômica ou caída, estrelas, janela de dano |
| 9 | Knockback / derrubada + levantar | 30 a 45 + 30 a 40 | Root motion; peso |
| 10 | Morte | 30 a 60 | Exagero; hold de 6 a 10 no ápice; dissolução 20 a 30; permanência opcional |
| 11 | Spawn | 30 a 60 | Telegrafa de onde vem, invulnerável durante |
| 12 | Provocação/inativo agressivo | 60 a 90 | Dá ritmo e leitura de personalidade ao grupo |

**Inimigo à distância:** trocar 5 por mirar (30 a 45, com linha ou laser de mira visível) + disparar (1 ativo) + recuar (20 a 30). **Elite:** + 1 ataque de área com marcação no chão (45 a 60 de antecipação) e + armadura visual (sem reação leve, só brilho). **Chefe:** 4 a 8 ataques com telegrafias de assinaturas distintas (pose + som + marcação), transição de fase (90 a 180, invulnerável), atordoamento longo (120 a 180), morte com "boss stop" (30 a 40 de congelamento + 60 a 120 de câmera lenta).

---

## 17. (iv) Erros que denunciam animação amadora ou gerada sem critério

| # | Erro | Como aparece nos quadros | Correção |
|---|---|---|---|
| 1 | **Ease in/out automático em todas as chaves** | Gráfico de espaçamento idêntico e simétrico em todo trecho; tudo "flutua" | Alças por chave, chegada dura nos contatos (§4.6) |
| 2 | **Todos os ossos começam e param juntos** | Corpo move como bloco; cabelo e capa param com o tronco | Defasagem 1 a 2 quadros por elo + molas (§4.5) |
| 3 | **Interpolação linear em rotação** | Movimento robótico, arcos com bicos | Bezier/curvas, traço de trajetória |
| 4 | **Gêmeos (twinning)** | Braços/pernas espelhados no idle e na corrida | Ruído assimétrico 3 a 8°, poses diferentes por lado |
| 5 | **Pose "manequim"** | Linha vertical reta, braços colados ao corpo | Linha de ação C/S, braços fora da silhueta |
| 6 | **Pé deslizando** | Pé "patina" enquanto planta; velocidade do clipe ≠ velocidade real | Sincronizar passada, IK, root motion |
| 7 | **Antecipação longa no herói** | Botão aperta e nada acontece por 10+ quadros | Começar carregado, antecipação de 1 a 3 quadros (§4.2) |
| 8 | **Inimigo sem telegrafia legível** | Ataque sai em < 20 quadros sem pose de aviso; ou aviso só por VFX | 24 a 36 quadros com hold e pose distinta (§5.1) |
| 9 | **Crossfade longo padrão em tudo** | "Mush": poses borradas entre estados, golpe perde o contato | 3 a 10 quadros por transição, cortes secos onde o estilo pede |
| 10 | **Sem hold** | Nunca há uma pose para o olho descansar; tudo se move o tempo todo | Holds no contato, ápice e carga |
| 11 | **Idle com ruído demais ou parado demais** | Personagem "tremendo" ou estátua | Moving hold com respiração lenta (§5.4) |
| 12 | **Hit sem reação** | Golpe atravessa o inimigo sem hit-stop, sem flinch | Pacote de impacto §6.6 |
| 13 | **Tremor de tela em todo golpe** | Câmera sacudindo o tempo todo; náusea em co-op | Só pesados, trauma², chute direcional |
| 14 | **Hit-stop global em co-op** | O jogo inteiro engasga quando qualquer um bate | Hit-stop local por entidade |
| 15 | **Smear que fica na tela** | Forma esticada visível em 3+ quadros ou parado | 1 quadro, 2 no pesado |
| 16 | **Squash sem preservar volume** | Personagem encolhe ou incha no impacto | `1/√s` (3D) ou `1/s` (2D) |
| 17 | **VFX branco puro e saturado o tempo todo** | Tela "estourada", telegrafias somem | Valor ≤ 92% no clímax, hierarquia §10 |
| 18 | **VFX com fade linear** | Efeito some como slide de apresentação | Dissipação exponencial com queda de saturação |
| 19 | **Dissipação longa** | Fumaça e brilho cobrindo inimigos por segundos | < 1 s, baixa opacidade |
| 20 | **Pose que estala ao blendar** | Osso salta > 25° num quadro na transição | Poses de saída compatíveis, verificação automática |
| 21 | **Root motion e física discordando** | Personagem anda de um jeito e desliza de outro; atravessa paredes | Uma fonte de verdade por tipo de ação (§5.5) |
| 22 | **Taxas de pose misturadas sem critério** | Um membro em 2s, outro em 1s, câmera em degrau | Ficha de taxa por trecho; câmera sempre a 60 |
| 23 | **Import a 30 fps** | Quadro de impacto e smear somem no jogo, existem no Blender | `animation/fps = 60` (§7.3) |
| 24 | **Escala não uniforme na raiz com molas** | Cabelo e capa explodem ou derivam | Squash em nó visual, não no esqueleto (doc do `SpringBoneSimulator3D`) |
| 25 | **Mesma animação em todos os inimigos do grupo, em fase** | 5 inimigos respirando e andando sincronizados | Fase aleatória (offset de tempo), velocidade ±5 a 10%, variações |
| 26 | **Exagero fora de lugar** | Squash em armadura rígida, overshoot em objeto pesado | Exagero proporcional ao material e ao peso |
| 27 | **Cabeça sem vida** | Cabeça fixa enquanto corpo gira; olhar não segue alvo | `LookAtModifier3D` com atraso de 3 a 6 quadros |
| 28 | **Animação "de banco" genérica** | Movimento que não diz nada sobre o personagem | Assinaturas (§4.12) |

---

## 18. O que ficou sem verificar

- Texto integral de: Cooper (Game Anim, cap. 3 e 4), artigo de Vasseur sobre Dead Cells, PDF do guia de VFX da Riot, handout de Motomura (Guilty Gear Xrd), transcrições dos vídeos de Sakurai, palestras de Nijman, Eiserloh e Gibson. Os hosts `gamedeveloper.com`, `nexus.leagueoflegends.com`, `amara.org` e similares não resolvem neste ambiente; foi tudo lido por resumo de busca. Liberar esses hosts permitiria conferir citações e números.
- Contagens oficiais de quadros de Hades, Hollow Knight e Dead Cells: só há planilhas de fãs ou nada.
- Durações exatas do *Animator's Survival Kit* para corrida (fontes secundárias confundem passo com ciclo).
- Comportamento exato do `AnimationNodeAdd2` (delta em relação ao `RESET` ou ao primeiro quadro) no Godot 4.5.
- Se `SpringBoneSimulator3D` pode ser quantizado em 2s junto com o personagem stepped.
- Se o plugin C# de squash and stretch exporta para Web no Godot 4.5 (a hipótese é que não).
- Números de câmera de Eiserloh e o significado de `r < 0` como antecipação no modelo de t3ssel8r (de memória).
- Todas as tabelas marcadas **[proposta]** são pontos de partida para ajuste jogando, não números publicados.

---

## 19. Fontes principais

- Cooper, *Game Anim*: https://www.routledge.com/Game-Anim-Video-Game-Animation-Explained/Cooper/p/book/9780367707651 ; excerto: https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games ; resumo dos 5 fundamentos: https://yufeizheng.myblog.arts.ac.uk/2021/10/24/thesis-research-week-3-the-five-fundamentals-of-game-animation/
- Totten, 12 princípios para jogos: https://www.gamedeveloper.com/game-platforms/12-principles-for-game-animation
- Sakurai: https://nintendowire.com/news/2022/12/12/this-week-in-sakurai-12-5-12-11-fine-tuning-hit-stop-and-cheating-the-system/ ; https://www.gonintendo.com/contents/13757-sakurai-details-the-process-of-making-snappy-attack-animations ; https://www.gonintendo.com/contents/11218-masahiro-sakurai-s-latest-video-details-over-exaggeration-in-animation ; https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/ ; https://tvtropes.org/pmwiki/pmwiki.php/WebVideo/MasahiroSakuraiOnCreatingGames
- Hitlag do Smash: https://www.ssbwiki.com/Hitlag ; https://kuroganehammer.com/Smash4/Formulas
- Dead Cells: https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i- ; https://www.gameanim.com/2018/01/31/dead-cells-3d-pipeline-2d-animation/ ; https://habr.com/post/416589 ; https://www.nintendolife.com/news/2018/05/feature_reanimating_the_roguelike_with_dead_cells_developer_motiontwin
- Riot VFX: https://nexus.leagueoflegends.com/en-us/2017/10/dev-leagues-vfx-style-guide/ ; https://www.vfxapprentice.com/blog/10-league-of-legends-vfx-design-tips ; https://80.lv/articles/vfx-staples-shape-color-and-motion/ ; https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/
- Overwatch: https://kotaku.com/this-is-not-an-overwatch-glitch-1777612546 ; https://80.lv/articles/david-gibson-animating-mei-in-overwatch ; tese de smear: https://theses.fh-hagenberg.at/index.php/system/files/pdf/Lendenfeld18.pdf
- Skullgirls (Cartwright, GDC 2014): https://gdcvault.com/play/1020575/Animation-Bootcamp-Fluid-and-Powerful ; https://80.lv/articles/tips-on-making-fluid-and-powerful-animations
- Dark Souls 3, anatomia do ataque: https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3
- Guilty Gear Xrd: https://www.ggxrd.com/Motomura_Junya_GuiltyGearXrd.pdf ; https://gdcvault.com/play/1022031/GuiltyGearXrd-s-Art-Style-The
- Spider-Verse: https://www.awn.com/animationworld/creating-stylized-universe-sonys-spider-man-spider-verse ; https://www.cgspectrum.com/blog/spider-man-into-the-spider-verse-how-they-got-that-mind-blowing-look
- South of Midnight: https://www.engadget.com/gaming/xbox/south-of-midnight-preview-stopped-motion-160003119.html ; https://blog.siggraph.org/2026/04/stop-motion-southern-gothic-and-games-the-visual-language-of-south-of-midnight.html/
- Hi-Fi Rush: https://www.unrealengine.com/developer-interviews/hi-fi-rush-was-inspired-by-shaun-of-the-dead-and-futurama
- Swink: https://arxiv.org/pdf/2011.09201 ; https://puccjogos.github.io/balanceamento-2017-1s/materiais/GameFeel_Chap1.pdf
- Vlambeer: https://gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games ; https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects
- Reação humana: https://www.blurbusters.com/human-reflex-part1-input-lag-and-the-limits-of-human-reaction-time
- Lean procedural: https://docs.vulkan.org/tutorial/latest/Advanced_glTF/Procedural_Animation_IK/06_physics_driven_lean.html
- Molas de 2ª ordem: https://hackaday.com/2022/06/30/a-math-based-personality-for-games
- Moving hold: https://animationmentor.com/blog/why-all-animators-need-to-master-the-moving-hold
- Ciclos: https://animation.monmouth.edu/instruct/?p=351
- Godot (referência de classes, GitHub): https://github.com/godotengine/godot/blob/4.5-stable/doc/classes/SpringBoneSimulator3D.xml ; https://github.com/godotengine/godot/blob/4.5-stable/doc/classes/LookAtModifier3D.xml ; https://github.com/godotengine/godot/blob/4.5-stable/doc/classes/ResourceImporterScene.xml ; https://github.com/godotengine/godot/blob/4.5-stable/modules/gltf/gltf_document.cpp ; https://github.com/godotengine/godot/blob/4.6-stable/doc/classes/TwoBoneIK3D.xml
- Hit-stop no Godot: https://forum.godotengine.org/t/tutorial-hit-stop-and-screen-shake-in-godot-4-autoload-trauma-camera-mit/145240
- Relatórios irmãos neste repositório: `docs/pesquisa/godot-render-vfx.md` (VFX no Compatibility, hit-stop em co-op, rastro por malha), `docs/pesquisa/direcao-de-arte.md` (direção "teatro de cordel"), `docs/pesquisa/addons-godot.md`.

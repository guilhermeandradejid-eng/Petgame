# Co-op local e online no Godot 4: Web, celular, IA parceira e dificuldade

Pesquisa feita em 27/11/2026 para o RPG de ação cooperativo (projeto-coop). Etapa só de pesquisa: nada aqui é decisão de projeto.

**Método e marcações**
- Cerca de 45 buscas na web (inglês e português). Nesta sessão o `WebFetch` só alcança o GitHub; o resto das páginas foi lido **pelos trechos que o buscador devolve**. A documentação oficial do Godot foi lida na íntegra a partir do repositório `godotengine/godot-docs` no GitHub (mesmo texto de docs.godotengine.org).
- **[T]** = testado nesta sessão no container. **[R]** = lido no código ou README do repositório clonado. **[W]** = trecho de fonte web (URL ao lado ou na seção 12). **(nv)** = não verificado: conhecimento geral do gênero ou fonte fraca. Opinião está escrita como opinião.
- Testes em `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-coop-rede/` (`teste-enet/`, clones de `netfox/`, `tube/`, `gdsync/`, `demos/`).
- Complementa os relatórios vizinhos: `addons-godot.md` (matriz de versões dos addons; netfox, Tube, Beehave, Virtual Joystick já avaliados lá), `godot-render-vfx.md` (Compatibility na Web) e `jogos-referencia.md` (Magicka, Lost Castle etc.).

---

## 0. Resumo em 12 pontos

1. **Primeiro corte = co-op local + parceiros de IA, sem rede.** Isso funciona em todo lugar: desktop, GitHub Pages, celular e **dentro do artifact do Claude**, onde conexões externas são bloqueadas. O online entra numa segunda fase, por cima da mesma arquitetura.
2. **A arquitetura tem de nascer "pronta para rede" mesmo sem rede:** jogador identificado por `(peer_id, slot_local)`, entrada como dado (`PlayerInput` serializável), simulação de inimigos, projéteis e dano só no "host" (no local, o host é a própria máquina). Retrofit de rede num jogo local é a causa clássica de reescrita (nv, consenso do gênero).
3. **Entrada local:** o Godot não separa jogadores por dispositivo nas ações; é preciso um roteador próprio de dispositivos (cerca de 150 linhas) ou addon. Teclado e primeiro controle colidem no `device 0` [W]. Na Web, controle só aparece depois de apertar um botão e o mapeamento varia por navegador [R docs oficiais].
4. **Câmera compartilhada:** enquadrar o grupo com zoom até um limite; passou do limite, **parede invisível na borda da câmera** (estilo beat 'em up) + **teleporte do retardatário** após 2 a 3 s fora de quadro. Split-screen não combina com magia sistêmica de fogo amigo, que pede todos na mesma cena (avaliação).
5. **Online no Web só tem dois transportes:** WebSocket (cliente) e WebRTC [R docs oficiais]. Para o anfitrião rodar **no navegador**, só WebRTC serve, porque o navegador não abre porta de servidor. WebRTC exige sinalização externa.
6. **Sinalização grátis sem servidor próprio existe e já está empacotada:** o addon **Tube** (MIT) usa **trackers WebTorrent públicos** como sinalização e STUN do Google/Cloudflare, com código de sala compartilhado por WhatsApp/Discord [R]. É o caminho mais curto para um protótipo online no GitHub Pages. Defeitos: depende de trackers de terceiros e **não tem TURN**, portanto falha quando os dois lados estão atrás de NAT simétrico/CGNAT (comum em 4G) [R].
7. **Sinalização grátis própria e robusta:** Cloudflare Worker + Durable Object (plano grátis: 100.000 requisições/dia; mensagens WebSocket recebidas contam 20:1) [W] + **TURN da Cloudflare (1.000 GB/mês grátis)** [W]. Alternativa: o servidor de sinalização oficial em GDScript/Node (demo `webrtc_signaling`) numa VM grátis da Oracle (4 OCPU/24 GB, 10 TB/mês de saída) [W].
8. **Modelo de autoridade recomendado para PvE:** host autoritativo para inimigos, projéteis inimigos, dano, saque e RNG; **cada cliente é dono do movimento do próprio personagem** (predição trivial: aplica a própria entrada na hora), host valida velocidade e cooldowns. Rollback completo com netfox (MIT, v1.49.12) fica como opção para quando o "puxão" de correção incomodar; não é necessário para começar. Inimigos: interpolação de snapshots. Projéteis: **evento de nascimento + simulação determinística**, nunca posição por quadro.
9. **Testar com várias instâncias sem interface funciona aqui [T]:** 1 host + 3 clientes `--headless` em ENet, e 1+1 em WebSocket, conectaram em <1 s, 100 RPCs de ida e volta cada, RTT local 7 a 21 ms. WebRTC nativo (GDExtension `webrtc-native`) **não pôde ser testado**: carregar o binário baixado foi negado pela política da sessão.
10. **Hospedagem Web:** GitHub Pages comprime com gzip na hora (o `godot.wasm` de 38,0 MB vira ~9,35 MB) e não deixa definir COOP/COEP, portanto export **sem threads** [R docs]. itch.io **não comprime** na hora [R docs] (o jogador baixa os 38 MB), tem caixa experimental "SharedArrayBuffer support" [W] e está bloqueado no container (upload manual). No artifact do Claude cada arquivo binário tem teto de 15 MB: o Céu Arcano já resolveu isso partindo o wasm em 5 pedaços de 9,5 MB e remontando em JS (lido no artifact publicado).
11. **Celular:** direcional dinâmico à esquerda (o Godot **4.7 tem `VirtualJoystick` nativo**, com modos fixo, dinâmico e "following" [R docs 4.7]), botão de ataque grande à direita com **toque = mira automática, arrastar = mira manual** (o esquema do Brawl Stars [W]), habilidades em arco ao redor. Áudio só depois de um toque (o botão "Jogar" do Céu Arcano já faz isso). iPhone não tem Fullscreen API nem trava de orientação no Safari [W]: a saída é PWA "Adicionar à tela de início" + aviso "gire o aparelho".
12. **IA parceira e dificuldade:** parceiro no molde do Bosco (Deep Rock Galactic): aparece quando o jogador está sozinho, some quando entra gente, obedece a um "ping", corre para reviver [W]. Regra de ouro da Naughty Dog para a Ellie: o parceiro **nunca pode irritar nem atrapalhar** [W]. Behaviour tree em **Beehave** (GDScript puro, roda na Web); LimboAI é GDExtension e na Web exige template `dlink` e cabeçalhos de isolamento [R docs][W]. Dificuldade: escalar **quantidade** de inimigos mais que vida; referência real: Diablo III foi de 75/85/95/110% por jogador para +75% fixo por jogador extra [W]; Deep Rock Galactic (Hazard 5) usa multiplicador de quantidade 0,85/0,85/1,25/1,50 para 1 a 4 jogadores [W, revisão antiga do wiki].

---

## 1. Co-op local

### 1.1 O problema técnico da entrada

| Fato | Fonte |
|---|---|
| Ações do `InputMap` aceitam eventos de "todos os dispositivos"; não há conceito de "jogador". `Input.is_action_pressed("atacar")` mistura todos os controles. | docs oficiais (`controllers_gamepads_joysticks.rst`) [R] |
| Teclado usa `device 0`, o mesmo número do primeiro controle; os dois eventos disparam. | fórum Godot [W] https://forum.godotengine.org/t/help-local-multiplayer-device-conflict/128696 |
| Controle ligado depois do jogo abrir pode receber ID a partir de 2; não presuma números fixos. | issue [W] https://github.com/godotengine/godot/issues/59250 |
| Desde o 4.5 o desktop usa **SDL 3** para controles; Android e Web ainda usam código próprio, "menos confiável". | docs oficiais [R] |
| **Web:** "controles não são detectados até um botão ser apertado"; mapeamento pode vir errado conforme navegador/SO, e a Gamepad API não dá informação para corrigir. | docs oficiais (`exporting_for_web.rst`) [R] |
| `input_devices/joypads/ignore_joypad_on_unfocused_application` existe para não ler controle com a janela sem foco. | docs oficiais [R] |

**Addons conferidos (todos alcançáveis por `git ls-remote`):**

| Addon | Licença | O que faz | Uso aqui |
|---|---|---|---|
| [matjlars/godot-multiplayer-input](https://github.com/matjlars/godot-multiplayer-input) | MIT [R] | Duplica ações por dispositivo: teclado = device -1, controles 0..7 [W] | Referência de código; simples |
| [andinodev/Input-Multi-Device](https://github.com/andinodev/Input-Multi-Device) | MIT (2026, KingKode) [R] | Roteador "nativo" de entrada multi-dispositivo, remapeamento dinâmico [W] | Avaliar; listagem antiga mira 4.1 |
| G.U.I.D.E | ver `addons-godot.md` | Entrada unificada + toque + contextos | Já recomendado no relatório de addons |
| Rebind Kit / Godot Couch Party | não verificado (só na asset library, que é bloqueada daqui) | "Entra com o primeiro botão que apertar", teclado dividido sem tecla em comum [W] | Ideia de design, não baixável |

**Recomendação (avaliação):** roteador próprio, porque é pouco código e precisa casar com a rede depois.

```gdscript
# Autoload "Jogadores": um slot por jogador local. Dispositivo = (tipo, id).
# KB_A = WASD+JKL, KB_B = setas+numpad, PAD = joypad n, TOUCH = tela.
enum Tipo { KB_A, KB_B, PAD, TOUCH, BOT }
var slots := []            # [{tipo, device, cor, personagem, ativo}]
func _input(e: InputEvent) -> void:
	var disp := _dispositivo_de(e)          # devolve null para mouse-motion etc.
	if disp == null: return
	var s := _slot_de(disp)
	if s == null and _e_botao_de_entrar(e): # Start/A/Enter/toque em "Entrar"
		entrar(disp)                        # drop-in: cria slot e personagem
	elif s != null:
		s.entrada.alimentar(e)              # PlayerInput por slot, serializável
```

- Cada slot tem um `PlayerInput` (vetor de movimento, mira, botões, "fila de elementos") que é **o mesmo objeto** enviado pela rede depois. O personagem só lê `PlayerInput`, nunca `Input` global. O bot da IA também preenche um `PlayerInput`. Assim, local, online e IA usam o mesmo código de personagem (avaliação; é o padrão do netfox `BaseNetInput` [R]).
- Teclado dividido em dois jogadores funciona, mas teclados baratos têm *ghosting* com 3+ teclas (nv). Só um jogador de teclado pode usar mouse para mirar.

### 1.2 Entrar e sair a qualquer momento

| Situação | Comportamento sugerido |
|---|---|
| Entrar | Tela de jogo mostra "Aperte ⊕ para entrar" no canto vazio; o personagem nasce **perto do jogador 1**, com 1 s de invulnerabilidade e um efeito de chegada legível. Dificuldade reescala **no próximo encontro**, nunca no meio da luta. |
| Sair voluntário | Segurar Select/Back 2 s (evita saída acidental). O personagem vira IA (se o modo parceiro estiver ligado) ou some com efeito de partida. |
| Controle desconectou (`Input.joy_connection_changed`) | Pausa se for o único humano; senão o personagem vira IA e aparece "J2: reconecte o controle" no HUD dele. Ao reconectar, qualquer botão daquele dispositivo devolve o controle. |
| Quarto jogador entra com IA ocupando vaga | IA cede a vaga ao humano (como o Bosco, que some quando outro jogador entra [W]). |

### 1.3 Câmera compartilhada que enquadra o grupo

Fontes de padrão: devlog do Package Party (projeção da posição de cada jogador na tela para decidir zoom) [W] https://pandaqi.itch.io/package-party/devlog/105217/9-camera-kung-fu ; artigos "Shared, multi, split screen design" [W] https://gamedeveloper.com/design/shared-multi-split-screen-design e "Single camera system for four players" [W] https://gamedeveloper.com/programming/single-camera-system-for-four-players . Phantom Camera (modo GROUP com distância automática) já foi avaliado em `addons-godot.md`.

Algoritmo recomendado (câmera isométrica/top-down 3D ou HD-2D):
1. Alvo = média ponderada das posições (peso 1 para vivos, 0,3 para caídos, 0 para quem está teleportando), mais um *look-ahead* pequeno na direção média do movimento.
2. Zoom = o necessário para caber o AABB do grupo + margem de 15% em cada borda, limitado entre `zoom_min` (luta íntima) e `zoom_max` (legibilidade de telegráfos no celular). Suavizar com mola crítica (sem overshoot), zoom mais lento que translação.
3. **Leash:** passou do `zoom_max`, a borda da câmera vira parede para quem tenta sair (empurrão suave, não parada seca). Quem fica para trás é arrastado pela borda.
4. **Teleporte do retardatário:** se um jogador fica fora do quadro por mais de 2,5 s (caiu, ficou preso, lag), teleporta para o lado do jogador mais próximo do centro com efeito visual próprio. Evita impasse "dois jogadores puxando para lados opostos".
5. Indicador de borda (seta com a cor do jogador) para quem está parcialmente fora.
6. Inimigos grandes e telegráfos de chefe entram no enquadramento com peso baixo, para o ataque nunca vir de fora da tela (avaliação; legibilidade é requisito de arte).

Split-screen (incluindo o "Voronoi" dinâmico da série LEGO, nv) foi descartado como padrão: o gênero Magicka/Lost Castle é de tela compartilhada [ver `jogos-referencia.md`], e fogo amigo/combos entre jogadores exigem ver todo mundo.

### 1.4 HUD por jogador

- **No mundo:** anel colorido no chão sob cada personagem (cor + forma diferentes, por daltonismo), número do jogador, barra fina de vida acima da cabeça só quando abaixo de 100% ou em combate. A fila de elementos/feitiço do jogador fica **perto do personagem**, não no canto, porque em 4 jogadores ninguém olha o canto (avaliação).
- **Cantos da tela:** um cartão por jogador (retrato, vida, recurso, cooldowns) na cor dele; slot vazio mostra "⊕ entrar".
- **Caído:** círculo de reviver com tempo restante, visível para todos; botão contextual "Reviver" aparece para quem está perto.
- **Celular:** o HUD de toque é só do jogador 1; jogadores com controle conectado ao mesmo celular/tablet também funcionam (Gamepad API), mas isso não foi testado.

---

## 2. Online: a API de alto nível do Godot

### 2.1 Transportes

| Transporte (`MultiplayerPeer`) | Desktop | Web (navegador) | Host no navegador? | Observações |
|---|---|---|---|---|
| `ENetMultiplayerPeer` (UDP) | sim | **não** | não | Canais, confiável/não confiável. Melhor para desktop. noray (MIT) faz NAT punch/relay para ENet [R netfox docs]; **não serve na Web** |
| `WebSocketMultiplayerPeer` (TCP) | sim (cliente e servidor) | **só cliente** | não | Tudo é confiável e ordenado (bloqueio *head-of-line*). Serve para servidor dedicado ou relay |
| `WebRTCMultiplayerPeer` | só com GDExtension [webrtc-native](https://github.com/godotengine/webrtc-native) 1.2.2 (MIT + libdatachannel MPL-2.0 [R]; Godot 4.3+) | **embutido** | **sim** | Modos `create_server`, `create_client`, `create_mesh`. Canais de dados confiáveis e não confiáveis. Exige sinalização externa |

Fonte: docs oficiais `exporting_for_web.rst` ("só HTTP, WebSocket (cliente) e WebRTC são suportados") e `webrtc.rst` [R]. Crossplay Web ↔ desktop: só via WebRTC (desktop com `webrtc-native`).

Ferramentas da API: `@rpc("authority"|"any_peer", "call_local"|"call_remote", "reliable"|"unreliable"|"unreliable_ordered", canal)`, `set_multiplayer_authority()` por nó, `MultiplayerSpawner` e `MultiplayerSynchronizer` (intervalo de replicação, sincronização delta, filtros de visibilidade) [R docs]. A doc oficial recomenda, para jogo competitivo, mandar **intenção/entrada** ao servidor e validar, citando https://mas-bandwidth.com/choosing-the-right-network-model-for-your-multiplayer-game/ [R].

### 2.2 Topologia e autoridade para PvE cooperativo

**Topologia:** estrela com *listen server* (o host também joga). Em WebRTC, `create_server()` no host e `create_client(id)` nos outros; o servidor repassa mensagens entre clientes ("server relay", ligado por padrão) [T: no teste ENet com 3 clientes, cada cliente recebeu `peer_connected` dos outros dois via host].

**Quem manda em quê (recomendação):**

| Objeto | Autoridade | Como sincroniza | Frequência |
|---|---|---|---|
| Movimento do próprio personagem | **o cliente dono** (`set_multiplayer_authority(peer_id)`) | Estado (posição, velocidade, mira, estado de animação) `unreliable_ordered`; host valida velocidade máxima, colisão grosseira e cooldowns | 20 a 30 Hz |
| Entrada de ação (ataque, feitiço, esquiva) | cliente envia, **host decide efeito** | RPC confiável com `tick` de quando aconteceu | por evento |
| Inimigos (IA, posição, vida, animação) | host | Snapshot `unreliable_ordered` + interpolação nos clientes (render ~100 ms no passado) | 10 a 20 Hz |
| Ataques de inimigo (telegráfo) | host | **Evento confiável** "começou ataque X no tick T, alvo Y"; o cliente toca a antecipação inteira localmente, sincronizada pelo tick | por evento |
| Projéteis | host (os do jogador: cliente prevê o visual, host confirma) | **Evento de nascimento** `(id, tipo, origem, direção, velocidade, tick, semente)`; cada máquina simula a trajetória; host manda "acertou/morreu id" | por evento |
| Dano, morte, reviver, saque, RNG de drops | host | RPC confiável | por evento |
| Estados de elemento/status (molhado, em chamas) e combinações entre jogadores | host | Evento + campo no snapshot do alvo | por evento |
| VFX, partículas, tremor, hitstop | **local** (nunca sincronizar) | disparado pelos eventos acima | — |

Por que o cliente é dono do próprio movimento: em PvE cooperativo não há incentivo para trapacear contra o grupo, e isso elimina a sensação de atraso no próprio personagem sem custo de rollback. A doc do netfox descreve exatamente o trade-off ("clientes não são confiáveis" vs. latência mascarada por predição) [R `docs/netfox/concepts/authoritative-servers.md`]. Avaliação: para co-op entre amigos, confiança no cliente para o movimento é aceitável; dano e saque ficam no host.

**Acerto corpo a corpo do jogador:** o cliente toca hitstop/faíscas na hora (predição só visual) e manda "acertei inimigo E no tick T"; o host aceita se E estava a uma distância plausível no tick T (rebobina 1 a 2 snapshots do E) e aplica dano. Se recusar, o cliente só não vê a vida cair; não desfaz animação. Isso é "favorecer quem ataca", padrão em co-op (nv).

### 2.3 Rollback com netfox contra interpolação simples

| | Interpolação + dono do movimento (recomendado no início) | netfox `RollbackSynchronizer` (predição + reconciliação) |
|---|---|---|
| Sensação do próprio personagem | instantânea | instantânea |
| Correções visíveis | nenhuma no próprio personagem; outros chegam ~100 ms atrasados | "puxões" quando cliente e servidor discordam [R FAQ netfox] |
| Custo de CPU | baixo | re-simula até `history_limit` = 64 ticks; tickrate padrão 30 tps [R `netfox.gd`] → pior caso 2,1 s de ressimulação por correção. Pesado em WASM sem threads (avaliação) |
| Restrições de código | nenhuma especial | Toda lógica em `_rollback_tick()`; sincronizar tudo que ela lê; `move_and_slide()` precisa de `velocity *= NetworkTime.physics_factor`; `is_on_floor()` só atualiza após um `move_and_slide` extra; física de corpos rígidos não rebobina sem addon/fork [R `rollback-caveats.md`, `physics.md`] |
| Anti-trapaça | fraca | forte |
| Maturidade | API do Godot | netfox **v1.49.12** (MIT, push de 23/11/2026) [R]; a 1.49 reescreveu o núcleo (`addons-godot.md`); exemplos escritos para Godot 4.1 [R README] |

O netfox serve mesmo sem rollback: `NetworkTime` (relógio de tick comum), `StateSynchronizer`, `TickInterpolator` ("Record First State" útil para projéteis [R]), `NetworkSimulator` (latência e perda simuladas, só no editor) e `WindowTiler` [R]. Funciona com qualquer `MultiplayerPeer`, inclusive Web [R FAQ: "Does netfox support android / iOS / web? Yes"]. Exemplos no repositório: `rollback-npc`, `state-synchronizer-npc`, `forest-brawl` [R].

Recomendação: começar com **interpolação + dono do movimento**, usar `NetworkTime` e `TickInterpolator` do netfox para relógio e suavização, e só ligar `RollbackSynchronizer` nos personagens jogáveis se os testes com 150 ms mostrarem problema. Nunca rollback em inimigos ou projéteis (avaliação: o custo cresce com o número de entidades e o ganho em PvE é pequeno).

### 2.4 Banda estimada (conta, não medição)

4 jogadores, 25 inimigos na tela, snapshot de inimigo ~14 bytes (id 2 + posição 2D quantizada 4 + rotação 1 + vida 2 + estado/animação 2 + flags 1 + cabeçalho amortizado ~2) a 15 Hz: 25 × 14 × 15 ≈ **5,3 KB/s por cliente**; jogadores 3 × 20 B × 30 Hz ≈ 1,8 KB/s; eventos ~1 KB/s. Total ~8 KB/s de descida por cliente, ~24 KB/s de subida no host. Cabe folgado em 4G e em TURN grátis (seção 3.3).

### 2.5 Testar com várias instâncias sem interface no mesmo computador

| Método | Resultado aqui |
|---|---|
| `godot --headless --path . -- --role=server` + N × `-- --role=client` (argumentos após `--` lidos com `OS.get_cmdline_user_args()`) | **[T]** ENet: 1 host + 3 clientes conectados, 100 pings cada, RTT 13,7 a 20,7 ms. WebSocket: 1+1, RTT 6,8 ms. Script em `teste-enet/main.gd` |
| Editor: *Debug → Customize Run Instances* (N instâncias com argumentos próprios) | [W] https://forum.godotengine.org/t/can-the-editor-start-multiple-instances-of-the-game/103120 ; só com interface |
| netfox `NetworkSimulator` (autoconexão, latência ms, perda %) e `WindowTiler` | [R] só roda quando lançado do editor; tem variável de ambiente para desligar em CI |
| `tc netem` (Linux) / clumsy (Windows) para latência real | citados na doc do netfox [R]; `tc` exige privilégio de rede, não testado no container |
| WebRTC entre dois processos nativos (`webrtc-native`) | **não testado**: o carregamento do `.so` baixado foi negado pela política da sessão |
| Web real (dois Chrome headless com WebRTC em localhost) | não testado; viável com o pipeline de Chrome headless de `godot-render-vfx.md` (nv) |

**Teste automático sugerido:** host + 3 clientes headless, cada um com **bot** preenchendo o `PlayerInput` (o mesmo bot da IA parceira, seção 6), `--fixed-fps 30`, 2 minutos de luta; a cada 30 ticks o host envia um *hash* do estado de inimigos e cada cliente compara com o próprio estado interpolado (tolerância); falha se divergir por mais de 1 s, se algum RPC de dano chegar duas vezes ou se houver erro no log. Roda no container em CPU.

---

## 3. Web: WebRTC precisa de sinalização

### 3.1 O que é preciso

1. **Sinalização**: troca de SDP e candidatos ICE antes da conexão; depois pode ser desligada [R docs `webrtc.rst`].
2. **STUN** (descobre IP público): grátis e ilimitado em `stun.cloudflare.com:3478` [W Cloudflare FAQ] e `stun.l.google.com:19302` [R README do Tube].
3. **TURN** (relay quando não dá conexão direta): pago na maioria dos provedores. Dados públicos são velhos: em 2016, 12% das sessões WebRTC falhavam, 85% das falhas por NAT/firewall [W https://webrtchacks.com/usage-stats/]; fornecedor diz que 75 a 80% conectam direto com só STUN [W Metered]. Em rede móvel, o CGNAT se comporta como NAT simétrico [W]; no Brasil, relato de fórum diz que "todas as operadoras fazem CGNAT" [W https://noping.com/pt/blog/cgnat-no-brasil-para-jogos-nat-portas-chat-e-ping] (opinião de usuário, não dado oficial). **Conclusão: sem TURN, partidas celular-com-celular em 4G vão falhar com frequência (nv quanto à taxa).**

### 3.2 Opções GRATUITAS de sinalização e relay

| Opção | Como funciona | Limite grátis | Web? | O que o usuário precisa configurar | Avaliação |
|---|---|---|---|---|---|
| **Tube** [koopmyers/tube](https://github.com/koopmyers/tube) (MIT, commit 27/09/2026, testado pelo autor no Godot 4.7.2) [R] | Trackers **WebTorrent públicos** (`wss://tracker.webtorrent.dev`, `wss://tracker.openwebtorrent.com`, `wss://open.ftorrent.com`, `wss://tracker.androodev.com`) como sinalização; `TubeClient` configura `MultiplayerAPI` automaticamente; host cria sessão e passa o ID por canal externo; kick, recusar conexões; `TubeInspector` para depurar; sinalização por LAN no desktop (não na Web) | Sem cota; depende da boa vontade dos trackers. Sem TURN público ("não há TURN público confiável") [R] | **sim** | Nada (só um App ID de 15 caracteres). Opcional: tracker próprio (bittorrent-tracker/openwebtorrent-tracker) e TURN (coturn/eturnal) | **Melhor protótipo.** Zero infraestrutura. Erro "Invalid status code" quando um tracker cai; usar vários |
| **Cloudflare Worker + Durable Object** (código próprio, ~150 linhas JS portando o protocolo JSON do demo oficial) | WebSocket do navegador → Worker → um DO por sala repassa SDP/ICE | Workers grátis: 100.000 req/dia, 10 ms de CPU por invocação [W https://developers.cloudflare.com/workers/platform/limits/]; DO no plano grátis desde 07/04/2025, só SQLite, 100.000 req/dia, mensagens WS recebidas contam 1/20, enviadas não contam, 5 GB [W https://developers.cloudflare.com/durable-objects/platform/pricing/] | sim (o próprio jogo é cliente WS) | Conta Cloudflare grátis, `wrangler deploy`. **wrangler vem do npm; o deploy precisa de credencial Cloudflare e acesso a api.cloudflare.com, bloqueado no container** → o usuário faria o deploy | **Melhor opção própria.** Como sinalização sozinha, o limite é praticamente infinito para uso caseiro. Até como *relay* de jogo (sem WebRTC): 100.000 × 20 = 2 M mensagens/dia ÷ (4 jogadores × 30 msg/s) ≈ **4,6 h de partida a 4 por dia** (conta) |
| **TURN da Cloudflare (Realtime TURN)** | TURN gerenciado; credencial temporária gerada por API (pode ser no mesmo Worker) | **1.000 GB/mês grátis** (compartilhado com SFU), depois US$ 0,05/GB [W https://developers.cloudflare.com/realtime/turn/faq/] | sim | Conta Cloudflare, criar chave TURN | Com ~24 KB/s por partida no pior caso, 1.000 GB ≈ 11.500 h de partida relayada por mês (conta) |
| **Open Relay (Metered)** | TURN gerenciado + sinalização gerenciada | 20 GB/mês, exige conta/API key [W https://metered.ca/tools/openrelay/] | sim | Conta grátis | Plano B de TURN; ~230 h relayadas/mês (conta) |
| **Demo oficial `networking/webrtc_signaling`** em [godot-demo-projects](https://github.com/godotengine/godot-demo-projects) (MIT) | Servidor de sinalização em **GDScript** (`server/ws_webrtc_server.gd`, roda num Godot headless) ou **Node** (`server_node/`); protocolo JSON com lobby [R] | — | cliente sim | Hospedar o servidor em algum lugar (linhas abaixo) | Ponto de partida do código; base para portar para Worker |
| **Oracle Cloud Always Free** | VM ARM para o servidor de sinalização + coturn | 3.000 OCPU-h e 18.000 GB-h/mês (≈ 4 OCPU + 24 GB), 10 TB/mês de saída [W https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm] | — | Cartão no cadastro (nv), domínio + TLS (wss obrigatório em página https), abrir portas UDP | Mais controle; "out of capacity" frequente ao criar VM ARM [W] |
| **Render (free web service)** | Node/Godot de sinalização | Dorme após 15 min sem tráfego (inclui mensagens WS); 750 h/mês por workspace [W https://render.com/docs/free] | — | Conta, deploy do repo | Primeira conexão após dormir demora (nv: dezenas de segundos). Aceitável para sinalização |
| **Deno Deploy** | Worker em TypeScript com WebSocket | ~1 M req/mês; números de banda/CPU conflitantes entre fontes [W https://deno.com/deploy/pricing] | — | Conta | Não verificado em detalhe |
| **Supabase Realtime** (canal *broadcast* como sinalização; Trystero tem estratégia Supabase) | — | 200 conexões simultâneas, 100 msg/s, 2 M msg/mês [W https://supabase.com/docs/guides/realtime/limits] | sim (WS) | Projeto Supabase grátis; protocolo Phoenix sobre WS teria de ser implementado em GDScript (nv) | Possível, mais trabalho |
| **PeerJS Cloud** (`0.peerjs.com`) | Broker gratuito mantido por doações; sem SLA; IDs podem colidir [W https://peerjs.com/server/cloud] | sem número publicado | sim | Implementar o protocolo PeerJS em GDScript (nv) ou usar via JavaScriptBridge | Arriscado |
| **Nostr / MQTT públicos** (estratégias do [Trystero](https://github.com/dmotz/trystero), MIT, 0.27.0) | Relays públicos como sinalização; Nostr é o padrão do Trystero [W] | sem SLA | sim | Trystero é JS: integrar pelo `JavaScriptBridge` exigiria um `MultiplayerPeerExtension` próprio (nv) ou portar o protocolo para GDScript | Tube já resolve o mesmo problema em GDScript |
| **GD-Sync** [GD-Sync/GD-Sync](https://github.com/GD-Sync/GD-Sync) (plugin 1.0.2, licença de fonte estilo BSD com "All rights reserved" [R]) | Backend gerenciado: lobbies, replicação, contas, matchmaking, relay; na Web usa **túnel WSS** (`OS.has_feature("web")` → `wss://`) [R código] | **não verificado** (gd-sync.com não resolve nesta sessão; review de usuário diz que o grátis "dá para jogo pequeno com amigos" [W]) | sim [R] | Conta, chaves de API em arquivo próprio (o plugin avisa para não versionar) [R] | API própria (não é só `MultiplayerPeer`): aprisionamento. Bom para quem não quer infraestrutura |
| **W4 Cloud** (W4 Games) | Stack completa para Godot: auth, lobby, matchmaking, sinalização WebRTC + STUN [W]; versão inicial AGPLv3 para auto-hospedagem [W] | "Dev Tier" por convite/tempo limitado, segundo usuário do fórum [W] | sim (nv) | Conta ou auto-hospedagem | Não verificado; [W4GamesOrg/w4-godot-sdk] não foi achado no GitHub com esse nome |
| **Nakama** + [nakama-godot](https://github.com/heroiclabs/nakama-godot) (Apache-2.0, v3.4.0 [R]) | Servidor de jogo open source; *relayed multiplayer* por WebSocket (funciona na Web) (nv) | Auto-hospedagem grátis; Heroic Cloud é pago (nv) | sim | Docker numa VM (Oracle grátis) | Pesado para o escopo |
| **Playroom Kit** | SDK JS para Web; Godot via `JavaScriptBridge`; só export Web [W https://playroom-docs.vercel.app/usage/godot] | "freemium" (nv) | só Web | Conta | Aprisionamento + API própria |
| **GodotSteam** [GodotSteam/GodotSteam](https://github.com/GodotSteam/GodotSteam) (v4.24; MIT por conhecimento prévio, arquivo de licença não localizado no HEAD) | Lobbies + P2P relayado pela Valve (`SteamMultiplayerPeer`), com RPC [W https://brogolem35.github.io/rollback-with-godotsteam/] | Relay grátis, mas **publicar na Steam custa US$ 100 por jogo** (Steam Direct, nv) | **não** | App ID da Steam | Só para versão desktop/Steam futura |
| **Epic Online Services** [EOSG](https://github.com/3ddelano/epic-online-services-godot) (MIT) / [GD-EOS](https://github.com/Daylily-Zeleen/GD-EOS) (MIT) | P2P com relay, lobbies crossplay, `EOSGMultiplayerPeer` [W] | Registro no portal Epic grátis (nv: serviço grátis) | **não** (Windows, Linux, macOS, Android, iOS) [W] | Produto no Epic Dev Portal | Desktop/mobile nativo futuro |

**Pilha recomendada (avaliação):**
- Protótipo online (fase 2): **Tube** + STUN Google/Cloudflare. Zero servidor. Código de sala de 6 a 8 caracteres exibido grande, com botão "copiar link" (`?sala=XXXX`).
- Versão sólida (fase 3): **Worker + Durable Object** com o protocolo do demo oficial + **TURN Cloudflare** com credencial temporária emitida pelo Worker. Tudo grátis dentro das cotas; o usuário faz o deploy com a conta dele.

### 3.3 Dentro do artifact do Claude

- A página do artifact não abre conexões externas (fetch, XHR e WebSocket para outros hosts são bloqueados, conforme o contexto do projeto). **Online não funciona lá; só local e bots.** O jogo precisa detectar isso e esconder o botão "Online" (por exemplo, tentar o WebSocket do tracker com timeout de 3 s e mostrar "Online indisponível nesta página; jogue pelo link do GitHub Pages").
- Limites de arquivo do artifact (descrição da ferramenta): 15 MB por arquivo binário, 16 MB por texto, 64 MB por publicação, 255 arquivos. O `godot.wasm` 4.5.1 sem threads tem **38.034.280 bytes** [T, template instalado]. O Céu Arcano publicado contorna isso: `part0..part4.wasm` (4 × 9.500.000 + 34.280 bytes), remontados com `Blob` e entregues ao `Engine` por um `fetch` interceptado; o `.pck` é servido como `data.wasm` (7.983.648 bytes) [lido no artifact publicado, arquivo `index.html`]. O mesmo truque vale para o RPG; **o `.pck` também terá de ser partido se passar de 15 MB** (provável com modelos 3D e música).
- Controles USB/Bluetooth dentro do iframe: no Chrome a política `gamepad` tem *allowlist* padrão `*` (iframes de outra origem podem ler) [W https://groups.google.com/a/chromium.org/g/blink-dev/c/B1QUuICApvc]; Firefox chegou a usar `self` [W]. Não testado no artifact.

---

## 4. Hospedagem do build Web

| Destino | Limites | Cabeçalhos COOP/COEP | Compressão | Como publicar daqui | Avaliação |
|---|---|---|---|---|---|
| **GitHub Pages** | site publicado ≤ 1 GB; banda "soft" 100 GB/mês; 10 builds/h (não vale para Actions) [W https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits]; arquivo ≤ 100 MB pelo limite de push do Git (nv para Pages especificamente) | **não configuráveis** [W https://github.com/orgs/community/discussions/13309] → export **sem threads e sem GDExtension** | **gzip na hora** [R docs] → wasm 38,0 MB vira ~9,35 MB (o zip do template dá 9.350.048 bytes [T]) | `git push` funciona do container | **Destino principal.** ~100 GB/mês ≈ 5.000 primeiras visitas de ~20 MB (conta) |
| **itch.io** | zip ≤ 500 MB, ≤ 1.000 arquivos, arquivo ≤ 200 MB (relatos do fórum citando a doc) [W https://itch.io/t/144349/html5-files-limits-are-bugging-me] | caixa experimental "SharedArrayBuffer support" em *Embed Options* adiciona COOP `same-origin` + COEP `credentialless`; pode quebrar partes da página; Safari não totalmente [W https://itch.io/t/2025776/experimental-sharedarraybuffer-support] | **nenhuma na hora** [R docs] → o jogador baixa os 38 MB do wasm inteiros | **itch.io é bloqueado no container**: upload manual pelo usuário (site ou `butler` na máquina dele) | Vitrine e comunidade; download 4× maior que no Pages |
| **Artifact do Claude** | ver 3.3 | não | não verificado | ferramenta Artifact | Só local/bots; bom para testar no celular rápido |
| **PWA** (opção do export) | — | **"Ensure/Enable Cross Origin Isolation Headers"** injeta COOP/COEP via service worker, permitindo threads em qualquer host [R docs] | — | — | Ícones, `display`, orientação no manifesto; joga offline depois da 1ª carga; cache pode ser despejado pelo navegador; página "offline" configurável [R docs] |

Notas:
- **Sem threads é o padrão certo** para Pages/itch/artifact: "mais compatível com itch.io, Poki, CrazyGames" e "funciona muito bem no macOS e iOS" [R docs]. Custo: sem `Thread`, e áudio pode estalar com FPS baixo [W https://godotengine.org/article/progress-report-web-export-in-4-3/].
- Threads ou GDExtension na Web exigem cabeçalhos de isolamento [R docs]. No Pages, só com service worker (opção PWA ou [nisovin/godot-coi-serviceworker](https://github.com/nisovin/godot-coi-serviceworker), MIT, v1.2 [R]), que recarrega a página na 1ª visita [W]. Não vale o risco no primeiro corte.
- **Modo de áudio "Sample" (padrão na Web desde 4.3):** sem AudioEffects, **sem reverb/doppler**, **sem geração procedural de áudio**, áudio posicional pode falhar [R docs]. Consequência para o pipeline: o áudio sintetizado em Python tem de sair **pré-renderizado** (.ogg/.wav) com reverb e variações já "assados"; nada de `AudioStreamGenerator` na Web. Trocar para "Stream" por player resolve os efeitos, com mais latência [R docs].
- Template sob medida (sem módulos não usados) reduz o wasm [R docs], mas exige compilar com Emscripten; não verificado se o emsdk baixa daqui (ele busca binários fora do GitHub, nv).
- Cache: ao republicar, o service worker do PWA pode servir build antigo (nv); versionar nomes ou avisar "nova versão, recarregue".

---

## 5. Celular na Web

### 5.1 HUD de toque para RPG de ação

Referências: Brawl Stars (esquerda move; direita é um "joystick de ataque": **tocar = tiro com mira automática, arrastar = mirar e soltar para disparar**; o especial usa a mesma lógica) [W https://deconstructoroffun.com/blog/2018/5/11/bs]; Android Developers (atualizar a mira só depois de passar um limiar, porque ao levantar o polegar o último evento fica na borda e "trava" a direção errada) [W https://developer.android.com/games/sdk/game-controller/common-pitfalls]; Fortnite mobile (evitar precisão, usar mira assistida e ações contextuais; botões ao alcance do polegar médio) [W https://dev.epicgames.com/documentation/fortnite/designing-for-mobile-in-fortnite]; Apple HIG (direcional que aparece onde o polegar encosta) [W https://developer.apple.com/design/human-interface-guidelines/game-controls].

Layout proposto (paisagem):

```
 [cartão J1]                                   [pausa]
                                       (hab2)
                                  (hab1)    (hab3)
 ( zona do direcional dinâmico )     ( ATAQUE ) (esquiva)
   metade esquerda inteira          botão Ø 96-120 px
```

| Elemento | Comportamento |
|---|---|
| Movimento | `VirtualJoystick` nativo do **Godot 4.7** em `JOYSTICK_DYNAMIC` (aparece onde o polegar encosta), propriedades `deadzone_ratio`, `clampzone_ratio`, `visibility_mode`, ações `action_up/down/left/right` [R `class_virtualjoystick.rst` 4.7]. No 4.5.1 instalado aqui não existe: usar o Virtual Joystick do MarcoFazio (MIT) [ver `addons-godot.md`] |
| Ataque básico | Toque = golpe/disparo no alvo da **mira automática**; segurar e arrastar = linha de mira manual, soltar dispara; arrastar de volta ao centro cancela |
| Mira automática | Pontuação por alvo: `ângulo em relação à direção do movimento` (peso maior) + `distância` + `ameaça` (quem está telegrafando); alvo "grudento" com histerese (só troca se o novo for 30% melhor); anel discreto sob o alvo atual; ignora aliados (fogo amigo no celular deveria ser reduzido, avaliação) |
| Habilidades/elementos | 3 a 4 botões em arco em volta do ataque (polegar alcança sem levantar a mão); para um sistema de combinar elementos estilo Magicka, **no máximo 4 elementos** no celular, combinação por toques em sequência com a fila desenhada perto do personagem (avaliação) |
| Esquiva | botão separado, maior que as habilidades |
| Contextual | "Reviver"/"Interagir" aparece só quando aplicável, no lugar do hab2 |
| Configurações de projeto | `emulate_touch_from_mouse` ligado, `emulate_mouse_from_touch` desligado para multitoque correto (nota do Virtual Joystick do MarcoFazio [W]); Céu Arcano já usa `touch-action:none` e bloqueio de seleção no canvas |
| Vibração | `navigator.vibrate` existe no Android Chrome, não no Safari iOS (nv) |

### 5.2 Desempenho

- Web = WebGL 2 + Compatibility; "CPU e GPU são escassos no celular, ainda mais em WebAssembly" [R docs]. O relatório `godot-render-vfx.md` já define o conteúdo "Compatibility-first" e limites (8 luzes por malha etc.).
- Sem threads, **IA, física, rede e animação dividem uma única thread** (avaliação). Orçamentos sugeridos para 30 fps num celular médio (nv, a medir): ≤ 40 inimigos ativos, IA a 10 Hz escalonada (cada inimigo pensa em um quadro diferente), `MultiMesh` para multidões e projéteis, partículas de CPU, sem rollback.
- Escala 3D com vizinho mais próximo (`SCALING_3D_MODE_NEAREST`, 4.7) para renderizar 3D a 0,5 a 0,75 da resolução com UI nítida [ver `godot-render-vfx.md`].
- iOS: relatos de perda de contexto WebGL e travamento com áudio em Godot 4.3 a 4.5 [W https://forum.godotengine.org/t/webgl-context-loss-and-app-crash-in-godot-4-3-exported-web-on-ios-browsers/81024 , https://forum.godotengine.org/t/sounds-crash-my-web-game-on-mobile-browser-godot-4-5-dev5-html-export-on-itch/113237]. Testar cedo num iPhone real.

### 5.3 Áudio, tela cheia e orientação

| Tema | Fato | Ação |
|---|---|---|
| Desbloqueio de áudio | Navegadores só tocam áudio depois de clique/toque/tecla; a doc recomenda pedir o toque numa tela inicial [R docs] | Manter o botão "Jogar" do Céu Arcano (que já inicia o motor no clique) |
| iPhone no modo silencioso | Tópico de fórum "sem áudio no modo silencioso" com Godot 4.3 [W https://forum.godotengine.org/t/iphone-web-app-no-audio-in-silent-mode-using-4-3/77674]; causa não confirmada | Aviso discreto "som desligado? confira a chave de silêncio" (avaliação) |
| Tela cheia | Android Chrome: Fullscreen API ok. iPhone: Fullscreen API em elemento que não é vídeo **não existe** (apareceu em beta 17.2 e sumiu) [W https://developer.apple.com/forums/thread/770080]; iPad tem versão prefixada | Botão "tela cheia" só onde `document.fullscreenEnabled`; no iPhone, sugerir "Adicionar à tela de início" (PWA `display: fullscreen/standalone`) |
| Orientação | `screen.orientation.lock()` exige tela cheia; no iOS não é suportado (caniuse: Safari iOS "not supported" para lock) [W https://caniuse.com/mdn-api_screenorientation_lock , https://bugs.webkit.org/show_bug.cgi?id=257695] | Android: travar paisagem ao entrar em tela cheia. Todos: mensagem "gire o aparelho" em retrato (o Céu Arcano já faz com CSS `orientation:portrait`) |
| Áreas seguras | Céu Arcano já usa `env(safe-area-inset-*)` e `viewport-fit=cover` | Repetir; HUD de toque respeita o recorte |

---

## 6. Parceiros controlados por IA (para quem joga sozinho)

### 6.1 Padrões de jogos com bons parceiros

| Jogo / parceiro | O que faz bem | Fonte |
|---|---|---|
| **Deep Rock Galactic — Bosco** | Só existe no solo (ou enquanto espera jogadores); **se autodestrói quando outro jogador entra**; comandos por "laser pointer" (ir ali, minerar, iluminar, atacar), chamar de volta; **larga tudo para reviver** o jogador caído. Reclamação: às vezes não obedece | [W https://deeprockgalactic.wiki.gg/wiki/APD-B317 , https://www.videogamer.com/guides/deep-rock-galactic-bosco , Steam] |
| **The Last of Us — Ellie** (GDC 2014, Max Dyckhoff) | O parceiro **nunca pode irritar ou frustrar**; exemplo do que quebra a relação: sair da cobertura e entregar a posição do jogador | [W https://www.gdcvault.com/play/1020364/ , https://www.gamedeveloper.com/design/video-ellie-s-buddy-ai-in-i-the-last-of-us-i-] |
| **BioShock Infinite — Elizabeth** | Ilusão de autonomia; ajuda com recursos sem precisar ser protegida | [W https://gamedeveloper.com/design/thinking-about-elizabeth-part-2] |
| Artigo "A good companion" | "Útil o bastante para ser valorizado, nem dominante (trivializa) nem frágil (vira escolta)" | [W https://gamedeveloper.com/design/a-good-companion---balancing-emotions-and-practicality-when-designing-companion-characters] |
| **Magicka 2** (contraexemplo) | Solo "jogável, mas mal e mal"; encontros parecem escalados para grupo | [W https://www.playstationlifestyle.net/2015/06/01/magicka-2-review-working-together-ps4/ ; ver `jogos-referencia.md`] |
| Lovers in a Dangerous Spacetime (pet que ajuda no solo), Secret of Mana (grade de comportamento da IA), Trine/Overcooked (trocar de personagem) | padrões conhecidos | (nv) |

### 6.2 Regras de design propostas (avaliação)

1. **Papel complementar, não espelho:** o parceiro **prepara** (aplica estado: molhado, oleoso, congelado) e o jogador **detona**. Isso ensina o sistema de combinação e casa com a recomendação central de `jogos-referencia.md` ("eu preparo, você detona").
2. Nunca rouba abate final de chefe nem saque; nunca bloqueia passagem (desvia do caminho do jogador; colisão branda entre aliados).
3. **Fogo amigo do parceiro contra o jogador: 25% ou zero**; do jogador contra o parceiro: normal (é comédia) e o parceiro reage com uma fala/animação, nunca com rancor.
4. Reviver: corre para reviver o jogador caído (com telegráfo para o jogador saber que vem), 1 vez por encontro no modo normal.
5. **Um botão de comando ("ping")**: apontar/tocar num inimigo = "foque esse"; no chão = "venha aqui"; segurar = "combo agora" (gasta o especial do parceiro no alvo do jogador).
6. Teleporta para perto se ficar fora da câmera por mais de 2 s (mesma regra dos humanos, seção 1.3).
7. Some ou cede a vaga quando entra humano (Bosco). No online, **o personagem de quem caiu da conexão vira IA** até ele voltar (Lost Castle 2 é criticado por não ter reconexão [W https://vaporlens.app/app/2445690/lost_castle_2.md], fonte fraca).
8. Opção "assistência do parceiro" (baixa/média/alta) no menu, para o jogador solo regular.

### 6.3 Behaviour tree

| Ferramenta | Licença / versão | Web | Nota |
|---|---|---|---|
| [Beehave](https://github.com/bitbrain/beehave) | MIT, v2.9.3 [R] | **sim** (GDScript puro; subiu no export Web de teste, ver `addons-godot.md`) | Editor visual e depurador; README diz "4.5+ usa 2.10+", ainda sem tag |
| [LimboAI](https://github.com/limbonaut/limboai) | MIT, v1.8.1 [R] (4.6+; v1.6.0 para 4.4 a 4.6) | GDExtension na Web exige **Extensions Support** + cabeçalhos de isolamento [R docs] e template `dlink` (não instalado aqui) [W fórum] | BT + máquina de estados hierárquica, editor excelente; só se o alvo for desktop |
| Godot State Charts | ver `addons-godot.md` | sim | Bom para chefes; BT é melhor para parceiros reativos |

Esboço da árvore do parceiro (Beehave), avaliada pelo **host** (no online, parceiros são entidades do host, como inimigos) e a 10 Hz:

```
Selector (raiz)
├─ Sequence "Emergência"     : jogador caído?            → ir até ele → reviver (canalizar 2 s)
├─ Sequence "Sobreviver"     : estou numa zona de perigo? → esquivar para o ponto seguro mais próximo
│                               (lê a lista de telegráfos ativos do host; mesma lista que desenha os avisos)
├─ Sequence "Comando"        : há ping recente (< 6 s)?   → executar (focar alvo / ir ao ponto / combo)
├─ Sequence "Preparar combo" : alvo do jogador sem estado E o jogador tem o elemento que detona?
│                               → aplicar o estado complementar no alvo
├─ Sequence "Lutar"          : escolher alvo por utilidade (ameaça ao jogador > ferido > perto) → atacar
└─ Sequence "Acompanhar"     : manter vaga de formação atrás/ao lado do jogador (raio 3 a 6 m);
                                > 15 m ou fora da câmera por 2 s → teleportar
```

- O parceiro escreve num `PlayerInput`, exatamente como um humano (seção 1.1). Ganho duplo: o **mesmo bot vira jogador de teste** nos testes headless com 4 instâncias (seção 2.5) e preenche vagas vazias no online.
- Blackboard: alvo atual, último ping, lista de telegráfos (círculos/cones com tick de impacto), posição do jogador líder, cooldowns.

---

## 7. Escalonamento de dificuldade por número de jogadores

### 7.1 Dados reais

| Jogo | Regra | Fonte |
|---|---|---|
| Diablo III, 1.0.3 | Dano de monstro **deixou** de subir por jogador; vida continuou subindo | [W https://www.pcgamer.com/diablo-3-hotfix-removes-monster-damage-boost-in-co-op-inferno-teams-breathe-sigh-of-relief] |
| Diablo III, 1.0.4 | Vida: de +75/85/95/110% por jogador extra (conforme dificuldade) para **+75% fixo** por jogador extra | [W https://www.tomshardware.com/news/Blizzard-Previews-Diablo-1.0.4-patch,16828.html] (prévia, não as notas finais) |
| Diablo III, 1.0.8 | Recompensa: +10% de achado mágico, ouro e XP por jogador extra, até +30% | [W https://www.diablowiki.net/Patch_1.0.8] |
| Deep Rock Galactic, Hazard 5 | Multiplicador de **quantidade** de inimigos 0,85 / 0,85 / 1,25 / 1,50 para 1 a 4 jogadores; resistência (vida) ×1,5 no Hazard 5 | [W https://deeprockgalactic.gamepedia.com/Difficulty_Scaling?oldid=8206] (revisão antiga); wiki atual: https://deeprockgalactic.wiki.gg/wiki/Hazard_Level |
| Risk of Rain 2 | Número de jogadores acelera a barra de dificuldade (tempo); inimigos ganham +30% vida e +20% dano por nível | [W https://riskofrain2.wiki.gg/wiki/Difficulty] (fórmula exata não verificada) |
| Earth Defense Force 6 | Vida 2,2× solo / 1,4× / 1,8× / 2,2× com 4 (relato de usuários, contestado) | [W https://steamcommunity.com/app/2291060/discussions/0/4766584846445035303] |
| Lost Castle 2 | Dificuldade "sobe com mais jogadores"; reviews criticam balanceamento | [W https://rogueliker.com/lost-castle-2-local-co-op/] (fraca) |

Lições: (1) escalar **dano** por jogador foi revertido no Diablo III; (2) o DRG quase não muda de 1 para 2 jogadores e põe o parceiro Bosco no solo; (3) recompensa sobe junto com a dificuldade.

### 7.2 Proposta (números iniciais para ajustar em teste)

`n` = jogadores humanos; parceiro de IA conta como `0,5` (então solo com parceiro: `n_eff = 1,5`).

| Grandeza | Fórmula | n=1 | n=1+IA | n=2 | n=3 | n=4 |
|---|---|---|---|---|---|---|
| Quantidade de inimigos comuns | `1 + 0,35·(n_eff − 1)` | 1,00 | 1,18 | 1,35 | 1,70 | 2,05 |
| Vida de inimigo comum | `1 + 0,15·(n_eff − 1)` | 1,00 | 1,08 | 1,15 | 1,30 | 1,45 |
| Vida de elite/chefe | `1 + 0,60·(n_eff − 1)` | 1,00 | 1,30 | 1,60 | 2,20 | 2,80 |
| Dano por golpe | constante (legibilidade: um golpe tira sempre a mesma fração) | 1 | 1 | 1 | 1 | 1 |
| Ataques simultâneos de chefe | +1 padrão de ataque com `n ≥ 3`; chefe divide atenção entre jogadores (aggro rotativo) | — | — | — | +1 | +1 |
| Tempo para reviver | `2,0 s + 0,25 s·(n − 1)` (mais gente para proteger quem revive) | 2,0 | 2,0 | 2,25 | 2,5 | 2,75 |
| Dano de fogo amigo | 100% até n=2; 70% com 3; 50% com 4 (caos cresce mais que linear) | 1 | 1 | 1 | 0,7 | 0,5 |
| Recompensa (ouro/XP individual) | `+10%` por jogador extra (como D3 1.0.8) | 1,0 | 1,0 | 1,1 | 1,2 | 1,3 |

Regras: recalcular **ao entrar numa sala/onda**, nunca no meio; ajuste dinâmico leve (±10% de quantidade na próxima onda) se o grupo caiu muitas vezes, invisível para o jogador; preferir **quantidade e composição** (mais inimigos que pedem combinações diferentes) a "esponja de vida".

---

## 8. Arquitetura recomendada (síntese)

```
Dispositivos (teclado A/B, controles, toque, bot)
        │  roteador de entrada
        ▼
PlayerInput por slot  ──(rede: RPC unreliable_ordered 30 Hz)──►  host
        │                                                         │
Personagem (lê só PlayerInput; dono do próprio movimento)         │ inimigos, projéteis,
        │                                                         │ dano, saque, RNG, IA parceira
        ▼                                                         ▼
Eventos (golpe, feitiço, telegráfo, nasce projétil)  ◄──── snapshots 15 Hz + eventos confiáveis
        │
VFX / áudio / câmera / HUD (sempre locais)
```

- Modo local = o host é a própria máquina e todos os slots são locais; nenhum código especial.
- Modo online = cada máquina tem 1 a 4 slots locais; jogador = `(peer_id, slot)`.
- `MultiplayerSpawner` para personagens e inimigos; projéteis **não** usam spawner (evento próprio com id e tick).

---

## 9. Plano em fases recomendado

| Fase | Entra | Fica de fora | Critério de pronto |
|---|---|---|---|
| **0. Esqueleto (1 a 2 dias)** | Roteador de entrada, `PlayerInput`, 2 personagens locais, câmera de grupo com leash e teleporte, harness de teste headless (bots) | Arte final | 2 jogadores locais e 2 bots rodam 2 min headless sem erro |
| **1. Primeiro corte jogável (local)** | Co-op local 1 a 4 (2 no teclado + controles + toque para J1), entrar/sair a qualquer momento, HUD por jogador, reviver, **1 parceiro de IA com Beehave**, escala por `n_eff`, HUD de toque com mira automática, export Web sem threads no **GitHub Pages** e no **artifact** (wasm e pck partidos), botão "Jogar" (áudio), aviso de rotação, PWA | Online, Steam, threads, GDExtension | Jogável no celular pelo artifact e pelo Pages; 1 jogador + IA termina uma sala; 4 jogadores locais no desktop |
| **2. Online protótipo** | **Tube** (WebRTC + trackers + STUN), sala por código/link, host autoritativo, dono do movimento, inimigos interpolados, projéteis por evento, telegráfos por tick, 2 a 4 jogadores, mistura local + online, personagem de quem caiu vira IA; desktop via `webrtc-native` | TURN, reconexão, contas | Duas abas/dois aparelhos na mesma rede jogam uma sala; teste headless com latência simulada 150 ms e 2% de perda sem divergência |
| **3. Online robusto** | Sinalização própria (Worker + Durable Object) + **TURN Cloudflare**, reconexão, `NetworkTime`/`TickInterpolator` do netfox, rollback do netfox só nos personagens se o teste pedir, lista de salas simples, detecção "online indisponível" no artifact | Matchmaking público | Partida 4G ↔ Wi-Fi conecta via TURN; queda de 10 s se recupera |
| **4. Opcional** | Build desktop com GodotSteam (lobbies Steam) ou EOS; itch.io (upload manual) | — | — |

---

## 10. Riscos

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| Sem TURN, celular ↔ celular em 4G/CGNAT não conecta | alta | alto | Fase 3 com TURN Cloudflare (1.000 GB grátis); mensagem clara de erro; jogar com IA enquanto isso |
| Trackers públicos do Tube instáveis ou fora do ar | média | médio | Lista de 4 trackers; plano de tracker próprio ou Worker na fase 3 |
| **O agente não consegue testar rede real daqui** (container só alcança GitHub/PyPI/apt; carregar `webrtc-native` foi negado) | certa | médio | Testes headless em localhost com ENet/WebSocket [T]; testes WebRTC reais ficam para o usuário (roteiro de 5 passos) |
| Desempenho do WASM sem threads no celular (IA + física + rede numa thread) | alta | alto | Orçamentos da seção 5.2; IA a 10 Hz escalonada; sem rollback; medir cedo |
| iOS Safari: perda de contexto WebGL, áudio travando, sem tela cheia | média | alto | Testar num iPhone na fase 1; PWA; manter cena leve |
| Áudio "Sample" na Web sem efeitos nem geração procedural | certa | baixo | Pré-renderizar o áudio sintetizado com reverb no pipeline Python |
| Controles na Web mal mapeados por navegador | média | médio | Tela "aperte cada botão" opcional; ícones genéricos |
| Limite de 15 MB por arquivo no artifact (wasm 38 MB, pck tende a crescer) | certa | médio | Partir wasm e pck (técnica do Céu Arcano); orçamento total < 64 MB por publicação |
| itch.io sem compressão (download 4× maior) e bloqueado no container | certa | baixo | GitHub Pages como principal; itch como vitrine, upload pelo usuário |
| API do netfox mudando (1.49 reescreveu o núcleo; exemplos de 4.1) | média | médio | Usar só `NetworkTime`/`TickInterpolator` no começo; fixar versão |
| Versão do Godot: 4.5.1 instalado aqui; `VirtualJoystick` nativo e Tube testado são 4.7 | certa | baixo | Migrar para 4.7.x (binário e template do GitHub, ver `godot-render-vfx.md`) antes da fase 1 |
| Escopo: online come o cronograma do jogo | alta | alto | Fase 1 sem rede, mas com arquitetura pronta; online só depois de o local ser divertido |
| Serviços "grátis" mudam termos (Render, Deno, GD-Sync, PeerJS) | média | médio | Preferir Tube (sem servidor) e Cloudflare (cotas documentadas); nada que trave o jogo local |

---

## 11. Pontos não verificados

- Preço e cotas do GD-Sync e do W4 Cloud (sites não resolvem nesta sessão).
- WebRTC real entre processos nativos ou abas (binário `webrtc-native` não pôde ser carregado; rede externa bloqueada).
- Tube + netfox juntos (cada um isolado é compatível com a API do Godot; a combinação não foi testada).
- Leitura de controle USB/Bluetooth dentro do iframe do artifact.
- Taxa real de falha WebRTC sem TURN em operadoras brasileiras.
- Fórmula exata do Risk of Rain 2 e valores atuais do DRG.
- Comportamento de cache do service worker do PWA do Godot ao republicar.
- Se o emsdk (para template Web enxuto) baixa a partir do container.

## 12. Fontes principais

Godot (docs lidas no GitHub `godotengine/godot-docs`): exportar para Web https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html ; multiplayer de alto nível https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html ; WebRTC https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html ; controles https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html ; VirtualJoystick https://docs.godotengine.org/en/4.7/classes/class_virtualjoystick.html ; 4.7 dev1 https://godotengine.org/article/dev-snapshot-godot-4-7-dev-1/ ; Web no 4.3 https://godotengine.org/article/progress-report-web-export-in-4-3/

Repositórios (todos conferidos com `git ls-remote`): netfox https://github.com/foxssake/netfox (MIT, v1.49.12) · noray https://github.com/foxssake/noray (MIT) · Tube https://github.com/koopmyers/tube (MIT) · demos https://github.com/godotengine/godot-demo-projects (MIT) · webrtc-native https://github.com/godotengine/webrtc-native (MIT, 1.2.2) · GD-Sync https://github.com/GD-Sync/GD-Sync · GodotSteam https://github.com/GodotSteam/GodotSteam (v4.24) · steam-multiplayer-peer https://github.com/expressobits/steam-multiplayer-peer · EOSG https://github.com/3ddelano/epic-online-services-godot (MIT) · GD-EOS https://github.com/Daylily-Zeleen/GD-EOS · Beehave https://github.com/bitbrain/beehave (MIT, v2.9.3) · LimboAI https://github.com/limbonaut/limboai (MIT, v1.8.1) · nakama-godot https://github.com/heroiclabs/nakama-godot (Apache-2.0, v3.4.0) · peerjs-server https://github.com/peers/peerjs-server (MIT) · Trystero https://github.com/dmotz/trystero (MIT, 0.27.0) · coi-serviceworker https://github.com/nisovin/godot-coi-serviceworker (MIT, v1.2) · godot-multiplayer-input https://github.com/matjlars/godot-multiplayer-input (MIT) · Input-Multi-Device https://github.com/andinodev/Input-Multi-Device (MIT) · Virtual Joystick https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot (MIT) · exemplo WebRTC https://github.com/AchcarLucas/WebRTC-Godot-Example (MIT) · demo com predição https://github.com/seaciety/GodotMultiplayerDemo (licença não conferida)

Infraestrutura: Cloudflare DO https://developers.cloudflare.com/durable-objects/platform/pricing/ e https://developers.cloudflare.com/changelog/2025-04-07-durable-objects-free-tier · Workers https://developers.cloudflare.com/workers/platform/limits/ · TURN https://developers.cloudflare.com/realtime/turn/faq/ e https://developers.cloudflare.com/realtime/pricing/ · Open Relay https://metered.ca/tools/openrelay/ · PeerJS https://peerjs.com/server/cloud · Supabase https://supabase.com/docs/guides/realtime/limits · Render https://render.com/docs/free · Oracle https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm · Deno https://deno.com/deploy/pricing · W4 Cloud https://w4games.com/w4cloud e https://forum.godotengine.org/t/using-w4-games-for-development/94534 · Playroom https://playroom-docs.vercel.app/usage/godot · GitHub Pages https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits · itch.io https://itch.io/docs/creators/html5 e https://itch.io/t/2025776/experimental-sharedarraybuffer-support · WebRTC stats https://webrtchacks.com/usage-stats/ · CGNAT https://noping.com/pt/blog/cgnat-no-brasil-para-jogos-nat-portas-chat-e-ping e https://tecnoblog.net/responde/o-que-e-cgnat/ · modelos de rede https://mas-bandwidth.com/choosing-the-right-network-model-for-your-multiplayer-game/ e https://www.gabrielgambetta.com/client-side-prediction-server-reconciliation.html

Celular e navegador: https://developer.apple.com/forums/thread/770080 · https://bugs.webkit.org/show_bug.cgi?id=257695 · https://caniuse.com/mdn-api_screenorientation_lock · https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Permissions-Policy/gamepad · https://groups.google.com/a/chromium.org/g/blink-dev/c/B1QUuICApvc · https://developer.android.com/games/sdk/game-controller/common-pitfalls · https://dev.epicgames.com/documentation/fortnite/designing-for-mobile-in-fortnite · https://developer.apple.com/design/human-interface-guidelines/game-controls · https://deconstructoroffun.com/blog/2018/5/11/bs

Design de co-op, IA e dificuldade: https://pandaqi.itch.io/package-party/devlog/105217/9-camera-kung-fu · https://pandaqi.itch.io/package-party/devlog/107256/21-input-management · https://gamedeveloper.com/design/shared-multi-split-screen-design · https://gamedeveloper.com/programming/single-camera-system-for-four-players · https://forum.godotengine.org/t/help-local-multiplayer-device-conflict/128696 · https://github.com/godotengine/godot/issues/59250 · https://deeprockgalactic.wiki.gg/wiki/APD-B317 · https://www.gdcvault.com/play/1020364/ · https://gamedeveloper.com/design/thinking-about-elizabeth-part-2 · https://gamedeveloper.com/design/a-good-companion---balancing-emotions-and-practicality-when-designing-companion-characters · https://www.pcgamer.com/diablo-3-hotfix-removes-monster-damage-boost-in-co-op-inferno-teams-breathe-sigh-of-relief · https://www.tomshardware.com/news/Blizzard-Previews-Diablo-1.0.4-patch,16828.html · https://www.diablowiki.net/Patch_1.0.8 · https://deeprockgalactic.gamepedia.com/Difficulty_Scaling?oldid=8206 · https://riskofrain2.wiki.gg/wiki/Difficulty · https://rogueliker.com/lost-castle-2-local-co-op/ · https://www.playstationlifestyle.net/2015/06/01/magicka-2-review-working-together-ps4/

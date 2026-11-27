# Contexto real de jogo: em que aparelho, com quem, e quanto o celular aguenta

Pesquisa complementar (lacuna do crítico de completude). Data: 27/11/2026. Motor: Godot 4.7.2-stable. Tudo o que foi medido aqui está marcado **[T]** (testado no container), **[W]** (fonte da web, com URL), **[R]** (código-fonte ou documentação lidos no GitHub), **[NV]** (não verificado) ou **[C]** (conta feita por mim, não medição).

Relatórios lidos antes, para não repetir: `coop-rede.md` (transportes, sinalização, TURN, HUD de toque, plano em fases), `godot-render-vfx.md` (paridade Compatibility × Forward+, captura Web com Chrome headless, split de wasm), `addons-godot.md`, `direcao-de-arte.md`.

---

## 0. Resumo em 14 pontos

1. **A pergunta central continua sem resposta do usuário**: modelo do celular, com quem e em que aparelhos ele quer jogar. Isso foi transformado num **formulário dentro do próprio teste de desempenho** (seção 2), que grava as respostas e os números num banco que o Claude lê depois. Link: **https://claude.ai/artifact/34DxYCDCstTXbcdrgEPpxv** (privado; só o dono abre).
2. **Cena de estresse pronta e publicada [T]**: Godot 4.7.2, Compatibility/WebGL2, export sem threads, `index.wasm` de 39.514.754 bytes partido em 3 arquivos de 13,2 MB, `.pck` de 285 KB. 4 heróis (8.808 triângulos cada) e 20 inimigos (3.080 triângulos) com esqueleto de 13 ossos e animação gerada no Blender por `bpy`, 6 efeitos, contorno por stencil, glow, 11 luzes (1 direcional + 10 omni), física `CharacterBody3D` a 30 Hz, IA escalonada. Seis etapas automáticas de 10 s (A a F, seção 2.2), com `godot-debug-menu` na tela e uma ficha final.
3. **O que já dá para afirmar sem o celular [T]**: (a) o **contorno por stencil dobra os triângulos desenhados** (72 mil → 144 mil) e acrescenta 24 draw calls; (b) **sombra direcional real** é o item mais caro: 96 → 204 draw calls, 144 mil → 431 mil primitivas, +64% no tempo de quadro em WebGL2 por software; (c) **o Godot Web desenha na resolução física da tela** (`devicePixelRatio`): num celular com DPR 2,625 a tela de 915×412 CSS vira um canvas de 1736×976. Resolução 3D a 70% cortou 31% do tempo de quadro nesse caso, e a 50% cortou 42%.
4. **Números absolutos do container não valem para celular**: SwiftShader (WebGL2 por CPU) fez 1,9 a 6,9 FPS. Eles servem só para comparar etapas entre si. O número real vem do aparelho do usuário.
5. **Co-op local no celular praticamente não existe** como modo principal: o toque atende um jogador; o segundo só entra com controle Bluetooth/USB (Gamepad API funciona no Chrome Android [W]), o que é raro no público de celular.
6. **WebRTC com host no navegador funciona [T]**: com o demo oficial `webrtc_signaling` (servidor de sinalização em GDScript rodando num Godot 4.7.2 sem interface), **1 host + 3 clientes em processos Chrome separados** conectaram em estrela (`create_server`/`create_client`), sem o GDExtension `webrtc-native`. RTT mediano 33 ms (2 jogadores) e 36,5 ms (4 jogadores) em localhost; 300 de 300 snapshots de 440 bytes a 30 Hz chegaram em cada cliente.
7. **Achado novo e importante [T]**: o RTT de 33 ms em localhost é **piso de quadro**, não rede: o Godot só lê a rede uma vez por quadro, então cada ida e volta paga cerca de 2 quadros de 16,7 ms. No celular a 30 FPS o piso vira ~67 ms **antes** de somar a rede móvel (30 a 80 ms [W]).
8. **Achado novo e crítico [T][W]**: **aba em segundo plano para o jogo**. No primeiro teste, com as duas abas no mesmo Chrome, a aba do host ficou em segundo plano e a conexão nunca fechou; com um processo por jogador, tudo funcionou. O Chrome não chama `requestAnimationFrame` em página escondida desde 2011 [W https://developer.chrome.com/blog/background_tabs]. Consequência: **se o host no celular atender o WhatsApp, o jogo congela para todos**.
9. **WebRTC não funciona dentro do artifact do Claude** (regra do próprio artifact: "service workers and WebRTC do not"). Online só no GitHub Pages ou similar. O teste de desempenho pode ficar no artifact; o teste online, não.
10. **Público real no Brasil = celular de entrada**: o mais vendido da América Latina em 2025 foi o Galaxy A06 (Helio G85, GPU Mali-G52 MC2 de 2 núcleos), e 8 dos 10 mais vendidos são 4G e custam menos de US$ 200 [W]. Se o usuário e os amigos têm aparelhos assim, o orçamento Web cai bastante (seção 4).
11. **Se o uso real for "cada um no seu celular, pela internet", o online deixa de ser fase 2 e vira requisito da fase 1**, junto com sinalização própria, TURN (CGNAT nas operadoras), host em primeiro plano e regras de jogo tolerantes a 100 a 150 ms (seção 5).
12. **Em co-op online cada celular desenha a própria câmera**: some a restrição da câmera compartilhada. As arenas podem ser maiores que a tela, e o orçamento de render é por aparelho; o host paga simulação + render + rede numa única thread.
13. **Caminho de maior qualidade continua sendo o PC**: export desktop em Forward+ (névoa volumétrica, SDFGI etc.), co-op local com controles e, mais tarde, **Steam Remote Play Together** transforma esse co-op local em online sem escrever rede (só o host precisa ter o jogo) [W].
14. **Recomendação provisória** até o usuário responder: manter o núcleo "local + parceiros de IA" (funciona em tudo), mas já arquitetar o estado do jogo como **host autoritativo com entradas por jogador** (mesma interface para teclado, controle, toque, bot e peer remoto), e escolher a fase 2 conforme a resposta (tabela da seção 6).

---

## 1. O que precisa ser perguntado ao usuário

O usuário testou o Céu Arcano no navegador do celular, mas o modelo não aparece em nenhum arquivo do repositório nem no histórico de commits [T: busca por "samsung|galaxy|iphone|motorola|xiaomi|android|safari" nos `.md` e `git log`]. As perguntas abaixo estão no formulário do artifact e também podem ser feitas na conversa:

| # | Pergunta | Por que muda o projeto |
|---|---|---|
| 1 | Qual o modelo do celular em que você testou o Céu Arcano? | Define o orçamento de render (seção 4) e se iPhone entra no teste cedo |
| 2 | Onde e com quem você quer jogar? (múltipla escolha: sozinho com IA no celular; amigos cada um no seu celular pela internet; amigos na mesma sala cada um no seu celular; PC/TV com controles; tela grande + celulares como controle; PC online) | Decide se o online é fase 1 ou 2 e qual topologia |
| 3 | Quantas pessoas e que aparelhos elas têm (algum iPhone)? | iPhone tem histórico de perda de contexto WebGL com Godot Web [W]; o host deveria ser o aparelho mais forte |
| 4 | Tem controle de videogame (Bluetooth/USB)? | Co-op local de 2 no mesmo celular/tablet só existe com controle |
| 5 (depois do teste) | Como ficou a ficha de resultado? | Números reais das etapas A a F |

---

## 2. O teste de desempenho publicado

### 2.1 Como usar

- Link: **https://claude.ai/artifact/34DxYCDCstTXbcdrgEPpxv** (artifact privado; o usuário precisa abrir logado).
- Baixa ~40 MB (3 partes de wasm + `.pck` de 285 KB), mostra "Começar o teste", roda ~1 minuto com o celular deitado e exibe a ficha na tela do jogo e numa tabela HTML abaixo.
- **Os resultados e as respostas do formulário são gravados no banco do artifact** (capacidade `db`, coleção `resultados`). O Claude lê com `ArtifactData` → `list` em `resultados` com a URL acima. Verificação feita: a coleção existe e estava vazia logo após publicar [T]. Se o banco não estiver disponível no aparelho, a página manda copiar o JSON ou mandar captura.
- O canvas é dimensionado em JS para `largura_CSS × devicePixelRatio`, de propósito: mede o custo real da tela do aparelho (a mesma coisa que o Godot faz com `canvasResizePolicy` adaptativo e `allow_hidpi` ligado, seção 3.3).

### 2.2 Etapas (8 s medidos depois de 2 s de aquecimento cada)

| Etapa | Configuração | Pergunta que responde |
|---|---|---|
| A | Tudo ligado, 3D a 100% da resolução física | O aparelho aguenta o "jeito ingênuo"? |
| B | Tudo ligado, 3D a 70% (`Viewport.scaling_3d_scale`) | Quanto ganha reduzindo só o 3D (HUD continua nítido) |
| C | Tudo ligado, 3D a 50% | Piso de resolução aceitável |
| D | Sem contorno e sem glow, 70% | Custo do contorno por stencil + glow |
| E | Pico: 40 inimigos e 12 efeitos (17 luzes), 70% | Limite de inimigos/efeitos; define o tamanho das ondas |
| F | Tudo + sombra direcional real, 70% | Se sombra real é viável na Web |

Métricas por etapa: FPS médio, tempo de quadro mediano, p95, p99 e máximo, "CPU ms" (do início do `_process` até `RenderingServer.frame_post_draw`, aproximação do tempo de thread principal: inclui script, física e envio de comandos GL, não inclui a GPU terminar), draw calls e primitivas médias (`Performance`), memória de vídeo, janela e resolução 3D. Na carga: tempo de download, motor pronto e primeiro quadro (via `JavaScriptBridge`). Dados do aparelho: GPU (`WEBGL_debug_renderer_info`), DPR, tela, núcleos, `navigator.deviceMemory`, user agent.

Observação [T]: `Performance.MEMORY_STATIC` volta 0 no export Web release; a ficha mostra memória de vídeo no lugar.

### 2.3 Conteúdo da cena (tudo gerado por código)

| Item | Detalhe | Fonte |
|---|---|---|
| Personagens | Humanoide por primitivas unidas, 13 ossos, pesos rígidos por parte, ações `run` (20 quadros) e `attack` (16 quadros, com antecipação, golpe rápido e follow-through) | `scripts/make_chars.py` (bpy 5.3) → `hero.glb` 391 KB, `enemy.glb` 165 KB |
| Material | `StandardMaterial3D` toon (diffuse e specular toon, rim 0,6), cor por vértice, `stencil_mode = OUTLINE`, espessura 0,035 | `main.gd` |
| Efeitos | Fogo (GPUParticles3D 160, aditivo), faíscas (120), névoa (40 quads grandes com mistura alfa = overdraw), círculo mágico no chão (shader aditivo), feixe (cilindro aditivo com fresnel), onda de choque com distorção da tela (`hint_screen_texture`) | `main.gd` |
| Cenário | 24 ladrilhos de 5×5 m com shader procedural, 10 pilares com colisão | `main.gd` |
| IA | Alvo recalculado a cada 3 ticks escalonados, separação O(n²), `move_and_slide` | `main.gd` |
| HUD | `godot-debug-menu` (estilo compacto) + rótulo próprio | addon MIT |

Arquivos de trabalho (scratchpad, podem ser apagados numa limpeza): `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-celular-coop/` (`proj/`, `pub/`, `rtc/`, `scripts/`, `out/`).

Addon usado, conferido: **godot-debug-menu** https://github.com/godot-extended-libraries/godot-debug-menu — `git ls-remote` HEAD `ff124615`, tag v1.2.0, licença **MIT** (Hugo Locurcio), último commit 19/11/2025 [T]. Usa `Thread` para coletar informações; no export sem threads funcionou e mostrou FPS e ms na tela [T].

### 2.4 Resultados no container (só comparação relativa)

WebGL2 real no Chrome for Testing 153 headless com ANGLE/SwiftShader (GPU por CPU, 4 núcleos), modo rápido (1 s + 3 s por etapa) [T]:

**Desktop emulado, 1100×619 de jogo, DPR 1**

| Etapa | FPS | Mediana ms | p95 ms | CPU ms | Draw calls | Primitivas | Res. 3D |
|---|---|---|---|---|---|---|---|
| A | 3,8 | 267,7 | 335,7 | 246,7 | 96 | 143.445 | 1100×619 |
| B | 4,9 | 198,2 | 238,1 | 198,5 | 96 | 143.956 | 770×433 |
| C | 5,5 | 187,1 | 219,3 | 176,0 | 96 | 143.699 | 550×309 |
| D | 6,9 | 141,3 | 173,5 | 139,1 | 72 | 72.288 | 770×433 |
| E | 3,5 | 282,4 | 343,2 | 269,4 | 142 | 266.952 | 770×433 |
| F | 3,0 | 324,4 | 403,3 | 323,5 | 204 | 430.996 | 770×433 |

**Celular emulado (915×412 CSS, DPR 2,625, `mobile: true`) → canvas 1736×976**

| Etapa | FPS | Mediana ms | p95 ms | Draw calls | Primitivas | Res. 3D | Mem. vídeo |
|---|---|---|---|---|---|---|---|
| A | 1,9 | 519,9 | 1090,1 | 96 | 161.575 | 1736×976 | 52,0 MB |
| B | 2,8 | 357,8 | 389,0 | 96 | 161.572 | 1215×683 | 41,0 MB |
| C | 3,3 | 303,7 | 348,0 | 96 | 161.572 | 868×488 | 35,9 MB |
| D | 3,4 | 285,3 | 355,4 | 72 | 82.571 | 1215×683 | 40,0 MB |
| E | 1,9 | 515,0 | 579,8 | 142 | 285.640 | 1215×683 | 42,3 MB |
| F | 1,7 | 586,5 | 689,6 | 204 | 483.844 | 1215×683 | 41,0 MB |

Desktop nativo Compatibility sobre llvmpipe (OpenGL por CPU), 1280×720, câmera mais afastada (versão anterior da cena), etapas completas: A 13,0 / B 15,6 / C 18,2 / D 19,0 / E 9,5 / F 8,1 FPS [T].

Leituras que valem para qualquer aparelho (proporções, não FPS):

| Achado | Evidência [T] | Regra para o projeto |
|---|---|---|
| Resolução importa muito em tela de DPR alto | A → B: −31% de tempo; A → C: −42% (DPR 2,625) | **Nunca renderizar o 3D em resolução física no celular.** Limitar DPR efetivo a ~1,5 e/ou `scaling_3d_scale` 0,6 a 0,75 |
| Contorno por stencil é caro em vértices | B → D: primitivas 144k → 72k, draw calls 96 → 72, tempo −29% (junto com glow) | Contorno em heróis, chefes e elites; nos inimigos comuns, testar contorno só por cor/rim ou casca invertida em malha simplificada |
| Sombra direcional real é proibitiva na Web | B → F: draw calls ×2,1, primitivas ×3, tempo +64% | **Sem sombra dinâmica no nível Web**: sombra blob (quad) ou assada; reforça `godot-render-vfx.md` §4 |
| Dobrar inimigos e efeitos ~ +42% | B → E | Ondas de 20 inimigos visíveis como padrão; picos de 30 a 40 só em momentos curtos (a confirmar no aparelho) |
| Memória de vídeo pequena | 36 a 52 MB | Não é o gargalo com arte procedural; textura grande seria |

### 2.5 Tamanho e carga

- `index.wasm` 4.7.2 sem threads: **39.514.754 bytes**; `gzip -9` dá **10.084.297 bytes** [T]. O `.pck` da cena: 285 KB (personagens e shaders são minúsculos porque tudo é procedural).
- Publicado em 3 partes de 13,2 MB (limite do artifact: 15 MB por binário) e remontado em JS antes de entregar ao `Engine` (sobrescrevendo `fetch` para `index.wasm`; o `.pck` é servido como `data.wasm`). Mesma técnica do Céu Arcano.
- Se o artifact servir sem compressão, são ~40 MB: em 4G a 20 Mbit/s seriam ~16 s; comprimido (~10 MB), ~4 s [C]. Compressão do artifact: [NV]. GitHub Pages comprime o wasm na hora (`coop-rede.md` §4).
- Em localhost, motor pronto + primeiro quadro em 0,7 a 2,0 s depois do download [T].

---

## 3. Como o usuário vai jogar: opções concretas

### 3.1 Panorama do público (Brasil)

| Dado | Valor | Fonte |
|---|---|---|
| Mais vendido da América Latina em 2025 | Galaxy A06 (7% das vendas da região) | Counterpoint via GSMArena [W https://www.gsmarena.com/counterpoint_samsung_galaxy_a06_was_the_bestselling_phone_in_latam_for_2025-news-71620.php] |
| Top 10 LATAM 2025 | A06, A16, Moto G15, Redmi 14C, A15, Moto G05, Redmi A5, Moto G35 5G, A56 5G, Redmi Note 14 | Selular.ID citando Counterpoint [W https://selular.id/2026/02/top-10-smartphone-terlaris-2025-samsung-galaxy-a06-mendominasi/] (lista completa só nessa fonte) |
| 8 dos 10 são 4G; maioria abaixo de US$ 200 | — | Counterpoint [W https://counterpointresearch.com/en/insights/samsung-leads-latam-top10-Smartphones-list-with-4spots] |
| Marcas no Brasil | Samsung ~36%, Motorola ~20%, Xiaomi ~17%, Apple ~13% (StatCounter, jul/2025) | [W https://www.oficinadanet.com.br/smartphones/63559-market-share-celulares-julho-2025-brasil] |
| GPU do A06 | Helio G85, Mali-G52 MC2 (2 núcleos, até 1 GHz); jogos leves 18 a 60 FPS | Notebookcheck [W https://www.notebookcheck.net/Mediatek-Helio-G85-Processor-Benchmarks-and-Specs.494452.0.html] |
| Benchmark WebGL do A06 | **não encontrado** | [NV] |

Conclusão: se o grupo do usuário tem aparelhos dessa faixa, o alvo Web realista é **30 FPS estáveis** com resolução 3D reduzida, e não 60.

### 3.2 Matriz de cenários

| Cenário | Como funciona | O que exige | Prós | Contras | Estado |
|---|---|---|---|---|---|
| **S1. Sozinho + parceiros de IA no celular** | 1 humano no toque, 1 a 3 bots | Nada de rede | Funciona no artifact, Pages, offline | Não é "jogar com amigos" | Plano atual, fase 1 |
| **S2. Amigos, cada um no seu celular, pela internet** | Host no navegador de um celular, outros conectam por WebRTC | Sinalização (Cloudflare Worker), **TURN** (CGNAT), host em primeiro plano, regras tolerantes à latência | É o uso mais comum de celular | Mais complexo; host congela se sair do app; iOS arriscado | WebRTC entre navegadores **provado aqui [T]**; rede móvel real [NV] |
| **S3. Amigos na mesma sala, cada um no seu celular (mesmo Wi-Fi)** | Igual a S2, mas ICE acha caminho direto na LAN | Sinalização (ainda precisa de internet); TURN quase nunca | Latência baixa | Mesmas limitações do host | Topologia testada em localhost [T] |
| **S4. PC/TV com controles, todos na mesma tela** | Co-op local clássico (Magicka, Lost Castle) | Controles; câmera compartilhada | Melhor visual (Forward+ no desktop), zero rede | Exige PC e controles | Arquitetura em `coop-rede.md` §1 |
| **S5. Tela grande + celulares como controle** (modelo AirConsole) | PC/TV/tablet roda o jogo; cada celular abre uma página leve de controle e manda entradas por WebRTC | Sinalização; página de controle (HTML puro, não precisa do Godot) | Ninguém precisa de controle; celular fraco basta | Precisa da tela grande; latência de entrada = rede + 1 quadro | AirConsole usa WebRTC com fallback por servidor [W https://developers2.airconsole.com/faq-help]; [NV] aqui |
| **S6. PC online** | Desktop nativo, ENet ou WebRTC (`webrtc-native`) | Servidor de sinalização/relay ou Steam | Desempenho e qualidade | Distribuição desktop | ENet testado em `coop-rede.md` [T] |
| **S4+ Remote Play Together** | Co-op local do PC transmitido pela Steam | Lançar na Steam | Online "de graça", amigo não precisa ter o jogo; até 4 [W https://www.tomsguide.com/reference/steam-remote-play-together-how-to-use] | Taxa da Steam; depende do upload do host [W https://www.pcgamer.com/steams-remote-play-together-is-fiddly-but-still-a-great-way-to-play-couch-co-op-online] | Futuro |

### 3.3 Por que co-op local no navegador do celular quase não existe

- O HUD de toque cobre um jogador. Dois jogadores no mesmo celular dividindo a tela por toque é inviável em 6"; num tablet é possível, mas apertado (avaliação).
- O segundo jogador no mesmo aparelho só com controle: Gamepad API suportada no Chrome Android, inclusive Bluetooth [W https://web.dev/articles/gamepad , https://caniuse.com/gamepad]; há relato antigo de controle Xbox que não chegava à página no Chrome Android [W https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/53825789/html5-gamepad-api-on-android-chrome]. No iOS Safari a API existe, mas o comportamento com controles Xbox/PS não foi confirmado [W https://caniuse.com/gamepad , https://bugs.webkit.org/show_bug.cgi?id=212933] [NV].
- Godot Web desenha em resolução física: `godot_js_display_setup_canvas(..., is_hidpi_allowed())` e `getPixelRatio()` devolve `window.devicePixelRatio` quando `hidpi` é verdadeiro [R https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/display_server_web.cpp , https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/js/libs/library_godot_display.js]. O padrão do projeto é `display/window/dpi/allow_hidpi = true`. **No preset Web, desligar `allow_hidpi` ou dimensionar o canvas com DPR limitado (como a página do teste faz) é a otimização mais barata que existe.**

---

## 4. Orçamento Web: o que sai do teste e como decidir

Os números abaixo são **regras de decisão** para quando a ficha do usuário chegar. Os limiares são avaliação minha [C], não medição em celular.

| Resultado da etapa B (completa, 3D 70%) no aparelho do usuário | Leitura | Orçamento para o protótipo |
|---|---|---|
| ≥ 55 FPS e p95 ≤ 20 ms | Aparelho folgado (provável intermediário/topo ou iPhone recente) | Alvo 60 FPS; 20 inimigos + 6 efeitos; contorno em todos; picos de 40 (se E ≥ 40 FPS) |
| 30 a 55 FPS | Faixa intermediária | **Alvo 30 FPS travado** (`Engine.max_fps = 30`, quadro estável vale mais que pico); 3D a 70%; contorno só em heróis/elites se D for >25% mais rápido que B; ondas de 15 a 20 |
| 20 a 30 FPS | Entrada (classe Mali-G52 MC2) | 30 FPS só com C (50%) ou DPR 1; sem glow; 10 a 12 inimigos visíveis; efeitos com no máximo 60 partículas; `MultiMesh` para multidão |
| < 20 FPS | Abaixo do mínimo para ação | O celular só serve como controle (S5) ou o jogo vira 2D/HD-2D com sprites (mais leve em vértices, `godot-render-vfx.md` §6) |

Regras independentes do resultado (do que já foi medido [T]):

1. Sem sombra direcional dinâmica no nível Web (F custa +64%).
2. Resolução 3D separada do HUD: `scaling_3d_scale` 0,6 a 0,75 + `allow_hidpi` controlado; HUD e texto continuam nítidos.
3. Contorno é o segundo item mais caro: orçar por personagem, não por cena.
4. **Host paga mais**: simulação de todos + render + serialização para até 3 peers numa thread só (export sem threads). O host deve ser o aparelho mais forte do grupo; com PC disponível, o PC hospeda.
5. Legibilidade decide arena: com a câmera do teste (FOV 40°, 14 m de altura) cabe ~16 × 10 m no quadro e um personagem de 1,8 m ocupa ~70 px CSS de altura num celular de 412 px CSS [C]. Em co-op online, cada aparelho segue o próprio jogador, então arenas podem ser maiores que a tela; em co-op local (S4) a arena precisa caber no enquadramento do grupo.

---

## 5. Rede: o que foi provado e o que muda nas mecânicas

### 5.1 Teste WebRTC entre navegadores [T]

Montagem:

- Projeto `rtc/` com `client/` e `server/` copiados do demo oficial `networking/webrtc_signaling` (godot-demo-projects, MIT, commit `281a99f0` de 25/11/2026) e uma cena `probe.gd` que lê `?role=host|join&lobby=...&n=...` da URL.
- Servidor de sinalização: `ws_webrtc_server.gd` rodando em Godot 4.7.2 nativo `--headless`, porta 9080.
- Clientes: export Web sem threads (WebRTC do próprio navegador; o `webrtc-native` não é necessário na Web).
- Orquestrador Node 22 por DevTools Protocol: abre o host, lê o código do lobby pelo `document.title`, abre os outros jogadores, espera todos terminarem.
- Host: `create_server()` no navegador (lobby sem malha, `mesh=false`); clientes `create_client()`; o servidor de jogo repassa mensagens entre clientes.
- Medição: 100 pings confiáveis + 100 não confiáveis a 20 Hz por cliente; depois 300 snapshots de 440 bytes (24 entidades × 18 B + cabeçalho) a 30 Hz em `unreliable_ordered`.

Resultados:

| Cenário | Conectou? | Tempo até `peer_connected` | RTT confiável (med / p95 / máx) | RTT não confiável (med / p95) | Snapshots recebidos | Intervalo entre snapshots (med / p95) |
|---|---|---|---|---|---|---|
| 2 abas no **mesmo** Chrome | **Não**: a aba do host ficou em segundo plano e parou de rodar | — | — | — | — | — |
| 2 processos Chrome, mDNS desligado | Sim | host 2,9 s (espera o outro abrir); cliente 0,49 s | 33,4 / 35,5 / 40,3 ms | 33,4 / 35,6 ms | 300/300 | 33,4 / 47,8 ms |
| 2 processos Chrome, **configuração padrão** (candidatos mDNS) | Sim | cliente 1,17 s | 31,9 / 47,6 / 94,5 ms | 32,0 / 47,6 ms | 300/300 | 34,5 / 56,5 ms |
| 4 processos Chrome (host + 3) | Sim, todos veem todos | clientes 0,87 a 1,05 s | 36,5 / 60,9 / 96,8 ms (300 amostras) | 36,9 / 61,9 ms | 300/300 em cada | 45 a 46 / 77 a 86 ms |

Leitura:

- **Host no navegador funciona**, sem GDExtension, com o protocolo do demo oficial. A sinalização pode ser desligada depois da conexão.
- **O RTT de localhost (~33 ms) é o custo de quadro**: o Godot faz `poll()` da rede uma vez por quadro a 60 FPS, então ida (1 quadro no cliente) + volta (1 quadro no host) ≈ 33 ms. Com 4 navegadores dividindo 4 CPUs, os quadros ficaram mais lentos e o RTT subiu. **No celular a 30 FPS, o piso sobe para ~67 ms antes da rede** [C].
- Rede móvel no Brasil: nPerf 2024–25 dá latência média por operadora de 30,4 ms (Claro), 43,6 ms (TIM) e 44,8 ms (Vivo) (sem separar 4G de 5G) [W https://olhardigital.com.br/2025/09/08/internet-e-redes-sociais/qual-operadora-tem-a-internet-mais-rapida-no-brasil-estudo-responde/]; Opensignal já citou 72 ms para o Brasil (ano não claro) [W https://www.folhavitoria.com.br/geral/internet-movel-do-brasil-perde-para-paises-como-albania-e-bolivia/]. Isso é até o servidor de teste; entre dois celulares, possivelmente passando por TURN, é mais [NV].
- **Orçamento de latência para design [C]**: celular ↔ celular via internet ≈ 2 × 40 ms de rede + 2 quadros a 30 FPS ≈ **150 ms de RTT típico**, picos de 250 ms. Projetar para 150 ms e tolerar 250 ms.
- **Aba em segundo plano congela o host**: o Chrome não chama `requestAnimationFrame` em páginas escondidas e limita timers a 1 por segundo [W https://developer.chrome.com/blog/background_tabs]; o mesmo problema aparece em bibliotecas de netcode Web [W https://www.github.com/rameshvarun/netplayjs/issues/76]. No Android o sistema ainda pode matar a aba [NV].
- Safari iOS tem `RTCDataChannel` desde o iOS 11 [W https://caniuse.com/mdn-api_rtcdatachannel], mas iPhone não foi testado.
- Dentro do artifact do Claude, WebRTC é bloqueado (contrato do artifact); o modo online precisa detectar isso e esconder o botão.

### 5.2 O que muda nas mecânicas se o online for requisito

| Mecânica (estilo Magicka/Lost Castle) | Problema com 150 ms | Regra proposta [avaliação] |
|---|---|---|
| Fogo amigo | Cliente vê o aliado num lugar, o host decide noutro; "fui atingido sem ver" | Acerto em aliado decidido no **host**, com **favor da vítima**: só conta se o aliado estava dentro da área também na visão do host; dano amigo reduzido (25 a 50%) e sempre com aviso visual de 300 ms antes (telegrafo do feitiço) |
| Combinar elementos entre jogadores (feixe A + feixe B = reação) | Dois clientes com relógios diferentes; a combinação depende de ordem | Reações calculadas só no host, por tick; janela de combinação ≥ 250 ms; o cliente mostra a reação prevista apenas como efeito cosmético até o host confirmar |
| Esquiva/aparar | Janela de 150 ms some na latência | Movimento do próprio jogador previsto no cliente (dono do movimento, `coop-rede.md` §2.2); invencibilidade decidida no cliente que esquiva, com verificação branda no host; nada de aparar com janela < 200 ms no online |
| Projéteis | Disparo parece atrasado | Projétil do próprio jogador nasce no cliente na hora (cosmético) e o host confirma o acerto; inimigos usam telegrafos ≥ 400 ms |
| Reviver aliado | Barra de progresso diverge | Progresso só no host; cliente mostra interpolado |
| Host sai do app | Todos congelam | Pausa automática com aviso "aguardando anfitrião" no `visibilitychange`; reconexão; **migração de host** fica para depois (custo alto) |
| Câmera | — | Cada aparelho segue o próprio herói; sem zoom de grupo no online |

Referências gerais: projéteis e compensação de latência [W https://medium.com/@geretti/netcode-series-part-4-projectiles-96427ac53633 , https://gamedeveloper.com/programming/why-making-multiplayer-games-is-hard-lag-compensating-weapons-in-mechwarrior-online]; vantagem do host e "favor do atirador" frustrando quem é atingido [W https://www.pcgamer.com/au/netcode-explained]. Fonte específica sobre fogo amigo em rede: **não encontrada** [NV]. Magicka 2 foi elogiado pela estabilidade online em reviews [W https://www.trustedreviews.com/reviews/magicka-2], sem detalhe técnico público encontrado.

---

## 6. Recomendação por resposta do usuário

| Se o usuário responder... | Fase 1 vira | Fase 2 | Arquitetura que já nasce na fase 1 |
|---|---|---|---|
| "Sozinho no celular" (S1) | Plano atual: local + IA, toque, Web no artifact/Pages | Online opcional | Entradas por jogador abstratas; host autoritativo local |
| "Amigos, cada um no seu celular" (S2/S3) | **Local + IA + online WebRTC mínimo** (2 jogadores, sala por código, Pages + sinalização própria) | TURN (Cloudflare), 4 jogadores, reconexão | Estado só no host; mecânicas da tabela 5.2 desde o início; detector de segundo plano; host = aparelho mais forte |
| "PC/TV com controles" (S4) | Co-op local 1 a 4 com controles, **export desktop Forward+** como vitrine e Web Compatibility como demo | Remote Play Together / online desktop | Câmera de grupo; arenas do tamanho do enquadramento |
| "Tela grande + celulares como controle" (S5) | Jogo no PC/TV + página HTML de controle | Online S2 | Mesmo protocolo de entradas do S2, só que sem simular nada nos celulares |
| Misturado | S1 + S4 primeiro (sem rede), S2 logo em seguida | — | A mesma camada de entrada serve para todos |

Em todos os casos: **testar o aparelho do usuário e um iPhone (se algum amigo tiver) antes de fixar a direção de arte**, porque o orçamento da seção 4 decide se o estilo final é 3D completo com contorno ou HD-2D com sprites.

---

## 7. Pontos não verificados

- Desempenho real em qualquer celular (o teste está publicado; falta o usuário rodar).
- Se o artifact serve o wasm comprimido.
- WebRTC entre dois celulares em rede móvel real, com CGNAT, e com TURN; taxa de falha sem TURN no Brasil.
- Comportamento de abas em segundo plano no Chrome Android e no Safari iOS (se a aba é suspensa ou morta, e em quanto tempo).
- Controles Bluetooth no Safari iOS e dentro do iframe do artifact.
- GPU time do `godot-debug-menu` na Web (WebGL2 normalmente não expõe consultas de tempo de GPU) [NV].
- Latência de 4G separada de 5G no Brasil em ms (as fontes misturam).
- `max_fps = 30` no export Web: efeito real sobre a fluidez e a bateria [NV].

---

## 8. Fontes

Mercado e aparelhos: https://www.gsmarena.com/counterpoint_samsung_galaxy_a06_was_the_bestselling_phone_in_latam_for_2025-news-71620.php · https://counterpointresearch.com/en/insights/samsung-leads-latam-top10-Smartphones-list-with-4spots · https://selular.id/2026/02/top-10-smartphone-terlaris-2025-samsung-galaxy-a06-mendominasi/ · https://www.oficinadanet.com.br/smartphones/63559-market-share-celulares-julho-2025-brasil · https://olhardigital.com.br/2025/06/07/reviews/chinesa-supera-apple-em-ranking-de-marcas-que-mais-venderam-celulares-no-brasil/ · https://www.notebookcheck.net/Mediatek-Helio-G85-Processor-Benchmarks-and-Specs.494452.0.html · https://nanoreview.net/en/benchmark-ranking/samsung-galaxy-a06

Rede móvel: https://olhardigital.com.br/2025/09/08/internet-e-redes-sociais/qual-operadora-tem-a-internet-mais-rapida-no-brasil-estudo-responde/ · https://insights.opensignal.com/brazil · https://www.folhavitoria.com.br/geral/internet-movel-do-brasil-perde-para-paises-como-albania-e-bolivia/

Navegador: https://developer.chrome.com/blog/background_tabs · https://www.github.com/rameshvarun/netplayjs/issues/76 · https://web.dev/articles/gamepad · https://caniuse.com/gamepad · https://bugs.webkit.org/show_bug.cgi?id=212933 · https://caniuse.com/mdn-api_rtcdatachannel

Godot Web: https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/display_server_web.cpp · https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/js/libs/library_godot_display.js · https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html · relato de 31 → 60 FPS em Android por compressão de textura (só título lido; o fórum é bloqueado no container): https://forum.godotengine.org/t/godot-4-web-export-stutters-on-mobile-its-probably-your-art-pipeline-not-your-code-31fps-to-60fps-benchmarks-inside/143268 · iOS: https://forum.godotengine.org/t/webgl-context-loss-and-app-crash-in-godot-4-3-exported-web-on-ios-browsers/81024

Co-op e rede: https://developers2.airconsole.com/faq-help · https://www.gamedeveloper.com/design/airconsole-using-smartphones-as-controllers · https://www.tomsguide.com/reference/steam-remote-play-together-how-to-use · https://www.pcgamer.com/steams-remote-play-together-is-fiddly-but-still-a-great-way-to-play-couch-co-op-online · https://medium.com/@geretti/netcode-series-part-4-projectiles-96427ac53633 · https://www.pcgamer.com/au/netcode-explained · https://www.trustedreviews.com/reviews/magicka-2

Repositórios (conferidos com `git ls-remote`/clone): godot-debug-menu https://github.com/godot-extended-libraries/godot-debug-menu (MIT, v1.2.0) · godot-demo-projects https://github.com/godotengine/godot-demo-projects (MIT; `networking/webrtc_signaling`, commit `281a99f0`).

# Addons e plugins gratuitos do Godot 4 para o RPG de ação co-op

Pesquisa feita em 26/11/2026, no container do projeto (Godot 4.5.1 estável, sem GPU). Etapa só de pesquisa: nada foi instalado no repositório.

**Como ler:** tudo que está marcado "testado" foi executado aqui, no Godot 4.5.1 local, em modo headless. Tudo que está marcado "não verificado" veio só de README ou de conhecimento prévio.

## 1. Resumo executivo

1. **Conjunto enxuto recomendado: 4 addons de jogo + 2 ferramentas, todos GDScript puro.** Phantom Camera, Godot State Charts, G.U.I.D.E e Debug Menu; mais GUT e gdtoolkit. Dialogue Manager e netfox entram só quando história e co-op online entrarem no escopo. Os addons de jogo importaram limpos no 4.5.1 e subiram num export Web real aberto no Chrome headless.
2. **Evitar GDExtension (binário nativo) no núcleo.** LimboAI, Terrain3D e Debug Draw 3D trazem binários wasm, mas o export Web exige templates `web_dlink_*`, que não estão instalados aqui (só `web_nothreads_*`). Além disso, o carregamento desses binários não pôde ser testado nesta sessão (ver seção 5.5).
3. **O ecossistema já mira o Godot 4.6/4.7.** No 4.5.1 é preciso fixar versões antigas de três addons: GUT 9.5.0, Dialogue Manager 3.10.5 e LimboAI 1.6.0. A matriz de versões está na seção 4.
4. **Instalação headless tem três armadilhas, todas reproduzidas aqui:**
   - autoloads registrados em `_enable_plugin()` não são criados quando o plugin só é listado no `project.godot` (772 linhas de erro no primeiro import);
   - um arquivo `.blend` dentro de um addon (demos do Proton Scatter) trava `--import` para sempre;
   - o `--import` devolve código de saída 0 mesmo com centenas de erros, então é obrigatório ler o log.
5. **Vários "addons" não valem o risco, porque o motor ou 100 linhas de GDScript resolvem:** juice (hit-stop, tremor, squash), áudio adaptativo, loot, atributos e habilidades, física Jolt, ossos com mola.
6. **Limites desta pesquisa:** o orçamento de buscas na web da sessão acabou no meio do trabalho (as categorias juice, loot e GAS tiveram uma busca cada); `godotengine.org` e `phantom-camera.dev` não são alcançáveis daqui; o Godot 4.7.2 não foi testado.

## 2. Conjunto enxuto recomendado

Cada addon a mais é risco. A lista abaixo é o mínimo que paga o próprio custo.

### 2.1 Adotar desde o primeiro dia

| # | Addon | Versão fixada (commit) | Para quê neste jogo | Tamanho | Risco principal | Plano B |
|---|---|---|---|---|---|---|
| 1 | **Phantom Camera** | v0.12 (`0094dde`, 17/11/2026) | Câmera co-op que enquadra 2 a 4 jogadores (modo GROUP com distância automática), transições por prioridade, tremor por ruído | 1,4 MB sem exemplos (2,3 MB com) | Versão 0.x: a API muda entre versões menores. No editor, consulta a API do GitHub para checar atualização; aqui isso gera 1 `SCRIPT ERROR` inofensivo no primeiro import, mais 1 erro de `disconnect` ao fechar | Câmera de grupo própria, cerca de 150 linhas |
| 2 | **Godot State Charts** | v0.22.5 (`76d226a`, 26/06/2026) | Estados de jogador, inimigos e chefes (hierárquicos e paralelos), com depurador visual | 624 KB | Um nó por estado: custo por inimigo quando houver centenas na tela. Versão 0.x | `AnimationTree` embutido + máquina de estados simples em código |
| 3 | **G.U.I.D.E** | v0.15.1 (`b20f2d9`, 02/11/2026) | Entrada unificada teclado, mouse, gamepad e toque; contextos (jogo/menu); joystick e botões virtuais embutidos; gatilhos de combo (`A > B > A`), úteis para combinar elementos como em Magicka; ícones de botão automáticos; remapeamento | 2,7 MB | O próprio README avisa que "ainda não foi muito usado" e tem arestas. Toda a entrada passa por ele (aprisionamento). Ações e contextos são `Resource`, que o agente terá de gerar por script | `InputMap` embutido + Virtual Joystick do MarcoFazio (1 cena) + Controller Icons |
| 4 | **Debug Menu** (Calinou) | `ff12461` (19/11/2025) | FPS e gráfico de tempo de quadro na tela, inclusive no celular | 64 KB | Quase nenhum | Remover |
| 5 | **GUT** | 9.5.0 (`8255c63`) no 4.5; 9.6.1 no 4.6; 9.7.1 no 4.7 | Testes automáticos por linha de comando: é como o agente verifica o próprio trabalho | 3,1 MB (excluir do export) | Cada versão do GUT serve a uma única versão menor do Godot | gdUnit4 v6.2.3 (cobre 4.5 a 4.7) |
| 6 | **gdtoolkit** (PyPI) | 4.5.0 | `gdformat` e `gdlint` em um venv | — | Última versão é a 4.5.0; sintaxe nova do 4.6+ pode não ser reconhecida (não verificado) | GDQuest GDScript-formatter 0.28.0 (binário Rust) |

### 2.2 Adotar só quando a necessidade aparecer

| Addon | Versão | Quando entra | Risco |
|---|---|---|---|
| **Dialogue Manager** | 3.10.5 (4.4/4.5) ou 4.2.0 (4.6+) | Quando houver NPCs e história. Os diálogos são arquivos de texto `.dialogue`, ideais para um agente escrever | Duas linhas de versão conforme o motor; migrar de 3.x para 4.x muda formato (não verificado o quanto) |
| **netfox** (+ internals, + extras) | v1.49.12 (`6410867`, 23/11/2026) | Só se o co-op online entrar no escopo e precisar de predição no cliente e rollback | Registra 14 autoloads. A 1.49 reescreveu o núcleo ("servers"). `netfox.noray` só funciona com ENet/UDP, portanto não serve para Web |
| **Tube** | 1.1 (`b1785c9`, 27/09/2026) | Protótipo de co-op online pelo navegador sem servidor próprio (WebRTC + trackers WebTorrent públicos + STUN) | Depende de trackers de terceiros. Sem TURN, algumas redes móveis (CGNAT) não conectam. Não foi possível testar conexão daqui |
| **SimpleDungeons** | `15b3240` (02/04/2025), CC0 | Se o jogo for de masmorras procedurais com salas pré-fabricadas | Sem versões nem tags, parado desde abril de 2025. Os exemplos pesam 22 MB e devem ser apagados |
| **Beehave** | v2.9.3 (`773a5f6`, 18/08/2026) | Se a IA de chefes ou de companheiros ficar grande demais para State Charts | O README diz "4.5+ usa 2.10+", mas a 2.10 ainda não tem tag. Um erro inofensivo `Capture not registered: 'beehave'` ao sair |
| **Maaack's Scene Loader** (parte do Game Template) | 1.8.0 (`d6ea887`, 22/11/2026) | Tela de carregamento com carga em thread | O assistente de instalação é gráfico. Os menus prontos têm cara de template e precisam de pele própria |
| **LimboConsole** | v0.8.0 (`969f5d4`, 20/06/2026) | Console de cheats e depuração dentro do jogo | O plugin fica na raiz do repositório: clonar direto em `addons/limbo_console` |

### 2.3 Não adotar (e por quê)

| Addon | Motivo |
|---|---|
| LimboAI | Excelente, mas é binário nativo de 83 MB. Web exige templates `web_dlink_*`. Não testado aqui. Reavaliar só se o alvo for desktop |
| Terrain3D | Top-down em arenas e masmorras não precisa de terreno gigante. GDExtension; Web "very experimental" segundo a própria documentação |
| Dialogic 2 | Ainda alpha ("2.0-Alpha-21 WIP"), centrado no editor gráfico, API instável segundo o README |
| Cyclops Level Builder / FuncGodot | Edição manual no editor (Cyclops) ou no TrenchBroom (FuncGodot). O agente modela por script no Blender. Cyclops 1.5 exige Godot 4.7 |
| GodotSteam | O repositório do GitHub virou um aviso de mudança para o Codeberg, que é bloqueado aqui. Sem alvo Steam por enquanto |
| Nakama | Exige servidor próprio (Docker + banco). Fora do escopo de um jogo hospedado como página estática |
| GD-Sync | Licença "All rights reserved" e serviço de nuvem pago. Não é livre |
| FairFeelingLoot | Licença "All Rights Reserved". Não é livre, e é módulo C++ |
| OctoD godot-gameplay-systems | O próprio autor manda usar os sucessores em GDExtension. Último commit em 06/2025 |
| Pandora | Alpha (`1.0-alpha10`) |
| Resonate | Última versão em 08/03/2024. O áudio embutido do Godot cobre o caso |
| PankuConsole | Última versão em 04/07/2024. LimboConsole é o substituto ativo |
| Juicee, Saltmire Juice e similares | Projetos de 2026, sem histórico. Hit-stop e tremor são cerca de 100 linhas próprias, e a "assinatura" do jogo depende desse ajuste fino |
| Gaea 2.0 | Beta (`v2.0.0-beta6`), baseado em grafo editado à mão |
| MDunGen | C# |
| godot-procedural3d / FloorArchitect | Abandonados (2019 e 2023) |
| JFA motion blur | Só Forward+; o repositório redireciona para outro |
| godot-jolt | Jolt já vem no motor |

## 3. O que o motor já faz sem addon

Conferido nesta sessão:

- **Jolt Physics** é o padrão de novos projetos 3D no Godot 4.6, e o **4.6 trouxe um framework de IK** (`IKModifier3D`) — fonte: resumos do lançamento do 4.6 ([digitalproduction.com](https://digitalproduction.com/2026/01/28/godot-4-6-arrives-with-major-cg-friendly-updates/), [gdquest.com](https://gdquest.com/library/godot_4_6_workflow_changes)).
- **`Trail3D`** (rastro de espada, funciona em todos os renderers) só chega no **Godot 4.8**: o demo oficial `3d/trails` declara `config/features=("4.8")`. Até lá, rastro é malha própria ou o addon GPUTrail.
- **WebRTC é embutido no export Web**; fora da Web precisa do GDExtension `webrtc-native` (documentação oficial, via busca).
- O demo oficial **`networking/webrtc_signaling`** traz cliente e servidor de sinalização em GDScript (`server/ws_webrtc_server.gd`) e em Node (`server_node/`).

De conhecimento prévio, não reverificado nesta sessão: `SpringBoneSimulator3D` e `LookAtModifier3D` (4.4) para movimento secundário; `AudioStreamInteractive`/`Playlist`/`Synchronized` (4.3) para música adaptativa; `MultiplayerSpawner`/`MultiplayerSynchronizer`; `GridMap`; navegação com `NavigationAgent3D`; interpolação de física 3D (4.4).

## 4. Matriz de versões por versão do Godot

| Addon | Godot 4.5.1 (atual) | Godot 4.6.x | Godot 4.7.x | Fonte |
|---|---|---|---|---|
| Phantom Camera | v0.12 (selo "4.4+") — testado | v0.12 | v0.12 | README |
| Godot State Charts | v0.22.5 — testado | v0.22.5 | v0.22.5 | README |
| G.U.I.D.E | v0.15.1 (exige 4.2+) — testado | v0.15.1 | v0.15.1 | docs do repo |
| netfox | v1.49.12 — testado | idem | idem | FAQ: usa só a API multiplayer do Godot |
| Dialogue Manager | **v3.10.5** — testado | v4.2.0 | v4.2.0 | README: "v4 para 4.6+, v3.10 para 4.4/4.5" |
| GUT | **9.5.0** — testado | 9.6.1 | 9.7.1 | tabela do README |
| gdUnit4 | v6.2.3 | v6.2.3 | v6.2.3 (master 7.0 exige 4.7) | tabela do README |
| LimboAI | **v1.6.0** (`gdextension-4.4.zip`) | v1.6.0 a v1.8.1 | v1.8.1 | tabela do README |
| Beehave | v2.9.3 — testado | v2.9.3 | v2.9.3 | README |
| Maaack Game Template | v1.8.0 ("4.4+ compatible") — testado | v1.8.0 | v1.8.0 | README |
| Terrain3D | v1.1.0 (4.5 a 4.8) | v1.1.0 | v1.1.0 | notas da release |
| Debug Draw 3D | 1.7.3 (4.4.1+) | 1.7.3 | 1.7.3 | título da release |
| Cyclops | v1.0.2 | v1.0.2 | v1.5.2 | README |
| Tube | 1.1 — testado ("desenvolvido no 4.7.2") | 1.1 | 1.1 | README |

Colunas 4.6 e 4.7: só documentação, nada executado.

## 5. Testes práticos feitos

Diretório de trabalho: `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-addons/` (projetos `proj` e `proj2`, mais os logs).

### 5.1 Import headless com 14 plugins GDScript (`proj`)

Plugins: Phantom Camera, State Charts, netfox (+internals, +extras), G.U.I.D.E, Dialogue Manager 3.10.5, GUT 9.5.0, Virtual Joystick, Controller Icons, Debug Menu, GLoot, Beehave, LimboConsole.

| Passo | Resultado |
|---|---|
| 1º `godot --headless --path proj --import`, só com `[editor_plugins]` | Código de saída 0, mas **772 linhas com erro**: `Identifier "ControllerIcons" not declared` (89), `"GUIDE" not declared` (14), autoloads do netfox "not compiling" (165) |
| Efeito colateral | O editor **reescreveu o `project.godot`**, acrescentando os 14 autoloads do netfox e o do Debug Menu (esses plugins registram em `_enter_tree()`) |
| Declarei à mão os 7 autoloads restantes e rodei de novo | **Limpo**: 28 linhas de log, só avisos de vazamento ao sair e 1 erro inofensivo do Phantom Camera |

### 5.2 Teste de execução (`smoke.tscn`)

- 11 de 11 autoloads presentes.
- 27 de 27 classes instanciadas: `PhantomCamera3D`, `StateChart`, `BeehaveTree`, `RollbackSynchronizer`, `GUIDEAction`, `Inventory`, `VirtualJoystick`, `DialogueResource`, `GutTest` e outras.
- Um State Chart montado por código transicionou `Idle -> Run` ao receber o evento.

### 5.3 Câmera co-op, GUT, Web

| Teste | Resultado |
|---|---|
| Phantom Camera, modo GROUP com 4 alvos criados por código | A distância da câmera ao centro do grupo foi de 6,2 para 22,2 e 30,0 m quando o raio do grupo foi de 1 para 12 e 30 m |
| GUT por linha de comando (`-s res://addons/gut/gut_cmdln.gd -gdir=res://test -gexit`) | 3 de 3 testes passaram, 2 s no total |
| Export Web (`--export-release "Web"`, template `web_nothreads_release`) | 10 s. `index.wasm` 38,0 MB, `index.pck` 19,7 MB com todos os exemplos dos addons |
| Mesmo export aberto no Chrome headless (WebGL2 por SwiftShader) | Motor subiu em Compatibility; os 11 autoloads e as classes carregaram; o State Chart transicionou. `GutTest` falhou de propósito: `exclude_filter="addons/gut/*"` funcionou |
| gdtoolkit 4.5.0 em venv | `gdparse` aceitou sintaxe do 4.5 (`@abstract`, argumentos variádicos `...args`, `Dictionary[StringName, int]`); `gdlint` e `gdformat --check` rodaram |

### 5.4 Segundo projeto (`proj2`): menus, áudio, mundo, masmorra

Plugins: Maaack Game Template (+ Scene Loader, Music Controller, UI Sound Controller), Proton Scatter, SimpleDungeons, Tube, Resonate, PankuConsole, gdUnit4 6.2.3.

- **O import travou** (mais de 10 minutos, 3% de CPU). Causa isolada: `addons/proton_scatter/demos/assets/source.blend`. Apagando a pasta `demos/`, o import terminou em **7 s, sem erros**.
- 6 de 6 autoloads e 9 de 9 classes OK (`ProtonScatter`, `DungeonGenerator3D`, `TubeClient`, `SoundBank`, `GdUnitTestSuite`...).
- **SimpleDungeons gerou uma masmorra** de grade 12x3x12 com as salas de exemplo em **142 ms**: 7 salas e 62 corredores.
- O plugin do Maaack gravou sozinho `disable_install_wizard=true` no `project.godot`; o Resonate gravou configurações de áudio.

### 5.5 O que não foi possível testar

- **Carregar GDExtensions (LimboAI 1.6.0, Debug Draw 3D 1.7.3, Terrain3D 1.1.0):** o comando que importava o projeto com esses binários nativos foi negado pela política de permissões da sessão. Só conferi o conteúdo dos zips: os três trazem `linux.x86_64` e wasm (com e sem threads); `compatibility_minimum` é 4.2 (LimboAI), 4.4.1 (DD3D) e 4.5 (Terrain3D).
- **Godot 4.7.2:** baixar e executar outro binário do motor também foi negado.
- **Conexão de rede real** (netfox sobre WebRTC, Tube com trackers): a rede do container não permite.

## 6. Como instalar sem interface gráfica

O script abaixo foi executado como está num projeto vazio (`proj3` no diretório de testes): baixou os 5 addons em 4 s, o import levou 7 s e a cena de verificação rodou (3 autoloads, câmera de grupo ativa, State Chart transicionando). Sobraram só os erros inofensivos do Phantom Camera descritos na seção 2.1.

```bash
#!/usr/bin/env bash
# tools/fetch_addons.sh — versões fixadas para Godot 4.5.1
set -euo pipefail
DEST="projeto-coop/game/addons"; TMP="$(mktemp -d)"; mkdir -p "$DEST"
fetch() {  # fetch <dono/repo> <tag-ou-branch> <pasta-no-repo> [nome-destino]
  git -c advice.detachedHead=false clone -q --depth 1 --branch "$2" "https://github.com/$1.git" "$TMP/r"
  local name="${4:-$(basename "$3")}"
  rm -rf "${DEST:?}/$name"; cp -r "$TMP/r/$3" "$DEST/$name"; rm -rf "$TMP/r"
}
fetch ramokz/phantom-camera                 v0.12    addons/phantom_camera
fetch derkork/godot-statecharts             v0.22.5  addons/godot_state_charts
fetch godotneers/G.U.I.D.E                  v0.15.1  addons/guide
fetch godot-extended-libraries/godot-debug-menu master addons/debug_menu
fetch bitwes/Gut                            v9.5.0   addons/gut
# quando entrarem:
# fetch nathanhoad/godot_dialogue_manager   v3.10.5  addons/dialogue_manager
# fetch foxssake/netfox                     v1.49.12 addons/netfox            (+ netfox.internals, netfox.extras)
rm -rf "$DEST"/phantom_camera/examples      # exemplos incham o .pck
find "$DEST" -name '*.blend' -delete        # .blend trava o --import headless
```

Depois, no `project.godot`:

```ini
[autoload]
PhantomCameraManager="*res://addons/phantom_camera/scripts/managers/phantom_camera_manager.gd"
GUIDE="*res://addons/guide/guide.gd"
DebugMenu="*res://addons/debug_menu/debug_menu.tscn"
; DialogueManager="*res://addons/dialogue_manager/dialogue_manager.gd"

[editor_plugins]
enabled=PackedStringArray("res://addons/phantom_camera/plugin.cfg", "res://addons/godot_state_charts/plugin.cfg", "res://addons/guide/plugin.cfg", "res://addons/debug_menu/plugin.cfg", "res://addons/gut/plugin.cfg")
```

Regras:

1. Rodar `godot --headless --path <proj> --import` e **procurar `ERROR` no log**; o código de saída é sempre 0.
2. Declarar à mão os autoloads de plugins que registram em `_enable_plugin()`. Além dos acima: `ControllerIcons`, `BeehaveGlobalMetrics`, `BeehaveGlobalDebugger`, `LimboConsole`, `SceneLoader`, `MusicController`, `UISoundController`, `Panku`. Os caminhos exatos estão em `proj/project.godot` e `proj2/project.godot` do diretório de testes.
3. Fazer commit do `project.godot` depois do primeiro import, porque os plugins o alteram.
4. No preset Web, excluir `addons/gut/*` e apagar pastas de exemplos.
5. Fixar por tag e anotar o commit. `gd-plug` (MIT, 0.2.6) faz isso por linha de comando, mas um script de 20 linhas basta.
6. Para silenciar a checagem de atualização do Phantom Camera, existe a configuração `phantom_camera/updater/updater_mode` (0 desliga, segundo o código; não testado).

## 7. Candidatos levantados (77 repositórios, todos conferidos com `git ls-remote`)

Legenda — **Tipo:** GD = GDScript puro; GDE = GDExtension C++ com binários. **Web:** T = subiu no teste de Chrome headless; s = GDScript puro, deve funcionar, não testado; wasm = traz wasm, exige templates `dlink`, não testado; n = não. Datas são do commit da tag ou do HEAD.

### Câmera, IA e máquinas de estado

| Addon | Repositório | Licença | Versão (data) | Tipo | Web | Veredito |
|---|---|---|---|---|---|---|
| Phantom Camera | [ramokz/phantom-camera](https://github.com/ramokz/phantom-camera) | MIT | v0.12 (17/11/2026) | GD | T | **Adotar** |
| Godot State Charts | [derkork/godot-statecharts](https://github.com/derkork/godot-statecharts) | MIT | v0.22.5 (26/06/2026) | GD | T | **Adotar** |
| LimboAI | [limbonaut/limboai](https://github.com/limbonaut/limboai) | MIT | v1.8.1 (20/08/2026), 4.6+; v1.6.0 para 4.4 a 4.6 | GDE | wasm | Só desktop |
| Beehave | [bitbrain/beehave](https://github.com/bitbrain/beehave) | MIT | v2.9.3 (18/08/2026) | GD | T | Opcional |
| Steering AI Framework | [GDQuest/godot-steering-ai-framework](https://github.com/GDQuest/godot-steering-ai-framework) | MIT | sem versão (HEAD 13/09/2024) | GD | s | Não (era Godot 3) |

### Rede

| Addon | Repositório | Licença | Versão (data) | Tipo | Web | Veredito |
|---|---|---|---|---|---|---|
| netfox | [foxssake/netfox](https://github.com/foxssake/netfox) | MIT | v1.49.12 (23/11/2026) | GD | T (carga) | Condicional |
| noray | [foxssake/noray](https://github.com/foxssake/noray) | MIT | sem tags (HEAD 20/09/2026) | servidor | n (UDP) | Não |
| Tube | [koopmyers/tube](https://github.com/koopmyers/tube) | MIT | 1.1 (27/09/2026) | GD | s | Protótipo |
| Demos oficiais de rede | [godotengine/godot-demo-projects](https://github.com/godotengine/godot-demo-projects) (`networking/webrtc_signaling`) | MIT | tag `4.7-6ad6167` | GD + Node | s | **Referência** |
| webrtc-native | [godotengine/webrtc-native](https://github.com/godotengine/webrtc-native) | MIT | 1.2.2-stable, Godot 4.3+ | GDE | desnecessário na Web | Só fora da Web |
| Nakama | [heroiclabs/nakama-godot](https://github.com/heroiclabs/nakama-godot) | Apache-2.0 | v3.4.0 (HEAD 22/09/2026) | GD | s | Não (servidor) |
| GodotSteam | [GodotSteam/GodotSteam](https://github.com/GodotSteam/GodotSteam) (migrou para Codeberg) | MIT | v4.24 | GDE | n | Não |
| GD-Sync | [GD-Sync/GD-Sync](https://github.com/GD-Sync/GD-Sync) | proprietária | 1.0.2 | GD | s | Não |

### Entrada

| Addon | Repositório | Licença | Versão (data) | Tipo | Web | Veredito |
|---|---|---|---|---|---|---|
| G.U.I.D.E | [godotneers/G.U.I.D.E](https://github.com/godotneers/G.U.I.D.E) | MIT | v0.15.1 (02/11/2026) | GD | T | **Adotar** |
| Virtual Joystick | [MarcoFazioRandom/Virtual-Joystick-Godot](https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot) | MIT | 1.0, sem tags (19/01/2025) | GD | T | Plano B |
| Controller Icons | [rsubtil/controller_icons](https://github.com/rsubtil/controller_icons) | MIT | v3.1.8 (28/07/2026) | GD | T | Plano B (4,2 MB) |
| Input Helper | [nathanhoad/godot_input_helper](https://github.com/nathanhoad/godot_input_helper) | MIT | v4.7.0 (08/06/2025) | GD | s | Coberto pelo G.U.I.D.E |
| Virtual Joystick DX | [Repechul/virtual-joystick-dx](https://github.com/Repechul/virtual-joystick-dx) | MIT | 1.1c (24/10/2026), 4.6+ | GD | s | Não |
| Touch Input Manager | [Federico-Ciuffardi/GodotTouchInputManager](https://github.com/Federico-Ciuffardi/GodotTouchInputManager) | MIT | sem versão (24/06/2026) | GD | s | Só se houver gestos |

### Menus, diálogo e transições

| Addon | Repositório | Licença | Versão (data) | Tipo | Web | Veredito |
|---|---|---|---|---|---|---|
| Maaack's Game Template | [Maaack/Godot-Game-Template](https://github.com/Maaack/Godot-Game-Template) | MIT | v1.8.0 (22/11/2026) | GD | s | Só o Scene Loader |
| Maaack's Menus Template | [Maaack/Godot-Menus-Template](https://github.com/Maaack/Godot-Menus-Template) | MIT | v1.8.0 | GD | s | Opcional |
| crystal-bit template | [crystal-bit/godot-game-template](https://github.com/crystal-bit/godot-game-template) | MIT | 2026.06.0 | GD | s | Não |
| Scene Manager | [glass-brick/Scene-Manager](https://github.com/glass-brick/Scene-Manager) | MIT | 2.1.0 (20/08/2026) | GD | s | Opcional |
| Dialogue Manager | [nathanhoad/godot_dialogue_manager](https://github.com/nathanhoad/godot_dialogue_manager) | MIT | v4.2.0 (4.6+); v3.10.5 (20/07/2026) | GD | T (3.10.5) | **Adotar quando houver história** |
| Dialogic 2 | [dialogic-godot/dialogic](https://github.com/dialogic-godot/dialogic) | MIT | 2.0-Alpha-21 WIP, 4.5+ | GD | s | Não |

### Mundo e geração procedural

| Addon | Repositório | Licença | Versão (data) | Tipo | Web | Veredito |
|---|---|---|---|---|---|---|
| Terrain3D | [TokisanGames/Terrain3D](https://github.com/TokisanGames/Terrain3D) | MIT | v1.1.0-stable, 4.5 a 4.8 | GDE | wasm, "very experimental" | Não |
| Proton Scatter | [HungryProton/scatter](https://github.com/HungryProton/scatter) | MIT | `plugin.cfg` 4.2.0 (27/09/2026) | GD | s | Opcional; apagar `demos/` |
| Cyclops Level Builder | [blackears/cyclopsLevelBuilder](https://github.com/blackears/cyclopsLevelBuilder) | MIT | v1.5.2 (4.7+) | GD | s | Não |
| FuncGodot | [func-godot/func_godot_plugin](https://github.com/func-godot/func_godot_plugin) | MIT | 2025.12 | GD | s | Não |
| HTerrain | [Zylann/godot_heightmap_plugin](https://github.com/Zylann/godot_heightmap_plugin) | MIT | 1.8.1 dev (13/11/2026) | GD | não verificado | Não |
| Spatial Gardener | [dreadpon/godot_spatial_gardener](https://github.com/dreadpon/godot_spatial_gardener) | MIT | v1.4.1 (05/03/2025) | GD | s | Não |
| Sky3D | [TokisanGames/Sky3D](https://github.com/TokisanGames/Sky3D) | MIT | v2.1.0; suporta Compatibility | GD | s | Opcional |
| SimpleDungeons | [majikayogames/SimpleDungeons](https://github.com/majikayogames/SimpleDungeons) | CC0 | sem versão (02/04/2025) | GD | s | Opcional |
| Gaea | [gaea-godot/gaea](https://github.com/gaea-godot/gaea) | MIT | v2.0.0-beta6, 4.4+ | GD | s | Não |
| WFC | [AlexeyBond/godot-constraint-solving](https://github.com/AlexeyBond/godot-constraint-solving) | MIT | 1.7 (13/05/2025) | GD | s | Opcional (TileMap/GridMap) |
| MDunGen | [MuNgLo/MDunGen](https://github.com/MuNgLo/MDunGen) | MIT | 1.4 | C# | n | Não |
| FloorArchitect | [Drejzer/FloorArchitect](https://github.com/Drejzer/FloorArchitect) | MIT | 0.5.0a (10/12/2023) | GD | s | Não |
| procedural3d | [RodZill4/godot-procedural3d](https://github.com/RodZill4/godot-procedural3d) | MIT | Godot 3.1 (2019) | GD | n | Não |

### Sistemas de RPG

| Addon | Repositório | Licença | Versão (data) | Tipo | Web | Veredito |
|---|---|---|---|---|---|---|
| GLoot | [peter-kish/gloot](https://github.com/peter-kish/gloot) | MIT | v3.0.2 (05/07/2026), 4.4+ | GD | T | Só se houver inventário em grade |
| Inventory System | [expressobits/inventory-system](https://github.com/expressobits/inventory-system) | MIT | 0.9.x (19/02/2026) | GDE | não verificado | Não |
| Gameplay Systems | [OctoD/godot-gameplay-systems](https://github.com/OctoD/godot-gameplay-systems) | MIT | 0.20.5 (06/06/2025) | GD | s | Não |
| Gameplay Abilities | [OctoD/godot-gameplay-abilities](https://github.com/OctoD/godot-gameplay-abilities) | MIT | sem tag (19/01/2026) | GDE | não verificado | Não |
| Pandora | [bitbrain/pandora](https://github.com/bitbrain/pandora) | MIT | v1.0-alpha10 | GD | s | Não |
| Quest System | [shomykohai/quest-system](https://github.com/shomykohai/quest-system) | MIT | 2.0.2 (05/08/2026), 4.4+ | GD | s | Opcional |
| Health/HitBox/HurtBox | [cluttered-code/godot-health-hitbox-hurtbox](https://github.com/cluttered-code/godot-health-hitbox-hurtbox) | MIT | v5.0.4 (22/07/2026) | GD | s | Referência de leitura |
| Lootie | [ninetailsrabbit/Lootie](https://github.com/ninetailsrabbit/Lootie) | MIT | 1.1.0 (04/03/2025) | GD | s | Não (fazer próprio) |
| Inventory Forge | [Menkos/inventory-forge](https://github.com/Menkos/inventory-forge) | MIT | 1.2.0 (31/01/2026) | GD | s | Não |
| FairFeelingLoot | [sclark39/FairFeelingLoot](https://github.com/sclark39/FairFeelingLoot) | proprietária | 2023 | C++ | n | Não |
| SaveMadeEasy | [AdamKormos/SaveMadeEasy](https://github.com/AdamKormos/SaveMadeEasy) | MIT | 1.3 (01/01/2025) | GD | s | Não |

### Animação, juice e áudio

| Addon | Repositório | Licença | Versão (data) | Tipo | Web | Veredito |
|---|---|---|---|---|---|---|
| Wigglebone | [detomon/wigglebone](https://github.com/detomon/wigglebone) | MIT | v3.0.1 (11/05/2026) | GD | s | Preferir o `SpringBoneSimulator3D` embutido |
| GPUTrail | [celyk/GPUTrail](https://github.com/celyk/GPUTrail) | MIT | 0.1 (27/09/2026) | GD | não verificado em Compatibility | Avaliar no protótipo |
| Anima | [ceceppa/anima](https://github.com/ceceppa/anima) | MIT | `plugin.cfg` 0.6 (25/11/2026) | GD | s | Não (`Tween` basta) |
| Juicee | [Kelpekk/Juicee](https://github.com/Kelpekk/Juicee) | MIT | v2.0.1 (13/11/2026) | GD | s | Não |
| Saltmire Juice | [saltmire/saltmire-juice](https://github.com/saltmire/saltmire-juice) | MIT | 1.1.0 (18/08/2026), 4.6+ | GD | s | Não |
| Damage Numbers | [Minoqi/minos-damage-numbers-for-godot](https://github.com/Minoqi/minos-damage-numbers-for-godot) | MIT | 23/03/2024 | GD | s | Não |
| Destruction | [Jummit/godot-destruction-plugin](https://github.com/Jummit/godot-destruction-plugin) | MIT | 7.2 (23/06/2024) | GD | s | Opcional |
| GDQuest shaders | [GDQuest/godot-shaders](https://github.com/GDQuest/godot-shaders) | duas licenças (código e arte separados) | tag 1.0.0; HEAD 19/11/2026 | shaders | s | Referência de leitura |
| Aseprite Wizard | [viniciusgerevini/godot-aseprite-wizard](https://github.com/viniciusgerevini/godot-aseprite-wizard) | MIT | v9.8.0 (11/11/2026) | GD | n/a | Não (nosso pipeline não usa Aseprite) |
| JFA Motion Blur | [sphynx-owner/JFA_driven_motion_blur_addon](https://github.com/sphynx-owner/JFA_driven_motion_blur_addon) | MIT | 4.3 | GD | n (Forward+) | Não |
| Resonate | [hugemenace/resonate](https://github.com/hugemenace/resonate) | MIT | v2.4.0 (08/03/2024) | GD | s | Não |
| Sound Manager | [nathanhoad/godot_sound_manager](https://github.com/nathanhoad/godot_sound_manager) | MIT | v2.6.2 (29/03/2026) | GD | s | Opcional |

### Depuração, testes e ferramentas

| Addon | Repositório | Licença | Versão (data) | Tipo | Web | Veredito |
|---|---|---|---|---|---|---|
| GUT | [bitwes/Gut](https://github.com/bitwes/Gut) | MIT | 9.5.0 / 9.6.1 / 9.7.1 | GD | excluir | **Adotar** |
| gdUnit4 | [MikeSchulze/gdUnit4](https://github.com/MikeSchulze/gdUnit4) | MIT | v6.2.3 (01/11/2026) | GD | excluir | Plano B |
| Debug Menu | [godot-extended-libraries/godot-debug-menu](https://github.com/godot-extended-libraries/godot-debug-menu) | MIT | 1.2.0 (19/11/2025) | GD | T | **Adotar** |
| Debug Draw 3D | [DmitriySalnikov/godot_debug_draw_3d](https://github.com/DmitriySalnikov/godot_debug_draw_3d) | MIT | 1.7.3 (04/2026), 4.4.1+ | GDE | wasm | Não por ora |
| LimboConsole | [limbonaut/limbo_console](https://github.com/limbonaut/limbo_console) | MIT | v0.8.0 (20/06/2026) | GD | T | Opcional |
| PankuConsole | [Ark2000/PankuConsole](https://github.com/Ark2000/PankuConsole) | MIT | v1.7.9 (04/07/2024) | GD | s | Não |
| Log.gd | [russmatney/log.gd](https://github.com/russmatney/log.gd) | MIT | v0.3.0 (21/11/2026) | GD | s | Opcional |
| gdtoolkit | [Scony/godot-gdscript-toolkit](https://github.com/Scony/godot-gdscript-toolkit) | MIT | 4.5.0 no PyPI | Python | — | **Adotar** |
| GDScript Formatter | [GDQuest/GDScript-formatter](https://github.com/GDQuest/GDScript-formatter) | MIT | 0.28.0 (26/11/2026) | binário Rust | — | Plano B |
| gd-plug | [imjp94/gd-plug](https://github.com/imjp94/gd-plug) | MIT | 0.2.6 (23/05/2026) | GD | — | Opcional |

Também conferidos e descartados sem detalhe: `maktoobgar/scene_manager`, `KoBeWi/Godot-Universal-Fade`, `kenyoni-software/godot-addons`, `Zennyth/EnhancedAbility` (vazio), `godot-jolt/godot-jolt`, `Maaack/Godot-Minimal-Game-Template`.

## 8. Riscos gerais

| Risco | Detalhe | Mitigação |
|---|---|---|
| Plugins 0.x | Phantom Camera, State Charts e G.U.I.D.E ainda não têm 1.0 | Fixar tag e commit; esconder cada um atrás de uma camada fina do jogo (`CoopCamera`, `InputRouter`) |
| Troca de versão do Godot | GUT, Dialogue Manager e LimboAI trocam de linha de versão entre 4.5 e 4.6 | Decidir a versão do motor antes de instalar; seção 4 |
| Peso no celular | O `.pck` de teste ficou com 19,7 MB só de addons e exemplos; o `.wasm` tem 38 MB | Apagar exemplos, excluir testes do export, medir o `.pck` a cada addon novo |
| Online pelo navegador | Uma página estática não hospeda servidor WebSocket; trackers públicos são de terceiros; CGNAT de operadoras pode impedir WebRTC sem TURN | Co-op local primeiro; online é uma fase separada, com protótipo antes de prometer |
| Aparência genérica | Menus do Maaack e ícones do Controller Icons têm cara de template | Usar só a lógica; a pele é do jogo |
| Política "sem IA" do Maaack | O README diz que o template "shares a no AI/LLM-gen policy" e pede que violações sejam reportadas. O texto fala do conteúdo do próprio template; a licença MIT não restringe quem o usa | Manter a atribuição; não enviar contribuições geradas ao repositório dele |

## 9. Documentação e tutoriais dos escolhidos

- Phantom Camera: https://phantom-camera.dev/ (não alcançável daqui; exemplos em `addons/phantom_camera/examples`)
- Godot State Charts: https://derkork.github.io/godot-statecharts/ e vídeo https://www.youtube.com/watch?v=E9h9VnbPGuw
- G.U.I.D.E: https://godotneers.github.io/G.U.I.D.E/ (exemplo `touch_3d_controls` no repositório)
- netfox: https://foxssake.github.io/netfox/ ; vídeos https://youtu.be/GqHTNmRspjU (compensação de lag) e https://youtu.be/AplKwFtBMjU (template multiplayer)
- GUT: https://gut.readthedocs.io/en/latest/Command-Line.html
- LimboAI: https://limboai.readthedocs.io/
- Beehave: https://bitbra.in/beehave
- SimpleDungeons: https://www.youtube.com/watch?v=v58l05FsdPs e https://github.com/majikayogames/SimpleDungeons/wiki
- Terrain3D: https://terrain3d.readthedocs.io/en/latest/docs/mobile_web.html
- WebRTC no Godot: https://docs.godotengine.org/en/4.5/tutorials/networking/webrtc.html

## 10. Fontes

- READMEs, `plugin.cfg`, licenças e tags lidos direto dos repositórios listados na seção 7 (clones rasos e `raw.githubusercontent.com`).
- Páginas de releases: [LimboAI](https://github.com/limbonaut/limboai/releases), [netfox v1.49.12](https://github.com/foxssake/netfox/releases/tag/v1.49.12), [Terrain3D](https://github.com/TokisanGames/Terrain3D/releases), [Debug Draw 3D](https://github.com/DmitriySalnikov/godot_debug_draw_3d/releases), [webrtc-native](https://github.com/godotengine/webrtc-native/releases).
- Terrain3D, plataformas: `doc/docs/platforms.md` na tag v1.1.0-stable ("Compatibility renderer is fully supported since Terrain3D 1.0 and Godot 4.4"; "web exports are very experimental").
- netfox, FAQ: `docs/faq.md` ("Does netfox support android / iOS / web / ENet? Yes... builds on top of Godot's multiplayer API").
- Godot 4.6: https://digitalproduction.com/2026/01/28/godot-4-6-arrives-with-major-cg-friendly-updates/ e https://gdquest.com/library/godot_4_6_workflow_changes
- Tube na Asset Library: https://godotengine.org/asset-library/asset/4419
- Listas gerais: https://github.com/godotengine/awesome-godot ; https://gamineai.com/blog/16-free-godot-4-plugins-worth-installing-before-your-first-vertical-slice-2026
- Buscas de juice, loot e GAS (uma busca cada): https://github.com/Kelpekk/Juicee , https://github.com/ninetailsrabbit/Lootie , https://github.com/OctoD/godot-gameplay-abilities

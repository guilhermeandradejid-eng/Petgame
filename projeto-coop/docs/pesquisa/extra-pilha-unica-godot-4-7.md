# Pilha única validada: Godot 4.7.2 + addons fixados + regra de fps 60

Pesquisa complementar (lacuna do crítico de completude). Data: 27/11/2026. Diretório de testes (fora do repositório): `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-pilha-47/`.

Marcas: **[T]** testado aqui; **[R]** código-fonte ou arquivo lido no GitHub (com link); **[NV]** não verificado. O orçamento de buscas na web da sessão acabou antes desta etapa. Por isso as fontes são o código-fonte e os arquivos dos repositórios, lidos pelo `git`/`raw.githubusercontent.com`, mais os relatórios anteriores. Não foi possível confirmar se o problema do otimizador (seção 3.3) já está relatado no rastreador do Godot.

---

## 0. Decisões (o que esta etapa fecha)

| Pergunta | Decisão | Evidência |
|---|---|---|
| Versão do motor | **Godot 4.7.2-stable** para tudo: editor, import, testes e export Web | Addons importam com 0 erros; cena de verificação passa em Compatibility, Forward+ e Web (seção 2) [T] |
| Pins dos addons | Phantom Camera **v0.12**, State Charts **v0.22.5**, G.U.I.D.E **v0.15.1**, Debug Menu **commit `ff12461`** (não a tag v1.2.0), Beehave **v2.9.3**, GUT **v9.7.1** | Script de instalação da seção 1 [T] |
| Framework de teste | **GUT 9.7.1** (único). gdUnit4 v6.2.3 também passou e fica só como plano B documentado | Seção 2.4 [T] |
| Entrada por toque | **G.U.I.D.E (`GUIDEVirtualStick` / `GUIDEVirtualButton`)**. O `VirtualJoystick` nativo do 4.7 funciona, mas **não entra no G.U.I.D.E** | Seção 2.5 [T][R] |
| fps de animação | **60 no Blender e 60 no importador do Godot**, definido **uma vez** no `project.godot` | Seção 3 [T] |
| Condição nova e obrigatória | **Desligar o otimizador de animação do importador** (`optimizer/enabled=false`), também no `project.godot`. Com ele ligado (padrão), **um pico simétrico de 1 quadro (squash 0,6) some**, mesmo a 60 fps | Seção 3.3 [T][R] |
| Proibido para clipes em degrau | `compression/enabled=true` no import: converte trilhas `NEAREST` em `LINEAR` | Seção 3.4 [T] |

A regra de fps do `pipeline-blender.md` ("30 nos dois") e a do `animacao-principios.md` ("60 no import") convergem aqui em **60 nos dois, mais o otimizador desligado**. Com import a 30, a pose de 1 quadro desaparece e os degraus de 2/3 quadros ficam deslocados (erro de matriz até 1,12). A 60 com o otimizador padrão, o degrau CONSTANT fica exato, mas o pico Bezier simétrico some. Só a combinação 60 + otimizador desligado foi exata em todos os casos (erro 0,00000).

---

## 1. Instalação fixada para 4.7 (script executado)

Arquivo: `scratchpad/pesquisa-pilha-47/scripts/fetch_addons_47.sh`. Instalou os 7 repositórios em cerca de 6 s [T].

```bash
#!/usr/bin/env bash
# Conjunto enxuto fixado para Godot 4.7.x. Uso: fetch_addons_47.sh <dir-addons> [gut|gdunit|both]
set -euo pipefail
DEST="$1"; TEST="${2:-gut}"; TMP="$(mktemp -d)"; mkdir -p "$DEST"
fetch() {  # fetch <owner/repo> <tag-ou-sha-completo> <pasta-no-repo> [nome-destino]
  if [[ "$2" =~ ^[0-9a-f]{40}$ ]]; then  # commit exato (sem tag)
    git init -q "$TMP/r"; git -C "$TMP/r" fetch -q --depth 1 "https://github.com/$1.git" "$2"
    git -C "$TMP/r" -c advice.detachedHead=false checkout -q FETCH_HEAD
  else
    git -c advice.detachedHead=false clone -q --depth 1 --branch "$2" "https://github.com/$1.git" "$TMP/r"
  fi
  echo "$1 $2 $(git -C "$TMP/r" rev-parse --short HEAD) $(git -C "$TMP/r" log -1 --format=%cs)"
  local name="${4:-$(basename "$3")}"
  rm -rf "${DEST:?}/$name"; cp -r "$TMP/r/$3" "$DEST/$name"; rm -rf "$TMP/r"
}
fetch ramokz/phantom-camera                     v0.12   addons/phantom_camera
fetch derkork/godot-statecharts                 v0.22.5 addons/godot_state_charts
fetch godotneers/G.U.I.D.E                      v0.15.1 addons/guide
fetch godot-extended-libraries/godot-debug-menu ff124615a7da981722b3927343b9965a6a156718 addons/debug_menu
fetch bitbrain/beehave                          v2.9.3  addons/beehave
case "$TEST" in
  gut)    fetch bitwes/Gut v9.7.1 addons/gut ;;
  gdunit) fetch MikeSchulze/gdUnit4 v6.2.3 addons/gdUnit4 ;;
  both)   fetch bitwes/Gut v9.7.1 addons/gut; fetch MikeSchulze/gdUnit4 v6.2.3 addons/gdUnit4 ;;
esac
rm -rf "$DEST"/phantom_camera/examples
find "$DEST" -name '*.blend' -delete
rm -rf "$TMP"
```

### 1.1 O que cada pin trouxe (saída real do script) e licença

| Addon | Pin | Commit / data | Licença (arquivo na raiz, conferida) | Tamanho em `addons/` | Por que este pin |
|---|---|---|---|---|---|
| [Phantom Camera](https://github.com/ramokz/phantom-camera) | `v0.12` | `0094dde` 17/11/2026 | MIT | 1,4 MB | Última tag |
| [Godot State Charts](https://github.com/derkork/godot-statecharts) | `v0.22.5` | `76d226a` 26/06/2026 | MIT | 624 KB | Última tag |
| [G.U.I.D.E](https://github.com/godotneers/G.U.I.D.E) | `v0.15.1` | `b20f2d9` 02/11/2026 | MIT (`LICENSE.md`) | 2,7 MB | Última tag; a 0.15.0 corrigiu toque com dedo preso em stick virtual (#211, [CHANGES.md](https://github.com/godotneers/G.U.I.D.E/blob/main/CHANGES.md)) [R] |
| [Debug Menu](https://github.com/godot-extended-libraries/godot-debug-menu) | **`ff124615…`** (master) | `ff12461` 19/11/2025 | MIT (`LICENSE.md`) | 56 KB | A tag `v1.2.0` é de **15/12/2023** (`9d36ea2`). Depois dela entraram 7 commits, entre eles "Add check to fix error for single-threaded Web builds (#34)" e "Remove arrows in labels causing tofu to appear on Web builds (#38)" [R]. O export Web recomendado é sem threads, então o pin vai no commit |
| [Beehave](https://github.com/bitbrain/beehave) | `v2.9.3` | `773a5f6` 18/08/2026 | MIT | 676 KB | O README pede "4.5+ → 2.10+", mas não existe tag 2.10. O branch `godot-4.x` (`fe58915`) tem só 2 commits depois da 2.9.3: `@tool` num template e o número de versão "2.9.4-dev" [R]. A 2.9.3 rodou limpa no 4.7.2 [T] |
| [GUT](https://github.com/bitwes/Gut) | `v9.7.1` | `aeb5d4f` 09/07/2026 | MIT (`addons/gut/LICENSE.md`; não há arquivo de licença na raiz do repositório) | 3,2 MB | A tabela do README dá 9.7.1 = "godot_4_7 branch / 4.7.x"; o `main` é 4.6.x [R] |
| [gdUnit4](https://github.com/MikeSchulze/gdUnit4) (plano B) | `v6.2.3` | `f2e4f86` 01/11/2026 | MIT | 4,4 MB | O README de v6.2.3 lista compatibilidade até "v4.7, v4.7.1" (4.7.2 não aparece). Funcionou no 4.7.2 [T] |

Todos responderam a `git ls-remote <url> HEAD` [T].

### 1.2 `project.godot` mínimo (declarar autoloads à mão)

Os plugins Phantom Camera, G.U.I.D.E e Beehave registram autoload em `_enable_plugin()`, que **não roda** num `--import` sem interface. O Debug Menu registra em `_enter_tree()` (código lido em `plugin.gd` de cada addon) [R]. Declarar tudo à mão dá um import determinístico:

```ini
config_version=5

[application]
config/features=PackedStringArray("4.7", "GL Compatibility")

[autoload]
PhantomCameraManager="*res://addons/phantom_camera/scripts/managers/phantom_camera_manager.gd"
GUIDE="*res://addons/guide/guide.gd"
DebugMenu="*res://addons/debug_menu/debug_menu.tscn"
BeehaveGlobalMetrics="*res://addons/beehave/metrics/beehave_global_metrics.gd"
BeehaveGlobalDebugger="*res://addons/beehave/debug/global_debugger.gd"

[editor_plugins]
; GUT fica FORA da lista: a linha de comando do GUT funciona sem o plugin ligado (testado)
enabled=PackedStringArray("res://addons/phantom_camera/plugin.cfg", "res://addons/godot_state_charts/plugin.cfg", "res://addons/guide/plugin.cfg", "res://addons/debug_menu/plugin.cfg", "res://addons/beehave/plugin.cfg")

[importer_defaults]
; regra de animação da seção 3: vale para todo .glb/.gltf/.blend novo
scene={
"_subresources": {
"nodes": {
"PATH:AnimationPlayer": {
"optimizer/enabled": false
}
}
},
"animation/fps": 60.0
}

[phantom_camera]
updater/updater_mode=0   ; sem isso aparece 1 SCRIPT ERROR no import (seção 2.2)

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

Preset Web: `exclude_filter="addons/gut/*,addons/gdUnit4/*,test/*,tests_gdunit/*,reports/*"`, `variant/thread_support=false` e `custom_template/release` apontando para `web_nothreads_release.zip` do 4.7.2. O template foi extraído por HTTP Range, como descrito em `godot-render-vfx.md`, apêndice C.

---

## 2. Testes da pilha no 4.7.2

Binário: `Godot_v4.7.2-stable_linux.x86_64`, já baixado pelo relatório de render. Cena de verificação: `proj/check.gd`.

### 2.1 Resumo

| Etapa | Resultado | Tempo |
|---|---|---|
| `--headless --import`, projeto novo, com GUT e gdUnit4 ligados como plugins | Código de saída 0. **3 linhas `ERROR`**: 1 do GUT (`Could not get version info, response code: 403 (API rate limit exceeded…)`) e 2 de um erro de tipo meu na cena, corrigido | 9,2 s |
| `--import`, projeto novo (`proj2`), **sem** os plugins de teste e com `updater_mode=0` | **0 linhas `ERROR`** | 6,5 s |
| Mesmo projeto sem `[phantom_camera] updater/updater_mode=0` (`proj3`) | 1 `SCRIPT ERROR` do updater do Phantom Camera: `Trying to assign value of type 'Dictionary' to a variable of type 'Array'` em `update_button.gd:62`. É a resposta de limite de taxa da API do GitHub | — |
| Cena de verificação, Compatibility (OpenGL por software, Xvfb) | 17 de 17 checagens OK (tabela 2.3) | < 5 s |
| Mesma cena, **Forward+** (Vulkan llvmpipe) | Mesmos resultados | — |
| GUT 9.7.1 por linha de comando (`-s res://addons/gut/gut_cmdln.gd -gdir=res://test -gexit`) | 4/4 testes passaram, código 0; com teste falhando de propósito, código **1** | 1,6 s |
| gdUnit4 6.2.3 (`-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://tests_gdunit --ignoreHeadlessMode`) | 3/3 passaram, código 0; com falha proposital, código **100**; gera relatório HTML e XML em `res://reports/` | 1,7 s |
| Export Web (`--export-release Web`, sem threads) | Código 0, 0 erros. `index.wasm` 39.514.754 B; `index.pck` 1,6 MB. Pastas de teste ausentes do `.pck`: só restam as menções em `editor_plugins` | 7,5 s |
| Web no Chrome 153 headless (WebGL2 por ANGLE/SwiftShader), aberto por DevTools Protocol | Motor em `gl_compatibility`, os 5 autoloads presentes, `res://addons` = `beehave,debug_menu,godot_state_charts,guide,phantom_camera`, `OS.has_feature`: `web,template`. Sem exceção JS nem `ERROR` no console | primeira tela em ~5 s |
| Web com **toque real do navegador** (`Input.dispatchTouchEvent`, 2 dedos simultâneos) | Stick do G.U.I.D.E = `(0.8, 0.0)`; `VirtualJoystick` nativo = `(0.0, -1.0)` | — |

Captura com o Debug Menu visível na Web: `scratchpad/pesquisa-pilha-47/out/web_touch_dm.png`. O painel desenha FPS, tempos e gráficos. A linha "Loading hardware information..." continuou presa no build sem threads até o quadro 70 [T]; se ela termina depois, ficou [NV].

### 2.2 Erros inofensivos conhecidos (filtrar na verificação automática)

| Mensagem | Origem | Quando aparece | Tratamento |
|---|---|---|---|
| `[GUT] Could not get version info, response code: 403` | `addons/gut/update_detector.gd:195`: o plugin consulta a API do GitHub uma vez por dia | Só com o plugin do GUT ligado no editor | Não ligar o plugin; a linha de comando não precisa dele [T] |
| `SCRIPT ERROR … update_button.gd:62` | Updater do Phantom Camera | Import com o plugin ligado e sem configuração | `phantom_camera/updater/updater_mode=0` [T] |
| `Can't send message. No active debugger` | `beehave/debug/debugger_messages.gd`: `can_send_message()` testa `OS.has_feature("editor")`, e `EngineDebugger.send_message` falha sem depurador ([core_bind.cpp 4.7.2, linha 2222](https://github.com/godotengine/godot/blob/4.7.2-stable/core/core_bind.cpp)) [R] | Só rodando a cena com o binário de **editor** sem `-d`. No template de export não ocorre (o console da Web ficou limpo) [T] | Ignorar, ou rodar a verificação com `--debug` |
| `Capture not registered: 'beehave'` | Beehave ao sair | Toda saída | Ignorar |
| `N ObjectDB instances leaked` / `1 resources still in use at exit` | Saída de cena de teste | Saída | Ignorar |

Regra para o verificador automático: falhar em `SCRIPT ERROR` e `Parse Error` sempre; em `ERROR:` só fora da lista acima.

### 2.3 O que a cena de verificação exercita (todas OK no 4.7.2)

`engine = 4.7.2-stable (official)`; 5 autoloads; `PhantomCamera3D` em modo GROUP com 4 alvos ativo e câmera a y = 30,6; State Chart `Idle -> Attack` por evento; `BeehaveTree` com `SequenceComposite` e folha própria (73 ticks em ~40 quadros); `GUIDEAction` AXIS_2D mapeada a `GUIDEInputJoyAxis2D(joy_index = -2)` (stick virtual 1) com `is_triggered() = true`; `ClassDB.class_exists("VirtualJoystick") = true`; `Viewport.SCALING_3D_MODE_NEAREST` aceito; SSAO ligado no `Environment` sem erro no Compatibility.

### 2.4 Um só framework de teste: GUT 9.7.1

| Critério | GUT 9.7.1 | gdUnit4 6.2.3 |
|---|---|---|
| Rodou no 4.7.2 | Sim [T] | Sim [T] |
| Amarração de versão | 1 linha por versão menor (9.7.x ↔ 4.7.x) [R] | Uma versão cobre 4.5 a 4.7.1 (4.7.2 não listado) [R] |
| Código de saída na falha | 1 | 100 |
| Tempo do conjunto | 1,6 s | 1,7 s |
| Precisa do plugin ligado | Não [T] | Não (rodou pela `GdUnitCmdTool.gd`) |
| Toque injetado por `Input.parse_input_event` em `--headless` | Funciona: G.U.I.D.E 0,8 e nativo 1,0 [T] | Funciona: mesmos valores [T] (o próprio gdUnit4 avisa que eventos não chegam em headless, mas para esse caso chegaram) |
| Efeito colateral | Nenhum | Grava `res://reports/` no projeto (precisa ir ao `.gitignore` e ao filtro de export) |
| Já recomendado em `addons-godot.md` | Sim | Plano B |

**Escolha: GUT 9.7.1.** Os dois funcionam, então decide a continuidade com o relatório de addons, a saída 0/1 mais simples e a ausência de arquivos gerados. Custo conhecido: ao migrar para o 4.8, trocar o GUT junto com o motor.

Armadilha medida: rodando o GUT **com janela** (Xvfb), o painel do GUT fica por cima e **engole o `gui_input`**. O `VirtualJoystick` nativo leu 0,0. O stick do G.U.I.D.E, que usa `_input`, leu 0,8. Com o `CanvasLayer` do teste em `layer = 128`, ou em `--headless`, os dois leem certo [T]. Regra: testes de entrada sempre em `--headless`.

### 2.5 Um só caminho de toque: G.U.I.D.E

| Aspecto | `GUIDEVirtualStick` / `GUIDEVirtualButton` (G.U.I.D.E 0.15.1) | `VirtualJoystick` nativo (4.7) |
|---|---|---|
| Como entrega a entrada | Cria um **joypad virtual** (ids −2 a −5) no estado de entrada do G.U.I.D.E. Qualquer `GUIDEInputJoy*` com `joy_index` "Virtual N" o lê, nos mesmos contextos de mapeamento do teclado e do controle [R: `guide_virtual_joy_base.gd`, `guide_input_joy_base.gd`] | Chama `Input.action_press(action_left…)` nas ações do **InputMap** ([virtual_joystick.cpp 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/gui/virtual_joystick.cpp), linhas 145–166) [R] |
| Integra com o G.U.I.D.E | Sim, nativamente | **Não**. O G.U.I.D.E lê eventos brutos (tecla, eixo, toque) e ações do próprio G.U.I.D.E (`GUIDEInputAction`), não ações do InputMap [R]. Usar os dois exigiria duas camadas de entrada |
| Prioridade de evento | `_input` (antes da GUI), consome o evento | `gui_input` (Control): qualquer Control por cima bloqueia (visto no teste 2.4) |
| Modos | FIXED, RELATIVE; raio de interação; 4 sticks; `input_mode` toque, mouse ou ambos | Fixed, Dynamic, Following; zona morta; clamp; visível só ao tocar; sinais `tapped` e `flicked` |
| Visual | Renderizador por textura ou `draw_debug`. O agente gera as texturas por script | Tema por StyleBox |
| Multitoque real na Web | OK (0,8) [T] | OK (−1,0) [T] |
| Exemplos | `guide_examples/virtual_sticks`, `touch`, `touch_3d_controls` (0.15.0) no repositório; docs: https://godotneers.github.io/G.U.I.D.E/usage/virtual-joysticks [R] | Docs 4.7 `class_virtualjoystick` (ver `coop-rede.md`) |

**Escolha: G.U.I.D.E.** Uma camada só (`InputRouter` → contextos G.U.I.D.E) para teclado, controle, toque e remapeamento. O `VirtualJoystick` nativo fica de fora; o "dinâmico" (stick aparece onde o polegar encosta), recomendado em `coop-rede.md`, equivale ao modo `RELATIVE` com `interaction_zone_radius` grande. "Flick" e "tap" saem dos *triggers* do G.U.I.D.E (`tap_and_hold` nos exemplos) [R, comportamento equivalente NV].

---

## 3. Squash por escala de osso e degraus NEAREST a 60 fps (Blender 5.3 × Godot 4.7.2)

### 3.1 Montagem

- `scripts/rig60.py` (bpy, 0,8 s): cena **60 fps**, quadros 0–30. Osso `root`; `body` (filho, recebe a escala com volume preservado `sx = sz = 1/√sy`); `arm` (filho de `body`, `inherit_scale='FULL'`, girado, portanto herda escala não uniforme com cisalhamento); `fx` (translação). Malha mínima pesada em todos.
- 4 actions:
  - `Spike1f_Bezier`: chaves nos quadros 10 (1,0), **11 (0,6)** e 12 (1,0). Pose de 1 quadro simétrica, Bezier.
  - `Spike1f_AsymBezier`: 10 (1,0), 11 (0,6), 14 (1,0).
  - `Spike1f_Const`: igual à simétrica, com chaves `CONSTANT`.
  - `Stepped_Const`: 11 chaves `CONSTANT` com holds de 2, 3 e 4 quadros, squash 0,6 / 1,3 / 0,8 / 1,25, braço de −35° a 60°.
- Verdade do Blender: `pose.bones[b].matrix` em todo quadro inteiro e meio quadro (`frame_set(f, subframe=0.5)`).
- Export GLB, modo ACTIONS, nas variantes `export_force_sampling=True` e `False`. glTF resultante [T]:
  - amostrado: trilhas animadas `LINEAR` (Bezier) ou `STEP` (CONSTANT), 31 amostras com t = f/60;
  - não amostrado: `CUBICSPLINE` (Bezier) ou `STEP`, só nas chaves.
- Godot 4.7.2: `scripts/dump_godot.gd` faz `seek(t, true, true)` para cada tempo e lê `get_bone_global_pose`. Conversão: Godot = C·(Blender), com C = (x, z, −y) aplicado à rotação e à origem e a base do osso mantida. Também simula a reprodução do jogo com `advance()` a 60 Hz, a 30 Hz e a 60 Hz com ±2 ms de variação.
- Variantes de import:
  - `imp60`: `importer_defaults` com fps 60;
  - `imp60noopt`: fps 60 e otimizador desligado no `.import`;
  - `impDef`: os dois no `project.godot` (bloco da seção 1.2);
  - `impPre`: `.import` escrito antes do primeiro import;
  - `imp30`: padrão;
  - `impComp`: fps 60, otimizador desligado, compressão ligada.

### 3.2 Resultado: erro máximo da matriz de osso (todos os ossos, quadros inteiros 0 a 30)

GLB amostrado (`export_force_sampling=True`):

| Import | Spike1f_Bezier (simétrico) | Spike1f_AsymBezier | Spike1f_Const | Stepped_Const | Chaves de `body.scale` (sim. / degrau) |
|---|---|---|---|---|---|
| **fps 30** (padrão do Godot) | **0,830** (pico perdido) | 0,574 | **0,830** (pico perdido) | **1,118** (holds deslocados) | 1 / 16 |
| fps 60, otimizador padrão (ligado) | **0,400** (squash 0,6 virou 1,0; o braço também perdeu os 40°) | **0,00000** | **0,00000** | **0,00000** | 3 / 20 |
| **fps 60 + otimizador desligado** (`imp60noopt`, `impDef`, `impPre`) | **0,00000** | **0,00000** | **0,00000** | **0,00000** | 31 / 31 |
| fps 60 + otimizador desligado + **compressão** | 0,00009 | 0,00013 | 0,00009 em quadro inteiro; **0,438 em meio quadro** | 0,00014 em quadro inteiro; **0,598 em meio quadro** | trilhas viraram `LINEAR` |

GLB não amostrado: mesmos números para Const e Stepped; `AsymBezier` com 0,055 (o Godot reamostra o `CUBICSPLINE` e não reproduz exatamente a Bezier do Blender). **Usar sempre `export_force_sampling=True`.**

Meio quadro (`f + 0,5`): trilhas `NEAREST` exatas (0,0000), porque o Blender CONSTANT e o Godot NEAREST seguram a pose até o quadro seguinte. Trilhas `LINEAR` diferem da Bezier entre amostras (0,049 no assimétrico), como esperado.

A cadeia com cisalhamento herdado (`arm` sob `body` não uniforme, `inherit_scale='FULL'`) chega **exata** (0,00000). Isso confirma, a 60 fps e no 4.7.2, o resultado do `pipeline-blender.md` no 4.5.1.

### 3.3 Causa do pico perdido: otimizador de animação do importador

- O importador de cena tem, por `AnimationPlayer`, `optimizer/enabled = true` por padrão, com `max_velocity_error 0.01`, `max_angular_error 0.01` e `max_precision_error 3` ([resource_importer_scene.cpp 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/import/3d/resource_importer_scene.cpp), linhas 1318–1324 e 2328–2331) [R].
- `Animation::_vector3_track_optimize_key` ([animation.cpp 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/resources/animation.cpp), a partir da linha 4189) compara só o **módulo** das velocidades antes de olhar a direção:

```cpp
// Calc velocities.
Vector3 vc0 = (t1.value - t0.value) / (t1.time - t0.time);
Vector3 vc1 = (t2.value - t1.value) / (t2.time - t1.time);
double v0 = vc0.length();
double v1 = vc1.length();
// Avoid zero div but check equality.
if (std::abs(v0 - v1) < p_allowed_precision_error) {
    return true;            // chave t1 considerada redundante
}
```

- Num pico em V simétrico (1,0 → 0,6 → 1,0, um quadro para descer e um para subir), as velocidades têm o mesmo módulo e sentidos opostos. A chave do meio é apagada. O mesmo vale para a rotação do braço: 0° → 40° → 0°, `_quaternion_track_optimize_key`.
- Trilhas `NEAREST` retornam antes desse teste (`if (p_is_nearest) return false;`), por isso o degrau CONSTANT sobreviveu.
- O mesmo trecho existe em `4.5.1-stable` e no `master` atual [R]. Não verifiquei se há issue aberta, porque a busca na web acabou nesta sessão [NV].
- Na prática: impacto, smear e overshoot de 1 quadro, desenhados como no `animacao-principios.md`, somem sem aviso com o import padrão, mesmo a 60 fps.

Correção validada [T], em ordem de preferência:

1. **`[importer_defaults] scene={"_subresources": {"nodes": {"PATH:AnimationPlayer": {"optimizer/enabled": false}}}, "animation/fps": 60.0}` no `project.godot`.** O Godot gravou os dois valores em cada `.import` novo e o resultado foi exato.
2. Pipeline gera o `.import` antes do primeiro import (`[remap] importer="scene"` + `[params]` com `animation/fps=60.0` e o mesmo `_subresources`). O Godot completou o arquivo (uid etc.) e manteve as opções.
3. Não usar `EditorScenePostImport` para isso: ele roda depois do otimizador.

Custo: sem otimizador, toda trilha fica com 1 chave por quadro. Medido: `.scn` de 3,9 KB → 4,8 KB neste rig de 4 ossos e 4 clipes. Para estimar o projeto real: 60 chaves/s × trilhas animadas × cerca de 16–20 B por chave ([C]: um herói com 30 ossos × 3 trilhas × 1 s ≈ 100 KB por segundo de animação, sem compressão; [NV] no projeto real). Se pesar, a saída é desligar o otimizador só nos clipes de combate e manter nos de locomoção, via `_subresources` → `"animations"` por clipe [NV].

### 3.4 Compressão de animação: não usar em clipe em degrau

`compression/enabled=true` trocou todas as trilhas para `LINEAR` (tipo 1). Nos quadros inteiros o erro é só de quantização (≤ 0,00014). Entre quadros, o degrau vira rampa: erro 0,598 em meio quadro no `Stepped_Const`. Com ±2 ms de variação, o hold de 0,6 apareceu em 9 amostras em vez de 10 [T]. Mantém o que está no `pipeline-blender.md`: sem compressão nesses clipes.

### 3.5 Reprodução em tempo real: o import exato não garante que o quadro apareça

Simulação com `AnimationPlayer.advance(dt)` a partir de t = 0 (GLB amostrado, import correto) [T]:

| Reprodução | Spike1f_Bezier | Spike1f_Const | Stepped_Const (amostras em 0,6) |
|---|---|---|---|
| 60 Hz estável | mínimo 0,6, 1 amostra | mínimo 0,6, 1 amostra | 10 |
| 60 Hz ±2 ms | mínimo **0,628** (a rampa linear foi amostrada fora do pico) | **0,6** (o NEAREST segura o quadro inteiro) | 10 |
| **30 Hz** (celular que caiu para 30 fps) | **1,0: pico invisível** | **1,0: pico invisível** | 5 |

Robustez a erro de ponto flutuante:

- A busca de chave do Godot usa `Math::is_equal_approx` no tempo (`Animation::_find`, animation.cpp linha 2399). O acúmulo de 1/60 não "perde" o degrau por arredondamento [R].
- O bake do glTF (`_interpolate_track`, gltf_document.cpp linha 5001) compara `float` com o tempo acumulado em `double` sem epsilon. Mesmo assim, no teste nenhum degrau escorregou de quadro: 0,00000 em todos os 31 quadros [T].

Regras para a animação:

1. **Pose de impacto ou smear com hold mínimo de 2 quadros a 60 (33 ms), em CONSTANT.** Assim ela aparece mesmo se o jogo cair para 30 fps.
2. Quando 1 quadro for indispensável, garantir pelo código: o hit-stop congela o `AnimationPlayer` (`speed_scale = 0`) no quadro do evento, disparado pela trilha de método. O quadro fica na tela pelos 3 a 6 quadros do hit-stop, qualquer que seja o fps.
3. Picos Bezier de 1 quadro só servem para curvas secundárias. Para o pico que importa, CONSTANT.

### 3.6 Configuração final do pipeline de animação

| Onde | Valor |
|---|---|
| Blender | `scene.render.fps = 60`, `fps_base = 1`, clipes começando no quadro 0 |
| Exportador glTF | `export_animation_mode='ACTIONS'`, **`export_force_sampling=True`**, `export_frame_step=1` (mais `export_hierarchy_flatten_bones=True` quando houver ossos guiados por constraint, conforme `pipeline-blender.md`) |
| Godot `project.godot` | `[importer_defaults] scene = { animation/fps: 60, _subresources.nodes."PATH:AnimationPlayer".optimizer/enabled: false }` |
| Import, por arquivo | Sem `compression/enabled` em clipes com degrau |
| Teste de regressão | `rig60.py` + `dump_godot.gd` + `compare.py` (tolerância 1e-4 em quadro inteiro; NEAREST também em meio quadro); falhar o build se `body.scale` tiver menos chaves que quadros |

---

## 4. Riscos e pontos em aberto

| Ponto | Estado |
|---|---|
| Celular real (toque, WebGL2 em GPU móvel) | [NV]: só Chrome headless com SwiftShader e toque emulado pelo DevTools |
| Bug do otimizador já relatado no rastreador do Godot | [NV] (sem busca na web nesta etapa). Vale abrir issue com o rig de 4 ossos como reprodução mínima |
| gdUnit4 6.2.3 oficialmente até 4.7.1 | Funcionou no 4.7.2 [T]; só importa se virar plano A |
| Beehave 2.10 (pedida pelo README para 4.5+) | Não existe tag; 2.9.3 testada e limpa no 4.7.2 [T] |
| Debug Menu "Loading hardware information..." na Web sem threads | Presa até o quadro 70 [T]; se carrega depois, [NV]. Só cosmético |
| Memória das animações sem otimizador num elenco completo | Estimativa [C]; medir no protótipo |
| `GUIDEVirtualStick` com tema próprio (texturas geradas por script) | Não testado visualmente; usei `draw_debug` |
| Desempenho | Nada medido aqui. Ver `extra-contexto-real-celular-coop.md` |

## 5. Arquivos dos testes

Tudo fica em `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-pilha-47/`:

- `scripts/`:
  - `fetch_addons_47.sh`, `rig60.py`, `dump_godot.gd`, `compare.py` e `gltfinfo.py`;
  - `cdp_check.mjs` (Chrome por DevTools Protocol, com `Input.dispatchTouchEvent` multitoque).
- `proj/` (pilha + GUT + gdUnit4), `proj2/` (pilha final, sem plugins de teste ligados, 0 erros de import) e `proj3/` (prova do updater do Phantom Camera).
- `imp30/`, `imp60/`, `imp60noopt/`, `impDef/`, `impPre/` e `impComp/`: projetos de import da seção 3.
- `blender/`: GLBs e `blender_truth.json`.
- `web/`: export 4.7.2.
- `out/`: `web_touch.png` e `web_touch_dm.png`.
- Logs: `import*.log`, `gut*.log`, `gdunit*.log`, `p2_*.log` e `export*.log`.

Fontes de código lidas (GitHub, tag `4.7.2-stable`):
- https://github.com/godotengine/godot/blob/4.7.2-stable/scene/resources/animation.cpp
- https://github.com/godotengine/godot/blob/4.7.2-stable/editor/import/3d/resource_importer_scene.cpp
- https://github.com/godotengine/godot/blob/4.7.2-stable/modules/gltf/gltf_document.cpp
- https://github.com/godotengine/godot/blob/4.7.2-stable/scene/gui/virtual_joystick.cpp
- https://github.com/godotengine/godot/blob/4.7.2-stable/core/core_bind.cpp

Repositórios dos addons: tabela 1.1. Mudanças do G.U.I.D.E: https://github.com/godotneers/G.U.I.D.E/blob/main/CHANGES.md . Tabela de versões do GUT: https://github.com/bitwes/Gut (README). Compatibilidade do gdUnit4: https://github.com/MikeSchulze/gdUnit4/blob/v6.2.3/README.md . Compatibilidade do Beehave: https://github.com/bitbrain/beehave (README).

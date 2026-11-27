# Ferramentas para o agente construtor: skills, MCP, qualidade, verificação visual, áudio e texturas

Pesquisa feita em 27/11/2026 neste container (4 CPUs, sem GPU, Godot 4.5.1, Blender 5.3 como módulo `bpy`). Tudo marcado **[teste]** foi executado aqui. Os scripts, as saídas e o venv ficaram em `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-ferramentas/`. Onde não consegui confirmar algo, está escrito **não verificado**.

Este relatório complementa `addons-godot.md` (GUT, gdtoolkit e addons do jogo), `pipeline-blender.md` (bake e render no Cycles) e `godot-render-vfx.md` (Movie Maker, seção 11). Para não repetir, ele aponta para esses arquivos.

---

## 1. Resumo executivo

1. **Servidores MCP de Godot e Blender servem pouco aqui.** Todos os que encontrei foram feitos para quem tem o editor ou o Blender abertos numa tela. O `blender-mcp` (ahujasid), o conector oficial Blender para o Claude e o `tomyud1/godot-mcp` dependem de um addon rodando dentro da interface gráfica, ligado por socket ou WebSocket. O `Coding-Solo/godot-mcp` só embrulha `godot --headless --script`, coisa que o agente já faz pelo Bash, e sem o custo de mudar a configuração do Claude Code. **Veredito: não instalar nenhum.**
2. **Algumas skills valem como leitura, não como dependência.** Pacotes úteis: `htdt/godogen` (MIT; receitas de captura e armadilhas do motor, que confirmei aqui), `anthropics/skills` (Apache-2.0; `skill-creator` para escrever as skills do próprio projeto e `webapp-testing`, com Playwright, para testar o export Web) e `Randroids-Dojo/Godot-Claude-Skills` (MIT, descontinuado; gdUnit4 e export). O `thedivergentai/gd-agentic-skills` tem 184 skills sob LGPL-3.0 e custa muitos tokens. O `xlanstar/godot-skills` mira o Godot 4.7+ e **não tem licença**, então não deve ser copiado. A melhor "skill" é a que o projeto escrever para si: captura, comparação de imagens, render de áudio e lint, cada uma com um script testado.
3. **A verificação visual automática funciona bem e é determinística [teste].** Com `--write-movie --fixed-fps` sob Xvfb, duas execuções do renderer Compatibility deram **quadros idênticos byte a byte** (SSIM 1,0000; 0 pixels diferentes). Quadros vizinhos deram SSIM 0,9949. Compatibility e Forward+ deram imagens **muito diferentes** na mesma cena (SSIM 0,48; fundo bem mais claro no Compatibility). Logo, cada renderer precisa das próprias imagens de referência ("golden"). O Playwright com o Google Chrome do sistema abriu o export Web do Céu Arcano emulando um Pixel 7 e tirou o print em 14 s.
4. **Qualidade de GDScript [teste].** O `gdlint` e o `gdformat` (gdtoolkit 4.5.0) varreram os 31 scripts do Céu Arcano em cerca de 2 s cada: 222 avisos (175 de linha longa) e 30 arquivos a reformatar. O gdUnit4 v6.2.3 rodou headless no 4.5.1 (2 de 2 testes, 1,7 s) e gerou `results.xml` (JUnit) e um relatório HTML. O `godot --doctool` gera a referência completa da API (1.011 XML, 6,6 MB) em 1,3 s, o que contorna o bloqueio de docs.godotengine.org.
5. **O áudio pode subir muito de nível sem numpy puro [teste].** Funcionaram FluidSynth 2.3.4 com GeneralUser GS (soundfont GM de 32 MB, uso livre), a biblioteca orquestral VSCO-2-CE (**CC0**, samples reais de cordas, metais e tímpanos), pedalboard 0.9.26 (efeitos de estúdio JUCE), DawDreamer 0.9.0 com Faust, Csound 6.18 e SoX 14.4.2. Os pacotes de sistema foram extraídos de `.deb` do apt para a pasta de scratch, sem instalar nada no sistema. Há uma armadilha séria: o `Limiter` do pedalboard **aplica ganho de compensação automático e satura em 0 dBFS**. Para fixar um teto, use `BrickwallLimiter(ceiling_db=-1)`.
6. **Texturas.** O Material Maker 1.8 (MIT) baixa do GitHub e tem exportação por linha de comando documentada (`--export-material --target Godot -o <saída> <arquivos .ptex>`). **Não consegui executar:** a política de permissões desta sessão bloqueou rodar o binário baixado. O `pyfastnoiselite` gera fBm de 6 oitavas em 1024×1024 em **0,13 s**, contra cerca de 60 s estimados para o `opensimplex` puro.
7. **Assets livres que estão no GitHub:** 2.019 famílias OFL no `google/fonts`. HDRIs de 1k vindos do Poly Haven (CC0) aparecem no `pmndrs/drei-assets` (12 arquivos), no `mrdoob/three.js` (cerca de 10) e dentro do próprio Material Maker (3). Também estão lá as bibliotecas de samples VSCO-2-CE e VCSL (as duas CC0) e o Sonatina (CC Sampling Plus 1.0). Não achei espelho no GitHub de texturas PBR do Poly Haven ou do ambientCG, e a API do Poly Haven está bloqueada.

---

## 2. Rede e permissões descobertas nesta sessão (complementa o contexto)

| Recurso | Resultado | Consequência |
|---|---|---|
| `git clone` / `git ls-remote` em github.com | funciona | forma principal de baixar |
| `raw.githubusercontent.com` | funciona (fonte Cinzel, 125 KB; HDR do three.js, 1,4 MB) | baixar arquivos sem clonar |
| `media.githubusercontent.com` (Git LFS) | funciona (`neutral.hdr` do Khronos, 80 MB) | repositórios em LFS são alcançáveis |
| Assets de releases (`github.com/<r>/releases/download/<tag>/<arquivo>`) | funciona com o nome exato | é preciso adivinhar o nome do arquivo (veja abaixo) |
| Página `github.com/<r>/releases` (HTML) e `gh release view` / API | **403** | não dá para listar os assets: use `git ls-remote --tags` e teste nomes com `curl -r 0-0` |
| Registro npm (`npm view`) | **funciona** (`@coding-solo/godot-mcp` 0.1.1, `pixelmatch` 8.0.0) | `npx` é viável |
| PyPI e apt (`apt-get download`) | funcionam | `.deb` extraído com `dpkg -x` numa pasta local roda sem instalar |
| api.polyhaven.com, dl.polyhaven.org, projects.blender.org | **403 no proxy** | sem Poly Haven direto e sem o repositório do MCP oficial do Blender |
| WebFetch em `rodzill4.github.io` e raw do godogen | falhou (DNS fora da lista / 404) | li a documentação de dentro do pacote baixado |
| Executar binário baixado do GitHub (Material Maker) | **negado pelo classificador de permissões** | Material Maker e Surge XT não foram executados; pacotes do apt do Ubuntu rodaram |

Truque que funcionou para descobrir assets: `git ls-remote --tags` mostra as tags (Material Maker até `1.8`, Surge XT até `1.3.4`). Depois, `curl -s -L -o /dev/null -w "%{http_code}" -r 0-0 <url>` devolve 206 quando o nome está certo e 404 quando não está.

---

## 3. (a) Skills, plugins e servidores MCP para Claude Code

### 3.1 Servidores MCP

| Projeto | Licença | Último commit | Como funciona | Precisa de interface gráfica? | Utilidade aqui |
|---|---|---|---|---|---|
| [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) (npm `@coding-solo/godot-mcp` 0.1.1) | MIT | 16/04/2026 | Node. Ferramentas `launch_editor`, `run_project`, `get_debug_output`, `create_scene`, `add_node`, `load_sprite`, `export_mesh_library`, `save_scene`, `get_uid`, `update_project_uids`. As operações de cena rodam `godot --headless --script godot_operations.gd` (li o `src/index.ts`, linhas 509 a 528) | não, para cenas; `launch_editor` abre a interface | **Baixa.** Repete o que o agente faz com Bash e GDScript; gerar `.tscn` por script já é o padrão. Exige `claude mcp add`, ou seja, mudar a configuração, o que só o usuário pode aprovar. Não instalar |
| [tomyud1/godot-mcp](https://github.com/tomyud1/godot-mcp) (npm `godot-mcp-server` 0.6.1) | MIT | 17/10/2026 | 69 ferramentas; addon no editor + servidor Node por WebSocket na porta 6505 | **sim**, o editor precisa estar aberto | **Nenhuma** sem tela. Em tese o editor sob Xvfb poderia funcionar (**não verificado**) e seria frágil |
| [ahujasid/blender-mcp](https://github.com/ahujasid/blender-mcp) (renomeado para `mcp-for-blender`; PyPI `blender-mcp` 2.0.0) | MIT | mesmo HEAD `7f31a462` | Addon no Blender abre um socket TCP na porta 9876; ferramentas `execute_blender_code`, `look`, `generate_3d` (Tripo, Hunyuan, Rodin, Meshy pagos), `search_assets` (Poly Haven, Sketchfab) | **sim** (todo o setup passa pela barra N) | **Nenhuma.** Aqui o `bpy` é importado direto no Python; o socket só acrescentaria uma camada. Coleta telemetria mínima por padrão (`DISABLE_TELEMETRY=true` desliga). As integrações de assets usam hosts bloqueados |
| Conector oficial Blender ([claude.com/connectors/blender](https://claude.com/connectors/blender); servidor em projects.blender.org/lab/blender_mcp) | não verificado (repositório bloqueado) | v1.0.3 de 11/09/2026 segundo [strayspark](https://www.strayspark.studio/blog/official-blender-mcp-server-comparison-2026) (fonte secundária) | Addon do Blender Lab, Blender 5.1+, age na cena aberta | **sim** | Nenhuma sem tela. Útil se o usuário quiser mexer numa cena no próprio PC |
| [sandraschi/blender-mcp](https://github.com/sandraschi/blender-mcp) | não verificado | — | Fork que roda `blender --background` como subprocesso | não | Baixa; o agente já roda `bpy` direto. Comparação parecida em [sumguy.com](https://sumguy.com/blender-mcp-vs-headless-bpy/) |

**Conclusão franca:** a vantagem de um MCP é dar acesso a um processo com interface que o agente não alcança. Aqui não existe interface. Godot e Blender são controlados melhor por scripts versionados no repositório, que se reexecutam, se revisam e entram em CI. Um MCP só faria sentido se o usuário quisesse que o agente mexesse no Blender ou no Godot abertos **no computador dele**.

### 3.2 Pacotes de skills

| Pacote | Licença | Último commit | Conteúdo | Veredito |
|---|---|---|---|---|
| [anthropics/skills](https://github.com/anthropics/skills) | Apache-2.0 na maioria (as skills de documentos são source-available) | HEAD `e4bb5d96` | 19 skills. Relevantes: `skill-creator` (criar e medir skills), `webapp-testing` (Playwright: prints e logs de app web local), `mcp-builder`, `slack-gif-creator` (validação de GIF), `algorithmic-art` (p5.js) | **Usar `skill-creator`** para escrever as skills do projeto (seção 10). **Usar o padrão do `webapp-testing`** para testar o export Web: funcionou aqui com o Chrome do sistema [teste] |
| [htdt/godogen](https://github.com/htdt/godogen) | MIT | 21/11/2026 | 2 skills: `engine-guide` (Godot, Bevy, Babylon, three.js; captura headless; armadilhas) e `asset-gen` (imagens por API paga; 3D, som e voz grátis só com GPU NVIDIA via `godogen_assets`) | **Ler `engine-guide/godot.md`** (65 linhas). A receita de captura é a mesma que validei: `--write-movie`, `--fixed-fps`, áudio sincronizado em `frame.wav`, câmera posicionada antes do primeiro quadro. Também avisa que Vulkan por software serve só para stills. **Ignorar `asset-gen`**: APIs pagas e GPU |
| [thedivergentai/gd-agentic-skills](https://github.com/thedivergentai/gd-agentic-skills) | **LGPL-3.0** | 16/10/2026 | 184 skills (100 de Godot, o resto Bevy); `godot-master` tem 524 linhas | Não instalar em bloco: custo de contexto alto e qualidade desigual (**não verificado** skill a skill). No máximo consultar `godot-genre-action-rpg` como lista de verificação |
| [Randroids-Dojo/Godot-Claude-Skills](https://github.com/Randroids-Dojo/Godot-Claude-Skills) | MIT | descontinuado; migrou para [Randroids-Dojo/skills](https://github.com/Randroids-Dojo/skills) | 1 skill `godot`: gdUnit4, PlayGodot, export; scripts `run_tests.py`, `parse_results.py`, `export_build.py`, `validate_project.py` | Bom modelo para a skill de testes do projeto; `parse_results.py` lê o `results.xml` do gdUnit4 |
| [xlanstar/godot-skills](https://github.com/xlanstar/godot-skills) | **sem licença** (nem LICENSE nem campo no package.json) | 02/09/2026 | 15 skills enxutas (CharacterBody, shader, tween, MultiMesh, LOD…) para o Godot 4.7+ | Só leitura; não copiar. Pode ajudar se o projeto for para o 4.7 |
| [wshobson/agents](https://github.com/wshobson/agents) `godot-gdscript-patterns` | MIT (**não verificado** no arquivo) | HEAD `c96b5f65` | 1 skill de padrões GDScript | Genérica; dispensável |
| [bfollington/terma](https://github.com/bfollington/terma) `godot` | CC-BY-SA-4.0 (segundo [claudeskills.info](https://claudeskills.info/skills/bfollington/terma/godot/)) | HEAD `ccaf04c5` | 1 skill | Dispensável |

Fontes da busca: [mcpservers.org](https://mcpservers.org/servers/Coding-Solo/godot-mcp), [claudemarketplaces.com](https://claudemarketplaces.com/skills/thedivergentai/gd-agentic-skills), [skills.sh godogen](https://www.skills.sh/htdt/godogen/godot-task).

---

## 4. (b) Qualidade de código GDScript e CI

| Ferramenta | Versão | Licença | Como verificar | Resultado aqui |
|---|---|---|---|---|
| [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) (`gdlint`, `gdformat`, `gdparse`, `gdradon`) | 4.5.0 (PyPI) | MIT | `pip index versions gdtoolkit` | **[teste]** 31 scripts do Céu Arcano: `gdlint` em 2,6 s, 222 problemas (175 `max-line-length`, 15 `class-definitions-order`, 10 `mixed-tabs-and-spaces`, 7 `function-variable-name`, 5 `loop-variable-name`, 3 `unused-argument`, 3 `max-returns`); `gdformat --check` em 2,0 s: 30 de 31 arquivos seriam reformatados. Conclusão: adotar desde o primeiro commit, com `gdlintrc` (`max-line-length: 120`) |
| [GDQuest/GDScript-formatter](https://github.com/GDQuest/GDScript-formatter) | 0.28.0 (binário Rust) | MIT | ls-remote ok | Não testado (binário baixado); plano B se o gdtoolkit ficar atrás da sintaxe 4.6+ |
| [gdUnit4](https://github.com/MikeSchulze/gdUnit4) | v6.2.3 | MIT | tag ok | **[teste]** `godot --headless -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test --ignoreHeadlessMode -c`: 2 de 2 testes, 1,68 s, `reports/report_1/results.xml` (JUnit) + HTML |
| [GUT](https://github.com/bitwes/Gut) | v9.7.1 | MIT | tag ok | Já testado em `addons-godot.md` §5.3 (3 de 3, 2 s) |
| `godot --doctool <dir>` | embutido | MIT | — | **[teste]** 1.011 XML de classes, 6,6 MB, 1,3 s. Referência offline da API exata da versão instalada: o agente faz `grep` antes de adivinhar nomes de método |
| [godotengine/godot-docs](https://github.com/godotengine/godot-docs) | CC-BY 3.0 (texto) | ls-remote ok | — | Manual completo (tutoriais) em RST, clonável: substitui docs.godotengine.org |
| `godot --headless --check-only -s <arquivo>` / `tools/check_scripts.gd` do Céu Arcano | — | — | — | Já existe no repositório; manter como etapa de CI |
| Export templates 4.5.1 | `Godot_v4.5.1-stable_export_templates.tpz` | MIT | `curl -r 0-0` → 206 | Só `web_nothreads_{debug,release}.zip` estão instalados em `~/.local/share/godot/export_templates/4.5.1.stable/`; o `.tpz` completo pode ser baixado |
| CI: [abarichello/godot-ci](https://github.com/abarichello/godot-ci) (imagem Docker `barichello/godot-ci`) | MIT | HEAD `2b2e4fe3` | — | Tag mais recente listada 4.7.2-stable ([marketplace](https://github.com/marketplace/actions/godot-ci)); tag 4.5.1 **não verificada** |
| CI: [MikeSchulze/gdUnit4-action](https://github.com/MikeSchulze/gdUnit4-action) | MIT | HEAD `379a0b1e` | — | Action pronta para rodar gdUnit4 |
| Python dos pipelines: `ruff`, `pyright` (já em `~/.local/bin`) + [`fake-bpy-module`](https://pypi.org/project/fake-bpy-module/) 20261031 | MIT | PyPI ok | — | Tipagem de `bpy` para o pyright; reduz erros de API do Blender antes de rodar |

**Pipeline de qualidade proposto (cerca de 10 s no total):** `gdformat --check` → `gdlint` → `godot --headless --import` → `check_scripts.gd` → gdUnit4 (ou GUT) → captura de 1 a 3 cenas e comparação com as golden (seção 5) → `ruff` + `pyright` nos pipelines Python.

---

## 5. (c) Verificação visual automática

### 5.1 Captura quadro a quadro [teste]

Cena de teste: cubo emissivo girando, com glow, em 640×360, 30 quadros.

| Modo | Comando | Tempo | Observação |
|---|---|---|---|
| Compatibility (OpenGL llvmpipe) | `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --write-movie out/f.png --fixed-fps 30 --quit-after 30` | 1 s (100% do tempo real); 5,5 ms de CPU e 5,5 ms de GPU por quadro | Grava `f00000000.png`… e **`f.wav`** com o áudio sincronizado |
| Forward+ (Vulkan lavapipe) | mesmo comando, sem `--rendering-*` | 3 s (33% do tempo real); 12,5 ms de GPU por quadro numa cena simples | Em cena pesada (SDFGI, névoa) fica perto de 0,8 s por quadro, como já medido |
| Determinismo | duas execuções Compatibility | — | **PNG idêntico byte a byte**, SSIM 1,0, 0 pixels diferentes |

Armadilhas: com `--write-movie`, use Xvfb e não `--headless` (o godogen diz que no macOS isso aborta; aqui usei só Xvfb). Posicione a câmera antes do primeiro quadro. Dirija a entrada pelo script, não pelo teclado. Em cenas com partículas aleatórias, fixe a `seed` (Godot 4.x tem `GPUParticles3D.seed`/`use_fixed_seed`, **não verificado** no 4.5).

### 5.2 Métricas de diferença [teste]

Script `imgdiff.py`: scikit-image `structural_similarity` e `peak_signal_noise_ratio`, mais `pixelmatch` (Python, ISC) com `threshold=0.1`, gerando um PNG de diferença.

| Par comparado | SSIM | PSNR | pixelmatch | Interpretação |
|---|---|---|---|---|
| Execução A, quadro 15 × execução B, quadro 15 | 1,0000 | ∞ | 0 (0%) | captura reprodutível: dá para fazer teste de regressão exato |
| A15 × A16 (quadros vizinhos) | 0,9949 | 35,6 dB | 294 px (0,13%) | movimento pequeno mal aparece no SSIM; o pixelmatch é mais sensível |
| Compatibility × Forward+ (mesmo quadro) | 0,4824 | 13,3 dB | 97,9% | o fundo `Color(0.05,0.06,0.1)` saiu azul-claro no Compatibility e quase preto no Forward+ (provável diferença de espaço de cor no fundo; causa **não verificada**) |

Ferramentas e limitações:

| Ferramenta | Uso | Nota |
|---|---|---|
| ImageMagick 6.9.12 `compare` | `compare -metric AE a.png b.png diff.png` (pixels diferentes); `-metric PSNR` | **A versão 6 não tem SSIM** (`unrecognized metric type SSIM`). Métricas disponíveis: AE, Fuzz, MAE, MEPP, MSE, NCC, PAE, PHASH, PSNR, RMSE. PHASH serve para "parece a mesma imagem" |
| scikit-image 0.26.0 | SSIM e PSNR | BSD-3 |
| pixelmatch-py 0.4.0 / npm `pixelmatch` 8.0.0 | contagem perceptual com antialias ignorado + imagem de diferença | ISC |
| ffmpeg 6.1.1 | filtros `ssim`, `psnr`, `identity`, `msad` entre dois vídeos | **sem `libvmaf`** nesta build |
| [kornelski/dssim](https://github.com/kornelski/dssim) | SSIM multiescala em L\*a\*b\* | não está no apt; seria binário baixado (não testado) |
| `lpips` 0.1.4 / `piq` 0.8.0 (PyPI) | métrica perceptual com rede neural | exige torch (centenas de MB); não testado; desnecessário para regressão |
| **O próprio agente olhando a imagem** (ferramenta Read) | julgamento estético | a métrica diz se mudou; o olho diz se ficou bom. Fazer uma "folha de contato" (abaixo) e olhar |

**Recomendação de uso:** as golden ficam por cena e por renderer (`tests/golden/<renderer>/<cena>_<quadro>.png`). O teste falha se SSIM < 0,995 ou pixelmatch > 0,5%, e grava `diff.png` para inspeção. Golden só se atualiza com um comando explícito.

### 5.3 GIF, MP4 e folhas de contato [teste]

```bash
# MP4 com áudio do Movie Maker (30 quadros: 21 KB)
ffmpeg -y -framerate 30 -i out/f%08d.png -i out/f.wav -c:v libx264 -crf 18 -pix_fmt yuv420p \
  -c:a aac -shortest -movflags +faststart cena.mp4
# GIF com paleta otimizada (33 KB)
ffmpeg -y -framerate 30 -i out/f%08d.png -vf "fps=15,scale=320:-1:flags=lanczos,split[s0][s1];\
[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4" cena.gif
# Folha de contato: 1 quadro a cada 6, lado a lado (ótima para o agente revisar arcos e espaçamento)
ffmpeg -y -framerate 30 -i out/f%08d.png -vf "select='not(mod(n\,6))',scale=160:-1,tile=5x1" -frames:v 1 folha.png
# Comparação lado a lado A | B | diff
montage a.png b.png diff.png -tile 3x1 -geometry +2+2 lado.png
```

O `gifski` (melhor qualidade de GIF) não está no apt; existe como release do [ImageOptim/gifski](https://github.com/ImageOptim/gifski) (AGPL-3.0, não testado).

### 5.4 Export Web visto "como no celular" [teste]

Playwright 1.65.2 (Apache-2.0) num venv, `chromium.launch(channel="chrome", headless=True, args=["--use-angle=swiftshader","--enable-unsafe-swiftshader","--ignore-gpu-blocklist"])` com `p.devices["Pixel 7"]`, apontando para `python3 -m http.server` na pasta `ceu-arcano/build/web`. Em 14,1 s o motor subiu em WebGL 2.0, o menu do Céu Arcano apareceu com os controles de toque e os logs do console foram capturados. Um deles avisa que o `AudioContext` exige um gesto do usuário. Não precisou baixar navegador: usa o `/usr/bin/google-chrome`. Esse teste deve entrar na CI do export Web, com print em retrato e em paisagem.

---

## 6. (d) Áudio melhor que numpy puro

### 6.1 Disponibilidade e licenças

| Ferramenta | Fonte e versão | Licença | Situação aqui |
|---|---|---|---|
| **FluidSynth** (CLI + lib) | apt 2.3.4 | LGPL-2.1 | **[teste]** `.deb` extraído; `fluidsynth -ni -q -g 0.6 -r 48000 -F out.wav banco.sf2 musica.mid` renderizou 8 s de MIDI em 0,52 s |
| **pyfluidsynth** | PyPI 1.4.0 | MIT (binding) | **[teste]** funciona; com a lib fora do sistema foi preciso trocar `ctypes.util.find_library` antes do import (ignora `LD_LIBRARY_PATH`) |
| **GeneralUser GS** v2.0.3 | [mrbumpy409/GeneralUser-GS](https://github.com/mrbumpy409/GeneralUser-GS) (.sf2 de 32 MB) | licença própria: uso livre, inclusive comercial e em software | **[teste]** banco GM completo, bom para esboço e para instrumentos de apoio |
| **VSCO-2-CE** | [sgossner/VSCO-2-CE](https://github.com/sgossner/VSCO-2-CE) (`master`: 3.168 WAV, cerca de 5 GB; branch `SFZ` com mapeamentos; release 1.1.0 em SFZ) | **CC0** | **[teste]** camadas de cello sus-vib, trompa sus e tímpano + pedalboard renderizadas em 0,42 s. **Melhor fonte orquestral real e livre** |
| **VCSL** | [sgossner/VCSL](https://github.com/sgossner/VCSL) (1.481 arquivos, cerca de 2,2 GB; Aerofones, Cordofones, Idiofones, Membranofones, Eletrofones) | **CC0** | ls-remote e licença conferidos; percussão étnica, sinos, gongos |
| Sonatina Symphonic Orchestra | [peastman/sso](https://github.com/peastman/sso) (SFZ, mantido) | CC Sampling Plus 1.0 (permite usar samples dentro de obra nova; ler os termos) | conferido; seção orquestral completa (como alternativa ou complemento) |
| apt: `fluid-soundfont-gm` 3.1, `musescore-general-soundfont` 0.2.1, `timgm6mb-soundfont`, `opl3-soundfont`, `freepats` | apt | MIT / livres (FluidR3: MIT) | disponíveis, não testados |
| **pedalboard** | PyPI 0.9.26 | **GPL-3.0** (ferramenta de build; o áudio gerado não é afetado) | **[teste]** cadeia HPF → shelf → Compressor → Reverb → limitador em 34,5 s de áudio levou 0,59 s. Também abre VST3 no Linux (**não testado**) |
| **DawDreamer** | PyPI 0.9.0 | GPL-3.0 | **[teste]** Faust compilado em tempo de execução: bumbo sintetizado (pitch envelope + ruído filtrado) de 2 s em 0,033 s. Também hospeda VST e tem sampler |
| **Csound** | apt 6.18.1 (+ `python3-csound`, `ctcsound` 6.17.1 no PyPI) | LGPL-2.1 | **[teste]** `.csd` com `expseg`, `poscil`, ruído em `butbp`, `reverbsc`: impacto de 1,5 s, 0 erros. Use `OPCODE6DIR64` apontando para os plugins extraídos |
| **SoX** | apt 14.4.2 | GPL/LGPL | **[teste]** cortar silêncio (`reverse silence 1 0.05 -70d reverse`), `overdrive`, `reverb`, `norm -1`, `stat` |
| pyloudnorm | PyPI 0.2.0 | MIT | **[teste]** LUFS integrado (ITU-R BS.1770) |
| Faust (compilador) | apt 2.70.3 | GPL (compilador); o código gerado é livre | não testado à parte (o DawDreamer já traz o Faust) |
| SuperCollider | apt `supercollider-server` 3.13.0 (`scsynth` em modo NRT) | GPL-3.0 | não testado; `sclang` só vem com o pacote completo (Qt) |
| **Surge XT** 1.3.4 | release `surge-xt-linux-x64-1.3.4.deb` (223 MB) em [surge-synthesizer/releases-xt](https://github.com/surge-synthesizer/releases-xt) | GPL-3.0 | baixado e inspecionado: VST3, LV2, CLAP, `surge-xt-cli`, **3.008 presets `.fxp`**. **Não executado** (política de binário baixado). Hospedar o VST3 no pedalboard ou no DawDreamer é o caminho, a testar com permissão |
| LV2 do apt: `dragonfly-reverb-lv2` 3.2.10, `x42-plugins`, `lsp-plugins-lv2` 1.2.14, `calf-plugins`, `zynaddsubfx` 3.0.6, `geonkick` 2.10.2, `avldrums.lv2` | apt | GPL / ISC | **Falha [teste]:** `lv2file` 0.95 listou o Dragonfly e seus parâmetros, mas **deu segfault ao processar** (Hall, Room e Plate; causa provável: o host não oferece os recursos LV2 que os plugins DPF exigem, **não verificado**). Pedalboard e DawDreamer não abrem LV2. Hospedar LV2 sem interface pede o `carla` (apt 2.5.8, não testado) |
| `pyo` 1.1.0, `librosa` 1.0.1, `pretty_midi`, `mido` 1.3.3, `music21` 10.5.2 | PyPI | LGPL-3 / ISC / MIT / BSD | `mido` **[teste]** para gerar MIDI; os outros são opcionais |

### 6.2 Armadilha do pedalboard (confirmada no docstring e em teste)

`pedalboard.Limiter` envolve o `juce::dsp::Limiter`, que tem **ganho de compensação automático e corte duro em 0 dBFS**. O `threshold_db` só diz quando a compressão entra, não define o teto. Medido: um sinal normalizado para −16 LUFS saiu a −11,5 LUFS com `Limiter(-1)` e a −6,5 LUFS com `Limiter(-6)`, sempre com pico em 0,00 dBFS. **Correto:** `BrickwallLimiter(ceiling_db=-1.0)` deu pico em −1,00 dBFS. A alternativa é `Limiter(...)` seguido de `Gain(-1)`.

### 6.3 Receita para trilha orquestral ou híbrida convincente

1. **Composição em MIDI por script** (`mido` ou `pretty_midi`): voicings abertos, tensões, contramelodia, ostinatos de cordas em colcheias, dinâmica por CC1/CC11 e não só por velocity, humanização de ±8 ms e ±6 de velocity.
2. **Render por seção com samples reais:** cordas, metais e madeiras do VSCO-2-CE (CC0) e do SSO. Percussão grande (tímpanos, bumbo, gongo) do VSCO-2-CE e do VCSL. O GeneralUser GS fica para coro, harpa e celesta de apoio quando faltar sample. Um player SFZ em Python cabe em cerca de 200 linhas (ler `.sfz`, escolher amostra por nota e velocity, reamostrar com `numpy`/`soxr`, envelope de release). Alternativa: converter o SFZ para SF2 e tocar no FluidSynth (**não verificado** nesta sessão).
3. **Camada híbrida sintetizada:** pulsos, risers e sub-bass com DawDreamer + Faust (ou Surge XT, se liberado). Os "braams" vêm de metais graves dobrados com serra filtrada e distorção leve.
4. **Mixagem por stem no pedalboard:** HPF por instrumento, EQ (`PeakFilter`, `LowShelfFilter`), `Compressor` suave no barramento, `Reverb` ou `Convolution` (com resposta ao impulso própria, por exemplo gerada por Csound ou ruído com envelope exponencial), `BrickwallLimiter(-1)`. Volume final por **LUFS** com pyloudnorm: cerca de −16 LUFS para música de jogo e cerca de −14 para web/mobile (alvos a fixar no projeto).
5. **Loop:** casar o ponto de loop por cruzamento de zero e crossfade. O godogen traz `find_loop_frame.py` e `loop_audio.py` como referência (MIT).

### 6.4 Efeitos de impacto (golpes, magias, explosões)

Camadas por evento, renderizadas offline e variadas por seed:

| Camada | Fonte | Ferramenta |
|---|---|---|
| Transiente (clique, 0 a 10 ms) | ruído filtrado + "tick" senoidal | Faust/DawDreamer ou Csound |
| Corpo (thump, 30 a 150 ms) | seno com queda de pitch de 220 a 50 Hz | Csound `expseg` [teste] / Faust [teste] |
| Textura (crunch, chiado, cristal) | samples CC0 do VCSL e do VSCO (metais, madeira, vidro) + `Distortion`/`Bitcrush` | pedalboard |
| Cauda (espaço) | `Reverb`/`reverbsc` curto e escuro | pedalboard / Csound |
| Sub (só em golpes pesados) | seno de 40 a 60 Hz, 80 ms | numpy |

Depois: `HighpassFilter(30)`, `BrickwallLimiter(-1)`, `soxr` para 48 kHz, corte de silêncio pelo SoX, e 4 a 6 variações de pitch e tempo por evento (round-robin) para evitar o "efeito metralhadora".

---

## 7. (e) Texturas e materiais procedurais

| Ferramenta | Fonte | Licença | Situação |
|---|---|---|---|
| **Material Maker 1.8** | release `material_maker_1_8_linux.tar.gz` (99 MB) em [RodZill4/material-maker](https://github.com/RodZill4/material-maker); tags até `1.8` | MIT | Baixado e inspecionado. Doc incluída (`doc/command_line.html`): **`material_maker --export-material --target <Blender|Godot|Unity|Unreal> -o <saída> <arquivos .ptex>`** (aceita curingas). Traz 30+ exemplos `.ptex` (tijolos, lava, mármore, terra seca, grama com flores…) e 3 HDRIs de 1k do Poly Haven. **Não executado:** rodar o binário baixado foi negado pela política de permissões. Riscos: fóruns relatam que o app fecha ao abrir pela linha de comando ([itch.io](https://rodzilla.itch.io/material-maker)); usa shaders (compute); sem GPU, só com lavapipe sob Xvfb. Requer `.ptex` montados à mão (JSON de grafo), o que um agente consegue escrever mas é trabalhoso. **Veredito: plano B; testar quando houver permissão** |
| **Nós do Blender + bake no Cycles** | embutido | GPL (ferramenta) | Já testado: 512 px em 0,3 a 3,4 s, 2048 px em 1,6 a 35 s (AO). Ver `pipeline-blender.md` §4. **Caminho principal** |
| **Godot `NoiseTexture2D` / `FastNoiseLite`** | embutido | MIT | Gera ruído no motor (inclusive em runtime e na Web); `Image.save_png()` headless para assar (não testado aqui, API padrão) |
| **pyfastnoiselite** | PyPI 0.0.7 | MIT | **[teste]** OpenSimplex2 fBm de 6 oitavas em 1024×1024: **0,13 s**; celular (Distance2Sub): 0,03 s. Mesmo algoritmo do `FastNoiseLite` do Godot, então dá para casar textura assada com ruído em runtime |
| `opensimplex` | PyPI 0.4.5.1 | MIT | **[teste]** 256×256 com 1 oitava em 0,64 s; cerca de 60 s estimados para 1024² com 6 oitavas. Lento demais |
| `noise` 1.2.2, `vnoise` 0.1.0 | PyPI | MIT | conferidos no PyPI, não testados (`noise` é extensão C antiga) |
| [nidorx/matcaps](https://github.com/nidorx/matcaps) | GitHub | MIT segundo o README (**não verificado** por arquivo) | 600+ matcaps; úteis para pré-visualização e estilização, não como textura final |

### Fontes tipográficas livres

[google/fonts](https://github.com/google/fonts): **2.019 famílias OFL**, 44 Apache e 5 UFL. Baixa-se arquivo a arquivo pelo raw (ex.: `https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf`, 125 KB, conferido), sem clonar o repositório inteiro. Famílias que existem e combinam com um RPG de fantasia: Cinzel e Cinzel Decorative, Cormorant (7 variações), EB Garamond, Alegreya (+ Sans, SC), Spectral, Fraunces, IM Fell (10 variações), Grenze e Grenze Gotisch, Almendra, Uncial Antiqua, Metamorphous, MedievalSharp, Pirata One, Macondo, Kurale, Marcellus; para a interface, Inter, Nunito e Faustina. Cada pasta traz `OFL.txt` e `METADATA.pb`: copiar o `OFL.txt` junto com a fonte.

---

## 8. (f) HDRIs e texturas CC0 no GitHub

| Repositório | Conteúdo | Licença | Acesso |
|---|---|---|---|
| [pmndrs/drei-assets](https://github.com/pmndrs/drei-assets) `hdri/` | 12 HDRs de 1k (1,4 a 1,9 MB): adams_place_bridge, dikhololo_night, empty_warehouse_01, forest_slope, immenstadter_horn, kiara_1_dawn, lebombo, potsdamer_platz, rooitou_park, st_fagans_interior, studio_small_03, venice_sunset | README: "HDRIs from HDRI Haven" → CC0 de origem | raw ok (forest_slope_1k.hdr, 1,9 MB) |
| [mrdoob/three.js](https://github.com/mrdoob/three.js) `examples/textures/equirectangular/` | HDRs de 1k do Poly Haven: blouberg_sunrise_2, ferndale_studio_04, monochrome_studio_02, moonless_golf, pedestrian_overpass, quarry_01, spruit_sunrise, venice_sunset; san_giuseppe_bridge_2k (6 MB) | repositório MIT; CC0 **inferido pelo nome** (Poly Haven). `752-hdri-skies-com_1k.hdr` vem de outra fonte, licença **não verificada** | raw ok (venice_sunset_1k.hdr, 1,4 MB) |
| Material Maker 1.8 (pacote) | epping_forest_01, moonless_golf, photo_studio_01 (1k) | CC0 de origem (Poly Haven) | dentro do tar.gz |
| [KhronosGroup/glTF-Sample-Environments](https://github.com/KhronosGroup/glTF-Sample-Environments) | chromatic, directional, doge2, ennis, field, footprint_court, helipad, neutral, papermill, pisa (`.hdr` grandes, ex. neutral 80 MB) | **não verificada** (o README não mostrou licença) | Git LFS: o raw devolve ponteiro; `media.githubusercontent.com` funciona |
| [Poly-Haven/polyhavenassets](https://github.com/Poly-Haven/polyhavenassets) | addon do Blender que **baixa** da API | GPL (addon); assets CC0 | inútil aqui: a API está bloqueada |
| Texturas PBR (ambientCG, Poly Haven) | **nenhum espelho confiável encontrado no GitHub** | — | gerar por procedimento (seção 7) |

Para um RPG estilizado isso basta. Os HDRIs servem de **iluminação de estúdio e de referência** (look-dev no Blender, reflexo no Godot), não como céu visível. O céu do jogo deve ser procedural (`ProceduralSkyMaterial` ou shader próprio), coerente com a direção de arte.

---

## 9. Testes práticos: resumo dos resultados (inclusive falhas)

| # | Teste | Resultado |
|---|---|---|
| 1 | gdtoolkit 4.5.0 no Céu Arcano (31 .gd) | ok: 222 avisos de lint, 30 arquivos a formatar, cerca de 2 s cada |
| 2 | gdUnit4 v6.2.3 headless no 4.5.1 | ok: 2/2, 1,68 s, JUnit XML |
| 3 | `godot --doctool` | ok: 1.011 XML, 1,3 s |
| 4 | Movie Maker Compatibility × 2 + Forward+ | ok: determinístico byte a byte; Forward+ a 33% do tempo real numa cena simples |
| 5 | SSIM, PSNR e pixelmatch; ImageMagick; ffmpeg MP4, GIF e folha de contato | ok; IM6 sem SSIM; ffmpeg sem VMAF |
| 6 | Playwright + Chrome do sistema no export Web (Pixel 7) | ok: print em 14 s, logs do console |
| 7 | FluidSynth CLI + pyfluidsynth + GeneralUser GS | ok (pyfluidsynth precisou de ajuste no `find_library`); o arquivo saiu com 34,5 s para 16,8 s de áudio útil: cortar a cauda com o SoX |
| 8 | pedalboard (cadeia de mastering, LUFS) | ok; **armadilha do `Limiter`** documentada; `BrickwallLimiter` correto |
| 9 | DawDreamer + Faust | ok (parâmetros em `/dawdreamer/<nome>`; o primeiro palpite `/kick/freq` falhou) |
| 10 | Csound 6.18 | ok depois de corrigir o `.csd` (as tags precisam ficar em linhas separadas) |
| 11 | SoX (corte, overdrive, reverb, norm) | ok |
| 12 | VSCO-2-CE em camadas + pedalboard | ok, 0,42 s |
| 13 | pyfastnoiselite × opensimplex | ok: 0,13 s × cerca de 60 s estimados |
| 14 | lv2file + Dragonfly Reverb LV2 | **falhou**: segfault nos 3 plugins testados |
| 15 | Material Maker 1.8 `--export-material` | **não executado**: binário baixado bloqueado pela política de permissões |
| 16 | Surge XT 1.3.4 (VST3 no pedalboard) | **não executado**, pelo mesmo motivo; pacote inspecionado |
| 17 | godot-mcp e blender-mcp | não instalados de propósito (exigem `claude mcp add` e/ou interface gráfica); avaliados pelo código-fonte |

---

## 10. Kit recomendado para o agente construtor

**Python (um venv do projeto, `tools/venv`):**
`gdtoolkit==4.5.0 scikit-image pixelmatch pedalboard==0.9.26 dawdreamer==0.9.0 pyfluidsynth soundfile pyloudnorm mido pyfastnoiselite playwright fake-bpy-module`

**Binários de sistema sem instalar no sistema:** `apt-get download fluidsynth libfluidsynth3 libinstpatch-1.0-2 libsdl2-2.0-0 libpipewire-0.3-0t64 libpulse0 sox libsox3 libsox-fmt-* csound libcsound64-6.0` → `dpkg -x` em `tools/sysroot` → `LD_LIBRARY_PATH` e `OPCODE6DIR64`. Para o pyfluidsynth: `ctypes.util.find_library` redirecionado. Alternativa mais simples, se o usuário permitir: `apt-get install`.

**Dados (fixar commit ou tag, nunca HEAD):** GeneralUser GS v2.0.3; VSCO-2-CE (branch `SFZ`, ou a pasta `master` com seleção parcial de instrumentos para não baixar 5 GB); VCSL (só as pastas usadas); 2 a 4 HDRIs de 1k do drei-assets; 2 a 3 famílias do google/fonts com `OFL.txt`.

**Skills do próprio projeto** (escritas com o `skill-creator`, cada uma com script testado):
1. `capturar-cena`: Movie Maker + Xvfb → PNG, MP4, GIF e folha de contato.
2. `comparar-golden`: SSIM, pixelmatch, `diff.png`, limites por cena.
3. `testar-web-mobile`: export Web + Playwright em retrato e paisagem + logs.
4. `renderizar-audio`: MIDI → seções com samples → mixagem pedalboard → LUFS → OGG.
5. `qualidade-gdscript`: gdformat, gdlint, check-only, gdUnit4.
6. `consultar-api-godot`: `grep` no XML do `--doctool` antes de usar uma API.

**Não adotar:** godot-mcp, blender-mcp e o conector oficial (sem tela, sem ganho); gd-agentic-skills em bloco (LGPL, custo de contexto); xlanstar/godot-skills (sem licença); `asset-gen` do godogen (APIs pagas e GPU); opensimplex (lento); lv2file (segfault).

---

## 11. Pontos em aberto

- Material Maker 1.8 por linha de comando sob Xvfb e lavapipe: precisa de permissão para executar o binário baixado.
- Surge XT VST3 hospedado no pedalboard ou no DawDreamer: idem.
- Hospedar LV2 sem interface (Dragonfly Hall é excelente): testar o `carla` do apt ou compilar um host mínimo com `lilv`.
- Licença do glTF-Sample-Environments e do `752-hdri-skies-com_1k.hdr`.
- Conversão de SFZ do VSCO-2-CE para SF2 (para usar no FluidSynth) ou player SFZ próprio: escolher depois de testar a qualidade.
- `pysfizz` 0.1.3 (PyPI) como player SFZ em Python: só confirmei que existe.
- Imagem de CI do Godot 4.5.1 (`barichello/godot-ci:4.5.1`): tag não verificada.
- Por que o fundo do Compatibility saiu mais claro que o do Forward+ (espaço de cor do `background_color`): investigar antes de criar as golden.

---

## 12. Fontes

- Godot MCP: <https://github.com/Coding-Solo/godot-mcp>, <https://github.com/tomyud1/godot-mcp>, <https://mcpservers.org/servers/Coding-Solo/godot-mcp>, <https://pushks18.github.io/Godot-MCP-Pilot/>
- Blender MCP: <https://github.com/ahujasid/blender-mcp>, <https://github.com/sandraschi/blender-mcp>, <https://sumguy.com/blender-mcp-vs-headless-bpy/>, <https://www.strayspark.studio/blog/official-blender-mcp-server-comparison-2026>, <https://claude.com/connectors/blender>, <https://claude.com/resources/tutorials/using-the-blender-connector-in-claude>, <https://9to5mac.com/2026/04/28/anthropic-releases-9-new-claude-connectors-for-creative-tools-including-blender-and-adobe/>
- Skills: <https://github.com/anthropics/skills>, <https://github.com/htdt/godogen>, <https://github.com/thedivergentai/gd-agentic-skills>, <https://github.com/Randroids-Dojo/Godot-Claude-Skills>, <https://github.com/xlanstar/godot-skills>, <https://claudemarketplaces.com/skills/thedivergentai/gd-agentic-skills>, <https://claudeskills.info/skills/bfollington/terma/godot/>
- Qualidade: <https://github.com/Scony/godot-gdscript-toolkit>, <https://github.com/GDQuest/GDScript-formatter>, <https://github.com/MikeSchulze/gdUnit4>, <https://github.com/MikeSchulze/gdUnit4-action>, <https://github.com/bitwes/Gut>, <https://github.com/abarichello/godot-ci>, <https://github.com/marketplace/actions/godot-ci>, <https://github.com/godotengine/godot-docs>
- Imagem: <https://github.com/mapbox/pixelmatch>, <https://github.com/whtsky/pixelmatch-py>, <https://github.com/kornelski/dssim>, <https://github.com/ImageOptim/gifski>, <https://playwright.dev/python/>
- Áudio: <https://github.com/FluidSynth/fluidsynth>, <https://github.com/mrbumpy409/GeneralUser-GS>, <https://github.com/sgossner/VSCO-2-CE>, <https://github.com/sgossner/VCSL>, <https://github.com/peastman/sso>, <https://github.com/spotify/pedalboard>, <https://github.com/DBraun/DawDreamer>, <https://github.com/csound/csound>, <https://github.com/supercollider/supercollider>, <https://github.com/surge-synthesizer/releases-xt>, <https://surge-synthesizer.github.io/downloads>, <https://github.com/michaelwillis/dragonfly-reverb>, <https://www.synthtopia.com/content/2011/01/31/free-creative-commons-orchestral-sample-library-sonatina-symphonic-orchestra/>
- Texturas e fontes: <https://github.com/RodZill4/material-maker> (doc `command_line.html` no pacote 1.8), <https://rodzilla.itch.io/material-maker/devlog/1491329/material-maker-16>, <https://github.com/google/fonts>, <https://github.com/nidorx/matcaps>
- HDRIs: <https://github.com/pmndrs/drei-assets>, <https://github.com/mrdoob/three.js>, <https://github.com/KhronosGroup/glTF-Sample-Environments>, <https://github.com/Poly-Haven/polyhavenassets>, <https://polyhaven.com/license>

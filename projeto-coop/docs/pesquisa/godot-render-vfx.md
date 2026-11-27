# Renderização e VFX no Godot 4 (4.5 → 4.7) para um RPG de ação co-op estilizado

Pesquisa feita em 26/11/2026. Etapa de pesquisa: nada do jogo foi construído.
Autor: agente de pesquisa (tema "renderização e VFX").

Legenda de confiança usada no texto:

- **[T]** testado aqui, no container (resultado real, com número ou captura).
- **[D]** documentação oficial do Godot 4.7 (lida pelo código-fonte em `github.com/godotengine/godot-docs`, branch `4.7`, porque `docs.godotengine.org` está bloqueado no shell).
- **[C]** changelog oficial (`CHANGELOG.md` das tags `4.6.3-stable` e `4.7.2-stable`) ou classe do motor.
- **[W]** fonte de terceiros na web (URL citada).
- **[H]** heurística / experiência geral, sem medição nesta etapa.
- **[NV]** não verificado.

---

## 0. Resumo executivo (decisões recomendadas)

1. **Versão: Godot 4.7.2-stable** (18/08/2026). É a estável mais nova; 4.8 está em beta 5 (24/11/2026) e ainda não deve ser base. Binário e template Web baixáveis do GitHub e testados aqui (seção 2).
2. **Dois níveis de qualidade com um único conjunto de assets**: Forward+ no desktop (capturas, trailer, PC) e Compatibility na Web (WebGL2, celular). O conteúdo deve ser **autorado "Compatibility-first"**: tudo que define o estilo (toon, contorno, VFX, tilt-shift) precisa funcionar no Compatibility; o Forward+ só acrescenta atmosfera (névoa volumétrica, SDFGI, SSR, DOF real, decals, trilhas de partículas).
3. **Achado medido mais importante**: com a mesma cena, Compatibility e Forward+ dão **pixels idênticos** quando a luz é só ambiente de cor fixa + luzes **sem sombra** + materiais unshaded. A diferença aparece em quatro pontos (seção 4): luz **com sombra** (Compatibility soma em sRGB, fica mais claro), **transparência** (Compatibility mistura em sRGB, aditivo estoura mais rápido), **emissão forte** (acima de ~2 de energia perde o matiz e vira branco) e **céu procedural / ambiente vindo do céu**. Isso define a direção de arte técnica: iluminação estilizada por shader próprio, sombra "falsa" ou assada, e VFX calibrado por renderer.
4. **Contorno, toon, hachura, distorção de tela, tilt-shift, stencil X-ray e colisão de partículas funcionam no Compatibility e em WebGL2 real** (testado em Chrome headless). **Não funcionam** no Compatibility: DOF nativo, decals, trilhas de GPUParticles, sub-emissores, CompositorEffect, textura normal/roughness, névoa volumétrica, SSR, SSIL, SDFGI, VoxelGI.
5. **Lightmap do Godot não é automatizável** aqui: `LightmapGI.bake()` não é exposto a script em nenhuma das três versões testadas e o bake é em GPU. Para luz assada, assar no **Blender (Cycles em CPU)** e trazer como textura/vertex color; funciona igual nos dois renderers.
6. **Verificação automática existe para os dois níveis**: capturas e vídeo via Xvfb + Movie Maker (Forward+ e Compatibility) e, novidade desta pesquisa, **captura do build Web em WebGL2 real** com Chrome headless + DevTools Protocol (seção 11 e apêndice B).

---

## 1. Método e ambiente de teste

| Item | Valor |
|---|---|
| Godot testados | 4.5.1 (instalado), 4.6.3 e 4.7.2 (baixados de `github.com/godotengine/godot/releases`) |
| Desktop Compatibility | `--rendering-method gl_compatibility --rendering-driver opengl3` sobre llvmpipe (OpenGL por software), Xvfb 1280×720 |
| Desktop Forward+ / Mobile | `--rendering-driver vulkan` sobre lavapipe (llvmpipe, Vulkan 1.4.318 por software) |
| Web | export 4.7.2 `web_nothreads_release`, servido por `python3 -m http.server`, aberto no Google Chrome for Testing 153 headless com `--use-angle=swiftshader` (WebGL2 via ANGLE/SwiftShader) e controlado por DevTools Protocol com Node 22 |
| Projeto de sonda | cena única gerada por GDScript, mais de 20 "features" selecionadas por argumento; cada execução grava PNG e log |
| Local dos testes (temporário) | `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-render-vfx/` (`proj/` projeto, `out/` capturas e logs, `scripts/` ferramentas) |

Os shaders e scripts que valem a pena reaproveitar estão copiados no apêndice deste arquivo, porque o scratchpad pode ser apagado.

Tempos por quadro são de **renderização por software** (sem GPU): servem para planejar captura, não representam desempenho em aparelho real.

| Cenário (1280×720, 4.7.2) | ms/quadro medidos |
|---|---|
| Compatibility (llvmpipe), cenas simples | 65 a 230 |
| Forward+ (lavapipe), cenas simples | 140 a 520 |
| Forward+ com SDFGI + névoa volumétrica + SSR + SSIL + glow + SSAO | 637 |
| Web (Chrome + SwiftShader), cenas simples | 260 a 420 |

---

## 2. (a) O que mudou em 4.6 e 4.7 e qual versão usar

Datas [C] (`_data/versions.yml` do repositório `godotengine/godot-website`): 4.5 em 09/2025; **4.6** em 26/01/2026 (4.6.3 em 20/05/2026); **4.7** em 18/06/2026 (4.7.1 em 14/07, **4.7.2 em 18/08/2026**); 4.8 beta 5 em 24/11/2026.

### 2.1 Godot 4.5 (base instalada hoje)

- **Stencil buffer** em shaders e no `BaseMaterial3D` (`stencil_mode` = Outline, X-Ray, Custom). Marcado como experimental [D]. Testado aqui: funciona nos três renderers e em WebGL2 [T].
- Shader baker (pré-compila shaders de Forward+/Mobile no export; não se aplica ao Compatibility) [W: https://itsfoss.com/news/godot-4-5-release/].
- Oclusão especular baseada em luz ambiente (Forward+/Mobile) [W: https://www.cgchannel.com/?p=170196].
- `SpringBoneSimulator3D`, `LookAtModifier3D` já existem (verificado por `ClassDB` no 4.5.1) [T].

### 2.2 Godot 4.6 ("All about your flow") — https://godotengine.org/releases/4.6/

| Área | Mudança | Impacto no projeto |
|---|---|---|
| Animação / IK | Novo framework: `IKModifier3D` sobre `SkeletonModifier3D`, com `TwoBoneIK3D`, `SplineIK3D`, `FABRIK3D`, `CCDIK3D`, `JacobianIK3D`; `LimitAngularVelocityModifier3D`, `BoneTwistDisperser3D`; `BoneConstraint3D` aceita alvo `Node3D` [C] | Pés no chão, mão na arma, mira e "overlap" procedural por cima das animações do Blender. `IKModifier3D` e `TwoBoneIK3D` existem em 4.6.3 e 4.7.2 e não em 4.5.1 [T] |
| Física | Jolt vira padrão em projetos 3D novos [D] | Ragdoll, destroços e projéteis mais estáveis |
| Render | **SSAO simplificado no Compatibility** ("Implement a very simple SSAO in GLES3") [C]; só Radius e Intensity [D] | Contato/oclusão também na Web. Confirmado: em 4.5.1 dá aviso e 0 pixels mudam; em 4.6.3 e 4.7.2 muda 1.822 pixels na cena de teste [T] |
| Render | SSR reescrito, com modo meia resolução [D] | Água/chão molhado no nível desktop |
| Render | Glow misturado **antes** do tonemap, modo padrão Screen; glow do Mobile reescrito [D] | Ao migrar de 4.5, reajustar glow (`glow_intensity` padrão 0,8 → 0,3) |
| Render | AgX com `agx_white` e `agx_contrast` [D]; probes de reflexão em mapas octaédricos [D]; debanding de material no Mobile [D] | Controle fino de contraste |
| Render | Névoa volumétrica com mistura fisicamente mais correta (fica mais clara) [D] | Reajustar densidade ao migrar |
| Compatibility | Vetores de movimento, cull mask de `DirectionalLight3D`, correções de refração/proximity fade [C] | Mais paridade |
| Windows | D3D12 passa a ser o driver padrão em projetos novos [D] | Sem efeito no Linux/Web |
| Arquivos | `.tscn` passa a gravar IDs únicos de nó; compatível nos dois sentidos, mas gera diffs grandes ao regravar [D] | Começar o projeto novo já em 4.7 evita isso |
| Editor de animação | Redimensionar animação arrastando a timeline; botões solo/ocultar/travar por grupo no editor Bezier [D] | Irrelevante para pipeline por script |
| Web | Só correções pequenas [C] | — |

### 2.3 Godot 4.7 ("Lights, camera, action") — https://godotengine.org/releases/4.7/

| Área | Mudança | Impacto no projeto |
|---|---|---|
| Render | **Escala 3D com vizinho mais próximo** (`Viewport.SCALING_3D_MODE_NEAREST = 5`) [C] | 3D em baixa resolução com pixels nítidos e UI em resolução nativa, sem SubViewport. Testado em Compatibility e Forward+ [T] |
| Render | `AreaLight3D` (luz retangular em tempo real) nos três renderers; textura na luz não funciona no Compatibility [D] | Janelas, portais, telas mágicas |
| Render | "Select relevant 3D lights per mesh on GLES3 and Mobile renderers" [C] | O limite de 8 luzes por malha passa a escolher as mais relevantes |
| Render | Bent normal map no Compatibility; fim do limite de tamanho do backbuffer no Compatibility; clearcoat corrigido [C] | Qualidade Web |
| Render | Saída HDR (Windows, macOS, iOS, visionOS, Linux/Wayland), só Forward+/Mobile [D] | Irrelevante para Web |
| Render | `DrawableTexture2D` (desenhar em textura por API simples) [D] | Marcas no chão, pintura de rastro, máscara de fog of war |
| Partículas | Escala 3D e rotação 3D no `ParticleProcessMaterial`, "Inherit Emitter Scale", mais opções de orientação, correção de velocidade herdada em sub-emissores [C] | Stretch & squash em partículas |
| Shaders | Pré-visualização inline no editor de shader de texto [D] | Irrelevante sem editor |
| Animação | `SyncMode` em BlendSpace1D/2D (substitui `sync` booleano), ping-pong em `SpriteFrames`, `Tween.tween_await()` [C][D] | Sprites HD-2D e cutscenes |
| Entrada | Nó `VirtualJoystick` embutido (Fixed, Dynamic, Following) [D]; giroscópio de controle; IDs de dispositivo para teclado/mouse [D] | Controles de toque sem addon. Classe existe em 4.7.2 e não em 4.6.3 [T] |
| Física | Jolt 5.5.0; `Area3D` detecta `SoftBody3D`; sinal de `WorldBoundaryShape3D.plane.d` invertido em relação ao 4.6 [C][D] | — |
| 2D / GUI | `offset_transform_*` em `Control` (animar sem quebrar container) [D]; gradiente cônico | Juice de UI |
| Web | `wasm64` opcional no build, correções [C] | — |
| Padrões | Projetos novos passam a usar stretch `canvas_items`/`expand` [C] | Bom para celular |

### 2.4 Godot 4.8 (beta, não usar ainda)

- `Trail3D`: nó de trilha para VFX que "works in all renderers (including Compatibility)" segundo o README do demo oficial `3d/trails` [W: https://github.com/godotengine/godot-demo-projects/tree/master/3d/trails]. A classe existe no `master` do motor (`doc/classes/Trail3D.xml`) e **não** existe em 4.7.2 [T].
- Sombras de contato em espaço de tela, streaming de mips, AO multi-bounce [W: https://80.lv/articles/godot-4-8-development-is-in-full-swing, https://godotengine.org/article/dev-snapshot-godot-4-8-beta-4/] [NV em detalhe].

### 2.5 Recomendação

**Usar 4.7.2-stable.** Motivos concretos frente ao 4.5.1 instalado: IK novo (4.6), SSAO no Compatibility (4.6), SSR e glow novos (4.6), escala nearest e `VirtualJoystick` (4.7), seleção de luzes por malha (4.7), partículas com escala/rotação 3D (4.7). Projetar a trilha de arma como componente próprio (malha em fita) com interface parecida com a do `Trail3D`, para trocar quando o 4.8 estabilizar.

Riscos a validar cedo: (1) relato de "memory access out of bounds" em export Web ao migrar 4.5.1 → 4.6 (https://forum.godotengine.org/t/memory-access-out-of-bounds-on-web-export-migrating-4-5-1-4-6/131968) [W]; aqui o export Web do 4.7.2 rodou sem erro em Chrome headless [T], mas falta celular real. (2) Stencil ainda é "experimental" [D].

Download verificado [T]:

- Editor: `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip` (77,9 MB).
- Templates: `.../Godot_v4.7.2-stable_export_templates.tpz` tem 1,28 GB, mas só `templates/web_nothreads_release.zip` (10,2 MB) é necessário. Dá para extrair só esse arquivo com requisições HTTP Range (script no apêndice C) e apontar o preset para ele com `custom_template/release`.

---

## 3. (b) Matriz de recursos por renderer

Fonte base: tabela oficial "Overview of renderers" do 4.7 [D] (https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html), mais testes [T]. "Sim/Não" na coluna Web vale igual ao Compatibility.

### 3.1 Luzes e sombras

| Recurso | Compatibility (Web) | Mobile | Forward+ |
|---|---|---|---|
| Abordagem | Forward de passe único; **luzes com sombra em multi-passe, somadas em sRGB** [D][T] | Forward de passe único | Forward clusterizado |
| Omni / Spot | 8 + 8 **por malha** (ajustável em `rendering/limits/opengl/max_lights_per_object`); 32 luzes renderizáveis na vista por padrão (`max_renderable_lights`) [D][T] | 8 + 8 por malha, 256 por vista (fixo) | 512 elementos por cluster (ajustável) |
| Direcionais | 8 | 8 | 8 |
| Sombras PCSS | Não | Omni/Spot sim, direcional não | Sim |
| Projetor de textura na luz | Não | Sim | Sim |
| `AreaLight3D` (4.7) | Sim, sem textura | Sim | Sim |

Teste do limite [T]: um chão de malha única com 16 `OmniLight3D` mostra só 8 no Compatibility e 16 no Forward+. Com `max_lights_per_object=16` no `project.godot`, o Compatibility mostra as 16 (custo: shader maior e compilação mais lenta [D]). Alternativa sem custo: dividir o chão em ladrilhos.

### 3.2 Iluminação global e reflexos

| Recurso | Compatibility | Mobile | Forward+ |
|---|---|---|---|
| `ReflectionProbe` | Sim, 2 por malha [D]; funcionou [T] | Sim, 8 por malha | Sim, ilimitado |
| `LightmapGI` | **Só exibe**; assar exige GPU com RenderingDevice [D] | Sim | Sim |
| `VoxelGI` | Não | Não | Sim (`VoxelGI.bake()` é exposto a script [T]) |
| SDFGI | Não | Não | Sim |
| SSIL | Não | Não | Sim |
| SSR | Não | Não | Sim |
| SSAO | **Sim desde 4.6**, versão simples [D][T] | Não | Sim |
| Sub-surface scattering | Não | Não | Sim |

**Dá para assar lightmap sem GPU?** Na prática não, neste ambiente:

- `ClassDB.class_has_method("LightmapGI", "bake")` retorna `false` em 4.5.1, 4.6.3 e 4.7.2 [T]; a classe diz que o bake "is only available in the editor" [C]. Um tópico do fórum confirma que não é exposto nem em builds de editor e estima "10+ minutos para um lightmap pequeno" com lavapipe [W: https://forum.godotengine.org/t/is-it-possible-to-bake-lightmapgi-node-using-headless-godot-editor/129607].
- Caminho recomendado: assar no Blender (`bpy.ops.object.bake`, Cycles em CPU) para um atlas em UV2 ou para vertex color, e multiplicar no shader do cenário. Fica igual nos dois renderers e na Web. [NV nesta etapa: o bake em si não foi executado aqui.]

### 3.3 Ambiente e pós-processamento

| Recurso | Compatibility | Mobile | Forward+ |
|---|---|---|---|
| Névoa por profundidade e altura | Sim | Sim | Sim |
| Névoa volumétrica / `FogVolume` | Não | Não | Sim |
| Tonemap (Linear, Reinhard, Filmic, ACES, AgX) | Sim | Sim | Sim |
| Glow | Sim, implementação própria: sem Levels, Normalized, Strength, Blend Mode, Mix e Map [D] | Sim | Sim |
| Ajustes (brilho, contraste, saturação, LUT) | Sim | Sim | Sim |
| DOF (`CameraAttributes`) | **Não** (aviso no log) [T] | Sim | Sim |
| Autoexposição | Não | Não | Sim |
| Pós com quad de tela cheia | Sim [T] | Sim | Sim [T] |
| `CompositorEffect` | **Não** | Sim | Sim |
| Decals | **Não** (não desenha nada, sem aviso) [T] | Sim, 8 por malha | Sim |

### 3.4 Antialiasing e escala

| Recurso | Compatibility | Mobile | Forward+ |
|---|---|---|---|
| MSAA 3D | Sim | Sim | Sim |
| MSAA 2D | Não | Sim | Sim |
| TAA | Não | Não | Sim |
| FSR2 | Não | Não | Sim |
| FXAA / SMAA | Não | Sim | Sim |
| SSAA (escala > 1) | Sim | Sim | Sim |
| Escala 3D bilinear | Sim | Sim | Sim |
| Escala 3D nearest (4.7) | Sim [T] | [NV] | Sim [T] |
| FSR1 | Não | Não (cai para bilinear em 4.7 [C]) | Sim |
| Debanding | Não | Sim | Sim |

### 3.5 Shaders e buffers

| Recurso | Compatibility | Mobile | Forward+ |
|---|---|---|---|
| `hint_screen_texture` | Sim [T] | Sim | Sim [T] |
| `hint_depth_texture` | Sim [T]; NDC OpenGL, z em [-1, 1] | Sim; z reverso | Sim; z reverso [T] |
| `hint_normal_roughness_texture` | **Erro de compilação** [T] | Não | Sim |
| Stencil (4.5+) | Sim [T], inclusive WebGL2 [T] | Sim | Sim [T] |
| Compute shaders / `RenderingDevice` | Não | Sim (com custo) | Sim |
| Precisão de cor | RGBA8, sem HDR interno [D]; emissivos perdem o matiz acima de ~2 de energia [T] | RGB10A2 | RGBA16F |
| Profundidade | 24 bits, sem z reverso | 24 bits, z reverso | 32 bits, z reverso |
| HDR 2D / saída HDR | Não | Sim | Sim |
| Pré-compilação de pipeline / ubershader | **Não**; exige pré-aquecer mostrando o material [D] | Sim | Sim |

### 3.6 Partículas

| Recurso | Compatibility | Mobile | Forward+ |
|---|---|---|---|
| `GPUParticles3D` básico | Sim [T] | Sim | Sim |
| Trilhas (`trail_enabled`) | **Não**: aviso e a `RibbonTrailMesh` aparece como tiras soltas [T] | Sim | Sim [T] |
| Sub-emissores | **Não**: aviso, nada é emitido [T]; `emit_particle()` também não [C] | Sim | Sim [T] |
| Colisão caixa/esfera | Sim [T], inclusive WebGL2 [T] | Sim | Sim [T] |
| Colisão SDF | Não [D] | Sim | Sim |
| Colisão heightfield | [NV] | Sim | Sim |
| Atratores | Sim [T] | Sim | Sim [T] |
| Turbulência | Sim [T]; "não recomendada para mobile/web" [D] | Sim | Sim |
| Flipbook (`particles_anim_*`) | Sim [H] | Sim | Sim |
| `CPUParticles3D` | Sim | Sim | Sim |

`CPUParticles3D` não tem trilha, colisão, sub-emissor nem atrator em nenhum renderer [D].

---

## 4. Paridade medida entre Compatibility e Forward+ (4.7.2)

Cena fixa (chão, cubo, esfera, sol com sombra, esferas emissivas). Pixels lidos das capturas.

| Configuração | Chão (Compat) | Chão (Forward+) | Leitura |
|---|---|---|---|
| Ambiente cor fixa, **sem sol**, tonemap linear | (37, 34, 40) | (37, 34, 40) | Idêntico |
| Ambiente cor fixa, sol **sem sombra** | (125, 117, 114) | (125, 117, 114) | Idêntico |
| Ambiente cor fixa, sol **com sombra** | (156, 146, 147) | (125, 117, 114) | Compat mais claro: 37 + 120 ≈ 156, soma em sRGB |
| Ambiente do céu (`AMBIENT_SOURCE_SKY`), **sem sol**, linear | (18, 27, 55) | (31, 31, 55) | Diverge: o próprio céu procedural sai diferente (pixel do céu (94, 98, 141) contra (120, 107, 140)) |
| Ambiente do céu, sol **sem sombra**, linear | (122, 116, 120) | (124, 117, 120) | Quase idêntico (a luz direta domina) |
| Ambiente do céu, sol **com sombra**, Filmic | (185, 191, 230) | (157, 149, 153) | Pior caso: soma em sRGB realça o ambiente azulado |
| Sprite `Sprite3D` unshaded | (220, 61, 78) | (219, 62, 79) | Idêntico |

A documentação confirma a causa: no Compatibility as luzes com sombra são renderizadas em multi-passe "in sRGB space instead of linear space" e "you may need to adjust the light's energy" [D] (https://docs.godotengine.org/en/4.7/tutorials/3d/lights_and_shadows.html).

Transparência (quad unshaded sobre fundo cinza 0,5):

| Mistura | Compatibility | Forward+ | Leitura |
|---|---|---|---|
| Aditivo, cor (0,5; 0,25; 0,05) | (255, 191, 136) | (175, 141, 129) | Compat soma valores sRGB; Forward+ soma em linear |
| Alpha 50%, vermelho puro | (191, 64, 64) | (204, 92, 92) | Compat interpola em sRGB |

Emissão e glow (esfera emissiva laranja (1,0; 0,45; 0,1), glow ligado):

| Energia de emissão | Compat (centro) | Forward+ (centro) |
|---|---|---|
| 1,0 | (255, 208, 123) | (255, 164, 88) |
| 1,8 | (255, 255, 153) | (255, 200, 98) |
| 3,0 | (255, 255, 191) | (255, 232, 114) |
| 6,0 | (255, 255, 255) branco puro | (255, 255, 120) |

Com energia 6 o halo do glow no Forward+ é alaranjado (213, 168, 159) e no Compatibility é quase neutro (205, 203, 216).

**Regras práticas que saem daqui:**

1. Para o visual do personagem e do cenário não depender do renderer: shader próprio (unshaded com rampa, ou `light()` com luzes sem sombra), ambiente de cor fixa (`AMBIENT_SOURCE_COLOR`) e luz assada/vertex color.
2. Sombra dinâmica na Web: ou aceitar um "rig de luz" próprio do nível Web (energia recalibrada), ou usar sombra falsa (blob/quad projetado) e reservar sombra real para o desktop.
3. Emissão entre 1,0 e 2,0; glow na Web com `glow_hdr_threshold` mais baixo e `glow_bloom` > 0, porque não há faixa HDR para "passar do branco".
4. VFX aditivo: calibrar no Compatibility primeiro. No shader único de VFX, usar `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY` para compensar intensidade/alpha.
5. Fundo escuro ou médio atrás de VFX aditivo: sobre fundo claro o aditivo vira branco no Compatibility [T].

Observação de ambiente: com **MSAA 3D 2x ligado**, `hint_depth_texture` voltou **zerado** em Forward+ e Mobile sob lavapipe, em 4.5.1, 4.6.3 e 4.7.2; sem MSAA funcionou. No Compatibility com MSAA funcionou [T]. Não dá para saber aqui se é limitação do lavapipe ou do motor [NV em GPU real]. Regra segura: no desktop, se houver pós-processo que lê profundidade, usar FXAA/SMAA/TAA em vez de MSAA, ou testar em GPU real antes.

---

## 5. (c) Pós-processamento

### 5.1 Três caminhos e quando usar cada um

| Caminho | Renderers | Lê profundidade | Lê normal | Ordem | Uso recomendado |
|---|---|---|---|---|---|
| `CanvasLayer` + `ColorRect` com shader `canvas_item` e `hint_screen_texture` | Todos [T] | Não | Não | Depois do tonemap, em espaço de tela final | Gradação de cor, vinheta, aberração cromática, flash, impact frame, transições. Afeta 2D abaixo da camada; UI vai em camada acima |
| Quad de tela cheia (`MeshInstance3D` + `QuadMesh` 2×2, `POSITION = vec4(VERTEX.xy, 1.0, 1.0)`) com shader `spatial` | Todos [T] | Sim | Só Forward+ (`hint_normal_roughness_texture`); nos outros reconstruir a partir da profundidade [T] | No passe transparente, antes do glow/tonemap do Forward+ | Contorno por profundidade, tilt-shift, névoa de altura custom, distorção global |
| `CompositorEffect` (compute shader em GLSL via `RenderingDevice`) | Só Forward+ e Mobile [D] | Sim | Sim (`needs_normal_roughness`) | 5 pontos: `PRE_OPAQUE`, `POST_OPAQUE`, `POST_SKY`, `PRE_TRANSPARENT`, `POST_TRANSPARENT` [C] | Luxo de desktop: contorno largo por jump flood, Kuwahara, god rays, motion blur |

Detalhes que custam tempo se esquecidos:

- Receita oficial do quad [D] (https://docs.godotengine.org/en/4.7/tutorials/shaders/advanced_postprocessing.html): `render_mode unshaded, fog_disabled;`, `flip_faces = true` no `QuadMesh`, `extra_cull_margin` no máximo, quad filho da câmera. Com `depth_draw_never` funcionou nos dois renderers e na Web [T].
- Profundidade: Forward+/Mobile usam z reverso com NDC z em [0, 1]; Compatibility usa NDC OpenGL com z em [-1, 1]. Trecho validado [T]:
  ```glsl
  #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
      vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
  #else
      vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
  #endif
      vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
      float linear_depth = -view.z / view.w;
  ```
- Em 3D, um material que usa `hint_screen_texture` é tratado como transparente e **não enxerga outros transparentes** (partículas, VFX) [D]. Logo, contorno por tela não pega VFX (bom) e distorção de tela não distorce partículas (ruim; para isso, usar camada canvas).
- Shader `canvas_item` não tem acesso à profundidade 3D [H]; 4.7 passou a proibir `hint_screen_texture` em tipos de shader sem suporte [C].
- Desfoque por mip (`textureLod` na textura de tela) fica **em blocos** no Compatibility [T]. Usar núcleo explícito de amostras (16 amostras em espiral áurea funcionou igual nos dois e na Web [T]).
- `SubViewport` extra é caro na Web: há relato de queda para menos de 1 FPS com vários SubViewports [W: https://forum.godotengine.org/t/subviewport-rendering-performances-on-web/101434]. Evitar cadeias de viewports no nível Web.
- Buffer de stencil do renderer principal não pode ser copiado em compositor effects [D].

### 5.2 Contorno (outline): opções comparadas

| Técnica | Renderers | Custo | Qualidade | Notas |
|---|---|---|---|---|
| Casca invertida (`next_pass` com `cull_front` e deslocamento pela normal) | Todos; WebGL2 ok [T] | +1 draw por malha contornada | Contorno externo limpo, espessura controlável por vértice | Precisa de normais suaves: em malha com quinas duras, gravar no Blender uma normal média em atributo (cor ou UV extra) e usar no deslocamento. Espessura constante em tela: multiplicar por `clip.w` (apêndice A.1) |
| `BaseMaterial3D.stencil_mode = OUTLINE` (4.5+) | Todos; WebGL2 ok [T] | +1 draw, usa stencil | Igual à casca, sem linhas internas sobrepostas | Uma linha de GDScript. `STENCIL_MODE_XRAY` dá silhueta atrás de parede: ótimo para co-op com câmera fixa (jogador escondido atrás de coluna) [T] |
| Detecção de borda em tela (profundidade + normal reconstruída) | Todos; WebGL2 ok [T] | 5 leituras de profundidade por pixel + 1 de cor | Pega bordas internas e interseções; espessura em pixels | Shader no apêndice A.2. No Forward+ pode usar a textura normal/roughness para bordas internas mais limpas |
| Campo de distância por jump flood | CE: Forward+/Mobile. Versão nó: Compatibility, com SubViewports | Vários passes | Contornos largos, brilho, traço "sketch" | Projeto pronto MIT: `pink-arcana/godot-distance-field-outlines` |
| Linhas internas autorais | Todos | Zero em runtime | Estilo Guilty Gear Xrd | Linhas desenhadas na textura ou em vertex color pelo script do Blender |

Recomendação: **stencil outline ou casca invertida** nos personagens e inimigos (lê bem em câmera distante, custo previsível), **X-ray por stencil** para oclusão, e borda por profundidade apenas como opção de desktop para cenário.

### 5.3 Toon / NPR e hachura

- A função `light()` de shader `spatial` roda por luz e funciona nos dois renderers e na Web [T]. Padrão: `ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5`, quantizar em 2 a 3 faixas ou amostrar uma rampa (`GradientTexture1D`), multiplicar por `ATTENUATION`, somar a `DIFFUSE_LIGHT`. Rim com `pow(1.0 - dot(NORMAL, VIEW), n)` em `SPECULAR_LIGHT`.
- Hachura: na faixa mais escura, modular por um padrão. Em tela (`FRAGCOORD`) é o mais barato [T], mas "nada" quando a câmera move; em espaço do objeto/triplanar com textura de traços (tonal art maps) fica preso à superfície. Para câmera quase fixa de RPG co-op, hachura em tela com ângulo fixo é aceitável.
- Cor de sombra **escolhida** (não preto multiplicado): `mix(shade_color, lit_color, faixa)`. É o que tira a cara de "PBR padrão".
- No Compatibility, luz com sombra passa pelo multi-passe sRGB (seção 4): o toon fica mais claro e lavado [T]. Opções: luz principal sem sombra + sombra falsa; ou segunda calibração de energia para a Web.
- Referência de método: palestra da Arc System Works sobre Guilty Gear Xrd (controle de normais editadas à mão, linhas internas, sombra por limiar pintado), GDC 2015 [W: https://gdcvault.com/play/1022031/GuiltyGearXrd-s-Art-Style-The; PDF: https://www.ggxrd.com/Motomura_Junya_GuiltyGearXrd.pdf]. Tudo ali é reproduzível por script no Blender (transferência de normais de uma esfera/proxy, máscaras em vertex color).
- Código pronto MIT para estudar: `eldskald/godot4-cel-shader` (atualizado em 10/2025, usa `diffuse_curve` global e outline em `next_pass`), `atzuk4451/FlexibleToonShaderGD-4.0` (faixas, rampas e hachura experimental).

### 5.4 Tilt-shift e profundidade de campo

| Opção | Renderers | Observação |
|---|---|---|
| `CameraAttributesPractical` (`dof_blur_far_*`, `dof_blur_near_*`) | Forward+ e Mobile [T] | Melhor qualidade; no Compatibility só gera aviso |
| Shader próprio por profundidade, 16 amostras | Todos; WebGL2 ok [T] | Apêndice A.3. 17 leituras de textura por pixel: reduzir para 8 no celular |
| Faixa por Y da tela (sem profundidade) | Todos [H] | Tilt-shift clássico: desfoca topo e base com gradiente vertical. O mais barato; combina com câmera fixa inclinada |
| Glow em modo Replace para desfocar a tela inteira [D] | Forward+/Mobile | Útil para pausa/menu |

---

## 6. (d) HD-2D no Godot

"HD-2D" é marca da Square Enix; aqui é usado só como descrição de técnica: sprites 2D em mundo 3D, com luz dinâmica, DOF/tilt-shift, bloom e partículas.

### 6.1 Blocos de construção

| Peça | Como fazer no Godot | Observações testadas |
|---|---|---|
| Sprite no mundo | `Sprite3D` / `AnimatedSprite3D` (`pixel_size`, `texture_filter = NEAREST`, `alpha_cut`, `billboard`, `shaded`, `double_sided`) | Renderiza igual nos dois renderers quando `shaded = false` [T] |
| Billboard | `billboard = BILLBOARD_FIXED_Y` (gira só no eixo Y) | Com câmera inclinada, Y fixo evita o sprite "deitar" |
| Recorte de alpha | `ALPHA_CUT_DISCARD` (borda dura, entra no passe opaco, recebe e projeta sombra) ou `ALPHA_CUT_OPAQUE_PREPASS` (borda suave com prepass) | Os dois projetaram sombra [T] |
| Sombra do sprite | `cast_shadow = ON` | Sombra de sprite billboard apareceu nos dois renderers [T]. Formato exato da sombra quando a luz é rasante [NV] |
| Sprite iluminado | `shaded = true` usa a normal do quad; para volume, quad com `ShaderMaterial` e **normal map por quadro** | No Compatibility, luz omni forte com sombra estourou o sprite e o chão [T] (multi-passe sRGB). Guia de sprite com normal map em 3D [W: https://eliornadir.github.io/gamedev/GodotSprite3DNormal] |
| Direções | 4 ou 8 direções escolhidas pelo ângulo entre a frente do personagem e a câmera | Demo oficial `3d/sprites` [W: https://github.com/godotengine/godot-demo-projects/tree/master/3d/sprites] |
| Cenário | Malhas 3D com textura sem filtro, luz assada, névoa por profundidade | — |
| Foco | DOF nativo (desktop) ou tilt-shift por shader (Web) | Seção 5.4 |
| Atmosfera | Glow, vinheta, partículas de poeira, raios de luz falsos (quads aditivos) na Web; névoa volumétrica no desktop | — |

### 6.2 Vantagem específica deste projeto

Como os personagens nascem em 3D no Blender, o mesmo script pode renderizar, por quadro e por direção: cor, **normal**, máscara de emissão e profundidade. Isso dá sprites com iluminação dinâmica coerente (normal map exato, não estimado) e contorno consistente, que é a parte mais difícil de produzir à mão. O custo é memória de textura: 8 direções × N animações × quadros × 2 a 3 mapas.

Estimativa de atlas [H]: personagem com 12 animações × 8 direções × 10 quadros = 960 quadros; a 96×96 px são 8,8 Mpx por mapa, ou seja, três atlas de 4096×2048 aproximadamente. Com espelhamento horizontal (5 direções em vez de 8) cai 37%.

### 6.3 Pixel perfeito: o que é possível

- Com câmera em perspectiva, o tamanho do texel em tela varia com a distância: o sprite "treme" ao andar. Há tópico recente exatamente sobre isso em 4.7 [W: https://forum.godotengine.org/t/pixel-art-sprite-jitters-while-moving-in-a-2d-gameplay-in-a-3d-world-2-5d-setup-godot-4-7/145750].
- Mitigações: (1) câmera ortográfica e posição do sprite arredondada à grade de texels em espaço de câmera; (2) sprites em resolução alta com filtro linear + mipmaps (abandona o pixel exato, ganha suavidade: é o que o estilo "HD" faz na prática); (3) 3D inteiro em baixa resolução com `scaling_3d_mode = NEAREST` e `scaling_3d_scale` 0,25 a 0,5, com UI nativa por cima [T]: caminho "3D pixel art" (referência MIT: `leopeltola/Godot-3d-pixelart-demo`, que usa o buffer de normal e portanto só Forward+).
- Série escrita sobre 2D top-down com luz e sombra no Godot 4 [W: https://catlikecoding.com/godot/true-top-down-2d/4-light-and-shadow/].
- Vídeo "HD-2D Style in Godot 4.0" (Gamedev Aki): Sprite3D com billboard Y para adereços [W: resumo em https://recapio.com/digest/hd-2d-style-in-godot-4-0-by-gamedev-aki; vídeo original não assistido, NV].
- Demo oficial `misc/2.5d` faz o inverso (nós 2D com matemática 3D), útil só se o jogo for 2D puro [W: https://github.com/godotengine/godot-demo-projects/tree/master/misc/2.5d].

### 6.4 HD-2D ou 3D completo? Impacto de renderização

| Critério | HD-2D (sprites pré-renderizados) | 3D completo estilizado |
|---|---|---|
| Custo por personagem em runtime | 1 quad, 1 draw; sem skinning | Skinning + 2 draws (com contorno) |
| Web/celular | Muito leve em geometria; pesa em memória de textura e download | Leve em memória; pesa em vértices e skinning |
| Animação (12 princípios) | Squash & stretch e smear podem ser exagerados no Blender sem limite de rig em runtime | Depende de escala de osso e blend; IK novo do 4.6 ajuda |
| Variação (equipamento, cores) | Cada combinação é novo atlas, ou troca de paleta por shader | Troca de malha/material |
| Paridade entre renderers | Alta com sprite unshaded ou shader próprio | Alta com shader próprio; cuidado com sombra |
| Risco de "cara de IA" | Baixo se o contorno e a paleta forem controlados no render | Médio: formas genéricas aparecem mais |

---

## 7. (e) Receitas de VFX estilizado

Princípios que valem para todas [W: guia de estilo de VFX da Riot, https://nexus.leagueoflegends.com/en-us/2017/10/dev-leagues-vfx-style-guide/ e https://www.vfxapprentice.com/blog/10-league-of-legends-vfx-design-tips]:

- Clareza de jogo primeiro: valor (claro/escuro) separa efeito, personagem e chão; evitar extremos absolutos.
- Tempo em três atos: antecipação curta, pico de 1 a 3 quadros muito claro, dissipação longa com desaceleração.
- 2 a 3 matizes por efeito, forma legível em silhueta, hierarquia (núcleo, corpo, resíduo).

Arquitetura sugerida: **um shader único de VFX** (`vfx_uber.gdshader`, `unshaded`) com máscara principal rolando, ruído de distorção rolando, limiar de erosão, rampa de cor por `GradientTexture1D`, fresnel opcional e proximity fade opcional. Parâmetros por instância vêm de `COLOR` (partícula/vértice) ou de `instance uniform` [NV: suporte de `instance uniform` no Compatibility não testado aqui]. Poucos shaders = pouca compilação na Web.

Insumos gerados por script: malhas de VFX no Blender (arco, anel, cone, cilindro, hélice, com U ao longo do comprimento e V na largura), ruídos ladrilháveis (Perlin, Worley, Voronoi de bordas) em Python/numpy ou `NoiseTexture2D` com `seamless`, rampas em `GradientTexture1D`, curvas em `CurveTexture`. Texturas CC0 prontas para estudo/uso: `RPicster/Godot-particle-and-vfx-textures`.

### 7.1 Malha com textura rolando (golpe de espada, tornado, aura)

1. No Blender, gerar a malha do arco (setor de anel de 120° a 200°, 16 a 24 segmentos), UV com U de 0 a 1 ao longo do arco e V de 0 (interno) a 1 (externo).
2. Shader `unshaded, blend_add` ou `blend_mix`, `cull_disabled`, `depth_draw_never`.
3. `uv = UV * tiling + vec2(TIME * speed, 0.0)`; amostrar máscara de traços (ruído esticado em U).
4. Multiplicar por máscara de forma: `smoothstep` em V (borda interna/externa) e em U (ponta e cauda).
5. Animar um `progress` de 0 a 1 em 0,12 a 0,25 s: desloca a janela visível em U (o golpe "varre") e aumenta a erosão no fim.
6. Mapear intensidade para cor por rampa (núcleo quase branco, borda saturada).
7. Instanciar orientado pela arma no quadro de contato; destruir ao fim.

### 7.2 Distorção de UV

1. Amostrar um ruído de fluxo (canais R e G) com UV rolando devagar.
2. `uv_main += (flow.rg - 0.5) * strength` antes de amostrar a máscara principal.
3. Usar duas camadas de distorção com velocidades e escalas diferentes para quebrar repetição.
4. Reduzir `strength` perto das bordas da malha para não vazar a forma.

### 7.3 Dissolve / erosão

1. `n = texture(noise, UV * scale).r` (em objetos, usar triplanar ou UV2 para não depender do UV de cor).
2. `ALPHA = smoothstep(t - w, t, n)`; para ficar no passe opaco com sombra, usar `ALPHA_SCISSOR_THRESHOLD`.
3. Borda acesa: `edge = smoothstep(t, t + band, n) * (1.0 - smoothstep(t + band, t + 2.0 * band, n))`; somar em `EMISSION` (ou em `ALBEDO` se unshaded).
4. Em VFX, o limiar `t` vem de `COLOR.a` da partícula: a partícula "se come" em vez de só ficar transparente (parece desenhado, não fumaça genérica).
5. Direcional (congelar de baixo para cima, teleporte): somar ao ruído um gradiente por posição (`world_pos.y`).
6. Referência MIT: `gdquest-demos/godot-shaders/godot/Shaders/dissolve.gdshader`.

### 7.4 Flipbooks

1. Fonte: simulação no Blender (Mantaflow) ou animação 2D procedural, renderizada em grade 8×8 (64 quadros) de 1024² ou 2048². [NV: geração no Blender não testada nesta etapa.]
2. Em partículas: `BaseMaterial3D.billboard_mode = BILLBOARD_PARTICLES`, `particles_anim_h_frames/v_frames`, e no `ParticleProcessMaterial` `anim_speed_min/max = 1` e `anim_offset` aleatório.
3. Suavizar: shader próprio que amostra quadro atual e próximo e mistura por `fract(frame)`.
4. Alpha pré-multiplicado (`blend_premul_alpha`) evita halo escuro.
5. Usar com parcimônia na Web: é o item que mais pesa em download.

### 7.5 Trilhas

| Opção | Renderers | Passos |
|---|---|---|
| Arco de malha animado (7.1) | Todos | Melhor para golpes: forma autoral, custo fixo |
| Fita em tempo real | Todos | Guardar as últimas N posições de dois pontos (base e ponta da arma); a cada quadro montar tira de triângulos com `ImmediateMesh` ou `ArrayMesh`; UV.x = idade normalizada; mesmo shader de VFX |
| `GPUParticles3D` com `trail_enabled` + `RibbonTrailMesh`/`TubeTrailMesh` | Forward+ e Mobile [T] | Material com `use_particle_trails = true`; no Compatibility quebra [T] |
| `Trail3D` | Todos, a partir do 4.8 [W] | Trocar quando estabilizar |
| Addon `celyk/GPUTrail` (MIT) | [NV no Compatibility] | Baseado em GPUParticles |

### 7.6 Onda de choque

1. Anel no chão: malha de coroa circular, UV radial; escala por tween com ease-out; erosão crescente.
2. Distorção: quad voltado para a câmera com o shader do apêndice A.4 (lê `hint_screen_texture`, desloca UV radialmente dentro de um anel); `radius` animado de 0,1 a 0,9 em 0,25 a 0,4 s. Funcionou igual nos dois renderers e na Web [T].
3. Poeira: `CPUParticles3D` em anel, 12 a 24 partículas, velocidade radial com amortecimento.
4. Marca no chão: `Decal` no desktop; na Web, quad rente ao chão com `render_priority` e pequeno deslocamento, porque decal não existe no Compatibility [T].
5. Câmera: shake por "trauma" e hit-stop (7.8).

### 7.7 Distorção de tela (calor, portal, impacto)

1. Malha transparente com `hint_screen_texture`; `offset = (noise.rg - 0.5) * strength * mask`.
2. `ALBEDO = texture(screen, SCREEN_UV + offset).rgb`.
3. Limitar à área da malha: tela inteira é cara em celular.
4. Lembrar que não distorce outros transparentes [D].
5. Aberração cromática local: amostrar R, G e B com offsets ligeiramente diferentes.

### 7.8 Impact frames e hit-stop

1. Hit-stop: `Engine.time_scale = 0.0` a `0.05` por 0,04 a 0,08 s (golpe leve) ou 0,10 a 0,18 s (pesado), restaurando com `get_tree().create_timer(dur, true, false, true)` (o quarto argumento ignora o time scale; sem isso o congelamento não termina) [W: https://forum.godotengine.org/t/tutorial-hit-stop-and-screen-shake-in-godot-4-autoload-trauma-camera-mit/145240, https://uhiyama-lab.com/en/notes/godot/hit-feedback-hitstop/].
2. Impact frame: por 1 a 3 quadros, `ColorRect` em `CanvasLayer` com shader que converte a tela em 2 tons (limiar de luminância) ou inverte, mais linhas radiais procedurais a partir do ponto de impacto em tela.
3. Flash no alvo: uniform `flash` no shader do personagem mistura para branco por 2 quadros.
4. Shake por trauma: valor 0 a 1 que decai; deslocamento = ruído × trauma². Manter o shake em tempo real durante o hit-stop.
5. Áudio não segue `time_scale`.
6. Em co-op, hit-stop global atrapalha os outros jogadores: preferir congelar só atacante e alvo (pausar `AnimationPlayer`/velocidade) e reservar o global para golpes finais.
7. Opção de acessibilidade para reduzir shake/flash.
8. Addons MIT para referência: `Kelpekk/Juicee`, `Eneskp3441/Shaker`, `ramokz/phantom-camera`.

### 7.9 Raios

1. Polilinha entre origem e alvo por deslocamento do ponto médio (4 a 5 subdivisões, amplitude proporcional ao comprimento).
2. Fita voltada para a câmera (como em 7.5) com núcleo branco fino e halo largo colorido (duas fitas ou V da UV).
3. Regerar a forma a cada 2 a 3 quadros por 0,1 a 0,2 s; 1 ou 2 ramos com 30 a 50% do comprimento.
4. Clarão: `OmniLight3D` sem sombra por 2 quadros + flash aditivo no ponto de impacto.
5. Versão só shader (feixe elétrico contínuo): em um quad, `y = UV.y - 0.5 + (noise(UV.x * f + TIME * v) - 0.5) * amp`; `line = smoothstep(w, 0.0, abs(y))`.

### 7.10 Feixes

1. Malha: cilindro sem tampas ou dois quads em cruz; U ao longo do comprimento.
2. Escalar o comprimento pela distância do raycast; multiplicar `UV.x` pelo comprimento para manter a densidade do padrão.
3. Rolar ruído em U (rápido) e uma segunda camada mais lenta em sentido oposto.
4. Erosão nas pontas, fresnel para engrossar a silhueta.
5. Brilho de origem e de impacto (sprites aditivos pulsando) + faíscas no impacto.
6. Abertura em 3 quadros (largura 0 → 1,3 → 1,0) e fechamento por erosão.

### 7.11 Fogo estilizado

1. Malha de chama (cone achatado ou cartões) com gradiente vertical em vertex color ou UV.
2. Ruído rolando para cima + distorção de UV (7.2).
3. `v = noise * gradiente`; quantizar em 2 a 3 faixas com `step`/`smoothstep` estreito (núcleo amarelo-claro, meio laranja, borda vermelha escura).
4. Deslocar vértices por seno/ruído para a silhueta dançar.
5. Brasas: 8 a 16 partículas pequenas subindo com turbulência leve.
6. Luz: omni sem sombra com energia oscilando por ruído.
7. Referência: `stylized_fire.gdshader` da GDQuest (MIT, baseado em técnica da Minions Art) e tutorial do Le Lu coberto pela 80.lv [W: https://80.lv/articles/learn-how-to-create-stylized-fire-shader-in-godot].

### 7.12 Água estilizada

1. Plano subdividido; ondas por soma de senos no `vertex()`.
2. Cor por profundidade: diferença entre a profundidade da cena e a do fragmento (com o ramo de NDC do Compatibility) define raso → fundo.
3. Espuma de borda: `smoothstep` nessa mesma diferença + ruído rolando.
4. Brilhos toon: `step` sobre dois ruídos rolando em direções opostas.
5. Refração: `hint_screen_texture` com offset pela normal/ruído.
6. Desktop: SSR ou `ReflectionProbe`; Web: cubemap/céu falso no shader.
7. Referências MIT: `gdquest-demos/godot-shaders` (`water_3d`, `stylized_waterfall`), `gdquest-demos/godot-4-vfx-assets` (`3d_stylized_water`), `Arnklit/Waterways`.

### 7.13 Gelo e cristal

1. Base: fresnel forte em cor fria + cor interna mais escura.
2. Rachaduras: Voronoi de bordas como máscara clara.
3. Refração com `hint_screen_texture` deslocada pela normal.
4. Cintilação: ruído de alta frequência com limiar dependente do ângulo de visão.
5. Crescimento: erosão direcional (7.3) de baixo para cima.
6. Quebra: estilhaços low-poly gerados no Blender, lançados por `CPUParticles3D` com malha, + flash + anel de onda.

---

## 8. (f) Fontes de tutoriais e o que cada uma ensina

| Fonte | URL | O que tem de mais útil | Observação |
|---|---|---|---|
| Documentação oficial 4.7 | https://docs.godotengine.org/en/4.7/ (fonte: `github.com/godotengine/godot-docs`, branch `4.7`, acessível do shell) | Tabela de renderers; `environment_and_post_processing`; `custom_postprocessing` e `advanced_postprocessing`; `screen-reading_shaders`; `compositor`; `3d/particles/*`; `using_lightmap_gi`; `pipeline_compilations`; `exporting_for_web`; `creating_movies` | Fonte primária de tudo que está marcado [D] |
| Demos oficiais | https://github.com/godotengine/godot-demo-projects | `3d/particles`, `3d/trails` (4.8), `3d/decals`, `3d/sprites`, `3d/graphics_settings` (menu de qualidade completo), `compute/post_shader` (CompositorEffect), `2d/screen_space_shaders`, `2d/sprite_shaders`, `viewport/3d_scaling`, `3d/ik` | MIT |
| GDQuest | https://gdquest.com/library/godot_4_6_workflow_changes ; https://www.gdquest.com/library/taxonomy/subject_tag/vfx | Resumo prático do 4.6; shaders comentados linha a linha (repos na seção 9) | Código MIT, **arte CC-BY-NC-SA** (não reutilizar texturas/modelos) |
| The Godot Shaders Bible (Jettelly, Fabrizio Espíndola) | https://jettelly.com/store/the-godot-shaders-bible ; cobertura: https://80.lv/articles/jettelly-s-the-godot-shaders-bible-is-finally-complete | 4 capítulos: fundamentos e matrizes, formas procedurais e geometria, VFX 2D/3D e espaço de tela, pós-processo, renderização estilizada, porte de Shadertoy, compute | Pago; amostra grátis de 349 páginas segundo o fórum [W: https://forum.godotengine.org/t/anyone-read-the-godot-shaders-bible-yet/133095]. Conteúdo não lido aqui [NV] |
| FencerDevLog | https://forum.godotengine.org/t/godot-4-shaders-a-list-of-video-tutorials/36500 | Lista com mais de 95 vídeos curtos de shader para Godot 4 (glow, espiral, raymarching, chuva, plasma), mantida até 11/2026 | YouTube bloqueado no shell |
| Le Lu (artista técnico de VFX) | Coberturas: https://80.lv/articles/learn-how-to-create-stylized-fire-shader-in-godot ; https://80.lv/articles/learn-how-to-create-cool-vfx-textures-with-this-detailed-tutorial | VFX estilizado em Godot 4 do zero: malhas simples + shader, criação de texturas de VFX dentro do Godot, trilhas (o addon GPUTrail credita um tutorial dele) | Vídeos não assistidos [NV] |
| 80.lv: artista de VFX sobre efeitos não fotorrealistas no Godot | https://80.lv/articles/vfx-technical-artist-on-creating-non-photorealistic-visual-effects-in-godot | Fluxo de trabalho de NPR em Godot | [NV em detalhe] |
| GodotCon | https://media.ccc.de/v/godotcon2023-57824-from-watercolors-to-mechs-stylized-rendering-and-asset-pipelines-in-godot ; https://talks.godotengine.org/godotcon-ams-2026/talk/NSNXFT/ | "From watercolors to mechs" (renderização estilizada e pipeline de assets); "Procedural Pixel Art: Retro VFX with Shaders" (Julian Rogawski, 2026); "Making Stylized 3D Games In Godot" (Boston 2025, ID da página não confirmado) | — |
| Acerola (Garrett Gunnell) | https://github.com/GarrettGunnell/Post-Processing ; https://github.com/GarrettGunnell/AcerolaFX | Código MIT de: correção de cor, bloom, blur, sharpen (CAS), dithering e paleta, filtro pixel art, Kuwahara (3 variantes), detecção de borda, diferença de gaussianas estendida, halftone, ASCII, névoa, lens flare, tonemapping | É HLSL de Unity/ReShade: serve como referência de algoritmo para portar. Kuwahara e DoG dão aparência "pintada" e precisam de muitos taps: desktop |
| The Book of Shaders | https://thebookofshaders.com ; https://github.com/patriciogonzalezvivo/thebookofshaders | Capítulos 05 a 13: funções de forma, cor, formas, matrizes, padrões, aleatório, ruído, ruído celular, fBm | Licença "all rights reserved": só leitura. Biblioteca `lygia` do mesmo autor usa Prosperity License (não permissiva) |
| Guia de estilo de VFX da Riot | https://nexus.leagueoflegends.com/en-us/2017/10/dev-leagues-vfx-style-guide/ | Valor, forma, cor, hierarquia e tempo de efeitos legíveis | Aplicável a qualquer motor |
| Guilty Gear Xrd (GDC 2015) | https://gdcvault.com/play/1022031/GuiltyGearXrd-s-Art-Style-The | 3D que parece 2D: normais editadas, linhas internas, animação em passos, câmera e escala por quadro | Base para "sem cara de IA" em 3D toon |
| Catlike Coding (Godot) | https://catlikecoding.com/godot/true-top-down-2d/4-light-and-shadow/ | Tutoriais escritos, passo a passo | — |
| RealtimeVFX | https://realtimevfx.com/t/official-league-of-legends-vfx-style-guide/3392 | Fórum da comunidade de VFX; desconstruções de efeitos | — |
| Kodeco | https://www.kodeco.com/43354079-introduction-to-shaders-in-godot-4 | Introdução escrita a shaders em Godot 4 | — |

---

## 9. (g) Repositórios GitHub verificados

Todos confirmados com `git ls-remote --symref <url> HEAD` em 26/11/2026; licença lida do arquivo `LICENSE*` do branch padrão. O hash curto é o do HEAD nessa data.

### 9.1 Código e shaders reutilizáveis

| Repositório | Branch / HEAD | Licença | Conteúdo | Nível |
|---|---|---|---|---|
| `godotengine/godot-demo-projects` | master `281a99f0` | MIT | Demos oficiais (lista na seção 8) | Ambos |
| `gdquest-demos/godot-shaders` | main `158a4905` | Código MIT, arte CC-BY-NC-SA 4.0 | `dissolve`, `shockwave_3d`, `force_field` (com ramo de NDC do Compatibility), `stylized_fire`, `outline3D*`, `xray_*`, `stencil_mask`, `water_3d`, `stylized_waterfall`, `wind_*` | Ambos |
| `gdquest-demos/godot-4-vfx-assets` | main `f6034a88` | Idem | `3d_flame`, `3d_smoke_explosion`, `3d_paintball_projectile`, `3d_hologram`, `3d_stylized_water`, `iridescent`, `2d_trail`, `2d_explosion`, `2d_vortex` | Ambos (conferir cada um) |
| `pink-arcana/godot-distance-field-outlines` | main `815fe196` | MIT (assets de terceiros CC0) | Contorno largo por jump flood: `DFOutlineCE` (CompositorEffect) e `DFOutlineNode` (Compatibility, com SubViewports) | CE: desktop |
| `eldskald/godot4-cel-shader` | main `8129cec4` | MIT | Cel shader completo com includes e outline em `next_pass` | Ambos |
| `atzuk4451/FlexibleToonShaderGD-4.0` | main `f397a8d9` | MIT | Toon com faixas, rampas e hachura (porte do addon do CaptainProton42) | Ambos |
| `leopeltola/Godot-3d-pixelart-demo` | master `6118473c` | MIT | Outline/highlight para 3D em pixel art | Forward+ (usa buffer de normal) |
| `paddy-exe/GodotVisualShader-Extras` | v4.x `0e86e427` | MIT | Nós extras de visual shader | Referência |
| `DigvijaysinhGohil/Godot-Shader-Lib` | main `c1c786f3` | MIT | Biblioteca de nós de shader | Referência |
| `celyk/GPUTrail` | main `bd0f151e` | MIT | Trilha em fita por GPU | Compatibility [NV] |
| `haowg/GODOT-VFX-LIBRARY` | main `6e8fc84e` | MIT | 35+ partículas e 24 shaders 2D (dissolve, frozen, burning, petrify, heat distortion, radial blur) + gerenciadores de shake/freeze | 2D; útil se o jogo for HD-2D |
| `spheras/godot-sprite-shader-mixer` | main `c7870813` | MIT | Shaders de sprite combináveis | 2D |
| `ItsKorin/PostFX` | main `7c28a27d` | MIT | Pós-processo por shader em CanvasLayer (sucessor do Post-Process-Plugin) | Ambos |
| `ArseniyMirniy/Godot-4-Color-Correction-and-Screen-Effects` | main `c8b16be4` | MIT | Correção de cor leve (Mini) e efeitos de tela, via CanvasLayer + ColorRect | Ambos |
| `Kelpekk/Juicee` | main `22f576b1` | MIT | Game feel: shake, hit stop, freeze frame, rampas de tempo | Ambos |
| `Eneskp3441/Shaker` | main `c127bcc4` | MIT | Shake de câmera/nó/propriedade | Ambos |
| `ramokz/phantom-camera` | main `7945af6b` | MIT | Comportamentos de câmera (seguir grupo, enquadrar vários alvos) | Ambos |
| `BastiaanOlij/RERadialSunRays` | master `a8aba559` | MIT | Raios de sol radiais por CompositorEffect | Desktop |
| `sphynx-owner/JFA_driven_motion_blur_addon` | master `e46656da` | MIT | Motion blur por CompositorEffect | Desktop |
| `Bonkahe/SunshineClouds2` | main `a73a80b0` | MIT | Nuvens volumétricas (compute) | Desktop |
| `2Retr0/GodotOceanWaves` | main `a171446f` | MIT | Oceano FFT (compute) | Desktop |
| `Arnklit/Waterways` | main `cd2e2193` | MIT | Rios com mapas de fluxo e espuma | [NV no 4.7] |
| `MenacingMecha/godot-psx-style-demo` | master `91bd2498` | MIT | Estilo PS1 (vertex snapping, dither) | Referência |
| `GarrettGunnell/Post-Processing` | main `871a7ffc` | MIT | Algoritmos de pós-processo (HLSL) | Portar |
| `GarrettGunnell/AcerolaFX` | main `c33f779b` | MIT | Idem (ReShade) | Portar |
| `ashima/webgl-noise` | master `6abed1e7` | MIT | Ruído simplex/clássico/celular em GLSL | Ambos |

### 9.2 Assets e ferramentas

| Repositório | Branch / HEAD | Licença | Uso |
|---|---|---|---|
| `RPicster/Godot-particle-and-vfx-textures` | main `9bb6fe7c` | CC0 1.0 | Texturas de partícula e VFX |
| `KenneyNL/Starter-Kit-3D-Platformer` | main `3fa8a04b` | MIT | Exemplo de projeto 3D pequeno e limpo |
| `godot-extended-libraries/godot-debug-menu` | master `ff124615` | MIT | Overlay de FPS/tempo de quadro para medir no celular |
| `Calinou/godot-movie-maker-demo` | master `57956cff` | MIT | Exemplo de Movie Maker |
| `Scony/godot-gdscript-toolkit` | master `f61a1f3a` | MIT | `gdlint`/`gdformat` (PyPI `gdtoolkit`) |
| `godotengine/godot-docs` | branch 4.7 | CC BY 3.0 | Documentação offline |
| `Koisuji02/GodotShaderWarmup` | main `749516af` | MIT | Aquecimento de pipelines; é GDExtension e mira Forward+/Mobile: só referência de método |
| `effekseer/EffekseerForGodot4` | main `8706d291` | MIT | Runtime Effekseer; é GDExtension: complica Web (exige "extensions support") |

### 9.3 Evitar ou usar com cuidado

- `patriciogonzalezvivo/lygia`: Prosperity Public License, não permissiva.
- `patriciogonzalezvivo/thebookofshaders`: "all rights reserved".
- Arte dos repositórios GDQuest: não comercial.
- `devkcud/vesperafx`: MPL-2.0 (copyleft fraco por arquivo).
- `OBKF/Godot-Trail-System` (MIT, 2020), `EXPWorlds/Godot-Cel-Shader` (MIT, Godot 3.2), `CaptainProton42/FlexibleToonShaderGD` (MIT, Godot 3): são da era Godot 3.
- "Kiln Shader Kit" (Asset Library, MIT): a própria página diz que o código foi escrito com assistente de IA [W: https://godotengine.org/asset-library/asset/5609]; revisar antes de confiar.

Não encontrados (ls-remote falhou; nomes provavelmente errados ou privados): `eldskald/godot-portfolio-shaders`, `CozyCubeGames/godot-polyliner`, `leopeltola/Godot-post-process-outlines`, `eliornadir/sprite-in-3d-normals`, `jettelly/godot-shaders-bible`, `denovodavid/3d-pixel-art-in-godot`, e tentativas com `QbieShay/*` e `lukky-nl/*`.

---

## 10. (h) Web: restrições, orçamento e estratégia de dois níveis

### 10.1 Restrições do export Web

| Tema | Fato | Fonte |
|---|---|---|
| Renderer | Só Compatibility (WebGL 2.0). Sem WebGPU, logo sem Forward+/Mobile. `rendering/renderer/rendering_method.web` já vale `gl_compatibility` por padrão | [D][T] |
| Threads | Export de thread única é o padrão desde 4.3. Com threads exige cabeçalhos COOP/COEP (isolamento de origem), ou PWA com service worker que injeta os cabeçalhos | [D] |
| GDExtension | Só com "Extensions Support" (também exige isolamento) e binário compilado para Web. Preferir addons 100% GDScript | [D] |
| C# | Não exporta para Web no Godot 4 | [D] |
| Tamanho do motor | `index.wasm` do 4.7.2: **39,5 MB** bruto, **10,1 MB** com gzip. 4.5.1: 38,0 MB / 9,3 MB. `index.js`: 0,28 MB | [T] |
| Compressão | GitHub Pages aplica gzip; itch.io e GitLab Pages não comprimem sozinhos | [D] |
| Áudio | Padrão Web é o modo **Sample** (Web Audio API): baixa latência mesmo sem threads, mas **sem AudioEffects, sem reverb/doppler, sem áudio procedural**, e posicional limitado. Modo Stream libera tudo com mais latência | [D][T: `default_playback_type.web = 1`] |
| Áudio (implicação) | Síntese deve ser offline (Python gera WAV/OGG). Efeitos de bus (reverb, filtro) precisam ser assados nos arquivos | Dedução |
| Autoplay | Som só depois de um toque/clique: tela "toque para começar" | [D] |
| Tela cheia / captura de mouse | Só dentro de um evento de entrada (`_input`) | [D] |
| Persistência | `user://` usa IndexedDB; falha em modo anônimo ou iframe sem cookies de terceiros | [D] |
| Aba em segundo plano | O jogo pausa; partidas em rede podem cair | [D] |
| Shaders | Sem pré-compilação nem ubershader no Compatibility. Primeiro uso de cada material/partícula trava. Mitigação oficial: exibir cada material/partícula **dentro do frustum por ao menos um quadro** durante o carregamento | [D] |
| Safari / iOS | "Safari has several issues with WebGL 2.0"; relatos de perda de contexto WebGL e recarga por memória em iOS | [D][W: https://forum.godotengine.org/t/webgl-context-loss-and-app-crash-in-godot-4-3-exported-web-on-ios-browsers/81024] |
| Texturas | Limite típico de 4096×4096 em GPU móvel. Compressão VRAM "For Mobile" (ETC2/ASTC) precisa estar ligada no preset para celular | [D] |
| Rede (co-op online) | No navegador só WebSocket e WebRTC | [H] |
| Entrada | Toque, teclado e Gamepad API. `VirtualJoystick` embutido no 4.7 | [D][T] |

### 10.2 Orçamento inicial para WebGL2 em celular intermediário

Números de partida [H], sem medição em aparelho nesta etapa. Devem ser confirmados no celular do usuário com `godot-debug-menu`.

| Recurso | Alvo Web (celular) | Motivo |
|---|---|---|
| Resolução 3D | `scaling_3d_scale` 0,6 a 0,75 (bilinear) ou estilo pixel 0,33 a 0,5 (nearest); UI nativa | Fill rate é o gargalo em celular |
| Draw calls por quadro | Até cerca de 100 a 150 | Custo de CPU em WebAssembly de thread única |
| Triângulos visíveis | Até cerca de 100 a 200 mil | — |
| Personagens com skinning | 4 jogadores + 10 a 15 inimigos, 3 a 8 mil triângulos cada, até cerca de 40 ossos | — |
| Luzes dinâmicas | 1 direcional; 0 a 1 luz com sombra (mapa 1024 a 2048, 2 cascatas); até 4 omnis sem sombra perto da ação; nunca mais de 8 por malha | Seção 3.1; cada luz com sombra é um passe extra [D] |
| Sombras de personagens | Blob (quad) ou sombra única do sol | — |
| Partículas | `CPUParticles3D` para rajadas curtas (até 32 por efeito); total em tela na casa de poucas centenas; nada de turbulência | [D] desaconselha turbulência em mobile/web |
| Overdraw de VFX | No máximo 3 a 4 camadas transparentes de tela cheia sobrepostas no pico | — |
| Pós-processo | 1 passe de tela (grade + vinheta) fixo; tilt-shift com 8 taps opcional; glow leve; SSAO simples opcional | — |
| Leituras de `screen_texture`/`depth_texture` | Poucos materiais simultâneos | Cada uso força cópia do buffer |
| SubViewports | Zero em jogo | [W] relato de menos de 1 FPS |
| Materiais/shaders distintos | Poucas dezenas, todos pré-aquecidos | Compilação em WebGL trava |
| Texturas | 512 a 1024 por objeto, atlas de 2048; VRAM total abaixo de cerca de 150 a 200 MB | iOS derruba abas pesadas |
| Download inicial | 10 MB (wasm gzip) + `.pck`; mirar `.pck` até 20 a 30 MB | — |
| Quadro | 30 FPS estável é meta realista; 60 FPS em aparelhos fortes | — |

### 10.3 Estratégia de dois níveis

Detecção em runtime: `RenderingServer.get_current_rendering_method()` devolve `"gl_compatibility"`, `"forward_plus"` ou `"mobile"` [T]; `OS.has_feature("web")` identifica o export Web.

| Camada | Compartilhado (um só asset) | Só desktop (Forward+) | Só Web (Compatibility) |
|---|---|---|---|
| Geometria e animação | GLB do Blender, esqueletos, `AnimationLibrary`, IK | — | LOD mais agressivo |
| Materiais de personagem/cenário | Shaders próprios toon/unshaded + luz assada: pixels iguais (seção 4) | Textura normal/roughness para bordas internas | — |
| Contorno | Stencil outline ou casca invertida; X-ray | Contorno por distância (CE) | — |
| Luz | Rig de luz como `Resource` com dois perfis | Sombras PCSS, mais luzes, SDFGI ou VoxelGI, SSR, SSIL | Sol recalibrado ou sem sombra + blobs; `AMBIENT_SOURCE_COLOR` |
| Ambiente | Névoa por profundidade/altura, tonemap, ajustes/LUT, glow | Névoa volumétrica, `FogVolume`, autoexposição, glow com níveis | Glow simples, SSAO simples, raios de luz falsos |
| Foco | Mesma intenção artística | DOF por `CameraAttributes` | Tilt-shift por shader |
| VFX | Shader único, malhas, texturas, `CPUParticles3D`, fitas próprias, distorção de tela | Trilhas e sub-emissores de GPUParticles, colisão SDF, decals, luzes extras | Fallbacks: quad no lugar de decal, rajada extra no lugar de sub-emissor |
| Pós | Passe canvas (grade, vinheta, impact frame) | CompositorEffects, TAA/FSR2, SMAA | Escala 3D reduzida |
| Código | 100% | — | — |

Organização prática: dois `Environment` (`env_desktop.tres`, `env_web.tres`), grupos de nós `desktop_only` / `web_only` ligados na carga, e constantes de compensação no shader de VFX via `CURRENT_RENDERER`. Os VFX devem ser aprovados primeiro na Web; o desktop só soma.

---

## 11. (i) Movie Maker e captura de quadros

### 11.1 Movie Maker [D][T]

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --path PROJ \
  --rendering-method forward_plus --rendering-driver vulkan --audio-driver Dummy \
  --resolution 1280x720 --write-movie /abs/saida.avi --fixed-fps 30 --quit-after 61
```

| Formato | Como | Medido aqui (61 quadros, 720p, 4.7.2) |
|---|---|---|
| AVI (MJPEG + PCM) | `--write-movie x.avi` | Compatibility 4,1 s; Forward+ 7,0 s (tempo total, com inicialização); 2,1 MB |
| OGV (Theora + Vorbis) | `--write-movie x.ogv`; só em build de editor | 4,2 s; 64 KB |
| Sequência PNG + WAV | `--write-movie pasta/f.png` | 8,8 s; 12 MB; sem perdas; aceita transparência com `transparent_bg` |

- `--fixed-fps` torna o tempo de jogo determinístico: o mesmo roteiro gera os mesmos quadros, o que permite comparar "antes/depois" de um shader.
- Caminho relativo é relativo ao projeto. AVI tem limite de 4 GB. `--write-movie` e `--fixed-fps` também funcionam no projeto exportado.
- Efeitos que convergem em vários quadros (TAA, SDFGI, névoa volumétrica) ficam melhores gravando a FPS maior e reduzindo depois [D].
- `ffmpeg` está instalado com `libx264`, `libvpx-vp9`, `libwebp_anim` e GIF; conversões AVI → MP4, PNG → WebM e AVI → GIF funcionaram [T].
- `--headless` usa renderer nulo: para imagem é obrigatório Xvfb.
- Custo estimado de um trailer Forward+ "com tudo ligado" a 0,64 s/quadro: 30 s a 30 FPS ≈ 10 minutos de render.

### 11.2 Captura de quadros por script [T]

```gdscript
await RenderingServer.frame_post_draw
get_viewport().get_texture().get_image().save_png(path)
```

Roteiro usado: argumentos depois de `--` (`OS.get_cmdline_user_args()`) escolhem cena/efeito; após N quadros, salvar e `get_tree().quit()`. Para ler várias capturas de uma vez, montar folha de contato com Pillow.

### 11.3 Captura do build Web em WebGL2 real [T]

1. Exportar: `godot --headless --path PROJ --export-release "Web" /abs/web/index.html` (preset com `custom_template/release` apontando para `web_nothreads_release.zip`).
2. Servir: `python3 -m http.server 8765 --bind 127.0.0.1` na pasta do export.
3. Chrome: `google-chrome --headless=new --no-sandbox --use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader --ignore-gpu-blocklist --window-size=1280,720 --remote-debugging-port=9333 about:blank`.
4. Script Node 22 (apêndice B) abre a URL, espera `document.title == "PROBE_DONE"` (o jogo define o título via `JavaScriptBridge.eval`), captura com `Page.captureScreenshot` e imprime o console.
5. O modo `--screenshot --virtual-time-budget` **não funcionou** (expirou sem imagem).

Resultado: 11 efeitos renderizaram no WebGL2 do Chrome (`ANGLE (Google, Vulkan 1.3.0 (SwiftShader ...))`, textura máxima 8192): glow + SSAO + névoa, sprites com sombra, stencil outline e X-ray, casca invertida, contorno por profundidade, tilt-shift de 16 taps, distorção de tela, pós em canvas, colisão de partículas, toon com `light()`, atratores e turbulência. Isso valida funcionalidade, não desempenho.

---

## 12. Pontos em aberto e não verificados

1. Desempenho real em celular (FPS, memória, tempo de carga): nada foi medido em aparelho. O orçamento da seção 10.2 é heurístico.
2. `hint_depth_texture` zerado com MSAA em Forward+/Mobile: observado só sob lavapipe; falta GPU real.
3. Renderer Mobile sob lavapipe mostrou o chão muito mais escuro que os outros dois na cena base (55, 58, 81 contra 157, 149, 153): provável artefato do software renderer; Mobile não é alvo do projeto.
4. Bake de luz no Blender (Cycles CPU) → Godot: caminho recomendado, mas não executado nesta etapa.
5. `instance uniform` no Compatibility, colisão heightfield de partículas no Compatibility, `GPUTrail` no Compatibility: não testados.
6. Formato da sombra de sprites billboard com luz rasante: não analisado em detalhe.
7. Jolt em export Web de thread única: não testado.
8. Conteúdo de vídeos (Le Lu, FencerDevLog, Gamedev Aki, Acerola) e do livro da Jettelly: YouTube e as lojas estão bloqueados; as descrições vêm de resumos e coberturas.
9. Recursos do 4.8 além do `Trail3D`: só por notícias.
10. Compilar template Web reduzido (menos de 39 MB) exigiria emscripten; viabilidade neste ambiente não verificada.

---

## Apêndice A. Shaders validados (Compatibility, Forward+ e WebGL2)

As versões exatas abaixo foram extraídas deste arquivo, compiladas e renderizadas sem erro em Compatibility e Forward+ no 4.7.2 [T]. Variantes funcionalmente equivalentes (as usadas na bateria de testes) também rodaram no export Web em WebGL2 [T].

### A.1 Casca invertida com espessura aproximadamente constante em tela

```glsl
shader_type spatial;
render_mode unshaded, cull_front;
uniform float width = 0.04;
uniform vec3 color : source_color = vec3(0.03, 0.02, 0.08);
void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	VERTEX += NORMAL * width * clip.w * 0.15;
}
void fragment() { ALBEDO = color; }
```

Uso: `material.next_pass = outline_material`. Equivalente embutido (4.5+): `mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE; mat.stencil_color = ...; mat.stencil_outline_thickness = 0.05`. X-ray: `STENCIL_MODE_XRAY`.

### A.2 Contorno por profundidade com normal reconstruída (quad de tela cheia)

```glsl
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float thickness = 1.5;
uniform vec3 line_color : source_color = vec3(0.04, 0.02, 0.08);
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
vec3 view_pos(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, d) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return v.xyz / v.w;
}
void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	vec3 c = view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 r = view_pos(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	vec3 l = view_pos(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	vec3 u = view_pos(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	vec3 d = view_pos(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float lap = abs(r.z + l.z + u.z + d.z - 4.0 * c.z) / max(-c.z, 0.1);
	float edge_d = smoothstep(0.02, 0.06, lap);
	vec3 n0 = normalize(cross(r - c, u - c));
	vec3 n1 = normalize(cross(l - c, d - c));
	float edge_n = smoothstep(0.25, 0.6, 1.0 - dot(n0, n1));
	ALBEDO = mix(texture(screen_tex, SCREEN_UV).rgb, line_color, max(edge_d, edge_n));
}
```

Montagem do quad (GDScript): `QuadMesh` com `size = Vector2(2, 2)` e `flip_faces = true`; `MeshInstance3D` filho da câmera com `extra_cull_margin = 16384` e `cast_shadow` desligado.

### A.3 Tilt-shift / DOF por profundidade, 16 amostras

```glsl
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float focus_dist = 7.0;
uniform float focus_range = 1.5;
uniform float max_radius_px = 9.0;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, d) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}
void fragment() {
	float lin = lin_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float coc = clamp((abs(lin - focus_dist) - focus_range) / 4.0, 0.0, 1.0);
	vec2 px = coc * max_radius_px / VIEWPORT_SIZE;
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	for (int i = 1; i <= 16; i++) {
		float fi = float(i);
		vec2 o = vec2(cos(fi * 2.39996323), sin(fi * 2.39996323)) * sqrt(fi / 16.0) * px;
		col += texture(screen_tex, SCREEN_UV + o).rgb;
	}
	ALBEDO = col / 17.0;
}
```

### A.4 Onda de choque por distorção de tela (quad no mundo)

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float radius = 0.6;
uniform float width = 0.12;
uniform float strength = 0.06;
void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p) * 2.0;
	float ring = smoothstep(radius - width, radius, d) * smoothstep(radius + width, radius, d);
	vec2 off = normalize(p + 1e-5) * ring * strength;
	ALBEDO = texture(screen_tex, SCREEN_UV + off).rgb + vec3(0.6, 0.8, 1.0) * ring * 0.25;
	ALPHA = step(0.001, ring);
}
```

### A.5 Toon em faixas com hachura em tela (função `light()`)

```glsl
shader_type spatial;
uniform vec3 base : source_color = vec3(0.9, 0.5, 0.3);
uniform vec3 shade : source_color = vec3(0.35, 0.18, 0.3);
uniform float bands = 3.0;
void fragment() { ALBEDO = base; ROUGHNESS = 1.0; SPECULAR = 0.0; }
void light() {
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = floor(ndl * ATTENUATION * bands + 0.5) / bands;
	float hatch = step(0.5, fract((FRAGCOORD.x + FRAGCOORD.y) / 6.0));
	float h = mix(1.0, hatch * 0.5 + 0.5, step(lit, 0.34));
	DIFFUSE_LIGHT += mix(shade, vec3(1.0), lit) * h * LIGHT_COLOR / PI;
	float rim = pow(1.0 - dot(NORMAL, VIEW), 3.0) * step(0.6, ndl);
	SPECULAR_LIGHT += vec3(rim) * 0.3 * LIGHT_COLOR;
}
```

No Compatibility, com luz que projeta sombra, o resultado sai mais claro (seção 4).

### A.6 Pós em canvas (aberração cromática, vinheta, grade simples)

```glsl
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float ca = 0.006;
void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	vec3 col = vec3(texture(screen_tex, SCREEN_UV + d * ca).r,
			texture(screen_tex, SCREEN_UV).g,
			texture(screen_tex, SCREEN_UV - d * ca).b);
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, mix(vec3(0.1, 0.05, 0.25), vec3(1.0, 0.9, 0.7), l), 0.35);
	COLOR = vec4(col * smoothstep(0.85, 0.35, length(d)), 1.0);
}
```

Uso: `CanvasLayer` (layer alto) com `ColorRect` em `PRESET_FULL_RECT`; UI em outra camada acima.

## Apêndice B. Captura do build Web com Chrome headless (Node 22, sem dependências)

```js
// uso: node cdp.mjs <url> <saida.png> [timeoutMs]   (Chrome já aberto com --remote-debugging-port=9333)
import fs from 'node:fs';
const [url, out, tmo = '90000'] = process.argv.slice(2);
const port = 9333;
const tab = await (await fetch(`http://127.0.0.1:${port}/json/new?${encodeURIComponent(url)}`, { method: 'PUT' })).json();
const ws = new WebSocket(tab.webSocketDebuggerUrl);
let id = 0; const pending = new Map(); const logs = [];
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result ?? m.error); pending.delete(m.id); }
  else if (m.method === 'Runtime.consoleAPICalled') logs.push(m.params.type + ': ' + m.params.args.map(a => a.value ?? a.description ?? '').join(' '));
  else if (m.method === 'Log.entryAdded') logs.push('log.' + m.params.entry.level + ': ' + m.params.entry.text);
};
const send = (method, params = {}) => new Promise((res) => { const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params })); });
await new Promise((r) => (ws.onopen = r));
await send('Runtime.enable'); await send('Log.enable'); await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
const t0 = Date.now(); let done = false;
while (Date.now() - t0 < +tmo) {
  const r = await send('Runtime.evaluate', { expression: 'document.title' });
  if (r?.result?.value === 'PROBE_DONE') { done = true; break; }
  await new Promise((r) => setTimeout(r, 500));
}
const shot = await send('Page.captureScreenshot', { format: 'png' });
fs.writeFileSync(out, Buffer.from(shot.data, 'base64'));
console.log(JSON.stringify({ done, ms: Date.now() - t0 })); logs.forEach(l => console.log('  ' + l.slice(0, 260)));
await fetch(`http://127.0.0.1:${port}/json/close/${tab.id}`); ws.close(); process.exit(0);
```

No jogo: ler parâmetros com `JavaScriptBridge.eval("window.location.search")` e sinalizar o fim com `JavaScriptBridge.eval("document.title='PROBE_DONE'")`.

## Apêndice C. Extrair só o template Web do `.tpz` de 1,28 GB (Python padrão)

```python
import io, sys, zipfile, urllib.request, os
class HttpFile(io.RawIOBase):
    def __init__(self, url):
        with urllib.request.urlopen(urllib.request.Request(url, method='HEAD')) as r:
            self.url, self.size, self.pos = r.geturl(), int(r.headers['Content-Length']), 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else self.pos + off if whence == 1 else self.size + off
        return self.pos
    def readinto(self, b):
        if self.pos >= self.size: return 0
        end = min(self.size, self.pos + len(b)) - 1
        req = urllib.request.Request(self.url, headers={'Range': f'bytes={self.pos}-{end}'})
        with urllib.request.urlopen(req) as r: d = r.read()
        b[:len(d)] = d; self.pos += len(d); return len(d)
url = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
z = zipfile.ZipFile(io.BufferedReader(HttpFile(url), buffer_size=1 << 20))
open(os.path.join(sys.argv[1], 'web_nothreads_release.zip'), 'wb').write(z.read('templates/web_nothreads_release.zip'))
```

No `export_presets.cfg`: `custom_template/release="/caminho/web_nothreads_release.zip"`, `variant/thread_support=false`, `variant/extensions_support=false`.

## Apêndice D. Fontes principais

- Páginas de release: https://godotengine.org/releases/4.5/ , https://godotengine.org/releases/4.6/ , https://godotengine.org/releases/4.7/ (texto lido em `github.com/godotengine/godot-website`, `_data/release_4_6/features.yml` e `_data/release_4_7/features.yml`).
- Changelogs: https://github.com/godotengine/godot/blob/4.6.3-stable/CHANGELOG.md e https://github.com/godotengine/godot/blob/4.7.2-stable/CHANGELOG.md
- Guias de migração: https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.6.html e `upgrading_to_godot_4.7.html`
- Renderers: https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html
- Luzes e sombras: https://docs.godotengine.org/en/4.7/tutorials/3d/lights_and_shadows.html
- Ambiente e pós: https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html
- Pós avançado: https://docs.godotengine.org/en/4.7/tutorials/shaders/advanced_postprocessing.html
- Leitura de tela: https://docs.godotengine.org/en/4.7/tutorials/shaders/screen-reading_shaders.html
- Shader spatial (stencil): https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html
- Compositor: https://docs.godotengine.org/en/4.7/tutorials/rendering/compositor.html
- Partículas 3D: https://docs.godotengine.org/en/4.7/tutorials/3d/particles/index.html
- Lightmap: https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/using_lightmap_gi.html
- Compilação de pipelines: https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html
- Export Web: https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html
- Movie Maker: https://docs.godotengine.org/en/4.7/tutorials/animation/creating_movies.html
- Export Web em 4.3 (thread única): https://godotengine.org/article/progress-report-web-export-in-4-3/
- Fórum, compilação de shader de partícula na Web: https://forum.godotengine.org/t/handling-particle-shader-compilation-lag-in-godot-4-web-compatibility-renderer/36170
- Fórum, engasgos em Web mobile e pipeline de arte: https://forum.godotengine.org/t/godot-4-web-export-stutters-on-mobile-its-probably-your-art-pipeline-not-your-code-31fps-to-60fps-benchmarks-inside/143268
- Redução de `.pck` para HTML5 mobile: https://jacobfilipp.com/godot/

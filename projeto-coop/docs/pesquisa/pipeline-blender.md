# Pipeline Blender sem interface (bpy 5.3) → Godot: personagens, cenários, animação e sprites

Pesquisa feita em 27/11/2026. É só pesquisa: nada do jogo foi construído.

**Como ler a confiança de cada informação**

- **[teste]**: medido aqui, no container (4 CPUs, sem GPU, Blender 5.3.0 como módulo Python `bpy`, Godot 4.5.1). Os scripts e as saídas estão em `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-pipeline-blender/`, uma pasta temporária que pode ser apagada.
- **[doc]**: lido na documentação oficial hospedada no GitHub (`godotengine/godot-docs`, `KhronosGroup/glTF-Blender-IO/docs`).
- **[fonte]**: página externa com link. A ferramenta de leitura não alcança docs.blender.org nem a maior parte da web, então várias dessas fontes foram lidas só pelo resumo da busca.
- **[repo]**: o repositório respondeu a `git ls-remote <url> HEAD` neste container. A licença foi lida no arquivo LICENSE via raw.githubusercontent.com.
- **[não verificado]**: não consegui confirmar.

---

## 1. Resumo e decisões recomendadas

1. **O pipeline inteiro roda sem tela.** Funcionaram por script: Rigify (geração de rig), exportação glTF com várias actions, bake no Cycles, render no Cycles, **EEVEE** (via Vulkan por software, llvmpipe, sem `DISPLAY`), Workbench, Freestyle, Line Art, importação de BVH e importação headless no Godot (`godot --headless --import`) [teste].
2. **Squash and stretch por escala de osso chega ao Godot 4.5.1, com duas armadilhas** [teste]:
   - **O FPS de importação do Godot reamostra a animação.** O padrão é `animation/fps=30`; o Blender exporta a 24 fps. Numa pose-chave com escala Y = 0,6, o Godot devolveu 0,633. Com `animation/fps=24` (o fps do Blender) o valor ficou exato (0,6 e 1,291). **Regra: cena do Blender e importador do Godot no mesmo fps.**
   - **Matriz que não se decompõe em TRS (cisalhamento).** No Rigify com IK esticado, `DEF-hand.L` chegou ao Godot com erro de até 0,79 na matriz e `DEF-spine.003` com 0,07. Exportando com `export_hierarchy_flatten_bones=True` o erro caiu para menos de 0,002 em todos os ossos. O manual do exportador diz o mesmo: "Flatten Bone Hierarchy: useful in case of non-decomposable TRS matrix" [doc].
3. **Animação "em 2s" (passo constante, no estilo de Guilty Gear Xrd) sobrevive.** Keyframes CONSTANT viram `STEP` no glTF, e o Godot importa a trilha como `INTERPOLATION_NEAREST` [teste]. Isso permite misturar movimento interpolado e pose segurada por trilha.
4. **Cycles não tem "Shader to RGB"** [fonte: manual]. O toon no Cycles se faz com emissão: produto escalar entre a normal e um vetor de luz fixo, ligado a uma color ramp CONSTANT. Para o contorno, a casca invertida (Solidify com normais invertidas e segundo material) precisa do truque `Geometry > Backfacing`, porque o Cycles ignora backface culling. Testado: 0,2 a 0,3 s por sprite de 256 px com 16 amostras. Fica idêntico ao EEVEE, que levou 2,2 s com 8 amostras [teste].
5. **A cena vazia (`read_factory_settings(use_empty=True)`) quebra o Freestyle.** O lineset padrão fica com `linestyle=None`, sai "strokes set empty" e nenhuma linha. Com a cena de fábrica normal funcionou: 0,74 a 0,94 s a 256 px [teste]. Crie um `FreestyleLineStyle` por script.
6. **No Blender 5.x, `Action.fcurves` não existe mais** (actions em camadas, com slots). Use `bpy_extras.anim_utils.action_get_channelbag_for_slot(action, slot).fcurves` [teste].
7. **Modelagem: SDF e voxel por Geometry Nodes já vêm embutidos** (`PointsToSDFGrid`, `SDFGridFillet`, `SDFGridBoolean`, `SDFGridOffset`, `GridToMesh`). Um boneco de esferas sai em 0,2 a 0,65 s com 73 mil triângulos, mas com degraus de voxel visíveis, então precisa de suavização e dizimação [teste]. Para personagem de jogo, o melhor custo-benefício é **Skin modifier + Subsurf** (2.912 triângulos em 8 ms, e ainda gera armature) ou **primitivas e bmesh com bevel e subsurf**.
8. **Addons de terceiros: pouco ganho real.** O que importa vem embutido no `bpy` 5.3: rigify, io_scene_gltf2, io_anim_bvh, io_scene_fbx, pose_library, node_wrangler. Os externos úteis são o **Rigodotify** (MIT, rig de jogo a partir do Rigify) e talvez o **MPFB2** (GPLv3, com assets CC0, para proporções e pesos de referência). Rodar código baixado foi bloqueado pela política de permissões, então o MPFB2 não foi executado (seção 8).
9. **Packs prontos dão cara de asset flip.** KayKit, Kenney e Quaternius são CC0 e conhecidíssimos. Use como placeholder de gameplay ou como referência de proporção e contagem de polígonos, nunca no jogo final. Mocap CMU (livre) e 100STYLE (CC BY 4.0) servem para retarget e timing. LaFAN1 e Bandai Namco são **proibidos** (NC/ND).

---

## 2. Resultados dos testes práticos [teste]

| Teste | Resultado | Tempo |
|---|---|---|
| Rigify, `armature_human_metarig_add` + `pose.rigify_generate()` | rig com 706 ossos, 160 deformadores (com rosto) | 7,08 s (6,47 s em "Generate bones") |
| Rigify, `armature_basic_human_metarig_add` | 222 ossos, 35 deformadores | 0,13 a 0,17 s |
| Blob com squash and stretch (escala de osso, volume preservado: x = z = 1/√y), 2 actions empurradas para o NLA, exportação GLB | glTF com 2 animações; trilha de escala `LINEAR` com 30 amostras | exportação 0,11 a 0,19 s |
| Godot 4.5.1, importação headless desse GLB | `AnimationPlayer` com ["Idle","Jump"]; escala não uniforme preservada; com fps=30, pico 0,633 (esperado 0,6); com fps=24, **exato** | importação < 10 s |
| Cisalhamento: osso filho girado sob pai com escala (0,7; 1,8; 0,7) | `inherit_scale=FULL`: **idêntico** no Godot. `ALIGNED`/`NONE`: **errado** (ex.: coluna X (0,58; −0,51; 0,29) contra (0,56; −0,17; 0,38) esperados). Com `flatten_bones`: **idêntico** | — |
| Rigify com IK esticado e torso achatado, só ossos DEF | 35 ossos no Godot, 13 trilhas de escala variando. Sem flatten: erro máximo 0,79 (mão), 0,07 (coluna). **Com flatten: < 0,002** | geração 0,13 s, exportação 0,13 s |
| Animação em passo (CONSTANT, 12 poses em 24 quadros) | glTF `STEP`, 12 chaves; Godot `INTERPOLATION_NEAREST`, 11 mudanças de pose | — |
| Bake de 512 px no Cycles (Suzanne com subsurf; alta poligonagem de 252 mil triângulos com Displace) | difuso 1,65 s (inclui aquecimento); normal de alta para baixa 0,34 s; AO com 64 amostras 3,37 s; curvatura (Pointiness → emissão) 0,36 s | ver seção 4 |
| Bake de 1024 / 2048 px | 1024: 0,71 / 0,57 / 10,3 / 0,62 s. 2048: 1,89 / 1,58 / 35,5 / 1,56 s (difuso / normal / AO com 64 amostras / curvatura) | — |
| Sprite de 256 px, 8 direções, toon por emissão + casca invertida | **Cycles com 16 amostras: 0,20 a 0,29 s/quadro** (o 1º leva 0,4 a 0,65 s) | 8 quadros em cerca de 2 s |
| EEVEE sem `DISPLAY` | **funciona**, backend `VULKAN`, `llvmpipe (LLVM 20.1.2)`, Mesa 25.2.8. 64 amostras: 11,5 s/quadro; 8 amostras: 2,2 s; 1 amostra: 0,8 a 1,0 s | — |
| Workbench sem tela | funciona, 0,2 s/quadro | — |
| Freestyle (Cycles, 256 px) | funciona na cena de fábrica; na cena vazia, sem linhas (linestyle None) | 0,74 a 0,94 s |
| Line Art (Grease Pencil v3, `grease_pencil_add(type='LINEART_SCENE')`) | gera traços (3 strokes no cubo) e renderiza no Cycles e no EEVEE, mas a linha padrão é fina demais (raio 0,0025); espessura grossa não verificada | Cycles 0,9 s; EEVEE 3,4 s |
| EXR multicamada com passes Normal e Depth | canais `ViewLayer.Normal.X/Y/Z`, `ViewLayer.Depth.Z` presentes | 0,53 a 0,74 s |
| Metaballs → malha → Remesh voxel 0,02 + Corrective Smooth | 14.320 triângulos | 0,04 s |
| Skin modifier + Subsurf 2, 12 vértices de esqueleto | 2.912 triângulos; `skin_armature_create` gera armature | 0,008 s |
| GN mesh → volume → mesh | 5.220 triângulos | 0,3 s |
| GN `PointsToSDFGrid` → `SDFGridFillet` → `GridToMesh` (voxel 0,015) | 72.976 triângulos, forma de "boneco de massinha" com degraus de voxel visíveis | 0,22 a 0,65 s |
| BVH CMU 02_05 ("punch/strike"), `import_anim.bvh` | 31 ossos, 1.855 quadros | 0,43 s |

Detalhe do API de exportação no 5.3 [teste]: `export_animation_mode` aceita `ACTIONS | ACTIVE_ACTIONS | BROADCAST | NLA_TRACKS | SCENE` (padrão `ACTIONS`); `export_force_sampling=True`, `export_optimize_animation_size=True`, `export_rest_position_armature=True` e `export_def_bones=False` são os padrões. O formato de imagem do render mudou: `image_settings.media_type='MULTI_LAYER_IMAGE'` + `file_format='OPEN_EXR_MULTILAYER'`. Os avisos "Draco/MeshOptimizer not available" do `bpy` do PyPI são inofensivos (não há compressão Draco).

---

## 3. (a) Modelagem por script: técnicas e qualidade

| Técnica | O que dá | Teto de qualidade | Onde usar | Custo |
|---|---|---|---|---|
| **Primitivas + modificadores** (Bevel, Subsurf, Mirror, Solidify, Array, Boolean, Weighted Normal) | formas duras e limpas, topologia controlada | alto para props, arquitetura e armas estilizadas (estilo "toy/diorama") | cenário modular, props, armaduras | ms |
| **bmesh** (extrude, inset, bevel, bridge loops, spin) | controle total de topologia e loops de deformação | o mais alto para personagem low/mid-poly **se** o gerador for bem escrito (loops em ombro, cotovelo e joelho) | corpo base de personagem, rosto simples | ms |
| **Skin modifier** (esqueleto de vértices com raio por vértice) + Subsurf | tubo orgânico em quads; gera armature junto | médio-alto para criaturas e chibis; mãos e rosto ficam "salsicha" | criaturas, membros, caudas, protótipo de herói | 8 ms [teste] |
| **Metaballs → malha → Remesh voxel** | blobs orgânicos de fusão suave | médio: topologia de triângulos e quads irregular, ruim para deformar sem retopo | rochas, nuvens, cogumelos, VFX sólidos | 40 ms [teste] |
| **SDF por Geometry Nodes** (`PointsToSDFGrid`, `MeshToSDFGrid`, `SDFGridBoolean`, `SDFGridFillet`, `SDFGridOffset`, `GridToMesh`) | união suave, fillet e offset reais | médio: degraus de voxel; precisa de Smooth + Decimate e talvez Shrinkwrap sobre uma malha limpa | esculturas orgânicas, terreno, estátuas; base para "retopo" por shrinkwrap | 0,2 a 0,65 s [teste] |
| **SDF em Python puro** (`fogleman/sdf`, MIT, marching cubes) | mesma ideia fora do Blender | igual ao anterior | já há um rig SDF no repo (`ceu-arcano/pipeline/pixelrig`) | não testado |
| **Curvas** (Bezier com bevel/taper, Curve to Mesh em GN) | cabelo em mechas, cordas, vinhas, cintos, trilhos | alto para cabelo estilizado em mechas (o padrão anime/Arcane) | cabelo, acessórios, plantas | ms |
| **Geometry Nodes criados por Python** (`node_groups.new(...,'GeometryNodeTree')`, `interface.new_socket`) | scatter, instâncias, pedra/madeira procedural, variações | alto para cenário (milhares de instâncias por seed) | vegetação, ruínas, dungeons por kit | testado: 0,3 s |
| **Deslocamento procedural** (Displace com textura Voronoi/Noise, ou displacement no material + bake de normal) | detalhe de superfície | alto se for assado em normal map e a malha final continuar leve | pedra, casca de árvore, tecido | bake 0,3 a 1,6 s |
| Sverchok / Tissue (addons) | nós paramétricos, tesselação | redundante com GN nativo | não recomendado | — |

**Conclusões práticas**

- Personagem: **corpo por bmesh ou Skin com proporções paramétricas, cabeça grande, mãos de 3 ou 4 dedos em bloco, cabelo por curvas, roupa por Solidify sobre seleção de faces.** Fica em 2 a 6 mil triângulos, deforma bem e se lê na câmera do co-op, que fica afastada.
- Cenário: **kit modular por primitivas e bevel + GN para espalhar** + materiais assados. O "acabamento AAA" vem de luz e pós-processamento no Godot e de bevels que pegam brilho (Weighted Normal), não de contagem de polígonos.
- SDF e metaball ficam para coisas orgânicas que não deformam (rochas, troncos, estátuas, cogumelos). O degrau de voxel vira "massinha", um estilo válido se for proposital (ver `direcao-de-arte.md`).

---

## 4. (b) UV e texturas sem interface

| Operador | Uso | Observação |
|---|---|---|
| `bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)` | UV automática para bake | funciona em modo de edição sem tela [teste]; ilhas fragmentadas, ok para bake e ruim para pintar |
| `bpy.ops.uv.lightmap_pack()` | segunda UV para lightmap (LightmapGI do Godot) | não testado; o Godot também gera UV2 na importação |
| `bpy.ops.uv.unwrap` com costuras marcadas por script (`edge.seam=True` via bmesh) | UV limpa para personagem | o gerador de malha sabe onde estão os loops; marque costura neles |
| Pack: `bpy.ops.uv.pack_islands(margin=...)` | empacotamento | embutido |

**Bake no Cycles (CPU, 4 núcleos), tempos reais [teste]:**

| Mapa | 512 px | 1024 px | 2048 px | Como |
|---|---|---|---|---|
| Albedo (DIFFUSE, só COLOR) | 1,65 s* | 0,71 s | 1,89 s | `bake(type='DIFFUSE', pass_filter={'COLOR'})`, 1 amostra |
| Normal (alta → baixa, 252 mil triângulos) | 0,34 s | 0,57 s | 1,58 s | `use_selected_to_active=True, cage_extrusion=0.05` |
| AO (64 amostras) | 3,37 s | 10,3 s | 35,5 s | a mais cara; 16 a 32 amostras + desfoque bastam para estilizado |
| Curvatura | 0,36 s | 0,62 s | 1,56 s | atributo `Pointiness` (só Cycles) → Map Range → Emission → `bake(type='EMIT')` |
| Espessura | — | — | — | não testado; via AO com normais invertidas (`Ambient Occlusion` com `inside=True`) assado como EMIT |

*inclui inicialização. Observação: o normal assado mostrou faixas espúrias em ilhas de borda (orelha da Suzanne). Ajuste `cage_extrusion` ou use uma cage explícita.

**Vertex color**: o glTF exporta `COLOR_0`, e o Godot usa isso em `vertex_color_use_as_albedo`. Para estilo chapado (toon de 3 a 5 cores por região), **vertex color dispensa textura e UV**: é o caminho mais robusto para script e para Web (zero amostragem de textura). O exportador 5.3 tem `export_vertex_color = MATERIAL | ACTIVE | NAME | NONE` [teste]. Para o Godot pegar a cor, o material precisa usar o atributo de cor (ou use `ACTIVE`).

**Orçamento de textura**: personagem com 512 ou 1024 px (albedo + normal), cenário com atlas de 1024 a 2048 compartilhado. 20 personagens com 4 mapas a 1024 px dão cerca de 4 min de bake.

---

## 5. (c) Rig

### 5.1 Rigify por script (funciona sem tela) [teste]

```python
import addon_utils; addon_utils.enable("rigify", default_set=True)
bpy.ops.object.armature_basic_human_metarig_add()   # ou armature_human_metarig_add (com rosto)
# ...ajustar edit_bones do metarig às proporções do personagem...
bpy.ops.pose.rigify_generate()                      # cria o objeto "rig"
rig = bpy.data.objects["rig"]
bpy.data.objects.remove(meta)                        # senão o metarig também é exportado
# apagar objetos/coleção "WGT*" (widgets) antes de exportar
```

- Pesos: `bpy.ops.object.parent_set(type='ARMATURE_AUTO')` (heat weights) funciona em background, desde que a malha seja estanque [não testado aqui].
- O Rigify cru é ruim para jogo: os DEF ficam pendurados em ORG/MCH (ex.: `DEF-pelvis.L` tem pai `ORG-pelvis.L`), há 222 ou 706 ossos e a hierarquia é estranha [teste, e [fonte](https://developer.blender.org/T57536)]. Com `export_def_bones=True`, o exportador mantém só os 35 DEF e refaz a hierarquia (`DEF-forearm.L` passa a ter pai `DEF-upper_arm.L.001` no Godot) [teste].
- **Rigodotify** ([github.com/catprisbrey/Rigodotify](https://github.com/catprisbrey/Rigodotify), MIT, [repo]): feature set do Rigify que converte o rig em esqueleto padrão Godot, Unity ou Unreal (root → pelvis → spine_01..03 → ...), com nomes amigáveis para o `BoneMap`/`SkeletonProfileHumanoid` do Godot e "constraints ajustadas para minimizar erros de escala". Também traz metarigs compatíveis com o Universal Animation Library do Quaternius. Instalação por UI documentada; por script, não verificado.
- **GameRig** ([github.com/Arminando/GameRig](https://github.com/Arminando/GameRig), GPL-2.0, [repo]): outra variante do Rigify para jogo.

### 5.2 Rig próprio (recomendado para personagem estilizado gerado por script)

O gerador de malha conhece as juntas, então pode criar o armature diretamente com uns 20 a 30 ossos: root, hips, spine ×2, chest, neck, head, ombro/braço/antebraço/mão ×2, coxa/canela/pé/dedo ×2, mais ossos extras de squash, cabelo e capa. Vantagens: hierarquia de jogo desde o início, nomes casando com `SkeletonProfileHumanoid` (retarget no Godot por `BoneMap`) e pesos por distância ou por vertex group gerado junto com a geometria. As constraints de animação (IK, Stretch To, Copy Rotation) ficam só no Blender e saem assadas no glTF.

### 5.3 Squash and stretch que sobrevive ao glTF

Regras confirmadas por teste:

1. **Mesmo fps** no Blender (`scene.render.fps`) e no import do Godot (`animation/fps` no `.import`, ou por padrão de projeto). Com 30 contra 24, as chaves são reamostradas e os picos de squash ficam ~5% mais rasos.
2. **Cadeia com `inherit_scale='FULL'`** (padrão) chega idêntica ao Godot, inclusive com cisalhamento herdado. `ALIGNED`, `NONE`, `AVERAGE` e `NONE_LEGACY`, ou ossos guiados por constraints como os DEF do Rigify, geram matriz não decomponível. Aí é preciso `export_hierarchy_flatten_bones=True`.
3. **Custo do flatten**: no Godot, todos os ossos viram filhos diretos do root. Retarget por `BoneMap` e IK do Godot (`TwoBoneIK3D` etc., que só existem no 4.6+) deixam de fazer sentido. Alternativas:
   - (a) Hierarquia de jogo limpa e squash só em **ossos-folha dedicados** (ex.: `squash_body` filho de `hips`, com a malha do tronco pesada nele) ou na **escala uniforme do root**. Sem cisalhamento e sem flatten.
   - (b) Flatten para personagens 100% animados no Blender (sem IK em runtime).
   - (c) **Shape keys** para squash facial e de corpo (morph targets do glTF; o Godot importa como blend shapes, que podem ser animadas). Custo: memória por vértice.
4. Sempre `export_force_sampling=True` quando houver constraints, drivers ou IK: o exportador amostra a pose final [teste: trilhas de escala do Rigify esticado chegaram].

### 5.4 Ossos de mola (overlap, follow-through)

- **No Godot (runtime, recomendado)**: `SpringBoneSimulator3D` existe no 4.5.1 [teste: `ClassDB.class_exists` = true], junto com `LookAtModifier3D`, `BoneConstraint3D`, `CopyTransformModifier3D`, `AimModifier3D`, `RetargetModifier3D` e `PhysicalBoneSimulator3D`. `TwoBoneIK3D`/`IKModifier3D` **não existem no 4.5.1** [teste] e chegam no 4.6 ([godotengine.org/article/inverse-kinematics-returns-to-godot-4-6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)). Cabelo, capa, cauda e orelhas ficam melhores como molas em runtime: reagem ao movimento real do jogador, a animação continua leve, e a física funciona nas duas plataformas.
- **No Blender (assado)**: Wiggle 2, Jiggle Physics, Wiggle Bones e Spring Bones (tabela na seção 8). Todos dependem de handler de mudança de quadro. Para bake sem tela: tocar quadro a quadro (`scene.frame_set`) e depois `bpy.ops.nla.bake(visual_keying=True, clear_constraints=False, bake_types={'POSE'})` [não testado]. O próprio autor do Wiggle 2 avisa que o bake é instável em versões novas ([fonte](https://github.com/shteeve3d/blender-wiggle-2/releases)). **Mais simples e determinístico: escrever a mola em Python** (integrador massa-mola amortecido sobre a rotação dos ossos da cadeia, quadro a quadro, gravando keyframes). São 40 a 60 linhas, sem dependência de addon.

---

## 6. (d) Animação por Python, NLA, glTF e importação no Godot

### 6.1 Keyframes no Blender 5.x

```python
from bpy_extras import anim_utils
act = bpy.data.actions.new("Attack_Light")
arm.animation_data_create(); arm.animation_data.action = act
pb = arm.pose.bones["spine"]; pb.rotation_mode = 'XYZ'
pb.rotation_euler = (0.3, 0, 0); pb.keyframe_insert("rotation_euler", frame=1)
cb = anim_utils.action_get_channelbag_for_slot(act, arm.animation_data.action_slot)
for fc in cb.fcurves:                       # act.fcurves NÃO existe mais [teste]
    for kp in fc.keyframe_points:
        kp.interpolation = 'BEZIER'          # ou 'CONSTANT' para pose segurada
        kp.easing = 'EASE_IN_OUT'
        kp.handle_left_type = kp.handle_right_type = 'AUTO_CLAMPED'   # ou 'FREE' + coordenadas p/ overshoot
```

Para os 12 princípios por código:

- **Timing e spacing**: quadro de cada chave + handles `FREE` com coordenadas explícitas (ease in/out mais forte que o AUTO).
- **Antecipação e follow-through**: chaves de contra-movimento antes e de overshoot depois, decaindo.
- **Overlapping**: deslocar as chaves de ossos filhos 1 a 3 quadros, por cadeia.
- **Arcos**: gerar posição de mão/pé por curva Bezier e resolver com IK no Blender (fica assado na exportação).
- **Squash and stretch**: escala com volume preservado (x = z = 1/√y).
- **Pose segurada** (golpes no estilo de luta): chaves `CONSTANT`, que chegam como `NEAREST` no Godot [teste].
- **Hit-stop e smear** ficam no Godot: `AnimationPlayer.speed_scale = 0` por 60 a 100 ms, e smear como malha extra ou shader.

### 6.2 Várias animações num glTF

- `export_animation_mode='ACTIONS'` (padrão): cada action vira uma animação glTF com o nome da action. Para o exportador encontrar a action sem que ela esteja atribuída, empurre-a para o NLA (`track.strips.new(name, start, action)`) [teste: "Idle" e "Jump" chegaram].
- `NLA_TRACKS`: uma animação por trilha NLA (bom para combinar ações de vários objetos).
- `use_fake_user=True` em toda action, senão ela some ao salvar.
- Loops: sufixo `-loop` no nome da animação faz o importador marcar como loop ([doc](https://github.com/godotengine/godot-docs/blob/4.5/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.rst)). Também dá para marcar por import script.
- Rest pose: `export_rest_position_armature=True` (padrão) exporta a pose de descanso como bind.
- Grandes bibliotecas: um GLB só com o esqueleto e as animações e outro com a malha. No Godot, use `AnimationLibrary` compartilhada (via "Save to file" nas opções avançadas de importação ou por import script).

### 6.3 Como o Godot importa

- `.blend` direto exige o executável do Blender no caminho configurado em Editor Settings ("Blender 3 Path"). Não funciona nos editores Web/Android, e cada pessoa da equipe precisa ter Blender ([doc](https://github.com/godotengine/godot-docs/blob/4.5/tutorials/assets_pipeline/importing_3d_scenes/available_formats.rst)). Aqui o Blender é só módulo `bpy`, então **glTF (.glb) é o caminho**, que também é o recomendado pela própria doc.
- Opções que importam no `.import` ([doc](https://github.com/godotengine/godot-docs/blob/4.5/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.rst)):
  - `animation/fps`: assa as curvas em pontos lineares nesse fps. **Ajuste para o fps do Blender**, pelo teste da seção 2.
  - `animation/trimming`, `animation/remove_immutable_tracks=true`: este último apaga trilhas de escala constantes; tudo bem, porque as de squash variam.
  - Import script (`EditorScenePostImport`): pós-processamento automático (trocar materiais por ShaderMaterial toon, criar colisões, marcar loops, extrair `AnimationLibrary`).
  - Sufixos de nó: `-col`, `-colonly`, `-convcolonly`, `-noimp`, `-loop`, `-navmesh`.
- **Verificação automática** (já funciona aqui): `godot --headless --import` seguido de um `SceneTree` que carrega o `.glb`, lista animações, mede trilhas de escala e compara `get_bone_global_pose` com as matrizes do Blender (scripts `check.gd`, `shear.gd`, `rigcmp.gd` na pasta de testes). **Recomendo transformar isso em teste de regressão do pipeline.** Conversão de eixo: Godot (x, y, z) = Blender (x, z, −y).

---

## 7. (e) Bake de sprites para HD-2D

### 7.1 Setup que funcionou [teste]

- Câmera ortográfica (`ortho_scale` fixo por tamanho de personagem), filha de um Empty pivô. Girar o pivô em `i·45°` dá 8 direções, e `film_transparent=True`. Para ficar no pixel, `filter_width` ~0,8 a 1,0 (ou 0,01 para pixel duro) e resolução 2× com redução por nearest no pós.
- **Toon por emissão (Cycles e EEVEE)**: `Geometry.Normal · L` → `ColorRamp(CONSTANT, 3 faixas)` → Emission. Dá luz fixa de "pintura", independente de lâmpada. Desvantagem: sem sombra projetada. Se quiser sombra projetada, use o passe `Diffuse Direct` + quantização no compositor (não testado), ou EEVEE com `Shader to RGB` (EEVEE apenas, [fonte](https://www.blender.org/manual/en/render/shader_nodes/converter/shader_to_rgb.html)).
- **Contorno**:

  | Método | Estado no teste | Comentário |
  |---|---|---|
  | **Casca invertida** (Solidify `offset=1`, `use_flip_normals`, `material_offset=1`; material: Mix(Emission preta, Transparent) com fator `Backfacing`) | **funciona em Cycles e EEVEE**, 0,2 s/quadro | **recomendado**: controle por vertex group (espessura variável = linha "de pincel"), e o mesmo truque roda no Godot em tempo real |
  | Freestyle | funciona (0,74 a 0,94 s) **se** houver linestyle | linhas de crease e silhueta de qualidade "ilustração", mais lento e pouco controlável quadro a quadro (cintila) |
  | Line Art (GP v3) | renderiza, mas linha padrão quase invisível em 256 px | ajustar `radius` e material; não validado |
  | Pós no Godot (Sobel em profundidade/normal) | — | ver `godot-render-vfx.md` |

- **Passes para luz 2D no Godot**: EXR multicamada com `Normal` e `Depth` [teste]. O passe Normal do Cycles é em **espaço de mundo**. Para normal map de sprite, renderize uma segunda passada com material override emitindo a normal em espaço de câmera (`Vector Transform World→Camera`, ×0,5 + 0,5), sem antialias. A convenção de Y do Godot 2D (`CanvasTexture.normal_texture`) não foi verificada. A profundidade serve para ordenar o sprite e para oclusão no cenário 3D (HD-2D).
- **Workbench** (0,2 s) serve para pré-visualização e silhuetas. Não serve como render final.

### 7.2 Orçamento de render (com os tempos medidos)

Por exemplo: 4 heróis × 12 animações × 10 quadros × 8 direções = 3.840 quadros.

| Motor | s/quadro (256 px) | Total |
|---|---|---|
| Cycles, toon por emissão, 16 amostras | 0,25 | ~16 min (+ ~16 min para o passe de normal) |
| EEVEE, 8 amostras | 2,2 | ~2 h 20 min |
| EEVEE, 1 amostra | 0,9 | ~58 min |

Conclusão: **para sprites toon, o Cycles com material de emissão é 4 a 9 vezes mais rápido que o EEVEE neste container sem GPU**, porque o EEVEE paga a rasterização Vulkan em software. O EEVEE só vale quando o visual precisar de `Shader to RGB` ou dos efeitos de tela dele.

### 7.3 Sprites 2D ou 3D completo?

- Sprite pré-renderizado: 8 direções × N quadros incham a memória (3.840 quadros de 256² ≈ 1 GB sem compressão, e mesmo em atlas com BC/ETC continua pesado para Web). O personagem perde equipamento visível trocável, a não ser que se renderize por camadas.
- 3D completo em toon no Godot (Compatibility): o mesmo `.glb` com casca invertida, shader de rampa e animação em passo para dar "sensação de 2D" (técnica do Guilty Gear Xrd: poses-chave seguradas, normais editadas, sombra controlada; [GDC 2015, Junya Motomura](https://gdcvault.com/play/1022031/GuiltyGearXrd-s-Art-Style-The), [handout PDF](https://www.ggxrd.com/Motomura_Junya_GuiltyGearXrd.pdf)). **Menos memória, equipamentos trocáveis, câmera livre.** Para um co-op de ação com loot, é o mais sensato.
- Dead Cells é a referência do 3D renderizado para pixel: modelo 3D, keyframes com poucas poses, render em resolução baixa sem antialias ([Thomas Vasseur, "Art Design Deep Dive" (republicação)](https://www.jikguard.com/news/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-dead-cells), [80.lv](https://80.lv/articles/case-study-dead-cells-character-art-pipeline)). O HD-2D da Square Enix (sprites + cenário 3D + DOF, tilt-shift e bloom) é descrito em [Unreal Engine: Octopath II](https://www.unrealengine.com/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style) e [Wikipedia HD-2D](https://en.wikipedia.org/wiki/HD-2D). Na Web (Compatibility) não há DOF de alta qualidade nem névoa volumétrica, então o HD-2D perde parte do charme.

---

## 8. (f) Addons gratuitos (GitHub/PyPI), verificados

Todos responderam a `git ls-remote` [repo]. Os addons são baixáveis por `git clone`; o `.zip` do codeload dá 403. Nenhum foi executado: **rodar código de terceiros recém-baixado foi bloqueado pela política de permissões desta sessão** (o teste do MPFB2 foi negado). Exige autorização explícita do usuário.

| Addon | Repo | Licença | Sem interface? | Veredito |
|---|---|---|---|---|
| Rigify | embutido no `bpy` 5.3 | GPL | **sim** [teste] | usar |
| glTF IO | embutido; fonte [KhronosGroup/glTF-Blender-IO](https://github.com/KhronosGroup/glTF-Blender-IO) | Apache-2.0 | **sim** [teste] | usar; a doc em `docs/blender_docs/scene_gltf2.rst` é a referência de flags |
| BVH import | embutido (`io_anim_bvh`) | GPL | **sim** [teste] | usar para mocap |
| **Rigodotify** | [catprisbrey/Rigodotify](https://github.com/catprisbrey/Rigodotify) | MIT | provável (operadores de armature); não testado | **bom candidato** se usarmos Rigify |
| GameRig | [Arminando/GameRig](https://github.com/Arminando/GameRig) | GPL-2.0 | não testado | alternativa |
| **MPFB2** (MakeHuman) | [makehumancommunity/mpfb2](https://github.com/makehumancommunity/mpfb2), v2.0.18, Blender ≥ 4.2 | código GPLv3; **assets CC0** (base mesh, targets, rigs, pesos) | tem API Python (`HumanService.create_human()`, `add_builtin_rig(basemesh, "game_engine")`, `RigService.generate_rigify_rig`) e 10 scripts de exemplo em `script_samples/`; o clone raso (108 MB) traz base.obj, 41 MB de targets e rigs `game_engine`, `mixamo`, `cmu_mb`, `rigify.human` | útil como **referência de proporção, topologia e pesos CC0**; o visual é humano realista, não estilizado. Execução não testada (bloqueada) |
| CharMorph | [Upliner/CharMorph](https://github.com/Upliner/CharMorph) | código GPLv3; **personagens MB-Lab em AGPLv3** e licença por personagem | não testado | evitar: licença dos modelos complica e o estilo é realista |
| Wiggle 2 | [shteeve3d/blender-wiggle-2](https://github.com/shteeve3d/blender-wiggle-2) | GPLv3 | handler de quadro; bake instável segundo o autor | preferir mola própria ou `SpringBoneSimulator3D` |
| Jiggle Physics (fork do Wiggle 2) | [naelstrof/blender-jiggle-physics](https://github.com/naelstrof/blender-jiggle-physics) | GPLv3 | idem; "desliga no render" | idem |
| Wiggle Bones | [Hans-xwh/wiggle-bones](https://github.com/Hans-xwh/wiggle-bones) | GPLv3 | não testado | idem |
| Spring Bones | [artellblender/springbones](https://github.com/artellblender/springbones) | sem LICENSE na raiz [não verificado] | "alpha, proof of concept" | não usar |
| JiggleArmature | [JacquesLucke/JiggleArmature](https://github.com/JacquesLucke/JiggleArmature) | MIT | bake removido | não usar |
| Expy-Kit (conversão de rig / retarget) | [pKrime/Expy-Kit](https://github.com/pKrime/Expy-Kit) | GPL | não testado | opcional para retarget BVH → rig próprio |
| Rokoko Studio Live (retarget) | [Rokoko/rokoko-studio-live-blender](https://github.com/Rokoko/rokoko-studio-live-blender) | LGPL-3.0 | não testado; feito para UI | opcional |
| TexTools | [franMarz/TexTools-Blender](https://github.com/franMarz/TexTools-Blender) | GPL | operadores de UI | redundante (bake nativo basta) |
| Tissue | [alessandro-zomparelli/tissue](https://github.com/alessandro-zomparelli/tissue) | GPL-3.0-or-later | não testado | redundante com GN |
| Sverchok | [nortikin/sverchok](https://github.com/nortikin/sverchok) | GPLv3 | pesado | redundante com GN |
| Sprites multi-direção | [aurodev/BlenderSpriteGenerator](https://github.com/aurodev/BlenderSpriteGenerator), [Mattline1/SpriteAtlasAddon](https://github.com/Mattline1/SpriteAtlasAddon) | não verificada | — | desnecessário: o script da seção 7 tem cerca de 60 linhas |
| fake-bpy-module (tipagem para o agente) | [nutti/fake-bpy-module](https://github.com/nutti/fake-bpy-module), também no PyPI | MIT | n/a | útil para pyright/mypy nos scripts |
| `sdf` (SDF → malha em Python) | [fogleman/sdf](https://github.com/fogleman/sdf) | MIT | n/a | opcional; o GN SDF nativo cobre |

Os addons GPL só afetam o código do addon. O que ele **gera** (malha, animação) não herda a GPL, mas não se deve embutir o código no jogo.

---

## 9. (g) Assets e bibliotecas de movimento no GitHub

| Recurso | Repo | Licença (lida no repo) | Observação |
|---|---|---|---|
| KayKit Adventurers (personagens + 75 animações) | [KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0) | **CC0** | estilo muito reconhecível |
| KayKit Skeletons | [KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0) | **CC0** | |
| KayKit Dungeon Remastered | [KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0](https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0) | **CC0** | |
| KayKit Medieval Hexagon | [KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0](https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0) | **CC0** | |
| KayKit Character Animations | sem repo no GitHub (itch/OpenGameArt) | CC0 | itch bloqueado aqui |
| Kenney Starter Kits (Godot) | [KenneyNL/Starter-Kit-3D-Platformer](https://github.com/KenneyNL/Starter-Kit-3D-Platformer), [-City-Builder](https://github.com/KenneyNL/Starter-Kit-City-Builder), [-FPS](https://github.com/KenneyNL/Starter-Kit-FPS), [-Racing](https://github.com/KenneyNL/Starter-Kit-Racing), [-Basic-Scene](https://github.com/KenneyNL/Starter-Kit-Basic-Scene) | código **MIT**; os modelos Kenney são CC0 [fonte](https://github.com/madjin/awesome-cc0) | não há espelho oficial da biblioteca completa do Kenney no GitHub |
| Quaternius (inclui Universal Animation Library 1 e 2) | **sem repo oficial no GitHub** | CC0 ([quaternius.com](https://quaternius.com/packs/universalanimationlibrary.html), [OpenGameArt](https://opengameart.org/content/universal-animation-library)) | quaternius.com e itch bloqueados aqui; espelhos de terceiros não verificados |
| Khronos glTF Sample Assets | [KhronosGroup/glTF-Sample-Assets](https://github.com/KhronosGroup/glTF-Sample-Assets) | **por modelo** (CC0, CC BY 4.0 etc.; veja o README de cada pasta) | ótimo para **testar o importador** (skin, morph, materiais), não para o jogo |
| Godot demo projects | [godotengine/godot-demo-projects](https://github.com/godotengine/godot-demo-projects) | MIT (código) | referência de código |
| Godot TPS demo | [godotengine/tps-demo](https://github.com/godotengine/tps-demo) | assets **CC BY 3.0** (atribuição) | referência de qualidade e pipeline |
| 100 Avatars | [PolygonalMind/100Avatars](https://github.com/PolygonalMind/100Avatars) | sem LICENSE na raiz; diz CC0 por release [não verificado] | VRM/estilo próprio |
| **CMU Mocap em BVH** (conversão cgspeed/Bruce Hahne, 2.554 arquivos) | [una-dinosauria/cmu-mocap](https://github.com/una-dinosauria/cmu-mocap), [meshula/cmu-mocap](https://github.com/meshula/cmu-mocap) | READMEFIRST: "free for use in research and **commercial** projects"; "CMU places no restrictions… I (Bruce) place no additional restrictions" | com índice (`cmu-mocap-index-text.txt`: walk, run, punch, swordplay…); importa em 0,43 s [teste]. Atenção: conversões FBX de terceiros aparecem como CC BY-NC ([fonte](https://paperswithcode.com/dataset/cmu-motion-capture)) |
| 100STYLE (100 estilos de locomoção, BVH a 60 fps) | Zenodo / [ianxmason.github.io/100style](https://ianxmason.github.io/100style) (não está no GitHub) | **CC BY 4.0**, pede crédito | download fora do GitHub, pode não ser alcançável daqui |
| **LaFAN1 (Ubisoft)** | [ubisoft/ubisoft-laforge-animation-dataset](https://github.com/ubisoft/ubisoft-laforge-animation-dataset) | **CC BY-NC-ND 4.0** | **PROIBIDO** (não comercial e sem derivados) |
| **Bandai Namco Motion Dataset** | [BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset](https://github.com/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset) | dados **CC BY-NC 4.0** (scripts MIT) | **PROIBIDO** em produto comercial |

**Avaliação franca: ajuda ou vira asset flip?**

- **Vira asset flip se aparecer na tela.** KayKit, Kenney e Quaternius estão em milhares de jogos de game jam; o público de Steam/itch reconhece na hora. É o oposto do "sem cara de IA slop" que o usuário pediu. Além disso, o estilo deles (low-poly chapado, cabeça grande) **não bate** com nada que geremos, e a mistura de estilos é o sinal número 1 de slop (ver `direcao-de-arte.md`).
- **Onde ajudam de verdade**:
  - (1) **Placeholder** de protótipo de gameplay, trocado antes de qualquer captura pública.
  - (2) **Referência métrica**: contagem de triângulos, proporções, tamanho de textura e lista de animações de um pack profissional (as 75 animações do KayKit Adventurers são uma ótima checklist).
  - (3) **Teste do importador** com Khronos Sample Assets.
  - (4) **Mocap como matéria-prima de timing**: CMU e 100STYLE retargetados para o rig próprio, **exagerados por script** (amplificar curvas, pose segurada, acentos de squash). Mocap cru em personagem estilizado parece "flutuante"; o ganho é ter uma base de peso e ritmo para estilizar.

---

## 10. (h) Tutoriais e referências

**Pipeline Blender → Godot**

- Godot docs, importação 3D (formatos, opções, sufixos, import script): [available_formats.rst](https://github.com/godotengine/godot-docs/blob/4.5/tutorials/assets_pipeline/importing_3d_scenes/available_formats.rst), [import_configuration.rst](https://github.com/godotengine/godot-docs/blob/4.5/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.rst), [node_type_customization.rst](https://github.com/godotengine/godot-docs/blob/4.5/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.rst) (legíveis daqui via raw.githubusercontent.com).
- Manual do exportador glTF do Blender (fonte RST): [glTF-Blender-IO/docs/blender_docs/scene_gltf2.rst](https://github.com/KhronosGroup/glTF-Blender-IO/blob/main/docs/blender_docs/scene_gltf2.rst) (Deformation Bones Only, Flatten Bone Hierarchy, sampling, NLA).
- Rigify para Godot: [Rigodotify](https://github.com/catprisbrey/Rigodotify); discussão sobre exportar só DEF e "keep custom tracks": [Godot Q&A](https://godotengine.org/qa/84416/import-rigify-rigged-character-godot-with-working-animations), [fórum](https://forum.godotengine.org/t/question-about-blender-to-godot-export/94036). Dica do RigPort (pago, só a doc foi lida): casar o FPS e desligar o otimizador ([superhivemarket.com/products/rigport/docs](https://superhivemarket.com/products/rigport/docs)), o que bate com o teste da seção 2.
- Bug de escala não uniforme em osso no Godot 4: [godot#91893](https://github.com/godotengine/godot/issues/91893); Remove Immutable Tracks contra escala de osso: [godot#72998](https://github.com/godotengine/godot/issues/72998) [via resumo].
- IK de volta no Godot 4.6: [godotengine.org](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/).

**Personagem estilizado e toon**

- Guilty Gear Xrd (GDC 2015, Junya Motomura): animação limitada, normais editadas à mão, luz por personagem. [GDC Vault](https://gdcvault.com/play/1022031/GuiltyGearXrd-s-Art-Style-The), [handout PDF](https://www.ggxrd.com/Motomura_Junya_GuiltyGearXrd.pdf). A técnica de "normais editadas" é reproduzível por script (Data Transfer de normais de uma esfera ou cápsula para o rosto, `Normal Edit`).
- Dead Cells, 3D → 2D: [Thomas Vasseur (republicação)](https://www.jikguard.com/news/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-dead-cells), [80.lv](https://80.lv/articles/case-study-dead-cells-character-art-pipeline).
- HD-2D: [Unreal, Octopath II](https://www.unrealengine.com/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style), [Siliconera, desenvolvimento do HD-2D](https://www.siliconera.com/project-octopath-traveler-developers-answer-project-started-troubles-developing-hd-2d/).
- Blender Studio (grátis): [Low Poly Character Creation](https://studio.blender.org/training/low-poly-character-creation/chapter/59776a708119172b0f1bf1c3), [Stylized Character Workflow](https://studio.blender.org/training/stylized-character-workflow/5d3a1a214bc3ff1bb9513d30).
- Canais conhecidos (YouTube, bloqueado aqui, não conferidos nesta sessão): CGDive (Rigify e game rigs), Grant Abbitt (low poly para jogos), Pierrick Picaut (animação de jogo no Blender), Joey Carlino (Geometry Nodes), Lightning Boy Studio (toon/NPR).

**Animação de jogo e os 12 princípios**

- Jonathan Cooper, *Game Anim: Video Game Animation Explained*, capítulo sobre os 12 princípios em jogos: [Game Developer](https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games). Lembra que muitos motores não suportam escala de osso por custo de memória; o Godot suporta, como testado.
- Antecipação em ataques inimigos: [Game Developer, "Adding weight… anticipation"](https://gamedeveloper.com/design/adding-weight-to-your-game-design-part-2-anticipation).
- Ver também `animacao-principios.md` nesta pasta.

---

## 11. Pipeline proposto (tudo por script, verificável)

```
gen_character.py   (bmesh/Skin + curvas de cabelo + Solidify roupas; params: altura, cabeça, paleta)
  → gen_rig.py     (armature próprio ~25 ossos com nomes SkeletonProfileHumanoid; pesos por vertex group gerado)
  → anim_lib.py    (actions por código: idle, run, dodge, 3 ataques, hit, death, cast;
                    curvas com antecipação/overshoot; squash em osso-folha; mola própria p/ cabelo
                    OU deixar cabelo para SpringBoneSimulator3D no Godot)
  → bake_tex.py    (vertex color chapado OU albedo+normal+AO 512–1024 px; ~5 s/personagem)
  → export_glb.py  (ACTIONS, force_sampling, def_bones, fps = fps do projeto;
                    flatten_bones só se houver ossos não-FULL)
  → godot --headless --import
  → verify_import.gd (lista animações, compara matrizes de osso Blender×Godot com tolerância 1e-3,
                      checa trilhas de escala e NEAREST; falha o build se divergir)
  → (opcional HD-2D) render_sprites.py (Cycles emissão + casca invertida, 8 direções, EXR Normal/Depth)
```

Configuração de projeto Godot: padronize `animation/fps` igual ao `scene.render.fps` do Blender (sugiro **30 nos dois**: casa com o padrão do Godot e evita editar cada `.import`) e escreva um `EditorScenePostImport` que aplique o material toon e marque os loops.

---

## 12. Pendências e pontos não verificados

- O MPFB2 e os demais addons de terceiros **não foram executados** (a política de permissões bloqueou rodar código baixado). Rodar o MPFB2 headless (`HumanService.create_human()` com `sys.path` apontando para `src/`) depende de autorização do usuário.
- Line Art com espessura útil em 256 px: não ajustado.
- `parent_set(type='ARMATURE_AUTO')` (heat weights) em background: não testado aqui.
- Bake de ossos de mola de Wiggle 2 / Jiggle Physics sem tela: não testado.
- Convenção do eixo Y do normal map 2D no Godot (`CanvasTexture`): não verificada.
- Licença do 100STYLE no Zenodo (a página do autor diz CC BY 4.0) e alcance do download a partir deste container: não verificados.
- Quaternius e Kenney: não há espelho oficial no GitHub; espelhos de terceiros não foram auditados.
- docs.blender.org não é alcançável daqui. A doc do exportador foi lida pela fonte RST no GitHub.

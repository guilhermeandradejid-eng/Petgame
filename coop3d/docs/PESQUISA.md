# Pesquisa de tutoriais e como cada técnica foi aplicada

Antes de construir o jogo, fiz um levantamento de tutoriais, documentação oficial e referências de game feel. A tabela de cada seção diz **o que foi aprendido** e **onde está no código**. Os números marcados como "ajuste" são valores de partida escolhidos e depois conferidos pelo playtest automatizado.

> Observação: alguns sites (docs.godotengine.org, godotshaders.com, gdquest.com, forum.godotengine.org) estavam bloqueados no ambiente de desenvolvimento. A documentação oficial foi lida pelo código-fonte da própria documentação no GitHub, que tem o mesmo conteúdo.

## 1. Controle do personagem (sensação de Mario/Rayman)

| Técnica | Aplicação |
|---|---|
| Física de pulo a partir de altura e tempo: `v = 2h/t`, `g = 2h/t²`, com gravidade maior na queda | `Player._set_jump()`. Lumi: 2,0 m em 0,36 s; Bolota: 2,25 m em 0,38 s |
| Coyote time (0,11 s) e jump buffer (0,13 s) | `_move_normal()` |
| Pulo variável (soltar cedo = gravidade ×2,4) e "apex hang" (gravidade ×0,55 no topo) | `_move_normal()` |
| Movimento relativo à câmera, projetado no plano tangente (funciona em planetas) | `_wish()` |
| `get_gravity()` + `up_direction` dinâmico para gravidade de Area3D | `_update_up()`, `world/planet.gd` |
| Derrapagem ao virar (aceleração ×2,2 + poeira), dash, pulo longo, ground pound com pausa de antecipação | `_move_normal()`, `_move_dash()`, estados `pound_wind`/`pound_fall` |
| Step-up de bordas pequenas com `test_move` | `_try_step()` |

## 2. Coop local na mesma tela

| Técnica | Aplicação |
|---|---|
| Ações por jogador criadas em tempo de execução no `InputMap`, com `device` por controle e teclas físicas | `Game.bind_player()` |
| Reatribuição quando um controle é conectado ou desconectado (`joy_connection_changed`) | `Game._on_joy_changed()` |
| Câmera compartilhada que enquadra todos: distância calculada pelo FOV, zoom-out rápido e zoom-in lento | `CoopCamera._process()` |
| "Up" médio dos jogadores + transporte paralelo do vetor frente (a câmera não vira de cabeça para baixo nos planetas) | `CoopCamera` |
| Bolha de resgate: quem cai flutua até a última posição segura do parceiro | `Player.enter_bubble()`, `LevelBase.respawn_point_for()` |
| Regras de design coop: papéis assimétricos, nada de soft-lock (placas reiniciam, timers repetem), estado legível (luzes por canal) e esperar o parceiro no objetivo | placas, portões com luzes por canal, `StarBloom` |

## 3. Game juice ("Juice it or lose it")

| Técnica | Aplicação |
|---|---|
| Hitstop no autoload, guardando só o fim mais tardio, para nunca travar o `time_scale` | `Juice.hitstop()` |
| Trauma shake: `shake = trauma²`, ruído contínuo e decaimento linear | `CoopCamera._update_transform()` |
| Camera punch em mola e FOV kick | `CoopCamera.punch()`, `fov_kick()` |
| Squash & stretch preservando volume: `(1/√s, s, 1/√s)` | `CharacterRig.animate()` |
| Partículas para cada evento (poeira, estrelas, confete), anéis de choque, speed lines, flash | `autoload/vfx.gd` |
| Som em todo evento, com variação de pitch e escala pentatônica crescente em coletas seguidas | `Sfx.play()`, `Sfx.pickup()` |
| Contador rolando, pops elásticos na UI, texto flutuante, slow motion nos grandes momentos | `Hud`, `UiTheme.pop()`, `Vfx.text_pop()`, `Juice.slowmo()` |

## 4. Os 12 princípios da Disney aplicados em código

| Princípio | Onde |
|---|---|
| Squash & stretch | mola de escala com impulsos no pulo e na aterrissagem, e estica com a velocidade vertical |
| Antecipação | agachar antes do pulo e do ground pound; o pound faz uma pirueta e segura a pose |
| Encenação (staging) | a câmera desliza até o portão quando ele abre (`focus_on`) |
| Follow-through e overlapping action | orelhas, antenas, cauda (2 segmentos), capa, cachecol, broto e cabeça são molas amortecidas guiadas pela aceleração |
| Slow in / slow out | molas, `1 - exp(-k·dt)` e plataformas com easing senoidal |
| Arcos | pés sobem em arco no ciclo de corrida, coletáveis voam em arco, anéis seguem Bézier |
| Ação secundária | piscar, respirar, abanar a cauda, olhar em volta, lanterna girando ao planar |
| Timing | pausa no ar do pound (0,22 s) e hitstop variando com o peso |
| Exagero | squash de até 45 % em aterrissagens fortes |
| Desenho sólido | modelos com volume (subdivisão, formas de pera, de gota e de bolota) |
| Apelo | olhos grandes com dois brilhos, bochechas, silhuetas distintas |
| Pose a pose | poses por estado (planar, carregar, comemorar, bolha) misturadas com o ciclo |

## 5. Shaders e VFX (Godot 4)

| Técnica | Aplicação |
|---|---|
| `light()` próprio: rampa de 2 tons com sombra colorida, rim light e highlight toon; `LIGHT_IS_DIRECTIONAL` separa a sombra da atenuação | `shaders/toon_common.gdshaderinc` |
| Normal map triplanar com blend "whiteout" (detalhe CC0 sem precisar de UV) | `triplanar_normal()` |
| Contorno por inverted hull (`cull_front` em `next_pass`) com largura proporcional à distância | `shaders/outline.gdshader` |
| Terreno triplanar: grama no topo e estratos de rocha nas laterais; "up" radial nos planetas | `shaders/terrain.gdshader` |
| Céu procedural (gradiente, sol em faixas, nuvens fbm, estrelas) | `shaders/sky.gdshader` |
| Mar de nuvens com deslocamento "billow" no vértice | `shaders/cloud_sea.gdshader` |
| Grama em MultiMesh com vento e curvatura em volta dos jogadores (global uniforms) | `shaders/grass.gdshader` |
| Dissolve com borda emissiva (portões, pontes), holograma para blocos inativos | `toon.gdshader`, `ghost.gdshader` |
| Fenda: billboard em coordenadas polares com redemoinho e borda cromática | `shaders/portal.gdshader` |
| Onda de choque aditiva com easing, feixe do Elo de Luz, bolha iridescente, transição em íris de estrela, speed lines | `shockwave`, `beam`, `bubble`, `transition`, `speedlines` |
| `source_color` em todos os uniforms de cor (sRGB correto no Forward+) | todos os shaders |

## 6. Blender por script (bpy)

- Formas paramétricas ("blobs"): uma esfera UV deformada por funções Python, depois um modificador Subdivision aplicado na exportação.
- Hierarquia de **empties-pivô** nas articulações. O Godot anima esses pivôs proceduralmente, o que é mais leve e mais "juicy" do que animação baked.
- Exportação glTF binário com `export_apply=True` e `export_yup=True`; os nomes dos materiais definem o shader no Godot.
- Previews em Cycles (`preview.py`) para revisar a qualidade sem abrir a interface.

## 7. Texturas abertas

Poly Haven e ambientCG são CC0, mas estavam inacessíveis no ambiente. Por isso foram usados os normal maps CC0 do pacote `@pmndrs/assets`, aplicados como detalhe triplanar. A cor vem de ruído procedural no shader, que combina melhor com o visual cel do que texturas fotorrealistas, recomendação comum dos tutoriais de estilo toon. Os sons vêm do pacote CC0 da Kenney.

## Fontes consultadas

- Documentação oficial do Godot (lida no GitHub): `spatial_shader.rst`, `shading_language.rst`, `controllers_gamepads_joysticks.rst`, e as classes `CharacterBody3D`, `PhysicsBody3D`, `Area3D`, `InputMap` e `InputEvent`.
- Fórmulas de pulo por altura e tempo: https://gist.github.com/sjvnnings/5f02d2f2fc417f3804e967daa73cccfd
- Trauma shake no Godot 4: https://gist.github.com/GammaGames/465acceccef14cbd478591b63a9fb1c3
- Movimento relativo à câmera: https://gist.github.com/bramreth/2a62faf5605ab602447eb5cc17374693
- Catálogo de game juice e armadilhas (time_scale preso em hitstops sobrepostos): https://github.com/Kelpekk/Juicee
- Palestra "Juice it or lose it", Jonasson & Purho, GDC Europe 2012
- Split-screen e coop local no Godot: https://uhiyama-lab.com/en/notes/godot/split-screen-multiplayer/ e https://gdquest.com/library/split_screen_coop
- Shaders toon, contorno e vento: godotshaders.com ("toon shader for Godot 4", "simplest outline via material", "simple wind sway")
- Cores de vértice e opções do exportador glTF no Blender 4.x/5.x: projects.blender.org/blender/blender/issues/123925
- Licenças: FAQ do Poly Haven (CC0); Kenney Starter Kit 3D Platformer (CC0 / MIT)
- Os 12 princípios da animação: Thomas & Johnston, *The Illusion of Life* (1981)

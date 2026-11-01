# Aurelia — plano do milestone 1

Plano produzido (Opus) antes da implementação. Resumo das decisões:

- **Engine**: Godot 4.4 (GDScript), renderer `gl_compatibility` (roda em hardware fraco, web-exportável, e é verificável em CI com Mesa/llvmpipe). Simulação a 60 ticks/s, toda a lógica de gameplay conta *ticks inteiros*.
- **Arte 2D**: sprites gerados por Python (Pillow + numpy), no estilo do pipeline do GRAYFALL: pose = dict de ângulos, IK, raster 4x, cel-shading por offset de máscara (5 tons), downsample por voto majoritário, costuras internas, contorno de 1px, rosto pintado depois do downsample, molas (cachecol/rabo de cavalo), normal maps procedurais, âncoras por frame e **contrato congelado** (nomes de animação, frames lógicos, ticks por frame) em `art/contracts/*.contract.json`.
- **Tamanho**: herói ~46 px de altura em célula 64x64 (chibi ~2.6 cabeças — escala parecida com Legend of Mana), 2 facings desenhados→ nesta fase 1 facing (3/4 direita) espelhado em engine.
- **Cenário**: palco 3D procedural (primitivas + ArrayMesh), billboards com normal map iluminados por luz 3D; caminho Blender → `.glb` documentado para depois.
- **Combate**: máquina de estados por ticks, dados em `Resource` (`AttackData`, `WeaponData`, `SpellData`, `EnemyData`), buffer de input de 8 ticks, janelas de cancel, hitstop por entidade (nunca `Engine.time_scale`), hitboxes via `intersect_shape`.
- **Multiplayer**: ENet, listen-server, até 4 jogadores. Cliente é autoritativo sobre o próprio movimento e detecta os próprios acertos (responsividade); host valida e é dono de inimigos/HP. Input abstraído em `InputFrame`/`InputSource` para co-op local depois.
- **Juice** (autoload `Juice`): hitstop, shake por trauma, kick de câmera, squash/stretch, flash, trail 3D de arma, faíscas, números de dano, poeira, afterimage de dash, dissolve na morte, magia 3D com shader "casca oca" (Ice Lance), SFX procedural.
- **QA**: `tools/qa.py <char>` falha a build se a arte quebra o contrato ou os limiares.

## Ordem de execução
1. bootstrap  2. contratos+pipeline de sprites  3. render/anim runtime  4. input+locomoção  5. combate  6. inimigo  7. multiplayer  8. rodadas de arte  9. fase  10. juice/VFX/SFX  11. HUD + README.

Corte se faltar tempo: facing de costas → jump → grama/riacho → pós-FX → afterimage. Nunca cortar: contrato, QA, combo, sync, Ice Lance, hitstop, shake, trail.

# Pipeline de arte do Lumen (Blender -> Godot)

Toda a arte 3D do jogo é modelada por scripts Python que rodam no Blender (módulo `bpy`,
Blender 5.3) e exportam `.glb` para `lumen/assets/models/`. Nada é pintado à mão em textura:
a cor vem de **materiais nomeados** (trocados por paleta no jogo) e de **cor por vértice**
(tinta, gradiente e oclusão). O Godot aplica um shader toon de duas faixas com luz ambiente
fria (sombra arroxeada) e sol quente.

## Arquivos

| arquivo | o que é |
|---|---|
| `lp.py` | kit de modelagem: classe `Geo` + primitivas (`stack`, `lathe`, `loft`, `tube`, `ellipsoid`, `box`, `cyl`, `cone`, `icosphere`, `poly_extrude`, `sheet`), cor (`hexc`, `grad`, `autograd`, `tint`, `bake_ao`), pesos (`bind`, `bind_axis`, `bind_fn`), deformações (`warp`, `bend`, `noise_warp`), e a ponte com o Blender (`to_object`, `make_armature`, `skin_to`, `export_glb`) |
| `anim.py` | animação pose a pose em código (`Clip`, `Rig`), assada quadro a quadro a 30 qps |
| `hero_body.py` | esqueleto do herói (`BONES`), medidas e peças-base (cabeça, rosto, mãos, tronco, braço, perna, pé) |
| `hero_anim.py` | os clipes do herói |
| `wd_base.py` | registro `@piece` e ajudantes do guarda-roupa (cabelo, cinto, saiote, armas na mão) |
| `wd_*.py` | as peças trocáveis, um módulo por grupo de slots |
| `build_hero.py` | monta tudo em `assets/models/hero.glb` + `hero_manifest.json` |

## Convenções

- Metros. **Z para cima, personagem olhando para -Y, lado esquerdo em +X** (sufixo `.L`).
- O herói tem ~1,27 m: cabeça com centro em z=1,005 e raios (0,265 / 0,245 / 0,25), ombros em
  z=0,69, quadril em z=0,405, pose de repouso em T (braços ao longo de X, palma para baixo).
- Faces com normal para fora (sentido anti-horário visto de fora). Confira em render: face
  invertida aparece como buraco.
- Sombreamento suave por padrão; arestas com mais de 42° ficam vivas sozinhas. Use `.flat()`
  só para pedra/cristal facetado.

### Materiais

Peças do herói usam materiais de paleta, que o jogador pode tingir:

`skin` pele · `hair` cabelo (também sobrancelha) · `primary` cor principal da roupa ·
`secondary` cor secundária · `accent` detalhe · `metal` · `leather` · `eye` contorno do olho ·
`iris` · `white` · `dark` · `mouth` · `glow` (emissivo)

Qualquer cor fixa (ouro, gema, madeira...) usa o material `vcol` com a cor no vértice:
`box(...).color(lp.hexc('#e9b949'))`. Em materiais de paleta a cor de vértice é só um
**multiplicador** (use para gradiente/sombra: `geo.grad('z', z0, z1, (0.72, 0.68, 0.80), lp.WHITE)`).
Sombra sempre puxada para o frio/roxo, luz para o quente; nunca multiplique por cinza puro.

Cenários e inimigos usam só `vcol` (cor inteira no vértice), `vcol_wind` (folhagem que balança),
`glow` (emissivo; a cor do vértice é a cor da luz) e `water`.

### Estilo

- Low-poly **estilizado e fofo**, formas cheias e legíveis de longe. Silhueta primeiro.
- Poucos polígonos, mas arredondado onde importa: anéis de 6 a 12 lados. Uma peça de roupa
  fica entre 150 e 900 triângulos; um inimigo comum entre 600 e 2500; cenário grande até 1500.
- Proporções exageradas: detalhes grandes e poucos (uma fivela grande, não dez rebites).
- Paleta viva e limpa: 3 a 5 cores por objeto, saturação alta só em áreas pequenas, grandes
  áreas mais calmas. Sempre um gradiente sutil (base mais escura e fria, topo mais claro).
- Nada de ruído gratuito, simetria perfeita demais em coisas orgânicas, ou formas genéricas de
  "primitiva pura": toda esfera/cubo precisa de um afunilamento, chanfro ou curva.

## Guarda-roupa

```python
@piece('hat', 'hat_mago', 'Chapéu de Mago', rarity=1, cost=120, hair='flat')
def hat_mago():
    g = ...            # Geo com materiais
    return g.bind('head')
```

- Slots e prefixo obrigatório do nome: `hair_` cabelo · `hat_` chapéu · `ears_` orelhas/chifres ·
  `acc_` acessório de rosto · `top_` tronco+braços · `bottom_` pernas+pés · `back_` costas ·
  armas `sword_` `bow_` `staff_` `hammer_` (slot `weapon`, meta `wt='sword'|'bow'|'staff'|'hammer'`).
- As roupas **substituem** o corpo: `top_*` precisa trazer tronco e os dois braços (pele onde
  for pele); `bottom_*` traz as duas pernas e os pés. Cabeça e mãos são fixas (`base_head`,
  `base_hands`). Use `hb.make_torso`, `hb.make_arm`, `hb.make_leg`, `hb.make_foot` como base e
  modele uma metade (`.L`) + `.both()` quando for simétrico.
- Todo vértice precisa de peso. Ossos: `hips spine chest head`, `upper_arm.L forearm.L hand.L
  weapon.L` (+`.R`), `thigh.L shin.L foot.L` (+`.R`), e cadeias com física de mola no jogo:
  `hair1 hair2` (rabo de cavalo), `hat1` (ponta de chapéu, orelha comprida), `cape1 cape2 cape3`
  (capas), `tail1 tail2` (rabos).
- Cabelo devolve `(base, topo)`: `base` é a casca + franja + laterais; `topo` é o volume que
  atravessaria um chapéu. Chapéus declaram `hair='keep'` (não mexe), `'flat'` (esconde o topo)
  ou `'hide'` (esconde o cabelo todo: capacete, capuz). Chapéu precisa de raio interno >= casca
  do cabelo (cabeça x 1,10).
- Armas: modele na origem com o cabo ao longo de Z (mão segura em z=0, ponta/lâmina para +Z) e
  use `to_hand(g, 'R')`. Arco: mão esquerda, braços do arco ao longo de ±Z, barriga do arco
  para +X, corda do lado -X, `to_hand(g, 'L')`. Escudo: preso em `forearm.L`.

## Comandos

```sh
# herói completo (todas as peças + animações) -> assets/models/hero.glb
python3 tools/blender/build_hero.py

# build parcial para preview (não toca no hero.glb do jogo)
python3 tools/blender/build_hero.py --noanim --mods wd_hats --out /tmp/x/hats.glb

# folha de contato (Godot, shader do jogo). Veja o cabeçalho de tools/preview.gd
tools/shot.sh glb=/tmp/x/hats.glb out=/tmp/x/hats.png "sets=hat_a;hat_b;hat_c" yaws=30 size=1600x560
tools/shot.sh glb=assets/models/env_forest.glb out=/tmp/x/f.png layout=row "filter=tree*" pitch=18
tools/strips.sh /tmp/x/anim.png 35 "sword_atk1:0,0.1,0.2,0.3"
```

## Kits de cenário, props e inimigos

- `kit.py`: registro `Kit` + `@kit.prop(nome, collider=..., tags=[...])` para objetos estáticos.
  Cada kit vira um `.glb` com uma malha por objeto (todas na origem, base em z=0) e um
  `<kit>_manifest.json` com colisor, etiquetas e tamanho.
- Inimigos: um `.glb` por inimigo (`enemy_<id>.glb`) com armature, malhas e clipes, mais
  `enemies_manifest.json` com raio, altura e os tempos de acerto de cada ataque.

# Céu Arcano: contrato de assets

Este arquivo define o que cada etapa do pipeline entrega para o projeto Godot (`../game`).
Tudo é gerado por código e reproduzível (`python3 build_all.py`).

## Convenções gerais

- Unidade do mundo = 1 pixel de arte. Coordenadas no estilo Godot: x para a direita, **y para baixo**.
- O chão da arena fica em `y = 0`. Altura negativa = no ar.
- Lutadores andam em `x ∈ [-470, 470]`.
- Resolução base do jogo: 640×360 (janela 1280×720 ou maior, escala livre com filtro "pixel AA").
- Câmera: zoom entre 0.72 (lutadores longe) e 1.15 (perto). Centro de referência `C0 = (0, -110)`.
  O centro y da câmera sobe até -380 quando alguém voa alto.
- Todo PNG é RGBA 8 bits, alfa binário (0 ou 255), exceto texturas marcadas como "glow".

## Paleta do céu (feita em shader no Godot, para harmonizar)

| faixa | cor |
|---|---|
| topo | `#0b0a24` |
| alto | `#1d1748` |
| meio | `#4a2a6e` |
| baixo | `#a2477a` |
| horizonte | `#f08a6a` |
| brilho do horizonte | `#ffc98a` |

## Cenário (Blender → `game/assets/stage/`)

Saída: `far.png`, `mid.png`, `near.png`, `ground.png`, `fg.png`, `moon.png`, `stage.json`, `preview.png`.

`stage.json`:

```json
{
  "ref_camera": [0, -110],
  "floor_y": 0,
  "layers": [
    {"name": "far", "file": "far.png", "parallax": 0.12, "origin": [-480, -400], "z": -40},
    {"name": "fg",  "file": "fg.png",  "parallax": 1.25, "origin": [-1000, 60], "z": 20, "front": true}
  ],
  "moon": {"file": "moon.png", "parallax": 0.03, "origin": [120, -380]},
  "lights":     [{"layer": "near", "x": 100, "y": 50, "r": 18, "color": "#ffc46a", "kind": "lantern"}],
  "waterfalls": [{"layer": "mid", "x": 300, "y": 120, "w": 8, "h": 90}]
}
```

- `origin` = posição no mundo do canto superior esquerdo da imagem quando a câmera está em `C0` com zoom 1.
- Camadas com `"front": true` são desenhadas na frente dos lutadores.
- `lights` e `waterfalls` usam coordenadas em pixels da imagem da camada indicada.
- Tamanhos-alvo: far ~960×540 (parallax 0.12), mid ~1100×560 (0.35), near ~1400×600 (0.65),
  ground cobrindo x ∈ [-800, 800] e y ∈ [-260, 200] (parallax 1.0, chão de pedra em perspectiva:
  os lutadores pisam a linha `y = 0`), fg cobrindo x ∈ [-1000, 1000] perto da borda de baixo
  (parallax 1.25, só elementos esparsos e baixos que não escondem os lutadores).

## VFX 3D (Blender → `game/assets/vfx/`)

Faixas horizontais de quadros do mesmo tamanho, com `<nome>.json` = `{"frame_w":…, "frame_h":…, "frames":…}`.

- `star_spin.png`: estrela dourada de 5 pontas, chanfrada, girando em 3D. 16 quadros de 24×24.
- `lantern_spin.png`: lanterna de papel e metal dourado girando, interior brilhando. 16 quadros de 24×32.
- `rock_chunks.png`: 8 pedaços de pedra diferentes × 8 rotações (grade 8×8 de 12×12) para detritos.

## Áudio (Python/numpy → `game/assets/audio/`)

- `sfx/<nome>.wav`: PCM 16 bits, 44.1 kHz, pico em -1 dBFS.
- `music/<nome>.ogg`: Vorbis, 44.1 kHz estéreo, loop sem emenda.

## Personagens (Python pixel rig → `game/assets/characters/<id>/`)

- `<id>_a.png`, `<id>_b.png`: atlas com a paleta principal e a alternativa (espelho).
- `<id>.json`: animações com retângulos no atlas, origem (pé), duração de cada quadro em frames de jogo (60 fps),
  hurtboxes, hitboxes, pontos de âncora e eventos.
- `portrait_a.png`, `portrait_b.png`: pose de declaração de carta, usada nos cut-ins.

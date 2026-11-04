# Personagens Mii: opções de personalização

Tudo é definido por um dicionário (`cfg`) em `mii.py` (`MALE` e `FEMALE` são os padrões).
Qualquer campo pode ser trocado por `--set campo=valor` em `build_mii.py`, por um JSON (`--config`)
ou direto em Python: `merge(MALE, {"skin": "ebano", "hair": {"style": "afro"}})`.

| Campo | Valores |
|---|---|
| `gender` | `male`, `female` (escolhe a base do corpo: ombros, quadril, proporções) |
| `height` | escala geral (padrão 1.0 masculino, 0.945 feminino) |
| `weight` | 0.85 – 1.25 (espessura de tronco e membros) |
| `shoulders` | 0.9 – 1.15 |
| `head_scale` | 0.9 – 1.15 |
| `skin` | `porcelana` `pessego` `dourada` `morena` `marrom` `escura` `ebano` ou `#rrggbb` |
| `face.shape` | `round` `oval` `square` |
| `face.eyes` | `round` (olho grande com íris) · `dot` (ponto estilo Mii clássico) · `wide` · `sleepy` |
| `face.eye_color` | `preto` `castanho` `azul` `verde` `mel` `cinza` ou `#rrggbb` |
| `face.eye_size`, `face.eye_gap` | 0.8 – 1.25 |
| `face.brows` | `soft` `thick` `thin` `none` |
| `face.nose` | `button` `long` `small` `none` |
| `face.mouth` | `smile` `grin` `smirk` `neutral` `determined` `open` |
| `face.cheeks`, `face.freckles`, `face.lashes` | `true` / `false` |
| `hair.style` | `short` `buzz` `spiky` `mohawk` `afro` `ponytail` `pigtails` `bun` `bob` `long` `none` |
| `hair.color` | `castanho` `preto` `loiro` `ruivo` `grisalho` `azul` `rosa` `roxo` `verde` `branco` ou `#rrggbb` |
| `accessories.visor` | cor `#rrggbb` ou `null` |
| `accessories.cap` | cor `#rrggbb` ou `null` (boné com aba) |
| `accessories.headband` | cor ou `null` |
| `accessories.sunglasses` | `null` ou `{"mount": "eyes"\|"top", "style": "sport"\|"round"\|"square"\|"aviator", "color": "mirror"\|"azul"\|"preta"\|"verde"\|"rosa"}` |
| `accessories.glasses` | `null` ou `{"style": "round"\|"square"\|"sport", "color": "#rrggbb"}` |
| `accessories.wristband` / `wristband_side` | cor ou `null` / `"R"` ou `"L"` |
| `outfit.top.style` | `tank` |
| `outfit.top.color_a` / `color_b` | cor de cima e de baixo do degradê da camisa |
| `outfit.top.number` | texto (ex. `"10"`) ou `null` |
| `outfit.top.emblem` | `wave` `star` `ball` ou `null` |
| `outfit.bottom.style` | `shorts` `long_shorts` `skirt` |
| `outfit.bottom.color`, `stripe_a`, `stripe_b` | cores do short/saia e das listras laterais |

Poses prontas (`--pose`): `stand` (A-pose), `ready`, `forehand`, `smash`, `cheer`. Com `--racket`
a raquete de beach tênis (placa furada, degradê) e a bola vêm junto.

Como o cabelo, o rosto, a roupa e os acessórios são geometria gerada por parâmetros, qualquer
combinação funciona sem retrabalho manual no Blender.

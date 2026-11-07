# Mochi Pet

Um cozy pet game mobile no estilo Pou, com bichinhos de gelatina brilhante. Roda direto no navegador, sem build e sem dependências.

## Como jogar

- **Cozinha**: arraste a comida até a boquinha (ou toque nela para dar). Cada comida custa moedas.
- **Banho**: esfregue o sabonete no bichinho e depois segure o chuveiro para enxaguar a espuma.
- **Quarto**: apague a luz para ele dormir e recarregar a energia.
- **Brincar**: arremesse a bolinha nele ou jogue a **Chuva de Doces** para ganhar moedas.
- **Closet**: troque de bichinho (Mochi, Coelho, Gato), compre cores e acessórios.

Toque no bichinho para cutucar, arraste o dedo em cima dele para fazer carinho. Se cutucar demais ele fica tonto.
As necessidades (fome, energia, diversão, higiene) caem com o tempo, e o progresso fica salvo no navegador.

## Rodando

Sirva a pasta com qualquer servidor estático (o renderizador 3D usa módulos ES, que não carregam via `file://`; nesse caso o jogo cai para a versão 2D):

```sh
npx http-server .
```

No celular, acesse o endereço da sua máquina na rede local (ou publique no GitHub Pages) e use "Adicionar à tela de início" para jogar em tela cheia.

## Estrutura

- `index.html`: estrutura da interface
- `style.css`: visual da interface
- `game.js`: lógica do jogo, física de molas para squash & stretch, cômodos, minigame, sons sintetizados com Web Audio e renderização 2D (cenário, partículas, ícones e fallback do bichinho)
- `pet3d.js`: bichinho em 3D com Three.js. Corpos gerados por revolução do contorno de cada espécie e um `ShaderMaterial` "jelly" próprio:
  - vertex shader: balanço de gelatina (o topo atrasa em relação à base) e ondulação que se espalha a partir do toque
  - fragment shader: gradiente de altura, subsurface/translucidez falsos, fresnel, reflexos de estúdio e o rosto projetado na superfície (desenhado num canvas e usado como textura, então todas as expressões animam)
- `vendor/three.module.min.js`: Three.js r160 (MIT), embutido para funcionar offline; se faltar, carrega da CDN

---

# Gramado Estelar

Minigolfe isométrico em pixel art, flutuando num céu de pôr do sol, inspirado em Kirby's Dream Course, com personagens próprios. Fica na pasta [`estelar/`](estelar/).

## Como jogar

- Arraste para trás e solte para tacar. A linha pontilhada mostra o começo do caminho.
- Derrube todos os inimigos. O último vira o buraco, e aí é só acertar a bola nele.
- **Pulo**: liga a tacada aérea, para passar por vãos, água e acertar inimigos voadores.
- Durante a rolagem, segure para frear. Se tiver uma habilidade, toque para usá-la:
  - **Rocha**: para na hora.
  - **Turbo**: dá uma arrancada.
  - **Mola**: dá um quique alto.
- Ouriços não podem ser derrotados e rebatem a bola. Água e vãos custam uma tacada.
- Personagens: Pipo (equilibrado), Brasa (força), Nimbo (pulo) e Musgo (controle).
- 6 buracos com rampas, areia, gelo, setas de turbo e rebatedores.

Teclado: `J` liga o pulo, espaço freia ou usa a habilidade, `Esc` pausa.

## Estrutura

- `estelar/holes.js`: os buracos, descritos como mapas de texto (tipo de piso + altura por casa)
- `estelar/game.js`: física isométrica com alturas e rampas, renderização em baixa resolução ampliada sem suavização, sprites gerados por código (personagens e inimigos são esferas iluminadas rasterizadas pixel a pixel, por isso rolam de verdade), música chiptune e efeitos sintetizados com Web Audio

---

# Mini Fúria (Godot 4)

Corrida isométrica 3D de mini carros no estilo "arcade de batidas", feita em **Godot 4.7** (renderizador Compatibility, roda no navegador e no celular). Projeto na pasta [`minifuria/`](minifuria/): abra o `project.godot` no Godot.

![carros e props modelados no Blender](minifuria/assets/preview.png)

## Como jogar

- **Celular**: arraste no lado esquerdo para apontar a direção (relativa à tela). Acelera sozinho. À direita: **NITRO**, **DRIFT** e **FREIO** (segurar o freio parado dá ré).
- **Teclado**: setas/WASD, `Espaço` drift, `Shift` nitro, `R` volta para a pista, `P` pausa, `M` som.
- **Nitro**: enche com drift, quase-batidas, contramão, pulos, boost pads e destruindo cones/barris/caixotes.
- **Takedown**: bata forte num rival ou jogue ele no muro. Enche o nitro, câmera lenta e o carro dele vira destroço.
- **Batida**: bater de frente no muro ou no trânsito capota o carro. Depois você volta consertado, piscando.
- 3 voltas contra 3 rivais, 16 carros de trânsito nos dois sentidos.

## Destruição

- Cada carro vem do Blender em **peças**: chassi, capô, para-choques (com faróis/lanternas), portas, cabine, aerofólio, caçamba e 4 rodas.
- Cada batida **amassa a malha** de verdade perto do ponto de impacto (vértices empurrados + normais recalculadas) e escurece a pintura.
- Peças perdem "vida" e **soltam** como corpos rígidos que quicam pela pista; vidro estilhaça; rodas saem rolando. Sem uma roda, o carro arrasta soltando faíscas.
- Com muito dano sai fumaça preta e depois fogo. Batida grande = explosão, clarão de luz, onda de choque e capotagem com física.

## Nitro, velocidade e game juice

Chama azul de nitro com núcleo brilhante, rastro das lanternas, onda de choque ao ativar, blur radial + aberração cromática + linhas de velocidade estilo anime (shader de tela), zoom que abre com a velocidade, glow nos faróis, hitstop nas batidas, câmera lenta com dessaturação nos takedowns, tremor de câmera por trauma, fumaça e marcas de pneu, faíscas, poeira nos pousos, confete, popups animados e motor sintetizado com troca de marchas.

## Estrutura

- `minifuria/blender/build_assets.py`: modela no Blender (via `bpy`) os carros em peças e os props e exporta `minifuria/assets/minicars.glb`. Roda com `blender -b -P build_assets.py` ou `pip install bpy && python build_assets.py --render preview.png`.
- `minifuria/scripts/car.gd`: `RigidBody3D` com suspensão por raycast, aderência lateral, drift, nitro, estabilizador, detecção de impacto, amassados, peças que soltam e IA.
- `minifuria/scripts/track.gd`: pista em spline, malhas, colisores, rampas e boost pads.
- `minifuria/scripts/main.gd`: regras (takedown, batida, quase-batida, contramão, voltas), câmera isométrica, tempo (hitstop/slow-mo) e efeitos.
- `minifuria/scripts/fx.gd`: partículas, marcas de pneu (MultiMesh), rastros, destroços físicos.
- `minifuria/scripts/hud.gd`, `touch.gd`, `sfx.gd`: HUD/menus, controles touch e áudio sintetizado.
- `minifuria/shaders/`: asfalto, grama, boost pad, xadrez e pós-processamento de tela.
- Fonte Bungee (SIL OFL), ver `minifuria/fonts/FONT-LICENSE.txt`.

## Exportar para a web

Instale os templates de exportação do Godot 4.7 e rode `godot --headless --export-release "Web" build/web/index.html` dentro de `minifuria/` (preset "Web", sem threads, já configurado). Teste automatizado: `godot --headless --fixed-fps 60 res://scenes/main.tscn -- --autotest` corre uma corrida inteira no piloto automático e imprime o resultado.

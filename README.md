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

## Kael — herói JRPG 3D (hack and slash)

Personagem 3D em estilo anime/JRPG, modelado, texturizado, rigado e animado no **Blender** por script
(`hero/blender/build_hero.py`), com um visualizador jogável em Three.js.

- `hero/hero.glb` — malha com skin (~36 mil triângulos, 53 ossos), atlas de textura pintado por código (bordados,
  costuras, cadarços, mechas do cabelo), rosto com 4 expressões e 9 animações a 60 fps: `Idle`, `Run`,
  `Attack1`–`Attack4` (combo de quatro golpes que encadeia pose a pose), `Stinger` (estocada a partir da esquiva),
  `Dash` e `Hit`. Ataques e esquiva têm *root motion* no osso `root`.
- `hero/hero.meta.json` — eventos dos clipes (quadro do acerto, janelas de cancelamento, pisadas), deslocamento da
  raiz, correntes de ossos de mola, colisores e paleta do shader toon.
- `hero/blender/hero.blend` — cena do Blender com shader toon, contorno e um clipe por faixa NLA.
- `hero/blender/textures/` — o atlas e a textura do rosto gerados pelo script.
- `hero/index.html` — visualizador jogável: mover (WASD / direcional na tela), atacar (J), esquivar (Espaço),
  levar dano (H). Ataque 4 vezes para o combo; ataque durante a esquiva para a Estocada. Tem cel shading com contorno,
  cabelo/cachecol/casaco com física em tempo real, rastro da espada, faíscas e anéis de impacto com *bloom*, hit-stop,
  recuo dos bonecos de treino, tremor de câmera e sons sintetizados.
- `hero/preview/` — renders do Blender (ficha do personagem, rosto, poses, reel) e vídeos do visualizador a 60 fps,
  com o som sintetizado da própria página.
- `hero/ANIMATION.md` — as referências (tempos do Genshin Impact, golpes de Devil May Cry 5, princípios de animação
  de combate), como foram aplicadas e o que dá peso aos golpes.

Para regenerar tudo (Blender 4.4+ ou o módulo `bpy` do pip):

```
blender -b -P hero/blender/build_hero.py -- --sheet --reel
# ou: pip install bpy && python3 hero/blender/build_hero.py --sheet --reel
```

Para ver no navegador: `python3 -m http.server` na raiz e abra `/hero/`.

O código fica em `hero/blender/kael/`: `model.py` (corpo, rosto, cabelo em mechas, roupa, espada), `atlas.py`
(atlas de textura pintado por código), `facetex.py` (textura do rosto), `skel.py` (esqueleto e pesos), `rig.py`
(solver de poses com IK, ossos de torção e ossos de mola), `anim.py` (os clipes), `look.py` (materiais e render).
O pós-processamento do visualizador usa os módulos do Three.js r160 em `vendor/jsm/`.

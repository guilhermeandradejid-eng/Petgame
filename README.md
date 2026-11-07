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

Corrida isométrica de **combate** com mini carros, feita em **Godot 4.7** (renderizador Compatibility, roda no navegador e no celular). Projeto em [`minifuria/`](minifuria/): abra o `project.godot` no Godot.

Referências de game design: **Rock n' Roll Racing** (armas e nitro limitados que recarregam a cada volta, dinheiro por colocação e por rival destruído, upgrades na garagem), **Hot Wheels Unleashed / Trackmania** (loopings, espirais, rampas, boosters antes dos elementos) e **Burnout** (tráfego, takedowns, quase-batidas).

![carros e props modelados no Blender](minifuria/assets/preview.png)

## Fluxo do jogo

Menu → **escolha da pista** (10) → **garagem** → corrida de 3 voltas contra 4 rivais armados → **resultado** com prêmio em dinheiro → próxima pista. O progresso (dinheiro, upgrades, equipamento, melhores colocações) fica salvo.

- **Carros**: Faísca (equilibrado), Trovão (pesado e blindado), Vespa (rápida e ágil, mas frágil).
- **Arma frontal**: Metralhadora (60 tiros por volta, mira automática no cone da frente) ou Lança-foguetes (4 por volta, teleguiado leve, explosão em área).
- **Arma traseira**: Minas (jogam o carro para o alto) ou Óleo (faz o carro rodar).
- **Nitro**: Curto (4 arrancadas de 1 s) ou Longo (2 de 2,6 s). Drift, pulos, quase-batidas e takedowns enchem um medidor que dá cargas extras.
- **Upgrades** (3 níveis cada): Motor, Blindagem, Munição e Nitro +1.
- Na pista: caixas de **munição**, **reparo** e **nitro**; boost pads; barris e pneus destrutíveis.
- Cair da pista (vãos, água, lava, nuvens) ou ser destruído faz você voltar um pouco atrás, piscando.

## As 10 pistas

| # | Pista | Tema | Destaques |
|---|---|---|---|
| 1 | Circuito do Parque | parque, dia | morros, chicane, pouco tráfego |
| 2 | Cidade Neon | cidade à noite | oito com viaduto sobre o cruzamento, pouco tráfego |
| 3 | Cânion do Deserto | pôr do sol, cactos | dois saltos sobre o vale |
| 4 | Pico Nevado | neve, gelo escorregadio | espiral de descida com 2 voltas |
| 5 | Docas do Porto | mar e contêineres | píeres e saltos sobre a água |
| 6 | Boca do Vulcão | lava e cristais | looping sobre a lava e salto |
| 7 | Loop Mania | pista de brinquedo laranja | 2 loopings, espiral, torção, salto |
| 8 | Espiral do Céu | nas nuvens | espirais de subida e descida, torção, salto |
| 9 | Pântano Sombrio | brejo e palmeiras | oito com ponte alta, saltos |
| 10 | Estação Lunar | lua, gravidade baixa | saltos enormes e looping |

## Controles

- **Direção "TELA" (padrão)**: você aponta para onde quer ir **na tela** e o carro vira sozinho para lá. Não inverte quando o carro desce a tela. No celular/mouse é o analógico da esquerda; no teclado, as setas/WASD (↑ sobe a tela, ← vai para a esquerda da tela) e o carro acelera sozinho.
- **Direção "CARRO" (clássica)**: ← → giram o carro em relação a ele mesmo, ↑ acelera, ↓ freia. Troca na garagem ou no menu de pausa.
- Botões na tela: **TIRO**, **NITRO**, **DRIFT**, **MINA/ÓLEO**, **FREIO**. Teclado: `B`/`C` freio e ré, `Z`/`J` tiro, `X`/`K` mina, `Shift` nitro, `Espaço` drift, `R` volta à pista, `P` pausa, `M` som.
- Se o carro ficar no sentido errado aparece "SENTIDO ERRADO!" e, se continuar, o jogo te coloca de volta na direção certa.

## Como a pista 3D é feita

Cada pista é um polígono de pontos `[x, z, altura]` mais elementos especiais (`loop`, `jump`, `helix`, `cork`) em `scripts/track_data.gd`. O `track.gd` expande os elementos em pontos de controle, passa uma Catmull-Rom centrípeta fechada e calcula um referencial por amostra: "para cima" do mundo projetado nos trechos normais, inclinação automática nas curvas e, dentro do looping, o "para cima" aponta para o eixo do looping. Daí saem asfalto, zebras, guard-rails (mais altos nos elementos), parte de baixo, pilares (sem cair em cima de outro trecho), colisores e a decoração (placas de curva, postes, pneus, bandeiras, outdoors). O carro usa a normal da pista como gravidade e tem assistência nos loopings e na torção, no estilo dos jogos de pista de brinquedo.

Ferramentas: `godot --headless -s res://tools/validate_tracks.gd` confere raio mínimo, cruzamentos sem altura suficiente e altura mínima das 10 pistas; `godot --headless --fixed-fps 60 res://scenes/main.tscn -- --autotest --track=N` corre a pista N no piloto automático e imprime o resultado (com `--debugfall` mostra cada queda); `-- --autotest --steertest` confere que as setas viram o carro para o lado certo da tela.

## Estrutura

- `minifuria/blender/build_assets.py`: carros em peças destrutíveis, props de todos os temas, armas e itens, com oclusão ambiente assada nos vértices (Cycles) → `minifuria/assets/minicars.glb`.
- `minifuria/scripts/track_data.gd` (pistas e temas), `track.gd` (geração 3D), `car.gd` (física, dano, IA), `weapons.gd` (armas), `main.gd` (fluxo, regras, câmera, efeitos), `fx.gd` (partículas e efeitos), `hud.gd` / `touch.gd` (interface), `sfx.gd` (áudio sintetizado).
- `minifuria/shaders/`: asfalto por tema, chão (grama, areia, neve, água, lava, lua, cidade, tapete, nuvens), chama do nitro, efeitos no chão, barra de vida e pós-processamento.
- `minifuria/tools/pack_web.py`: divide o export web em arquivos de 4 MB.
- Fonte Bungee (SIL OFL), ver `minifuria/fonts/FONT-LICENSE.txt`.

## Exportar para a web

Com os templates do Godot 4.7 instalados, dentro de `minifuria/`: `godot --headless --export-release "Web" build/web/index.html` e, se o host limitar o tamanho por arquivo, `python3 tools/pack_web.py build/web build/web_split`.

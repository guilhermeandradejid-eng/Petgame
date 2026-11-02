# Lumi & Bolota: Jardins Orbitais

Plataforma 3D **cooperativo local** com foco em **puzzles**, feito em **Godot 4.7.2** (versão estável mais recente) com personagens e cenário modelados por script no **Blender 5.2.3 LTS**. A arte é estilizada: toon shading, contornos, céu e efeitos feitos em shader, e muito game juice.

Inspirações de *conceito* (nada é copiado): os pequenos planetas com gravidade própria de Mario Galaxy, a leitura clara de fases e o coop no mesmo sofá de 3D World, o ritmo e a expressividade de Rayman, e as fendas dimensionais de Ratchet & Clank: Rift Apart. Os personagens, as fases e as mecânicas são originais.

## Os heróis

| | Lumi (P1) | Bolota (P2) |
|---|---|---|
| Quem é | Raposinha-vaga-lume com uma lanterna na cauda | Cavaleirinho-bolota com capa de folha |
| Pulo | Pulo duplo e **planar** (segure pulo) | Pulo único, mais alto |
| Especial | **Elo de Luz**: puxa o Bolota até ela, a até 16 m | **Erguer/arremessar** a Lumi e caixotes |
| Peso | 1 (placa normal) | 2 (aciona placas pesadas ⬇⬇) |

Os dois têm dash, pulo longo (dash + pulo) e ground pound. Quem cai do mapa vira uma **bolha** que flutua até o parceiro.

## Fases

0. **Vale do Riacho** (demo): um mundo contínuo, no chão, sem ilhas flutuantes nem planetas. O terreno é gerado por função de altura (`scripts/world/terrain.gd`), com rio, cascata, dois penhascos, floresta murada, desfiladeiro e colina. Os puzzles usam a geografia: placas que estendem uma ponte sobre o rio, arremesso + elevador de placa no penhasco, portão de placa pesada com caixote, ventilador + Elo de Luz, ponte temporizada sobre o desfiladeiro e blocos de maré.
1. **Campo de Treino**: todas as mecânicas numa fase compacta.
2. **Prado das Lanternas** (tutorial coop): duas placas abrem um portão; o Bolota arremessa a Lumi numa torre enquanto segura uma placa pesada; um caixote faz o papel de um herói; Espinhudos; corrente de ar para a Lumi planar e Elo de Luz para puxar o Bolota.
3. **Jardim Orbital**: planetoides com gravidade esférica. Placas em lados opostos de um planeta, corrida contra um interruptor temporizado em volta de outro, e luas gêmeas cujos campos de gravidade se tocam.
4. **Ruínas da Fenda**: ponte de luz temporizada, fendas mantidas abertas pelos dois lados, escadaria de **blocos de maré** (um alterna, o outro sobe) e placas em ilhas distantes.

Cada fase tem 3 **Sementes Estelares** escondidas e faíscas para coletar.

## Controles

|  | P1 (Lumi) | P2 (Bolota) | Controle |
|---|---|---|---|
| Mover | WASD | Setas | Analógico esq. / D-pad |
| Pular | Espaço | Enter / Num0 | A |
| Dash | Shift | Num1 / `/` | X |
| Erguer, arremessar / Elo de Luz | F | `.` / Num2 | Y / RB |
| Ground pound (no ar) | C / Ctrl | Num3 / `,` | B / LB / LT |
| Câmera | Q / E | PgUp / PgDn | Analógico dir. |
| Pausa | Esc | P | Start |

- Com 1 controle e o teclado: o controle vai para o P1; use *Pausa > Trocar controles P1/P2* para inverter.
- **Modo solo**: Tab (ou Back) troca de personagem; o outro fica parado onde você o deixou, segurando placas, por exemplo.
- Arremessar **andando** joga longe; **parado** joga a Lumi para cima, ou pousa o caixote à sua frente.

## Como rodar

1. Instale o [Godot 4.7.2](https://godotengine.org/download) (versão padrão, sem .NET).
2. Abra `coop3d/project.godot` no Godot e aperte F5.

O projeto usa o renderizador Forward+ e cai para Compatibility/OpenGL automaticamente quando o Vulkan não está disponível.

## Demo para Android (APK)

O APK da demo fica em [`build/LumiBolota-demo.apk`](../build/LumiBolota-demo.apk). Ele é arm64, tem cerca de 37 MB e é assinado com uma chave de debug (v2/v3).

- Começa no **Vale do Riacho** (mundo contínuo); o **Campo de Treino** também está no menu, uma fase compacta com todas as mecânicas: pulo, pulo duplo e planar; dash e pulo longo; duas placas e um portão; arremesso até a torre com placa pesada; caixote; Espinhudo; cogumelo; ponte temporizada; fenda; ventilador com Elo de Luz; blocos de maré; planetinha com anéis de lançamento; Flor Estelar.
- **Controles de toque:** joystick flutuante à esquerda; botões Pular, Dash, Erguer/Elo, Pound e Trocar à direita; arrastar no lado direito gira a câmera.
- No celular o modo solo vem primeiro (o botão Trocar alterna entre Lumi e Bolota). Com dois controles Bluetooth dá para jogar em coop.
- O renderizador é Compatibility (OpenGL ES 3), com grama, sombras e cenário reduzidos para rodar em mais aparelhos.

Para instalar, copie o APK para o celular, permita "instalar apps de fontes desconhecidas" e abra o arquivo. Pelo PC: `adb install build/LumiBolota-demo.apk`.

Para gerar de novo, instale os export templates do Godot 4.7.2 e um Android SDK, depois:

```sh
godot --headless --path coop3d --export-release "Android" ../build/unsigned.apk
# assine com o apksigner do SDK ou com o uber-apk-signer:
java -jar uber-apk-signer.jar -a build/unsigned.apk
```

O preset fica em `coop3d/export_presets.cfg`: arm64-v8a, sem Gradle, pacote `com.lumibolota.demo`.

## Estrutura

```
coop3d/
  blender/      geradores bpy: characters.py, props.py (+ previews em Cycles)
  assets/       .glb gerados, sons CC0, fonte OFL, normal maps CC0
  shaders/      toon, contorno, terreno, céu, mar de nuvens, grama, VFX
  scripts/
    autoload/   Game (coop, entrada, progresso), Sfx (sintetizador + música
                procedural), Juice (hitstop, shake), Vfx, Transition
    player/     player.gd (controlador), character_rig.gd (animação procedural)
    core/       coop_camera.gd, mats.gd (conversão de materiais)
    world/      placas, portões, pontes, plataformas, fendas, anéis, etc.
    levels/     level_base.gd (construtor + lógica) e level_1..3.gd
    ui/         título, HUD, tema
    dev/        playtest automatizado e ferramenta de screenshots
  docs/PESQUISA.md  pesquisa de tutoriais e como cada técnica foi aplicada
```

## Regerar os modelos no Blender

Os modelos são 100% procedurais. Com o Blender 5.2 instalado:

```sh
cd coop3d/blender
blender -b -P characters.py      # lumi.glb, bolota.glb
blender -b -P props.py           # ilhas, árvores, cogumelo, cristais...
```

Sem a interface do Blender, o módulo `bpy` do PyPI também funciona: `pip install bpy==5.2.3`, depois `python characters.py`. Para ver um render de conferência: `python preview.py saida.png ../assets/models/lumi.glb`.

O rig depende dos nomes dos pivôs (`Hips`, `Head`, `ArmL`, `EarL`, `Tail1`, `Cape`...), e a conversão de materiais depende dos prefixos dos nomes (`M_Glow*`, `M_Eye*`, `M_Grass*`...).

## Testes

```sh
# compila todos os scripts
godot --headless --path coop3d res://tools/check.tscn
# testa as mecânicas de cada fase com entradas simuladas
godot --headless --path coop3d -- --playtest --level=0   # 0 = Vale do Riacho, 1 = Campo de Treino, 2..4 = fases
# screenshot de uma fase depois de N frames
godot --path coop3d -- --shot=2 --out=/tmp/fase2.png --frames=120 [--touch]
```

O playtest confere, por exemplo, alturas de pulo, pulo duplo, arremesso até a torre, placas e portões, placa pesada, ground pound, caixote na placa, Elo de Luz, corrente de ar, bolha de resgate, gravidade esférica, troca de gravidade entre luas, anéis de lançamento, fendas, maré e a Flor Estelar exigindo os dois heróis.

## Créditos e licenças

- Código, shaders, modelos e fases: originais deste projeto.
- Sons `jump/land/fall/break/coin.ogg`: Kenney, *Starter Kit 3D Platformer* (CC0).
- Fonte Lilita One: Juan Montoreano (SIL Open Font License 1.1), veja `assets/fonts/LICENSE_OFL.txt`.
- Normal maps de detalhe: pacote `@pmndrs/assets` (CC0), veja `assets/textures/LICENSE_CC0_pmndrs.txt`.
- Os demais sons e a música são sintetizados em tempo de execução pelo próprio jogo.

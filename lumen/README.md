# Lúmen: Ruínas do Entardecer

Roguelite de ação cooperativo **online para até 4 amigos**, em terceira pessoa, feito na
**Godot 4.7**. Visual low poly estilizado, com personagens chibi que você veste do jeito que
quiser. Todos os modelos, roupas, inimigos, cenários e animações foram modelados e animados
por script no **Blender 5.3**.

O grupo se encontra na **Vila do Farol**, troca de classe e de roupa, e atravessa as ruínas:
**Bosque Luminoso**, **Gruta de Cristal** e, no fim, o **Santuário do Guardião**, onde o
Guardião Cristalino espera. Cada sala vencida dá uma recompensa, e cada expedição rende
**fragmentos de lúmen** para melhorias permanentes e roupas novas.

## Como rodar

1. Baixe a **Godot 4.7.2** (versão padrão, não a .NET): https://godotengine.org/download
   É um executável só, não precisa instalar.
2. Abra a Godot, clique em **Importar** e escolha o arquivo `lumen/project.godot`.
   A primeira abertura importa os modelos (leva alguns segundos).
3. Aperte **F5** para jogar.

### Gerar o executável para mandar aos amigos

Os presets de exportação já estão no projeto (Windows, Linux, macOS e servidor dedicado):

1. Na Godot: **Editor > Gerenciar Modelos de Exportação > Baixar e Instalar**.
2. **Projeto > Exportar**, escolha **Windows** (ou outro) e clique em **Exportar Projeto**.
3. Sai um `Lumen.exe` único (com tudo embutido) em `lumen/builds/windows/`. É só mandar.

## Jogando com amigos

- **Quem hospeda** clica em **Criar sala**. Na vila aparecem, no canto inferior direito, a porta
  e os endereços da sala. O jogo tenta abrir a porta **24565 (UDP)** no roteador sozinho, via UPnP.
- **Quem entra** digita o IP do host em **Entrar na sala de um amigo**.
- Na **mesma rede** (casa, LAN): use o IP "Rede local" mostrado na vila.
- Pela **internet**: use o IP "Internet". Se o UPnP do roteador estiver desligado, abra a porta
  24565 UDP manualmente para o computador do host.
- **Sem mexer no roteador**: instalem todos o mesmo programa de rede virtual gratuito
  (**Tailscale**, **ZeroTier**, **Radmin VPN** ou **Hamachi**) e usem o IP que ele mostra para o host.
- Dá para entrar no meio de uma expedição: o jogador novo cai direto na sala atual.

**Só o host abre o portal** para começar a expedição (fica no fundo da vila) e decide voltar
à vila depois do resumo. Nas salas, cada um entra no portal que quiser: o grupo vota e a porta
mais votada vence (ou todos entram na mesma e vai na hora).

### Servidor dedicado (opcional)

Para deixar uma sala sempre aberta num PC ou servidor, sem jogador no host:

```sh
godot --headless --path lumen -- --server            # ou exporte o preset "Servidor dedicado"
```

Nesse modo qualquer jogador pode abrir o portal, e o servidor volta à vila sozinho no fim.

## Controles

| Ação | Teclado e mouse | Controle |
|---|---|---|
| Mover / câmera | WASD / mouse | analógicos |
| Ataque básico (segure para combo) | botão esquerdo | RT |
| Especial da classe | botão direito | LT |
| Habilidades | Q e R | LB e RB |
| Suprema | F | Y |
| Esquiva (invulnerável) | Shift | B |
| Pular | Espaço | A |
| Interagir / levantar aliado (segure) | E | X |
| Frasco de cura | V | ↑ |
| Emotes (acenar, comemorar, dançar, sentar) | 1 a 4 | |
| Ver bênçãos e relíquias | Tab (segure) | Back |
| Menu e opções | Esc | Start |

Quando um herói cai, um aliado chega perto e segura **E** para levantá-lo. Se o grupo inteiro
cair, a expedição termina.

## Conteúdo da demo

**4 classes**, cada uma com ataque básico, especial, duas habilidades e uma suprema:

- **Espadachim**: combo de 3 cortes, estocada invulnerável, redemoinho, salto esmagador e Tempestade de Lâminas.
- **Patrulheiro**: tiros rápidos (o 3º sai triplo), flecha perfurante, leque de flechas, salto de recuo e Chuva de Flechas.
- **Arcanista**: orbes arcanos, piscar, bola de fogo, nova de gelo e Meteoro.
- **Guardião**: marteladas, escudada que atordoa, bênção de cura, tremor e Santuário.

**12 magias** encontradas nas expedições (qualquer classe usa, no lugar do Q ou do R): corrente de
raios, lança de gelo, chuva de estrelas, escudo de lúmen, círculo de cura, totem espinhoso,
lâminas orbitantes, vórtice, vendaval, raio solar, passo de luz e bola de fogo.

**24 bênçãos** que acumulam níveis e **25 relíquias** com efeitos especiais (explodir inimigos ao
derrotá-los, raios a cada 5 acertos, escudo no começo da sala, eco de habilidade, pena de fênix...).

**Expedição** de 10 salas com escolha de caminho: combate, elite, mercador, fonte de cura,
tesouro e o chefe. O chefe tem 3 fases, investida, chuva de cristais e invoca ajudantes.

**6 inimigos**: Brotinho, Cogumelo Brigão, Fagulha (atira de longe), Cascudo (investe),
Sentinela de Ruína (elite) e o Guardião Cristalino. Inimigos "campeões" aparecem maiores e com
aura dourada. Todo ataque inimigo avisa no chão antes de acertar: dá para esquivar sempre.

**Guarda-roupa** (na vila) com **74 peças** + 5 estilos de olhos: 11 cabelos, 12 chapéus,
5 orelhas e chifres, 7 acessórios, 10 roupas, 7 calças e botas, 10 itens de costas (capas que
balançam, asas, caudas, mochila, casco) e 3 visuais para cada uma das 4 armas. Seis cores
editáveis: pele, cabelo, cor principal, secundária, detalhes e olhos. Peças raras são compradas
com fragmentos de lúmen.

**Progressão permanente** no Altar de Lúmen (vida, dano, crítico, recarga, ouro inicial, frascos,
segundo fôlego, sorte e mais fragmentos) e **níveis de dificuldade** ("Fúria") liberados ao
vencer o Guardião.

## Estrutura

```
lumen/
  project.godot, export_presets.cfg
  scenes/main.tscn            cena inicial (monta mundo + interface)
  scripts/core/               save, rede (ENet + UPnP), fluxo do jogo, banco de dados, efeitos, áudio, testes
  scripts/player/             herói, câmera, visual e troca de roupa, habilidades, relíquias
  scripts/enemies/            inimigos (IA no host, avisos de ataque em todos os clientes)
  scripts/world/              mundo, salas procedurais, vila, portais, projéteis, saque
  scripts/ui/                 HUD, janelas (recompensa, loja, guarda-roupa, altar...), menu
  shaders/                    toon em duas faixas, avisos no chão, cortes, brilho, portal
  assets/models/              .glb gerados pelo Blender + manifestos .json
  assets/icons, assets/fonts  ícones (game-icons.net) e fontes (OFL)
  tools/blender/              scripts de modelagem e animação (ver tools/blender/README.md)
  tools/*.sh, tools/preview.gd  capturas, testes de rede e folhas de contato
```

### Rede, em resumo

- ENet (UDP) com compressão. Host = servidor com autoridade sobre salas, inimigos e recompensas.
- Cada jogador simula o próprio herói (controle sem atraso) e manda posição 20x por segundo;
  os outros interpolam. Ações (golpes, magias, esquivas) viajam como eventos e são repetidas.
- Inimigos rodam no host e chegam aos clientes em lotes ~14x por segundo. Cada ataque inimigo é
  anunciado antes, e cada cliente confere se o **próprio** herói foi atingido na hora do golpe,
  então esquivas funcionam igual para todos, mesmo com latência.
- Ouro e recompensas são individuais (ninguém disputa saque).

### Arte

Tudo sai de `tools/blender/` (precisa do Blender 5.3 ou do módulo Python `bpy`):

```sh
pip install bpy==5.3.0
python3 tools/blender/build_hero.py      # herói, roupas e 40 animações -> assets/models/hero.glb
python3 tools/blender/enemies.py         # os 6 inimigos
python3 tools/blender/env_forest.py      # e env_hub.py, env_crystal.py, env_boss.py, props.py
```

O guia de estilo e as convenções (materiais de paleta, ossos, slots de roupa) estão em
`tools/blender/README.md`.

## Testes automáticos

O jogo aceita opções depois de `--` para testar sem ninguém jogando:

```sh
godot --path lumen -- --host --bot --autostart=3          # o herói joga sozinho
godot --path lumen -- --host --bot --room=boss:boss --autostart=2 --god
tools/mp_test.sh 2 120                                     # host + 2 clientes bots, sem janela, por 120 s
```

`--profile=nome` usa um perfil salvo separado (útil para abrir duas cópias no mesmo PC),
`--cls=arcanista`, `--look=aleatorio`, `--shot=arquivo.png@10` (captura), `--log` e `--quit=S`.
Veja o cabeçalho de `scripts/core/dev.gd`.

## Limitações conhecidas da demo

- O host tem a palavra final sobre inimigos, mas cada jogador confia no próprio herói (pensado
  para jogar entre amigos, não há proteção contra trapaça).
- Não há busca de salas: a conexão é por IP (ou rede virtual). Steam/EOS ficaram fora da demo.
- Os sons e a música são sintetizados pelo próprio jogo; ainda são simples.

Créditos de ícones e fontes em [CREDITS.md](CREDITS.md).

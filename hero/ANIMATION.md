# Kael — como as animações foram feitas

Tudo é gerado por `blender/build_hero.py` (Blender / `bpy`), a 60 fps. Este arquivo registra as referências que
guiaram os tempos, a técnica usada em cada clipe e o que dá peso aos golpes no visualizador.

## Referências

Os números de quadros abaixo vieram de trechos de busca das fontes citadas (as páginas não puderam ser abertas por
inteiro neste ambiente), então trate-os como referência, não como medição própria. As inspirações em
*Devil May Cry 5* e nos efeitos visuais do *Genshin Impact* vêm de conhecimento geral sobre os jogos, sem medição.

| Tema | Referência | O que foi aplicado |
| --- | --- | --- |
| Tempo dos golpes de espada no Genshin | N1 acerta em 8–14 quadros, N2 em 9–11, N3 em 13–16; o próximo golpe pode sair 5–18 quadros depois do acerto ([KQM: Kaeya](https://library.keqingmains.com/characters/cryo/kaeya), [Bennett](https://library.keqingmains.com/characters/pyro/bennett), [Keqing](https://library.keqingmains.com/characters/electro/keqing)) | Acerto nos quadros 12 / 13 / 13 e 27 (finalizador); cancelamento a partir de 22 / 23 / 25 / 50 |
| Esquiva | ~20 quadros, cancela a recuperação dos golpes ([KQM: frames](https://library.keqingmains.com/combat-mechanics/frames)) | Arranque em 3 quadros, 2,6 m, cancelável a partir do quadro 18 |
| Hit-stop | Desaceleração por 2–6 quadros nos golpes leves e 8–11 nos pesados ([Hitlag](https://genshin-impact.fandom.com/wiki/Hitlag), [gcsim](https://docs.gcsim.app/mechanics/hitlag/)) | 5 / 5 / 7 / 12 quadros no combo e 9 na Estocada, a 2% de velocidade; os pesados voltam à velocidade normal aos poucos |
| Produção | Captura de movimento com exagero aplicado por cima; a pose de descanso "conta uma história" ([HoYoverse, time de animação](https://genshin.hoyoverse.com/en/news/detail/103849)) | Poses-chave exageradas; idle com a espada apoiada no ombro, mão na cintura e peso numa perna |
| Estrutura de um golpe | Antecipação curta, golpe em 2–5 quadros, pose final segurada, recuperação cancelável ([Sakurai](https://www.youtube.com/watch?v=3kTYazhO3fs), [Aztez](https://aztez.com/blog/2012/05/24/the-amalur-problem/)) | Antecipação de 5–7 quadros, corte em 4–8 com o contato no meio, pose final segurada por ~9 |
| Sobreposição | Cada articulação parte 2–5 quadros depois da anterior ([Animation Mentor](https://www.animationmentor.com/?p=96605), [Cascadeur](https://cascadeur.com/blog/general/separation-and-compensation-principle-in-strikes-animation)) | Quadril → coluna (+1) → peito (+1,6) → braço (+2,4) → lâmina (+3) |
| Corrida | Contato, descida, passagem, subida; pé de apoio recua em linha reta na velocidade exata do personagem ([anim.works](https://anim.works/?p=32499)) | Ciclo de 36 quadros, 4,38 m/s, 10 quadros de apoio e 8 de voo por passo |
| Tecidos e cabelo | Algoritmo do VRM SpringBone: inércia com arrasto, rigidez, gravidade, colisores esféricos ([VRM](https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_springBone-1.0/README.md)) | 11 correntes de ossos de mola, simuladas no Blender e, em tempo real, no visualizador |
| Transições | Golpes de combo começam na pose final do golpe anterior; blends curtos para ataques ([Unreal forum](https://forums.unrealengine.com/t/wip-ninja-arcade/7468/88)) | Cada golpe do combo começa na pose final do anterior; blend de 2–3 quadros |
| Golpes de *Devil May Cry 5* | Stinger (investida com estocada), Helm Breaker (corte vertical vindo do ar), combos que variam o ritmo e terminam em pose | `Stinger` sai ao atacar durante a esquiva; `Attack4` é um salto com corte a duas mãos; o terceiro golpe é um giro de 360° no ar |
| Efeitos do Genshin | Rastro em crescente fino com borda brilhante e corpo translúcido, estrela de impacto, anéis no chão, cor do elemento, brilho contido | Ver "Efeitos" abaixo |

## Os golpes

| Clipe | Nome no jogo | Quadros | Acerto | Cancela | Raiz | Movimento |
| --- | --- | --- | --- | --- | --- | --- |
| `Idle` | Em guarda | 384 (ciclo) | | | | Espada no ombro direito, mão esquerda na cintura, respiração |
| `Run` | Corrida | 36 (ciclo) | | | 4,38 m/s | Tronco inclinado, espada baixa para trás |
| `Attack1` | Corte diagonal | 56 | 12 | 22 | +0,34 m | Corte que sai do ombro, com avanço e pisada |
| `Attack2` | Corte horizontal | 56 | 13 | 23 | +0,36 m | Revés largo com passo cruzado, termina com a espada erguida |
| `Attack3` | Giro aéreo | 62 | 13 | 25 | +0,30 m | Salto curto com giro de 360° e aterrissagem baixa |
| `Attack4` | Quebra-elmo | 86 | 27 | 50 | +1,34 m | Salto e corte vertical a duas mãos, aterrissagem agachada |
| `Stinger` | Estocada | 62 | 12–22 | 31 | +3,42 m | Investida longa; sai ao atacar durante a esquiva |
| `Dash` | Esquiva | 40 | | 18 | +2,6 m | Arranque baixo; cancela quase tudo |
| `Hit` | Dano | 44 | | 26 | −0,38 m | Recuo com o tronco jogado para trás |

Encadeamento: `Attack1 → 2 → 3 → 4 → 1`; `Dash` + ataque → `Stinger`; `Stinger` → `Attack2`.

## Como cada peça funciona

- **Poses-chave em espaço do personagem.** Cada pose define quadril, torção do tronco, direção do olhar, braço
  (direção + extensão a partir do ombro) e direção da lâmina. Braços e pernas são resolvidos por IK; a mão da espada
  é orientada pela lâmina.
- **Braços sem torção.** O ombro só balança; todo o giro vai para um osso de torção (`upper_arm_twist`), e o antebraço
  tem o seu (`forearm_twist`). O cotovelo acompanha a mão (aponta para o lado oposto à lâmina) em vez de ficar preso a
  um alvo fixo, e a espada é empunhada com 22° de inclinação, como um sabre, o que tira o punho do limite.
- **Giro do punho.** Onde o giro natural é bem definido ele é calculado pela menor tensão; perto do alinhamento
  lâmina/antebraço, ou na pegada a duas mãos, vale uma chave explícita. Isso evita estalos entre um golpe e outro.
- **Tempo.** Cada chave é `hold` (para) ou `pass` (atravessa em velocidade); cada trecho tem uma curva de aceleração
  própria. O golpe atravessa a pose de contato na velocidade máxima e freia só na pose final.
- **Arcos.** A direção da lâmina é interpolada em ângulos, nunca em linha reta, então a ponta sempre descreve um arco.
- **Assentamento.** Depois de montado, cada clipe passa por um filtro de mola subamortecida no quadril, coluna, peito
  e olhar: o corpo passa um pouco do ponto e volta, que é o que vende a massa depois de um golpe ou de uma aterrissagem.
- **Pés.** Cada pé é uma sequência de apoios fixos no chão e passos reais, com giro sobre o calcanhar ou a ponta; o
  quadril é puxado para manter o pé plantado ao alcance. Os ataques e a esquiva carregam *root motion* (o `Attack3`
  inclui o giro de 360° na raiz).
- **Vida.** Respiração em onda (barriga → peito → ombros → cabeça) por cima de todas as poses, piscadas e troca de
  expressão no rosto (neutro, piscando, ataque, dor).

## Peso dos golpes no visualizador

- **Hit-stop** por golpe (5 / 5 / 7 / 12 / 9 quadros), com o alvo tremendo e piscando em branco; nos golpes pesados a
  velocidade volta aos poucos.
- **O alvo reage.** Cada acerto empurra o boneco para trás (0,30 a 1,35 m), inclina, amassa e, no giro, faz rodar. O
  herói para a uma distância de combate (1,25 a 1,5 m): o avanço do golpe serve para alcançar o alvo, não para
  atravessá-lo.
- **Câmera.** Aproximação rápida do campo de visão e tremor proporcional ao golpe.
- **Chão.** Poeira na pisada de cada golpe e nos passos da corrida; o Quebra-elmo deixa dois anéis e uma rachadura.
- **Som** sintetizado (Web Audio): assobio da lâmina 4 quadros antes do acerto, baque e tinido no contato, passos na
  corrida; um limitador na saída evita distorção quando vários sons se somam.

## Efeitos

- **Rastro da espada**: fita amostrada 4 vezes por quadro entre a base e a ponta da lâmina. Só a borda da ponta é
  clara (e só ela passa do limiar do *bloom*); o corpo é translúcido, azul-esverdeado, corroído por ruído, e afina
  até sumir na cauda. O personagem continua visível através dele.
- **Impacto**: linha de corte sobre o alvo com estrela de quatro pontas, faíscas em risco, brilhos em losango e o
  número do dano.
- **Estocada e esquiva**: linhas de vento ao longo do deslocamento e anel no chão na arrancada.
- **Bloom** (`UnrealBloomPass`) com limiar acima de 1: só elementos HDR brilham. Em aparelhos lentos o passe é
  desligado sozinho.

## Verificação

`build_hero.py` imprime, por clipe, o pico de velocidade da ponta da espada, o ângulo do punho e a extensão máxima
das pernas, e grava tudo quadro a quadro em `blender/diag.json`. Na versão atual a ponta chega a 50–70 m/s nos
golpes e o alvo do pé nunca fica a mais de 105% do alcance da perna (99% fora do salto e da estocada).

O visualizador foi conferido quadro a quadro em navegador sem tela (folhas de contato extraídas dos vídeos de `preview/`):
todos os golpes do combo e a Estocada acertam o alvo, a demo automática roda 40 s sem erro e a página não transborda
na largura de celular. O som dos vídeos foi renderizado fora do tempo real a partir do mesmo grafo de áudio da página
e conferido por medição (pico de 0,68, sem saturar). Os vídeos não foram assistidos em movimento nem o som foi ouvido.

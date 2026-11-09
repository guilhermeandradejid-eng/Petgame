# Kael — como as animações foram feitas

Tudo é gerado por `blender/build_hero.py` (Blender / `bpy`), a 60 fps. Este arquivo registra a pesquisa que guiou
os tempos e a técnica usada em cada clipe.

## O que a pesquisa mostrou

Os números abaixo vieram de trechos de busca das fontes citadas (as páginas não puderam ser abertas por inteiro
neste ambiente), então trate-os como referência, não como medição própria.

| Tema | Referência | O que foi aplicado |
| --- | --- | --- |
| Tempo dos golpes de espada no Genshin | N1 acerta em 8–14 quadros, N2 em 9–11, N3 em 13–16; o próximo golpe pode sair 5–18 quadros depois do acerto ([KQM: Kaeya](https://library.keqingmains.com/characters/cryo/kaeya), [Bennett](https://library.keqingmains.com/characters/pyro/bennett), [Keqing](https://library.keqingmains.com/characters/electro/keqing)) | Acerto no quadro 13 (N1), 13 (N2) e 27 (finalizador); cancelamento a partir do quadro 22 / 22 / 47 |
| Esquiva | ~20 quadros, cancela a recuperação dos golpes ([KQM: frames](https://library.keqingmains.com/combat-mechanics/frames)) | Arranque em 3 quadros, deslocamento até o quadro 18, cancelável a partir do 18 |
| Hit-stop | Desaceleração para ~1% por 2–6 quadros nos golpes leves, mais no finalizador ([Hitlag](https://genshin-impact.fandom.com/wiki/Hitlag), [gcsim](https://docs.gcsim.app/mechanics/hitlag/)) | 4 / 5 / 9 quadros a 3% de velocidade, com tremor de câmera e flash no alvo |
| Produção | Captura de movimento com exagero aplicado por cima; a pose de descanso "conta uma história" ([HoYoverse, time de animação](https://genshin.hoyoverse.com/en/news/detail/103849)) | Poses-chave exageradas e idle com respiração em onda |
| Estrutura de um golpe | Antecipação curta, golpe em 2–5 quadros, pose final segurada, recuperação cancelável ([Sakurai](https://www.youtube.com/watch?v=3kTYazhO3fs), [Aztez](https://aztez.com/blog/2012/05/24/the-amalur-problem/)) | Antecipação de 5–6 quadros, corte em ~6, pose final segurada por ~10 |
| Sobreposição | Cada articulação parte 2–5 quadros depois da anterior ([Animation Mentor](https://www.animationmentor.com/?p=96605), [Cascadeur](https://cascadeur.com/blog/general/separation-and-compensation-principle-in-strikes-animation)) | Quadril → coluna (+1) → peito (+1,6) → braço (+2,4) → lâmina (+3) |
| Corrida | Contato, descida, passagem, subida; pé de apoio recua em linha reta na velocidade exata do personagem ([anim.works](https://anim.works/?p=32499)) | Ciclo de 36 quadros, 4,38 m/s, 10 quadros de apoio e 8 de voo por passo |
| Tecidos e cabelo | Algoritmo do VRM SpringBone: inércia com arrasto, rigidez, gravidade, colisores esféricos ([VRM](https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_springBone-1.0/README.md)) | 11 correntes de ossos de mola, simuladas no Blender e, em tempo real, no visualizador |
| Transições | Golpes de combo começam na pose final do golpe anterior; blends curtos para ataques ([Unreal forum](https://forums.unrealengine.com/t/wip-ninja-arcade/7468/88)) | N2 começa na pose final de N1, N3 na de N2; blend de 2–3 quadros |

## Como cada peça funciona

- **Poses-chave em espaço do personagem.** Cada pose define quadril, torção do tronco, direção do olhar, braço
  (direção + extensão a partir do ombro) e direção da lâmina. Braços e pernas são resolvidos por IK; a mão da espada
  é orientada pela lâmina.
- **Tempo.** Cada chave é `hold` (para) ou `pass` (atravessa em velocidade); cada trecho tem uma curva de aceleração
  própria. O golpe atravessa a pose de contato na velocidade máxima e freia só na pose final.
- **Arcos.** A direção da lâmina é interpolada em ângulos, nunca em linha reta, então a ponta sempre descreve um arco.
- **Fio da lâmina.** A lâmina fica atrasada em relação ao antebraço durante o golpe, o que mantém o fio à frente do
  movimento; o giro do punho é uma chave explícita para o antebraço pronar sem estalar entre um golpe e outro.
- **Pés.** Cada pé é uma sequência de apoios fixos no chão e passos reais; o quadril é puxado para manter o pé
  plantado ao alcance. Os ataques e a esquiva carregam *root motion*.
- **Vida.** Respiração em onda (barriga → peito → ombros → cabeça) por cima de todas as poses, piscadas e troca de
  expressão no rosto (neutro, piscando, ataque, dor).

## Verificação

`build_hero.py` imprime, por clipe, o pico de velocidade da ponta da espada, o alinhamento do fio com o movimento,
o ângulo lâmina/antebraço e a extensão máxima das pernas, e grava tudo quadro a quadro em `blender/diag.json`.

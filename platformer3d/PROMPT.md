# Prompt: Bolo & Pip, personagem de plataforma 3D

> Prompt consolidado a partir das respostas do autor. Serve de especificação para este MVP e pode ser reutilizado como está.

## O pedido

Crie, com Blender (via `bpy`, tudo em script, reproduzível) e Godot 4.7, o personagem jogável de um plataforma 3D em terceira pessoa, com co-op previsto para o futuro. As referências são Banjo-Kazooie, Donkey Kong 64 e Super Mario 64/Odyssey. O acabamento é de **brinquedo de vinil**: formas macias e fundidas, superfície lisa com brilho de verniz, cores saturadas. Entregue um cenário de teste genérico (graybox) que exercite todas as mecânicas, jogável no PC e numa versão web testável no celular.

## Personagem

- **Bolo**, panda-vermelho, protagonista jogável.
  - Silhueta de pera com cabeça grande (cerca de 40% da altura), orelhas triangulares arredondadas, bochechas fofas e cauda anelada grossa.
  - Paleta: ferrugem `#c9562c`, creme `#f4e6cc` (focinho, sobrancelhas, barriga, anéis da cauda), membros marrom-escuro `#3a2420`.
  - Personalidade: corajoso, teimoso, um pouco desajeitado. Corre inclinado para a frente com os braços para trás.
- **Pip**, morceguinho roxo `#6d4ba3` com orelhas enormes, companheiro **que voa em volta do Bolo como a Navi**, sem mochila.
  - Segue com mola e atraso, flutua oscilando e olha para onde o Bolo vai.
  - Participa das mecânicas:
    - **pulo duplo:** o Pip mergulha sob os pés do Bolo, que pisa nele e salta (o Pip achata e sai girando);
    - **planar:** o Bolo agarra os pés do Pip acima da cabeça e o Pip bate as asas como um guarda-chuva.
  - No co-op futuro, o Pip é o 2º jogador.

## Moveset e animações

Todas as animações seguem os 12 princípios da Disney, adaptados para jogo:

| Animação | Notas de animação |
|---|---|
| `idle` | respiração com squash leve, a cauda e as orelhas atrasam (follow-through) |
| `idle_fidget` | após ~6 s parado: brinca com o Pip (tenta pegá-lo, o Pip escapa) |
| `walk`, `run` | blend por velocidade; arcos claros na cabeça e na cauda; inclinação na corrida; contato e passagem bem marcados |
| `skid` | ao inverter a direção correndo: freia com o corpo para trás e solta poeira |
| `jump` | antecipação curta (2 a 3 frames, para não atrasar o controle), esticar na subida |
| `apex`, `fall` | squash no ápice e esticar na queda; os braços sobem na queda |
| `land`, `land_heavy` | pouso normal com squash; pouso pesado quando a queda é alta: squash forte, poeira e tremor de câmera |
| `double_jump` | pisa no Pip e dá uma cambalhota para a frente |
| `glide` | segura o Pip acima da cabeça, as pernas balançam, queda lenta |
| `ledge_hang`, `ledge_climb` | agarra a borda, fica pendurado balançando e sobe |

Princípios aplicados:
- **Squash & stretch** nas poses e em escala de ossos.
- **Antecipação.**
- **Staging:** silhueta legível na câmera de jogo.
- **Pose a pose** com breakdowns.
- **Follow-through e overlap:** cauda, orelhas e o Pip; molas em runtime.
- **Slow in/slow out** com curvas bezier.
- **Arcos.**
- **Ação secundária:** o Pip.
- **Timing** em frames.
- **Exagero.**
- **Volume sólido.**
- **Appeal.**

## Controle (game feel)

- Aceleração e desaceleração com curva e giro suave.
- **Coyote time** (~0,12 s), **buffer de pulo** (~0,12 s) e **altura variável** (toque curto = pulinho, segurar = pulo alto).
- Pulo duplo uma vez por voo. Planar ao segurar o pulo durante a queda (depois do pulo duplo ou caindo).
- Derrapagem ao inverter a direção acima de ~70% da velocidade máxima.
- Pouso pesado quando a queda passa de ~4 m.
- Agarrar borda detectado por raycasts (parede no peito, vazio acima da cabeça). Na borda, pulo ou frente sobe; trás solta.
- Câmera livre (Odyssey): mouse, analógico direito ou arrastar na tela. Recentraliza atrás do personagem quando fica parada e evita paredes.

## Cenário de teste

Um graybox pastel com:
- área aberta para correr e derrapar;
- degraus de alturas crescentes;
- vãos que só passam com pulo duplo;
- vão longo que exige planar;
- torre alta para o pouso pesado;
- paredes com beiradas para agarrar;
- rampas.

## Entregáveis

- `platformer3d/blender/`: scripts `bpy` que geram o modelo, o rig, as animações e o `.glb`.
- `platformer3d/godot/`: projeto Godot 4.7 com controlador, câmera, Pip, cenário e controles de toque (joystick à esquerda; pulo à direita; arrastar para girar a câmera).
- Uma versão web publicada para testar no celular.

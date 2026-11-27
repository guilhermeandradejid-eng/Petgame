# Prova de estilo: Tralha da Cheia (v2, depois da crítica)

Esta é uma cena de demonstração, não o jogo. Tudo foi gerado por código neste container: modelagem e pintura em bpy e numpy, cena em Godot 4.7.2. Nenhum modelo, textura ou fonte foi baixado. Personagens, cenário e padrões são originais. A referência é o brinquedo de miriti de Abaetetuba, sem copiar nenhuma peça e sem nenhum elemento religioso.

A versão anterior (v1) de todas as entregas, com as notas dela, está em `entrega/v1/`. O código da v1 está copiado em `bak_v1/`.

## O momento mostrado

É "o passe no Trapiche Velho", da proposta, contado como uma pequena história:

1. A Tiá Marola dá o último golpe do malho num Bucho: a **Despedida**. O malho racha pelas facetas, vira 2 tons junto com o alvo e estoura em lascas. Uma lasca na cor dela voa para o canto do Mural.
2. O Piaba já tinha visto que o malho estava no fim e arremessa o remo durante o congelamento. O congelamento é local: só a Marola e o Bucho param.
3. A Marola pede ("me passa!", balão com a mão aberta na cor dela), vira para ele e pega o remo no ar. Um anel recortado na cor dela se abre no chão.
4. Ela solta a **recepção**, uma remada larga, no segundo Bucho, que estava telegrafando: inchando, com a espiral listrada girando e se fechando no chão. O Bucho voa do trapiche e cai na água rasa, que levanta uma **coroa de respingo** recortada. Ele fica boiando.
5. O Piaba comemora, quica e assenta. No fundo, a Lata-Velha treme sobre a rota listrada dela, que anda com setas.

## Entregas

Todas ficam em `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/provas/tralha-da-cheia/entrega/`.

| Arquivo | O que é | Renderer | Tempo de render |
|---|---|---|---|
| `beauty.png` | 1920×1080, quadro 58 da linha do tempo do clipe. Câmera mais baixa e mais perto (28°, 7,4 m), Marola no terço direito, contraluz quente, Bucho escuro desfocado em primeiro plano, vinheta leve de valor. Nível PC: sombra real, MSAA 4×, névoa só no fundo | Forward+ | cerca de 12 s |
| `stress.png` | 1280×720 na câmera de camarote (31°, 15,5 m). 4 heróis com cor e símbolo de chão, 20 inimigos (Buchos de 0,8 a 1,2×) e 3 efeitos ao mesmo tempo: Despedida da Mestra Breu, passe no ar do Remanso para a Marola com a fita verde, e Piaba como Boia na água com espuma e coroa. Também há 4 telegrafias e o balão "me passa!" | Compatibility | 4,1 s; 148 draw calls, 61 mil primitivas |
| `portoes.png`, `portoes.json` e `colisao.json` | Portões do estresse (cinza, borrão de 4 px, miniatura 320×180, deuteranopia e protanopia) e teste de colisão da arma | — | 3 s |
| `clip.mp4` e `clip.gif` | 4,2 s (252 quadros), 1280×720 a 60 fps, renderizado a 1920×1080 com MSAA 4× e reduzido. Câmera de 28° | Forward+ com sombra | 302 s pelo Movie Maker (1,2 s por quadro) e cerca de 20 s de codificação. O mp4 tem 3,0 MB; o gif, de 640 px a 15 fps, tem 2,7 MB |
| `modelo.png` | Folha de modelo: os 4 heróis e 2 Inchados de frente, de 3/4 e de perfil, mais 3 faixas de 8 poses-chave (remada da Marola, a mesma remada no Piaba, malho até a Despedida), agora a 60° de giro, com o rosto à mostra | Forward+ | cerca de 4 s por faixa |

## O que mudou na v2, por prioridade da crítica

### 1. Cor = dono (corrigido)

- O malho era açaí, a cor da 4ª jogadora, e por isso as lascas e a estrela da Despedida saíam roxas. **As armas agora são tralha neutra**: o malho tem cabeça de lama com faixas de miriti cru, e o remo tem cabo de lama e pá ferrugem com chevrons creme. A cor de jogador fica no anel, no recorte do corpo e nos efeitos.
- **Todo efeito de golpe usa a cor de quem bateu**: estrela de estalo, borrão (smear) e a lasca que voa para o Mural. As outras lascas são neutras (lama, creme, ocre). Na Despedida da Marola, a estrela é urucum. No estresse, a Despedida é da Breu e a estrela é roxa ao lado do anel roxo dela, o que agora está certo pela regra.
- Os frutos de açaí da barraca passaram de roxo para quase preto, e o snorkel do Piaba trocou as faixas urucum por anil.
- O magenta continua só nos inimigos: olho do Bucho, olho e isca da Gaiola.

### 2. Piso (corrigido)

- O piso usa **2 matizes claros e dessaturados**: miriti cru `#EDE1C6` e um cinza-azulado novo, `tabua_cinza` `#C4C9C3`. A diferença de valor entre eles é de cerca de 14%.
- A cor vai **por placa**, em remendos de 5 fileiras por cerca de 3,6 m, e não mais por tábua. As faixas pintadas nas tábuas saíram e a mancha de água caiu para a metade.
- A sombra do piso clareou: a tinta de sombra passou para cerca de 80% de valor (antes ~55%), e o degrau do meio do toon subiu para 0,88. A sombra da água também clareou.
- Resultado: os heróis e os inimigos ficam nos extremos de valor e o piso fica no meio-tom claro.
- A paleta mestra tem 25 cores (era 24).
- Também corrigi um defeito de reprodutibilidade: a semente do cenário vinha de `hash()` de string, que muda a cada processo. Agora vem de `crc32`, e o cenário sai igual em toda execução.

### 3. Câmera e rostos (corrigido)

- A câmera do jogo desceu de 38° para **28° no clipe e no quadro bonito** e para **31° no estresse**. O estresse ficou mais alto que o clipe porque mais baixo os inimigos se encobrem e o portão de borrão caiu (testei 34° e posições diferentes).
- **Cabeça 1,3× maior e crânio inclinado 12° para trás** em todos os heróis. O ajuste é aplicado às peças e aos ossos da cabeça, chapéu, lenço e snorkel (`cabeca_grande`/`cabeca_ossos` em `bonecos.py`, `Builder.xf` em `malha.py`). As marcas pintadas acompanham o ajuste.
- **Olhos maiores e mais claros que a pele**: o olho de herói virou olho de boneco pintado, com branco creme, borda de tinta, pupila grande e brilho. Agora o rosto da Marola lê sobre a pele escura.
- No estresse, a Marola foi virada para a câmera (antes estava de costas).

### 4. Corpos e silhuetas (parcialmente corrigido)

- **Braços e pernas afunilados**: ombro e coxa cheios, cotovelo e joelho finos e antebraço "de boneco", cheio perto do cotovelo e fino no punho. A canela tem panturrilha.
- **Mãos de luva**: palma em almofada, rolo de dedos e polegar à parte. A mão aberta tem 3 dedos redondos e polegar.
- **Mestra Breu** ganhou um pote de breu nas costas, de ferrugem com borda de tinta escorrendo, e um pincel de estopa saindo torto acima da cabeça. Ganhou também um chumaço de estopa pendurado no ombro esquerdo, com mola. A silhueta virou assimétrica de verdade.
- **Seu Remanso** ganhou uma vara mais longa (2,45 m; antes 1,8 m), 60% mais grossa e inclinada, que quebra a vertical. O chapéu cônico passou a ser palha escura com faixas verdes (antes era amarelo com faixas pretas, o que também era listra de perigo).
- O chanfro (bevel) só existe nas peças de caixa. As peças de loft continuam facetadas por desenho.

### 5. Inimigos lidos de cima (corrigido)

- O olho do Bucho subiu para o terço de cima, inclinado para a câmera e 1,4× maior.
- Os Buchos variam de tamanho de 0,8 a 1,2×.
- A Gaiola ganhou patas 2× mais grossas, de tinta, com contorno 1,6× e uma **isca magenta** pendurada dentro. A porta deixou de ser amarela.

### 6. Listra amarela e preta só para perigo (corrigido)

- A "prancha listrada" que a crítica viu é a rota de telegrafia da Lata-Velha. Ela agora **anda**: listras rolando, setas creme e borda de tinta na frente do enchimento. No quadro bonito, onde a Lata ficava fora do quadro e a faixa parecia decoração, a Lata e a rota foram escondidas (`lata=0`).
- O anel do Bucho virou uma **espiral listrada que gira para dentro** enquanto se fecha.
- Não sobrou listra amarela e preta no cenário: a janela listrada da casa flutuante virou tábua lisa, e saíram também a porta amarela da Gaiola e o chapéu do Remanso.

### 7. Separação de borda (corrigido, com uma escolha)

- No shader `miriti`, as facetas de borda (fresnel em degrau) dos heróis jogáveis ganham a cor do dono, com intensidade 0,45.
- Também testei um **fio de contorno colorido por fora do preto**. Ele fica lindo no quadro bonito, mas derrubou o portão de borrão: herói mínimo 0,106, porque o fio de valor médio come o contraste do contorno preto contra o piso claro. Com a versão escura da cor, o mínimo foi 0,119. Por isso ficou desligado (`fio=1` liga).
- No quadro bonito há contraluz quente nas facetas de costas.

### 8. Rastros e lascas (corrigido)

- A fita do passe tem no máximo 9 amostras (cerca de 130° do giro do remo), largura zero na cauda e cheia na cabeça, e some em 4 quadros.
- As lascas vivem no máximo 0,8 s e encolhem até sumir nos últimos 12 quadros. São no máximo 12 por golpe (antes eram até 24). Só a lasca do Mural vive mais, porque voa para a interface.

### 9. Animação (parcialmente corrigido)

- **Respiração em degrau** no idle de todos os heróis: o peito estica 2,8% em hold de 12 quadros (8 no Piaba, 14 no Remanso, 10 na Breu), com a cabeça e a boia acompanhando. Ficou em 2,8% e não 3% porque a mola desliga em osso com escala acima de 3%.
- Na antecipação da remada da Marola, o cotovelo dobra 96° e a mão esquerda cruza o peito. O tronco torce 42° (antes 30°). Assim o golpe desenha arco com a mão, em vez de compasso.
- A ação secundária (lenço, saia, caixote, snorkel, pés de pato, chapéu, balde e estopa) já vinha das molas da v1. Ela aparece no clipe, mas é sutil nas poses paradas da folha.

### Defeito da v1 achado no caminho

O Bucho da recepção nunca aparecia boiando, nem na v1. A cambalhota somava 0,7 rad em `rotation.x` a cada 3 quadros. Depois de 90°, o Godot decompõe o Euler de outro jeito e põe π em Y e Z. Quando a rotação X voltava a 0, o Bucho ficava de cabeça para baixo, dentro da água. Agora a rotação é composta pela base (yaw × giro) e o Bucho cai um pouco mais longe (2,15 m), na frente da viga. No clipe, ele boia de olho arregalado depois da coroa, como a história pede.

### 10. Composição do quadro bonito (corrigido)

- A câmera está 15% mais perto e mais baixa, com a Marola no terço direito e o horizonte dentro do quadro.
- Há contraluz quente, vinheta leve de valor (`shaders/vinheta.gdshader`) e um Bucho escuro em primeiro plano desfocado por DOF de perto (`CameraAttributesPractical`).
- O piso calmo já faz a clareira atrás dela.

## Portões no `stress.png` (Compatibility), v1 → v2

| Portão | v1 | v2 | Passa? |
|---|---|---|---|
| Cinza: ΔL OKLab dos heróis (mín.) | 0,185 | **0,224** | sim |
| Cinza: inimigos (mediana) | 0,246 | **0,312** | sim |
| Borrão de 4 px: heróis (mín. / mediana) | 0,140 / 0,147 | **0,126** / 0,151 | sim (mín. ≥ 0,12) |
| Borrão de 4 px: inimigos (mediana) | 0,153 | **0,182** | sim |
| Miniatura 320×180: altura dos heróis | 27 a 59 px | 34 a 66 px | sim |
| Anéis dos 4 jogadores, ΔE mínimo (normal / deuteranopia / protanopia) | 0,113 / 0,055 / 0,065 | 0,109 / **0,052** / 0,054 | sim, por pouco; o símbolo segura |

**A única piora é o borrão mínimo dos heróis (0,140 → 0,126)**. É a Marola, agora virada para a câmera. De costas ela media 0,155, porque o caixote e a saia escura ficavam para cima. De frente, o lenço amarelo 1,3× maior fica próximo do valor do piso claro. Escolhi mostrar o rosto: o portão passa, mas com margem pequena. Escurecer o lenço resolveria, só que o lenço é a marca dela.

Em deuteranopia, o urucum da Marola, o verde do Remanso e o amarelo das telegrafias caem todos num amarelo parecido (veja `portoes.png`). Isso já acontecia na v1. Quem segura a leitura são o símbolo do anel e o recorte. Trocar a cor de um jogador mexe no conceito, por isso fica como pendência.

Também medi, com 7 golpes, a colisão da arma (`colisao.json`): **0 violações**. A paridade entre os renderers no estresse dá diferença média de **4,8/255** (era 5,7), com 22% dos pixels acima de 8.

## O que não deu para corrigir, e por quê

- **"Além de triple A" continua fora de alcance.** É um 3D toon estilizado com acabamento de indie bom. Há uma luz só, sem luz rebatida pintada nem oclusão.
- **Corpos ainda de lofts facetados.** O afunilamento e as luvas tiram a cara de caixa, mas não há escultura: cotovelo e joelho são tarugos à mostra, de propósito (é brinquedo de miriti), e as mãos ainda são blocos. Um artista com Blender faria em uma tarde o que o código não faz bem: volumes de rosto (nariz, bochecha, queixo) e mãos com gesto.
- **Desgaste branco em todos os membros.** A tinta que falha nas arestas deixa riscos creme em braços e pernas que, na folha de modelo, parecem um pouco repetitivos. Não mexi porque isso muda a leitura do material em todo o resto.
- **O olho do Bucho de perfil** fica um pouco para fora do corpo, porque é um quad inclinado para a câmera. De cima, que é o que importa, ele lê bem.
- **Ação secundária e arco de membro** foram melhorados nas poses-chave e na respiração, mas não há quadros de quebra (breakdowns) com arrasto (drag) nos membros em todas as ações. Seria preciso reanimar o malho e o arremesso pose a pose.
- **O fio de contorno colorido** ficou desligado pelo motivo do item 7.
- **Desempenho real não foi medido.** São 148 draw calls por software no estresse, ainda acima do teto de 100 a 150 proposto para a Web. As lascas são uma malha cada e precisariam de MultiMesh.
- **Partes do conceito que não foram feitas**: a Tralha Grande em uso (a âncora só está no cenário), a Fisgada, o Mural de verdade (a lasca só voa para o canto), o som e a distorção de tela do nível PC.

## Código

Fica em `/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/provas/tralha-da-cheia/`. Na v2 foram mudados `malha.py` (`Builder.xf`), `bonecos.py`, `poses.py`, `cenario.py`, `paleta.py`, `main.gd`, `vfx.gd`, `cenario.gd`, `boneco.gd`, os shaders `miriti`, `olho` e `perigo`, e foi criado o `vinheta`.

Ferramentas (`tools/`):

- `paleta.py`: paleta mestra, agora com 25 cores;
- `malha.py`: Builder de peças, com transformação por osso;
- `pintura.py`: atlas por faceta e pintura em numpy;
- `bonecos.py`: heróis, Inchados e armas;
- `poses.py`: poses e ações, com respiração;
- `animar.py` e `exportar.py`: animação e exportação;
- `cenario.py`: cenário;
- `portoes.py`: portões;
- `folha_modelo.py` e `folha_clip.py`: folhas;
- `run.sh`, `check.sh` e `codificar.sh`: execução, checagem e codificação.

Motor (`proj/`):

- `main.gd`: cenas `folha`, `poses`, `duelo`, `estresse` e `colisao`. Argumentos novos: `pitch`, `rim`, `rim_amt`, `fio`, `lata`, `fg_*`, `dof_*`, `contraluz`, `cl_az`, `vinheta`, `myaw` e `pz`;
- `boneco.gd`, `mola.gd`, `cenario.gd` e `vfx.gd`;
- `shaders/`.

Comandos da v2 (a partir da pasta da prova):

- modelos: `cd tools && python3 exportar.py ../proj` (cerca de 40 s) e `python3 cenario.py ../proj` (cerca de 70 s);
- quadro bonito: `tools/run.sh fplus 1920x1080 entrega/beauty.png cena=duelo beauty=1 pc=1 quadro=58 dist=7.4 pitch=28 tx=-0.7 ty=1.05 tz=0.6 yaw=-6 az=-100 el=38 coroa_f=49 cx=-2.0 msaa=4 sol_e=0.9 lata=0 fg_x=-2.5 fg_z=2.85 fg_yaw=25 dof_amt=0.3 dof_perto=6.3 dof_trans=0.8 contraluz=0.7`
- estresse: `tools/run.sh compat 1280x720 entrega/stress.png cena=estresse frames=4 pitch=31 tz=0.5`. Para os portões, acrescente `mascara=1` e `mascara=aneis` e rode `python3 tools/portoes.py`;
- clipe: `EXTRA="--write-movie <caminho absoluto>/out/clip7/q.png" tools/run.sh fplus 1920x1080 out/clip7_run.png cena=duelo pc=1 frames=252 dist=8.7 pitch=28 tx=-0.1 ty=0.75 tz=1.9 yaw=-6 az=-100 el=40 msaa=4 sol_e=0.92` e depois `tools/codificar.sh out/clip7 entrega/clip`;
- folha de modelo:
  - `cena=folha who=marola,piaba cy=0.8` a 2400×700;
  - `who=remanso,breu cy=0.95` a 2400×700;
  - `who=bucho,gaiola cy=0.45 pitch=14` a 2400×520;
  - `cena=poses ... yaw=60 dx=1.65 cy=0.8` a 2400×520;
  - todas com `bg=#e6d9bd`, seguidas de `python3 tools/folha_modelo.py out/v2 entrega/modelo.png`;
- colisão: `tools/run.sh compat 640x360 out/v2/colisao.png cena=colisao frames=3`.

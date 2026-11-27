# Notas de coleta — biblioteca de sons do Plumbdeep

## Resumo

- **337 arquivos .ogg** em `biblioteca/` (42 MB), **79 eventos**, 11 categorias. Todos são gravações reais ou sons desenhados por estúdios e autores; não há nenhum som procedural gerado por mim.
- Tudo vem do **OpenGameArt.org**. São 56 pacotes, com licença **CC0, CC-BY 3.0, CC-BY 4.0 ou OGA-BY 3.0**. Não usei nada com NC, ND ou SA. Os créditos estão em `CREDITOS.md`, e o catálogo com a origem de cada camada em `catalogo.json`.
- Formato: Ogg Vorbis q6 a 48 kHz. Efeitos pontuais e emissores posicionais (lanterna, fungos, fervura, zumbido elétrico) são mono. Ambientes, música e jingles são estéreo.
- Picos: todos os arquivos ficam **≤ -1 dBTP**, medidos depois da codificação com sobreamostragem 4x. Pior caso: -1,07 dBTP.
- Testei a importação no Godot 4.7.2 headless (`--audio-driver Dummy`): os 337 arquivos carregam como `AudioStreamOggVorbis`, sem falhas.

## Onde procurei e o que ficou de fora

- **Pixabay e Kenney:** não acessei. Os dois bloqueiam download automático com verificação anti-robô, e eu não tentei contornar. Freesound também ficou de fora, porque exige chave de API.
- **OpenGameArt:** listei as buscas de Sound Effect e Music ordenadas por favoritos (três páginas de 144 em SFX e uma de Music). Também fiz buscas por palavra-chave: cave, rope, chain, winch, electric, thunder, waterfall, drip, wind, torch, slime, bubble, boil, footstep, mud, whoosh, swing, wood, stone, coin, bag, growl, creature, drone, dark ambient, dungeon, underground e abyss.
- **GitHub e Hugging Face:** não precisei. O OGA cobriu quase todos os eventos com material melhor documentado.
- **Download:** baixei 96 pacotes (cerca de 1,3 GB extraídos) para `bruto/<pacote>/`. Os arquivos compactados estão em `zips/` e não os apaguei, porque o disco tem folga.
- **Análise:** passei os 2.925 arquivos por `scripts/analisa.py` (ffprobe + numpy). O resultado está em `analise.json` e mede:
  - formato, taxa e bits;
  - pico e trechos de clipping (≥ 3 amostras seguidas no pico);
  - piso de ruído (percentil 10 do RMS em janelas de 20 ms);
  - faixa dinâmica, silêncio inicial e final;
  - centroide espectral, banda efetiva e energia abaixo de 150 Hz;
  - offset DC.

## Critérios de qualidade

Como não posso ouvir, escolhi com base nestas evidências:

1. **Reputação e origem.** Dei preferência a bibliotecas de estúdio ou de gravação profissional:
   - Still North Media (192 kHz/24 bits);
   - Little Robot Sound Factory (WAV 24 bits/48 kHz);
   - Jan Schupke/"Vehicle" (44,1/16, sem processamento);
   - bart (32 bits float);
   - Ogrebane e artisticdude (24 bits);
   - Michel Baradari (apollo-music.de);
   - leohpaz (24 bits);
   - JC Sounds.
2. **Formato.** Só 44,1/48/96/192 kHz com 16, 24 ou 32 bits. Descartei tudo que é 8 bits, chiptune ou 22 kHz, como os pacotes "8-bit" e "512 Sound Effects".
3. **Ruído.** Descartei arquivos com piso de ruído alto em relação ao sinal. Por exemplo, os passos de pedra "Fantozzi" têm piso de -33 a -40 dB e foram descartados.
4. **Clipping.** Descartei arquivos com clipping ou com picos acima de 0 dBFS na decodificação de Vorbis:
   - **StarNinjas** (impactos e espadas): picos de +3 a +12 dBFS.
   - **ljudbank "impactwood"**: de 9 a 103 trechos de clipping em vários arquivos, e no espectrograma são texturas longas de madeira quebrando, não pancadas.
   - **Darsycho** (snarls, troll) e vários arquivos de criatura do rubberduck: milhares de amostras acima de 1,0.
5. **Banda.** Fontes MP3 ou Vorbis com corte em 15–16 kHz entraram só como apoio. Caso a caso:
   - Os pacotes do **rubberduck** são Vorbis a 48 kHz com corte em cerca de 15,6 kHz. Usei apenas lama (2), corrente (3), gosma (3), borbulha (1), rangido (2) e fervura (1).
   - A "ljudbank" (`hit*.mp3.flac`) vem de MP3, com corte em 16 kHz. Usei só os golpes de carne sem nenhum trecho de clipping.
6. **Espectrogramas.** Gerei espectrogramas e olhei cada um. Isso mudou decisões:
   - Os swings da Still North Media (machado, lança, katana) são dominados por um estouro de vento de baixa frequência no microfone e têm piso de ruído entre os golpes. **Descartei o machado para a viga.** Mantive adaga e katana com um expansor descendente, que coloca o ruído 42 dB abaixo do pico, e corte justo do silêncio.
   - A "ljudbank impactwood" foi trocada por madeira contra concreto (bart, 32 bits) mais o baque de corpo no chão (dklon).
   - Na `elite_rugido_2` (LRSF Monster_02), o espectrograma mostra um bloco de amplitude constante, provavelmente muito comprimido. Ela ficou na biblioteca, mas inimigos e whooshes passaram a ser normalizados por loudness, e não por pico, para que um rugido comprimido não fique mais alto que os outros.

## Tratamento (`scripts/construir.py` + `scripts/receita.py`)

Cada variação é uma ou mais **camadas de gravação real**. As operações possíveis são:

- corte automático por ataque (`fatia`) ou por tempo;
- varispeed em semitons, para dar peso;
- passa-alta e passa-baixa;
- expansor;
- inversão;
- ganho e deslocamento entre camadas.

Depois disso, o script:

1. remove o silêncio inicial (limiar de -45 dB em relação ao pico, deixando 2 ms antes do ataque);
2. corta a cauda (-58 dB) e aplica fade quadrático;
3. normaliza e codifica;
4. mede de novo e corrige se o pico verdadeiro passar do alvo.

Os laços (ambientes e loops) ganham um crossfade de potência constante entre o fim e o começo, para emendar sem estalo.

Alvos de normalização:

| Categoria | Alvo |
|---|---|
| Impactos, carne, magia | pico -1 dBTP |
| Whooshes | -21 a -24 LUFS (viga mais alta, punhal mais baixo) |
| Passos | pico -6 dBTP (pesados: -4) |
| Interface | pico -6/-9 (jingles: -3) |
| Inimigos | -18 LUFS, teto de -1,5 dBTP |
| Ambientes | -26 LUFS integrado |
| Música | -20 LUFS |

Exceções nos alvos de loudness: `exploracao_2/3` ficaram em cerca de -22 LUFS e `amb_goteiras_1` e `lanterna_crepitar_2` mais baixos. Nos quatro casos, o teto de pico verdadeiro de -1,5 dBTP impediu de subir mais (são sons com picos isolados).

O `catalogo.json` traz, para cada arquivo: duração, **`pico_em_s`** (instante do pico), LUFS, pico em dBFS e dBTP, e a origem de cada camada (pacote, autor original, página, licença, URL da licença, arquivo original e tratamento).

## Como usar no jogo (ritmo e peso)

- **Golpe pesado da viga:**
  1. `viga_whoosh`, posicionado de forma que o `pico_em_s` caia 1 a 2 quadros antes do contato;
  2. no quadro de contato, `viga_impacto` + `carne_pesado` (ou `pa_pancada`/`osso_quebra`) + `peso_thump`;
  3. o hit-stop começa junto com o thump.

  O silêncio inicial foi removido de todos os arquivos (o primeiro ataque começa cerca de 2 ms depois do início). Alguns sons têm mais de um ataque (por exemplo, `osso_quebra_1`, com pico em 0,35 s); use o `pico_em_s` do catálogo para alinhar.
- **Punhal:** `punhal_whoosh` (0,2 a 0,45 s, seco) + `punhal_corte`/`punhal_metal`. Não use thump.
- **Variação:** use um `AudioStreamRandomizer` por evento, com todas as variações, `random_pitch` de cerca de 1,06 (±6%) e `random_volume_offset_db` de cerca de 1,5. Evite repetir a mesma variação seguida (modo "random no repeats").
- **Personagens pesados:** use os eventos `*_pesado` (pedra, água, madeira, aterrissagem). Para lama pesada, toque `passo_lama` com pitch de 0,85.
- **Emissores posicionais** (mono, em laço): `lanterna_crepitar`, `fungos_zumbido`, `fervura_laco`, `raio_zumbido_agua`.
- **Camadas de ambiente** (estéreo): `amb_caverna_base` + `amb_abismo_respiracao` + `amb_goteiras`, com `gota_eco` em pontos aleatórios. Cascata e rio por proximidade.

## Lacunas e limites honestos

- **Não ouvi nada.** A seleção se baseia em métricas, espectrogramas e reputação. Coisas que só se confirmam ouvindo: o timbre combina com dark fantasy? Os rugidos soam caricatos? As músicas combinam entre si? Os laços têm "padrão" perceptível? **Recomendo uma passada de escuta** para cortar as variações mais fracas. O catálogo facilita trocar por outra fonte.
- **Estalo de corda arrebentando:** sem fonte boa. `corda_chicote` (corda de pular cortando o ar e batendo) é um substituto provisório.
- **Arrasto de viga de madeira em pedra:** `viga_arrasto` usa metal e ferramentas arrastadas em concreto, com varispeed para o grave. É aceitável, mas não é madeira.
- **Turíbulo:** só há chocalho de corrente e cota de malha. Falta o balanço do incensário com fumaça; dá para somar um whoosh leve no jogo.
- **Rolamento** (corpo rolando na pedra): não há. `esquiva` (tecido em movimento rápido, Vinrax) cobre a esquiva.
- **Floração e fungos:** são soluções de design, não gravações do fenômeno. Floração = couro esticado com varispeed grave + textura úmida. Fungos = hum de cristal (JC) e laço elétrico grave filtrado (LRSF).
- **Ouvidor:** guinchos agudos e rosnados genéricos. Faltam sons de "orelha em leque" abrindo ou farejando; um couro sacudido (Vehicle, `quiver-leather-squeeze`) pode servir.
- **Elevador:** há catraca, corrente de guincho, rangido de roldana e trava, mas falta um motor ou zumbido contínuo de roldana. Dá para encadear `guincho_corrente`.
- **JC Sounds** (CC-BY 4.0, três pacotes muito usados: passos, cordas, rangidos, ambientes, magia elétrica, espadas pesadas): o autor é recente no OGA e descreve o material como "professionally crafted", sem dizer como foi gravado ou sintetizado. Não consigo verificar se é material original. A licença foi declarada por quem publicou. Além disso, o FLAC da cascata (Nature Pack) mostra uma queda de cerca de 31 dB em 16 kHz, sinal de origem com perda ou filtro; por isso há alternativas de outros autores em `amb_cascata`. **Se o projeto quiser risco mínimo, estes são os primeiros a revisar.**
- **Origem de terceiros, declarada por quem publicou:**
  - **ljudbank:** apresentada como CC0 pelo qubodup, a partir de independent.nu.
  - **Medieval:** "CC0 no rights reserved", segundo o texto da Still North Media citado na página.
  - **Yo Frankie!:** sons do Blender Foundation (CC-BY 3.0), publicados por Lamoot.
- **Música:** as faixas escolhidas pela descrição e pelo espectro são "Caves of Sorrow", "Forgotten tombs", "Dungeon Ambience", "Enshadowment", "Abyss", "Bleeding out" e "Cold Silence". Não consigo julgar a qualidade musical. "Forgotten tombs" só existe em MP3 (banda de 18 kHz).
- **Licenças com várias opções:** "Bleeding out" (HaelDB) usada como CC0 e "12 Player Movement" (leohpaz) como CC-BY 4.0.

## Reprodutibilidade

`scripts/oga_meta.py` (metadados e licenças das páginas) → `scripts/dl.sh` (download) → `scripts/analisa.py` (métricas) → `scripts/receita.py` + `scripts/construir.py` (biblioteca) → `scripts/finalizar.py` (`catalogo.json` e `CREDITOS.md`) → `scripts/espectro.py` (PNGs em `espectros/`; `espectros/triagem/` mostra as fontes descartadas).

## Segunda etapa: desenho em camadas e integração

Detalhes em `INTEGRACAO.md`. Resumo do que mudou na biblioteca:

- **`biblioteca/compostos/`:** 65 golpes assados em camadas, feitos só com arquivos desta biblioteca:
  - os combos das quatro classes (leve e final);
  - a recepção do Prumo e o golpe de recepção;
  - a reação Corrente.

  Cada composto tem transiente + corpo + cauda + sub, com atrasos de 3 a 140 ms e variação de pitch de ±3,5 %. Eles estão no `catalogo.json` com a camada de origem (arquivo, papel, atraso, pitch, ganho) e os créditos de cada fonte. A normalização foi por loudness momentâneo máximo, com limitador de pico (até 4 dB) a −1,3 dBTP.
- **`ganho_db` por arquivo** no `eventos.json`, para efeitos pontuais. A coleta normalizou por pico, então dentro de um grupo as variações densas soavam até cerca de 9 dB mais altas que as secas (por exemplo, `punhal_corte` vai de −27,4 a −18,0 LUFS). O ganho puxa as mais altas para baixo, até −6 dB.
- **`ataque_em_s` por arquivo** no `eventos.json`: primeira amostra a 12 dB do pico, ou seja, o instante que deve cair no quadro de contato. Fica ao lado do `pico_em_s`, usado para alinhar os sopros.
- **Scripts novos:**
  - `scripts/motor.py`: mixagem offline com a mesma lógica do `som.gd`;
  - `scripts/compor.py`: desenho dos eventos, compostos e `eventos.json`;
  - `scripts/demo.py` e `scripts/demo_folha.py`: trilha de demonstração;
  - `scripts/trilha_do_log.py`: trilha de clipe a partir do log de eventos.

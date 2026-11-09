class_name Lang
## Idiomas do jogo: português (o texto escrito no código é a chave) e inglês (tabelas abaixo).
## O LangTr entrega a tradução ao Godot, então Labels e botões traduzem sozinhos, inclusive os textos
## montados no código ("VOLTA 2", "CORISCO destruiu VOCÊ", "MUNDO 2 · DUNAS ALTAS"):
##   1) frase exata (também a versão em MAIÚSCULAS de cada frase);
##   2) formato: "VOLTA %d" vira uma expressão regular; os %s capturados são traduzidos de novo;
##   3) pedaços: o texto é quebrado em "\n", " · ", ": " ... e cada pedaço é traduzido.
## Em inglês, "1º" vira "1st". Textos desenhados à mão (draw_string) chamam Lang.t().

## o idioma vale pelo locale do TranslationServer (sobrevive à recarga do script entre a abertura e o jogo)
static var code: String:
	get:
		return "en" if en() else "pt"
static var _exact := {}
static var _fmt: Array = []     # [RegEx, modelo em inglês, tipos dos grupos, trecho fixo mais longo]
static var _cache := {}
static var _letter: RegEx
static var _ord: RegEx

## frases exatas
const EN := {
	# --- abertura, menu, telas
	"LIGANDO OS MOTORES": "STARTING ENGINES", "CARREGANDO": "LOADING", "CARREGANDO PISTA": "LOADING TRACK",
	"CARREIRA": "CAREER", "CORRIDA RÁPIDA": "QUICK RACE", "Configurações": "Settings", "Sair": "Quit",
	"SEU CARRO": "YOUR CAR", "NA GARAGEM": "IN THE GARAGE", "VOLTAR": "BACK",
	"PAUSA": "PAUSED", "CONTINUAR": "RESUME", "REINICIAR": "RESTART", "CONFIGURAÇÕES": "SETTINGS",
	"SAIR DA CORRIDA": "QUIT RACE", "GARAGEM": "GARAGE", "DE NOVO": "RETRY", "DECIBEL  ·  AO VIVO": "DECIBEL  ·  LIVE",
	"DIREÇÃO": "STEERING", "DIREÇÃO: TELA": "STEERING: SCREEN", "DIREÇÃO: CARRO": "STEERING: CAR",
	"APONTA NA TELA": "POINT ON SCREEN", "GIRA O CARRO": "TURN THE CAR",
	"COMPRAR?": "BUY?", "CANCELAR": "CANCEL", "COMPRAR": "BUY", "  · DESTRUÍDO": "  · WRECKED",
	"CAMPEÃO DO WRECK 'N' ROLL!": "WRECK 'N' ROLL CHAMPION!",
	# --- HUD da corrida
	"CONTRAMÃO!": "ONCOMING!", "SENTIDO ERRADO! VIRE": "WRONG WAY! TURN AROUND", "VAI!": "GO!",
	"LARGADA PERFEITA!": "PERFECT START!", "ÚLTIMA VOLTA!": "FINAL LAP!", "MUNIÇÃO E NITRO RECARREGADOS": "AMMO AND NITRO RELOADED",
	"DE VOLTA AO SENTIDO CERTO": "BACK ON COURSE", "POR UM TRIZ!": "BY A HAIR!", "QUASE!": "CLOSE CALL!",
	"VOLTANDO À PISTA": "BACK TO THE TRACK", "CAIU! VOLTANDO": "FELL OFF! RESPAWNING", "30 s PARA TERMINAR!": "30 s TO FINISH!",
	"TODOS OS RIVAIS TERMINARAM": "ALL RIVALS HAVE FINISHED", "CAIU!": "FELL OFF!", "DESTRUÍDO!": "WRECKED!",
	"A PISTA": "THE TRACK", "VOCÊ": "YOU", "CHEFE DESTRUÍDO!": "BOSS WRECKED!", "ele volta em instantes...": "back in a moment...",
	"TRÂNSITO!": "TRAFFIC!", "DESTRUIU!": "WRECKED!", "MUNIÇÃO!": "AMMO!", "REPARO!": "REPAIR!",
	"VITÓRIA!": "VICTORY!", "TEMPO": "TIME", "MELHOR VOLTA": "BEST LAP", "DESTRUÍDOS": "TAKEDOWNS",
	"MAIOR DRIFT": "LONGEST DRIFT", "MAIOR PULO": "BIGGEST AIR", "CHEFE DERROTADO": "BOSS DEFEATED",
	"não terminou": "did not finish", "  (você)": "  (you)", "ENFRENTAR CHEFE": "FIGHT THE BOSS",
	"PRÓXIMO MUNDO": "NEXT WORLD", "PRÓXIMA CORRIDA": "NEXT RACE", "TENTAR DE NOVO": "TRY AGAIN",
	"FREIO": "BRAKE", "LÍDER": "LEADER",
	# --- chefes: avisos dos ataques
	"TREMOR! SAIA DO CÍRCULO": "QUAKE! GET OUT OF THE CIRCLE", "BARRIS GIGANTES!": "GIANT BARRELS!",
	"ÍMÃ! PULE, USE ESCUDO OU SE AFASTE": "MAGNET! JUMP, SHIELD UP OR BREAK AWAY",
	"BLOQUEIO À FRENTE! PROCURE A BRECHA": "ROADBLOCK AHEAD! FIND THE GAP", "LAMA! DESVIE DAS POÇAS": "MUD! DODGE THE PUDDLES",
	"BOTE! SAIA DA FAIXA": "STRIKE! GET OUT OF THE LANE", "BOLAS DE NEVE! FIQUE NA FAIXA LIVRE": "SNOWBALLS! STAY IN THE CLEAR LANE",
	"GELO À FRENTE! NÃO ACELERE NA CURVA": "ICE AHEAD! EASE OFF IN THE CORNER", "PULSO EMP! SE AFASTE DELE": "EMP PULSE! KEEP YOUR DISTANCE",
	"PORTÕES LASER! PASSE QUANDO APAGAREM": "LASER GATES! GO WHEN THEY SWITCH OFF", "METEOROS! DESVIE DOS CÍRCULOS": "METEORS! DODGE THE CIRCLES",
	# nomes dos ataques (tirados da descrição do chefe)
	"TREMOR": "QUAKE", "BARRIS": "BARRELS", "BOTE": "STRIKE", "ÍMÃ": "MAGNET", "BLOQUEIO": "ROADBLOCK",
	"BOLAS DE NEVE": "SNOWBALLS", "PULSO EMP": "EMP PULSE", "PORTÕES LASER": "LASER GATES", "METEOROS": "METEORS",
	"MURO DE FOGO": "WALL OF FIRE",
	# --- efeitos das armas
	"MINA!": "MINE!", "ÓLEO!": "OIL!", "ESCORREGOU!": "SPUN OUT!", "PREGOS!": "SPIKES!", "PNEU FURADO!": "FLAT TIRE!",
	"BARRIL!": "BARREL!", "SALTO!": "JUMP!", "ESCUDO!": "SHIELD!", "ONDA DE CHOQUE!": "SHOCKWAVE!", "ESQUIVA!": "DODGE!",
	"PLANANDO!": "GLIDING!", "INVESTIDA!": "RAM!", "EMP! ARMAS DESLIGADAS": "EMP! WEAPONS OFFLINE", "VÓRTICE!": "VORTEX!",
	"ATOLOU!": "BOGGED DOWN!", "GELO!": "ICE!", "PNEU FURADO! USE A BRECHA": "FLAT TIRE! USE THE GAP",
	"ARPOADO!": "HARPOONED!", "CONGELADO!": "FROZEN!",
	# --- equipamentos
	"ESCUDO": "SHIELD", "Escudo": "Shield", "Onda de choque": "Shockwave", "CHOQUE": "SHOCK", "REPARO": "REPAIR", "Reparo": "Repair",
	"Metralhadora": "Machine gun", "Lança-foguetes": "Rocket launcher", "Raio elétrico": "Lightning gun", "Lança-chamas": "Flamethrower",
	"Canhão laser": "Laser cannon", "Arpão": "Harpoon", "Morteiro": "Mortar", "Canhão de gelo": "Freeze cannon",
	"Canhão de trilho": "Railgun",
	"TIRO": "GUN", "FOGUETE": "ROCKET", "RAIO": "ZAP", "FOGO": "FIRE", "ARPÃO": "HARPOON", "MORTEIRO": "MORTAR",
	"GELO": "ICE", "TRILHO": "RAIL", "MINA": "MINE", "ÓLEO": "OIL", "PREGOS": "SPIKES", "BARRIL": "BARREL",
	"FUMAÇA": "SMOKE", "LAMA": "MUD", "VÓRTICE": "VORTEX",
	"Minas": "Mines", "Óleo": "Oil", "Pregos": "Spikes", "Barril rolante": "Rolling barrel", "Cortina de fumaça": "Smoke screen",
	"Poça de lama": "Mud puddle", "Rastro de fogo": "Fire trail", "Placa de gelo": "Ice slick", "Mina EMP": "EMP mine",
	"Vórtice": "Vortex", "Nitro curto": "Short nitro", "Nitro longo": "Long nitro", "SALTO": "JUMP", "Salto": "Jump",
	"INVESTIDA": "RAM", "Investida": "Ram", "ESQUIVA": "DODGE", "Esquiva": "Dodge", "PLANAR": "GLIDE", "Planar": "Glide",
	"Rajada contínua de balas.": "A non-stop stream of bullets.",
	"Foguete teleguiado no alvo da frente.": "Homing rocket that locks onto the car ahead.",
	"Raio instantâneo que salta para um 2º carro.": "Instant bolt that arcs to a second car.",
	"Jato curto que incendeia (dano contínuo).": "Short jet that sets cars ablaze (damage over time).",
	"Mancha que faz rodopiar.": "A slick that sends cars spinning.",
	"Explode quando alguém passa.": "Blows up when someone drives over it.",
	"Furam os pneus: o carro fica lento.": "They pop tires: the car slows to a crawl.",
	"Barril rola para trás e explode.": "A barrel rolls backwards and explodes.",
	"Arrancadas curtas e fortes (4 por volta).": "Short, strong bursts (4 per lap).",
	"Arrancadas longas (3 por volta).": "Long bursts (3 per lap).",
	"Pula minas, óleo e carros (3 por volta).": "Hop over mines, oil and cars (3 per lap).",
	"Arrancada que atropela e arremessa quem estiver na frente.": "A charge that flattens and launches anyone in front.",
	"Feixe contínuo que queima.": "A continuous burning beam.",
	"Fisga o alvo, puxa para trás e segura.": "Hooks the target, drags it back and holds it.",
	"Granada em arco onde o alvo vai estar.": "Lobs a grenade where the target is headed.",
	"Bola de gelo: o alvo escorrega e perde força.": "Ice ball: the target slides and loses power.",
	"Disparo que atravessa todos na linha.": "A shot that pierces everyone in its path.",
	"Rajada de bolas teleguiadas.": "A burst of homing orbs.",
	"Nuvem: ninguém mira em quem está dentro.": "Cloud: nobody can lock onto you inside it.",
	"Poça que atola quem passa.": "A puddle that bogs down whoever drives through.",
	"Chão em chamas atrás de você.": "Burning ground behind you.",
	"Placa lisa: quem passa derrapa.": "Slick plate: whoever drives over it skids.",
	"Mina que desliga armas e especial.": "A mine that shuts down weapons and special.",
	"Redemoinho que puxa e segura.": "A whirlwind that pulls cars in and holds them.",
	"Salto lateral rápido para desviar.": "A quick sideways hop to dodge.",
	"Impulso e voo planado por 1,8 s.": "A boost and a 1.8 s glide.",
	"3 s invulnerável + aríete.": "3 s invulnerable + battering ram.",
	"Arremessa e machuca quem está perto.": "Blasts away and hurts anyone close by.",
	"Devolve 40% da blindagem e apaga o fogo.": "Restores 40% armor and puts out fire.",
	# --- carros
	"FAÍSCA": "SPARK", "VESPA": "HORNET", "TROVÃO": "THUNDER", "MONSTRO": "MONSTER", "ZÉFIRO": "ZEPHYR",
	"JACARÉ": "GATOR", "ESCORPIÃO": "SCORPION", "NEVASCA": "BLIZZARD", "NÊMESIS": "NEMESIS", "FALCÃO": "FALCON",
	"ESPORTIVO": "SPORTS CAR", "Equilibrado e rápido no nitro.": "Balanced and quick on nitro.",
	"HATCH DE RALLY": "RALLY HATCH", "Buggy leve: o mais ágil, salta obstáculos.": "Light buggy: the most agile, jumps over obstacles.",
	"MUSCLE BLINDADO": "ARMORED MUSCLE", "Muscle car blindado: foguetes e nitro longo.": "Armored muscle car: rockets and long nitro.",
	"PICAPE MONSTRO": "MONSTER PICKUP", "Picape pesada: fogo, barris e investida.": "Heavy pickup: fire, barrels and ram.",
	"GT ELÉTRICO": "ELECTRIC GT", "GT elétrico: laser, fumaça e esquiva lateral.": "Electric GT: laser, smoke and side dodge.",
	"SUV ANFÍBIO": "AMPHIBIOUS SUV", "SUV anfíbio: arpão, lama e nitro longo.": "Amphibious SUV: harpoon, mud and long nitro.",
	"Trophy truck: morteiro, fogo e salto.": "Trophy truck: mortar, fire and jump.",
	"SUV DE NEVE": "SNOW SUV", "SUV de neve: canhão de gelo e placas de gelo.": "Snow SUV: freeze cannon and ice slicks.",
	"HIPERCARRO": "HYPERCAR", "Hipercarro: canhão de trilho, mina EMP e esquiva.": "Hypercar: railgun, EMP mine and dodge.",
	"AEROCARRO": "AEROCAR", "Aerocarro: plasma, vórtice e voo planado.": "Aerocar: plasma, vortex and gliding.",
	# rivais
	"CORISCO": "BOLT", "JARARACA": "VIPER", "FAGULHA": "EMBER", "ARRAIA": "STINGRAY", "DUNA": "DUNE", "ROLO": "ROLLER",
	"BRUTA": "BRUTE", "GEADA": "FROST", "CRISTAL": "CRYSTAL", "BRASA": "BLAZE", "BRISA": "BREEZE", "SUCURI": "ANACONDA",
	"MIRAGEM": "MIRAGE", "GLACIAL": "GLACIER", "TURBINA": "TURBINE",
	# --- carreira: mundos e chefes
	"PARQUE": "PARK", "BRUTUS, O ROLO": "BRUTUS THE ROLLER", "PÂNTANO": "SWAMP", "CROCODILO DO BREJO": "BOG CROCODILE",
	"DESERTO": "DESERT", "XERIFE DE AÇO": "STEEL SHERIFF", "NEVE": "SNOW", "CIDADE NEON": "NEON CITY",
	"CÉU": "SKY", "O IMPERADOR": "THE EMPEROR",
	"Hipercarro elétrico blindado gigante. TREMOR: marca um círculo onde você vai passar e explode o chão. BARRIS: rola barris gigantes para trás.":
		"A giant armored electric hypercar. QUAKE: marks a circle where you're about to drive and blows up the ground. BARRELS: rolls giant barrels backwards.",
	"Picape-crocodilo gigante. LAMA: cospe poças que atolam o carro e sujam a tela. BOTE: marca uma faixa da pista e dá um bote lateral nela.":
		"A giant crocodile pickup. MUD: spits puddles that bog your car down and splatter the screen. STRIKE: marks a lane of the track and lunges sideways into it.",
	"Viatura colossal. ÍMÃ: um raio te puxa para perto e segura sua velocidade. BLOQUEIO: fileira de pregos na pista com uma brecha.":
		"A colossal police cruiser. MAGNET: a beam pulls you in and holds your speed. ROADBLOCK: a row of spikes across the track with one gap.",
	"Trophy truck da neve. BOLAS DE NEVE: rola bolas gigantes pela pista contra você (faixas avisadas). GELO: transforma um trecho em gelo liso.":
		"A snow trophy truck. SNOWBALLS: rolls giant snowballs down the track at you (lanes are flagged). ICE: turns a stretch of road into slick ice.",
	"Sedã hacker. PULSO EMP: anel que desliga suas armas e o especial por 3 s. PORTÕES LASER: barreiras que ligam e desligam na pista.":
		"A hacker sedan. EMP PULSE: a ring that shuts down your weapons and special for 3 s. LASER GATES: barriers that switch on and off across the track.",
	"Muscle car dourado. METEOROS: círculos vermelhos caem do céu à sua frente. MURO DE FOGO: deixa a pista em chamas atrás de si.":
		"A golden muscle car. METEORS: red circles rain down from the sky ahead of you. WALL OF FIRE: leaves the track in flames behind it.",
	"CAMPEÃO": "CHAMPION", "CHEFE": "BOSS", "ENFRENTAR": "FIGHT", "VENÇA AS 4": "WIN ALL 4", "PRÓXIMA": "NEXT",
	"O CHEFE CHEGOU ANTES": "THE BOSS GOT THERE FIRST", "CHEGUE NO PÓDIO PARA AVANÇAR": "FINISH ON THE PODIUM TO ADVANCE",
	"CHEFE LIBERADO!": "BOSS UNLOCKED!",
	# --- garagem
	"MOTOR": "ENGINE", "BLINDAGEM": "ARMOR", "PNEUS": "TIRES", "MUNIÇÃO": "AMMO", "DANO": "DAMAGE", "CADÊNCIA": "FIRE RATE",
	"VELOCIDADE": "SPEED", "ACELERAÇÃO": "ACCELERATION", "CONTROLE": "HANDLING", "ATAQUE": "ATTACK", "PEÇAS": "PARTS",
	"ESPECIAL": "SPECIAL", "LARGAR!": "RACE!", "ARMA DE ATAQUE": "ATTACK WEAPON", "NOVO CARRO": "NEW CAR",
	"NOVO CARRO NA GARAGEM": "NEW CAR IN THE GARAGE", "+4% VELOCIDADE E ACELERAÇÃO": "+4% SPEED AND ACCELERATION",
	"+20% BLINDAGEM": "+20% ARMOR", "+6% ADERÊNCIA": "+6% GRIP", "+25% DE DANO": "+25% DAMAGE", "+22% CADÊNCIA": "+22% FIRE RATE",
	"SEM ARMA": "NO WEAPON", "MÁX": "MAX", "NO MÁXIMO": "MAXED OUT", "EQUIPADA": "EQUIPPED", "LIBERADA": "UNLOCKED",
	"EQUIPADO": "EQUIPPED", "USAR": "USE", "SEU": "YOURS", "NOTA": "RATING",
	# --- dicas da tela de carregamento
	"Cada volta recarrega munição e nitro.": "Every lap reloads your ammo and nitro.",
	"Placas de turbo laranja dão um tranco de velocidade.": "Orange boost pads give you a kick of speed.",
	"Manobras (drift, pulos, quase-batidas) enchem o medidor de nitro extra.": "Stunts (drifts, jumps, near misses) fill the bonus nitro meter.",
	"Pneus slick: +12% de aderência em relação aos de rua.": "Slick tires: +12% grip over street tires.",
	"Foguetes perseguem quem está na frente: dá para fugir com nitro.": "Rockets chase whoever is ahead: you can outrun them with nitro.",
	"Mina atrás de você + rival colado = destruição.": "Mine behind you + rival on your tail = wreckage.",
	"No online, a voz fica mais alta quando os carros estão perto.": "Online, voices get louder when cars are close.",
	"Até 4 pessoas na mesma tela: cada uma com seu controle ou metade do teclado.": "Up to 4 players on one screen: each with a controller or half a keyboard.",
	"Preso na mureta? Aperte R (ou BACK no controle) para voltar à pista.": "Stuck on a wall? Press R (or BACK on the controller) to get back on track.",
	# --- multijogador local e online
	"ESPAÇO": "SPACE", "PISTA": "TRACK", "Ninguém entrou ainda!": "Nobody has joined yet!",
	"A corrida já começou nessa sala": "The race has already started in that room", "Sala cheia": "The room is full",
	"seu nome": "your name", "servidor (ex.: ws://192.168.0.10:9080)": "server (e.g. ws://192.168.0.10:9080)",
	"CONECTAR": "CONNECT", "HOSPEDAR AQUI": "HOST HERE",
	"Conecte num servidor de salas (veja o README) ou hospede aqui para jogar na rede local.": "Connect to a room server (see the README) or host here to play on your local network.",
	"CRIAR SALA": "CREATE ROOM", "código": "code", "ENTRAR": "JOIN", "ATUALIZAR": "REFRESH", "IA": "AI", "SAIR DA SALA": "LEAVE ROOM",
	"Não deu para abrir a porta 9080 (já está em uso?)": "Couldn't open port 9080 (is it already in use?)",
	"Conectado! Crie uma sala ou entre numa.": "Connected! Create a room or join one.", "CONEXÃO PERDIDA": "CONNECTION LOST",
	"Nenhuma sala aberta. Crie uma!": "No open rooms. Create one!", "  · FALANDO": "  · TALKING", "[ANFITRIÃO] ": "[HOST] ",
	"COMPLETA O GRID": "FILL THE GRID", "SEM IA": "NO AI",
	"Você é o anfitrião: escolha a pista e largue quando todos estiverem prontos.": "You're the host: pick the track and start when everyone is ready.",
	"Aguardando o anfitrião escolher a pista e largar.": "Waiting for the host to pick the track and start.",
	"TECLADO/CONTROLE": "KEYBOARD/CONTROLLER", "TECLADO (WASD)": "KEYBOARD (WASD)", "TECLADO (SETAS)": "KEYBOARD (ARROWS)",
	"WASD dirige · E tiro · Q mina · Shift nitro · F especial · Espaço freio": "WASD steer · E fire · Q mine · Shift nitro · F special · Space brake",
	"Setas dirigem · . tiro · , mina · / nitro · L especial · Enter freio": "Arrows steer · . fire · , mine · / nitro · L special · Enter brake",
	"Analógico dirige · A/RT acelera · B/LT freio · X tiro · Y mina · RB nitro · LB especial": "Stick steers · A/RT throttle · B/LT brake · X fire · Y mine · RB nitro · LB special",
	"VOZ: DESLIGADA": "VOICE: OFF", "VOZ: MICROFONE ABERTO": "VOICE: OPEN MIC", "VOZ: APERTE V / L3 PARA FALAR": "VOICE: PRESS V / L3 TO TALK",
	# --- configurações
	"BAIXA": "LOW", "MÉDIA": "MEDIUM", "ALTA": "HIGH", "SEM LIMITE": "UNLIMITED", "ÁUDIO": "AUDIO", "VÍDEO": "VIDEO",
	"JOGO": "GAME", "CONTROLES": "CONTROLS", "CRÉDITOS": "CREDITS", "VOLUME GERAL": "MASTER VOLUME", "MÚSICA": "MUSIC",
	"EFEITOS (MOTOR, TIROS, BATIDAS)": "EFFECTS (ENGINE, GUNS, CRASHES)", "NARRADOR (DECIBEL)": "ANNOUNCER (DECIBEL)",
	"VOZ DO NARRADOR": "ANNOUNCER LANGUAGE", "IGUAL AO JOGO": "SAME AS THE GAME", "CHAT DE VOZ": "VOICE CHAT",
	"O chat de voz liga no lobby online ou no menu de pausa.": "Voice chat is switched on in the online lobby or the pause menu.",
	"QUALIDADE GRÁFICA": "GRAPHICS QUALITY",
	"Baixa: sem sombras e sem antisserrilhado (celulares simples). Média: sombras e MSAA 2x. Alta: sombras suaves e MSAA 4x.":
		"Low: no shadows and no anti-aliasing (basic phones). Medium: shadows and 2x MSAA. High: soft shadows and 4x MSAA.",
	"RESOLUÇÃO 3D": "3D RESOLUTION",
	"Menos de 100% desenha o 3D menor e amplia: mais FPS, imagem mais suave.": "Below 100% renders the 3D smaller and scales it up: more FPS, softer image.",
	"TELA CHEIA": "FULLSCREEN", "NÃO": "NO", "SIM": "YES", "VSYNC (SEM CORTES NA IMAGEM)": "VSYNC (NO SCREEN TEARING)",
	"LIGADO": "ON", "DESLIGADO": "OFF", "LIGADA": "ON", "DESLIGADA": "OFF", "LIGADOS": "ON", "DESLIGADOS": "OFF",
	"TAXA DE QUADROS (FPS)": "FRAME RATE (FPS)", "RESOLUÇÃO DINÂMICA": "DYNAMIC RESOLUTION",
	"Na corrida, se a placa de vídeo não der conta da taxa escolhida, o 3D baixa a resolução aos poucos (até 70%) e volta quando sobra folga.":
		"During a race, if the graphics card can't keep up with the chosen frame rate, the 3D resolution drops gradually (down to 70%) and comes back when there is headroom.",
	"120 FPS precisa de tela de 120 Hz (celulares e monitores rápidos). Nos menus o jogo segura em 60 para poupar bateria.":
		"120 FPS needs a 120 Hz screen (fast phones and monitors). In the menus the game holds 60 to save battery.",
	"EFEITOS DE TELA (BORRÃO, ABERRAÇÃO, LINHAS)": "SCREEN EFFECTS (BLUR, ABERRATION, SCANLINES)", "MOSTRAR FPS": "SHOW FPS",
	"TREMOR DA CÂMERA": "CAMERA SHAKE", "VIBRAÇÃO (CELULAR E CONTROLE)": "VIBRATION (PHONE AND CONTROLLER)",
	"Direção TELA: você aponta para onde quer ir na tela. CARRO: esquerda/direita giram o carro (clássico).":
		"SCREEN steering: you point where you want to go on the screen. CAR: left/right turn the car (classic).",
	"TELA": "SCREEN", "CARRO": "CAR", "TECLADO": "KEYBOARD", "Dirigir": "Steer", "Setas / WASD": "Arrows / WASD",
	"Analógico esquerdo / direcional": "Left stick / D-pad", "Acelerar": "Throttle", "automático (modo TELA) · ↑": "automatic (SCREEN mode) · ↑",
	"A ou RT": "A or RT", "Freio / ré": "Brake / reverse", "B ou C": "B or C", "B ou LT": "B or LT", "Tiro / foguete": "Fire / rocket",
	"Z, J ou Ctrl": "Z, J or Ctrl", "Mina / óleo": "Mine / oil", "X ou K": "X or K", "Nitro / mobilidade": "Nitro / mobility",
	"Shift ou N": "Shift or N", "Especial": "Special", "E ou L": "E or L", "Voltar à pista": "Back to the track", "Pausa": "Pause",
	"P ou Esc": "P or Esc", "Falar (voz)": "Talk (voice)", "L3 (aperte o analógico)": "L3 (click the stick)",
	"Multijogador local: teclado WASD (E tiro · Q mina · Shift nitro · F especial · Espaço freio), teclado setas (. tiro · , mina · / nitro · L especial · Enter freio) e um controle por pessoa. Celular: analógico na tela e botões grandes.":
		"Local multiplayer: WASD keyboard (E fire · Q mine · Shift nitro · F special · Space brake), arrow keys (. fire · , mine · / nitro · L special · Enter brake) and one controller per player. Phone: on-screen stick and big buttons.",
	"Loyalty Freak Music e HoliznaCC0 — CC0 (domínio público).": "Loyalty Freak Music and HoliznaCC0 — CC0 (public domain).",
	"SONS (GRAVAÇÕES REAIS)": "SOUNDS (REAL RECORDINGS)",
	"Motores gravados no engine-sim, turbo, batidas e raspadas: CryHam / Stunt Rally 3 — CC-BY 4.0.": "Engines recorded in engine-sim, turbo, crashes and scrapes: CryHam / Stunt Rally 3 — CC-BY 4.0.",
	"Batidas de metal, terra e raspada: Halleck (freesound.org) — CC-BY 4.0. Água e lama: CGEffex — CC-BY 4.0. Turbo: shimsewn — CC-BY 4.0.":
		"Metal, dirt and scrape impacts: Halleck (freesound.org) — CC-BY 4.0. Water and mud: CGEffex — CC-BY 4.0. Turbo: shimsewn — CC-BY 4.0.",
	"Motor elétrico: JotrainG — CC0.": "Electric motor: JotrainG — CC0.",
	"Pneu cantando e pouso: Ya2 / Yorg — CC-BY-SA. Explosão: Michel Baradari — CC-BY 3.0.": "Tire squeal and landing: Ya2 / Yorg — CC-BY-SA. Explosion: Michel Baradari — CC-BY 3.0.",
	"Armas, explosões, estalos e vento: Red Eclipse Team — CC-BY-SA 4.0 (as versões editadas seguem a mesma licença).":
		"Weapons, explosions, clicks and wind: Red Eclipse Team — CC-BY-SA 4.0 (the edited versions keep the same license).",
	"Impactos, interface, fichas e vinhetas: Kenney (kenney.nl) — CC0. Arco e golpes: Battle Sound Effects (OpenGameArt) — CC0.":
		"Impacts, interface, chips and jingles: Kenney (kenney.nl) — CC0. Bow and swishes: Battle Sound Effects (OpenGameArt) — CC0.",
	"Narrador Decibel: voz gerada por IA com o Kokoro-82M (Apache 2.0, hexgrad) via kokoro-onnx (MIT). Guitarra e prato da vinheta: amostras do Sonic Pi (freesound) — CC0.":
		"Decibel the announcer: AI-generated voice made with Kokoro-82M (Apache 2.0, hexgrad) via kokoro-onnx (MIT). Stinger guitar and cymbal: Sonic Pi samples (freesound) — CC0.",
	"Lista completa, arquivo por arquivo: sfx/CREDITOS.txt no código do jogo.": "Full list, file by file: sfx/CREDITOS.txt in the game's source.",
	# --- pistas e temas
	"Cidade Neon": "Neon City", "Céu": "Sky", "Pântano": "Swamp", "Estação Lunar": "Moon Base", "Parque": "Park",
	"Deserto": "Desert", "Neve": "Snow", "Porto": "Harbor",
	"Lago Azul": "Blue Lake", "Volta larga em torno do lago com uma chicane. A pista para aprender.": "A wide lap around the lake with one chicane. The track to learn on.",
	"Circuito do Parque": "Park Circuit", "Morros, chicane e grampo. Tráfego nos dois sentidos.": "Hills, a chicane and a hairpin. Traffic both ways.",
	"Trilha do Bosque": "Woodland Trail", "Curvas em S entre as árvores e um salto no riacho.": "S-bends through the trees and a jump over the creek.",
	"Colina dos Ventos": "Windy Hill", "Sobe e desce pelos morros, com salto no topo.": "Up and down the hills, with a jump at the top.",
	"Brejo das Garças": "Heron Marsh", "Rente à água, com dois saltos sobre o brejo.": "Right by the water, with two jumps over the marsh.",
	"Raízes Retorcidas": "Twisted Roots", "Grampos fechados entre raízes e um salto no final.": "Tight hairpins between the roots and a jump at the end.",
	"Pântano Sombrio": "Gloomy Swamp", "Oito com ponte alta e saltos sobre o brejo.": "A figure eight with a high bridge and jumps over the marsh.",
	"Ponte Podre": "Rotten Bridge", "Oito com ponte alta de madeira sobre o cruzamento.": "A figure eight with a tall wooden bridge over the crossing.",
	"Dunas Altas": "High Dunes", "Dunas enormes e dois saltos longos.": "Huge dunes and two long jumps.",
	"Cânion do Deserto": "Desert Canyon", "Subidas fortes e dois saltos sobre o vale.": "Steep climbs and two jumps across the valley.",
	"Mesa Vermelha": "Red Mesa", "Espiral de subida até o topo da mesa e salto na descida.": "A spiral climb to the top of the mesa and a jump on the way down.",
	"Desfiladeiro": "The Gorge", "Looping no fundo do cânion e salto entre as rochas.": "A loop at the bottom of the canyon and a jump between the rocks.",
	"Lago Congelado": "Frozen Lake", "Volta larga sobre o lago de gelo: o carro escorrega.": "A wide lap over the frozen lake: your car slides.",
	"Pico Nevado": "Snowy Peak", "Espiral de descida com 2 voltas e asfalto escorregadio.": "A two-turn downhill spiral on slippery asphalt.",
	"Trilha do Yeti": "Yeti Trail", "Descida longa pela montanha, salto e espiral de volta ao topo.": "A long run down the mountain, a jump and a spiral back to the top.",
	"Saca-rolhas no vale gelado e salto na crista.": "A corkscrew in the frozen valley and a jump on the ridge.",
	"Oito à noite com viaduto por cima do cruzamento.": "A night-time figure eight with an overpass above the crossing.",
	"Viaduto": "Overpass", "Oito comprido com viaduto sobre a avenida.": "A long figure eight with an overpass above the avenue.",
	"Centro Financeiro": "Financial District", "Quarteirões em ângulo reto e salto na avenida larga.": "Right-angle city blocks and a jump on the wide avenue.",
	"Túnel de Neon": "Neon Tunnel", "Dois loopings iluminados nas avenidas principais.": "Two lit-up loops on the main avenues.",
	"Estratosfera": "Stratosphere", "O topo do mundo: rampas entre ilhas flutuantes.": "The top of the world: ramps between floating islands.",
	"Nuvem Nove": "Cloud Nine", "Dois loopings flutuando acima das nuvens.": "Two loops floating above the clouds.",
	"Arco-íris": "Rainbow", "Saca-rolhas, espiral até o arco e salto entre as ilhas.": "A corkscrew, a spiral up to the arch and a jump between the islands.",
	"Espiral do Céu": "Sky Spiral", "Nas nuvens: espirais de subida e descida, torção e salto.": "In the clouds: spirals up and down, a twist and a jump.",
	"Docas do Porto": "Harbor Docks", "Píeres sobre o mar e saltos entre as docas.": "Piers over the sea and jumps between the docks.",
	"Pista de brinquedo: 2 loopings, espiral, torção e salto.": "A toy track: 2 loops, a spiral, a twist and a jump.",
}

## formatos: %d / %.1f (números) e %s (texto, traduzido de novo); {n} = n-ésimo valor no modelo em inglês
const FMT := {
	"Disponível no MUNDO %d": "Available in WORLD {0}", "Faltam $%d": "Need ${0} more", "Faltam $%s": "Need ${0} more",
	"CORRIDA %d DE %d": "RACE {0} OF {1}", "%dº": "{0}º", "CHEFE DERROTADO  +$%d": "BOSS DEFEATED  +${0}",
	"MUNDO %d LIBERADO": "WORLD {0} UNLOCKED", "NOVO CARRO: %s": "NEW CAR: {0}", "CORRIDA %d LIBERADA": "RACE {0} UNLOCKED",
	"MUNDO %d · %d / %d": "WORLD {0} · {1} / {2}", "NÍVEL %d DE 3": "LEVEL {0} OF 3", "MUNDO %d": "WORLD {0}",
	"+1 %s POR VOLTA": "+1 {0} PER LAP", "+%d TIROS POR VOLTA": "+{0} SHOTS PER LAP", "%s  NV %d/3": "{0}  LV {1}/3",
	"COMPRAR $%s": "BUY ${0}", "×%d POR VOLTA": "×{0} PER LAP", "SALDO  $%s  →  $%s": "BALANCE  ${0}  →  ${1}",
	"%s II": "{0} II", "+%d PONTOS": "+{0} POINTS", "DIREÇÃO: %s": "STEERING: {0}", "%s destruiu %s": "{0} wrecked {1}",
	"DESTRUIU %s!": "WRECKED {0}!", "PULÃO %.1fs": "BIG AIR {0}s", "VOLTA %d": "LAP {0}", "CONTRAMÃO %dm": "ONCOMING {0}m",
	"%s terminou em %dº": "{0} finished {1}º", "%dº LUGAR": "{0}º PLACE",
	"%dº  %s%s   %s   ·   %d destruídos": "{0}º  {1}{2}   {3}   ·   {4} takedowns", "%s VENCEU!": "{0} WINS!",
	"%d PRONTO%s": "{0} READY", "%s · %dº · VOLTA %d/%d": "{0} · {1}º · LAP {2}/{3}",
	"Sala %s não existe": "Room {0} does not exist", "Sala de %s": "{0}'s room", "CLIENTE%d": "CLIENT{0}", "PILOTO%d": "DRIVER{0}",
	"Conectando em %s ...": "Connecting to {0} ...", "Servidor aberto. Na mesma rede, os outros conectam em: %s": "Server is up. On the same network, others connect to: {0}",
	"Sem conexão com %s": "No connection to {0}", "%s entrou na sala": "{0} joined the room", "Novo anfitrião: %s": "New host: {0}",
	"SALA %s  ·  %s": "ROOM {0}  ·  {1}", "[ANFITRIÃO] %s": "[HOST] {0}", "%d/%d pessoas · ping %d ms": "{0}/{1} people · ping {2} ms",
	"PISTA: %s": "TRACK: {0}", "IA: %s": "AI: {0}", "%s saiu da corrida": "{0} left the race", "%s (saiu)": "{0} (left)",
	"VOZ: %s": "VOICE: {0}", "CONTROLE %d%s": "CONTROLLER {0}{1}", "ALVO: %s": "TARGET: {0}", "CHEFE · %s": "BOSS · {0}",
	"%s  %d%%": "{0}  {1}%",
}

const SEPS := ["\n", "  ·  ", " · ", " — ", ": "]


## liga o idioma ("en" ou "pt"); a primeira chamada registra a tradução no Godot
static func setup(c: String) -> void:
	if _exact.is_empty():
		_build()
	if not Engine.has_meta("lang_tr"):
		var t := LangTr.new()
		t.locale = "en"
		TranslationServer.add_translation(t)
		Engine.set_meta("lang_tr", t)
	_cache.clear()
	var loc := "en" if c == "en" else "pt_BR"
	if TranslationServer.get_locale() != loc:
		# trocar o locale avisa todos os nós (NOTIFICATION_TRANSLATION_CHANGED): os textos se refazem na hora
		TranslationServer.set_locale(loc)
	else:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			st.root.propagate_notification(Node.NOTIFICATION_TRANSLATION_CHANGED)


static func ready() -> bool:
	return Engine.has_meta("lang_tr")


## idioma salvo nas configurações (a abertura roda antes do jogo carregar o save)
static func saved_code() -> String:
	var p := "user://minifuria.json"
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else null
		if d is Dictionary and d.get("cfg") is Dictionary and String(d.cfg.get("lang", "")) in ["en", "pt"]:
			return String(d.cfg.lang)
	return default_code()


## idioma inicial: o do aparelho (português -> pt; qualquer outro -> inglês)
static func default_code() -> String:
	return "pt" if OS.get_locale_language() == "pt" else "en"


static func en() -> bool:
	return TranslationServer.get_locale().begins_with("en")


## texto traduzido (para o que é desenhado à mão ou montado fora de um Label)
static func t(s: String) -> String:
	if not en():
		return s
	var r := lookup(s)
	return s if r == "" else r


## um ou outro conforme o idioma (palavras com dois sentidos, como CONTROLE = handling / controller)
static func pick(pt: String, en_: String) -> String:
	return en_ if en() else pt


## sufixo do ordinal: 1º / 1st
static func ord(n: int) -> String:
	if not en():
		return "%dº" % n
	return str(n) + _suffix(n)


static func ord_suffix(n: int) -> String:
	return _suffix(n) if en() else "º"


static func _suffix(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "th"
	return {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")


## inglês de um texto ("" = sem tradução)
static func lookup(s: String) -> String:
	if s.length() < 2:
		return ""
	if _exact.is_empty():
		_build()
	if _exact.has(s):
		return _exact[s]
	if _cache.has(s):
		return _cache[s]
	var r := _compose(s, 0)
	if _cache.size() > 4000:
		_cache.clear()
	_cache[s] = r
	return r


static func _compose(s: String, depth: int) -> String:
	if _exact.has(s):
		return _exact[s]
	if depth > 6 or s.length() < 2 or _letter.search(s) == null:
		return ""
	# espaços nas pontas
	var st := s.strip_edges()
	if st != s and st.length() >= 2:
		var ti := _compose(st, depth + 1)
		if ti != "":
			var a := s.find(st)
			return s.left(a) + ti + s.substr(a + st.length())
		return ""
	if s.begins_with("▸ "):
		var tb := _compose(s.substr(2), depth + 1)
		return "▸ " + tb if tb != "" else ""
	for f in _fmt:
		if f[3] != "" and not s.contains(f[3]):
			continue
		var m: RegExMatch = (f[0] as RegEx).search(s)
		if m == null:
			continue
		var out: String = f[1]
		var kinds: Array = f[2]
		for gi in kinds.size():
			var g := m.get_string(gi + 1)
			if kinds[gi] == "s":
				var tg := _compose(g, depth + 1)
				if tg != "":
					g = tg
			out = out.replace("{%d}" % gi, g)
		return _ordinals(out)
	for sep in SEPS:
		if not s.contains(sep):
			continue
		var parts := s.split(sep)
		var changed := false
		for i in parts.size():
			var tp := _compose(parts[i], depth + 1)
			if tp != "":
				parts[i] = tp
				changed = true
		return sep.join(parts) if changed else ""
	return ""


static func _ordinals(s: String) -> String:
	if not s.contains("º"):
		return s
	var out := s
	for m in _ord.search_all(s):
		var n := int(m.get_string(1))
		out = out.replace(m.get_string(0), str(n) + _suffix(n))
	return out


static func _build() -> void:
	_letter = RegEx.new()
	_letter.compile("[A-Za-zÀ-ÿº]")
	_ord = RegEx.new()
	_ord.compile("(\\d+)º")
	for k in EN:
		_exact[k] = EN[k]
	# versões em maiúsculas (nomes de pista e de mundo aparecem assim nos títulos)
	for k in EN:
		var up := String(k).to_upper()
		if not _exact.has(up):
			_exact[up] = String(EN[k]).to_upper()
	var tok := RegEx.new()
	tok.compile("%(\\.\\d+)?[dsf]|%%")
	var list: Array = []
	for k in FMT:
		var src := String(k)
		var pat := "^"
		var kinds: Array = []
		var pos := 0
		var longest := ""
		for m in tok.search_all(src):
			var lit := src.substr(pos, m.get_start() - pos)
			pat += _esc(lit)
			if lit.strip_edges().length() > longest.length():
				longest = lit.strip_edges()
			var tk := m.get_string(0)
			if tk == "%%":
				pat += "%"
			elif tk.ends_with("s"):
				pat += "(.*?)"
				kinds.append("s")
			elif tk.ends_with("f"):
				pat += "(-?[0-9]+(?:[.,][0-9]+)?)"
				kinds.append("f")
			else:
				pat += "(-?[0-9]+)"
				kinds.append("d")
			pos = m.get_end()
		var tail := src.substr(pos)
		pat += _esc(tail)
		if tail.strip_edges().length() > longest.length():
			longest = tail.strip_edges()
		pat += "$"
		var re := RegEx.new()
		if re.compile(pat) != OK:
			push_warning("Lang: formato inválido " + src)
			continue
		list.append([re, String(FMT[k]), kinds, longest, src.length() - kinds.size() * 2])
	# formatos mais específicos (mais texto fixo) primeiro
	list.sort_custom(func(a, b): return int(a[4]) > int(b[4]))
	_fmt = list


static func _esc(s: String) -> String:
	var out := ""
	for ch in s:
		if ch in ".^$*+?()[]{}|\\/":
			out += "\\" + ch
		else:
			out += ch
	return out

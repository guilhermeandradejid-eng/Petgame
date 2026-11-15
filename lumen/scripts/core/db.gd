extends Node
## Banco de dados do jogo: classes, habilidades, bencaos, reliquias, inimigos,
## melhorias permanentes e o catalogo de cosmeticos (lido do manifesto do Blender).

const RARITY_NAMES := ["Comum", "Raro", "Épico", "Lendário"]
const RARITY_COLORS := [Color("b9c2d6"), Color("58b6ff"), Color("c07bff"), Color("ffb23e")]

# ------------------------------------------------------------------ classes
const CLASS_ORDER := ["espadachim", "patrulheiro", "arcanista", "guardiao"]
const CLASSES := {
	"espadachim": {
		"name": "Espadachim", "wt": "sword", "color": "ef6a5b", "hp": 120, "speed": 5.9,
		"desc": "Combos velozes de espada e muita mobilidade. Fica no meio da briga.",
		"primary": "sw_combo", "secondary": "sw_estocada", "skills": ["sw_redemoinho", "sw_salto"], "ult": "sw_tempestade",
	},
	"patrulheiro": {
		"name": "Patrulheiro", "wt": "bow", "color": "6fc46a", "hp": 95, "speed": 6.1,
		"desc": "Flechas de longe, saltos para escapar e uma chuva de flechas devastadora.",
		"primary": "bw_tiro", "secondary": "bw_perfurante", "skills": ["bw_leque", "bw_recuo"], "ult": "bw_chuva",
	},
	"arcanista": {
		"name": "Arcanista", "wt": "staff", "color": "8f7bff", "hp": 85, "speed": 5.7,
		"desc": "Magias de fogo e gelo em área. Frágil, mas apaga salas inteiras.",
		"primary": "st_faisca", "secondary": "st_piscar", "skills": ["st_bola_fogo", "st_nova_gelo"], "ult": "st_meteoro",
	},
	"guardiao": {
		"name": "Guardião", "wt": "hammer", "color": "f2b632", "hp": 155, "speed": 5.5,
		"desc": "Martelo, escudo e bênçãos. Aguenta pancada e mantém o grupo de pé.",
		"primary": "hm_combo", "secondary": "hm_escudada", "skills": ["hm_bencao", "hm_tremor"], "ult": "hm_santuario",
	},
}

# ------------------------------------------------------------------ habilidades
# fn = implementacao em scripts/player/skills.gd. mult = multiplicador do ataque base.
const SKILLS := {
	# --- espadachim
	"sw_combo": {"name": "Corte Triplo", "icon": "sword", "fn": "combo", "cd": 0.0,
		"desc": "Três cortes em sequência; o último salta e esmaga.",
		"steps": [
			{"anim": "sword_atk1", "hit": 0.20, "cancel": 0.34, "dur": 0.52, "mult": 1.0, "r": 2.5, "angle": 150.0, "lunge": 1.4, "kb": 2.0, "slash": 1},
			{"anim": "sword_atk2", "hit": 0.20, "cancel": 0.34, "dur": 0.52, "mult": 1.1, "r": 2.5, "angle": 150.0, "lunge": 1.4, "kb": 2.0, "slash": -1},
			{"anim": "sword_atk3", "hit": 0.37, "cancel": 0.62, "dur": 0.80, "mult": 2.0, "r": 2.9, "angle": 130.0, "lunge": 2.2, "kb": 5.0, "slash": 2, "shake": 0.5},
		]},
	"sw_estocada": {"name": "Estocada", "icon": "thrust", "fn": "dash_strike", "cd": 3.5, "anim": "thrust",
		"desc": "Avança num rasante e perfura tudo no caminho. Invulnerável durante o avanço.",
		"mult": 1.7, "dist": 6.5, "time": 0.2, "width": 1.5, "kb": 3.0},
	"sw_redemoinho": {"name": "Redemoinho", "icon": "whirl", "fn": "whirl", "cd": 8.0, "anim": "spin-loop",
		"desc": "Gira com a lâmina estendida por 1,8 s, cortando tudo ao redor. Dá para andar girando.",
		"mult": 0.55, "r": 2.9, "time": 1.8, "tick": 0.2},
	"sw_salto": {"name": "Salto Esmagador", "icon": "leap", "fn": "leap_slam", "cd": 10.0, "anim": "sword_atk3",
		"desc": "Salta até o ponto mirado e esmaga o chão numa área.",
		"mult": 2.8, "r": 3.4, "range": 10.0, "kb": 6.0},
	"sw_tempestade": {"name": "Tempestade de Lâminas", "icon": "storm", "fn": "blade_storm", "cd": 42.0, "anim": "spin-loop",
		"desc": "SUPREMA. Vira um vendaval de cortes numa área enorme e termina com uma explosão.",
		"mult": 0.8, "final": 4.5, "r": 5.5, "time": 1.8, "tick": 0.15},
	# --- patrulheiro
	"bw_tiro": {"name": "Tiro Rápido", "icon": "arrow", "fn": "shot", "cd": 0.0, "anim": "bow_shot",
		"desc": "Flechas rápidas. A cada terceiro tiro saem três flechas.",
		"mult": 0.9, "speed": 36.0, "release": 0.16, "dur": 0.40, "anim_speed": 1.5, "proj": "arrow", "every3": 3, "spread": 9.0},
	"bw_perfurante": {"name": "Flecha Perfurante", "icon": "pierce", "fn": "shot", "cd": 4.0, "anim": "bow_shot",
		"desc": "Uma flecha carregada que atravessa todos os inimigos na linha.",
		"mult": 2.6, "speed": 48.0, "release": 0.42, "dur": 0.70, "anim_speed": 0.6, "proj": "arrow_big", "pierce": 99, "kb": 4.0},
	"bw_leque": {"name": "Leque de Flechas", "icon": "fan", "fn": "shot", "cd": 6.0, "anim": "bow_shot",
		"desc": "Dispara sete flechas em leque.",
		"mult": 0.85, "speed": 32.0, "release": 0.2, "dur": 0.5, "anim_speed": 1.2, "proj": "arrow", "count": 7, "spread": 11.0},
	"bw_recuo": {"name": "Salto de Recuo", "icon": "backflip", "fn": "backflip_shot", "cd": 8.0, "anim": "bow_leap",
		"desc": "Salta para trás, invulnerável, e larga três flechas explosivas.",
		"mult": 1.3, "dist": 7.0, "r": 2.2},
	"bw_chuva": {"name": "Chuva de Flechas", "icon": "rain", "fn": "zone", "cd": 40.0, "anim": "bow_shot",
		"desc": "SUPREMA. Flechas caem por 4 s na área mirada, ferindo e deixando os inimigos lentos.",
		"mult": 0.65, "r": 5.5, "time": 4.0, "tick": 0.25, "range": 16.0, "status": "chill", "vfx": "arrow_rain", "anim_speed": 0.8},
	# --- arcanista
	"st_faisca": {"name": "Faísca Arcana", "icon": "bolt", "fn": "shot", "cd": 0.0, "anim": "staff_bolt",
		"desc": "Orbes arcanos que estouram em pequena área.",
		"mult": 1.0, "speed": 26.0, "release": 0.18, "dur": 0.42, "anim_speed": 1.2, "proj": "orb", "splash": 1.4, "color": "9d8bff"},
	"st_piscar": {"name": "Piscar", "icon": "blink", "fn": "blink", "cd": 5.0, "anim": "",
		"desc": "Teleporta na direção em que anda e deixa uma explosão arcana para trás.",
		"mult": 1.0, "dist": 7.5, "r": 2.6},
	"st_bola_fogo": {"name": "Bola de Fogo", "icon": "fire", "fn": "shot", "cd": 5.0, "anim": "staff_bolt",
		"desc": "Explode ao acertar, queimando todos na área.",
		"mult": 2.5, "speed": 22.0, "release": 0.3, "dur": 0.6, "anim_speed": 0.75, "proj": "fireball", "splash": 3.2, "status": "burn", "color": "ff8a3d", "kb": 3.0},
	"st_nova_gelo": {"name": "Nova de Gelo", "icon": "frost", "fn": "nova", "cd": 9.0, "anim": "staff_big",
		"desc": "Uma onda gelada explode ao seu redor e congela os inimigos.",
		"mult": 1.7, "r": 5.5, "delay": 0.45, "status": "freeze", "color": "8fe3ff"},
	"st_meteoro": {"name": "Meteoro", "icon": "meteor", "fn": "meteor", "cd": 45.0, "anim": "staff_big",
		"desc": "SUPREMA. Chama um meteoro gigante no ponto mirado.",
		"mult": 8.5, "r": 6.0, "delay": 1.3, "range": 18.0, "status": "burn", "color": "ff6a2a"},
	# --- guardiao
	"hm_combo": {"name": "Marteladas", "icon": "hammer", "fn": "combo", "cd": 0.0,
		"desc": "Golpes pesados e lentos que empurram os inimigos.",
		"steps": [
			{"anim": "hammer_atk1", "hit": 0.25, "cancel": 0.42, "dur": 0.62, "mult": 1.35, "r": 2.5, "angle": 150.0, "lunge": 1.1, "kb": 4.0, "slash": 1, "speed": 0.82},
			{"anim": "hammer_atk2", "hit": 0.25, "cancel": 0.42, "dur": 0.62, "mult": 1.45, "r": 2.5, "angle": 150.0, "lunge": 1.1, "kb": 4.0, "slash": -1, "speed": 0.82},
			{"anim": "hammer_atk3", "hit": 0.43, "cancel": 0.72, "dur": 0.92, "mult": 2.7, "r": 3.1, "angle": 360.0, "lunge": 1.6, "kb": 7.0, "slash": 2, "shake": 0.7, "speed": 0.86, "status": "stun", "status_t": 0.6},
		]},
	"hm_escudada": {"name": "Escudada", "icon": "shield_bash", "fn": "bash", "cd": 4.0, "anim": "bash",
		"desc": "Pancada de escudo que atordoa. Você bloqueia 70% do dano por um instante.",
		"mult": 1.5, "r": 2.6, "angle": 130.0, "kb": 6.0, "status": "stun", "status_t": 1.2, "guard": 0.9},
	"hm_bencao": {"name": "Bênção", "icon": "heal", "fn": "heal_circle", "cd": 14.0, "anim": "raise",
		"desc": "Cura você e os aliados próximos em 28% da vida máxima.",
		"heal": 0.28, "r": 6.5, "color": "ffe38a"},
	"hm_tremor": {"name": "Tremor", "icon": "quake", "fn": "nova", "cd": 9.0, "anim": "slam",
		"desc": "Martelada no chão que fere e atordoa todos ao redor.",
		"mult": 2.3, "r": 4.8, "delay": 0.4, "status": "stun", "status_t": 1.3, "color": "ffd36b", "shake": 0.8},
	"hm_santuario": {"name": "Santuário", "icon": "sanctuary", "fn": "sanctuary", "cd": 50.0, "anim": "raise",
		"desc": "SUPREMA. Cria uma zona sagrada por 8 s: aliados curam e sofrem metade do dano; inimigos queimam.",
		"mult": 0.5, "heal": 0.04, "r": 7.0, "time": 8.0, "tick": 0.5, "color": "ffe38a"},
	# --- magias (tomos encontrados durante a run; qualquer classe usa)
	"sp_fogo": {"name": "Bola de Fogo", "icon": "fire", "fn": "shot", "cd": 6.0, "anim": "throw", "spell": true, "rarity": 0,
		"desc": "Arremessa uma bola de fogo que explode e queima.",
		"mult": 2.1, "speed": 22.0, "release": 0.2, "dur": 0.5, "proj": "fireball", "splash": 3.0, "status": "burn", "color": "ff8a3d"},
	"sp_lanca_gelo": {"name": "Lança de Gelo", "icon": "icicle", "fn": "shot", "cd": 5.0, "anim": "throw", "spell": true, "rarity": 0,
		"desc": "Uma lança gelada que atravessa inimigos e os deixa lentos.",
		"mult": 1.9, "speed": 34.0, "release": 0.2, "dur": 0.5, "proj": "icicle", "pierce": 99, "status": "chill", "color": "8fe3ff"},
	"sp_corrente": {"name": "Corrente de Raios", "icon": "lightning", "fn": "chain", "cd": 7.0, "anim": "raise", "spell": true, "rarity": 1,
		"desc": "Um raio salta entre até 6 inimigos.",
		"mult": 1.3, "range": 12.0, "jumps": 6, "jump_r": 6.0, "color": "ffe95c"},
	"sp_estrelas": {"name": "Chuva de Estrelas", "icon": "stars", "fn": "star_rain", "cd": 11.0, "anim": "raise", "spell": true, "rarity": 1,
		"desc": "Sete estrelas caem perto do ponto mirado.",
		"mult": 1.6, "r": 2.4, "count": 7, "area": 5.5, "range": 14.0, "color": "ffd36b"},
	"sp_escudo": {"name": "Escudo de Lúmen", "icon": "barrier", "fn": "shield", "cd": 16.0, "anim": "raise", "spell": true, "rarity": 1,
		"desc": "Você e os aliados próximos ganham um escudo que absorve dano por 8 s.",
		"shield": 0.35, "r": 6.5, "time": 8.0, "color": "7df9ff"},
	"sp_cura": {"name": "Círculo de Cura", "icon": "heal", "fn": "heal_circle", "cd": 16.0, "anim": "raise", "spell": true, "rarity": 0,
		"desc": "Cura você e os aliados próximos em 20% da vida máxima.",
		"heal": 0.20, "r": 6.0, "color": "8dffb0"},
	"sp_piscar": {"name": "Passo de Luz", "icon": "blink", "fn": "blink", "cd": 6.0, "anim": "", "spell": true, "rarity": 0,
		"desc": "Teleporta na direção em que anda.",
		"mult": 0.8, "dist": 7.0, "r": 2.4},
	"sp_totem": {"name": "Totem Espinhoso", "icon": "totem", "fn": "totem", "cd": 14.0, "anim": "throw", "spell": true, "rarity": 1,
		"desc": "Planta um totem que atira espinhos nos inimigos por 9 s.",
		"mult": 0.6, "time": 9.0, "tick": 0.5, "range": 11.0, "color": "8fd16a"},
	"sp_laminas": {"name": "Lâminas Orbitantes", "icon": "orbit", "fn": "orbit", "cd": 15.0, "anim": "raise", "spell": true, "rarity": 2,
		"desc": "Três lâminas de luz giram ao seu redor por 8 s.",
		"mult": 0.55, "time": 8.0, "tick": 0.3, "r": 2.6, "count": 3, "color": "7df9ff"},
	"sp_vortice": {"name": "Vórtice", "icon": "vortex", "fn": "vortex", "cd": 13.0, "anim": "throw", "spell": true, "rarity": 2,
		"desc": "Abre um vórtice que puxa os inimigos por 3,5 s. Combina com qualquer área.",
		"mult": 0.35, "r": 6.5, "time": 3.5, "tick": 0.25, "range": 13.0, "color": "b48cff"},
	"sp_vendaval": {"name": "Vendaval", "icon": "wind", "fn": "bash", "cd": 8.0, "anim": "slam", "spell": true, "rarity": 0,
		"desc": "Uma rajada em cone que arremessa os inimigos para longe.",
		"mult": 1.5, "r": 6.5, "angle": 80.0, "kb": 14.0, "color": "c6ffe0", "delay": 0.38, "vfx": "gust"},
	"sp_raio_solar": {"name": "Raio Solar", "icon": "beam", "fn": "beam", "cd": 12.0, "anim": "channel-loop", "spell": true, "rarity": 2,
		"desc": "Canaliza um feixe de luz por 2 s que atravessa tudo.",
		"mult": 0.7, "range": 16.0, "time": 2.0, "tick": 0.2, "width": 1.3, "color": "fff2a8", "status": "burn"},
}

# ------------------------------------------------------------------ bencaos (empilham niveis)
# mods: soma por nivel. Estatisticas: ver Player.recalc_stats.
const BOONS := {
	"forca": {"name": "Força", "icon": "fist", "max": 5, "mods": {"atk": 0.12}, "desc": "+12% de dano"},
	"precisao": {"name": "Precisão", "icon": "target", "max": 5, "mods": {"crit": 0.08}, "desc": "+8% de chance de crítico"},
	"furia": {"name": "Fúria", "icon": "rage", "max": 4, "mods": {"crit_dmg": 0.35}, "desc": "+35% de dano crítico"},
	"vigor": {"name": "Vigor", "icon": "heart", "max": 5, "mods": {"max_hp": 25.0}, "desc": "+25 de vida máxima", "heal": 25.0},
	"presteza": {"name": "Presteza", "icon": "speed", "max": 4, "mods": {"aspd": 0.10}, "desc": "+10% de velocidade de ataque"},
	"passos": {"name": "Passos Leves", "icon": "boots", "max": 3, "mods": {"mspd": 0.08}, "desc": "+8% de movimento"},
	"foco": {"name": "Foco", "icon": "hourglass", "max": 4, "mods": {"cdr": 0.10}, "desc": "-10% de recarga das habilidades"},
	"casca": {"name": "Casca Grossa", "icon": "armor", "max": 4, "mods": {"def": 0.08}, "desc": "-8% de dano sofrido"},
	"sanguessuga": {"name": "Sanguessuga", "icon": "fang", "max": 3, "mods": {"lifesteal": 0.02}, "desc": "Cura 2% do dano causado", "rarity": 1},
	"ganancia": {"name": "Ganância", "icon": "coins", "max": 3, "mods": {"gold": 0.30}, "desc": "+30% de ouro"},
	"sorte": {"name": "Sorte", "icon": "clover", "max": 3, "mods": {"luck": 1.0}, "desc": "Recompensas mais raras"},
	"esquiva": {"name": "Fôlego Extra", "icon": "dash", "max": 2, "mods": {"dodges": 1.0}, "desc": "+1 carga de esquiva", "rarity": 1},
	"regen": {"name": "Regeneração", "icon": "regen", "max": 3, "mods": {"regen": 1.2}, "desc": "Recupera 1,2 de vida por segundo"},
	"espinhos": {"name": "Espinhos", "icon": "thorns", "max": 3, "mods": {"thorns": 25.0}, "desc": "Quem te acerta sofre 25 de dano"},
	"arcano": {"name": "Poder Arcano", "icon": "magic", "max": 5, "mods": {"skill": 0.15}, "desc": "+15% de dano das habilidades"},
	"mestre": {"name": "Mestre de Armas", "icon": "sword", "max": 5, "mods": {"primary": 0.15}, "desc": "+15% de dano dos ataques básicos"},
	"chama": {"name": "Chama Interior", "icon": "fire", "max": 3, "mods": {"p_burn": 0.20}, "desc": "Ataques básicos têm +20% de chance de queimar", "rarity": 1},
	"toque_gelido": {"name": "Toque Gélido", "icon": "frost", "max": 3, "mods": {"p_chill": 0.20}, "desc": "Ataques básicos têm +20% de chance de deixar lento", "rarity": 1},
	"veneno": {"name": "Lâmina Venenosa", "icon": "poison", "max": 3, "mods": {"p_poison": 0.25}, "desc": "Ataques básicos têm +25% de chance de envenenar", "rarity": 1},
	"faisca": {"name": "Faísca", "icon": "lightning", "max": 3, "mods": {"p_chain": 0.12}, "desc": "+12% de chance de um raio saltar para inimigos próximos", "rarity": 1},
	"pulo": {"name": "Pulo Duplo", "icon": "wings", "max": 1, "mods": {"jumps": 1.0}, "desc": "Pode pular mais uma vez no ar", "rarity": 1},
	"colosso": {"name": "Colosso", "icon": "giant", "max": 2, "mods": {"size": 0.12, "max_hp": 20.0, "atk": 0.06}, "desc": "Fica maior: +20 de vida e +6% de dano", "rarity": 1},
	"ima": {"name": "Ímã", "icon": "magnet", "max": 1, "mods": {"magnet": 6.0}, "desc": "Coleta ouro e itens de bem mais longe"},
	"supremo": {"name": "Ímpeto", "icon": "star", "max": 3, "mods": {"ult_cdr": 0.15}, "desc": "-15% de recarga da habilidade suprema", "rarity": 1},
}

# ------------------------------------------------------------------ reliquias (unicas)
# proc: efeito especial tratado em scripts/player/procs.gd
const RELICS := {
	"coracao_brasa": {"name": "Coração de Brasa", "icon": "ember", "rarity": 1, "proc": "kill_explode",
		"desc": "Inimigos que você derrota explodem, ferindo os vizinhos."},
	"sino_prata": {"name": "Sino de Prata", "icon": "bell", "rarity": 1, "proc": "nth_bolt",
		"desc": "A cada 5 acertos, um raio cai sobre o alvo."},
	"trevo_dourado": {"name": "Trevo Dourado", "icon": "clover", "rarity": 1, "mods": {"crit": 0.12}, "proc": "crit_gold",
		"desc": "+12% de crítico. Críticos às vezes soltam ouro."},
	"lente_cacador": {"name": "Lente do Caçador", "icon": "lens", "rarity": 0, "proc": "full_hp_bonus",
		"desc": "+35% de dano em inimigos com a vida cheia."},
	"semente_viva": {"name": "Semente Viva", "icon": "seed", "rarity": 0, "proc": "kill_heal",
		"desc": "Cura 3 de vida a cada inimigo derrotado."},
	"manto_aurora": {"name": "Manto da Aurora", "icon": "cloak", "rarity": 0, "proc": "room_shield",
		"desc": "Começa cada sala com um escudo de 30% da vida."},
	"dente_dragao": {"name": "Dente de Dragão", "icon": "tooth", "rarity": 2, "mods": {"primary": 0.20, "p_burn": 0.35},
		"desc": "+20% de dano básico e grande chance de queimar."},
	"lua_crescente": {"name": "Lua Crescente", "icon": "moon", "rarity": 1, "proc": "dodge_crit",
		"desc": "Depois de esquivar, seu próximo golpe é crítico garantido."},
	"coroa_partida": {"name": "Coroa Partida", "icon": "crown", "rarity": 2, "mods": {"atk": 0.45, "hp_pct": -0.25},
		"desc": "+45% de dano, mas -25% de vida máxima."},
	"amuleto_eco": {"name": "Amuleto do Eco", "icon": "echo", "rarity": 2, "proc": "skill_echo",
		"desc": "25% de chance de uma habilidade não entrar em recarga."},
	"laminas_gemeas": {"name": "Lâminas Gêmeas", "icon": "orbit", "rarity": 2, "proc": "orbit_blades",
		"desc": "Duas lâminas de luz giram ao seu redor o tempo todo."},
	"tambor_guerra": {"name": "Tambor de Guerra", "icon": "drum", "rarity": 1, "proc": "kill_stack",
		"desc": "+3% de dano por inimigo derrotado na sala (até 36%)."},
	"calice": {"name": "Cálice Transbordante", "icon": "chalice", "rarity": 0, "mods": {"heal_bonus": 0.5},
		"desc": "Toda cura que você recebe é 50% maior."},
	"pedra_trovao": {"name": "Pedra-Trovão", "icon": "lightning", "rarity": 1, "proc": "dodge_shock",
		"desc": "Esquivar solta uma descarga elétrica no ponto de partida."},
	"estrela_cadente": {"name": "Estrela Cadente", "icon": "stars", "rarity": 2, "proc": "periodic_star",
		"desc": "A cada 6 s uma estrela cai num inimigo próximo."},
	"fio_dourado": {"name": "Fio Dourado", "icon": "thread", "rarity": 1, "proc": "ally_aura",
		"desc": "Você e os aliados a até 9 m causam +12% de dano."},
	"elo_solidario": {"name": "Elo Solidário", "icon": "link", "rarity": 0, "mods": {"revive_speed": 1.0}, "proc": "revive_heal",
		"desc": "Levanta aliados duas vezes mais rápido e os dois se curam."},
	"escudo_espelhado": {"name": "Escudo Espelhado", "icon": "mirror", "rarity": 1, "proc": "hurt_nova",
		"desc": "Ao sofrer dano, solta uma onda de choque (recarga de 4 s)."},
	"bota_alada": {"name": "Botas Aladas", "icon": "wings", "rarity": 1, "mods": {"mspd": 0.15, "jumps": 1.0},
		"desc": "+15% de movimento e um pulo extra no ar."},
	"gema_gelida": {"name": "Gema Gélida", "icon": "gem", "rarity": 1, "proc": "slow_bonus", "mods": {"p_chill": 0.15},
		"desc": "Inimigos lentos ou congelados sofrem +30% de dano."},
	"polvora_feerica": {"name": "Pólvora Feérica", "icon": "bomb", "rarity": 2, "proc": "hit_burst",
		"desc": "Seus acertos têm 20% de chance de estourar em área."},
	"fenix": {"name": "Pena de Fênix", "icon": "phoenix", "rarity": 3, "mods": {"revives": 1.0},
		"desc": "Uma vez por run, levanta sozinho com metade da vida."},
	"olho_tempestade": {"name": "Olho da Tempestade", "icon": "storm", "rarity": 3, "mods": {"cdr": 0.25, "ult_cdr": 0.25, "aspd": 0.15},
		"desc": "-25% de todas as recargas e +15% de velocidade de ataque."},
	"coracao_colosso": {"name": "Coração do Colosso", "icon": "giant", "rarity": 3, "mods": {"hp_pct": 0.6, "def": 0.12, "size": 0.15},
		"desc": "+60% de vida máxima, -12% de dano sofrido. Você cresce."},
	"prisma_lumen": {"name": "Prisma de Lúmen", "icon": "prism", "rarity": 3, "mods": {"atk": 0.25, "crit": 0.15, "skill": 0.25},
		"desc": "+25% de dano, +15% de crítico e +25% de dano de habilidades."},
}

# ------------------------------------------------------------------ melhorias permanentes (altar)
const UPGRADES := {
	"vida": {"name": "Vitalidade", "icon": "heart", "max": 5, "cost": 30, "mods": {"max_hp": 12.0}, "desc": "+12 de vida máxima por nível"},
	"forca": {"name": "Treino", "icon": "fist", "max": 5, "cost": 40, "mods": {"atk": 0.05}, "desc": "+5% de dano por nível"},
	"critico": {"name": "Olho Afiado", "icon": "target", "max": 5, "cost": 40, "mods": {"crit": 0.03}, "desc": "+3% de crítico por nível"},
	"recarga": {"name": "Disciplina", "icon": "hourglass", "max": 5, "cost": 40, "mods": {"cdr": 0.04}, "desc": "-4% de recarga por nível"},
	"ouro": {"name": "Mesada", "icon": "coins", "max": 3, "cost": 35, "start_gold": 40, "desc": "Começa a run com +40 de ouro por nível"},
	"frasco": {"name": "Frasco de Cura", "icon": "potion", "max": 3, "cost": 60, "flasks": 1, "desc": "+1 frasco de cura por run (tecla V)"},
	"reviver": {"name": "Segundo Fôlego", "icon": "phoenix", "max": 1, "cost": 220, "mods": {"revives": 1.0}, "desc": "Levanta sozinho uma vez por run"},
	"sorte": {"name": "Faro", "icon": "clover", "max": 3, "cost": 70, "mods": {"luck": 0.7}, "desc": "Recompensas mais raras"},
	"fragmentos": {"name": "Colecionador", "icon": "shard", "max": 5, "cost": 45, "shard_bonus": 0.12, "desc": "+12% de fragmentos por nível"},
}

# ------------------------------------------------------------------ inimigos
# atk: lista de ataques. shape: circle (raio r em volta de um ponto a 'off' metros a frente),
# cone (r, angle), line (len, width). Tempos de acerto vem do manifesto das animacoes quando existem.
const ENEMIES := {
	"dummy": {"name": "Boneco de Treino", "hp": 99999.0, "speed": 0.0, "radius": 0.45, "height": 1.7, "cost": 0.0, "gold": 0, "ai": "none",
		"range": 0.0, "color": "c9a26b", "atk": [], "no_spawn_anim": true, "poise": 1.0},
	"broto": {"name": "Brotinho", "hp": 36.0, "speed": 3.9, "radius": 0.38, "height": 0.75, "cost": 1.0, "gold": 2, "ai": "melee",
		"range": 2.0, "color": "5fce7a",
		"atk": [{"anim": "attack", "hit": 0.42, "len": 0.9, "dmg": 9.0, "shape": "circle", "r": 1.25, "off": 1.1, "lunge": 2.2, "cd": 1.4}]},
	"cogu": {"name": "Cogumelo Brigão", "hp": 92.0, "speed": 2.9, "radius": 0.55, "height": 1.15, "cost": 2.2, "gold": 4, "ai": "melee",
		"range": 2.1, "color": "e2665a",
		"atk": [{"anim": "attack", "hit": 0.45, "len": 1.0, "dmg": 15.0, "shape": "cone", "r": 2.3, "angle": 110.0, "cd": 1.6, "kb": 5.0},
			{"anim": "attack2", "hit": 0.70, "len": 1.4, "dmg": 20.0, "shape": "circle", "r": 3.0, "off": 0.0, "cd": 6.0, "kb": 7.0, "min_cd": 3.0}]},
	"fagulha": {"name": "Fagulha", "hp": 48.0, "speed": 3.2, "radius": 0.4, "height": 1.5, "cost": 2.0, "gold": 4, "ai": "ranged",
		"range": 12.0, "keep": 7.5, "color": "ffb14a", "float": 0.0,
		"atk": [{"anim": "cast", "hit": 0.55, "len": 1.0, "dmg": 12.0, "shape": "proj", "speed": 11.5, "r": 0.45, "cd": 2.6, "color": "ff9a3d"}]},
	"cascudo": {"name": "Cascudo", "hp": 125.0, "speed": 2.6, "radius": 0.7, "height": 1.0, "cost": 3.0, "gold": 6, "ai": "charger",
		"range": 13.0, "color": "5a7bd6",
		"atk": [{"anim": "charge_start", "hit": 0.65, "len": 0.65, "dmg": 22.0, "shape": "charge", "speed": 15.0, "time": 1.15, "width": 1.5, "cd": 4.5, "kb": 9.0},
			{"anim": "attack", "hit": 0.35, "len": 0.8, "dmg": 14.0, "shape": "cone", "r": 2.2, "angle": 100.0, "cd": 2.0, "kb": 6.0, "close": 2.2}]},
	"sentinela": {"name": "Sentinela de Ruína", "hp": 560.0, "speed": 2.5, "radius": 1.0, "height": 2.3, "cost": 9.0, "gold": 22, "ai": "melee", "elite": true,
		"range": 3.4, "color": "9fb0ff", "poise": 0.85,
		"atk": [{"anim": "attack", "hit": 0.75, "len": 1.5, "dmg": 30.0, "shape": "circle", "r": 3.4, "off": 2.2, "cd": 2.6, "kb": 8.0, "shake": 0.6, "wave": true},
			{"anim": "attack2", "hit": 0.6, "len": 1.3, "dmg": 24.0, "shape": "cone", "r": 4.4, "angle": 170.0, "cd": 4.0, "kb": 9.0}]},
	"guardiao": {"name": "Guardião Cristalino", "hp": 2400.0, "speed": 2.7, "radius": 1.5, "height": 3.5, "cost": 99.0, "gold": 120, "ai": "boss", "boss": true,
		"range": 4.6, "color": "7df9ff", "poise": 1.0,
		"atk": [{"anim": "attack", "hit": 0.8, "len": 1.7, "dmg": 34.0, "shape": "circle", "r": 4.6, "off": 3.0, "cd": 3.0, "kb": 9.0, "shake": 0.9, "wave": true},
			{"anim": "attack2", "hit": 0.65, "len": 1.5, "dmg": 28.0, "shape": "cone", "r": 6.0, "angle": 180.0, "cd": 4.5, "kb": 10.0},
			{"anim": "charge_start", "hit": 0.8, "len": 0.8, "dmg": 32.0, "shape": "charge", "speed": 17.0, "time": 1.0, "width": 3.2, "cd": 9.0, "kb": 12.0},
			{"anim": "cast", "hit": 0.9, "len": 1.7, "dmg": 26.0, "shape": "rain", "r": 2.4, "delay": 1.0, "count": 5, "cd": 8.0, "phase": 1},
			{"anim": "roar", "hit": 0.8, "len": 1.5, "dmg": 0.0, "shape": "summon", "count": 3, "cd": 16.0, "phase": 2}]},
}

# ------------------------------------------------------------------ biomas
const BIOMES := {
	"forest": {"name": "Bosque Luminoso", "kit": "env_forest", "pool": ["broto", "broto", "cogu", "fagulha"], "elite_adds": ["broto", "cogu"]},
	"crystal": {"name": "Gruta de Cristal", "kit": "env_crystal", "pool": ["broto", "cogu", "fagulha", "cascudo", "cascudo"], "elite_adds": ["fagulha", "cascudo"]},
	"boss": {"name": "Santuário do Guardião", "kit": "env_boss", "pool": ["broto", "fagulha"], "elite_adds": []},
}

const ROOM_NAMES := {"combat": "Combate", "elite": "Elite", "shop": "Mercador", "rest": "Fonte", "boss": "Guardião", "treasure": "Tesouro"}
const ROOM_ICONS := {"combat": "sword", "elite": "skull", "shop": "coins", "rest": "heart", "boss": "crown", "treasure": "chest"}

# ------------------------------------------------------------------ paletas de tinta
const SKIN_TONES := ["fbe0c8", "f6c9a4", "e8b088", "c98f62", "a06a43", "7a4a2e", "5a3622", "c9e4b8", "b9c8f2", "e9bfd9"]
const HAIR_COLORS := ["2f2a3d", "5a3a28", "7a4a2e", "b0703c", "e8b04a", "f5e2a0", "f2f2f2", "c9423c", "ff7fa8", "8f7bff", "3f86d9", "4fd0c0", "5fae6a", "7d8597"]
const CLOTH_COLORS := ["3f86d9", "2f4f9f", "4fd0c0", "3fae7a", "8fd16a", "f2b632", "f08a3c", "d9534f", "ff7fa8", "c07bff", "6a4fb0", "f3ead6", "b9c2d6", "6b7286", "2f2a3d", "8a5a3c"]
const IRIS_COLORS := ["5fb0e8", "4fd0c0", "6fc46a", "c98f3c", "8a5a3c", "c07bff", "d9534f", "ff7fa8", "7d8597", "f2d24a"]

const SLOT_ORDER := ["hair", "hat", "ears", "acc", "eyes", "top", "bottom", "back", "weapon"]
const SLOT_NAMES := {"hair": "Cabelo", "hat": "Chapéu", "ears": "Orelhas", "acc": "Acessório", "eyes": "Olhos",
	"top": "Roupa", "bottom": "Calça", "back": "Costas", "weapon": "Arma"}
const EYE_NAMES := {"eyes_round": "Redondos", "eyes_sharp": "Afiados", "eyes_sleepy": "Sonolentos", "eyes_dot": "Pontinhos", "eyes_happy": "Sorridentes"}

var cosmetics: Dictionary = {}       # id -> {slot, label, rarity, cost, ...}
var by_slot: Dictionary = {}         # slot -> [ids]
var enemy_anims: Dictionary = {}     # id -> manifesto do Blender
var kits: Dictionary = {}            # nome do kit -> manifesto

func _enter_tree() -> void:
	_load_cosmetics()
	_load_manifests()

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _load_cosmetics() -> void:
	cosmetics = _read_json("res://assets/models/hero_manifest.json")
	for id in EYE_NAMES:
		cosmetics[id] = {"slot": "eyes", "label": EYE_NAMES[id], "rarity": 0, "cost": 0}
	by_slot = {}
	for s in SLOT_ORDER:
		by_slot[s] = []
	for id in cosmetics:
		var c: Dictionary = cosmetics[id]
		c["rarity"] = int(c.get("rarity", 0))
		c["cost"] = int(c.get("cost", 0))
		if by_slot.has(c["slot"]):
			by_slot[c["slot"]].append(id)
	for s in by_slot:
		by_slot[s].sort_custom(func(a: String, b: String) -> bool:
			var ca: Dictionary = cosmetics[a]
			var cb: Dictionary = cosmetics[b]
			if ca["cost"] != cb["cost"]:
				return ca["cost"] < cb["cost"]
			return a < b)

func _load_manifests() -> void:
	enemy_anims = _read_json("res://assets/models/enemies_manifest.json")
	for k in ["env_forest", "env_hub", "env_crystal", "env_boss", "props"]:
		kits[k] = _read_json("res://assets/models/%s_manifest.json" % k)

func cosmetic_cost(id: String) -> int:
	return int(cosmetics.get(id, {}).get("cost", 0))

func cosmetic_label(id: String) -> String:
	if id == "":
		return "Nenhum"
	return str(cosmetics.get(id, {}).get("label", id))

func weapons_of(wt: String) -> Array:
	var out: Array = []
	for id in by_slot.get("weapon", []):
		if cosmetics[id].get("wt", "") == wt:
			out.append(id)
	return out

func default_weapon(wt: String) -> String:
	for id in weapons_of(wt):
		if cosmetic_cost(id) <= 0:
			return id
	var all := weapons_of(wt)
	return all[0] if all.size() > 0 else ""

func upgrade_cost(id: String, level: int) -> int:
	return int(UPGRADES[id]["cost"] * (1.0 + level * 0.75))

## Tempo de acerto de um ataque: usa o manifesto das animacoes se existir.
func enemy_attack(kind: String, index: int) -> Dictionary:
	var a: Dictionary = ENEMIES[kind]["atk"][index].duplicate()
	var man: Dictionary = enemy_anims.get(kind, {}).get("anims", {}).get(a["anim"], {})
	if man.has("hit"):
		a["hit"] = float(man["hit"])
	if man.has("len") and a["shape"] != "charge":
		a["len"] = max(float(man["len"]), float(a["hit"]) + 0.2)
	return a

func skill_name(id: String) -> String:
	return str(SKILLS.get(id, {}).get("name", id))

func item_def(id: String) -> Dictionary:
	if BOONS.has(id):
		return BOONS[id]
	if RELICS.has(id):
		return RELICS[id]
	if SKILLS.has(id):
		return SKILLS[id]
	return {}

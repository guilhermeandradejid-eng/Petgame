class_name Car
extends RigidBody3D
## Carro arcade com física de verdade em pista 3D: suspensão por raycast, "gruda" na pista (gravidade ao longo da
## normal do asfalto, para loopings e saca-rolhas), aderência lateral, drift, nitro por cargas, vida, armas e destruição.

signal hit(car: Car, other: Object, point: Vector3, dv: float)
signal part_off(car: Car, mesh: MeshInstance3D, xform: Transform3D, vel: Vector3, is_wheel: bool)
signal landed(car: Car, air_time: float, impact: float)
signal died(car: Car, killer: Car)

const SUSP := 0.38
# mola mais longa que o curso: em repouso o carro fica na altura do modelo (roda dentro da caixa de roda,
# sem a carroceria "sentar" em cima do pneu); o batente segura as compressões fortes
const PRELOAD := 0.11
const BUMP := 0.12
const WHEEL_UP := 0.05   # quanto a roda pode subir visualmente antes de encostar no para-lama
const GRAV := 9.8 * 2.2

const SPECS := {
	"faisca": {"len": 3.7, "wid": 2.0, "h": 0.62, "clr": 0.34, "mass": 1.0, "vmax": 40.0, "nitro": 58.0, "accel": 26.0, "grip": 9.5, "drift_grip": 1.6, "turn": 2.7, "hp": 100.0},
	"trovao": {"len": 4.1, "wid": 2.1, "h": 0.6, "clr": 0.3, "mass": 1.25, "vmax": 38.0, "nitro": 54.0, "accel": 23.0, "grip": 8.5, "drift_grip": 1.8, "turn": 2.45, "hp": 140.0},
	"vespa": {"len": 3.6, "wid": 2.0, "h": 0.58, "clr": 0.32, "mass": 0.95, "vmax": 42.0, "nitro": 58.0, "accel": 28.0, "grip": 10.0, "drift_grip": 1.7, "turn": 2.95, "hp": 80.0},
	"sedan": {"len": 3.9, "wid": 1.95, "h": 0.66, "clr": 0.3, "mass": 1.0, "vmax": 26.0, "nitro": 26.0, "accel": 12.0, "grip": 8.0, "drift_grip": 2.0, "turn": 2.2, "hp": 60.0},
	"taxi": {"len": 3.9, "wid": 1.95, "h": 0.66, "clr": 0.3, "mass": 1.0, "vmax": 26.0, "nitro": 26.0, "accel": 12.0, "grip": 8.0, "drift_grip": 2.0, "turn": 2.2, "hp": 60.0},
	"policia": {"len": 3.9, "wid": 1.95, "h": 0.66, "clr": 0.3, "mass": 1.1, "vmax": 30.0, "nitro": 30.0, "accel": 14.0, "grip": 8.0, "drift_grip": 2.0, "turn": 2.2, "hp": 70.0},
	"picape": {"len": 4.3, "wid": 2.1, "h": 0.8, "clr": 0.45, "mass": 1.5, "vmax": 24.0, "nitro": 24.0, "accel": 10.0, "grip": 8.0, "drift_grip": 2.0, "turn": 2.0, "hp": 80.0},
	"van": {"len": 4.4, "wid": 2.1, "h": 0.85, "clr": 0.35, "mass": 1.8, "vmax": 22.0, "nitro": 22.0, "accel": 9.0, "grip": 8.0, "drift_grip": 2.0, "turn": 1.9, "hp": 90.0},
	# picape monstro (comprável): pesada, resistente, menos ágil
	"monstro": {"len": 4.3, "wid": 2.1, "h": 0.8, "clr": 0.45, "mass": 1.45, "vmax": 39.0, "nitro": 52.0, "accel": 22.0, "grip": 9.2, "drift_grip": 1.9, "turn": 2.35, "hp": 175.0},
	# carros dos mundos (um por tema, modernos)
	"zefiro": {"len": 3.9, "wid": 2.05, "h": 0.6, "clr": 0.2, "mass": 1.0, "vmax": 41.5, "nitro": 58.0, "accel": 27.0, "grip": 10.0, "drift_grip": 1.6, "turn": 2.75, "hp": 95.0},
	"jacare": {"len": 4.2, "wid": 2.15, "h": 0.68, "clr": 0.5, "mass": 1.4, "vmax": 39.0, "nitro": 54.0, "accel": 23.0, "grip": 9.4, "drift_grip": 1.9, "turn": 2.4, "hp": 160.0},
	"escorpiao": {"len": 4.5, "wid": 2.25, "h": 0.63, "clr": 0.52, "mass": 1.35, "vmax": 41.0, "nitro": 56.0, "accel": 25.0, "grip": 9.6, "drift_grip": 1.8, "turn": 2.45, "hp": 150.0},
	"nevasca": {"len": 3.95, "wid": 2.1, "h": 0.64, "clr": 0.42, "mass": 1.3, "vmax": 40.5, "nitro": 56.0, "accel": 25.0, "grip": 10.4, "drift_grip": 1.8, "turn": 2.6, "hp": 145.0},
	"nemesis": {"len": 4.3, "wid": 2.2, "h": 0.59, "clr": 0.15, "mass": 1.2, "vmax": 43.5, "nitro": 60.0, "accel": 29.0, "grip": 10.8, "drift_grip": 1.7, "turn": 2.65, "hp": 120.0},
	"falcao": {"len": 4.2, "wid": 1.95, "h": 0.56, "clr": 0.24, "mass": 1.05, "vmax": 44.0, "nitro": 61.0, "accel": 29.0, "grip": 10.6, "drift_grip": 1.6, "turn": 2.75, "hp": 110.0},
	# chefes (modelos ampliados 1,6x; vida alta, pesados)
	"hyper": {"len": 4.1, "wid": 2.15, "h": 0.66, "clr": 0.18, "mass": 1.3, "vmax": 44.0, "nitro": 58.0, "accel": 28.0, "grip": 10.5, "drift_grip": 1.7, "turn": 2.6, "hp": 120.0},
	"boss_brutus": {"len": 6.6, "wid": 3.45, "h": 1.06, "clr": 0.29, "mass": 4.0, "vmax": 41.0, "nitro": 50.0, "accel": 24.0, "grip": 10.0, "drift_grip": 2.4, "turn": 2.2, "hp": 1100.0},
	"boss_xerife": {"len": 6.2, "wid": 3.1, "h": 1.05, "clr": 0.48, "mass": 3.2, "vmax": 42.0, "nitro": 54.0, "accel": 26.0, "grip": 10.5, "drift_grip": 2.2, "turn": 2.4, "hp": 1300.0},
	"boss_croc": {"len": 6.9, "wid": 3.4, "h": 1.3, "clr": 0.77, "mass": 3.8, "vmax": 41.5, "nitro": 52.0, "accel": 24.0, "grip": 10.5, "drift_grip": 2.2, "turn": 2.3, "hp": 1250.0},
	"boss_avalanche": {"len": 5.8, "wid": 3.4, "h": 1.0, "clr": 0.82, "mass": 3.2, "vmax": 42.5, "nitro": 54.0, "accel": 26.0, "grip": 10.5, "drift_grip": 2.2, "turn": 2.5, "hp": 1350.0},
	"boss_blackout": {"len": 6.2, "wid": 3.1, "h": 1.05, "clr": 0.42, "mass": 3.0, "vmax": 43.5, "nitro": 56.0, "accel": 27.0, "grip": 11.0, "drift_grip": 2.2, "turn": 2.6, "hp": 1450.0},
	"boss_imperador": {"len": 6.6, "wid": 3.4, "h": 0.96, "clr": 0.48, "mass": 3.6, "vmax": 43.0, "nitro": 56.0, "accel": 28.0, "grip": 11.0, "drift_grip": 2.2, "turn": 2.5, "hp": 1500.0},
}
## modelo 3D de cada tipo (os chefes e a Monstro reaproveitam modelos, ampliados ou não)
const MODEL := {"monstro": "picape", "boss_brutus": "hyper", "boss_xerife": "policia", "boss_imperador": "trovao",
	"boss_croc": "picape", "boss_avalanche": "vespa", "boss_blackout": "sedan"}
const VSCALE := {"boss_brutus": 1.6, "boss_xerife": 1.6, "boss_imperador": 1.6, "boss_croc": 1.6, "boss_avalanche": 1.7, "boss_blackout": 1.6}
## cada carro tem armas próprias (estilo Rock n' Roll Racing): [arma de ataque, item de chão, mobilidade]
## a mobilidade fica no botão do NITRO; o ESPECIAL (escudo, choque, reparo) tem botão próprio e é comprado à parte
const LOADOUT := {"faisca": ["mg", "oil", "short"], "vespa": ["zap", "spikes", "jump"],
	"trovao": ["rocket", "mine", "long"], "monstro": ["flame", "barrel", "ram"],
	"zefiro": ["laser", "smoke", "dash"], "jacare": ["harpoon", "mud", "long"], "escorpiao": ["mortar", "fire", "jump"],
	"nevasca": ["freeze", "ice", "short"], "nemesis": ["railgun", "emp", "dash"], "falcao": ["plasma", "vortex", "glide"]}
const SPECIAL := {"shield": {"name": "Escudo", "cap": 2, "label": "ESCUDO"}, "shock": {"name": "Onda de choque", "cap": 2, "label": "CHOQUE"},
	"repair": {"name": "Reparo", "cap": 1, "label": "REPARO"}}
const SPECIAL_ORDER := ["shield", "shock", "repair"]

## equipamentos: valores base por volta (Rock n' Roll Racing: recarregam a cada volta)
const FRONT := {"mg": {"name": "Metralhadora", "cap": 60, "up": 15}, "rocket": {"name": "Lança-foguetes", "cap": 4, "up": 1},
	"zap": {"name": "Raio elétrico", "cap": 10, "up": 3}, "flame": {"name": "Lança-chamas", "cap": 60, "up": 15},
	"laser": {"name": "Canhão laser", "cap": 40, "up": 10}, "harpoon": {"name": "Arpão", "cap": 4, "up": 1},
	"mortar": {"name": "Morteiro", "cap": 5, "up": 1}, "freeze": {"name": "Canhão de gelo", "cap": 8, "up": 2},
	"railgun": {"name": "Canhão de trilho", "cap": 4, "up": 1}, "plasma": {"name": "Plasma", "cap": 24, "up": 6},
	"none": {"name": "—", "cap": 0, "up": 0}}
## torres articuladas (peças wb_/wy_/wg_/ws_ do minicars.glb): pivô da peça que gira, eixo do giro e boca da arma,
## em coordenadas do corpo da arma. Yaw fica 0,2 acima da base; o corpo, 0,26 acima do yaw.
const WPN := {
	"mg": {"spin": Vector3(0, 0, 0.32), "axis": Vector3(0, 0, 1), "muz": Vector3(0, 0, 1.05), "spd": 34.0},
	"rocket": {"muz": Vector3(0, 0.02, 0.45)}, "zap": {"spin": Vector3(0, 0.2, -0.06), "axis": Vector3(0, 1, 0), "muz": Vector3(0, 0.03, 0.52), "spd": 2.5},
	"flame": {"muz": Vector3(0, 0.02, 0.85)}, "laser": {"muz": Vector3(0, 0, 0.72)}, "harpoon": {"muz": Vector3(0, 0.08, 0.78)},
	"mortar": {"muz": Vector3(0, 0.38, 0.4), "pitch": 0.0}, "freeze": {"muz": Vector3(0, 0.02, 0.58)}, "railgun": {"muz": Vector3(0, 0, 0.85)},
	"plasma": {"spin": Vector3(0, 0.06, 0.05), "axis": Vector3(0, 0, 1), "muz": Vector3(0, 0.03, 0.5), "spd": 3.0}}
const WPN_YAW := 0.6        # quanto a torre gira para cada lado (rad)
## rótulos curtos (botões na tela e HUD) e nomes dos carros jogáveis
const LBL_F := {"mg": "TIRO", "rocket": "FOGUETE", "zap": "RAIO", "flame": "FOGO", "laser": "LASER", "harpoon": "ARPÃO",
	"mortar": "MORTEIRO", "freeze": "GELO", "railgun": "TRILHO", "plasma": "PLASMA", "none": "—"}
const LBL_R := {"mine": "MINA", "oil": "ÓLEO", "spikes": "PREGOS", "barrel": "BARRIL", "smoke": "FUMAÇA", "mud": "LAMA",
	"fire": "FOGO", "ice": "GELO", "emp": "EMP", "vortex": "VÓRTICE", "none": "—"}
const PLAYABLE := ["faisca", "vespa", "zefiro", "jacare", "trovao", "escorpiao", "monstro", "nevasca", "nemesis", "falcao"]
const CAR_NAME := {"faisca": "FAÍSCA", "vespa": "VESPA", "trovao": "TROVÃO", "monstro": "MONSTRO", "zefiro": "ZÉFIRO",
	"jacare": "JACARÉ", "escorpiao": "ESCORPIÃO", "nevasca": "NEVASCA", "nemesis": "NÊMESIS", "falcao": "FALCÃO"}
const REAR := {"mine": {"name": "Minas", "cap": 3, "up": 1}, "oil": {"name": "Óleo", "cap": 3, "up": 1},
	"spikes": {"name": "Pregos", "cap": 3, "up": 1}, "barrel": {"name": "Barril rolante", "cap": 3, "up": 1},
	"smoke": {"name": "Cortina de fumaça", "cap": 3, "up": 1}, "mud": {"name": "Poça de lama", "cap": 3, "up": 1},
	"fire": {"name": "Rastro de fogo", "cap": 3, "up": 1}, "ice": {"name": "Placa de gelo", "cap": 3, "up": 1},
	"emp": {"name": "Mina EMP", "cap": 2, "up": 1}, "vortex": {"name": "Vórtice", "cap": 2, "up": 1},
	"none": {"name": "—", "cap": 0, "up": 0}}
## mobilidade (botão do nitro): nitro curto, nitro longo, salto e investida (arrancada que atropela quem estiver na frente)
const NITRO := {"short": {"name": "Nitro curto", "cap": 4, "dur": 1.0, "acc": 2.3, "label": "NITRO"},
	"long": {"name": "Nitro longo", "cap": 3, "dur": 2.2, "acc": 1.8, "label": "NITRO"},
	"jump": {"name": "Salto", "cap": 3, "dur": 0.0, "acc": 0.0, "label": "SALTO"},
	"ram": {"name": "Investida", "cap": 3, "dur": 0.75, "acc": 3.4, "label": "INVESTIDA"},
	"dash": {"name": "Esquiva", "cap": 4, "dur": 0.0, "acc": 0.0, "label": "ESQUIVA"},
	"glide": {"name": "Planar", "cap": 3, "dur": 0.0, "acc": 0.0, "label": "PLANAR"}}

var kind := ""
var role := "traffic"       # player | rival | traffic
var human := false          # dirigido por uma pessoa (local ou de outra máquina)
var net_remote := false     # simulado em outra máquina: aqui só recebe o estado pela rede
var owner_id := 0           # id de rede de quem simula este carro (0 = offline)
var slot := -1              # posição no grid / índice na corrida em rede
var local_idx := -1         # jogador local (0..3) que controla este carro
var net_buf: Array = []     # estados recebidos [t, xform, vel, ...] para interpolar
var display_name := ""
var sp: Dictionary
var color := Color.RED
var ctrl := {"steer": 0.0, "throttle": 0.0, "brake": 0.0, "drift": false, "nitro": false, "fire": false, "drop": false, "special": false, "dir": null, "dir_mag": 0.0}

# equipamento e munição
var front_type := "mg"
var rear_type := "mine"
var nitro_type := "short"
var special_type := ""      # especial comprado (botão próprio): "" | shield | shock | repair
var spec_cap := 0
var spec_ch := 0
var dmg_mult := 1.0         # upgrade DANO da arma de ataque
var rate_mult := 1.0        # upgrade CADÊNCIA: atira mais rápido e o projétil voa mais rápido
var mkind := ""             # modelo 3D usado
var vscale := 1.0           # escala visual (chefes)
var is_boss := false
var shield_t := 0.0
var flat_t := 0.0           # pneus furados (pregos): mais lento e escorregando
var burn_t := 0.0           # pegando fogo (lança-chamas / muro de fogo)
var burn_by: Car = null
var ice_t := 0.0            # no gelo (chefe AVALANCHE): quase sem aderência
var emp_t := 0.0            # pulso EMP (chefe BLACKOUT): armas e especial desligados
var mud_t := 0.0            # atolado na lama (chefe CROCODILO)
var slow_t := 0.0           # levando tiro de metralhadora: perde um pouco de velocidade
var glide_t := 0.0          # planando (Falcão): cai devagar
var special_cd := 0.0
var game: Node = null
var _burn_acc := 0.0
var front_cap := 60
var rear_cap := 3
var nitro_cap := 4
var ammo_f := 60
var ammo_r := 3
var nitro_ch := 4
var nitro_t := 0.0
var nitro_meter := 0.0        # manobras enchem: cheio = +1 carga
var fire_cd := 0.0
var drop_cd := 0.0
var engine_mult := 1.0
var max_health := 100.0
var health := 100.0
var grav_factor := 1.0
var grip_factor := 1.0
var tire_grip := 1.0      # upgrade PNEUS: +6% de aderência por nível
var tire_kind := ""
var _mat_cache := {}
static var _tire_cache := {}
static var refl_metal: Material = null   # passada de reflexo do metal (criada pelo main.gd)
const WHEEL_W := {"faisca": 0.5, "trovao": 0.52, "vespa": 0.5, "picape": 0.5, "zefiro": 0.48, "jacare": 0.5, "escorpiao": 0.55,
	"nevasca": 0.5, "nemesis": 0.52, "falcao": 0.48, "hyper": 0.5}
const OFFROAD := ["picape", "jacare", "escorpiao", "nevasca"]   # pneus com cravos e para-barros no kit
## pneu por nível do upgrade: rua -> esportivo (perfil baixo) -> slick de corrida (nível 3: faixa na cor do kit)
const TIRE_BY_LEVEL := ["street", "sport", "slick", "slick"]
var _nitro_was := false
var _spec_was := false
var _drop_was := false

var nitroing := false
var v_f := 0.0
var v_s := 0.0
var steer_s := 0.0
var drifting := false
var drift_dir := 0.0
var drift_t := 0.0
var drift_slip := 0.0
var on_ground := true
var on_road := false
var ground_n := Vector3.UP
var ground_pt := Vector3.ZERO
var air_t := 0.0
var stun := 0.0
var oil_t := 0.0
var invuln := 0.0
var wrecked := false
var wreck_t := 0.0
var last_hit_by: Car = null
var last_hit_t := -10.0
var game_time := 0.0
var flash_t := 0.0
var turn_mult := 1.0
var _uturn := 0.0
# informação da pista (preenchida pelo jogo a cada passo)
var track_up := Vector3.UP
var on_feature := false
var feat_type := ""
var track_left := Vector3.RIGHT
var track_tan := Vector3.FORWARD
var in_loop := false
var h_surf := 0.0
var road_half := 9.0
var track_ref: Track = null
var guided_spd := 0.0
var guided_now := false
var _gs := 0.0   # distância ao longo da pista integrada no trecho guiado (sem saltos de reprojeção)
var exit_assist := 0.0   # logo após loop/saca-rolhas: a direção se alinha à pista (sem guinada na saída)
var _susp_forces := true
var jump_cd := 0.0
var _jump_armed := true
var launch_t := 0.0     # largada: pneus cantando e fumaça
var fall_t := 0.0
var oily_t := 0.0      # pneus sujos de graxa: deixam rastro escuro por um tempo
var _hard_t := 0.0      # tempo de curva forte (auto-drift)
var _dh := 0.0
# "game juice" visual: amassa ao pousar, estica e empina no nitro (mola amortecida, só no modelo)
var eng_rpm := 0.0           # rotação do motor (0..1) para a vibração e o escapamento
var _thr_prev := 0.0
var ex_smoke: Array = []      # fumaça saindo das ponteiras
var squash := 0.0
var squash_v := 0.0
var pitch_kick := 0.0
var pitch_v := 0.0
var _nitro_vis := false
var ghost_t := 0.0   # nos trechos guiados os carros se atravessam (sem engavetar nem "estourar" na saída)

# IA / pista
var oncoming := false
var lane := -2.75
var lane_t := -2.75
var lane_cur := -2.75
var cruise := 18.0
var rubber := 1.0
var seed_f := 0.0
var next_bash := 5.0
var lane_switch_t := 0.0
var ai_skill := 1.0
var ti := -1
var s_track := 0.0
var lat := 0.0
var h_track := 0.0
var dist := 0.0
var prev_s := 0.0
var lap := 0
var nm_state = null
var pad_t := 0.0
var off_t := 0.0
var stuck_t := 0.0
var finished := false
var kills := 0

var model: Node3D
var wheels: Array = []
var parts: Dictionary = {}
var tier := 0                 # nível visual (0 = de fábrica .. 3 = elite), pela soma dos upgrades
var _kit: Array = []
const TIER_ACCENT := [Color("#d8dbe2"), Color("#ffffff"), Color("#ffcf33"), Color("#2ee6ff")]
const TIER_RIM := [Color("#c9ccd4"), Color("#202227"), Color("#b0703a"), Color("#f2c230")]
var paint: StandardMaterial3D
var tail_mat: StandardMaterial3D
var sirens: Array = []
var exhaust_local := Vector3.ZERO
var exhaust2_local := Vector3.ZERO
var mount_local := Vector3.ZERO
var tail_local := [Vector3.ZERO, Vector3.ZERO]
var muzzle_local := Vector3.ZERO
var weapon_node: Node3D
var wpn_yaw: Node3D
var wpn_gun: Node3D
var wpn_spin: Node3D
var wpn_gun_mesh: MeshInstance3D
var wpn_smoke: CPUParticles3D
var aim_tgt: Car = null
var aim_yaw := 0.0
var aim_pitch := 0.0
var spin_v := 0.0
var weapon_base := Vector3.ZERO
var recoil := 0.0
var firing_t := 0.0
var casings: CPUParticles3D
var hbar: MeshInstance3D

var _prev_v := Vector3.ZERO
var _applied := Vector3.ZERO
var _contacts: Array = []
var _teleport = null
var _dent_cd := 0.0
var _k := 0.0
var _c := 0.0
var scraping := false
var scrape_pt := Vector3.ZERO
var scrape_n := Vector3.UP
var scrape_v := Vector3.ZERO


func setup(lib: Node3D, kind_: String, role_: String, col: Color) -> void:
	kind = kind_
	role = role_
	color = col
	sp = SPECS[kind]
	mass = 1000.0 * sp.mass
	gravity_scale = 0.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.3, 0)   # centro de massa baixo: mais "peso", difícil de capotar
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 6
	angular_damp = 1.2
	linear_damp = 0.02
	can_sleep = false
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	var pm := PhysicsMaterial.new()
	pm.friction = 0.25
	pm.bounce = 0.02
	physics_material_override = pm
	max_health = sp.hp
	health = max_health

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(sp.wid * 0.94, sp.h + 0.45, sp.len * 0.96)
	cs.shape = box
	cs.position = Vector3(0, sp.clr + (sp.h + 0.45) * 0.5 + 0.02, 0)
	add_child(cs)

	mkind = String(MODEL.get(kind, kind))
	vscale = float(VSCALE.get(kind, 1.0))
	is_boss = kind.begins_with("boss_")
	model = lib.get_node("car_" + mkind).duplicate()
	model.transform = Transform3D.IDENTITY
	add_child(model)
	var mat_cache := _mat_cache
	for ch in model.get_children():
		if not (ch is MeshInstance3D):
			continue
		var mi: MeshInstance3D = ch
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mats: Array = []
		for s in mi.mesh.get_surface_count():
			mats.append(_car_mat(mi.mesh.surface_get_material(s), mat_cache))
			mi.set_surface_override_material(s, mats[s])
		var part_name := String(mi.name).substr(mkind.length() + 1)
		if part_name.begins_with("w") and part_name.length() == 3:
			wheels.append({"mesh": mi, "base": mi.position, "front": mi.position.z > 0, "r": mi.position.y,
				"spin": 0.0, "dist": SUSP + mi.position.y, "contact": false, "lost": false, "name": part_name})
		else:
			var arrays: Array = []
			for s in mi.mesh.get_surface_count():
				arrays.append(mi.mesh.surface_get_arrays(s))
			parts[part_name] = {"mesh": mi, "orig": mi.mesh, "arrays": arrays, "mats": mats, "hp": 100.0, "off": false,
				"center": mi.transform * mi.mesh.get_aabb().get_center(), "base": mi.position, "rot": mi.rotation}
	_apply_tires(lib, {})
	var Lc: float = sp.len
	var Wc: float = sp.wid
	exhaust_local = Vector3(Wc * 0.26, sp.clr - 0.03, -(Lc * 0.5 + 0.38))
	exhaust2_local = Vector3(-Wc * 0.26, sp.clr - 0.03, -(Lc * 0.5 + 0.38))
	mount_local = Vector3(0, sp.clr + sp.h + 0.6, -0.2)
	# pontos marcados no modelo (Blender): ponteiras do escapamento e base da arma no teto
	var exr := model.get_node_or_null(mkind + "_exR") as Node3D
	var exl := model.get_node_or_null(mkind + "_exL") as Node3D
	var mnt := model.get_node_or_null(mkind + "_mount") as Node3D
	if exr:
		exhaust_local = exr.position * vscale
	if exl:
		exhaust2_local = exl.position * vscale
	if mnt:
		mount_local = mnt.position
	# fumaça do escapamento (sai das ponteiras abertas; engrossa ao acelerar)
	ex_smoke.clear()
	if role != "traffic" or true:
		for exn in [exr, exl]:
			if exn:
				ex_smoke.append(_exhaust_smoke(exn.position))
	if vscale != 1.0:
		# chefe: modelo ampliado; a física usa as rodas na escala nova (o visual continua no espaço do modelo)
		model.scale = Vector3.ONE * vscale
		for w in wheels:
			w.vbase = w.base
			w.base = (w.base as Vector3) * vscale
			w.r = float(w.r) * vscale
			w.dist = SUSP + float(w.r)
	var tz: float = sp.clr + sp.h * 0.65
	tail_local = [Vector3(-Wc * 0.32, tz, -Lc * 0.5), Vector3(Wc * 0.32, tz, -Lc * 0.5)]
	muzzle_local = Vector3(0, sp.clr + sp.h + 0.55, Lc * 0.5 + 0.4)
	_k = mass * GRAV / 4.0 / 0.13
	_c = 2.0 * sqrt(_k * mass / 4.0) * 0.55
	if role != "traffic":
		hbar = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2.4, 0.26)
		hbar.mesh = q
		var hm := ShaderMaterial.new()
		hm.shader = load("res://shaders/hbar.gdshader")
		hm.set_shader_parameter("col", color)
		hbar.material_override = hm
		hbar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hbar.position = Vector3(0, 2.6, 0)
		hbar.visible = false
		add_child(hbar)


## arma visível no teto + capacidades por equipamento e upgrades
func configure(lib: Node3D, front: String, rear: String, nitro: String, up: Dictionary, special := "") -> void:
	front_type = front if FRONT.has(front) else "none"
	rear_type = rear if REAR.has(rear) else "none"
	front = front_type
	nitro_type = nitro if NITRO.has(nitro) else "short"
	special_type = special if SPECIAL.has(special) else ""
	front_cap = int(FRONT[front].cap) + int(FRONT[front].up) * int(up.get("ammo", 0))
	rear_cap = int(REAR[rear_type].cap) + int(REAR[rear_type].up) * int(up.get("rear", up.get("ammo", 0)))
	nitro_cap = int(NITRO[nitro_type].cap) + int(up.get("nitro", 0))
	spec_cap = int(SPECIAL[special_type].cap) if special_type != "" else 0
	dmg_mult = 1.0 + 0.25 * int(up.get("dmg", 0))
	rate_mult = 1.0 + 0.22 * int(up.get("rate", 0))
	engine_mult = 1.0 + 0.04 * int(up.get("engine", 0))
	max_health = sp.hp * (1.0 + 0.2 * int(up.get("armor", 0)))
	health = max_health
	refill()
	_build_weapon(lib, front)
	_apply_tires(lib, up)
	_build_kit(up)


## torre da arma parafusada no teto (ponto "_mount" do modelo): base fixa, anel que gira (mira), corpo que
## recua e peça giratória (canos rotativos, gaiola do plasma), com fumaça na boca e efeitos próprios de cada arma
func _build_weapon(lib: Node3D, front: String) -> void:
	if weapon_node:
		weapon_node.queue_free()
	wpn_yaw = null
	wpn_gun = null
	wpn_spin = null
	wpn_gun_mesh = null
	wpn_smoke = null
	casings = null
	weapon_base = mount_local
	weapon_node = Node3D.new()
	weapon_node.position = weapon_base
	model.add_child(weapon_node)
	if front == "none" or not WPN.has(front):
		weapon_node.visible = false
		muzzle_local = weapon_base + Vector3(0, 0.5, 0.6)
		return
	var cfg: Dictionary = WPN[front]
	_wpn_mesh(lib, "wb_" + front, weapon_node)
	wpn_yaw = Node3D.new()
	wpn_yaw.position = Vector3(0, 0.2, 0)
	weapon_node.add_child(wpn_yaw)
	_wpn_mesh(lib, "wy_" + front, wpn_yaw)
	wpn_gun = Node3D.new()
	wpn_gun.position = Vector3(0, 0.26, 0)
	wpn_yaw.add_child(wpn_gun)
	wpn_gun_mesh = _wpn_mesh(lib, "wg_" + front, wpn_gun)
	if cfg.has("spin") and lib.get_node_or_null("ws_" + front):
		wpn_spin = Node3D.new()
		wpn_spin.position = cfg.spin
		wpn_gun.add_child(wpn_spin)
		_wpn_mesh(lib, "ws_" + front, wpn_spin)
	var muz: Vector3 = cfg.muz
	# fumaça na boca ao atirar
	wpn_smoke = _wpn_particles(muz, Color(0.75, 0.75, 0.78, 0.5), 10, 0.6, Vector3(0, 1.2, 0.6), 0.09, false)
	match front:
		"zap":
			_wpn_particles(Vector3(0, 0.42, -0.06), Color(0.5, 0.9, 1.0), 6, 0.25, Vector3(0, 0.4, 0), 0.03, true, 1.6)
		"flame":
			_wpn_particles(muz, Color(1.0, 0.55, 0.15), 8, 0.22, Vector3(0, 0.6, 0.2), 0.035, true, 2.5)
		"freeze":
			_wpn_particles(muz, Color(0.85, 0.95, 1.0, 0.7), 8, 0.8, Vector3(0, -0.4, 0.2), 0.04, true)
		"plasma":
			_wpn_particles(Vector3(0, 0.06, 0.05), Color(0.4, 1.0, 0.5), 6, 0.4, Vector3(0, 0.3, 0), 0.03, true, 2.0)
		"railgun":
			_wpn_particles(Vector3(0, 0.0, 0.4), Color(0.75, 0.45, 1.0), 5, 0.3, Vector3(0, 0.2, 0), 0.025, true, 2.0)
	muzzle_local = _muzzle_now()


func _wpn_mesh(lib: Node3D, nm: String, parent: Node3D) -> MeshInstance3D:
	var src := lib.get_node_or_null(nm) as MeshInstance3D
	if src == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = src.mesh
	for si in mi.mesh.get_surface_count():
		mi.set_surface_override_material(si, _car_mat(mi.mesh.surface_get_material(si), _mat_cache))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


## partículas da arma (presas no corpo da arma, soltas no mundo): fumaça, faíscas, chama piloto, névoa
func _wpn_particles(at: Vector3, col: Color, n: int, life: float, vel: Vector3, sz: float, always: bool, glow := 0.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.local_coords = false
	p.emitting = always
	p.position = at
	var m := SphereMesh.new()
	m.radius = sz
	m.height = sz * 2.0
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	if glow > 0.0:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(col.r * glow, col.g * glow, col.b * glow, col.a)
	m.material = mat
	p.mesh = m
	p.direction = vel.normalized() if vel.length() > 0.0 else Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = vel.length() * 0.6
	p.initial_velocity_max = vel.length() * 1.2
	p.gravity = Vector3(0, 0.6 if vel.y >= 0.0 else -1.5, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wpn_gun.add_child(p)
	return p


## boca da arma em coordenadas do carro (segue o giro e o recuo da torre)
func _muzzle_now() -> Vector3:
	if wpn_gun == null:
		return muzzle_local
	var muz: Vector3 = WPN[front_type].muz
	return model.transform * weapon_node.transform * wpn_yaw.transform * wpn_gun.transform * muz


## direção para onde a arma aponta (mundo)
func gun_dir() -> Vector3:
	if wpn_gun and wpn_gun.is_inside_tree():
		return wpn_gun.global_transform.basis.z.normalized()
	return global_transform.basis.z


## mira da torre (visual): segue o alvo dentro do arco; sem alvo, varre devagar
func _aim_turret(dt: float) -> void:
	if wpn_yaw == null:
		return
	var want_y := sin(game_time * 0.7 + seed_f) * 0.2
	var want_p := 0.0
	if aim_tgt != null and is_instance_valid(aim_tgt) and not aim_tgt.wrecked:
		var lp := global_transform.affine_inverse() * aim_tgt.global_position - (weapon_base + Vector3(0, 0.46, 0))
		want_y = clampf(atan2(lp.x, lp.z), -WPN_YAW, WPN_YAW)
		want_p = clampf(atan2(lp.y + 0.3, Vector2(lp.x, lp.z).length()), -0.12, 0.3)
	if front_type == "mortar":
		want_p = 0.0
	var k := 1.0 - exp(-7.0 * dt)
	aim_yaw = lerp_angle(aim_yaw, want_y, k)
	aim_pitch = lerpf(aim_pitch, want_p, k)
	wpn_yaw.rotation.y = aim_yaw
	wpn_gun.rotation.x = -aim_pitch - recoil * 0.07
	wpn_gun.position = Vector3(0, 0.26 + recoil * 0.02, -recoil * 0.13)
	if wpn_spin:
		var cfg: Dictionary = WPN[front_type]
		var base_spd: float = 0.0 if front_type == "mg" else float(cfg.get("spd", 0.0))
		spin_v = move_toward(spin_v, float(cfg.get("spd", 0.0)) if firing_t > 0.0 else base_spd, dt * 60.0)
		wpn_spin.rotate_object_local(cfg.axis, spin_v * dt)
	if wpn_smoke:
		wpn_smoke.emitting = firing_t > 0.0 and not wrecked
	muzzle_local = _muzzle_now()


## (antigo) visual das armas: bobina elétrica e tanques — substituído pelas torres do modelo
func _weapon_extra(front: String) -> void:
	var em := StandardMaterial3D.new()
	em.emission_enabled = true
	if front == "zap":
		em.albedo_color = Color(0.4, 0.9, 1.0)
		em.emission = Color(0.35, 0.85, 1.0)
		em.emission_energy_multiplier = 3.0
		var coil := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		coil.mesh = sm
		coil.material_override = em
		coil.position = Vector3(0, 0.62, 0.2)
		weapon_node.add_child(coil)
		for i in 3:
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.12 + i * 0.03
			tm.outer_radius = 0.17 + i * 0.03
			ring.mesh = tm
			var rm := StandardMaterial3D.new()
			rm.albedo_color = Color(0.75, 0.55, 0.3)
			rm.metallic = 1.0
			rm.roughness = 0.3
			ring.material_override = rm
			ring.position = Vector3(0, 0.3 + i * 0.1, 0.2)
			weapon_node.add_child(ring)
	else:
		em.albedo_color = Color(1.0, 0.5, 0.1)
		em.emission = Color(1.0, 0.45, 0.1)
		em.emission_energy_multiplier = 1.5
		for sx: float in [-0.32, 0.32]:
			var tank := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.16
			cm.bottom_radius = 0.16
			cm.height = 0.9
			tank.mesh = cm
			var tmat := StandardMaterial3D.new()
			tmat.albedo_color = Color(0.85, 0.12, 0.08)
			tmat.metallic = 0.5
			tmat.roughness = 0.35
			tank.material_override = tmat
			tank.rotation.x = PI / 2
			tank.position = Vector3(sx, 0.18, -0.35)
			weapon_node.add_child(tank)
		var pilot := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.08
		ps.height = 0.16
		pilot.mesh = ps
		pilot.material_override = em
		pilot.position = Vector3(0, 0.32, 1.15)
		weapon_node.add_child(pilot)


## troca a malha das rodas pela variante de pneu (modelo padrão do Blender, ajustado ao tamanho de cada roda)
func _apply_tires(lib: Node3D, up: Dictionary) -> void:
	var lvl := int(up.get("tires", 0))
	tire_grip = 1.0 + 0.06 * lvl
	var vis := int(up.get("_tire_vis", lvl))
	var k: String = "knobby" if mkind in OFFROAD else String(TIRE_BY_LEVEL[clampi(vis, 0, 3)])
	if k == tire_kind:
		return
	var src := lib.get_node_or_null("tire_" + k) as MeshInstance3D
	if src == null:
		return
	tire_kind = k
	var ww: float = WHEEL_W.get(mkind, 0.42)
	for w in wheels:
		var mi: MeshInstance3D = w.mesh
		var side := 1.0 if (w.base as Vector3).x >= 0.0 else -1.0
		mi.mesh = _tire_mesh(src.mesh, k, float(w.r), ww, side)
		for si in mi.mesh.get_surface_count():
			mi.set_surface_override_material(si, _car_mat(mi.mesh.surface_get_material(si), _mat_cache))


static func _tire_mesh(src: Mesh, k: String, r: float, ww: float, side: float) -> ArrayMesh:
	var key := "%s_%.3f_%.3f_%d" % [k, r, ww, int(side)]
	if _tire_cache.has(key):
		return _tire_cache[key]
	var sx := ww / 0.5 * side
	var sr := r / 0.5
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var arr := src.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in v.size():
			v[i] = Vector3(v[i].x * sx, v[i].y * sr, v[i].z * sr)
		for i in nr.size():
			nr[i] = Vector3(nr[i].x / sx, nr[i].y / sr, nr[i].z / sr).normalized()
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nr
		arr[Mesh.ARRAY_TANGENT] = null   # materiais usam mapeamento triplanar (não precisam de tangente)
		if side < 0.0 and arr[Mesh.ARRAY_INDEX] != null:
			# espelhado: inverte a ordem dos triângulos para as faces continuarem viradas para fora
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			for t in range(0, idx.size() - 2, 3):
				var tmp := idx[t + 1]
				idx[t + 1] = idx[t + 2]
				idx[t + 2] = tmp
			arr[Mesh.ARRAY_INDEX] = idx
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, src.surface_get_material(si))
	_tire_cache[key] = out
	return out


func refill() -> void:
	ammo_f = front_cap
	ammo_r = rear_cap
	nitro_ch = nitro_cap
	spec_ch = spec_cap


func _car_mat(m: Material, cache: Dictionary) -> Material:
	if m == null:
		return m
	if cache.has(m):
		return cache[m]
	var out := m
	var nm := m.resource_name
	if nm == "Paint" or nm == "Taillight" or nm.begins_with("Siren"):
		out = m.duplicate()
		if nm == "Paint":
			(out as StandardMaterial3D).albedo_color = color
			(out as StandardMaterial3D).emission_enabled = true
			(out as StandardMaterial3D).emission = Color.WHITE
			(out as StandardMaterial3D).emission_energy_multiplier = 0.0
			paint = out
		elif nm == "Taillight":
			tail_mat = out
		else:
			sirens.append(out)
	cache[m] = out
	return out


# ------------------------------------------------------------------ física
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _teleport != null:
		state.transform = _teleport.xform
		state.linear_velocity = _teleport.vel
		state.angular_velocity = Vector3.ZERO
		_teleport = null
		call_deferred("reset_physics_interpolation")
		_prev_v = state.linear_velocity
	_contacts.clear()
	for i in state.get_contact_count():
		_contacts.append([state.get_contact_collider_object(i), state.get_contact_local_position(i), state.get_contact_local_normal(i)])


func _physics_process(dt: float) -> void:
	game_time += dt
	_visuals(dt)
	_dent_cd = maxf(0.0, _dent_cd - dt)
	flash_t = maxf(0.0, flash_t - dt)
	fire_cd = maxf(0.0, fire_cd - dt)
	drop_cd = maxf(0.0, drop_cd - dt)
	_detect_impacts(dt)
	_applied = Vector3.ZERO
	if freeze:
		air_t = 0.0
		on_ground = true
		_prev_v = Vector3.ZERO
		return
	if wrecked:
		collision_layer = 2
		collision_mask = 1 | 2 | 4
		ghost_t = 0.0
		wreck_t += dt
		var f := Vector3.DOWN * GRAV * grav_factor * mass
		apply_central_force(f)
		_applied += f
		_suspension(true)
		return
	invuln = maxf(0.0, invuln - dt)
	stun = maxf(0.0, stun - dt)
	oil_t = maxf(0.0, oil_t - dt)
	_wall_hold()
	var guided := on_feature and (in_loop or feat_type == "cork") and h_surf < 3.0 and h_surf > -1.5 and track_ref != null
	_susp_forces = not guided
	guided_now = guided
	var grounded := _suspension(false)
	_susp_forces = true
	var was_ground := on_ground
	on_ground = grounded >= 2
	jump_cd = maxf(0.0, jump_cd - dt)
	if on_ground:
		_jump_armed = true
	elif _jump_armed and feat_type == "jump" and track_ref != null and jump_cd <= 0.0:
		_jump_assist()
	# "ímã" de pista nos loopings, espirais e saca-rolhas (arcade, estilo pista de brinquedo)
	var magnet := on_feature and h_surf < 2.6 and h_surf > -1.2 and linear_velocity.length() > 6.0
	if magnet and h_surf < 1.5:
		on_ground = true
		on_road = true
		ground_n = ground_n.lerp(track_up, 0.6).normalized()
	# no trecho guiado a carroceria não colide com o asfalto (as rodas continuam lendo a pista):
	# assim nenhuma emenda ou quina do colisor segura o carro. Os carros também viram "fantasmas"
	# entre si (camada 16) ali e por meio segundo depois, para não se empurrarem para fora da pista.
	ghost_t = 0.5 if guided else maxf(0.0, ghost_t - dt)
	var want_layer := 16 if ghost_t > 0.0 else 2
	var want_mask := 4 if guided else ((1 | 4) if ghost_t > 0.0 else (1 | 2 | 4))
	if collision_layer != want_layer:
		collision_layer = want_layer
	if collision_mask != want_mask:
		collision_mask = want_mask
	if guided:
		# looping e torção guiados: o carro segue a pista com velocidade mínima, sem engasgar nas emendas
		# a rapidez é guardada à parte (entra com a do carro e não perde nada nas emendas)
		var spd := maxf(guided_spd, 30.0 if in_loop else 28.0)
		if nitro_t > 0.0:
			spd = move_toward(spd, maxf(spd, sp.nitro * engine_mult * 0.9), 40.0 * dt)
		spd = minf(spd, 58.0)
		guided_spd = spd
		# lateral só por posição (sem reaproveitar v·L medido: num looping com deslocamento lateral
		# essa leitura carrega o giro do referencial e empurraria o carro para fora da pista)
		var lim := road_half - 1.6
		var lat_target := -lat * 0.25
		if role == "player":
			if ctrl.dir == null:
				lat_target += ctrl.steer * 5.0   # direção clássica: dá para desviar para os lados
		else:
			lat_target = (clampf(lane_cur, -lim, lim) - lat) * 1.2
		if absf(lat) > lim:
			lat_target = minf(lat_target, -(absf(lat) - lim) * 3.0 - 1.0) if lat > 0.0 else maxf(lat_target, (absf(lat) - lim) * 3.0 + 1.0)
		# segue a pista exatamente: mira o ponto onde o carro deve estar no próximo quadro
		# (s + v·dt, faixa e altura suavizadas), então não sobra erro para acumular entre quadros
		var lat_next := clampf(lat + clampf(lat_target, -8.0, 8.0) * dt, -road_half + 1.2, road_half - 1.2)
		var h_next := lerpf(h_surf, 0.0, 0.3)
		var L := track_ref.length
		if exit_assist < 0.6 or absf(wrapf(_gs - s_track, -L * 0.5, L * 0.5)) > 4.0:
			_gs = s_track
		else:
			# segue a distância integrada, puxando de leve para a medida (sem acumular erro)
			_gs += wrapf(s_track - _gs, -L * 0.5, L * 0.5) * 0.08
		_gs = fposmod(_gs + spd * dt, L)
		var nx := track_ref.at(_gs, lat_next)
		var target: Vector3 = nx.pos + (nx.up as Vector3) * h_next
		var lv := (target - global_position) / dt
		if lv.length() > spd * 1.6 + 6.0:
			lv = lv.normalized() * (spd * 1.6 + 6.0)
		linear_velocity = lv
		var want: Basis = (nx.basis as Basis).orthonormalized()
		var dq := (want * global_transform.basis.orthonormalized().inverse()).get_rotation_quaternion()
		var ax := dq.get_axis()
		var ang := dq.get_angle()
		if ang > PI:
			ang -= TAU
		angular_velocity = ax.normalized() * ang * 12.0 if ax.length() > 0.001 else Vector3.ZERO
		v_f = spd
		nitroing = nitro_t > 0.0
		exit_assist = 0.6
		_applied = Vector3.ZERO
		_prev_v = linear_velocity
		on_ground = true
		air_t = 0.0
		return
	if exit_assist >= 0.6:
		# saída limpa do trecho guiado: sem giro herdado e sem deriva lateral, só a velocidade ao longo da pista
		var vt := linear_velocity.dot(track_tan)
		var vu := clampf(linear_velocity.dot(track_up), -2.0, 2.0)
		linear_velocity = track_tan * vt + track_up * vu
		angular_velocity = Vector3.ZERO
		_prev_v = linear_velocity
	exit_assist = maxf(0.0, exit_assist - dt)
	guided_spd = maxf(0.0, linear_velocity.dot(track_tan))
	if magnet and feat_type == "cork":
		# no saca-rolhas a pista gira em volta do eixo: puxa o carro para o centro
		var cf := -track_left * lat * mass * 9.0 - track_left * linear_velocity.dot(track_left) * mass * 2.0
		apply_central_force(cf)
		_applied += cf
	if not on_ground:
		if h_surf > 0.7 or not on_feature:
			air_t += dt
	elif not was_ground:
		if air_t > 0.15:
			landed.emit(self, air_t, maxf(0.0, -_prev_v.dot(ground_n)))
		air_t = 0.0

	var b := global_transform.basis
	var up := b.y
	var fwd := b.z
	var v := linear_velocity
	var n := ground_n if on_ground else up
	# gravidade: no asfalto ela puxa contra a pista (gruda nos loopings), no ar é a normal
	var gdir := Vector3.DOWN
	var gmag := GRAV * grav_factor
	if magnet:
		gdir = -track_up
		gmag = GRAV * 1.3
	elif on_ground and on_road and (n.y > 0.35 or v.length() > 11.0):
		gdir = -n
	var gf := gdir * gmag * mass
	apply_central_force(gf)
	_applied += gf

	var fwd_g := (fwd - n * fwd.dot(n)).normalized()
	var left_g := n.cross(fwd_g)
	v_f = v.dot(fwd_g)
	v_s = v.dot(left_g)

	var steer: float = ctrl.steer
	var ea := clampf(exit_assist / 0.6, 0.0, 1.0)
	if ctrl.dir != null:
		var dw: Vector3 = ctrl.dir
		if ea > 0.0 and role == "player":
			# na saída de loop/saca-rolhas o analógico vale só como "um pouco para o lado" da pista
			var tg := Vector3(track_tan.x, 0, track_tan.z)
			if tg.length() > 0.2:
				tg = tg.normalized()
				var ang := tg.signed_angle_to(Vector3(dw.x, 0, dw.z), Vector3.UP)
				var lim := lerpf(PI, 0.18, ea)
				dw = tg.rotated(Vector3.UP, clampf(ang, -lim, lim))
		var d: Vector3 = b.inverse() * dw
		var dh := atan2(d.x, d.z)
		# meia-volta: com o alvo quase atrás, continua girando para o mesmo lado (sem ficar indeciso)
		if absf(dh) > 2.4:
			if _uturn == 0.0:
				_uturn = signf(dh) if absf(steer_s) < 0.1 else signf(steer_s)
			dh = _uturn * absf(dh)
		else:
			_uturn = 0.0
		steer = clampf(dh * 2.4, -1.0, 1.0) * float(ctrl.dir_mag)
		_dh = dh
		# só inverte quando o jogador está dando ré de propósito (segurando o freio)
		if v_f < -2.0 and ctrl.brake > 0.0:
			steer = -steer
	else:
		_uturn = 0.0
		if ea > 0.0 and role == "player":
			steer *= lerpf(1.0, 0.3, ea)
	steer_s = lerpf(steer_s, steer, minf(1.0, dt * 14.0))
	var vmax: float = sp.vmax * engine_mult * (0.62 if flat_t > 0.0 else 1.0)
	var spd01 := minf(1.0, absf(v_f) / vmax)

	# auto-drift: curva forte em velocidade entra sozinha num drift suave (sem botão)
	var demand: float = (absf(_dh) / 0.8) if ctrl.dir != null else (absf(ctrl.steer) / 0.9)
	if on_ground and v_f > 19.0 and demand >= 1.0 and not on_feature:
		_hard_t += dt
	else:
		_hard_t = maxf(0.0, _hard_t - dt * 2.0)
	var want_drift: bool = ctrl.drift or _hard_t > 0.14
	if not drifting and on_ground and want_drift and v_f > 15.0 and absf(steer_s) > 0.3:
		drifting = true
		drift_dir = signf(steer_s)
		drift_t = 0.0
		angular_velocity += up * drift_dir * 0.55
	if drifting:
		drift_t += dt
		drift_slip = absf(atan2(v_s, maxf(1.0, v_f)))
		var holding: bool = ctrl.drift or (steer_s * drift_dir > 0.35 and demand > 0.55)
		if v_f < 7.0 or not on_ground or (drift_t > 0.35 and drift_slip < 0.1 and not holding) or (drift_t > 0.2 and drift_slip < 0.05):
			drifting = false
	else:
		drift_slip = 0.0

	# nitro por cargas: um toque = uma arrancada
	nitro_t = maxf(0.0, nitro_t - dt)
	var np: bool = ctrl.nitro
	special_cd = maxf(0.0, special_cd - dt)
	ice_t = maxf(0.0, ice_t - dt)
	emp_t = maxf(0.0, emp_t - dt)
	mud_t = maxf(0.0, mud_t - dt)
	if mud_t > 0.0 and on_ground:
		linear_velocity *= 1.0 - 1.6 * dt   # lama: o carro afunda e perde embalo
	if burn_t > 0.0:
		# queimando: dano contínuo (crédito para quem pôs fogo)
		burn_t -= dt
		_burn_acc += dt
		if _burn_acc > 0.25:
			_burn_acc = 0.0
			apply_damage(2.2, global_position + Vector3.UP, burn_by, false)
	shield_t = maxf(0.0, shield_t - dt)
	flat_t = maxf(0.0, flat_t - dt)
	# especial comprado (escudo, onda de choque, reparo): botão próprio, cargas por volta
	var spp: bool = ctrl.special
	if special_type != "" and spp and not _spec_was and spec_ch > 0 and special_cd <= 0.0 and emp_t <= 0.0 and game and game.weapons.can_special(self, special_type):
		spec_ch -= 1
		special_cd = 0.8
		game.weapons.special(self, special_type)
	_spec_was = spp
	# mobilidade no botão do nitro: salto, esquiva e planar são impulsos; nitro e investida são arrancadas
	if nitro_type in ["jump", "dash", "glide"]:
		if np and not _nitro_was and nitro_ch > 0 and special_cd <= 0.0 and emp_t <= 0.0 and game and game.weapons.can_special(self, nitro_type):
			nitro_ch -= 1
			special_cd = 0.6
			game.weapons.special(self, nitro_type)
	elif np and not _nitro_was and nitro_ch > 0 and nitro_t <= 0.0 and emp_t <= 0.0:
		nitro_ch -= 1
		nitro_t = float(NITRO[nitro_type].dur)
		if nitro_type == "ram" and game:
			game.weapons.ram_start(self)
	_nitro_was = np
	nitroing = nitro_t > 0.0
	var nacc: float = NITRO[nitro_type].acc
	var vmax_now: float = (sp.nitro * engine_mult) if nitroing else vmax
	slow_t = maxf(0.0, slow_t - dt)
	if glide_t > 0.0:
		glide_t -= dt
		if not on_ground:
			# planando: a sustentação cancela boa parte da gravidade e empurra para frente
			linear_velocity.y += GRAV * grav_factor * 0.55 * dt
			var fwd_h := global_transform.basis.z.slide(Vector3.UP).normalized()
			linear_velocity += fwd_h * 2.5 * dt
			# planando o carro segue reto para onde aponta (some a deriva lateral)
			var side_v := linear_velocity.slide(Vector3.UP) - fwd_h * linear_velocity.dot(fwd_h)
			linear_velocity -= side_v * minf(1.0, 2.5 * dt)
			# no ar dá para virar (as asinhas funcionam como leme)
			angular_velocity.y = lerpf(angular_velocity.y, steer_s * 2.4, minf(1.0, 6.0 * dt))
	if slow_t > 0.0:
		# rajada de metralhadora segura o carro (o nitro ajuda a escapar; chefes sentem menos)
		vmax_now *= (0.97 if is_boss else (0.93 if nitroing else 0.86))
	# descidas embalam (e subidas freiam menos): a gravidade "de verdade" ao longo da rampa
	var slope_a := 0.0
	if on_ground and not magnet and not on_feature:
		var gw := Vector3.DOWN * GRAV * grav_factor
		var gt := gw - n * gw.dot(n)
		var along := gt.dot(fwd_g)
		slope_a = along * (1.7 if along > 0.0 else 0.55)
		vmax_now += maxf(0.0, slope_a) * 0.9
	launch_t = maxf(0.0, launch_t - dt)
	oily_t = maxf(0.0, oily_t - dt)

	var wy := angular_velocity.dot(up)
	var inertia: float = mass * (sp.len * sp.len + sp.wid * sp.wid) / 12.0
	if on_ground:
		var target := 0.0
		if drifting:
			target = (steer_s * 1.15 + drift_dir * 0.4) * sp.turn * 0.95
		else:
			var rate: float = sp.turn * turn_mult * minf(1.0, absf(v_f) / 5.0) * (1.0 - 0.28 * spd01)
			target = steer_s * rate * (1.0 if v_f >= 0.0 else -1.0)
		var auth := 0.25 if stun > 0.0 else 1.0
		if oil_t > 0.0:
			# perda de controle: rabeia de um lado para o outro, mais forte logo ao entrar
			auth = 0.15
			target += sin(game_time * 7.5) * 2.8 * clampf(oil_t / 1.1, 0.3, 1.0)
		var k := (5.0 if drifting else 9.0) * auth
		apply_torque(up * (target - wy) * inertia * k)
		var a := 0.0
		if ctrl.throttle > 0.0 and not (ctrl.brake > 0.0 and v_f > 1.0):
			if v_f < vmax_now:
				var f := maxf(0.12, 1.0 - pow(v_f / vmax_now, 2.0))
				a += sp.accel * engine_mult * (nacc if nitroing else 1.0) * ctrl.throttle * f
			else:
				a -= (v_f - vmax_now) * 1.2
		elif ctrl.brake <= 0.0:
			a -= signf(v_f) * minf(absf(v_f) / dt, 4.0) + v_f * 0.08
		if nitroing and v_f < vmax_now:
			a += 6.0
		a += slope_a
		if ctrl.brake > 0.0:
			if v_f > 0.5:
				a -= 8.0 if drifting else 32.0
			elif v_f > -12.0:
				a -= 16.0
		if drifting:
			a -= v_f * 0.1
		var grip: float = (sp.drift_grip if drifting else sp.grip) * grip_factor * tire_grip * (0.3 if ice_t > 0.0 else 1.0)
		if stun > 0.0:
			grip *= 0.25
		if oil_t > 0.0:
			grip *= 0.18
		var lost := v_s * (1.0 - exp(-grip * dt))
		if drifting:
			a += absf(lost) / dt * 0.35
		var force := fwd_g * a * mass + left_g * (-lost / dt) * mass
		apply_force(force, -up * 0.15 + b * center_of_mass)
		_applied += force
		var dfc := -up * mass * clampf(absf(v_f) * 0.2, 0, 10)   # pressão aerodinâmica: cola no chão
		apply_central_force(dfc)
		_applied += dfc
	elif nitroing:
		var f := fwd_g * mass * 10.0
		apply_central_force(f)
		_applied += f
	# estabilizador: alinha o carro com a pista (ou com o céu, no ar)
	var target_up := ground_n if on_ground else Vector3.UP
	if magnet:
		target_up = track_up
	var tilt := up.cross(target_up)
	var ang_nyaw := angular_velocity - up * wy
	if magnet:
		# acompanha a rotação da pista na hora (sem isso o carro "descola" no saca-rolhas)
		angular_velocity = up * wy + tilt * 18.0
	else:
		var stab := 30.0 if on_ground else 10.0   # no ar o carro se nivela (pousa de rodas)
		# peso: amortece capotar/empinar (não a virada), então o carro não "bóia" nas batidas
		apply_torque((tilt * stab - ang_nyaw * (4.5 if on_ground else 1.8)) * inertia)


func _suspension(wreck_mode: bool) -> int:
	var space := get_world_3d().direct_space_state
	var b := global_transform.basis
	var up := b.y
	var grounded := 0
	var excl := [get_rid()]
	var nsum := Vector3.ZERO
	var psum := Vector3.ZERO
	var road_hits := 0
	for w in wheels:
		if w.lost:
			continue
		var mount: Vector3 = global_transform * (w.base + Vector3(0, SUSP, 0))
		var maxd: float = SUSP + w.r + 0.3
		var q := PhysicsRayQueryParameters3D.create(mount, mount - up * maxd, 1, excl)
		var res := space.intersect_ray(q)
		w.contact = false
		w.dist = maxd
		if res:
			var dist: float = mount.distance_to(res.position)
			var comp: float = SUSP + w.r - dist
			w.dist = dist
			if comp > -0.03 - PRELOAD:
				w.contact = true
				grounded += 1
				nsum += res.normal
				psum += res.position
				if res.collider and (res.collider as Node).has_meta("road"):
					road_hits += 1
				if (not wreck_mode or up.y > 0.5) and _susp_forces:
					var rel: Vector3 = mount - global_position
					var pv := linear_velocity + angular_velocity.cross(rel)
					var f := maxf(0.0, _k * maxf(comp + PRELOAD, 0.0) - _c * pv.dot(up))
					if comp > BUMP:
						f += _k * 6.0 * (comp - BUMP) - _c * 1.5 * minf(0.0, pv.dot(up))
					f = minf(f, mass * 130.0)
					apply_force(up * f, rel)
					_applied += up * f
	if grounded > 0:
		ground_n = ground_n.lerp(nsum.normalized(), 0.5).normalized()
		ground_pt = psum / grounded
	on_road = road_hits >= 2
	return grounded


func _detect_impacts(dt: float) -> void:
	_detect_scrape()
	var v := linear_velocity
	var jump := v - _prev_v - _applied / mass * dt
	var dv := jump.length()
	_prev_v = v
	if dv < 3.0 or _contacts.is_empty():
		return
	var up := global_transform.basis.y
	var best = null
	for c in _contacts:
		var nrm: Vector3 = c[2]
		if not wrecked and nrm.dot(up) > 0.75:
			continue
		best = c
		break
	if best == null:
		return
	hit.emit(self, best[0], best[1], dv)


func _detect_scrape() -> void:
	scraping = false
	if linear_velocity.length() < 5.0:
		return
	var up := global_transform.basis.y
	var best := 0.0
	for c in _contacts:
		var nrm: Vector3 = c[2]
		if not wrecked and nrm.dot(up) > 0.7:
			continue
		var rel := linear_velocity
		if c[0] is RigidBody3D:
			rel -= (c[0] as RigidBody3D).linear_velocity
		var tang := rel - nrm * rel.dot(nrm)
		var spd := tang.length()
		if spd > 4.0 and spd > best:
			best = spd
			scraping = true
			scrape_pt = c[1]
			scrape_n = nrm
			scrape_v = tang


# ------------------------------------------------------------------ dano e vida
## dano de batida física (dv = variação de velocidade no impacto)
func take_impact(point: Vector3, dv: float, wall := false) -> void:
	if net_remote:
		_deform(point, dv * 0.5)
		return
	var tough := 0.55 if role == "player" else 1.0
	if wall:
		tough *= 0.45   # raspar/bater na mureta amassa, mas raramente destrói
	_deform(point, dv * (0.7 if wall else 1.0))
	var dmg := maxf(0.0, dv - (10.0 if wall else 7.5)) * 1.5 * tough
	if dmg > 0.0:
		apply_damage(dmg, point, last_hit_by if game_time - last_hit_t < 1.5 else null, false)


## dano de qualquer fonte (armas, batidas). Retorna true se destruiu o carro.
func apply_damage(amount: float, point: Vector3, attacker: Car, deform := true) -> bool:
	if wrecked or invuln > 0.0 or amount <= 0.0:
		return false
	if shield_t > 0.0:
		flash_t = 0.03   # escudo: nada passa
		return false
	if net_remote:
		# quem decide o dano é a máquina dona do carro; aqui só o efeito visual (e quem atirou leva o crédito lá)
		flash_t = 0.06
		return false
	health -= amount
	flash_t = 0.06
	if attacker:
		last_hit_by = attacker
		last_hit_t = game_time
	if deform:
		_deform(point, amount * 0.6 + 4.0)
	if paint:
		var dmg := clampf(1.0 - health / max_health, 0.0, 1.0)
		paint.albedo_color = color.lerp(Color(0.18, 0.16, 0.15), dmg * 0.55)
		paint.roughness = 0.24 + dmg * 0.5
	if health <= 0.0:
		health = 0.0
		died.emit(self, attacker)
		return true
	return false


func _deform(point: Vector3, dv: float) -> void:
	var lp := to_local(point)
	if _dent_cd <= 0.0 and dv > 4.0:
		_dent_cd = 0.08
		var dir := Vector3(-lp.x, 0, -lp.z).normalized()
		var depth := clampf(dv * 0.016, 0.04, 0.38)
		for pn in parts:
			var p: Dictionary = parts[pn]
			if p.off:
				continue
			if (p.center as Vector3).distance_to(lp) < 2.2:
				_dent(p, lp, dir, depth, 1.0 + dv * 0.03)
	var tough := 0.5 if role == "player" else 1.0
	for pn in parts:
		var p: Dictionary = parts[pn]
		if p.off or pn == "body":
			continue
		var d: float = (p.center as Vector3).distance_to(lp)
		if d < 1.8:
			p.hp -= dv * 6.0 * tough * (1.0 - d / 1.8)
			if p.hp <= 0.0 and (pn != "cabin" or wrecked):
				detach(pn, (lp - (p.center as Vector3)).normalized() * -1.0)


func _dent(p: Dictionary, lp: Vector3, dir: Vector3, depth: float, radius: float) -> void:
	var mi: MeshInstance3D = p.mesh
	var inv := mi.transform.affine_inverse()
	var c := inv * lp
	var dm := (inv.basis * dir).normalized()
	var am := ArrayMesh.new()
	for s in p.arrays.size():
		var arr: Array = p.arrays[s]
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var changed := false
		for i in verts.size():
			var dd := verts[i].distance_to(c)
			if dd < radius:
				var f := 1.0 - dd / radius
				f = f * f * (3.0 - 2.0 * f)
				var jit := Vector3(sin(i * 12.9898), cos(i * 78.233), sin(i * 4.1414)) * 0.035
				verts[i] += (dm * depth + jit) * f
				changed = true
		if changed:
			arr[Mesh.ARRAY_VERTEX] = verts
			_flat_normals(arr)
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(s, p.mats[s])
	mi.mesh = am
	for s in am.get_surface_count():
		mi.set_surface_override_material(s, p.mats[s])


func _flat_normals(arr: Array) -> void:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ind = arr[Mesh.ARRAY_INDEX]
	if ind == null or nrm.size() != verts.size():
		return
	var idx: PackedInt32Array = ind
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]
		var n := (verts[idx[t + 2]] - a).cross(verts[idx[t + 1]] - a).normalized()
		nrm[idx[t]] = n
		nrm[idx[t + 1]] = n
		nrm[idx[t + 2]] = n
	arr[Mesh.ARRAY_NORMAL] = nrm


func detach(pn: String, push := Vector3.ZERO) -> void:
	var p: Dictionary = parts[pn]
	if p.off:
		return
	p.off = true
	var mi: MeshInstance3D = p.mesh
	var copy := mi.duplicate() as MeshInstance3D
	var xf := mi.global_transform
	mi.visible = false
	var c: Vector3 = global_transform * (p.center as Vector3)
	var vel := linear_velocity + angular_velocity.cross(c - global_position)
	vel += (global_transform.basis * push) * randf_range(3, 7) + global_transform.basis.y * randf_range(4, 9)
	part_off.emit(self, copy, xf, vel, false)


func detach_wheel(w: Dictionary) -> void:
	if w.lost:
		return
	w.lost = true
	var mi: MeshInstance3D = w.mesh
	var copy := mi.duplicate() as MeshInstance3D
	var xf := mi.global_transform
	mi.visible = false
	var side := signf(w.base.x)
	var vel := linear_velocity + global_transform.basis.x * side * randf_range(4, 8) + global_transform.basis.y * randf_range(4, 8)
	part_off.emit(self, copy, xf, vel, true)


func wreck(power: float, from_dir: Vector3, pop := true) -> void:
	if wrecked:
		return
	wrecked = true
	wreck_t = 0.0
	drifting = false
	nitroing = false
	nitro_t = 0.0
	angular_damp = 0.15
	var pw := clampf(power / 30.0, 0.5, 1.4)
	var fwd := global_transform.basis.z
	var side := global_transform.basis.x
	var up := global_transform.basis.y
	if pop:
		apply_central_impulse((up * (5.0 + 5.0 * pw) + from_dir * 4.0) * mass)
	var tq := fwd * randf_range(-1, 1) * 8.0 * pw + side * randf_range(-4, 4) * pw + up * randf_range(-5, 5)
	apply_torque_impulse(tq * mass * 2.0)
	var names := parts.keys().filter(func(k): return k != "body" and not parts[k].off)
	names.shuffle()
	for i in mini(randi_range(1, 3), names.size()):
		detach(names[i], Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)))
	if randf() < 0.6:
		var ws := wheels.duplicate()
		ws.shuffle()
		detach_wheel(ws[0])


func repair() -> void:
	wrecked = false
	flat_t = 0.0
	burn_t = 0.0
	shield_t = 0.0
	health = max_health
	angular_damp = 1.2
	oil_t = 0.0
	stun = 0.0
	for pn in parts:
		var p: Dictionary = parts[pn]
		p.off = false
		p.hp = 100.0
		var mi: MeshInstance3D = p.mesh
		mi.mesh = p.orig
		mi.visible = true
		p.arrays.clear()
		for s in mi.mesh.get_surface_count():
			p.arrays.append(mi.mesh.surface_get_arrays(s))
			mi.set_surface_override_material(s, p.mats[s])
	for w in wheels:
		w.lost = false
		(w.mesh as MeshInstance3D).visible = true
	if paint:
		paint.albedo_color = color
		paint.roughness = 0.24


func place(xform: Transform3D, speed: float) -> void:
	_teleport = {"xform": xform, "vel": xform.basis.z * speed}
	global_transform = xform
	linear_velocity = xform.basis.z * speed
	angular_velocity = Vector3.ZERO
	_prev_v = linear_velocity
	drifting = false
	on_ground = true
	air_t = 0.0
	stun = 0.0
	off_t = 0.0
	ground_n = xform.basis.y
	v_f = speed


## ------------------------------------------------------------------ kit visual por nível
## Dá para reconhecer de longe o nível de cada carro:
##   nível 1: splitter dianteiro, faixa lateral e aro preto
##   nível 2: + asa traseira com pilares, canards e aro bronze (o aerofólio de fábrica sai)
##   nível 3: + asa grande com placas coloridas, neon embaixo do carro e aro dourado
## e cada upgrade aparece: blindagem (placas nas portas), nitro (cilindros atrás), motor (blower no capô),
## munição (tambor extra na arma).
func _kit_mat(col: Color, rough := 0.4, metal := 0.3, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if metal >= 0.8 and refl_metal:
		m.metallic = 0.8
		m.next_pass = refl_metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


## caixa que envolve o casulo da arma (sem os enfeites de upgrade), em coordenadas do nó da arma
func _pod_box() -> AABB:
	if wpn_gun_mesh:
		return wpn_gun_mesh.get_aabb()   # corpo da arma (sem base nem anel)
	if weapon_node is MeshInstance3D:
		return (weapon_node as MeshInstance3D).get_aabb()   # o casulo do modelo é uma malha só
	var out := AABB()
	var first := true
	for ch in weapon_node.get_children():
		# só as peças do casulo vindas do modelo (wp_*), sem bobina/tanques extras nem enfeites
		if ch is MeshInstance3D and not _kit.has(ch) and String(ch.name).begins_with("wp_"):
			var bb: AABB = (ch as MeshInstance3D).transform * (ch as MeshInstance3D).get_aabb()
			out = bb if first else out.merge(bb)
			first = false
	return out if not first else AABB(Vector3(-0.31, 0.09, -0.45), Vector3(0.62, 0.42, 0.9))


func _kit_box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	(parent if parent else model).add_child(mi)
	_kit.append(mi)
	return mi


func _kit_cyl(r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	(parent if parent else model).add_child(mi)
	_kit.append(mi)
	return mi


func _build_kit(up: Dictionary) -> void:
	for n in _kit:
		if is_instance_valid(n):
			n.queue_free()
	_kit.clear()
	var total := int(up.get("engine", 0)) + int(up.get("armor", 0)) + int(up.get("ammo", 0)) + int(up.get("nitro", 0)) + int(up.get("tires", 0))
	tier = 0 if total < 4 else (1 if total < 8 else (2 if total < 12 else 3))
	if up.has("_tier"):
		tier = int(up["_tier"])
	if role == "traffic" or model == null:
		return
	var Lc: float = sp.len
	var Wc: float = sp.wid
	var top: float = sp.clr + sp.h
	var carbon := _kit_mat(Color(0.07, 0.075, 0.085), 0.3, 0.35)
	var accent := _kit_mat(TIER_ACCENT[tier], 0.3, 0.2, 0.6 if tier == 3 else 0.0)
	# cor do aro por nível (o material "Rim" das rodas)
	var rim := _kit_mat(TIER_RIM[tier], 0.2, 1.0)
	for w in wheels:
		var mi: MeshInstance3D = w.mesh
		for si in mi.mesh.get_surface_count():
			var sm := mi.mesh.surface_get_material(si)
			if sm and sm.resource_name == "Rim":
				mi.set_surface_override_material(si, rim)
			elif sm and sm.resource_name == "TireStripe" and tier >= 2:
				mi.set_surface_override_material(si, accent)
	var offroad: bool = mkind in OFFROAD or mkind == "vespa"
	if tier >= 1:
		# lâmina dianteira rente ao para-choque e filete na cor do kit encostado na lateral (entre as rodas)
		_kit_box(Vector3(Wc * 0.84, 0.035, 0.2), Vector3(0, sp.clr + 0.02, Lc * 0.5 + 0.03), carbon)
		for sx: float in [-1.0, 1.0]:
			_kit_box(Vector3(0.02, 0.06, Lc * 0.34), Vector3(sx * (Wc * 0.5 + 0.012), sp.clr + sp.h * 0.78, 0.0), accent)
	if tier >= 2 and offroad:
		# buggy e picape: em vez de asa de pista, para-barros na cor do kit atrás das rodas traseiras
		for w in wheels:
			var wb: Vector3 = w.base
			if wb.z < 0.0:
				var fl := _kit_box(Vector3(0.36, float(w.r) * 0.9, 0.03), Vector3(wb.x, float(w.r) * 0.75, wb.z - float(w.r) - 0.1), carbon)
				_kit_box(Vector3(0.37, 0.05, 0.035), Vector3(0, float(w.r) * 0.3, 0), accent, Vector3.ZERO, fl)
	elif tier >= 2:
		var stock: Dictionary = parts.get("spoiler", {})
		if not stock.is_empty():
			(stock.mesh as MeshInstance3D).visible = false
		var wy := top + (0.55 if tier == 3 else 0.42)
		var wz := -Lc * 0.5 + 0.3
		for sx: float in [-1.0, 1.0]:
			_kit_box(Vector3(0.06, wy - top, 0.14), Vector3(sx * Wc * 0.28, top + (wy - top) * 0.5, wz), carbon)
			# canards (aletinhas) nos cantos do para-choque
			_kit_box(Vector3(0.26, 0.025, 0.16), Vector3(sx * Wc * 0.42, sp.clr + 0.22, Lc * 0.5 + 0.06), carbon, Vector3(0, 0, sx * 0.25))
		var ww := Wc * (1.08 if tier == 3 else 0.96)
		_kit_box(Vector3(ww, 0.05, 0.46), Vector3(0, wy, wz), carbon, Vector3(-0.14, 0, 0))
		for sx: float in [-1.0, 1.0]:
			_kit_box(Vector3(0.035, 0.26, 0.52), Vector3(sx * ww * 0.5, wy - 0.04, wz), accent)
	if tier >= 3:
		# neon embaixo do carro (cor do carro, brilha no chão)
		var neon := _kit_mat(color.lightened(0.2), 1.0, 0.0, 3.0)
		neon.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_kit_box(Vector3(Wc * 0.84, 0.02, Lc * 0.8), Vector3(0, sp.clr - 0.05, 0), neon)
	# upgrades individuais
	var armor := int(up.get("armor", 0))
	if armor >= 2 and mkind != "trovao":   # o Trovão já vem com placas de fábrica
		var plate := _kit_mat(Color(0.32, 0.34, 0.37), 0.45, 0.8)
		for sx: float in [-1.0, 1.0]:
			# encostada na porta (antes ficava 7 cm para fora, flutuando)
			_kit_box(Vector3(0.05, sp.h * 0.44, Lc * 0.32), Vector3(sx * (Wc * 0.5 + 0.03), sp.clr + sp.h * 0.4, 0.0), plate)
			for k in 3:
				_kit_cyl(0.035, 0.03, Vector3(sx * (Wc * 0.5 + 0.06), sp.clr + sp.h * 0.4, (k - 1) * Lc * 0.11), _kit_mat(Color(0.75, 0.75, 0.78), 0.2, 1.0), Vector3(0, 0, PI / 2))
	var nit := int(up.get("nitro", 0))
	if nit >= 2:
		var blue := _kit_mat(Color("#2f7dff"), 0.25, 0.6, 0.4)
		for sx: float in [-1.0, 1.0]:
			_kit_cyl(0.1, 0.45, Vector3(sx * 0.24, top + 0.1, -Lc * 0.5 + 0.45), blue, Vector3(PI / 2, 0, 0))
	var eng := int(up.get("engine", 0))
	if eng >= 2:
		var chrome := _kit_mat(Color(0.85, 0.86, 0.9), 0.15, 1.0)
		_kit_box(Vector3(0.42, 0.18, 0.4), Vector3(0, top + 0.02, Lc * 0.5 - 0.95), chrome)
		_kit_box(Vector3(0.34, 0.14, 0.12), Vector3(0, top + 0.16, Lc * 0.5 - 0.82), carbon)
	# arma de ataque melhorada: cano reforçado (dano) e carregador extra (cadência)
	if weapon_node and front_type != "none":
		var dl := int(up.get("dmg", 0))
		var rl := int(up.get("rate", 0))
		var pb := _pod_box()
		# só o "miolo" do corpo (sem esfera, tanques altos ou mira)
		pb = AABB(Vector3(maxf(pb.position.x, -0.2), maxf(pb.position.y, -0.13), pb.position.z), Vector3(minf(pb.size.x, 0.4), minf(pb.size.y, 0.26), pb.size.z))
		if dl >= 1:
			# DANO: cinta laranja de dissipação abraçando o corpo da arma (mais larga por nível)
			var hot := _kit_mat(Color("#ff6a1a"), 0.35, 0.5, 0.25 * dl)
			_kit_box(Vector3(pb.size.x + 0.04, pb.size.y + 0.03, 0.05 + 0.03 * dl), pb.get_center() + Vector3(0, 0, pb.size.z * 0.12), hot, Vector3.ZERO, wpn_gun)
		if rl >= 1:
			# CADÊNCIA: respiros azuis nas laterais do corpo (um par por nível)
			var cool := _kit_mat(Color("#2ee6ff"), 0.3, 0.4, 0.35 * rl)
			for k in rl:
				for sx: float in [-1.0, 1.0]:
					_kit_box(Vector3(0.03, pb.size.y * 0.4, 0.07), Vector3(pb.get_center().x + sx * (pb.size.x * 0.5 + 0.012), pb.get_center().y, pb.get_center().z - 0.12 + k * 0.11), cool, Vector3.ZERO, wpn_gun)
	if int(up.get("ammo", 0)) >= 2 and wpn_gun and front_type != "none":
		var pb3 := _pod_box()
		_kit_cyl(0.11, 0.16, Vector3(pb3.end.x + 0.08, pb3.position.y + 0.12, pb3.get_center().z - pb3.size.z * 0.15), _kit_mat(Color("#c8a43a"), 0.35, 0.8), Vector3(0, 0, PI / 2), wpn_gun)


## encostado na mureta: o carro não "sobe" nela nem é lançado para fora (tira a velocidade para cima
## e o giro de capotagem), e devolve parte da velocidade ao longo da pista
func _wall_hold() -> void:
	if wrecked:
		return
	var touching := false
	for c in _contacts:
		var ob: Object = c[0]
		if ob is Node and (ob as Node).has_meta("rail"):
			touching = true
			break
	if not touching:
		return
	var up := track_up
	var vu := linear_velocity.dot(up)
	if vu > 1.0:
		linear_velocity -= up * (vu - 1.0) * 0.85
	var b := global_transform.basis
	var yaw := angular_velocity.dot(b.y)
	angular_velocity = angular_velocity.lerp(b.y * yaw, 0.5)


## salto assistido (arcade): na decolagem o carro sai alinhado com a pista e com a rapidez mínima
## para cair na rampa de pouso (sem pousar torto na mureta nem cair no vão por falta de embalo)
func _jump_assist() -> void:
	var tr := track_ref
	var j := ti
	var k := 0
	# só na ponta da rampa (o vão começa logo à frente): um pulinho no começo da rampa não conta
	while k < 5 and tr.gap[tr.idx(j)] == 0:
		j += 1
		k += 1
	if tr.gap[tr.idx(j)] == 0:
		return
	if h_surf < -0.5:
		return   # já caiu abaixo da rampa: não dá mais para salvar
	_jump_armed = false
	while k < 60 and tr.gap[tr.idx(j)] == 1:
		j += 1
		k += 1
	jump_cd = 1.2
	var li := tr.idx(j + 6)
	var land: Vector3 = tr.P[li] + tr.L[li] * clampf(lat, -road_half * 0.4, road_half * 0.4)
	var to := land - global_position
	var D := Vector2(to.x, to.z).length()
	var G := GRAV * grav_factor
	var v := linear_velocity
	var vy := maxf(v.y, 5.5)   # arco mínimo: salto "de verdade", não um pulinho
	# tempo de voo até a altura do pouso: vy·t − ½·G·t² = Δy (se o pouso estiver acima do ápice, usa o ápice)
	var disc := vy * vy - 2.0 * G * to.y
	var tf := (vy + sqrt(maxf(disc, 0.0))) / G
	var need := D / maxf(tf, 0.2)
	var vh := Vector2(v.x, v.z).length()
	var hd := Vector3(to.x, 0, to.z).normalized()
	var newh := clampf(maxf(vh, need), 0.0, maxf(vh, 8.0) * 1.5 + 6.0)
	# rápido demais (nitro + placa): segura um pouco no ar para pousar na rampa, não voar para fora na curva
	newh = minf(newh, need * 1.4 + 5.0)
	if OS.get_cmdline_user_args().has("--debugjump"):
		print("JUMP %s s=%d k=%d D=%.1f dy=%.1f vy=%.1f tf=%.2f vh=%.1f need=%.1f new=%.1f ang=%.0f" % [display_name, int(s_track), k, D, to.y, v.y, tf, vh, need, newh, rad_to_deg(Vector2(v.x, v.z).angle_to(Vector2(to.x, to.z)))])
	linear_velocity = hd * newh + Vector3.UP * vy
	angular_velocity = Vector3.ZERO   # sai reto da rampa (sem cambalhota)


# ------------------------------------------------------------------ IA
func ai(track: Track, _game: Node, dt: float) -> void:
	var pr := track.project(global_position, ti)
	ti = pr.i
	lat = pr.lat
	var dir := -1.0 if oncoming else 1.0
	var look := 5.0 + maxf(0.0, v_f) * 0.42
	var lt := lane_t
	var ahead := track.idx(pr.i + int(look / track.ds))
	if track.ftype[ahead] == "cork" or track.ftype[pr.i] == "cork" or track.ftype[ahead] == "loop":
		lt = clampf(lane_t, -3.5, 3.5)   # nos loopings e torções cada um mantém sua faixa (sem engavetar no meio)
	elif track.ftype[ahead] == "jump" or track.ftype[pr.i] == "jump":
		lt = clampf(lane_t, -2.5, 2.5)   # salto pelo meio da rampa
	lane_cur += clampf(lt - lane_cur, -dt * 6.0, dt * 6.0)
	var tp := track.at(pr.s + look * dir, lane_cur)
	var to: Vector3 = tp.pos - global_position
	ctrl.dir = to.normalized()
	ctrl.dir_mag = 1.0
	ctrl.drift = false
	var want := cruise
	if role == "rival":
		var max_c := 0.0
		var special := false
		for k in range(2, 26, 2):
			var j := track.idx(pr.i + k)
			max_c = maxf(max_c, absf(track.curv[j]))
			if track.feat[j] == 1 and (track.ftype[j] == "loop" or track.ftype[j] == "jump" or track.ftype[j] == "cork"):
				special = true
		var lim := sqrt(30.0 / maxf(max_c, 1e-4))
		want = minf(cruise * rubber * ai_skill, lim)
		if special:
			want = maxf(want, 32.0)   # loopings e saltos pedem velocidade
		ctrl.nitro = max_c < 0.01 and v_f > 25.0 and nitro_ch > 0 and sin(game.time_g * 0.5 + seed_f) > 0.6
		var p: Car = null
		var pd := 1e9
		for h in game.humans:
			var dd: float = global_position.distance_to(h.global_position)
			if dd < pd and not h.wrecked:
				pd = dd
				p = h
		if p and not p.wrecked and pd < 9.0 and game.time_g > next_bash:
			lane_t = clampf(p.lat, -track.HALF + 2.0, track.HALF - 2.0)
			next_bash = game.time_g + randf_range(3, 6)
	var blocked = null
	var bf := 1e9
	var fwd := global_transform.basis.z
	var left := global_transform.basis.x
	for o in game.cars:
		if o == self or o.wrecked:
			continue
		var d: Vector3 = o.global_position - global_position
		var f := d.dot(fwd)
		var sd := d.dot(left)
		if f > 0.0 and f < 10.0 + v_f * 0.5 and absf(sd) < 2.4 and absf(d.dot(global_transform.basis.y)) < 3.0 and f < bf:
			bf = f
			blocked = o
	if blocked:
		if role == "rival":
			if game.time_g > lane_switch_t:
				var opts: Array = [track.lanes_fwd[0], track.lanes_fwd[1], track.lanes_onc[0], track.lanes_onc[1]]
				var best: float = opts[0]
				for l in opts:
					if absf(l - blocked.lat) > absf(best - blocked.lat):
						best = l
				lane_t = best
				lane_switch_t = game.time_g + 1.2
		elif blocked.role != "player":
			want = minf(want, maxf(0.0, blocked.v_f) * 0.9)
	elif role == "rival" and game.time_g > lane_switch_t and track.data.traffic > 0 and lane_t > 0.0:
		lane_t = track.lanes_fwd[int(seed_f) % 2]
	ctrl.throttle = 1.0 if v_f < want else 0.0
	ctrl.brake = 1.0 if v_f > want + 3.0 else 0.0


# ------------------------------------------------------------------ visual
func _exhaust_smoke(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.9
	p.local_coords = false
	p.position = at
	var m := SphereMesh.new()
	m.radius = 0.13
	m.height = 0.26
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.62, 0.66, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	p.mesh = m
	p.direction = Vector3(0, 0.35, -1)
	p.spread = 14.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, 0.8, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = sc
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(p)
	return p


## motor vivo: a carroceria (não as rodas) treme com a rotação — forte na marcha lenta acelerando
## parado, mais fina em alta; fumaça nas ponteiras e estalos ao tirar o pé em alta rotação
func _engine_life(dt: float) -> void:
	var thr: float = clampf(ctrl.throttle, 0.0, 1.0)
	var spd01 := clampf(absf(v_f) / maxf(1.0, float(sp.vmax) * engine_mult), 0.0, 1.2)
	var g := minf(4.0, floorf(spd01 * 5.0 * 0.999))
	var want := 0.22 + (spd01 * 5.0 - g) * 0.7 * (0.6 + thr * 0.4) + g * 0.04
	if spd01 < 0.08:
		want = 0.18 + thr * 0.75   # acelerando parado (largada): giro sobe e cai
	eng_rpm = lerpf(eng_rpm, want, minf(1.0, dt * (9.0 if want > eng_rpm else 4.0)))
	var live := not wrecked and role != "traffic"
	var amp := 0.0
	if live:
		amp = (0.0045 + 0.011 * thr * (1.0 - spd01 * 0.6) + (0.006 if nitroing else 0.0)) * (1.0 if on_ground else 0.35)
	var t := game_time
	var f := 38.0 + eng_rpm * 46.0
	var off := Vector3(sin(t * f * 0.83) * 0.4, sin(t * f) + sin(t * f * 1.71) * 0.4, sin(t * f * 0.57) * 0.25) * amp
	var roll := sin(t * f * 0.91 + 1.3) * amp * 1.6
	for pn in parts:
		var pp: Dictionary = parts[pn]
		if pp.off or not pp.has("base"):
			continue
		var mi: MeshInstance3D = pp.mesh
		mi.position = (pp.base as Vector3) + off
		mi.rotation = (pp.rot as Vector3) + Vector3(0, 0, roll)
	if weapon_node:
		weapon_node.position = weapon_base + off
	# fumaça: mais e mais escura com o pé no fundo
	for s in ex_smoke:
		var p: CPUParticles3D = s
		p.emitting = live and (thr > 0.05 or spd01 < 0.3)
		p.speed_scale = 0.7 + thr * 0.8
		p.color = Color(1.0 - thr * 0.35, 1.0 - thr * 0.35, 1.0 - thr * 0.3, 0.45 + thr * 0.55)
		p.initial_velocity_max = 2.0 + thr * 2.5
	# estalo do escapamento: soltou o acelerador em alta rotação
	if live and _thr_prev > 0.8 and thr < 0.2 and eng_rpm > 0.55 and randf() < 0.45 and game and game._on_screen(global_position):
		for s in ex_smoke:
			game.fx.hit_light((s as Node3D).global_position, Color(1.0, 0.55, 0.15), 4.0, 3.0, 0.08)
		if self == game.player:
			game.sfx.play("gun", -16.0, 0.45)
	_thr_prev = thr


func juice_squash(amount: float) -> void:
	squash_v += amount


func juice_pitch(amount: float) -> void:
	pitch_v += amount


## visual do carro (rodas, suspensão, "squash", recuo da arma): roda no passo de física para a
## interpolação de física desenhar tudo junto, sem "soquinhos"
func _visuals(dt: float) -> void:
	if model and not wrecked:
		if nitroing and not _nitro_vis:
			juice_squash(-1.6)   # estica para a frente
			juice_pitch(0.9)     # empina o nariz
		_nitro_vis = nitroing
		squash_v += (-squash * 160.0 - squash_v * 11.0) * dt
		squash = clampf(squash + squash_v * dt, -0.16, 0.2)
		pitch_v += (-pitch_kick * 120.0 - pitch_v * 10.0) * dt
		pitch_kick = clampf(pitch_kick + pitch_v * dt, -0.12, 0.12)
		model.scale = Vector3(1.0 + squash * 0.45, 1.0 - squash, 1.0 - squash * 0.35) * vscale
		model.rotation.x = -pitch_kick
	if model:
		_engine_life(dt)
	for w in wheels:
		if w.lost:
			continue
		var mi: MeshInstance3D = w.mesh
		var y: float = w.base.y + SUSP - w.dist + w.r
		mi.position.y = lerpf(mi.position.y, clampf(y, w.base.y - 0.25, w.base.y + WHEEL_UP) / vscale, minf(1.0, dt * 25.0))
		# giro visível: acima de ~3 voltas/s o olho vê o raio "parado" (efeito estroboscópico);
		# o giro desenhado é limitado para os raios sempre parecerem girar para a frente
		var wspin: float = (v_f + (35.0 if launch_t > 0.0 and not w.front else 0.0)) / maxf(0.2, w.r)
		w.spin += clampf(wspin, -19.0, 19.0) * dt
		var st := 0.0
		if w.front:
			st = (-drift_dir * 0.28 + steer_s * 0.14) if drifting else steer_s * 0.32
		mi.rotation = Vector3(w.spin, st, 0)
	if tail_mat:
		tail_mat.emission_energy_multiplier = 6.0 if ctrl.brake > 0.0 else (3.0 if nitroing else 1.5)
	if paint:
		paint.emission_energy_multiplier = 0.9 if flash_t > 0.0 else 0.0
	if sirens.size() >= 2:
		var on := sin(game_time * 14.0) > 0.0
		sirens[0].emission_energy_multiplier = 6.0 if on else 0.3
		sirens[1].emission_energy_multiplier = 0.3 if on else 6.0
	# recuo da arma a cada tiro
	recoil = maxf(0.0, recoil - dt * 9.0)
	firing_t = maxf(0.0, firing_t - dt)
	if weapon_node:
		_aim_turret(dt)
	if casings:
		casings.emitting = firing_t > 0.0 and not wrecked
	if hbar:
		hbar.visible = not wrecked and health < max_health * 0.999
		if hbar.visible:
			(hbar.material_override as ShaderMaterial).set_shader_parameter("ratio", health / max_health)
	visible = invuln <= 0.0 or int(game_time * 16.0) % 2 == 0

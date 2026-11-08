extends Node3D
## Mini Fúria: corrida isométrica de combate com mini carros.
## Fluxo: menu -> escolha da pista -> garagem (carro, armas, nitro, upgrades) -> corrida -> resultado ($).

const LAPS := 3
const PRIZE := [1000, 650, 400, 250, 120]
const KILL_BONUS := 150
const UP_PRICE := [400, 900, 1600]
const CAM_YAW := PI / 4.0
const CAM_PITCH := 0.62
const CAM_DIST := 70.0   # câmera ortográfica: mais perto = sombras do sol cobrindo a tela toda
const SAVE_PATH := "user://minifuria.json"

const RIVALS := [
	{"kind": "trovao", "color": "#2f6fd6", "name": "TROVÃO"},
	{"kind": "vespa", "color": "#ffb31a", "name": "VESPA"},
	{"kind": "trovao", "color": "#8a5cd6", "name": "CORISCO"},
	{"kind": "vespa", "color": "#2fbf71", "name": "JARARACA"},
]
const TRAFFIC := [
	["sedan", ["#5cc26b", "#f08a7a", "#7fc8d9", "#e6e1d6", "#9a7cf0"]],
	["taxi", ["#ffcf33"]],
	["policia", ["#f4f4f4"]],
	["picape", ["#8a5cd6", "#e2553b", "#3d8bd6"]],
]

var lib: Node3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var cam: Camera3D
var hud: Hud
var sfx: Sfx
var fx: Fx
var weapons: Weapons
var world: Node3D
var track: Track
var track_idx := 0
var theme: Dictionary
var ground_shader: Shader
var road_shader: Shader

var cars: Array = []
var rivals: Array = []
var traffic: Array = []
var props: Array = []
var pickups: Array = []
var player: Car            # jogador principal desta máquina (P1): save, prêmio, som do motor, HUD cheio
var humans: Array = []     # todos os carros dirigidos por pessoas (locais e de outras máquinas)
var locals: Array = []     # jogadores desta máquina: {"car", "dev", "idx", "name", "done"}
## sessão: "solo" | "local" (tela dividida, até 4) | "online" (até 8, em salas)
var session := {"kind": "solo", "players": []}
var multi: Multi
var settings: Settings
var career: Career
var boss: Car = null          # chefe da corrida (carreira)
var career_lines: Array = []
var loader: Loader
var online: NetGame
var race_end_t := -1.0     # multijogador: depois que o 1º humano termina, a corrida acaba em 30 s
## paleta da garagem (cor da pintura do seu carro)
const PAINT_COLORS := ["#e8352b", "#ff7a1a", "#ffcf33", "#7dff6a", "#1fae5b", "#2ee6ff", "#2f6fd6", "#5b3df0", "#c04de0", "#ff4fa3", "#f4f2ff", "#2a2a33"]
const HUMAN_COLORS := ["#e8352b", "#2f6fd6", "#2fbf71", "#ffb31a", "#c04de0", "#ff7a1a", "#2ee6ff", "#f2f2f2"]
const MORE_AI := [
	{"kind": "faisca", "color": "#6b6f7a", "name": "FUMAÇA"},
	{"kind": "trovao", "color": "#d6455c", "name": "BRASA"},
	{"kind": "vespa", "color": "#38c7c7", "name": "PIRANHA"},
]
var em := {}
var scrape_pool: Array = []

var mode := "menu"
var prev_mode := "race"
var save := {}
var stats := {}
var time_g := 0.0
var real := 0.0
var ts := 1.0
var ts_target := 1.0
var slow_t := 0.0
var hitstop := 0.0
var trauma := 0.0
var shake_t := 0.0
var zoom_kick := 0.0
var view_h := 28.0
var cam_pos := Vector3.ZERO
var cam_focus: Car = null
var focus_t := 0.0
var flash := Color(1, 1, 1, 0)
var race_t := 0.0
var countdown := 0.0
var last_beep := 4
var finished_n := 0   # rivais que já completaram todas as voltas
var music: Music
var lap_start := 0.0
var best_lap := INF
var crash_t := -1.0
var place := 5
var onc_dist := 0.0
var nm_combo := 0
var last_nm := -10.0
var was_drift := false
var was_nitro := false
var _last_us := 0
var auto_test := false
var test_shots: Array = []
var test_lane := 0.0
var post_blur := 0.0
var post_aberr := 0.0
var post_lines := 0.0
var wrong_t := 0.0
var steer_testing := false
var test_zoom := 0.0
var cam_yaw := CAM_YAW
var cam_pitch := CAM_PITCH
var cam_mode := ""
var cam_mode_t := 0.0
var cam_loop := {}
var cam_loop_u := 1.0   # 0 = câmera de loop completa, 1 = câmera normal
var cam_kick := Vector3.ZERO
var oil_fx := 0.0
var nitro_zoom := 0.0
var cam_size_mul := 1.0   # tela dividida 2x2: um pouco mais de zoom (quadros menores)


func _ready() -> void:
	randomize()
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		# servidor de salas dedicado (sem gráficos): godot --headless -- --server --port=9080
		var port := 9080
		var cert := ""
		var key := ""
		for a in args:
			if a.begins_with("--port="):
				port = int(a.substr(7))
			if a.begins_with("--cert="):
				cert = a.substr(7)
			if a.begins_with("--key="):
				key = a.substr(6)
		var sv := NetServer.new()
		add_child(sv)
		sv.start(port, "*", cert, key)
		set_process(false)
		set_physics_process(false)
		return
	_setup_input()
	_load_save()
	auto_test = "--autotest" in args
	for a in args:
		if a.begins_with("--shots="):
			test_shots = Array(a.substr(8).split(","))
		if a.begins_with("--lane="):
			test_lane = float(a.substr(7))
		if a.begins_with("--track="):
			track_idx = int(a.substr(8))
		if a.begins_with("--zoom="):
			test_zoom = float(a.substr(7))

	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(1, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(5, 0.6)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.14
	env.adjustment_brightness = 0.97
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 1.1
	sun.shadow_opacity = 0.92
	add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = view_h
	cam.near = 1.0
	cam.far = 500.0
	add_child(cam)
	cam.make_current()
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # a câmera anda no _process

	lib = (load("res://assets/minicars.glb") as PackedScene).instantiate()
	_prep_materials(lib, {})
	ground_shader = load("res://shaders/ground.gdshader")
	road_shader = load("res://shaders/road.gdshader")
	fx = Fx.new()
	add_child(fx)
	fx.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # efeitos posicionados a cada quadro
	sfx = Sfx.new()
	add_child(sfx)
	for i in 6:
		var sc := fx.make_scrape()
		fx.add_child(sc)
		scrape_pool.append(sc)
	weapons = Weapons.new()
	add_child(weapons)
	weapons.setup(self, fx, sfx, lib)
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	music = Music.new()
	add_child(music)
	settings = Settings.new()
	add_child(settings)
	settings.setup(self, hud)
	loader = Loader.new()
	hud.add_child(loader)
	career = Career.new()
	add_child(career)
	career.setup(self, hud)
	if "--careertest" in args:
		# teste: corrida da carreira (mundo N, chefe opcional) com um carro escolhido
		var wi := 0
		var bs := "--boss" in args
		for a in args:
			if a.begins_with("--world="):
				wi = int(a.substr(8))
			if a.begins_with("--car="):
				save.garage.owned.append(a.substr(6))
				career.pick_car(a.substr(6))
		if "--maxup" in args:
			for u in save.up:
				save.up[u] = 3
		if "--maxup" in args or "--kit" in args:
			# teste: arma de ataque e todos os especiais comprados (--spec=X escolhe o equipado)
			var kt: Dictionary = save.garage.kit[String(save.car)]
			kt.front = true
			kt.spec = Car.SPECIAL_ORDER.duplicate()
			kt.eq = String(Career.DEF_SPECIAL[String(save.car)])
			for a in args:
				if a.begins_with("--spec="):
					kt.eq = a.substr(7)
		var tr: int = Career.WORLDS[wi].boss_track if bs else int(Career.WORLDS[wi].tracks[0])
		career.event = {"world": wi, "track": tr, "boss": bs}
		track_idx = tr
	multi = Multi.new()
	add_child(multi)
	multi.setup(self, hud)
	online = NetGame.new()
	add_child(online)
	online.setup(self, hud)
	if "--localtest" in args:
		var devs: Array = ["kbA", "kbB", "joy0", "joy1"]
		var np := 2
		for a in args:
			if a.begins_with("--players="):
				np = int(a.substr(10))
		var pl: Array = []
		for i in np:
			pl.append({"dev": devs[i], "car": Multi.CARS[i % 3], "name": "P%d" % (i + 1), "color": HUMAN_COLORS[i], "local": true})
		session = {"kind": "local", "players": pl}
	load_track(track_idx)
	_last_us = Time.get_ticks_usec()
	if not auto_test:
		music.play_menu()
	if "--overview" in args:
		_overview_shots()
	elif "--showroom" in args:
		_showroom()
	elif "--steertest" in args:
		_steer_test()
	elif "--uishot" in args:
		_ui_shots()
	elif "--server" in args or "--netclient" in args:
		pass   # servidor/cliente de teste: o módulo online cuida
	elif auto_test:
		start_race()


func _steer_test() -> void:
	steer_testing = true
	save.steer = "tela"
	start_race()
	while mode != "race":
		await get_tree().physics_frame
	var rr := Vector3(cos(CAM_YAW), 0, -sin(CAM_YAW))
	var ff := Vector3(-sin(CAM_YAW), 0, -cos(CAM_YAW))
	for test in [["tela", "left", -rr], ["tela", "right", rr], ["tela", "down", -ff], ["tela", "up", ff], ["carro", "left", rr]]:
		save.steer = test[0]
		# carro andando para BAIXO da tela, a 20 m/s, numa reta
		var a := track.at(60.0)
		var down := -ff
		var bs := Basis.looking_at(-down, Vector3.UP)
		player.place(Transform3D(bs, Vector3(400, float(theme.gy) + 0.3, 400)), 20.0)
		wrong_t = -1000.0
		for k in 20:
			await get_tree().physics_frame
		Input.action_press(test[1])
		for k in (150 if test[1] == "up" else 70):
			await get_tree().physics_frame
		Input.action_release(test[1])
		var fwd := player.global_transform.basis.z
		fwd = Vector3(fwd.x, 0, fwd.z).normalized()
		var exp_dir: Vector3 = test[2]
		print("STEER %s tecla=%s  frente·esperado=%.2f  (1 = virou para o lado certo)" % [test[0], test[1], fwd.dot(exp_dir)])
	get_tree().quit()


## fotos de inspeção: pista inteira vista de cima + closes nos elementos especiais e na decoração
## vitrine (teste): carros parados lado a lado com pneus/nível 0..3, câmera bem perto
func _showroom() -> void:
	start_race()
	# espera a pista carregar (a largada passa pela tela de loading)
	while mode != "countdown" and mode != "race":
		await get_tree().physics_frame
	for f in 10:
		await get_tree().physics_frame
	loader.visible = false
	hud.touch.visible = false
	# os 4 carros jogáveis com o kit real (armas do LOADOUT), em níveis diferentes, + Faísca de fábrica sem arma
	var specs := [["faisca", 1], ["vespa", 2], ["trovao", 3], ["monstro", 2], ["faisca", 0], ["monstro", 0]]
	var a0 := track.at(30.0)
	var used := 0
	for c in cars:
		if used >= specs.size():
			c.visible = false
			c.freeze = true
			continue
		var sp: Array = specs[used]
		var lv: int = sp[1]
		if c.kind != String(sp[0]):
			c.visible = false
			c.freeze = true
			continue
		used += 1
	# monta carros novos (sem física) para a foto
	for c in cars:
		c.visible = false
		c.freeze = true
	var k := 0
	for sp in specs:
		var c := Car.new()
		add_child(c)
		c.setup(lib, String(sp[0]), "rival", [Color("#e8352b"), Color("#2f6fd6"), Color("#ffd23a"), Color("#33c46b"), Color("#9b4dff"), Color("#ff7a1a")][k])
		var lv: int = sp[1]
		var lo: Array = Car.LOADOUT[String(sp[0])]
		c.configure(lib, lo[0] if k != 4 else "none", lo[1], lo[2], {"engine": lv, "armor": lv, "ammo": lv, "nitro": lv, "tires": lv, "dmg": lv, "rate": lv})
		c.freeze = true
		var p := (a0.pos as Vector3) + (a0.left as Vector3) * (float(k % 3) - 1.0) * 5.5 - (a0.tan as Vector3) * float(k / 3) * 7.0
		c.global_transform = Transform3D((a0.basis as Basis).rotated(a0.up, 0.6), p + (a0.up as Vector3) * 0.05)
		k += 1
	mode = "shots"
	hud.show_screen("none")
	hud.big_l.visible = false
	for k2 in 6:
		var p2 := (a0.pos as Vector3) + (a0.left as Vector3) * (float(k2 % 3) - 1.0) * 5.5 - (a0.tan as Vector3) * float(k2 / 3) * 7.0
		cam_pos = p2 + Vector3.UP * 0.5
		view_h = 5.5
		for f in 6:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://showroom_t%d_%d.png" % [track_idx, k2])
	get_tree().quit()


func _overview_shots() -> void:
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = int(a.substr(7))
	for ti in TrackData.TRACKS.size():
		if only >= 0 and ti != only:
			continue
		load_track(ti)
		hud.show_screen("none")
		var spots: Array = []
		var i := 0
		while i < track.n and spots.size() < 4:
			if track.feat[i] == 1 and track.feat[track.idx(i - 1)] == 0:
				spots.append(track.P[track.idx(i + 20)])
				i += 40
			i += 1
		# trecho elevado normal (decoração ao lado da pista)
		for k in range(0, track.n, 7):
			if track.feat[k] == 0 and track.P[k].y - float(theme.gy) > 4.0:
				spots.append(track.P[k])
				break
		spots.append(track.P[0])
		for si in spots.size():
			mode = "shots"
			cam_pos = spots[si]
			view_h = 46.0
			for f in 6:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("user://ov_t%d_%d.png" % [ti, si])
	get_tree().quit()


func _ui_shots() -> void:
	if "--loadershot" in OS.get_cmdline_user_args():
		loader.show_for("CIRCUITO DO PARQUE")
		loader.progress = 0.62
		for k in 50:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://ui_loader.png")
		loader.visible = false
	for scr in ["menu", "tracks", "garage", "local", "online", "config", "config2", "pause", "career", "world", "garage2"]:
		if scr == "garage2":
			# garagem no modo história (carro novo: só o item de chão)
			career.event = {"world": 0, "track": 0, "boss": false}
			hud.show_screen("garage")
		elif scr == "career":
			career.open()
		elif scr == "world":
			save.career.points[0] = 22
			career.open_world(0)
		elif scr == "config":
			settings.open("menu")
		elif scr == "config2":
			settings._show_tab("video")
		elif scr == "local":
			multi.open_join()
			multi.slots = [{"dev": "kbA", "car": "faisca"}, {"dev": "joy0", "car": "vespa"}]
			multi._refresh_join()
		elif scr == "online":
			online.open()
		else:
			hud.show_screen(scr)
		for k in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://ui_%s.png" % scr)
	get_tree().quit()


func _exit_tree() -> void:
	if is_instance_valid(lib):
		lib.free()


func _setup_input() -> void:
	var keys := {
		"left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D], "up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S],
		"drift": [KEY_SPACE], "nitro": [KEY_SHIFT, KEY_N], "fire": [KEY_Z, KEY_J, KEY_CTRL], "drop": [KEY_X, KEY_K],
		"special": [KEY_E, KEY_L],
		"brake": [KEY_B, KEY_C],
		"reset": [KEY_R], "pause": [KEY_P, KEY_ESCAPE], "mute": [KEY_M],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	# controles (qualquer um, no jogo solo): analógico/direcional, A/RT acelera, B/LT freio, X tiro,
	# Y mina, RB nitro (mobilidade), LB especial, Start pausa, Back volta à pista
	var axes := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0], "up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0],
		"accel": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "brake": [JOY_AXIS_TRIGGER_LEFT, 1.0]}
	var btns := {"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT], "up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN],
		"accel": [JOY_BUTTON_A], "brake": [JOY_BUTTON_B], "fire": [JOY_BUTTON_X], "drop": [JOY_BUTTON_Y],
		"nitro": [JOY_BUTTON_RIGHT_SHOULDER], "special": [JOY_BUTTON_LEFT_SHOULDER], "pause": [JOY_BUTTON_START], "reset": [JOY_BUTTON_BACK]}
	if not InputMap.has_action("accel"):
		InputMap.add_action("accel")
	for a in axes:
		var ja := InputEventJoypadMotion.new()
		ja.device = -1
		ja.axis = axes[a][0]
		ja.axis_value = axes[a][1]
		InputMap.action_add_event(a, ja)
		InputMap.action_set_deadzone(a, 0.2)
	for a in btns:
		for bi in btns[a]:
			var jb := InputEventJoypadButton.new()
			jb.device = -1
			jb.button_index = bi
			InputMap.action_add_event(a, jb)


# ------------------------------------------------------------------ save
func _load_save() -> void:
	save = {"cash": 800, "car": "faisca", "front": "mg", "rear": "mine", "nitro": "short", "steer": "tela",
		"up": {"engine": 0, "armor": 0, "ammo": 0, "nitro": 0, "tires": 0}, "best": {}}
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				save[k] = d[k]
	for k in ["engine", "armor", "ammo", "nitro", "tires", "dmg", "rate"]:
		save.up[k] = int(save.up.get(k, 0))


func _write_save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))


func upgrade_price(k: String) -> int:
	if career:
		return career.up_price(k)
	return UP_PRICE[mini(int(save.up[k]), 2)]


func buy_upgrade(k: String) -> void:
	var lvl: int = save.up.get(k, 0)
	if lvl >= 3:
		return
	var price := upgrade_price(k)
	if int(save.cash) < price:
		return
	save.cash = int(save.cash) - price
	save.up[k] = lvl + 1
	_write_save()
	sfx.play("pickup")
	hud.refresh_garage()


func equip(slot: String, key: String) -> void:
	if slot == "front" or slot == "special":
		var m := career.buy_front() if slot == "front" else career.pick_special(key)
		if m != "":
			hud.popup(m, Color("#ff7a7a"))
		sfx.play("drop", -6.0)
		hud.refresh_garage()
		return
	if slot == "car":
		var msg := career.pick_car(key)
		if msg != "":
			hud.popup(msg, Color("#ff7a7a"))
		sfx.play("drop", -6.0)
		hud.refresh_garage()
		return
	save[slot] = key
	_write_save()
	sfx.play("drop", -6.0)
	hud.refresh_garage()


# ------------------------------------------------------------------ materiais e cenário
## textura de detalhe procedural (normal map por ruído, em coordenadas do objeto): borracha, metal escovado
## e flocos de pintura — dá "material" às peças sem precisar de UV nos modelos low-poly
var _detail_tex := {}
## reflexos (verniz da pintura, vidro, metal): passadas extras somadas por cima — ver shaders/reflect.gdshader
var refl := {}


func _refl(kind: String) -> ShaderMaterial:
	if not refl.has(kind):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/reflect.gdshader")
		m.render_priority = 1
		match kind:
			"paint":
				m.set_shader_parameter("strength", 1.0)
				m.set_shader_parameter("f0", 0.11)
				m.set_shader_parameter("glint", 1.0)
				m.set_shader_parameter("streaks", 0.22)
				m.set_shader_parameter("streak_freq", 0.22)
				m.set_shader_parameter("streak_w", 0.3)
			"glass":
				m.set_shader_parameter("strength", 1.0)
				m.set_shader_parameter("f0", 0.16)
				m.set_shader_parameter("glint", 1.3)
				m.set_shader_parameter("streaks", 1.5)
				m.set_shader_parameter("streak_freq", 0.6)
				m.set_shader_parameter("streak_w", 0.16)
			"chrome":
				m.set_shader_parameter("strength", 0.55)
				m.set_shader_parameter("f0", 0.55)
				m.set_shader_parameter("glint", 0.9)
				m.set_shader_parameter("tint_amt", 0.4)
				m.set_shader_parameter("tint", Color(0.85, 0.87, 0.92))
		refl[kind] = m
	return refl[kind]


func _refl_theme() -> void:
	Car.refl_metal = _refl("chrome")
	var night := bool(theme.night)
	var dusk := bool(theme.get("dusk", false))
	var k := 0.45 if night else (0.75 if dusk else 1.0)
	for kind in ["paint", "glass", "chrome"]:
		var m := _refl(kind)
		m.set_shader_parameter("sky_top", Color(theme.sky_top) * k)
		m.set_shader_parameter("sky_hor", Color(theme.sky_hor) * k)
		m.set_shader_parameter("ground_col", Color(theme.ga).darkened(0.55).lerp(Color(0.22, 0.22, 0.24), 0.7) * k)
		m.set_shader_parameter("sun_col", Color(theme.sun))
		m.set_shader_parameter("sun_dir", sun.transform.basis.z.normalized())
		m.set_shader_parameter("night", 1.0 if night else (0.4 if dusk else 0.0))


## texturas CC0 do ambientCG (textures/cc0): normal, rugosidade e detalhe de cor, em projeção triplanar
const CC0 := {"rubber": "rubber004", "plastic": "plastic006", "brushed": "metal009", "worn": "metal046a",
	"paintworn": "paintedmetal004", "deck": "diamondplate004", "leather": "leather026"}
const CC0_SCALE := {"rubber": 5.0, "plastic": 2.5, "brushed": 2.2, "worn": 2.0, "paintworn": 1.6, "deck": 4.0, "leather": 3.0}
var _cc0_cache := {}


func _cc0_tex(path: String) -> Texture2D:
	if not _cc0_cache.has(path):
		_cc0_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cc0_cache[path]


func _cc0(m: StandardMaterial3D, kind: String, depth: float, rough: float, detail := true) -> void:
	var base := "res://textures/cc0/%s" % String(CC0[kind])
	var n := _cc0_tex(base + "_n.png")
	if n == null:
		_detail(m, "rubber" if kind in ["rubber", "plastic", "leather"] else "brushed", depth * 0.5)
		return
	m.normal_enabled = true
	m.normal_texture = n
	m.normal_scale = depth
	var r := _cc0_tex(base + "_r.png")
	if r:
		m.roughness_texture = r
		m.roughness = clampf(rough / 0.75, 0.0, 1.0)
	var c := _cc0_tex(base + "_c.png")
	if detail and c:
		m.detail_enabled = true
		m.detail_albedo = c
		m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * float(CC0_SCALE[kind])


func _detail(m: StandardMaterial3D, kind: String, depth: float) -> void:
	if not _detail_tex.has(kind):
		var nz := FastNoiseLite.new()
		var tex := NoiseTexture2D.new()
		tex.width = 256
		tex.height = 256
		tex.seamless = true
		tex.as_normal_map = true
		match kind:
			"rubber":
				nz.noise_type = FastNoiseLite.TYPE_CELLULAR
				nz.frequency = 0.09
				tex.bump_strength = 4.0
			"brushed":
				nz.noise_type = FastNoiseLite.TYPE_SIMPLEX
				nz.frequency = 0.02
				nz.fractal_octaves = 3
				tex.bump_strength = 2.0
			_:
				nz.noise_type = FastNoiseLite.TYPE_VALUE
				nz.frequency = 0.35
				tex.bump_strength = 1.2
		tex.noise = nz
		_detail_tex[kind] = tex
	m.normal_enabled = true
	m.normal_texture = _detail_tex[kind]
	m.normal_scale = depth
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.uv1_scale = Vector3.ONE * (6.0 if kind == "rubber" else (3.0 if kind == "brushed" else 9.0))
	if kind == "brushed":
		m.uv1_scale = Vector3(1.0, 14.0, 1.0)   # riscos alongados (escovado)


func _prep_materials(n: Node, done: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m == null or done.has(m):
				continue
			done[m] = true
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = false
			match m.resource_name:
				"Paint", "Paint2":
					m.roughness = 0.24
					m.metallic = 0.18
					m.metallic_specular = 0.7
					m.rim_enabled = true
					m.rim = 0.25
					m.rim_tint = 0.6
					_detail(m, "flake", 0.12)   # pintura metálica: "flocos" finos no reflexo
					m.next_pass = _refl("paint")   # verniz: reflexo do céu e brilho do sol
				"Tire", "Sidewall", "Hose":
					m.metallic_specular = 0.3
					_cc0(m, "rubber", 0.9, 0.92)   # borracha de verdade (Rubber004)
				"RimDark":
					m.metallic = 0.85
					_cc0(m, "brushed", 0.4, 0.38, false)
				"Trim":
					_cc0(m, "plastic", 0.6, 0.62)   # plástico fosco com marcas de uso
				"Gunmetal", "Exhaust":
					_cc0(m, "worn", 0.7, 0.45)   # metal gasto
				"Deck":
					_cc0(m, "deck", 1.0, 0.5)   # chapa xadrez
				"Seat":
					_cc0(m, "leather", 0.6, 0.7)
				"MineYellow", "Olive", "RocketRed", "AmmoGreen":
					_cc0(m, "paintworn", 0.5, 0.55)   # pintura riscada das armas
				"Steel", "Copper", "Brass":
					m.metallic = 1.0
					_cc0(m, "brushed", 0.35, 0.3, false)
					m.next_pass = _refl("chrome")
				"Glass":
					m.roughness = 0.03
					m.metallic = 0.7
					m.metallic_specular = 1.0
					m.next_pass = _refl("glass")
				"Chrome", "Rim", "LugNut":
					m.metallic = 1.0
					_cc0(m, "brushed", 0.3, 0.16, false)   # metal escovado (Metal009)
					m.next_pass = _refl("chrome")
				"SignYellow", "SignBlack", "Metal":
					m.cull_mode = BaseMaterial3D.CULL_DISABLED
				"Headlight", "Taillight", "LampGlow", "Window", "Billboard", "Billboard2", "CrystalC", "CrystalM", "RedLight", "NitroBlue":
					m.vertex_color_use_as_albedo = false
	for c in n.get_children():
		_prep_materials(c, done)


func _inst(name_: String) -> Node3D:
	var n := lib.get_node(name_).duplicate() as Node3D
	n.transform = Transform3D.IDENTITY
	_shadows(n)
	return n


func _shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in n.get_children():
		_shadows(c)


func load_track(i: int) -> void:
	Engine.time_scale = 1.0
	track_idx = i
	if world:
		remove_child(world)
		world.queue_free()
	weapons.clear()
	for d in fx.debris:
		(d.rb as Node).queue_free()
	fx.debris.clear()
	for tr in fx.trails:
		(tr.mi as Node).queue_free()
	fx.trails.clear()
	fx.skid_mm.visible_instance_count = 0
	fx.skid_head = 0
	em.clear()
	cars.clear()
	rivals.clear()
	traffic.clear()
	props.clear()
	pickups.clear()
	var data: Dictionary = TrackData.TRACKS[i]
	theme = TrackData.THEMES[data.theme]
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	track = Track.new()
	track.setup(data, theme)
	world.add_child(track)
	track.build(ground_shader, road_shader)
	_apply_theme()
	_build_scenery()
	_spawn_cars()
	hud.set_track(track)
	hud.cars = cars
	hud.player = player
	cam_pos = player.global_position
	mode = "menu"


func _apply_theme() -> void:
	sky_mat.sky_top_color = Color(theme.sky_top)
	sky_mat.sky_horizon_color = Color(theme.sky_hor)
	sky_mat.ground_horizon_color = Color(theme.sky_hor)
	sky_mat.ground_bottom_color = Color(theme.ga).darkened(0.3)
	env.background_color = Color(theme.bg)
	# color grade: ambiente mais baixo (sombras mais densas) e noites bem mais escuras
	var night := bool(theme.night)
	var dusk := bool(theme.get("dusk", false))
	env.ambient_light_energy = float(theme.amb) * (0.95 if night else (0.75 if dusk else 0.72))
	# à noite parte da luz ambiente vem de uma cor de "luar" (o céu noturno sozinho deixava tudo escuro)
	env.ambient_light_sky_contribution = 0.5 if night else (0.75 if dusk else 1.0)
	env.ambient_light_color = Color(0.46, 0.52, 0.74) if night else Color(0.62, 0.6, 0.66)
	env.tonemap_exposure = 1.0 if night else (0.98 if dusk else 1.0)
	env.adjustment_saturation = 1.18 if night else 1.1
	env.adjustment_contrast = 1.2 if night else 1.14
	env.fog_enabled = String(theme.fog) != ""
	if env.fog_enabled:
		env.fog_light_color = Color(theme.fog)
		env.fog_density = float(theme.get("fog_d", 0.0011))
	sun.light_color = Color(theme.sun)
	sun.light_energy = float(theme.sun_e) * (0.7 if night else (0.8 if dusk else 1.05))
	sun.rotation = Vector3(deg_to_rad(theme.sun_rot[0]), deg_to_rad(theme.sun_rot[1]), 0)
	_refl_theme()
	env.glow_intensity = 0.8 if night else 0.55


func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337 + track_idx * 101
	var a0 := track.at(0.0)
	var gate := _inst("prop_gate")
	var gs: float = (track.WALL - 0.35) / 13.0
	# arco sempre de pé e alinhado com a linha xadrez: só o rumo da pista (sem a inclinação nem a rampa),
	# com os pés na altura mais baixa das bordas (nenhum pé fica flutuando)
	var th := Vector3((a0.tan as Vector3).x, 0, (a0.tan as Vector3).z).normalized()
	var lh := Vector3(th.z, 0, -th.x)
	var e1: Vector3 = (a0.pos as Vector3) + (a0.left as Vector3) * (track.WALL - 0.35)
	var e2: Vector3 = (a0.pos as Vector3) - (a0.left as Vector3) * (track.WALL - 0.35)
	var gate_p := Vector3((a0.pos as Vector3).x, minf(e1.y, e2.y) - 0.05, (a0.pos as Vector3).z)
	gate.transform = Transform3D(Basis(lh, Vector3.UP, th).scaled_local(Vector3(gs, 1, 1)), gate_p)
	world.add_child(gate)
	for e in [[24.0, -1.0], [50.0, -1.0], [-30.0, 1.0]]:
		var p := track.at(e[0], e[1] * (track.WALL + 4.0))
		if track.U[p.i].y < 0.9 or track.P[p.i].y - float(theme.gy) > 1.5 or float(theme.gy) < -0.5:
			continue
		var st := _inst("prop_stand")
		var n: Vector3 = (p.left as Vector3) * -float(e[1])
		st.position = Vector3(p.pos.x, float(theme.gy), p.pos.z)
		st.rotation.y = atan2(n.x, n.z)
		world.add_child(st)
	for spot in track.decor_spots():
		var nd := _inst(spot.kind)
		nd.transform = spot.xf
		if spot.get("flip", false):
			nd.scale = Vector3(-1, 1, 1)
		world.add_child(nd)
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for i in range(0, track.n, 5):
		mn = mn.min(Vector2(track.P[i].x, track.P[i].z))
		mx = mx.max(Vector2(track.P[i].x, track.P[i].z))
	mn -= Vector2(70, 70)
	mx += Vector2(70, 70)
	var list: Array = theme.props
	var total := 0
	for it in list:
		total += int(it[1])
	var gy: float = theme.gy
	var placed := 0
	var dens: int = theme.density
	var pscale: float = theme.get("prop_scale", 1.0)
	for k in dens * 4:
		if placed >= dens or total == 0:
			break
		var x := rng.randf_range(mn.x, mx.x)
		var z := rng.randf_range(mn.y, mx.y)
		if track.clearance_xz(Vector3(x, 0, z)) < track.WALL + 5.0 * pscale:
			continue
		var r := rng.randi() % total
		var kind := ""
		for it in list:
			r -= int(it[1])
			if r < 0:
				kind = it[0]
				break
		if kind == "container":
			_container_pad(Vector3(x, gy, z), rng)
		else:
			var m := _inst(kind)
			var base_y := gy
			if gy < -0.5:
				base_y = gy + 0.6
				_mound(Vector3(x, gy, z), rng.randf_range(2.4, 3.6))
			m.position = Vector3(x, base_y, z)
			m.rotation.y = rng.randf() * TAU
			m.scale = Vector3.ONE * (0.8 + rng.randf() * 0.7) * pscale
			world.add_child(m)
		placed += 1
	placed = 0
	var bn: int = theme.bldg
	for k in bn * 6:
		if placed >= bn:
			break
		var x := rng.randf_range(mn.x - 40, mx.x + 40)
		var z := rng.randf_range(mn.y - 40, mx.y + 40)
		if track.clearance_xz(Vector3(x, 0, z)) < track.WALL + 12.0:
			continue
		var b := _inst(["prop_bldgA", "prop_bldgB", "prop_bldgC"][rng.randi() % 3])
		b.position = Vector3(x, gy, z)
		b.rotation.y = round(rng.randf() * 4.0) * PI / 2.0
		if theme.night:
			b.scale = Vector3(1.0, 1.0 + rng.randf() * 1.5, 1.0)
		world.add_child(b)
		placed += 1
	if theme.ground == 8:
		_clouds(rng, mn, mx)
		_sky_decor(rng, mn, mx)
	if theme.ground == 9:
		_swamp_decor(rng, mn, mx)
	for ps in track.pickup_spots:
		var a := track.at(ps.s, ps.lat)
		var nd := _inst("pickup_" + String(ps.kind))
		nd.position = a.pos + a.up * 1.0
		world.add_child(nd)
		var glow := MeshInstance3D.new()
		var gp := PlaneMesh.new()
		gp.size = Vector2(3.2, 3.2)
		glow.mesh = gp
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.albedo_texture = fx.dot_tex
		gm.albedo_color = {"ammo": Color(0.6, 1.4, 0.4), "repair": Color(1.5, 0.5, 0.45), "nitro": Color(0.4, 0.9, 1.6)}[ps.kind]
		glow.material_override = gm
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.transform = Transform3D(a.basis, (a.pos as Vector3) + (a.up as Vector3) * 0.1)
		world.add_child(glow)
		pickups.append({"node": nd, "kind": ps.kind, "t": 0.0, "base": a.pos + a.up * 1.0, "up": a.up})
	var made := 0
	for i in track.n:
		if made >= 6:
			break
		if track.feat[i] == 0 and absf(track.curv[i]) > 1.0 / 32.0 and track.U[i].y > 0.95 and i % 4 == 0:
			var outside := signf(track.curv[i])
			for j in 3:
				var a := track.at(i * track.ds + j * 2.5, outside * (track.HALF + 0.6))
				_add_prop("prop_crate" if theme.road == 1 else ["prop_barrel", "prop_tires"][j % 2], a, 30.0, Vector2(0.5, 1.0))
			made += 1


## Céu: ilhas flutuantes em várias alturas e balões subindo e descendo devagar
func _sky_decor(rng: RandomNumberGenerator, mn: Vector2, mx: Vector2) -> void:
	var placed := 0
	for k in 220:
		if placed >= 16:
			break
		var x := rng.randf_range(mn.x - 30, mx.x + 30)
		var z := rng.randf_range(mn.y - 30, mx.y + 30)
		var p := Vector3(x, 0, z)
		if track.clearance_xz(p) < track.WALL + 16.0:
			continue
		var isl := _inst("prop_island")
		var sc := rng.randf_range(0.8, 1.9)
		isl.position = Vector3(x, float(theme.gy) + rng.randf_range(6.0, 26.0), z)
		isl.rotation.y = rng.randf() * TAU
		isl.scale = Vector3.ONE * sc
		world.add_child(isl)
		placed += 1
	placed = 0
	for k in 200:
		if placed >= 7:
			break
		var x := rng.randf_range(mn.x, mx.x)
		var z := rng.randf_range(mn.y, mx.y)
		if track.clearance_xz(Vector3(x, 0, z)) < track.WALL + 10.0:
			continue
		var b := _inst("prop_balloon")
		var y0 := float(theme.gy) + rng.randf_range(18.0, 40.0)
		b.position = Vector3(x, y0, z)
		b.rotation.y = rng.randf() * TAU
		b.scale = Vector3.ONE * rng.randf_range(1.4, 2.0)
		world.add_child(b)
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "position:y", y0 + 2.5, rng.randf_range(3.5, 5.5)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "position:y", y0, rng.randf_range(3.5, 5.5)).set_trans(Tween.TRANS_SINE)
		placed += 1


## Pântano: touceiras de taboa na beira da pista e vaga-lumes no ar
func _swamp_decor(rng: RandomNumberGenerator, mn: Vector2, mx: Vector2) -> void:
	for i in range(0, track.n, 7):
		if track.feat[i] == 1 or track.gap[i] == 1 or track.P[i].y - float(theme.gy) > 4.0:
			continue
		for sg: float in [-1.0, 1.0]:
			if rng.randf() < 0.45:
				continue
			var off := track.WALL + rng.randf_range(1.5, 6.0)
			var pp: Vector3 = track.P[i] + track.L[i] * sg * off
			if track.clearance_xz(pp) < track.WALL + 1.0:
				continue
			var r := _inst("prop_reeds")
			r.position = Vector3(pp.x, float(theme.gy) - 0.1, pp.z)
			r.rotation.y = rng.randf() * TAU
			r.scale = Vector3.ONE * rng.randf_range(1.0, 1.7)
			world.add_child(r)
	var ff := CPUParticles3D.new()
	ff.amount = 160
	ff.lifetime = 6.0
	ff.preprocess = 6.0
	ff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var c := (mn + mx) * 0.5
	ff.position = Vector3(c.x, float(theme.gy) + 3.0, c.y)
	ff.emission_box_extents = Vector3((mx.x - mn.x) * 0.5, 2.5, (mx.y - mn.y) * 0.5)
	ff.direction = Vector3(0, 1, 0)
	ff.spread = 180
	ff.initial_velocity_min = 0.2
	ff.initial_velocity_max = 0.8
	ff.gravity = Vector3.ZERO
	ff.damping_min = 0.1
	ff.damping_max = 0.3
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	q.material = fx._bb_mat(fx.star_tex, true)
	ff.mesh = q
	ff.color_ramp = fx._ramp([Color(2.2, 2.6, 0.6, 0.0), Color(2.4, 2.8, 0.7, 1.0), Color(1.6, 2.2, 0.4, 0.0), Color(2.4, 2.8, 0.7, 0.9), Color(2.2, 2.6, 0.6, 0.0)])
	ff.local_coords = false
	ff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ff)
	ff.emitting = true


func _mound(p: Vector3, r: float) -> void:
	# ilhota de terra/pedra embaixo dos objetos na água ou na lava
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.75
	cm.bottom_radius = r
	cm.height = 1.4
	cm.radial_segments = 9
	cm.rings = 1
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(theme.shoulder).darkened(0.1) if (theme.ground != 3 and theme.ground != 9) else Color("#4f5e30")
	m.roughness = 1.0
	mi.material_override = m
	mi.position = p + Vector3(0, -0.1, 0)
	mi.rotation.y = randf() * TAU
	world.add_child(mi)


func _container_pad(p: Vector3, rng: RandomNumberGenerator) -> void:
	var pad := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(9, 4, 15)
	pad.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#8a8d94")
	m.roughness = 0.9
	pad.material_override = m
	pad.position = p + Vector3(0, 1.6, 0)
	pad.rotation.y = rng.randf() * TAU
	world.add_child(pad)
	var cnt := rng.randi_range(1, 3)
	for k in cnt:
		var c := _inst(["prop_containerR", "prop_containerB", "prop_containerY"][rng.randi() % 3])
		c.position = Vector3([-2.5, 2.5, 0.0][k], 2.0 + (2.6 if k == 2 else 0.0), 0)
		pad.add_child(c)


func _clouds(rng: RandomNumberGenerator, mn: Vector2, mx: Vector2) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1)
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.85, 0.88, 1.0)
	m.emission_energy_multiplier = 0.35
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 7
	for k in 34:
		var c := Vector3(rng.randf_range(mn.x, mx.x), float(theme.gy) + rng.randf_range(-3, 3), rng.randf_range(mn.y, mx.y))
		var s := rng.randf_range(6, 14)
		for b in rng.randi_range(4, 7):
			var mi := MeshInstance3D.new()
			mi.mesh = sm
			mi.material_override = m
			var bs := s * rng.randf_range(0.5, 1.0)
			mi.scale = Vector3(bs, bs * 0.75, bs)
			mi.position = c + Vector3(rng.randf_range(-1.4, 1.4) * s, rng.randf_range(0.0, 0.5) * s, rng.randf_range(-1.0, 1.0) * s)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(mi)


func _add_prop(name_: String, a: Dictionary, m: float, dims: Vector2) -> void:
	var rb := RigidBody3D.new()
	rb.mass = m
	rb.collision_layer = 4
	rb.collision_mask = 1 | 2 | 4
	rb.contact_monitor = true
	rb.max_contacts_reported = 2
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 0.6
	rb.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = dims.x
	c.height = dims.y
	cs.shape = c
	cs.position.y = dims.y * 0.5
	rb.add_child(cs)
	rb.add_child(_inst(name_))
	world.add_child(rb)
	rb.global_transform = Transform3D(a.basis, (a.pos as Vector3) + (a.up as Vector3) * 0.05)
	var pr := {"rb": rb, "hit": false, "name": name_}
	props.append(pr)
	rb.body_entered.connect(func(b): _prop_hit(pr, b))


func _prop_hit(pr: Dictionary, b: Node) -> void:
	if pr.hit or not (b is Car):
		return
	pr.hit = true
	var c: Car = b
	var rb: RigidBody3D = pr.rb
	var v := c.linear_velocity
	rb.apply_central_impulse((v * 0.5 + Vector3.UP * (4.0 + v.length() * 0.25)) * rb.mass)
	rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * rb.mass * 3.0)
	fx.sparks(rb.global_position + Vector3.UP * 0.5, v, 0.3)
	fx.burst("smoke", rb.global_position + Vector3.UP * 0.4)
	if c == player and mode == "race":
		sfx.play("smash", -4.0)
		_shake(0.2)
		stats.score += 25


# ------------------------------------------------------------------ carros
func _make_car(kind: String, role: String, col: Color) -> Car:
	var c := Car.new()
	c.game = self
	c.setup(lib, kind, role, col)
	c.grav_factor = float(theme.grav)
	c.grip_factor = float(theme.grip)
	world.add_child(c)
	c.hit.connect(_on_hit)
	c.part_off.connect(_on_part_off)
	c.landed.connect(_on_landed)
	c.died.connect(_on_died)
	cars.append(c)
	var e := {"skid": [null, null, null, null]}
	if role != "traffic":
		e.smoke = [fx.make_tire_smoke(), fx.make_tire_smoke()]
		e.dust = [fx.make_dust(), fx.make_dust()]
		for s in e.smoke + e.dust:
			world.add_child(s)
			s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_add_xray(c)
		if bool(theme.night) or bool(theme.get("dusk", false)):
			e.lights = _add_headlights(c)
		e.flame = fx.make_nitro_flame()
		c.add_child(e.flame)
		e.flame.position = c.exhaust_local
		# segundo cano: mesma chama, sem luz própria (uma luz por carro basta)
		e.flame2 = fx.make_nitro_flame(false)
		c.add_child(e.flame2)
		e.flame2.position = c.exhaust2_local
		e.trails = [fx.make_trail(Color(1.5, 0.25, 0.4)), fx.make_trail(Color(1.5, 0.25, 0.4))]
	e.dark = fx.make_damage_smoke(true)
	e.fire = fx.make_damage_smoke(false)
	c.add_child(e.dark)
	c.add_child(e.fire)
	e.dark.position = Vector3(0, 1.0, c.sp.len * 0.3)
	e.fire.position = Vector3(0, 0.9, c.sp.len * 0.3)
	e.shadow = fx.contact_shadow(c.sp.len, c.sp.wid)
	world.add_child(e.shadow)
	e.shadow.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if role == "player":
		e.wind = fx.make_wind()
		world.add_child(e.wind)
		e.wind.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	em[c] = e
	return c


func _place(c: Car, s: float, lat: float, speed: float) -> void:
	var a := track.at(s, lat)
	var b: Basis = a.basis
	if c.oncoming:
		b = b.rotated(a.up, PI)
	c.place(Transform3D(b, (a.pos as Vector3) + (a.up as Vector3) * 0.25), speed)
	var pr := track.project(a.pos)
	c.ti = pr.i
	c.s_track = pr.s
	c.lat = pr.lat
	c.lane = lat
	c.lane_t = lat
	c.lane_cur = lat


func _spawn_cars() -> void:
	var L := track.length
	var lw := track.W * 0.22
	humans.clear()
	boss = null
	var ev: Dictionary = career.event if career and career.active() else {}
	var wlv: int = int(Career.WORLDS[int(ev.world)].lv) if not ev.is_empty() else -1
	locals.clear()
	# quem corre: pessoas (locais ou da sala online) + IA para completar o grid
	var people: Array = session.players if session.kind != "solo" and session.players.size() > 0 else [{"dev": "solo", "name": "VOCÊ", "car": save.car, "local": true, "color": String(save.get("color", HUMAN_COLORS[0]))}]
	var n_ai: int = int(session.get("ai", -1))
	if n_ai < 0:
		n_ai = mini(RIVALS.size(), 8 - people.size()) if session.kind != "online" else clampi(6 - people.size(), 0, 4)
	if session.kind == "solo":
		n_ai = RIVALS.size()
	if not ev.is_empty() and bool(ev.boss):
		n_ai = 3   # chefe + 3 rivais
	var total: int = people.size() + n_ai + (1 if not ev.is_empty() and bool(ev.boss) else 0)
	# grid: fileiras de 2 (o último sozinho no meio se sobrar); IA na frente, pessoas atrás (como no solo)
	var grid: Array = []
	for i in total:
		var row := i / 2
		var lat := (-lw if i % 2 == 0 else lw)
		if i == total - 1 and total % 2 == 1:
			lat = 0.0
		grid.append([-9.0 - row * 9.0, lat])
	var ai_list: Array = RIVALS + MORE_AI
	var gi := 0
	if not ev.is_empty() and bool(ev.boss):
		# CHEFE: largando na frente de todos
		var wd: Dictionary = Career.WORLDS[int(ev.world)]
		var bc := _make_car(String(wd.boss), "rival", Color(String(wd.boss_col)))
		bc.display_name = String(wd.boss_name)
		bc.seed_f = 0.3
		bc.cruise = 38.5 + int(ev.world) * 0.8
		bc.ai_skill = 1.02
		bc.next_bash = 4.0
		bc.configure(lib, "none", "none", "short", {"engine": 0, "armor": 0, "_tier": 3, "_tire_vis": 3})
		_add_xray(bc)
		bc.slot = 0
		_place(bc, L + grid[0][0] + 4.0, 0.0, 0)
		var bn := Boss.new()
		bc.add_child(bn)
		bn.setup(bc, self)
		rivals.append(bc)
		boss = bc
		gi = 1
	# rivais com a cara do mundo: na carreira, dois deles correm com o carro do tema; na corrida rápida, carros variados
	const WORLD_RIVAL := [["zefiro", "#e8f0ff", "BRISA"], ["jacare", "#5a7a32", "SUCURI"], ["escorpiao", "#d9822b", "MIRAGEM"],
		["nevasca", "#f2f5fa", "GLACIAL"], ["nemesis", "#7b2cff", "NEON"], ["falcao", "#2ec4ff", "TURBINA"]]
	for i in n_ai:
		var r: Dictionary = ai_list[i % ai_list.size()]
		if not ev.is_empty() and i % 2 == 0:
			var wr: Array = WORLD_RIVAL[int(ev.world)]
			r = {"kind": wr[0], "color": wr[1], "name": wr[2] if i == 0 else String(wr[2]) + " II"}
		elif ev.is_empty() and i % 3 == 1:
			var wr2: Array = WORLD_RIVAL[(track_idx + i) % WORLD_RIVAL.size()]
			r = {"kind": wr2[0], "color": wr2[1], "name": wr2[2]}
		var c := _make_car(r.kind, "rival", Color(r.color))
		c.display_name = r.name
		c.seed_f = i * 2.1 + 0.5
		c.cruise = 36.0 + i * 0.5 + track_idx * 0.25
		c.ai_skill = randf_range(0.95, 1.03) if session.kind != "online" else 0.99 + 0.01 * (i % 3)
		c.next_bash = 6.0 + i * 3.0
		var lv := clampi(track_idx / 3 + (i % 3), 0, 3)
		if wlv >= 0:
			# carreira: rivais mais fortes a cada mundo (motor, blindagem e pneus)
			lv = clampi(wlv + (i % 2), 0, 3)
			c.cruise = 36.5 + wlv * 1.3 + i * 0.4
		var rup := {"engine": lv / 2 + (1 if wlv >= 2 else 0), "armor": lv / 2, "ammo": 0, "nitro": 0, "tires": lv / 2, "_tier": lv, "_tire_vis": lv,
			"dmg": maxi(0, wlv - 2) if wlv >= 0 else 0, "rate": maxi(0, wlv - 3) if wlv >= 0 else 0}
		var lo: Array = Car.LOADOUT.get(String(r.kind), ["mg", "oil", "short"])
		# especial dos rivais: no modo história só a partir do 2º mundo
		var rsp := ""
		var give := i % 3 != 2 if wlv < 0 else (wlv >= 1 or i % 4 == 3)
		if give:
			rsp = String(Car.SPECIAL_ORDER[(i + int(r.kind.length())) % Car.SPECIAL_ORDER.size()])
		c.configure(lib, lo[0], lo[1], lo[2], rup, rsp)
		_add_xray(c)
		c.slot = gi
		_place(c, L + grid[gi][0], grid[gi][1], 0)
		rivals.append(c)
		gi += 1
	var li := 0
	for k in people.size():
		var pp: Dictionary = people[k]
		var is_local: bool = bool(pp.get("local", true))
		var ck := String(pp.get("car", "faisca"))
		if not Car.LOADOUT.has(ck):
			ck = "faisca"
		var c := _make_car(ck, "player" if is_local else "rival", Color(String(pp.get("color", HUMAN_COLORS[k % HUMAN_COLORS.size()]))))
		c.human = true
		c.display_name = String(pp.get("name", "P%d" % (k + 1)))
		c.slot = gi
		c.owner_id = int(pp.get("id", 0))
		var up: Dictionary = pp.get("up", save.up) if not is_local or li == 0 else save.garage.up.get(ck, save.up)
		var lo: Array = Car.LOADOUT[ck]
		var kit: Array = [lo[0], lo[1], lo[2], String(pp.get("spec", Career.DEF_SPECIAL.get(ck, "shield")))]
		if is_local and li == 0:
			kit = career.loadout(ck)   # modo história: só o que foi comprado
		c.configure(lib, kit[0], kit[1], kit[2], up, kit[3])
		_add_xray(c)
		c.turn_mult = 1.15
		_place(c, L + grid[gi][0], grid[gi][1], 0)
		gi += 1
		humans.append(c)
		if is_local:
			c.local_idx = li
			locals.append({"car": c, "dev": String(pp.get("dev", "solo")), "idx": li, "name": c.display_name, "done": false})
			li += 1
		else:
			c.net_remote = true
			c.role = "remote"
	player = locals[0].car if locals.size() > 0 else humans[0]
	var tc: int = track.data.traffic
	for i in tc:
		var t: Array = TRAFFIC[i % TRAFFIC.size()]
		var cols: Array = t[1]
		var c := _make_car(t[0], "traffic", Color(cols[randi() % cols.size()]))
		c.oncoming = i % 5 == 1 or i % 5 == 3
		c.cruise = randf_range(15, 20) if c.oncoming else randf_range(13, 19)
		var s := 60.0 + (float(i) / tc) * (L - 100.0) + randf_range(-8, 8)
		var lanes: Array = track.lanes_onc if c.oncoming else track.lanes_fwd
		_place(c, s, lanes[randi() % 2], c.cruise)
		traffic.append(c)
	for c in cars:
		var pr := track.project(c.global_position)
		c.dist = pr.s - L if pr.s > L * 0.5 else pr.s
		c.prev_s = pr.s
		c.lap = 0
	for c in humans + rivals:
		c.freeze = true
	if online:
		online.on_spawned()


## carros da corrida (pessoas + IA), sem o trânsito
func racers() -> Array:
	return rivals + humans


func is_mp() -> bool:
	return session.kind != "solo"


func local_of(c: Car) -> Dictionary:
	if c == null or c.local_idx < 0 or c.local_idx >= locals.size():
		return {}
	return locals[c.local_idx]


## mensagens/sacudidas do jogador c: P1 em tela cheia usa o HUD normal; na tela dividida vão para o quadro dele
func pop_for(c: Car, text: String, col: Color, sub := "") -> void:
	if c == null or c.local_idx < 0:
		return
	if multi and multi.split:
		multi.pop(c.local_idx, text + ("  " + sub if sub != "" else ""), col)
	else:
		hud.popup(text, col, sub)


func big_for(c: Car, text: String, col: Color, outline: Color) -> void:
	if c == null or c.local_idx < 0:
		return
	if multi and multi.split:
		multi.pop(c.local_idx, text, col, true)
	else:
		hud.big(text, col, outline)


func shake_for(c: Car, a: float) -> void:
	if c == player:
		_shake(a)
	elif c and c.local_idx > 0 and multi:
		multi.shake(c.local_idx, a)


# ------------------------------------------------------------------ fluxo
func choose_track(i: int) -> void:
	if online and online.in_room():
		online.pick_track(i)
		return
	if not career.event.is_empty() and int(career.event.track) != i:
		career.event = {}
	load_track(i)
	if session.kind == "local":
		start_race()
		return
	hud.show_screen("garage")


func set_solo() -> void:
	session = {"kind": "solo", "players": []}


func to_menu_mp() -> void:
	set_solo()
	to_menu()


func next_track() -> void:
	if career.active():
		career.open_world(int(career.event.world))
		return
	load_track((track_idx + 1) % TrackData.TRACKS.size())
	hud.show_screen("garage")


var _loading := false


## largada com a tela de carregamento (carrinho andando) enquanto a pista é montada
func start_race() -> void:
	if auto_test or loader == null or _loading:
		_start_race_now()
		return
	_loading = true
	loader.show_for(String(TrackData.TRACKS[track_idx].name).to_upper())
	loader.progress = 0.35
	hud.show_screen("none")
	for i in 3:
		await get_tree().process_frame
	loader.progress = 0.7
	await get_tree().process_frame
	_start_race_now()
	loader.progress = 1.0
	await get_tree().process_frame
	loader.finish()
	_loading = false


func _start_race_now() -> void:
	load_track(track_idx)
	stats = {"kills": 0, "takedowns": 0, "near": 0, "best_drift": 0.0, "air": 0.0, "falls": 0, "deaths": 0, "score": 0, "oncoming": 0.0, "prize": 0}
	race_t = 0.0
	lap_start = 0.0
	best_lap = INF
	ts = 1.0
	ts_target = 1.0
	slow_t = 0.0
	hitstop = 0.0
	crash_t = -1.0
	cam_focus = null
	place = racers().size()
	finished_n = 0
	race_end_t = -1.0
	for c in racers():
		c.set_meta("done", false)
		c.set_meta("kills", 0)
	if multi:
		multi.setup_views()
	hud.show_screen("race")
	hud.touch.release_all()
	hud.touch.labels["drop"] = String(Car.LBL_R.get(player.rear_type, "MINA"))
	hud.touch.labels["fire"] = String(Car.LBL_F.get(player.front_type, "TIRO"))
	hud.touch.labels["nitro"] = String(Car.NITRO[player.nitro_type].label)
	hud.touch.labels["special"] = String(Car.SPECIAL[player.special_type].label) if player.special_type != "" else ""
	mode = "countdown"
	if not auto_test:
		music.play_track(track_idx, String(track.data.theme), boss != null)
		if music.now_text != "":
			hud.killfeed("♪ " + music.now_text, Color(1.0, 0.85, 0.45))
	countdown = 4.2   # ~1 s mostrando o nome da pista, depois 3, 2, 1, VAI!
	# compila os shaders dos efeitos agora, escondidos sob a largada (evita tranco na 1ª explosão/nitro)
	var a0 := track.at(6.0)
	fx.prewarm((a0.pos as Vector3) - (a0.up as Vector3) * 2.5, lib)
	last_beep = 4
	hud.big(String(track.data.name).to_upper(), Color("#ffcf33"), Color("#c74200"))


func to_menu() -> void:
	if online:
		online.leave()
	set_solo()
	Engine.time_scale = 1.0
	if multi:
		multi.setup_views()
	load_track(track_idx)
	hud.show_screen("menu")
	music.play_menu()


func pause(on: bool) -> void:
	if on and online.racing and mode in ["race", "countdown", "finish"]:
		hud.show_screen("pause")   # online o jogo não para: só abre o menu por cima
		return
	if not on and online.racing and hud.cur_screen == "pause":
		hud.show_screen("race")
		return
	if on and mode in ["race", "countdown"]:
		prev_mode = mode
		mode = "paused"
		hud.show_screen("pause")
		Engine.time_scale = 0.0
		music.set_paused(true)
	elif not on and mode == "paused":
		mode = prev_mode
		hud.show_screen("race")
		music.set_paused(false)


func toggle_steer() -> void:
	save.steer = "carro" if String(save.get("steer", "tela")) == "tela" else "tela"
	_write_save()
	hud.refresh_steer()
	hud.popup("DIREÇÃO: " + ("APONTA NA TELA" if save.steer == "tela" else "GIRA O CARRO"), Color("#2ee6ff"))


func toggle_mute() -> void:
	sfx.set_muted(not sfx.muted)


# ------------------------------------------------------------------ eventos
func _on_hit(c: Car, other: Object, point: Vector3, dv: float) -> void:
	var oc: Car = other as Car
	if oc:
		c.last_hit_by = oc
		c.last_hit_t = time_g
	if mode != "race":
		return
	var wall: bool = other is Node and (other as Node).has_meta("rail")
	c.take_impact(point, dv, wall)
	var vis := _on_screen(point)
	var out := (point - c.global_position).normalized()
	if vis and dv > 4.0:
		var back := -c.linear_velocity.normalized() * 0.6
		fx.sparks(point + Vector3.UP * 0.3, out + back, clampf(dv / 14.0, 0.3, 2.0))
		if dv > 10.0:
			fx.hit_light(point + Vector3.UP, Color(1.0, 0.7, 0.3), clampf(dv * 0.35, 3.0, 9.0), 9.0, 0.25)
	if c.local_idx > 0 and dv > 5.0:
		shake_for(c, minf(0.5, dv * 0.022))
	if c == player and dv > 5.0:
		_shake(minf(0.5, dv * 0.022))
		sfx.play("bump", linear_to_db(clampf(dv / 20.0, 0.2, 1.0)))
		if dv > 10.0:
			sfx.play("metal", -6.0)
			hitstop = maxf(hitstop, 0.04)
			_flash(Color(1, 1, 1), 0.1)
		if dv > 16.0:
			c.stun = 0.2
	# trânsito atropelado com força pelo jogador vira sucata
	if c.role == "traffic" and oc == player and dv > 14.0 and not c.wrecked:
		c.apply_damage(500.0, point, player, false)


func _on_died(c: Car, killer: Car) -> void:
	var big := c.role != "traffic"
	var from: Vector3 = killer.global_position if killer else c.global_position - c.global_transform.basis.z
	var fell: bool = c.get_meta("fell", false)
	c.set_meta("fell", false)
	c.wreck(28.0, (c.global_position - from).normalized(), not fell)
	if _on_screen(c.global_position):
		fx.explosion(c.global_position, big)
		sfx.play("crash", 0.0 if big else -5.0)
		_shake(0.6 if big else 0.25)
	if killer and killer != c and mode == "race":
		killer.set_meta("kills", int(killer.get_meta("kills", 0)) + 1)
	if online:
		online.on_died(c, killer)
	if c.local_idx >= 0 and (c != player or is_mp()):
		big_for(c, "CAIU!" if fell else "DESTRUÍDO!", Color("#ffe14d"), Color("#ff5a1a"))
		hud.killfeed("%s destruiu %s" % [killer.display_name if killer else "A PISTA", c.display_name], Color("#ff7a7a"))
		shake_for(c, 0.6)
		if c == player:
			stats.deaths += 1
			crash_t = 0.0
		_vibrate(150)
		return
	if c == player:
		stats.deaths += 1
		hud.big("CAIU!" if fell else "DESTRUÍDO!", Color("#ffe14d"), Color("#ff5a1a"))
		hud.killfeed("%s destruiu VOCÊ" % (killer.display_name if killer else "A PISTA"), Color("#ff7a7a"))
		_flash(Color(1, 1, 1), 0.6)
		hitstop = 0.1
		_slowmo(0.3, 1.4)
		crash_t = 0.0
		zoom_kick -= 8.0
		_vibrate(150)
		return
	if c.is_boss and killer and killer.human and mode == "race":
		var bounty := int(600 * career.mult())
		save.cash = int(save.cash) + bounty
		hud.big("CHEFE DESTRUÍDO!", Color.WHITE, Color("#ff2d55"))
		hud.popup("+$%d" % bounty, Color("#7dff6a"), "ele volta em instantes...")
	if killer and killer.local_idx >= 0 and killer != player and mode == "race":
		pop_for(killer, "DESTRUIU %s!" % c.display_name, Color("#ff2d55"))
		hud.killfeed("%s destruiu %s" % [killer.display_name, c.display_name], Color("#7dff6a"))
		return
	if killer == player and mode == "race":
		var ram := player.linear_velocity.length() > 15.0 and c.global_position.distance_to(player.global_position) < 6.0
		stats.kills += 1
		if c.role == "traffic":
			stats.score += 150
			hud.popup("TRÂNSITO!", Color("#ff7a1a"), "+150")
			_add_meter(0.2)
		else:
			if ram:
				stats.takedowns += 1
			hud.big("TAKEDOWN!" if ram else "DESTRUIU!", Color.WHITE, Color("#ff2d55"))
			hud.popup(c.display_name, Color("#ff2d55"), "+$%d" % KILL_BONUS)
			hud.killfeed("%s destruiu %s" % [player.display_name if is_mp() else "VOCÊ", c.display_name], Color("#7dff6a"))
			stats.score += 1000
			sfx.play("fanfare", -6.0)
			_flash(Color(1, 0.9, 0.6), 0.3)
			hitstop = 0.07
			if randf() < 0.6:
				hitstop = maxf(hitstop, 0.05)
			_add_meter(0.5)
			_vibrate(80)
	elif c.role != "traffic" and mode == "race":
		hud.killfeed("%s destruiu %s" % [killer.display_name if killer else "A PISTA", c.display_name], Color(1, 1, 1, 0.85))


## tiro local acertou carro de outra máquina (o dono decide o dano): só efeito visual
func net_report_hit(_c: Car, _amount: float, _point: Vector3, _attacker: Car) -> void:
	pass


func on_player_hit_enemy(_c: Car, _killed: bool) -> void:
	pass


func on_player_got_hit(amount: float) -> void:
	_shake(minf(0.3, amount * 0.02))
	_flash(Color(1, 0.2, 0.15), minf(0.25, amount * 0.012))


func _on_part_off(c: Car, mesh: MeshInstance3D, xform: Transform3D, vel: Vector3, is_wheel: bool) -> void:
	mesh.material_overlay = null
	var rb := fx.spawn_debris(mesh, xform, vel, is_wheel)
	if not _on_screen(xform.origin):
		return
	fx.sparks(xform.origin, vel, 0.6)
	if String(mesh.name).ends_with("cabin"):
		fx.burst("glass", xform.origin + Vector3.UP)
		sfx.play("glass", -3.0)
	else:
		sfx.play("metal", -8.0, randf_range(0.8, 1.3))
	if c == player and rb:
		pass


func _on_landed(c: Car, air: float, impact: float) -> void:
	c.juice_squash(clampf(impact * 0.12, 0.4, 2.2))
	c.juice_pitch(-clampf(impact * 0.03, 0.1, 0.5))
	if not _on_screen(c.global_position):
		return
	fx.burst("dust", c.global_position + c.global_transform.basis.y * 0.2)
	if c != player:
		return
	_shake(minf(0.45, impact * 0.03))
	sfx.play("land", linear_to_db(clampf(impact / 15.0, 0.3, 1.0)))
	hitstop = maxf(hitstop, 0.035)
	if air > 0.6 and mode == "race":
		var pts := int(air * 150)
		hud.popup("PULÃO %.1fs" % air, Color("#7dff6a"), "+%d" % pts)
		stats.score += pts
		stats.air = maxf(stats.air, air)
		_add_meter(0.25)


## manobras enchem o medidor; cheio = uma carga extra de nitro
func _add_meter(a: float) -> void:
	player.nitro_meter += a
	if player.nitro_meter >= 1.0:
		player.nitro_meter -= 1.0
		if player.nitro_ch < player.nitro_cap + 1:
			player.nitro_ch += 1
			hud.popup("+1 NITRO", Color("#2ee6ff"))
			sfx.play("coin", -6.0)


func _shake(a: float) -> void:
	trauma = minf(1.0, trauma + a * float(settings.val("shake")) if settings else a)


## vibração: celular e controles dos jogadores (se estiver ligada nas configurações)
func _vibrate(ms: int) -> void:
	if settings and not bool(settings.val("vibration")):
		return
	Input.vibrate_handheld(ms)
	for lp in locals:
		var dev := String(lp.dev)
		if dev.begins_with("joy"):
			Input.start_joy_vibration(int(dev.substr(3)), 0.4, 0.8, ms / 1000.0)
		elif dev == "solo":
			for j in Input.get_connected_joypads():
				Input.start_joy_vibration(j, 0.4, 0.8, ms / 1000.0)


func _flash(c: Color, a: float) -> void:
	flash = Color(c.r, c.g, c.b, maxf(flash.a, a))


func _slowmo(target: float, dur: float) -> void:
	if is_mp():
		return   # câmera lenta afeta todo mundo: no multijogador fica desligada
	ts_target = target
	slow_t = dur
	ts = minf(ts, target + 0.15)


func _on_screen(p: Vector3) -> bool:
	if Vector2(p.x - cam_pos.x, p.z - cam_pos.z).length() < view_h * 1.4:
		return true
	if multi and multi.split:
		for c in multi.cells:
			var cp: Vector3 = c.rig.cam_pos
			if Vector2(p.x - cp.x, p.z - cp.z).length() < float(c.rig.view_h) * 1.4:
				return true
	return false


# ------------------------------------------------------------------ física e regras
func _physics_process(dt: float) -> void:
	if mode == "paused":
		return
	time_g += dt
	for c in cars:
		c.game_time = time_g
		if c.role != "player" and not c.wrecked and not c.net_remote:
			c.ai(track, self, dt)
	if online:
		online.physics(dt)
	for lp in locals:
		var pc: Car = lp.car
		if pc.wrecked:
			continue
		if mode == "race" and not lp.done:
			if lp.dev == "solo":
				_player_input()
			else:
				_local_input(lp)
		else:
			pc.ctrl.fire = false
			pc.ctrl.drop = false
			pc.ctrl.nitro = false
			pc.ctrl.special = false
			pc.ctrl.drift = false
			pc.ctrl.brake = 0.0
			pc.ctrl.dir = null
			pc.ctrl.steer = 0.0
			pc.ctrl.throttle = 0.0
			if mode == "finish" or (mode == "race" and lp.done):
				# terminou: o carro segue sozinho até o fim da corrida
				pc.cruise = 30.0
				pc.role = "rival"
				pc.ai(track, self, dt)
				pc.role = "player"
				pc.ctrl.nitro = false
				pc.ctrl.special = false
				pc.ctrl.fire = false
				pc.ctrl.drop = false
	if mode in ["race", "finish"]:
		weapons.update(dt)
	for c in cars:
		if c.wrecked or not c.on_ground or time_g < c.pad_t:
			continue
		var pad = track.pad_at(c.s_track, c.lat)
		if pad != null and absf(c.h_track) < 2.0:
			c.pad_t = time_g + 0.8
			var f: Vector3 = c.global_transform.basis.z
			var want: float = float(pad.spd) if float(pad.spd) > 0.0 else c.sp.nitro * 0.95
			var v: float = maxf(c.linear_velocity.length(), want)
			c.linear_velocity = f.slide(c.ground_n).normalized() * v
			pad.hit = 1.0
			c.juice_squash(-1.2)
			c.juice_pitch(0.6)
			if _on_screen(c.global_position):
				var acc: Color = pad.accent
				fx.hit_light(c.global_position + c.ground_n * 0.8, acc, 3.5, 8.0, 0.25)
				for sgn: float in [-1.0, 1.0]:
					fx.sparks(c.global_transform * Vector3(sgn * c.sp.wid * 0.45, 0.15, -c.sp.len * 0.45), -f + c.ground_n * 0.35, 0.9)
				fx.nitro_burst(c.global_transform * c.exhaust_local, f)
			if c.local_idx > 0:
				pop_for(c, "TURBO!", Color("#ff9a1a"))
			if c == player:
				sfx.play("nitro", -2.0)
				pop_for(c, "TURBO!", Color("#ff9a1a"))
				zoom_kick += 5.0
				cam_kick -= f * 2.2
				_shake(0.22)
				_flash((pad.accent as Color).lerp(Color.WHITE, 0.4), 0.16)
				_add_meter(0.15)
	_pickups(dt)
	_feature_stats(dt)
	_rules(dt)
	_respawns(dt)
	_recycle()


## Direção "tela": o jogador aponta para onde quer ir na tela (não inverte quando o carro desce a tela).
## Direção "carro": esquerda/direita giram o carro (estilo clássico).
## medição de fluidez: quantas vezes um carro "engasga" (cai abaixo de 8 m/s) dentro de loop/torção/espiral
func _feature_stats(_dt: float) -> void:
	if mode != "race":
		return
	for c in cars:
		if c.role == "traffic" or c.wrecked or c.freeze:
			continue
		var on_f: bool = track.feat[c.ti] == 1
		var slow: bool = c.linear_velocity.length() < 8.0
		var was: bool = c.get_meta("stall", false)
		if on_f and slow and not was:
			var key := "stalls" if c == player else "ai_stalls"
			stats[key] = int(stats.get(key, 0)) + 1
			var k2 := "st_" + track.ftype[c.ti] + ("_l" if track.loopf[c.ti] == 1 else "")
			stats[k2] = int(stats.get(k2, 0)) + 1
			if (c == player or OS.get_cmdline_user_args().has("--debugstall_ai")) and OS.get_cmdline_user_args().has("--debugstall"):
				print("STALL %s s=%d lat=%.1f h=%.1f v=%.1f onf=%s inloop=%s ft=%s gnd=%s wheels=%d up·U=%.2f inv=%.1f" % [k2, int(c.s_track), c.lat, c.h_surf, c.linear_velocity.length(), c.on_feature, c.in_loop, c.feat_type, c.on_ground, c.wheels.filter(func(w): return w.contact).size(), c.global_transform.basis.y.dot(track.U[c.ti]), c.invuln])
				for ct in c._contacts:
					var ob: Object = ct[0]
					var nm := "?"
					if ob is Node:
						nm = (ob as Node).name + ":" + (ob as Node).get_class()
					print("   contact ", nm, " lp=", ct[1], " n=", ct[2])
				for o in cars:
					if o != c and o.global_position.distance_to(c.global_position) < 6.0:
						print("   near car ", o.role, " d=%.1f" % o.global_position.distance_to(c.global_position))
		c.set_meta("stall", on_f and slow)


## jogador local com teclado próprio ou controle (tela dividida)
func _local_input(lp: Dictionary) -> void:
	var pc: Car = lp.car
	var rr := Vector3(cos(CAM_YAW), 0, -sin(CAM_YAW))
	var ff := Vector3(-sin(CAM_YAW), 0, -cos(CAM_YAW))
	PInput.read(String(lp.dev), pc.ctrl, String(save.get("steer", "tela")) == "tela", rr, ff)
	if auto_test:
		pc.role = "rival"
		pc.cruise = 37.0
		pc.ai(track, self, 1.0 / 60.0)
		pc.role = "player"
		pc.ctrl.fire = weapons._target(pc, 50.0, 0.97) != null


func _player_input() -> void:
	var c := player.ctrl
	var screen_mode := String(save.get("steer", "tela")) == "tela"
	# controles presos ao ângulo base da câmera: a câmera dinâmica (loops/torções) não inverte a direção
	var rr := Vector3(cos(CAM_YAW), 0, -sin(CAM_YAW))
	var ff := Vector3(-sin(CAM_YAW), 0, -cos(CAM_YAW))
	c.dir = null
	c.steer = 0.0
	c.throttle = 0.0
	c.brake = Input.get_action_strength("brake")
	if screen_mode:
		var kx := Input.get_action_strength("right") - Input.get_action_strength("left")
		var ky := Input.get_action_strength("up") - Input.get_action_strength("down")
		var kv := Vector2(kx, ky)
		if kv.length() > 0.1:
			c.dir = (rr * kx + ff * ky).normalized()
			c.dir_mag = minf(1.0, kv.length() * 1.4)
			c.throttle = 1.0
		elif Input.get_action_strength("accel") > 0.3:
			c.throttle = 1.0
	else:
		c.steer = Input.get_action_strength("left") - Input.get_action_strength("right")
		c.throttle = maxf(Input.get_action_strength("up"), Input.get_action_strength("accel"))
		c.brake = maxf(c.brake, Input.get_action_strength("down"))
	if c.brake > 0.0:
		c.throttle = 0.0
	c.drift = Input.is_action_pressed("drift")
	c.nitro = Input.is_action_pressed("nitro")
	c.fire = Input.is_action_pressed("fire")
	c.drop = Input.is_action_pressed("drop")
	c.special = Input.is_action_pressed("special")
	var tp := hud.touch
	if tp.used:
		if not tp.btn.brake and c.brake <= 0.0:
			c.throttle = 1.0
		if tp.btn.brake:
			c.brake = 1.0
			c.throttle = 0.0
		c.drift = c.drift or tp.btn.drift
		c.nitro = c.nitro or tp.btn.nitro
		c.fire = c.fire or tp.btn.fire
		c.drop = c.drop or tp.btn.drop
		c.special = c.special or tp.btn.special
		if screen_mode and tp.stick_vec.length() > 0.22:
			c.dir = (rr * tp.stick_vec.x - ff * tp.stick_vec.y).normalized()
			c.dir_mag = minf(1.0, (tp.stick_vec.length() - 0.22) / 0.5)
		elif not screen_mode and absf(tp.stick_vec.x) > 0.15:
			c.steer = clampf(-tp.stick_vec.x * 1.4, -1.0, 1.0)
	if auto_test and not OS.get_cmdline_user_args().has("--steertest"):
		player.cruise = 21.0 if OS.get_cmdline_user_args().has("--slowplayer") else (46.0 if OS.get_cmdline_user_args().has("--fastplayer") else 38.0)
		player.role = "rival"
		player.ai(track, self, 1.0 / 60.0)
		player.role = "player"
		if OS.get_cmdline_user_args().has("--nosteer_cork"):
			for kb in range(0, int(60.0 / track.ds)):
				if track.ftype[track.idx(player.ti - kb)] == "cork":
					c.steer = 0.0
					c.dir = null
					break
		if test_lane != 0.0:
			var a := track.at(player.s_track + 12.0, test_lane)
			c.dir = ((a.pos as Vector3) - player.global_position).normalized()
		c.nitro = player.nitro_ch > 0 and absf(track.curv[track.idx(player.ti + 10)]) < 0.008 and randf() < 0.02
		if OS.get_cmdline_user_args().has("--nitrotest"):
			player.nitro_ch = 3
			c.nitro = int(real * 2.0) % 2 == 0
		c.fire = weapons._target(player, 50.0, 0.97) != null
		c.drop = randf() < 0.01
		c.special = randf() < 0.01


func _pickups(dt: float) -> void:
	for pk in pickups:
		var nd: Node3D = pk.node
		if pk.t > 0.0:
			pk.t -= dt
			nd.visible = pk.t <= 0.0
			continue
		nd.rotate(pk.up, dt * 2.0)
		nd.position = (pk.base as Vector3) + (pk.up as Vector3) * sin(time_g * 3.0) * 0.25
		for c in cars:
			if c.role == "traffic" or c.wrecked:
				continue
			if c.global_position.distance_to(nd.global_position) < 2.8:
				pk.t = 10.0
				nd.visible = false
				match String(pk.kind):
					"ammo":
						c.ammo_f = mini(c.front_cap, c.ammo_f + maxi(1, c.front_cap / 2))
						c.ammo_r = mini(c.rear_cap, c.ammo_r + 1)
					"repair":
						c.health = minf(c.max_health, c.health + c.max_health * 0.4)
					"nitro":
						c.nitro_ch = mini(c.nitro_cap + 1, c.nitro_ch + 1)
				if c.local_idx >= 0:
					sfx.play("pickup")
					var names := {"ammo": "MUNIÇÃO!", "repair": "REPARO!", "nitro": "NITRO!"}
					pop_for(c, names[pk.kind], Color("#7dff6a"))
					fx.sparkle(nd.global_position, {"ammo": Color(0.7, 1.4, 0.5), "repair": Color(1.4, 0.6, 0.5), "nitro": Color(0.5, 1.0, 1.6)}[pk.kind])
				break


func _rules(dt: float) -> void:
	var L := track.length
	for c in cars:
		var pr := track.project(c.global_position, c.ti)
		c.ti = pr.i
		c.lat = pr.lat
		c.s_track = pr.s
		c.h_track = pr.h
		c.in_loop = track.loopf[pr.i] == 1
		c.feat_type = track.ftype[pr.i]
		c.on_feature = track.feat[pr.i] == 1 and track.gap[pr.i] == 0 and track.ftype[pr.i] != "jump"
		if c.on_feature:
			var fr := track.frame(c.global_position, pr.i)
			c.track_up = fr.u
			c.track_left = fr.l
			c.track_tan = fr.t
			c.h_surf = fr.h
			c.lat = fr.lat
		else:
			c.track_up = track.U[pr.i]
			c.track_left = track.L[pr.i]
			c.track_tan = track.T[pr.i]
			c.h_surf = pr.h
		c.road_half = track.HALF
		c.track_ref = track
		if c.role == "traffic":
			continue
		var d: float = pr.s - c.prev_s
		if d > L * 0.5:
			d -= L
		elif d < -L * 0.5:
			d += L
		c.dist += d
		c.prev_s = pr.s
		var lap := int(floor(c.dist / L))
		if c.net_remote:
			lap = c.lap   # volta de carro de outra máquina vem pela rede
		if lap >= LAPS and not c.get_meta("done", false) and mode == "race" and not c.net_remote:
			c.set_meta("done", true)
			c.set_meta("fin_t", race_t)
			if not c.human:
				finished_n += 1
			if not is_mp() and c != player and finished_n == rivals.size() and player.lap < LAPS:
				hud.popup("TODOS OS RIVAIS TERMINARAM", Color("#ff7a7a"))
				_finish()
			elif is_mp():
				_mp_finished(c)
		if lap > c.lap:
			if OS.get_cmdline_user_args().has("--debuglap"):
				var d0: float = (c.global_position - track.P[0]).dot(track.T[0])
				var lat0: float = (c.global_position - track.P[0]).dot(track.L[0])
				print("LAP %s lap=%d along_line=%.2f lat=%.1f s=%.1f ti=%d v=%.1f" % [c.display_name, lap, d0, lat0, pr.s, pr.i, c.linear_velocity.length()])
			c.lap = lap
			if not c.net_remote:
				c.refill()
			if c == player and mode == "race":
				var lt := race_t - lap_start
				lap_start = race_t
				best_lap = minf(best_lap, lt)
			if c.local_idx >= 0 and mode == "race":
				if lap >= LAPS:
					if not is_mp():
						_finish()
				else:
					big_for(c, "ÚLTIMA VOLTA!" if lap == LAPS - 1 else "VOLTA %d" % (lap + 1), Color("#ffcf33"), Color("#c74200"))
					pop_for(c, "MUNIÇÃO E NITRO RECARREGADOS", Color("#2ee6ff"))
					sfx.play("fanfare", -6.0)
					fx.burst("confetti", c.global_position + Vector3.UP)
	if mode != "race":
		return
	race_t += dt
	var order := standings()
	place = order.find(player) + 1
	if race_end_t >= 0.0:
		race_end_t -= dt
		if race_end_t <= 0.0:
			_finish()
			return
	# borracha da IA: mira no humano mais à frente (no solo, o jogador)
	var lead := player.dist
	if is_mp():
		for h in humans:
			lead = maxf(lead, h.dist)
	for r in rivals:
		if r.is_boss:
			# duelo: o chefe segura quando abre vantagem (fica ao alcance dos ataques) e só "solta tudo" na última volta
			var last: bool = r.lap >= LAPS - 1
			r.rubber = clampf(1.0 + (lead - r.dist) * 0.006, 0.9 if last else 0.74, 1.06)
		else:
			r.rubber = clampf(1.0 + (lead - r.dist) * 0.0028, 0.86, 1.1)
	if player.wrecked:
		return
	var p := player
	var v := p.linear_velocity
	# sentido errado: avisa e, se continuar, coloca o carro de volta na direção certa
	var along_t: float = p.global_transform.basis.z.dot(track.T[p.ti])
	if along_t < -0.35 and v.length() > 2.0 and not p.in_loop:
		wrong_t += dt
	else:
		wrong_t = maxf(0.0, wrong_t - dt * 2.0)
	hud.wrong_l.visible = wrong_t > 0.8
	if hud.wrong_l.visible:
		hud.wrong_l.modulate.a = 1.0 if int(real * 5.0) % 2 == 0 else 0.4
	if wrong_t > 3.5:
		wrong_t = 0.0
		hud.wrong_l.visible = false
		_respawn(p, false)
		hud.popup("DE VOLTA AO SENTIDO CERTO", Color("#2ee6ff"))
	if p.drifting and p.v_f > 12.0:
		p.nitro_meter += dt * 0.08 * minf(1.0, p.drift_slip * 2.0)
	if was_drift and not p.drifting and p.drift_t > 0.8:
		var pts := int(p.drift_t * 120)
		hud.popup("DRIFT %.1fs" % p.drift_t, Color("#c77dff"), "+%d" % pts)
		stats.score += pts
		stats.best_drift = maxf(stats.best_drift, p.drift_t)
		_add_meter(minf(0.3, p.drift_t * 0.08))
	was_drift = p.drifting
	if p.nitro_meter >= 1.0:
		_add_meter(0.0)
	if track.data.traffic > 0:
		var tg := track.T[p.ti]
		var along := v.dot(tg)
		if p.lat > 0.8 and along > 14.0 and p.on_ground:
			p.nitro_meter += dt * 0.08
			onc_dist += along * dt
			stats.oncoming += along * dt
			hud.onc_l.modulate.a = 1.0 if int(real * 6.0) % 2 == 0 else 0.6
		else:
			if onc_dist > 40.0:
				hud.popup("CONTRAMÃO %dm" % int(onc_dist), Color("#ff2d55"), "+%d" % int(onc_dist))
				stats.score += int(onc_dist)
			onc_dist = 0.0
			hud.onc_l.modulate.a = 0.0
		for c in traffic:
			if c.wrecked:
				c.nm_state = null
				continue
			var dd: float = c.global_position.distance_to(p.global_position)
			var rel: float = (c.linear_velocity - v).length()
			if dd < 4.6 and rel > 12.0 and c.nm_state == null:
				c.nm_state = {"touched": false}
			if c.nm_state != null:
				if c.last_hit_by == p and time_g - c.last_hit_t < 0.5:
					c.nm_state.touched = true
				if dd > 7.5:
					if not c.nm_state.touched:
						_near_miss(c)
					c.nm_state = null


func _near_miss(c: Car) -> void:
	stats.near += 1
	nm_combo = nm_combo + 1 if real - last_nm < 2.5 else 1
	last_nm = real
	var pts := 50 * nm_combo
	stats.score += pts
	_add_meter(0.18)
	hud.popup("POR UM TRIZ!" if c.oncoming else "QUASE!", Color("#2ee6ff"), ("x%d +%d" % [nm_combo, pts]) if nm_combo > 1 else "+%d" % pts)
	sfx.play("whoosh", -3.0)
	zoom_kick += 1.5


## caiu da pista, ficou de cabeça para baixo ou foi destruído: volta para a pista
func _respawns(dt: float) -> void:
	if steer_testing:
		return
	for c in cars:
		if c.role == "traffic" or c.net_remote:
			continue
		if c.wrecked:
			if c.local_idx < 0 and c.wreck_t > 3.0:
				_respawn(c, false)
			continue
		if c.freeze:
			continue
		var below: bool = c.h_track < -4.0
		var away: bool = absf(c.lat) > track.WALL + 3.0
		# caiu para fora da pista: explode ao bater no chão/água (ou depois de cair um tempo, no céu)
		var falling: bool = below or (away and c.h_track < -1.5 and c.linear_velocity.y < -2.0)
		var water_now: bool = c.global_position.y < float(theme.gy) + 0.6 and track.P[c.ti].y > float(theme.gy) + 2.5
		if falling or water_now:
			c.fall_t = float(c.get("fall_t")) + dt
			var hit_ground: bool = c.global_position.y < float(theme.gy) + 1.4
			if water_now or hit_ground or c.fall_t > 1.3:
				c.fall_t = 0.0
				_fall_wreck(c, water_now)
				continue
		else:
			c.fall_t = 0.0
		var upside: bool = c.global_transform.basis.y.dot(track.U[c.ti]) < -0.2 and c.linear_velocity.length() < 5.0
		var in_water: bool = c.global_position.y < float(theme.gy) + 0.6 and track.P[c.ti].y > float(theme.gy) + 2.5
		if below or away or upside or in_water:
			c.off_t += dt
		else:
			c.off_t = 0.0
		# preso (encostado na mureta, de lado, travado): volta para a pista
		if mode == "race" and c.linear_velocity.length() < 2.5:
			c.stuck_t += dt
		else:
			c.stuck_t = 0.0
		if c.stuck_t > 3.0:
			c.stuck_t = 0.0
			pop_for(c, "VOLTANDO À PISTA", Color("#2ee6ff"))
			_respawn(c, false)
			continue
		if c.off_t > (0.15 if in_water else (0.6 if (below or away) else 1.5)):
			if auto_test and OS.get_cmdline_user_args().has("--debugfall"):
				print("FALL %s s=%d lat=%.1f h=%.1f v=%.1f below=%s away=%s up=%s water=%s feat=%d gap=%d loop=%d" % [c.display_name, int(c.s_track), c.lat, c.h_track, c.linear_velocity.length(), below, away, upside, in_water, track.feat[c.ti], track.gap[c.ti], track.loopf[c.ti]])
			if in_water and _on_screen(c.global_position):
				if theme.ground == 4:
					fx.explosion(c.global_position, false, "smoke")
				else:
					fx.burst("smoke", c.global_position)
					sfx.play("splash", -3.0)
			_respawn(c, true)
	if crash_t >= 0.0:
		crash_t += dt / maxf(Engine.time_scale, 0.05)
		if crash_t > 2.2:
			crash_t = -1.0
			_respawn(player, false)
	# outros jogadores locais: voltam 2,2 s depois de destruídos
	for lp in locals:
		var pc: Car = lp.car
		if pc != player and pc.wrecked and pc.wreck_t > 2.2:
			_respawn(pc, false)


## faróis acesos à noite: uma luz spot (ilumina a pista) + dois fachos aditivos
func _add_headlights(c: Car) -> Array:
	var out := []
	var y: float = c.sp.clr + c.sp.h * 0.6
	var z: float = c.sp.len * 0.5 + 0.15
	var sp := SpotLight3D.new()
	sp.light_color = Color(1.0, 0.92, 0.78)
	# luz suave: menos energia, cone mais aberto com borda esfumada e queda maior com a distância
	var dusk_only: bool = not bool(theme.night)
	sp.light_energy = (2.6 if c.role == "player" else 1.7) * (0.45 if dusk_only else 1.0)
	sp.spot_range = 24.0
	sp.spot_angle = 46.0
	sp.spot_angle_attenuation = 2.4
	sp.spot_attenuation = 1.4
	sp.shadow_enabled = false
	sp.light_specular = 0.18
	sp.transform = Transform3D(Basis.looking_at(Vector3(0, -0.2, 1.0), Vector3.UP), Vector3(0, y + 0.2, z))
	c.add_child(sp)
	out.append(sp)
	var bsh := load("res://shaders/beam.gdshader") as Shader
	for sx: float in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.18
		cm.bottom_radius = 2.4
		cm.height = 11.0
		cm.radial_segments = 14
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		mi.mesh = cm
		var m := ShaderMaterial.new()
		m.shader = bsh
		m.set_shader_parameter("strength", (0.085 if c.role == "player" else 0.055) * (0.35 if dusk_only else 1.0))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# cilindro "deitado": eixo apontando para a frente e um pouco para baixo
		var dirv := Vector3(0, -0.12, 1.0).normalized()
		# eixo Y do cilindro aponta para trás (topo estreito no farol, base larga lá na frente)
		var yb := -dirv
		var zb := Vector3.RIGHT.cross(yb).normalized()
		var xb := yb.cross(zb).normalized()
		mi.transform = Transform3D(Basis(xb, yb, zb), Vector3(sx * c.sp.wid * 0.32, y, z) + dirv * 5.5)
		c.add_child(mi)
		out.append(mi)
	return out


## lens flare: fontes de luz rápidas (explosões, turbo, nitro) registradas pelos efeitos
var flares_t: Array = []


func add_flare(pos: Vector3, col: Color, k: float, dur: float) -> void:
	flares_t.append({"pos": pos, "col": col, "k": k, "t": 0.0, "dur": dur})
	if flares_t.size() > 16:
		flares_t.pop_front()


func _update_flares(rdt: float) -> void:
	var m := hud.post_mat
	var vs := get_viewport().get_visible_rect().size
	var cand: Array = []
	var cam_f := -cam.global_basis.z
	var night := bool(theme.night) or bool(theme.get("dusk", false))
	for c in cars:
		if c.wrecked or not _on_screen(c.global_position):
			continue
		var cxf: Transform3D = c.get_global_transform_interpolated()
		var f: Vector3 = cxf.basis.z
		if night:
			# faróis virados para a câmera brilham na lente
			var facing := clampf(-f.dot(cam_f) * 1.6 + 0.25, 0.0, 1.0)
			# no entardecer (céu ainda claro) o farol quase não "estoura" a lente; o do jogador é mais
			# contido para nunca esconder o próprio carro no brilho
			var dk: float = 1.0 if bool(theme.night) else 0.22
			if facing > 0.05:
				for sx: float in [-1.0, 1.0]:
					var hp: Vector3 = cxf * Vector3(sx * c.sp.wid * 0.32, c.sp.clr + c.sp.h * 0.6, c.sp.len * 0.5 + 0.1)
					cand.append([hp, Color(1.0, 0.9, 0.75), facing * (0.38 if c == player else 0.55) * dk, 0.7 if c == player else 0.85])
		if c.nitroing:
			cand.append([cxf * c.exhaust_local, Color(0.45, 0.75, 1.0), 0.7, 1.2])
	for i in range(flares_t.size() - 1, -1, -1):
		var ft: Dictionary = flares_t[i]
		ft.t += rdt
		if ft.t > ft.dur:
			flares_t.remove_at(i)
			continue
		cand.append([ft.pos, ft.col, float(ft.k) * (1.0 - float(ft.t) / float(ft.dur)), 1.6])
	cand.sort_custom(func(a, b): return a[2] > b[2])
	var pos_a: Array = []
	var col_a: Array = []
	for cd in cand:
		if pos_a.size() >= 8:
			break
		var wp: Vector3 = cd[0]
		if cam.is_position_behind(wp):
			continue
		var sp: Vector2 = cam.unproject_position(wp) / vs
		if sp.x < -0.1 or sp.x > 1.1 or sp.y < -0.1 or sp.y > 1.1:
			continue
		pos_a.append(Vector4(sp.x, sp.y, float(cd[2]), float(cd[3])))
		col_a.append(Vector4((cd[1] as Color).r, (cd[1] as Color).g, (cd[1] as Color).b, 1.0))
	while pos_a.size() < 12:
		pos_a.append(Vector4.ZERO)
		col_a.append(Vector4.ZERO)
	var nfl := 0
	for p4 in pos_a:
		if (p4 as Vector4).z > 0.0:
			nfl += 1
	m.set_shader_parameter("fl_pos", pos_a)
	m.set_shader_parameter("fl_col", col_a)
	m.set_shader_parameter("fl_n", nfl)
	# sol (dia): brilho entrando pela borda do lado do sol
	if not night and mode != "menu":
		var sd: Vector3 = sun.global_basis.z
		var cf := Vector2(cam_f.x, cam_f.z).normalized()
		var sh := Vector2(sd.x, sd.z).normalized()
		var toward := cf.dot(sh)   # sol na frente da câmera = mais brilho
		var r := cam.global_basis.x
		var sx: float = Vector2(r.x, r.z).normalized().dot(sh)
		var su := Vector2(0.5 + sx * 0.62, -0.08 - maxf(0.0, toward) * 0.05)
		m.set_shader_parameter("sun_uv", su)
		m.set_shader_parameter("sun_k", clampf(0.35 + toward * 0.65, 0.0, 1.0) * 0.9)
		m.set_shader_parameter("sun_col", Color(theme.sun))
	else:
		m.set_shader_parameter("sun_k", 0.0)


## silhueta "raio-X": o carro aparece mesmo embaixo de outro trecho de pista
func _add_xray(c: Car) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/xray.gdshader")
	var me: bool = c.role == "player"
	var col: Color = c.color if not me else Color("#ffd23a")
	m.set_shader_parameter("col", col.lightened(0.25))
	m.set_shader_parameter("strength", 1.0 if me else 0.6)
	var stack: Array = [c.model]
	while stack.size() > 0:
		var nd: Node = stack.pop_back()
		if nd is MeshInstance3D:
			(nd as MeshInstance3D).material_overlay = m
		for ch in nd.get_children():
			stack.append(ch)


func _fall_wreck(c: Car, water: bool) -> void:
	if auto_test and OS.get_cmdline_user_args().has("--debugfall"):
		print("FALL %s s=%d lat=%.1f h=%.1f v=%.1f water=%s feat=%d gap=%d loop=%d" % [c.display_name, int(c.s_track), c.lat, c.h_track, c.linear_velocity.length(), water, track.feat[c.ti], track.gap[c.ti], track.loopf[c.ti]])
	if c == player:
		stats.falls += 1
	elif mode == "race":
		stats["ai_falls"] = int(stats.get("ai_falls", 0)) + 1
	var pos := c.global_position
	if _on_screen(pos):
		if water and int(theme.ground) == 4:
			fx.explosion(pos, true, "fireball")
		elif water:
			fx.burst("smoke", pos)
			fx.burst("smoke", pos + Vector3.UP)
			sfx.play("splash", 0.0)
		else:
			fx.scorch(pos, 3.0)
	# quem derrubou leva o crédito (batida/tiro recente)
	var killer: Car = c.last_hit_by if c.last_hit_by and c.game_time - c.last_hit_t < 4.0 else null
	c.set_meta("fell", true)
	c.invuln = 0.0
	c.apply_damage(c.health + 9999.0, pos, killer, false)


func _respawn(c: Car, fell: bool) -> void:
	var s := track.safe_s(c.s_track - 6.0)
	# a distância corrida acompanha o recuo (6 m ou mais, até um trecho seguro): sem isso a volta
	# era contada 7–90 m antes da linha de chegada
	var old_dist := c.dist - wrapf(c.s_track - s, -track.length * 0.5, track.length * 0.5)
	if c.wrecked:
		c.repair()
	var lat: float = [0.0, -track.W * 0.25, track.W * 0.25][randi() % 3] if track.data.traffic == 0 else track.lanes_fwd[0]
	_place(c, s, lat, 18.0)
	c.dist = old_dist
	c.prev_s = track.project(c.global_position).s
	c.invuln = 2.0
	if online:
		online.on_respawn(c)
	if c.local_idx >= 0:
		if c == player:
			zoom_kick += 4.0
		fx.sparkle(c.global_position + Vector3.UP, Color(1.2, 1.2, 1.3))
		if fell:
			if c == player:
				stats.falls += 1
			pop_for(c, "CAIU! VOLTANDO", Color("#ffcf33"))
	elif fell:
		stats.ai_falls = int(stats.get("ai_falls", 0)) + 1


func _recycle() -> void:
	var p := player
	var L := track.length
	for c in traffic:
		var rel: float = wrapf(c.s_track - p.s_track, -L * 0.5, L * 0.5)
		var far := rel < -70.0 or rel > 260.0
		var vis := _on_screen(c.global_position)
		if ((c.wrecked and c.wreck_t > 4.0) or far or c.h_track < -4.0) and not vis:
			for tries in 6:
				var s: float = track.safe_s(p.s_track + randf_range(110, 250))
				var lanes: Array = track.lanes_onc if c.oncoming else track.lanes_fwd
				var lat: float = lanes[randi() % 2]
				var pos: Vector3 = track.at(s, lat).pos
				var ok := true
				for o in cars:
					if o != c and o.global_position.distance_to(pos) < 8.0:
						ok = false
						break
				if ok:
					c.repair()
					_place(c, s, lat, c.cruise)
					break
			c.nm_state = null


## ordem da corrida: quem terminou (pelo tempo) e depois quem ainda corre (pela distância)
func standings() -> Array:
	var order := racers()
	order.sort_custom(func(a, b):
		var da: bool = a.get_meta("done", false)
		var db: bool = b.get_meta("done", false)
		if da != db:
			return da
		if da and db:
			return float(a.get_meta("fin_t", 0.0)) < float(b.get_meta("fin_t", 0.0))
		return a.dist > b.dist)
	return order


## multijogador: alguém completou as voltas
func _mp_finished(c: Car) -> void:
	if online.racing:
		online.send_fin(c)
	var order := standings()
	var pl := order.find(c) + 1
	if c.human:
		hud.killfeed("%s terminou em %dº" % [c.display_name, pl], Color("#ffcf33"))
	var lp := local_of(c)
	if not lp.is_empty():
		lp.done = true
		big_for(c, "VITÓRIA!" if pl == 1 else "%dº LUGAR" % pl, Color("#ffcf33"), Color("#c74200"))
		fx.burst("confetti", c.global_position + Vector3.UP)
		sfx.play("fanfare")
		if c == player:
			place = pl
	# todos os humanos terminaram: fim. Senão, quem falta tem 30 s (avisa na tela)
	var all_done := true
	for h in humans:
		if not h.get_meta("done", false):
			all_done = false
	if all_done:
		_finish()
	elif c.human and race_end_t < 0.0:
		race_end_t = 30.0
		hud.popup("30 s PARA TERMINAR!", Color("#ff7a7a"))


func _finish() -> void:
	if mode == "finish":
		return
	mode = "finish"
	race_end_t = -1.0
	if is_mp():
		place = standings().find(player) + 1
	if online:
		online.on_finish()
	var prize: int = int(((PRIZE[place - 1] if place <= PRIZE.size() else 60) + int(stats.kills) * KILL_BONUS) * career.mult())
	career_lines = []
	if career.active():
		var beat: bool = boss != null and (player.get_meta("done", false) or player.lap >= LAPS) and not boss.get_meta("done", false)
		if boss != null and boss.get_meta("done", false) and player.get_meta("done", false):
			beat = float(player.get_meta("fin_t", 1e9)) < float(boss.get_meta("fin_t", 0.0))
		career_lines = career.apply_result(place, beat)
	stats.prize = prize
	save.cash = int(save.cash) + prize
	var key := str(track_idx)
	var best: Dictionary = save.best.get(key, {})
	if not best.has("place") or place < int(best.place) or (place == int(best.place) and race_t < float(best.time)):
		save.best[key] = {"place": place, "time": race_t}
	_write_save()
	hud.big("VITÓRIA!" if place == 1 else "%dº LUGAR" % place, Color("#ffcf33"), Color("#c74200"))
	sfx.play("fanfare")
	fx.burst("confetti", player.global_position + Vector3.UP)
	_slowmo(0.35, 1.2)
	get_tree().create_timer(2.0, true, false, true).timeout.connect(_show_results)
	if auto_test:
		var ord: Array = []
		for oc in standings():
			ord.append("%s%s" % [oc.display_name, "@%.1f" % float(oc.get_meta("fin_t", 0.0)) if oc.get_meta("done", false) else ""])
		print("RESULT ", JSON.stringify({"track": track_idx, "place": place, "time": snappedf(race_t, 0.1), "order": ord, "stats": stats, "uses": weapons.uses}))


func _show_results() -> void:
	if mode != "finish":
		return
	hud.res_title.text = "VITÓRIA!" if place == 1 else "%dº LUGAR" % place
	if is_mp():
		var order := standings()
		var rows: Array = []
		for i in order.size():
			var c: Car = order[i]
			var tm: String = _fmt(float(c.get_meta("fin_t", 0.0))) if c.get_meta("done", false) else "não terminou"
			rows.append("%dº  %s%s   %s   ·   %d destruídos" % [i + 1, c.display_name, "  (você)" if c.local_idx >= 0 and locals.size() == 1 else "", tm, int(c.get_meta("kills", 0))])
		if locals.size() > 1:
			hud.res_title.text = "%s VENCEU!" % (order[0] as Car).display_name
		hud.res_list.text = "\n".join(rows)
		hud.res_cash.text = "+$%d   (total $%d)" % [int(stats.prize), int(save.cash)]
		hud.show_screen("results")
		if auto_test:
			get_tree().quit()
		return
	var lines := [
		"Tempo total   %s" % _fmt(race_t), "Melhor volta   %s" % _fmt(best_lap),
		"Destruídos   %d  (takedowns %d)" % [stats.kills, stats.takedowns], "Quedas   %d   ·   Destruições sofridas   %d" % [stats.falls, stats.deaths],
		"Maior drift   %.1fs   ·   Maior pulo   %.1fs" % [stats.best_drift, stats.air], "Pontos   %d" % stats.score]
	hud.res_list.text = "\n".join(lines)
	hud.res_cash.text = "+$%d   (total $%d)" % [int(stats.prize), int(save.cash)]
	if career_lines.size() > 0:
		hud.res_list.text += "\n\n" + "\n".join(career_lines)
		if auto_test:
			print("CAREER ", career_lines, " unlocked=", save.career.unlocked)
	hud.show_screen("results")
	if auto_test:
		get_tree().quit()


func _fmt(t: float) -> String:
	if t == INF:
		return "--:--.--"
	var m := int(t / 60.0)
	return "%d:%05.2f" % [m, t - m * 60.0]


# ------------------------------------------------------------------ quadro
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var rdt := minf(0.05, (now - _last_us) / 1e6)
	_last_us = now
	if auto_test:
		rdt = 1.0 / 60.0
	real += rdt
	if Input.is_action_just_pressed("pause"):
		pause(mode != "paused")
	if mode == "race" and locals.size() > 1:
		for lp in locals:
			var pc: Car = lp.car
			if PInput.reset_pressed(String(lp.dev)) and not pc.wrecked and not pc.freeze and float(pc.get_meta("rs_t", -9.0)) < real - 2.0:
				pc.set_meta("rs_t", real)
				_respawn(pc, false)
	if Input.is_action_just_pressed("mute"):
		toggle_mute()
	if Input.is_action_just_pressed("reset") and mode == "race" and not player.wrecked:
		_respawn(player, false)
	if mode == "paused":
		Engine.time_scale = 0.0
		return
	if slow_t > 0.0:
		slow_t -= rdt
		if slow_t <= 0.0:
			ts_target = 1.0
	ts = lerpf(ts, ts_target, minf(1.0, rdt * (12.0 if ts_target < ts else 3.0)))
	var eff := ts
	if is_mp():
		hitstop = 0.0
		eff = 1.0
	if hitstop > 0.0:
		hitstop -= rdt
		eff = 0.03
	Engine.time_scale = eff
	if focus_t > 0.0:
		focus_t -= rdt
		if focus_t <= 0.0:
			cam_focus = null
	if mode == "countdown":
		countdown -= rdt
		var n := int(ceil(countdown))
		if n < last_beep and n > 0 and n <= 3:
			last_beep = n
			hud.big(str(n), Color.WHITE, Color("#2e7dff"))
			sfx.play("beep")
			_shake(0.1)
		if countdown <= 0.0:
			mode = "race"
			hud.big("VAI!", Color("#7dff6a"), Color("#1f8a2a"))
			sfx.play("go")
			_shake(0.3)
			zoom_kick += 4.0
			for c in racers():
				if c.net_remote:
					continue
				c.freeze = false
				c.launch_t = 0.85   # pneus cantando na largada
			if Input.is_action_pressed("up") or hud.touch.used or auto_test:
				player.linear_velocity = player.global_transform.basis.z * 14.0
				hud.popup("LARGADA PERFEITA!", Color("#ff9a1a"))
	_car_fx(rdt * eff)
	if player.nitroing and not was_nitro:
		sfx.play("nitro")
		zoom_kick += 4.5
		cam_kick -= player.global_transform.basis.z * 2.6   # a câmera "fica para trás" e alcança o carro
		_shake(0.18)
		var ex: Vector3 = player.global_transform * player.exhaust_local
		fx.nitro_burst(ex, player.global_transform.basis.z)
		fx.hit_light(ex - player.global_transform.basis.z * 0.8, Color(1.0, 0.55, 0.2), 7.0, 8.0, 0.18)
		fx.burst("backfire", ex - player.global_transform.basis.z * 0.3, -player.global_transform.basis.z)
		_flash(Color(0.6, 0.9, 1.0), 0.12)
	if player.nitroing and not player.wrecked:
		trauma = maxf(trauma, 0.16)   # ronco: leve tremor contínuo durante o nitro
	was_nitro = player.nitroing
	var sp01: float = player.linear_velocity.length() / player.sp.vmax
	var slip: float = 1.0 if (player.drifting or player.launch_t > 0.15) else clampf((absf(player.v_s) - 3.0) / 8.0, 0.0, 1.0)
	if player.ctrl.brake > 0.0 and player.v_f > 10.0:
		slip += 0.5
	sfx.drive(clampf(sp01, 0.0, 1.3), player.ctrl.throttle, slip, player.nitroing, ts < 0.6, mode in ["race", "countdown", "finish"] and not player.wrecked)
	_camera(rdt)
	if multi and multi.split:
		multi.update(rdt)
	else:
		_post(rdt)
		_update_flares(rdt)
	_hud()
	if online:
		online.frame(rdt)
	# onda de luz das placas de turbo depois que alguém passa
	for pd in track.pads:
		if float(pd.get("hit", 0.0)) > 0.0 and pd.has("mat"):
			pd.hit = maxf(0.0, float(pd.hit) - rdt * 2.2)
			(pd.mat as ShaderMaterial).set_shader_parameter("hit", pd.hit)
	if auto_test and OS.get_cmdline_user_args().has("--camshots") and cam_mode != "":
		var key := "cam_" + cam_mode
		var fr := int(stats.get(key, 0)) + 1
		stats[key] = fr
		if fr % 40 == 0 and fr <= 160:
			get_viewport().get_texture().get_image().save_png("user://cam_t%d_%s_%d.png" % [track_idx, cam_mode, fr / 40])
			print("CAMSHOT ", cam_mode, " ", fr / 40)
	elif auto_test:
		stats.erase("cam_loop"); stats.erase("cam_twist"); stats.erase("cam_helix"); stats.erase("cam_air")
	if auto_test and test_shots.size() > 0 and real > float(test_shots[0]):
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://shot_t%d_%s.png" % [track_idx, test_shots[0]])
		print("SHOT ", track_idx)
		test_shots.pop_front()
	if auto_test and OS.get_cmdline_user_args().has("--debugair") and player.air_t > 2.0 and int(real * 60.0) % 30 == 0:
		var p2 := player
		print("AIR t=%.1f air=%.1f s=%d lat=%.1f h=%.1f v=%.1f gnd=%s feat=%d ft=%s gap=%d y=%.1f grounded_wheels=%d" % [real, p2.air_t, int(p2.s_track), p2.lat, p2.h_track, p2.linear_velocity.length(), p2.on_ground, track.feat[p2.ti], track.ftype[p2.ti], track.gap[p2.ti], p2.global_position.y, p2.wheels.filter(func(w): return w.contact).size()])
	if auto_test and OS.get_cmdline_user_args().has("--debugfall") and int(real * 60.0) % (20 if (player.s_track > 400 and player.s_track < 560) else 600) == 0:
		var p := player
		print("P t=%d s=%d lat=%.1f h=%.1f v=%.1f vf=%.1f gnd=%s road=%s up=%s n=%s feat=%d loop=%d thr=%.1f br=%.1f" % [int(real), int(p.s_track), p.lat, p.h_track, p.linear_velocity.length(), p.v_f, p.on_ground, p.on_road, str(p.global_transform.basis.y.snapped(Vector3.ONE * 0.01)), str(p.ground_n.snapped(Vector3.ONE * 0.01)), track.feat[p.ti], track.loopf[p.ti], p.ctrl.throttle, p.ctrl.brake])
	if auto_test and OS.get_cmdline_user_args().has("--debugcam") and int(real * 60.0) % 6 == 0:
		var pq := player.get_global_transform_interpolated().origin
		var lb2 := -1
		for kb in range(0, int(60.0 / track.ds)):
			if track.loopf[track.idx(player.ti - kb)] == 1:
				lb2 = kb
				break
		if lb2 >= 0:
			print("CAM t=%.2f after=%dm mode=%s u=%.2f off=%.1f" % [real, int(lb2 * track.ds), cam_mode, cam_loop_u, Vector2(cam_pos.x - pq.x, cam_pos.z - pq.z).length()])
	if auto_test and OS.get_cmdline_user_args().has("--debugcork"):
		var pc := player
		var near := false
		for kb in range(0, int(50.0 / track.ds)):
			var jb := track.idx(pc.ti - kb)
			if track.ftype[jb] == "cork" and track.feat[jb] == 1:
				near = true
				break
		if near and int(real * 60.0) % 3 == 0:
			var vl := pc.linear_velocity
			print("CK t=%.2f s=%d ti=%d feat=%d ft=%s cork=%d guided=%s lat=%.2f h=%.2f vT=%.1f vL=%.2f vU=%.2f wT=%.2f wU=%.2f wL=%.2f gnd=%s wheels=%d upU=%.2f" % [real, int(pc.s_track), pc.ti, track.feat[pc.ti], track.ftype[pc.ti], track.corkf[pc.ti], pc.guided_now, pc.lat, pc.h_surf, vl.dot(track.T[pc.ti]), vl.dot(track.L[pc.ti]), vl.dot(track.U[pc.ti]), pc.angular_velocity.dot(track.T[pc.ti]), pc.angular_velocity.dot(track.U[pc.ti]), pc.angular_velocity.dot(track.L[pc.ti]), pc.on_ground, pc.wheels.filter(func(w): return w.contact).size(), pc.global_transform.basis.y.dot(track.U[pc.ti])])
	if auto_test and real > 240.0:
		print("TIMEOUT ", JSON.stringify({"track": track_idx, "lap": player.lap, "dist": player.dist, "stats": stats}))
		get_tree().quit()


func _scrapes() -> void:
	var list: Array = []
	for c in cars:
		if c.scraping and _on_screen(c.scrape_pt):
			list.append(c)
	list.sort_custom(func(a, b): return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	var player_scr := 0.0
	for i in scrape_pool.size():
		var n: Node3D = scrape_pool[i]
		if i < list.size():
			var c: Car = list[i]
			var v: Vector3 = c.scrape_v
			var spd := v.length()
			var dir := (-v.normalized() * 0.85 + c.scrape_n * 0.35 + Vector3.UP * 0.3).normalized()
			fx.set_scrape(n, true, c.scrape_pt + Vector3.UP * 0.25, dir, clampf(spd / 30.0, 0.2, 1.3))
			if c == player:
				player_scr = clampf(spd / 25.0, 0.3, 1.0)
		else:
			fx.set_scrape(n, false, Vector3.ZERO, Vector3.UP, 0.0)
	sfx.set_scrape(player_scr if mode in ["race", "finish"] else 0.0)
	if player_scr > 0.0:
		_shake(0.012 * player_scr)


func _car_fx(dt: float) -> void:
	_scrapes()
	for c in cars:
		var e: Dictionary = em[c]
		var cx: Transform3D = c.get_global_transform_interpolated()
		var vis: bool = _on_screen(c.global_position)
		var slip: float = absf(c.v_s)
		var braking: bool = c.ctrl.brake > 0.0 and c.v_f > 10.0
		var launching: bool = c.launch_t > 0.0 and c.on_ground
		var skidding: bool = vis and not c.wrecked and c.on_ground and (c.drifting or slip > 3.5 or braking or launching)
		var wi := 0
		for w in c.wheels:
			if w.lost:
				wi += 1
				continue
			var wp: Vector3 = cx * Vector3(w.base.x, 0.0, w.base.z)
			var oily: bool = c.oily_t > 0.0 and vis and c.on_ground and w.contact and not c.wrecked
			if (skidding and w.contact and (not w.front or braking)) or oily:
				var last = e.skid[wi]
				if last != null:
					var al: float = 0.5 if (c.drifting or launching) else 0.28
					if oily:
						al = maxf(al, 0.75 * clampf(c.oily_t / 1.2, 0.0, 1.0))
					fx.skid(last, wp, 0.44 if oily else 0.38, al, c.ground_n)
				e.skid[wi] = wp
			else:
				e.skid[wi] = null
			wi += 1
		if e.has("smoke"):
			var rear: Array = c.wheels.filter(func(w): return not w.front)
			for i in 2:
				var s: CPUParticles3D = e.smoke[i]
				var du: CPUParticles3D = e.dust[i]
				if i < rear.size() and not rear[i].lost:
					var wpos: Vector3 = cx * Vector3(rear[i].base.x, 0.2, rear[i].base.z)
					s.global_position = wpos
					du.global_position = wpos
				s.emitting = skidding and (c.drifting or slip > 5.0 or braking or launching)
				du.emitting = vis and not c.wrecked and c.on_ground and absf(c.lat) > track.HALF + 0.4 and c.linear_velocity.length() > 8.0
			var flame: Node3D = e.flame
			if c.nitroing and not e.get("was_n", false) and c != player and vis:
				fx.nitro_burst(cx * c.exhaust_local, cx.basis.z)
			e.was_n = c.nitroing
			e.heat_t = 0.5 if c.nitroing else maxf(0.0, float(e.get("heat_t", 0.0)) - dt)
			for fl: Node3D in [flame, e.flame2]:
				(fl.get_node("P") as CPUParticles3D).emitting = c.nitroing
				(fl.get_node("Haze") as CPUParticles3D).emitting = vis and (c.nitroing or float(e.heat_t) > 0.0)
				var core := fl.get_node("Core") as Node3D
				core.visible = c.nitroing
				if c.nitroing:
					var w := randf_range(0.9, 1.15)
					core.scale = Vector3(w, w, randf_range(0.8, 1.25))
			for i in 2:
				var tp: Vector3 = cx * c.tail_local[i]
				fx.trail_push(e.trails[i], tp, real, c.nitroing and vis)
		(e.dark as CPUParticles3D).emitting = vis and (c.health < c.max_health * 0.45 or c.wrecked)
		(e.fire as CPUParticles3D).emitting = vis and (c.health < c.max_health * 0.2 or (c.wrecked and c.wreck_t < 3.0) or c.burn_t > 0.0)
		var sh: MeshInstance3D = e.shadow
		sh.visible = vis
		if vis:
			var a := track.at(c.s_track, c.lat)
			var gp: Vector3 = c.ground_pt if c.on_ground and not c.wrecked else a.pos
			var gn: Vector3 = c.ground_n if c.on_ground and not c.wrecked else a.up
			var hgt: float = maxf(0.0, (c.global_position - gp).dot(gn))
			var f: Vector3 = cx.basis.z.slide(gn).normalized()
			if f.length() < 0.5:
				f = a.tan
			sh.global_transform = Transform3D(Basis(gn.cross(f).normalized(), gn, f).scaled_local(Vector3(c.sp.wid * 1.45, 1, c.sp.len * 1.25)), gp + gn * 0.08)
			(sh.material_override as ShaderMaterial).set_shader_parameter("strength", clampf(1.0 - hgt * 0.25, 0.15, 1.0))
		if e.has("wind"):
			var w: CPUParticles3D = e.wind
			var sp: float = c.linear_velocity.length()
			w.emitting = (sp > 36.0 or c.nitroing) and not c.wrecked
			if w.emitting:
				var dir: Vector3 = c.linear_velocity.normalized()
				w.global_position = c.global_position + dir * 10.0 + Vector3.UP * 1.5
				w.direction = -dir
				w.initial_velocity_min = sp * 0.05
				w.initial_velocity_max = sp * 0.1
		if vis and not c.wrecked and c.linear_velocity.length() > 6.0:
			for w in c.wheels:
				if w.lost and randf() < dt * 30.0:
					fx.sparks(cx * Vector3(w.base.x, 0.1, w.base.z), -c.linear_velocity, 0.25)


func _cam_mode(rdt: float) -> String:
	if mode != "race" and mode != "finish" and mode != "countdown":
		return ""
	var p := player
	if p.wrecked:
		return ""
	var want := ""
	cam_loop_u = 1.0
	# looping: distância (em amostras) até o loop à frente e ao que acabou de passar.
	# A câmera de loop entra aos poucos na chegada e devolve a visão ao carro logo depois da saída.
	var la := -1
	var lb := -1
	if track.loopf[p.ti] == 1:
		la = 0
	else:
		for k in range(1, int(30.0 / track.ds)):
			if track.loopf[track.idx(p.ti + k)] == 1:
				la = k
				break
		for k in range(1, int(20.0 / track.ds)):
			if track.loopf[track.idx(p.ti - k)] == 1:
				lb = k
				break
	if la >= 0 or lb >= 0:
		want = "loop"
		var use_ahead := la >= 0 and (lb < 0 or la * 2 <= lb * 3)
		cam_loop = track.loop_info(track.idx(p.ti + la) if use_ahead else track.idx(p.ti - lb))
		var ua := 1.0 if la < 0 else clampf((la * track.ds - 5.0) / 20.0, 0.0, 1.0)
		var ub := 1.0 if lb < 0 else clampf((lb * track.ds - 2.0) / 13.0, 0.0, 1.0)
		cam_loop_u = minf(ua, ub)
		cam_loop_u = cam_loop_u * cam_loop_u * (3.0 - 2.0 * cam_loop_u)
	else:
		var steps := int(30.0 / track.ds)
		for k in range(-2, steps):
			var j := track.idx(p.ti + k)
			if track.feat[j] == 1 and track.ftype[j] == "cork":
				want = "twist"
				for k2 in range(maxi(k, 0), steps):
					var j2 := track.idx(p.ti + k2)
					if track.corkf[j2] == 1:
						cam_loop = track.loop_info(j2)
						break
				break
			if track.feat[j] == 1 and track.ftype[j] == "helix" and k < 6:
				want = "helix"
				break
	if want == "" and not p.on_ground and p.air_t > 0.3:
		want = "air"
	if want != "":
		cam_mode = want
		cam_mode_t = 0.4
	else:
		cam_mode_t -= rdt
		if cam_mode_t <= 0.0:
			cam_mode = ""
	return cam_mode


func _camera(rdt: float) -> void:
	var p := player
	var v := p.linear_velocity
	# posição desenhada (interpolada entre passos de física): câmera e carro andam juntos, sem tremer
	var pp := p.get_global_transform_interpolated().origin
	# nitro: a câmera abre (zoom out) e olha mais à frente — sensação de velocidade
	nitro_zoom = move_toward(nitro_zoom, 1.0 if (p.nitroing and not p.wrecked) else 0.0, rdt * (2.2 if p.nitroing else 1.1))
	var nz := nitro_zoom * nitro_zoom * (3.0 - 2.0 * nitro_zoom)
	var target := pp + Vector3(v.x, 0, v.z) * (0.36 + nz * 0.16)
	var focus_h := 0.0
	if cam_focus and focus_t > 0.0:
		target = (cam_focus.get_global_transform_interpolated().origin + pp) * 0.5
		focus_h = -5.0
	if p.wrecked:
		target = pp
	if mode == "menu":
		target = track.at(fmod(real * 18.0, track.length)).pos
	var cm := _cam_mode(rdt) if mode != "shots" else ""
	var want_yaw := CAM_YAW
	var want_pitch := CAM_PITCH
	var follow := 3.0 if p.wrecked else 4.5
	var extra := 0.0
	var size_fix := -1.0
	var size_u := 0.0
	match cm:
		"loop":
			# vista 3/4: de lado e um pouco de frente, alta o bastante para ver o asfalto por dentro
			var lc: Vector3 = cam_loop.center
			var ax: Vector3 = cam_loop.axis
			var axh := Vector3(ax.x, 0, ax.z).normalized()
			var y1 := atan2(axh.x, axh.z)
			var y2 := atan2(-axh.x, -axh.z)
			var ys := y1 if absf(angle_difference(CAM_YAW, y1)) <= absf(angle_difference(CAM_YAW, y2)) else y2
			# gira 38° para o lado de onde a câmera normal vem (continua familiar para o jogador)
			var u := cam_loop_u
			want_yaw = lerp_angle(ys + signf(angle_difference(ys, CAM_YAW)) * deg_to_rad(38.0), CAM_YAW, u)
			want_pitch = lerpf(0.42, CAM_PITCH, u)
			var along := (pp - lc).dot(ax)
			var mid := lc + ax * along
			target = mid.lerp(pp, 0.3).lerp(target, u)
			size_fix = float(cam_loop.r) * 2.0 + 20.0
			size_u = u
			follow = lerpf(3.2, 5.0, u)
		"twist":
			# saca-rolhas: a câmera segue o EIXO da espiral (reto e fixo), não a pista que gira em volta dele
			var ax2: Vector3 = cam_loop.get("axis", track.T[p.ti])
			var c0: Vector3 = cam_loop.get("center", pp)
			var th := Vector3(ax2.x, 0, ax2.z).normalized()
			var yb := atan2(-th.x, -th.z)
			want_yaw = lerp_angle(CAM_YAW, yb, 0.35)   # gira pouco: o analógico continua batendo com a tela
			want_pitch = 0.5
			var on_axis := c0 + ax2 * (pp - c0).dot(ax2)
			target = on_axis + th * 6.0
			size_fix = 32.0
			follow = 3.5
		"helix":
			want_pitch = 0.9
			extra = 11.0
		"air":
			want_pitch = 0.5
			extra = 6.0
	var bk := 1.0 - exp(-rdt * 2.4)   # trocas de câmera mais macias
	cam_yaw = lerp_angle(cam_yaw, want_yaw, bk)
	cam_pitch = lerpf(cam_pitch, want_pitch, bk)
	if mode == "menu" or mode == "shots":
		cam_yaw = CAM_YAW
		cam_pitch = CAM_PITCH
	var k := 1.0 - exp(-rdt * follow)
	cam_kick *= exp(-rdt * 5.0)
	if mode != "shots":
		cam_pos = cam_pos.lerp(target + cam_kick, k)
	var vs := cam.get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(1.0, vs.y)
	var base := (maxf(28.0, 26.0 / aspect) if aspect < 1.0 else 28.0) * cam_size_mul
	var sp := v.length()
	var want := base + clampf(sp / 55.0, 0.0, 1.0) * 8.0 + nz * base * 0.34 + focus_h + (-8.0 if p.wrecked else 0.0) + extra
	if size_fix > 0.0:
		want = lerpf(maxf(size_fix, base) / clampf(aspect, 0.6, 1.0), want, size_u)
	if mode == "menu":
		want = 40.0
	if test_zoom > 0.0 and mode != "menu":
		want = test_zoom
	if mode == "shots":
		want = view_h
		zoom_kick = 0.0
	zoom_kick *= exp(-rdt * 4.0)
	view_h = lerpf(view_h, want + zoom_kick, 1.0 - exp(-rdt * 3.0))
	cam.size = maxf(8.0, view_h)
	var off := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch)) * CAM_DIST
	cam.global_position = cam_pos + off
	cam.look_at(cam_pos, Vector3.UP)
	shake_t += rdt
	trauma = maxf(0.0, trauma - rdt * 1.6)
	var s := trauma * trauma
	cam.h_offset = (sin(shake_t * 37.0) * 0.6 + sin(shake_t * 85.0 + 1.0) * 0.4) * s * 1.5
	cam.v_offset = (sin(shake_t * 41.0 + 4.0) * 0.6 + sin(shake_t * 94.0 + 2.0) * 0.4) * s * 1.1
	cam.rotate_object_local(Vector3.FORWARD, sin(shake_t * 29.0 + 9.0) * s * 0.04)


func _post(rdt: float) -> void:
	var p := player
	var sp := p.linear_velocity.length()
	var slow := ts < 0.6
	var bt := (0.6 if p.nitroing else 0.0) + clampf((sp - 38.0) / 30.0, 0.0, 0.2) + (0.4 if slow else 0.0)
	post_blur = lerpf(post_blur, bt, minf(1.0, rdt * 6.0))
	oil_fx = maxf(0.0, oil_fx - rdt * 1.2)
	post_aberr = lerpf(post_aberr, (0.8 if p.nitroing else 0.0) + trauma * 1.5 + (0.8 if slow else 0.0) + oil_fx * 2.2, minf(1.0, rdt * 8.0))
	post_lines = lerpf(post_lines, (1.35 if p.nitroing else 0.0) + clampf((sp - 42.0) / 15.0, 0.0, 0.6), minf(1.0, rdt * 6.0))
	flash.a *= exp(-rdt * 7.0)
	var m := hud.post_mat
	var sfx_on: float = 1.0 if bool(settings.val("screen_fx")) else 0.0
	m.set_shader_parameter("blur", post_blur * sfx_on)
	m.set_shader_parameter("aberr", post_aberr * sfx_on)
	m.set_shader_parameter("lines", post_lines * sfx_on)
	m.set_shader_parameter("flash", Vector4(flash.r, flash.g, flash.b, flash.a))
	m.set_shader_parameter("sat", 0.7 if slow else 1.0)
	m.set_shader_parameter("vig", 0.3 + (0.25 if p.nitroing else 0.0) + (0.3 if slow else 0.0))
	var vs := get_viewport().get_visible_rect().size
	m.set_shader_parameter("aspect", vs.x / maxf(1.0, vs.y))
	m.set_shader_parameter("center", cam.unproject_position(p.get_global_transform_interpolated().origin + Vector3.UP * 0.6) / vs)


func _hud() -> void:
	var p := player
	hud.pos_l.text = "%dº" % place
	hud.lap_l.text = "VOLTA %d/%d" % [clampi(p.lap + 1, 1, LAPS), LAPS]
	hud.time_l.text = _fmt(race_t)
	hud.score_l.text = "$%d  ·  %d DESTRUÍDOS" % [int(save.cash), int(stats.get("kills", 0))]
	hud.speed_l.text = "%d km/h" % int(p.linear_velocity.length() * 3.6 * 1.25)
	hud.boss_bar.visible = boss != null and mode in ["race", "countdown", "finish"] and not (multi and multi.split)
	if hud.boss_bar.visible:
		hud.boss_bar.queue_redraw()
	var tc := hud.touch
	tc.counts["fire"] = str(p.ammo_f)
	tc.counts["drop"] = str(p.ammo_r)
	tc.counts["nitro"] = str(p.nitro_ch)
	tc.counts["special"] = str(p.spec_ch)
	tc.nitro_on = p.nitroing

extends Node3D
## Smash na Areia - controlador da partida.
## Regras de beach tennis: a bola não pode tocar a areia, um toque por dupla,
## saque único, contagem de tênis com "ponto de ouro" no 40-40.
## Camada arcade: golpes com efeito, golpe carregado, estrelas de chance,
## barra de energia e super golpe de cada personagem.

enum S { SERVE, RALLY, POINT, REPLAY, END }

var state := S.SERVE
var time := 0.0
var demo := true
var rng := RandomNumberGenerator.new()

var world: World
var ball: Ball
var cam: Camera3D
var hud: Hud
var players: Array[Player] = []
var human: Player = null            # jogador 1 (toque/teclado/controle)
var humans: Array[Player] = []      # todos os jogadores humanos (multiplayer local)
var views: Array[Dictionary] = []   # uma câmera por jogador no modo VS (tela dividida)
var view_layer: CanvasLayer
var pad_prev := {}                  # estado anterior dos botões de cada controle
var marker: MeshInstance3D

var points := [0, 0]
var games := [0, 0]
var games_to_win := 2
var serving_team := 0
var server_turn := [0, 0]
var server: Player = null
var serve_phase := 0
var serve_type := -1
var serve_timer := 0.0
var point_timer := 0.0
var match_over := false
var assigned: Array = [null, null]
var assign_t := 0.0
var announced_hit := -1
var rally_hits := 0

# camada arcade
var energy := [0.0, 0.0]
var chance := {}              # {team, pos, type, player}
var chance_hit := -1
var chance_star: MeshInstance3D
var last_winner: Player = null

# câmera
var cam_pos := Vector3(0, 8, 17)
var cam_look := Vector3.ZERO
var cam_back := 1.0
var cam_cut := true
var fov_kick := 0.0
var shake := 0.0
var hitstop := 0.0
var intro_t := 10.0
var celeb: Player = null
var cam_vel := Vector3.ZERO
var look_vel := Vector3.ZERO

# replay em câmera lenta dos lances bonitos
const REC_MAX := 150
const REPLAY_LEN := 105
const REPLAY_SPEED := 0.42
var rec: Array = []
var highlight := 0
var replay_f := 0.0
var replay_from := 0
var replay_done := false
var replay_cam := Vector3.ZERO
var replay_ok := false
var replay_cool := 0

var sfx_players: Array[AudioStreamPlayer] = []
var sfx_next := 0
var sounds := {}
var music: AudioStreamPlayer
var waves: AudioStreamPlayer
var sand_small: Array[CPUParticles3D] = []
var sand_big: Array[CPUParticles3D] = []
var sand_i := 0
var sparks: Array[CPUParticles3D] = []
var spark_i := 0
var impacts: Array[Dictionary] = []

# depuração / testes automáticos (argumentos depois de "--")
var autoplay := false
var sim := false
var shot_dir := ""
var shot_next := 2.0
var shot_n := 0
var shot_max := 12
var shot_dt := 1.7
var stats := {}
var total_points := 0
var keytest := false
var keytest_t := 0.0


func _ready() -> void:
	rng.randomize()
	_setup_input()
	world = World.new()
	add_child(world)
	_setup_views()
	cam = views[0]["cam"]
	ball = Ball.new()
	add_child(ball)
	ball.trail_cam = cam
	ball.landed.connect(_on_ball_landed)
	ball.touched_net.connect(_on_net)
	marker = Toon.blob(1.0, Color(1, 0.9, 0.2, 0.9), true)
	add_child(marker)
	chance_star = MeshInstance3D.new()
	var cq := PlaneMesh.new()
	cq.size = Vector2(1.9, 1.9)
	chance_star.mesh = cq
	var cm := ShaderMaterial.new()
	cm.shader = preload("res://shaders/chance.gdshader")
	cm.render_priority = 2
	chance_star.material_override = cm
	chance_star.visible = false
	add_child(chance_star)
	_setup_audio()
	_setup_particles()
	hud = Hud.new()
	add_child(hud)
	hud.sfx_cb = func(n: String):
		if n == "music_toggle":
			_update_music()
		else:
			sfx(n, -4.0)
	hud.play_pressed.connect(start_match)
	hud.rematch_pressed.connect(start_match)
	hud.menu_pressed.connect(go_menu)
	hud.touch.shot.connect(_on_shot_button)
	hud.touch.dive.connect(_on_dive_button)
	hud.touch.super_pressed.connect(_on_super_button)
	hud.touch.defense_pressed.connect(func(): _on_shot_button(Shots.DEFENSE))
	get_viewport().size_changed.connect(_layout_views)
	Input.joy_connection_changed.connect(_on_joy_changed)
	go_menu()
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			autoplay = true
		elif a == "--sim":
			sim = true
			autoplay = true
		elif a == "--keytest":
			keytest = true
			autoplay = true
		elif a == "--inputtest":
			# entradas reais de J1 e J2 pelo teclado, sem IA nos humanos
			keytest = true
			start_match.call_deferred()
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8)
		elif a.begins_with("--shotdt="):
			shot_dt = float(a.substr(9))
		elif a.begins_with("--shotmax="):
			shot_max = int(a.substr(10))
		elif a.begins_with("--char="):
			GameData.char_index = int(a.substr(7))
		elif a.begins_with("--mode="):
			GameData.mode = a.substr(7)
		elif a.begins_with("--diff="):
			GameData.difficulty = int(a.substr(7))
		elif a.begins_with("--portrait="):
			_portrait.call_deferred(a.substr(11))
	if autoplay:
		start_match.call_deferred()


## O 3D é desenhado em SubViewports (uma por jogador no modo VS) que dividem a tela.
func _setup_views() -> void:
	get_viewport().disable_3d = true
	view_layer = CanvasLayer.new()
	view_layer.layer = -1
	add_child(view_layer)
	for i in 2:
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view_layer.add_child(svc)
		var sv := SubViewport.new()
		sv.world_3d = get_viewport().world_3d
		sv.msaa_3d = Viewport.MSAA_2X
		sv.audio_listener_enable_3d = false
		svc.add_child(sv)
		var c := Camera3D.new()
		c.fov = 54
		c.far = 1000
		sv.add_child(c)
		c.current = true
		views.append({"svc": svc, "sv": sv, "cam": c, "viewer": null, "pos": Vector3(0, 8, 17),
			"look": Vector3.ZERO, "vel": Vector3.ZERO, "lvel": Vector3.ZERO, "back": 1.0, "cut": true})
	_layout_views()


func split_active() -> bool:
	return not demo and GameData.mode == "vs" and humans.size() >= 2 and state != S.REPLAY


func _layout_views() -> void:
	if views.is_empty():
		return
	var vs := get_viewport().get_visible_rect().size
	var split := split_active()
	for i in views.size():
		var v: Dictionary = views[i]
		var svc: SubViewportContainer = v["svc"]
		var sv: SubViewport = v["sv"]
		if i == 0:
			svc.position = Vector2.ZERO
			svc.size = Vector2(vs.x * (0.5 if split else 1.0), vs.y)
			svc.visible = true
		else:
			svc.visible = split
			svc.position = Vector2(vs.x * 0.5, 0)
			svc.size = Vector2(vs.x * 0.5, vs.y)
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS if svc.visible else SubViewport.UPDATE_DISABLED
		v["cut"] = true
	if hud:
		hud.set_split(split)


## Gera o retrato usado no ícone do app (fundo transparente).
func _portrait(path: String) -> void:
	hud.visible = false
	world.visible = false
	ball.visible = false
	marker.visible = false
	for p in players:
		p.visible = false
	set_physics_process(false)
	get_viewport().transparent_bg = true
	(views[0]["sv"] as SubViewport).transparent_bg = true
	_layout_views()
	var we := world.get_child(0) as WorldEnvironment
	we.environment.background_mode = Environment.BG_CLEAR_COLOR
	var p := Player.new()
	add_child(p)
	p.setup(GameData.CHARACTERS[GameData.char_index], 0, false)
	p.side = -1.0
	p.reset_state()
	p.shadow.visible = false
	for i in 20:
		p.update(1.0 / 30.0)
	cam.h_offset = 0.0
	cam.fov = 30
	cam.look_at_from_position(Vector3(0.75, 1.62, 3.1), Vector3(0.02, 1.32, 0.0))
	for i in 6:
		await get_tree().process_frame
	(views[0]["sv"] as SubViewport).get_texture().get_image().save_png(path)
	get_tree().quit()


var input_report := false


func _process(dt: float) -> void:
	if keytest and not demo:
		_keytest_step()
		if not autoplay and time > 140.0 and not input_report:
			input_report = true
			print("INPUTTEST ", stats, " placar ", games, points)
	_update_impacts(dt)
	if shot_dir != "" and time >= shot_next and shot_n < shot_max:
		shot_next = time + shot_dt
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%02d.png" % [shot_dir, shot_n])
		shot_n += 1
		if shot_n >= shot_max:
			get_tree().quit()


## Teste automático: aperta teclas como um jogador (caminho real de entrada).
func _keytest_step() -> void:
	if time < keytest_t:
		return
	keytest_t = time + rng.randf_range(0.25, 0.9)
	var actions := ["shot_drive", "shot_lob", "shot_drop", "shot_smash", "shot_defense", "jump", "dive", "move_left", "super",
		"move_up", "move_right", "p2_drive", "p2_lob", "p2_drop", "p2_smash", "p2_defense", "p2_super", "p2_dive", "p2_left", "p2_up"]
	var a: String = actions[rng.randi() % actions.size()]
	var e := InputEventAction.new()
	e.action = a
	e.pressed = true
	Input.parse_input_event(e)
	_stat("key_" + a)
	var r := InputEventAction.new()
	r.action = a
	r.pressed = false
	Input.parse_input_event.call_deferred(r)


func _stat(key: String) -> void:
	stats[key] = int(stats.get(key, 0)) + 1


func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A], "move_right": [KEY_D], "move_up": [KEY_W], "move_down": [KEY_S],
		"shot_drive": [KEY_J], "shot_lob": [KEY_K], "shot_drop": [KEY_L], "shot_smash": [KEY_I],
		"shot_defense": [KEY_O], "super": [KEY_U], "jump": [KEY_SPACE], "dive": [KEY_SHIFT],
		"pause": [KEY_ESCAPE, KEY_P],
		# J2 no teclado
		"p2_left": [KEY_LEFT], "p2_right": [KEY_RIGHT], "p2_up": [KEY_UP], "p2_down": [KEY_DOWN],
		"p2_drive": [KEY_N], "p2_lob": [KEY_M], "p2_drop": [KEY_COMMA], "p2_smash": [KEY_PERIOD],
		"p2_defense": [KEY_SLASH], "p2_super": [KEY_B], "p2_dive": [KEY_V],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)


# ---------------------------------------------------------------- áudio / fx

func _setup_audio() -> void:
	for n in ["hit", "drop", "lob", "smash", "defense", "sand", "dive", "net", "jump", "swoosh",
			"whistle", "click", "tick", "cheer", "aww", "point", "lose_point", "win", "lose"]:
		sounds[n] = load("res://assets/audio/%s.wav" % n)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		sfx_players.append(p)
	music = AudioStreamPlayer.new()
	music.stream = _looped(load("res://assets/audio/music.wav"))
	music.volume_db = -9.0
	add_child(music)
	waves = AudioStreamPlayer.new()
	waves.stream = _looped(load("res://assets/audio/waves.wav"))
	waves.volume_db = -14.0
	add_child(waves)
	waves.play()
	_update_music()


func _looped(s: AudioStreamWAV) -> AudioStreamWAV:
	var w := s.duplicate() as AudioStreamWAV
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = int(w.get_length() * w.mix_rate)
	return w


func _update_music() -> void:
	if GameData.music_on and not music.playing:
		music.play()
	elif not GameData.music_on:
		music.stop()


func sfx(n: String, db := 0.0, pitch_var := 0.08, pitch := 1.0) -> void:
	if not sounds.has(n):
		return
	var p := sfx_players[sfx_next]
	sfx_next = (sfx_next + 1) % sfx_players.size()
	p.stream = sounds[n]
	p.volume_db = db
	p.pitch_scale = pitch + rng.randf_range(-pitch_var, pitch_var)
	p.play()


func _setup_particles() -> void:
	var grain := SphereMesh.new()
	grain.radius = 0.05
	grain.height = 0.1
	grain.radial_segments = 6
	grain.rings = 3
	var mat := Toon.make(Color("f5d39a"), {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	for i in 14:
		var big := i >= 8
		var p := CPUParticles3D.new()
		p.mesh = grain
		p.material_override = mat
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = 16 if big else 6
		p.lifetime = 0.6
		p.direction = Vector3.UP
		p.spread = 70.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 4.5 if big else 3.0
		p.gravity = Vector3(0, -12, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.6
		p.scale_amount_curve = curve
		add_child(p)
		if big:
			sand_big.append(p)
		else:
			sand_small.append(p)
	# faíscas de impacto (estrelinhas coloridas)
	var star := QuadMesh.new()
	star.size = Vector2(0.18, 0.18)
	var smat := ShaderMaterial.new()
	smat.shader = preload("res://shaders/spark.gdshader")
	for i in 6:
		var s := CPUParticles3D.new()
		s.mesh = star
		s.material_override = smat
		s.emitting = false
		s.one_shot = true
		s.explosiveness = 1.0
		s.amount = 12
		s.lifetime = 0.35
		s.spread = 180.0
		s.initial_velocity_min = 3.0
		s.initial_velocity_max = 6.5
		s.gravity = Vector3(0, -4, 0)
		s.damping_min = 6.0
		s.damping_max = 9.0
		s.scale_amount_curve = curve
		add_child(s)
		sparks.append(s)
	for i in 5:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/impact.gdshader")
		mi.material_override = m
		mi.visible = false
		add_child(mi)
		impacts.append({"node": mi, "t": 1.0, "life": 0.18})


func sand_burst(pos: Vector3, n: int) -> void:
	var pool := sand_big if n >= 8 else sand_small
	var p := pool[sand_i % pool.size()]
	sand_i += 1
	p.global_position = Vector3(pos.x, 0.05, pos.z)
	p.restart()
	p.emitting = true


## Impacto 3D no ponto da batida: estrela de gibi + faíscas da cor do golpe
func impact(pos: Vector3, color: Color, size := 1.0) -> void:
	var s := sparks[spark_i % sparks.size()]
	spark_i += 1
	s.global_position = pos
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(color, 0.0))
	s.color_ramp = g
	s.amount = int(8 + 8 * size)
	s.restart()
	s.emitting = true
	for d in impacts:
		if float(d["t"]) >= 1.0:
			var n: MeshInstance3D = d["node"]
			n.global_position = pos
			n.scale = Vector3.ONE * 0.9 * size
			n.visible = true
			var m := n.material_override as ShaderMaterial
			m.set_shader_parameter("color", color)
			m.set_shader_parameter("seed", rng.randf() * TAU)
			d["t"] = 0.0
			d["life"] = 0.16 + 0.06 * size
			return


func _update_impacts(dt: float) -> void:
	for d in impacts:
		if float(d["t"]) < 1.0:
			d["t"] = minf(float(d["t"]) + dt / float(d["life"]), 1.0)
			var n: MeshInstance3D = d["node"]
			(n.material_override as ShaderMaterial).set_shader_parameter("t", d["t"])
			if float(d["t"]) >= 1.0:
				n.visible = false


func screen_pos(p: Vector3, vi := 0) -> Vector2:
	var v: Dictionary = views[vi]
	var c: Camera3D = v["cam"]
	var svc: SubViewportContainer = v["svc"]
	if c.is_position_behind(p):
		return svc.position + svc.size * 0.5
	return svc.position + c.unproject_position(p)


## Letreiro pequeno (sem atrapalhar a visão da bola), em cada tela
func comic(p: Vector3, text: String, color: Color, size := 0.6, star := true) -> void:
	for vi in (2 if split_active() else 1):
		hud.fx.pop(screen_pos(p, vi), text, color, size * (0.8 if split_active() else 1.0), star)


# ---------------------------------------------------------------- fluxo

func go_menu() -> void:
	get_tree().paused = false
	demo = true
	_spawn_players(false)
	_reset_score(3)
	hud.show_menu()
	cam_cut = true
	_layout_views()
	_begin_serve()


func start_match() -> void:
	demo = false
	_spawn_players(true)
	_layout_views()
	_reset_score(GameData.LENGTHS[GameData.length_index]["games"])
	hud.show_game()
	hud.show_banner("VAI COMEÇAR!", "%s x %s" % [GameData.TEAMS[0]["name"], GameData.TEAMS[1]["name"]], Color("ffd23f"), 1.8)
	sfx("whistle", -6.0)
	intro_t = 0.0
	_begin_serve()


func _reset_score(target: int) -> void:
	points = [0, 0]
	games = [0, 0]
	energy = [0.0, 0.0]
	games_to_win = target
	serving_team = 0
	server_turn = [0, 0]
	match_over = false
	hud.set_score(points, games, serving_team, games_to_win)
	hud.set_energy(energy)


func _spawn_players(with_human: bool) -> void:
	for p in players:
		p.queue_free()
	players.clear()
	humans.clear()
	human = null
	var ci: int = GameData.char_index if with_human else rng.randi() % 4
	var order := [ci, (ci + 1) % 4, (ci + 2) % 4, (ci + 3) % 4]
	var mode: String = GameData.mode if with_human else "solo"
	# índice no array de jogadores de cada humano: 0 = J1; J2 é parceiro (co-op) ou rival (VS)
	var p2_index := -1
	if mode == "coop":
		p2_index = 1
	elif mode == "vs":
		p2_index = 2
	if p2_index >= 0:
		var c2: int = GameData.char_index_p2
		if c2 == ci:
			c2 = (ci + 2) % 4
		order.erase(c2)
		order.insert(p2_index, c2)
	var diff: Dictionary = GameData.DIFFICULTIES[GameData.difficulty if with_human else 1]
	for i in 4:
		var team := 0 if i < 2 else 1
		var p := Player.new()
		add_child(p)
		var is_h := with_human and (i == 0 or i == p2_index)
		p.setup(GameData.CHARACTERS[order[i]], team, is_h)
		p.game = self
		p.home_x = 1.8 if i % 2 == 0 else -1.8
		if not is_h:
			var d := diff
			if team == 0 and with_human:
				d = GameData.DIFFICULTIES[1]
			p.brain = AIBrain.new(p, d)
			p.diff_speed = float(d["speed"])
		else:
			p.pid = 1 if i == 0 else 2
			if i == 0:
				human = p
			humans.append(p)
			if autoplay:
				p.brain = AIBrain.new(p, GameData.DIFFICULTIES[1])
		players.append(p)
	_assign_pads()


## Distribui os controles: com 2 controles cada jogador usa um; com 1, o J2 fica
## com o controle e o J1 com toque/teclado.
func _assign_pads() -> void:
	var pads := Input.get_connected_joypads()
	for p in humans:
		p.pad = -1 if p.pid == 1 else -3
	if humans.size() == 1:
		humans[0].pad = pads[0] if pads.size() > 0 else -1
		humans[0].pad_also_kb = true
	elif humans.size() >= 2:
		if pads.size() >= 2:
			humans[0].pad = pads[0]
			humans[1].pad = pads[1]
		elif pads.size() == 1:
			humans[0].pad = -1
			humans[1].pad = pads[0]
		humans[0].pad_also_kb = true
	for p in humans:
		p.show_tag(humans.size() > 1)


## Controle conectado/desconectado no meio da partida ou no menu
func _on_joy_changed(_device: int, connected: bool) -> void:
	if not demo:
		_assign_pads()
		hud.show_banner("CONTROLE " + ("CONECTADO" if connected else "DESCONECTADO"), "", Color.WHITE, 1.2)
	else:
		hud._refresh_menu()


## Vibração no controle (ou no celular, para o J1 no toque)
func rumble(p: Player, strong: bool) -> void:
	if p.pad >= 0:
		Input.start_joy_vibration(p.pad, 0.4 if not strong else 0.7, 0.2 if not strong else 0.9, 0.12 if not strong else 0.25)
	elif p.pid == 1:
		Input.vibrate_handheld(35 if not strong else 90)


func team_human(team: int) -> Player:
	for p in humans:
		if p.team == team:
			return p
	return null


func team_players(team: int) -> Array[Player]:
	var out: Array[Player] = []
	for p in players:
		if p.team == team:
			out.append(p)
	return out


func teammate(p: Player) -> Player:
	for o in players:
		if o != p and o.team == p.team:
			return o
	return null


func opponents(p: Player) -> Array:
	var out := []
	for o in players:
		if o.team != p.team:
			out.append(o)
	return out


func interceptor(team: int) -> Player:
	return assigned[team]


## Onde um jogador sem a bola deve ficar.
func support_position(p: Player) -> Vector3:
	var s := p.side
	var mate := teammate(p)
	if ball.is_live() and ball.last_team != p.team and mate != null and assigned[p.team] == mate:
		var mx := mate.position.x
		if mate.brain and not mate.brain.plan.is_empty():
			mx = (mate.brain.plan["stand"] as Vector3).x
		var cx := mx + (2.6 if mx < 0.0 else -2.6)
		return Vector3(clampf(cx, -3.4, 3.4), 0.0, s * 4.6)
	var z := 4.2
	if ball.last_team == p.team:
		match ball.last_shot:
			Shots.LOB, Shots.DEFENSE:
				z = 4.9
			Shots.SMASH, Shots.DROP, Shots.SPECIAL:
				z = 3.1
		if ball.is_live() and ball.last_shot == Shots.LOB:
			var lp := ball.landing_point()
			if absf(lp.z) < 5.5:
				z = 5.7
	var x := p.home_x * 0.95 + ball.position.x * 0.3
	return Vector3(clampf(x, -3.6, 3.6), 0.0, s * z)


func _begin_serve() -> void:
	state = S.SERVE
	serve_phase = 0
	serve_timer = 0.0
	serve_type = -1
	rally_hits = 0
	highlight = 0
	rec.clear()
	replay_done = false
	hud.set_replay(false)
	assigned = [null, null]
	chance = {}
	chance_star.visible = false
	celeb = null
	cam_cut = true
	var tp := team_players(serving_team)
	var th := team_human(serving_team) if not demo else null
	if th != null:
		server = th
	else:
		server = tp[server_turn[serving_team] % tp.size()]
	var lane := 1.0 if (points[0] + points[1]) % 2 == 0 else -1.0
	var ss := 1.0 if serving_team == 0 else -1.0
	var serve_x := lane * 1.6 * ss
	# quem recebe fica na diagonal do sacador, no meio-fundo; o parceiro fica perto da rede
	var recv_team := 1 - serving_team
	var rs := 1.0 if recv_team == 0 else -1.0
	var receiver: Player = null
	var best_d := INF
	for p in team_players(recv_team):
		var dd := absf(p.home_x - (-serve_x))
		if dd < best_d:
			best_d = dd
			receiver = p
	for p in players:
		p.reset_state()
		p.lock_x = false
		if p == server:
			p.position = Vector3(serve_x, 0, ss * 8.7)
			p.serve_mode = true
			if p.is_human:
				p.lock_x = true
				p.locked_z = p.position.z
		elif p.team == serving_team:
			p.position = Vector3(-serve_x * 0.8, 0, ss * 2.7)
		elif p == receiver:
			p.position = Vector3(-serve_x * 1.05, 0, rs * 6.1)
		else:
			p.position = Vector3(serve_x * 0.85, 0, rs * 3.0)
		if p.brain:
			p.brain.move_target = p.position
			p.brain.plan = {}
	ball.reset_to(server.position + Vector3(0, 1.2, 0))
	ball.held_by = server
	ball.last_team = serving_team
	if points[0] == 3 and points[1] == 3:
		hud.show_banner("PONTO DE OURO!", "quem fizer leva o game", Color("ff4b3e"), 1.6)
	if not demo:
		var who := ""
		if server.is_human:
			who = "SEU SAQUE" if humans.size() == 1 else "SAQUE DO J%d" % server.pid
		hud.set_hint(who + ": escolha um golpe (SMASH = saque viagem)" if who != "" else "")
	hud.set_score(points, games, serving_team, games_to_win)


func _hand_pos(p: Player) -> Vector3:
	return p.global_position + p.global_transform.basis * Vector3(0.38, 1.25, 0.25)


func _do_toss(type: int) -> void:
	if serve_phase != 0:
		return
	serve_phase = 1
	serve_type = type
	serve_timer = 0.0
	ball.toss(_hand_pos(server), Vector3(0, 5.2 if type == Shots.SMASH else 4.6, 0))
	server.pending_shot = Shots.SMASH
	server.pending_t = 5.0
	server.style = "smash"
	if type == Shots.SMASH:
		server.jump_timer = 0.32
	hud.set_hint("")
	sfx("swoosh", -10.0)


func _serve_hit() -> void:
	var type := serve_type
	var aim := Vector2.ZERO
	if server.is_human and not autoplay:
		aim = _human_aim(server)
	else:
		aim = Vector2(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.2, 0.7))
	var shot := Shots.DRIVE
	var quality := 0.85
	match type:
		Shots.LOB:
			shot = Shots.LOB
		Shots.DROP:
			shot = Shots.DROP
		Shots.SMASH:
			shot = Shots.SMASH
			quality = 0.7
	server._start_swing(Shots.SMASH, ball.position, "smash")
	var err := 1.0 if server.is_human else float(GameData.DIFFICULTIES[GameData.difficulty]["error"])
	var res := Shots.compute(shot, ball.position, -server.side, aim, quality,
			float(server.data["power"]), float(server.data["control"]), err * 0.8, rng)
	if shot == Shots.SMASH:
		res["label"] = "SAQUE VIAGEM!"
	_launch(server, shot, res, quality, 0.0, false)
	ball.is_serve = true
	server.serve_mode = false
	server.lock_x = false
	state = S.RALLY


func _launch(p: Player, shot: int, res: Dictionary, quality: float, charge: float, chance_shot: bool) -> void:
	ball.is_serve = false
	var sp: String = res.get("special", "")
	ball.launch(res["velocity"], res["spin"], p.team, p, shot, sp, quality)
	if sim:
		ball.set_meta("sp", sp)
		var simd: Dictionary = res.get("sim", {})
		ball.set_meta("dbg", "%s from=%s v=%s w=%s net_h=%s" % [Shots.NAMES[shot], ball.global_position, res["velocity"], res["spin"], simd.get("net_h", -1)])
	rally_hits += 1
	if shot_dir != "":
		print("EVT ", shot_n, " ", res["label"], " team=", p.team, " human=", p.is_human, " q=", snappedf(quality, 0.01),
				" charge=", snappedf(charge, 0.1), " chance=", chance_shot)
	_stat("shot_" + Shots.NAMES[shot] + ("_serve" if state == S.SERVE else ""))
	_stat("style_" + p.last_style)
	announced_hit = -1
	assign_t = 0.0
	for o in opponents(p):
		(o as Player).split_step()
	if shot == Shots.SMASH or shot == Shots.SPECIAL:
		highlight += 2
	if chance_shot or p.last_style == "gancho" or p.last_style == "dive":
		highlight += 1
	var pos := ball.global_position
	var head := p.global_position + Vector3(0, 2.7, 0)
	var col := Color(1.0, 0.96, 0.82)
	# energia da barra de super
	if shot == Shots.SPECIAL:
		energy[p.team] = 0.0
	else:
		var gain := 0.012 + (0.02 if quality > 0.85 else 0.0) + charge * 0.03
		if chance_shot:
			gain += 0.1
		if shot == Shots.SMASH:
			gain += 0.015
		energy[p.team] = minf(1.0, energy[p.team] + gain)
	hud.set_energy(energy)
	match shot:
		Shots.SPECIAL:
			col = Shots.SPECIALS.get(sp, {"color": col})["color"]
			sfx("smash", 2.0, 0.02, 0.8)
			sfx("swoosh", 0.0)
			shake = 0.6
			hitstop = 0.16
			fov_kick = -12.0
			hud.fx.smash_lines(screen_pos(pos))
			hud.fx.do_flash(0.5)
			comic(head + Vector3(0, 0.3, 0), res["label"], col, 0.75)
			world.cheer(1.0)
			impact(pos, col, 2.2)
		Shots.SMASH:
			sfx("smash", 0.0)
			shake = 0.4
			hitstop = 0.06
			fov_kick = -6.0
			if p.is_human or rng.randf() < 0.5:
				comic(head, "POW!" if res["label"] == "SMASH" else res["label"], col, 0.6)
			world.cheer(0.6)
			impact(pos, col, 1.5)
		Shots.LOB:
			sfx("lob", -2.0)
			impact(pos, col, 0.7)
		Shots.DROP:
			sfx("drop", -2.0)
			impact(pos, col, 0.7)
		Shots.DEFENSE:
			sfx("defense", 0.0)
			impact(pos, col, 0.9)
			world.cheer(0.4)
		_:
			sfx("hit", 0.0)
			impact(pos, col, 0.9 + charge * 0.5)
	if chance_shot:
		comic(head + Vector3(0, 0.35, 0), "CHANCE!", Color("ffe14d"), 0.55)
		shake = maxf(shake, 0.25)
	if p.is_human:
		if shot != Shots.SPECIAL and shot != Shots.SMASH:
			var txt: String = res["label"]
			if quality > 0.88:
				txt = "PERFEITO!"
			hud.fx.pop(screen_pos(head), txt, col.lightened(0.2), 0.42, false)
		rumble(p, shot == Shots.SMASH or shot == Shots.SPECIAL)
	chance = {}
	chance_star.visible = false


func _do_hit(p: Player, type: int, quality: float, charge: float, style := "") -> void:
	var incoming_speed := ball.vel.length()
	var shot := type
	# recebeu um super golpe: é empurrado e só consegue defender
	if ball.special != "" and shot != Shots.SPECIAL:
		var resist := quality > 0.92 and rng.randf() < 0.35
		if not resist:
			p.knockback(Vector3(ball.vel.x, 0, ball.vel.z), 1.0)
			if p.is_human:
				rumble(p, true)
			comic(p.global_position + Vector3(0, 2.6, 0), "UAAAU!", Color("ffffff"), 0.5, false)
			shot = Shots.DEFENSE
			quality = 0.25
			charge = 0.0
	if incoming_speed > 16.5 and (shot == Shots.DRIVE or shot == Shots.DROP):
		shot = Shots.DEFENSE
	if shot == Shots.LOB and incoming_speed > 16.5:
		quality *= 0.85
	if shot == Shots.SPECIAL and energy[p.team] < 1.0:
		shot = Shots.SMASH if ball.position.y > 2.0 else Shots.DRIVE
	var is_chance := false
	if not chance.is_empty() and int(chance["team"]) == p.team and (int(chance["type"]) == shot):
		var cpos: Vector3 = chance["pos"]
		var rc := p.reach_center()
		if Vector2(cpos.x - rc.x, cpos.z - rc.z).length() < 1.1:
			is_chance = true
	var aim := Vector2.ZERO
	var err := 1.0
	if p.is_human and not autoplay:
		aim = _human_aim(p)
		if p.stick.length() < 0.25:
			aim.x = _auto_aim_x(p)
		err = 0.9
	elif p.brain:
		aim = p.brain.choose_aim(self, shot)
		err = float(p.brain.diff["error"])
	var extra := {"charge": charge, "chance": is_chance, "special": String(p.data.get("special", ""))}
	if style == "gancho":
		quality = maxf(quality - 0.05, 0.3)
	var res := Shots.compute(shot, ball.global_position, -p.side, aim, quality,
			float(p.data["power"]), float(p.data["control"]), err, rng, extra)
	if style == "gancho" and shot != Shots.SPECIAL:
		res["label"] = "GANCHO!"
		comic(p.global_position + Vector3(0, 2.9, 0), "GANCHO!", Color("ffe14d"), 0.5, false)
	_launch(p, shot, res, quality, charge, is_chance)


func _auto_aim_x(p: Player) -> float:
	var best := 0.0
	var best_s := -INF
	for cx in [-0.9, -0.45, 0.0, 0.45, 0.9]:
		var m := INF
		for o in opponents(p):
			m = minf(m, absf((o as Player).position.x - cx * 3.2))
		if m > best_s:
			best_s = m
			best = cx
	return best


func _key_vec() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Mira a partir do analógico do jogador (na tela dele). Para o J2 do outro lado
## da quadra o eixo lateral é invertido, porque a câmera dele olha ao contrário.
func _human_aim(p: Player) -> Vector2:
	var v := p.stick
	return Vector2(v.x * p.side, -v.y)


## Lê o analógico e os botões de cada jogador humano.
func _poll_inputs() -> void:
	for p in humans:
		var v := Vector2.ZERO
		if p.pad == -1 or p.pad_also_kb:
			v = hud.touch.joy_vec if p.pid == 1 else Vector2.ZERO
			var kv := _key_vec()
			if kv.length() > v.length():
				v = kv
		if p.pad == -3:
			v = Input.get_vector("p2_left", "p2_right", "p2_up", "p2_down")
		if p.pad >= 0:
			var jv := Vector2(Input.get_joy_axis(p.pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(p.pad, JOY_AXIS_LEFT_Y))
			if jv.length() < 0.2:
				jv = Vector2.ZERO
			var dp := Vector2(float(Input.is_joy_button_pressed(p.pad, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(p.pad, JOY_BUTTON_DPAD_LEFT)),
				float(Input.is_joy_button_pressed(p.pad, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(p.pad, JOY_BUTTON_DPAD_UP)))
			if dp.length() > jv.length():
				jv = dp.normalized()
			if jv.length() > v.length():
				v = jv
			_poll_pad_buttons(p)
		if v.length() > 1.0:
			v = v.normalized()
		p.stick = v


func _pad_edge(p: Player, key: String, down: bool) -> bool:
	var k := "%d_%s" % [p.pad, key]
	var was: bool = pad_prev.get(k, false)
	pad_prev[k] = down
	return down and not was


## Controle: A forte, X lob, B curta, Y smash, gatilho direito defesa,
## RB super, LB peixinho, Start pausa.
func _poll_pad_buttons(p: Player) -> void:
	var d := p.pad
	if _pad_edge(p, "start", Input.is_joy_button_pressed(d, JOY_BUTTON_START)) and not demo and state != S.END:
		hud._on_pause()
	if get_tree().paused:
		return
	var pairs := [[JOY_BUTTON_A, Shots.DRIVE], [JOY_BUTTON_X, Shots.LOB], [JOY_BUTTON_B, Shots.DROP], [JOY_BUTTON_Y, Shots.SMASH]]
	for pr in pairs:
		if _pad_edge(p, "b%d" % pr[0], Input.is_joy_button_pressed(d, pr[0])):
			_player_shot(p, pr[1])
	if _pad_edge(p, "rt", Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > 0.5 or Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_STICK)):
		_player_shot(p, Shots.DEFENSE)
	if _pad_edge(p, "rb", Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_SHOULDER)):
		_player_super(p)
	if _pad_edge(p, "lb", Input.is_joy_button_pressed(d, JOY_BUTTON_LEFT_SHOULDER) or Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) > 0.5):
		_player_dive(p)


## Estrela de chance: aparece quando o adversário devolve uma bola fraca.
func _refresh_chance() -> void:
	chance = {}
	chance_star.visible = false
	if not ball.is_live() or ball.last_team < 0:
		return
	var team := 1 - ball.last_team
	var weak := (ball.last_quality < 0.62 and ball.last_shot != Shots.SMASH) or ball.last_shot == Shots.DEFENSE
	if ball.last_shot == Shots.LOB and absf(ball.landing_point().z) < 5.8:
		weak = true
	if not weak or ball.is_serve:
		return
	var best := {}
	var who: Player = null
	for p in team_players(team):
		var plan := AIBrain.intercept(p, ball, 0.0)
		if plan.is_empty() or plan["dive"]:
			continue
		if best.is_empty() or float(plan["t"]) < float(best["t"]):
			best = plan
			who = p
	if who == null:
		return
	var bp: Vector3 = best["point"]
	var type := Shots.DROP
	if bp.y > Player.TOP_REACH - 0.25:
		type = Shots.SMASH
	elif bp.y > 0.85:
		type = Shots.DRIVE
	var pos: Vector3 = best["stand"] + who.net_dir() * 0.3
	chance = {"team": team, "pos": pos, "type": type, "player": who}
	chance_star.visible = true
	chance_star.global_position = Vector3(pos.x, 0.035, pos.z)
	(chance_star.material_override as ShaderMaterial).set_shader_parameter("color", Shots.COLORS[type])
	if team == 0 and not demo:
		sfx("tick", -6.0, 0.0, 1.3)


# ---------------------------------------------------------------- entrada

func _on_shot_button(type: int) -> void:
	if human:
		_player_shot(human, type)


func _on_super_button() -> void:
	if human:
		_player_super(human)


func _on_dive_button() -> void:
	if human:
		_player_dive(human)


func _player_shot(p: Player, type: int) -> void:
	if intro_t < 0.4 and not demo:
		return   # o botão que confirmou o menu não vale como golpe
	if state == S.REPLAY and not demo:
		replay_f = float(rec.size())
		return
	if demo or p == null or get_tree().paused:
		return
	if state == S.SERVE and server == p:
		_do_toss(type if type != Shots.DEFENSE else Shots.LOB)
		return
	if state != S.RALLY:
		return
	p.request_shot(type)


func _player_super(p: Player) -> void:
	if intro_t < 0.4 and not demo:
		return   # o botão que confirmou o menu não vale como golpe
	if demo or p == null or state != S.RALLY or energy[p.team] < 1.0:
		return
	p.request_shot(Shots.SPECIAL)
	if p.data.get("special", "") == "meteoro" and p.on_ground():
		p.jump_boost = 1.45
		if p.jump_timer < 0.0:
			p.jump_timer = 0.05
	sfx("swoosh", -2.0, 0.0, 1.3)


func _player_dive(p: Player) -> void:
	if intro_t < 0.4 and not demo:
		return   # o botão que confirmou o menu não vale como golpe
	if demo or p == null or state != S.RALLY:
		return
	var dir := Vector3(p.stick.x, 0, p.stick.y) * p.side
	if dir.length() < 0.2 and ball.is_live():
		var lp := ball.landing_point()
		dir = Vector3(lp.x - p.position.x, 0, lp.z - p.position.z)
	p.request_dive(dir)


func _unhandled_input(event: InputEvent) -> void:
	if state == S.REPLAY and not demo and event.is_pressed() and not event.is_echo():
		replay_f = float(rec.size())   # toque para pular o replay
		return
	if event.is_action_pressed("pause") and not demo and state != S.END:
		hud._on_pause()
	if demo or human == null:
		return
	for pair in [["shot_drive", Shots.DRIVE], ["shot_lob", Shots.LOB], ["shot_drop", Shots.DROP],
			["shot_smash", Shots.SMASH], ["shot_defense", Shots.DEFENSE]]:
		if event.is_action_pressed(pair[0]):
			hud.touch.flash_button(pair[1])
			_on_shot_button(pair[1])
	if event.is_action_pressed("super"):
		_on_super_button()
	if event.is_action_pressed("jump") and state == S.RALLY:
		human.request_jump()
	if event.is_action_pressed("dive"):
		_on_dive_button()
	# J2 no teclado (setas + N M , . /)
	for p in humans:
		if p.pad != -3:
			continue
		for pair in [["p2_drive", Shots.DRIVE], ["p2_lob", Shots.LOB], ["p2_drop", Shots.DROP],
				["p2_smash", Shots.SMASH], ["p2_defense", Shots.DEFENSE]]:
			if event.is_action_pressed(pair[0]):
				_player_shot(p, pair[1])
		if event.is_action_pressed("p2_super"):
			_player_super(p)
		if event.is_action_pressed("p2_dive"):
			_player_dive(p)


## Quanto tempo até uma bola alta descer para a altura de cravar perto do jogador.
func time_until_reachable(p: Player) -> float:
	if not ball.is_live() or ball.last_team == p.team:
		return -1.0
	for i in range(1, 80):
		var t := i * 0.02
		var bp := ball.predict(t)
		if bp.z * p.side < 0.3:
			continue
		var d := Vector2(bp.x - p.position.x, bp.z - p.position.z).length()
		if bp.y < Player.TOP_REACH + 0.95 and d < 3.5:
			return t
	return -1.0


func predict_high_contact(p: Player) -> float:
	if not ball.is_live() or ball.last_team == p.team:
		return -1.0
	for i in range(1, 40):
		var t := i * 0.02
		var bp := ball.predict(t)
		if bp.z * p.side < 0.3:
			continue
		var c := p.reach_center() + p.vel * t * 0.6
		var d := Vector2(bp.x - c.x, bp.z - c.z).length()
		if d < Player.REACH * 0.95 and bp.y > Player.TOP_REACH - 0.15 and bp.y < Player.TOP_REACH + 1.0:
			return t
	return -1.0


# ---------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta
		_update_camera(delta)
		return
	var dt := delta
	time += dt
	intro_t += dt
	if not demo and not autoplay:
		_poll_inputs()
		for hp in humans:
			var v := hp.stick
			if state == S.SERVE and server == hp:
				v.y = 0.0
			# a câmera do J2 olha para o outro lado: o analógico é espelhado
			hp.move_input = Vector3(v.x, 0, v.y) * hp.side if state != S.POINT else Vector3.ZERO
	if state == S.RALLY:
		assign_t -= dt
		if assign_t <= 0.0:
			_assign()
			assign_t = 0.12
		if ball.hit_id != chance_hit:
			chance_hit = ball.hit_id
			_refresh_chance()
	for p in players:
		if p.brain and state == S.RALLY:
			p.brain.update(dt, self)
		elif p.brain and state != S.RALLY and p != server:
			p.move_input = Vector3.ZERO
	match state:
		S.SERVE:
			_update_serve(dt)
		S.POINT:
			point_timer -= dt
			if _wants_replay() and point_timer <= 1.2:
				_start_replay()
			elif point_timer <= 0.0:
				_after_point()
		S.REPLAY:
			_update_replay(dt)
			_update_camera(dt)
			return
	for p in players:
		p.update(dt)
	ball.step(dt)
	world.set_ball(ball.global_position)
	if state == S.RALLY or (state == S.POINT and point_timer > 2.2):
		_record()
	if state == S.RALLY and ball.is_live():
		for p in players:
			p.hittable = false
			if ball.last_team == p.team or ball.position.z * p.side <= 0.0:
				continue
			if p.is_human:
				p.hittable = p.reach_info(ball.global_position)["in"]
			var res := p.try_contact(ball, dt)
			if not res.is_empty():
				_do_hit(p, int(res["type"]), float(res["quality"]), float(res.get("charge", 0.0)),
						String(res.get("style", "")))
				break
	else:
		for hp in humans:
			hp.hittable = false
	if not ball.is_live():
		chance_star.visible = false
	_update_marker()
	_update_camera(dt)


func _update_serve(dt: float) -> void:
	serve_timer += dt
	if serve_phase == 0:
		ball.position = _hand_pos(server)
		if not server.is_human or (autoplay and not keytest):
			server.move_input = Vector3.ZERO
			if serve_timer > (1.6 if not demo else 1.1):
				var r := rng.randf()
				var t := Shots.DRIVE
				if r < 0.22:
					t = Shots.LOB
				elif r < 0.42 and (demo or GameData.difficulty > 0):
					t = Shots.SMASH
				elif r < 0.5:
					t = Shots.DROP
				_do_toss(t)
	elif serve_phase == 1:
		var contact_h := 2.75 if serve_type == Shots.SMASH else 2.45
		if serve_type == Shots.SMASH:
			contact_h = server.y + Player.TOP_REACH + 0.25
		if ball.vel.y < 0.0 and ball.position.y <= contact_h:
			_serve_hit()


func _assign() -> void:
	for team in 2:
		if not ball.is_live() or ball.last_team == team:
			assigned[team] = null
			continue
		var best: Player = null
		var best_s := INF
		for p in team_players(team):
			if p.is_busy():
				continue
			var plan := AIBrain.intercept(p, ball, 0.0)
			var s := 0.0
			if plan.is_empty():
				var lp := ball.landing_point()
				s = 50.0 + Vector2(lp.x - p.position.x, lp.z - p.position.z).length()
			else:
				var st: Vector3 = plan["stand"]
				s = Vector2(st.x - p.position.x, st.z - p.position.z).length()
			if p.is_human:
				s -= 0.8
				if p.pending_shot >= 0:
					s -= 2.0
			if p == assigned[team]:
				s -= 0.35
			if s < best_s:
				best_s = s
				best = p
		assigned[team] = best
		if best and team_human(team) != null and not demo and announced_hit != ball.hit_id:
			announced_hit = ball.hit_id
			if not best.is_human and best.brain and not best.brain.leaving and rng.randf() < 0.6:
				best.say("MINHA!", Color("4fc3ff"))
			elif best.is_human and rng.randf() < 0.2:
				var m := teammate(best)
				if m:
					m.say("SUA!", Color("ffd23f"))


func _update_marker() -> void:
	if state == S.RALLY and ball.is_live() and ball.position.y > 0.4:
		var lp := ball.landing_point()
		marker.visible = true
		marker.global_position = Vector3(lp.x, 0.03, lp.z)
		var col := Color("ff5fa2")
		if lp.z > 0.0:
			col = Color("ffd23f") if (assigned[0] == null or assigned[0].is_human or human == null) else Color("4fc3ff")
		elif team_human(1) != null:
			col = Color("ffd23f") if (assigned[1] == null or assigned[1].is_human) else Color("4fc3ff")
		var out := absf(lp.x) > GameData.COURT_HALF_W or absf(lp.z) > GameData.COURT_HALF_L
		if out:
			col = Color(0.9, 0.9, 0.9)
		col.a = 0.9
		var m := marker.material_override as ShaderMaterial
		m.set_shader_parameter("color", col)
		m.set_shader_parameter("pulse", 1.0)
		marker.scale = Vector3.ONE * lerpf(0.7, 1.3, clampf(ball.position.y / 6.0, 0.0, 1.0))
	else:
		marker.visible = false


# ---------------------------------------------------------------- pontos

func _on_net(pos: Vector3) -> void:
	world.net_hit(pos)
	_stat("net_" + (Shots.NAMES[ball.last_shot] if ball.last_shot >= 0 else "?") + "_" + ball.get_meta("sp", ""))
	if sim and stats.get("netlog", 0) < 12:
		stats["netlog"] = int(stats.get("netlog", 0)) + 1
		print("NET ", ball.get_meta("dbg", ""), " at ", pos)
	sfx("net", 0.0)
	comic(pos + Vector3(0, 0.8, 0), "REDE!", Color("ffffff"), 0.5)


func _on_ball_landed(pos: Vector3) -> void:
	if state != S.RALLY:
		return
	sand_burst(pos, 14)
	sfx("sand", 0.0)
	var in_bounds := absf(pos.x) <= GameData.COURT_HALF_W + 0.06 and absf(pos.z) <= GameData.COURT_HALF_L + 0.06
	var side_team := 0 if pos.z > 0.0 else 1
	var loser := side_team
	var reason := "NA AREIA!"
	if ball.net_touched:
		loser = ball.last_team
		reason = "NA REDE!"
	elif not in_bounds:
		loser = ball.last_team
		reason = "FORA!"
	elif ball.is_serve and rally_hits == 1:
		reason = "ACE!"
	if ball.is_serve and rally_hits == 1 and loser == ball.last_team:
		reason = "FALTA!" if reason == "FORA!" else "SAQUE NA REDE!"
	comic(pos + Vector3(0, 0.7, 0), reason, Color("ffffff") if not in_bounds else Color("ffd23f"), 0.7)
	_stat("end_" + reason)
	if ball.last_shot >= 0:
		_stat("last_" + Shots.NAMES[ball.last_shot] + ("_in" if in_bounds else "_out"))
	_stat("rally_" + str(mini(rally_hits, 10)))
	if sim:
		total_points += 1
		if total_points % 50 == 0:
			print("pontos=", total_points, " ", stats)
		if total_points >= 300:
			print("FINAL ", stats)
			get_tree().quit()
	_award_point(1 - loser, reason)


func _award_point(team: int, reason: String) -> void:
	# replay só quando o ponto foi decidido por um lance bonito
	replay_cool -= 1
	var lh := ball.last_hitter as Player
	var won_by_shot := ball.last_team == team and lh != null
	replay_ok = false
	if won_by_shot and replay_cool <= 0:
		var sty := lh.last_style
		if ball.last_shot == Shots.SPECIAL or sty == "gancho" or highlight >= 4 \
				or (ball.last_shot == Shots.SMASH and rally_hits >= 4) or rally_hits >= 9:
			replay_ok = true
			replay_cool = 2
	if shot_dir != "":
		print("EVT ", shot_n, " PONTO ", reason, " team=", team)
	state = S.POINT
	point_timer = 2.6
	sfx("whistle", -8.0)
	world.whistle()
	world.cheer(1.0)
	if not demo:
		if team == 0:
			sfx("point", -3.0)
			sfx("cheer", -6.0)
			world.ola()
		else:
			sfx("lose_point", -4.0)
			sfx("aww", -8.0)
	energy[team] = minf(1.0, energy[team] + 0.04)
	hud.set_energy(energy)
	for p in players:
		if p.team == team:
			p.celebrate()
		else:
			p.be_sad()
	# câmera de comemoração: close no autor do ponto
	celeb = null
	if ball.last_hitter is Player and (ball.last_hitter as Player).team == team:
		celeb = ball.last_hitter
	else:
		var tp := team_players(team)
		celeb = tp[0] if tp.size() > 0 else null
	if demo:
		celeb = null
	points[team] += 1
	var game_won: bool = points[team] >= 4
	var title := ""
	var sub := ""
	if game_won:
		games[team] += 1
		points = [0, 0]
		serving_team = 1 - serving_team
		server_turn[serving_team] += 1
		if games[team] >= games_to_win:
			match_over = true
			point_timer = 3.0
			title = "GAME, SET E MATCH!"
		else:
			title = "GAME!"
			sub = "%s  %d x %d  %s" % [GameData.TEAMS[0]["name"], games[0], games[1], GameData.TEAMS[1]["name"]]
	else:
		if GameData.mode == "vs" and humans.size() > 1:
			title = "PONTO DO J1!" if team == 0 else "PONTO DO J2!"
		else:
			title = "PONTO NOSSO!" if team == 0 else "PONTO DELES!"
		sub = "%s - %s" % [GameData.POINT_NAMES[mini(points[0], 3)], GameData.POINT_NAMES[mini(points[1], 3)]]
		if points[0] == 3 and points[1] == 3:
			sub = "40-40: PONTO DE OURO!"
	if not demo:
		hud.show_banner(title, sub, Color("ffd23f") if team == 0 else Color("ff4b3e"), 2.0)
	hud.set_score(points, games, serving_team, games_to_win)


func _after_point() -> void:
	if match_over:
		_finish_match()
	else:
		_begin_serve()


# ---------------------------------------------------------------- replay

func _record() -> void:
	var snap := {"b": ball.global_position, "f": ball.flying, "p": []}
	for p in players:
		snap["p"].append([p.position, p.facing, p.body.rotation, p.body.scale, p.rig.cur.duplicate(),
			p.swing_t, p.swing_type])
	rec.append(snap)
	if rec.size() > REC_MAX:
		rec.pop_front()


func _wants_replay() -> bool:
	return replay_ok and not replay_done and not sim and rec.size() > 40


func _start_replay() -> void:
	replay_done = true
	state = S.REPLAY
	replay_from = maxi(0, rec.size() - REPLAY_LEN)
	replay_f = float(replay_from)
	_layout_views()   # replay em tela cheia, mesmo no VS
	hud.set_replay(true)
	var b0: Vector3 = rec[replay_from]["b"]
	replay_cam = Vector3(-10.4, 2.7, clampf(b0.z * 0.7, -6.0, 6.0))
	cam_cut = true
	sfx("swoosh", -6.0, 0.0, 0.7)
	world.cheer(0.6)


func _update_replay(dt: float) -> void:
	replay_f += REPLAY_SPEED * (dt * 60.0)
	if replay_f >= float(rec.size() - 1):
		hud.set_replay(false)
		state = S.POINT
		_layout_views()
		point_timer = 0.0
		_after_point()
		return
	var i := int(replay_f)
	var k := replay_f - float(i)
	var a: Dictionary = rec[i]
	var b: Dictionary = rec[mini(i + 1, rec.size() - 1)]
	for j in players.size():
		var pl := players[j]
		var pa: Array = a["p"][j]
		var pb: Array = b["p"][j]
		pl.position = (pa[0] as Vector3).lerp(pb[0], k)
		pl.facing = lerp_angle(float(pa[1]), float(pb[1]), k)
		pl.rotation.y = pl.facing
		pl.body.rotation = pa[2]
		pl.body.scale = pa[3]
		pl.rig.apply(pa[4], 1.0)
		pl.swing_t = pa[5]
		pl.swing_type = pa[6]
		pl._update_trail()
		pl.shadow.global_position = Vector3(pl.position.x + 0.12, 0.015, pl.position.z + 0.08)
	var bp := (a["b"] as Vector3).lerp(b["b"], k)
	ball.show_replay(bp, a["b"], bool(a["f"]))
	world.set_ball(bp)


func _finish_match() -> void:
	if demo:
		_reset_score(3)
		_begin_serve()
		return
	state = S.END
	if sim:
		_stat("match_won" if games[0] > games[1] else "match_lost")
		start_match.call_deferred()
		return
	var won: bool = games[0] > games[1]
	sfx("win" if won else "lose", -2.0)
	if won:
		sfx("cheer", -4.0)
		world.ola()
	hud.show_end(won, games, GameData.mode == "vs" and humans.size() > 1)
	for p in players:
		if (p.team == 0) == won:
			p.celebrate()
		else:
			p.be_sad()


# ---------------------------------------------------------------- câmera

func _smooth(cur: Vector3, target: Vector3, v: Vector3, smooth_time: float, dt: float) -> Array:
	# mola criticamente amortecida (sem tranco e sem passar do ponto)
	var omega := 2.0 / maxf(smooth_time, 0.0001)
	var x := omega * dt
	var ex := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - target
	var temp := (v + change * omega) * dt
	v = (v - temp * omega) * ex
	return [target + (change + temp) * ex, v]


func _update_camera(dt: float) -> void:
	fov_kick = lerpf(fov_kick, 0.0, 1.0 - exp(-5.0 * dt))
	var off := Vector3.ZERO
	if shake > 0.0:
		shake = maxf(shake - dt, 0.0)
		var sh := shake * shake * 0.8
		off = Vector3(rng.randf_range(-sh, sh), rng.randf_range(-sh, sh), 0.0)
	var n := 2 if split_active() else 1
	for vi in n:
		var v: Dictionary = views[vi]
		var viewer: Player = human
		if vi == 1 and humans.size() > 1:
			viewer = humans[1]
		_update_view(v, viewer, dt, off, n > 1)
	cam_pos = views[0]["pos"]


func _mirror(p: Vector3, s: float) -> Vector3:
	return Vector3(p.x * s, p.y, p.z * s)


func _update_view(v: Dictionary, viewer: Player, dt: float, off: Vector3, split: bool) -> void:
	var c: Camera3D = v["cam"]
	var target_pos: Vector3
	var target_look: Vector3
	var base_fov := 54.0
	var smooth_t := 0.35
	var s := viewer.side if viewer else 1.0
	c.h_offset = lerpf(c.h_offset, -3.0 if demo and state != S.REPLAY else 0.0, 1.0 - exp(-5.0 * dt))
	if state == S.REPLAY:
		var bp := ball.global_position
		replay_cam = replay_cam.lerp(Vector3(-10.4, 2.7 + bp.y * 0.15, clampf(bp.z * 0.7, -6.0, 6.0)), 1.0 - exp(-2.5 * dt))
		target_pos = replay_cam
		target_look = Vector3(bp.x * 0.4, 0.9 + bp.y * 0.3, bp.z * 0.85)
		base_fov = 44.0
		smooth_t = 0.25
	elif demo:
		var shot := int(time / 7.0) % 3
		var a := time * 0.12
		match shot:
			0:
				target_pos = Vector3(sin(a) * 4.0, 6.2, 13.5)
				target_look = Vector3(ball.position.x * 0.25, 1.0, -1.5)
			1:
				target_pos = Vector3(-9.5, 2.0, clampf(ball.position.z * 0.6, -5.0, 5.0) + 2.0)
				target_look = Vector3(ball.position.x * 0.3, 1.4, ball.position.z * 0.7)
				base_fov = 48.0
			_:
				target_pos = Vector3(cos(a) * 3.0, 8.5, -15.0)
				target_look = Vector3(0, 0.8, 1.0)
		smooth_t = 0.9
	elif state == S.POINT and celeb != null and point_timer < 2.2:
		var cc := celeb.global_position
		var sx := signf(cc.x) if absf(cc.x) > 0.3 else 1.0
		var dir := Vector3(sx * 0.75, 0.0, -celeb.side * 0.66).normalized()
		target_pos = cc + dir * 3.9 + Vector3(0, 1.35, 0)
		if target_pos.z * celeb.side < 0.9:
			target_pos.z = celeb.side * 0.9
		target_look = cc + Vector3(0, 1.1, 0)
		base_fov = 48.0
		smooth_t = 0.5
		if not v["cut"] and (v["pos"] as Vector3).distance_to(target_pos) > 6.0:
			v["cut"] = true
	elif state == S.SERVE and server == viewer and viewer != null:
		# por cima do ombro de quem saca (no referencial do lado dele)
		var c2 := _mirror(server.global_position, s)
		target_pos = _mirror(c2 + Vector3(1.4, 2.6, 4.3), s)
		target_look = _mirror(Vector3(c2.x * 0.3, 1.0, -6.0), s)
		base_fov = 52.0
		smooth_t = 0.45
	elif state == S.END:
		target_pos = _mirror(Vector3(0, 3.2, 11.5), s)
		target_look = _mirror(Vector3(0, 1.2, 3.0), s)
		base_fov = 46.0
		smooth_t = 0.8
	else:
		# rali: enquadra o(s) jogador(es) e a bola, antecipando para onde a bola vai
		var hp := Vector3(0, 0, 6.0)
		if viewer:
			hp = _mirror(viewer.position, s)
			if GameData.mode == "coop" and humans.size() > 1 and not split:
				hp = (hp + _mirror(humans[1].position, s)) * 0.5
		var ahead := ball.global_position
		if ball.is_live():
			ahead = ball.global_position.lerp(ball.predict(0.45), 0.6)
		ahead = _mirror(ahead, s)
		var fx := clampf(lerpf(hp.x, ahead.x, 0.4), -3.5, 3.5)
		var lift := clampf((ahead.y - 3.5) * 0.28, 0.0, 1.6)
		var back := clampf((hp.z - 3.5) / 5.0, 0.0, 1.0)
		v["back"] = lerpf(float(v["back"]), back, 1.0 - exp(-2.5 * dt))
		var cb: float = v["back"]
		var far_side := clampf(-ahead.z / 8.0, 0.0, 1.0) if ahead.z < 0.0 else 0.0
		var zz := lerpf(11.4, 14.6, cb) + (1.2 if split else 0.0)
		target_pos = _mirror(Vector3(fx * 0.55, lerpf(4.7, 6.0, cb) + lift + (0.4 if split else 0.0), zz), s)
		target_look = _mirror(Vector3(fx * 0.4, lerpf(1.35, 1.0, cb) + lift * 0.6,
				lerpf(-3.0, -2.0, cb) - far_side * 1.2), s)
		base_fov = 54.0 - far_side * 2.0
		if intro_t < 2.4:
			var k := smoothstep(0.0, 2.4, intro_t)
			target_pos = _mirror(Vector3(0, 22, -46), s).lerp(target_pos, k)
			target_look = _mirror(Vector3(0, 1.5, -6), s).lerp(target_look, k)
			smooth_t = 0.05
	if cam_cut:
		for vv in views:
			vv["cut"] = true
		cam_cut = false
	if v["cut"]:
		v["cut"] = false
		v["pos"] = target_pos
		v["look"] = target_look
		v["vel"] = Vector3.ZERO
		v["lvel"] = Vector3.ZERO
	var r1 := _smooth(v["pos"], target_pos, v["vel"], smooth_t, dt)
	v["pos"] = r1[0]
	v["vel"] = r1[1]
	var r2 := _smooth(v["look"], target_look, v["lvel"], smooth_t * 0.8, dt)
	v["look"] = r2[0]
	v["lvel"] = r2[1]
	c.fov = lerpf(c.fov, base_fov + fov_kick, 1.0 - exp(-10.0 * dt))
	c.look_at_from_position((v["pos"] as Vector3) + off, (v["look"] as Vector3) + off * 0.5)

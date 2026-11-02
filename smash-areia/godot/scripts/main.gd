extends Node3D
## Smash na Areia - controlador da partida.
## Regras de beach tennis: a bola não pode tocar a areia, um toque por dupla,
## saque único, contagem de tênis com "ponto de ouro" no 40-40.
## Camada arcade: golpes com efeito, golpe carregado, estrelas de chance,
## barra de energia e super golpe de cada personagem.

enum S { SERVE, RALLY, POINT, END }

var state := S.SERVE
var time := 0.0
var demo := true
var rng := RandomNumberGenerator.new()

var world: World
var ball: Ball
var cam: Camera3D
var hud: Hud
var players: Array[Player] = []
var human: Player = null
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
	cam = Camera3D.new()
	cam.fov = 54
	cam.far = 1000
	add_child(cam)
	cam.current = true
	ball = Ball.new()
	add_child(ball)
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
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8)
		elif a.begins_with("--shotdt="):
			shot_dt = float(a.substr(9))
		elif a.begins_with("--shotmax="):
			shot_max = int(a.substr(10))
		elif a.begins_with("--char="):
			GameData.char_index = int(a.substr(7))
		elif a.begins_with("--diff="):
			GameData.difficulty = int(a.substr(7))
		elif a.begins_with("--portrait="):
			_portrait.call_deferred(a.substr(11))
	if autoplay:
		start_match.call_deferred()


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
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _process(dt: float) -> void:
	if keytest and not demo:
		_keytest_step()
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
	var actions := ["shot_drive", "shot_lob", "shot_drop", "shot_smash", "jump", "dive", "move_left", "super"]
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
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"shot_drive": [KEY_J], "shot_lob": [KEY_K], "shot_drop": [KEY_L], "shot_smash": [KEY_I],
		"super": [KEY_U], "jump": [KEY_SPACE], "dive": [KEY_SHIFT], "pause": [KEY_ESCAPE, KEY_P],
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


func screen_pos(p: Vector3) -> Vector2:
	if cam.is_position_behind(p):
		return get_viewport().get_visible_rect().size * 0.5
	return cam.unproject_position(p)


## Letreiro pequeno (sem atrapalhar a visão da bola)
func comic(p: Vector3, text: String, color: Color, size := 0.6, star := true) -> void:
	hud.fx.pop(screen_pos(p), text, color, size, star)


# ---------------------------------------------------------------- fluxo

func go_menu() -> void:
	get_tree().paused = false
	demo = true
	_spawn_players(false)
	_reset_score(3)
	hud.show_menu()
	cam_cut = true
	_begin_serve()


func start_match() -> void:
	demo = false
	_spawn_players(true)
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
	human = null
	var ci: int = GameData.char_index if with_human else rng.randi() % 4
	var order := [ci, (ci + 1) % 4, (ci + 2) % 4, (ci + 3) % 4]
	var diff: Dictionary = GameData.DIFFICULTIES[GameData.difficulty if with_human else 1]
	for i in 4:
		var team := 0 if i < 2 else 1
		var p := Player.new()
		add_child(p)
		var is_h := with_human and i == 0
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
			human = p
			if autoplay:
				p.brain = AIBrain.new(p, GameData.DIFFICULTIES[1])
		players.append(p)


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
	assigned = [null, null]
	chance = {}
	chance_star.visible = false
	celeb = null
	cam_cut = true
	var tp := team_players(serving_team)
	if not demo and serving_team == 0:
		server = human
	else:
		server = tp[server_turn[serving_team] % tp.size()]
	var lane := 1.0 if (points[0] + points[1]) % 2 == 0 else -1.0
	for p in players:
		p.reset_state()
		p.lock_x = false
		var ps := 1.0 if p.team == 0 else -1.0
		if p == server:
			p.position = Vector3(lane * 1.6 * ps, 0, ps * 8.7)
			p.serve_mode = true
			if p.is_human:
				p.lock_x = true
				p.locked_z = p.position.z
		elif p.team == serving_team:
			p.position = Vector3(-lane * 1.7 * ps, 0, ps * 3.0)
		else:
			p.position = Vector3(p.home_x, 0, ps * 5.6)
		if p.brain:
			p.brain.move_target = p.position
			p.brain.plan = {}
	ball.reset_to(server.position + Vector3(0, 1.2, 0))
	ball.held_by = server
	ball.last_team = serving_team
	if points[0] == 3 and points[1] == 3:
		hud.show_banner("PONTO DE OURO!", "quem fizer leva o game", Color("ff4b3e"), 1.6)
	if not demo:
		hud.set_hint("SEU SAQUE: escolha um golpe (SMASH = saque viagem)" if server == human else "")
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
	if type == Shots.SMASH:
		server.jump_timer = 0.32
	hud.set_hint("")
	sfx("swoosh", -10.0)


func _serve_hit() -> void:
	var type := serve_type
	var aim := Vector2.ZERO
	if server.is_human and not autoplay:
		aim = _human_aim()
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
	server._start_swing(Shots.SMASH, ball.position)
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
	announced_hit = -1
	assign_t = 0.0
	var pos := ball.global_position
	var head := p.global_position + Vector3(0, 2.7, 0)
	var col: Color = Shots.COLORS[shot]
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
		Input.vibrate_handheld(35 if shot != Shots.SMASH and shot != Shots.SPECIAL else 90)
	chance = {}
	chance_star.visible = false


func _do_hit(p: Player, type: int, quality: float, charge: float) -> void:
	var incoming_speed := ball.vel.length()
	var shot := type
	# recebeu um super golpe: é empurrado e só consegue defender
	if ball.special != "" and shot != Shots.SPECIAL:
		var resist := quality > 0.92 and rng.randf() < 0.35
		if not resist:
			p.knockback(Vector3(ball.vel.x, 0, ball.vel.z), 1.0)
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
		aim = _human_aim()
		if hud.touch.joy_vec.length() < 0.25 and _key_vec().length() < 0.25:
			aim.x = _auto_aim_x(p)
		err = 0.9
	elif p.brain:
		aim = p.brain.choose_aim(self, shot)
		err = float(p.brain.diff["error"])
	var extra := {"charge": charge, "chance": is_chance, "special": String(p.data.get("special", ""))}
	var res := Shots.compute(shot, ball.global_position, -p.side, aim, quality,
			float(p.data["power"]), float(p.data["control"]), err, rng, extra)
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


func _human_aim() -> Vector2:
	var v := hud.touch.joy_vec
	if _key_vec().length() > v.length():
		v = _key_vec()
	return Vector2(v.x, -v.y)


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
	if demo or human == null or get_tree().paused:
		return
	if state == S.SERVE and server == human:
		_do_toss(type)
		return
	if state != S.RALLY:
		return
	human.request_shot(type)


func _on_super_button() -> void:
	if demo or human == null or state != S.RALLY or energy[0] < 1.0:
		return
	human.request_shot(Shots.SPECIAL)
	if human.data.get("special", "") == "meteoro" and human.on_ground():
		human.jump_boost = 1.45
		if human.jump_timer < 0.0:
			human.jump_timer = 0.05
	sfx("swoosh", -2.0, 0.0, 1.3)


func _on_dive_button() -> void:
	if demo or human == null or state != S.RALLY:
		return
	var dir := Vector3(hud.touch.joy_vec.x, 0, hud.touch.joy_vec.y)
	var kv := _key_vec()
	if kv.length() > 0.2:
		dir = Vector3(kv.x, 0, kv.y)
	if dir.length() < 0.2 and ball.is_live():
		var lp := ball.landing_point()
		dir = Vector3(lp.x - human.position.x, 0, lp.z - human.position.z)
	human.request_dive(dir)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not demo and state != S.END:
		hud._on_pause()
	if demo or human == null:
		return
	for pair in [["shot_drive", Shots.DRIVE], ["shot_lob", Shots.LOB], ["shot_drop", Shots.DROP], ["shot_smash", Shots.SMASH]]:
		if event.is_action_pressed(pair[0]):
			hud.touch.flash_button(pair[1])
			_on_shot_button(pair[1])
	if event.is_action_pressed("super"):
		_on_super_button()
	if event.is_action_pressed("jump") and state == S.RALLY:
		human.request_jump()
	if event.is_action_pressed("dive"):
		_on_dive_button()


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
	if human and not demo and not autoplay:
		var v := hud.touch.joy_vec
		var kv := _key_vec()
		if kv.length() > v.length():
			v = kv
		if v.length() > 1.0:
			v = v.normalized()
		if state == S.SERVE and server == human:
			v.y = 0.0
		human.move_input = Vector3(v.x, 0, v.y) if state != S.POINT else Vector3.ZERO
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
			if point_timer <= 0.0:
				if match_over:
					_finish_match()
				else:
					_begin_serve()
	for p in players:
		p.update(dt)
	ball.step(dt)
	world.set_ball(ball.global_position)
	if state == S.RALLY and ball.is_live():
		for p in players:
			p.hittable = false
			if ball.last_team == p.team or ball.position.z * p.side <= 0.0:
				continue
			if p.is_human:
				p.hittable = p.reach_info(ball.global_position)["in"]
			var res := p.try_contact(ball, dt)
			if not res.is_empty():
				_do_hit(p, int(res["type"]), float(res["quality"]), float(res.get("charge", 0.0)))
				break
	elif human:
		human.hittable = false
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
		if best and team == 0 and not demo and announced_hit != ball.hit_id:
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
			col = Color("ffd23f") if (assigned[0] == human or human == null) else Color("4fc3ff")
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
		title = "PONTO NOSSO!" if team == 0 else "PONTO DELES!"
		sub = "%s - %s" % [GameData.POINT_NAMES[mini(points[0], 3)], GameData.POINT_NAMES[mini(points[1], 3)]]
		if points[0] == 3 and points[1] == 3:
			sub = "40-40: PONTO DE OURO!"
	if not demo:
		hud.show_banner(title, sub, Color("ffd23f") if team == 0 else Color("ff4b3e"), 2.0)
	hud.set_score(points, games, serving_team, games_to_win)


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
	hud.show_end(won, games)
	for p in players:
		if (p.team == 0) == won:
			p.celebrate()
		else:
			p.be_sad()


# ---------------------------------------------------------------- câmera

func _update_camera(dt: float) -> void:
	var target_pos: Vector3
	var target_look: Vector3
	var base_fov := 54.0
	var follow := 5.0
	cam.h_offset = lerpf(cam.h_offset, -3.0 if demo else 0.0, 1.0 - exp(-5.0 * dt))
	if demo:
		# menu: planos de TV que se alternam
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
		follow = 2.0
	elif state == S.POINT and celeb != null and point_timer < 2.2:
		# close na comemoração
		var c := celeb.global_position
		# de frente-lateral, sempre do lado do jogador (nunca atrás da rede)
		var sx := signf(c.x) if absf(c.x) > 0.3 else 1.0
		var dir := Vector3(sx * 0.75, 0.0, -celeb.side * 0.66).normalized()
		target_pos = c + dir * 3.9 + Vector3(0, 1.35, 0)
		if target_pos.z * celeb.side < 0.9:
			target_pos.z = celeb.side * 0.9
		target_look = c + Vector3(0, 1.1, 0)
		base_fov = 48.0
		if not cam_cut and cam_pos.distance_to(target_pos) > 6.0:
			cam_cut = true
	elif state == S.SERVE and server == human:
		# por cima do ombro de quem saca
		var c2 := server.global_position
		target_pos = c2 + Vector3(1.4, 2.6, 4.3)
		target_look = Vector3(c2.x * 0.3, 1.0, -6.0)
		base_fov = 52.0
	elif state == S.END:
		target_pos = Vector3(0, 3.2, 11.5)
		target_look = Vector3(0, 1.2, 3.0)
		base_fov = 46.0
	else:
		var fx := 0.0
		if human:
			fx = lerpf(human.position.x, ball.position.x, 0.4)
		fx = clampf(fx, -3.5, 3.5)
		var lift := clampf((ball.position.y - 4.0) * 0.3, 0.0, 1.5)
		var hz := human.position.z if human else 6.0
		var back := clampf((hz - 3.5) / 5.0, 0.0, 1.0)
		cam_back = lerpf(cam_back, back, 1.0 - exp(-3.0 * dt))
		target_pos = Vector3(fx * 0.55, lerpf(4.7, 6.0, cam_back) + lift, lerpf(11.4, 14.6, cam_back))
		target_look = Vector3(fx * 0.38, lerpf(1.35, 1.0, cam_back) + lift * 0.6, lerpf(-3.0, -2.0, cam_back))
		# entrada cinematográfica no começo da partida
		if intro_t < 2.4:
			var k := smoothstep(0.0, 2.4, intro_t)
			target_pos = Vector3(0, 22, -46).lerp(target_pos, k)
			target_look = Vector3(0, 1.5, -6).lerp(target_look, k)
			follow = 30.0
	if cam_cut:
		cam_cut = false
		cam_pos = target_pos
		cam_look = target_look
	var k2 := 1.0 - exp(-follow * dt)
	cam_pos = cam_pos.lerp(target_pos, k2)
	cam_look = cam_look.lerp(target_look, k2)
	fov_kick = lerpf(fov_kick, 0.0, 1.0 - exp(-5.0 * dt))
	cam.fov = lerpf(cam.fov, base_fov + fov_kick, 1.0 - exp(-12.0 * dt))
	var off := Vector3.ZERO
	if shake > 0.0:
		shake = maxf(shake - dt, 0.0)
		var s := shake * shake * 0.8
		off = Vector3(rng.randf_range(-s, s), rng.randf_range(-s, s), 0.0)
	cam.look_at_from_position(cam_pos + off, cam_look + off * 0.5)

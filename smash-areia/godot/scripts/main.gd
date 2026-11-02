extends Node3D
## Smash na Areia - controlador da partida.
## Regras de beach tennis: a bola não pode tocar a areia, um toque por dupla,
## saque único, contagem de tênis com "ponto de ouro" no 40-40.

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
var serve_phase := 0          # 0 segurando, 1 bola no ar
var serve_type := -1
var serve_timer := 0.0
var serve_aim := Vector2.ZERO
var point_timer := 0.0
var match_over := false
var assigned: Array = [null, null]
var assign_t := 0.0
var announced_hit := -1
var shake := 0.0
var hitstop := 0.0
var slowmo := 0.0
var cam_pos := Vector3(0, 8, 17)
var cam_look := Vector3.ZERO
var cam_back := 1.0
var rally_hits := 0

var sfx_players: Array[AudioStreamPlayer] = []
var sfx_next := 0
var sounds := {}
var music: AudioStreamPlayer
var waves: AudioStreamPlayer
var sand_small: Array[CPUParticles3D] = []
var sand_big: Array[CPUParticles3D] = []
var sand_i := 0

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
	cam.fov = 50
	cam.far = 900
	add_child(cam)
	cam.current = true
	ball = Ball.new()
	add_child(ball)
	ball.landed.connect(_on_ball_landed)
	ball.touched_net.connect(_on_net)
	marker = Toon.blob(1.0, Color(1, 0.9, 0.2, 0.9), true)
	add_child(marker)
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
	p.side = -1.0   # olha para a câmera
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


func _process(_dt: float) -> void:
	if keytest and not demo:
		_keytest_step()
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
	var actions := ["shot_drive", "shot_lob", "shot_drop", "shot_smash", "jump", "dive", "move_left"]
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
		"jump": [KEY_SPACE], "dive": [KEY_SHIFT], "pause": [KEY_ESCAPE, KEY_P],
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


func sfx(n: String, db := 0.0, pitch_var := 0.08) -> void:
	if not sounds.has(n):
		return
	var p := sfx_players[sfx_next]
	sfx_next = (sfx_next + 1) % sfx_players.size()
	p.stream = sounds[n]
	p.volume_db = db
	p.pitch_scale = 1.0 + rng.randf_range(-pitch_var, pitch_var)
	p.play()


func _setup_particles() -> void:
	var grain := SphereMesh.new()
	grain.radius = 0.05
	grain.height = 0.1
	grain.radial_segments = 6
	grain.rings = 3
	var mat := Toon.make(Color("f5d39a"), {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
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
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0))
		p.scale_amount_curve = curve
		add_child(p)
		if big:
			sand_big.append(p)
		else:
			sand_small.append(p)


func sand_burst(pos: Vector3, n: int) -> void:
	var pool := sand_big if n >= 8 else sand_small
	var p := pool[sand_i % pool.size()]
	sand_i += 1
	p.global_position = Vector3(pos.x, 0.05, pos.z)
	p.restart()
	p.emitting = true


func screen_pos(p: Vector3) -> Vector2:
	if cam.is_position_behind(p):
		return get_viewport().get_visible_rect().size * 0.5
	var sp := cam.unproject_position(p)
	# o HUD usa as coordenadas do canvas (stretch), que são as mesmas da viewport aqui
	return sp


func comic(p: Vector3, text: String, color: Color, size := 1.0) -> void:
	hud.fx.pop(screen_pos(p), text, color, size)


# ---------------------------------------------------------------- fluxo

func go_menu() -> void:
	get_tree().paused = false
	demo = true
	_spawn_players(false)
	_reset_score(3)
	hud.show_menu()
	_begin_serve()


func start_match() -> void:
	demo = false
	_spawn_players(true)
	_reset_score(GameData.LENGTHS[GameData.length_index]["games"])
	hud.show_game()
	hud.show_banner("VAI COMEÇAR!", "%s x %s" % [GameData.TEAMS[0]["name"], GameData.TEAMS[1]["name"]], Color("ffd23f"), 1.6)
	sfx("whistle", -6.0)
	_begin_serve()


func _reset_score(target: int) -> void:
	points = [0, 0]
	games = [0, 0]
	games_to_win = target
	serving_team = 0
	server_turn = [0, 0]
	match_over = false
	hud.set_score(points, games, serving_team, games_to_win)


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
				d = GameData.DIFFICULTIES[1]   # o parceiro joga no nível médio
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
		# o parceiro vai na bola: cobre o outro lado
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
			Shots.SMASH, Shots.DROP:
				z = 3.1
		if ball.is_live() and ball.last_shot == Shots.LOB:
			var lp := ball.landing_point()
			if absf(lp.z) < 5.5:
				z = 5.7   # lob curto: o adversário pode cravar
	var x := p.home_x * 0.95 + ball.position.x * 0.3
	return Vector3(clampf(x, -3.6, 3.6), 0.0, s * z)


func _begin_serve() -> void:
	state = S.SERVE
	serve_phase = 0
	serve_timer = 0.0
	serve_type = -1
	rally_hits = 0
	assigned = [null, null]
	var tp := team_players(serving_team)
	if not demo and serving_team == 0:
		server = human
	else:
		server = tp[server_turn[serving_team] % tp.size()]
	var sgn := 1.0 if serving_team == 0 else -1.0
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
		if server == human:
			hud.set_hint("SEU SAQUE: escolha um golpe  (FORTE • LOB • CURTA • SMASH = saque viagem)")
		else:
			hud.set_hint("")
	hud.set_score(points, games, serving_team, games_to_win)


func _hand_pos(p: Player) -> Vector3:
	return p.global_position + p.global_transform.basis * Vector3(0.38, 1.25, 0.25)


func _do_toss(type: int) -> void:
	if serve_phase != 0:
		return
	serve_phase = 1
	serve_type = type
	serve_timer = 0.0
	ball.held_by = null
	ball.position = _hand_pos(server)
	ball.vel = Vector3(0, 5.2 if type == Shots.SMASH else 4.6, 0)
	ball.flying = true
	ball.dead = true
	server.pending_shot = Shots.SMASH
	server.pending_t = 5.0
	if type == Shots.SMASH:
		server.jump_timer = 0.32
	hud.set_hint("")
	sfx("swoosh", -10.0)


func _serve_hit() -> void:
	var type := serve_type
	var aim := Vector2.ZERO
	if server.is_human:
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
	_launch(server, shot, res, quality)
	ball.is_serve = true
	server.serve_mode = false
	server.lock_x = false
	state = S.RALLY


func _launch(p: Player, shot: int, res: Dictionary, quality: float) -> void:
	ball.dead = false
	ball.is_serve = false
	ball.launch(res["velocity"], p.team, p, shot)
	rally_hits += 1
	if shot_dir != "":
		print("EVT ", shot_n, " ", res["label"], " team=", p.team, " human=", p.is_human, " q=", snappedf(quality, 0.01))
	_stat("shot_" + Shots.NAMES[shot] + ("_serve" if state == S.SERVE else ""))
	announced_hit = -1
	assign_t = 0.0
	var pos := ball.global_position
	match shot:
		Shots.SMASH:
			sfx("smash", 0.0)
			shake = 0.45
			hitstop = 0.07
			slowmo = 0.0
			hud.fx.smash_lines(screen_pos(pos))
			comic(pos + Vector3(0, 0.4, 0), res["label"] if res["label"] != "SMASH" else "POW!", Color("ff4b3e"), 1.25)
			world.cheer(0.7)
		Shots.LOB:
			sfx("lob", -2.0)
			if rng.randf() < 0.6 or p.is_human:
				comic(pos + Vector3(0, 0.4, 0), "LOB!", Color("4fc3ff"), 0.8)
		Shots.DROP:
			sfx("drop", -2.0)
			comic(pos + Vector3(0, 0.4, 0), "CURTINHA!", Color("7dff6b"), 0.8)
		Shots.DEFENSE:
			sfx("defense", 0.0)
			comic(pos + Vector3(0, 0.4, 0), "DEFESA!", Color("ffffff"), 1.0)
			world.cheer(0.5)
		_:
			sfx("hit", 0.0)
			if quality > 0.85 and (p.is_human or rng.randf() < 0.3):
				comic(pos + Vector3(0, 0.4, 0), "TÓIM!", Color("ffd23f"), 0.8)
	if p.is_human and quality > 0.88 and shot != Shots.SMASH:
		hud.fx.pop(screen_pos(pos) + Vector2(0, -90), "PERFEITO!", Color("ffd23f"), 0.6, false)
	if p.is_human:
		Input.vibrate_handheld(40 if shot != Shots.SMASH else 90)


func _do_hit(p: Player, type: int, quality: float) -> void:
	var incoming_speed := ball.vel.length()
	var shot := type
	if incoming_speed > 16.5 and (shot == Shots.DRIVE or shot == Shots.DROP):
		shot = Shots.DEFENSE
	if shot == Shots.LOB and incoming_speed > 16.5:
		quality *= 0.85
	var aim := Vector2.ZERO
	var err := 1.0
	if p.is_human:
		aim = _human_aim()
		if hud.touch.joy_vec.length() < 0.25 and _key_vec().length() < 0.25:
			aim.x = _auto_aim_x(p)
		err = 0.9
	else:
		aim = p.brain.choose_aim(self, shot)
		err = float(p.brain.diff["error"])
	var res := Shots.compute(shot, ball.global_position, -p.side, aim, quality,
			float(p.data["power"]), float(p.data["control"]), err, rng)
	_launch(p, shot, res, quality)


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
	# entrada humana
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
	# IA
	if state == S.RALLY:
		assign_t -= dt
		if assign_t <= 0.0:
			_assign()
			assign_t = 0.12
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
		S.END:
			pass
	for p in players:
		p.update(dt)
	ball.step(dt)
	if state == S.RALLY and ball.is_live():
		for p in players:
			p.hittable = false
			if ball.last_team == p.team or ball.position.z * p.side <= 0.0:
				continue
			if p.is_human:
				var info := p.reach_info(ball.global_position)
				p.hittable = info["in"]
			var res := p.try_contact(ball, dt)
			if not res.is_empty():
				_do_hit(p, int(res["type"]), float(res["quality"]))
				break
	elif human:
		human.hittable = false
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
		# o parceiro avisa
		if best and team == 0 and not demo and announced_hit != ball.hit_id:
			announced_hit = ball.hit_id
			if not best.is_human and best.brain and not best.brain.leaving and rng.randf() < 0.7:
				best.say("MINHA!", Color("4fc3ff"))
			elif best.is_human and rng.randf() < 0.25:
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
		var s := lerpf(0.7, 1.3, clampf(ball.position.y / 6.0, 0.0, 1.0))
		marker.scale = Vector3.ONE * s
	else:
		marker.visible = false


# ---------------------------------------------------------------- pontos

func _on_net(pos: Vector3) -> void:
	sfx("net", 0.0)
	comic(pos + Vector3(0, 0.5, 0), "REDE!", Color("ffffff"), 0.9)


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
	comic(pos + Vector3(0, 0.6, 0), reason, Color("ffffff") if not in_bounds else Color("ffd23f"), 1.15)
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


func _award_point(team: int, _reason: String) -> void:
	if shot_dir != "":
		print("EVT ", shot_n, " PONTO ", _reason, " team=", team)
	state = S.POINT
	point_timer = 2.3
	sfx("whistle", -8.0)
	world.cheer(1.0)
	if demo:
		pass
	elif team == 0:
		sfx("point", -3.0)
		sfx("cheer", -6.0)
	else:
		sfx("lose_point", -4.0)
		sfx("aww", -8.0)
	for p in players:
		if p.team == team:
			p.celebrate()
		else:
			p.be_sad()
	points[team] += 1
	var game_won: bool = points[team] >= 4   # 40-40 = ponto de ouro (sem vantagem)
	var title := ""
	var sub := ""
	if game_won:
		games[team] += 1
		points = [0, 0]
		serving_team = 1 - serving_team
		server_turn[serving_team] += 1
		if games[team] >= games_to_win:
			match_over = true
			point_timer = 2.8
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
		var col := Color("ffd23f") if team == 0 else Color("ff4b3e")
		hud.show_banner(title, sub, col, 1.9)
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
	cam.h_offset = lerpf(cam.h_offset, -3.4 if demo else 0.0, 1.0 - exp(-5.0 * dt))
	if demo:
		var a := time * 0.15
		target_pos = Vector3(sin(a) * 4.5, 6.8 + sin(a * 0.7) * 0.6, 14.5 + cos(a) * 1.5)
		target_look = Vector3(ball.position.x * 0.25, 0.8, -1.0)
	else:
		var fx := 0.0
		if human:
			fx = lerpf(human.position.x, ball.position.x, 0.4)
		fx = clampf(fx, -3.5, 3.5)
		var lift := clampf((ball.position.y - 4.0) * 0.25, 0.0, 1.2)
		# câmera de perto no rali, recua quando o jogador vai para o fundo/saque
		var hz := human.position.z if human else 6.0
		var back := clampf((hz - 4.0) / 4.7, 0.0, 1.0)
		if state == S.SERVE and server == human:
			back = 1.0
		cam_back = lerpf(cam_back, back, 1.0 - exp(-3.0 * dt))
		var cz := lerpf(13.2, 16.6, cam_back)
		var cy := lerpf(5.9, 7.4, cam_back)
		target_pos = Vector3(fx * 0.55, cy + lift, cz)
		target_look = Vector3(fx * 0.4, lerpf(1.0, 0.6, cam_back) + lift * 0.6, lerpf(-1.6, -0.8, cam_back))
		if state == S.END:
			target_pos = Vector3(0, 4.5, 12.0)
			target_look = Vector3(0, 1.0, 3.0)
	var k := 1.0 - exp(-4.0 * dt)
	cam_pos = cam_pos.lerp(target_pos, k)
	cam_look = cam_look.lerp(target_look, k)
	var off := Vector3.ZERO
	if shake > 0.0:
		shake = maxf(shake - dt, 0.0)
		var s := shake * shake * 0.9
		off = Vector3(rng.randf_range(-s, s), rng.randf_range(-s, s), 0.0)
	cam.look_at_from_position(cam_pos + off, cam_look + off * 0.5)

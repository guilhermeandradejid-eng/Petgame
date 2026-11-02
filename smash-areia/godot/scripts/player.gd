class_name Player
extends Node3D
## Jogador de beach tennis: movimento na areia, pulo, mergulho, golpes e
## animação procedural das partes do boneco modelado no Blender.

enum State { NORMAL, DIVE, RECOVER, CELEBRATE, SAD }

const CHAR_SCENE := preload("res://assets/models/character.glb")
const FONT := preload("res://assets/fonts/Bangers.woff")
const BASE_SPEED := 6.4
const REACH := 1.25
const TOP_REACH := 2.3
const JUMP_V := 5.6
const GRAV := 16.0
const PENDING_WINDOW := 0.5
const STRIKE_TIME := 0.26

var team := 0
var side := 1.0               # +1 = lado z>0 (time da câmera), -1 = lado adversário
var home_x := 1.8
var is_human := false
var data: Dictionary = {}
var game: Node = null
var brain: AIBrain = null
var diff_speed := 1.0

var vel := Vector3.ZERO
var y := 0.0
var vy := 0.0
var move_input := Vector3.ZERO
var state := State.NORMAL
var state_t := 0.0
var facing := 0.0
var dive_dir := Vector3.ZERO
var lock_x := false           # durante o saque o jogador só anda de lado
var locked_z := 0.0

# golpe
var pending_shot := -1
var pending_t := 0.0
var best_dist := INF
var swing_type := -1
var swing_t := 1.0
var swing_side := 1.0
var jump_timer := -1.0
var serve_mode := false

# visual
var model: Node3D
var body: Node3D
var parts := {}
var run_phase := 0.0
var squash := 1.0
var squash_v := 0.0
var anim_time := 0.0
var bubble: Label3D
var bubble_t := 0.0
var shadow: MeshInstance3D
var zone_ring: MeshInstance3D
var hittable := false
var footstep_t := 0.0


func setup(char_data: Dictionary, team_index: int, human: bool) -> void:
	data = char_data
	team = team_index
	side = 1.0 if team == 0 else -1.0
	is_human = human
	_build_model()


func _build_model() -> void:
	body = Node3D.new()
	add_child(body)
	model = CHAR_SCENE.instantiate()
	model.scale = Vector3.ONE * GameData.CHAR_SCALE
	body.add_child(model)
	var orig := {}
	for n in ["Hips", "Torso", "Head", "ArmR", "ArmL", "Racket", "LegR", "LegL",
			"Hair_Spiky", "Hair_Bun", "Hair_Afro", "Cap"]:
		var node := model.find_child(n, true, false) as Node3D
		if node:
			parts[n] = node
			orig[n] = node.position
	var hierarchy := {
		"Torso": "Hips", "LegR": "Hips", "LegL": "Hips", "Head": "Torso", "ArmR": "Torso",
		"ArmL": "Torso", "Racket": "ArmR", "Hair_Spiky": "Head", "Hair_Bun": "Head",
		"Hair_Afro": "Head", "Cap": "Head",
	}
	for child_name in ["Torso", "LegR", "LegL", "Head", "ArmR", "ArmL", "Racket",
			"Hair_Spiky", "Hair_Bun", "Hair_Afro", "Cap"]:
		if not parts.has(child_name):
			continue
		var c: Node3D = parts[child_name]
		var parent_name: String = hierarchy[child_name]
		var p: Node3D = parts[parent_name]
		c.get_parent().remove_child(c)
		p.add_child(c)
		c.position = orig[child_name] - orig[parent_name]
	for h in ["Hair_Spiky", "Hair_Bun", "Hair_Afro", "Cap"]:
		if parts.has(h):
			(parts[h] as Node3D).visible = (h == data.get("hair", ""))
	var t: Dictionary = GameData.TEAMS[team]
	var palette := {
		"Skin": data["skin"], "Hair": data["hair_color"], "Band": data["accent"],
		"Racket": data["racket"], "Shirt": t["shirt"], "ShirtTrim": t["trim"], "Shorts": t["shorts"],
	}
	var soft := {"halftone": 0.0, "shadow": Color(0.78, 0.62, 0.72)}
	Toon.apply(model, palette, {"outline": 0.022, "rim": 0.45}, [],
			{"Skin": soft, "EyeWhite": soft, "Cheek": soft, "Mouth": soft, "Pupil": {"halftone": 0.0}})

	shadow = Toon.blob(1.1, Color(0.3, 0.12, 0.2, 0.42))
	shadow.top_level = true
	add_child(shadow)
	if is_human:
		zone_ring = Toon.blob(REACH * 2.1, Color(1.0, 0.95, 0.3, 0.0), true)
		zone_ring.top_level = true
		add_child(zone_ring)

	bubble = Label3D.new()
	bubble.font = FONT
	bubble.font_size = 64
	bubble.outline_size = 18
	bubble.pixel_size = 0.006
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.modulate = Color.WHITE
	bubble.outline_modulate = Color(0.08, 0.04, 0.12)
	bubble.position = Vector3(0, 2.55, 0)
	bubble.visible = false
	add_child(bubble)


func net_dir() -> Vector3:
	return Vector3(0, 0, -side)


func max_speed() -> float:
	return BASE_SPEED * float(data.get("speed", 1.0)) * diff_speed


func say(text: String, color: Color = Color.WHITE) -> void:
	bubble.text = text
	bubble.modulate = color
	bubble.visible = true
	bubble_t = 0.9
	bubble.scale = Vector3.ONE * 0.2


func is_busy() -> bool:
	return state == State.DIVE or state == State.RECOVER


func on_ground() -> bool:
	return y <= 0.001 and vy <= 0.0


# ---------------------------------------------------------------- comandos

func request_shot(type: int) -> void:
	if state != State.NORMAL:
		return
	if swing_t < 0.6:
		return
	pending_shot = type
	pending_t = PENDING_WINDOW
	best_dist = INF
	swing_side = 1.0
	if type == Shots.SMASH and game != null and on_ground():
		var tc: float = game.predict_high_contact(self)
		if tc >= 0.0:
			jump_timer = maxf(tc - 0.3, 0.0)
			pending_t = tc + 0.25
		elif not serve_mode:
			jump_timer = 0.0


func request_jump() -> void:
	if state == State.NORMAL and on_ground():
		vy = JUMP_V
		squash_v = 3.0
		if game:
			game.sfx("jump", -6.0)


func request_dive(dir: Vector3) -> void:
	if state != State.NORMAL or not on_ground():
		return
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = vel if vel.length() > 0.5 else net_dir() * -1.0
	dive_dir = dir.normalized()
	vel = dive_dir * 10.0
	state = State.DIVE
	state_t = 0.0
	pending_shot = -1
	facing = atan2(dive_dir.x, dive_dir.z)
	if game:
		if game.shot_dir != "":
			print("EVT ", game.shot_n, " MERGULHO team=", team)
		game.sfx("dive", -2.0)
		game.sand_burst(global_position, 10)


func celebrate() -> void:
	state = State.CELEBRATE
	state_t = 0.0
	pending_shot = -1


func be_sad() -> void:
	state = State.SAD
	state_t = 0.0
	pending_shot = -1


func reset_state() -> void:
	state = State.NORMAL
	state_t = 0.0
	vel = Vector3.ZERO
	y = 0.0
	vy = 0.0
	pending_shot = -1
	swing_t = 1.0
	swing_type = -1
	jump_timer = -1.0
	facing = atan2(net_dir().x, net_dir().z)
	rotation.y = facing
	body.rotation = Vector3.ZERO
	serve_mode = false


# ---------------------------------------------------------------- alcance

func reach_center() -> Vector3:
	var c := global_position + net_dir() * 0.3
	if state == State.DIVE:
		c = global_position + dive_dir * 1.1
	c.y = 0.0
	return c


## Retorna {in, dist, quality, high}
func reach_info(p: Vector3, fast := false) -> Dictionary:
	var c := reach_center()
	var reach := REACH * (0.74 if fast else 1.0)
	var d := Vector2(p.x - c.x, p.z - c.z).length()
	var rel := p.y - y
	var ok := false
	var q := 0.0
	if state == State.DIVE:
		ok = d < 1.5 and p.y < 1.1 and p.y > 0.05
		q = clampf(1.0 - d / 1.5, 0.2, 0.9)
	elif state == State.NORMAL:
		ok = d < reach and p.y > 0.12 and rel < TOP_REACH + 0.25
		var qd := 1.0 - clampf((d - 0.45) / (reach - 0.5), 0.0, 1.0)
		var qh := 1.0
		if rel < 0.45:
			qh = 0.55
		elif rel > TOP_REACH:
			qh = 0.7
		q = clampf(qd * 0.75 + qh * 0.25, 0.0, 1.0)
		if fast:
			q *= 0.8
	return {"in": ok, "dist": d, "quality": q, "high": p.y > 2.0}


## Chamado pelo jogo a cada frame em que este jogador pode rebater a bola.
## Retorna o tipo de golpe executado (ou -1).
func try_contact(ball: Ball, delta: float) -> Dictionary:
	if state == State.DIVE:
		var info := reach_info(ball.global_position)
		if info["in"]:
			return {"type": Shots.DEFENSE, "quality": info["quality"]}
		return {}
	if pending_shot < 0 or state != State.NORMAL:
		return {}
	var fast := ball.vel.length() > 16.0
	var info := reach_info(ball.global_position, fast)
	if not info["in"]:
		return {}
	var d: float = info["dist"]
	var falling_low := ball.global_position.y < 0.35 and ball.vel.y < 0.0
	var next := ball.predict(delta)
	var next_info := reach_info(next, fast)
	var leaving: bool = not next_info["in"]
	if d < 0.32 or falling_low or leaving or d > best_dist + 0.01:
		var q: float = info["quality"]
		if d > best_dist + 0.01:
			q = maxf(q - 0.1, 0.0)   # passou do ponto: um pouco atrasado
		var shot := pending_shot
		_start_swing(shot, ball.global_position)
		return {"type": shot, "quality": q}
	best_dist = minf(best_dist, d)
	return {}


func _start_swing(type: int, ball_pos: Vector3) -> void:
	swing_type = type
	swing_t = 0.0
	pending_shot = -1
	var local := global_transform.affine_inverse() * ball_pos
	# personagem olha para +Z local; a raquete está do lado -X
	swing_side = 1.0 if local.x <= 0.15 else -1.0


# ---------------------------------------------------------------- update

func update(dt: float) -> void:
	anim_time += dt
	state_t += dt
	match state:
		State.NORMAL:
			_update_normal(dt)
		State.DIVE:
			vel = vel.move_toward(Vector3.ZERO, 14.0 * dt)
			if state_t > 0.5:
				state = State.RECOVER
				state_t = 0.0
				if game:
					game.sand_burst(global_position + dive_dir * 1.2, 12)
					game.sfx("sand", -4.0)
		State.RECOVER:
			vel = vel.move_toward(Vector3.ZERO, 20.0 * dt)
			if state_t > 0.42:
				state = State.NORMAL
				state_t = 0.0
		State.CELEBRATE, State.SAD:
			vel = vel.move_toward(Vector3.ZERO, 20.0 * dt)
			if state == State.CELEBRATE and on_ground() and fmod(state_t, 0.62) < dt:
				vy = 4.6
	# vertical
	if y > 0.0 or vy > 0.0:
		vy -= GRAV * dt
		y += vy * dt
		if y <= 0.0:
			y = 0.0
			vy = 0.0
			squash_v = -4.0
			if game:
				game.sand_burst(global_position, 5)
	# horizontal
	var pos := position + vel * dt
	var min_z := 0.35
	if side > 0.0:
		pos.z = clampf(pos.z, min_z, 11.5)
	else:
		pos.z = clampf(pos.z, -11.5, -min_z)
	pos.x = clampf(pos.x, -7.0, 7.0)
	if lock_x:
		pos.z = locked_z
	pos.y = y
	position = pos
	_animate(dt)


func _update_normal(dt: float) -> void:
	if pending_shot >= 0:
		pending_t -= dt
		if pending_t <= 0.0:
			_start_swing(pending_shot, global_position + net_dir())
	if jump_timer >= 0.0:
		jump_timer -= dt
		if jump_timer < 0.0:
			request_jump()
	if swing_t < 1.0:
		swing_t = minf(swing_t + dt / STRIKE_TIME, 1.0)
	var target := move_input * max_speed()
	if swing_t < 0.7:
		target *= 0.35
	elif pending_shot >= 0:
		target *= 0.85
	if not on_ground():
		target = vel
	var accel := 40.0 if move_input.length() > 0.1 else 32.0
	vel = vel.move_toward(Vector3(target.x, 0.0, target.z), accel * dt)
	# rosto: corre olhando para onde vai, rebate olhando para a rede
	var face_target := atan2(net_dir().x, net_dir().z)
	var flat := Vector2(vel.x, vel.z)
	if flat.length() > 2.2 and pending_shot < 0 and swing_t >= 1.0 and not serve_mode:
		var run_yaw := atan2(vel.x, vel.z)
		face_target = lerp_angle(face_target, run_yaw, 0.75)
	facing = lerp_angle(facing, face_target, 1.0 - exp(-12.0 * dt))
	# passos na areia
	if flat.length() > 3.0 and on_ground():
		footstep_t -= dt
		if footstep_t <= 0.0:
			footstep_t = 0.22
			if game:
				game.sand_burst(global_position, 2)


# ---------------------------------------------------------------- animação

func _animate(dt: float) -> void:
	rotation.y = facing
	var spd := Vector2(vel.x, vel.z).length()
	var run := clampf(spd / 5.5, 0.0, 1.0)
	run_phase += dt * (5.0 + spd * 1.7)
	var s := sin(run_phase)
	var breathe := sin(anim_time * 3.2) * 0.03
	# local: rotação de cada parte
	var r := {
		"Hips": Vector3.ZERO,
		"Torso": Vector3(0.12 * run + breathe, 0.0, 0.0),
		"Head": Vector3(-0.08 * run, 0.0, 0.0),
		"ArmR": Vector3(-0.75 - s * 0.35 * run, 0.35, -0.2),
		"ArmL": Vector3(-0.25 + s * 0.9 * run, 0.0, 0.18),
		"LegR": Vector3(-s * 0.95 * run, 0.0, 0.0),
		"LegL": Vector3(s * 0.95 * run, 0.0, 0.0),
		"Racket": Vector3.ZERO,
	}
	var hips_y := absf(cos(run_phase)) * 0.07 * run
	var body_rot := Vector3.ZERO
	var crouch := 0.0
	var sharp := 14.0

	if state == State.NORMAL and pending_shot >= 0:
		_windup_pose(pending_shot, r)
		crouch = 0.08
		if pending_shot == Shots.LOB or pending_shot == Shots.DEFENSE:
			crouch = 0.16
	if swing_t < 1.0 and swing_type >= 0:
		_strike_pose(swing_type, swing_t, r)
		sharp = 30.0
	if not on_ground():
		r["LegR"] = Vector3(-0.6, 0, 0)
		r["LegL"] = Vector3(0.35, 0, 0)
		if serve_mode or swing_type == Shots.SMASH or pending_shot == Shots.SMASH:
			r["ArmL"] = Vector3(-2.7, 0.0, 0.3)
	match state:
		State.DIVE, State.RECOVER:
			var k := 1.0 if state == State.DIVE else clampf(1.0 - state_t / 0.42, 0.0, 1.0)
			k = minf(k, clampf(state_t / 0.12, 0.0, 1.0)) if state == State.DIVE else k
			body_rot.x = 1.3 * k
			r["ArmR"] = Vector3(-2.9 * k - 0.6 * (1.0 - k), 0.0, -0.1)
			r["ArmL"] = Vector3(-2.9 * k - 0.4 * (1.0 - k), 0.0, 0.1)
			r["LegR"] = Vector3(0.35 * k, 0, 0)
			r["LegL"] = Vector3(0.25 * k, 0, 0)
			r["Head"] = Vector3(-0.7 * k, 0, 0)
			hips_y = 0.0
			sharp = 18.0
		State.CELEBRATE:
			var w := sin(state_t * 14.0)
			r["ArmR"] = Vector3(-2.8, 0.0, -0.35 + w * 0.25)
			r["ArmL"] = Vector3(-2.8, 0.0, 0.35 - w * 0.25)
			r["Head"] = Vector3(-0.3, 0, 0)
			r["Torso"] = Vector3(-0.15, sin(state_t * 7.0) * 0.3, 0)
		State.SAD:
			r["Torso"] = Vector3(0.45, 0, 0)
			r["Head"] = Vector3(0.5, 0, 0)
			r["ArmR"] = Vector3(0.1, 0, -0.05)
			r["ArmL"] = Vector3(0.1, 0, 0.05)
			crouch = 0.05
	# aplica com suavização
	var a := 1.0 - exp(-sharp * dt)
	for k in r:
		if parts.has(k):
			var n: Node3D = parts[k]
			var target: Vector3 = r[k]
			n.rotation = Vector3(lerp_angle(n.rotation.x, target.x, a), lerp_angle(n.rotation.y, target.y, a),
					lerp_angle(n.rotation.z, target.z, a))
	body.rotation.x = lerp_angle(body.rotation.x, body_rot.x, 1.0 - exp(-16.0 * dt))
	# squash & stretch (mola)
	squash_v += (1.0 - squash) * 180.0 * dt
	squash_v *= exp(-11.0 * dt)
	squash += squash_v * dt
	var sq := clampf(squash, 0.75, 1.3)
	body.scale = Vector3(1.0 / sqrt(sq), sq, 1.0 / sqrt(sq))
	if parts.has("Hips"):
		var hips: Node3D = parts["Hips"]
		hips.position.y = lerpf(hips.position.y, 0.86 + hips_y - crouch, 1.0 - exp(-14.0 * dt))
	# sombra, anel e balão
	shadow.global_position = Vector3(global_position.x, 0.015, global_position.z)
	shadow.scale = Vector3.ONE * lerpf(1.0, 0.6, clampf(y / 1.2, 0.0, 1.0))
	if zone_ring:
		var c := reach_center()
		zone_ring.global_position = Vector3(c.x, 0.025, c.z)
		var m := zone_ring.material_override as ShaderMaterial
		var target_a := 0.85 if hittable else 0.0
		var col: Color = m.get_shader_parameter("color")
		col.a = lerpf(col.a, target_a, 1.0 - exp(-14.0 * dt))
		m.set_shader_parameter("color", col)
		m.set_shader_parameter("pulse", 1.0 if hittable else 0.0)
	if bubble_t > 0.0:
		bubble_t -= dt
		var sc := minf(1.0, bubble.scale.x + dt * 8.0)
		bubble.scale = Vector3.ONE * sc
		bubble.position.y = 2.55 + (0.9 - bubble_t) * 0.25
		if bubble_t <= 0.0:
			bubble.visible = false


func _windup_pose(type: int, r: Dictionary) -> void:
	match type:
		Shots.DRIVE:
			r["ArmR"] = Vector3(-1.3, -1.9, 0.0)
			r["Torso"] = Vector3(0.1, -0.7, 0.0)
		Shots.LOB, Shots.DEFENSE:
			r["ArmR"] = Vector3(0.45, -0.5, 0.0)
			r["ArmL"] = Vector3(-0.6, 0.0, 0.3)
			r["Torso"] = Vector3(0.35, -0.2, 0.0)
		Shots.DROP:
			r["ArmR"] = Vector3(-0.9, -1.0, 0.0)
			r["Torso"] = Vector3(0.15, -0.35, 0.0)
		Shots.SMASH:
			r["ArmR"] = Vector3(-3.4, -0.3, 0.0)
			r["ArmL"] = Vector3(-2.6, 0.0, 0.25)
			r["Torso"] = Vector3(-0.3, -0.4, 0.0)
			r["Head"] = Vector3(-0.4, 0.0, 0.0)


func _strike_pose(type: int, t: float, r: Dictionary) -> void:
	var e := 1.0 - pow(1.0 - t, 3.0)
	var sw := swing_side
	match type:
		Shots.DRIVE:
			if sw > 0.0:
				r["ArmR"] = Vector3(-1.35, lerpf(-1.9, 1.1, e), 0.0)
				r["Torso"] = Vector3(0.1, lerpf(-0.7, 0.55, e), 0.0)
			else:
				r["ArmR"] = Vector3(-1.3, lerpf(1.2, -1.5, e), 0.0)
				r["Torso"] = Vector3(0.1, lerpf(0.8, -0.4, e), 0.0)
		Shots.LOB, Shots.DEFENSE:
			r["ArmR"] = Vector3(lerpf(0.45, -2.6, e), lerpf(-0.5, 0.25, e), 0.0)
			r["ArmL"] = Vector3(-0.8, 0.0, 0.3)
			r["Torso"] = Vector3(lerpf(0.35, -0.25, e), 0.0, 0.0)
			r["Head"] = Vector3(-0.3 * e, 0.0, 0.0)
		Shots.DROP:
			r["ArmR"] = Vector3(lerpf(-0.9, -1.5, e), lerpf(-1.0, -0.15, e), 0.0)
			r["Torso"] = Vector3(0.15, lerpf(-0.35, 0.05, e), 0.0)
		Shots.SMASH:
			r["ArmR"] = Vector3(lerpf(-3.4, -0.5, e), lerpf(-0.3, 0.45, e), 0.0)
			r["ArmL"] = Vector3(lerpf(-2.6, -0.4, e), 0.0, 0.25)
			r["Torso"] = Vector3(lerpf(-0.3, 0.55, e), lerpf(-0.4, 0.3, e), 0.0)
			r["Head"] = Vector3(lerpf(-0.4, 0.2, e), 0.0, 0.0)

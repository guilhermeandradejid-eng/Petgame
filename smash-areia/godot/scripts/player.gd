class_name Player
extends Node3D
## Jogador de beach tennis: movimento na areia, pulo, mergulho, golpes
## carregados, super golpe e animação procedural do boneco com esqueleto
## (modelado no Blender).

enum State { NORMAL, DIVE, RECOVER, CELEBRATE, SAD, KNOCK }

const MODEL := preload("res://assets/models/player.glb")
const RACKET := preload("res://assets/models/racket.glb")
const FONT := preload("res://assets/fonts/Bangers.woff")
const BASE_SPEED := 6.4
const REACH := 1.25
const TOP_REACH := 2.3
const JUMP_V := 5.6
const GRAV := 16.0
const PENDING_WINDOW := 0.7
const STRIKE_TIME := 0.24
const CHARGE_TIME := 0.5
const HAIRS := ["Hair_Spiky", "Hair_Pony", "Cap", "Hair_Puffs", "Shades"]
const THIGH := 0.41
const SHIN := 0.42

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
var lock_x := false
var locked_z := 0.0

# golpe
var pending_shot := -1
var pending_t := 0.0
var pending_age := 0.0
var best_dist := INF
var swing_type := -1
var swing_t := 1.0
var swing_side := 1.0
var jump_timer := -1.0
var jump_boost := 1.0
var serve_mode := false
var last_charge := 0.0

# visual
var model: Node3D
var body: Node3D
var rig: Rig
var racket: Node3D
var run_phase := 0.0
var squash := 1.0
var squash_v := 0.0
var anim_time := 0.0
var lean := Vector2.ZERO
var bubble: Label3D
var bubble_t := 0.0
var shadow: MeshInstance3D
var zone_ring: MeshInstance3D
var aura: MeshInstance3D
var hittable := false
var footstep_t := 0.0
var trail_im: ImmediateMesh
var trail_mi: MeshInstance3D
var trail_pts: Array = []
var trail_color := Color.WHITE


func setup(char_data: Dictionary, team_index: int, human: bool) -> void:
	data = char_data
	team = team_index
	side = 1.0 if team == 0 else -1.0
	is_human = human
	_build_model()


## Cria o boneco com a paleta de um personagem/time. Usado também pelo juiz e pela prévia.
static func make_model(char_data: Dictionary, team_data: Dictionary) -> Dictionary:
	var m: Node3D = MODEL.instantiate()
	m.scale = Vector3.ONE * GameData.CHAR_SCALE
	var sk := _find_skeleton(m)
	for h in HAIRS:
		var n := m.find_child(h, true, false)
		if n:
			(n as Node3D).visible = (h == char_data.get("hair", ""))
	var palette := {
		"Skin": char_data["skin"], "Hair": char_data["hair_color"], "Band": char_data["accent"],
		"Shirt": team_data["shirt"], "ShirtTrim": team_data["trim"], "Shorts": team_data["shorts"],
	}
	var soft := {"halftone": 0.0, "shadow": Color(0.8, 0.64, 0.74), "rim": 0.5}
	Toon.apply(m, palette, {"outline": 0.018, "rim": 0.4}, [],
			{"Skin": soft, "Cheek": soft, "Mouth": soft, "Pupil": {"halftone": 0.0, "outline": 0.0},
			"EyeShine": {"halftone": 0.0, "outline": 0.0}})
	var r := Rig.new(sk)
	var att := BoneAttachment3D.new()
	att.bone_name = "Hand.R"
	sk.add_child(att)
	var rk: Node3D = RACKET.instantiate()
	Toon.apply(rk, {"Racket": char_data.get("racket", Color.WHITE)}, {"outline": 0.014, "rim": 0.5})
	att.add_child(rk)
	rk.transform = r.local_to_bone("Hand.R", Transform3D(Basis(), Vector3(-0.285, 0.89, 0.0)))
	return {"model": m, "rig": r, "racket": rk, "skeleton": sk}


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null


func _build_model() -> void:
	body = Node3D.new()
	add_child(body)
	var mm := make_model(data, GameData.TEAMS[team])
	model = mm["model"]
	rig = mm["rig"]
	racket = mm["racket"]
	body.add_child(model)

	shadow = Toon.blob(1.0, Color(0.3, 0.12, 0.2, 0.42))
	shadow.top_level = true
	add_child(shadow)
	aura = Toon.blob(1.7, Color(1, 1, 1, 0.0), true)
	aura.top_level = true
	add_child(aura)
	if is_human:
		zone_ring = Toon.blob(REACH * 2.1, Color(1.0, 0.95, 0.3, 0.0), true)
		zone_ring.top_level = true
		add_child(zone_ring)

	trail_im = ImmediateMesh.new()
	trail_mi = MeshInstance3D.new()
	trail_mi.mesh = trail_im
	trail_mi.top_level = true
	var tm := ShaderMaterial.new()
	tm.shader = preload("res://shaders/swing.gdshader")
	trail_mi.material_override = tm
	trail_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail_mi)

	bubble = Label3D.new()
	bubble.font = FONT
	bubble.font_size = 56
	bubble.outline_size = 16
	bubble.pixel_size = 0.005
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.outline_modulate = Color(0.08, 0.04, 0.12)
	bubble.position = Vector3(0, 2.4, 0)
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
	bubble_t = 0.8
	bubble.scale = Vector3.ONE * 0.2


func is_busy() -> bool:
	return state == State.DIVE or state == State.RECOVER or state == State.KNOCK


func on_ground() -> bool:
	return y <= 0.001 and vy <= 0.0


func charge() -> float:
	if pending_shot < 0:
		return 0.0
	return clampf((pending_age - 0.12) / CHARGE_TIME, 0.0, 1.0)


# ---------------------------------------------------------------- comandos

func request_shot(type: int) -> void:
	if state != State.NORMAL or swing_t < 0.6:
		return
	if pending_shot >= 0 and pending_shot == type:
		return
	pending_shot = type
	pending_t = PENDING_WINDOW + (0.5 if type == Shots.SPECIAL else 0.0)
	pending_age = 0.0
	best_dist = INF
	trail_color = Shots.COLORS[type]
	if (type == Shots.SMASH or (type == Shots.SPECIAL and data.get("special", "") == "meteoro")) \
			and game != null and on_ground():
		var tc: float = game.predict_high_contact(self)
		if tc >= 0.0:
			jump_timer = maxf(tc - 0.3, 0.0)
			pending_t = tc + 0.25
		elif not serve_mode and type == Shots.SMASH:
			jump_timer = 0.0


func request_jump(boost := 1.0) -> void:
	if state == State.NORMAL and on_ground():
		vy = JUMP_V * boost
		squash_v = 3.5
		if game:
			game.sfx("jump", -6.0)


func request_dive(dir: Vector3) -> void:
	if state != State.NORMAL or not on_ground():
		return
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = vel if vel.length() > 0.5 else -net_dir()
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


## Empurrado para trás ao receber um super golpe.
func knockback(dir: Vector3, power: float) -> void:
	dir.y = 0.0
	state = State.KNOCK
	state_t = 0.0
	pending_shot = -1
	vel = dir.normalized() * 7.5 * power
	vy = 2.5
	if game:
		game.sand_burst(global_position, 12)


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
	trail_pts.clear()


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
func try_contact(ball: Ball, delta: float) -> Dictionary:
	if state == State.DIVE:
		var info := reach_info(ball.global_position)
		if info["in"]:
			return {"type": Shots.DEFENSE, "quality": info["quality"], "charge": 0.0}
		return {}
	if pending_shot < 0 or state != State.NORMAL:
		return {}
	var fast := ball.vel.length() > 16.0
	var info := reach_info(ball.global_position, fast)
	if not info["in"]:
		return {}
	var d: float = info["dist"]
	var falling_low := ball.global_position.y < 0.35 and ball.vel.y < 0.0
	var next_info := reach_info(ball.predict(delta), fast)
	var leaving: bool = not next_info["in"]
	if d < 0.32 or falling_low or leaving or d > best_dist + 0.01:
		var q: float = info["quality"]
		if d > best_dist + 0.01:
			q = maxf(q - 0.1, 0.0)
		var shot := pending_shot
		var ch := charge()
		_start_swing(shot, ball.global_position)
		return {"type": shot, "quality": q, "charge": ch}
	best_dist = minf(best_dist, d)
	return {}


func _start_swing(type: int, ball_pos: Vector3) -> void:
	swing_type = type
	swing_t = 0.0
	last_charge = charge()
	pending_shot = -1
	trail_pts.clear()
	trail_color = Shots.COLORS[type]
	var local := global_transform.affine_inverse() * ball_pos
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
		State.KNOCK:
			vel = vel.move_toward(Vector3.ZERO, 9.0 * dt)
			if state_t > 0.75:
				state = State.NORMAL
				state_t = 0.0
		State.CELEBRATE, State.SAD:
			vel = vel.move_toward(Vector3.ZERO, 20.0 * dt)
			if state == State.CELEBRATE and on_ground() and fmod(state_t, 0.62) < dt:
				vy = 4.6
	if y > 0.0 or vy > 0.0:
		vy -= GRAV * dt
		y += vy * dt
		if y <= 0.0:
			y = 0.0
			vy = 0.0
			squash_v = -4.5
			if game:
				game.sand_burst(global_position, 5)
	var pos := position + vel * dt
	if side > 0.0:
		pos.z = clampf(pos.z, 0.35, 11.5)
	else:
		pos.z = clampf(pos.z, -11.5, -0.35)
	pos.x = clampf(pos.x, -7.0, 7.0)
	if lock_x:
		pos.z = locked_z
	pos.y = y
	position = pos
	_animate(dt)


func _update_normal(dt: float) -> void:
	if pending_shot >= 0:
		pending_t -= dt
		pending_age += dt
		if pending_t <= 0.0:
			_start_swing(pending_shot, global_position + net_dir())
	if jump_timer >= 0.0:
		jump_timer -= dt
		if jump_timer < 0.0:
			request_jump(jump_boost)
			jump_boost = 1.0
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
	var face_target := atan2(net_dir().x, net_dir().z)
	var flat := Vector2(vel.x, vel.z)
	if flat.length() > 2.2 and pending_shot < 0 and swing_t >= 1.0 and not serve_mode:
		face_target = lerp_angle(face_target, atan2(vel.x, vel.z), 0.75)
	facing = lerp_angle(facing, face_target, 1.0 - exp(-12.0 * dt))
	if flat.length() > 3.0 and on_ground():
		footstep_t -= dt
		if footstep_t <= 0.0:
			footstep_t = 0.22
			if game:
				game.sand_burst(global_position, 2)


# ---------------------------------------------------------------- animação

func _leg_drop(thigh: float, knee: float) -> float:
	# quanto o quadril precisa descer para o pé continuar no chão
	return THIGH * (1.0 - cos(thigh)) + SHIN * (1.0 - cos(thigh + knee))


func _animate(dt: float) -> void:
	rotation.y = facing
	var spd := Vector2(vel.x, vel.z).length()
	var run := clampf(spd / 5.5, 0.0, 1.0) if on_ground() and state == State.NORMAL else 0.0
	run_phase += dt * (6.0 + spd * 1.6)
	var s := sin(run_phase)
	var breathe := sin(anim_time * 3.0) * 0.025
	var lv := global_transform.basis.inverse() * vel
	lean = lean.lerp(Vector2(lv.x, lv.z) / 6.5, 1.0 - exp(-8.0 * dt))
	var ready := 1.0 - run
	var p := {
		"Spine": Vector3(0.1 + lean.y * 0.25 + breathe, 0.0, -lean.x * 0.15),
		"Chest": Vector3(0.06 * ready + 0.12 * run, 0.0, 0.0),
		"Neck": Vector3(-0.08, 0.0, 0.0),
		"Head": Vector3(-0.1 - 0.1 * run, 0.0, 0.0),
		"UpperArm.R": Vector3(-0.55 * ready + (-0.3 - s * 0.6) * run, 0.25 * ready, -0.28),
		"LowerArm.R": Vector3(-1.0 * ready - 1.3 * run, 0.0, 0.0),
		"Hand.R": Vector3(0.25, 0.0, 0.0),
		"UpperArm.L": Vector3(-0.4 * ready + (-0.2 + s * 0.8) * run, 0.0, 0.25),
		"LowerArm.L": Vector3(-0.9 * ready - 1.4 * run, 0.0, 0.0),
	}
	var thigh_r := -0.42 * ready + (-0.3 + 0.85 * s) * run
	var thigh_l := -0.42 * ready + (-0.3 - 0.85 * s) * run
	var knee_r := 0.78 * ready + (0.45 + 1.2 * maxf(0.0, s)) * run
	var knee_l := 0.78 * ready + (0.45 + 1.2 * maxf(0.0, -s)) * run
	var crouch := 0.0
	var sharp := 14.0
	var body_rot := Vector3.ZERO

	if state == State.NORMAL and pending_shot >= 0:
		_windup_pose(pending_shot, p)
		var ch := charge()
		crouch = 0.03 + ch * 0.05
		if pending_shot == Shots.LOB or pending_shot == Shots.DEFENSE:
			knee_r += 0.4
			knee_l += 0.4
			thigh_r -= 0.2
			thigh_l -= 0.2
		body.position.x = (randf() - 0.5) * 0.03 * ch if int(anim_time * 30.0) % 2 == 0 else 0.0
	else:
		body.position.x = 0.0
	if swing_t < 1.0 and swing_type >= 0:
		_strike_pose(swing_type, swing_t, p)
		sharp = 32.0
		thigh_l -= 0.3 * sin(swing_t * PI)
		knee_l += 0.2 * sin(swing_t * PI)
	if not on_ground():
		thigh_r = -0.9
		knee_r = 1.3
		thigh_l = 0.2
		knee_l = 0.6
		if serve_mode or swing_type == Shots.SMASH or pending_shot == Shots.SMASH:
			p["UpperArm.L"] = Vector3(-2.7, 0.0, 0.25)
			p["LowerArm.L"] = Vector3(-0.2, 0.0, 0.0)
	match state:
		State.DIVE, State.RECOVER:
			var k := 1.0 if state == State.DIVE else clampf(1.0 - state_t / 0.42, 0.0, 1.0)
			if state == State.DIVE:
				k = minf(k, clampf(state_t / 0.12, 0.0, 1.0))
			body_rot.x = 1.3 * k
			p["UpperArm.R"] = Vector3(-2.9 * k - 0.6 * (1.0 - k), 0.0, -0.15)
			p["UpperArm.L"] = Vector3(-2.9 * k - 0.4 * (1.0 - k), 0.0, 0.15)
			p["LowerArm.R"] = Vector3(-0.2, 0, 0)
			p["LowerArm.L"] = Vector3(-0.2, 0, 0)
			p["Head"] = Vector3(-0.7 * k, 0, 0)
			thigh_r = 0.25 * k
			thigh_l = 0.1 * k
			knee_r = 0.5 * k
			knee_l = 0.3 * k
			sharp = 18.0
		State.KNOCK:
			var k2 := clampf(1.0 - state_t / 0.75, 0.0, 1.0)
			body_rot.x = -0.55 * k2
			body_rot.z = sin(state_t * 22.0) * 0.2 * k2
			p["UpperArm.R"] = Vector3(-1.8, 0, -1.0 - sin(state_t * 30.0) * 0.5)
			p["UpperArm.L"] = Vector3(-1.8, 0, 1.0 + sin(state_t * 30.0) * 0.5)
			p["Head"] = Vector3(0.4, sin(state_t * 18.0) * 0.4, 0)
		State.CELEBRATE:
			var w := sin(state_t * 14.0)
			p["UpperArm.R"] = Vector3(-2.8, 0.0, -0.35 + w * 0.2)
			p["UpperArm.L"] = Vector3(-2.8, 0.0, 0.35 - w * 0.2)
			p["LowerArm.R"] = Vector3(-0.3 - w * 0.3, 0, 0)
			p["LowerArm.L"] = Vector3(-0.3 + w * 0.3, 0, 0)
			p["Head"] = Vector3(-0.35, 0, 0)
			p["Spine"] = Vector3(-0.15, sin(state_t * 7.0) * 0.3, 0)
		State.SAD:
			p["Spine"] = Vector3(0.4, 0, 0)
			p["Chest"] = Vector3(0.2, 0, 0)
			p["Head"] = Vector3(0.5, 0, 0)
			p["UpperArm.R"] = Vector3(0.05, 0, -0.08)
			p["UpperArm.L"] = Vector3(0.05, 0, 0.08)
			p["LowerArm.R"] = Vector3(-0.2, 0, 0)
			p["LowerArm.L"] = Vector3(-0.2, 0, 0)
			thigh_r = -0.15
			thigh_l = -0.15
			knee_r = 0.3
			knee_l = 0.3
	p["UpperLeg.R"] = Vector3(thigh_r, 0.0, -0.06)
	p["UpperLeg.L"] = Vector3(thigh_l, 0.0, 0.06)
	p["LowerLeg.R"] = Vector3(knee_r, 0.0, 0.0)
	p["LowerLeg.L"] = Vector3(knee_l, 0.0, 0.0)
	p["Foot.R"] = Vector3(-(thigh_r + knee_r) * 0.8, 0.0, 0.0)
	p["Foot.L"] = Vector3(-(thigh_l + knee_l) * 0.8, 0.0, 0.0)
	var drop := minf(_leg_drop(thigh_r, knee_r), _leg_drop(thigh_l, knee_l))
	if not on_ground() or state == State.DIVE:
		drop = 0.0
	var bob := absf(cos(run_phase)) * 0.05 * run
	rig.apply(p, 1.0 - exp(-sharp * dt), Vector3(0.0, -drop - crouch + bob, 0.0))
	# super golpe: giro completo de desenho animado
	if swing_type == Shots.SPECIAL and swing_t < 1.0:
		body.rotation.y = (1.0 - pow(1.0 - swing_t, 2.0)) * TAU
	else:
		body.rotation.y = 0.0
	body.rotation.x = lerp_angle(body.rotation.x, body_rot.x, 1.0 - exp(-16.0 * dt))
	body.rotation.z = lerp_angle(body.rotation.z, body_rot.z, 1.0 - exp(-16.0 * dt))
	squash_v += (1.0 - squash) * 180.0 * dt
	squash_v *= exp(-11.0 * dt)
	squash += squash_v * dt
	var sq := clampf(squash, 0.78, 1.25)
	body.scale = Vector3(1.0 / sqrt(sq), sq, 1.0 / sqrt(sq))
	_update_trail()
	_update_decals(dt)


func _update_decals(dt: float) -> void:
	shadow.global_position = Vector3(global_position.x + 0.12, 0.015, global_position.z + 0.08)
	shadow.scale = Vector3.ONE * lerpf(1.0, 0.6, clampf(y / 1.2, 0.0, 1.0))
	var am := aura.material_override as ShaderMaterial
	var ch := charge()
	var ac: Color = Shots.COLORS[pending_shot] if pending_shot >= 0 else Color.WHITE
	ac.a = ch * 0.9 if pending_shot >= 0 else 0.0
	if pending_shot == Shots.SPECIAL:
		ac.a = 0.6 + 0.4 * sin(anim_time * 20.0)
	am.set_shader_parameter("color", ac)
	am.set_shader_parameter("pulse", 1.0)
	aura.global_position = Vector3(global_position.x, 0.03, global_position.z)
	aura.scale = Vector3.ONE * (0.8 + ch * 0.4 + (0.3 if pending_shot == Shots.SPECIAL else 0.0))
	if zone_ring:
		var c := reach_center()
		zone_ring.global_position = Vector3(c.x, 0.025, c.z)
		var m := zone_ring.material_override as ShaderMaterial
		var col: Color = m.get_shader_parameter("color")
		col.a = lerpf(col.a, 0.8 if hittable else 0.0, 1.0 - exp(-14.0 * dt))
		m.set_shader_parameter("color", col)
		m.set_shader_parameter("pulse", 1.0 if hittable else 0.0)
	if bubble_t > 0.0:
		bubble_t -= dt
		bubble.scale = Vector3.ONE * minf(1.0, bubble.scale.x + dt * 8.0)
		bubble.position.y = 2.4 + (0.8 - bubble_t) * 0.2
		if bubble_t <= 0.0:
			bubble.visible = false


## Rastro da raquete ("smear" de desenho animado) durante a batida.
func _update_trail() -> void:
	trail_im.clear_surfaces()
	if racket == null:
		return
	if swing_t < 1.0 and swing_type >= 0:
		var xf := racket.global_transform
		trail_pts.push_front([xf * Vector3(0, -0.12, 0), xf * Vector3(0, -0.6, 0)])
	elif trail_pts.size() > 0:
		trail_pts.pop_back()
	while trail_pts.size() > 9:
		trail_pts.pop_back()
	if trail_pts.size() < 2:
		return
	var m := trail_mi.material_override as ShaderMaterial
	m.set_shader_parameter("color", trail_color.lerp(Color.WHITE, 0.45))
	trail_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := trail_pts.size()
	for i in n:
		var t := 1.0 - float(i) / float(n - 1)
		var a: Vector3 = trail_pts[i][0]
		var b: Vector3 = trail_pts[i][1]
		trail_im.surface_set_uv(Vector2(t, 0.0))
		trail_im.surface_add_vertex(a.lerp(b, 0.35 * (1.0 - t)))
		trail_im.surface_set_uv(Vector2(t, 1.0))
		trail_im.surface_add_vertex(b)
	trail_im.surface_end()


func _windup_pose(type: int, r: Dictionary) -> void:
	match type:
		Shots.DRIVE:
			r["UpperArm.R"] = Vector3(-1.1, -1.25, -0.3)
			r["LowerArm.R"] = Vector3(-0.6, 0.0, 0.0)
			r["Chest"] = Vector3(0.08, -0.75, 0.0)
			r["Spine"] = Vector3(0.12, -0.3, 0.0)
		Shots.LOB, Shots.DEFENSE:
			r["UpperArm.R"] = Vector3(0.45, -0.4, -0.2)
			r["LowerArm.R"] = Vector3(-0.3, 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-0.8, 0.0, 0.35)
			r["Chest"] = Vector3(0.2, -0.35, 0.0)
		Shots.DROP:
			r["UpperArm.R"] = Vector3(-0.9, -0.8, -0.25)
			r["LowerArm.R"] = Vector3(-1.2, 0.0, 0.0)
			r["Chest"] = Vector3(0.12, -0.4, 0.0)
		Shots.SMASH, Shots.SPECIAL:
			r["UpperArm.R"] = Vector3(-2.9, -0.45, -0.3)
			r["LowerArm.R"] = Vector3(-1.9, 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-2.7, 0.0, 0.2)
			r["LowerArm.L"] = Vector3(-0.2, 0.0, 0.0)
			r["Spine"] = Vector3(-0.25, -0.2, 0.0)
			r["Chest"] = Vector3(-0.15, -0.45, 0.0)
			r["Head"] = Vector3(-0.45, 0.0, 0.0)


func _strike_pose(type: int, t: float, r: Dictionary) -> void:
	var e := 1.0 - pow(1.0 - t, 3.0)
	match type:
		Shots.DRIVE:
			if swing_side > 0.0:
				r["UpperArm.R"] = Vector3(-1.25, lerpf(-1.25, 1.1, e), -0.2)
				r["LowerArm.R"] = Vector3(lerpf(-0.6, -1.3, e), 0.0, 0.0)
				r["Chest"] = Vector3(0.08, lerpf(-0.75, 0.6, e), 0.0)
				r["Spine"] = Vector3(0.12, lerpf(-0.3, 0.3, e), 0.0)
			else:
				r["UpperArm.R"] = Vector3(-1.2, lerpf(1.3, -1.4, e), -0.3)
				r["LowerArm.R"] = Vector3(lerpf(-1.3, -0.2, e), 0.0, 0.0)
				r["Chest"] = Vector3(0.08, lerpf(0.85, -0.45, e), 0.0)
		Shots.LOB, Shots.DEFENSE:
			r["UpperArm.R"] = Vector3(lerpf(0.45, -2.5, e), lerpf(-0.4, 0.25, e), -0.2)
			r["LowerArm.R"] = Vector3(lerpf(-0.3, -0.5, e), 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-0.9, 0.0, 0.35)
			r["Chest"] = Vector3(lerpf(0.2, -0.25, e), 0.0, 0.0)
			r["Head"] = Vector3(-0.35 * e, 0.0, 0.0)
		Shots.DROP:
			r["UpperArm.R"] = Vector3(lerpf(-0.9, -1.35, e), lerpf(-0.8, -0.1, e), -0.25)
			r["LowerArm.R"] = Vector3(lerpf(-1.2, -0.7, e), 0.0, 0.0)
			r["Chest"] = Vector3(0.12, lerpf(-0.4, 0.05, e), 0.0)
		Shots.SMASH:
			r["UpperArm.R"] = Vector3(lerpf(-2.9, -0.6, e), lerpf(-0.45, 0.5, e), -0.2)
			r["LowerArm.R"] = Vector3(lerpf(-1.9, -0.15, e), 0.0, 0.0)
			r["UpperArm.L"] = Vector3(lerpf(-2.7, -0.5, e), 0.0, 0.25)
			r["Spine"] = Vector3(lerpf(-0.25, 0.45, e), lerpf(-0.2, 0.25, e), 0.0)
			r["Chest"] = Vector3(lerpf(-0.15, 0.3, e), lerpf(-0.45, 0.35, e), 0.0)
			r["Head"] = Vector3(lerpf(-0.45, 0.2, e), 0.0, 0.0)
		Shots.SPECIAL:
			r["Spine"] = Vector3(lerpf(-0.25, 0.4, e), 0.0, 0.0)
			r["UpperArm.R"] = Vector3(lerpf(-2.9, -0.8, e), lerpf(-0.45, 0.5, e), -0.6)
			r["LowerArm.R"] = Vector3(lerpf(-1.9, -0.1, e), 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-1.6, 0.0, 1.0)

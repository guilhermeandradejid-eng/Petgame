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

# estilo visual do golpe (escolhido pela posição da bola): fore, back, low_fore,
# low_back, lunge_fore, lunge_back, smash, gancho, block
var style := "fore"
var last_style := "fore"
var style_t := 0.0
var loco := "idle"        # idle, run, shuffle, back
var split_t := -1.0


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
	var soft := {"halftone": 0.0, "shadow": Color(0.86, 0.72, 0.8), "rim": 0.45}
	var flat := {"halftone": 0.0, "outline": 0.0, "rim": 0.0}
	Toon.apply(m, palette, {"outline": 0.018, "rim": 0.4, "halftone": 0.45}, [],
			{"Skin": soft, "Cheek": flat, "Mouth": flat, "Pupil": flat, "EyeShine": flat,
			"Hair": {"halftone": 0.0, "rim": 0.5}, "Band": {"halftone": 0.0}})
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
		# gancho: bola alta passando por cima/atrás da cabeça
		if not ok and rel > 1.8 and rel < TOP_REACH + 0.6:
			var dh := Vector2(p.x - global_position.x, p.z - global_position.z).length()
			if dh < 0.95:
				ok = true
				q = 0.72
		if fast:
			q *= 0.8
	return {"in": ok, "dist": d, "quality": q, "high": p.y > 2.0}


## Classifica o golpe pela posição da bola em relação ao corpo (de frente
## para a rede): forehand, backhand, baixo, avanço lateral, smash ou gancho.
func classify(bp: Vector3, type: int, fast: bool) -> String:
	if type == Shots.DEFENSE and state == State.DIVE:
		return "dive"
	var f := net_dir()
	var left := Vector3.UP.cross(f)
	var rel := bp - global_position
	var lx := rel.dot(left)          # > 0: lado esquerdo (backhand de quem é destro)
	var fz := rel.dot(f)
	var h := bp.y - y
	if h > 1.8 and fz < 0.3:
		return "gancho" if (lx > -0.25 or type != Shots.SMASH) else "smash"
	if type == Shots.SMASH or type == Shots.SPECIAL or h > 1.95:
		return "smash"
	if fast or type == Shots.DEFENSE:
		return "block"
	var c := reach_center()
	var lat := absf(Vector2(bp.x - c.x, bp.z - c.z).dot(Vector2(left.x, left.z)))
	var sd := "back" if lx > 0.12 else "fore"
	if lat > 0.8 and h < 1.6:
		return "lunge_" + sd
	if h < 0.6:
		return "low_" + sd
	return sd


func _predict_style() -> void:
	if game == null:
		return
	var b: Ball = game.ball
	if not b.is_live():
		return
	var fast := b.vel.length() > 16.0
	for i in range(1, 30):
		var t := i * 0.03
		var bp := b.predict(t)
		var me := global_position + vel * t
		var c := me + net_dir() * 0.3
		if Vector2(bp.x - c.x, bp.z - c.z).length() < REACH and bp.y > 0.12:
			style = classify(bp - vel * t, pending_shot, fast)
			return


## Pulinho de preparação (split-step) quando o adversário bate na bola.
func split_step() -> void:
	if state == State.NORMAL and on_ground() and pending_shot < 0 and swing_t >= 1.0:
		split_t = 0.0
		vy = 2.0


## Chamado pelo jogo a cada frame em que este jogador pode rebater a bola.
func try_contact(ball: Ball, delta: float) -> Dictionary:
	if state == State.DIVE:
		var info := reach_info(ball.global_position)
		if info["in"]:
			last_style = "dive"
			return {"type": Shots.DEFENSE, "quality": info["quality"], "charge": 0.0, "style": "dive"}
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
		var st := classify(ball.global_position, shot, fast or ball.special != "")
		_start_swing(shot, ball.global_position, st)
		return {"type": shot, "quality": q, "charge": ch, "style": st}
	best_dist = minf(best_dist, d)
	return {}


func _start_swing(type: int, ball_pos: Vector3, st := "") -> void:
	swing_type = type
	swing_t = 0.0
	last_charge = charge()
	pending_shot = -1
	trail_pts.clear()
	trail_color = Shots.COLORS[type]
	if st == "":
		st = classify(ball_pos, type, false)
	style = st
	last_style = st
	if st == "gancho" and on_ground():
		vy = 2.6   # pulinho no gancho
	var local := global_transform.affine_inverse() * ball_pos
	swing_side = 1.0 if local.x <= 0.15 else -1.0


# ---------------------------------------------------------------- update

func update(dt: float) -> void:
	anim_time += dt
	state_t += dt
	if split_t >= 0.0:
		split_t += dt
		if split_t > 0.3:
			split_t = -1.0
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
			squash_v = -4.5 if split_t < 0.0 else -2.5
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


func _style_yaw(st: String) -> float:
	match st:
		"fore", "low_fore":
			return -0.45
		"back", "low_back":
			return 0.75
		"lunge_fore":
			return -0.6
		"lunge_back":
			return 0.9
		"gancho":
			return 1.25
		"smash":
			return -0.35
	return 0.0


func _update_normal(dt: float) -> void:
	if pending_shot >= 0:
		pending_t -= dt
		pending_age += dt
		style_t -= dt
		if style_t <= 0.0:
			style_t = 0.08
			_predict_style()
		if pending_t <= 0.0:
			_start_swing(pending_shot, global_position + net_dir(), style)
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
	# locomoção: corrida, passo lateral (de frente para a rede) ou recuo de costas
	var net_yaw := atan2(net_dir().x, net_dir().z)
	var face_target := net_yaw
	var flat := Vector2(vel.x, vel.z)
	var spd := flat.length()
	var fwd := Vector2(net_dir().x, net_dir().z)
	var along := flat.dot(fwd)
	var lat := absf(flat.dot(Vector2(-fwd.y, fwd.x)))
	if spd < 0.6:
		loco = "idle"
	elif spd > 4.6 and pending_shot < 0 and swing_t >= 1.0 and not serve_mode and along > -2.0:
		loco = "run"
		face_target = lerp_angle(net_yaw, atan2(vel.x, vel.z), 0.8)
	elif along < -0.6 and along * along > lat * lat:
		loco = "back"
	else:
		loco = "shuffle"
	if pending_shot >= 0:
		face_target = net_yaw + _style_yaw(style)
	elif swing_t < 1.0:
		face_target = net_yaw + _style_yaw(style) * (1.0 - swing_t)
	facing = lerp_angle(facing, face_target, 1.0 - exp(-12.0 * dt))
	if spd > 3.0 and on_ground():
		footstep_t -= dt
		if footstep_t <= 0.0:
			footstep_t = 0.22
			if game:
				game.sand_burst(global_position, 2)


# ---------------------------------------------------------------- animação

func _leg_drop(thigh: float, knee: float, spread := 0.0) -> float:
	# quanto o quadril precisa descer para o pé continuar no chão
	var cs := cos(spread)
	return THIGH * (1.0 - cos(thigh) * cs) + SHIN * (1.0 - cos(thigh + knee) * cs)


func _animate(dt: float) -> void:
	rotation.y = facing
	var spd := Vector2(vel.x, vel.z).length()
	var moving := clampf(spd / 5.5, 0.0, 1.0) if on_ground() and state == State.NORMAL else 0.0
	run_phase += dt * (6.0 + spd * 1.6)
	var s := sin(run_phase)
	var breathe := sin(anim_time * 3.0) * 0.025
	var lv := global_transform.basis.inverse() * vel
	lean = lean.lerp(Vector2(lv.x, lv.z) / 6.5, 1.0 - exp(-8.0 * dt))
	var run := moving if loco == "run" else 0.0
	var shuf := moving if loco == "shuffle" else 0.0
	var bk := moving if loco == "back" else 0.0
	var ready := 1.0 - run
	var p := {
		"Spine": Vector3(0.12 + lean.y * 0.25 + breathe - bk * 0.15, 0.0, -lean.x * 0.18),
		"Chest": Vector3(0.06 * ready + 0.12 * run, 0.0, 0.0),
		"Neck": Vector3(-0.08, 0.0, 0.0),
		"Head": Vector3(-0.1 - 0.1 * run, 0.0, 0.0),
		"UpperArm.R": Vector3(-0.6 * ready + (-0.3 - s * 0.6) * run, 0.25 * ready, -0.3 - shuf * 0.15),
		"LowerArm.R": Vector3(-1.05 * ready - 1.3 * run, 0.0, 0.0),
		"Hand.R": Vector3(0.25, 0.0, 0.0),
		"UpperArm.L": Vector3(-0.45 * ready + (-0.2 + s * 0.8) * run, 0.0, 0.3 + shuf * 0.15),
		"LowerArm.L": Vector3(-0.95 * ready - 1.4 * run, 0.0, 0.0),
	}
	# pernas: base atlética + corrida + passo lateral + recuo
	var L := {
		"tr": -0.45 * ready + (-0.3 + 0.85 * s) * run + 0.35 * s * bk,
		"tl": -0.45 * ready + (-0.3 - 0.85 * s) * run - 0.35 * s * bk,
		"kr": 0.8 * ready + (0.45 + 1.2 * maxf(0.0, s)) * run + 0.4 * maxf(0.0, -s) * bk,
		"kl": 0.8 * ready + (0.45 + 1.2 * maxf(0.0, -s)) * run + 0.4 * maxf(0.0, s) * bk,
		"zr": -0.08 - shuf * (0.12 + 0.22 * maxf(0.0, s)),
		"zl": 0.08 + shuf * (0.12 + 0.22 * maxf(0.0, -s)),
		"crouch": 0.0, "tilt": 0.0,
	}
	if split_t >= 0.0:
		L["zr"] = -0.28
		L["zl"] = 0.28
	var sharp := 14.0
	var body_rot := Vector3.ZERO

	if state == State.NORMAL and pending_shot >= 0:
		_windup_pose(pending_shot, style, p, L)
		var ch := charge()
		L["crouch"] = float(L["crouch"]) + 0.03 + ch * 0.05
		body.position.x = (randf() - 0.5) * 0.03 * ch if int(anim_time * 30.0) % 2 == 0 else 0.0
	else:
		body.position.x = 0.0
	if swing_t < 1.0 and swing_type >= 0:
		_strike_pose(swing_type, style, swing_t, p, L)
		sharp = 32.0
	if not on_ground() and split_t < 0.0:
		L["tr"] = -0.9
		L["kr"] = 1.3
		L["tl"] = 0.2
		L["kl"] = 0.6
		if serve_mode or style == "smash" or pending_shot == Shots.SMASH:
			if not (swing_t < 1.0):
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
			L["tr"] = 0.25 * k
			L["tl"] = 0.1 * k
			L["kr"] = 0.5 * k
			L["kl"] = 0.3 * k
			L["zr"] = -0.1
			L["zl"] = 0.1
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
			L["tr"] = -0.15
			L["tl"] = -0.15
			L["kr"] = 0.3
			L["kl"] = 0.3
	var tr: float = L["tr"]
	var tl: float = L["tl"]
	var kr: float = L["kr"]
	var kl: float = L["kl"]
	var zr: float = L["zr"]
	var zl: float = L["zl"]
	p["UpperLeg.R"] = Vector3(tr, 0.0, zr)
	p["UpperLeg.L"] = Vector3(tl, 0.0, zl)
	p["LowerLeg.R"] = Vector3(kr, 0.0, 0.0)
	p["LowerLeg.L"] = Vector3(kl, 0.0, 0.0)
	p["Foot.R"] = Vector3(-(tr + kr) * 0.8, 0.0, -zr * 0.7)
	p["Foot.L"] = Vector3(-(tl + kl) * 0.8, 0.0, -zl * 0.7)
	var sp: Vector3 = p["Spine"]
	sp.z += float(L["tilt"])
	p["Spine"] = sp
	var drop := minf(_leg_drop(tr, kr, zr), _leg_drop(tl, kl, zl))
	if not on_ground() or state == State.DIVE:
		drop = 0.0
	var bob := absf(cos(run_phase)) * 0.05 * run + absf(sin(run_phase)) * 0.03 * shuf
	rig.apply(p, 1.0 - exp(-sharp * dt), Vector3(0.0, -drop - float(L["crouch"]) + bob, 0.0))
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


# ---------------------------------------------------------------- poses dos golpes
# Eixos do personagem: X = esquerda, Y = cima, Z = frente. Raquete na mão direita (-X).
# Braço: x negativo levanta para a frente; y gira em volta do corpo; z abre para o lado.

func _low_legs(L: Dictionary) -> void:
	L["tr"] = -0.75
	L["tl"] = -0.75
	L["kr"] = 1.45
	L["kl"] = 1.45
	L["crouch"] = 0.06


func _lunge_legs(L: Dictionary, to_left: bool) -> void:
	# passo largo para o lado da bola, perna de trás esticada
	if to_left:
		L["zl"] = 0.7
		L["tl"] = -0.5
		L["kl"] = 1.2
		L["zr"] = -0.15
		L["tr"] = -0.1
		L["kr"] = 0.2
		L["tilt"] = 0.25
	else:
		L["zr"] = -0.7
		L["tr"] = -0.5
		L["kr"] = 1.2
		L["zl"] = 0.15
		L["tl"] = -0.1
		L["kl"] = 0.2
		L["tilt"] = -0.25
	L["crouch"] = 0.04


func _windup_pose(type: int, st: String, r: Dictionary, L: Dictionary) -> void:
	match st:
		"fore", "low_fore":
			r["UpperArm.R"] = Vector3(-1.1 if type != Shots.LOB else 0.35, -1.3, -0.3)
			r["LowerArm.R"] = Vector3(-0.6, 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-1.2, 0.45, 0.25)
			r["LowerArm.L"] = Vector3(-0.4, 0.0, 0.0)
			r["Chest"] = Vector3(0.08, -0.7, 0.0)
			r["Spine"] = Vector3(0.14, -0.3, 0.0)
			if st == "low_fore":
				_low_legs(L)
				r["Spine"] = Vector3(0.45, -0.3, 0.0)
				r["UpperArm.R"] = Vector3(-0.4, -1.3, -0.3)
		"back", "low_back":
			r["UpperArm.R"] = Vector3(-1.1 if type != Shots.LOB else 0.1, 1.35, 0.25)
			r["LowerArm.R"] = Vector3(-1.45, 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-0.9, 0.9, 0.1)
			r["LowerArm.L"] = Vector3(-1.3, 0.0, 0.0)
			r["Chest"] = Vector3(0.1, 0.85, 0.0)
			r["Spine"] = Vector3(0.16, 0.35, 0.0)
			if st == "low_back":
				_low_legs(L)
				r["Spine"] = Vector3(0.45, 0.35, 0.0)
				r["UpperArm.R"] = Vector3(-0.45, 1.3, 0.25)
		"lunge_fore":
			_lunge_legs(L, false)
			r["UpperArm.R"] = Vector3(-0.9, -0.9, -0.9)
			r["LowerArm.R"] = Vector3(-0.3, 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-0.3, 0.0, 0.9)
			r["Chest"] = Vector3(0.2, -0.45, 0.0)
		"lunge_back":
			_lunge_legs(L, true)
			r["UpperArm.R"] = Vector3(-1.0, 1.25, 0.4)
			r["LowerArm.R"] = Vector3(-0.6, 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-0.2, 0.0, -0.4)
			r["Chest"] = Vector3(0.2, 0.7, 0.0)
		"block":
			L["tr"] = -0.6
			L["tl"] = -0.6
			L["kr"] = 1.1
			L["kl"] = 1.1
			L["zr"] = -0.3
			L["zl"] = 0.3
			r["UpperArm.R"] = Vector3(-1.25, 0.35, -0.1)
			r["LowerArm.R"] = Vector3(-0.95, 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-1.0, -0.2, 0.3)
			r["LowerArm.L"] = Vector3(-1.1, 0.0, 0.0)
			r["Spine"] = Vector3(0.3, 0.0, 0.0)
			r["Head"] = Vector3(-0.2, 0.0, 0.0)
		"gancho":
			r["UpperArm.R"] = Vector3(-2.6, 1.05, 0.6)
			r["LowerArm.R"] = Vector3(-1.1, 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-1.3, 0.0, 1.1)
			r["LowerArm.L"] = Vector3(-0.3, 0.0, 0.0)
			r["Spine"] = Vector3(-0.3, 0.2, 0.0)
			r["Chest"] = Vector3(-0.15, 0.5, 0.0)
			r["Head"] = Vector3(-0.55, 0.0, 0.0)
		_:   # smash / super
			r["UpperArm.R"] = Vector3(-2.9, -0.45, -0.3)
			r["LowerArm.R"] = Vector3(-1.9, 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-2.7, 0.0, 0.2)
			r["LowerArm.L"] = Vector3(-0.2, 0.0, 0.0)
			r["Spine"] = Vector3(-0.25, -0.2, 0.0)
			r["Chest"] = Vector3(-0.15, -0.45, 0.0)
			r["Head"] = Vector3(-0.45, 0.0, 0.0)


func _strike_pose(type: int, st: String, t: float, r: Dictionary, L: Dictionary) -> void:
	var e := 1.0 - pow(1.0 - t, 3.0)
	var lob := type == Shots.LOB or type == Shots.DEFENSE
	var soft := type == Shots.DROP
	var amp := 0.55 if soft else 1.0
	match st:
		"fore", "low_fore":
			var x0 := 0.35 if lob else -1.1
			var x1 := -2.4 if lob else -1.3
			if st == "low_fore":
				_low_legs(L)
				x0 = 0.2 if lob else -0.4
				x1 = -1.9 if lob else -0.8
				r["Spine"] = Vector3(lerpf(0.45, 0.25, e), lerpf(-0.3, 0.3, e), 0.0)
			else:
				r["Spine"] = Vector3(0.14, lerpf(-0.3, 0.3, e) * amp, 0.0)
			r["UpperArm.R"] = Vector3(lerpf(x0, x1, e), lerpf(-1.3, 1.1 * amp, e), -0.2)
			r["LowerArm.R"] = Vector3(lerpf(-0.6, -1.25, e), 0.0, 0.0)
			r["UpperArm.L"] = Vector3(lerpf(-1.2, -0.3, e), lerpf(0.45, -0.4, e), 0.4)
			r["Chest"] = Vector3(0.08, lerpf(-0.7, 0.6 * amp, e), 0.0)
			L["tl"] = float(L["tl"]) - 0.3 * sin(t * PI)
			L["kl"] = float(L["kl"]) + 0.2 * sin(t * PI)
		"back", "low_back":
			var bx0 := 0.1 if lob else -1.1
			var bx1 := -2.3 if lob else -1.35
			if st == "low_back":
				_low_legs(L)
				bx0 = 0.1 if lob else -0.45
				bx1 = -1.8 if lob else -0.85
			r["UpperArm.R"] = Vector3(lerpf(bx0, bx1, e), lerpf(1.35, -1.2 * amp, e), lerpf(0.25, -0.45, e))
			r["LowerArm.R"] = Vector3(lerpf(-1.45, -0.1, e), 0.0, 0.0)
			r["UpperArm.L"] = Vector3(lerpf(-0.9, 0.3, e), lerpf(0.9, 0.0, e), lerpf(0.1, 0.7, e))
			r["LowerArm.L"] = Vector3(-0.5, 0.0, 0.0)
			r["Chest"] = Vector3(0.1, lerpf(0.85, -0.35 * amp, e), 0.0)
			r["Spine"] = Vector3(0.16 if st == "back" else 0.4, lerpf(0.35, -0.15, e), 0.0)
			L["tr"] = float(L["tr"]) - 0.3 * sin(t * PI)
			L["kr"] = float(L["kr"]) + 0.2 * sin(t * PI)
		"lunge_fore":
			_lunge_legs(L, false)
			r["UpperArm.R"] = Vector3(lerpf(-0.9, -1.2, e), lerpf(-0.9, 0.3, e), lerpf(-0.9, -0.6, e))
			r["LowerArm.R"] = Vector3(-0.3, 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-0.3, 0.0, 0.9)
			r["Chest"] = Vector3(0.2, lerpf(-0.45, 0.1, e), 0.0)
		"lunge_back":
			_lunge_legs(L, true)
			r["UpperArm.R"] = Vector3(lerpf(-1.0, -1.3, e), lerpf(1.25, 0.3, e), lerpf(0.4, 0.1, e))
			r["LowerArm.R"] = Vector3(lerpf(-0.6, -0.1, e), 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-0.2, 0.0, -0.4)
			r["Chest"] = Vector3(0.2, lerpf(0.7, 0.1, e), 0.0)
		"block":
			L["tr"] = -0.6
			L["tl"] = -0.6
			L["kr"] = 1.1
			L["kl"] = 1.1
			L["zr"] = -0.3
			L["zl"] = 0.3
			r["UpperArm.R"] = Vector3(lerpf(-1.25, -1.5, e), 0.3, -0.1)
			r["LowerArm.R"] = Vector3(lerpf(-0.95, -0.45, e), 0.0, 0.0)
			r["UpperArm.L"] = Vector3(-1.0, -0.2, 0.3)
			r["LowerArm.L"] = Vector3(-1.1, 0.0, 0.0)
			r["Spine"] = Vector3(lerpf(0.3, 0.4, e), 0.0, 0.0)
		"dive":
			pass
		"gancho":
			# arco por cima da cabeça, do lado esquerdo para o direito
			r["UpperArm.R"] = Vector3(lerpf(-2.6, -2.2, e), lerpf(1.05, -1.3, e), lerpf(0.6, -0.9, e))
			r["LowerArm.R"] = Vector3(lerpf(-1.1, -0.15, e), 0.0, 0.0)
			r["UpperArm.L"] = Vector3(lerpf(-1.3, -0.4, e), 0.0, lerpf(1.1, 0.6, e))
			r["Spine"] = Vector3(lerpf(-0.3, 0.15, e), lerpf(0.2, -0.3, e), 0.0)
			r["Chest"] = Vector3(lerpf(-0.15, 0.1, e), lerpf(0.5, -0.5, e), 0.0)
			r["Head"] = Vector3(lerpf(-0.55, -0.1, e), 0.0, 0.0)
		_:
			if type == Shots.SPECIAL:
				r["Spine"] = Vector3(lerpf(-0.25, 0.4, e), 0.0, 0.0)
				r["UpperArm.R"] = Vector3(lerpf(-2.9, -0.8, e), lerpf(-0.45, 0.5, e), -0.6)
				r["LowerArm.R"] = Vector3(lerpf(-1.9, -0.1, e), 0.0, 0.0)
				r["UpperArm.L"] = Vector3(-1.6, 0.0, 1.0)
			else:
				r["UpperArm.R"] = Vector3(lerpf(-2.9, -0.6, e), lerpf(-0.45, 0.5, e), -0.2)
				r["LowerArm.R"] = Vector3(lerpf(-1.9, -0.15, e), 0.0, 0.0)
				r["UpperArm.L"] = Vector3(lerpf(-2.7, -0.5, e), 0.0, 0.25)
				r["Spine"] = Vector3(lerpf(-0.25, 0.45, e), lerpf(-0.2, 0.25, e), 0.0)
				r["Chest"] = Vector3(lerpf(-0.15, 0.3, e), lerpf(-0.45, 0.35, e), 0.0)
				r["Head"] = Vector3(lerpf(-0.45, 0.2, e), 0.0, 0.0)

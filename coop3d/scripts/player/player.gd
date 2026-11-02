class_name Player
extends CharacterBody3D
## Playable character. Works with any gravity direction (flat islands and
## spherical planetoids) by reading get_gravity() and re-orienting itself.
##
## Shared moves: run, variable-height jump (coyote time + jump buffer),
## dash (ground dash + jump = long jump), ground pound, rescue bubble.
## Lumi: double jump, lantern hover, Light Tether (pulls the partner to her).
## Bolota: heavy (heavy plates, cracks), carries/throws Lumi and crates.

signal landed(impact: float)

const SHADOW_TEX_SIZE := 64

var index := 0
var kind := "lumi"
var level: Node
var partner: Player
var rig: CharacterRig
var visual: Node3D
var data: Dictionary

# tuning (filled in setup from the character profile)
var max_speed := 8.0
var accel := 60.0
var decel := 50.0
var air_accel := 32.0
var air_decel := 10.0
var jump_v := 11.0
var g_up := 30.0
var g_down := 46.0
var can_double := false
var can_hover := false
var heavy := false
var weight := 1

var up := Vector3.UP
var facing := Vector3.BACK
var state := "normal"
var t_state := 0.0
var controlled := true
var coyote := 0.0
var buffer := 0.0
var jumps_left := 0
var air_dash_used := false
var hover_time := 0.0
var dash_dir := Vector3.ZERO
var dash_cd := 0.0
var tether_cd := 0.0
var invuln := 0.0
var carrying: Node3D = null
var carried_by: Player = null
var safe_pos := Vector3.ZERO
var safe_up := Vector3.UP
var _safe_t := 0.0
var _was_on_floor := true
var _prev_vel := Vector3.ZERO
var _prev_facing := Vector3.BACK
var _turn := 0.0
var _path := {}  # launch/pull curve data
var wind := Vector3.ZERO
var _shadow: MeshInstance3D
var _trail: CPUParticles3D
var _bubble: MeshInstance3D
var _light: OmniLight3D
var _beam: MeshInstance3D
var _beam_t := 0.0
var _run_dust_t := 0.0
var _air_lock := 0.0  # ignore stale floor contact right after throws/bounces


func setup(i: int, lvl: Node) -> void:
	index = i
	level = lvl
	data = Game.CHARACTERS[i]
	kind = data["kind"]
	name = data["name"]
	if kind == "lumi":
		max_speed = 8.2
		accel = 62.0
		decel = 55.0
		air_accel = 34.0
		_set_jump(2.0, 0.36, 0.3)
		can_double = true
		can_hover = true
		weight = 1
	else:
		max_speed = 7.3
		accel = 52.0
		decel = 48.0
		air_accel = 28.0
		_set_jump(2.25, 0.38, 0.28)
		heavy = true
		weight = 2

	collision_layer = 2
	collision_mask = 1 | 2 | 4
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	floor_constant_speed = true
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_UPWARD_VELOCITY
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34 if kind == "lumi" else 0.42
	cap.height = 1.1 if kind == "lumi" else 1.15
	shape.shape = cap
	shape.position = Vector3(0, cap.height * 0.5, 0)
	add_child(shape)

	visual = Node3D.new()
	add_child(visual)
	rig = CharacterRig.new()
	visual.add_child(rig)
	rig.setup(load(data["model"]), kind)
	rig.set_step_callback(_on_step)

	_light = OmniLight3D.new()
	_light.light_color = data["light"]
	_light.light_energy = 0.6
	_light.omni_range = 3.0
	_light.position = Vector3(0, 0.6, 0.35 if kind == "lumi" else 0.0)
	_light.shadow_enabled = false
	visual.add_child(_light)

	_make_shadow()
	_trail = Vfx.trail(visual, data["light"], 40)
	_trail.position = Vector3(0, 0.5, 0)
	_make_bubble()
	safe_pos = global_position


func _set_jump(h: float, t_peak: float, t_down: float) -> void:
	jump_v = 2.0 * h / t_peak
	g_up = 2.0 * h / (t_peak * t_peak)
	g_down = 2.0 * h / (t_down * t_down)


# ------------------------------------------------------------------ input
func _pi() -> int:
	return index if Game.coop else 0


func pressed(a: String) -> bool:
	return controlled and Input.is_action_pressed(Game.act(_pi(), a))


func just(a: String) -> bool:
	return controlled and Input.is_action_just_pressed(Game.act(_pi(), a))


func _input_vec() -> Vector2:
	if not controlled:
		return Vector2.ZERO
	var p := _pi()
	return Input.get_vector(Game.act(p, "left"), Game.act(p, "right"), Game.act(p, "fwd"), Game.act(p, "back"))


func _wish(inp: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null or inp.length() < 0.01:
		return Vector3.ZERO
	var f := -cam.global_basis.z
	f = f - up * f.dot(up)
	if f.length() < 0.2:
		f = cam.global_basis.y - up * cam.global_basis.y.dot(up)
	f = f.normalized()
	var r := f.cross(up).normalized()
	var w := r * inp.x - f * inp.y
	return w.limit_length(1.0)


# ---------------------------------------------------------------- physics
func _physics_process(delta: float) -> void:
	t_state += delta
	_air_lock -= delta
	invuln -= delta
	dash_cd -= delta
	tether_cd -= delta
	_update_up(delta)
	var wish := _wish(_input_vec())

	match state:
		"normal", "hover", "thrown", "stunned":
			_move_normal(delta, wish)
		"dash":
			_move_dash(delta, wish)
		"pound_wind":
			velocity = velocity.lerp(up * 1.5, 1.0 - exp(-12.0 * delta))
			move_and_slide()
			if t_state > 0.22:
				_set_state("pound_fall")
				velocity = -up * 34.0
				Sfx.play("whoosh", 0.7)
		"pound_fall":
			velocity = -up * 34.0
			move_and_slide()
			if is_on_floor() or t_state > 3.0:
				_pound_land()
		"carried":
			_follow_carrier()
		"launch", "pulled":
			_follow_path(delta)
		"bubble":
			_move_bubble(delta)
		"celebrate", "frozen":
			velocity = velocity.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
			velocity -= up * g_down * delta * 0.5
			move_and_slide()

	_update_facing(delta, wish)
	_update_carry()
	_post_move(delta)


func _update_up(delta: float) -> void:
	if state in ["carried", "bubble"]:
		return
	var g := get_gravity()
	var target := -g.normalized() if g.length_squared() > 0.01 else Vector3.UP
	if up.dot(target) < -0.95:
		target = (target + facing * 0.2).normalized()
	up = up.slerp(target, 1.0 - exp(-10.0 * delta)).normalized()
	up_direction = up


func _move_normal(delta: float, wish: Vector3) -> void:
	var on_floor := is_on_floor() and _air_lock <= 0.0
	var v_up := velocity.dot(up)
	var v_tan := velocity - up * v_up

	if on_floor:
		coyote = 0.11
		jumps_left = 1 if can_double else 0
		air_dash_used = false
		hover_time = 0.0
		if state == "thrown":
			_set_state("normal")
	else:
		coyote -= delta
	if just("jump"):
		buffer = 0.13
	else:
		buffer -= delta

	if state == "stunned":
		wish = Vector3.ZERO
		if t_state > 0.45 and on_floor:
			_set_state("normal")

	var spd := max_speed * (0.8 if carrying else 1.0)
	var target := wish * spd
	var a: float
	if on_floor:
		a = accel if wish.length() > 0.05 else decel
		if wish.length() > 0.05 and v_tan.length() > 3.0 and v_tan.normalized().dot(wish) < -0.3:
			a *= 2.2  # skid turn
			_run_dust_t -= delta * 4.0
	else:
		a = air_accel if wish.length() > 0.05 else air_decel
		if state == "thrown":
			a *= 0.5
	v_tan = v_tan.move_toward(target, a * delta)

	# --- jumps
	if buffer > 0.0 and state != "stunned":
		if on_floor or coyote > 0.0:
			v_up = jump_v * (0.85 if carrying else 1.0)
			_jumped(false)
		elif jumps_left > 0 and not carrying:
			jumps_left -= 1
			v_up = jump_v * 0.86
			_jumped(true)
			if wish.length() > 0.1:
				v_tan = wish * maxf(v_tan.length(), spd * 0.8)

	# --- hover (Lumi): hold jump while falling (after the double jump, or
	# right away inside an updraft)
	var updraft := wind.dot(up)
	if can_hover and state in ["normal", "thrown"] and not on_floor and pressed("jump") and v_up < -1.0 \
			and (jumps_left == 0 or updraft > 1.0) and hover_time < 1.5 and buffer <= 0.0:
		_set_state("hover")
		Sfx.play("swish", 1.6)
	if state == "hover":
		if updraft < 5.0:
			hover_time += delta
		v_up = move_toward(v_up, minf(-1.4 + updraft * 0.18, 12.0), 40.0 * delta)
		if not pressed("jump") or hover_time > 1.5 or on_floor:
			_set_state("normal")
	else:
		var g := g_up if v_up > 0.0 else g_down
		if v_up > 0.0 and not pressed("jump") and state != "thrown" and _air_lock <= 0.0:
			g *= 2.4  # short hop when jump is released early
		if absf(v_up) < 1.6 and pressed("jump"):
			g *= 0.55  # apex hang time
		v_up -= g * delta
		v_up += wind.dot(up) * delta * (0.6 if heavy else 1.0)
	v_tan += (wind - up * wind.dot(up)) * delta
	v_up = maxf(v_up, -30.0)
	velocity = v_tan + up * v_up
	move_and_slide()
	_try_step(v_tan)
	_check_hits()

	if state in ["normal", "hover", "thrown"]:
		if just("dash") and dash_cd <= 0.0 and not carrying and (on_floor or not air_dash_used):
			_start_dash(wish)
		elif just("pound") and not on_floor and not carrying:
			_set_state("pound_wind")
			velocity = up * 2.0
			rig.anticipate(1.0)
			Sfx.play("swish", 0.7)
		elif just("grab"):
			_grab()


## Step-up assist: climb small ledges (island rims, bridge lips) without
## having to jump, like most commercial platformers do.
func _try_step(v_tan: Vector3) -> void:
	if not is_on_wall() or v_tan.length() < 0.5:
		return
	if not (is_on_floor() or _was_on_floor):
		return
	var step := 0.5
	var xf := global_transform
	if test_move(xf, up * step):
		return
	var fwd := v_tan.normalized() * 0.3
	var up_xf := xf.translated(up * step)
	if test_move(up_xf, fwd):
		return
	var ahead := up_xf.translated(fwd)
	var col := KinematicCollision3D.new()
	if test_move(ahead, -up * (step + 0.05), col) and col.get_normal().dot(up) > 0.7:
		global_position = ahead.origin + col.get_travel()


func _jumped(double: bool) -> void:
	buffer = 0.0
	coyote = 0.0
	rig.pop(0.32 if not double else 0.25)
	Sfx.play("jump", 1.1 if kind == "lumi" else 0.85, -4.0)
	if double:
		Vfx.ring(global_position, up, data["light"], 1.4, 0.35)
		Vfx.burst(global_position, data["light"], 8, 3.0, 0.7, up)
		Sfx.play("pop", 1.4, -6.0)
	else:
		Vfx.dust(global_position, up, 5, 0.8)


func _start_dash(wish: Vector3) -> void:
	dash_dir = wish.normalized() if wish.length() > 0.1 else facing
	air_dash_used = not is_on_floor()
	dash_cd = 0.4
	_set_state("dash")
	Sfx.play("dash", 1.2 if kind == "lumi" else 0.9)
	Vfx.speedlines(0.35)
	_trail.emitting = true
	rig.pop(-0.2)


func _move_dash(delta: float, wish: Vector3) -> void:
	var dur := 0.2
	var k := 1.0 - t_state / dur
	var speed := lerpf(8.0, 16.5, clampf(k, 0.0, 1.0))
	if wish.length() > 0.1:
		dash_dir = dash_dir.slerp(wish.normalized(), 1.0 - exp(-3.0 * delta)).normalized()
	var v_up := velocity.dot(up)
	v_up = maxf(v_up - g_down * 0.15 * delta, -4.0) if not is_on_floor() else 0.0
	if air_dash_used and t_state < delta * 1.5:
		v_up = 2.5
	velocity = dash_dir * speed + up * v_up
	move_and_slide()
	_check_hits()
	# ground dash + jump = long jump
	if just("jump") and is_on_floor():
		velocity = dash_dir * 13.0 + up * jump_v * 0.72
		_set_state("normal")
		jumps_left = 1 if can_double else 0
		_jumped(false)
		Vfx.speedlines(0.5)
		_trail.emitting = true
		get_tree().create_timer(0.5).timeout.connect(func(): _trail.emitting = false)
		return
	if t_state > dur:
		_set_state("normal")
		_trail.emitting = false
		velocity = dash_dir * 8.0 + up * velocity.dot(up)


func _pound_land() -> void:
	_set_state("normal")
	t_state = 0.0
	var power := 1.0 if heavy else 0.6
	rig.land(34.0)
	Juice.hitstop(0.07 if heavy else 0.04)
	Juice.shake(0.45 * power)
	Juice.punch(-up, 0.25 * power)
	Sfx.play("thud", 0.8 if heavy else 1.2)
	Sfx.play("land", 0.7, -2.0)
	Vfx.ring(global_position, up, Color(1, 0.85, 0.55), 3.5 * power, 0.5)
	Vfx.dust(global_position, up, 14, 1.6 * power)
	velocity = up * 5.0
	var hit := []
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c and c.has_method("on_pound") and not c in hit:
			hit.append(c)
			c.on_pound(self)
	level.on_pound(self, global_position, 2.6 if heavy else 1.8, hit)


# -------------------------------------------------------- grab and throw
func _grab() -> void:
	if carrying:
		_throw()
		return
	if kind == "bolota":
		if partner and partner.state in ["normal", "hover", "thrown", "stunned"] and partner.carrying == null \
				and partner.global_position.distance_to(global_position) < 1.9:
			_pick(partner)
			return
		var best: Node3D = null
		var bd := 1.9
		for c in get_tree().get_nodes_in_group("crate"):
			var d: float = c.global_position.distance_to(global_position + up * 0.4)
			if d < bd and c.can_pick():
				best = c
				bd = d
		if best:
			_pick(best)
	elif kind == "lumi":
		_tether()


func _pick(target: Node3D) -> void:
	carrying = target
	rig.pop(-0.25)
	Sfx.play("pop", 0.8)
	if target is Player:
		target.carried_by = self
		target._set_state("carried")
		target.collision_mask = 0
		target.collision_layer = 0
		target.rig.pop(0.3)
		level.toast("%s ergueu %s!" % [name, target.name], data["color"])
	else:
		target.pick(self)


func _throw() -> void:
	var t := carrying
	carrying = null
	var dir := facing
	var moving := _input_vec().length() > 0.3
	# moving: long forward throw; standing still: straight up (or set a crate down)
	var vel := dir * 10.0 + up * 14.0 + velocity * 0.4 if moving else dir * 1.5 + up * 17.0
	rig.anticipate(0.6)
	rig.pop(0.25)
	Sfx.play("whoosh", 1.2)
	Juice.punch(dir, 0.1)
	if t is Player:
		t.carried_by = null
		t.collision_mask = 1 | 2 | 4
		t.collision_layer = 2
		t.velocity = vel
		t.jumps_left = 1 if t.can_double else 0
		t.air_dash_used = false
		t._air_lock = 0.15
		t._set_state("thrown")
		t._trail.emitting = true
		get_tree().create_timer(0.6).timeout.connect(func(): t._trail.emitting = false)
		Vfx.burst(t.global_position, data["light"], 10, 4.0)
	elif moving:
		t.throw(vel * 0.8)
	else:
		t.global_position = global_position + facing * 1.3 + up * 0.6
		t.throw(velocity * 0.5 + up * 1.0)


func drop_carry() -> void:
	if carrying is Player:
		carrying.carried_by = null
		carrying.collision_mask = 1 | 2 | 4
		carrying.collision_layer = 2
		carrying._set_state("normal")
	elif carrying:
		carrying.throw(Vector3.ZERO)
	carrying = null


func _update_carry() -> void:
	if carrying == null:
		return
	if not is_instance_valid(carrying):
		carrying = null
		return
	var sock := global_position + up * 1.3 + facing * 0.05
	if carrying is Player:
		pass  # the carried player follows in _follow_carrier
	else:
		carrying.global_position = sock
		carrying.global_basis = global_basis


func _follow_carrier() -> void:
	if carried_by == null or not is_instance_valid(carried_by):
		_set_state("normal")
		collision_mask = 1 | 2 | 4
		collision_layer = 2
		return
	up = carried_by.up
	up_direction = up
	facing = carried_by.facing
	global_position = carried_by.global_position + up * 1.25
	velocity = carried_by.velocity
	if just("jump"):
		carried_by.carrying = null
		carried_by = null
		collision_mask = 1 | 2 | 4
		collision_layer = 2
		velocity = up * jump_v * 0.8 + facing * 2.0
		_set_state("normal")
		jumps_left = 1 if can_double else 0
		_jumped(false)


# -------------------------------------------------------- light tether
func _tether() -> void:
	if partner == null or tether_cd > 0.0:
		return
	var d := partner.global_position.distance_to(global_position)
	if d > 16.0 or d < 1.5 or not partner.state in ["normal", "stunned", "thrown"] or partner.carrying is Player:
		Sfx.play("tock", 0.6)
		level.toast("Elo de Luz: o Bolota precisa estar a até 16 m", data["color"])
		tether_cd = 0.4
		return
	tether_cd = 1.0
	partner.drop_carry()
	partner.start_path(self, global_position + up * 0.4 - facing * 0.9, maxf(0.35, d * 0.035), 1.5 + d * 0.12, "pulled")
	Sfx.play("zap", 1.0)
	Juice.shake(0.12)
	_beam_t = partner._path["dur"] + 0.05
	rig.pop(0.2)


## Follow a quadratic Bézier (launch rings, tether pulls).
func start_path(follow: Node3D, to: Vector3, dur: float, height: float, kind_state := "launch") -> void:
	_path = {"p0": global_position, "to": to, "follow": follow, "dur": dur, "h": height}
	if follow:
		_path["offset"] = to - follow.global_position
	_set_state(kind_state)
	collision_mask = 0
	_trail.emitting = true
	rig.pop(0.35)


func _follow_path(delta: float) -> void:
	var dur: float = _path["dur"]
	var t := clampf(t_state / dur, 0.0, 1.0)
	var p0: Vector3 = _path["p0"]
	var p2: Vector3 = _path["to"]
	var f = _path.get("follow")
	if f and is_instance_valid(f) and _path.has("offset"):
		p2 = f.global_position + _path["offset"]
	var g := get_gravity()
	var lift := -g.normalized() if g.length_squared() > 0.01 else Vector3.UP
	var p1 := (p0 + p2) * 0.5 + lift * float(_path["h"])
	var e := t * t * (3.0 - 2.0 * t) if state == "pulled" else t
	var a := p0.lerp(p1, e)
	var b := p1.lerp(p2, e)
	var np := a.lerp(b, e)
	velocity = (np - global_position) / maxf(delta, 0.0001)
	global_position = np
	var tan := (b - a)
	tan -= up * tan.dot(up)
	if tan.length() > 0.01:
		facing = tan.normalized()
	if t >= 1.0:
		collision_mask = 1 | 2 | 4
		_trail.emitting = false
		velocity = velocity.limit_length(10.0) * 0.4
		jumps_left = 1 if can_double else 0
		air_dash_used = false
		_set_state("normal")


# --------------------------------------------------------------- bubble
func enter_bubble() -> void:
	if state == "bubble":
		return
	drop_carry()
	if carried_by:
		carried_by.carrying = null
		carried_by = null
	_set_state("bubble")
	collision_mask = 0
	collision_layer = 0
	velocity = Vector3.ZERO
	_bubble.visible = true
	_bubble.scale = Vector3.ONE * 0.2
	_bubble.create_tween().tween_property(_bubble, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("bubble", 0.8)


func _move_bubble(delta: float) -> void:
	var target: Vector3 = level.respawn_point_for(self)
	var tup: Vector3 = level.respawn_up_for(self)
	up = up.slerp(tup, 1.0 - exp(-3.0 * delta)).normalized()
	var goal := target + tup * 1.6
	global_position = global_position.lerp(goal, 1.0 - exp(-2.2 * delta)) + up * sin(t_state * 3.0) * 0.01
	var near := global_position.distance_to(goal) < 1.4
	if (near and t_state > 1.2) and (just("jump") or t_state > 2.6 or not controlled):
		pop_bubble()


func pop_bubble() -> void:
	_bubble.visible = false
	collision_mask = 1 | 2 | 4
	collision_layer = 2
	velocity = up * 7.0
	invuln = 1.0
	_set_state("normal")
	Sfx.play("pop", 1.0)
	Sfx.play("bubble", 1.5, -4.0)
	Vfx.burst(global_position + up * 0.5, Color(0.8, 0.95, 1.0), 16, 5.0)
	Vfx.ring(global_position + up * 0.5, up, Color(0.7, 0.9, 1.0), 2.0, 0.4)
	rig.pop(0.35)


# --------------------------------------------------------- interactions
func hurt(from: Vector3) -> void:
	if invuln > 0.0 or state in ["bubble", "carried", "launch", "pulled", "celebrate", "pound_fall"]:
		return
	drop_carry()
	invuln = 1.4
	var away := global_position - from
	away -= up * away.dot(up)
	away = away.normalized() if away.length() > 0.01 else -facing
	velocity = away * 8.0 + up * 8.0
	_set_state("stunned")
	rig.flash(1.0)
	rig.pop(-0.3)
	Sfx.play("hurt")
	Juice.hitstop(0.06)
	Juice.shake(0.3)
	Vfx.burst(global_position + up * 0.6, Color(1, 0.5, 0.6), 10, 5.0)
	level.on_player_hurt(self)


func bounce(strength: float) -> void:
	if state in ["bubble", "carried", "launch", "pulled"]:
		return
	var v_tan := velocity - up * velocity.dot(up)
	velocity = v_tan + up * strength
	jumps_left = 1 if can_double else 0
	air_dash_used = false
	_set_state("thrown")
	_air_lock = 0.15
	rig.pop(0.45)
	coyote = 0.0
	buffer = 0.0


func celebrate() -> void:
	drop_carry()
	_set_state("celebrate")


func freeze(on: bool) -> void:
	_set_state("frozen" if on else "normal")


func _check_hits() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var c := col.get_collider()
		if c == null:
			continue
		if state == "dash" and c.has_method("on_dash"):
			c.on_dash(self)
		if c.has_method("on_player_touch"):
			c.on_player_touch(self, col.get_normal())


func _set_state(s: String) -> void:
	state = s
	t_state = 0.0


func is_busy() -> bool:
	return state in ["bubble", "carried", "launch", "pulled", "celebrate", "frozen"]


# ------------------------------------------------------- visuals/post
func _update_facing(delta: float, wish: Vector3) -> void:
	facing = facing - up * facing.dot(up)
	if facing.length() < 0.05:
		facing = up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD)
	facing = facing.normalized()
	if wish.length() > 0.1 and state in ["normal", "hover", "thrown"]:
		var w := wish.normalized()
		facing = facing.slerp(w, 1.0 - exp(-16.0 * delta)).normalized() if facing.dot(w) > -0.98 else w
	var x := up.cross(facing).normalized()
	global_basis = Basis(x, up, x.cross(up).normalized())
	var ang := _prev_facing.signed_angle_to(facing, up)
	_turn = lerpf(_turn, ang / maxf(delta, 0.0001), 1.0 - exp(-12.0 * delta))
	_prev_facing = facing


func _post_move(delta: float) -> void:
	var on_floor := is_on_floor()
	var v_up := velocity.dot(up)
	if on_floor and not _was_on_floor and state in ["normal", "hover", "thrown", "stunned", "dash"]:
		var impact := -_prev_vel.dot(up)
		if impact > 2.0:
			rig.land(impact)
			Vfx.dust(global_position, up, int(clampf(impact * 0.6, 4, 12)), clampf(impact / 14.0, 0.6, 1.4))
			Sfx.play("land", 1.1 if kind == "lumi" else 0.8, linear_to_db(clampf(impact / 20.0, 0.2, 1.0)))
			if impact > 16.0:
				Juice.shake(0.08)
			landed.emit(impact)
		if state == "hover":
			_set_state("normal")
	_was_on_floor = on_floor

	# safe respawn spot
	_safe_t -= delta
	if on_floor and state == "normal" and _safe_t <= 0.0:
		var fc := get_last_slide_collision()
		var ok := true
		if fc and fc.get_collider() is AnimatableBody3D:
			ok = false
		if ok:
			safe_pos = global_position
			safe_up = up
			_safe_t = 0.3

	# run dust
	var sp := (velocity - up * v_up).length()
	if on_floor and sp > max_speed * 0.7:
		_run_dust_t -= delta
		if _run_dust_t <= 0.0:
			_run_dust_t = 0.18
			Vfx.dust(global_position - facing * 0.2, up, 2, 0.5)

	# rig
	var acc := (velocity - _prev_vel) / maxf(delta, 0.0001)
	var acc_local := global_basis.inverse() * acc
	var rstate := state
	if state == "normal" and carrying:
		rstate = "carrying"
	rig.animate(delta, {
		"speed": sp, "max_speed": max_speed, "on_floor": on_floor, "v_up": v_up,
		"accel": acc_local, "turn": _turn, "state": rstate, "t_state": t_state,
	})
	_prev_vel = velocity
	wind = Vector3.ZERO

	# invulnerability blink
	visual.visible = not (invuln > 0.0 and state != "bubble" and fmod(invuln, 0.16) < 0.06)
	_light.light_energy = 1.4 if state == "hover" else 0.6
	_update_shadow()
	_update_beam(delta)


func _on_step() -> void:
	Sfx.play("step", 1.3 if kind == "lumi" else 0.8, -10.0, 0.2)


func _make_shadow() -> void:
	_shadow = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.0, 1.0)
	_shadow.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.15, 0.08, 0.25, 0.45)
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.6, Color(1, 1, 1, 0.8))
	g.gradient = grad
	m.albedo_texture = g
	m.disable_receive_shadows = true
	_shadow.material_override = m
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)


func _update_shadow() -> void:
	var space := get_world_3d().direct_space_state
	var from := global_position + up * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from - up * 30.0, 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty() or state == "bubble":
		_shadow.visible = false
		return
	_shadow.visible = true
	var h := from.distance_to(hit["position"])
	var s := clampf(1.1 - h * 0.05, 0.3, 1.1) * (0.9 if kind == "lumi" else 1.15)
	var n: Vector3 = hit["normal"]
	var x := n.cross(facing).normalized()
	if x.length() < 0.1:
		x = n.cross(Vector3.RIGHT).normalized()
	_shadow.global_transform = Transform3D(Basis(x, n, x.cross(n)).scaled(Vector3(s, 1, s)), hit["position"] + n * 0.03)


func _make_bubble() -> void:
	_bubble = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.85
	sm.height = 1.7
	_bubble.mesh = sm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/bubble.gdshader")
	_bubble.material_override = m
	_bubble.position = Vector3(0, 0.6, 0)
	_bubble.visible = false
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bubble)


func _update_beam(delta: float) -> void:
	_beam_t -= delta
	if _beam_t <= 0.0 or partner == null:
		if _beam:
			_beam.visible = false
		return
	if _beam == null:
		_beam = MeshInstance3D.new()
		_beam.mesh = ImmediateMesh.new()
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/beam.gdshader")
		m.set_shader_parameter("color", data["light"])
		_beam.material_override = m
		_beam.top_level = true
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_beam)
	_beam.visible = true
	_beam.global_transform = Transform3D.IDENTITY
	var a := global_position + up * 0.7
	var b := partner.global_position + partner.up * 0.6
	var cam := get_viewport().get_camera_3d()
	var side := (b - a).cross(cam.global_position - a).normalized() * 0.18
	var im := _beam.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var seg := 16
	for i in seg + 1:
		var t := float(i) / seg
		var p := a.lerp(b, t) + up * sin(t * PI) * 0.6 + up * sin(t * 18.0 + Time.get_ticks_msec() * 0.02) * 0.05
		im.surface_set_uv(Vector2(t, 0))
		im.surface_add_vertex(p - side)
		im.surface_set_uv(Vector2(t, 1))
		im.surface_add_vertex(p + side)
	im.surface_end()

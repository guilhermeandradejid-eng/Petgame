class_name CharacterRig
extends Node3D
## Procedural animation for the Blender-built characters.
##
## The model is a hierarchy of pivot nodes (Hips, Head, ArmL, LegR, EarL,
## Tail1, Cape...). Every frame we compute small offsets on top of each pivot's
## rest pose. Disney's principles drive the choices:
##  - Squash & stretch: this node scales around the feet, volume preserved.
##  - Anticipation: crouch before jumps and pounds (`anticipate()`).
##  - Follow-through / overlapping action: ears, tail, cape, scarf, sprout
##    and head are damped springs that lag behind the body's acceleration.
##  - Arcs: feet lift on a curve during the run cycle; arms swing in arcs.
##  - Slow in / slow out: springs and exponential smoothing everywhere.
##  - Secondary action: blinking, breathing, tail wag, looking around.
##  - Exaggeration & timing: big squash on landings, held pound pose.

var kind := "lumi"
var model: Node3D
var pivots := {}  # name -> {"node": Node3D, "rest": Transform3D}

# springs: name -> Vector4(x, vx, y, vy)
var _springs := {}
var _squash := 1.0
var _squash_v := 0.0
var _phase := 0.0
var _time := 0.0
var _blink_t := 2.0
var _blink := 0.0
var _look_t := 3.0
var _look_target := Vector2.ZERO
var _look := Vector2.ZERO
var _lean := Vector2.ZERO
var _spin := 0.0
var _tail_spin := 0.0
var _anticip := 0.0
var _land_crouch := 0.0
var _mood := 0.0  # -1 angry (brows), +1 happy
var _step_cb: Callable
var _last_step_sign := 0.0


func setup(scene: PackedScene, character_kind: String, outline_width := 0.011) -> void:
	kind = character_kind
	model = scene.instantiate()
	add_child(model)
	Mats.stylize(model, outline_width)
	_collect(model)
	for mi in Mats._all_meshes(model):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func set_step_callback(cb: Callable) -> void:
	_step_cb = cb


func _collect(n: Node) -> void:
	if n is Node3D and not (n is MeshInstance3D):
		pivots[n.name] = {"node": n, "rest": n.transform}
	for c in n.get_children():
		_collect(c)


## Squash (<0) or stretch (>0) impulse, e.g. -0.35 on a hard landing.
func pop(amount: float) -> void:
	_squash = 1.0 + amount
	_squash_v = 0.0


func anticipate(amount := 1.0) -> void:
	_anticip = amount


func land(impact: float) -> void:
	pop(-clampf(impact * 0.022, 0.1, 0.45))
	_land_crouch = clampf(impact * 0.03, 0.2, 1.0)


func set_mood(m: float) -> void:
	_mood = m


func flash(strength := 1.0) -> void:
	for mi in Mats._all_meshes(model):
		var m := mi as MeshInstance3D
		for s in m.get_surface_override_material_count():
			var mat := m.get_surface_override_material(s)
			if mat is ShaderMaterial and mat.shader == ShaderLib.get_shader("toon"):
				var dup: ShaderMaterial = mat.duplicate()
				dup.set_shader_parameter("hit_flash", strength)
				m.set_surface_override_material(s, dup)
				var tw := m.create_tween()
				tw.tween_method(func(v): dup.set_shader_parameter("hit_flash", v), strength, 0.0, 0.35)
				tw.tween_callback(func(): if is_instance_valid(m): m.set_surface_override_material(s, mat))


# ----------------------------------------------------------------- update
## `st` keys: speed, max_speed, on_floor, v_up, accel (Vector3 local),
## turn (rad/s), state (String), t_state (seconds in state).
func animate(delta: float, st: Dictionary) -> void:
	_time += delta
	var speed: float = st.get("speed", 0.0)
	var sr := clampf(speed / maxf(st.get("max_speed", 8.0), 0.1), 0.0, 1.5)
	var on_floor: bool = st.get("on_floor", true)
	var v_up: float = st.get("v_up", 0.0)
	var acc: Vector3 = st.get("accel", Vector3.ZERO)
	var turn: float = st.get("turn", 0.0)
	var state: String = st.get("state", "normal")
	var ts: float = st.get("t_state", 0.0)

	var rot := {}  # pivot -> Vector3 euler offset
	var pos := {}  # pivot -> Vector3 position offset
	var scl := {}  # pivot -> Vector3 scale

	# ---- squash & stretch spring
	var target := 1.0
	if not on_floor and state in ["normal", "thrown", "launch"]:
		target = 1.0 + clampf(v_up * 0.018, -0.1, 0.22)
	if state == "dash":
		target = 0.85
	_squash_v += (target - _squash) * 320.0 * delta
	_squash_v *= exp(-14.0 * delta)
	_squash += _squash_v * delta
	_anticip = move_toward(_anticip, 0.0, delta * 6.0)
	_land_crouch = move_toward(_land_crouch, 0.0, delta * 4.0)
	var s := clampf(_squash - _anticip * 0.15, 0.45, 1.7)
	# breathing (secondary action)
	if on_floor and sr < 0.1:
		s += sin(_time * 2.4) * 0.018
	scale = Vector3(1.0 / sqrt(s), s, 1.0 / sqrt(s))

	# ---- body lean (into acceleration and turns)
	var lean_t := Vector2(clampf(sr * 0.12 + acc.z * 0.006, -0.25, 0.4), clampf(-turn * 0.06, -0.3, 0.3))
	if state == "dash":
		lean_t.x = 0.6
	_lean = _lean.lerp(lean_t, 1.0 - exp(-10.0 * delta))
	var body_rot := Vector3(_lean.x, 0.0, _lean.y)

	# ---- whole-body spins (pound flip, celebrate twirl, bubble roll)
	match state:
		"pound_wind":
			_spin = -TAU * clampf(ts / 0.22, 0.0, 1.0)
			body_rot.x += _spin
		"celebrate":
			_spin = TAU * ease_out_back(clampf(fmod(ts, 1.6) / 0.6, 0.0, 1.0))
			rotation.y = _spin
		"bubble":
			body_rot.z += sin(_time * 2.0) * 0.3
		_:
			rotation.y = lerp_angle(rotation.y, 0.0, 1.0 - exp(-12.0 * delta))
	rotation.x = body_rot.x
	rotation.z = body_rot.z

	# ---- run cycle
	var moving := on_floor and sr > 0.05 and state in ["normal", "carrying"]
	if moving:
		_phase += delta * TAU * (1.4 + speed * 0.26)
		var sgn := signf(sin(_phase))
		if sgn != _last_step_sign and _step_cb.is_valid():
			_step_cb.call()
		_last_step_sign = sgn
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, 1.0 - exp(-10.0 * delta))
	var amp := minf(sr, 1.2) if moving else 0.0
	var leg_amp := deg_to_rad(48.0) * amp
	for side in [1.0, -1.0]:
		var nm := "L" if side > 0 else "R"
		var ph := _phase + (0.0 if side > 0 else PI)
		var a := sin(ph) * leg_amp
		var lift := maxf(0.0, cos(ph)) * 0.07 * amp
		rot["Leg" + nm] = Vector3(-a, 0, 0)
		pos["Leg" + nm] = Vector3(0, lift, 0)
		# arms swing opposite to the leg on the same side, slightly delayed
		var arm_a := sin(ph - 0.35) * deg_to_rad(50.0) * amp
		rot["Arm" + nm] = Vector3(arm_a, 0, side * deg_to_rad(6.0))
	var bob := -absf(cos(_phase)) * 0.035 * amp
	pos["Hips"] = Vector3(0, bob - _land_crouch * 0.06 - _anticip * 0.05, 0)
	rot["Hips"] = Vector3(0, sin(_phase) * 0.12 * amp, sin(_phase) * 0.06 * amp)

	# ---- poses per state (override run cycle)
	var arms_out := 0.0
	var arms_fwd := 0.0
	var legs_tuck := 0.0
	if not on_floor and state in ["normal", "thrown", "launch", "pulled"]:
		if v_up > 0.0:
			arms_out = 0.9
			legs_tuck = 0.5
		else:
			arms_out = 1.6 + sin(_time * 18.0) * 0.15  # flail on the way down
			legs_tuck = 0.2
	match state:
		"hover":
			arms_out = 1.35
			legs_tuck = 0.3
			_tail_spin += delta * 28.0
		"pound_wind":
			legs_tuck = 1.2
			arms_fwd = 1.0
		"pound_fall":
			legs_tuck = -0.2
			arms_out = 2.6
		"dash":
			arms_fwd = -1.0
			legs_tuck = 0.4
		"carried":
			arms_out = 2.6 + sin(_time * 6.0) * 0.2
			legs_tuck = 0.3 + sin(_time * 5.0) * 0.4
		"carrying":
			arms_out = 2.75
		"bubble":
			legs_tuck = 1.0
			arms_fwd = 0.9
		"celebrate":
			arms_out = 2.5 + sin(_time * 14.0) * 0.25
			legs_tuck = 0.3 * absf(sin(_time * 7.0))
		"stunned":
			arms_out = 0.6 + sin(_time * 10.0) * 0.4
	if not state in ["hover"]:
		_tail_spin = lerpf(_tail_spin, roundf(_tail_spin / TAU) * TAU, 1.0 - exp(-6.0 * delta))
	for side in [1.0, -1.0]:
		var nm := "L" if side > 0 else "R"
		if arms_out != 0.0 or arms_fwd != 0.0:
			var base: Vector3 = rot.get("Arm" + nm, Vector3.ZERO)
			rot["Arm" + nm] = Vector3(base.x * 0.2 - arms_fwd * 1.2, 0, side * arms_out)
		if legs_tuck != 0.0:
			var lb: Vector3 = rot.get("Leg" + nm, Vector3.ZERO)
			rot["Leg" + nm] = Vector3(lb.x * 0.3 - legs_tuck * (0.9 if side > 0 else 0.6), 0, side * legs_tuck * 0.15)
			pos["Leg" + nm] = Vector3(0, legs_tuck * 0.05, 0)

	# ---- head: overlapping action + idle look-around + counter-bob
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = randf_range(1.5, 4.0)
		_look_target = Vector2(randf_range(-0.15, 0.2), randf_range(-0.6, 0.6)) if sr < 0.1 and on_floor else Vector2.ZERO
	if sr > 0.1 or not on_floor:
		_look_target = Vector2.ZERO
	_look = _look.lerp(_look_target, 1.0 - exp(-4.0 * delta))
	var head := _spring("head", Vector2(-acc.z * 0.01 - v_up * 0.01, turn * 0.08), 120.0, 9.0, delta)
	rot["Head"] = Vector3(head.x + _look.x + cos(_phase * 2.0) * 0.04 * amp - _lean.x * 0.5, head.y + _look.y, -_lean.y * 0.6)

	# ---- follow-through appendages
	var fall := clampf(-v_up * 0.03, -0.6, 0.8)
	var ears := _spring("ears", Vector2(-sr * 0.4 - v_up * 0.025 - acc.z * 0.004, -turn * 0.05 + acc.x * 0.004), 140.0, 7.0, delta)
	rot["EarL"] = Vector3(ears.x, 0, ears.y + (sin(_time * 1.7) * 0.03))
	rot["EarR"] = Vector3(ears.x, 0, ears.y - (sin(_time * 1.9 + 1.0) * 0.03))
	var ant := _spring("ant", Vector2(-sr * 0.5 - v_up * 0.04, -turn * 0.08), 90.0, 5.0, delta)
	rot["AntL"] = Vector3(ant.x, 0, ant.y)
	rot["AntR"] = Vector3(ant.x, 0, ant.y)
	var wag := sin(_time * (3.0 if sr < 0.1 else 9.0)) * (0.25 if sr < 0.1 else 0.12)
	var tail := _spring("tail", Vector2(v_up * 0.03 + sr * 0.25, turn * 0.12 + wag), 110.0, 6.0, delta)
	rot["Tail1"] = Vector3(tail.x, 0, tail.y)
	var tail2 := _spring("tail2", Vector2(tail.x * 0.8, tail.y * 1.2), 70.0, 5.0, delta)
	rot["Tail2"] = Vector3(tail2.x, _tail_spin, tail2.y)
	var cape := _spring("cape", Vector2(sr * 0.7 + maxf(fall, 0.0) * 1.2 + (0.8 if state == "dash" else 0.0), -turn * 0.1 + sin(_time * 2.3) * 0.04), 80.0, 5.0, delta)
	rot["Cape"] = Vector3(cape.x, 0, cape.y)
	var scarf := _spring("scarf", Vector2(sr * 0.9 + maxf(fall, 0.0), sin(_time * 7.0) * 0.12 * (0.3 + sr)), 60.0, 4.0, delta)
	rot["ScarfTail"] = Vector3(scarf.x, 0, scarf.y)
	var sprout := _spring("sprout", Vector2(-sr * 0.5 - v_up * 0.05, -turn * 0.12 + sin(_time * 1.3) * 0.05), 100.0, 4.5, delta)
	rot["Sprout"] = Vector3(sprout.x, 0, sprout.y)
	rot["SproutLeaf"] = Vector3(sprout.x * 0.6, 0, sprout.y * 0.8)

	# ---- face: blink + brows
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(1.8, 4.5)
		_blink = 1.0
	_blink = move_toward(_blink, 0.0, delta * 9.0)
	var eye_y := 1.0 - (sin(_blink * PI) * 0.9)
	if state == "pound_fall" or state == "dash":
		eye_y = minf(eye_y, 0.55)  # determined squint
	if state == "stunned":
		eye_y = 0.25
	scl["EyeL"] = Vector3(1, eye_y, 1)
	scl["EyeR"] = Vector3(1, eye_y, 1)
	var angry := state in ["pound_wind", "pound_fall", "dash", "carrying"] or _mood < -0.5
	var happy := state == "celebrate" or _mood > 0.5
	var brow := 0.35 if angry else (-0.25 if happy else 0.0)
	rot["BrowL"] = Vector3(0, 0, -brow)
	rot["BrowR"] = Vector3(0, 0, brow)
	pos["BrowL"] = Vector3(0, -0.02 if angry else (0.025 if happy else 0.0), 0)
	pos["BrowR"] = pos["BrowL"]

	_apply(rot, pos, scl)


func _apply(rot: Dictionary, pos: Dictionary, scl: Dictionary) -> void:
	for name in pivots:
		var p: Dictionary = pivots[name]
		var rest: Transform3D = p["rest"]
		var r: Vector3 = rot.get(name, Vector3.ZERO)
		var o: Vector3 = pos.get(name, Vector3.ZERO)
		var sc: Vector3 = scl.get(name, Vector3.ONE)
		if r == Vector3.ZERO and o == Vector3.ZERO and sc == Vector3.ONE:
			(p["node"] as Node3D).transform = rest
			continue
		var b := rest.basis * Basis.from_euler(r)
		if sc != Vector3.ONE:
			b = b * Basis.from_scale(sc)
		(p["node"] as Node3D).transform = Transform3D(b, rest.origin + o)


## 2D damped spring (semi-implicit Euler). Returns the current value.
func _spring(key: String, target: Vector2, k: float, damping: float, dt: float) -> Vector2:
	var v: Vector4 = _springs.get(key, Vector4.ZERO)
	v.y += (target.x - v.x) * k * dt
	v.w += (target.y - v.z) * k * dt
	v.y *= exp(-damping * dt)
	v.w *= exp(-damping * dt)
	v.x += v.y * dt
	v.z += v.w * dt
	_springs[key] = v
	return Vector2(v.x, v.z)


static func ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)

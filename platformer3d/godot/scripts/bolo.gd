class_name Bolo
extends CharacterBody3D
## Bolo's controller. Movement is tuned for feel first: coyote time, jump buffering, variable
## jump height, a 3-frame jump squat that matches the animation's anticipation, double jump off
## Pip, gliding, skids, heavy landings and ledge grabs.

const SCALE := 0.6                 # Blender units -> metres
const RUN := 7.2
const ACCEL := 34.0
const DECEL := 40.0
const AIR_ACCEL := 16.0
const SKID_DECEL := 30.0
const JUMP_V := 12.0
const DJ_V := 11.0
const G_UP := 30.0
const G_DOWN := 44.0
const G_GLIDE := 10.0
const GLIDE_FALL := 2.2
const GLIDE_SPEED := 6.0
const COYOTE := 0.12
const BUFFER := 0.12
const SQUAT := 0.05
const HEAVY_DROP := 4.0
# Measured on the rig in Blender (bolo_anims.py): hands on the ledge while hanging.
const HAND_H := 1.56 * SCALE
const HANG_FRONT := 0.36 * SCALE + 0.03
const CLIMB_FWD := 0.75 * SCALE

var cam: OrbitCam
var pip: Node3D
var visual: Node3D
var model: Node3D
var anim: AnimationPlayer
var skeleton: Skeleton3D
var shadow: MeshInstance3D
var dust: CPUParticles3D

var state := "ground"
var coyote := 0.0
var buffer := 0.0
var squat_t := 0.0
var air_jumps := 1
var cut_done := false
var prev_held := false
var peak_y := 0.0
var lock_t := 0.0
var skid_t := 0.0
var skid_dir := Vector3.ZERO
var speed_mem := 0.0          # recent top speed, so a keyboard reversal with a gap still skids
var move_dir := Vector3.FORWARD
var idle_t := 0.0
var fidget := false
var oneshot := ""
var oneshot_t := 0.0
var ledge_n := Vector3.ZERO
var regrab_t := 0.0
var climb_t := 0.0
var hang_t := 0.0
var face_yaw := 0.0
var lean := 0.0
var cur_anim := ""
var spawn := Vector3.ZERO
var wish := Vector3.ZERO
var debug := false
var debug_t := 0.0
var _last_sig := ""


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.15
	col.shape = cap
	col.position.y = 0.575
	add_child(col)
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)

	visual = Node3D.new()
	add_child(visual)
	model = load("res://assets/bolo.glb").instantiate()
	model.scale = Vector3.ONE * SCALE
	model.rotation.y = PI  # glTF faces +Z, the game faces -Z
	visual.add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	skeleton = model.find_child("Skeleton3D", true, false)
	for n in ["idle", "walk", "run", "fall", "glide", "ledge_hang"]:
		anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	anim.animation_finished.connect(_on_anim_finished)
	Look.vinylize(model)

	shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.3)
	q.orientation = PlaneMesh.FACE_Y
	shadow.mesh = q
	shadow.material_override = Look.blob_shadow()
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

	dust = Look.dust()
	add_child(dust)
	spawn = global_position
	face_yaw = 0.0
	_play("idle", 0.0)


func facing_yaw() -> float:
	return face_yaw


func forward() -> Vector3:
	return Vector3(-sin(face_yaw), 0, -cos(face_yaw))


func _physics_process(d: float) -> void:
	var mv := Controls.move_vector()
	var basis := cam.flat_basis()
	wish = (basis * Vector3(mv.x, 0, mv.y))
	wish.y = 0
	if wish.length() > 1.0:
		wish = wish.normalized()
	var held := Controls.jump_held()
	var pressed := held and not prev_held
	prev_held = held
	if pressed:
		buffer = BUFFER
	buffer -= d
	regrab_t -= d

	match state:
		"hang":
			_hang(pressed)
			return
		"climb":
			climb_t -= d
			if climb_t <= 0.0:
				_finish_climb()
			return

	var on_floor := is_on_floor()
	if on_floor:
		coyote = COYOTE
		air_jumps = 1
	else:
		coyote -= d

	_horizontal(d, on_floor)
	_jumping(d, on_floor, held)
	_gravity(d, held)

	var was_air := not on_floor
	move_and_slide()
	if global_position.y < -30.0:
		_respawn()
		return

	if is_on_floor() and was_air and state in ["air", "glide"]:
		_land()
	elif not is_on_floor() and state in ["ground", "skid"]:
		state = "air"
		peak_y = global_position.y
	if state in ["air", "glide"]:
		peak_y = max(peak_y, global_position.y)
		if state == "glide":
			peak_y = global_position.y  # gliding down never counts as a big drop
		if velocity.y <= 1.0 and regrab_t <= 0.0:
			_try_ledge()

	_face(d)
	_animate(d)
	_update_shadow()
	if debug:
		var sig := state + "/" + cur_anim
		if sig != _last_sig:
			_last_sig = sig
			print("DBG pos=", global_position.snapped(Vector3.ONE * 0.01), " vel=", velocity.snapped(Vector3.ONE * 0.01), " state=", state, " floor=", is_on_floor(), " wish=", wish.snapped(Vector3.ONE * 0.01), " anim=", cur_anim)


# ---------------------------------------------------------------- movement

func _horizontal(d: float, on_floor: bool) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	var target := wish * RUN
	if state == "land_heavy":
		lock_t -= d
		hv = hv.move_toward(Vector3.ZERO, DECEL * d)
		if lock_t <= 0.0:
			state = "ground"
	elif state == "skid":
		skid_t -= d
		hv = hv.move_toward(Vector3.ZERO, SKID_DECEL * d)
		if int(skid_t * 30) % 3 == 0:
			_puff(2)
		if skid_t <= 0.0 or hv.length() < 0.5:
			state = "ground"
			face_yaw = atan2(-skid_dir.x, -skid_dir.z)
	elif on_floor and state == "ground":
		var speed := hv.length()
		if speed > 2.0:
			move_dir = hv / speed
		speed_mem = max(speed, speed_mem - 8.0 * d)
		if speed_mem > RUN * 0.7 and wish.length() > 0.5 and wish.normalized().dot(move_dir) < -0.55:
			speed_mem = 0.0
			state = "skid"
			skid_t = 0.3
			skid_dir = wish.normalized()
			_puff(8)
			_play("skid", 0.06)
		else:
			hv = hv.move_toward(target, (ACCEL if target.length() > 0.1 else DECEL) * d)
	else:
		var top := GLIDE_SPEED if state == "glide" else RUN
		hv = hv.move_toward(wish * top, AIR_ACCEL * d)
	velocity.x = hv.x
	velocity.z = hv.z


func _jumping(d: float, on_floor: bool, held: bool) -> void:
	if state == "jumpsquat":
		squat_t -= d
		if squat_t <= 0.0:
			velocity.y = JUMP_V
			state = "air"
			cut_done = false
			peak_y = global_position.y
		return
	if buffer > 0.0 and (on_floor or coyote > 0.0) and state in ["ground", "skid", "air"] and (on_floor or coyote > 0.0):
		if state == "skid":
			face_yaw = atan2(-skid_dir.x, -skid_dir.z)  # a skid jump goes the new way (sideflip-ish)
		buffer = 0.0
		coyote = 0.0
		state = "jumpsquat"
		squat_t = SQUAT
		fidget = false
		_play("jump", 0.04, true)
		return
	if state in ["air", "glide"] and buffer > 0.0 and air_jumps > 0 and not on_floor:
		buffer = 0.0
		air_jumps = 0
		velocity.y = DJ_V
		cut_done = true
		state = "air"
		peak_y = global_position.y
		_play("double_jump", 0.03, true)
		oneshot = "double_jump"
		oneshot_t = 0.6
		if pip:
			pip.boost()
		_puff(6)
		return
	# variable jump height: let go early and the rise is cut
	if state == "air" and velocity.y > 0.0 and not held and not cut_done:
		velocity.y *= 0.45
		cut_done = true
	# glide: keep holding jump while falling
	if state == "air" and held and velocity.y < -0.5 and buffer <= 0.0:
		state = "glide"
		if pip:
			pip.carry(true)
	elif state == "glide" and (not held or on_floor):
		state = "air"
		if pip:
			pip.carry(false)


func _gravity(d: float, _held: bool) -> void:
	if state == "glide":
		velocity.y = max(velocity.y - G_GLIDE * d, -GLIDE_FALL)
		return
	if state == "jumpsquat":
		velocity.y = 0.0
		return
	var g := G_UP if velocity.y > 0.0 else G_DOWN
	velocity.y = max(velocity.y - g * d, -32.0)


func _land() -> void:
	if pip and state == "glide":
		pip.carry(false)
	var drop := peak_y - global_position.y
	if drop > HEAVY_DROP:
		state = "land_heavy"
		lock_t = 0.45
		cam.add_shake(1.0)
		_puff(18)
		_play("land_heavy", 0.02, true)
		oneshot = "land_heavy"
		oneshot_t = 1.0
	else:
		state = "ground"
		_puff(5)
		oneshot = "land"
		oneshot_t = 0.35
		_play("land", 0.03, true)


func _respawn() -> void:
	global_position = spawn
	velocity = Vector3.ZERO
	state = "air"
	peak_y = global_position.y


# ---------------------------------------------------------------- ledges

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func _try_ledge() -> void:
	var fwd := forward()
	if wish.length() > 0.2:
		fwd = wish.normalized()
	var o := global_position
	var hit := _ray(o + Vector3.UP * (HAND_H - 0.12), o + Vector3.UP * (HAND_H - 0.12) + fwd * 0.8)
	if hit.is_empty() or abs(hit.normal.y) > 0.3:
		return
	if not _ray(o + Vector3.UP * (HAND_H + 0.5), o + Vector3.UP * (HAND_H + 0.5) + fwd * 0.8).is_empty():
		return
	var n: Vector3 = hit.normal
	n.y = 0
	n = n.normalized()
	var probe: Vector3 = hit.position - n * 0.2 + Vector3.UP * 0.7
	var down := _ray(probe, probe + Vector3.DOWN * 1.0)
	if down.is_empty() or down.normal.y < 0.8:
		return
	var top: float = down.position.y
	var dy := top - (o.y + HAND_H)
	if dy < -0.3 or dy > 0.4:
		return
	state = "hang"
	hang_t = 0.0
	ledge_n = n
	velocity = Vector3.ZERO
	var wp: Vector3 = hit.position
	global_position = Vector3(wp.x, top - HAND_H, wp.z) + n * HANG_FRONT
	face_yaw = atan2(n.x, n.z)
	visual.rotation.y = face_yaw
	oneshot = ""
	_play("ledge_hang", 0.08)
	if pip:
		pip.carry(false)
		pip.cheer()


func _hang(pressed: bool) -> void:
	var into := -ledge_n
	hang_t += get_physics_process_delta_time()
	if hang_t > 0.25 and (pressed or wish.dot(into) > 0.6):
		state = "climb"
		climb_t = anim.get_animation("ledge_climb").length
		_play("ledge_climb", 0.05, true)
	elif wish.dot(ledge_n) > 0.6:
		state = "air"
		regrab_t = 0.4
		velocity = ledge_n * 2.0
		peak_y = global_position.y


func _finish_climb() -> void:
	global_position += -ledge_n * CLIMB_FWD + Vector3.UP * HAND_H
	velocity = Vector3.ZERO
	state = "ground"
	_play("idle", 0.0)
	cur_anim = "idle"


# ---------------------------------------------------------------- look

func _face(d: float) -> void:
	var hv := Vector2(velocity.x, velocity.z)
	var old := face_yaw
	if state in ["ground", "air", "glide", "jumpsquat"] and hv.length() > 0.4:
		var want := atan2(-hv.x, -hv.y)
		face_yaw = lerp_angle(face_yaw, want, clamp(d * (14.0 if is_on_floor() else 6.0), 0.0, 1.0))
	visual.rotation.y = face_yaw
	# lean into turns while running (secondary action, done at runtime)
	var turn: float = wrapf(face_yaw - old, -PI, PI) / max(d, 0.001)
	var target_lean: float = clamp(-turn * 0.06 * clamp(hv.length() / RUN, 0.0, 1.0), -0.35, 0.35)
	lean = lerp(lean, target_lean, clamp(d * 8.0, 0.0, 1.0))
	model.rotation.z = lean


func _animate(d: float) -> void:
	if oneshot != "":
		oneshot_t -= d
		var moving := Vector2(velocity.x, velocity.z).length() > 1.0
		if oneshot_t <= 0.0 or (oneshot == "land" and moving) or (oneshot == "double_jump" and state == "glide"):
			oneshot = ""
		else:
			return
	var speed := Vector2(velocity.x, velocity.z).length()
	match state:
		"ground":
			if speed < 0.25:
				idle_t += d
				if idle_t > 6.0 and not fidget:
					fidget = true
					_play("idle_fidget", 0.2, true)
					if pip:
						pip.tease()
				elif not fidget:
					_play("idle", 0.2)
			else:
				idle_t = 0.0
				fidget = false
				if speed < 3.2:
					_play("walk", 0.15)
					anim.speed_scale = clamp(speed / 1.4, 0.6, 2.0)
				else:
					_play("run", 0.15)
					anim.speed_scale = clamp(speed / 5.0, 0.8, 1.6)
		"skid":
			_play("skid", 0.06)
		"jumpsquat":
			pass
		"air":
			idle_t = 0.0
			fidget = false
			if velocity.y > 3.0:
				_play("jump", 0.1)
			elif velocity.y > -2.5:
				_play("apex", 0.15)
			else:
				_play("fall", 0.2)
		"glide":
			_play("glide", 0.15)
		"land_heavy":
			pass


func _play(name: String, blend: float, restart := false) -> void:
	if name == cur_anim and not restart:
		return
	cur_anim = name
	anim.speed_scale = 1.0
	if restart:
		anim.stop()
	anim.play(name, blend)


func _on_anim_finished(name: StringName) -> void:
	if name == &"idle_fidget":
		fidget = false
		idle_t = 0.0
		_play("idle", 0.25)


func _puff(n: int) -> void:
	dust.global_position = global_position + Vector3.UP * 0.05
	dust.amount = max(n, 1)
	dust.restart()
	dust.emitting = true


func _update_shadow() -> void:
	var hit := _ray(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 30.0)
	if hit.is_empty():
		shadow.visible = false
		return
	shadow.visible = true
	var h: float = global_position.y - hit.position.y
	shadow.global_position = hit.position + Vector3.UP * 0.02
	var s: float = clamp(1.0 - h * 0.05, 0.55, 1.0)
	shadow.scale = Vector3(s, 1, s)

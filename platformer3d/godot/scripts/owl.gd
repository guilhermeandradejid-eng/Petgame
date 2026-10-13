class_name Owl
extends Node3D
## The owl companion. Perches on Bolo's head (riding the head bone) while he stands or walks,
## takes off to fly alongside with a spring when he runs or jumps, and joins the moves:
## springboard for the double jump, carries him by the scarf while gliding, teases him when idle.

const SCALE := 1.15
const PERCH_UP := 0.6        # from the head bone to where the owl's body sits

var bolo: Bolo
var model: Node3D
var anim: AnimationPlayer
var vel := Vector3.ZERO
var mode := "follow"
var mode_t := 0.0
var t := 0.0
var orbit := 0.0
var cur := ""
var yaw := 0.0
var calm_t := 0.0
var head_idx := -1


func _ready() -> void:
	model = load("res://assets/owl.glb").instantiate()
	model.scale = Vector3.ONE * SCALE
	model.rotation.y = PI
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	for n in ["perch", "fly", "hover", "carry", "tease"]:
		anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	Look.dress(model, 0.02)
	head_idx = bolo.skeleton.find_bone("head")
	global_position = _perch_point()
	mode = "perch"
	_play("perch")


func _head_xf() -> Transform3D:
	return bolo.skeleton.global_transform * bolo.skeleton.get_bone_global_pose(head_idx)


func _perch_point() -> Vector3:
	var h := _head_xf()
	return h.origin + h.basis.y.normalized() * PERCH_UP


func boost() -> void:
	mode = "boost"
	mode_t = 0.0
	global_position = bolo.global_position + Vector3.DOWN * 0.1
	vel = Vector3.ZERO
	_play("boost", true)


func carry(on: bool) -> void:
	if on:
		mode = "carry"
		_play("carry")
	elif mode == "carry":
		mode = "follow"
		vel = bolo.velocity * 0.5 + Vector3.UP * 2.0


func tease() -> void:
	if mode == "perch":
		mode = "tease"
		mode_t = 0.0


func cheer() -> void:
	if mode != "perch":
		vel += Vector3.UP * 3.0


func _process(d: float) -> void:
	t += d
	mode_t += d
	var fwd := bolo.forward()
	var side := fwd.cross(Vector3.UP)
	var speed := Vector2(bolo.velocity.x, bolo.velocity.z).length()
	var calm: bool = bolo.state in ["ground", "skid", "land_heavy", "hang"] and speed < 4.5
	calm_t = calm_t + d if calm else 0.0
	match mode:
		"perch":
			global_position = _perch_point()
			yaw = bolo.facing_yaw()
			vel = Vector3.ZERO
			if not calm:
				mode = "follow"
				vel = Vector3.UP * 2.5 + bolo.velocity * 0.6
		"landing":
			var p := _perch_point()
			_spring(p, d, 16.0)
			_play("hover")
			if global_position.distance_to(p) < 0.06:
				mode = "perch"
				_play("perch")
			elif not calm:
				mode = "follow"
		"boost":
			if mode_t < 0.12:
				global_position = global_position.lerp(bolo.global_position + Vector3.DOWN * 0.15, clamp(d * 30.0, 0.0, 1.0))
			else:
				if mode_t < 0.14:
					vel = side * 3.5 + Vector3.UP * 1.5 - bolo.velocity * 0.2
				_spring(_follow_point(fwd, side), d, 10.0)
			if mode_t > 0.6:
				mode = "follow"
		"carry":
			var h := _head_xf()
			var grip := h.origin + h.basis.y.normalized() * (PERCH_UP + 0.12) - fwd * 0.05
			global_position = global_position.lerp(grip, clamp(d * 25.0, 0.0, 1.0))
			vel = Vector3.ZERO
			yaw = bolo.facing_yaw()
		"tease":
			# hops off when Bolo reaches for it, giggles above him, then lands back
			var p := _perch_point() + Vector3.UP * 0.7 + side * 0.5
			if mode_t < 1.0:
				p = _perch_point()
			else:
				_play("tease")
			_spring(p, d, 14.0)
			if mode_t > 2.8:
				mode = "landing"
		_:
			_spring(_follow_point(fwd, side), d, 7.0)
			if calm_t > 0.6:
				mode = "landing"
	if mode in ["follow", "boost", "tease", "landing"]:
		var hv := Vector2(vel.x, vel.z)
		var want := atan2(-hv.x, -hv.y) if hv.length() > 1.2 else bolo.facing_yaw() + 0.5 * sin(t * 0.7)
		yaw = lerp_angle(yaw, want, clamp(d * 4.0, 0.0, 1.0))
		if mode == "follow":
			_play("fly" if vel.length() > 2.0 else "hover")
	rotation.y = yaw
	var bank: float = clamp(-vel.dot(Basis(Vector3.UP, yaw).x) * 0.06, -0.5, 0.5)
	rotation.z = lerp(rotation.z, bank if mode != "perch" else 0.0, clamp(d * 6.0, 0.0, 1.0))


func _follow_point(fwd: Vector3, side: Vector3) -> Vector3:
	orbit += 0.016 * 0.8
	var o := side * (0.7 * cos(orbit * 0.7)) - fwd * (0.3 + 0.35 * sin(orbit)) + Vector3.UP * (1.55 + 0.12 * sin(t * 2.3))
	return bolo.global_position + o


func _spring(target: Vector3, d: float, k: float) -> void:
	var acc := (target - global_position) * k * k - vel * 2.0 * k
	vel += acc * d
	global_position += vel * d


func _play(name: String, restart := false) -> void:
	if name == cur and not restart:
		return
	cur = name
	if restart:
		anim.stop()
	anim.play(name, 0.15)

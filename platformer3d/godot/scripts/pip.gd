class_name Pip
extends Node3D
## Pip flies around Bolo like a fairy companion: spring-damped follow, a slow orbit and bob,
## and he joins the moves (springboard for the double jump, carries Bolo while gliding).

const SCALE := 0.6

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


func _ready() -> void:
	model = load("res://assets/pip.glb").instantiate()
	model.scale = Vector3.ONE * SCALE
	model.rotation.y = PI
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	for n in ["fly", "hover", "carry", "tease"]:
		anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	Look.vinylize(model)
	global_position = bolo.global_position + Vector3(0.8, 1.6, 0.5)
	_play("hover")


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
	mode = "tease"
	mode_t = 0.0


func cheer() -> void:
	vel += Vector3.UP * 3.0


func _process(d: float) -> void:
	t += d
	mode_t += d
	var fwd := bolo.forward()
	var side := fwd.cross(Vector3.UP)
	match mode:
		"boost":
			# flattened under Bolo's feet for a moment, then flung off to the side spinning
			if mode_t < 0.12:
				global_position = global_position.lerp(bolo.global_position + Vector3.DOWN * 0.15, clamp(d * 30.0, 0.0, 1.0))
			else:
				if mode_t < 0.14:
					vel = side * 3.5 + Vector3.UP * 1.5 - bolo.velocity * 0.2
				_spring(_follow_point(fwd, side), d, 10.0)
			if mode_t > 0.6:
				mode = "follow"
		"carry":
			var head := bolo.global_position + Vector3.UP * (2.05 * Bolo.SCALE) + fwd * 0.05
			global_position = global_position.lerp(head, clamp(d * 25.0, 0.0, 1.0))
			vel = Vector3.ZERO
			yaw = bolo.facing_yaw()
		"tease":
			# Bolo swipes about a second in: dart up and away, giggle, come back
			var p := _follow_point(fwd, side)
			if mode_t > 0.9 and mode_t < 2.6:
				p += Vector3.UP * 0.9 + side * 0.7
				_play("tease")
			_spring(p, d, 14.0)
			if mode_t > 3.2:
				mode = "follow"
		_:
			_spring(_follow_point(fwd, side), d, 7.0)
	if mode != "carry":
		var hv := Vector2(vel.x, vel.z)
		var want := atan2(-hv.x, -hv.y) if hv.length() > 1.2 else bolo.facing_yaw() + 0.6 * sin(t * 0.7)
		yaw = lerp_angle(yaw, want, clamp(d * 4.0, 0.0, 1.0))
		if mode == "follow":
			_play("fly" if vel.length() > 2.0 else "hover")
	rotation.y = yaw
	# bank into the flight direction
	var bank: float = clamp(-vel.dot(Basis(Vector3.UP, yaw).x) * 0.06, -0.5, 0.5)
	rotation.z = lerp(rotation.z, bank, clamp(d * 6.0, 0.0, 1.0))


func _follow_point(fwd: Vector3, side: Vector3) -> Vector3:
	orbit += 0.016 * 0.8
	var o := side * (0.75 * cos(orbit * 0.7)) - fwd * (0.3 + 0.35 * sin(orbit)) + Vector3.UP * (1.45 + 0.12 * sin(t * 2.3))
	return bolo.global_position + o


func _spring(target: Vector3, d: float, k: float) -> void:
	# critically damped spring: lags behind like follow-through, never overshoots far
	var acc := (target - global_position) * k * k - vel * 2.0 * k
	vel += acc * d
	global_position += vel * d


func _play(name: String, restart := false) -> void:
	if name == cur and not restart:
		return
	cur = name
	if restart:
		anim.stop()
	anim.play(name, 0.12)

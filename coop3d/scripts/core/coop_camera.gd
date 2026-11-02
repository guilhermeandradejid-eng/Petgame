class_name CoopCamera
extends Node3D
## Shared co-op camera. Frames every target (players), zooms out as they
## spread, follows the averaged "up" on planetoids (the forward vector is
## parallel-transported so it never flips), and owns the juice layer:
## trauma shake (noise-based), directional punches and FOV kicks.

var targets: Array = []
var cam: Camera3D
var pitch := deg_to_rad(28.0)
var min_dist := 9.0
var max_dist := 42.0
var base_fov := 55.0
var yaw_input := 0.0
var focus_override := Vector3.ZERO
var focus_weight := 0.0

var _up := Vector3.UP
var _fwd := Vector3.FORWARD
var _center := Vector3.ZERO
var _dist := 12.0
var _trauma := 0.0
var _punch := Vector3.ZERO
var _punch_v := Vector3.ZERO
var _fov_add := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = base_fov
	cam.near = 0.1
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	_noise.frequency = 1.0
	Juice.camera = self


func snap(center: Vector3, fwd := Vector3.FORWARD, up := Vector3.UP) -> void:
	_center = center
	_fwd = fwd.normalized()
	_up = up
	_update_transform(1.0)


func add_trauma(t: float) -> void:
	_trauma = clampf(_trauma + t, 0.0, 1.0)


func punch(dir: Vector3, strength: float) -> void:
	_punch_v += dir.normalized() * strength * 18.0


func fov_kick(amount: float) -> void:
	_fov_add = maxf(_fov_add, amount)


func _process(delta: float) -> void:
	# use real time so hitstop doesn't freeze the shake
	var dt := delta / maxf(Engine.time_scale, 0.02) if Engine.time_scale < 0.5 else delta
	_t += dt
	var live := []
	for t in targets:
		if is_instance_valid(t) and t.visible:
			live.append(t)
	if live.is_empty():
		return
	# --- center & spread
	var c := Vector3.ZERO
	var upsum := Vector3.ZERO
	var vel := Vector3.ZERO
	for t in live:
		c += t.global_position
		upsum += t.up if "up" in t else Vector3.UP
		vel += t.velocity if "velocity" in t else Vector3.ZERO
	c /= live.size()
	vel /= live.size()
	var spread := 0.0
	for t in live:
		spread = maxf(spread, t.global_position.distance_to(c))
	if focus_weight > 0.0:
		c = c.lerp(focus_override, focus_weight)
	if upsum.length() > 0.3:
		_up = _up.slerp(upsum.normalized(), 1.0 - exp(-2.5 * dt)).normalized()
	# parallel-transport the forward vector onto the new tangent plane
	_fwd = (_fwd - _up * _fwd.dot(_up))
	if _fwd.length() < 0.05:
		_fwd = _up.cross(Vector3.RIGHT)
	_fwd = _fwd.normalized()
	_fwd = _fwd.rotated(_up, yaw_input * dt * 2.2).normalized()

	var lead := (vel - _up * vel.dot(_up)) * 0.25
	_center = _center.lerp(c + lead, 1.0 - exp(-5.0 * dt))
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var vfov := deg_to_rad(cam.fov)
	var hfov := 2.0 * atan(tan(vfov * 0.5) * aspect)
	var need := (spread + 3.0) / sin(minf(vfov, hfov) * 0.5)
	var target_d := clampf(need, min_dist, max_dist)
	var k := 4.0 if target_d > _dist else 1.6  # zoom out fast, in slowly
	_dist = lerpf(_dist, target_d, 1.0 - exp(-k * dt))

	# --- juice
	_trauma = maxf(_trauma - dt * 1.2, 0.0)
	_punch_v += -_punch * 260.0 * dt
	_punch_v *= exp(-14.0 * dt)
	_punch += _punch_v * dt
	_fov_add = lerpf(_fov_add, 0.0, 1.0 - exp(-4.0 * dt))
	cam.fov = base_fov + _fov_add
	_update_transform(dt)


func _update_transform(_dt: float) -> void:
	var back := -_fwd
	var pos := _center + _up * (sin(pitch) * _dist + 1.0) + back * (cos(pitch) * _dist)
	var look := _center + _up * 1.0
	global_position = pos + _punch
	if (look - global_position).normalized().cross(_up).length() > 0.01:
		look_at(look, _up)
	var sh := _trauma * _trauma
	if sh > 0.0:
		var n1 := _noise.get_noise_2d(_t * 40.0, 0.0)
		var n2 := _noise.get_noise_2d(_t * 40.0, 100.0)
		var n3 := _noise.get_noise_2d(_t * 40.0, 200.0)
		cam.rotation = Vector3(deg_to_rad(5.0) * sh * n1, deg_to_rad(5.0) * sh * n2, deg_to_rad(4.0) * sh * n3)
		cam.position = Vector3(n2, n3, 0.0) * 0.25 * sh
	else:
		cam.rotation = Vector3.ZERO
		cam.position = Vector3.ZERO


func forward_flat() -> Vector3:
	return _fwd

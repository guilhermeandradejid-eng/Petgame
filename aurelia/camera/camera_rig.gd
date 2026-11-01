class_name CameraRig
extends Node3D
## HD-2D camera: tilted perspective with a narrow FOV, follows the party centroid and
## zooms out to keep everyone framed. Shake = trauma^2 noise; kicks and FOV punches from Juice.

const PITCH := 36.0
const BASE_DIST := 11.3          # => one sprite pixel is ~4 screen pixels at 720p
const FOV := 28.0

var cam: Camera3D
var focus := Vector3.ZERO
var dist := BASE_DIST
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.5
	cam.far = 160.0
	cam.current = true
	add_child(cam)
	_noise.frequency = 1.0
	_noise.seed = 7
	_place(1.0)


func _physics_process(delta: float) -> void:
	_t += delta
	var ps := get_tree().get_nodes_in_group("players")
	var lo := Vector3(1e9, 0, 1e9)
	var hi := Vector3(-1e9, 0, -1e9)
	var n := 0
	for p in ps:
		var q: Vector3 = p.global_position
		lo.x = minf(lo.x, q.x)
		lo.z = minf(lo.z, q.z)
		hi.x = maxf(hi.x, q.x)
		hi.z = maxf(hi.z, q.z)
		n += 1
	if n > 0:
		var centre := (lo + hi) * 0.5
		var spread := maxf((hi.x - lo.x) / 11.0, (hi.z - lo.z) / 6.0)
		var want := BASE_DIST * clampf(1.0 + maxf(spread - 0.55, 0.0) * 0.8, 1.0, 1.9)
		dist = lerpf(dist, want, 0.04)
		focus = focus.lerp(centre, 0.14)
		focus.x = clampf(focus.x, -Game.ARENA_HALF + 6.0, Game.ARENA_HALF - 6.0)
		focus.z = clampf(focus.z, -Game.ARENA_HALF + 3.0, Game.ARENA_HALF - 1.0)
	_place(delta)


func _place(_delta: float) -> void:
	var pr := deg_to_rad(PITCH)
	var off := Vector3(0, sin(pr), cos(pr)) * dist
	var shake := Juice.trauma * Juice.trauma
	var sx := _noise.get_noise_2d(_t * 40.0, 0.0) * shake * 0.55
	var sy := _noise.get_noise_2d(0.0, _t * 40.0) * shake * 0.4
	var roll := _noise.get_noise_2d(_t * 33.0, 99.0) * shake * 0.05
	cam.global_position = focus + off + Vector3(sx, sy, 0) + Juice.kick_vec
	cam.rotation = Vector3(-pr, 0, roll)
	cam.fov = FOV + Juice.fov_punch

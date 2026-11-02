class_name CameraRig
extends Node3D
## HD-2D camera. Explore: critically-damped follow of the party centroid with look-ahead, a soft
## dead-zone and a hint of banking. Battle: pulls back and tilts a little more top-down to frame the
## whole arena (blended with the party so the action stays centred), with a dolly "punch" on entry.
## Shake = trauma^2 noise; kicks, FOV punches and roll come from Juice.

const PITCH_EXPLORE := 35.0
const PITCH_BATTLE := 39.0
const DIST_EXPLORE := 11.3          # one sprite pixel is ~4 screen pixels at 720p
const DIST_BATTLE := 14.6
const FOV := 28.0
const DEAD_ZONE := 0.45

var cam: Camera3D
var focus := Vector3.ZERO
var dist := DIST_EXPLORE
var pitch := PITCH_EXPLORE
var _focus_vel := Vector3.ZERO
var _look := Vector3.ZERO          # smoothed look-ahead
var _bank := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0
var _dist_vel := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.5
	cam.far = 160.0
	cam.current = true
	add_child(cam)
	_noise.frequency = 1.0
	_noise.seed = 7
	_place()


var _occ: Dictionary = {}


func _fade_canopies(delta: float) -> void:
	## Foliage between the camera and the party dissolves (dithered) instead of hiding the fight.
	var to_focus := (focus - cam.global_position)
	var len := to_focus.length()
	if len < 0.1:
		return
	var ray := to_focus / len
	for m in get_tree().get_nodes_in_group("canopy"):
		var rel: Vector3 = m.global_position + Vector3(0, 0.5, 0) - cam.global_position
		var along := rel.dot(ray)
		var want := 0.0
		if along > 0.0 and along < len + 1.0:
			var perp := (rel - ray * along).length()
			want = 0.9 if perp < 2.6 else 0.0
		var cur: float = _occ.get(m, 0.0)
		cur = lerpf(cur, want, clampf(delta * 8.0, 0.0, 1.0))
		if absf(cur - float(_occ.get(m, -1.0))) > 0.01:
			_occ[m] = cur
			(m.material_override as ShaderMaterial).set_shader_parameter("occlude", cur)


static func _smooth_damp(cur: float, target: float, vel: float, smooth_time: float, dt: float) -> Array:
	var omega := 2.0 / maxf(smooth_time, 0.0001)
	var x := omega * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - target
	var temp := (vel + omega * change) * dt
	var nv := (vel - omega * temp) * e
	return [target + (change + temp) * e, nv]


func _physics_process(delta: float) -> void:
	_t += delta
	var ps := get_tree().get_nodes_in_group("players")
	var lo := Vector3(1e9, 0, 1e9)
	var hi := Vector3(-1e9, 0, -1e9)
	var n := 0
	var vel_sum := Vector3.ZERO
	for p in ps:
		var q: Vector3 = p.global_position
		lo.x = minf(lo.x, q.x)
		lo.z = minf(lo.z, q.z)
		hi.x = maxf(hi.x, q.x)
		hi.z = maxf(hi.z, q.z)
		n += 1
		if p.is_multiplayer_authority():
			vel_sum += p.velocity
	if n > 0:
		var centre := (lo + hi) * 0.5
		var spread := maxf((hi.x - lo.x) / 11.0, (hi.z - lo.z) / 6.5)
		var target_dist := DIST_EXPLORE
		var target_pitch := PITCH_EXPLORE
		var want := centre
		if Game.arena_active:
			want = centre.lerp(Game.arena_center, 0.55)
			target_dist = DIST_BATTLE
			target_pitch = PITCH_BATTLE
		else:
			# look ahead in the direction we are running, softly
			var ahead := Vector3(vel_sum.x, 0, vel_sum.z) * 0.22
			ahead = ahead.limit_length(1.3)
			_look = _look.lerp(ahead, clampf(delta * 3.0, 0.0, 1.0))
			want += _look
		target_dist *= clampf(1.0 + maxf(spread - 0.62, 0.0) * 0.8, 1.0, 1.9)
		# dead-zone: tiny movements do not drag the camera around
		var off := want - focus
		off.y = 0.0
		if off.length() < DEAD_ZONE and not Game.arena_active:
			want = focus
		elif not Game.arena_active:
			want = focus + off.normalized() * (off.length() - DEAD_ZONE * 0.5)
		var sx := _smooth_damp(focus.x, want.x, _focus_vel.x, 0.22 if not Game.arena_active else 0.35, delta)
		var sz := _smooth_damp(focus.z, want.z, _focus_vel.z, 0.22 if not Game.arena_active else 0.35, delta)
		focus.x = sx[0]
		_focus_vel.x = sx[1]
		focus.z = sz[0]
		_focus_vel.z = sz[1]
		var sd := _smooth_damp(dist, target_dist, _dist_vel, 0.6, delta)
		dist = sd[0]
		_dist_vel = sd[1]
		pitch = lerpf(pitch, target_pitch, clampf(delta * 2.0, 0.0, 1.0))
		focus.x = clampf(focus.x, -Game.ARENA_HALF + 5.5, Game.ARENA_HALF - 5.5)
		focus.z = clampf(focus.z, -Game.ARENA_HALF + 3.5, Game.ARENA_HALF - 0.5)
		_bank = lerpf(_bank, clampf(_focus_vel.x * 0.012, -0.03, 0.03), clampf(delta * 4.0, 0.0, 1.0))
	_fade_canopies(delta)
	_place()


func _place() -> void:
	var pr := deg_to_rad(pitch)
	var off := Vector3(0, sin(pr), cos(pr)) * dist
	var shake := Juice.trauma * Juice.trauma
	var sx := _noise.get_noise_2d(_t * 40.0, 0.0) * shake * 0.5
	var sy := _noise.get_noise_2d(0.0, _t * 40.0) * shake * 0.38
	var roll := _noise.get_noise_2d(_t * 33.0, 99.0) * shake * 0.05 + _bank
	cam.global_position = focus + off + Vector3(sx, sy, 0) + Juice.kick_vec
	cam.rotation = Vector3(-pr, 0, roll)
	cam.fov = FOV + Juice.fov_punch

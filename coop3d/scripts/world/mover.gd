class_name MovingPlatform
extends AnimatableBody3D
## Floating platform that ping-pongs through local points with sine easing
## (slow in / slow out), or spins. Optionally powered by a channel: without
## power it glides back home.

var level: Node
var points: Array = []
var period := 4.0
var channel := ""
var spin := 0.0
var _t := 0.0
var _origin := Transform3D.IDENTITY
var _power := 1.0


func setup(lvl: Node, size: Vector3, pts: Array, per := 4.0, ch := "", spin_speed := 0.0, style := "wood") -> void:
	level = lvl
	points = pts
	period = per
	channel = ch
	spin = spin_speed
	sync_to_physics = true
	collision_layer = 1
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	if style == "wood":
		mi.material_override = Mats.toon(Color(0.86, 0.6, 0.38), {"detail_normal": Mats.N_WOOD, "detail_strength": 0.6, "detail_scale": 0.7, "noise_tint": 0.08})
	else:
		mi.material_override = Mats.toon(Color(0.72, 0.68, 0.84), {"detail_normal": Mats.N_TILES, "detail_strength": 0.5, "detail_scale": 0.5})
	add_child(mi)
	# grassy trim on top
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(size.x + 0.1, 0.12, size.z + 0.1)
	top.mesh = tm
	top.position.y = size.y * 0.5
	top.material_override = Mats.toon(Color(0.5, 0.82, 0.4), {"noise_tint": 0.15, "noise_scale": 1.2})
	add_child(top)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, size.y + 0.12, size.z)
	cs.shape = bs
	cs.position.y = 0.06
	add_child(cs)
	if channel != "":
		_power = 0.0
		var glow := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		glow.mesh = sm
		glow.material_override = Mats.glow(level.channel_color(channel), 1.5)
		glow.position = Vector3(0, -size.y * 0.5 - 0.1, 0)
		add_child(glow)


func _ready() -> void:
	_origin = transform


func _physics_process(delta: float) -> void:
	if channel != "":
		_power = move_toward(_power, 1.0 if level.channel(channel) else 0.0, delta * 0.8)
		_t += delta * _power
	else:
		_t += delta
	var xf := _origin
	if points.size() >= 2:
		var seg_count := points.size() - 1
		var u := fmod(_t / period, 2.0)
		if u > 1.0:
			u = 2.0 - u  # ping-pong
		if channel != "":
			u = clampf(_t / period, 0.0, 1.0)
			_t = minf(_t, period) if level.channel(channel) else maxf(_t - delta * 2.0, 0.0)
		var f := u * seg_count
		var i := mini(int(f), seg_count - 1)
		var k := f - i
		k = 0.5 - 0.5 * cos(k * PI)  # slow in / slow out
		var p: Vector3 = (points[i] as Vector3).lerp(points[i + 1], k)
		xf.origin = _origin.origin + _origin.basis * p
	if spin != 0.0:
		xf.basis = _origin.basis * Basis(Vector3.UP, _t * spin)
	transform = xf

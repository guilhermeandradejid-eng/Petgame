class_name LaunchRing
extends Area3D
## Petal ring that flings a player along an arc to a target point
## (between islands or planetoids). Speed lines + FOV kick sell the speed.

var level: Node
var target := Vector3.ZERO
var height := 12.0
var duration := 1.4
var channel := ""
var _ring: Node3D
var _cool := {}
var _petals: Array = []


func setup(lvl: Node, to: Vector3, h := 12.0, dur := 1.4, ch := "") -> void:
	level = lvl
	target = to
	height = h
	duration = dur
	channel = ch
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 1.1
	sh.height = 1.6
	cs.shape = sh
	cs.position.y = 0.8
	add_child(cs)
	_ring = Node3D.new()
	_ring.position.y = 0.25
	add_child(_ring)
	var base := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.95
	tm.outer_radius = 1.25
	base.mesh = tm
	base.material_override = Mats.toon(Color(1.0, 0.75, 0.35), {"spec_amount": 1.0, "rim_amount": 1.0, "outline": 0.0})
	_ring.add_child(base)
	for i in 8:
		var a := i * TAU / 8.0
		var p := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		p.mesh = sm
		p.scale = Vector3(1.0, 0.4, 1.8)
		p.material_override = Mats.glow(Color(1.0, 0.55, 0.85) if i % 2 else Color(1.0, 0.9, 0.4), 1.4)
		p.position = Vector3(cos(a) * 1.25, 0.05, sin(a) * 1.25)
		p.rotation.y = -a
		_ring.add_child(p)
		_petals.append(p)
	var glow := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 0.9
	cm.height = 0.05
	glow.mesh = cm
	glow.material_override = Mats.glow(Color(1.0, 0.85, 0.5), 2.0)
	_ring.add_child(glow)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_ring.rotate_y(delta * 1.5)
	var on: bool = channel == "" or level.channel(channel)
	_ring.scale = _ring.scale.lerp(Vector3.ONE * (1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.006)) if on else Vector3.ONE * 0.5, 1.0 - exp(-8.0 * delta))
	for k in _cool.keys():
		_cool[k] -= delta
		if _cool[k] <= 0.0:
			_cool.erase(k)


func _on_body(b: Node) -> void:
	if not (b is Player) or b.is_busy() or _cool.has(b):
		return
	if channel != "" and not level.channel(channel):
		return
	_cool[b] = 1.0
	b.drop_carry()
	b.start_path(null, target, duration, height, "launch")
	Sfx.play("portal", 1.4)
	Sfx.play("whoosh", 0.9)
	Vfx.speedlines(1.0)
	Juice.fov_kick(14.0)
	Juice.shake(0.12)
	Vfx.burst(global_position + global_basis.y, Color(1, 0.8, 0.5), 20, 7.0, 1.0, global_basis.y)
	var tw := create_tween()
	tw.tween_property(_ring, "scale", Vector3(1.5, 0.6, 1.5), 0.06)
	tw.tween_property(_ring, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

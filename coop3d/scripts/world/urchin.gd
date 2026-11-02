class_name Urchin
extends Node3D
## "Espinhudo": a grumpy urchin that patrols and breathes its spikes in and
## out. Spikes out = hurts on touch. Spikes in = can be stomped. A heavy
## ground pound nearby always knocks it out.

const MODEL := preload("res://assets/models/urchin.glb")

var level: Node
var points: Array = []
var speed := 1.6
var planet_center = null
var _t := 0.0
var _model: Node3D
var _spikes: Array = []
var _spiky := true
var _cycle := 0.0
var _area: Area3D
var _dead := false
var _up := Vector3.UP
var _face := Vector3.BACK


func setup(lvl: Node, pts: Array, spd := 1.6, center = null) -> void:
	level = lvl
	points = pts
	speed = spd
	planet_center = center
	add_to_group("pound_target")
	_model = MODEL.instantiate()
	add_child(_model)
	Mats.stylize(_model, 0.014)
	for n in Mats._all_meshes(_model):
		if String(n.name).begins_with("Spike"):
			_spikes.append(n)
	_area = Area3D.new()
	_area.collision_layer = 8
	_area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.7
	cs.shape = sh
	cs.position.y = 0.45
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_on_body)
	_cycle = randf() * 4.0


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	_cycle += delta
	var c := fmod(_cycle, 4.2)
	var want_spiky := c < 2.7
	if want_spiky != _spiky:
		_spiky = want_spiky
		Sfx.play("swish", 1.6 if _spiky else 0.9, -12.0)
	for s in _spikes:
		s.scale = s.scale.lerp(Vector3.ONE * (1.0 if _spiky else 0.15), 1.0 - exp(-12.0 * delta))
	# patrol (ping-pong along points, optionally hugging a planet)
	if points.size() >= 2:
		var total := 0.0
		for i in points.size() - 1:
			total += (points[i] as Vector3).distance_to(points[i + 1])
		var u := fmod(_t * speed / maxf(total, 0.01), 2.0)
		if u > 1.0:
			u = 2.0 - u
		var d := u * total
		var p: Vector3 = points[0]
		for i in points.size() - 1:
			var seg: float = (points[i] as Vector3).distance_to(points[i + 1])
			if d <= seg:
				p = (points[i] as Vector3).lerp(points[i + 1], d / maxf(seg, 0.001))
				break
			d -= seg
		if planet_center != null:
			var r: float = (points[0] as Vector3).distance_to(planet_center)
			p = planet_center + (p - planet_center).normalized() * r
			_up = (p - planet_center).normalized()
		var mv := p - global_position
		if mv.length() > 0.001:
			_face = (mv - _up * mv.dot(_up)).normalized()
		global_position = p
	var x := _up.cross(_face).normalized()
	if x.length() > 0.1:
		global_basis = Basis(x, _up, x.cross(_up))
	var hop := absf(sin(_t * 6.0)) * 0.12
	_model.position = Vector3(0, hop, 0)
	_model.scale = Vector3(1.0 + (0.12 - hop) * 0.6, 1.0 - (0.12 - hop) * 0.8, 1.0 + (0.12 - hop) * 0.6)
	for b in _area.get_overlapping_bodies():
		_on_body(b)


func _on_body(b: Node) -> void:
	if _dead or not (b is Player) or b.is_busy():
		return
	var rel: float = (b.global_position - global_position).dot(_up)
	var falling: bool = b.velocity.dot(_up) < 1.0
	if b.state == "pound_fall" or (rel > 0.45 and falling and not _spiky):
		b.bounce(12.0)
		defeat()
	else:
		b.hurt(global_position)


func on_pound(p: Node) -> void:
	defeat()


func defeat() -> void:
	if _dead:
		return
	_dead = true
	_area.set_deferred("monitoring", false)
	Sfx.play("pop", 0.7)
	Sfx.play("thud", 1.4, -4.0)
	Juice.hitstop(0.05)
	Juice.shake(0.12)
	Vfx.burst(global_position + _up * 0.5, Color(0.75, 0.5, 1.0), 16, 5.0)
	Vfx.text_pop(global_position + _up * 1.5, "Poft!", Color(1, 0.7, 0.9))
	for i in 3:
		level.spawn_spark(global_position + _up * (0.8 + i * 0.4))
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3(1.6, 0.2, 1.6), 0.1)
	tw.tween_property(_model, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

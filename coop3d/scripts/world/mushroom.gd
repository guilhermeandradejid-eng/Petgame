class_name BounceMushroom
extends StaticBody3D
## Jelly mushroom trampoline. Landing on the cap launches the player and the
## cap wobbles with an elastic squash.

const MODEL := preload("res://assets/models/mushroom.glb")

var strength := 19.0
var _cap: Node3D
var _model: Node3D
var _cool := {}


func setup(_lvl: Node, s := 19.0, size := 1.4) -> void:
	strength = s
	collision_layer = 1
	_model = MODEL.instantiate()
	_model.scale = Vector3.ONE * size
	add_child(_model)
	Mats.stylize(_model, 0.012)
	_cap = _model.find_child("CapPivot", true, false)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.95 * size
	cyl.height = 0.4 * size
	cs.shape = cyl
	cs.position.y = 0.95 * size
	add_child(cs)
	var stem := CollisionShape3D.new()
	var sc := CylinderShape3D.new()
	sc.radius = 0.3 * size
	sc.height = 0.8 * size
	stem.shape = sc
	stem.position.y = 0.4 * size
	add_child(stem)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var acs := CollisionShape3D.new()
	var acyl := CylinderShape3D.new()
	acyl.radius = 0.9 * size
	acyl.height = 0.4
	acs.shape = acyl
	acs.position.y = 1.25 * size
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(_on_body)


func _physics_process(_delta: float) -> void:
	for k in _cool.keys():
		_cool[k] -= _delta
		if _cool[k] <= 0.0:
			_cool.erase(k)


func _on_body(b: Node) -> void:
	if not (b is Player) or _cool.has(b) or b.is_busy():
		return
	if b.velocity.dot(b.up) > 2.0:
		return
	_cool[b] = 0.3
	var s := strength * (1.15 if b.state == "pound_fall" else 1.0)
	if b.state == "pound_fall":
		b._set_state("normal")
	b.bounce(s)
	Sfx.play("boing", randf_range(0.9, 1.1))
	Vfx.burst(b.global_position, Color(1, 0.5, 0.7), 10, 4.0, 0.8, global_basis.y)
	Vfx.ring(global_position + global_basis.y * 1.3 * _model.scale.y, global_basis.y, Color(1, 0.6, 0.8), 1.8, 0.35)
	if _cap:
		var tw := create_tween()
		tw.tween_property(_cap, "scale", Vector3(1.35, 0.55, 1.35), 0.06)
		tw.tween_property(_cap, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

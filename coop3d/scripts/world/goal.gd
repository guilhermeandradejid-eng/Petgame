class_name StarBloom
extends Area3D
## Level goal: a crystal flower that blooms when the heroes reach it
## together (in co-op both must be inside).

const MODEL := preload("res://assets/models/star_bloom.glb")

var level: Node
var done := false
var _model: Node3D
var _bloom: Node3D
var _petals: Array = []
var _label: Label3D
var _wait_t := 0.0


func setup(lvl: Node) -> void:
	level = lvl
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 3.0
	sh.height = 4.0
	cs.shape = sh
	cs.position.y = 2.0
	add_child(cs)
	_model = MODEL.instantiate()
	_model.scale = Vector3.ONE * 1.4
	add_child(_model)
	Mats.stylize(_model, 0.014)
	_bloom = _model.find_child("Bloom", true, false)
	for i in 5:
		var p := _model.find_child("Petal%d" % i, true, false)
		if p:
			_petals.append(p)
			p.rotation.y = 0.0
			p.scale = Vector3(0.4, 0.4, 0.4)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.9)
	l.light_energy = 2.0
	l.omni_range = 8.0
	l.position.y = 3.0
	add_child(l)
	_label = Label3D.new()
	_label.font_size = 64
	_label.outline_size = 14
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 4.6
	_label.pixel_size = 0.01
	_label.modulate = Color(1, 0.85, 0.95)
	_label.text = "Flor Estelar"
	add_child(_label)


func _process(delta: float) -> void:
	if _bloom:
		_bloom.rotate_y(delta * (0.4 if not done else 3.0))
	if done:
		return
	var inside := 0
	var needed := 0
	for p in level.players:
		if Game.coop or p.controlled:
			needed += 1
			if overlaps_body(p):
				inside += 1
	if inside > 0 and inside < needed:
		_wait_t -= delta
		_label.text = "Esperando o parceiro... (%d/%d)" % [inside, needed]
		if _wait_t <= 0.0:
			_wait_t = 3.0
			level.toast("Cheguem juntos na Flor Estelar!", Color(1, 0.8, 0.95))
	else:
		_label.text = "Flor Estelar"
	if needed > 0 and inside >= needed:
		_complete()


func _complete() -> void:
	done = true
	_label.text = "Floresceu!"
	for i in _petals.size():
		var tw := create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(_petals[i], "scale", Vector3.ONE * 1.3, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_petals[i], "scale", Vector3.ONE, 0.3)
	Vfx.confetti(global_position + Vector3.UP * 3.0, 90)
	Vfx.ring(global_position + Vector3.UP * 0.1, Vector3.UP, Color(1, 0.75, 0.95), 7.0, 0.8)
	Juice.slowmo(0.4, 0.8)
	Juice.shake(0.3)
	Sfx.play("fanfare", 1.0)
	level.complete()

class_name Checkpoint
extends Area3D
## Lantern post. Touching it lights the lamp and saves the respawn point.

const MODEL := preload("res://assets/models/lantern_post.glb")

var level: Node
var lit := false
var _light: OmniLight3D
var _model: Node3D


func setup(lvl: Node) -> void:
	level = lvl
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 1.4
	sh.height = 3.0
	cs.shape = sh
	cs.position.y = 1.5
	add_child(cs)
	_model = MODEL.instantiate()
	add_child(_model)
	Mats.stylize(_model, 0.012)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.85, 0.5)
	_light.light_energy = 0.0
	_light.omni_range = 6.0
	_light.position = Vector3(0.5, 1.3, 0)
	add_child(_light)
	body_entered.connect(_on_body)


func _on_body(b: Node) -> void:
	if lit or not (b is Player):
		return
	lit = true
	level.set_checkpoint(global_position + global_basis.y * 0.3, global_basis.y)
	Sfx.play("unlock", 1.3)
	Sfx.play("sparkle", 1.2, -6.0)
	Vfx.burst(_light.global_position, Color(1, 0.85, 0.5), 18, 4.0)
	Vfx.text_pop(global_position + global_basis.y * 2.6, "Checkpoint!", Color(1, 0.9, 0.5))
	create_tween().tween_property(_light, "light_energy", 2.2, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3(1.2, 0.8, 1.2), 0.08)
	tw.tween_property(_model, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

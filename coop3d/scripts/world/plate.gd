class_name PressurePlate
extends Area3D
## Pressure plate. Active while the weight on top reaches `required`.
## Weights: Lumi 1, Bolota 2, crate 2 (so heavy plates need Bolota or a crate).

var level: Node
var channel := ""
var required := 1
var active := false
var _button: MeshInstance3D
var _ring_mat: ShaderMaterial
var _color: Color
var _press := 0.0


func setup(lvl: Node, ch: String, heavy := false) -> void:
	level = lvl
	channel = ch
	required = 2 if heavy else 1
	_color = level.channel_color(ch)
	collision_layer = 0
	collision_mask = 2 | 4
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.95 if not heavy else 1.15
	sh.height = 0.9
	cs.shape = sh
	cs.position = Vector3(0, 0.4, 0)
	add_child(cs)

	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = sh.radius + 0.15
	bm.bottom_radius = sh.radius + 0.3
	bm.height = 0.2
	base.mesh = bm
	base.position.y = 0.05
	base.material_override = Mats.toon(Color(0.55, 0.5, 0.62), {"detail_normal": Mats.N_STONE, "detail_strength": 0.5, "detail_scale": 1.5})
	add_child(base)

	_button = MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = sh.radius - 0.05
	tm.bottom_radius = sh.radius
	tm.height = 0.18
	_button.mesh = tm
	_button.position.y = 0.22
	_ring_mat = Mats.glow(_color, 0.9).duplicate()
	_button.material_override = _ring_mat
	add_child(_button)

	# glyph: heavy plates show a big weight symbol
	var l := Label3D.new()
	l.text = "⬇⬇" if heavy else "⬇"
	l.font_size = 96
	l.modulate = Color(1, 1, 1, 0.9)
	l.outline_size = 12
	l.outline_modulate = Color(0.2, 0.1, 0.3)
	l.rotation_degrees = Vector3(-90, 0, 0)
	l.position.y = 0.33
	l.pixel_size = 0.006
	add_child(l)


func _physics_process(delta: float) -> void:
	var w := 0
	for b in get_overlapping_bodies():
		if b is Player:
			if not b.is_busy() or b.state == "celebrate":
				w += b.weight + (b.carrying.weight if b.carrying is Player else 0) + (2 if b.carrying and not b.carrying is Player else 0)
		elif "weight" in b:
			w += b.weight
	var now := w >= required
	if now != active:
		active = now
		level.set_channel(channel, self, active)
		if active:
			Sfx.play("click", 1.0)
			Sfx.play("unlock", 1.2, -6.0)
			Vfx.ring(global_position + global_basis.y * 0.3, global_basis.y, _color, 2.0, 0.4)
			Vfx.burst(global_position + global_basis.y * 0.4, _color, 8, 3.0, 0.7, global_basis.y)
		else:
			Sfx.play("click", 0.7)
		if w > 0 and not active:
			Sfx.play("tock", 0.5, -6.0)  # not heavy enough
	_press = lerpf(_press, 1.0 if active else (0.4 if w > 0 else 0.0), 1.0 - exp(-14.0 * delta))
	_button.position.y = 0.22 - _press * 0.12
	_ring_mat.set_shader_parameter("energy", 0.6 + _press * 2.2)

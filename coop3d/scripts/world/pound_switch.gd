class_name PoundSwitch
extends StaticBody3D
## Big button that must be ground-pounded.
## mode "toggle": flips its channel (tide blocks).
## mode "timed": turns the channel on for `duration` seconds with an
## accelerating tick and a shrinking ring (race against the clock).

var level: Node
var channel := ""
var mode := "toggle"
var duration := 6.0
var _left := 0.0
var _cap: MeshInstance3D
var _mat: ShaderMaterial
var _label: Label3D
var _tick := 0.0
var _color: Color


func setup(lvl: Node, ch: String, m := "toggle", dur := 6.0) -> void:
	level = lvl
	channel = ch
	mode = m
	duration = dur
	_color = level.channel_color(ch)
	collision_layer = 1
	add_to_group("pound_target")
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.9
	bm.bottom_radius = 1.1
	bm.height = 0.4
	base.mesh = bm
	base.position.y = 0.2
	base.material_override = Mats.toon(Color(0.45, 0.4, 0.55), {"detail_normal": Mats.N_STONE, "detail_strength": 0.5})
	add_child(base)
	_cap = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.75
	sm.height = 0.8
	sm.is_hemisphere = true
	_cap.mesh = sm
	_cap.position.y = 0.4
	_mat = Mats.toon(_color, {"emission": _color, "emission_energy": 0.6, "spec_amount": 1.0, "outline": 0.02}).duplicate()
	_cap.material_override = _mat
	add_child(_cap)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.0
	cyl.height = 0.9
	cs.shape = cyl
	cs.position.y = 0.45
	add_child(cs)
	_label = Label3D.new()
	_label.font_size = 90
	_label.outline_size = 16
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 2.0
	_label.pixel_size = 0.008
	_label.text = "⟳" if mode == "toggle" else "⏱"
	_label.modulate = _color.lightened(0.4)
	add_child(_label)


func on_pound(_p: Node) -> void:
	var tw := create_tween()
	tw.tween_property(_cap, "scale", Vector3(1.3, 0.3, 1.3), 0.05)
	tw.tween_property(_cap, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Vfx.ring(global_position + global_basis.y * 0.5, global_basis.y, _color, 3.0)
	if mode == "toggle":
		level.toggle_channel(channel)
		Sfx.play("unlock", 1.0 if level.channel(channel) else 0.8)
	else:
		_left = duration
		_tick = 0.0
		level.set_channel(channel, self, true)
		Sfx.play("unlock", 1.1)


func _process(delta: float) -> void:
	if mode != "timed":
		return
	if _left > 0.0:
		_left -= delta
		_tick -= delta
		var urgency := 1.0 - _left / duration
		if _tick <= 0.0:
			_tick = lerpf(0.5, 0.12, urgency)
			Sfx.play("tick" if int(_left * 4.0) % 2 == 0 else "tock", 1.0 + urgency * 0.5, -6.0, 0.0)
		_label.text = "%d" % ceili(_left)
		_label.modulate = _color.lightened(0.4).lerp(Color(1, 0.3, 0.3), urgency)
		_mat.set_shader_parameter("emission_energy", 0.6 + 1.5 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02 * (1.0 + urgency))))
		if _left <= 0.0:
			level.set_channel(channel, self, false)
			_label.text = "⏱"
			_label.modulate = _color.lightened(0.4)
			_mat.set_shader_parameter("emission_energy", 0.6)
			Sfx.play("click", 0.6)

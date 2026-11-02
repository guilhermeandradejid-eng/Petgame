class_name Gate
extends StaticBody3D
## Energy gate inside a stone frame. Opens (dissolves) when every channel in
## `channels` is active. With `latch` it stays open for good.

var level: Node
var channels: Array = []
var latch := true
var opened := false
var _door: MeshInstance3D
var _door_mat: ShaderMaterial
var _shape: CollisionShape3D
var _lights: Array = []


func setup(lvl: Node, chs: Array, width := 4.0, height := 3.5, do_latch := true) -> void:
	level = lvl
	channels = chs
	latch = do_latch
	collision_layer = 1
	var stone := Mats.toon(Color(0.68, 0.62, 0.78), {"detail_normal": Mats.N_STONE, "detail_strength": 0.6, "detail_scale": 0.8, "noise_tint": 0.1})
	for side in [-1, 1]:
		var p := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.8, height + 0.6, 0.9)
		p.mesh = bm
		p.material_override = stone
		p.position = Vector3(side * (width * 0.5 + 0.4), (height + 0.6) * 0.5, 0)
		add_child(p)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		cs.shape = bs
		cs.position = p.position
		add_child(cs)
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(width + 2.2, 0.7, 1.1)
	top.mesh = tm
	top.material_override = stone
	top.position.y = height + 0.6
	add_child(top)
	var tcs := CollisionShape3D.new()
	var tbs := BoxShape3D.new()
	tbs.size = tm.size
	tcs.shape = tbs
	tcs.position = top.position
	add_child(tcs)
	# one indicator light per required channel
	for i in channels.size():
		var li := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.4
		li.mesh = sm
		var c: Color = level.channel_color(channels[i])
		li.material_override = Mats.glow(c.darkened(0.6), 0.3).duplicate()
		li.position = Vector3((i - (channels.size() - 1) * 0.5) * 0.7, height + 0.6, -0.6)
		add_child(li)
		_lights.append(li)

	_door = MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(width, height, 0.3)
	_door.mesh = dm
	_door_mat = Mats.toon(level.channel_color(channels[0]) if channels.size() > 0 else Color(0.6, 0.8, 1.0),
			{"emission": Color(0.5, 0.8, 1.0), "emission_energy": 0.8, "emission_pulse": 0.4, "rim_amount": 1.2}).duplicate()
	_door.material_override = _door_mat
	_door.position.y = height * 0.5
	add_child(_door)
	_shape = CollisionShape3D.new()
	var ds := BoxShape3D.new()
	ds.size = dm.size
	_shape.shape = ds
	_shape.position = _door.position
	add_child(_shape)
	level.channel_changed.connect(_on_channel)


func _on_channel(_name: String, _v: bool) -> void:
	var all := true
	for i in channels.size():
		var on: bool = level.channel(channels[i])
		var c: Color = level.channel_color(channels[i])
		(_lights[i].material_override as ShaderMaterial).set_shader_parameter("color", c if on else c.darkened(0.6))
		(_lights[i].material_override as ShaderMaterial).set_shader_parameter("energy", 2.5 if on else 0.3)
		all = all and on
	if all and not opened:
		_open()
	elif not all and opened and not latch:
		_close()


func _open() -> void:
	opened = true
	_shape.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_method(func(v): _door_mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.7)
	tw.tween_callback(func(): _door.visible = false)
	Sfx.play("unlock", 0.9)
	Sfx.play("sparkle", 1.0, -4.0)
	Juice.shake(0.15)
	Vfx.burst(_door.global_position, level.channel_color(channels[0]), 24, 6.0, 1.2)
	if latch:
		level.focus_on(global_position, 1.0)
		level.toast("Portão aberto!", Color(0.7, 0.95, 1.0))


func _close() -> void:
	opened = false
	_door.visible = true
	_shape.set_deferred("disabled", false)
	var tw := create_tween()
	tw.tween_method(func(v): _door_mat.set_shader_parameter("dissolve", v), 1.0, 0.0, 0.35)
	Sfx.play("click", 0.6)

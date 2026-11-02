class_name Bridge
extends StaticBody3D
## A block that is solid only while its channel is on (or off, if `invert`).
## When inactive it renders as a translucent hologram; switching materializes
## it with the dissolve shader. Used for light bridges and tide blocks.

var level: Node
var channel := ""
var invert := false
var solid := false
var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _solid_mat: ShaderMaterial
var _ghost_mat: ShaderMaterial
var _color: Color


func setup(lvl: Node, ch: String, size: Vector3, inverted := false, color := Color(-1, 0, 0)) -> void:
	level = lvl
	channel = ch
	invert = inverted
	_color = color if color.r >= 0.0 else level.channel_color(ch)
	collision_layer = 1
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	add_child(_mesh)
	_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	_shape.shape = bs
	add_child(_shape)
	_solid_mat = Mats.toon(_color.lerp(Color.WHITE, 0.25), {"emission": _color, "emission_energy": 0.35, "detail_normal": Mats.N_TILES,
			"detail_strength": 0.5, "detail_scale": 0.5, "rim_amount": 0.9}).duplicate()
	_ghost_mat = Mats.ghost(_color)
	level.channel_changed.connect(func(_n, _v): _refresh(false))
	_refresh(true)


func _refresh(instant: bool) -> void:
	var want: bool = level.channel(channel) != invert
	if want == solid and not instant:
		return
	solid = want
	_shape.set_deferred("disabled", not solid)
	if solid:
		_mesh.material_override = _solid_mat
		if not instant:
			var tw := create_tween()
			tw.tween_method(func(v): _solid_mat.set_shader_parameter("dissolve", v), 0.9, 0.0, 0.4)
			Sfx.play("sparkle", 1.3, -8.0)
	else:
		_mesh.material_override = _ghost_mat
	# kick players standing inside a block that just became solid
	if solid and not instant:
		for p in level.players:
			var local: Vector3 = to_local(p.global_position + p.up * 0.5)
			var half: Vector3 = (_mesh.mesh as BoxMesh).size * 0.5
			if absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z:
				p.global_position = to_global(Vector3(local.x, half.y + 0.05, local.z))

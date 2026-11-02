class_name WindFan
extends Area3D
## Updraft column. Lumi hovering inside rises a lot; Bolota barely moves.

var strength := 34.0
var height := 9.0
var _blades: Node3D


func setup(_lvl: Node, h := 9.0, s := 34.0) -> void:
	height = h
	strength = s
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.3
	cyl.height = height
	cs.shape = cyl
	cs.position.y = height * 0.5
	add_child(cs)
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 1.4
	bm.bottom_radius = 1.6
	bm.height = 0.35
	base.mesh = bm
	base.material_override = Mats.toon(Color(0.55, 0.62, 0.75), {"spec_amount": 1.0, "detail_normal": Mats.N_TILES, "detail_strength": 0.4})
	base.position.y = 0.17
	add_child(base)
	_blades = Node3D.new()
	_blades.position.y = 0.4
	add_child(_blades)
	for i in 4:
		var b := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.2, 0.05, 0.35)
		b.mesh = box
		b.position = Vector3(cos(i * TAU / 4.0) * 0.6, 0, sin(i * TAU / 4.0) * 0.6)
		b.rotation = Vector3(0.4, -i * TAU / 4.0, 0)
		b.material_override = Mats.toon(Color(0.95, 0.95, 1.0), {"rim_amount": 0.8})
		_blades.add_child(b)
	# streaks rising through the column
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.45)
	q.material = m
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.1
	p.direction = Vector3.UP
	p.spread = 3.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = height * 0.6
	p.initial_velocity_max = height * 0.9
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.add_point(0.2, Color(1, 1, 1, 1))
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	p.position.y = 0.6
	add_child(p)


func _process(delta: float) -> void:
	_blades.rotate_y(delta * 14.0)


func _physics_process(_delta: float) -> void:
	for b in get_overlapping_bodies():
		if b is Player:
			var h: float = (b.global_position - global_position).dot(global_basis.y)
			var falloff := clampf(1.0 - h / height, 0.15, 1.0)
			var s := strength * falloff
			if b.state == "hover":
				s *= 2.4
			if b.heavy:
				s *= 0.25
			b.wind += global_basis.y * s

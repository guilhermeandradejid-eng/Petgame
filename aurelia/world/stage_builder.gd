class_name StageBuilder
extends RefCounted
## Procedural "Glade of Aurel": everything is generated from a seed with primitive meshes, so the
## stage works with zero imported assets. (Blender path later: export .glb into assets/models/,
## name colliders with a "-col" suffix and swap props in place of the generators below.)

const GROUND := preload("res://vfx/shaders/ground.gdshader")
const FOLIAGE := preload("res://vfx/shaders/foliage.gdshader")
const GRASS := preload("res://vfx/shaders/grass_blade.gdshader")
const WATER := preload("res://vfx/shaders/water.gdshader")
const SPARK := preload("res://vfx/shaders/spark.gdshader")

var rng := RandomNumberGenerator.new()
var root: Node3D
var props := 0


func build(parent: Node3D, seed_val: int = 1337) -> Dictionary:
	rng.seed = seed_val
	root = Node3D.new()
	root.name = "Stage"
	parent.add_child(root)
	_ground()
	_cliffs()
	_trees()
	_rocks()
	_ruins()
	_stream()
	_grass()
	_fireflies()
	var info := {
		"player_spawn": Vector3(0, 0.1, 7),
		"enemy_spawns": [Vector3(-9, 0.1, -6), Vector3(9, 0.1, -4), Vector3(0, 0.1, -16), Vector3(-14, 0.1, 4), Vector3(13, 0.1, 6)],
		"dummy": Vector3(5, 0.1, 2),
		"props": props,
	}
	return info


func _mat_foliage(base: Color, light: Color, sway := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("light_color", light)
	m.set_shader_parameter("sway", sway)
	return m


func _body(pos: Vector3, shape: Shape3D, offset_y: float) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = offset_y
	b.add_child(cs)
	root.add_child(b)
	b.position = pos
	return b


func _ground() -> void:
	var m := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(140, 140)
	m.mesh = p
	var mat := ShaderMaterial.new()
	mat.shader = GROUND
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	var box := BoxShape3D.new()
	box.size = Vector3(140, 2, 140)
	_body(Vector3.ZERO, box, -1.0)


func _cliffs() -> void:
	# a broken ring of stepped stone outcrops framing the diorama
	var stone := _mat_foliage(Color(0.36, 0.34, 0.4), Color(0.55, 0.62, 0.38))
	var half := Game.ARENA_HALF + 4.0
	for side in 4:
		var n := 7
		for i in n:
			var t := (float(i) / (n - 1) - 0.5) * 2.0 * (half + 4.0)
			var h := rng.randf_range(2.2, 6.0)
			var w := rng.randf_range(5.0, 8.5)
			var d := rng.randf_range(4.0, 6.0)
			var pos := Vector3.ZERO
			var size := Vector3(w, h, d)
			match side:
				0: pos = Vector3(t, h * 0.5, -half - d * 0.4)
				1: pos = Vector3(t, h * 0.5, half + d * 0.9)
				2:
					pos = Vector3(-half - d * 0.4, h * 0.5, t)
					size = Vector3(d, h, w)
				3:
					pos = Vector3(half + d * 0.4, h * 0.5, t)
					size = Vector3(d, h, w)
			if side == 1 and absf(t) < 10.0:
				continue      # keep the front open so the camera sees into the glade
			var m := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = size
			m.mesh = bm
			m.material_override = stone
			m.position = pos
			root.add_child(m)
			# a bevelled cap
			var cap := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(size.x * 0.82, 0.5, size.z * 0.82)
			cap.mesh = cm
			cap.material_override = _mat_foliage(Color(0.2, 0.45, 0.22), Color(0.45, 0.72, 0.3))
			cap.position = pos + Vector3(0, size.y * 0.5 + 0.2, 0)
			root.add_child(cap)
			var bs := BoxShape3D.new()
			bs.size = size
			_body(pos, bs, 0.0)
			props += 2


func _tree(pos: Vector3, scale_f: float) -> void:
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.3
	cm.height = 2.6
	cm.radial_segments = 6
	trunk.mesh = cm
	trunk.material_override = _mat_foliage(Color(0.3, 0.2, 0.15), Color(0.42, 0.3, 0.2))
	trunk.position = pos + Vector3(0, 1.3 * scale_f, 0)
	trunk.scale = Vector3.ONE * scale_f
	root.add_child(trunk)
	var leaf := _mat_foliage(Color(0.16, 0.42, 0.24), Color(0.5, 0.8, 0.32), 1.0)
	for k in 3:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(1.0, 1.5)
		sm.height = sm.radius * 1.8
		sm.radial_segments = 7
		sm.rings = 4
		s.mesh = sm
		s.material_override = leaf
		var off := Vector3(rng.randf_range(-0.7, 0.7), 2.4 + k * 0.55 + rng.randf_range(0, 0.3), rng.randf_range(-0.7, 0.7))
		s.position = pos + off * scale_f
		s.scale = Vector3.ONE * scale_f
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(s)
	var cs := CylinderShape3D.new()
	cs.radius = 0.4 * scale_f
	cs.height = 2.0
	_body(pos, cs, 1.0)
	props += 5


func _near_path_or_spawn(p: Vector3) -> bool:
	if Vector2(p.x, p.z).distance_to(Vector2(0, 5)) < 6.0:
		return true
	if Vector2(p.x, p.z).distance_to(Vector2(5, 2)) < 2.5:
		return true
	return false


func _trees() -> void:
	var placed := 0
	var tries := 0
	while placed < 38 and tries < 400:
		tries += 1
		var p := Vector3(rng.randf_range(-27, 27), 0, rng.randf_range(-27, 22))
		var edge := maxf(absf(p.x), absf(p.z))
		if edge < 12.0 and rng.randf() < 0.85:
			continue          # keep the middle open for fighting
		if _near_path_or_spawn(p):
			continue
		_tree(p, rng.randf_range(0.85, 1.35))
		placed += 1


func _rocks() -> void:
	var rock := _mat_foliage(Color(0.38, 0.36, 0.42), Color(0.62, 0.64, 0.58))
	for i in 14:
		var p := Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 16))
		if _near_path_or_spawn(p):
			continue
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radial_segments = 6
		sm.rings = 3
		m.mesh = sm
		var s := rng.randf_range(0.5, 1.1)
		m.scale = Vector3(s, s * 0.65, s * 0.9)
		m.rotation.y = rng.randf() * TAU
		m.position = p + Vector3(0, s * 0.3, 0)
		m.material_override = rock
		root.add_child(m)
		var cs := CylinderShape3D.new()
		cs.radius = s * 0.8
		cs.height = 1.0
		_body(p, cs, 0.5)
		props += 2


func _ruins() -> void:
	var stone := _mat_foliage(Color(0.52, 0.5, 0.5), Color(0.8, 0.78, 0.7))
	var spots := [Vector3(-6, 0, -12), Vector3(-3, 0, -12.5), Vector3(7, 0, -11), Vector3(12, 0, -9)]
	for i in spots.size():
		var h: float = [3.2, 2.1, 3.6, 1.4][i]
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.42
		cm.bottom_radius = 0.5
		cm.height = h
		cm.radial_segments = 8
		m.mesh = cm
		m.material_override = stone
		m.position = spots[i] + Vector3(0, h * 0.5, 0)
		root.add_child(m)
		var cs := CylinderShape3D.new()
		cs.radius = 0.5
		cs.height = h
		_body(spots[i], cs, h * 0.5)
		props += 2
	# fallen column
	var fm := MeshInstance3D.new()
	var fc := CylinderMesh.new()
	fc.top_radius = 0.42
	fc.bottom_radius = 0.45
	fc.height = 3.0
	fc.radial_segments = 8
	fm.mesh = fc
	fm.material_override = stone
	fm.rotation_degrees = Vector3(0, 25, 90)
	fm.position = Vector3(-0.5, 0.42, -13.5)
	root.add_child(fm)
	var fb := BoxShape3D.new()
	fb.size = Vector3(2.8, 0.8, 0.9)
	var b := _body(fm.position, fb, 0.0)
	b.rotation_degrees.y = 25
	props += 2


func _stream() -> void:
	var w := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(70, 3.2)
	w.mesh = p
	var mat := ShaderMaterial.new()
	mat.shader = WATER
	w.material_override = mat
	w.position = Vector3(0, 0.03, -17.5)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(w)
	# plank bridge
	var wood := _mat_foliage(Color(0.42, 0.28, 0.18), Color(0.6, 0.42, 0.26))
	for i in 9:
		var pl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.36, 0.1, 3.8)
		pl.mesh = bm
		pl.material_override = wood
		pl.position = Vector3(-1.6 + i * 0.4, 0.14, -17.5)
		root.add_child(pl)
	for sz in [-1.8, 1.8]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(3.8, 0.1, 0.1)
		rail.mesh = rm
		rail.material_override = wood
		rail.position = Vector3(0.2, 0.7, -17.5 + sz)
		root.add_child(rail)
	props += 12


func _grass() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.36, 0.34)
	q.center_offset = Vector3(0, 0.17, 0)
	mm.mesh = q
	var n := 900 if Game.low_quality else 2200
	mm.instance_count = n
	for i in n:
		var p := Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 26))
		var s := rng.randf_range(0.7, 1.25)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), p))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = GRASS
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	props += n


func _fireflies() -> void:
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(24, 1.6, 24)
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.3
	p.gravity = Vector3.ZERO
	p.color = Color(1.0, 0.95, 0.5, 0.9)
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var sm := ShaderMaterial.new()
	sm.shader = SPARK
	q.material = sm
	p.mesh = q
	p.position = Vector3(0, 1.6, 0)
	root.add_child(p)

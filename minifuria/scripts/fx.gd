class_name Fx
extends Node3D
## Game juice no mundo 3D: faíscas, fumaça, fogo, explosões, vidro, nitro, marcas de pneu, rastros e destroços.

var soft_tex: GradientTexture2D
var pools := {}
var pool_i := {}
var skid_mm: MultiMesh
var skid_head := 0
const SKID_MAX := 1600
var debris: Array = []
const DEBRIS_MAX := 70
var trails: Array = []   # {mesh: ImmediateMesh, pts: Array, life}


func _ready() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	soft_tex = GradientTexture2D.new()
	soft_tex.gradient = g
	soft_tex.fill = GradientTexture2D.FILL_RADIAL
	soft_tex.fill_from = Vector2(0.5, 0.5)
	soft_tex.fill_to = Vector2(1.0, 0.5)
	soft_tex.width = 64
	soft_tex.height = 64

	_pool("sparks", 10, func(): return _sparks())
	_pool("smoke", 10, func(): return _puff(Color(0.92, 0.91, 0.94, 0.75), 14, 1.2, 1.6, 3.4))
	_pool("dust", 10, func(): return _puff(Color(0.85, 0.77, 0.6, 0.8), 10, 0.9, 1.2, 2.8))
	_pool("fire", 5, func(): return _fireball())
	_pool("darksmoke", 5, func(): return _puff(Color(0.2, 0.19, 0.22, 0.8), 18, 2.2, 2.0, 5.0))
	_pool("glass", 5, func(): return _glass())
	_pool("confetti", 3, func(): return _confetti())
	_pool("ring", 4, func(): return _ring())

	# marcas de pneu: multimesh de quads no chão
	skid_mm = MultiMesh.new()
	skid_mm.transform_format = MultiMesh.TRANSFORM_3D
	skid_mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.orientation = PlaneMesh.FACE_Y
	skid_mm.mesh = q
	skid_mm.instance_count = SKID_MAX
	skid_mm.visible_instance_count = 0
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.08, 0.08, 0.09)
	sm.vertex_color_use_as_albedo = true
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = sm
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = skid_mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _pool(name_: String, count: int, maker: Callable) -> void:
	pools[name_] = []
	pool_i[name_] = 0
	for i in count:
		var p: Node3D = maker.call()
		add_child(p)
		pools[name_].append(p)


func _next(name_: String) -> Node3D:
	var arr: Array = pools[name_]
	var i: int = pool_i[name_]
	pool_i[name_] = (i + 1) % arr.size()
	return arr[i]


func billboard_mat(add: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_tex
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	return m


func _base(amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false
	return p


func _curve(a: float, b: float, c: float) -> Curve:
	var cv := Curve.new()
	cv.add_point(Vector2(0, a))
	cv.add_point(Vector2(0.3, b))
	cv.add_point(Vector2(1, c))
	return cv


func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / (cols.size() - 1))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	return g


func _sparks() -> CPUParticles3D:
	var p := _base(26, 0.55)
	var m := BoxMesh.new()
	m.size = Vector3(0.07, 0.07, 0.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(4.0, 2.4, 0.8)
	m.material = mat
	p.mesh = m
	p.particle_flag_align_y = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 70
	p.initial_velocity_min = 5
	p.initial_velocity_max = 14
	p.gravity = Vector3(0, -24, 0)
	p.damping_min = 1
	p.damping_max = 3
	p.scale_amount_curve = _curve(1.0, 0.8, 0.0)
	p.color_ramp = _ramp([Color(1, 1, 0.8), Color(1, 0.7, 0.2), Color(1, 0.2, 0.05)])
	return p


func _puff(col: Color, amount: int, life: float, s0: float, s1: float) -> CPUParticles3D:
	var p := _base(amount, life)
	p.explosiveness = 0.85
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = billboard_mat(false)
	p.mesh = q
	p.direction = Vector3(0, 1, 0)
	p.spread = 80
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, 1.2, 0)
	p.damping_min = 2
	p.damping_max = 3
	p.scale_amount_min = s0
	p.scale_amount_max = s0 * 1.4
	p.scale_amount_curve = _curve(0.5, 0.9, s1 / s0 * 0.6)
	var c0 := col
	var c1 := col
	c1.a = 0
	p.color_ramp = _ramp([c0, c0, c1])
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	return p


func _fireball() -> CPUParticles3D:
	var p := _base(40, 0.8)
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = billboard_mat(true)
	p.mesh = q
	p.direction = Vector3(0, 1, 0)
	p.spread = 180
	p.initial_velocity_min = 3
	p.initial_velocity_max = 13
	p.gravity = Vector3(0, 4, 0)
	p.damping_min = 3
	p.damping_max = 5
	p.scale_amount_min = 1.8
	p.scale_amount_max = 3.2
	p.scale_amount_curve = _curve(1.0, 0.8, 0.1)
	p.color_ramp = _ramp([Color(3, 2.6, 1.6, 1), Color(2.5, 1.0, 0.2, 1), Color(1.2, 0.2, 0.05, 0.8), Color(0.2, 0.05, 0.05, 0)])
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.8
	return p


func _glass() -> CPUParticles3D:
	var p := _base(24, 1.2)
	var m := BoxMesh.new()
	m.size = Vector3(0.14, 0.03, 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.92, 1.0, 0.85)
	mat.metallic = 0.5
	mat.roughness = 0.05
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.8, 1.0)
	mat.emission_energy_multiplier = 0.6
	m.material = mat
	p.mesh = m
	p.direction = Vector3(0, 1, 0)
	p.spread = 70
	p.initial_velocity_min = 3
	p.initial_velocity_max = 9
	p.gravity = Vector3(0, -24, 0)
	p.angular_velocity_min = -720
	p.angular_velocity_max = 720
	p.particle_flag_rotate_y = true
	p.scale_amount_curve = _curve(1.0, 1.0, 0.0)
	return p


func _confetti() -> CPUParticles3D:
	var p := _base(80, 2.0)
	var m := QuadMesh.new()
	m.size = Vector2(0.3, 0.18)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.material = mat
	p.mesh = m
	p.direction = Vector3(0, 1, 0)
	p.spread = 45
	p.initial_velocity_min = 8
	p.initial_velocity_max = 16
	p.gravity = Vector3(0, -12, 0)
	p.damping_min = 1
	p.damping_max = 2
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	p.color_initial_ramp = _ramp([Color("#ff4d6d"), Color("#ffd23a"), Color("#4dd2ff"), Color("#7dff6a"), Color("#c77dff")])
	return p


func _ring() -> MeshInstance3D:
	# onda de choque (nitro / takedown): anel que cresce e some
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	t.rings = 24
	t.ring_segments = 6
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.5, 0.9, 2.0, 1.0)
	mi.material_override = m
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ------------------------------------------------------------------ disparos
func burst(kind: String, pos: Vector3, dir := Vector3.UP, scale_ := 1.0) -> void:
	var p := _next(kind) as CPUParticles3D
	p.global_position = pos
	if dir != Vector3.UP:
		p.direction = (dir.normalized() + Vector3.UP * 0.6).normalized()
	p.restart()
	p.emitting = true


func sparks(pos: Vector3, dir: Vector3, power: float) -> void:
	var p := _next("sparks") as CPUParticles3D
	p.global_position = pos
	p.direction = (dir.normalized() + Vector3.UP * 0.7).normalized()
	p.initial_velocity_min = 4.0 + power * 4.0
	p.initial_velocity_max = 9.0 + power * 10.0
	p.amount = int(clampf(10 + power * 30, 10, 40))
	p.restart()
	p.emitting = true


func ring(pos: Vector3, col: Color, size: float) -> void:
	var r := _next("ring") as MeshInstance3D
	r.global_position = pos + Vector3(0, 0.3, 0)
	r.visible = true
	r.scale = Vector3.ONE * 0.5
	var m := r.material_override as StandardMaterial3D
	m.albedo_color = col
	var tw := create_tween().set_parallel()
	tw.tween_property(r, "scale", Vector3(size, 1.0, size), 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(func(): r.visible = false)


func explosion(pos: Vector3, big: bool) -> void:
	burst("fire", pos + Vector3(0, 0.6, 0))
	burst("darksmoke", pos + Vector3(0, 1.0, 0))
	sparks(pos + Vector3(0, 0.6, 0), Vector3.UP, 1.6)
	sparks(pos + Vector3(0, 0.6, 0), Vector3(1, 0.2, 0), 1.2)
	if big:
		burst("glass", pos + Vector3(0, 1.2, 0))
		ring(pos, Color(2.0, 1.0, 0.3, 1.0), 9.0)
	# clarão de luz
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 10.0 if big else 5.0
	l.omni_range = 14.0
	add_child(l)
	l.global_position = pos + Vector3(0, 2, 0)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ emissores contínuos por carro
func make_tire_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 36
	p.lifetime = 1.1
	p.emitting = false
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = billboard_mat(false)
	p.mesh = q
	p.direction = Vector3(0, 1, 0)
	p.spread = 50
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, 0.8, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.9
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _curve(0.5, 1.4, 3.0)
	p.color_ramp = _ramp([Color(0.95, 0.95, 0.97, 0.0), Color(0.95, 0.95, 0.97, 0.7), Color(0.9, 0.9, 0.93, 0.0)])
	return p


func make_nitro_flame() -> Node3D:
	# chama azul do nitro: partículas aditivas + núcleo brilhante
	var root := Node3D.new()
	var p := CPUParticles3D.new()
	p.amount = 48
	p.lifetime = 0.22
	p.emitting = false
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = billboard_mat(true)
	p.mesh = q
	p.direction = Vector3(0, 0, -1)
	p.spread = 7
	p.initial_velocity_min = 7
	p.initial_velocity_max = 11
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.1
	p.scale_amount_curve = _curve(1.0, 0.7, 0.1)
	p.color_ramp = _ramp([Color(2.5, 2.8, 3.0, 1), Color(0.4, 1.4, 3.0, 1), Color(0.6, 0.3, 2.6, 0.8), Color(0.3, 0.1, 1.0, 0)])
	p.name = "P"
	root.add_child(p)
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.2
	cm.height = 1.4
	cm.radial_segments = 8
	core.mesh = cm
	core.rotation.x = -PI / 2
	core.position.z = -0.7
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.6, 2.4, 3.0, 0.9)
	core.material_override = m
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.visible = false
	core.name = "Core"
	root.add_child(core)
	return root


func make_damage_smoke(dark: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 1.6
	p.emitting = false
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = billboard_mat(not dark)
	p.mesh = q
	p.direction = Vector3(0, 1, 0)
	p.spread = 20
	p.initial_velocity_min = 2
	p.initial_velocity_max = 4
	p.gravity = Vector3(0, 1, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	p.scale_amount_curve = _curve(0.6, 1.4, 2.6)
	if dark:
		p.color_ramp = _ramp([Color(0.25, 0.24, 0.26, 0.0), Color(0.25, 0.24, 0.26, 0.75), Color(0.5, 0.5, 0.52, 0.0)])
	else:
		p.lifetime = 0.6
		p.color_ramp = _ramp([Color(3, 2.2, 0.8, 1), Color(2.4, 0.8, 0.15, 0.9), Color(0.6, 0.1, 0.05, 0)])
	return p


# ------------------------------------------------------------------ marcas de pneu
func skid(a: Vector3, b: Vector3, width: float, alpha: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.05:
		return
	var mid := (a + b) * 0.5
	mid.y = 0.045
	var z := d / l
	var x := Vector3.UP.cross(z).normalized()
	var basis := Basis(x * width, Vector3.UP, z * (l + 0.05))
	skid_mm.set_instance_transform(skid_head, Transform3D(basis, mid))
	skid_mm.set_instance_color(skid_head, Color(1, 1, 1, alpha))
	skid_head = (skid_head + 1) % SKID_MAX
	skid_mm.visible_instance_count = mini(SKID_MAX, maxi(skid_mm.visible_instance_count, skid_head if skid_head > 0 else SKID_MAX))


# ------------------------------------------------------------------ rastros (fitas que somem)
func make_trail(col: Color) -> Dictionary:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var t := {"mesh": im, "pts": [], "col": col}
	trails.append(t)
	return t


func trail_push(t: Dictionary, p: Vector3, now: float, active: bool) -> void:
	var pts: Array = t.pts
	if active:
		pts.append([p, now])
	while pts.size() > 0 and now - pts[0][1] > 0.4:
		pts.pop_front()
	var im: ImmediateMesh = t.mesh
	im.clear_surfaces()
	if pts.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var a: float = 1.0 - (now - pts[i][1]) / 0.4
		var c: Color = t.col
		c.a = a * 0.9
		var w := 0.28 * a
		im.surface_set_color(c)
		im.surface_add_vertex(pts[i][0] + Vector3(0, w, 0))
		im.surface_set_color(c)
		im.surface_add_vertex(pts[i][0] - Vector3(0, w, 0))
	im.surface_end()


# ------------------------------------------------------------------ destroços físicos
func spawn_debris(mesh: MeshInstance3D, xform: Transform3D, vel: Vector3, is_wheel: bool) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.collision_layer = 8
	rb.collision_mask = 1 | 8
	rb.mass = 30.0 if is_wheel else 15.0
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.7 if is_wheel else 0.5
	rb.physics_material_override = pm
	var aabb := mesh.mesh.get_aabb()
	var center := aabb.get_center()
	add_child(rb)
	rb.global_transform = Transform3D(xform.basis.orthonormalized(), xform * center)
	mesh.transform = Transform3D(Basis.IDENTITY, -center)
	mesh.visible = true
	rb.add_child(mesh)
	var cs := CollisionShape3D.new()
	if is_wheel:
		var cy := CylinderShape3D.new()
		cy.radius = maxf(aabb.size.y, aabb.size.z) * 0.5
		cy.height = aabb.size.x
		cs.shape = cy
		cs.rotation.z = PI / 2
	else:
		var bx := BoxShape3D.new()
		bx.size = aabb.size.max(Vector3(0.12, 0.12, 0.12))
		cs.shape = bx
	rb.add_child(cs)
	rb.linear_velocity = vel
	rb.angular_velocity = Vector3(randf_range(-12, 12), randf_range(-8, 8), randf_range(-12, 12))
	if is_wheel:
		rb.angular_velocity = xform.basis.x * randf_range(15, 30)
	debris.append({"rb": rb, "t": 0.0, "life": randf_range(7, 10)})
	while debris.size() > DEBRIS_MAX:
		var d: Dictionary = debris.pop_front()
		(d.rb as Node).queue_free()
	return rb


func _process(dt: float) -> void:
	for i in range(debris.size() - 1, -1, -1):
		var d: Dictionary = debris[i]
		d.t += dt
		if d.t > d.life:
			var rb: RigidBody3D = d.rb
			var s := maxf(0.0, 1.0 - (d.t - d.life) * 2.0)
			for c in rb.get_children():
				if c is MeshInstance3D:
					c.scale = Vector3.ONE * maxf(0.01, s)
			if s <= 0.0:
				rb.queue_free()
				debris.remove_at(i)

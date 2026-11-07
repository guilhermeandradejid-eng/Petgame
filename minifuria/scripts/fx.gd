class_name Fx
extends Node3D
## Game juice no mundo 3D. Texturas de fumaça/fogo geradas por ruído, faíscas esticadas na direção da
## velocidade, chama de nitro com shader, linhas de vento, marcas de pneu, queimados, ondas de choque e destroços.

var smoke_tex: ImageTexture
var fire_tex: ImageTexture
var dot_tex: GradientTexture2D
var skid_tex: GradientTexture2D
var pools := {}
var pool_i := {}
var skid_mm: MultiMesh
var skid_head := 0
const SKID_MAX := 2000
var debris: Array = []
const DEBRIS_MAX := 80
var trails: Array = []
var ground_marks: Array = []
var ground_shader: Shader


func _ready() -> void:
	smoke_tex = _cloud_tex(128, 1337, true)
	fire_tex = _cloud_tex(128, 7, false)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	dot_tex = GradientTexture2D.new()
	dot_tex.gradient = g
	dot_tex.fill = GradientTexture2D.FILL_RADIAL
	dot_tex.fill_from = Vector2(0.5, 0.5)
	dot_tex.fill_to = Vector2(1.0, 0.5)
	var sg := Gradient.new()
	sg.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
	sg.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	skid_tex = GradientTexture2D.new()
	skid_tex.gradient = sg
	skid_tex.width = 32
	skid_tex.height = 4
	ground_shader = load("res://shaders/ground_fx.gdshader")

	_pool("sparks", 12, _sparks)
	_pool("smoke", 10, func(): return _puff(Color(0.93, 0.92, 0.95, 0.85), 16, 1.6, 1.4, 4.0, false))
	_pool("dust", 10, func(): return _puff(Color(0.82, 0.73, 0.56, 0.85), 14, 1.3, 1.2, 3.4, false))
	_pool("fire", 5, _fireball)
	_pool("embers", 5, _embers)
	_pool("darksmoke", 5, func(): return _puff(Color(0.17, 0.16, 0.18, 0.9), 22, 3.2, 2.2, 7.0, true))
	_pool("glass", 5, _glass)
	_pool("confetti", 3, _confetti)
	_pool("ring", 5, func(): return _ground_quad(2))
	_pool("scorch", 10, func(): return _ground_quad(1))

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
	sm.albedo_color = Color(0.05, 0.05, 0.06)
	sm.albedo_texture = skid_tex
	sm.vertex_color_use_as_albedo = true
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.render_priority = -1
	q.material = sm
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = skid_mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ------------------------------------------------------------------ texturas procedurais
func _cloud_tex(size: int, seed_: int, shaded: bool) -> ImageTexture:
	# nuvem de ruído fbm com borda arredondada; a fumaça tem "luz" pintada (topo claro, base escura)
	var nz := FastNoiseLite.new()
	nz.seed = seed_
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.fractal_type = FastNoiseLite.FRACTAL_FBM
	nz.fractal_octaves = 4
	nz.frequency = 0.045
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c) / c
			var r := d.length()
			var n := nz.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - r * (0.85 + n * 0.5)) * 2.2, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			var lum := 1.0
			if shaded:
				lum = clampf(0.72 + (-d.y * 0.22 - d.x * 0.1) + (n - 0.5) * 0.35, 0.45, 1.1)
			else:
				lum = clampf(0.6 + n * 0.6 + (1.0 - r) * 0.3, 0.0, 1.0)
			img.set_pixel(x, y, Color(lum, lum, lum, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _bb_mat(tex: Texture2D, add: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_receive_shadows = true
	return m


func billboard_mat(add: bool) -> StandardMaterial3D:
	return _bb_mat(fire_tex if add else smoke_tex, add)


func _streak_mesh(w: float, l: float) -> ArrayMesh:
	# dois quads cruzados ao longo de Y (visíveis de qualquer ângulo), para alinhar à velocidade
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ax in [Vector3(w, 0, 0), Vector3(0, 0, w)]:
		var a: Vector3 = -ax * 0.5
		var b: Vector3 = ax * 0.5
		var top := Vector3(0, l * 0.5, 0)
		var bot := Vector3(0, -l * 0.5, 0)
		for v in [[a + bot, Vector2(0, 1)], [b + bot, Vector2(1, 1)], [b + top, Vector2(1, 0)], [a + bot, Vector2(0, 1)], [b + top, Vector2(1, 0)], [a + top, Vector2(0, 0)]]:
			st.set_uv(v[1])
			st.add_vertex(v[0])
	return st.commit()


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


func _base(amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _curve(pts: Array) -> Curve:
	var cv := Curve.new()
	cv.max_value = 8.0
	for p in pts:
		cv.add_point(p)
	return cv


func _ramp(cols: Array, offs: Array = []) -> Gradient:
	var g := Gradient.new()
	var o := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in cols.size():
		o.append(offs[i] if offs.size() == cols.size() else float(i) / (cols.size() - 1))
		cs.append(cols[i])
	g.offsets = o
	g.colors = cs
	return g


func _sparks() -> CPUParticles3D:
	var p := _base(30, 0.6)
	var m := _streak_mesh(0.07, 0.7)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = dot_tex
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	p.mesh = m
	p.particle_flag_align_y = true
	p.direction = Vector3(0, 1, 0)
	p.spread = 70
	p.initial_velocity_min = 5
	p.initial_velocity_max = 15
	p.gravity = Vector3(0, -26, 0)
	p.damping_min = 1
	p.damping_max = 3
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _curve([Vector2(0, 1.0), Vector2(0.7, 0.8), Vector2(1, 0.0)])
	p.color_ramp = _ramp([Color(4, 4, 3, 1), Color(4, 2.4, 0.7, 1), Color(3, 0.8, 0.15, 0.9), Color(1, 0.2, 0.05, 0)])
	return p


func _puff(col: Color, amount: int, life: float, s0: float, s1: float, rising: bool) -> CPUParticles3D:
	var p := _base(amount, life)
	p.explosiveness = 0.8
	p.randomness = 0.5
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _bb_mat(smoke_tex, false)
	p.mesh = q
	p.direction = Vector3(0, 1, 0)
	p.spread = 75
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, 2.2 if rising else 0.6, 0)
	p.damping_min = 2
	p.damping_max = 3.5
	p.angle_min = 0
	p.angle_max = 360
	p.angular_velocity_min = -40
	p.angular_velocity_max = 40
	p.scale_amount_min = s0 * 0.8
	p.scale_amount_max = s0 * 1.2
	p.scale_amount_curve = _curve([Vector2(0, 0.4), Vector2(0.25, 1.0), Vector2(1, s1 / s0)])
	var c1 := col
	c1.a = 0
	var c0 := col
	c0.a = 0
	p.color_ramp = _ramp([c0, col, col * Color(1, 1, 1, 0.6), c1], [0.0, 0.08, 0.5, 1.0])
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	return p


func _fireball() -> CPUParticles3D:
	var p := _base(44, 0.9)
	p.randomness = 0.6
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _bb_mat(fire_tex, true)
	p.mesh = q
	p.direction = Vector3(0, 1, 0)
	p.spread = 180
	p.initial_velocity_min = 3
	p.initial_velocity_max = 14
	p.gravity = Vector3(0, 6, 0)
	p.damping_min = 4
	p.damping_max = 6
	p.angle_min = 0
	p.angle_max = 360
	p.angular_velocity_min = -90
	p.angular_velocity_max = 90
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.6
	p.scale_amount_curve = _curve([Vector2(0, 0.6), Vector2(0.15, 1.2), Vector2(1, 0.3)])
	p.color_ramp = _ramp([Color(4, 3.6, 2.6, 1), Color(3.2, 1.5, 0.35, 1), Color(1.6, 0.35, 0.08, 0.8), Color(0.15, 0.05, 0.05, 0)], [0.0, 0.2, 0.55, 1.0])
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.0
	return p


func _embers() -> CPUParticles3D:
	var p := _base(40, 2.2)
	p.explosiveness = 0.9
	p.randomness = 0.8
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	q.material = _bb_mat(dot_tex, true)
	p.mesh = q
	p.direction = Vector3(0, 1, 0)
	p.spread = 60
	p.initial_velocity_min = 4
	p.initial_velocity_max = 12
	p.gravity = Vector3(0, 1.5, 0)
	p.damping_min = 1
	p.damping_max = 2.5
	p.color_ramp = _ramp([Color(4, 2.5, 0.8, 1), Color(3, 0.9, 0.2, 1), Color(1, 0.2, 0.05, 0)])
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2
	return p


func _glass() -> CPUParticles3D:
	var p := _base(36, 1.4)
	var m := BoxMesh.new()
	m.size = Vector3(0.16, 0.025, 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.94, 1.0, 0.8)
	mat.metallic = 0.6
	mat.roughness = 0.04
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.85, 1.0)
	mat.emission_energy_multiplier = 1.2
	m.material = mat
	p.mesh = m
	p.direction = Vector3(0, 1, 0)
	p.spread = 75
	p.initial_velocity_min = 3
	p.initial_velocity_max = 10
	p.gravity = Vector3(0, -26, 0)
	p.angular_velocity_min = -720
	p.angular_velocity_max = 720
	p.particle_flag_rotate_y = true
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.scale_amount_curve = _curve([Vector2(0, 1.0), Vector2(0.8, 1.0), Vector2(1, 0.0)])
	return p


func _confetti() -> CPUParticles3D:
	var p := _base(90, 2.4)
	var m := QuadMesh.new()
	m.size = Vector2(0.32, 0.2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material = mat
	p.mesh = m
	p.direction = Vector3(0, 1, 0)
	p.spread = 45
	p.initial_velocity_min = 9
	p.initial_velocity_max = 18
	p.gravity = Vector3(0, -12, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.angle_min = 0
	p.angle_max = 360
	p.angular_velocity_min = -500
	p.angular_velocity_max = 500
	p.particle_flag_rotate_y = true
	p.color_initial_ramp = _ramp([Color("#ff4d6d"), Color("#ffd23a"), Color("#4dd2ff"), Color("#7dff6a"), Color("#c77dff")])
	return p


func _ground_quad(mode: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = ground_shader
	m.set_shader_parameter("mode", mode)
	m.render_priority = 1 if mode == 2 else 0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


func contact_shadow(len_: float, wid: float) -> MeshInstance3D:
	var mi := _ground_quad(0)
	mi.visible = true
	mi.scale = Vector3(wid * 1.45, 1, len_ * 1.25)
	return mi


# ------------------------------------------------------------------ disparos
func burst(kind: String, pos: Vector3, dir := Vector3.UP, _scale := 1.0) -> void:
	var p := _next(kind) as CPUParticles3D
	p.global_position = pos
	if dir != Vector3.UP:
		p.direction = (dir.normalized() + Vector3.UP * 0.6).normalized()
	p.restart()
	p.emitting = true


func sparks(pos: Vector3, dir: Vector3, power: float) -> void:
	var p := _next("sparks") as CPUParticles3D
	p.global_position = pos
	p.direction = (dir.normalized() + Vector3.UP * 0.6).normalized()
	p.initial_velocity_min = 4.0 + power * 5.0
	p.initial_velocity_max = 9.0 + power * 12.0
	p.amount = int(clampf(12 + power * 30, 12, 46))
	p.restart()
	p.emitting = true


func ring(pos: Vector3, col: Color, size: float) -> void:
	var r := _next("ring") as MeshInstance3D
	r.global_position = Vector3(pos.x, 0.12, pos.z)
	r.visible = true
	r.scale = Vector3(size * 2.0, 1, size * 2.0)
	var m := r.material_override as ShaderMaterial
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("ring_t", 0.0)
	var tw := create_tween()
	tw.tween_method(func(t): m.set_shader_parameter("ring_t", t), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): r.visible = false)


func scorch(pos: Vector3, size: float) -> void:
	var s := _next("scorch") as MeshInstance3D
	s.global_position = Vector3(pos.x, 0.06, pos.z)
	s.rotation.y = randf() * TAU
	s.scale = Vector3(size, 1, size)
	s.visible = true
	var m := s.material_override as ShaderMaterial
	m.set_shader_parameter("strength", 1.0)
	var tw := create_tween()
	tw.tween_interval(14.0)
	tw.tween_method(func(t): m.set_shader_parameter("strength", t), 1.0, 0.0, 3.0)


func hit_light(pos: Vector3, col: Color, energy: float, rng: float, dur: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


func explosion(pos: Vector3, big: bool) -> void:
	burst("fire", pos + Vector3(0, 0.8, 0))
	burst("darksmoke", pos + Vector3(0, 1.2, 0))
	burst("embers", pos + Vector3(0, 1.0, 0))
	sparks(pos + Vector3(0, 0.6, 0), Vector3.UP, 1.8)
	sparks(pos + Vector3(0, 0.6, 0), Vector3(randf_range(-1, 1), 0.2, randf_range(-1, 1)), 1.3)
	scorch(pos, 6.0 if big else 4.0)
	ring(pos, Color(1.0, 0.55, 0.2, 1.0), 10.0 if big else 6.0)
	if big:
		burst("glass", pos + Vector3(0, 1.2, 0))
	hit_light(pos + Vector3(0, 2.5, 0), Color(1.0, 0.55, 0.2), 14.0 if big else 7.0, 18.0, 0.7)


# ------------------------------------------------------------------ emissores contínuos por carro
func make_tire_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 48
	p.lifetime = 1.8
	p.emitting = false
	p.local_coords = false
	p.randomness = 0.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _bb_mat(smoke_tex, false)
	p.mesh = q
	p.direction = Vector3(0, 1, 0)
	p.spread = 60
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, 0.7, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.angle_min = 0
	p.angle_max = 360
	p.angular_velocity_min = -30
	p.angular_velocity_max = 30
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.5
	p.scale_amount_curve = _curve([Vector2(0, 0.5), Vector2(0.3, 1.6), Vector2(1, 3.6)])
	p.color_ramp = _ramp([Color(0.96, 0.96, 0.98, 0.0), Color(0.96, 0.96, 0.98, 0.75), Color(0.9, 0.9, 0.93, 0.35), Color(0.9, 0.9, 0.93, 0.0)], [0.0, 0.08, 0.5, 1.0])
	return p


func make_dust() -> CPUParticles3D:
	var p := make_tire_smoke()
	p.amount = 24
	p.lifetime = 1.2
	p.color_ramp = _ramp([Color(0.8, 0.7, 0.5, 0.0), Color(0.8, 0.7, 0.5, 0.7), Color(0.8, 0.7, 0.5, 0.0)], [0.0, 0.1, 1.0])
	return p


func make_nitro_flame() -> Node3D:
	var root := Node3D.new()
	# partículas: faíscas azuis e fumaça quente
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.28
	p.emitting = false
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _bb_mat(fire_tex, true)
	p.mesh = q
	p.direction = Vector3(0, 0, -1)
	p.spread = 9
	p.initial_velocity_min = 8
	p.initial_velocity_max = 13
	p.gravity = Vector3.ZERO
	p.angle_min = 0
	p.angle_max = 360
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	p.scale_amount_curve = _curve([Vector2(0, 1.0), Vector2(0.4, 0.8), Vector2(1, 0.15)])
	p.color_ramp = _ramp([Color(3, 3.2, 3.5, 1), Color(0.5, 1.6, 3.5, 1), Color(0.8, 0.4, 3.0, 0.7), Color(0.3, 0.1, 1.0, 0)])
	p.name = "P"
	root.add_child(p)
	# núcleo: dois cones com shader de chama
	var core := Node3D.new()
	core.name = "Core"
	core.visible = false
	root.add_child(core)
	var sh := load("res://shaders/nitro.gdshader") as Shader
	for spec in [[0.26, 2.0, 1.0], [0.14, 1.3, 1.6]]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = spec[0]
		cm.height = spec[1]
		cm.radial_segments = 12
		cm.rings = 4
		mi.mesh = cm
		mi.rotation.x = -PI / 2
		mi.position.z = -spec[1] * 0.5 + 0.05
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("power", spec[2])
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		core.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(0.35, 0.7, 1.0)
	l.light_energy = 3.0
	l.omni_range = 6.0
	l.position.z = -1.0
	core.add_child(l)
	return root


func make_damage_smoke(dark: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 30 if dark else 26
	p.lifetime = 2.2 if dark else 0.7
	p.emitting = false
	p.local_coords = false
	p.randomness = 0.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _bb_mat(smoke_tex if dark else fire_tex, not dark)
	p.mesh = q
	p.direction = Vector3(0, 1, 0)
	p.spread = 18
	p.initial_velocity_min = 2
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, 1.5, 0)
	p.angle_min = 0
	p.angle_max = 360
	p.angular_velocity_min = -40
	p.angular_velocity_max = 40
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.1
	if dark:
		p.scale_amount_curve = _curve([Vector2(0, 0.6), Vector2(0.4, 1.8), Vector2(1, 3.4)])
		p.color_ramp = _ramp([Color(0.2, 0.19, 0.21, 0.0), Color(0.2, 0.19, 0.21, 0.85), Color(0.45, 0.45, 0.48, 0.4), Color(0.6, 0.6, 0.62, 0.0)], [0.0, 0.1, 0.6, 1.0])
	else:
		p.scale_amount_curve = _curve([Vector2(0, 1.2), Vector2(1, 0.3)])
		p.color_ramp = _ramp([Color(4, 3, 1.2, 1), Color(3, 1.1, 0.2, 0.9), Color(0.8, 0.15, 0.05, 0)])
	return p


func make_wind() -> CPUParticles3D:
	# linhas de vento em volta do carro em alta velocidade (alinhadas ao movimento)
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.35
	p.emitting = false
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := _streak_mesh(0.05, 4.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = dot_tex
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	p.mesh = m
	p.particle_flag_align_y = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(9, 2.5, 9)
	p.direction = Vector3(0, 0, -1)
	p.spread = 0
	p.initial_velocity_min = 2
	p.initial_velocity_max = 3
	p.gravity = Vector3.ZERO
	p.color_ramp = _ramp([Color(1.4, 1.6, 2.0, 0), Color(1.4, 1.6, 2.0, 0.55), Color(1.4, 1.6, 2.0, 0)])
	return p


func make_scrape() -> Node3D:
	# jato contínuo de faíscas (estilo Burnout) para quando o carro raspa no muro ou em outro carro
	var root := Node3D.new()
	var p := CPUParticles3D.new()
	p.name = "P"
	p.amount = 200
	p.lifetime = 0.6
	p.emitting = false
	p.local_coords = false
	p.randomness = 0.6
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := _streak_mesh(0.11, 1.3)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = dot_tex
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	p.mesh = m
	p.particle_flag_align_y = true
	p.direction = Vector3(0, 0.3, -1)
	p.spread = 24
	p.initial_velocity_min = 9
	p.initial_velocity_max = 20
	p.gravity = Vector3(0, -24, 0)
	p.damping_min = 0.5
	p.damping_max = 2
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.scale_amount_curve = _curve([Vector2(0, 1.0), Vector2(0.6, 0.85), Vector2(1, 0.0)])
	p.color_ramp = _ramp([Color(5, 5, 4, 1), Color(5, 3.2, 1.0, 1), Color(3.5, 1.1, 0.2, 0.9), Color(1, 0.2, 0.05, 0)], [0.0, 0.2, 0.6, 1.0])
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	root.add_child(p)
	# pontinhos que quicam no chão
	var b := CPUParticles3D.new()
	b.name = "B"
	b.amount = 50
	b.lifetime = 0.9
	b.emitting = false
	b.local_coords = false
	b.randomness = 0.7
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	q.material = _bb_mat(dot_tex, true)
	b.mesh = q
	b.direction = Vector3(0, 0.6, -1)
	b.spread = 40
	b.initial_velocity_min = 4
	b.initial_velocity_max = 10
	b.gravity = Vector3(0, -22, 0)
	b.color_ramp = _ramp([Color(5, 4, 2, 1), Color(4, 1.5, 0.3, 1), Color(1, 0.2, 0.05, 0)])
	root.add_child(b)
	var l := OmniLight3D.new()
	l.name = "L"
	l.light_color = Color(1.0, 0.65, 0.25)
	l.light_energy = 0.0
	l.omni_range = 8.0
	l.position.y = 0.8
	root.add_child(l)
	return root


func set_scrape(n: Node3D, on: bool, pos: Vector3, dir: Vector3, strength: float) -> void:
	var p := n.get_node("P") as CPUParticles3D
	var b := n.get_node("B") as CPUParticles3D
	var l := n.get_node("L") as OmniLight3D
	p.emitting = on
	b.emitting = on
	if on:
		n.global_position = pos
		p.direction = dir
		b.direction = (dir + Vector3.UP * 0.4).normalized()
		p.initial_velocity_min = 6.0 + strength * 6.0
		p.initial_velocity_max = 12.0 + strength * 14.0
		l.light_energy = randf_range(2.0, 6.0) * clampf(strength, 0.4, 1.2)
	else:
		l.light_energy = maxf(0.0, l.light_energy - 0.6)


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
	var basis := Basis(x * width, Vector3.UP, z * (l + 0.06))
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
	while pts.size() > 0 and now - pts[0][1] > 0.45:
		pts.pop_front()
	var im: ImmediateMesh = t.mesh
	im.clear_surfaces()
	if pts.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var a: float = 1.0 - (now - pts[i][1]) / 0.45
		var c: Color = t.col
		c.a = a * a
		var w := 0.22 * a + 0.03
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
	# peça solta leva um rastro de fumaça por um instante
	var sm := make_damage_smoke(true)
	sm.amount = 12
	sm.lifetime = 1.0
	sm.emitting = true
	rb.add_child(sm)
	get_tree().create_timer(1.2, false).timeout.connect(func(): if is_instance_valid(sm): sm.emitting = false)
	debris.append({"rb": rb, "t": 0.0, "life": randf_range(8, 12)})
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

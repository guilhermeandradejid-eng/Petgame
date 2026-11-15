class_name Level
extends Node3D
## Base dos niveis (vila e salas): arena plana delimitada por um contorno radial,
## com obstaculos circulares. Guarda o que a IA e o gerador precisam consultar.

const SAMPLES := 96

var rng := RandomNumberGenerator.new()
var spawn_points: Array = []
var spawn_yaw := 0.0
var obstacles: Array = []          # {pos: Vector3, r: float}
var bounds := PackedFloat32Array()  # raio do contorno por angulo
var base_r := 15.0
var env: Environment
var sun: DirectionalLight3D

func build(_room: Dictionary) -> void:
	pass

func on_room_event(_kind: String, _data: Dictionary) -> void:
	pass

# ------------------------------------------------------------------ contorno
func make_bounds(r: float, wobble: float) -> void:
	base_r = r
	bounds.resize(SAMPLES)
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var p3 := rng.randf() * TAU
	for i in SAMPLES:
		var a := TAU * i / SAMPLES
		bounds[i] = r * (1.0 + wobble * (0.6 * sin(2.0 * a + p1) + 0.3 * sin(3.0 * a + p2) + 0.2 * sin(5.0 * a + p3)))

func bounds_r(angle: float) -> float:
	var f := fposmod(angle, TAU) / TAU * SAMPLES
	var i := int(f) % SAMPLES
	var j := (i + 1) % SAMPLES
	return lerpf(bounds[i], bounds[j], f - floor(f))

func point_at(angle: float, k: float = 1.0) -> Vector3:
	return Vector3(cos(angle), 0, sin(angle)) * bounds_r(angle) * k

func clamp_inside(pos: Vector3, margin: float) -> Vector3:
	var l := Vector2(pos.x, pos.z).length()
	if l < 0.001:
		return pos
	var lim := bounds_r(atan2(pos.z, pos.x)) - margin
	if l > lim:
		var k := lim / l
		return Vector3(pos.x * k, pos.y, pos.z * k)
	return pos

func is_free(pos: Vector3, r: float) -> bool:
	if Vector2(pos.x, pos.z).length() > bounds_r(atan2(pos.z, pos.x)) - r - 0.5:
		return false
	for o in obstacles:
		if (o["pos"] as Vector3).distance_to(pos) < float(o["r"]) + r:
			return false
	return true

func enemy_spawn_points(n: int) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < n and tries < n * 30:
		tries += 1
		var a := randf() * TAU
		var p := point_at(a, randf_range(0.35, 0.86))
		var ok := is_free(p, 0.9)
		for pl: Player in Game.world.all_players():
			if pl.global_position.distance_to(p) < 6.5:
				ok = false
		if ok:
			out.append(p)
	while out.size() < n:
		out.append(point_at(randf() * TAU, 0.6))
	return out

# ------------------------------------------------------------------ construcao comum
func add_wall_collision(height: float = 9.0) -> void:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = 1
	var faces := PackedVector3Array()
	for i in SAMPLES:
		var a0 := TAU * i / SAMPLES
		var a1 := TAU * (i + 1) / SAMPLES
		var p0 := point_at(a0)
		var p1 := point_at(a1)
		var q0 := p0 + Vector3(0, height, 0)
		var q1 := p1 + Vector3(0, height, 0)
		p0.y = -1.0
		p1.y = -1.0
		faces.append_array([p0, p1, q1, p0, q1, q0])
	var sh := ConcavePolygonShape3D.new()
	sh.backface_collision = true
	sh.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = sh
	body.add_child(cs)
	add_child(body)

func add_floor_collision(size: float = 120.0) -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = 1
	var bx := BoxShape3D.new()
	bx.size = Vector3(size, 2.0, size)
	var cs := CollisionShape3D.new()
	cs.shape = bx
	cs.position.y = -1.0
	body.add_child(cs)
	add_child(body)

## Chao em malha polar com cor por vertice: manchas de cor + caminho + escurecida na borda.
func build_floor(col_a: Color, col_b: Color, col_edge: Color, extra: float = 9.0, path_col: Color = Color(0, 0, 0, 0)) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 22
	var segs := 72
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.09
	var noise2 := FastNoiseLite.new()
	noise2.seed = rng.randi()
	noise2.frequency = 0.35
	var grid: Array = []
	for ri in rings + 1:
		var row: Array = []
		for si in segs:
			var a := TAU * si / segs
			var lim := bounds_r(a)
			var t := float(ri) / rings
			var rad := (lim + extra) * pow(t, 0.85)
			var p := Vector3(cos(a) * rad, 0, sin(a) * rad)
			var n := noise.get_noise_2d(p.x, p.z) * 0.5 + 0.5
			var n2 := noise2.get_noise_2d(p.x, p.z) * 0.5 + 0.5
			var c := col_a.lerp(col_b, smoothstep(0.35, 0.65, n))
			c = c.lerp(c.lightened(0.12), n2 * 0.5)
			if path_col.a > 0.0:
				var pk := exp(-pow(p.x / 2.3, 2.0)) * smoothstep(0.25, 0.5, n2 + 0.25)
				c = c.lerp(path_col, pk * path_col.a)
			var edge := smoothstep(lim - 3.0, lim + 1.0, rad)
			c = c.lerp(col_edge, edge * 0.85)
			if rad > lim + 0.5:
				p.y = -0.02 + (rad - lim) * -0.06
			row.append([p, c])
		grid.append(row)
	for ri in rings:
		for si in segs:
			var sj := (si + 1) % segs
			var a0: Array = grid[ri][si]
			var a1: Array = grid[ri][sj]
			var b0: Array = grid[ri + 1][si]
			var b1: Array = grid[ri + 1][sj]
			for v: Array in [a0, b1, b0, a0, a1, b1]:
				st.set_color(v[1])
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.name = "FloorMesh"
	mi.mesh = st.commit()
	mi.material_override = Mats.toon(Color.WHITE, {"rim": 0.0, "half_tone": 0.0})
	add_child(mi)
	return mi

func add_obstacle(pos: Vector3, r: float) -> void:
	obstacles.append({"pos": pos, "r": r})

## Coloca uma peca do kit com colisao. Retorna o no (ou null se a peca nao existir).
func place(kit: String, piece: String, pos: Vector3, yaw: float = 0.0, scale: float = 1.0, solid: bool = true) -> Node3D:
	var mi := KitLib.make(kit, piece)
	if mi == null:
		return null
	var root: Node3D
	var cs := KitLib.collider(kit, piece, scale) if solid else null
	if cs:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.add_child(cs)
		root = body
		add_obstacle(pos, KitLib.collider_radius(kit, piece) * scale)
	else:
		root = Node3D.new()
	root.name = piece
	mi.scale = Vector3.ONE * scale
	root.add_child(mi)
	root.position = pos
	root.rotation.y = yaw
	var l := KitLib.light_of(kit, piece)
	if l:
		root.add_child(l)
	add_child(root)
	return root

## Espalha muitas copias de uma peca sem colisao usando MultiMesh.
func scatter_multi(kit: String, piece: String, xforms: Array) -> void:
	var m := KitLib.mesh(kit, piece)
	if m == null or xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "MM_" + piece
	var src := m.surface_get_material(0)
	mmi.material_override = Mats.env(src.resource_name if src else "vcol")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func fallback_block(pos: Vector3, r: float, h: float, col: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = h
	var cs := CollisionShape3D.new()
	cs.shape = cyl
	cs.position.y = h * 0.5
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.8
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 7
	mi.mesh = cm
	mi.position.y = h * 0.5
	mi.material_override = Mats.toon(col)
	body.add_child(mi)
	body.position = pos
	add_child(body)
	add_obstacle(pos, r)

# ------------------------------------------------------------------ atmosfera
## cfg: sun_dir (graus), sun_col, sun_e, amb, amb_e, sky_top, sky_hor, fog, fog_d, glow, vol
func make_environment(cfg: Dictionary) -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(str(cfg["sky_top"]))
	sm.sky_horizon_color = Color(str(cfg["sky_hor"]))
	sm.ground_bottom_color = Color(str(cfg.get("ground", cfg["sky_hor"])))
	sm.ground_horizon_color = Color(str(cfg["sky_hor"]))
	sm.sky_curve = 0.12
	sm.ground_curve = 0.08
	sm.sun_angle_max = 6.0
	sm.sun_curve = 0.08
	sm.sky_energy_multiplier = float(cfg.get("sky_e", 1.0))
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(str(cfg["amb"]))
	env.ambient_light_energy = float(cfg["amb_e"])
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.3
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.glow_enabled = true
	env.glow_intensity = float(cfg.get("glow", 0.7))
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = Color(str(cfg["fog"]))
	env.fog_density = float(cfg.get("fog_d", 0.012))
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.3
	env.fog_height = -4.0
	env.fog_height_density = 0.02
	if cfg.get("vol", false) and not Dev.low_gfx:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = float(cfg.get("vol_d", 0.012))
		env.volumetric_fog_albedo = Color(str(cfg["fog"]))
		env.volumetric_fog_emission = Color(str(cfg["fog"])) * 0.15
		env.volumetric_fog_length = 70.0
		env.volumetric_fog_anisotropy = 0.5
	env.adjustment_enabled = true
	env.adjustment_saturation = float(cfg.get("sat", 1.12))
	env.adjustment_contrast = 1.04
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	var sd: Vector2 = cfg["sun_dir"]
	sun.rotation_degrees = Vector3(sd.x, sd.y, 0)
	sun.light_color = Color(str(cfg["sun_col"]))
	sun.light_energy = float(cfg["sun_e"])
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.light_angular_distance = 1.5
	add_child(sun)

func add_motes(col: Color, count: int, area: float, height: float = 4.0) -> void:
	var cp := CPUParticles3D.new()
	cp.amount = count
	cp.lifetime = 7.0
	cp.preprocess = 7.0
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	cp.emission_box_extents = Vector3(area, height * 0.5, area)
	cp.position.y = height * 0.5 + 0.3
	cp.gravity = Vector3(0, 0.05, 0)
	cp.direction = Vector3(1, 0.2, 0.3)
	cp.spread = 180.0
	cp.initial_velocity_min = 0.1
	cp.initial_velocity_max = 0.45
	cp.scale_amount_min = 0.5
	cp.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	cp.scale_amount_curve = curve
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = Fx.soft_dot()
	qm.material = m
	cp.mesh = qm
	cp.name = "Motes"
	add_child(cp)

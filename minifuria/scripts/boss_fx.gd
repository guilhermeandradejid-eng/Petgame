class_name BossFx
extends RefCounted
## Peças visuais dos ataques de chefe (montadas por código, mas sem cara de "primitiva"):
## - esferas amassadas por ruído 3D com normais suaves (bola de neve, rocha do meteoro, bolota de lama);
## - faixa de pregos de polícia (placas sanfonadas com fileiras de pontas, desenrola na pista);
## - postes de portão laser (base sextavada, coluna com faixas de alerta, emissor com anel aceso);
## - rastros de partículas (fogo e fumaça do meteoro, neve espirrando, lama pingando, chamas no chão).

static var _cache := {}


# ------------------------------------------------------------------ malhas
static func _k(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))


## esfera deformada por ruído 3D: amp = fração do raio. Normais médias por posição (sem costura no UV).
static func lumpy(key: String, radius: float, amp: float, freq: float, seed_: int, rings := 16, segs := 28) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.rings = rings
	sm.radial_segments = segs
	var arr := sm.get_mesh_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nz := FastNoiseLite.new()
	nz.seed = seed_
	nz.frequency = freq
	nz.fractal_octaves = 3
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	for i in vs.size():
		var d := vs[i].normalized()
		vs[i] = d * radius * (1.0 + nz.get_noise_3dv(d * 2.0) * amp)
	var acc := {}
	for t in range(0, idx.size(), 3):
		var a := vs[idx[t]]
		var b := vs[idx[t + 1]]
		var c := vs[idx[t + 2]]
		var fn := (b - a).cross(c - a)
		if fn.dot(a + b + c) < 0.0:
			fn = -fn
		for j in 3:
			var kk := _k(vs[idx[t + j]])
			acc[kk] = (acc.get(kk, Vector3.ZERO) as Vector3) + fn
	var ns := PackedVector3Array()
	ns.resize(vs.size())
	for i in vs.size():
		ns[i] = (acc[_k(vs[i])] as Vector3).normalized()
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_cache[key] = m
	return m


static func _noise_tex(seed_: int, freq: float, c0: Color, c1: Color, normal := false) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = freq
	n.fractal_octaves = 4
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = 6.0
	else:
		var g := Gradient.new()
		g.colors = PackedColorArray([c0, c1])
		t.color_ramp = g
	return t


static func snow_mat() -> Material:
	if _cache.has("m_snow"):
		return _cache.m_snow
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1)
	m.albedo_texture = _noise_tex(5, 0.02, Color(0.78, 0.84, 0.93), Color(1.0, 1.0, 1.0))
	m.normal_enabled = true
	m.normal_texture = _noise_tex(9, 0.05, Color.BLACK, Color.WHITE, true)
	m.normal_scale = 0.7
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.45, 0.45, 0.45)
	m.roughness = 0.82
	m.rim_enabled = true
	m.rim = 0.45
	m.rim_tint = 0.3
	_cache.m_snow = m
	return m


static func mud_mat() -> Material:
	if _cache.has("m_mud"):
		return _cache.m_mud
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(3, 0.04, Color(0.16, 0.09, 0.03), Color(0.36, 0.23, 0.09))
	m.uv1_triplanar = true
	m.normal_enabled = true
	m.normal_texture = _noise_tex(4, 0.06, Color.BLACK, Color.WHITE, true)
	m.normal_scale = 0.8
	m.roughness = 0.22
	m.metallic_specular = 0.7
	_cache.m_mud = m
	return m


static func rock_mat() -> Material:
	if _cache.has("m_rock"):
		return _cache.m_rock
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/meteor_rock.gdshader")
	_cache.m_rock = m
	return m


static func metal_mat(col: Color, rough := 0.35, metal := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


static func glow_mat(col: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


## faixas diagonais amarelo/preto (alerta) para colunas e pontas da barreira
static func hazard_mat() -> Material:
	if _cache.has("m_haz"):
		return _cache.m_haz
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var on := ((x + y) / 16) % 2 == 0
			img.set_pixel(x, y, Color(1.0, 0.72, 0.05) if on else Color(0.06, 0.06, 0.07))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.5
	m.uv1_scale = Vector3(3, 2, 1)
	_cache.m_haz = m
	return m


# ------------------------------------------------------------------ partículas
static func _ramp(cols: Array, offs: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	return g


static func _curve(pts: Array) -> Curve:
	var cv := Curve.new()
	cv.max_value = 8.0
	for p in pts:
		cv.add_point(p)
	return cv


## emissor contínuo de billboards (fogo aditivo ou fumaça/neve)
static func trail(fx: Fx, add: bool, amount: int, life: float, s0: float, s1: float, cols: Array, offs: Array, vel := 1.5, grav := Vector3.ZERO, radius := 0.6) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = fx.billboard_mat(add)
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.gravity = grav
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
	p.scale_amount_min = s0 * 0.8
	p.scale_amount_max = s0 * 1.2
	p.scale_amount_curve = _curve([Vector2(0, 0.6), Vector2(0.2, 1.0), Vector2(1, s1 / s0)])
	p.color_ramp = _ramp(cols, offs)
	return p


# ------------------------------------------------------------------ peças prontas
## bola de neve gigante: núcleo amassado, torrões grudados, neve espirrando atrás e sombra no chão
static func snowball(fx: Fx, radius: float) -> Dictionary:
	var root := Node3D.new()
	var ball := MeshInstance3D.new()
	ball.mesh = lumpy("snowball", radius, 0.11, 0.9, 11, 20, 32)
	ball.material_override = snow_mat()
	root.add_child(ball)
	for i in 7:
		var lump := MeshInstance3D.new()
		lump.mesh = lumpy("snowlump%d" % (i % 3), radius * randf_range(0.2, 0.3), 0.25, 1.6, 20 + i, 8, 12)
		lump.material_override = snow_mat()
		var d := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		lump.position = d * radius * 0.93
		ball.add_child(lump)
	var spray := trail(fx, false, 26, 0.8, 1.2, 3.2, [Color(1, 1, 1, 0), Color(0.95, 0.97, 1.0, 0.85), Color(0.9, 0.94, 1.0, 0.0)], [0.0, 0.15, 1.0], 4.0, Vector3(0, -3.0, 0), radius * 0.5)
	spray.position = Vector3(0, -radius * 0.75, 0)
	root.add_child(spray)
	var sh := fx.contact_shadow(radius * 1.6, radius * 1.6)
	sh.position = Vector3(0, -radius + 0.06, 0)
	root.add_child(sh)
	return {"root": root, "ball": ball, "spray": spray}


## meteoro: rocha com rachaduras de lava, chama e fumaça no rastro e uma luz laranja
static func meteor(fx: Fx) -> Node3D:
	var root := Node3D.new()
	var rock := MeshInstance3D.new()
	rock.mesh = lumpy("meteor", 1.25, 0.32, 1.4, 31, 14, 24)
	rock.material_override = rock_mat()
	rock.name = "Rock"
	root.add_child(rock)
	var fire := trail(fx, true, 46, 0.42, 2.2, 0.6, [Color(4, 3.4, 2.2, 1), Color(3.2, 1.3, 0.3, 1), Color(1.2, 0.25, 0.05, 0.0)], [0.0, 0.3, 1.0], 1.2, Vector3.ZERO, 0.9)
	root.add_child(fire)
	var smoke := trail(fx, false, 30, 1.1, 1.6, 4.5, [Color(0.2, 0.17, 0.16, 0), Color(0.22, 0.19, 0.18, 0.75), Color(0.3, 0.28, 0.28, 0.0)], [0.0, 0.2, 1.0], 0.8, Vector3(0, 1.0, 0), 0.8)
	root.add_child(smoke)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.15)
	l.light_energy = 2.5
	l.omni_range = 10.0
	l.shadow_enabled = false
	root.add_child(l)
	return root


## bolota de lama que o crocodilo cospe (pinga no caminho)
static func mud_blob(fx: Fx) -> Node3D:
	var root := Node3D.new()
	var b := MeshInstance3D.new()
	b.mesh = lumpy("mudblob", 0.85, 0.3, 1.8, 41, 10, 16)
	b.material_override = mud_mat()
	b.name = "Blob"
	root.add_child(b)
	var drip := trail(fx, false, 14, 0.5, 0.5, 0.2, [Color(0.3, 0.19, 0.07, 0), Color(0.32, 0.2, 0.08, 0.95), Color(0.25, 0.15, 0.05, 0.0)], [0.0, 0.1, 1.0], 1.0, Vector3(0, -14, 0), 0.5)
	root.add_child(drip)
	return root


## pedaço solto (torrão de neve, rocha, lama) para os estilhaços
static func chunk(kind: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	match kind:
		"snow":
			mi.mesh = lumpy("snowlump%d" % (randi() % 3), randf_range(0.35, 0.7), 0.3, 1.6, 20 + randi() % 3, 8, 12)
			mi.material_override = snow_mat()
		"mud":
			mi.mesh = lumpy("mudchunk", 0.35, 0.35, 2.0, 43, 8, 12)
			mi.material_override = mud_mat()
		_:
			mi.mesh = lumpy("rockchunk%d" % (randi() % 2), randf_range(0.25, 0.5), 0.4, 2.2, 50 + randi() % 2, 8, 12)
			mi.material_override = rock_mat() if kind == "lava" else metal_mat(Color(0.3, 0.27, 0.24), 0.95, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## faixa de pregos de polícia atravessando a pista (eixo X local), com uma brecha.
## Devolve {"root", "plates": MultiMesh, "spikes": MultiMesh, "xs": posições dos segmentos} para desenrolar.
static func spike_strip(half: float, gap: float, gap_w: float) -> Dictionary:
	var root := Node3D.new()
	var xs: Array = []
	var x := -half
	while x <= half:
		if absf(x - gap) > gap_w:
			xs.append(x)
		x += 0.92
	var plate := BoxMesh.new()
	plate.size = Vector3(0.86, 0.07, 0.62)
	var mmp := MultiMesh.new()
	mmp.transform_format = MultiMesh.TRANSFORM_3D
	mmp.mesh = plate
	mmp.instance_count = xs.size()
	var mip := MultiMeshInstance3D.new()
	mip.multimesh = mmp
	mip.material_override = metal_mat(Color(0.12, 0.12, 0.13), 0.7, 0.4)
	root.add_child(mip)
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.075
	spike.height = 0.34
	spike.radial_segments = 4
	var mms := MultiMesh.new()
	mms.transform_format = MultiMesh.TRANSFORM_3D
	mms.mesh = spike
	mms.instance_count = xs.size() * 6
	var mis := MultiMeshInstance3D.new()
	mis.multimesh = mms
	mis.material_override = metal_mat(Color(0.85, 0.87, 0.9), 0.18, 1.0)
	root.add_child(mis)
	# pontas de alerta nos dois lados da brecha
	for sgn: float in [-1.0, 1.0]:
		var cap := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(0.3, 0.16, 0.7)
		cap.mesh = cb
		cap.material_override = hazard_mat()
		cap.position = Vector3(gap + sgn * (gap_w - 0.25), 0.08, 0)
		root.add_child(cap)
	return {"root": root, "plates": mmp, "spikes": mms, "xs": xs}


## posiciona os segmentos (u = quanto já desenrolou, 0..1; cada segmento sobe e gira de leve, sanfonado)
static func spike_strip_set(d: Dictionary, u: float, from_left: bool) -> void:
	var xs: Array = d.xs
	var n := xs.size()
	var mmp: MultiMesh = d.plates
	var mms: MultiMesh = d.spikes
	for i in n:
		var k := float(i) / maxf(1.0, n - 1.0)
		if not from_left:
			k = 1.0 - k
		var s := clampf((u - k * 0.7) / 0.3, 0.0, 1.0)
		s = 1.0 - pow(1.0 - s, 3.0)
		var zig := 0.12 if i % 2 == 0 else -0.12
		var b := Basis(Vector3.UP, zig).scaled(Vector3(s, s, s))
		var o := Vector3(float(xs[i]), 0.04, 0)
		mmp.set_instance_transform(i, Transform3D(b, o))
		for r in 2:
			for c in 3:
				var so := Vector3((c - 1) * 0.26, 0.2, (r - 0.5) * 0.3)
				var tilt := Basis(Vector3.RIGHT, -0.35 if r == 0 else 0.35)
				mms.set_instance_transform(i * 6 + r * 3 + c, Transform3D(b * tilt, o + b * so))


## poste do portão laser: base sextavada, coluna com faixas de alerta, emissor com anel aceso e luz piscando no topo
static func laser_pylon(beam_h: float) -> Dictionary:
	var root := Node3D.new()
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.48
	bm.bottom_radius = 0.6
	bm.height = 0.28
	bm.radial_segments = 6
	base.mesh = bm
	base.material_override = metal_mat(Color(0.1, 0.1, 0.12), 0.45, 0.8)
	base.position.y = 0.14
	root.add_child(base)
	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.17
	cm.bottom_radius = 0.24
	cm.height = beam_h + 1.2
	cm.radial_segments = 8
	col.mesh = cm
	col.material_override = metal_mat(Color(0.16, 0.16, 0.19), 0.3, 0.9)
	col.position.y = 0.28 + cm.height * 0.5
	root.add_child(col)
	var band := MeshInstance3D.new()
	var hb := CylinderMesh.new()
	hb.top_radius = 0.255
	hb.bottom_radius = 0.255
	hb.height = 0.5
	hb.radial_segments = 8
	band.mesh = hb
	band.material_override = hazard_mat()
	band.position.y = 0.6
	root.add_child(band)
	# emissor: anel e lente na altura do feixe
	var emit_m := glow_mat(Color(1.0, 0.15, 0.25), 4.0)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.24
	tm.outer_radius = 0.36
	tm.rings = 20
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = emit_m
	ring.rotation = Vector3(0, 0, PI * 0.5)
	ring.position.y = beam_h
	root.add_child(ring)
	var lens := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.radial_segments = 12
	sm.rings = 6
	lens.mesh = sm
	lens.material_override = emit_m
	lens.position.y = beam_h
	root.add_child(lens)
	var top_m := glow_mat(Color(1.0, 0.6, 0.1), 3.0)
	var top := MeshInstance3D.new()
	var tsm := SphereMesh.new()
	tsm.radius = 0.13
	tsm.height = 0.26
	top.mesh = tsm
	top.material_override = top_m
	top.position.y = 0.28 + cm.height + 0.1
	root.add_child(top)
	return {"root": root, "emit": emit_m, "top": top_m}


## feixe: núcleo fino e brilho macio em volta (cilindro ao longo do eixo X local)
static func laser_beam(length: float) -> Node3D:
	var root := Node3D.new()
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.05
	cm.height = length
	cm.radial_segments = 8
	core.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(3.5, 1.4, 1.6)
	core.material_override = m
	core.rotation = Vector3(0, 0, PI * 0.5)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	var glow := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.42
	gm.bottom_radius = 0.42
	gm.height = length
	gm.radial_segments = 16
	glow.mesh = gm
	var sh := ShaderMaterial.new()
	sh.shader = load("res://shaders/beam_glow.gdshader")
	sh.set_shader_parameter("col", Color(1.0, 0.15, 0.25))
	glow.material_override = sh
	glow.rotation = Vector3(0, 0, PI * 0.5)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	return root

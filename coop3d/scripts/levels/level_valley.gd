extends LevelBase
## Vale do Riacho - a continuous, grounded world (no floating islands or
## planets): a valley carved by a river, two cliffs, a forest walled by
## rocks, a deep ravine and a flower hill. Puzzles live in the geography.

const RIVER_Z := -40.0
const CLIFF1_Z := -62.0
const CLIFF2_Z := -104.0
const RAVINE_Z := -127.0
const WATER_Y := -1.1

var ground: TerrainGround
var _noise := FastNoiseLite.new()


func configure() -> void:
	music_seed = 4
	kill_y = -30.0
	floating_world = false
	sky_colors = {
		"zenith": Color(0.28, 0.56, 0.98), "horizon": Color(0.86, 0.92, 1.0), "ground": Color(0.46, 0.62, 0.55),
		"ambient": Color(0.7, 0.74, 0.9), "fog": Color(0.82, 0.9, 1.0), "stars": 0.0, "clouds": 0.5,
		"sun": Color(1.0, 0.95, 0.86),
	}


# ------------------------------------------------------------- the shape
func _step(z: float, at: float, width: float) -> float:
	return smoothstep(at + width, at - width, z)


func height_at(x: float, z: float) -> float:
	var y := 0.0
	var path := smoothstep(4.0, 14.0, absf(x))  # flat walkway in the middle
	y += _noise.get_noise_2d(x, z) * 1.6 * path
	# cliffs (steeper than the walkable 50 degrees)
	y += 4.5 * _step(z, CLIFF1_Z, 0.9)
	y += 4.5 * _step(z, CLIFF2_Z, 0.9)
	# river bed winding across the valley
	var zr := RIVER_Z + 3.0 * sin(x * 0.07)
	var dr := absf(z - zr)
	y -= 3.6 * (1.0 - smoothstep(4.5, 7.0, dr))
	# sandbar island in the river (secret seed)
	y += 3.4 * (1.0 - smoothstep(1.8, 3.2, Vector2(x - 15.0, z - (RIVER_Z + 3.0 * sin(15.0 * 0.07))).length()))
	# deep ravine on the upper plateau
	var dv := absf(z - RAVINE_Z)
	y -= 34.0 * (1.0 - smoothstep(4.8, 5.8, dv))
	# flower hill around the goal
	y += 1.6 * (1.0 - smoothstep(2.0, 16.0, Vector2(x, z + 152.0).length()))
	# valley walls (sides + ends), wobbly so they look natural
	var ax := absf(x) + _noise.get_noise_2d(z * 2.0, 7.0) * 3.0
	y += 18.0 * smoothstep(27.0, 31.0, ax)
	y += 18.0 * smoothstep(16.0, 20.0, z)
	y += 18.0 * smoothstep(-161.0, -165.0, z)
	return y


func g(x: float, z: float) -> float:
	return ground.height(x, z)


func at(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, g(x, z) + lift, z)


func is_out_of_bounds(pos: Vector3) -> bool:
	return pos.y < -2.2 or super.is_out_of_bounds(pos)


# ------------------------------------------------------------------ build
func build() -> void:
	_noise.seed = 11
	_noise.frequency = 0.045
	_noise.fractal_octaves = 3
	ground = TerrainGround.new()
	add_child(ground)
	ground.build(height_at, -48, 48, -170, 22)
	spawn = at(0, 10, 0.3)
	spawn_fwd = Vector3.FORWARD
	_water()
	_scatter()

	# ------------------------------------------ 1: meadow + river bridge
	sign_text(at(-3.5, 5), "Bem-vindos ao Vale do Riacho!\nMover e pular (segure para mais alto)")
	sign_text(at(3.5, 5), "Lumi: pulo duplo e PLANAR\nDash + pulo = pulo longo")
	mushroom(at(-11, 0), 19.0, 1.4)
	spark_ring(at(-11, 0, 6.5), 1.4, 6)
	block(at(-14, -14, 4.6), Vector3(3.0, 6.0, 3.0), "stone")
	star_seed(at(-14, -14, 4.6 + 3.3), 0)
	sign_text(at(-10, -9), "Aquela semente no pilar...\nBolota, arremesse a Lumi!")
	spark_line(at(0, 2, 1.0), at(0, -10, 1.0), 6)
	plate(at(-5, -25), "a")
	plate(at(5, -25), "b")
	latch_gate("river", ["a", "b"])
	sign_text(at(0, -22), "Um herói em cada placa\nestende a ponte sobre o rio!")
	bridge(Vector3(0, 0.25, RIVER_Z), Vector3(3.4, 0.5, 17.0), "river")
	spark_line(Vector3(0, 1.4, RIVER_Z + 6), Vector3(0, 1.4, RIVER_Z - 6), 5)
	star_seed(at(15, RIVER_Z + 3.0 * sin(15.0 * 0.07), 1.3), 1)

	# ------------------------- 2: the first cliff (throw + plate elevator)
	checkpoint_at(at(-4, -52))
	sign_text(at(-4.5, -57), "Bolota: ERGA a Lumi (F / . / Y) e arremesse\nparado para jogá-la PARA CIMA!")
	plate(at(-4, -68), "lift")
	sign_text(at(5.5, -55), "Lumi segura a placa lá em cima\ne o ELEVADOR sobe com o Bolota")
	mover(at(6, -58.9, 0.15), Vector3(3.0, 0.5, 3.0), [Vector3.ZERO, Vector3(0, 4.6, 0)], 1.6, "lift", 0.0, "stone")
	block(Vector3(6, g(6, -65.0), -62.2), Vector3(3.0, 0.6, 3.6), "wood")
	spark_line(at(6, -58.9, 1.5), at(6, -58.9, 5.5), 4)

	# --------------------------------------- 3: forest + rock wall gate
	for x in [-24.0, -19.0, -14.0, -9.0, -4.5]:
		block(at(x, -92, 4.4), Vector3(5.2, 5.4, 2.2), "stone")
		block(at(-x, -92, 4.4), Vector3(5.2, 5.4, 2.2), "stone")
	gate(at(0, -92), ["heavy"], 0.0, 3.4, 3.4, false)
	plate(at(7, -86), "heavy", true)
	crate(at(-7, -78))
	crate(at(9, -74), true)
	crate(at(-11, -88), true)
	urchin([at(-6, -82), at(6, -82)], 1.6)
	urchin([at(-8, -72), at(-8, -66)], 1.2)
	sign_text(at(2.5, -80), "Portão ⬇⬇: a placa pesada precisa\ndo Bolota... ou de um caixote!")
	checkpoint_at(at(-4, -71))
	spark_ring(at(0, -76, 1.0), 5.0, 12)

	# -------------------------- 4: second cliff (updraft + light tether)
	wind_fan(at(0, -100), 12.0, 36.0)
	sign_text(at(-4, -97), "Lumi: PLANE sobre o ventilador.\nLá em cima, o ELO DE LUZ puxa o Bolota!")
	spark_line(at(0, -100, 2.0), at(0, -100, 9.0), 5)
	checkpoint_at(at(-5, -111))

	# ------------------------------------------- 5: ravine timed bridge
	pound_switch(at(5, -116), "rav", "timed", 8.0)
	sign_text(at(-4, -116), "GROUND POUND no ⏱ (no ar)\ne atravessem o desfiladeiro!")
	for i in 4:
		bridge(Vector3(0, 9.25, RAVINE_Z + 4.5 - i * 3.0), Vector3(3.2, 0.5, 2.95), "rav")
	spark_line(Vector3(0, 10.4, RAVINE_Z + 4), Vector3(0, 10.4, RAVINE_Z - 4), 4)

	# ----------------------------------- 6: flower hill + tide blocks + goal
	pound_switch(at(-6, -140), "tide", "toggle")
	sign_text(at(-2, -137), "Blocos de MARÉ: o ⟳ alterna rosa e azul")
	bridge(at(-10, -145, 1.9), Vector3(2.4, 0.5, 2.4), "tide", true)
	bridge(at(-12.5, -148.5, 3.8), Vector3(2.4, 0.5, 2.4), "tide", false)
	star_seed(at(-12.5, -148.5, 5.6), 2)
	urchin([at(5, -141), at(9, -147)], 1.5)
	goal(at(0, -152))
	spark_ring(at(0, -152, 1.2), 5.0, 14)


func _water() -> void:
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(62, 22)
	pm.subdivide_width = 40
	pm.subdivide_depth = 14
	water.mesh = pm
	var wm := ShaderLib.material("water")
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	water.global_position = Vector3(0, WATER_Y, RIVER_Z)
	# waterfall feeding the river from the west wall
	var fall := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(5.0, 15.0)
	fall.mesh = q
	var fm := ShaderLib.material("water")
	fm.set_shader_parameter("fall", 1.0)
	fall.material_override = fm
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fall)
	fall.global_position = Vector3(-27.5, WATER_Y + 6.5, RIVER_Z + 3.0 * sin(-27.5 * 0.07))
	fall.rotation.y = PI * 0.5
	var mist := CPUParticles3D.new()
	mist.amount = 24
	mist.lifetime = 1.4
	var mq := QuadMesh.new()
	mq.size = Vector2(1.2, 1.2)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_texture = Vfx.tex_puff
	mm.albedo_color = Color(1, 1, 1, 0.5)
	mq.material = mm
	mist.mesh = mq
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(0.5, 0.2, 2.2)
	mist.direction = Vector3(1, 0.6, 0)
	mist.spread = 35.0
	mist.initial_velocity_min = 1.0
	mist.initial_velocity_max = 2.5
	mist.gravity = Vector3(0, 0.3, 0)
	add_child(mist)
	mist.global_position = Vector3(-26.5, WATER_Y + 0.2, fall.global_position.z)


## Trees, rocks, bushes, flowers and grass across the walkable ground.
func _scatter() -> void:
	var xf := []
	var n := 2600 if low_spec else 7500
	for i in n:
		var x := _rng.randf_range(-26.0, 26.0)
		var z := _rng.randf_range(-160.0, 16.0)
		var y := g(x, z)
		if y < WATER_Y + 0.25 or ground.normal(x, z).y < 0.85:
			continue
		var s := _rng.randf_range(0.6, 1.4)
		xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.3), s)), Vector3(x, y - 0.03, z)))
	_grass_mmi(xf)
	# trees along the valley sides (leave the middle free for play)
	var trees := 0
	var tries := 0
	while trees < (28 if low_spec else 46) and tries < 600:
		tries += 1
		var x := _rng.randf_range(-25.0, 25.0)
		if absf(x) < 9.0:
			continue
		var z := _rng.randf_range(-160.0, 14.0)
		if ground.normal(x, z).y < 0.9 or g(x, z) < WATER_Y + 0.6:
			continue
		if absf(z - CLIFF1_Z) < 4.0 or absf(z - CLIFF2_Z) < 4.0 or absf(z - RAVINE_Z) < 8.0 or absf(z + 92.0) < 3.0:
			continue
		tree(at(x, z), _rng.randf_range(1.2, 1.9), _rng.randf() < 0.35)
		trees += 1
	for i in (10 if low_spec else 22):
		var x := _rng.randf_range(-24.0, 24.0)
		var z := _rng.randf_range(-160.0, 14.0)
		if absf(x) < 6.0 or g(x, z) < WATER_Y + 0.4 or ground.normal(x, z).y < 0.85:
			continue
		if i % 3 == 0:
			rock(at(x, z), _rng.randf_range(0.8, 1.6))
		elif i % 3 == 1:
			bush(at(x, z), _rng.randf_range(0.9, 1.3))
		else:
			crystal(at(x, z), _rng.randf_range(0.7, 1.1))
	for i in (20 if low_spec else 60):
		var x := _rng.randf_range(-24.0, 24.0)
		var z := _rng.randf_range(-160.0, 14.0)
		if g(x, z) < WATER_Y + 0.4 or ground.normal(x, z).y < 0.9:
			continue
		flower(at(x, z))

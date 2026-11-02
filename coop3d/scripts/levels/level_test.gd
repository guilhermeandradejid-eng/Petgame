extends LevelBase
## Campo de Treino: a compact test stage with every mechanic in a row.
## Used as the demo level (and the first level of the Android build).


func configure() -> void:
	music_seed = 1
	kill_y = -30.0


func build() -> void:
	spawn = Vector3(0, 0.2, 6)
	spawn_fwd = Vector3.FORWARD

	# --------------------------------------- A: basics + two plates
	island(Vector3(0, 0, 0), 11.0)
	sign_text(Vector3(-3.0, 0, 5.0), "Mover e pular!\nSegure pulo para ir mais alto")
	sign_text(Vector3(3.0, 0, 5.0), "Lumi: pulo duplo + segure para PLANAR\nDash + pulo = PULO LONGO")
	mushroom(Vector3(-8.0, 0, 2.0), 19.0, 1.3)
	spark_ring(Vector3(-8.0, 6.0, 2.0), 1.4, 6)
	block(Vector3(7.5, 2.8, 3.0), Vector3(2.6, 3.2, 2.6), "stone")
	spark_ring(Vector3(7.5, 3.6, 3.0), 0.9, 5)
	plate(Vector3(-5.0, 0, -4.0), "a")
	plate(Vector3(5.0, 0, -4.0), "b")
	sign_text(Vector3(0, 0, -2.0), "Um herói em cada placa\nabre o portão!")
	tree(Vector3(-8.5, 0, -5.0), 1.4, true)
	tree(Vector3(8.5, 0, -5.5), 1.3)
	bush(Vector3(-3.0, 0, 8.5), 1.0)
	crystal(Vector3(4.0, 0, 8.5), 1.0)
	spark_line(Vector3(0, 1, 2), Vector3(0, 1, -6), 5)
	block(Vector3(0, 0, -14.5), Vector3(3.6, 0.8, 8.0), "wood")
	gate(Vector3(0, 0, -12.5), ["a", "b"], 0.0, 3.4, 3.4)

	# --------------------------- B: throw + heavy plate + enemy + crate
	island(Vector3(0, 0, -27), 9.0)
	block(Vector3(-4.5, 4.5, -29.0), Vector3(3.6, 5.2, 3.6), "stone")
	plate(Vector3(-4.5, 4.5, -29.0), "c")
	star_seed(Vector3(-4.5, 7.9, -29.0), 0)
	plate(Vector3(4.5, 0, -26.0), "d", true)
	sign_text(Vector3(0, 0, -22.0), "Bolota: ERGA a Lumi e ARREMESSE (parado = para cima)\nPlaca ⬇⬇ pesada: Bolota ou caixote")
	crate(Vector3(6.5, 0, -31.0))
	crate(Vector3(-7.0, 0, -24.0), true)
	urchin([Vector3(-3.0, 0, -33.0), Vector3(4.0, 0, -33.0)], 1.5)
	checkpoint_at(Vector3(-6.5, 0, -27.0))
	block(Vector3(0, 0, -40.0), Vector3(3.6, 0.8, 9.0), "wood")
	gate(Vector3(0, 0, -38.0), ["c", "d"], 0.0, 3.4, 3.4)

	# ------------------------------------ C: timed bridge (ground pound)
	island(Vector3(0, 0, -53), 9.0)
	pound_switch(Vector3(4.0, 0, -51.0), "t", "timed", 7.0)
	sign_text(Vector3(-3.5, 0, -49.0), "GROUND POUND no ⏱ (no ar)\ne corram pela ponte!")
	for i in 2:
		bridge(Vector3(0, 0, -62.75 - i * 2.5), Vector3(3.0, 0.6, 2.45), "t")
	tree(Vector3(-7.0, 0, -56.0), 1.3, true)
	spark_ring(Vector3(0, 1, -53), 5.0, 10)

	# ------------------------------ D: rift + updraft for Lumi + tether
	island(Vector3(0, 0, -73), 7.5)
	plate(Vector3(4.0, 0, -70.0), "r")
	rift_pair(Vector3(-4.5, 0, -71.0), Vector3(0, 0, 1), Vector3(-20.0, 0, -71.0), Vector3(0, 0, 1), "r", "r")
	island(Vector3(-20, 0, -72), 4.0)
	star_seed(Vector3(-21.0, 1.4, -74.0), 1)
	plate(Vector3(-18.5, 0, -73.5), "r")
	sign_text(Vector3(-1.0, 0, -68.0), "A FENDA abre com alguém na placa")
	wind_fan(Vector3(0, 0, -78.5), 12.0, 36.0)
	sign_text(Vector3(3.5, 0, -76.0), "Lumi: PLANE sobre o ventilador.\nLá em cima, Elo de Luz puxa o Bolota!")
	checkpoint_at(Vector3(-4.0, 0, -76.0))

	# ---------------------------------- E: high island + tide blocks
	island(Vector3(0, 9, -90), 7.5)
	pound_switch(Vector3(-4.0, 9, -88.0), "tide", "toggle")
	bridge(Vector3(3.5, 10.8, -91.0), Vector3(2.4, 0.6, 2.4), "tide", true)
	bridge(Vector3(5.5, 12.6, -93.5), Vector3(2.4, 0.6, 2.4), "tide", false)
	star_seed(Vector3(5.5, 14.4, -93.5), 2)
	sign_text(Vector3(0, 9, -86.0), "Blocos de MARÉ: o ⟳ alterna rosa e azul")
	checkpoint_at(Vector3(-5.0, 9, -92.0))

	# ------------------------------- F: tiny planet + launch rings + goal
	var p := planet(Vector3(0, 20, -118), 5.0, "planet")
	launch_ring(Vector3(0, 9, -95.0), p.global_position + Vector3.UP * 6.2, 9.0, 1.5)
	spark_ring(p.global_position, 6.2, 14, Vector3.UP)
	spark_ring(p.global_position, 6.2, 10, Vector3.RIGHT)
	for d in [Vector3(0.6, 0.6, 0.4), Vector3(-0.6, 0.3, -0.6), Vector3(0.2, -0.8, 0.6)]:
		var t := on_planet(p, d)
		tree(t["pos"], 0.9, true, t["up"])
	var top := on_planet(p, Vector3(0.3, 1, 0.5))
	sign_text(top["pos"], "Gravidade de planetinha:\ndê a volta até o outro anel!")
	var r := on_planet(p, Vector3(0, -0.2, -1))
	launch_ring(r["pos"], Vector3(0, 9.6, -136), 9.0, 1.6, "", r["up"])
	island(Vector3(0, 9, -141), 8.5)
	goal(Vector3(0, 9, -144))
	tree(Vector3(-6.0, 9, -146.0), 1.5, true)
	tree(Vector3(6.0, 9, -145.0), 1.4)
	spark_ring(Vector3(0, 10, -144), 4.5, 12)

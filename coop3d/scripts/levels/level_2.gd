extends LevelBase
## Level 2 - Jardim Orbital.
## Tiny planets with spherical gravity: walk all the way around them,
## hold plates on opposite sides of a planet, race a timed switch around
## another one, and hop between twin moons whose gravity fields touch.


func configure() -> void:
	music_seed = 2
	kill_y = -40.0
	sky_colors = {
		"zenith": Color(0.2, 0.22, 0.55), "horizon": Color(0.98, 0.66, 0.72), "ground": Color(0.42, 0.36, 0.7),
		"ambient": Color(0.72, 0.66, 0.95), "fog": Color(0.85, 0.65, 0.8), "stars": 0.9, "clouds": 0.3,
		"sea_top": Color(0.98, 0.88, 0.95), "sea_low": Color(0.62, 0.52, 0.88), "sun": Color(1.0, 0.86, 0.8),
	}


func build() -> void:
	spawn = Vector3(0, 0.2, 4)
	spawn_fwd = Vector3.FORWARD

	# ------------------------------------------------------- start island
	island(Vector3(0, 0, 0), 8.0)
	tree(Vector3(-5.5, 0, 2.0), 1.4, true)
	tree(Vector3(5.0, 0, 3.0), 1.2)
	crystal(Vector3(-4.5, 0, -4.0), 1.2)
	sign_text(Vector3(-2.5, 0, -1.0), "Anel de pétalas: pise nele\npara voar até o planetinha!")
	sign_text(Vector3(3.0, 0, -1.5), "Nos planetas a gravidade puxa\npara o centro: dê a volta neles!")
	var p1 := planet(Vector3(0, 6, -40), 7.0, "planet")
	launch_ring(Vector3(0, 0, -5.0), p1.global_position + Vector3.UP * 8.2, 10.0, 1.6)
	spark_arc(Vector3(0, 2, -8), Vector3(0, 14, -34), 6.0, 7)

	# ---------------------------------- planet 1: plates on opposite sides
	var a := on_planet(p1, Vector3(1, 0.25, 0))
	var b := on_planet(p1, Vector3(-1, 0.25, 0))
	plate(a["pos"], "p1a", false, a["up"])
	plate(b["pos"], "p1b", false, b["up"])
	and_gate("p1", ["p1a", "p1b"])
	var top := on_planet(p1, Vector3(0, 1, 0.35))
	sign_text(top["pos"], "Duas placas em lados opostos\nligam o anel do outro lado!")
	spark_ring(p1.global_position, 8.2, 16, Vector3.UP)
	spark_ring(p1.global_position, 8.2, 12, Vector3.RIGHT)
	for d in [Vector3(0.6, 0.7, 0.4), Vector3(-0.5, 0.6, -0.6), Vector3(0.3, -0.8, 0.5), Vector3(-0.7, -0.4, 0.6)]:
		var t := on_planet(p1, d)
		tree(t["pos"], 1.0, randf() < 0.5, t["up"])
	for d in [Vector3(0.9, -0.2, -0.4), Vector3(-0.3, 0.2, 0.95), Vector3(0.1, -1, -0.2)]:
		var t := on_planet(p1, d)
		crystal(t["pos"], 0.9, t["up"])
	var u0 := on_planet(p1, Vector3(0.2, 0.5, 1))
	var u1 := on_planet(p1, Vector3(-0.2, -0.5, 1))
	urchin([u0["pos"], u1["pos"]], 1.4, p1.global_position)
	var seed_spot := on_planet(p1, Vector3(0, -1, -0.15), 4.2)
	star_seed(seed_spot["pos"], 0)
	var p2 := planet(Vector3(30, 14, -72), 5.0, "planet_pink")
	var ring_spot := on_planet(p1, Vector3(0, 0.1, -1))
	launch_ring(ring_spot["pos"], p2.global_position + Vector3.UP * 6.2, 12.0, 1.7, "p1", ring_spot["up"])
	checkpoint_at(on_planet(p1, Vector3(0.35, 0.95, 0.4))["pos"], on_planet(p1, Vector3(0.35, 0.95, 0.4))["up"])

	# ------------------------------------ planet 2: race the timed switch
	var sw := on_planet(p2, Vector3(0.2, 1, 0.3))
	pound_switch(sw["pos"], "p2", "timed", 9.0, sw["up"])
	var sgn := on_planet(p2, Vector3(-0.6, 1, 0.2))
	sign_text(sgn["pos"], "Ground pound no ⏱ e corram\naté o anel do outro lado!")
	spark_ring(p2.global_position, 6.0, 14, Vector3(1, 0, 1).normalized())
	for d in [Vector3(1, 0.3, 0.2), Vector3(-0.4, 0.5, -0.9), Vector3(0.3, -0.6, 0.8), Vector3(-0.9, -0.3, 0.1)]:
		var t := on_planet(p2, d)
		flower(t["pos"], t["up"])
		bush(on_planet(p2, d + Vector3(0.2, 0.1, 0))["pos"], 0.8, on_planet(p2, d + Vector3(0.2, 0.1, 0))["up"])
	var gold := on_planet(p2, Vector3(0.9, 0.4, -0.6))
	var gc := crate(gold["pos"] - Vector3(0, 0.5, 0), true)
	gc.global_basis = Basis(Quaternion(Vector3.UP, gold["up"]))
	var m1 := planet(Vector3(55, 22, -96), 3.6, "planet_sand")
	var m2 := planet(Vector3(55, 22, -107.4), 3.6, "planet_sand")
	var r2 := on_planet(p2, Vector3(0, -0.35, -1))
	launch_ring(r2["pos"], m1.global_position + Vector3.UP * 4.8, 10.0, 1.6, "p2", r2["up"])
	checkpoint_at(on_planet(p2, Vector3(-0.3, 1, -0.3))["pos"], on_planet(p2, Vector3(-0.3, 1, -0.3))["up"])

	# ---------------------------------------------- twin moons hop
	spark_line(Vector3(55, 22, -100.5), Vector3(55, 22, -103.0), 3)
	star_seed(Vector3(55, 27.8, -101.7), 1)
	var s1 := on_planet(m1, Vector3(0, 1, 0.3))
	sign_text(s1["pos"], "Pule de uma lua para a outra:\na gravidade troca no meio!")
	for d in [Vector3(1, 0.2, 0), Vector3(-1, 0.3, 0.2), Vector3(0, -1, 0)]:
		var t := on_planet(m1, d)
		crystal(t["pos"], 0.7, t["up"])
		var t2 := on_planet(m2, d)
		flower(t2["pos"], t2["up"])
	var mu0 := on_planet(m2, Vector3(1, 0.2, 0))
	var mu1 := on_planet(m2, Vector3(0, 0.2, 1))
	urchin([mu0["pos"], mu1["pos"]], 1.0, m2.global_position)
	var r3 := on_planet(m2, Vector3(0, -0.2, -1))
	launch_ring(r3["pos"], Vector3(55, 10.6, -124), 9.0, 1.6, "", r3["up"])

	# ---------------------------------------------- goal island
	island(Vector3(55, 10, -135), 10.0)
	checkpoint_at(Vector3(50.0, 10, -128.0))
	goal(Vector3(55, 10, -141))
	block(Vector3(62.0, 15.0, -136.0), Vector3(2.4, 5.4, 2.4), "stone")
	star_seed(Vector3(62.0, 18.2, -136.0), 2)
	sign_text(Vector3(59.0, 10, -131.0), "Aquela semente lá em cima...\nBolota, arremesse a Lumi!")
	tree(Vector3(48.0, 10, -140.0), 1.6, true)
	tree(Vector3(61.0, 10, -143.0), 1.4)
	crystal(Vector3(50.0, 10, -134.0), 1.3)
	spark_ring(Vector3(55, 11, -141), 5.0, 14)
	urchin([Vector3(50, 10, -137), Vector3(58, 10, -137)], 1.6)

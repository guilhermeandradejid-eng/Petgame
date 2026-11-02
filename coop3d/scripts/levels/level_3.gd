extends LevelBase
## Level 3 - Ruínas da Fenda.
## Timed light bridge, dimensional rifts held open from both sides,
## alternating tide blocks that one hero toggles while the other climbs,
## and a final gate that needs plates on two far-apart islands.


func configure() -> void:
	music_seed = 3
	kill_y = -30.0
	sky_colors = {
		"zenith": Color(0.36, 0.42, 0.85), "horizon": Color(1.0, 0.72, 0.52), "ground": Color(0.6, 0.48, 0.72),
		"ambient": Color(0.78, 0.68, 0.86), "fog": Color(1.0, 0.78, 0.66), "stars": 0.4, "clouds": 0.55,
		"sun": Color(1.0, 0.86, 0.68), "sea_top": Color(1.0, 0.92, 0.86), "sea_low": Color(0.86, 0.66, 0.82),
	}


func build() -> void:
	spawn = Vector3(0, 0.2, 4)
	spawn_fwd = Vector3.FORWARD

	# -------------------------------------------------- A: ruined plaza
	island(Vector3(0, 0, 0), 8.5, -1.0, "ruins")
	for x in [-5.5, 5.5]:
		pillar(Vector3(x, 0, -3.0), 4.5, 0.5)
		pillar(Vector3(x, 0, 3.0), 3.0, 0.5)
	sign_text(Vector3(-2.5, 0, 0), "Ruínas da Fenda: aqui tudo\nprecisa de DOIS heróis.")
	spark_line(Vector3(0, 1, -2), Vector3(0, 1, -7), 4)
	crystal(Vector3(6.5, 0, 0), 1.0)
	block(Vector3(0, 0.4, -11.5), Vector3(2.6, 1.6, 2.6), "ruins")

	# ------------------------------------------------ B: timed bridge
	island(Vector3(0, 0, -22), 8.0, -1.0, "ruins")
	pound_switch(Vector3(3.5, 0, -25.0), "t1", "timed", 7.0)
	sign_text(Vector3(-3.0, 0, -20.0), "GROUND POUND (C / B no ar) no ⏱:\na ponte aparece por pouco tempo!")
	for i in 3:
		bridge(Vector3(0, 0, -32.5 - i * 3.0), Vector3(3.0, 0.6, 2.6), "t1")
	spark_line(Vector3(0, 1.2, -32), Vector3(0, 1.2, -38), 4)
	checkpoint_at(Vector3(-4.5, 0, -24.0))
	urchin([Vector3(-4, 0, -19), Vector3(4, 0, -19)], 1.5)
	# secret seed below the bridge island
	island(Vector3(-11.0, -5.0, -27.0), 2.8, -1.0, "ruins")
	star_seed(Vector3(-11.0, -3.6, -27.5), 0)
	launch_ring(Vector3(-11.5, -5.0, -25.5), Vector3(-3.0, 0.6, -21.0), 6.0, 1.1)
	spark_arc(Vector3(-6.5, 0.8, -24.0), Vector3(-10.5, -3.5, -26.5), 1.4, 5)

	# --------------------------------------------- C: rifts held open
	island(Vector3(0, 0, -48), 8.5, -1.0, "ruins")
	plate(Vector3(5.0, 0, -46.0), "r1")
	var rifts := rift_pair(Vector3(-4.5, 0, -50.0), Vector3(0, 0, 1), Vector3(30.0, 0, -50.0), Vector3(0, 0, 1), "r1", "r1")
	sign_text(Vector3(0, 0, -44.0), "A FENDA só abre com alguém na placa.\nDo outro lado há outra placa!")
	pillar(Vector3(-6.5, 0, -45.0), 3.5)
	pillar(Vector3(6.5, 0, -52.0), 4.0)
	tree(Vector3(-6.0, 0, -54.0), 1.3, true)
	spark_ring(Vector3(0, 1, -48), 5.0, 12)
	checkpoint_at(Vector3(-2.0, 0, -42.5))

	# the far island, reachable only through the rift
	island(Vector3(30, 0, -50), 6.5, -1.0, "ruins")
	plate(Vector3(33.0, 0, -47.0), "r1")
	block(Vector3(26.5, 4.2, -53.0), Vector3(2.2, 4.8, 2.2), "ruins")
	star_seed(Vector3(26.5, 6.0, -53.0), 1)
	crystal(Vector3(34.0, 0, -53.0), 1.3)
	sign_text(Vector3(29.0, 0, -46.0), "Segure a placa daqui para\no parceiro atravessar também!")
	launch_ring(Vector3(30.0, 0, -55.0), Vector3(30.0, 3.6, -74.0), 9.0, 1.5)

	# --------------------------------------------- D: tide staircase
	island(Vector3(30, 3, -80), 9.0, -1.0, "ruins")
	pound_switch(Vector3(26.0, 3, -77.0), "tide", "toggle")
	sign_text(Vector3(33.5, 3, -75.5), "Blocos de MARÉ: o ⟳ alterna rosa e azul.\nUm alterna, o outro sobe!")
	var steps := [
		[Vector3(30.0, 4.8, -86.5), false], [Vector3(33.0, 6.6, -89.5), true],
		[Vector3(30.0, 8.4, -92.5), false], [Vector3(27.0, 10.2, -95.5), true],
	]
	for s in steps:
		bridge(s[0], Vector3(2.8, 0.6, 2.8), "tide", not s[1])
	star_seed(Vector3(24.5, 13.0, -95.5), 2)
	urchin([Vector3(33, 3, -82), Vector3(27, 3, -82)], 1.4)
	crate(Vector3(35.0, 3, -79.0), true)
	checkpoint_at(Vector3(34.0, 3, -84.0))

	# ------------------------------------- E: plates on two far islands
	island(Vector3(30, 12, -102), 7.0, -1.0, "ruins")
	pound_switch(Vector3(26.5, 12, -100.0), "tide", "toggle")
	plate(Vector3(33.0, 12, -104.0), "fx")
	sign_text(Vector3(30.0, 12, -98.5), "Uma placa aqui, outra na ilhota.\nO anel leva até lá!")
	launch_ring(Vector3(25.5, 12, -105.0), Vector3(46.0, 16.6, -104.0), 7.0, 1.4)
	island(Vector3(46, 16, -104), 3.2, -1.0, "ruins")
	plate(Vector3(46.5, 16, -105.0), "fy")
	launch_ring(Vector3(45.0, 16, -102.5), Vector3(31.0, 12.6, -100.0), 6.0, 1.2)
	checkpoint_at(Vector3(27.0, 12, -104.0))
	block(Vector3(30, 12, -113.5), Vector3(3.6, 0.8, 10.0), "wood")
	gate(Vector3(30, 12, -111.0), ["fx", "fy"], 0.0, 3.4, 3.4)

	# --------------------------------------------- F: goal
	island(Vector3(30, 12, -128), 9.5, -1.0, "ruins")
	goal(Vector3(30, 12, -132))
	for x in [-6.0, 6.0]:
		pillar(Vector3(30 + x, 12, -126.0), 5.0, 0.55)
		pillar(Vector3(30 + x, 12, -136.0), 5.0, 0.55)
	tree(Vector3(24.0, 12, -131.0), 1.6, true)
	tree(Vector3(36.5, 12, -130.0), 1.5, true)
	crystal(Vector3(33.0, 12, -124.0), 1.1)
	spark_ring(Vector3(30, 13, -132), 5.0, 14)
	urchin([Vector3(26, 12, -125), Vector3(34, 12, -125)], 1.8)

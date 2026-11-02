extends LevelBase
## Level 1 - Prado das Lanternas.
## Teaches: moving/jumping, dash & long jump, two-plate gate, throwing Lumi
## onto a ledge + heavy plate, crate as a "stand-in" partner, enemies,
## Lumi's hover in an updraft and the Light Tether to pull Bolota up.


func configure() -> void:
	music_seed = 1
	kill_y = -30.0


func build() -> void:
	spawn = Vector3(0, 0.2, 3)
	spawn_fwd = Vector3.FORWARD

	# ---------------------------------------------------- A: meadow start
	island(Vector3(0, 0, 0), 9.0)
	tree(Vector3(-6.0, 0, 3.5), 1.5, true)
	tree(Vector3(6.5, 0, -1.0), 1.3)
	tree(Vector3(-5.5, 0, -5.0), 1.1)
	bush(Vector3(5.0, 0, 4.5), 1.2)
	bush(Vector3(-7.0, 0, -1.5), 1.0)
	rock(Vector3(7.0, 0, 3.0), 1.0)
	sign_text(Vector3(-2.5, 0, 0), "Mover: WASD / Setas / Analógico\nPular: Espaço / Enter / A\n(segure para pular mais alto)")
	sign_text(Vector3(2.8, 0, -3.0), "Câmera: Q/E • PgUp/PgDn • Analógico direito")
	spark_line(Vector3(0, 1, -2), Vector3(0, 1, -7), 5)

	# stepping stone to the second island
	block(Vector3(0, 0.5, -11.5), Vector3(2.6, 2.0, 2.6))
	spark_arc(Vector3(0, 1.2, -9.0), Vector3(0, 1.2, -14.5), 1.6, 5)

	# ---------------------------------------------------- B: moves practice
	island(Vector3(0, 0, -20), 6.5)
	sign_text(Vector3(-3.2, 0, -17.5), "Dash: Shift / Num1 / X\nDash + pulo = PULO LONGO!")
	sign_text(Vector3(3.2, 0, -17.5), "Lumi: pulo duplo no ar\ne segure pulo para PLANAR")
	block(Vector3(4.0, 3.0, -22.5), Vector3(2.6, 3.4, 2.6), "stone")
	spark_ring(Vector3(4.0, 3.9, -22.5), 0.9, 5)
	checkpoint_at(Vector3(-3.5, 0, -22.0))
	tree(Vector3(-4.5, 0, -24.0), 1.2, true)

	# lateral moving platform over the gap
	mover(Vector3(0, 0, -28.6), Vector3(3.0, 0.5, 3.0), [Vector3(-3.5, 0, 0), Vector3(3.5, 0, 0)], 3.0)
	spark_line(Vector3(-3, 1.2, -28.6), Vector3(3, 1.2, -28.6), 4)

	# ---------------------------------------------- C: two plates, one gate
	island(Vector3(0, 0, -40), 9.0)
	plate(Vector3(-5.0, 0, -38.0), "a")
	plate(Vector3(5.0, 0, -38.0), "b")
	sign_text(Vector3(0, 0, -36.0), "Cada herói em uma placa\npara abrir o portão!")
	spark_ring(Vector3(0, 1, -40), 3.5, 10)
	tree(Vector3(-7.0, 0, -44.0), 1.4)
	tree(Vector3(7.0, 0, -43.0), 1.5, true)
	bush(Vector3(6.5, 0, -35.0))
	crystal(Vector3(-7.5, 0, -36.0), 1.0)
	block(Vector3(0, 0, -53.0), Vector3(3.6, 0.8, 9.0), "wood")
	gate(Vector3(0, 0, -51.0), ["a", "b"], 0.0, 3.4, 3.4)
	spark_line(Vector3(0, 1, -54), Vector3(0, 1, -57), 3)

	# ---------------------------------------- D: throw Lumi + heavy plate
	island(Vector3(0, 0, -66), 8.5)
	block(Vector3(-4.0, 4.5, -68.0), Vector3(3.6, 5.2, 3.6), "stone")
	plate(Vector3(-4.0, 4.5, -68.0), "c")
	plate(Vector3(4.0, 0, -65.0), "d", true)
	star_seed(Vector3(-4.0, 7.9, -68.0), 0)
	sign_text(Vector3(-0.5, 0, -62.0), "Bolota: F / . / Y perto da Lumi para erguê-la.\nAperte de novo para ARREMESSAR!")
	sign_text(Vector3(5.5, 0, -61.5), "Placa pesada ⬇⬇:\nsó o Bolota (ou um caixote)")
	checkpoint_at(Vector3(5.0, 0, -70.0))
	tree(Vector3(-6.5, 0, -61.0), 1.3, true)
	bush(Vector3(6.5, 0, -68.5), 1.1)
	block(Vector3(0, 0, -79.0), Vector3(3.6, 0.8, 10.0), "wood")
	gate(Vector3(0, 0, -77.0), ["c", "d"], 0.0, 3.4, 3.4)
	# secret: something sparkles below the east edge (seed + ring back up)
	spark_arc(Vector3(7.0, 0.8, -63.0), Vector3(12.0, -3.0, -60.0), 1.5, 5)
	island(Vector3(13.0, -4.0, -59.0), 3.0, -1.0, "meadow", true)
	star_seed(Vector3(13.5, -2.8, -60.0), 2)
	launch_ring(Vector3(12.0, -4.0, -57.5), Vector3(4.0, 0.6, -62.0), 6.0, 1.1)

	# ----------------------------------------- E: crate + enemies + gate
	island(Vector3(0, 0, -93), 9.0)
	plate(Vector3(-4.5, 0, -97.0), "e")
	crate(Vector3(5.0, 0, -88.0))
	crate(Vector3(6.5, 0, -95.5), true)
	crate(Vector3(-6.5, 0, -90.0), true)
	urchin([Vector3(-5.0, 0, -92.5), Vector3(5.0, 0, -92.5)], 1.8)
	sign_text(Vector3(-5.5, 0, -87.0), "Caixote ⬇⬇ vale um herói na placa.\nBolota pode carregá-lo (F / . / Y)")
	sign_text(Vector3(2.0, 0, -86.5), "Espinhudo: pule nele quando recolher\nos espinhos, ou GROUND POUND (C / B)!")
	checkpoint_at(Vector3(-7.0, 0, -93.0))
	tree(Vector3(7.5, 0, -99.0), 1.4)
	spark_ring(Vector3(0, 1, -93), 6.0, 14)
	block(Vector3(0, 0, -107.0), Vector3(3.6, 0.8, 10.0), "wood")
	gate(Vector3(0, 0, -105.0), ["e"], 0.0, 3.4, 3.4, false)

	# ------------------------------- F: updraft for Lumi, tether for Bolota
	island(Vector3(0, 0, -120), 7.5)
	wind_fan(Vector3(0, 0, -125.5), 12.0, 36.0)
	sign_text(Vector3(-3.5, 0, -116.0), "Lumi: PLANE (segure pulo)\nsobre o ventilador para subir!")
	sign_text(Vector3(3.5, 0, -116.0), "Lumi lá em cima: F / . / Y\npuxa o Bolota com o ELO DE LUZ!")
	mushroom(Vector3(5.0, 0, -119.0), 19.0, 1.25)
	star_seed(Vector3(5.0, 7.2, -119.0), 1)
	spark_line(Vector3(0, 2.0, -125.5), Vector3(0, 10.0, -125.5), 6)
	urchin([Vector3(-4.0, 0, -121.0), Vector3(-4.0, 0, -116.0)], 1.2)

	# --------------------------------------------- G: the Star Bloom
	island(Vector3(0, 9, -142), 9.5)
	checkpoint_at(Vector3(-5.0, 9, -137.0))
	goal(Vector3(0, 9, -146))
	tree(Vector3(-6.5, 9, -148.0), 1.6, true)
	tree(Vector3(6.5, 9, -147.0), 1.5)
	crystal(Vector3(4.0, 9, -139.0), 1.2)
	crystal(Vector3(-3.0, 9, -150.0), 0.9)
	spark_ring(Vector3(0, 10, -146), 4.5, 12)
